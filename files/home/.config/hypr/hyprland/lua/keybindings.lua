-- ========================================
--              KEYBINDINGS
-- ========================================

local json = require("hyprland.lua.utils.json")
local wk = require("hyprland.lua.utils.workspaces")

local workspaces = {
	["1"] = 1,
	["2"] = 2,
	["3"] = 3,
	["4"] = 4,
	["5"] = 5,
	["6"] = 6,
	["7"] = 7,
	["8"] = 8,
	["9"] = 9,
	["0"] = "last",
	["L"] = "next",
	["H"] = "previous",
	["MINUS"] = "new",
	["GRAVE"] = "back",
}

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("kitty"), { description = "Launch terminal", repeating = true })
hl.bind("SUPER + CONTROL + RETURN", hl.dsp.exec_cmd("kitty", { float = true }), { description = "Launch floating terminal" })
-- hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("kitty $BN_SCRIPTS/tmux-main"), { description = "Launch main tmux session" })
-- hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("ghostty"), { description = "Launch terminal", repeating = true })
-- hl.bind("SUPER + CONTROL + RETURN", hl.dsp.exec_cmd("ghostty --gtk-single-instance=false", { float = true }), { description = "Launch floating terminal" })
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("ghostty -e $BN_SCRIPTS/tmux-main"), { description = "Launch main tmux session" })

hl.bind("SUPER + SPACE", hl.dsp.global("quickshell:launcher-toggle"), { description = "Toggle launcher" })
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"), { description = "Open file manager" })
hl.bind("SUPER + SHIFT + E", hl.dsp.global("quickshell:launcher-files"), { description = "Browse files" })
hl.bind("SUPER + V", hl.dsp.global("quickshell:launcher-clipboard"), { description = "Open clipboard manager" })
hl.bind("SUPER + K", hl.dsp.global("quickshell:launcher-keybinds"), { description = "Show keybindings" })
hl.bind("SUPER + N", hl.dsp.global("quickshell:launcher-tasks"), { description = "Open Todos" })
hl.bind("SUPER + D", hl.dsp.global("quickshell:launcher-monitors"), { description = "Open display settings" })
hl.bind("SUPER + C", hl.dsp.exec_cmd("qs ipc call colorpicker hex"), { description = "Pick color" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc call settings toggle hideTopBar"), { description = "Toggle bar visibility" })
hl.bind("SUPER + W", hl.dsp.global("quickshell:launcher-wallpaper"), { description = "Select wallpaper" })
hl.bind("SUPER + U", hl.dsp.global("quickshell:launcher-unsplash"), { description = "Unsplash" })
hl.bind("SUPER + A", hl.dsp.global("quickshell:launcher-wallhaven"), { description = "Wallhaven" })
hl.bind("SUPER + CONTROL + W", hl.dsp.exec_cmd("$BN_SCRIPTS/select-wallpaper --random"), { description = "Random wallpaper" })
hl.bind("SUPER + CONTROL + R", hl.dsp.exec_cmd("$BN_SCRIPTS/qs-nothp kill; $BN_SCRIPTS/qs-nothp"), { description = "Restart Quickshell" })
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:bar-resources"), { description = "Toggle bar resources module" })
hl.bind("SUPER + SHIFT + P", hl.dsp.global("quickshell:bar-mpris"), { description = "Toggle bar media module" })
hl.bind("SUPER + SHIFT + D", hl.dsp.global("quickshell:bar-datetime"), { description = "Toggle bar date/time module" })
hl.bind("SUPER + SHIFT + W", hl.dsp.global("quickshell:bar-weather"), { description = "Toggle bar weather module" })
hl.bind("SUPER + SHIFT + C", hl.dsp.global("quickshell:bar-controlcenter"), { description = "Toggle bar control center module" })
hl.bind("SUPER + SHIFT + B", hl.dsp.global("quickshell:bar-battery"), { description = "Toggle bar battery module" })
hl.bind("SUPER + SHIFT + T", hl.dsp.global("quickshell:launcher-translate"), { description = "Translate" })
hl.bind("SUPER + SHIFT + Q", hl.dsp.global("quickshell:launcher-processes"), { description = "Kill process selector" })
hl.bind("SUPER + PERIOD", hl.dsp.global("quickshell:launcher-emojis"), { description = "Emoji picker" })
hl.bind("XF86Calculator", hl.dsp.global("quickshell:launcher-calculator"), { repeating = true })

hl.bind("SUPER + S", hl.dsp.layout("swapsplit"), { description = "Swap split" })
hl.bind("SUPER + Y", hl.dsp.layout("togglesplit"), { description = "Toggle window split" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close window", repeating = true })
hl.bind("SUPER + T", function()
	hl.dispatch(hl.dsp.window.float())
	local active_window = hl.get_active_window()
	if active_window and active_window.floating and active_window.initial_class ~= "Emulator" then
		hl.dispatch(hl.dsp.window.resize({ x = 1326, y = 747, relative = false }))
	end
	hl.dispatch(hl.dsp.window.center())
end, { description = "Toggle floating" })
hl.bind("SUPER + EQUAL", hl.dsp.window.center(), { description = "Center window" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Toggle maximized" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Toggle fullscreen" })
hl.bind("SUPER + X", function()
	local powersaver_json = json.load("powersaver.json")
	if powersaver_json.enabled then
		return
	end
	local windowrules = json.load("rules.json").windowrules
	windowrules.xray = not windowrules.xray
	json.set("rules.json", "windowrules", windowrules)
end, { description = "Toggle windows x-ray mode" })
hl.bind("SUPER + SHIFT + X", function()
	local powersaver_json = json.load("powersaver.json")
	if powersaver_json.enabled then
		return
	end
	hl.dispatch(hl.dsp.exec_cmd([[ sh -c '[ "$(qs ipc call settings get transparentize)" = "true" ] && qs ipc call settings set transparentize false || qs ipc call settings set transparentize true' ]]))
end, { description = "Toggle layer x-ray mode" })

hl.bind("SUPER + CONTROL + P", function()
	local w = hl.get_active_window()
	local mon = hl.get_active_monitor()
	if w == nil or mon == nil then
		return
	end
	local pip = not w.pinned
	local border = pip and 0 or "unset"
	local rounding = pip and (hl.get_config("decoration.rounding") - 6) or "unset"
	if pip and not w.floating then
		hl.dispatch(hl.dsp.window.float({ action = "set" }))
	end
	if not pip then
		hl.dispatch(hl.dsp.window.float({ action = "unset" }))
	end
	hl.dispatch(hl.dsp.window.pin({ action = pip and "set" or "unset" }))
	hl.dispatch(hl.dsp.window.set_prop({ prop = "border_size", value = border }))
	hl.dispatch(hl.dsp.window.set_prop({ prop = "rounding", value = rounding }))
	if pip then
		local pip_w = 581
		local pip_h = pip_w / 16 * 9
		hl.dispatch(hl.dsp.window.resize({ x = pip_w - w.size.x, y = pip_h - w.size.y, relative = true }))
		hl.dispatch(hl.dsp.window.move({ x = mon.position.x + mon.size.width - pip_w - 16, y = mon.position.y + 46, relative = false }))
	end
	hl.dispatch(hl.dsp.exec_cmd("qs ipc call popup showInfo 'Picture-in-Picture " .. (pip and "On" or "Off") .. "' '' 3000"))
end, { description = "Toggle Picture-in-Picture mode" })

-- Move
hl.bind("SUPER + CONTROL + H", hl.dsp.window.move({ direction = "left" }), { description = "Move window left", repeating = true })
hl.bind("SUPER + CONTROL + J", hl.dsp.window.move({ direction = "down" }), { description = "Move window down", repeating = true })
hl.bind("SUPER + CONTROL + K", hl.dsp.window.move({ direction = "up" }), { description = "Move window up", repeating = true })
hl.bind("SUPER + CONTROL + L", hl.dsp.window.move({ direction = "right" }), { description = "Move window right", repeating = true })

-- Focus
hl.bind("SUPER + ALT + H", hl.dsp.focus({ direction = "left" }), { description = "Focus window left", repeating = true })
hl.bind("SUPER + ALT + J", hl.dsp.focus({ direction = "down" }), { description = "Focus window down", repeating = true })
hl.bind("SUPER + ALT + K", hl.dsp.focus({ direction = "up" }), { description = "Focus window up", repeating = true })
hl.bind("SUPER + ALT + L", hl.dsp.focus({ direction = "right" }), { description = "Focus window right", repeating = true })

-- Resize
hl.bind("SUPER + SHIFT + ALT + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { description = "Resize window left", repeating = true })
hl.bind("SUPER + SHIFT + ALT + J", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { description = "Resize window down", repeating = true })
hl.bind("SUPER + SHIFT + ALT + K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { description = "Resize window up", repeating = true })
hl.bind("SUPER + SHIFT + ALT + L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { description = "Resize window right", repeating = true })

for key, ws in pairs(workspaces) do
	hl.bind("SUPER + " .. key, wk:go(ws), { description = "Go to workspace " .. ws, repeating = true })
end
for key, ws in pairs(workspaces) do
	hl.bind("SUPER + SHIFT + " .. key, wk:move(ws, true), { description = "Move to workspace " .. ws, repeating = true })
end
for key, ws in pairs(workspaces) do
	hl.bind("SUPER + CONTROL + SHIFT + " .. key, wk:move(ws, false), { description = "Move silently to workspace " .. ws, repeating = true })
end

hl.bind("SUPER + M", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })
hl.bind("SUPER + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic", follow = true }), { description = "Move to scratchpad (follow)" })
hl.bind("SUPER + CONTROL + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic", follow = false }), { description = "Move to scratchpad silently" })

hl.bind("SUPER + CONTROL + B", function()
	local powersaver_json = json.load("powersaver.json")
	if powersaver_json.enabled then
		return
	end
	local blur = json.load("decoration.json").blur
	blur.enabled = not blur.enabled
	json.set("decoration.json", "blur", blur)
end, { description = "Toggle blur" })

hl.bind("SUPER + G", function()
	local general = json.load("general.json")
	general.big_gaps_out = not general.big_gaps_out
	json.set("general.json", nil, general)
end, { description = "Toggle gaps" })

hl.bind("SUPER + CONTROL + SHIFT + O", function()
	hl.dispatch(hl.dsp.dpms({ action = "toggle" }))
	hl.dispatch(hl.dsp.exec_cmd("qs ipc call hyprland setDPMS " .. tostring(hl.get_active_monitor().dpms_status)))
end, { description = "Toggle monitor power" })

hl.bind("SUPER + DELETE", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock screen" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs ipc call screencapture region"), { description = "Screenshot selection" })

hl.bind("SUPER + CONTROL + EQUAL", function()
	local zoom_factor = hl.get_config("cursor.zoom_factor")
	hl.config({ cursor = { zoom_factor = math.floor(zoom_factor * 10 + 0.5 + 1) / 10 } })
end, { description = "Cursor zoom in", repeating = true })

hl.bind("SUPER + CONTROL + MINUS", function()
	local zoom_factor = hl.get_config("cursor.zoom_factor")
	if math.floor(zoom_factor * 10 + 0.5 - 1) >= 10 then
		hl.config({ cursor = { zoom_factor = math.floor(zoom_factor * 10 + 0.5 - 1) / 10 } })
	end
end, { description = "Cursor zoom out", repeating = true })
hl.bind("SUPER + CONTROL + 0", function()
	hl.config({ cursor = { zoom_factor = 1.0 } })
end, { description = "Reset cursor zoom" })

hl.bind("ALT + TAB", hl.dsp.global("quickshell:alttab-next"), { description = "Window switcher next", repeating = true })
hl.bind("ALT + SHIFT + TAB", hl.dsp.global("quickshell:alttab-previous"), { description = "Window switcher previous", repeating = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call volume increaseVolume 0.05 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit $(awk '{print ($2 >= 1.0) ? 1.5 : 1.0}' <<< $(wpctl get-volume @DEFAULT_AUDIO_SINK@))"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call volume decreaseVolume 0.05 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit $(awk '{print ($2 >= 1.0) ? 1.5 : 1.0}' <<< $(wpctl get-volume @DEFAULT_AUDIO_SINK@))"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs ipc call volume toggleVolumeMute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("qs ipc call volume toggleMicMute || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call brightness increment 0.05 || brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call brightness decrement 0.05 || brightnessctl s 5%-"), { locked = true, repeating = true })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
