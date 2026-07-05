local AddonName, ns = ...
local Chatto = _G[AddonName]

local Loot = Chatto:NewModule("Loot", "AceEvent-3.0", "AceHook-3.0")

local ipairs = ipairs
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber
local type = type
local pcall = pcall

-- Compile WoW system loot templates
local G = {
	HONOR_POINTS = HONOR_POINTS or "Honor Points",
	COMBATLOG_HONORAWARD = COMBATLOG_HONORAWARD,
	COMBATLOG_HONORGAIN = COMBATLOG_HONORGAIN,
	COMBATLOG_HONORGAIN_NO_RANK = COMBATLOG_HONORGAIN_NO_RANK,
	COMBATLOG_ARENAPOINTSAWARD = COMBATLOG_ARENAPOINTSAWARD,

	QUEST_LOG_RECEIVED_ITEM = "Received item: %s",
	QUEST_LOG_RECEIVED_ITEM_MULTIPLE = "Received item: %sx%d",
	QUEST_LOG_RECEIVED_COUNT_OF_ITEM = "Received %d of item: %s",

	LOOT_ROLL_YOU_WON = LOOT_ROLL_YOU_WON,
	LOOT_ROLL_WON = LOOT_ROLL_WON,
	LOOT_ROLL_PASSED_SELF = LOOT_ROLL_PASSED_SELF,
	LOOT_ROLL_PASSED = LOOT_ROLL_PASSED,
	LOOT_ROLL_PASSED_AUTO = LOOT_ROLL_PASSED_AUTO,
	LOOT_ROLL_PASSED_SELF_AUTO = LOOT_ROLL_PASSED_SELF_AUTO,
	LOOT_ROLL_GREED_SELF = LOOT_ROLL_GREED_SELF,
	LOOT_ROLL_GREED = LOOT_ROLL_GREED,
	LOOT_ROLL_NEED_SELF = LOOT_ROLL_NEED_SELF,
	LOOT_ROLL_NEED = LOOT_ROLL_NEED,
	LOOT_ROLL_DISENCHANT_SELF = LOOT_ROLL_DISENCHANT_SELF,
	LOOT_ROLL_DISENCHANT = LOOT_ROLL_DISENCHANT,
	LOOT_ROLL_ALL_PASSED = LOOT_ROLL_ALL_PASSED,
}

local P = Chatto:MakePatternCache()

local ROLL_ACTIONS = {
	{ pattern = G.LOOT_ROLL_YOU_WON, kind = "self", out = "roll_won_self" },
	{ pattern = G.LOOT_ROLL_WON, kind = "other", out = "roll_won_other", nameFirst = true },
	{ pattern = G.LOOT_ROLL_NEED_SELF, kind = "self", out = "roll_need_self" },
	{ pattern = G.LOOT_ROLL_NEED, kind = "other", out = "roll_need_other" },
	{ pattern = G.LOOT_ROLL_GREED_SELF, kind = "self", out = "roll_greed_self" },
	{ pattern = G.LOOT_ROLL_GREED, kind = "other", out = "roll_greed_other" },
	{ pattern = G.LOOT_ROLL_DISENCHANT_SELF, kind = "self", out = "roll_de_self" },
	{ pattern = G.LOOT_ROLL_DISENCHANT, kind = "other", out = "roll_de_other" },
	{ pattern = G.LOOT_ROLL_PASSED_SELF, kind = "self", out = "roll_pass_self" },
	{ pattern = G.LOOT_ROLL_PASSED, kind = "other", out = "roll_pass_other" },
	{ pattern = G.LOOT_ROLL_PASSED_SELF_AUTO, kind = "self", out = "roll_pass_self" },
	{ pattern = G.LOOT_ROLL_PASSED_AUTO, kind = "other", out = "roll_pass_other" },
}

local ROLL_RESULTS = {
	{ pattern = "Need Roll %- (%d+) for (.+) by (.+)", out = "roll_result_need" },
	{ pattern = "Greed Roll %- (%d+) for (.+) by (.+)", out = "roll_result_greed" },
	{ pattern = "Disenchant Roll %- (%d+) for (.+) by (.+)", out = "roll_result_de" },
}

local function FilterLootEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.loot then return end

	if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		return true
	elseif event == "CHAT_MSG_CURRENCY" then
		for _, pattern in ipairs(self.patterns) do
			local matchedItem = string_match(message, pattern)
			if matchedItem then
				local first, last = string_find(message, "|c(.+)|r")
				if first and last then
					local item = string_sub(message, first, last)
					item = Chatto:StripBrackets(item)
					local countString = string_sub(message, last + 1)
					local count = tonumber(string_match(countString, "(%d+)"))

					-- Check for quest rewards buffering
					if Chatto.db.profile.filters.quests and chatFrame then
						local rewardText = count and count > 1 and string_format("%s |cff9d9d9d(%d)|r", item, count) or item
						if Chatto.AddQuestReward and Chatto:AddQuestReward(chatFrame, "item", rewardText) then
							return true -- Suppress, let quest aggregator output it
						end
					end

					local formatted
					if count and count > 1 then
						formatted = string_format(Chatto.out.item_multiple, item, count)
					else
						formatted = string_format(Chatto.out.item_single, item)
					end
					return false, formatted, author, ...
				end
			end
		end
	elseif event == "CHAT_MSG_LOOT" then
		-- Check rolls first
		for _, rule in ipairs(ROLL_ACTIONS) do
			local pat = P[rule.pattern]
			if pat then
				if rule.kind == "self" then
					local item = Chatto:SafeMatch(message, pat)
					if item then
						return false, string_format(Chatto.out[rule.out], Chatto:StripBrackets(item)), author, ...
					end
				else
					local name, item = Chatto:SafeMatch(message, pat)
					if name and item then
						item = Chatto:StripBrackets(item)
						local formatted
						if rule.nameFirst then
							formatted = string_format(Chatto.out[rule.out], name, item)
						else
							formatted = string_format(Chatto.out[rule.out], item, name)
						end
						return false, formatted, author, ...
					end
				end
			end
		end

		-- Roll results
		for _, rule in ipairs(ROLL_RESULTS) do
			local roll, item, name = string_match(message, rule.pattern)
			if roll and item and name then
				return false, string_format(Chatto.out[rule.out], Chatto:StripBrackets(item), tonumber(roll), name), author, ...
			end
		end

		-- All passed
		local allPassed = Chatto:SafeMatch(message, P[G.LOOT_ROLL_ALL_PASSED])
		if allPassed then
			return false, string_format(Chatto.out.roll_all_passed, Chatto:StripBrackets(allPassed)), author, ...
		end

		-- Standard Loot
		for _, pattern in ipairs(self.patterns) do
			local results = { string_match(message, pattern) }
			if #results > 0 then
				local parsedItem, parsedCount, parsedName
				for ri, rj in ipairs(results) do
					local k = tonumber(rj)
					if k then
						table_remove(results, ri)
						parsedCount = k
						break
					end
				end

				if #results == 2 then
					for ri, rj in ipairs(results) do
						if string_find(rj, "|c%x%x%x%x%x%x%x%x|Hitem") then
							parsedItem = table_remove(results, ri)
							parsedItem = Chatto:StripBrackets(parsedItem)
							break
						end
					end
					parsedName = string_gsub(results[1], "[%[/%]]", "")
				elseif #results == 1 then
					parsedItem = Chatto:StripBrackets(results[1])
				end

				if parsedItem then
					-- Buffer quest rewards
					if not parsedName and Chatto.db.profile.filters.quests and chatFrame then
						local rewardText = parsedCount and parsedCount > 1 and string_format("%s |cff9d9d9d(%d)|r", parsedItem, parsedCount) or parsedItem
						if Chatto.AddQuestReward and Chatto:AddQuestReward(chatFrame, "item", rewardText) then
							return true -- Suppress
						end
					end

					local formatted
					if parsedCount and parsedCount > 1 then
						if parsedName then
							formatted = string_format(Chatto.out.item_multiple_other, parsedName, parsedItem, parsedCount)
						else
							formatted = string_format(Chatto.out.item_multiple, parsedItem, parsedCount)
						end
					else
						if parsedName then
							formatted = string_format(Chatto.out.item_single_other, parsedName, parsedItem)
						else
							formatted = string_format(Chatto.out.item_single, parsedItem)
						end
					end
					return false, formatted, author, ...
				end
			end
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		-- Ascension appearances collection
		local itemLink = string_match(message, "(|c%x+|Happearance:%d+|h%[.-%]|h|r)")
		if itemLink and string_find(message, "appearance collection") then
			local itemName = string_match(itemLink, "|h%[(.-)%]|h")
			if itemName then
				local _, realItemLink = GetItemInfo(itemName)
				if realItemLink then
					local coloredItem = Chatto:StripBrackets(realItemLink)
					return false, string_format(Chatto.out.appearance_added, coloredItem), author, ...
				else
					return false, string_format(Chatto.out.appearance_added, itemName), author, ...
				end
			end
		end

		-- Suppress system quest item notifications spammed duplicate to CHAT_MSG_LOOT
		local sysCount, item = Chatto:SafeMatch(message, P[G.QUEST_LOG_RECEIVED_COUNT_OF_ITEM])
		if sysCount and item then return true end

		item = Chatto:SafeMatch(message, P[G.QUEST_LOG_RECEIVED_ITEM_MULTIPLE])
		if item then return true end

		item = Chatto:SafeMatch(message, P[G.QUEST_LOG_RECEIVED_ITEM])
		if item then return true end
	end
end

-- Deletion / Destruction report
function Loot:ReportItemSold(link, count)
	if not link then return end
	local item = Chatto:StripBrackets(link)
	local msg
	if count and count > 1 then
		msg = string_format(Chatto.out.item_deficit_multiple, item, count)
	else
		msg = string_format(Chatto.out.item_deficit, item)
	end
	Chatto:PrintToFrame(DEFAULT_CHAT_FRAME or ChatFrame1, msg, "LOOT")
end

-- Mail items extraction report
function Loot:ReportMailItem(mailID, attachIndex)
	local link = GetInboxItemLink and GetInboxItemLink(mailID, attachIndex)
	if not link then return end

	local _, _, count = GetInboxItem(mailID, attachIndex)
	local item = Chatto:StripBrackets(link)
	local msg
	if count and count > 1 then
		msg = string_format(Chatto.out.item_multiple, item, count)
	else
		msg = string_format(Chatto.out.item_single, item)
	end
	Chatto:PrintToFrame(DEFAULT_CHAT_FRAME or ChatFrame1, msg, "LOOT")
end

function Loot:OnInitialize()
	self.patterns = {}

	for _, global in ipairs({
		"LOOT_ITEM_CREATED_SELF_MULTIPLE",
		"LOOT_ITEM_CREATED_SELF",
		"LOOT_ITEM_SELF_MULTIPLE",
		"LOOT_ITEM_SELF",
		"LOOT_ITEM_PUSHED_SELF_MULTIPLE",
		"LOOT_ITEM_PUSHED_SELF",
		"LOOT_ITEM_REFUND",
		"LOOT_ITEM_REFUND_MULTIPLE",
		"CURRENCY_GAINED",
		"CURRENCY_GAINED_MULTIPLE",
		"CURRENCY_GAINED_MULTIPLE_BONUS",
		"LOOT_ITEM",
		"LOOT_ITEM_BONUS_ROLL",
		"LOOT_ITEM_BONUS_ROLL_MULTIPLE",
		"LOOT_ITEM_MULTIPLE",
		"LOOT_ITEM_PUSHED",
		"LOOT_ITEM_PUSHED_MULTIPLE",
	}) do
		local msg = _G[global]
		if msg then
			table_insert(self.patterns, Chatto:MakePattern(msg))
		end
	end

	table_insert(self.patterns, Chatto:MakePattern(G.QUEST_LOG_RECEIVED_ITEM))
	table_insert(self.patterns, Chatto:MakePattern(G.QUEST_LOG_RECEIVED_ITEM_MULTIPLE))
	table_insert(self.patterns, Chatto:MakePattern(G.QUEST_LOG_RECEIVED_COUNT_OF_ITEM))

	Chatto:RegisterFilter("Loot", function(core, chatFrame, text, r, g, b, chatID, ...)
		-- Fallback to blacklist hook in AddMessage if necessary
		if Chatto.db.profile.filters.loot then
			if Chatto:SafeMatch(text, P[G.COMBATLOG_HONORGAIN]) or 
			   Chatto:SafeMatch(text, P[G.COMBATLOG_HONORGAIN_NO_RANK]) or 
			   Chatto:SafeMatch(text, P[G.COMBATLOG_HONORAWARD]) or 
			   Chatto:SafeMatch(text, P[G.COMBATLOG_ARENAPOINTSAWARD]) then
				return nil
			end
		end
		return text, r, g, b
	end, 20)
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterLootEvent(Loot, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Loot:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", OnChatEventProxy)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnChatEventProxy)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnChatEventProxy)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)

	-- Safe hook container items for vendor sales
	if not self.merchantHooked then
		self.merchantHooked = true
		hooksecurefunc("UseContainerItem", function(bag, slot)
			if not self._isEnabled then return end
			if not MerchantFrame or not MerchantFrame:IsShown() then return end

			local link = GetContainerItemLink(bag, slot)
			if not link then return end
			local _, countBefore = GetContainerItemInfo(bag, slot)
			countBefore = countBefore or 1

			if C_Timer and C_Timer.After then
				local attempts = 0
				local function check()
					attempts = attempts + 1
					local linkAfter = GetContainerItemLink(bag, slot)
					local _, countAfter = GetContainerItemInfo(bag, slot)
					countAfter = countAfter or 0

					if not linkAfter then
						self:ReportItemSold(link, countBefore)
					elseif linkAfter == link and countAfter < countBefore then
						self:ReportItemSold(link, countBefore - countAfter)
					elseif attempts < 12 then
						C_Timer.After(0.1, check)
					end
				end
				C_Timer.After(0.05, check)
			else
				self:ReportItemSold(link, countBefore)
			end
		end)
	end

	-- Mail hooks
	if not self.mailHooked then
		self.mailHooked = true
		hooksecurefunc("TakeInboxItem", function(mailID, attachIndex)
			if self._isEnabled then
				self:ReportMailItem(mailID, attachIndex)
			end
		end)
	end

	-- Destruction popup hooks
	if not self.deleteHooked then
		self.deleteHooked = true
		local origDeleteItem = StaticPopupDialogs["DELETE_ITEM"] and StaticPopupDialogs["DELETE_ITEM"].OnAccept
		local origDeleteGoodItem = StaticPopupDialogs["DELETE_GOOD_ITEM"] and StaticPopupDialogs["DELETE_GOOD_ITEM"].OnAccept

		local function reportDeletedItem()
			if not self._isEnabled then return end
			local infoType, itemId, itemLink = GetCursorInfo()
			if infoType == "item" then
				local link = itemLink
				if not link or type(link) ~= "string" or not string_find(link, "|H") then
					if itemId then
						local _, constructedLink = GetItemInfo(itemId)
						link = constructedLink
					end
				end
				if link then
					self:ReportItemSold(link, 1)
				end
			end
		end

		if StaticPopupDialogs["DELETE_ITEM"] then
			StaticPopupDialogs["DELETE_ITEM"].OnAccept = function(popup, ...)
				reportDeletedItem()
				if origDeleteItem then return origDeleteItem(popup, ...) end
			end
		end
		if StaticPopupDialogs["DELETE_GOOD_ITEM"] then
			StaticPopupDialogs["DELETE_GOOD_ITEM"].OnAccept = function(popup, ...)
				reportDeletedItem()
				if origDeleteGoodItem then return origDeleteGoodItem(popup, ...) end
			end
		end
	end
end

function Loot:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", OnChatEventProxy)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnChatEventProxy)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnChatEventProxy)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end
