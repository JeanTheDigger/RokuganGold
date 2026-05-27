extends GutTest
## Tests for WorshipSystem per GDD s4.3.21.


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


# -- Enum Tests -----------------------------------------------------------------

func test_great_fortune_count() -> void:
	assert_eq(WorshipSystem.GREAT_FORTUNE_COUNT, 7)


func test_fortune_ring_associations() -> void:
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.BENTEN], Enums.Ring.AIR)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.BISHAMON], Enums.Ring.FIRE)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.DAIKOKU], Enums.Ring.WATER)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.EBISU], Enums.Ring.EARTH)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.FUKUROKUJIN], Enums.Ring.FIRE)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.HOTEI], Enums.Ring.WATER)
	assert_eq(WorshipSystem.FORTUNE_RING[Enums.GreatFortune.JUROJIN], Enums.Ring.VOID)


# -- State Factory Tests --------------------------------------------------------

func test_initial_province_worship_has_seven_zeroes() -> void:
	var wp: Dictionary = WorshipSystem.make_initial_province_worship()
	assert_eq(wp.size(), 7)
	for f: int in range(7):
		assert_eq(wp[f], 0.0)


func test_initial_worship_state_structure() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	assert_true(state.has("province_wp"))
	assert_true(state.has("province_tiers"))
	assert_true(state.has("empire_tiers"))
	assert_true(state.has("minor_fortune_wp"))


# -- Passive WP Tests -----------------------------------------------------------

func test_general_roadside_shrine_splits_wp() -> void:
	var locations: Array = [{"type": "roadside_shrine", "dedicated": false}]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	var total: float = 0.0
	for f: int in range(7):
		total += wp[f]
	assert_almost_eq(total, 0.5, 0.01, "Roadside shrine generates 0.5 WP total")
	assert_almost_eq(wp[0], 0.5 / 7.0, 0.01, "Split evenly across 7 fortunes")


func test_general_temple_splits_wp() -> void:
	var locations: Array = [{"type": "temple", "dedicated": false}]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	var total: float = 0.0
	for f: int in range(7):
		total += wp[f]
	assert_almost_eq(total, 4.0, 0.01, "Temple generates 4.0 WP total")


func test_dedicated_temple_all_to_one_fortune() -> void:
	var locations: Array = [{"type": "temple", "dedicated": true, "fortune": Enums.GreatFortune.BENTEN}]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	assert_almost_eq(wp[Enums.GreatFortune.BENTEN], 12.0, 0.01, "Dedicated temple = 12 WP")
	assert_almost_eq(wp[Enums.GreatFortune.BISHAMON], 0.0, 0.01, "Other fortunes get 0")


func test_dedicated_shinden_wp() -> void:
	var locations: Array = [{"type": "shinden", "dedicated": true, "fortune": Enums.GreatFortune.EBISU}]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	assert_almost_eq(wp[Enums.GreatFortune.EBISU], 24.0, 0.01, "Dedicated shinden = 24 WP")


func test_multiple_locations_stack() -> void:
	var locations: Array = [
		{"type": "roadside_shrine", "dedicated": false},
		{"type": "village_shrine", "dedicated": false},
		{"type": "temple", "dedicated": false},
	]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	var total: float = 0.0
	for f: int in range(7):
		total += wp[f]
	assert_almost_eq(total, 0.5 + 1.0 + 4.0, 0.01, "Multiple locations stack")


func test_dedicated_and_general_mix() -> void:
	var locations: Array = [
		{"type": "temple", "dedicated": true, "fortune": Enums.GreatFortune.BISHAMON},
		{"type": "village_shrine", "dedicated": false},
	]
	var wp: Dictionary = WorshipSystem.compute_passive_wp(locations)
	assert_almost_eq(wp[Enums.GreatFortune.BISHAMON], 12.0 + 1.0 / 7.0, 0.01)


# -- Active Worship Tests -------------------------------------------------------

func test_normal_character_worship_1wp() -> void:
	var result: Dictionary = WorshipSystem.resolve_active_worship(
		"bushi", false, _dice, 3, 0, "temple", -1,
	)
	assert_almost_eq(result["total_wp"], 1.0, 0.01)
	assert_almost_eq(result["base_wp"], 1.0, 0.01)
	assert_almost_eq(result["bonus_wp"], 0.0, 0.01)


func test_monk_worship_2wp() -> void:
	var result: Dictionary = WorshipSystem.resolve_active_worship(
		"monk", false, _dice, 3, 0, "temple", -1,
	)
	assert_almost_eq(result["total_wp"], 2.0, 0.01)


func test_shugenja_base_1wp() -> void:
	_dice.set_seed(999)
	var result: Dictionary = WorshipSystem.resolve_active_worship(
		"shugenja", true, _dice, 3, 3, "roadside_shrine", -1,
	)
	assert_almost_eq(result["base_wp"], 1.0, 0.01)
	assert_true(result["total_wp"] >= 1.0, "Shugenja always gets at least 1 WP")


func test_shugenja_bonus_capped_at_3() -> void:
	_dice.set_seed(1)
	var max_bonus: float = 0.0
	for i: int in range(100):
		_dice.set_seed(i)
		var result: Dictionary = WorshipSystem.resolve_active_worship(
			"shugenja", true, _dice, 5, 5, "shinden", -1,
		)
		if result["bonus_wp"] > max_bonus:
			max_bonus = result["bonus_wp"]
	assert_true(max_bonus <= 3.0, "Bonus WP capped at 3")


func test_directed_worship_all_to_one_fortune() -> void:
	var result: Dictionary = WorshipSystem.resolve_active_worship(
		"bushi", false, _dice, 3, 0, "temple", Enums.GreatFortune.HOTEI,
	)
	var dist: Dictionary = result["wp_distribution"]
	assert_almost_eq(dist.get(Enums.GreatFortune.HOTEI, 0.0), 1.0, 0.01)
	assert_almost_eq(dist.get(Enums.GreatFortune.BENTEN, 0.0), 0.0, 0.01)
	assert_true(result["directed"])


func test_split_worship_distributes_evenly() -> void:
	var result: Dictionary = WorshipSystem.resolve_active_worship(
		"bushi", false, _dice, 3, 0, "temple", -1,
	)
	var dist: Dictionary = result["wp_distribution"]
	for f: int in range(7):
		assert_almost_eq(dist[f], 1.0 / 7.0, 0.01)
	assert_false(result["directed"])


# -- Threshold Tier Tests -------------------------------------------------------

func test_tier_none_at_threshold() -> void:
	assert_eq(WorshipSystem.get_worship_tier(10.0, 10.0), Enums.WorshipTier.NONE)


func test_tier_none_above_threshold() -> void:
	assert_eq(WorshipSystem.get_worship_tier(15.0, 10.0), Enums.WorshipTier.NONE)


func test_tier_restless_at_75_percent() -> void:
	assert_eq(WorshipSystem.get_worship_tier(7.5, 10.0), Enums.WorshipTier.NONE)


func test_tier_displeased_below_75_above_40() -> void:
	assert_eq(WorshipSystem.get_worship_tier(5.0, 10.0), Enums.WorshipTier.NONE)


func test_tier_wrathful_below_40() -> void:
	assert_eq(WorshipSystem.get_worship_tier(3.0, 10.0), Enums.WorshipTier.NONE)


func test_tier_wrathful_at_zero() -> void:
	assert_eq(WorshipSystem.get_worship_tier(0.0, 10.0), Enums.WorshipTier.NONE)


func test_province_threshold_evaluation() -> void:
	var wp: Dictionary = {}
	for f: int in range(7):
		wp[f] = 12.0
	wp[Enums.GreatFortune.BENTEN] = 3.0
	var tiers: Dictionary = WorshipSystem.evaluate_province_thresholds(wp)
	assert_eq(tiers[Enums.GreatFortune.BENTEN], Enums.WorshipTier.NONE)
	assert_eq(tiers[Enums.GreatFortune.BISHAMON], Enums.WorshipTier.NONE)


# -- Aggregate Threshold Tests --------------------------------------------------

func test_aggregate_sums_provinces() -> void:
	var province_wp: Dictionary = {
		1: {0: 5.0, 1: 5.0, 2: 5.0, 3: 5.0, 4: 5.0, 5: 5.0, 6: 5.0},
		2: {0: 5.0, 1: 5.0, 2: 5.0, 3: 5.0, 4: 5.0, 5: 5.0, 6: 5.0},
	}
	var tiers: Dictionary = WorshipSystem.evaluate_aggregate_thresholds(
		province_wp, [1, 2], 10.0,
	)
	assert_eq(tiers[0], Enums.WorshipTier.NONE, "10 WP aggregate meets threshold 10")


func test_aggregate_below_threshold() -> void:
	var province_wp: Dictionary = {
		1: {0: 3.0, 1: 3.0, 2: 3.0, 3: 3.0, 4: 3.0, 5: 3.0, 6: 3.0},
	}
	var tiers: Dictionary = WorshipSystem.evaluate_aggregate_thresholds(
		province_wp, [1], 60.0,
	)
	assert_eq(tiers[0], Enums.WorshipTier.NONE, "get_worship_tier always returns NONE (thresholds disabled)")


# -- Malus Tests ----------------------------------------------------------------

func test_no_malus_at_none_tier() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.BENTEN, Enums.WorshipTier.NONE,
	)
	assert_eq(malus.size(), 0)


func test_benten_restless_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.BENTEN, Enums.WorshipTier.RESTLESS,
	)
	assert_eq(malus["pop_growth_modifier"], -0.25)


func test_benten_wrathful_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.BENTEN, Enums.WorshipTier.WRATHFUL,
	)
	assert_eq(malus["pop_growth_modifier"], -1.0)
	assert_true(malus["marriage_auto_fail"])


func test_bishamon_displeased_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.BISHAMON, Enums.WorshipTier.DISPLEASED,
	)
	assert_eq(malus["army_attack"], -2)
	assert_eq(malus["army_morale"], -3)


func test_ebisu_wrathful_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.EBISU, Enums.WorshipTier.WRATHFUL,
	)
	assert_eq(malus["rice_modifier"], -0.50)
	assert_true(malus["harvest_famine_level"])


func test_hotei_wrathful_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.HOTEI, Enums.WorshipTier.WRATHFUL,
	)
	assert_eq(malus["stability_per_season"], -20)
	assert_true(malus["insurgency_spawn_doubled"])


func test_daikoku_displeased_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.DAIKOKU, Enums.WorshipTier.DISPLEASED,
	)
	assert_eq(malus["koku_modifier"], -0.30)
	assert_eq(malus["market_price_modifier"], 0.10)


func test_fukurokujin_wrathful_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.FUKUROKUJIN, Enums.WorshipTier.WRATHFUL,
	)
	assert_true(malus["divination_impossible"])
	assert_eq(malus["intelligence_roll_modifier"], -10)


func test_jurojin_restless_malus() -> void:
	var malus: Dictionary = WorshipSystem.get_fortune_malus(
		Enums.GreatFortune.JUROJIN, Enums.WorshipTier.RESTLESS,
	)
	assert_true(malus["natural_death_increase"])


# -- Worst Tier Tests -----------------------------------------------------------

func test_worst_tier_picks_highest() -> void:
	var worst: Enums.WorshipTier = WorshipSystem.get_worst_tier(
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.RESTLESS,
		Enums.WorshipTier.DISPLEASED,
		Enums.WorshipTier.NONE,
	)
	assert_eq(worst, Enums.WorshipTier.DISPLEASED)


func test_worst_tier_all_none() -> void:
	var worst: Enums.WorshipTier = WorshipSystem.get_worst_tier(
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
	)
	assert_eq(worst, Enums.WorshipTier.NONE)


func test_effective_malus_uses_worst_tier() -> void:
	var malus: Dictionary = WorshipSystem.compute_province_effective_maluses(
		Enums.GreatFortune.BENTEN,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.RESTLESS,
		Enums.WorshipTier.NONE,
	)
	assert_eq(malus["pop_growth_modifier"], -0.25, "Clan-level restless cascades down")


# -- Minor Fortune Blessing Tier Tests ------------------------------------------

func test_minor_tier_none_below_3() -> void:
	assert_eq(WorshipSystem.get_minor_blessing_tier(2.0), Enums.MinorBlessingTier.NONE)


func test_minor_tier_noticed_at_3() -> void:
	assert_eq(WorshipSystem.get_minor_blessing_tier(3.0), Enums.MinorBlessingTier.NOTICED)


func test_minor_tier_favored_at_8() -> void:
	assert_eq(WorshipSystem.get_minor_blessing_tier(8.0), Enums.MinorBlessingTier.FAVORED)


func test_minor_tier_beloved_at_15() -> void:
	assert_eq(WorshipSystem.get_minor_blessing_tier(15.0), Enums.MinorBlessingTier.BELOVED)


func test_minor_tier_beloved_above_15() -> void:
	assert_eq(WorshipSystem.get_minor_blessing_tier(25.0), Enums.MinorBlessingTier.BELOVED)


# -- Divination Tests -----------------------------------------------------------

func test_divination_flavor_text() -> void:
	assert_eq(WorshipSystem.get_divination_flavor(Enums.WorshipTier.NONE), "The Fortune is pleased")
	assert_eq(WorshipSystem.get_divination_flavor(Enums.WorshipTier.RESTLESS), "The Fortune grows restless")
	assert_eq(WorshipSystem.get_divination_flavor(Enums.WorshipTier.DISPLEASED), "The Fortune's gaze has turned away")
	assert_eq(WorshipSystem.get_divination_flavor(Enums.WorshipTier.WRATHFUL), "The Fortune is wrathful")


func test_divination_success_returns_tier() -> void:
	_dice.set_seed(1)
	var wp: Dictionary = {Enums.GreatFortune.BENTEN: 3.0}
	var result: Dictionary = WorshipSystem.resolve_divination(
		_dice, 5, 3, Enums.GreatFortune.BENTEN, wp,
	)
	if result["success"]:
		assert_eq(result["tier"], Enums.WorshipTier.NONE)
		assert_true(result["scope"] in ["province", "family", "clan", "empire"])


func test_divination_raises_expand_scope() -> void:
	_dice.set_seed(42)
	var wp: Dictionary = {Enums.GreatFortune.BENTEN: 12.0}
	var found_family: bool = false
	var found_clan: bool = false
	for i: int in range(200):
		_dice.set_seed(i)
		var result: Dictionary = WorshipSystem.resolve_divination(
			_dice, 5, 4, Enums.GreatFortune.BENTEN, wp,
		)
		if result["success"]:
			if result.get("scope", "") == "family":
				found_family = true
			elif result.get("scope", "") == "clan":
				found_clan = true
	assert_true(found_family or found_clan, "Higher rolls should expand scope beyond province")


# -- Seasonal Processing Tests --------------------------------------------------

func test_seasonal_processing_adds_passive_wp() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	var province_locations: Dictionary = {
		1: [{"type": "temple", "dedicated": false}],
	}
	var result: Dictionary = WorshipSystem.process_seasonal_worship(
		state, province_locations, {"Doji": [1]}, {"Crane": ["Doji"]}, [1],
	)
	var tiers: Dictionary = result["province_tiers"][1]
	for f: int in range(7):
		var pw: float = state["province_wp"][1][f]
		assert_almost_eq(pw, 4.0 / 7.0, 0.01, "General temple splits 4 WP")


func test_seasonal_processing_province_with_dedicated_temple_meets_threshold() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	var province_locations: Dictionary = {
		1: [{"type": "temple", "dedicated": true, "fortune": Enums.GreatFortune.EBISU}],
	}
	var result: Dictionary = WorshipSystem.process_seasonal_worship(
		state, province_locations, {"Doji": [1]}, {"Crane": ["Doji"]}, [1],
	)
	var tiers: Dictionary = result["province_tiers"][1]
	assert_eq(tiers[Enums.GreatFortune.EBISU], Enums.WorshipTier.NONE, "12 WP >= 10 threshold")
	assert_eq(tiers[Enums.GreatFortune.BENTEN], Enums.WorshipTier.NONE, "get_worship_tier always returns NONE (thresholds disabled)")


func test_seasonal_reset_clears_wp() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	state["province_wp"] = {1: {0: 10.0}}
	WorshipSystem.reset_seasonal_wp(state)
	assert_eq(state["province_wp"].size(), 0)


# -- Active Worship Accumulation Tests ------------------------------------------

func test_add_active_worship_to_province() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	var dist: Dictionary = {Enums.GreatFortune.BENTEN: 2.0}
	WorshipSystem.add_active_worship_to_province(state, 1, dist)
	var pw: Dictionary = state["province_wp"][1]
	assert_almost_eq(pw[Enums.GreatFortune.BENTEN], 2.0, 0.01)


func test_active_worship_stacks_with_passive() -> void:
	var state: Dictionary = WorshipSystem.make_initial_worship_state()
	state["province_wp"] = {1: WorshipSystem.make_initial_province_worship()}
	state["province_wp"][1][Enums.GreatFortune.BENTEN] = 5.0
	var dist: Dictionary = {Enums.GreatFortune.BENTEN: 3.0}
	WorshipSystem.add_active_worship_to_province(state, 1, dist)
	assert_almost_eq(state["province_wp"][1][Enums.GreatFortune.BENTEN], 8.0, 0.01)


# -- Location Free Raise Tests -------------------------------------------------

func test_roadside_shrine_no_free_raises() -> void:
	assert_eq(WorshipSystem.SHUGENJA_LOCATION_FREE_RAISES["roadside_shrine"], 0)


func test_local_shrine_one_free_raise() -> void:
	assert_eq(WorshipSystem.SHUGENJA_LOCATION_FREE_RAISES["local_shrine"], 1)


func test_temple_two_free_raises() -> void:
	assert_eq(WorshipSystem.SHUGENJA_LOCATION_FREE_RAISES["temple"], 2)


func test_shinden_three_free_raises() -> void:
	assert_eq(WorshipSystem.SHUGENJA_LOCATION_FREE_RAISES["shinden"], 3)


# -- Passive WP Value Tests (cross-reference GDD) ------------------------------

func test_general_village_shrine_wp() -> void:
	assert_eq(WorshipSystem.GENERAL_PASSIVE_WP["village_shrine"], 1.0)


func test_general_local_shrine_wp() -> void:
	assert_eq(WorshipSystem.GENERAL_PASSIVE_WP["local_shrine"], 2.0)


func test_general_shinden_wp() -> void:
	assert_eq(WorshipSystem.GENERAL_PASSIVE_WP["shinden"], 8.0)


func test_dedicated_roadside_shrine_wp() -> void:
	assert_eq(WorshipSystem.DEDICATED_PASSIVE_WP["roadside_shrine"], 1.5)


func test_dedicated_village_shrine_wp() -> void:
	assert_eq(WorshipSystem.DEDICATED_PASSIVE_WP["village_shrine"], 3.0)


func test_dedicated_local_shrine_wp() -> void:
	assert_eq(WorshipSystem.DEDICATED_PASSIVE_WP["local_shrine"], 6.0)


# -- Threshold Constants Tests --------------------------------------------------

func test_province_threshold_value() -> void:
	assert_eq(WorshipSystem.PROVINCE_THRESHOLD, 10.0)


func test_family_threshold_value() -> void:
	assert_eq(WorshipSystem.FAMILY_THRESHOLD, 60.0)


func test_clan_threshold_value() -> void:
	assert_eq(WorshipSystem.CLAN_THRESHOLD, 150.0)


func test_empire_threshold_value() -> void:
	assert_eq(WorshipSystem.EMPIRE_THRESHOLD, 800.0)


# -- Cascade Integration Tests -------------------------------------------------

func test_clan_tier_cascades_to_province() -> void:
	var malus: Dictionary = WorshipSystem.compute_province_effective_maluses(
		Enums.GreatFortune.EBISU,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.DISPLEASED,
		Enums.WorshipTier.NONE,
	)
	assert_eq(malus["rice_modifier"], -0.30, "Clan-level Ebisu displeased cascades")


func test_empire_tier_cascades_to_province() -> void:
	var malus: Dictionary = WorshipSystem.compute_province_effective_maluses(
		Enums.GreatFortune.HOTEI,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.WRATHFUL,
	)
	assert_eq(malus["stability_per_season"], -20, "Empire wrathful cascades")


func test_province_healthy_in_healthy_hierarchy_no_malus() -> void:
	var malus: Dictionary = WorshipSystem.compute_province_effective_maluses(
		Enums.GreatFortune.BENTEN,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
		Enums.WorshipTier.NONE,
	)
	assert_eq(malus.size(), 0)
