extends GutTest
## Tests for s57.57 Topic Detection Mechanics.
## Covers: FUGITIVE_SIGHTING (Paths A/B/C), DISAPPEARANCE, JUSTICE_REFUSAL,
## BEHAVIORAL_ANOMALY Path B, and last_social_ic_day tracking.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_char(cid: int, name: String = "Test", clan: String = "Crane") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = name
	c.clan = clan
	c.physical_location = str(100 + cid)
	c.wounds_taken = 0
	c.disposition_values = {}
	c.topic_pool = []
	return c


func _make_crime(perp_id: int, status: Enums.LegalStatus = Enums.LegalStatus.FUGITIVE) -> CrimeRecord:
	var r := CrimeRecord.new()
	r.perpetrator_id = perp_id
	r.legal_status = status
	r.location = "101"  # same as char location default for perp
	r.crime_type = Enums.CrimeType.TREASON
	return r


func _make_settlement(sid: int, prov_id: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = prov_id
	return s


func _make_topic(tid: int, ttype: String, subject: int = -1) -> TopicData:
	var t := TopicData.new()
	t.topic_id = tid
	t.topic_type = ttype
	t.subject_character_id = subject
	t.resolved = false
	t.ic_day_created = 0
	t.tier = TopicData.Tier.TIER_4
	t.category = TopicData.Category.POLITICAL
	t.momentum = 5.0
	return t


func _make_letter(lid: int, sender_id: int, ic_day_sent: int) -> LetterData:
	var l := LetterData.new()
	l.letter_id = lid
	l.sender_id = sender_id
	l.recipient_id = 99
	l.ic_day_sent = ic_day_sent
	l.ic_day_arrival = ic_day_sent + 3
	l.topic = -1
	return l


# ---------------------------------------------------------------------------
# PATH C — STATUS THRESHOLD FIX (s57.57 §57.57.1)
# ---------------------------------------------------------------------------

func test_path_c_threshold_is_5():
	# The old threshold was 3.0; s57.57 corrects it to 5.0
	assert_false(FugitiveExtraditionSystem.generates_sighting_topic(4.9))
	assert_true(FugitiveExtraditionSystem.generates_sighting_topic(5.0))


# ---------------------------------------------------------------------------
# PATH A — CO-LOCATION DAILY SIGHTING (s57.57 §57.57.1 Path A)
# ---------------------------------------------------------------------------

func test_path_a_colocated_observer_fires_sighting():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"
	var observer := _make_char(2, "Observer", "Crane")
	observer.physical_location = "200"

	var crime := _make_crime(1)
	crime.location = "101"

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive, 2: observer}

	DayOrchestrator._process_fugitive_sighting_colocation(
		[crime], [fugitive, observer], chars_by_id, topics, next_id, 100, []
	)

	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "fugitive_sighting")
	assert_eq(topics[0].subject_character_id, 1)


func test_path_a_no_sighting_when_not_colocated():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"
	var observer := _make_char(2, "Observer", "Crane")
	observer.physical_location = "201"  # different settlement

	var crime := _make_crime(1)
	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive, 2: observer}

	DayOrchestrator._process_fugitive_sighting_colocation(
		[crime], [fugitive, observer], chars_by_id, topics, next_id, 100, []
	)

	assert_eq(topics.size(), 0)


func test_path_a_dedup_only_one_sighting_per_fugitive():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"
	var obs_a := _make_char(2, "ObserverA", "Crane")
	obs_a.physical_location = "200"
	var obs_b := _make_char(3, "ObserverB", "Lion")
	obs_b.physical_location = "200"

	var crime := _make_crime(1)
	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive, 2: obs_a, 3: obs_b}

	DayOrchestrator._process_fugitive_sighting_colocation(
		[crime], [fugitive, obs_a, obs_b], chars_by_id, topics, next_id, 100, []
	)

	# Only one topic even though two observers
	assert_eq(topics.size(), 1)


func test_path_a_no_sighting_when_topic_already_exists():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"
	var observer := _make_char(2, "Observer", "Crane")
	observer.physical_location = "200"

	var crime := _make_crime(1)
	var existing := _make_topic(5, "fugitive_sighting", 1)
	var topics: Array = [existing]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive, 2: observer}

	DayOrchestrator._process_fugitive_sighting_colocation(
		[crime], [fugitive, observer], chars_by_id, topics, next_id, 100, []
	)

	assert_eq(topics.size(), 1)  # no new topic added


# ---------------------------------------------------------------------------
# PATH B — ORDER_PATROL (s57.57 §57.57.1 Path B)
# ---------------------------------------------------------------------------

func test_path_b_patrol_in_province_fires_sighting():
	# Fugitive (Scorpion) is at settlement 200 in province 50 (Crane territory).
	# Crime was committed in province 99 (Crane). ORDER_PATROL covers province 50.
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"  # settlement 200 → province 50
	fugitive.clan = "Scorpion"

	var settlement_200 := _make_settlement(200, 50)  # fugitive's location
	var settlement_101 := _make_settlement(101, 99)  # crime location

	var crime_province := ProvinceData.new()
	crime_province.province_id = 99
	crime_province.clan = "Crane"  # different from "Scorpion" → cross-clan

	var crime := _make_crime(1)
	crime.location = "101"  # maps to province 99 via settlement_101

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}
	var provinces: Dictionary = {99: crime_province}
	var season_meta: Dictionary = {"patrolled_provinces": {50: true}}

	DayOrchestrator._process_fugitive_extradition_seasonal(
		[crime], [fugitive], chars_by_id, provinces,
		[settlement_200, settlement_101],
		topics, next_id, 100, season_meta
	)

	var sighting_count: int = 0
	for t: TopicData in topics:
		if t.topic_type == "fugitive_sighting":
			sighting_count += 1
	assert_eq(sighting_count, 1, "Path B patrol in fugitive's province fires sighting")


func test_path_b_no_patrol_no_sighting():
	# Same setup as Path B test but province 50 is NOT in patrolled_provinces.
	# No Path C trigger (low status). Expect no sighting topic.
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	fugitive.physical_location = "200"
	fugitive.status = 2.0  # below 5.0 threshold

	var settlement_200 := _make_settlement(200, 50)
	var settlement_101 := _make_settlement(101, 99)

	var crime_province := ProvinceData.new()
	crime_province.province_id = 99
	crime_province.clan = "Crane"

	var crime := _make_crime(1)
	crime.location = "101"

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}
	var provinces: Dictionary = {99: crime_province}
	var season_meta: Dictionary = {}  # no patrolled_provinces

	DayOrchestrator._process_fugitive_extradition_seasonal(
		[crime], [fugitive], chars_by_id, provinces,
		[settlement_200, settlement_101],
		topics, next_id, 100, season_meta
	)

	var sighting_count: int = 0
	for t: TopicData in topics:
		if t.topic_type == "fugitive_sighting":
			sighting_count += 1
	assert_eq(sighting_count, 0, "No patrol and low status produces no sighting")


# ---------------------------------------------------------------------------
# DISAPPEARANCE (s57.57 §57.57.2)
# ---------------------------------------------------------------------------

func test_disappearance_fires_after_90_day_silence():
	var c := _make_char(1, "Recluse", "Dragon")
	c.last_social_ic_day = 0  # set 90 days ago
	c.lord_id = 2

	var lord := _make_char(2, "Lord", "Dragon")

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c, 2: lord}

	DayOrchestrator._process_disappearance_check(
		[c, lord], chars_by_id, [], [], topics, next_id, 90
	)

	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "disappearance")
	assert_eq(topics[0].subject_character_id, 1)
	# Lord should be notified
	assert_true(lord.topic_pool.has(topics[0].topic_id))


func test_disappearance_no_fire_if_recent_social():
	var c := _make_char(1, "Active", "Crab")
	c.last_social_ic_day = 85  # only 5 days ago

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_disappearance_check(
		[c], chars_by_id, [], [], topics, next_id, 90
	)

	assert_eq(topics.size(), 0)


func test_disappearance_no_fire_if_letter_sent_recently():
	var c := _make_char(1, "Writer", "Phoenix")
	c.last_social_ic_day = 0  # 90+ days ago socially

	var recent_letter := _make_letter(1, 1, 50)  # sent 40 days ago (within 90-day window)

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_disappearance_check(
		[c], chars_by_id, [recent_letter], [], topics, next_id, 90
	)

	assert_eq(topics.size(), 0)


func test_disappearance_no_fire_if_fugitive():
	var c := _make_char(1, "Fugitive", "Scorpion")
	c.last_social_ic_day = 0

	var crime := _make_crime(1)  # FUGITIVE status

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_disappearance_check(
		[c], chars_by_id, [], [crime], topics, next_id, 90
	)

	assert_eq(topics.size(), 0)


func test_disappearance_dedup_no_double_fire():
	var c := _make_char(1, "Recluse", "Dragon")
	c.last_social_ic_day = 0

	var existing := _make_topic(5, "disappearance", 1)
	var topics: Array = [existing]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_disappearance_check(
		[c], chars_by_id, [], [], topics, next_id, 90
	)

	assert_eq(topics.size(), 1)  # no new topic


func test_disappearance_friend_associate_notified():
	var c := _make_char(1, "Recluse", "Dragon")
	c.last_social_ic_day = 0
	c.physical_location = "200"
	c.lord_id = -1  # no lord

	var associate := _make_char(3, "Friend", "Dragon")
	associate.physical_location = "200"
	associate.disposition_values = {1: 40}  # Friend tier

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c, 3: associate}

	DayOrchestrator._process_disappearance_check(
		[c, associate], chars_by_id, [], [], topics, next_id, 90
	)

	assert_eq(topics.size(), 1)
	assert_true(associate.topic_pool.has(topics[0].topic_id))


# ---------------------------------------------------------------------------
# JUSTICE_REFUSAL (s57.57 §57.57.3)
# ---------------------------------------------------------------------------

func test_justice_refusal_fires_after_90_days_with_extrad_request():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	var crime := _make_crime(1)

	var extrad_topic := _make_topic(7, "extradition_request", 1)
	extrad_topic.ic_day_created = 0  # created 100 days ago

	var topics: Array = [extrad_topic]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}

	DayOrchestrator._process_justice_refusal_check(
		[crime], chars_by_id, topics, next_id, 100, []
	)

	var refusal_topics: Array = []
	for t: TopicData in topics:
		if t.topic_type == "justice_refusal":
			refusal_topics.append(t)

	assert_eq(refusal_topics.size(), 1)
	assert_eq(refusal_topics[0].tier, TopicData.Tier.TIER_3)
	assert_eq(refusal_topics[0].subject_character_id, 1)


func test_justice_refusal_no_fire_without_extrad_request():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	var crime := _make_crime(1)

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}

	DayOrchestrator._process_justice_refusal_check(
		[crime], chars_by_id, topics, next_id, 100, []
	)

	assert_eq(topics.size(), 0)


func test_justice_refusal_no_fire_before_90_days():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	var crime := _make_crime(1)

	var extrad_topic := _make_topic(7, "extradition_request", 1)
	extrad_topic.ic_day_created = 50  # only 50 days ago

	var topics: Array = [extrad_topic]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}

	DayOrchestrator._process_justice_refusal_check(
		[crime], chars_by_id, topics, next_id, 100, []
	)

	var new_topics: int = 0
	for t: TopicData in topics:
		if t.topic_type == "justice_refusal":
			new_topics += 1
	assert_eq(new_topics, 0)


func test_justice_refusal_dedup():
	var fugitive := _make_char(1, "Fugitive", "Scorpion")
	var crime := _make_crime(1)

	var extrad_topic := _make_topic(7, "extradition_request", 1)
	extrad_topic.ic_day_created = 0
	var existing_refusal := _make_topic(8, "justice_refusal", 1)
	var topics: Array = [extrad_topic, existing_refusal]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: fugitive}

	DayOrchestrator._process_justice_refusal_check(
		[crime], chars_by_id, topics, next_id, 100, []
	)

	var refusal_count: int = 0
	for t: TopicData in topics:
		if t.topic_type == "justice_refusal":
			refusal_count += 1
	assert_eq(refusal_count, 1)


# ---------------------------------------------------------------------------
# BEHAVIORAL_ANOMALY PATH B (s57.57 §57.57.4)
# ---------------------------------------------------------------------------

func test_behavioral_anomaly_fires_after_gap_with_3_prior_letters():
	var c := _make_char(1, "Correspondent", "Lion")
	c.lord_id = -1

	# 3 old letters (beyond the 90-day window at ic_day=100)
	var l1 := _make_letter(1, 1, 1)
	var l2 := _make_letter(2, 1, 10)
	var l3 := _make_letter(3, 1, 20)

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_behavioral_anomaly_check(
		[c], chars_by_id, [l1, l2, l3], topics, next_id, 100
	)

	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "behavioral_anomaly")
	assert_eq(topics[0].subject_character_id, 1)


func test_behavioral_anomaly_no_fire_with_only_2_prior_letters():
	var c := _make_char(1, "Quiet", "Lion")
	c.lord_id = -1

	var l1 := _make_letter(1, 1, 1)
	var l2 := _make_letter(2, 1, 10)

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_behavioral_anomaly_check(
		[c], chars_by_id, [l1, l2], topics, next_id, 100
	)

	assert_eq(topics.size(), 0)


func test_behavioral_anomaly_no_fire_if_recent_letter():
	var c := _make_char(1, "Writer", "Lion")
	c.lord_id = -1

	var old1 := _make_letter(1, 1, 1)
	var old2 := _make_letter(2, 1, 10)
	var old3 := _make_letter(3, 1, 20)
	var recent := _make_letter(4, 1, 95)  # within 90-day window at ic_day=100

	var topics: Array = []
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_behavioral_anomaly_check(
		[c], chars_by_id, [old1, old2, old3, recent], topics, next_id, 100
	)

	assert_eq(topics.size(), 0)


func test_behavioral_anomaly_dedup():
	var c := _make_char(1, "Correspondent", "Lion")
	c.lord_id = -1

	var l1 := _make_letter(1, 1, 1)
	var l2 := _make_letter(2, 1, 10)
	var l3 := _make_letter(3, 1, 20)

	var existing := _make_topic(5, "behavioral_anomaly", 1)
	var topics: Array = [existing]
	var next_id: Array = [10]
	var chars_by_id: Dictionary = {1: c}

	DayOrchestrator._process_behavioral_anomaly_check(
		[c], chars_by_id, [l1, l2, l3], topics, next_id, 100
	)

	assert_eq(topics.size(), 1)  # no new topic added


# ---------------------------------------------------------------------------
# LAST_SOCIAL_IC_DAY TRACKING (s57.57 §57.57.5)
# ---------------------------------------------------------------------------

func test_social_ic_day_updated_from_conversations():
	var a := _make_char(1, "Char A", "Crane")
	var b := _make_char(2, "Char B", "Lion")
	a.last_social_ic_day = -1
	b.last_social_ic_day = -1

	var chars_by_id: Dictionary = {1: a, 2: b}
	var conv_results: Array = [{"char_a_id": 1, "char_b_id": 2}]

	DayOrchestrator._update_social_ic_day_from_conversations(conv_results, chars_by_id, 55)

	assert_eq(a.last_social_ic_day, 55)
	assert_eq(b.last_social_ic_day, 55)


func test_social_ic_day_updated_from_letter_delivery():
	var sender := _make_char(1, "Sender", "Crane")
	var recipient := _make_char(2, "Recipient", "Lion")
	sender.last_social_ic_day = -1
	recipient.last_social_ic_day = -1

	var chars_by_id: Dictionary = {1: sender, 2: recipient}
	var letter_results: Array = [
		{"sender_id": 1, "recipient_id": 2, "delivered": true}
	]

	DayOrchestrator._update_social_ic_day_from_letters(letter_results, chars_by_id, 77)

	assert_eq(sender.last_social_ic_day, 77)
	assert_eq(recipient.last_social_ic_day, 77)


func test_social_ic_day_not_updated_for_undeliverable():
	var sender := _make_char(1, "Sender", "Crane")
	sender.last_social_ic_day = -1

	var chars_by_id: Dictionary = {1: sender}
	var letter_results: Array = [
		{"sender_id": 1, "recipient_id": 2, "undeliverable": true}
	]

	DayOrchestrator._update_social_ic_day_from_letters(letter_results, chars_by_id, 77)

	assert_eq(sender.last_social_ic_day, -1)
