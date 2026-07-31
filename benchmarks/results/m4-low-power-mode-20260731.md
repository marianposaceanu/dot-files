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
