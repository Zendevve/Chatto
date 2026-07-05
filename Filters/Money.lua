local AddonName, ns = ...
local Chatto = _G[AddonName]

local Money = Chatto:NewModule("Money", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Chatto")

local math_abs = math.abs
local math_floor = math.floor
local string_format = string.format
local string_gsub = string.gsub
local string_find = string.find
local string_match = string.match
local tonumber = tonumber
local tostring = tostring
local table_concat = table.concat

local COINS_TEXTURE = [[Interface\AddOns\Chatto\Assets\coins]]
local CoinGold, CoinSilver, CoinCopper

local function UpdateCoinTextures()
	local frame = DEFAULT_CHAT_FRAME or ChatFrame1
	local _, fontHeight = frame:GetFont()
	fontHeight = fontHeight or 14
	local size = math_floor(fontHeight * 1.6)
	if size < 12 then size = 12 end

	CoinGold = string_format([[|T%s:%d:%d:0:0:64:64:0:32:0:32|t]], COINS_TEXTURE, size, size)
	CoinSilver = string_format([[|T%s:%d:%d:0:0:64:64:32:64:0:32|t]], COINS_TEXTURE, size, size)
	CoinCopper = string_format([[|T%s:%d:%d:0:0:64:64:0:32:32:64|t]], COINS_TEXTURE, size, size)
end

local function GetPrettifiedNumber(value)
	if value >= 1000 then
		local thousands = math_floor(value / 1000)
		local remainder = value % 1000
		return string_format("%d %03d", thousands, remainder)
	else
		return tostring(value)
	end
end

local function GetFormatMoneyString(gold, silver, copper, colorCode)
	colorCode = colorCode or "|cfff0f0f0"
	if not CoinGold then UpdateCoinTextures() end

	local parts = {}
	if gold and gold > 0 then
		local goldStr = GetPrettifiedNumber(gold)
		parts[#parts + 1] = string_format("%s%s|r%s", colorCode, goldStr, CoinGold)
	end
	if silver and silver > 0 then
		parts[#parts + 1] = string_format("%s%d|r%s", colorCode, silver, CoinSilver)
	end
	if copper and copper > 0 then
		parts[#parts + 1] = string_format("%s%d|r%s", colorCode, copper, CoinCopper)
	end
	if #parts == 0 then
		return colorCode .. "0|r" .. CoinCopper
	end
	return table_concat(parts, " ")
end

local P = Chatto:MakePatternCache()

local function ParseForMoney(message)
	if LARGE_NUMBER_SEPERATOR and LARGE_NUMBER_SEPERATOR ~= "" then
		message = string_gsub(message or "", "(%d)%" .. LARGE_NUMBER_SEPERATOR .. "(%d)", "%1%2")
	end

	local gold = string_match(message, P[GOLD_AMOUNT or "%d Gold"])
	local gold_amount = gold and tonumber(gold) or 0

	local silver = string_match(message, P[SILVER_AMOUNT or "%d Silver"])
	local silver_amount = silver and tonumber(silver) or 0

	local copper = string_match(message, P[COPPER_AMOUNT or "%d Copper"])
	local copper_amount = copper and tonumber(copper) or 0

	if gold_amount == 0 and silver_amount == 0 and copper_amount == 0 then
		-- Fallback to scanning textures
		local hasGold = string_find(message, "(UI%-GoldIcon)") or string_find(message, "UI%-GoldIcon")
		local hasSilver = string_find(message, "(UI%-SilverIcon)") or string_find(message, "UI%-SilverIcon")
		local hasCopper = string_find(message, "(UI%-CopperIcon)") or string_find(message, "UI%-CopperIcon")

		if hasGold or hasSilver or hasCopper then
			message = string_gsub(message, "\124T(.-)\124t", " ")
			message = string_gsub(message, "\124[cC]%x%x%x%x%x%x%x%x", "")
			message = string_gsub(message, "\124[rR]", "")

			if hasGold then
				if hasSilver and hasCopper then
					gold_amount, silver_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*%s+(%d+).*")
				elseif hasSilver then
					gold_amount, silver_amount = string_match(message, "(%d+).*%s+(%d+).*")
				elseif hasCopper then
					gold_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*")
				else
					gold_amount = string_match(message, "(%d+).*%s")
				end
			elseif hasSilver then
				if hasCopper then
					silver_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*")
				else
					silver_amount = string_match(message, "(%d+).*%s")
				end
			elseif hasCopper then
				copper_amount = string_match(message, "(%d+).*%s")
			end
		end
	end

	return tonumber(gold_amount) or 0, tonumber(silver_amount) or 0, tonumber(copper_amount) or 0
end

-- Filter to intercept default prints or addon prints containing gold/silver/copper
function Money:FilterMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.filters.money then return text, r, g, b end
	if self.emittingOwnMessage then return text, r, g, b end

	local gold, silver, copper = ParseForMoney(text)
	if gold + silver + copper > 0 then
		return nil -- Suppress duplicate or unformatted text
	end

	return text, r, g, b
end

local function OnChatMsgMoney(self, event, message, ...)
	-- Completely suppress default message, we will print our own
	if Chatto.db.profile.filters.money then
		return true
	end
end

function Money:OnInitialize()
	Chatto:RegisterFilter("Money", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 30)
end

function Money:OnEnable()
	self.playerMoney = GetMoney()
	self.isLooting = false
	self.lootClosedTime = nil

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_MONEY")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_CLOSED")
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnChatMsgMoney)
end

function Money:OnDisable()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("PLAYER_MONEY")
	self:UnregisterEvent("LOOT_OPENED")
	self:UnregisterEvent("LOOT_CLOSED")
	
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnChatMsgMoney)
end

function Money:PLAYER_ENTERING_WORLD()
	self.playerMoney = GetMoney()
end

function Money:LOOT_OPENED()
	self.isLooting = true
end

function Money:LOOT_CLOSED()
	self.isLooting = false
	self.lootClosedTime = GetTime()
end

function Money:PLAYER_MONEY()
	local currentMoney = GetMoney()
	if not Chatto.db.profile.filters.money then
		self.playerMoney = currentMoney
		return
	end

	-- Suppress inside auction frame
	local atAuction = (AuctionFrame and AuctionFrame:IsShown()) or (AuctionHouseFrame and AuctionHouseFrame:IsShown())
	if atAuction then
		self.playerMoney = currentMoney
		return
	end

	if self.playerMoney then
		local money = currentMoney - self.playerMoney
		if money ~= 0 then
			local value = math_abs(money)
			local g = math_floor(value / 1e4)
			local s = math_floor((value - (g * 1e4)) / 100)
			local c = value % 100

			local info = ChatTypeInfo and ChatTypeInfo["MONEY"]
			local r = info and info.r or 1
			local gb = info and info.g or 1
			local b = info and info.b or 0

			if money > 0 then
				-- Check for quest reward buffering
				local atVendor = MerchantFrame and MerchantFrame:IsShown()
				local atMail = MailFrame and MailFrame:IsShown()
				local atTrainer = ClassTrainerFrame and ClassTrainerFrame:IsShown()
				local atLoot = self.isLooting or (LootFrame and LootFrame:IsShown())
				local recentlyLooted = self.lootClosedTime and (GetTime() - self.lootClosedTime) < 0.5

				if not atVendor and not atMail and not atTrainer and not atLoot and not recentlyLooted and Chatto.db.profile.filters.quests then
					local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
					if chatFrame then
						local moneyText = GetFormatMoneyString(g, s, c)
						-- Buffer it in Quests if it can be combined
						if Chatto.AddQuestReward and Chatto:AddQuestReward(chatFrame, "money", moneyText) then
							self.playerMoney = currentMoney
							return
						end
					end
				end

				local msg = string_format(Chatto.out.money, GetFormatMoneyString(g, s, c))
				self:PrintMoneyMessage(msg, r, gb, b)
			else
				local palered = Chatto.Colors.palered.colorCode
				local msg = string_format(Chatto.out.money_deficit, GetFormatMoneyString(g, s, c, palered))
				self:PrintMoneyMessage(msg, r, gb, b)
			end
		end
	end
	self.playerMoney = currentMoney
end

function Money:PrintMoneyMessage(msg, r, gb, b)
	local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
	if not chatFrame or not chatFrame.AddMessage then return end

	self.emittingOwnMessage = true
	local ok, err = pcall(chatFrame.AddMessage, chatFrame, msg, r, gb, b)
	self.emittingOwnMessage = false
	if not ok then
		print(msg)
	end
end
