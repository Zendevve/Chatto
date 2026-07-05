local AddonName, ns = ...
local Chatto = _G[AddonName]

local TellTarget = Chatto:NewModule("TellTarget", "AceHook-3.0")

local _G = _G
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitName = UnitName
local string_gsub = string.gsub
local string_find = string.find
local InviteUnit = InviteUnit

function TellTarget:OnInitialize()
end

function TellTarget:OnEnable()
	local editBox = _G.ChatFrame1EditBox
	if editBox then
		self:HookScript(editBox, "OnTextChanged", function(box)
			if not Chatto.db.profile.utilities.telltarget then return end
			local text = box:GetText()
			if text and text:sub(1, 4) == "/tt " then
				local name, realm = UnitName("target")
				if name and UnitIsPlayer("target") then
					if name then name = string_gsub(name, " ", "") end
					if realm and realm ~= "" then
						name = name .. "-" .. string_gsub(realm, " ", "")
					end
					
					-- Switch editbox to whisper target
					box:SetText("")
					box:SetAttribute("chatType", "WHISPER")
					box:SetAttribute("tellTarget", name)
					ChatEdit_UpdateHeader(box)
					
					-- Append remainder
					local rest = text:sub(5)
					if rest and rest ~= "" then
						box:SetText(rest)
					end
				end
			end
		end)
	end
end

function TellTarget:OnDisable()
	self:UnhookAll()
end
