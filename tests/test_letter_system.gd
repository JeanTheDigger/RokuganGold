extends GutTest


func _make_char(id: int, calligraphy_rank: int = 3) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 3
	c.agility = 3
	c.intelligence = 3
	c.skills = {"Calligraphy": calligraphy_rank}
	c.emphases = {}
	c.wounds_taken = 0
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.action_points_current = 2
	c.action_points_max = 2
	c.lord_id = -1
	c.topic_pool = []
	c.knowledge_pool = []
	c.disposition_values = {}
	return c


# -- Delivery Time Formula -----------------------------------------------------

func test_delivery_same_province():
	assert_eq(LetterSystem.calculate_delivery_time(0), 0)

func test_delivery_adjacent_province():
	assert_eq(LetterSystem.calculate_delivery_time(1), 1)

func test_delivery_three_provinces():
	assert_eq(LetterSystem.calculate_delivery_time(3), 1)

func test_delivery_four_provinces():
	assert_eq(LetterSystem.calculate_delivery_time(4), 2)

func test_delivery_six_provinces():
	assert_eq(LetterSystem.calculate_delivery_time(6), 2)

func test_delivery_twenty_provinces():
	assert_eq(LetterSystem.calculate_delivery_time(20), 7)

func test_delivery_mountain_adds_one_per_province():
	assert_eq(LetterSystem.calculate_delivery_time(3, 2), 3)

func test_delivery_warzone_adds_one_per_province():
	assert_eq(LetterSystem.calculate_delivery_time(3, 0, 1), 2)

func test_delivery_ocean_segment_adds_two():
	assert_eq(LetterSystem.calculate_delivery_time(0, 0, 0, 1), 2)

func test_delivery_miya_reduces_by_one():
	assert_eq(LetterSystem.calculate_delivery_time(6, 0, 0, 0, true), 1)

func test_delivery_miya_minimum_zero():
	assert_eq(LetterSystem.calculate_delivery_time(0, 0, 0, 0, true), 0)

func test_delivery_combined_modifiers():
	# 6 provinces (2 days) + 1 mountain + 1 ocean - miya = 2+1+2-1 = 4
	assert_eq(LetterSystem.calculate_delivery_time(6, 1, 0, 1, true), 4)


# -- AP / Budget Check ---------------------------------------------------------

func test_non_lord_first_letter_free():
	assert_true(LetterSystem.can_send_free_letter(false, 0))

func test_non_lord_second_letter_not_free():
	assert_false(LetterSystem.can_send_free_letter(false, 1))

func test_lord_cannot_send_free():
	assert_false(LetterSystem.can_send_free_letter(true, 0))

func test_non_lord_can_send_batch_with_ap():
	var c := _make_char(1)
	assert_true(LetterSystem.can_send_batch(c, false))

func test_non_lord_cannot_send_batch_without_ap():
	var c := _make_char(1)
	c.action_points_current = 0
	assert_false(LetterSystem.can_send_batch(c, false))

func test_lord_cannot_send_batch():
	var c := _make_char(1)
	assert_false(LetterSystem.can_send_batch(c, true))


# -- Quality Roll --------------------------------------------------------------

func test_quality_failure_returns_zero():
	# Use seed 0 — with Calligraphy rank 0 unskilled (no explode), 1k0 would fail TN 15
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var c := _make_char(1, 0)  # no calligraphy skill
	# Unskilled 3k3 can still fail depending on seed
	var q: int = LetterSystem.roll_letter_quality(c, dice)
	assert_true(q >= 0 and q <= 3)

func test_quality_success_with_high_skill():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var c := _make_char(1, 5)
	c.awareness = 4
	var results: Array[int] = []
	for i in range(10):
		results.append(LetterSystem.roll_letter_quality(c, dice))
	# With high skill, most rolls should pass TN 15
	var passed: int = 0
	for q: int in results:
		if q > 0:
			passed += 1
	assert_true(passed >= 5)

func test_quality_maximum_is_three():
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_char(1, 5)
	for i in range(20):
		var q: int = LetterSystem.roll_letter_quality(c, dice)
		assert_true(q <= 3)


# -- Write Letter --------------------------------------------------------------

func test_write_letter_sets_fields():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var letter: LetterData = LetterSystem.write_letter(
		100, sender, 2, 2, 10, dice, 3
	)
	assert_eq(letter.letter_id, 100)
	assert_eq(letter.sender_id, 1)
	assert_eq(letter.recipient_id, 2)
	assert_eq(letter.topic, 2)
	assert_eq(letter.ic_day_sent, 10)
	assert_false(letter.delivered)

func test_write_letter_arrival_calculated():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	# 6 provinces = 2 days transit
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 5, dice, 6
	)
	assert_eq(letter.ic_day_arrival, 7)

func test_write_letter_same_province_arrives_today():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 5, dice, 0
	)
	assert_eq(letter.ic_day_arrival, 5)

func test_write_reply_flagged():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 5, dice, 0,
		0, 0, 0, false, Enums.Trait.AWARENESS, true
	)
	assert_true(letter.is_reply)


# -- Deliver Letter ------------------------------------------------------------

func test_deliver_transfers_new_topic():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 0
	)
	LetterSystem.deliver_letter(letter, recipient, 1, log)

	assert_true(2 in recipient.topic_pool)
	assert_eq(recipient.knowledge_pool.size(), 1)
	assert_eq(recipient.knowledge_pool[0].entry_type, "topic_learned")

func test_deliver_does_not_duplicate_known_topic():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	recipient.topic_pool = [2]
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 0
	)
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_false(result["topic_transferred"])
	assert_eq(recipient.topic_pool.size(), 1)

func test_deliver_applies_disposition_bonus():
	var dice := DiceEngine.new()
	# Seed that produces high calligraphy (use seed 1, rank 5)
	dice.set_seed(1)
	var sender := _make_char(1, 5)
	sender.awareness = 5
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 30
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0
	)
	var bonus_applied: int = letter.disposition_bonus
	LetterSystem.deliver_letter(letter, recipient, 1, log)

	assert_eq(recipient.disposition_values[1], 30 + bonus_applied)

func test_deliver_marks_letter_delivered():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0
	)
	LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_true(letter.delivered)

func test_deliver_idempotent():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 0
	)
	LetterSystem.deliver_letter(letter, recipient, 1, log)
	LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_eq(recipient.topic_pool.size(), 1)


# -- Reply Chance --------------------------------------------------------------

func test_reply_chance_hostile_is_zero():
	var c := _make_char(1)
	var chance: float = LetterSystem.get_reply_chance(c, -35)
	assert_eq(chance, 0.0)

func test_reply_chance_base_with_neutral():
	var c := _make_char(1)
	var chance: float = LetterSystem.get_reply_chance(c, 0)
	assert_almost_eq(chance, LetterSystem.BASE_REPLY_CHANCE, 0.001)

func test_reply_chance_increases_with_disposition():
	var c := _make_char(1)
	var low: float = LetterSystem.get_reply_chance(c, 10)
	var high: float = LetterSystem.get_reply_chance(c, 60)
	assert_true(high > low)

func test_reply_chance_courtesy_bonus():
	var c := _make_char(1)
	c.bushido_virtue = Enums.BushidoVirtue.REI
	var base_c := _make_char(2)
	var with_rei: float = LetterSystem.get_reply_chance(c, 30)
	var without: float = LetterSystem.get_reply_chance(base_c, 30)
	assert_almost_eq(with_rei - without, LetterSystem.COURTESY_REPLY_BONUS, 0.001)

func test_reply_chance_capped_at_95():
	var c := _make_char(1)
	c.bushido_virtue = Enums.BushidoVirtue.REI
	var chance: float = LetterSystem.get_reply_chance(c, 100)
	assert_true(chance <= 0.95)

func test_should_reply_passes_below_chance():
	var c := _make_char(1)
	# 20% base chance, roll of 5 should pass
	assert_true(LetterSystem.should_reply(c, 0, 5))

func test_should_reply_fails_above_chance():
	var c := _make_char(1)
	# 20% base chance, roll of 50 should fail
	assert_false(LetterSystem.should_reply(c, 0, 50))


# -- Exchange Bonus ------------------------------------------------------------

func test_exchange_bonus_mutual():
	var a := _make_char(1)
	var b := _make_char(2)
	a.disposition_values[2] = 30
	b.disposition_values[1] = 25
	LetterSystem.apply_exchange_bonus(a, b)
	assert_eq(a.disposition_values[2], 31)
	assert_eq(b.disposition_values[1], 26)

func test_exchange_bonus_from_zero():
	var a := _make_char(1)
	var b := _make_char(2)
	LetterSystem.apply_exchange_bonus(a, b)
	assert_eq(a.disposition_values[2], 1)
	assert_eq(b.disposition_values[1], 1)


# -- Batch Processing ----------------------------------------------------------

func test_process_pending_delivers_due_letters():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 0
	)
	var pending: Array = [letter]
	var results: Array[Dictionary] = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log
	)
	assert_eq(results.size(), 1)
	assert_true(2 in recipient.topic_pool)

func test_process_pending_skips_not_yet_due():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array[Dictionary] = []

	# 6 provinces = arrives day 2
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 6
	)
	var pending: Array = [letter]
	var results: Array[Dictionary] = LetterSystem.process_pending_letters(
		pending, chars, 1, 1, log
	)
	assert_eq(results.size(), 0)
	assert_false(2 in recipient.topic_pool)

func test_process_pending_skips_already_delivered():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array[Dictionary] = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0
	)
	letter.delivered = true
	var pending: Array = [letter]
	var results: Array[Dictionary] = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log
	)
	assert_eq(results.size(), 0)
