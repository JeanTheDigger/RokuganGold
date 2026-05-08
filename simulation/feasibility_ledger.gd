class_name FeasibilityLedger
## AI War Readiness Check — Phase 1: Feasibility Ledger per GDD s4.3.17.
## Estimates whether a lord can sustain a proposed military campaign across
## three strategic resources (Rice, Arms, Koku). Pure static functions.


# -- Enums --------------------------------------------------------------------

enum ResourceStatus {
	GREEN,
	YELLOW,
	RED,
}

enum CompositeVerdict {
	FEASIBLE,
	RISKY,
	NOT_FEASIBLE,
	DESPERATE,
}


# -- Campaign Length Constants ------------------------------------------------

const BASE_CAMPAIGN_SEASONS: Dictionary = {
	0: 1,  # PROVINCIAL_RAID
	1: 2,  # BORDER_CONFLICT
	2: 3,  # FAMILY_WAR
	3: 4,  # CLAN_WAR
}

const REDUCE_ESTIMATE_VIRTUES: Array[String] = ["Yu", "Kyoryoku"]
const INCREASE_ESTIMATE_VIRTUES: Array[String] = ["Seigyo", "Chishiki"]

const RICE_CIVILIAN_RATE: float = 0.25
const RICE_MILITARY_RATE: float = 0.35
const RICE_YIELD_PER_PU: float = 1.50
const LEVY_PRODUCTION_LOSS_PER_PU: float = 1.50

const RICE_GREEN_THRESHOLD: float = 1.00

const PROCEED_ON_YELLOW_VIRTUES: Array[String] = [
	"Yu", "Kyoryoku", "Ketsui", "Ishi",
]


# -- Step 1: Campaign Length Estimation ---------------------------------------

static func estimate_campaign_seasons(
	authority_level: int,
	primary_virtue: String,
) -> int:
	var base: int = BASE_CAMPAIGN_SEASONS.get(authority_level, 2)

	if primary_virtue in REDUCE_ESTIMATE_VIRTUES:
		return maxi(1, base - 1)

	if primary_virtue in INCREASE_ESTIMATE_VIRTUES:
		return base + 1

	return base


# -- Step 2: Rice Budget ------------------------------------------------------

static func calculate_rice_budget(
	controlled_settlements: Array,
	proposed_levy_pu: float,
	campaign_seasons: int,
	levy_before_planting: bool,
	spans_autumn: bool,
	provinces: Array = [],
) -> Dictionary:
	var current_stockpile: float = 0.0
	var total_civilian_pu: float = 0.0
	var total_military_pu: float = 0.0
	var total_farming_pu: float = 0.0

	for s: Variant in controlled_settlements:
		if not (s is SettlementData):
			continue
		var sd: SettlementData = s
		current_stockpile += sd.rice_stockpile
		total_civilian_pu += float(sd.farming_pu + sd.mining_pu + sd.town_pu)
		total_military_pu += float(sd.military_pu)
		total_farming_pu += float(sd.farming_pu)

	var civilian_burn: float = total_civilian_pu * RICE_CIVILIAN_RATE * campaign_seasons
	var military_burn: float = (
		(total_military_pu + proposed_levy_pu) * RICE_MILITARY_RATE * campaign_seasons
	)

	var production_loss: float = 0.0
	if levy_before_planting:
		production_loss = proposed_levy_pu * LEVY_PRODUCTION_LOSS_PER_PU

	var projected_harvest: float = 0.0
	if spans_autumn:
		var farming_after_levy: float = maxf(0.0, total_farming_pu - proposed_levy_pu)
		var terrain_mult: float = _avg_terrain_multiplier(controlled_settlements, provinces)
		projected_harvest = farming_after_levy * RICE_YIELD_PER_PU * terrain_mult

	var net: float = (
		current_stockpile + projected_harvest
		- civilian_burn - military_burn - production_loss
	)

	var total_pu: float = total_civilian_pu + total_military_pu + proposed_levy_pu
	var per_pu: float = net / maxf(1.0, total_pu)

	var status: int = ResourceStatus.RED
	if net >= 0.0 and per_pu >= RICE_GREEN_THRESHOLD:
		status = ResourceStatus.GREEN
	elif net >= 0.0:
		status = ResourceStatus.YELLOW

	return {
		"status": status,
		"net_position": net,
		"per_pu": per_pu,
		"current_stockpile": current_stockpile,
		"civilian_burn": civilian_burn,
		"military_burn": military_burn,
		"production_loss": production_loss,
		"projected_harvest": projected_harvest,
	}


# -- Step 3: Arms Budget ------------------------------------------------------

static func calculate_arms_budget(
	clan_arms_stockpile: float,
	clan_iron_stockpile: float,
	total_mining_pu: float,
	equip_cost: float,
	existing_military_pu: float,
	proposed_levy_pu: float,
	iron_upkeep_rate_per_pu: float,
	campaign_seasons: int,
	available_koku_for_market: float = 0.0,
) -> Dictionary:
	var iron_per_season: float = total_mining_pu * 0.50
	var total_iron_available: float = clan_iron_stockpile + (iron_per_season * campaign_seasons)

	var iron_upkeep_total: float = (
		(existing_military_pu + proposed_levy_pu)
		* iron_upkeep_rate_per_pu * campaign_seasons
	)

	var net_iron: float = total_iron_available - iron_upkeep_total
	var projected_production: float = minf(net_iron, iron_per_season * campaign_seasons) * 0.5

	var net: float = clan_arms_stockpile + projected_production - equip_cost

	var status: int = ResourceStatus.RED
	if net >= 0.0:
		status = ResourceStatus.GREEN
	elif available_koku_for_market > 0.0:
		var deficit: float = absf(net)
		var iron_price: float = 0.8
		if available_koku_for_market / iron_price >= deficit:
			status = ResourceStatus.YELLOW

	return {
		"status": status,
		"net_position": net,
		"clan_arms_stockpile": clan_arms_stockpile,
		"equip_cost": equip_cost,
		"iron_upkeep_total": iron_upkeep_total,
		"projected_production": projected_production,
	}


# -- Step 4: Koku Budget ------------------------------------------------------

static func calculate_koku_budget(
	current_koku: float,
	campaign_seasons: int,
	stipend_per_season: float = 0.0,
	market_purchase_cost: float = 0.0,
) -> Dictionary:
	var stipend_total: float = stipend_per_season * campaign_seasons
	var net: float = current_koku - stipend_total - market_purchase_cost

	var status: int = ResourceStatus.RED
	if net >= 0.0:
		status = ResourceStatus.GREEN
	elif current_koku >= market_purchase_cost:
		status = ResourceStatus.YELLOW

	return {
		"status": status,
		"net_position": net,
		"current_koku": current_koku,
		"stipend_total": stipend_total,
		"market_purchase_cost": market_purchase_cost,
	}


# -- Step 5: Composite Verdict -----------------------------------------------

static func compute_composite_verdict(
	rice_status: int,
	arms_status: int,
	koku_status: int,
) -> int:
	if (
		rice_status == ResourceStatus.RED
		and arms_status == ResourceStatus.RED
		and koku_status == ResourceStatus.RED
	):
		return CompositeVerdict.DESPERATE

	if (
		rice_status == ResourceStatus.RED
		or arms_status == ResourceStatus.RED
		or koku_status == ResourceStatus.RED
	):
		return CompositeVerdict.NOT_FEASIBLE

	if (
		rice_status == ResourceStatus.YELLOW
		or arms_status == ResourceStatus.YELLOW
		or koku_status == ResourceStatus.YELLOW
	):
		return CompositeVerdict.RISKY

	return CompositeVerdict.FEASIBLE


static func should_proceed_on_risky(
	primary_virtue: String,
	is_high_priority_objective: bool,
) -> bool:
	if is_high_priority_objective:
		return true
	return primary_virtue in PROCEED_ON_YELLOW_VIRTUES


# -- Full Ledger Entry Point --------------------------------------------------

static func evaluate_feasibility(inputs: Dictionary) -> Dictionary:
	var authority_level: int = inputs.get("authority_level", 0)
	var primary_virtue: String = inputs.get("primary_virtue", "")
	var controlled_settlements: Array = inputs.get("controlled_settlements", [])
	var provinces: Array = inputs.get("provinces", [])
	var clan_arms_stockpile: float = inputs.get("clan_arms_stockpile", 0.0)
	var clan_iron_stockpile: float = inputs.get("clan_iron_stockpile", 0.0)
	var proposed_levy_pu: float = inputs.get("proposed_levy_pu", 0.0)
	var equip_cost: float = inputs.get("equip_cost", 0.0)
	var iron_upkeep_rate: float = inputs.get("iron_upkeep_rate_per_pu", 0.10)
	var levy_before_planting: bool = inputs.get("levy_before_planting", false)
	var spans_autumn: bool = inputs.get("spans_autumn", false)
	var current_koku: float = inputs.get("current_koku", 0.0)
	var stipend_per_season: float = inputs.get("stipend_per_season", 0.0)
	var is_high_priority: bool = inputs.get("is_high_priority_objective", false)

	var campaign_seasons: int = estimate_campaign_seasons(
		authority_level, primary_virtue,
	)

	var total_mining_pu: float = 0.0
	var existing_military_pu: float = 0.0
	for s: Variant in controlled_settlements:
		if s is SettlementData:
			total_mining_pu += float((s as SettlementData).mining_pu)
			existing_military_pu += float((s as SettlementData).military_pu)

	var rice: Dictionary = calculate_rice_budget(
		controlled_settlements, proposed_levy_pu, campaign_seasons,
		levy_before_planting, spans_autumn, provinces,
	)

	var arms: Dictionary = calculate_arms_budget(
		clan_arms_stockpile, clan_iron_stockpile, total_mining_pu,
		equip_cost, existing_military_pu, proposed_levy_pu,
		iron_upkeep_rate, campaign_seasons, current_koku,
	)

	var koku: Dictionary = calculate_koku_budget(
		current_koku, campaign_seasons, stipend_per_season, 0.0,
	)

	var verdict: int = compute_composite_verdict(
		rice["status"], arms["status"], koku["status"],
	)

	var feasible: bool = verdict == CompositeVerdict.FEASIBLE
	if verdict == CompositeVerdict.RISKY:
		feasible = should_proceed_on_risky(primary_virtue, is_high_priority)

	return {
		"feasible": feasible,
		"verdict": verdict,
		"campaign_seasons": campaign_seasons,
		"rice": rice,
		"arms": arms,
		"koku": koku,
	}


# -- Helpers ------------------------------------------------------------------

static func _avg_terrain_multiplier(
	settlements: Array,
	provinces: Array,
) -> float:
	if provinces.is_empty():
		return 1.0
	var province_map: Dictionary = {}
	for p: Variant in provinces:
		if p is ProvinceData:
			province_map[(p as ProvinceData).province_id] = p
	var total: float = 0.0
	var count: int = 0
	for s: Variant in settlements:
		if not (s is SettlementData):
			continue
		var sd: SettlementData = s
		var prov: Variant = province_map.get(sd.province_id, null)
		if prov is ProvinceData:
			total += (prov as ProvinceData).get_rice_multiplier()
			count += 1
	if count == 0:
		return 1.0
	return total / float(count)
