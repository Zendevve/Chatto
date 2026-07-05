local AddonName, ns = ...
local Chatto = _G[AddonName]

local Blacklist = Chatto:NewModule("Blacklist", "AceEvent-3.0")

local string_find = string.find
local string_format = string.format
local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local type = type

local B = {}
if ERR_NOT_IN_INSTANCE_GROUP then B[ERR_NOT_IN_INSTANCE_GROUP] = true end
if ERR_NOT_IN_RAID then B[ERR_NOT_IN_RAID] = true end
if ERR_QUEST_ALREADY_ON then B[ERR_QUEST_ALREADY_ON] = true end

-- Swallowing GlassUI benign errors
local lastErrorWas3481 = false
local prevErrorHandler

local function ChattoErrorHandler(err, ...)
	local is3481 = (type(err) == "string") and string_find(err, "ChatFrame.lua:3481", 1, true) and true or false
	lastErrorWas3481 = is3481
	if is3481 then
		return -- swallow
	end
	if prevErrorHandler then
		return prevErrorHandler(err, ...)
	end
end

local function InstallErrorWatcher()
	if not _G.seterrorhandler then return end
	local cur = _G.geterrorhandler and _G.geterrorhandler()
	if cur == ChattoErrorHandler then return end
	prevErrorHandler = cur
	_G.seterrorhandler(ChattoErrorHandler)
end

local function FilterBlacklistEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.blacklist then return end

	-- Death message
	if string_find(message, "|Hdeath:") then
		return false, Chatto.out.died, author, ...
	end

	-- Durability loss
	if event == "CHAT_MSG_COMBAT_MISC_INFO" then
		local durability = string_match(message, "suffer a (%d+)%% durability loss")
		if durability then
			return false, string_format(Chatto.out.durability_loss, tonumber(durability)), author, ...
		end
	end

	-- Group alerts in instances
	if B[message] then
		if IsInInstance() then
			return true -- suppress
		end
	end
end

-- Filter direct message text (AddMessage)
function Blacklist:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.filters.blacklist then return text, r, g, b end
	if not text then return text, r, g, b end

	-- Suppress "UI Error" if caused by the benign 3481 assert
	if lastErrorWas3481 then
		if string_find(text, "Huierror", 1, true) or string_find(text, "an interface error occ", 1, true) then
			return nil -- Suppress
		end
	end

	-- Check user-defined phrases
	local phrases = Chatto.db.profile.blacklist.phrases
	if phrases and #phrases > 0 then
		local lowerText = text:lower()
		for _, phrase in ipairs(phrases) do
			if string_find(lowerText, phrase:lower(), 1, true) then
				return nil -- Suppress matching message
			end
		end
	end

	return text, r, g, b
end

function Blacklist:OnInitialize()
	InstallErrorWatcher()
	
	Chatto:RegisterFilter("Blacklist", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 10) -- Run first to block unwanted messages early
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterBlacklistEvent(Blacklist, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

function Blacklist:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnChatEventProxy)
	
	-- Re-hook error handler on Login/world change just in case
	InstallErrorWatcher()
	self:RegisterEvent("PLAYER_LOGIN", InstallErrorWatcher)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", InstallErrorWatcher)
end

function Blacklist:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnChatEventProxy)
	self:UnregisterEvent("PLAYER_LOGIN")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end
