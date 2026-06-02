class_name TestMissionTemplateResolver
extends GutTest
## Tests for MissionTemplateResolver — structural wiring layer connecting
## QuestSeedSelector → TemplateSelector → template generators → AsciiMapData.

# -- Helpers -------------------------------------------------------------------

func _make_province(terrain: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 1
	p.terrain_type = terrain
	p.province_taint_level = 0.0
	p.stability = 50.0
	return p


func _seed_dict(strength: int) -> Dictionary:
	return {"strength": strength, "seed_type": 0, "seed_label": "RONIN_BANDIT"}


# -- dispatch: all 7 template IDs return correct subtype -----------------------

func test_dispatch_cave_returns_cave_map_data():
	var result = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 1, [0], "t")
	assert_true(result is CaveMapData)


func test_dispatch_occupied_village_returns_occupied_village_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.OCCUPIED_VILLAGE, 1, [0], "t")
	assert_true(result is OccupiedVillageMapData)


func test_dispatch_forest_approach_camp_returns_forest_approach_camp_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.FOREST_APPROACH_CAMP, 1, [0], "t")
	assert_true(result is ForestApproachCampMapData)


func test_dispatch_makeshift_stockade_returns_makeshift_stockade_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.MAKESHIFT_STOCKADE, 1, [0], "t")
	assert_true(result is MakeshiftStockadeMapData)


func test_dispatch_hilltop_position_returns_hilltop_position_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.HILLTOP_POSITION, 1, [0], "t")
	assert_true(result is HilltopPositionMapData)


func test_dispatch_ravine_camp_returns_ravine_camp_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.RAVINE_CAMP, 1, [0], "t")
	assert_true(result is RavineCampMapData)


func test_dispatch_ruined_structure_returns_ruined_structure_map_data():
	var result = MissionTemplateResolver.dispatch(
		TemplateSelector.RUINED_STRUCTURE, 1, [0], "t")
	assert_true(result is RuinedStructureMapData)


# -- dispatch: fallback for unknown template ID --------------------------------

func test_dispatch_unknown_template_id_falls_back_to_cave():
	var result = MissionTemplateResolver.dispatch("NotATemplate", 1, [0], "t")
	assert_true(result is CaveMapData)


func test_dispatch_empty_string_falls_back_to_cave():
	var result = MissionTemplateResolver.dispatch("", 1, [0], "t")
	assert_true(result is CaveMapData)


# -- dispatch: objectives defaulting -------------------------------------------

func test_dispatch_empty_objectives_uses_default_and_returns_non_null():
	var result = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 1, [], "t")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_dispatch_empty_objectives_matches_explicit_kill_leader():
	# DEFAULT_OBJECTIVES = [0] = [ObjType.KILL_LEADER]; both paths must yield same map.
	var r_empty = MissionTemplateResolver.dispatch(
		TemplateSelector.CAVE, 1, [], "det_seed_42")
	var r_explicit = MissionTemplateResolver.dispatch(
		TemplateSelector.CAVE, 1, [0], "det_seed_42")
	assert_eq(r_empty.width,  r_explicit.width)
	assert_eq(r_empty.height, r_explicit.height)


# -- dispatch: determinism -----------------------------------------------------

func test_dispatch_same_inputs_produce_same_dimensions():
	var seed_str := "province_7_summer_2_insurgency"
	var r1 = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 2, [0], seed_str)
	var r2 = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 2, [0], seed_str)
	assert_eq(r1.width,  r2.width)
	assert_eq(r1.height, r2.height)


func test_dispatch_different_seeds_may_differ():
	# Smoke test: no crash on varied seeds; uniqueness not guaranteed but both valid.
	var r1 = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 1, [0], "alpha")
	var r2 = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 1, [0], "beta")
	assert_true(r1 is AsciiMapData)
	assert_true(r2 is AsciiMapData)


# -- dispatch: strength propagation --------------------------------------------

func test_dispatch_strength_1_returns_valid_map():
	var result = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 1, [0], "s1")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_dispatch_strength_5_returns_valid_map():
	var result = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 5, [0], "s5")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_dispatch_strength_10_returns_valid_map():
	var result = MissionTemplateResolver.dispatch(TemplateSelector.CAVE, 10, [0], "s10")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


# -- select_and_generate: basic contract ---------------------------------------

func test_select_and_generate_returns_ascii_map_data():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result = MissionTemplateResolver.select_and_generate(
		p, [], _seed_dict(1), [0], "sg_test_1")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_select_and_generate_returns_ascii_map_data_plains():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result = MissionTemplateResolver.select_and_generate(
		p, [], _seed_dict(2), [0], "sg_plains_1")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_select_and_generate_returns_ascii_map_data_forest():
	var p := _make_province(Enums.TerrainType.FOREST)
	var result = MissionTemplateResolver.select_and_generate(
		p, [], _seed_dict(3), [0], "sg_forest_1")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


# -- select_and_generate: terrain type drives template pool --------------------

func test_select_and_generate_mountains_produces_valid_result():
	# Mountains pool: Cave 50%, RavineCamp 20%, HilltopPosition 20%, Ruin 10%.
	# Majority of seeds → Cave or Ravine/Hilltop — never OccupiedVillage.
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result = MissionTemplateResolver.select_and_generate(
		p, [], _seed_dict(1), [0], "mt_seed_1")
	assert_not_null(result)
	assert_false(result is OccupiedVillageMapData,
		"Mountains pool never contains OccupiedVillage")


func test_select_and_generate_plains_never_returns_cave():
	# Plains pool: OccupiedVillage 45%, MakeshiftStockade 35%, Ruin 15%, Ravine 5%.
	# No Cave entry regardless of seed.
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result = MissionTemplateResolver.select_and_generate(
		p, [], _seed_dict(1), [0], "plains_seed_1")
	assert_not_null(result)
	assert_false(result is CaveMapData, "Plains pool never contains Cave")


func test_select_and_generate_different_terrain_different_pools():
	# Mountains and Plains pools are disjoint in their dominant templates.
	# Cave is only in Mountains; OccupiedVillage weights differ substantially.
	# At minimum: no crash and both return valid data.
	var p_mt := _make_province(Enums.TerrainType.MOUNTAINS)
	var p_pl := _make_province(Enums.TerrainType.PLAINS)
	var r_mt = MissionTemplateResolver.select_and_generate(
		p_mt, [], _seed_dict(1), [0], "terrain_cmp_seed")
	var r_pl = MissionTemplateResolver.select_and_generate(
		p_pl, [], _seed_dict(1), [0], "terrain_cmp_seed")
	assert_true(r_mt is AsciiMapData)
	assert_true(r_pl is AsciiMapData)


# -- select_and_generate: ruin history -----------------------------------------

func test_select_and_generate_no_ruin_history_plains_never_yields_ruined_structure():
	# Without ruin tags, RuinedStructure weight is redistributed away.
	# Running 5 different seeds on a ruin-free province should never pick RuinedStructure.
	var p := _make_province(Enums.TerrainType.PLAINS)
	var sd := _seed_dict(1)
	for i in range(5):
		var r = MissionTemplateResolver.select_and_generate(
			p, [], sd, [0], "noruin_seed_%d" % i)
		assert_false(r is RuinedStructureMapData,
			"Ruin-free province must not produce RuinedStructure (seed %d)" % i)


func test_select_and_generate_ruin_history_does_not_crash():
	# Ruin history unlocks RuinedStructure in the pool; function must complete cleanly.
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result = MissionTemplateResolver.select_and_generate(
		p, ["war_damage"], _seed_dict(1), [0], "ruin_seed_1")
	assert_not_null(result)
	assert_true(result is AsciiMapData)


func test_select_and_generate_all_ruin_tags_accepted():
	var ruin_tags := ["war_damage", "famine", "taint_corruption",
					  "peasant_revolt", "natural_decay"]
	var p := _make_province(Enums.TerrainType.PLAINS)
	for tag in ruin_tags:
		var r = MissionTemplateResolver.select_and_generate(
			p, [tag], _seed_dict(1), [0], "ruintag_" + tag)
		assert_not_null(r, "Ruin tag %s should not crash select_and_generate" % tag)
		assert_true(r is AsciiMapData)


# -- select_and_generate: strength from seed_dict ------------------------------

func test_select_and_generate_reads_strength_from_seed_dict():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	# Strength comes from seed_dict["strength"]; missing key defaults to 1.
	var r_with := MissionTemplateResolver.select_and_generate(
		p, [], {"strength": 3}, [0], "str_test")
	var r_default := MissionTemplateResolver.select_and_generate(
		p, [], {}, [0], "str_test")
	# Both must return valid data; shape may or may not differ by strength.
	assert_true(r_with is AsciiMapData)
	assert_true(r_default is AsciiMapData)


# -- select_and_generate: determinism ------------------------------------------

func test_select_and_generate_same_inputs_deterministic():
	var p := _make_province(Enums.TerrainType.FOREST)
	var sd := _seed_dict(2)
	var seed_str := "det_sg_province_3_autumn"
	var r1 = MissionTemplateResolver.select_and_generate(p, [], sd, [0], seed_str)
	var r2 = MissionTemplateResolver.select_and_generate(p, [], sd, [0], seed_str)
	assert_eq(r1.width,  r2.width)
	assert_eq(r1.height, r2.height)
	assert_eq(r1.get_class(), r2.get_class())
