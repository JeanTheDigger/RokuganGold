class_name WorshipSystem
## Kami Worship System per GDD s4.3.21.
## Manages Worship Points (WP), Great Fortune thresholds, Minor Fortune
## bonuses, active/passive generation, and cascade maluses.


# -- Constants ----------------------------------------------------------------

const PROVINCE_THRESHOLD: float = 10.0
const FAMILY_THRESHOLD: float = 60.0
const CLAN_THRESHOLD: float = 150.0
const EMPIRE_THRESHOLD: float = 800.0

const GREAT_FORTUNE_COUNT: int = 7

const FORTUNE_RING: Dictionary = {
	Enums.GreatFortune.BENTEN: Enums.Ring.AIR,
	Enums.GreatFortune.BISHAMON: Enums.Ring.FIRE,
	Enums.GreatFortune.DAIKOKU: Enums.Ring.WATER,
	Enums.GreatFortune.EBISU: Enums.Ring.EARTH,
	Enums.GreatFortune.FUKUROKUJIN: Enums.Ring.FIRE,
	Enums.GreatFortune.HOTEI: Enums.Ring.WATER,
	Enums.GreatFortune.JUROJIN: Enums.Ring.VOID,
}


# -- Passive WP Generation per Season ----------------------------------------

const GENERAL_PASSIVE_WP: Dictionary = {
	"roadside_shrine": 0.5,
	"village_shrine": 1.0,
	"local_shrine": 2.0,
	"temple": 4.0,
	"shinden": 8.0,
}

const DEDICATED_PASSIVE_WP: Dictionary = {
	"roadside_shrine": 1.5,
	"village_shrine": 3.0,
	"local_shrine": 6.0,
	"temple": 12.0,
	"shinden": 24.0,
}

const SHUGENJA_LOCATION_FREE_RAISES: Dictionary = {
	"roadside_shrine": 0,
	"village_shrine": 0,
	"local_shrine": 1,
	"temple": 2,
	"shinden": 3,
}


# -- Active Worship WP per Character Type ------------------------------------

const NORMAL_WORSHIP_WP: float = 1.0
const MONK_WORSHIP_WP: float = 2.0
const SHUGENJA_BASE_WP: float = 1.0
const SHUGENJA_WORSHIP_TN: int = 15


# -- Minor Fortune Thresholds ------------------------------------------------

const MINOR_TIER_1_THRESHOLD: float = 3.0
const MINOR_TIER_2_THRESHOLD: float = 8.0
const MINOR_TIER_3_THRESHOLD: float = 15.0


# -- Great Fortune Malus Tables (per GDD s4.3.21) ----------------------------

const BENTEN_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"pop_growth_modifier": -0.25},
	Enums.WorshipTier.DISPLEASED: {"pop_growth_modifier": -0.50, "stability_per_season": -1},
	Enums.WorshipTier.WRATHFUL: {"pop_growth_modifier": -1.0, "stability_per_season": -3, "marriage_auto_fail": true},
}

const BISHAMON_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"army_attack": -1, "army_morale": -1},
	Enums.WorshipTier.DISPLEASED: {"army_attack": -2, "army_morale": -3},
	Enums.WorshipTier.WRATHFUL: {"army_attack": -3, "army_morale": -5, "commander_risk_reduced": true},
}

const DAIKOKU_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"koku_modifier": -0.15},
	Enums.WorshipTier.DISPLEASED: {"koku_modifier": -0.30, "market_price_modifier": 0.10},
	Enums.WorshipTier.WRATHFUL: {"koku_modifier": -0.50, "trade_route_koku_disabled": true},
}

const EBISU_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"rice_modifier": -0.15},
	Enums.WorshipTier.DISPLEASED: {"rice_modifier": -0.30, "harvest_cap_reduced": true},
	Enums.WorshipTier.WRATHFUL: {"rice_modifier": -0.50, "harvest_famine_level": true},
}

const FUKUROKUJIN_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"divination_dice_penalty": -1},
	Enums.WorshipTier.DISPLEASED: {"divination_dice_penalty": -2, "intelligence_roll_modifier": -5},
	Enums.WorshipTier.WRATHFUL: {"divination_impossible": true, "intelligence_roll_modifier": -10},
}

const HOTEI_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"stability_per_season": -5},
	Enums.WorshipTier.DISPLEASED: {"stability_per_season": -10, "peasant_loyalty_modifier": -10},
	Enums.WorshipTier.WRATHFUL: {"stability_per_season": -20, "insurgency_spawn_doubled": true},
}

const JUROJIN_MALUS: Dictionary = {
	Enums.WorshipTier.RESTLESS: {"natural_death_increase": true, "healing_slower": true},
	Enums.WorshipTier.DISPLEASED: {"aging_accelerated": true, "injury_recovery_doubled": true},
	Enums.WorshipTier.WRATHFUL: {"rank4_commander_risk_checks": true},
}

const GREAT_FORTUNE_MALUS: Dictionary = {
	Enums.GreatFortune.BENTEN: BENTEN_MALUS,
	Enums.GreatFortune.BISHAMON: BISHAMON_MALUS,
	Enums.GreatFortune.DAIKOKU: DAIKOKU_MALUS,
	Enums.GreatFortune.EBISU: EBISU_MALUS,
	Enums.GreatFortune.FUKUROKUJIN: FUKUROKUJIN_MALUS,
	Enums.GreatFortune.HOTEI: HOTEI_MALUS,
	Enums.GreatFortune.JUROJIN: JUROJIN_MALUS,
}


# -- State Factory ------------------------------------------------------------

static func make_initial_province_worship() -> Dictionary:
	var wp: Dictionary = {}
	for f: int in range(GREAT_FORTUNE_COUNT):
		wp[f] = 0.0
	return wp


static func make_initial_worship_state() -> Dictionary:
	return {
		"province_wp": {},
		"province_tiers": {},
		"family_tiers": {},
		"clan_tiers": {},
		"empire_tiers": make_initial_province_worship(),
		"minor_fortune_wp": {},
	}


# -- Passive WP Computation ---------------------------------------------------

static func compute_passive_wp(worship_locations: Array) -> Dictionary:
	var wp: Dictionary = make_initial_province_worship()
	for loc: Dictionary in worship_locations:
		var loc_type: String = loc.get("type", "")
		var is_dedicated: bool = loc.get("dedicated", false)
		var dedicated_fortune: int = loc.get("fortune", -1)

		var base_wp: float = 0.0
		if is_dedicated:
			base_wp = DEDICATED_PASSIVE_WP.get(loc_type, 0.0)
		else:
			base_wp = GENERAL_PASSIVE_WP.get(loc_type, 0.0)

		if is_dedicated and dedicated_fortune >= 0 and dedicated_fortune < GREAT_FORTUNE_COUNT:
			wp[dedicated_fortune] = wp.get(dedicated_fortune, 0.0) + base_wp
		else:
			var per_fortune: float = base_wp / float(GREAT_FORTUNE_COUNT)
			for f: int in range(GREAT_FORTUNE_COUNT):
				wp[f] = wp.get(f, 0.0) + per_fortune
	return wp


# -- Active Worship Resolution ------------------------------------------------

static func resolve_active_worship(
	character_type: String,
	is_shugenja: bool,
	dice_engine: DiceEngine,
	ring_value: int,
	theology_rank: int,
	location_type: String,
	directed_fortune: int,
) -> Dictionary:
	var base_wp: float = NORMAL_WORSHIP_WP
	if character_type == "monk":
		base_wp = MONK_WORSHIP_WP

	var bonus_wp: float = 0.0
	var roll_total: int = 0
	var roll_tn: int = 0

	if is_shugenja:
		base_wp = SHUGENJA_BASE_WP
		var free_raises: int = SHUGENJA_LOCATION_FREE_RAISES.get(location_type, 0)
		var kept: int = max(1, ring_value)
		var rolled: int = max(1, theology_rank + ring_value)
		# Ring+Skill roll (spellcasting pattern) — not routable through SkillResolver
		var result: DiceResult = dice_engine.roll_and_keep(rolled, kept)
		roll_total = result.total + free_raises * 5
		roll_tn = SHUGENJA_WORSHIP_TN
		if roll_total >= roll_tn:
			var margin: int = roll_total - roll_tn
			bonus_wp = min(3.0, float(int(margin / 5)))

	var total_wp: float = base_wp + bonus_wp

	var wp_distribution: Dictionary = {}
	if directed_fortune >= 0 and directed_fortune < GREAT_FORTUNE_COUNT:
		wp_distribution[directed_fortune] = total_wp
	else:
		var per_fortune: float = total_wp / float(GREAT_FORTUNE_COUNT)
		for f: int in range(GREAT_FORTUNE_COUNT):
			wp_distribution[f] = per_fortune

	return {
		"total_wp": total_wp,
		"base_wp": base_wp,
		"bonus_wp": bonus_wp,
		"roll_total": roll_total,
		"roll_tn": roll_tn,
		"wp_distribution": wp_distribution,
		"directed": directed_fortune >= 0,
	}


# -- Threshold Evaluation -----------------------------------------------------

# DISABLED: GDD s4.3.21 does not specify WP ratio thresholds for tier transitions
static func get_worship_tier(wp: float, threshold: float) -> Enums.WorshipTier:
	if wp >= threshold:
		return Enums.WorshipTier.NONE
	return Enums.WorshipTier.NONE


static func evaluate_province_thresholds(province_wp: Dictionary) -> Dictionary:
	var tiers: Dictionary = {}
	for f: int in range(GREAT_FORTUNE_COUNT):
		var wp: float = province_wp.get(f, 0.0)
		tiers[f] = get_worship_tier(wp, PROVINCE_THRESHOLD)
	return tiers


static func evaluate_aggregate_thresholds(
	province_wp_map: Dictionary,
	province_ids: Array,
	threshold: float,
) -> Dictionary:
	var aggregate: Dictionary = make_initial_province_worship()
	for pid: Variant in province_ids:
		var pw: Dictionary = province_wp_map.get(pid, {})
		for f: int in range(GREAT_FORTUNE_COUNT):
			aggregate[f] = aggregate.get(f, 0.0) + pw.get(f, 0.0)
	var tiers: Dictionary = {}
	for f: int in range(GREAT_FORTUNE_COUNT):
		tiers[f] = get_worship_tier(aggregate[f], threshold)
	return tiers


# -- Malus Retrieval -----------------------------------------------------------

static func get_fortune_malus(fortune: Enums.GreatFortune, tier: Enums.WorshipTier) -> Dictionary:
	if tier == Enums.WorshipTier.NONE:
		return {}
	var table: Dictionary = GREAT_FORTUNE_MALUS.get(fortune, {})
	return table.get(tier, {})


static func get_worst_tier(
	province_tier: Enums.WorshipTier,
	family_tier: Enums.WorshipTier,
	clan_tier: Enums.WorshipTier,
	empire_tier: Enums.WorshipTier,
) -> Enums.WorshipTier:
	return max(province_tier, max(family_tier, max(clan_tier, empire_tier))) as Enums.WorshipTier


static func compute_province_effective_maluses(
	fortune: Enums.GreatFortune,
	province_tier: Enums.WorshipTier,
	family_tier: Enums.WorshipTier,
	clan_tier: Enums.WorshipTier,
	empire_tier: Enums.WorshipTier,
) -> Dictionary:
	var worst: Enums.WorshipTier = get_worst_tier(province_tier, family_tier, clan_tier, empire_tier)
	return get_fortune_malus(fortune, worst)


# -- Minor Fortune Blessing Tier -----------------------------------------------

static func get_minor_blessing_tier(wp: float) -> Enums.MinorBlessingTier:
	if wp >= MINOR_TIER_3_THRESHOLD:
		return Enums.MinorBlessingTier.BELOVED
	elif wp >= MINOR_TIER_2_THRESHOLD:
		return Enums.MinorBlessingTier.FAVORED
	elif wp >= MINOR_TIER_1_THRESHOLD:
		return Enums.MinorBlessingTier.NOTICED
	return Enums.MinorBlessingTier.NONE


# -- Divination ----------------------------------------------------------------

static func get_divination_flavor(tier: Enums.WorshipTier) -> String:
	match tier:
		Enums.WorshipTier.NONE:
			return "The Fortune is pleased"
		Enums.WorshipTier.RESTLESS:
			return "The Fortune grows restless"
		Enums.WorshipTier.DISPLEASED:
			return "The Fortune's gaze has turned away"
		Enums.WorshipTier.WRATHFUL:
			return "The Fortune is wrathful"
	return ""


static func resolve_divination(
	dice_engine: DiceEngine,
	theology_rank: int,
	ring_value: int,
	target_fortune: int,
	province_wp: Dictionary,
	province_malus: Dictionary = {},
) -> Dictionary:
	if province_malus.get("divination_impossible", false):
		return {"success": false, "divination_impossible": true}
	var dice_penalty: int = int(province_malus.get("divination_dice_penalty", 0))
	var kept: int = max(1, ring_value)
	var rolled: int = max(1, theology_rank + ring_value + dice_penalty)
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept)
	var roll_total: int = result.total
	var base_tn: int = 15

	var wp: float = province_wp.get(target_fortune, 0.0)
	var tier: Enums.WorshipTier = get_worship_tier(wp, PROVINCE_THRESHOLD)

	if roll_total < base_tn:
		return {"success": false, "roll_total": roll_total, "tn": base_tn}

	var raises: int = int((roll_total - base_tn) / 5)
	var scope: String = "province"
	if raises >= 3:
		scope = "empire"
	elif raises >= 2:
		scope = "clan"
	elif raises >= 1:
		scope = "family"

	var above_threshold: bool = wp >= PROVINCE_THRESHOLD
	var surplus_comfort: String = "unknown"

	return {
		"success": true,
		"roll_total": roll_total,
		"tn": base_tn,
		"raises": raises,
		"scope": scope,
		"tier": tier,
		"flavor": get_divination_flavor(tier),
		"above_threshold": above_threshold,
		"surplus_comfort": surplus_comfort,
	}


# -- Seasonal Processing Entry Point ------------------------------------------

static func process_seasonal_worship(
	worship_state: Dictionary,
	province_worship_locations: Dictionary,
	province_family_map: Dictionary,
	family_clan_map: Dictionary,
	all_province_ids: Array,
) -> Dictionary:
	var province_wp: Dictionary = worship_state.get("province_wp", {})

	for pid: Variant in province_worship_locations:
		var locations: Array = province_worship_locations[pid]
		var passive: Dictionary = compute_passive_wp(locations)
		if not province_wp.has(pid):
			province_wp[pid] = make_initial_province_worship()
		var current: Dictionary = province_wp[pid]
		for f: int in range(GREAT_FORTUNE_COUNT):
			current[f] = current.get(f, 0.0) + passive.get(f, 0.0)

	var province_tiers: Dictionary = {}
	for pid: Variant in province_wp:
		province_tiers[pid] = evaluate_province_thresholds(province_wp[pid])

	var family_tiers: Dictionary = {}
	for family_name: String in province_family_map:
		var pids: Array = province_family_map[family_name]
		family_tiers[family_name] = evaluate_aggregate_thresholds(
			province_wp, pids, FAMILY_THRESHOLD,
		)

	var clan_tiers: Dictionary = {}
	for clan_name: String in family_clan_map:
		var families: Array = family_clan_map[clan_name]
		var clan_pids: Array = []
		for fam: String in families:
			if province_family_map.has(fam):
				clan_pids.append_array(province_family_map[fam])
		clan_tiers[clan_name] = evaluate_aggregate_thresholds(
			province_wp, clan_pids, CLAN_THRESHOLD,
		)

	var empire_tiers: Dictionary = evaluate_aggregate_thresholds(
		province_wp, all_province_ids, EMPIRE_THRESHOLD,
	)

	worship_state["province_wp"] = province_wp
	worship_state["province_tiers"] = province_tiers
	worship_state["family_tiers"] = family_tiers
	worship_state["clan_tiers"] = clan_tiers
	worship_state["empire_tiers"] = empire_tiers

	return {
		"province_tiers": province_tiers,
		"family_tiers": family_tiers,
		"clan_tiers": clan_tiers,
		"empire_tiers": empire_tiers,
	}


static func reset_seasonal_wp(worship_state: Dictionary) -> void:
	worship_state["province_wp"] = {}
	worship_state["minor_fortune_wp"] = {}


static func compute_all_province_maluses(
	worship_state: Dictionary,
	provinces: Dictionary,
) -> Dictionary:
	var province_tiers: Dictionary = worship_state.get("province_tiers", {})
	var family_tiers: Dictionary = worship_state.get("family_tiers", {})
	var clan_tiers: Dictionary = worship_state.get("clan_tiers", {})
	var empire_tiers: Dictionary = worship_state.get("empire_tiers", {})

	var result: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid] as ProvinceData
		if prov == null:
			continue
		var p_tiers: Dictionary = province_tiers.get(pid, {})
		var fam: String = prov.family
		var clan: String = prov.clan
		var f_tiers: Dictionary = family_tiers.get(fam, {})
		var c_tiers: Dictionary = clan_tiers.get(clan, {})

		var combined: Dictionary = {}
		for f: int in range(GREAT_FORTUNE_COUNT):
			var pt: Enums.WorshipTier = p_tiers.get(f, Enums.WorshipTier.NONE) as Enums.WorshipTier
			var ft: Enums.WorshipTier = f_tiers.get(f, Enums.WorshipTier.NONE) as Enums.WorshipTier
			var ct: Enums.WorshipTier = c_tiers.get(f, Enums.WorshipTier.NONE) as Enums.WorshipTier
			var et: Enums.WorshipTier = empire_tiers.get(f, Enums.WorshipTier.NONE) as Enums.WorshipTier
			var worst: Enums.WorshipTier = get_worst_tier(pt, ft, ct, et)
			if worst == Enums.WorshipTier.NONE:
				continue
			var malus: Dictionary = get_fortune_malus(f as Enums.GreatFortune, worst)
			for key: String in malus:
				if malus[key] is float or malus[key] is int:
					combined[key] = combined.get(key, 0.0) + float(malus[key])
				elif malus[key] is bool and malus[key]:
					combined[key] = true
		result[prov.province_id] = combined
	return result


static func add_active_worship_to_province(
	worship_state: Dictionary,
	province_id: Variant,
	wp_distribution: Dictionary,
) -> void:
	var province_wp: Dictionary = worship_state.get("province_wp", {})
	if not province_wp.has(province_id):
		province_wp[province_id] = make_initial_province_worship()
	var current: Dictionary = province_wp[province_id]
	for f: int in wp_distribution:
		current[f] = current.get(f, 0.0) + wp_distribution.get(f, 0.0)
	worship_state["province_wp"] = province_wp
