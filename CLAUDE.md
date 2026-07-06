# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is the **parent repo** (`dotfiles-arch`) for a multi-repo dotfiles system. It lives at `~/dotfiles-arch` during incremental migration (eventually `~/dotfiles`). It manages app configs via git submodules. Each submodule is a standalone **app repo** (e.g., `dotfiles-zsh`, `dotfiles-nvim`) checked out at `~/dotfiles-arch/<appname>`.

The parent repo owns `install.sh`, `packages`, and the submodule declarations — it never hard-codes config paths. All symlink mappings live in each app repo's `.links` manifest.

The legacy flat repo (`arch-dotfiles-v2` at `~/dotfiles`) still manages unmigrated configs (hypr, waybar, containers, etc.) until each is moved into an app repo.

## Key commands

```bash
# Bootstrap / apply all symlinks (also inits submodules)
./install.sh

# Pull latest commits from an app repo into this parent
git submodule update --remote <submodule-name>
# Then commit the new SHA so the parent tracks the update
git add <submodule-name> && git commit -m "Update <submodule-name> submodule"

# Initialize submodules on a fresh clone (install.sh does this too)
git submodule update --init --recursive
```

## Architecture

### Symlink system

Each app submodule contains a `.links` file — a plain-text manifest of `source:target` pairs (one per line, `~` expands to `$HOME`). `install.sh` reads every submodule's `.links` and creates the declared symlinks, backing up pre-existing files to `<target>.bak`.

Two guards run before each `ln -s`:

- **Circular source repair**: if `src_path` inside the submodule is itself a symlink (bad state from a previous run), it is replaced with the content from `<src>.bak`.
- **Same-path guard**: if `src_path` and `tgt` resolve to the same file via `realpath` (can happen when the target directory is symlinked into the submodule), the entry is skipped.

Current submodules and their targets:

| Submodule  | Target                            |
| ---------- | --------------------------------- |
| `zsh`      | `~/.zshrc`                        |
| `nvim`     | `~/.config/nvim`                  |
| `lazygit`  | `~/.config/lazygit/config.yml`    |
| `bin`      | `~/.local/bin/*` (per-file links) |

### Adding a new app

1. Create a GitHub repo named `dotfiles-<appname>`.
2. Inside `~/dotfiles-arch`, create the submodule directory and initialise a git repo:
   ```bash
   mkdir <appname> && cd <appname> && git init
   ```
3. Create a `config/` subdirectory (this is what gets symlinked to the target path) and a `.links` manifest at the repo root:
   ```
   config:~/.config/<appname>
   ```
4. Set the remote, commit, and push:
   ```bash
   git remote add origin git@github.com:SaratAngajalaoffl/dotfiles-<appname>.git
   git add . && git commit -m "init"
   git push -u origin main
   ```
5. Register the directory as a submodule in the parent repo:
   ```bash
   # Back in ~/dotfiles-arch
   git config --file .gitmodules submodule.<appname>.path <appname>
   git config --file .gitmodules submodule.<appname>.url git@github.com:SaratAngajalaoffl/dotfiles-<appname>.git
   git submodule init <appname>
   git add .gitmodules <appname>
   git commit -m "Add <appname> submodule"
   ```
6. Re-run `./install.sh`.

### Platform-specific config

Shared app repos use runtime OS guards (`$OSTYPE` / `uname`) inside config files rather than separate per-OS files. This keeps changes in sync across macOS and Arch Linux (the other parent repo is `dotfiles-macos`, at `~/dotfiles` on that machine).

### Neovim layout (`nvim/config/`)

Built from scratch with lazy.nvim — no starter distribution.

- `lua/config/` — `options.lua`, `keymaps.lua`, `lazy.lua` (bootstrap)
- `lua/plugins/` — one file per plugin spec (`git.lua`, `neo-tree.lua`, `snacks.lua`, `which-key.lua`)

Plugin updates: `:Lazy update` inside Neovim. Lock file is `lazy-lock.json`.

## ADRs

- **ADR 0001** (`docs/adr/0001-...`): Why multi-repo with submodules over a flat repo, Stow, or per-OS files.
- **ADR 0002** (`docs/adr/0002-...`): Why from-scratch Neovim over NVChad/LazyVim/AstroNvim.

### packages

`packages` at the repo root declares Arch packages in two sections (`pacman:` and `aur:`). `install.sh` runs `sudo pacman -S --needed --noconfirm` for official packages and `yay` or `paru -S --needed --noconfirm` for AUR packages (auto-detects whichever helper is installed).

To add a package: add its name under the relevant section and commit.

`pacman` must be available before running `install.sh` — the script will exit with a clear error if it isn't found.
