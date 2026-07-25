class_name PcSystem
## PC Integration — GDD s60.
## Handles AP banking, login/logout presence, offline reactive-event policies,
## and Bubble Time scene management.  Pure static functions; no Node inheritance.

# -- Constants (s60.11) -------------------------------------------------------

const BANKED_AP_CAP_MULTIPLIER: int = 4
const OFFLINE_EVENT_QUEUE_CAP: int = 30

# School types a player character may NOT take (s60.2, owner-locked 2026-06-06).
# Monk is excluded — kiho/monastic play is NPC-only, so PCs can never be monks
# (and therefore can never learn kiho, which is monk-only per s38a).
const DISALLOWED_PC_SCHOOL_TYPES: Array = [Enums.SchoolType.MONK]

const DEFAULT_OFFLINE_POLICIES: Dictionary = {
	"DUEL_CHALLENGE_RECEIVED": "QUEUE",
	"FAVOR_REQUESTED": "HONOR",
	"COURT_INVITATION": "QUEUE",
	"ACCEPT_TRAINING": "DECLINE",
	"CONTRACT_OFFERED": "QUEUE",
}

# -- Character creation constraints (s60.2) -----------------------------------

## True if `school_type` is a valid choice for a player character (s60.2).
## PCs may not be monks. The character-creation flow must reject disallowed types.
static func is_school_type_allowed_for_pc(school_type: Enums.SchoolType) -> bool:
	return not (school_type in DISALLOWED_PC_SCHOOL_TYPES)


## True if `character` is a valid PC (s60.2): flagged is_pc and not a disallowed
## school type. Use at the end of character creation to validate the build.
static func is_valid_pc(character: L5RCharacterData) -> bool:
	if character == null or not character.is_pc:
		return false
	return is_school_type_allowed_for_pc(character.school_type)


# -- AP Banking (s60.5) -------------------------------------------------------

static func bank_daily_ap(character: L5RCharacterData, daily_ap: int) -> void:
	var cap: int = daily_ap * BANKED_AP_CAP_MULTIPLIER
	character.banked_ap = mini(character.banked_ap + daily_ap, cap)


## True if the PC has at least `cost` banked AP to spend (s60.5).
static func can_spend_banked_ap(character: L5RCharacterData, cost: int) -> bool:
	return cost > 0 and character.banked_ap >= cost


## Spend `cost` from the PC's banked AP pool (s60.5). Returns
## {success, remaining} or {success:false, reason, available, required}.
static func spend_banked_ap(character: L5RCharacterData, cost: int) -> Dictionary:
	if cost <= 0:
		return {"success": false, "reason": "invalid_cost"}
	if character.banked_ap < cost:
		return {
			"success": false,
			"reason": "insufficient_ap",
			"available": character.banked_ap,
			"required": cost,
		}
	character.banked_ap -= cost
	return {"success": true, "remaining": character.banked_ap, "spent": cost}


# -- Presence (s60.3 / s60.4) -------------------------------------------------

static func login(character: L5RCharacterData) -> void:
	character.is_logged_in = true
	if character.physical_location.is_empty():
		var home: int = character.home_settlement_id
		if home >= 0:
			character.physical_location = str(home)


static func logout(character: L5RCharacterData) -> void:
	character.is_logged_in = false
	if character.home_settlement_id < 0 and not character.physical_location.is_empty():
		character.home_settlement_id = character.physical_location.to_int()
	character.physical_location = ""
	# A logged-out PC holds no pending arrival missions (s56.19); also reset the
	# arrival marker so a fresh login re-triggers arrival detection at home.
	character.pending_arrival_mission = {}
	character.last_arrival_province_id = -1


# -- Offline Policy Helpers (s60.6) -------------------------------------------

static func get_policy(character: L5RCharacterData, event_type: String) -> String:
	return character.offline_policies.get(
		event_type,
		DEFAULT_OFFLINE_POLICIES.get(event_type, "QUEUE")
	)


static func _evaluate_condition(condition: String, event: Dictionary, character: L5RCharacterData, characters_by_id: Dictionary) -> bool:
	var initiator_id: int = int(event.get("challenger_id",
		event.get("requester_id",
		event.get("host_id",
		event.get("lord_id", -1)))))
	var initiator: L5RCharacterData = characters_by_id.get(initiator_id)
	if initiator == null:
		return false

	for cond: String in condition.split(" "):
		match cond:
			"same_clan":
				if initiator.clan != character.clan:
					return false
			"disposition_friend":
				var disp: int = character.disposition_values.get(initiator_id, 0)
				if disp < 31:
					return false
			"higher_status":
				if initiator.status <= character.status:
					return false
			"lower_status":
				if initiator.status >= character.status:
					return false
	return true


static func resolve_policy(
	character: L5RCharacterData,
	event: Dictionary,
	characters_by_id: Dictionary,
) -> String:
	var event_type: String = event.get("reactive_type", "")
	var policy: String = get_policy(character, event_type)

	if policy == "QUEUE":
		return "QUEUE"
	if policy == "HONOR" or policy == "ACCEPT":
		return "ACCEPT"
	if policy == "DECLINE":
		return "DECLINE"
	if policy.begins_with("CONDITIONAL:"):
		var condition: String = policy.substr("CONDITIONAL:".length())
		if _evaluate_condition(condition, event, character, characters_by_id):
			return "ACCEPT"
		return "DECLINE"
	return "QUEUE"


# -- Offline Event Processing (s60.6) -----------------------------------------

static func process_offline_events(
	character: L5RCharacterData,
	characters_by_id: Dictionary,
	ic_day: int,
) -> Array:
	if character.is_logged_in or character.pending_events.is_empty():
		return []

	var consequences: Array = []
	var remaining: Array = []

	for event: Dictionary in character.pending_events:
		var event_type: String = event.get("reactive_type", "")
		var resolution: String = resolve_policy(character, event, characters_by_id)

		match resolution:
			"QUEUE":
				remaining.append(event)
			"ACCEPT":
				consequences.append({
					"event": event,
					"event_type": event_type,
					"resolution": "ACCEPT",
					"character_id": character.character_id,
					"ic_day": ic_day,
				})
			"DECLINE":
				consequences.append({
					"event": event,
					"event_type": event_type,
					"resolution": "DECLINE",
					"character_id": character.character_id,
					"ic_day": ic_day,
				})

	# Re-apply queue cap (s60.6 line "Queue cap: 30")
	if remaining.size() > OFFLINE_EVENT_QUEUE_CAP:
		remaining = remaining.slice(remaining.size() - OFFLINE_EVENT_QUEUE_CAP)

	character.pending_events = remaining
	return consequences


# -- Bubble Time (s60.7) ------------------------------------------------------

static func create_bubble_scene(
	participant_ids: Array,
	anchor_ic_day: int,
	next_scene_id: Array,
	characters_by_id: Dictionary,
) -> Dictionary:
	var scene_id: int = next_scene_id[0]
	next_scene_id[0] = scene_id + 1

	var scene: Dictionary = {
		"scene_id": scene_id,
		"participant_ids": participant_ids.duplicate(),
		"anchor_ic_day": anchor_ic_day,
		"queued_actions": [],
	}

	for pid: int in participant_ids:
		var c: L5RCharacterData = characters_by_id.get(pid)
		if c != null and not CharacterStats.is_dead(c):
			c.bubble_scene_id = scene_id
			c.bubble_anchor_ic_day = anchor_ic_day

	return scene


static func close_bubble_scene(
	scene_id: int,
	active_bubble_scenes: Array,
	characters_by_id: Dictionary,
) -> Dictionary:
	var scene_idx: int = -1
	for i: int in active_bubble_scenes.size():
		var s: Dictionary = active_bubble_scenes[i]
		if s.get("scene_id", -1) == scene_id:
			scene_idx = i
			break

	if scene_idx < 0:
		return {"success": false, "reason": "scene_not_found"}

	var scene: Dictionary = active_bubble_scenes[scene_idx]
	active_bubble_scenes.remove_at(scene_idx)

	for pid: int in scene.get("participant_ids", []):
		var c: L5RCharacterData = characters_by_id.get(pid)
		if c != null and not CharacterStats.is_dead(c):
			c.bubble_scene_id = -1
			c.bubble_anchor_ic_day = -1

	return {
		"success": true,
		"scene_id": scene_id,
		"anchor_ic_day": scene.get("anchor_ic_day", -1),
		"queued_actions": scene.get("queued_actions", []),
	}
