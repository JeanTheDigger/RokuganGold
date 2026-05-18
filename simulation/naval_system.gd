class_name NavalSystem
## Ship types, naval combat, weather, trade route rules, boarding, and river
## constraints per GDD s11.9. Pure static functions except where a DiceEngine
## instance is needed for rolls.


# -- Ship Stat Blocks (s11.9 Naval Combat Stats) --------------------------------

const SHIP_STATS: Dictionary = {
	Enums.ShipClass.KOBUNE: {
		"health": 100, "attack": 3, "defense": 3, "morale": 12, "morale_defense": 4,
		"cargo": 0.3, "construction_cost": 3.0, "crew": 20,
		"can_river": true, "can_coastal": true, "can_ocean": false,
		"is_flat_bottomed": true, "is_military": false,
		"movement_per_subtile": 1,
	},
	Enums.ShipClass.SAMPAN: {
		"health": 30, "attack": 0, "defense": 1, "morale": 4, "morale_defense": 0,
		"cargo": 0.1, "construction_cost": 0.5, "crew": 2,
		"can_river": true, "can_coastal": true, "can_ocean": false,
		"is_flat_bottomed": true, "is_military": false,
		"movement_per_subtile": 1,
	},
	Enums.ShipClass.MERCHANT_BARGE: {
		"health": 80, "attack": 1, "defense": 2, "morale": 6, "morale_defense": 1,
		"cargo": 0.5, "construction_cost": 2.0, "crew": 10,
		"can_river": true, "can_coastal": true, "can_ocean": false,
		"is_flat_bottomed": true, "is_military": false,
		"movement_per_subtile": 1,
	},
	Enums.ShipClass.SENGOKOBUNE: {
		"health": 130, "attack": 4, "defense": 4, "morale": 14, "morale_defense": 5,
		"cargo": 0.5, "construction_cost": 8.0, "crew": 40,
		"can_river": false, "can_coastal": true, "can_ocean": true,
		"is_flat_bottomed": false, "is_military": false,
		"movement_per_subtile": 1,
	},
	Enums.ShipClass.KOUTETSUKAN: {
		"health": 200, "attack": 6, "defense": 8, "morale": 20, "morale_defense": 8,
		"cargo": 0.0, "construction_cost": 12.0, "crew": 100,
		"can_river": false, "can_coastal": true, "can_ocean": false,
		"is_flat_bottomed": false, "is_military": true,
		"movement_per_subtile": 2,
	},
	Enums.ShipClass.ATAKEBUNE: {
		"health": 250, "attack": 7, "defense": 6, "morale": 18, "morale_defense": 7,
		"cargo": 0.0, "construction_cost": 20.0, "crew": 200,
		"can_river": false, "can_coastal": true, "can_ocean": true,
		"is_flat_bottomed": false, "is_military": true,
		"movement_per_subtile": 1,
	},
	Enums.ShipClass.TORTOISE_OCEANGOING: {
		"health": 130, "attack": 3, "defense": 4, "morale": 14, "morale_defense": 5,
		"cargo": 0.0, "construction_cost": 10.0, "crew": 28,
		"can_river": false, "can_coastal": true, "can_ocean": true,
		"is_flat_bottomed": false, "is_military": false,
		"movement_per_subtile": 1,
	},
}

# Ships that are signature clan-exclusive vessels.
const SIGNATURE_SHIPS: Dictionary = {
	Enums.ShipClass.ATAKEBUNE: "Mantis",
	Enums.ShipClass.KOUTETSUKAN: "Crab",
}

# Clan exclusivity — only these clans can legitimately own/operate.
const CLAN_EXCLUSIVE_SHIPS: Dictionary = {
	Enums.ShipClass.KOUTETSUKAN: "Crab",
	Enums.ShipClass.ATAKEBUNE: "Mantis",
	Enums.ShipClass.TORTOISE_OCEANGOING: "Tortoise",
}

# Ships that can traverse open ocean without the 10% catastrophic loss penalty.
const OCEAN_CAPABLE_CLASSES: Array[int] = [
	Enums.ShipClass.SENGOKOBUNE,
	Enums.ShipClass.ATAKEBUNE,
	Enums.ShipClass.TORTOISE_OCEANGOING,
]

# River-capable classes (for river combat constraint).
const RIVER_COMBAT_CLASSES: Array[int] = [
	Enums.ShipClass.KOBUNE,
	Enums.ShipClass.SAMPAN,
	Enums.ShipClass.MERCHANT_BARGE,
]

const DEEP_OCEAN_LOSS_CHANCE: float = 0.10

const BOARDING_FIRST_ROUND_ATTACK_PENALTY: int = -2

# Kobune archer quarterdeck: ranged support from reserve row.
const KOBUNE_RANGED_DICE: int = 5
const KOBUNE_RANGED_RAIN_DICE: int = 3
const KOBUNE_FIRST_ROUND_ATTACK_BONUS: int = 1

# Koutetsukan ram attack.
const RAM_ATTACK_BONUS: int = 8
const RAM_SELF_DAMAGE: int = 5

# Atakebune mobile fortress adjacent defense bonus.
const ATAKEBUNE_ADJACENT_DEFENSE_BONUS: int = 3

# Construction time in seasons.
const CONSTRUCTION_TIME_SEASONS: int = 1

# Mantis pirate suppression bonus.
const MANTIS_PIRATE_SUPPRESSION_BONUS: int = 3
const MANTIS_PIRATE_SPAWN_REDUCTION: float = 0.10

# River combat constraints.
const STANDARD_RIVER_MAX_ABREAST: int = 2
const MAJOR_RIVER_MAX_ABREAST: int = 3
const RIVER_DOWNSTREAM_ATTACK_BONUS: int = 1
const RIVER_UPSTREAM_ATTACK_PENALTY: int = -1
const RIVER_GROUNDING_TN: int = 15


# -- Weather at Sea (s11.9 — LOCKED) -------------------------------------------

const WEATHER_TABLE: Dictionary = {
	"spring": {0: Enums.NavalWeather.CLEAR, 41: Enums.NavalWeather.WIND,
				76: Enums.NavalWeather.RAIN, 96: Enums.NavalWeather.STORM},
	"summer": {0: Enums.NavalWeather.CLEAR, 46: Enums.NavalWeather.WIND,
				81: Enums.NavalWeather.RAIN, 96: Enums.NavalWeather.STORM},
	"autumn": {0: Enums.NavalWeather.CLEAR, 21: Enums.NavalWeather.WIND,
				46: Enums.NavalWeather.RAIN, 81: Enums.NavalWeather.STORM,
				96: Enums.NavalWeather.TYPHOON},
	"winter": {0: Enums.NavalWeather.CLEAR, 16: Enums.NavalWeather.WIND,
				36: Enums.NavalWeather.RAIN, 71: Enums.NavalWeather.STORM,
				96: Enums.NavalWeather.TYPHOON},
}

const WEATHER_GLOBAL_MODIFIERS: Dictionary = {
	Enums.NavalWeather.CLEAR: {"attack": 0, "defense": 0},
	Enums.NavalWeather.WIND: {"attack": 0, "defense": 0},
	Enums.NavalWeather.RAIN: {"attack": -1, "defense": 0},
	Enums.NavalWeather.STORM: {"attack": -2, "defense": 0},
	Enums.NavalWeather.TYPHOON: {"attack": -3, "defense": -2},
}

const FLAT_BOTTOM_WEATHER_DEFENSE: Dictionary = {
	Enums.NavalWeather.CLEAR: 0,
	Enums.NavalWeather.WIND: 0,
	Enums.NavalWeather.RAIN: 0,
	Enums.NavalWeather.STORM: -1,
	Enums.NavalWeather.TYPHOON: -2,
}

const KOUTETSUKAN_WEATHER_ATTACK: Dictionary = {
	Enums.NavalWeather.CLEAR: 0,
	Enums.NavalWeather.WIND: 0,
	Enums.NavalWeather.RAIN: 0,
	Enums.NavalWeather.STORM: -1,
	Enums.NavalWeather.TYPHOON: -1,
}

# Tortoise Escape Attempt weather bonuses (rolled dice bonus).
const TORTOISE_ESCAPE_WEATHER_BONUS: Dictionary = {
	Enums.NavalWeather.CLEAR: 0,
	Enums.NavalWeather.WIND: 1,
	Enums.NavalWeather.RAIN: 1,
	Enums.NavalWeather.STORM: 2,
	Enums.NavalWeather.TYPHOON: 3,
}


# -- Ship Factory ---------------------------------------------------------------

static func create_ship(ship_id: int, ship_class: int, owning_clan: String,
		ship_name: String = "", ic_day: int = -1) -> ShipData:
	var ship := ShipData.new()
	ship.ship_id = ship_id
	ship.ship_class = ship_class
	ship.owning_clan = owning_clan
	ship.ship_name = ship_name
	ship.ic_day_launched = ic_day

	var stats: Dictionary = SHIP_STATS.get(ship_class, {})
	ship.health = stats.get("health", 100)
	ship.max_health = ship.health
	ship.attack = stats.get("attack", 0)
	ship.defense = stats.get("defense", 0)
	ship.morale = stats.get("morale", 8)
	ship.morale_defense = stats.get("morale_defense", 0)
	ship.cargo_capacity = stats.get("cargo", 0.0)
	ship.construction_cost = stats.get("construction_cost", 0.0)
	return ship


# -- Water Traversal Queries ----------------------------------------------------

static func can_traverse(ship_class: int, water_type: int) -> bool:
	var stats: Dictionary = SHIP_STATS.get(ship_class, {})
	if stats.is_empty():
		return false
	match water_type:
		Enums.WaterSubtileType.RIVER:
			return stats.get("can_river", false)
		Enums.WaterSubtileType.LAKE:
			return stats.get("can_river", false)
		Enums.WaterSubtileType.COASTAL:
			return stats.get("can_coastal", false)
		Enums.WaterSubtileType.OCEAN:
			return stats.get("can_ocean", false)
	return false


static func is_ocean_capable(ship_class: int) -> bool:
	return ship_class in OCEAN_CAPABLE_CLASSES


static func get_deep_ocean_loss_chance(ship_class: int) -> float:
	if is_ocean_capable(ship_class):
		return 0.0
	return DEEP_OCEAN_LOSS_CHANCE


static func get_movement_days(ship_class: int) -> int:
	var stats: Dictionary = SHIP_STATS.get(ship_class, {})
	return stats.get("movement_per_subtile", 1)


static func is_signature_ship(ship_class: int) -> bool:
	return ship_class in SIGNATURE_SHIPS


static func get_signature_clan(ship_class: int) -> String:
	return SIGNATURE_SHIPS.get(ship_class, "")


static func is_clan_exclusive(ship_class: int) -> bool:
	return ship_class in CLAN_EXCLUSIVE_SHIPS


static func can_clan_operate(ship_class: int, clan: String) -> bool:
	if not is_clan_exclusive(ship_class):
		return true
	return CLAN_EXCLUSIVE_SHIPS.get(ship_class, "") == clan


# -- Weather Determination (s11.9) ----------------------------------------------

static func determine_weather(dice: DiceEngine, season: String,
		is_inland: bool = false) -> int:
	var roll: int = dice.rand_int_range(1, 100)
	return weather_from_roll(roll, season, is_inland)


static func weather_from_roll(roll: int, season: String,
		is_inland: bool = false) -> int:
	var table: Dictionary = WEATHER_TABLE.get(season, WEATHER_TABLE["spring"])
	var result: int = Enums.NavalWeather.CLEAR
	var thresholds: Array[int] = table.keys()
	thresholds.sort()
	for threshold: int in thresholds:
		if roll > threshold:
			result = table[threshold]
	if is_inland and result == Enums.NavalWeather.TYPHOON:
		result = Enums.NavalWeather.STORM
	return result


# -- Combat Modifiers -----------------------------------------------------------

static func get_weather_attack_modifier(ship_class: int, weather: int) -> int:
	var global: int = WEATHER_GLOBAL_MODIFIERS.get(weather, {}).get("attack", 0)
	var specific: int = 0
	if ship_class == Enums.ShipClass.KOUTETSUKAN:
		specific = KOUTETSUKAN_WEATHER_ATTACK.get(weather, 0)
	return global + specific


static func get_weather_defense_modifier(ship_class: int, weather: int) -> int:
	var global: int = WEATHER_GLOBAL_MODIFIERS.get(weather, {}).get("defense", 0)
	var specific: int = 0
	var stats: Dictionary = SHIP_STATS.get(ship_class, {})
	if stats.get("is_flat_bottomed", false):
		specific = FLAT_BOTTOM_WEATHER_DEFENSE.get(weather, 0)
	return global + specific


static func get_effective_attack(ship: ShipData, weather: int,
		is_mantis_operated: bool = false) -> int:
	var base: int = ship.attack
	var modifier: int = get_weather_attack_modifier(ship.ship_class, weather)
	var mantis_bonus: int = 0
	if is_mantis_operated and ship.ship_class == Enums.ShipClass.SENGOKOBUNE:
		mantis_bonus = 1
	return maxi(0, base + modifier + mantis_bonus)


static func get_effective_defense(ship: ShipData, weather: int) -> int:
	var base: int = ship.defense
	var modifier: int = get_weather_defense_modifier(ship.ship_class, weather)
	return maxi(0, base + modifier)


# -- Kobune Ranged Support (Reserve Row) ----------------------------------------

static func get_kobune_ranged_dice(weather: int) -> int:
	match weather:
		Enums.NavalWeather.CLEAR, Enums.NavalWeather.WIND:
			return KOBUNE_RANGED_DICE
		Enums.NavalWeather.RAIN:
			return KOBUNE_RANGED_RAIN_DICE
		Enums.NavalWeather.STORM, Enums.NavalWeather.TYPHOON:
			return 0
	return KOBUNE_RANGED_DICE


static func resolve_kobune_ranged(dice: DiceEngine, weather: int,
		attack_stat: int) -> int:
	var ranged_dice: int = get_kobune_ranged_dice(weather)
	if ranged_dice <= 0:
		return 0
	var roll: int = dice.rand_int_range(1, ranged_dice)
	return roll + attack_stat


# -- Ram Attack (Koutetsukan) ---------------------------------------------------

static func resolve_ram(ship: ShipData, target: ShipData, _dice: DiceEngine,
		weather: int) -> Dictionary:
	if ship.ship_class != Enums.ShipClass.KOUTETSUKAN:
		return {"success": false, "reason": "not_koutetsukan"}
	var eff_attack: int = get_effective_attack(ship, weather) + RAM_ATTACK_BONUS
	var eff_defense: int = get_effective_defense(target, weather)
	var damage: int = maxi(0, eff_attack - eff_defense)
	var self_damage: int = RAM_SELF_DAMAGE
	return {
		"success": true,
		"damage_dealt": damage,
		"self_damage": self_damage,
		"effective_attack": eff_attack,
		"effective_defense": eff_defense,
	}


# -- Boarding Actions (s11.9) ---------------------------------------------------

static func can_board(attacker_class: int, defender_class: int) -> bool:
	if defender_class == Enums.ShipClass.KOUTETSUKAN:
		return false
	if attacker_class == Enums.ShipClass.SAMPAN:
		return false
	return true


static func get_boarding_attack_modifier(is_first_round: bool) -> int:
	if is_first_round:
		return BOARDING_FIRST_ROUND_ATTACK_PENALTY
	return 0


static func compute_capture_prize_value(ship_class: int) -> float:
	var stats: Dictionary = SHIP_STATS.get(ship_class, {})
	return stats.get("construction_cost", 0.0) * 0.5


static func evaluate_signature_capture_decision(virtue: String) -> String:
	match virtue.to_upper():
		"YU", "CHUGI", "MEIYO":
			return "destroy"
		"SEIGYO", "KANPEKI", "KYORYOKU":
			return "keep"
		"MAKOTO", "JIN":
			return "return"
	return "destroy"


# -- Tortoise Escape Attempt (s11.9) --------------------------------------------

static func resolve_escape_attempt(dice: DiceEngine, captain_nav: int,
		captain_int: int, enemy_battle: int, enemy_int: int,
		weather: int) -> Dictionary:
	var weather_bonus: int = TORTOISE_ESCAPE_WEATHER_BONUS.get(weather, 0)
	var escape_rolled: int = captain_nav + weather_bonus
	var escape_kept: int = captain_int
	var escape_result: DiceResult = dice.roll_and_keep(escape_rolled, escape_kept)

	var pursue_result: DiceResult = dice.roll_and_keep(enemy_battle, enemy_int)

	var escaped: bool = escape_result.total >= pursue_result.total
	return {
		"escaped": escaped,
		"escape_total": escape_result.total,
		"pursue_total": pursue_result.total,
		"weather_bonus": weather_bonus,
	}


# -- Tortoise Recognition (s11.9) -----------------------------------------------

const TORTOISE_RECOGNITION_TN_DISTANCE: int = 25
const TORTOISE_RECOGNITION_TN_ABOARD: int = 20
const TORTOISE_RECOGNITION_TN_INSPECTION: int = 15

static func can_auto_recognize_tortoise(school: String, _sailing_rank: int) -> bool:
	if school.begins_with("Kaiu"):
		return true
	if school.begins_with("Yoritomo") and school.find("Captain") >= 0:
		return true
	return false


static func can_auto_recognize_by_sailing(sailing_rank: int) -> bool:
	return sailing_rank >= 5


static func get_tortoise_recognition_tn(access_level: String) -> int:
	match access_level:
		"distance":
			return TORTOISE_RECOGNITION_TN_DISTANCE
		"aboard":
			return TORTOISE_RECOGNITION_TN_ABOARD
		"inspection":
			return TORTOISE_RECOGNITION_TN_INSPECTION
	return TORTOISE_RECOGNITION_TN_DISTANCE


# -- Naval Trade Route Rules (s11.9) --------------------------------------------

static func can_establish_naval_route(ship_classes_available: Array[int],
		crosses_ocean: bool) -> bool:
	if not crosses_ocean:
		return true
	for sc: int in ship_classes_available:
		if sc in OCEAN_CAPABLE_CLASSES:
			return true
	return false


static func get_pirate_spawn_modifier(clan: String) -> float:
	if clan == "Mantis":
		return -MANTIS_PIRATE_SPAWN_REDUCTION
	return 0.0


static func get_pirate_suppression_bonus(clan: String) -> int:
	if clan == "Mantis":
		return MANTIS_PIRATE_SUPPRESSION_BONUS
	return 0


# -- River Combat Constraints (s11.9) -------------------------------------------

static func can_operate_on_river(ship_class: int) -> bool:
	return ship_class in RIVER_COMBAT_CLASSES


static func get_max_ships_abreast(is_major_river: bool) -> int:
	if is_major_river:
		return MAJOR_RIVER_MAX_ABREAST
	return STANDARD_RIVER_MAX_ABREAST


static func get_river_current_modifier(is_downstream: bool) -> int:
	if is_downstream:
		return RIVER_DOWNSTREAM_ATTACK_BONUS
	return RIVER_UPSTREAM_ATTACK_PENALTY


static func resolve_grounding_check(dice: DiceEngine, navigation_rank: int,
		strength: int) -> Dictionary:
	var free_result: DiceResult = dice.roll_and_keep(1, 1, false, false)
	var freed: bool = free_result.total + strength >= RIVER_GROUNDING_TN
	return {
		"freed": freed,
		"total": free_result.total + strength,
		"tn": RIVER_GROUNDING_TN,
		"navigation_rank": navigation_rank,
	}


# -- Shore-Based Attack Modifiers (s11.9) ---------------------------------------

const SHIP_TO_SHORE_ATTACK_PENALTY: int = -2

static func get_shore_to_ship_modifier() -> int:
	return 0

static func get_ship_to_shore_modifier() -> int:
	return SHIP_TO_SHORE_ATTACK_PENALTY


# -- Navigation Bonuses ---------------------------------------------------------

const DIRECTION_FINDER_BONUS_ROLLED: int = 1
const SHUGENJA_ASSIST_BONUS_ROLLED: int = 2
const SHUGENJA_ASSIST_TN: int = 20
const TORTOISE_OCEAN_NAV_BONUS_ROLLED: int = 1

static func get_navigation_bonus(ship_class: int, has_direction_finder: bool,
		has_shugenja_assist: bool) -> int:
	var bonus: int = 0
	if ship_class == Enums.ShipClass.TORTOISE_OCEANGOING:
		bonus += TORTOISE_OCEAN_NAV_BONUS_ROLLED
	if has_direction_finder:
		bonus += DIRECTION_FINDER_BONUS_ROLLED
	if has_shugenja_assist:
		bonus += SHUGENJA_ASSIST_BONUS_ROLLED
	return bonus


# -- Civilian Ship Special Rules ------------------------------------------------

static func is_civilian_vessel(ship_class: int) -> bool:
	return ship_class in [Enums.ShipClass.MERCHANT_BARGE, Enums.ShipClass.SAMPAN]


static func civilian_auto_surrenders(ship_class: int) -> bool:
	return ship_class == Enums.ShipClass.MERCHANT_BARGE


static func civilian_auto_flees(ship_class: int) -> bool:
	return ship_class == Enums.ShipClass.SAMPAN
