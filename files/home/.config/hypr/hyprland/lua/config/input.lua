-- ========================================
--                  INPUT
-- ========================================

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "altgr-intl",
		kb_options = "caps:escape",
		follow_mouse = true,
		repeat_rate = 50,
		repeat_delay = 250,
		accel_profile = "adaptive",
		sensitivity = 0.175,
		-- accel_profile = "adaptive", -- flat / adaptive
		-- sensitivity = 0.125, -- 0.85 (flat) / 0.125 (adaptive)

		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
		},
	},
})
