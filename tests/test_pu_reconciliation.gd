extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_settlement(
	id: int,
	province_id: int,
	pop: int = 10,
	military: int = 2,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.population_pu = pop
	s.military_pu = military
	s.farming_pu = pop - military
	return s


func _make_battle_company(
	company_id: int,
	starting_health: int = 153,
	current_health: int = 80,
	source_province_id: int = 1,
) -> Dictionary:
	return {
		"company_id": company_id,
		"starting_health": starting_health,
		"current_health": current_health,
		"source_province_id": source_province_id,
	}


# -- Constants -------------------------------------------------------------------

func test_health_to_pu_ratio() -> void:
	assert_almost_eq(PUReconciliation.HEALTH_TO_PU, 1.0 / 153.0, 0.0001)


func test_recovery_rates_sum_to_one() -> void:
	var total: float = (
		PUReconciliation.RECOVERY_RATE
		+ PUReconciliation.RETURN_RATE
		+ PUReconciliation.DEAD_RATE
	)
	assert_almost_eq(total, 1.0, 0.001)


# -- Levy Consumption Tests ------------------------------------------------------

func test_consume_levy_pu() -> void:
	var s: SettlementData = _make_settlement(1, 1, 10, 2)
	var r: Dictionary = PUReconciliation.consume_levy_pu(s)
	assert_eq(r["pu_consumed"], 1)
	assert_eq(s.military_pu, 1)
	assert_eq(s.population_pu, 9)


func test_consume_levy_pu_multiple() -> void:
	var s: SettlementData = _make_settlement(1, 1, 10, 3)
	var r: Dictionary = PUReconciliation.consume_levy_pu(s, 2)
	assert_eq(r["pu_consumed"], 2)
	assert_eq(s.military_pu, 1)
	assert_eq(s.population_pu, 8)


func test_consume_levy_pu_capped_at_available() -> void:
	var s: SettlementData = _make_settlement(1, 1, 10, 1)
	var r: Dictionary = PUReconciliation.consume_levy_pu(s, 3)
	assert_eq(r["pu_consumed"], 1)
	assert_eq(s.military_pu, 0)


func test_consume_levy_pu_zero_military() -> void:
	var s: SettlementData = _make_settlement(1, 1, 10, 0)
	var r: Dictionary = PUReconciliation.consume_levy_pu(s, 1)
	assert_eq(r["pu_consumed"], 0)
	assert_eq(s.population_pu, 10)


# -- Disband Return Tests -------------------------------------------------------

func test_return_disband_full_health() -> void:
	var s: SettlementData = _make_settlement(1, 1, 9, 1)
	var r: Dictionary = PUReconciliation.return_disband_pu(s, 153)
	assert_eq(r["pu_returned"], 1)
	assert_eq(s.military_pu, 2)
	assert_eq(s.population_pu, 10)


func test_return_disband_half_health() -> void:
	var s: SettlementData = _make_settlement(1, 1, 9, 1)
	var r: Dictionary = PUReconciliation.return_disband_pu(s, 76)
	# 76/153 = 0.497 → floor = 0
	assert_eq(r["pu_returned"], 0)
	assert_eq(s.military_pu, 1)


func test_return_disband_zero_health() -> void:
	var s: SettlementData = _make_settlement(1, 1, 9, 1)
	var r: Dictionary = PUReconciliation.return_disband_pu(s, 0)
	assert_eq(r["pu_returned"], 0)


func test_return_disband_near_full() -> void:
	var s: SettlementData = _make_settlement(1, 1, 9, 1)
	var r: Dictionary = PUReconciliation.return_disband_pu(s, 150)
	# 150/153 = 0.98 → floor = 0 (still under 1.0 PU)
	assert_eq(r["pu_returned"], 0)


# -- Company PU Loss Calculation -------------------------------------------------

func test_compute_company_pu_loss() -> void:
	var loss: float = PUReconciliation.compute_company_pu_loss(153, 80)
	# 73 * (1/153) = 0.477
	assert_almost_eq(loss, 73.0 / 153.0, 0.01)


func test_compute_company_pu_loss_no_damage() -> void:
	var loss: float = PUReconciliation.compute_company_pu_loss(153, 153)
	assert_almost_eq(loss, 0.0, 0.001)


func test_compute_company_pu_loss_destroyed() -> void:
	var loss: float = PUReconciliation.compute_company_pu_loss(153, 0)
	assert_almost_eq(loss, 1.0, 0.01)


# -- Battle Casualty Processing --------------------------------------------------

func test_process_battle_casualties_single_company() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 80, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements_by_province: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_battle_casualties(
		companies, settlements_by_province,
	)
	assert_true(r["total_dead_pu"] > 0.0)
	assert_almost_eq(r["ronin_losses_pu"], 0.0, 0.001)


func test_process_battle_casualties_multiple_provinces() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 80, 1),
		_make_battle_company(2, 153, 50, 2),
	]
	var s1: SettlementData = _make_settlement(10, 1, 10, 2)
	var s2: SettlementData = _make_settlement(20, 2, 10, 2)
	var settlements: Dictionary = {1: [s1], 2: [s2]}
	var r: Dictionary = PUReconciliation.process_battle_casualties(
		companies, settlements,
	)
	assert_true(r["pu_losses_by_province"].has(1))
	assert_true(r["pu_losses_by_province"].has(2))


func test_process_battle_casualties_ronin_no_pu_exchange() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 80, -1),
	]
	var r: Dictionary = PUReconciliation.process_battle_casualties(companies, {})
	assert_true(r["ronin_losses_pu"] > 0.0)
	assert_almost_eq(r["total_dead_pu"], 0.0, 0.001)
	assert_eq(r["settlement_mutations"].size(), 0)


func test_process_battle_casualties_no_damage_no_loss() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 153, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_battle_casualties(
		companies, settlements,
	)
	assert_almost_eq(r["total_dead_pu"], 0.0, 0.001)


func test_process_battle_casualties_destroyed_company() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 0, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_battle_casualties(
		companies, settlements,
	)
	# Full company loss = 1.0 PU
	assert_almost_eq(r["total_dead_pu"], 1.0, 0.01)


func test_process_battle_casualties_mutates_settlement() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 0, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	PUReconciliation.process_battle_casualties(companies, settlements)
	assert_eq(s.military_pu, 1)
	assert_eq(s.population_pu, 9)


# -- Victor Recovery Tests -------------------------------------------------------

func test_victor_recovery_splits_correctly() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 53, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_victor_recovery(
		companies, settlements,
	)
	# 100 health lost
	assert_eq(r["total_health_lost"], 100)
	assert_eq(r["recovered_to_companies"], 10)
	assert_eq(r["returned_as_pu_health"], 10)
	assert_eq(r["permanently_dead_health"], 80)


func test_victor_recovery_no_losses() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 153, 1),
	]
	var r: Dictionary = PUReconciliation.process_victor_recovery(companies, {})
	assert_eq(r["total_health_lost"], 0)
	assert_eq(r["recovered_to_companies"], 0)
	assert_eq(r["returned_as_pu_health"], 0)


func test_victor_recovery_ronin_no_pu_return() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 53, -1),
	]
	var r: Dictionary = PUReconciliation.process_victor_recovery(companies, {})
	assert_eq(r["total_health_lost"], 100)
	assert_eq(r["recovered_to_companies"], 10)
	assert_almost_eq(r["total_returned_pu"], 0.0, 0.001)


func test_victor_recovery_multiple_companies_same_province() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 100, 1),
		_make_battle_company(2, 153, 100, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_victor_recovery(
		companies, settlements,
	)
	# Each lost 53 health, total 106
	assert_eq(r["total_health_lost"], 106)
	assert_true(r["returned_pu_by_province"].has(1))


# -- Full Battle Reconciliation --------------------------------------------------

func test_reconcile_battle_produces_both() -> void:
	var victors: Array = [
		_make_battle_company(1, 153, 100, 1),
	]
	var losers: Array = [
		_make_battle_company(2, 153, 50, 2),
	]
	var s1: SettlementData = _make_settlement(10, 1, 10, 2)
	var s2: SettlementData = _make_settlement(20, 2, 10, 2)
	var settlements: Dictionary = {1: [s1], 2: [s2]}
	var r: Dictionary = PUReconciliation.reconcile_battle(
		victors, losers, settlements,
	)
	assert_true(r.has("casualties"))
	assert_true(r.has("recovery"))


# -- Army Dissolution Tests ------------------------------------------------------

func test_process_army_dissolution() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 30, 1),
		_make_battle_company(2, 153, 20, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_army_dissolution(
		companies, settlements,
	)
	assert_true(r["total_returned_pu"] > 0.0)


func test_dissolution_ronin_no_return() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 50, -1),
	]
	var r: Dictionary = PUReconciliation.process_army_dissolution(companies, {})
	assert_true(r["ronin_lost_pu"] > 0.0)
	assert_almost_eq(r["total_returned_pu"], 0.0, 0.001)


func test_dissolution_dead_companies_return_nothing() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 0, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 2)
	var settlements: Dictionary = {1: [s]}
	var r: Dictionary = PUReconciliation.process_army_dissolution(
		companies, settlements,
	)
	assert_almost_eq(r["total_returned_pu"], 0.0, 0.001)
	assert_eq(s.population_pu, 10)


func test_dissolution_returns_survivors() -> void:
	var companies: Array = [
		_make_battle_company(1, 153, 153, 1),
	]
	var s: SettlementData = _make_settlement(10, 1, 8, 1)
	var settlements: Dictionary = {1: [s]}
	PUReconciliation.process_army_dissolution(companies, settlements)
	# 153/153 * 1.0 = 1.0 PU → floor = 1
	assert_eq(s.military_pu, 2)
	assert_eq(s.population_pu, 9)


# -- PU Distribution Helpers -----------------------------------------------------

func test_loss_distributed_to_military_first() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array = [
		_make_battle_company(1, 153, 0, 1),
		_make_battle_company(2, 153, 0, 1),
	]
	var settlements: Dictionary = {1: [s]}
	PUReconciliation.process_battle_casualties(companies, settlements)
	# 2 companies destroyed = 2 PU loss, deducted from military_pu first
	assert_eq(s.military_pu, 1)
	assert_eq(s.population_pu, 8)


func test_loss_overflows_to_general_population() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 1)
	var companies: Array = [
		_make_battle_company(1, 153, 0, 1),
		_make_battle_company(2, 153, 0, 1),
	]
	var settlements: Dictionary = {1: [s]}
	PUReconciliation.process_battle_casualties(companies, settlements)
	# 2 PU loss: 1 from military, 1 from general pop
	assert_eq(s.military_pu, 0)
	assert_eq(s.population_pu, 8)
