-- ArchMerOS Hyprland Lua config for greetd/sysc-greet.

hl.animation({ leaf = "global", enabled = false })

hl.monitor({ output = "DP-3",     mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "1366x0", scale = 1 })
hl.monitor({ output = "DP-2",     mode = "preferred", position = "3286x0", scale = 1 })

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

hl.workspace_rule({ workspace = "1",  monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-3",     default = true })
hl.workspace_rule({ workspace = "11", monitor = "DP-2",     default = true })

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
    },
    decoration = {
        rounding = 0,
        blur = { enabled = false },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgb(000000)",
        disable_watchdog_warning = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    input = {
        kb_layout = "br,us",
        repeat_delay = 400,
        repeat_rate = 40,
        touchpad = { tap_to_click = true },
    },
})

hl.window_rule({
    name = "sysc-greet-kitty",
    match = { class = "^(kitty)$" },
    workspace = "1 silent",
    fullscreen = 1,
    opacity = "1.0 1.0",
})

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -lc 'kitty --start-as=fullscreen --config=/etc/greetd/kitty-greeter.conf /usr/local/bin/sysc-greet --theme archmeros; hyprctl eval \"hl.dispatch(hl.dsp.exit())\"'")
end)
