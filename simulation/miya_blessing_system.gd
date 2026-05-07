class_name MiyaBlessingSystem
## Annual Miya's Blessing per GDD s11.5b. Fires at the start of Spring,
## after planting and before rice consumption. Withdraws Rice from the
## Emperor's settlement stockpile and deposits it into three provinces
## judged most in need.
##
## Pure simulation class — no Node inheritance, no scene tree.
## Callers (DayOrchestrator) supply the inputs; this system computes
## allocation, selection, distribution, and returns a result dict that
## the caller applies to world state.


# -- Blessing rate by Emperor archetype (s11.5b §5) --------------------------

const BLESSING_RATE: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: 0.20,
	StrategicReview.EmperorArchetype.IRON: 0.15,
	StrategicReview.EmperorArchetype.CUNNING: 0.10,
	StrategicReview.EmperorArchetype.WARLIKE: 0.05,
	StrategicReview.EmperorArchetype.TYRANT: 0.00,
}


# -- Allocation thresholds (s11.5b §2) ---------------------------------------

const MIN_THRESHOLD: float = 0.50          # Total below this → suspended.
const MAX_PROVINCE_CAP: float = 5.0        # Per-province ceiling.
const MAX_TOTAL: float = MAX_PROVINCE_CAP * 3.0
const OU_RESERVE_MULTIPLIER: float = 0.25  # Otosan Uchi PU × 0.25 = season buffer floor.

const PROVINCES_SELECTED: int = 3


# -- Need score weights (s11.5b §4.1) ----------------------------------------

const NEED_SHORTAGE: int = 5
const NEED_HUNGER: int = 10
const NEED_FAMINE: int = 20
const NEED_STABILITY_RESTLESS: int = 2     # 51–75
const NEED_STABILITY_VOLATILE: int = 5     # 26–50
const NEED_STABILITY_BROKEN: int = 10      # 0–25
const NEED_ACTIVE_WAR: int = 5
const NEED_RAIDED: int = 3
const NEED_INSURGENCY: int = 3
const NEED_PU_DECLINE_10: int = 5
const NEED_PU_DECLINE_25: int = 10
const NEED_NOT_BLESSED_LAST_YEAR: int = 2
const NEED_BLESSED_LAST_YEAR_MALUS: int = -5

const PETITION_BONUS_BASE: int = 8
const PETITION_BONUS_PER_RAISE: int = 2


# -- Application bonuses (s11.5b §6) -----------------------------------------

const STABILITY_BONUS: int = 5
const POP_GROWTH_BONUS: float = 0.01


# -- Disposition deltas (s11.5b §7) ------------------------------------------

const DISP_MIYA_FROM_SELECTED_LORD: int = 2
const DISP_EMPEROR_FROM_SELECTED_LORD: int = 1
const DISP_MIYA_TOWARD_EMPEROR_ON_SUSPENSION: int = -3
const DISP_EMPIRE_TOWARD_EMPEROR_ON_SUSPENSION: int = -1
const STABILITY_PENALTY_NEEDY_PROVINCE_ON_SUSPENSION: int = -1


# -- Allocation calculation (§2.1, §2.2, §2.3, §2.4) -------------------------

static func compute_blessing_rate(
	archetype: StrategicReview.EmperorArchetype,
) -> float:
	return BLESSING_RATE.get(archetype, 0.0)


static func compute_allocation(
	emperor_autumn_tax_income: float,
	blessing_rate: float,
	emperor_stockpile: float,
	otosan_uchi_pu: float,
) -> float:
	## Returns the total Rice that may be paid out across the three provinces
	## this Spring. Returns 0.0 when the Blessing is suspended (below
	## MIN_THRESHOLD or below the Imperial reserve floor).
	var raw: float = emperor_autumn_tax_income * blessing_rate
	# Apply the per-year ceiling.
	raw = minf(raw, MAX_TOTAL)
	# Stockpile constraint: must keep at least OU_PU * 0.25 in reserve.
	var reserve_floor: float = otosan_uchi_pu * OU_RESERVE_MULTIPLIER
	var available: float = maxf(emperor_stockpile - reserve_floor, 0.0)
	var allocation: float = minf(raw, available)
	# Minimum-threshold check is the caller's concern — exposed via
	# `is_suspended()` so the suspension topic and consequences fire cleanly.
	return maxf(allocation, 0.0)


static func is_suspended(allocation: float) -> bool:
	return allocation < MIN_THRESHOLD


# -- Need score (§4.1) -------------------------------------------------------

static func get_stability_need(stability: float) -> int:
	if stability <= 25.0:
		return NEED_STABILITY_BROKEN
	if stability <= 50.0:
		return NEED_STABILITY_VOLATILE
	if stability <= 75.0:
		return NEED_STABILITY_RESTLESS
	return 0


static func get_starvation_need(worst_stage: int) -> int:
	## worst_stage uses ResourceTick.StarvationStage values:
	## 0 = CLEAR, 1 = SHORTAGE, 2 = HUNGER, 3 = FAMINE.
	match worst_stage:
		ResourceTick.StarvationStage.SHORTAGE:
			return NEED_SHORTAGE
		ResourceTick.StarvationStage.HUNGER:
			return NEED_HUNGER
		ResourceTick.StarvationStage.FAMINE:
			return NEED_FAMINE
	return 0


static func get_pu_decline_need(decline_pct: float) -> int:
	if decline_pct >= 0.25:
		return NEED_PU_DECLINE_25
	if decline_pct >= 0.10:
		return NEED_PU_DECLINE_10
	return 0


static func compute_need_score(conditions: Dictionary) -> int:
	## conditions is a dict with the following keys (all optional, all int/float
	## except blessed flags which are bool):
	##   stability: float            (province stability 0–100)
	##   worst_starvation_stage: int (ResourceTick.StarvationStage)
	##   had_active_war: bool        (during the previous IC year)
	##   had_raid: bool              (during the previous IC year)
	##   has_insurgency: bool        (active right now)
	##   pu_decline_pct: float       (0.0–1.0; e.g. 0.18 = 18% decline)
	##   blessed_last_year: bool
	##   blessed_two_years_ago: bool (unused — kept for caller compatibility)
	##   petition_bonus: int         (winter-court petition contributions)
	var score: int = 0
	score += get_starvation_need(conditions.get("worst_starvation_stage", 0))
	score += get_stability_need(conditions.get("stability", 100.0))
	if conditions.get("had_active_war", false):
		score += NEED_ACTIVE_WAR
	if conditions.get("had_raid", false):
		score += NEED_RAIDED
	if conditions.get("has_insurgency", false):
		score += NEED_INSURGENCY
	score += get_pu_decline_need(conditions.get("pu_decline_pct", 0.0))
	if conditions.get("blessed_last_year", false):
		score += NEED_BLESSED_LAST_YEAR_MALUS
	else:
		score += NEED_NOT_BLESSED_LAST_YEAR
	score += int(conditions.get("petition_bonus", 0))
	return score


# -- Province selection (§4.2, §4.3) -----------------------------------------

static func is_excluded(conditions: Dictionary) -> bool:
	## Shadowlands (Taint above the maho cult spawn threshold) and provinces
	## in active rebellion against the Emperor are excluded.
	if conditions.get("in_rebellion", false):
		return true
	if conditions.get("over_taint_threshold", false):
		return true
	return false


static func select_provinces(
	scored: Array[Dictionary],
) -> Array[int]:
	## scored is an array of dicts shaped:
	##   {
	##     "province_id": int,
	##     "score": int,
	##     "stability": float,
	##     "population_pu": float,
	##     "excluded": bool,   # set by is_excluded()
	##   }
	## Returns up to PROVINCES_SELECTED province_ids ordered by score desc,
	## tiebroken by lowest stability, then by smaller population PU.
	var eligible: Array[Dictionary] = []
	for entry in scored:
		if entry.get("excluded", false):
			continue
		eligible.append(entry)
	eligible.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["stability"] != b["stability"]:
			return a["stability"] < b["stability"]
		return a["population_pu"] < b["population_pu"]
	)
	var selected: Array[int] = []
	for entry in eligible:
		if selected.size() >= PROVINCES_SELECTED:
			break
		selected.append(int(entry["province_id"]))
	return selected


# -- Petition resolution (§4.3) ----------------------------------------------

static func compute_petition_bonus(success: bool, raises: int) -> int:
	## Winter Court petition: Courtier (Manipulation) / Awareness vs TN 25.
	## Success adds +8, each Raise adds +2 more. Failure contributes 0.
	if not success:
		return 0
	return PETITION_BONUS_BASE + (PETITION_BONUS_PER_RAISE * maxi(raises, 0))


# -- Distribution (§2.5, §6.1) -----------------------------------------------

static func distribute_to_settlements(
	settlements: Array,
	rice_for_province: float,
) -> Dictionary:
	## Returns { settlement_id: float } share of the province's allocation
	## proportional to each settlement's population_pu. Settlements with 0 PU
	## are skipped. Returns an empty dict if no eligible settlements.
	var shares: Dictionary = {}
	if rice_for_province <= 0.0 or settlements.is_empty():
		return shares
	var total_pu: float = 0.0
	for s in settlements:
		total_pu += float(s.population_pu)
	if total_pu <= 0.0:
		return shares
	for s in settlements:
		var pu: float = float(s.population_pu)
		if pu <= 0.0:
			continue
		shares[s.settlement_id] = rice_for_province * (pu / total_pu)
	return shares


# -- Top-level orchestration -------------------------------------------------
#
# inputs dict shape:
#   {
#     "emperor_archetype": StrategicReview.EmperorArchetype,
#     "emperor_autumn_tax_income": float,
#     "emperor_stockpile": float,
#     "otosan_uchi_pu": float,
#     "scored_provinces": Array[Dictionary],   # see select_provinces()
#     "province_settlements": Dictionary,      # province_id: int -> Array[SettlementData]
#   }
#
# Returns:
#   {
#     "fired": bool,
#     "suspended": bool,
#     "suspension_reason": String,             # "" | "tyrant_archetype" | "below_threshold"
#     "allocation_total": float,
#     "allocation_per_province": float,
#     "selected_province_ids": Array[int],
#     "settlement_rice_grants": Dictionary,    # settlement_id: int -> float
#     "stability_bonus": int,                  # STABILITY_BONUS for selected provinces
#     "pop_growth_bonus": float,               # POP_GROWTH_BONUS, one-season
#   }

static func process_annual_blessing(inputs: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"fired": false,
		"suspended": false,
		"suspension_reason": "",
		"allocation_total": 0.0,
		"allocation_per_province": 0.0,
		"selected_province_ids": [] as Array[int],
		"settlement_rice_grants": {},
		"stability_bonus": STABILITY_BONUS,
		"pop_growth_bonus": POP_GROWTH_BONUS,
	}

	var archetype: StrategicReview.EmperorArchetype = inputs.get(
		"emperor_archetype", StrategicReview.EmperorArchetype.IRON
	)
	var rate: float = compute_blessing_rate(archetype)

	if rate <= 0.0:
		result["suspended"] = true
		result["suspension_reason"] = "tyrant_archetype"
		return result

	var allocation: float = compute_allocation(
		float(inputs.get("emperor_autumn_tax_income", 0.0)),
		rate,
		float(inputs.get("emperor_stockpile", 0.0)),
		float(inputs.get("otosan_uchi_pu", 0.0)),
	)

	if is_suspended(allocation):
		result["suspended"] = true
		result["suspension_reason"] = "below_threshold"
		result["allocation_total"] = allocation
		return result

	# Cap at the per-province × 3 ceiling (defensive — compute_allocation
	# already enforces the cap, but rounding on long chains shouldn't slip).
	allocation = minf(allocation, MAX_TOTAL)
	var per_province: float = allocation / float(PROVINCES_SELECTED)

	var scored_array: Array[Dictionary] = []
	for entry in inputs.get("scored_provinces", []):
		scored_array.append(entry)
	var selected_ids: Array[int] = select_provinces(scored_array)
	if selected_ids.is_empty():
		# No eligible recipient — the allocation stays in the Emperor's stockpile.
		result["allocation_total"] = allocation
		return result

	# If fewer than PROVINCES_SELECTED are eligible, only the selected ones
	# receive shares. The remaining allocation stays in the stockpile per
	# §9 ("unallocated Rice stays in Emperor's stockpile").
	var per_province_actual: float = minf(per_province, MAX_PROVINCE_CAP)
	var fired_total: float = per_province_actual * float(selected_ids.size())

	var settlement_grants: Dictionary = {}
	var province_settlements: Dictionary = inputs.get("province_settlements", {})
	for pid in selected_ids:
		var settlements: Array = province_settlements.get(pid, [])
		var shares: Dictionary = distribute_to_settlements(settlements, per_province_actual)
		for sid in shares:
			settlement_grants[sid] = settlement_grants.get(sid, 0.0) + shares[sid]

	result["fired"] = true
	result["allocation_total"] = fired_total
	result["allocation_per_province"] = per_province_actual
	result["selected_province_ids"] = selected_ids
	result["settlement_rice_grants"] = settlement_grants
	return result
