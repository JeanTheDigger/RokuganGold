class_name ResourceTick
## Seasonal and monthly resource processing per GDD s4.3.
## Handles Rice production/consumption, Koku generation, Iron production,
## tax cascade, starvation, and population dynamics.
## PU breakdown and stockpiles live on SettlementData. Iron pools to ClanData.

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
# Settlement PU Helpers
# ==============================================================================

static func get_province_settlements(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> Array[SettlementData]:
	var result: Array[SettlementData] = []
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			result.append(s)
	return result


static func sum_farming_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.farming_pu
	return total


static func sum_mining_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.mining_pu
	return total


static func sum_town_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.town_pu
	return total


static func sum_military_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.military_pu
	return total


static func sum_population_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.population_pu
	return total


static func sum_garrison_pu(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> int:
	var total: int = 0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.garrison_pu
	return total


static func get_province_rice(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> float:
	var total: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id == province.province_id:
			total += s.rice_stockpile
	return total


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

	settlement_meta["_provinces"] = provinces
	settlement_meta["_settlements"] = settlements

	if season == "spring":
		_lock_planting(provinces, settlements, settlement_meta)

	if season == "autumn":
		var harvest: Dictionary = _process_harvest(provinces, settlements, settlement_meta)
		results["harvest"] = harvest
		settlement_meta["_harvest"] = harvest

	var consumption: Dictionary = _process_rice_consumption(provinces, settlements)
	results["rice_consumed"] = consumption
	settlement_meta["_consumption"] = consumption

	var starvation: Dictionary = _process_starvation_check(provinces, settlements, settlement_meta)
	results["starvation_changes"] = starvation
	settlement_meta["_starvation"] = starvation

	if season == "autumn":
		var taxes: Dictionary = _process_tax_cascade(provinces, settlements, settlement_meta)
		results["tax_collected"] = taxes

	var pop_changes: Dictionary = _process_population_adjustment(provinces, settlements, settlement_meta)
	results["population_changes"] = pop_changes

	var iron: Dictionary = _process_iron_production(settlements, settlement_meta)
	results["iron_produced"] = iron

	var koku: Dictionary = _process_koku_generation(settlements, settlement_meta)
	results["koku_generated"] = koku

	return results


# ==============================================================================
# Spring Planting — Locks farming PU for Autumn harvest ceiling
# ==============================================================================

static func _lock_planting(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> void:
	for prov: ProvinceData in provinces:
		var farming: int = sum_farming_pu(prov, settlements)
		settlement_meta[prov.province_id] = settlement_meta.get(prov.province_id, {})
		settlement_meta[prov.province_id]["locked_farming_pu"] = farming


# ==============================================================================
# Autumn Harvest — farming PU locked at spring × 1.50 × terrain modifier
# ==============================================================================

static func _process_harvest(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var harvest_results: Dictionary = {}
	for prov: ProvinceData in provinces:
		var meta: Dictionary = settlement_meta.get(prov.province_id, {})
		var farming: int = sum_farming_pu(prov, settlements)
		var locked_farming: float = float(meta.get("locked_farming_pu", farming))
		var terrain_mult: float = prov.get_rice_multiplier()
		var yield_amount: float = locked_farming * RICE_YIELD_PER_FARMING_PU_PER_YEAR * terrain_mult
		_distribute_rice_to_settlements(prov, settlements, yield_amount)
		harvest_results[prov.province_id] = {
			"farming_pu": locked_farming,
			"terrain_mult": terrain_mult,
			"yield": yield_amount,
		}
	return harvest_results


static func _distribute_rice_to_settlements(
	province: ProvinceData,
	settlements: Array[SettlementData],
	rice_amount: float,
) -> void:
	var province_settlements: Array[SettlementData] = get_province_settlements(province, settlements)
	var total_pop: int = 0
	for s: SettlementData in province_settlements:
		total_pop += s.population_pu
	if province_settlements.is_empty():
		return
	if total_pop <= 0:
		province_settlements[0].rice_stockpile += rice_amount
		return
	for s: SettlementData in province_settlements:
		var share: float = rice_amount * (float(s.population_pu) / float(total_pop))
		s.rice_stockpile += share


# ==============================================================================
# Rice Consumption — 0.25 per civilian PU, 0.35 per military PU per season
# ==============================================================================

static func _process_rice_consumption(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
) -> Dictionary:
	var results: Dictionary = {}
	for prov: ProvinceData in provinces:
		var result: Dictionary = consume_rice_province(prov, settlements)
		results[prov.province_id] = result
	return results


static func consume_rice_province(
	province: ProvinceData,
	settlements: Array[SettlementData],
) -> Dictionary:
	var total_civilian_cost: float = 0.0
	var total_military_cost: float = 0.0
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		var civilian: int = s.farming_pu + s.mining_pu + s.town_pu
		var civilian_cost: float = float(civilian) * RICE_CONSUMPTION_PER_PU_PER_SEASON
		var military_cost: float = float(s.military_pu) * MILITARY_RICE_PER_PU_PER_SEASON
		var settlement_cost: float = civilian_cost + military_cost
		var old_rice: float = s.rice_stockpile
		s.rice_stockpile = maxf(0.0, s.rice_stockpile - settlement_cost)
		total_civilian_cost += civilian_cost
		total_military_cost += military_cost
	var total_cost: float = total_civilian_cost + total_military_cost
	var new_stockpile: float = get_province_rice(province, settlements)
	var old_stockpile: float = new_stockpile + total_cost
	var deficit: float = maxf(0.0, total_cost - old_stockpile)
	return {
		"civilian_cost": total_civilian_cost,
		"military_cost": total_military_cost,
		"total_cost": total_cost,
		"deficit": deficit,
		"stockpile_after": new_stockpile,
	}


# ==============================================================================
# Starvation Check — Deficit triggers escalation per s4.3.6
# ==============================================================================

static func _process_starvation_check(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var consumption: Dictionary = settlement_meta.get("_consumption", {})
	for prov: ProvinceData in provinces:
		var cons: Dictionary = consumption.get(prov.province_id, {})
		var deficit: float = cons.get("deficit", 0.0)
		var consecutive: int = settlement_meta.get("_deficit_seasons", {}).get(prov.province_id, 0)
		var prov_rice: float = get_province_rice(prov, settlements)
		var starv: Dictionary = check_starvation(deficit, consecutive, prov_rice)
		if starv["stage"] != StarvationStage.CLEAR:
			apply_starvation_loss_settlements(prov, settlements, starv["pu_loss_rate"])
		results[prov.province_id] = starv
	return results


static func check_starvation(
	deficit: float,
	consecutive_deficit_seasons: int,
	province_rice: float = 0.0,
) -> Dictionary:
	if deficit <= 0.0:
		return {"stage": StarvationStage.CLEAR, "pu_loss_rate": 0.0}

	var stage: StarvationStage
	if province_rice <= 0.0 and deficit > 0.0:
		stage = StarvationStage.FAMINE
	elif consecutive_deficit_seasons >= 3:
		stage = StarvationStage.FAMINE
	elif consecutive_deficit_seasons >= 2:
		stage = StarvationStage.HUNGER
	else:
		stage = StarvationStage.SHORTAGE

	var loss_rate: float = STARVATION_PU_LOSS[stage]
	return {"stage": stage, "pu_loss_rate": loss_rate}


static func apply_starvation_loss_settlements(
	province: ProvinceData,
	settlements: Array[SettlementData],
	loss_rate: float,
) -> Dictionary:
	var total_lost: int = 0
	var remaining_pu: int = 0
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		var loss: float = float(s.population_pu) * loss_rate
		var lost_pu: int = int(loss)
		if lost_pu > 0 and s.farming_pu > 0:
			var farming_loss: int = mini(lost_pu, s.farming_pu)
			s.farming_pu -= farming_loss
			lost_pu -= farming_loss
		if lost_pu > 0 and s.town_pu > 0:
			var town_loss: int = mini(lost_pu, s.town_pu)
			s.town_pu -= town_loss
			lost_pu -= town_loss
		s.population_pu = s.farming_pu + s.mining_pu + s.town_pu + s.military_pu
		total_lost += int(loss)
		remaining_pu += s.population_pu
	return {"total_lost": total_lost, "remaining_pu": remaining_pu}


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


static func compute_taxable_surplus(total_population_pu: int, autumn_yield: float) -> float:
	var subsistence: float = float(total_population_pu) * SUBSISTENCE_FLOOR_PER_PU
	return maxf(0.0, autumn_yield - subsistence)


static func _process_tax_cascade(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var harvest: Dictionary = settlement_meta.get("_harvest", {})
	for prov: ProvinceData in provinces:
		var harvest_data: Dictionary = harvest.get(prov.province_id, {})
		var yield_amount: float = harvest_data.get("yield", 0.0)
		var total_pop: int = sum_population_pu(prov, settlements)
		var surplus: float = compute_taxable_surplus(total_pop, yield_amount)
		if surplus <= 0.0:
			results[prov.province_id] = {"surplus": 0.0, "total_collected": 0.0}
			continue
		var tax_mod: float = settlement_meta.get("_tax_modifier", {}).get(prov.province_id, 0.0)
		var tier_result: Dictionary = apply_tax_at_tier(surplus, "local_daimyo", tax_mod)
		_distribute_rice_to_settlements(prov, settlements, tier_result["collected"])
		results[prov.province_id] = {
			"surplus": surplus,
			"total_collected": tier_result["collected"],
			"passed_up": tier_result["passed_up"],
		}
	return results


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
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var starvation_data: Dictionary = settlement_meta.get("_starvation", {})
	var peace_map: Dictionary = settlement_meta.get("_peace_seasons", {})
	for prov: ProvinceData in provinces:
		var starv: Dictionary = starvation_data.get(prov.province_id, {})
		var stage: StarvationStage = starv.get("stage", StarvationStage.CLEAR)
		var peace: int = peace_map.get(prov.province_id, 0)
		var total_pop: int = sum_population_pu(prov, settlements)
		var prov_rice: float = get_province_rice(prov, settlements)
		var rate: float = compute_growth_rate(total_pop, stage, peace, prov_rice)
		var growth: Dictionary = apply_population_growth_settlements(prov, settlements, rate)
		results[prov.province_id] = growth
	return results


static func compute_growth_rate(
	population_pu: int,
	starvation_stage: StarvationStage,
	peace_seasons: int,
	province_rice: float = 0.0,
) -> float:
	if starvation_stage != StarvationStage.CLEAR:
		return 0.0

	var rice_per_pu: float = 0.0
	if population_pu > 0:
		rice_per_pu = province_rice / float(population_pu)

	var annual_rate: float = BASELINE_GROWTH_ANNUAL
	if rice_per_pu >= STRONG_STOCKPILE_THRESHOLD:
		annual_rate = STRONG_STOCKPILE_GROWTH_ANNUAL
	elif rice_per_pu >= MODEST_STOCKPILE_THRESHOLD:
		annual_rate = MODEST_STOCKPILE_GROWTH_ANNUAL

	if peace_seasons >= PEACE_SEASONS_REQUIRED:
		annual_rate += PEACE_BONUS_ANNUAL

	return annual_rate / 4.0


static func apply_population_growth_settlements(
	province: ProvinceData,
	settlements: Array[SettlementData],
	seasonal_rate: float,
) -> Dictionary:
	if seasonal_rate <= 0.0:
		var total: int = sum_population_pu(province, settlements)
		return {"growth": 0, "new_total": total}
	var total_growth: int = 0
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		var growth: float = float(s.farming_pu) * seasonal_rate
		var growth_pu: int = int(growth)
		if growth_pu > 0:
			s.farming_pu += growth_pu
			s.population_pu += growth_pu
			total_growth += growth_pu
	var new_total: int = sum_population_pu(province, settlements)
	return {"growth": total_growth, "new_total": new_total}


# ==============================================================================
# Iron Production — 0.50 per mining PU per season, pools to clan level
# ==============================================================================

static func _process_iron_production(
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var quality_map: Dictionary = settlement_meta.get("_mine_quality", {})
	var clan_data: Dictionary = settlement_meta.get("_clan_data", {})
	var province_iron: Dictionary = {}
	for s: SettlementData in settlements:
		if s.mining_pu <= 0:
			continue
		var quality: float = quality_map.get(s.province_id, 1.0)
		var iron: float = float(s.mining_pu) * IRON_PER_MINING_PU_PER_SEASON * quality
		province_iron[s.province_id] = province_iron.get(s.province_id, 0.0) + iron
	for pid: int in province_iron:
		results[pid] = {"iron_produced": province_iron[pid]}
	for clan_name: String in clan_data:
		var cd: ClanData = clan_data[clan_name]
		for pid: int in cd.province_ids:
			if province_iron.has(pid):
				cd.iron_stockpile += province_iron[pid]
	return results


static func produce_iron_settlement(settlement: SettlementData, mine_quality: float) -> Dictionary:
	var iron: float = float(settlement.mining_pu) * IRON_PER_MINING_PU_PER_SEASON * mine_quality
	return {"iron_produced": iron}


# ==============================================================================
# Koku Generation — 0.25 per town PU per season, per settlement
# ==============================================================================

static func _process_koku_generation(
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var location_mods: Dictionary = settlement_meta.get("_koku_modifiers", {})
	for s: SettlementData in settlements:
		if s.town_pu <= 0:
			continue
		var loc_mod: float = location_mods.get(s.settlement_id, location_mods.get(s.province_id, 1.0))
		var koku: float = float(s.town_pu) * KOKU_PER_TOWN_PU_PER_SEASON * loc_mod
		s.koku_stockpile += koku
		var pid: int = s.province_id
		if not results.has(pid):
			results[pid] = {"koku_generated": 0.0}
		results[pid]["koku_generated"] += koku
	return results
