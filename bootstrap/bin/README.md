# macOS arm64 binary

Build the self-contained installer from the checked-in Clojure sources:

```sh
bb bootstrap/binary/build.clj
```

The output is `dotfiles-bootstrap-macos-aarch64` with a matching, standard
`shasum -a 256 -c` checksum file. It embeds the pinned Babashka arm64 runtime
and does not need Babashka, Clojure, or a JVM at runtime. Generated binaries
stay out of Git history and are distributed as GitHub release assets.

The builder records the pinned Babashka version and checksum. The embedded
runtime is distributed under the
[Eclipse Public License 1.0](https://github.com/babashka/babashka/blob/master/LICENSE),
with source available from the
[Babashka repository](https://github.com/babashka/babashka).
