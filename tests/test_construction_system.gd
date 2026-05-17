extends GutTest

# -- Helpers -------------------------------------------------------------------

func _make_char(id: int, status: float = 3.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crane"
	c.family = "Doji"
	c.status = status
	c.lord_id = -1
	return c


func _make_province(id: int, terrain: Enums.TerrainType = Enums.TerrainType.PLAINS) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.province_name = "Test Province %d" % id
	p.terrain_type = terrain
	p.stability = 80.0
	p.clan = "Crane"
	p.family = "Doji"
	return p


func _make_settlement(
	id: int, province_id: int,
	stype: Enums.SettlementType = Enums.SettlementType.VILLAGE,
	pop: int = 5, rice: float = 10.0, koku: float = 20.0,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = stype
	s.population_pu = pop
	s.farming_pu = pop
	s.rice_stockpile = rice
	s.koku_stockpile = koku
	return s


# -- Validation: Village -------------------------------------------------------

func test_validate_village_success() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var result: Dictionary = ConstructionSystem.validate_village_founding(c, p, [s] as Array[SettlementData])
	assert_true(result.get("valid", false))


func test_validate_village_insufficient_koku() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 1.0)
	var result: Dictionary = ConstructionSystem.validate_village_founding(c, p, [s] as Array[SettlementData])
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_koku")


func test_validate_village_insufficient_pu() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 0, 10.0, 20.0)
	var result: Dictionary = ConstructionSystem.validate_village_founding(c, p, [s] as Array[SettlementData])
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_pu")


func test_validate_village_tainted_terrain() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	p.province_taint_level = 5.0
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var result: Dictionary = ConstructionSystem.validate_village_founding(c, p, [s] as Array[SettlementData])
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "tainted_terrain")


# -- Validation: Fortification -------------------------------------------------

func test_validate_fortification_success() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var result: Dictionary = ConstructionSystem.validate_fortification(c, p, [s] as Array[SettlementData])
	assert_true(result.get("valid", false))


func test_validate_fortification_insufficient_koku() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 2.0)
	var result: Dictionary = ConstructionSystem.validate_fortification(c, p, [s] as Array[SettlementData])
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_koku")


# -- Validation: Shrine --------------------------------------------------------

func test_validate_shrine_roadside_general() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 10.0)
	var result: Dictionary = ConstructionSystem.validate_shrine(
		ConstructionData.ConstructionType.SHRINE_ROADSIDE, c, s, false,
	)
	assert_true(result.get("valid", false))


func test_validate_shrine_roadside_dedicated() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 15.0)
	var result: Dictionary = ConstructionSystem.validate_shrine(
		ConstructionData.ConstructionType.SHRINE_ROADSIDE, c, s, true,
	)
	assert_true(result.get("valid", false))


func test_validate_shrine_roadside_dedicated_insufficient() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 10.0)
	var result: Dictionary = ConstructionSystem.validate_shrine(
		ConstructionData.ConstructionType.SHRINE_ROADSIDE, c, s, true,
	)
	assert_false(result.get("valid", false))


func test_validate_shrine_local_cost() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 35.0)
	var result: Dictionary = ConstructionSystem.validate_shrine(
		ConstructionData.ConstructionType.SHRINE_LOCAL, c, s, false,
	)
	assert_true(result.get("valid", false))


# -- Validation: Temple / Shinden / Monastery ----------------------------------

func test_validate_temple_success() -> void:
	var c := _make_char(1, 5.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 100.0)
	var result: Dictionary = ConstructionSystem.validate_temple(
		ConstructionData.ConstructionType.TEMPLE, c, p, [s] as Array[SettlementData], false,
	)
	assert_true(result.get("valid", false))


func test_validate_temple_insufficient_authority() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 100.0)
	var result: Dictionary = ConstructionSystem.validate_temple(
		ConstructionData.ConstructionType.TEMPLE, c, p, [s] as Array[SettlementData], false,
	)
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_authority")


func test_validate_shinden_cost() -> void:
	var c := _make_char(1, 5.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 300.0)
	var result: Dictionary = ConstructionSystem.validate_temple(
		ConstructionData.ConstructionType.SHINDEN, c, p, [s] as Array[SettlementData], false,
	)
	assert_true(result.get("valid", false))


func test_validate_shinden_insufficient_koku() -> void:
	var c := _make_char(1, 5.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 100.0)
	var result: Dictionary = ConstructionSystem.validate_temple(
		ConstructionData.ConstructionType.SHINDEN, c, p, [s] as Array[SettlementData], false,
	)
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_koku")


func test_validate_monastery_success() -> void:
	var c := _make_char(1, 5.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 100.0)
	var result: Dictionary = ConstructionSystem.validate_temple(
		ConstructionData.ConstructionType.MONASTERY, c, p, [s] as Array[SettlementData], false,
	)
	assert_true(result.get("valid", false))


# -- Validation: Ship Commission -----------------------------------------------

func test_validate_ship_kobune() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 10.0)
	s.infrastructure = ["shipyard"]
	var result: Dictionary = ConstructionSystem.validate_ship_commission(
		c, Enums.ShipClass.KOBUNE, s,
	)
	assert_true(result.get("valid", false))


func test_validate_ship_no_shipyard() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 10.0)
	var result: Dictionary = ConstructionSystem.validate_ship_commission(
		c, Enums.ShipClass.KOBUNE, s,
	)
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "no_shipyard")


func test_validate_ship_insufficient_koku() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 1.0)
	s.infrastructure = ["shipyard"]
	var result: Dictionary = ConstructionSystem.validate_ship_commission(
		c, Enums.ShipClass.KOBUNE, s,
	)
	assert_false(result.get("valid", false))
	assert_eq(result.get("reason", ""), "insufficient_koku")


# -- Factory Tests -------------------------------------------------------------

func test_create_village_sets_type() -> void:
	var p := _make_province(1)
	var v: SettlementData = ConstructionSystem.create_founded_village(100, p, "Hamlet", 2.0, 2.0)
	assert_eq(v.settlement_type, Enums.SettlementType.VILLAGE)
	assert_eq(v.population_pu, 2)
	assert_eq(v.farming_pu, 2)
	assert_eq(v.rice_stockpile, 2.0)


func test_create_fortification_no_population() -> void:
	var p := _make_province(1)
	var f: SettlementData = ConstructionSystem.create_fortification(100, p, "Fort")
	assert_eq(f.settlement_type, Enums.SettlementType.FORTIFICATION)
	assert_eq(f.population_pu, 0)
	assert_eq(f.rice_stockpile, ConstructionSystem.FORTIFICATION_MAX_RICE)


func test_create_temple_with_worship_location() -> void:
	var p := _make_province(1)
	var t: SettlementData = ConstructionSystem.create_temple(100, p, "Temple", 1.0, true, 3)
	assert_eq(t.settlement_type, Enums.SettlementType.TEMPLE)
	assert_eq(t.worship_locations.size(), 1)
	assert_true(t.worship_locations[0].get("dedicated", false))
	assert_eq(t.worship_locations[0].get("fortune", -1), 3)


func test_create_monastery_type() -> void:
	var p := _make_province(1)
	var m: SettlementData = ConstructionSystem.create_monastery(100, p, "Brotherhood Monastery", 1.0)
	assert_eq(m.settlement_type, Enums.SettlementType.MONASTERY)
	assert_eq(m.population_pu, 1)


func test_create_shinden_worship_location() -> void:
	var p := _make_province(1)
	var s: SettlementData = ConstructionSystem.create_shinden(100, p, "Great Shinden", 2.0, false, -1)
	assert_eq(s.settlement_type, Enums.SettlementType.SHINDEN)
	assert_false(s.worship_locations[0].get("dedicated", true))


func test_fortification_is_military() -> void:
	var p := _make_province(1)
	var f: SettlementData = ConstructionSystem.create_fortification(100, p, "Fort")
	assert_true(f.is_military())


# -- Construction Queue --------------------------------------------------------

func test_create_construction_sets_fields() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.TEMPLE, 10, 5, 100,
		80.0, 0.5,
	)
	assert_eq(cd.construction_id, 1)
	assert_eq(cd.construction_type, ConstructionData.ConstructionType.TEMPLE)
	assert_eq(cd.seasons_remaining, ConstructionSystem.TEMPLE_BUILD_SEASONS)
	assert_eq(cd.seasons_total, ConstructionSystem.TEMPLE_BUILD_SEASONS)
	assert_false(cd.is_complete)


func test_tick_decrements_seasons() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_LOCAL, 10, 5, 100,
	)
	assert_eq(cd.seasons_remaining, 3)
	ConstructionSystem.tick_construction_queue([cd] as Array[ConstructionData])
	assert_eq(cd.seasons_remaining, 2)
	assert_false(cd.is_complete)


func test_tick_completes_when_zero() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_ROADSIDE, 10, 5, 100,
	)
	assert_eq(cd.seasons_remaining, 1)
	var completed: Array[ConstructionData] = ConstructionSystem.tick_construction_queue(
		[cd] as Array[ConstructionData],
	)
	assert_eq(completed.size(), 1)
	assert_true(cd.is_complete)


func test_tick_multiple_entries() -> void:
	var cd1: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_ROADSIDE, 10, 5, 100,
	)
	var cd2: ConstructionData = ConstructionSystem.create_construction(
		2, ConstructionData.ConstructionType.TEMPLE, 10, 5, 100,
	)
	var completed: Array[ConstructionData] = ConstructionSystem.tick_construction_queue(
		[cd1, cd2] as Array[ConstructionData],
	)
	assert_eq(completed.size(), 1)
	assert_true(cd1.is_complete)
	assert_false(cd2.is_complete)
	assert_eq(cd2.seasons_remaining, ConstructionSystem.TEMPLE_BUILD_SEASONS - 1)


func test_tick_skips_already_complete() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_ROADSIDE, 10, 5, 100,
	)
	cd.is_complete = true
	var completed: Array[ConstructionData] = ConstructionSystem.tick_construction_queue(
		[cd] as Array[ConstructionData],
	)
	assert_eq(completed.size(), 0)


# -- Shrine Addition -----------------------------------------------------------

func test_add_shrine_to_settlement() -> void:
	var s := _make_settlement(10, 1)
	assert_eq(s.worship_locations.size(), 0)
	ConstructionSystem.add_shrine_to_settlement(s, "village_shrine", true, 2)
	assert_eq(s.worship_locations.size(), 1)
	assert_eq(s.worship_locations[0].get("type", ""), "village_shrine")
	assert_true(s.worship_locations[0].get("dedicated", false))
	assert_eq(s.worship_locations[0].get("fortune", -1), 2)


# -- Resource Deduction --------------------------------------------------------

func test_deduct_village_resources() -> void:
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var result: Dictionary = ConstructionSystem.deduct_village_resources(
		[s] as Array[SettlementData], 1, 1.0, 3.0,
	)
	assert_eq(result["pu_moved"], 1.0)
	assert_eq(result["rice_moved"], 1.0)
	assert_eq(result["koku_deducted"], 3.0)
	assert_eq(s.population_pu, 4)
	assert_eq(s.koku_stockpile, 17.0)
	assert_eq(s.rice_stockpile, 9.0)


func test_deduct_koku_from_province() -> void:
	var s1 := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 3.0)
	var s2 := _make_settlement(11, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 4.0)
	var deducted: float = ConstructionSystem.deduct_koku(
		[s1, s2] as Array[SettlementData], 1, 5.0,
	)
	assert_eq(deducted, 5.0)
	assert_eq(s1.koku_stockpile, 0.0)
	assert_eq(s2.koku_stockpile, 2.0)


# -- Organic Village Formation -------------------------------------------------

func test_organic_check_eligible() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_true(result.get("eligible", false))


func test_organic_check_low_stability() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	p.stability = 30.0
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "low_stability")


func test_organic_check_insufficient_surplus() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 2, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "insufficient_surplus")


func test_organic_check_starving_blocks() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 0.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "settlements_starving")


func test_organic_check_tainted_blocks() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	p.province_taint_level = 5.0
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_false(result.get("eligible", false))
	assert_eq(result.get("reason", ""), "tainted")


func test_organic_mountains_higher_threshold() -> void:
	var p := _make_province(1, Enums.TerrainType.MOUNTAINS)
	# Mountains threshold = 10.0 PU. 8 PU is below threshold.
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 8, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.check_organic_formation(p, [s] as Array[SettlementData])
	assert_false(result.get("eligible", false))


func test_organic_formation_creates_village() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var result: Dictionary = ConstructionSystem.process_organic_formation(
		p, [s] as Array[SettlementData], 200,
	)
	assert_true(result.get("formed", false))
	var village: SettlementData = result.get("settlement")
	assert_not_null(village)
	assert_eq(village.settlement_type, Enums.SettlementType.VILLAGE)
	assert_eq(village.settlement_id, 200)
	# Source should lose PU
	assert_eq(s.population_pu, 9)


# -- Authority Checks ----------------------------------------------------------

func test_authority_provincial_daimyo() -> void:
	var c := _make_char(1, 3.0)
	assert_eq(ConstructionSystem.get_authority_level(c), ConstructionSystem.AuthorityLevel.PROVINCIAL_DAIMYO)


func test_authority_family_daimyo() -> void:
	var c := _make_char(1, 5.0)
	assert_eq(ConstructionSystem.get_authority_level(c), ConstructionSystem.AuthorityLevel.FAMILY_DAIMYO)


func test_authority_clan_champion() -> void:
	var c := _make_char(1, 7.0)
	assert_eq(ConstructionSystem.get_authority_level(c), ConstructionSystem.AuthorityLevel.CLAN_CHAMPION)


func test_village_authority_any_daimyo() -> void:
	var c := _make_char(1, 3.0)
	assert_true(ConstructionSystem.has_authority(ConstructionData.ConstructionType.VILLAGE, c))


func test_temple_requires_family_daimyo() -> void:
	var c_low := _make_char(1, 3.0)
	var c_high := _make_char(2, 5.0)
	assert_false(ConstructionSystem.has_authority(ConstructionData.ConstructionType.TEMPLE, c_low))
	assert_true(ConstructionSystem.has_authority(ConstructionData.ConstructionType.TEMPLE, c_high))


# -- Build Season Constants ----------------------------------------------------

func test_build_season_temple() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.TEMPLE, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 4)


func test_build_season_shinden() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHINDEN, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 8)


func test_build_season_monastery() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.MONASTERY, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 4)


func test_build_season_ship() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHIP, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 1)


func test_build_season_shrine_village() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_VILLAGE, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 2)


func test_build_season_shrine_local() -> void:
	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_LOCAL, 10, 5, 100,
	)
	assert_eq(cd.seasons_total, 3)


# -- Cost Constants ------------------------------------------------------------

func test_village_koku_cost() -> void:
	assert_eq(ConstructionSystem.VILLAGE_KOKU_COST, 3.0)


func test_fortification_koku_cost() -> void:
	assert_eq(ConstructionSystem.FORTIFICATION_KOKU_COST, 5.0)


func test_temple_koku_cost() -> void:
	assert_eq(ConstructionSystem.TEMPLE_KOKU_COST, 80.0)


func test_shinden_koku_cost() -> void:
	assert_eq(ConstructionSystem.SHINDEN_KOKU_COST, 250.0)


func test_ship_kobune_cost() -> void:
	assert_eq(ConstructionSystem.SHIP_COSTS[Enums.ShipClass.KOBUNE], 3.0)


func test_ship_sengokobune_cost() -> void:
	assert_eq(ConstructionSystem.SHIP_COSTS[Enums.ShipClass.SENGOKOBUNE], 8.0)


func test_shrine_dedicated_costs_more() -> void:
	var entry: Dictionary = ConstructionSystem.SHRINE_COSTS[ConstructionData.ConstructionType.SHRINE_ROADSIDE]
	assert_true(entry["dedicated"] > entry["general"])


# -- Shrine Type Names ---------------------------------------------------------

func test_shrine_type_name_roadside() -> void:
	assert_eq(
		ConstructionSystem.SHRINE_TYPE_NAMES[ConstructionData.ConstructionType.SHRINE_ROADSIDE],
		"roadside_shrine",
	)


func test_shrine_type_name_local() -> void:
	assert_eq(
		ConstructionSystem.SHRINE_TYPE_NAMES[ConstructionData.ConstructionType.SHRINE_LOCAL],
		"local_shrine",
	)


# -- Infrastructure Decomposition (s57.20.1) -----------------------------------

func _make_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.season = 1
	ctx.ic_day = 10
	ctx.status = 5.0
	return ctx


func test_infra_non_lord_gets_rest() -> void:
	var ctx := _make_ctx()
	ctx.is_lord = false
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")


func test_infra_not_at_holdings_gets_rest() -> void:
	var ctx := _make_ctx()
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")


func test_infra_worship_failure_builds_shrine() -> void:
	var ctx := _make_ctx()
	ctx.worship_failing_province_ids = [10]
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "BUILD_INFRASTRUCTURE")
	assert_eq(need.priority, 3)
	assert_eq(need.target_province_id, 10)
	assert_eq(need.target_intent, "BUILD_SHRINE")


func test_infra_border_without_fort_builds_fortification() -> void:
	var ctx := _make_ctx()
	ctx.border_province_ids_without_fort = [20]
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "BUILD_INFRASTRUCTURE")
	assert_eq(need.priority, 2)
	assert_eq(need.target_province_id, 20)
	assert_eq(need.target_intent, "BUILD_FORTIFICATION")


func test_infra_surplus_pu_founds_village() -> void:
	var ctx := _make_ctx()
	ctx.surplus_pu_province_ids = [30]
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "BUILD_INFRASTRUCTURE")
	assert_eq(need.priority, 1)
	assert_eq(need.target_province_id, 30)
	assert_eq(need.target_intent, "FOUND_VILLAGE")


func test_infra_coastal_naval_threat_commissions_ship() -> void:
	var ctx := _make_ctx()
	ctx.is_coastal = true
	ctx.has_naval_threat = true
	ctx.has_naval_assets =false
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "BUILD_INFRASTRUCTURE")
	assert_eq(need.priority, 3)
	assert_eq(need.target_intent, "COMMISSION_SHIP")


func test_infra_coastal_with_ships_no_commission() -> void:
	var ctx := _make_ctx()
	ctx.is_coastal = true
	ctx.has_naval_threat = true
	ctx.has_naval_assets =true
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")


func test_infra_no_needs_returns_rest() -> void:
	var ctx := _make_ctx()
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")


func test_infra_worship_takes_priority_over_fort() -> void:
	var ctx := _make_ctx()
	ctx.worship_failing_province_ids = [10]
	ctx.border_province_ids_without_fort = [20]
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.target_intent, "BUILD_SHRINE")


func test_infra_fort_takes_priority_over_village() -> void:
	var ctx := _make_ctx()
	ctx.border_province_ids_without_fort = [20]
	ctx.surplus_pu_province_ids = [30]
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.target_intent, "BUILD_FORTIFICATION")


func test_infra_village_takes_priority_over_ship() -> void:
	var ctx := _make_ctx()
	ctx.surplus_pu_province_ids = [30]
	ctx.is_coastal = true
	ctx.has_naval_threat = true
	ctx.has_naval_assets =false
	var obj := {"need_type": "BUILD_INFRASTRUCTURE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.target_intent, "FOUND_VILLAGE")


# -- Integration: Orchestrator Construction Pipeline ---------------------------

func _make_dice() -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(42)
	return d


func _make_day_result(char_id: int, action: String, extras: Dictionary = {}) -> Dictionary:
	var effects: Dictionary = {
		"requires_construction": true,
		"construction_action": action,
	}
	effects.merge(extras)
	return {"character_id": char_id, "effects": effects}


# -- Village founding via effect flag → immediate settlement creation ----------

func test_integration_village_founding_creates_settlement() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var chars_by_id: Dictionary = {1: c}
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []
	var ships: Array[ShipData] = []
	var next_sid: Array[int] = [100]
	var next_cid: Array[int] = [1]

	var day_results: Array = [_make_day_result(1, "FOUND_VILLAGE", {"province_id": 1})]

	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, provinces, settlements, constructions,
		next_sid, next_cid, 50, ships, _make_dice(),
	)

	assert_eq(results.size(), 1)
	assert_true(results[0].get("applied", false))
	assert_eq(results[0].get("type", ""), "village")
	assert_eq(settlements.size(), 2)
	assert_eq(settlements[1].settlement_id, 100)
	assert_eq(settlements[1].settlement_type, Enums.SettlementType.VILLAGE)
	assert_eq(next_sid[0], 101)
	# Resources deducted from source settlement
	assert_true(s.koku_stockpile < 20.0)


func test_integration_village_founding_deducts_resources() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var chars_by_id: Dictionary = {1: c}
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]

	var day_results: Array = [_make_day_result(1, "FOUND_VILLAGE", {"province_id": 1})]
	DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, provinces, settlements,
		[] as Array[ConstructionData], [100] as Array[int], [1] as Array[int],
		50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(s.koku_stockpile, 17.0)
	assert_eq(s.population_pu, 4)
	assert_eq(s.rice_stockpile, 9.0)


# -- Fortification via effect flag → immediate creation ------------------------

func test_integration_fortification_creates_settlement() -> void:
	var c := _make_char(1, 3.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var chars_by_id: Dictionary = {1: c}
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]

	var day_results: Array = [_make_day_result(1, "BUILD_FORTIFICATION", {"province_id": 1})]
	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, provinces, settlements,
		[] as Array[ConstructionData], [100] as Array[int], [1] as Array[int],
		50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(results.size(), 1)
	assert_true(results[0].get("applied", false))
	assert_eq(results[0].get("type", ""), "fortification")
	assert_eq(settlements.size(), 2)
	assert_eq(settlements[1].settlement_type, Enums.SettlementType.FORTIFICATION)
	assert_eq(s.koku_stockpile, 15.0)


# -- Shrine: roadside = immediate, village/local = queued ----------------------

func test_integration_roadside_shrine_immediate() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []

	var day_results: Array = [_make_day_result(1, "BUILD_SHRINE", {
		"settlement_id": 10, "shrine_tier": "roadside", "is_dedicated": false,
	})]
	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements, constructions,
		[100] as Array[int], [1] as Array[int], 50, [] as Array[ShipData], _make_dice(),
	)

	assert_true(results[0].get("applied", false))
	assert_true(results[0].get("immediate", false))
	assert_eq(constructions.size(), 0)
	assert_eq(s.worship_locations.size(), 1)
	assert_eq(s.koku_stockpile, 15.0)


func test_integration_village_shrine_queued() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 30.0)
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []

	var day_results: Array = [_make_day_result(1, "BUILD_SHRINE", {
		"settlement_id": 10, "shrine_tier": "village", "is_dedicated": false,
	})]
	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements, constructions,
		[100] as Array[int], [1] as Array[int], 50, [] as Array[ShipData], _make_dice(),
	)

	assert_true(results[0].get("applied", false))
	assert_true(results[0].get("queued", false))
	assert_eq(constructions.size(), 1)
	assert_eq(constructions[0].construction_type, ConstructionData.ConstructionType.SHRINE_VILLAGE)
	assert_eq(constructions[0].seasons_remaining, 2)
	assert_eq(s.worship_locations.size(), 0)


func test_integration_local_shrine_queued_3_seasons() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 70.0)
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []

	var day_results: Array = [_make_day_result(1, "BUILD_SHRINE", {
		"settlement_id": 10, "shrine_tier": "local", "is_dedicated": true,
		"dedicated_fortune": 3,
	})]
	DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements, constructions,
		[100] as Array[int], [1] as Array[int], 50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(constructions.size(), 1)
	assert_eq(constructions[0].construction_type, ConstructionData.ConstructionType.SHRINE_LOCAL)
	assert_eq(constructions[0].seasons_remaining, 3)
	assert_true(constructions[0].is_dedicated)
	assert_eq(constructions[0].dedicated_fortune, 3)


# -- Shrine queue completion → worship_location added --------------------------

func test_integration_shrine_queue_to_completion() -> void:
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHRINE_VILLAGE, 10, 1, 50,
		15.0, 0.0, 0.0, 10, true, 2,
	)
	constructions.append(cd)

	# Tick once: 2 → 1
	DayOrchestrator._process_construction_completions(
		constructions, settlements, {}, [] as Array[ShipData], _make_dice(),
		[100] as Array[int], topics, next_tid, 100,
	)
	assert_eq(constructions.size(), 1)
	assert_eq(s.worship_locations.size(), 0)

	# Tick again: 1 → 0 = complete
	DayOrchestrator._process_construction_completions(
		constructions, settlements, {}, [] as Array[ShipData], _make_dice(),
		[100] as Array[int], topics, next_tid, 200,
	)
	assert_eq(constructions.size(), 0)
	assert_eq(s.worship_locations.size(), 1)
	assert_true(s.worship_locations[0].get("dedicated", false))
	assert_eq(s.worship_locations[0].get("fortune", -1), 2)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "shrine_completed")


# -- Temple queue → new SettlementData -----------------------------------------

func test_integration_temple_queue_entry() -> void:
	var c := _make_char(1, 5.0)
	var p := _make_province(1)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 100.0)
	var chars_by_id: Dictionary = {1: c}
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []

	var day_results: Array = [_make_day_result(1, "FOUND_TEMPLE", {
		"province_id": 1, "is_dedicated": false,
	})]
	DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, provinces, settlements, constructions,
		[100] as Array[int], [1] as Array[int], 50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(constructions.size(), 1)
	assert_eq(constructions[0].construction_type, ConstructionData.ConstructionType.TEMPLE)
	assert_eq(constructions[0].seasons_remaining, 4)
	assert_eq(s.koku_stockpile, 20.0)


func test_integration_temple_completion_creates_settlement() -> void:
	var p := _make_province(1)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = []
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.TEMPLE, 10, 1, 50,
		80.0, 0.5, 0.0,
	)
	cd.is_dedicated = true
	cd.dedicated_fortune = 5
	cd.seasons_remaining = 1
	var constructions: Array[ConstructionData] = [cd]

	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [] as Array[ShipData], _make_dice(),
		next_sid, topics, next_tid, 300,
	)

	assert_eq(constructions.size(), 0)
	assert_eq(settlements.size(), 1)
	assert_eq(settlements[0].settlement_type, Enums.SettlementType.TEMPLE)
	assert_eq(settlements[0].settlement_id, 200)
	assert_eq(next_sid[0], 201)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "temple_completed")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_3)
	assert_eq(topics[0].momentum, TopicMomentumSystem.MOMENTUM_SECONDARY_FLOOR)


# -- Monastery queue → new SettlementData --------------------------------------

func test_integration_monastery_completion_creates_settlement() -> void:
	var p := _make_province(1)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = []
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.MONASTERY, 10, 1, 50,
		80.0, 0.5, 0.0,
	)
	cd.seasons_remaining = 1
	var constructions: Array[ConstructionData] = [cd]

	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [] as Array[ShipData], _make_dice(),
		next_sid, topics, next_tid, 300,
	)

	assert_eq(constructions.size(), 0)
	assert_eq(settlements.size(), 1)
	assert_eq(settlements[0].settlement_type, Enums.SettlementType.MONASTERY)
	assert_eq(next_sid[0], 201)
	assert_eq(topics[0].variant, "monastery_completed")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_3)


# -- Ship commission → queue → ShipData creation -------------------------------

func test_integration_ship_commission_queues() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	s.infrastructure = ["shipyard"]
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = [s]
	var constructions: Array[ConstructionData] = []

	var day_results: Array = [_make_day_result(1, "COMMISSION_SHIP", {
		"settlement_id": 10, "ship_class": Enums.ShipClass.KOBUNE,
	})]
	DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements, constructions,
		[100] as Array[int], [1] as Array[int], 50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(constructions.size(), 1)
	assert_eq(constructions[0].construction_type, ConstructionData.ConstructionType.SHIP)
	assert_eq(constructions[0].ship_class, Enums.ShipClass.KOBUNE)
	assert_eq(constructions[0].seasons_remaining, 1)
	assert_eq(s.koku_stockpile, 17.0)


func test_integration_ship_completion_creates_ship_data() -> void:
	var settlements: Array[SettlementData] = []
	var ships: Array[ShipData] = []
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHIP, 10, 1, 50,
		3.0, 0.0, 0.0, 10, false, -1, Enums.ShipClass.KOBUNE,
	)
	cd.seasons_remaining = 1
	var constructions: Array[ConstructionData] = [cd]

	DayOrchestrator._process_construction_completions(
		constructions, settlements, {}, ships, _make_dice(),
		next_sid, topics, next_tid, 300,
	)

	assert_eq(constructions.size(), 0)
	assert_eq(ships.size(), 1)
	assert_eq(ships[0].ship_class, Enums.ShipClass.KOBUNE)
	assert_eq(ships[0].max_health, 100)
	assert_eq(ships[0].health, 100)
	assert_eq(ships[0].attack, 3)
	assert_eq(ships[0].defense, 3)
	assert_eq(ships[0].morale, 12)
	assert_eq(ships[0].cargo_capacity, 0.3)
	assert_eq(ships[0].ic_day_launched, 300)
	assert_eq(ships[0].current_province_id, 1)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "ship_launched")


# -- Organic village formation on season boundary ------------------------------

func test_integration_organic_village_formation() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	DayOrchestrator._process_organic_villages(
		provinces, settlements, next_sid, topics, next_tid, 100,
	)

	assert_eq(settlements.size(), 2)
	assert_eq(settlements[1].settlement_type, Enums.SettlementType.VILLAGE)
	assert_eq(settlements[1].settlement_id, 200)
	assert_eq(next_sid[0], 201)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "settlement")
	assert_eq(topics[0].variant, "organic_formation")
	assert_eq(s.population_pu, 9)


func test_integration_organic_village_low_stability_blocked() -> void:
	var p := _make_province(1, Enums.TerrainType.PLAINS)
	p.stability = 30.0
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 10, 20.0, 10.0)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = [s]
	var topics: Array[TopicData] = []

	DayOrchestrator._process_organic_villages(
		provinces, settlements, [200] as Array[int], topics, [1] as Array[int], 100,
	)

	assert_eq(settlements.size(), 1)
	assert_eq(topics.size(), 0)


# -- Topic generation on completion --------------------------------------------

func test_integration_shinden_topic_tier_2() -> void:
	var p := _make_province(1)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = []
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.SHINDEN, 10, 1, 50,
		250.0, 1.0, 0.0,
	)
	cd.seasons_remaining = 1
	var constructions: Array[ConstructionData] = [cd]

	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [] as Array[ShipData], _make_dice(),
		next_sid, topics, next_tid, 300,
	)

	assert_eq(topics.size(), 1)
	assert_eq(topics[0].tier, TopicData.Tier.TIER_2)
	assert_eq(topics[0].momentum, 40.0)
	assert_eq(topics[0].variant, "shinden_completed")
	assert_eq(settlements[0].settlement_type, Enums.SettlementType.SHINDEN)


# -- Validation failures propagate through pipeline ----------------------------

func test_integration_village_invalid_province_returns_not_applied() -> void:
	var c := _make_char(1, 3.0)
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = []

	var day_results: Array = [_make_day_result(1, "FOUND_VILLAGE", {"province_id": 999})]
	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements,
		[] as Array[ConstructionData], [100] as Array[int], [1] as Array[int],
		50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(results.size(), 1)
	assert_false(results[0].get("applied", true))
	assert_eq(results[0].get("reason", ""), "province_not_found")


func test_integration_unknown_action_returns_not_applied() -> void:
	var c := _make_char(1, 3.0)
	var chars_by_id: Dictionary = {1: c}

	var day_results: Array = [_make_day_result(1, "BUILD_CASTLE", {})]
	var results: Array[Dictionary] = DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, [] as Array[SettlementData],
		[] as Array[ConstructionData], [100] as Array[int], [1] as Array[int],
		50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(results.size(), 1)
	assert_false(results[0].get("applied", true))
	assert_eq(results[0].get("reason", ""), "unknown_action")


# -- Multi-season queue tick counts correctly ----------------------------------

func test_integration_temple_4_season_queue() -> void:
	var p := _make_province(1)
	var provinces: Dictionary = {1: p}
	var settlements: Array[SettlementData] = []
	var topics: Array[TopicData] = []
	var next_sid: Array[int] = [200]
	var next_tid: Array[int] = [1]

	var cd: ConstructionData = ConstructionSystem.create_construction(
		1, ConstructionData.ConstructionType.TEMPLE, 10, 1, 50,
		80.0, 0.5, 0.0,
	)
	var constructions: Array[ConstructionData] = [cd]
	assert_eq(cd.seasons_remaining, 4)

	for i: int in range(3):
		DayOrchestrator._process_construction_completions(
			constructions, settlements, provinces, [] as Array[ShipData], _make_dice(),
			next_sid, topics, next_tid, 100 + i * 90,
		)

	assert_eq(constructions.size(), 1)
	assert_eq(cd.seasons_remaining, 1)
	assert_eq(settlements.size(), 0)

	# Final tick completes it
	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [] as Array[ShipData], _make_dice(),
		next_sid, topics, next_tid, 460,
	)

	assert_eq(constructions.size(), 0)
	assert_eq(settlements.size(), 1)
	assert_eq(settlements[0].settlement_type, Enums.SettlementType.TEMPLE)
	assert_eq(topics.size(), 1)


# -- Dedicated shrine passes fortune through pipeline --------------------------

func test_integration_dedicated_roadside_shrine_fortune() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 20.0)
	var chars_by_id: Dictionary = {1: c}
	var settlements: Array[SettlementData] = [s]

	var day_results: Array = [_make_day_result(1, "BUILD_SHRINE", {
		"settlement_id": 10, "shrine_tier": "roadside",
		"is_dedicated": true, "dedicated_fortune": 4,
	})]
	DayOrchestrator._process_construction_effects(
		day_results, chars_by_id, {}, settlements,
		[] as Array[ConstructionData], [100] as Array[int], [1] as Array[int],
		50, [] as Array[ShipData], _make_dice(),
	)

	assert_eq(s.worship_locations.size(), 1)
	assert_true(s.worship_locations[0].get("dedicated", false))
	assert_eq(s.worship_locations[0].get("fortune", -1), 4)
	assert_eq(s.koku_stockpile, 8.0)


# -- Forge Construction (GDD s4.3) ---------------------------------------------

func test_forge_koku_cost_constant() -> void:
	assert_almost_eq(ConstructionSystem.FORGE_KOKU_COST, 35.0, 0.01)


func test_forge_build_seasons_constant() -> void:
	assert_eq(ConstructionSystem.FORGE_BUILD_SEASONS, 2)


func test_validate_forge_sufficient_koku() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 40.0)
	var r: Dictionary = ConstructionSystem.validate_forge_construction(c, s)
	assert_true(r["valid"])


func test_validate_forge_insufficient_koku() -> void:
	var c := _make_char(1, 3.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 10.0)
	var r: Dictionary = ConstructionSystem.validate_forge_construction(c, s)
	assert_false(r["valid"])
	assert_eq(r["reason"], "insufficient_koku")


func test_validate_forge_insufficient_authority() -> void:
	var c := _make_char(1, 1.0)
	var s := _make_settlement(10, 1, Enums.SettlementType.VILLAGE, 5, 10.0, 40.0)
	var r: Dictionary = ConstructionSystem.validate_forge_construction(c, s)
	assert_false(r["valid"])
	assert_eq(r["reason"], "insufficient_authority")


func test_forge_get_build_seasons() -> void:
	var cd_data := ConstructionData.new()
	cd_data.construction_type = ConstructionData.ConstructionType.FORGE
	cd_data.seasons_remaining = 2
	# Verify the enum is wired into _get_build_seasons via create_construction
	var cd_out: ConstructionData = ConstructionSystem.create_construction(
		99, ConstructionData.ConstructionType.FORGE, 1, 1, 0, 35.0,
	)
	assert_eq(cd_out.seasons_remaining, 2)
	assert_eq(cd_out.seasons_total, 2)
