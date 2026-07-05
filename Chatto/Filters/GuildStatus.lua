local AddonName, ns = ...
local Chatto = _G[AddonName]

local GuildStatus = Chatto:NewModule("GuildStatus", "AceEvent-3.0")

local string_find = string.find
local string_format = string.format
local string_match = string.match

local function FilterGuildStatusEvent(self, chatFrame, event, message, author, ...)
	if not Chatto.db.profile.filters.guildstatus then return end

	-- Guild online: "|Hplayer:Name|h[Name]|h has come online."
	-- Guild offline: "Name has gone offline." (plain text, no player link)
	local onlineName = string_match(message, "|Hplayer:([^|]+)|h.-has come online")
	if onlineName then
		return false, string_format(Chatto.out.guild_online, onlineName), author, ...
	end

	local offlineName = string_match(message, "^(%S+) has gone offline")
	if offlineName then
		return false, string_format(Chatto.out.guild_offline, offlineName), author, ...
	end
end

local function OnChatEventProxy(frame, event, ...)
	local block, newMsg, author, rest = FilterGuildStatusEvent(GuildStatus, frame, event, ...)
	if block then return true end
	if newMsg then return false, newMsg, author, rest end
end

-- Intercept direct print messages to block "Added as:" alerts
function GuildStatus:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.filters.guildstatus then return text, r, g, b end
	if not text then return text, r, g, b end

	if string_find(text, "Added as:") then
		return nil -- Block completely
	end

	return text, r, g, b
end

function GuildStatus:OnInitialize()
	Chatto:RegisterFilter("GuildStatus", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 70)
end

function GuildStatus:OnEnable()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end

function GuildStatus:OnDisable()
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatEventProxy)
end
