local json = require("hyprland.lua.utils.dkjson")

local config_dir = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local json_dir = config_dir .. "/hypr/hyprland/json/"

local defaults = {
	["decoration.json"] = {
		rounded_corners = true,
		blur = { enabled = true },
		shadow = { enabled = true },
	},
	["general.json"] = {
		big_gaps_out = false,
		gaps_out = { top = 45, bottom = 45, left = 45, right = 45 },
	},
	["powersaver.json"] = { enabled = false },
	["rules.json"] = { windowrules = { xray = true } },
	["monitors.json"] = {},
}

local json_dir_ready = false

local function ensure_json_dir()
	if json_dir_ready then
		return
	end
	local quoted = json_dir:gsub("'", "'\\''")
	os.execute("mkdir -p '" .. quoted .. "'")
	json_dir_ready = true
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = copy(v)
	end
	return result
end

local function resolve(path)
	if path:sub(1, 1) == "/" or path:sub(1, 1) == "~" or path:sub(1, 5) == "$HOME" then
		return path
	end
	return json_dir .. path
end

local function save(path, data)
	local encoded = json.encode(data, { indent = true })
	if not encoded then
		return
	end

	local f = io.open(resolve(path), "w")
	if not f then
		return
	end

	if type(encoded) == "string" then
		f:write(encoded)
	end
	f:close()
end

local M = {}

function M.load(path)
	local f = io.open(resolve(path), "r")
	if not f then
		local default = defaults[path]
		if default then
			ensure_json_dir()
			default = copy(default)
			save(path, default)
			return default
		end
		return {}
	end
	local content = f:read("*a")
	f:close()
	return json.decode(content) or {}
end

function M.set(path, key, value)
	local data = M.load(path)
	if key then
		data[key] = value
	else
		data = value
	end
	save(path, data)
end

function M.set_where(path, field, value, patch)
	local data = M.load(path)
	if not data then
		return
	end

	for _, entry in ipairs(data) do
		if entry[field] == value then
			for k, v in pairs(patch) do
				entry[k] = v
			end
		end
	end
	save(path, data)
end

return M
