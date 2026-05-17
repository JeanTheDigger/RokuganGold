extends GutTest
## End-to-end integration test for the crime pipeline:
## commit → investigation → accusation → conviction → seppuku resolution.
##
## Perpetrators use SchoolType.COURTIER so DefenseHearingSystem.should_demand_trial
## returns false (non-BUSHI, non-YU). With null DiceEngine, sincerity roll = 0;
## 0 + testimony_weight(25) < evidence_total(40) → defense always fails → conviction.


# -- Fixtures ------------------------------------------------------------------

func _make_perpetrator(id: int = 10) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "crane"
	c.honor = 5.0
	c.glory = 3.0
	c.status = 3.0
	c.infamy = 0.0
	c.school_type = Enums.SchoolType.COURTIER
	c.awareness = 2
	c.skills = {}
	return c


func _make_lord(id: int = 20) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "crane"
	c.honor = 7.0
	c.glory = 5.0
	c.status = 5.0
	c.infamy = 0.0
	return c


func _make_victim(id: int = 30, victim_clan: String = "lion") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = victim_clan
	c.status = 2.0
	return c


func _open_and_accuse(
	perpetrator: L5RCharacterData,
	record: CrimeRecord,
	accusation_day: int,
) -> LegalCaseEntry:
	var entry: LegalCaseEntry = LegalStatusSystem.open_case(perpetrator, record.case_id, true)
	LegalStatusSystem.add_evidence(entry, "scene_examination", 40, "magistrate", accusation_day)
	LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED, accusation_day)
	record.legal_status = Enums.LegalStatus.ACCUSED
	return entry


func _run_pipeline(
	record: CrimeRecord,
	chars: Dictionary,
	lord_map: Dictionary,
	ic_day: int,
	next_id: Array[int],
	topics: Array[TopicData],
) -> Array[Dictionary]:
	return ConvictionProcessor.process_accused_cases(
		[record], chars, null, ic_day, next_id, topics, lord_map
	)


# -- 1. At-Act Consequences ----------------------------------------------------

func test_at_act_honor_loss_fires_immediately():
	var perp := _make_perpetrator()
	var initial: float = perp.honor
	CrimeSystem.apply_at_act_consequences(perp, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	assert_lt(perp.honor, initial)


# -- 2. Legal Status Machine ---------------------------------------------------

func test_open_case_starts_under_investigation():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(1, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	var entry: LegalCaseEntry = LegalStatusSystem.open_case(perp, record.case_id, true)
	assert_eq(entry.state, Enums.LegalStatus.UNDER_INVESTIGATION)
	assert_eq(perp.legal_cases.size(), 1)


func test_evidence_at_threshold_signals_accusation():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(2, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	var entry: LegalCaseEntry = LegalStatusSystem.open_case(perp, record.case_id, true)
	var result: Dictionary = LegalStatusSystem.add_evidence(entry, "scene", 40, "mag_1", 2)
	assert_eq(result["threshold_crossed"], "accusation")


func test_invalid_transition_rejected_and_state_unchanged():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(3, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	var entry: LegalCaseEntry = LegalStatusSystem.open_case(perp, record.case_id, true)
	var result: Dictionary = LegalStatusSystem.transition(entry, Enums.LegalStatus.DECREED_GUILTY, 1)
	assert_false(result["success"])
	assert_eq(entry.state, Enums.LegalStatus.UNDER_INVESTIGATION)


func test_worst_state_query_returns_most_severe():
	var perp := _make_perpetrator()
	var r1 := CrimeSystem.create_crime_record(4, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	var r2 := CrimeSystem.create_crime_record(5, Enums.CrimeType.SKIMMING, perp.character_id, "zone_b", 1)
	LegalStatusSystem.open_case(perp, r1.case_id, true)
	var e2: LegalCaseEntry = LegalStatusSystem.open_case(perp, r2.case_id, true)
	LegalStatusSystem.add_evidence(e2, "scene", 40, "mag_1", 1)
	LegalStatusSystem.transition(e2, Enums.LegalStatus.ACCUSED, 1)
	assert_eq(LegalStatusSystem.get_worst_state(perp), Enums.LegalStatus.ACCUSED)


# -- 3. Defense Hearing Timer --------------------------------------------------

func test_case_skipped_when_under_three_days_since_accusation():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(6, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	_open_and_accuse(perp, record, 10)

	var next_id: Array[int] = [100]
	var topics: Array[TopicData] = []
	var results := _run_pipeline(
		record,
		{perp.character_id: perp, lord.character_id: lord},
		{perp.character_id: lord.character_id},
		12, next_id, topics
	)
	assert_eq(results.size(), 0)


func test_case_processed_exactly_three_days_after_accusation():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(7, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	_open_and_accuse(perp, record, 10)

	var next_id: Array[int] = [100]
	var topics: Array[TopicData] = []
	var results := _run_pipeline(
		record,
		{perp.character_id: perp, lord.character_id: lord},
		{perp.character_id: lord.character_id},
		13, next_id, topics
	)
	assert_eq(results.size(), 1)


# -- 4. Conviction — VIOLENCE (no seppuku) ------------------------------------

func test_violence_conviction_decrements_glory_and_marks_guilty():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(8, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	_open_and_accuse(perp, record, 10)
	var initial_glory: float = perp.glory

	var next_id: Array[int] = [200]
	var topics: Array[TopicData] = []
	var results := _run_pipeline(
		record,
		{perp.character_id: perp, lord.character_id: lord},
		{perp.character_id: lord.character_id},
		13, next_id, topics
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["outcome"], "convicted")
	assert_eq(results[0]["crime_type"], Enums.CrimeType.VIOLENCE)
	assert_false(results[0]["seppuku_offered"])
	assert_lt(perp.glory, initial_glory)
	assert_eq(record.legal_status, Enums.LegalStatus.DECREED_GUILTY)
	assert_ge(record.ic_day_conviction, 0)


# -- 5. Conviction — UNSANCTIONED_OPEN_KILLING (seppuku offered) ---------------

func test_open_killing_conviction_offers_seppuku_and_applies_infamy():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var victim := _make_victim()
	var record := CrimeSystem.create_crime_record(
		9, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING,
		perp.character_id, "zone_b", 1, victim.character_id
	)
	_open_and_accuse(perp, record, 10)

	var chars: Dictionary = {
		perp.character_id: perp,
		lord.character_id: lord,
		victim.character_id: victim,
	}
	var next_id: Array[int] = [300]
	var topics: Array[TopicData] = []
	var results := _run_pipeline(record, chars, {perp.character_id: lord.character_id}, 13, next_id, topics)

	assert_eq(results[0]["outcome"], "convicted")
	assert_true(results[0]["seppuku_offered"])
	assert_true(record.seppuku_offered)
	assert_gt(perp.infamy, 0.0)
	assert_lt(perp.glory, 3.0)


func test_cross_clan_victim_flagged_in_conviction_result():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var victim := _make_victim(30, "lion")
	var record := CrimeSystem.create_crime_record(
		10, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING,
		perp.character_id, "zone_b", 1, victim.character_id
	)
	_open_and_accuse(perp, record, 10)

	var chars: Dictionary = {
		perp.character_id: perp,
		lord.character_id: lord,
		victim.character_id: victim,
	}
	var next_id: Array[int] = [350]
	var topics: Array[TopicData] = []
	var results := _run_pipeline(record, chars, {perp.character_id: lord.character_id}, 13, next_id, topics)

	assert_true(results[0]["is_cross_clan"])


# -- 6. Seppuku Accepted -------------------------------------------------------

func test_seppuku_accepted_grants_honor_bonus_and_marks_dead():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(
		11, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, perp.character_id, "zone_b", 1
	)
	record.seppuku_offered = true
	var initial_honor: float = perp.honor

	var next_id: Array[int] = [400]
	var result := ConvictionProcessor.resolve_seppuku(record, perp, true, 20, next_id)

	assert_true(result["applicable"])
	assert_true(result["accepted"])
	assert_true(result["character_dead"])
	assert_gt(perp.honor, initial_honor)
	assert_true(record.seppuku_accepted)


func test_resolve_seppuku_returns_not_applicable_when_not_offered():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(
		12, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, perp.character_id, "zone_b", 1
	)
	var next_id: Array[int] = [410]
	var result := ConvictionProcessor.resolve_seppuku(record, perp, true, 20, next_id)
	assert_false(result["applicable"])


# -- 7. Seppuku Refused --------------------------------------------------------

func test_seppuku_refused_penalizes_honor_and_infamy():
	var perp := _make_perpetrator()
	var record := CrimeSystem.create_crime_record(
		13, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, perp.character_id, "zone_b", 1
	)
	record.seppuku_offered = true
	var initial_honor: float = perp.honor
	var initial_infamy: float = perp.infamy

	var next_id: Array[int] = [500]
	var result := ConvictionProcessor.resolve_seppuku(record, perp, false, 20, next_id)

	assert_true(result["applicable"])
	assert_false(result["accepted"])
	assert_lt(perp.honor, initial_honor)
	assert_gt(perp.infamy, initial_infamy)
	assert_false(record.seppuku_accepted)


# -- 8. Topic Generation -------------------------------------------------------

func test_conviction_topic_added_to_active_topics_and_lord_pool():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(
		14, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, perp.character_id, "zone_b", 1
	)
	_open_and_accuse(perp, record, 10)

	var chars: Dictionary = {perp.character_id: perp, lord.character_id: lord}
	var next_id: Array[int] = [600]
	var topics: Array[TopicData] = []
	_run_pipeline(record, chars, {perp.character_id: lord.character_id}, 13, next_id, topics)

	assert_gt(topics.size(), 0)
	assert_true(topics[0].topic_id in lord.topic_pool)


func test_conviction_topic_id_consumed_from_counter():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(
		15, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1
	)
	_open_and_accuse(perp, record, 10)

	var next_id: Array[int] = [700]
	var topics: Array[TopicData] = []
	_run_pipeline(
		record,
		{perp.character_id: perp, lord.character_id: lord},
		{perp.character_id: lord.character_id},
		13, next_id, topics
	)
	assert_gt(next_id[0], 700, "Topic counter must advance after topic creation")


# -- 9. Double-Processing Guard ------------------------------------------------

func test_already_convicted_case_not_reprocessed():
	var perp := _make_perpetrator()
	var lord := _make_lord()
	var record := CrimeSystem.create_crime_record(16, Enums.CrimeType.VIOLENCE, perp.character_id, "zone_a", 1)
	_open_and_accuse(perp, record, 10)

	var chars: Dictionary = {perp.character_id: perp, lord.character_id: lord}
	var lord_map: Dictionary = {perp.character_id: lord.character_id}
	var next_id: Array[int] = [800]
	var topics: Array[TopicData] = []

	_run_pipeline(record, chars, lord_map, 13, next_id, topics)
	var glory_after_first: float = perp.glory

	_run_pipeline(record, chars, lord_map, 14, next_id, topics)
	assert_eq(perp.glory, glory_after_first)


# -- 10. Multiple Cases Processed Independently --------------------------------

func test_two_cases_both_resolved_in_one_pass():
	var perp1 := _make_perpetrator(11)
	var perp2 := _make_perpetrator(12)
	perp2.clan = "scorpion"
	var lord := _make_lord()

	var r1 := CrimeSystem.create_crime_record(17, Enums.CrimeType.VIOLENCE, perp1.character_id, "zone_a", 1)
	var r2 := CrimeSystem.create_crime_record(18, Enums.CrimeType.SKIMMING, perp2.character_id, "zone_b", 1)
	_open_and_accuse(perp1, r1, 10)
	_open_and_accuse(perp2, r2, 10)

	var chars: Dictionary = {
		perp1.character_id: perp1,
		perp2.character_id: perp2,
		lord.character_id: lord,
	}
	var lord_map: Dictionary = {
		perp1.character_id: lord.character_id,
		perp2.character_id: lord.character_id,
	}
	var next_id: Array[int] = [900]
	var topics: Array[TopicData] = []

	var results := ConvictionProcessor.process_accused_cases(
		[r1, r2], chars, null, 13, next_id, topics, lord_map
	)
	assert_eq(results.size(), 2)
	assert_eq(r1.legal_status, Enums.LegalStatus.DECREED_GUILTY)
	assert_eq(r2.legal_status, Enums.LegalStatus.DECREED_GUILTY)
