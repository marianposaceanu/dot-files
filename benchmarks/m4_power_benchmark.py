#!/usr/bin/env python3
"""Measure whole-system battery draw during an idle and SHA-256 workload phase."""

import argparse
import datetime as dt
import json
import plistlib
import statistics
import subprocess
import time
from pathlib import Path


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


def sample_phase(duration, interval, command=None):
    started = time.monotonic()
    process = (
        subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if command
        else None
    )
    samples = []
    while True:
        samples.append(battery_state())
        elapsed = time.monotonic() - started
        if process:
            if process.poll() is not None:
                break
        elif elapsed >= duration:
            break
        time.sleep(min(interval, max(0, duration - elapsed)))

    output = ""
    if process:
        output = process.communicate()[0]
    elapsed = time.monotonic() - started
    return summarize(samples, elapsed), output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("normal", "low"))
    parser.add_argument("--idle-seconds", type=int, default=90)
    parser.add_argument("--warmup-seconds", type=int, default=60)
    parser.add_argument("--load-seconds", type=int, default=180)
    parser.add_argument("--sample-seconds", type=int, default=5)
    args = parser.parse_args()

    expected_mode = 0 if args.mode == "normal" else 1
    actual_mode = battery_low_power_mode()
    if actual_mode != expected_mode:
        raise SystemExit(
            f"Expected battery lowpowermode={expected_mode}, found {actual_mode}. "
            "Change it in System Settings; this script never changes power settings."
        )

    if battery_state()["current_mA"] >= 0:
        raise SystemExit("The Mac must be discharging on battery power")

    idle, _ = sample_phase(args.idle_seconds, args.sample_seconds)
    workload = [
        "openssl", "speed", "-elapsed",
        "-seconds", str(args.warmup_seconds + args.load_seconds),
        "-bytes", "8192", "-evp", "sha256",
    ]
    process = subprocess.Popen(
        workload,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    warmup, _ = sample_phase(args.warmup_seconds, args.sample_seconds)
    if process.poll() is not None:
        raise SystemExit("OpenSSL exited during the telemetry warmup")
    load, _ = sample_phase(args.load_seconds, args.sample_seconds)
    openssl_output = process.communicate()[0]

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
    output = Path(__file__).parent / "results" / (
        f"m4-power-{args.mode}-{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}.json"
    )
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({
        "result": str(output),
        "idle_average_W": idle["average_power_W"],
        "load_average_W": load["average_power_W"],
        "load_energy_Wh": load["estimated_energy_Wh_from_samples"],
        "capacity_energy_Wh": load["estimated_energy_Wh_from_capacity"],
        "openssl_result": openssl_output.strip().splitlines()[-1],
    }, indent=2))


if __name__ == "__main__":
    main()
