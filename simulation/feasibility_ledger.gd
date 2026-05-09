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
	market_rice_bonus: float = 0.0,
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
		current_stockpile + projected_harvest + market_rice_bonus
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
	var market_rice_bonus: float = inputs.get("market_rice_bonus", 0.0)

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
		levy_before_planting, spans_autumn, provinces, market_rice_bonus,
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


# =============================================================================
# Phase 2: The Alternative Ladder (s4.3.17)
# =============================================================================
# When the Feasibility Ledger returns RISKY or NOT_FEASIBLE/DESPERATE, the AI
# walks down 7 rungs sequentially, recalculating after each. Stops when the
# verdict improves to an acceptable level.

enum LadderRung {
	SCALE_DOWN,
	DELAY_TO_HARVEST,
	PURCHASE_MARKET,
	DEMAND_TRIBUTE,
	REQUEST_ALLIED_AID,
	RAID_NEIGHBOR,
	DESPERATION_OVERRIDE,
}


# -- Constants ----------------------------------------------------------------

const SCALE_DOWN_FACTOR: float = 0.5
const SCALE_DOWN_EQUIP_RATIO: float = 0.5

const DELAY_SKIP_VIRTUES: Array[String] = ["Yu", "Kyoryoku"]
const DELAYABLE_SEASONS: Array[String] = ["spring", "summer"]

const TRIBUTE_MAX_FRACTION: float = 0.25
const TRIBUTE_DISPOSITION_COST: int = -5
const TRIBUTE_FRIEND_THRESHOLD: int = 31
const TRIBUTE_REFUSE_THRESHOLD: int = -11

const ALLIED_AID_SKIP_VIRTUES: Array[String] = ["Ketsui", "Ishi"]
const ALLIED_AID_FRIEND_THRESHOLD: int = 31
const ALLIED_AID_SIGNIFICANT_FRACTION: float = 0.30

const RAID_BLOCK_VIRTUES: Array[String] = ["Jin", "Gi"]
const RAID_HONOR_COST: float = -1.0
const RAID_GLORY_COST: float = -0.3
const RAID_CLAN_DISPOSITION_COST: int = -15
const RAID_OTHER_DISPOSITION_COST: int = -5
const RAID_RICE_FRACTION: float = 0.50
const RAID_GARRISON_CAP: float = 1.0

const DESPERATION_RICE_PER_PU: float = 0.50
const DESPERATION_VIRTUES: Array[String] = [
	"Yu", "Chugi", "Ketsui", "Kyoryoku", "Ishi",
]
const CRITICAL_OBJECTIVES: Array[String] = [
	"DEFEND_PROVINCE", "DEFEND_TERRITORY",
	"RESOLVE_CLAN_WAR", "SEEK_VENGEANCE", "AVENGE",
]
const DESPERATION_JIN_HONOR_COST: float = -1.0


# -- Rung 1: Scale Down the Army ----------------------------------------------

static func try_scale_down(inputs: Dictionary) -> Dictionary:
	var modified: Dictionary = inputs.duplicate(true)
	var current_levy: float = modified.get("proposed_levy_pu", 0.0)
	var current_equip: float = modified.get("equip_cost", 0.0)

	modified["proposed_levy_pu"] = current_levy * SCALE_DOWN_FACTOR
	modified["equip_cost"] = current_equip * SCALE_DOWN_EQUIP_RATIO

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.SCALE_DOWN,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
		"reduced_levy_pu": modified["proposed_levy_pu"],
	}


# -- Rung 2: Delay to Post-Harvest --------------------------------------------

static func try_delay_to_harvest(
	inputs: Dictionary,
	primary_virtue: String,
	current_season: String,
) -> Dictionary:
	if primary_virtue in DELAY_SKIP_VIRTUES:
		return {"rung": LadderRung.DELAY_TO_HARVEST, "applied": false, "reason": "personality_skip"}

	if current_season not in DELAYABLE_SEASONS:
		return {"rung": LadderRung.DELAY_TO_HARVEST, "applied": false, "reason": "wrong_season"}

	var modified: Dictionary = inputs.duplicate(true)
	modified["levy_before_planting"] = false
	modified["spans_autumn"] = true

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.DELAY_TO_HARVEST,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
	}


# -- Rung 3: Purchase on the Market -------------------------------------------

static func try_market_purchase(
	inputs: Dictionary,
	koku_status: int,
	has_trade_routes: bool,
) -> Dictionary:
	if koku_status == ResourceStatus.RED:
		return {"rung": LadderRung.PURCHASE_MARKET, "applied": false, "reason": "koku_red"}

	if not has_trade_routes:
		return {"rung": LadderRung.PURCHASE_MARKET, "applied": false, "reason": "no_trade_routes"}

	var modified: Dictionary = inputs.duplicate(true)
	var available_koku: float = modified.get("current_koku", 0.0)
	var rice_price: float = 1.0
	var purchasable_rice: float = available_koku * 0.5 / rice_price

	var bonus_rice: float = purchasable_rice
	modified["market_rice_bonus"] = bonus_rice

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.PURCHASE_MARKET,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
		"koku_spent": available_koku * 0.5,
		"rice_purchased": bonus_rice,
	}


# -- Rung 4: Demand Extraordinary Tribute --------------------------------------

static func try_demand_tribute(
	inputs: Dictionary,
	primary_virtue: String,
	vassal_stockpiles: Array,
) -> Dictionary:
	if vassal_stockpiles.is_empty():
		return {"rung": LadderRung.DEMAND_TRIBUTE, "applied": false, "reason": "no_vassals"}

	var total_tribute_rice: float = 0.0
	var total_tribute_arms: float = 0.0
	var compliant_vassals: int = 0
	var refusing_vassals: int = 0

	for v: Variant in vassal_stockpiles:
		if not (v is Dictionary):
			continue
		var vd: Dictionary = v
		var disp: int = vd.get("disposition", 0)
		var rice: float = vd.get("rice_stockpile", 0.0)
		var arms: float = vd.get("arms_stockpile", 0.0)
		var in_shortage: bool = vd.get("in_shortage", false)

		if primary_virtue == "Jin" and in_shortage:
			continue

		if disp < TRIBUTE_REFUSE_THRESHOLD:
			refusing_vassals += 1
			continue

		total_tribute_rice += rice * TRIBUTE_MAX_FRACTION
		total_tribute_arms += arms * TRIBUTE_MAX_FRACTION
		compliant_vassals += 1

	if compliant_vassals == 0:
		return {"rung": LadderRung.DEMAND_TRIBUTE, "applied": false, "reason": "no_compliant_vassals"}

	var modified: Dictionary = inputs.duplicate(true)
	modified["market_rice_bonus"] = modified.get("market_rice_bonus", 0.0) + total_tribute_rice
	modified["clan_arms_stockpile"] = modified.get("clan_arms_stockpile", 0.0) + total_tribute_arms

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.DEMAND_TRIBUTE,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
		"tribute_rice": total_tribute_rice,
		"tribute_arms": total_tribute_arms,
		"compliant_vassals": compliant_vassals,
		"refusing_vassals": refusing_vassals,
		"disposition_cost": TRIBUTE_DISPOSITION_COST,
		"generates_topic": true,
		"topic_tier": 4,
	}


# -- Rung 5: Request Allied Aid -----------------------------------------------

static func try_request_allied_aid(
	inputs: Dictionary,
	primary_virtue: String,
	allied_surplus: Array,
) -> Dictionary:
	if primary_virtue in ALLIED_AID_SKIP_VIRTUES:
		return {"rung": LadderRung.REQUEST_ALLIED_AID, "applied": false, "reason": "personality_skip"}

	if allied_surplus.is_empty():
		return {"rung": LadderRung.REQUEST_ALLIED_AID, "applied": false, "reason": "no_allies"}

	var total_aid_rice: float = 0.0
	var total_aid_koku: float = 0.0
	var favor_tier: int = 3
	var contributing_ally_ids: Array[int] = []

	for ally: Variant in allied_surplus:
		if not (ally is Dictionary):
			continue
		var ad: Dictionary = ally
		var disp: int = ad.get("disposition", 0)
		if disp < ALLIED_AID_FRIEND_THRESHOLD:
			continue
		var surplus_rice: float = ad.get("surplus_rice", 0.0)
		var surplus_koku: float = ad.get("surplus_koku", 0.0)
		if surplus_rice <= 0.0 and surplus_koku <= 0.0:
			continue
		var contribution_rice: float = surplus_rice * 0.25
		var contribution_koku: float = surplus_koku * 0.25
		total_aid_rice += contribution_rice
		total_aid_koku += contribution_koku
		contributing_ally_ids.append(ad.get("character_id", -1))
		if contribution_rice > surplus_rice * ALLIED_AID_SIGNIFICANT_FRACTION:
			favor_tier = 2

	if total_aid_rice <= 0.0 and total_aid_koku <= 0.0:
		return {"rung": LadderRung.REQUEST_ALLIED_AID, "applied": false, "reason": "no_willing_allies"}

	var modified: Dictionary = inputs.duplicate(true)
	modified["market_rice_bonus"] = modified.get("market_rice_bonus", 0.0) + total_aid_rice
	modified["current_koku"] = modified.get("current_koku", 0.0) + total_aid_koku

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.REQUEST_ALLIED_AID,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
		"aid_rice": total_aid_rice,
		"aid_koku": total_aid_koku,
		"favor_tier": favor_tier,
		"creates_favor": true,
		"contributing_ally_ids": contributing_ally_ids,
	}


# -- Rung 6: Raid a Vulnerable Neighbor ----------------------------------------

static func try_raid_neighbor(
	inputs: Dictionary,
	primary_virtue: String,
	has_grievance: bool,
	has_issued_demand: bool,
	raidable_provinces: Array,
) -> Dictionary:
	if primary_virtue in RAID_BLOCK_VIRTUES:
		return {"rung": LadderRung.RAID_NEIGHBOR, "applied": false, "reason": "personality_block"}

	if primary_virtue == "Meiyo" and not has_grievance:
		return {"rung": LadderRung.RAID_NEIGHBOR, "applied": false, "reason": "meiyo_no_grievance"}

	if primary_virtue == "Rei" and not has_issued_demand:
		return {"rung": LadderRung.RAID_NEIGHBOR, "applied": false, "reason": "rei_no_prior_demand"}

	if raidable_provinces.is_empty():
		return {"rung": LadderRung.RAID_NEIGHBOR, "applied": false, "reason": "no_targets"}

	var best_target: Dictionary = {}
	var best_rice: float = 0.0
	for rp: Variant in raidable_provinces:
		if not (rp is Dictionary):
			continue
		var rpd: Dictionary = rp
		var garrison: float = rpd.get("garrison_pu", 0.0)
		if garrison > RAID_GARRISON_CAP:
			continue
		var rice: float = rpd.get("rice_stockpile", 0.0) * RAID_RICE_FRACTION
		var at_war: bool = rpd.get("already_at_war", false)
		var effective_rice: float = rice * (1.5 if at_war else 1.0)
		if effective_rice > best_rice:
			best_rice = effective_rice
			best_target = rpd

	if best_target.is_empty():
		return {"rung": LadderRung.RAID_NEIGHBOR, "applied": false, "reason": "no_viable_targets"}

	var seized_rice: float = best_target.get("rice_stockpile", 0.0) * RAID_RICE_FRACTION

	var modified: Dictionary = inputs.duplicate(true)
	modified["market_rice_bonus"] = modified.get("market_rice_bonus", 0.0) + seized_rice

	var ledger: Dictionary = evaluate_feasibility(modified)
	return {
		"rung": LadderRung.RAID_NEIGHBOR,
		"applied": true,
		"ledger": ledger,
		"modified_inputs": modified,
		"seized_rice": seized_rice,
		"target_province_id": best_target.get("province_id", -1),
		"target_clan": best_target.get("clan", ""),
		"honor_cost": RAID_HONOR_COST,
		"glory_cost": RAID_GLORY_COST,
		"clan_disposition_cost": RAID_CLAN_DISPOSITION_COST,
		"other_disposition_cost": RAID_OTHER_DISPOSITION_COST,
		"triggers_war_status": not best_target.get("already_at_war", false),
		"generates_topic": true,
		"topic_tier": 3,
	}


# -- Rung 7: Desperation Override ----------------------------------------------

const CRITICAL_OBJECTIVE_KEYS: Array[String] = [
	"DEFEND_PROVINCE", "DEFEND_TERRITORY",
	"RESOLVE_CLAN_WAR", "SEEK_VENGEANCE", "AVENGE",
]


static func try_desperation_override(
	_inputs: Dictionary,
	primary_virtue: String,
	rice_per_pu: float,
	has_critical_objective: bool,
	war_score: int,
	is_defending: bool,
) -> Dictionary:
	if rice_per_pu >= DESPERATION_RICE_PER_PU:
		return {"rung": LadderRung.DESPERATION_OVERRIDE, "applied": false, "reason": "rice_above_threshold"}

	if not has_critical_objective:
		return {"rung": LadderRung.DESPERATION_OVERRIDE, "applied": false, "reason": "no_critical_objective"}

	var personality_qualifies: bool = primary_virtue in DESPERATION_VIRTUES
	var score_qualifies: bool = war_score < 25 and is_defending
	if not personality_qualifies and not score_qualifies:
		return {"rung": LadderRung.DESPERATION_OVERRIDE, "applied": false, "reason": "personality_and_score_block"}

	var honor_cost: float = 0.0
	if primary_virtue == "Jin":
		honor_cost = DESPERATION_JIN_HONOR_COST

	return {
		"rung": LadderRung.DESPERATION_OVERRIDE,
		"applied": true,
		"overrides_feasibility": true,
		"desperation_levy": true,
		"honor_cost": honor_cost,
		"generates_topic": true,
		"topic_tier": 3,
	}


# -- Full Ladder Walk ----------------------------------------------------------

static func walk_alternative_ladder(
	inputs: Dictionary,
	primary_virtue: String,
	current_season: String,
	vassal_stockpiles: Array = [],
	allied_surplus: Array = [],
	raidable_provinces: Array = [],
	has_trade_routes: bool = false,
	has_grievance: bool = false,
	has_issued_demand: bool = false,
	has_critical_objective: bool = false,
	war_score: int = 50,
	is_defending: bool = false,
) -> Dictionary:
	var rungs_tried: Array[Dictionary] = []
	var working_inputs: Dictionary = inputs.duplicate(true)
	var current_ledger: Dictionary = evaluate_feasibility(working_inputs)

	if current_ledger["feasible"]:
		return {
			"outcome": "already_feasible",
			"rungs_tried": rungs_tried,
			"final_ledger": current_ledger,
		}

	# Rung 1: Scale Down
	var r1: Dictionary = try_scale_down(working_inputs)
	rungs_tried.append(r1)
	if r1["applied"] and r1["ledger"]["feasible"]:
		return {
			"outcome": "scaled_down",
			"rungs_tried": rungs_tried,
			"final_ledger": r1["ledger"],
			"modified_inputs": r1["modified_inputs"],
		}
	if r1["applied"]:
		working_inputs = r1["modified_inputs"]
		current_ledger = r1["ledger"]

	# Rung 2: Delay to Harvest
	var r2: Dictionary = try_delay_to_harvest(working_inputs, primary_virtue, current_season)
	rungs_tried.append(r2)
	if r2.get("applied", false) and r2.get("ledger", {}).get("feasible", false):
		return {
			"outcome": "delayed_to_harvest",
			"rungs_tried": rungs_tried,
			"final_ledger": r2["ledger"],
			"modified_inputs": r2["modified_inputs"],
		}
	if r2.get("applied", false):
		working_inputs = r2["modified_inputs"]
		current_ledger = r2["ledger"]

	# Rung 3: Market Purchase
	var koku_status: int = current_ledger.get("koku", {}).get("status", ResourceStatus.RED)
	var r3: Dictionary = try_market_purchase(working_inputs, koku_status, has_trade_routes)
	rungs_tried.append(r3)
	if r3.get("applied", false) and r3.get("ledger", {}).get("feasible", false):
		return {
			"outcome": "market_purchase",
			"rungs_tried": rungs_tried,
			"final_ledger": r3["ledger"],
			"modified_inputs": r3["modified_inputs"],
		}
	if r3.get("applied", false):
		working_inputs = r3["modified_inputs"]
		current_ledger = r3["ledger"]

	# Rung 4: Demand Tribute
	var r4: Dictionary = try_demand_tribute(working_inputs, primary_virtue, vassal_stockpiles)
	rungs_tried.append(r4)
	if r4.get("applied", false) and r4.get("ledger", {}).get("feasible", false):
		return {
			"outcome": "demanded_tribute",
			"rungs_tried": rungs_tried,
			"final_ledger": r4["ledger"],
			"modified_inputs": r4["modified_inputs"],
			"side_effects": _extract_side_effects(r4),
		}
	if r4.get("applied", false):
		working_inputs = r4["modified_inputs"]
		current_ledger = r4["ledger"]

	# Rung 5: Allied Aid
	var r5: Dictionary = try_request_allied_aid(working_inputs, primary_virtue, allied_surplus)
	rungs_tried.append(r5)
	if r5.get("applied", false) and r5.get("ledger", {}).get("feasible", false):
		return {
			"outcome": "allied_aid",
			"rungs_tried": rungs_tried,
			"final_ledger": r5["ledger"],
			"modified_inputs": r5["modified_inputs"],
			"side_effects": _extract_side_effects(r5),
		}
	if r5.get("applied", false):
		working_inputs = r5["modified_inputs"]
		current_ledger = r5["ledger"]

	# Rung 6: Raid Neighbor
	var r6: Dictionary = try_raid_neighbor(
		working_inputs, primary_virtue, has_grievance, has_issued_demand,
		raidable_provinces,
	)
	rungs_tried.append(r6)
	if r6.get("applied", false) and r6.get("ledger", {}).get("feasible", false):
		return {
			"outcome": "raid_neighbor",
			"rungs_tried": rungs_tried,
			"final_ledger": r6["ledger"],
			"modified_inputs": r6["modified_inputs"],
			"side_effects": _extract_side_effects(r6),
		}
	if r6.get("applied", false):
		working_inputs = r6["modified_inputs"]
		current_ledger = r6["ledger"]

	# Rung 7: Desperation Override
	var rice_per_pu: float = current_ledger.get("rice", {}).get("per_pu", 1.0)
	var r7: Dictionary = try_desperation_override(
		working_inputs, primary_virtue, rice_per_pu,
		has_critical_objective, war_score, is_defending,
	)
	rungs_tried.append(r7)
	if r7.get("applied", false) and r7.get("overrides_feasibility", false):
		return {
			"outcome": "desperation_override",
			"rungs_tried": rungs_tried,
			"final_ledger": current_ledger,
			"desperation_levy": true,
			"side_effects": _extract_side_effects(r7),
		}

	return {
		"outcome": "abandoned",
		"rungs_tried": rungs_tried,
		"final_ledger": current_ledger,
	}


static func _extract_side_effects(rung_result: Dictionary) -> Dictionary:
	var effects: Dictionary = {}
	effects["rung"] = rung_result.get("rung", -1)
	if rung_result.get("generates_topic", false):
		effects["generates_topic"] = true
		effects["topic_tier"] = rung_result.get("topic_tier", 4)
	if rung_result.has("honor_cost"):
		effects["honor_cost"] = rung_result["honor_cost"]
	if rung_result.has("glory_cost"):
		effects["glory_cost"] = rung_result["glory_cost"]
	if rung_result.has("disposition_cost"):
		effects["disposition_cost"] = rung_result["disposition_cost"]
	if rung_result.has("clan_disposition_cost"):
		effects["clan_disposition_cost"] = rung_result["clan_disposition_cost"]
	if rung_result.has("other_disposition_cost"):
		effects["other_disposition_cost"] = rung_result["other_disposition_cost"]
	if rung_result.get("creates_favor", false):
		effects["creates_favor"] = true
		effects["favor_tier"] = rung_result.get("favor_tier", 3)
		effects["contributing_ally_ids"] = rung_result.get("contributing_ally_ids", [])
	if rung_result.get("triggers_war_status", false):
		effects["triggers_war_status"] = true
		effects["raid_target_clan"] = rung_result.get("target_clan", "")
		effects["raid_target_province_id"] = rung_result.get("target_province_id", -1)
	if rung_result.get("desperation_levy", false):
		effects["desperation_levy"] = true
	return effects


# =============================================================================
# Phase 3: Mid-Campaign Supply Status Monitor (s4.3.17)
# =============================================================================
# Seasonal survival assessment of fielded armies and settlements feeding them.
# Three checks: Home Front Status, Army Supply Status, Iron Upkeep Status.
# Response matrix combines Home Front × Army Supply to produce AI decisions.

enum HomeFrontStatus {
	CLEAR,
	SHORTAGE,
	HUNGER,
	FAMINE,
}

enum ArmySupplyStatus {
	SUPPLIED,
	UNSUPPLIED,
}

enum IronUpkeepStatus {
	MAINTAINED,
	DEGRADING,
}

enum CampaignDecision {
	CONTINUE,
	PUSH_TO_FINISH,
	SEEK_PEACE,
	URGENT_PEACE,
	IMMEDIATE_PEACE,
	RESTORE_TETHER,
	RETREAT,
}


const SHORTAGE_RICE_PER_PU: float = 1.00
const HUNGER_RICE_PER_PU: float = 0.50
const FAMINE_RICE_PER_PU: float = 0.0

const WINNING_THRESHOLD: int = 65

const SHORTAGE_IGNORE_VIRTUES: Array[String] = ["Yu", "Kyoryoku", "Ishi"]
const HUNGER_CONTINUE_VIRTUES: Array[String] = ["Ishi"]
const FAMINE_CONTINUE_VIRTUES: Array[String] = ["Ishi"]

const TETHER_HOLD_EXTRA_VIRTUES: Array[String] = ["Ketsui"]
const TETHER_HOLD_SEASONS_DEFAULT: int = 1
const TETHER_HOLD_SEASONS_KETSUI: int = 2


# -- Check 1: Home Front Status -----------------------------------------------

static func assess_home_front(
	controlled_settlements: Array,
) -> Dictionary:
	var worst: int = HomeFrontStatus.CLEAR
	var worst_settlement_id: int = -1

	for s: Variant in controlled_settlements:
		if not (s is SettlementData):
			continue
		var sd: SettlementData = s
		var civilian_pu: float = float(sd.farming_pu + sd.mining_pu + sd.town_pu)
		if civilian_pu <= 0.0:
			continue
		var rice_per_pu: float = sd.rice_stockpile / civilian_pu
		var status: int = HomeFrontStatus.CLEAR
		if rice_per_pu <= FAMINE_RICE_PER_PU:
			status = HomeFrontStatus.FAMINE
		elif rice_per_pu <= HUNGER_RICE_PER_PU:
			status = HomeFrontStatus.HUNGER
		elif rice_per_pu < SHORTAGE_RICE_PER_PU:
			status = HomeFrontStatus.SHORTAGE
		if status > worst:
			worst = status
			worst_settlement_id = sd.settlement_id

	return {
		"status": worst,
		"worst_settlement_id": worst_settlement_id,
	}


# -- Check 2: Army Supply Status -----------------------------------------------

static func assess_army_supply(
	tether_state: int,
	source_has_rice: bool,
) -> Dictionary:
	var supplied: bool = tether_state == 0 and source_has_rice
	return {
		"status": ArmySupplyStatus.SUPPLIED if supplied else ArmySupplyStatus.UNSUPPLIED,
		"tether_intact": tether_state == 0,
		"source_has_rice": source_has_rice,
	}


# -- Check 3: Iron Upkeep Status -----------------------------------------------

static func assess_iron_upkeep(
	clan_iron_stockpile: float,
	total_iron_upkeep: float,
) -> Dictionary:
	var maintained: bool = clan_iron_stockpile >= total_iron_upkeep
	return {
		"status": IronUpkeepStatus.MAINTAINED if maintained else IronUpkeepStatus.DEGRADING,
		"deficit": maxf(0.0, total_iron_upkeep - clan_iron_stockpile),
	}


# -- Response Matrix -----------------------------------------------------------

static func determine_campaign_decision(
	home_front: int,
	army_supply: int,
	primary_virtue: String,
	war_score: int,
	seasons_tether_cut: int = 0,
) -> Dictionary:
	if army_supply == ArmySupplyStatus.UNSUPPLIED:
		var hold_limit: int = TETHER_HOLD_SEASONS_DEFAULT
		if primary_virtue in TETHER_HOLD_EXTRA_VIRTUES:
			hold_limit = TETHER_HOLD_SEASONS_KETSUI
		if seasons_tether_cut < hold_limit:
			return {
				"decision": CampaignDecision.RESTORE_TETHER,
				"reason": "supply_cut",
				"hold_seasons_remaining": hold_limit - seasons_tether_cut,
			}
		return {
			"decision": CampaignDecision.RETREAT,
			"reason": "tether_restoration_failed",
		}

	match home_front:
		HomeFrontStatus.CLEAR:
			return {
				"decision": CampaignDecision.CONTINUE,
				"reason": "all_clear",
			}

		HomeFrontStatus.SHORTAGE:
			if primary_virtue in SHORTAGE_IGNORE_VIRTUES:
				return {
					"decision": CampaignDecision.CONTINUE,
					"reason": "personality_ignores_shortage",
				}
			if war_score >= WINNING_THRESHOLD:
				return {
					"decision": CampaignDecision.PUSH_TO_FINISH,
					"reason": "shortage_but_winning",
				}
			return {
				"decision": CampaignDecision.SEEK_PEACE,
				"reason": "shortage_not_winning",
			}

		HomeFrontStatus.HUNGER:
			if primary_virtue in HUNGER_CONTINUE_VIRTUES:
				return {
					"decision": CampaignDecision.CONTINUE,
					"reason": "personality_ignores_hunger",
				}
			return {
				"decision": CampaignDecision.URGENT_PEACE,
				"reason": "hunger_at_home",
			}

		HomeFrontStatus.FAMINE:
			if primary_virtue in FAMINE_CONTINUE_VIRTUES:
				return {
					"decision": CampaignDecision.CONTINUE,
					"reason": "personality_ignores_famine",
				}
			return {
				"decision": CampaignDecision.IMMEDIATE_PEACE,
				"reason": "famine_at_home",
			}

	return {
		"decision": CampaignDecision.CONTINUE,
		"reason": "default",
	}


# -- Retreat Target Selection --------------------------------------------------

static func find_retreat_target(
	_army_province_id: int,
	friendly_provinces: Array,
	max_distance: int = 2,
) -> Dictionary:
	var best_id: int = -1
	var best_score: float = -1.0

	for fp: Variant in friendly_provinces:
		if not (fp is Dictionary):
			continue
		var fpd: Dictionary = fp
		var dist: int = fpd.get("distance", 99)
		if dist > max_distance:
			continue
		var rice_per_pu: float = fpd.get("rice_per_pu", 0.0)
		var has_forge: bool = fpd.get("has_forge", false)
		if rice_per_pu < 1.0 and not has_forge:
			continue
		var score: float = rice_per_pu + (5.0 if has_forge else 0.0) - float(dist)
		if score > best_score:
			best_score = score
			best_id = fpd.get("province_id", -1)

	if best_id < 0:
		return {"found": false, "should_disband": true}
	return {"found": true, "province_id": best_id, "should_disband": false}


# -- Full Supply Status Check --------------------------------------------------

static func run_supply_status_check(inputs: Dictionary) -> Dictionary:
	var settlements: Array = inputs.get("controlled_settlements", [])
	var tether_state: int = inputs.get("tether_state", 0)
	var source_has_rice: bool = inputs.get("source_has_rice", true)
	var clan_iron: float = inputs.get("clan_iron_stockpile", 0.0)
	var total_iron_upkeep: float = inputs.get("total_iron_upkeep", 0.0)
	var primary_virtue: String = inputs.get("primary_virtue", "")
	var war_score: int = inputs.get("war_score", 50)
	var seasons_tether_cut: int = inputs.get("seasons_tether_cut", 0)

	var home: Dictionary = assess_home_front(settlements)
	var army: Dictionary = assess_army_supply(tether_state, source_has_rice)
	var iron: Dictionary = assess_iron_upkeep(clan_iron, total_iron_upkeep)

	var decision: Dictionary = determine_campaign_decision(
		home["status"], army["status"], primary_virtue, war_score,
		seasons_tether_cut,
	)

	return {
		"home_front": home,
		"army_supply": army,
		"iron_upkeep": iron,
		"decision": decision,
	}
