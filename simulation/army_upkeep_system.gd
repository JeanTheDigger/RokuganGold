class_name ArmyUpkeepSystem
## Army upkeep costs, iron degradation, and field deprivation per GDD s4.3 / s11.7.
## Pure static functions. Caller owns all state dictionaries.


# -- Rice Upkeep -----------------------------------------------------------------

const RICE_PER_MILITARY_PU_PER_SEASON: float = 0.35


# -- Iron Upkeep (per unit per season) -------------------------------------------

const UNIT_IRON_UPKEEP: Dictionary = {
	Enums.CompanyUnitType.PEASANT_LEVY: 0.03,
	Enums.CompanyUnitType.ASHIGARU_SPEARMEN: 0.10,
	Enums.CompanyUnitType.ASHIGARU_ARCHERS: 0.10,
	Enums.CompanyUnitType.BUSHI_RETAINER: 0.20,
	Enums.CompanyUnitType.LIGHT_CAVALRY: 0.20,
	Enums.CompanyUnitType.RONIN: 0.00,
	Enums.CompanyUnitType.GARRISON: 0.10,
}

const TIER_IRON_UPKEEP: Dictionary = {1: 0.25, 2: 0.35, 3: 0.50}


# -- Arms Equip Cost (one-time) --------------------------------------------------

const UNIT_ARMS_EQUIP: Dictionary = {
	Enums.CompanyUnitType.PEASANT_LEVY: 0.25,
	Enums.CompanyUnitType.ASHIGARU_SPEARMEN: 1.00,
	Enums.CompanyUnitType.ASHIGARU_ARCHERS: 1.00,
	Enums.CompanyUnitType.BUSHI_RETAINER: 2.00,
	Enums.CompanyUnitType.LIGHT_CAVALRY: 2.00,
	Enums.CompanyUnitType.RONIN: 0.00,
	Enums.CompanyUnitType.GARRISON: 0.75,
}

const TIER_ARMS_EQUIP: Dictionary = {1: 2.50, 2: 3.50, 3: 5.00}


# -- Koku Costs ------------------------------------------------------------------

const GARRISON_KOKU_PER_PU_PER_SEASON: float = 0.20
const RONIN_HIRE_KOKU: float = 2.00
const RONIN_UPKEEP_KOKU_PER_MONTH: float = 0.50


# -- Clan Elite Cost Tier Mapping ------------------------------------------------

const CLAN_ELITE_COST_TIER: Dictionary = {
	# Crab
	Enums.CompanyUnitType.HIDA_BUSHI: 1,
	Enums.CompanyUnitType.HIRUMA_SCOUTS: 2,
	Enums.CompanyUnitType.CRAB_BERSERKERS: 3,
	# Crane
	Enums.CompanyUnitType.KAKITA_BUSHI: 1,
	Enums.CompanyUnitType.DAIDOJI_HEAVY_SPEARMEN: 2,
	Enums.CompanyUnitType.KENSHINZEN: 3,
	# Dragon
	Enums.CompanyUnitType.MIRUMOTO_BUSHI: 1,
	Enums.CompanyUnitType.DRAGON_TALONS: 2,
	Enums.CompanyUnitType.YAMABUSHI: 2,
	# Lion
	Enums.CompanyUnitType.AKODO_BUSHI: 1,
	Enums.CompanyUnitType.DEATHSEEKERS: 2,
	Enums.CompanyUnitType.LIONS_PRIDE: 3,
	# Phoenix
	Enums.CompanyUnitType.SHIBA_BUSHI: 1,
	Enums.CompanyUnitType.ELEMENTAL_LEGIONS: 2,
	Enums.CompanyUnitType.ELEMENTAL_GUARD: 3,
	# Scorpion
	Enums.CompanyUnitType.BAYUSHI_BUSHI: 1,
	Enums.CompanyUnitType.BLACK_CABAL: 2,
	Enums.CompanyUnitType.SCORPIONS_CLAWS: 2,
	# Unicorn
	Enums.CompanyUnitType.SHINJO_BUSHI: 1,
	Enums.CompanyUnitType.WHITE_GUARD: 2,
	Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS: 3,
	# Mantis
	Enums.CompanyUnitType.YORITOMO_BUSHI: 1,
	Enums.CompanyUnitType.STORM_RIDERS: 2,
	Enums.CompanyUnitType.STORM_LEGION: 2,
}


# -- Iron Upkeep Failure Penalties (s4.3) ----------------------------------------

const IRON_FAILURE_PENALTIES: Dictionary = {
	1: {"attack": -2, "defense": -2, "morale": -4, "morale_defense": -2},
	2: {"attack": -4, "defense": -4, "morale": -8, "morale_defense": -4},
}


# -- Field Deprivation Tables (s11.7) -------------------------------------------

const RICE_DEPRIVATION: Dictionary = {
	1: {"morale": 0, "health": 0},
	2: {"morale": -3, "health": 0},
	3: {"morale": -3, "health": -5},
	4: {"morale": -5, "health": -10},
}

const ARMS_DEPRIVATION: Dictionary = {
	1: {"attack": 0, "defense": 0},
	2: {"attack": -2, "defense": -2},
	3: {"attack": -4, "defense": -4},
	4: {"attack": -6, "defense": -6},
}

const RECOVERY_HEALTH_PER_TICK: int = 5
const RECOVERY_MORALE_PER_TICK: int = 3


# -- Cost Query Functions --------------------------------------------------------

static func get_iron_upkeep(unit_type: Enums.CompanyUnitType) -> float:
	if UNIT_IRON_UPKEEP.has(unit_type):
		return UNIT_IRON_UPKEEP[unit_type]
	var tier: int = CLAN_ELITE_COST_TIER.get(unit_type, 1)
	return TIER_IRON_UPKEEP.get(tier, 0.25)


static func get_arms_equip_cost(unit_type: Enums.CompanyUnitType) -> float:
	if UNIT_ARMS_EQUIP.has(unit_type):
		return UNIT_ARMS_EQUIP[unit_type]
	var tier: int = CLAN_ELITE_COST_TIER.get(unit_type, 1)
	return TIER_ARMS_EQUIP.get(tier, 2.50)


static func get_cost_tier(unit_type: Enums.CompanyUnitType) -> int:
	return CLAN_ELITE_COST_TIER.get(unit_type, 0)


static func compute_company_seasonal_costs(
	unit_type: Enums.CompanyUnitType,
) -> Dictionary:
	var iron: float = get_iron_upkeep(unit_type)
	var koku: float = 0.0
	if unit_type == Enums.CompanyUnitType.GARRISON:
		koku = GARRISON_KOKU_PER_PU_PER_SEASON
	elif unit_type == Enums.CompanyUnitType.RONIN:
		koku = RONIN_UPKEEP_KOKU_PER_MONTH * 3.0
	return {
		"rice": RICE_PER_MILITARY_PU_PER_SEASON,
		"iron": iron,
		"koku": koku,
	}


static func compute_army_seasonal_costs(
	companies: Array,
) -> Dictionary:
	var total_rice: float = 0.0
	var total_iron: float = 0.0
	var total_koku: float = 0.0
	for c: MilitaryUnitData.CompanyData in companies:
		var costs: Dictionary = compute_company_seasonal_costs(c.unit_type)
		total_rice += costs["rice"]
		total_iron += costs["iron"]
		total_koku += costs["koku"]
	return {"rice": total_rice, "iron": total_iron, "koku": total_koku}


# -- Iron Upkeep Failure ---------------------------------------------------------

static func get_iron_failure_penalties(seasons_without_iron: int) -> Dictionary:
	if seasons_without_iron <= 0:
		return {"attack": 0, "defense": 0, "morale": 0, "morale_defense": 0}
	var key: int = mini(seasons_without_iron, 2)
	return IRON_FAILURE_PENALTIES[key].duplicate()


static func apply_iron_failure(
	company: MilitaryUnitData.CompanyData,
	seasons_without_iron: int,
) -> Dictionary:
	var base: Dictionary = ArmyCombatSystem.UNIT_STATS.get(company.unit_type, {})
	if base.is_empty():
		return {"attack": 0, "defense": 0, "morale": 0, "morale_defense": 0}

	var penalties: Dictionary = get_iron_failure_penalties(seasons_without_iron)
	company.attack = maxi(base["attack"] + penalties["attack"], 0)
	company.defense = maxi(base["defense"] + penalties["defense"], 0)
	company.morale = maxi(base["morale"] + penalties["morale"], 0)
	company.morale_defense = maxi(base["morale_defense"] + penalties["morale_defense"], 0)
	return penalties


static func process_iron_upkeep(
	companies: Array,
	iron_state: Dictionary,
	clan_iron_available: float,
) -> Dictionary:
	var total_needed: float = 0.0
	for c: MilitaryUnitData.CompanyData in companies:
		total_needed += get_iron_upkeep(c.unit_type)

	var supplied: bool = clan_iron_available >= total_needed
	var iron_consumed: float = minf(clan_iron_available, total_needed)
	var degraded: Array = []

	for c: MilitaryUnitData.CompanyData in companies:
		var cid: int = c.company_id
		if not iron_state.has(cid):
			iron_state[cid] = 0

		if supplied:
			if iron_state[cid] > 0:
				iron_state[cid] = 0
				apply_iron_failure(c, 0)
		else:
			iron_state[cid] += 1
			apply_iron_failure(c, iron_state[cid])
			degraded.append(cid)

	return {
		"iron_consumed": iron_consumed,
		"iron_needed": total_needed,
		"supplied": supplied,
		"degraded_companies": degraded,
	}


static func apply_iron_failure_to_dict(
	company: Dictionary,
	seasons_without_iron: int,
) -> Dictionary:
	var unit_type: int = company.get("unit_type", Enums.CompanyUnitType.ASHIGARU_SPEARMEN)
	var base: Dictionary = ArmyCombatSystem.UNIT_STATS.get(unit_type, {})
	if base.is_empty():
		return {"attack": 0, "defense": 0, "morale": 0, "morale_defense": 0}
	var penalties: Dictionary = get_iron_failure_penalties(seasons_without_iron)
	company["attack"] = maxi(base.get("attack", 0) + penalties["attack"], 0)
	company["defense"] = maxi(base.get("defense", 0) + penalties["defense"], 0)
	company["morale"] = maxi(base.get("morale", 0) + penalties["morale"], 0)
	company["morale_defense"] = maxi(base.get("morale_defense", 0) + penalties["morale_defense"], 0)
	return penalties


static func process_iron_upkeep_dict(
	companies: Array,
	iron_state: Dictionary,
	clan_iron_available: float,
) -> Dictionary:
	var total_needed: float = 0.0
	for c: Dictionary in companies:
		total_needed += get_iron_upkeep(c.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY))

	var supplied: bool = clan_iron_available >= total_needed
	var iron_consumed: float = minf(clan_iron_available, total_needed)
	var degraded: Array = []

	for c: Dictionary in companies:
		var cid: int = c.get("company_id", -1)
		if not iron_state.has(cid):
			iron_state[cid] = 0

		if supplied:
			if iron_state[cid] > 0:
				iron_state[cid] = 0
				apply_iron_failure_to_dict(c, 0)  # reset stats to base
		else:
			iron_state[cid] += 1
			apply_iron_failure_to_dict(c, iron_state[cid])
			degraded.append(cid)

	return {
		"iron_consumed": iron_consumed,
		"iron_needed": total_needed,
		"supplied": supplied,
		"degraded_companies": degraded,
	}


# -- Field Deprivation -----------------------------------------------------------

static func get_rice_deprivation_effect(tick: int) -> Dictionary:
	var key: int = clampi(tick, 1, 4)
	return RICE_DEPRIVATION[key].duplicate()


static func get_arms_deprivation_effect(tick: int) -> Dictionary:
	var key: int = clampi(tick, 1, 4)
	return ARMS_DEPRIVATION[key].duplicate()


static func apply_rice_deprivation_tick(
	company: MilitaryUnitData.CompanyData,
	tick: int,
) -> Dictionary:
	var effect: Dictionary = get_rice_deprivation_effect(tick)
	var morale_lost: int = 0
	var health_lost: int = 0

	if effect["morale"] < 0:
		morale_lost = absi(effect["morale"])
		company.morale = maxi(company.morale - morale_lost, 0)
	if effect["health"] < 0:
		health_lost = absi(effect["health"])
		company.health = maxi(company.health - health_lost, 0)

	return {
		"morale_lost": morale_lost,
		"health_lost": health_lost,
		"warning_only": tick <= 1,
	}


static func apply_arms_deprivation(
	company: MilitaryUnitData.CompanyData,
	tick: int,
) -> Dictionary:
	var base: Dictionary = ArmyCombatSystem.UNIT_STATS.get(company.unit_type, {})
	if base.is_empty():
		return {"attack_penalty": 0, "defense_penalty": 0, "warning_only": true}

	var effect: Dictionary = get_arms_deprivation_effect(tick)
	var iron_delta_atk: int = company.attack - base["attack"]
	var iron_delta_def: int = company.defense - base["defense"]
	company.attack = maxi(base["attack"] + mini(iron_delta_atk, 0) + effect["attack"], 0)
	company.defense = maxi(base["defense"] + mini(iron_delta_def, 0) + effect["defense"], 0)

	return {
		"attack_penalty": effect["attack"],
		"defense_penalty": effect["defense"],
		"warning_only": tick <= 1,
	}


static func process_deprivation_tick(
	companies: Array,
	dep_state: Dictionary,
) -> Dictionary:
	var results: Array = []

	for c: MilitaryUnitData.CompanyData in companies:
		var cid: int = c.company_id
		if not dep_state.has(cid):
			dep_state[cid] = {
				"rice_tick": 0,
				"arms_tick": 0,
				"rice_supplied": true,
				"arms_supplied": true,
			}

		var s: Dictionary = dep_state[cid]

		if s["rice_supplied"]:
			if s["rice_tick"] > 0:
				s["rice_tick"] = 1
		else:
			s["rice_tick"] += 1

		if s["arms_supplied"]:
			if s["arms_tick"] > 0:
				s["arms_tick"] = 1
		else:
			s["arms_tick"] += 1

		var rice_result: Dictionary = {}
		var arms_result: Dictionary = {}

		if s["rice_tick"] > 0:
			rice_result = apply_rice_deprivation_tick(c, s["rice_tick"])
		if s["arms_tick"] > 0:
			arms_result = apply_arms_deprivation(c, s["arms_tick"])

		results.append({
			"company_id": cid,
			"rice_tick": s["rice_tick"],
			"arms_tick": s["arms_tick"],
			"rice_result": rice_result,
			"arms_result": arms_result,
		})

	return {"results": results}


# -- Recovery (stationary + supplied) --------------------------------------------

static func apply_recovery_tick(
	company: MilitaryUnitData.CompanyData,
	is_stationary: bool,
	rice_supplied: bool,
	arms_supplied: bool,
	arms_deprivation_tick: int,
) -> Dictionary:
	if not is_stationary:
		return {
			"health_recovered": 0,
			"morale_recovered": 0,
			"arms_tier_recovered": false,
		}

	var base: Dictionary = ArmyCombatSystem.UNIT_STATS.get(company.unit_type, {})
	var health_recovered: int = 0
	var morale_recovered: int = 0
	var arms_recovered: bool = false

	if rice_supplied and not base.is_empty():
		var max_health: int = base["health"]
		var old_health: int = company.health
		company.health = mini(company.health + RECOVERY_HEALTH_PER_TICK, max_health)
		health_recovered = company.health - old_health

		var max_morale: int = base["morale"]
		var old_morale: int = company.morale
		company.morale = mini(company.morale + RECOVERY_MORALE_PER_TICK, max_morale)
		morale_recovered = company.morale - old_morale

	if arms_supplied and arms_deprivation_tick > 1:
		var new_tick: int = maxi(arms_deprivation_tick - 1, 1)
		apply_arms_deprivation(company, new_tick)
		arms_recovered = true

	return {
		"health_recovered": health_recovered,
		"morale_recovered": morale_recovered,
		"arms_tier_recovered": arms_recovered,
	}
