extends GutTest
## Tests for RoninSystem (s52 Part 5, s52.5).


func _make_samurai(id: int = 1) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Test Samurai"
	c.clan = "Lion"
	c.family = "Akodo"
	c.school = "Akodo Bushi"
	c.school_type = Enums.SchoolType.BUSHI
	c.lord_id = 100
	c.role_position = "Samurai"
	c.status = 2.0
	c.honor = 5.0
	c.glory = 3.0
	c.stamina = 3
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 3
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 3
	c.void_ring = 2
	c.skills = {"Kenjutsu": 3, "Battle": 2, "Etiquette": 2, "Courtier": 3}
	c.koku = 10.0
	c.bushido_virtue = Enums.BushidoVirtue.YU
	return c


func _make_lord(id: int = 100) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Lord"
	c.clan = "Crane"
	c.lord_id = -1
	c.status = 5.0
	c.awareness = 3
	c.skills = {"Etiquette": 3}
	c.disposition_values = {}
	return c


# === MAKE RONIN ===

func test_make_ronin_clears_lord():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_eq(c.lord_id, -1)

func test_make_ronin_clears_role():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_eq(c.role_position, "")

func test_make_ronin_clears_military():
	var c := _make_samurai()
	c.military_rank = Enums.MilitaryRank.GUNSO
	c.commanded_unit_id = 5
	c.assigned_company_id = 3
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_eq(c.military_rank, Enums.MilitaryRank.NONE)
	assert_eq(c.commanded_unit_id, -1)
	assert_eq(c.assigned_company_id, -1)

func test_make_ronin_reduces_status():
	var c := _make_samurai()
	c.status = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_almost_eq(c.status, 2.0, 0.01)

func test_make_ronin_status_floor_zero():
	var c := _make_samurai()
	c.status = 0.5
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_almost_eq(c.status, 0.0, 0.01)

func test_make_ronin_all_causes_status_drop_same():
	# All causes drop Status by 1.0 — no cause gets extra Status loss (s52.5).
	for cause in [
		RoninSystem.RoninCause.LORD_DEATH_NO_HEIR,
		RoninSystem.RoninCause.CLAN_DESTROYED,
		RoninSystem.RoninCause.VOLUNTARY_DEPARTURE,
		RoninSystem.RoninCause.DISMISSAL,
		RoninSystem.RoninCause.DISMISSAL_DISGRACE,
	]:
		var c := _make_samurai()
		c.status = 3.0
		RoninSystem.make_ronin(c, cause)
		assert_almost_eq(c.status, 2.0, 0.01, "cause %d should drop status by 1.0" % cause)

func test_make_ronin_honor_unaffected():
	# Honor is NOT changed on becoming ronin — Glory only (s52.5).
	var c := _make_samurai()
	c.honor = 5.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL_DISGRACE)
	assert_almost_eq(c.honor, 5.0, 0.01)

func test_make_ronin_glory_loss_lord_death_no_heir():
	var c := _make_samurai()
	c.glory = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_almost_eq(c.glory, 3.0 - RoninSystem.GLORY_LOSS_LORD_DEATH_NO_HEIR, 0.01)

func test_make_ronin_glory_loss_clan_destroyed():
	var c := _make_samurai()
	c.glory = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.CLAN_DESTROYED)
	assert_almost_eq(c.glory, 3.0 - RoninSystem.GLORY_LOSS_CLAN_DESTROYED, 0.01)

func test_make_ronin_glory_loss_dismissal():
	var c := _make_samurai()
	c.glory = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_almost_eq(c.glory, 3.0 - RoninSystem.GLORY_LOSS_DISMISSAL, 0.01)

func test_make_ronin_glory_loss_dismissal_disgrace():
	var c := _make_samurai()
	c.glory = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL_DISGRACE)
	assert_almost_eq(c.glory, 3.0 - RoninSystem.GLORY_LOSS_DISMISSAL_DISGRACE, 0.01)

func test_make_ronin_glory_loss_voluntary_uses_disloyalty_scale():
	# VOLUNTARY_DEPARTURE uses rank-scaled disloyalty Glory (s52.5 A40).
	var c := _make_samurai()
	c.honor = 5.0  # honor rank 5 → HONOR_TABLE_DISLOYALTY index 5 → -14 → -1.4
	c.glory = 5.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	var expected_loss: float = absf(CrimeSystem.get_disloyalty_honor(c))
	# Glory loss equals |disloyalty cost| at this honor rank; Glory went down.
	assert_true(c.glory < 5.0)
	assert_almost_eq(c.glory, 5.0 - expected_loss, 0.01)

func test_make_ronin_preserves_original_lord():
	var c := _make_samurai()
	c.lord_id = 100
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_eq(c.original_lord_id, 100)

func test_make_ronin_keeps_stats():
	var c := _make_samurai()
	var old_agility: int = c.agility
	var old_kenjutsu: int = c.skills.get("Kenjutsu", 0)
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_eq(c.agility, old_agility)
	assert_eq(c.skills.get("Kenjutsu", 0), old_kenjutsu)

func test_make_ronin_returns_report():
	var c := _make_samurai()
	var result: Dictionary = RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_eq(result["character_id"], c.character_id)
	assert_eq(result["cause"], RoninSystem.RoninCause.DISMISSAL)
	assert_eq(result["old_clan"], "Lion")
	assert_eq(result["old_role"], "Samurai")

func test_make_ronin_clears_operational_hierarchy():
	var c := _make_samurai()
	c.operational_superior_id = 50
	c.operational_hierarchy_type = Enums.OperationalHierarchyType.MILITARY
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.CLAN_DESTROYED)
	assert_eq(c.operational_superior_id, -1)
	assert_eq(c.operational_hierarchy_type, Enums.OperationalHierarchyType.NONE)


# === IS RONIN ===

func test_is_ronin_true():
	var c := _make_samurai()
	c.status = 0.5
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_true(RoninSystem.is_ronin(c))

func test_is_ronin_false_with_lord():
	var c := _make_samurai()
	assert_false(RoninSystem.is_ronin(c))

func test_is_ronin_false_lord_tier():
	var c := _make_samurai()
	c.lord_id = -1
	c.role_position = "Clan Champion"
	c.status = 7.0
	assert_false(RoninSystem.is_ronin(c))


# === ACCEPT INTO SERVICE ===

func test_accept_into_service_sets_lord_and_role():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_eq(c.lord_id, 200)
	assert_eq(c.role_position, "Retainer")
	assert_true(c.status >= 1.0)

func test_accept_into_service_clan_unchanged():
	# Hiring as retainer does NOT change clan — formal induction is a separate step (s52.5 D).
	var c := _make_samurai()
	c.clan = "Lion"
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_eq(c.clan, "Lion")

func test_accept_restores_glory():
	# s52.5 A43: HIRING_GLORY_RECOVERY = 0.3
	var c := _make_samurai()
	c.status = 0.8
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var glory_before: float = c.glory
	RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_almost_eq(c.glory, glory_before + RoninSystem.HIRING_GLORY_RECOVERY, 0.01)

func test_accept_honor_unchanged():
	# Honor is not modified on acceptance (s52.5 D).
	var c := _make_samurai()
	c.honor = 5.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_almost_eq(c.honor, 5.0, 0.01)

func test_accept_clears_petition_cooldown():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	c.supply_ledger["petition_refused_until"] = 500
	RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_false(c.supply_ledger.has("petition_refused_until"))

func test_no_longer_ronin_after_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_false(RoninSystem.is_ronin(c))


# === PETITION ===

func test_petition_negative_disposition_auto_rejects():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var lord := _make_lord()
	var dice := DiceEngine.new(42)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice, -5)
	assert_false(result["success"])
	assert_true(result.get("rejected", false))
	assert_eq(result.get("reason", ""), "disposition_too_low")

func test_petition_permanent_ronin_auto_rejects():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	c.permanent_ronin = true
	var lord := _make_lord()
	var dice := DiceEngine.new(42)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice, 20)
	assert_false(result["success"])
	assert_true(result.get("rejected", false))
	assert_eq(result.get("reason", ""), "permanent_ronin")

func test_petition_returns_roll_totals():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var lord := _make_lord()
	var dice := DiceEngine.new(12345)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice, 0)
	assert_true(result.has("ronin_total"))
	assert_true(result.has("lord_total"))
	assert_true(result.has("margin"))
	assert_true(result.has("presentation_modifier"))

func test_petition_presentation_modifier_from_margin():
	# presentation_modifier = margin / PETITION_MARGIN_SCALE (integer division).
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var lord := _make_lord()
	var dice := DiceEngine.new(99999)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice, 0)
	var expected_modifier: int = result["margin"] / RoninSystem.PETITION_MARGIN_SCALE
	assert_eq(result["presentation_modifier"], expected_modifier)

func test_petition_success_requires_min_tn():
	# Even if ronin wins the contested roll, must beat PETITION_MIN_TN = 20.
	var c := _make_samurai()
	# Zero all skills so roll total is likely below 20.
	c.skills = {}
	c.awareness = 1
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var lord := _make_lord()
	lord.skills = {}
	lord.awareness = 1
	var dice := DiceEngine.new(1)  # Low seed → low rolls
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice, 0)
	# success == (ronin_total >= 20)
	assert_eq(result["success"], result["ronin_total"] >= RoninSystem.PETITION_MIN_TN)


# === LORD AUTO-REJECTS ===

func test_lord_auto_rejects_permanent_ronin():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	petitioner.permanent_ronin = true
	assert_true(RoninSystem.lord_auto_rejects(lord, petitioner, 10, []))

func test_lord_auto_rejects_negative_disposition():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	assert_true(RoninSystem.lord_auto_rejects(lord, petitioner, -1, []))

func test_lord_auto_rejects_treason():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	assert_true(RoninSystem.lord_auto_rejects(lord, petitioner, 5, [Enums.CrimeType.TREASON]))

func test_lord_auto_rejects_maho():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	assert_true(RoninSystem.lord_auto_rejects(lord, petitioner, 5, [Enums.CrimeType.MAHO_USE]))

func test_lord_auto_rejects_murder():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	assert_true(RoninSystem.lord_auto_rejects(lord, petitioner, 5, [Enums.CrimeType.UNSANCTIONED_COVERT_KILLING]))

func test_lord_does_not_auto_reject_neutral_no_crimes():
	var lord := _make_lord()
	var petitioner := _make_samurai()
	assert_false(RoninSystem.lord_auto_rejects(lord, petitioner, 0, []))


# === PERMANENT RONIN: FIVE DISGRACES ===

func _make_disgrace_record(perpetrator_id: int) -> CrimeRecord:
	var rec := CrimeRecord.new()
	rec.perpetrator_id = perpetrator_id
	rec.source_action = "dismissal_disgrace"
	return rec

func test_five_disgraces_sets_permanent_ronin():
	var c := _make_samurai()
	var recs: Array = []
	for i in range(RoninSystem.PERMANENT_RONIN_DISGRACE_COUNT):
		recs.append(_make_disgrace_record(c.character_id))
	RoninSystem.check_permanent_ronin_on_disgrace(c, recs)
	assert_true(c.permanent_ronin)

func test_four_disgraces_does_not_set_permanent_ronin():
	var c := _make_samurai()
	var recs: Array = [
		_make_disgrace_record(c.character_id),
		_make_disgrace_record(c.character_id),
		_make_disgrace_record(c.character_id),
		_make_disgrace_record(c.character_id),
	]
	RoninSystem.check_permanent_ronin_on_disgrace(c, recs)
	assert_false(c.permanent_ronin)

func test_disgrace_only_counts_own_records():
	var c := _make_samurai(1)
	var recs: Array = []
	for i in range(RoninSystem.PERMANENT_RONIN_DISGRACE_COUNT):
		recs.append(_make_disgrace_record(2))
	RoninSystem.check_permanent_ronin_on_disgrace(c, recs)
	assert_false(c.permanent_ronin)

func test_already_permanent_returns_true_immediately():
	var c := _make_samurai()
	c.permanent_ronin = true
	assert_true(RoninSystem.check_permanent_ronin_on_disgrace(c, []))


# === INCOME TRACKING & DESPERATION ===

func test_mark_ronin_start():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	assert_eq(c.supply_ledger.get("ronin_since_season"), 10)
	assert_eq(c.supply_ledger.get("last_income_season"), 10)

func test_seasons_without_income():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	assert_eq(RoninSystem.get_seasons_without_income(c, 12), 2)

func test_record_income_resets_counter():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	RoninSystem.record_income(c, 13)
	assert_eq(RoninSystem.get_seasons_without_income(c, 14), 1)

func test_debt_after_4_seasons():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.check_desperation(c, 14)
	assert_eq(result["state"], "debt")
	assert_true(c.disadvantages.has("Debt"))

func test_no_debt_before_4_seasons():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.check_desperation(c, 13)
	assert_eq(result["state"], "stable")
	assert_false(c.disadvantages.has("Debt"))

func test_desperate_after_8_seasons():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.check_desperation(c, 18)
	assert_eq(result["state"], "desperate")

func test_is_desperate():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	assert_false(RoninSystem.is_desperate(c, 14))
	assert_true(RoninSystem.is_desperate(c, 18))


# === INSURGENCY SEEDING ===

func test_can_seed_insurgency_when_desperate():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 0)
	assert_true(RoninSystem.can_seed_insurgency(c, 10))

func test_cannot_seed_insurgency_not_desperate():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	assert_false(RoninSystem.can_seed_insurgency(c, 14))


# === MERCENARY HIRING ===

func test_hire_as_mercenary():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.hire_as_mercenary(c, 200, 5.0, 12)
	assert_eq(result["employer_id"], 200)
	assert_almost_eq(c.koku, 15.0, 0.01)
	assert_eq(c.operational_superior_id, 200)
	assert_eq(c.supply_ledger.get("last_income_season"), 12)


# === SEASONAL PROCESSING ===

func test_process_seasonal_skips_non_ronin():
	var c := _make_samurai()
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 20)
	assert_eq(result["debt_results"].size(), 0)
	assert_eq(result["desperate_results"].size(), 0)

func test_process_seasonal_skips_dead():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 0)
	c.wounds_taken = 999
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 20)
	assert_eq(result["debt_results"].size(), 0)

func test_process_seasonal_detects_debt():
	var c := _make_samurai()
	c.status = 0.5
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 14)
	assert_eq(result["debt_results"].size(), 1)

func test_process_seasonal_detects_desperate():
	var c := _make_samurai()
	c.status = 0.5
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 18)
	assert_eq(result["desperate_results"].size(), 1)

func test_process_seasonal_insurgency_seeds():
	var c := _make_samurai()
	c.status = 0.5
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 18)
	assert_true(result["insurgency_seeds"].has(c.character_id))

func test_process_seasonal_multiple_characters():
	var c1 := _make_samurai(1)
	var c2 := _make_samurai(2)
	c2.character_id = 2
	c1.status = 0.5
	c2.status = 0.5
	RoninSystem.make_ronin(c1, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.make_ronin(c2, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c1, 0)
	RoninSystem.mark_ronin_start(c2, 5)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c1, c2], 10)
	# c1: 10 seasons without income -> desperate + insurgency seed
	# c2: 5 seasons without income -> debt
	assert_eq(result["desperate_results"].size(), 1)
	assert_eq(result["debt_results"].size(), 1)


# === RONIN CAUSE ENUM ===

func test_all_causes_exist():
	assert_eq(RoninSystem.RoninCause.LORD_DEATH_NO_HEIR, 0)
	assert_eq(RoninSystem.RoninCause.DISMISSAL, 1)
	assert_eq(RoninSystem.RoninCause.DISMISSAL_DISGRACE, 2)
	assert_eq(RoninSystem.RoninCause.CLAN_DESTROYED, 3)
	assert_eq(RoninSystem.RoninCause.VOLUNTARY_DEPARTURE, 4)


# === PERMANENT RONIN GATES ===

func test_permanent_ronin_rejects_accept_into_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	c.permanent_ronin = true
	var result: Dictionary = RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_true(result.get("rejected", false))
	assert_eq(c.lord_id, -1)

func test_non_permanent_ronin_accepts_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_false(c.permanent_ronin)
	var result: Dictionary = RoninSystem.accept_into_service(c, 200, "Retainer")
	assert_false(result.get("rejected", false))
	assert_eq(c.lord_id, 200)
