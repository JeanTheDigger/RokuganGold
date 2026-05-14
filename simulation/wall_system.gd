class_name WallSystem
## Kaiu Wall mechanics per GDD s2.4.2, s2.4.3, s2.4.10, s2.4.11, s2.4.15.
## Pure static functions — caller owns all SettlementData and ProvinceData.
## Seasonal pressure, Shadowlands Strength tiers, sortie precondition checks,
## and SI defense bonus lookups are all here. Combat resolution against a
## Jigoku Horde is deferred until s2.4.7 Horde generation is implemented.


# -- SI Defense Bonus Table (s2.4.2 — LOCKED) ----------------------------------

const SI_DEFENSE_BONUS: Dictionary = {
	10: 12,
	9: 10, 8: 10,
	7: 7, 6: 7,
	5: 4, 4: 4,
	3: 1, 2: 1,
	1: 0, 0: 0,
}


# -- Seasonal Pressure Constants (s2.4.3 — LOCKED) ----------------------------

const SEASONAL_SI_DECAY: Dictionary = {
	"spring": 1, "summer": 0, "autumn": 1, "winter": 2,
}

const SEASONAL_KOKU_COST: Dictionary = {
	"spring": 2, "summer": 1, "autumn": 2, "winter": 3,
}

const SEASONAL_RICE_MODIFIER: Dictionary = {
	"spring": 1.0, "summer": 1.0, "autumn": 1.2, "winter": 1.5,
}

# SI at or below this value triggers adjacent bleed per s2.4.3.
const ADJACENT_BLEED_THRESHOLD: int = 4
const ADJACENT_BLEED_AMOUNT: float = 0.5

# SI at or below this value is considered "degraded" and adds extra PTL per s2.4.2.
const SI_DEGRADED_THRESHOLD: int = 5
const PTL_BASELINE_PER_SEASON: float = 0.1
const PTL_DEGRADED_EXTRA_PER_SEASON: float = 0.5


# -- Shadowlands Strength (SS) Constants (s2.4.10 — LOCKED) -------------------

const SS_LOW_MAX: int = 4
const SS_MEDIUM_MAX: int = 8
# High SS is anything above SS_MEDIUM_MAX (no ceiling).

const SS_MEDIUM_ADDITIONAL_SI_DECAY: float = 0.5
const SS_HIGH_ADDITIONAL_SI_DECAY: float = 1.0

const SS_MEDIUM_ADDITIONAL_KOKU: int = 1
const SS_HIGH_ADDITIONAL_KOKU: int = 2

const SS_MEDIUM_RICE_MODIFIER: float = 1.1
const SS_HIGH_RICE_MODIFIER: float = 1.2


# -- Garrison Threshold (s2.4.2 — PROVISIONAL) --------------------------------
# Minimum defensible garrison: 1 full Company (153 Health = 1.0 PU).
# Marked PROVISIONAL in GDD — may be revised after playtesting.
const MINIMUM_GARRISON_PU: float = 1.0

## Returns true when garrison is below the minimum defensible threshold.
static func is_garrison_below_minimum(garrison_pu: int) -> bool:
	return float(garrison_pu) < MINIMUM_GARRISON_PU


# -- Sortie Constants (s2.4.10, s2.4.11, s2.4.15 — LOCKED) -------------------

const SORTIE_SMALL_MIN_PCT: float = 0.10
const SORTIE_SMALL_MAX_PCT: float = 0.20
const SORTIE_SMALL_SS_REDUCTION: int = 1
const SORTIE_SMALL_JADE_PER_WARRIOR: int = 1  # "1 finger per warrior" (s2.4.15)

const SORTIE_MEDIUM_MIN_PCT: float = 0.21
const SORTIE_MEDIUM_MAX_PCT: float = 0.40
const SORTIE_MEDIUM_SS_REDUCTION: int = 2
const SORTIE_MEDIUM_JADE_PER_WARRIOR: int = 2  # "2 fingers per warrior" (s2.4.15)

const SORTIE_LARGE_MIN_PCT: float = 0.41
const SORTIE_LARGE_MAX_PCT: float = 0.60
const SORTIE_LARGE_SS_REDUCTION: int = 3
const SORTIE_LARGE_JADE_PER_WARRIOR: int = 3  # "3 fingers per warrior" (s2.4.15)


# -- SS Tier Queries -----------------------------------------------------------

static func get_ss_tier(ss: int) -> String:
	if ss <= 0:
		return "none"
	if ss <= SS_LOW_MAX:
		return "low"
	if ss <= SS_MEDIUM_MAX:
		return "medium"
	return "high"


# -- SI Defense Bonus ----------------------------------------------------------

static func get_si_defense_bonus(si: int) -> int:
	var clamped: int = clampi(si, 0, 10)
	return SI_DEFENSE_BONUS.get(clamped, 0)


# -- Seasonal Pressure ---------------------------------------------------------

## Returns the base SI decay for a given season name (lowercase).
static func get_seasonal_si_decay(season_name: String) -> int:
	return SEASONAL_SI_DECAY.get(season_name.to_lower(), 1)


## Returns the Koku cost to maintain a wall tower this season (s2.4.3).
## season_name: "spring" | "summer" | "autumn" | "winter"
## ss: current Shadowlands Strength for this province (extra cost from s2.4.10).
static func get_total_koku_cost(season_name: String, ss: int) -> int:
	var base: int = SEASONAL_KOKU_COST.get(season_name.to_lower(), 2)
	match get_ss_tier(ss):
		"medium":
			return base + SS_MEDIUM_ADDITIONAL_KOKU
		"high":
			return base + SS_HIGH_ADDITIONAL_KOKU
	return base


## Returns the total SI decay for this season including SS tier modifier.
static func get_total_si_decay(season_name: String, ss: int) -> float:
	var base: float = float(get_seasonal_si_decay(season_name))
	match get_ss_tier(ss):
		"medium":
			return base + SS_MEDIUM_ADDITIONAL_SI_DECAY
		"high":
			return base + SS_HIGH_ADDITIONAL_SI_DECAY
	return base


## Returns the Rice consumption multiplier for a Wall tower this season.
## The higher of the seasonal modifier and the SS tier modifier applies
## (per s2.4.10 table: SS modifies on top of seasonal, so they multiply).
static func get_rice_modifier(season_name: String, ss: int) -> float:
	var base: float = SEASONAL_RICE_MODIFIER.get(season_name.to_lower(), 1.0)
	match get_ss_tier(ss):
		"medium":
			return base * SS_MEDIUM_RICE_MODIFIER
		"high":
			return base * SS_HIGH_RICE_MODIFIER
	return base


# -- Kaiu Reinforcement Table (s2.4.16 — LOCKED) --------------------------------
# Indexed by Kaiu Engineer school rank (1–5).
const KAIU_REINFORCE_TABLE: Dictionary = {
	1: {"decay_reduction": 0.25, "duration": 2},
	2: {"decay_reduction": 0.25, "duration": 3},
	3: {"decay_reduction": 0.50, "duration": 3},
	4: {"decay_reduction": 0.50, "duration": 4},
	5: {"decay_reduction": 0.75, "duration": 5},
}


## Returns the Kaiu Reinforcement modifier for a given school rank (1–5).
static func get_kaiu_reinforce(rank: int) -> Dictionary:
	return KAIU_REINFORCE_TABLE.get(clampi(rank, 1, 5), KAIU_REINFORCE_TABLE[1])


## Returns the FORTIFY_WALL_SECTION TN for the current Tower SI.
## TN = 20 + (10 − SI) × 2. SI clamped 1–10 (breach requires SEAL_WALL_BREACH).
static func get_fortify_tn(si: int) -> int:
	return 20 + (10 - clampi(si, 1, 10)) * 2


## Compute SI gain from a FORTIFY_WALL_SECTION roll result.
## Base +1.0 SI; each Raise adds +0.5. Returns float; caller floors to int.
static func compute_fortify_si_gain(raises: int) -> float:
	return 1.0 + raises * 0.5


## Apply seasonal SI decay to a Tower settlement.
## Returns the new SI value (clamped 0–10) and the amount actually decayed.
## kaiu_reduction: flat decay reduction from an active Kaiu Reinforcement modifier.
## Caller must write `settlement.wall_si = result["new_si"]`.
static func apply_seasonal_si_decay(
	settlement: SettlementData,
	season_name: String,
	ss: int,
	kaiu_reduction: float = 0.0,
) -> Dictionary:
	var raw_decay: float = get_total_si_decay(season_name, ss)
	# Subtract Kaiu Reinforcement; floor at 0 so the modifier cannot add SI.
	var decay: float = maxf(0.0, raw_decay - kaiu_reduction)
	var old_si: int = settlement.wall_si
	var new_si: int = maxi(0, old_si - int(decay))
	# Fractional decay is floored (conservative). GDD is silent on rounding.
	return {
		"new_si": new_si,
		"decay_applied": old_si - new_si,
	}


## Compute adjacent tower bleed effect per s2.4.3.
## If `si` <= ADJACENT_BLEED_THRESHOLD, adjacent towers lose extra SI.
## Returns {"bleed_active": bool, "bleed_amount": float}.
static func compute_adjacent_bleed(si: int) -> Dictionary:
	if si <= ADJACENT_BLEED_THRESHOLD:
		return {"bleed_active": true, "bleed_amount": ADJACENT_BLEED_AMOUNT}
	return {"bleed_active": false, "bleed_amount": 0.0}


## Compute PTL contribution from this tower's SI state per s2.4.2.
## wall_adjacent: true if this province borders the Shadowlands.
## Returns the seasonal PTL increase to apply to the province.
static func compute_ptl_contribution(si: int, wall_adjacent: bool) -> float:
	if not wall_adjacent:
		return 0.0
	var ptl: float = PTL_BASELINE_PER_SEASON
	if si <= SI_DEGRADED_THRESHOLD:
		ptl += PTL_DEGRADED_EXTRA_PER_SEASON
	return ptl


# -- Sortie Mechanics ----------------------------------------------------------

## Determine the appropriate sortie force size from the current SS tier.
## Returns "small", "medium", "large", or "none".
## Per s2.4.11: Low SS → no sortie, Medium → Small, High → Medium.
## Large sorties require explicit Shireikan authorisation — never auto-selected.
static func get_ai_sortie_size(ss: int) -> String:
	match get_ss_tier(ss):
		"low", "none":
			return "none"
		"medium":
			return "small"
		"high":
			return "medium"
	return "none"


## Returns the SS reduction a successful sortie of `force_size` achieves.
static func get_ss_reduction(force_size: String) -> int:
	match force_size:
		"small":
			return SORTIE_SMALL_SS_REDUCTION
		"medium":
			return SORTIE_MEDIUM_SS_REDUCTION
		"large":
			return SORTIE_LARGE_SS_REDUCTION
	return 0


## Returns the garrison fraction committed for a given force size.
## Uses the upper bound of each tier per s2.4.10.
static func get_force_pct(force_size: String) -> float:
	match force_size:
		"small":
			return SORTIE_SMALL_MAX_PCT
		"medium":
			return SORTIE_MEDIUM_MAX_PCT
		"large":
			return SORTIE_LARGE_MAX_PCT
	return 0.0


## Returns the jade finger allocation per warrior for this sortie size (s2.4.15).
static func get_jade_per_warrior(force_size: String) -> int:
	match force_size:
		"small":
			return SORTIE_SMALL_JADE_PER_WARRIOR
		"medium":
			return SORTIE_MEDIUM_JADE_PER_WARRIOR
		"large":
			return SORTIE_LARGE_JADE_PER_WARRIOR
	return 0


## Validate all preconditions for ordering a sortie per s2.4.11 and s55.23a.
## Returns {"can_sortie": bool, "blocked_reason": String, "force_size": String}.
static func validate_sortie(
	ss: int,
	si: int,
	garrison_above_minimum: bool,
	jade_stockpile_critical: bool,
	is_shireikan: bool,
	force_size_override: String = "",
) -> Dictionary:
	# Jade gate — absolute block (s2.4.11 Decision 5, s2.4.15)
	if jade_stockpile_critical:
		return {
			"can_sortie": false,
			"blocked_reason": "jade_critical",
			"force_size": "",
		}

	# Garrison minimum gate (s2.4.11, s55.23a)
	if not garrison_above_minimum:
		return {
			"can_sortie": false,
			"blocked_reason": "garrison_below_minimum",
			"force_size": "",
		}

	# SI gate: cannot sortie if SI < 6 and SS is High (double crisis, s2.4.11)
	if si < 6 and get_ss_tier(ss) == "high":
		return {
			"can_sortie": false,
			"blocked_reason": "si_critical_and_ss_high",
			"force_size": "",
		}

	var size: String = force_size_override if not force_size_override.is_empty() \
		else get_ai_sortie_size(ss)

	if size == "none" or size.is_empty():
		return {
			"can_sortie": false,
			"blocked_reason": "ss_too_low",
			"force_size": "",
		}

	# Large sortie requires Shireikan authority (s2.4.10, s2.4.11)
	if size == "large" and not is_shireikan:
		return {
			"can_sortie": false,
			"blocked_reason": "large_requires_shireikan",
			"force_size": "large",
		}

	return {
		"can_sortie": true,
		"blocked_reason": "",
		"force_size": size,
	}


## Full sortie resolution entry point called from ActionExecutor.
## Returns a result dict. Actual horde combat resolves via
## HordeSystem.resolve_sortie_combat — call it from DayOrchestrator
## using the committed garrison companies and pass ss_reduction from here.
static func resolve_sortie(
	ss: int,
	si: int,
	garrison_above_minimum: bool,
	jade_stockpile_critical: bool,
	is_shireikan: bool,
	target_province_id: int,
	force_size_override: String = "",
) -> Dictionary:
	var validation: Dictionary = validate_sortie(
		ss, si, garrison_above_minimum, jade_stockpile_critical,
		is_shireikan, force_size_override
	)

	if not validation["can_sortie"]:
		return {
			"success": false,
			"blocked_reason": validation["blocked_reason"],
			"force_size": validation["force_size"],
		}

	var size: String = validation["force_size"]
	var ss_reduction: int = get_ss_reduction(size)
	var force_pct: float = get_force_pct(size)
	var jade_per_warrior: int = get_jade_per_warrior(size)

	return {
		"success": true,
		"force_size": size,
		"force_pct": force_pct,
		"ss_reduction": ss_reduction,
		"jade_per_warrior": jade_per_warrior,
		"target_province_id": target_province_id,
		"requires_sortie_combat": true,
	}
