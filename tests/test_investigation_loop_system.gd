extends GutTest
## Tests for InvestigationLoopSystem per GDD s11.3.13 and s11.3.14.


# -- Witness Recall TN (s11.3.13b) ----

func test_recall_tn_same_day():
	assert_eq(InvestigationLoopSystem.get_recall_tn(0), 10)


func test_recall_tn_same_month():
	assert_eq(InvestigationLoopSystem.get_recall_tn(14), 15)


func test_recall_tn_prev_month():
	assert_eq(InvestigationLoopSystem.get_recall_tn(40), 20)


func test_recall_tn_two_months():
	assert_eq(InvestigationLoopSystem.get_recall_tn(70), 25)


func test_recall_tn_near_season():
	assert_eq(InvestigationLoopSystem.get_recall_tn(100), 30)


func test_recall_possible_within_season():
	assert_true(InvestigationLoopSystem.is_recall_possible(100))


func test_recall_impossible_beyond_season():
	assert_false(InvestigationLoopSystem.is_recall_possible(113))


# -- Evidence Decay (s11.3.13d) ----

func test_decay_same_day():
	assert_eq(InvestigationLoopSystem.get_scene_examination_penalty(0), 0)


func test_decay_same_week():
	assert_eq(InvestigationLoopSystem.get_scene_examination_penalty(5), -2)


func test_decay_same_month():
	assert_eq(InvestigationLoopSystem.get_scene_examination_penalty(20), -5)


func test_decay_prev_month():
	assert_eq(InvestigationLoopSystem.get_scene_examination_penalty(40), -10)


func test_decay_near_season():
	assert_eq(InvestigationLoopSystem.get_scene_examination_penalty(100), -15)


func test_scene_not_viable_beyond_season():
	assert_false(InvestigationLoopSystem.is_scene_viable(113))


func test_scene_viable_within_season():
	assert_true(InvestigationLoopSystem.is_scene_viable(100))


# -- Crime Scene Evidence (s11.3.13d) ----

func test_scene_evidence_failure():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(10, 15, 0), 0)


func test_scene_evidence_minor():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(15, 15, 0), 10)


func test_scene_evidence_significant():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(20, 15, 0), 20)


func test_scene_evidence_major():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(25, 15, 0), 30)


func test_scene_evidence_with_raises():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(15, 15, 2), 30)


func test_scene_evidence_major_with_raises():
	assert_eq(InvestigationLoopSystem.get_scene_evidence_weight(26, 15, 1), 40)


# -- Criminal Recall (s11.3.13c) ----

func test_criminal_recall_tn():
	assert_eq(InvestigationLoopSystem.get_criminal_recall_tn(), 10)


# -- Witness Tampering (s11.3.13c Step 3) ----

func test_bribe_success():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_success_result(
		InvestigationLoopSystem.TamperingMethod.BRIBE_WITNESS
	)
	assert_true(r["witness_silenced"])
	assert_true(r["co_conspirator_created"])
	assert_eq(r["secret_tier"], 2)
	assert_false(r["hostile_action"])


func test_intimidate_success():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_success_result(
		InvestigationLoopSystem.TamperingMethod.INTIMIDATE_WITNESS
	)
	assert_true(r["witness_silenced"])
	assert_false(r["co_conspirator_created"])
	assert_true(r["hostile_action"])
	assert_true(r["provocation_flag"])


func test_kill_success():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_success_result(
		InvestigationLoopSystem.TamperingMethod.KILL_WITNESS
	)
	assert_true(r["witness_silenced"])
	assert_true(r["new_crime_created"])


func test_do_nothing():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_success_result(
		InvestigationLoopSystem.TamperingMethod.DO_NOTHING
	)
	assert_false(r["witness_silenced"])


func test_bribe_failure():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_failure_result(
		InvestigationLoopSystem.TamperingMethod.BRIBE_WITNESS
	)
	assert_false(r["witness_silenced"])
	assert_eq(r["evidence_if_reported"], 10)
	assert_true(r["witness_suspicious"])


func test_intimidate_failure():
	var r: Dictionary = InvestigationLoopSystem.get_tampering_failure_result(
		InvestigationLoopSystem.TamperingMethod.INTIMIDATE_WITNESS
	)
	assert_false(r["witness_silenced"])
	assert_eq(r["evidence_if_reported"], 10)
	assert_true(r["witness_hostile"])
	assert_true(r["witness_motivated_to_report"])


# -- Legal Status State Machine (s11.3.14) ----

func test_clear_to_suspected():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.CLEAR,
		InvestigationLoopSystem.LegalState.SUSPECTED
	))


func test_clear_to_under_investigation():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.CLEAR,
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION
	))


func test_clear_cannot_to_accused():
	assert_false(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.CLEAR,
		InvestigationLoopSystem.LegalState.ACCUSED
	))


func test_suspected_to_investigation():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.SUSPECTED,
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION
	))


func test_suspected_to_clear():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.SUSPECTED,
		InvestigationLoopSystem.LegalState.CLEAR
	))


func test_investigation_to_accused():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION,
		InvestigationLoopSystem.LegalState.ACCUSED
	))


func test_investigation_to_fugitive():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION,
		InvestigationLoopSystem.LegalState.FUGITIVE
	))


func test_accused_to_guilty():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.ACCUSED,
		InvestigationLoopSystem.LegalState.DECREED_GUILTY
	))


func test_accused_to_acquitted():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.ACCUSED,
		InvestigationLoopSystem.LegalState.ACQUITTED
	))


func test_accused_to_fugitive():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.ACCUSED,
		InvestigationLoopSystem.LegalState.FUGITIVE
	))


func test_guilty_to_pardoned():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.DECREED_GUILTY,
		InvestigationLoopSystem.LegalState.PARDONED
	))


func test_fugitive_to_guilty():
	assert_true(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.FUGITIVE,
		InvestigationLoopSystem.LegalState.DECREED_GUILTY
	))


func test_acquitted_cannot_transition():
	assert_false(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.ACQUITTED,
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION
	))


func test_pardoned_cannot_transition():
	assert_false(InvestigationLoopSystem.can_transition(
		InvestigationLoopSystem.LegalState.PARDONED,
		InvestigationLoopSystem.LegalState.CLEAR
	))


# -- Transition Triggers ----

func test_trigger_immediate_discovery():
	assert_eq(
		InvestigationLoopSystem.get_transition_trigger(
			InvestigationLoopSystem.LegalState.CLEAR,
			InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION
		),
		"immediate_discovery"
	)


func test_trigger_evidence_threshold():
	assert_eq(
		InvestigationLoopSystem.get_transition_trigger(
			InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION,
			InvestigationLoopSystem.LegalState.ACCUSED
		),
		"evidence_threshold_reached"
	)


func test_trigger_invalid():
	assert_eq(
		InvestigationLoopSystem.get_transition_trigger(
			InvestigationLoopSystem.LegalState.CLEAR,
			InvestigationLoopSystem.LegalState.ACCUSED
		),
		"invalid"
	)


# -- Investigation Entry Points (s11.3.13h) ----

func test_murder_immediate():
	assert_eq(
		InvestigationLoopSystem.get_discovery_type("murder"),
		InvestigationLoopSystem.DiscoveryType.IMMEDIATE
	)


func test_treason_gradual():
	assert_eq(
		InvestigationLoopSystem.get_discovery_type("treason"),
		InvestigationLoopSystem.DiscoveryType.GRADUAL
	)


func test_maho_specialized():
	assert_eq(
		InvestigationLoopSystem.get_discovery_type("maho"),
		InvestigationLoopSystem.DiscoveryType.SPECIALIZED
	)


func test_immediate_skips_to_investigation():
	assert_eq(
		InvestigationLoopSystem.get_initial_legal_state(
			InvestigationLoopSystem.DiscoveryType.IMMEDIATE
		),
		InvestigationLoopSystem.LegalState.UNDER_INVESTIGATION
	)


func test_gradual_starts_suspected():
	assert_eq(
		InvestigationLoopSystem.get_initial_legal_state(
			InvestigationLoopSystem.DiscoveryType.GRADUAL
		),
		InvestigationLoopSystem.LegalState.SUSPECTED
	)


# -- Accusation Check ----

func test_should_accuse_at_threshold():
	assert_true(InvestigationLoopSystem.should_accuse(40))


func test_should_accuse_above():
	assert_true(InvestigationLoopSystem.should_accuse(55))


func test_should_not_accuse_below():
	assert_false(InvestigationLoopSystem.should_accuse(39))


func test_bribery_trigger_at_25():
	assert_true(InvestigationLoopSystem.should_trigger_bribery_eval(25))


func test_bribery_trigger_below():
	assert_false(InvestigationLoopSystem.should_trigger_bribery_eval(24))


# -- Crime Record Status ----

func test_case_solved():
	assert_eq(
		InvestigationLoopSystem.get_case_close_status(true, false),
		InvestigationLoopSystem.CrimeRecordStatus.SOLVED
	)


func test_case_buried():
	assert_eq(
		InvestigationLoopSystem.get_case_close_status(false, true),
		InvestigationLoopSystem.CrimeRecordStatus.BURIED
	)


func test_case_insufficient():
	assert_eq(
		InvestigationLoopSystem.get_case_close_status(false, false),
		InvestigationLoopSystem.CrimeRecordStatus.CLOSED_INSUFFICIENT_EVIDENCE
	)


# -- Zone Event Log ----

func test_zone_log_available():
	assert_true(InvestigationLoopSystem.is_zone_log_available(80))


func test_zone_log_purged():
	assert_false(InvestigationLoopSystem.is_zone_log_available(91))


# -- Concealment ----

func test_open_crime_tn_zero():
	assert_eq(InvestigationLoopSystem.get_open_crime_concealment_tn(), 0)


func test_concealment_skill_poison():
	assert_eq(
		InvestigationLoopSystem.get_concealment_skill(
			InvestigationLoopSystem.ConcealmentMethod.POISON
		),
		"Medicine/Intelligence"
	)


func test_concealment_skill_stealth():
	assert_eq(
		InvestigationLoopSystem.get_concealment_skill(
			InvestigationLoopSystem.ConcealmentMethod.STEALTH
		),
		"Stealth/Agility"
	)


func test_concealment_skill_open():
	assert_eq(
		InvestigationLoopSystem.get_concealment_skill(
			InvestigationLoopSystem.ConcealmentMethod.OPEN
		),
		"none"
	)
