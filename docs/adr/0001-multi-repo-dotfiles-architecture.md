# ADR 0001: Multi-repo dotfiles architecture

## Status
Accepted

## Context
Config needs to be managed across two machines: a macOS laptop and an Arch Linux desktop. Some apps (zsh, nvim, tmux) are shared; others (skhd, hypr) are platform-specific. A single flat repo makes it hard to share only the relevant subset of config with each machine.

## Decision
Use two parent repos (`dotfiles-macos`, `dotfiles-arch`) each living at `~/dotfiles` on their respective machine. Shared and platform-specific app configs each live in their own standalone repo (`dotfiles-zsh`, `dotfiles-nvim`, etc.) and are included as git submodules in whichever parent repos need them.

Each app repo ships a `.links` plain-text manifest at its root declaring `source:target` symlink pairs (one per line, paths relative to repo root and `~` for home). The parent repo's `install.sh` iterates submodules, reads each `.links`, and creates the symlinks — backing up any pre-existing file to `<target>.bak` before symlinking.

Platform-specific config within a shared app repo is handled via runtime OS guards (`$OSTYPE`/`uname`) inside the config file itself, not via separate files, so that changes made on either machine sync to the other through git.

## Alternatives considered
- **Single repo with directories per machine** — simpler but cannot share app repos independently; adding a third machine means duplicating config.
- **GNU Stow** — good tool but derives paths from directory structure rather than an explicit manifest; less obvious to readers unfamiliar with Stow conventions.
- **Independent repos linked by a script (no submodules)** — avoids submodule complexity but loses the parent repo's ability to pin app repos to specific commits.
- **Per-OS files (aliases-macos.zsh, aliases-arch.zsh)** — explicit but splits changes across files; a change on one machine doesn't propagate to the other without manual merging.

## Consequences
- Adding a new app requires creating a new repo, adding `.links`, and registering it as a submodule in the relevant parent repo(s).
- Submodule updates must be committed in the parent repo to take effect (`git submodule update --remote` + commit).
- The install script must be re-run after adding or updating submodules to create new symlinks.
