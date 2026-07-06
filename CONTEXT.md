# Dotfiles Context

## Glossary

**App repo** — a standalone git repository containing the configuration for a single application (e.g., `dotfiles-zsh`, `dotfiles-nvim`). App repos are the source of truth for their config and are shared across machines.

**Parent repo** — a machine-specific top-level repository (`dotfiles-macos` or `dotfiles-arch`) that declares which app repos are active on that machine via git submodules, and owns the install script, package manifest, and submodule declarations. On Arch during incremental migration, the parent repo lives at `~/dotfiles-arch`; the legacy flat repo (`arch-dotfiles-v2`) remains at `~/dotfiles` until all configs are migrated.

**Submodule** — the mechanism by which a parent repo references an app repo at a specific commit SHA. Each machine's parent repo decides which app repos (submodules) it includes.

**Manifest** — a file inside each app repo that declares the `source → target` symlink mappings for that app's config files. The parent install script reads each submodule's manifest and applies it; the parent itself does not hard-code any paths.

**Brewfile** — (macOS parent only) a file at the parent repo root that declares all Homebrew packages (formulae, casks, taps) for that machine. The install script runs `brew bundle --no-upgrade` against it, installing missing packages without upgrading existing ones.

**packages** — (Arch parent only) a file at the parent repo root with `pacman:` and `aur:` sections declaring official and AUR packages. The install script runs `sudo pacman -S --needed` and `yay`/`paru -S --needed` (auto-detected) to install missing packages.

**Install script** — a script inside each parent repo that: (1) checks the platform package manager is present (`brew` on macOS, `pacman` on Arch); (2) iterates submodules, reads each manifest, and creates the declared symlinks; (3) installs missing packages from the package manifest. Before creating a symlink it repairs any `src_path` that is itself a symlink and skips creation if `src_path` and `tgt` resolve to the same file.

**OS guard** — a runtime check (via `$OSTYPE` or `uname`) inside a shared config file that conditionally applies platform-specific settings. Used instead of separate per-OS files so that changes sync across machines through git.

**Bootstrap** — the sequence of steps to go from a fresh machine to a fully configured one: clone the parent repo, run the install script. On macOS: install Homebrew first, clone to `~/dotfiles`. On Arch: clone to `~/dotfiles-arch`, ensure `yay` or `paru` is available if any AUR packages are listed. The install script inits submodules, creates symlinks (backing up any pre-existing file to `<target>.bak`), then installs packages from the manifest.

**AI commit assistant** — a standalone script (`aic`) in the `bin` app repo that generates a Conventional Commits message for the current staged diff by delegating to an AI CLI backend (claude or pi, selected via `--agent`), then confirms before committing. `claude` backend uses Anthropic models; `pi` backend uses the anera custom provider (`aneramodel` via OpenAI-compatible schema). Supports a `--generate` flag that prints the message and exits without prompting, used by the lazygit integration. In lazygit, pressing `C` in the files panel runs `aic --generate` via a `menuFromCommand` prompt, lets the user select and edit the message in lazygit's native UI, then commits — no TTY wrangling required.

**Setup manifest** — a `.setup` file inside an app repo containing plain-text instructions for secrets or manual steps that cannot be committed (e.g. API keys, URLs). The install script reads each submodule's `.setup` file and prints all instructions under a "manual setup required" section at the end of the bootstrap run.
