class_name MagistrateAllocation
## Magistrate count, doshin allocation, and investigation bonuses per GDD s11.3.17/s11.3.19e.
## Doshin counts scale with settlement PU. Bonuses apply to investigation
## and suppression rolls.


enum DoshinTier {
	VILLAGE,
	CITY,
}

# Magistrate allocation (s11.3.17a)
const MAGISTRATE_PER_PROVINCE: int = 1
const MAGISTRATE_PER_CITY: int = 1
const MAGISTRATE_PER_OTOSAN_UCHI_DISTRICT: int = 1

# Doshin force size thresholds (s11.3.19e.ii)
const FORCE_SMALL_MAX: int = 2
const FORCE_MEDIUM_MAX: int = 5

# Doshin bonuses (s11.3.19e.ii)
const BONUS_SMALL: int = 3
const BONUS_MEDIUM: int = 5
const BONUS_LARGE: int = 8
const BONUS_SAMURAI_INVESTIGATION: int = 3

# Settlement PU thresholds for doshin tier (s11.3.19e.vi)
const PU_VILLAGE_MIN: float = 0.5
const PU_LARGE_VILLAGE_MIN: float = 1.0
const PU_CASTLE_TOWN_MIN: float = 2.0
const PU_TOWN_MIN: float = 5.0
const PU_CITY_MIN: float = 10.0
const PU_MAJOR_CITY_MIN: float = 20.0

# Stability threshold (s11.3.19e.vii)
const LOW_STABILITY_THRESHOLD: int = 25
const LOW_STABILITY_PENALTY: int = 2

# Doshin recovery (s11.3.19e.vii)
const DOSHIN_RECOVERY_PER_SEASON: int = 1

# Recruitment limit (s11.3.19e.viii)
# Maximum recruitable = ceil(available / 2)


static func get_magistrate_count(
	num_cities: int,
	is_otosan_uchi: bool = false,
	otosan_uchi_districts: int = 17,
) -> int:
	if is_otosan_uchi:
		return otosan_uchi_districts * MAGISTRATE_PER_OTOSAN_UCHI_DISTRICT
	return MAGISTRATE_PER_PROVINCE + (num_cities * MAGISTRATE_PER_CITY)


static func get_doshin_baseline(settlement_pu: float, is_remote: bool = false) -> Dictionary:
	if is_remote or settlement_pu < PU_VILLAGE_MIN:
		return {"count": 0, "tier": DoshinTier.VILLAGE, "has_headman": false}

	if settlement_pu < PU_LARGE_VILLAGE_MIN:
		return {"count": 1, "tier": DoshinTier.VILLAGE, "has_headman": false}

	if settlement_pu < PU_CASTLE_TOWN_MIN:
		return {"count": 2, "tier": DoshinTier.VILLAGE, "has_headman": false}

	if settlement_pu < PU_TOWN_MIN:
		return {"count": 3, "tier": DoshinTier.CITY, "has_headman": false}

	if settlement_pu < PU_CITY_MIN:
		return {"count": 5, "tier": DoshinTier.CITY, "has_headman": true}

	if settlement_pu < PU_MAJOR_CITY_MIN:
		return {"count": 10, "tier": DoshinTier.CITY, "has_headman": true}

	return {"count": 15, "tier": DoshinTier.CITY, "has_headman": true}


static func get_available_doshin(
	settlement_pu: float,
	doshin_losses: int,
	is_remote: bool,
	is_village: bool,
	is_planting_or_harvest: bool,
	province_stability: int,
) -> int:
	var baseline: Dictionary = get_doshin_baseline(settlement_pu, is_remote)
	var available: int = baseline["count"] - doshin_losses

	if is_village and is_planting_or_harvest:
		available = ceili(available / 2.0)

	if province_stability < LOW_STABILITY_THRESHOLD:
		available -= LOW_STABILITY_PENALTY

	return maxi(available, 0)


static func get_max_recruitable(available: int) -> int:
	return ceili(available / 2.0)


static func get_investigation_bonus(doshin_count: int, is_samurai_target: bool) -> int:
	if is_samurai_target:
		return BONUS_SAMURAI_INVESTIGATION

	if doshin_count <= 0:
		return 0
	if doshin_count <= FORCE_SMALL_MAX:
		return BONUS_SMALL
	if doshin_count <= FORCE_MEDIUM_MAX:
		return BONUS_MEDIUM
	return BONUS_LARGE


static func get_suppression_bonus(doshin_count: int) -> int:
	if doshin_count <= 0:
		return 0
	if doshin_count <= FORCE_SMALL_MAX:
		return BONUS_SMALL
	if doshin_count <= FORCE_MEDIUM_MAX:
		return BONUS_MEDIUM
	return BONUS_LARGE


static func apply_doshin_loss(current_losses: int, casualties: int) -> int:
	return current_losses + casualties


static func apply_seasonal_recovery(current_losses: int) -> int:
	return maxi(0, current_losses - DOSHIN_RECOVERY_PER_SEASON)
