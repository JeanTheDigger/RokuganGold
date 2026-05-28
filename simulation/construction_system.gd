class_name ConstructionSystem
## Settlement creation, fortification building, shrine construction, and ship
## commissioning per GDD s4.3.22 and s57.20. Pure static functions.

# -- Costs (GDD s4.3.22) ------------------------------------------------------

const VILLAGE_KOKU_COST: float = 3.0
const VILLAGE_MIN_PU: float = 1.0
const VILLAGE_RICE_PER_PU: float = 1.0
const VILLAGE_BUILD_SEASONS: int = 1

const FORTIFICATION_KOKU_COST: float = 5.0
# GDD s4.3.22 does not specify fortification build time
const FORTIFICATION_BUILD_SEASONS: int = -1
const FORTIFICATION_MAX_RICE: float = 0.5
const FORTIFICATION_MIN_GARRISON: float = 0.5
const FORTIFICATION_DEFENSE_BONUS: int = 2

const SHRINE_COSTS: Dictionary = {
	ConstructionData.ConstructionType.SHRINE_ROADSIDE: {"general": 5.0, "dedicated": 12.0, "seasons": 1},
	ConstructionData.ConstructionType.SHRINE_VILLAGE: {"general": 15.0, "dedicated": 30.0, "seasons": 2},
	ConstructionData.ConstructionType.SHRINE_LOCAL: {"general": 30.0, "dedicated": 60.0, "seasons": 3},
}

const TEMPLE_KOKU_COST: float = 80.0
const TEMPLE_DEDICATED_KOKU_COST: float = 160.0
const TEMPLE_MIN_PU: float = 0.5
const TEMPLE_BUILD_SEASONS: int = 4

const SHINDEN_KOKU_COST: float = 250.0
const SHINDEN_DEDICATED_KOKU_COST: float = 400.0
const SHINDEN_MIN_PU: float = 1.0
const SHINDEN_BUILD_SEASONS: int = 8

const MONASTERY_KOKU_COST: float = 80.0
const MONASTERY_MIN_PU: float = 0.5
const MONASTERY_BUILD_SEASONS: int = 4

const SHIP_COSTS: Dictionary = {
	Enums.ShipClass.KOBUNE: 3.0,
	Enums.ShipClass.SENGOKOBUNE: 8.0,
}
const SHIP_BUILD_SEASONS: int = 1

const FORGE_KOKU_COST: float = 35.0
# GDD s4.3.10 does not specify forge build time
const FORGE_BUILD_SEASONS: int = -1

# -- Terrain Difficulty (GDD s4.3.22) -----------------------------------------

const TERRAIN_FOUNDING_DIFFICULTY: Dictionary = {
	Enums.TerrainType.PLAINS: 0,
	Enums.TerrainType.RIVER_DELTA: 0,
	Enums.TerrainType.FOREST: 1,
	Enums.TerrainType.HILLS: 2,
	Enums.TerrainType.MOUNTAINS: 3,
}

# -- Organic Formation Thresholds -----------------------------------------------
# DISABLED: GDD s4.3.22 does not specify surplus PU thresholds, stability minimum,
# or migrating PU amount for organic village formation.

const ORGANIC_SURPLUS_PU_THRESHOLD: Dictionary = {
	Enums.TerrainType.PLAINS: -1.0,
	Enums.TerrainType.RIVER_DELTA: -1.0,
	Enums.TerrainType.FOREST: -1.0,
	Enums.TerrainType.HILLS: -1.0,
	Enums.TerrainType.MOUNTAINS: -1.0,
}
const ORGANIC_MIN_STABILITY: float = -1.0
const ORGANIC_MIGRATING_PU: float = -1.0
const ORGANIC_RICE_PER_PU: float = 1.0

# -- Authority Tiers -----------------------------------------------------------

enum AuthorityLevel { PROVINCIAL_DAIMYO, FAMILY_DAIMYO, CLAN_CHAMPION }

const CONSTRUCTION_AUTHORITY: Dictionary = {
	ConstructionData.ConstructionType.VILLAGE: [AuthorityLevel.PROVINCIAL_DAIMYO],
	ConstructionData.ConstructionType.FORTIFICATION: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.SHRINE_ROADSIDE: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.SHRINE_VILLAGE: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.SHRINE_LOCAL: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.TEMPLE: [
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.SHINDEN: [
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.MONASTERY: [
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.SHIP: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
	ConstructionData.ConstructionType.FORGE: [
		AuthorityLevel.PROVINCIAL_DAIMYO,
		AuthorityLevel.FAMILY_DAIMYO,
		AuthorityLevel.CLAN_CHAMPION,
	],
}


# -- Validation ----------------------------------------------------------------


static func get_authority_level(character: L5RCharacterData) -> AuthorityLevel:
	if character.status >= 7.0:
		return AuthorityLevel.CLAN_CHAMPION
	if character.status >= 5.0:
		return AuthorityLevel.FAMILY_DAIMYO
	return AuthorityLevel.PROVINCIAL_DAIMYO


static func has_authority(
	construction_type: ConstructionData.ConstructionType,
	character: L5RCharacterData,
) -> bool:
	var level: AuthorityLevel = get_authority_level(character)
	var allowed: Array = CONSTRUCTION_AUTHORITY.get(construction_type, [])
	return level in allowed


static func validate_village_founding(
	character: L5RCharacterData,
	province: ProvinceData,
	settlements: Array,
) -> Dictionary:
	if not has_authority(ConstructionData.ConstructionType.VILLAGE, character):
		return {"valid": false, "reason": "insufficient_authority"}

	var total_pu: float = 0.0
	var total_koku: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total_pu += s.population_pu
			total_koku += s.koku_stockpile
	if total_pu < VILLAGE_MIN_PU:
		return {"valid": false, "reason": "insufficient_pu"}
	if total_koku < VILLAGE_KOKU_COST:
		return {"valid": false, "reason": "insufficient_koku"}

	var terrain_diff: int = TERRAIN_FOUNDING_DIFFICULTY.get(province.terrain_type, 3)
	if terrain_diff >= 3 and province.terrain_type == Enums.TerrainType.MOUNTAINS:
		var has_valley: bool = false
		for s: SettlementData in settlements:
			if s.province_id == province.province_id and s.settlement_type == Enums.SettlementType.VILLAGE:
				has_valley = true
				break
		if not has_valley:
			return {"valid": false, "reason": "no_suitable_terrain"}

	# GDD says "effectively impossible" for tainted terrain; using PTL > 0
	if province.province_taint_level > 0.0:
		return {"valid": false, "reason": "tainted_terrain"}

	return {"valid": true}


static func validate_fortification(
	character: L5RCharacterData,
	province: ProvinceData,
	settlements: Array,
) -> Dictionary:
	if not has_authority(ConstructionData.ConstructionType.FORTIFICATION, character):
		return {"valid": false, "reason": "insufficient_authority"}

	var total_koku: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total_koku += s.koku_stockpile
	if total_koku < FORTIFICATION_KOKU_COST:
		return {"valid": false, "reason": "insufficient_koku"}

	return {"valid": true}


static func validate_shrine(
	shrine_type: ConstructionData.ConstructionType,
	character: L5RCharacterData,
	settlement: SettlementData,
	is_dedicated: bool,
) -> Dictionary:
	if not has_authority(shrine_type, character):
		return {"valid": false, "reason": "insufficient_authority"}

	var cost_entry: Dictionary = SHRINE_COSTS.get(shrine_type, {})
	if cost_entry.is_empty():
		return {"valid": false, "reason": "invalid_shrine_type"}

	var cost: float = cost_entry["dedicated"] if is_dedicated else cost_entry["general"]
	if settlement.koku_stockpile < cost:
		return {"valid": false, "reason": "insufficient_koku"}

	return {"valid": true}


static func validate_temple(
	construction_type: ConstructionData.ConstructionType,
	character: L5RCharacterData,
	province: ProvinceData,
	settlements: Array,
	is_dedicated: bool,
) -> Dictionary:
	if not has_authority(construction_type, character):
		return {"valid": false, "reason": "insufficient_authority"}

	var koku_cost: float = 0.0
	var min_pu: float = 0.0
	match construction_type:
		ConstructionData.ConstructionType.TEMPLE:
			koku_cost = TEMPLE_DEDICATED_KOKU_COST if is_dedicated else TEMPLE_KOKU_COST
			min_pu = TEMPLE_MIN_PU
		ConstructionData.ConstructionType.SHINDEN:
			koku_cost = SHINDEN_DEDICATED_KOKU_COST if is_dedicated else SHINDEN_KOKU_COST
			min_pu = SHINDEN_MIN_PU
		ConstructionData.ConstructionType.MONASTERY:
			koku_cost = MONASTERY_KOKU_COST
			min_pu = MONASTERY_MIN_PU

	var total_koku: float = 0.0
	var total_pu: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total_koku += s.koku_stockpile
			total_pu += s.population_pu
	if total_koku < koku_cost:
		return {"valid": false, "reason": "insufficient_koku"}
	if total_pu < min_pu:
		return {"valid": false, "reason": "insufficient_pu"}

	return {"valid": true}


static func validate_ship_commission(
	character: L5RCharacterData,
	ship_class: Enums.ShipClass,
	settlement: SettlementData,
) -> Dictionary:
	if not has_authority(ConstructionData.ConstructionType.SHIP, character):
		return {"valid": false, "reason": "insufficient_authority"}

	var cost: float = SHIP_COSTS.get(ship_class, -1.0)
	if cost < 0.0:
		return {"valid": false, "reason": "invalid_ship_class"}
	if settlement.koku_stockpile < cost:
		return {"valid": false, "reason": "insufficient_koku"}

	if not settlement.has_infrastructure("shipyard"):
		return {"valid": false, "reason": "no_shipyard"}

	return {"valid": true}


static func validate_forge_construction(
	character: L5RCharacterData,
	settlement: SettlementData,
) -> Dictionary:
	if not has_authority(ConstructionData.ConstructionType.FORGE, character):
		return {"valid": false, "reason": "insufficient_authority"}
	if settlement.koku_stockpile < FORGE_KOKU_COST:
		return {"valid": false, "reason": "insufficient_koku"}
	return {"valid": true}


# -- Construction Queue --------------------------------------------------------


static func create_construction(
	construction_id: int,
	construction_type: ConstructionData.ConstructionType,
	lord_id: int,
	province_id: int,
	ic_day: int,
	koku: float = 0.0,
	pu: float = 0.0,
	rice: float = 0.0,
	settlement_id: int = -1,
	is_dedicated: bool = false,
	dedicated_fortune: int = -1,
	ship_class: int = -1,
) -> ConstructionData:
	var cd := ConstructionData.new()
	cd.construction_id = construction_id
	cd.construction_type = construction_type
	cd.ordering_lord_id = lord_id
	cd.province_id = province_id
	cd.settlement_id = settlement_id
	cd.koku_committed = koku
	cd.pu_committed = pu
	cd.rice_committed = rice
	cd.ic_day_started = ic_day
	cd.is_dedicated = is_dedicated
	cd.dedicated_fortune = dedicated_fortune
	cd.ship_class = ship_class

	var seasons: int = _get_build_seasons(construction_type)
	cd.seasons_remaining = seasons
	cd.seasons_total = seasons
	return cd


static func _get_build_seasons(ct: ConstructionData.ConstructionType) -> int:
	match ct:
		ConstructionData.ConstructionType.VILLAGE:
			return VILLAGE_BUILD_SEASONS
		ConstructionData.ConstructionType.FORTIFICATION:
			return FORTIFICATION_BUILD_SEASONS
		ConstructionData.ConstructionType.SHRINE_ROADSIDE:
			return int(SHRINE_COSTS[ConstructionData.ConstructionType.SHRINE_ROADSIDE]["seasons"])
		ConstructionData.ConstructionType.SHRINE_VILLAGE:
			return int(SHRINE_COSTS[ConstructionData.ConstructionType.SHRINE_VILLAGE]["seasons"])
		ConstructionData.ConstructionType.SHRINE_LOCAL:
			return int(SHRINE_COSTS[ConstructionData.ConstructionType.SHRINE_LOCAL]["seasons"])
		ConstructionData.ConstructionType.TEMPLE:
			return TEMPLE_BUILD_SEASONS
		ConstructionData.ConstructionType.SHINDEN:
			return SHINDEN_BUILD_SEASONS
		ConstructionData.ConstructionType.MONASTERY:
			return MONASTERY_BUILD_SEASONS
		ConstructionData.ConstructionType.SHIP:
			return SHIP_BUILD_SEASONS
		ConstructionData.ConstructionType.FORGE:
			return FORGE_BUILD_SEASONS
	return 1


static func tick_construction_queue(
	constructions: Array,
) -> Array:
	var completed: Array = []
	for cd: ConstructionData in constructions:
		if cd.is_complete:
			continue
		cd.seasons_remaining -= 1
		if cd.seasons_remaining <= 0:
			cd.is_complete = true
			completed.append(cd)
	return completed


# -- Settlement Factories ------------------------------------------------------


static func create_founded_village(
	settlement_id: int,
	province: ProvinceData,
	name: String,
	pu_moved: float,
	rice_moved: float,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = name
	s.province_id = province.province_id
	s.settlement_type = Enums.SettlementType.VILLAGE
	s.population_pu = int(pu_moved)
	s.farming_pu = int(pu_moved)
	s.rice_stockpile = rice_moved
	return s


static func create_fortification(
	settlement_id: int,
	province: ProvinceData,
	name: String,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = name
	s.province_id = province.province_id
	s.settlement_type = Enums.SettlementType.FORTIFICATION
	s.rice_stockpile = FORTIFICATION_MAX_RICE
	return s


static func create_temple(
	settlement_id: int,
	province: ProvinceData,
	name: String,
	pu_moved: float,
	is_dedicated: bool,
	dedicated_fortune: int,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = name
	s.province_id = province.province_id
	s.settlement_type = Enums.SettlementType.TEMPLE
	s.population_pu = int(pu_moved)
	if is_dedicated:
		s.worship_locations = [{"type": "temple", "dedicated": true, "fortune": dedicated_fortune}]
	else:
		s.worship_locations = [{"type": "temple", "dedicated": false, "fortune": -1}]
	return s


static func create_shinden(
	settlement_id: int,
	province: ProvinceData,
	name: String,
	pu_moved: float,
	is_dedicated: bool,
	dedicated_fortune: int,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = name
	s.province_id = province.province_id
	s.settlement_type = Enums.SettlementType.SHINDEN
	s.population_pu = int(pu_moved)
	if is_dedicated:
		s.worship_locations = [{"type": "shinden", "dedicated": true, "fortune": dedicated_fortune}]
	else:
		s.worship_locations = [{"type": "shinden", "dedicated": false, "fortune": -1}]
	return s


static func create_monastery(
	settlement_id: int,
	province: ProvinceData,
	name: String,
	pu_moved: float,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = name
	s.province_id = province.province_id
	s.settlement_type = Enums.SettlementType.MONASTERY
	s.population_pu = int(pu_moved)
	return s


static func add_shrine_to_settlement(
	settlement: SettlementData,
	shrine_type: String,
	is_dedicated: bool,
	dedicated_fortune: int,
) -> void:
	settlement.worship_locations.append({
		"type": shrine_type,
		"dedicated": is_dedicated,
		"fortune": dedicated_fortune,
	})


# -- Resource Deduction --------------------------------------------------------


static func deduct_village_resources(
	settlements: Array,
	province_id: int,
	pu_to_move: float,
	koku_cost: float,
) -> Dictionary:
	var pu_moved: float = 0.0
	var rice_moved: float = 0.0
	var koku_deducted: float = 0.0

	for s: SettlementData in settlements:
		if s.province_id != province_id:
			continue
		if koku_deducted < koku_cost:
			var take: float = minf(s.koku_stockpile, koku_cost - koku_deducted)
			s.koku_stockpile -= take
			koku_deducted += take
		if pu_moved < pu_to_move:
			var take_pu: float = minf(float(s.population_pu), pu_to_move - pu_moved)
			var take_rice: float = take_pu * VILLAGE_RICE_PER_PU
			take_rice = minf(take_rice, s.rice_stockpile)
			s.population_pu -= int(take_pu)
			s.farming_pu = maxi(0, s.farming_pu - int(take_pu))
			s.rice_stockpile -= take_rice
			pu_moved += take_pu
			rice_moved += take_rice

	return {"pu_moved": pu_moved, "rice_moved": rice_moved, "koku_deducted": koku_deducted}


static func deduct_koku(
	settlements: Array,
	province_id: int,
	amount: float,
) -> float:
	var deducted: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id != province_id:
			continue
		if deducted >= amount:
			break
		var take: float = minf(s.koku_stockpile, amount - deducted)
		s.koku_stockpile -= take
		deducted += take
	return deducted


static func deduct_pu(
	settlements: Array,
	province_id: int,
	amount: float,
) -> float:
	var deducted: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id != province_id:
			continue
		if deducted >= amount:
			break
		var take: float = minf(float(s.population_pu), amount - deducted)
		s.population_pu -= int(take)
		deducted += take
	return deducted


# -- Organic Village Formation -------------------------------------------------


static func check_organic_formation(
	province: ProvinceData,
	settlements: Array,
) -> Dictionary:
	# DISABLED: GDD s4.3.22 does not specify numeric thresholds for organic formation
	if ORGANIC_MIN_STABILITY < 0.0 or ORGANIC_MIGRATING_PU < 0.0:
		return {"eligible": false, "reason": "disabled_pending_gdd_spec"}

	if province.stability < ORGANIC_MIN_STABILITY:
		return {"eligible": false, "reason": "low_stability"}

	# GDD says "effectively impossible" for tainted terrain; using PTL > 0
	if province.province_taint_level > 0.0:
		return {"eligible": false, "reason": "tainted"}

	var threshold: float = ORGANIC_SURPLUS_PU_THRESHOLD.get(province.terrain_type, -1.0)
	if threshold < 0.0:
		return {"eligible": false, "reason": "disabled_pending_gdd_spec"}

	var total_pu: float = 0.0
	var healthy: bool = true
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		total_pu += s.population_pu
		if s.rice_stockpile <= 0.0:
			healthy = false

	if not healthy:
		return {"eligible": false, "reason": "settlements_starving"}

	var surplus: float = total_pu - threshold
	if surplus < ORGANIC_MIGRATING_PU:
		return {"eligible": false, "reason": "insufficient_surplus"}

	return {"eligible": true, "surplus_pu": surplus}


static func process_organic_formation(
	province: ProvinceData,
	settlements: Array,
	next_settlement_id: int,
) -> Dictionary:
	var check: Dictionary = check_organic_formation(province, settlements)
	if not check.get("eligible", false):
		return {"formed": false}

	var pu_to_move: float = ORGANIC_MIGRATING_PU
	var rice_to_move: float = pu_to_move * ORGANIC_RICE_PER_PU

	var actual_rice: float = 0.0
	var actual_pu: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		if actual_pu >= pu_to_move:
			break
		var take_pu: float = minf(float(s.population_pu), pu_to_move - actual_pu)
		if take_pu <= 0.0:
			continue
		var take_rice: float = minf(take_pu * ORGANIC_RICE_PER_PU, s.rice_stockpile)
		s.population_pu -= int(take_pu)
		s.farming_pu = maxi(0, s.farming_pu - int(take_pu))
		s.rice_stockpile -= take_rice
		actual_pu += take_pu
		actual_rice += take_rice

	if actual_pu < ORGANIC_MIGRATING_PU:
		return {"formed": false, "reason": "insufficient_pu_after_deduction"}

	var village: SettlementData = create_founded_village(
		next_settlement_id, province,
		province.province_name + " Hamlet",
		actual_pu, actual_rice,
	)

	return {"formed": true, "settlement": village}


# -- Shrine Type Mapping -------------------------------------------------------

const SHRINE_TYPE_NAMES: Dictionary = {
	ConstructionData.ConstructionType.SHRINE_ROADSIDE: "roadside_shrine",
	ConstructionData.ConstructionType.SHRINE_VILLAGE: "village_shrine",
	ConstructionData.ConstructionType.SHRINE_LOCAL: "local_shrine",
}
