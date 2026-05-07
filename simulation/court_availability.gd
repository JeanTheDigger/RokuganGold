class_name CourtAvailability
## Helper function for decomposition trees that need ATTEND_COURT.
## Checks court availability and evaluates alternative channels.
## Per GDD s55.34. Returns a need dictionary or null if no option exists.


static func attend_court_or_alternative(
	active_court_at_location: Dictionary,
	upcoming_courts: Array[Dictionary],
	character: L5RCharacterData,
	target_npc_id: int,
	held_leverage: Array[Dictionary],
	action_log: Array[Dictionary],
	current_season: int,
	known_locations: Dictionary = {},
) -> Variant:
	# Step 1: Active court at current location
	if not active_court_at_location.is_empty():
		return {
			"need_type": "ATTEND_COURT",
			"target_settlement_id": active_court_at_location.get("settlement_id", -1),
			"priority": 2,
		}

	# Step 2: Upcoming court within 1 season that can be reached
	var best_court: Dictionary = _pick_highest_prestige_court(upcoming_courts)
	if not best_court.is_empty():
		return {
			"need_type": "TRAVEL_TO",
			"target_settlement_id": best_court.get("settlement_id", -1),
			"priority": 2,
		}

	# Step 3a: Deploy leverage by letter
	if not held_leverage.is_empty():
		var letter_target: int = _pick_best_letter_target(
			target_npc_id, held_leverage, character
		)
		if letter_target >= 0:
			return {
				"need_type": "SEND_LETTER",
				"target_npc_id": letter_target,
				"priority": 2,
			}

	# Step 3b: Request lord call court (once per season)
	if character.lord_id >= 0:
		var already_requested: bool = _has_requested_court_this_season(
			character.character_id, character.lord_id, action_log, current_season
		)
		if not already_requested:
			return {
				"need_type": "SEND_LETTER",
				"target_npc_id": character.lord_id,
				"priority": 1,
			}

	# Step 3c: Personal visit to target
	if target_npc_id >= 0:
		var target_location: int = known_locations.get(target_npc_id, -1)
		if target_location >= 0:
			return {
				"need_type": "TRAVEL_TO",
				"target_settlement_id": target_location,
				"priority": 1,
			}

	# Step 3d: No alternative — fall through to standing objective
	return null


static func _pick_highest_prestige_court(
	courts: Array[Dictionary],
) -> Dictionary:
	if courts.is_empty():
		return {}
	var best: Dictionary = courts[0]
	var best_prestige: int = best.get("prestige", 0)
	for i: int in range(1, courts.size()):
		var prestige: int = courts[i].get("prestige", 0)
		if prestige > best_prestige:
			best = courts[i]
			best_prestige = prestige
	return best


static func _pick_best_letter_target(
	target_npc_id: int,
	held_leverage: Array[Dictionary],
	character: L5RCharacterData,
) -> int:
	# Prefer the target's lord, then the target themselves
	for leverage: Dictionary in held_leverage:
		var target_lord: int = leverage.get("target_lord_id", -1)
		if target_lord >= 0:
			return target_lord
	if target_npc_id >= 0:
		return target_npc_id
	return -1


static func _has_requested_court_this_season(
	requester_id: int,
	lord_id: int,
	action_log: Array[Dictionary],
	current_season: int,
) -> bool:
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) != requester_id:
			continue
		if entry.get("action_id", "") != "SEND_LETTER":
			continue
		if entry.get("target_npc_id", -1) != lord_id:
			continue
		if entry.get("season", -1) == current_season:
			return true
	return false
