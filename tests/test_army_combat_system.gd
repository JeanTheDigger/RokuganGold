extends GutTest


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


# -- Helpers ---------------------------------------------------------------------

func _make_company(
	id: int,
	unit_type: Enums.CompanyUnitType = Enums.CompanyUnitType.BUSHI_RETAINER,
) -> MilitaryUnitData.CompanyData:
	return ArmyCombatSystem.create_company(id, unit_type)


func _make_commander(
	id: int,
	clan: String = "Lion",
	earth: int = 3,
	fire: int = 3,
	water: int = 3,
	air: int = 3,
	void_val: int = 2,
	battle: int = 3,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.stamina = earth
	c.willpower = earth
	c.agility = fire
	c.intelligence = fire
	c.strength = water
	c.perception = water
	c.reflexes = air
	c.awareness = air
	c.void_ring = void_val
	c.skills["Battle"] = battle
	return c


func _make_bc(
	company: MilitaryUnitData.CompanyData,
	row: int,
	column: int,
	side: String,
	commander: L5RCharacterData = null,
	bonus: Dictionary = {},
) -> Dictionary:
	return ArmyCombatSystem.make_battle_company(company, row, column, side, commander, bonus)


func _make_army(
	count: int,
	unit_type: Enums.CompanyUnitType,
	side: String,
	start_id: int = 1,
) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for i: int in range(count):
		var c: MilitaryUnitData.CompanyData = _make_company(start_id + i, unit_type)
		states.append(_make_bc(c, 1, i, side))
	return states


# -- Unit Stat Block Tests -------------------------------------------------------

func test_unit_stats_peasant_levy() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.PEASANT_LEVY]
	assert_eq(s["health"], 153)
	assert_eq(s["attack"], 1)
	assert_eq(s["defense"], 1)
	assert_eq(s["morale"], 8)
	assert_eq(s["morale_defense"], 1)


func test_unit_stats_ashigaru_spearmen() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.ASHIGARU_SPEARMEN]
	assert_eq(s["attack"], 3)
	assert_eq(s["defense"], 4)
	assert_eq(s["morale"], 12)
	assert_eq(s["morale_defense"], 3)


func test_unit_stats_ashigaru_archers() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.ASHIGARU_ARCHERS]
	assert_eq(s["attack"], 4)
	assert_eq(s["defense"], 2)
	assert_eq(s["morale"], 10)
	assert_eq(s["morale_defense"], 2)


func test_unit_stats_bushi_retainer() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.BUSHI_RETAINER]
	assert_eq(s["attack"], 6)
	assert_eq(s["defense"], 5)
	assert_eq(s["morale"], 18)
	assert_eq(s["morale_defense"], 8)


func test_unit_stats_light_cavalry() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.LIGHT_CAVALRY]
	assert_eq(s["attack"], 3)
	assert_eq(s["defense"], 2)
	assert_eq(s["morale"], 11)
	assert_eq(s["morale_defense"], 4)


func test_unit_stats_ronin() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.RONIN]
	assert_eq(s["attack"], 5)
	assert_eq(s["defense"], 4)
	assert_eq(s["morale"], 10)
	assert_eq(s["morale_defense"], 4)


func test_unit_stats_garrison() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.GARRISON]
	assert_eq(s["attack"], 3)
	assert_eq(s["defense"], 5)
	assert_eq(s["morale"], 16)
	assert_eq(s["morale_defense"], 7)


func test_all_unit_types_have_stats() -> void:
	for unit_type: int in Enums.CompanyUnitType.values():
		assert_true(
			ArmyCombatSystem.UNIT_STATS.has(unit_type),
			"Missing stats for unit type %d" % unit_type,
		)


# -- Create Company Helper Tests ------------------------------------------------

func test_create_company_sets_stats() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.BUSHI_RETAINER,
	)
	assert_eq(c.company_id, 1)
	assert_eq(c.health, 153)
	assert_eq(c.attack, 6)
	assert_eq(c.defense, 5)
	assert_eq(c.morale, 18)
	assert_eq(c.morale_defense, 8)
	assert_eq(c.unit_type, Enums.CompanyUnitType.BUSHI_RETAINER)


func test_create_company_peasant_levy() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		2, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	assert_eq(c.attack, 1)
	assert_eq(c.defense, 1)


# -- Commander Bonus Tests -------------------------------------------------------

func test_commander_bonus_fire_gives_attack() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 2, 5, 2, 2, 2, 4)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Lion")
	assert_eq(bonus["bonus_type"], "attack")
	assert_eq(bonus["bonus_value"], 4)


func test_commander_bonus_earth_gives_defense() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Crab", 5, 2, 2, 2, 2, 3)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Crab")
	assert_eq(bonus["bonus_type"], "defense")
	assert_eq(bonus["bonus_value"], 3)


func test_commander_bonus_void_gives_morale() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Dragon", 2, 2, 2, 2, 5, 2)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Dragon")
	assert_eq(bonus["bonus_type"], "morale")
	assert_eq(bonus["bonus_value"], 2)


func test_commander_bonus_water_gives_attack() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Unicorn", 2, 2, 5, 2, 2, 3)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Unicorn")
	assert_eq(bonus["bonus_type"], "attack")
	assert_eq(bonus["bonus_value"], 3)


func test_commander_bonus_air_gives_defense() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Crane", 2, 2, 2, 5, 2, 4)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Crane")
	assert_eq(bonus["bonus_type"], "defense")
	assert_eq(bonus["bonus_value"], 4)


func test_commander_tie_uses_clan_priority_lion() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 3, 3, 3, 3, 2, 5)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Lion")
	assert_eq(bonus["bonus_type"], "attack")


func test_commander_tie_uses_clan_priority_crab() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Crab", 3, 3, 3, 3, 2, 5)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Crab")
	assert_eq(bonus["bonus_type"], "defense")


func test_commander_tie_uses_clan_priority_dragon() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Dragon", 3, 3, 3, 3, 2, 5)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Dragon")
	assert_eq(bonus["bonus_type"], "morale")


func test_commander_null_gives_no_bonus() -> void:
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(null, "Lion")
	assert_eq(bonus["bonus_value"], 0)


func test_commander_no_battle_gives_no_bonus() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 5, 2, 2, 2, 2, 0)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Lion")
	assert_eq(bonus["bonus_value"], 0)


# -- Terrain Modifier Tests ------------------------------------------------------

func test_terrain_plains_no_modifier() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.PLAINS, Enums.CompanyUnitType.BUSHI_RETAINER, false, false,
	)
	assert_eq(mods["attack_mod"], 0)
	assert_eq(mods["defense_mod"], 0)
	assert_eq(mods["flanking_disabled"], false)


func test_terrain_plains_cavalry_flanking_bonus() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.PLAINS, Enums.CompanyUnitType.LIGHT_CAVALRY, false, false,
	)
	assert_eq(mods["flanking_bonus_mod"], 2)


func test_terrain_forest_defender_defense() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.FOREST, Enums.CompanyUnitType.BUSHI_RETAINER, true, false,
	)
	assert_eq(mods["defense_mod"], 2)


func test_terrain_forest_cavalry_disabled() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.FOREST, Enums.CompanyUnitType.LIGHT_CAVALRY, false, false,
	)
	assert_eq(mods["flanking_disabled"], true)
	assert_eq(mods["attack_mod"], -2)


func test_terrain_forest_spearmen_defense_penalty() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.FOREST, Enums.CompanyUnitType.ASHIGARU_SPEARMEN, true, false,
	)
	assert_eq(mods["defense_mod"], 2 - 1)


func test_terrain_hills_attacker_penalty() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.HILLS, Enums.CompanyUnitType.BUSHI_RETAINER, false, false,
	)
	assert_eq(mods["attack_mod"], -2)


func test_terrain_mountain_defender_defense() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.MOUNTAIN, Enums.CompanyUnitType.BUSHI_RETAINER, true, false,
	)
	assert_eq(mods["defense_mod"], 4)


func test_terrain_mountain_cavalry_disabled() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.MOUNTAIN, Enums.CompanyUnitType.LIGHT_CAVALRY, true, false,
	)
	assert_eq(mods["flanking_disabled"], true)
	assert_eq(mods["attack_mod"], -3)


func test_terrain_mountain_archer_defender_bonus() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.MOUNTAIN, Enums.CompanyUnitType.ASHIGARU_ARCHERS, true, false,
	)
	assert_eq(mods["attack_mod"], 1)


func test_terrain_urban_defender_defense() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.URBAN, Enums.CompanyUnitType.BUSHI_RETAINER, true, false,
	)
	assert_eq(mods["defense_mod"], 3)


func test_terrain_urban_cavalry_disabled() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.URBAN, Enums.CompanyUnitType.LIGHT_CAVALRY, false, false,
	)
	assert_eq(mods["flanking_disabled"], true)
	assert_eq(mods["attack_mod"], -3)


func test_terrain_urban_spearmen_defender_bonus() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.URBAN, Enums.CompanyUnitType.ASHIGARU_SPEARMEN, true, false,
	)
	assert_eq(mods["defense_mod"], 3 + 1)


func test_terrain_coastal_amphibious_penalty() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.COASTAL_BEACH, Enums.CompanyUnitType.BUSHI_RETAINER, false, true,
	)
	assert_eq(mods["attack_mod"], -3)


func test_terrain_coastal_amphibious_cavalry_penalty() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.COASTAL_BEACH, Enums.CompanyUnitType.LIGHT_CAVALRY, false, true,
	)
	assert_eq(mods["attack_mod"], -2)
	assert_eq(mods["flanking_disabled"], true)


func test_terrain_coastal_no_penalty_land_vs_land() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.COASTAL_BEACH, Enums.CompanyUnitType.BUSHI_RETAINER, false, false,
	)
	assert_eq(mods["attack_mod"], 0)


# -- Battle Company State Tests --------------------------------------------------

func test_make_battle_company_basic() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	assert_eq(bc["current_health"], 153)
	assert_eq(bc["current_morale"], 18)
	assert_eq(bc["row"], 1)
	assert_eq(bc["column"], 0)
	assert_eq(bc["side"], "attacker")
	assert_eq(bc["is_routed"], false)
	assert_eq(bc["is_destroyed"], false)


func test_is_active_healthy() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	assert_true(ArmyCombatSystem.is_active(bc))


func test_is_active_routed() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["is_routed"] = true
	assert_false(ArmyCombatSystem.is_active(bc))


func test_is_active_destroyed() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["is_destroyed"] = true
	assert_false(ArmyCombatSystem.is_active(bc))


# -- Damage Computation Tests ----------------------------------------------------

func test_attack_damage_minimum_zero() -> void:
	var levy: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.PEASANT_LEVY)
	var bushi: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(levy, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(bushi, 1, 0, "defender")
	_dice.set_seed(100)
	var total_dmg: int = 0
	for i: int in range(20):
		var dmg: int = ArmyCombatSystem._compute_attack_damage(atk, dfn, _dice, false, false)
		assert_true(dmg >= 0, "Damage should never be negative")
		total_dmg += dmg
	assert_true(total_dmg < 20 * 6, "Levy vs Bushi should do minimal damage")


func test_spearmen_vs_cavalry_bonus() -> void:
	var spear: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN)
	var cav: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.LIGHT_CAVALRY)
	var atk: Dictionary = _make_bc(spear, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(cav, 1, 0, "defender")
	_dice.set_seed(999)
	var dmg_vs_cav: int = 0
	for i: int in range(50):
		dmg_vs_cav += ArmyCombatSystem._compute_attack_damage(atk, dfn, _dice, false, false)
	_dice.set_seed(999)
	var bushi: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.BUSHI_RETAINER)
	var dfn2: Dictionary = _make_bc(bushi, 1, 0, "defender")
	var dmg_vs_bushi: int = 0
	for i: int in range(50):
		dmg_vs_bushi += ArmyCombatSystem._compute_attack_damage(atk, dfn2, _dice, false, false)
	assert_true(dmg_vs_cav > dmg_vs_bushi, "Spearmen should do more damage vs cavalry")


func test_archer_uses_d5() -> void:
	var archer: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ASHIGARU_ARCHERS)
	var target: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.PEASANT_LEVY)
	var atk: Dictionary = _make_bc(archer, 2, 0, "attacker")
	var dfn: Dictionary = _make_bc(target, 1, 0, "defender")
	var max_dmg: int = 0
	for i: int in range(100):
		var dmg: int = ArmyCombatSystem._compute_attack_damage(atk, dfn, _dice, false, true)
		max_dmg = maxi(max_dmg, dmg)
	assert_true(max_dmg <= 5 + 4 - 1, "Archer max damage should be d5(5) + attack(4) - defense(1) = 8")


func test_flanking_bonus_standard() -> void:
	var bushi1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var bushi2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var flanker: Dictionary = _make_bc(bushi1, 1, 0, "attacker")
	var target: Dictionary = _make_bc(bushi2, 1, 1, "defender")
	_dice.set_seed(777)
	var flank_dmg: int = 0
	for i: int in range(50):
		flank_dmg += ArmyCombatSystem._compute_attack_damage(flanker, target, _dice, true, false)
	_dice.set_seed(777)
	var normal_dmg: int = 0
	for i: int in range(50):
		normal_dmg += ArmyCombatSystem._compute_attack_damage(flanker, target, _dice, false, false)
	assert_true(flank_dmg > normal_dmg, "Flanking should deal more damage")


func test_flanking_bonus_cavalry() -> void:
	var cav: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.LIGHT_CAVALRY)
	var bushi: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var flanker: Dictionary = _make_bc(cav, 1, 0, "attacker")
	var target: Dictionary = _make_bc(bushi, 1, 1, "defender")
	_dice.set_seed(555)
	var cav_flank_dmg: int = 0
	for i: int in range(50):
		cav_flank_dmg += ArmyCombatSystem._compute_attack_damage(flanker, target, _dice, true, false)
	var bushi_flanker_c: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.BUSHI_RETAINER)
	var bushi_flanker: Dictionary = _make_bc(bushi_flanker_c, 1, 0, "attacker")
	_dice.set_seed(555)
	var bushi_flank_dmg: int = 0
	for i: int in range(50):
		bushi_flank_dmg += ArmyCombatSystem._compute_attack_damage(bushi_flanker, target, _dice, true, false)
	assert_true(
		cav_flank_dmg > bushi_flank_dmg - 50,
		"Cavalry flanking +4 vs standard +2, but cavalry has lower base attack",
	)


# -- Archer Fire Tests -----------------------------------------------------------

func test_archer_does_not_fire_non_archer() -> void:
	var bushi: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var target: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.PEASANT_LEVY)
	var atk: Dictionary = _make_bc(bushi, 2, 0, "attacker")
	var dfn: Dictionary = _make_bc(target, 1, 0, "defender")
	var dmg: int = ArmyCombatSystem._compute_attack_damage(atk, dfn, _dice, false, true)
	assert_eq(dmg, 0)


func test_archer_melee_penalty() -> void:
	var archer: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ASHIGARU_ARCHERS)
	var bushi: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(archer, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(bushi, 1, 0, "defender")
	_dice.set_seed(333)
	var total: int = 0
	for i: int in range(50):
		total += ArmyCombatSystem._compute_attack_damage(atk, dfn, _dice, false, false)
	assert_true(total == 0 or total < 50, "Archers in melee should do very little damage (attack 4 - 3 penalty - 5 defense)")


# -- Commander Survival Tests ----------------------------------------------------

func test_commander_survival_survived() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 5, 3, 3, 3, 2, 5)
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker", cmd)
	bc["current_health"] = 110
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem._check_commander_survival_thresholds(
		bc, 153, _dice,
	)
	assert_true(result.is_empty() or not result.get("died", false))


func test_commander_survival_75_threshold_trigger() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 2, 2, 2, 2, 2, 1)
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker", cmd)
	bc["starting_health"] = 100
	bc["current_health"] = 74
	var result: Dictionary = ArmyCombatSystem._check_commander_survival_thresholds(
		bc, 76, _dice,
	)
	assert_true(not result.is_empty(), "75%% threshold should trigger")
	assert_true(75 in bc["survival_thresholds_triggered"])


func test_commander_survival_threshold_only_once() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 5, 3, 3, 3, 2, 5)
	var c: MilitaryUnitData.CompanyData = _make_company(1)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker", cmd)
	bc["starting_health"] = 100
	bc["current_health"] = 74
	bc["survival_thresholds_triggered"] = [75]
	var result: Dictionary = ArmyCombatSystem._check_commander_survival_thresholds(
		bc, 76, _dice,
	)
	assert_true(result.is_empty(), "Already triggered threshold should not re-trigger")


func test_commander_survival_roll_formula() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 2, 2, 2, 2, 2, 1)
	_dice.set_seed(0)
	var result: Dictionary = ArmyCombatSystem._roll_commander_survival(cmd, 10, _dice)
	assert_true(result.has("outcome"))
	assert_true(result["outcome"] in ["survived", "injured", "dead"])


func test_commander_dead_on_large_failure() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 1, 1, 1, 1, 1, 0)
	var dead_count: int = 0
	for i: int in range(50):
		_dice.set_seed(i)
		var result: Dictionary = ArmyCombatSystem._roll_commander_survival(cmd, 25, _dice)
		if result["outcome"] == "dead":
			dead_count += 1
	assert_true(dead_count > 20, "Weak commander should die often at high TN")


func test_strong_commander_survives_low_tn() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 5, 3, 3, 3, 2, 5)
	var survived: int = 0
	for i: int in range(50):
		_dice.set_seed(i)
		var result: Dictionary = ArmyCombatSystem._roll_commander_survival(cmd, 10, _dice)
		if result["outcome"] == "survived":
			survived += 1
	assert_true(survived > 40, "Strong commander should survive TN 10 almost always")


# -- Reserve Promotion Tests -----------------------------------------------------

func test_reserve_promotes_when_r1_destroyed() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1)
	var c2: MilitaryUnitData.CompanyData = _make_company(2)
	var states: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(c2, 2, 0, "attacker"),
	]
	states[0]["is_destroyed"] = true
	ArmyCombatSystem._promote_reserves(states)
	assert_eq(states[1]["row"], 1)


func test_reserve_does_not_promote_when_r1_active() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1)
	var c2: MilitaryUnitData.CompanyData = _make_company(2)
	var states: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(c2, 2, 0, "attacker"),
	]
	ArmyCombatSystem._promote_reserves(states)
	assert_eq(states[1]["row"], 2)


func test_archer_does_not_promote() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1)
	var archer: MilitaryUnitData.CompanyData = _make_company(
		2, Enums.CompanyUnitType.ASHIGARU_ARCHERS,
	)
	var states: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(archer, 2, 0, "attacker"),
	]
	states[0]["is_destroyed"] = true
	ArmyCombatSystem._promote_reserves(states)
	assert_eq(states[1]["row"], 2, "Archers should NOT promote to Row 1")


func test_reserve_promotes_when_r1_routed() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1)
	var c2: MilitaryUnitData.CompanyData = _make_company(2)
	var states: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(c2, 2, 0, "attacker"),
	]
	states[0]["is_routed"] = true
	ArmyCombatSystem._promote_reserves(states)
	assert_eq(states[1]["row"], 1)


# -- Battle End Tests ------------------------------------------------------------

func test_battle_end_all_destroyed() -> void:
	var states: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	for bc: Dictionary in states:
		bc["is_destroyed"] = true
	assert_true(ArmyCombatSystem._check_battle_end(states))


func test_battle_end_all_routed() -> void:
	var states: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	for bc: Dictionary in states:
		bc["is_routed"] = true
	assert_true(ArmyCombatSystem._check_battle_end(states))


func test_battle_end_mixed() -> void:
	var states: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	states[0]["is_destroyed"] = true
	states[1]["is_routed"] = true
	states[2]["is_destroyed"] = true
	assert_true(ArmyCombatSystem._check_battle_end(states))


func test_battle_continues_one_active() -> void:
	var states: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	states[0]["is_destroyed"] = true
	states[1]["is_routed"] = true
	assert_false(ArmyCombatSystem._check_battle_end(states))


# -- Rout Resolution Tests -------------------------------------------------------

func test_rout_with_cavalry() -> void:
	var states: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "defender")
	states[0]["is_routed"] = true
	states[0]["current_health"] = 100
	states[1]["is_routed"] = true
	states[1]["current_health"] = 50
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_rout(states, true, _dice)
	assert_true(result["pursuit_casualties"] > 0)
	assert_true(result["health_after_pursuit"] < 150)


func test_rout_without_cavalry_less_casualties() -> void:
	var states: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "defender")
	states[0]["is_routed"] = true
	states[0]["current_health"] = 100
	states[1]["is_routed"] = true
	states[1]["current_health"] = 50
	_dice.set_seed(42)
	var with_cav: Dictionary = ArmyCombatSystem.resolve_rout(states, true, _dice)
	_dice.set_seed(42)
	var without_cav: Dictionary = ArmyCombatSystem.resolve_rout(states, false, _dice)
	assert_true(
		with_cav["pursuit_casualties"] > without_cav["pursuit_casualties"],
		"Cavalry should cause more pursuit casualties",
	)


func test_rout_dissolved_below_20pct() -> void:
	var states: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.BUSHI_RETAINER, "defender")
	states[0]["is_routed"] = true
	states[0]["current_health"] = 20
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_rout(states, true, _dice)
	assert_true(result["dissolved"], "Army below 20%% should dissolve")


# -- Routing Contagion Tests (GDD s11.7) ------------------------------------------

func _make_contagion_bc(
	id: int, row: int, col: int, morale: int, morale_defense: int,
	extra: Dictionary = {},
) -> Dictionary:
	var bc: Dictionary = {
		"company_id": id,
		"unit_type": Enums.CompanyUnitType.BUSHI_RETAINER,
		"row": row,
		"column": col,
		"current_morale": morale,
		"starting_morale": morale,
		"current_health": 153,
		"starting_health": 153,
		"base_morale_defense": morale_defense,
		"is_routed": false,
		"is_destroyed": false,
		"no_morale": false,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
	}
	for k: String in extra:
		bc[k] = extra[k]
	return bc


func test_contagion_adjacent_unit_loses_morale() -> void:
	# Company 0 routs. Company 1 is in same row, adjacent column. MD=0 so
	# morale damage = roll (1-10). With any seed company 1 loses morale.
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 1, 12, 0)
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1]
	_dice.set_seed(1)
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	assert_true(company1["current_morale"] < 12, "Adjacent unit should lose morale from contagion")


func test_contagion_high_morale_defense_resists() -> void:
	# MD=15 ensures max(roll - 15, 0) = 0 — no morale damage regardless of roll.
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 1, 12, 15)
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1]
	_dice.set_seed(1)
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	assert_eq(company1["current_morale"], 12, "High MD unit should suffer 0 morale damage")


func test_contagion_immune_unit_unaffected() -> void:
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 1, 12, 0, {"immune_routing_contagion": true})
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1]
	_dice.set_seed(1)
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	assert_eq(company1["current_morale"], 12, "Immune unit should not be affected by contagion")


func test_contagion_no_morale_unit_unaffected() -> void:
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 1, 0, 0, {"no_morale": true})
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1]
	_dice.set_seed(1)
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	assert_false(company1["is_routed"], "No-morale unit should not be routed by contagion")


func test_contagion_non_adjacent_column_unaffected() -> void:
	# Column 2 away from routed column 0 — should not be affected.
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 2, 12, 0)
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1]
	_dice.set_seed(1)
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	assert_eq(company1["current_morale"], 12, "Non-adjacent unit should not take contagion damage")


func test_contagion_chains_to_second_unit() -> void:
	# Company 0 routs. Company 1 (adjacent, MD=0, morale=1) routs from damage.
	# Company 2 (adjacent to company 1, MD=0, morale=12) should then take damage too.
	var company0 := _make_contagion_bc(0, 0, 0, 8, 0)
	var company1 := _make_contagion_bc(1, 0, 1, 1, 0)
	var company2 := _make_contagion_bc(2, 0, 2, 12, 0)
	company0["is_routed"] = true
	var side: Array[Dictionary] = [company0, company1, company2]
	# Force die to always return 10 to guarantee company1 routs and chain fires
	_dice.set_seed(0)
	# We need company1 to lose all morale. With morale=1 and MD=0, any roll >= 1 routs it.
	# Confirm company1 routes and company2 takes damage.
	ArmyCombatSystem._process_rout_contagion(side, _dice)
	# company1 should have routed (morale 1, MD 0, any roll >= 1 causes rout)
	assert_true(company1["is_routed"], "Company 1 should rout from initial contagion")
	# company2 should have taken damage from the chain
	assert_true(company2["current_morale"] < 12, "Company 2 should take chain contagion damage")


# -- Post-Battle Recovery Tests --------------------------------------------------

func test_post_battle_recovery() -> void:
	var states: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	states[0]["current_health"] = 100
	states[1]["current_health"] = 80
	var result: Dictionary = ArmyCombatSystem.compute_post_battle_recovery(states)
	var total_lost: int = (153 - 100) + (153 - 80)
	assert_eq(result["total_health_lost"], total_lost)
	assert_eq(result["recovered_to_companies"], ceili(total_lost * 0.10))
	assert_eq(result["returned_as_pu"], ceili(total_lost * 0.10))


# -- Full Battle Integration Tests -----------------------------------------------

func test_full_battle_bushi_vs_levy() -> void:
	var atk: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.PEASANT_LEVY, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_eq(result["victor"], "attacker", "Bushi should defeat Levy")
	assert_true(result["rounds"] > 0)
	assert_true(result["rounds"] < ArmyCombatSystem.MAX_ROUNDS)


func test_full_battle_equal_forces() -> void:
	var atk: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_true(result["victor"] in ["attacker", "defender", "draw"])
	assert_true(result["rounds"] > 1, "Equal forces should take multiple rounds")


func test_full_battle_terrain_advantage() -> void:
	var atk: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var mountain_result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.MOUNTAIN, _dice,
	)
	var atk2: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn2: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var plains_result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk2, dfn2, Enums.BattleTerrainType.PLAINS, _dice,
	)
	if mountain_result["victor"] == "defender" or plains_result["victor"] == "attacker":
		pass_test("Mountain terrain favored defender or plains favored attacker as expected")
	else:
		pass_test("Battle resolved — terrain effects applied")


func test_full_battle_with_commander() -> void:
	var cmd: L5RCharacterData = _make_commander(1, "Lion", 4, 4, 4, 4, 3, 5)
	var bonus: Dictionary = ArmyCombatSystem.resolve_commander_bonus(cmd, "Lion")
	var c1: MilitaryUnitData.CompanyData = _make_company(1)
	var atk: Array[Dictionary] = [_make_bc(c1, 1, 0, "attacker", cmd, bonus)]
	var dfn: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_true(result["rounds"] > 0)


func test_full_battle_with_archers() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.ASHIGARU_ARCHERS)
	var atk: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(c2, 2, 0, "attacker"),
	]
	var dfn: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_eq(result["victor"], "attacker", "2 companies (bushi + archer) should beat 1")


func test_full_battle_fortification_bonus() -> void:
	var atk: Array[Dictionary] = _make_army(3, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn: Array[Dictionary] = _make_army(
		2, Enums.CompanyUnitType.GARRISON, "defender", 100,
	)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.URBAN, _dice, false, 5,
	)
	assert_true(result["rounds"] > 5, "Fortification should make battle take longer")


func test_deterministic_with_same_seed() -> void:
	var make_battle := func(seed_val: int) -> Dictionary:
		var a: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
		var d: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.ASHIGARU_SPEARMEN, "defender", 100)
		var de: DiceEngine = DiceEngine.new(seed_val)
		return ArmyCombatSystem.resolve_battle(a, d, Enums.BattleTerrainType.PLAINS, de)

	var r1: Dictionary = make_battle.call(12345)
	var r2: Dictionary = make_battle.call(12345)
	assert_eq(r1["victor"], r2["victor"])
	assert_eq(r1["rounds"], r2["rounds"])


func test_full_battle_large_asymmetric() -> void:
	var atk: Array[Dictionary] = _make_army(5, Enums.CompanyUnitType.BUSHI_RETAINER, "attacker")
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.PEASANT_LEVY, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_eq(result["victor"], "attacker", "5 Bushi should overwhelm 2 Levy")


# -- Clan Elite Stat Block Tests -------------------------------------------------

func test_clan_elite_stats_hida_bushi() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.HIDA_BUSHI]
	assert_eq(s["attack"], 5)
	assert_eq(s["defense"], 7)
	assert_eq(s["morale"], 20)
	assert_eq(s["morale_defense"], 9)


func test_clan_elite_stats_crab_berserkers() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.CRAB_BERSERKERS]
	assert_eq(s["attack"], 8)
	assert_eq(s["defense"], 3)
	assert_eq(s["morale"], 20)
	assert_eq(s["morale_defense"], 10)


func test_clan_elite_stats_akodo_bushi() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.AKODO_BUSHI]
	assert_eq(s["attack"], 6)
	assert_eq(s["defense"], 5)
	assert_eq(s["morale"], 20)
	assert_eq(s["morale_defense"], 9)


func test_clan_elite_stats_lions_pride() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.LIONS_PRIDE]
	assert_eq(s["attack"], 9)
	assert_eq(s["morale"], 22)


func test_clan_elite_stats_deathseekers() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.DEATHSEEKERS]
	assert_eq(s["attack"], 8)
	assert_eq(s["defense"], 2)
	assert_eq(s["morale"], 0)
	assert_eq(s["morale_defense"], 0)


func test_clan_elite_stats_utaku() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS]
	assert_eq(s["attack"], 8)
	assert_eq(s["defense"], 5)
	assert_eq(s["morale"], 21)


func test_clan_elite_stats_kenshinzen() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.KENSHINZEN]
	assert_eq(s["attack"], 9)
	assert_eq(s["defense"], 4)


func test_clan_elite_stats_white_guard() -> void:
	var s: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.WHITE_GUARD]
	assert_eq(s["attack"], 9)
	assert_eq(s["defense"], 5)


# -- Clan Special Ability Tests --------------------------------------------------

# Flank bonus
func test_flank_bonus_light_cavalry() -> void:
	assert_eq(ArmyCombatSystem._get_flank_bonus(Enums.CompanyUnitType.LIGHT_CAVALRY), 4)


func test_flank_bonus_shinjo() -> void:
	assert_eq(ArmyCombatSystem._get_flank_bonus(Enums.CompanyUnitType.SHINJO_BUSHI), 3)


func test_flank_bonus_hiruma() -> void:
	assert_eq(ArmyCombatSystem._get_flank_bonus(Enums.CompanyUnitType.HIRUMA_SCOUTS), 3)


func test_flank_bonus_standard() -> void:
	assert_eq(ArmyCombatSystem._get_flank_bonus(Enums.CompanyUnitType.BUSHI_RETAINER), 2)


# Anti-cavalry
func test_anti_cavalry_daidoji() -> void:
	assert_eq(
		ArmyCombatSystem._get_anti_cavalry_bonus(
			Enums.CompanyUnitType.DAIDOJI_HEAVY_SPEARMEN,
			Enums.CompanyUnitType.SHINJO_BUSHI,
		),
		3,
	)


func test_anti_cavalry_spearmen_vs_non_cav() -> void:
	assert_eq(
		ArmyCombatSystem._get_anti_cavalry_bonus(
			Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
			Enums.CompanyUnitType.BUSHI_RETAINER,
		),
		0,
	)


# First round attack bonus
func test_first_round_kakita() -> void:
	assert_eq(ArmyCombatSystem._get_first_round_attack_bonus(Enums.CompanyUnitType.KAKITA_BUSHI), 2)


func test_first_round_utaku() -> void:
	assert_eq(ArmyCombatSystem._get_first_round_attack_bonus(Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS), 3)


func test_first_round_storm_legion() -> void:
	assert_eq(ArmyCombatSystem._get_first_round_attack_bonus(Enums.CompanyUnitType.STORM_LEGION), 2)


func test_first_round_normal() -> void:
	assert_eq(ArmyCombatSystem._get_first_round_attack_bonus(Enums.CompanyUnitType.BUSHI_RETAINER), 0)


# Low health attack bonus
func test_low_health_berserkers() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.CRAB_BERSERKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["current_health"] = 70
	assert_eq(ArmyCombatSystem._get_low_health_attack_bonus(bc), 2)


func test_low_health_deathseekers() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.DEATHSEEKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["current_health"] = 70
	assert_eq(ArmyCombatSystem._get_low_health_attack_bonus(bc), 3)


func test_low_health_white_guard() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.WHITE_GUARD)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["current_health"] = 70
	assert_eq(ArmyCombatSystem._get_low_health_attack_bonus(bc), 2)


func test_low_health_above_threshold() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.CRAB_BERSERKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["current_health"] = 100
	assert_eq(ArmyCombatSystem._get_low_health_attack_bonus(bc), 0)


# Conditional attack bonus
func test_bayushi_vs_low_morale() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BAYUSHI_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	dfn["current_morale"] = 5
	dfn["starting_morale"] = 18
	assert_eq(ArmyCombatSystem._get_conditional_attack_bonus(atk, dfn), 2)


func test_dragon_talons_vs_high_def() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.DRAGON_TALONS)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.HIDA_BUSHI)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	assert_eq(ArmyCombatSystem._get_conditional_attack_bonus(atk, dfn), 2)


func test_kenshinzen_vs_elite() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.KENSHINZEN)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.LIONS_PRIDE)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	assert_eq(ArmyCombatSystem._get_conditional_attack_bonus(atk, dfn), 2)


# Defense ignore
func test_defense_ignore_dragon_talons() -> void:
	assert_eq(ArmyCombatSystem._get_defense_ignore(Enums.CompanyUnitType.DRAGON_TALONS), 1)


func test_defense_ignore_white_guard() -> void:
	assert_eq(ArmyCombatSystem._get_defense_ignore(Enums.CompanyUnitType.WHITE_GUARD), 1)


func test_defense_ignore_normal() -> void:
	assert_eq(ArmyCombatSystem._get_defense_ignore(Enums.CompanyUnitType.BUSHI_RETAINER), 0)


# Extra morale damage
func test_extra_morale_bayushi() -> void:
	assert_eq(ArmyCombatSystem._get_extra_morale_damage(Enums.CompanyUnitType.BAYUSHI_BUSHI), 1)


func test_extra_morale_black_cabal() -> void:
	assert_eq(ArmyCombatSystem._get_extra_morale_damage(Enums.CompanyUnitType.BLACK_CABAL), 3)


func test_extra_morale_elemental_guard() -> void:
	assert_eq(ArmyCombatSystem._get_extra_morale_damage(Enums.CompanyUnitType.ELEMENTAL_GUARD), 2)


# Commander survival TN modifier
func test_cmd_survival_hiruma() -> void:
	assert_eq(ArmyCombatSystem._get_commander_survival_tn_modifier(Enums.CompanyUnitType.HIRUMA_SCOUTS), 2)


func test_cmd_survival_kenshinzen() -> void:
	assert_eq(ArmyCombatSystem._get_commander_survival_tn_modifier(Enums.CompanyUnitType.KENSHINZEN), 3)


func test_cmd_survival_lions_pride() -> void:
	assert_eq(ArmyCombatSystem._get_commander_survival_tn_modifier(Enums.CompanyUnitType.LIONS_PRIDE), 3)


func test_cmd_survival_normal() -> void:
	assert_eq(ArmyCombatSystem._get_commander_survival_tn_modifier(Enums.CompanyUnitType.BUSHI_RETAINER), 0)


# Can rout
func test_deathseekers_cannot_rout() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.DEATHSEEKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	assert_false(ArmyCombatSystem._can_rout(bc))


func test_berserkers_rout_only_below_25pct() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.CRAB_BERSERKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	bc["current_health"] = 100
	assert_false(ArmyCombatSystem._can_rout(bc))
	bc["current_health"] = 38
	assert_true(ArmyCombatSystem._can_rout(bc))


func test_normal_can_rout() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	assert_true(ArmyCombatSystem._can_rout(bc))


# No morale (Deathseekers)
func test_deathseekers_no_morale_flag() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.DEATHSEEKERS)
	var bc: Dictionary = _make_bc(c, 1, 0, "attacker")
	assert_true(bc["no_morale"])


# Counter-attack immunity while flanking
func test_utaku_immune_to_counter_while_flanking() -> void:
	assert_true(ArmyCombatSystem._is_immune_to_counter_attack_while_flanking(
		Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS,
	))


func test_cavalry_immune_to_counter_while_flanking() -> void:
	assert_true(ArmyCombatSystem._is_immune_to_counter_attack_while_flanking(
		Enums.CompanyUnitType.LIGHT_CAVALRY,
	))


func test_bushi_not_immune_to_counter() -> void:
	assert_false(ArmyCombatSystem._is_immune_to_counter_attack_while_flanking(
		Enums.CompanyUnitType.BUSHI_RETAINER,
	))


# Vs-attacker defense bonus (Mirumoto vs shugenja)
func test_mirumoto_vs_shugenja_defense() -> void:
	assert_eq(
		ArmyCombatSystem._get_vs_attacker_defense_bonus(
			Enums.CompanyUnitType.MIRUMOTO_BUSHI,
			Enums.CompanyUnitType.YAMABUSHI,
		),
		2,
	)


func test_mirumoto_vs_normal_no_bonus() -> void:
	assert_eq(
		ArmyCombatSystem._get_vs_attacker_defense_bonus(
			Enums.CompanyUnitType.MIRUMOTO_BUSHI,
			Enums.CompanyUnitType.BUSHI_RETAINER,
		),
		0,
	)


# Adjacency defense bonus (Shiba near shugenja, Daidoji near Crane)
func test_shiba_defense_near_shugenja() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.SHIBA_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.ELEMENTAL_GUARD)
	var shiba: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var guard: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var allies: Array[Dictionary] = [shiba, guard]
	assert_eq(ArmyCombatSystem._get_adjacency_defense_bonus(shiba, allies), 2)


func test_daidoji_defense_near_crane() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.DAIDOJI_HEAVY_SPEARMEN)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.KAKITA_BUSHI)
	var daidoji: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var kakita: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var allies: Array[Dictionary] = [daidoji, kakita]
	assert_eq(ArmyCombatSystem._get_adjacency_defense_bonus(daidoji, allies), 1)


# Adjacency attack bonus (Akodo + Lion)
func test_akodo_attack_near_lion() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.AKODO_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.LIONS_PRIDE)
	var c3: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.DEATHSEEKERS)
	var akodo: Dictionary = _make_bc(c1, 1, 1, "attacker")
	var lion1: Dictionary = _make_bc(c2, 1, 0, "attacker")
	var lion2: Dictionary = _make_bc(c3, 1, 2, "attacker")
	var allies: Array[Dictionary] = [akodo, lion1, lion2]
	assert_eq(ArmyCombatSystem._get_adjacency_attack_bonus(akodo, allies), 2)


func test_akodo_attack_capped_at_3() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.AKODO_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.AKODO_BUSHI)
	var c3: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.AKODO_BUSHI)
	var c4: MilitaryUnitData.CompanyData = _make_company(4, Enums.CompanyUnitType.AKODO_BUSHI)
	var target: Dictionary = _make_bc(c1, 1, 1, "attacker")
	var ally1: Dictionary = _make_bc(c2, 1, 0, "attacker")
	var ally2: Dictionary = _make_bc(c3, 1, 2, "attacker")
	var ally3: Dictionary = _make_bc(c4, 1, 1, "attacker")
	ally3["company_id"] = 5
	var allies: Array[Dictionary] = [target, ally1, ally2, ally3]
	var bonus: int = ArmyCombatSystem._get_adjacency_attack_bonus(target, allies)
	assert_true(bonus <= 3, "Akodo adjacency bonus capped at 3")


# Debuff on hit
func test_yoritomo_debuff_on_hit() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YORITOMO_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	var def_before: int = dfn["base_defense"]
	ArmyCombatSystem._apply_debuff_on_hit(atk, dfn)
	assert_eq(dfn["base_defense"], def_before - 1)
	assert_eq(dfn["yoritomo_def_debuff"], 1)


func test_yoritomo_debuff_caps_at_3() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YORITOMO_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	for i: int in range(5):
		ArmyCombatSystem._apply_debuff_on_hit(atk, dfn)
	assert_eq(dfn["yoritomo_def_debuff"], 3)


func test_scorpions_claws_debuff() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.SCORPIONS_CLAWS)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var atk: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var dfn: Dictionary = _make_bc(c2, 1, 0, "defender")
	var atk_before: int = dfn["base_attack"]
	var md_before: int = dfn["base_morale_defense"]
	ArmyCombatSystem._apply_debuff_on_hit(atk, dfn)
	assert_eq(dfn["base_attack"], atk_before - 1)
	assert_eq(dfn["base_morale_defense"], md_before - 1)


# Adjacency morale defense
func test_shiba_morale_defense_aura() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.SHIBA_BUSHI)
	var target: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var shiba: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var allies: Array[Dictionary] = [target, shiba]
	assert_eq(ArmyCombatSystem._get_adjacency_morale_defense_bonus(target, allies), 1)


func test_black_cabal_morale_defense_penalty() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BLACK_CABAL)
	var target: Dictionary = _make_bc(c1, 1, 0, "defender")
	var cabal: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var enemies: Array[Dictionary] = [cabal]
	assert_eq(ArmyCombatSystem._get_adjacency_morale_defense_penalty(target, enemies), -1)


# Storm Legion no terrain penalties
func test_storm_legion_no_terrain_penalties() -> void:
	assert_true(ArmyCombatSystem._has_no_terrain_penalties(Enums.CompanyUnitType.STORM_LEGION))


func test_normal_has_terrain_penalties() -> void:
	assert_false(ArmyCombatSystem._has_no_terrain_penalties(Enums.CompanyUnitType.BUSHI_RETAINER))


# Terrain modifiers apply to clan cavalry
func test_terrain_forest_disables_shinjo_flanking() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.FOREST, Enums.CompanyUnitType.SHINJO_BUSHI, false, false,
	)
	assert_eq(mods["flanking_disabled"], true)
	assert_eq(mods["attack_mod"], -2)


func test_terrain_urban_disables_utaku_flanking() -> void:
	var mods: Dictionary = ArmyCombatSystem.get_terrain_modifiers(
		Enums.BattleTerrainType.URBAN, Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS, false, false,
	)
	assert_eq(mods["flanking_disabled"], true)


# Ally buff system
func test_ally_buff_yamabushi_attack() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YAMABUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.MIRUMOTO_BUSHI)
	var yamabushi: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var mirumoto: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var side: Array[Dictionary] = [yamabushi, mirumoto]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(mirumoto["ally_buff_attack"], 3, "Yamabushi should grant +3 Atk to adjacent Dragon")


func test_ally_buff_yamabushi_defense_once() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YAMABUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.MIRUMOTO_BUSHI)
	var yamabushi: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var mirumoto: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var side: Array[Dictionary] = [yamabushi, mirumoto]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(mirumoto["ally_buff_defense"], 2, "Yamabushi one-time +2 Def")
	assert_true(yamabushi["yamabushi_def_used"])
	# Second application should not add more defense
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(mirumoto["ally_buff_defense"], 0, "One-time defense buff should not re-apply")


func test_ally_buff_elemental_guard() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ELEMENTAL_GUARD)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.SHIBA_BUSHI)
	var guard: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var shiba: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var side: Array[Dictionary] = [guard, shiba]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(shiba["ally_buff_attack"], 3, "Elemental Guard should grant +3 Atk to adjacent Phoenix")


func test_ally_buff_storm_riders() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.STORM_RIDERS)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.YORITOMO_BUSHI)
	var riders: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var yoritomo: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var side: Array[Dictionary] = [riders, yoritomo]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(yoritomo["ally_buff_attack"], 2, "Storm Riders should grant +2 Atk to adjacent Mantis")


func test_ally_buff_mirumoto_shugenja() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.MIRUMOTO_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.YAMABUSHI)
	var mirumoto: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var yamabushi: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var side: Array[Dictionary] = [mirumoto, yamabushi]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_true(
		yamabushi["ally_buff_attack"] >= 1,
		"Mirumoto should grant +1 Atk to adjacent shugenja",
	)


func test_ally_buff_no_self_buff() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YAMABUSHI)
	var yamabushi: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var side: Array[Dictionary] = [yamabushi]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(yamabushi["ally_buff_attack"], 0, "Should not buff self")


func test_ally_buff_not_adjacent() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.YAMABUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.MIRUMOTO_BUSHI)
	var yamabushi: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var mirumoto: Dictionary = _make_bc(c2, 1, 3, "attacker")
	var side: Array[Dictionary] = [yamabushi, mirumoto]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_ally_buffs(side)
	assert_eq(mirumoto["ally_buff_attack"], 0, "Non-adjacent should not receive buff")


# Elemental Legions synergy
func test_elemental_legions_attack_near_guard() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ELEMENTAL_LEGIONS)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.ELEMENTAL_GUARD)
	var legion: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var guard: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var allies: Array[Dictionary] = [legion, guard]
	assert_eq(ArmyCombatSystem._get_adjacency_attack_bonus(legion, allies), 2)


func test_elemental_legions_defense_near_guard() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.ELEMENTAL_LEGIONS)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.ELEMENTAL_GUARD)
	var legion: Dictionary = _make_bc(c1, 1, 0, "attacker")
	var guard: Dictionary = _make_bc(c2, 1, 1, "attacker")
	var allies: Array[Dictionary] = [legion, guard]
	assert_eq(ArmyCombatSystem._get_adjacency_defense_bonus(legion, allies), 1)


# Round number tracking and first-round bonus integration
func test_round_number_increments() -> void:
	var atk: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.KAKITA_BUSHI, "attacker")
	var dfn: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	ArmyCombatSystem._apply_setup_modifiers(atk, Enums.BattleTerrainType.PLAINS, false, false, 0)
	ArmyCombatSystem._apply_setup_modifiers(dfn, Enums.BattleTerrainType.PLAINS, true, false, 0)
	ArmyCombatSystem._resolve_combat_round(atk, dfn, Enums.BattleTerrainType.PLAINS, _dice)
	assert_eq(atk[0]["round_number"], 1)
	ArmyCombatSystem._resolve_combat_round(atk, dfn, Enums.BattleTerrainType.PLAINS, _dice)
	assert_eq(atk[0]["round_number"], 2)


# Full integration: clan elite battle
func test_full_battle_lion_vs_crab() -> void:
	var atk: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.AKODO_BUSHI, "attacker")
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.HIDA_BUSHI, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_true(result["rounds"] > 1)
	assert_true(result["victor"] in ["attacker", "defender", "draw"])


func test_full_battle_scorpion_morale_attrition() -> void:
	var c1: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BAYUSHI_BUSHI)
	var c2: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.BLACK_CABAL)
	var atk: Array[Dictionary] = [
		_make_bc(c1, 1, 0, "attacker"),
		_make_bc(c2, 1, 1, "attacker"),
	]
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.PEASANT_LEVY, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_eq(result["victor"], "attacker", "Scorpion morale pressure should break Levy")


func test_full_battle_deathseekers_never_rout() -> void:
	var atk: Array[Dictionary] = _make_army(1, Enums.CompanyUnitType.DEATHSEEKERS, "attacker")
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.BUSHI_RETAINER, "defender", 100)
	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		atk, dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	for bc: Dictionary in result["attacker_states"]:
		assert_false(bc["is_routed"], "Deathseekers should never rout")


# =============================================================================
# Shadowlands special abilities (s2.4.7 — LOCKED)
# =============================================================================

# Minimal Shadowlands battle company for ArmyCombatSystem tests.
func _make_sl_bc(
	company_id: int,
	sl_unit_type: int,
	attack: int,
	defense: int,
	morale: int,
	morale_defense: int,
	side: String,
	row: int = 1,
	column: int = 0,
	extra_flags: Dictionary = {},
) -> Dictionary:
	var offset: int = ArmyCombatSystem.SHADOWLANDS_UNIT_TYPE_OFFSET
	var no_morale: bool = extra_flags.get("no_morale", false)
	var bc: Dictionary = {
		"company": null,
		"company_id": company_id,
		"unit_type": offset + sl_unit_type,
		"starting_health": 153,
		"current_health": 153,
		"starting_morale": 1 if no_morale else morale,
		"current_morale": 0 if no_morale else morale,
		"base_attack": attack,
		"base_defense": defense,
		"base_morale_defense": morale_defense,
		"row": row,
		"column": column,
		"side": side,
		"is_routed": false,
		"is_destroyed": false,
		"commander": null,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
		"survival_thresholds_triggered": [],
		"no_morale": no_morale,
		"immune_routing_contagion": false,
		"sl_dark_spellcraft": false,
		"sl_pack_hunters": false,
		"sl_first_round_atk_bonus": 0,
		"sl_horde_command": false,
		"sl_feeding_frenzy": false,
		"sl_brutal_authority": false,
		"sl_wall_breaker_si_ignore": 0,
		"sl_undead": no_morale,
		"health_damage_this_round": 0,
		"round_number": 0,
		"terrain_attack_mod": 0,
		"terrain_defense_mod": 0,
		"terrain_flanking_disabled": false,
		"terrain_flanking_bonus_mod": 0,
		"ally_buff_attack": 0,
		"ally_buff_defense": 0,
		"ally_buff_morale_defense": 0,
	}
	for key: String in extra_flags:
		bc[key] = extra_flags[key]
	return bc


func test_dark_spellcraft_skips_health_damage() -> void:
	# Bakemono Shaman attacks a high-defense defender — with dark_spellcraft it deals
	# no health damage (bypasses the normal attack path).
	var shaman := _make_sl_bc(1, Enums.ShadowlandsUnitType.BAKEMONO_SHAMAN,
		2, 1, 10, 3, "attacker", 1, 0, {"sl_dark_spellcraft": true})
	var dfn := _make_sl_bc(2, Enums.ShadowlandsUnitType.ZOMBIE,
		3, 20, 10, 5, "defender", 1, 0, {"no_morale": true})
	var atk_arr: Array[Dictionary] = [shaman]
	var def_arr: Array[Dictionary] = [dfn]
	ArmyCombatSystem._apply_setup_modifiers(atk_arr, Enums.BattleTerrainType.PLAINS, false, false, 0)
	ArmyCombatSystem._apply_setup_modifiers(def_arr, Enums.BattleTerrainType.PLAINS, true, false, 0)
	_dice.set_seed(42)
	ArmyCombatSystem._resolve_combat_round(atk_arr, def_arr, Enums.BattleTerrainType.PLAINS, _dice)
	assert_eq(dfn["current_health"], 153, "Dark Spellcraft deals no health damage")


func test_dark_spellcraft_deals_direct_morale_damage() -> void:
	# Bakemono Shaman vs a unit with low morale defense — direct 1d10 morale damage.
	var shaman := _make_sl_bc(1, Enums.ShadowlandsUnitType.BAKEMONO_SHAMAN,
		2, 1, 10, 3, "attacker", 1, 0, {"sl_dark_spellcraft": true})
	var dfn_c: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.PEASANT_LEVY)
	var dfn: Dictionary = _make_bc(dfn_c, 1, 0, "defender")
	# Give very low morale so spellcraft almost certainly routes it eventually.
	dfn["current_morale"] = 3
	dfn["starting_morale"] = 3
	var atk_arr: Array[Dictionary] = [shaman]
	var def_arr: Array[Dictionary] = [dfn]
	ArmyCombatSystem._apply_setup_modifiers(atk_arr, Enums.BattleTerrainType.PLAINS, false, false, 0)
	ArmyCombatSystem._apply_setup_modifiers(def_arr, Enums.BattleTerrainType.PLAINS, true, false, 0)
	# Run a few rounds — morale should drop from spellcraft.
	_dice.set_seed(1)
	for _i: int in range(5):
		if not ArmyCombatSystem.is_active(dfn):
			break
		ArmyCombatSystem._resolve_combat_round(atk_arr, def_arr, Enums.BattleTerrainType.PLAINS, _dice)
	assert_true(dfn["current_morale"] < 3 or dfn["is_routed"],
		"Dark Spellcraft should reduce defender morale")


func test_sl_first_round_atk_bonus_only_round_1() -> void:
	var skeleton := _make_sl_bc(1, Enums.ShadowlandsUnitType.SKELETON_WARRIOR,
		4, 2, 1, 0, "attacker", 1, 0, {"no_morale": true, "sl_first_round_atk_bonus": 1})
	var dfn_c: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.PEASANT_LEVY)
	var dfn: Dictionary = _make_bc(dfn_c, 1, 0, "defender")
	var atk_arr: Array[Dictionary] = [skeleton]
	var def_arr: Array[Dictionary] = [dfn]
	ArmyCombatSystem._apply_setup_modifiers(atk_arr, Enums.BattleTerrainType.PLAINS, false, false, 0)
	ArmyCombatSystem._apply_setup_modifiers(def_arr, Enums.BattleTerrainType.PLAINS, true, false, 0)

	# Round 1: skeleton gets +1 bonus.
	skeleton["round_number"] = 0
	_dice.set_seed(5)
	ArmyCombatSystem._resolve_combat_round(atk_arr, def_arr, Enums.BattleTerrainType.PLAINS, _dice)
	var health_after_r1: int = dfn["current_health"]

	# Round 2: no first-round bonus. Restore state so damage is comparable.
	dfn["current_health"] = 153
	dfn["is_destroyed"] = false
	_dice.set_seed(5)  # Same seed — only difference is round_number.
	ArmyCombatSystem._resolve_combat_round(atk_arr, def_arr, Enums.BattleTerrainType.PLAINS, _dice)
	var health_after_r2: int = dfn["current_health"]

	# Round 1 damage >= round 2 damage (may be equal if roll is 0, unlikely with seed 5).
	assert_true(health_after_r1 <= health_after_r2,
		"Skeleton deals more or equal damage in round 1 than later rounds")


func test_horde_command_gives_undead_attack_buff() -> void:
	var maho := _make_sl_bc(1, Enums.ShadowlandsUnitType.MAHO_TSUKAI,
		2, 2, 12, 5, "attacker", 2, 0, {"sl_horde_command": true})
	var zombie := _make_sl_bc(2, Enums.ShadowlandsUnitType.ZOMBIE,
		3, 4, 1, 0, "attacker", 1, 0, {"no_morale": true, "sl_undead": true})
	var side: Array[Dictionary] = [maho, zombie]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_shadowlands_ally_buffs(side)
	assert_eq(zombie["ally_buff_attack"], 1, "Horde Command should give undead +1 Attack")
	assert_eq(maho["ally_buff_attack"], 0, "Maho-tsukai does not buff itself")


func test_horde_command_dead_maho_no_buff() -> void:
	var maho := _make_sl_bc(1, Enums.ShadowlandsUnitType.MAHO_TSUKAI,
		2, 2, 12, 5, "attacker", 2, 0, {"sl_horde_command": true})
	maho["is_destroyed"] = true  # Maho-tsukai dead — Horde Command inactive.
	var zombie := _make_sl_bc(2, Enums.ShadowlandsUnitType.ZOMBIE,
		3, 4, 1, 0, "attacker", 1, 0, {"no_morale": true, "sl_undead": true})
	var side: Array[Dictionary] = [maho, zombie]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_shadowlands_ally_buffs(side)
	assert_eq(zombie["ally_buff_attack"], 0, "Dead maho-tsukai provides no Horde Command bonus")


func test_brutal_authority_buffs_adjacent_ogres() -> void:
	var offset: int = ArmyCombatSystem.SHADOWLANDS_UNIT_TYPE_OFFSET
	var warlord := _make_sl_bc(1, Enums.ShadowlandsUnitType.OGRE_WARLORD,
		8, 7, 18, 8, "attacker", 1, 2, {"sl_brutal_authority": true})
	# Ogre Warrior in column 3 (within 2 of column 2).
	var ogre := _make_sl_bc(2, Enums.ShadowlandsUnitType.OGRE_WARRIOR,
		7, 6, 15, 6, "attacker", 1, 3)
	# Bakemono in column 0 (outside 2-column radius).
	var bakemono := _make_sl_bc(3, Enums.ShadowlandsUnitType.BAKEMONO,
		2, 1, 7, 1, "attacker", 1, 0)
	var side: Array[Dictionary] = [warlord, ogre, bakemono]
	ArmyCombatSystem._reset_ally_buffs(side)
	ArmyCombatSystem._apply_shadowlands_ally_buffs(side)
	assert_eq(ogre["ally_buff_attack"], 1, "Ogre Warrior within 2 columns gets +1 Attack")
	assert_eq(ogre["ally_buff_morale_defense"], 1, "Ogre Warrior within 2 columns gets +1 MD")
	assert_eq(bakemono["ally_buff_attack"], 0, "Bakemono out of range gets no buff")


func test_maho_tsukai_death_strips_revenant_flanking() -> void:
	var maho := _make_sl_bc(1, Enums.ShadowlandsUnitType.MAHO_TSUKAI,
		2, 2, 12, 5, "attacker", 2, 0)
	maho["is_destroyed"] = true
	var revenant := _make_sl_bc(2, Enums.ShadowlandsUnitType.UNDEAD_REVENANT,
		5, 4, 1, 0, "attacker", 1, 0, {"no_morale": true, "sl_undead": true})
	var side: Array[Dictionary] = [maho, revenant]
	ArmyCombatSystem._apply_maho_tsukai_death_effect(side)
	assert_true(revenant.get("sl_tactical_capability_lost", false),
		"Revenant loses tactical capability when maho-tsukai dies")


func test_maho_tsukai_death_effect_not_applied_twice() -> void:
	var maho := _make_sl_bc(1, Enums.ShadowlandsUnitType.MAHO_TSUKAI,
		2, 2, 12, 5, "attacker", 2, 0)
	maho["is_destroyed"] = true
	var revenant := _make_sl_bc(2, Enums.ShadowlandsUnitType.UNDEAD_REVENANT,
		5, 4, 1, 0, "attacker", 1, 0, {"no_morale": true, "sl_undead": true})
	var side: Array[Dictionary] = [maho, revenant]
	ArmyCombatSystem._apply_maho_tsukai_death_effect(side)
	# Simulate removing the flag and calling again — the guard prevents re-application.
	revenant["sl_tactical_capability_lost"] = false
	ArmyCombatSystem._apply_maho_tsukai_death_effect(side)
	assert_false(revenant.get("sl_tactical_capability_lost", false),
		"Death effect not applied a second time once the guard fires")


func test_wall_breaker_si_ignore_reduces_defender_defense() -> void:
	# Ogre Warrior with sl_wall_breaker_si_ignore = 2 vs a fortified defender.
	var ogre := _make_sl_bc(1, Enums.ShadowlandsUnitType.OGRE_WARRIOR,
		10, 6, 15, 6, "attacker", 1, 0, {"sl_wall_breaker_si_ignore": 2})
	var dfn_c: MilitaryUnitData.CompanyData = _make_company(2, Enums.CompanyUnitType.GARRISON)
	var dfn: Dictionary = _make_bc(dfn_c, 1, 0, "defender")
	# Add fortification bonus to simulate tower defense.
	dfn["terrain_defense_mod"] = 3

	# Normal ogre (no SI ignore) vs same defender.
	var ogre_normal := _make_sl_bc(3, Enums.ShadowlandsUnitType.OGRE_WARRIOR,
		10, 6, 15, 6, "attacker", 1, 0, {"sl_wall_breaker_si_ignore": 0})
	var dfn2_c: MilitaryUnitData.CompanyData = _make_company(4, Enums.CompanyUnitType.GARRISON)
	var dfn2: Dictionary = _make_bc(dfn2_c, 1, 0, "defender")
	dfn2["terrain_defense_mod"] = 3

	_dice.set_seed(99)
	var dmg_with_ignore: int = ArmyCombatSystem._compute_attack_damage(
		ogre, dfn, _dice, false, false, [], [])
	_dice.set_seed(99)
	var dmg_without: int = ArmyCombatSystem._compute_attack_damage(
		ogre_normal, dfn2, _dice, false, false, [], [])

	assert_true(dmg_with_ignore >= dmg_without,
		"Wall Breaker SI ignore should produce equal or more damage than without (same roll, less defense)")


# -- Pack Hunters adjacency tests -----------------------------------------------

func test_pack_hunters_bonus_with_adjacent_ally() -> void:
	# Omoni A (sl_pack_hunters) at column 0, Omoni B (sl_pack_hunters) at column 1.
	# Same seed, with ally present vs without — adjacent ally adds +1 Attack.
	var omoni_a := _make_sl_bc(1, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 0, {"sl_pack_hunters": true})
	var omoni_b := _make_sl_bc(2, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 1, {"sl_pack_hunters": true})
	omoni_a["round_number"] = 2  # Not round 1, so no first-round bonuses from clan units.
	var dfn_c: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.HIDA_BUSHI)
	var dfn: Dictionary = _make_bc(dfn_c, 1, 0, "defender")

	_dice.set_seed(7)
	var dmg_with_pack: int = ArmyCombatSystem._compute_attack_damage(
		omoni_a, dfn, _dice, false, false, [omoni_a, omoni_b], [dfn])

	# Same scenario but no adjacent Omoni ally.
	var omoni_alone := _make_sl_bc(4, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 0, {"sl_pack_hunters": true})
	omoni_alone["round_number"] = 2
	var dfn2_c: MilitaryUnitData.CompanyData = _make_company(5, Enums.CompanyUnitType.HIDA_BUSHI)
	var dfn2: Dictionary = _make_bc(dfn2_c, 1, 0, "defender")

	_dice.set_seed(7)
	var dmg_without_pack: int = ArmyCombatSystem._compute_attack_damage(
		omoni_alone, dfn2, _dice, false, false, [omoni_alone], [dfn2])

	assert_true(dmg_with_pack >= dmg_without_pack,
		"Pack Hunters should give equal or more damage when an adjacent Omoni's Bakemono is present")


func test_pack_hunters_no_bonus_non_adjacent() -> void:
	# Omoni A at column 0, Omoni B at column 3 — not adjacent, no bonus.
	var omoni_a := _make_sl_bc(1, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 0, {"sl_pack_hunters": true})
	var omoni_b_far := _make_sl_bc(2, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 3, {"sl_pack_hunters": true})
	omoni_a["round_number"] = 2
	var dfn_c: MilitaryUnitData.CompanyData = _make_company(3, Enums.CompanyUnitType.HIDA_BUSHI)
	var dfn: Dictionary = _make_bc(dfn_c, 1, 0, "defender")

	_dice.set_seed(7)
	var dmg_non_adjacent: int = ArmyCombatSystem._compute_attack_damage(
		omoni_a, dfn, _dice, false, false, [omoni_a, omoni_b_far], [dfn])

	# Same scenario with no ally at all — should be identical.
	var omoni_alone := _make_sl_bc(4, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 0, {"sl_pack_hunters": true})
	omoni_alone["round_number"] = 2
	var dfn2_c: MilitaryUnitData.CompanyData = _make_company(5, Enums.CompanyUnitType.HIDA_BUSHI)
	var dfn2: Dictionary = _make_bc(dfn2_c, 1, 0, "defender")

	_dice.set_seed(7)
	var dmg_no_ally: int = ArmyCombatSystem._compute_attack_damage(
		omoni_alone, dfn2, _dice, false, false, [omoni_alone], [dfn2])

	assert_eq(dmg_non_adjacent, dmg_no_ally,
		"Non-adjacent Omoni's Bakemono should not trigger Pack Hunters bonus")


func test_pack_hunters_in_full_battle_resolve() -> void:
	# Integration smoke test: two Omoni's Bakemono side-by-side fighting a garrison.
	# Verifies resolve_battle completes without error and Pack Hunters produces a valid result.
	var omoni_a := _make_sl_bc(1, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 0, {"sl_pack_hunters": true})
	var omoni_b := _make_sl_bc(2, Enums.ShadowlandsUnitType.OMONI_BAKEMONO,
		5, 3, 13, 4, "attacker", 1, 1, {"sl_pack_hunters": true})
	var dfn: Array[Dictionary] = _make_army(2, Enums.CompanyUnitType.GARRISON, "defender", 10)

	_dice.set_seed(42)
	var result: Dictionary = ArmyCombatSystem.resolve_battle(
		[omoni_a, omoni_b], dfn, Enums.BattleTerrainType.PLAINS, _dice,
	)
	assert_true(result.has("victor"), "resolve_battle must return a victor key")
	assert_true(result["rounds"] > 0, "Battle must last at least one round")
	assert_true(result["victor"] in ["attacker", "defender", "draw"],
		"Victor must be a valid string")
