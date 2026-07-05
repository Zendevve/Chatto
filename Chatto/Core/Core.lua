local AddonName, ns = ...
Chatto = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0")
_G[AddonName] = Chatto
Chatto.ns = ns

-- Shared media
Chatto.LSM = LibStub("LibSharedMedia-3.0")

-- Module registration lists
local filters = {}
local utilities = {}
local layouts = {}

-- Message Pipeline Filter Registration
function Chatto:RegisterFilter(name, filterFunc, priority)
	priority = priority or 50
	table.insert(filters, { name = name, func = filterFunc, priority = priority })
	table.sort(filters, function(a, b) return a.priority < b.priority end)
end

-- Utility Registration
function Chatto:RegisterUtility(name, modulePrototype)
	utilities[name] = modulePrototype
end

-- Layout Registration
function Chatto:RegisterLayout(name, modulePrototype)
	layouts[name] = modulePrototype
end

-- Unified Message Pipeline: run message through all registered filters
function Chatto:FilterMessage(chatFrame, text, r, g, b, chatID, ...)
	if not text or text == "" then
		return text, r, g, b
	end

	for _, filter in ipairs(filters) do
		-- Only run if the filter is enabled in database
		if self.db.profile.filters[filter.name:lower()] ~= false then
			local success, resultText, newR, newG, newB = pcall(filter.func, self, chatFrame, text, r, g, b, chatID, ...)
			if success then
				if resultText == nil then
					return nil -- Blocked/suppressed
				end
				text = resultText
				r = newR or r
				g = newG or g
				b = newB or b
			else
				-- Silent fail to keep chat functional under error
			end
		end
	end
	return text, r, g, b
end

-- Default Settings
local defaults = {
	profile = {
		layoutMode = "Classic", -- "Classic" or "Glass"
		
		-- Filters
		filters = {
			loot = true,
			money = true,
			experience = true,
			reputation = true,
			quests = true,
			spells = true,
			status = true,
			guildstatus = true,
			blacklist = true,
		},
		
		-- Utilities
		utilities = {
			altnames = true,
			altclickinvite = true,
			wordhighlight = true,
			stickychannels = true,
			telltarget = true,
			timestamps = false,
			urlcopy = true,
			playernames = true,
		},
		
		-- Classic Layout Options
		classic = {
			font = "Friz Quadrata TT",
			fontSize = 12,
			fontFlags = "OUTLINE",
			scrollbackLimit = 1000,
			hideButtons = true,
			editBoxPosition = "BOTTOM",
			editBoxBorder = true,
			editBoxBackground = true,
			mouseWheelScroll = true,
			shiftScrollAcceleration = true,
			frameBorders = false,
		},

		-- Glass Layout Options (Style)
		glass = {
			frameWidth = 520,
			frameHeight = 340,
			hideCombatLog = true,
			positionAnchor = {
				point = "BOTTOMLEFT",
				xOfs = 20,
				yOfs = 230,
			},
			editBoxFont = "Friz Quadrata TT",
			editBoxFontSize = 12,
			editBoxFontFlags = "OUTLINE",
			editBoxBackgroundOpacity = 0.6,
			editBoxBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 },
			editBoxHorizontalPadding = 1,
			editBoxAnchor = "BELOW", -- "ABOVE" or "BELOW"
			editBoxYOffset = -5,
			showOnEditFocus = true,
			messageFont = "Friz Quadrata TT",
			messageFontSize = 12,
			messageFontFlags = "OUTLINE",
			messageAnimations = true,
			messagesAlwaysVisible = false,
			chatBackgroundOpacity = 0.15,
			chatBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 },
			messageLeading = 3,
			messageLinePadding = 0.25,
			messageLeftPadding = 3,
			messageHistoryLimit = 128,
			restoreChatMessages = true,
			chatHoldTime = 14,
			chatFadeInDuration = 0.6,
			chatFadeOutDuration = 0.6,
			chatSlideInDuration = 0.35,
			
			-- Dock & Tabs
			dockFont = "Friz Quadrata TT",
			dockFontSize = 12,
			dockFontFlags = "OUTLINE",
			dockAnimations = true,
			tabsAlwaysVisible = false,
			dockBackgroundOpacity = 0,
			dockBackgroundColor = { r = 0, g = 0, b = 0 },
			dockHoldTime = 10,
			dockFadeOutDuration = 0.6,
			dockFadeInDuration = 0.3,
			tabsOnHover = true,
			tabStyle = "minimal", -- "minimal" or "outline"
			tabCornerStyle = "rounded", -- "square" or "rounded"
			tabActiveColor = { r = 1.0, g = 191 / 255, b = 0 },
			tabInactiveColor = { r = 1.0, g = 191 / 255, b = 0 },
			tabBackgroundOpacity = 1.0,
			tabSpacing = 5,
			tabBorderThickness = 1,
			tabPadding = 5,
			flashTabOnMessage = true,
			
			-- Scroll Indicator
			scrollIndicatorColor = { r = 223 / 255, g = 186 / 255, b = 105 / 255 },
			scrollIndicatorOpacity = 1,
			scrollIndicatorBgColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 },
			scrollIndicatorBgOpacity = 0.65,
			hideScrollIndicator = false,
			
			-- Native Buttons
			hideChatMenuButton = true,
			hideSocialButton = true,
			windows = {},
		},
		
		-- Shared Utilities Options
		altNames = {
			guildNotes = true,
			customAlts = {},
		},
		wordHighlight = {
			words = {},
			sound = "Raid Warning",
			color = { r = 1, g = 0.5, b = 0 },
		},
		stickyChannels = {
			SAY = true,
			PARTY = true,
			RAID = true,
			GUILD = true,
			OFFICER = true,
			WHISPER = true,
			CHANNEL = true,
		},
		timestamps = {
			format = "%H:%M:%S",
			color = { r = 0.7, g = 0.7, b = 0.7 },
		},
		playerNames = {
			classColor = true,
			showLevel = false,
			showGuildRank = false,
			bracket = "square", -- "none", "square", "round", "angle"
		},
		blacklist = {
			phrases = {},
		},
	},
	global = {
		chatHistory = {},
		chatHistoryTime = 0,
	}
}

-- Initialize Addon
function Chatto:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ChattoDB", defaults, "Default")
	
	-- Register options
	if self.SetupOptions then
		self:SetupOptions()
	end
	
	-- Set up slash commands
	self:RegisterChatCommand("chatto", "OpenConfig")
	self:RegisterChatCommand("ct", "OpenConfig")
	
	-- Initialize filters
	for _, filter in ipairs(filters) do
		if filter.Init then
			filter:Init()
		end
	end
	
	-- Initialize layouts
	for name, layout in pairs(layouts) do
		if layout.OnInitialize then
			layout:OnInitialize()
		end
	end
	
	-- Initialize QoL utilities
	for name, util in pairs(utilities) do
		if util.OnInitialize then
			util:OnInitialize()
		end
	end
end

function Chatto:OnEnable()
	-- Enable active layout
	local activeLayout = self.db.profile.layoutMode
	local layout = layouts[activeLayout]
	if layout and layout.OnEnable then
		layout:OnEnable()
	end
	
	-- Enable active utilities
	for name, util in pairs(utilities) do
		if self.db.profile.utilities[name:lower()] ~= false then
			if util.OnEnable then
				util:OnEnable()
			end
			util._isEnabled = true
		end
	end
	
	print("|cffDFBA69Chatto|r loaded! Type /ct for settings.")
end

function Chatto:OnDisable()
	-- Disable layouts
	for _, layout in pairs(layouts) do
		if layout.OnDisable then
			layout:OnDisable()
		end
	end
	
	-- Disable utilities
	for name, util in pairs(utilities) do
		if util._isEnabled and util.OnDisable then
			util:OnDisable()
			util._isEnabled = false
		end
	end
end

function Chatto:OpenConfig()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		-- Call twice to workaround Blizzard UI expansion panels bug
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	end
end
