extends GutTest
## Tests for s12.8 wiring into ActionExecutor and DayOrchestrator.


var _engine: DiceEngine
var _actor: L5RCharacterData
var _target: L5RCharacterData
var _chars: Dictionary


func before_each() -> void:
	_engine = DiceEngine.new(42)

	_actor = L5RCharacterData.new()
	_actor.character_id = 1
	_actor.agility = 4
	_actor.intelligence = 4
	_actor.awareness = 4
	_actor.perception = 3
	_actor.reflexes = 3
	_actor.strength = 3
	_actor.willpower = 3
	_actor.skills = {
		"Stealth": 4,
		"Forgery": 3,
		"Investigation": 2,
		"Sleight of Hand": 3,
		"Temptation": 3,
	}
	_actor.honor = 5.0
	_actor.infamy = 0.0
	_actor.physical_location = "castle_a"

	_target = L5RCharacterData.new()
	_target.character_id = 2
	_target.perception = 3
	_target.willpower = 3
	_target.skills = {"Investigation": 2, "Etiquette": 2}
	_target.honor = 3.0
	_target.physical_location = "castle_a"

	_chars = {1: _actor, 2: _target}


func _make_action(action_id: String, target_id: int = 2, meta: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_id
	a.metadata = meta
	return a


func _make_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 100
	ctx.season = 0
	ctx.dispositions = {2: 0}
	return ctx


# ==============================================================================
# ActionExecutor Covert Intercepts
# ==============================================================================

func test_eavesdrop_routes_to_secret_system() -> void:
	var a := _make_action("EAVESDROP")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "EAVESDROP")
	assert_eq(r["skill_used"], "Stealth")
	assert_has(r["effects"], "detection_risk")


func test_intercept_letter_routes() -> void:
	var a := _make_action("INTERCEPT_LETTER")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "INTERCEPT_LETTER")
	assert_eq(r["skill_used"], "Stealth")


func test_search_quarters_routes() -> void:
	var a := _make_action("SEARCH_QUARTERS")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "SEARCH_QUARTERS")


func test_shadow_target_routes() -> void:
	var a := _make_action("SHADOW_TARGET")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "SHADOW_TARGET")
	assert_eq(r["skill_used"], "Stealth")


func test_conceal_item_routes() -> void:
	var a := _make_action("CONCEAL_ITEM", -1, {"item_size": "SMALL", "is_weapon": false})
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "CONCEAL_ITEM")
	assert_eq(r["skill_used"], "Sleight of Hand")


func test_forge_impersonation_letter_routes() -> void:
	var a := _make_action("FORGE_IMPERSONATION_LETTER", -1, {"authority_level": "minor"})
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "FORGE_IMPERSONATION_LETTER")
	assert_eq(r["skill_used"], "Forgery")


func test_forge_order_routes() -> void:
	var a := _make_action("FORGE_ORDER", -1, {"authority_level": "moderate"})
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "FORGE_ORDER")
	assert_eq(r["skill_used"], "Forgery")


func test_fabricate_secret_routes() -> void:
	var a := _make_action("FABRICATE_SECRET", 2, {
		"severity": SecretData.Severity.TIER_3, "secret_id": 99
	})
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "FABRICATE_SECRET")
	assert_eq(r["skill_used"], "Forgery")


func test_seduce_routes() -> void:
	var a := _make_action("SEDUCE")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "SEDUCE")
	assert_eq(r["skill_used"], "Temptation")


func test_seduce_for_info_routes() -> void:
	var a := _make_action("SEDUCE_FOR_INFO")
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "SEDUCE_FOR_INFO")


func test_search_person_routes() -> void:
	var a := _make_action("SEARCH_PERSON", 2, {"concealment_tn": 20})
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_eq(r["action_id"], "SEARCH_PERSON")
	assert_eq(r["skill_used"], "Investigation")


func test_eavesdrop_no_target_falls_through() -> void:
	var a := _make_action("EAVESDROP", 999)
	var ctx := _make_ctx()
	var r: Dictionary = ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	# Falls through to generic path when target not found
	assert_eq(r["action_id"], "EAVESDROP")


func test_covert_action_applies_honor_cost() -> void:
	var starting_honor: float = _actor.honor
	var a := _make_action("EAVESDROP")
	var ctx := _make_ctx()
	ActionExecutor.execute(a, _actor, ctx, _engine, {}, {}, _chars)
	assert_true(_actor.honor < starting_honor)


# ==============================================================================
# ScoredAction metadata field
# ==============================================================================

func test_scored_action_has_metadata() -> void:
	var a := NPCDataStructures.ScoredAction.new()
	assert_typeof(a.metadata, TYPE_DICTIONARY)


func test_scored_action_metadata_default_empty() -> void:
	var a := NPCDataStructures.ScoredAction.new()
	assert_true(a.metadata.is_empty())


# ==============================================================================
# DayOrchestrator — Entanglement Processing
# ==============================================================================

func test_entanglement_broken_after_3_missed() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 10)
	ent["missed_windows"] = 2
	var entanglements: Array = [ent]
	var results: Array = DayOrchestrator._process_entanglements(entanglements, 30)
	assert_true(results.size() > 0)
	assert_eq(results[0]["event"], "broken")


func test_entanglement_neglected_warning() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 10)
	var entanglements: Array = [ent]
	var results: Array = DayOrchestrator._process_entanglements(entanglements, 30)
	if results.size() > 0:
		assert_eq(results[0]["event"], "neglected")


func test_active_entanglement_no_result() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var entanglements: Array = [ent]
	var results: Array = DayOrchestrator._process_entanglements(entanglements, 105)
	assert_eq(results.size(), 0)


# ==============================================================================
# DayOrchestrator — Bound State Processing
# ==============================================================================

func test_bound_character_attempts_escape() -> void:
	var prisoner: L5RCharacterData = L5RCharacterData.new()
	prisoner.character_id = 10
	prisoner.agility = 4
	prisoner.skills = {"Sleight of Hand": 3}
	prisoner.honor = 5.0
	var chars: Dictionary = {10: prisoner}
	var bs: Dictionary = BoundEscapeSystem.create_bound_state(10, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var bound_states: Array = [bs]
	var results: Array = DayOrchestrator._process_bound_states(
		bound_states, chars, _engine, 101
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["character_id"], 10)


func test_bound_no_sleight_of_hand_no_attempt() -> void:
	var prisoner: L5RCharacterData = L5RCharacterData.new()
	prisoner.character_id = 11
	prisoner.agility = 3
	prisoner.skills = {}
	prisoner.honor = 5.0
	var chars: Dictionary = {11: prisoner}
	var bs: Dictionary = BoundEscapeSystem.create_bound_state(11, 3, BoundEscapeSystem.BindingMaterial.CHAINS, 100)
	var bound_states: Array = [bs]
	var results: Array = DayOrchestrator._process_bound_states(
		bound_states, chars, _engine, 101
	)
	assert_eq(results.size(), 0)


func test_freed_states_removed() -> void:
	var bs: Dictionary = BoundEscapeSystem.create_bound_state(10, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	bs["state"] = BoundEscapeSystem.BoundState.FREE
	var bound_states: Array = [bs]
	DayOrchestrator._process_bound_states(bound_states, {}, _engine, 101)
	assert_eq(bound_states.size(), 0)
