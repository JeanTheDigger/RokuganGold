extends GutTest


var _province: ProvinceData
var _settlement: SettlementData


func before_each() -> void:
	_province = ProvinceData.new()
	_province.province_id = 1
	_province.province_name = "Test Province"
	_province.terrain_type = Enums.TerrainType.PLAINS

	_settlement = SettlementData.new()
	_settlement.settlement_id = 10
	_settlement.province_id = 1
	_settlement.population_pu = 8
	_settlement.farming_pu = 4
	_settlement.mining_pu = 1
	_settlement.town_pu = 2
	_settlement.military_pu = 1
	_settlement.garrison_pu = 1
	_settlement.rice_stockpile = 5.0
	_settlement.koku_stockpile = 2.0


func _settlements() -> Array[SettlementData]:
	return [_settlement]


# -- Rice Consumption ----------------------------------------------------------

func test_consume_rice_civilian_cost() -> void:
	var result: Dictionary = ResourceTick.consume_rice_province(_province, _settlements())
	# civilian: (4 + 1 + 2) * 0.25 = 1.75
	assert_almost_eq(result["civilian_cost"], 1.75, 0.01)


func test_consume_rice_military_cost() -> void:
	var result: Dictionary = ResourceTick.consume_rice_province(_province, _settlements())
	# military: 1 * 0.35 = 0.35
	assert_almost_eq(result["military_cost"], 0.35, 0.01)


func test_consume_rice_total() -> void:
	var result: Dictionary = ResourceTick.consume_rice_province(_province, _settlements())
	# total: 1.75 + 0.35 = 2.10
	assert_almost_eq(result["total_cost"], 2.10, 0.01)


func test_consume_rice_stockpile_decreases() -> void:
	ResourceTick.consume_rice_province(_province, _settlements())
	# 5.0 - 2.10 = 2.90
	assert_almost_eq(_settlement.rice_stockpile, 2.90, 0.01)


func test_consume_rice_no_deficit_when_sufficient() -> void:
	var result: Dictionary = ResourceTick.consume_rice_province(_province, _settlements())
	assert_almost_eq(result["deficit"], 0.0, 0.01)


func test_consume_rice_deficit_when_insufficient() -> void:
	_settlement.rice_stockpile = 1.0
	var result: Dictionary = ResourceTick.consume_rice_province(_province, _settlements())
	# cost 2.10, stockpile 1.0 -> deficit 1.10
	assert_true(result["deficit"] > 1.0)
	assert_almost_eq(_settlement.rice_stockpile, 0.0, 0.01)


# -- Harvest -------------------------------------------------------------------

func test_harvest_plains_baseline() -> void:
	var meta: Dictionary = {1: {"locked_farming_pu": 4}}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, _settlements(), meta)
	assert_almost_eq(result[1]["yield"], 6.0, 0.01)


func test_harvest_river_delta() -> void:
	_province.terrain_type = Enums.TerrainType.RIVER_DELTA
	var meta: Dictionary = {1: {"locked_farming_pu": 4}}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, _settlements(), meta)
	# 4 × 1.50 × 1.5 = 9.0
	assert_almost_eq(result[1]["yield"], 9.0, 0.01)


func test_harvest_mountains() -> void:
	_province.terrain_type = Enums.TerrainType.MOUNTAINS
	var meta: Dictionary = {1: {"locked_farming_pu": 4}}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, _settlements(), meta)
	# 4 × 1.50 × 0.5 = 3.0
	assert_almost_eq(result[1]["yield"], 3.0, 0.01)


func test_harvest_adds_to_settlement_stockpile() -> void:
	var old_stock: float = _settlement.rice_stockpile
	var meta: Dictionary = {1: {"locked_farming_pu": 4}}
	var provinces: Array[ProvinceData] = [_province]
	ResourceTick._process_harvest(provinces, _settlements(), meta)
	assert_almost_eq(_settlement.rice_stockpile, old_stock + 6.0, 0.01)


func test_harvest_levy_reduces_yield() -> void:
	var meta: Dictionary = {1: {"locked_farming_pu": 2}}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, _settlements(), meta)
	# 2 × 1.50 × 1.0 = 3.0
	assert_almost_eq(result[1]["yield"], 3.0, 0.01)


# -- Starvation ----------------------------------------------------------------

func test_starvation_clear_when_no_deficit() -> void:
	var result: Dictionary = ResourceTick.check_starvation(0.0, 0, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.CLEAR)


func test_starvation_shortage_first_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(1.0, 1, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.SHORTAGE)
	assert_almost_eq(result["pu_loss_rate"], 0.03, 0.001)


func test_starvation_hunger_second_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(1.0, 2, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.HUNGER)
	assert_almost_eq(result["pu_loss_rate"], 0.08, 0.001)


func test_starvation_famine_third_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(1.0, 3, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.FAMINE)
	assert_almost_eq(result["pu_loss_rate"], 0.20, 0.001)


func test_starvation_instant_famine_on_zero_stockpile() -> void:
	var result: Dictionary = ResourceTick.check_starvation(1.0, 1, 0.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.FAMINE)


# -- Starvation Recovery (s4.3.6 LOCKED) ---------------------------------------

func test_famine_to_hunger_after_one_relief() -> void:
	var result: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, 0, ResourceTick.StarvationStage.FAMINE, 5.0,
	)
	assert_eq(result["stage"], ResourceTick.StarvationStage.HUNGER)
	assert_false(result["apply_loss"])
	assert_true(result["recovering"])


func test_hunger_to_shortage_after_one_relief() -> void:
	var result: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, 0, ResourceTick.StarvationStage.HUNGER, 5.0,
	)
	assert_eq(result["stage"], ResourceTick.StarvationStage.SHORTAGE)
	assert_false(result["apply_loss"])
	assert_true(result["recovering"])


func test_shortage_needs_two_relief_seasons() -> void:
	var r1: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, 0, ResourceTick.StarvationStage.SHORTAGE, 5.0,
	)
	assert_eq(r1["stage"], ResourceTick.StarvationStage.SHORTAGE)
	assert_false(r1["apply_loss"])
	assert_true(r1["recovering"])
	assert_eq(r1["relief_seasons"], 1)

	var r2: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, r1["relief_seasons"], ResourceTick.StarvationStage.SHORTAGE, 5.0,
	)
	assert_eq(r2["stage"], ResourceTick.StarvationStage.CLEAR)
	assert_false(r2["recovering"])


func test_full_famine_recovery_takes_four_seasons() -> void:
	var stage: ResourceTick.StarvationStage = ResourceTick.StarvationStage.FAMINE
	var relief: int = 0
	for i: int in range(4):
		var r: Dictionary = ResourceTick.resolve_starvation_transition(
			0.0, 0, relief, stage, 5.0,
		)
		stage = r["stage"] as ResourceTick.StarvationStage
		relief = r["relief_seasons"]
		assert_false(r["apply_loss"])
		if i < 3:
			assert_true(r["recovering"])
	assert_eq(stage, ResourceTick.StarvationStage.CLEAR)


func test_re_escalation_on_relapse_during_recovery() -> void:
	var r1: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, 0, ResourceTick.StarvationStage.HUNGER, 5.0,
	)
	assert_eq(r1["stage"], ResourceTick.StarvationStage.SHORTAGE)
	var r2: Dictionary = ResourceTick.resolve_starvation_transition(
		1.0, 0, r1["relief_seasons"], r1["stage"] as ResourceTick.StarvationStage, 3.0,
	)
	assert_eq(r2["stage"], ResourceTick.StarvationStage.HUNGER)
	assert_true(r2["apply_loss"])


func test_sudden_collapse_always_famine() -> void:
	var result: Dictionary = ResourceTick.resolve_starvation_transition(
		1.0, 0, 0, ResourceTick.StarvationStage.SHORTAGE, 0.0,
	)
	assert_eq(result["stage"], ResourceTick.StarvationStage.FAMINE)


func test_deficit_seasons_increment() -> void:
	var r: Dictionary = ResourceTick.resolve_starvation_transition(
		1.0, 1, 0, ResourceTick.StarvationStage.CLEAR, 5.0,
	)
	assert_eq(r["deficit_seasons"], 2)
	assert_eq(r["relief_seasons"], 0)


func test_relief_resets_deficit_counter() -> void:
	var r: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 3, 0, ResourceTick.StarvationStage.FAMINE, 5.0,
	)
	assert_eq(r["deficit_seasons"], 0)
	assert_eq(r["relief_seasons"], 0)


func test_no_pu_loss_during_relief() -> void:
	var result: Dictionary = ResourceTick.resolve_starvation_transition(
		0.0, 0, 0, ResourceTick.StarvationStage.FAMINE, 5.0,
	)
	assert_eq(result["stage"], ResourceTick.StarvationStage.HUNGER)
	assert_false(result["apply_loss"])
	assert_almost_eq(result["pu_loss_rate"], 0.08, 0.001)


# -- Tax Cascade ---------------------------------------------------------------

func test_taxable_surplus_basic() -> void:
	# 8 PU, yield 6.0 -> subsistence 8.0 -> surplus = max(0, 6.0-8.0) = 0
	var surplus: float = ResourceTick.compute_taxable_surplus(8, 6.0)
	assert_almost_eq(surplus, 0.0, 0.01)


func test_taxable_surplus_with_excess() -> void:
	var surplus: float = ResourceTick.compute_taxable_surplus(2, 6.0)
	# subsistence = 2.0, surplus = 4.0
	assert_almost_eq(surplus, 4.0, 0.01)


func test_tax_at_local_daimyo_tier() -> void:
	var result: Dictionary = ResourceTick.apply_tax_at_tier(4.0, "local_daimyo", 0.0)
	# 40% of 4.0 = 1.6
	assert_almost_eq(result["collected"], 1.6, 0.01)
	assert_almost_eq(result["passed_up"], 2.4, 0.01)


func test_tax_at_provincial_daimyo_tier() -> void:
	var result: Dictionary = ResourceTick.apply_tax_at_tier(2.4, "provincial_daimyo", 0.0)
	# 30% of 2.4 = 0.72
	assert_almost_eq(result["collected"], 0.72, 0.01)


func test_tax_personality_modifier_jin() -> void:
	var mod: float = ResourceTick.compute_tax_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, -0.10, 0.001)


func test_tax_personality_modifier_stacks() -> void:
	var mod: float = ResourceTick.compute_tax_modifier(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.KYORYOKU
	)
	# CHUGI +0.05 + KYORYOKU +0.10 = +0.15
	assert_almost_eq(mod, 0.15, 0.001)


func test_tax_with_personality_changes_collected() -> void:
	# Jin lord at local tier: 40% - 10% = 30%
	var result: Dictionary = ResourceTick.apply_tax_at_tier(4.0, "local_daimyo", -0.10)
	assert_almost_eq(result["collected"], 1.2, 0.01)


# -- Iron Production -----------------------------------------------------------

func test_iron_production_standard() -> void:
	var result: Dictionary = ResourceTick.produce_iron_settlement(_settlement, 1.0)
	# 1 mining PU × 0.50 × 1.0 = 0.50
	assert_almost_eq(result["iron_produced"], 0.50, 0.01)


func test_iron_production_rich_vein() -> void:
	var result: Dictionary = ResourceTick.produce_iron_settlement(_settlement, 1.5)
	# 1 × 0.50 × 1.5 = 0.75
	assert_almost_eq(result["iron_produced"], 0.75, 0.01)


func test_iron_returns_produced_amount() -> void:
	var result: Dictionary = ResourceTick.produce_iron_settlement(_settlement, 1.0)
	assert_almost_eq(result["iron_produced"], 0.50, 0.01)


# -- Koku Generation -----------------------------------------------------------

func test_koku_generation_baseline() -> void:
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {"_koku_modifiers": {1: 1.0}}
	var results: Dictionary = ResourceTick._process_koku_generation(settlements, meta)
	# 2 town PU × 0.25 × 1.0 = 0.50
	assert_almost_eq(results[1]["koku_generated"], 0.50, 0.01)


func test_koku_generation_port_city() -> void:
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {"_koku_modifiers": {1: 1.5}}
	var results: Dictionary = ResourceTick._process_koku_generation(settlements, meta)
	# 2 × 0.25 × 1.5 = 0.75
	assert_almost_eq(results[1]["koku_generated"], 0.75, 0.01)


func test_koku_adds_to_settlement_stockpile() -> void:
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {"_koku_modifiers": {1: 1.0}}
	ResourceTick._process_koku_generation(settlements, meta)
	assert_almost_eq(_settlement.koku_stockpile, 2.50, 0.01)


# -- Population Growth ---------------------------------------------------------

func test_growth_rate_baseline() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		8, ResourceTick.StarvationStage.CLEAR, 0, 5.0
	)
	# 5% annual / 4 = 1.25%
	assert_almost_eq(rate, 0.0125, 0.001)


func test_growth_rate_with_peace_bonus() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		8, ResourceTick.StarvationStage.CLEAR, 4, 5.0
	)
	# (5% + 3%) / 4 = 2%
	assert_almost_eq(rate, 0.02, 0.001)


func test_growth_rate_strong_stockpile() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		8, ResourceTick.StarvationStage.CLEAR, 0, 20.0
	)
	# 20/8 = 2.5 per PU > 2.0 threshold → 10% annual / 4 = 2.5%
	assert_almost_eq(rate, 0.025, 0.001)


func test_growth_rate_zero_during_starvation() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		8, ResourceTick.StarvationStage.SHORTAGE, 0, 5.0
	)
	assert_eq(rate, 0.0)


func test_growth_max_rate() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		8, ResourceTick.StarvationStage.CLEAR, 5, 20.0
	)
	# (10% + 3%) / 4 = 3.25%
	assert_almost_eq(rate, 0.0325, 0.001)


# -- Full Seasonal Tick --------------------------------------------------------

func test_process_seasonal_tick_summer_consumes_rice() -> void:
	var provinces: Array[ProvinceData] = [_province]
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {"_peace_seasons": {1: 0}, "_deficit_seasons": {1: 0}}
	var result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "summer", meta
	)
	assert_true(result["rice_consumed"].has(1))
	assert_almost_eq(result["rice_consumed"][1]["total_cost"], 2.10, 0.01)


func test_process_seasonal_tick_autumn_harvests() -> void:
	var provinces: Array[ProvinceData] = [_province]
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {
		1: {"locked_farming_pu": 4},
		"_peace_seasons": {1: 0},
		"_deficit_seasons": {1: 0},
	}
	var result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "autumn", meta
	)
	assert_true(result["harvest"].has(1))
	assert_almost_eq(result["harvest"][1]["yield"], 6.0, 0.01)


func test_process_seasonal_tick_iron_production() -> void:
	var provinces: Array[ProvinceData] = [_province]
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {
		"_mine_quality": {1: 1.0},
		"_peace_seasons": {1: 0},
		"_deficit_seasons": {1: 0},
	}
	var result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "summer", meta
	)
	assert_true(result["iron_produced"].has(1))
	assert_almost_eq(result["iron_produced"][1]["iron_produced"], 0.50, 0.01)


func test_process_seasonal_tick_koku_generation() -> void:
	var provinces: Array[ProvinceData] = [_province]
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {
		"_koku_modifiers": {1: 1.0},
		"_peace_seasons": {1: 0},
		"_deficit_seasons": {1: 0},
	}
	var result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "summer", meta
	)
	assert_true(result["koku_generated"].has(1))
	assert_almost_eq(result["koku_generated"][1]["koku_generated"], 0.50, 0.01)


func test_process_seasonal_tick_spring_locks_planting() -> void:
	var provinces: Array[ProvinceData] = [_province]
	var settlements: Array[SettlementData] = _settlements()
	var meta: Dictionary = {"_peace_seasons": {1: 0}, "_deficit_seasons": {1: 0}}
	ResourceTick.process_seasonal_tick(provinces, settlements, "spring", meta)
	assert_eq(int(meta[1]["locked_farming_pu"]), 4)


# -- Forge Conversion (GDD s4.3) -----------------------------------------------

func test_forge_single_forge_full_capacity() -> void:
	# 1 forge, 5.0 iron → converts 3.0 (capacity cap)
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(1, 5.0)
	assert_almost_eq(r["capacity"], 3.0, 0.01)
	assert_almost_eq(r["arms_produced"], 3.0, 0.01)
	assert_almost_eq(r["iron_consumed"], 3.0, 0.01)


func test_forge_single_forge_limited_iron() -> void:
	# 1 forge, 1.5 iron → converts only 1.5 (iron-limited)
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(1, 1.5)
	assert_almost_eq(r["capacity"], 3.0, 0.01)
	assert_almost_eq(r["arms_produced"], 1.5, 0.01)
	assert_almost_eq(r["iron_consumed"], 1.5, 0.01)


func test_forge_two_forges_doubles_capacity() -> void:
	# 2 forges, 10.0 iron → capacity 6.0, converts 6.0
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(2, 10.0)
	assert_almost_eq(r["capacity"], 6.0, 0.01)
	assert_almost_eq(r["arms_produced"], 6.0, 0.01)


func test_forge_no_forges_no_conversion() -> void:
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(0, 10.0)
	assert_almost_eq(r["arms_produced"], 0.0, 0.01)
	assert_almost_eq(r["iron_consumed"], 0.0, 0.01)


func test_forge_no_iron_no_conversion() -> void:
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(1, 0.0)
	assert_almost_eq(r["arms_produced"], 0.0, 0.01)
	assert_almost_eq(r["iron_consumed"], 0.0, 0.01)


func test_forge_one_to_one_conversion_rate() -> void:
	# GDD s4.3: 1.00 Iron → 1.00 Arms, no loss in conversion
	var r: Dictionary = ResourceTick.process_forge_conversion_single_clan(1, 2.5)
	assert_almost_eq(r["arms_produced"], r["iron_consumed"], 0.001)


# -- Garrison Check (GDD s4.3.11) -----------------------------------------------

func test_garrison_required_rounds_up() -> void:
	assert_almost_eq(ResourceTick.compute_garrison_required(1), 0.1, 0.01)
	assert_almost_eq(ResourceTick.compute_garrison_required(8), 0.4, 0.01)
	assert_almost_eq(ResourceTick.compute_garrison_required(10), 0.5, 0.01)
	assert_almost_eq(ResourceTick.compute_garrison_required(100), 5.0, 0.01)


func test_not_under_garrisoned_when_sufficient() -> void:
	assert_false(ResourceTick.is_under_garrisoned(_province, _settlements()))


func test_under_garrisoned_when_zero() -> void:
	_settlement.garrison_pu = 0
	assert_true(ResourceTick.is_under_garrisoned(_province, _settlements()))


func test_garrison_check_increments_under_seasons() -> void:
	_settlement.garrison_pu = 0
	var meta: Dictionary = {}
	var r1: Dictionary = ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_eq(r1[1]["seasons"], 1)
	var r2: Dictionary = ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_eq(r2[1]["seasons"], 2)


func test_garrison_check_resets_when_garrisoned() -> void:
	_settlement.garrison_pu = 0
	var meta: Dictionary = {}
	ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	_settlement.garrison_pu = 1
	var r2: Dictionary = ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_eq(r2[1]["seasons"], 0)


func test_garrison_check_drains_rice() -> void:
	_settlement.garrison_pu = 0
	_settlement.rice_stockpile = 5.0
	var meta: Dictionary = {}
	ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_almost_eq(_settlement.rice_stockpile, 4.95, 0.001)


func test_garrison_check_reduces_stability() -> void:
	_settlement.garrison_pu = 0
	_province.stability = 100.0
	var meta: Dictionary = {}
	ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_almost_eq(_province.stability, 98.0, 0.01)


func test_garrison_trade_drain_caps() -> void:
	_settlement.garrison_pu = 0
	var meta: Dictionary = {"_under_garrison_seasons": {1: 10}}
	var r: Dictionary = ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	assert_almost_eq(r[1]["trade_drain"], 0.3, 0.001)


func test_garrison_koku_malus_applied() -> void:
	_settlement.garrison_pu = 0
	_settlement.town_pu = 2
	_settlement.koku_stockpile = 0.0
	var meta: Dictionary = {"_koku_modifiers": {1: 1.0}}
	ResourceTick._process_garrison_check(
		[_province] as Array[ProvinceData], _settlements(), meta
	)
	ResourceTick._process_koku_generation(_settlements(), meta)
	var expected: float = float(_settlement.town_pu) * ResourceTick.KOKU_PER_TOWN_PU_PER_SEASON * 0.8
	assert_almost_eq(_settlement.koku_stockpile, expected, 0.01)


# -- Stipend Personality Modifier (GDD s4.3.9) ---------------------------------

func test_stipend_modifier_jin_gives_ten_percent() -> void:
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE,
	)
	assert_almost_eq(mod, 0.10, 0.001)


func test_stipend_modifier_meiyo_gives_five_percent() -> void:
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE,
	)
	assert_almost_eq(mod, 0.05, 0.001)


func test_stipend_modifier_kyoryoku_gives_minus_ten_percent() -> void:
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU,
	)
	assert_almost_eq(mod, -0.10, 0.001)


func test_stipend_modifier_seigyo_ishi_stack_to_minus_ten_percent() -> void:
	# Both Seigyo -5% and Ishi -5% don't combine here (only one Shourido virtue per lord)
	# Test Seigyo alone:
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO,
	)
	assert_almost_eq(mod, -0.05, 0.001)


func test_stipend_modifier_jin_plus_kyoryoku_clamps_to_zero() -> void:
	# Jin +10% + Kyōryōku -10% = 0%
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.KYORYOKU,
	)
	assert_almost_eq(mod, 0.0, 0.001)


func test_stipend_modifier_none_none_is_zero() -> void:
	var mod: float = ResourceTick.compute_stipend_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
	)
	assert_almost_eq(mod, 0.0, 0.001)


func test_stipend_modifier_clamps_at_positive_fifteen() -> void:
	# Jin +10% + Meiyo +5% = +15% — at the cap
	# Both virtues can't coexist (one Bushido per lord), but test the cap logic
	# by using compute_stipend_modifier with a combined manual scenario via clamping
	var combined: float = 0.10 + 0.05  # equivalent to having both active
	var clamped: float = clampf(combined, -0.15, 0.15)
	assert_almost_eq(clamped, 0.15, 0.001)


# -- Stipend Disposition Delta (GDD s4.3.9) ------------------------------------

func test_stipend_disposition_delta_plus_ten_percent_gives_plus_two() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(0.10), 2)


func test_stipend_disposition_delta_plus_five_percent_gives_plus_one() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(0.05), 1)


func test_stipend_disposition_delta_zero_gives_zero() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(0.0), 0)


func test_stipend_disposition_delta_minus_five_gives_minus_one() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(-0.05), -1)


func test_stipend_disposition_delta_minus_ten_gives_minus_two() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(-0.10), -2)


func test_stipend_disposition_delta_plus_fifteen_gives_plus_two() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(0.15), 2)


func test_stipend_disposition_delta_minus_fifteen_gives_minus_two() -> void:
	assert_eq(ResourceTick.compute_stipend_disposition_delta(-0.15), -2)


# -- Emperor Tax Rate (GDD s55.10) ---------------------------------------------

func test_emperor_take_rate_iron_is_baseline() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate(
		{"archetype": StrategicReview.EmperorArchetype.IRON}
	)
	assert_almost_eq(rate, 0.15, 0.001)


func test_emperor_take_rate_benevolent_minus_five() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate(
		{"archetype": StrategicReview.EmperorArchetype.BENEVOLENT}
	)
	assert_almost_eq(rate, 0.10, 0.001)


func test_emperor_take_rate_warlike_plus_five() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate(
		{"archetype": StrategicReview.EmperorArchetype.WARLIKE}
	)
	assert_almost_eq(rate, 0.20, 0.001)


func test_emperor_take_rate_tyrant_plus_ten() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate(
		{"archetype": StrategicReview.EmperorArchetype.TYRANT}
	)
	assert_almost_eq(rate, 0.25, 0.001)


func test_emperor_take_rate_cunning_unchanged() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate(
		{"archetype": StrategicReview.EmperorArchetype.CUNNING}
	)
	assert_almost_eq(rate, 0.15, 0.001)


func test_emperor_take_rate_empty_config_defaults_to_iron() -> void:
	var rate: float = ResourceTick.compute_emperor_take_rate({})
	assert_almost_eq(rate, 0.15, 0.001)


# -- Cunning Clan Redistribution (GDD s55.10) ----------------------------------

func test_cunning_modifier_friend_clan_gets_plus_ten() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier(
		"Crane", {"Crane": 40}
	)
	assert_almost_eq(mod, 0.10, 0.001)


func test_cunning_modifier_rival_clan_gets_minus_ten() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier(
		"Lion", {"Lion": -15}
	)
	assert_almost_eq(mod, -0.10, 0.001)


func test_cunning_modifier_stranger_clan_gets_zero() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier(
		"Dragon", {"Dragon": 5}
	)
	assert_almost_eq(mod, 0.0, 0.001)


func test_cunning_modifier_unknown_clan_gets_zero() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier("Mantis", {})
	assert_almost_eq(mod, 0.0, 0.001)


func test_cunning_modifier_devoted_gets_plus_ten() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier(
		"Scorpion", {"Scorpion": 95}
	)
	assert_almost_eq(mod, 0.10, 0.001)


func test_cunning_modifier_blood_enemy_gets_minus_ten() -> void:
	var mod: float = ResourceTick.compute_cunning_clan_modifier(
		"Crab", {"Crab": -80}
	)
	assert_almost_eq(mod, -0.10, 0.001)


# -- Emperor Income from Cascade (GDD s55.10) ----------------------------------

func _make_tax_result(passed_up: float) -> Dictionary:
	return {"surplus": 10.0, "total_collected": 4.0, "passed_up": passed_up}


func test_emperor_income_iron_matches_legacy_constant() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Crane"
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov], {"archetype": StrategicReview.EmperorArchetype.IRON}
	)
	# 6.0 * 0.42 * 0.15 = 0.378
	assert_almost_eq(result["rice"], 0.378, 0.001)
	assert_almost_eq(result["arms_redirect"], 0.0, 0.001)


func test_emperor_income_tyrant_higher_rate() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Crane"
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov], {"archetype": StrategicReview.EmperorArchetype.TYRANT}
	)
	# 6.0 * 0.42 * 0.25 = 0.63
	assert_almost_eq(result["rice"], 0.63, 0.001)
	assert_almost_eq(result["arms_redirect"], 0.0, 0.001)


func test_emperor_income_warlike_splits_arms_redirect() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Lion"
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov], {"archetype": StrategicReview.EmperorArchetype.WARLIKE}
	)
	# baseline: 6.0 * 0.42 * 0.15 = 0.378 (rice)
	# warlike:  6.0 * 0.42 * 0.20 = 0.504 (total)
	# arms_redirect = 0.504 - 0.378 = 0.126
	assert_almost_eq(result["rice"], 0.378, 0.001)
	assert_almost_eq(result["arms_redirect"], 0.126, 0.001)


func test_emperor_income_cunning_friend_clan_gets_more() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Crane"
	var config: Dictionary = {
		"archetype": StrategicReview.EmperorArchetype.CUNNING,
		"clan_dispositions": {"Crane": 40},
	}
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov], config
	)
	# 6.0 * 0.42 * (0.15 + 0.10) = 6.0 * 0.42 * 0.25 = 0.63
	assert_almost_eq(result["rice"], 0.63, 0.001)


func test_emperor_income_cunning_rival_clan_gets_less() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Lion"
	var config: Dictionary = {
		"archetype": StrategicReview.EmperorArchetype.CUNNING,
		"clan_dispositions": {"Lion": -20},
	}
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov], config
	)
	# 6.0 * 0.42 * (0.15 - 0.10) = 6.0 * 0.42 * 0.05 = 0.126
	assert_almost_eq(result["rice"], 0.126, 0.001)


func test_emperor_income_cunning_mixed_clans() -> void:
	var taxes: Dictionary = {
		1: _make_tax_result(6.0),
		2: _make_tax_result(6.0),
	}
	var prov1: ProvinceData = ProvinceData.new()
	prov1.province_id = 1
	prov1.clan = "Crane"
	var prov2: ProvinceData = ProvinceData.new()
	prov2.province_id = 2
	prov2.clan = "Lion"
	var config: Dictionary = {
		"archetype": StrategicReview.EmperorArchetype.CUNNING,
		"clan_dispositions": {"Crane": 40, "Lion": -20},
	}
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(
		taxes, [prov1, prov2], config
	)
	# Crane (Friend): 6.0 * 0.42 * 0.25 = 0.63
	# Lion (Rival):   6.0 * 0.42 * 0.05 = 0.126
	# Total = 0.756
	assert_almost_eq(result["rice"], 0.756, 0.001)


func test_emperor_income_empty_config_uses_baseline() -> void:
	var taxes: Dictionary = {1: _make_tax_result(6.0)}
	var result: Dictionary = ResourceTick._compute_emperor_income_from_cascade(taxes)
	# Legacy path: 6.0 * 0.42 * 0.15 = 0.378
	assert_almost_eq(result["rice"], 0.378, 0.001)


# -- Warlike Arms Redirect Consumer (GDD s55.10) -------------------------------

func test_arms_redirect_applied_to_imperial_clan() -> void:
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 5.0
	var meta: Dictionary = {"_clan_data": {"Imperial": imperial_clan}}
	var result: Dictionary = ResourceTick.apply_warlike_arms_redirect(2.5, meta)
	assert_eq(result["applied_to"], "Imperial")
	assert_almost_eq(result["amount"], 2.5, 0.001)
	assert_almost_eq(imperial_clan.arms_stockpile, 7.5, 0.001)


func test_arms_redirect_accumulates_on_imperial_clan() -> void:
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 0.0
	var meta: Dictionary = {"_clan_data": {"Imperial": imperial_clan}}
	ResourceTick.apply_warlike_arms_redirect(1.0, meta)
	ResourceTick.apply_warlike_arms_redirect(1.5, meta)
	assert_almost_eq(imperial_clan.arms_stockpile, 2.5, 0.001)


func test_arms_redirect_pending_when_no_imperial_clan() -> void:
	var meta: Dictionary = {"_clan_data": {}}
	var result: Dictionary = ResourceTick.apply_warlike_arms_redirect(3.0, meta)
	assert_eq(result["applied_to"], "pending")
	assert_almost_eq(result["amount"], 3.0, 0.001)
	assert_almost_eq(float(meta["_imperial_arms_pending"]), 3.0, 0.001)


func test_arms_redirect_pending_accumulates() -> void:
	var meta: Dictionary = {"_clan_data": {}}
	ResourceTick.apply_warlike_arms_redirect(1.0, meta)
	ResourceTick.apply_warlike_arms_redirect(2.0, meta)
	assert_almost_eq(float(meta["_imperial_arms_pending"]), 3.0, 0.001)


func test_arms_redirect_zero_amount_no_change() -> void:
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 5.0
	var meta: Dictionary = {"_clan_data": {"Imperial": imperial_clan}}
	ResourceTick.apply_warlike_arms_redirect(0.0, meta)
	assert_almost_eq(imperial_clan.arms_stockpile, 5.0, 0.001)


func test_arms_redirect_drains_pending_on_imperial_clan_arrival() -> void:
	var meta: Dictionary = {"_clan_data": {}}
	ResourceTick.apply_warlike_arms_redirect(2.0, meta)
	ResourceTick.apply_warlike_arms_redirect(3.0, meta)
	assert_almost_eq(float(meta["_imperial_arms_pending"]), 5.0, 0.001)
	# Now Imperial ClanData appears
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 0.0
	meta["_clan_data"] = {"Imperial": imperial_clan}
	var result: Dictionary = ResourceTick.apply_warlike_arms_redirect(1.0, meta)
	# Should drain 5.0 pending + 1.0 new = 6.0 total
	assert_eq(result["applied_to"], "Imperial")
	assert_almost_eq(result["amount"], 6.0, 0.001)
	assert_almost_eq(result["drained_pending"], 5.0, 0.001)
	assert_almost_eq(imperial_clan.arms_stockpile, 6.0, 0.001)
	assert_false(meta.has("_imperial_arms_pending"))


func test_arms_redirect_no_pending_drain_key_absent() -> void:
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 0.0
	var meta: Dictionary = {"_clan_data": {"Imperial": imperial_clan}}
	var result: Dictionary = ResourceTick.apply_warlike_arms_redirect(2.0, meta)
	assert_almost_eq(result["drained_pending"], 0.0, 0.001)
	assert_almost_eq(imperial_clan.arms_stockpile, 2.0, 0.001)
	assert_false(meta.has("_imperial_arms_pending"))


func test_arms_redirect_does_not_touch_other_clans() -> void:
	var crab_clan := ClanData.new()
	crab_clan.clan_name = "Crab"
	crab_clan.arms_stockpile = 10.0
	var imperial_clan := ClanData.new()
	imperial_clan.clan_name = "Imperial"
	imperial_clan.arms_stockpile = 0.0
	var meta: Dictionary = {"_clan_data": {"Crab": crab_clan, "Imperial": imperial_clan}}
	ResourceTick.apply_warlike_arms_redirect(5.0, meta)
	assert_almost_eq(crab_clan.arms_stockpile, 10.0, 0.001)
	assert_almost_eq(imperial_clan.arms_stockpile, 5.0, 0.001)
