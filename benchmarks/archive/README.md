# Legacy benchmarks archive

`benchmarks-shell-20261004.tar.gz` preserves all 27 tracked benchmark files plus
the Bash/Python regression harness (28 files) at dot-files commit `b8aad75`,
before the Clojure rewrite. Files were compared byte for byte against the archive
before replacing the scripts. Generated or ignored corpora are excluded.

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
