extends GutTest
## Tests for NavalSystem per GDD s11.9.


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


# -- Helpers -------------------------------------------------------------------

func _make_ship(ship_class: int, clan: String = "Mantis") -> ShipData:
	return NavalSystem.create_ship(1, ship_class, clan, "Test Ship")


# =============================================================================
# Ship Stat Blocks (s11.9 — LOCKED)
# =============================================================================

func test_kobune_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.KOBUNE]
	assert_eq(stats["health"], 100)
	assert_eq(stats["attack"], 3)
	assert_eq(stats["defense"], 3)
	assert_eq(stats["morale"], 12)
	assert_eq(stats["morale_defense"], 4)
	assert_eq(stats["cargo"], 0.3)
	assert_true(stats["can_river"])
	assert_true(stats["can_coastal"])
	assert_false(stats["can_ocean"])
	assert_true(stats["is_flat_bottomed"])


func test_sampan_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.SAMPAN]
	assert_eq(stats["health"], 30)
	assert_eq(stats["attack"], 0)
	assert_eq(stats["defense"], 1)
	assert_eq(stats["morale"], 4)
	assert_eq(stats["morale_defense"], 0)
	assert_eq(stats["cargo"], 0.1)


func test_merchant_barge_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.MERCHANT_BARGE]
	assert_eq(stats["health"], 80)
	assert_eq(stats["attack"], 1)
	assert_eq(stats["defense"], 2)
	assert_eq(stats["morale"], 6)
	assert_eq(stats["morale_defense"], 1)
	assert_eq(stats["cargo"], 0.5)


func test_sengokobune_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.SENGOKOBUNE]
	assert_eq(stats["health"], 130)
	assert_eq(stats["attack"], 4)
	assert_eq(stats["defense"], 4)
	assert_eq(stats["morale"], 14)
	assert_eq(stats["morale_defense"], 5)
	assert_eq(stats["cargo"], 0.5)
	assert_true(stats["can_ocean"])


func test_koutetsukan_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.KOUTETSUKAN]
	assert_eq(stats["health"], 200)
	assert_eq(stats["attack"], 6)
	assert_eq(stats["defense"], 8)
	assert_eq(stats["morale"], 20)
	assert_eq(stats["morale_defense"], 8)
	assert_eq(stats["cargo"], 0.0)
	assert_eq(stats["movement_per_subtile"], 2)


func test_atakebune_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.ATAKEBUNE]
	assert_eq(stats["health"], 250)
	assert_eq(stats["attack"], 7)
	assert_eq(stats["defense"], 6)
	assert_eq(stats["morale"], 18)
	assert_eq(stats["morale_defense"], 7)
	assert_true(stats["can_ocean"])


func test_tortoise_oceangoing_stats() -> void:
	var stats: Dictionary = NavalSystem.SHIP_STATS[Enums.ShipClass.TORTOISE_OCEANGOING]
	assert_eq(stats["health"], 130)
	assert_eq(stats["attack"], 3)
	assert_eq(stats["defense"], 4)
	assert_eq(stats["morale"], 14)
	assert_eq(stats["morale_defense"], 5)
	assert_eq(stats["construction_cost"], 10.0)
	assert_true(stats["can_ocean"])


func test_all_seven_ship_classes_have_stats() -> void:
	assert_eq(NavalSystem.SHIP_STATS.size(), 7)
	for sc in Enums.ShipClass.values():
		assert_true(NavalSystem.SHIP_STATS.has(sc),
			"Missing stats for ShipClass %d" % sc)


# =============================================================================
# Ship Factory
# =============================================================================

func test_create_ship_sets_stats_from_table() -> void:
	var ship := NavalSystem.create_ship(5, Enums.ShipClass.KOBUNE, "Crab", "Wave Cutter", 100)
	assert_eq(ship.ship_id, 5)
	assert_eq(ship.ship_class, Enums.ShipClass.KOBUNE)
	assert_eq(ship.owning_clan, "Crab")
	assert_eq(ship.ship_name, "Wave Cutter")
	assert_eq(ship.ic_day_launched, 100)
	assert_eq(ship.health, 100)
	assert_eq(ship.max_health, 100)
	assert_eq(ship.attack, 3)
	assert_eq(ship.defense, 3)
	assert_eq(ship.cargo_capacity, 0.3)


func test_create_ship_koutetsukan_military_stats() -> void:
	var ship := NavalSystem.create_ship(1, Enums.ShipClass.KOUTETSUKAN, "Crab")
	assert_eq(ship.health, 200)
	assert_eq(ship.attack, 6)
	assert_eq(ship.defense, 8)
	assert_eq(ship.cargo_capacity, 0.0)


# =============================================================================
# Water Traversal
# =============================================================================

func test_kobune_can_traverse_river() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.KOBUNE, Enums.WaterSubtileType.RIVER))

func test_kobune_cannot_traverse_ocean() -> void:
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.KOBUNE, Enums.WaterSubtileType.OCEAN))

func test_sengokobune_can_traverse_ocean() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.SENGOKOBUNE, Enums.WaterSubtileType.OCEAN))

func test_sengokobune_cannot_traverse_river() -> void:
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.SENGOKOBUNE, Enums.WaterSubtileType.RIVER))

func test_koutetsukan_cannot_traverse_ocean() -> void:
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.KOUTETSUKAN, Enums.WaterSubtileType.OCEAN))

func test_atakebune_can_traverse_ocean() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.ATAKEBUNE, Enums.WaterSubtileType.OCEAN))

func test_tortoise_can_traverse_ocean() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.TORTOISE_OCEANGOING, Enums.WaterSubtileType.OCEAN))

func test_merchant_barge_river_and_coastal_only() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.MERCHANT_BARGE, Enums.WaterSubtileType.RIVER))
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.MERCHANT_BARGE, Enums.WaterSubtileType.COASTAL))
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.MERCHANT_BARGE, Enums.WaterSubtileType.OCEAN))

func test_sampan_river_and_coastal_only() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.SAMPAN, Enums.WaterSubtileType.RIVER))
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.SAMPAN, Enums.WaterSubtileType.COASTAL))
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.SAMPAN, Enums.WaterSubtileType.OCEAN))

func test_lake_traversal_same_as_river() -> void:
	assert_true(NavalSystem.can_traverse(Enums.ShipClass.KOBUNE, Enums.WaterSubtileType.LAKE))
	assert_false(NavalSystem.can_traverse(Enums.ShipClass.SENGOKOBUNE, Enums.WaterSubtileType.LAKE))


# =============================================================================
# Ocean Capability & Deep Ocean Loss
# =============================================================================

func test_ocean_capable_classes() -> void:
	assert_true(NavalSystem.is_ocean_capable(Enums.ShipClass.SENGOKOBUNE))
	assert_true(NavalSystem.is_ocean_capable(Enums.ShipClass.ATAKEBUNE))
	assert_true(NavalSystem.is_ocean_capable(Enums.ShipClass.TORTOISE_OCEANGOING))
	assert_false(NavalSystem.is_ocean_capable(Enums.ShipClass.KOBUNE))
	assert_false(NavalSystem.is_ocean_capable(Enums.ShipClass.KOUTETSUKAN))

func test_deep_ocean_loss_chance_non_capable() -> void:
	assert_almost_eq(NavalSystem.get_deep_ocean_loss_chance(Enums.ShipClass.KOBUNE), 0.10, 0.001)

func test_deep_ocean_loss_chance_capable() -> void:
	assert_almost_eq(NavalSystem.get_deep_ocean_loss_chance(Enums.ShipClass.SENGOKOBUNE), 0.0, 0.001)


# =============================================================================
# Signature Ships & Clan Exclusivity
# =============================================================================

func test_atakebune_is_signature() -> void:
	assert_true(NavalSystem.is_signature_ship(Enums.ShipClass.ATAKEBUNE))
	assert_eq(NavalSystem.get_signature_clan(Enums.ShipClass.ATAKEBUNE), "Mantis")

func test_koutetsukan_is_signature() -> void:
	assert_true(NavalSystem.is_signature_ship(Enums.ShipClass.KOUTETSUKAN))
	assert_eq(NavalSystem.get_signature_clan(Enums.ShipClass.KOUTETSUKAN), "Crab")

func test_kobune_not_signature() -> void:
	assert_false(NavalSystem.is_signature_ship(Enums.ShipClass.KOBUNE))

func test_clan_exclusive_tortoise() -> void:
	assert_true(NavalSystem.can_clan_operate(Enums.ShipClass.TORTOISE_OCEANGOING, "Tortoise"))
	assert_false(NavalSystem.can_clan_operate(Enums.ShipClass.TORTOISE_OCEANGOING, "Mantis"))

func test_kobune_any_clan_can_operate() -> void:
	assert_true(NavalSystem.can_clan_operate(Enums.ShipClass.KOBUNE, "Lion"))
	assert_true(NavalSystem.can_clan_operate(Enums.ShipClass.KOBUNE, "Crab"))


# =============================================================================
# Weather Determination (s11.9 — LOCKED)
# =============================================================================

func test_weather_clear_spring_low_roll() -> void:
	assert_eq(NavalSystem.weather_from_roll(1, "spring"), Enums.NavalWeather.CLEAR)

func test_weather_wind_spring() -> void:
	assert_eq(NavalSystem.weather_from_roll(50, "spring"), Enums.NavalWeather.WIND)

func test_weather_rain_spring() -> void:
	assert_eq(NavalSystem.weather_from_roll(80, "spring"), Enums.NavalWeather.RAIN)

func test_weather_storm_spring() -> void:
	assert_eq(NavalSystem.weather_from_roll(97, "spring"), Enums.NavalWeather.STORM)

func test_no_typhoon_in_spring() -> void:
	assert_eq(NavalSystem.weather_from_roll(100, "spring"), Enums.NavalWeather.STORM)

func test_no_typhoon_in_summer() -> void:
	assert_eq(NavalSystem.weather_from_roll(100, "summer"), Enums.NavalWeather.STORM)

func test_typhoon_autumn() -> void:
	assert_eq(NavalSystem.weather_from_roll(97, "autumn"), Enums.NavalWeather.TYPHOON)

func test_typhoon_winter() -> void:
	assert_eq(NavalSystem.weather_from_roll(97, "winter"), Enums.NavalWeather.TYPHOON)

func test_typhoon_inland_downgrades_to_storm() -> void:
	assert_eq(NavalSystem.weather_from_roll(97, "autumn", true), Enums.NavalWeather.STORM)

func test_weather_boundary_spring_clear_to_wind() -> void:
	assert_eq(NavalSystem.weather_from_roll(40, "spring"), Enums.NavalWeather.CLEAR)
	assert_eq(NavalSystem.weather_from_roll(41, "spring"), Enums.NavalWeather.CLEAR)
	assert_eq(NavalSystem.weather_from_roll(42, "spring"), Enums.NavalWeather.WIND)

func test_weather_determination_uses_dice() -> void:
	var w: int = NavalSystem.determine_weather(_dice, "autumn")
	assert_true(w >= 0 and w <= 4)


# =============================================================================
# Combat Modifiers
# =============================================================================

func test_clear_weather_no_modifiers() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.KOBUNE, Enums.NavalWeather.CLEAR), 0)
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.KOBUNE, Enums.NavalWeather.CLEAR), 0)

func test_rain_global_attack_minus_1() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.RAIN), -1)

func test_storm_global_attack_minus_2() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.STORM), -2)

func test_typhoon_global_attack_minus_3_defense_minus_2() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.TYPHOON), -3)
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.TYPHOON), -2)

func test_flat_bottomed_storm_defense_penalty() -> void:
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.KOBUNE, Enums.NavalWeather.STORM), -1)

func test_flat_bottomed_typhoon_defense_penalty() -> void:
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.KOBUNE, Enums.NavalWeather.TYPHOON), -4)

func test_koutetsukan_storm_extra_attack_penalty() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.KOUTETSUKAN, Enums.NavalWeather.STORM), -3)

func test_koutetsukan_typhoon_extra_attack_penalty() -> void:
	assert_eq(NavalSystem.get_weather_attack_modifier(Enums.ShipClass.KOUTETSUKAN, Enums.NavalWeather.TYPHOON), -4)

func test_sengokobune_no_additional_weather_penalties() -> void:
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.STORM), 0)
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.SENGOKOBUNE, Enums.NavalWeather.TYPHOON), -2)

func test_tortoise_no_additional_weather_penalties() -> void:
	assert_eq(NavalSystem.get_weather_defense_modifier(Enums.ShipClass.TORTOISE_OCEANGOING, Enums.NavalWeather.STORM), 0)


# =============================================================================
# Effective Stats
# =============================================================================

func test_effective_attack_clear() -> void:
	var ship := _make_ship(Enums.ShipClass.SENGOKOBUNE)
	assert_eq(NavalSystem.get_effective_attack(ship, Enums.NavalWeather.CLEAR), 4)

func test_effective_attack_mantis_sengokobune_bonus() -> void:
	var ship := _make_ship(Enums.ShipClass.SENGOKOBUNE, "Mantis")
	assert_eq(NavalSystem.get_effective_attack(ship, Enums.NavalWeather.CLEAR, true), 5)

func test_effective_attack_mantis_bonus_only_sengokobune() -> void:
	var ship := _make_ship(Enums.ShipClass.KOBUNE, "Mantis")
	assert_eq(NavalSystem.get_effective_attack(ship, Enums.NavalWeather.CLEAR, true), 3)

func test_effective_defense_floor_zero() -> void:
	var ship := _make_ship(Enums.ShipClass.SAMPAN)
	var def: int = NavalSystem.get_effective_defense(ship, Enums.NavalWeather.TYPHOON)
	assert_true(def >= 0)

func test_effective_attack_floor_zero() -> void:
	var ship := _make_ship(Enums.ShipClass.SAMPAN)
	var atk: int = NavalSystem.get_effective_attack(ship, Enums.NavalWeather.TYPHOON)
	assert_true(atk >= 0)


# =============================================================================
# Kobune Ranged Support
# =============================================================================

func test_kobune_ranged_clear() -> void:
	assert_eq(NavalSystem.get_kobune_ranged_dice(Enums.NavalWeather.CLEAR), 5)

func test_kobune_ranged_wind() -> void:
	assert_eq(NavalSystem.get_kobune_ranged_dice(Enums.NavalWeather.WIND), 5)

func test_kobune_ranged_rain_degraded() -> void:
	assert_eq(NavalSystem.get_kobune_ranged_dice(Enums.NavalWeather.RAIN), 3)

func test_kobune_ranged_storm_suppressed() -> void:
	assert_eq(NavalSystem.get_kobune_ranged_dice(Enums.NavalWeather.STORM), 0)

func test_kobune_ranged_typhoon_suppressed() -> void:
	assert_eq(NavalSystem.get_kobune_ranged_dice(Enums.NavalWeather.TYPHOON), 0)

func test_resolve_kobune_ranged_returns_zero_in_storm() -> void:
	assert_eq(NavalSystem.resolve_kobune_ranged(_dice, Enums.NavalWeather.STORM, 3), 0)

func test_resolve_kobune_ranged_positive_in_clear() -> void:
	var result: int = NavalSystem.resolve_kobune_ranged(_dice, Enums.NavalWeather.CLEAR, 3)
	assert_true(result > 0)


# =============================================================================
# Ram Attack (Koutetsukan)
# =============================================================================

func test_ram_only_koutetsukan() -> void:
	var ship := _make_ship(Enums.ShipClass.KOBUNE)
	var target := _make_ship(Enums.ShipClass.SENGOKOBUNE)
	var result: Dictionary = NavalSystem.resolve_ram(ship, target, _dice, Enums.NavalWeather.CLEAR)
	assert_false(result["success"])

func test_ram_koutetsukan_deals_damage_and_self_damage() -> void:
	var ship := _make_ship(Enums.ShipClass.KOUTETSUKAN, "Crab")
	var target := _make_ship(Enums.ShipClass.SENGOKOBUNE)
	var result: Dictionary = NavalSystem.resolve_ram(ship, target, _dice, Enums.NavalWeather.CLEAR)
	assert_true(result["success"])
	assert_eq(result["self_damage"], 5)
	assert_true(result["damage_dealt"] >= 0)
	assert_eq(result["effective_attack"], 6 + 8)


# =============================================================================
# Boarding Actions
# =============================================================================

func test_cannot_board_koutetsukan() -> void:
	assert_false(NavalSystem.can_board(Enums.ShipClass.KOBUNE, Enums.ShipClass.KOUTETSUKAN))

func test_sampan_cannot_board() -> void:
	assert_false(NavalSystem.can_board(Enums.ShipClass.SAMPAN, Enums.ShipClass.KOBUNE))

func test_kobune_can_board_sengokobune() -> void:
	assert_true(NavalSystem.can_board(Enums.ShipClass.KOBUNE, Enums.ShipClass.SENGOKOBUNE))

func test_boarding_first_round_penalty() -> void:
	assert_eq(NavalSystem.get_boarding_attack_modifier(true), -2)

func test_boarding_subsequent_round_no_penalty() -> void:
	assert_eq(NavalSystem.get_boarding_attack_modifier(false), 0)

func test_capture_prize_value_half_cost() -> void:
	assert_almost_eq(NavalSystem.compute_capture_prize_value(Enums.ShipClass.SENGOKOBUNE), 4.0, 0.01)

func test_capture_prize_value_kobune() -> void:
	assert_almost_eq(NavalSystem.compute_capture_prize_value(Enums.ShipClass.KOBUNE), 1.5, 0.01)


# =============================================================================
# Signature Ship Capture Decision
# =============================================================================

func test_signature_capture_yu_destroys() -> void:
	assert_eq(NavalSystem.evaluate_signature_capture_decision("Yu"), "destroy")

func test_signature_capture_seigyo_keeps() -> void:
	assert_eq(NavalSystem.evaluate_signature_capture_decision("Seigyo"), "keep")

func test_signature_capture_jin_returns() -> void:
	assert_eq(NavalSystem.evaluate_signature_capture_decision("Jin"), "return")

func test_signature_capture_chugi_destroys() -> void:
	assert_eq(NavalSystem.evaluate_signature_capture_decision("Chugi"), "destroy")

func test_signature_capture_default_destroys() -> void:
	assert_eq(NavalSystem.evaluate_signature_capture_decision("Dosatsu"), "destroy")


# =============================================================================
# Tortoise Escape Attempt
# =============================================================================

func test_escape_attempt_returns_result_dict() -> void:
	var result: Dictionary = NavalSystem.resolve_escape_attempt(
		_dice, 4, 3, 3, 3, Enums.NavalWeather.CLEAR)
	assert_has(result, "escaped")
	assert_has(result, "escape_total")
	assert_has(result, "pursue_total")
	assert_has(result, "weather_bonus")

func test_escape_attempt_weather_bonus_storm() -> void:
	var result: Dictionary = NavalSystem.resolve_escape_attempt(
		_dice, 4, 3, 3, 3, Enums.NavalWeather.STORM)
	assert_eq(result["weather_bonus"], 2)

func test_escape_attempt_weather_bonus_typhoon() -> void:
	var result: Dictionary = NavalSystem.resolve_escape_attempt(
		_dice, 4, 3, 3, 3, Enums.NavalWeather.TYPHOON)
	assert_eq(result["weather_bonus"], 3)


# =============================================================================
# Tortoise Recognition
# =============================================================================

func test_kaiu_auto_recognizes() -> void:
	assert_true(NavalSystem.can_auto_recognize_tortoise("Kaiu Engineer", 0))

func test_sailing_5_auto_recognizes() -> void:
	assert_true(NavalSystem.can_auto_recognize_by_sailing(5))

func test_sailing_4_does_not_auto_recognize() -> void:
	assert_false(NavalSystem.can_auto_recognize_by_sailing(4))

func test_recognition_tn_distance() -> void:
	assert_eq(NavalSystem.get_tortoise_recognition_tn("distance"), 25)

func test_recognition_tn_aboard() -> void:
	assert_eq(NavalSystem.get_tortoise_recognition_tn("aboard"), 20)

func test_recognition_tn_inspection() -> void:
	assert_eq(NavalSystem.get_tortoise_recognition_tn("inspection"), 15)


# =============================================================================
# Naval Trade Route Rules
# =============================================================================

func test_can_establish_non_ocean_route_without_ocean_ships() -> void:
	assert_true(NavalSystem.can_establish_naval_route([Enums.ShipClass.KOBUNE], false))

func test_cannot_establish_ocean_route_without_ocean_ships() -> void:
	assert_false(NavalSystem.can_establish_naval_route([Enums.ShipClass.KOBUNE], true))

func test_can_establish_ocean_route_with_sengokobune() -> void:
	assert_true(NavalSystem.can_establish_naval_route([Enums.ShipClass.SENGOKOBUNE], true))

func test_mantis_pirate_spawn_reduction() -> void:
	assert_almost_eq(NavalSystem.get_pirate_spawn_modifier("Mantis"), -0.10, 0.001)

func test_non_mantis_no_pirate_modifier() -> void:
	assert_almost_eq(NavalSystem.get_pirate_spawn_modifier("Crane"), 0.0, 0.001)

func test_mantis_pirate_suppression_bonus() -> void:
	assert_eq(NavalSystem.get_pirate_suppression_bonus("Mantis"), 3)

func test_non_mantis_no_suppression_bonus() -> void:
	assert_eq(NavalSystem.get_pirate_suppression_bonus("Lion"), 0)


# =============================================================================
# River Combat Constraints
# =============================================================================

func test_kobune_can_operate_on_river() -> void:
	assert_true(NavalSystem.can_operate_on_river(Enums.ShipClass.KOBUNE))

func test_sampan_can_operate_on_river() -> void:
	assert_true(NavalSystem.can_operate_on_river(Enums.ShipClass.SAMPAN))

func test_sengokobune_cannot_operate_on_river() -> void:
	assert_false(NavalSystem.can_operate_on_river(Enums.ShipClass.SENGOKOBUNE))

func test_koutetsukan_cannot_operate_on_river() -> void:
	assert_false(NavalSystem.can_operate_on_river(Enums.ShipClass.KOUTETSUKAN))

func test_standard_river_2_abreast() -> void:
	assert_eq(NavalSystem.get_max_ships_abreast(false), 2)

func test_major_river_3_abreast() -> void:
	assert_eq(NavalSystem.get_max_ships_abreast(true), 3)

func test_downstream_attack_bonus() -> void:
	assert_eq(NavalSystem.get_river_current_modifier(true), 1)

func test_upstream_attack_penalty() -> void:
	assert_eq(NavalSystem.get_river_current_modifier(false), -1)


# =============================================================================
# Shore-Based Attack Modifiers
# =============================================================================

func test_shore_to_ship_no_modifier() -> void:
	assert_eq(NavalSystem.get_shore_to_ship_modifier(), 0)

func test_ship_to_shore_penalty() -> void:
	assert_eq(NavalSystem.get_ship_to_shore_modifier(), -2)


# =============================================================================
# Navigation Bonuses
# =============================================================================

func test_tortoise_ocean_nav_bonus() -> void:
	assert_eq(NavalSystem.get_navigation_bonus(Enums.ShipClass.TORTOISE_OCEANGOING, false, false), 1)

func test_direction_finder_bonus() -> void:
	assert_eq(NavalSystem.get_navigation_bonus(Enums.ShipClass.SENGOKOBUNE, true, false), 1)

func test_shugenja_assist_bonus() -> void:
	assert_eq(NavalSystem.get_navigation_bonus(Enums.ShipClass.SENGOKOBUNE, false, true), 2)

func test_all_nav_bonuses_stack() -> void:
	assert_eq(NavalSystem.get_navigation_bonus(Enums.ShipClass.TORTOISE_OCEANGOING, true, true), 4)


# =============================================================================
# Civilian Vessel Rules
# =============================================================================

func test_merchant_barge_is_civilian() -> void:
	assert_true(NavalSystem.is_civilian_vessel(Enums.ShipClass.MERCHANT_BARGE))

func test_sampan_is_civilian() -> void:
	assert_true(NavalSystem.is_civilian_vessel(Enums.ShipClass.SAMPAN))

func test_kobune_not_civilian() -> void:
	assert_false(NavalSystem.is_civilian_vessel(Enums.ShipClass.KOBUNE))

func test_merchant_barge_auto_surrenders() -> void:
	assert_true(NavalSystem.civilian_auto_surrenders(Enums.ShipClass.MERCHANT_BARGE))

func test_sampan_auto_flees() -> void:
	assert_true(NavalSystem.civilian_auto_flees(Enums.ShipClass.SAMPAN))


# =============================================================================
# Movement
# =============================================================================

func test_koutetsukan_2_days_per_subtile() -> void:
	assert_eq(NavalSystem.get_movement_days(Enums.ShipClass.KOUTETSUKAN), 2)

func test_kobune_1_day_per_subtile() -> void:
	assert_eq(NavalSystem.get_movement_days(Enums.ShipClass.KOBUNE), 1)

func test_atakebune_1_day_per_subtile() -> void:
	assert_eq(NavalSystem.get_movement_days(Enums.ShipClass.ATAKEBUNE), 1)
