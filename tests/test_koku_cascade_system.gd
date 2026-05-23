extends GutTest


func _make_character(
	id: int, clan: String, status: float, lord_id: int = -1,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = status
	c.lord_id = lord_id
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.stamina = 2
	c.willpower = 2
	c.koku = 0.0
	return c


func _make_settlement(sid: int, pid: int, koku: float, town_pu: int = 0) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = pid
	s.koku_stockpile = koku
	s.town_pu = town_pu
	return s


func _make_clan(name: String, pids: Array) -> ClanData:
	var cd := ClanData.new()
	cd.clan_name = name
	cd.province_ids = pids
	return cd


# -- Tier Mapping --------------------------------------------------------------

func test_tier_for_clan_champion() -> void:
	assert_eq(
		KokuCascadeSystem.get_tier_for_lord_rank(Enums.LordRank.CLAN_CHAMPION),
		"clan_champion",
	)


func test_tier_for_family_daimyo() -> void:
	assert_eq(
		KokuCascadeSystem.get_tier_for_lord_rank(Enums.LordRank.FAMILY_DAIMYO),
		"family_daimyo",
	)


func test_tier_for_provincial_daimyo() -> void:
	assert_eq(
		KokuCascadeSystem.get_tier_for_lord_rank(Enums.LordRank.PROVINCIAL_DAIMYO),
		"provincial_daimyo",
	)


func test_tier_for_city_daimyo() -> void:
	assert_eq(
		KokuCascadeSystem.get_tier_for_lord_rank(Enums.LordRank.CITY_DAIMYO),
		"local_daimyo",
	)


# -- Upward Pooling ------------------------------------------------------------

func test_pool_upward_drains_settlement_koku() -> void:
	var s1 := _make_settlement(1, 10, 6.0)
	var clan := _make_clan("Crane", [10])
	var settlements: Array = [s1]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	# Monthly share = 6.0 / 3 = 2.0
	assert_almost_eq(result["Crane"], 2.0, 0.001)
	assert_almost_eq(s1.koku_stockpile, 4.0, 0.001)


func test_pool_upward_multiple_settlements() -> void:
	var s1 := _make_settlement(1, 10, 9.0)
	var s2 := _make_settlement(2, 11, 3.0)
	var clan := _make_clan("Lion", [10, 11])
	var settlements: Array = [s1, s2]
	var clans: Dictionary = {"Lion": clan}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	# (9 + 3) / 3 = 4.0
	assert_almost_eq(result["Lion"], 4.0, 0.001)


func test_pool_upward_different_clans() -> void:
	var s1 := _make_settlement(1, 10, 6.0)
	var s2 := _make_settlement(2, 20, 12.0)
	var crane := _make_clan("Crane", [10])
	var crab := _make_clan("Crab", [20])
	var settlements: Array = [s1, s2]
	var clans: Dictionary = {"Crane": crane, "Crab": crab}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	assert_almost_eq(result["Crane"], 2.0, 0.001)
	assert_almost_eq(result["Crab"], 4.0, 0.001)


# -- Downward Cascade ----------------------------------------------------------

func test_champion_retains_40_percent() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var chars: Array = [champ]
	var by_id: Dictionary = {1: champ}
	var clan_pools: Dictionary = {"Crane": 10.0}
	var result: Dictionary = KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# Retains 40% of 10.0 = 4.0 koku units = 2000 individual koku
	assert_almost_eq(champ.koku, 2000.0, 0.1)
	assert_almost_eq(result[1]["retained"], 4.0, 0.001)
	assert_almost_eq(result[1]["passed_down"], 6.0, 0.001)


func test_generous_champion_retains_less() -> void:
	var champ := _make_character(1, "Crane", 7.0, -1, Enums.BushidoVirtue.JIN)
	var chars: Array = [champ]
	var by_id: Dictionary = {1: champ}
	var clan_pools: Dictionary = {"Crane": 10.0}
	KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# JIN = +10% stipend modifier → retention goes from 40% to 30%
	# Retained = 10 * 0.30 = 3.0 → 1500 individual koku
	assert_almost_eq(champ.koku, 1500.0, 0.1)


func test_miserly_champion_retains_more() -> void:
	var champ := _make_character(
		1, "Crane", 7.0, -1,
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU,
	)
	var chars: Array = [champ]
	var by_id: Dictionary = {1: champ}
	var clan_pools: Dictionary = {"Crane": 10.0}
	KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# KYORYOKU = -10% modifier → retention goes from 40% to 50%
	# Retained = 10 * 0.50 = 5.0 → 2500 individual koku
	assert_almost_eq(champ.koku, 2500.0, 0.1)


func test_cascade_two_tiers() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var family := _make_character(2, "Crane", 6.0, 1)
	var chars: Array = [champ, family]
	var by_id: Dictionary = {1: champ, 2: family}
	var clan_pools: Dictionary = {"Crane": 10.0}
	var result: Dictionary = KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# Champion retains 40% = 4.0, passes 6.0
	# Family Daimyo retains 25% of 6.0 = 1.5
	assert_almost_eq(champ.koku, 2000.0, 0.1)
	assert_almost_eq(family.koku, 750.0, 0.1)
	assert_almost_eq(result[2]["retained"], 1.5, 0.001)


func test_cascade_full_chain() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var family := _make_character(2, "Crane", 6.0, 1)
	var provincial := _make_character(3, "Crane", 5.0, 2)
	var local := _make_character(4, "Crane", 4.0, 3)
	var chars: Array = [champ, family, provincial, local]
	var by_id: Dictionary = {1: champ, 2: family, 3: provincial, 4: local}
	var clan_pools: Dictionary = {"Crane": 10.0}
	var result: Dictionary = KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# Champion: retains 40% of 10 = 4.0, passes 6.0
	# Family: retains 25% of 6 = 1.5, passes 4.5
	# Provincial: retains 20% of 4.5 = 0.9, passes 3.6
	# Local: retains 15% of 3.6 = 0.54, passes 3.06
	assert_almost_eq(result[1]["retained"], 4.0, 0.001)
	assert_almost_eq(result[2]["retained"], 1.5, 0.001)
	assert_almost_eq(result[3]["retained"], 0.9, 0.001)
	assert_almost_eq(result[4]["retained"], 0.54, 0.001)


# -- Individual Stipends -------------------------------------------------------

func test_retainer_receives_stipend_from_local_lord() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.5, "passed_down": 3.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	# Local daimyo base stipend = 1.0 koku/month
	# Pool = 3.0 * 500 = 1500 individual koku; needs 1.0 for 1 retainer → ratio 1.0
	assert_almost_eq(result[2]["actual_payment"], 1.0, 0.01)
	assert_almost_eq(retainer.koku, 1.0, 0.01)


func test_retainer_of_champion_gets_five_koku() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [champ, retainer]
	var by_id: Dictionary = {1: champ, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "clan_champion", "retained": 4.0, "passed_down": 6.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_almost_eq(result[2]["actual_payment"], 5.0, 0.01)


func test_reduced_stipend_from_empty_pool() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var r1 := _make_character(2, "Crane", 2.0, 1)
	var r2 := _make_character(3, "Crane", 2.0, 1)
	var chars: Array = [local, r1, r2]
	var by_id: Dictionary = {1: local, 2: r1, 3: r2}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_almost_eq(result[2]["actual_payment"], 0.0, 0.01)
	assert_eq(result[2]["consequence"], KokuCascadeSystem.DISPOSITION_NO_STIPEND)


func test_partial_stipend_reduced_consequence() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	# Pool = 0.001 koku units * 500 = 0.5 individual koku
	# Needed: 1.0 per retainer. Ratio = 0.5 → severely reduced
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.001},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_true(result[2]["ratio"] < 0.75)


# -- Stipend Consequences ------------------------------------------------------

func test_consequence_full_stipend() -> void:
	assert_eq(KokuCascadeSystem._stipend_consequence(1.0), 0)


func test_consequence_slightly_reduced() -> void:
	assert_eq(KokuCascadeSystem._stipend_consequence(0.6), KokuCascadeSystem.DISPOSITION_REDUCED)


func test_consequence_severely_reduced() -> void:
	assert_eq(
		KokuCascadeSystem._stipend_consequence(0.3),
		KokuCascadeSystem.DISPOSITION_SEVERELY_REDUCED,
	)


func test_consequence_no_stipend() -> void:
	assert_eq(KokuCascadeSystem._stipend_consequence(0.0), KokuCascadeSystem.DISPOSITION_NO_STIPEND)


# -- Consecutive Unpaid Tracking -----------------------------------------------

func test_months_without_stipend_increments_on_zero_payment() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	KokuCascadeSystem._pay_individual_stipends(lord_pools, chars, by_id)
	assert_eq(retainer.months_without_stipend, 1)
	KokuCascadeSystem._pay_individual_stipends(lord_pools, chars, by_id)
	assert_eq(retainer.months_without_stipend, 2)


func test_months_without_stipend_resets_on_any_payment() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 2
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.5, "passed_down": 3.0},
	}
	KokuCascadeSystem._pay_individual_stipends(lord_pools, chars, by_id)
	assert_eq(retainer.months_without_stipend, 0)


func test_severely_reduced_resets_counter() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 2
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	# Pool = 0.0002 * 500 = 0.1 koku. Need 1.0. Ratio = 0.1 (severely reduced but nonzero)
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0002},
	}
	KokuCascadeSystem._pay_individual_stipends(lord_pools, chars, by_id)
	assert_eq(retainer.months_without_stipend, 0)


func test_crisis_flag_after_three_months() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 2
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(retainer.months_without_stipend, 3)
	assert_true(result[2]["in_crisis"])


func test_no_crisis_at_two_months() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 1
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(retainer.months_without_stipend, 2)
	assert_false(result[2]["in_crisis"])


func test_crisis_persists_beyond_three() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 5
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(retainer.months_without_stipend, 6)
	assert_true(result[2]["in_crisis"])


# -- Topic Generation Flags ----------------------------------------------------

func test_reduced_stipend_generates_topic() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	# Pool = 0.0012 * 500 = 0.6. Need 1.0. Ratio = 0.6 → reduced (50-75%)
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0012},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_true(result[2]["ratio"] >= 0.50 and result[2]["ratio"] < 0.75)
	assert_true(result[2]["generates_topic"])
	assert_eq(result[2]["lord_id"], 1)


func test_full_stipend_no_topic() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.5, "passed_down": 3.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_false(result[2]["generates_topic"])


func test_severely_reduced_no_topic() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	# Pool = 0.0004 * 500 = 0.2. Need 1.0. Ratio = 0.2 → severely reduced (<50%)
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0004},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_true(result[2]["ratio"] < 0.50 and result[2]["ratio"] > 0.0)
	assert_false(result[2]["generates_topic"])


func test_crisis_month_generates_topic() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 2
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(retainer.months_without_stipend, 3)
	assert_true(result[2]["generates_topic"])


func test_crisis_beyond_three_no_repeat_topic() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	retainer.months_without_stipend = 3
	var chars: Array = [local, retainer]
	var by_id: Dictionary = {1: local, 2: retainer}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(retainer.months_without_stipend, 4)
	assert_true(result[2]["in_crisis"])
	assert_false(result[2]["generates_topic"])


# -- Full Flow Integration -----------------------------------------------------

func test_full_flow_single_clan() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var local := _make_character(2, "Crane", 4.0, 1)
	var retainer := _make_character(3, "Crane", 2.0, 2)
	var settlement := _make_settlement(100, 10, 12.0)
	var clan := _make_clan("Crane", [10])
	var chars: Array = [champ, local, retainer]
	var by_id: Dictionary = {1: champ, 2: local, 3: retainer}
	var settlements: Array = [settlement]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem.process_monthly_koku_flow(
		chars, by_id, settlements, clans, 3,
	)
	# Upward: 12 / 3 = 4.0 koku units pooled to Crane
	assert_almost_eq(result["upward"]["Crane"], 4.0, 0.001)
	# Champion gets some koku, retainer gets a stipend
	assert_true(champ.koku > 0.0)
	assert_true(retainer.koku > 0.0)


# -- Indirect Retainer Stipends ------------------------------------------------

func test_indirect_retainer_gets_point_six_koku() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var samurai := _make_character(2, "Crane", 2.0, 1)
	var yojimbo := _make_character(3, "Crane", 2.0, 2)
	var chars: Array = [local, samurai, yojimbo]
	var by_id: Dictionary = {1: local, 2: samurai, 3: yojimbo}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.5, "passed_down": 3.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_almost_eq(result[2]["actual_payment"], 1.0, 0.01)
	assert_false(result[2]["is_indirect"])
	assert_almost_eq(result[3]["actual_payment"], 0.6, 0.01)
	assert_true(result[3]["is_indirect"])
	assert_almost_eq(yojimbo.koku, 0.6, 0.01)


func test_indirect_retainer_disposition_targets_direct_lord() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var samurai := _make_character(2, "Crane", 2.0, 1)
	var yojimbo := _make_character(3, "Crane", 2.0, 2)
	var chars: Array = [local, samurai, yojimbo]
	var by_id: Dictionary = {1: local, 2: samurai, 3: yojimbo}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.0, "passed_down": 0.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_eq(result[3]["consequence"], KokuCascadeSystem.DISPOSITION_NO_STIPEND)
	assert_eq(yojimbo.disposition_values.get(2, 0), KokuCascadeSystem.DISPOSITION_NO_STIPEND)
	assert_false(yojimbo.disposition_values.has(1))


func test_indirect_retainer_shares_pool_with_direct() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var samurai := _make_character(2, "Crane", 2.0, 1)
	var yojimbo := _make_character(3, "Crane", 2.0, 2)
	var chars: Array = [champ, samurai, yojimbo]
	var by_id: Dictionary = {1: champ, 2: samurai, 3: yojimbo}
	# Pool = 0.02 koku units * 500 = 10.0 individual koku
	# Demand: samurai direct (5.0) + yojimbo indirect (0.6) = 5.6
	# Pool 10.0 > 5.6 → ratio = 1.0
	var lord_pools: Dictionary = {
		1: {"tier": "clan_champion", "retained": 4.0, "passed_down": 0.02},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_almost_eq(result[2]["actual_payment"], 5.0, 0.01)
	assert_almost_eq(result[3]["actual_payment"], 0.6, 0.01)


func test_indirect_retainer_insufficient_pool_proportional() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var samurai := _make_character(2, "Crane", 2.0, 1)
	var yojimbo := _make_character(3, "Crane", 2.0, 2)
	var chars: Array = [champ, samurai, yojimbo]
	var by_id: Dictionary = {1: champ, 2: samurai, 3: yojimbo}
	# Pool = 0.0056 koku units * 500 = 2.8 individual koku
	# Demand: 5.0 + 0.6 = 5.6. Ratio = 2.8 / 5.6 = 0.5
	var lord_pools: Dictionary = {
		1: {"tier": "clan_champion", "retained": 4.0, "passed_down": 0.0056},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_almost_eq(result[2]["ratio"], 0.5, 0.01)
	assert_almost_eq(result[3]["ratio"], 0.5, 0.01)
	assert_almost_eq(result[2]["actual_payment"], 2.5, 0.01)
	assert_almost_eq(result[3]["actual_payment"], 0.3, 0.01)


func test_deep_chain_indirect_retainer() -> void:
	var local := _make_character(1, "Crane", 4.0)
	var a := _make_character(2, "Crane", 2.0, 1)
	var b := _make_character(3, "Crane", 2.0, 2)
	var c := _make_character(4, "Crane", 2.0, 3)
	var chars: Array = [local, a, b, c]
	var by_id: Dictionary = {1: local, 2: a, 3: b, 4: c}
	var lord_pools: Dictionary = {
		1: {"tier": "local_daimyo", "retained": 0.5, "passed_down": 3.0},
	}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_false(result[2]["is_indirect"])
	assert_true(result[3]["is_indirect"])
	assert_true(result[4]["is_indirect"])
	assert_almost_eq(result[2]["base_stipend"], 1.0, 0.01)
	assert_almost_eq(result[3]["base_stipend"], 0.6, 0.01)
	assert_almost_eq(result[4]["base_stipend"], 0.6, 0.01)


func test_no_funding_lord_no_stipend() -> void:
	var ronin := _make_character(1, "Crane", 2.0)
	var retainer := _make_character(2, "Crane", 2.0, 1)
	var chars: Array = [ronin, retainer]
	var by_id: Dictionary = {1: ronin, 2: retainer}
	var lord_pools: Dictionary = {}
	var result: Dictionary = KokuCascadeSystem._pay_individual_stipends(
		lord_pools, chars, by_id,
	)
	assert_false(result.has(2))


func test_find_funding_lord_direct() -> void:
	var lord_pools: Dictionary = {10: {"passed_down": 1.0}}
	var c := _make_character(1, "Crane", 2.0, 10)
	var by_id: Dictionary = {1: c}
	var fid: int = KokuCascadeSystem._find_funding_lord_id(1, by_id, lord_pools)
	assert_eq(fid, 10)


func test_find_funding_lord_two_hops() -> void:
	var lord_pools: Dictionary = {10: {"passed_down": 1.0}}
	var a := _make_character(1, "Crane", 2.0, 5)
	var b := _make_character(5, "Crane", 2.0, 10)
	var by_id: Dictionary = {1: a, 5: b}
	var fid: int = KokuCascadeSystem._find_funding_lord_id(1, by_id, lord_pools)
	assert_eq(fid, 10)


func test_find_funding_lord_no_chain() -> void:
	var lord_pools: Dictionary = {10: {"passed_down": 1.0}}
	var a := _make_character(1, "Crane", 2.0, 5)
	var by_id: Dictionary = {1: a}
	var fid: int = KokuCascadeSystem._find_funding_lord_id(1, by_id, lord_pools)
	assert_eq(fid, -1)


func test_find_funding_lord_lordless() -> void:
	var lord_pools: Dictionary = {10: {"passed_down": 1.0}}
	var a := _make_character(1, "Crane", 2.0, -1)
	var by_id: Dictionary = {1: a}
	var fid: int = KokuCascadeSystem._find_funding_lord_id(1, by_id, lord_pools)
	assert_eq(fid, -1)


# -- Full Flow Integration -----------------------------------------------------

func test_no_champion_no_cascade() -> void:
	var local := _make_character(2, "Crane", 4.0)
	var settlement := _make_settlement(100, 10, 12.0)
	var clan := _make_clan("Crane", [10])
	var chars: Array = [local]
	var by_id: Dictionary = {2: local}
	var settlements: Array = [settlement]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem.process_monthly_koku_flow(
		chars, by_id, settlements, clans, 3,
	)
	# Pool goes up but nobody to distribute it
	assert_almost_eq(result["upward"]["Crane"], 4.0, 0.001)
	assert_eq(result["downward"].size(), 0)


# -- Audit: Dead character guards (2026-05-23) ---------------------------------

func test_stipend_skips_dead_retainers() -> void:
	var lord := _make_character(1, "Crane", 7.0)
	lord.koku = 100.0
	var dead_retainer := _make_character(2, "Crane", 3.0, 1)
	dead_retainer.wounds_taken = 999
	dead_retainer.koku = 0.0
	var chars: Array = [lord, dead_retainer]
	KokuCascadeSystem.distribute_individual_stipends(chars, {1: {"passed_down": 50.0}})
	assert_eq(dead_retainer.koku, 0.0,
		"Dead retainer should not receive stipend")
