extends GutTest
## Tests for InvestigationLoopSystem per GDD s11.3.13.
## Tests for witness tampering, discovery type, concealment, zone log purge.


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
		InvestigationLoopSystem.get_initial_legal_status(
			InvestigationLoopSystem.DiscoveryType.IMMEDIATE
		),
		Enums.LegalStatus.UNDER_INVESTIGATION
	)


func test_gradual_starts_suspected():
	assert_eq(
		InvestigationLoopSystem.get_initial_legal_status(
			InvestigationLoopSystem.DiscoveryType.GRADUAL
		),
		Enums.LegalStatus.SUSPECTED
	)


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
