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
# Paths and configuration
# ─────────────────────────────────────────────

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/dotfiles/.config"
THEMES_SRC="$DOTFILES/dotfiles/.themes"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

PACMAN_PKGS=(
    hyprland
    swaync
    paru
    uwsm
    rofi-wayland
    kitty
    fish
    starship
    awww
    thunar
    thunar-archive-plugin
    vivaldi
    thunar-volman
    file-roller
    gvfs
    gthumb
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
    pamixer
    bluez
    bluez-utils
    vscodium
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gnome
    qt5-wayland
    qt6-wayland
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    papirus-icon-theme
    vim
    flat-remix-gtk
    alacritty
    polkit-gnome
    qt6ct
    btop
    batsignal
    hyprpicker
    hyprlock
    imagemagick
)

AUR_PKGS=(
    waybar-cava-git
    otf-geist-mono-nerd
    waypaper
)

CONFIGS=(
    cava
    fish
    gtk-3.0
    gtk-4.0
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

THEMES=(
    Gruvbox-Material-Dark
    Gruvbox-Material-Dark-HIDPI
)

# ─────────────────────────────────────────────
# Options
# ─────────────────────────────────────────────

SKIP_DEPS=false
USE_SYMLINKS=false

for arg in "$@"; do
    case "$arg" in
        --no-deps)
            SKIP_DEPS=true
            ;;

        --symlink)
            USE_SYMLINKS=true
            ;;

        --help|-h)
            cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --no-deps     Skip dependency installation
  --symlink     Symlink configs instead of copying them
  --help, -h    Show this help message
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
# Validate source directories
# ─────────────────────────────────────────────

if [[ ! -d "$SRC" ]]; then
    error "Config source directory not found:"
    error "$SRC"
    exit 1
fi

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

    # Update system
    step "Updating the system"

    if ! sudo pacman -Syu; then
        error "System update failed."
        return 1
    fi

    # Find missing official repository packages
    for pkg in "${PACMAN_PKGS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            info "✓ $pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        info "All official repository packages are already installed."
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
            warn "Skipping official repository package installation."
        fi
    fi

    # Detect AUR helper
    if command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    elif command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    else
        warn "No AUR helper found."
        warn "AUR packages will be skipped."
        return 0
    fi

    # Find missing AUR packages
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
# Copy or symlink helper
# ─────────────────────────────────────────────

install_path() {
    local source="$1"
    local destination="$2"
    local backup_dir="$3"

    if [[ ! -e "$source" && ! -L "$source" ]]; then
        warn "$source not found; skipping."
        return 0
    fi

    mkdir -p "$(dirname "$destination")"

    if [[ -L "$destination" ]]; then
        rm -f "$destination"
    elif [[ -e "$destination" ]]; then
        backup_path "$destination" "$backup_dir"
    fi

    if [[ "$USE_SYMLINKS" == true ]]; then
        ln -sfnT "$source" "$destination"
        info "Linked $destination → $source"
    else
        cp -aT "$source" "$destination"
        info "Copied $source → $destination"
    fi
}

# ─────────────────────────────────────────────
# Install configs
# ─────────────────────────────────────────────

install_configs() {
    if [[ "$USE_SYMLINKS" == true ]]; then
        step "Installing configs as symlinks"
    else
        step "Installing configs normally"
    fi

    mkdir -p "$HOME/.config"

    for cfg in "${CONFIGS[@]}"; do
        install_path \
            "$SRC/$cfg" \
            "$HOME/.config/$cfg" \
            "$BACKUP/.config"
    done

    for file in "${FILES[@]}"; do
        install_path \
            "$SRC/$file" \
            "$HOME/.config/$file" \
            "$BACKUP/.config"
    done
}

# ─────────────────────────────────────────────
# Install themes
# ─────────────────────────────────────────────

install_themes() {
    if [[ "$USE_SYMLINKS" == true ]]; then
        step "Installing themes as symlinks"
    else
        step "Installing themes normally"
    fi

    mkdir -p "$HOME/.themes"

    for theme in "${THEMES[@]}"; do
        install_path \
            "$THEMES_SRC/$theme" \
            "$HOME/.themes/$theme" \
            "$BACKUP/.themes"
    done
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

info "Detected distro: $DISTRO"

if [[ "$USE_SYMLINKS" == true ]]; then
    info "Installation mode: symlinks"
else
    info "Installation mode: normal copies"
fi

if [[ "$SKIP_DEPS" == false ]]; then
    if ! install_deps; then
        error "Dependency installation failed."
        exit 1
    fi
else
    warn "Skipping dependency installation (--no-deps)."
fi

install_configs
install_themes

echo
info "Installation complete."

if [[ -d "$BACKUP" ]]; then
    warn "Backups saved to: $BACKUP"
fi

if [[ "$USE_SYMLINKS" == true ]]; then
    info "Configs were installed as symlinks."
else
    info "Configs were installed as normal copies."
fi

info "Log out and back in, or restart Hyprland, to apply changes."
