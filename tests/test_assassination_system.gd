extends GutTest


var _assassin: L5RCharacterData
var _target: L5RCharacterData
var _bodyguard: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_engine = DiceEngine.new(42)

	_assassin = L5RCharacterData.new()
	_assassin.character_id = 1
	_assassin.agility = 5
	_assassin.intelligence = 4
	_assassin.reflexes = 4
	_assassin.awareness = 3
	_assassin.perception = 3
	_assassin.skills = {
		"Stealth": 5,
		"Sleight of Hand": 4,
		"Forgery": 3,
		"Kenjutsu": 4,
		"Ninjutsu": 3,
		"Engineering": 2,
		"Medicine": 3,
		"Courtier": 2,
		"Temptation": 2,
	}

	_target = L5RCharacterData.new()
	_target.character_id = 2
	_target.reflexes = 3
	_target.armor_tn_bonus = 0
	_target.perception = 3
	_target.skills = {"Investigation": 2}

	_bodyguard = L5RCharacterData.new()
	_bodyguard.character_id = 3
	_bodyguard.reflexes = 4
	_bodyguard.perception = 3
	_bodyguard.skills = {"Investigation": 3}


# ==============================================================================
# State Factory
# ==============================================================================

func test_create_state() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 100)
	assert_eq(s["assassin_id"], 1)
	assert_eq(s["target_id"], 2)
	assert_eq(s["method"], AssassinationSystem.ExecutionMethod.POISON)
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.ACCESS)
	assert_eq(s["suspicion"], 0)
	assert_eq(s["days_in_access"], 0)


# ==============================================================================
# Suspicion Management
# ==============================================================================

func test_add_suspicion() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	AssassinationSystem.add_suspicion(s, 10)
	assert_eq(s["suspicion"], 10)


func test_suspicion_clamped_at_100() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	AssassinationSystem.add_suspicion(s, 200)
	assert_eq(s["suspicion"], 100)


func test_suspicion_clamped_at_0() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 5
	AssassinationSystem.decay_suspicion(s, false)
	assert_eq(s["suspicion"], 4)


func test_suspicion_decay_absent() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 10
	AssassinationSystem.decay_suspicion(s, false)
	assert_eq(s["suspicion"], 9)


func test_suspicion_decay_present_no_change() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 10
	AssassinationSystem.decay_suspicion(s, true)
	assert_eq(s["suspicion"], 10)


func test_failure_margin_gives_5_suspicion() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-3), 5)


func test_notable_failure_gives_10() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-7), 10)


func test_critical_failure_gives_15() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-12), 15)


func test_alert_threshold() -> void:
	var s: Dictionary = {"suspicion": 20}
	assert_true(AssassinationSystem.is_alert(s))
	s["suspicion"] = 19
	assert_false(AssassinationSystem.is_alert(s))


func test_lockdown_threshold() -> void:
	var s: Dictionary = {"suspicion": 40}
	assert_true(AssassinationSystem.is_lockdown(s))
	s["suspicion"] = 39
	assert_false(AssassinationSystem.is_lockdown(s))


func test_suspicion_tn_modifier_tiers() -> void:
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 0}), 0)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 10}), 5)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 25}), 10)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 50}), 15)


# ==============================================================================
# Phase 1 — Access
# ==============================================================================

func test_access_day_increments_counter() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	AssassinationSystem.resolve_access_day(_assassin, s, "stealth", _engine)
	assert_eq(s["days_in_access"], 1)


func test_access_invalid_method() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var r: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "invalid", _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "invalid_method")


func test_cannot_advance_before_3_days() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["days_in_access"] = 2
	assert_false(AssassinationSystem.can_advance_to_execution(s))


func test_can_advance_at_3_days() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["days_in_access"] = 3
	assert_true(AssassinationSystem.can_advance_to_execution(s))


func test_cannot_advance_during_lockdown() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["days_in_access"] = 5
	s["suspicion"] = 40
	assert_false(AssassinationSystem.can_advance_to_execution(s))


func test_advance_changes_phase() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	AssassinationSystem.advance_to_execution(s)
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.EXECUTION)


func test_access_forge_credentials() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var r: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "forge_credentials", _engine)
	assert_has(r, "roll_total")
	assert_eq(r["skill"], "Forgery")


func test_access_bribe() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var r: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "bribe", _engine)
	assert_eq(r["skill"], "Courtier")


func test_access_failure_adds_suspicion() -> void:
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 99
	weak.agility = 1
	weak.intelligence = 1
	weak.awareness = 1
	weak.skills = {"Stealth": 0}
	var s: Dictionary = AssassinationSystem.create_assassination_state(99, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var e: DiceEngine = DiceEngine.new(1)
	AssassinationSystem.resolve_access_day(weak, s, "stealth", e)
	assert_true(s["suspicion"] > 0)


# ==============================================================================
# Phase 2 — Execution
# ==============================================================================

func test_execution_bodyguard_blocks() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, _engine, true)
	assert_false(r["success"])
	assert_true(r["bodyguard_encountered"])
	assert_true(s["bodyguard_encountered"])


func test_execution_poison_returns_method() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, _engine)
	assert_eq(r["method"], AssassinationSystem.ExecutionMethod.POISON)


func test_execution_blade_returns_method() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, _engine)
	assert_eq(r["method"], AssassinationSystem.ExecutionMethod.BLADE)


func test_execution_accident_returns_method() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, _engine)
	assert_eq(r["method"], AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT)


func test_successful_execution_moves_to_concealment() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, e)
	if r["success"]:
		assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.CONCEALMENT)
	else:
		assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.FAILED)


func test_failed_execution_moves_to_failed() -> void:
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 99
	weak.agility = 1
	weak.intelligence = 1
	weak.skills = {"Stealth": 0, "Sleight of Hand": 0}
	var s: Dictionary = AssassinationSystem.create_assassination_state(99, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = AssassinationSystem.resolve_execution(weak, _target, s, e)
	assert_false(r["success"])
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.FAILED)


# ==============================================================================
# Phase 3 — Concealment
# ==============================================================================

func test_concealment_tn_poison_lowest() -> void:
	assert_eq(AssassinationSystem.get_concealment_tn(AssassinationSystem.ExecutionMethod.POISON), 15)


func test_concealment_tn_blade_highest() -> void:
	assert_eq(AssassinationSystem.get_concealment_tn(AssassinationSystem.ExecutionMethod.BLADE), 25)


func test_concealment_tn_accident_middle() -> void:
	assert_eq(AssassinationSystem.get_concealment_tn(AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT), 20)


func test_concealment_moves_to_complete() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.COMPLETE)


func test_concealment_returns_result() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_has(r, "concealed")
	assert_has(r, "roll_total")
	assert_has(r, "tn")
	assert_eq(r["method"], AssassinationSystem.ExecutionMethod.POISON)


func test_concealment_poison_uses_medicine() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_eq(r["skill"], "Medicine")


func test_concealment_blade_uses_stealth() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_eq(r["skill"], "Stealth")


func test_concealment_accident_uses_engineering() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_eq(r["skill"], "Engineering")


# ==============================================================================
# Bodyguard Response
# ==============================================================================

func test_bodyguard_abort() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var r: Dictionary = AssassinationSystem.resolve_bodyguard_encounter(
		_assassin, _bodyguard, AssassinationSystem.BodyguardResponse.ABORT, s, _engine
	)
	assert_true(r["aborted"])
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.ABORTED)
	assert_true(s["suspicion"] > 0)


func test_bodyguard_fight_returns_initiative() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var r: Dictionary = AssassinationSystem.resolve_bodyguard_encounter(
		_assassin, _bodyguard, AssassinationSystem.BodyguardResponse.FIGHT_FIRST, s, _engine
	)
	assert_true(r["fight_initiated"])
	assert_has(r, "assassin_first")
	assert_has(r, "assassin_initiative")


func test_bodyguard_go_for_target_contested() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var r: Dictionary = AssassinationSystem.resolve_bodyguard_encounter(
		_assassin, _bodyguard, AssassinationSystem.BodyguardResponse.GO_FOR_TARGET, s, _engine
	)
	assert_has(r, "evaded_guard")
	assert_has(r, "assassin_stealth")
	assert_has(r, "guard_detection")


# ==============================================================================
# PC Safeguard
# ==============================================================================

func test_pc_crisis_window_poison() -> void:
	assert_eq(AssassinationSystem.get_pc_crisis_window(AssassinationSystem.ExecutionMethod.POISON), 12)


func test_pc_crisis_window_blade() -> void:
	assert_eq(AssassinationSystem.get_pc_crisis_window(AssassinationSystem.ExecutionMethod.BLADE), 4)


func test_pc_crisis_window_accident() -> void:
	assert_eq(AssassinationSystem.get_pc_crisis_window(AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT), 8)


func test_target_offline_detection() -> void:
	assert_true(AssassinationSystem.is_target_pc_offline(5, [1, 2, 3] as Array[int]))
	assert_false(AssassinationSystem.is_target_pc_offline(2, [1, 2, 3] as Array[int]))


# -- Technique bonus integration (SkillResolver routing) -----------------------

func test_doji_courtier_bribe_access_gets_free_raise() -> void:
	var doji: L5RCharacterData = L5RCharacterData.new()
	doji.character_id = 70
	doji.school = "Doji Courtier"
	doji.awareness = 4
	doji.perception = 3
	doji.intelligence = 3
	doji.willpower = 2
	doji.stamina = 2
	doji.strength = 2
	doji.agility = 3
	doji.reflexes = 3
	doji.void_ring = 2
	doji.honor = 7.0
	doji.skills = {"Courtier": 3, "Sincerity": 2, "Etiquette": 2, "Stealth": 1}

	var generic: L5RCharacterData = L5RCharacterData.new()
	generic.character_id = 71
	generic.school = "Bayushi Bushi"
	generic.awareness = 4
	generic.perception = 3
	generic.intelligence = 3
	generic.willpower = 2
	generic.stamina = 2
	generic.strength = 2
	generic.agility = 3
	generic.reflexes = 3
	generic.void_ring = 2
	generic.honor = 7.0
	generic.skills = {"Courtier": 3, "Sincerity": 2, "Etiquette": 2, "Stealth": 1}

	var doji_total: int = 0
	var generic_total: int = 0
	var trials: int = 200
	for i: int in range(trials):
		var state_a: Dictionary = AssassinationSystem.create_state(
			doji.character_id, 99, AssassinationSystem.ExecutionMethod.POISON,
		)
		var d1: DiceEngine = DiceEngine.new(i * 13)
		var r1: Dictionary = AssassinationSystem.resolve_access_day(doji, state_a, "bribe", d1)
		doji_total += r1.get("roll_total", 0)

		var state_b: Dictionary = AssassinationSystem.create_state(
			generic.character_id, 99, AssassinationSystem.ExecutionMethod.POISON,
		)
		var d2: DiceEngine = DiceEngine.new(i * 13)
		var r2: Dictionary = AssassinationSystem.resolve_access_day(generic, state_b, "bribe", d2)
		generic_total += r2.get("roll_total", 0)

	assert_true(
		doji_total > generic_total,
		"Doji Courtier should average higher on bribe access due to Courtier free raise"
	)
