# AGENTS Notes

## What this repo is
- Personal dotfiles repo (not an app/library project): there is no build, lint, typecheck, test, or CI workflow to run.
- Main editable configs live at repo root (`.vimrc`, `.zshrc`, `.tmux.conf`, `.alacritty.yml`, `.gitconfig`).

## High-impact structure
- Vim plugin code under `.vim/pack/**` is mostly Git submodules (third-party upstream code), not first-party config.
- First-party Vim customizations are primarily `.vimrc`, `.vim/plugin/*.vim`, `.vim/colors/*.vim`, and `.vim/pack/local/opt/**`.

## Commands agents should use
- After clone, initialize plugins/submodules: `git submodule update --init`.
- Update submodules from `.gitmodules` paths (safer than `git submodule foreach git pull origin master`, which fails for non-`master` plugins).
- Remove a submodule with repo script (preferred over manual steps): `./bootstrap/remove_submodule.sh <submodule-path>`.

## Editing guardrails
- Do not hand-edit files inside plugin submodules unless the task is explicitly to patch vendored plugin code.
- For plugin upgrades/additions/removals, use submodule workflows (`git submodule ...`) and commit pointer/`.gitmodules` changes.
