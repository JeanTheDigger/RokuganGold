class_name MissionBuilder
## s56.9 Objective Slot assignment --- LOCKED.
## Wires QuestSeedSelector output into the full ASCII map mission pipeline:
## seed_dict → objectives → map generation → roster composition → unit placement.
## Returns a complete mission package ready for the quest display layer.
## get_player_entry() resolves the player start tile per s4.4 entry conventions.

# Objectives by seed type (s56.10) -----------------------------------------------
# Maps seed_type int → ObjType int array passed to the template generator.
# ObjType 0 == KILL_LEADER is universal across all non-urban templates.
# SEED_URBAN_CRIMINAL_NETWORK uses UrbanHideoutMapData.ObjType numbering (s56.10.15):
#   [2] = KILL_CAPTURE_LEADER, [4] = RECOVER_EVIDENCE.
const _OBJECTIVES_BY_SEED: Dictionary = {
	RosterCompositionSystem.SEED_MAHO_CULT:              [0, 1],    # KILL_LEADER + RECOVER_GOODS (s56.10.8)
	RosterCompositionSystem.SEED_PEASANT_REVOLT:         [0],       # KILL_LEADER; DRIVE_OUT excluded per s56.10.4e
	RosterCompositionSystem.SEED_RONIN_BANDIT:           [0],       # KILL_LEADER
	RosterCompositionSystem.SEED_TAINT_MANIFESTATION:    [0],       # KILL_LEADER (focal point guardian, s56.10.10)
	RosterCompositionSystem.SEED_NEZUMI_INFESTATION:     [0, 1, 2], # chieftain + goods + burn nest (s56.10.6f)
	RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK: [2, 4],    # KILL_CAPTURE_LEADER + RECOVER_EVIDENCE (s56.10.15)
	RosterCompositionSystem.SEED_WALL_SORTIE:            [0],       # KILL_LEADER
	QuestSeedSelector.SEED_ONI_MANIFESTATION:            [0],       # KILL_LEADER (oni boss; roster_ready=false in practice)
	QuestSeedSelector.SEED_ROAD_ENCOUNTER:               [0],       # road encounters use RONIN_BANDIT seed_type in practice
}


## Returns the player's starting tile for a newly-entered mission map.
## Dispatches by which entry field the map subclass exposes (duck-typed via Object.get).
##
## Priority order:
##   1. CastleSiegeMapData:   explicit player_start_x / player_start_y
##   2. ShipBoardingMapData,
##      UrbanHideoutMapData:  entrance_x / entrance_y  →  (entrance_x, entrance_y + 1)
##   3. CaveMapData:          entry_points[is_main]    →  ZONE_EXIT tile position
##   4. ForestApproachCamp,
##      HilltopPosition, …:  entry_vectors southernmost (largest y)
##   5. Fallback:             scan second-to-last row for a passable tile
static func get_player_entry(map: AsciiMapData) -> Vector2i:
	# 1. CastleSiegeMapData: set explicitly by the generator.
	var psx: Variant = map.get("player_start_x")
	if psx != null and (psx as int) >= 0:
		return Vector2i(psx as int, map.get("player_start_y") as int)

	# 2. ShipBoardingMapData (entrance_y == 0) + UrbanHideoutMapData (entrance_y > 0).
	#    Both: player starts one row south of the ZONE_EXIT, inside the entry space.
	var enx: Variant = map.get("entrance_x")
	if enx != null and (enx as int) >= 0:
		var eny: int = map.get("entrance_y") as int
		return Vector2i(enx as int, eny + 1)

	# 3. CaveMapData: prefer the is_main == true entry point.
	var eps: Variant = map.get("entry_points")
	if eps != null and (eps as Array).size() > 0:
		for ep: Dictionary in (eps as Array):
			if ep.get("is_main", false):
				return Vector2i(ep["x"], ep["y"])
		var ep0: Dictionary = (eps as Array)[0]
		return Vector2i(ep0["x"], ep0["y"])

	# 4. Template entry_vectors: pick southernmost entry (largest y).
	var evs: Variant = map.get("entry_vectors")
	if evs != null and (evs as Array).size() > 0:
		var best: Dictionary = (evs as Array)[0]
		for ev: Dictionary in (evs as Array):
			if ev.get("y", 0) > best.get("y", 0):
				best = ev
		return Vector2i(best["x"], best["y"])

	# 5. Fallback: first passable tile on the second-to-last row.
	var fy: int = map.height - 2
	for fx in range(map.width):
		if MovementSystem.is_passable(map.get_tile(fx, fy)):
			return Vector2i(fx, fy)
	return Vector2i(map.width / 2, map.height / 2)


## Returns the province's BiomeType for environment metadata.
## Reads province.biome if set; falls back to biome_for_terrain() when absent.
static func biome_for_province(province: ProvinceData) -> int:
	if province.get("biome") != null:
		return province.biome
	return AsciiMapEnvironment.biome_for_terrain(province.terrain_type)


## Assembles a complete mission package from a QuestSeedSelector seed_dict.
## province_history: Array[String] event tags (war_damage, famine, taint_corruption,
##   peasant_revolt, natural_decay) — controls RuinedStructure availability.
## seed_str: deterministic seed string (province_id + "_" + season + "_" + seed_type).
##
## Return dict keys:
##   "map"             → AsciiMapData subclass instance
##   "placements"      → Array of placement dicts (standard)
##                     | {"friendly": Array, "enemy": Array} (SEED_WALL_SORTIE)
##   "objective_slots" → Array from map.objective_slots
##   "seed_dict"       → input seed_dict unchanged
##   "roster"          → Dictionary from RosterCompositionSystem.compose_roster()
##
## Returns {} when roster_ready is false (encounter design blocked on future GDD sections).
static func assemble(
		province: ProvinceData,
		province_history: Array,
		seed_dict: Dictionary,
		seed_str: String) -> Dictionary:
	if not seed_dict.get("roster_ready", true):
		return {}

	var seed_type: int        = seed_dict.get("seed_type", -1)
	var strength:  int        = seed_dict.get("strength", 1)
	var options:   Dictionary = seed_dict.get("options", {})
	var objectives: Array     = _OBJECTIVES_BY_SEED.get(seed_type, [0])

	var pop_seed: int = hash(seed_str + "_pop")

	var roster: Dictionary = RosterCompositionSystem.compose_roster(
		seed_type, strength, options, pop_seed)

	var map: AsciiMapData
	var placements  # Array (standard) or {"friendly":Array,"enemy":Array} (sortie)

	if seed_type == RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK:
		# UrbanHideout is absent from every TemplateSelector terrain pool — call directly.
		map = UrbanHideoutGenerator.generate(seed_str, strength, objectives)
		placements = MissionPopulator.populate(map, roster, pop_seed)
	elif seed_type == RosterCompositionSystem.SEED_WALL_SORTIE:
		map = MissionTemplateResolver.select_and_generate(
			province, province_history, seed_dict, objectives, seed_str)
		placements = MissionPopulator.populate_sortie(map, roster, pop_seed)
	else:
		map = MissionTemplateResolver.select_and_generate(
			province, province_history, seed_dict, objectives, seed_str)
		placements = MissionPopulator.populate(map, roster, pop_seed)

	var biome: int        = biome_for_province(province)
	# Use spell-induced province weather when active (s31-37a), otherwise fall back to
	# seed_dict default (CLEAR if not specified by caller).
	var spell_weather: int = province.province_weather_state \
		if province.province_weather_state > 0 else AsciiMapEnvironment.WeatherState.CLEAR
	var seed_base: int    = seed_dict.get("weather", AsciiMapEnvironment.WeatherState.CLEAR)
	var base_weather: int = spell_weather if spell_weather != AsciiMapEnvironment.WeatherState.CLEAR \
		else seed_base
	var season: int       = seed_dict.get("season", TimeSystem.Season.SPRING)
	var weather: int      = AsciiMapEnvironment.apply_biome_weather_conversion(
		base_weather, biome, season)
	var fov_mod: int      = AsciiMapEnvironment.weather_to_fov_modifier(weather)

	return {
		"map":             map,
		"placements":      placements,
		"objective_slots": map.objective_slots,
		"seed_dict":       seed_dict,
		"roster":          roster,
		"entry_pos":       get_player_entry(map),
		"environment": {
			"biome":        biome,
			"weather":      weather,
			"fov_modifier": fov_mod,
			"weather_data": AsciiMapEnvironment.get_weather_data(weather),
		},
	}
