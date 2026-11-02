-- ========================================
--                GENERAL
-- ========================================

local json = require("hyprland.lua.utils.json")
local general_json = json.load("general.json")

hl.config({
	general = {
		layout = "dwindle",
		allow_tearing = true,
		locale = "en_GB",
		gaps_in = 4,
		gaps_out = general_json.big_gaps_out and general_json.gaps_out or 8,
		border_size = 1,
		no_focus_fallback = false,

		snap = {
			enabled = true,
			respect_gaps = true,
		},

		col = {
			active_border = "rgba(FFFFFF4F)",
			inactive_border = "rgba(FFFFFF1F)",
		},
	},
})
