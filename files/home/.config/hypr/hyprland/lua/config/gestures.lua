-- ========================================
--               GESTURES
-- ========================================

hl.config({
	gestures = {
		workspace_swipe_distance = 300,
		workspace_swipe_create_new = true,
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 3,
	direction = "up",
	action = function()
		if hl.get_active_special_workspace() == nil then
			hl.dispatch(hl.dsp.workspace.toggle_special("magic"))
		end
	end,
	-- action = "special",
	-- workspace_name = "magic",
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
		if hl.get_active_special_workspace() ~= nil then
			hl.dispatch(hl.dsp.workspace.toggle_special("magic"))
		end
	end,
	-- action = "special",
	-- workspace_name = "magic",
})

hl.gesture({
	fingers = 4,
	direction = "swipe",
	action = "move",
})

-- hl.gesture({ fingers = 2, direction = "pinchin", action = "cursorZoom", zoom_level = 1.2, mode = "mult" })
-- hl.gesture({ fingers = 2, direction = "pinchout", action = "cursorZoom", zoom_level = 0.8, mode = "mult" })
