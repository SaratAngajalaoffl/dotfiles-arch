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
| `theme`    | `~/.config/theme` + `~/.local/bin/*` (theme switcher, see Theming below) |

(Not exhaustive — run `git submodule status` for the full list; most app submodules follow the `config:~/.config/<app>` pattern from the "Adding a new app" steps.)

### Secrets

Any app submodule that needs an API key or similar credential declares it in a `.secrets` file at the submodule root — a plain-text manifest of `label:attrs` pairs (one per line, same shape as `.links`), where `attrs` is the exact attribute list `secret-tool` needs, e.g.:

```
Spotify Soloist API key:service spotify-soloist key api-key
```

`install.sh` reads every submodule's `.secrets` after installing packages, checks each via `secret-tool lookup <attrs>`, and for anything missing, prompts `enter it now? [Y/n]` and runs `secret-tool store --label="<label>" <attrs>` (both reads pinned to `/dev/tty` so they don't collide with the `.secrets` file being parsed). If any secret is still unset after prompting, install.sh exits non-zero listing what's missing — a fresh install can't silently run without them.

Secrets never live in this repo or any submodule as files — only the gnome-keyring entry does, keyed by whatever `service`/`key` (or similar) attributes the submodule's scripts look up at runtime. Because the manifest splits on the *first* colon per line (same as `.links`), a label must not itself contain a colon.

Submodules using this: `systemd` (Spotify Soloist API key), `eww` (Spotify search Client ID/Secret), `pi-agent` (per-provider API keys).

### Manual setup notes

A submodule can also drop a `.setup` file at its root — free-form text for steps that can't be automated (pairing a device, running a one-time wizard). `install.sh` collects and prints every submodule's `.setup` under "manual setup required" at the end of a run. Don't duplicate secret-prompting instructions here — that's what `.secrets` is for; `.setup` is for what's left after secrets are handled.

### Theming

`theme/config/themes/<name>/` holds one directory per theme (`catppuccin-mocha` is the default — matches what was previously hardcoded per-app; `catppuccin-macchiato` is a hand-built extra). The rest (`catppuccin-latte`, `tokyo-night`, `nord`, `gruvbox`, `kanagawa`, `rose-pine`, `everforest`, and a dozen more) are ported from [basecamp/omarchy](https://github.com/basecamp/omarchy) (MIT licensed): each one's palette comes from omarchy's `themes/<name>/colors.toml`, mapped onto our 26-key Catppuccin-style slots (see `gen_theme.py` approach — omarchy's `red`/`bright_red`/`magenta`/etc. get matched to `rosewater`/`flamingo`/`pink`/... by hue, `background`/`dark_background`/`darker_background`/`lighter_background` become `base`/`mantle`/`crust`/`surface0-2`), and its wallpaper is one of omarchy's own bundled images, re-encoded to JPEG. Each theme directory contains:

- `theme.conf` — `THEME_NAME`, `THEME_MODE` (dark/light), `QT_SCHEME` (which `qt5ct`/`qt6ct` color file to select)
- `waybar-colors.css`, `kitty-theme.conf`, `rofi-colors.rasi`, `dunstrc`, `hyprland-colors.lua`, `nvim-colors.lua` — full themed files for each app
- `backgrounds/` — one or more wallpapers, committed to the repo. With 2+ backgrounds, the first (alphabetically) is used 7 AM-7 PM and the second at night.

The consuming submodules (`waybar`, `kitty`, `rofi`, `dunst`) gitignore their theme-owned file (`config/colors.css`, `config/current-theme.conf`, `config/colors.rasi`, `config/dunstrc`) — these are symlinks to the active theme, not tracked content. `hypr` gitignores `config/conf/hyprland/colors.lua` the same way; `look_and_feel.lua` requires it for border colors. `nvim` gitignores `config/lua/config/theme-colors.lua` the same way; the `catppuccin/nvim` colorscheme plugin (`nvim/config/lua/plugins/colorscheme.lua`) requires it — falling back to a hardcoded default flavour if the file is absent — and returns `{ mode, palette }` (the palette uses catppuccin's own key names, which is what each theme's `waybar-colors.css` already provides) applied via `color_overrides`; picking up a new theme requires reopening nvim. `qt5ct`/`qt6ct` are untouched by symlinks — `theme-set.sh` just rewrites the `color_scheme_path` line in `qt5ct.conf`/`qt6ct.conf` to point at the theme's declared `QT_SCHEME` file (those per-accent files already live in `qt5ct/config/colors/` and `qt6ct/config/colors/`, committed normally).

```bash
# Switch theme (also reloads waybar/dunst, sets the wallpaper, reloads Hyprland)
theme-set.sh <theme-name>

# Rofi picker over available themes, bound to SUPER + CTRL + SPACE
theme-menu.sh
```

`~/.config/theme/current` is a symlink to the active theme directory, repointed by `theme-set.sh`. `install.sh` bootstraps the default theme automatically on a fresh install if no theme has been set yet — it never overrides an already-chosen theme on a subsequent run.

To add a new theme: copy an existing `theme/config/themes/<name>/` directory, edit `theme.conf` and the per-app files, drop wallpaper(s) into `backgrounds/`, and (if using a new Qt accent) add matching color files under `qt5ct/config/colors/` and `qt6ct/config/colors/`.

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
   If the app needs credentials, add a `.secrets` manifest too (see Secrets above); for anything else manual, add a `.setup` file.
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

`packages` at the repo root declares system dependencies in up to four sections: `pacman:`, `aur:`, `rustup:`, and `npm:`. `install.sh` runs, in order: `sudo pacman -S --needed --noconfirm` for official packages, `yay`/`paru -S --needed --noconfirm` for AUR packages (auto-detects whichever helper is installed), `rustup toolchain install --no-self-update <name>` for each `rustup:` entry, and `npm install -g <name>` for each `npm:` entry.

`rustup:` entries are toolchain names (e.g. `stable`), not components or targets — this exists for tools (like `eww`) whose upstream recommends building against a rustup-managed toolchain rather than the distro's `rust` package. `rustup` itself must be declared under `pacman:` (it's an official Arch package); `install.sh` errors out if `rustup:` entries are present but the `rustup` binary isn't found. Likewise `npm:` entries require `npm` already on `PATH` (this repo doesn't manage a Node install — the machine's own npm/nvm setup provides it); `install.sh` errors out if `npm:` entries are present but `npm` isn't found.

To add a package/toolchain/global: add its name under the relevant section and commit. Only add a `rustup:`/`npm:` section when something actually needs it — don't add empty sections speculatively.

`pacman` must be available before running `install.sh` — the script will exit with a clear error if it isn't found.
