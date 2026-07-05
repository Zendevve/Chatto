local AddonName, ns = ...
local Chatto = _G[AddonName]

local StickyChannels = Chatto:NewModule("StickyChannels")

local _G = _G
local pairs = pairs
local ChatTypeInfo = ChatTypeInfo

local channels = {
	SAY = true,
	EMOTE = true,
	YELL = true,
	OFFICER = true,
	RAID_WARNING = true,
	WHISPER = true,
	CHANNEL = true,
}

function StickyChannels:OnInitialize()
end

function StickyChannels:OnEnable()
	local stickyProfile = Chatto.db.profile.stickyChannels
	for channel, defaultVal in pairs(channels) do
		local enabled = stickyProfile[channel]
		if enabled == nil then enabled = defaultVal end
		if ChatTypeInfo[channel] then
			ChatTypeInfo[channel].sticky = enabled and 1 or 0
		end
	end
end

function StickyChannels:OnDisable()
	-- Reset default Blizzard settings (Say/Emote/Yell are usually non-sticky, Whisper/Guild/Party are sticky by default)
	local defaults = {
		SAY = 1,
		EMOTE = 0,
		YELL = 0,
		OFFICER = 1,
		RAID_WARNING = 0,
		WHISPER = 0,
		CHANNEL = 0,
	}
	for channel, val in pairs(defaults) do
		if ChatTypeInfo[channel] then
			ChatTypeInfo[channel].sticky = val
		end
	end
end
