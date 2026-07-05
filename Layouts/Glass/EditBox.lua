local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local _G = _G
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local Mixin = Mixin

local Hooker = {}
LibStub("AceHook-3.0"):Embed(Hooker)

local EditBoxMixin = {}

function EditBoxMixin:Init(parent)
	self:SetParent(parent)
	self:ClearAllPoints()

	local xPad = self.profile.editBoxHorizontalPadding or 10
	local yOfs = self.profile.editBoxYOffset or -5

	if self.profile.editBoxAnchor == "ABOVE" then
		self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", xPad, yOfs)
	else
		self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", xPad, yOfs)
	end

	self:SetWidth(self.profile.frameWidth - xPad)
	if self.header then
		self.header:ClearAllPoints()
		self.header:SetPoint("LEFT", 8, 0)
	end

	self:UpdateFontFromProfile()

	if not self.bg then
		self.bg = self:CreateTexture(nil, "BACKGROUND")
	end
	self:UpdateBackgroundFromProfile()

	-- Suppress and hide default Blizzard borders
	for _, region in ipairs({ self:GetRegions() }) do
		if region ~= self.bg and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:Hide()
			if not Hooker:IsHooked(region, "Show") then
				Hooker:RawHook(region, "Show", function() end, true)
			end
		end
	end

	if self.GetBackdrop and self:GetBackdrop() then
		self:SetBackdrop(nil)
	end

	local function GetFontHeight(fontString)
		if fontString.GetLineHeight then
			local h = fontString:GetLineHeight()
			if h and h > 0 then return h end
		end
		if fontString.GetStringHeight then
			local h = fontString:GetStringHeight()
			if h and h > 0 then return h end
		end
		return 14
	end

	local Ypadding = GetFontHeight(self.header or self) * 0.5
	self:SetHeight(GetFontHeight(self.header or self) + Ypadding * 2)

	if not Hooker:IsHooked(self, "SetTextInsets") then
		Hooker:RawHook(self, "SetTextInsets", function(self, left, right, top, bottom)
			local pad = GetFontHeight(self.header or self) * 0.5
			local headerW = self.header and self.header:GetStringWidth() or 0
			Hooker.hooks[self].SetTextInsets(self, headerW + 12, 8, pad, pad)
		end, true)
	end

	self:SetTextInsets()

	self:SetScript("OnShow", function()
		self:SetAlpha(1)
	end)

	local oldOnEditFocusGained = self:GetScript("OnEditFocusGained")
	self:SetScript("OnEditFocusGained", function(frame, ...)
		if self.profile.showOnEditFocus then
			Glass:Dispatch("EDIT_FOCUS_GAINED", self.window)
		end
		if oldOnEditFocusGained then oldOnEditFocusGained(frame, ...) end
	end)

	local oldOnEditFocusLost = self:GetScript("OnEditFocusLost")
	self:SetScript("OnEditFocusLost", function(frame, ...)
		if self.profile.showOnEditFocus then
			Glass:Dispatch("EDIT_FOCUS_LOST", self.window)
		end
		if oldOnEditFocusLost then oldOnEditFocusLost(frame, ...) end
	end)

	self.subscriptions = {
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			if key == "editBoxFont" or key == "editBoxFontSize" or key == "editBoxFontFlags" then
				self:UpdateFontFromProfile()
				local pad = GetFontHeight(self.header or self) * 0.5
				self:SetHeight(GetFontHeight(self.header or self) + pad * 2)
				self:SetTextInsets()
			elseif key == "frameWidth" or key == "editBoxHorizontalPadding" or key == "editBoxYOffset" or key == "editBoxAnchor" then
				local xPadding = self.profile.editBoxHorizontalPadding or 10
				local yOffset = self.profile.editBoxYOffset or -5
				self:SetWidth(self.profile.frameWidth - xPadding)
				local anchorParent = self:GetParent() or parent
				self:ClearAllPoints()
				if self.profile.editBoxAnchor == "ABOVE" then
					self:SetPoint("BOTTOMLEFT", anchorParent, "TOPLEFT", xPadding, yOffset)
				else
					self:SetPoint("TOPLEFT", anchorParent, "BOTTOMLEFT", xPadding, yOffset)
				end
			elseif key == "editBoxBackgroundOpacity" or key == "editBoxBackgroundColor" then
				self:UpdateBackgroundFromProfile()
			end
		end),
	}
end

function EditBoxMixin:AttachToWindow(parent, profile, window)
	self.profile = profile or self.profile
	self.window = window

	local xPadding = self.profile.editBoxHorizontalPadding or 10
	local yOffset = self.profile.editBoxYOffset or -5
	self:SetParent(parent)
	self:ClearAllPoints()
	if self.profile.editBoxAnchor == "ABOVE" then
		self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", xPadding, yOffset)
	else
		self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", xPadding, yOffset)
	end
	self:SetWidth(self.profile.frameWidth - xPadding)
	if self.header then
		self.header:ClearAllPoints()
		self.header:SetPoint("LEFT", 8, 0)
	end
	self:SetTextInsets()

	self:UpdateFontFromProfile()
	self:UpdateBackgroundFromProfile()
end

function EditBoxMixin:UpdateFontFromProfile()
	local fontPath = Glass.Libs.LSM:Fetch("font", self.profile.editBoxFont)
	local fontSize = self.profile.editBoxFontSize
	local fontFlags = self.profile.editBoxFontFlags

	if fontPath and fontSize then
		self:SetFont(fontPath, fontSize, fontFlags or "")
		if self.header then
			self.header:SetFont(fontPath, fontSize, fontFlags or "")
		end
	end
end

function EditBoxMixin:UpdateBackgroundFromProfile()
	if not self.bg then return end
	local color = self.profile.editBoxBackgroundColor or { r = 17/255, g = 17/255, b = 17/255 }
	local opacity = self.profile.editBoxBackgroundOpacity or 0.6
	if self.bg.SetColorTexture then
		self.bg:SetColorTexture(color.r, color.g, color.b, opacity)
	else
		self.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
		self.bg:SetVertexColor(color.r, color.g, color.b, opacity)
	end
end

Glass.Components.CreateEditBox = function(parent, profile)
	local object = Mixin(_G.ChatFrame1EditBox, EditBoxMixin)
	Glass.Libs.AceHook:Embed(object)
	object.profile = profile or Chatto.db.profile.glass
	object:Init(parent)
	return object
end
