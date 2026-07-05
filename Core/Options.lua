local AddonName, ns = ...
local Chatto = _G[AddonName]

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function GetLSMFonts()
	local fonts = Chatto.LSM:List("font")
	local fontTable = {}
	for _, fontName in ipairs(fonts) do
		fontTable[fontName] = fontName
	end
	return fontTable
end

local function GetLSMSounds()
	local sounds = Chatto.LSM:List("sound")
	local soundTable = {}
	for _, soundName in ipairs(sounds) do
		soundTable[soundName] = soundName
	end
	return soundTable
end

local fontFlags = {
	[""] = "None",
	["OUTLINE"] = "Outline",
	["THICKOUTLINE"] = "Thick Outline",
	["MONOCHROME"] = "Monochrome",
}

local bracketStyles = {
	["none"] = "None (Name)",
	["square"] = "Square [Name]",
	["round"] = "Round (Name)",
	["angle"] = "Angle <Name>",
}

function Chatto:SetupOptions()
	local options = {
		type = "group",
		name = "Chatto Options",
		args = {
			general = {
				type = "group",
				name = "General",
				order = 10,
				args = {
					layoutMode = {
						type = "select",
						name = "Layout Mode",
						desc = "Choose Chatto's layout engine. Requires a UI Reload when changed.",
						order = 10,
						values = {
							["Classic"] = "Classic Enhanced (Skins Blizzard chat frames)",
							["Glass"] = "Glass Immersive (Full custom animated chat replacement)",
						},
						get = function() return Chatto.db.profile.layoutMode end,
						set = function(_, value)
							Chatto.db.profile.layoutMode = value
							StaticPopup_Show("CHATTO_RELOAD_UI")
						end,
					},
				},
			},
			filters = {
				type = "group",
				name = "Filters",
				desc = "Consolidate repetitive log messages into concise inline formats.",
				order = 20,
				get = function(info) return Chatto.db.profile.filters[info[#info]] end,
				set = function(info, value) Chatto.db.profile.filters[info[#info]] = value end,
				args = {
					loot = {
						type = "toggle",
						name = "Loot Consolidation",
						desc = "Simplify item looted, roll events, and mailbox retrieves.",
						order = 10,
					},
					money = {
						type = "toggle",
						name = "Money Formatter",
						desc = "Convert silver/gold text awards into graphical coin icons.",
						order = 20,
					},
					experience = {
						type = "toggle",
						name = "Experience Gains",
						desc = "Compress experience messages and display percentage to level.",
						order = 30,
					},
					reputation = {
						type = "toggle",
						name = "Reputation Standing",
						desc = "Shorten faction reputation alerts.",
						order = 40,
					},
					quests = {
						type = "toggle",
						name = "Quest Aggregation",
						desc = "Collapse XP, money, and items on quest turn-ins into a single line.",
						order = 50,
					},
					spells = {
						type = "toggle",
						name = "Spell Specialization Gains",
						desc = "Filters spell learning alerts spammed during spec swaps.",
						order = 60,
					},
					status = {
						type = "toggle",
						name = "Player Status Messages",
						desc = "Simplify AFK, DND, and rested standing alerts.",
						order = 70,
					},
					guildstatus = {
						type = "toggle",
						name = "Guild Login Notifications",
						desc = "Convert guild member logins/logouts to single clean lines.",
						order = 80,
					},
					blacklist = {
						type = "toggle",
						name = "Custom Blacklist",
						desc = "Filter out lines containing blacklisted terms.",
						order = 90,
					},
				},
			},
			utilities = {
				type = "group",
				name = "QoL Utilities",
				desc = "Essential tools to improve daily chat interactions.",
				order = 30,
				get = function(info) return Chatto.db.profile.utilities[info[#info]] end,
				set = function(info, value) Chatto.db.profile.utilities[info[#info]] = value end,
				args = {
					playernames = {
						type = "toggle",
						name = "Player Name Enhancements",
						desc = "Applies class coloring, brackets, level, and guild ranks to names in chat.",
						order = 5,
					},
					altnames = {
						type = "toggle",
						name = "Alt Character Mapping",
						desc = "Displays alt main names next to player alts based on guild notes.",
						order = 10,
					},
					altclickinvite = {
						type = "toggle",
						name = "Alt-Click Invite",
						desc = "Alt-click on names in chat to send a group invite.",
						order = 20,
					},
					wordhighlight = {
						type = "toggle",
						name = "Keyword Highlighting",
						desc = "Colorizes matching words and triggers sound alarms.",
						order = 30,
					},
					stickychannels = {
						type = "toggle",
						name = "Sticky Channels",
						desc = "Keep active channel (e.g. Whispers) when pressing Enter.",
						order = 40,
					},
					telltarget = {
						type = "toggle",
						name = "TellTarget Shortcut (/tt)",
						desc = "Enables slash command /tt to whisper your current target.",
						order = 50,
					},
					timestamps = {
						type = "toggle",
						name = "Custom Timestamps",
						desc = "Prepends custom timestamps to chat lines.",
						order = 60,
					},
					urlcopy = {
						type = "toggle",
						name = "Clickable URL Copying",
						desc = "Detects web addresses and shows a Ctrl+C dialog on click.",
						order = 70,
					},
				},
			},
			classic = {
				type = "group",
				name = "Classic Layout Settings",
				order = 40,
				hidden = function() return Chatto.db.profile.layoutMode ~= "Classic" end,
				get = function(info) return Chatto.db.profile.classic[info[#info]] end,
				set = function(info, value)
					Chatto.db.profile.classic[info[#info]] = value
					local layout = Chatto:GetLayout("Classic")
					if layout and layout.ApplySettings then layout:ApplySettings() end
				end,
				args = {
					font = {
						type = "select",
						name = "Chat Font",
						desc = "Font face used by default chat frames.",
						order = 10,
						values = GetLSMFonts,
					},
					fontSize = {
						type = "range",
						name = "Font Size",
						min = 8, max = 24, step = 1,
						order = 20,
					},
					fontFlags = {
						type = "select",
						name = "Font Style",
						order = 30,
						values = fontFlags,
					},
					scrollbackLimit = {
						type = "range",
						name = "Scrollback History Limit",
						desc = "How many lines of chat to remember (Blizzard default is 128).",
						min = 100, max = 2000, step = 50,
						order = 40,
					},
					hideButtons = {
						type = "toggle",
						name = "Hide Sidebar Buttons",
						desc = "Hides the clunky Blizzard scroll, bottom, friends, and menu buttons.",
						order = 50,
					},
					editBoxPosition = {
						type = "select",
						name = "EditBox Position",
						order = 60,
						values = { ["TOP"] = "Top", ["BOTTOM"] = "Bottom" },
					},
					editBoxBorder = {
						type = "toggle",
						name = "Clean EditBox Border",
						desc = "Hides the default clunky textures around input box.",
						order = 70,
					},
					editBoxBackground = {
						type = "toggle",
						name = "Clean EditBox Background",
						desc = "Draws a solid dark transparent box behind text input.",
						order = 80,
					},
					mouseWheelScroll = {
						type = "toggle",
						name = "Enable Mousewheel Scroll",
						desc = "Allows scrolling the chat frame with the mouse wheel.",
						order = 90,
					},
					shiftScrollAcceleration = {
						type = "toggle",
						name = "Shift-Scroll to End",
						desc = "Shift-scrolling snaps immediately to the bottom/top.",
						order = 100,
					},
				},
			},
			glass = {
				type = "group",
				name = "Glass Layout Settings",
				order = 50,
				hidden = function() return Chatto.db.profile.layoutMode ~= "Glass" end,
				get = function(info) return Chatto.db.profile.glass[info[#info]] end,
				set = function(info, value)
					Chatto.db.profile.glass[info[#info]] = value
					-- Fire glass layout config changes
					if Chatto.GlassEngine and Chatto.GlassEngine.OnConfigChanged then
						Chatto.GlassEngine:OnConfigChanged(info[#info])
					end
				end,
				args = {
					dimensions = {
						type = "header",
						name = "Window Dimensions",
						order = 10,
					},
					frameWidth = {
						type = "range",
						name = "Width",
						min = 200, max = 1000, step = 10,
						order = 11,
					},
					frameHeight = {
						type = "range",
						name = "Height",
						min = 100, max = 800, step = 10,
						order = 12,
					},
					hideCombatLog = {
						type = "toggle",
						name = "Hide Combat Log Tab",
						desc = "Hides the native Combat Log from the Glass tab dock.",
						order = 13,
					},
					fonts = {
						type = "header",
						name = "Typography",
						order = 20,
					},
					messageFont = {
						type = "select",
						name = "Message Font",
						values = GetLSMFonts,
						order = 21,
					},
					messageFontSize = {
						type = "range",
						name = "Message Font Size",
						min = 8, max = 24, step = 1,
						order = 22,
					},
					messageFontFlags = {
						type = "select",
						name = "Message Font Style",
						values = fontFlags,
						order = 23,
					},
					messageLeading = {
						type = "range",
						name = "Line Spacing (Leading)",
						min = 0, max = 10, step = 1,
						order = 24,
					},
					messageLinePadding = {
						type = "range",
						name = "Vertical Line Padding",
						min = 0.0, max = 1.0, step = 0.05,
						order = 25,
					},
					messageLeftPadding = {
						type = "range",
						name = "Left Alignment Indent",
						min = 0, max = 20, step = 1,
						order = 26,
					},
					animations = {
						type = "header",
						name = "Animations & Fading",
						order = 30,
					},
					messageAnimations = {
						type = "toggle",
						name = "Enable Animations",
						desc = "Enable smooth slide-ins and fades. When disabled, chat remains static.",
						order = 31,
					},
					messagesAlwaysVisible = {
						type = "toggle",
						name = "Always Keep Visible",
						desc = "Chat text never fades out automatically.",
						order = 32,
					},
					chatHoldTime = {
						type = "range",
						name = "Text Hold Duration (seconds)",
						min = 3, max = 60, step = 1,
						order = 33,
					},
					chatFadeOutDuration = {
						type = "range",
						name = "Fade Out Animation Duration (seconds)",
						min = 0.1, max = 3.0, step = 0.05,
						order = 34,
					},
					chatSlideInDuration = {
						type = "range",
						name = "Slide In Animation Duration (seconds)",
						min = 0.0, max = 2.0, step = 0.05,
						order = 35,
					},
					background = {
						type = "header",
						name = "Background Styling",
						order = 40,
					},
					chatBackgroundColor = {
						type = "color",
						name = "Background Color",
						get = function()
							local c = Chatto.db.profile.glass.chatBackgroundColor
							return c.r, c.g, c.b
						end,
						set = function(_, r, g, b)
							Chatto.db.profile.glass.chatBackgroundColor = { r = r, g = g, b = b }
							if Chatto.GlassEngine and Chatto.GlassEngine.OnConfigChanged then
								Chatto.GlassEngine:OnConfigChanged("chatBackgroundColor")
							end
						end,
						order = 41,
					},
					chatBackgroundOpacity = {
						type = "range",
						name = "Background Opacity",
						min = 0.0, max = 1.0, step = 0.05,
						order = 42,
					},
				},
			},
		},
	}

	-- Register options table with Ace3
	AceConfig:RegisterOptionsTable("Chatto", options)
	self.optionsFrame = AceConfigDialog:AddToBlizOptions("Chatto", "Chatto")
end

-- Layout registration callback helper
local activeLayouts = {}
function Chatto:GetLayout(name)
	return activeLayouts[name]
end
function Chatto:RegisterLayout(name, modulePrototype)
	activeLayouts[name] = modulePrototype
end

-- Custom static popup for UI reloading
StaticPopupDialogs["CHATTO_RELOAD_UI"] = {
	text = "|cffDFBA69Chatto|r: Layout configuration has changed. A UI reload is required to apply the changes.",
	button1 = "Reload UI",
	button2 = "Later",
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}
