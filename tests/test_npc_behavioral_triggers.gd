extends GutTest
## Tests for s45 NPC behavioral disadvantage triggers wired into the wave
## resolver (_pick_rumormonger_targets) and day orchestrator
## (_process_brash_reactions, _process_contrary_reactions).


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_char(id: int, wil: int = 2, honor: float = 2.0, glory: float = 2.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC " + str(id)
	c.willpower = wil
	c.stamina = 2
	c.strength = 2
	c.reflexes = 2
	c.agility = 2
	c.awareness = 2
	c.perception = 2
	c.intelligence = 2
	c.void_ring = 2
	c.current_void_points = 2
	c.honor = honor
	c.glory = glory
	c.status = 2.0
	c.action_points_current = 2
	c.action_points_max = 2
	c.physical_location = "100"
	c.advantages = []
	c.disadvantages = []
	c.school = "Hida Bushi"
	c.clan = "Crab"
	c.wounds_taken = 0
	c.skills = {}
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _add_dis(c: L5RCharacterData, type: Enums.Disadvantage, rank: int = 1, meta: Dictionary = {}) -> void:
	var dis := DisadvantageData.new()
	dis.disadvantage_type = type
	dis.rank = rank
	dis.metadata = meta.duplicate()
	c.disadvantages.append(dis)


# ---------------------------------------------------------------------------
# _pick_rumormonger_targets
# ---------------------------------------------------------------------------

func test_rumormonger_targets_empty_when_no_colocated() -> void:
	var speaker := _make_char(1)
	var chars_by_id: Dictionary = {1: speaker}
	var result := NPCWaveResolver._pick_rumormonger_targets(speaker, chars_by_id)
	assert_eq(result.get("subject_id"), -1)
	assert_eq(result.get("listener_id"), -1)


func test_rumormonger_targets_highest_glory_is_subject() -> void:
	var speaker := _make_char(1)
	var hi := _make_char(2, 2, 2.0, 7.0)  # glory 7
	var lo := _make_char(3, 2, 2.0, 1.0)  # glory 1
	var chars_by_id: Dictionary = {1: speaker, 2: hi, 3: lo}
	var result := NPCWaveResolver._pick_rumormonger_targets(speaker, chars_by_id)
	assert_eq(result.get("subject_id"), 2)


func test_rumormonger_targets_listener_differs_from_subject_with_two_colocated() -> void:
	var speaker := _make_char(1)
	var a := _make_char(2, 2, 2.0, 5.0)
	var b := _make_char(3, 2, 2.0, 2.0)
	var chars_by_id: Dictionary = {1: speaker, 2: a, 3: b}
	var result := NPCWaveResolver._pick_rumormonger_targets(speaker, chars_by_id)
	assert_ne(result.get("subject_id"), result.get("listener_id"))


func test_rumormonger_targets_excludes_different_location() -> void:
	var speaker := _make_char(1)
	speaker.physical_location = "100"
	var far := _make_char(2, 2, 2.0, 9.0)
	far.physical_location = "999"
	var chars_by_id: Dictionary = {1: speaker, 2: far}
	var result := NPCWaveResolver._pick_rumormonger_targets(speaker, chars_by_id)
	assert_eq(result.get("subject_id"), -1)


func test_rumormonger_targets_excludes_dead() -> void:
	var speaker := _make_char(1)
	var dead := _make_char(2)
	dead.wounds_taken = 40  # fatal
	var chars_by_id: Dictionary = {1: speaker, 2: dead}
	var result := NPCWaveResolver._pick_rumormonger_targets(speaker, chars_by_id)
	assert_eq(result.get("subject_id"), -1)


# ---------------------------------------------------------------------------
# _process_brash_reactions
# ---------------------------------------------------------------------------

func test_brash_no_event_without_disadvantage() -> void:
	# Target has no BRASH disadvantage — no duel challenge injected.
	var target := _make_char(2)
	var result: Dictionary = {
		"action_id": "PUBLIC_INSULT",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(1, {}).get("pending_events", []).size(), 0)


func test_brash_no_event_on_failed_insult() -> void:
	# Insult missed — target's BRASH does not trigger.
	var target := _make_char(2)
	_add_dis(target, Enums.Disadvantage.BRASH)
	var result: Dictionary = {
		"action_id": "PUBLIC_INSULT",
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(1, {}).get("pending_events", []).size(), 0)


func test_brash_no_event_for_dead_target() -> void:
	var target := _make_char(2)
	target.wounds_taken = 40
	_add_dis(target, Enums.Disadvantage.BRASH)
	var result: Dictionary = {
		"action_id": "PUBLIC_INSULT",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(1, {}).get("pending_events", []).size(), 0)


func test_brash_injects_duel_challenge_on_failed_willpower_roll() -> void:
	# willpower=1, honor=0, no explosions → max roll total = 10 < TN 25.
	# This is guaranteed to fail the Willpower check.
	var target := _make_char(2, 1, 0.0)  # wil=1, honor=0
	_add_dis(target, Enums.Disadvantage.BRASH)
	var result: Dictionary = {
		"action_id": "PUBLIC_INSULT",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	var dice := DiceEngine.new()
	dice.set_seed(42)
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, dice)
	var pending: Array = world_states.get(1, {}).get("pending_events", [])
	assert_eq(pending.size(), 1)
	assert_eq(pending[0].get("reactive_type"), "DUEL_CHALLENGE_RECEIVED")
	assert_eq(pending[0].get("challenger_id"), 2)  # insulted party challenges insulter
	assert_true(pending[0].get("brash_triggered", false))


func test_brash_event_is_sanctioned_public_non_lethal() -> void:
	var target := _make_char(2, 1, 0.0)
	_add_dis(target, Enums.Disadvantage.BRASH)
	var result: Dictionary = {
		"action_id": "PUBLIC_INSULT",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, DiceEngine.new())
	var pending: Array = world_states.get(1, {}).get("pending_events", [])
	if pending.size() > 0:
		assert_false(pending[0].get("to_death", true))
		assert_true(pending[0].get("is_sanctioned", false))
		assert_true(pending[0].get("is_public", false))


func test_brash_no_event_for_non_insult_action() -> void:
	var target := _make_char(2)
	_add_dis(target, Enums.Disadvantage.BRASH)
	var result: Dictionary = {
		"action_id": "CHARM",  # not an insult
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
	}
	var chars_by_id: Dictionary = {2: target}
	var world_states: Dictionary = {}
	DayOrchestrator._process_brash_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(1, {}).get("pending_events", []).size(), 0)


# ---------------------------------------------------------------------------
# _process_contrary_reactions
# ---------------------------------------------------------------------------

func test_contrary_no_log_without_disadvantage() -> void:
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var bystander := _make_char(2)
	bystander.physical_location = "100"
	# No CONTRARY disadvantage
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)


func test_contrary_no_log_on_failed_debate() -> void:
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var bystander := _make_char(2)
	bystander.physical_location = "100"
	_add_dis(bystander, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": false,  # debate failed
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)


func test_contrary_no_log_for_different_location() -> void:
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var bystander := _make_char(2)
	bystander.physical_location = "999"  # different location
	_add_dis(bystander, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)


func test_contrary_logs_event_on_failed_willpower_roll() -> void:
	# willpower=1, no explosions → max roll = 10.
	# actor glory=3.0 → TN = int(5.0 * 3.0) = 15. Always fails.
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var bystander := _make_char(2, 1)  # wil=1
	bystander.physical_location = "100"
	_add_dis(bystander, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	var dice := DiceEngine.new()
	dice.set_seed(42)
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, dice)
	var log: Array = world_states.get(2, {}).get("action_log", [])
	assert_eq(log.size(), 1)
	assert_eq(log[0].get("action_id"), "CONTRARY_REACTION")
	assert_eq(log[0].get("contrary_character_id"), 2)
	assert_eq(log[0].get("debate_actor_id"), 1)


func test_contrary_no_log_on_passed_willpower_roll() -> void:
	# willpower=10, no explosions → 10k10 min = 10.
	# actor glory=0.1 → TN = int(5.0 * 0.1) = 0. Always passes (any roll >= 0).
	var actor := _make_char(1, 2, 2.0, 0.1)
	actor.physical_location = "100"
	var bystander := _make_char(2, 10)  # wil=10
	bystander.physical_location = "100"
	_add_dis(bystander, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	# TN=0 means always passes — no log entry
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)


func test_contrary_skips_dead_bystander() -> void:
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var dead := _make_char(2, 1)
	dead.physical_location = "100"
	dead.wounds_taken = 40
	_add_dis(dead, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "PUBLIC_DEBATE",
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: dead}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)


func test_contrary_skips_non_debate_action() -> void:
	var actor := _make_char(1, 2, 2.0, 3.0)
	actor.physical_location = "100"
	var bystander := _make_char(2, 1)
	bystander.physical_location = "100"
	_add_dis(bystander, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = {
		"action_id": "CHARM",  # not PUBLIC_DEBATE
		"success": true,
		"character_id": 1,
	}
	var chars_by_id: Dictionary = {1: actor, 2: bystander}
	var world_states: Dictionary = {}
	DayOrchestrator._process_contrary_reactions([result], chars_by_id, world_states, DiceEngine.new())
	assert_eq(world_states.get(2, {}).get("action_log", []).size(), 0)
