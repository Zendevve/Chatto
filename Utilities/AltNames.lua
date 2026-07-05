local AddonName, ns = ...
local Chatto = _G[AddonName]

local AltNames = Chatto:NewModule("AltNames", "AceEvent-3.0")

local _G = _G
local ipairs = ipairs
local pairs = pairs
local type = type
local strlower = string.lower
local string_format = string.format
local GetNumGuildMembers = GetNumGuildMembers
local GetGuildRosterInfo = GetGuildRosterInfo
local IsInGuild = IsInGuild

local guildNotes = {}

local function ScanGuildNotes()
	if not IsInGuild() then return end

	local names = {}
	local memberCount = GetNumGuildMembers(true) or 0
	
	-- Map guild names
	for i = 1, memberCount do
		local name = GetGuildRosterInfo(i)
		if name then
			names[strlower(name)] = name
		end
	end

	-- Scan notes
	guildNotes = {}
	for i = 1, memberCount do
		local name, rank, _, _, _, _, note = GetGuildRosterInfo(i)
		if name and note and note ~= "" then
			local matched = false
			-- Scan words in note
			for word in string.gmatch(strlower(note), "[%a\128-\255]+") do
				if names[word] and strlower(name) ~= word then
					guildNotes[name] = names[word]
					matched = true
					break
				end
			end
			-- Fallback if rank contains "alt"
			if not matched then
				local lowerRank = strlower(rank or "")
				if string.find(lowerRank, "alt") then
					guildNotes[name] = note
				end
			end
		end
	end
end

local function GetAltText(msg, name)
	if name and #name > 0 then
		local main = guildNotes[name]
		if main and main ~= "" then
			return string_format("%s|cff888888(%s)|r", msg, main)
		end
	end
	return msg
end

function AltNames:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.utilities.altnames then return text, r, g, b end
	if not text then return text, r, g, b end

	-- Matches |Hplayer:PlayerName|h[PlayerName]|h
	text = text:gsub("(|Hplayer:([^:]+).-|h.-|h)", GetAltText)
	return text, r, g, b
end

function AltNames:OnInitialize()
	Chatto:RegisterFilter("AltNames", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 90)
end

function AltNames:OnEnable()
	self:RegisterEvent("GUILD_ROSTER_UPDATE", function()
		ScanGuildNotes()
	end)
	if IsInGuild() then
		GuildRoster()
		ScanGuildNotes()
	end
end

function AltNames:OnDisable()
	self:UnregisterEvent("GUILD_ROSTER_UPDATE")
	guildNotes = {}
end
