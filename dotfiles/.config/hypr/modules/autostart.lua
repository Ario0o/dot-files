-- Autostart

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("batsignal -w 15 -c 5 -d 2 -p")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("wifi-manager")
end)