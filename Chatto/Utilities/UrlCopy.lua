local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local UrlCopy = Chatto:NewModule("UrlCopy", "AceHook-3.0")

local _G = _G
local pairs = pairs
local ipairs = ipairs
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match
local unpack = unpack
local StaticPopup_Show = StaticPopup_Show

local currentUrl = ""

_G.StaticPopupDialogs["ChattoUrlCopyDialog"] = {
	text = "Chatto: Ctrl-C to copy link",
	button2 = "Close",
	hasEditBox = 1,
	hasWideEditBox = 1,
	OnShow = function(frame)
		local editBox = _G[frame:GetName() .. "WideEditBox"] or _G[frame:GetName() .. "EditBox"]
		if editBox then
			editBox:SetText(currentUrl)
			editBox:SetFocus()
			editBox:HighlightText(0)
		end
		local button = _G[frame:GetName() .. "Button2"]
		if button then
			button:ClearAllPoints()
			button:SetWidth(120)
			button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

local function ShowCopyDialog(url)
	currentUrl = url
	StaticPopup_Show("ChattoUrlCopyDialog")
end

function UrlCopy:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.utilities.urlcopy then return text, r, g, b end
	if not text then return text, r, g, b end

	local tokennum = 1
	local matchTable = {}

	local function RegisterMatch(matchText)
		local token = "\255\254\253" .. tokennum .. "\253\254\255"
		matchTable[token] = string_gsub(matchText, "%%", "%%%%")
		tokennum = tokennum + 1
		return token
	end

	local function Link(urlVal)
		return RegisterMatch("|cff71d5ff|Hurl:" .. urlVal .. "|h[" .. urlVal .. "]|h|r")
	end

	-- 1. Parse protocols
	text = string_gsub(text, "(%a+://%S+)", Link)
	-- 2. Parse www.
	text = string_gsub(text, "(%f[%S]www%.[-%w_%%]+%.%S+)", Link)

	-- 3. Restore tokens
	for token, repl in pairs(matchTable) do
		text = string_gsub(text, token, repl)
	end

	return text, r, g, b
end

function UrlCopy:OnInitialize()
	Chatto:RegisterFilter("UrlCopy", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 50)
end

function UrlCopy:OnEnable()
	-- Hook Classic Link Clicks
	if not self:IsHooked("SetItemRef") then
		self:RawHook("SetItemRef", function(link, text, button, chatFrame)
			if Chatto.db.profile.utilities.urlcopy and link and string_find(link, "^url:") then
				local url = link:sub(5)
				ShowCopyDialog(url)
				return true -- Handled
			end
			return self.hooks.SetItemRef(link, text, button, chatFrame)
		end, true)
	end

	-- Subscribe to Glass custom hyperlink clicks
	if Glass and Glass.Subscribe then
		self.unsubscribe = Glass:Subscribe("HYPERLINK_CLICK", function(data)
			local link, text, mouseButton = unpack(data)
			if Chatto.db.profile.utilities.urlcopy and link and string_find(link, "^url:") then
				local url = link:sub(5)
				ShowCopyDialog(url)
			end
		end)
	end
end

function UrlCopy:OnDisable()
	self:UnhookAll()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end
