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


func _make_clan(name: String, pids: Array[int]) -> ClanData:
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
	var settlements: Array[SettlementData] = [s1]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	# Monthly share = 6.0 / 3 = 2.0
	assert_almost_eq(result["Crane"], 2.0, 0.001)
	assert_almost_eq(s1.koku_stockpile, 4.0, 0.001)


func test_pool_upward_multiple_settlements() -> void:
	var s1 := _make_settlement(1, 10, 9.0)
	var s2 := _make_settlement(2, 11, 3.0)
	var clan := _make_clan("Lion", [10, 11])
	var settlements: Array[SettlementData] = [s1, s2]
	var clans: Dictionary = {"Lion": clan}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	# (9 + 3) / 3 = 4.0
	assert_almost_eq(result["Lion"], 4.0, 0.001)


func test_pool_upward_different_clans() -> void:
	var s1 := _make_settlement(1, 10, 6.0)
	var s2 := _make_settlement(2, 20, 12.0)
	var crane := _make_clan("Crane", [10])
	var crab := _make_clan("Crab", [20])
	var settlements: Array[SettlementData] = [s1, s2]
	var clans: Dictionary = {"Crane": crane, "Crab": crab}
	var result: Dictionary = KokuCascadeSystem._pool_upward(settlements, clans, 3)
	assert_almost_eq(result["Crane"], 2.0, 0.001)
	assert_almost_eq(result["Crab"], 4.0, 0.001)


# -- Downward Cascade ----------------------------------------------------------

func test_champion_retains_40_percent() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var chars: Array[L5RCharacterData] = [champ]
	var by_id: Dictionary = {1: champ}
	var clan_pools: Dictionary = {"Crane": 10.0}
	var result: Dictionary = KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# Retains 40% of 10.0 = 4.0 koku units = 2000 individual koku
	assert_almost_eq(champ.koku, 2000.0, 0.1)
	assert_almost_eq(result[1]["retained"], 4.0, 0.001)
	assert_almost_eq(result[1]["passed_down"], 6.0, 0.001)


func test_generous_champion_retains_less() -> void:
	var champ := _make_character(1, "Crane", 7.0, -1, Enums.BushidoVirtue.JIN)
	var chars: Array[L5RCharacterData] = [champ]
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
	var chars: Array[L5RCharacterData] = [champ]
	var by_id: Dictionary = {1: champ}
	var clan_pools: Dictionary = {"Crane": 10.0}
	KokuCascadeSystem._cascade_downward(clan_pools, chars, by_id)
	# KYORYOKU = -10% modifier → retention goes from 40% to 50%
	# Retained = 10 * 0.50 = 5.0 → 2500 individual koku
	assert_almost_eq(champ.koku, 2500.0, 0.1)


func test_cascade_two_tiers() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var family := _make_character(2, "Crane", 6.0, 1)
	var chars: Array[L5RCharacterData] = [champ, family]
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
	var chars: Array[L5RCharacterData] = [champ, family, provincial, local]
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
	var chars: Array[L5RCharacterData] = [local, retainer]
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
	var chars: Array[L5RCharacterData] = [champ, retainer]
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
	var chars: Array[L5RCharacterData] = [local, r1, r2]
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
	var chars: Array[L5RCharacterData] = [local, retainer]
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


# -- Full Flow Integration -----------------------------------------------------

func test_full_flow_single_clan() -> void:
	var champ := _make_character(1, "Crane", 7.0)
	var local := _make_character(2, "Crane", 4.0, 1)
	var retainer := _make_character(3, "Crane", 2.0, 2)
	var settlement := _make_settlement(100, 10, 12.0)
	var clan := _make_clan("Crane", [10])
	var chars: Array[L5RCharacterData] = [champ, local, retainer]
	var by_id: Dictionary = {1: champ, 2: local, 3: retainer}
	var settlements: Array[SettlementData] = [settlement]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem.process_monthly_koku_flow(
		chars, by_id, settlements, clans, 3,
	)
	# Upward: 12 / 3 = 4.0 koku units pooled to Crane
	assert_almost_eq(result["upward"]["Crane"], 4.0, 0.001)
	# Champion gets some koku, retainer gets a stipend
	assert_true(champ.koku > 0.0)
	assert_true(retainer.koku > 0.0)


func test_no_champion_no_cascade() -> void:
	var local := _make_character(2, "Crane", 4.0)
	var settlement := _make_settlement(100, 10, 12.0)
	var clan := _make_clan("Crane", [10])
	var chars: Array[L5RCharacterData] = [local]
	var by_id: Dictionary = {2: local}
	var settlements: Array[SettlementData] = [settlement]
	var clans: Dictionary = {"Crane": clan}
	var result: Dictionary = KokuCascadeSystem.process_monthly_koku_flow(
		chars, by_id, settlements, clans, 3,
	)
	# Pool goes up but nobody to distribute it
	assert_almost_eq(result["upward"]["Crane"], 4.0, 0.001)
	assert_eq(result["downward"].size(), 0)
