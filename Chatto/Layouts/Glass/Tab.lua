local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local _G = _G
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local type = type
local CreateFrame = CreateFrame
local Mixin = Mixin

local Hooker = {}
LibStub("AceHook-3.0"):Embed(Hooker)

local tabTexs = { "", "Selected", "Highlight" }

local ChatTabMixin = {}

function ChatTabMixin:Init(slidingMessageFrame)
	self.slidingMessageFrame = slidingMessageFrame
	self.chatFrame = slidingMessageFrame.chatFrame
	local dropDown = _G[self.chatFrame:GetName() .. "TabDropDown"]

	-- Clear default Blizzard textures
	for _, texName in ipairs(tabTexs) do
		local leftTex = _G[self:GetName() .. texName .. "Left"]
		local middleTex = _G[self:GetName() .. texName .. "Middle"]
		local rightTex = _G[self:GetName() .. texName .. "Right"]
		if leftTex then leftTex:SetTexture() end
		if middleTex then middleTex:SetTexture() end
		if rightTex then rightTex:SetTexture() end
	end

	self:SetHeight(28) -- Dock height constant

	local tabText = self.Text or _G[self:GetName() .. "Text"] or self:GetFontString()
	self.Text = tabText

	self:UpdateFontFromProfile()

	if tabText then
		tabText:ClearAllPoints()
		tabText:SetPoint("LEFT", 5, 0) -- Text X padding constant
		local textWidth = tabText:GetStringWidth()
		if textWidth and textWidth > 10 then
			self:SetWidth(textWidth + 10)
		else
			self:SetWidth(60)
		end
	else
		self:SetWidth(60)
	end

	-- Lock alpha to 1 (Glass manages dock-level alpha instead)
	if not Hooker:IsHooked(self, "SetAlpha") then
		Hooker:RawHook(self, "SetAlpha", function(self, alpha)
			Hooker.hooks[self].SetAlpha(self, 1)
		end, true)
	end

	-- Dynamically set width based on text width
	if not Hooker:IsHooked(self, "SetWidth") then
		Hooker:RawHook(self, "SetWidth", function(self, width)
			local textWidth = 0
			if self.Text then
				textWidth = self.Text:GetStringWidth() or 0
			end
			local newWidth = textWidth + 10
			if newWidth < 40 then newWidth = 60 end
			Hooker.hooks[self].SetWidth(self, newWidth)
		end, true)
	end

	-- Force unselected tab text colors
	if tabText and not Hooker:IsHooked(tabText, "SetTextColor") then
		Hooker:RawHook(tabText, "SetTextColor", function(self, r, g, b, a)
			if self.chatFrame and self.chatFrame.isTemporary then
				Hooker.hooks[self].SetTextColor(self, r, g, b, a)
			else
				local col = Chatto.Colors.normal
				Hooker.hooks[self].SetTextColor(self, col[1], col[2], col[3])
			end
		end, true)
	end

	-- SetText recalculates width
	if tabText and not Hooker:IsHooked(tabText, "SetText") then
		Hooker:RawHook(tabText, "SetText", function(fontString, text)
			Hooker.hooks[tabText].SetText(fontString, text)
			if not self._widthUpdateFrame then
				self._widthUpdateFrame = CreateFrame("Frame")
			end
			self._widthUpdateFrame:SetScript("OnUpdate", function(frame)
				frame:SetScript("OnUpdate", nil)
				self:SetWidth()
			end)
		end, true)
	end

	-- Click tab handler
	local originalOnClick = self:GetScript("OnClick")
	self:SetScript("OnClick", function(frame, button)
		if FCF_StopAlertFlash then
			FCF_StopAlertFlash(self.chatFrame)
		end
		Glass.Components.SelectChatTab(self, true)
		if self.chatFrame == _G.ChatFrame2 then return end -- Skip Blizzard Combat Log click code
		if originalOnClick then
			originalOnClick(frame, button)
		end
	end)

	if self.chatFrame == _G.ChatFrame1 or self.chatFrame == _G.ChatFrame2 then
		self:RegisterForDrag()
	end
end

function ChatTabMixin:UpdateFontFromProfile()
	local fontPath = Glass.Libs.LSM:Fetch("font", self.slidingMessageFrame.profile.dockFont)
	local fontSize = self.slidingMessageFrame.profile.dockFontSize
	local fontFlags = self.slidingMessageFrame.profile.dockFontFlags
	if fontPath and fontSize and self.Text then
		self.Text:SetFont(fontPath, fontSize, fontFlags or "")
	end
end

-- Custom Flash implementation
function ChatTabMixin:FlashTab()
	if self._isFlashing then return end
	self._isFlashing = true

	if not self._flashFrame then
		self._flashFrame = CreateFrame("Frame")
	end

	local totalTime = 0
	local flashStyle = self.slidingMessageFrame.profile.flashTabStyle or "blink"
	local highlightColor = { r = 1, g = 1, b = 1 }
	local activeColor = self.slidingMessageFrame.profile.tabActiveColor or { r = 1, g = 0.75, b = 0 }
	local dimColor = { r = 0.5, g = 0.5, b = 0.5 }

	self._flashFrame:SetScript("OnUpdate", function(frame, delta)
		totalTime = totalTime + delta
		if totalTime > 15 or Glass.Components.selectedTab == self then
			frame:SetScript("OnUpdate", nil)
			self._isFlashing = false
			local tabText = self.Text
			if tabText then
				local col = (Glass.Components.selectedTab == self) and { r = 1, g = 1, b = 1 } or { r = activeColor.r, r = activeColor.g, b = activeColor.b }
				tabText:SetTextColor(col.r or 1, col.g or 1, col.b or 1)
			end
			return
		end

		if self.Text then
			local cyclePos = math_floor(totalTime / 0.5) % 2
			if cyclePos == 0 then
				self.Text:SetTextColor(highlightColor.r, highlightColor.g, highlightColor.b)
			else
				self.Text:SetTextColor(dimColor.r, dimColor.g, dimColor.b)
			end
		end
	end)
end

Glass.Components.CreateChatTab = function(slidingMessageFrame)
	local frameName = slidingMessageFrame.chatFrame:GetName()
	local tabName = frameName .. "Tab"
	local frame = _G[tabName]

	if not frame then return nil end

	if frame._glassInitialized then
		frame.slidingMessageFrame = slidingMessageFrame
		frame.chatFrame = slidingMessageFrame.chatFrame
		frame.glassDock = slidingMessageFrame.window and slidingMessageFrame.window.dock or _G["GlassChatDock"]
		return frame
	end

	local object = Mixin(frame, ChatTabMixin)
	object:Init(slidingMessageFrame)
	frame._glassInitialized = true
	object.glassDock = slidingMessageFrame.window and slidingMessageFrame.window.dock or _G["GlassChatDock"]

	return object
end

Glass.Components.UpdateTabPositions = function(tabs)
	local firstTab = tabs and tabs[1]
	if not firstTab then return end
	local ownerWindow = firstTab.slidingMessageFrame and firstTab.slidingMessageFrame.window
	local glassDock = ownerWindow and ownerWindow.dock or _G["GlassChatDock"]
	if not glassDock then return end

	local profile = ownerWindow and ownerWindow.profile or Chatto.db.profile.glass
	local tabPadding = profile.tabPadding or 5
	local tabSpacing = profile.tabSpacing or 5

	local xOffset = tabPadding
	for _, tab in ipairs(tabs) do
		if tab then
			tab:SetParent(glassDock)
			tab:SetFrameStrata("MEDIUM")
			tab:SetFrameLevel(11)
			tab:ClearAllPoints()
			tab:SetPoint("BOTTOMLEFT", glassDock, "BOTTOMLEFT", xOffset, 0)
			
			if Hooker.hooks[tab] and Hooker.hooks[tab].SetAlpha then
				Hooker.hooks[tab].SetAlpha(tab, 1)
			else
				tab:SetAlpha(1)
			end
			tab:Show()

			local tabWidth = tab:GetWidth()
			if tabWidth < 30 then tabWidth = 60 end
			xOffset = xOffset + tabWidth + tabSpacing
		end
	end
end

Glass.Components.selectedTab = nil

Glass.Components.SelectChatTab = function(selectedTab, isUserClick)
	local visWindow = selectedTab.slidingMessageFrame and selectedTab.slidingMessageFrame.window
	local frames = visWindow and visWindow.frames or Glass.UIManager.state.frames
	local tabs = visWindow and visWindow.tabs or Glass.UIManager.state.tabs

	if visWindow and isUserClick then
		Glass.UIManager:SetActiveWindow(visWindow)
	end
	Glass.Components.selectedTab = selectedTab

	local selectedChatFrame = selectedTab.chatFrame
	if selectedChatFrame then
		_G.SELECTED_CHAT_FRAME = selectedChatFrame
		_G.SELECTED_DOCK_FRAME = selectedChatFrame
	end

	local combatLogFrame = _G.ChatFrame2
	local selectingCombatLog = (selectedChatFrame == combatLogFrame)

	local combatLogButtons = _G["CombatLogQuickButtonFrame"]
	if combatLogButtons then
		combatLogButtons:Hide()
		combatLogButtons:SetAlpha(0)
	end

	if combatLogFrame then
		if selectingCombatLog then
			combatLogFrame:Show()
			combatLogFrame:SetAlpha(1)
			combatLogFrame:EnableMouse(true)
			combatLogFrame:EnableMouseWheel(true)
			combatLogFrame:ClearAllPoints()
			combatLogFrame:SetPoint("TOPLEFT", Glass.UIManager.container, "TOPLEFT", 0, -28 - 30)
			combatLogFrame:SetPoint("BOTTOMRIGHT", Glass.UIManager.container, "BOTTOMRIGHT", 0, 0)
		else
			combatLogFrame:Hide()
			combatLogFrame:SetAlpha(0)
		end
	end

	for _, smf in pairs(frames) do
		if smf and smf.chatFrame then
			if smf.state and smf.state.isCombatLog then
				smf:Hide()
			elseif smf.chatFrame == selectedChatFrame then
				smf:Show()
			else
				smf:Hide()
			end
		end
	end

	for _, tab in pairs(tabs) do
		if tab then
			tab:Show()
			local tabText = tab.Text
			if tabText then
				if tab == selectedTab then
					tabText:SetTextColor(1, 1, 1)
				else
					local col = Chatto.Colors.normal
					tabText:SetTextColor(col[1], col[2], col[3])
				end
			end
		end
	end

	local visDock = visWindow and visWindow.dock or _G["GlassChatDock"]
	if visDock then visDock:Show() end
end
