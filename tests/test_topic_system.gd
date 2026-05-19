extends GutTest


func _make_crisis(tier: TopicData.Tier, momentum: float = 20.0, provinces: int = 1) -> TopicData:
	var prov: Array[int] = []
	for i in range(provinces):
		prov.append(i + 1)
	return TopicMomentumSystem.create_topic(
		1, "Test Crisis", tier, TopicData.Category.MILITARY, 0, momentum, prov
	)


func _make_tier4(momentum: float = 20.0) -> TopicData:
	return TopicMomentumSystem.create_topic(
		1, "Test Topic", TopicData.Tier.TIER_4, TopicData.Category.PERSONAL, 0, momentum
	)


# -- Momentum Levels -----------------------------------------------------------

func test_momentum_level_rumor():
	assert_eq(TopicMomentumSystem.get_momentum_level(5), TopicMomentumSystem.MomentumLevel.RUMOR)

func test_momentum_level_minor():
	assert_eq(TopicMomentumSystem.get_momentum_level(15), TopicMomentumSystem.MomentumLevel.MINOR_TOPIC)

func test_momentum_level_secondary():
	assert_eq(TopicMomentumSystem.get_momentum_level(40), TopicMomentumSystem.MomentumLevel.SECONDARY_TOPIC)

func test_momentum_level_major():
	assert_eq(TopicMomentumSystem.get_momentum_level(60), TopicMomentumSystem.MomentumLevel.MAJOR_TOPIC)

func test_momentum_level_unavoidable():
	assert_eq(TopicMomentumSystem.get_momentum_level(80), TopicMomentumSystem.MomentumLevel.UNAVOIDABLE_CRISIS)

func test_momentum_level_boundary_10():
	assert_eq(TopicMomentumSystem.get_momentum_level(10), TopicMomentumSystem.MomentumLevel.RUMOR)

func test_momentum_level_boundary_11():
	assert_eq(TopicMomentumSystem.get_momentum_level(11), TopicMomentumSystem.MomentumLevel.MINOR_TOPIC)


# -- Scope Multiplier ----------------------------------------------------------

func test_scope_1_province():
	assert_eq(TopicMomentumSystem.get_scope_multiplier(1), 1.0)

func test_scope_3_provinces():
	assert_eq(TopicMomentumSystem.get_scope_multiplier(3), 1.5)

func test_scope_5_provinces():
	assert_eq(TopicMomentumSystem.get_scope_multiplier(5), 2.0)

func test_scope_10_provinces():
	assert_eq(TopicMomentumSystem.get_scope_multiplier(10), 3.0)


# -- Crisis Momentum Gain ------------------------------------------------------

func test_tier1_base_gain():
	var t := _make_crisis(TopicData.Tier.TIER_1, 0.0)
	assert_almost_eq(TopicMomentumSystem.calculate_momentum_gain(t), 3.0, 0.001)

func test_tier2_base_gain():
	var t := _make_crisis(TopicData.Tier.TIER_2, 0.0)
	assert_almost_eq(TopicMomentumSystem.calculate_momentum_gain(t), 2.0, 0.001)

func test_tier3_base_gain():
	var t := _make_crisis(TopicData.Tier.TIER_3, 0.0)
	assert_almost_eq(TopicMomentumSystem.calculate_momentum_gain(t), 1.0, 0.001)

func test_tier4_no_crisis_gain():
	var t := _make_tier4()
	assert_eq(TopicMomentumSystem.calculate_momentum_gain(t), 0.0)

func test_tier2_with_scope():
	var t := _make_crisis(TopicData.Tier.TIER_2, 0.0, 5)
	assert_almost_eq(TopicMomentumSystem.calculate_momentum_gain(t), 4.0, 0.001)

func test_tier1_with_large_scope():
	var t := _make_crisis(TopicData.Tier.TIER_1, 0.0, 8)
	assert_almost_eq(TopicMomentumSystem.calculate_momentum_gain(t), 9.0, 0.001)


# -- Advance Crisis Momentum ---------------------------------------------------

func test_advance_increases_momentum():
	var t := _make_crisis(TopicData.Tier.TIER_2, 10.0)
	var gain: float = TopicMomentumSystem.advance_crisis_momentum(t)
	assert_almost_eq(t.momentum, 12.0, 0.001)
	assert_almost_eq(gain, 2.0, 0.001)

func test_advance_caps_at_100():
	var t := _make_crisis(TopicData.Tier.TIER_1, 99.0, 8)
	TopicMomentumSystem.advance_crisis_momentum(t)
	assert_eq(t.momentum, 100.0)

func test_advance_resolved_topic_no_gain():
	var t := _make_crisis(TopicData.Tier.TIER_1, 50.0)
	t.resolved = true
	var gain: float = TopicMomentumSystem.advance_crisis_momentum(t)
	assert_eq(gain, 0.0)
	assert_eq(t.momentum, 50.0)


# -- Tier 4 Decay --------------------------------------------------------------

func test_tier4_decays_without_discussion():
	var t := _make_tier4(20.0)
	var change: float = TopicMomentumSystem.decay_tier4_topic(t)
	assert_almost_eq(t.momentum, 18.0, 0.001)
	assert_almost_eq(change, -2.0, 0.001)

func test_tier4_holds_with_discussion():
	var t := _make_tier4(20.0)
	t.discussion_count_this_day = 2
	TopicMomentumSystem.decay_tier4_topic(t)
	assert_almost_eq(t.momentum, 20.0, 0.001)

func test_tier4_gains_with_heavy_discussion():
	var t := _make_tier4(20.0)
	t.discussion_count_this_day = 5
	TopicMomentumSystem.decay_tier4_topic(t)
	assert_almost_eq(t.momentum, 23.0, 0.001)

func test_tier4_does_not_go_below_zero():
	var t := _make_tier4(1.0)
	TopicMomentumSystem.decay_tier4_topic(t)
	assert_eq(t.momentum, 0.0)

func test_tier4_resets_discussion_count():
	var t := _make_tier4(20.0)
	t.discussion_count_this_day = 3
	TopicMomentumSystem.decay_tier4_topic(t)
	assert_eq(t.discussion_count_this_day, 0)

func test_tier4_expired_at_zero():
	var t := _make_tier4(0.0)
	assert_true(TopicMomentumSystem.is_topic_expired(t))

func test_tier4_not_expired_above_zero():
	var t := _make_tier4(5.0)
	assert_false(TopicMomentumSystem.is_topic_expired(t))

func test_crisis_not_expired():
	var t := _make_crisis(TopicData.Tier.TIER_2, 0.0)
	assert_false(TopicMomentumSystem.is_topic_expired(t))


# -- Personal Relevance --------------------------------------------------------

func test_relevance_own_clan():
	var t := _make_crisis(TopicData.Tier.TIER_2, 50.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.OWN, false, false
	)
	assert_almost_eq(rel, 100.0, 0.001)

func test_relevance_enemy_clan():
	var t := _make_crisis(TopicData.Tier.TIER_2, 50.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.ENEMY, false, false
	)
	assert_almost_eq(rel, 37.5, 0.001)

func test_relevance_own_family_bonus():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.OWN, true, false
	)
	assert_almost_eq(rel, 80.0, 0.001)

func test_relevance_same_clan_family_bonus():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.OWN, false, true
	)
	assert_almost_eq(rel, 70.0, 0.001)

func test_relevance_tier1_minimum():
	var t := _make_crisis(TopicData.Tier.TIER_1, 10.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.ENEMY, false, false
	)
	assert_true(rel >= 50.0)

func test_relevance_tier3_maximum():
	var t := _make_crisis(TopicData.Tier.TIER_3, 80.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.OWN, true, false
	)
	assert_true(rel <= 60.0)

func test_relevance_tier2_no_minimum():
	var t := _make_crisis(TopicData.Tier.TIER_2, 5.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.DISTANT, false, false
	)
	assert_almost_eq(rel, 5.0, 0.001)

func test_relevance_clamped_at_100():
	var t := _make_crisis(TopicData.Tier.TIER_1, 90.0)
	var rel: float = TopicMomentumSystem.calculate_personal_relevance(
		t, TopicMomentumSystem.ClanRelation.OWN, true, false
	)
	assert_eq(rel, 100.0)


# -- Position Resistance -------------------------------------------------------

func test_resistance_zero_relevance():
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 0.0)
	assert_almost_eq(result, 12.0, 0.001)

func test_resistance_50_relevance():
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 50.0)
	assert_almost_eq(result, 8.0, 0.001)

func test_resistance_100_relevance():
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 100.0)
	assert_almost_eq(result, 6.0, 0.001)

func test_resistance_60_relevance():
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 60.0)
	assert_almost_eq(result, 7.5, 0.001)


# -- Position Weight -----------------------------------------------------------

func test_weight_champion_full_relevance():
	var w: float = TopicMomentumSystem.calculate_position_weight(7.0, 100.0)
	assert_almost_eq(w, 14.0, 0.001)

func test_weight_daimyo_low_relevance():
	var w: float = TopicMomentumSystem.calculate_position_weight(3.0, 25.0)
	assert_almost_eq(w, 1.5, 0.001)

func test_weight_zero_relevance():
	var w: float = TopicMomentumSystem.calculate_position_weight(5.0, 0.0)
	assert_eq(w, 0.0)


# -- Aggregate Weighted Opinion ------------------------------------------------

func test_aggregate_basic():
	var positions: Array[float] = [50.0, -20.0]
	var weights: Array[float] = [10.0, 5.0]
	var result: float = TopicMomentumSystem.calculate_aggregate_opinion(positions, weights)
	assert_almost_eq(result, 26.667, 0.01)

func test_aggregate_empty():
	var positions: Array[float] = []
	var weights: Array[float] = []
	assert_eq(TopicMomentumSystem.calculate_aggregate_opinion(positions, weights), 0.0)

func test_aggregate_zero_weights():
	var positions: Array[float] = [50.0, -20.0]
	var weights: Array[float] = [0.0, 0.0]
	assert_eq(TopicMomentumSystem.calculate_aggregate_opinion(positions, weights), 0.0)


# -- Daily Tick Processing -----------------------------------------------------

func test_daily_tick_advances_crisis():
	var t := _make_crisis(TopicData.Tier.TIER_2, 10.0)
	var topics: Array[TopicData] = [t]
	var result: Dictionary = TopicMomentumSystem.process_daily_tick(topics)
	assert_almost_eq(t.momentum, 12.0, 0.001)
	assert_true(result["momentum_changes"].has(t.topic_id))

func test_daily_tick_decays_tier4():
	var t := _make_tier4(5.0)
	var topics: Array[TopicData] = [t]
	var result: Dictionary = TopicMomentumSystem.process_daily_tick(topics)
	assert_almost_eq(t.momentum, 3.0, 0.001)

func test_daily_tick_expires_tier4():
	var t := _make_tier4(1.0)
	var topics: Array[TopicData] = [t]
	var result: Dictionary = TopicMomentumSystem.process_daily_tick(topics)
	assert_true(t.topic_id in result["expired_topic_ids"])

func test_daily_tick_skips_resolved():
	var t := _make_crisis(TopicData.Tier.TIER_2, 50.0)
	t.resolved = true
	var topics: Array[TopicData] = [t]
	var result: Dictionary = TopicMomentumSystem.process_daily_tick(topics)
	assert_eq(result["momentum_changes"].size(), 0)

func test_daily_tick_mixed_topics():
	var crisis := _make_crisis(TopicData.Tier.TIER_1, 30.0)
	crisis.topic_id = 1
	var social := _make_tier4(10.0)
	social.topic_id = 2
	var topics: Array[TopicData] = [crisis, social]
	var result: Dictionary = TopicMomentumSystem.process_daily_tick(topics)
	assert_almost_eq(crisis.momentum, 33.0, 0.001)
	assert_almost_eq(social.momentum, 8.0, 0.001)
	assert_eq(result["momentum_changes"].size(), 2)


# -- Topic Factory & Resolution ------------------------------------------------

func test_create_topic():
	var provinces: Array[int] = [1, 2, 3]
	var t: TopicData = TopicMomentumSystem.create_topic(
		42, "War in Lion", TopicData.Tier.TIER_2, TopicData.Category.MILITARY,
		100, 15.0, provinces, "Lion", "Akodo"
	)
	assert_eq(t.topic_id, 42)
	assert_eq(t.tier, TopicData.Tier.TIER_2)
	assert_eq(t.category, TopicData.Category.MILITARY)
	assert_eq(t.provinces_affected.size(), 3)
	assert_almost_eq(t.momentum, 15.0, 0.001)

func test_resolve_topic():
	var t := _make_crisis(TopicData.Tier.TIER_2, 80.0)
	TopicMomentumSystem.resolve_topic(t)
	assert_true(t.resolved)
	assert_eq(t.momentum, 0.0)


func test_create_topic_with_type_and_variant():
	var t: TopicData = TopicMomentumSystem.create_topic(
		10, "A Death", TopicData.Tier.TIER_4, TopicData.Category.PERSONAL,
		5, 15.0, [], "", "", -1, "death", "suspicious"
	)
	assert_eq(t.topic_type, "death")
	assert_eq(t.variant, "suspicious")


# -- Discussion Count Wiring ---------------------------------------------------

func test_increment_discussion_counts_basic():
	var t1 := _make_tier4(20.0)
	t1.topic_id = 1
	var t2 := _make_tier4(20.0)
	t2.topic_id = 2
	var topics: Array[TopicData] = [t1, t2]
	var discussed: Array[int] = [1, 1, 2]
	TopicMomentumSystem.increment_discussion_counts(topics, discussed)
	assert_eq(t1.discussion_count_this_day, 2)
	assert_eq(t2.discussion_count_this_day, 1)


func test_increment_discussion_counts_unknown_id_ignored():
	var t1 := _make_tier4(20.0)
	t1.topic_id = 1
	var topics: Array[TopicData] = [t1]
	var discussed: Array[int] = [1, 99]
	TopicMomentumSystem.increment_discussion_counts(topics, discussed)
	assert_eq(t1.discussion_count_this_day, 1)


func test_increment_discussion_counts_empty():
	var t1 := _make_tier4(20.0)
	t1.topic_id = 1
	var topics: Array[TopicData] = [t1]
	var discussed: Array[int] = []
	TopicMomentumSystem.increment_discussion_counts(topics, discussed)
	assert_eq(t1.discussion_count_this_day, 0)


# -- Public Knowledge Broadcast ------------------------------------------------

func _make_char(id: int, clan: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.topic_pool = []
	c.topic_positions = {}
	c.disposition_values = {}
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_province(id: int, clan: String = "", adjacent: Array[int] = []) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.clan = clan
	p.adjacent_province_ids = adjacent
	return p


func test_broadcast_rumor_no_spread():
	var t := _make_crisis(TopicData.Tier.TIER_2, 5.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {10: "Crane"}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 0)
	assert_eq(c.topic_pool.size(), 0)


func test_broadcast_minor_affected_province():
	var t := _make_crisis(TopicData.Tier.TIER_2, 15.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {10: "Crane"}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 1)
	assert_true(1 in c.topic_pool)


func test_broadcast_minor_non_affected_province_excluded():
	var t := _make_crisis(TopicData.Tier.TIER_2, 15.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 20}
	var prov_clan: Dictionary = {10: "Crane", 20: "Lion"}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 0)


func test_broadcast_secondary_adjacent_province():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	var p10 := _make_province(10, "Crane", [20])
	var p20 := _make_province(20, "Lion", [10])
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 20}
	var prov_clan: Dictionary = {10: "Crane", 20: "Lion"}
	var provinces: Dictionary = {10: p10, 20: p20}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan, provinces
	)
	assert_eq(results.size(), 1)
	assert_true(1 in c.topic_pool)


func test_broadcast_secondary_non_adjacent_excluded():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	var p10 := _make_province(10, "Crane", [])
	var p20 := _make_province(20, "Lion", [])
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 20}
	var prov_clan: Dictionary = {10: "Crane", 20: "Lion"}
	var provinces: Dictionary = {10: p10, 20: p20}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan, provinces
	)
	assert_eq(results.size(), 0)


func test_broadcast_major_same_clan():
	var t := _make_crisis(TopicData.Tier.TIER_1, 55.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	t.clan_involved = "Crane"
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 20}
	var prov_clan: Dictionary = {10: "Crane", 20: "Crane"}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 1)


func test_broadcast_major_different_clan_excluded():
	var t := _make_crisis(TopicData.Tier.TIER_1, 55.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	t.clan_involved = "Crane"
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 30}
	var prov_clan: Dictionary = {10: "Crane", 30: "Dragon"}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 0)


func test_broadcast_unavoidable_all_characters():
	var t := _make_crisis(TopicData.Tier.TIER_1, 80.0)
	t.topic_id = 1
	var c1 := _make_char(1)
	var c2 := _make_char(2)
	var chars: Array[L5RCharacterData] = [c1, c2]
	var char_prov: Dictionary = {1: 10, 2: 99}
	var prov_clan: Dictionary = {}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 2)
	assert_true(1 in c1.topic_pool)
	assert_true(1 in c2.topic_pool)


func test_broadcast_skips_already_known():
	var t := _make_crisis(TopicData.Tier.TIER_1, 80.0)
	t.topic_id = 1
	var c := _make_char(1)
	c.topic_pool = [1]
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {}
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan
	)
	assert_eq(results.size(), 0)


func test_broadcast_skips_resolved():
	var t := _make_crisis(TopicData.Tier.TIER_1, 80.0)
	t.topic_id = 1
	t.resolved = true
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, {1: 10}, {}
	)
	assert_eq(results.size(), 0)


# -- Adjacency Check -----------------------------------------------------------

func test_is_adjacent_to_affected_true():
	var p1 := _make_province(1, "Crane", [2, 3])
	var p2 := _make_province(2, "Lion", [1])
	var provinces: Dictionary = {1: p1, 2: p2}
	var affected: Array[int] = [2]
	assert_true(TopicMomentumSystem._is_adjacent_to_affected(1, affected, provinces))


func test_is_adjacent_to_affected_false():
	var p1 := _make_province(1, "Crane", [3])
	var provinces: Dictionary = {1: p1}
	var affected: Array[int] = [2]
	assert_false(TopicMomentumSystem._is_adjacent_to_affected(1, affected, provinces))


func test_is_adjacent_to_affected_unknown_province():
	var affected: Array[int] = [2]
	assert_false(TopicMomentumSystem._is_adjacent_to_affected(99, affected, {}))


# -- Starting Position Calculation ---------------------------------------------

func test_starting_position_neutral_no_virtue():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.subject_character_id = 5
	t.subject_role = "NEUTRAL"
	t.topic_type = "battle_outcome"
	t.variant = "victory"
	var dispositions: Dictionary = {5: 40}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, 5.0, 0.001)


func test_starting_position_beneficiary():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.subject_character_id = 5
	t.subject_role = "BENEFICIARY"
	var dispositions: Dictionary = {5: 60}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, 30.0, 0.001)


func test_starting_position_victim():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.subject_character_id = 5
	t.subject_role = "VICTIM"
	var dispositions: Dictionary = {5: 60}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, -30.0, 0.001)


func test_starting_position_perpetrator():
	var t := _make_crisis(TopicData.Tier.TIER_2, 30.0)
	t.subject_character_id = 5
	t.subject_role = "PERPETRATOR"
	var dispositions: Dictionary = {5: 40}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, -20.0, 0.001)


func test_starting_position_with_bushido_modifier():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	t.topic_type = "betrayal"
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, -15.0, 0.001)


func test_starting_position_with_shourido_modifier():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	t.topic_type = "spy_uncovered"
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	)
	assert_almost_eq(pos, 10.0, 0.001)


func test_starting_position_with_variant():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	t.topic_type = "death"
	t.variant = "suspicious"
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, -8.0, 0.001)


func test_starting_position_variant_fallback_to_type():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	t.topic_type = "betrayal"
	t.variant = "unknown_variant"
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, -15.0, 0.001)


func test_starting_position_both_virtues():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	t.topic_type = "betrayal"
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.DOSATSU
	)
	assert_almost_eq(pos, -7.0, 0.001)


func test_starting_position_clamped_positive():
	var t := _make_tier4(20.0)
	t.subject_character_id = 5
	t.subject_role = "BENEFICIARY"
	var dispositions: Dictionary = {5: 100}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, 50.0, 0.001)


func test_starting_position_no_subject():
	var t := _make_tier4(20.0)
	t.subject_character_id = -1
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, {}, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, 0.0, 0.001)


func test_starting_position_unknown_subject_id():
	var t := _make_tier4(20.0)
	t.subject_character_id = 99
	t.subject_role = "BENEFICIARY"
	var dispositions: Dictionary = {}
	var pos: float = TopicMomentumSystem.calculate_starting_position(
		t, dispositions, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(pos, 0.0, 0.001)


# =============================================================================
# Public Knowledge — Knowledge Entry Creation (s55.12)
# =============================================================================


func test_broadcast_creates_knowledge_entry():
	var t := _make_crisis(TopicData.Tier.TIER_2, 15.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	c.knowledge_pool = []
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {10: "Crane"}
	TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan, {}, 3
	)
	assert_eq(c.knowledge_pool.size(), 1)
	assert_eq(c.knowledge_pool[0].source, Enums.KnowledgeSource.PUBLIC_KNOWLEDGE)
	assert_eq(c.knowledge_pool[0].entry_type, "topic_learned")
	assert_eq(c.knowledge_pool[0].data.get("topic", -1), 1)
	assert_eq(c.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.FRESH)
	assert_eq(c.knowledge_pool[0].season_acquired, 3)


func test_broadcast_no_knowledge_entry_for_excluded_character():
	var t := _make_crisis(TopicData.Tier.TIER_2, 5.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	c.knowledge_pool = []
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {10: "Crane"}
	TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan, {}, 3
	)
	assert_eq(c.knowledge_pool.size(), 0)


func test_broadcast_no_duplicate_knowledge_entry():
	var t := _make_crisis(TopicData.Tier.TIER_2, 15.0)
	t.topic_id = 1
	t.provinces_affected = [10]
	var c := _make_char(1)
	c.topic_pool = [1]
	c.knowledge_pool = []
	var chars: Array[L5RCharacterData] = [c]
	var char_prov: Dictionary = {1: 10}
	var prov_clan: Dictionary = {10: "Crane"}
	TopicMomentumSystem.broadcast_public_knowledge(
		[t] as Array[TopicData], chars, char_prov, prov_clan, {}, 3
	)
	# Already in topic_pool → skipped, no knowledge entry either
	assert_eq(c.knowledge_pool.size(), 0)
