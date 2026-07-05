local AddonName, ns = ...
local Chatto = _G[AddonName]

local Spells = Chatto:NewModule("Spells", "AceEvent-3.0")

local G = {
	LEARN_ABILITY = ERR_LEARN_ABILITY_S or "You have learned a new ability: %s.",
	LEARN_PASSIVE = ERR_LEARN_PASSIVE_S or "You have learned a new passive effect: %s.",
	LEARN_SPELL = ERR_LEARN_SPELL_S or "You have learned a new spell: %s.",
	SPELL_UNLEARNED = ERR_SPELL_UNLEARNED_S or "You have unlearned %s.",
}

local P = Chatto:MakePatternCache()

function Spells:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	if not Chatto.db.profile.filters.spells then return text, r, g, b end
	if not text then return text, r, g, b end

	if Chatto:SafeMatch(text, P[G.LEARN_ABILITY]) or 
	   Chatto:SafeMatch(text, P[G.LEARN_PASSIVE]) or 
	   Chatto:SafeMatch(text, P[G.LEARN_SPELL]) or 
	   Chatto:SafeMatch(text, P[G.SPELL_UNLEARNED]) then
		return nil -- Block completely
	end

	return text, r, g, b
end

function Spells:OnInitialize()
	Chatto:RegisterFilter("Spells", function(core, chatFrame, text, r, g, b, chatID, ...)
		return self:FilterAddMessage(core, chatFrame, text, r, g, b, chatID, ...)
	end, 60)
end

function Spells:OnEnable()
end

function Spells:OnDisable()
end
