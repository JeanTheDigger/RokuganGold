class_name SkillMasterySystem
## s24 Skill Mastery Abilities (LOCKED). Implements the roll-applicable masteries
## consumed by SkillResolver; other masteries are wired by their own systems or
## deferred (see the tranche list below). Pure data + helpers — no Node, no state.
##
## WIRED HERE (roll bonuses, via SkillResolver.resolve_skill_check / resolve_contested_check):
##   • Universal Rank 10 — one Free Raise on ALL rolls using the skill (s24 §24.0, line 31).
##   • Rank 5 contested-roll masteries (s24.1 / s24.4):
##       Courtier +1k0, Etiquette +1k0, Sincerity +5, Investigation +5,
##       Intimidation +5, Temptation +5 — "to all Contested Rolls using <skill>".
##
## DEFERRED (each needs a different consumer; values all LOCKED in s24):
##   • Insight masteries — Courtier/Etiquette R3 (+3 Insight) / R7 (+7 total) → CharacterStats.get_insight.
##   • Casting — Spellcraft R5 (+1k0 Spell Casting Rolls) → SpellSystem.resolve_cast.
##   • TN reduction — Acting R3/5/7 (disguise TN −5/−10/−15) → disguise creation consumer.
##   • VP/recovery — Meditation R3/5/7, Divination R5 (Tea Ceremony R5 + Medicine R5 already wired).
##   • Conditional roll — Hunting R5 (+1k0 Stealth in wilderness) → needs a wilderness context flag.
##   • Action-economy — Investigation R3/R7 (extra Search attempts).
##   • Combat / movement (s40 layer) — Defense, Kenjutsu, Iaijutsu, War Fan, Athletics, Stealth,
##     Battle, Horsemanship, Jiujutsu, weapon skills, etc.
##   • Specific uses already hand-wired elsewhere — Calligraphy R5 (cipher, letter_system),
##     Engineering R5 (+5 cooperative, s57.41), Tea Ceremony R5 (2 VP), Medicine R5 (+1k0 heal).


const MASTERY_RANK_5: int = 5
const MASTERY_RANK_10: int = 10

# s24 Rank-5 contested-roll masteries, keyed by base skill. {rolled, kept, flat}.
const CONTESTED_R5: Dictionary = {
	"Courtier":      {"rolled": 1, "kept": 0, "flat": 0},  # +1k0 (s24 line 57)
	"Etiquette":     {"rolled": 1, "kept": 0, "flat": 0},  # +1k0 (s24 line 67)
	"Sincerity":     {"rolled": 0, "kept": 0, "flat": 5},  # +5   (s24 line 85)
	"Investigation": {"rolled": 0, "kept": 0, "flat": 5},  # +5   (s24 line 121)
	"Intimidation":  {"rolled": 0, "kept": 0, "flat": 5},  # +5   (s24 line 409)
	"Temptation":    {"rolled": 0, "kept": 0, "flat": 5},  # +5   (s24 line 437)
}


# Strip "Parent: Sub" to the base skill — masteries key on the base skill.
static func base_skill(skill: String) -> String:
	var c: int = skill.find(":")
	if c >= 0:
		return skill.substr(0, c).strip_edges()
	return skill


# Universal Rank-10 mastery: 1 Free Raise on ALL rolls using the skill (s24 line 31).
static func universal_free_raise(rank: int) -> int:
	return 1 if rank >= MASTERY_RANK_10 else 0


# Rank-5 contested-roll bonus for the skill. {rolled, kept, flat} (zeros if none).
# The universal Rank-10 free raise is handled separately via universal_free_raise().
static func contested_bonus(skill: String, rank: int) -> Dictionary:
	if rank >= MASTERY_RANK_5:
		var b: String = base_skill(skill)
		if CONTESTED_R5.has(b):
			return CONTESTED_R5[b]
	return {"rolled": 0, "kept": 0, "flat": 0}
