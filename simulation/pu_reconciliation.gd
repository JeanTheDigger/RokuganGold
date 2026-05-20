class_name PUReconciliation
## PU reconciliation between military companies and source settlements per
## GDD s11.7 "Battle → World Map: PU Reconciliation — LOCKED".
## Every company is tagged to its source province/settlement at levy time.
## Health lost = PU lost. Health remaining on disband = PU returned.
## Victor post-battle: 10% recovered to companies, 10% returned as PU,
## 80% permanently dead. Ronin have no source — no PU exchange.
## Pure static functions. Caller owns all state.


const COMPANY_STARTING_HEALTH: int = 153
const PU_PER_COMPANY: float = 1.0
const HEALTH_TO_PU: float = PU_PER_COMPANY / float(COMPANY_STARTING_HEALTH)

const RECOVERY_RATE: float = 0.10
const RETURN_RATE: float = 0.10
const DEAD_RATE: float = 0.80


# -- Levy Consumption ------------------------------------------------------------

static func consume_levy_pu(
	settlement: SettlementData,
	count: int = 1,
) -> Dictionary:
	var pu_cost: float = PU_PER_COMPANY * count
	var old_military: int = settlement.military_pu
	var old_pop: int = settlement.population_pu

	var actual_deducted: int = mini(ceili(pu_cost), settlement.military_pu)
	settlement.military_pu -= actual_deducted
	settlement.population_pu -= actual_deducted

	return {
		"settlement_id": settlement.settlement_id,
		"pu_consumed": actual_deducted,
		"old_military_pu": old_military,
		"new_military_pu": settlement.military_pu,
		"old_population_pu": old_pop,
		"new_population_pu": settlement.population_pu,
	}


# -- Disband Return --------------------------------------------------------------

static func return_disband_pu(
	settlement: SettlementData,
	company_health: int,
) -> Dictionary:
	var ratio: float = float(company_health) / float(COMPANY_STARTING_HEALTH)
	var pu_returned: float = PU_PER_COMPANY * clampf(ratio, 0.0, 1.0)
	var pu_int: int = maxi(floori(pu_returned), 0)

	settlement.military_pu += pu_int
	settlement.population_pu += pu_int

	return {
		"settlement_id": settlement.settlement_id,
		"health_at_disband": company_health,
		"pu_returned": pu_int,
		"pu_fraction_lost": PU_PER_COMPANY - pu_returned,
	}


# -- Battle Casualty Processing --------------------------------------------------

static func compute_company_pu_loss(
	starting_health: int,
	current_health: int,
) -> float:
	var health_lost: int = maxi(starting_health - current_health, 0)
	return float(health_lost) * HEALTH_TO_PU


static func process_battle_casualties(
	battle_companies: Array,
	settlements_by_province: Dictionary,
) -> Dictionary:
	var pu_losses: Dictionary = {}
	var total_dead_pu: float = 0.0
	var ronin_losses: float = 0.0

	for bc: Dictionary in battle_companies:
		var source_id: int = bc.get("source_province_id", -1)
		var starting: int = bc.get("starting_health", COMPANY_STARTING_HEALTH)
		var current: int = maxi(bc.get("current_health", 0), 0)
		var health_lost: int = maxi(starting - current, 0)
		var pu_loss: float = float(health_lost) * HEALTH_TO_PU

		if source_id < 0:
			ronin_losses += pu_loss
			continue

		if not pu_losses.has(source_id):
			pu_losses[source_id] = 0.0
		pu_losses[source_id] += pu_loss
		total_dead_pu += pu_loss

	var settlement_mutations: Array = []
	for province_id: int in pu_losses:
		var loss_pu: int = maxi(floori(pu_losses[province_id]), 0)
		if loss_pu <= 0:
			continue

		var settlements: Array = settlements_by_province.get(province_id, [])
		if settlements.is_empty():
			continue

		var mutation: Dictionary = _distribute_pu_loss(settlements, loss_pu)
		mutation["province_id"] = province_id
		mutation["total_loss"] = loss_pu
		settlement_mutations.append(mutation)

	return {
		"pu_losses_by_province": pu_losses,
		"total_dead_pu": total_dead_pu,
		"ronin_losses_pu": ronin_losses,
		"settlement_mutations": settlement_mutations,
	}


# -- Post-Battle Recovery (Victor Only) ------------------------------------------

static func process_victor_recovery(
	victor_companies: Array,
	settlements_by_province: Dictionary,
) -> Dictionary:
	var total_lost: int = 0
	for bc: Dictionary in victor_companies:
		var starting: int = bc.get("starting_health", COMPANY_STARTING_HEALTH)
		var current: int = maxi(bc.get("current_health", 0), 0)
		total_lost += maxi(starting - current, 0)

	var recovered_health: int = ceili(float(total_lost) * RECOVERY_RATE)
	var returned_health: int = ceili(float(total_lost) * RETURN_RATE)
	var dead_health: int = total_lost - recovered_health - returned_health

	var returned_pu_by_province: Dictionary = {}
	var total_returned_pu: float = 0.0

	for bc: Dictionary in victor_companies:
		var starting: int = bc.get("starting_health", COMPANY_STARTING_HEALTH)
		var current: int = maxi(bc.get("current_health", 0), 0)
		var company_lost: int = maxi(starting - current, 0)
		if company_lost <= 0:
			continue

		var proportion: float = float(company_lost) / float(total_lost) if total_lost > 0 else 0.0
		var company_returned_health: int = ceili(float(returned_health) * proportion)
		var company_returned_pu: float = float(company_returned_health) * HEALTH_TO_PU

		var source_id: int = bc.get("source_province_id", -1)
		if source_id < 0:
			continue

		if not returned_pu_by_province.has(source_id):
			returned_pu_by_province[source_id] = 0.0
		returned_pu_by_province[source_id] += company_returned_pu
		total_returned_pu += company_returned_pu

	var settlement_mutations: Array = []
	for province_id: int in returned_pu_by_province:
		var return_pu: int = maxi(floori(returned_pu_by_province[province_id]), 0)
		if return_pu <= 0:
			continue

		var settlements: Array = settlements_by_province.get(province_id, [])
		if settlements.is_empty():
			continue

		var mutation: Dictionary = _distribute_pu_gain(settlements, return_pu)
		mutation["province_id"] = province_id
		mutation["total_returned"] = return_pu
		settlement_mutations.append(mutation)

	return {
		"total_health_lost": total_lost,
		"recovered_to_companies": recovered_health,
		"returned_as_pu_health": returned_health,
		"permanently_dead_health": dead_health,
		"returned_pu_by_province": returned_pu_by_province,
		"total_returned_pu": total_returned_pu,
		"settlement_mutations": settlement_mutations,
	}


# -- Full Battle PU Reconciliation -----------------------------------------------

static func reconcile_battle(
	victor_companies: Array,
	loser_companies: Array,
	settlements_by_province: Dictionary,
) -> Dictionary:
	var all_companies: Array = []
	all_companies.append_array(victor_companies)
	all_companies.append_array(loser_companies)

	var casualties: Dictionary = process_battle_casualties(
		all_companies, settlements_by_province,
	)

	var recovery: Dictionary = process_victor_recovery(
		victor_companies, settlements_by_province,
	)

	return {
		"casualties": casualties,
		"recovery": recovery,
	}


# -- Army Dissolution PU Return --------------------------------------------------

static func process_army_dissolution(
	companies: Array,
	settlements_by_province: Dictionary,
) -> Dictionary:
	var returned_by_province: Dictionary = {}
	var total_returned: float = 0.0
	var ronin_lost: float = 0.0

	for bc: Dictionary in companies:
		var current: int = maxi(bc.get("current_health", 0), 0)
		var source_id: int = bc.get("source_province_id", -1)
		var pu_remaining: float = float(current) * HEALTH_TO_PU

		if source_id < 0:
			ronin_lost += pu_remaining
			continue

		if not returned_by_province.has(source_id):
			returned_by_province[source_id] = 0.0
		returned_by_province[source_id] += pu_remaining
		total_returned += pu_remaining

	var settlement_mutations: Array = []
	for province_id: int in returned_by_province:
		var return_pu: int = maxi(floori(returned_by_province[province_id]), 0)
		if return_pu <= 0:
			continue

		var settlements: Array = settlements_by_province.get(province_id, [])
		if settlements.is_empty():
			continue

		var mutation: Dictionary = _distribute_pu_gain(settlements, return_pu)
		mutation["province_id"] = province_id
		mutation["total_returned"] = return_pu
		settlement_mutations.append(mutation)

	return {
		"returned_by_province": returned_by_province,
		"total_returned_pu": total_returned,
		"ronin_lost_pu": ronin_lost,
		"settlement_mutations": settlement_mutations,
	}


# -- Settlement PU Distribution Helpers ------------------------------------------

static func _distribute_pu_loss(
	settlements: Array,
	loss_pu: int,
) -> Dictionary:
	var per_settlement: Dictionary = {}
	var remaining: int = loss_pu

	for s: SettlementData in settlements:
		if remaining <= 0:
			break
		var deductible: int = mini(remaining, s.military_pu)
		if deductible > 0:
			s.military_pu -= deductible
			s.population_pu -= deductible
			remaining -= deductible
			per_settlement[s.settlement_id] = deductible

	if remaining > 0:
		for s: SettlementData in settlements:
			if remaining <= 0:
				break
			var available: int = maxi(s.population_pu, 0)
			var deductible: int = mini(remaining, available)
			if deductible > 0:
				s.population_pu -= deductible
				remaining -= deductible
				per_settlement[s.settlement_id] = per_settlement.get(s.settlement_id, 0) + deductible

	per_settlement["unallocated"] = remaining
	return per_settlement


static func _distribute_pu_gain(
	settlements: Array,
	gain_pu: int,
) -> Dictionary:
	var per_settlement: Dictionary = {}
	if settlements.is_empty():
		per_settlement["unallocated"] = gain_pu
		return per_settlement

	var primary: SettlementData = settlements[0]
	primary.military_pu += gain_pu
	primary.population_pu += gain_pu
	per_settlement[primary.settlement_id] = gain_pu
	return per_settlement
