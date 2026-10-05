#!/bin/fish

pkill waybar
pkill swaync
waybar &
swaync &
wifi-manager --reload