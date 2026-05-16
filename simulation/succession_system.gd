class_name SuccessionSystem

# -- Succession Order Constants ------------------------------------------------

enum CandidatePriority {
	DESIGNATED_HEIR = 1,
	ELDEST_CHILD = 2,
	OTHER_CHILD = 3,
	ADOPTED_HEIR = 4,
	SIBLING = 5,
	LORD_SELECTS = 6,
	GENERATED = 7,
}

# -- Transition Timing ---------------------------------------------------------

const CLEAN_SUCCESSION_MIN_TICKS: int = 7
const CLEAN_SUCCESSION_MAX_TICKS: int = 14
const DISPUTED_MAX_TICKS: int = 60

# -- Heir Evaluation Base Weights (9 factors) ----------------------------------

const BASE_WEIGHTS: Dictionary = {
	"disposition": 15,
	"birth_order": 12,
	"honor": 10,
	"glory": 8,
	"insight_rank": 10,
	"school_type": 8,
	"skills": 7,
	"achievements": 10,
	"titles": 5,
}

# -- Bushido Virtue Weight Multipliers -----------------------------------------

const BUSHIDO_WEIGHT_MODS: Dictionary = {
	Enums.BushidoVirtue.JIN: {"disposition": 1.5, "honor": 1.3, "glory": 0.7, "achievements": 0.7},
	Enums.BushidoVirtue.YU: {"achievements": 1.8, "glory": 1.3, "disposition": 0.7, "birth_order": 0.7},
	Enums.BushidoVirtue.REI: {"birth_order": 1.5, "school_type": 1.3, "disposition": 1.2, "achievements": 0.8},
	Enums.BushidoVirtue.CHUGI: {"disposition": 1.5, "insight_rank": 1.3, "birth_order": 1.2},
	Enums.BushidoVirtue.GI: {"honor": 2.0, "achievements": 0.8, "disposition": 0.8},
	Enums.BushidoVirtue.MEIYO: {"honor": 1.8, "glory": 1.2, "skills": 1.2, "disposition": 0.8},
	Enums.BushidoVirtue.MAKOTO: {"disposition": 1.3, "honor": 1.3, "achievements": 1.2, "glory": 0.7},
}

# -- Shourido Virtue Weight Multipliers ----------------------------------------

const SHOURIDO_WEIGHT_MODS: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: {"disposition": 1.8, "insight_rank": 0.8, "achievements": 0.7},
	Enums.ShouridoVirtue.KETSUI: {"achievements": 1.5, "insight_rank": 1.3, "birth_order": 0.7},
	Enums.ShouridoVirtue.DOSATSU: {"skills": 1.5, "insight_rank": 1.3, "school_type": 1.3, "achievements": 1.2},
	Enums.ShouridoVirtue.CHISHIKI: {"skills": 1.8, "insight_rank": 1.3, "school_type": 1.2},
	Enums.ShouridoVirtue.KANPEKI: {"honor": 1.3, "glory": 1.3, "skills": 1.3, "insight_rank": 1.3, "achievements": 1.2},
	Enums.ShouridoVirtue.KYORYOKU: {"achievements": 1.8, "glory": 1.5, "skills": 1.2, "birth_order": 0.5},
	Enums.ShouridoVirtue.ISHI: {"birth_order": 2.0, "disposition": 1.3},
}

const ISHI_OTHER_FACTOR_MOD: float = 0.8

# -- Confirmation Authority Tier Map -------------------------------------------

const CONFIRMING_TIER: Dictionary = {
	Enums.LordRank.VILLAGE_HEADMAN: Enums.LordRank.PROVINCIAL_DAIMYO,
	Enums.LordRank.CITY_DAIMYO: Enums.LordRank.PROVINCIAL_DAIMYO,
	Enums.LordRank.PROVINCIAL_DAIMYO: Enums.LordRank.FAMILY_DAIMYO,
	Enums.LordRank.FAMILY_DAIMYO: Enums.LordRank.CLAN_CHAMPION,
	Enums.LordRank.CLAN_CHAMPION: Enums.LordRank.IMPERIAL,
}

# -- Province Dominant Demand Types --------------------------------------------

const MILITARY_TERRAINS: Array[String] = ["border", "wall", "frontier"]
const SPIRITUAL_TERRAINS: Array[String] = ["sacred", "temple", "shrine"]

# -- Achievement Topic Types ---------------------------------------------------

const BATTLE_COMMANDER_TYPES: Array[String] = ["battle_commander_victory"]
const BATTLE_PARTICIPANT_TYPES: Array[String] = ["battle_victory", "battle_outcome"]
const DUEL_TYPES: Array[String] = ["duel_victory", "duel_honorable"]
const PROMOTION_TYPES: Array[String] = ["promotion", "appointment"]
const OBJECTIVE_TYPES: Array[String] = ["objective_completed"]
const DISGRACE_TYPES: Array[String] = ["disgrace", "defeat", "battle_defeat"]
const BETRAYAL_TYPES: Array[String] = ["betrayal"]


# ==============================================================================
# Succession Trigger
# ==============================================================================

static func trigger_succession(
	deceased: L5RCharacterData,
	cause: SuccessionData.VacancyCause,
	position_tier: Enums.LordRank,
	current_tick: int,
	suspicious: bool = false,
) -> SuccessionData:
	var data := SuccessionData.new()
	data.deceased_id = deceased.character_id
	data.position_tier = position_tier
	data.clan = deceased.clan
	data.family = deceased.family
	data.cause = cause
	data.start_tick = current_tick
	data.designated_heir_id = deceased.designated_heir_id
	data.suspicious_death = suspicious
	data.settlement_id = deceased.physical_location
	return data


# ==============================================================================
# Candidate Gathering (7 Priorities)
# ==============================================================================

static func get_candidates(
	deceased: L5RCharacterData,
	chars_by_id: Dictionary,
	position_clan: String = "",
) -> Array[Dictionary]:
	var clan: String = position_clan if position_clan != "" else deceased.clan
	var candidates: Array[Dictionary] = []

	# Priority 1 — Designated Heir
	if deceased.designated_heir_id >= 0:
		var heir: L5RCharacterData = chars_by_id.get(deceased.designated_heir_id)
		if heir != null and not _is_dead(heir):
			candidates.append({"id": heir.character_id, "priority": CandidatePriority.DESIGNATED_HEIR, "character": heir})

	# Priority 2 & 3 — Biological Children (eldest first)
	var children: Array[Dictionary] = []
	for cid in deceased.children_ids:
		var child: L5RCharacterData = chars_by_id.get(cid)
		if child != null and not _is_dead(child) and child.clan == clan:
			children.append({"id": child.character_id, "age": child.age, "character": child})

	children.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["age"] > b["age"])

	for i in range(children.size()):
		var pri: int = CandidatePriority.ELDEST_CHILD if i == 0 else CandidatePriority.OTHER_CHILD
		var already: bool = false
		for c in candidates:
			if c["id"] == children[i]["id"]:
				already = true
				break
		if not already:
			candidates.append({"id": children[i]["id"], "priority": pri, "character": children[i]["character"]})

	# Priority 4 — Adopted Heirs
	for aid in deceased.adopted_children_ids:
		var adopted: L5RCharacterData = chars_by_id.get(aid)
		if adopted == null or _is_dead(adopted) or adopted.clan != clan:
			continue
		var already: bool = false
		for c in candidates:
			if c["id"] == adopted.character_id:
				already = true
				break
		if not already:
			candidates.append({"id": adopted.character_id, "priority": CandidatePriority.ADOPTED_HEIR, "character": adopted})

	# Priority 5 — Siblings
	for sid in deceased.sibling_ids:
		var sib: L5RCharacterData = chars_by_id.get(sid)
		if sib != null and not _is_dead(sib) and sib.family == deceased.family:
			var already: bool = false
			for c in candidates:
				if c["id"] == sib.character_id:
					already = true
					break
			if not already:
				candidates.append({"id": sib.character_id, "priority": CandidatePriority.SIBLING, "character": sib})

	return candidates


# ==============================================================================
# Confirmation Authority
# ==============================================================================

static func get_confirming_authority_tier(position_tier: Enums.LordRank) -> Enums.LordRank:
	return CONFIRMING_TIER.get(position_tier, Enums.LordRank.IMPERIAL)


static func find_confirming_authority(
	position_tier: Enums.LordRank,
	clan: String,
	chars_by_id: Dictionary,
) -> int:
	var target_tier: Enums.LordRank = get_confirming_authority_tier(position_tier)

	var best_id: int = -1
	var best_status: float = -1.0
	for id in chars_by_id:
		var c: L5RCharacterData = chars_by_id[id]
		if _is_dead(c):
			continue
		if target_tier == Enums.LordRank.IMPERIAL:
			if c.status >= 8.0 and (c.role_position == "emperor" or c.clan == "Imperial"):
				if c.status > best_status:
					best_status = c.status
					best_id = c.character_id
		else:
			if c.clan == clan and c.status >= _min_status_for_tier(target_tier):
				if c.status > best_status:
					best_status = c.status
					best_id = c.character_id

	return best_id


# ==============================================================================
# Clean vs. Disputed
# ==============================================================================

static func is_clean_succession(
	succession: SuccessionData,
	candidates: Array[Dictionary],
	confirming_disp_toward_top: int,
) -> bool:
	if succession.suspicious_death:
		return false
	if succession.contesting_ids.size() > 0:
		return false

	if candidates.size() == 0:
		return false

	var top_priority: int = candidates[0]["priority"]
	var same_priority_count: int = 0
	for c in candidates:
		if c["priority"] == top_priority:
			same_priority_count += 1

	if same_priority_count > 1 and top_priority != CandidatePriority.DESIGNATED_HEIR:
		return false

	if confirming_disp_toward_top < 11:
		return false

	return true


static func get_transition_duration(is_clean: bool, confirming_disp: int) -> int:
	if is_clean:
		if confirming_disp >= 31:
			return CLEAN_SUCCESSION_MIN_TICKS
		return CLEAN_SUCCESSION_MAX_TICKS
	return DISPUTED_MAX_TICKS


# ==============================================================================
# Heir Evaluation (9-factor scoring)
# ==============================================================================

static func compute_personality_weights(
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue,
) -> Dictionary:
	var weights: Dictionary = BASE_WEIGHTS.duplicate()

	if bushido != Enums.BushidoVirtue.NONE and BUSHIDO_WEIGHT_MODS.has(bushido):
		var mods: Dictionary = BUSHIDO_WEIGHT_MODS[bushido]
		for key in mods:
			if weights.has(key):
				weights[key] = int(float(weights[key]) * mods[key])

	if shourido != Enums.ShouridoVirtue.NONE and SHOURIDO_WEIGHT_MODS.has(shourido):
		var mods: Dictionary = SHOURIDO_WEIGHT_MODS[shourido]
		for key in mods:
			if weights.has(key):
				weights[key] = int(float(weights[key]) * mods[key])
		if shourido == Enums.ShouridoVirtue.ISHI:
			for key in weights:
				if not mods.has(key):
					weights[key] = int(float(weights[key]) * ISHI_OTHER_FACTOR_MOD)

	return weights


static func evaluate_candidate(
	lord: L5RCharacterData,
	candidate: L5RCharacterData,
	priority: int,
	weights: Dictionary,
	position_demand: String = "military",
	topics_about_candidate: Array[Dictionary] = [],
) -> Dictionary:
	var scores: Dictionary = {}

	# Factor 1 — Disposition
	var disp: int = lord.disposition_values.get(candidate.character_id, 0)
	scores["disposition"] = _score_disposition(disp)

	# Factor 2 — Birth Order
	scores["birth_order"] = _score_birth_order(priority)

	# Factor 3 — Honor Rank
	scores["honor"] = _score_honor(candidate.honor)

	# Factor 4 — Glory Rank
	scores["glory"] = _score_glory(candidate.glory)

	# Factor 5 — Insight Rank
	var insight_rank: int = CharacterStats.get_insight_rank(candidate)
	scores["insight_rank"] = _score_insight_rank(insight_rank)

	# Factor 6 — School Type Relevance
	scores["school_type"] = _score_school_type(candidate.school_type, position_demand)

	# Factor 7 — Relevant Skill Ranks
	scores["skills"] = _score_skills(candidate, position_demand)

	# Factor 8 — Known Achievements
	scores["achievements"] = _score_achievements(topics_about_candidate)

	# Factor 9 — Titles and Positions
	scores["titles"] = _score_titles(candidate.status)

	var total: float = 0.0
	for key in scores:
		var w: int = weights.get(key, 0)
		total += float(scores[key]) * float(w) / float(BASE_WEIGHTS.get(key, 1))

	return {"scores": scores, "total": total, "candidate_id": candidate.character_id}


static func evaluate_all_candidates(
	lord: L5RCharacterData,
	candidates: Array[Dictionary],
	position_demand: String = "military",
	topics_by_character: Dictionary = {},
) -> Array[Dictionary]:
	var weights: Dictionary = compute_personality_weights(lord.bushido_virtue, lord.shourido_virtue)
	var results: Array[Dictionary] = []

	for c in candidates:
		var candidate_char: L5RCharacterData = c.get("character")
		if candidate_char == null:
			continue
		var topics: Array[Dictionary] = topics_by_character.get(c["id"], [])
		var result: Dictionary = evaluate_candidate(lord, candidate_char, c["priority"], weights, position_demand, topics)
		results.append(result)

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["total"] > b["total"])
	return results


# ==============================================================================
# Confirm Successor
# ==============================================================================

static func confirm_successor(
	succession: SuccessionData,
	successor_id: int,
) -> Dictionary:
	succession.successor_id = successor_id
	succession.state = SuccessionData.SuccessionState.CONFIRMED
	return {
		"succession_id": succession.succession_id,
		"successor_id": successor_id,
		"position_tier": succession.position_tier,
		"clan": succession.clan,
		"family": succession.family,
		"ticks_elapsed": succession.ticks_elapsed,
	}


# ==============================================================================
# Transition Effects
# ==============================================================================

static func get_transition_effects(succession: SuccessionData) -> Dictionary:
	return {
		"tax_cascade_suspended": true,
		"koku_flow_suspended": true,
		"stockpile_frozen": true,
		"settlement_id": succession.settlement_id,
		"position_tier": succession.position_tier,
	}


static func apply_successor_inheritance(
	successor: L5RCharacterData,
	deceased: L5RCharacterData,
) -> Dictionary:
	var inherited_favors: int = 0
	var remaining_favors: Array[FavorData] = []
	for favor in deceased.favors:
		if favor.tier == FavorData.FavorTier.MAJOR:
			favor.heir_id = successor.character_id
			successor.favors.append(favor)
			inherited_favors += 1
		else:
			remaining_favors.append(favor)
	deceased.favors = remaining_favors

	return {"inherited_major_favors": inherited_favors}


# ==============================================================================
# Dispute
# ==============================================================================

static func contest_succession(
	succession: SuccessionData,
	contester_id: int,
) -> void:
	if not succession.contesting_ids.has(contester_id):
		succession.contesting_ids.append(contester_id)
	succession.state = SuccessionData.SuccessionState.DISPUTED


static func process_tick(
	succession: SuccessionData,
	max_duration: int,
) -> Dictionary:
	succession.ticks_elapsed += 1
	var result: Dictionary = {"expired": false, "ticks_elapsed": succession.ticks_elapsed}
	if succession.ticks_elapsed >= max_duration and succession.state != SuccessionData.SuccessionState.CONFIRMED:
		result["expired"] = true
	return result


# ==============================================================================
# Heir Designation (NPC action, 1 AP)
# ==============================================================================

static func designate_heir(
	lord: L5RCharacterData,
	heir_id: int,
) -> void:
	lord.designated_heir_id = heir_id


static func should_reevaluate_heir(
	lord: L5RCharacterData,
	trigger_changes: Dictionary = {},
) -> bool:
	if lord.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		if lord.designated_heir_id >= 0:
			var heir_dead: bool = trigger_changes.get("heir_dead", false)
			var objective_change: bool = trigger_changes.get("standing_objective_changed", false)
			return heir_dead or objective_change
		return true

	if lord.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return true

	if trigger_changes.get("new_candidate_gempuku", false):
		return true
	if trigger_changes.get("honor_glory_insight_changed", false):
		return true
	if trigger_changes.get("disposition_threshold_crossed", false):
		return true
	if trigger_changes.get("achievement_topic_gained", false):
		return true
	if trigger_changes.get("heir_dead", false):
		return true
	if trigger_changes.get("heir_disgraced", false):
		return true
	if trigger_changes.get("marriage_new_child", false):
		return true

	return lord.designated_heir_id < 0


static func get_designation_urgency(lord: L5RCharacterData) -> int:
	if lord.designated_heir_id >= 0:
		return 0
	if lord.age >= 40:
		return 2
	var has_blood_enemy: bool = false
	for disp in lord.disposition_values.values():
		if disp <= -60:
			has_blood_enemy = true
			break
	if has_blood_enemy:
		return 2
	return 1


# ==============================================================================
# Emperor Succession (Special Case)
# ==============================================================================

static func is_emperor_succession(position_tier: Enums.LordRank) -> bool:
	return position_tier == Enums.LordRank.IMPERIAL


static func evaluate_emperor_succession(
	deceased_emperor: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Dictionary:
	if deceased_emperor.designated_heir_id >= 0:
		var heir: L5RCharacterData = chars_by_id.get(deceased_emperor.designated_heir_id)
		if heir != null and not _is_dead(heir):
			return {"successor_id": heir.character_id, "crisis": false, "method": "designated_heir"}

	var eldest_child_id: int = -1
	var eldest_age: int = -1
	for cid in deceased_emperor.children_ids:
		var child: L5RCharacterData = chars_by_id.get(cid)
		if child != null and not _is_dead(child) and child.age > eldest_age:
			eldest_age = child.age
			eldest_child_id = child.character_id

	if eldest_child_id >= 0:
		return {"successor_id": eldest_child_id, "crisis": false, "method": "eldest_child"}

	return {"successor_id": -1, "crisis": true, "method": "no_viable_candidate"}


# ==============================================================================
# Topic Generation
# ==============================================================================

static func generate_succession_topic(
	succession: SuccessionData,
	is_disputed: bool,
) -> Dictionary:
	var tier: int = 4 if not is_disputed else 2
	var momentum: float = 10.0 if not is_disputed else 50.0
	var category: String = "POLITICAL"
	var slug: String = "succession_%s_%s" % [succession.clan, str(succession.succession_id)]

	return {
		"tier": tier,
		"momentum": momentum,
		"category": category,
		"slug": slug,
		"subject_ids": [succession.deceased_id],
		"variant": "disputed" if is_disputed else "clean",
	}


# ==============================================================================
# Clan Exception Checks
# ==============================================================================

static func is_phoenix_champion_succession(clan: String, position_tier: Enums.LordRank) -> bool:
	return clan == "Phoenix" and position_tier == Enums.LordRank.CLAN_CHAMPION


static func is_dragon_togashi_removal(clan: String, position_tier: Enums.LordRank) -> bool:
	return clan == "Dragon" and position_tier == Enums.LordRank.CLAN_CHAMPION


# ==============================================================================
# Dragon Exception — Togashi Formal Removal (s22.5 cross-ref, s55.10.2.6)
# ==============================================================================

## Builds a SuccessionData for a Mirumoto FC removed by Togashi at Stage 4.
## Cause is REMOVAL. The confirming authority is Togashi (Dragon Clan Champion)
## which is the standard path for Family Daimyo succession — no special override
## is needed. The key difference from a natural vacancy is that Togashi confirms
## immediately (duration = CLEAN_SUCCESSION_MIN_TICKS) since he is both remover
## and confirmer with no political opposition to his own decision.
##
## Returns a Dictionary:
##   succession      : SuccessionData  — ready for candidate evaluation
##   confirming_id   : int             — Togashi's character_id (-1 if not found)
##   immediate       : bool            — always true (Togashi self-confirms)
static func resolve_dragon_togashi_removal(
	mirumoto_fc: L5RCharacterData,
	current_tick: int,
	chars_by_id: Dictionary,
) -> Dictionary:
	var data: SuccessionData = trigger_succession(
		mirumoto_fc,
		SuccessionData.VacancyCause.REMOVAL,
		Enums.LordRank.FAMILY_DAIMYO,
		current_tick,
		false,
	)
	var togashi_id: int = find_confirming_authority(
		Enums.LordRank.FAMILY_DAIMYO, "Dragon", chars_by_id
	)
	return {
		"succession":    data,
		"confirming_id": togashi_id,
		"immediate":     true,
	}


# ==============================================================================
# Phoenix Exception — Shiba Reincarnation (s55.10.3.8)
# ==============================================================================

## Resolves Shiba Champion succession through divine reincarnation.
## Bypasses standard succession order and Emperor confirmation entirely.
## A randomly selected living, non-captive Shiba character becomes Champion.
##
## Parameters:
##   chars_by_id  — full character roster
##   rng          — caller-owned RandomNumberGenerator (seeded or not)
##
## Returns a Dictionary:
##   new_champion_id           : int   — the reincarnated Champion's character_id
##                                       (-1 if no eligible Shiba exist)
##   void_master_id            : int   — Void Master character_id for confirmation
##                                       (-1 if no living Void Master)
##   bypasses_emperor_confirmation : bool — always true
##   previous_position_vacated : bool  — true if the new Champion held a position
##   previous_position_tier    : Enums.LordRank — only valid if above is true
##   topic                     : Dictionary — reincarnation topic to generate
static func resolve_shiba_reincarnation(
	chars_by_id: Dictionary,
	rng: RandomNumberGenerator,
) -> Dictionary:
	# Gather all living, non-captive Shiba characters
	var eligible: Array[L5RCharacterData] = []
	for c: L5RCharacterData in chars_by_id.values():
		if c.family != "Shiba":
			continue
		if _is_dead(c):
			continue
		if c.captive_status != "":
			continue
		eligible.append(c)

	if eligible.is_empty():
		return {
			"new_champion_id":               -1,
			"void_master_id":                _find_void_master_id(chars_by_id),
			"bypasses_emperor_confirmation": true,
			"previous_position_vacated":     false,
			"previous_position_tier":        Enums.LordRank.VILLAGE_HEADMAN,
			"topic":                         {},
		}

	# True random selection per GDD s55.10.3.8 — no weighting
	var selected: L5RCharacterData = eligible[rng.randi_range(0, eligible.size() - 1)]

	var had_position: bool = selected.status >= _min_status_for_tier(Enums.LordRank.CITY_DAIMYO)
	var prev_tier: Enums.LordRank = _estimate_lord_rank(selected.status)

	return {
		"new_champion_id":               selected.character_id,
		"void_master_id":                _find_void_master_id(chars_by_id),
		"bypasses_emperor_confirmation": true,
		"previous_position_vacated":     had_position,
		"previous_position_tier":        prev_tier,
		"topic": {
			"tier":        3,
			"momentum":    40.0,
			"category":    "SPIRITUAL",
			"slug":        "shiba_reincarnation_%d" % selected.character_id,
			"subject_ids": [selected.character_id],
			"variant":     "reincarnation",
		},
	}


static func _find_void_master_id(chars_by_id: Dictionary) -> int:
	for c: L5RCharacterData in chars_by_id.values():
		if c.clan == "Phoenix" and c.role_position == "Master of Void" and not _is_dead(c):
			return c.character_id
	return -1


static func _estimate_lord_rank(status: float) -> Enums.LordRank:
	if status >= 8.0:
		return Enums.LordRank.IMPERIAL
	if status >= 6.0:
		return Enums.LordRank.CLAN_CHAMPION
	if status >= 5.0:
		return Enums.LordRank.FAMILY_DAIMYO
	if status >= 4.0:
		return Enums.LordRank.PROVINCIAL_DAIMYO
	return Enums.LordRank.CITY_DAIMYO


# ==============================================================================
# Private Helpers
# ==============================================================================

static func _is_dead(c: L5RCharacterData) -> bool:
	return CharacterStats.is_dead(c)


static func _min_status_for_tier(tier: Enums.LordRank) -> float:
	match tier:
		Enums.LordRank.IMPERIAL: return 8.0
		Enums.LordRank.CLAN_CHAMPION: return 6.0
		Enums.LordRank.FAMILY_DAIMYO: return 5.0
		Enums.LordRank.PROVINCIAL_DAIMYO: return 4.0
		_: return 3.0


static func _score_disposition(disp: int) -> int:
	if disp >= 61:
		return 15
	if disp >= 31:
		return 10
	if disp >= -10:
		return 5
	if disp >= -30:
		return 1
	return 0


static func _score_birth_order(priority: int) -> int:
	match priority:
		CandidatePriority.DESIGNATED_HEIR: return 12
		CandidatePriority.ELDEST_CHILD: return 12
		CandidatePriority.OTHER_CHILD: return 8
		CandidatePriority.ADOPTED_HEIR: return 4
		CandidatePriority.SIBLING: return 3
		CandidatePriority.LORD_SELECTS: return 0
		_: return 0


static func _score_honor(honor_val: float) -> int:
	if honor_val >= 7.0:
		return 10
	if honor_val >= 5.0:
		return 8
	if honor_val >= 3.0:
		return 5
	if honor_val >= 2.0:
		return 2
	return 0


static func _score_glory(glory_val: float) -> int:
	if glory_val >= 6.0:
		return 8
	if glory_val >= 4.0:
		return 6
	if glory_val >= 2.0:
		return 3
	return 1


static func _score_insight_rank(rank: int) -> int:
	if rank >= 5:
		return 10
	if rank == 4:
		return 8
	if rank == 3:
		return 6
	if rank == 2:
		return 3
	return 1


static func _score_school_type(school_type: Enums.SchoolType, demand: String) -> int:
	match demand:
		"military":
			if school_type == Enums.SchoolType.BUSHI:
				return 8
			if school_type == Enums.SchoolType.COURTIER:
				return 4
			return 1
		"political":
			if school_type == Enums.SchoolType.COURTIER:
				return 8
			if school_type == Enums.SchoolType.BUSHI:
				return 4
			return 1
		"spiritual":
			if school_type == Enums.SchoolType.SHUGENJA:
				return 8
			if school_type == Enums.SchoolType.MONK:
				return 4
			return 1
		_:
			return 4


static func _score_skills(candidate: L5RCharacterData, demand: String) -> int:
	var relevant_skills: Array[String] = _get_relevant_skills(demand)
	var total: int = 0
	var count: int = 0
	for skill_name in relevant_skills:
		var rank: int = candidate.skills.get(skill_name, 0)
		total += rank
		count += 1
	if count == 0:
		return 1
	var avg: float = float(total) / float(count)
	if avg >= 5.0:
		return 7
	if avg >= 3.0:
		return 5
	if avg >= 2.0:
		return 3
	return 1


static func _get_relevant_skills(demand: String) -> Array[String]:
	match demand:
		"military":
			return ["Kenjutsu", "Battle", "Defense"]
		"political":
			return ["Courtier", "Etiquette", "Sincerity"]
		"spiritual":
			return ["Theology", "Meditation", "Lore: Theology"]
		_:
			return ["Etiquette", "Kenjutsu", "Courtier"]


static func _score_achievements(topics: Array[Dictionary]) -> int:
	var score: int = 0
	for topic in topics:
		var t_type: String = topic.get("topic_type", "")
		if t_type in BATTLE_COMMANDER_TYPES:
			score += 3
		elif t_type in BATTLE_PARTICIPANT_TYPES:
			score += 2
		elif t_type in DUEL_TYPES:
			score += 2
		elif t_type in PROMOTION_TYPES:
			score += 1
		elif t_type in OBJECTIVE_TYPES:
			score += 2
		elif t_type in DISGRACE_TYPES:
			score -= 2
		elif t_type in BETRAYAL_TYPES:
			score -= 5
	return clampi(score, 0, 10)


static func _score_titles(status_val: float) -> int:
	if status_val >= 5.0:
		return 5
	if status_val >= 3.0:
		return 3
	if status_val >= 1.0:
		return 1
	return 0
