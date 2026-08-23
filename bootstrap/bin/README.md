# macOS arm64 binary

Build the self-contained installer from the checked-in Clojure sources:

```sh
bb bootstrap/binary/build.clj
```

The output is `dotfiles-bootstrap-macos-aarch64` with a matching `.sha256`
file. It embeds the pinned Babashka arm64 runtime and does not need Babashka,
Clojure, or a JVM at runtime. Generated binaries stay out of Git history; use a
GitHub release asset for distribution.

The embedded Babashka runtime is distributed under the
[Eclipse Public License 1.0](https://github.com/babashka/babashka/blob/v1.13.219/LICENSE).
Its source is available from the
[Babashka v1.13.219 repository](https://github.com/babashka/babashka/tree/v1.13.219).
