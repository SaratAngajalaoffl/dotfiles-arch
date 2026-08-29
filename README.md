# dotfiles-arch

Personal Arch Linux dotfiles, split into one git repo per application and wired together here as submodules. This is the parent repo — it owns bootstrapping (`install.sh`), the system package list (`packages`), and the submodule declarations. It never hard-codes an app's config paths; that lives in each submodule's own `.links` manifest.

## Layout

| Path         | Purpose                                                              |
| ------------ | --------------------------------------------------------------------- |
| `install.sh` | Bootstraps everything: submodules, packages, symlinks, secrets       |
| `packages`   | System dependencies (`pacman:`, `aur:`, `rustup:`, `npm:`)           |
| `<appname>/` | One submodule per app, each a standalone `dotfiles-<appname>` repo   |
| `docs/adr/`  | Architecture decision records                                        |

Current submodules: `applications`, `atuin`, `bin`, `claude`, `dunst`, `eww`, `fastfetch`, `hypr`, `kitty`, `lazygit`, `nvim`, `pi-agent`, `qt5ct`, `qt6ct`, `rofi`, `scripts`, `systemd`, `theme`, `tmux`, `waybar`, `zsh` — run `git submodule status` for exact commits.

## Bootstrap

```bash
git clone --recurse-submodules git@github.com:SaratAngajalaoffl/dotfiles-arch.git
cd dotfiles-arch
./install.sh
```

`install.sh`, in order:

1. Initializes submodules (`git submodule update --init --recursive`)
2. Installs packages from `packages` — `pacman`, then AUR via whichever of `yay`/`paru` is installed, then `rustup` toolchains, then global `npm` packages
3. Reads every submodule's `.secrets` manifest and prompts for anything missing, storing it in the system keyring via `secret-tool` — credentials never live in git
4. Reads every submodule's `.links` manifest and symlinks `source` → `target`, backing up any pre-existing file to `<target>.bak`
5. Prints any submodule's `.setup` notes under "manual setup required" (device pairing, one-time wizards — whatever can't be automated)
6. Bootstraps the default theme on a fresh install, without overriding one you've already chosen

## Theming

`theme/` is the central theme system consumed by `waybar`, `kitty`, `rofi`, `dunst`, `hypr`, `nvim`, and Qt apps — one directory per theme (Catppuccin flavors, plus a set ported from [omarchy](https://github.com/basecamp/omarchy)).

```bash
theme-set.sh <theme-name>   # switch theme, reload the affected apps
theme-menu.sh                # rofi picker, bound to SUPER+CTRL+SPACE
```

## Secrets

No credential ever lives in this repo or any submodule as a file. A submodule that needs one declares it in a `.secrets` manifest; `install.sh` reads/writes it through `secret-tool` (gnome-keyring) at install time.

## Adding an app

See `CLAUDE.md` for the full steps: create a `dotfiles-<appname>` repo, add a `.links` manifest (and `.secrets`/`.setup` if needed), register it as a submodule here.

## ADRs

- [0001](docs/adr/0001-multi-repo-dotfiles-architecture.md) — multi-repo + submodules over Stow or a flat repo
- [0002](docs/adr/0002-from-scratch-neovim-config.md) — from-scratch Neovim over a starter distro
- [0003](docs/adr/0003-ai-agent-popup-architecture.md) — AI agent popup architecture
- [0004](docs/adr/0004-ai-commit-assistant-backend-selection.md) — AI commit assistant backend selection
- [0005](docs/adr/0005-pi-agent-anera-only-provider.md) — pi-agent anera-only provider
