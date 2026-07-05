local AddonName, ns = ...
local Chatto = _G[AddonName]
local Glass = Chatto.GlassEngine

local WordHighlight = Chatto:NewModule("WordHighlight", "AceEvent-3.0")

local _G = _G
local ipairs = ipairs
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat
local PlaySoundFile = PlaySoundFile

local function HighlightWordCaseInsensitive(str, word, colorHex)
	local lowerWord = word:lower()
	local matched = false
	local pos = 1
	local out = {}

	while true do
		local s, e = string_find(str:lower(), lowerWord, pos, true)
		if not s then
			out[#out + 1] = string_sub(str, pos)
			break
		end

		out[#out + 1] = string_sub(str, pos, s - 1)
		local matchText = string_sub(str, s, e)
		out[#out + 1] = "|cff" .. colorHex .. matchText .. "|r"
		matched = true
		pos = e + 1
	end

	return table_concat(out), matched
end

local function HighlightPlain(plain, words, colorHex)
	if plain == "" then return plain, false end
	local matched = false
	for _, word in ipairs(words) do
		if word and word ~= "" then
			local result, wordMatched = HighlightWordCaseInsensitive(plain, word, colorHex)
			if wordMatched then
				plain = result
				matched = true
			end
		end
	end
	return plain, matched
end

local function SafeHighlight(text, words, colorHex)
	if not text or text == "" or not words or #words == 0 then return text, false end

	local pos = 1
	local parts = {}
	local matched = false

	while true do
		local link_s, link_e, link_val = string_find(text, "(|H.-|h.-|h)", pos)
		local tex_s, tex_e, tex_val = string_find(text, "(|T.-|t)", pos)

		local tag_s, tag_e, tag_val
		if link_s and tex_s then
			if link_s < tex_s then
				tag_s, tag_e, tag_val = link_s, link_e, link_val
			else
				tag_s, tag_e, tag_val = tex_s, tex_e, tex_val
			end
		elseif link_s then
			tag_s, tag_e, tag_val = link_s, link_e, link_val
		elseif tex_s then
			tag_s, tag_e, tag_val = tex_s, tex_e, tex_val
		end

		if not tag_s then
			local plain = string_sub(text, pos)
			local plainHighlighted, wordMatched = HighlightPlain(plain, words, colorHex)
			if wordMatched then matched = true end
			parts[#parts + 1] = plainHighlighted
			break
		end

		local plain = string_sub(text, pos, tag_s - 1)
		local plainHighlighted, wordMatched = HighlightPlain(plain, words, colorHex)
		if wordMatched then matched = true end
		parts[#parts + 1] = plainHighlighted

		parts[#parts + 1] = tag_val
		pos = tag_e + 1
	end

	return table_concat(parts), matched
end

function WordHighlight:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.utilities.wordhighlight then return text, r, g, b end
	if not text then return text, r, g, b end

	local words = Chatto.db.profile.utilities.highlightWords
	local colorHex = Chatto.db.profile.utilities.highlightColorHex or "ffff00"

	local highlighted, matched = SafeHighlight(text, words, colorHex)
	if matched and Chatto.db.profile.utilities.highlightSound then
		PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
	end

	return highlighted, r, g, b
end

function WordHighlight:OnInitialize()
	Chatto:RegisterFilter("WordHighlight", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 95)
end

function WordHighlight:OnEnable()
end

function WordHighlight:OnDisable()
end
