# M4 MacBook Air Low Power Mode benchmark

- Date: 2026-07-31
- Machine: MacBook Air `Mac16,12`, Apple M4, 4 performance + 6 efficiency cores, 16 GB
- OS: macOS 26.6 (`25G72`)
- Power: battery, 83% at the normal run and 82% at the Low Power run
- Browser: Google Chrome 150.0.7871.188, headless, fresh profile per run
- Benchmark: Speedometer 3.1, five iterations
- Native workload: OpenSSL 3.6.3 SHA-256, three five-second samples

## Controls

- The same Chrome executable, browser build, V8 build, command-line arguments,
  benchmark URL, viewport, and isolated-profile setup were used for both modes.
- Normal mode was selected as **Never** and Low Power Mode as **Only on Battery**
  in System Settings. `pmset -g custom` verified the effective value before each
  run. No privileged `pmset` setter was used.
- `pmset -g therm` reported no thermal or performance warnings before either run.
- The official Speedometer aggregate is reported. A separate warm median excludes
  the first iteration in each mode, which was visibly cold.

## Raw results

### Normal mode

SHA-256 8192-byte throughput, kB/s:

```text
3,353,713.23
3,362,220.07
3,363,868.32
```

Speedometer iteration scores:

```text
33.57849164471205
58.09206459812502
58.34821138875800
58.31134810232748
58.610525843344995
```

Official aggregate: `53.4 ± 14`

### Low Power Mode

SHA-256 8192-byte throughput, kB/s:

```text
1,590,906.10
1,590,919.23
1,590,984.90
```

Speedometer iteration scores:

```text
23.62447153828941
28.562136334100156
30.66746695456233
30.683329187965818
30.903012142231564
```

Official aggregate: `28.9 ± 3.8`

## Derived comparison

| Measurement | Normal | Low Power | Throughput loss | Normal / low |
| --- | ---: | ---: | ---: | ---: |
| SHA-256 median, kB/s | 3,362,220.07 | 1,590,919.23 | 52.68% | 2.113× |
| Speedometer aggregate | 53.4 | 28.9 | 45.88% | 1.848× |
| Speedometer warm median | 58.3298 | 30.6754 | 47.41% | 1.902× |

For a fixed amount of work, the reciprocal ratios imply approximately 111% more
time for this SHA-256 workload and 90% more time for warm browser work. These are
workload-specific measurements, not a claim that every interaction takes twice
as long.

## Reproduce

The checked-in harness refuses to change power settings. Select the mode in
System Settings and run each half separately:

```sh
./benchmarks/m4_low_power_benchmark.sh normal
./benchmarks/m4_low_power_benchmark.sh low
```

See `benchmarks/speedometer_runner.mjs` for the exact browser flags and DevTools
automation.

## Whole-system power follow-up

A second batch measured battery draw after Chrome had been removed. It exercises
the same native single-thread SHA-256 workload; it does not measure browser power.
The checked-in `m4_power_benchmark.py` refuses to run unless the requested mode
matches the effective battery setting.

### Method

- Battery only, approximately 79–77%, automatic display brightness enabled
- Battery cycle count: 13; reported full-charge capacity: approximately 4,684 mAh
- 90 seconds idle sampling
- 60 seconds loaded warmup to allow the battery gauge to reach steady state
- 180 seconds measured OpenSSL SHA-256 load
- One `AppleSmartBattery` sample every five seconds via unprivileged `ioreg`
- Whole-system watts: `abs(InstantAmperage_mA) × Voltage_mV / 1,000,000`
- Primary energy estimate: average sample watts × elapsed time
- Raw-capacity energy retained only as a coarse cross-check

`powermetrics` was not used because it requires administrator access. Power-mode
changes used System Settings rather than a privileged `pmset` setter. The mode was
verified before each run and restored to **Only on Battery** afterward.

### Corrected steady-state results

| Measurement | Normal | Low Power |
| --- | ---: | ---: |
| Verified battery value | `lowpowermode=0` | `lowpowermode=1` |
| Idle average | 2.0297 W | 2.1265 W |
| Loaded average | 8.7811 W | 2.9132 W |
| Loaded sample count | 37 | 37 |
| Loaded elapsed time | 180.02 s | 180.03 s |
| Sample-integrated energy | 0.4391 Wh | 0.1457 Wh |
| Capacity-counter cross-check | 0.5016 Wh | 0.1975 Wh |
| SHA-256 throughput | 3,305,470.67 kB/s | 1,568,375.53 kB/s |

The corrected raw captures are:

- `m4-power-normal-20260731T100310Z.json`
- `m4-power-low-20260731T095511Z.json`

An exploratory pair without loaded warmup exposed delayed, stepwise battery-gauge
updates and was excluded. The 60-second warmup was added before collecting the
corrected pair.

### Derived power and energy comparison

- Whole-system loaded power reduction: **66.82%**
- Continuous-load runtime multiplier: **3.014×**
- SHA throughput loss in this pair: **52.55%** (normal is **2.108×** as fast)
- Relative energy for equal SHA work: **69.92%**
- Fixed-work energy saving: **30.08%**

Using a nominal 53.8 Wh full battery, the measured loaded averages extrapolate to
6.13 hours in normal mode and 18.47 hours in Low Power Mode. This is arithmetic
for an uninterrupted SHA workload, not a battery rundown or browsing-runtime
claim. Display, radio, video, network waits, idle periods, and background activity
change the result for ordinary web use.

### Reproduce the power batch

Select each mode in System Settings before its command. The script verifies the
setting but never changes it:

```sh
python3 benchmarks/m4_power_benchmark.py normal
python3 benchmarks/m4_power_benchmark.py low
```

The defaults are `--idle-seconds 90`, `--warmup-seconds 60`,
`--load-seconds 180`, and `--sample-seconds 5`. Every run writes a timestamped
JSON capture under `benchmarks/results/` containing all samples and OpenSSL output.
