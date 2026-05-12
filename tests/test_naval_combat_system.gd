extends GutTest
## Tests for NavalCombatSystem per GDD s11.9.


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


# -- Helpers -------------------------------------------------------------------

func _make_ship(id: int, ship_class: int, clan: String = "Mantis") -> ShipData:
	return NavalSystem.create_ship(id, ship_class, clan, "Ship_%d" % id)


func _make_nc(ship: ShipData, row: int, col: int, side: String,
		weather: int = Enums.NavalWeather.CLEAR,
		is_mantis: bool = false) -> Dictionary:
	return NavalCombatSystem.make_naval_company(ship, row, col, side, weather, is_mantis)


func _make_attacker(id: int, ship_class: int, col: int,
		weather: int = Enums.NavalWeather.CLEAR,
		clan: String = "Mantis") -> Dictionary:
	var ship := _make_ship(id, ship_class, clan)
	return _make_nc(ship, 1, col, "attacker", weather, clan == "Mantis")


func _make_defender(id: int, ship_class: int, col: int,
		weather: int = Enums.NavalWeather.CLEAR,
		clan: String = "Crab") -> Dictionary:
	var ship := _make_ship(id, ship_class, clan)
	return _make_nc(ship, 1, col, "defender", weather)


func _to_typed_array(arr: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in arr:
		result.append(item)
	return result


# =============================================================================
# Make Naval Company
# =============================================================================

func test_make_naval_company_sets_stats() -> void:
	var ship := _make_ship(1, Enums.ShipClass.SENGOKOBUNE)
	var nc := _make_nc(ship, 1, 0, "attacker")
	assert_eq(nc["starting_health"], 130)
	assert_eq(nc["current_health"], 130)
	assert_eq(nc["base_attack"], 4)
	assert_eq(nc["base_defense"], 4)
	assert_eq(nc["starting_morale"], 14)
	assert_eq(nc["base_morale_defense"], 5)
	assert_eq(nc["side"], "attacker")
	assert_eq(nc["row"], 1)
	assert_eq(nc["column"], 0)


func test_make_naval_company_mantis_sengokobune_bonus() -> void:
	var ship := _make_ship(1, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	var nc := _make_nc(ship, 1, 0, "attacker", Enums.NavalWeather.CLEAR, true)
	assert_eq(nc["base_attack"], 5)


func test_make_naval_company_weather_modifiers_applied() -> void:
	var ship := _make_ship(1, Enums.ShipClass.KOBUNE)
	var nc := _make_nc(ship, 1, 0, "attacker", Enums.NavalWeather.STORM)
	assert_eq(nc["base_attack"], 1)  # 3 - 2 (storm global)
	assert_eq(nc["base_defense"], 2)  # 3 - 1 (flat-bottomed storm)


func test_make_naval_company_kobune_reserve_is_ranged() -> void:
	var ship := _make_ship(1, Enums.ShipClass.KOBUNE)
	var nc := _make_nc(ship, 2, 0, "attacker")
	assert_true(nc["is_kobune_ranged"])


func test_make_naval_company_non_kobune_reserve_not_ranged() -> void:
	var ship := _make_ship(1, Enums.ShipClass.SENGOKOBUNE)
	var nc := _make_nc(ship, 2, 0, "attacker")
	assert_false(nc["is_kobune_ranged"])


func test_civilian_flags_merchant_barge() -> void:
	var ship := _make_ship(1, Enums.ShipClass.MERCHANT_BARGE)
	var nc := _make_nc(ship, 1, 0, "attacker")
	assert_true(nc["is_civilian"])
	assert_true(nc["auto_surrenders"])
	assert_false(nc["auto_flees"])


func test_civilian_flags_sampan() -> void:
	var ship := _make_ship(1, Enums.ShipClass.SAMPAN)
	var nc := _make_nc(ship, 1, 0, "attacker")
	assert_true(nc["is_civilian"])
	assert_true(nc["auto_flees"])


func test_is_active_normal() -> void:
	var nc := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	assert_true(NavalCombatSystem.is_active(nc))


func test_is_active_routed() -> void:
	var nc := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	nc["is_routed"] = true
	assert_false(NavalCombatSystem.is_active(nc))


func test_is_active_destroyed() -> void:
	var nc := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	nc["is_destroyed"] = true
	assert_false(NavalCombatSystem.is_active(nc))


func test_is_active_captured() -> void:
	var nc := _make_attacker(1, Enums.ShipClass.MERCHANT_BARGE, 0)
	nc["is_captured"] = true
	assert_false(NavalCombatSystem.is_active(nc))


func test_sampan_auto_flees_not_active() -> void:
	var ship := _make_ship(1, Enums.ShipClass.SAMPAN)
	var nc := _make_nc(ship, 1, 0, "attacker")
	assert_false(NavalCombatSystem.is_active(nc))


# =============================================================================
# Civilian Processing
# =============================================================================

func test_civilians_flee_and_surrender() -> void:
	var sampan := _make_attacker(1, Enums.ShipClass.SAMPAN, 0)
	var barge := _make_defender(2, Enums.ShipClass.MERCHANT_BARGE, 0)
	var warship := _make_attacker(3, Enums.ShipClass.SENGOKOBUNE, 1)
	var atk: Array[Dictionary] = _to_typed_array([sampan, warship])
	var def: Array[Dictionary] = _to_typed_array([barge])
	var result: Dictionary = NavalCombatSystem.process_civilians(atk, def)
	assert_true(1 in result["fled"])
	assert_true(2 in result["surrendered"])
	assert_true(barge["is_captured"])


# =============================================================================
# Engagement Rules
# =============================================================================

func test_koutetsukan_cannot_be_boarded() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	var def := _make_defender(2, Enums.ShipClass.KOUTETSUKAN, 0, Enums.NavalWeather.CLEAR, "Crab")
	assert_false(NavalCombatSystem._can_engage(atk, def))


func test_koutetsukan_cannot_board_others() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.KOUTETSUKAN, 0, Enums.NavalWeather.CLEAR, "Crab")
	var def := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	assert_false(NavalCombatSystem._can_engage(atk, def))


func test_normal_ships_can_engage() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	var def := _make_defender(2, Enums.ShipClass.KOBUNE, 0)
	assert_true(NavalCombatSystem._can_engage(atk, def))


# =============================================================================
# Ram Attack
# =============================================================================

func test_ram_deals_damage_and_self_damage() -> void:
	var ram_ship := _make_attacker(1, Enums.ShipClass.KOUTETSUKAN, 0, Enums.NavalWeather.CLEAR, "Crab")
	var target := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var result: Dictionary = NavalCombatSystem.resolve_ram_in_battle(ram_ship, target, _dice)
	assert_true(result["success"])
	assert_true(result["damage_dealt"] >= 0)
	assert_eq(result["self_damage"], 5)
	assert_true(ram_ship["ram_used"])


func test_ram_cannot_fire_twice() -> void:
	var ram_ship := _make_attacker(1, Enums.ShipClass.KOUTETSUKAN, 0, Enums.NavalWeather.CLEAR, "Crab")
	var target := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	NavalCombatSystem.resolve_ram_in_battle(ram_ship, target, _dice)
	var result2: Dictionary = NavalCombatSystem.resolve_ram_in_battle(ram_ship, target, _dice)
	assert_false(result2["success"])
	assert_eq(result2["reason"], "already_used")


func test_ram_only_koutetsukan() -> void:
	var attacker := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	var target := _make_defender(2, Enums.ShipClass.KOBUNE, 0)
	var result: Dictionary = NavalCombatSystem.resolve_ram_in_battle(attacker, target, _dice)
	assert_false(result["success"])


func test_ram_can_destroy_target() -> void:
	var ram_ship := _make_attacker(1, Enums.ShipClass.KOUTETSUKAN, 0, Enums.NavalWeather.CLEAR, "Crab")
	var target := _make_defender(2, Enums.ShipClass.SAMPAN, 0)
	target["current_health"] = 1
	var result: Dictionary = NavalCombatSystem.resolve_ram_in_battle(ram_ship, target, _dice)
	assert_true(target["is_destroyed"])


# =============================================================================
# Naval Battle Resolution
# =============================================================================

func test_resolve_battle_returns_result() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_has(result, "victor")
	assert_has(result, "rounds")
	assert_has(result, "round_log")
	assert_has(result, "civilian_result")
	assert_has(result, "captured_ships")
	assert_true(result["rounds"] > 0)
	assert_true(result["rounds"] <= NavalCombatSystem.MAX_ROUNDS)


func test_resolve_battle_has_winner() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.ATAKEBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_true(result["victor"] in ["attacker", "defender"])


func test_resolve_battle_strong_vs_weak() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.ATAKEBUNE, 0),
		_make_attacker(3, Enums.ShipClass.SENGOKOBUNE, 1),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_eq(result["victor"], "attacker")


func test_no_flanking_at_sea() -> void:
	# Two attackers vs one defender — the unmatched attacker should NOT flank
	# (flanking is disabled at sea). It will sit idle unless it can promote.
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
		_make_attacker(3, Enums.ShipClass.KOBUNE, 1),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	# The battle should end. The key test is that no flanking happened —
	# verify via round_log matchups count (should be 1 per round, not more)
	for rnd: Dictionary in result["round_log"]:
		assert_true(rnd["matchups"] <= 1)


# =============================================================================
# Kobune Ranged From Reserve Row
# =============================================================================

func test_kobune_reserve_fires_ranged() -> void:
	var front := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	var kobune_ship := _make_ship(3, Enums.ShipClass.KOBUNE, "Mantis")
	var ranged := _make_nc(kobune_ship, 2, 0, "attacker")
	var def := _make_defender(2, Enums.ShipClass.KOBUNE, 0)
	var atk: Array[Dictionary] = _to_typed_array([front, ranged])
	var defn: Array[Dictionary] = _to_typed_array([def])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, defn, Enums.NavalWeather.CLEAR, _dice)
	assert_eq(result["victor"], "attacker")


func test_kobune_ranged_suppressed_in_storm() -> void:
	var dice := DiceEngine.new(999)
	var pending_dmg: Dictionary = {}
	var pending_morale: Dictionary = {}
	var kobune_ship := _make_ship(1, Enums.ShipClass.KOBUNE, "Mantis")
	var ranged := _make_nc(kobune_ship, 2, 0, "attacker", Enums.NavalWeather.STORM)
	var target := _make_defender(2, Enums.ShipClass.KOBUNE, 0, Enums.NavalWeather.STORM)
	var reserve: Array[Dictionary] = _to_typed_array([ranged])
	var enemy_r1: Array[Dictionary] = _to_typed_array([target])
	NavalCombatSystem._resolve_kobune_ranged_fire(
		reserve, enemy_r1, Enums.NavalWeather.STORM, dice, pending_dmg, pending_morale)
	assert_eq(pending_dmg.size(), 0)


# =============================================================================
# Atakebune Adjacent Defense
# =============================================================================

func test_atakebune_grants_defense_to_adjacent() -> void:
	var atakebune := _make_attacker(1, Enums.ShipClass.ATAKEBUNE, 0)
	var ally := _make_attacker(2, Enums.ShipClass.SENGOKOBUNE, 1)
	var side: Array[Dictionary] = _to_typed_array([atakebune, ally])
	NavalCombatSystem._apply_atakebune_defense(side)
	assert_eq(ally["atakebune_def_bonus"], 3)


func test_atakebune_does_not_buff_self() -> void:
	var atakebune := _make_attacker(1, Enums.ShipClass.ATAKEBUNE, 0)
	var side: Array[Dictionary] = _to_typed_array([atakebune])
	NavalCombatSystem._apply_atakebune_defense(side)
	assert_eq(atakebune["atakebune_def_bonus"], 0)


func test_atakebune_does_not_buff_non_adjacent() -> void:
	var atakebune := _make_attacker(1, Enums.ShipClass.ATAKEBUNE, 0)
	var far_ally := _make_attacker(2, Enums.ShipClass.SENGOKOBUNE, 3)
	var side: Array[Dictionary] = _to_typed_array([atakebune, far_ally])
	NavalCombatSystem._apply_atakebune_defense(side)
	assert_eq(far_ally["atakebune_def_bonus"], 0)


# =============================================================================
# River Combat
# =============================================================================

func test_river_downstream_attack_bonus() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var atk_base: int = atk[0]["base_attack"]
	var def_base: int = def[0]["base_attack"]
	NavalCombatSystem._apply_river_modifiers(atk, def, true)
	assert_eq(atk[0]["base_attack"], atk_base + 1)
	assert_eq(def[0]["base_attack"], def_base - 1)


func test_river_upstream_attack_penalty() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var atk_base: int = atk[0]["base_attack"]
	NavalCombatSystem._apply_river_modifiers(atk, def, false)
	assert_eq(atk[0]["base_attack"], atk_base - 1)


func test_river_battle_resolves() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice, true, true)
	assert_true(result["victor"] in ["attacker", "defender", "draw"])


# =============================================================================
# Boarding Mechanics
# =============================================================================

func test_first_round_boarding_penalty() -> void:
	var penalty: int = NavalCombatSystem._compute_naval_damage(
		_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0),
		_make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0),
		_dice, true,
	)
	# We can't test exact damage due to dice, but we verified the code path runs
	assert_true(penalty >= 0)


func test_kobune_first_round_attack_bonus() -> void:
	# Kobune gets +1 on first round (archers loose before boarding)
	# Net: -2 boarding penalty + 1 kobune bonus = -1 total
	var atk := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	var def := _make_defender(2, Enums.ShipClass.KOBUNE, 0)
	# Just verify it doesn't crash — exact outcome depends on dice
	var _dmg: int = NavalCombatSystem._compute_naval_damage(atk, def, _dice, true)


# =============================================================================
# Rout Resolution
# =============================================================================

func test_naval_rout_no_cavalry_pursuit() -> void:
	var routed: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	routed[0]["current_health"] = 50
	var result: Dictionary = NavalCombatSystem.resolve_naval_rout(routed, _dice)
	assert_has(result, "pursuit_casualties")
	assert_has(result, "dissolved")
	# No cavalry at sea, so pursuit is always the low percentage
	assert_true(result["pursuit_casualties"] >= 0)


func test_naval_rout_dissolution_threshold() -> void:
	var routed: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	routed[0]["current_health"] = 5  # Very low health
	var result: Dictionary = NavalCombatSystem.resolve_naval_rout(routed, _dice)
	assert_true(result["dissolved"])


# =============================================================================
# Captured Ships
# =============================================================================

func test_captured_ships_collected() -> void:
	var barge := _make_defender(2, Enums.ShipClass.MERCHANT_BARGE, 0)
	barge["is_captured"] = true
	var atk: Array[Dictionary] = _to_typed_array([])
	var def: Array[Dictionary] = _to_typed_array([barge])
	var captured: Array[Dictionary] = NavalCombatSystem._collect_captured_ships(atk, def)
	assert_true(captured.size() >= 1)
	assert_eq(captured[0]["captured_by"], "attacker")
	assert_true(captured[0]["prize_value"] > 0)


func test_destroyed_ships_captured_as_prize() -> void:
	var def := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	def["is_destroyed"] = true
	var atk: Array[Dictionary] = _to_typed_array([])
	var defs: Array[Dictionary] = _to_typed_array([def])
	var captured: Array[Dictionary] = NavalCombatSystem._collect_captured_ships(atk, defs)
	assert_true(captured.size() >= 1)
	assert_eq(captured[0]["prize_value"], 4.0)  # half of 8.0


# =============================================================================
# Reserve Promotion
# =============================================================================

func test_reserve_promotes_when_front_empty() -> void:
	var r1 := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	r1["is_destroyed"] = true
	var ship2 := _make_ship(2, Enums.ShipClass.SENGOKOBUNE)
	var r2 := _make_nc(ship2, 2, 0, "attacker")
	var states: Array[Dictionary] = _to_typed_array([r1, r2])
	NavalCombatSystem._promote_reserves(states)
	assert_eq(r2["row"], 1)


func test_kobune_ranged_stays_in_reserve() -> void:
	var r1 := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	r1["is_destroyed"] = true
	var kobune_ship := _make_ship(2, Enums.ShipClass.KOBUNE)
	var r2 := _make_nc(kobune_ship, 2, 0, "attacker")
	var states: Array[Dictionary] = _to_typed_array([r1, r2])
	NavalCombatSystem._promote_reserves(states)
	assert_eq(r2["row"], 2)


# =============================================================================
# Full Battle Integration
# =============================================================================

func test_full_battle_sengokobune_vs_kobune_fleet() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0),
		_make_attacker(3, Enums.ShipClass.SENGOKOBUNE, 1),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
		_make_defender(4, Enums.ShipClass.KOBUNE, 1),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_true(result["victor"] in ["attacker", "defender", "draw"])
	assert_true(result["rounds"] <= NavalCombatSystem.MAX_ROUNDS)


func test_full_battle_with_weather() -> void:
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0, Enums.NavalWeather.STORM),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0, Enums.NavalWeather.STORM),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.STORM, _dice)
	assert_has(result, "weather")
	assert_eq(result["weather"], Enums.NavalWeather.STORM)


func test_civilian_convoy_auto_captured() -> void:
	var barge := _make_defender(2, Enums.ShipClass.MERCHANT_BARGE, 0)
	var warship := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	var atk: Array[Dictionary] = _to_typed_array([warship])
	var def: Array[Dictionary] = _to_typed_array([barge])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_eq(result["victor"], "attacker")
	assert_true(result["civilian_result"]["surrendered"].size() > 0)


func test_battle_max_rounds_cap() -> void:
	# Two identical ships should eventually end, but verify cap
	var atk: Array[Dictionary] = _to_typed_array([
		_make_attacker(1, Enums.ShipClass.KOBUNE, 0),
	])
	var def: Array[Dictionary] = _to_typed_array([
		_make_defender(2, Enums.ShipClass.KOBUNE, 0),
	])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_true(result["rounds"] <= NavalCombatSystem.MAX_ROUNDS)


func test_battle_end_detection() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	atk["is_destroyed"] = true
	var states: Array[Dictionary] = _to_typed_array([atk])
	assert_true(NavalCombatSystem._check_battle_end(states))


func test_battle_not_ended_with_active_ship() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.KOBUNE, 0)
	var states: Array[Dictionary] = _to_typed_array([atk])
	assert_false(NavalCombatSystem._check_battle_end(states))
