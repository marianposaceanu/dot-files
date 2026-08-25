# AGENTS Notes

## What this repo is
- Personal dotfiles repo, not an app/library project. There is no package build, lint, unit test suite, or CI workflow to run.
- Main first-party configs live at repo root: `.vimrc`, `.zprofile`, `.zshrc`, `.zlogin`, `.bashrc`, `.tmux.conf`, `.gitconfig`, and `.gitignore_global`.
- Additional first-party configs live in `bat/`, `ghostty/`, `bootstrap/`, `benchmarks/`, and `tutorials/`.

## High-impact structure
- Vim plugin code under `.vim/pack/bundles/**` is Git submodule/vendor code, not normal first-party config.
- First-party Vim customizations are primarily `.vimrc`, `.vim/plugin/*.vim`, `.vim/colors/*.vim`, and `.vim/pack/local/opt/**`.
- `Brewfile` is the Homebrew dependency source. `bb bootstrap/setup/install_brew_deps.clj` installs the same core tools used by the configs.
- `bb bootstrap/setup/link_configs.clj` creates symlinks into `$HOME` and backs up existing targets with `.backup.<timestamp>` suffixes.

## Verification
- For shell, Vim, or terminal config changes, prefer `bb bootstrap/checks/check_configs.clj`. It runs `bash -n` for repo scripts, loads `.vimrc` with Vim, and validates Ghostty config when `ghostty` is installed.
- For local environment/symlink health, use `bb bootstrap/checks/doctor.clj`. It is environment-dependent and may fail because the user's home directory is not linked or dependencies are missing.
- For Vim startup/performance work, use `./benchmarks/profile_vim_plugins.sh` or `./benchmarks/profile_vim_plugins_median.sh` when relevant.
- If a command depends on local macOS/Homebrew state and fails for missing tools, report that directly instead of treating it as a repo regression.

## Submodules
- After clone, initialize plugins/submodules with `bb bootstrap/submodules/update_submodules.clj`.
- Intentionally update plugin pointers with `bb bootstrap/submodules/update_submodules.clj --remote`; this changes tracked submodule commits.
- Update submodules from `.gitmodules` paths instead of assuming every plugin branch is `master`.
- Remove a submodule with the repo script: `bb bootstrap/submodules/remove_submodule.clj <submodule-path>`.

## Editing guardrails
- Do not hand-edit files inside `.vim/pack/bundles/**` unless the task explicitly asks to patch vendored plugin code.
- For plugin upgrades/additions/removals, use submodule workflows (`git submodule ...`) and include the related pointer/`.gitmodules` changes.
- Do not run `bb bootstrap/setup/link_configs.clj` unless the task is specifically about installing/linking dotfiles; it mutates files in `$HOME`.
