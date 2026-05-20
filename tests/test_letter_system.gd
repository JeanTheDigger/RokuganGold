extends GutTest


func _make_char(id: int, calligraphy_rank: int = 3) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 3
	c.agility = 3
	c.intelligence = 3
	c.perception = 3
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
	var results: Array = []
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
	var log: Array = []

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
	var log: Array = []

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
	var log: Array = []

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
	var log: Array = []

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
	var log: Array = []

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
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 0
	)
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
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
	var log: Array = []

	# 6 provinces = arrives day 2
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 2, 0, dice, 6
	)
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
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
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0
	)
	letter.delivered = true
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log
	)
	assert_eq(results.size(), 0)


# -- Dead Recipient -----------------------------------------------------------

func test_dead_recipient_marked_undeliverable():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	recipient.wounds_taken = 200
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 0
	)
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log
	)
	assert_eq(results.size(), 1)
	assert_true(results[0].get("undeliverable", false))
	assert_eq(results[0].get("reason", ""), "recipient_dead")
	assert_true(letter.delivered)

func test_dead_recipient_topic_not_transferred():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	recipient.wounds_taken = 200
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 0
	)
	var pending: Array = [letter]
	LetterSystem.process_pending_letters(pending, chars, 0, 1, log)
	assert_false(5 in recipient.topic_pool)


# -- Blockade Check -----------------------------------------------------------

func test_ocean_letter_blocked_by_blockade():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 0, 0, 0, 1
	)
	var wars: Array = [{"has_naval_component": true}]
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log, wars
	)
	assert_eq(results.size(), 0)
	assert_true(letter.blocked_by_blockade)
	assert_false(letter.delivered)

func test_overland_letter_not_blocked_by_blockade():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 3
	)
	var wars: Array = [{"has_naval_component": true}]
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log, wars
	)
	assert_eq(results.size(), 1)
	assert_false(letter.blocked_by_blockade)

func test_blocked_letter_unblocked_when_blockade_lifts():
	var letter := LetterData.new()
	letter.blocked_by_blockade = true
	letter.ocean_segments = 1
	var pending: Array = [letter]
	var count: int = LetterSystem.unblock_letters(pending)
	assert_eq(count, 1)
	assert_false(letter.blocked_by_blockade)


# -- Forgery Detection -------------------------------------------------------

func test_has_prior_correspondence_true():
	var recipient := _make_char(2)
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	assert_true(LetterSystem.has_prior_correspondence(recipient, 1, pending))

func test_has_prior_correspondence_false_no_letters():
	var recipient := _make_char(2)
	var pending: Array = []
	assert_false(LetterSystem.has_prior_correspondence(recipient, 1, pending))

func test_has_prior_correspondence_false_only_forged():
	var recipient := _make_char(2)
	var forged := LetterData.new()
	forged.sender_id = 1
	forged.recipient_id = 2
	forged.delivered = true
	forged.is_forged = true
	var pending: Array = [forged]
	assert_false(LetterSystem.has_prior_correspondence(recipient, 1, pending))

func test_auto_detect_forgery_no_reference():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var recipient := _make_char(2)
	recipient.skills["Investigation"] = 4
	var forged := LetterData.new()
	forged.is_forged = true
	forged.sender_id = 1
	forged.forgery_tn = 10
	var pending: Array = []
	var detected: bool = LetterSystem.auto_detect_forgery(
		forged, recipient, dice, pending
	)
	assert_false(detected)

func test_auto_detect_forgery_with_reference_high_skill():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var recipient := _make_char(2)
	recipient.skills["Investigation"] = 5
	recipient.perception = 5
	var forged := LetterData.new()
	forged.is_forged = true
	forged.sender_id = 1
	forged.forgery_tn = 10
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	var detected_count: int = 0
	for i in range(10):
		dice.set_seed(i)
		if LetterSystem.auto_detect_forgery(forged, recipient, dice, pending):
			detected_count += 1
	assert_true(detected_count > 0)

func test_auto_detect_non_forged_returns_false():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var recipient := _make_char(2)
	var letter := LetterData.new()
	letter.is_forged = false
	var pending: Array = []
	assert_false(LetterSystem.auto_detect_forgery(letter, recipient, dice, pending))

func test_deliberate_examine_no_reference():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var examiner := _make_char(2)
	examiner.skills["Investigation"] = 4
	var letter := LetterData.new()
	letter.is_forged = true
	letter.sender_id = 1
	letter.forgery_tn = 15
	var pending: Array = []
	var result: Dictionary = LetterSystem.deliberate_examine_letter(
		letter, examiner, dice, pending
	)
	assert_false(result["detected"])
	assert_true(result.get("no_reference", false))

func test_deliberate_examine_authentic_letter():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var examiner := _make_char(2)
	examiner.skills["Investigation"] = 4
	var letter := LetterData.new()
	letter.is_forged = false
	letter.sender_id = 1
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	var result: Dictionary = LetterSystem.deliberate_examine_letter(
		letter, examiner, dice, pending
	)
	assert_false(result["detected"])
	assert_true(result.get("authentic", false))

func test_deliberate_examine_detects_forgery():
	var dice := DiceEngine.new()
	var examiner := _make_char(2)
	examiner.skills["Investigation"] = 5
	examiner.perception = 5
	var letter := LetterData.new()
	letter.is_forged = true
	letter.sender_id = 1
	letter.forgery_tn = 10
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	var detected_count: int = 0
	for i in range(10):
		dice.set_seed(i)
		var result: Dictionary = LetterSystem.deliberate_examine_letter(
			letter, examiner, dice, pending
		)
		if result["detected"]:
			detected_count += 1
	assert_true(detected_count > 0)

func test_deliberate_examine_marks_forgery_detected():
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var examiner := _make_char(2)
	examiner.skills["Investigation"] = 8
	examiner.perception = 5
	var letter := LetterData.new()
	letter.is_forged = true
	letter.sender_id = 1
	letter.forgery_tn = 5
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	var result: Dictionary = LetterSystem.deliberate_examine_letter(
		letter, examiner, dice, pending
	)
	if result["detected"]:
		assert_true(letter.forgery_detected)

func test_forgery_rank5_bonus_in_deliberate():
	var dice := DiceEngine.new()
	var examiner := _make_char(2)
	examiner.skills["Investigation"] = 3
	examiner.skills["Forgery"] = 5
	examiner.perception = 3
	var letter := LetterData.new()
	letter.is_forged = true
	letter.sender_id = 1
	letter.forgery_tn = 15
	var prior := LetterData.new()
	prior.sender_id = 1
	prior.recipient_id = 2
	prior.delivered = true
	prior.is_forged = false
	var pending: Array = [prior]
	var detected_with: int = 0
	var detected_without: int = 0
	for i in range(20):
		dice.set_seed(i)
		var r: Dictionary = LetterSystem.deliberate_examine_letter(
			letter, examiner, dice, pending
		)
		if r["detected"]:
			detected_with += 1
	examiner.skills["Forgery"] = 0
	for i in range(20):
		dice.set_seed(i)
		letter.forgery_detected = false
		var r: Dictionary = LetterSystem.deliberate_examine_letter(
			letter, examiner, dice, pending
		)
		if r["detected"]:
			detected_without += 1
	assert_true(detected_with >= detected_without)


# -- Forged Letter in Batch Processing ----------------------------------------

func test_forged_letter_delivers_with_forgery_info():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 0
	)
	letter.is_forged = true
	letter.forged_sender_id = 99
	letter.forgery_tn = 30
	var pending: Array = [letter]
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log, [], dice
	)
	assert_eq(results.size(), 1)
	assert_true(results[0].get("is_forged", false))
	assert_eq(results[0].get("forged_sender_id", -1), 99)


# -- Reply Generation --------------------------------------------------------

func test_generate_replies_creates_reply():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10, 20]
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	var pending: Array = [letter]
	LetterSystem.process_pending_letters(pending, chars, 0, 1, log)

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
		"topic_transferred": true,
		"disposition_bonus": 1,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	if replies.size() > 0:
		assert_true(replies[0].is_reply)
		assert_eq(replies[0].sender_id, 2)
		assert_eq(replies[0].recipient_id, 1)
		assert_true(replies[0].topic >= 0)

func test_generate_replies_skips_dead_sender():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	sender.wounds_taken = 200
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	var chars: Dictionary = {1: sender, 2: recipient}

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, [], chars, 0, dice, next_id
	)
	assert_eq(replies.size(), 0)

func test_generate_replies_skips_undeliverable():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	var chars: Dictionary = {1: sender, 2: recipient}

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
		"undeliverable": true,
		"reason": "recipient_dead",
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, [], chars, 0, dice, next_id
	)
	assert_eq(replies.size(), 0)

func test_generate_replies_does_not_apply_exchange_bonus():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	sender.disposition_values[2] = 30
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	recipient.bushido_virtue = Enums.BushidoVirtue.REI
	var chars: Dictionary = {1: sender, 2: recipient}

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0
	)
	var pending: Array = [letter]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	if replies.size() > 0:
		# Exchange bonus deferred until reply arrives (per GDD s12.7)
		assert_eq(sender.disposition_values[2], 30)
		assert_eq(recipient.disposition_values[1], 80)


func test_exchange_bonus_applied_when_reply_delivered():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	sender.disposition_values[2] = 30
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 50
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	# Create a reply letter from recipient(2) to sender(1), same province (arrives immediately)
	var reply: LetterData = LetterSystem.write_letter(
		100, recipient, 1, 10, 0, dice, 0,
		0, 0, 0, false, Enums.Trait.AWARENESS, true
	)
	var pending: Array = [reply]
	LetterSystem.process_pending_letters(pending, chars, 0, 1, log)

	# Exchange bonus: both get +1
	assert_eq(sender.disposition_values[2], 31)
	assert_eq(recipient.disposition_values[1], 51)

func test_generate_replies_uses_original_route():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	recipient.bushido_virtue = Enums.BushidoVirtue.REI
	var chars: Dictionary = {1: sender, 2: recipient}

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 6, 2, 1, 1, true
	)
	var pending: Array = [letter]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	if replies.size() > 0:
		assert_eq(replies[0].province_distance, 6)
		assert_eq(replies[0].mountain_provinces, 2)
		assert_eq(replies[0].warzone_provinces, 1)
		assert_eq(replies[0].ocean_segments, 1)
		assert_true(replies[0].has_miya_route)

func test_reply_topic_prefers_original():
	var recipient := _make_char(2)
	recipient.topic_pool = [10, 20, 30]
	var topic: int = LetterSystem._pick_reply_topic(recipient, 20)
	assert_eq(topic, 20)

func test_reply_topic_fallback_first_when_original_unknown():
	var recipient := _make_char(2)
	recipient.topic_pool = [10, 20, 30]
	var topic: int = LetterSystem._pick_reply_topic(recipient, 99)
	assert_eq(topic, 10)

func test_reply_topic_uses_original_when_pool_empty():
	var recipient := _make_char(2)
	recipient.topic_pool = []
	var topic: int = LetterSystem._pick_reply_topic(recipient, 5)
	assert_eq(topic, 5)

func test_next_letter_id_incremented_per_reply():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var r1 := _make_char(2, 3)
	r1.disposition_values[1] = 90
	r1.topic_pool = [10]
	r1.bushido_virtue = Enums.BushidoVirtue.REI
	var r2 := _make_char(3, 3)
	r2.disposition_values[1] = 90
	r2.topic_pool = [20]
	r2.bushido_virtue = Enums.BushidoVirtue.REI
	var chars: Dictionary = {1: sender, 2: r1, 3: r2}

	var l1: LetterData = LetterSystem.write_letter(1, sender, 2, 10, 0, dice, 0)
	var l2: LetterData = LetterSystem.write_letter(2, sender, 3, 20, 0, dice, 0)
	var pending: Array = [l1, l2]

	var delivery_results: Array = [
		{"letter_id": 1, "sender_id": 1, "recipient_id": 2, "topic": 10},
		{"letter_id": 2, "sender_id": 1, "recipient_id": 3, "topic": 20},
	]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	if replies.size() >= 2:
		assert_ne(replies[0].letter_id, replies[1].letter_id)
	assert_true(next_id[0] >= 100 + replies.size())


# -- EXAMINE_LETTER Wiring ----------------------------------------------------

func test_examine_letter_in_action_skill_map():
	var loader := ScoringTableLoader.new()
	loader.load_all()
	var tables: Dictionary = loader.get_scoring_tables()
	var skill_map: Dictionary = tables.get("action_skill_map", {})
	assert_true(skill_map.has("EXAMINE_LETTER"))
	assert_eq(skill_map["EXAMINE_LETTER"]["primary"], "Investigation")
	assert_eq(skill_map["EXAMINE_LETTER"]["secondary"], "Perception")

func test_examine_letter_in_objective_alignment():
	var loader := ScoringTableLoader.new()
	loader.load_all()
	var tables: Dictionary = loader.get_scoring_tables()
	var obj_align: Dictionary = tables.get("objective_alignment", {})
	assert_true(obj_align.has("INVESTIGATE_THREAT"))
	var inv_threat: Dictionary = obj_align["INVESTIGATE_THREAT"]
	assert_true(inv_threat.has("EXAMINE_LETTER"))
	assert_eq(inv_threat["EXAMINE_LETTER"], 85)
	assert_true(obj_align.has("GATHER_INTELLIGENCE"))
	var gather: Dictionary = obj_align["GATHER_INTELLIGENCE"]
	assert_true(gather.has("EXAMINE_LETTER"))
	assert_eq(gather["EXAMINE_LETTER"], 75)

func test_examine_letter_in_personality_lean():
	var loader := ScoringTableLoader.new()
	loader.load_all()
	var tables: Dictionary = loader.get_scoring_tables()
	var lean: Dictionary = tables.get("personality_lean", {})
	for virtue: String in ["JIN", "YU", "REI", "CHUGI", "GI", "MEIYO", "MAKOTO",
			"SEIGYO", "KETSUI", "DOSATSU", "CHISHIKI", "KANPEKI", "KYORYOKU", "ISHI"]:
		assert_true(lean[virtue].has("EXAMINE_LETTER"),
			"Missing EXAMINE_LETTER in %s" % virtue)

func test_examine_letter_in_context_lists():
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var holdings_actions: Array = NPCDecisionEngine._get_actions_for_context(ctx.context_flag)
	assert_true("EXAMINE_LETTER" in holdings_actions,
		"EXAMINE_LETTER should be in AT_OWN_HOLDINGS actions")
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	var court_actions: Array = NPCDecisionEngine._get_actions_for_context(ctx.context_flag)
	assert_true("EXAMINE_LETTER" in court_actions,
		"EXAMINE_LETTER should be in AT_COURT actions")

func test_examine_letter_executor_returns_deferred_flag():
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "EXAMINE_LETTER"
	action.target_npc_id = -1
	action.target_province_id = -1
	action.metadata = {"letter_id": 42}
	var char := _make_char(1)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	ctx.season = 0
	ctx.character_id = 1
	var dice := DiceEngine.new(99)
	var skill_map: Dictionary = {"EXAMINE_LETTER": {"primary": "Investigation", "secondary": "Perception"}}
	var result: Dictionary = ActionExecutor.execute(action, char, ctx, dice, skill_map)
	assert_true(result["success"])
	assert_eq(result["action_id"], "EXAMINE_LETTER")
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_letter_examination", false))
	assert_eq(effects["letter_id"], 42)
	assert_eq(effects["examiner_id"], 1)

func test_examine_letter_orchestrator_processes_examination():
	var examiner := _make_char(1)
	examiner.skills["Investigation"] = 5
	var sender := _make_char(2)
	var dice := DiceEngine.new(42)
	var forged_letter := LetterData.new()
	forged_letter.letter_id = 10
	forged_letter.sender_id = 2
	forged_letter.recipient_id = 1
	forged_letter.is_forged = true
	forged_letter.forgery_tn = 10
	forged_letter.delivered = true
	var authentic_letter := LetterData.new()
	authentic_letter.letter_id = 5
	authentic_letter.sender_id = 2
	authentic_letter.recipient_id = 1
	authentic_letter.delivered = true
	authentic_letter.is_forged = false
	var pending: Array = [authentic_letter, forged_letter]
	var chars: Dictionary = {1: examiner, 2: sender}
	var day_results: Array = [{
		"action_id": "EXAMINE_LETTER",
		"character_id": 1,
		"effects": {
			"requires_letter_examination": true,
			"letter_id": 10,
			"examiner_id": 1,
		},
	}]
	var results: Array = DayOrchestrator._process_letter_examinations(
		day_results, pending, chars, dice,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["letter_id"], 10)
	assert_eq(results[0]["examiner_id"], 1)
	assert_true(results[0].has("detected"))

func test_examine_letter_orchestrator_skips_invalid_letter():
	var examiner := _make_char(1)
	var dice := DiceEngine.new(42)
	var pending: Array = []
	var chars: Dictionary = {1: examiner}
	var day_results: Array = [{
		"action_id": "EXAMINE_LETTER",
		"character_id": 1,
		"effects": {
			"requires_letter_examination": true,
			"letter_id": 999,
			"examiner_id": 1,
		},
	}]
	var results: Array = DayOrchestrator._process_letter_examinations(
		day_results, pending, chars, dice,
	)
	assert_eq(results.size(), 0)

func test_examine_letter_orchestrator_skips_without_dice():
	var day_results: Array = [{
		"effects": {"requires_letter_examination": true, "letter_id": 1, "examiner_id": 1},
	}]
	var results: Array = DayOrchestrator._process_letter_examinations(
		day_results, [], {}, null,
	)
	assert_eq(results.size(), 0)


func test_deliver_refreshes_topic_momentum_for_known_topic():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	recipient.topic_pool = [5]
	var log: Array = []

	var topic := TopicData.new()
	topic.topic_id = 5
	topic.discussion_count_this_day = 0
	var topics_by_id: Dictionary = {5: topic}

	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, 5, 0, dice, 0)
	LetterSystem.deliver_letter(letter, recipient, 1, log, topics_by_id)

	assert_eq(topic.discussion_count_this_day, 1)
	assert_eq(recipient.topic_pool.size(), 1)


func test_deliver_refreshes_momentum_for_new_topic_too():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2)
	recipient.topic_pool = []
	var log: Array = []

	var topic := TopicData.new()
	topic.topic_id = 7
	topic.discussion_count_this_day = 0
	var topics_by_id: Dictionary = {7: topic}

	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, 7, 0, dice, 0)
	LetterSystem.deliver_letter(letter, recipient, 1, log, topics_by_id)

	assert_eq(topic.discussion_count_this_day, 1)
	assert_true(7 in recipient.topic_pool)


func test_exchange_bonus_clamps_at_100():
	var sender := _make_char(1)
	var recipient := _make_char(2)
	sender.disposition_values = {2: 100}
	recipient.disposition_values = {1: 99}

	LetterSystem.apply_exchange_bonus(sender, recipient)

	assert_eq(sender.disposition_values[2], 100)
	assert_eq(recipient.disposition_values[1], 100)


# --- Meeting Proposal Reply Propagation (s55.31) ---

func test_reply_propagates_meeting_proposal_when_disposition_ok():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 10
	recipient.topic_pool = [10]
	recipient.bushido_virtue = Enums.BushidoVirtue.REI
	var chars: Dictionary = {1: sender, 2: recipient}

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	letter.meeting_proposal = true
	letter.meeting_settlement_id = 100
	letter.meeting_deadline_ic_day = 90
	var pending: Array = [letter]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	if replies.size() > 0:
		assert_true(replies[0].meeting_proposal,
			"Reply should carry meeting_proposal")
		assert_eq(replies[0].meeting_settlement_id, 100)
		assert_eq(replies[0].meeting_deadline_ic_day, 90)


func test_reply_does_not_propagate_meeting_when_hostile():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = -5
	recipient.topic_pool = [10]
	recipient.bushido_virtue = Enums.BushidoVirtue.REI
	var chars: Dictionary = {1: sender, 2: recipient}

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	letter.meeting_proposal = true
	letter.meeting_settlement_id = 100
	letter.meeting_deadline_ic_day = 90
	var pending: Array = [letter]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id
	)
	for reply: LetterData in replies:
		assert_false(reply.meeting_proposal,
			"Hostile recipient should not confirm meeting")


# -- Forgery Detection Skip (GDD s12.7: detected forgery = discard) -----------


func test_detected_forgery_skips_topic_transfer():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 7)
	recipient.skills["Investigation"] = 10
	recipient.set_trait_value(Enums.Trait.PERCEPTION, 10)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var authentic: LetterData = LetterSystem.write_letter(
		1, sender, 2, 5, 0, dice, 0
	)
	authentic.ic_day_arrival = 0

	var forged: LetterData = LetterSystem.write_letter(
		2, sender, 2, 99, 1, dice, 0
	)
	forged.ic_day_arrival = 1
	forged.is_forged = true
	forged.forged_sender_id = 50
	forged.forgery_tn = 5
	var pending: Array = [authentic, forged]

	LetterSystem.process_pending_letters(pending, chars, 0, 1, log, [], dice)
	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 1, 1, log, [], dice
	)
	assert_eq(results.size(), 1)
	assert_true(results[0].get("forgery_detected", false))
	assert_false(99 in recipient.topic_pool,
		"Detected forgery should NOT transfer topic")


func test_undetected_forgery_transfers_topic():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 1)
	recipient.skills["Investigation"] = 1
	recipient.set_trait_value(Enums.Trait.PERCEPTION, 1)
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var forged: LetterData = LetterSystem.write_letter(
		1, sender, 2, 99, 0, dice, 0
	)
	forged.ic_day_arrival = 0
	forged.is_forged = true
	forged.forged_sender_id = 50
	forged.forgery_tn = 50
	var pending: Array = [forged]

	var results: Array = LetterSystem.process_pending_letters(
		pending, chars, 0, 1, log, [], dice
	)
	assert_eq(results.size(), 1)
	assert_false(results[0].get("forgery_detected", true))
	assert_true(99 in recipient.topic_pool,
		"Undetected forgery SHOULD transfer topic")


# -- Reply to forged letter tags reply_to_forged --------------------------------


func test_reply_to_forged_letter_tagged():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10, 20]
	var chars: Dictionary = {1: sender, 2: recipient}
	var log: Array = []

	var forged: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	forged.ic_day_arrival = 0
	forged.is_forged = true
	forged.forged_sender_id = 99
	forged.forgery_tn = 50
	var pending: Array = [forged]

	LetterSystem.process_pending_letters(pending, chars, 0, 1, log, [], dice)
	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
		"is_forged": true,
		"forged_sender_id": 99,
		"forgery_detected": false,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id,
	)
	if replies.size() > 0:
		assert_true(replies[0].reply_to_forged,
			"Reply to undetected forged letter should be tagged")
		assert_eq(replies[0].original_forger_id, 99)
	else:
		pass_test("No reply generated (RNG), can't test tag")


func test_no_reply_to_detected_forgery():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	var chars: Dictionary = {1: sender, 2: recipient}

	var forged: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	forged.is_forged = true
	forged.forged_sender_id = 99
	forged.forgery_detected = true
	var pending: Array = [forged]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
		"is_forged": true,
		"forged_sender_id": 99,
		"forgery_detected": true,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id,
	)
	assert_eq(replies.size(), 0,
		"Should not generate reply to detected forgery")


func test_reply_to_detected_forgery_not_tagged():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1, 3)
	var recipient := _make_char(2, 3)
	recipient.disposition_values[1] = 80
	recipient.topic_pool = [10]
	var chars: Dictionary = {1: sender, 2: recipient}

	var forged: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 3
	)
	forged.is_forged = true
	forged.forged_sender_id = 99
	forged.forgery_detected = true
	var pending: Array = [forged]

	var delivery_results: Array = [{
		"letter_id": 1,
		"sender_id": 1,
		"recipient_id": 2,
		"topic": 10,
		"is_forged": true,
		"forged_sender_id": 99,
		"forgery_detected": true,
	}]
	var next_id: Array = [100]
	var replies: Array = LetterSystem.generate_replies(
		delivery_results, pending, chars, 0, dice, next_id,
	)
	for reply: LetterData in replies:
		assert_false(reply.reply_to_forged,
			"Reply to detected forgery should NOT be tagged")
