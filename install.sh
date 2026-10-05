#!/usr/bin/env bash
# install.sh - Install Hyprland dotfiles + dependencies

set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${BLUE}==>${NC} $1"; }

# ─────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/dotfiles/.config"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Packages split into: official repos + AUR
PACMAN_PKGS=(
    hyprland swaync paru
    rofi-wayland fuzzel
    kitty fish starship awww
    thunar thunar-volman gvfs gthumb
    network-manager-applet brightnessctl playerctl
    grim slurp wl-clipboard cliphist
    pipewire pipewire-pulse wireplumber pavucontrol
    bluez bluez-utils blueman vscodium
    polkit-kde-agent xdg-desktop-portal-hyprland
    qt5-wayland qt6-wayland
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji vim
)

AUR_PKGS=(
    helium-browser-bin
    waybar-cava-git
    otf-geist-mono-nerd
    waypaper
)

# Configs to symlink
CONFIGS=(cava fish fuzzel hypr kitty rofi swaync waybar wifi-manager)
FILES=(starship.toml)

# Themes
THEMES_SRC="$DOTFILES/dotfiles/.themes"
THEMES=(Gruvbox-Material-Dark Gruvbox-Material-Dark-HIDPI)

# ─────────────────────────────────────────────
# Parse flags
# ─────────────────────────────────────────────
INSTALL_DEPS=true
SKIP_DEPS=false

for arg in "$@"; do
    case "$arg" in
        --no-deps) SKIP_DEPS=true ;;
        --help|-h)
            cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --no-deps     Skip dependency installation (only symlink configs)
  --help, -h    Show this help
EOF
            exit 0
            ;;
    esac
done

# ─────────────────────────────────────────────
# Distro detection
# ─────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

DISTRO="$(detect_distro)"

# ─────────────────────────────────────────────
# Package installation
# ─────────────────────────────────────────────
install_deps() {
    step "Installing dependencies"

    case "$DISTRO" in
        arch|cachyos|endeavouros|manjaro)
            install_arch
            ;;
        *)
            warn "Distro '$DISTRO' is not supported for auto-install."
            warn "Please install the packages listed in README.md manually."
            return 1
            ;;
    esac
}

install_arch() {
    # Check for AUR helper
    AUR_HELPER=""
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    else
        warn "No AUR helper (paru/yay) found. AUR packages will be skipped."
    fi

    # Filter out already-installed packages
    local to_install=()
    for pkg in "${PACMAN_PKGS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            info "✓ $pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -eq 0 ]; then
        info "All official-repo packages are already installed."
    else
        echo
        warn "The following packages will be installed from official repos:"
        printf '  %s\n' "${to_install[@]}"
        echo
        read -rp "Continue? [Y/n] " reply
        if [[ ! "$reply" =~ ^[Yy]?$ ]]; then
            warn "Skipping official-repo install."
        else
            sudo pacman -S --needed --noconfirm "${to_install[@]}" || \
                warn "Some packages failed to install. Check output above."
        fi
    fi

    # AUR packages
    if [ -n "$AUR_HELPER" ]; then
        local aur_to_install=()
        for pkg in "${AUR_PKGS[@]}"; do
            if pacman -Qi "$pkg" &>/dev/null; then
                info "✓ $pkg (already installed)"
            else
                aur_to_install+=("$pkg")
            fi
        done

        if [ ${#aur_to_install[@]} -gt 0 ]; then
            echo
            warn "The following AUR packages will be installed:"
            printf '  %s\n' "${aur_to_install[@]}"
            echo
            read -rp "Continue? [Y/n] " reply
            if [[ ! "$reply" =~ ^[Yy]?$ ]]; then
                warn "Skipping AUR install."
            else
                "$AUR_HELPER" -S --needed --noconfirm "${aur_to_install[@]}" || \
                    warn "Some AUR packages failed. You may need to install them manually."
            fi
        fi
    fi
}

# ─────────────────────────────────────────────
# Symlink configs
# ─────────────────────────────────────────────
link_configs() {
    step "Symlinking configs into ~/.config/"
    mkdir -p "$HOME/.config"

    for cfg in "${CONFIGS[@]}"; do
        [ -d "$SRC/$cfg" ] || { warn "$cfg not found, skipping"; continue; }
        local dest="$HOME/.config/$cfg"

        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mkdir -p "$BACKUP/.config"
            mv "$dest" "$BACKUP/.config/"
            info "Backed up existing $dest"
        fi
        [ -L "$dest" ] && rm "$dest"
        ln -sfn "$SRC/$cfg" "$dest"
        info "Linked $dest → $SRC/$cfg"
    done

    for f in "${FILES[@]}"; do
        [ -f "$SRC/$f" ] || continue
        local dest="$HOME/.config/$f"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mkdir -p "$BACKUP/.config"
            mv "$dest" "$BACKUP/.config/"
        fi
        [ -L "$dest" ] && rm "$dest"
        ln -sfn "$SRC/$f" "$dest"
        info "Linked $dest → $SRC/$f"
    done
}

# ─────────────────────────────────────────────
# Symlink themes
# ─────────────────────────────────────────────
link_themes() {
    step "Symlinking themes into ~/.themes/"
    mkdir -p "$HOME/.themes"

    for theme in "${THEMES[@]}"; do
        [ -d "$THEMES_SRC/$theme" ] || { warn "$theme not found, skipping"; continue; }
        local dest="$HOME/.themes/$theme"

        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mkdir -p "$BACKUP/.themes"
            mv "$dest" "$BACKUP/.themes/"
            info "Backed up existing $dest"
        fi
        [ -L "$dest" ] && rm "$dest"
        ln -sfn "$THEMES_SRC/$theme" "$dest"
        info "Linked $dest → $THEMES_SRC/$theme"
    done
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
info "Detected distro: $DISTRO"

if [ "$SKIP_DEPS" = false ]; then
    install_deps
else
    warn "Skipping dependency install (--no-deps)"
fi

link_configs
link_themes

echo
info "Done!"
[ -d "$BACKUP" ] && warn "Backups saved to: $BACKUP"
info "Log out and back in (or restart Hyprland) to apply changes."