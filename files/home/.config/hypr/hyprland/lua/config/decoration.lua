-- ========================================
--                DECORATION
-- ========================================

local json = require("hyprland.lua.utils.json")
local decoration_json = json.load("decoration.json")
local powersaver_json = json.load("powersaver.json")

hl.config({
	decoration = {
		rounding = decoration_json.rounded_corners and 18 or 0,
		rounding_power = 2.0,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		dim_inactive = false,
		dim_strength = 0.045,
		dim_special = 0.07,

		shadow = {
			enabled = decoration_json.shadow.enabled and not powersaver_json.enabled,
			range = 50,
			render_power = 4,
			color = "0x48000000",
		},

		blur = {
			enabled = decoration_json.blur.enabled and not powersaver_json.enabled,
			size = 8,
			passes = 2,
			noise = 0.125,
			vibrancy = 0.2,
			brightness = 0.85,
			contrast = 1.3,
			special = true,
			new_optimizations = true,
			popups = true,
			ignore_opacity = true,
			xray = false,
		},
	},
})
