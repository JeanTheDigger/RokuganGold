extends GutTest
## Tests for RoninSystem (s52 Part 5).


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
	c.glory = 2.0
	c.stamina = 3
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 3
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 3
	c.void_ring = 2
	c.skills = {"Kenjutsu": 3, "Battle": 2, "Etiquette": 2}
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

func test_make_ronin_honor_loss_involuntary():
	var c := _make_samurai()
	c.honor = 5.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	assert_almost_eq(c.honor, 4.5, 0.01)

func test_make_ronin_honor_loss_voluntary():
	var c := _make_samurai()
	c.honor = 5.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	assert_almost_eq(c.honor, 4.0, 0.01)

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

func test_accept_into_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_eq(c.lord_id, 200)
	assert_eq(c.role_position, "Retainer")
	assert_eq(c.clan, "Crane")
	assert_true(c.status >= 1.0)

func test_accept_restores_honor():
	var c := _make_samurai()
	c.honor = 3.0
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	var honor_before: float = c.honor
	RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_almost_eq(c.honor, honor_before + 0.1, 0.01)

func test_no_longer_ronin_after_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.LORD_DEATH_NO_HEIR)
	RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_false(RoninSystem.is_ronin(c))


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

func test_can_seed_insurgency_bushi():
	var c := _make_samurai()
	c.bushido_virtue = Enums.BushidoVirtue.YU
	RoninSystem.mark_ronin_start(c, 0)
	assert_true(RoninSystem.can_seed_insurgency(c, 10))

func test_cannot_seed_insurgency_courtier():
	var c := _make_samurai()
	c.school_type = Enums.SchoolType.COURTIER
	RoninSystem.mark_ronin_start(c, 0)
	assert_false(RoninSystem.can_seed_insurgency(c, 10))

func test_cannot_seed_insurgency_gi_virtue():
	var c := _make_samurai()
	c.bushido_virtue = Enums.BushidoVirtue.GI
	RoninSystem.mark_ronin_start(c, 0)
	assert_false(RoninSystem.can_seed_insurgency(c, 10))

func test_cannot_seed_insurgency_meiyo_virtue():
	var c := _make_samurai()
	c.bushido_virtue = Enums.BushidoVirtue.MEIYO
	RoninSystem.mark_ronin_start(c, 0)
	assert_false(RoninSystem.can_seed_insurgency(c, 10))

func test_cannot_seed_insurgency_not_desperate():
	var c := _make_samurai()
	RoninSystem.mark_ronin_start(c, 10)
	assert_false(RoninSystem.can_seed_insurgency(c, 14))

func test_ninja_can_seed_insurgency():
	var c := _make_samurai()
	c.school_type = Enums.SchoolType.NINJA
	c.bushido_virtue = Enums.BushidoVirtue.YU
	RoninSystem.mark_ronin_start(c, 0)
	assert_true(RoninSystem.can_seed_insurgency(c, 10))


# === PETITION ===

func test_petition_success():
	var c := _make_samurai()
	c.awareness = 4
	c.skills["Etiquette"] = 3
	var lord := _make_lord()
	lord.disposition_values[c.character_id] = 10
	var dice := DiceEngine.new(42)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice)
	assert_true(result.has("success"))
	assert_eq(result["tn"], 20)

func test_petition_harder_with_negative_disposition():
	var c := _make_samurai()
	var lord := _make_lord()
	lord.disposition_values[c.character_id] = -15
	var dice := DiceEngine.new(42)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice)
	assert_eq(result["tn"], 30)


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
	c.bushido_virtue = Enums.BushidoVirtue.YU
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 18)
	assert_true(result["insurgency_seeds"].has(c.character_id))

func test_process_seasonal_no_insurgency_seed_gi():
	var c := _make_samurai()
	c.bushido_virtue = Enums.BushidoVirtue.GI
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	RoninSystem.mark_ronin_start(c, 10)
	var result: Dictionary = RoninSystem.process_seasonal_ronin([c], 18)
	assert_eq(result["insurgency_seeds"].size(), 0)

func test_process_seasonal_multiple_characters():
	var c1 := _make_samurai(1)
	var c2 := _make_samurai(2)
	c2.character_id = 2
	c1.status = 0.5
	c2.status = 0.5
	c1.bushido_virtue = Enums.BushidoVirtue.YU
	c2.bushido_virtue = Enums.BushidoVirtue.CHUGI
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
	assert_eq(RoninSystem.RoninCause.CLAN_DESTROYED, 2)
	assert_eq(RoninSystem.RoninCause.VOLUNTARY_DEPARTURE, 3)


# === PERMANENT RONIN GATES ===

func test_permanent_ronin_rejects_accept_into_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	c.permanent_ronin = true
	var result: Dictionary = RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_true(result.get("rejected", false))
	assert_eq(c.lord_id, -1)

func test_permanent_ronin_rejects_petition():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
	c.permanent_ronin = true
	var lord := _make_lord()
	var dice := DiceEngine.new(42)
	var result: Dictionary = RoninSystem.resolve_petition(c, lord, dice)
	assert_false(result["success"])
	assert_true(result.get("rejected", false))

func test_non_permanent_ronin_accepts_service():
	var c := _make_samurai()
	RoninSystem.make_ronin(c, RoninSystem.RoninCause.DISMISSAL)
	assert_false(c.permanent_ronin)
	var result: Dictionary = RoninSystem.accept_into_service(c, 200, "Retainer", "Crane")
	assert_false(result.get("rejected", false))
	assert_eq(c.lord_id, 200)
