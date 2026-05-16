class_name ReactiveDecisions
## Reactive decision path per GDD s55.11.
## Reactive events bypass normal scoring. Each type has a decision tree
## driven by personality + disposition.


enum ReactiveType {
	DUEL_CHALLENGE_RECEIVED,
	FAVOR_REQUESTED,
	COURT_INVITATION,
	ACCEPT_TRAINING,
}


static func evaluate_reactive_event(
	event: Dictionary,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var event_type: String = event.get("reactive_type", "")
	match event_type:
		"DUEL_CHALLENGE_RECEIVED":
			return _evaluate_duel_response(event, character, ctx)
		"FAVOR_REQUESTED":
			return _evaluate_favor_response(event, character)
		"COURT_INVITATION":
			return _evaluate_court_invitation(event, character)
		"ACCEPT_TRAINING":
			return _evaluate_training_response(event, character, ctx)
	return {"action": "PASS", "need_type": event.get("need_type", "")}


# -- Duel Response (s55.11) ----------------------------------------------------

static func _evaluate_duel_response(
	event: Dictionary,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var challenger_id: int = event.get("challenger_id", -1)
	var disposition: float = character.disposition_values.get(challenger_id, 0.0)
	var is_public: bool = event.get("is_public", true)

	var accept: bool = false

	if character.bushido_virtue == Enums.BushidoVirtue.YU:
		accept = true
	elif character.shourido_virtue == Enums.ShouridoVirtue.KYORYOKU:
		accept = true
	elif disposition <= -11.0:
		accept = true
	elif character.bushido_virtue == Enums.BushidoVirtue.MEIYO and is_public:
		accept = true
	elif character.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		accept = true

	if not accept and is_public:
		if character.bushido_virtue != Enums.BushidoVirtue.NONE:
			accept = true

	if accept:
		return {
			"action": "ACCEPT_DUEL",
			"need_type": "ACCEPT_DUEL",
			"target_npc_id": challenger_id,
			"priority": 3,
		}
	return {
		"action": "DECLINE_DUEL",
		"need_type": "DECLINE_DUEL",
		"target_npc_id": challenger_id,
		"priority": 2,
		"glory_loss": -0.3,
	}


# -- Proactive Duel Trigger (s55.11) -------------------------------------------

static func evaluate_duel_trigger(
	character: L5RCharacterData,
	trigger_event: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_id: int = trigger_event.get("target_npc_id", -1)
	var trigger_type: String = trigger_event.get("trigger_type", "")

	if not _passes_capability_check(character, ctx):
		return {}

	if not _passes_target_assessment(character, target_id, ctx):
		return {}

	if not _passes_personality_gate_duel(character, trigger_type):
		return {}

	return {
		"action": "ISSUE_DUEL_CHALLENGE",
		"need_type": "ISSUE_DUEL_CHALLENGE",
		"target_npc_id": target_id,
		"priority": 3,
	}


static func _passes_capability_check(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if character.bushido_virtue == Enums.BushidoVirtue.YU:
		return true
	if character.shourido_virtue == Enums.ShouridoVirtue.KYORYOKU:
		return true

	var iaijutsu_rank: int = character.skills.get("Iaijutsu", 0)
	if iaijutsu_rank >= 3:
		return true

	for cid: int in ctx.characters_present:
		if cid == character.character_id:
			continue
		var disp: float = character.disposition_values.get(cid, 0.0)
		if disp >= 31.0:
			return true

	return false


static func _passes_target_assessment(
	character: L5RCharacterData,
	target_id: int,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if character.bushido_virtue == Enums.BushidoVirtue.YU:
		return true
	if character.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return true

	if character.shourido_virtue == Enums.ShouridoVirtue.DOSATSU:
		var has_intel: bool = _has_target_intel(character, target_id)
		if not has_intel:
			return false
	if character.shourido_virtue == Enums.ShouridoVirtue.CHISHIKI:
		var has_intel: bool = _has_target_intel(character, target_id)
		if not has_intel:
			return false

	return true


static func _has_target_intel(character: L5RCharacterData, target_id: int) -> bool:
	for entry: KnowledgeEntry in character.knowledge_pool:
		if entry.entry_type == "skill_assessment" and entry.data.get("target_id", -1) == target_id:
			return true
	return false


static func _passes_personality_gate_duel(
	character: L5RCharacterData,
	trigger_type: String,
) -> bool:
	if character.bushido_virtue == Enums.BushidoVirtue.YU:
		return true
	if character.shourido_virtue == Enums.ShouridoVirtue.KYORYOKU:
		return true
	if character.bushido_virtue == Enums.BushidoVirtue.MEIYO:
		return trigger_type == "public_insult" or trigger_type == "cornered_in_court"
	if character.bushido_virtue == Enums.BushidoVirtue.JIN:
		return false
	if character.bushido_virtue == Enums.BushidoVirtue.REI:
		return false
	if character.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return trigger_type == "public_insult"
	return true


# -- Favor Response (s55.11) ---------------------------------------------------

static func _evaluate_favor_response(
	event: Dictionary,
	character: L5RCharacterData,
) -> Dictionary:
	var requester_id: int = event.get("requester_id", -1)
	var disposition: float = character.disposition_values.get(requester_id, 0.0)

	var honor: bool = false

	if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		honor = true
	elif character.bushido_virtue == Enums.BushidoVirtue.MAKOTO:
		honor = true
	elif disposition >= 31.0:
		honor = true

	if honor:
		return {
			"action": "HONOR_FAVOR",
			"need_type": "HONOR_FAVOR",
			"target_npc_id": requester_id,
			"priority": 2,
		}
	return {
		"action": "DECLINE_FAVOR",
		"need_type": "DECLINE_FAVOR",
		"target_npc_id": requester_id,
		"priority": 1,
	}


# -- Court Invitation Response (s55.11) ----------------------------------------

static func _evaluate_court_invitation(
	event: Dictionary,
	character: L5RCharacterData,
) -> Dictionary:
	var host_id: int = event.get("host_id", -1)
	var court_prestige: int = event.get("prestige", 1)
	var disposition: float = character.disposition_values.get(host_id, 0.0)

	var attend: bool = court_prestige >= 3 or disposition >= 15.0

	if character.bushido_virtue == Enums.BushidoVirtue.REI:
		attend = true
	if character.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		if court_prestige < 3:
			attend = false

	if attend:
		return {
			"action": "ATTEND_COURT",
			"need_type": "ATTEND_COURT",
			"target_npc_id": host_id,
			"priority": 2,
		}
	return {
		"action": "DECLINE_INVITATION",
		"need_type": "REST",
		"priority": 1,
	}


# -- Training Response (s55.11) ------------------------------------------------

static func _evaluate_training_response(
	event: Dictionary,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var sensei_id: int = event.get("sensei_id", -1)
	var skill_name: String = event.get("skill", "")
	var sensei_rank: int = event.get("sensei_rank", 0)

	var student_rank: int = character.skills.get(skill_name, 0)
	if sensei_rank <= student_rank:
		return {"action": "DECLINE_TRAINING", "reason": "no_benefit"}

	if character.shourido_virtue == Enums.ShouridoVirtue.KANPEKI:
		if sensei_rank < student_rank + 2:
			return {"action": "DECLINE_TRAINING", "reason": "perfectionist_gate"}

	if character.shourido_virtue == Enums.ShouridoVirtue.KETSUI:
		var has_mentor_objective: bool = _has_mentor_objective(character, sensei_id, ctx)
		if not has_mentor_objective:
			return {"action": "DECLINE_TRAINING", "reason": "self_reliance"}

	return {
		"action": "ACCEPT_TRAINING",
		"need_type": "TRAIN_SKILL",
		"target_npc_id": sensei_id,
		"priority": 2,
		"skill": skill_name,
	}


static func _has_mentor_objective(
	_character: L5RCharacterData,
	sensei_id: int,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	var primary: Dictionary = ctx.known_objectives.get("primary", {})
	return primary.get("objective_type", "") == "MENTOR_CHARACTER" and \
		primary.get("target_npc_id", -1) == sensei_id
