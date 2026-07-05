local AddonName, ns = ...
local Chatto = _G[AddonName]

local Quests = Chatto:NewModule("Quests", "AceEvent-3.0")

local string_format = string.format
local string_match = string.match
local string_find = string.find
local table_concat = table.concat
local table_insert = table.insert
local ipairs = ipairs

local G = {
	SET_COMPLETE = ERR_COMPLETED_TRANSMOG_SET_S,
	QUEST_ACCEPTED = ERR_QUEST_ACCEPTED_S,
	QUEST_ALREADY_DONE = ERR_QUEST_ALREADY_DONE,
	QUEST_ALREADY_DONE_DAILY = ERR_QUEST_ALREADY_DONE_DAILY,
	QUEST_FAILED_TOO_MANY_DAILY = ERR_QUEST_FAILED_TOO_MANY_DAILY_QUESTS_I,
	NO_DAILY_QUESTS_REMAINING = NO_DAILY_QUESTS_REMAINING,
	QUEST_COMPLETE = ERR_QUEST_COMPLETE_S,
	QUEST = QUEST_LOG or "Quest",
	ACCEPTED = "Accepted",
	COMPLETE = "Complete",
}

local P = Chatto:MakePatternCache()

local QUEST_COMPLETE_ANCHORED = G.QUEST_COMPLETE and ("^" .. Chatto:MakePattern(G.QUEST_COMPLETE) .. "$")

-- Quest Rewards Combined Buffer
local questRewardBuffer

local function FilterQuestEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.quests then return end

	local name

	-- Transmog set complete
	if G.SET_COMPLETE then
		name = Chatto:SafeMatch(message, P[G.SET_COMPLETE])
		if name then
			return false, string_format(Chatto.out.set_complete, G.COMPLETE, Chatto:StripBrackets(name)), author, ...
		end
	end

	-- Quest accepted
	name = Chatto:SafeMatch(message, P[G.QUEST_ACCEPTED])
	if name then
		return false, string_format(Chatto.out.quest_accepted, G.ACCEPTED, Chatto:StripBrackets(name)), author, ...
	end

	-- Quest completed
	if not Chatto:SafeMatch(message, P[G.QUEST_ALREADY_DONE])
		and not Chatto:SafeMatch(message, P[G.QUEST_ALREADY_DONE_DAILY])
		and not Chatto:SafeMatch(message, P[G.QUEST_FAILED_TOO_MANY_DAILY])
		and not Chatto:SafeMatch(message, P[G.NO_DAILY_QUESTS_REMAINING]) then
		
		name = QUEST_COMPLETE_ANCHORED and string_match(message, QUEST_COMPLETE_ANCHORED)
		if name then
			return false, string_format(Chatto.out.quest_complete, G.COMPLETE, Chatto:StripBrackets(name)), author, ...
		end
	end
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterQuestEvent(Quests, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Quests:OnInitialize()
	-- Instantiate the frame buffer for quest rewards collapsing
	questRewardBuffer = Chatto:CreateFrameBuffer(function()
		return { items = {}, xp = nil, money = nil }
	end, function(chatFrame, buf)
		local parts = {}
		
		-- Items first
		for _, itemText in ipairs(buf.items) do
			parts[#parts + 1] = itemText
		end
		-- Money second
		if buf.money then
			parts[#parts + 1] = buf.money
		end
		-- XP third
		if buf.xp then
			parts[#parts + 1] = buf.xp
		end

		if #parts > 0 then
			local text = string_format(Chatto.out.quest_rewards_combined, table_concat(parts, ", "))
			Chatto:PrintToFrame(chatFrame, text, "LOOT")
		end
	end)

	-- Expose global API on Chatto object so Loot, XP, and Money can use it
	Chatto.AddQuestReward = function(core, chatFrame, rewardType, rewardText)
		if not Chatto.db.profile.filters.quests then
			return false
		end
		if not chatFrame or not chatFrame.AddMessage then
			return false
		end

		local buf = questRewardBuffer.Get(chatFrame)
		if rewardType == "item" then
			table_insert(buf.items, rewardText)
		elseif rewardType == "xp" then
			buf.xp = rewardText
		elseif rewardType == "money" then
			buf.money = rewardText
		else
			return false
		end

		questRewardBuffer.Schedule(chatFrame)
		return true
	end
end

function Quests:OnEnable()
	self:RegisterEvent("CHAT_MSG_SYSTEM", function(event, ...)
		local block, newMsg = FilterQuestEvent(self, DEFAULT_CHAT_FRAME, event, ...)
		if block then return end
		-- Chat event filters handle it natively on other frames, but this is a fallback
	end)
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end

function Quests:OnDisable()
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end
