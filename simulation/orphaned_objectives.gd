class_name OrphanedObjectives
## Handles vassal objective validity when assigning lord dies.
## Per GDD s55.33. Lord-dependent objectives become ORPHANED;
## target-dependent objectives persist as ACTIVE.


const LORD_DEPENDENT_OBJECTIVES: Array[String] = [
	"BREAK_ALLIANCE",
	"ISOLATE_CHARACTER",
	"GAIN_WINTER_COURT_INVITATION",
	"APPOINT_TO_POSITION",
	"REMOVE_FROM_POSITION",
	"RESOLVE_CLAN_WAR",
	"OBTAIN_IMPERIAL_EDICT",
	"CONQUER_PROVINCE",
	"SABOTAGE_ECONOMY",
]

const TARGET_DEPENDENT_OBJECTIVES: Array[String] = [
	"EXPOSE_SECRET",
	"INCREASE_KOKU",
	"AVENGE",
]

const STATUS_ACTIVE: String = "ACTIVE"
const STATUS_ORPHANED: String = "ORPHANED"


static func is_lord_dependent(objective_type: String) -> bool:
	return objective_type in LORD_DEPENDENT_OBJECTIVES


static func is_target_dependent(objective_type: String) -> bool:
	return objective_type in TARGET_DEPENDENT_OBJECTIVES


static func check_objective_validity(
	objective: Dictionary,
	dead_lord_id: int,
) -> String:
	var assigning_lord: int = objective.get("assigning_lord_id", -1)
	if assigning_lord != dead_lord_id:
		return STATUS_ACTIVE

	var obj_type: String = objective.get("objective_type", "")
	if is_lord_dependent(obj_type):
		return STATUS_ORPHANED
	return STATUS_ACTIVE


static func process_lord_death(
	vassals: Array,
	dead_lord_id: int,
	successor_id: int,
	objectives_map: Dictionary,
) -> Array:
	var results: Array = []

	for vassal: L5RCharacterData in vassals:
		if vassal.lord_id != dead_lord_id:
			continue

		var objectives: Dictionary = objectives_map.get(vassal.character_id, {})
		var primary: Dictionary = objectives.get("primary", {})
		if primary.is_empty():
			continue

		var validity: String = check_objective_validity(primary, dead_lord_id)
		if validity == STATUS_ORPHANED:
			primary["status"] = STATUS_ORPHANED
			results.append({
				"vassal_id": vassal.character_id,
				"objective_type": primary.get("objective_type", ""),
				"status": STATUS_ORPHANED,
				"report_target_id": successor_id if successor_id >= 0 else _find_next_authority(vassal, vassals),
			})

	return results


static func generate_report_need(
	vassal: L5RCharacterData,
	successor_id: int,
) -> Dictionary:
	var target_id: int = successor_id
	if target_id < 0:
		target_id = _find_next_authority(vassal)
	if target_id < 0:
		return {}
	return {
		"need_type": "REPORT_TO_NEW_LORD",
		"target_npc_id": target_id,
		"priority": 0,
	}


static func resolve_orphaned_objective(
	vassal_objectives: Dictionary,
	decision: String,
	new_objective: Dictionary = {},
	new_lord_id: int = -1,
) -> Dictionary:
	var primary: Dictionary = vassal_objectives.get("primary", {})
	match decision:
		"CONFIRM":
			primary["status"] = STATUS_ACTIVE
			# GDD s55.33.5 (LOCKED): "The objective's assigning_lord_id updates
			# to the new lord."
			if new_lord_id >= 0:
				primary["assigning_lord_id"] = new_lord_id
			return {"action": "CONFIRM", "objective": primary}
		"MODIFY":
			vassal_objectives["primary"] = new_objective
			new_objective["status"] = STATUS_ACTIVE
			return {"action": "MODIFY", "objective": new_objective}
		"CANCEL":
			vassal_objectives.erase("primary")
			return {"action": "CANCEL"}
	return {}


static func has_orphaned_vassals(
	vassals: Array,
	lord_id: int,
	objectives_map: Dictionary,
) -> Array:
	var orphaned_ids: Array = []
	for vassal: L5RCharacterData in vassals:
		if vassal.lord_id != lord_id:
			continue
		var objectives: Dictionary = objectives_map.get(vassal.character_id, {})
		var primary: Dictionary = objectives.get("primary", {})
		if primary.get("status", "") == STATUS_ORPHANED:
			orphaned_ids.append(vassal.character_id)
	return orphaned_ids


static func _find_next_authority(
	vassal: L5RCharacterData,
	characters: Array = [],
) -> int:
	if vassal.operational_superior_id >= 0:
		return vassal.operational_superior_id

	# GDD s55.33.4 (LOCKED): "If the entire chain is broken... the vassal
	# reports to the Clan Champion. If the Clan Champion is also dead, the
	# report goes to the highest-Status surviving character in the clan.
	# There is always someone." Family Daimyo / Clan Champion status
	# thresholds match the established day_orchestrator.gd conventions
	# (_get_family_daimyo_ids / _get_clan_champions).
	var family_daimyo: L5RCharacterData = null
	var clan_champion: L5RCharacterData = null
	var highest_status: L5RCharacterData = null

	for c: L5RCharacterData in characters:
		if c.character_id == vassal.character_id:
			continue
		if CharacterStats.is_dead(c):
			continue
		if c.clan != vassal.clan:
			continue
		if highest_status == null or c.status > highest_status.status:
			highest_status = c
		if c.status >= 7.0 and c.lord_id == -1:
			clan_champion = c
		elif c.family == vassal.family and c.status >= 6.0 and c.status < 7.0:
			family_daimyo = c

	if family_daimyo != null:
		return family_daimyo.character_id
	if clan_champion != null:
		return clan_champion.character_id
	if highest_status != null:
		return highest_status.character_id
	return -1
