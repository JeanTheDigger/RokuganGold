extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_company(
	id: int,
	unit_type: Enums.CompanyUnitType = Enums.CompanyUnitType.BUSHI_RETAINER,
) -> MilitaryUnitData.CompanyData:
	return ArmyCombatSystem.create_company(id, unit_type)


# -- Iron Upkeep Cost Tests ------------------------------------------------------

func test_iron_upkeep_levy() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.PEASANT_LEVY),
		0.03, 0.001,
	)


func test_iron_upkeep_ashigaru() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
		0.10, 0.001,
	)


func test_iron_upkeep_bushi() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.BUSHI_RETAINER),
		0.20, 0.001,
	)


func test_iron_upkeep_ronin_is_zero() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.RONIN),
		0.00, 0.001,
	)


func test_iron_upkeep_garrison() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.GARRISON),
		0.10, 0.001,
	)


func test_iron_upkeep_clan_t1_hida() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.HIDA_BUSHI),
		0.25, 0.001,
	)


func test_iron_upkeep_clan_t2_hiruma() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.HIRUMA_SCOUTS),
		0.35, 0.001,
	)


func test_iron_upkeep_clan_t3_berserkers() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.CRAB_BERSERKERS),
		0.50, 0.001,
	)


func test_iron_upkeep_clan_t3_lions_pride() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.LIONS_PRIDE),
		0.50, 0.001,
	)


func test_iron_upkeep_clan_t3_utaku() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_iron_upkeep(Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS),
		0.50, 0.001,
	)


# -- Arms Equip Cost Tests -------------------------------------------------------

func test_arms_equip_levy() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.PEASANT_LEVY),
		0.25, 0.001,
	)


func test_arms_equip_ashigaru() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
		1.00, 0.001,
	)


func test_arms_equip_bushi() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.BUSHI_RETAINER),
		2.00, 0.001,
	)


func test_arms_equip_garrison() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.GARRISON),
		0.75, 0.001,
	)


func test_arms_equip_ronin_zero() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.RONIN),
		0.00, 0.001,
	)


func test_arms_equip_clan_t1() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.AKODO_BUSHI),
		2.50, 0.001,
	)


func test_arms_equip_clan_t2() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.DRAGON_TALONS),
		3.50, 0.001,
	)


func test_arms_equip_clan_t3() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.get_arms_equip_cost(Enums.CompanyUnitType.KENSHINZEN),
		5.00, 0.001,
	)


# -- Cost Tier Mapping Tests -----------------------------------------------------

func test_tier_mapping_all_clans_have_t1() -> void:
	var t1_units: Array[int] = [
		Enums.CompanyUnitType.HIDA_BUSHI,
		Enums.CompanyUnitType.KAKITA_BUSHI,
		Enums.CompanyUnitType.MIRUMOTO_BUSHI,
		Enums.CompanyUnitType.AKODO_BUSHI,
		Enums.CompanyUnitType.SHIBA_BUSHI,
		Enums.CompanyUnitType.BAYUSHI_BUSHI,
		Enums.CompanyUnitType.SHINJO_BUSHI,
		Enums.CompanyUnitType.YORITOMO_BUSHI,
	]
	for ut: int in t1_units:
		assert_eq(ArmyUpkeepSystem.get_cost_tier(ut), 1, "Unit %d should be Tier 1" % ut)


func test_tier_mapping_elite_units() -> void:
	var t3_units: Array[int] = [
		Enums.CompanyUnitType.CRAB_BERSERKERS,
		Enums.CompanyUnitType.KENSHINZEN,
		Enums.CompanyUnitType.LIONS_PRIDE,
		Enums.CompanyUnitType.ELEMENTAL_GUARD,
		Enums.CompanyUnitType.UTAKU_BATTLE_MAIDENS,
	]
	for ut: int in t3_units:
		assert_eq(ArmyUpkeepSystem.get_cost_tier(ut), 3, "Unit %d should be Tier 3" % ut)


func test_tier_mapping_universal_returns_zero() -> void:
	assert_eq(ArmyUpkeepSystem.get_cost_tier(Enums.CompanyUnitType.BUSHI_RETAINER), 0)


# -- Koku Cost Tests -------------------------------------------------------------

func test_garrison_koku_upkeep() -> void:
	assert_almost_eq(
		ArmyUpkeepSystem.GARRISON_KOKU_PER_PU_PER_SEASON,
		0.20, 0.001,
	)


func test_ronin_hire_cost() -> void:
	assert_almost_eq(ArmyUpkeepSystem.RONIN_HIRE_KOKU, 2.00, 0.001)


func test_ronin_monthly_upkeep() -> void:
	assert_almost_eq(ArmyUpkeepSystem.RONIN_UPKEEP_KOKU_PER_MONTH, 0.50, 0.001)


# -- Seasonal Cost Computation Tests ---------------------------------------------

func test_compute_company_costs_bushi() -> void:
	var costs: Dictionary = ArmyUpkeepSystem.compute_company_seasonal_costs(
		Enums.CompanyUnitType.BUSHI_RETAINER,
	)
	assert_almost_eq(costs["rice"], 0.35, 0.001)
	assert_almost_eq(costs["iron"], 0.20, 0.001)
	assert_almost_eq(costs["koku"], 0.00, 0.001)


func test_compute_company_costs_garrison() -> void:
	var costs: Dictionary = ArmyUpkeepSystem.compute_company_seasonal_costs(
		Enums.CompanyUnitType.GARRISON,
	)
	assert_almost_eq(costs["koku"], 0.20, 0.001)


func test_compute_company_costs_ronin() -> void:
	var costs: Dictionary = ArmyUpkeepSystem.compute_company_seasonal_costs(
		Enums.CompanyUnitType.RONIN,
	)
	assert_almost_eq(costs["iron"], 0.00, 0.001)
	assert_almost_eq(costs["koku"], 1.50, 0.001)


func test_compute_army_costs() -> void:
	var companies: Array[MilitaryUnitData.CompanyData] = [
		_make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_company(2, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
		_make_company(3, Enums.CompanyUnitType.PEASANT_LEVY),
	]
	var costs: Dictionary = ArmyUpkeepSystem.compute_army_seasonal_costs(companies)
	assert_almost_eq(costs["rice"], 0.35 * 3.0, 0.001)
	assert_almost_eq(costs["iron"], 0.20 + 0.10 + 0.03, 0.001)
	assert_almost_eq(costs["koku"], 0.00, 0.001)


# -- Iron Upkeep Failure Tests ---------------------------------------------------

func test_iron_failure_zero_seasons() -> void:
	var p: Dictionary = ArmyUpkeepSystem.get_iron_failure_penalties(0)
	assert_eq(p["attack"], 0)
	assert_eq(p["defense"], 0)
	assert_eq(p["morale"], 0)
	assert_eq(p["morale_defense"], 0)


func test_iron_failure_one_season() -> void:
	var p: Dictionary = ArmyUpkeepSystem.get_iron_failure_penalties(1)
	assert_eq(p["attack"], -2)
	assert_eq(p["defense"], -2)
	assert_eq(p["morale"], -4)
	assert_eq(p["morale_defense"], -2)


func test_iron_failure_two_seasons() -> void:
	var p: Dictionary = ArmyUpkeepSystem.get_iron_failure_penalties(2)
	assert_eq(p["attack"], -4)
	assert_eq(p["defense"], -4)
	assert_eq(p["morale"], -8)
	assert_eq(p["morale_defense"], -4)


func test_iron_failure_clamps_at_two() -> void:
	var p3: Dictionary = ArmyUpkeepSystem.get_iron_failure_penalties(3)
	var p2: Dictionary = ArmyUpkeepSystem.get_iron_failure_penalties(2)
	assert_eq(p3["attack"], p2["attack"])
	assert_eq(p3["morale"], p2["morale"])


func test_apply_iron_failure_degrades_stats() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	assert_eq(c.attack, 6)
	assert_eq(c.defense, 5)
	ArmyUpkeepSystem.apply_iron_failure(c, 1)
	assert_eq(c.attack, 4)
	assert_eq(c.defense, 3)
	assert_eq(c.morale, 14)
	assert_eq(c.morale_defense, 6)


func test_apply_iron_failure_flat_not_cumulative() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	ArmyUpkeepSystem.apply_iron_failure(c, 1)
	ArmyUpkeepSystem.apply_iron_failure(c, 2)
	assert_eq(c.attack, 2, "Should be base(6) - 4, not base(4) - 4")
	assert_eq(c.defense, 1, "Should be base(5) - 4")


func test_apply_iron_failure_restores_on_zero() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	ArmyUpkeepSystem.apply_iron_failure(c, 2)
	assert_eq(c.attack, 2)
	ArmyUpkeepSystem.apply_iron_failure(c, 0)
	assert_eq(c.attack, 6, "Should restore to base stats")
	assert_eq(c.defense, 5)


func test_apply_iron_failure_floors_at_zero() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.PEASANT_LEVY)
	ArmyUpkeepSystem.apply_iron_failure(c, 2)
	assert_eq(c.attack, 0, "Levy attack(1) - 4 should floor at 0")
	assert_eq(c.defense, 0, "Levy defense(1) - 4 should floor at 0")


func test_process_iron_upkeep_sufficient() -> void:
	var companies: Array[MilitaryUnitData.CompanyData] = [
		_make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var state: Dictionary = {}
	var result: Dictionary = ArmyUpkeepSystem.process_iron_upkeep(
		companies, state, 1.0,
	)
	assert_true(result["supplied"])
	assert_eq(result["degraded_companies"].size(), 0)


func test_process_iron_upkeep_insufficient() -> void:
	var companies: Array[MilitaryUnitData.CompanyData] = [
		_make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var state: Dictionary = {}
	var result: Dictionary = ArmyUpkeepSystem.process_iron_upkeep(
		companies, state, 0.0,
	)
	assert_false(result["supplied"])
	assert_eq(result["degraded_companies"].size(), 1)
	assert_eq(state[1], 1)
	assert_eq(companies[0].attack, 4)


func test_process_iron_upkeep_recovery() -> void:
	var companies: Array[MilitaryUnitData.CompanyData] = [
		_make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var state: Dictionary = {1: 2}
	ArmyUpkeepSystem.apply_iron_failure(companies[0], 2)
	assert_eq(companies[0].attack, 2)
	ArmyUpkeepSystem.process_iron_upkeep(companies, state, 1.0)
	assert_eq(state[1], 0)
	assert_eq(companies[0].attack, 6, "Stats should restore on resupply")


# -- Rice Deprivation Tests ------------------------------------------------------

func test_rice_deprivation_tick_1_warning() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(1)
	assert_eq(effect["morale"], 0)
	assert_eq(effect["health"], 0)


func test_rice_deprivation_tick_2_morale_only() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(2)
	assert_eq(effect["morale"], -3)
	assert_eq(effect["health"], 0)


func test_rice_deprivation_tick_3() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(3)
	assert_eq(effect["morale"], -3)
	assert_eq(effect["health"], -5)


func test_rice_deprivation_tick_4() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(4)
	assert_eq(effect["morale"], -5)
	assert_eq(effect["health"], -10)


func test_rice_deprivation_tick_5_clamps_to_4() -> void:
	var e5: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(5)
	var e4: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(4)
	assert_eq(e5["morale"], e4["morale"])
	assert_eq(e5["health"], e4["health"])


func test_apply_rice_deprivation_damages_company() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var result: Dictionary = ArmyUpkeepSystem.apply_rice_deprivation_tick(c, 3)
	assert_eq(result["morale_lost"], 3)
	assert_eq(result["health_lost"], 5)
	assert_eq(c.morale, 18 - 3)
	assert_eq(c.health, 153 - 5)


func test_rice_deprivation_cumulative() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	ArmyUpkeepSystem.apply_rice_deprivation_tick(c, 2)
	ArmyUpkeepSystem.apply_rice_deprivation_tick(c, 3)
	assert_eq(c.morale, 18 - 3 - 3, "Rice deprivation is cumulative per tick")
	assert_eq(c.health, 153 - 5)


# -- Arms Deprivation Tests ------------------------------------------------------

func test_arms_deprivation_tick_1_no_effect() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_arms_deprivation_effect(1)
	assert_eq(effect["attack"], 0)
	assert_eq(effect["defense"], 0)


func test_arms_deprivation_tick_2() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_arms_deprivation_effect(2)
	assert_eq(effect["attack"], -2)
	assert_eq(effect["defense"], -2)


func test_arms_deprivation_tick_4() -> void:
	var effect: Dictionary = ArmyUpkeepSystem.get_arms_deprivation_effect(4)
	assert_eq(effect["attack"], -6)
	assert_eq(effect["defense"], -6)


func test_apply_arms_deprivation_flat_from_base() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	ArmyUpkeepSystem.apply_arms_deprivation(c, 2)
	assert_eq(c.attack, 4, "Base 6 - 2")
	assert_eq(c.defense, 3, "Base 5 - 2")
	ArmyUpkeepSystem.apply_arms_deprivation(c, 3)
	assert_eq(c.attack, 2, "Base 6 - 4, not 4 - 4")
	assert_eq(c.defense, 1, "Base 5 - 4, not 3 - 4")


# -- Supply Restoration Tests ----------------------------------------------------

func test_supply_restored_resets_tick() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var dep: Dictionary = {
		1: {
			"rice_tick": 3,
			"arms_tick": 3,
			"rice_supplied": true,
			"arms_supplied": true,
		},
	}
	ArmyUpkeepSystem.process_deprivation_tick([c], dep)
	assert_eq(dep[1]["rice_tick"], 1, "Supply restored should reset to tick 1")
	assert_eq(dep[1]["arms_tick"], 1)


func test_supply_cut_increments_tick() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var dep: Dictionary = {
		1: {
			"rice_tick": 2,
			"arms_tick": 2,
			"rice_supplied": false,
			"arms_supplied": false,
		},
	}
	ArmyUpkeepSystem.process_deprivation_tick([c], dep)
	assert_eq(dep[1]["rice_tick"], 3)
	assert_eq(dep[1]["arms_tick"], 3)


# -- Recovery Tests --------------------------------------------------------------

func test_recovery_stationary_supplied() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	c.health = 140
	c.morale = 10
	var result: Dictionary = ArmyUpkeepSystem.apply_recovery_tick(c, true, true, true, 1)
	assert_eq(c.health, 145)
	assert_eq(c.morale, 13)
	assert_eq(result["health_recovered"], 5)
	assert_eq(result["morale_recovered"], 3)


func test_recovery_not_stationary() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	c.health = 140
	var result: Dictionary = ArmyUpkeepSystem.apply_recovery_tick(c, false, true, true, 1)
	assert_eq(c.health, 140, "No recovery while moving")
	assert_eq(result["health_recovered"], 0)


func test_recovery_caps_at_base() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	c.health = 152
	c.morale = 17
	ArmyUpkeepSystem.apply_recovery_tick(c, true, true, true, 1)
	assert_eq(c.health, 153, "Should cap at base health")
	assert_eq(c.morale, 18, "Should cap at base morale")


func test_recovery_arms_tier() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	ArmyUpkeepSystem.apply_arms_deprivation(c, 3)
	assert_eq(c.attack, 2)
	var result: Dictionary = ArmyUpkeepSystem.apply_recovery_tick(c, true, true, true, 3)
	assert_true(result["arms_tier_recovered"])
	assert_eq(c.attack, 4, "Should recover one tier: tick 3→2, base 6 - 2 = 4")


func test_recovery_no_arms_recovery_at_tick_1() -> void:
	var c: MilitaryUnitData.CompanyData = _make_company(1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var result: Dictionary = ArmyUpkeepSystem.apply_recovery_tick(c, true, true, true, 1)
	assert_false(result["arms_tier_recovered"])
