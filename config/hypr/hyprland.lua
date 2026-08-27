-- ArchMerOS Hyprland Configuration (Lua)
-- Migrated from hyprlang (.conf) for Hyprland v0.57+
-- Original backup: config/hypr/legacy-conf-backup/

---@diagnostic disable: undefined-global

local theme = require("theme")
local tp    = require("transparency")

-----------------------
---- MY PROGRAMS ------
-----------------------
local mod         = "SUPER"
local terminal    = "~/.config/archmeros/scripts/archmeros-wezterm.sh terminal"
local fileManager = "thunar"
local launcher    = "~/.config/archmeros/scripts/archmeros-launcher.sh"
local paraHub     = "~/.config/archmeros/scripts/archmeros-para.sh"

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("QT_SCALE_FACTOR", "1.10")
hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1.10")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/archmeros/scripts/archmeros-waybar.sh start")
    hl.exec_cmd("mako -c ~/.config/mako/config")
    hl.exec_cmd("~/.config/archmeros/scripts/archmeros-wallpaper.sh")
    hl.exec_cmd("~/.config/archmeros/scripts/archmeros-session-appearance.sh")
    hl.exec_cmd("~/.config/archmeros/scripts/archmeros-audio-policy.sh")
    hl.exec_cmd("sh -lc 'command -v systemctl >/dev/null 2>&1 && systemctl --user restart hypridle.service >/tmp/archmeros-hypridle.log 2>&1'")
    hl.exec_cmd("systemctl --user start archmeros-elephant.service archmeros-walker.service archmeros-reopen-listener.service archmeros-notification-focus.service")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("blueman-applet")
end)

------------------
---- MONITORS ----
------------------
hl.monitor({ output = "DP-3",     mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "1366x0", scale = 1 })
hl.monitor({ output = "DP-2",     mode = "preferred", position = "3286x0", scale = 1 })

-----------------------
---- WORKSPACE MAP ----
-----------------------
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "8", monitor = "DP-3",     default = true })
hl.workspace_rule({ workspace = "9", monitor = "DP-2",     default = true })

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 8,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding           = 8,
        active_opacity     = tp.active_opacity,
        inactive_opacity   = tp.inactive_opacity,
        fullscreen_opacity = 1.0,

        blur = {
            enabled           = tp.blur_enabled,
            size              = tp.blur_size,
            passes            = tp.blur_passes,
            ignore_opacity    = true,
            new_optimizations = true,
            noise             = 0.018,
            contrast          = 1.05,
            brightness        = 1.0,
            vibrancy          = tp.blur_vibrancy,
            popups            = true,
            popups_ignorealpha = 0.2,
        },

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = theme.shadow,
        },
    },

    animations = {
        enabled = true,
    },
})

-------------------------
---- BEZIER & ANIMS -----
-------------------------
hl.curve("curve", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

hl.animation({ leaf = "windows",      enabled = true, speed = 5, bezier = "curve", style = "slide" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 5, bezier = "curve", style = "slide" })
hl.animation({ leaf = "border",       enabled = true, speed = 8, bezier = "curve" })
hl.animation({ leaf = "borderangle",  enabled = true, speed = 8, bezier = "curve" })
hl.animation({ leaf = "fade",         enabled = true, speed = 5, bezier = "curve" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 6, bezier = "curve", style = "slidefade 18%" })

---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout  = "br,us",
        kb_variant = "abnt2,",
        kb_options = "grp:alt_shift_toggle,lvl3:ralt_switch",
        kb_file    = "~/.config/hypr/archmeros-keyboard.xkb",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
        sensitivity = 0,
    },

    cursor = {
        no_hardware_cursors = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    binds = {
        pass_mouse_when_bound = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------

-- App launchers
hl.bind(mod .. " + T",               hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T",            hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-termius.sh"))
hl.bind("CTRL + " .. mod .. " + T",  hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-termius.sh"))
hl.bind(mod .. " + space",           hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + SHIFT + space",   hl.dsp.exec_cmd("rofi -show drun -show-icons -theme ~/.config/rofi/launchers/drun.rasi"))
hl.bind(mod .. " + E",               hl.dsp.exec_cmd(paraHub))
hl.bind(mod .. " + Return",          hl.dsp.exec_cmd(terminal))

-- Keyboard layout
hl.bind("CTRL + ALT + space",        hl.dsp.exec_cmd("hyprctl switchxkblayout current next"))
hl.bind("SUPER + Insert",            hl.dsp.exec_cmd("/home/zacmero/.config/archmeros/scripts/archmeros-keyboard.sh toggle"))

-- Wallpaper / Appearance
hl.bind(mod .. " + ALT + P",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-wallpaper-pick.sh"))
hl.bind(mod .. " + ALT + code:33",   hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-wallpaper-pick.sh"))
hl.bind(mod .. " + ALT + A",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-appearance.sh"))
hl.bind(mod .. " + ALT + T",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-theme-select.sh"))
hl.bind(mod .. " + P",               hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-wallpaper-pick.sh"))

-- AI assistants
hl.bind(mod .. " + A",               hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-ai-float.sh aichat"))
hl.bind(mod .. " + SHIFT + A",       hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-ai-float.sh fabric"))
hl.bind(mod .. " + CTRL + A",        hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-ai-float.sh sessions"))

-- Side monitor / audio
hl.bind(mod .. " + S",               hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-side-standby.sh"))
hl.bind(mod .. " + ALT + S",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-side-standby.sh"))
hl.bind(mod .. " + ALT + SHIFT + S", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-audio.sh"))

-- Screenshot (multiple key aliases for different keyboards)
hl.bind(mod .. " + Print",           hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh region"))
hl.bind(mod .. " + SHIFT + Print",   hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh full"))
hl.bind(mod .. " + code:107",        hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh region"))
hl.bind(mod .. " + SHIFT + code:107", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh full"))
hl.bind(mod .. " + Sys_Req",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh region"))
hl.bind(mod .. " + SHIFT + Sys_Req", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh full"))
hl.bind(mod .. " + F12",             hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh region"))
hl.bind(mod .. " + SHIFT + F12",     hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-screenshot.sh full"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-media-control.sh previous"))
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-media-control.sh play-pause"))
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-media-control.sh next"))

-- Volume bracket keys
hl.bind(mod .. " + bracketleft",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind(mod .. " + backslash",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(mod .. " + bracketright", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))

-- Workspace switching (ALT + number)
hl.bind("ALT + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("ALT + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("ALT + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("ALT + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("ALT + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind("ALT + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind("ALT + 7", hl.dsp.focus({ workspace = 7 }))

-- Workspace switching (ALT + numpad)
hl.bind("ALT + KP_1", hl.dsp.focus({ workspace = 1 }))
hl.bind("ALT + KP_2", hl.dsp.focus({ workspace = 2 }))
hl.bind("ALT + KP_3", hl.dsp.focus({ workspace = 3 }))
hl.bind("ALT + KP_4", hl.dsp.focus({ workspace = 4 }))
hl.bind("ALT + KP_5", hl.dsp.focus({ workspace = 5 }))

-- Workspace switching (ALT + numpad keycodes, numlock-off fallback)
hl.bind("ALT + code:87", hl.dsp.focus({ workspace = 1 }))
hl.bind("ALT + code:88", hl.dsp.focus({ workspace = 2 }))
hl.bind("ALT + code:89", hl.dsp.focus({ workspace = 3 }))
hl.bind("ALT + code:83", hl.dsp.focus({ workspace = 4 }))
hl.bind("ALT + code:84", hl.dsp.focus({ workspace = 5 }))

-- Workspace switching (SUPER + number)
hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + 7", hl.dsp.focus({ workspace = 7 }))

-- Workspace navigation (adjacent)
hl.bind("CTRL + ALT + LEFT",      hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + RIGHT",     hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + ALT + code:105",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + code:106",  hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "m+1" }))

-- Mouse nav buttons for image viewer (bindr = repeating)
hl.bind("mouse:275", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-imv-mouse-nav.sh prev"), { repeating = true })
hl.bind("mouse:276", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-imv-mouse-nav.sh next"), { repeating = true })

-- Move window to workspace
hl.bind(mod .. " + SHIFT + F1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mod .. " + SHIFT + F2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mod .. " + SHIFT + F3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mod .. " + SHIFT + F4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mod .. " + SHIFT + F5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mod .. " + SHIFT + F6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mod .. " + SHIFT + F7", hl.dsp.window.move({ workspace = 7 }))

-- Window management
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-close.sh"))
hl.bind(mod .. " + Q",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-close.sh"))
hl.bind(mod .. " + O",         hl.dsp.exec_cmd("python3 ~/.config/archmeros/scripts/archmeros-reopen-history.py reopen-folders"))
hl.bind(mod .. " + SHIFT + O", hl.dsp.exec_cmd("python3 ~/.config/archmeros/scripts/archmeros-reopen-history.py reopen-general"))
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-tile-window.sh"))
hl.bind(mod .. " + F",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-fullscreen.sh"))

-- Web apps
hl.bind(mod .. " + C",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-webapp.sh gemini"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-webapp.sh chatgpt"))
hl.bind(mod .. " + B",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-firefox.sh"))

-- Window pop (grave / backtick / apostrophe / dead keys / keycode 49)
local pop_full = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-window-pop.sh full")
local pop_shrink = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-window-pop.sh shrink")
local pop_medium = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-window-pop.sh medium")

for _, k in ipairs({"grave", "apostrophe", "dead_acute", "dead_grave", "acute"}) do
    hl.bind(mod .. " + " .. k, pop_full)
    hl.bind(mod .. " + SHIFT + " .. k, pop_shrink)
    hl.bind("ALT + " .. k, pop_full)
    hl.bind("ALT + SHIFT + " .. k, pop_medium)
end
hl.bind(mod .. " + SHIFT + quotedbl", pop_shrink)
hl.bind("ALT + SHIFT + quotedbl", pop_medium)
hl.bind(mod .. " + SHIFT + asciitilde", pop_shrink)
hl.bind("ALT + SHIFT + asciitilde", pop_medium)

-- Miscellaneous
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("wdisplays"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-refresh-shell.sh"))
hl.bind(mod .. " + M",         hl.dsp.exec_cmd("[workspace 9 silent] ~/.config/archmeros/scripts/archmeros-youtube-music.sh"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-note.sh"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-productivity.sh"))
hl.bind(mod .. " + G",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-telegram.sh"))
hl.bind(mod .. " + 0",         hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-obsidian.sh"))
hl.bind(mod .. " + period",    hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-emoji.sh"))

-- Focus movement (vim + arrows)
hl.bind(mod .. " + J",     hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + K",     hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + H",     hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L",     hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + Down",  hl.dsp.focus({ direction = "down" }))

-- Window move / waybar toggle
hl.bind(mod .. " + SHIFT + J", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-move-window.py d"))
hl.bind(mod .. " + SHIFT + K", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-move-window.py u"))
hl.bind(mod .. " + SHIFT + H", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-waybar.sh toggleall"))
hl.bind(mod .. " + SHIFT + 1", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-waybar.sh toggle1"))
hl.bind(mod .. " + SHIFT + 2", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-waybar.sh toggle2"))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-waybar.sh toggle3"))
hl.bind("CTRL + SHIFT + H",    hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-move-window.py l"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-move-window.py r"))

-- Swap windows (arrows)
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mod .. " + SHIFT + Up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + Down",  hl.dsp.window.swap({ direction = "down" }))

-- Alt-tab and Super-tab cards cycle
local cycle_recent_next = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-cycle-window.sh recent next")
local cycle_recent_prev = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-cycle-window.sh recent prev")
local cycle_all_next    = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-cycle-window.sh all next")
local cycle_all_prev    = hl.dsp.exec_cmd("~/.config/archmeros/scripts/archmeros-cycle-window.sh all prev")

hl.bind("ALT + Tab",           cycle_recent_next)
hl.bind("ALT + SHIFT + Tab",   cycle_recent_prev)
hl.bind(mod .. " + Tab",       cycle_all_next)
hl.bind(mod .. " + SHIFT + Tab", cycle_all_prev)

-- Mouse drag/resize (bindm = {mouse = true})
hl.bind("SHIFT + mouse:272",   hl.dsp.window.drag(),   { mouse = true })
hl.bind("SHIFT + mouse:273",   hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------------------
---- WINDOW RULES ----
--------------------------------

-- Thunar file manager
hl.window_rule({
    name  = "thunar-float",
    match = { class = "(thunar|Thunar)" },
    opacity = tp.thunar_active_opacity .. " " .. tp.thunar_inactive_opacity,
    float   = true,
    size    = "72% 76%",
    center  = true,
})

-- Walker launcher
hl.window_rule({
    name  = "walker-float",
    match = { class = "^(dev\\.benz\\.walker)$" },
    float   = true,
    center  = true,
    size    = "34% 42%",
    opacity = tp.walker_active_opacity .. " " .. tp.walker_inactive_opacity,
})

-- Smile emoji picker
hl.window_rule({
    name  = "smile-float",
    match = { class = "^(it\\.mijorus\\.smile)$" },
    float   = true,
    center  = true,
    size    = "34% 46%",
    opacity = "0.92 0.86",
})

-- imv image viewer
hl.window_rule({
    name  = "imv-float",
    match = { class = "^(imv)$" },
    float   = true,
    center  = true,
    size    = "52% 62%",
    opacity = "0.94 0.90",
})

-- Wallpaper picker
hl.window_rule({
    name  = "wallpaper-picker",
    match = { title = "^ArchMerOS Wallpaper Picker$" },
    float  = true,
    center = true,
    size   = "68% 76%",
})

-- Wallpaper source / auth dialogs — flat style
hl.window_rule({
    name  = "wallpaper-source-flat",
    match = { title = "^Choose wallpaper source$" },
    rounding    = 0,
    border_size = 0,
})

hl.window_rule({
    name  = "auth-mount-flat",
    match = { title = "^Authentication is required to mount.*$" },
    rounding    = 0,
    border_size = 0,
})

hl.window_rule({
    name  = "auth-required-flat",
    match = { title = "^Authentication required.*$" },
    rounding    = 0,
    border_size = 0,
})

-- Polkit agents — flat style
hl.window_rule({
    name  = "polkit-flat",
    match = { class = "^(polkit-kde-authentication-agent-1|org\\.kde\\.polkit-kde-authentication-agent-1|polkit-gnome-authentication-agent-1|org\\.gnome\\.PolkitAuthenticationAgent|polkit-qt-1-authentication-agent-1)$" },
    rounding    = 0,
    border_size = 0,
})

-- Crop wallpaper dialog
hl.window_rule({
    name  = "crop-wallpaper",
    match = { title = "^Crop Wallpaper.*$" },
    float  = true,
    center = true,
    size   = "84% 88%",
})

-- Calendar popup
hl.window_rule({
    name  = "calendar-popup",
    match = { title = "^ArchMerOS Calendar$" },
    float   = true,
    center  = true,
    size    = "28% 38%",
    opacity = "0.98 0.98",
})

-- Screensaver
hl.window_rule({
    name  = "screensaver",
    match = { class = "^(ArchMerOS-Screensaver)$" },
    float   = true,
    opacity = "1.0 1.0",
})

-- Side monitor blackout
hl.window_rule({
    name  = "side-blackout",
    match = { class = "^(archmeros-side-blackout)$" },
    workspace  = "8 silent",
    float      = true,
    fullscreen = 1,
    opacity    = "1.0 1.0",
})

-- WezTerm terminal opacity
hl.window_rule({
    name  = "wezterm-opacity",
    match = { class = "(org\\.wezfurlong\\.wezterm)" },
    opacity = tp.terminal_active_opacity .. " " .. tp.terminal_inactive_opacity,
})

-- Custom WezTerm instances
hl.window_rule({
    name  = "wezterm-custom-opacity",
    match = { class = "^(archmeros-wezterm-.*)$" },
    opacity = tp.terminal_active_opacity .. " " .. tp.terminal_inactive_opacity,
})

-- Code editors
hl.window_rule({
    name  = "code-editor-opacity",
    match = { class = "(code|codium|Code|Codium)" },
    opacity = tp.code_active_opacity .. " " .. tp.code_inactive_opacity,
})

-- ChatGPT webapp
hl.window_rule({
    name  = "chatgpt-float",
    match = { class = "^(archmeros-chatgpt)$" },
    float   = true,
    size    = "72% 76%",
    center  = true,
    opacity = tp.walker_active_opacity .. " " .. tp.walker_inactive_opacity,
})

-- Gemini webapp
hl.window_rule({
    name  = "gemini-float",
    match = { class = "^(archmeros-gemini)$" },
    float   = true,
    size    = "72% 76%",
    center  = true,
    opacity = tp.walker_active_opacity .. " " .. tp.walker_inactive_opacity,
})

-- AIChat float terminal
hl.window_rule({
    name  = "aichat-float",
    match = { class = "^(archmeros-aichat-float)$" },
    float   = true,
    center  = true,
    size    = "72% 76%",
    opacity = tp.terminal_active_opacity .. " " .. tp.terminal_inactive_opacity,
})

-- AIChat sessions picker
hl.window_rule({
    name  = "aichat-sessions",
    match = { class = "^(archmeros-aichat-sessions)$" },
    float   = true,
    center  = true,
    size    = "72% 76%",
    opacity = tp.terminal_active_opacity .. " " .. tp.terminal_inactive_opacity,
})

-- Fabric browser
hl.window_rule({
    name  = "fabric-browser",
    match = { class = "^(archmeros-fabric-browser)$" },
    float   = true,
    center  = true,
    size    = "74% 82%",
    opacity = tp.terminal_active_opacity .. " " .. tp.terminal_inactive_opacity,
})

-- YouTube Music auto-workspace
hl.window_rule({
    name  = "youtube-music-ws9",
    match = { title = "^(.* - )?YouTube Music$" },
    workspace = "9 silent",
})

-- Todoist auto-workspace
hl.window_rule({
    name  = "todoist-ws5",
    match = { class = "^(archmeros-todoist|com\\.todoist\\.Todoist|Todoist)$" },
    workspace = "5 silent",
})

--------------------------
---- LAYER RULES ---------
--------------------------
hl.layer_rule({ name = "waybar-blur",        match = { namespace = "^(waybar)$" },        blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ name = "notifications-blur",  match = { namespace = "^(notifications)$" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ name = "walker-blur",         match = { namespace = "^(walker)$" },        blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ name = "rofi-blur",           match = { namespace = "^(rofi)$" },          blur = true, ignore_alpha = 0.15 })
