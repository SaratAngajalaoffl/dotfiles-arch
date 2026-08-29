#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Require pacman (Arch)
if ! command -v pacman &>/dev/null; then
    echo "error: pacman not found — this install script is for Arch Linux." >&2
    exit 1
fi

git -C "$DOTFILES_DIR" submodule update --init --recursive

# qt5ct/qt6ct: their .conf files are gitignored (theme-set.sh rewrites
# color_scheme_path on every theme switch), so seed them from the
# tracked template if they don't exist yet.
for tool in qt5ct qt6ct; do
    conf="$DOTFILES_DIR/$tool/config/$tool.conf"
    tpl="$DOTFILES_DIR/$tool/config/$tool.conf.tpl"
    if [[ ! -f "$conf" && -f "$tpl" ]]; then
        cp "$tpl" "$conf"
        echo "seeded: $conf ← $tpl"
    fi
done

link_one() {
    local src_path="$1"
    local tgt="$2"

    # Repair: src_path should never be a symlink — it's the source of truth.
    # If it is (e.g. from a previous circular-link bug), restore from .bak.
    if [[ -L "$src_path" ]]; then
        local bak="${src_path}.bak"
        if [[ -f "$bak" ]]; then
            echo "repairing circular source: $src_path (restoring from ${src_path}.bak)"
            rm "$src_path"
            mv "$bak" "$src_path"
        else
            echo "warning: $src_path is a symlink with no .bak to restore from — skipping" >&2
            return
        fi
    fi

    mkdir -p "$(dirname "$tgt")"

    # Guard: if src_path and tgt resolve to the same path, skip to avoid a circular symlink.
    # This can happen when the target directory is itself symlinked into the submodule.
    if [[ -e "$tgt" ]] && [[ "$(realpath "$src_path")" == "$(realpath "$tgt")" ]]; then
        echo "already same file: $tgt"
        return
    fi

    if [[ -L "$tgt" && "$(readlink "$tgt")" == "$src_path" ]]; then
        echo "already linked: $tgt"
    elif [[ -L "$tgt" ]]; then
        rm "$tgt"
    elif [[ -e "$tgt" ]]; then
        mv "$tgt" "${tgt}.bak"
        echo "backed up: $tgt → ${tgt}.bak"
    fi

    ln -s "$src_path" "$tgt"
    echo "linked: $tgt → $src_path"
}

# Symlink configs
while IFS= read -r submodule; do
    links_file="$DOTFILES_DIR/$submodule/.links"
    [[ -f "$links_file" ]] || continue

    while IFS=: read -r src tgt || [[ -n "$src" ]]; do
        [[ -z "$src" || "${src:0:1}" == "#" ]] && continue
        tgt="${tgt/#\~/$HOME}"

        if [[ "$src" == *"/*" ]]; then
            # Glob mapping: symlink each file in the directory individually into tgt dir.
            src_dir="$DOTFILES_DIR/$submodule/${src%/*}"
            tgt_dir="${tgt%/}"
            mkdir -p "$tgt_dir"
            for file in "$src_dir"/*; do
                [[ -f "$file" ]] || continue
                link_one "$file" "$tgt_dir/$(basename "$file")"
            done
        else
            link_one "$DOTFILES_DIR/$submodule/$src" "$tgt"
        fi
    done < "$links_file"
done < <(git -C "$DOTFILES_DIR" submodule foreach --quiet 'echo "$displaypath"')

# Bootstrap the default theme on a fresh install (never overrides an already-chosen theme)
DEFAULT_THEME="catppuccin-mocha"
if [[ ! -e "$HOME/.config/theme/current" && -x "$HOME/.local/bin/theme-set.sh" ]]; then
    echo "bootstrapping default theme: $DEFAULT_THEME"
    "$HOME/.local/bin/theme-set.sh" "$DEFAULT_THEME" || echo "warning: theme bootstrap failed, run theme-set.sh manually later" >&2
fi

# Install packages from packages manifest
install_packages() {
    local packages_file="$DOTFILES_DIR/packages"
    [[ -f "$packages_file" ]] || return

    local section=""
    local -a pacman_pkgs=()
    local -a aur_pkgs=()
    local -a rustup_toolchains=()
    local -a npm_pkgs=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue

        if [[ "$line" == *: ]]; then
            section="${line%:}"
            continue
        fi

        case "$section" in
            pacman) pacman_pkgs+=("$line") ;;
            aur)    aur_pkgs+=("$line") ;;
            rustup) rustup_toolchains+=("$line") ;;
            npm)    npm_pkgs+=("$line") ;;
        esac
    done < "$packages_file"

    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        echo "installing pacman packages: ${pacman_pkgs[*]}"
        sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        local aur_helper=""
        if command -v yay &>/dev/null; then
            aur_helper=yay
        elif command -v paru &>/dev/null; then
            aur_helper=paru
        else
            echo "error: AUR packages listed in packages but neither yay nor paru is installed." >&2
            exit 1
        fi
        echo "installing AUR packages via $aur_helper: ${aur_pkgs[*]}"
        "$aur_helper" -S --needed --noconfirm "${aur_pkgs[@]}"
    fi

    if [[ ${#rustup_toolchains[@]} -gt 0 ]]; then
        command -v rustup &>/dev/null || { echo "error: rustup toolchains listed in packages but rustup is not installed (add 'rustup' under pacman:)." >&2; exit 1; }
        echo "installing rustup toolchains: ${rustup_toolchains[*]}"
        for toolchain in "${rustup_toolchains[@]}"; do
            rustup toolchain install --no-self-update "$toolchain"
        done
    fi

    if [[ ${#npm_pkgs[@]} -gt 0 ]]; then
        command -v npm &>/dev/null || { echo "error: npm packages listed in packages but npm is not installed." >&2; exit 1; }
        echo "installing npm global packages: ${npm_pkgs[*]}"
        npm install -g "${npm_pkgs[@]}"
    fi
}

echo "installing packages from packages..."
install_packages

# Check secrets declared in each submodule's .secrets manifest (format:
# "label:secret-tool attribute pairs", one per line — same idea as .links).
# Prompts via `secret-tool store` for anything missing; fails at the end if
# any are still unset, so a fresh install can't silently run without them.
check_secrets() {
    command -v secret-tool &>/dev/null || return

    local secrets_file label attrs reply
    local -a attr_array missing=()

    while IFS= read -r submodule; do
        secrets_file="$DOTFILES_DIR/$submodule/.secrets"
        [[ -f "$secrets_file" ]] || continue

        while IFS=: read -r label attrs || [[ -n "$label" ]]; do
            [[ -z "$label" || "${label:0:1}" == "#" ]] && continue
            attrs="${attrs# }"
            read -ra attr_array <<< "$attrs"

            secret-tool lookup "${attr_array[@]}" &>/dev/null && continue

            echo ""
            echo "missing secret: $label"
            read -r -p "  enter it now? [Y/n] " reply </dev/tty
            if [[ -z "$reply" || "$reply" =~ ^[Yy] ]]; then
                secret-tool store --label="$label" "${attr_array[@]}" </dev/tty
            fi

            secret-tool lookup "${attr_array[@]}" &>/dev/null || missing+=("$label ($submodule)")
        done < "$secrets_file"
    done < <(git -C "$DOTFILES_DIR" submodule foreach --quiet 'echo "$displaypath"')

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo "error: missing required secrets:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        exit 1
    fi
}

echo "checking required secrets..."
check_secrets

# Print manual setup instructions from each submodule's .setup file
setup_notes=()
while IFS= read -r submodule; do
    setup_file="$DOTFILES_DIR/$submodule/.setup"
    [[ -f "$setup_file" ]] || continue
    setup_notes+=("[$submodule]" "$(cat "$setup_file")" "")
done < <(git -C "$DOTFILES_DIR" submodule foreach --quiet 'echo "$displaypath"')

if [[ ${#setup_notes[@]} -gt 0 ]]; then
    echo ""
    echo "=== manual setup required ==="
    printf '%s\n' "${setup_notes[@]}"
fi
