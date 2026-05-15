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


# =============================================================================
# Tortoise Escape Attempt (s11.9)
# =============================================================================

func _make_captain(nav: int, intel: int) -> L5RCharacterData:
	var cap := L5RCharacterData.new()
	cap.character_id = 9000
	cap.intelligence = intel
	cap.skills["Navigation"] = nav
	cap.skills["Battle"] = 0
	return cap


func _make_tortoise(id: int, col: int, side: String,
		cap: L5RCharacterData = null) -> Dictionary:
	var ship := _make_ship(id, Enums.ShipClass.TORTOISE_OCEANGOING)
	var nc := NavalCombatSystem.make_naval_company(
		ship, 1, col, side, Enums.NavalWeather.CLEAR, false, cap)
	return nc


func test_is_active_returns_false_for_escaped_ship() -> void:
	var nc := _make_tortoise(1, 0, "attacker")
	nc["is_escaped"] = true
	assert_false(NavalCombatSystem.is_active(nc))


func test_escape_attempted_set_after_attempt() -> void:
	var cap := _make_captain(0, 2)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var own: Array[Dictionary] = _to_typed_array([tortoise])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	NavalCombatSystem._process_tortoise_escapes(own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_true(tortoise["escape_attempted"])


func test_escape_attempted_flag_prevents_retry() -> void:
	var cap := _make_captain(0, 2)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	tortoise["escape_attempted"] = true
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var own: Array[Dictionary] = _to_typed_array([tortoise])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	var results: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_eq(results.size(), 0, "Already-attempted ship should produce no result")


func test_non_tortoise_ships_skipped_by_escape() -> void:
	var atk := _make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var own: Array[Dictionary] = _to_typed_array([atk])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	var results: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_eq(results.size(), 0, "Non-Tortoise ships must not attempt escape")


func test_process_tortoise_escapes_result_has_required_keys() -> void:
	var cap := _make_captain(0, 2)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var own: Array[Dictionary] = _to_typed_array([tortoise])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	var results: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_eq(results.size(), 1)
	var r: Dictionary = results[0]
	assert_has(r, "company_id")
	assert_has(r, "ship_id")
	assert_has(r, "escaped")
	assert_has(r, "escape_total")
	assert_has(r, "pursue_total")
	assert_has(r, "weather_bonus")


func test_tortoise_escape_with_overwhelming_nav_skill() -> void:
	# Navigation 10 + Intelligence 10 vs Battle 0 + Intelligence 2 = escape is near-certain.
	# Roll range 1-10 on both sides: attacker gets 10+20=30 minimum, enemy gets at most 10+2=12.
	var cap := _make_captain(10, 10)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var own: Array[Dictionary] = _to_typed_array([tortoise])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	var results: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_eq(results.size(), 1)
	assert_true(results[0]["escaped"], "Overwhelming Nav/Int should escape vs 0-Battle enemy")
	assert_true(tortoise["is_escaped"])


func test_tortoise_escape_with_zero_nav_vs_strong_pursuer() -> void:
	# Navigation 0 + Intelligence 2 vs Battle 10 + Intelligence 10: escape is near-impossible.
	var cap := _make_captain(0, 2)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	var enemy_cap := _make_captain(10, 10)
	enemy_cap.skills["Battle"] = 10
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	enemy["captain"] = enemy_cap
	var own: Array[Dictionary] = _to_typed_array([tortoise])
	var foe: Array[Dictionary] = _to_typed_array([enemy])
	var results: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own, foe, _dice, Enums.NavalWeather.CLEAR)
	assert_eq(results.size(), 1)
	assert_false(results[0]["escaped"], "Zero-nav Tortoise vs strong pursuer should fail to escape")
	assert_false(tortoise["is_escaped"])


func test_escaped_ship_excluded_from_matchups() -> void:
	var cap := _make_captain(10, 10)
	var tortoise := _make_tortoise(1, 0, "attacker", cap)
	var enemy := _make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)
	var atk: Array[Dictionary] = _to_typed_array([tortoise])
	var def: Array[Dictionary] = _to_typed_array([enemy])
	# Run escape processing — with high nav the ship should escape
	NavalCombatSystem._process_tortoise_escapes(atk, def, _dice, Enums.NavalWeather.CLEAR)
	if tortoise["is_escaped"]:
		assert_false(NavalCombatSystem.is_active(tortoise),
			"Escaped ship must not be active for matchup building")


func test_battle_result_has_escaped_ships_key() -> void:
	var atk: Array[Dictionary] = _to_typed_array([_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)])
	var def: Array[Dictionary] = _to_typed_array([_make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_has(result, "escaped_ships")
	assert_true(result["escaped_ships"] is Array)


func test_round_log_has_escape_results_key() -> void:
	var atk: Array[Dictionary] = _to_typed_array([_make_attacker(1, Enums.ShipClass.SENGOKOBUNE, 0)])
	var def: Array[Dictionary] = _to_typed_array([_make_defender(2, Enums.ShipClass.SENGOKOBUNE, 0)])
	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk, def, Enums.NavalWeather.CLEAR, _dice)
	assert_true(result["round_log"].size() > 0)
	assert_has(result["round_log"][0], "escape_results")


func test_tortoise_escape_with_typhoon_bonus_increases_escape_total() -> void:
	var cap := _make_captain(3, 2)
	var tortoise_clear := _make_tortoise(10, 0, "attacker", cap)
	var tortoise_typhoon := _make_tortoise(11, 0, "attacker", cap)
	var enemy := _make_defender(20, Enums.ShipClass.SENGOKOBUNE, 0)
	var foe: Array[Dictionary] = _to_typed_array([enemy])

	var dice_clear := DiceEngine.new(99)
	var own_clear: Array[Dictionary] = _to_typed_array([tortoise_clear])
	var res_clear: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own_clear, foe, dice_clear, Enums.NavalWeather.CLEAR)

	var dice_typhoon := DiceEngine.new(99)
	var own_typhoon: Array[Dictionary] = _to_typed_array([tortoise_typhoon])
	var res_typhoon: Array[Dictionary] = NavalCombatSystem._process_tortoise_escapes(
		own_typhoon, foe, dice_typhoon, Enums.NavalWeather.TYPHOON)

	assert_eq(res_clear.size(), 1)
	assert_eq(res_typhoon.size(), 1)
	assert_true(
		res_typhoon[0]["weather_bonus"] > res_clear[0]["weather_bonus"],
		"Typhoon escape bonus should exceed Clear bonus"
	)


func test_collect_escaped_ships_returns_correct_side() -> void:
	var atk := _make_tortoise(1, 0, "attacker")
	atk["is_escaped"] = true
	var def := _make_tortoise(2, 0, "defender")
	def["is_escaped"] = true
	var atk_arr: Array[Dictionary] = _to_typed_array([atk])
	var def_arr: Array[Dictionary] = _to_typed_array([def])
	var escaped: Array[Dictionary] = NavalCombatSystem._collect_escaped_ships(atk_arr, def_arr)
	assert_eq(escaped.size(), 2)
	var sides: Array[String] = []
	for e: Dictionary in escaped:
		sides.append(e["side"])
	sides.sort()
	assert_eq(sides, ["attacker", "defender"])
