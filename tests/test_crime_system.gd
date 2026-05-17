extends GutTest


func _make_character(honor: float = 5.0, glory: float = 3.0, status: float = 3.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.honor = honor
	c.glory = glory
	c.status = status
	c.infamy = 0.0
	return c


func _make_record(crime_type: Enums.CrimeType = Enums.CrimeType.VIOLENCE) -> CrimeRecord:
	return CrimeSystem.create_crime_record(1, crime_type, 100, "test_zone", 10)


# -- Severity Lookup -----------------------------------------------------------

func test_severity_minor_dishonorable_conduct():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.DISHONORABLE_CONDUCT), Enums.CrimeSeverity.MINOR)

func test_severity_minor_violence():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.VIOLENCE), Enums.CrimeSeverity.MINOR)

func test_severity_moderate_skimming():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.SKIMMING), Enums.CrimeSeverity.MODERATE)

func test_severity_moderate_duel_death():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.UNSANCTIONED_DUEL_DEATH), Enums.CrimeSeverity.MODERATE)

func test_severity_moderate_duel_defilement():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.DUEL_DEFILEMENT), Enums.CrimeSeverity.MODERATE)

func test_severity_serious_open_killing():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING), Enums.CrimeSeverity.SERIOUS)

func test_severity_serious_covert_killing():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING), Enums.CrimeSeverity.SERIOUS)

func test_severity_serious_corruption():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.MAGISTRATE_CORRUPTION), Enums.CrimeSeverity.SERIOUS)

func test_severity_capital_treason():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.TREASON), Enums.CrimeSeverity.CAPITAL)

func test_severity_capital_maho():
	assert_eq(CrimeSystem.get_severity(Enums.CrimeType.MAHO), Enums.CrimeSeverity.CAPITAL)


# -- At-Act Honor Loss (Table 2.3) --------------------------------------------

func test_at_act_honor_loss_minor_low_rank():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.DISHONORABLE_CONDUCT, 2)
	assert_eq(loss, 0.0)

func test_at_act_honor_loss_minor_mid_rank():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.DISHONORABLE_CONDUCT, 5)
	assert_eq(loss, -0.2)

func test_at_act_honor_loss_minor_high_rank():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.DISHONORABLE_CONDUCT, 9)
	assert_eq(loss, -0.2)

func test_at_act_honor_loss_maho_rank_0():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.MAHO, 0)
	assert_eq(loss, -0.1)

func test_at_act_honor_loss_maho_high_rank():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.MAHO, 9)
	assert_eq(loss, -2.0)

func test_at_act_honor_loss_treason_rank_5():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.TREASON, 5)
	assert_eq(loss, -1.0)

func test_at_act_honor_loss_treason_rank_7():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.TREASON, 7)
	assert_eq(loss, -1.4)

func test_at_act_honor_loss_skimming_rank_3():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.SKIMMING, 3)
	assert_eq(loss, -0.3)

func test_at_act_honor_loss_violence_rank_8():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.VIOLENCE, 8)
	assert_eq(loss, -0.6)

func test_at_act_honor_loss_open_killing_rank_5():
	var loss: float = CrimeSystem.get_at_act_honor_loss(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, 5)
	assert_eq(loss, -1.2)


# -- Apply At-Act Consequences -------------------------------------------------

func test_apply_at_act_reduces_honor():
	var c := _make_character(5.0)
	var result: Dictionary = CrimeSystem.apply_at_act_consequences(c, Enums.CrimeType.TREASON)
	assert_lt(c.honor, 5.0)
	assert_eq(result["honor_delta"], c.honor - 5.0)

func test_apply_at_act_maho_high_honor():
	var c := _make_character(9.5)
	CrimeSystem.apply_at_act_consequences(c, Enums.CrimeType.MAHO)
	assert_almost_eq(c.honor, 7.5, 0.001)

func test_apply_at_act_no_loss_at_rank_0():
	var c := _make_character(0.3)
	CrimeSystem.apply_at_act_consequences(c, Enums.CrimeType.DISHONORABLE_CONDUCT)
	assert_almost_eq(c.honor, 0.3, 0.001)

func test_apply_at_act_honor_does_not_go_below_zero():
	var c := _make_character(0.05)
	CrimeSystem.apply_at_act_consequences(c, Enums.CrimeType.MAHO)
	assert_eq(c.honor, 0.0)


# -- At-Conviction Consequences ------------------------------------------------

func test_conviction_treason_glory():
	var c := _make_character(5.0, 5.0, 5.0)
	var record := _make_record(Enums.CrimeType.TREASON)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_almost_eq(c.glory, 3.0, 0.001)
	assert_almost_eq(result["glory_delta"], -2.0, 0.001)

func test_conviction_treason_infamy():
	var c := _make_character(5.0, 5.0, 5.0)
	var record := _make_record(Enums.CrimeType.TREASON)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_almost_eq(c.infamy, 3.0, 0.001)
	assert_almost_eq(result["infamy_delta"], 3.0, 0.001)

func test_conviction_treason_status_zeroed():
	var c := _make_character(5.0, 5.0, 7.0)
	var record := _make_record(Enums.CrimeType.TREASON)
	CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_eq(c.status, 0.0)

func test_conviction_maho_all_consequences():
	var c := _make_character(5.0, 5.0, 6.0)
	var record := _make_record(Enums.CrimeType.MAHO)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_almost_eq(c.glory, 2.0, 0.001)
	assert_almost_eq(c.infamy, 5.0, 0.001)
	assert_eq(c.status, 0.0)
	assert_eq(result["topic_tier"], 1)

func test_conviction_violence_minor_consequences():
	var c := _make_character(5.0, 3.0, 3.0)
	var record := _make_record(Enums.CrimeType.VIOLENCE)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_almost_eq(c.glory, 2.9, 0.001)
	assert_eq(c.infamy, 0.0)
	assert_eq(result["topic_tier"], 4)

func test_conviction_sets_legal_status():
	var c := _make_character()
	var record := _make_record(Enums.CrimeType.VIOLENCE)
	CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_eq(record.legal_status, Enums.LegalStatus.DECREED_GUILTY)

func test_conviction_seppuku_offered_for_eligible_crimes():
	var c := _make_character()
	var record := _make_record(Enums.CrimeType.TREASON)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_true(result["seppuku_offered"])

func test_conviction_seppuku_not_offered_for_maho():
	var c := _make_character()
	var record := _make_record(Enums.CrimeType.MAHO)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_false(result["seppuku_offered"])

func test_conviction_seppuku_not_offered_for_minor():
	var c := _make_character()
	var record := _make_record(Enums.CrimeType.DISHONORABLE_CONDUCT)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_false(result["seppuku_offered"])

func test_conviction_skimming_does_not_zero_status():
	var c := _make_character(5.0, 3.0, 4.0)
	var record := _make_record(Enums.CrimeType.SKIMMING)
	CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_eq(c.status, 4.0)

func test_conviction_covert_killing_high_status_victim_tier_2():
	var c := _make_character(5.0, 5.0, 5.0)
	var record := _make_record(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record, 6.0)
	assert_eq(result["topic_tier"], 2)

func test_conviction_covert_killing_low_status_victim_tier_3():
	var c := _make_character(5.0, 5.0, 5.0)
	var record := _make_record(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record, 2.0)
	assert_eq(result["topic_tier"], 3)

func test_conviction_covert_killing():
	var c := _make_character(5.0, 5.0, 5.0)
	var record := _make_record(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	var result: Dictionary = CrimeSystem.apply_at_conviction_consequences(c, record)
	assert_almost_eq(c.glory, 4.0, 0.001)
	assert_almost_eq(c.infamy, 2.0, 0.001)
	assert_eq(result["topic_tier"], 3)


# -- Seppuku Resolution -------------------------------------------------------

func test_seppuku_accepted_grants_honor():
	var c := _make_character(3.0)
	var record := _make_record(Enums.CrimeType.TREASON)
	var result: Dictionary = CrimeSystem.apply_seppuku_accepted(c, record)
	assert_almost_eq(c.honor, 4.0, 0.001)
	assert_true(result["character_dead"])
	assert_true(record.seppuku_accepted)

func test_seppuku_refused_penalties():
	var c := _make_character(3.0)
	var record := _make_record(Enums.CrimeType.TREASON)
	var result: Dictionary = CrimeSystem.apply_seppuku_refused(c, record)
	assert_almost_eq(c.honor, 2.0, 0.001)
	assert_almost_eq(c.infamy, 1.0, 0.001)
	assert_eq(result["topic_tier"], 4)
	assert_false(record.seppuku_accepted)
	assert_true(record.seppuku_offered)


# -- CrimeRecord Factory -------------------------------------------------------

func test_create_crime_record_basic():
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		42, Enums.CrimeType.MAHO, 100, "crab_province_1", 55
	)
	assert_eq(record.case_id, 42)
	assert_eq(record.crime_type, Enums.CrimeType.MAHO)
	assert_eq(record.severity, Enums.CrimeSeverity.CAPITAL)
	assert_eq(record.perpetrator_id, 100)
	assert_eq(record.location, "crab_province_1")
	assert_eq(record.ic_day_committed, 55)

func test_create_crime_record_with_witnesses():
	var witnesses: Array[int] = [200, 201, 202]
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		1, Enums.CrimeType.VIOLENCE, 100, "zone", 10, 150, 20, witnesses
	)
	assert_eq(record.witnesses.size(), 3)
	assert_eq(record.victim_id, 150)
	assert_eq(record.concealment_tn, 20)


# -- Legal Status Transitions --------------------------------------------------

func test_begin_investigation():
	var record := _make_record()
	CrimeSystem.begin_investigation(record, 500)
	assert_eq(record.legal_status, Enums.LegalStatus.UNDER_INVESTIGATION)
	assert_eq(record.investigating_magistrate_id, 500)

func test_formally_accuse():
	var record := _make_record()
	CrimeSystem.begin_investigation(record, 500)
	CrimeSystem.formally_accuse(record)
	assert_eq(record.legal_status, Enums.LegalStatus.ACCUSED)

func test_clear_suspect():
	var record := _make_record()
	CrimeSystem.begin_investigation(record, 500)
	CrimeSystem.clear_suspect(record)
	assert_eq(record.legal_status, Enums.LegalStatus.CLEAR)

func test_is_seppuku_eligible():
	assert_true(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.TREASON))
	assert_true(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING))
	assert_false(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.MAHO))
	assert_false(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.DISHONORABLE_CONDUCT))

func test_is_seppuku_eligible_skimming_above_threshold():
	assert_true(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.SKIMMING, 15.0))

func test_is_seppuku_eligible_skimming_below_threshold():
	assert_false(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.SKIMMING, 5.0))

func test_is_seppuku_eligible_skimming_at_threshold():
	assert_false(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.SKIMMING, 10.0))


# -- Escalation ----------------------------------------------------------------

func test_escalation_under_threshold():
	var records: Array = []
	for i in range(2):
		var r := CrimeSystem.create_crime_record(i, Enums.CrimeType.DISHONORABLE_CONDUCT, 1, "z", 10 + i)
		records.append(r)
	assert_false(CrimeSystem.check_escalation(records, 50, 90))

func test_escalation_at_threshold():
	var records: Array = []
	for i in range(3):
		var r := CrimeSystem.create_crime_record(i, Enums.CrimeType.DISHONORABLE_CONDUCT, 1, "z", 10 + i)
		records.append(r)
	assert_true(CrimeSystem.check_escalation(records, 50, 90))

func test_escalation_old_records_not_counted():
	var records: Array = []
	for i in range(3):
		var r := CrimeSystem.create_crime_record(i, Enums.CrimeType.DISHONORABLE_CONDUCT, 1, "z", 10 + i)
		records.append(r)
	# Current day is far past the window (4 seasons * 90 days = 360 days)
	assert_false(CrimeSystem.check_escalation(records, 500, 90))

func test_escalation_ignores_other_crime_types():
	var records: Array = []
	for i in range(5):
		var r := CrimeSystem.create_crime_record(i, Enums.CrimeType.VIOLENCE, 1, "z", 10 + i)
		records.append(r)
	assert_false(CrimeSystem.check_escalation(records, 50, 90))
