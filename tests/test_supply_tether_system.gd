extends GutTest


# -- Helpers ---------------------------------------------------------------------

var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


func _make_tether(
	path: Array[int] = [10, 20, 30],
	army_id: int = 1,
	source_id: int = 100,
) -> Dictionary:
	var typed_path: Array[int] = []
	typed_path.assign(path)
	return SupplyTetherSystem.create_tether(army_id, source_id, typed_path)


func _make_company(
	id: int,
	unit_type: Enums.CompanyUnitType = Enums.CompanyUnitType.BUSHI_RETAINER,
) -> MilitaryUnitData.CompanyData:
	return ArmyCombatSystem.create_company(id, unit_type)


# -- Create Tether Tests --------------------------------------------------------

func test_create_tether_structure() -> void:
	var t: Dictionary = _make_tether()
	assert_eq(t["army_id"], 1)
	assert_eq(t["source_province_id"], 100)
	assert_eq(t["sub_tile_path"].size(), 3)
	assert_eq(t["overall_state"], SupplyTetherSystem.TetherState.SOLID)
	assert_eq(t["rice_deprivation_tick"], 0)
	assert_eq(t["arms_deprivation_tick"], 0)


func test_create_tether_node_states() -> void:
	var t: Dictionary = _make_tether()
	for tile_id: int in [10, 20, 30]:
		assert_true(t["node_states"].has(tile_id))
		var node: Dictionary = t["node_states"][tile_id]
		assert_eq(node["state"], SupplyTetherSystem.TetherState.SOLID)
		assert_eq(node["escort_company_id"], -1)
		assert_eq(node["escort_returning"], false)


# -- Garrison Attack Tests -------------------------------------------------------

func test_garrison_attack_standard_pu() -> void:
	assert_eq(SupplyTetherSystem.compute_garrison_attack(1.0), 3)


func test_garrison_attack_half_pu() -> void:
	assert_eq(SupplyTetherSystem.compute_garrison_attack(0.5), 2)


func test_garrison_attack_double_pu() -> void:
	assert_eq(SupplyTetherSystem.compute_garrison_attack(2.0), 5)


func test_garrison_attack_1_5_pu() -> void:
	assert_eq(SupplyTetherSystem.compute_garrison_attack(1.5), 4)


func test_garrison_attack_floor_at_zero() -> void:
	assert_eq(SupplyTetherSystem.compute_garrison_attack(0.0), 1)


# -- Raid TN Tests ---------------------------------------------------------------

func test_raid_tn_unescorted() -> void:
	assert_eq(SupplyTetherSystem.compute_raid_tn(0), 5)


func test_raid_tn_with_escort() -> void:
	assert_eq(SupplyTetherSystem.compute_raid_tn(4), 9)


func test_raid_tn_bushi_escort() -> void:
	assert_eq(SupplyTetherSystem.compute_raid_tn(5), 10)


# -- Raid Resolution Tests -------------------------------------------------------

func test_raid_fail_below_tn() -> void:
	var dice: DiceEngine = DiceEngine.new(1)
	# Try to get a low roll
	var found_fail: bool = false
	for i: int in 100:
		dice.set_seed(i)
		var r: Dictionary = SupplyTetherSystem.resolve_garrison_raid(dice, 0.5, 5)
		if r["result"] == SupplyTetherSystem.TetherState.SOLID:
			found_fail = true
			assert_true(r["margin"] < 0)
			break
	assert_true(found_fail, "Should find at least one raid failure in 100 seeds")


func test_raid_partial_at_tn() -> void:
	var found_partial: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SupplyTetherSystem.resolve_garrison_raid(_dice, 1.0, 0)
		if r["result"] == SupplyTetherSystem.TetherState.THREATENED:
			found_partial = true
			assert_true(r["margin"] >= 0)
			assert_true(r["margin"] < 5)
			break
	assert_true(found_partial, "Should find at least one partial raid in 100 seeds")


func test_raid_full_cut_high_margin() -> void:
	var found_cut: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SupplyTetherSystem.resolve_garrison_raid(_dice, 2.0, 0)
		if r["result"] == SupplyTetherSystem.TetherState.BROKEN:
			found_cut = true
			assert_true(r["margin"] >= 5)
			break
	assert_true(found_cut, "Should find at least one full cut in 100 seeds")


# -- Tether Tick Tests -----------------------------------------------------------

func test_tether_tick_no_threats() -> void:
	var t: Dictionary = _make_tether()
	var garrisons: Dictionary = {}
	var enemies: Array[int] = []
	var companies: Dictionary = {}
	var r: Dictionary = SupplyTetherSystem.process_tether_tick(
		_dice, t, garrisons, enemies, companies,
	)
	assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.SOLID)
	assert_eq(r["partial_count"], 0)


func test_tether_tick_enemy_army_cuts() -> void:
	var t: Dictionary = _make_tether()
	var enemies: Array[int] = [20]
	var r: Dictionary = SupplyTetherSystem.process_tether_tick(
		_dice, t, {}, enemies, {},
	)
	assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.BROKEN)
	assert_eq(t["node_states"][20]["state"], SupplyTetherSystem.TetherState.BROKEN)


func test_tether_tick_two_partials_stack_to_broken() -> void:
	var t: Dictionary = _make_tether([10, 20, 30])
	var garrisons: Dictionary = {10: 1.0, 20: 1.0}
	# We need both garrisons to get partial results
	# Force by using high escort defense on tile 30 (no garrison there)
	# and seed to get partials on 10, 20
	var found: bool = false
	for i: int in 200:
		_dice.set_seed(i)
		var fresh: Dictionary = _make_tether([10, 20, 30])
		var r: Dictionary = SupplyTetherSystem.process_tether_tick(
			_dice, fresh, garrisons, [], {},
		)
		if r["partial_count"] >= 2:
			assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.BROKEN)
			found = true
			break
	assert_true(found, "Should find two partials stacking to broken")


func test_tether_tick_single_partial() -> void:
	var t: Dictionary = _make_tether([10, 20])
	var garrisons: Dictionary = {10: 1.0}
	var found: bool = false
	for i: int in 200:
		_dice.set_seed(i)
		var fresh: Dictionary = _make_tether([10, 20])
		var r: Dictionary = SupplyTetherSystem.process_tether_tick(
			_dice, fresh, garrisons, [], {},
		)
		if r["partial_count"] == 1 and r["overall_state"] == SupplyTetherSystem.TetherState.THREATENED:
			found = true
			break
	assert_true(found, "Should find single partial = threatened")


# -- Supply Fraction Tests -------------------------------------------------------

func test_supply_fraction_solid() -> void:
	assert_almost_eq(
		SupplyTetherSystem.compute_supply_fraction(SupplyTetherSystem.TetherState.SOLID),
		1.0, 0.001,
	)


func test_supply_fraction_threatened() -> void:
	assert_almost_eq(
		SupplyTetherSystem.compute_supply_fraction(SupplyTetherSystem.TetherState.THREATENED),
		0.5, 0.001,
	)


func test_supply_fraction_broken() -> void:
	assert_almost_eq(
		SupplyTetherSystem.compute_supply_fraction(SupplyTetherSystem.TetherState.BROKEN),
		0.0, 0.001,
	)


# -- Friendly Territory Tests ---------------------------------------------------

func test_in_friendly_territory() -> void:
	var friendly: Array[int] = [1, 2, 3]
	assert_true(SupplyTetherSystem.is_in_friendly_territory(2, friendly))


func test_not_in_friendly_territory() -> void:
	var friendly: Array[int] = [1, 2, 3]
	assert_false(SupplyTetherSystem.is_in_friendly_territory(5, friendly))


# -- Escort Tests ----------------------------------------------------------------

func test_assign_escort() -> void:
	var t: Dictionary = _make_tether()
	var r: Dictionary = SupplyTetherSystem.assign_escort(t, 20, 5)
	assert_true(r["success"])
	assert_eq(t["node_states"][20]["escort_company_id"], 5)


func test_assign_escort_invalid_tile() -> void:
	var t: Dictionary = _make_tether()
	var r: Dictionary = SupplyTetherSystem.assign_escort(t, 99, 5)
	assert_false(r["success"])
	assert_eq(r["reason"], "tile_not_on_path")


func test_assign_escort_already_escorted() -> void:
	var t: Dictionary = _make_tether()
	SupplyTetherSystem.assign_escort(t, 20, 5)
	var r: Dictionary = SupplyTetherSystem.assign_escort(t, 20, 6)
	assert_false(r["success"])
	assert_eq(r["reason"], "already_escorted")


func test_recall_escort() -> void:
	var t: Dictionary = _make_tether()
	SupplyTetherSystem.assign_escort(t, 20, 5)
	var r: Dictionary = SupplyTetherSystem.recall_escort(t, 20)
	assert_true(r["success"])
	assert_eq(r["company_id"], 5)
	assert_true(t["node_states"][20]["escort_returning"])
	assert_eq(t["node_states"][20]["escort_return_ticks"], 1)


func test_recall_no_escort() -> void:
	var t: Dictionary = _make_tether()
	var r: Dictionary = SupplyTetherSystem.recall_escort(t, 20)
	assert_false(r["success"])


func test_escort_returning_clears_after_tick() -> void:
	var t: Dictionary = _make_tether([20])
	SupplyTetherSystem.assign_escort(t, 20, 5)
	SupplyTetherSystem.recall_escort(t, 20)
	assert_true(t["node_states"][20]["escort_returning"])
	# Process a tick with no threats — the escort return should complete
	SupplyTetherSystem.process_tether_tick(_dice, t, {}, [], {})
	assert_false(t["node_states"][20]["escort_returning"])
	assert_eq(t["node_states"][20]["escort_company_id"], -1)


func test_escort_defense_used_in_raid() -> void:
	var t: Dictionary = _make_tether([10])
	var company: MilitaryUnitData.CompanyData = _make_company(5)
	company.defense = 6
	SupplyTetherSystem.assign_escort(t, 10, 5)
	var def_val: int = SupplyTetherSystem.get_escort_defense(t, 10, {5: company})
	assert_eq(def_val, 6)


func test_escort_returning_gives_zero_defense() -> void:
	var t: Dictionary = _make_tether([10])
	var company: MilitaryUnitData.CompanyData = _make_company(5)
	company.defense = 6
	SupplyTetherSystem.assign_escort(t, 10, 5)
	SupplyTetherSystem.recall_escort(t, 10)
	var def_val: int = SupplyTetherSystem.get_escort_defense(t, 10, {5: company})
	assert_eq(def_val, 0)


# -- Deprivation Advance Tests --------------------------------------------------

func test_deprivation_advances_on_broken() -> void:
	var t: Dictionary = _make_tether()
	var r: Dictionary = SupplyTetherSystem.advance_deprivation(
		t, SupplyTetherSystem.TetherState.BROKEN,
	)
	assert_eq(r["rice_tick"], 1)
	assert_eq(r["arms_tick"], 1)
	assert_true(r["rice_advanced"])
	assert_true(r["arms_advanced"])


func test_deprivation_half_speed_on_threatened() -> void:
	var t: Dictionary = _make_tether()
	# First threatened tick — accumulator goes to 1, no advance yet
	var r1: Dictionary = SupplyTetherSystem.advance_deprivation(
		t, SupplyTetherSystem.TetherState.THREATENED,
	)
	assert_eq(r1["rice_tick"], 0)
	assert_false(r1["rice_advanced"])
	# Second threatened tick — accumulator hits 2, advances
	var r2: Dictionary = SupplyTetherSystem.advance_deprivation(
		t, SupplyTetherSystem.TetherState.THREATENED,
	)
	assert_eq(r2["rice_tick"], 1)
	assert_true(r2["rice_advanced"])


func test_deprivation_no_advance_on_solid() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 0
	var r: Dictionary = SupplyTetherSystem.advance_deprivation(
		t, SupplyTetherSystem.TetherState.SOLID,
	)
	assert_eq(t["rice_deprivation_tick"], 0)
	assert_false(r.get("rice_advanced", false))


func test_deprivation_accumulator_resets_on_solid() -> void:
	var t: Dictionary = _make_tether()
	# Build up partial accumulator
	SupplyTetherSystem.advance_deprivation(t, SupplyTetherSystem.TetherState.THREATENED)
	assert_eq(t["partial_tick_accumulator_rice"], 1)
	# Solid resets it
	SupplyTetherSystem.advance_deprivation(t, SupplyTetherSystem.TetherState.SOLID)
	assert_eq(t["partial_tick_accumulator_rice"], 0)


func test_deprivation_accumulates_over_multiple_broken_ticks() -> void:
	var t: Dictionary = _make_tether()
	SupplyTetherSystem.advance_deprivation(t, SupplyTetherSystem.TetherState.BROKEN)
	SupplyTetherSystem.advance_deprivation(t, SupplyTetherSystem.TetherState.BROKEN)
	SupplyTetherSystem.advance_deprivation(t, SupplyTetherSystem.TetherState.BROKEN)
	assert_eq(t["rice_deprivation_tick"], 3)
	assert_eq(t["arms_deprivation_tick"], 3)


# -- Step-Down Recovery Tests ----------------------------------------------------

func test_step_down_on_solid() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 3
	t["arms_deprivation_tick"] = 2
	var r: Dictionary = SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.SOLID,
	)
	assert_eq(t["rice_deprivation_tick"], 2)
	assert_eq(t["arms_deprivation_tick"], 1)
	assert_true(r["rice_recovered"])
	assert_true(r["arms_recovered"])


func test_step_down_floors_at_zero() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 1
	SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.SOLID,
	)
	assert_eq(t["rice_deprivation_tick"], 0)
	var r: Dictionary = SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.SOLID,
	)
	assert_eq(t["rice_deprivation_tick"], 0)
	assert_false(r["rice_recovered"])


func test_step_down_half_speed_on_threatened() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 3
	# First tick — accumulator goes to 1
	var r1: Dictionary = SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.THREATENED,
	)
	assert_eq(t["rice_deprivation_tick"], 3)
	assert_false(r1["rice_recovered"])
	# Second tick — accumulator hits 2, recovers one stage
	var r2: Dictionary = SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.THREATENED,
	)
	assert_eq(t["rice_deprivation_tick"], 2)
	assert_true(r2["rice_recovered"])


func test_step_down_no_recovery_on_broken() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 3
	var r: Dictionary = SupplyTetherSystem.process_step_down_recovery(
		t, SupplyTetherSystem.TetherState.BROKEN,
	)
	assert_eq(t["rice_deprivation_tick"], 3)
	assert_false(r["rice_recovered"])


func test_full_recovery_sequence() -> void:
	var t: Dictionary = _make_tether()
	t["rice_deprivation_tick"] = 3
	t["arms_deprivation_tick"] = 3
	# 3 ticks of solid supply should fully recover
	for i: int in 3:
		SupplyTetherSystem.process_step_down_recovery(
			t, SupplyTetherSystem.TetherState.SOLID,
		)
	assert_eq(t["rice_deprivation_tick"], 0)
	assert_eq(t["arms_deprivation_tick"], 0)


# -- Supply Source Tests ---------------------------------------------------------

func test_supply_source_lord_only() -> void:
	var lord: Array[int] = [1, 2, 3]
	var result: Array[int] = SupplyTetherSystem.get_supply_source_provinces(lord, [], [])
	assert_eq(result.size(), 3)
	assert_has(result, 1)
	assert_has(result, 2)
	assert_has(result, 3)


func test_supply_source_with_compelled() -> void:
	var lord: Array[int] = [1, 2]
	var compelled: Array[int] = [3, 4]
	var result: Array[int] = SupplyTetherSystem.get_supply_source_provinces(
		lord, compelled, [],
	)
	assert_eq(result.size(), 4)


func test_supply_source_no_duplicates() -> void:
	var lord: Array[int] = [1, 2]
	var compelled: Array[int] = [2, 3]
	var shared: Array[int] = [3, 4]
	var result: Array[int] = SupplyTetherSystem.get_supply_source_provinces(
		lord, compelled, shared,
	)
	assert_eq(result.size(), 4)


# -- Full Tick Orchestrator Tests ------------------------------------------------

func test_full_tick_solid_no_threats() -> void:
	var t: Dictionary = _make_tether()
	var r: Dictionary = SupplyTetherSystem.process_supply_tick(
		_dice, t, {}, [], {},
	)
	assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.SOLID)
	assert_almost_eq(r["supply_fraction"], 1.0, 0.001)
	assert_eq(r["rice_deprivation_tick"], 0)


func test_full_tick_broken_advances_deprivation() -> void:
	var t: Dictionary = _make_tether([10])
	var enemies: Array[int] = [10]
	var r: Dictionary = SupplyTetherSystem.process_supply_tick(
		_dice, t, {}, enemies, {},
	)
	assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.BROKEN)
	assert_almost_eq(r["supply_fraction"], 0.0, 0.001)
	assert_eq(r["rice_deprivation_tick"], 1)
	assert_eq(r["arms_deprivation_tick"], 1)


func test_full_tick_recovery_when_cleared() -> void:
	var t: Dictionary = _make_tether([10])
	# First: cut the tether
	SupplyTetherSystem.process_supply_tick(_dice, t, {}, [10], {})
	SupplyTetherSystem.process_supply_tick(_dice, t, {}, [10], {})
	assert_eq(t["rice_deprivation_tick"], 2)
	# Now clear the threat
	var r: Dictionary = SupplyTetherSystem.process_supply_tick(_dice, t, {}, [], {})
	assert_eq(r["overall_state"], SupplyTetherSystem.TetherState.SOLID)
	assert_eq(t["rice_deprivation_tick"], 1)


func test_full_tick_multiple_broken_then_recovery() -> void:
	var t: Dictionary = _make_tether([10])
	# 3 ticks of broken
	for i: int in 3:
		SupplyTetherSystem.process_supply_tick(_dice, t, {}, [10], {})
	assert_eq(t["rice_deprivation_tick"], 3)
	# 3 ticks of solid to fully recover
	for i: int in 3:
		SupplyTetherSystem.process_supply_tick(_dice, t, {}, [], {})
	assert_eq(t["rice_deprivation_tick"], 0)
