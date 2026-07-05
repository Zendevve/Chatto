local AddonName, ns = ...
local Chatto = _G[AddonName]

local Status = Chatto:NewModule("Status", "AceEvent-3.0")

local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

local G = {
	CLEARED_AFK = CLEARED_AFK,
	CLEARED_DND = CLEARED_DND,
	DEFAULT_AFK_MESSAGE = DEFAULT_AFK_MESSAGE,
	DEFAULT_DND_MESSAGE = DEFAULT_DND_MESSAGE,
	MARKED_AFK = MARKED_AFK,
	MARKED_AFK_MESSAGE = MARKED_AFK_MESSAGE,
	MARKED_DND = MARKED_DND,
	EXHAUSTION_NORMAL = ERR_EXHAUSTION_NORMAL,
	EXHAUSTION_WELLRESTED = ERR_EXHAUSTION_WELLRESTED,
}

local P = Chatto:MakePatternCache()

local function FilterStatusEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.status then return end

	-- AFK
	if message == G.MARKED_AFK then
		return false, Chatto.out.afk_added, author, ...
	end
	if message == G.CLEARED_AFK then
		return false, Chatto.out.afk_cleared, author, ...
	end
	local afk_message = string_match(message, P[G.MARKED_AFK_MESSAGE])
	if afk_message then
		if afk_message == G.DEFAULT_AFK_MESSAGE then
			return false, Chatto.out.afk_added, author, ...
		end
		return false, string_format(Chatto.out.afk_added_message, afk_message), author, ...
	end

	-- DND
	if message == G.CLEARED_DND then
		return false, Chatto.out.dnd_cleared, author, ...
	end
	local dnd_message = string_match(message, P[G.MARKED_DND])
	if dnd_message then
		if dnd_message == G.DEFAULT_DND_MESSAGE then
			return false, Chatto.out.dnd_added, author, ...
		end
		return false, string_format(Chatto.out.dnd_added_message, dnd_message), author, ...
	end

	-- Rested
	if message == G.EXHAUSTION_WELLRESTED then
		return false, Chatto.out.rested_added, author, ...
	end
	if message == G.EXHAUSTION_NORMAL then
		return false, Chatto.out.rested_cleared, author, ...
	end

	-- Arena Points (Ascension)
	if string_find(message, "Arena Points") then
		local amount = string_match(message, "received (%d+) Arena Points")
		local current, cap = string_match(message, "Cap: %((%d+)/(%d+)%)")
		if amount and current and cap then
			local line1 = string_format(Chatto.out.arena_points, tonumber(amount))
			local line2 = string_format(Chatto.out.arena_points_status, tonumber(current), tonumber(cap))
			return false, line1 .. "\n" .. line2, author, ...
		end
	end

	-- Glory (Ascension)
	local cleanMessage = string_gsub(message, "|[cC]%x%x%x%x%x%x%x%x", "")
	cleanMessage = string_gsub(cleanMessage, "|r", "")
	if string_find(cleanMessage, "Glory") then
		local amount = string_match(cleanMessage, "gained (%d+) Glory")
		local needed = string_match(cleanMessage, "(%d+) Glory needed")
		if amount then
			local line1 = string_format(Chatto.out.glory, tonumber(amount))
			if needed then
				local line2 = string_format(Chatto.out.glory_progress, tonumber(needed))
				return false, line1 .. "\n" .. line2, author, ...
			end
			return false, line1, author, ...
		end
	end
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterStatusEvent(Status, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Status:OnInitialize()
end

function Status:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end

function Status:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end
