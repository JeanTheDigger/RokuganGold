extends GutTest


func _make_char(id: int, topics: Array[String] = []) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.topic_pool = topics.duplicate()
	return c


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
	var topics: Array[String] = ["war_in_lion", "crane_scandal", "trade_deal"]
	var c := _make_char(1, topics)
	var topic: String = DailyConversation.select_topic_to_share(c, 1)
	assert_eq(topic, "crane_scandal")

func test_select_topic_empty_pool():
	var c := _make_char(1)
	var topic: String = DailyConversation.select_topic_to_share(c, 0)
	assert_eq(topic, "")


# -- Topic Transfer ------------------------------------------------------------

func test_transfer_new_topic():
	var topics_a: Array[String] = ["war_in_lion"]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	var transferred: bool = DailyConversation.transfer_topic(a, b, "war_in_lion")
	assert_true(transferred)
	assert_true("war_in_lion" in b.topic_pool)

func test_transfer_duplicate_topic_fails():
	var topics: Array[String] = ["war_in_lion"]
	var a := _make_char(1, topics)
	var b := _make_char(2, topics)
	var transferred: bool = DailyConversation.transfer_topic(a, b, "war_in_lion")
	assert_false(transferred)

func test_transfer_empty_topic_fails():
	var a := _make_char(1)
	var b := _make_char(2)
	var transferred: bool = DailyConversation.transfer_topic(a, b, "")
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
	var topics_a: Array[String] = ["war_in_lion"]
	var topics_b: Array[String] = ["crane_scandal"]
	var a := _make_char(1, topics_a)
	var b := _make_char(2, topics_b)
	_set_mutual_disposition(a, b, 50)

	var result: Dictionary = DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(result["topic_shared_by_a"], "war_in_lion")
	assert_eq(result["topic_shared_by_b"], "crane_scandal")
	assert_true(result["transferred_to_b"])
	assert_true(result["transferred_to_a"])
	assert_true("war_in_lion" in b.topic_pool)
	assert_true("crane_scandal" in a.topic_pool)

func test_resolve_conversation_adds_knowledge_entries():
	var topics_a: Array[String] = ["war_in_lion"]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(b.knowledge_pool.size(), 1)
	assert_eq(b.knowledge_pool[0]["entry_type"], "topic_learned")
	assert_eq(b.knowledge_pool[0]["data"]["topic"], "war_in_lion")
	assert_eq(b.knowledge_pool[0]["data"]["from_character_id"], 1)

func test_resolve_conversation_no_knowledge_if_already_known():
	var topics: Array[String] = ["war_in_lion"]
	var a := _make_char(1, topics)
	var b := _make_char(2, topics)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(b.knowledge_pool.size(), 0)

func test_resolve_conversation_grants_disposition():
	var topics_a: Array[String] = ["war_in_lion"]
	var a := _make_char(1, topics_a)
	var b := _make_char(2)
	_set_mutual_disposition(a, b, 50)

	DailyConversation.resolve_conversation(a, b, 0, 0, 5)
	assert_eq(a.disposition_values[b.character_id], 51)
	assert_eq(b.disposition_values[a.character_id], 51)


# -- Settlement Resolution with Cap --------------------------------------------

func test_settlement_resolution_basic():
	var topics_a: Array[String] = ["topic_1"]
	var topics_b: Array[String] = ["topic_2"]
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
		var topics: Array[String] = ["topic_" + str(i)]
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
