extends GutTest
## Tests for CrimeWiring — integration between UnsanctionedKillingSystem,
## TreasonSystem, CrimeSystem, and InvestigationSystem.


func _make_char(id: int, clan: String, status: float, honor: float = 3.5) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = status
	c.honor = honor
	c.character_name = "Test_%d" % id
	c.physical_location = "test_zone"
	return c


func _make_case_entry() -> LegalCaseEntry:
	var e := LegalCaseEntry.new()
	e.evidence_total = 0
	e.evidence_items = []
	return e


func _make_crime_record(crime_type: Enums.CrimeType, perp_id: int = 1, vic_id: int = 2) -> CrimeRecord:
	return CrimeSystem.create_crime_record(1, crime_type, perp_id, "zone_a", 100, vic_id)


# -- Killing Crime Processing ----

func test_wartime_battlefield_no_crime():
	var attacker := _make_char(1, "Crab", 3.0)
	var victim := _make_char(2, "Scorpion", 3.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_OPEN_KILLING}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 1, 100, [], true, true, false, false, false
	)
	assert_false(r["crime_created"])
	assert_eq(r["reason"], "battlefield_killing")


func test_self_defense_no_crime():
	var attacker := _make_char(1, "Crane", 3.0)
	var victim := _make_char(2, "Crane", 3.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_OPEN_KILLING}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 1, 100, [3], false, false, false, true, true
	)
	assert_false(r["crime_created"])
	assert_eq(r["reason"], "self_defense")


func test_killing_creates_record():
	var attacker := _make_char(1, "Scorpion", 3.0)
	var victim := _make_char(2, "Crane", 3.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_OPEN_KILLING}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 5, 200, [3, 4], false, false, false, false, false
	)
	assert_true(r["crime_created"])
	assert_not_null(r["record"])
	assert_eq(r["record"].crime_type, Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	assert_eq(r["jurisdiction"]["type"], "cross_clan")


func test_killing_upward_escalates_crime_type():
	var attacker := _make_char(1, "Lion", 2.0)
	var victim := _make_char(2, "Lion", 6.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_OPEN_KILLING}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 5, 200, [], false, false, false, false, false
	)
	assert_true(r["crime_created"])
	assert_eq(r["record"].crime_type, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	assert_true(r["classification"]["status_escalated"])


func test_duel_death_creates_correct_type():
	var attacker := _make_char(1, "Crane", 4.0)
	var victim := _make_char(2, "Crane", 4.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_DUEL_DEATH}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 1, 100, [], false, false, false, false, false
	)
	assert_true(r["crime_created"])
	assert_eq(r["record"].crime_type, Enums.CrimeType.UNSANCTIONED_DUEL_DEATH)


func test_same_clan_jurisdiction():
	var attacker := _make_char(1, "Lion", 3.0)
	var victim := _make_char(2, "Lion", 3.0)
	var effects := {"crime_type": Enums.CrimeType.UNSANCTIONED_OPEN_KILLING}
	var r := CrimeWiring.process_killing_crime(
		effects, attacker, victim, 1, 100, [], false, false, false, false, false
	)
	assert_eq(r["jurisdiction"]["type"], "same_clan")


# -- Treason Evidence Routing ----

func test_treason_evidence_routes_through_treason_system():
	var case_entry := _make_case_entry()
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	var r := CrimeWiring.add_treason_evidence_to_case(
		case_entry, record,
		TreasonSystem.TreasonEvidenceType.INTERCEPTED_LETTER, 100
	)
	assert_true(r["routed"])
	assert_eq(r["weight_added"], 50)
	assert_eq(case_entry.evidence_total, 50)
	assert_eq(record.evidence_total, 50)


func test_treason_evidence_not_routed_for_non_treason():
	var case_entry := _make_case_entry()
	var record := _make_crime_record(Enums.CrimeType.VIOLENCE)
	var r := CrimeWiring.add_treason_evidence_to_case(
		case_entry, record,
		TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL, 100
	)
	assert_false(r["routed"])


func test_treason_evidence_crosses_threshold_transitions_to_accused():
	var case_entry := _make_case_entry()
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	var r := CrimeWiring.add_treason_evidence_to_case(
		case_entry, record,
		TreasonSystem.TreasonEvidenceType.CONFESSION, 100
	)
	assert_true(r["crossed_threshold"])
	assert_eq(r["threshold_result"], "accusation")
	assert_eq(record.legal_status, Enums.LegalStatus.ACCUSED)


func test_treason_evidence_no_double_accusation():
	var case_entry := _make_case_entry()
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.legal_status = Enums.LegalStatus.ACCUSED
	record.evidence_total = 45
	case_entry.evidence_total = 45
	var r := CrimeWiring.add_treason_evidence_to_case(
		case_entry, record,
		TreasonSystem.TreasonEvidenceType.OBJECTIVE_STALL, 200
	)
	assert_eq(r["threshold_result"], "")


# -- Treason Defense Hearing ----

func test_defense_hearing_succeeds():
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.evidence_total = 42
	record.legal_status = Enums.LegalStatus.ACCUSED
	var accused := _make_char(1, "Crane", 3.0, 8.5)
	var lord := _make_char(10, "Crane", 6.0)
	var r := CrimeWiring.process_treason_defense_hearing(record, accused, 30, lord)
	assert_true(r["applicable"])
	assert_false(r["blocked"])
	assert_true(r["defense_succeeded"])
	assert_eq(record.legal_status, Enums.LegalStatus.ACQUITTED)
	assert_eq(record.evidence_total, 21)


func test_defense_hearing_fails():
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.evidence_total = 50
	record.legal_status = Enums.LegalStatus.ACCUSED
	var accused := _make_char(1, "Lion", 3.0, 1.5)
	var lord := _make_char(10, "Lion", 6.0)
	var r := CrimeWiring.process_treason_defense_hearing(record, accused, 5, lord)
	assert_true(r["applicable"])
	assert_false(r["defense_succeeded"])
	assert_true(r["proceed_to_judgment"])


func test_defense_hearing_blocked_by_authority():
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.evidence_total = 45
	record.legal_status = Enums.LegalStatus.ACCUSED
	var accused := _make_char(1, "Lion", 6.0)
	var lord := _make_char(10, "Lion", 4.0)
	var r := CrimeWiring.process_treason_defense_hearing(record, accused, 30, lord)
	assert_true(r["applicable"])
	assert_true(r["blocked"])
	assert_eq(r["reason"], "insufficient_authority")


func test_defense_hearing_not_applicable_non_treason():
	var record := _make_crime_record(Enums.CrimeType.VIOLENCE)
	var accused := _make_char(1, "Crane", 3.0)
	var lord := _make_char(10, "Crane", 6.0)
	var r := CrimeWiring.process_treason_defense_hearing(record, accused, 20, lord)
	assert_false(r["applicable"])


# -- Treason Conviction ----

func test_treason_conviction_gi_names_conspirators():
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.legal_status = Enums.LegalStatus.ACCUSED
	var convicted := _make_char(1, "Lion", 3.0)
	convicted.glory = 5.0
	var lord := _make_char(10, "Lion", 6.0)
	lord.bushido_virtue = Enums.BushidoVirtue.GI
	var co_ids: Array = [5, 6]
	var next_id: Array = [100]
	var r := CrimeWiring.process_treason_conviction(
		record, convicted, lord, co_ids, next_id, 200
	)
	assert_true(r["applicable"])
	assert_true(r["co_conspirators_named_publicly"])
	assert_eq(r["co_conspirator_ids"], [5, 6])
	assert_eq(record.legal_status, Enums.LegalStatus.DECREED_GUILTY)
	assert_not_null(r["conviction_topic"])
	assert_true(r.has("glory_delta"), "Treason conviction should include glory delta")
	assert_true(r.has("infamy_delta"), "Treason conviction should include infamy delta")
	assert_true(r.has("status_delta"), "Treason conviction should include status delta")


func test_treason_conviction_seigyo_hides_conspirators():
	var record := _make_crime_record(Enums.CrimeType.TREASON)
	record.legal_status = Enums.LegalStatus.ACCUSED
	var convicted := _make_char(1, "Scorpion", 3.0)
	var lord := _make_char(10, "Scorpion", 6.0)
	lord.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var co_ids: Array = [5, 6]
	var next_id: Array = [100]
	var r := CrimeWiring.process_treason_conviction(
		record, convicted, lord, co_ids, next_id, 200
	)
	assert_false(r["co_conspirators_named_publicly"])


# -- Trial by Combat ----

func test_trial_by_combat_accused_wins_acquittal():
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	record.legal_status = Enums.LegalStatus.ACCUSED
	var r := CrimeWiring.process_trial_by_combat(
		record, UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS, 3.0
	)
	assert_true(r["case_cleared"])
	assert_true(r["accused_alive"])
	assert_eq(record.legal_status, Enums.LegalStatus.ACQUITTED)


func test_trial_by_combat_accused_loses_conviction():
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	record.legal_status = Enums.LegalStatus.ACCUSED
	var r := CrimeWiring.process_trial_by_combat(
		record, UnsanctionedKillingSystem.TrialOutcome.ACCUSED_LOSES, 3.0
	)
	assert_true(r["case_cleared"])
	assert_false(r["accused_alive"])
	assert_eq(record.legal_status, Enums.LegalStatus.DECREED_GUILTY)


func test_trial_by_combat_accused_loses_applies_conviction_consequences():
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	record.legal_status = Enums.LegalStatus.ACCUSED
	var accused := _make_char(1, "Crane", 3.0)
	accused.glory = 5.0
	accused.infamy = 0.0
	var initial_glory: float = accused.glory
	var r := CrimeWiring.process_trial_by_combat(
		record, UnsanctionedKillingSystem.TrialOutcome.ACCUSED_LOSES, 3.0, accused
	)
	assert_true(r["case_cleared"])
	assert_eq(record.legal_status, Enums.LegalStatus.DECREED_GUILTY)
	assert_true(r.has("glory_delta"), "Lost trial with accused should include glory delta")
	assert_true(accused.glory < initial_glory, "Accused should lose glory on conviction")


# -- Attempted Murder ----

func test_attempted_murder_creates_record():
	var attacker := _make_char(1, "Scorpion", 3.0)
	var victim := _make_char(2, "Crane", 3.0)
	var r := CrimeWiring.process_attempted_murder(
		attacker, victim,
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING,
		10, 300, [4]
	)
	assert_not_null(r["record"])
	assert_eq(r["record"].crime_type, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	assert_almost_eq(r["evaluation"]["honor_loss"], -2.0, 0.01)


# -- Cross-Clan Disposition ----

func test_cross_clan_disposition_hit():
	var attacker := _make_char(1, "Scorpion", 3.0)
	var victim := _make_char(2, "Crane", 3.0)
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	var r := CrimeWiring.compute_cross_clan_disposition_change(
		record, attacker, victim, false
	)
	assert_true(r["applies"])
	assert_eq(r["disposition_hit"], -15)
	assert_eq(r["from_clan"], "Crane")


func test_same_clan_no_cross_clan_hit():
	var attacker := _make_char(1, "Lion", 3.0)
	var victim := _make_char(2, "Lion", 3.0)
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	var r := CrimeWiring.compute_cross_clan_disposition_change(
		record, attacker, victim, false
	)
	assert_false(r["applies"])


func test_cross_clan_cooperation_halves_hit():
	var attacker := _make_char(1, "Scorpion", 3.0)
	var victim := _make_char(2, "Crane", 3.0)
	var record := _make_crime_record(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	var r := CrimeWiring.compute_cross_clan_disposition_change(
		record, attacker, victim, true
	)
	assert_eq(r["disposition_hit"], -12)
