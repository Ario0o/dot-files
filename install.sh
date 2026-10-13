#!/usr/bin/env bash

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

# ── Arch / CachyOS packages ──────────────────
PACMAN_PKGS=(
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
)

# ── openSUSE Tumbleweed packages ─────────────
# Packages available from official repos + X11:Wayland OBS repo.
ZYPPER_PKGS=(
    hyprland
    hyprlock
    hyprpicker
    hypridle
    swaync
    uwsm
    rofi-wayland
    kitty
    fish
    starship
    awww
    thunar
    thunar-plugin-archive
    thunar-volman
    file-roller
    gvfs
    gthumb
    cava
    brightnessctl
    playerctl
    grim
    slurp
    wl-clipboard
    pipewire
    pipewire-pulseaudio
    wireplumber
    pavucontrol
    pamixer
    bluez
    bluez-utils
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gnome
    libqt5-qtwayland
    qt6-wayland
    noto-sans-fonts
    noto-coloremoji-fonts
    papirus-icon-theme
    vim
    alacritty
    polkit-gnome
    qt6ct
    btop
    batsignal
    ImageMagick
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
# Package installation
# ─────────────────────────────────────────────

install_deps() {
    step "Installing dependencies"

    case "$DISTRO" in
        arch|cachyos|endeavouros|manjaro)
            install_arch
            ;;

        opensuse*|suse*|sles)
            install_opensuse
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
# openSUSE Tumbleweed installation
# ─────────────────────────────────────────────

add_opensuse_repos() {
    step "Ensuring required OBS repositories"

    local alias_name="X11_Wayland"
    local url="https://download.opensuse.org/repositories/X11:Wayland/openSUSE_Tumbleweed/"

    if zypper lr 2>/dev/null | grep -q "$alias_name"; then
        info "✓ OBS repo X11:Wayland already present"
    else
        info "Adding OBS repo X11:Wayland"
        if ! sudo zypper addrepo -f "$url" "$alias_name"; then
            warn "Could not add X11:Wayland repo."
        fi
    fi

    sudo zypper --gpg-auto-import-keys refresh
}

install_opensuse() {
    local to_install=()

    add_opensuse_repos

    step "Updating the system"
    if ! sudo zypper --gpg-auto-import-keys dup -y; then
        warn "System update (zypper dup) reported issues; continuing anyway."
    fi

    # Find missing packages
    for pkg in "${ZYPPER_PKGS[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            info "✓ $pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        info "All openSUSE repository packages are already installed."
    else
        echo
        warn "The following packages will be installed via zypper:"
        printf '  %s\n' "${to_install[@]}"
        echo

        if confirm "Continue?"; then
            # Install one at a time so a single missing package
            # doesn't abort the whole batch.
            local failed=()
            for pkg in "${to_install[@]}"; do
                if ! sudo zypper install -y --no-recommends "$pkg"; then
                    failed+=("$pkg")
                fi
            done

            if [[ ${#failed[@]} -gt 0 ]]; then
                warn "These packages failed to install:"
                printf '  %s\n' "${failed[@]}"
                warn "You may need to find alternate sources for them."
            fi
        else
            warn "Skipping repository package installation."
        fi
    fi

    install_opensuse_extras
}

install_opensuse_extras() {
    step "Installing openSUSE extras (non-repo packages)"

    # ── VSCodium (OBS home:kwk:vscodium) ─────
    if command -v codium >/dev/null 2>&1; then
        info "✓ codium already installed"
    else
        info "Adding VSCodium repo"
        sudo rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null || true
        sudo zypper addrepo -f \
            https://download.opensuse.org/repositories/home:kwk:vscodium/openSUSE_Tumbleweed/ \
            vscodium 2>/dev/null || true
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper install -y codium || warn "VSCodium install failed."
    fi

    # ── Vivaldi (official repo) ──────────────
    if command -v vivaldi >/dev/null 2>&1 || command -v vivaldi-stable >/dev/null 2>&1; then
        info "✓ Vivaldi already installed"
    else
        info "Adding Vivaldi repo"
        sudo rpm --import https://repo.vivaldi.com/archive/linux_signing_key.pub 2>/dev/null || true
        sudo zypper addrepo -f \
            https://repo.vivaldi.com/archive/rpm/x86_64 \
            vivaldi 2>/dev/null || true
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper install -y vivaldi-stable || warn "Vivaldi install failed."
    fi

    # ── cliphist (build from source) ─────────
    if command -v cliphist >/dev/null 2>&1; then
        info "✓ cliphist already installed"
    else
        info "cliphist is not packaged on openSUSE; building from source"

        if ! command -v go >/dev/null 2>&1; then
            if confirm "cliphist needs Go. Install 'go' now?"; then
                sudo zypper install -y go || warn "Go install failed."
            fi
        fi

        if command -v go >/dev/null 2>&1; then
            local tmpdir
            tmpdir="$(mktemp -d)"
            if git clone --depth=1 https://github.com/sentriz/cliphist "$tmpdir/cliphist"; then
                if (cd "$tmpdir/cliphist" && go build -o cliphist .); then
                    sudo install -Dm755 "$tmpdir/cliphist/cliphist" /usr/local/bin/cliphist
                    info "✓ cliphist installed to /usr/local/bin/cliphist"
                else
                    warn "cliphist build failed."
                fi
            else
                warn "cliphist clone failed."
            fi
            rm -rf "$tmpdir"
        else
            warn "Skipping cliphist (Go not available)."
        fi
    fi

    # ── Fonts not packaged on openSUSE ───────
    install_opensuse_fonts
}

install_opensuse_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    if compgen -G "$font_dir/JetBrainsMono*NerdFont*.ttf" >/dev/null; then
        info "✓ JetBrains Mono Nerd Font already installed"
    else
        info "Downloading JetBrains Mono Nerd Font"
        local tmpzip
        tmpzip="$(mktemp)"
        if curl -fL -o "$tmpzip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
            unzip -o "$tmpzip" -d "$font_dir" >/dev/null
            info "✓ JetBrains Mono Nerd Font installed"
        else
            warn "JetBrains Mono Nerd Font download failed."
        fi
        rm -f "$tmpzip"
    fi

    # Geist Mono Nerd Font (Arch: otf-geist-mono-nerd)
    if compgen -G "$font_dir/GeistMono*NerdFont*" >/dev/null; then
        info "✓ Geist Mono Nerd Font already installed"
    else
        info "Downloading Geist Mono Nerd Font"
        local tmpzip
        tmpzip="$(mktemp)"
        if curl -fL -o "$tmpzip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip"; then
            unzip -o "$tmpzip" -d "$font_dir" >/dev/null
            info "✓ Geist Mono Nerd Font installed"
        else
            warn "Geist Mono Nerd Font download failed."
        fi
        rm -f "$tmpzip"
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi
}

# ─────────────────────────────────────────────
# Set fish as shell
# ─────────────────────────────────────────────

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

if [[ "$DISTRO" == "cachyos" ]]; then
    PACMAN_PKGS+=(paru)
fi

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

    local scripts_dir="$HOME/.config/hypr/scripts"
    if compgen -G "$scripts_dir/*.sh" >/dev/null; then
        chmod +x "$scripts_dir/"*.sh
    fi
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
set_fish_default

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