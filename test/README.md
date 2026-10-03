# Clojure tests

These tests run with Babashka's built-in `clojure.test`; no JVM test runner or
additional dependencies are required. Follow the
[Practicalli unit-testing guide](https://practical.li/clojure/testing/unit-testing/writing-unit-tests/).

## Run tests

From the repository root:

```sh
bb test                                      # all Clojure tests
bb test:unit                                 # bootstrap library tests
bb test:integration                          # installer and editor integration tests
bb test bootstrap.lib.ruby-warnings-test      # one namespace
bb test integration.install-macos-test integration.editor-config-test
```

`bb.edn` adds the repository and `test/` to the classpath. `test.runner` loads the
selected namespaces, prints the standard test summary, and exits nonzero on a
failure or error. Unknown namespace names fail rather than silently running
nothing. Test files declare tests; requiring them does not execute the suite or
exit the process.

`bb bootstrap/checks/check_configs.clj` runs both suites alongside configuration
checks. Successful test output is captured; failure output is shown.

The benchmark checks remain a separate Bash entry point:

```sh
bash test/benchmarks_test.sh
```

## Organization and conventions

- Library tests mirror the source path, such as
  `bootstrap/lib/ruby_warnings.clj` → `test/bootstrap/lib/ruby_warnings_test.clj`.
  The namespace adds `-test` to the source namespace.
- Installer and editor integration tests live in `test/integration/`. They
  exercise commands and real configuration behavior instead of pretending these
  checks are isolated function tests.
- Start files with `ns`. Refer only the `clojure.test` macros needed, and require
  the namespace under test with a meaningful alias.
- Name `deftest` forms after the function or behavior being tested, ending in
  `-test`. Use `testing` to describe a scenario and group related assertions.
- Use `is` for assertions, with expected values first in equality checks. Use
  `are` for repeated assertions that differ only in their data; keep stateful
  scenarios and setup explicit.
- Use `use-fixtures :each` for setup and cleanup. `test.support/with-temp-dir`
  guarantees each integration test gets a fresh directory and removes it in a
  `finally` block. Installer setup is a separate composed fixture.
- Scope replacements with `with-redefs`, output capture with `binding`, and
  mutable observation state with local atoms. Keep test data and helpers private
  unless another namespace needs them.

The installer fixtures simulate Homebrew, RVM, and other setup commands in a
throwaway home directory. They do not install packages or modify the real home.
Editor tests require Vim, Git, ripgrep, bat, and initialized Vim plugins. Library
tests need Babashka; progress reporting also launches a short Babashka child.

## REPL workflow

Start `bb repl` from the repository root, then load and run tests explicitly:

```clojure
(require '[clojure.test :as test]
         '[bootstrap.lib.ruby-warnings-test])

(test/run-tests 'bootstrap.lib.ruby-warnings-test)
(test/test-vars [#'bootstrap.lib.ruby-warnings-test/repair-command-test])
```

Use `:reload` when requiring an edited namespace. The shared runner handles CLI
exit codes; individual test namespaces remain safe to load into a REPL.
