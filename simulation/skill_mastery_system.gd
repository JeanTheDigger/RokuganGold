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
## WIRED HERE (Merchant masteries — s24 Commerce / Engineering / Sailing):
##   • Engineering R5 (+5 Cooperative/Cumulative) via cooperative_roll_bonus() — LIVE
##     (ActionExecutor FORTIFY_WALL_SECTION cumulative SI track, s57.41).
##   • Sailing R5 (+5 Cooperative/Cumulative) via the same helper — READY but DORMANT
##     (no Sailing skill roll exists in the sim; Sailing is only rank-gated for captaincy).
##   • Commerce R5 (price ±20% in the actor's favor) via commerce_price_favor_multiplier() —
##     the BUY half is LIVE (PURCHASE_MARKET koku cost); the sell half is dormant.
##   • Craft has NO masteries (s24 "Mastery Abilities: None").
##
## NO CONSUMER (LOCKED but no sim mechanic to attach to — documented so they aren't "forgotten"):
##   • Meditation R5 Fasting TN −5 — no individual food/water mechanic (starvation is province-level).
##   • Divination R5 (free second divination roll) — Divination is not a sim action (GM-flavor).
##
## WIRED HERE (Bugei combat masteries, s24.2, via IndividualCombat resolve hooks):
##   • Kenjutsu R3 (+1k0 sword damage) / R7 (explode on 9-10); Jiujutsu R3 (+1k0 unarmed) /
##     R7 (+0k1); Heavy Weapons R7 (explode on 9-10); Kyujutsu R7 (Bow Strength +1 → +1 die)
##     → resolve_damage.
##   • Defense R5 (Armor TN +3 in Defense/Full Defense); War Fan R5/R7 (Armor TN +1/+3) → get_armor_tn.
##   • Battle R5 (Battle Rank to Initiative in skirmishes) → roll_initiative.
##   • Heavy Weapons R3 (opponent Reduction −2) / Spears R3 (−3 first round) → total_defender_reduction.
##   • Heavy Weapons R5 (Free Raise toward Knockdown) / Knives R5 (toward Disarm) → orchestrator
##     maneuver resolution.
##   • Iaijutsu R5 (Focus Free Raise) / R7 (Assessment-win Focus bonus +2k2 vs +1k1) →
##     resolve_duel_focus; Knives R3 (no off-hand penalty with a knife) → resolve_off_hand_attack.
##   The damage/explode/War-Fan/reduction masteries fire in NPC summary combat (duels, bodyguard
##   fights, hunts); Defense-stance, Battle-initiative, and the maneuver free-raises fire in the
##   turn-based orchestrator. The WEAPON_CATALOG was expanded to the full L5R 4e equipment tables
##   (owner-provided 2026-06-29), so Spears (yari, lance, …), Chain Weapons (kusarigama, …), and
##   Staves (bo, jo, …) now have weapons — those masteries are live (Spears R3 reduction-pierce,
##   etc.). The bo's skill was corrected "Bo" → "Staves" (the canonical name).
##
## DEFERRED (each needs a different consumer; values all LOCKED in s24):
##   • TN reduction — Acting R3/5/7 (disguise TN −5/−10/−15) → disguise creation consumer.
##   • Conditional roll — Hunting R5 (+1k0 Stealth in wilderness) → needs a wilderness context flag.
##   • Action-economy — Investigation R3/R7 (extra Search attempts).
##   • Bugei action-economy / movement / maneuver (turn-based orchestrator, mostly PC-travel HOLD):
##     Ready-as-Free-Action (Kenjutsu R5, Iaijutsu R3, Spears/Polearms/Staves R7), Defense R3/R7
##     stance actions, Athletics/Stealth terrain movement, Horsemanship mount actions, Kyujutsu
##     range, Polearms R5 (vs mounted), and the Extra-Attack free-raise mastery (Knives R7 helper
##     exists, maneuver site not yet wired).
##   • Specific uses already hand-wired elsewhere — Calligraphy R5 (cipher, letter_system),
##     Tea Ceremony R5 (2 VP), Medicine R5 (+1k0 heal).


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
		"Kyujutsu":
			# R7: Bow Strength +1 → +1 rolled damage die (s24 line 407).
			if rank >= MASTERY_RANK_7:
				rolled += 1
	return {"rolled": rolled, "kept": kept}


# Free Raises a weapon-skill mastery grants toward a specific COMBAT MANEUVER (s24.2).
#   "disarm":       Knives R5 (s24 line 411).
#   "knockdown":    Heavy Weapons R5 (s24 line 403).
#   "grapple":      Jiujutsu R5 (s24 line 387).
#   "extra_attack": Knives R7 (s24 line 411).
static func maneuver_free_raises(weapon_skill: String, rank: int, maneuver: String) -> int:
	match maneuver:
		"disarm":
			if weapon_skill == "Knives" and rank >= MASTERY_RANK_5:
				return 1
			# Chain Weapons R7: Free Raise toward Disarm OR Knockdown (s24 line 319).
			if weapon_skill == "Chain Weapons" and rank >= MASTERY_RANK_7:
				return 1
		"knockdown":
			if weapon_skill == "Heavy Weapons" and rank >= MASTERY_RANK_5:
				return 1
			# Staves R5: Free Raise toward Knockdown (s24 line 327).
			if weapon_skill == "Staves" and rank >= MASTERY_RANK_5:
				return 1
			# Chain Weapons R7: Free Raise toward Disarm OR Knockdown (s24 line 319).
			if weapon_skill == "Chain Weapons" and rank >= MASTERY_RANK_7:
				return 1
		"grapple":
			if weapon_skill == "Jiujutsu" and rank >= MASTERY_RANK_5:
				return 1
		"extra_attack":
			if weapon_skill == "Knives" and rank >= MASTERY_RANK_7:
				return 1
	return 0


# Chain Weapons R3: a chain weapon may initiate a Grapple only at rank 3+ (s24 line 319). Below R3 a
# chain-weapon wielder cannot weapon-grapple.
static func chain_weapon_can_grapple(weapon_skill: String, rank: int) -> bool:
	return weapon_skill == "Chain Weapons" and rank >= MASTERY_RANK_3


# Chain Weapons R5: +1k0 (one rolled die) on rolls against an entangled/Grappled opponent — applied
# to the chain-user's attack roll vs a restrained target (s24 line 319).
static func chain_vs_restrained_bonus(weapon_skill: String, rank: int, target_restrained: bool) -> int:
	return 1 if (weapon_skill == "Chain Weapons" and rank >= MASTERY_RANK_5 and target_restrained) else 0


# Staves R7: a SMALL staff gets +1k0 damage (s24 line 327; large staves get the ready-as-Free-Action
# benefit instead). weapon_size is the weapon's catalog size ("Large" = the bo).
static func staff_small_damage_bonus(weapon_skill: String, rank: int, weapon_size: String) -> int:
	return 1 if (weapon_skill == "Staves" and rank >= MASTERY_RANK_7 and weapon_size != "Large") else 0


# Spears R5: ranged (thrown) range +5' = +1 tile (s24 line 399). Applies to a thrown Spears weapon.
static func spears_thrown_range_bonus(weapon_skill: String, rank: int) -> int:
	return 1 if (weapon_skill == "Spears" and rank >= MASTERY_RANK_5) else 0


# Hunting R5: +1k0 (one rolled die) to Stealth Skill Rolls in wilderness environments (s24 line 233).
static func hunting_wilderness_stealth_bonus(character: L5RCharacterData, skill: String, in_wilderness: bool) -> int:
	if skill == "Stealth" and in_wilderness and int(character.skills.get("Hunting", 0)) >= MASTERY_RANK_5:
		return 1
	return 0


# Forgery R5: +1k0 (one rolled die) on ANY roll to DETECT a forgery made by someone else
# (s24 Forgery mastery). Cross-skill — the detector's Forgery RANK boosts their
# Investigation/Perception detection roll. Returns the rolled-die bonus (0 or 1).
static func forgery_detect_rolled_bonus(character: L5RCharacterData) -> int:
	return 1 if int(character.skills.get("Forgery", 0)) >= MASTERY_RANK_5 else 0


# Forgery R3: +1k0 (one rolled die) on the roll that MAKES a forgery — a better forgery is
# harder to detect (s24 Forgery mastery). The forger's roll total is the forgery's detection
# TN (owner ruling 2026-06-30, reconciling s12.8 base+raises with the s24 roll-result model),
# so the mastery die raises that TN. Returns the rolled-die bonus (0 or 1).
static func forgery_tn_rolled_bonus(character: L5RCharacterData) -> int:
	return 1 if int(character.skills.get("Forgery", 0)) >= MASTERY_RANK_3 else 0


# Forgery R7: +0k1 (one kept die) on the roll that MAKES a forgery (s24 Forgery mastery).
# Cumulative with R3 (a Rank-7 forger gets +1k1). Returns the kept-die bonus (0 or 1).
static func forgery_tn_kept_bonus(character: L5RCharacterData) -> int:
	return 1 if int(character.skills.get("Forgery", 0)) >= MASTERY_RANK_7 else 0


# Staves base rule: a staff attack doubles the DEFENDER's worn-armor TN bonus (s24 line 327). The
# staff-user negates this doubling at Staves R3. Returns true when the attacker wields a staff and
# lacks R3 (so the defender's armor TN bonus should be added one extra time = doubled).
static func staff_doubles_armor(attacker_weapon_skill: String, attacker_rank: int) -> bool:
	return attacker_weapon_skill == "Staves" and attacker_rank < MASTERY_RANK_3


# Athletics R7: +5 ft = +1 tile to ONE Move Action per Round (s24 line ~193; the round total is
# capped, so it is a single-action burst, not a net round increase). Returns the per-move tile bonus
# for an Athletics R7+ character (the once-per-Round gating is the caller's TurnState flag).
static func athletics_move_burst(character: L5RCharacterData) -> int:
	return 1 if int(character.skills.get("Athletics", 0)) >= MASTERY_RANK_7 else 0


# Action cost to READY (draw / string) a weapon (s24 "ready as a Free Action" masteries). Returns
# "free" / "simple" / "complex". The BASE costs are PROVISIONAL L5R 4e core values (the project GDD
# gives no base): a melee weapon is readied/sheathed as a Simple Action; a bow must be strung as a
# Complex Action. The masteries reduce them:
#   Kyujutsu R3  — stringing a bow is a Simple Action (s24 line 405).
#   Kenjutsu R5  — a sword is readied as a Free Action (s24 line 393).
#   Iaijutsu R3  — readying a KATANA is a Free Action (s24 line 243).
#   Spears R7    — ready as a Free Action (s24 line 399).
#   Polearms R7  — ready as a Free Action (s24 line 325).
#   Staves R7    — LARGE staves ready as a Free Action (s24 line 327).
static func weapon_ready_cost(character: L5RCharacterData, weapon_name: String, weapon_skill: String, weapon_size: String) -> String:
	# Bows: stringing. Base Complex (PROVISIONAL); Kyujutsu R3 → Simple.
	if weapon_skill == "Kyujutsu":
		return "simple" if int(character.skills.get("Kyujutsu", 0)) >= MASTERY_RANK_3 else "complex"
	# Melee: base Simple (PROVISIONAL). A matching ready-mastery makes it Free.
	if weapon_skill == "Kenjutsu" and int(character.skills.get("Kenjutsu", 0)) >= MASTERY_RANK_5:
		return "free"
	if weapon_name == "katana" and int(character.skills.get("Iaijutsu", 0)) >= MASTERY_RANK_3:
		return "free"
	if weapon_skill == "Spears" and int(character.skills.get("Spears", 0)) >= MASTERY_RANK_7:
		return "free"
	if weapon_skill == "Polearms" and int(character.skills.get("Polearms", 0)) >= MASTERY_RANK_7:
		return "free"
	if weapon_skill == "Staves" and weapon_size == "Large" and int(character.skills.get("Staves", 0)) >= MASTERY_RANK_7:
		return "free"
	return "simple"


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


# Attacker's weapon-skill reduction-pierce (subtracted from the defender's Reduction).
#   Heavy Weapons R3: opponent Reduction −2, any round (s24 line 403).
#   Spears R3: ignore 3 Reduction against opponents in the FIRST round only (s24 line 399).
static func weapon_reduction_pierce(weapon_skill: String, rank: int, is_first_round: bool) -> int:
	if rank < MASTERY_RANK_3:
		return 0
	match weapon_skill:
		"Heavy Weapons":
			return 2
		"Spears":
			return 3 if is_first_round else 0
	return 0


# Iaijutsu R5: one Free Raise on the Iaijutsu (Focus)/Void roll during a duel's Focus Stage
# (s24 line 245). Applied as +5 to the contested Focus total (the codebase 1-Raise = +5
# convention; the Focus margin is itself converted to strike Free Raises via margin/5).
static func iaijutsu_focus_free_raise(character: L5RCharacterData) -> int:
	return 5 if int(character.skills.get("Iaijutsu", 0)) >= MASTERY_RANK_5 else 0


# Iaijutsu R7: the Assessment-win Focus bonus is +2k2 instead of +1k1 when the duelist's
# Assessment exceeded the opponent's by 10+ (s24 line 247). Returns the bonus dice count N
# (the Focus bonus is +NkN): base 1, R7 → 2.
static func iaijutsu_assessment_bonus_dice(character: L5RCharacterData) -> int:
	return 2 if int(character.skills.get("Iaijutsu", 0)) >= MASTERY_RANK_7 else 1


# Knives R3: the off-hand attack suffers NO size penalty when the off-hand WEAPON is a knife
# (s24 line 303). off_hand_skill is the off-hand weapon's skill ("Knives" for a knife).
static func knives_negates_offhand_penalty(character: L5RCharacterData, off_hand_skill: String) -> bool:
	return off_hand_skill == "Knives" and int(character.skills.get("Knives", 0)) >= MASTERY_RANK_3


# Horsemanship action costs (s24, owner-confirmed). Mounting: Complex (base) → Simple at R5 → Free
# at R7. Dismounting: Simple (base) → Free at R5+.
static func horsemanship_mount_cost(character: L5RCharacterData) -> String:
	var r: int = int(character.skills.get("Horsemanship", 0))
	if r >= MASTERY_RANK_7:
		return "free"
	if r >= MASTERY_RANK_5:
		return "simple"
	return "complex"


static func horsemanship_dismount_cost(character: L5RCharacterData) -> String:
	return "free" if int(character.skills.get("Horsemanship", 0)) >= MASTERY_RANK_5 else "simple"


# Horsemanship R3: the character may use Full Attack Stance while mounted (s24). Without it, a
# mounted combatant cannot take Full Attack.
static func horsemanship_allows_mounted_full_attack(character: L5RCharacterData) -> bool:
	return int(character.skills.get("Horsemanship", 0)) >= MASTERY_RANK_3


# Polearms R5: +1k0 damage against a mounted or significantly larger opponent (s24 line 325).
# weapon_skill must be "Polearms" (the wielded weapon's skill); target_mounted/_large describe
# the defender. Returns the {rolled, kept} damage bonus.
static func polearm_vs_mounted_larger_bonus(weapon_skill: String, rank: int, target_mounted: bool, target_large: bool) -> Dictionary:
	if weapon_skill == "Polearms" and rank >= MASTERY_RANK_5 and (target_mounted or target_large):
		return {"rolled": 1, "kept": 0}
	return {"rolled": 0, "kept": 0}


# Polearms R3: +5 Initiative in the FIRST round of a skirmish (s24 line 323). round_number is the
# combat round (1 = first); the bonus applies only on round 1.
static func polearm_first_round_initiative(weapon_skill: String, rank: int, round_number: int) -> int:
	if weapon_skill == "Polearms" and rank >= MASTERY_RANK_3 and round_number == 1:
		return 5
	return 0


# Kyujutsu R5: bow maximum range increased 50% (s24 line 405). Returns the range multiplier for a
# bow (Kyujutsu skill) wielder at rank 5+, else 1.0 (no change).
static func kyujutsu_range_multiplier(weapon_skill: String, rank: int) -> float:
	if weapon_skill == "Kyujutsu" and rank >= MASTERY_RANK_5:
		return 1.5
	return 1.0


# ============================================================================
# Merchant / Craft masteries — s24 (Commerce, Engineering, Sailing). Craft has
# NO Mastery Abilities per s24 ("Mastery Abilities: None"), so nothing to wire.
# ============================================================================

# Cooperative/Cumulative-roll flat bonus (+5) granted by a skill's Rank-5 mastery:
# Engineering R5 and Sailing R5 ("+5 to <skill> rolls made as part of a Cooperative
# or Cumulative effort", s24). Returned as a flat add for SkillResolver's mastery
# bonus slot. Engineering R5 is LIVE (FORTIFY_WALL_SECTION cumulative track, s57.41);
# Sailing R5 is READY but DORMANT — no Sailing skill check exists in the sim (Sailing
# is only rank-gated for captaincy, never rolled), so it has no consumer until a
# cooperative/cumulative Sailing roll is added.
const COOPERATIVE_ROLL_BONUS: int = 5
const COOPERATIVE_SKILLS: Array = ["Engineering", "Sailing"]

static func cooperative_roll_bonus(skill: String, character: L5RCharacterData) -> int:
	var b: String = base_skill(skill)
	if b in COOPERATIVE_SKILLS and int(character.skills.get(b, 0)) >= MASTERY_RANK_5:
		return COOPERATIVE_ROLL_BONUS
	return 0


# Commerce R5: when the character buys or sells goods, the final price moves up to
# 20% in their favor (s24). Returns the price multiplier: buying → 0.8 (pay 20%
# less); selling → 1.2 (receive 20% more); 1.0 if not Commerce R5+. The 20% is
# GDD-locked. Applied to PURCHASE_MARKET (the sim's market-buy koku cost); the sell
# half has no koku-producing sell transaction in the sim yet (dormant).
const COMMERCE_PRICE_FAVOR: float = 0.20

static func commerce_price_favor_multiplier(character: L5RCharacterData, is_buying: bool) -> float:
	if int(character.skills.get("Commerce", 0)) < MASTERY_RANK_5:
		return 1.0
	return (1.0 - COMMERCE_PRICE_FAVOR) if is_buying else (1.0 + COMMERCE_PRICE_FAVOR)
