extends GutTest
## Tests for HordeSystem per GDD s2.4.4, s2.4.5, s2.4.6, s2.4.7.


# -- Helpers -------------------------------------------------------------------

func _make_tower_settlement(province_id: int, si: int = 8, koku: float = 5.0) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = province_id * 10
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = si
	s.koku_stockpile = koku
	return s


# =============================================================================
# Unit Stat Table (s2.4.7 — LOCKED)
# =============================================================================

func test_bakemono_stats_locked() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO)
	assert_eq(stats["attack"], 2)
	assert_eq(stats["defense"], 1)
	assert_eq(stats["morale"], 7)
	assert_eq(stats["morale_defense"], 1)
	assert_eq(stats["health"], 153)
	assert_true(stats["immune_routing_contagion"])


func test_bakemono_warrior_stats_locked() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO_WARRIOR)
	assert_eq(stats["attack"], 3)
	assert_eq(stats["defense"], 2)
	assert_eq(stats["morale"], 9)
	assert_eq(stats["morale_defense"], 2)


func test_zombie_no_morale_flag() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.ZOMBIE)
	assert_eq(stats["morale"], -1)
	assert_true(stats["no_morale"])
	assert_true(stats["immune_routing_contagion"])


func test_skeleton_first_round_bonus() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.SKELETON_WARRIOR)
	assert_eq(stats["first_round_attack_bonus"], 1)
	assert_eq(stats["morale"], -1)


func test_maho_tsukai_horde_command_flag() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.MAHO_TSUKAI)
	assert_true(stats["horde_command"])
	assert_true(stats["commander_unit"])


func test_ogre_warrior_wall_breaker_stats() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.OGRE_WARRIOR)
	assert_eq(stats["attack"], 7)
	assert_eq(stats["defense"], 6)
	assert_eq(stats["wall_breaker_attack_bonus"], 3)
	assert_eq(stats["wall_breaker_si_ignore"], 2)


func test_ogre_warlord_stats_locked() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.OGRE_WARLORD)
	assert_eq(stats["attack"], 8)
	assert_eq(stats["defense"], 7)
	assert_eq(stats["morale"], 18)
	assert_eq(stats["morale_defense"], 8)
	assert_true(stats["brutal_authority"])


func test_ravenous_ogre_feeding_frenzy() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.RAVENOUS_OGRE)
	assert_eq(stats["attack"], 9)
	assert_true(stats["feeding_frenzy"])


func test_unit_stats_include_unit_type_key() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO)
	assert_true(stats.has("unit_type"))
	assert_eq(stats["unit_type"], Enums.ShadowlandsUnitType.BAKEMONO)


func test_unit_stats_include_current_health() -> void:
	var stats := HordeSystem.get_unit_stats(Enums.ShadowlandsUnitType.ZOMBIE)
	assert_eq(stats["current_health"], 153)


# =============================================================================
# Horde Frequency Roll (s2.4.4 — LOCKED)
# =============================================================================

func test_roll_horde_fires_returns_bool() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: bool = HordeSystem.roll_horde_fires(dice)
	assert_true(result is bool)


func test_horde_roll_fires_every_two_seasons() -> void:
	assert_eq(HordeSystem.HORDE_ROLL_SEASON_INTERVAL, 2)


func test_base_probability_is_50_percent() -> void:
	assert_almost_eq(HordeSystem.HORDE_BASE_PROBABILITY, 0.50, 0.001)


# =============================================================================
# Invasion Type Roll (s2.4.6 — LOCKED)
# =============================================================================

func test_invasion_type_returns_valid_enum() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: int = HordeSystem.roll_invasion_type(dice)
	assert_true(result in [
		Enums.InvasionType.JIGOKU_HORDE,
		Enums.InvasionType.UNDEAD_LEGION,
		Enums.InvasionType.ONI_LED,
		Enums.InvasionType.ONI_LED_SPAWN,
	])


func test_invasion_type_jigoku_60_percent_majority() -> void:
	# Run 200 rolls and verify Jigoku Horde is the most common (roughly 60%).
	var dice := DiceEngine.new()
	dice.set_seed(99)
	var counts: Dictionary = {}
	for _i: int in range(200):
		var t: int = HordeSystem.roll_invasion_type(dice)
		counts[t] = int(counts.get(t, 0)) + 1
	var jigoku_count: int = int(counts.get(Enums.InvasionType.JIGOKU_HORDE, 0))
	# Expect roughly 60% but allow wide margin for test stability.
	assert_true(jigoku_count > 80,
		"Jigoku Horde should win majority of rolls (got %d/200)" % jigoku_count)


# =============================================================================
# Target Tower Selection (s2.4.4 — LOCKED)
# =============================================================================

func test_select_target_returns_valid_province() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var towers: Array[int] = [10, 20, 30]
	var result: int = HordeSystem.select_target_tower(towers, -1, dice)
	assert_true(result in towers)


func test_select_target_single_tower_always_selected() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var towers: Array[int] = [42]
	var result: int = HordeSystem.select_target_tower(towers, -1, dice)
	assert_eq(result, 42)


func test_select_target_empty_returns_minus_one() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: int = HordeSystem.select_target_tower([] as Array[int], -1, dice)
	assert_eq(result, -1)


func test_last_targeted_appears_with_double_weight() -> void:
	# With 2 towers and last_targeted = 10, the pool is [10, 20, 10]
	# so tower 10 has roughly 2/3 probability.
	var dice := DiceEngine.new()
	dice.set_seed(7)
	var towers: Array[int] = [10, 20]
	var counts: Dictionary = {10: 0, 20: 0}
	for _i: int in range(120):
		var r: int = HordeSystem.select_target_tower(towers, 10, dice)
		counts[r] = int(counts[r]) + 1
	# Tower 10 should win roughly 2/3 of the time.
	var pct_10: float = float(int(counts[10])) / 120.0
	assert_true(pct_10 > 0.50,
		"Last-targeted tower should appear with 2x probability (got %.0f%%)" % (pct_10 * 100))


# =============================================================================
# Horde Company Generation (s2.4.4, s2.4.6, s2.4.7 — LOCKED)
# =============================================================================

func test_jigoku_horde_base_has_seven_companies() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var companies := HordeSystem.generate_horde_companies(
		Enums.InvasionType.JIGOKU_HORDE, 0, dice
	)
	assert_eq(companies.size(), 7, "Base Jigoku Horde: 4 Bakemono + 2 Bake Warrior + 1 Ogre")


func test_jigoku_horde_strength_adds_companies() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var companies := HordeSystem.generate_horde_companies(
		Enums.InvasionType.JIGOKU_HORDE, 3, dice
	)
	assert_eq(companies.size(), 10, "Strength 3 adds 3 extra companies")


func test_undead_legion_base_has_seven_companies() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var companies := HordeSystem.generate_horde_companies(
		Enums.InvasionType.UNDEAD_LEGION, 0, dice
	)
	assert_eq(companies.size(), 7, "Base Undead Legion: 3 Zombie + 2 Skeleton + 1 Revenant + 1 Maho")


func test_undead_legion_includes_maho_tsukai() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var companies := HordeSystem.generate_horde_companies(
		Enums.InvasionType.UNDEAD_LEGION, 0, dice
	)
	var has_maho: bool = false
	for c: Dictionary in companies:
		if c.get("unit_type", -1) == Enums.ShadowlandsUnitType.MAHO_TSUKAI:
			has_maho = true
			break
	assert_true(has_maho, "Undead Legion must include a Maho-tsukai")


func test_oni_led_companies_same_structure_as_jigoku() -> void:
	var dice1 := DiceEngine.new()
	dice1.set_seed(42)
	var dice2 := DiceEngine.new()
	dice2.set_seed(42)
	var jigoku := HordeSystem.generate_horde_companies(
		Enums.InvasionType.JIGOKU_HORDE, 0, dice1
	)
	var oni_led := HordeSystem.generate_horde_companies(
		Enums.InvasionType.ONI_LED, 0, dice2
	)
	# Same baseline companies (Oni is separate from the company list).
	assert_eq(jigoku.size(), oni_led.size())


func test_zero_strength_no_bonus_companies() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var base := HordeSystem.generate_horde_companies(
		Enums.InvasionType.JIGOKU_HORDE, 0, dice
	).size()
	dice.set_seed(1)
	var with_strength := HordeSystem.generate_horde_companies(
		Enums.InvasionType.JIGOKU_HORDE, 5, dice
	).size()
	assert_eq(with_strength - base, 5)


# =============================================================================
# Assault SI Hit (s2.4.5 — LOCKED)
# =============================================================================

func test_assault_si_hit_decisive_victory_is_1() -> void:
	assert_eq(
		HordeSystem.get_assault_si_hit(Enums.HordeBattleOutcome.DECISIVE_DEFENDER_VICTORY),
		1
	)


func test_assault_si_hit_contested_is_2() -> void:
	assert_eq(
		HordeSystem.get_assault_si_hit(Enums.HordeBattleOutcome.CONTESTED_BATTLE),
		2
	)


func test_assault_si_hit_pushed_back_is_3() -> void:
	assert_eq(
		HordeSystem.get_assault_si_hit(Enums.HordeBattleOutcome.ATTACKER_PUSHED_BACK),
		3
	)


func test_assault_si_hit_overrun_is_4() -> void:
	assert_eq(
		HordeSystem.get_assault_si_hit(Enums.HordeBattleOutcome.DEFENDER_OVERRUN),
		4
	)


func test_apply_assault_si_hit_reduces_settlement_si() -> void:
	var tower := _make_tower_settlement(10, 8)
	var result := HordeSystem.apply_assault_si_hit(
		tower, Enums.HordeBattleOutcome.CONTESTED_BATTLE
	)
	assert_eq(tower.wall_si, 6, "Contested battle: SI 8 - 2 = 6")
	assert_eq(result["si_hit"], 2)
	assert_eq(result["new_si"], 6)
	assert_eq(result["old_si"], 8)


func test_apply_assault_si_hit_clamps_at_zero() -> void:
	var tower := _make_tower_settlement(10, 2)
	var result := HordeSystem.apply_assault_si_hit(
		tower, Enums.HordeBattleOutcome.ATTACKER_PUSHED_BACK
	)
	assert_eq(tower.wall_si, 0, "SI cannot go below 0")
	assert_eq(result["new_si"], 0)


func test_apply_assault_si_hit_breach_flag_on_overrun() -> void:
	var tower := _make_tower_settlement(10, 1)
	var result := HordeSystem.apply_assault_si_hit(
		tower, Enums.HordeBattleOutcome.DEFENDER_OVERRUN
	)
	assert_true(result["breach"], "Overrun with SI reaching 0 should set breach flag")


func test_apply_assault_si_hit_no_breach_on_decisive_victory() -> void:
	var tower := _make_tower_settlement(10, 8)
	var result := HordeSystem.apply_assault_si_hit(
		tower, Enums.HordeBattleOutcome.DECISIVE_DEFENDER_VICTORY
	)
	assert_false(result["breach"])


# =============================================================================
# Strength Counter (s2.4.4 — LOCKED)
# =============================================================================

func test_strength_counter_starts_at_zero() -> void:
	var counters: Dictionary = {}
	assert_eq(HordeSystem.get_strength_counter(counters), 0)


func test_increment_strength_counter_adds_one() -> void:
	var counters: Dictionary = {}
	HordeSystem.increment_strength_counter(counters, [] as Array[int])
	assert_eq(HordeSystem.get_strength_counter(counters), 1)


func test_increment_strength_counter_accumulates() -> void:
	var counters: Dictionary = {}
	for _i: int in range(5):
		HordeSystem.increment_strength_counter(counters, [] as Array[int])
	assert_eq(HordeSystem.get_strength_counter(counters), 5)


func test_reset_strength_counter_sets_to_zero() -> void:
	var counters: Dictionary = {"global": 7}
	HordeSystem.reset_strength_counter(counters)
	assert_eq(HordeSystem.get_strength_counter(counters), 0)


# =============================================================================
# Full Horde Generation (s2.4.4 — LOCKED)
# =============================================================================

func test_generate_horde_returns_horde_data() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var towers: Array[int] = [10, 20, 30]
	var counters: Dictionary = {}
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 100)
	assert_not_null(horde)
	assert_true(horde is HordeData)


func test_generate_horde_target_is_valid_tower() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(2)
	var towers: Array[int] = [10, 20, 30]
	var counters: Dictionary = {}
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 1)
	assert_true(horde.target_province_id in towers)


func test_generate_horde_resets_strength_counter() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var towers: Array[int] = [10]
	var counters: Dictionary = {"global": 4}
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 1)
	assert_eq(horde.strength_at_formation, 4, "Strength at formation captures counter value")
	assert_eq(HordeSystem.get_strength_counter(counters), 0, "Counter reset after horde fires")


func test_generate_horde_has_oni_only_for_oni_types() -> void:
	var dice := DiceEngine.new()
	var towers: Array[int] = [10]
	var counters: Dictionary = {}

	# Force Jigoku type by checking non-Oni invasion type.
	# We can't guarantee the roll, but we can verify the has_oni flag consistency.
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 1)
	if horde.invasion_type in [Enums.InvasionType.ONI_LED, Enums.InvasionType.ONI_LED_SPAWN]:
		assert_true(horde.has_oni)
	else:
		assert_false(horde.has_oni)


func test_generate_horde_has_companies() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(5)
	var towers: Array[int] = [10]
	var counters: Dictionary = {}
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 1)
	assert_true(horde.companies.size() >= 7, "Every horde has at least 7 companies")


func test_generate_horde_ic_day_recorded() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var towers: Array[int] = [10]
	var counters: Dictionary = {}
	var horde := HordeSystem.generate_horde(towers, -1, counters, dice, 250)
	assert_eq(horde.ic_day_generated, 250)
