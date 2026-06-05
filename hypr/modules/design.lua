---------------------
---- DESIGN CONFIG ---
---------------------
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 4,
        border_size = 0,
        resize_on_border = true,
        allow_tearing = false,
    }
})

---------------------
---- DECORATION ----
---------------------

hl.config({
    decoration = {
        rounding = 16,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = false,
            range = 20,
            render_power = 3,
            color = 0xee121212
        }
    },

    animations = {
        enabled = false
    }
})
