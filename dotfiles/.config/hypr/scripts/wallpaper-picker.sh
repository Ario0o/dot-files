#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="~/.config/rofi/wallpaper-picker.rasi"
TRANSITION_FPS=60

if pgrep -x "rofi" > /dev/null; then
    hyprctl notify 3 2500 "rgb(C62E2E)" "fontsize:35 Rofi is already open"
    exit 1
fi

list=""
for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,gif,webp}; do
    [ -e "$img" ] || continue
    filename=$(basename "$img")
    list+="$filename\x00icon\x1f$img\n"
done

selected=$(echo -e "$list" | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p "Wallpaper")

if [ -n "$selected" ]; then
    wallpaper_path="$WALLPAPER_DIR/$selected"
    awww img "$wallpaper_path" --transition-fps "$TRANSITION_FPS" --transition-type any --transition-duration 1
fi