local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local MessageLineMixin = {}

local CreateFrame = CreateFrame
local Mixin = Mixin
local CreateObjectPool = CreateObjectPool
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local string_rep = string.rep
local table_concat = table.concat
local ipairs = ipairs
local math_max = math.max
local math_floor = math.floor
local math_abs = math.abs

local function GetFontHeight(fontString)
	if fontString.GetLineHeight then
		local h = fontString:GetLineHeight()
		if h and h > 0 then return h end
	end
	if fontString.GetFont then
		local _, h = fontString:GetFont()
		if h and h > 0 then return h end
	end
	if fontString.GetStringHeight then
		local h = fontString:GetStringHeight()
		if h and h > 0 then return h end
	end
	return 14
end

local measureFontString
local function GetMeasureFontString()
	if not measureFontString then
		measureFontString = _G.UIParent:CreateFontString(nil, "ARTWORK")
		measureFontString:Hide()
	end
	return measureFontString
end

local function BuildDisplayText(text, fs)
	fs:SetWidth(0)
	fs:SetText(" ")
	local spaceW = fs:GetStringWidth() or 3
	if spaceW <= 0 then spaceW = 3 end

	local out, icons = {}, {}
	local pos = 1
	while true do
		local s, e, inner = string_find(text, "|T(.-)|t", pos)
		if not s then
			out[#out + 1] = string_sub(text, pos)
			break
		end
		out[#out + 1] = string_sub(text, pos, s - 1)

		local path = inner
		local params = nil
		local colon = string_find(inner, ":", 1, true)
		if colon then
			path = string_sub(inner, 1, colon - 1)
			params = string_sub(inner, colon + 1)
		end

		local nums = {}
		if params then
			local normalized = string_gsub(params, "|:", ":")
			for token in string.gmatch(normalized, "[^:]+") do
				nums[#nums + 1] = tonumber(token)
			end
		end

		local h, w = nums[1], nums[2]
		local offsetX, offsetY = nums[3] or 0, nums[4] or 0
		local texWidth, texHeight = nums[5], nums[6]
		local texLeft, texRight, texTop, texBottom = nums[7], nums[8], nums[9], nums[10]

		if path ~= "" then
			local defaultSize = 16
			local actualH = (h and h > 0) and h or defaultSize
			local actualW = (w and w > 0) and w or actualH
			local n = math_max(1, math_floor(actualW / spaceW + 0.5))
			
			local texCoords = nil
			if texWidth and texHeight and texLeft and texRight and texTop and texBottom then
				texCoords = {
					left = texLeft / texWidth,
					right = texRight / texWidth,
					top = texTop / texHeight,
					bottom = texBottom / texHeight,
				}
			end
			icons[#icons + 1] = {
				path = path,
				w = actualW,
				h = actualH,
				offsetX = offsetX,
				offsetY = offsetY,
				texCoords = texCoords,
				before = table_concat(out),
			}
			out[#out + 1] = string_rep(" ", n)
		else
			out[#out + 1] = string_sub(text, s, e)
		end
		pos = e + 1
	end

	return table_concat(out), icons
end

function MessageLineMixin:Init()
	self:SetWidth(self.profile.frameWidth)
	local animate = self.profile.messageAnimations ~= false
	self:SetFadeInDuration(animate and self.profile.chatFadeInDuration or 0)
	self:SetFadeOutDuration(animate and self.profile.chatFadeOutDuration or 0)

	local rightBgWidth = math_max(50, self.profile.frameWidth - 50)
	self:SetGradientBackground(
		50,
		rightBgWidth,
		self.profile.chatBackgroundColor or { r = 17/255, g = 17/255, b = 17/255 },
		self.profile.chatBackgroundOpacity or 0.15
	)

	if self.text == nil then
		self.text = self:CreateFontString(nil, "ARTWORK", "ChatFrame1Font")
	end
	self:UpdateFontFromProfile()
	local leftPadding = self.profile.messageLeftPadding or 3
	self.text:SetPoint("LEFT", leftPadding, 0)
	self.text:SetWidth(self.profile.frameWidth - leftPadding - 6)
	self.text:SetIndentedWordWrap(self.profile.indentWordWrap)
	if self.text.SetNonSpaceWrap then
		self.text:SetNonSpaceWrap(true)
	end

	self.linkButtons = self.linkButtons or {}
	self.iconTextures = self.iconTextures or {}

	self.subscriptions = {
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			if key == "chatFadeInDuration" or key == "messageAnimations" then
				local anim = self.profile.messageAnimations ~= false
				self:SetFadeInDuration(anim and self.profile.chatFadeInDuration or 0)
			elseif key == "chatFadeOutDuration" or key == "messageAnimations" then
				local anim = self.profile.messageAnimations ~= false
				self:SetFadeOutDuration(anim and self.profile.chatFadeOutDuration or 0)
			elseif key == "messageLeftPadding" then
				self:UpdateFrame()
			elseif key == "messageFont" or key == "messageFontSize" or key == "messageFontFlags" or key == "messageLeading" then
				self:UpdateFontFromProfile()
			end
		end),
	}
end

function MessageLineMixin:UpdateFontFromProfile()
	local fontPath = Glass.Libs.LSM:Fetch("font", self.profile.messageFont)
	local fontSize = self.profile.messageFontSize
	local fontFlags = self.profile.messageFontFlags
	local leading = self.profile.messageLeading

	if fontPath and fontSize then
		self.text:SetFont(fontPath, fontSize, fontFlags or "")
		self.text:SetSpacing(leading or 0)
	end
end

function MessageLineMixin:SetMessageText(processed)
	self.processedText = processed

	if not processed or not string_find(processed, "|T", 1, true) then
		self.displayText = processed
		self.iconList = nil
		self.text:SetText(processed or "")
		return
	end

	local fs = GetMeasureFontString()
	local fontPath, fontSize, fontFlags = self.text:GetFont()
	if fontPath then fs:SetFont(fontPath, fontSize, fontFlags) end

	local displayText, icons = BuildDisplayText(processed, fs)
	self.displayText = displayText
	self.iconList = (icons and #icons > 0) and icons or nil
	self.text:SetText(displayText)
end

function MessageLineMixin:UpdateFrame()
	local leftPadding = self.profile.messageLeftPadding or 3
	self:SetWidth(self.profile.frameWidth)
	self.text:ClearAllPoints()
	self.text:SetPoint("LEFT", leftPadding, 0)
	self.text:SetWidth(self.profile.frameWidth - leftPadding - 6)
	self.text:SetIndentedWordWrap(self.profile.indentWordWrap)

	local lineHeight = GetFontHeight(self.text)
	local stringHeight = self.text:GetStringHeight() or 0
	if stringHeight < lineHeight then
		stringHeight = lineHeight
	end

	local Ypadding = lineHeight * (self.profile.messageLinePadding or 0.25)
	self:SetHeight(stringHeight + Ypadding * 2)

	local rightBgWidth = math_max(50, self.profile.frameWidth - 50)
	self:SetGradientBackground(
		50,
		rightBgWidth,
		self.profile.chatBackgroundColor or { r = 17/255, g = 17/255, b = 17/255 },
		self.profile.chatBackgroundOpacity or 0.15
	)

	self:UpdateIcons()
	self:UpdateHyperlinks()
end

function MessageLineMixin:UpdateIcons()
	local pool = self.iconTextures
	for i = 1, #pool do pool[i]:Hide() end

	local icons = self.iconList
	if not icons or #icons == 0 then return end

	local fs = GetMeasureFontString()
	local fontPath, fontSize, fontFlags = self.text:GetFont()
	if fontPath then fs:SetFont(fontPath, fontSize, fontFlags) end

	local leftPadding = self.profile.messageLeftPadding or 3
	local wrapWidth = self.profile.frameWidth - leftPadding - 6
	fs:SetWidth(0)
	fs:SetText("Ay")
	local lineHeight = fs:GetStringHeight() or 12

	for i = 1, #icons do
		local icon = icons[i]
		local t = pool[i]
		if not t then
			t = self:CreateTexture(nil, "ARTWORK")
			pool[i] = t
		end

		local before = icon.before or ""
		fs:SetWidth(0)
		fs:SetText(before)
		local unwrappedWidth = fs:GetStringWidth() or 0

		fs:SetWidth(wrapWidth)
		fs:SetText(before)
		local wrappedHeight = fs:GetStringHeight() or lineHeight
		local lineCount = math_max(1, math_floor(wrappedHeight / lineHeight + 0.5))

		local x = (lineCount == 1) and unwrappedWidth or (unwrappedWidth % wrapWidth)
		if x < 5 then x = 0 end
		local y = -lineHeight * (lineCount - 0.5)

		local iconW, iconH = icon.w, icon.h
		local wasScaled = false
		if iconH > lineHeight then
			local scale = lineHeight / iconH
			iconW = iconW * scale
			iconH = lineHeight
			wasScaled = true
		end

		local iconOffsetX = wasScaled and 0 or (icon.offsetX or 0)
		local iconOffsetY = wasScaled and 0 or (icon.offsetY or 0)

		t:SetTexture(icon.path)
		if icon.texCoords then
			t:SetTexCoord(icon.texCoords.left, icon.texCoords.right, icon.texCoords.top, icon.texCoords.bottom)
		else
			t:SetTexCoord(0, 1, 0, 1)
		end
		t:SetSize(iconW, iconH)
		t:ClearAllPoints()
		t:SetPoint("LEFT", self.text, "TOPLEFT", x + iconOffsetX, y + iconOffsetY)
		t:Show()
	end
end

local function stripHyperlinks(str)
	return (string_gsub(str, "|H.-|h(.-)|h", "%1"))
end

local function stripColors(str)
	local s = string_gsub(str, "|c%x%x%x%x%x%x%x%x", "")
	return (string_gsub(s, "|r", ""))
end

function MessageLineMixin:UpdateHyperlinks()
	local buttons = self.linkButtons
	for i = 1, #buttons do buttons[i]:Hide() end

	local text = self.displayText or self.processedText
	if not text or not string_find(text, "|H", 1, true) then return end

	local textXPad = self.profile.messageLeftPadding or 3
	local textWidth = self.profile.frameWidth - textXPad - 6

	local fs = GetMeasureFontString()
	local fontPath, fontSize, fontFlags = self.text:GetFont()
	if fontPath then fs:SetFont(fontPath, fontSize, fontFlags) end

	fs:SetWidth(0)
	fs:SetText("Ay")
	local oneLineH = fs:GetStringHeight() or 14

	local count = 0
	local pos = 1
	while true do
		local s, e, link, linkText = string_find(text, "|H(.-)|h(.-)|h", pos)
		if not s then break end
		pos = e + 1
		count = count + 1

		local btn = buttons[count]
		if not btn then
			btn = CreateFrame("Button", nil, self)
			btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			btn:SetScript("OnClick", function(b, mouseButton)
				if b._link then
					Glass:Dispatch("HYPERLINK_CLICK", { b._link, b._text, mouseButton })
				end
			end)
			btn:SetScript("OnEnter", function(b)
				if b._link and self.profile.mouseOverTooltips then
					Glass:Dispatch("HYPERLINK_ENTER", { b._link, b._text })
				end
			end)
			btn:SetScript("OnLeave", function(b)
				if b._link then
					Glass:Dispatch("HYPERLINK_LEAVE", b._link)
				end
			end)
			buttons[count] = btn
		end

		btn._link = link
		btn._text = linkText
		btn:ClearAllPoints()

		local prefix = string_sub(text, 1, s - 1)
		local strippedPrefix = stripHyperlinks(prefix)
		local cleanLinkText = stripColors(linkText)

		fs:SetWidth(0)
		fs:SetText(strippedPrefix)
		local prefixUnwrappedWidth = fs:GetStringWidth() or 0

		fs:SetText(cleanLinkText)
		local linkWidth = fs:GetStringWidth() or 0

		fs:SetWidth(textWidth)
		fs:SetText(strippedPrefix ~= "" and strippedPrefix or "")
		local prefixWrappedHeight = strippedPrefix ~= "" and (fs:GetStringHeight() or oneLineH) or 0
		local startLine = math_max(0, math_floor(prefixWrappedHeight / oneLineH + 0.5))
		if strippedPrefix ~= "" and prefixWrappedHeight > 0 then
			startLine = startLine - 1
		end

		local xPos = 0
		if strippedPrefix ~= "" then
			xPos = prefixUnwrappedWidth % textWidth
			if prefixUnwrappedWidth > 0 and xPos < 1 then
				xPos = 0
				startLine = startLine + 1
			end
		end

		local spaceOnLine = textWidth - xPos
		if linkWidth <= spaceOnLine then
			btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", xPos, -startLine * oneLineH)
			btn:SetSize(math_max(4, linkWidth), oneLineH)
		else
			local strippedUpToEnd = stripHyperlinks(string_sub(text, 1, e))
			fs:SetWidth(textWidth)
			fs:SetText(strippedUpToEnd)
			local totalHeight = fs:GetStringHeight() or oneLineH
			local endLine = math_max(startLine, math_floor(totalHeight / oneLineH + 0.5) - 1)

			btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", 0, -startLine * oneLineH)
			btn:SetSize(textWidth, oneLineH * (endLine - startLine + 1))
		end

		btn:Show()
	end
end

function MessageLineMixin:UpdateTextures()
	local rightBgWidth = math_max(50, self.profile.frameWidth - 50)
	self:SetGradientBackground(
		50,
		rightBgWidth,
		self.profile.chatBackgroundColor or { r = 17/255, g = 17/255, b = 17/255 },
		self.profile.chatBackgroundOpacity or 0.15
	)
end

function MessageLineMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then unsubscribe() end
		end
		self.subscriptions = nil
	end
end

local function CreateMessageLine(parent, profile)
	local FadingFrameMixin = Glass.Components.FadingFrameMixin
	local GradientBackgroundMixin = Glass.Components.GradientBackgroundMixin

	local frame = CreateFrame("Frame", nil, parent)
	local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

	object.profile = profile or Chatto.db.profile.glass
	FadingFrameMixin.Init(object)
	GradientBackgroundMixin.Init(object)
	MessageLineMixin.Init(object)

	return object
end

local function CreateMessageLinePool(parent, profile)
	return CreateObjectPool(function()
		return CreateMessageLine(parent, profile)
	end, function(_, message)
		message:QuickHide()
	end)
end

Glass.Components.CreateMessageLine = CreateMessageLine
Glass.Components.CreateMessageLinePool = CreateMessageLinePool
