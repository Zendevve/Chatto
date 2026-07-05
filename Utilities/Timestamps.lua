local AddonName, ns = ...
local Chatto = _G[AddonName]

local Timestamps = Chatto:NewModule("Timestamps")

local _G = _G
local date = date

function Timestamps:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.utilities.timestamps then return text, r, g, b end
	if not text then return text, r, g, b end

	local fmt = Chatto.db.profile.utilities.timestampFormat or "%H:%M:%S"
	local color = Chatto.db.profile.utilities.timestampColorHex or "888888"
	local timeStr = date(fmt)
	local timestamp = "|cff" .. color .. "[" .. timeStr .. "]|r "

	return timestamp .. text, r, g, b
end

function Timestamps:OnInitialize()
	Chatto:RegisterFilter("Timestamps", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 100) -- Run last so timestamps are prepended to the final message
end

function Timestamps:OnEnable()
end

function Timestamps:OnDisable()
end
