local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local Mixin = Mixin
local CreateFrame = CreateFrame
local MouseIsOver = MouseIsOver
local type = type

local ContainerMixin = {}

function ContainerMixin:Init()
	self.state = {
		mouseOver = false,
	}

	self:SetWidth(self.profile.frameWidth)
	self:SetHeight(self.profile.frameHeight)

	-- Clicking container makes it the active window
	self:EnableMouse(true)
	self:SetScript("OnMouseDown", function(frame, button)
		if button == "LeftButton" then
			if Glass.UIManager and Glass.UIManager.SetActiveWindow and frame.window then
				Glass.UIManager:SetActiveWindow(frame.window)
			end
		end
	end)

	self.subscriptions = {
		Glass:Subscribe("UPDATE_CONFIG", function(key)
			if key == "frameWidth" then
				self:SetWidth(self.profile.frameWidth)
			elseif key == "frameHeight" then
				self:SetHeight(self.profile.frameHeight)
			end
		end),
	}
end

function ContainerMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then
				unsubscribe()
			end
		end
		self.subscriptions = nil
	end
end

function ContainerMixin:OnFrame()
	local isOver = MouseIsOver(self)
	if self.state.mouseOver ~= isOver then
		if not self.state.mouseOver then
			Glass:Dispatch("MOUSE_ENTER", self.window)
		else
			Glass:Dispatch("MOUSE_LEAVE", self.window)
		end
		self.state.mouseOver = not self.state.mouseOver
	end
end

Glass.Components.CreateContainer = function(name, parent, profile)
	local frame = CreateFrame("Frame", name, parent)
	local object = Mixin(frame, ContainerMixin)
	object.profile = profile or Chatto.db.profile.glass
	object:Init()
	return object
end
