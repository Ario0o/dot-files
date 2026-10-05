# my hyprland Dotfiles

My personal Hyprland setup on CachyOS. Originally based on
[babyanonymouse/Zero_Drag.dotfiles](https://github.com/babyanonymouse/Zero_Drag.dotfiles).

![screenshot](screenshot.png)

## What's Inside

| Config | Purpose |
|--------|---------|
| `hypr` | Hyprland window manager |
| `waybar` | Status bar |
| `swaync` | Notification daemon |
| `rofi` | Application launcher |
| `fuzzel` | Alternative launcher |
| `thunar` | File manager |
| `helium` | Browser |
| `kitty` | Terminal emulator |
| `fish` | Shell |
| `awww` | Wallpaper |
| `waypaper` | Wallpaper manager (GUI) |
| `starship` | Shell prompt |
| `cava` | Audio visualizer |
| `VScodium` | Code editor |
| `wifi-manager` | Wi-Fi management (TUI/GUI) |
| `paru` | AUR helper |

## Keybindings

`mainMod` = `SUPER`. Full list in `hypr/binds.lua`.

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `SUPER + Return` | Terminal | `SUPER + Q` | Close window |
| `SUPER + E` | File manager | `SUPER + F` | Fullscreen |
| `SUPER + Space` | Launcher | `SUPER + G` | Float |
| `SUPER + B` | Browser | `SUPER + M` | Maximize |
| `SUPER + T` | Editor | `SUPER + L` | Lock screen |
| `SUPER + 1–9` | Workspace 1–9 | `SUPER + W` | Wallpaper |
| `SUPER + SHIFT + 1–9` | Move to workspace | `SUPER + V` | Clipboard |
| `SUPER + ←/→/↑/↓` | Focus window | `SUPER + P` | Color picker |
| `SUPER + H/L/K/J` | Focus (Vim) | `SUPER + R` | Reload waybar |
| `SUPER + ALT + ←/→` | Resize H | `Print` / `SUPER + S` | Screenshot |
| `CTRL + ALT + ←/→/↑/↓` | Move window | `SUPER + Tab` | Next workspace |

> **Note:** This configuration uses Hyprland's Lua syntax (0.55+). Keybinds are
> defined with `hl.bind()` in `hypr/binds.lua`. If you're on an older Hyprland
> version using `hyprlang`, you'll need to convert these to `bind = MOD, KEY, ...`
> format.

## Requirements

- Hyprland
- Waybar
- SwayNC
- Rofi / Fuzzel
- Kitty
- VS codium
- Fish shell
- Starship
- Cava
- thunar
- awww
- waypaper
- wifi manager
- helium
- paru

Install on Arch/CachyOS:

## Installation

clone this repository and run the installation script.

```bash
git clone https://github.com/Ario0o/dot-files ~/dot-files
cd ~/dot-files
./install.sh
```

If you prefer to only symlink the configuration files without installing any dependencies, run:

```bash
./install.sh --no-deps
```

The script will:
- Detect your distribution (auto-install supported for Arch/CachyOS).
- Symlink the configuration files into `~/.config/`.
- Back up any existing files to `~/.dotfiles-backup-<timestamp>`.

## install dependencys sepearatly 

```bash
sudo pacman -S --needed --noconfirm \
    hyprland swaync \
    rofi-wayland fuzzel \
    kitty fish starship \
    awww \
    thunar thunar-volman gvfs gthumb \
    network-manager-applet brightnessctl playerctl \
    grim slurp wl-clipboard cliphist \
    pipewire pipewire-pulse wireplumber pavucontrol \
    bluez bluez-utils blueman \
    polkit-kde-agent xdg-desktop-portal-hyprland \
    qt5-wayland qt6-wayland \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    vscodium paru
```

```bash
paru -S --needed \
    vscodium-bin \
    helium-browser-bin \
    waybar-cava-git \
    otf-geist-mono-nerd \
    waypaper
```
