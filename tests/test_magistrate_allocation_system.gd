extends GutTest
## Tests for MagistrateAllocationSystem per GDD s11.3.17.


# -- Magistrate Count (s11.3.17a) ----

func test_rural_province_base_count():
	var count := MagistrateAllocationSystem.get_magistrate_count(false, 0, false)
	assert_eq(count, 1)


func test_province_with_one_city():
	var count := MagistrateAllocationSystem.get_magistrate_count(true, 1, false)
	assert_eq(count, 2)


func test_province_with_multiple_cities():
	var count := MagistrateAllocationSystem.get_magistrate_count(true, 3, false)
	assert_eq(count, 4)


func test_otosan_uchi_default_districts():
	var count := MagistrateAllocationSystem.get_magistrate_count(false, 0, true)
	assert_eq(count, 17)


func test_otosan_uchi_custom_districts():
	var count := MagistrateAllocationSystem.get_magistrate_count(false, 0, true, 10)
	assert_eq(count, 10)


func test_otosan_uchi_ignores_city_flag():
	var count := MagistrateAllocationSystem.get_magistrate_count(true, 5, true)
	assert_eq(count, 17)


# -- Yoriki (s11.3.17b) ----

func test_yoriki_range_rural():
	var r := MagistrateAllocationSystem.get_yoriki_range(
		MagistrateAllocationSystem.JurisdictionType.RURAL
	)
	assert_eq(r["min"], 1)
	assert_eq(r["max"], 2)


func test_yoriki_range_city():
	var r := MagistrateAllocationSystem.get_yoriki_range(
		MagistrateAllocationSystem.JurisdictionType.CITY
	)
	assert_eq(r["min"], 4)
	assert_eq(r["max"], 5)


func test_yoriki_range_major():
	var r := MagistrateAllocationSystem.get_yoriki_range(
		MagistrateAllocationSystem.JurisdictionType.MAJOR
	)
	assert_eq(r["min"], 4)
	assert_eq(r["max"], 12)


func test_investigation_capacity():
	assert_eq(MagistrateAllocationSystem.get_investigation_capacity(2), 3)
	assert_eq(MagistrateAllocationSystem.get_investigation_capacity(0), 1)


# -- Case Load and Availability (s11.3.17d) ----

func test_magistrate_available_no_cases():
	assert_true(MagistrateAllocationSystem.is_magistrate_available(0))


func test_magistrate_unavailable_with_case():
	assert_false(MagistrateAllocationSystem.is_magistrate_available(1))
	assert_false(MagistrateAllocationSystem.is_magistrate_available(3))


func test_case_queue_status_clear():
	var r := MagistrateAllocationSystem.get_case_queue_status(0, 0)
	assert_false(r["magistrate_occupied"])
	assert_false(r["legal_coverage_compromised"])


func test_case_queue_status_occupied_with_pending():
	var r := MagistrateAllocationSystem.get_case_queue_status(1, 2)
	assert_true(r["magistrate_occupied"])
	assert_eq(r["crimes_waiting"], 2)
	assert_true(r["legal_coverage_compromised"])


func test_case_queue_occupied_no_pending():
	var r := MagistrateAllocationSystem.get_case_queue_status(1, 0)
	assert_true(r["magistrate_occupied"])
	assert_false(r["legal_coverage_compromised"])


# -- Conviction Cascade (s11.3.17e) ----

func test_conviction_cascade_magistrate():
	var r := MagistrateAllocationSystem.get_conviction_cascade(
		MagistrateAllocationSystem.ConvictedPosition.MAGISTRATE
	)
	assert_eq(r["position"], "magistrate")
	assert_true(r["cases_suspended"])
	assert_true(r["replacement_required"])
	assert_true(r["replacement_re_examines_evidence"])
	assert_eq(r["stability_hit"], 0)
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_4)


func test_conviction_cascade_governor():
	var r := MagistrateAllocationSystem.get_conviction_cascade(
		MagistrateAllocationSystem.ConvictedPosition.GOVERNOR
	)
	assert_eq(r["position"], "governor")
	assert_true(r["succession_fires"])
	assert_eq(r["stability_hit"], -5)
	assert_eq(r["stability_scope"], "province")
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_3)


func test_conviction_cascade_family_daimyo():
	var r := MagistrateAllocationSystem.get_conviction_cascade(
		MagistrateAllocationSystem.ConvictedPosition.FAMILY_DAIMYO
	)
	assert_eq(r["position"], "family_daimyo")
	assert_true(r["succession_fires"])
	assert_eq(r["stability_hit"], -5)
	assert_eq(r["stability_scope"], "family_provinces")
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_2)
	assert_eq(r["scope"], "clan")


func test_conviction_cascade_clan_champion():
	var r := MagistrateAllocationSystem.get_conviction_cascade(
		MagistrateAllocationSystem.ConvictedPosition.CLAN_CHAMPION
	)
	assert_eq(r["position"], "clan_champion")
	assert_true(r["succession_fires"])
	assert_eq(r["stability_hit"], -5)
	assert_eq(r["stability_scope"], "all_clan_provinces")
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_2)
	assert_eq(r["scope"], "empire")


# -- Magistrate Conviction Resolution ----

func _make_record(
	case_id: int,
	magistrate_id: int,
	status: Enums.LegalStatus,
) -> CrimeRecord:
	var r := CrimeRecord.new()
	r.case_id = case_id
	r.investigating_magistrate_id = magistrate_id
	r.legal_status = status
	return r


func test_resolve_magistrate_conviction_suspends_active_cases():
	var records: Array = [
		_make_record(1, 5, Enums.LegalStatus.UNDER_INVESTIGATION),
		_make_record(2, 5, Enums.LegalStatus.ACCUSED),
		_make_record(3, 5, Enums.LegalStatus.DECREED_GUILTY),
		_make_record(4, 9, Enums.LegalStatus.UNDER_INVESTIGATION),
	]
	var r := MagistrateAllocationSystem.resolve_magistrate_conviction(5, records)
	assert_eq(r["case_count"], 2)
	assert_has(r["suspended_case_ids"], 1)
	assert_has(r["suspended_case_ids"], 2)
	assert_true(r["replacement_needed"])
	assert_true(r["evidence_preserved"])


func test_resolve_magistrate_conviction_no_active_cases():
	var records: Array = [
		_make_record(1, 5, Enums.LegalStatus.DECREED_GUILTY),
	]
	var r := MagistrateAllocationSystem.resolve_magistrate_conviction(5, records)
	assert_eq(r["case_count"], 0)


func test_assign_replacement_magistrate():
	var records: Array = [
		_make_record(1, 5, Enums.LegalStatus.UNDER_INVESTIGATION),
		_make_record(2, 5, Enums.LegalStatus.ACCUSED),
		_make_record(3, 9, Enums.LegalStatus.UNDER_INVESTIGATION),
	]
	var suspended: Array = [1, 2]
	var r := MagistrateAllocationSystem.assign_replacement_magistrate(
		suspended, 20, records
	)
	assert_eq(r["new_magistrate_id"], 20)
	assert_eq(r["cases_reassigned"], 2)
	assert_true(r["must_re_examine_evidence"])
	assert_eq(records[0].investigating_magistrate_id, 20)
	assert_eq(records[1].investigating_magistrate_id, 20)
	assert_eq(records[2].investigating_magistrate_id, 9)


# -- Vacancy Effects (s11.3.17e) ----

func test_vacancy_effects_magistrate():
	var r := MagistrateAllocationSystem.get_vacancy_effects(
		MagistrateAllocationSystem.ConvictedPosition.MAGISTRATE
	)
	assert_true(r["investigations_blocked"])
	assert_true(r["new_crimes_unprocessed"])
	assert_true(r["existing_cases_frozen"])


func test_vacancy_effects_governor():
	var r := MagistrateAllocationSystem.get_vacancy_effects(
		MagistrateAllocationSystem.ConvictedPosition.GOVERNOR
	)
	assert_true(r["tax_rates_frozen"])
	assert_true(r["no_new_construction"])
	assert_true(r["no_levy_orders"])
	assert_true(r["stability_decays"])


func test_vacancy_effects_higher_positions():
	var r := MagistrateAllocationSystem.get_vacancy_effects(
		MagistrateAllocationSystem.ConvictedPosition.FAMILY_DAIMYO
	)
	assert_true(r["administrative_paralysis"])
	assert_true(r["stability_decays"])
	assert_eq(r["appointment_urgency"], "critical")


# -- Emerald Magistrate (s11.3.17c) ----

func test_emerald_magistrate_total():
	assert_eq(MagistrateAllocationSystem.EMERALD_MAGISTRATE_TOTAL, 6)


func test_emerald_jurisdiction_cross_clan():
	assert_true(MagistrateAllocationSystem.is_emerald_jurisdiction(
		MagistrateAllocationSystem.EmeraldJurisdictionTrigger.CROSS_CLAN_CRIME
	))


func test_emerald_jurisdiction_treason():
	assert_true(MagistrateAllocationSystem.is_emerald_jurisdiction(
		MagistrateAllocationSystem.EmeraldJurisdictionTrigger.TREASON
	))


func test_emerald_jurisdiction_maho():
	assert_true(MagistrateAllocationSystem.is_emerald_jurisdiction(
		MagistrateAllocationSystem.EmeraldJurisdictionTrigger.MAHO
	))


func test_emerald_jurisdiction_local_failed():
	assert_true(MagistrateAllocationSystem.is_emerald_jurisdiction(
		MagistrateAllocationSystem.EmeraldJurisdictionTrigger.LOCAL_JUSTICE_FAILED
	))


func test_emerald_can_override_clan():
	assert_true(MagistrateAllocationSystem.can_override_clan_magistrate())


func test_emerald_assignment_topic_tier():
	assert_eq(MagistrateAllocationSystem.get_emerald_assignment_topic_tier(), TopicData.Tier.TIER_3)
