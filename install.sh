#!/usr/bin/env bash
# install.sh - Install Hyprland dotfiles and dependencies

set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

step() {
    echo -e "${BLUE}==>${NC} $1"
}

# ─────────────────────────────────────────────
# Safety checks
# ─────────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/dotfiles/.config"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

PACMAN_PKGS=(
    hyprland
    swaync
    paru
    rofi-wayland
    fuzzel
    kitty
    fish
    starship
    awww
    thunar
    thunar-volman
    gvfs
    gthumb
    network-manager-applet
    brightnessctl
    playerctl
    grim
    slurp
    wl-clipboard
    cliphist
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    bluez
    bluez-utils
    blueman
    vscodium
    polkit-kde-agent
    xdg-desktop-portal-hyprland
    qt5-wayland
    qt6-wayland
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    vim
)

AUR_PKGS=(
    helium-browser-bin
    waybar-cava-git
    otf-geist-mono-nerd
    waypaper
)

CONFIGS=(
    cava
    fish
    fuzzel
    hypr
    kitty
    rofi
    swaync
    waybar
    wifi-manager
)

FILES=(
    starship.toml
)

THEMES_SRC="$DOTFILES/dotfiles/.themes"

THEMES=(
    Gruvbox-Material-Dark
    Gruvbox-Material-Dark-HIDPI
)

# ─────────────────────────────────────────────
# Validate source directories
# ─────────────────────────────────────────────

if [[ ! -d "$SRC" ]]; then
    error "Config source directory not found:"
    error "$SRC"
    exit 1
fi

# ─────────────────────────────────────────────
# Parse command-line arguments
# ─────────────────────────────────────────────

SKIP_DEPS=false

for arg in "$@"; do
    case "$arg" in
        --no-deps)
            SKIP_DEPS=true
            ;;

        --help|-h)
            cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --no-deps     Skip dependency installation
  --help -h     Show this help message
EOF
            exit 0
            ;;

        *)
            error "Unknown option: $arg"
            echo "Use './install.sh --help' for usage."
            exit 2
            ;;
    esac
done

# ─────────────────────────────────────────────
# Distro detection
# ─────────────────────────────────────────────

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

DISTRO="$(detect_distro)"

# ─────────────────────────────────────────────
# Prompt helper
# ─────────────────────────────────────────────

confirm() {
    local prompt="$1"
    local reply

    if ! read -r -p "$prompt [Y/n] " reply; then
        reply="n"
    fi

    [[ "$reply" =~ ^[Yy]?$ ]]
}

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
            warn "Distro '$DISTRO' is not supported for automatic installation."
            warn "Please install the packages listed in README.md manually."
            return 1
            ;;
    esac
}

install_arch() {
    local to_install=()
    local aur_to_install=()
    local aur_helper=""

    # Check official repository packages
    for pkg in "${PACMAN_PKGS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            info "✓ $pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        info "All official-repository packages are already installed."
    else
        echo
        warn "The following packages will be installed from official repositories:"
        printf '  %s\n' "${to_install[@]}"
        echo

        if confirm "Continue?"; then
            if ! sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
                error "Official package installation failed."
                return 1
            fi
        else
            warn "Skipping official-repository package installation."
        fi
    fi

    # Detect the AUR helper after.
    if command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    elif command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    else
        warn "No AUR helper found."
        warn "AUR packages will be skipped."
        return 0
    fi

    # Check AUR packages
    for pkg in "${AUR_PKGS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            info "✓ $pkg already installed"
        else
            aur_to_install+=("$pkg")
        fi
    done

    if [[ ${#aur_to_install[@]} -eq 0 ]]; then
        info "All AUR packages are already installed."
        return 0
    fi

    echo
    warn "The following AUR packages will be installed:"
    printf '  %s\n' "${aur_to_install[@]}"
    echo

    if confirm "Continue?"; then
        if ! "$aur_helper" -S --needed --noconfirm "${aur_to_install[@]}"; then
            error "AUR package installation failed."
            return 1
        fi
    else
        warn "Skipping AUR package installation."
    fi
}

# ─────────────────────────────────────────────
# Backup helper
# ─────────────────────────────────────────────

backup_path() {
    local source_path="$1"
    local backup_dir="$2"

    mkdir -p "$backup_dir"
    mv "$source_path" "$backup_dir/"
    info "Backed up $source_path"
}

# ─────────────────────────────────────────────
# Symlink configs
# ─────────────────────────────────────────────

link_configs() {
    step "Symlinking configs into ~/.config/"

    mkdir -p "$HOME/.config"

    for cfg in "${CONFIGS[@]}"; do
        local source="$SRC/$cfg"
        local dest="$HOME/.config/$cfg"

        if [[ ! -d "$source" ]]; then
            warn "$source not found; skipping."
            continue
        fi

        if [[ -e "$dest" && ! -L "$dest" ]]; then
            backup_path "$dest" "$BACKUP/.config"
        elif [[ -L "$dest" ]]; then
            rm -f "$dest"
        fi

        ln -s "$source" "$dest"
        info "Linked $dest → $source"
    done

    for file in "${FILES[@]}"; do
        local source="$SRC/$file"
        local dest="$HOME/.config/$file"

        if [[ ! -f "$source" ]]; then
            warn "$source not found; skipping."
            continue
        fi

        if [[ -e "$dest" && ! -L "$dest" ]]; then
            backup_path "$dest" "$BACKUP/.config"
        elif [[ -L "$dest" ]]; then
            rm -f "$dest"
        fi

        ln -s "$source" "$dest"
        info "Linked $dest → $source"
    done
}

# ─────────────────────────────────────────────
# Symlink themes
# ─────────────────────────────────────────────

link_themes() {
    step "Symlinking themes into ~/.themes/"

    mkdir -p "$HOME/.themes"

    for theme in "${THEMES[@]}"; do
        local source="$THEMES_SRC/$theme"
        local dest="$HOME/.themes/$theme"

        if [[ ! -d "$source" ]]; then
            warn "$source not found; skipping."
            continue
        fi

        if [[ -e "$dest" && ! -L "$dest" ]]; then
            backup_path "$dest" "$BACKUP/.themes"
        elif [[ -L "$dest" ]]; then
            rm -f "$dest"
        fi

        ln -s "$source" "$dest"
        info "Linked $dest → $source"
    done
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

info "Detected distro: $DISTRO"

if [[ "$SKIP_DEPS" == false ]]; then
    if ! install_deps; then
        error "Dependency installation failed."
        exit 1
    fi
else
    warn "Skipping dependency installation (--no-deps)."
fi

link_configs
link_themes

echo
info "Done!"

if [[ -d "$BACKUP" ]]; then
    warn "Backups saved to: $BACKUP"
fi

info "Log out and back in, or restart Hyprland, to apply changes."