local AddonName, ns = ...
local Chatto = _G[AddonName]

local Colors = {}
Chatto.Colors = Colors

local string_format = string.format
local string_gsub = string.gsub
local math_floor = math.floor
local pairs = pairs
local unpack = unpack
local select = select

local ColorTemplate = {}

ColorTemplate.GetRGB = function(self)
	return self[1], self[2], self[3]
end

ColorTemplate.GetRGBAsBytes = function(self)
	return self[1] * 255, self[2] * 255, self[3] * 255
end

ColorTemplate.GenerateHexColor = function(self)
	return string_format(
		"ff%02x%02x%02x",
		math_floor(self[1] * 255),
		math_floor(self[2] * 255),
		math_floor(self[3] * 255)
	)
end

ColorTemplate.GenerateHexColorMarkup = function(self)
	return "|c" .. self:GenerateHexColor()
end

local function CreateColor(...)
	local tbl
	if select("#", ...) == 1 then
		local old = ...
		if old.r then
			tbl = { old.r, old.g, old.b }
		else
			tbl = { unpack(old) }
		end
	else
		tbl = { ... }
	end
	for name, method in pairs(ColorTemplate) do
		tbl[name] = method
	end
	if #tbl == 3 then
		tbl.colorCode = tbl:GenerateHexColorMarkup()
		tbl.colorCodeClean = tbl:GenerateHexColor()
	end
	return tbl
end

Colors.CreateColor = CreateColor

-- Basic colors
Colors.normal = CreateColor(229 / 255, 178 / 255, 38 / 255)
Colors.highlight = CreateColor(250 / 255, 250 / 255, 250 / 255)
Colors.title = CreateColor(255 / 255, 234 / 255, 137 / 255)
Colors.white = CreateColor(220 / 255, 220 / 255, 220 / 255)
Colors.offwhite = CreateColor(196 / 255, 196 / 255, 196 / 255)
Colors.green = CreateColor(25 / 255, 178 / 255, 25 / 255)
Colors.red = CreateColor(204 / 255, 25 / 255, 25 / 255)
Colors.palered = CreateColor(204 / 255, 68 / 255, 68 / 255)
Colors.pink = CreateColor(255 / 255, 128 / 255, 255 / 255)
Colors.gray = CreateColor(128 / 255, 128 / 255, 128 / 255)
Colors.darkorange = CreateColor(225 / 255, 96 / 255, 0 / 255) -- Legendary style
Colors.orange = CreateColor(255 / 255, 106 / 255, 26 / 255)
Colors.yellow = CreateColor(255 / 255, 178 / 255, 38 / 255)

-- Item Quality Colors
Colors.quality = {
	[0] = CreateColor(157 / 255, 157 / 255, 157 / 255), -- Poor
	[1] = CreateColor(240 / 255, 240 / 255, 240 / 255), -- Common
	[2] = CreateColor(30 / 255, 198 / 255, 0 / 255),    -- Uncommon
	[3] = CreateColor(0 / 255, 112 / 255, 221 / 255),   -- Rare
	[4] = CreateColor(163 / 255, 53 / 255, 238 / 255),  -- Epic
	[5] = CreateColor(225 / 255, 96 / 255, 0 / 255),    -- Legendary
	[6] = CreateColor(229 / 255, 204 / 255, 127 / 255),  -- Artifact
	[7] = CreateColor(79 / 255, 196 / 255, 225 / 255),   -- Heirloom
}

-- Class Colors
Colors.class = {
	DEATHKNIGHT = CreateColor(176 / 255, 31 / 255, 79 / 255),
	DRUID = CreateColor(245 / 255, 145 / 255, 55 / 255),
	HUNTER = CreateColor(191 / 255, 232 / 255, 115 / 255),
	MAGE = CreateColor(105 / 255, 204 / 255, 240 / 255),
	PALADIN = CreateColor(245 / 255, 185 / 255, 226 / 255),
	PRIEST = CreateColor(176 / 255, 200 / 255, 225 / 255),
	ROGUE = CreateColor(255 / 255, 225 / 255, 95 / 255),
	SHAMAN = CreateColor(32 / 255, 122 / 255, 222 / 255),
	WARLOCK = CreateColor(128 / 255, 110 / 255, 181 / 255),
	WARRIOR = CreateColor(229 / 255, 156 / 255, 110 / 255),
	UNKNOWN = CreateColor(195 / 255, 202 / 255, 217 / 255),
}

-- Formatting tags parsing
local FormatTags = {
	{ "%*title%*", Colors.title.colorCode },
	{ "%*white%*", Colors.highlight.colorCode },
	{ "%*offwhite%*", Colors.offwhite.colorCode },
	{ "%*palered%*", Colors.palered.colorCode },
	{ "%*pink%*", Colors.pink.colorCode },
	{ "%*red%*", Colors.red.colorCode },
	{ "%*darkorange%*", Colors.darkorange.colorCode },
	{ "%*orange%*", Colors.orange.colorCode },
	{ "%*yellow%*", Colors.yellow.colorCode },
	{ "%*green%*", Colors.green.colorCode },
	{ "%*gray%*", Colors.gray.colorCode },
	{ "%*%*", "|r" }, -- Reset tag
}

function Chatto:FormatMessage(msg)
	if not msg then return msg end
	for _, entry in ipairs(FormatTags) do
		msg = string_gsub(msg, entry[1], entry[2])
	end
	return msg
end

-- Custom output templates
Chatto.out = {
	achievement = "%s: %s",
	afk_added = "*orange*+ AFK**",
	afk_added_message = "*orange*+ AFK: ***white*%s**",
	afk_cleared = "*green*- AFK**",
	dnd_added = "*darkorange*+ DND**",
	dnd_added_message = "*darkorange*+ DND: ***white*%s**",
	dnd_cleared = "*green*- DND**",
	guild_online = "*green*+ **%s *green*has come online**",
	guild_offline = "*gray*- **%s *gray*has gone offline**",
	
	item_single = "*green*+** %s",
	item_multiple = "*green*+** %s *offwhite*(%d)**",
	item_single_other = "%s*gray*:** %s",
	item_multiple_other = "%s*gray*:** %s *offwhite*(%d)**",
	craft_single_other = "%s *gray*created:** %s",
	craft_multiple_other = "%s *gray*created:** %s *offwhite*(%d)**",
	item_deficit = "*red*- %s**",
	item_deficit_multiple = "*red*- %s** *offwhite*(%d)**",
	
	money = "*green*+** %s",
	money_deficit = "*gray*-** %s",
	quest_accepted = "*green*+** *white*%s:** *yellow*%s**",
	quest_complete = "*green*+** *white*%s:** *green*%s**",
	objective_status = "*green*+** *white*%s:** *yellow*%s**",
	rested_added = "*green*+** *gray*Rested**",
	rested_cleared = "*orange*- Rested**",
	
	standing = "*green*+** *white*%d** *white*%s:** %s",
	standing_generic = "*green*+** *gray*%s:** %s",
	standing_deficit = "*red*-** *white*%d** *white*%s:** %s",
	standing_deficit_generic = "*red*-** *palered*%s:** %s",
	
	xp_levelup = "%s",
	xp_named = "*green*+** *white*%d** *white*%s:** *yellow*%s**",
	xp_unnamed = "*green*+** *white*%d** *white*%s**",
	quest_rewards_combined = "*green*+** %s",
	
	roll_won_self = "*green*+** *green*Won** %s",
	roll_won_other = "%s *green*Won** %s",
	roll_need_self = "*green*+** *yellow*Need** %s",
	roll_need_other = "*yellow*Need** %s %s",
	roll_greed_self = "*green*+** *green*Greed** %s",
	roll_greed_other = "*green*Greed** %s %s",
	roll_de_self = "*green*+** *darkorange*Disenchant** %s",
	roll_de_other = "*darkorange*Disenchant** %s %s",
	roll_pass_self = "*green*+** *gray*Pass** %s",
	roll_pass_other = "*gray*Pass** %s %s",
	roll_result_need = "*yellow*Need** %s *white*[%d]** %s",
	roll_result_greed = "*green*Greed** %s *white*[%d]** %s",
	roll_result_de = "*darkorange*Disenchant** %s *white*[%d]** %s",
	roll_all_passed = "*gray*All Passed** %s",
	
	levelup_ding = "*yellow*Level %d**",
	levelup_hp = "*green*+** *white*%d** *green*HP**",
	levelup_stat = "*green*+** *white*%d** *green*%s**",
	
	died = "*red*-** *palered*Died**",
	durability_loss = "*red*-** *palered*%d%% Durability**",
	appearance_added = "*green*+** *pink*Appearance:** %s",
	honor = "*green*+** *white*%d** *white*%s**",
	honor_kill = "*green*+** *white*%d** *white*%s:** *yellow*%s**",
	boss_emote = "*darkorange*[Boss]** %s",
	boss_whisper = "*red*[Boss Whisper]** %s",
}

-- Populate out templates with formatted colors
for k, v in pairs(Chatto.out) do
	Chatto.out[k] = Chatto:FormatMessage(v)
end
