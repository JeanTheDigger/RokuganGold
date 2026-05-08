extends GutTest

# ==============================================================================
# Tests for performative arts wiring into ActionExecutor
# ==============================================================================

func _make_action(action_id: String, target_id: int = -1) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_id
	a.target_province_id = -1
	return a


func _make_ctx(char_id: int = 1) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char_id
	ctx.ic_day = 10
	ctx.season = 0
	return ctx


func _make_performer(id: int = 1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 4
	c.agility = 3
	c.void_ring = 3
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.intelligence = 3
	c.reflexes = 3
	c.skills = {"Artisan": 5, "Etiquette": 3}
	c.glory = 3.0
	c.honor = 5.0
	c.physical_location = "court_hall"
	c.disposition_values = {}
	c.pieces_seen = {}
	return c


func _make_witness(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 3
	c.physical_location = "court_hall"
	c.disposition_values = {}
	return c


# ==============================================================================
# PUBLIC_PERFORMANCE via ActionExecutor
# ==============================================================================

func test_public_performance_returns_performance_result() -> void:
	var performer := _make_performer()
	var witness := _make_witness(10)
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer, 10: witness}
	var action := _make_action("PUBLIC_PERFORMANCE")
	var ctx := _make_ctx()

	var result := ActionExecutor.execute(
		action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_eq(result["action_id"], "PUBLIC_PERFORMANCE")
	assert_true(result["effects"].has("performance_applied"))
	assert_true(result["effects"]["performance_applied"])


func test_public_performance_changes_witness_disposition() -> void:
	var performer := _make_performer()
	var witness := _make_witness(10)
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var chars_by_id := {1: performer, 10: witness}
	var action := _make_action("PUBLIC_PERFORMANCE")
	var ctx := _make_ctx()

	ActionExecutor.execute(action, performer, ctx, dice, {}, {}, chars_by_id)

	if result_has_success(performer, witness):
		assert_gt(witness.disposition_values.get(1, 0), 0)


func result_has_success(performer: L5RCharacterData, _witness: L5RCharacterData) -> bool:
	return performer.glory >= 3.0


func test_public_performance_increments_fatigue() -> void:
	var performer := _make_performer()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer}
	var action := _make_action("PUBLIC_PERFORMANCE")
	var ctx := _make_ctx()

	ActionExecutor.execute(action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_eq(performer.pieces_seen.get("_performance_count_today", 0), 1)


func test_public_performance_fatigue_stacks() -> void:
	var performer := _make_performer()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer}
	var action := _make_action("PUBLIC_PERFORMANCE")
	var ctx := _make_ctx()

	ActionExecutor.execute(action, performer, ctx, dice, {}, {}, chars_by_id)
	dice.set_seed(42)
	ActionExecutor.execute(action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_eq(performer.pieces_seen.get("_performance_count_today", 0), 2)


# ==============================================================================
# PERFORM_FOR via ActionExecutor
# ==============================================================================

func test_perform_for_returns_performance_result() -> void:
	var performer := _make_performer()
	var recipient := _make_witness(10)
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer, 10: recipient}
	var action := _make_action("PERFORM_FOR", 10)
	var ctx := _make_ctx()

	var result := ActionExecutor.execute(
		action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_eq(result["action_id"], "PERFORM_FOR")
	assert_true(result["effects"].has("performance_applied"))
	assert_eq(result["effects"]["recipient_id"], 10)


func test_perform_for_no_recipient_fallback() -> void:
	var performer := _make_performer()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer}
	var action := _make_action("PERFORM_FOR", 99)
	var ctx := _make_ctx()

	var result := ActionExecutor.execute(
		action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_false(result["effects"].has("performance_applied"))


func test_perform_for_does_not_increment_fatigue() -> void:
	var performer := _make_performer()
	var recipient := _make_witness(10)
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars_by_id := {1: performer, 10: recipient}
	var action := _make_action("PERFORM_FOR", 10)
	var ctx := _make_ctx()

	ActionExecutor.execute(action, performer, ctx, dice, {}, {}, chars_by_id)

	assert_eq(performer.pieces_seen.get("_performance_count_today", 0), 0)


# ==============================================================================
# Daily fatigue reset
# ==============================================================================

func test_daily_reset_clears_performance_fatigue() -> void:
	var performer := _make_performer()
	performer.pieces_seen["_performance_count_today"] = 3
	performer.action_points_current = 0
	performer.action_points_max = 2

	DayOrchestrator._reset_all_ap([performer])

	assert_false(performer.pieces_seen.has("_performance_count_today"))
	assert_eq(performer.action_points_current, 2)
