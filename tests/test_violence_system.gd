extends GutTest
## Tests for ViolenceSystem per GDD s11.3.12.


func _make_character(status: float = 3.0, honor: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.status = status
	c.honor = honor
	c.glory = 3.0
	c.infamy = 0.0
	return c


# -- Basic Evaluation (s11.3.12a) ----

func test_basic_violence_minor_severity():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["severity"], Enums.CrimeSeverity.MINOR)
	assert_eq(result["crime_type"], Enums.CrimeType.VIOLENCE)


func test_basic_honor_and_glory_loss():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_almost_eq(result["honor_loss"], -0.2, 0.01)
	assert_almost_eq(result["glory_loss"], -0.1, 0.01)


func test_first_offense_no_infamy():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_almost_eq(result["infamy_gain"], 0.0, 0.01)


func test_first_offense_tier_4_topic():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_4)


func test_auto_detected():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_true(result["auto_detected"])


func test_creates_duel_pretext():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_true(result["creates_duel_pretext"])


# -- Status Modifier (s11.3.12c) ----

func test_violence_upward_harsher():
	var attacker := _make_character(2.0)
	var victim := _make_character(5.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["status_direction"], "upward")
	assert_eq(result["punishment"], ViolenceSystem.PunishmentLevel.BANISHMENT)


func test_violence_downward_lenient():
	var attacker := _make_character(5.0)
	var victim := _make_character(2.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["status_direction"], "downward")
	assert_eq(result["punishment"], ViolenceSystem.PunishmentLevel.REPRIMAND)


func test_violence_equal_standard():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["status_direction"], "equal")
	assert_eq(result["punishment"], ViolenceSystem.PunishmentLevel.HOUSE_ARREST)


# -- Repeated Offenses (s11.3.12e) ----

func test_second_offense_infamy_locked_s11_3_12a():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 1, false)
	assert_almost_eq(result["infamy_gain"], ViolenceSystem.INFAMY_PER_REPEATED_OFFENSE, 0.01)


func test_third_offense_escalates_topic():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 3, false)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_3)


func test_third_offense_escalates_punishment():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 3, false)
	assert_eq(result["punishment"], ViolenceSystem.PunishmentLevel.BANISHMENT)


func test_upward_violence_with_repeats_max_punishment():
	var attacker := _make_character(2.0)
	var victim := _make_character(5.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 3, false)
	assert_eq(result["punishment"], ViolenceSystem.PunishmentLevel.FORMAL_CENSURE)


func test_brutal_first_offense_infamy_locked_s11_3_12a():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.evaluate_violence(attacker, victim, 0, true)
	assert_almost_eq(result["infamy_gain"], ViolenceSystem.INFAMY_PER_REPEATED_OFFENSE, 0.01)


# -- Offense Window Counting ----

func test_count_offenses_in_window():
	var days: Array = [10, 100, 200, 400]
	# Window = 4 seasons * 90 = 360 days. Current day 450 → window starts at 90
	assert_eq(ViolenceSystem.count_offenses_in_window(days, 450), 3)


func test_count_offenses_all_old():
	var days: Array = [5, 10, 15]
	assert_eq(ViolenceSystem.count_offenses_in_window(days, 500), 0)


func test_count_offenses_all_recent():
	var days: Array = [100, 110, 120]
	assert_eq(ViolenceSystem.count_offenses_in_window(days, 150), 3)


# -- Consequence Application ----

func test_apply_consequences_modifies_character():
	var attacker := _make_character(3.0, 5.0)
	var initial_honor: float = attacker.honor
	var initial_glory: float = attacker.glory
	var eval_result := ViolenceSystem.evaluate_violence(attacker, _make_character(3.0), 1, false)
	ViolenceSystem.apply_consequences(attacker, eval_result)
	assert_almost_eq(attacker.honor, initial_honor - 0.2, 0.01)
	assert_almost_eq(attacker.glory, initial_glory - 0.1, 0.01)
	assert_almost_eq(attacker.infamy, ViolenceSystem.INFAMY_PER_REPEATED_OFFENSE, 0.01)


# -- Duel Pretext (s11.3.12d) ----

func test_duel_pretext_granted():
	var attacker := _make_character(3.0)
	var victim := _make_character(3.0)
	var result := ViolenceSystem.creates_duel_pretext(attacker, victim)
	assert_true(result["pretext_granted"])
	assert_eq(result["pretext_type"], "violence_provocation")


# -- Escalation to Killing (s11.3.12 intro) ----

func test_blades_drawn_and_death_escalates():
	assert_true(ViolenceSystem.should_escalate_to_killing(true, true))


func test_blades_drawn_no_death_no_escalation():
	assert_false(ViolenceSystem.should_escalate_to_killing(true, false))


func test_no_blades_no_escalation():
	assert_false(ViolenceSystem.should_escalate_to_killing(false, false))


# -- violence_offense_days field and wiring (s11.3.12 wiring) ----

func test_violence_offense_days_field_exists():
	var c := _make_character()
	# Field must exist and default to empty array.
	assert_not_null(c.violence_offense_days)
	assert_eq(c.violence_offense_days.size(), 0)


func test_violence_offense_days_accumulates():
	var c := _make_character()
	c.violence_offense_days.append(100)
	c.violence_offense_days.append(200)
	assert_eq(ViolenceSystem.count_offenses_in_window(c.violence_offense_days, 300), 2)


func test_brutal_bodyguard_combat_wiring_produces_infamy():
	# Simulate the non-lethal bodyguard path: evaluate + apply, is_brutal=true.
	var assassin := _make_character(3.0, 5.0)
	var guard := _make_character(3.0, 5.0)
	var prior_count: int = ViolenceSystem.count_offenses_in_window(
		assassin.violence_offense_days, 500)
	var v_eval: Dictionary = ViolenceSystem.evaluate_violence(
		assassin, guard, prior_count, true)
	ViolenceSystem.apply_consequences(assassin, v_eval)
	assassin.violence_offense_days.append(500)
	# is_brutal=true always triggers infamy regardless of prior offenses.
	assert_almost_eq(assassin.infamy, ViolenceSystem.INFAMY_PER_REPEATED_OFFENSE, 0.01)
	# Offense recorded.
	assert_eq(assassin.violence_offense_days.size(), 1)


func test_seed_assassination_violence_seeds_settlement():
	var settlement := SettlementData.new()
	settlement.settlement_id = 42
	settlement.public_record = []

	var assassination_results: Array = [
		{
			"violence_result": {
				"topic_tier": TopicData.Tier.TIER_4,
				"crime_type": Enums.CrimeType.VIOLENCE,
			},
			"violence_attacker_id": 7,
			"violence_location": "42",
		}
	]

	DayOrchestrator._seed_assassination_violence_public_records(
		assassination_results, [settlement], 100)

	assert_eq(settlement.public_record.size(), 1)
	var entry: Dictionary = settlement.public_record[0]
	assert_eq(entry["event_type"], "violence")
	assert_eq(entry["tier"], TopicData.Tier.TIER_4)
	assert_eq(entry["subject_id"], 7)


func test_seed_assassination_violence_skips_no_violence_result():
	var settlement := SettlementData.new()
	settlement.settlement_id = 1
	settlement.public_record = []

	# Tick result with no violence_result key should be skipped.
	var assassination_results: Array = [{"other_key": "value"}]
	DayOrchestrator._seed_assassination_violence_public_records(
		assassination_results, [settlement], 100)

	assert_eq(settlement.public_record.size(), 0)


func test_seed_assassination_violence_skips_empty_location():
	var settlement := SettlementData.new()
	settlement.settlement_id = 5
	settlement.public_record = []

	var assassination_results: Array = [
		{
			"violence_result": {"topic_tier": TopicData.Tier.TIER_4},
			"violence_attacker_id": 3,
			"violence_location": "",
		}
	]
	DayOrchestrator._seed_assassination_violence_public_records(
		assassination_results, [settlement], 100)

	assert_eq(settlement.public_record.size(), 0)
