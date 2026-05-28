extends GutTest
## Tests for LegalStatusSystem per GDD s11.3.14.


func _make_character() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Test Suspect"
	return c


func _make_entry(state: Enums.LegalStatus = Enums.LegalStatus.CLEAR) -> LegalCaseEntry:
	var e := LegalCaseEntry.new()
	e.crime_record_id = 100
	e.state = state
	return e


# -- Valid Transitions (s11.3.14b) ----

func test_clear_to_suspected_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.CLEAR, Enums.LegalStatus.SUSPECTED))


func test_clear_to_under_investigation_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.CLEAR, Enums.LegalStatus.UNDER_INVESTIGATION))


func test_suspected_to_under_investigation_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.SUSPECTED, Enums.LegalStatus.UNDER_INVESTIGATION))


func test_suspected_to_clear_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.SUSPECTED, Enums.LegalStatus.CLEAR))


func test_under_investigation_to_accused_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.UNDER_INVESTIGATION, Enums.LegalStatus.ACCUSED))


func test_under_investigation_to_clear_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.UNDER_INVESTIGATION, Enums.LegalStatus.CLEAR))


func test_under_investigation_to_fugitive_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.UNDER_INVESTIGATION, Enums.LegalStatus.FUGITIVE))


func test_accused_to_decreed_guilty_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.ACCUSED, Enums.LegalStatus.DECREED_GUILTY))


func test_accused_to_acquitted_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.ACCUSED, Enums.LegalStatus.ACQUITTED))


func test_accused_to_fugitive_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.ACCUSED, Enums.LegalStatus.FUGITIVE))


func test_decreed_guilty_to_pardoned_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.DECREED_GUILTY, Enums.LegalStatus.PARDONED))


func test_fugitive_to_decreed_guilty_valid():
	assert_true(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.FUGITIVE, Enums.LegalStatus.DECREED_GUILTY))


# -- Invalid Transitions ----

func test_clear_to_accused_invalid():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.CLEAR, Enums.LegalStatus.ACCUSED))


func test_suspected_to_accused_invalid():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.SUSPECTED, Enums.LegalStatus.ACCUSED))


func test_acquitted_terminal():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.ACQUITTED, Enums.LegalStatus.CLEAR))


func test_pardoned_terminal():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.PARDONED, Enums.LegalStatus.CLEAR))


func test_accused_to_clear_invalid():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.ACCUSED, Enums.LegalStatus.CLEAR))


func test_decreed_guilty_to_clear_invalid():
	assert_false(LegalStatusSystem.is_valid_transition(
		Enums.LegalStatus.DECREED_GUILTY, Enums.LegalStatus.CLEAR))


# -- Open Case (s11.3.14b) ----

func test_open_case_gradual_detection():
	var c := _make_character()
	var entry := LegalStatusSystem.open_case(c, 100, false)
	assert_eq(entry.state, Enums.LegalStatus.SUSPECTED)
	assert_eq(entry.crime_record_id, 100)
	assert_eq(c.legal_cases.size(), 1)


func test_open_case_immediate_investigation():
	var c := _make_character()
	var entry := LegalStatusSystem.open_case(c, 200, true)
	assert_eq(entry.state, Enums.LegalStatus.UNDER_INVESTIGATION)
	assert_eq(entry.crime_record_id, 200)


# -- Transition Function ----

func test_transition_success():
	var entry := _make_entry(Enums.LegalStatus.UNDER_INVESTIGATION)
	var result := LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED, 42)
	assert_true(result["success"])
	assert_eq(result["from"], Enums.LegalStatus.UNDER_INVESTIGATION)
	assert_eq(result["to"], Enums.LegalStatus.ACCUSED)
	assert_eq(entry.state, Enums.LegalStatus.ACCUSED)
	assert_eq(entry.accusation_timestamp, 42)


func test_transition_invalid_returns_error():
	var entry := _make_entry(Enums.LegalStatus.CLEAR)
	var result := LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED)
	assert_false(result["success"])
	assert_eq(result["error"], "invalid_transition")
	assert_eq(entry.state, Enums.LegalStatus.CLEAR)


func test_transition_to_guilty_sets_verdict_timestamp():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	LegalStatusSystem.transition(entry, Enums.LegalStatus.DECREED_GUILTY, 99)
	assert_eq(entry.verdict_timestamp, 99)


func test_transition_to_acquitted_sets_verdict_timestamp():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	LegalStatusSystem.transition(entry, Enums.LegalStatus.ACQUITTED, 55)
	assert_eq(entry.verdict_timestamp, 55)


# -- Evidence (s11.3.14c) ----

func test_add_evidence_increases_total():
	var entry := _make_entry(Enums.LegalStatus.UNDER_INVESTIGATION)
	var result := LegalStatusSystem.add_evidence(entry, "witness", 15, "interview", 10)
	assert_eq(entry.evidence_total, 15)
	assert_eq(result["new_total"], 15)
	assert_eq(entry.evidence_items.size(), 1)


func test_add_evidence_crosses_accusation_threshold():
	var entry := _make_entry(Enums.LegalStatus.UNDER_INVESTIGATION)
	entry.evidence_total = 30
	var result := LegalStatusSystem.add_evidence(entry, "scene", 15, "examination", 20)
	assert_eq(result["threshold_crossed"], "accusation")


func test_add_evidence_no_threshold_when_not_under_investigation():
	var entry := _make_entry(Enums.LegalStatus.SUSPECTED)
	entry.evidence_total = 35
	var result := LegalStatusSystem.add_evidence(entry, "scene", 10, "tip", 5)
	assert_eq(result["threshold_crossed"], "")


# -- Multiple Concurrent Cases (s11.3.14c) ----

func test_multiple_cases_on_one_character():
	var c := _make_character()
	LegalStatusSystem.open_case(c, 100, true)
	LegalStatusSystem.open_case(c, 200, false)
	LegalStatusSystem.open_case(c, 300, true)
	assert_eq(c.legal_cases.size(), 3)


func test_get_case_by_id():
	var c := _make_character()
	LegalStatusSystem.open_case(c, 100, true)
	LegalStatusSystem.open_case(c, 200, false)
	var entry := LegalStatusSystem.get_case(c, 200)
	assert_not_null(entry)
	assert_eq(entry.crime_record_id, 200)
	assert_eq(entry.state, Enums.LegalStatus.SUSPECTED)


func test_get_case_returns_null_for_missing():
	var c := _make_character()
	assert_null(LegalStatusSystem.get_case(c, 999))


func test_independent_progression():
	var c := _make_character()
	var e1 := LegalStatusSystem.open_case(c, 100, true)
	var e2 := LegalStatusSystem.open_case(c, 200, true)
	LegalStatusSystem.transition(e1, Enums.LegalStatus.ACCUSED, 10)
	assert_eq(e1.state, Enums.LegalStatus.ACCUSED)
	assert_eq(e2.state, Enums.LegalStatus.UNDER_INVESTIGATION)


# -- Query Helpers ----

func test_get_active_cases():
	var c := _make_character()
	var e1 := LegalStatusSystem.open_case(c, 100, true)
	var e2 := LegalStatusSystem.open_case(c, 200, false)
	LegalStatusSystem.transition(e1, Enums.LegalStatus.CLEAR)
	var active := LegalStatusSystem.get_active_cases(c)
	assert_eq(active.size(), 1)
	assert_eq(active[0].crime_record_id, 200)


func test_has_active_case():
	var c := _make_character()
	assert_false(LegalStatusSystem.has_active_case(c))
	LegalStatusSystem.open_case(c, 100, true)
	assert_true(LegalStatusSystem.has_active_case(c))


func test_is_fugitive():
	var c := _make_character()
	var entry := LegalStatusSystem.open_case(c, 100, true)
	assert_false(LegalStatusSystem.is_fugitive(c))
	LegalStatusSystem.transition(entry, Enums.LegalStatus.FUGITIVE, 5)
	assert_true(LegalStatusSystem.is_fugitive(c))


func test_is_accused():
	var c := _make_character()
	var entry := LegalStatusSystem.open_case(c, 100, true)
	assert_false(LegalStatusSystem.is_accused(c))
	LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED, 10)
	assert_true(LegalStatusSystem.is_accused(c))


func test_get_worst_state_no_cases():
	var c := _make_character()
	assert_eq(LegalStatusSystem.get_worst_state(c), Enums.LegalStatus.CLEAR)


func test_get_worst_state_multiple():
	var c := _make_character()
	LegalStatusSystem.open_case(c, 100, false)
	var e2 := LegalStatusSystem.open_case(c, 200, true)
	LegalStatusSystem.transition(e2, Enums.LegalStatus.ACCUSED, 10)
	assert_eq(LegalStatusSystem.get_worst_state(c), Enums.LegalStatus.ACCUSED)


# -- Flee and Capture (s11.3.14b) ----

func test_flee_from_investigation():
	var entry := _make_entry(Enums.LegalStatus.UNDER_INVESTIGATION)
	var result := LegalStatusSystem.flee(entry, 30)
	assert_true(result["success"])
	assert_false(result["was_accused"])
	assert_eq(entry.state, Enums.LegalStatus.FUGITIVE)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_3)


func test_flee_from_accused():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	var result := LegalStatusSystem.flee(entry, 30)
	assert_true(result["success"])
	assert_true(result["was_accused"])


func test_flee_from_clear_invalid():
	var entry := _make_entry(Enums.LegalStatus.CLEAR)
	var result := LegalStatusSystem.flee(entry, 30)
	assert_false(result["success"])


func test_capture_fugitive():
	var entry := _make_entry(Enums.LegalStatus.FUGITIVE)
	var result := LegalStatusSystem.capture_fugitive(entry, 60)
	assert_true(result["success"])
	assert_eq(entry.state, Enums.LegalStatus.DECREED_GUILTY)
	assert_eq(entry.verdict_timestamp, 60)


func test_capture_non_fugitive_fails():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	var result := LegalStatusSystem.capture_fugitive(entry, 60)
	assert_false(result["success"])


# -- Pardon and Acquittal (s11.3.14b) ----

func test_pardon_guilty():
	var entry := _make_entry(Enums.LegalStatus.DECREED_GUILTY)
	var result := LegalStatusSystem.pardon(entry, 80)
	assert_true(result["success"])
	assert_eq(entry.state, Enums.LegalStatus.PARDONED)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_3)


func test_pardon_non_guilty_fails():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	var result := LegalStatusSystem.pardon(entry, 80)
	assert_false(result["success"])


func test_acquit_accused():
	var entry := _make_entry(Enums.LegalStatus.ACCUSED)
	var result := LegalStatusSystem.acquit(entry, 70)
	assert_true(result["success"])
	assert_eq(entry.state, Enums.LegalStatus.ACQUITTED)
	assert_true(result["can_reinvestigate_with_new_evidence"])


func test_acquit_non_accused_fails():
	var entry := _make_entry(Enums.LegalStatus.UNDER_INVESTIGATION)
	var result := LegalStatusSystem.acquit(entry, 70)
	assert_false(result["success"])


# -- Close Case ----

func test_close_case_from_investigation():
	var c := _make_character()
	LegalStatusSystem.open_case(c, 100, true)
	assert_true(LegalStatusSystem.close_case(c, 100))
	assert_eq(c.legal_cases[0].state, Enums.LegalStatus.CLEAR)


func test_close_case_from_suspected():
	var c := _make_character()
	LegalStatusSystem.open_case(c, 100, false)
	assert_true(LegalStatusSystem.close_case(c, 100))


func test_close_case_cannot_close_accused():
	var c := _make_character()
	var entry := LegalStatusSystem.open_case(c, 100, true)
	LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED, 10)
	assert_false(LegalStatusSystem.close_case(c, 100))
	assert_eq(entry.state, Enums.LegalStatus.ACCUSED)


func test_close_case_missing_returns_false():
	var c := _make_character()
	assert_false(LegalStatusSystem.close_case(c, 999))
