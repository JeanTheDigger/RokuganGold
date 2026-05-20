class_name NPCAdvancement
## NPC autonomous advancement per GDD s52 Part 3 and s48.
## NPCs accumulate XP daily based on role and activity, then spend it
## on progress bars following a fixed priority order toward their
## school's strengths.


# === XP CONVERSION ===

const XP_TO_PROGRESS: int = 200

# === SKILL PROGRESS COSTS (current_rank -> cost to reach next_rank) ===

const SKILL_PROGRESS_COST: Dictionary = {
	0: 1000,
	1: 2000,
	2: 3000,
	3: 4000,
	4: 5000,
}

# === RING PROGRESS COSTS (current_rank -> cost to reach next_rank) ===

const RING_PROGRESS_COST: Dictionary = {
	0: 4000,
	1: 8000,
	2: 12000,
	3: 16000,
	4: 20000,
}

# === BASE XP RATES PER OOC DAY BY ROLE (s52 Part 3) ===

const BASE_RATE_PEACETIME: float = 0.02
const BASE_RATE_ACTIVE_DUTY: float = 0.04
const BASE_RATE_GUNSO: float = 0.05
const BASE_RATE_CHUI: float = 0.06
const BASE_RATE_TAISA: float = 0.08
const BASE_RATE_SHIREIKAN: float = 0.10
const BASE_RATE_ACTIVE_COURTIER: float = 0.05
const BASE_RATE_MAGISTRATE: float = 0.06
const BASE_RATE_SENSEI: float = 0.04
const BASE_RATE_TEMPLE_HEAD: float = 0.05

# === ACTIVITY MULTIPLIERS (s52 Part 3) ===

const MULTIPLIER_PEACETIME: float = 1.0
const MULTIPLIER_BORDER_PATROL: float = 1.5
const MULTIPLIER_BATTLE: float = 2.5
const MULTIPLIER_COMMANDING_BATTLE: float = 3.0
const MULTIPLIER_COURT_SEASON: float = 1.5
const MULTIPLIER_SIEGE: float = 2.0
const MULTIPLIER_MAJOR_CRISIS: float = 2.0

const MAX_SKILL_RANK: int = 5
const MAX_RING_RANK: int = 5
const IC_DAYS_PER_OOC_DAY: int = 4


static func get_base_xp_rate(character: L5RCharacterData) -> float:
	if character.military_rank == Enums.MilitaryRank.RIKUGUNSHOKAN:
		return BASE_RATE_SHIREIKAN
	if character.military_rank == Enums.MilitaryRank.SHIREIKAN:
		return BASE_RATE_SHIREIKAN
	if character.military_rank == Enums.MilitaryRank.TAISA:
		return BASE_RATE_TAISA
	if character.military_rank == Enums.MilitaryRank.CHUI:
		return BASE_RATE_CHUI
	if character.military_rank == Enums.MilitaryRank.GUNSO:
		return BASE_RATE_GUNSO

	var pos: String = character.role_position
	if pos == "School Master":
		return BASE_RATE_SENSEI
	if pos == "Temple Head" or pos == "Monastery Abbot":
		return BASE_RATE_TEMPLE_HEAD
	if pos == "Clan Magistrate" or pos == "Emerald Magistrate":
		return BASE_RATE_MAGISTRATE

	if character.school_type == Enums.SchoolType.COURTIER:
		return BASE_RATE_ACTIVE_COURTIER
	if character.school_type == Enums.SchoolType.SHUGENJA:
		return BASE_RATE_TEMPLE_HEAD

	if character.assigned_company_id >= 0:
		return BASE_RATE_ACTIVE_DUTY

	return BASE_RATE_PEACETIME


static func get_activity_multiplier(character: L5RCharacterData, world_state: Dictionary) -> float:
	var multiplier: float = MULTIPLIER_PEACETIME

	var in_battle: bool = world_state.get("in_battle_ids", []).has(character.character_id)
	if in_battle:
		if character.military_rank >= Enums.MilitaryRank.CHUI and character.commanded_unit_id >= 0:
			return MULTIPLIER_COMMANDING_BATTLE
		return MULTIPLIER_BATTLE

	var in_siege: bool = world_state.get("in_siege_ids", []).has(character.character_id)
	if in_siege:
		return MULTIPLIER_SIEGE

	var in_crisis: bool = world_state.get("in_crisis_ids", []).has(character.character_id)
	if in_crisis:
		multiplier = maxf(multiplier, MULTIPLIER_MAJOR_CRISIS)

	var in_court: bool = world_state.get("in_court_ids", []).has(character.character_id)
	if in_court and character.school_type == Enums.SchoolType.COURTIER:
		multiplier = maxf(multiplier, MULTIPLIER_COURT_SEASON)

	if character.assigned_company_id >= 0 and multiplier < MULTIPLIER_BORDER_PATROL:
		multiplier = MULTIPLIER_BORDER_PATROL

	return multiplier


static func compute_daily_xp(character: L5RCharacterData, world_state: Dictionary) -> float:
	var base: float = get_base_xp_rate(character)
	var mult: float = get_activity_multiplier(character, world_state)
	return base * mult


static func accumulate_daily_xp(character: L5RCharacterData, world_state: Dictionary) -> float:
	var xp_per_ooc_day: float = compute_daily_xp(character, world_state)
	var xp: float = xp_per_ooc_day / float(IC_DAYS_PER_OOC_DAY)
	character.xp_fractional += xp
	var whole: int = int(character.xp_fractional)
	if whole > 0:
		character.xp_total += whole
		character.xp_fractional -= float(whole)
	return xp


# === PROGRESS BAR KEY HELPERS ===

static func _ring_key(ring: Enums.Ring) -> String:
	match ring:
		Enums.Ring.AIR: return "ring_air"
		Enums.Ring.EARTH: return "ring_earth"
		Enums.Ring.FIRE: return "ring_fire"
		Enums.Ring.WATER: return "ring_water"
		Enums.Ring.VOID: return "ring_void"
	return "ring_void"


static func _skill_key(skill_name: String) -> String:
	return "skill_" + skill_name


# === RING VALUE HELPERS ===

static func _get_ring_rank(character: L5RCharacterData, ring: Enums.Ring) -> int:
	return CharacterStats.get_ring_value(character, ring)


static func _raise_ring(character: L5RCharacterData, ring: Enums.Ring) -> void:
	if ring == Enums.Ring.VOID:
		character.void_ring += 1
		character.max_void_points = character.void_ring
		return
	var traits: Array[int] = Enums.RING_TRAITS[ring]
	var t1_val: int = character.get_trait_value(traits[0])
	var t2_val: int = character.get_trait_value(traits[1])
	if t1_val <= t2_val:
		character.set_trait_value(traits[0], t1_val + 1)
	else:
		character.set_trait_value(traits[1], t2_val + 1)


# === SCHOOL DATA LOOKUPS ===

static func get_school_skills(character: L5RCharacterData) -> Array[String]:
	var school_data: Dictionary = WorldGenerator.SCHOOL_DATA.get(character.school, {})
	if school_data.is_empty():
		return []
	var skills: Array[String] = []
	for s: String in school_data.get("skills", []):
		skills.append(s)
	return skills


static func get_focus_rings(character: L5RCharacterData) -> Array[int]:
	var school_data: Dictionary = WorldGenerator.SCHOOL_DATA.get(character.school, {})
	if school_data.is_empty():
		return []
	return school_data.get("focus_rings", [])


# === PROGRESS BAR ACCESS ===

static func _get_progress(character: L5RCharacterData, key: String) -> int:
	return character.progress_bars.get(key, 0)


static func _set_progress(character: L5RCharacterData, key: String, value: int) -> void:
	character.progress_bars[key] = value


# === XP SPENDING ON INDIVIDUAL TARGETS ===

static func _try_spend_on_ring(character: L5RCharacterData, ring: Enums.Ring, available_progress: int) -> Dictionary:
	var current_rank: int = _get_ring_rank(character, ring)
	if current_rank >= MAX_RING_RANK:
		return {"spent": 0, "advanced": false}

	var cost: int = RING_PROGRESS_COST.get(current_rank, 0)
	if cost <= 0:
		return {"spent": 0, "advanced": false}

	var key: String = _ring_key(ring)
	var current_progress: int = _get_progress(character, key)
	var remaining: int = cost - current_progress

	var to_spend: int = mini(available_progress, remaining)
	_set_progress(character, key, current_progress + to_spend)

	var advanced: bool = false
	if current_progress + to_spend >= cost:
		_raise_ring(character, ring)
		_set_progress(character, key, 0)
		advanced = true

	return {"spent": to_spend, "advanced": advanced}


static func _try_spend_on_skill(character: L5RCharacterData, skill_name: String, available_progress: int) -> Dictionary:
	var current_rank: int = character.skills.get(skill_name, 0)
	if current_rank >= MAX_SKILL_RANK:
		return {"spent": 0, "advanced": false}

	var cost: int = SKILL_PROGRESS_COST.get(current_rank, 0)
	if cost <= 0:
		return {"spent": 0, "advanced": false}

	var key: String = _skill_key(skill_name)
	var current_progress: int = _get_progress(character, key)
	var remaining: int = cost - current_progress

	var to_spend: int = mini(available_progress, remaining)
	_set_progress(character, key, current_progress + to_spend)

	var advanced: bool = false
	if current_progress + to_spend >= cost:
		character.skills[skill_name] = current_rank + 1
		_set_progress(character, key, 0)
		advanced = true

	return {"spent": to_spend, "advanced": advanced}


# === MAIN XP SPENDING PRIORITY (s52 Part 3) ===

static func spend_accumulated_xp(character: L5RCharacterData) -> Dictionary:
	var available_xp: int = character.xp_total - character.xp_spent
	if available_xp <= 0:
		return {"xp_spent": 0, "advancements": []}

	var available_progress: int = available_xp * XP_TO_PROGRESS
	var total_spent_progress: int = 0
	var advancements: Array[Dictionary] = []

	var focus_rings: Array[int] = get_focus_rings(character)
	var school_skills: Array[String] = get_school_skills(character)
	var is_shugenja: bool = character.school_type == Enums.SchoolType.SHUGENJA

	# Priority 1: Primary Ring (first focus ring)
	if focus_rings.size() > 0:
		var result: Dictionary = _try_spend_on_ring(character, focus_rings[0], available_progress - total_spent_progress)
		total_spent_progress += result["spent"]
		if result["advanced"]:
			advancements.append({"type": "ring", "ring": focus_rings[0], "priority": 1})

	# Priority 2: Highest-ranked school skill (the specialty)
	if total_spent_progress < available_progress and school_skills.size() > 0:
		var best_skill: String = _get_highest_ranked_skill(character, school_skills)
		if best_skill != "":
			var result: Dictionary = _try_spend_on_skill(character, best_skill, available_progress - total_spent_progress)
			total_spent_progress += result["spent"]
			if result["advanced"]:
				advancements.append({"type": "skill", "skill": best_skill, "priority": 2})

	# Priority 3: Other school skills in descending rank order
	if total_spent_progress < available_progress and school_skills.size() > 1:
		var best_skill: String = _get_highest_ranked_skill(character, school_skills)
		var sorted_skills: Array[String] = _sort_skills_by_rank_desc(character, school_skills)
		for skill: String in sorted_skills:
			if skill == best_skill:
				continue
			if total_spent_progress >= available_progress:
				break
			var result: Dictionary = _try_spend_on_skill(character, skill, available_progress - total_spent_progress)
			total_spent_progress += result["spent"]
			if result["advanced"]:
				advancements.append({"type": "skill", "skill": skill, "priority": 3})

	# Priority 4: Secondary Ring (second focus ring)
	if total_spent_progress < available_progress and focus_rings.size() > 1:
		var result: Dictionary = _try_spend_on_ring(character, focus_rings[1], available_progress - total_spent_progress)
		total_spent_progress += result["spent"]
		if result["advanced"]:
			advancements.append({"type": "ring", "ring": focus_rings[1], "priority": 4})

	# Priority 4b: Void Ring for shugenja only
	if total_spent_progress < available_progress and is_shugenja:
		var result: Dictionary = _try_spend_on_ring(character, Enums.Ring.VOID, available_progress - total_spent_progress)
		total_spent_progress += result["spent"]
		if result["advanced"]:
			advancements.append({"type": "ring", "ring": Enums.Ring.VOID, "priority": 4})

	# Convert progress spent back to XP consumed (ceiling division)
	@warning_ignore("integer_division")
	var xp_consumed: int = total_spent_progress / XP_TO_PROGRESS
	if total_spent_progress % XP_TO_PROGRESS > 0:
		xp_consumed += 1

	character.xp_spent += xp_consumed

	# Priority 5: Remaining XP held in reserve (not spent)

	return {"xp_spent": xp_consumed, "advancements": advancements}


# === SKILL SORTING HELPERS ===

static func _get_highest_ranked_skill(character: L5RCharacterData, skill_list: Array[String]) -> String:
	var best_skill: String = ""
	var best_rank: int = -1
	for skill: String in skill_list:
		var rank: int = character.skills.get(skill, 0)
		if rank > best_rank:
			best_rank = rank
			best_skill = skill
	return best_skill


static func _sort_skills_by_rank_desc(character: L5RCharacterData, skill_list: Array[String]) -> Array[String]:
	var pairs: Array[Dictionary] = []
	for skill: String in skill_list:
		pairs.append({"skill": skill, "rank": character.skills.get(skill, 0)})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] > b["rank"])
	var result: Array[String] = []
	for p: Dictionary in pairs:
		result.append(p["skill"])
	return result


# === SEASONAL BATCH PROCESSING ===

static func process_seasonal_advancement(characters: Array[L5RCharacterData], world_state: Dictionary, days_in_season: int) -> Dictionary:
	var results: Array[Dictionary] = []
	var total_rank_advancements: int = 0

	for character: L5RCharacterData in characters:
		if CharacterStats.is_dead(character):
			continue

		var old_rank: int = CharacterStats.get_insight_rank(character)

		# Accumulate XP for all OOC days in the season (rates are per OOC day)
		var daily_xp: float = compute_daily_xp(character, world_state)
		@warning_ignore("integer_division")
		var ooc_days: int = days_in_season / IC_DAYS_PER_OOC_DAY
		var season_xp: float = daily_xp * float(ooc_days)
		character.xp_fractional += season_xp
		var whole: int = int(character.xp_fractional)
		if whole > 0:
			character.xp_total += whole
			character.xp_fractional -= float(whole)

		# Spend accumulated XP on progress bars
		var spend_result: Dictionary = spend_accumulated_xp(character)

		var new_rank: int = CharacterStats.get_insight_rank(character)
		var ranked_up: bool = new_rank > old_rank

		if ranked_up or spend_result["advancements"].size() > 0:
			var entry: Dictionary = {
				"character_id": character.character_id,
				"xp_earned_season": season_xp,
				"xp_spent": spend_result["xp_spent"],
				"advancements": spend_result["advancements"],
				"ranked_up": ranked_up,
			}
			if ranked_up:
				entry["old_rank"] = old_rank
				entry["new_rank"] = new_rank
				total_rank_advancements += 1
				SkillResolver.apply_technique_flags(character)
			results.append(entry)

	return {"results": results, "total_rank_advancements": total_rank_advancements}
