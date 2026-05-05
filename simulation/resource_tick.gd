class_name ResourceTick
## Seasonal and monthly resource processing per GDD s4.3.
## Handles Rice production/consumption, Koku generation, Iron production,
## tax cascade, starvation, and population dynamics.

# -- Constants per GDD s4.3.3 (Core Equation) ---------------------------------

const RICE_CONSUMPTION_PER_PU_PER_SEASON: float = 0.25
const MILITARY_RICE_SURCHARGE: float = 0.10
const MILITARY_RICE_PER_PU_PER_SEASON: float = 0.35
const RICE_YIELD_PER_FARMING_PU_PER_YEAR: float = 1.50
const SUBSISTENCE_FLOOR_PER_PU: float = 1.00
const KOKU_PER_TOWN_PU_PER_SEASON: float = 0.25
const IRON_PER_MINING_PU_PER_SEASON: float = 0.50

# -- Tax Cascade Rates per GDD s4.3.7 -----------------------------------------

const TAX_RATES: Dictionary = {
	"local_daimyo": 0.40,
	"provincial_daimyo": 0.30,
	"family_daimyo": 0.25,
	"clan_champion": 0.20,
	"emperor": 0.15,
}

# -- Stipend Cascade Rates per GDD s4.3.9 -------------------------------------

const STIPEND_RETENTION: Dictionary = {
	"clan_champion": 0.40,
	"family_daimyo": 0.25,
	"provincial_daimyo": 0.20,
	"local_daimyo": 0.15,
}

# -- Population Growth per GDD s4.3.6 -----------------------------------------

const BASELINE_GROWTH_ANNUAL: float = 0.05
const MODEST_STOCKPILE_GROWTH_ANNUAL: float = 0.07
const STRONG_STOCKPILE_GROWTH_ANNUAL: float = 0.10
const PEACE_BONUS_ANNUAL: float = 0.03
const MODEST_STOCKPILE_THRESHOLD: float = 1.00
const STRONG_STOCKPILE_THRESHOLD: float = 2.00
const PEACE_SEASONS_REQUIRED: int = 4

# -- Starvation per GDD s4.3.6 ------------------------------------------------

enum StarvationStage { CLEAR, SHORTAGE, HUNGER, FAMINE }

const STARVATION_PU_LOSS: Dictionary = {
	StarvationStage.CLEAR: 0.0,
	StarvationStage.SHORTAGE: 0.03,
	StarvationStage.HUNGER: 0.08,
	StarvationStage.FAMINE: 0.20,
}

# -- Personality Tax Modifiers per GDD s4.3.7 ---------------------------------

const BUSHIDO_TAX_MODIFIERS: Dictionary = {
	"JIN": -0.10,
	"YU": 0.0,
	"REI": 0.0,
	"CHUGI": 0.05,
	"GI": 0.0,
	"MEIYO": -0.05,
	"MAKOTO": 0.0,
}

const SHOURIDO_TAX_MODIFIERS: Dictionary = {
	"SEIGYO": 0.05,
	"KETSUI": 0.0,
	"DOSATSU": 0.0,
	"CHISHIKI": 0.0,
	"KANPEKI": 0.0,
	"KYORYOKU": 0.10,
	"ISHI": 0.05,
}

# -- Tax Stability Effects per GDD s4.3.7 -------------------------------------

const TAX_STABILITY_EFFECTS: Dictionary = {
	0.15: -3.0,
	0.10: -2.0,
	0.05: -1.0,
	0.0: 0.0,
	-0.05: 1.0,
	-0.10: 2.0,
}

# -- Koku Location Modifiers per GDD s4.3.8 -----------------------------------

const KOKU_LOCATION_MODIFIERS: Dictionary = {
	"castle_town": 1.2,
	"crossroads": 1.3,
	"coastal": 1.3,
	"port_city": 1.5,
	"river_town": 1.2,
	"remote": 0.7,
	"conflict_zone": 0.5,
	"bandit_infested": 0.8,
}

# -- Months per Season per GDD s4.3.2 -----------------------------------------

const MONTHS_PER_SEASON: Dictionary = {
	"spring": 3,
	"summer": 3,
	"autumn": 2,
	"winter": 4,
}


# ==============================================================================
# Seasonal Tick Entry Point
# ==============================================================================

static func process_seasonal_tick(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	season: String,
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {
		"rice_consumed": {},
		"starvation_changes": {},
		"population_changes": {},
		"iron_produced": {},
		"koku_generated": {},
		"harvest": {},
		"tax_collected": {},
	}

	if season == "spring":
		_lock_planting(provinces, settlement_meta)

	if season == "autumn":
		var harvest: Dictionary = _process_harvest(provinces, settlement_meta)
		results["harvest"] = harvest

	var consumption: Dictionary = _process_rice_consumption(settlements, settlement_meta)
	results["rice_consumed"] = consumption

	var starvation: Dictionary = _process_starvation_check(settlements, settlement_meta)
	results["starvation_changes"] = starvation

	if season == "autumn":
		var taxes: Dictionary = _process_tax_cascade(provinces, settlement_meta)
		results["tax_collected"] = taxes

	var pop_changes: Dictionary = _process_population_adjustment(settlements, settlement_meta)
	results["population_changes"] = pop_changes

	var iron: Dictionary = _process_iron_production(provinces, settlement_meta)
	results["iron_produced"] = iron

	var koku: Dictionary = _process_koku_generation(settlements, settlement_meta)
	results["koku_generated"] = koku

	return results


# ==============================================================================
# Spring Planting — Locks farming PU for Autumn harvest ceiling
# ==============================================================================

static func _lock_planting(
	provinces: Array[ProvinceData],
	settlement_meta: Dictionary,
) -> void:
	for prov: ProvinceData in provinces:
		var farming: float = float(prov.farming_pu)
		settlement_meta[prov.province_id] = settlement_meta.get(prov.province_id, {})
		settlement_meta[prov.province_id]["locked_farming_pu"] = farming


# ==============================================================================
# Autumn Harvest — farming PU locked at spring × 1.50 × terrain modifier
# ==============================================================================

static func _process_harvest(
	provinces: Array[ProvinceData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var harvest_results: Dictionary = {}
	for prov: ProvinceData in provinces:
		var meta: Dictionary = settlement_meta.get(prov.province_id, {})
		var locked_farming: float = float(meta.get("locked_farming_pu", prov.farming_pu))
		var terrain_mult: float = prov.get_rice_multiplier()
		var yield_amount: float = locked_farming * RICE_YIELD_PER_FARMING_PU_PER_YEAR * terrain_mult
		prov.rice_stockpile += yield_amount
		harvest_results[prov.province_id] = {
			"farming_pu": locked_farming,
			"terrain_mult": terrain_mult,
			"yield": yield_amount,
		}
	return harvest_results


# ==============================================================================
# Rice Consumption — 0.25 per civilian PU, 0.35 per military PU per season
# ==============================================================================

static func _process_rice_consumption(
	_settlements: Array[SettlementData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func consume_rice_province(province: ProvinceData) -> Dictionary:
	var civilian_pu: int = province.farming_pu + province.mining_pu + province.town_pu
	var military_pu: int = province.military_pu
	var civilian_cost: float = float(civilian_pu) * RICE_CONSUMPTION_PER_PU_PER_SEASON
	var military_cost: float = float(military_pu) * MILITARY_RICE_PER_PU_PER_SEASON
	var total_cost: float = civilian_cost + military_cost
	var old_stockpile: float = province.rice_stockpile
	province.rice_stockpile = maxf(0.0, province.rice_stockpile - total_cost)
	var deficit: float = maxf(0.0, total_cost - old_stockpile)
	return {
		"civilian_cost": civilian_cost,
		"military_cost": military_cost,
		"total_cost": total_cost,
		"deficit": deficit,
		"stockpile_after": province.rice_stockpile,
	}


# ==============================================================================
# Starvation Check — Deficit triggers escalation per s4.3.6
# ==============================================================================

static func _process_starvation_check(
	_settlements: Array[SettlementData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func check_starvation(
	province: ProvinceData,
	deficit: float,
	consecutive_deficit_seasons: int,
) -> Dictionary:
	if deficit <= 0.0:
		return {"stage": StarvationStage.CLEAR, "pu_loss_rate": 0.0}

	var stage: StarvationStage
	if province.rice_stockpile <= 0.0 and deficit > 0.0:
		stage = StarvationStage.FAMINE
	elif consecutive_deficit_seasons >= 3:
		stage = StarvationStage.FAMINE
	elif consecutive_deficit_seasons >= 2:
		stage = StarvationStage.HUNGER
	else:
		stage = StarvationStage.SHORTAGE

	var loss_rate: float = STARVATION_PU_LOSS[stage]
	return {"stage": stage, "pu_loss_rate": loss_rate}


static func apply_starvation_loss(province: ProvinceData, loss_rate: float) -> Dictionary:
	var total_pu: int = province.population_pu
	var loss: float = float(total_pu) * loss_rate
	var lost_pu: int = int(loss)
	if lost_pu > 0 and province.farming_pu > 0:
		var farming_loss: int = mini(lost_pu, province.farming_pu)
		province.farming_pu -= farming_loss
		lost_pu -= farming_loss
	if lost_pu > 0 and province.town_pu > 0:
		var town_loss: int = mini(lost_pu, province.town_pu)
		province.town_pu -= town_loss
		lost_pu -= town_loss
	province.population_pu = province.farming_pu + province.mining_pu + province.town_pu + province.military_pu
	return {"total_lost": int(loss), "remaining_pu": province.population_pu}


# ==============================================================================
# Tax Cascade — s4.3.7
# ==============================================================================

static func compute_tax_modifier(
	bushido_virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
) -> float:
	var modifier: float = 0.0
	if bushido_virtue != Enums.BushidoVirtue.NONE:
		var name: String = Enums.bushido_virtue_name(bushido_virtue)
		modifier += BUSHIDO_TAX_MODIFIERS.get(name, 0.0)
	if shourido_virtue != Enums.ShouridoVirtue.NONE:
		var name: String = Enums.shourido_virtue_name(shourido_virtue)
		modifier += SHOURIDO_TAX_MODIFIERS.get(name, 0.0)
	return clampf(modifier, -0.15, 0.15)


static func compute_taxable_surplus(province: ProvinceData, autumn_yield: float) -> float:
	var subsistence: float = float(province.population_pu) * SUBSISTENCE_FLOOR_PER_PU
	return maxf(0.0, autumn_yield - subsistence)


static func _process_tax_cascade(
	_provinces: Array[ProvinceData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func apply_tax_at_tier(
	surplus_arriving: float,
	tier: String,
	tax_personality_modifier: float,
) -> Dictionary:
	var base_rate: float = TAX_RATES.get(tier, 0.0)
	var effective_rate: float = clampf(base_rate + tax_personality_modifier, 0.0, 1.0)
	var collected: float = surplus_arriving * effective_rate
	var passed_up: float = surplus_arriving - collected
	return {
		"collected": collected,
		"passed_up": passed_up,
		"effective_rate": effective_rate,
	}


# ==============================================================================
# Population Growth — s4.3.6
# ==============================================================================

static func _process_population_adjustment(
	_settlements: Array[SettlementData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func compute_growth_rate(
	province: ProvinceData,
	starvation_stage: StarvationStage,
	peace_seasons: int,
) -> float:
	if starvation_stage != StarvationStage.CLEAR:
		return 0.0

	var rice_per_pu: float = 0.0
	if province.population_pu > 0:
		rice_per_pu = province.rice_stockpile / float(province.population_pu)

	var annual_rate: float = BASELINE_GROWTH_ANNUAL
	if rice_per_pu >= STRONG_STOCKPILE_THRESHOLD:
		annual_rate = STRONG_STOCKPILE_GROWTH_ANNUAL
	elif rice_per_pu >= MODEST_STOCKPILE_THRESHOLD:
		annual_rate = MODEST_STOCKPILE_GROWTH_ANNUAL

	if peace_seasons >= PEACE_SEASONS_REQUIRED:
		annual_rate += PEACE_BONUS_ANNUAL

	return annual_rate / 4.0


static func apply_population_growth(province: ProvinceData, seasonal_rate: float) -> Dictionary:
	if seasonal_rate <= 0.0:
		return {"growth": 0, "new_total": province.population_pu}
	var growth: float = float(province.farming_pu) * seasonal_rate
	var growth_pu: int = int(growth)
	if growth_pu > 0:
		province.farming_pu += growth_pu
		province.population_pu += growth_pu
	return {"growth": growth_pu, "new_total": province.population_pu}


# ==============================================================================
# Iron Production — 0.50 per mining PU per season
# ==============================================================================

static func _process_iron_production(
	_provinces: Array[ProvinceData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func produce_iron_province(province: ProvinceData, mine_quality: float) -> Dictionary:
	var iron: float = float(province.mining_pu) * IRON_PER_MINING_PU_PER_SEASON * mine_quality
	province.iron_stockpile += iron
	return {"iron_produced": iron, "stockpile_after": province.iron_stockpile}


# ==============================================================================
# Koku Generation — 0.25 per town PU per season
# ==============================================================================

static func _process_koku_generation(
	_settlements: Array[SettlementData],
	_settlement_meta: Dictionary,
) -> Dictionary:
	return {}


static func generate_koku_province(province: ProvinceData, location_modifier: float) -> Dictionary:
	var koku: float = float(province.town_pu) * KOKU_PER_TOWN_PU_PER_SEASON * location_modifier
	province.koku_stockpile += koku
	return {"koku_generated": koku, "stockpile_after": province.koku_stockpile}
