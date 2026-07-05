local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local CreateFrame = CreateFrame
local Mixin = Mixin
local CreateObjectPool = CreateObjectPool
local ipairs = ipairs
local pairs = pairs
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local math_floor = math.floor
local type = type
local pcall = pcall
local C_Timer = C_Timer
local getmetatable = getmetatable

local FramePrototype = getmetatable(CreateFrame("Frame")).__index
local Frame_Show = FramePrototype.Show
local Frame_Hide = FramePrototype.Hide
local Frame_SetScript = FramePrototype.SetScript

--------------------------------------------------------------------------------
-- 1. NewMessageAlertFrame
--------------------------------------------------------------------------------

local NewMessageAlertFrameMixin = {}

function NewMessageAlertFrameMixin:Init()
	self:SetHeight(20)
	self:SetPoint("BOTTOMLEFT")
	self:SetPoint("BOTTOMRIGHT")
	self:SetFadeInDuration(0.15)
	self:SetFadeOutDuration(0.15)

	if self.text == nil then
		self.text = self:CreateFontString(nil, "ARTWORK", "ChatFrame1Font")
	end
	
	local indicatorColor = self.profile.scrollIndicatorColor or { r = 223/255, g = 186/255, b = 105/255 }
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	self.text:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	self.text:SetPoint("BOTTOMLEFT", 30, 10)
	self.text:SetText("Unread messages")

	if self.bottomLine == nil then
		local GradientBackgroundMixin = Glass.Components.GradientBackgroundMixin
		self.bottomLine = CreateFrame("Frame", nil, self)
		self.bottomLine = Mixin(self.bottomLine, GradientBackgroundMixin)
		GradientBackgroundMixin.Init(self.bottomLine)
		self.bottomLine:SetHeight(1)
		self.bottomLine:SetPoint("BOTTOMLEFT")
		self.bottomLine:SetPoint("BOTTOMRIGHT")
	end
	local lineOpacity = 0.65 * indicatorOpacity
	self.bottomLine:SetGradientBackground(15, 15, indicatorColor, lineOpacity)
end

function NewMessageAlertFrameMixin:UpdateIndicatorStyle()
	local indicatorColor = self.profile.scrollIndicatorColor or { r = 223/255, g = 186/255, b = 105/255 }
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	if self.text then
		self.text:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	end
	if self.bottomLine then
		local lineOpacity = 0.65 * indicatorOpacity
		self.bottomLine:SetGradientBackground(15, 15, indicatorColor, lineOpacity)
	end
end

local function CreateNewMessageAlertFrame(parent, profile)
	local FadingFrameMixin = Glass.Components.FadingFrameMixin
	local frame = CreateFrame("Frame", nil, parent)
	local object = Mixin(frame, FadingFrameMixin, NewMessageAlertFrameMixin)
	object.profile = profile or Chatto.db.profile.glass
	FadingFrameMixin.Init(object)
	NewMessageAlertFrameMixin.Init(object)
	return object
end

--------------------------------------------------------------------------------
-- 2. ScrollOverlayFrame
--------------------------------------------------------------------------------

local ScrollOverlayFrame = {}

function ScrollOverlayFrame:Init()
	local overlayHeight = 28
	self:SetHeight(overlayHeight)
	self:ClearAllPoints()

	local mainContainer = self:GetParent():GetParent()
	if self.profile.editBoxAnchor == "ABOVE" then
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", 0, self.profile.editBoxYOffset or 5)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", 0, self.profile.editBoxYOffset or 5)
	else
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", 0, self.profile.editBoxYOffset or -5)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", 0, self.profile.editBoxYOffset or -5)
	end

	self:SetFadeInDuration(0.3)
	self:SetFadeOutDuration(0.15)

	local bgColor = self.profile.scrollIndicatorBgColor or { r = 17/255, g = 17/255, b = 17/255 }
	local bgOpacity = self.profile.scrollIndicatorBgOpacity or 0.65
	self:SetGradientBackground(15, 15, bgColor, bgOpacity)

	if self.icon == nil then
		self.icon = self:CreateTexture(nil, "ARTWORK")
	end
	self.icon:SetTexture("Interface\\AddOns\\Chatto\\Assets\\snapToBottomIcon")
	self.icon:SetWidth(16)
	self.icon:SetHeight(16)
	self.icon:SetPoint("BOTTOMLEFT", 15, 5)

	if self.snapToBottomFrame == nil then
		self.snapToBottomFrame = CreateFrame("Frame", nil, self)
	end
	self.snapToBottomFrame:ClearAllPoints()
	self.snapToBottomFrame:SetHeight(20)
	self.snapToBottomFrame:SetPoint("BOTTOMLEFT")
	self.snapToBottomFrame:SetPoint("BOTTOMRIGHT")
	self.snapToBottomFrame:EnableMouse(true)

	if self.newMessageAlertFrame == nil then
		self.newMessageAlertFrame = CreateNewMessageAlertFrame(self, self.profile)
	end
	self.newMessageAlertFrame:QuickHide()

	if self.snapToPresentText == nil then
		self.snapToPresentText = self:CreateFontString(nil, "ARTWORK", "ChatFrame1Font")
	end
	self.snapToPresentText:ClearAllPoints()
	local indicatorColor = self.profile.scrollIndicatorColor or { r = 223/255, g = 186/255, b = 105/255 }
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	self.snapToPresentText:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	self.snapToPresentText:SetPoint("BOTTOMLEFT", 30, 10)
	self.snapToPresentText:SetText("Bring me to the present")
	self.snapToPresentText:Show()
end

function ScrollOverlayFrame:UpdatePosition()
	self:ClearAllPoints()
	local mainContainer = self:GetParent():GetParent()
	if self.profile.editBoxAnchor == "ABOVE" then
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", 0, self.profile.editBoxYOffset or 5)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", 0, self.profile.editBoxYOffset or 5)
	else
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", 0, self.profile.editBoxYOffset or -5)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", 0, self.profile.editBoxYOffset or -5)
	end
end

function ScrollOverlayFrame:UpdateIndicatorStyle()
	local indicatorColor = self.profile.scrollIndicatorColor or { r = 223/255, g = 186/255, b = 105/255 }
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	if self.snapToPresentText then
		self.snapToPresentText:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	end
	local bgColor = self.profile.scrollIndicatorBgColor or { r = 17/255, g = 17/255, b = 17/255 }
	local bgOpacity = self.profile.scrollIndicatorBgOpacity or 0.65
	self:SetGradientBackground(15, 15, bgColor, bgOpacity)
	if self.newMessageAlertFrame and self.newMessageAlertFrame.UpdateIndicatorStyle then
		self.newMessageAlertFrame:UpdateIndicatorStyle()
	end
end

function ScrollOverlayFrame:SetScript(name, callback)
	if name == "OnClickSnapFrame" then
		self.snapToBottomFrame:SetScript("OnMouseDown", callback)
		return
	end
	Frame_SetScript(self, name, callback)
end

function ScrollOverlayFrame:ShowNewMessageAlert()
	if self.snapToPresentText then self.snapToPresentText:Hide() end
	self.newMessageAlertFrame:Show()
end

function ScrollOverlayFrame:HideNewMessageAlert()
	self.newMessageAlertFrame:Hide()
	if self.snapToPresentText then self.snapToPresentText:Show() end
end

function ScrollOverlayFrame:Show()
	if self.profile.hideScrollIndicator then return end
	local FadingFrameMixin = Glass.Components.FadingFrameMixin
	FadingFrameMixin.Show(self)
end

local function CreateScrollOverlayFrame(parent, profile)
	local FadingFrameMixin = Glass.Components.FadingFrameMixin
	local GradientBackgroundMixin = Glass.Components.GradientBackgroundMixin

	local frame = CreateFrame("Frame", nil, parent)
	local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ScrollOverlayFrame)
	object.profile = profile or Chatto.db.profile.glass
	FadingFrameMixin.Init(object)
	GradientBackgroundMixin.Init(object)
	ScrollOverlayFrame.Init(object)
	return object
end
Glass.Components.CreateScrollOverlayFrame = CreateScrollOverlayFrame

--------------------------------------------------------------------------------
-- 3. SlidingMessageFrame
--------------------------------------------------------------------------------

local SlidingMessageFrameMixin = {}

function SlidingMessageFrameMixin:Init(chatFrame)
	self.profile = self.window and self.window.profile or Chatto.db.profile.glass
	self.config = {
		height = self.profile.frameHeight - 28 - 5,
		width = self.profile.frameWidth,
		overflowHeight = 60,
	}
	self.state = {
		mouseOver = false,
		prevEasingHandle = nil,
		incomingMessages = {},
		messages = {},
		head = nil,
		tail = nil,
		isCombatLog = (chatFrame == _G.ChatFrame2),
		scrollAtBottom = true,
		unreadMessages = false,
	}
	self.chatFrame = chatFrame

	if self.state.isCombatLog then
		local buttonFrame = _G[chatFrame:GetName() .. "ButtonFrame"]
		if buttonFrame then buttonFrame:Hide() end
		self:SetHeight(self.config.height + self.config.overflowHeight)
		self:SetWidth(self.config.width)
		self:SetPoint("TOPLEFT", 0, -(28 + 5))
		self:SetVerticalScroll(self.config.overflowHeight)
		self:Hide()
		return
	end

	local buttonFrame = _G[chatFrame:GetName() .. "ButtonFrame"]
	if buttonFrame then buttonFrame:Hide() end

	chatFrame:SetAlpha(0)
	if not self:IsHooked(chatFrame, "SetAlpha") then
		self:RawHook(chatFrame, "SetAlpha", function()
			self.hooks[chatFrame].SetAlpha(chatFrame, 0)
		end, true)
	end
	chatFrame:EnableMouse(false)
	chatFrame:EnableMouseWheel(false)

	if not self:IsHooked(chatFrame, "Show") then
		self:SecureHook(chatFrame, "Show", function() chatFrame:Hide() end)
	end
	chatFrame:Hide()

	self:SetHeight(self.config.height + self.config.overflowHeight)
	self:SetWidth(self.config.width)
	self:SetPoint("TOPLEFT", 0, -(28 + 5))
	self:SetVerticalScroll(self.config.overflowHeight)

	if self.overlay == nil then
		self.overlay = CreateScrollOverlayFrame(self, self.profile)
		self.overlay:QuickHide()
		self.overlay:SetScript("OnClickSnapFrame", function() self:SnapToBottom() end)
	end

	self:SetScript("OnMouseWheel", function(frame, delta)
		local maxScroll = self.state.scrollAtBottom and self:GetVerticalScrollRange() + self.config.overflowHeight or self:GetVerticalScrollRange()
		local minScroll = self.config.height + self.config.overflowHeight
		local scrollValue

		if delta < 0 then
			scrollValue = math_min(self:GetVerticalScroll() + 20, maxScroll)
		else
			scrollValue = math_max(self:GetVerticalScroll() - 20, math_min(minScroll, maxScroll))
		end

		self:UpdateScrollChildRect()
		self:SetVerticalScroll(scrollValue)
		self.state.scrollAtBottom = (scrollValue == maxScroll)

		if self.state.scrollAtBottom then
			self:SetHeight(self.config.height + self.config.overflowHeight)
			self.overlay:Hide()
			self.overlay:HideNewMessageAlert()
			self.state.unreadMessages = false
		else
			self:SetHeight(self.config.height)
			self.overlay:Show()
		end

		for _, message in ipairs(self.state.messages) do message:Show() end
	end)

	self:EnableMouse(true)
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseDown", function(frame, button)
		if button == "LeftButton" and frame.window then
			Glass.UIManager:SetActiveWindow(frame.window)
		end
	end)

	if self.slider == nil then
		self.slider = CreateFrame("Frame", nil, self)
	end
	self.slider:SetHeight(self.config.height + self.config.overflowHeight)
	self.slider:SetWidth(self.config.width)
	self:SetScrollChild(self.slider)

	if self.slider.bg == nil then
		self.slider.bg = self.slider:CreateTexture(nil, "BACKGROUND")
	end
	self.slider.bg:SetAllPoints()
	self.slider.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.slider.bg:SetVertexColor(0, 0, 0, 0)

	if self.messageFramePool == nil then
		self.messageFramePool = Glass.Components.CreateMessageLinePool(self.slider, self.profile)
	end

	-- Hook AddMessage to intercept Blizzard's outputs
	self:Hook(chatFrame, "AddMessage", function(frame, text, ...)
		local isRestoring = Glass.UIManager and Glass.UIManager._restoringMessages
		if not isRestoring and text ~= nil then
			-- Pass it through Chatto's general pipeline!
			local filtered, newR, newG, newB = Chatto:FilterMessage(frame, text, ...)
			if filtered == nil then return end
			text = filtered
		end
		self:AddMessage(frame, text, ...)
	end, true)

	self:Show()

	self.subscriptions = {
		Glass:Subscribe("MOUSE_ENTER", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = true
			if not self.state.scrollAtBottom then self.overlay:Show() end
			for _, message in ipairs(self.state.messages) do
				if message.hideTimer then message.hideTimer:Cancel(); message.hideTimer = nil end
			end
			if self.profile.messagesOnHover then
				local fadeDur = (self.profile.messageAnimations ~= false) and (self.profile.chatFadeInDuration or 0.3) or 0
				for _, message in ipairs(self.state.messages) do message:FadeIn(fadeDur) end
			end
		end),
		Glass:Subscribe("MOUSE_LEAVE", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = false
			self.overlay:HideDelay(self.profile.chatHoldTime)
			if not self.profile.messagesAlwaysVisible then
				for _, message in ipairs(self.state.messages) do message:HideDelay(self.profile.chatHoldTime) end
			end
		end),
		Glass:Subscribe("EDIT_FOCUS_GAINED", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = true
			for _, message in ipairs(self.state.messages) do
				if message.hideTimer then message.hideTimer:Cancel(); message.hideTimer = nil end
			end
			local fadeDur = (self.profile.messageAnimations ~= false) and (self.profile.chatFadeInDuration or 0.3) or 0
			for _, message in ipairs(self.state.messages) do message:FadeIn(fadeDur) end
			if self.state.unreadMessages or (self.overlay and self.overlay:IsShown()) then
				self:SnapToBottom()
			end
		end),
		Glass:Subscribe("EDIT_FOCUS_LOST", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = false
			self.overlay:HideDelay(self.profile.chatHoldTime)
			if not self.profile.messagesAlwaysVisible then
				for _, message in ipairs(self.state.messages) do message:HideDelay(self.profile.chatHoldTime) end
			end
		end),
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			self:OnConfigChanged(key)
		end),
	}
end

function SlidingMessageFrameMixin:SnapToBottom()
	self.state.scrollAtBottom = true
	self.state.unreadMessages = false
	self.overlay:Hide()
	self.overlay:HideNewMessageAlert()

	local startOffset = math_max(self:GetVerticalScrollRange() - self.config.height * 2, self:GetVerticalScroll())
	local endOffset = self:GetVerticalScrollRange()

	if Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:Ease(
			function(offset) self:SetVerticalScroll(offset) end,
			startOffset,
			endOffset,
			0.3,
			Glass.Libs.LibEasing.OutCubic,
			function() self:SetHeight(self.config.height + self.config.overflowHeight) end
		)
	else
		self:SetVerticalScroll(endOffset)
		self:SetHeight(self.config.height + self.config.overflowHeight)
	end
end

function SlidingMessageFrameMixin:OnConfigChanged(key)
	if self.state.isCombatLog then return end

	if key == "messageFont" or key == "messageFontSize" or key == "frameWidth" or key == "frameHeight" or 
	   key == "messageLeading" or key == "messageLinePadding" or key == "indentWordWrap" then
		
		self.config.height = self.profile.frameHeight - 28 - 5
		self.config.width = self.profile.frameWidth
		self:SetHeight(self.config.height + self.config.overflowHeight)
		self:SetWidth(self.config.width)

		for _, message in ipairs(self.state.messages) do message:UpdateFrame() end

		local contentHeight = 0
		for _, m in ipairs(self.state.messages) do contentHeight = contentHeight + (m:GetHeight() or 0) end
		self.slider:SetHeight(self.config.height + self.config.overflowHeight + contentHeight)
		self.slider:SetWidth(self.config.width)

		self.state.scrollAtBottom = true
		self.state.unreadMessages = false
		self:UpdateScrollChildRect()
		self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
		self.overlay:Hide()
		self.overlay:HideNewMessageAlert()

		if self.overlay and self.overlay.UpdatePosition then self.overlay:UpdatePosition() end
	end

	if key == "chatBackgroundOpacity" or key == "chatBackgroundColor" then
		for _, message in ipairs(self.state.messages) do message:UpdateTextures() end
	end

	if key == "messagesOnHover" and self.profile.messagesOnHover and self.state.mouseOver then
		for _, message in ipairs(self.state.messages) do message:Show() end
	end

	if key == "messagesAlwaysVisible" then
		if self.profile.messagesAlwaysVisible then
			for _, message in ipairs(self.state.messages) do
				if message.hideTimer then message.hideTimer:Cancel(); message.hideTimer = nil end
				message:Show()
			end
		elseif not self.state.mouseOver then
			for _, message in ipairs(self.state.messages) do message:HideDelay(self.profile.chatHoldTime) end
		end
	end

	if key == "scrollIndicatorColor" or key == "scrollIndicatorOpacity" or 
	   key == "scrollIndicatorBgColor" or key == "scrollIndicatorBgOpacity" or key == "hideScrollIndicator" then
		if self.overlay and self.overlay.UpdateIndicatorStyle then self.overlay:UpdateIndicatorStyle() end
	end
end

function SlidingMessageFrameMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then unsubscribe() end
		end
		self.subscriptions = nil
	end
end

function SlidingMessageFrameMixin:CreateMessageFrame(frame, text, red, green, blue, messageId, holdTime)
	red = red or 1
	green = green or 1
	blue = blue or 1
	local message = self.messageFramePool:Acquire()
	message.smf = self
	message.text:SetTextColor(red, green, blue, 1)
	message:SetMessageText(text)
	message:UpdateFrame()
	return message
end

function SlidingMessageFrameMixin:AddMessage(...)
	local args = { ... }
	table.insert(self.state.incomingMessages, args)
end

function SlidingMessageFrameMixin:RecomputeContentHeight()
	local contentHeight = 0
	for _, m in ipairs(self.state.messages) do contentHeight = contentHeight + (m:GetHeight() or 0) end
	self.slider:SetHeight(self.config.height + self.config.overflowHeight + contentHeight)
	self:UpdateScrollChildRect()
	if self.state.scrollAtBottom then
		self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
	end
end

function SlidingMessageFrameMixin:OnFrame()
	if self.state.pendingMeasure and #self.state.pendingMeasure > 0 then
		local changed = false
		for _, message in ipairs(self.state.pendingMeasure) do
			local before = message:GetHeight() or 0
			message:UpdateFrame()
			if math_abs((message:GetHeight() or 0) - before) > 0.5 then changed = true end
		end
		self.state.pendingMeasure = {}
		if changed then self:RecomputeContentHeight() end
	end

	if #self.state.incomingMessages > 0 then
		local incoming = {}
		for _, msg in ipairs(self.state.incomingMessages) do table.insert(incoming, msg) end
		self.state.incomingMessages = {}
		self:Update(incoming)
	end
end

function SlidingMessageFrameMixin:Update(incoming)
	local newMessages = {}
	local baseLevel = (self.slider:GetFrameLevel() or 1) + 1
	if not self.state.nextFrameLevel then self.state.nextFrameLevel = baseLevel end

	if self.state.nextFrameLevel > 500 then
		local level = baseLevel
		for _, msg in ipairs(self.state.messages) do
			msg:SetFrameLevel(level)
			level = level + 1
		end
		self.state.nextFrameLevel = level
	end

	for _, msgArgs in ipairs(incoming) do
		local messageFrame = self:CreateMessageFrame(unpack(msgArgs))
		messageFrame:SetPoint("BOTTOMLEFT")
		messageFrame:SetFrameLevel(self.state.nextFrameLevel)
		self.state.nextFrameLevel = self.state.nextFrameLevel + 1

		if self.state.head then
			self.state.head:ClearAllPoints()
			self.state.head:SetPoint("BOTTOMLEFT", messageFrame, "TOPLEFT")
		end

		if self.state.tail == nil then self.state.tail = messageFrame end
		if self.state.head == nil then self.state.head = messageFrame end
		self.state.head = messageFrame

		table.insert(newMessages, messageFrame)
	end

	local offset = 0
	for _, m in ipairs(newMessages) do offset = offset + m:GetHeight() end
	local newHeight = self.slider:GetHeight() + offset
	self.slider:SetHeight(newHeight)

	if self.state.scrollAtBottom then
		if self.state.prevEasingHandle ~= nil then
			Glass.Libs.LibEasing:StopEasing(self.state.prevEasingHandle)
		end
		local startOffset = self:GetVerticalScroll()
		local endOffset = newHeight - self:GetHeight() + self.config.overflowHeight

		if (self.profile.messageAnimations ~= false) and self.profile.chatSlideInDuration > 0 and Glass.Libs.LibEasing then
			self.state.prevEasingHandle = Glass.Libs.LibEasing:Ease(
				function(n) self:SetVerticalScroll(n) end,
				startOffset, endOffset, self.profile.chatSlideInDuration, Glass.Libs.LibEasing.OutCubic
			)
		else
			self:SetVerticalScroll(endOffset)
		end
	else
		self.state.unreadMessages = true
		self.overlay:Show()
		self.overlay:ShowNewMessageAlert()
		if not self.state.mouseOver then
			self.overlay:HideDelay(self.profile.chatHoldTime)
		end
	end

	for _, message in ipairs(newMessages) do
		message:Show()
		if not self.state.mouseOver and not self.profile.messagesAlwaysVisible then
			message:HideDelay(self.profile.chatHoldTime)
		end
		table.insert(self.state.messages, message)

		self.state.pendingMeasure = self.state.pendingMeasure or {}
		table.insert(self.state.pendingMeasure, message)
	end

	local historyLimit = self.profile.messageHistoryLimit or 128
	if #self.state.messages > historyLimit then
		local overflow = #self.state.messages - historyLimit
		for i = 1, overflow do
			local old = table.remove(self.state.messages, 1)
			self.messageFramePool:Release(old)
		end
	end

	-- Flash tab if not active
	if #newMessages > 0 then
		local chatFrameName = self.chatFrame:GetName()
		local myTab = _G[chatFrameName .. "Tab"]
		if myTab and Glass.Components.selectedTab ~= myTab then
			if myTab.FlashTab then myTab:FlashTab() end
		end
	end
end

local function CreateSlidingMessageFrame(name, parent, chatFrame)
	local frame = CreateFrame("ScrollFrame", name, parent)
	local object = Mixin(frame, SlidingMessageFrameMixin)
	Glass.Libs.AceHook:Embed(object)
	if chatFrame then object:Init(chatFrame) end
	object:Hide()
	return object
end

local function CreateSlidingMessageFramePool(parent, window)
	return CreateObjectPool(function()
		local smf = CreateSlidingMessageFrame(nil, parent)
		smf.window = window
		return smf
	end, function(_, smf)
		smf:Hide()
		smf:Destroy()
		if smf.chatFrame and not smf.state.isCombatLog then
			if smf:IsHooked(smf.chatFrame, "AddMessage") then smf:Unhook(smf.chatFrame, "AddMessage") end
			if smf:IsHooked(smf.chatFrame, "SetAlpha") then smf:Unhook(smf.chatFrame, "SetAlpha") end
			if smf:IsHooked(smf.chatFrame, "Show") then smf:Unhook(smf.chatFrame, "Show") end
		end
		if smf.state then
			smf.state.head = nil
			smf.state.tail = nil
			smf.state.messages = {}
			smf.state.incomingMessages = {}
			smf.state.nextFrameLevel = nil
		end
		if smf.messageFramePool then smf.messageFramePool:ReleaseAll() end
	end)
end

Glass.Components.CreateSlidingMessageFrame = CreateSlidingMessageFrame
Glass.Components.CreateSlidingMessageFramePool = CreateSlidingMessageFramePool
