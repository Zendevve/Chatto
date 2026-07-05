local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local ChatDockMixin = {}

local CreateFrame = CreateFrame
local Mixin = Mixin
local ipairs = ipairs
local type = type
local getmetatable = getmetatable
local C_Timer = C_Timer

local Frame_Hide = getmetatable(CreateFrame("Frame")).__index.Hide

function ChatDockMixin:Init(parent)
	self.state = {
		mouseOver = false,
	}

	self:SetWidth(self.profile.frameWidth)
	self:SetHeight(28) -- Dock height constant
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", parent, "TOPLEFT")
	self:SetFrameStrata("MEDIUM")
	self:SetFrameLevel(10)
	self:SetFadeInDuration(0.6)
	self:SetFadeOutDuration(0.6)

	-- Apply custom background
	self:SetGradientBackground(
		50,
		250,
		self.profile.dockBackgroundColor or { r = 0, g = 0, b = 0 },
		self.profile.dockBackgroundOpacity or 0.4
	)

	self:Show()
	self:SetAlpha(1)
	if self.profile.tabsOnHover then
		self:FadeOutTabs()
	end

	self.subscriptions = {
		Glass:Subscribe("MOUSE_ENTER", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = true
			if self.profile.tabsOnHover then
				self:ShowTabs()
			end
		end),
		Glass:Subscribe("MOUSE_LEAVE", function(window)
			if window and window ~= self.window then return end
			self.state.mouseOver = false
			if self.profile.tabsOnHover then
				self:FadeOutTabs()
			end
		end),
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			local profile = self.profile or Chatto.db.profile.glass
			if key == "frameWidth" then
				self:SetWidth(profile.frameWidth)
			end
			if key == "frameWidth" or key == "dockBackgroundOpacity" or key == "dockBackgroundColor" then
				self:SetGradientBackground(
					50,
					250,
					profile.dockBackgroundColor or { r = 0, g = 0, b = 0 },
					profile.dockBackgroundOpacity or 0.4
				)
			end
			if key == "tabsOnHover" then
				if profile.tabsOnHover then
					self:FadeOutTabs()
				else
					self:ShowTabs()
				end
			end
			if key == "tabsAlwaysVisible" then
				if profile.tabsAlwaysVisible then
					self:ShowTabs()
				elseif profile.tabsOnHover then
					self:FadeOutTabs()
				end
			end
		end),
	}
end

function ChatDockMixin:ShowTabs()
	if self.fadeOutTimer then
		self.fadeOutTimer:Cancel()
		self.fadeOutTimer = nil
	end
	if self.fadeHandle then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end
	self:Show()

	local duration = (self.profile.dockAnimations ~= false) and (self.profile.dockFadeInDuration or 0) or 0
	if duration > 0 and Glass.Libs.LibEasing then
		self.fadeHandle = Glass.Libs.LibEasing:Ease(
			function(a) self:SetAlpha(a) end,
			self:GetAlpha(),
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

function ChatDockMixin:FadeOutTabs()
	if self.profile.tabsAlwaysVisible then
		self:ShowTabs()
		return
	end

	if self.fadeOutTimer then
		self.fadeOutTimer:Cancel()
	end

	self.fadeOutTimer = C_Timer.NewTimer(self.profile.dockHoldTime or 10, function()
		self.fadeOutTimer = nil
		if self.state.mouseOver then return end

		local duration = (self.profile.dockAnimations ~= false) and (self.profile.dockFadeOutDuration or 0.6) or 0
		if self.fadeHandle then
			Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
			self.fadeHandle = nil
		end

		if duration > 0 and self:IsVisible() and Glass.Libs.LibEasing then
			self.fadeHandle = Glass.Libs.LibEasing:Ease(
				function(a) self:SetAlpha(a) end,
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
			Frame_Hide(self)
			self:SetAlpha(1)
		end
	end)
end

function ChatDockMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then unsubscribe() end
		end
		self.subscriptions = nil
	end
	if self.fadeOutTimer then
		self.fadeOutTimer:Cancel()
		self.fadeOutTimer = nil
	end
	if self.fadeHandle then
		Glass.Libs.LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end
end

Glass.Components.CreateChatDock = function(parent, name, profile)
	local FadingFrameMixin = Glass.Components.FadingFrameMixin
	local GradientBackgroundMixin = Glass.Components.GradientBackgroundMixin

	local frame = CreateFrame("Frame", name or "GlassChatDock", parent)
	local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ChatDockMixin)
	Glass.Libs.AceHook:Embed(object)
	object.profile = profile or Chatto.db.profile.glass
	FadingFrameMixin.Init(object)
	GradientBackgroundMixin.Init(object)
	ChatDockMixin.Init(object, parent)

	return object
end
