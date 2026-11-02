-- ========================================
--               MONITORS
-- ========================================

local json = require("hyprland.lua.utils.json")
local monitors_json = json.load("monitors.json")

if type(monitors_json) == "table" then
	for _, monitor in ipairs(monitors_json) do
		hl.monitor(monitor)
	end
end
