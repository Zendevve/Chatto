local AddonName, ns = ...
local Chatto = _G[AddonName]

local Reputation = Chatto:NewModule("Reputation", "AceEvent-3.0")

local string_format = string.format
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local tonumber = tonumber
local ipairs = ipairs
local next = next

local G = {
	INCREASED = FACTION_STANDING_INCREASED,
	DECREASED = FACTION_STANDING_DECREASED,
	INCREASED_GENERIC = FACTION_STANDING_INCREASED_GENERIC,
	DECREASED_GENERIC = FACTION_STANDING_DECREASED_GENERIC,
	REPUTATION = REPUTATION or "Reputation",
}

local P = Chatto:MakePatternCache()

local function FixArgs(...)
	local str, num
	for i = 1, select("#", ...) do
		local val = select(i, ...)
		local n = tonumber(val)
		if n and n > 0 then
			num = n
		elseif not n then
			str = val
		end
	end
	return str, num
end

-- Buffering for grouping reputation changes of same value in same frame
local repBuffer = Chatto:CreateFrameBuffer(function()
	return { order = {}, byValue = {} }
end, function(chatFrame, buf)
	for _, value in ipairs(buf.order) do
		local factions = buf.byValue[value]
		if factions then
			local text = string_format(Chatto.out.standing, value, G.REPUTATION, table_concat(factions, ", "))
			Chatto:PrintToFrame(chatFrame, text, "CHAT_MSG_COMBAT_FACTION_CHANGE")
		end
	end
end)

local function FilterRepEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.reputation then return end

	local faction, value

	faction, value = FixArgs(string_match(message, P[G.INCREASED]))
	if faction then
		if value then
			if C_Timer and C_Timer.After and chatFrame and chatFrame.AddMessage then
				local buf = repBuffer.Get(chatFrame)
				if not buf.byValue[value] then
					buf.byValue[value] = {}
					table_insert(buf.order, value)
				end
				table_insert(buf.byValue[value], faction)
				repBuffer.Schedule(chatFrame)
				return true -- Suppress individual lines, wait for consolidated flush
			end
			return false, string_format(Chatto.out.standing, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(Chatto.out.standing_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction, value = FixArgs(string_match(message, P[G.DECREASED]))
	if faction then
		if value then
			return false, string_format(Chatto.out.standing_deficit, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(Chatto.out.standing_deficit_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction = FixArgs(string_match(message, P[G.INCREASED_GENERIC]))
	if faction then
		return false, string_format(Chatto.out.standing_generic, G.REPUTATION, faction), author, ...
	end

	faction = FixArgs(string_match(message, P[G.DECREASED_GENERIC]))
	if faction then
		return false, string_format(Chatto.out.standing_deficit_generic, G.REPUTATION, faction), author, ...
	end
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterRepEvent(Reputation, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Reputation:OnInitialize()
	-- Filters registered for AddMessage if needed, but Event Filter is cleaner
end

function Reputation:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", OnChatEventProxy)
end

function Reputation:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", OnChatEventProxy)
end
