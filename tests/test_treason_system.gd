extends GutTest
## Tests for TreasonSystem per GDD s11.3.8.


# -- Evidence Weights (s11.3.8b) ----

func test_intercepted_letter_weight_50():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.INTERCEPTED_LETTER), 50)


func test_co_conspirator_testimony_weight_45():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.CO_CONSPIRATOR_TESTIMONY), 45)


func test_confession_weight_50():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.CONFESSION), 50)


func test_caught_in_act_weight_40():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.CAUGHT_IN_ACT), 40)


func test_objective_stall_weight_5():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL), 5)


func test_disposition_anomaly_weight_8():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.DISPOSITION_ANOMALY), 8)


func test_suspicious_meeting_weight_5():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.SUSPICIOUS_MEETING), 5)


func test_unexplained_absence_weight_3():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.UNEXPLAINED_ABSENCE), 3)


func test_voting_against_lord_weight_5():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.VOTING_AGAINST_LORD), 5)


func test_failed_order_weight_10():
	assert_eq(TreasonSystem.get_evidence_weight(
		TreasonSystem.TreasonEvidenceType.FAILED_ORDER), 10)


func test_hard_evidence_classification():
	assert_true(TreasonSystem.is_hard_evidence(
		TreasonSystem.TreasonEvidenceType.INTERCEPTED_LETTER))
	assert_true(TreasonSystem.is_hard_evidence(
		TreasonSystem.TreasonEvidenceType.CONFESSION))
	assert_false(TreasonSystem.is_hard_evidence(
		TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL))
	assert_false(TreasonSystem.is_hard_evidence(
		TreasonSystem.TreasonEvidenceType.SUSPICIOUS_MEETING))


# -- Evidence Accumulation (s11.3.8b) ----

func _make_case() -> LegalCaseEntry:
	var c := LegalCaseEntry.new()
	c.evidence_total = 0
	c.evidence_items = []
	return c


func test_single_hard_evidence_crosses_threshold():
	var case_entry := _make_case()
	var r := TreasonSystem.add_treason_evidence(
		case_entry, TreasonSystem.TreasonEvidenceType.INTERCEPTED_LETTER, 100)
	assert_eq(r["weight_added"], 50)
	assert_eq(r["new_total"], 50)
	assert_true(r["crossed_threshold"])
	assert_true(r["is_hard_evidence"])


func test_circumstantial_accumulates():
	var case_entry := _make_case()
	TreasonSystem.add_treason_evidence(
		case_entry, TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL, 10)
	TreasonSystem.add_treason_evidence(
		case_entry, TreasonSystem.TreasonEvidenceType.DISPOSITION_ANOMALY, 20)
	assert_eq(case_entry.evidence_total, 13)
	assert_false(TreasonSystem.can_formally_accuse(case_entry))


func test_many_circumstantial_crosses_threshold():
	var case_entry := _make_case()
	for i in range(8):
		TreasonSystem.add_treason_evidence(
			case_entry, TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL, 10 + i)
	assert_eq(case_entry.evidence_total, 40)
	assert_true(TreasonSystem.can_formally_accuse(case_entry))


func test_evidence_items_tracked():
	var case_entry := _make_case()
	TreasonSystem.add_treason_evidence(
		case_entry, TreasonSystem.TreasonEvidenceType.SUSPICIOUS_MEETING, 50)
	assert_eq(case_entry.evidence_items.size(), 1)
	assert_eq(case_entry.evidence_items[0]["type"],
		TreasonSystem.TreasonEvidenceType.SUSPICIOUS_MEETING)
	assert_eq(case_entry.evidence_items[0]["ic_day"], 50)


# -- Defense Hearing (s11.3.8c) ----

func test_defense_succeeds_halves_evidence():
	var r := TreasonSystem.resolve_defense_hearing(30, 40, 4)
	assert_true(r["defense_succeeded"])
	assert_eq(r["evidence_halved_to"], 20)
	assert_true(r["political_shield_active"])
	assert_eq(r["reaccusation_requires"], 20)


func test_defense_fails():
	var r := TreasonSystem.resolve_defense_hearing(5, 50, 2)
	assert_false(r["defense_succeeded"])
	assert_true(r["accusation_stands"])
	assert_true(r["proceed_to_judgment"])


func test_high_honor_helps_defense():
	# Honor rank 8 → testimony weight 40, effective evidence = max(45-40, 0) = 5
	# Sincerity roll 10 >= 5 → defense succeeds
	var r := TreasonSystem.resolve_defense_hearing(10, 45, 8)
	assert_true(r["defense_succeeded"])


func test_low_honor_hurts_defense():
	# Honor rank 1 → testimony weight 5, effective evidence = max(45-5, 0) = 40
	# Sincerity roll 10 < 40 → defense fails
	var r := TreasonSystem.resolve_defense_hearing(10, 45, 1)
	assert_false(r["defense_succeeded"])


# -- Re-accusation (s11.3.8c) ----

func test_reaccusation_insufficient_new_evidence():
	var case_entry := _make_case()
	case_entry.evidence_total = 35
	var r := TreasonSystem.can_reaccuse(case_entry, 20)
	assert_eq(r["new_evidence_since_acquittal"], 15)
	assert_false(r["meets_threshold"])


func test_reaccusation_sufficient_new_evidence():
	var case_entry := _make_case()
	case_entry.evidence_total = 45
	var r := TreasonSystem.can_reaccuse(case_entry, 20)
	assert_eq(r["new_evidence_since_acquittal"], 25)
	assert_true(r["meets_threshold"])


# -- Authority Chain (s11.3.8d) ----

func test_lord_can_convict_lower_status():
	var r := TreasonSystem.can_convict(5.0, 3.0)
	assert_true(r["has_authority"])
	assert_false(r["must_escalate"])


func test_lord_cannot_convict_equal_status():
	var r := TreasonSystem.can_convict(4.0, 4.0)
	assert_false(r["has_authority"])
	assert_true(r["must_escalate"])


func test_lord_cannot_convict_higher_status():
	var r := TreasonSystem.can_convict(3.0, 5.0)
	assert_false(r["has_authority"])
	assert_true(r["must_escalate"])


func test_escalation_provincial_daimyo_to_champion():
	var target := TreasonSystem.get_escalation_target(true)
	assert_eq(target, TreasonSystem.EscalationTarget.CLAN_CHAMPION)


func test_escalation_other_to_emperor():
	var target := TreasonSystem.get_escalation_target(false)
	assert_eq(target, TreasonSystem.EscalationTarget.EMPEROR)


# -- Intervention (s11.3.8d) ----

func test_pardon_most_costly():
	var r := TreasonSystem.evaluate_intervention(
		TreasonSystem.InterventionType.PARDON, 7.0, 5.0)
	assert_true(r["valid"])
	assert_almost_eq(r["honor_cost"], -0.5, 0.01)
	assert_eq(r["disposition_hit_from_vassals"], -15)
	assert_true(r["undermines_authority"])


func test_commute_least_costly():
	var r := TreasonSystem.evaluate_intervention(
		TreasonSystem.InterventionType.COMMUTE, 7.0, 5.0)
	assert_true(r["valid"])
	assert_almost_eq(r["honor_cost"], -0.2, 0.01)
	assert_eq(r["disposition_hit_from_vassals"], -5)


func test_intervention_requires_higher_status():
	var r := TreasonSystem.evaluate_intervention(
		TreasonSystem.InterventionType.PARDON, 4.0, 5.0)
	assert_false(r["valid"])
	assert_eq(r["reason"], "insufficient_status")


# -- Co-Conspirator Naming (s11.3.8e) ----

func test_gi_lord_names_publicly():
	var r := TreasonSystem.should_name_co_conspirators(Enums.BushidoVirtue.GI)
	assert_true(r["names_publicly"])
	assert_true(r["co_conspirators_flagged"])


func test_seigyo_lord_keeps_names_private():
	var r := TreasonSystem.should_name_co_conspirators(Enums.ShouridoVirtue.SEIGYO)
	assert_false(r["names_publicly"])
	assert_true(r["names_kept_in_intel_db"])


func test_chugi_lord_keeps_names_private():
	var r := TreasonSystem.should_name_co_conspirators(Enums.BushidoVirtue.CHUGI)
	assert_false(r["names_publicly"])


func test_meiyo_lord_names_publicly():
	var r := TreasonSystem.should_name_co_conspirators(Enums.BushidoVirtue.MEIYO)
	assert_true(r["names_publicly"])


# -- False Accusation (s11.3.8e) ----

func test_false_accusation_penalty():
	var r := TreasonSystem.apply_false_accusation_penalty()
	assert_almost_eq(r["honor_change"], -0.5, 0.01)
	assert_eq(r["disposition_hit_all_vassals"], -15)
	assert_true(r["chilling_effect"])


# -- Refused Seppuku (s11.3.8d) ----

func test_refused_seppuku_exile():
	var r := TreasonSystem.apply_refused_seppuku()
	assert_eq(r["new_legal_status"], "ronin")
	assert_almost_eq(r["honor_change"], -5.0, 0.01)
	assert_almost_eq(r["infamy_gain"], 3.0, 0.01)
	assert_almost_eq(r["status_set_to"], 0.0, 0.01)
	assert_true(r["exile"])


# -- Lord Response to Suspicion (s11.3.8g) ----

func test_yu_lord_prefers_confrontation():
	var r := TreasonSystem.get_preferred_response(Enums.BushidoVirtue.YU)
	assert_eq(r, TreasonSystem.SuspicionResponse.CONFRONT_DIRECTLY)


func test_seigyo_lord_prefers_patience():
	var r := TreasonSystem.get_preferred_response(Enums.ShouridoVirtue.SEIGYO)
	assert_eq(r, TreasonSystem.SuspicionResponse.WAIT_FOR_PROOF)


func test_dosatsu_lord_prefers_surveillance():
	var r := TreasonSystem.get_preferred_response(Enums.ShouridoVirtue.DOSATSU)
	assert_eq(r, TreasonSystem.SuspicionResponse.INCREASE_SURVEILLANCE)


func test_jin_lord_prefers_loyalty_test():
	var r := TreasonSystem.get_preferred_response(Enums.BushidoVirtue.JIN)
	assert_eq(r, TreasonSystem.SuspicionResponse.TEST_LOYALTY)


func test_surveillance_response_details():
	var r := TreasonSystem.evaluate_suspicion_response(
		TreasonSystem.SuspicionResponse.INCREASE_SURVEILLANCE)
	assert_eq(r["action"], "assign_probe")
	assert_false(r["tips_off_suspect"])
	assert_true(r["recorded_in_zone_log"])


func test_restrict_access_tips_off():
	var r := TreasonSystem.evaluate_suspicion_response(
		TreasonSystem.SuspicionResponse.RESTRICT_ACCESS)
	assert_true(r["tips_off_suspect"])
	assert_true(r["limits_damage"])


func test_confront_directly_sincerity_check():
	var r := TreasonSystem.evaluate_suspicion_response(
		TreasonSystem.SuspicionResponse.CONFRONT_DIRECTLY)
	assert_true(r["sincerity_vs_investigation"])
	assert_true(r["tips_off_suspect"])
