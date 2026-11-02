local fuzzy = require("hyprland.lua.utils.fuzzy")

local M = {}

function M:focus(query)
	local w = fuzzy.find(query, hl.get_windows(), function(x)
		return x.class .. " " .. x.title
	end)

	if w then
		hl.dispatch(hl.dsp.focus({ window = w }))
	end
end

return M
