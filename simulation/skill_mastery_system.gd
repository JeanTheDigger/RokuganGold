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
## WIRED HERE (Insight bonus, via CharacterStats.get_insight):
##   • Courtier/Etiquette R3 (+3 Insight) / R7 (+7 Insight total) — the ONLY two skills with
##     Insight masteries (s24 lines 57, 67).
##
## WIRED HERE (Spell Casting Roll bonus, via SpellSystem.resolve_cast):
##   • Spellcraft R5 (+1k0 on Spell Casting Rolls, s24 line 153). NOTE the casting roll is
##     Ring + School Rank — NOT a Spellcraft skill roll — so the universal R10 Free Raise does
##     NOT apply to it (R10 covers actual Spellcraft skill rolls via SkillResolver).
##
## WIRED HERE (Void Point recovery cap, via ActionExecutor._execute_meditate):
##   • Meditation R3 (restores up to 2 VP) / R7 (restores up to 3 VP), base 1 (s24 line 145).
##
## NO CONSUMER (LOCKED but no sim mechanic to attach to — documented so they aren't "forgotten"):
##   • Meditation R5 Fasting TN −5 — no individual food/water mechanic (starvation is province-level).
##   • Divination R5 (free second divination roll) — Divination is not a sim action (GM-flavor).
##
## WIRED HERE (Bugei combat masteries, s24.2, via IndividualCombat resolve hooks):
##   • Kenjutsu R3 (+1k0 sword damage) / R7 (explode on 9-10); Jiujutsu R3 (+1k0 unarmed) /
##     R7 (+0k1); Heavy Weapons R7 (explode on 9-10) → resolve_damage.
##   • Defense R5 (Armor TN +3 in Defense/Full Defense); War Fan R5/R7 (Armor TN +1/+3) → get_armor_tn.
##   • Battle R5 (Battle Rank to Initiative in skirmishes) → roll_initiative.
##   The damage/explode/War-Fan masteries fire in NPC summary combat (duels, bodyguard fights,
##   hunts); Defense-stance and Battle-initiative fire in the turn-based orchestrator.
##
## DEFERRED (each needs a different consumer; values all LOCKED in s24):
##   • TN reduction — Acting R3/5/7 (disguise TN −5/−10/−15) → disguise creation consumer.
##   • Conditional roll — Hunting R5 (+1k0 Stealth in wilderness) → needs a wilderness context flag.
##   • Action-economy — Investigation R3/R7 (extra Search attempts).
##   • Bugei action-economy / movement / maneuver (turn-based orchestrator, mostly PC-travel HOLD):
##     Ready-as-Free-Action (Kenjutsu R5, Iaijutsu R3, Spears/Polearms/Staves R7), Defense R3/R7
##     stance actions, Athletics/Stealth terrain movement, Horsemanship mount actions, Kyujutsu
##     range, Iaijutsu R5/R7 duel Focus, Polearms R5 (vs mounted), reduction-pierce (Spears/Heavy
##     R3), and the Grapple/Knockdown/Disarm/Extra-Attack free-raise masteries.
##   • Specific uses already hand-wired elsewhere — Calligraphy R5 (cipher, letter_system),
##     Engineering R5 (+5 cooperative, s57.41), Tea Ceremony R5 (2 VP), Medicine R5 (+1k0 heal).


const MASTERY_RANK_3: int = 3
const MASTERY_RANK_5: int = 5
const MASTERY_RANK_7: int = 7
const MASTERY_RANK_10: int = 10

# s24 skills carrying an Insight-bonus mastery (the only two). R3 → +3, R7 → +7 total.
const INSIGHT_SKILLS: Array = ["Courtier", "Etiquette"]
const INSIGHT_R3_BONUS: int = 3  # s24 lines 57, 67
const INSIGHT_R7_BONUS: int = 7  # s24 lines 57, 67 ("total" — supersedes, not cumulative)

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


# Insight-bonus mastery for one skill at the given rank (s24 lines 57, 67).
# R7+ → +7 (total, supersedes R3); R3–6 → +3; else 0. Only Courtier/Etiquette qualify.
static func insight_bonus(skill: String, rank: int) -> int:
	if not INSIGHT_SKILLS.has(base_skill(skill)):
		return 0
	if rank >= MASTERY_RANK_7:
		return INSIGHT_R7_BONUS
	if rank >= MASTERY_RANK_3:
		return INSIGHT_R3_BONUS
	return 0


# Total Insight bonus across all of a character's skills (Courtier + Etiquette masteries).
static func total_insight_bonus(character: L5RCharacterData) -> int:
	var total: int = 0
	for skill: String in character.skills.keys():
		total += insight_bonus(skill, int(character.skills[skill]))
	return total


# Spellcraft R5 mastery: extra ROLLED dice (+1k0) on Spell Casting Rolls (s24 line 153).
# Applies to the cast roll (Ring + School Rank), which is NOT a Spellcraft skill roll, so the
# universal R10 Free Raise is deliberately excluded here.
static func spellcraft_casting_rolled_bonus(character: L5RCharacterData) -> int:
	return 1 if int(character.skills.get("Spellcraft", 0)) >= MASTERY_RANK_5 else 0


# Meditation Void-recovery cap per meditation session (s24 line 145): base 1, R3 → 2, R7 → 3.
static func meditation_vp_recovery_cap(meditation_rank: int) -> int:
	if meditation_rank >= MASTERY_RANK_7:
		return 3
	if meditation_rank >= MASTERY_RANK_3:
		return 2
	return 1


# ============================================================================
# Bugei (martial) masteries — s24.2. Folded into IndividualCombat resolve hooks.
# ============================================================================

# Damage-roll bonus (rolled/kept dice) for a weapon SKILL at its rank.
#   Kenjutsu R3: +1k0 sword damage (s24 line 393).
#   Jiujutsu R3: +1k0 unarmed; R7: +0k1 unarmed (total +1k1 with R3) (s24 line 387).
static func weapon_damage_bonus(weapon_skill: String, rank: int) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0
	match weapon_skill:
		"Kenjutsu":
			if rank >= MASTERY_RANK_3:
				rolled += 1
		"Jiujutsu":
			if rank >= MASTERY_RANK_3:
				rolled += 1
			if rank >= MASTERY_RANK_7:
				kept += 1
	return {"rolled": rolled, "kept": kept}


# True if the weapon skill's damage dice explode on 9 (and 10) at this rank.
#   Kenjutsu R7 (s24 line 393) / Heavy Weapons R7 (s24 line 403).
static func weapon_damage_explodes_on_9(weapon_skill: String, rank: int) -> bool:
	return rank >= MASTERY_RANK_7 and (weapon_skill == "Kenjutsu" or weapon_skill == "Heavy Weapons")


# Bugei Armor-TN bonus (stance-aware).
#   Defense R5: Armor TN +3 in Defense/Full Defense Stance (s24 line 367 — ON TOP of the base
#     Defense-stance bonus, which already includes the Defense Rank).
#   War Fan R5: +1; R7: +3 (passive defensive bonus from war-fan mastery) (s24 line 419).
static func combat_armor_tn_bonus(character: L5RCharacterData, stance: Enums.Stance) -> int:
	var bonus: int = 0
	var def_rank: int = int(character.skills.get("Defense", 0))
	if def_rank >= MASTERY_RANK_5 and (stance == Enums.Stance.DEFENSE or stance == Enums.Stance.FULL_DEFENSE):
		bonus += 3
	var fan_rank: int = int(character.skills.get("War Fan", 0))
	if fan_rank >= MASTERY_RANK_7:
		bonus += 3
	elif fan_rank >= MASTERY_RANK_5:
		bonus += 1
	return bonus


# Battle R5: add Battle Skill Rank to Initiative Score during skirmishes (s24 line 339).
# All individual combat is skirmish-scale, so the bonus always applies at rank 5+.
static func battle_initiative_bonus(character: L5RCharacterData) -> int:
	var battle_rank: int = int(character.skills.get("Battle", 0))
	return battle_rank if battle_rank >= MASTERY_RANK_5 else 0
