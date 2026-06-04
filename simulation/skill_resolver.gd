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

	# Build the pool: (trait + skill + bonus_rolled) k (trait + bonus_kept)
	var rolled: int = (
		trait_value + skill_rank + bonus_rolled + ashes_bonus
		+ adv_skill.get("rolled", 0) + mutation_mod.get("rolled", 0)
		+ imbalance_mod.get("rolled", 0)
	)
	var kept: int = (
		trait_value + bonus_kept + adv_skill.get("kept", 0) + mutation_mod.get("kept", 0)
		+ imbalance_mod.get("kept", 0)
	)
	var total_bonus: int = flat_bonus + wound_penalty + (technique_fr * FREE_RAISE_VALUE) \
		+ (adv_skill.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn \
		+ mutation_mod.get("tn", 0)

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
	if wp_a < 0:
		wp_a = mini(0, wp_a + adv_wound_a)
	if wp_b < 0:
		wp_b = mini(0, wp_b + adv_wound_b)

	# Elemental Imbalance overflow penalties (s45 lines 537-545)
	var is_social_a: bool = context_a.get("is_social", false)
	var is_social_b: bool = context_b.get("is_social", false)
	var imb_a: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(char_a, is_social_a, ic_day)
	var imb_b: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(char_b, is_social_b, ic_day)

	var roll_a: DiceResult = dice_engine.roll_and_keep(
		tv_a + sr_a + bonus_rolled_a + ashes_a + adv_a.get("rolled", 0) + imb_a.get("rolled", 0),
		tv_a + adv_a.get("kept", 0) + imb_a.get("kept", 0), sr_a > 0, emph_a
	)
	var roll_b: DiceResult = dice_engine.roll_and_keep(
		tv_b + sr_b + bonus_rolled_b + ashes_b + adv_b.get("rolled", 0) + imb_b.get("rolled", 0),
		tv_b + adv_b.get("kept", 0) + imb_b.get("kept", 0), sr_b > 0, emph_b
	)

	var total_a: int = roll_a.total + flat_bonus_a + wp_a + (tfr_a * FREE_RAISE_VALUE) \
		+ (adv_a.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn_a
	var total_b: int = roll_b.total + flat_bonus_b + wp_b + (tfr_b * FREE_RAISE_VALUE) \
		+ (adv_b.get("free_raises", 0) * FREE_RAISE_VALUE) + adv_tn_b

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
