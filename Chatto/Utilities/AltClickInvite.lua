local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local AltClickInvite = Chatto:NewModule("AltClickInvite", "AceHook-3.0")

local _G = _G
local IsAltKeyDown = IsAltKeyDown
local InviteUnit = InviteUnit
local string_find = string.find
local string_match = string.match
local unpack = unpack

function AltClickInvite:OnInitialize()
end

function AltClickInvite:OnEnable()
	-- Hook Classic Chat Link Clicks
	if not self:IsHooked("SetItemRef") then
		self:RawHook("SetItemRef", function(link, text, button, chatFrame)
			if Chatto.db.profile.utilities.altclickinvite and IsAltKeyDown() and link and string_find(link, "^player:") then
				local name = string_match(link, "^player:([^:]+)")
				if name then
					InviteUnit(name)
					return true -- Handled
				end
			end
			return self.hooks.SetItemRef(link, text, button, chatFrame)
		end, true)
	end

	-- Subscribe to Glass Custom Hyperlink Clicks
	if Glass and Glass.Subscribe then
		self.unsubscribe = Glass:Subscribe("HYPERLINK_CLICK", function(data)
			local link, text, mouseButton = unpack(data)
			if Chatto.db.profile.utilities.altclickinvite and IsAltKeyDown() and link and string_find(link, "^player:") then
				local name = string_match(link, "^player:([^:]+)")
				if name then
					InviteUnit(name)
				end
			end
		end)
	end
end

function AltClickInvite:OnDisable()
	self:UnhookAll()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end
