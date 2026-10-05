-- window rules

hl.on("config.reloaded", function()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme \"Gruvbox-Material-Dark\"")
end)

hl.layer_rule({
    match = { namespace = "gtk-layer-shell" },
    no_anim = true,
})

hl.layer_rule({
    match = { namespace = "waybar" },
    blur = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    match = { namespace = "wifi-manager" },
    blur = true,
    ignore_alpha = 0.3,
})

hl.config({
    general = {
        resize_on_border = true,
        extend_border_grab_area = 20,
    }
})