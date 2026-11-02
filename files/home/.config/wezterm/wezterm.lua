local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Font
config.font_size = 13.5
config.font = wezterm.font({
	family = "JetBrainsMono Nerd Font",
	weight = "Medium",
})

-- Window size
config.initial_cols = 122
config.initial_rows = 32

-- Window decorations & frame
config.window_decorations = "NONE"
config.window_frame = {
	border_left_width = "0pt",
	border_right_width = "0pt",
	border_top_height = "0pt",
	border_bottom_height = "0pt",
	font = wezterm.font({ family = "JetBrainsMono Nerd Font", weight = "Bold" }),
}
config.window_padding = {
	left = 4,
	right = 4,
	top = 4,
	bottom = 4,
}
config.window_close_confirmation = "NeverPrompt"

-- Appearance
config.underline_position = -3
config.underline_thickness = "200%"
config.audible_bell = "Disabled"
config.enable_scroll_bar = false
config.enable_tab_bar = false

-- Cursor
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- Platform
config.enable_wayland = true

-- Keybindings
config.keys = {
	{ key = "t", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{ key = "Backspace", mods = "CTRL", action = wezterm.action.SendString("\x17") },
}

-- Mouse / scroll
local act = wezterm.action
config.mouse_bindings = {
	{
		event = { Down = { streak = 1, button = { WheelUp = 1 } } },
		mods = "NONE",
		action = act.ScrollByLine(-1),
		alt_screen = true,
	},
	{
		event = { Down = { streak = 1, button = { WheelDown = 1 } } },
		mods = "NONE",
		action = act.ScrollByLine(1),
		alt_screen = true,
	},
}

-- Colors
local ok, colors = pcall(dofile, wezterm.config_dir .. "/colors.lua")
-- local ok, colors = pcall(dofile, wezterm.config_dir .. "/themes/ayu.lua")
if ok and type(colors) == "table" then
	config.colors = colors
end

return config
