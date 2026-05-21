extends GutTest


var _prisoner: L5RCharacterData
var _guard: L5RCharacterData
var _binder: L5RCharacterData
var _rescuer: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_engine = DiceEngine.new(42)

	_prisoner = L5RCharacterData.new()
	_prisoner.character_id = 1
	_prisoner.agility = 4
	_prisoner.skills = {"Sleight of Hand": 3, "Stealth": 3}
	_prisoner.honor = 5.0

	_guard = L5RCharacterData.new()
	_guard.character_id = 2
	_guard.perception = 3
	_guard.skills = {"Investigation": 3}

	_binder = L5RCharacterData.new()
	_binder.character_id = 3
	_binder.intelligence = 4
	_binder.skills = {"Sailing": 3}

	_rescuer = L5RCharacterData.new()
	_rescuer.character_id = 4
	_rescuer.strength = 5


# ==============================================================================
# Material TNs
# ==============================================================================

func test_simple_rope_tn_15() -> void:
	assert_eq(BoundEscapeSystem.MATERIAL_TN[BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE], 15)


func test_quality_rope_tn_20() -> void:
	assert_eq(BoundEscapeSystem.MATERIAL_TN[BoundEscapeSystem.BindingMaterial.QUALITY_ROPE], 20)


func test_chains_tn_25() -> void:
	assert_eq(BoundEscapeSystem.MATERIAL_TN[BoundEscapeSystem.BindingMaterial.CHAINS], 25)


func test_high_grade_chains_tn_30() -> void:
	assert_eq(BoundEscapeSystem.MATERIAL_TN[BoundEscapeSystem.BindingMaterial.HIGH_GRADE_CHAINS], 30)


# ==============================================================================
# State Factory
# ==============================================================================

func test_create_bound_state() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.QUALITY_ROPE, 100)
	assert_eq(s["character_id"], 1)
	assert_eq(s["binder_id"], 3)
	assert_eq(s["state"], BoundEscapeSystem.BoundState.BOUND)
	assert_eq(s["escape_tn"], 20)
	assert_eq(s["escape_attempts_today"], 0)
	assert_eq(s["times_rebound"], 0)


func test_create_bound_state_custom_tn() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100, 25)
	assert_eq(s["escape_tn"], 25)


# ==============================================================================
# Knotwork Binding
# ==============================================================================

func test_knotwork_binding_sets_tn() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_knotwork_binding(_binder, 1, _engine, 100)
	assert_true(r["binding_tn"] >= 15)
	assert_eq(r["state"]["binder_id"], _binder.character_id)
	assert_eq(r["state"]["state"], BoundEscapeSystem.BoundState.BOUND)


func test_knotwork_binding_minimum_tn_15() -> void:
	var weak_binder: L5RCharacterData = L5RCharacterData.new()
	weak_binder.character_id = 99
	weak_binder.intelligence = 1
	weak_binder.skills = {}
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = BoundEscapeSystem.resolve_knotwork_binding(weak_binder, 1, e, 100)
	assert_true(r["binding_tn"] >= 15)


# ==============================================================================
# Escape Attempt
# ==============================================================================

func test_can_attempt_escape_first_try() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	assert_true(BoundEscapeSystem.can_attempt_escape(s, 101))


func test_cannot_attempt_if_already_escaped() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	s["state"] = BoundEscapeSystem.BoundState.ESCAPED_BONDS
	assert_false(BoundEscapeSystem.can_attempt_escape(s, 101))


func test_cannot_attempt_twice_same_day() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
	assert_false(BoundEscapeSystem.can_attempt_escape(s, 101))


func test_can_attempt_next_day() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
	if s["state"] == BoundEscapeSystem.BoundState.BOUND:
		assert_true(BoundEscapeSystem.can_attempt_escape(s, 102))
	else:
		pass_test("Prisoner escaped on first attempt — next-day path not tested")


func test_escape_applies_honor_cost() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var starting: float = _prisoner.honor
	BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
	assert_true(_prisoner.honor < starting)


func test_escape_generates_quiet_noise() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var r: Dictionary = BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
	assert_eq(r["noise_level"], BoundEscapeSystem.NoiseLevel.QUIET)
	assert_eq(r["noise_range"], 3)


func test_successful_escape_changes_state() -> void:
	var skilled: L5RCharacterData = L5RCharacterData.new()
	skilled.character_id = 10
	skilled.agility = 6
	skilled.skills = {"Sleight of Hand": 6}
	skilled.honor = 5.0
	var s: Dictionary = BoundEscapeSystem.create_bound_state(10, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = BoundEscapeSystem.resolve_escape_attempt(skilled, s, e, 101)
	if r["success"]:
		assert_eq(s["state"], BoundEscapeSystem.BoundState.ESCAPED_BONDS)


func test_no_attempts_remaining_returns_reason() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
	if s["state"] == BoundEscapeSystem.BoundState.BOUND:
		var r: Dictionary = BoundEscapeSystem.resolve_escape_attempt(_prisoner, s, _engine, 101)
		assert_false(r["success"])
		assert_eq(r["reason"], "no_attempts_remaining")
	else:
		pass_test("Prisoner escaped on first attempt — no-attempts path not tested")


# ==============================================================================
# Guard Detection
# ==============================================================================

func test_guard_detects_no_noise() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.NONE, 1, _engine
	)
	assert_false(r["detected"])


func test_guard_out_of_range() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.QUIET, 5, _engine
	)
	assert_false(r["detected"])
	assert_eq(r["reason"], "out_of_range")


func test_guard_within_quiet_range() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.QUIET, 2, _engine
	)
	assert_has(r, "detected")
	assert_has(r, "roll_total")
	assert_has(r, "tn")


func test_guard_moderate_noise_range() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.MODERATE, 5, _engine
	)
	assert_has(r, "detected")


func test_guard_moderate_out_of_range() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.MODERATE, 7, _engine
	)
	assert_false(r["detected"])


func test_guard_tn_increases_with_distance() -> void:
	var r1: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.QUIET, 1, DiceEngine.new(42)
	)
	var r2: Dictionary = BoundEscapeSystem.resolve_guard_detection(
		_guard, BoundEscapeSystem.NoiseLevel.QUIET, 3, DiceEngine.new(42)
	)
	assert_true(r2["tn"] > r1["tn"])


# ==============================================================================
# Rebinding
# ==============================================================================

func test_rebind_increases_tn() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var original_tn: int = s["escape_tn"]
	BoundEscapeSystem.rebind(s)
	assert_eq(s["escape_tn"], original_tn + 5)
	assert_eq(s["state"], BoundEscapeSystem.BoundState.BOUND)
	assert_eq(s["times_rebound"], 1)


func test_rebind_stacks() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	BoundEscapeSystem.rebind(s)
	BoundEscapeSystem.rebind(s)
	assert_eq(s["escape_tn"], 25)
	assert_eq(s["times_rebound"], 2)


func test_rebind_resets_state_from_escaped() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	s["state"] = BoundEscapeSystem.BoundState.ESCAPED_BONDS
	BoundEscapeSystem.rebind(s)
	assert_eq(s["state"], BoundEscapeSystem.BoundState.BOUND)


# ==============================================================================
# Location Escape
# ==============================================================================

func test_location_escape_success() -> void:
	var skilled: L5RCharacterData = L5RCharacterData.new()
	skilled.agility = 5
	skilled.skills = {"Stealth": 5}
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = BoundEscapeSystem.resolve_location_escape(skilled, 15, e)
	if r["success"]:
		assert_true(r["fully_free"])


func test_location_escape_returns_tn() -> void:
	var r: Dictionary = BoundEscapeSystem.resolve_location_escape(_prisoner, 20, _engine)
	assert_eq(r["tn"], 20)
	assert_has(r, "roll_total")


# ==============================================================================
# Free Ally — Rope
# ==============================================================================

func test_free_ally_rope_no_blade() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_rope(s, false)
	assert_false(r["success"])
	assert_eq(r["reason"], "no_blade")


func test_free_ally_rope_success() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_rope(s, true)
	assert_true(r["success"])
	assert_eq(s["state"], BoundEscapeSystem.BoundState.FREE)
	assert_eq(r["noise_level"], BoundEscapeSystem.NoiseLevel.QUIET)


func test_free_ally_rope_quality_rope() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.QUALITY_ROPE, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_rope(s, true)
	assert_true(r["success"])


func test_free_ally_rope_fails_on_chains() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.CHAINS, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_rope(s, true)
	assert_false(r["success"])
	assert_eq(r["reason"], "not_rope")


# ==============================================================================
# Free Ally — Chains
# ==============================================================================

func test_free_ally_chains_with_key() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.CHAINS, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_chains(_rescuer, s, true, false, _engine)
	assert_true(r["success"])
	assert_eq(r["method"], "key")
	assert_eq(s["state"], BoundEscapeSystem.BoundState.FREE)


func test_free_ally_chains_no_tool() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.CHAINS, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_chains(_rescuer, s, false, false, _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "no_tool")


func test_free_ally_chains_force_attempt() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.CHAINS, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_chains(_rescuer, s, false, true, _engine)
	assert_has(r, "roll_total")
	assert_eq(r["tn"], 25)
	assert_eq(r["method"], "force")
	assert_eq(r["noise_level"], BoundEscapeSystem.NoiseLevel.MODERATE)


func test_free_ally_chains_not_chains() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.SIMPLE_ROPE, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_chains(_rescuer, s, false, true, _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "not_chains")


func test_free_ally_high_grade_chains() -> void:
	var s: Dictionary = BoundEscapeSystem.create_bound_state(1, 3, BoundEscapeSystem.BindingMaterial.HIGH_GRADE_CHAINS, 100)
	var r: Dictionary = BoundEscapeSystem.free_ally_chains(_rescuer, s, true, false, _engine)
	assert_true(r["success"])


# ==============================================================================
# Action Filter
# ==============================================================================

func test_charm_allowed_while_bound() -> void:
	assert_true(BoundEscapeSystem.is_action_allowed_while_bound("CHARM"))


func test_negotiate_allowed_while_bound() -> void:
	assert_true(BoundEscapeSystem.is_action_allowed_while_bound("NEGOTIATE"))


func test_attack_not_allowed_while_bound() -> void:
	assert_false(BoundEscapeSystem.is_action_allowed_while_bound("ATTACK"))


func test_travel_not_allowed_while_bound() -> void:
	assert_false(BoundEscapeSystem.is_action_allowed_while_bound("BEGIN_TRAVEL"))


func test_cast_spell_allowed() -> void:
	assert_true(BoundEscapeSystem.is_action_allowed_while_bound("CAST_SPELL"))


func test_filter_actions_removes_forbidden() -> void:
	var actions: Array = ["CHARM", "ATTACK", "NEGOTIATE", "BEGIN_TRAVEL", "CAST_SPELL"]
	var filtered: Array = BoundEscapeSystem.filter_actions_for_bound(actions)
	assert_eq(filtered.size(), 3)
	assert_true("CHARM" in filtered)
	assert_true("NEGOTIATE" in filtered)
	assert_true("CAST_SPELL" in filtered)
	assert_false("ATTACK" in filtered)


# -- Technique bonus integration (SkillResolver routing) -----------------------

func test_kitsuki_guard_gets_free_raise_on_detection() -> void:
	var kitsuki_guard: L5RCharacterData = L5RCharacterData.new()
	kitsuki_guard.character_id = 80
	kitsuki_guard.school = "Kitsuki Investigator"
	kitsuki_guard.perception = 3
	kitsuki_guard.awareness = 3
	kitsuki_guard.intelligence = 3
	kitsuki_guard.willpower = 2
	kitsuki_guard.stamina = 2
	kitsuki_guard.strength = 2
	kitsuki_guard.agility = 2
	kitsuki_guard.reflexes = 2
	kitsuki_guard.void_ring = 2
	kitsuki_guard.skills = {"Investigation": 2}

	var generic_guard: L5RCharacterData = L5RCharacterData.new()
	generic_guard.character_id = 81
	generic_guard.school = "Bayushi Bushi"
	generic_guard.perception = 3
	generic_guard.awareness = 3
	generic_guard.intelligence = 3
	generic_guard.willpower = 2
	generic_guard.stamina = 2
	generic_guard.strength = 2
	generic_guard.agility = 2
	generic_guard.reflexes = 2
	generic_guard.void_ring = 2
	generic_guard.skills = {"Investigation": 2}

	var kitsuki_total: int = 0
	var generic_total: int = 0
	var trials: int = 200
	for i: int in range(trials):
		var d1: DiceEngine = DiceEngine.new(i * 11)
		var r1: Dictionary = BoundEscapeSystem.resolve_guard_detection(
			kitsuki_guard, BoundEscapeSystem.NoiseLevel.QUIET, 1, d1,
		)
		kitsuki_total += r1.get("roll_total", 0)
		var d2: DiceEngine = DiceEngine.new(i * 11)
		var r2: Dictionary = BoundEscapeSystem.resolve_guard_detection(
			generic_guard, BoundEscapeSystem.NoiseLevel.QUIET, 1, d2,
		)
		generic_total += r2.get("roll_total", 0)

	assert_true(
		kitsuki_total > generic_total,
		"Kitsuki guard should average higher due to Investigation free raise"
	)
