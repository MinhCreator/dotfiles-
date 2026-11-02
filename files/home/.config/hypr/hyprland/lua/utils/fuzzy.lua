local M = {}

local SCORE_GAP_LEADING = -0.005
local SCORE_GAP_TRAILING = -0.005
local SCORE_GAP_INNER = -0.01
local SCORE_MATCH_SLASH = 0.9
local SCORE_MATCH_WORD = 0.8
local SCORE_MATCH_CAPITAL = 0.7
local SCORE_MATCH_DOT = 0.6
local SCORE_DEFAULT_MATCH = 0.1

local function is_lower(c)
	return c:match("%l")
end
local function is_upper(c)
	return c:match("%u")
end

local function char_score(prev, curr)
	if prev == "/" then
		return SCORE_MATCH_SLASH
	end
	if prev == " " or prev == "_" or prev == "-" then
		return SCORE_MATCH_WORD
	end
	if prev == "." then
		return SCORE_MATCH_DOT
	end
	if is_lower(prev) and is_upper(curr) then
		return SCORE_MATCH_CAPITAL
	end
	return SCORE_DEFAULT_MATCH
end

function M.has_match(needle, haystack)
	needle = needle:lower()
	haystack = haystack:lower()
	local j = 1
	for i = 1, #haystack do
		if haystack:sub(i, i) == needle:sub(j, j) then
			j = j + 1
			if j > #needle then
				return true
			end
		end
	end
	return false
end

function M.score(needle, haystack)
	if not M.has_match(needle, haystack) then
		return -math.huge
	end
	if needle == haystack then
		return 1
	end

	local n, m = #needle, #haystack
	needle = needle:lower()
	haystack = haystack:lower()

	-- gap scores for unmatched leading/trailing chars
	local score = 0
	local j = 1
	local last_match = 0

	for i = 1, m do
		if haystack:sub(i, i) == needle:sub(j, j) then
			local prev = i > 1 and haystack:sub(i - 1, i - 1) or ""
			local curr = haystack:sub(i, i)
			if last_match == 0 then
				score = score + SCORE_GAP_LEADING * (i - 1)
			elseif last_match ~= i - 1 then
				score = score + SCORE_GAP_INNER * (i - 1 - last_match)
			end
			score = score + char_score(prev, curr)
			last_match = i
			j = j + 1
			if j > n then
				break
			end
		end
	end

	score = score + SCORE_GAP_TRAILING * (m - last_match)
	return score
end

-- Returns the single best matching item, or nil
function M.find(query, items, key)
	key = key or function(x)
		return tostring(x)
	end
	local best_score = -math.huge
	local best_item = nil
	for _, item in ipairs(items) do
		local str = key(item)
		if M.has_match(query, str) then
			local s = M.score(query, str)
			if s > best_score then
				best_score = s
				best_item = item
			end
		end
	end
	return best_item
end

return M
