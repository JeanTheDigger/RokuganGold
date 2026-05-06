class_name TattooSystem
## Tattoo application, visibility, disposition bonds, cultural reluctance,
## ability tattoo gates, commission handling, and provenance per GDD s57.25.


# =============================================================================
# 57.25.3 — Quality Tier Constants
# =============================================================================

const AP_COST: Dictionary = {
	Enums.TattooQualityTier.NORMAL: 2,
	Enums.TattooQualityTier.FINE: 3,
	Enums.TattooQualityTier.EXCEPTIONAL: 4,
	Enums.TattooQualityTier.MASTERWORK: 5,
	Enums.TattooQualityTier.LEGENDARY: 6,
}

const APPLY_TN: Dictionary = {
	Enums.TattooQualityTier.NORMAL: 15,
	Enums.TattooQualityTier.FINE: 20,
	Enums.TattooQualityTier.EXCEPTIONAL: 25,
	Enums.TattooQualityTier.MASTERWORK: 30,
	Enums.TattooQualityTier.LEGENDARY: 35,
}

const SKILL_GATE: Dictionary = {
	Enums.TattooQualityTier.NORMAL: 1,
	Enums.TattooQualityTier.FINE: 2,
	Enums.TattooQualityTier.EXCEPTIONAL: 3,
	Enums.TattooQualityTier.MASTERWORK: 4,
	Enums.TattooQualityTier.LEGENDARY: 5,
}


# =============================================================================
# 57.25.4 — Disposition Bond Values
# =============================================================================

const DISPOSITION_BOND: Dictionary = {
	Enums.TattooQualityTier.NORMAL: 1,
	Enums.TattooQualityTier.FINE: 2,
	Enums.TattooQualityTier.EXCEPTIONAL: 3,
	Enums.TattooQualityTier.MASTERWORK: 4,
	Enums.TattooQualityTier.LEGENDARY: 5,
}


# =============================================================================
# 57.25.10 — Commission Completion Bonus
# =============================================================================

const COMMISSION_COMPLETION_BONUS: Dictionary = {
	Enums.TattooQualityTier.NORMAL: 2,
	Enums.TattooQualityTier.FINE: 3,
	Enums.TattooQualityTier.EXCEPTIONAL: 5,
	Enums.TattooQualityTier.MASTERWORK: 7,
	Enums.TattooQualityTier.LEGENDARY: 10,
}

const COMMISSION_FAILURE_DISPOSITION: int = -3
const COMMISSION_FAILURE_HONOR: float = -0.3
const COMMISSION_WINDOW_SEASONS: int = 1


# =============================================================================
# 57.25.3 — Cultural Reluctance
# =============================================================================

const NO_RELUCTANCE_CLANS: Array[String] = ["Dragon", "Crab", "Mantis"]
const RELUCTANT_CLANS: Array[String] = ["Lion", "Unicorn", "Phoenix", "Scorpion"]
const IMPERIAL_FAMILIES: Array[String] = ["Otomo", "Seppun", "Miya"]

const RELUCTANCE_DISPOSITION_THRESHOLD: Dictionary = {
	Enums.CulturalReluctance.NO_RELUCTANCE: 0,
	Enums.CulturalReluctance.RELUCTANT: 46,
	Enums.CulturalReluctance.VERY_RELUCTANT: 71,
}

const WRIST_FOREARM_LOCATIONS: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.LEFT_WRIST_FOREARM,
	Enums.TattooBodyLocation.RIGHT_WRIST_FOREARM,
]


static func get_cultural_reluctance(
	clan: String,
	family: String,
	body_location: Enums.TattooBodyLocation,
) -> Enums.CulturalReluctance:
	if clan in NO_RELUCTANCE_CLANS:
		return Enums.CulturalReluctance.NO_RELUCTANCE

	if family == "Daidoji" and body_location in WRIST_FOREARM_LOCATIONS:
		return Enums.CulturalReluctance.NO_RELUCTANCE

	if family in IMPERIAL_FAMILIES:
		return Enums.CulturalReluctance.VERY_RELUCTANT

	if clan in RELUCTANT_CLANS or clan == "Crane":
		return Enums.CulturalReluctance.RELUCTANT

	return Enums.CulturalReluctance.RELUCTANT


static func check_consent(
	recipient_clan: String,
	recipient_family: String,
	body_location: Enums.TattooBodyLocation,
	disposition_toward_artist: int,
	subject_personally_meaningful: bool,
	scorpion_leverage_active: bool,
) -> bool:
	var reluctance: Enums.CulturalReluctance = get_cultural_reluctance(
		recipient_clan, recipient_family, body_location
	)

	if scorpion_leverage_active and recipient_clan == "Scorpion":
		reluctance = Enums.CulturalReluctance.NO_RELUCTANCE

	if subject_personally_meaningful and reluctance > Enums.CulturalReluctance.NO_RELUCTANCE:
		reluctance = (reluctance - 1) as Enums.CulturalReluctance

	var threshold: int = RELUCTANCE_DISPOSITION_THRESHOLD[reluctance]
	return disposition_toward_artist >= threshold


# =============================================================================
# 57.25.2 — Body Location Management
# =============================================================================

const ALL_BODY_LOCATIONS: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.LEFT_WRIST_FOREARM,
	Enums.TattooBodyLocation.RIGHT_WRIST_FOREARM,
	Enums.TattooBodyLocation.LEFT_UPPER_ARM_SHOULDER,
	Enums.TattooBodyLocation.RIGHT_UPPER_ARM_SHOULDER,
	Enums.TattooBodyLocation.CHEST_TORSO,
	Enums.TattooBodyLocation.BACK,
	Enums.TattooBodyLocation.LEFT_LEG_THIGH,
	Enums.TattooBodyLocation.RIGHT_LEG_THIGH,
	Enums.TattooBodyLocation.HEAD,
]


static func get_occupied_locations(tattoos: Array[TattooData], character_id: int) -> Array[Enums.TattooBodyLocation]:
	var result: Array[Enums.TattooBodyLocation] = []
	for t: TattooData in tattoos:
		if t.recipient_id == character_id:
			result.append(t.body_location)
	return result


static func get_available_locations(tattoos: Array[TattooData], character_id: int, is_bald: bool) -> Array[Enums.TattooBodyLocation]:
	var occupied: Array[Enums.TattooBodyLocation] = get_occupied_locations(tattoos, character_id)
	var result: Array[Enums.TattooBodyLocation] = []
	for loc: Enums.TattooBodyLocation in ALL_BODY_LOCATIONS:
		if loc in occupied:
			continue
		if loc == Enums.TattooBodyLocation.HEAD and not is_bald:
			continue
		result.append(loc)
	return result


static func is_location_available(tattoos: Array[TattooData], character_id: int, location: Enums.TattooBodyLocation, is_bald: bool) -> bool:
	if location == Enums.TattooBodyLocation.HEAD and not is_bald:
		return false
	for t: TattooData in tattoos:
		if t.recipient_id == character_id and t.body_location == location:
			return false
	return true


static func get_character_tattoos(tattoos: Array[TattooData], character_id: int) -> Array[TattooData]:
	var result: Array[TattooData] = []
	for t: TattooData in tattoos:
		if t.recipient_id == character_id:
			result.append(t)
	return result


# =============================================================================
# 57.25.2 — Visibility
# =============================================================================

const ALWAYS_VISIBLE_LOCATIONS: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.LEFT_WRIST_FOREARM,
	Enums.TattooBodyLocation.RIGHT_WRIST_FOREARM,
]

const VISIBLE_WITHOUT_OUTER_GARMENT: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.LEFT_UPPER_ARM_SHOULDER,
	Enums.TattooBodyLocation.RIGHT_UPPER_ARM_SHOULDER,
]

const VISIBLE_UPPER_REMOVED: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.CHEST_TORSO,
	Enums.TattooBodyLocation.BACK,
]

const VISIBLE_LOWER_REMOVED: Array[Enums.TattooBodyLocation] = [
	Enums.TattooBodyLocation.LEFT_LEG_THIGH,
	Enums.TattooBodyLocation.RIGHT_LEG_THIGH,
]


static func compute_visibility(
	location: Enums.TattooBodyLocation,
	wearing_formal_sleeves: bool,
	wearing_outer_garment: bool,
	upper_garment_removed: bool,
	lower_garment_removed: bool,
	is_bald: bool,
	wearing_hood: bool,
) -> bool:
	if location in ALWAYS_VISIBLE_LOCATIONS:
		return not wearing_formal_sleeves

	if location in VISIBLE_WITHOUT_OUTER_GARMENT:
		return not wearing_outer_garment

	if location in VISIBLE_UPPER_REMOVED:
		return upper_garment_removed

	if location in VISIBLE_LOWER_REMOVED:
		return lower_garment_removed

	if location == Enums.TattooBodyLocation.HEAD:
		return is_bald and not wearing_hood

	return false


# =============================================================================
# 57.25.3 — APPLY_TATTOO
# =============================================================================

static func get_ap_cost(tier: Enums.TattooQualityTier) -> int:
	return AP_COST.get(tier, 2)


static func get_apply_tn(tier: Enums.TattooQualityTier) -> int:
	return APPLY_TN.get(tier, 15)


static func meets_skill_gate(tattooing_rank: int, tier: Enums.TattooQualityTier) -> bool:
	return tattooing_rank >= SKILL_GATE.get(tier, 1)


static func resolve_quality(
	target_tier: Enums.TattooQualityTier,
	roll_result: int,
	raises_called: int,
) -> Enums.TattooQualityTier:
	var tn: int = get_apply_tn(target_tier)
	var success: bool = roll_result >= tn

	if success:
		var final_tier: int = target_tier + raises_called
		if final_tier > Enums.TattooQualityTier.LEGENDARY:
			final_tier = Enums.TattooQualityTier.LEGENDARY
		return final_tier as Enums.TattooQualityTier
	else:
		var downgrade: int = target_tier - 1
		if downgrade < Enums.TattooQualityTier.NORMAL:
			return Enums.TattooQualityTier.MUNDANE
		return downgrade as Enums.TattooQualityTier


static func create_tattoo(
	tattoo_id: int,
	recipient_id: int,
	artist_id: int,
	quality: Enums.TattooQualityTier,
	body_location: Enums.TattooBodyLocation,
	subject_type: Enums.TattooSubjectType,
	subject_description: String,
	topic_id: int,
	is_ability: bool,
	ability: Enums.TattooAbility,
	ic_day: int,
) -> TattooData:
	if quality == Enums.TattooQualityTier.MUNDANE:
		return null

	var t := TattooData.new()
	t.tattoo_id = tattoo_id
	t.recipient_id = recipient_id
	t.artist_id = artist_id
	t.quality_tier = quality
	t.body_location = body_location
	t.subject_type = subject_type
	t.subject_description = subject_description
	t.topic_id = topic_id
	t.is_ability_tattoo = is_ability
	t.ability_granted = ability
	t.date_applied = ic_day
	return t


# =============================================================================
# 57.25.4 — Disposition Bond
# =============================================================================

static func get_disposition_bond(quality: Enums.TattooQualityTier) -> int:
	return DISPOSITION_BOND.get(quality, 0)


static func calculate_total_bond(
	tattoos: Array[TattooData],
	character_a: int,
	character_b: int,
) -> int:
	var total: int = 0
	for t: TattooData in tattoos:
		if (t.artist_id == character_a and t.recipient_id == character_b) \
			or (t.artist_id == character_b and t.recipient_id == character_a):
			total += get_disposition_bond(t.quality_tier)
	return total


# =============================================================================
# 57.25.6 — Togashi Ability Tattoo Gates
# =============================================================================

const TOGASHI_SCHOOLS: Array[String] = [
	"Togashi Tattooed Order",
	"Kikage Zumi",
	"Hoshi Tsurui Zumi",
]

const SCHOOL_ALLOTMENTS: Dictionary = {
	"Togashi Tattooed Order": {1: 2, 3: 2, 5: 2},
	"Kikage Zumi": {1: 1, 3: 1, 5: 1},
	"Hoshi Tsurui Zumi": {1: 1, 4: 1},
}

const TOTAL_SCHOOL_TATTOOS: Dictionary = {
	"Togashi Tattooed Order": 6,
	"Kikage Zumi": 3,
	"Hoshi Tsurui Zumi": 2,
}


static func is_togashi_school(school: String) -> bool:
	return school in TOGASHI_SCHOOLS


static func get_allotment_for_rank(school: String, school_rank: int) -> int:
	if school not in SCHOOL_ALLOTMENTS:
		return 0
	var allotments: Dictionary = SCHOOL_ALLOTMENTS[school]
	var total: int = 0
	for rank: int in allotments:
		if rank <= school_rank:
			total += allotments[rank]
	return total


static func get_current_rank_allotment(school: String, school_rank: int) -> int:
	if school not in SCHOOL_ALLOTMENTS:
		return 0
	var allotments: Dictionary = SCHOOL_ALLOTMENTS[school]
	return allotments.get(school_rank, 0)


static func count_ability_tattoos(tattoos: Array[TattooData], character_id: int) -> int:
	var count: int = 0
	for t: TattooData in tattoos:
		if t.recipient_id == character_id and t.is_ability_tattoo:
			count += 1
	return count


static func has_unfilled_ability_slots(
	tattoos: Array[TattooData],
	character_id: int,
	school: String,
	school_rank: int,
) -> bool:
	if not is_togashi_school(school):
		return false
	var allotment: int = get_allotment_for_rank(school, school_rank)
	var current: int = count_ability_tattoos(tattoos, character_id)
	return current < allotment


static func can_receive_decorative(
	tattoos: Array[TattooData],
	character_id: int,
	school: String,
	school_rank: int,
) -> bool:
	if not is_togashi_school(school):
		return true
	return not has_unfilled_ability_slots(tattoos, character_id, school, school_rank)


static func can_apply_ability_tattoo(
	artist_school: String,
	artist_school_rank: int,
	in_togashi_territory: bool,
) -> bool:
	if not is_togashi_school(artist_school):
		return false
	if artist_school_rank < 3:
		return false
	if not in_togashi_territory:
		return false
	return true


static func can_self_apply(school: String, school_rank: int) -> bool:
	return is_togashi_school(school) and school_rank >= 3


static func is_seek_tattoo_blocked(
	tattoos: Array[TattooData],
	character_id: int,
) -> bool:
	var occupied: Array[Enums.TattooBodyLocation] = get_occupied_locations(tattoos, character_id)
	return occupied.size() >= ALL_BODY_LOCATIONS.size()


# =============================================================================
# 57.25.7 — SEEK_TATTOO Urgency
# =============================================================================

const SEEK_TATTOO_STANDARD_SCORE: int = 85
const SEEK_TATTOO_OVERRIDE_SCORE: int = 90
const SEEK_TATTOO_MAXIMUM_SCORE: int = 95

const KNOWN_ELDER_OFFER_SCORE: int = 95
const KNOWN_ELDER_TRAVEL_SCORE: int = 90
const UNKNOWN_ELDER_TRAVEL_SCORE: int = 85
const ASK_INTRODUCTION_SCORE: int = 80
const GATHER_INTELLIGENCE_SCORE: int = 75

const GRANT_TATTOO_SCORE: int = 95


static func get_seek_tattoo_urgency(seasons_at_rank_unfilled: int) -> int:
	if seasons_at_rank_unfilled >= 3:
		return SEEK_TATTOO_MAXIMUM_SCORE
	elif seasons_at_rank_unfilled >= 2:
		return SEEK_TATTOO_OVERRIDE_SCORE
	return SEEK_TATTOO_STANDARD_SCORE


# =============================================================================
# 57.25.9 — Provenance Investigation
# =============================================================================

const PROVENANCE_TN_LEGENDARY: int = 15
const PROVENANCE_TN_EXCEPTIONAL: int = 20
const PROVENANCE_TN_FINE: int = 25
const PROVENANCE_TN_NORMAL: int = 30

const HERALDRY_TN_MAJOR_CLAN: int = 10
const HERALDRY_TN_MINOR_CLAN: int = 15
const HERALDRY_TN_OBSCURE: int = 25
const HERALDRY_TN_PERSONAL: int = 30


static func get_provenance_tn(quality: Enums.TattooQualityTier) -> int:
	match quality:
		Enums.TattooQualityTier.LEGENDARY:
			return PROVENANCE_TN_LEGENDARY
		Enums.TattooQualityTier.EXCEPTIONAL:
			return PROVENANCE_TN_EXCEPTIONAL
		Enums.TattooQualityTier.FINE:
			return PROVENANCE_TN_FINE
		_:
			return PROVENANCE_TN_NORMAL


# =============================================================================
# 57.25.5 — Topic Tattoo Discovery
# =============================================================================

const TOPIC_TN_MAJOR_CLAN_SYMBOL: int = 10
const TOPIC_TN_WELL_KNOWN_EVENT: int = 15
const TOPIC_TN_OBSCURE_REGIONAL: int = 20
const TOPIC_TN_PERSONAL: int = 30


# =============================================================================
# 57.25.10 — Commission
# =============================================================================

static func get_commission_completion_bonus(quality: Enums.TattooQualityTier) -> int:
	return COMMISSION_COMPLETION_BONUS.get(quality, 2)


static func is_commission_expired(window_start_day: int, current_day: int, days_per_season: int) -> bool:
	return (current_day - window_start_day) >= days_per_season


# =============================================================================
# 57.25.8 — World Generation Helpers
# =============================================================================

const CRAB_MANTIS_TATTOO_CHANCE_MIN: float = 0.4
const CRAB_MANTIS_TATTOO_CHANCE_MAX: float = 0.6
const DAIDOJI_WRIST_TATTOO_CHANCE: float = 0.5


static func should_seed_crab_mantis_tattoo(rng_value: float) -> bool:
	return rng_value <= CRAB_MANTIS_TATTOO_CHANCE_MAX


static func should_seed_daidoji_tattoo(rng_value: float) -> bool:
	return rng_value <= DAIDOJI_WRIST_TATTOO_CHANCE


static func get_dragon_decorative_count(rng_value: float) -> int:
	if rng_value < 0.33:
		return 0
	elif rng_value < 0.66:
		return 1
	return 2


# =============================================================================
# Permanent Passive Tattoo Checks
# =============================================================================

static func has_mantis_tattoo(tattoos: Array[TattooData], character_id: int) -> bool:
	for t: TattooData in tattoos:
		if t.recipient_id == character_id and t.is_ability_tattoo and t.ability_granted == Enums.TattooAbility.MANTIS:
			return true
	return false


static func has_ocean_tattoo(tattoos: Array[TattooData], character_id: int) -> bool:
	for t: TattooData in tattoos:
		if t.recipient_id == character_id and t.is_ability_tattoo and t.ability_granted == Enums.TattooAbility.OCEAN:
			return true
	return false


static func get_active_ability_tattoo(tattoos: Array[TattooData], character_id: int, active_tattoo_ability: Enums.TattooAbility) -> TattooData:
	if active_tattoo_ability == Enums.TattooAbility.NONE:
		return null
	for t: TattooData in tattoos:
		if t.recipient_id == character_id and t.is_ability_tattoo and t.ability_granted == active_tattoo_ability:
			return t
	return null


static func can_activate_tattoo(tattoo: TattooData) -> bool:
	return tattoo.is_visible and tattoo.is_ability_tattoo and tattoo.ability_granted != Enums.TattooAbility.NONE
