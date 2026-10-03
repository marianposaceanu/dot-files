#!/usr/bin/env bash
# Drive Chrome through DevTools; Node.js 22+ supplies fetch and WebSocket.
set -euo pipefail
command -v node >/dev/null || { echo "Node.js 22+ is required" >&2; exit 1; }
exec node --input-type=module - "$@" <<'JAVASCRIPT'
import { access, mkdtemp, readFile, rm } from "node:fs/promises";
import { constants } from "node:fs";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const chrome = process.env.CHROME_BIN || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const iterations = Number(process.argv[2] || 5);
const timeout = Number(process.env.SPEEDOMETER_TIMEOUT_MS || 900000);
const requestTimeout = Number(process.env.SPEEDOMETER_REQUEST_TIMEOUT_MS || 30000);
for (const [name, value] of [["Iteration count", iterations], ["Timeout", timeout], ["Request timeout", requestTimeout]]) {
    if (!Number.isInteger(value) || value < 1) throw new Error(`${name} must be a positive integer`);
}
if (typeof WebSocket !== "function") throw new Error("Node.js 22+ with WebSocket support is required");
await access(chrome, constants.X_OK);
const benchmarkURL = `https://browserbench.org/Speedometer3.1/?startAutomatically&iterationCount=${iterations}&viewport=1200x900`;
const profile = await mkdtemp(join(tmpdir(), "speedometer-profile-"));
const deadline = Date.now() + timeout;
const pending = new Map();
let child, socket, nextID = 1, browserError = "", spawnError = "", stopped = false;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const remaining = () => {
    const ms = deadline - Date.now();
    if (ms <= 0) throw new Error("Speedometer timed out");
    return ms;
};
const failPending = (error) => {
    for (const waiter of pending.values()) { clearTimeout(waiter.timer); waiter.reject(error); }
    pending.clear();
};
async function fetchJSON(url, options = {}) {
    const response = await fetch(url, { ...options, signal: AbortSignal.timeout(Math.min(requestTimeout, remaining())) });
    if (!response.ok) throw new Error(`DevTools HTTP ${response.status}`);
    return response.json();
}
async function endpoint() {
    while (true) {
        remaining();
        if (stopped) throw new Error(spawnError || `Chrome exited before DevTools was ready: ${browserError}`);
        try {
            const [port] = (await readFile(join(profile, "DevToolsActivePort"), "utf8")).split("\n");
            const base = `http://127.0.0.1:${Number(port)}`;
            return { base, version: await fetchJSON(`${base}/json/version`) };
        } catch (error) {
            if (error.code !== "ENOENT") throw error;
        }
        await sleep(Math.min(100, remaining()));
    }
}
function request(method, params = {}) {
    return new Promise((resolve, reject) => {
        const id = nextID++;
        const timer = setTimeout(() => {
            pending.delete(id);
            reject(new Error(`DevTools request timed out: ${method}`));
        }, Math.min(requestTimeout, remaining()));
        pending.set(id, { resolve, reject, timer });
        try { socket.send(JSON.stringify({ id, method, params })); }
        catch (error) { clearTimeout(timer); pending.delete(id); reject(error); }
    });
}
async function evaluate(expression) {
    const response = await request("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
}
try {
    const startedAt = new Date().toISOString();
    child = spawn(chrome, [
        "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
        "--window-size=1200,900", "--no-first-run", "--disable-default-apps",
        "--disable-extensions", "--disable-sync", "--disable-component-update",
        "--disable-background-timer-throttling", "--disable-backgrounding-occluded-windows",
        "--disable-renderer-backgrounding", "about:blank",
    ], { stdio: ["ignore", "ignore", "pipe"], detached: true });
    child.stderr.on("data", (chunk) => { browserError = (browserError + chunk).slice(-8192); });
    // Chrome emits ordinary diagnostics on stderr; only process failure stops startup.
    child.on("error", (error) => { spawnError = error.message; stopped = true; failPending(error); });
    child.on("exit", () => { stopped = true; failPending(new Error(spawnError || "Chrome exited")); });
    const { base, version: browserVersion } = await endpoint();
    const target = await fetchJSON(`${base}/json/new?${encodeURIComponent("about:blank")}`, { method: "PUT" });
    socket = new WebSocket(target.webSocketDebuggerUrl);
    const onDisconnect = () => failPending(new Error("Chrome DevTools connection closed"));
    socket.addEventListener("close", onDisconnect);
    socket.addEventListener("error", onDisconnect);
    await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error("DevTools connection timed out")), Math.min(requestTimeout, remaining()));
        socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
        for (const event of ["error", "close"]) socket.addEventListener(event, () => {
            clearTimeout(timer); reject(new Error("DevTools connection failed"));
        }, { once: true });
    });
    socket.addEventListener("message", (event) => {
        const message = JSON.parse(event.data);
        const waiter = pending.get(message.id);
        if (!waiter) return;
        pending.delete(message.id); clearTimeout(waiter.timer);
        if (message.error) waiter.reject(new Error(message.error.message));
        else waiter.resolve(message.result);
    });
    await request("Runtime.enable");
    await request("Emulation.setDeviceMetricsOverride", { width: 1200, height: 900, deviceScaleFactor: 1, mobile: false });
    const navigation = await request("Page.navigate", { url: benchmarkURL });
    if (navigation.errorText) throw new Error(`Speedometer navigation failed: ${navigation.errorText}`);
    while (true) {
        remaining();
        const state = JSON.parse(await evaluate(`JSON.stringify({
            ready: document.readyState, hash: location.hash,
            score: document.querySelector('#result-number')?.textContent.trim() || '',
            confidence: document.querySelector('#confidence-number')?.textContent.trim() || '',
            valid: document.querySelector('#summary')?.classList.contains('valid') || false,
            progress: document.querySelector('#progress-completed')?.value || 0,
            progressMax: document.querySelector('#progress-completed')?.max || 0,
            iterationScores: globalThis.benchmarkClient?._measuredValuesList?.map((value) => value.score) || [],
            userAgent: navigator.userAgent, viewport: [innerWidth, innerHeight]
        })`));
        if (state.hash === "#summary" && state.score) {
            if (!state.valid || !Number.isFinite(Number(state.score)) || Number(state.score) <= 0)
                throw new Error(`Invalid Speedometer result: ${JSON.stringify(state)}`);
            console.log(JSON.stringify({ startedAt, finishedAt: new Date().toISOString(), iterations,
                executablePath: chrome, browserVersion, benchmarkURL, ...state }));
            break;
        }
        await sleep(Math.min(1000, remaining()));
    }
} finally {
    failPending(new Error("Speedometer finished"));
    if (socket) socket.close();
    if (child?.pid) {
        try { process.kill(-child.pid, "SIGTERM"); } catch {}
        await sleep(500);
        try { process.kill(-child.pid, "SIGKILL"); } catch {}
    }
    await rm(profile, { recursive: true, force: true });
}
JAVASCRIPT
