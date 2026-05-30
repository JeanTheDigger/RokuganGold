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


# === STANDING OBJECTIVE ASSIGNMENT ===

func _make_ronin_char(id: int = 10) -> L5RCharacterData:
	var c := _make_samurai(id)
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	return c


func test_assign_ronin_standing_assigns_find_new_lord():
	var c := _make_ronin_char()
	var objectives_map: Dictionary = {}
	DayOrchestrator._assign_ronin_standing_objectives([c], objectives_map)
	var standing: Dictionary = objectives_map[c.character_id].get("standing", {})
	assert_eq(standing.get("need_type", ""), "FIND_NEW_LORD")


func test_assign_ronin_standing_skips_non_ronin():
	var c := _make_samurai()  # still has lord_id=100 and role_position
	var objectives_map: Dictionary = {}
	DayOrchestrator._assign_ronin_standing_objectives([c], objectives_map)
	assert_false(objectives_map.has(c.character_id))


func test_assign_ronin_standing_skips_permanent_ronin():
	var c := _make_ronin_char()
	c.permanent_ronin = true
	var objectives_map: Dictionary = {}
	DayOrchestrator._assign_ronin_standing_objectives([c], objectives_map)
	assert_false(objectives_map.has(c.character_id))


func test_assign_ronin_standing_skips_dead():
	var c := _make_ronin_char()
	c.wounds_taken = 999
	var objectives_map: Dictionary = {}
	DayOrchestrator._assign_ronin_standing_objectives([c], objectives_map)
	assert_false(objectives_map.has(c.character_id))


func test_assign_ronin_standing_does_not_overwrite_existing():
	var c := _make_ronin_char()
	var objectives_map: Dictionary = {
		c.character_id: {"standing": {"need_type": "UPHOLD_LAW"}},
	}
	DayOrchestrator._assign_ronin_standing_objectives([c], objectives_map)
	assert_eq(objectives_map[c.character_id]["standing"]["need_type"], "UPHOLD_LAW")


# === EXECUTOR: PETITION_RONIN ===

func _make_ctx_for_petition(ronin_id: int, lord_id: int, loc: String = "1") -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = ronin_id
	ctx.ic_day = 100
	ctx.season = 1
	ctx.location_id = loc
	ctx.characters_present = [lord_id]
	ctx.disposition_values = {lord_id: 10}
	return ctx


func test_executor_petition_ronin_no_lord_present():
	var ronin := _make_ronin_char()
	var ctx := _make_ctx_for_petition(ronin.character_id, 200)
	ctx.characters_present = []
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PETITION_RONIN"
	action.target_npc_id = -1
	action.metadata = {"target_lord_id": -1}
	var result: Dictionary = ActionExecutor.execute(action, ronin, ctx, DiceEngine.new(42), {})
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_lord_present")


func test_executor_petition_ronin_cooldown_blocks():
	var ronin := _make_ronin_char()
	ronin.supply_ledger["petition_refused_until"] = 200
	var lord := _make_lord(200)
	var ctx := _make_ctx_for_petition(ronin.character_id, 200)
	var chars: Dictionary = {200: lord}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PETITION_RONIN"
	action.target_npc_id = 200
	action.metadata = {"target_lord_id": 200}
	var result: Dictionary = ActionExecutor.execute(action, ronin, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "petition_cooldown")


func test_executor_petition_ronin_auto_rejected_low_disposition():
	var ronin := _make_ronin_char()
	var lord := _make_lord(200)
	var ctx := _make_ctx_for_petition(ronin.character_id, 200)
	ctx.disposition_values = {200: -5}
	var chars: Dictionary = {200: lord}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PETITION_RONIN"
	action.target_npc_id = 200
	action.metadata = {"target_lord_id": 200}
	var result: Dictionary = ActionExecutor.execute(action, ronin, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "auto_rejected")
	assert_eq(result.get("effects", {}).get("petition_refused_until", -1),
		100 + RoninSystem.PETITION_COOLDOWN_DAYS)


func test_executor_petition_ronin_success_returns_acceptance_flag():
	var ronin := _make_ronin_char()
	ronin.skills = {"Courtier": 5, "Etiquette": 3}
	ronin.awareness = 4
	var lord := _make_lord(200)
	lord.skills = {"Etiquette": 1}
	lord.awareness = 1
	var ctx := _make_ctx_for_petition(ronin.character_id, 200)
	ctx.disposition_values = {200: 20}
	var chars: Dictionary = {200: lord}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PETITION_RONIN"
	action.target_npc_id = 200
	action.metadata = {"target_lord_id": 200}
	# High seed gives high rolls → petition likely succeeds and effective_disp >= 0.
	var dice := DiceEngine.new(999999)
	var result: Dictionary = ActionExecutor.execute(action, ronin, ctx, dice, {}, {}, chars)
	if result.get("success", false):
		assert_true(result.get("effects", {}).get("requires_ronin_acceptance", false))
		assert_eq(result.get("effects", {}).get("accepting_lord_id", -1), 200)
		assert_eq(result.get("effects", {}).get("ronin_id", -1), ronin.character_id)


# === EXECUTOR: ACCEPT_RONIN_PETITION ===

func _make_ctx_for_lord(lord_id: int, ronin_id: int, loc: String = "1") -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = lord_id
	ctx.ic_day = 100
	ctx.season = 1
	ctx.location_id = loc
	ctx.characters_present = [ronin_id]
	ctx.is_lord = true
	return ctx


func test_executor_accept_ronin_petition_no_ronin_present():
	var lord := _make_lord(200)
	var ctx := _make_ctx_for_lord(200, 10)
	ctx.characters_present = []
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ACCEPT_RONIN_PETITION"
	action.target_npc_id = -1
	action.metadata = {"target_ronin_id": -1}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {})
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_ronin_present")


func test_executor_accept_ronin_petition_not_a_ronin():
	var lord := _make_lord(200)
	var samurai := _make_samurai(10)  # still has lord and role
	lord.disposition_values = {10: 5}
	var ctx := _make_ctx_for_lord(200, 10)
	var chars: Dictionary = {10: samurai}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ACCEPT_RONIN_PETITION"
	action.target_npc_id = 10
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "not_eligible")


func test_executor_accept_ronin_petition_succeeds():
	var lord := _make_lord(200)
	var ronin := _make_ronin_char(10)
	lord.disposition_values = {10: 10}
	var ctx := _make_ctx_for_lord(200, 10)
	var chars: Dictionary = {10: ronin}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ACCEPT_RONIN_PETITION"
	action.target_npc_id = 10
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_true(result.get("success", false))
	assert_true(result.get("effects", {}).get("requires_ronin_acceptance", false))
	assert_eq(result.get("effects", {}).get("accepting_lord_id", -1), 200)


func test_executor_accept_ronin_petition_rejects_permanent_ronin():
	var lord := _make_lord(200)
	var ronin := _make_ronin_char(10)
	ronin.permanent_ronin = true
	lord.disposition_values = {10: 10}
	var ctx := _make_ctx_for_lord(200, 10)
	var chars: Dictionary = {10: ronin}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ACCEPT_RONIN_PETITION"
	action.target_npc_id = 10
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "not_eligible")


# === WRITEBACK: _process_petition_writebacks ===

func test_writeback_acceptance_calls_accept_into_service():
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {10: ronin}
	var objectives_map: Dictionary = {
		10: {"standing": {"need_type": "FIND_NEW_LORD"}},
	}
	var results: Array = [{
		"action_id": "PETITION_RONIN",
		"character_id": 10,
		"success": true,
		"effects": {
			"requires_ronin_acceptance": true,
			"accepting_lord_id": 200,
			"ronin_id": 10,
		},
	}]
	DayOrchestrator._process_petition_writebacks(results, chars, objectives_map, 5)
	assert_eq(ronin.lord_id, 200)
	assert_eq(ronin.role_position, "Samurai")
	assert_false(objectives_map[10].has("standing"))


func test_writeback_failure_writes_cooldown():
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {10: ronin}
	var objectives_map: Dictionary = {}
	var refused_day: int = 100 + RoninSystem.PETITION_COOLDOWN_DAYS
	var results: Array = [{
		"action_id": "PETITION_RONIN",
		"character_id": 10,
		"success": false,
		"effects": {
			"failed": true,
			"petition_refused_until": refused_day,
			"recipient_disposition_change": -3,
		},
	}]
	DayOrchestrator._process_petition_writebacks(results, chars, objectives_map, 5)
	assert_eq(ronin.supply_ledger.get("petition_refused_until", -1), refused_day)


# =============================================================================
# s52.6 CONTRACT HIRE SYSTEM
# =============================================================================


func _make_lord_with_family(id: int, clan: String, family: String) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Lord"
	c.clan = clan
	c.family = family
	c.lord_id = -1
	c.status = 5.0
	c.awareness = 3
	c.skills = {"Courtier": 5, "Etiquette": 3}
	c.koku = 50.0
	c.disposition_values = {}
	return c


func _make_ctx_for_hire(lord_id: int, ronin_id: int, loc: String = "1") -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = lord_id
	ctx.ic_day = 100
	ctx.season = 1
	ctx.location_id = loc
	ctx.characters_present = [ronin_id]
	ctx.disposition_values = {ronin_id: 15}
	ctx.is_lord = true
	ctx.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	return ctx


# -- get_contract_payment --

func test_contract_payment_province_defense_1_season():
	assert_eq(RoninSystem.get_contract_payment("PROVINCE_DEFENSE", 1), 3.0)


func test_contract_payment_magistrate_aide_2_seasons():
	assert_eq(RoninSystem.get_contract_payment("MAGISTRATE_AIDE", 2), 4.0)


func test_contract_payment_military_service_3_seasons():
	assert_eq(RoninSystem.get_contract_payment("MILITARY_SERVICE", 3), 6.0)


func test_contract_payment_duration_clamped_at_3():
	# Duration > 3 clamps to 3.
	assert_eq(RoninSystem.get_contract_payment("PROVINCE_DEFENSE", 5), 9.0)


# -- executor_hire_ronin --

func test_executor_hire_ronin_no_ronin_present():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	var ctx := _make_ctx_for_hire(200, -1)
	ctx.characters_present = []
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "HIRE_RONIN"
	action.metadata = {"target_ronin_id": -1, "contract_type": "PROVINCE_DEFENSE", "duration_seasons": 1}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, {})
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_ronin_present")


func test_executor_hire_ronin_already_contracted():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_end_ic_day"] = 500  # already contracted
	var chars: Dictionary = {200: lord, 10: ronin}
	var ctx := _make_ctx_for_hire(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "HIRE_RONIN"
	action.metadata = {"target_ronin_id": 10, "contract_type": "PROVINCE_DEFENSE", "duration_seasons": 1}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "already_contracted")


func test_executor_hire_ronin_insufficient_koku():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 1.0  # PROVINCE_DEFENSE 2 seasons = 6 koku, not enough
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {200: lord, 10: ronin}
	var ctx := _make_ctx_for_hire(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "HIRE_RONIN"
	action.metadata = {"target_ronin_id": 10, "contract_type": "PROVINCE_DEFENSE", "duration_seasons": 2}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "insufficient_koku")


func test_executor_hire_ronin_success_injects_reactive_event():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.skills = {"Courtier": 6}
	lord.awareness = 5
	var ronin := _make_ronin_char(10)
	ronin.disposition_values = {200: 5}  # ronin doesn't dislike lord
	var chars: Dictionary = {200: lord, 10: ronin}
	var ctx := _make_ctx_for_hire(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "HIRE_RONIN"
	action.metadata = {"target_ronin_id": 10, "contract_type": "PROVINCE_DEFENSE", "duration_seasons": 1}
	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, DiceEngine.new(999), {}, {}, chars)
	assert_true(result.get("success", false))
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.get("injects_reactive_event", false))
	assert_eq(eff.get("reactive_type", ""), "CONTRACT_OFFERED")
	assert_eq(eff.get("contract_type", ""), "PROVINCE_DEFENSE")


# -- reactive: CONTRACT_OFFERED --

func test_reactive_contract_offered_desperate_auto_accepts():
	var ronin := _make_ronin_char(10)
	ronin.shourido_virtue = Enums.ShouridoVirtue.ISHI  # ISHI normally refuses
	ronin.supply_ledger["ronin_since_season"] = 0
	# 20 seasons without income >> SEASONS_BEFORE_DESPERATE (8) → desperate.
	var event: Dictionary = {
		"reactive_type": "CONTRACT_OFFERED",
		"lord_id": 200,
		"contract_type": "PROVINCE_DEFENSE",
		"duration_seasons": 1,
		"payment": 3.0,
		"season_start": 0,
		"current_season": 20,
	}
	var result: Dictionary = ReactiveDecisions._evaluate_contract_offer(event, ronin)
	# Desperate ISHI still accepts — desperation overrides self-reliance.
	assert_eq(result.get("action", ""), "ACCEPT_CONTRACT")


func test_reactive_contract_ishi_refuses_unless_desperate():
	var ronin := _make_ronin_char(10)
	ronin.shourido_virtue = Enums.ShouridoVirtue.ISHI
	ronin.disposition_values = {200: 5}  # slightly positive but not desperate
	var event: Dictionary = {
		"reactive_type": "CONTRACT_OFFERED",
		"lord_id": 200,
		"contract_type": "PROVINCE_DEFENSE",
		"duration_seasons": 1,
		"payment": 3.0,
		"season_start": 0,
		"current_season": 1,
	}
	var result: Dictionary = ReactiveDecisions._evaluate_contract_offer(event, ronin)
	assert_eq(result.get("action", ""), "DECLINE_CONTRACT")


func test_reactive_contract_chugi_accepts_province_defense():
	var ronin := _make_ronin_char(10)
	ronin.bushido_virtue = Enums.BushidoVirtue.CHUGI
	ronin.disposition_values = {200: 0}
	var event: Dictionary = {
		"reactive_type": "CONTRACT_OFFERED",
		"lord_id": 200,
		"contract_type": "PROVINCE_DEFENSE",
		"duration_seasons": 1,
		"payment": 3.0,
		"season_start": 0,
		"current_season": 1,
	}
	var result: Dictionary = ReactiveDecisions._evaluate_contract_offer(event, ronin)
	assert_eq(result.get("action", ""), "ACCEPT_CONTRACT")


func test_reactive_contract_high_disposition_accepts():
	var ronin := _make_ronin_char(10)
	ronin.disposition_values = {200: 35}  # >= 31, auto-accepts
	var event: Dictionary = {
		"reactive_type": "CONTRACT_OFFERED",
		"lord_id": 200,
		"contract_type": "MILITARY_SERVICE",
		"duration_seasons": 1,
		"payment": 2.0,
		"season_start": 0,
		"current_season": 1,
	}
	var result: Dictionary = ReactiveDecisions._evaluate_contract_offer(event, ronin)
	assert_eq(result.get("action", ""), "ACCEPT_CONTRACT")


# -- contract acceptance writeback --

func test_writeback_contract_acceptance_sets_contract_fields():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 20.0
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {200: lord, 10: ronin}
	var objectives_map: Dictionary = {}
	var results: Array = [{
		"action": "ACCEPT_CONTRACT",
		"character_id": 10,
		"target_npc_id": 200,
		"contract_type": "PROVINCE_DEFENSE",
		"duration_seasons": 1,
	}]
	DayOrchestrator._process_contract_acceptance_writebacks(
		results, chars, objectives_map, 1, 100,
	)
	assert_true(ronin.supply_ledger.get("contract_end_ic_day", -1) > 0)
	assert_eq(ronin.supply_ledger.get("contract_type", ""), "PROVINCE_DEFENSE")
	assert_eq(ronin.supply_ledger.get("contract_lord_family", ""), "Doji")


func test_writeback_contract_acceptance_deducts_lord_koku():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 20.0
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {200: lord, 10: ronin}
	var objectives_map: Dictionary = {}
	var results: Array = [{
		"action": "ACCEPT_CONTRACT",
		"character_id": 10,
		"target_npc_id": 200,
		"contract_type": "PROVINCE_DEFENSE",
		"duration_seasons": 1,
	}]
	DayOrchestrator._process_contract_acceptance_writebacks(
		results, chars, objectives_map, 1, 100,
	)
	# PROVINCE_DEFENSE 1 season = 3 koku deducted from lord, given to ronin.
	assert_eq(lord.koku, 17.0)
	assert_eq(ronin.koku, 3.0)


func test_writeback_contract_acceptance_assigns_objective():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 20.0
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {200: lord, 10: ronin}
	var objectives_map: Dictionary = {}
	var results: Array = [{
		"action": "ACCEPT_CONTRACT",
		"character_id": 10,
		"target_npc_id": 200,
		"contract_type": "MAGISTRATE_AIDE",
		"duration_seasons": 1,
	}]
	DayOrchestrator._process_contract_acceptance_writebacks(
		results, chars, objectives_map, 1, 100,
	)
	var primary: Dictionary = objectives_map.get(10, {}).get("primary", {})
	assert_eq(primary.get("need_type", ""), "UPHOLD_LAW")
	assert_eq(primary.get("source", ""), "contract")


func test_writeback_contract_decline_applies_disposition():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	var ronin := _make_ronin_char(10)
	ronin.disposition_values = {200: 5}
	lord.disposition_values = {10: 10}
	var chars: Dictionary = {200: lord, 10: ronin}
	var results: Array = [{
		"action": "DECLINE_CONTRACT",
		"character_id": 10,
		"target_npc_id": 200,
	}]
	DayOrchestrator._process_contract_acceptance_writebacks(
		results, chars, {}, 1, 100,
	)
	assert_eq(int(ronin.disposition_values.get(200, 0)), 4)
	assert_eq(int(lord.disposition_values.get(10, 0)), 9)


# -- contract expiry --

func test_contract_expiry_clean_increments_deed_count():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_end_ic_day"] = 100
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	ronin.supply_ledger["contract_lord_family"] = "Doji"
	var chars: Dictionary = {10: ronin}
	var objectives_map: Dictionary = {
		10: {"primary": {"need_type": "DEFEND_PROVINCE", "source": "contract", "assigned_by": 200}},
	}
	DayOrchestrator._process_contract_expiry(chars, objectives_map, 2, 100, [], {}, {})
	assert_eq(RoninSystem.get_deed_count(ronin, "Doji"), 1)


func test_contract_expiry_abandoned_applies_disposition_penalty():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.disposition_values = {10: 5}
	var ronin := _make_ronin_char(10)
	ronin.lord_id = 200
	ronin.supply_ledger["contract_end_ic_day"] = 100
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	ronin.supply_ledger["contract_lord_family"] = "Doji"
	var chars: Dictionary = {10: ronin, 200: lord}
	var objectives_map: Dictionary = {
		10: {"primary": {"need_type": "SEEK_GLORY", "source": "self", "assigned_by": -1}},
	}
	DayOrchestrator._process_contract_expiry(chars, objectives_map, 2, 100, [], {}, {})
	assert_eq(int(lord.disposition_values.get(10, 0)), 5 + RoninSystem.CONTRACT_ABANDONED_DISPOSITION)


func test_contract_expiry_clears_contract_objective():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_end_ic_day"] = 100
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	ronin.supply_ledger["contract_lord_family"] = "Doji"
	var chars: Dictionary = {10: ronin}
	var objectives_map: Dictionary = {
		10: {"primary": {"need_type": "DEFEND_PROVINCE", "source": "contract", "assigned_by": 200}},
	}
	DayOrchestrator._process_contract_expiry(chars, objectives_map, 2, 100, [], {}, {})
	assert_false(objectives_map.get(10, {}).has("primary"))


func test_contract_expiry_extraordinary_deed_when_all_conditions_met():
	# All three extraordinary deed conditions: at war, crisis, 3+ seasons.
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.clan = "Crane"
	var ronin := _make_ronin_char(10)
	ronin.lord_id = 200
	ronin.supply_ledger["contract_end_ic_day"] = 100
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	ronin.supply_ledger["contract_lord_family"] = "Doji"
	ronin.supply_ledger["contract_duration_seasons"] = 3
	var chars: Dictionary = {10: ronin, 200: lord}
	var objectives_map: Dictionary = {
		10: {"primary": {"need_type": "DEFEND_PROVINCE", "source": "contract", "assigned_by": 200}},
	}
	var war := WarData.new()
	war.is_active = true
	war.clan_a = "Crane"
	war.clan_b = "Lion"
	var prov := ProvinceData.new()
	prov.province_id = 5
	prov.active_crisis_id = 1  # active crisis
	var provinces: Dictionary = {5: prov}
	var char_province_map: Dictionary = {200: 5}
	DayOrchestrator._process_contract_expiry(
		chars, objectives_map, 2, 100, [war], provinces, char_province_map,
	)
	assert_eq(RoninSystem.get_extraordinary_deed_count(ronin, "Doji"), 1)


func test_contract_expiry_no_extraordinary_deed_when_no_war():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.clan = "Crane"
	var ronin := _make_ronin_char(10)
	ronin.lord_id = 200
	ronin.supply_ledger["contract_end_ic_day"] = 100
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	ronin.supply_ledger["contract_lord_family"] = "Doji"
	ronin.supply_ledger["contract_duration_seasons"] = 3
	var chars: Dictionary = {10: ronin, 200: lord}
	var objectives_map: Dictionary = {
		10: {"primary": {"need_type": "DEFEND_PROVINCE", "source": "contract", "assigned_by": 200}},
	}
	var prov := ProvinceData.new()
	prov.province_id = 5
	prov.active_crisis_id = 1
	var provinces: Dictionary = {5: prov}
	var char_province_map: Dictionary = {200: 5}
	# No active wars → not extraordinary
	DayOrchestrator._process_contract_expiry(
		chars, objectives_map, 2, 100, [], provinces, char_province_map,
	)
	assert_eq(RoninSystem.get_extraordinary_deed_count(ronin, "Doji"), 0)
	assert_eq(RoninSystem.get_deed_count(ronin, "Doji"), 1)  # still gets normal deed


# -- APPROVE_CLAN_INDUCTION --

func test_approve_induction_sets_approval_flag():
	var ronin := _make_ronin_char(10)
	RoninSystem.approve_induction(ronin, 200)
	assert_eq(int(ronin.supply_ledger.get("family_daimyo_approval", -1)), 200)


func test_approve_induction_overwrites_previous():
	var ronin := _make_ronin_char(10)
	RoninSystem.approve_induction(ronin, 200)
	RoninSystem.approve_induction(ronin, 300)
	assert_eq(int(ronin.supply_ledger.get("family_daimyo_approval", -1)), 300)


func test_writeback_approve_induction_sets_flag():
	var fd := _make_lord_with_family(200, "Crane", "Doji")
	fd.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	var chars: Dictionary = {200: fd, 10: ronin}
	var results: Array = [{
		"action_id": "APPROVE_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"effects": {
			"approve_ronin_id": 10,
			"family_daimyo_id": 200,
		},
	}]
	DayOrchestrator._process_approve_induction_writebacks(results, chars)
	assert_eq(int(ronin.supply_ledger.get("family_daimyo_approval", -1)), 200)


func test_writeback_approve_induction_skips_dead_ronin():
	var fd := _make_lord_with_family(200, "Crane", "Doji")
	var ronin := _make_ronin_char(10)
	ronin.wounds_taken = 999  # dead
	var chars: Dictionary = {200: fd, 10: ronin}
	var results: Array = [{
		"action_id": "APPROVE_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"effects": {"approve_ronin_id": 10, "family_daimyo_id": 200},
	}]
	DayOrchestrator._process_approve_induction_writebacks(results, chars)
	assert_eq(int(ronin.supply_ledger.get("family_daimyo_approval", -1)), -1)


func test_executor_approve_induction_rank_gate():
	var pd := _make_lord_with_family(200, "Crane", "Doji")
	pd.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO  # too low — needs FAMILY_DAIMYO
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	var chars: Dictionary = {200: pd, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "APPROVE_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, pd, ctx, DiceEngine.new(1), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "approver_rank_too_low")


func test_executor_approve_induction_insufficient_deeds():
	var fd := _make_lord_with_family(200, "Crane", "Doji")
	fd.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 5}  # below 8
	var chars: Dictionary = {200: fd, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "APPROVE_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, fd, ctx, DiceEngine.new(1), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "insufficient_deeds")


func test_executor_approve_induction_no_extraordinary_deed():
	var fd := _make_lord_with_family(200, "Crane", "Doji")
	fd.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	# No extraordinary_deeds_for_family set
	var chars: Dictionary = {200: fd, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "APPROVE_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, fd, ctx, DiceEngine.new(1), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_extraordinary_deed")


func test_executor_approve_induction_success():
	var fd := _make_lord_with_family(200, "Crane", "Doji")
	fd.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	var chars: Dictionary = {200: fd, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "APPROVE_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, fd, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_true(result.get("success", false))
	assert_eq(result.get("effects", {}).get("approve_ronin_id", -1), 10)
	assert_eq(result.get("effects", {}).get("family_daimyo_id", -1), 200)


# =============================================================================
# s52.7 CLAN INDUCTION SYSTEM
# =============================================================================


# -- can_be_inducted --

func _make_inducted_ronin(id: int = 10) -> L5RCharacterData:
	var ronin := _make_ronin_char(id)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	ronin.supply_ledger["family_daimyo_approval"] = 200
	return ronin


func test_can_be_inducted_all_gates_pass():
	var ronin := _make_inducted_ronin(10)
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, [])
	assert_true(result.get("eligible", false))


func test_can_be_inducted_permanent_ronin_blocked():
	var ronin := _make_inducted_ronin(10)
	ronin.permanent_ronin = true
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 60, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "permanent_ronin")


func test_can_be_inducted_sponsor_rank_too_low():
	var ronin := _make_inducted_ronin(10)
	var local_lord := _make_lord_with_family(201, "Crane", "Doji")
	local_lord.lord_rank = Enums.LordRank.LOCAL_DAIMYO  # too low
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, local_lord, 55, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "sponsoring_lord_rank_too_low")


func test_can_be_inducted_low_disposition_blocked():
	var ronin := _make_inducted_ronin(10)
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 30, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "disposition_too_low")


func test_can_be_inducted_insufficient_deeds_blocked():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 5}  # below 8
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	ronin.supply_ledger["family_daimyo_approval"] = 200
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "insufficient_deeds")


func test_can_be_inducted_no_extraordinary_deed_blocked():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	# No extraordinary deed
	ronin.supply_ledger["family_daimyo_approval"] = 200
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "no_extraordinary_deed")


func test_can_be_inducted_no_fd_approval_blocked():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 8}
	ronin.supply_ledger["extraordinary_deeds_for_family"] = {"Doji": 1}
	# No family_daimyo_approval
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "no_family_daimyo_approval")


func test_can_be_inducted_same_clan_blocked():
	var ronin := _make_inducted_ronin(10)
	ronin.clan = "Crane"  # same as sponsor
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, [])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "already_same_clan")


func test_can_be_inducted_serious_crime_blocked():
	var ronin := _make_inducted_ronin(10)
	var sponsor := _make_lord_with_family(201, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var known_crimes: Array = [Enums.CrimeType.TREASON]
	var result: Dictionary = RoninSystem.can_be_inducted(ronin, sponsor, 55, known_crimes)
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "known_serious_crime")


# -- perform_induction --

func test_perform_induction_changes_clan():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 3}
	var daimyo := _make_lord_with_family(200, "Crane", "Doji")
	RoninSystem.perform_induction(ronin, daimyo)
	assert_eq(ronin.clan, "Crane")
	assert_eq(ronin.family, "Doji")


func test_perform_induction_sets_lord_id():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 3}
	var daimyo := _make_lord_with_family(200, "Crane", "Doji")
	RoninSystem.perform_induction(ronin, daimyo)
	assert_eq(ronin.lord_id, 200)


func test_perform_induction_clears_permanent_ronin():
	var ronin := _make_ronin_char(10)
	ronin.permanent_ronin = true  # perform_induction bypasses this check
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 3}
	var daimyo := _make_lord_with_family(200, "Crane", "Doji")
	RoninSystem.perform_induction(ronin, daimyo)
	assert_false(ronin.permanent_ronin)


func test_perform_induction_clears_deed_credits():
	var ronin := _make_ronin_char(10)
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 4, "Akodo": 2}
	var daimyo := _make_lord_with_family(200, "Crane", "Doji")
	RoninSystem.perform_induction(ronin, daimyo)
	assert_eq(RoninSystem.get_deed_count(ronin, "Doji"), 0)
	# Other family deeds preserved.
	assert_eq(RoninSystem.get_deed_count(ronin, "Akodo"), 2)


func test_perform_induction_glory_gains():
	var ronin := _make_ronin_char(10)
	ronin.glory = 2.0
	ronin.supply_ledger["contract_deeds_for_family"] = {"Doji": 3}
	var daimyo := _make_lord_with_family(200, "Crane", "Doji")
	daimyo.glory = 4.0
	RoninSystem.perform_induction(ronin, daimyo)
	assert_almost_eq(ronin.glory, 2.0 + RoninSystem.INDUCTION_INDUCTEE_GLORY_GAIN, 0.001)
	assert_almost_eq(daimyo.glory, 4.0 + RoninSystem.INDUCTION_DAIMYO_GLORY_GAIN, 0.001)


# -- executor: PERFORM_CLAN_INDUCTION --

func _make_ctx_for_induction(sponsor_id: int, ronin_id: int) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = sponsor_id
	ctx.ic_day = 100
	ctx.season = 1
	ctx.location_id = "1"
	ctx.characters_present = [ronin_id]
	ctx.is_lord = true
	ctx.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	return ctx


func test_executor_induction_sponsoring_lord_rank_too_low():
	var local_lord := _make_lord_with_family(200, "Crane", "Doji")
	local_lord.lord_rank = Enums.LordRank.LOCAL_DAIMYO
	local_lord.koku = 20.0
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: local_lord, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERFORM_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, local_lord, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "sponsoring_lord_rank_too_low")
	assert_eq(local_lord.koku, 20.0)  # koku not deducted — gated before koku check


func test_executor_induction_ceremony_failure_returns_failure_topic():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	sponsor.skills = {"Courtier": 1}
	sponsor.awareness = 1
	sponsor.koku = 20.0
	sponsor.disposition_values = {10: 60}
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERFORM_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	# Seed 1 produces low rolls (TN 20 unlikely with Courtier 1).
	var result: Dictionary = ActionExecutor.execute(action, sponsor, ctx, DiceEngine.new(1), {}, {}, chars)
	# Koku always deducted (Pattern B).
	assert_eq(sponsor.koku, 10.0)
	if not result.get("success", false):
		assert_true(result.get("effects", {}).get("ceremony_failure_topic", false))


func test_executor_induction_insufficient_koku_blocked():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	sponsor.koku = 5.0  # less than 10 required
	sponsor.disposition_values = {10: 60}
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var ctx := _make_ctx_for_induction(200, 10)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERFORM_CLAN_INDUCTION"
	action.metadata = {"target_ronin_id": 10}
	var result: Dictionary = ActionExecutor.execute(action, sponsor, ctx, DiceEngine.new(42), {}, {}, chars)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "insufficient_koku")


# -- induction writeback --

func test_writeback_induction_success_changes_clan():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var objectives_map: Dictionary = {}
	var active_topics: Array = []
	var next_id: Array[int] = [1]
	var results: Array = [{
		"action_id": "PERFORM_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {"inductee_id": 10, "daimyo_id": 200},
	}]
	DayOrchestrator._process_clan_induction_writebacks(
		results, chars, objectives_map, active_topics, next_id, 100,
	)
	assert_eq(ronin.clan, "Crane")
	assert_eq(ronin.family, "Doji")


func test_writeback_induction_creates_tier3_political_topic():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var active_topics: Array = []
	var next_id: Array[int] = [1]
	var results: Array = [{
		"action_id": "PERFORM_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {"inductee_id": 10, "daimyo_id": 200},
	}]
	DayOrchestrator._process_clan_induction_writebacks(
		results, chars, {}, active_topics, next_id, 100,
	)
	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_eq(topic.category, TopicData.Category.POLITICAL)


func test_writeback_induction_applies_family_disposition():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var family_member := _make_lord_with_family(201, "Crane", "Doji")
	family_member.physical_location = sponsor.physical_location
	family_member.disposition_values = {10: 0}
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 201: family_member, 10: ronin}
	var active_topics: Array = []
	var next_id: Array[int] = [1]
	var results: Array = [{
		"action_id": "PERFORM_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {"inductee_id": 10, "daimyo_id": 200},
	}]
	DayOrchestrator._process_clan_induction_writebacks(
		results, chars, {}, active_topics, next_id, 100,
	)
	assert_eq(int(family_member.disposition_values.get(10, 0)),
		RoninSystem.INDUCTION_FAMILY_BASELINE_SHIFT)


func test_writeback_induction_ceremony_failure_creates_tier4_topic():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	var ronin := _make_ronin_char(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var active_topics: Array = []
	var next_id: Array[int] = [5]
	var results: Array = [{
		"action_id": "PERFORM_CLAN_INDUCTION",
		"success": false,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {"ceremony_failure_topic": true},
	}]
	DayOrchestrator._process_clan_induction_writebacks(
		results, chars, {}, active_topics, next_id, 100,
	)
	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.tier, TopicData.Tier.TIER_4)


func test_writeback_induction_clears_fd_approval_flag():
	var sponsor := _make_lord_with_family(200, "Crane", "Doji")
	sponsor.lord_rank = Enums.LordRank.PROVINCIAL_DAIMYO
	var ronin := _make_inducted_ronin(10)
	var chars: Dictionary = {200: sponsor, 10: ronin}
	var results: Array = [{
		"action_id": "PERFORM_CLAN_INDUCTION",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {"inductee_id": 10, "daimyo_id": 200},
	}]
	DayOrchestrator._process_clan_induction_writebacks(
		results, chars, {}, [], [1], 100,
	)
	assert_eq(int(ronin.supply_ledger.get("family_daimyo_approval", -1)), -1)


# -- TERMINATE_CONTRACT writeback --

func test_terminate_contract_refunds_half_koku():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 0.0
	var ronin := _make_ronin_char(10)
	ronin.lord_id = 200
	ronin.supply_ledger["contract_end_ic_day"] = 280  # 180 days remaining ≈ 2 seasons
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	var chars: Dictionary = {200: lord, 10: ronin}
	var results: Array = [{
		"action_id": "TERMINATE_CONTRACT",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {
			"terminate_ronin_id": 10,
			"contract_type": "PROVINCE_DEFENSE",
			"remaining_seasons": 2,
			"disposition_change": RoninSystem.CONTRACT_EARLY_TERMINATION_DISPOSITION,
		},
	}]
	DayOrchestrator._process_terminate_contract_writebacks(results, chars, 2)
	# PROVINCE_DEFENSE 2 seasons = 6 koku, half refund = 3 koku.
	assert_eq(lord.koku, 3.0)


func test_terminate_contract_applies_disposition_penalty():
	var lord := _make_lord_with_family(200, "Crane", "Doji")
	lord.koku = 0.0
	lord.disposition_values = {10: 20}
	var ronin := _make_ronin_char(10)
	ronin.lord_id = 200
	ronin.supply_ledger["contract_end_ic_day"] = 280
	ronin.supply_ledger["contract_type"] = "PROVINCE_DEFENSE"
	var chars: Dictionary = {200: lord, 10: ronin}
	var results: Array = [{
		"action_id": "TERMINATE_CONTRACT",
		"success": true,
		"character_id": 200,
		"target_npc_id": 10,
		"effects": {
			"terminate_ronin_id": 10,
			"contract_type": "PROVINCE_DEFENSE",
			"remaining_seasons": 2,
			"disposition_change": RoninSystem.CONTRACT_EARLY_TERMINATION_DISPOSITION,
		},
	}]
	DayOrchestrator._process_terminate_contract_writebacks(results, chars, 2)
	assert_eq(int(lord.disposition_values.get(10, 0)),
		20 + RoninSystem.CONTRACT_EARLY_TERMINATION_DISPOSITION)
