---------------------
---- KEYBINDINGS ----
---------------------

-- Main modifier key
local mainMod = "SUPER"

-- Application variables
local terminal = "ghostty"
local fileManager = "thunar"
local browser = "brave"
local menu = "rofi -show drun -theme ~/.config/rofi/spotlight.rasi"
local vm = "vmware"
local editor = "code"
local chrome = "google-chrome-stable"
local notes = "obsidian"
local draw = "/opt/brave-bin/brave --profile-directory=Default --app-id=dnfpoenibinnbbckgbhendmlljoobcfg"
local rec = "obs"

-- Application Keybindings
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(notes))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(chrome))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(vm))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(draw))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(rec))

-- Window Control
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.float({
    action = "toggle"
}))

-- Screenshot with slurp
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(
    "mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" - | " ..
    "tee ~/Pictures/Screenshots/s-$(date +%d%m%y-%H%M%S).png | wl-copy"
))

-- Shutdown/Exit
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(
    "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"
))

-- Brightness Control
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), {
    locked = true,
    repeating = true
})

-- Volume Control
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"), {
    locked = true,
    repeating = true
})

-- Focus switching
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

-- Move Window within workspace
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

-- Workspace Navigation (1-9)
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({
        workspace = i
    }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({
        workspace = i
    }))
end
