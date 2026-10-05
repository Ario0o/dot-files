-- decorations

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 6,
        border_size = 1,
        col = {
            active_border = "#7daea3",
            inactive_border = "#7daea3",
        },
        layout = "dwindle",
        allow_tearing = false,
    },

    decoration = {
        rounding = 7,
        rounding_power = 3,
        blur = {
            enabled = true,
            size = 20,
            passes = 3,
            vibrancy = 0.16969,
        },
        shadow = {
            enabled = false,
            range = 20,
            render_power = 3,
            color = 0xee0a0a0a,
        },
    },

    animations = {
        enabled = true,
    },

})