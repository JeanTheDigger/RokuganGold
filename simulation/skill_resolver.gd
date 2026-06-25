class_name SkillResolver
## Resolves skill checks by looking up the correct trait for a skill,
## pulling the character's rank and emphases, applying wound penalties,
## and calling DiceEngine. All skill-based rolling goes through here.

# Skill -> default Trait mapping per L5R4e Section 24.
# Macro-skills (Lore, Perform, Craft, etc.) share one entry — sub-skills
# use the same trait unless overridden below.
const SKILL_TRAITS: Dictionary = {
	# -- High Skills --
	"Acting": Enums.Trait.AWARENESS,
	"Artisan": Enums.Trait.AWARENESS,
	"Calligraphy": Enums.Trait.INTELLIGENCE,
	"Courtier": Enums.Trait.AWARENESS,
	"Divination": Enums.Trait.INTELLIGENCE,
	"Etiquette": Enums.Trait.AWARENESS,
	"Games": Enums.Trait.AWARENESS,
	"Investigation": Enums.Trait.PERCEPTION,
	"Lore": Enums.Trait.INTELLIGENCE,
	"Medicine": Enums.Trait.INTELLIGENCE,
	"Meditation": Enums.Trait.VOID,
	"Perform": Enums.Trait.AWARENESS,
	"Sincerity": Enums.Trait.AWARENESS,
	"Spellcraft": Enums.Trait.INTELLIGENCE,
	"Tea Ceremony": Enums.Trait.VOID,
	# -- Bugei Skills --
	"Athletics": Enums.Trait.STRENGTH,
	"Battle": Enums.Trait.PERCEPTION,
	"Defense": Enums.Trait.REFLEXES,
	"Horsemanship": Enums.Trait.AGILITY,
	"Hunting": Enums.Trait.PERCEPTION,
	"Iaijutsu": Enums.Trait.REFLEXES,
	"Jiujutsu": Enums.Trait.AGILITY,
	"Kenjutsu": Enums.Trait.AGILITY,
	"Kyujutsu": Enums.Trait.REFLEXES,
	"Spears": Enums.Trait.AGILITY,
	"Polearms": Enums.Trait.AGILITY,
	"Heavy Weapons": Enums.Trait.AGILITY,
	"Knives": Enums.Trait.AGILITY,
	"War Fan": Enums.Trait.AGILITY,
	"Chain Weapons": Enums.Trait.AGILITY,
	"Staves": Enums.Trait.AGILITY,
	"Ninjutsu": Enums.Trait.AGILITY,
	# -- Merchant Skills --
	"Animal Handling": Enums.Trait.AWARENESS,
	"Commerce": Enums.Trait.INTELLIGENCE,
	"Craft": Enums.Trait.INTELLIGENCE,
	"Engineering": Enums.Trait.INTELLIGENCE,
	"Sailing": Enums.Trait.INTELLIGENCE,
	# -- Low Skills --
	"Forgery": Enums.Trait.AGILITY,
	"Intimidation": Enums.Trait.WILLPOWER,
	"Sleight of Hand": Enums.Trait.AGILITY,
	"Stealth": Enums.Trait.AGILITY,
	"Temptation": Enums.Trait.AWARENESS,
}

# Sub-skills that use a different trait than their parent macro-skill.
const SUB_SKILL_TRAIT_OVERRIDES: Dictionary = {
	# Perform sub-skills using Agility
	"Perform: Biwa": Enums.Trait.AGILITY,
	"Perform: Dance": Enums.Trait.AGILITY,
	"Perform: Drums": Enums.Trait.AGILITY,
	"Perform: Flute": Enums.Trait.AGILITY,
	"Perform: Puppeteer": Enums.Trait.AGILITY,
	"Perform: Samisen": Enums.Trait.AGILITY,
	# Perform sub-skills using Awareness (default, listed for completeness)
	"Perform: Oratory": Enums.Trait.AWARENESS,
	"Perform: Song": Enums.Trait.AWARENESS,
	"Perform: Storytelling": Enums.Trait.AWARENESS,
	# Games sub-skills
	"Games: Go": Enums.Trait.INTELLIGENCE,
	"Games: Shogi": Enums.Trait.INTELLIGENCE,
	"Games: Kemari": Enums.Trait.AGILITY,
	# Sailing can use Agility for physical maneuvers
	"Sailing: Knot-work": Enums.Trait.AGILITY,
	# Athletics throwing offensively uses Agility
	"Athletics: Throwing": Enums.Trait.AGILITY,
}


static func get_trait_for_skill(skill_name: String) -> Enums.Trait:
	if SUB_SKILL_TRAIT_OVERRIDES.has(skill_name):
		return SUB_SKILL_TRAIT_OVERRIDES[skill_name]

	# Check for "Parent: Sub" format — look up the parent
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		var parent: String = skill_name.substr(0, colon_pos).strip_edges()
		if SKILL_TRAITS.has(parent):
			return SKILL_TRAITS[parent]

	if SKILL_TRAITS.has(skill_name):
		return SKILL_TRAITS[skill_name]

	# Unknown skill — default to Awareness (least harmful fallback)
	return Enums.Trait.AWARENESS


static func get_skill_rank(character: L5RCharacterData, skill_name: String) -> int:
	if character.skills.has(skill_name):
		return character.skills[skill_name]

	# Check parent macro-skill for "Parent: Sub" format
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		var parent: String = skill_name.substr(0, colon_pos).strip_edges()
		if character.skills.has(parent):
			return character.skills[parent]

	return 0


static func has_emphasis(character: L5RCharacterData, skill_name: String, emphasis_name: String) -> bool:
	# Check exact skill name first, then parent
	var check_names: Array = [skill_name]
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		check_names.append(skill_name.substr(0, colon_pos).strip_edges())

	for name: String in check_names:
		if character.emphases.has(name):
			var emph_list: Array = character.emphases[name]
			if emphasis_name in emph_list:
				return true
	return false


# -- Technique Flag Assignment (s29.15) — called on creation and rank-up ------

static func apply_technique_flags(character: L5RCharacterData) -> void:
	var rank: int = CharacterStats.get_insight_rank(character)
	if character.school.begins_with("Ikoma Bard") and rank >= 1:
		character.precise_memory = true
	if character.school.begins_with("Doji Courtier") and rank >= 2:
		character.cadence_trained = true
	# Kshatriya Warrior (Ivory Kingdoms, s29.14) Fear resistance: Strength of Indra (R1)
	# raises Willpower one Rank vs Fear; Courage of Shiva (R5) adds +1k1 to resist Fear.
	if character.school.begins_with("Kshatriya Warrior"):
		if rank >= 1:
			character.fear_resist_willpower_bonus = 1
		if rank >= 5:
			character.fear_resist_rolled_bonus = 1
			character.fear_resist_kept_bonus = 1
	if rank >= 1:
		var all_schools: Array = [character.school]
		for path: String in character.school_paths:
			if path not in all_schools:
				all_schools.append(path)
		for s: String in all_schools:
			if s.begins_with("Yasuki Courtier") or s.begins_with("Yoritomo Courtier") or s.begins_with("Ide Trader"):
				character.commerce_honor_exempt = true
			if s.begins_with("Otomo Courtier") or s.begins_with("Yoritomo Courtier"):
				character.intimidation_honor_exempt = true


# -- School Technique Free Raises (s29.15) -------------------------------------

const DOJI_HONOR_THRESHOLD: float = 6.0
const DOJI_FREE_RAISE_SKILLS: Array[String] = ["Courtier", "Sincerity", "Etiquette"]
const FREE_RAISE_VALUE: int = 5

static func get_technique_free_raises(character: L5RCharacterData, skill_name: String) -> int:
	var free_raises: int = 0
	var base_skill: String = skill_name
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		base_skill = skill_name.substr(0, colon_pos).strip_edges()

	if character.school.begins_with("Doji Courtier") and character.honor >= DOJI_HONOR_THRESHOLD:
		if base_skill in DOJI_FREE_RAISE_SKILLS:
			free_raises += 1
	if character.school.begins_with("Yasuki Courtier") and base_skill == "Commerce":
		free_raises += 1
	if character.school.begins_with("Kitsuki Investigator") and base_skill == "Investigation":
		free_raises += 1
	if character.school.begins_with("Asako Loremaster") and base_skill == "Lore":
		free_raises += 1
	return free_raises


# -- Asako R2: From the Ashes (s29.15.10) — location-bound social buff --------

const SOCIAL_SKILLS: Array[String] = [
	"Acting", "Courtier", "Etiquette", "Sincerity",
	"Intimidation", "Temptation",
]
const FROM_THE_ASHES_BONUS_ROLLED: int = 2
const FROM_THE_ASHES_DURATION_DAYS: int = 2
const FROM_THE_ASHES_TN: int = 20

static func _get_ashes_bonus_for_skill(character: L5RCharacterData, skill_name: String, ic_day: int = -1) -> int:
	var buff: Dictionary = character.from_the_ashes
	if ic_day >= 0:
		var expires: int = buff.get("expires_ic_day", -1)
		if expires >= 0 and expires <= ic_day:
			character.from_the_ashes = {}
			return 0
	var base_skill: String = skill_name
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		base_skill = skill_name.substr(0, colon_pos).strip_edges()
	if base_skill not in SOCIAL_SKILLS:
		return 0
	return FROM_THE_ASHES_BONUS_ROLLED


static func activate_from_the_ashes(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	location_id: String,
	ic_day: int,
) -> Dictionary:
	if not character.school.begins_with("Asako Loremaster"):
		return {"success": false, "reason": "wrong_school"}
	var school_rank: int = CharacterStats.get_insight_rank(character)
	if school_rank < 2:
		return {"success": false, "reason": "rank_too_low"}

	var result: Dictionary = resolve_skill_check(
		character, dice_engine, "Lore: History", FROM_THE_ASHES_TN, 0, "",
		Enums.Trait.PERCEPTION,
	)
	if not result.get("success", false):
		return {"success": false, "roll_total": result.get("total", 0)}

	character.from_the_ashes = {
		"location_id": location_id,
		"expires_ic_day": ic_day + FROM_THE_ASHES_DURATION_DAYS,
	}
	return {"success": true, "roll_total": result.get("total", 0), "expires_ic_day": ic_day + FROM_THE_ASHES_DURATION_DAYS}


static func check_from_the_ashes_expiry(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	location_id: String,
	ic_day: int,
) -> Dictionary:
	var buff: Dictionary = character.from_the_ashes
	if buff.is_empty():
		return {"action": "none"}
	if buff.get("location_id", "") != location_id:
		character.from_the_ashes = {}
		return {"action": "cleared_wrong_location"}
	var expires: int = buff.get("expires_ic_day", -1)
	if expires > ic_day:
		return {"action": "still_active", "expires_ic_day": expires}
	return activate_from_the_ashes(character, dice_engine, location_id, ic_day)


# -- s38 out-of-combat kiho buffs (monk-only) ---------------------------------
# Two effects have real world-sim consumers (s38, scope owner-approved 2026-06-16):
#   The Mind's Fire (Fire 4): +2k2 on Intelligence-based skill rolls.
#   Steal the Air Dragon (Air 7): +Air Ring rolled & kept on Stealth rolls.
# Just-in-time per tick: the first qualifying roll of the IC day spends 1 Void
# Point (s38a Void Point activation = Free Action) to turn the buff on; later
# qualifying rolls the same tick reuse it (no extra VP). No effect when ic_day < 0
# (can't dedup, so we never risk draining Void Points on untracked calls).
const KIHO_MINDS_FIRE: String = "The Mind's Fire"
const KIHO_STEAL_AIR_DRAGON: String = "Steal the Air Dragon"


## s54.10 Buruburu Descent into Terror: after 3 consecutive failed nightly Willpower
## tests, the victim suffers +5 TN on all rolls, +5 more each consecutive day after.
## Returned as a negative roll penalty (DiceEngine.roll_check adds `bonus` to the roll).
## The nightmare-resist roll itself is exempt (it does not route through SkillResolver).
static func _get_possession_terror_penalty(character: L5RCharacterData) -> int:
	if String(character.possession_affliction.get("kind", "")) != "buruburu":
		return 0
	var fails: int = int(character.possession_affliction.get("consecutive_fails", 0))
	if fails < 3:
		return 0
	return -5 * (fails - 2)


static func _get_kiho_buff_bonus(
	character: L5RCharacterData, skill_name: String, trait_used: Enums.Trait, ic_day: int
) -> Dictionary:
	if ic_day < 0 or character.kiho.is_empty():
		return {"rolled": 0, "kept": 0}
	var rolled: int = 0
	var kept: int = 0
	if trait_used == Enums.Trait.INTELLIGENCE and character.kiho.has(KIHO_MINDS_FIRE):
		if _activate_kiho_buff(character, KIHO_MINDS_FIRE, ic_day):
			rolled += 2
			kept += 2
	if character.kiho.has(KIHO_STEAL_AIR_DRAGON):
		var base: String = skill_name
		var colon: int = skill_name.find(":")
		if colon != -1:
			base = skill_name.substr(0, colon).strip_edges()
		if base == "Stealth" and _activate_kiho_buff(character, KIHO_STEAL_AIR_DRAGON, ic_day):
			var air: int = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
			rolled += air
			kept += air
	return {"rolled": rolled, "kept": kept}


## s35 Mental Quickness (Fire 2): +3 Intelligence on the NEXT Intelligence-trait roll this IC day
## (owner 2026-06-25 — the "10 minutes" maps to one roll). A trait point = +1 rolled AND +1 kept, so
## +3 Int = +3k3. ONE-SHOT: consumed (mental_quickness_ic_day -> -1) the moment it applies. ic_day-gated
## (like the kiho buffs) so it lapses with the tick if no Int roll is made. Inert for non-Int rolls.
static func _get_mental_quickness_bonus(
	character: L5RCharacterData, trait_used: Enums.Trait, ic_day: int
) -> Dictionary:
	if ic_day < 0 or character.mental_quickness_ic_day != ic_day:
		return {"rolled": 0, "kept": 0}
	if trait_used != Enums.Trait.INTELLIGENCE:
		return {"rolled": 0, "kept": 0}
	character.mental_quickness_ic_day = -1  # consumed by this roll
	return {"rolled": 3, "kept": 3}


static func _activate_kiho_buff(character: L5RCharacterData, kiho_name: String, ic_day: int) -> bool:
	if character.active_kiho_buffs.get(kiho_name, -1) == ic_day:
		return true  # already active this tick
	if not VoidSystem.can_spend(character):
		return false
	VoidSystem.spend(character)
	character.active_kiho_buffs[kiho_name] = ic_day
	return true


# Void Point spend on a Skill/Trait roll (core L5R rule; the UI's "spend a Void Point" action).
# Opt-in via context["spend_void"] = true and context["void_points"] = N (default 1) — so existing
# callers that don't request it never drain VP. Normally capped at 1 VP per roll; while s37
# Altering the Course is active this tick (altering_course_ic_day == ic_day) the caster may spend
# up to N (bounded by the pool) for +NkN. NOT valid for damage rolls (this path is skill checks).
static func _get_void_spend_bonus(
	character: L5RCharacterData, context: Dictionary, ic_day: int
) -> Dictionary:
	if not context.get("spend_void", false):
		return {"rolled": 0, "kept": 0}
	var requested: int = maxi(1, int(context.get("void_points", 1)))
	var cap: int = 1
	if ic_day >= 0 and character.altering_course_ic_day == ic_day:
		cap = character.current_void_points  # Altering the Course: multiple VP on one roll
	var n: int = mini(requested, cap)
	if n < 1:
		return {"rolled": 0, "kept": 0}
	var r: Dictionary = VoidSystem.spend_n_for_roll(character, n)
	return {"rolled": int(r["rolled_bonus"]), "kept": int(r["kept_bonus"])}


# -- Voice of the Wind (s33 Air 1) — spoken social buff -----------------------
# A target under Voice of the Wind gains, for the IC day it was cast (the GDD's
# 10-minute / one-encounter window at this granularity): +1k0 to spoken Social
# Skill Rolls (Courtier/Etiquette/Sincerity/Intimidation/Temptation/Acting), and
# the Voice Advantage (+1k1 on a Perform Roll using voice, via context
# "is_voice_perform"). The two effects never overlap (Perform is not a Social
# Skill), so there is no double-count. Stacks additively with From the Ashes.
static func _get_voice_of_the_wind_bonus(
	character: L5RCharacterData, skill_name: String, context: Dictionary, ic_day: int
) -> Dictionary:
	if ic_day < 0 or character.voice_of_the_wind_ic_day != ic_day:
		return {"rolled": 0, "kept": 0}
	var rolled: int = 0
	var kept: int = 0
	var base_skill: String = skill_name
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		base_skill = skill_name.substr(0, colon_pos).strip_edges()
	if base_skill in SOCIAL_SKILLS:
		rolled += 1  # +1k0 to Social Skill Rolls that involve speech
	if context.get("is_voice_perform", false):
		rolled += 1  # granted Voice Advantage: +1k1 on a voice Perform Roll
		kept += 1
	return {"rolled": rolled, "kept": kept}


# -- Soul of Stone (s34 Earth 1, Defense) — manipulation resist / influence penalty --
# +3k0 when RESISTING coercive social manipulation (the caller marks the roll with
# context "is_manipulation_resist"); -1k0 to the buffed character's own Awareness-based
# social-influence rolls (Courtier/Etiquette/Sincerity/Temptation/Intimidation/Acting).
# The two are exclusive: a resist roll gets +3 (never the -1). Both are GDD-exact (s34).
const SOUL_OF_STONE_RESIST_BONUS: int = 3
const SOUL_OF_STONE_INFLUENCE_PENALTY: int = -1

static func _get_soul_of_stone_bonus(
	character: L5RCharacterData, skill_name: String, trait_used: Enums.Trait, context: Dictionary
) -> int:
	if not character.has_day_buff("soul_of_stone"):
		return 0
	if context.get("is_manipulation_resist", false):
		return SOUL_OF_STONE_RESIST_BONUS  # +3k0 to resist manipulation
	# Downside: -1k0 to Awareness-based Skill Rolls made to influence others.
	if trait_used == Enums.Trait.AWARENESS:
		var base_skill: String = skill_name
		var colon_pos: int = skill_name.find(":")
		if colon_pos >= 0:
			base_skill = skill_name.substr(0, colon_pos).strip_edges()
		if base_skill in SOCIAL_SKILLS:
			return SOUL_OF_STONE_INFLUENCE_PENALTY
	return 0


# -- Mental Quickness (s35 Fire 2) — Intelligence +3 from an imbued item ------
# The spell imbues an ITEM, and "anyone who carries that item has Intelligence +3". The buff
# therefore lives on the item (a "mental_quickness_imbued" flag on the item dict) and follows
# ownership: whoever's `items` array currently holds the imbued item gets the bonus. Only affects
# Intelligence-based rolls (the trait adds to both rolled and kept, so this is effectively +3k3).
const MENTAL_QUICKNESS_INT_BONUS: int = 3

static func _mental_quickness_trait_bonus(character: L5RCharacterData, trait_used: Enums.Trait) -> int:
	if trait_used != Enums.Trait.INTELLIGENCE:
		return 0
	for item: Variant in character.items:
		if item is Dictionary and (item as Dictionary).get("mental_quickness_imbued", false):
			return MENTAL_QUICKNESS_INT_BONUS
	return 0


# s34 Earth's Touch (Earth 1): +1 to ONE Earth Trait (caster's choice — Stamina or Willpower) for the
# day, via the trait-tagged day buff ("earths_touch_stamina" / "earths_touch_willpower"). Applied at
# roll resolution only (never the stored field), so the Earth Ring (= min(Stamina, Willpower)) is NOT
# increased per the GDD. Adds to both rolled and kept (effectively +1k1) on rolls using that trait.
static func _earths_touch_trait_bonus(character: L5RCharacterData, trait_used: Enums.Trait) -> int:
	# s34 Stone's Endurance shares this Stamina boost (non-stacking — +1 from this family, not +2).
	if trait_used == Enums.Trait.STAMINA and (character.has_day_buff("earths_touch_stamina") \
			or character.has_day_buff("stones_endurance")):
		return 1
	if trait_used == Enums.Trait.WILLPOWER and character.has_day_buff("earths_touch_willpower"):
		return 1
	return 0


# -- Doji R3: The Perfect Gift (s29.15.4) — one-shot disposition modifier ------

const PERFECT_GIFT_TN: int = 20
const PERFECT_GIFT_BASE_DISP: int = 20
const PERFECT_GIFT_RAISE_VALUES: Array[int] = [20, 35, 50]

static func execute_perfect_gift(
	doji: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if not doji.school.begins_with("Doji Courtier"):
		return {"success": false, "reason": "wrong_school"}
	var school_rank: int = CharacterStats.get_insight_rank(doji)
	if school_rank < 3:
		return {"success": false, "reason": "rank_too_low"}
	if target.character_id in doji.perfect_gift_targets:
		return {"success": false, "reason": "already_applied"}

	var result: Dictionary = resolve_skill_check(
		doji, dice_engine, "Courtier", PERFECT_GIFT_TN
	)
	if not result.get("success", false):
		return {"success": false, "roll_total": result.get("total", 0)}

	var margin: int = result.get("margin", 0)
	var raises: int = maxi(int(margin / 5), 0)
	var disp_value: int = PERFECT_GIFT_BASE_DISP
	if raises >= 2:
		disp_value = PERFECT_GIFT_RAISE_VALUES[2]
	elif raises >= 1:
		disp_value = PERFECT_GIFT_RAISE_VALUES[1]

	var old_disp: int = target.disposition_values.get(doji.character_id, 0)
	target.disposition_values[doji.character_id] = clampi(old_disp + disp_value, -100, 100)
	doji.perfect_gift_targets.append(target.character_id)

	return {
		"success": true,
		"roll_total": result.get("total", 0),
		"raises": raises,
		"disposition_applied": disp_value,
		"new_disposition": target.disposition_values[doji.character_id],
	}


# -- Deception Defense TN Modifier (s29.15.6 Kitsuki R2, s29.15.2 Yasuki R4) --

const DECEPTION_TN_PER_RANK: int = 5

const DECEPTIVE_ACTION_IDS: Array[String] = [
	"GOSSIP", "FABRICATE_SECRET", "FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
]

static func get_deception_defense_bonus(defender: L5RCharacterData) -> int:
	var school_rank: int = CharacterStats.get_insight_rank(defender)
	if defender.school.begins_with("Kitsuki Investigator") and school_rank >= 2:
		return DECEPTION_TN_PER_RANK * school_rank
	if defender.school.begins_with("Yasuki Courtier") and school_rank >= 4:
		return DECEPTION_TN_PER_RANK * school_rank
	return 0


# -- Cadence Sync (s29.15.4 Doji Courtier R2) — silent topic transfer ----------

const CADENCE_TN: int = 15

static func resolve_cadence_sync(
	characters: Array,
	court_char_ids: Array,
	dice_engine: DiceEngine,
) -> Array:
	var results: Array = []
	var cadence_ids: Array = []
	var char_map: Dictionary = {}
	for cid: int in court_char_ids:
		for c: L5RCharacterData in characters:
			if c.character_id == cid and c.cadence_trained and not CharacterStats.is_dead(c):
				cadence_ids.append(cid)
				char_map[cid] = c
				break
	if cadence_ids.size() < 2:
		return results
	for i: int in range(cadence_ids.size()):
		var sender: L5RCharacterData = char_map[cadence_ids[i]]
		var roll: Dictionary = resolve_skill_check(
			sender, dice_engine, "Courtier", CADENCE_TN, 0, "",
			Enums.Trait.AWARENESS,
		)
		if not roll.get("success", false):
			results.append({
				"sender_id": sender.character_id,
				"success": false,
			})
			continue
		var transferred: Array = []
		for j: int in range(cadence_ids.size()):
			if i == j:
				continue
			var receiver: L5RCharacterData = char_map[cadence_ids[j]]
			for tid: int in sender.topic_pool:
				if tid not in receiver.topic_pool:
					receiver.topic_pool.append(tid)
					if tid not in transferred:
						transferred.append(tid)
		results.append({
			"sender_id": sender.character_id,
			"success": true,
			"topics_shared": transferred.size(),
		})
	return results


# -- The main entry point: resolve a full skill check --------------------------

static func resolve_skill_check(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
	ic_day: int = -1,
	context: Dictionary = {},
) -> Dictionary:
	# Determine trait
	var trait_used: Enums.Trait
	if trait_override != Enums.Trait.NONE:
		trait_used = trait_override
	else:
		trait_used = get_trait_for_skill(skill_name)

	var trait_value: int = character.get_trait_value(trait_used)
	var skill_rank: int = get_skill_rank(character, skill_name)
	# CRAB_HANDS / CRAFTY / SAGE / SENSATION / SOUL_OF_ARTISTRY (s45)
	if skill_rank == 0 and not context.is_empty():
		skill_rank = AdvantageSystem.get_unskilled_rank_bonus(character, skill_name, context)

	# Emphasis check
	var has_emph: bool = false
	if emphasis_name != "":
		has_emph = has_emphasis(character, skill_name, emphasis_name)

	# Wound penalty applies to all Trait rolls
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)

	# School technique free raises (s29.15)
	var technique_fr: int = get_technique_free_raises(character, skill_name)

	# Asako R2: From the Ashes social buff (s29.15.10)
	var ashes_bonus: int = 0
	if not character.from_the_ashes.is_empty():
		ashes_bonus = _get_ashes_bonus_for_skill(character, skill_name, ic_day)

	# Advantage & Disadvantage modifiers (s45)
	var adv_skill: Dictionary = AdvantageSystem.get_skill_bonus(character, skill_name, context)
	var adv_tn: int = AdvantageSystem.get_tn_modifier(character, context)
	var adv_wound: int = AdvantageSystem.get_wound_tn_modifier(character)
	var adv_trait: int = AdvantageSystem.get_trait_modifier(character, trait_used, context)
	trait_value += adv_trait
	trait_value += _mental_quickness_trait_bonus(character, trait_used)  # s35: +3 Int from imbued item
	trait_value += _earths_touch_trait_bonus(character, trait_used)  # s34: +1 chosen Earth Trait
	if wound_penalty < 0:
		wound_penalty = mini(0, wound_penalty + adv_wound)

	# Mutation / Shadowlands Power modifiers (s44)
	var mutation_mod: Dictionary = MutationSystem.get_skill_modifiers(
		character, skill_name, emphasis_name, context
	)

	# Elemental Imbalance overflow penalties (s45 lines 537-545)
	var is_social: bool = context.get("is_social", false)
	var imbalance_mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(
		character, is_social, ic_day
	)

	# INHERITANCE (s45): +1k1 when using the family heirloom (extra kept die).
	var inheritance_mod: Dictionary = AdvantageSystem.get_inheritance_skill_bonus(
		character, context.get("using_heirloom", false)
	)

	# SOFT_HEARTED (s45): +10 TN on all rolls until end of the IC day a kill occurred.
	var soft_hearted_tn: int = 0
	if character.soft_hearted_tn_until >= 0 and ic_day >= 0 and ic_day < character.soft_hearted_tn_until:
		soft_hearted_tn = 10

	# CANT_LIE (s45): contested Willpower TN 20 before any Sincerity:Deceit roll.
	# On failure the roll is automatically treated as failed (returns early).
	if "Sincerity" in skill_name and context.get("is_deception", false):
		var cant_lie: Dictionary = AdvantageSystem.check_cant_lie_trigger(character, true)
		if cant_lie.get("triggered", false):
			# Roll Willpower TN 20 to override the block.
			var will_roll: Dictionary = dice_engine.roll_check(
				character.willpower, character.willpower, 20, 0, 0, true, false
			)
			if not will_roll.get("success", false):
				return {
					"success": false, "total": 0, "tn": tn, "margin": -tn,
					"skill": skill_name, "trait_used": trait_used, "skill_rank": skill_rank,
					"wound_penalty": wound_penalty, "emphasis_applied": false,
					"technique_free_raises": 0, "advantage_bonus": {},
					"cant_lie_blocked": true,
				}

	# DARLING_OF_THE_COURT (s45): +1 effective Status rank at home court → +5 TN equivalent.
	var darling_bonus: int = 0
	if context.get("is_court", false):
		darling_bonus = AdvantageSystem.get_darling_status_bonus(
			character, context.get("court_settlement_id", -1)
		) * 5  # 1 Status rank ≈ 1 Free Raise ≈ +5 effective bonus — PROVISIONAL

	# s38 out-of-combat kiho buffs (Mind's Fire / Steal the Air Dragon)
	var kiho_mod: Dictionary = _get_kiho_buff_bonus(character, skill_name, trait_used, ic_day)

	# s35 Mental Quickness: one-shot +3k3 on the next Intelligence-trait roll this tick
	var mq_mod: Dictionary = _get_mental_quickness_bonus(character, trait_used, ic_day)

	# Void Point spend on this roll (opt-in via context; s37 Altering the Course allows +NkN)
	var void_mod: Dictionary = _get_void_spend_bonus(character, context, ic_day)

	# s33 Voice of the Wind: spoken-social buff (+1k0 social-speech, +1k1 voice Perform)
	var voice_mod: Dictionary = _get_voice_of_the_wind_bonus(character, skill_name, context, ic_day)

	# s34 Soul of Stone: +3k0 resisting manipulation / -1k0 Awareness social influence
	var soul_mod: int = _get_soul_of_stone_bonus(character, skill_name, trait_used, context)

	# Build the pool: (trait + skill + bonus_rolled) k (trait + bonus_kept)
	var rolled: int = (
		trait_value + skill_rank + bonus_rolled + ashes_bonus
		+ adv_skill.get("rolled", 0) + mutation_mod.get("rolled", 0)
		+ imbalance_mod.get("rolled", 0) + inheritance_mod.get("rolled", 0)
		+ kiho_mod.get("rolled", 0) + void_mod.get("rolled", 0) + voice_mod.get("rolled", 0)
		+ mq_mod.get("rolled", 0) + soul_mod
	)
	var kept: int = (
		trait_value + bonus_kept + adv_skill.get("kept", 0) + mutation_mod.get("kept", 0)
		+ imbalance_mod.get("kept", 0) + inheritance_mod.get("kept", 0)
		+ kiho_mod.get("kept", 0) + void_mod.get("kept", 0) + voice_mod.get("kept", 0)
		+ mq_mod.get("kept", 0)
	)
	var total_bonus: int = flat_bonus + wound_penalty + (technique_fr * FREE_RAISE_VALUE) \
		+ (adv_skill.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn \
		+ mutation_mod.get("tn", 0) + soft_hearted_tn + darling_bonus \
		+ _get_possession_terror_penalty(character)

	# Unskilled: no explosions
	var explodes: bool = skill_rank > 0

	var result: Dictionary = dice_engine.roll_check(
		rolled, kept, tn, raises, total_bonus, explodes, has_emph
	)

	result["skill"] = skill_name
	result["trait_used"] = trait_used
	result["skill_rank"] = skill_rank
	result["wound_penalty"] = wound_penalty
	result["emphasis_applied"] = has_emph
	result["technique_free_raises"] = technique_fr
	result["advantage_bonus"] = adv_skill

	# LINGERING_MISFORTUNE: a narrow success (margin 0–4) is overturned once per month (s45)
	if ic_day >= 0 and result.get("success", false):
		var ic_month: int = ic_day / 30
		var lm: Dictionary = AdvantageSystem.check_lingering_misfortune(
			character, result.get("margin", 0), ic_month
		)
		if lm.get("triggered", false):
			result["success"] = false
			result["lingering_misfortune"] = true
			for dis: DisadvantageData in character.disadvantages:
				if dis.disadvantage_type == Enums.Disadvantage.BAD_FORTUNE:
					if dis.metadata.get("type", "") == "Lingering_Misfortune":
						dis.metadata["last_misfortune_month"] = ic_month
						break

	# DARK_PARAGON (s45): NPC activates retroactively when activation would turn a failed roll
	# into a success, or prevent death/crippling for Will/Determination.
	# Precept effects per s45:77:
	#   Determination — negate all TN/Wound penalties (no +5 bonus).
	#   Perfection    — NPC simulation proxy: +5 (die explosion cannot be simulated; GDD NPC
	#                   trigger rule uses "+5 or re-roll would change outcome" as proxy).
	#   All others    — +5 bonus (Control, Insight, Knowledge, Strength, Will).
	if not result.get("success", false):
		var dp_adv: AdvantageData = AdvantageSystem.get_advantage(
			character, Enums.Advantage.DARK_PARAGON
		)
		if dp_adv != null:
			var dp_precept: String = dp_adv.metadata.get("precept", "")
			var dp: Dictionary = AdvantageSystem.check_dark_paragon_activation(
				character, result.get("total", 0), result.get("tn", tn), dp_precept, ic_day
			)
			if dp.get("should_activate", false):
				if dp_precept == "Determination":
					# Negate wound penalty (wound_penalty is negative; subtracting negates it).
					var wp: int = result.get("wound_penalty", 0)
					result["total"] = result["total"] - wp
				else:
					# Perfection proxy (+5) and all other precepts (+5).
					result["total"] = result["total"] + 5
				result["margin"] = result["total"] - result["tn"]
				result["success"] = result["margin"] >= 0
				result["dark_paragon_activated"] = true
				result["dark_paragon_precept"] = dp_precept
				AdvantageSystem.apply_dark_paragon_cost(character, ic_day)

	# PARAGON Duty (s45 line 257): NPC spends a VP to negate all Wound/TN penalties on one roll.
	# Retroactive activation: fires when the roll failed and VP spend would change the outcome.
	# Does not activate if DARK_PARAGON already fixed the roll this tick.
	if not result.get("success", false) and not result.get("dark_paragon_activated", false):
		var pd: Dictionary = AdvantageSystem.check_paragon_duty_activation(
			character, result.get("total", 0), result.get("tn", tn),
			result.get("wound_penalty", 0)
		)
		if pd.get("should_activate", false):
			var wp: int = result.get("wound_penalty", 0)
			result["total"] = result["total"] - wp  # wound_penalty is negative; subtracting negates it
			result["margin"] = result["total"] - result["tn"]
			result["success"] = result["margin"] >= 0
			result["paragon_duty_activated"] = true
			character.current_void_points -= 1

	return result


# -- Contested skill check between two characters ------------------------------

static func resolve_contested_check(
	char_a: L5RCharacterData,
	char_b: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_a: String,
	skill_b: String,
	emphasis_a: String = "",
	emphasis_b: String = "",
	trait_override_a: Enums.Trait = Enums.Trait.NONE,
	trait_override_b: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled_a: int = 0,
	bonus_rolled_b: int = 0,
	flat_bonus_a: int = 0,
	flat_bonus_b: int = 0,
	ic_day: int = -1,
	context_a: Dictionary = {},
	context_b: Dictionary = {},
) -> Dictionary:
	# Character A
	var trait_a: Enums.Trait = trait_override_a if trait_override_a != Enums.Trait.NONE else get_trait_for_skill(skill_a)
	var tv_a: int = char_a.get_trait_value(trait_a)
	var sr_a: int = get_skill_rank(char_a, skill_a)
	var emph_a: bool = has_emphasis(char_a, skill_a, emphasis_a) if emphasis_a != "" else false
	var wp_a: int = CharacterStats.get_wound_penalty(char_a)
	var tfr_a: int = get_technique_free_raises(char_a, skill_a)
	var ashes_a: int = _get_ashes_bonus_for_skill(char_a, skill_a, ic_day) if not char_a.from_the_ashes.is_empty() else 0

	# Character B
	var trait_b: Enums.Trait = trait_override_b if trait_override_b != Enums.Trait.NONE else get_trait_for_skill(skill_b)
	var tv_b: int = char_b.get_trait_value(trait_b)
	var sr_b: int = get_skill_rank(char_b, skill_b)
	var emph_b: bool = has_emphasis(char_b, skill_b, emphasis_b) if emphasis_b != "" else false
	var wp_b: int = CharacterStats.get_wound_penalty(char_b)
	var tfr_b: int = get_technique_free_raises(char_b, skill_b)
	var ashes_b: int = _get_ashes_bonus_for_skill(char_b, skill_b, ic_day) if not char_b.from_the_ashes.is_empty() else 0

	# Advantage & Disadvantage modifiers (s45)
	var adv_a: Dictionary = AdvantageSystem.get_skill_bonus(char_a, skill_a, context_a)
	var adv_b: Dictionary = AdvantageSystem.get_skill_bonus(char_b, skill_b, context_b)
	var adv_tn_a: int = AdvantageSystem.get_tn_modifier(char_a, context_a)
	var adv_tn_b: int = AdvantageSystem.get_tn_modifier(char_b, context_b)
	var adv_wound_a: int = AdvantageSystem.get_wound_tn_modifier(char_a)
	var adv_wound_b: int = AdvantageSystem.get_wound_tn_modifier(char_b)
	tv_a += AdvantageSystem.get_trait_modifier(char_a, trait_a, context_a)
	tv_b += AdvantageSystem.get_trait_modifier(char_b, trait_b, context_b)
	tv_a += _mental_quickness_trait_bonus(char_a, trait_a)  # s35: +3 Int from imbued item
	tv_b += _mental_quickness_trait_bonus(char_b, trait_b)
	tv_a += _earths_touch_trait_bonus(char_a, trait_a)  # s34: +1 chosen Earth Trait
	tv_b += _earths_touch_trait_bonus(char_b, trait_b)
	if wp_a < 0:
		wp_a = mini(0, wp_a + adv_wound_a)
	if wp_b < 0:
		wp_b = mini(0, wp_b + adv_wound_b)

	# Elemental Imbalance overflow penalties (s45 lines 537-545)
	var is_social_a: bool = context_a.get("is_social", false)
	var is_social_b: bool = context_b.get("is_social", false)
	var imb_a: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(char_a, is_social_a, ic_day)
	var imb_b: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(char_b, is_social_b, ic_day)

	# s38 out-of-combat kiho buffs (Mind's Fire / Steal the Air Dragon), per side.
	var kiho_a: Dictionary = _get_kiho_buff_bonus(char_a, skill_a, trait_a, ic_day)
	var kiho_b: Dictionary = _get_kiho_buff_bonus(char_b, skill_b, trait_b, ic_day)

	# Void Point spend on this roll, per side (opt-in via context[_a/_b].spend_void; either
	# participant of a contested roll may spend, and s37 Altering the Course allows +NkN).
	var void_a: Dictionary = _get_void_spend_bonus(char_a, context_a, ic_day)
	var void_b: Dictionary = _get_void_spend_bonus(char_b, context_b, ic_day)

	# s33 Voice of the Wind: spoken-social buff, per side (court CHARM/NEGOTIATE/PERSUADE).
	var voice_a: Dictionary = _get_voice_of_the_wind_bonus(char_a, skill_a, context_a, ic_day)
	var voice_b: Dictionary = _get_voice_of_the_wind_bonus(char_b, skill_b, context_b, ic_day)

	# s34 Soul of Stone, per side: +3k0 resisting manipulation / -1k0 Awareness social influence.
	var soul_a: int = _get_soul_of_stone_bonus(char_a, skill_a, trait_a, context_a)
	var soul_b: int = _get_soul_of_stone_bonus(char_b, skill_b, trait_b, context_b)

	var roll_a: DiceResult = dice_engine.roll_and_keep(
		tv_a + sr_a + bonus_rolled_a + ashes_a + adv_a.get("rolled", 0) + imb_a.get("rolled", 0) + kiho_a.get("rolled", 0) + void_a.get("rolled", 0) + voice_a.get("rolled", 0) + soul_a,
		tv_a + adv_a.get("kept", 0) + imb_a.get("kept", 0) + kiho_a.get("kept", 0) + void_a.get("kept", 0) + voice_a.get("kept", 0), sr_a > 0, emph_a
	)
	var roll_b: DiceResult = dice_engine.roll_and_keep(
		tv_b + sr_b + bonus_rolled_b + ashes_b + adv_b.get("rolled", 0) + imb_b.get("rolled", 0) + kiho_b.get("rolled", 0) + void_b.get("rolled", 0) + voice_b.get("rolled", 0) + soul_b,
		tv_b + adv_b.get("kept", 0) + imb_b.get("kept", 0) + kiho_b.get("kept", 0) + void_b.get("kept", 0) + voice_b.get("kept", 0), sr_b > 0, emph_b
	)

	var total_a: int = roll_a.total + flat_bonus_a + wp_a + (tfr_a * FREE_RAISE_VALUE) \
		+ (adv_a.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn_a \
		+ _get_possession_terror_penalty(char_a)
	var total_b: int = roll_b.total + flat_bonus_b + wp_b + (tfr_b * FREE_RAISE_VALUE) \
		+ (adv_b.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn_b \
		+ _get_possession_terror_penalty(char_b)

	var winner: String = "a"
	if total_b > total_a:
		winner = "b"
	elif total_a == total_b:
		winner = "tie"

	return {
		"winner": winner,
		"total_a": total_a,
		"total_b": total_b,
		"dice_a": roll_a,
		"dice_b": roll_b,
		"wound_penalty_a": wp_a,
		"wound_penalty_b": wp_b,
	}
