extends GutTest


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


func _make_province(id: int, stability: float = 100.0, coastal: bool = false) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.stability = stability
	p.population_pu = 1000
	p.garrison_pu = 100
	p.is_coastal = coastal
	return p


func _make_insurgency(
	id: int, itype: Enums.InsurgencyType, province_id: int,
	strength: int = 1, concealment: int = -1, detected: bool = false,
) -> InsurgencyData:
	var ins := InsurgencyData.new()
	ins.insurgency_id = id
	ins.insurgency_type = itype
	ins.province_id = province_id
	ins.strength = strength
	if concealment < 0:
		ins.concealment = InsurgencySystem.BASE_CONCEALMENT.get(itype, 5)
	else:
		ins.concealment = concealment
	ins.detected = detected
	return ins


func _make_character(honor: float = 3.5, glory: float = 1.0, taint: float = 0.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.honor = honor
	c.glory = glory
	c.taint = taint
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


# -- Stability Tier Tests ------------------------------------------------------

func test_stability_tier_stable():
	assert_eq(InsurgencySystem.get_stability_tier(100.0), Enums.StabilityTier.STABLE)
	assert_eq(InsurgencySystem.get_stability_tier(76.0), Enums.StabilityTier.STABLE)

func test_stability_tier_restless():
	assert_eq(InsurgencySystem.get_stability_tier(75.0), Enums.StabilityTier.RESTLESS)
	assert_eq(InsurgencySystem.get_stability_tier(51.0), Enums.StabilityTier.RESTLESS)

func test_stability_tier_volatile():
	assert_eq(InsurgencySystem.get_stability_tier(50.0), Enums.StabilityTier.VOLATILE)
	assert_eq(InsurgencySystem.get_stability_tier(26.0), Enums.StabilityTier.VOLATILE)

func test_stability_tier_broken():
	assert_eq(InsurgencySystem.get_stability_tier(25.0), Enums.StabilityTier.BROKEN)
	assert_eq(InsurgencySystem.get_stability_tier(0.0), Enums.StabilityTier.BROKEN)


# -- Stability Change Tests ----------------------------------------------------

func test_stability_loss_from_starvation():
	var p := _make_province(1, 80.0)
	var ins_arr: Array[InsurgencyData] = []
	assert_eq(InsurgencySystem.compute_stability_change(p, ins_arr, 1, false, false, 0), -1.0)
	assert_eq(InsurgencySystem.compute_stability_change(p, ins_arr, 2, false, false, 0), -3.0)
	assert_eq(InsurgencySystem.compute_stability_change(p, ins_arr, 3, false, false, 0), -10.0)

func test_stability_loss_from_war():
	var p := _make_province(1, 80.0)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, true, false, 0)
	assert_eq(delta, -2.0)

func test_stability_loss_from_raid():
	var p := _make_province(1, 80.0)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, false, true, 0)
	assert_eq(delta, -5.0)

func test_stability_loss_from_insurgency():
	var p := _make_province(1, 80.0)
	var ins: InsurgencyData = _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1)
	var ins_arr: Array[InsurgencyData] = [ins]
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, false, false, 0)
	assert_eq(delta, -1.0)

func test_stability_recovery_clear():
	var p := _make_province(1, 80.0)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, false, false, 0)
	assert_eq(delta, 2.0)

func test_stability_recovery_with_peace_bonus():
	var p := _make_province(1, 80.0)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, false, false, 4)
	assert_eq(delta, 3.0)

func test_stability_under_garrisoned():
	var p := _make_province(1, 80.0)
	p.garrison_pu = 10  # below 5% of 1000
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_stability_change(p, ins_arr, 0, false, false, 0)
	assert_true(delta < 0.0, "Under-garrisoned should prevent recovery and add penalty")


# -- Eligible Types Tests ------------------------------------------------------

func test_eligible_types_stable():
	var p := _make_province(1, 100.0)
	var types: Array[int] = InsurgencySystem.get_eligible_types(Enums.StabilityTier.STABLE, p, 0.0)
	assert_true(Enums.InsurgencyType.MAHO_CULT in types, "Maho cult can spawn in stable")
	assert_true(Enums.InsurgencyType.NEZUMI_INFESTATION in types, "Nezumi can spawn anywhere")
	assert_false(Enums.InsurgencyType.PEASANT_REVOLT in types, "No revolt in stable")

func test_eligible_types_coastal():
	var p := _make_province(1, 50.0, true)
	var types: Array[int] = InsurgencySystem.get_eligible_types(Enums.StabilityTier.VOLATILE, p, 0.0)
	assert_true(Enums.InsurgencyType.PIRATE_FLEET in types, "Pirates on coastal")

func test_eligible_types_not_coastal():
	var p := _make_province(1, 50.0, false)
	var types: Array[int] = InsurgencySystem.get_eligible_types(Enums.StabilityTier.VOLATILE, p, 0.0)
	assert_false(Enums.InsurgencyType.PIRATE_FLEET in types, "No pirates inland")

func test_eligible_taint_from_ptl():
	var p := _make_province(1, 100.0)
	var types: Array[int] = InsurgencySystem.get_eligible_types(Enums.StabilityTier.STABLE, p, 3.0)
	assert_true(Enums.InsurgencyType.TAINT_MANIFESTATION in types, "Taint spawns from PTL >= 3")


# -- Spawn Chance Tests --------------------------------------------------------

func test_spawn_chance_peasant_revolt_needs_volatile():
	var p := _make_province(1, 60.0)
	var chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.PEASANT_REVOLT, Enums.StabilityTier.RESTLESS, p, {}
	)
	assert_eq(chance, 0.0, "Peasant revolt should not spawn in Restless")

func test_spawn_chance_maho_stable():
	var p := _make_province(1, 100.0)
	var chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.MAHO_CULT, Enums.StabilityTier.STABLE, p, {}
	)
	assert_almost_eq(chance, 0.02, 0.001)

func test_spawn_chance_pirate_not_coastal():
	var p := _make_province(1, 50.0, false)
	var chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.PIRATE_FLEET, Enums.StabilityTier.VOLATILE, p, {}
	)
	assert_eq(chance, 0.0)

func test_spawn_chance_taint_needs_ptl():
	var p := _make_province(1, 50.0)
	var chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.TAINT_MANIFESTATION, Enums.StabilityTier.VOLATILE, p, {"ptl": 2.0}
	)
	assert_eq(chance, 0.0)
	chance = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.TAINT_MANIFESTATION, Enums.StabilityTier.VOLATILE, p, {"ptl": 3.0}
	)
	assert_eq(chance, 1.0, "Taint manifestation auto-spawns at PTL 3+")


# -- Hidden Growth Tests -------------------------------------------------------

func test_hidden_growth_increases_strength():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 2, 5)
	InsurgencySystem.process_hidden_growth(ins)
	assert_eq(ins.strength, 3)
	assert_eq(ins.concealment, 4)

func test_hidden_growth_auto_detect_at_zero():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 3, 1)
	var result: Dictionary = InsurgencySystem.process_hidden_growth(ins)
	assert_true(result["auto_detected"])
	assert_true(ins.detected)

func test_hidden_growth_hint_at_strength_5():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 4, 5)
	var result: Dictionary = InsurgencySystem.process_hidden_growth(ins)
	assert_eq(ins.strength, 5)
	assert_true(result["hint_generated"])

func test_hidden_growth_skips_detected():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 3, 5, true)
	var result: Dictionary = InsurgencySystem.process_hidden_growth(ins)
	assert_eq(ins.strength, 3, "Should not grow when already detected")


# -- Detection Tests -----------------------------------------------------------

func test_detection_tn():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 3, 8)
	assert_eq(InsurgencySystem.get_detection_tn(ins), 40)

func test_detection_success():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 3, 5)
	var result: Dictionary = InsurgencySystem.attempt_detection(ins, 30)
	assert_eq(result["result"], "success")
	assert_true(ins.detected)
	assert_eq(result["strength_estimate"], 3)

func test_detection_partial():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 3, 5)
	var result: Dictionary = InsurgencySystem.attempt_detection(ins, 26)
	assert_eq(result["result"], "partial")
	assert_true(ins.detected)

func test_detection_failure():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 3, 5)
	var result: Dictionary = InsurgencySystem.attempt_detection(ins, 20)
	assert_eq(result["result"], "failure")
	assert_false(ins.detected)
	assert_eq(ins.concealment, 6, "Concealment should increase on failure")


# -- Suppression Tests ---------------------------------------------------------

func test_suppression_tn_standard():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 5)
	assert_eq(InsurgencySystem.get_suppression_tn(ins), 25)

func test_suppression_tn_ronin():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 5)
	assert_eq(InsurgencySystem.get_suppression_tn(ins), 35)

func test_suppression_success():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 30, false)
	assert_eq(result["outcome"], "success")
	assert_eq(ins.strength, 2)

func test_suppression_partial():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 27, false)
	assert_eq(result["outcome"], "partial")
	assert_eq(ins.strength, 4)

func test_suppression_failure():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 20, false)
	assert_eq(result["outcome"], "failure")
	assert_eq(ins.strength, 5)

func test_suppression_critical_failure():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 15, false)
	assert_eq(result["outcome"], "critical_failure")
	assert_eq(ins.strength, 6)

func test_suppression_maho_without_shugenja():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 4, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 30, false)
	assert_eq(ins.strength, 3, "Without shugenja, max -1 reduction")

func test_suppression_maho_with_shugenja():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 4, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 30, true)
	assert_eq(ins.strength, 1, "With shugenja, full -3 reduction")

func test_suppression_eliminates():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 2, 0, true)
	var result: Dictionary = InsurgencySystem.resolve_suppression(ins, 20, false)
	assert_true(result["suppressed"])
	assert_eq(result["stability_gain"], 5)
	assert_eq(ins.strength, 0)


# -- Coordinated Suppression Tests ---------------------------------------------

func test_coordinated_suppression_cumulative():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 8, 0, true)
	var rolls: Array[int] = [60, 58, 40]  # TN = 56 for ronin S8
	var result: Dictionary = InsurgencySystem.resolve_coordinated_suppression(ins, rolls, false, 0)
	assert_true(result["outcomes"].size() == 3)

func test_coordinated_with_leader_bonus():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 4, 0, true)
	var rolls: Array[int] = [15, 15]  # TN = 20, with bonus 10 = 25 each
	var result: Dictionary = InsurgencySystem.resolve_coordinated_suppression(ins, rolls, false, 10)
	assert_eq(result["outcomes"][0], "success")
	assert_eq(result["outcomes"][1], "success")


# -- Spread Tests --------------------------------------------------------------

func test_spread_chance_zero_low_strength():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 4)
	var chance: float = InsurgencySystem.get_spread_chance(ins, Enums.StabilityTier.VOLATILE)
	assert_eq(chance, 0.0)

func test_spread_chance_detected_at_5():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 5, 0, true)
	var chance: float = InsurgencySystem.get_spread_chance(ins, Enums.StabilityTier.VOLATILE)
	assert_true(chance > 0.0)

func test_spread_chance_zero_into_stable():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 7, 0, true)
	var chance: float = InsurgencySystem.get_spread_chance(ins, Enums.StabilityTier.STABLE)
	assert_eq(chance, 0.0)

func test_spread_nezumi_into_stable():
	var ins := _make_insurgency(1, Enums.InsurgencyType.NEZUMI_INFESTATION, 1, 5, 0, true)
	var chance: float = InsurgencySystem.get_spread_chance(ins, Enums.StabilityTier.STABLE)
	assert_almost_eq(chance, 0.05, 0.001, "Nezumi can spread into stable")


# -- PTL Tests -----------------------------------------------------------------

func test_ptl_tier_clean():
	assert_eq(InsurgencySystem.get_ptl_tier(0.0), "CLEAN")
	assert_eq(InsurgencySystem.get_ptl_tier(2.0), "CLEAN")

func test_ptl_tier_touched():
	assert_eq(InsurgencySystem.get_ptl_tier(3.0), "TOUCHED")
	assert_eq(InsurgencySystem.get_ptl_tier(5.0), "TOUCHED")

func test_ptl_tier_corrupted():
	assert_eq(InsurgencySystem.get_ptl_tier(6.0), "CORRUPTED")

func test_ptl_tier_blighted():
	assert_eq(InsurgencySystem.get_ptl_tier(9.0), "BLIGHTED")

func test_taint_resistance_tn():
	assert_eq(InsurgencySystem.get_taint_resistance_tn(0.0), 0)
	assert_eq(InsurgencySystem.get_taint_resistance_tn(3.0), 15)
	assert_eq(InsurgencySystem.get_taint_resistance_tn(6.0), 25)
	assert_eq(InsurgencySystem.get_taint_resistance_tn(9.0), 35)

func test_ptl_gain_from_maho_events():
	var p := _make_province(1)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 2, {}, false, 0, false, false, 0, false
	)
	assert_true(delta > 0.0, "Maho events should increase PTL")

func test_ptl_gain_from_active_maho_cult():
	var p := _make_province(1)
	var maho := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1)
	var ins_arr: Array[InsurgencyData] = [maho]
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 0, {}, false, 0, false, false, 0, false
	)
	assert_almost_eq(delta, 0.5, 0.01, "Maho cult +1 minus natural decay 0.5")

func test_ptl_double_from_maho_plus_taint():
	var p := _make_province(1)
	var maho := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1)
	var taint := _make_insurgency(2, Enums.InsurgencyType.TAINT_MANIFESTATION, 1)
	var ins_arr: Array[InsurgencyData] = [maho, taint]
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 0, {}, false, 0, false, false, 0, false
	)
	assert_true(delta >= 4.0, "Maho+Taint should double the base gain of 2.0")

func test_ptl_adjacent_bleed():
	var p := _make_province(1)
	var ins_arr: Array[InsurgencyData] = []
	var adj_ptls: Dictionary = {2: 8.0}
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 0, adj_ptls, false, 0, false, false, 0, false
	)
	assert_true(delta > 0.0, "Adjacent PTL 8 should cause bleed")

func test_ptl_adjacent_bleed_reduced_by_jade():
	var p := _make_province(1)
	var ins_arr: Array[InsurgencyData] = []
	var adj_ptls: Dictionary = {2: 8.0}
	var no_jade: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 0, adj_ptls, false, 0, false, false, 0, false
	)
	var with_jade: float = InsurgencySystem.compute_ptl_change(
		p, 0.0, ins_arr, 0, adj_ptls, true, 0, false, false, 0, false
	)
	assert_true(with_jade < no_jade, "Jade should reduce bleed")

func test_ptl_natural_decay():
	var p := _make_province(1)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 5.0, ins_arr, 0, {}, false, 0, false, false, 0, false
	)
	assert_almost_eq(delta, -0.5, 0.01, "Natural decay when no gain events")

func test_ptl_shugenja_purification():
	var p := _make_province(1)
	var ins_arr: Array[InsurgencyData] = []
	var delta: float = InsurgencySystem.compute_ptl_change(
		p, 5.0, ins_arr, 0, {}, false, 0, false, false, 2, false
	)
	assert_true(delta <= -2.0, "Purification should reduce PTL")


# -- Crisis Tier Tests ---------------------------------------------------------

func test_crisis_tier_maho():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1)
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 1)

func test_crisis_tier_peasant_revolt_low():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 3)
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 3)

func test_crisis_tier_peasant_revolt_high():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5)
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 2)

func test_crisis_tier_ucn_tiers():
	var ins := _make_insurgency(1, Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK, 1, 3)
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 4)
	ins.strength = 5
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 3)
	ins.strength = 8
	assert_eq(InsurgencySystem.get_crisis_tier(ins), 2)


# -- Ronin Hiring Tests --------------------------------------------------------

func test_ronin_hire_success():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 4)
	var result: Dictionary = InsurgencySystem.attempt_ronin_hire(ins, 25)
	assert_eq(result["result"], "success")
	assert_eq(ins.strength, 0)

func test_ronin_hire_failure():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 4)
	var result: Dictionary = InsurgencySystem.attempt_ronin_hire(ins, 15)
	assert_eq(result["result"], "failure")
	assert_eq(ins.strength, 5)

func test_ronin_hire_cost():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 5)
	assert_almost_eq(InsurgencySystem.get_ronin_hire_cost(ins), 10.0, 0.01)

func test_ronin_hire_invalid_type():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 4)
	assert_eq(InsurgencySystem.get_ronin_hire_cost(ins), -1.0)


# -- Susceptibility Tests ------------------------------------------------------

func test_susceptibility_base():
	var c := _make_character(3.5, 1.0)
	var score: int = InsurgencySystem.compute_susceptibility(c, 0)
	assert_true(score > 0)

func test_susceptibility_high_honor_low():
	var c := _make_character(7.0, 5.0)
	var score: int = InsurgencySystem.compute_susceptibility(c, 50)
	assert_true(score <= 0, "High honor + glory + friendly lord = low susceptibility")

func test_susceptibility_enemy_lord():
	var c := _make_character(3.5, 1.0)
	var score_friend: int = InsurgencySystem.compute_susceptibility(c, 50)
	var score_enemy: int = InsurgencySystem.compute_susceptibility(c, -50)
	assert_true(score_enemy > score_friend, "Enemy lord = higher susceptibility")

func test_susceptibility_maho_taint_bonus():
	var c := _make_character(3.5, 1.0, 2.0)
	var base: int = InsurgencySystem.compute_susceptibility(c, 0)
	var maho: int = InsurgencySystem.compute_susceptibility_maho(c, 0)
	assert_true(maho > base, "Taint should increase maho susceptibility")

func test_ishi_immune():
	var c := _make_character()
	c.shourido_virtue = Enums.ShouridoVirtue.ISHI
	assert_true(InsurgencySystem.is_immune_to_corruption(c))


# -- Economic Effect Tests -----------------------------------------------------

func test_koku_drain_ronin():
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 1, 4)
	assert_almost_eq(InsurgencySystem.get_koku_drain(ins), 0.2, 0.01)

func test_koku_drain_pirate():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PIRATE_FLEET, 1, 8)
	assert_almost_eq(InsurgencySystem.get_koku_drain(ins), 0.4, 0.01)

func test_rice_drain_nezumi():
	var ins := _make_insurgency(1, Enums.InsurgencyType.NEZUMI_INFESTATION, 1, 5)
	assert_almost_eq(InsurgencySystem.get_rice_drain(ins), 0.5, 0.01)

func test_rice_drain_nezumi_strength_10():
	var ins := _make_insurgency(1, Enums.InsurgencyType.NEZUMI_INFESTATION, 1, 10)
	assert_almost_eq(InsurgencySystem.get_rice_drain(ins), 1.0, 0.01)

func test_pu_loss_peasant():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 5)
	assert_almost_eq(InsurgencySystem.get_pu_loss_on_suppression(ins), 0.5, 0.01)


# -- Strength 10 Consequence Tests ---------------------------------------------

func test_strength_10_maho():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 10)
	assert_eq(InsurgencySystem.get_strength_10_consequence(ins), "oni_manifestation")

func test_strength_10_revolt():
	var ins := _make_insurgency(1, Enums.InsurgencyType.PEASANT_REVOLT, 1, 10)
	assert_eq(InsurgencySystem.get_strength_10_consequence(ins), "province_seized")

func test_strength_below_10_no_consequence():
	var ins := _make_insurgency(1, Enums.InsurgencyType.MAHO_CULT, 1, 9)
	assert_eq(InsurgencySystem.get_strength_10_consequence(ins), "")


# -- Process Season Integration Test -------------------------------------------

func test_process_season_basic():
	var provinces: Dictionary = {1: _make_province(1, 40.0)}
	var ptls: Dictionary = {1: 0.0}
	var insurgencies: Array[InsurgencyData] = []
	var world_states: Dictionary = {1: {}}
	var result: Dictionary = InsurgencySystem.process_season(
		insurgencies, provinces, ptls, _dice, 0, 100, world_states
	)
	assert_true(result.has("new_insurgencies"))
	assert_true(result.has("events"))
	assert_true(result.has("next_id"))
