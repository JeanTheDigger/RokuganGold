extends GutTest
## Tests for MiyaBlessingSystem per GDD s11.5b.


# -- Blessing rate by archetype ----------------------------------------------

func test_benevolent_blessing_rate_is_20_percent() -> void:
	assert_eq(
		MiyaBlessingSystem.compute_blessing_rate(StrategicReview.EmperorArchetype.BENEVOLENT),
		0.20,
	)


func test_iron_blessing_rate_is_15_percent() -> void:
	assert_eq(
		MiyaBlessingSystem.compute_blessing_rate(StrategicReview.EmperorArchetype.IRON),
		0.15,
	)


func test_cunning_blessing_rate_is_10_percent() -> void:
	assert_eq(
		MiyaBlessingSystem.compute_blessing_rate(StrategicReview.EmperorArchetype.CUNNING),
		0.10,
	)


func test_warlike_blessing_rate_is_5_percent() -> void:
	assert_eq(
		MiyaBlessingSystem.compute_blessing_rate(StrategicReview.EmperorArchetype.WARLIKE),
		0.05,
	)


func test_tyrant_blessing_rate_is_zero() -> void:
	assert_eq(
		MiyaBlessingSystem.compute_blessing_rate(StrategicReview.EmperorArchetype.TYRANT),
		0.0,
	)


# -- Allocation calculation --------------------------------------------------

func test_gdd_example_yields_1_80_rice() -> void:
	# GDD §2.1 example: Emperor collected 12.0 Rice last Autumn at 15% rate.
	# Plenty of stockpile, modest reserve floor → full 1.80 allocation.
	var alloc: float = MiyaBlessingSystem.compute_allocation(12.0, 0.15, 100.0, 50.0)
	assert_almost_eq(alloc, 1.80, 0.001)


func test_allocation_capped_at_max_total() -> void:
	# Massive tax income would compute to 30 Rice; capped at 15.0 (5.0 × 3).
	var alloc: float = MiyaBlessingSystem.compute_allocation(200.0, 0.15, 1000.0, 0.0)
	assert_eq(alloc, MiyaBlessingSystem.MAX_TOTAL)


func test_allocation_constrained_by_imperial_reserve() -> void:
	# Reserve floor = OU_PU * 0.25 = 100 * 0.25 = 25.0.
	# Stockpile 28 - 25 = 3 available. Raw allocation 12*0.15 = 1.8.
	# 1.8 < 3.0, so we get the full 1.8.
	var alloc: float = MiyaBlessingSystem.compute_allocation(12.0, 0.15, 28.0, 100.0)
	assert_almost_eq(alloc, 1.80, 0.001)


func test_allocation_clamped_to_available_after_reserve() -> void:
	# Reserve floor = 25. Stockpile 26 → 1.0 available. Raw alloc 1.8 → clamped to 1.0.
	var alloc: float = MiyaBlessingSystem.compute_allocation(12.0, 0.15, 26.0, 100.0)
	assert_almost_eq(alloc, 1.00, 0.001)


func test_allocation_zero_when_stockpile_below_reserve() -> void:
	# Reserve floor = 25. Stockpile 20 → 0 available. Allocation 0.
	var alloc: float = MiyaBlessingSystem.compute_allocation(12.0, 0.15, 20.0, 100.0)
	assert_eq(alloc, 0.0)


func test_allocation_zero_when_tax_income_zero() -> void:
	var alloc: float = MiyaBlessingSystem.compute_allocation(0.0, 0.15, 100.0, 0.0)
	assert_eq(alloc, 0.0)


# -- Suspension threshold ----------------------------------------------------

func test_below_threshold_is_suspended() -> void:
	assert_true(MiyaBlessingSystem.is_suspended(0.49))


func test_at_threshold_not_suspended() -> void:
	assert_false(MiyaBlessingSystem.is_suspended(0.50))


func test_above_threshold_not_suspended() -> void:
	assert_false(MiyaBlessingSystem.is_suspended(2.0))


# -- Need score components ---------------------------------------------------

func test_starvation_score_shortage_5() -> void:
	assert_eq(
		MiyaBlessingSystem.get_starvation_need(ResourceTick.StarvationStage.SHORTAGE),
		5,
	)


func test_starvation_score_hunger_10() -> void:
	assert_eq(
		MiyaBlessingSystem.get_starvation_need(ResourceTick.StarvationStage.HUNGER),
		10,
	)


func test_starvation_score_famine_20() -> void:
	assert_eq(
		MiyaBlessingSystem.get_starvation_need(ResourceTick.StarvationStage.FAMINE),
		20,
	)


func test_starvation_score_clear_zero() -> void:
	assert_eq(
		MiyaBlessingSystem.get_starvation_need(ResourceTick.StarvationStage.CLEAR),
		0,
	)


func test_stability_score_brackets() -> void:
	assert_eq(MiyaBlessingSystem.get_stability_need(100.0), 0)
	assert_eq(MiyaBlessingSystem.get_stability_need(80.0), 0)
	assert_eq(MiyaBlessingSystem.get_stability_need(75.0), 2)
	assert_eq(MiyaBlessingSystem.get_stability_need(60.0), 2)
	assert_eq(MiyaBlessingSystem.get_stability_need(50.0), 5)
	assert_eq(MiyaBlessingSystem.get_stability_need(30.0), 5)
	assert_eq(MiyaBlessingSystem.get_stability_need(25.0), 10)
	assert_eq(MiyaBlessingSystem.get_stability_need(0.0), 10)


func test_pu_decline_score_brackets() -> void:
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.0), 0)
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.05), 0)
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.10), 5)
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.20), 5)
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.25), 10)
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.50), 10)


func test_pu_decline_25_replaces_10() -> void:
	# GDD §4.1: "+10 (replaces the +5)" — verify we don't double-count.
	assert_eq(MiyaBlessingSystem.get_pu_decline_need(0.30), 10)


# -- Need score composition --------------------------------------------------

func test_need_score_stable_province_with_no_problems() -> void:
	var conditions: Dictionary = {
		"stability": 90.0,
		"worst_starvation_stage": ResourceTick.StarvationStage.CLEAR,
		"blessed_two_years_ago": false,
		"blessed_last_year": false,
	}
	# Eligible for the +2 rotation bonus (no recent Blessing).
	assert_eq(MiyaBlessingSystem.compute_need_score(conditions), 2)


func test_need_score_famine_volatile_war_raid() -> void:
	# Province at Famine (+20), Volatile (+5), war (+5), raid (+3),
	# insurgency (+3), 18% PU decline (+5), not blessed last year (+2).
	# Total: 43.
	var conditions: Dictionary = {
		"stability": 30.0,
		"worst_starvation_stage": ResourceTick.StarvationStage.FAMINE,
		"had_active_war": true,
		"had_raid": true,
		"has_insurgency": true,
		"pu_decline_pct": 0.18,
		"blessed_last_year": false,
		"blessed_two_years_ago": false,
	}
	assert_eq(MiyaBlessingSystem.compute_need_score(conditions), 43)


func test_need_score_blessed_last_year_applies_minus_5_malus() -> void:
	# Province at Hunger (+10), Restless (+2), blessed last year (-5).
	# Total: 7.
	var conditions: Dictionary = {
		"stability": 60.0,
		"worst_starvation_stage": ResourceTick.StarvationStage.HUNGER,
		"blessed_last_year": true,
	}
	assert_eq(MiyaBlessingSystem.compute_need_score(conditions), 7)


func test_need_score_blessed_two_years_ago_still_gets_rotation_bonus() -> void:
	# Not blessed last year → always gets the +2 rotation bonus per GDD.
	var conditions: Dictionary = {
		"stability": 80.0,
		"blessed_last_year": false,
		"blessed_two_years_ago": true,
	}
	assert_eq(MiyaBlessingSystem.compute_need_score(conditions), 2)


func test_need_score_includes_petition_bonus() -> void:
	var conditions: Dictionary = {
		"stability": 90.0,
		"blessed_last_year": false,
		"petition_bonus": 12,   # successful petition + 2 raises
	}
	assert_eq(MiyaBlessingSystem.compute_need_score(conditions), 14)


# -- Petition bonus ----------------------------------------------------------

func test_petition_failure_contributes_zero() -> void:
	assert_eq(MiyaBlessingSystem.compute_petition_bonus(false, 5), 0)


func test_petition_success_no_raises_is_8() -> void:
	assert_eq(MiyaBlessingSystem.compute_petition_bonus(true, 0), 8)


func test_petition_success_two_raises_is_12() -> void:
	assert_eq(MiyaBlessingSystem.compute_petition_bonus(true, 2), 12)


func test_petition_negative_raises_clamped() -> void:
	assert_eq(MiyaBlessingSystem.compute_petition_bonus(true, -3), 8)


# -- Exclusions --------------------------------------------------------------

func test_excluded_when_in_rebellion() -> void:
	assert_true(MiyaBlessingSystem.is_excluded({"in_rebellion": true}))


func test_excluded_when_over_taint_threshold() -> void:
	assert_true(MiyaBlessingSystem.is_excluded({"over_taint_threshold": true}))


func test_not_excluded_default() -> void:
	assert_false(MiyaBlessingSystem.is_excluded({}))


# -- Province selection ------------------------------------------------------

func test_select_top_three_by_score() -> void:
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 5, "stability": 80.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 2, "score": 30, "stability": 40.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 3, "score": 15, "stability": 60.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 4, "score": 20, "stability": 50.0, "population_pu": 10.0, "excluded": false},
	]
	var selected: Array[int] = MiyaBlessingSystem.select_provinces(scored)
	assert_eq(selected, [2, 4, 3])


func test_select_skips_excluded() -> void:
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 100, "stability": 10.0, "population_pu": 10.0, "excluded": true},
		{"province_id": 2, "score": 30, "stability": 40.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 3, "score": 15, "stability": 60.0, "population_pu": 10.0, "excluded": false},
	]
	var selected: Array[int] = MiyaBlessingSystem.select_provinces(scored)
	assert_false(selected.has(1))
	assert_eq(selected.size(), 2)


func test_select_tiebreak_by_lowest_stability() -> void:
	# Two provinces tie on score; the one with lower stability wins.
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 20, "stability": 30.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 2, "score": 20, "stability": 60.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 3, "score": 5, "stability": 80.0, "population_pu": 10.0, "excluded": false},
	]
	var selected: Array[int] = MiyaBlessingSystem.select_provinces(scored)
	assert_eq(selected[0], 1)


func test_select_tiebreak_by_smaller_population() -> void:
	# Score and stability tied; smaller PU wins.
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 10, "stability": 50.0, "population_pu": 30.0, "excluded": false},
		{"province_id": 2, "score": 10, "stability": 50.0, "population_pu": 10.0, "excluded": false},
	]
	var selected: Array[int] = MiyaBlessingSystem.select_provinces(scored)
	assert_eq(selected[0], 2)


func test_select_returns_only_eligible_count() -> void:
	# Only one province; selection returns [pid].
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 10, "stability": 50.0, "population_pu": 10.0, "excluded": false},
	]
	assert_eq(MiyaBlessingSystem.select_provinces(scored).size(), 1)


# -- Distribution ------------------------------------------------------------

class _StubSettlement:
	var settlement_id: int
	var population_pu: float
	func _init(sid: int, pu: float) -> void:
		settlement_id = sid
		population_pu = pu


func test_distribute_proportional_to_pu() -> void:
	var settlements: Array = [
		_StubSettlement.new(1, 10.0),
		_StubSettlement.new(2, 30.0),
	]
	var shares: Dictionary = MiyaBlessingSystem.distribute_to_settlements(settlements, 4.0)
	# Total PU = 40. Settlement 1 gets 10/40 = 0.25 → 1.0. Settlement 2 → 3.0.
	assert_almost_eq(shares[1], 1.0, 0.001)
	assert_almost_eq(shares[2], 3.0, 0.001)


func test_distribute_skips_zero_pu_settlements() -> void:
	var settlements: Array = [
		_StubSettlement.new(1, 0.0),
		_StubSettlement.new(2, 10.0),
	]
	var shares: Dictionary = MiyaBlessingSystem.distribute_to_settlements(settlements, 5.0)
	assert_false(shares.has(1))
	assert_almost_eq(shares[2], 5.0, 0.001)


func test_distribute_zero_rice_returns_empty() -> void:
	var settlements: Array = [_StubSettlement.new(1, 10.0)]
	assert_true(MiyaBlessingSystem.distribute_to_settlements(settlements, 0.0).is_empty())


func test_distribute_no_settlements_returns_empty() -> void:
	assert_true(MiyaBlessingSystem.distribute_to_settlements([], 5.0).is_empty())


func test_distribute_zero_total_pu_returns_empty() -> void:
	var settlements: Array = [
		_StubSettlement.new(1, 0.0),
		_StubSettlement.new(2, 0.0),
	]
	assert_true(MiyaBlessingSystem.distribute_to_settlements(settlements, 5.0).is_empty())


# -- process_annual_blessing end-to-end --------------------------------------

func _make_inputs(
	archetype: StrategicReview.EmperorArchetype,
	tax_income: float,
	stockpile: float,
	ou_pu: float,
	scored: Array[Dictionary],
	province_settlements: Dictionary,
) -> Dictionary:
	return {
		"emperor_archetype": archetype,
		"emperor_autumn_tax_income": tax_income,
		"emperor_stockpile": stockpile,
		"otosan_uchi_pu": ou_pu,
		"scored_provinces": scored,
		"province_settlements": province_settlements,
	}


func test_tyrant_archetype_suspends_blessing() -> void:
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.TYRANT, 12.0, 100.0, 50.0, [], {}
	))
	assert_true(result["suspended"])
	assert_eq(result["suspension_reason"], "tyrant_archetype")
	assert_false(result["fired"])


func test_below_threshold_suspends_with_reason() -> void:
	# Tax income too small to clear MIN_THRESHOLD (0.50).
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 1.0, 100.0, 50.0, [], {}
	))
	# 1.0 * 0.15 = 0.15 < 0.50 → suspended.
	assert_true(result["suspended"])
	assert_eq(result["suspension_reason"], "below_threshold")


func test_full_blessing_fires_and_distributes() -> void:
	var settlements_p1: Array = [_StubSettlement.new(101, 10.0)]
	var settlements_p2: Array = [_StubSettlement.new(201, 5.0), _StubSettlement.new(202, 5.0)]
	var settlements_p3: Array = [_StubSettlement.new(301, 20.0)]
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 30, "stability": 30.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 2, "score": 20, "stability": 50.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 3, "score": 15, "stability": 70.0, "population_pu": 20.0, "excluded": false},
		{"province_id": 4, "score": 5, "stability": 80.0, "population_pu": 30.0, "excluded": false},
	]
	var province_settlements: Dictionary = {1: settlements_p1, 2: settlements_p2, 3: settlements_p3}

	# 12.0 tax × 0.15 = 1.80 total. Per province = 0.60.
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 12.0, 100.0, 50.0, scored, province_settlements
	))
	assert_true(result["fired"])
	assert_false(result["suspended"])
	assert_almost_eq(result["allocation_total"], 1.80, 0.001)
	assert_almost_eq(result["allocation_per_province"], 0.60, 0.001)
	assert_eq(result["selected_province_ids"], [1, 2, 3])
	# Settlement 101 gets all of province 1's share.
	assert_almost_eq(result["settlement_rice_grants"][101], 0.60, 0.001)
	# Settlements 201 and 202 split province 2's share equally.
	assert_almost_eq(result["settlement_rice_grants"][201], 0.30, 0.001)
	assert_almost_eq(result["settlement_rice_grants"][202], 0.30, 0.001)
	assert_almost_eq(result["settlement_rice_grants"][301], 0.60, 0.001)


func test_per_province_capped_at_5_rice() -> void:
	# Massive tax income — allocation ceiling 15.0. Per province 5.0.
	var settlements_p1: Array = [_StubSettlement.new(101, 10.0)]
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 100, "stability": 10.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 2, "score": 90, "stability": 20.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 3, "score": 80, "stability": 30.0, "population_pu": 10.0, "excluded": false},
	]
	var province_settlements: Dictionary = {
		1: settlements_p1,
		2: [_StubSettlement.new(201, 10.0)],
		3: [_StubSettlement.new(301, 10.0)],
	}
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 200.0, 1000.0, 0.0, scored, province_settlements
	))
	assert_almost_eq(result["allocation_per_province"], 5.0, 0.001)
	assert_almost_eq(result["allocation_total"], 15.0, 0.001)


func test_excluded_provinces_not_selected() -> void:
	var settlements: Array = [_StubSettlement.new(101, 10.0)]
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 100, "stability": 10.0, "population_pu": 10.0, "excluded": true},
		{"province_id": 2, "score": 30, "stability": 50.0, "population_pu": 10.0, "excluded": false},
	]
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 12.0, 100.0, 50.0, scored, {2: settlements}
	))
	assert_false(result["selected_province_ids"].has(1))
	assert_true(result["selected_province_ids"].has(2))


func test_fewer_than_three_eligible_distributes_to_what_remains() -> void:
	# Only one eligible province — the Blessing fires for that one,
	# remaining allocation stays implicitly in the Emperor's stockpile.
	var settlements: Array = [_StubSettlement.new(101, 10.0)]
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 30, "stability": 30.0, "population_pu": 10.0, "excluded": false},
	]
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 12.0, 100.0, 50.0, scored, {1: settlements}
	))
	assert_eq(result["selected_province_ids"], [1])
	# Per-province share is 0.60; only one province → total fired = 0.60.
	assert_almost_eq(result["allocation_total"], 0.60, 0.001)


func test_fired_total_matches_per_province_times_count() -> void:
	# Verifies allocation_total reflects what's actually distributed (not the
	# cap), which matters when fewer-than-three are eligible.
	var settlements: Array = [_StubSettlement.new(101, 10.0)]
	var scored: Array[Dictionary] = [
		{"province_id": 1, "score": 30, "stability": 30.0, "population_pu": 10.0, "excluded": false},
		{"province_id": 2, "score": 20, "stability": 50.0, "population_pu": 10.0, "excluded": false},
	]
	var province_settlements: Dictionary = {
		1: settlements,
		2: [_StubSettlement.new(201, 10.0)],
	}
	var result: Dictionary = MiyaBlessingSystem.process_annual_blessing(_make_inputs(
		StrategicReview.EmperorArchetype.IRON, 12.0, 100.0, 50.0, scored, province_settlements
	))
	assert_eq(result["selected_province_ids"].size(), 2)
	# 0.60 per province × 2 selected = 1.20 actually fired.
	assert_almost_eq(result["allocation_total"], 1.20, 0.001)
