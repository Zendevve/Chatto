local AddonName, ns = ...
local Chatto = _G[AddonName]

-- Define Glass sub-namespace
local Glass = {}
Chatto.GlassEngine = Glass

Glass.Components = {}
Glass.Version = "1.0.0"

-- Grab libs
Glass.Libs = {
	LSM = Chatto.LSM,
	LibEasing = LibStub("LibEasing-1.0"),
	AceHook = LibStub("AceHook-3.0"),
}

-- Registry of windows and event listeners
Glass.windows = {}
Glass.listeners = {}

-- Pub-sub events system for Glass elements
function Glass:Subscribe(event, listener)
	if not self.listeners[event] then
		self.listeners[event] = {}
	end
	table.insert(self.listeners[event], listener)
	return function()
		local list = self.listeners[event]
		if not list then return end
		for i = #list, 1, -1 do
			if list[i] == listener then
				table.remove(list, i)
				break
			end
		end
	end
end

function Glass:Dispatch(event, payload)
	local list = self.listeners[event]
	if not list then return end
	for _, listener in ipairs(list) do
		listener(payload)
	end
end

function Glass:OnInitialize()
	-- Handled by UIManager
	if self.UIManager and self.UIManager.OnInitialize then
		self.UIManager:OnInitialize()
	end
end

function Glass:OnEnable()
	if Chatto.db.profile.layoutMode ~= "Glass" then return end
	if self.UIManager and self.UIManager.OnEnable then
		self.UIManager:OnEnable()
	end
end

function Glass:OnDisable()
	if self.UIManager and self.UIManager.OnDisable then
		self.UIManager:OnDisable()
	end
end

function Glass:OnConfigChanged(key)
	self:Dispatch("UPDATE_CONFIG", key)
end

Chatto:RegisterLayout("Glass", Glass)
