#!/usr/bin/env bash
# Battery telemetry and SHA-256 workload; Python 3 handles plist and JSON data.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }
exec python3 - "$SCRIPT_DIR" "$@" <<'PYTHON'
"""Measure whole-system battery draw during an idle and SHA-256 workload phase."""

import argparse
import datetime as dt
import json
import plistlib
import statistics
import subprocess
import time
from pathlib import Path
import sys
import tempfile

SCRIPT_DIR = Path(sys.argv.pop(1))


def battery_state():
    payload = subprocess.check_output(
        ["ioreg", "-r", "-n", "AppleSmartBattery", "-a"]
    )
    battery = plistlib.loads(payload)[0]
    current_ma = battery["InstantAmperage"]
    voltage_mv = battery["Voltage"]
    return {
        "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
        "monotonic": time.monotonic(),
        "current_mA": current_ma,
        "voltage_mV": voltage_mv,
        "power_W": abs(current_ma) * voltage_mv / 1_000_000,
        "raw_capacity_mAh": battery["AppleRawCurrentCapacity"],
        "raw_max_capacity_mAh": battery["AppleRawMaxCapacity"],
        "temperature_C": battery["Temperature"] / 100,
        "telemetry_system_load_mW": battery["PowerTelemetryData"]["SystemLoad"],
    }


def battery_low_power_mode():
    output = subprocess.check_output(["pmset", "-g", "custom"], text=True)
    in_battery = False
    for line in output.splitlines():
        if line.startswith("Battery Power:"):
            in_battery = True
        elif line.startswith("AC Power:"):
            in_battery = False
        elif in_battery and "lowpowermode" in line:
            return int(line.split()[-1])
    raise RuntimeError("Could not read battery Low Power Mode")


def summarize(samples, elapsed_seconds):
    watts = [sample["power_W"] for sample in samples]
    start = samples[0]
    finish = samples[-1]
    average_voltage = statistics.mean(sample["voltage_mV"] for sample in samples) / 1000
    capacity_delta = start["raw_capacity_mAh"] - finish["raw_capacity_mAh"]
    return {
        "elapsed_seconds": elapsed_seconds,
        "sample_count": len(samples),
        "average_power_W": statistics.mean(watts),
        "median_power_W": statistics.median(watts),
        "minimum_power_W": min(watts),
        "maximum_power_W": max(watts),
        "estimated_energy_Wh_from_samples": statistics.mean(watts) * elapsed_seconds / 3600,
        "capacity_delta_mAh": capacity_delta,
        "estimated_energy_Wh_from_capacity": capacity_delta * average_voltage / 1000,
        "start_capacity_mAh": start["raw_capacity_mAh"],
        "finish_capacity_mAh": finish["raw_capacity_mAh"],
        "samples": samples,
    }


def sample_phase(duration, interval, expected_mode, process=None):
    started = time.monotonic()
    samples = []
    while True:
        state = battery_state()
        if state["current_mA"] >= 0 or battery_low_power_mode() != expected_mode:
            raise SystemExit("Battery discharge or Low Power Mode changed during measurement")
        samples.append(state)
        elapsed = time.monotonic() - started
        if elapsed >= duration:
            break
        if process is not None and process.poll() is not None:
            raise SystemExit("OpenSSL exited before the measurement phase completed")
        time.sleep(min(interval, duration - elapsed))
    return summarize(samples, time.monotonic() - started)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("normal", "low"))
    parser.add_argument("--idle-seconds", type=int, default=90)
    parser.add_argument("--warmup-seconds", type=int, default=60)
    parser.add_argument("--load-seconds", type=int, default=180)
    parser.add_argument("--sample-seconds", type=int, default=5)
    args = parser.parse_args()

    if min(args.idle_seconds, args.warmup_seconds, args.load_seconds, args.sample_seconds) <= 0:
        parser.error("All durations and sampling intervals must be positive")

    expected_mode = 0 if args.mode == "normal" else 1
    actual_mode = battery_low_power_mode()
    if actual_mode != expected_mode:
        raise SystemExit(
            f"Expected battery lowpowermode={expected_mode}, found {actual_mode}. "
            "Change it in System Settings; this script never changes power settings."
        )

    if battery_state()["current_mA"] >= 0:
        raise SystemExit("The Mac must be discharging on battery power")

    idle = sample_phase(args.idle_seconds, args.sample_seconds, expected_mode)
    workload = [
        "openssl", "speed", "-elapsed",
        "-seconds", str(args.warmup_seconds + args.load_seconds),
        "-bytes", "8192", "-evp", "sha256",
    ]
    # Keep the process pipe drained without relying on a small output buffer.
    with tempfile.TemporaryFile(mode="w+t") as log:
        process = subprocess.Popen(workload, stdout=log, stderr=subprocess.STDOUT, text=True)
        try:
            warmup = sample_phase(args.warmup_seconds, args.sample_seconds, expected_mode, process)
            load = sample_phase(args.load_seconds, args.sample_seconds, expected_mode, process)
            if process.wait(timeout=30) != 0:
                raise SystemExit("OpenSSL workload failed")
            log.seek(0)
            openssl_output = log.read()
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()

    result = {
        "mode": args.mode,
        "battery_lowpowermode": actual_mode,
        "started_at": idle["samples"][0]["timestamp"],
        "finished_at": load["samples"][-1]["timestamp"],
        "sample_interval_seconds": args.sample_seconds,
        "workload_command": workload,
        "openssl_output": openssl_output,
        "idle": idle,
        "load_warmup": warmup,
        "load": load,
    }
    output = SCRIPT_DIR / "results" / (
        f"m4-power-{args.mode}-{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}.json"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({
        "result": str(output),
        "idle_average_W": idle["average_power_W"],
        "load_average_W": load["average_power_W"],
        "load_energy_Wh": load["estimated_energy_Wh_from_samples"],
        "capacity_energy_Wh": load["estimated_energy_Wh_from_capacity"],
        "openssl_result": openssl_output.strip().splitlines()[-1] if openssl_output.strip() else "",
    }, indent=2))


if __name__ == "__main__":
    main()

PYTHON
