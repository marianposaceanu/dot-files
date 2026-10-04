# Legacy benchmarks archive

`benchmarks-shell-20261004.tar.gz` preserves the legacy shell scripts, their README,
and the regression harness from dot-files commit `b8aad75`, before the Clojure
rewrite. Historical profiles, telemetry, and other generated results are excluded;
their published measurements remain in Markdown reports under `../results/`.
The original full archive remains recoverable from Git history.

Verify the archive from this directory:

```sh
shasum -a 256 -c benchmarks-shell-20261004.tar.gz.sha256
```

Extract it into a fresh directory from the repository root:

```sh
legacy_dir=$(mktemp -d)
tar -xzf benchmarks/archive/benchmarks-shell-20261004.tar.gz -C "$legacy_dir"
```

These are historical sources. They include installation-changing workflows and
Python/Node dependencies described in the archived README. Active Clojure entry
points and their current dependencies are documented in `../README.md`.
