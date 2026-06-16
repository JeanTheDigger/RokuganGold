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

# Eight compass-bearing unit vectors for wind assignment (s56.6.6): N, NE, E, SE,
# S, SW, W, NW. y- is north (matches the tile grid's top-origin).
const _WIND_BEARINGS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


## s56.6.6: wind direction is assigned randomly at map generation and fixed for the
## mission (only mechanically relevant during Wind/Rain/Storm). Deterministic from seed.
static func _assign_wind(map: AsciiMapData, seed_str: String) -> void:
	map.wind_dir = _WIND_BEARINGS[absi(hash(seed_str + "_wind")) % _WIND_BEARINGS.size()]


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
## Returns {} when roster_ready is false (encounter design blocked on future GDD sections),
## EXCEPT SEED_SPIRITUAL_OVERLAP, which is assembled palette-only (map + overlay, no roster).
static func assemble(
		province: ProvinceData,
		province_history: Array,
		seed_dict: Dictionary,
		seed_str: String) -> Dictionary:
	# Spiritual overlap (s56.16): palette-layer mission — generate the terrain map
	# and apply the depth-driven SpiritualPalette gradient. Spirit rosters and the
	# ritual encounter loop are stubbed, so this bypasses the roster_ready gate
	# (the seed is intentionally roster_ready=false) and population.
	if seed_dict.get("seed_type", -1) == QuestSeedSelector.SEED_SPIRITUAL_OVERLAP:
		return _assemble_spiritual(province, province_history, seed_dict, seed_str)

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
	else:
		map = MissionTemplateResolver.select_and_generate(
			province, province_history, seed_dict, objectives, seed_str)

	# Depth gradient (s56.21): tag tiles with path-distance from the player
	# entry BEFORE population so the populator can bias stronger units / the
	# leader into deeper regions.
	var entry: Vector2i = get_player_entry(map)
	map.compute_depth_grid(entry.x, entry.y)
	_assign_wind(map, seed_str)  # s56.6.6 fire/smoke wind bearing

	if seed_type == RosterCompositionSystem.SEED_WALL_SORTIE:
		placements = MissionPopulator.populate_sortie(map, roster, pop_seed)
	else:
		placements = MissionPopulator.populate(map, roster, pop_seed)

	# Traps (s56.20): placed only when the roster carries a trap-laying unit
	# (PROVISIONAL gate — see TrapSystem.TRAP_LAYER_UNIT_TYPES). No-op otherwise.
	TrapSystem.place_traps(map, roster, strength, hash(seed_str + "_traps"))

	return {
		"map":             map,
		"placements":      placements,
		"objective_slots": map.objective_slots,
		"seed_dict":       seed_dict,
		"roster":          roster,
		"entry_pos":       entry,
		"environment":     _build_environment(province, seed_dict),
	}


## Spiritual overlap (s56.16) mission package. Reuses the province terrain template
## (the realm overlaps the mortal map — MissionTemplateResolver selects by terrain,
## not seed_type), tags the depth gradient, and applies the SpiritualPalette overlay.
## Enriches the package with the data the (deferred) ritual/exposure combat loop
## consumes: the spirit roster pool (s56.16.6b/8e/9c/7b), the Restoration Ritual
## metadata (s56.16.5b/5c/5d), the exposure realm (s56.16.6a/7a/8a/9a), and the
## heart tile. Population is still stubbed: placements/roster empty (the live
## creature combat is a later tranche), so the map's KILL_LEADER slot stays unfilled.
static func _assemble_spiritual(
		province: ProvinceData,
		province_history: Array,
		seed_dict: Dictionary,
		seed_str: String) -> Dictionary:
	var options: Dictionary = seed_dict.get("options", {})
	var event_type: int = int(options.get("event_type", Enums.SpiritualEventType.REALM_OVERLAP))
	var realm: int      = int(options.get("realm", Enums.SpiritRealm.GAKI_DO))
	var element: int    = int(options.get("element", Enums.Ring.NONE))
	var severity: int   = int(options.get("severity", Enums.SpiritualSeverity.MILD))

	var map: AsciiMapData = MissionTemplateResolver.select_and_generate(
		province, province_history, seed_dict, [], seed_str)

	# Depth gradient first (s56.21), then derive the overlap intensity from it.
	var entry: Vector2i = get_player_entry(map)
	map.compute_depth_grid(entry.x, entry.y)
	_assign_wind(map, seed_str)  # s56.6.6 fire/smoke wind bearing
	SpiritualPalette.apply_overlap(map, event_type, realm, element)

	var roster_pool: Dictionary = _spiritual_roster_pool(event_type, realm, province)

	var environment: Dictionary = _build_environment(province, seed_dict)
	environment["spiritual"] = {
		"event_type":     event_type,
		"realm":          realm,
		"element":        element,
		"severity":       severity,
		"roster_pool":    roster_pool,        # zone → creature-id arrays ({} for elemental/Meido/Yume-do)
		"roster_realm":   realm if not roster_pool.is_empty() else -1,
		"exposure_realm": realm,              # SpiritExposureSystem.new_state(realm, pc.willpower)
		"ritual":         _spiritual_ritual_meta(event_type, realm, element, severity),
		"heart_pos":      _find_heart_tile(map),
	}
	return {
		"map":             map,
		"placements":      [],
		"objective_slots": map.objective_slots,
		"seed_dict":       seed_dict,
		"roster":          {},
		"roster_pool":     roster_pool,
		"entry_pos":       entry,
		"environment":     environment,
	}


## Spirit roster pool for a spiritual overlap. Realm overlaps return the realm's
## zone→creature-id pool (s56.16.6b/8e/9c/7b) with availability gates; elemental
## imbalances and realms with no GDD roster (Meido/Yume-do) return {}.
static func _spiritual_roster_pool(event_type: int, realm: int, province: ProvinceData) -> Dictionary:
	if event_type != Enums.SpiritualEventType.REALM_OVERLAP:
		return {}  # elemental imbalances have no creature roster (counter-ritual encounter)
	match realm:
		Enums.SpiritRealm.GAKI_DO:
			var famine: bool = province.starvation_stage > 0 or province.crisis_type == "famine"
			# settlement=false: the overlap reuses the terrain template, not a settlement map,
			# so the settlement-only Mokumokuren does not appear here.
			return SpiritBestiary.gaki_do_pool(province.terrain_type, famine, false)
		Enums.SpiritRealm.TOSHIGOKU:
			return SpiritBestiary.toshigoku_pool()
		Enums.SpiritRealm.SAKKAKU:
			return SpiritBestiary.sakkaku_pool()
		Enums.SpiritRealm.CHIKUSHUDO:
			return SpiritBestiary.chikushudo_pool()
		_:
			return {}  # Meido / Yume-do: no roster in s56.16


## Restoration Ritual metadata (s56.16.5b/5c/5d) for the combat loop: duration,
## per-round TN, and the approach (realm trait, or elemental counter Ring).
static func _spiritual_ritual_meta(event_type: int, realm: int, element: int, severity: int) -> Dictionary:
	var meta: Dictionary = {
		"duration_rounds": SpiritualRitualSystem.DURATION_BY_SEVERITY.get(severity, 10),
		"ritual_tn":       SpiritualRitualSystem.RITUAL_TN,
	}
	if event_type == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE:
		meta["counter_ring"] = SpiritualRitualSystem.counter_ring(element)  # NONE = Void: any Ring
	else:
		meta["approach_trait"] = SpiritualRitualSystem.REALM_TRAIT.get(realm, Enums.Trait.AWARENESS)
	return meta


## The heart tile: the deepest reachable tile on the depth grid (s56.16.5a — the
## overlap intensity peaks at the heart). Falls back to map centre if ungraded.
static func _find_heart_tile(map: AsciiMapData) -> Vector2i:
	if not map.has_depth_grid():
		return Vector2i(map.width / 2, map.height / 2)
	var best_d: int = -1
	var best: Vector2i = Vector2i(map.width / 2, map.height / 2)
	for y in range(map.height):
		for x in range(map.width):
			var d: int = map.depth_at(x, y)
			if d > best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


## Builds the environment metadata dict (biome + resolved weather + FoV modifier).
## Uses spell-induced province weather when active (s31-37a), else the seed_dict
## default (CLEAR), then applies biome/season conversion (s56.6).
static func _build_environment(province: ProvinceData, seed_dict: Dictionary) -> Dictionary:
	var biome: int        = biome_for_province(province)
	var spell_weather: int = province.province_weather_state \
		if province.province_weather_state > 0 else AsciiMapEnvironment.WeatherState.CLEAR
	var seed_base: int    = seed_dict.get("weather", AsciiMapEnvironment.WeatherState.CLEAR)
	var base_weather: int = spell_weather if spell_weather != AsciiMapEnvironment.WeatherState.CLEAR \
		else seed_base
	var season: int       = seed_dict.get("season", TimeSystem.Season.SPRING)
	var weather: int      = AsciiMapEnvironment.apply_biome_weather_conversion(
		base_weather, biome, season)
	return {
		"biome":        biome,
		"weather":      weather,
		"fov_modifier": AsciiMapEnvironment.weather_to_fov_modifier(weather),
		"weather_data": AsciiMapEnvironment.get_weather_data(weather),
	}
