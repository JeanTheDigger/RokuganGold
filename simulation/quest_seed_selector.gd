class_name QuestSeedSelector
## s56.1 Quest Seed Trigger Selection --- LOCKED.
## Maps province/insurgency/wall world-state to available ASCII map quest seed
## parameter dicts, each ready to pass to RosterCompositionSystem.compose_roster().
## Only detected insurgencies produce seeds (NPCs never use the ASCII map;
## NPC-only resolution goes through the dice engine — CLAUDE.md hard constraint).

# -- Extended seed type constants (beyond RosterCompositionSystem 0-5, 100) ------
const SEED_ONI_MANIFESTATION: int = 101  # s56.1.2: Named Oni boss encounter
const SEED_ROAD_ENCOUNTER:    int = 102  # s56.1.5: Travel hazard (15% chance)
const SEED_SPIRITUAL_OVERLAP: int = 103  # s56.16: spirit-realm / elemental overlap (palette only)

# -- Trigger thresholds ---------------------------------------------------------
const PTL_TAINT_TRIGGER:      float = 3.0   # s56.1.1: Taint Manifestation fires at PTL >= 3
const ONI_STRENGTH_THRESHOLD: int   = 10    # s56.1.2: Maho Cult Strength 10 → Oni Manifestation
# s16.3 "extreme PTL" proxy — PROVISIONAL (no numeric threshold in GDD s16.3)
const PTL_ONI_TRIGGER:        float = 9.0
const ROAD_ENCOUNTER_CHANCE:  float = 0.15  # s4.3.11: 15% per under-garrisoned province traversed

# Stability "Broken" tier upper bound — s11.11: 0-25 is Broken.
# Used as PROVISIONAL proxy for famine/battle province (high_corpse_availability).
const STABILITY_BROKEN_THRESHOLD: float = 25.0

# -- Establishment path: BloodspeakerCellData enum int → RosterCompositionSystem String ---
const _PATH_MAP: Dictionary = {
	0: RosterCompositionSystem.MAHO_PATH_WHISPERING_CELL,    # AGENT_INFILTRATION
	1: RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER,       # PTL_CORRUPTION
	2: RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_NPC,  # NAMED_NPC_FALL
	3: RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_ART,  # ARTIFACT_DISCOVERY
}


## Returns all available quest seeds for `province` given current world state.
## `insurgencies` must contain only detected insurgencies in the province.
## Each returned dict is ready for RosterCompositionSystem.compose_roster() unless
## roster_ready == false (blocked on future GDD sections).
## Return dict keys: seed_type, seed_label, source, strength, options,
##                   source_insurgency_id, roster_ready.
static func select_province_seeds(
		province: ProvinceData,
		insurgencies: Array,
		wall_statuses: Dictionary,
		bloodspeaker_cells: Array,
		seed: int,
		spiritual_events: Array = []) -> Array:
	var results: Array = []

	# 1. Insurgency-sourced seeds (detected only).
	for ins in insurgencies:
		if not ins is InsurgencyData:
			continue
		if not ins.detected:
			continue
		var entry: Dictionary = _seed_from_insurgency(ins, province, bloodspeaker_cells)
		if not entry.is_empty():
			results.append(entry)
		# Maho Cult at Strength 10 additionally generates Oni Manifestation (s56.1.2).
		if ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT \
				and ins.strength >= ONI_STRENGTH_THRESHOLD:
			results.append(_oni_seed_entry(ins.insurgency_id))

	# 2. PTL-triggered Taint Manifestation (no active detected TAINT_MANIFESTATION insurgency).
	if province.province_taint_level >= PTL_TAINT_TRIGGER:
		var taint_already_covered := false
		for ins in insurgencies:
			if ins is InsurgencyData and ins.detected \
					and ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION:
				taint_already_covered = true
				break
		if not taint_already_covered:
			results.append(_ptl_only_taint_seed(province))

	# 3. Oni from extreme PTL (s16.3) — only if not already added via Maho Cult path.
	if province.province_taint_level >= PTL_ONI_TRIGGER:
		var oni_from_cult := false
		for ins in insurgencies:
			if ins is InsurgencyData and ins.detected \
					and ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT \
					and ins.strength >= ONI_STRENGTH_THRESHOLD:
				oni_from_cult = true
				break
		if not oni_from_cult:
			results.append(_oni_seed_entry(-1))

	# 4. Wall sortie (s56.1.2 / s2.4.11).
	if wall_statuses.has(province.province_id):
		var ws: Dictionary = wall_statuses[province.province_id]
		var ss: int = ws.get("ss", 0)
		var size_lower: String = WallSystem.get_ai_sortie_size(ss)
		if size_lower != "none":
			results.append(_wall_sortie_seed(size_lower, ws))

	# 5. Spiritual overlap (s56.16) — one seed per active unresolved spiritual
	#    insurgency event in the province. Palette-only: spirit rosters and the
	#    ritual encounter loop are stubbed, so roster_ready = false.
	for ev in spiritual_events:
		if not ev is SpiritualInsurgencyData:
			continue
		if ev.resolved:
			continue
		if ev.province_id != province.province_id:
			continue
		results.append(_spiritual_seed(ev))

	return results


## Rolls for a road encounter in an under-garrisoned province.
## s4.3.11: 15% chance per under-garrisoned province traversed.
## Returns {triggered, seed_type, seed_label, source, strength, options,
##          source_insurgency_id, roster_ready}.
## triggered == false when garrison_meets_minimum or the roll does not fire.
static func check_road_encounter(
		province: ProvinceData,
		garrison_meets_minimum: bool,
		seed: int) -> Dictionary:
	var base: Dictionary = {
		"triggered":             false,
		"seed_type":             -1,
		"seed_label":            "",
		"source":                "road_encounter",
		"strength":              0,
		"options":               {},
		"source_insurgency_id":  -1,
		"roster_ready":          false,
	}
	if garrison_meets_minimum:
		return base

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("road_" + str(province.province_id) + "_" + str(seed))
	if rng.randf() >= ROAD_ENCOUNTER_CHANCE:
		return base

	# s56.1.5: Road encounters use the Ronin Bandit seed type (bandits accost traveller).
	base["triggered"]    = true
	base["seed_type"]    = RosterCompositionSystem.SEED_RONIN_BANDIT
	base["seed_label"]   = "ROAD_ENCOUNTER"
	base["strength"]     = 1  # s56.1.5 describes a single encounter band, not scaled by insurgency
	base["options"]      = {"stability": int(province.stability)}
	base["roster_ready"] = true
	return base


# -- Private helpers ------------------------------------------------------------

static func _seed_from_insurgency(
		ins: InsurgencyData,
		province: ProvinceData,
		bloodspeaker_cells: Array) -> Dictionary:
	var base: Dictionary = {
		"source":              "insurgency",
		"source_insurgency_id": ins.insurgency_id,
		"strength":            ins.strength,
		"roster_ready":        true,
	}
	match ins.insurgency_type:
		Enums.InsurgencyType.RONIN_BANDIT:
			base["seed_type"]  = RosterCompositionSystem.SEED_RONIN_BANDIT
			base["seed_label"] = "RONIN_BANDIT"
			base["options"]    = {"stability": int(province.stability)}
		Enums.InsurgencyType.PEASANT_REVOLT:
			base["seed_type"]  = RosterCompositionSystem.SEED_PEASANT_REVOLT
			base["seed_label"] = "PEASANT_REVOLT"
			base["options"]    = {}
		Enums.InsurgencyType.MAHO_CULT:
			base["seed_type"]  = RosterCompositionSystem.SEED_MAHO_CULT
			base["seed_label"] = "MAHO_CULT"
			base["options"]    = _maho_options(ins, province, bloodspeaker_cells)
		Enums.InsurgencyType.TAINT_MANIFESTATION:
			base["seed_type"]  = RosterCompositionSystem.SEED_TAINT_MANIFESTATION
			base["seed_label"] = "TAINT_MANIFESTATION"
			base["options"]    = {"ptl": province.province_taint_level}
		Enums.InsurgencyType.NEZUMI_INFESTATION:
			base["seed_type"]  = RosterCompositionSystem.SEED_NEZUMI_INFESTATION
			base["seed_label"] = "NEZUMI_INFESTATION"
			base["options"]    = {}
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			base["seed_type"]  = RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK
			base["seed_label"] = "URBAN_CRIMINAL_NETWORK"
			base["options"]    = {}
		_:
			return {}
	return base


static func _maho_options(
		ins: InsurgencyData,
		province: ProvinceData,
		bloodspeaker_cells: Array) -> Dictionary:
	var path: String = RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER  # default
	for cell in bloodspeaker_cells:
		if cell is BloodspeakerCellData and cell.insurgency_id == ins.insurgency_id:
			path = _PATH_MAP.get(cell.establishment_path, RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER)
			break
	# high_corpse_availability: PROVISIONAL — Broken stability tier (0-25) as
	# famine/battle province proxy. Actual starvation_stage not available on ProvinceData.
	var high_corpse: bool = province.stability <= STABILITY_BROKEN_THRESHOLD
	return {
		"establishment_path":       path,
		"seasons_active":           ins.seasons_active,
		"high_corpse_availability": high_corpse,
	}


## PTL >= 3 but no detected TAINT_MANIFESTATION insurgency in province.
## Strength derived PROVISIONALLY: floor(ptl / 3), minimum 1.
## GDD does not specify a formula for PTL-only (no insurgency) taint encounter strength.
static func _ptl_only_taint_seed(province: ProvinceData) -> Dictionary:
	var ptl: float = province.province_taint_level
	var strength: int = maxi(1, int(ptl / 3.0))
	return {
		"seed_type":             RosterCompositionSystem.SEED_TAINT_MANIFESTATION,
		"seed_label":            "TAINT_MANIFESTATION",
		"source":                "ptl_only",
		"strength":              strength,
		"options":               {"ptl": ptl},
		"source_insurgency_id":  -1,
		"roster_ready":          true,
	}


## Oni Manifestation — Named Oni boss encounter (s56.1.2).
## roster_ready = false: Named Oni stat blocks not yet in GDD s54.
static func _oni_seed_entry(source_insurgency_id: int) -> Dictionary:
	return {
		"seed_type":             SEED_ONI_MANIFESTATION,
		"seed_label":            "ONI_MANIFESTATION",
		"source":                "oni_manifestation",
		"strength":              10,
		"options":               {},
		"source_insurgency_id":  source_insurgency_id,
		"roster_ready":          false,
	}


## Spiritual overlap (s56.16). REALM_OVERLAP or ELEMENTAL_IMBALANCE carried in
## options.event_type (with realm/element). roster_ready = false: the encounter
## loop and spirit rosters are blocked on the larger s56.16 ASCII design — the
## seed exists to drive map generation + the SpiritualPalette depth gradient.
## strength = severity tier + 1 (1..4) — structural map-scale input, not a game value.
static func _spiritual_seed(ev: SpiritualInsurgencyData) -> Dictionary:
	var is_realm: bool = ev.event_type == Enums.SpiritualEventType.REALM_OVERLAP
	return {
		"seed_type":             SEED_SPIRITUAL_OVERLAP,
		"seed_label":            "REALM_OVERLAP" if is_realm else "ELEMENTAL_IMBALANCE",
		"source":                "spiritual_insurgency",
		"strength":              int(ev.severity) + 1,
		"options":               {
			"event_type": ev.event_type,
			"realm":      ev.realm,
			"element":    ev.element,
			"severity":   int(ev.severity),
		},
		"source_insurgency_id":  -1,
		"spiritual_event_id":    ev.event_id,
		"roster_ready":          false,
	}


static func _wall_sortie_seed(sortie_size_lower: String, ws: Dictionary) -> Dictionary:
	return {
		"seed_type":             RosterCompositionSystem.SEED_WALL_SORTIE,
		"seed_label":            "WALL_SORTIE",
		"source":                "wall_sortie",
		"strength":              ws.get("ss", 1),
		"options":               {"sortie_size": sortie_size_lower.to_upper()},
		"source_insurgency_id":  -1,
		"roster_ready":          true,
	}
