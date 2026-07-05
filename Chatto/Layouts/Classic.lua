local AddonName, ns = ...
local Chatto = _G[AddonName]

local Classic = Chatto:NewModule("ClassicLayout", "AceHook-3.0")

local _G = _G
local ipairs = ipairs
local select = select
local pairs = pairs
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local function PreventShow(self)
	self:Hide()
end

function Classic:OnInitialize()
	Chatto:RegisterLayout("Classic", self)
end

function Classic:OnEnable()
	if Chatto.db.profile.layoutMode ~= "Classic" then return end
	self:ApplySettings()
end

function Classic:OnDisable()
	self:ResetSettings()
end

function Classic:ApplySettings()
	local cfg = Chatto.db.profile.classic
	
	-- Customize Chat Fonts and Scroll Limits
	local fontPath = Chatto.LSM:Fetch("font", cfg.font)
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame then
			-- Font face and size
			if fontPath and cfg.fontSize then
				frame:SetFont(fontPath, cfg.fontSize, cfg.fontFlags or "")
			end
			
			-- Max lines limit
			if cfg.scrollbackLimit then
				frame:SetMaxLines(cfg.scrollbackLimit)
			end
			
			-- Enable Mouse Wheel Scrolling
			if cfg.mouseWheelScroll then
				frame:EnableMouseWheel(true)
				frame:SetScript("OnMouseWheel", function(self, delta)
					if delta > 0 then
						if IsShiftKeyDown() and cfg.shiftScrollAcceleration then
							self:ScrollToTop()
						else
							self:ScrollUp()
						end
					else
						if IsShiftKeyDown() and cfg.shiftScrollAcceleration then
							self:ScrollToBottom()
						else
							self:ScrollDown()
						end
					end
				end)
			else
				frame:EnableMouseWheel(false)
				frame:SetScript("OnMouseWheel", nil)
			end
			
			-- Hook or override AddMessage to register with our pipeline
			Chatto:HookChatFrame(frame)
		end
	end
	
	-- Manage standard Blizzard buttons
	if cfg.hideButtons then
		if ChatFrameMenuButton then
			ChatFrameMenuButton:Hide()
			self:SecureHook(ChatFrameMenuButton, "Show", PreventShow)
		end
		if FriendsMicroButton then
			FriendsMicroButton:Hide()
			self:SecureHook(FriendsMicroButton, "Show", PreventShow)
		end
		
		for i = 1, NUM_CHAT_WINDOWS do
			local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
			if bf then
				bf:Hide()
				self:SecureHook(bf, "Show", PreventShow)
			end
			
			local up = _G["ChatFrame" .. i .. "UpButton"]
			local down = _G["ChatFrame" .. i .. "DownButton"]
			local bottom = _G["ChatFrame" .. i .. "BottomButton"]
			
			if up then up:Hide() end
			if down then down:Hide() end
			if bottom then bottom:Hide() end
		end
	else
		self:UnhookAll()
		if ChatFrameMenuButton then ChatFrameMenuButton:Show() end
		if FriendsMicroButton then FriendsMicroButton:Show() end
		for i = 1, NUM_CHAT_WINDOWS do
			local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
			if bf then bf:Show() end
		end
	end
	
	-- EditBox Styling & Positioning
	for i = 1, NUM_CHAT_WINDOWS do
		local editBox = _G["ChatFrame" .. i .. "EditBox"]
		local chatFrame = _G["ChatFrame" .. i]
		if editBox and chatFrame then
			-- Reposition EditBox
			editBox:ClearAllPoints()
			if cfg.editBoxPosition == "TOP" then
				editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -2, 4)
				editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 2, 4)
			else
				editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -2, -4)
				editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 2, -4)
			end
			
			-- Border and textures clean
			local prefix = "ChatFrame" .. i .. "EditBox"
			local left = _G[prefix .. "Left"]
			local mid = _G[prefix .. "Mid"]
			local right = _G[prefix .. "Right"]
			
			if cfg.editBoxBorder then
				if left then left:SetAlpha(0) end
				if mid then mid:SetAlpha(0) end
				if right then right:SetAlpha(0) end
			else
				if left then left:SetAlpha(1) end
				if mid then mid:SetAlpha(1) end
				if right then right:SetAlpha(1) end
			end
			
			-- Draw clean dark transparent background
			if cfg.editBoxBackground then
				if not editBox.chattoBg then
					editBox.chattoBg = editBox:CreateTexture(nil, "BACKGROUND")
					editBox.chattoBg:SetTexture(0, 0, 0, 0.5)
					editBox.chattoBg:SetAllPoints()
				end
				editBox.chattoBg:Show()
			else
				if editBox.chattoBg then
					editBox.chattoBg:Hide()
				end
			end
		end
	end
end

function Classic:ResetSettings()
	self:UnhookAll()
	if ChatFrameMenuButton then ChatFrameMenuButton:Show() end
	if FriendsMicroButton then FriendsMicroButton:Show() end
	for i = 1, NUM_CHAT_WINDOWS do
		local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
		if bf then bf:Show() end
		local editBox = _G["ChatFrame" .. i .. "EditBox"]
		if editBox then
			if editBox.chattoBg then editBox.chattoBg:Hide() end
			local prefix = "ChatFrame" .. i .. "EditBox"
			local left = _G[prefix .. "Left"]
			local mid = _G[prefix .. "Mid"]
			local right = _G[prefix .. "Right"]
			if left then left:SetAlpha(1) end
			if mid then mid:SetAlpha(1) end
			if right then right:SetAlpha(1) end
		end
	end
end
