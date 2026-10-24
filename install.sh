#!/usr/bin/env bash

set -Eeuo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info() {
    printf "%b[INFO]%b %s\n" "$GREEN" "$NC" "$1"
}

warn() {
    printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
}

error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"
}

step() {
    printf "%b==>%b %s\n" "$BLUE" "$NC" "$1"
}

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

readonly DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SRC="$DOTFILES/dotfiles/.config"
readonly THEMES_SRC="$DOTFILES/dotfiles/.themes"
readonly BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

declare -a PACMAN_PKGS=(
    hyprland
    swaync
    uwsm
    rofi-wayland
    kitty
    fish
    starship
    awww
    thunar
    thunar-archive-plugin
    thunar-volman
    file-roller
    gvfs
    gvfs-mtp
    gthumb
    vivaldi
    cava
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
    blueman
    bluez
    bluez-utils
    vscodium
    kate
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gnome
    qt5-wayland
    qt6-wayland
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    papirus-icon-theme
    vim
    alacritty
    polkit-gnome
    qt6ct
    breeze
    kvantum
    btop
    batsignal
    hyprpicker
    hyprlock
    imagemagick
)

declare -a AUR_PKGS=(
    waybar-cava-git
    otf-geist-mono-nerd
)

declare -a CONFIGS=(
    cava
    fish
    gtk-3.0
    gtk-4.0
    hypr
    kitty
    rofi
    swaync
    uwsm
    qt6ct
    waybar
    wifi-manager
)

declare -a FILES=(
    starship.toml
)

declare -a THEMES=(
    Gruvbox-Material-Dark
    Gruvbox-Material-Dark-HIDPI
)

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
            printf "Use './install.sh --help' for usage.\n"
            exit 2
            ;;
    esac
done

if [[ ! -d "$SRC" ]]; then
    error "Config source directory not found:"
    error "$SRC"
    exit 1
fi

confirm() {
    local prompt="$1"
    local reply

    if ! read -r -p "$prompt [Y/n] " reply; then
        reply="n"
    fi

    [[ "$reply" =~ ^[Yy]?$ ]]
}

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

    step "Updating the system"

    if ! sudo pacman -Syu; then
        error "System update failed."
        return 1
    fi

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
        printf "\n"
        warn "The following packages will be installed from official repositories:"
        printf '  %s\n' "${to_install[@]}"
        printf "\n"

        if confirm "Continue?"; then
            if ! sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
                error "Official package installation failed."
                return 1
            fi
        else
            warn "Skipping official repository package installation."
        fi
    fi

    if command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    elif command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    else
        warn "No AUR helper found."
        warn "AUR packages will be skipped."
        return 0
    fi

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

    printf "\n"
    warn "The following AUR packages will be installed:"
    printf '  %s\n' "${aur_to_install[@]}"
    printf "\n"

    if confirm "Continue?"; then
        if ! "$aur_helper" -S --needed --noconfirm "${aur_to_install[@]}"; then
            error "AUR package installation failed."
            return 1
        fi
    else
        warn "Skipping AUR package installation."
    fi
}

set_fish_default() {
    local fish_path

    if ! fish_path="$(command -v fish)"; then
        warn "Fish isn't installed; skipping default-shell change."
        return 0
    fi

    if ! grep -Fxq "$fish_path" /etc/shells; then
        warn "$fish_path isn't listed in /etc/shells; skipping default-shell change."
        return 0
    fi

    if confirm "Set Fish as your default login shell?"; then
        if chsh -s "$fish_path"; then
            info "Fish set as your default login shell. Log out and back in for it to take effect."
        else
            warn "Could not change the default shell."
        fi
    else
        info "Leaving your current default shell unchanged."
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        printf "%s\n" "${ID:-unknown}"
    else
        printf "unknown\n"
    fi
}

DISTRO="$(detect_distro)"

if [[ "$DISTRO" == "cachyos" ]]; then
    PACMAN_PKGS+=(paru)
fi

backup_path() {
    local source_path="$1"
    local backup_dir="$2"

    mkdir -p "$backup_dir"
    mv "$source_path" "$backup_dir/"
    info "Backed up $source_path"
}

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

    local scripts_dir="$HOME/.config/hypr/scripts"
    if compgen -G "$scripts_dir/*.sh" >/dev/null; then
        chmod +x "$scripts_dir/"*.sh
    fi
}

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

    if command -v gsettings >/dev/null 2>&1; then
        if ! gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Material-Dark"; then
            warn "Could not set GTK theme."
        fi

        if ! gsettings set org.gnome.desktop.interface icon-theme "Papirus"; then
            warn "Could not set icon theme."
        fi
    else
        warn "gsettings not found; skipping GTK theme settings."
    fi
}

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
set_fish_default

printf "\n"
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