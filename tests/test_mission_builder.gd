class_name TestMissionBuilder
extends GutTest
## Tests for MissionBuilder — top-level mission assembly orchestrator (s56.9).

# -- Helpers -------------------------------------------------------------------

func _make_province(terrain: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 1
	p.terrain_type = terrain
	p.province_taint_level = 0.0
	p.stability = 50.0
	return p


func _seed_dict(seed_type: int, strength: int = 1) -> Dictionary:
	return {
		"seed_type":            seed_type,
		"strength":             strength,
		"options":              {},
		"roster_ready":         true,
		"source_insurgency_id": -1,
	}


# -- Return structure ----------------------------------------------------------

func test_assemble_returns_all_required_keys():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "struct_test")
	assert_true(result.has("map"),             "map key missing")
	assert_true(result.has("placements"),      "placements key missing")
	assert_true(result.has("objective_slots"), "objective_slots key missing")
	assert_true(result.has("seed_dict"),       "seed_dict key missing")
	assert_true(result.has("roster"),          "roster key missing")


func test_assemble_map_is_ascii_map_data():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "map_type_test")
	assert_true(result["map"] is AsciiMapData)


func test_assemble_placements_is_array_for_standard_seed():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "placements_type")
	assert_true(result["placements"] is Array)


func test_assemble_objective_slots_is_array():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "objslot_type")
	assert_true(result["objective_slots"] is Array)


func test_assemble_objective_slots_match_map_objective_slots():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "objslot_match")
	assert_eq(result["objective_slots"], result["map"].objective_slots)


func test_assemble_seed_dict_passthrough():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT)
	var result := MissionBuilder.assemble(p, [], sd, "passthrough")
	assert_eq(result["seed_dict"], sd)


func test_assemble_roster_is_dictionary():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "roster_type")
	assert_true(result["roster"] is Dictionary)


# -- roster_ready gate ---------------------------------------------------------

func test_assemble_roster_ready_false_returns_empty_dict():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_RONIN_BANDIT,
		"strength":     1,
		"options":      {},
		"roster_ready": false,
	}
	assert_eq(MissionBuilder.assemble(p, [], sd, "blocked"), {})


func test_assemble_missing_roster_ready_defaults_to_true():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type": RosterCompositionSystem.SEED_RONIN_BANDIT,
		"strength":  1,
		"options":   {},
	}
	var result := MissionBuilder.assemble(p, [], sd, "no_ready_key")
	assert_true(result.has("map"),
		"Missing roster_ready should default to true and proceed normally")


# -- Urban Criminal Network routing -------------------------------------------

func test_assemble_urban_criminal_network_returns_urban_hideout_map():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK), "urban_map")
	assert_true(result["map"] is UrbanHideoutMapData,
		"SEED_URBAN_CRIMINAL_NETWORK must route directly to UrbanHideoutGenerator")


func test_assemble_urban_criminal_network_placements_is_array():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK), "urban_place")
	assert_true(result["placements"] is Array,
		"Urban path uses populate() not populate_sortie()")


func test_assemble_urban_criminal_network_objective_slots_not_empty():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK), "urban_obj")
	assert_false(result["objective_slots"].is_empty(),
		"UrbanHideout always generates at least one objective slot")


# -- Wall Sortie routing -------------------------------------------------------

func test_assemble_wall_sortie_placements_is_dictionary():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_WALL_SORTIE,
		"strength":     2,
		"options":      {"sortie_size": "SMALL"},
		"roster_ready": true,
	}
	var result := MissionBuilder.assemble(p, [], sd, "sortie_dict")
	assert_true(result["placements"] is Dictionary)


func test_assemble_wall_sortie_placements_has_friendly_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_WALL_SORTIE,
		"strength":     1,
		"options":      {},
		"roster_ready": true,
	}
	var result := MissionBuilder.assemble(p, [], sd, "sortie_friendly")
	assert_true(result["placements"].has("friendly"))


func test_assemble_wall_sortie_placements_has_enemy_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_WALL_SORTIE,
		"strength":     1,
		"options":      {},
		"roster_ready": true,
	}
	var result := MissionBuilder.assemble(p, [], sd, "sortie_enemy")
	assert_true(result["placements"].has("enemy"))


func test_assemble_wall_sortie_map_is_ascii_map_data():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_WALL_SORTIE,
		"strength":     1,
		"options":      {},
		"roster_ready": true,
	}
	var result := MissionBuilder.assemble(p, [], sd, "sortie_map")
	assert_true(result["map"] is AsciiMapData)


# -- Smoke tests: one per seed type -------------------------------------------

func test_assemble_maho_cult_produces_valid_map():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_MAHO_CULT), "maho_smoke")
	assert_not_null(result.get("map"))
	assert_true(result["map"] is AsciiMapData)


func test_assemble_peasant_revolt_produces_valid_map():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_PEASANT_REVOLT), "revolt_smoke")
	assert_not_null(result.get("map"))
	assert_true(result["placements"] is Array)


func test_assemble_taint_manifestation_produces_valid_map():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":            RosterCompositionSystem.SEED_TAINT_MANIFESTATION,
		"strength":             2,
		"options":              {"ptl": 4.5},
		"roster_ready":         true,
		"source_insurgency_id": -1,
	}
	var result := MissionBuilder.assemble(p, [], sd, "taint_smoke")
	assert_not_null(result.get("map"))
	assert_true(result["map"] is AsciiMapData)


func test_assemble_nezumi_infestation_produces_valid_map():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_NEZUMI_INFESTATION), "nezumi_smoke")
	assert_not_null(result.get("map"))
	assert_true(result["placements"] is Array)


func test_assemble_oni_manifestation_roster_ready_false_returns_empty():
	# GDD s56.1.2: Named Oni stat blocks not yet in s54; roster_ready=false.
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    QuestSeedSelector.SEED_ONI_MANIFESTATION,
		"strength":     10,
		"options":      {},
		"roster_ready": false,
	}
	assert_eq(MissionBuilder.assemble(p, [], sd, "oni_smoke"), {})


# -- Determinism ---------------------------------------------------------------

func test_assemble_same_inputs_produce_same_map_dimensions():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT, 2)
	var seed_str := "det_province_7_summer_2_ronin"
	var r1 := MissionBuilder.assemble(p, [], sd, seed_str)
	var r2 := MissionBuilder.assemble(p, [], sd, seed_str)
	assert_eq(r1["map"].width,  r2["map"].width)
	assert_eq(r1["map"].height, r2["map"].height)


func test_assemble_urban_same_inputs_deterministic():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK)
	var seed_str := "urban_det_province_2_autumn"
	var r1 := MissionBuilder.assemble(p, [], sd, seed_str)
	var r2 := MissionBuilder.assemble(p, [], sd, seed_str)
	assert_eq(r1["map"].width,  r2["map"].width)
	assert_eq(r1["map"].height, r2["map"].height)


# -- Unknown seed type fallback ------------------------------------------------

func test_assemble_unknown_seed_type_does_not_crash():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(p, [], _seed_dict(999), "unknown_seed")
	assert_not_null(result)
	assert_true(result.has("map"))


func test_assemble_unknown_seed_type_map_is_ascii_map_data():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(p, [], _seed_dict(999), "unknown_map_type")
	assert_true(result["map"] is AsciiMapData)


# -- Province history interaction ----------------------------------------------

func test_assemble_with_ruin_history_does_not_crash():
	var p := _make_province(Enums.TerrainType.PLAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT)
	var result := MissionBuilder.assemble(p, ["war_damage"], sd, "ruin_hist")
	assert_not_null(result.get("map"))
	assert_true(result["map"] is AsciiMapData)


# -- Environment metadata (s56.6 weather + FoV integration) -------------------

func test_assemble_returns_environment_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_key")
	assert_true(result.has("environment"), "environment key missing")


func test_environment_has_biome_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_biome")
	assert_true(result["environment"].has("biome"))


func test_environment_has_weather_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_weather")
	assert_true(result["environment"].has("weather"))


func test_environment_has_fov_modifier_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_fov")
	assert_true(result["environment"].has("fov_modifier"))


func test_environment_has_weather_data_key():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_wd")
	assert_true(result["environment"].has("weather_data"))
	assert_true(result["environment"]["weather_data"] is Dictionary)


func test_environment_biome_matches_terrain_type():
	# Mountains province → NORTHERN_HIGHLAND biome.
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_biome_match")
	assert_eq(result["environment"]["biome"],
		AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND)


func test_environment_default_weather_is_clear():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_clear")
	assert_eq(result["environment"]["weather"], AsciiMapEnvironment.WeatherState.CLEAR)


func test_environment_fov_modifier_zero_for_clear_weather():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var result := MissionBuilder.assemble(
		p, [], _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT), "env_fov_clear")
	assert_eq(result["environment"]["fov_modifier"], 0)


func test_environment_rain_weather_gives_fov_modifier_2():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT)
	sd["weather"] = AsciiMapEnvironment.WeatherState.RAIN
	sd["season"]  = TimeSystem.Season.SUMMER  # Summer: no snow conversion
	var result := MissionBuilder.assemble(p, [], sd, "env_rain_fov")
	assert_eq(result["environment"]["fov_modifier"], 2)


func test_environment_rain_winter_northern_highland_converts_to_snow():
	# Province is MOUNTAINS → NORTHERN_HIGHLAND biome; Rain + Winter → Snow.
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := _seed_dict(RosterCompositionSystem.SEED_RONIN_BANDIT)
	sd["weather"] = AsciiMapEnvironment.WeatherState.RAIN
	sd["season"]  = TimeSystem.Season.WINTER
	var result := MissionBuilder.assemble(p, [], sd, "env_snow_conv")
	assert_eq(result["environment"]["weather"], AsciiMapEnvironment.WeatherState.SNOW)


func test_environment_roster_ready_false_returns_empty():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_RONIN_BANDIT,
		"strength":     1,
		"options":      {},
		"roster_ready": false,
	}
	var result := MissionBuilder.assemble(p, [], sd, "env_blocked")
	assert_eq(result, {})
