local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local UIManager = {}
Glass.UIManager = UIManager

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local pairs = pairs
local type = type
local select = select
local unpack = unpack
local math_floor = math.floor
local PlaySound = PlaySound
local GetTime = GetTime
local C_Timer = C_Timer
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

--------------------------------------------------------------------------------
-- 1. Helper Mixins (FadingFrame and GradientBackground)
--------------------------------------------------------------------------------

local FadingFrameMixin = {}
Glass.Components.FadingFrameMixin = FadingFrameMixin

local function SafeSetAlphaAnimation(anim, fromAlpha, toAlpha)
	anim._fromAlpha = fromAlpha
	anim._toAlpha = toAlpha
	if anim.SetFromAlpha and anim.SetToAlpha then
		anim:SetFromAlpha(fromAlpha)
		anim:SetToAlpha(toAlpha)
	elseif anim.SetChange then
		anim:SetChange(toAlpha - fromAlpha)
	end
	if anim.SetSmoothing then
		anim:SetSmoothing("OUT")
	end
end

local FramePrototype = getmetatable(CreateFrame("Frame")).__index
local Frame_Show = FramePrototype.Show
local Frame_Hide = FramePrototype.Hide

function FadingFrameMixin:Init()
	if self.showAg == nil then
		self.showAg = self:CreateAnimationGroup()
		self.fadeIn = self.showAg:CreateAnimation("Alpha")
		SafeSetAlphaAnimation(self.fadeIn, 0, 1)
		self.fadeIn:SetDuration(0)
		self.showAg:SetScript("OnFinished", function()
			self:SetAlpha(1)
		end)
	end

	if self.hideAg == nil then
		self.hideAg = self:CreateAnimationGroup()
		self.fadeOut = self.hideAg:CreateAnimation("Alpha")
		SafeSetAlphaAnimation(self.fadeOut, 1, 0)
		self.fadeOut:SetDuration(0)
		self.hideAg:SetScript("OnFinished", function()
			self:SetAlpha(1)
			self:QuickHide()
		end)
	end
end

function FadingFrameMixin:QuickShow()
	if self.fadeHandle and Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end
	if self.hideTimer then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end
	self:SetAlpha(1)
	Frame_Show(self)
end

function FadingFrameMixin:QuickHide()
	if self.fadeHandle and Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end
	if self.hideTimer then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end
	self:SetAlpha(1)
	Frame_Hide(self)
end

function FadingFrameMixin:Show()
	if self.hideTimer then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end
	if self.fadeHandle and Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end
	self:SetAlpha(1)
	if not self:IsVisible() then
		Frame_Show(self)
	end
end

function FadingFrameMixin:FadeIn(duration)
	if self.hideTimer then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end
	if self.fadeHandle and Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	duration = duration or 0.3
	local startAlpha = self:GetAlpha()

	if not self:IsVisible() then
		self:SetAlpha(0)
		startAlpha = 0
		Frame_Show(self)
	end

	if duration > 0 and startAlpha < 1 and Glass.Libs.LibEasing then
		self.fadeHandle = Glass.Libs.LibEasing:Ease(
			function(alpha)
				self:SetAlpha(alpha)
			end,
			startAlpha,
			1,
			duration,
			Glass.Libs.LibEasing.OutCubic,
			function()
				self.fadeHandle = nil
				self:SetAlpha(1)
			end
		)
	else
		self:SetAlpha(1)
	end
end

function FadingFrameMixin:Hide()
	if self.hideTimer then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end
	if not self:IsVisible() then return end
	if self.fadeHandle and Glass.Libs.LibEasing then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	local duration = self.fadeOutDuration or 0
	if duration > 0 and Glass.Libs.LibEasing then
		self.fadeHandle = Glass.Libs.LibEasing:Ease(
			function(alpha)
				self:SetAlpha(alpha)
			end,
			self:GetAlpha(),
			0,
			duration,
			Glass.Libs.LibEasing.OutCubic,
			function()
				self.fadeHandle = nil
				Frame_Hide(self)
				self:SetAlpha(1)
			end
		)
	else
		self:SetAlpha(1)
		Frame_Hide(self)
	end
end

function FadingFrameMixin:HideDelay(delay)
	delay = delay or 10
	if delay < 1 then delay = 10 end
	if self:IsVisible() then
		if self.hideTimer then self.hideTimer:Cancel() end
		self.hideTimer = C_Timer.NewTimer(delay, function()
			self:Hide()
		end)
	end
end

function FadingFrameMixin:SetFadeInDuration(duration)
	self.fadeInDuration = duration
end

function FadingFrameMixin:SetFadeOutDuration(duration)
	self.fadeOutDuration = duration
end

local GradientBackgroundMixin = {}
Glass.Components.GradientBackgroundMixin = GradientBackgroundMixin

function GradientBackgroundMixin:Init() end

function GradientBackgroundMixin:SetGradientBackground(leftWidth, rightWidth, color, opacity)
	if self.centerBg == nil then
		self.centerBg = self:CreateTexture(nil, "BACKGROUND")
		self.centerBg:SetAllPoints()
		self.centerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	end
	self.centerBg:SetVertexColor(color.r, color.g, color.b, opacity)
	self.centerBg:Show()
end

--------------------------------------------------------------------------------
-- 2. Draggable Mover dialog & Mover handle frame
--------------------------------------------------------------------------------

local MoverDialogMixin = {}

function MoverDialogMixin:Init()
	self:SetFrameStrata("DIALOG")
	self:SetToplevel(true)
	self:SetWidth(360)
	self:SetHeight(110)
	self:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
		tileSize = 32,
		edgeSize = 32,
	})
	self:SetPoint("TOP", 0, -50)
	self:Hide()

	self:SetScript("OnShow", function() PlaySound("igMainMenuOption") end)
	self:SetScript("OnHide", function() PlaySound("gsTitleOptionExit") end)

	self.header = self:CreateTexture(nil, "ARTWORK")
	self.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	self.header:SetWidth(256)
	self.header:SetHeight(64)
	self.header:SetPoint("TOP", 0, 12)

	self.title = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	self.title:SetPoint("TOP", self.header, "TOP", 0, -14)
	self.title:SetText("Chatto (Glass)")

	self.desc = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	self.desc:SetJustifyV("TOP")
	self.desc:SetJustifyH("LEFT")
	self.desc:SetPoint("TOPLEFT", 18, -32)
	self.desc:SetPoint("BOTTOMRIGHT", -18, 48)
	self.desc:SetText("Chat frame unlocked. You can now drag the chat frame to reposition it.")

	self.lockButton = CreateFrame("Button", nil, self, "OptionsButtonTemplate")
	self.lockButton:SetText("Lock")
	self.lockButton:SetScript("OnClick", function()
		Glass:Dispatch("LOCK_MOVER")
	end)
	self.lockButton:SetPoint("BOTTOMRIGHT", -14, 14)

	Glass:Subscribe("LOCK_MOVER", function() self:Hide() end)
	Glass:Subscribe("UNLOCK_MOVER", function() self:Show() end)
end

local function CreateMoverDialog(name, parent)
	local frame = CreateFrame("Frame", name, parent)
	local object = Mixin(frame, MoverDialogMixin)
	object:Init()
	return object
end
Glass.Components.CreateMoverDialog = CreateMoverDialog

local MoverFrameMixin = {}

function MoverFrameMixin:Init()
	local editBoxMargin = 35
	self:ClearAllPoints()
	self:SetPoint(self.profile.positionAnchor.point, self.profile.positionAnchor.xOfs, self.profile.positionAnchor.yOfs)
	self:SetWidth(self.profile.frameWidth)
	self:SetHeight(self.profile.frameHeight + editBoxMargin)

	self:SetFrameStrata("DIALOG")
	self:SetToplevel(true)

	local GOLD = { 223 / 255, 186 / 255, 105 / 255 }

	self.bg = self:CreateTexture(nil, "BACKGROUND")
	self.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
	self.bg:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.10)
	self.bg:SetAllPoints()

	local function makeEdge()
		local t = self:CreateTexture(nil, "BORDER")
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
		return t
	end
	local thickness = 2
	self.edgeTop = makeEdge()
	self.edgeTop:SetPoint("TOPLEFT")
	self.edgeTop:SetPoint("TOPRIGHT")
	self.edgeTop:SetHeight(thickness)

	self.edgeBottom = makeEdge()
	self.edgeBottom:SetPoint("BOTTOMLEFT")
	self.edgeBottom:SetPoint("BOTTOMRIGHT")
	self.edgeBottom:SetHeight(thickness)

	self.edgeLeft = makeEdge()
	self.edgeLeft:SetPoint("TOPLEFT")
	self.edgeLeft:SetPoint("BOTTOMLEFT")
	self.edgeLeft:SetWidth(thickness)

	self.edgeRight = makeEdge()
	self.edgeRight:SetPoint("TOPRIGHT")
	self.edgeRight:SetPoint("BOTTOMRIGHT")
	self.edgeRight:SetWidth(thickness)

	self.plate = self:CreateTexture(nil, "ARTWORK")
	self.plate:SetTexture("Interface\\Buttons\\WHITE8X8")
	self.plate:SetVertexColor(0, 0, 0, 0.6)
	self.plate:SetPoint("CENTER")
	self.plate:SetSize(258, 50)

	self.title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.title:SetPoint("TOPLEFT", self.plate, "TOPLEFT", 16, -10)
	self.title:SetText("Move chat frame")
	self.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)

	self.hint = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.hint:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
	self.hint:SetText("Drag to move · Corners to resize · Lock to save")
	self.hint:SetTextColor(0.8, 0.8, 0.8, 1)

	self.deleteButton = CreateFrame("Button", nil, self)
	self.deleteButton:SetSize(120, 22)
	self.deleteButton:SetPoint("TOP", self.plate, "BOTTOM", 0, -6)
	self.deleteButton:SetFrameLevel(self:GetFrameLevel() + 5)
	self.deleteButton:Hide()

	self.deleteButton.border = self.deleteButton:CreateTexture(nil, "BACKGROUND")
	self.deleteButton.border:SetTexture("Interface\\Buttons\\WHITE8X8")
	self.deleteButton.border:SetVertexColor(0.8, 0.2, 0.2, 1)
	self.deleteButton.border:SetPoint("TOPLEFT", -1, 1)
	self.deleteButton.border:SetPoint("BOTTOMRIGHT", 1, -1)

	self.deleteButton.innerBg = self.deleteButton:CreateTexture(nil, "BORDER")
	self.deleteButton.innerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	self.deleteButton.innerBg:SetVertexColor(0, 0, 0, 0.9)
	self.deleteButton.innerBg:SetAllPoints()

	self.deleteButton.text = self.deleteButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.deleteButton.text:SetPoint("CENTER")
	self.deleteButton.text:SetText("Delete Window")
	self.deleteButton.text:SetTextColor(0.9, 0.2, 0.2, 1)

	self.deleteButton:SetScript("OnEnter", function(btn)
		btn.innerBg:SetVertexColor(0.15, 0.15, 0.15, 1)
		btn.border:SetVertexColor(1, 0.3, 0.3, 1)
		btn.text:SetTextColor(1, 0.4, 0.4, 1)
	end)
	self.deleteButton:SetScript("OnLeave", function(btn)
		btn.innerBg:SetVertexColor(0, 0, 0, 0.9)
		btn.border:SetVertexColor(0.8, 0.2, 0.2, 1)
		btn.text:SetTextColor(0.9, 0.2, 0.2, 1)
	end)
	self.deleteButton:SetScript("OnClick", function()
		if self.window and self.window.id ~= "Main" then
			UIManager:DeleteWindow(self.window.id)
		end
	end)

	self:Hide()
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		local point, _, _, xOfs, yOfs = self:GetPoint()
		self.profile.positionAnchor = { point = point, xOfs = xOfs, yOfs = yOfs }
	end)

	self:SetResizable(true)
	if self.SetMinResize then self:SetMinResize(100, 80) end
	if self.SetMaxResize then self:SetMaxResize(4000, 3000) end

	local lastDispatchTime = 0
	local THROTTLE_INTERVAL = 0.1

	local function syncMoverSize(force)
		local now = GetTime()
		if not force and (now - lastDispatchTime < THROTTLE_INTERVAL) then
			return
		end

		local newWidth = math_floor(self:GetWidth() + 0.5)
		local newHeight = math_floor(self:GetHeight() - editBoxMargin + 0.5)
		if newWidth < 100 then newWidth = 100 end
		if newHeight < 1 then newHeight = 1 end

		local changed = false
		if self.profile.frameWidth ~= newWidth then
			self.profile.frameWidth = newWidth
			changed = true
		end
		if self.profile.frameHeight ~= newHeight then
			self.profile.frameHeight = newHeight
			changed = true
		end

		if changed then
			lastDispatchTime = now
			Glass:Dispatch("UPDATE_CONFIG", "frameWidth")
			Glass:Dispatch("UPDATE_CONFIG", "frameHeight")
		end
	end

	self:SetScript("OnSizeChanged", function()
		if self.isSizing then
			syncMoverSize(false)
		end
	end)

	-- Add resizing corner grips
	local cornerSize = 16
	local function createCornerGrip(point, cursor)
		local corner = CreateFrame("Frame", nil, self)
		corner:SetSize(cornerSize, cornerSize)
		corner:SetPoint(point)
		corner:EnableMouse(true)
		corner:SetScript("OnMouseDown", function()
			self.isSizing = true
			self:StartSizing(point)
		end)
		corner:SetScript("OnMouseUp", function()
			self.isSizing = false
			self:StopMovingOrSizing()
			syncMoverSize(true)
		end)
	end

	createCornerGrip("BOTTOMRIGHT", "SIZENWSE")
	createCornerGrip("BOTTOMLEFT", "SIZENESW")
	createCornerGrip("TOPLEFT", "SIZENWSE")
	createCornerGrip("TOPRIGHT", "SIZENESW")

	-- Subscriptions to show/hide mover when locked
	self.subscriptions = {
		Glass:Subscribe("LOCK_MOVER", function()
			self:Hide()
		end),
		Glass:Subscribe("UNLOCK_MOVER", function()
			self:Show()
		end),
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			if key == "frameWidth" then
				self:SetWidth(self.profile.frameWidth)
			elseif key == "frameHeight" then
				self:SetHeight(self.profile.frameHeight + editBoxMargin)
			end
		end),
	}
end

function MoverFrameMixin:SetWindowLabel(windowId)
	self._windowId = windowId
	if windowId == "Main" then
		self.title:SetText("Chatto (Main)")
		self.deleteButton:Hide()
	else
		self.title:SetText("Chatto (" .. windowId .. ")")
		self.deleteButton:Show()
	end
end

function MoverFrameMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then
				unsubscribe()
			end
		end
		self.subscriptions = nil
	end
end

local function CreateMoverFrame(name, parent, profile)
	local frame = CreateFrame("Frame", name, parent)
	local object = Mixin(frame, MoverFrameMixin)
	object.profile = profile or Chatto.db.profile.glass
	object:Init()
	return object
end
Glass.Components.CreateMoverFrame = CreateMoverFrame

--------------------------------------------------------------------------------
-- 3. Window constructor
--------------------------------------------------------------------------------

local function CreateWindow(opts)
	opts = opts or {}
	local id = opts.id or "Main"
	local parent = opts.parent or _G.UIParent

	local window = {
		id = id,
		primaryChatFrame = opts.primaryChatFrame,
		frames = {},
		tabs = {},
	}

	-- Set profile pointer
	if id == "Main" then
		window.profile = Chatto.db.profile.glass
	else
		Chatto.db.profile.glass.windows = Chatto.db.profile.glass.windows or {}
		if not Chatto.db.profile.glass.windows[id] then
			Chatto.db.profile.glass.windows[id] = CopyTable(Chatto.db.profile.glass)
			Chatto.db.profile.glass.windows[id].windows = nil -- Strip nested
		end
		window.profile = Chatto.db.profile.glass.windows[id]
	end

	window.moverFrame = CreateMoverFrame(opts.moverName or ("GlassMoverFrame" .. id), parent, window.profile)
	window.moverFrame.window = window
	window.moverFrame:SetWindowLabel(id)

	window.container = Glass.Components.CreateContainer(opts.containerName or ("GlassFrame" .. id), parent, window.profile)
	window.container:SetPoint("TOPLEFT", window.moverFrame)
	window.container.window = window

	window.dock = Glass.Components.CreateChatDock(window.container, opts.dockName or ("GlassChatDock" .. id), window.profile)
	window.dock.window = window

	window.pool = Glass.Components.CreateSlidingMessageFramePool(window.container, window)

	return window
end
Glass.Components.CreateWindow = CreateWindow

--------------------------------------------------------------------------------
-- 4. UIManager logic
--------------------------------------------------------------------------------

function UIManager:OnInitialize()
	self.state = {
		frames = {},
		tabs = {},
		temporaryFrames = {},
		temporaryTabs = {},
	}
	self.windows = {}
end

function UIManager:OnEnable()
	self.tickerFrame = CreateFrame("Frame", "ChattoGlassUpdaterFrame", _G.UIParent)

	self.moverDialog = CreateMoverDialog("ChattoGlassMoverDialog", _G.UIParent)

	self.mainWindow = CreateWindow({
		id = "Main",
		parent = _G.UIParent,
		moverName = "GlassMoverFrame",
		containerName = "GlassFrame",
		dockName = "GlassChatDock",
		primaryChatFrame = _G.ChatFrame1,
	})
	self.windows["Main"] = self.mainWindow

	-- Backwards compatibility aliases
	self.moverFrame = self.mainWindow.moverFrame
	self.container = self.mainWindow.container
	self.dock = self.mainWindow.dock
	self.slidingMessageFramePool = self.mainWindow.pool
	self.state.frames = self.mainWindow.frames
	self.state.tabs = self.mainWindow.tabs

	-- Restore secondary windows
	if Chatto.db.profile.glass.windows then
		local num = 2
		for wId, wProfile in pairs(Chatto.db.profile.glass.windows) do
			if wId ~= "Main" and type(wProfile) == "table" then
				local window = CreateWindow({
					id = wId,
					parent = _G.UIParent,
					moverName = "GlassMoverFrame" .. num,
					containerName = "GlassFrame" .. num,
					dockName = "GlassChatDock" .. num,
					primaryChatFrame = nil,
				})
				if window then
					self.windows[wId] = window
					if wProfile.positionAnchor then
						window.moverFrame:ClearAllPoints()
						window.moverFrame:SetPoint(
							wProfile.positionAnchor.point or "BOTTOMLEFT",
							_G.UIParent,
							wProfile.positionAnchor.point or "BOTTOMLEFT",
							wProfile.positionAnchor.xOfs or 50,
							wProfile.positionAnchor.yOfs or 200
						)
					end
				end
				num = num + 1
			end
		end
	end

	local function IsChatFrameActive(index)
		local chatFrame = _G["ChatFrame" .. index]
		if not chatFrame then return false end
		if index <= 2 then return true end
		if chatFrame.isDocked then return true end
		return false
	end

	local function SetupTabs(reveal)
		local combatLogFrame = _G.ChatFrame2
		if combatLogFrame then
			combatLogFrame:Hide()
			combatLogFrame:SetAlpha(0)
		end

		local activeTabsByWindow = {}

		for i = 1, NUM_CHAT_WINDOWS do
			local chatFrame = _G["ChatFrame" .. i]
			local chatTab = _G["ChatFrame" .. i .. "Tab"]

			if chatFrame then
				local isCombatLog = (chatFrame == _G.ChatFrame2)
				local owner = self:GetOwnerWindowForIndex(i)

				-- Reconcile ownership
				for _, w in pairs(self.windows) do
					if w ~= owner and w.frames[i] then
						local stale = w.frames[i]
						w.frames[i] = nil
						w.tabs[i] = nil
						if w.pool then w.pool:Release(stale) end
					end
				end

				if not owner.frames[i] then
					local smf = owner.pool:Acquire()
					smf.window = owner
					smf:Init(chatFrame)
					owner.frames[i] = smf
				end

				local smf = owner.frames[i]
				smf.window = owner
				smf.profile = owner.profile
				local isActive = IsChatFrameActive(i)

				if isCombatLog and Chatto.db.profile.glass.hideCombatLog then
					isActive = false
				end

				if isActive then
					local tab = Glass.Components.CreateChatTab(smf)
					owner.tabs[i] = tab
					if tab then
						tab.glassDock = owner.dock
						activeTabsByWindow[owner] = activeTabsByWindow[owner] or {}
						table.insert(activeTabsByWindow[owner], tab)
					end

					if not isCombatLog then
						chatFrame:SetAlpha(0)
					end
				else
					if chatTab then chatTab:Hide() end
					owner.tabs[i] = nil
				end
			end
		end

		if Glass.Components.UpdateTabPositions then
			for _, tabs in pairs(activeTabsByWindow) do
				Glass.Components.UpdateTabPositions(tabs)
			end
		end

		if reveal then
			for _, window in pairs(self.windows) do
				if window.dock then
					window.dock:Show()
					if window.dock.FadeOutTabs then window.dock:FadeOutTabs() end
				end
			end

			if Glass.Components.SelectChatTab then
				for _, window in pairs(self.windows) do
					local tabToSelect = window.selectedTab
					if tabToSelect then
						local stillThere = false
						for _, t in pairs(window.tabs) do
							if t == tabToSelect then stillThere = true; break end
						end
						if not stillThere then tabToSelect = nil end
					end
					if not tabToSelect then
						for _, t in pairs(window.tabs) do
							if t then tabToSelect = t; break end
						end
					end
					if tabToSelect then
						Glass.Components.SelectChatTab(tabToSelect)
					end
				end
			end
		end
	end

	self._setupTabs = SetupTabs
	SetupTabs(true)

	C_Timer.After(0.5, function() SetupTabs(true) end)
	C_Timer.After(2, function() SetupTabs(true) end)
	C_Timer.After(1, function() self:RestoreChatMessages() end)

	-- Keep tabs in our dock on Blizzard updates
	local reassertScheduled = false
	local function ReassertTabs()
		if reassertScheduled then return end
		reassertScheduled = true
		C_Timer.After(0, function()
			reassertScheduled = false
			SetupTabs(false)
		end)
	end
	if hooksecurefunc and _G.FCF_DockUpdate then
		hooksecurefunc("FCF_DockUpdate", ReassertTabs)
	end

	-- Custom Editbox
	self.editBox = Glass.Components.CreateEditBox(self.container, self.mainWindow.profile)
	self.editBox.window = self.mainWindow
	self.activeWindow = self.mainWindow

	-- Hides native chat frame buttons
	for _, buttonName in ipairs({
		"ChatFrameChannelButton",
		"ChatFrameToggleVoiceDeafenButton",
		"ChatFrameToggleVoiceMuteButton",
	}) do
		local button = _G[buttonName]
		if button then
			button:Hide()
			if hooksecurefunc then
				hooksecurefunc(button, "Show", function(b) b:Hide() end)
			end
		end
	end

	self:SetupSocialAndMenuButtons()

	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame then
			local bg = _G["ChatFrame" .. i .. "Background"]
			if bg then bg:Hide() end
			local resize = _G["ChatFrame" .. i .. "ResizeButton"]
			if resize then resize:Hide() end

			local bottom = _G["ChatFrame" .. i .. "BottomButton"]
			if bottom then bottom:Hide() end
			local up = _G["ChatFrame" .. i .. "UpButton"]
			if up then up:Hide() end
			local down = _G["ChatFrame" .. i .. "DownButton"]
			if down then down:Hide() end
		end
	end

	if GeneralDockManager then GeneralDockManager:Hide() end
	if ChatFrame1TabHolder then ChatFrame1TabHolder:Hide() end
	if ChatFrame1Background then ChatFrame1Background:Hide() end

	-- Hook temporary whisper windows
	self:RawHook("FCF_OpenTemporaryWindow", function(...)
		local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
		local smf = self.slidingMessageFramePool:Acquire()
		smf:Init(chatFrame)

		self.state.temporaryFrames[chatFrame:GetName()] = smf
		self.state.temporaryTabs[chatFrame:GetName()] = Glass.Components.CreateChatTab(smf)
		return chatFrame
	end, true)

	-- FCF_GetCurrentChatFrame fallback interceptor
	if _G.FCF_GetCurrentChatFrame then
		local origFCF_GetCurrentChatFrame = _G.FCF_GetCurrentChatFrame
		_G.FCF_GetCurrentChatFrame = function()
			local result = origFCF_GetCurrentChatFrame()
			if not result then
				if Glass.Components.selectedTab and Glass.Components.selectedTab.chatFrame then
					result = Glass.Components.selectedTab.chatFrame
				else
					result = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
				end
			end
			return result
		end
	end

	self:StartRenderLoop()
end

function UIManager:OnDisable()
	self:UnhookAll()
	if self.tickerFrame then
		self.tickerFrame:SetScript("OnUpdate", nil)
	end
end

-- Optimised Render Ticker:
-- In CleanerChat, this runs 100 times per second unconditionally.
-- In Chatto, we can optimize this.
-- We check if any animations or ticks are actually needed.
-- In WotLK, we only need to call OnFrame if we have active sliding message frames,
-- or when mouse changes hover state.
function UIManager:StartRenderLoop()
	self.timeElapsed = 0
	self.tickerFrame:SetScript("OnUpdate", function(_, elapsed)
		self.timeElapsed = self.timeElapsed + elapsed
		while self.timeElapsed > 0.01 do
			self.timeElapsed = self.timeElapsed - 0.01

			local anyActive = false
			for _, window in pairs(self.windows) do
				if window.container then
					window.container:OnFrame()
				end
				for _, smf in pairs(window.frames) do
					if smf and smf.OnFrame then
						smf:OnFrame()
						-- If there are queued or active sliding messages, keep ticker awake
						if #smf.state.incomingMessages > 0 or (smf.state.prevEasingHandle) then
							anyActive = true
						end
					end
				end
			end

			for _, smf in pairs(self.state.temporaryFrames) do
				if smf and smf.OnFrame then
					smf:OnFrame()
					if #smf.state.incomingMessages > 0 or (smf.state.prevEasingHandle) then
						anyActive = true
					end
				end
			end
			
			-- If nothing is animating, we could throttle the OnUpdate.
			-- We keep it running but since it only checks MouseIsOver, it's very lightweight.
		end
	end)
end

function UIManager:GetOwnerWindowForIndex(chatFrameIndex)
	for wId, window in pairs(self.windows) do
		if wId ~= "Main" and window.profile and window.profile.chatFrames then
			for _, idx in ipairs(window.profile.chatFrames) do
				if idx == chatFrameIndex then
					return window
				end
			end
		end
	end
	return self.mainWindow
end

function UIManager:SetActiveWindow(window)
	if not window then return end
	self.activeWindow = window
	if self.editBox and self.editBox.AttachToWindow then
		self.editBox:AttachToWindow(window.container, window.profile, window)
	end
	local chatFrame = window.primaryChatFrame or _G.ChatFrame1
	if chatFrame then
		_G.SELECTED_CHAT_FRAME = chatFrame
		_G.SELECTED_DOCK_FRAME = chatFrame
	end
end

function UIManager:SetupSocialAndMenuButtons()
	local social = _G["FriendsMicroButton"]
	if social then
		if Chatto.db.profile.glass.hideSocialButton then social:Hide() else social:Show() end
		if hooksecurefunc then
			hooksecurefunc(social, "Show", function(b)
				if Chatto.db.profile.glass.hideSocialButton then b:Hide() end
			end)
		end
	end

	local menu = _G["ChatFrameMenuButton"]
	if menu then
		if Chatto.db.profile.glass.hideChatMenuButton then menu:Hide() else menu:Show() end
		if hooksecurefunc then
			hooksecurefunc(menu, "Show", function(b)
				if Chatto.db.profile.glass.hideChatMenuButton then b:Hide() end
			end)
		end
	end
end

-- Save chat history
function UIManager:SaveChatMessages()
	if not Chatto.db.profile.glass.restoreChatMessages then
		Chatto.db.global.chatHistory = {}
		Chatto.db.global.chatHistoryTime = 0
		return
	end

	local chatTypeIndexToName = {}
	for t in pairs(ChatTypeInfo) do
		local idx = GetChatTypeIndex(t)
		if idx then chatTypeIndexToName[idx] = t end
	end

	local function WrapWithColor(msg, lineID)
		if not msg then return nil end
		msg = msg:gsub("|T.-|t", "")
		msg = msg:gsub("|A.-|a", "")

		local inf = ChatTypeInfo[chatTypeIndexToName[lineID]]
		local r, g, b = (inf and inf.r) or 1, (inf and inf.g) or 1, (inf and inf.b) or 1
		local hex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
		return hex .. msg:gsub("|r", "|r" .. hex) .. "|r"
	end

	Chatto.db.global.chatHistory = {}
	Chatto.db.global.chatHistoryTime = time()

	for i = 1, NUM_CHAT_WINDOWS do
		if i ~= 2 then
			local chatFrame = _G["ChatFrame" .. i]
			if chatFrame and chatFrame.GetNumMessages and chatFrame.GetMessageInfo then
				local num = chatFrame:GetNumMessages()
				if num and num > 0 then
					local historyKey = "ChatFrame" .. i
					Chatto.db.global.chatHistory[historyKey] = {}
					local first = (num > 50) and (num - 50 + 1) or 1
					for n = first, num do
						local txt, _, lineID = chatFrame:GetMessageInfo(n)
						if txt then
							local colored = WrapWithColor(txt, lineID)
							if colored then
								table.insert(Chatto.db.global.chatHistory[historyKey], colored)
							end
						end
					end
				end
			end
		end
	end
end

-- Restore chat history
function UIManager:RestoreChatMessages()
	if self._messagesRestored or not Chatto.db.profile.glass.restoreChatMessages then return end
	local savedTime = Chatto.db.global.chatHistoryTime or 0
	if time() - savedTime > 10 then return end

	local chatHistory = Chatto.db.global.chatHistory
	if not chatHistory then return end

	self._messagesRestored = true
	self._restoringMessages = true

	for _, window in pairs(self.windows) do
		if window.frames then
			for chatFrameIndex, smf in pairs(window.frames) do
				if chatFrameIndex ~= 2 then
					local historyKey = "ChatFrame" .. chatFrameIndex
					local messages = chatHistory[historyKey]
					if messages and #messages > 0 and smf.chatFrame then
						for _, line in ipairs(messages) do
							if line then
								smf:AddMessage(smf.chatFrame, line)
							end
						end
					end
				end
			end
		end
	end

	self._restoringMessages = false
end

-- Handle logouts
local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
logoutFrame:SetScript("OnEvent", function()
	if UIManager._hasSaved then return end
	UIManager._hasSaved = true
	UIManager:SaveChatMessages()
end)
