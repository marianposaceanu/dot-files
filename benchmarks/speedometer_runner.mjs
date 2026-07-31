#!/usr/bin/env node

import { mkdtemp, rm } from "node:fs/promises";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const chrome = process.env.CHROME_BIN ||
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const iterations = Number(process.argv[2] || 5);
const port = 19000 + Math.floor(Math.random() * 1000);
const profile = await mkdtemp(join(tmpdir(), "speedometer-profile-"));
const benchmarkURL =
    `https://browserbench.org/Speedometer3.1/?startAutomatically&iterationCount=${iterations}&viewport=1200x900`;

if (!Number.isInteger(iterations) || iterations < 1) {
    throw new Error("Iteration count must be a positive integer");
}

const child = spawn(chrome, [
    "--headless=new",
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    "--window-size=1200,900",
    "--no-first-run",
    "--disable-default-apps",
    "--disable-extensions",
    "--disable-sync",
    "--disable-component-update",
    "--disable-background-timer-throttling",
    "--disable-backgrounding-occluded-windows",
    "--disable-renderer-backgrounding",
    "about:blank",
], { stdio: ["ignore", "ignore", "pipe"], detached: true });

let chromeError = "";
child.stderr.on("data", (chunk) => { chromeError += chunk.toString(); });

async function waitForEndpoint() {
    for (let attempt = 0; attempt < 100; attempt++) {
        try {
            const response = await fetch(`http://127.0.0.1:${port}/json/version`);
            if (response.ok) return response.json();
        } catch {}
        await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error(`Chrome DevTools endpoint did not start: ${chromeError}`);
}

let socket;
let nextID = 1;
const pending = new Map();

function request(method, params = {}) {
    const id = nextID++;
    socket.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

async function evaluate(expression) {
    const response = await request("Runtime.evaluate", {
        expression,
        returnByValue: true,
        awaitPromise: true,
    });
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
}

async function run() {
    const browserVersion = await waitForEndpoint();
    const targetResponse = await fetch(
        `http://127.0.0.1:${port}/json/new?${encodeURIComponent(benchmarkURL)}`,
        { method: "PUT" },
    );
    const target = await targetResponse.json();
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
        socket.addEventListener("open", resolve, { once: true });
        socket.addEventListener("error", reject, { once: true });
    });
    socket.addEventListener("message", (event) => {
        const message = JSON.parse(event.data);
        if (!message.id || !pending.has(message.id)) return;
        const waiter = pending.get(message.id);
        pending.delete(message.id);
        if (message.error) waiter.reject(new Error(message.error.message));
        else waiter.resolve(message.result);
    });
    await request("Runtime.enable");

    const deadline = Date.now() + 15 * 60 * 1000;
    while (Date.now() < deadline) {
        const state = await evaluate(`JSON.stringify({
            ready: document.readyState,
            hash: location.hash,
            score: document.querySelector('#result-number')?.textContent.trim() || '',
            confidence: document.querySelector('#confidence-number')?.textContent.trim() || '',
            valid: document.querySelector('#summary')?.classList.contains('valid') || false,
            progress: document.querySelector('#progress-completed')?.value || 0,
            progressMax: document.querySelector('#progress-completed')?.max || 0,
            iterationScores: globalThis.benchmarkClient?._measuredValuesList?.map((value) => value.score) || [],
            userAgent: navigator.userAgent,
            viewport: [innerWidth, innerHeight]
        })`);
        const parsed = JSON.parse(state);
        if (parsed.hash === "#summary" && parsed.score) {
            if (!parsed.valid || parsed.score === "Error") {
                throw new Error(`Invalid Speedometer result: ${state}`);
            }
            return {
                executablePath: chrome,
                browserVersion,
                benchmarkURL,
                ...parsed,
            };
        }
        await new Promise((resolve) => setTimeout(resolve, 1000));
    }
    throw new Error("Speedometer timed out");
}

try {
    const startedAt = new Date().toISOString();
    const result = await run();
    console.log(JSON.stringify({
        startedAt,
        finishedAt: new Date().toISOString(),
        iterations,
        ...result,
    }));
} finally {
    if (socket) socket.close();
    try { process.kill(-child.pid, "SIGTERM"); } catch {}
    await new Promise((resolve) => setTimeout(resolve, 500));
    try { process.kill(-child.pid, "SIGKILL"); } catch {}
    await rm(profile, { recursive: true, force: true });
}
