local AddonName, ns = ...
local Chatto = _G[AddonName]

local Experience = Chatto:NewModule("Experience", "AceEvent-3.0")

local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local next = next

local G = {
	ERR_ZONE_EXPLORED_XP = ERR_ZONE_EXPLORED_XP,
	ERR_QUEST_REWARD_EXP_I = ERR_QUEST_REWARD_EXP_I,
	XP = XP or "XP",
	NAMED = COMBATLOG_XPGAIN_FIRSTPERSON,
	UNNAMED = COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED,
	LEVEL_UP = LEVEL_UP,
}

local P = Chatto:MakePatternCache()

if G.LEVEL_UP then
	P[G.LEVEL_UP] = string_gsub(G.LEVEL_UP, "(|.+|r)", "(.+)")
end

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
	return num, str
end

local function FilterXPEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.experience then return end

	local value, source
	if event == "CHAT_MSG_COMBAT_XP_GAIN" then
		value, source = FixArgs(string_match(message, P[G.NAMED]))
		if value then
			return false, string_format(Chatto.out.xp_named, value, G.XP, source), author, ...
		end

		value = string_match(message, P[G.UNNAMED])
		if value then
			if Chatto.db.profile.filters.quests and chatFrame then
				local rewardText = string_format("|cffffffff%s|r |cffffffff%s|r", value, G.XP)
				if Chatto.AddQuestReward and Chatto:AddQuestReward(chatFrame, "xp", rewardText) then
					return true -- Buffered
				end
			end
			return false, string_format(Chatto.out.xp_unnamed, value, G.XP), author, ...
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		-- Zone explored
		value, source = FixArgs(Chatto:SafeMatch(message, P[G.ERR_ZONE_EXPLORED_XP]))
		if value then
			return false, string_format(Chatto.out.xp_named, value, G.XP, source), author, ...
		end

		-- Level up
		if G.LEVEL_UP then
			value = Chatto:SafeMatch(message, P[G.LEVEL_UP])
			if value then
				return false, string_format(Chatto.out.xp_levelup, Chatto:StripBrackets(value)), author, ...
			end
		end

		-- Fallback 3.3.5 plain text Level up
		if string_find(message, "Congratulations, you have reached level") then
			local level = string_match(message, "level (%d+)")
			if level then
				return false, string_format(Chatto.out.levelup_ding, tonumber(level)), author, ...
			end
		end

		-- Gained HP on level up
		if string_find(message, "You have gained") and string_find(message, "hit points") then
			local hp = string_match(message, "gained (%d+)")
			if hp then
				return false, string_format(Chatto.out.levelup_hp, tonumber(hp)), author, ...
			end
		end

		-- Hide talent points in system event
		if string_find(message, "You have gained") and string_find(message, "talent point") then
			return true
		end

		-- Stat increases
		if string_find(message, "increases by") then
			local stat, amount = string_match(message, "Your (%a+) increases by (%d+)")
			if stat and amount then
				return false, string_format(Chatto.out.levelup_stat, tonumber(amount), stat), author, ...
			end
		end

		-- Ascension Unspent Talent Essence
		if string_find(message, "Unspent Talent Essence") then
			return false, Chatto.out.levelup_essence, author, ...
		end

		-- Suppress Quest Reward XP Echo
		if Chatto:SafeMatch(message, P[G.ERR_QUEST_REWARD_EXP_I]) then
			return true
		end
	end
end

function Experience:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.filters.experience then return text, r, g, b end

	-- Suppress redundant Talent Points gained messages
	if text and string_find(text, "You have gained") and string_find(text, "talent point") then
		return nil
	end

	-- Run direct replacements for prints that don't trigger events
	if text then
		if string_find(text, "Congratulations, you have reached level") then
			local level = string_match(text, "level (%d+)")
			if level then
				return string_format(Chatto.out.levelup_ding, tonumber(level))
			end
		end

		if string_find(text, "gained") and string_find(text, "hit points") then
			local hp = string_match(text, "gained (%d+)")
			if hp then
				return string_format(Chatto.out.levelup_hp, tonumber(hp))
			end
		end

		if string_find(text, "increases by") then
			local stat, amount = string_match(text, "Your (%a+) increases by (%d+)")
			if stat and amount then
				return string_format(Chatto.out.levelup_stat, tonumber(amount), stat)
			end
		end

		if string_find(text, "nspent Talent Essence") then
			return Chatto.out.levelup_essence
		end
	end

	return text, r, g, b
end

function Experience:OnInitialize()
	Chatto:RegisterFilter("Experience", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 22)
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterXPEvent(Experience, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Experience:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnChatEventProxy)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end

function Experience:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnChatEventProxy)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end
