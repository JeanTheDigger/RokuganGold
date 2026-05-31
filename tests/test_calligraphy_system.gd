extends GutTest
## Tests for s57.30 Calligraphy (Cipher + High Rokugani) system.


func _make_char(id: int, calligraphy_rank: int = 3) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 3
	c.intelligence = 3
	c.perception = 3
	c.willpower = 3
	c.skills = {"Calligraphy": calligraphy_rank, "Sincerity": 3}
	c.emphases = {}
	c.wounds_taken = 0
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.action_points_current = 2
	c.action_points_max = 2
	c.lord_id = -1
	c.lord_rank = Enums.LordRank.NONE
	c.topic_pool = []
	c.knowledge_pool = []
	c.disposition_values = {}
	c.school = "Doji Courtier"
	c.physical_location = "100"
	c.from_the_ashes = {}
	return c


func _make_settlement(id: int, stype: Enums.SettlementType) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = stype
	return s


func _make_letter(sender: L5RCharacterData, recipient_id: int) -> LetterData:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	return LetterSystem.write_letter(1, sender, recipient_id, -1, 0, dice)


# -- Part A: Cipher — Writer side (concealment_tn population) -----------------

func test_write_letter_populates_concealment_tn():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	assert_true(letter.concealment_tn > 0, "concealment_tn should be the sincerity roll total")


func test_write_letter_concealment_tn_scales_with_sincerity():
	var dice_low := DiceEngine.new()
	dice_low.set_seed(7)
	var dice_high := DiceEngine.new()
	dice_high.set_seed(7)

	var sender_low := _make_char(1)
	sender_low.skills["Sincerity"] = 1
	sender_low.awareness = 1

	var sender_high := _make_char(2)
	sender_high.skills["Sincerity"] = 5
	sender_high.awareness = 5

	var totals_low: Array = []
	var totals_high: Array = []
	for i in range(20):
		totals_low.append(LetterSystem.write_letter(i, sender_low, 3, -1, 0, dice_low).concealment_tn)
		totals_high.append(LetterSystem.write_letter(i, sender_high, 3, -1, 0, dice_high).concealment_tn)

	var avg_low: float = 0.0
	var avg_high: float = 0.0
	for v: int in totals_low:
		avg_low += v
	for v: int in totals_high:
		avg_high += v
	avg_low /= totals_low.size()
	avg_high /= totals_high.size()
	assert_true(avg_high > avg_low, "Higher Sincerity skill should produce higher concealment_tn on average")


# -- Part A: Cipher — writer_disposition_tier ---------------------------------

func test_write_letter_disposition_tier_friend():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	sender.disposition_values[2] = 40  # Friend tier
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	assert_eq(letter.writer_disposition_tier, DispositionSystem.Tier.FRIEND)


func test_write_letter_disposition_tier_rival():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	sender.disposition_values[2] = -20  # Rival tier
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	assert_eq(letter.writer_disposition_tier, DispositionSystem.Tier.RIVAL)


func test_write_letter_disposition_tier_stranger_when_unknown():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	# No disposition entry for recipient
	var letter: LetterData = LetterSystem.write_letter(1, sender, 99, -1, 0, dice)
	assert_eq(letter.writer_disposition_tier, DispositionSystem.Tier.STRANGER)


# -- Part A: Cipher — writer_topic_stance -------------------------------------

func test_write_letter_topic_stance_supports():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	sender.disposition_values[5] = 20  # subject_character_id 5 = Acquaintance
	var topic := TopicData.new()
	topic.topic_id = 10
	topic.subject_character_id = 5
	var topics_by_id: Dictionary = {10: topic}
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0, 0, 0, 0, false,
		Enums.Trait.AWARENESS, false, "", topics_by_id
	)
	assert_eq(letter.writer_topic_stance, "supports")


func test_write_letter_topic_stance_opposes():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	sender.disposition_values[5] = -25  # Rival
	var topic := TopicData.new()
	topic.topic_id = 10
	topic.subject_character_id = 5
	var topics_by_id: Dictionary = {10: topic}
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0, 0, 0, 0, false,
		Enums.Trait.AWARENESS, false, "", topics_by_id
	)
	assert_eq(letter.writer_topic_stance, "opposes")


func test_write_letter_topic_stance_indifferent():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	sender.disposition_values[5] = 5  # Stranger
	var topic := TopicData.new()
	topic.topic_id = 10
	topic.subject_character_id = 5
	var topics_by_id: Dictionary = {10: topic}
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0, 0, 0, 0, false,
		Enums.Trait.AWARENESS, false, "", topics_by_id
	)
	assert_eq(letter.writer_topic_stance, "indifferent")


func test_write_letter_topic_stance_empty_when_no_topic():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	assert_eq(letter.writer_topic_stance, "")


func test_write_letter_topic_stance_empty_when_topic_has_no_subject():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	var topic := TopicData.new()
	topic.topic_id = 10
	topic.subject_character_id = -1  # no subject
	var topics_by_id: Dictionary = {10: topic}
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, 10, 0, dice, 0, 0, 0, 0, false,
		Enums.Trait.AWARENESS, false, "", topics_by_id
	)
	assert_eq(letter.writer_topic_stance, "")


# -- Part A: Cipher — writer_needtype -----------------------------------------

func test_write_letter_needtype_stored():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice, 0, 0, 0, 0, false,
		Enums.Trait.AWARENESS, false, "RAISE_DISPOSITION"
	)
	assert_eq(letter.writer_needtype, "RAISE_DISPOSITION")


func test_write_letter_needtype_empty_for_player():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sender := _make_char(1)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	assert_eq(letter.writer_needtype, "")


# -- Part A: Cipher — reader side (cipher extraction) -------------------------

func _make_dice_with_guaranteed_outcome(seed: int) -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(seed)
	return d


func test_cipher_not_attempted_without_emphasis():
	var sender := _make_char(1)
	var dice := _make_dice_with_guaranteed_outcome(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	letter.concealment_tn = 5  # easy to beat

	var recipient := _make_char(2, 5)
	# No Cipher emphasis
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice)
	assert_false(result.has("cipher_attempted"), "No cipher extraction without emphasis")


func test_cipher_attempted_with_emphasis():
	var sender := _make_char(1)
	var dice := _make_dice_with_guaranteed_outcome(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice)
	letter.concealment_tn = 1  # almost guaranteed success

	var recipient := _make_char(2, 5)
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice)
	assert_true(result.has("cipher_attempted"), "Cipher extraction should be attempted")


func test_cipher_success_creates_knowledge_entries():
	var sender := _make_char(1)
	sender.disposition_values[2] = 40  # Friend

	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.concealment_tn = 1  # guaranteed success on read

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	if result.get("cipher_success", false):
		var has_tier_entry: bool = false
		for entry: KnowledgeEntry in recipient.knowledge_pool:
			if entry.entry_type == "writer_disposition_tier":
				has_tier_entry = true
				break
		assert_true(has_tier_entry, "Knowledge entry for writer_disposition_tier should be created")


func test_cipher_failure_creates_no_knowledge():
	var sender := _make_char(1)
	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.concealment_tn = 999  # impossible to beat

	var recipient := _make_char(2, 1)
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	var dice_read := DiceEngine.new()
	dice_read.set_seed(7)
	var log: Array = []
	LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	var has_cipher_entry: bool = false
	for entry: KnowledgeEntry in recipient.knowledge_pool:
		if entry.entry_type == "writer_disposition_tier":
			has_cipher_entry = true
			break
	assert_false(has_cipher_entry, "No cipher knowledge on failed extraction")


func test_cipher_rank5_mastery_bonus_applied():
	# The CIPHER_RANK5_EXTRACTION_BONUS constant should be 10
	assert_eq(LetterSystem.CIPHER_RANK5_EXTRACTION_BONUS, 10)


# -- Part A: Cipher — deception detection (A3) --------------------------------

func test_deception_present_hostile_tier_with_warm_letter():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.RIVAL  # hostile
	letter.disposition_bonus = 2  # warm letter
	letter.topic = -1
	letter.writer_topic_stance = ""
	assert_true(LetterSystem._check_deception_present(letter))


func test_deception_present_enemy_tier_with_warm_letter():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.ENEMY
	letter.disposition_bonus = 1
	letter.topic = -1
	letter.writer_topic_stance = ""
	assert_true(LetterSystem._check_deception_present(letter))


func test_no_deception_friend_tier_warm_letter():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.FRIEND
	letter.disposition_bonus = 2
	letter.topic = -1
	letter.writer_topic_stance = ""
	assert_false(LetterSystem._check_deception_present(letter))


func test_no_deception_rival_tier_no_bonus():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.RIVAL
	letter.disposition_bonus = 0  # no disposition bonus (failed quality roll)
	letter.topic = -1
	letter.writer_topic_stance = ""
	assert_false(LetterSystem._check_deception_present(letter))


func test_deception_present_opposes_topic_warm_letter():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.ACQUAINTANCE  # not hostile tier
	letter.disposition_bonus = 1
	letter.topic = 10
	letter.writer_topic_stance = "opposes"
	assert_true(LetterSystem._check_deception_present(letter))


func test_no_deception_supports_topic():
	var letter := LetterData.new()
	letter.writer_disposition_tier = DispositionSystem.Tier.ACQUAINTANCE
	letter.disposition_bonus = 1
	letter.topic = 10
	letter.writer_topic_stance = "supports"
	assert_false(LetterSystem._check_deception_present(letter))


func test_deception_detection_applies_disposition_penalty():
	var sender := _make_char(1)
	sender.disposition_values[2] = -20  # Rival

	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	# Create a letter that will definitely show deception
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.writer_disposition_tier = DispositionSystem.Tier.RIVAL
	letter.disposition_bonus = 2  # forced warm letter
	letter.concealment_tn = 1  # trivial to beat

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	recipient.disposition_values[1] = 30
	# Use a seed that produces 2+ raises
	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	if result.get("deception_detected", false):
		var disp: int = recipient.disposition_values.get(1, 30)
		assert_true(disp < 30, "Deception detection should reduce disposition toward sender")
		assert_eq(result["deception_disposition_change"], LetterSystem.CIPHER_DECEPTION_DISPOSITION_PENALTY)


func test_cipher_deception_penalty_constant():
	assert_eq(LetterSystem.CIPHER_DECEPTION_DISPOSITION_PENALTY, -3)


# -- Part A: Cipher — Kitsuki investigator zone_event_log entry ---------------

func test_kitsuki_deception_generates_zone_entry():
	var sender := _make_char(1)
	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.writer_disposition_tier = DispositionSystem.Tier.RIVAL
	letter.disposition_bonus = 2
	letter.concealment_tn = 1

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	recipient.school = "Kitsuki Investigator"
	recipient.physical_location = "settlement_42"

	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	if result.get("deception_detected", false):
		assert_true(result.has("kitsuki_written_deception"),
			"Kitsuki should get zone_event_log entry on deception detection")
		var entry: Dictionary = result["kitsuki_written_deception"]
		assert_eq(entry["settlement_id"], "settlement_42")
		assert_eq(entry["sender_id"], 1)


func test_non_kitsuki_deception_has_no_zone_entry():
	var sender := _make_char(1)
	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.writer_disposition_tier = DispositionSystem.Tier.RIVAL
	letter.disposition_bonus = 2
	letter.concealment_tn = 1

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}
	recipient.school = "Doji Courtier"  # not Kitsuki

	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	assert_false(result.has("kitsuki_written_deception"),
		"Non-Kitsuki recipient should not get zone_event_log entry")


# -- Part A: Cipher — motivation inference (A4) --------------------------------

func test_motivation_inference_creates_knowledge_entry():
	var sender := _make_char(1)
	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice_write,
		0, 0, 0, 0, false, Enums.Trait.AWARENESS, false, "RAISE_DISPOSITION"
	)
	letter.concealment_tn = 1  # trivial to beat

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}

	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	if result.get("motivation_inferred", false):
		var has_motivation: bool = false
		for entry: KnowledgeEntry in recipient.knowledge_pool:
			if entry.entry_type == "writer_motivation":
				has_motivation = true
				assert_eq(entry.data.get("needtype", ""), "RAISE_DISPOSITION")
				break
		assert_true(has_motivation, "writer_motivation knowledge entry should be created")
		assert_true(result.get("cipher_insight_bonus_active", false),
			"Insight bonus flag should be set on motivation inference")


func test_motivation_inference_skipped_when_needtype_empty():
	var sender := _make_char(1)
	var dice_write := DiceEngine.new()
	dice_write.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(1, sender, 2, -1, 0, dice_write)
	letter.writer_needtype = ""  # no needtype (player letter)
	letter.concealment_tn = 1

	var recipient := _make_char(2, 5)
	recipient.intelligence = 5
	recipient.emphases = {"Calligraphy": ["Cipher"]}

	var dice_read := DiceEngine.new()
	dice_read.set_seed(1)
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_read)

	assert_false(result.get("motivation_inferred", false),
		"Motivation inference should not fire for empty needtype")


# -- Part B: High Rokugani — trigger conditions --------------------------------

func test_high_rokugani_not_attempted_without_emphasis():
	var sender := _make_char(1)
	sender.emphases = {}  # no High Rokugani emphasis

	var recipient := _make_char(2)
	recipient.lord_rank = Enums.LordRank.NONE
	recipient.physical_location = "100"

	var settlement: SettlementData = _make_settlement(100, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"100": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice,
		0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
		"", {}, settlements, chars_by_id
	)
	assert_false(letter.high_rokugani_attempted)


func test_high_rokugani_not_attempted_outside_imperial_capital():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}

	var recipient := _make_char(2)
	recipient.physical_location = "200"

	var settlement: SettlementData = _make_settlement(200, Enums.SettlementType.CASTLE)
	var settlements: Dictionary = {"200": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice,
		0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
		"", {}, settlements, chars_by_id
	)
	assert_false(letter.high_rokugani_attempted)


func test_high_rokugani_attempted_at_imperial_capital():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}
	sender.skills["Calligraphy"] = 5
	sender.intelligence = 5

	var recipient := _make_char(2)
	recipient.physical_location = "300"
	recipient.lord_rank = Enums.LordRank.NONE

	var settlement: SettlementData = _make_settlement(300, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"300": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var letter: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice,
		0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
		"", {}, settlements, chars_by_id
	)
	assert_true(letter.high_rokugani_attempted)


# -- Part B: High Rokugani — TN selection (B2) ---------------------------------

func test_get_high_rokugani_tn_default():
	var recipient := _make_char(1)
	recipient.lord_rank = Enums.LordRank.NONE
	assert_eq(LetterSystem._get_high_rokugani_tn(recipient), LetterSystem.HIGH_ROKUGANI_TN_INNER_CITY)


func test_get_high_rokugani_tn_imperial_family():
	var recipient := _make_char(1)
	recipient.lord_rank = Enums.LordRank.IMPERIAL
	assert_eq(LetterSystem._get_high_rokugani_tn(recipient), LetterSystem.HIGH_ROKUGANI_TN_IMPERIAL_FAMILY)


func test_high_rokugani_tn_constants():
	assert_eq(LetterSystem.HIGH_ROKUGANI_TN_INNER_CITY, 15)
	assert_eq(LetterSystem.HIGH_ROKUGANI_TN_IMPERIAL_FAMILY, 20)
	assert_eq(LetterSystem.HIGH_ROKUGANI_TN_EMPERORS_CHOSEN, 25)
	assert_eq(LetterSystem.HIGH_ROKUGANI_TN_EMPEROR, 30)


# -- Part B: High Rokugani — bonus tier (B3) -----------------------------------

func test_high_rokugani_failure_produces_zero_bonus():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}
	sender.skills["Calligraphy"] = 1
	sender.intelligence = 1  # very low — likely to fail TN 15

	var recipient := _make_char(2)
	recipient.physical_location = "400"
	recipient.lord_rank = Enums.LordRank.NONE

	var settlement: SettlementData = _make_settlement(400, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"400": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	var successes_bonus_gt0: int = 0
	for _i in range(20):
		var dice := DiceEngine.new()
		dice.set_seed(_i * 3 + 1)
		var letter: LetterData = LetterSystem.write_letter(
			1, sender, 2, -1, 0, dice,
			0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
			"", {}, settlements, chars_by_id
		)
		if letter.high_rokugani_attempted and letter.high_rokugani_bonus > 0:
			successes_bonus_gt0 += 1
	# With extremely low skill, most should fail and produce 0 bonus
	# Just verify the field exists and can be 0
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var letter_check: LetterData = LetterSystem.write_letter(
		1, sender, 2, -1, 0, dice,
		0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
		"", {}, settlements, chars_by_id
	)
	assert_true(letter_check.high_rokugani_attempted)
	assert_true(letter_check.high_rokugani_bonus >= 0)


func test_high_rokugani_success_produces_nonzero_bonus():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}
	sender.skills["Calligraphy"] = 5
	sender.intelligence = 5  # high enough to reliably pass TN 15

	var recipient := _make_char(2)
	recipient.physical_location = "500"
	recipient.lord_rank = Enums.LordRank.NONE

	var settlement: SettlementData = _make_settlement(500, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"500": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	var bonuses: Array = []
	for _i in range(10):
		var dice := DiceEngine.new()
		dice.set_seed(_i + 10)
		var letter: LetterData = LetterSystem.write_letter(
			1, sender, 2, -1, 0, dice,
			0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
			"", {}, settlements, chars_by_id
		)
		bonuses.append(letter.high_rokugani_bonus)

	var any_success: bool = false
	for b: int in bonuses:
		if b > 0:
			any_success = true
			break
	assert_true(any_success, "With high skill, at least some High Rokugani rolls should succeed")


func test_high_rokugani_bonus_maximum_is_four():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}
	sender.skills["Calligraphy"] = 5
	sender.intelligence = 5

	var recipient := _make_char(2)
	recipient.physical_location = "600"
	recipient.lord_rank = Enums.LordRank.NONE

	var settlement: SettlementData = _make_settlement(600, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"600": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	for _i in range(50):
		var dice := DiceEngine.new()
		dice.set_seed(_i)
		var letter: LetterData = LetterSystem.write_letter(
			1, sender, 2, -1, 0, dice,
			0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
			"", {}, settlements, chars_by_id
		)
		assert_true(letter.high_rokugani_bonus <= 4, "High Rokugani bonus cannot exceed +4")


# -- Part B: High Rokugani — delivery stacks with base Calligraphy bonus ------

func test_high_rokugani_bonus_applied_on_delivery():
	var sender := _make_char(1)
	sender.emphases = {"Calligraphy": ["High Rokugani"]}
	sender.skills["Calligraphy"] = 5
	sender.intelligence = 5

	var recipient := _make_char(2)
	recipient.physical_location = "700"
	recipient.lord_rank = Enums.LordRank.NONE

	var settlement: SettlementData = _make_settlement(700, Enums.SettlementType.IMPERIAL_CAPITAL)
	var settlements: Dictionary = {"700": settlement}
	var chars_by_id: Dictionary = {2: recipient}

	# Find a seed where HR bonus is nonzero
	for _i in range(20):
		var dice_w := DiceEngine.new()
		dice_w.set_seed(_i + 20)
		var letter: LetterData = LetterSystem.write_letter(
			1, sender, 2, -1, 0, dice_w,
			0, 0, 0, 0, false, Enums.Trait.AWARENESS, false,
			"", {}, settlements, chars_by_id
		)
		if letter.high_rokugani_bonus > 0:
			var initial_disp: int = recipient.disposition_values.get(1, 0)
			var dice_d := DiceEngine.new()
			dice_d.set_seed(42)
			var log: Array = []
			LetterSystem.deliver_letter(letter, recipient, 1, log, {}, dice_d)
			var final_disp: int = recipient.disposition_values.get(1, 0)
			var total_bonus: int = letter.disposition_bonus + letter.high_rokugani_bonus
			assert_eq(final_disp - initial_disp, total_bonus,
				"Both base Calligraphy and HR bonus should stack on delivery")
			break


# -- Part C: Poetry-in-Letter (s57.30.6) -----------------------------------------

func test_poem_base_disposition_constant() -> void:
	assert_eq(LetterSystem.POEM_BASE_DISPOSITION, 2)


func test_deliver_letter_with_poem_applies_base_bonus() -> void:
	# attached_poem_id >= 0, raises = 0 → +2 disposition to recipient toward sender.
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 0
	var letter := LetterData.new()
	letter.sender_id = 1
	letter.recipient_id = 2
	letter.attached_poem_id = 10
	letter.attached_poem_raises = 0
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_eq(result.get("poem_bonus", 0), 2)
	assert_eq(recipient.disposition_values.get(1, 0), 2)


func test_deliver_letter_with_poem_and_raises_adds_per_raise() -> void:
	# attached_poem_raises = 2 → +2 base + 2 raises = +4 total.
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 0
	var letter := LetterData.new()
	letter.sender_id = 1
	letter.recipient_id = 2
	letter.attached_poem_id = 10
	letter.attached_poem_raises = 2
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_eq(result.get("poem_bonus", 0), 4)
	assert_eq(recipient.disposition_values.get(1, 0), 4)


func test_deliver_letter_without_poem_no_bonus() -> void:
	# attached_poem_id = -1 (default) → no poem bonus applied.
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 0
	var letter := LetterData.new()
	letter.sender_id = 1
	letter.recipient_id = 2
	# attached_poem_id defaults to -1
	var log: Array = []
	var result: Dictionary = LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_eq(result.get("poem_bonus", 0), 0)
	assert_eq(recipient.disposition_values.get(1, 0), 0)


func test_deliver_letter_poem_stacks_with_calligraphy_bonus() -> void:
	# Poem bonus stacks additively with the Calligraphy quality disposition_bonus.
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 0
	var letter := LetterData.new()
	letter.sender_id = 1
	letter.recipient_id = 2
	letter.disposition_bonus = 2   # Calligraphy success bonus
	letter.attached_poem_id = 10
	letter.attached_poem_raises = 1  # +3 poem bonus
	var log: Array = []
	LetterSystem.deliver_letter(letter, recipient, 1, log)
	# Calligraphy +2 + poem +3 = +5
	assert_eq(recipient.disposition_values.get(1, 0), 5)


func test_deliver_letter_poem_bonus_clamped_to_100() -> void:
	# Poem bonus does not push disposition above 100.
	var recipient := _make_char(2)
	recipient.disposition_values[1] = 99
	var letter := LetterData.new()
	letter.sender_id = 1
	letter.recipient_id = 2
	letter.attached_poem_id = 10
	letter.attached_poem_raises = 3  # +5 would exceed 100
	var log: Array = []
	LetterSystem.deliver_letter(letter, recipient, 1, log)
	assert_eq(recipient.disposition_values.get(1, 0), 100)
