local AddonName, ns = ...
local Chatto = _G[AddonName]

-- Compiled pattern caches
local string_gsub = string.gsub
local string_match = string.match
local rawset = rawset
local rawget = rawget
local setmetatable = setmetatable
local type = type

-- Pattern compiler
function Chatto:MakePattern(msg)
	if (not msg) or (msg == "") then
		return nil
	end
	-- Escape regex magic chars except %d and %s templates
	msg = string_gsub(msg, "%%([%d%$]-)d", "(%%d+)")
	msg = string_gsub(msg, "%%([%d%$]-)s", "(.+)")
	return msg
end

function Chatto:MakePatternCache()
	return setmetatable({}, {
		__index = function(t, k)
			if (k == nil) or (k == "") then
				return nil
			end
			rawset(t, k, Chatto:MakePattern(k))
			return rawget(t, k)
		end,
	})
end

function Chatto:SafeMatch(msg, pattern)
	if not pattern or not msg then
		return nil
	end
	return string_match(msg, pattern)
end

function Chatto:StripBrackets(s)
	if not s then return s end
	return (string_gsub(s, "[%[/%]]", ""))
end

function Chatto:PrintToFrame(chatFrame, msg, chatType)
	if (not chatFrame) or not chatFrame.AddMessage or not msg then
		return
	end
	local info = chatType and ChatTypeInfo and ChatTypeInfo[chatType]
	if info then
		chatFrame:AddMessage(msg, info.r, info.g, info.b)
	else
		chatFrame:AddMessage(msg)
	end
end

-- Frame Buffer for event aggregation (Quest Turn-in reward collapse)
function Chatto:CreateFrameBuffer(newState, flush)
	local buffers = {}

	local function get(chatFrame)
		local buf = buffers[chatFrame]
		if not buf then
			buf = newState()
			buf.scheduled = false
			buffers[chatFrame] = buf
		end
		return buf
	end

	local function schedule(chatFrame)
		local buf = get(chatFrame)
		if buf.scheduled then
			return
		end
		buf.scheduled = true

		local function run()
			local b = buffers[chatFrame]
			if not b then
				return
			end
			buffers[chatFrame] = nil
			flush(chatFrame, b)
		end

		if C_Timer and C_Timer.After then
			C_Timer.After(0, run)
		else
			run()
		end
	end

	return { Get = get, Schedule = schedule }
end

-- Class colored string formatter
function Chatto:GetClassColoredName(name, class)
	if not name or name == "" then return name end
	local color = Chatto.Colors.class[class or "UNKNOWN"] or Chatto.Colors.class.UNKNOWN
	return color.colorCode .. name .. "|r"
end

-- Item colored string formatter
function Chatto:GetItemQualityColoredName(name, quality)
	if not name or name == "" then return name end
	local color = Chatto.Colors.quality[quality or 1] or Chatto.Colors.white
	return color.colorCode .. name .. "|r"
end
