local fuzzy = require("hyprland.lua.utils.fuzzy")

local M = {}

-- Internal helper to calculate the target workspace based on the action argument
local function get_target_workspace(arg, is_move)
	local active_monitor = hl.get_active_monitor()
	local active_workspace = hl.get_active_workspace()

	if not active_monitor or not active_workspace then
		return nil
	end

	local workspaces = hl.get_workspaces()
	local monitor_workspaces = {}
	local global_max_id = 0

	-- Filter and gather workspace info
	for _, ws in pairs(workspaces) do
		if ws.id >= 1 then
			if ws.id > global_max_id then
				global_max_id = ws.id
			end

			if ws.monitor.id == active_monitor.id then
				table.insert(monitor_workspaces, ws)
			end
		end
	end

	-- Sort workspaces on this monitor by ID
	table.sort(monitor_workspaces, function(a, b)
		return a.id < b.id
	end)

	local first_ws = monitor_workspaces[1]
	local last_ws = monitor_workspaces[#monitor_workspaces]

	-- Helper to find the last non-empty workspace on the current monitor
	local function get_last_non_empty()
		for i = #monitor_workspaces, 1, -1 do
			if monitor_workspaces[i].windows > 0 then
				return monitor_workspaces[i]
			end
		end
		return nil
	end

	-- Direct workspace id (m~1, m~2, etc.)
	if type(arg) == "number" then
		local target_ws = monitor_workspaces[arg]
		if target_ws and target_ws.id == active_workspace.id then
			if hl.get_active_special_workspace() ~= nil then
				return active_workspace.id
			else
				return "previous_per_monitor"
			end
		end
		return "m~" .. arg
	end

	if arg == "next" then
		-- If on the last workspace of the monitor and it's empty, stop
		if last_ws and active_workspace.id == last_ws.id and active_workspace.windows == 0 then
			return nil
		end

		local last_non_empty = get_last_non_empty()
		-- Next on the last non-empty workspace opens a new one
		if last_non_empty and active_workspace.id == last_non_empty.id then
			-- For move, only create new if there's at least one OTHER window
			local threshold = is_move and 1 or 0
			if active_workspace.windows > threshold then
				return global_max_id + 1
			end
			return nil
		else
			return "m+1"
		end
	elseif arg == "previous" then
		-- If on the first workspace of the monitor, stop
		if first_ws and active_workspace.id == first_ws.id then
			return nil
		end
		return "m-1"
	elseif arg == "last" then
		local last_non_empty = get_last_non_empty()
		return last_non_empty and last_non_empty.id or nil
	elseif arg == "back" then
		return "previous_per_monitor"
	elseif arg == "new" then
		if is_move then
			-- If on the last workspace of the monitor and it's empty, stop
			if last_ws and active_workspace.id == last_ws.id and active_workspace.windows == 0 then
				return nil
			end

			local last_non_empty = get_last_non_empty()
			if last_non_empty and active_workspace.id == last_non_empty.id then
				local threshold = is_move and 1 or 0
				if active_workspace.windows > threshold then
					return global_max_id + 1
				end
				return nil
			else
				return global_max_id + 1
			end
		else
			if active_workspace.windows > 0 then
				return global_max_id + 1
			end
		end
	end

	return nil
end

-- Focus a workspace
function M:go(arg)
	return function()
		local target = get_target_workspace(arg, false)
		if target then
			hl.dispatch(hl.dsp.focus({ workspace = target }))
		end
	end
end

-- Move active window to a workspace (follow: boolean)
function M:move(arg, follow)
	return function()
		local target = get_target_workspace(arg, true)
		if target then
			hl.dispatch(hl.dsp.window.move({ workspace = target, follow = follow }))
		end
	end
end

-- Move a window to a workspace (follow: boolean)
function M:move_win(win_query, ws_query, follow)
	local w = fuzzy.find(win_query, hl.get_windows(), function(x)
		return x.class .. " " .. x.title
	end)

	return function()
		local ws_target = get_target_workspace(ws_query, true)
		if ws_target then
			hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws_target, follow = follow }))
		end
	end
end

M.get_target_workspace = get_target_workspace
return M
