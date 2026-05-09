class_name MilitaryServiceSystem
## Military service assignment per GDD s11.7a. Request flows down the feudal
## chain: Clan Champion → Rikugunshokan → Family Daimyo → Provincial/City Daimyo.
## Provincial Daimyo selects retainers via ASSIGN_TO_MILITARY_SERVICE (1 AP).
## operational_superior_id changes; lord_id stays unchanged.
## Commitment protection scores shared with LevySystem.
## Pure static functions. Caller owns all state.


# -- Request Flow ----------------------------------------------------------------

static func create_service_request(
	requesting_commander_id: int,
	target_unit_id: int,
	rank_needed: Enums.MilitaryRank,
	count: int = 1,
) -> Dictionary:
	return {
		"requesting_commander_id": requesting_commander_id,
		"target_unit_id": target_unit_id,
		"rank_needed": rank_needed,
		"count": count,
		"fulfilled": 0,
		"assigned_character_ids": [],
	}


static func cascade_request_to_vassals(
	family_daimyo_id: int,
	vassal_ids: Array[int],
	total_needed: int,
) -> Array[Dictionary]:
	if vassal_ids.is_empty():
		return []

	var per_vassal: int = maxi(int(total_needed / vassal_ids.size()), 1)
	var remainder: int = total_needed % vassal_ids.size()

	var assignments: Array[Dictionary] = []
	for i: int in vassal_ids.size():
		var count: int = per_vassal
		if i < remainder:
			count += 1
		if count <= 0:
			continue
		assignments.append({
			"from_lord_id": family_daimyo_id,
			"to_vassal_id": vassal_ids[i],
			"count_requested": count,
		})
	return assignments


# -- Candidate Evaluation --------------------------------------------------------

static func evaluate_candidates(
	candidates: Array[Dictionary],
	selecting_lord_personality: String,
) -> Array[Dictionary]:
	return LevySystem.rank_candidates(candidates, selecting_lord_personality)


static func get_commitment_score(role: String) -> int:
	return LevySystem.get_commitment_score(role)


static func evaluate_candidate(
	candidate_role: String,
	personality_virtue: String,
) -> int:
	return LevySystem.evaluate_candidate(candidate_role, personality_virtue)


# -- Assignment Execution --------------------------------------------------------

static func assign_to_military_service(
	character_data: Dictionary,
	military_commander_id: int,
	unit_id: int,
) -> Dictionary:
	var old_operational_superior: int = character_data.get("operational_superior_id", -1)
	character_data["operational_superior_id"] = military_commander_id
	character_data["assigned_company_id"] = unit_id

	return {
		"success": true,
		"character_id": character_data.get("character_id", -1),
		"old_operational_superior_id": old_operational_superior,
		"new_operational_superior_id": military_commander_id,
		"assigned_unit_id": unit_id,
		"lord_id_unchanged": character_data.get("lord_id", -1),
	}


static func release_from_military_service(
	character_data: Dictionary,
) -> Dictionary:
	var old_commander: int = character_data.get("operational_superior_id", -1)
	var old_unit: int = character_data.get("assigned_company_id", -1)

	character_data["operational_superior_id"] = character_data.get("lord_id", -1)
	character_data["assigned_company_id"] = -1

	return {
		"released": true,
		"character_id": character_data.get("character_id", -1),
		"old_commander_id": old_commander,
		"old_unit_id": old_unit,
		"returned_to_lord_id": character_data.get("lord_id", -1),
	}


# -- Authority Validation --------------------------------------------------------

static func can_assign_military_service(
	lord_rank: String,
) -> bool:
	return lord_rank in ["provincial_daimyo", "city_daimyo"]


static func can_request_service(
	requester_rank: Enums.MilitaryRank,
) -> bool:
	return requester_rank >= Enums.MilitaryRank.SHIREIKAN


# -- Bulk Selection --------------------------------------------------------------

static func select_candidates_for_service(
	available_retainers: Array[Dictionary],
	count_needed: int,
	selecting_lord_personality: String,
) -> Dictionary:
	var ranked: Array[Dictionary] = evaluate_candidates(
		available_retainers, selecting_lord_personality,
	)

	var selected: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []

	for candidate: Dictionary in ranked:
		if selected.size() >= count_needed:
			rejected.append(candidate)
			continue
		selected.append(candidate)

	return {
		"selected": selected,
		"rejected": rejected,
		"count_requested": count_needed,
		"count_fulfilled": selected.size(),
		"shortfall": maxi(count_needed - selected.size(), 0),
	}


static func apply_service_assignments(
	selected: Array[Dictionary],
	characters_by_id: Dictionary,
	military_commander_id: int,
	unit_id: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for candidate: Dictionary in selected:
		var char_id: int = candidate.get("character_id", -1)
		if char_id < 0:
			continue
		var char_data: Dictionary = characters_by_id.get(char_id, {})
		if char_data.is_empty():
			continue
		var r: Dictionary = assign_to_military_service(
			char_data, military_commander_id, unit_id,
		)
		results.append(r)
	return results
