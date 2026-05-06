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
