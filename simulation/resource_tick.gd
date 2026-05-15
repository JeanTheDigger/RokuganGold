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

## Effective fraction of each province's local-tier passed-up rice that
## ultimately reaches the Emperor's stockpile through the four upper
## tiers of the cascade per GDD s4.3.7. Approximation only — does not
## yet account for per-tier personality modifiers (those need the full
## hierarchy wired up). 0.70 (provincial passes 70%) × 0.75 × 0.80 × 0.15.
const EMPEROR_TAKE_FROM_PASSED_UP: float = 0.063


static func process_seasonal_tick(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	season: String,
	settlement_meta: Dictionary,
	miya_inputs: Dictionary = {},
	worship_maluses: Dictionary = {},
) -> Dictionary:
	var results: Dictionary = {
		"rice_consumed": {},
		"starvation_changes": {},
		"population_changes": {},
		"iron_produced": {},
		"koku_generated": {},
		"harvest": {},
		"tax_collected": {},
		"miya_blessing": {},
	}

	settlement_meta["_provinces"] = provinces
	settlement_meta["_settlements"] = settlements
	settlement_meta["_worship_maluses"] = worship_maluses

	if season == "spring":
		_lock_planting(provinces, settlements, settlement_meta)
		# Miya's Blessing fires after planting and BEFORE consumption per
		# GDD s11.5b §3 — the injected rice can absorb the Spring draw and
		# pull settlements out of Shortage before the starvation check.
		if not miya_inputs.is_empty():
			results["miya_blessing"] = _apply_miya_blessing(
				provinces, settlements, miya_inputs, settlement_meta
			)

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
		# Persist the Emperor's approximate income for next Spring's Blessing
		# allocation (s11.5b §2.1).
		settlement_meta["last_autumn_emperor_tax_income"] = (
			_compute_emperor_income_from_cascade(taxes)
		)

	var pop_changes: Dictionary = _process_population_adjustment(provinces, settlements, settlement_meta)
	results["population_changes"] = pop_changes

	var iron: Dictionary = _process_iron_production(settlements, settlement_meta)
	results["iron_produced"] = iron

	var arms: Dictionary = _process_forge_conversion(settlements, settlement_meta)
	results["arms_produced"] = arms

	var koku: Dictionary = _process_koku_generation(settlements, settlement_meta)
	results["koku_generated"] = koku

	return results


# ==============================================================================
# Miya's Blessing application (s11.5b)
# ==============================================================================
#
# `miya_inputs` is the dict assembled by DayOrchestrator. Required keys:
#   "emperor_archetype": StrategicReview.EmperorArchetype
#   "emperor_settlement_id": int   -- where the Imperial stockpile lives
#   "otosan_uchi_pu": float        -- for the reserve floor
#   "emperor_autumn_tax_income": float  -- previous Autumn income
#   "current_ic_year": int
#   "petition_bonuses": Dictionary -- province_id -> int (optional)
#   "exclusions": Dictionary       -- province_id -> {in_rebellion, over_taint_threshold}
#   "war_history": Dictionary      -- province_id -> bool (had active war last year)
#   "raid_history": Dictionary     -- province_id -> bool
#   "pu_decline": Dictionary       -- province_id -> float (0.0..1.0)
# Returns the MiyaBlessingSystem result dict, plus an "applied" sub-dict
# describing the actual rice/stability/year-tracking mutations performed.

static func _apply_miya_blessing(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	miya_inputs: Dictionary,
	settlement_meta: Dictionary,
) -> Dictionary:
	var current_ic_year: int = int(miya_inputs.get("current_ic_year", -1))
	var emperor_settlement_id: int = int(miya_inputs.get("emperor_settlement_id", -1))
	var emperor_settlement: SettlementData = null
	for s in settlements:
		if s.settlement_id == emperor_settlement_id:
			emperor_settlement = s
			break

	var stockpile: float = 0.0
	if emperor_settlement != null:
		stockpile = emperor_settlement.rice_stockpile

	var scored: Array[Dictionary] = _build_scored_provinces(
		provinces, settlements, miya_inputs, settlement_meta, current_ic_year
	)

	var inputs: Dictionary = {
		"emperor_archetype": miya_inputs.get(
			"emperor_archetype", StrategicReview.EmperorArchetype.IRON
		),
		"emperor_autumn_tax_income": float(miya_inputs.get("emperor_autumn_tax_income", 0.0)),
		"emperor_stockpile": stockpile,
		"otosan_uchi_pu": float(miya_inputs.get("otosan_uchi_pu", 0.0)),
		"scored_provinces": scored,
		"province_settlements": _group_settlements_by_province(provinces, settlements),
	}

	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(inputs)

	if not result.get("fired", false):
		return result

	# Apply: withdraw from Emperor's stockpile, deposit into selected
	# settlements, bump province stability, mark last_blessed_ic_year.
	if emperor_settlement != null:
		emperor_settlement.rice_stockpile = maxf(
			0.0, emperor_settlement.rice_stockpile - float(result.get("allocation_total", 0.0))
		)
	var grants: Dictionary = result.get("settlement_rice_grants", {})
	for s in settlements:
		if grants.has(s.settlement_id):
			s.rice_stockpile += float(grants[s.settlement_id])
	# One-season +1% pop growth (§6.3) — stash by province_id; the
	# population adjustment step reads this dict and adds to its rate.
	var growth_bonus: Dictionary = {}
	var pop_growth_bonus: float = float(result.get("pop_growth_bonus", 0.0))
	for prov in provinces:
		if prov.province_id in result.get("selected_province_ids", []):
			prov.stability = clampf(
				prov.stability + float(result.get("stability_bonus", 0)),
				0.0, 100.0,
			)
			if current_ic_year >= 0:
				prov.last_blessed_ic_year = current_ic_year
			growth_bonus[prov.province_id] = pop_growth_bonus
	settlement_meta["_miya_growth_bonus"] = growth_bonus
	return result


static func _build_scored_provinces(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
	miya_inputs: Dictionary,
	settlement_meta: Dictionary,
	current_ic_year: int,
) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	var petition_bonuses: Dictionary = miya_inputs.get("petition_bonuses", {})
	var exclusions: Dictionary = miya_inputs.get("exclusions", {})
	var war_history: Dictionary = miya_inputs.get("war_history", {})
	var raid_history: Dictionary = miya_inputs.get("raid_history", {})
	var pu_decline: Dictionary = miya_inputs.get("pu_decline", {})

	for prov in provinces:
		var pid: int = prov.province_id
		var blessed_last_year: bool = (
			current_ic_year > 0 and prov.last_blessed_ic_year == current_ic_year - 1
		)
		var blessed_two_years_ago: bool = (
			current_ic_year > 1 and prov.last_blessed_ic_year == current_ic_year - 2
		)
		var conditions: Dictionary = {
			"stability": prov.stability,
			"worst_starvation_stage": _worst_starvation_in_province(prov, settlement_meta),
			"had_active_war": bool(war_history.get(pid, false)),
			"had_raid": bool(raid_history.get(pid, false)),
			"has_insurgency": prov.active_insurgency_id >= 0,
			"pu_decline_pct": float(pu_decline.get(pid, 0.0)),
			"blessed_last_year": blessed_last_year,
			"blessed_two_years_ago": blessed_two_years_ago,
			"petition_bonus": int(petition_bonuses.get(pid, 0)),
		}
		var ex_data: Dictionary = exclusions.get(pid, {})
		var entry: Dictionary = {
			"province_id": pid,
			"score": MiyaBlessingSystem.compute_need_score(conditions),
			"stability": prov.stability,
			"population_pu": float(sum_population_pu(prov, settlements)),
			"excluded": MiyaBlessingSystem.is_excluded(ex_data),
		}
		scored.append(entry)
	return scored


static func _worst_starvation_in_province(
	province: ProvinceData,
	settlement_meta: Dictionary,
) -> int:
	## Reads from the previous tick's "_starvation" entry if present; otherwise
	## CLEAR. Note: at Spring start this is the prior season's stage — exactly
	## the signal Miya wants when deciding which provinces are most at risk
	## entering the new year. Starvation results are keyed by province_id with
	## a single { stage, pu_loss_rate } dict per province.
	var starv_data: Dictionary = settlement_meta.get("_starvation", {})
	var entry: Dictionary = starv_data.get(province.province_id, {})
	return int(entry.get("stage", StarvationStage.CLEAR))


static func _group_settlements_by_province(
	provinces: Array[ProvinceData],
	settlements: Array[SettlementData],
) -> Dictionary:
	var grouped: Dictionary = {}
	for prov in provinces:
		var bucket: Array = []
		for s in settlements:
			if s.province_id == prov.province_id:
				bucket.append(s)
		grouped[prov.province_id] = bucket
	return grouped


static func _compute_emperor_income_from_cascade(taxes: Dictionary) -> float:
	## Approximation of Emperor's Autumn income from the local-tier cascade
	## results. Real cascade should sum each tier's retention; until the full
	## hierarchy is wired, multiply total passed-up rice by the upper-tier
	## product (0.70 × 0.75 × 0.80 × 0.15 = 0.063).
	var total_passed_up: float = 0.0
	for pid in taxes:
		total_passed_up += float(taxes[pid].get("passed_up", 0.0))
	return total_passed_up * EMPEROR_TAKE_FROM_PASSED_UP


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
		var harvest_destroyed: bool = meta.get("harvest_destroyed", false)
		if harvest_destroyed:
			yield_amount = 0.0
			meta["harvest_destroyed"] = false
		var worship_m: Dictionary = settlement_meta.get("_worship_maluses", {})
		var rice_mod: float = (worship_m.get(prov.province_id, {}) as Dictionary).get("rice_modifier", 0.0)
		if rice_mod < 0.0 and yield_amount > 0.0:
			yield_amount = maxf(0.0, yield_amount * (1.0 + rice_mod))
		_distribute_rice_to_settlements(prov, settlements, yield_amount)
		harvest_results[prov.province_id] = {
			"farming_pu": locked_farming,
			"terrain_mult": terrain_mult,
			"yield": yield_amount,
			"destroyed": harvest_destroyed,
			"worship_rice_modifier": rice_mod,
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
	var old_stockpile: float = get_province_rice(province, settlements)
	for s: SettlementData in settlements:
		if s.province_id != province.province_id:
			continue
		var civilian: int = s.farming_pu + s.mining_pu + s.town_pu
		var civilian_cost: float = float(civilian) * RICE_CONSUMPTION_PER_PU_PER_SEASON
		var military_cost: float = float(s.military_pu + s.garrison_pu) * MILITARY_RICE_PER_PU_PER_SEASON
		var settlement_cost: float = civilian_cost + military_cost
		s.rice_stockpile = maxf(0.0, s.rice_stockpile - settlement_cost)
		total_civilian_cost += civilian_cost
		total_military_cost += military_cost
	var total_cost: float = total_civilian_cost + total_military_cost
	var new_stockpile: float = get_province_rice(province, settlements)
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
		if loss > 0.0 and lost_pu == 0:
			lost_pu = 1
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
	# One-season Miya's Blessing growth bonus (s11.5b §6.3) — keyed by
	# province_id and added to the computed rate for blessed provinces.
	var miya_growth_bonus: Dictionary = settlement_meta.get("_miya_growth_bonus", {})
	var worship_m: Dictionary = settlement_meta.get("_worship_maluses", {})
	for prov: ProvinceData in provinces:
		var starv: Dictionary = starvation_data.get(prov.province_id, {})
		var stage: StarvationStage = starv.get("stage", StarvationStage.CLEAR)
		var peace: int = peace_map.get(prov.province_id, 0)
		var total_pop: int = sum_population_pu(prov, settlements)
		var prov_rice: float = get_province_rice(prov, settlements)
		var rate: float = compute_growth_rate(total_pop, stage, peace, prov_rice)
		rate += float(miya_growth_bonus.get(prov.province_id, 0.0))
		var pop_mod: float = (worship_m.get(prov.province_id, {}) as Dictionary).get("pop_growth_modifier", 0.0)
		if pop_mod < 0.0:
			rate = maxf(0.0, rate * (1.0 + pop_mod))
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
# Forge Conversion — Iron → Arms per GDD s4.3
# 3.00 Arms capacity per Forge per season. 1.00 Iron = 1.00 Arms (no loss).
# Each Forge converts up to 3.00 Iron; conversion is capped by Iron available.
# ==============================================================================

const ARMS_PER_FORGE_PER_SEASON: float = 3.0

static func _process_forge_conversion(
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var clan_data: Dictionary = settlement_meta.get("_clan_data", {})
	var results: Dictionary = {}

	# Build forge count per clan by summing forges in each settlement
	var clan_forge_count: Dictionary = {}
	for s: SettlementData in settlements:
		var forge_count: int = 0
		for tag: String in s.infrastructure:
			if tag == "forge":
				forge_count += 1
		if forge_count == 0:
			continue
		# Map settlement → clan by province_id
		for clan_name: String in clan_data:
			var cd: ClanData = clan_data[clan_name]
			if s.province_id in cd.province_ids:
				clan_forge_count[clan_name] = clan_forge_count.get(clan_name, 0) + forge_count
				break

	for clan_name: String in clan_forge_count:
		var cd: ClanData = clan_data[clan_name]
		var capacity: float = float(clan_forge_count[clan_name]) * ARMS_PER_FORGE_PER_SEASON
		var converted: float = minf(capacity, cd.iron_stockpile)
		cd.iron_stockpile -= converted
		cd.arms_stockpile += converted
		results[clan_name] = {
			"forge_count": clan_forge_count[clan_name],
			"capacity": capacity,
			"arms_produced": converted,
			"iron_consumed": converted,
		}

	return results


static func process_forge_conversion_single_clan(
	forge_count: int,
	iron_available: float,
) -> Dictionary:
	var capacity: float = float(forge_count) * ARMS_PER_FORGE_PER_SEASON
	var converted: float = minf(capacity, iron_available)
	return {
		"forge_count": forge_count,
		"capacity": capacity,
		"arms_produced": converted,
		"iron_consumed": converted,
	}


# ==============================================================================
# Koku Generation — 0.25 per town PU per season, per settlement
# ==============================================================================

static func _process_koku_generation(
	settlements: Array[SettlementData],
	settlement_meta: Dictionary,
) -> Dictionary:
	var results: Dictionary = {}
	var location_mods: Dictionary = settlement_meta.get("_koku_modifiers", {})
	var worship_m: Dictionary = settlement_meta.get("_worship_maluses", {})
	for s: SettlementData in settlements:
		if s.town_pu <= 0:
			continue
		var loc_mod: float = location_mods.get(s.settlement_id, location_mods.get(s.province_id, 1.0))
		var koku: float = float(s.town_pu) * KOKU_PER_TOWN_PU_PER_SEASON * loc_mod
		var koku_mod: float = (worship_m.get(s.province_id, {}) as Dictionary).get("koku_modifier", 0.0)
		if koku_mod < 0.0:
			koku = maxf(0.0, koku * (1.0 + koku_mod))
		s.koku_stockpile += koku
		var pid: int = s.province_id
		if not results.has(pid):
			results[pid] = {"koku_generated": 0.0}
		results[pid]["koku_generated"] += koku
	return results
