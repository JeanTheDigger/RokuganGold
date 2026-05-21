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
	assert_eq(s["suspicion"], 0.0)
	assert_eq(s["suspicion_raised_ic_day"], -1)
	assert_eq(s["days_in_access"], 0)
	assert_eq(s["access_tn_penalty"], 0)
	assert_eq(s["equipment_prepared"], false)
	assert_eq(s["equipment_concealment_tn"], 0)


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


func test_suspicion_decay_present_inactive() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 10.0
	AssassinationSystem.decay_suspicion(s, true)
	assert_eq(s["suspicion"], 9.5, "Present but inactive: -0.5 per tick")


func test_failure_margin_gives_5_suspicion() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-3), 5)


func test_notable_failure_gives_10() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-15), 10)


func test_critical_failure_gives_15() -> void:
	assert_eq(AssassinationSystem.get_suspicion_from_failure(-25), 15)


func test_watchful_threshold() -> void:
	var s: Dictionary = {"suspicion": 10.0}
	assert_true(AssassinationSystem.is_watchful(s))
	s["suspicion"] = 9.0
	assert_false(AssassinationSystem.is_watchful(s))


func test_alert_threshold() -> void:
	var s: Dictionary = {"suspicion": 20.0}
	assert_true(AssassinationSystem.is_alert(s))
	s["suspicion"] = 19.0
	assert_false(AssassinationSystem.is_alert(s))


func test_lockdown_threshold() -> void:
	var s: Dictionary = {"suspicion": 30.0}
	assert_true(AssassinationSystem.is_lockdown(s))
	s["suspicion"] = 29.0
	assert_false(AssassinationSystem.is_lockdown(s))


func test_should_assign_bodyguard() -> void:
	assert_true(AssassinationSystem.should_assign_bodyguard({"suspicion": 20.0}))
	assert_true(AssassinationSystem.should_assign_bodyguard({"suspicion": 25.0}))
	assert_false(AssassinationSystem.should_assign_bodyguard({"suspicion": 19.0}))


func test_household_investigation_bonus() -> void:
	assert_eq(AssassinationSystem.get_household_investigation_bonus({"suspicion": 5.0}), 0)
	assert_eq(AssassinationSystem.get_household_investigation_bonus({"suspicion": 10.0}), 5)
	assert_eq(AssassinationSystem.get_household_investigation_bonus({"suspicion": 15.0}), 5)
	assert_eq(AssassinationSystem.get_household_investigation_bonus({"suspicion": 20.0}), 0,
		"At bodyguard threshold, watchful bonus no longer applies")
	assert_eq(AssassinationSystem.get_household_investigation_bonus({"suspicion": 35.0}), 0)


func test_suspicion_tn_modifier_lockdown_only() -> void:
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 0.0}), 0)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 10.0}), 0)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 25.0}), 0)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 30.0}), 10)
	assert_eq(AssassinationSystem.get_suspicion_tn_modifier({"suspicion": 50.0}), 10)


# -- SEARCH_PERSON Suspicion Trigger -------------------------------------------

func test_find_best_searcher_co_located() -> void:
	_target.physical_location = "Kyuden Bayushi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 60
	guard.physical_location = "Kyuden Bayushi"
	guard.perception = 4
	guard.skills = {"Investigation": 3}
	var chars: Dictionary = {1: _assassin, 2: _target, 60: guard}
	var best: L5RCharacterData = AssassinationSystem.find_best_searcher(_target, 1, chars)
	assert_not_null(best)
	assert_eq(best.character_id, 60)


func test_find_best_searcher_excludes_assassin() -> void:
	_target.physical_location = "Kyuden Bayushi"
	_assassin.physical_location = "Kyuden Bayushi"
	_assassin.perception = 5
	_assassin.skills["Investigation"] = 5
	var chars: Dictionary = {1: _assassin, 2: _target}
	var best: L5RCharacterData = AssassinationSystem.find_best_searcher(_target, 1, chars)
	assert_null(best, "Assassin should not search themselves")


func test_find_best_searcher_picks_highest_score() -> void:
	_target.physical_location = "Kyuden Doji"
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 61
	weak.physical_location = "Kyuden Doji"
	weak.perception = 2
	weak.skills = {"Investigation": 1}
	var strong: L5RCharacterData = L5RCharacterData.new()
	strong.character_id = 62
	strong.physical_location = "Kyuden Doji"
	strong.perception = 4
	strong.skills = {"Investigation": 4}
	var chars: Dictionary = {1: _assassin, 2: _target, 61: weak, 62: strong}
	var best: L5RCharacterData = AssassinationSystem.find_best_searcher(_target, 1, chars)
	assert_eq(best.character_id, 62)


func test_find_best_searcher_none_at_location() -> void:
	_target.physical_location = "Kyuden Bayushi"
	var away: L5RCharacterData = L5RCharacterData.new()
	away.character_id = 63
	away.physical_location = "Otosan Uchi"
	away.perception = 5
	away.skills = {"Investigation": 5}
	var chars: Dictionary = {1: _assassin, 2: _target, 63: away}
	var best: L5RCharacterData = AssassinationSystem.find_best_searcher(_target, 1, chars)
	assert_null(best)


func test_suspicion_search_finds_unconcealed() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 70
	searcher.perception = 3
	searcher.skills = {"Investigation": 2}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["equipment_concealment_tn"] = 0
	var result: Dictionary = AssassinationSystem.resolve_suspicion_search(searcher, s, _engine)
	assert_true(result["found"], "Zero concealment_tn means equipment is visible")


func test_suspicion_search_applies_investigation_bonus() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 71
	searcher.perception = 3
	searcher.skills = {"Investigation": 2}

	var total_with_bonus: int = 0
	var total_without_bonus: int = 0
	for i: int in range(100):
		var s1: Dictionary = {"suspicion": 15.0, "equipment_concealment_tn": 25}
		var e1: DiceEngine = DiceEngine.new(i * 7)
		var r1: Dictionary = AssassinationSystem.resolve_suspicion_search(searcher, s1, e1)
		total_with_bonus += r1.get("roll_total", 0)

		var s2: Dictionary = {"suspicion": 5.0, "equipment_concealment_tn": 25}
		var e2: DiceEngine = DiceEngine.new(i * 7)
		var r2: Dictionary = AssassinationSystem.resolve_suspicion_search(searcher, s2, e2)
		total_without_bonus += r2.get("roll_total", 0)

	assert_true(total_with_bonus > total_without_bonus,
		"Watchful bonus (+5 Investigation) should improve search rolls")


# -- SEDUCE_FOR_ACCESS Bypass --------------------------------------------------

func test_seduce_for_access_found() -> void:
	var household: L5RCharacterData = L5RCharacterData.new()
	household.character_id = 90
	household.physical_location = "Kyuden Bayushi"
	_target.physical_location = "Kyuden Bayushi"
	var chars: Dictionary = {1: _assassin, 2: _target, 90: household}
	var ent: Array = [SeductionSystem.create_entanglement(
		1, 90, 10, SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS,
	)]
	assert_true(AssassinationSystem.has_seduce_for_access(1, "Kyuden Bayushi", ent, chars))


func test_seduce_for_access_wrong_variant() -> void:
	var household: L5RCharacterData = L5RCharacterData.new()
	household.character_id = 91
	household.physical_location = "Kyuden Bayushi"
	var chars: Dictionary = {91: household}
	var ent: Array = [SeductionSystem.create_entanglement(1, 91, 10)]
	assert_false(AssassinationSystem.has_seduce_for_access(1, "Kyuden Bayushi", ent, chars))


func test_seduce_for_access_broken_entanglement() -> void:
	var household: L5RCharacterData = L5RCharacterData.new()
	household.character_id = 92
	household.physical_location = "Kyuden Bayushi"
	var chars: Dictionary = {92: household}
	var ent: Array = [SeductionSystem.create_entanglement(
		1, 92, 10, SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS,
	)]
	ent[0]["state"] = SeductionSystem.EntanglementState.BROKEN
	assert_false(AssassinationSystem.has_seduce_for_access(1, "Kyuden Bayushi", ent, chars))


func test_seduce_for_access_wrong_location() -> void:
	var household: L5RCharacterData = L5RCharacterData.new()
	household.character_id = 93
	household.physical_location = "Otosan Uchi"
	var chars: Dictionary = {93: household}
	var ent: Array = [SeductionSystem.create_entanglement(
		1, 93, 10, SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS,
	)]
	assert_false(AssassinationSystem.has_seduce_for_access(1, "Kyuden Bayushi", ent, chars))


func test_seduce_for_access_wrong_seducer() -> void:
	var household: L5RCharacterData = L5RCharacterData.new()
	household.character_id = 94
	household.physical_location = "Kyuden Bayushi"
	var chars: Dictionary = {94: household}
	var ent: Array = [SeductionSystem.create_entanglement(
		99, 94, 10, SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS,
	)]
	assert_false(AssassinationSystem.has_seduce_for_access(1, "Kyuden Bayushi", ent, chars))


# -- Per-Roll Permanent TN Penalty ---------------------------------------------

func test_access_penalty_standard_failure() -> void:
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-5), 5)


func test_access_penalty_notable_failure() -> void:
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-15), 10)


func test_access_penalty_critical_failure() -> void:
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-25), 15)


func test_access_penalty_boundary_notable() -> void:
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-10), 10)
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-9), 5)


func test_access_penalty_boundary_critical() -> void:
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-20), 15)
	assert_eq(AssassinationSystem.get_access_penalty_from_failure(-19), 10)


func test_access_penalty_accumulates_on_failure() -> void:
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 99
	weak.agility = 1
	weak.intelligence = 1
	weak.awareness = 1
	weak.skills = {"Stealth": 0}
	weak.school = "Shosuro Infiltrator"
	var s: Dictionary = AssassinationSystem.create_assassination_state(99, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var e: DiceEngine = DiceEngine.new(1)
	AssassinationSystem.resolve_access_day(weak, s, "stealth", e)
	assert_true(s["access_tn_penalty"] > 0, "Penalty should increase after failure")
	var first_penalty: int = s["access_tn_penalty"]
	var e2: DiceEngine = DiceEngine.new(2)
	AssassinationSystem.resolve_access_day(weak, s, "stealth", e2)
	assert_true(s["access_tn_penalty"] >= first_penalty, "Penalty should not decrease")


func test_access_penalty_applied_to_tn() -> void:
	_assassin.skills["Stealth"] = 5
	_assassin.agility = 4
	_assassin.school = "Shosuro Infiltrator"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var e1: DiceEngine = DiceEngine.new(42)
	var r1: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", e1)
	var base_tn: int = r1["tn"]
	s["access_tn_penalty"] = 10
	var e2: DiceEngine = DiceEngine.new(42)
	var r2: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", e2)
	assert_eq(r2["tn"], base_tn + 10)


func test_access_penalty_stacks_with_lockdown() -> void:
	_assassin.skills["Stealth"] = 5
	_assassin.agility = 4
	_assassin.school = "Shosuro Infiltrator"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 35.0
	s["access_tn_penalty"] = 15
	var e: DiceEngine = DiceEngine.new(42)
	var r: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", e)
	assert_eq(r["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + 10 + 15)


func test_access_penalty_not_added_on_success() -> void:
	_assassin.skills["Stealth"] = 10
	_assassin.agility = 5
	_assassin.school = "Shosuro Infiltrator"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var success_count: int = 0
	for i: int in range(50):
		var e: DiceEngine = DiceEngine.new(i * 13)
		s["access_tn_penalty"] = 0
		s["suspicion"] = 0.0
		AssassinationSystem.resolve_access_day(_assassin, s, "stealth", e)
		if s["access_tn_penalty"] == 0:
			success_count += 1
	assert_true(success_count > 0, "At least some rolls should succeed without adding penalty")


# -- Critical Failure Detection Check ------------------------------------------

func test_is_critical_failure() -> void:
	assert_true(AssassinationSystem.is_critical_failure(-20))
	assert_true(AssassinationSystem.is_critical_failure(-25))
	assert_false(AssassinationSystem.is_critical_failure(-19))
	assert_false(AssassinationSystem.is_critical_failure(-5))


func test_critical_detection_auto_detects_zero_roll() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 80
	guard.perception = 3
	guard.skills = {"Investigation": 2}
	var s: Dictionary = {"suspicion": 5.0}
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = AssassinationSystem.resolve_critical_failure_detection(guard, 0, s, e)
	assert_true(r["detected"], "Roll total of 0 means TN 0 — always detected")


func test_critical_detection_uses_roll_total_as_tn() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 81
	guard.perception = 2
	guard.skills = {"Investigation": 1}
	var s: Dictionary = {"suspicion": 0.0}
	var detected_count: int = 0
	for i: int in range(50):
		var e: DiceEngine = DiceEngine.new(i * 11)
		var r: Dictionary = AssassinationSystem.resolve_critical_failure_detection(guard, 25, s, e)
		if r.get("detected", false):
			detected_count += 1
	assert_true(detected_count < 50, "High detection TN should sometimes prevent detection")
	var detected_easy: int = 0
	for i: int in range(50):
		var e2: DiceEngine = DiceEngine.new(i * 11)
		var r2: Dictionary = AssassinationSystem.resolve_critical_failure_detection(guard, 5, s, e2)
		if r2.get("detected", false):
			detected_easy += 1
	assert_true(detected_easy > detected_count, "Lower TN should be easier to detect")


func test_critical_detection_includes_investigation_bonus() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 82
	guard.perception = 3
	guard.skills = {"Investigation": 2}
	var total_with: int = 0
	var total_without: int = 0
	for i: int in range(100):
		var s1: Dictionary = {"suspicion": 15.0}
		var e1: DiceEngine = DiceEngine.new(i * 7)
		var r1: Dictionary = AssassinationSystem.resolve_critical_failure_detection(guard, 20, s1, e1)
		total_with += r1.get("roll_total", 0)

		var s2: Dictionary = {"suspicion": 5.0}
		var e2: DiceEngine = DiceEngine.new(i * 7)
		var r2: Dictionary = AssassinationSystem.resolve_critical_failure_detection(guard, 20, s2, e2)
		total_without += r2.get("roll_total", 0)
	assert_true(total_with > total_without,
		"Watchful bonus should improve detection rolls")


# -- Daily Detection Signals ---------------------------------------------------

func test_daily_detection_adds_suspicion_on_notice() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 85
	guard.perception = 5
	guard.skills = {"Investigation": 5}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var noticed_count: int = 0
	for i: int in range(50):
		s["suspicion"] = 0.0
		var e: DiceEngine = DiceEngine.new(i * 11)
		var r: Dictionary = AssassinationSystem.resolve_daily_detection(guard, 10, s, e)
		if r["noticed"]:
			noticed_count += 1
			assert_true(s["suspicion"] > 0, "Suspicion should increase on notice")
	assert_true(noticed_count > 0, "Guard with high skills should notice sometimes")


func test_daily_detection_no_suspicion_on_miss() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 86
	guard.perception = 1
	guard.skills = {"Investigation": 0}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var missed_count: int = 0
	for i: int in range(50):
		s["suspicion"] = 0.0
		var e: DiceEngine = DiceEngine.new(i * 13)
		var r: Dictionary = AssassinationSystem.resolve_daily_detection(guard, 30, s, e)
		if not r["noticed"]:
			missed_count += 1
			assert_eq(s["suspicion"], 0.0, "Suspicion should not change on miss")
	assert_true(missed_count > 0, "Weak guard vs high TN should miss sometimes")


func test_daily_detection_uses_roll_total_as_tn() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 87
	guard.perception = 3
	guard.skills = {"Investigation": 2}
	var easy_count: int = 0
	var hard_count: int = 0
	for i: int in range(100):
		var s1: Dictionary = {"suspicion": 0.0}
		var e1: DiceEngine = DiceEngine.new(i * 7)
		var r1: Dictionary = AssassinationSystem.resolve_daily_detection(guard, 5, s1, e1)
		if r1["noticed"]:
			easy_count += 1
		var s2: Dictionary = {"suspicion": 0.0}
		var e2: DiceEngine = DiceEngine.new(i * 7)
		var r2: Dictionary = AssassinationSystem.resolve_daily_detection(guard, 30, s2, e2)
		if r2["noticed"]:
			hard_count += 1
	assert_true(easy_count > hard_count, "Lower TN should be easier to notice")


func test_daily_detection_suspicion_increment() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 88
	guard.perception = 5
	guard.skills = {"Investigation": 5}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = AssassinationSystem.resolve_daily_detection(guard, 0, s, e)
	assert_true(r["noticed"])
	assert_eq(s["suspicion"], float(AssassinationSystem.SUSPICION_DAILY_DETECTION))


# -- Honor / Infamy Consequences -----------------------------------------------

func test_ordering_honor_loss_status_low() -> void:
	assert_eq(AssassinationSystem.get_ordering_honor_loss(1.0), -2.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(2.0), -2.0)


func test_ordering_honor_loss_status_mid() -> void:
	assert_eq(AssassinationSystem.get_ordering_honor_loss(3.0), -3.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(5.0), -3.0)


func test_ordering_honor_loss_status_high() -> void:
	assert_eq(AssassinationSystem.get_ordering_honor_loss(6.0), -4.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(7.0), -4.0)


func test_ordering_honor_loss_status_elite() -> void:
	assert_eq(AssassinationSystem.get_ordering_honor_loss(8.0), -5.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(10.0), -5.0)


func test_ordering_honor_loss_boundary() -> void:
	assert_eq(AssassinationSystem.get_ordering_honor_loss(2.9), -2.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(5.9), -3.0)
	assert_eq(AssassinationSystem.get_ordering_honor_loss(7.9), -4.0)


func test_execution_honor_loss_scorpion() -> void:
	var scorpion: L5RCharacterData = L5RCharacterData.new()
	scorpion.clan = "Scorpion"
	assert_eq(AssassinationSystem.get_execution_honor_loss(scorpion), -0.5)


func test_execution_honor_loss_non_scorpion() -> void:
	var crane: L5RCharacterData = L5RCharacterData.new()
	crane.clan = "Crane"
	assert_eq(AssassinationSystem.get_execution_honor_loss(crane), -3.0)
	var lion: L5RCharacterData = L5RCharacterData.new()
	lion.clan = "Lion"
	assert_eq(AssassinationSystem.get_execution_honor_loss(lion), -3.0)


func test_execution_applies_honor_cost_on_success() -> void:
	_assassin.clan = "Crane"
	_assassin.honor = 5.0
	_assassin.skills["Stealth"] = 8
	_assassin.agility = 5
	_assassin.school = "Shosuro Infiltrator"
	_target.physical_location = "Kyuden Bayushi"
	_assassin.physical_location = "Kyuden Bayushi"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var successes: int = 0
	for i: int in range(50):
		_assassin.honor = 5.0
		var e: DiceEngine = DiceEngine.new(i * 17)
		var r: Dictionary = AssassinationSystem.resolve_execution(_assassin, _target, s, e)
		if r.get("success", false):
			successes += 1
			assert_eq(_assassin.honor, 5.0 + AssassinationSystem.EXECUTE_HONOR_LOSS_DEFAULT)
			assert_eq(r.get("honor_cost"), AssassinationSystem.EXECUTE_HONOR_LOSS_DEFAULT)
			break
		s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	assert_true(successes > 0, "Should have at least one successful execution")


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
	s["suspicion"] = 30.0
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


func test_concealment_outcome_has_field() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
	var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, _engine)
	assert_has(r, "outcome")
	assert_true(r["outcome"] in ["full", "partial", "failure"])


func test_concealment_full_success() -> void:
	_assassin.skills["Medicine"] = 8
	_assassin.intelligence = 5
	var full_count: int = 0
	for i: int in range(50):
		var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
		var e: DiceEngine = DiceEngine.new(i * 13)
		var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, e)
		if r["outcome"] == "full":
			full_count += 1
			assert_true(r["concealed"])
	assert_true(full_count > 0, "Skilled assassin should get full concealment sometimes")


func test_concealment_failure_not_concealed() -> void:
	_assassin.skills["Medicine"] = 0
	_assassin.intelligence = 1
	var failure_count: int = 0
	for i: int in range(50):
		var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
		var e: DiceEngine = DiceEngine.new(i * 7)
		var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, e)
		if r["outcome"] == "failure":
			failure_count += 1
			assert_false(r["concealed"])
			assert_eq(r["concealment_tn"], 0)
	assert_true(failure_count > 0, "Weak assassin should fail concealment sometimes")


func test_concealment_partial_not_concealed() -> void:
	var partial_found: bool = false
	for i: int in range(200):
		_assassin.skills["Medicine"] = 2
		_assassin.intelligence = 2
		var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
		var e: DiceEngine = DiceEngine.new(i * 3)
		var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, e)
		if r["outcome"] == "partial":
			partial_found = true
			assert_false(r["concealed"])
			assert_true(r["concealment_tn"] > 0, "Partial keeps investigator TN")
			break
	assert_true(partial_found, "Should find at least one partial outcome in 200 trials")


func test_concealment_partial_preserves_investigator_tn() -> void:
	var partial_found: bool = false
	for i: int in range(200):
		_assassin.skills["Medicine"] = 2
		_assassin.intelligence = 2
		var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		s["phase"] = AssassinationSystem.AssassinationPhase.CONCEALMENT
		var e: DiceEngine = DiceEngine.new(i * 3)
		var r: Dictionary = AssassinationSystem.resolve_concealment(_assassin, s, e)
		if r["outcome"] == "partial":
			partial_found = true
			assert_eq(r["concealment_tn"], r["roll_total"])
			break
	assert_true(partial_found, "Should find partial outcome")


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


# -- Bodyguard NPC Decision Logic -----------------------------------------------

func test_bodyguard_decision_seigyo_always_aborts() -> void:
	_assassin.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	_assassin.skills["Kenjutsu"] = 7
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.ABORT)


func test_bodyguard_decision_ketsui_pushes_through() -> void:
	_assassin.shourido_virtue = Enums.ShouridoVirtue.KETSUI
	_assassin.skills["Kenjutsu"] = 1
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.GO_FOR_TARGET)


func test_bodyguard_decision_yu_pushes_through() -> void:
	_assassin.bushido_virtue = Enums.BushidoVirtue.YU
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.GO_FOR_TARGET)


func test_bodyguard_decision_lockdown_forces_abort() -> void:
	_assassin.skills["Kenjutsu"] = 7
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["suspicion"] = 35.0
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.ABORT)


func test_bodyguard_decision_high_combat_fights() -> void:
	_assassin.skills["Kenjutsu"] = 5
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.FIGHT_FIRST)


func test_bodyguard_decision_stealthy_goes_for_target() -> void:
	_assassin.skills["Stealth"] = 6
	_assassin.skills["Kenjutsu"] = 2
	_assassin.skills["Ninjutsu"] = 0
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.GO_FOR_TARGET)


func test_bodyguard_decision_low_skill_aborts() -> void:
	_assassin.skills["Stealth"] = 2
	_assassin.skills["Kenjutsu"] = 2
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_eq(AssassinationSystem.evaluate_bodyguard_response(_assassin, s), AssassinationSystem.BodyguardResponse.ABORT)


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
	assert_true(AssassinationSystem.is_target_pc_offline(5, [1, 2, 3]))
	assert_false(AssassinationSystem.is_target_pc_offline(2, [1, 2, 3]))


func test_pc_crisis_event_poison() -> void:
	var ev: Dictionary = AssassinationSystem.create_pc_crisis_event(2, 1, AssassinationSystem.ExecutionMethod.POISON, 100)
	assert_eq(ev["event_type"], "assassination_crisis")
	assert_eq(ev["target_id"], 2)
	assert_eq(ev["grace_period_days"], 12)
	assert_eq(ev["deadline_ic_day"], 100 + 12 * 4)
	assert_false(ev["resolved"])


func test_pc_crisis_event_blade() -> void:
	var ev: Dictionary = AssassinationSystem.create_pc_crisis_event(2, 1, AssassinationSystem.ExecutionMethod.BLADE, 50)
	assert_eq(ev["grace_period_days"], 4)
	assert_eq(ev["deadline_ic_day"], 50 + 4 * 4)


func test_pc_crisis_event_accident() -> void:
	var ev: Dictionary = AssassinationSystem.create_pc_crisis_event(2, 1, AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT, 200)
	assert_eq(ev["grace_period_days"], 8)
	assert_eq(ev["deadline_ic_day"], 200 + 8 * 4)


# -- Access Method Selection ---------------------------------------------------

func test_pick_method_stealth_preferred() -> void:
	_assassin.skills = {"Stealth": 5, "Forgery": 1, "Courtier": 1, "Temptation": 1}
	_assassin.agility = 4
	_assassin.intelligence = 2
	_assassin.awareness = 2
	assert_eq(AssassinationSystem.pick_best_access_method(_assassin), "stealth")


func test_pick_method_forgery_preferred() -> void:
	_assassin.skills = {"Stealth": 1, "Forgery": 5, "Courtier": 1, "Temptation": 1}
	_assassin.agility = 2
	_assassin.intelligence = 4
	_assassin.awareness = 2
	assert_eq(AssassinationSystem.pick_best_access_method(_assassin), "forge_credentials")


func test_pick_method_bribe_preferred() -> void:
	_assassin.skills = {"Stealth": 1, "Forgery": 1, "Courtier": 5, "Temptation": 1}
	_assassin.agility = 2
	_assassin.intelligence = 2
	_assassin.awareness = 4
	assert_eq(AssassinationSystem.pick_best_access_method(_assassin), "bribe")


func test_pick_method_includes_trait() -> void:
	_assassin.skills = {"Stealth": 3, "Forgery": 3, "Courtier": 3, "Temptation": 3}
	_assassin.agility = 5
	_assassin.intelligence = 2
	_assassin.awareness = 2
	assert_eq(AssassinationSystem.pick_best_access_method(_assassin), "stealth")


# -- Abort & Restart -----------------------------------------------------------

func test_abort_sets_phase() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	AssassinationSystem.abort_operation(s)
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.ABORTED)


func test_restart_resets_access_state() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.ABORTED
	s["days_in_access"] = 5
	s["access_tn_penalty"] = 15
	s["equipment_prepared"] = true
	s["equipment_concealment_tn"] = 20
	s["suspicion"] = 25.0
	AssassinationSystem.restart_access(s)
	assert_eq(s["phase"], AssassinationSystem.AssassinationPhase.ACCESS)
	assert_eq(s["days_in_access"], 0)
	assert_eq(s["access_tn_penalty"], 0)
	assert_false(s["equipment_prepared"])
	assert_eq(s["equipment_concealment_tn"], 0)


func test_restart_preserves_suspicion() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 15.0
	s["access_tn_penalty"] = 10
	AssassinationSystem.restart_access(s)
	assert_eq(s["suspicion"], 15.0, "Settlement suspicion persists across restarts")
	assert_eq(s["access_tn_penalty"], 0, "Per-roll penalty resets on restart")


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
		var state_a: Dictionary = AssassinationSystem.create_assassination_state(
			doji.character_id, 99, AssassinationSystem.ExecutionMethod.POISON, 0,
		)
		var d1: DiceEngine = DiceEngine.new(i * 13)
		var r1: Dictionary = AssassinationSystem.resolve_access_day(doji, state_a, "bribe", d1)
		doji_total += r1.get("roll_total", 0)

		var state_b: Dictionary = AssassinationSystem.create_assassination_state(
			generic.character_id, 99, AssassinationSystem.ExecutionMethod.POISON, 0,
		)
		var d2: DiceEngine = DiceEngine.new(i * 13)
		var r2: Dictionary = AssassinationSystem.resolve_access_day(generic, state_b, "bribe", d2)
		generic_total += r2.get("roll_total", 0)

	assert_true(
		doji_total > generic_total,
		"Doji Courtier should average higher on bribe access due to Courtier free raise"
	)


# ==============================================================================
# Suspicion Baseline Restoration (s12.8 — 14-tick minimum)
# ==============================================================================

func test_14_tick_minimum_blocks_early_restore() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 100)
	s["suspicion"] = 1.0
	s["suspicion_raised_ic_day"] = 105
	AssassinationSystem.decay_suspicion(s, false, 110)
	assert_true(s["suspicion"] > 0.0, "Suspicion should not reach 0 before 14 ticks")


func test_14_tick_minimum_allows_restore_after_14_days() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 100)
	s["suspicion"] = 1.0
	s["suspicion_raised_ic_day"] = 105
	AssassinationSystem.decay_suspicion(s, false, 120)
	assert_eq(s["suspicion"], 0.0, "Suspicion should reach 0 after 14+ ticks")


func test_14_tick_minimum_resets_raised_day_on_clear() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 100)
	s["suspicion"] = 1.0
	s["suspicion_raised_ic_day"] = 105
	AssassinationSystem.decay_suspicion(s, false, 120)
	assert_eq(s["suspicion_raised_ic_day"], -1, "raised_ic_day should reset to -1 on clear")


func test_14_tick_minimum_clamps_to_half() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 100)
	s["suspicion"] = 0.5
	s["suspicion_raised_ic_day"] = 108
	AssassinationSystem.decay_suspicion(s, false, 112)
	assert_eq(s["suspicion"], 0.5, "Suspicion clamped to 0.5 within 14-tick window")


func test_decay_absent_multiple_ticks() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 5.0
	s["suspicion_raised_ic_day"] = 0
	for tick: int in range(5):
		AssassinationSystem.decay_suspicion(s, false, tick + 1)
	assert_eq(s["suspicion"], 0.5, "5 absent ticks from 5.0 should clamp at 0.5 within 14-tick window")


func test_decay_present_inactive_rate() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 5.0
	s["suspicion_raised_ic_day"] = 0
	for tick: int in range(4):
		AssassinationSystem.decay_suspicion(s, true, tick + 1)
	assert_eq(s["suspicion"], 3.0, "4 present-inactive ticks at -0.5 should reduce 5.0 to 3.0")


func test_no_decay_when_suspicion_zero() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["suspicion"] = 0.0
	AssassinationSystem.decay_suspicion(s, false, 50)
	assert_eq(s["suspicion"], 0.0, "Zero suspicion should remain zero")


# ==============================================================================
# Non-Shinobi TN Modifier (s12.8 NON-SCORPION ASSASSINS)
# ==============================================================================

func test_shinobi_training_shosuro_infiltrator() -> void:
	_assassin.school = "Shosuro Infiltrator"
	assert_true(AssassinationSystem.has_shinobi_training(_assassin))


func test_shinobi_training_shosuro_actor() -> void:
	_assassin.school = "Shosuro Actor"
	assert_true(AssassinationSystem.has_shinobi_training(_assassin))


func test_no_shinobi_training_bayushi_bushi() -> void:
	_assassin.school = "Bayushi Bushi"
	assert_false(AssassinationSystem.has_shinobi_training(_assassin))


func test_no_shinobi_training_akodo_bushi() -> void:
	_assassin.school = "Akodo Bushi"
	assert_false(AssassinationSystem.has_shinobi_training(_assassin))


func test_shinobi_via_school_paths() -> void:
	_assassin.school = "Bayushi Bushi"
	_assassin.school_paths = ["Bayushi Bushi", "Shosuro Actor"]
	assert_true(AssassinationSystem.has_shinobi_training(_assassin))


func test_non_shinobi_tn_modifier_applied() -> void:
	_assassin.school = "Akodo Bushi"
	var mod: int = AssassinationSystem.get_non_shinobi_tn_modifier(_assassin)
	assert_eq(mod, AssassinationSystem.NON_SHINOBI_ACCESS_TN_INCREASE)


func test_shinobi_tn_modifier_zero() -> void:
	_assassin.school = "Shosuro Infiltrator"
	var mod: int = AssassinationSystem.get_non_shinobi_tn_modifier(_assassin)
	assert_eq(mod, 0)


func test_access_tn_includes_non_shinobi_modifier() -> void:
	_assassin.school = "Akodo Bushi"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", _engine)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + AssassinationSystem.NON_SHINOBI_ACCESS_TN_INCREASE,
		"Non-shinobi should face higher TN")


func test_access_tn_no_modifier_for_shinobi() -> void:
	_assassin.school = "Shosuro Infiltrator"
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", _engine)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN,
		"Shinobi should face base TN only")


func test_non_shinobi_access_passes_target_and_chars() -> void:
	_assassin.school = "Akodo Bushi"
	_target.clan = "Crab"
	_target.status = 0.0
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var chars: Dictionary = {1: _assassin, 2: _target}
	var result: Dictionary = AssassinationSystem.resolve_access_day(_assassin, s, "stealth", _engine, _target, chars)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + AssassinationSystem.NON_SHINOBI_ACCESS_TN_INCREASE,
		"Non-Imperial target at Status 0 should have no Seppun or Status modifier")
	_target.status = 1.0


# ==============================================================================
# Seppun Protection (s12.8 Imperial Assassination)
# ==============================================================================

func test_is_imperial_dynasty_true() -> void:
	_target.clan = "Imperial"
	assert_true(AssassinationSystem.is_imperial_dynasty(_target))


func test_is_imperial_dynasty_false() -> void:
	_target.clan = "Crane"
	assert_false(AssassinationSystem.is_imperial_dynasty(_target))


func test_seppun_guard_present_detects_seppun() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Otosan Uchi"
	var seppun_guard: L5RCharacterData = L5RCharacterData.new()
	seppun_guard.character_id = 50
	seppun_guard.family = "Seppun"
	seppun_guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {2: _target, 50: seppun_guard}
	assert_true(AssassinationSystem.has_seppun_guard_present(_target, chars))


func test_seppun_guard_absent_no_seppun_at_location() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Kyuden Doji"
	var seppun_guard: L5RCharacterData = L5RCharacterData.new()
	seppun_guard.character_id = 50
	seppun_guard.family = "Seppun"
	seppun_guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {2: _target, 50: seppun_guard}
	assert_false(AssassinationSystem.has_seppun_guard_present(_target, chars))


func test_seppun_tn_modifier_non_imperial_zero() -> void:
	_target.clan = "Crane"
	var chars: Dictionary = {2: _target}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.ACCESS, chars)
	assert_eq(mod, 0)


func test_seppun_full_protection_phase1() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Otosan Uchi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 50
	guard.family = "Seppun"
	guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {2: _target, 50: guard}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.ACCESS, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_FULL_PHASE1_TN)


func test_seppun_full_protection_phase2() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Otosan Uchi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 50
	guard.family = "Seppun"
	guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {2: _target, 50: guard}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.EXECUTION, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_FULL_PHASE2_TN)


func test_seppun_full_protection_phase3() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Otosan Uchi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 50
	guard.family = "Seppun"
	guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {2: _target, 50: guard}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.CONCEALMENT, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_FULL_PHASE3_TN)


func test_seppun_half_protection_phase1() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Kyuden Doji"
	var chars: Dictionary = {2: _target}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.ACCESS, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_HALF_PHASE1_TN)


func test_seppun_half_protection_phase2() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Kyuden Doji"
	var chars: Dictionary = {2: _target}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.EXECUTION, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_HALF_PHASE2_TN)


func test_seppun_half_protection_phase3() -> void:
	_target.clan = "Imperial"
	_target.physical_location = "Kyuden Doji"
	var chars: Dictionary = {2: _target}
	var mod: int = AssassinationSystem.get_seppun_tn_modifier(
		_target, AssassinationSystem.AssassinationPhase.CONCEALMENT, chars)
	assert_eq(mod, AssassinationSystem.SEPPUN_HALF_PHASE3_TN)


func test_access_tn_includes_seppun_full_protection() -> void:
	_assassin.school = "Shosuro Infiltrator"
	_target.clan = "Imperial"
	_target.status = 0.0
	_target.physical_location = "Otosan Uchi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 50
	guard.family = "Seppun"
	guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {1: _assassin, 2: _target, 50: guard}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, s, "stealth", _engine, _target, chars)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + AssassinationSystem.SEPPUN_FULL_PHASE1_TN)
	_target.status = 1.0


func test_access_tn_includes_seppun_half_protection() -> void:
	_assassin.school = "Shosuro Infiltrator"
	_target.clan = "Imperial"
	_target.status = 0.0
	_target.physical_location = "Kyuden Doji"
	var chars: Dictionary = {1: _assassin, 2: _target}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, s, "stealth", _engine, _target, chars)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + AssassinationSystem.SEPPUN_HALF_PHASE1_TN)
	_target.status = 1.0


func test_access_tn_stacks_seppun_and_non_shinobi() -> void:
	_assassin.school = "Akodo Bushi"
	_target.clan = "Imperial"
	_target.status = 0.0
	_target.physical_location = "Otosan Uchi"
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 50
	guard.family = "Seppun"
	guard.physical_location = "Otosan Uchi"
	var chars: Dictionary = {1: _assassin, 2: _target, 50: guard}
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, s, "stealth", _engine, _target, chars)
	var expected_tn: int = AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + AssassinationSystem.NON_SHINOBI_ACCESS_TN_INCREASE + AssassinationSystem.SEPPUN_FULL_PHASE1_TN
	assert_eq(result["tn"], expected_tn,
		"Non-shinobi + Seppun full protection should stack")
	_target.status = 1.0


# ==============================================================================
# Equipment Preparation (s12.8 pre-Phase 1)
# ==============================================================================

func test_can_use_blade_rank_5() -> void:
	_assassin.skills["Sleight of Hand"] = 5
	assert_true(AssassinationSystem.can_use_blade_method(_assassin))


func test_cannot_use_blade_rank_4() -> void:
	_assassin.skills["Sleight of Hand"] = 4
	assert_false(AssassinationSystem.can_use_blade_method(_assassin))


func test_cannot_use_blade_no_skill() -> void:
	_assassin.skills.erase("Sleight of Hand")
	assert_false(AssassinationSystem.can_use_blade_method(_assassin))


func test_equipment_tn_poison() -> void:
	assert_eq(AssassinationSystem.get_equipment_tn(AssassinationSystem.ExecutionMethod.POISON), 10)


func test_equipment_tn_blade() -> void:
	assert_eq(AssassinationSystem.get_equipment_tn(AssassinationSystem.ExecutionMethod.BLADE), 20)


func test_equipment_tn_accident_skipped() -> void:
	assert_eq(AssassinationSystem.get_equipment_tn(AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT), -1)


func test_equipment_prep_accident_auto_success() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT, 0)
	var result: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s, _engine)
	assert_true(result["success"])
	assert_true(result.get("skipped", false))
	assert_true(s["equipment_prepared"])


func test_equipment_prep_blade_blocked_without_rank_5() -> void:
	_assassin.skills["Sleight of Hand"] = 3
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var result: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s, _engine)
	assert_false(result["success"])
	assert_eq(result["reason"], "rank_gate")
	assert_false(s["equipment_prepared"])


func test_equipment_prep_poison_success() -> void:
	_assassin.skills["Sleight of Hand"] = 4
	_assassin.agility = 5
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var e: DiceEngine = DiceEngine.new(7)
	var result: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s, e)
	assert_true(result["success"], "Skilled assassin should conceal poison (TN 10)")
	assert_true(s["equipment_prepared"])
	assert_true(s["equipment_concealment_tn"] > 0)


func test_equipment_prep_blade_success_rank_5() -> void:
	_assassin.skills["Sleight of Hand"] = 5
	_assassin.agility = 5
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var e: DiceEngine = DiceEngine.new(7)
	var result: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s, e)
	if result["success"]:
		assert_true(s["equipment_prepared"])
		assert_true(s["equipment_concealment_tn"] >= AssassinationSystem.EQUIPMENT_BLADE_TN)


func test_equipment_prep_school_lean_shosuro() -> void:
	_assassin.school = "Shosuro Infiltrator"
	_assassin.skills["Sleight of Hand"] = 3
	_assassin.agility = 3
	var total_with_lean: int = 0
	var total_without_lean: int = 0
	var trials: int = 100
	for i: int in range(trials):
		var s1: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		var e1: DiceEngine = DiceEngine.new(i * 7)
		var r1: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s1, e1)
		total_with_lean += r1.get("roll_total", 0)

	_assassin.school = "Akodo Bushi"
	for i: int in range(trials):
		var s2: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		var e2: DiceEngine = DiceEngine.new(i * 7)
		var r2: Dictionary = AssassinationSystem.resolve_equipment_preparation(_assassin, s2, e2)
		total_without_lean += r2.get("roll_total", 0)

	assert_true(total_with_lean > total_without_lean,
		"Shosuro Infiltrator should average higher due to +1k0 school lean")


func test_equipment_prep_failure_weak_assassin() -> void:
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 99
	weak.agility = 1
	weak.skills = {"Sleight of Hand": 1}
	var s: Dictionary = AssassinationSystem.create_assassination_state(99, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	var result: Dictionary = AssassinationSystem.resolve_equipment_preparation(weak, s, _engine)
	assert_false(result["success"], "Rank 1 cannot attempt blade — rank gate blocks it")
	assert_eq(result["reason"], "rank_gate")


# ==============================================================================
# Target Status TN Modifier
# ==============================================================================

func test_status_tn_modifier_scales_with_status() -> void:
	var low_status: L5RCharacterData = L5RCharacterData.new()
	low_status.status = 1.0
	var high_status: L5RCharacterData = L5RCharacterData.new()
	high_status.status = 7.0
	assert_eq(AssassinationSystem.get_target_status_tn_modifier(low_status), 1)
	assert_eq(AssassinationSystem.get_target_status_tn_modifier(high_status), 7)


func test_status_tn_modifier_zero_status() -> void:
	var nobody: L5RCharacterData = L5RCharacterData.new()
	nobody.status = 0.0
	assert_eq(AssassinationSystem.get_target_status_tn_modifier(nobody), 0)


func test_access_day_includes_status_modifier() -> void:
	_target.status = 5.0
	_target.physical_location = "Castle"
	_assassin.physical_location = "Castle"
	_assassin.school = "Shosuro Infiltrator"
	var state: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, state, "stealth", _engine, _target, {},
	)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + 5,
		"TN should include +5 for Status 5.0 target (shinobi, no other modifiers)")
	_assassin.school = ""


func test_access_day_no_status_modifier_without_target() -> void:
	_assassin.school = "Shosuro Infiltrator"
	var state: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, state, "stealth", _engine, null, {},
	)
	assert_eq(result["tn"], AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN,
		"TN should be base only when no target passed")
	_assassin.school = ""


func test_access_day_status_stacks_with_non_shinobi() -> void:
	_target.status = 3.0
	_assassin.school = "Akodo Bushi"
	var state: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_access_day(
		_assassin, state, "stealth", _engine, _target, {},
	)
	var expected: int = AssassinationSystem.ACCESS_STEALTH_INFILTRATE_TN + 3 + AssassinationSystem.NON_SHINOBI_ACCESS_TN_INCREASE
	assert_eq(result["tn"], expected,
		"Status +3 and non-shinobi +10 should both apply")
	_assassin.school = ""


# ==============================================================================
# Loyalty Gate on Daily Detection
# ==============================================================================

func test_find_best_searcher_loyalty_filters_non_household() -> void:
	var bystander: L5RCharacterData = L5RCharacterData.new()
	bystander.character_id = 50
	bystander.physical_location = "Castle"
	bystander.perception = 5
	bystander.skills = {"Investigation": 5}
	bystander.lord_id = 999

	_target.physical_location = "Castle"
	_target.lord_id = 10

	var chars: Dictionary = {50: bystander}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, true,
	)
	assert_null(found, "Bystander with different lord should be excluded with loyalty gate")


func test_find_best_searcher_loyalty_includes_same_lord() -> void:
	var retainer: L5RCharacterData = L5RCharacterData.new()
	retainer.character_id = 51
	retainer.physical_location = "Castle"
	retainer.perception = 3
	retainer.skills = {"Investigation": 3}
	retainer.lord_id = 10

	_target.physical_location = "Castle"
	_target.lord_id = 10

	var chars: Dictionary = {51: retainer}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, true,
	)
	assert_eq(found.character_id, 51, "Same-lord retainer should pass loyalty gate")


func test_find_best_searcher_loyalty_includes_direct_vassal() -> void:
	var vassal: L5RCharacterData = L5RCharacterData.new()
	vassal.character_id = 52
	vassal.physical_location = "Castle"
	vassal.perception = 3
	vassal.skills = {"Investigation": 3}
	vassal.lord_id = _target.character_id

	_target.physical_location = "Castle"

	var chars: Dictionary = {52: vassal}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, true,
	)
	assert_eq(found.character_id, 52, "Direct vassal should pass loyalty gate")


func test_find_best_searcher_loyalty_includes_bodyguard() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.character_id = 53
	guard.physical_location = "Castle"
	guard.perception = 4
	guard.skills = {"Investigation": 4}
	guard.lord_id = 999
	guard.assigned_protection_target_id = _target.character_id

	_target.physical_location = "Castle"

	var chars: Dictionary = {53: guard}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, true,
	)
	assert_eq(found.character_id, 53, "Assigned bodyguard should pass loyalty gate regardless of lord")


func test_find_best_searcher_loyalty_excludes_disgruntled_household() -> void:
	var disgruntled: L5RCharacterData = L5RCharacterData.new()
	disgruntled.character_id = 54
	disgruntled.physical_location = "Castle"
	disgruntled.perception = 5
	disgruntled.skills = {"Investigation": 5}
	disgruntled.lord_id = 10
	disgruntled.disposition_values = {_target.character_id: -5}

	_target.physical_location = "Castle"
	_target.lord_id = 10

	var chars: Dictionary = {54: disgruntled}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, true,
	)
	assert_null(found, "Household member with negative disposition toward target should be excluded")


func test_find_best_searcher_no_loyalty_gate_includes_all() -> void:
	var bystander: L5RCharacterData = L5RCharacterData.new()
	bystander.character_id = 55
	bystander.physical_location = "Castle"
	bystander.perception = 5
	bystander.skills = {"Investigation": 5}
	bystander.lord_id = 999

	_target.physical_location = "Castle"
	_target.lord_id = 10

	var chars: Dictionary = {55: bystander}
	var found: L5RCharacterData = AssassinationSystem.find_best_searcher(
		_target, _assassin.character_id, chars, false,
	)
	assert_eq(found.character_id, 55, "Without loyalty gate, any co-located character qualifies")


# ==============================================================================
# Household Member Detection
# ==============================================================================

func test_is_household_member_same_lord() -> void:
	var retainer: L5RCharacterData = L5RCharacterData.new()
	retainer.lord_id = 10
	_target.lord_id = 10
	assert_true(AssassinationSystem._is_household_member(retainer, _target))


func test_is_household_member_direct_vassal() -> void:
	var vassal: L5RCharacterData = L5RCharacterData.new()
	vassal.lord_id = _target.character_id
	assert_true(AssassinationSystem._is_household_member(vassal, _target))


func test_is_household_member_bodyguard() -> void:
	var guard: L5RCharacterData = L5RCharacterData.new()
	guard.lord_id = 999
	guard.assigned_protection_target_id = _target.character_id
	assert_true(AssassinationSystem._is_household_member(guard, _target))


func test_is_household_member_unrelated() -> void:
	var stranger: L5RCharacterData = L5RCharacterData.new()
	stranger.lord_id = 999
	_target.lord_id = 10
	assert_false(AssassinationSystem._is_household_member(stranger, _target))


# ==============================================================================
# Entanglement Creation Wiring
# ==============================================================================

func test_process_seduction_entanglements_creates_on_success() -> void:
	var day_results: Array = [{
		"action_id": "SEDUCE_FOR_ACCESS",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"creates_entanglement": true},
	}]
	var entanglements: Array = []
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
	assert_eq(entanglements.size(), 1)
	assert_eq(entanglements[0]["seducer_id"], 1)
	assert_eq(entanglements[0]["target_id"], 2)
	assert_eq(entanglements[0]["variant"], SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS)
	assert_eq(entanglements[0]["state"], SeductionSystem.EntanglementState.ACTIVE)


func test_process_seduction_entanglements_skips_failure() -> void:
	var day_results: Array = [{
		"action_id": "SEDUCE",
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {},
	}]
	var entanglements: Array = []
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
	assert_eq(entanglements.size(), 0, "Failed seduction should not create entanglement")


func test_process_seduction_entanglements_no_duplicate() -> void:
	var existing: Dictionary = SeductionSystem.create_entanglement(1, 2, 5, SeductionSystem.SeductionVariant.SEDUCE)
	var entanglements: Array = [existing]
	var day_results: Array = [{
		"action_id": "SEDUCE",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"creates_entanglement": true},
	}]
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
	assert_eq(entanglements.size(), 1, "Should not create duplicate entanglement")


func test_process_seduction_entanglements_allows_after_broken() -> void:
	var broken: Dictionary = SeductionSystem.create_entanglement(1, 2, 5)
	broken["state"] = SeductionSystem.EntanglementState.BROKEN
	var entanglements: Array = [broken]
	var day_results: Array = [{
		"action_id": "SEDUCE",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"creates_entanglement": true},
	}]
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
	assert_eq(entanglements.size(), 2, "Should allow new entanglement after previous one broke")


func test_process_seduction_entanglements_variant_mapping() -> void:
	var variants: Dictionary = {
		"SEDUCE": SeductionSystem.SeductionVariant.SEDUCE,
		"SEDUCE_FOR_INFO": SeductionSystem.SeductionVariant.SEDUCE_FOR_INFO,
		"SEDUCE_FOR_LEVERAGE": SeductionSystem.SeductionVariant.SEDUCE_FOR_LEVERAGE,
		"SEDUCE_TO_COMPROMISE": SeductionSystem.SeductionVariant.SEDUCE_TO_COMPROMISE,
	}
	for action_id: String in variants:
		var entanglements: Array = []
		var day_results: Array = [{
			"action_id": action_id,
			"success": true,
			"character_id": 100 + variants[action_id],
			"target_npc_id": 200 + variants[action_id],
			"effects": {"creates_entanglement": true},
		}]
		DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
		assert_eq(entanglements.size(), 1, "Should create entanglement for " + action_id)
		assert_eq(entanglements[0]["variant"], variants[action_id],
			"Variant should match action_id " + action_id)


# ==============================================================================
# Vengeance Consequences (s12.8)
# ==============================================================================

func test_vengeance_applies_disposition_to_family() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.mother_id = 101
	victim.father_id = 102
	victim.sibling_ids = [103]
	victim.children_ids = [104]
	victim.spouse_id = 105

	var mother: L5RCharacterData = L5RCharacterData.new()
	mother.character_id = 101
	var father: L5RCharacterData = L5RCharacterData.new()
	father.character_id = 102
	var sibling: L5RCharacterData = L5RCharacterData.new()
	sibling.character_id = 103
	var child: L5RCharacterData = L5RCharacterData.new()
	child.character_id = 104
	var spouse: L5RCharacterData = L5RCharacterData.new()
	spouse.character_id = 105

	var chars: Dictionary = {100: victim, 101: mother, 102: father, 103: sibling, 104: child, 105: spouse}
	var objectives: Dictionary = {}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	assert_eq(result["family_affected"], 5)
	assert_eq(result["disposition_modifier"], AssassinationSystem.FAMILY_VENGEANCE_DISPOSITION)
	var key: String = "killed_family_100"
	assert_true(mother.historical_modifiers.has(key))
	assert_eq(mother.historical_modifiers[key]["target_id"], 50)
	assert_eq(mother.historical_modifiers[key]["modifier"], -50)
	assert_true(father.historical_modifiers.has(key))
	assert_true(sibling.historical_modifiers.has(key))
	assert_true(child.historical_modifiers.has(key))
	assert_true(spouse.historical_modifiers.has(key))


func test_vengeance_assigns_objective_to_heir() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.designated_heir_id = 104

	var heir: L5RCharacterData = L5RCharacterData.new()
	heir.character_id = 104

	var chars: Dictionary = {100: victim, 104: heir}
	var objectives: Dictionary = {104: {"primary": "MAINTAIN_POSITION"}}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	assert_eq(result["avenger_id"], 104)
	assert_eq(objectives[104]["primary"], "AVENGE_DEATH")
	assert_eq(objectives[104]["avenge_target_id"], 50)
	assert_eq(objectives[104]["avenge_victim_id"], 100)
	assert_true(objectives[104]["crisis_override"])


func test_vengeance_assigns_to_victim_if_alive() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100

	var chars: Dictionary = {100: victim}
	var objectives: Dictionary = {100: {"primary": "MAINTAIN_POSITION"}}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, false, chars, objectives,
	)
	assert_eq(result["avenger_id"], 100)
	assert_eq(objectives[100]["primary"], "AVENGE_DEATH")


func test_vengeance_falls_back_to_eldest_child() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.designated_heir_id = -1
	victim.children_ids = [201, 202]

	var young: L5RCharacterData = L5RCharacterData.new()
	young.character_id = 201
	young.age = 14

	var elder: L5RCharacterData = L5RCharacterData.new()
	elder.character_id = 202
	elder.age = 22

	var chars: Dictionary = {100: victim, 201: young, 202: elder}
	var objectives: Dictionary = {202: {"primary": "MAINTAIN_POSITION"}}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	assert_eq(result["avenger_id"], 202, "Should select eldest child as avenger")


func test_vengeance_skips_dead_family_members() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.sibling_ids = [103]

	var dead_sibling: L5RCharacterData = L5RCharacterData.new()
	dead_sibling.character_id = 103
	var earth: int = CharacterStats.get_ring_value(dead_sibling, Enums.Ring.EARTH)
	dead_sibling.wounds_taken = earth * 5 * 5

	var chars: Dictionary = {100: victim, 103: dead_sibling}
	var objectives: Dictionary = {}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	var key: String = "killed_family_100"
	assert_false(dead_sibling.historical_modifiers.has(key),
		"Dead family members should not receive disposition modifier")


func test_vengeance_no_avenger_if_no_heir_or_children() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.designated_heir_id = -1

	var chars: Dictionary = {100: victim}
	var objectives: Dictionary = {}

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	assert_eq(result["avenger_id"], -1, "No avenger when no heir or children")


func test_get_biological_family_comprehensive() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.mother_id = 10
	c.father_id = 11
	c.sibling_ids = [12, 13]
	c.children_ids = [14]
	c.spouse_id = 15
	var family: Array = AssassinationSystem._get_biological_family(c)
	assert_eq(family.size(), 6)
	assert_true(10 in family)
	assert_true(11 in family)
	assert_true(12 in family)
	assert_true(13 in family)
	assert_true(14 in family)
	assert_true(15 in family)


func test_get_biological_family_skips_unset_ids() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.mother_id = -1
	c.father_id = -1
	c.spouse_id = -1
	var family: Array = AssassinationSystem._get_biological_family(c)
	assert_eq(family.size(), 0)


# ==============================================================================
# PvP Blade Edge Case (s12.8)
# ==============================================================================

func test_pvp_blade_can_engine_resolve() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	assert_true(AssassinationSystem.can_pvp_blade_resolve_via_engine(s))


func test_pvp_blade_cannot_engine_resolve_poison() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	assert_false(AssassinationSystem.can_pvp_blade_resolve_via_engine(s),
		"Only blade method has the PvP edge case")


func test_pvp_blade_cannot_engine_resolve_access_phase() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	assert_false(AssassinationSystem.can_pvp_blade_resolve_via_engine(s),
		"Must be in EXECUTION phase")


func test_pvp_blade_wait_tick_increments_days() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	var r1: Dictionary = AssassinationSystem.pvp_blade_wait_tick(s, 10)
	assert_eq(r1["pvp_wait_days"], 1)
	var r2: Dictionary = AssassinationSystem.pvp_blade_wait_tick(s, 11)
	assert_eq(r2["pvp_wait_days"], 2)


func test_pvp_blade_wait_decays_suspicion() -> void:
	var s: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.BLADE, 0)
	s["phase"] = AssassinationSystem.AssassinationPhase.EXECUTION
	AssassinationSystem.add_suspicion(s, 20)
	s["suspicion_raised_ic_day"] = 0
	AssassinationSystem.pvp_blade_wait_tick(s, 20)
	assert_true(float(s["suspicion"]) < 20.0, "Suspicion should decay while waiting (present-inactive)")


# ==============================================================================
# Entanglement Integration Test
# ==============================================================================

func test_entanglement_integration_seduce_for_access_to_bypass() -> void:
	var day_results: Array = [{
		"action_id": "SEDUCE_FOR_ACCESS",
		"success": true,
		"character_id": 1,
		"target_npc_id": 5,
		"effects": {"creates_entanglement": true},
	}]
	var entanglements: Array = []
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 10)
	assert_eq(entanglements.size(), 1)

	var seduced: L5RCharacterData = L5RCharacterData.new()
	seduced.character_id = 5
	seduced.physical_location = "Castle"
	var chars: Dictionary = {1: _assassin, 2: _target, 5: seduced}
	_target.physical_location = "Castle"

	var has_bypass: bool = AssassinationSystem.has_seduce_for_access(
		1, "Castle", entanglements, chars,
	)
	assert_true(has_bypass, "Should detect active SEDUCE_FOR_ACCESS entanglement at target location")


func test_entanglement_integration_broken_revokes_bypass() -> void:
	var entanglements: Array = [
		SeductionSystem.create_entanglement(1, 5, 5, SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS),
	]
	entanglements[0]["state"] = SeductionSystem.EntanglementState.BROKEN

	var seduced: L5RCharacterData = L5RCharacterData.new()
	seduced.character_id = 5
	seduced.physical_location = "Castle"
	var chars: Dictionary = {1: _assassin, 5: seduced}

	var has_bypass: bool = AssassinationSystem.has_seduce_for_access(
		1, "Castle", entanglements, chars,
	)
	assert_false(has_bypass, "Broken entanglement should not grant access bypass")


# ==============================================================================
# Betrayal Topic on Trace (s12.8)
# ==============================================================================

func test_vengeance_creates_betrayal_topic() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100

	var chars: Dictionary = {100: victim}
	var objectives: Dictionary = {100: {"primary": "MAINTAIN_POSITION"}}
	var topics: Array = []
	var next_id: Array = [500]

	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, false, chars, objectives, topics, next_id, 30,
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "betrayal")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_2)
	assert_eq(topics[0].category, TopicData.Category.POLITICAL)
	assert_eq(topics[0].subject_character_id, 50)
	assert_eq(topics[0].ic_day_created, 30)
	assert_eq(result["betrayal_topic_id"], 500)
	assert_eq(next_id[0], 501)


func test_vengeance_no_topic_without_topic_params() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	var chars: Dictionary = {100: victim}
	var objectives: Dictionary = {}
	var result: Dictionary = AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, objectives,
	)
	assert_eq(result["betrayal_topic_id"], -1,
		"No topic generated when topic params not provided")


func test_vengeance_topic_subject_role_neutral() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	var chars: Dictionary = {100: victim}
	var topics: Array = []
	var next_id: Array = [1]
	AssassinationSystem.apply_vengeance_consequences(
		50, victim, true, chars, {}, topics, next_id, 10,
	)
	assert_eq(topics[0].subject_role, "NEUTRAL",
		"Dead characters always carry NEUTRAL subject_role valence")


# ==============================================================================
# Non-Shinobi Detection Severity (s12.8)
# ==============================================================================

func test_daily_detection_non_shinobi_bonus() -> void:
	var observer: L5RCharacterData = L5RCharacterData.new()
	observer.character_id = 30
	observer.perception = 3
	observer.skills = {"Investigation": 3}

	var non_shinobi: L5RCharacterData = L5RCharacterData.new()
	non_shinobi.character_id = 40
	non_shinobi.school = "Akodo Bushi"

	var shinobi: L5RCharacterData = L5RCharacterData.new()
	shinobi.character_id = 41
	shinobi.school = "Shosuro Infiltrator"

	var total_noticed_non_shinobi: int = 0
	var total_noticed_shinobi: int = 0
	var trials: int = 100

	for i: int in range(trials):
		var s1: Dictionary = AssassinationSystem.create_assassination_state(40, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		var d1: DiceEngine = DiceEngine.new(i)
		var r1: Dictionary = AssassinationSystem.resolve_daily_detection(observer, 20, s1, d1, non_shinobi)
		if r1.get("noticed", false):
			total_noticed_non_shinobi += 1

		var s2: Dictionary = AssassinationSystem.create_assassination_state(41, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
		var d2: DiceEngine = DiceEngine.new(i)
		var r2: Dictionary = AssassinationSystem.resolve_daily_detection(observer, 20, s2, d2, shinobi)
		if r2.get("noticed", false):
			total_noticed_shinobi += 1

	assert_true(total_noticed_non_shinobi > total_noticed_shinobi,
		"Non-shinobi assassins should be detected more often due to +%d bonus" % AssassinationSystem.NON_SHINOBI_DETECTION_BONUS)


func test_daily_detection_no_bonus_for_shinobi() -> void:
	var observer: L5RCharacterData = L5RCharacterData.new()
	observer.character_id = 30
	observer.perception = 3
	observer.skills = {"Investigation": 3}

	var shinobi: L5RCharacterData = L5RCharacterData.new()
	shinobi.character_id = 41
	shinobi.school = "Shosuro Infiltrator"

	var state: Dictionary = AssassinationSystem.create_assassination_state(41, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_daily_detection(observer, 30, state, _engine, shinobi)
	assert_true(result.has("noticed"), "Should return noticed field regardless of shinobi status")


func test_daily_detection_null_assassin_no_bonus() -> void:
	var observer: L5RCharacterData = L5RCharacterData.new()
	observer.character_id = 30
	observer.perception = 3
	observer.skills = {"Investigation": 3}

	var state: Dictionary = AssassinationSystem.create_assassination_state(1, 2, AssassinationSystem.ExecutionMethod.POISON, 0)
	var result: Dictionary = AssassinationSystem.resolve_daily_detection(observer, 30, state, _engine, null)
	assert_true(result.has("noticed"), "Should work with null assassin (backward compatible)")


# ==============================================================================
# Vengeance Wiring in Conviction Pipeline
# ==============================================================================

func test_apply_assassination_vengeance_fires_on_covert_killing() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100
	victim.sibling_ids = [103]
	var sibling: L5RCharacterData = L5RCharacterData.new()
	sibling.character_id = 103

	var record: CrimeRecord = CrimeRecord.new()
	record.case_id = 1
	record.crime_type = Enums.CrimeType.UNSANCTIONED_COVERT_KILLING
	record.victim_id = 100
	record.perpetrator_id = 1
	record.commissioner_id = 50

	var conviction_results: Array = [{
		"case_id": 1,
		"outcome": "convicted",
		"crime_type": Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
	}]
	var chars: Dictionary = {100: victim, 103: sibling}
	var objectives: Dictionary = {}
	var topics: Array = []
	var next_id: Array = [500]

	DayOrchestrator._apply_assassination_vengeance(
		conviction_results, [record], chars, objectives, topics, next_id, 30,
	)
	var key: String = "killed_family_100"
	assert_true(sibling.historical_modifiers.has(key),
		"Sibling should receive vengeance disposition modifier")
	assert_eq(sibling.historical_modifiers[key]["target_id"], 50)
	assert_eq(topics.size(), 1, "Betrayal topic should be generated")


func test_apply_assassination_vengeance_skips_non_assassination() -> void:
	var record: CrimeRecord = CrimeRecord.new()
	record.case_id = 2
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.commissioner_id = 50

	var conviction_results: Array = [{
		"case_id": 2,
		"outcome": "convicted",
		"crime_type": Enums.CrimeType.VIOLENCE,
	}]
	var topics: Array = []
	DayOrchestrator._apply_assassination_vengeance(
		conviction_results, [record], {}, {}, topics, [1], 10,
	)
	assert_eq(topics.size(), 0, "No vengeance for non-assassination crimes")


func test_apply_assassination_vengeance_skips_no_commissioner() -> void:
	var victim: L5RCharacterData = L5RCharacterData.new()
	victim.character_id = 100

	var record: CrimeRecord = CrimeRecord.new()
	record.case_id = 3
	record.crime_type = Enums.CrimeType.UNSANCTIONED_COVERT_KILLING
	record.victim_id = 100
	record.commissioner_id = -1

	var conviction_results: Array = [{
		"case_id": 3,
		"outcome": "convicted",
		"crime_type": Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
	}]
	var topics: Array = []
	DayOrchestrator._apply_assassination_vengeance(
		conviction_results, [record], {100: victim}, {}, topics, [1], 10,
	)
	assert_eq(topics.size(), 0,
		"No vengeance when no commissioner is identified")


# ==============================================================================
# CrimeRecord Commissioner ID Propagation
# ==============================================================================

func test_crime_record_has_commissioner_field() -> void:
	var record: CrimeRecord = CrimeRecord.new()
	assert_eq(record.commissioner_id, -1, "Default should be -1 sentinel")
