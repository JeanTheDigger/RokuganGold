extends GutTest


func _make_char(id: int, topics: Array[int] = [], clan: String = "", family: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.topic_pool = topics.duplicate()
	c.clan = clan
	c.family = family
	return c


func _make_topic(id: int, clan_involved: String = "", family_involved: String = "", momentum: float = 10.0, category: TopicData.Category = TopicData.Category.PERSONAL) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.clan_involved = clan_involved
	t.family_involved = family_involved
	t.momentum = momentum
	t.category = category
	return t


func _set_mutual_disposition(a: L5RCharacterData, b: L5RCharacterData, value: int) -> void:
	a.disposition_values[b.character_id] = value
	b.disposition_values[a.character_id] = value


# -- Probability Lookup --------------------------------------------------------

func test_chance_below_threshold_is_zero():
	assert_eq(DailyConversation.get_conversation_chance(10), 0)
	assert_eq(DailyConversation.get_conversation_chance(0), 0)
	assert_eq(DailyConversation.get_conversation_chance(-5), 0)

func test_chance_acquaintance_tier():
	assert_eq(DailyConversation.get_conversation_chance(11), 10)
	assert_eq(DailyConversation.get_conversation_chance(20), 10)
	assert_eq(DailyConversation.get_conversation_chance(30), 10)

func test_chance_friend_lower():
	assert_eq(DailyConversation.get_conversation_chance(31), 15)
	assert_eq(DailyConversation.get_conversation_chance(45), 15)

func test_chance_friend_upper():
	assert_eq(DailyConversation.get_conversation_chance(46), 20)
	assert_eq(DailyConversation.get_conversation_chance(60), 20)

func test_chance_trusted_ally_lower():
	assert_eq(DailyConversation.get_conversation_chance(61), 28)
	assert_eq(DailyConversation.get_conversation_chance(75), 28)

func test_chance_trusted_ally_upper():
	assert_eq(DailyConversation.get_conversation_chance(76), 35)
	assert_eq(DailyConversation.get_conversation_chance(90), 35)

func test_chance_devoted():
	assert_eq(DailyConversation.get_conversation_chance(91), 50)
	assert_eq(DailyConversation.get_conversation_chance(99), 50)

func test_chance_max_devoted():
	assert_eq(DailyConversation.get_conversation_chance(100), 65)


# -- Effective Disposition (uses lower of the two) -----------------------------

func test_effective_disposition_uses_minimum():
	var a := _make_char(1)
	var b := _make_char(2)
	a.disposition_values[2] = 50
	b.disposition_values[1] = 20
	assert_eq(DailyConversation.get_effective_disposition(a, b), 20)

func test_effective_disposition_symmetric():
	var a := _make_char(1)
	var b := _make_char(2)
	a.disposition_values[2] = 30
	b.disposition_values[1] = 30
	assert_eq(DailyConversation.get_effective_disposition(a, b), 30)

func test_effective_disposition_stranger():
	var a := _make_char(1)
	var b := _make_char(2)
	assert_eq(DailyConversation.get_effective_disposition(a, b), 0)


# -- Should Converse -----------------------------------------------------------

func test_should_converse_passes_under_chance():
	var a := _make_char(1)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)
	# Chance is 20%, roll of 5 should pass
	assert_true(DailyConversation.should_converse(a, b, 5))

func test_should_converse_fails_over_chance():
	var a := _make_char(1)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)
	# Chance is 20%, roll of 25 should fail
	assert_false(DailyConversation.should_converse(a, b, 25))

func test_should_converse_strangers_never():
	var a := _make_char(1)
	var b := _make_char(2)
	assert_false(DailyConversation.should_converse(a, b, 0))


# -- Topic Selection -----------------------------------------------------------

func test_select_topic_from_pool():
	var topics: Array[int] = [1, 2, 3]
	var c := _make_char(1, topics)
	var topic: int = DailyConversation.select_topic_to_share(c, 1)
	assert_eq(topic, 2)

func test_select_topic_empty_pool():
	var c := _make_char(1)
	var topic: int = DailyConversation.select_topic_to_share(c, 0)
	assert_eq(topic, -1)


# -- Topic Transfer ------------------------------------------------------------

func test_transfer_new_topic():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	var transferred: bool = DailyConversation.transfer_topic(a, b, 1)
	assert_true(transferred)
	assert_true(1 in b.topic_pool)

func test_transfer_duplicate_topic_fails():
	var topics: Array[int] = [1]
	var a := _make_char(1, topics)
	var b := _make_char(2, topics)
	var transferred: bool = DailyConversation.transfer_topic(a, b, 1)
	assert_false(transferred)

func test_transfer_empty_topic_fails():
	var a := _make_char(1)
	var b := _make_char(2)
	var transferred: bool = DailyConversation.transfer_topic(a, b, -1)
	assert_false(transferred)


# -- Disposition Bonus ---------------------------------------------------------

func test_disposition_bonus_applied():
	var a := _make_char(1)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 30)
	DailyConversation.apply_disposition_bonus(a, b)
	assert_eq(a.disposition_values[b.character_id], 31)
	assert_eq(b.disposition_values[a.character_id], 31)

func test_disposition_bonus_from_zero():
	var a := _make_char(1)
	var b := _make_char(2)
	DailyConversation.apply_disposition_bonus(a, b)
	assert_eq(a.disposition_values[b.character_id], 1)
	assert_eq(b.disposition_values[a.character_id], 1)


# -- Full Conversation Resolution ----------------------------------------------

func test_resolve_conversation_transfers_topics():
	var topics_a: Array[int] = [1]
	var topics_b: Array[int] = [2]
	var a := _make_char(1, topics_a)
	var b := _make_char(2, topics_b)
	_set_mutual_disposition(a, b, 50)

	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(result["topic_shared_by_a"], 1)
	assert_eq(result["topic_shared_by_b"], 2)
	assert_true(result["transferred_to_b"])
	assert_true(result["transferred_to_a"])
	assert_true(1 in b.topic_pool)
	assert_true(2 in a.topic_pool)

func test_resolve_conversation_adds_knowledge_entries():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(b.knowledge_pool.size(), 1)
	assert_eq(b.knowledge_pool[0].entry_type, "topic_learned")
	assert_eq(b.knowledge_pool[0].data["topic"], 1)
	assert_eq(b.knowledge_pool[0].data["from_character_id"], 1)

func test_resolve_conversation_no_knowledge_if_already_known():
	var topics: Array[int] = [1]
	var a := _make_char(1, topics)
	var b := _make_char(2, topics)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(b.knowledge_pool.size(), 0)

func test_resolve_conversation_grants_disposition():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(a.disposition_values[b.character_id], 51)
	assert_eq(b.disposition_values[a.character_id], 51)


# -- Settlement Resolution with Cap --------------------------------------------

func test_settlement_resolution_basic():
	var topics_a: Array[int] = [101]
	var topics_b: Array[int] = [102]
	var a := _make_char(1, topics_a)
	var b := _make_char(2, topics_b)
	_set_mutual_disposition(a, b, 50)

	var chars: Array[L5RCharacterData] = [a, b]
	# Roll of 5 passes (chance is 20%), then two topic rng values
	var rng: Array[int] = [5, 0, 0]
	var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(chars, rng, 5)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["char_a_id"], 1)
	assert_eq(results[0]["char_b_id"], 2)

func test_settlement_resolution_fails_roll():
	var a := _make_char(1)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)

	var chars: Array[L5RCharacterData] = [a, b]
	var rng: Array[int] = [99]
	var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(chars, rng, 5)
	assert_eq(results.size(), 0)

func test_settlement_resolution_cap_enforced():
	var chars: Array[L5RCharacterData] = []
	for i in range(8):
		var topics: Array[int] = [200 + i]
		var c := _make_char(i + 1, topics)
		chars.append(c)

	# All characters know each other well
	for i in range(chars.size()):
		for j in range(chars.size()):
			if i != j:
				chars[i].disposition_values[chars[j].character_id] = 80

	# All rolls pass (roll=0, chance is 35% at disp 80)
	var rng: Array[int] = []
	for i in range(100):
		rng.append(0)

	var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(chars, rng, 5)

	# Count how many times char 1 participated
	var char1_count: int = 0
	for r: Dictionary in results:
		if r["char_a_id"] == 1 or r["char_b_id"] == 1:
			char1_count += 1
	assert_true(char1_count <= DailyConversation.MAX_CONVERSATIONS_PER_DAY)

func test_settlement_resolution_strangers_skipped():
	var a := _make_char(1)
	var b := _make_char(2)
	# No disposition set — they are strangers

	var chars: Array[L5RCharacterData] = [a, b]
	var rng: Array[int] = [0, 0, 0]
	var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(chars, rng, 5)
	assert_eq(results.size(), 0)


# -- Relevance-Weighted Topic Selection ----------------------------------------

func test_select_topic_weighted_empty_pool():
	var c := _make_char(1, [], "Crab", "Hida")
	var topics_by_id: Dictionary = {}
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 0, topics_by_id)
	assert_eq(result, -1)

func test_select_topic_weighted_single_topic():
	var topics_arr: Array[int] = [10]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t := _make_topic(10, "Crab", "Hida", 50.0)
	var topics_by_id: Dictionary = {10: t}
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 42, topics_by_id)
	assert_eq(result, 10)

func test_select_topic_weighted_favors_relevant():
	var topics_arr: Array[int] = [1, 2, 3]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	# Topic 1: own clan+family → high relevance (momentum 80 × 2.0 + 20 = 180)
	var t1 := _make_topic(1, "Crab", "Hida", 80.0)
	# Topics 2,3: distant clan → low relevance (momentum 10 × 1.0 = 10)
	var t2 := _make_topic(2, "Crane", "Doji", 10.0)
	var t3 := _make_topic(3, "Lion", "Akodo", 10.0)
	var topics_by_id: Dictionary = {1: t1, 2: t2, 3: t3}

	var count_1: int = 0
	var count_other: int = 0
	for rng_val: int in range(100):
		var result: int = DailyConversation.select_topic_to_share_weighted(c, rng_val, topics_by_id)
		if result == 1:
			count_1 += 1
		else:
			count_other += 1
	# Topic 1 should be selected significantly more often (weight ~180 vs ~10 each)
	assert_true(count_1 > count_other, "Relevant topic should be selected more often")
	assert_true(count_1 > 80, "High-relevance topic should dominate selection")

func test_select_topic_weighted_missing_topic_data_uses_floor():
	var topics_arr: Array[int] = [1, 999]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t1 := _make_topic(1, "Crane", "", 5.0)
	# Topic 999 not in topics_by_id — should get floor weight of 1.0
	var topics_by_id: Dictionary = {1: t1}
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 999, topics_by_id)
	assert_true(result == 1 or result == 999)

func test_select_topic_weighted_deterministic():
	var topics_arr: Array[int] = [1, 2, 3]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t1 := _make_topic(1, "Crab", "Hida", 50.0)
	var t2 := _make_topic(2, "Crane", "", 20.0)
	var t3 := _make_topic(3, "Lion", "", 10.0)
	var topics_by_id: Dictionary = {1: t1, 2: t2, 3: t3}
	var first: int = DailyConversation.select_topic_to_share_weighted(c, 42, topics_by_id)
	var second: int = DailyConversation.select_topic_to_share_weighted(c, 42, topics_by_id)
	assert_eq(first, second, "Same rng_value should always produce same result")

func test_resolve_conversation_with_topics_by_id():
	var topics_a: Array[int] = [1, 2]
	var topics_b: Array[int] = [3]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, topics_b, "Crane", "Doji")
	_set_mutual_disposition(a, b, 50)

	var t1 := _make_topic(1, "Crab", "Hida", 80.0)
	var t2 := _make_topic(2, "Crane", "Doji", 5.0)
	var t3 := _make_topic(3, "Crane", "Doji", 20.0)
	var topics_by_id: Dictionary = {1: t1, 2: t2, 3: t3}

	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5, topics_by_id)
	assert_true(result.has("topic_shared_by_a"))
	assert_true(result.has("topic_shared_by_b"))
	assert_eq(result["topic_shared_by_b"], 3)

func test_resolve_conversation_backward_compat():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)
	# No topics_by_id — should use old random path
	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(result["topic_shared_by_a"], 1)

func test_settlement_resolution_with_topics_by_id():
	var topics_a: Array[int] = [101]
	var topics_b: Array[int] = [102]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, topics_b, "Crane", "Doji")
	_set_mutual_disposition(a, b, 50)

	var t1 := _make_topic(101, "Crab", "Hida", 50.0)
	var t2 := _make_topic(102, "Crane", "Doji", 50.0)
	var topics_by_id: Dictionary = {101: t1, 102: t2}

	var chars: Array[L5RCharacterData] = [a, b]
	var rng: Array[int] = [5, 0, 0]
	var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(
		chars, rng, 5, topics_by_id
	)
	assert_eq(results.size(), 1)


# -- Information Sharing Filter (s12.2 sensitivity gate) -----------------------

func test_sensitive_topic_blocked_below_trusted_ally():
	var topics_arr: Array[int] = [10]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t := _make_topic(10, "Crab", "Hida", 50.0, TopicData.Category.MILITARY)
	var topics_by_id: Dictionary = {10: t}
	# Disposition 50 = Friend tier → should NOT share military/sensitive topics
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 0, topics_by_id, 50)
	assert_eq(result, -1)

func test_sensitive_topic_allowed_at_trusted_ally():
	var topics_arr: Array[int] = [10]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t := _make_topic(10, "Crab", "Hida", 50.0, TopicData.Category.MILITARY)
	var topics_by_id: Dictionary = {10: t}
	# Disposition 61 = Trusted Ally → SHOULD share military/sensitive topics
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 0, topics_by_id, 61)
	assert_eq(result, 10)

func test_non_sensitive_topic_shared_at_acquaintance():
	var topics_arr: Array[int] = [10]
	var c := _make_char(1, topics_arr, "Crab", "Hida")
	var t := _make_topic(10, "Crab", "Hida", 50.0, TopicData.Category.PERSONAL)
	var topics_by_id: Dictionary = {10: t}
	# Disposition 15 = Acquaintance → should share non-sensitive topics
	var result: int = DailyConversation.select_topic_to_share_weighted(c, 0, topics_by_id, 15)
	assert_eq(result, 10)

func test_resolve_conversation_filters_sensitive_topics():
	var topics_a: Array[int] = [1, 2]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, [], "Crane", "Doji")
	_set_mutual_disposition(a, b, 40)

	# Topic 1 is military (sensitive), topic 2 is personal (not sensitive)
	var t1 := _make_topic(1, "Crab", "Hida", 80.0, TopicData.Category.MILITARY)
	var t2 := _make_topic(2, "Crab", "Hida", 5.0, TopicData.Category.PERSONAL)
	var topics_by_id: Dictionary = {1: t1, 2: t2}

	# At disposition 40 (Friend), military topics are filtered out
	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5, topics_by_id)
	# A should share topic 2 (personal), not topic 1 (military)
	assert_eq(result["topic_shared_by_a"], 2)

func test_resolve_conversation_shares_sensitive_at_high_disposition():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, [], "Crane", "Doji")
	_set_mutual_disposition(a, b, 70)

	var t1 := _make_topic(1, "Crab", "Hida", 80.0, TopicData.Category.MILITARY)
	var topics_by_id: Dictionary = {1: t1}

	# At disposition 70 (Trusted Ally), military topics should be shared
	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5, topics_by_id)
	assert_eq(result["topic_shared_by_a"], 1)
	assert_true(result["transferred_to_b"])


# -- Topic Momentum Refresh (s12.6 / s16.5) -----------------------------------

func test_conversation_refreshes_topic_momentum():
	var topics_a: Array[int] = [1]
	var topics_b: Array[int] = [1]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, topics_b, "Crane", "Doji")
	_set_mutual_disposition(a, b, 50)

	var t1 := _make_topic(1, "Crab", "Hida", 20.0)
	assert_eq(t1.discussion_count_this_day, 0)
	var topics_by_id: Dictionary = {1: t1}

	DailyConversation.resolve_conversation(a, b, 0, 0, 5, topics_by_id)
	# Both characters shared topic 1 → discussed twice (once by each sharer)
	assert_eq(t1.discussion_count_this_day, 2)

func test_conversation_refreshes_new_topic_momentum():
	var topics_a: Array[int] = [1]
	var a := _make_char(1, topics_a, "Crab", "Hida")
	var b := _make_char(2, [], "Crane", "Doji")
	_set_mutual_disposition(a, b, 50)

	var t1 := _make_topic(1, "Crab", "Hida", 20.0)
	var topics_by_id: Dictionary = {1: t1}

	DailyConversation.resolve_conversation(a, b, 0, 0, 5, topics_by_id)
	# Topic 1 was shared by A → increment once (B has no topics to share)
	assert_eq(t1.discussion_count_this_day, 1)
