extends GutTest


var _province: ProvinceData
var _settlement: SettlementData


func before_each() -> void:
	_province = ProvinceData.new()
	_province.province_id = 1
	_province.province_name = "Test Province"
	_province.terrain_type = Enums.TerrainType.PLAINS
	_province.farming_pu = 4
	_province.mining_pu = 1
	_province.town_pu = 2
	_province.military_pu = 1
	_province.population_pu = 8

	_settlement = SettlementData.new()
	_settlement.settlement_id = 10
	_settlement.province_id = 1
	_settlement.population_pu = 8
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
	# 4 farming PU × 1.50 × 1.0 (plains) = 6.0
	var meta: Dictionary = {1: {"locked_farming_pu": 4}, "_settlements": _settlements()}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, meta)
	assert_almost_eq(result[1]["yield"], 6.0, 0.01)


func test_harvest_river_delta() -> void:
	_province.terrain_type = Enums.TerrainType.RIVER_DELTA
	var meta: Dictionary = {1: {"locked_farming_pu": 4}, "_settlements": _settlements()}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, meta)
	# 4 × 1.50 × 1.5 = 9.0
	assert_almost_eq(result[1]["yield"], 9.0, 0.01)


func test_harvest_mountains() -> void:
	_province.terrain_type = Enums.TerrainType.MOUNTAINS
	var meta: Dictionary = {1: {"locked_farming_pu": 4}, "_settlements": _settlements()}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, meta)
	# 4 × 1.50 × 0.5 = 3.0
	assert_almost_eq(result[1]["yield"], 3.0, 0.01)


func test_harvest_adds_to_settlement_stockpile() -> void:
	var old_stock: float = _settlement.rice_stockpile
	var meta: Dictionary = {1: {"locked_farming_pu": 4}, "_settlements": _settlements()}
	var provinces: Array[ProvinceData] = [_province]
	ResourceTick._process_harvest(provinces, meta)
	assert_almost_eq(_settlement.rice_stockpile, old_stock + 6.0, 0.01)


func test_harvest_levy_reduces_yield() -> void:
	# Only 2 PU planted in spring (2 levied)
	var meta: Dictionary = {1: {"locked_farming_pu": 2}, "_settlements": _settlements()}
	var provinces: Array[ProvinceData] = [_province]
	var result: Dictionary = ResourceTick._process_harvest(provinces, meta)
	# 2 × 1.50 × 1.0 = 3.0
	assert_almost_eq(result[1]["yield"], 3.0, 0.01)


# -- Starvation ----------------------------------------------------------------

func test_starvation_clear_when_no_deficit() -> void:
	var result: Dictionary = ResourceTick.check_starvation(_province, 0.0, 0, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.CLEAR)


func test_starvation_shortage_first_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(_province, 1.0, 1, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.SHORTAGE)
	assert_almost_eq(result["pu_loss_rate"], 0.03, 0.001)


func test_starvation_hunger_second_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(_province, 1.0, 2, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.HUNGER)
	assert_almost_eq(result["pu_loss_rate"], 0.08, 0.001)


func test_starvation_famine_third_season() -> void:
	var result: Dictionary = ResourceTick.check_starvation(_province, 1.0, 3, 5.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.FAMINE)
	assert_almost_eq(result["pu_loss_rate"], 0.20, 0.001)


func test_starvation_instant_famine_on_zero_stockpile() -> void:
	var result: Dictionary = ResourceTick.check_starvation(_province, 1.0, 1, 0.0)
	assert_eq(result["stage"], ResourceTick.StarvationStage.FAMINE)


# -- Tax Cascade ---------------------------------------------------------------

func test_taxable_surplus_basic() -> void:
	# 8 PU, yield 6.0 -> subsistence 8.0 -> surplus = max(0, 6.0-8.0) = 0
	var surplus: float = ResourceTick.compute_taxable_surplus(_province, 6.0)
	assert_almost_eq(surplus, 0.0, 0.01)


func test_taxable_surplus_with_excess() -> void:
	_province.population_pu = 2
	var surplus: float = ResourceTick.compute_taxable_surplus(_province, 6.0)
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
	var result: Dictionary = ResourceTick.produce_iron_province(_province, 1.0)
	# 1 mining PU × 0.50 × 1.0 = 0.50
	assert_almost_eq(result["iron_produced"], 0.50, 0.01)


func test_iron_production_rich_vein() -> void:
	var result: Dictionary = ResourceTick.produce_iron_province(_province, 1.5)
	# 1 × 0.50 × 1.5 = 0.75
	assert_almost_eq(result["iron_produced"], 0.75, 0.01)


func test_iron_returns_produced_amount() -> void:
	var result: Dictionary = ResourceTick.produce_iron_province(_province, 1.0)
	assert_almost_eq(result["iron_produced"], 0.50, 0.01)


# -- Koku Generation -----------------------------------------------------------

func test_koku_generation_baseline() -> void:
	var result: Dictionary = ResourceTick.generate_koku_province(_province, _settlements(), 1.0)
	# 2 town PU × 0.25 × 1.0 = 0.50
	assert_almost_eq(result["koku_generated"], 0.50, 0.01)


func test_koku_generation_port_city() -> void:
	var result: Dictionary = ResourceTick.generate_koku_province(_province, _settlements(), 1.5)
	# 2 × 0.25 × 1.5 = 0.75
	assert_almost_eq(result["koku_generated"], 0.75, 0.01)


func test_koku_adds_to_settlement_stockpile() -> void:
	ResourceTick.generate_koku_province(_province, _settlements(), 1.0)
	assert_almost_eq(_settlement.koku_stockpile, 2.50, 0.01)


# -- Population Growth ---------------------------------------------------------

func test_growth_rate_baseline() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		_province, ResourceTick.StarvationStage.CLEAR, 0, 5.0
	)
	# 5% annual / 4 = 1.25%
	assert_almost_eq(rate, 0.0125, 0.001)


func test_growth_rate_with_peace_bonus() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		_province, ResourceTick.StarvationStage.CLEAR, 4, 5.0
	)
	# (5% + 3%) / 4 = 2%
	assert_almost_eq(rate, 0.02, 0.001)


func test_growth_rate_strong_stockpile() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		_province, ResourceTick.StarvationStage.CLEAR, 0, 20.0
	)
	# 20/8 = 2.5 per PU > 2.0 threshold → 10% annual / 4 = 2.5%
	assert_almost_eq(rate, 0.025, 0.001)


func test_growth_rate_zero_during_starvation() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		_province, ResourceTick.StarvationStage.SHORTAGE, 0, 5.0
	)
	assert_eq(rate, 0.0)


func test_growth_max_rate() -> void:
	var rate: float = ResourceTick.compute_growth_rate(
		_province, ResourceTick.StarvationStage.CLEAR, 5, 20.0
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
