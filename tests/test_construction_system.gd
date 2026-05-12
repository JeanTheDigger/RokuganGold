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
