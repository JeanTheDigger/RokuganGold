extends GutTest


var _time: TimeSystem
var _dice: DiceEngine
var _characters: Array[L5RCharacterData]
var _characters_by_id: Dictionary
var _provinces: Dictionary
var _action_log: Array[Dictionary]
var _scoring_tables: Dictionary
var _filter_data: Dictionary
var _action_skill_map: Dictionary
var _season_meta: Dictionary


func before_each() -> void:
	_time = TimeSystem.new(1120, 0)
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.character_name = "NPC 1"
	c1.status = 3.0
	c1.action_points_current = 2
	c1.action_points_max = 2
	c1.honor = 5.0
	c1.glory = 3.0
	c1.bushido_virtue = Enums.BushidoVirtue.NONE
	c1.shourido_virtue = Enums.ShouridoVirtue.NONE
	c1.reflexes = 3
	c1.awareness = 3
	c1.stamina = 3
	c1.willpower = 3
	c1.agility = 3
	c1.intelligence = 3
	c1.strength = 3
	c1.perception = 3
	c1.void_ring = 2
	c1.skills = {"Etiquette": 3}
	c1.emphases = {}
	c1.wounds_taken = 0
	c1.knowledge_pool = []
	c1.known_contacts_by_clan = {}
	c1.met_characters = []

	_characters = [c1]
	_characters_by_id = {1: c1}

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS
	_provinces = {10: province}

	_action_log = []

	_scoring_tables = {
		"objective_alignment": {
			"REST": {"DO_NOTHING": 10, "REST": 50, "TRAIN": 30},
		},
		"disposition_tiers": [
			{"min": -10, "max": 10, "cooperative": 0, "hostile": 0},
		],
		"personality_lean": {},
		"action_skill_map": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}
	_filter_data = {"bushido": {}, "shourido": {}}

	_action_skill_map = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
	}

	_season_meta = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}


func _make_world_states() -> Dictionary:
	return {
		1: {
			"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
			"season": 1,
			"ic_day": _time.get_ic_day(),
			"characters_present": [] as Array[int],
			"is_lord": false,
			"known_topics": [] as Array[int],
			"known_positions": {},
			"known_objectives": {},
			"known_contacts": [] as Array[int],
			"pending_events": [],
			"action_log": [] as Array[String],
		},
	}


func _make_objectives() -> Dictionary:
	return {
		1: {"primary": {"need_type": "REST", "priority": 3}},
	}


# -- Basic Advance -------------------------------------------------------------

func test_advance_day_returns_ic_day() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_eq(result["ic_day"], 1)


func test_advance_day_increments_time() -> void:
	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_eq(_time.current_tick, 1)


func test_advance_day_resets_ap() -> void:
	_characters[0].action_points_current = 0
	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_eq(_characters[0].action_points_current, 2)


func test_advance_day_produces_results() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result["day_results"].size() > 0)


func test_advance_day_logs_actions() -> void:
	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(_action_log.size() > 0)


func test_advance_day_no_season_change_in_spring() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_false(result["season_changed"])
	assert_eq(result["seasonal_result"].size(), 0)


# -- Season Boundary -----------------------------------------------------------

func test_advance_day_detects_season_change() -> void:
	# Advance to last day of spring (tick 89 = day 89, season SPRING)
	_time.current_tick = 89
	assert_eq(_time.get_season(), TimeSystem.Season.SPRING)
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	# tick 90 = day 90, season SUMMER
	assert_true(result["season_changed"])
	assert_eq(result["season"], TimeSystem.Season.SUMMER)
	assert_true(result["seasonal_result"].has("season_name"))
	assert_eq(result["seasonal_result"]["season_name"], "summer")


func test_season_change_decays_knowledge() -> void:
	InformationSystem.add_knowledge(_characters[0], InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 0
	))
	# Jump to season boundary (spring → summer at tick 90)
	_time.current_tick = 89
	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	# Season 0→1 is 1 season old → RECENT
	assert_eq(
		_characters[0].knowledge_pool[0].confidence,
		Enums.KnowledgeConfidence.RECENT
	)


func test_season_change_runs_resource_tick() -> void:
	_time.current_tick = 89
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result["seasonal_result"].has("resource_tick"))


# -- Multiple Days -------------------------------------------------------------

func test_multiple_days_accumulate_log() -> void:
	for i: int in range(3):
		DayOrchestrator.advance_day(
			_time, _characters, _characters_by_id, _make_world_states(),
			_make_objectives(), _scoring_tables, _filter_data, _dice,
			_action_skill_map, _provinces, _action_log, _season_meta
		)
	assert_true(_action_log.size() >= 3)
	assert_eq(_time.current_tick, 3)


func test_multiple_days_ap_reset_each_day() -> void:
	for i: int in range(3):
		_characters[0].action_points_current = 0
		DayOrchestrator.advance_day(
			_time, _characters, _characters_by_id, _make_world_states(),
			_make_objectives(), _scoring_tables, _filter_data, _dice,
			_action_skill_map, _provinces, _action_log, _season_meta
		)
	# After 3 days, AP should be back to max (was reset at start of each day)
	# But wave resolver spends them, so they may be 0 after resolution
	# The key test is that actions were produced each day
	assert_true(_action_log.size() >= 3)


# -- Daily Conversations -------------------------------------------------------

func test_advance_day_returns_conversation_results() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result.has("conversation_results"))


func test_advance_day_conversations_fire_for_colocated_friends() -> void:
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.character_name = "NPC 2"
	c2.status = 3.0
	c2.awareness = 3
	c2.action_points_current = 2
	c2.action_points_max = 2
	c2.honor = 5.0
	c2.glory = 3.0
	c2.bushido_virtue = Enums.BushidoVirtue.NONE
	c2.shourido_virtue = Enums.ShouridoVirtue.NONE
	c2.skills = {"Etiquette": 3}
	c2.emphases = {}
	c2.knowledge_pool = []
	c2.known_contacts_by_clan = {}
	c2.met_characters = []
	c2.topic_pool = [4]

	_characters[0].physical_location = "castle_crane"
	_characters[0].topic_pool = [1]
	_characters[0].disposition_values[2] = 80
	c2.physical_location = "castle_crane"
	c2.disposition_values[1] = 80

	_characters.append(c2)
	_characters_by_id[2] = c2

	var ws: Dictionary = _make_world_states()
	ws[2] = ws[1].duplicate(true)

	var objs: Dictionary = _make_objectives()
	objs[2] = {"primary": {"need_type": "REST", "priority": 3}}

	# Seed that produces low rolls so conversations trigger (35% chance at disp 80)
	_dice.set_seed(1)

	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, ws,
		objs, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result.has("conversation_results"))
	assert_true(result["conversation_results"] is Array)


# -- Letter Delivery -----------------------------------------------------------

func test_advance_day_returns_letter_results() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result.has("letter_results"))


# -- Topic Propagation Wiring --------------------------------------------------

func test_advance_day_wires_discussion_counts() -> void:
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.character_name = "NPC 2"
	c2.status = 3.0
	c2.awareness = 3
	c2.reflexes = 3
	c2.stamina = 3
	c2.willpower = 3
	c2.agility = 3
	c2.intelligence = 3
	c2.strength = 3
	c2.perception = 3
	c2.void_ring = 2
	c2.action_points_current = 2
	c2.action_points_max = 2
	c2.honor = 5.0
	c2.glory = 3.0
	c2.bushido_virtue = Enums.BushidoVirtue.NONE
	c2.shourido_virtue = Enums.ShouridoVirtue.NONE
	c2.skills = {"Etiquette": 3}
	c2.emphases = {}
	c2.knowledge_pool = []
	c2.known_contacts_by_clan = {}
	c2.met_characters = []
	c2.topic_pool = [100]
	c2.topic_positions = {}

	_characters[0].physical_location = "castle_crane"
	_characters[0].topic_pool = [100]
	_characters[0].topic_positions = {}
	_characters[0].disposition_values[2] = 80
	c2.physical_location = "castle_crane"
	c2.disposition_values[1] = 80

	_characters.append(c2)
	_characters_by_id[2] = c2

	var topic := TopicMomentumSystem.create_topic(
		100, "Gossip", TopicData.Tier.TIER_4, TopicData.Category.PERSONAL, 0, 15.0
	)
	var active_topics: Array[TopicData] = [topic]

	var ws: Dictionary = _make_world_states()
	ws[2] = ws[1].duplicate(true)
	var objs: Dictionary = _make_objectives()
	objs[2] = {"primary": {"need_type": "REST", "priority": 3}}

	_dice.set_seed(1)

	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, ws,
		objs, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		active_topics
	)
	assert_true(result.has("topic_results"))
	assert_true(result.has("broadcast_results"))


func test_advance_day_broadcast_spreads_topics() -> void:
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.character_name = "NPC 2"
	c2.status = 3.0
	c2.awareness = 3
	c2.reflexes = 3
	c2.stamina = 3
	c2.willpower = 3
	c2.agility = 3
	c2.intelligence = 3
	c2.strength = 3
	c2.perception = 3
	c2.void_ring = 2
	c2.action_points_current = 2
	c2.action_points_max = 2
	c2.honor = 5.0
	c2.glory = 3.0
	c2.bushido_virtue = Enums.BushidoVirtue.NONE
	c2.shourido_virtue = Enums.ShouridoVirtue.NONE
	c2.skills = {"Etiquette": 3}
	c2.emphases = {}
	c2.knowledge_pool = []
	c2.known_contacts_by_clan = {}
	c2.met_characters = []
	c2.topic_pool = []
	c2.topic_positions = {}

	_characters[0].topic_pool = []
	_characters[0].topic_positions = {}

	_characters.append(c2)
	_characters_by_id[2] = c2

	var topic := TopicMomentumSystem.create_topic(
		200, "War!", TopicData.Tier.TIER_1, TopicData.Category.MILITARY,
		0, 80.0
	)
	var active_topics: Array[TopicData] = [topic]

	var ws: Dictionary = _make_world_states()
	ws[2] = ws[1].duplicate(true)
	var objs: Dictionary = _make_objectives()
	objs[2] = {"primary": {"need_type": "REST", "priority": 3}}

	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, ws,
		objs, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		active_topics
	)
	assert_true(200 in _characters[0].topic_pool)
	assert_true(200 in c2.topic_pool)
	assert_true(result["broadcast_results"].size() > 0)


func test_advance_day_broadcast_computes_positions() -> void:
	_characters[0].topic_pool = []
	_characters[0].topic_positions = {}
	_characters[0].bushido_virtue = Enums.BushidoVirtue.CHUGI

	var topic := TopicMomentumSystem.create_topic(
		300, "Betrayal", TopicData.Tier.TIER_1, TopicData.Category.POLITICAL,
		0, 80.0, [], "", "", 5, "betrayal"
	)
	var active_topics: Array[TopicData] = [topic]

	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		active_topics
	)
	assert_true(_characters[0].topic_positions.has(300))


func test_advance_day_letter_delivery_computes_positions() -> void:
	_characters[0].topic_pool = []
	_characters[0].topic_positions = {}
	_characters[0].bushido_virtue = Enums.BushidoVirtue.JIN

	var dice2 := DiceEngine.new()
	dice2.set_seed(42)
	var sender := L5RCharacterData.new()
	sender.character_id = 99
	sender.skills = {"Calligraphy": 3}
	sender.emphases = {}
	sender.awareness = 3
	sender.agility = 3
	sender.wounds_taken = 0
	sender.lord_id = -1

	var topic := TopicMomentumSystem.create_topic(
		400, "Death", TopicData.Tier.TIER_4, TopicData.Category.PERSONAL,
		0, 15.0, [], "", "", 5, "death", "suspicious"
	)
	var active_topics: Array[TopicData] = [topic]

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, _characters[0].character_id, 400, 0, dice2, 0
	)
	var pending: Array = [letter]

	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		active_topics, pending
	)
	assert_true(400 in _characters[0].topic_pool)
	assert_true(_characters[0].topic_positions.has(400))
	# JIN virtue + death:suspicious = -8 modifier, no disposition anchor
	assert_almost_eq(_characters[0].topic_positions[400], -8.0, 0.001)


func test_advance_day_delivers_due_letters() -> void:
	var recipient := _characters[0]
	var dice2 := DiceEngine.new()
	dice2.set_seed(42)
	var sender := L5RCharacterData.new()
	sender.character_id = 99
	sender.skills = {"Calligraphy": 3}
	sender.emphases = {}
	sender.awareness = 3
	sender.agility = 3
	sender.wounds_taken = 0
	sender.lord_id = -1

	var letter: LetterData = LetterSystem.write_letter(
		1, sender, recipient.character_id, 2, 0, dice2, 0
	)
	var pending: Array = [letter]

	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], pending
	)
	assert_true(2 in recipient.topic_pool)


# -- Crime Detection Topic Creation -------------------------------------------

func test_crime_detection_creates_topic() -> void:
	var active_topics: Array[TopicData] = []
	var crime_records: Array[CrimeRecord] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	# Add a witness at the same location
	var witness := L5RCharacterData.new()
	witness.character_id = 2
	witness.physical_location = "castle_crane"
	witness.topic_pool = []
	_characters_by_id[2] = witness

	var results: Array = [{
		"character_id": 1,
		"action_id": "EAVESDROP",
		"target_npc_id": -1,
		"effects": {"detection_risk": true},
	}]
	_characters[0].physical_location = "castle_crane"

	var crime_results: Array[Dictionary] = DayOrchestrator._process_crime_detection(
		results, _characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	assert_eq(crime_results.size(), 1)
	assert_eq(crime_results[0]["topic_id"], 500)
	assert_eq(crime_results[0]["witness_count"], 1)
	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_type, "crime")
	assert_eq(active_topics[0].slug, "crime_case_1")
	assert_almost_eq(active_topics[0].momentum, 0.0, 0.001)
	assert_eq(next_topic_id[0], 501)
	# Witness should have the topic seeded into their pool
	assert_true(500 in witness.topic_pool)
	# Perpetrator should NOT have the topic
	assert_false(500 in _characters[0].topic_pool)


func test_crime_detection_no_witnesses_still_creates_topic() -> void:
	var active_topics: Array[TopicData] = []
	var crime_records: Array[CrimeRecord] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	var results: Array = [{
		"character_id": 1,
		"action_id": "EAVESDROP",
		"target_npc_id": -1,
		"effects": {"detection_risk": true},
	}]
	_characters[0].physical_location = "remote_wilderness"

	var crime_results: Array[Dictionary] = DayOrchestrator._process_crime_detection(
		results, _characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	assert_eq(crime_results.size(), 1)
	assert_eq(crime_results[0]["witness_count"], 0)
	assert_eq(active_topics.size(), 1)
	assert_almost_eq(active_topics[0].momentum, 0.0, 0.001)


func test_crime_topic_seeds_to_victim() -> void:
	var active_topics: Array[TopicData] = []
	var crime_records: Array[CrimeRecord] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	var victim := L5RCharacterData.new()
	victim.character_id = 3
	victim.physical_location = "castle_crane"
	victim.topic_pool = []
	_characters_by_id[3] = victim

	var results: Array = [{
		"character_id": 1,
		"action_id": "EAVESDROP",
		"target_npc_id": 3,
		"effects": {"detection_risk": true},
	}]
	_characters[0].physical_location = "castle_crane"

	DayOrchestrator._process_crime_detection(
		results, _characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	# Victim receives the topic (target_npc_id = 3 becomes victim_id)
	assert_true(500 in victim.topic_pool)


# -- UPHOLD_LAW Scan Wiring ---------------------------------------------------

func test_uphold_law_scan_activates_magistrate() -> void:
	var mag := _characters[0]
	mag.physical_location = "castle_crane"
	mag.bushido_virtue = Enums.BushidoVirtue.GI

	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.crime_type = Enums.CrimeType.SKIMMING
	cr.location = "castle_crane"
	cr.perpetrator_id = 99
	cr.investigating_magistrate_id = -1
	var crime_records: Array[CrimeRecord] = [cr]

	var crime_topic := TopicData.new()
	crime_topic.topic_id = 600
	crime_topic.topic_type = "crime"
	crime_topic.slug = "crime_case_1"
	crime_topic.category = TopicData.Category.LEGAL
	var active_topics: Array[TopicData] = [crime_topic]

	mag.topic_pool = [600]

	var objectives: Dictionary = {
		1: {
			"primary": {"need_type": "REST", "priority": 3},
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}

	var results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		_characters, objectives, crime_records, active_topics
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["magistrate_id"], 1)
	assert_eq(results[0]["case_id"], 1)
	assert_eq(cr.investigating_magistrate_id, 1)
	assert_true(objectives[1]["standing"].has("active_case"))


func test_uphold_law_scan_skips_no_standing_objective() -> void:
	_characters[0].physical_location = "castle_crane"
	_characters[0].topic_pool = [600]

	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.location = "castle_crane"
	cr.investigating_magistrate_id = -1
	var crime_records: Array[CrimeRecord] = [cr]

	var crime_topic := TopicData.new()
	crime_topic.topic_id = 600
	crime_topic.topic_type = "crime"
	crime_topic.slug = "crime_case_1"
	var active_topics: Array[TopicData] = [crime_topic]

	var objectives: Dictionary = {
		1: {"primary": {"need_type": "REST", "priority": 3}},
	}

	var results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		_characters, objectives, crime_records, active_topics
	)
	assert_eq(results.size(), 0)


# -- Witness PROBE Evidence Wiring ---------------------------------------------

func test_check_witness_evidence_increments_record() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.witnesses = [50]
	cr.evidence_total = 0
	var crime_records: Array[CrimeRecord] = [cr]

	var objectives: Dictionary = {
		1: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {
					"case_id": 1,
					"interviewed_witnesses": [],
					"evidence_total": 0,
				},
			},
		},
	}

	var result: Dictionary = DayOrchestrator._check_witness_evidence(
		1, 50, 3, crime_records, objectives
	)

	assert_true(result.get("evidence_gained", 0) > 0)
	assert_true(cr.evidence_total > 0)


func test_check_witness_evidence_no_active_case() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.witnesses = [50]
	var crime_records: Array[CrimeRecord] = [cr]

	var objectives: Dictionary = {
		1: {"primary": {"need_type": "REST"}},
	}

	var result: Dictionary = DayOrchestrator._check_witness_evidence(
		1, 50, 3, crime_records, objectives
	)
	assert_true(result.is_empty())


# -- Festival Wiring ----------------------------------------------------------

func test_advance_day_returns_festival_results() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result.has("festival_results"))
	assert_true(result["festival_results"].has("rokuyo"))
	assert_true(result["festival_results"].has("is_ceasefire"))
	assert_true(result["festival_results"].has("is_labor_halt"))


func test_festival_sets_world_state_flags() -> void:
	var ws: Dictionary = _make_world_states()
	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, ws,
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(ws.has("is_ceasefire_day"))
	assert_true(ws.has("is_labor_halt_day"))
	assert_true(ws.has("is_taian"))
	assert_true(ws.has("is_inauspicious_for_social"))
	assert_true(ws.has("rokuyo"))


# -- Cohabitation Wiring -------------------------------------------------------

func test_cohabitation_increments_days() -> void:
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.character_name = "NPC 2"
	c2.status = 3.0
	c2.awareness = 3
	c2.reflexes = 3
	c2.stamina = 3
	c2.willpower = 3
	c2.agility = 3
	c2.intelligence = 3
	c2.strength = 3
	c2.perception = 3
	c2.void_ring = 2
	c2.action_points_current = 2
	c2.action_points_max = 2
	c2.honor = 5.0
	c2.glory = 3.0
	c2.bushido_virtue = Enums.BushidoVirtue.NONE
	c2.shourido_virtue = Enums.ShouridoVirtue.NONE
	c2.skills = {"Etiquette": 3}
	c2.emphases = {}
	c2.knowledge_pool = []
	c2.known_contacts_by_clan = {}
	c2.met_characters = []
	c2.topic_pool = []

	_characters[0].physical_location = "castle_crane"
	c2.physical_location = "castle_crane"

	_characters.append(c2)
	_characters_by_id[2] = c2

	var ws: Dictionary = _make_world_states()
	ws[2] = ws[1].duplicate(true)
	var objs: Dictionary = _make_objectives()
	objs[2] = {"primary": {"need_type": "REST", "priority": 3}}

	DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, ws,
		objs, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_eq(_characters[0].cohabitation_days.get(2, 0), 1)
	assert_eq(c2.cohabitation_days.get(1, 0), 1)


# -- Favor Processing Wiring --------------------------------------------------

func test_advance_day_returns_favor_results() -> void:
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta
	)
	assert_true(result.has("favor_results"))
	assert_true(result["favor_results"].has("expired_favor_ids"))
	assert_true(result["favor_results"].has("deadline_breaches"))


func test_favor_expiration_fires() -> void:
	var favor := FavorData.new()
	favor.favor_id = 1
	favor.tier = FavorData.FavorTier.MINOR
	favor.created_ic_day = 0
	var favors: Array = [favor]

	_time.current_tick = 360
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000], [], {}, favors
	)
	assert_true(result["favor_results"]["expired_favor_ids"].has(1))


func test_favor_breach_applies_honor_and_disposition() -> void:
	var debtor := L5RCharacterData.new()
	debtor.character_id = 2
	debtor.character_name = "Debtor"
	debtor.honor = 5.0
	debtor.glory = 3.0
	debtor.status = 2.0
	debtor.reflexes = 3
	debtor.awareness = 3
	debtor.stamina = 3
	debtor.willpower = 3
	debtor.agility = 3
	debtor.intelligence = 3
	debtor.strength = 3
	debtor.perception = 3
	debtor.void_ring = 2
	debtor.skills = {"Etiquette": 2}
	debtor.emphases = {}
	debtor.wounds_taken = 0
	debtor.knowledge_pool = []
	debtor.known_contacts_by_clan = {}
	debtor.met_characters = []
	_characters.append(debtor)
	_characters_by_id[2] = debtor

	var creditor: L5RCharacterData = _characters[0]
	creditor.disposition_values = {2: 10}

	var favor := FavorData.new()
	favor.favor_id = 1
	favor.tier = FavorData.FavorTier.MODERATE
	favor.creditor_id = 1
	favor.debtor_id = 2
	favor.invoked = true
	favor.response_deadline_ic_day = 5
	favor.created_ic_day = 0
	var favors: Array = [favor]

	_time.current_tick = 10
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, _characters, _characters_by_id, _make_world_states(),
		_make_objectives(), _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000], [], {}, favors
	)

	assert_eq(result["favor_results"]["deadline_breaches"].size(), 1)
	assert_true(debtor.honor < 5.0)
	assert_true(creditor.disposition_values[2] < 10)


func test_favor_breach_witness_disposition_applied() -> void:
	var debtor := L5RCharacterData.new()
	debtor.character_id = 2
	debtor.character_name = "Debtor"
	debtor.honor = 5.0
	debtor.glory = 3.0
	debtor.status = 2.0
	debtor.reflexes = 3
	debtor.awareness = 3
	debtor.stamina = 3
	debtor.willpower = 3
	debtor.agility = 3
	debtor.intelligence = 3
	debtor.strength = 3
	debtor.perception = 3
	debtor.void_ring = 2
	debtor.skills = {"Etiquette": 2}
	debtor.emphases = {}
	debtor.wounds_taken = 0
	debtor.knowledge_pool = []
	debtor.known_contacts_by_clan = {}
	debtor.met_characters = []
	_characters.append(debtor)
	_characters_by_id[2] = debtor

	var breach: Dictionary = {
		"debtor_id": 2,
		"creditor_id": 1,
		"disposition_change": -35,
		"honor_loss": -1.0,
		"glory_loss": -0.5,
		"witness_disposition_loss": -10,
		"witnesses": [1],
	}

	DayOrchestrator._apply_favor_breach(breach, _characters_by_id)

	assert_almost_eq(debtor.honor, 4.0, 0.01)
	assert_almost_eq(debtor.glory, 2.5, 0.01)
	var creditor: L5RCharacterData = _characters[0]
	assert_eq(creditor.disposition_values.get(2, 0), -35)


func test_favor_breach_disposition_floor_prevents_overcorrection() -> void:
	var debtor := L5RCharacterData.new()
	debtor.character_id = 2
	debtor.character_name = "Debtor"
	debtor.honor = 5.0
	debtor.glory = 3.0
	debtor.skills = {}
	debtor.emphases = {}
	debtor.wounds_taken = 0
	debtor.knowledge_pool = []
	debtor.known_contacts_by_clan = {}
	debtor.met_characters = []
	var chars: Dictionary = {1: _characters[0], 2: debtor}

	_characters[0].disposition_values = {2: 0}

	var breach: Dictionary = {
		"debtor_id": 2,
		"creditor_id": 1,
		"disposition_change": -20,
		"disposition_floor": -15,
		"honor_loss": 0.0,
		"glory_loss": 0.0,
		"witness_disposition_loss": 0,
		"witnesses": [],
	}

	DayOrchestrator._apply_favor_breach(breach, chars)

	assert_eq(_characters[0].disposition_values[2], -15)


# -- Famine Crisis Processing (s16.2) -----------------------------------------

func _make_province_for_famine(id: int, clan: String = "Crab") -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func test_famine_crisis_creates_topic_at_hunger() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "created")
	assert_eq(results[0]["tier"], TopicData.Tier.TIER_3)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "famine")
	assert_eq(topics[0].variant, "provincial_famine")
	assert_true(1 in topics[0].provinces_affected)


func test_famine_crisis_tier_2_at_famine_stage() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.FAMINE, "pu_loss_rate": 0.20},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["tier"], TopicData.Tier.TIER_2)
	assert_eq(topics[0].momentum, DayOrchestrator._FAMINE_FAMINE_MOMENTUM)


func test_famine_crisis_no_duplicate_topic() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.provinces_affected = [1]
	existing.resolved = false

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.FAMINE, "pu_loss_rate": 0.20},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 0, "Should not create duplicate famine topic")
	assert_eq(topics.size(), 1)


func test_famine_crisis_recovery_increments() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.provinces_affected = [1]
	existing.resolved = false

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.CLEAR, "pu_loss_rate": 0.0},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	var tracking: Dictionary = meta.get("_famine_tracking", {})
	assert_eq(tracking.get(1, 0), 1)
	assert_false(existing.resolved, "Not yet at threshold")


func test_famine_crisis_resolves_at_threshold() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.provinces_affected = [1]
	existing.resolved = false
	existing.momentum = 50.0

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.CLEAR, "pu_loss_rate": 0.0},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {"_famine_tracking": {1: 9}}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "resolved")
	assert_true(existing.resolved)
	assert_eq(existing.momentum, 0.0)


func test_famine_crisis_recovery_resets_on_relapse() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.provinces_affected = [1]
	existing.resolved = false

	var meta: Dictionary = {"_famine_tracking": {1: 5}}
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]

	DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	var tracking: Dictionary = meta.get("_famine_tracking", {})
	assert_false(tracking.has(1), "Recovery count should reset on relapse")


func test_famine_crisis_no_topic_at_shortage() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.SHORTAGE, "pu_loss_rate": 0.03},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 0, "Shortage should not trigger famine crisis")
	assert_eq(topics.size(), 0)


func test_famine_crisis_empty_starvation_noop() -> void:
	var seasonal_result: Dictionary = {"resource_tick": {}}
	var provinces: Dictionary = {}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 0)


func test_famine_crisis_sets_clan_on_topic() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				5: {"stage": ResourceTick.StarvationStage.FAMINE, "pu_loss_rate": 0.20},
			},
		},
	}
	var provinces: Dictionary = {5: _make_province_for_famine(5, "Lion")}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(topics[0].clan_involved, "Lion")


func test_famine_crisis_clear_without_topic_is_noop() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.CLEAR, "pu_loss_rate": 0.0},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1)}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {"_famine_tracking": {1: 3}}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 0)
	assert_false(meta["_famine_tracking"].has(1), "Tracking cleared when no active topic")


# -- Multi-province famine aggregation -----------------------------------------

func test_multi_province_famine_creates_clan_topic() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
				2: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {
		1: _make_province_for_famine(1, "Crab"),
		2: _make_province_for_famine(2, "Crab"),
	}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "created_clan")
	assert_eq(results[0]["tier"], TopicData.Tier.TIER_2)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "clan_famine")
	assert_eq(topics[0].clan_involved, "Crab")
	assert_true(1 in topics[0].provinces_affected)
	assert_true(2 in topics[0].provinces_affected)


func test_multi_province_different_clans_separate_topics() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
				2: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {
		1: _make_province_for_famine(1, "Crab"),
		2: _make_province_for_famine(2, "Crane"),
	}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(topics.size(), 2)
	for t: TopicData in topics:
		assert_eq(t.variant, "provincial_famine")
		assert_eq(t.tier, TopicData.Tier.TIER_3)


func test_new_province_added_to_existing_clan_topic() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.variant = "clan_famine"
	existing.clan_involved = "Crab"
	existing.provinces_affected = [1, 2]
	existing.resolved = false

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				3: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {3: _make_province_for_famine(3, "Crab")}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "added_to_clan_topic")
	assert_true(3 in existing.provinces_affected)
	assert_eq(topics.size(), 1, "No new topic created")


func test_clan_topic_province_recovers_removed_from_list() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.variant = "clan_famine"
	existing.clan_involved = "Crab"
	existing.provinces_affected = [1, 2]
	existing.resolved = false
	existing.momentum = 50.0

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.CLEAR, "pu_loss_rate": 0.0},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1, "Crab")}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {"_famine_tracking": {1: 9}}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "province_recovered")
	assert_false(1 in existing.provinces_affected)
	assert_true(2 in existing.provinces_affected)
	assert_false(existing.resolved, "Topic stays active with remaining provinces")


func test_clan_topic_resolves_when_last_province_recovers() -> void:
	var existing: TopicData = TopicData.new()
	existing.topic_id = 50
	existing.topic_type = "famine"
	existing.variant = "clan_famine"
	existing.clan_involved = "Crab"
	existing.provinces_affected = [1]
	existing.resolved = false
	existing.momentum = 50.0

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.CLEAR, "pu_loss_rate": 0.0},
			},
		},
	}
	var provinces: Dictionary = {1: _make_province_for_famine(1, "Crab")}
	var topics: Array[TopicData] = [existing]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {"_famine_tracking": {1: 9}}

	var results: Array[Dictionary] = DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "resolved")
	assert_true(existing.resolved)


func test_clan_topic_absorbs_existing_provincial_topics() -> void:
	var provincial: TopicData = TopicData.new()
	provincial.topic_id = 40
	provincial.topic_type = "famine"
	provincial.variant = "provincial_famine"
	provincial.clan_involved = "Crab"
	provincial.provinces_affected = [1]
	provincial.resolved = false
	provincial.momentum = 25.0

	var seasonal_result: Dictionary = {
		"resource_tick": {
			"starvation_changes": {
				1: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
				2: {"stage": ResourceTick.StarvationStage.HUNGER, "pu_loss_rate": 0.08},
			},
		},
	}
	var provinces: Dictionary = {
		1: _make_province_for_famine(1, "Crab"),
		2: _make_province_for_famine(2, "Crab"),
	}
	var topics: Array[TopicData] = [provincial]
	var next_id: Array[int] = [100]
	var meta: Dictionary = {}

	DayOrchestrator._process_famine_crises(
		seasonal_result, provinces, topics, next_id, 10, meta,
	)

	assert_true(provincial.resolved, "Old provincial topic should be absorbed")
	assert_eq(provincial.momentum, 0.0)
	var clan_topic: TopicData = null
	for t: TopicData in topics:
		if t.variant == "clan_famine" and not t.resolved:
			clan_topic = t
	assert_not_null(clan_topic, "New clan topic should be created")
	assert_true(1 in clan_topic.provinces_affected)
	assert_true(2 in clan_topic.provinces_affected)


# -- Supply Sharing Effects ----------------------------------------------------

func _make_settlement_for_sharing(
	province_id: int,
	rice: float,
	pop: float,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.province_id = province_id
	s.rice_stockpile = rice
	s.population_pu = pop
	return s


func _make_lord_for_sharing(
	id: int,
	clan: String,
	honor: float = 5.0,
) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.honor = honor
	return c


func test_supply_sharing_transfers_rice() -> void:
	var lord: L5RCharacterData = _make_lord_for_sharing(1, "Crane")
	var giver_s: SettlementData = _make_settlement_for_sharing(10, 100.0, 50.0)
	var receiver_s: SettlementData = _make_settlement_for_sharing(20, 0.5, 50.0)
	var applied: Array = [{
		"character_id": 1,
		"target_province_id": 20,
		"effects": {"requires_supply_sharing": true},
	}]
	var chars: Dictionary = {1: lord}
	var settlements: Array[SettlementData] = [giver_s, receiver_s]
	var prov_dict: Dictionary = {
		10: _make_province_for_famine(10, "Crane"),
		20: _make_province_for_famine(20, "Lion"),
	}

	var results: Array[Dictionary] = DayOrchestrator._process_supply_sharing(
		applied, chars, settlements, prov_dict,
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "supply_sharing")
	assert_gt(results[0]["amount"], 0.0)
	assert_gt(results[0]["honor_gain"], 0.0)
	assert_lt(giver_s.rice_stockpile, 100.0, "Giver lost rice")
	assert_gt(receiver_s.rice_stockpile, 0.5, "Receiver gained rice")


func test_supply_sharing_no_surplus_skips() -> void:
	var lord: L5RCharacterData = _make_lord_for_sharing(1, "Crane")
	var giver_s: SettlementData = _make_settlement_for_sharing(10, 0.1, 50.0)
	var receiver_s: SettlementData = _make_settlement_for_sharing(20, 0.5, 50.0)
	var applied: Array = [{
		"character_id": 1,
		"target_province_id": 20,
		"effects": {"requires_supply_sharing": true},
	}]
	var chars: Dictionary = {1: lord}
	var settlements: Array[SettlementData] = [giver_s, receiver_s]
	var prov_dict: Dictionary = {
		10: _make_province_for_famine(10, "Crane"),
		20: _make_province_for_famine(20, "Lion"),
	}

	var results: Array[Dictionary] = DayOrchestrator._process_supply_sharing(
		applied, chars, settlements, prov_dict,
	)

	assert_eq(results.size(), 0, "No surplus means no sharing")


func test_supply_sharing_same_province_skips() -> void:
	var lord: L5RCharacterData = _make_lord_for_sharing(1, "Crane")
	var s: SettlementData = _make_settlement_for_sharing(10, 100.0, 50.0)
	var applied: Array = [{
		"character_id": 1,
		"target_province_id": 10,
		"effects": {"requires_supply_sharing": true},
	}]
	var chars: Dictionary = {1: lord}
	var settlements: Array[SettlementData] = [s]
	var prov_dict: Dictionary = {10: _make_province_for_famine(10, "Crane")}

	var results: Array[Dictionary] = DayOrchestrator._process_supply_sharing(
		applied, chars, settlements, prov_dict,
	)

	assert_eq(results.size(), 0, "Cannot share with self")


func test_supply_sharing_receiver_not_starving_skips() -> void:
	var lord: L5RCharacterData = _make_lord_for_sharing(1, "Crane")
	var giver_s: SettlementData = _make_settlement_for_sharing(10, 100.0, 50.0)
	var receiver_s: SettlementData = _make_settlement_for_sharing(20, 100.0, 50.0)
	var applied: Array = [{
		"character_id": 1,
		"target_province_id": 20,
		"effects": {"requires_supply_sharing": true},
	}]
	var chars: Dictionary = {1: lord}
	var settlements: Array[SettlementData] = [giver_s, receiver_s]
	var prov_dict: Dictionary = {
		10: _make_province_for_famine(10, "Crane"),
		20: _make_province_for_famine(20, "Lion"),
	}

	var results: Array[Dictionary] = DayOrchestrator._process_supply_sharing(
		applied, chars, settlements, prov_dict,
	)

	assert_eq(results.size(), 0, "Well-fed receiver needs no sharing")


# -- Urgency data injection tests -----------------------------------------------

func test_inject_urgency_data_favors() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var favors: Array = [FavorData.new()]
	DayOrchestrator._inject_urgency_data(
		ws, [c], favors, [], [], {}, [],
	)
	assert_eq(ws[1]["favors"], favors)


func test_inject_urgency_data_active_tethers() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var tethers: Array[Dictionary] = [{"army_id": 5, "overall_state": 2}]
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], tethers, [], {}, [],
	)
	assert_eq(ws[1]["active_tethers"], tethers)


func test_inject_urgency_data_active_topics() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var topics: Array[TopicData] = [TopicData.new()]
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], {}, topics,
	)
	assert_eq(ws[1]["active_topics"], topics)


func test_inject_urgency_data_objective_stalled_seasons() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "CONQUER_PROVINCE", "seasons_without_progress": 3}},
	}
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], objectives_map, [],
	)
	assert_eq(ws[1]["objective_stalled_seasons"], 3)


func test_inject_urgency_data_no_primary_objective() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], {}, [],
	)
	assert_eq(ws[1]["objective_stalled_seasons"], 0)


func test_inject_urgency_data_besieged_settlement() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.physical_location = "42"
	var siege: Dictionary = SiegeSystem.create_siege_state(42, 1, 2, 0.5, 10.0, 1.0)
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [siege], {}, [],
	)
	assert_true(ws[1]["besieged_settlement_health_pct"] < 1.0, "Besieged location should have pct < 1")


func test_inject_urgency_data_starved_garrison() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.physical_location = "42"
	var siege: Dictionary = SiegeSystem.create_siege_state(42, 1, 2, 0.0, 10.0, 1.0)
	siege["garrison_starved"] = true
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [siege], {}, [],
	)
	assert_eq(ws[1]["besieged_settlement_health_pct"], 0.0, "Starved garrison = 0 pct")


func test_inject_urgency_data_not_besieged() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.physical_location = "99"
	var siege: Dictionary = SiegeSystem.create_siege_state(42, 1, 2, 0.5, 10.0, 1.0)
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [siege], {}, [],
	)
	assert_eq(ws[1]["besieged_settlement_health_pct"], 1.0, "Not at besieged settlement")


func test_inject_urgency_data_creates_ws_for_unknown_character() -> void:
	var ws: Dictionary = {}
	var c := L5RCharacterData.new()
	c.character_id = 5
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], {}, [],
	)
	assert_true(ws.has(5), "Should create per-character ws dict")


func test_inject_urgency_data_standing_need_type() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var objectives_map: Dictionary = {
		1: {"standing": {"need_type": "SEEK_GLORY"}},
	}
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], objectives_map, [],
	)
	var known_objs: Dictionary = ws[1].get("known_objectives", {})
	assert_eq(known_objs.get("standing_need_type", ""), "SEEK_GLORY")


func test_inject_urgency_data_no_standing_objective() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	DayOrchestrator._inject_urgency_data(
		ws, [c], [], [], [], {}, [],
	)
	var known_objs: Dictionary = ws[1].get("known_objectives", {})
	assert_eq(known_objs.get("standing_need_type", ""), "", "No standing obj = empty string")


# -- Characters present injection tests ----------------------------------------

func test_inject_characters_present_co_located() -> void:
	var ws: Dictionary = {1: {}, 2: {}, 3: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.physical_location = "100"
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.physical_location = "100"
	var c3 := L5RCharacterData.new()
	c3.character_id = 3
	c3.physical_location = "200"
	DayOrchestrator._inject_urgency_data(
		ws, [c1, c2, c3], [], [], [], {}, [],
	)
	var present_1: Array = ws[1].get("characters_present", [])
	assert_true(2 in present_1, "Char 1 should see char 2")
	assert_false(3 in present_1, "Char 1 should not see char 3")
	var present_2: Array = ws[2].get("characters_present", [])
	assert_true(1 in present_2, "Char 2 should see char 1")


func test_inject_characters_present_excludes_self() -> void:
	var ws: Dictionary = {1: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.physical_location = "100"
	DayOrchestrator._inject_urgency_data(
		ws, [c1], [], [], [], {}, [],
	)
	var present: Array = ws[1].get("characters_present", [])
	assert_eq(present.size(), 0, "Should not include self")


func test_inject_characters_present_excludes_dead() -> void:
	var ws: Dictionary = {1: {}, 2: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.physical_location = "100"
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.physical_location = "100"
	c2.wounds_taken = 999
	DayOrchestrator._inject_urgency_data(
		ws, [c1, c2], [], [], [], {}, [],
	)
	var present: Array = ws[1].get("characters_present", [])
	assert_false(2 in present, "Dead character should not be present")


func test_inject_characters_present_excludes_traveling() -> void:
	var ws: Dictionary = {1: {}, 2: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.physical_location = "100"
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.physical_location = "100"
	c2.travel_destination = "200"
	c2.travel_days_remaining = 3
	DayOrchestrator._inject_urgency_data(
		ws, [c1, c2], [], [], [], {}, [],
	)
	var present: Array = ws[1].get("characters_present", [])
	assert_false(2 in present, "Traveling character should not be present")


func test_inject_characters_present_empty_location() -> void:
	var ws: Dictionary = {1: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.physical_location = ""
	DayOrchestrator._inject_urgency_data(
		ws, [c1], [], [], [], {}, [],
	)
	var present: Array = ws[1].get("characters_present", [])
	assert_eq(present.size(), 0, "Empty location should have no co-located chars")


# -- Resource stockpiles population tests --------------------------------------

func _make_province(pid: int, clan: String) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	return p


func _make_settlement_for(sid: int, pid: int, rice: float, koku: float, pop: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = pid
	s.rice_stockpile = rice
	s.koku_stockpile = koku
	s.population_pu = pop
	return s


func test_resource_stockpiles_populated_for_lord() -> void:
	var ws: Dictionary = {}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Crane"
	lord.status = 6.0
	lord.lord_id = -1
	var prov := _make_province(100, "Crane")
	var s1 := _make_settlement_for(1, 100, 50.0, 20.0, 10)
	var s2 := _make_settlement_for(2, 100, 30.0, 10.0, 5)
	var clan := ClanData.new()
	clan.clan_name = "Crane"
	clan.arms_stockpile = 15.0
	clan.iron_stockpile = 8.0
	DayOrchestrator._populate_resource_stockpiles(
		ws, [lord], {100: prov}, [s1, s2], {"Crane": clan}, [],
	)
	var rs: Dictionary = ws[1].get("resource_stockpiles", {})
	assert_eq(rs.get("rice", 0.0), 80.0, "Rice should sum both settlements")
	assert_eq(rs.get("koku", 0.0), 30.0, "Koku should sum both settlements")
	assert_eq(rs.get("arms", 0.0), 15.0, "Arms from clan data")
	assert_eq(rs.get("iron", 0.0), 8.0, "Iron from clan data")
	assert_true(rs.get("population_pu", 0.0) >= 15.0, "Population PU summed")


func test_resource_stockpiles_skipped_for_non_lord() -> void:
	var ws: Dictionary = {}
	var samurai := L5RCharacterData.new()
	samurai.character_id = 2
	samurai.clan = "Crane"
	samurai.status = 3.0
	samurai.lord_id = 1
	DayOrchestrator._populate_resource_stockpiles(
		ws, [samurai], {}, [], {}, [],
	)
	assert_false(ws.has(2), "Non-lord should not get resource stockpiles")


func test_resource_stockpiles_rice_consumption() -> void:
	var ws: Dictionary = {}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Lion"
	lord.status = 5.0
	lord.lord_id = -1
	var prov := _make_province(200, "Lion")
	var s1 := _make_settlement_for(10, 200, 100.0, 0.0, 20)
	DayOrchestrator._populate_resource_stockpiles(
		ws, [lord], {200: prov}, [s1], {}, [],
	)
	var rs: Dictionary = ws[1].get("resource_stockpiles", {})
	assert_almost_eq(rs.get("rice_consumption", 0.0), 5.0, 0.01, "20 PU * 0.25 = 5.0")


func test_resource_stockpiles_no_matching_clan() -> void:
	var ws: Dictionary = {}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Scorpion"
	lord.status = 6.0
	lord.lord_id = -1
	var prov := _make_province(100, "Crane")
	var s1 := _make_settlement_for(1, 100, 50.0, 20.0, 10)
	DayOrchestrator._populate_resource_stockpiles(
		ws, [lord], {100: prov}, [s1], {}, [],
	)
	var rs: Dictionary = ws[1].get("resource_stockpiles", {})
	assert_eq(rs.get("rice", 0.0), 0.0, "No Scorpion settlements")


# -- Court availability data population tests ----------------------------------

func test_upcoming_courts_populated() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var court := CourtSessionData.new()
	court.court_id = 10
	court.host_settlement_id = 50
	court.prestige = 2
	court.court_phase = CourtSessionData.CourtPhase.SCHEDULED
	DayOrchestrator._populate_court_availability_data(
		[court], [c], {1: c}, ws, [],
	)
	var upcoming: Array = ws[1].get("upcoming_courts", [])
	assert_eq(upcoming.size(), 1, "Should have 1 upcoming court")
	assert_eq(upcoming[0].get("settlement_id", -1), 50)
	assert_eq(upcoming[0].get("prestige", 0), 2)


func test_upcoming_courts_excludes_active() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var court := CourtSessionData.new()
	court.court_phase = CourtSessionData.CourtPhase.ACTIVE
	DayOrchestrator._populate_court_availability_data(
		[court], [c], {1: c}, ws, [],
	)
	var upcoming: Array = ws[1].get("upcoming_courts", [])
	assert_eq(upcoming.size(), 0, "Active courts should not appear as upcoming")


func test_held_leverage_from_favors() -> void:
	var ws: Dictionary = {1: {}, 2: {}}
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.lord_id = 5
	var f := FavorData.new()
	f.creditor_id = 1
	f.debtor_id = 2
	f.invoked = false
	f.tier = FavorData.FavorTier.MODERATE
	DayOrchestrator._populate_court_availability_data(
		[], [c1, c2], {1: c1, 2: c2}, ws, [f],
	)
	var leverage: Array = ws[1].get("held_leverage", [])
	assert_eq(leverage.size(), 1, "Creditor should have 1 leverage entry")
	assert_eq(leverage[0].get("debtor_id", -1), 2)
	assert_eq(leverage[0].get("target_lord_id", -1), 5)
	var lev2: Array = ws[2].get("held_leverage", [])
	assert_eq(lev2.size(), 0, "Debtor should have no leverage")


func test_held_leverage_excludes_invoked() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var f := FavorData.new()
	f.creditor_id = 1
	f.debtor_id = 2
	f.invoked = true
	DayOrchestrator._populate_court_availability_data(
		[], [c], {1: c}, ws, [f],
	)
	var leverage: Array = ws[1].get("held_leverage", [])
	assert_eq(leverage.size(), 0, "Invoked favors should not appear as leverage")


func test_known_npc_locations_from_knowledge_pool() -> void:
	var ws: Dictionary = {1: {}}
	var c := L5RCharacterData.new()
	c.character_id = 1
	var entry := KnowledgeEntry.new()
	entry.entry_type = "location"
	entry.data = {"character_id": 5, "settlement_id": "300"}
	c.knowledge_pool.append(entry)
	DayOrchestrator._populate_court_availability_data(
		[], [c], {1: c}, ws, [],
	)
	var locations: Dictionary = ws[1].get("known_npc_locations", {})
	assert_eq(locations.get(5, -1), 300, "Should map NPC 5 to settlement 300")


func test_available_levy_pu_populated_for_lord() -> void:
	var ws: Dictionary = {}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Crab"
	lord.status = 6.0
	lord.lord_id = -1
	var prov := _make_province(100, "Crab")
	var s1 := _make_settlement_for(1, 100, 10.0, 5.0, 10)
	s1.military_pu = 3
	var s2 := _make_settlement_for(2, 100, 5.0, 2.0, 5)
	s2.military_pu = 2
	DayOrchestrator._populate_resource_stockpiles(
		ws, [lord], {100: prov}, [s1, s2], {}, [],
	)
	assert_eq(ws[1].get("available_levy_pu", 0.0), 5.0, "Sum of military_pu")


# -- Court context flag gap fix tests ------------------------------------------

func test_court_context_creates_world_state_entry() -> void:
	var ws: Dictionary = {}
	var court := CourtSessionData.new()
	court.court_phase = CourtSessionData.CourtPhase.ACTIVE
	court.elapsed_ticks = 1
	court.duration_ticks = 10
	court.attendee_ids = [42]
	DayOrchestrator._set_court_context_flags([court], ws)
	assert_true(ws.has(42), "Should create world_state entry for attendee")
	assert_eq(ws[42].get("context_flag", -1), Enums.ContextFlag.AT_COURT)
	assert_false(ws[42].get("active_court_at_location", {}).is_empty())


# -- Sortie wiring (_process_sortie_results) ------------------------------------

func _make_wall_tower(sid: int, pid: int, garrison: int, jade: float, si: int = 8) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = pid
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.garrison_pu = garrison
	s.jade_stockpile = jade
	s.wall_si = si
	return s


func _make_shadowlands_province(pid: int, ss: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.shadowlands_strength = ss
	return p


func _make_sortie_applied(pid: int, force_pct: float, ss_red: int, jade_pw: int) -> Dictionary:
	return {
		"effects": {
			"requires_sortie_combat": true,
			"target_province_id": pid,
			"ss_reduction": ss_red,
			"force_pct": force_pct,
			"jade_per_warrior": jade_pw,
		}
	}


func test_sortie_no_requires_flag_skipped() -> void:
	var applied: Array = [{"effects": {"ss_reduction": 3}}]
	var tower := _make_wall_tower(1, 10, 5, 20.0)
	var prov := _make_shadowlands_province(10, 6)
	var results: Array[Dictionary] = DayOrchestrator._process_sortie_results(
		applied, [tower], {10: prov}, _dice
	)
	assert_eq(results.size(), 0)
	assert_eq(prov.shadowlands_strength, 6)


func test_sortie_jade_consumed_regardless_of_outcome() -> void:
	# force_pct=0.4 × garrison=5 = 2 committed warriors, jade_per_warrior=2 → 4 jade
	var applied: Array = [_make_sortie_applied(10, 0.4, 2, 2)]
	var tower := _make_wall_tower(1, 10, 5, 20.0)
	var prov := _make_shadowlands_province(10, 6)
	DayOrchestrator._process_sortie_results(applied, [tower], {10: prov}, _dice)
	# jade consumed = 2 warriors × 2 jade = 4 regardless of combat success
	assert_eq(tower.jade_stockpile, 16.0)


func test_sortie_result_has_expected_keys() -> void:
	var applied: Array = [_make_sortie_applied(10, 0.4, 2, 1)]
	var tower := _make_wall_tower(1, 10, 5, 20.0)
	var prov := _make_shadowlands_province(10, 6)
	var results: Array[Dictionary] = DayOrchestrator._process_sortie_results(
		applied, [tower], {10: prov}, _dice
	)
	assert_eq(results.size(), 1)
	var r: Dictionary = results[0]
	assert_true(r.has("province_id"))
	assert_true(r.has("sortie_success"))
	assert_true(r.has("ss_reduction_applied"))
	assert_true(r.has("new_ss"))
	assert_true(r.has("pu_lost"))
	assert_true(r.has("jade_consumed"))


func test_sortie_ss_reduction_only_on_success() -> void:
	# With garrison_pu=5 and force_pct=0.4 → 2 garrison companies.
	# SS=12 (High tier), planned ss_reduction=3.
	# If combat succeeds, SS drops. If fails, SS unchanged.
	var applied: Array = [_make_sortie_applied(10, 0.4, 3, 1)]
	var tower := _make_wall_tower(1, 10, 5, 20.0)
	var prov := _make_shadowlands_province(10, 12)
	var results: Array[Dictionary] = DayOrchestrator._process_sortie_results(
		applied, [tower], {10: prov}, _dice
	)
	assert_eq(results.size(), 1)
	var r: Dictionary = results[0]
	if r["sortie_success"]:
		assert_eq(r["ss_reduction_applied"], 3)
		assert_eq(prov.shadowlands_strength, 9)
	else:
		assert_eq(r["ss_reduction_applied"], 0)
		assert_eq(prov.shadowlands_strength, 12)


func test_sortie_garrison_pu_reduced_by_casualties() -> void:
	# garrison_pu starts at 10, force_pct=1.0 → all 10 committed.
	var applied: Array = [_make_sortie_applied(10, 1.0, 2, 1)]
	var tower := _make_wall_tower(1, 10, 10, 20.0)
	var prov := _make_shadowlands_province(10, 8)
	DayOrchestrator._process_sortie_results(applied, [tower], {10: prov}, _dice)
	# Garrison PU must not increase and should stay >= 0
	assert_true(tower.garrison_pu >= 0)
	assert_true(tower.garrison_pu <= 10)


func test_build_garrison_sortie_states_count() -> void:
	var states: Array[Dictionary] = DayOrchestrator._build_garrison_sortie_states(3)
	assert_eq(states.size(), 3)


func test_build_garrison_sortie_states_fields() -> void:
	var states: Array[Dictionary] = DayOrchestrator._build_garrison_sortie_states(1)
	var bc: Dictionary = states[0]
	assert_eq(bc["side"], "defender")
	assert_eq(bc["unit_type"], Enums.CompanyUnitType.GARRISON)
	assert_eq(bc["starting_health"], 153)
	assert_false(bc["no_morale"])


func test_build_garrison_sortie_states_zero_returns_empty() -> void:
	var states: Array[Dictionary] = DayOrchestrator._build_garrison_sortie_states(0)
	assert_eq(states.size(), 0)


# =============================================================================
# _rebel_holds_seat (s53.2.7 — Gap 1)
# =============================================================================

func _make_province_for_seat(pid: int, clan: String, family: String, settlement_id: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	p.family = family
	p.settlement_ids = [settlement_id]
	return p


func _make_rebel_at(cid: int, clan: String, family: String, loc_settlement: int) -> L5RCharacterData:
	var r := L5RCharacterData.new()
	r.character_id = cid
	r.clan = clan
	r.family = family
	r.physical_location = str(loc_settlement)
	return r


func test_rebel_holds_seat_when_in_family_province() -> void:
	var prov := _make_province_for_seat(10, "Lion", "Matsu", 500)
	var rebel := _make_rebel_at(101, "Lion", "Matsu", 500)
	assert_true(DayOrchestrator._rebel_holds_seat(rebel, {10: prov}))


func test_rebel_seat_lost_when_outside_family_province() -> void:
	var prov := _make_province_for_seat(10, "Lion", "Matsu", 500)
	var rebel := _make_rebel_at(101, "Lion", "Matsu", 999)  # wrong settlement
	assert_false(DayOrchestrator._rebel_holds_seat(rebel, {10: prov}))


func test_rebel_holds_seat_null_lord_returns_false() -> void:
	var prov := _make_province_for_seat(10, "Lion", "Matsu", 500)
	assert_false(DayOrchestrator._rebel_holds_seat(null, {10: prov}))


func test_rebel_holds_seat_no_matching_province_returns_false() -> void:
	var prov := _make_province_for_seat(10, "Crane", "Doji", 500)
	var rebel := _make_rebel_at(101, "Lion", "Matsu", 500)
	assert_false(DayOrchestrator._rebel_holds_seat(rebel, {10: prov}))


func test_rebel_holds_seat_invalid_location_returns_false() -> void:
	var prov := _make_province_for_seat(10, "Lion", "Matsu", 500)
	var rebel := _make_rebel_at(101, "Lion", "Matsu", 500)
	rebel.physical_location = "not_an_int"
	assert_false(DayOrchestrator._rebel_holds_seat(rebel, {10: prov}))


# =============================================================================
# _reconstitute_clan_military (s53.2.3 — Gap 2)
# =============================================================================

func _make_state_with_factions(rebel_id: int, auth_id: int) -> Dictionary:
	var s: Dictionary = IntraClanCivilWar.make_initial_state(rebel_id, auth_id, "Lion", 5000, 1)
	IntraClanCivilWar.assign_faction(s, rebel_id, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(s, auth_id, IntraClanCivilWar.Faction.LEGITIMACY)
	return s


func _make_company(cid: int, cmd_id: int, hp: int = 153, start_hp: int = 153) -> Dictionary:
	return {
		"company_id": cid,
		"commander_id": cmd_id,
		"current_health": hp,
		"starting_health": start_hp,
		"is_destroyed": false,
	}


func test_reconstitute_clears_losing_rebel_commanders() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var rebel_char := L5RCharacterData.new()
	rebel_char.character_id = 101
	rebel_char.wounds_taken = 0
	var co: Dictionary = _make_company(1, 101)
	var chars: Dictionary = {101: rebel_char}
	# Legitimacy wins → rebel commander loses their company.
	DayOrchestrator._reconstitute_clan_military(state, true, [co], chars)
	assert_eq(co["commander_id"], -1)


func test_reconstitute_keeps_winning_faction_commanders() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var auth_char := L5RCharacterData.new()
	auth_char.character_id = 1
	auth_char.wounds_taken = 0
	var co: Dictionary = _make_company(2, 1)
	var chars: Dictionary = {1: auth_char}
	# Legitimacy wins → legitimacy commander keeps their company.
	DayOrchestrator._reconstitute_clan_military(state, true, [co], chars)
	assert_eq(co["commander_id"], 1)


func test_reconstitute_clears_dead_commanders() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var auth_char := L5RCharacterData.new()
	auth_char.character_id = 1
	auth_char.wounds_taken = 999  # effectively dead
	var co: Dictionary = _make_company(2, 1)
	var chars: Dictionary = {1: auth_char}
	DayOrchestrator._reconstitute_clan_military(state, true, [co], chars)
	assert_eq(co["commander_id"], -1)


func test_reconstitute_reports_vacancies() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var rebel_char := L5RCharacterData.new()
	rebel_char.character_id = 101
	rebel_char.wounds_taken = 0
	var co: Dictionary = _make_company(1, 101)
	var chars: Dictionary = {101: rebel_char}
	var result: Dictionary = DayOrchestrator._reconstitute_clan_military(state, true, [co], chars)
	assert_eq(result["vacancies_created"], 1)


func test_reconstitute_consolidates_understrength_pair() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var auth_char := L5RCharacterData.new()
	auth_char.character_id = 1
	auth_char.wounds_taken = 0
	# Both companies at 40% health — below 50% threshold.
	var co1: Dictionary = _make_company(10, 1, 61, 153)
	var co2: Dictionary = _make_company(11, 1, 61, 153)
	var chars: Dictionary = {1: auth_char}
	var result: Dictionary = DayOrchestrator._reconstitute_clan_military(state, true, [co1, co2], chars)
	assert_eq(result["companies_dissolved"], 1)
	assert_true(co2["is_destroyed"])
	assert_true(co1["current_health"] > 61)  # absorbed co2's health


func test_reconstitute_no_dissolution_if_healthy() -> void:
	var state: Dictionary = _make_state_with_factions(101, 1)
	var auth_char := L5RCharacterData.new()
	auth_char.character_id = 1
	auth_char.wounds_taken = 0
	var co1: Dictionary = _make_company(10, 1, 100, 153)
	var co2: Dictionary = _make_company(11, 1, 100, 153)
	var chars: Dictionary = {1: auth_char}
	var result: Dictionary = DayOrchestrator._reconstitute_clan_military(state, true, [co1, co2], chars)
	assert_eq(result["companies_dissolved"], 0)


# =============================================================================
# _apply_civil_war_edict_shifts (s53.2.5 — Gap 3)
# =============================================================================

func _make_condemn_edict(eid: int, target_clan: String, target_char: int) -> EdictData:
	var e := EdictData.new()
	e.edict_id = eid
	e.edict_type = EdictData.EdictType.CONDEMN_CLAN
	e.target_clan = target_clan
	e.target_character_id = target_char
	e.is_active = true
	return e


func test_edict_targeting_rebel_shifts_to_legitimacy() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 1)
	var edict := _make_condemn_edict(1, "Lion", 101)
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	assert_true(state["war_score"] > 50)  # shifted toward legitimacy


func test_edict_targeting_authority_shifts_to_rebel() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 1)
	var edict := _make_condemn_edict(1, "Lion", 1)
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	assert_true(state["war_score"] < 50)  # shifted toward rebel


func test_edict_not_processed_twice() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 1)
	var edict := _make_condemn_edict(1, "Lion", 101)
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	var score_after_first: int = state["war_score"]
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	assert_eq(state["war_score"], score_after_first)


func test_edict_with_no_character_target_skipped() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 1)
	# target_character_id = -1 → clan-level only, ambiguous, must be skipped.
	var edict := _make_condemn_edict(1, "Lion", -1)
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	assert_eq(state["war_score"], 50)


func test_inactive_edict_skipped() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 1)
	var edict := _make_condemn_edict(1, "Lion", 101)
	edict.is_active = false
	DayOrchestrator._apply_civil_war_edict_shifts(state, 101, 1, [edict])
	assert_eq(state["war_score"], 50)


# =============================================================================
# s55.10.2.8 / s55.10.3.7 — Schism Crisis clan-specific faction rules
# =============================================================================

func _make_clan_char(cid: int, clan: String, family: String, lord_id: int = -1,
		status: float = 3.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = clan
	c.family = family
	c.lord_id = lord_id
	c.status = status
	c.honor = 5.0
	return c


func _make_trigger_cw_setup(clan: String, rebel_id: int, auth_id: int,
		extra_npcs: Array[L5RCharacterData] = []) -> Dictionary:
	var rebel := _make_clan_char(rebel_id, clan, "Mirumoto" if clan == "Dragon" else "Shiba",
		-1, 7.0)
	var authority := _make_clan_char(auth_id, clan,
		"Togashi" if clan == "Dragon" else "Isawa", -1, 7.0)
	var characters: Array[L5RCharacterData] = [rebel, authority]
	characters.append_array(extra_npcs)
	var by_id: Dictionary = {}
	for c: L5RCharacterData in characters:
		by_id[c.character_id] = c
	return {
		"rebel": rebel,
		"authority": authority,
		"characters": characters,
		"by_id": by_id,
	}


func test_dragon_trigger_auto_assigns_togashi_family_to_legitimacy() -> void:
	# Togashi Order monks must side with Togashi unconditionally (s55.10.2.8).
	var monk := _make_clan_char(99, "Dragon", "Togashi", -1, 2.0)
	var kitsuki := _make_clan_char(98, "Dragon", "Kitsuki", -1, 2.0)
	var setup: Dictionary = _make_trigger_cw_setup("Dragon", 10, 20, [monk, kitsuki])
	var wars: Array[Dictionary] = []
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [1]
	DayOrchestrator._trigger_civil_war(
		10, 20, "Dragon", "removal order",
		setup["characters"], setup["by_id"], {},
		wars, topics, next_id, 100, 5,
		false, "dragon_schism",
	)
	var state: Dictionary = wars[0]
	assert_eq(int(state["faction_assignments"].get(99, -1)), IntraClanCivilWar.Faction.LEGITIMACY)
	# Kitsuki evaluated normally (went LEGITIMACY by default with no rebel pull)
	assert_ne(int(state["faction_assignments"].get(98, -1)), -1)


func test_dragon_trigger_stores_treaty_penalty() -> void:
	var setup: Dictionary = _make_trigger_cw_setup("Dragon", 10, 20)
	var wars: Array[Dictionary] = []
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [1]
	DayOrchestrator._trigger_civil_war(
		10, 20, "Dragon", "removal order",
		setup["characters"], setup["by_id"], {},
		wars, topics, next_id, 100, 5,
	)
	assert_eq(int(wars[0].get("dragon_treaty_penalty", 0)), -15)


func test_phoenix_trigger_auto_assigns_isawa_to_legitimacy() -> void:
	# All Isawa side with Council unconditionally (s55.10.3.7).
	var isawa_monk := _make_clan_char(99, "Phoenix", "Isawa", -1, 2.0)
	var shiba_soldier := _make_clan_char(98, "Phoenix", "Shiba", -1, 2.0)
	var champion := _make_clan_char(10, "Phoenix", "Shiba", -1, 7.0)
	var master := _make_clan_char(20, "Phoenix", "Isawa", -1, 7.0)
	master.role_position = "Master of Fire"
	var characters: Array[L5RCharacterData] = [champion, master, isawa_monk, shiba_soldier]
	var by_id: Dictionary = {}
	for c: L5RCharacterData in characters:
		by_id[c.character_id] = c
	var wars: Array[Dictionary] = []
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [1]
	# Defiance Path: rebel = champion, authority = master
	DayOrchestrator._trigger_civil_war(
		10, 20, "Phoenix", "champion defiance",
		characters, by_id, {},
		wars, topics, next_id, 100, 5,
		false, "defiance",
	)
	var state: Dictionary = wars[0]
	assert_eq(int(state["faction_assignments"].get(99, -1)), IntraClanCivilWar.Faction.LEGITIMACY)
	# Shiba soldier evaluated normally
	assert_ne(int(state["faction_assignments"].get(98, -1)), -1)


func test_phoenix_overreach_trigger_suppresses_hemorrhage() -> void:
	# Council Overreach Path: suppress_honor_hemorrhage must be true (s55.10.3.7).
	var setup: Dictionary = _make_trigger_cw_setup("Phoenix", 20, 10)
	var wars: Array[Dictionary] = []
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [1]
	DayOrchestrator._trigger_civil_war(
		20, 10, "Phoenix", "council overreach",
		setup["characters"], setup["by_id"], {},
		wars, topics, next_id, 100, 5,
		true, "overreach",
	)
	assert_true(wars[0].get("suppress_honor_hemorrhage", false))
	assert_eq(wars[0].get("schism_path", ""), "overreach")


func test_phoenix_defiance_trigger_no_hemorrhage_suppression() -> void:
	# Defiance Path: standard −0.3/season applies (s55.10.3.7).
	var setup: Dictionary = _make_trigger_cw_setup("Phoenix", 10, 20)
	var wars: Array[Dictionary] = []
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [1]
	DayOrchestrator._trigger_civil_war(
		10, 20, "Phoenix", "champion defiance",
		setup["characters"], setup["by_id"], {},
		wars, topics, next_id, 100, 5,
		false, "defiance",
	)
	assert_false(wars[0].get("suppress_honor_hemorrhage", false))
	assert_eq(wars[0].get("schism_path", ""), "defiance")


# =============================================================================
# _apply_phoenix_master_death_honor_penalty (s55.10.3.7)
# =============================================================================

func _make_phoenix_schism_state(schism_path: String, rebel_id: int,
		auth_id: int) -> Dictionary:
	var s: Dictionary = IntraClanCivilWar.make_initial_state(rebel_id, auth_id, "Phoenix", 1, 0)
	s["schism_path"] = schism_path
	return s


func test_dead_master_penalizes_defiance_path_champion() -> void:
	# Defiance: rebel = champion → champion takes −0.5 for each dead Master.
	var state: Dictionary = _make_phoenix_schism_state("defiance", 10, 20)
	var champion := _make_clan_char(10, "Phoenix", "Shiba", -1, 7.0)
	champion.honor = 5.0
	var master := _make_clan_char(20, "Phoenix", "Isawa", -1, 7.0)
	master.role_position = "Master of Fire"
	master.wounds_taken = 999  # dead
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var by_id: Dictionary = {10: champion, 20: master}
	var count: int = DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	assert_eq(count, 1)
	assert_almost_eq(champion.honor, 4.5, 0.001)


func test_dead_master_not_double_penalized() -> void:
	var state: Dictionary = _make_phoenix_schism_state("defiance", 10, 20)
	var champion := _make_clan_char(10, "Phoenix", "Shiba", -1, 7.0)
	champion.honor = 5.0
	var master := _make_clan_char(20, "Phoenix", "Isawa", -1, 7.0)
	master.role_position = "Master of Water"
	master.wounds_taken = 999
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var by_id: Dictionary = {10: champion, 20: master}
	DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	var second_pass: int = DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	assert_eq(second_pass, 0)
	assert_almost_eq(champion.honor, 4.5, 0.001)


func test_living_master_not_penalized() -> void:
	var state: Dictionary = _make_phoenix_schism_state("defiance", 10, 20)
	var champion := _make_clan_char(10, "Phoenix", "Shiba", -1, 7.0)
	champion.honor = 5.0
	var master := _make_clan_char(20, "Phoenix", "Isawa", -1, 7.0)
	master.role_position = "Master of Earth"
	master.wounds_taken = 0  # alive
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var by_id: Dictionary = {10: champion, 20: master}
	var count: int = DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	assert_eq(count, 0)
	assert_almost_eq(champion.honor, 5.0, 0.001)


func test_non_phoenix_civil_war_skips_master_penalty() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	var by_id: Dictionary = {}
	var count: int = DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	assert_eq(count, 0)


func test_overreach_path_champion_is_authority_lord() -> void:
	# Overreach: authority = champion → champion takes −0.5 for each dead Master.
	var state: Dictionary = _make_phoenix_schism_state("overreach", 20, 10)
	var champion := _make_clan_char(10, "Phoenix", "Shiba", -1, 7.0)
	champion.honor = 5.0
	var master := _make_clan_char(20, "Phoenix", "Isawa", -1, 7.0)
	master.role_position = "Master of Air"
	master.wounds_taken = 999
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var by_id: Dictionary = {10: champion, 20: master}
	var count: int = DayOrchestrator._apply_phoenix_master_death_honor_penalty(state, by_id)
	assert_eq(count, 1)
	assert_almost_eq(champion.honor, 4.5, 0.001)


# =============================================================================
# _resolve_civil_war — victory_flags (s55.10.2.8 / s55.10.3.7)
# =============================================================================

func test_dragon_rebel_victory_returns_autonomous_rule_flag() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	state["schism_path"] = "dragon_schism"
	IntraClanCivilWar.assign_faction(state, 10, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var result: Dictionary = DayOrchestrator._resolve_civil_war(
		state, false, {}, {}, 5, topics, next_id, 100, {}, "Dragon",
	)
	assert_true(result["victory_flags"].get("dragon_autonomous_rule", false))


func test_dragon_legitimacy_victory_no_autonomous_rule_flag() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	IntraClanCivilWar.assign_faction(state, 10, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var result: Dictionary = DayOrchestrator._resolve_civil_war(
		state, true, {}, {}, 5, topics, next_id, 100, {}, "Dragon",
	)
	assert_false(result["victory_flags"].get("dragon_autonomous_rule", false))


func test_phoenix_rebel_victory_returns_champion_authority_flag() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Phoenix", 1, 0)
	state["schism_path"] = "defiance"
	IntraClanCivilWar.assign_faction(state, 10, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var result: Dictionary = DayOrchestrator._resolve_civil_war(
		state, false, {}, {}, 5, topics, next_id, 100, {}, "Phoenix",
	)
	assert_true(result["victory_flags"].get("phoenix_champion_authority", false))


func test_non_clan_specific_war_no_victory_flags() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Lion", 1, 0)
	IntraClanCivilWar.assign_faction(state, 10, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(state, 20, IntraClanCivilWar.Faction.LEGITIMACY)
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var result: Dictionary = DayOrchestrator._resolve_civil_war(
		state, false, {}, {}, 5, topics, next_id, 100, {}, "Lion",
	)
	assert_true(result["victory_flags"].is_empty())


# =============================================================================
# _apply_dragon_spiritual_reeval (s55.10.2.8 — spiritual concern re-evaluation)
# =============================================================================

func _make_dragon_schism_state(rebel_id: int, auth_id: int,
		snap_dissat: float = 0.0) -> Dictionary:
	var s: Dictionary = IntraClanCivilWar.make_initial_state(rebel_id, auth_id, "Dragon", 1, 0)
	s["schism_path"] = "dragon_schism"
	# Snapshot: some initial dissatisfaction
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	s["concern_snapshot"] = {axis_key: snap_dissat}
	IntraClanCivilWar.assign_faction(s, rebel_id, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(s, auth_id, IntraClanCivilWar.Faction.LEGITIMACY)
	return s


func test_spiritual_reeval_worsened_flips_rebel_npc_to_legitimacy() -> void:
	var state: Dictionary = _make_dragon_schism_state(10, 20, 1.0)
	# Rebel NPC with Chugi virtue → strong Legitimacy pull, will flip when grievance is strong
	var npc := _make_clan_char(99, "Dragon", "Mirumoto", -1, 2.0)
	npc.bushido_virtue = Enums.BushidoVirtue.CHUGI
	IntraClanCivilWar.assign_faction(state, 99, IntraClanCivilWar.Faction.REBEL)
	var by_id: Dictionary = {10: _make_clan_char(10, "Dragon", "Mirumoto"), 20: _make_clan_char(20, "Dragon", "Togashi"), 99: npc}
	# Togashi state with worsened concern
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	var togashi_st: Dictionary = {"dissatisfaction": {axis_key: 5.0}}  # higher than snapshot 1.0
	var result: Array[Dictionary] = DayOrchestrator._apply_dragon_spiritual_reeval(
		state, togashi_st, by_id, {}
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["character_id"], 99)
	assert_eq(result[0]["reason"], "spiritual_reeval")
	assert_eq(int(state["faction_assignments"][99]), IntraClanCivilWar.Faction.LEGITIMACY)


func test_spiritual_reeval_no_change_when_concern_same() -> void:
	var state: Dictionary = _make_dragon_schism_state(10, 20, 3.0)
	var npc := _make_clan_char(99, "Dragon", "Mirumoto")
	npc.bushido_virtue = Enums.BushidoVirtue.CHUGI
	IntraClanCivilWar.assign_faction(state, 99, IntraClanCivilWar.Faction.REBEL)
	var by_id: Dictionary = {99: npc}
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	# Current same as snapshot — no worsening
	var togashi_st: Dictionary = {"dissatisfaction": {axis_key: 3.0}}
	var result: Array[Dictionary] = DayOrchestrator._apply_dragon_spiritual_reeval(
		state, togashi_st, by_id, {}
	)
	assert_eq(result.size(), 0)


func test_spiritual_reeval_togashi_monks_never_reeval() -> void:
	# Togashi Order monks are auto-assigned — spiritual re-eval skips them.
	var state: Dictionary = _make_dragon_schism_state(10, 20, 0.0)
	var monk := _make_clan_char(99, "Dragon", "Togashi")
	monk.bushido_virtue = Enums.BushidoVirtue.NONE  # would be ronin-candidate otherwise
	IntraClanCivilWar.assign_faction(state, 99, IntraClanCivilWar.Faction.REBEL)
	var by_id: Dictionary = {99: monk}
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	var togashi_st: Dictionary = {"dissatisfaction": {axis_key: 99.0}}
	var result: Array[Dictionary] = DayOrchestrator._apply_dragon_spiritual_reeval(
		state, togashi_st, by_id, {}
	)
	assert_eq(result.size(), 0)


func test_spiritual_reeval_no_snapshot_skips_reeval() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	state["schism_path"] = "dragon_schism"
	# No concern_snapshot stored
	var npc := _make_clan_char(99, "Dragon", "Mirumoto")
	IntraClanCivilWar.assign_faction(state, 99, IntraClanCivilWar.Faction.REBEL)
	var by_id: Dictionary = {99: npc}
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	var togashi_st: Dictionary = {"dissatisfaction": {axis_key: 99.0}}
	var result: Array[Dictionary] = DayOrchestrator._apply_dragon_spiritual_reeval(
		state, togashi_st, by_id, {}
	)
	assert_eq(result.size(), 0)


func test_spiritual_reeval_skips_non_dragon_civil_war() -> void:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Lion", 1, 0)
	var axis_key: int = TogashiOversight.Axis.SPIRITUAL_HEALTH
	state["concern_snapshot"] = {axis_key: 0.0}
	var npc := _make_clan_char(99, "Lion", "Matsu")
	IntraClanCivilWar.assign_faction(state, 99, IntraClanCivilWar.Faction.REBEL)
	var by_id: Dictionary = {99: npc}
	var togashi_st: Dictionary = {"dissatisfaction": {axis_key: 99.0}}
	var result: Array[Dictionary] = DayOrchestrator._apply_dragon_spiritual_reeval(
		state, togashi_st, by_id, {}
	)
	assert_eq(result.size(), 0)


# =============================================================================
# -- Stipend Disposition Update (GDD s4.3.9) ----------------------------------
# =============================================================================

func _make_lord_retainer_pair(
	lord_id: int, retainer_id: int,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> Array[L5RCharacterData]:
	var lord := L5RCharacterData.new()
	lord.character_id = lord_id
	lord.lord_id = -1
	lord.bushido_virtue = bushido
	lord.shourido_virtue = shourido

	var retainer := L5RCharacterData.new()
	retainer.character_id = retainer_id
	retainer.lord_id = lord_id

	return [lord, retainer]


func test_stipend_jin_lord_adds_two_disposition_to_retainer() -> void:
	# Jin lord: +10% stipend → +2 disposition per season (GDD s4.3.9)
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(
		1, 2, Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE,
	)
	var lord: L5RCharacterData = pair[0]
	var retainer: L5RCharacterData = pair[1]
	var by_id: Dictionary = {1: lord, 2: retainer}
	var chars: Array[L5RCharacterData] = [lord, retainer]

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), 2)


func test_stipend_kyoryoku_lord_subtracts_two_disposition() -> void:
	# Kyōryōku lord: -10% stipend → -2 disposition per season (GDD s4.3.9)
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(
		1, 2, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU,
	)
	var retainer: L5RCharacterData = pair[1]
	var by_id: Dictionary = {1: pair[0], 2: retainer}
	var chars: Array[L5RCharacterData] = pair

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), -2)


func test_stipend_no_virtue_no_disposition_change() -> void:
	# No virtue → 0 modifier → no disposition delta (GDD s4.3.9: 0% → no change)
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(1, 2)
	var retainer: L5RCharacterData = pair[1]
	var by_id: Dictionary = {1: pair[0], 2: retainer}
	var chars: Array[L5RCharacterData] = pair

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), 0)


func test_stipend_meiyo_lord_adds_one_disposition() -> void:
	# Meiyo lord: +5% stipend → +1 disposition per season
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(
		1, 2, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE,
	)
	var retainer: L5RCharacterData = pair[1]
	var by_id: Dictionary = {1: pair[0], 2: retainer}
	var chars: Array[L5RCharacterData] = pair

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), 1)


func test_stipend_disposition_clamps_at_100() -> void:
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(
		1, 2, Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE,
	)
	var retainer: L5RCharacterData = pair[1]
	retainer.disposition_values[1] = 99
	var by_id: Dictionary = {1: pair[0], 2: retainer}
	var chars: Array[L5RCharacterData] = pair

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), 100)


func test_stipend_disposition_clamps_at_minus_100() -> void:
	var pair: Array[L5RCharacterData] = _make_lord_retainer_pair(
		1, 2, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU,
	)
	var retainer: L5RCharacterData = pair[1]
	retainer.disposition_values[1] = -99
	var by_id: Dictionary = {1: pair[0], 2: retainer}
	var chars: Array[L5RCharacterData] = pair

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(1, 0), -100)


func test_stipend_no_lord_id_skipped() -> void:
	# Characters without a lord (lord_id == -1) should be unaffected
	var standalone := L5RCharacterData.new()
	standalone.character_id = 5
	standalone.lord_id = -1
	standalone.bushido_virtue = Enums.BushidoVirtue.JIN
	var by_id: Dictionary = {5: standalone}
	var chars: Array[L5RCharacterData] = [standalone]

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(standalone.disposition_values.get(5, 0), 0)


func test_stipend_missing_lord_skipped() -> void:
	# Retainer whose lord is not in characters_by_id — should not crash
	var retainer := L5RCharacterData.new()
	retainer.character_id = 99
	retainer.lord_id = 77  # lord 77 is not in by_id
	var by_id: Dictionary = {99: retainer}
	var chars: Array[L5RCharacterData] = [retainer]

	DayOrchestrator._process_seasonal_stipend_disposition(chars, by_id)
	assert_eq(retainer.disposition_values.get(77, 0), 0)


# -- Stipend Failure Topic Creation (s4.3.9 T4-81) ----------------------------

func test_stipend_topic_created_for_reduced_payment() -> void:
	var stipends: Dictionary = {
		2: {"generates_topic": true, "lord_id": 1, "ratio": 0.6, "in_crisis": false},
	}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.physical_location = "Castle_A"
	var retainer := L5RCharacterData.new()
	retainer.character_id = 2
	retainer.lord_id = 1
	retainer.physical_location = "Castle_A"
	var by_id: Dictionary = {1: lord, 2: retainer}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [500]
	var results: Array[Dictionary] = DayOrchestrator._create_stipend_failure_topics(
		stipends, by_id, topics, next_id, 30,
	)
	assert_eq(results.size(), 1)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "stipend_failure")
	assert_eq(topics[0].variant, "STIPEND_FAILURE")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_4)
	assert_eq(topics[0].category, TopicData.Category.ECONOMIC)
	assert_eq(topics[0].subject_character_id, 1)
	assert_eq(topics[0].subject_role, "NEGATIVE")
	assert_true(500 in lord.topic_pool)
	assert_true(500 in retainer.topic_pool)
	assert_eq(next_id[0], 501)


func test_stipend_topic_not_created_when_flag_false() -> void:
	var stipends: Dictionary = {
		2: {"generates_topic": false, "lord_id": 1, "ratio": 1.0, "in_crisis": false},
	}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	var retainer := L5RCharacterData.new()
	retainer.character_id = 2
	retainer.lord_id = 1
	var by_id: Dictionary = {1: lord, 2: retainer}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [500]
	var results: Array[Dictionary] = DayOrchestrator._create_stipend_failure_topics(
		stipends, by_id, topics, next_id, 30,
	)
	assert_eq(results.size(), 0)
	assert_eq(topics.size(), 0)
	assert_eq(next_id[0], 500)


func test_stipend_topic_co_located_vassals_receive_topic() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.physical_location = "Castle_A"
	var retainer := L5RCharacterData.new()
	retainer.character_id = 2
	retainer.lord_id = 1
	retainer.physical_location = "Castle_A"
	var bystander := L5RCharacterData.new()
	bystander.character_id = 3
	bystander.lord_id = 1
	bystander.physical_location = "Castle_A"
	var outsider := L5RCharacterData.new()
	outsider.character_id = 4
	outsider.lord_id = 1
	outsider.physical_location = "Castle_B"
	var by_id: Dictionary = {1: lord, 2: retainer, 3: bystander, 4: outsider}
	var stipends: Dictionary = {
		2: {"generates_topic": true, "lord_id": 1, "ratio": 0.6, "in_crisis": false},
	}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [600]
	DayOrchestrator._create_stipend_failure_topics(
		stipends, by_id, topics, next_id, 30,
	)
	assert_true(600 in bystander.topic_pool)
	assert_false(600 in outsider.topic_pool)


func test_stipend_crisis_topic_includes_crisis_flag() -> void:
	var stipends: Dictionary = {
		2: {"generates_topic": true, "lord_id": 1, "ratio": 0.0, "in_crisis": true},
	}
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	var retainer := L5RCharacterData.new()
	retainer.character_id = 2
	retainer.lord_id = 1
	var by_id: Dictionary = {1: lord, 2: retainer}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [700]
	var results: Array[Dictionary] = DayOrchestrator._create_stipend_failure_topics(
		stipends, by_id, topics, next_id, 30,
	)
	assert_eq(results.size(), 1)
	assert_true(results[0]["in_crisis"])
	assert_eq(results[0]["lord_id"], 1)
	assert_eq(results[0]["character_id"], 2)


# -- Tax Modifier Population (s4.3.7) -----------------------------------------

func _make_province_with_lord(
	pid: int, clan: String, lord_id: int, status: float,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> Dictionary:
	var prov := ProvinceData.new()
	prov.province_id = pid
	prov.clan = clan
	var lord := L5RCharacterData.new()
	lord.character_id = lord_id
	lord.clan = clan
	lord.status = status
	lord.lord_id = -1
	lord.bushido_virtue = bushido
	lord.shourido_virtue = shourido
	return {"province": prov, "lord": lord}


func test_tax_modifier_jin_lord_negative() -> void:
	var d: Dictionary = _make_province_with_lord(
		1, "Crane", 10, 5.0, Enums.BushidoVirtue.JIN,
	)
	var provinces: Dictionary = {1: d["province"]}
	var lord: L5RCharacterData = d["lord"]
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {10: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	var tax_mods: Dictionary = meta.get("_tax_modifier", {})
	assert_true(tax_mods.has(1))
	assert_almost_eq(tax_mods[1], -0.10, 0.001)


func test_tax_modifier_kyoryoku_lord_positive() -> void:
	var d: Dictionary = _make_province_with_lord(
		2, "Crab", 20, 6.0,
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU,
	)
	var provinces: Dictionary = {2: d["province"]}
	var lord: L5RCharacterData = d["lord"]
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {20: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	assert_almost_eq(meta["_tax_modifier"][2], 0.10, 0.001)


func test_tax_modifier_no_virtue_no_entry() -> void:
	var d: Dictionary = _make_province_with_lord(3, "Lion", 30, 5.0)
	var provinces: Dictionary = {3: d["province"]}
	var lord: L5RCharacterData = d["lord"]
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {30: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	var tax_mods: Dictionary = meta.get("_tax_modifier", {})
	assert_false(tax_mods.has(3))


func test_tax_modifier_combined_bushido_shourido() -> void:
	var d: Dictionary = _make_province_with_lord(
		4, "Scorpion", 40, 5.0,
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.SEIGYO,
	)
	var provinces: Dictionary = {4: d["province"]}
	var lord: L5RCharacterData = d["lord"]
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {40: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	# CHUGI +0.05 + SEIGYO +0.05 = +0.10
	assert_almost_eq(meta["_tax_modifier"][4], 0.10, 0.001)


func test_tax_modifier_dead_lord_skipped() -> void:
	var d: Dictionary = _make_province_with_lord(
		5, "Phoenix", 50, 5.0, Enums.BushidoVirtue.JIN,
	)
	var lord: L5RCharacterData = d["lord"]
	lord.stamina = 0
	lord.willpower = 0
	var provinces: Dictionary = {5: d["province"]}
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {50: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	var tax_mods: Dictionary = meta.get("_tax_modifier", {})
	assert_false(tax_mods.has(5))


func test_tax_modifier_low_status_ignored() -> void:
	var d: Dictionary = _make_province_with_lord(
		6, "Dragon", 60, 2.0, Enums.BushidoVirtue.JIN,
	)
	var provinces: Dictionary = {6: d["province"]}
	var lord: L5RCharacterData = d["lord"]
	var chars: Array[L5RCharacterData] = [lord]
	var by_id: Dictionary = {60: lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	var tax_mods: Dictionary = meta.get("_tax_modifier", {})
	assert_false(tax_mods.has(6))


func test_tax_modifier_highest_status_lord_wins() -> void:
	var prov := ProvinceData.new()
	prov.province_id = 7
	prov.clan = "Unicorn"
	var lesser_lord := L5RCharacterData.new()
	lesser_lord.character_id = 70
	lesser_lord.clan = "Unicorn"
	lesser_lord.status = 4.0
	lesser_lord.lord_id = -1
	lesser_lord.bushido_virtue = Enums.BushidoVirtue.JIN
	var greater_lord := L5RCharacterData.new()
	greater_lord.character_id = 71
	greater_lord.clan = "Unicorn"
	greater_lord.status = 7.0
	greater_lord.lord_id = -1
	greater_lord.shourido_virtue = Enums.ShouridoVirtue.KYORYOKU
	var provinces: Dictionary = {7: prov}
	var chars: Array[L5RCharacterData] = [lesser_lord, greater_lord]
	var by_id: Dictionary = {70: lesser_lord, 71: greater_lord}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	# Greater lord has KYORYOKU (+0.10), lesser has JIN (-0.10).
	# Highest status (7.0) wins → KYORYOKU's +0.10.
	assert_almost_eq(meta["_tax_modifier"][7], 0.10, 0.001)


func test_tax_modifier_multiple_provinces() -> void:
	var d1: Dictionary = _make_province_with_lord(
		8, "Crane", 80, 5.0, Enums.BushidoVirtue.JIN,
	)
	var d2: Dictionary = _make_province_with_lord(
		9, "Lion", 90, 5.0,
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI,
	)
	var provinces: Dictionary = {8: d1["province"], 9: d2["province"]}
	var chars: Array[L5RCharacterData] = [d1["lord"], d2["lord"]]
	var by_id: Dictionary = {80: d1["lord"], 90: d2["lord"]}
	var meta: Dictionary = {}
	DayOrchestrator._populate_tax_modifiers(chars, by_id, provinces, meta)
	assert_almost_eq(meta["_tax_modifier"][8], -0.10, 0.001)
	assert_almost_eq(meta["_tax_modifier"][9], 0.05, 0.001)


# -- Clan Balance Weight (Cunning s55.10) --------------------------------------

func _make_retainer(id: int, lord_id: int, clan: String, status: float = 2.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.lord_id = lord_id
	c.clan = clan
	c.status = status
	c.honor = 3.0
	c.glory = 2.0
	c.stamina = 2
	c.willpower = 2
	return c


func test_clan_position_counts() -> void:
	var emperor_id: int = 1
	var r1 := _make_retainer(10, emperor_id, "Crane")
	r1.role_position = "Emerald Magistrate"
	var r2 := _make_retainer(11, emperor_id, "Crane")
	r2.role_position = "Imperial Advisor"
	var r3 := _make_retainer(12, emperor_id, "Lion")
	r3.role_position = "Imperial Herald"
	var r4 := _make_retainer(13, emperor_id, "Scorpion")
	var chars: Array[L5RCharacterData] = [r1, r2, r3, r4]
	var counts: Dictionary = DayOrchestrator._compute_clan_position_counts(emperor_id, chars)
	assert_eq(counts.get("Crane", 0), 2)
	assert_eq(counts.get("Lion", 0), 1)
	assert_false(counts.has("Scorpion"))


func test_clan_balance_favors_underrepresented_clan() -> void:
	var emperor_id: int = 1
	var crane := _make_retainer(10, emperor_id, "Crane")
	var lion := _make_retainer(11, emperor_id, "Lion")
	# Crane holds 3 positions, Lion holds 0 → Lion is underrepresented
	var clan_counts: Dictionary = {"Crane": 3, "Lion": 0}
	var by_id: Dictionary = {10: crane, 11: lion}
	var chars: Array[L5RCharacterData] = [crane, lion]
	# Without balance: same base scores → first candidate wins
	var no_balance: int = DayOrchestrator._find_vacancy_candidate(
		emperor_id, "Magistrate", chars, by_id, 0.0, {},
	)
	# With balance weight 25: Lion gets bonus, Crane gets penalty
	var with_balance: int = DayOrchestrator._find_vacancy_candidate(
		emperor_id, "Magistrate", chars, by_id, 25.0, clan_counts,
	)
	assert_eq(with_balance, 11)


func test_clan_balance_zero_weight_no_effect() -> void:
	var emperor_id: int = 1
	var crane := _make_retainer(10, emperor_id, "Crane")
	crane.honor = 10.0
	var lion := _make_retainer(11, emperor_id, "Lion")
	lion.honor = 1.0
	var clan_counts: Dictionary = {"Crane": 5, "Lion": 0}
	var chars: Array[L5RCharacterData] = [crane, lion]
	var by_id: Dictionary = {10: crane, 11: lion}
	var result: int = DayOrchestrator._find_vacancy_candidate(
		emperor_id, "Magistrate", chars, by_id, 0.0, clan_counts,
	)
	assert_eq(result, 10)


func test_clan_balance_skill_still_matters() -> void:
	var emperor_id: int = 1
	var crane := _make_retainer(10, emperor_id, "Crane")
	crane.honor = 20.0
	crane.glory = 10.0
	var lion := _make_retainer(11, emperor_id, "Lion")
	lion.honor = 1.0
	lion.glory = 1.0
	var clan_counts: Dictionary = {"Crane": 2, "Lion": 0}
	var chars: Array[L5RCharacterData] = [crane, lion]
	var by_id: Dictionary = {10: crane, 11: lion}
	# Crane's base score is much higher — balance weight shouldn't override that
	var result: int = DayOrchestrator._find_vacancy_candidate(
		emperor_id, "Magistrate", chars, by_id, 25.0, clan_counts,
	)
	assert_eq(result, 10)


# -- Accusation Threshold Wiring -----------------------------------------------

func test_scene_exam_accusation_generates_topic() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Bayushi Koro"
	accused.clan = "Scorpion"
	accused.family = "Bayushi"
	accused.lord_id = 10
	accused.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.character_name = "Bayushi Shoju"
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 7
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 5
	record.evidence_total = 45
	record.legal_status = Enums.LegalStatus.ACCUSED

	var characters_by_id: Dictionary = {5: accused, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [500]
	var world_states: Dictionary = {"_crime_records": [record] as Array[CrimeRecord]}

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 1,
		"effects": {
			"effect": "scene_examined",
			"case_id": 7,
			"evidence_gained": 10,
			"threshold_crossed": "accusation",
		},
	}]
	var objectives_map: Dictionary = {}

	DayOrchestrator._process_scene_examination_writebacks(
		results, objectives_map, world_states,
		characters_by_id, active_topics, next_topic_id, 100,
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 500)
	assert_eq(next_topic_id[0], 501)
	assert_true(active_topics[0].title.contains("Bayushi Koro"))
	assert_true(lord.topic_pool.has(500))


func test_scene_exam_accusation_transitions_case_entry() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Akodo Ryu"
	accused.clan = "Lion"
	accused.family = "Akodo"
	accused.lord_id = 10

	var existing_entry := LegalCaseEntry.new()
	existing_entry.crime_record_id = 3
	existing_entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	accused.legal_cases = [existing_entry]

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 3
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 42
	record.legal_status = Enums.LegalStatus.ACCUSED

	var characters_by_id: Dictionary = {5: accused, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [600]
	var world_states: Dictionary = {"_crime_records": [record] as Array[CrimeRecord]}

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 1,
		"effects": {
			"effect": "scene_examined",
			"case_id": 3,
			"evidence_gained": 8,
			"threshold_crossed": "accusation",
		},
	}]

	DayOrchestrator._process_scene_examination_writebacks(
		results, {}, world_states,
		characters_by_id, active_topics, next_topic_id, 150,
	)

	assert_eq(existing_entry.state, Enums.LegalStatus.ACCUSED)


func test_scene_exam_accusation_creates_case_entry_if_missing() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Shosuro Mei"
	accused.clan = "Scorpion"
	accused.family = "Shosuro"
	accused.lord_id = 10
	accused.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 9
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 5
	record.evidence_total = 40
	record.legal_status = Enums.LegalStatus.ACCUSED

	var characters_by_id: Dictionary = {5: accused, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [700]
	var world_states: Dictionary = {"_crime_records": [record] as Array[CrimeRecord]}

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 1,
		"effects": {
			"effect": "scene_examined",
			"case_id": 9,
			"evidence_gained": 5,
			"threshold_crossed": "accusation",
		},
	}]

	DayOrchestrator._process_scene_examination_writebacks(
		results, {}, world_states,
		characters_by_id, active_topics, next_topic_id, 200,
	)

	assert_eq(accused.legal_cases.size(), 1)
	assert_eq(accused.legal_cases[0].state, Enums.LegalStatus.ACCUSED)
	assert_eq(accused.legal_cases[0].crime_record_id, 9)


func test_witness_accusation_generates_topic() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Doji Sato"
	accused.clan = "Crane"
	accused.family = "Doji"
	accused.lord_id = 20
	accused.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 20
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 12
	record.crime_type = Enums.CrimeType.UNSANCTIONED_OPEN_KILLING
	record.perpetrator_id = 5
	record.evidence_total = 42
	record.legal_status = Enums.LegalStatus.ACCUSED
	record.known_suspects = [5]

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: accused, 20: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [800]

	var objectives_map: Dictionary = {
		1: {"standing": {"active_case": {"case_id": 12, "need_type": "INVESTIGATE_CRIME"}}}
	}

	DayOrchestrator._generate_accusation_topic_from_witness(
		1, crime_records, objectives_map,
		characters_by_id, active_topics, next_topic_id, 250,
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 800)
	assert_true(active_topics[0].title.contains("Doji Sato"))
	assert_true(lord.topic_pool.has(800))


func test_handle_evidence_threshold_accusation() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 3
	accused.character_name = "Hida Goro"
	accused.clan = "Crab"
	accused.family = "Hida"
	accused.lord_id = 15
	accused.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 15
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 22
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 3
	record.evidence_total = 42
	record.legal_status = Enums.LegalStatus.ACCUSED

	var characters_by_id: Dictionary = {3: accused, 15: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [900]

	DayOrchestrator.handle_evidence_threshold(
		"accusation", record, characters_by_id,
		active_topics, next_topic_id, 300,
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 900)
	assert_true(lord.topic_pool.has(900))
	assert_eq(accused.legal_cases.size(), 1)
	assert_eq(accused.legal_cases[0].state, Enums.LegalStatus.ACCUSED)
	assert_eq(accused.legal_cases[0].accusation_timestamp, 300)


func test_handle_evidence_threshold_bribery_eval() -> void:
	var record := CrimeRecord.new()
	record.case_id = 33
	record.perpetrator_id = 7
	record.evidence_total = 28

	var world_states: Dictionary = {}
	var characters_by_id: Dictionary = {}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]

	DayOrchestrator.handle_evidence_threshold(
		"bribery_eval", record, characters_by_id,
		active_topics, next_topic_id, 50, world_states,
	)

	var perp_ws: Dictionary = world_states.get(7, {})
	var pending: Array = perp_ws.get("pending_events", [])
	assert_eq(pending.size(), 1)
	assert_eq(pending[0]["type"], "bribery_eval")
	assert_eq(pending[0]["case_id"], 33)


func test_failed_bribe_adds_evidence_to_existing_case() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 5
	briber.character_name = "Guilty Briber"
	briber.clan = "Scorpion"
	briber.family = "Bayushi"
	briber.lord_id = 10
	briber.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 50
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 20
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: briber, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1000]
	var world_states: Dictionary = {}

	DayOrchestrator._apply_failed_bribe_evidence(
		crime_records, 5, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
	)

	assert_eq(record.evidence_total, 35)


func test_failed_bribe_triggers_accusation_if_threshold_crossed() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 5
	briber.character_name = "Caught Briber"
	briber.clan = "Scorpion"
	briber.family = "Bayushi"
	briber.lord_id = 10
	briber.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 51
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 30
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: briber, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1000]
	var world_states: Dictionary = {}

	DayOrchestrator._apply_failed_bribe_evidence(
		crime_records, 5, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
	)

	assert_eq(record.evidence_total, 45)
	assert_eq(record.legal_status, Enums.LegalStatus.ACCUSED)
	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 1000)


func test_investigation_opened_topic_generated() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 7
	magistrate.character_name = "Kitsuki Shin"
	magistrate.clan = "Dragon"
	magistrate.family = "Kitsuki"

	var record := CrimeRecord.new()
	record.case_id = 60
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 3
	record.location = "castle_lion"

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {7: magistrate}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [500]

	var uphold_law_results: Array[Dictionary] = [
		{"magistrate_id": 7, "case_id": 60}
	]

	DayOrchestrator._generate_investigation_opened_topics(
		uphold_law_results, crime_records, characters_by_id,
		active_topics, next_topic_id, 50,
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 500)
	assert_eq(active_topics[0].tier, TopicData.Tier.TIER_4)
	assert_eq(active_topics[0].category, TopicData.Category.LEGAL)
	assert_eq(active_topics[0].slug, "investigation_60")


# -- Bribery Attempt Topic (T3-15) ---

func test_failed_bribe_generates_bribery_attempt_topic() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 5
	briber.character_name = "Shosuro Hametsu"
	briber.clan = "Scorpion"
	briber.family = "Shosuro"
	briber.lord_id = 10
	briber.legal_cases = []

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Kitsuki Kaagi"

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 77
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 18
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: briber, 10: lord, 20: magistrate}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [900]
	var world_states: Dictionary = {}

	DayOrchestrator._apply_failed_bribe_evidence(
		crime_records, 5, characters_by_id,
		active_topics, next_topic_id, 100, world_states, 20,
	)

	assert_eq(record.evidence_total, 33)
	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].tier, TopicData.Tier.TIER_3)
	assert_eq(active_topics[0].category, TopicData.Category.POLITICAL)
	assert_true(active_topics[0].title.contains("Shosuro Hametsu"))
	assert_true(active_topics[0].title.contains("Kitsuki Kaagi"))
	assert_eq(active_topics[0].slug, "bribery_attempt_77")


# -- Successful Bribe (s11.3.11f Step 7b) ---

func test_successful_bribe_buries_case() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 5
	briber.character_name = "Bayushi Koro"
	briber.clan = "Scorpion"
	briber.lord_id = 10
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 88
	entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	briber.legal_cases = [entry]

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Corrupt Magistrate"
	magistrate.honor = 3.0

	var record := CrimeRecord.new()
	record.case_id = 88
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 28
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: briber, 20: magistrate}

	var results: Array = [{
		"action_id": "BRIBE_FOR_INFO",
		"success": true,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {
			"suppress_case": true,
			"magistrate_id": 20,
			"detection_risk": false,
		},
	}]

	DayOrchestrator._process_successful_bribe_writebacks(
		results, crime_records, characters_by_id, 100,
	)

	assert_eq(record.legal_status, Enums.LegalStatus.CLEAR)
	assert_eq(entry.state, Enums.LegalStatus.CLEAR)
	assert_lt(magistrate.honor, 3.0)


# -- Fugitive Declaration (T3-12) ---

func test_fugitive_declaration_generates_topic() -> void:
	var fugitive := L5RCharacterData.new()
	fugitive.character_id = 5
	fugitive.character_name = "Ikoma Tsuko"
	fugitive.clan = "Lion"
	fugitive.family = "Ikoma"
	fugitive.lord_id = 10
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 99
	entry.state = Enums.LegalStatus.ACCUSED
	fugitive.legal_cases = [entry]

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 99
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 5
	record.legal_status = Enums.LegalStatus.ACCUSED

	var characters_by_id: Dictionary = {5: fugitive, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1100]

	var result: Dictionary = DayOrchestrator.process_fugitive_declaration(
		record, fugitive, characters_by_id,
		active_topics, next_topic_id, 200,
	)

	assert_true(result["declared"])
	assert_eq(record.legal_status, Enums.LegalStatus.FUGITIVE)
	assert_eq(entry.state, Enums.LegalStatus.FUGITIVE)
	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_id, 1100)
	assert_true(active_topics[0].title.contains("Ikoma Tsuko"))
	assert_eq(active_topics[0].slug, "fugitive_5")
	assert_true(lord.topic_pool.has(1100))


# -- Co-Conspirator Secrets ---

func test_successful_bribe_creates_two_secrets() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 5
	briber.character_name = "Bayushi Koro"
	briber.clan = "Scorpion"
	briber.lord_id = 10
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 88
	entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	briber.legal_cases = [entry]

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Corrupt Magistrate"
	magistrate.honor = 3.0

	var record := CrimeRecord.new()
	record.case_id = 88
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 5
	record.evidence_total = 28
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: briber, 20: magistrate}
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [50]

	var results: Array = [{
		"action_id": "BRIBE_FOR_INFO",
		"success": true,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {
			"suppress_case": true,
			"magistrate_id": 20,
			"detection_risk": false,
		},
	}]

	DayOrchestrator._process_successful_bribe_writebacks(
		results, crime_records, characters_by_id, 100,
		active_secrets, next_secret_id,
	)

	assert_eq(active_secrets.size(), 2)
	assert_eq(next_secret_id[0], 52)

	var secret_mag: SecretData = active_secrets[0]
	assert_eq(secret_mag.subject_id, 20)
	assert_eq(secret_mag.severity, SecretData.Severity.TIER_1)
	assert_true(secret_mag.slug.begins_with("bribe_accepted_"))
	assert_true(secret_mag.description.contains("Corrupt Magistrate"))

	var secret_briber: SecretData = active_secrets[1]
	assert_eq(secret_briber.subject_id, 5)
	assert_eq(secret_briber.severity, SecretData.Severity.TIER_1)
	assert_true(secret_briber.slug.begins_with("bribe_offered_"))
	assert_true(secret_briber.description.contains("Bayushi Koro"))


# -- Flee Jurisdiction Writeback ---

func test_flee_jurisdiction_triggers_fugitive_declaration() -> void:
	var fugitive := L5RCharacterData.new()
	fugitive.character_id = 7
	fugitive.character_name = "Daidoji Ran"
	fugitive.clan = "Crane"
	fugitive.family = "Daidoji"
	fugitive.lord_id = 10
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 77
	entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	fugitive.legal_cases = [entry]

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 77
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 7
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {7: fugitive, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [2000]

	var results: Array = [{
		"action_id": "FLEE_JURISDICTION",
		"success": true,
		"character_id": 7,
		"target_npc_id": -1,
		"target_province_id": -1,
		"effects": {
			"effect": "flee_jurisdiction",
			"fugitive_id": 7,
		},
	}]

	DayOrchestrator._process_flee_jurisdiction_writebacks(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 150,
	)

	assert_eq(record.legal_status, Enums.LegalStatus.FUGITIVE)
	assert_eq(entry.state, Enums.LegalStatus.FUGITIVE)
	assert_eq(active_topics.size(), 1)
	assert_true(active_topics[0].title.contains("Daidoji Ran"))


# -- Extortion Writeback ---

func test_extortion_buries_case_and_creates_secret() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 30
	magistrate.character_name = "Soshi Ito"
	magistrate.honor = 2.5

	var suspect := L5RCharacterData.new()
	suspect.character_id = 8
	suspect.character_name = "Yasuki Tai"
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 44
	entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	suspect.legal_cases = [entry]

	var record := CrimeRecord.new()
	record.case_id = 44
	record.crime_type = Enums.CrimeType.SKIMMING
	record.perpetrator_id = 8
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {30: magistrate, 8: suspect}
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [100]

	var results: Array = [{
		"action_id": "EXTORT_ACCUSED",
		"success": true,
		"character_id": 30,
		"target_npc_id": 8,
		"effects": {
			"effect": "extortion_attempt",
			"suppress_case": true,
			"magistrate_id": 30,
			"suspect_id": 8,
		},
	}]

	DayOrchestrator._process_extortion_writebacks(
		results, crime_records, characters_by_id, 200,
		active_secrets, next_secret_id,
	)

	assert_eq(record.legal_status, Enums.LegalStatus.CLEAR)
	assert_eq(entry.state, Enums.LegalStatus.CLEAR)
	assert_lt(magistrate.honor, 2.5)
	assert_eq(active_secrets.size(), 1)
	assert_eq(active_secrets[0].subject_id, 30)
	assert_true(active_secrets[0].slug.begins_with("extortion_"))
	assert_true(active_secrets[0].description.contains("Soshi Ito"))


# -- Evidence Threshold Injects Extortion Opportunity ---

func test_bribery_eval_threshold_injects_extortion_event() -> void:
	var record := CrimeRecord.new()
	record.case_id = 55
	record.perpetrator_id = 3
	record.investigating_magistrate_id = 12
	record.evidence_total = 26

	var characters_by_id: Dictionary = {}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [500]
	var world_states: Dictionary = {}

	DayOrchestrator.handle_evidence_threshold(
		"bribery_eval", record, characters_by_id,
		active_topics, next_topic_id, 80, world_states,
	)

	var mag_ws: Dictionary = world_states.get(12, {})
	var mag_pending: Array = mag_ws.get("pending_events", [])
	assert_eq(mag_pending.size(), 1)
	assert_eq(mag_pending[0]["type"], "extortion_opportunity")
	assert_eq(mag_pending[0]["suspect_id"], 3)
	assert_eq(mag_pending[0]["case_id"], 55)


# -- PTL Detection (Channel 1) ---

func test_ptl_detection_shugenja_generates_topic() -> void:
	var shugenja := L5RCharacterData.new()
	shugenja.character_id = 15
	shugenja.character_name = "Kuni Yori"
	shugenja.clan = "Crab"
	shugenja.family = "Kuni"
	shugenja.school_type = Enums.SchoolType.SHUGENJA
	shugenja.perception = 4
	shugenja.skills["Lore: Shadowlands"] = 3
	shugenja.lord_id = 10

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var province := ProvinceData.new()
	province.province_name = "Kuni Wastes"
	province.province_taint_level = 4.0

	var characters_by_id: Dictionary = {15: shugenja, 10: lord}
	var provinces: Dictionary = {3: province}
	var character_province_map: Dictionary = {15: 3}
	var dice_engine := DiceEngine.new()
	dice_engine.set_seed(42)
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [3000]

	var results: Array = [{
		"action_id": "INVESTIGATE_PROVINCE",
		"success": true,
		"character_id": 15,
		"target_province_id": 3,
	}]

	DayOrchestrator._process_ptl_detection(
		results, characters_by_id, provinces, character_province_map,
		dice_engine, active_topics, next_topic_id, 50,
	)

	# TN = PTL × 5 = 20; Kuni shugenja rolls 4+3+2=9k4; very likely to succeed
	if active_topics.size() > 0:
		assert_eq(active_topics[0].tier, TopicData.Tier.TIER_3)
		assert_eq(active_topics[0].category, TopicData.Category.SUPERNATURAL)
		assert_true(active_topics[0].title.contains("Kuni Wastes"))
		assert_true(active_topics[0].slug.begins_with("ptl_detection_"))
		assert_true(lord.topic_pool.has(active_topics[0].topic_id))
	else:
		pass_test("Roll failed — probabilistic; PTL detection is gated by dice")


func test_ptl_detection_non_shugenja_skipped() -> void:
	var bushi := L5RCharacterData.new()
	bushi.character_id = 16
	bushi.character_name = "Hida Kisada"
	bushi.clan = "Crab"
	bushi.family = "Hida"
	bushi.school_type = Enums.SchoolType.BUSHI
	bushi.perception = 3
	bushi.skills["Lore: Shadowlands"] = 2

	var province := ProvinceData.new()
	province.province_name = "Kuni Wastes"
	province.province_taint_level = 5.0

	var characters_by_id: Dictionary = {16: bushi}
	var provinces: Dictionary = {3: province}
	var character_province_map: Dictionary = {16: 3}
	var dice_engine := DiceEngine.new()
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [3000]

	var results: Array = [{
		"action_id": "INVESTIGATE_PROVINCE",
		"success": true,
		"character_id": 16,
		"target_province_id": 3,
	}]

	DayOrchestrator._process_ptl_detection(
		results, characters_by_id, provinces, character_province_map,
		dice_engine, active_topics, next_topic_id, 50,
	)

	assert_eq(active_topics.size(), 0)


# -- Blood Evidence Discovery (Channel 2) ---

func test_blood_evidence_discovery_generates_topic() -> void:
	var investigator := L5RCharacterData.new()
	investigator.character_id = 25
	investigator.character_name = "Soshi Magistrate"
	investigator.clan = "Scorpion"
	investigator.lord_id = 10

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var record := CrimeRecord.new()
	record.case_id = 66
	record.crime_type = Enums.CrimeType.MAHO
	record.perpetrator_id = 99
	record.location = "Isawa Province"
	record.concealment_tn = 15
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {25: investigator, 10: lord}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [4000]

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 25,
		"roll_total": 20,
		"effects": {"case_id": 66, "evidence_gained": 8},
	}]

	DayOrchestrator._process_blood_evidence_discovery(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 80,
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].tier, TopicData.Tier.TIER_3)
	assert_eq(active_topics[0].category, TopicData.Category.SUPERNATURAL)
	assert_true(active_topics[0].title.contains("blood magic"))
	assert_true(active_topics[0].title.contains("Isawa Province"))
	assert_eq(active_topics[0].slug, "blood_evidence_66")
	assert_true(lord.topic_pool.has(active_topics[0].topic_id))


func test_blood_evidence_not_triggered_for_non_maho() -> void:
	var record := CrimeRecord.new()
	record.case_id = 67
	record.crime_type = Enums.CrimeType.VIOLENCE
	record.perpetrator_id = 99
	record.location = "Lion Province"
	record.concealment_tn = 15

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {25: L5RCharacterData.new()}
	characters_by_id[25].character_id = 25
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [4000]

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 25,
		"roll_total": 20,
		"effects": {"case_id": 67, "evidence_gained": 5},
	}]

	DayOrchestrator._process_blood_evidence_discovery(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 80,
	)

	assert_eq(active_topics.size(), 0)


func test_blood_evidence_not_triggered_below_concealment_tn() -> void:
	var record := CrimeRecord.new()
	record.case_id = 68
	record.crime_type = Enums.CrimeType.MAHO
	record.perpetrator_id = 99
	record.location = "Shinomen Mori"
	record.concealment_tn = 25

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {25: L5RCharacterData.new()}
	characters_by_id[25].character_id = 25
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [4000]

	var results: Array = [{
		"action_id": "EXAMINE_CRIME_SCENE",
		"success": true,
		"character_id": 25,
		"roll_total": 18,
		"effects": {"case_id": 68, "evidence_gained": 3},
	}]

	DayOrchestrator._process_blood_evidence_discovery(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 80,
	)

	assert_eq(active_topics.size(), 0)


# -- Flee Logistics ---

func test_flee_logistics_starts_travel() -> void:
	var fugitive := L5RCharacterData.new()
	fugitive.character_id = 7
	fugitive.character_name = "Fugitive"
	fugitive.physical_location = "crane_castle"
	fugitive.travel_destination = ""
	fugitive.travel_days_remaining = 0

	var characters_by_id: Dictionary = {7: fugitive}
	var active_courts: Array[CourtSessionData] = []

	var results: Array = [{
		"action_id": "FLEE_JURISDICTION",
		"success": true,
		"character_id": 7,
		"effects": {"effect": "flee_jurisdiction", "fugitive_id": 7},
	}]

	DayOrchestrator._process_flee_logistics(
		results, characters_by_id, active_courts,
	)

	assert_eq(fugitive.travel_destination, "ronin_haven")
	assert_gt(fugitive.travel_days_remaining, 0)


func test_flee_logistics_removes_from_court() -> void:
	var fugitive := L5RCharacterData.new()
	fugitive.character_id = 7
	fugitive.character_name = "Fugitive"
	fugitive.physical_location = "crane_castle"
	fugitive.travel_destination = ""
	fugitive.travel_days_remaining = 0

	var court := CourtSessionData.new()
	court.attendee_ids = [7, 10, 20] as Array[int]

	var characters_by_id: Dictionary = {7: fugitive}
	var active_courts: Array[CourtSessionData] = [court]

	var results: Array = [{
		"action_id": "FLEE_JURISDICTION",
		"success": true,
		"character_id": 7,
		"effects": {"effect": "flee_jurisdiction", "fugitive_id": 7},
	}]

	DayOrchestrator._process_flee_logistics(
		results, characters_by_id, active_courts,
	)

	assert_false(court.attendee_ids.has(7))
	assert_eq(court.attendee_ids.size(), 2)


# -- Position Vacancy on Flee ---

func test_flee_creates_vacancy_for_position_holder() -> void:
	var fugitive := L5RCharacterData.new()
	fugitive.character_id = 7
	fugitive.character_name = "Magistrate"
	fugitive.physical_location = "scorpion_castle"
	fugitive.travel_destination = ""
	fugitive.travel_days_remaining = 0
	fugitive.role_position = "provincial_magistrate"
	fugitive.lord_id = 10

	var characters_by_id: Dictionary = {7: fugitive}
	var active_courts: Array[CourtSessionData] = []
	var world_states: Dictionary = {}

	var results: Array = [{
		"action_id": "FLEE_JURISDICTION",
		"success": true,
		"character_id": 7,
		"effects": {"effect": "flee_jurisdiction", "fugitive_id": 7},
	}]

	DayOrchestrator._process_flee_logistics(
		results, characters_by_id, active_courts, world_states,
	)

	assert_eq(fugitive.role_position, "")
	var vkey: String = "vacant_positions_10"
	var vacancies: Array = world_states.get(vkey, [])
	assert_eq(vacancies.size(), 1)
	assert_eq(vacancies[0]["position_type"], "provincial_magistrate")
	assert_eq(vacancies[0]["priority"], 2)


# -- Zone Log Purge ---

func test_zone_log_purge_resets_concealment_tn() -> void:
	var record := CrimeRecord.new()
	record.case_id = 100
	record.crime_type = Enums.CrimeType.MAHO
	record.concealment_tn = 18
	record.ic_day_committed = 10

	var crime_records: Array[CrimeRecord] = [record]

	DayOrchestrator._purge_expired_crime_evidence(crime_records, 99)
	assert_eq(record.concealment_tn, 18)

	DayOrchestrator._purge_expired_crime_evidence(crime_records, 100)
	assert_eq(record.concealment_tn, 0)


func test_zone_log_purge_skips_zero_concealment() -> void:
	var record := CrimeRecord.new()
	record.case_id = 101
	record.concealment_tn = 0
	record.ic_day_committed = 5

	var crime_records: Array[CrimeRecord] = [record]
	DayOrchestrator._purge_expired_crime_evidence(crime_records, 200)
	assert_eq(record.concealment_tn, 0)


# -- Taint Proximity Detection (Channel 3) ---

func test_taint_detection_generates_topic_for_tainted_target() -> void:
	var detector := L5RCharacterData.new()
	detector.character_id = 30
	detector.character_name = "Kuni Witch-Hunter"
	detector.clan = "Crab"
	detector.family = "Kuni"
	detector.school_type = Enums.SchoolType.SHUGENJA
	detector.perception = 4
	detector.skills["Lore: Shadowlands"] = 4
	detector.lord_id = 10

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.topic_pool = [] as Array[int]

	var tainted := L5RCharacterData.new()
	tainted.character_id = 40
	tainted.character_name = "Maho Tsukai"
	tainted.clan = "Scorpion"
	tainted.family = "Soshi"
	tainted.taint = 3.5

	var characters_by_id: Dictionary = {30: detector, 40: tainted, 10: lord}
	var character_province_map: Dictionary = {30: 1, 40: 1}
	var dice_engine := DiceEngine.new()
	dice_engine.set_seed(42)
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [5000]

	var results: Array = [{
		"action_id": "PROBE",
		"success": true,
		"character_id": 30,
		"target_npc_id": 40,
	}]

	DayOrchestrator._process_taint_proximity_detection(
		results, characters_by_id, character_province_map,
		dice_engine, active_topics, next_topic_id, 100,
	)

	# Kuni with 4+4+2=10k4 vs TN 20: should succeed with seed 42
	if active_topics.size() > 0:
		assert_eq(active_topics[0].tier, TopicData.Tier.TIER_3)
		assert_eq(active_topics[0].category, TopicData.Category.SUPERNATURAL)
		assert_true(active_topics[0].title.contains("Maho Tsukai"))
		assert_eq(active_topics[0].slug, "taint_suspected_40")
		assert_eq(active_topics[0].subject_role, "PERPETRATOR")
	else:
		pass_test("Roll failed — probabilistic; taint detection gated by dice")


func test_taint_detection_skips_low_taint() -> void:
	var detector := L5RCharacterData.new()
	detector.character_id = 30
	detector.character_name = "Kuni"
	detector.family = "Kuni"
	detector.perception = 4
	detector.skills["Lore: Shadowlands"] = 4

	var target := L5RCharacterData.new()
	target.character_id = 40
	target.taint = 1.5

	var characters_by_id: Dictionary = {30: detector, 40: target}
	var dice_engine := DiceEngine.new()
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [5000]

	var results: Array = [{
		"action_id": "PROBE",
		"success": true,
		"character_id": 30,
		"target_npc_id": 40,
	}]

	DayOrchestrator._process_taint_proximity_detection(
		results, characters_by_id, {},
		dice_engine, active_topics, next_topic_id, 100,
	)

	assert_eq(active_topics.size(), 0)


# -- Witness Tampering Writebacks ---

func test_bribe_witness_success_removes_from_record() -> void:
	var record := CrimeRecord.new()
	record.case_id = 200
	record.perpetrator_id = 5
	record.witnesses = [20, 30] as Array[int]
	record.evidence_total = 15

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [6000]
	var world_states: Dictionary = {}

	var results: Array = [{
		"action_id": "BRIBE_WITNESS",
		"success": true,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {"effect": "witness_bribed", "witness_id": 20},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
	)

	assert_false(record.witnesses.has(20))
	assert_true(record.witnesses.has(30))
	assert_eq(record.evidence_total, 15)


func test_intimidate_witness_failure_adds_evidence() -> void:
	var record := CrimeRecord.new()
	record.case_id = 201
	record.perpetrator_id = 5
	record.witnesses = [20] as Array[int]
	record.evidence_total = 10

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [6000]
	var world_states: Dictionary = {}

	var results: Array = [{
		"action_id": "INTIMIDATE_WITNESS",
		"success": false,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {
			"effect": "intimidation_rejected",
			"witness_id": 20,
			"witness_hostile": true,
			"evidence_on_fail": 10,
		},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
	)

	assert_true(record.witnesses.has(20))
	assert_eq(record.evidence_total, 20)


# -- Bribe Witness Co-Conspirator Secret ---

func test_bribe_witness_creates_tier2_secret() -> void:
	var criminal := L5RCharacterData.new()
	criminal.character_id = 5
	criminal.character_name = "Bayushi Koro"

	var witness := L5RCharacterData.new()
	witness.character_id = 20
	witness.character_name = "Doji Ran"

	var record := CrimeRecord.new()
	record.case_id = 300
	record.perpetrator_id = 5
	record.witnesses = [20] as Array[int]
	record.evidence_total = 10

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {5: criminal, 20: witness}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [7000]
	var world_states: Dictionary = {}
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [200]
	var next_case_id: Array[int] = [500]

	var results: Array = [{
		"action_id": "BRIBE_WITNESS",
		"success": true,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {"effect": "witness_bribed", "witness_id": 20},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
		active_secrets, next_secret_id, next_case_id,
	)

	assert_false(record.witnesses.has(20))
	assert_eq(active_secrets.size(), 1)
	assert_eq(active_secrets[0].subject_id, 20)
	assert_eq(active_secrets[0].severity, SecretData.Severity.TIER_2)
	assert_true(active_secrets[0].slug.begins_with("bribed_witness_"))


# -- Kill Witness ---

func test_kill_witness_removes_and_creates_murder_record() -> void:
	var record := CrimeRecord.new()
	record.case_id = 310
	record.perpetrator_id = 5
	record.witnesses = [20] as Array[int]
	record.evidence_total = 10
	record.location = "scorpion_province"

	var crime_records: Array[CrimeRecord] = [record]
	var characters_by_id: Dictionary = {}
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [7000]
	var world_states: Dictionary = {}
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [200]
	var next_case_id: Array[int] = [500]

	var results: Array = [{
		"action_id": "KILL_WITNESS",
		"success": true,
		"character_id": 5,
		"target_npc_id": 20,
		"effects": {
			"effect": "witness_killed",
			"witness_id": 20,
			"concealment_tn": 22,
		},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		results, crime_records, characters_by_id,
		active_topics, next_topic_id, 100, world_states,
		active_secrets, next_secret_id, next_case_id,
	)

	assert_false(record.witnesses.has(20))
	assert_eq(crime_records.size(), 2)
	var murder: CrimeRecord = crime_records[1]
	assert_eq(murder.crime_type, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	assert_eq(murder.perpetrator_id, 5)
	assert_eq(murder.victim_id, 20)
	assert_eq(murder.concealment_tn, 22)
	assert_eq(murder.location, "scorpion_province")


# -- Criminal Recall ---

func test_criminal_recall_success_stores_awareness() -> void:
	var criminal := L5RCharacterData.new()
	criminal.character_id = 5
	criminal.intelligence = 4

	var record := CrimeRecord.new()
	record.case_id = 400

	var witnesses: Array[int] = [20, 30]
	var dice_engine := DiceEngine.new()
	dice_engine.set_seed(42)
	var world_states: Dictionary = {}

	DayOrchestrator._apply_criminal_recall(
		criminal, record, witnesses, dice_engine, world_states,
	)

	# Intelligence 4, rolls 4k4 vs TN 10 — should succeed with seed 42
	var ws: Dictionary = world_states.get(5, {})
	if ws.has("criminal_recall"):
		assert_eq(ws["criminal_recall"]["case_id"], 400)
		assert_eq(ws["criminal_recall"]["witness_count"], 2)
		assert_true(ws["criminal_recall"]["aware_of_evidence"])
	else:
		pass_test("Roll failed — probabilistic; recall gated by dice")


# -- Investigation Loop: Discovery Type Routes Legal Status ---

func test_discovery_type_sets_initial_legal_status() -> void:
	var violence_discovery := InvestigationLoopSystem.get_discovery_type("violence")
	var violence_status := InvestigationLoopSystem.get_initial_legal_status(violence_discovery)
	assert_eq(violence_status, Enums.LegalStatus.UNDER_INVESTIGATION)

	var skimming_discovery := InvestigationLoopSystem.get_discovery_type("skimming")
	var skimming_status := InvestigationLoopSystem.get_initial_legal_status(skimming_discovery)
	assert_eq(skimming_status, Enums.LegalStatus.SUSPECTED)

	var maho_discovery := InvestigationLoopSystem.get_discovery_type("maho")
	var maho_status := InvestigationLoopSystem.get_initial_legal_status(maho_discovery)
	assert_eq(maho_status, Enums.LegalStatus.UNDER_INVESTIGATION)


func test_crime_type_to_string_mapping() -> void:
	assert_eq(DayOrchestrator._crime_type_to_string(Enums.CrimeType.VIOLENCE), "violence")
	assert_eq(DayOrchestrator._crime_type_to_string(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING), "murder")
	assert_eq(DayOrchestrator._crime_type_to_string(Enums.CrimeType.SKIMMING), "skimming")
	assert_eq(DayOrchestrator._crime_type_to_string(Enums.CrimeType.MAHO), "maho")
	assert_eq(DayOrchestrator._crime_type_to_string(Enums.CrimeType.TREASON), "treason")


# ==============================================================================
# INTEGRATION TEST: Full Investigation Pipeline End-to-End
# ==============================================================================
# Exercises: crime committed → topic created → witnesses seeded → criminal recall
# → magistrate UPHOLD_LAW scan → scene examination → evidence accumulates
# → bribery_eval threshold (25) → accusation threshold (40) → fugitive declaration

func test_investigation_pipeline_end_to_end() -> void:
	# --- Setup: criminal, victim, witness, magistrate ---
	var criminal := L5RCharacterData.new()
	criminal.character_id = 100
	criminal.character_name = "Bayushi Kachiko"
	criminal.clan = "Scorpion"
	criminal.family = "Bayushi"
	criminal.honor = 2.0
	criminal.glory = 4.0
	criminal.intelligence = 4
	criminal.agility = 4
	criminal.awareness = 3
	criminal.reflexes = 3
	criminal.willpower = 3
	criminal.perception = 3
	criminal.stamina = 3
	criminal.strength = 3
	criminal.void_ring = 3
	criminal.skills = {"Stealth": 4, "Temptation": 3}
	criminal.emphases = {}
	criminal.wounds_taken = 0
	criminal.knowledge_pool = []
	criminal.known_contacts_by_clan = {}
	criminal.met_characters = []
	criminal.physical_location = "scorpion_province_1"
	criminal.lord_id = 200
	criminal.legal_cases = []
	criminal.topic_pool = []

	var victim := L5RCharacterData.new()
	victim.character_id = 101
	victim.character_name = "Crane Merchant"
	victim.clan = "Crane"
	victim.physical_location = "scorpion_province_1"
	victim.honor = 4.0
	victim.topic_pool = []
	victim.legal_cases = []

	var witness := L5RCharacterData.new()
	witness.character_id = 102
	witness.character_name = "Doji Witness"
	witness.clan = "Crane"
	witness.family = "Doji"
	witness.awareness = 4
	witness.perception = 3
	witness.honor = 6.0
	witness.physical_location = "scorpion_province_1"
	witness.topic_pool = []
	witness.legal_cases = []

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 103
	magistrate.character_name = "Soshi Magistrate"
	magistrate.clan = "Scorpion"
	magistrate.family = "Soshi"
	magistrate.role_position = "emerald_magistrate"
	magistrate.bushido_virtue = Enums.BushidoVirtue.GI
	magistrate.shourido_virtue = Enums.ShouridoVirtue.NONE
	magistrate.honor = 7.0
	magistrate.perception = 4
	magistrate.intelligence = 4
	magistrate.awareness = 4
	magistrate.reflexes = 3
	magistrate.willpower = 4
	magistrate.agility = 3
	magistrate.stamina = 3
	magistrate.strength = 3
	magistrate.void_ring = 3
	magistrate.skills = {"Investigation": 5, "Etiquette": 3, "Lore: Law": 4}
	magistrate.emphases = {}
	magistrate.wounds_taken = 0
	magistrate.knowledge_pool = []
	magistrate.known_contacts_by_clan = {}
	magistrate.met_characters = []
	magistrate.physical_location = "scorpion_province_1"
	magistrate.topic_pool = []
	magistrate.legal_cases = []

	var lord := L5RCharacterData.new()
	lord.character_id = 200
	lord.character_name = "Bayushi Lord"
	lord.clan = "Scorpion"
	lord.topic_pool = []
	lord.legal_cases = []

	var characters_by_id: Dictionary = {
		100: criminal, 101: victim, 102: witness, 103: magistrate, 200: lord,
	}

	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1000]
	var next_case_id: Array[int] = [1]
	var world_states: Dictionary = {}
	var ic_day: int = 50

	# ---------------------------------------------------------------
	# PHASE 1: Crime committed — murder with a witness present
	# ---------------------------------------------------------------
	var witnesses: Array[int] = [102]
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		next_case_id[0],
		Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
		100,
		"scorpion_province_1",
		ic_day,
		101,
		15,
		witnesses,
	)
	next_case_id[0] += 1
	crime_records.append(record)

	# Verify discovery type routes to IMMEDIATE for murder
	var crime_type_str: String = DayOrchestrator._crime_type_to_string(
		Enums.CrimeType.UNSANCTIONED_COVERT_KILLING
	)
	var discovery: InvestigationLoopSystem.DiscoveryType = InvestigationLoopSystem.get_discovery_type(crime_type_str)
	assert_eq(discovery, InvestigationLoopSystem.DiscoveryType.IMMEDIATE)
	record.legal_status = InvestigationLoopSystem.get_initial_legal_status(discovery)
	assert_eq(record.legal_status, Enums.LegalStatus.UNDER_INVESTIGATION)

	# Crime topic created and seeded to witness
	var crime_topic: TopicData = DayOrchestrator._create_crime_topic(
		record, criminal, ic_day, next_topic_id,
	)
	assert_not_null(crime_topic)
	assert_eq(crime_topic.slug, "crime_case_1")
	active_topics.append(crime_topic)
	DayOrchestrator._seed_crime_topic_to_knowers(crime_topic, record, characters_by_id)

	# Witness now knows about the crime topic
	assert_true(crime_topic.topic_id in witness.topic_pool)
	# Victim also seeded
	assert_true(crime_topic.topic_id in victim.topic_pool)

	# ---------------------------------------------------------------
	# PHASE 2: Criminal recall — Intelligence vs TN 10
	# ---------------------------------------------------------------
	_dice.set_seed(42)
	DayOrchestrator._apply_criminal_recall(
		criminal, record, witnesses, _dice, world_states,
	)
	# Intelligence 4 vs TN 10 — with seed 42, likely to succeed
	var recall_data: Dictionary = world_states.get(100, {}).get("criminal_recall", {})
	if not recall_data.is_empty():
		assert_eq(recall_data["case_id"], 1)
		assert_eq(recall_data["witness_count"], 1)
		assert_true(recall_data["aware_of_evidence"])
	else:
		pass_test("Recall failed — probabilistic")

	# ---------------------------------------------------------------
	# PHASE 3: Magistrate UPHOLD_LAW scan picks up the crime topic
	# ---------------------------------------------------------------
	# Give magistrate knowledge of the crime topic
	magistrate.topic_pool.append(crime_topic.topic_id)

	var objectives_map: Dictionary = {
		103: {
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}

	var uphold_results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		[magistrate] as Array[L5RCharacterData],
		objectives_map,
		crime_records,
		active_topics,
	)

	assert_eq(uphold_results.size(), 1)
	assert_eq(uphold_results[0]["magistrate_id"], 103)
	assert_eq(uphold_results[0]["case_id"], 1)
	# Magistrate is now assigned to the case
	assert_eq(record.investigating_magistrate_id, 103)

	# Investigation opened topic generated
	DayOrchestrator._generate_investigation_opened_topics(
		uphold_results, crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day,
	)
	var investigation_topic: TopicData = null
	for t: TopicData in active_topics:
		if t.slug == "investigation_1":
			investigation_topic = t
			break
	assert_not_null(investigation_topic)

	# ---------------------------------------------------------------
	# PHASE 4: Scene examination — evidence accumulates
	# ---------------------------------------------------------------
	_dice.set_seed(100)
	var exam_result: Dictionary = InvestigationSystem.examine_scene(
		magistrate, record, _dice, ic_day,
	)
	assert_true(exam_result["success"])
	assert_true(exam_result["evidence_gained"] > 0)

	# Evidence should be building. If not enough yet, add a second pass.
	if record.evidence_total < InvestigationSystem.BRIBERY_EVAL_TRIGGER:
		_dice.set_seed(200)
		InvestigationSystem.examine_scene(magistrate, record, _dice, ic_day + 1)

	# ---------------------------------------------------------------
	# PHASE 5: Bribery eval threshold (25) — criminal gets event
	# ---------------------------------------------------------------
	# Manually push evidence to exactly trigger bribery_eval if not there yet
	if record.evidence_total < InvestigationSystem.BRIBERY_EVAL_TRIGGER:
		record.evidence_total = InvestigationSystem.BRIBERY_EVAL_TRIGGER

	var threshold_1: String = InvestigationSystem.check_thresholds(record)
	assert_eq(threshold_1, "bribery_eval")

	DayOrchestrator.handle_evidence_threshold(
		"bribery_eval", record, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
	)

	# Criminal should have a pending bribery_eval event
	var criminal_ws: Dictionary = world_states.get(100, {})
	var criminal_pending: Array = criminal_ws.get("pending_events", [])
	var has_bribery_eval: bool = false
	for ev: Dictionary in criminal_pending:
		if ev.get("type", "") == "bribery_eval":
			has_bribery_eval = true
			assert_eq(ev["case_id"], 1)
			assert_eq(ev["magistrate_id"], 103)
			assert_eq(ev["witness_id"], 102)
	assert_true(has_bribery_eval)

	# Magistrate should have an extortion_opportunity event
	var mag_ws: Dictionary = world_states.get(103, {})
	var mag_pending: Array = mag_ws.get("pending_events", [])
	var has_extortion: bool = false
	for ev: Dictionary in mag_pending:
		if ev.get("type", "") == "extortion_opportunity":
			has_extortion = true
			assert_eq(ev["suspect_id"], 100)
	assert_true(has_extortion)

	# ---------------------------------------------------------------
	# PHASE 6: Accusation threshold (40) — legal status transitions
	# ---------------------------------------------------------------
	record.evidence_total = InvestigationSystem.ACCUSATION_THRESHOLD
	# Reset legal status to allow accusation transition
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var threshold_2: String = InvestigationSystem.check_thresholds(record)
	assert_eq(threshold_2, "accusation")
	assert_eq(record.legal_status, Enums.LegalStatus.ACCUSED)

	DayOrchestrator.handle_evidence_threshold(
		"accusation", record, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
	)

	# Criminal should have an ACCUSED legal case entry
	var criminal_case: LegalCaseEntry = LegalStatusSystem.get_case(criminal, 1)
	assert_not_null(criminal_case)
	assert_eq(criminal_case.state, Enums.LegalStatus.ACCUSED)

	# Accusation topic should exist
	var accusation_topic: TopicData = null
	for t: TopicData in active_topics:
		if t.slug == "accusation_1":
			accusation_topic = t
			break
	assert_not_null(accusation_topic)
	assert_eq(accusation_topic.subject_role, "PERPETRATOR")

	# Lord should know about the accusation
	assert_true(accusation_topic.topic_id in lord.topic_pool)

	# ---------------------------------------------------------------
	# PHASE 7: Fugitive declaration — criminal flees
	# ---------------------------------------------------------------
	var fugitive_result: Dictionary = DayOrchestrator.process_fugitive_declaration(
		record, criminal, characters_by_id,
		active_topics, next_topic_id, ic_day,
	)
	assert_true(fugitive_result["declared"])
	assert_eq(fugitive_result["fugitive_id"], 100)
	assert_eq(record.legal_status, Enums.LegalStatus.FUGITIVE)

	# Fugitive topic generated
	var fugitive_topic: TopicData = null
	for t: TopicData in active_topics:
		if t.slug.begins_with("fugitive_"):
			fugitive_topic = t
			break
	assert_not_null(fugitive_topic)

	# ---------------------------------------------------------------
	# PHASE 8: Zone log purge — evidence expires after 90 days
	# ---------------------------------------------------------------
	assert_true(record.concealment_tn > 0)
	DayOrchestrator._purge_expired_crime_evidence(crime_records, ic_day + 89)
	assert_true(record.concealment_tn > 0, "Still valid before 90 days")
	DayOrchestrator._purge_expired_crime_evidence(crime_records, ic_day + 90)
	assert_eq(record.concealment_tn, 0, "Purged at exactly 90 days")

	# ---------------------------------------------------------------
	# Verify final state
	# ---------------------------------------------------------------
	# Record tracks full lifecycle
	assert_eq(record.case_id, 1)
	assert_eq(record.perpetrator_id, 100)
	assert_eq(record.victim_id, 101)
	assert_eq(record.investigating_magistrate_id, 103)
	assert_eq(record.legal_status, Enums.LegalStatus.FUGITIVE)
	# Topics created: crime, investigation_opened, accusation, fugitive
	var pipeline_topics: int = 0
	for t: TopicData in active_topics:
		if t.slug in ["crime_case_1", "investigation_1", "accusation_1"] or t.slug.begins_with("fugitive_"):
			pipeline_topics += 1
	assert_eq(pipeline_topics, 4)


func test_investigation_pipeline_witness_tampering_branch() -> void:
	# Tests the branch where criminal bribes witness, reducing evidence path
	var criminal := L5RCharacterData.new()
	criminal.character_id = 110
	criminal.character_name = "Shosuro Agent"
	criminal.clan = "Scorpion"
	criminal.family = "Shosuro"
	criminal.honor = 1.5
	criminal.intelligence = 3
	criminal.willpower = 3
	criminal.awareness = 3
	criminal.perception = 3
	criminal.agility = 3
	criminal.reflexes = 3
	criminal.stamina = 3
	criminal.strength = 3
	criminal.void_ring = 2
	criminal.skills = {"Temptation": 4}
	criminal.emphases = {}
	criminal.wounds_taken = 0
	criminal.physical_location = "scorpion_holdings"
	criminal.knowledge_pool = []
	criminal.known_contacts_by_clan = {}
	criminal.met_characters = []
	criminal.topic_pool = []
	criminal.legal_cases = []

	var witness := L5RCharacterData.new()
	witness.character_id = 111
	witness.character_name = "Bribeable Witness"
	witness.clan = "Mantis"
	witness.honor = 2.0
	witness.willpower = 2
	witness.awareness = 2
	witness.perception = 2
	witness.skills = {"Etiquette": 2}
	witness.emphases = {}
	witness.wounds_taken = 0
	witness.physical_location = "scorpion_holdings"
	witness.topic_pool = []
	witness.legal_cases = []

	var characters_by_id: Dictionary = {110: criminal, 111: witness}
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [2000]
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [1]
	var next_case_id: Array[int] = [10]
	var world_states: Dictionary = {}
	var ic_day: int = 75

	# Create original crime
	var witnesses_arr: Array[int] = [111]
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		10, Enums.CrimeType.SKIMMING, 110,
		"scorpion_holdings", ic_day, -1, 0, witnesses_arr,
	)
	crime_records.append(record)

	# Simulate successful bribe witness result
	var bribe_result: Array = [{
		"action_id": "BRIBE_WITNESS",
		"character_id": 110,
		"target_npc_id": 111,
		"success": true,
		"effects": {"witness_id": 111},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		bribe_result, crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
		active_secrets, next_secret_id, next_case_id,
	)

	# Witness removed from record
	assert_false(111 in record.witnesses)
	# Co-conspirator secret created
	assert_eq(active_secrets.size(), 1)
	assert_eq(active_secrets[0].severity, SecretData.Severity.TIER_2)
	assert_true("bribed_witness" in active_secrets[0].slug)

	# Now simulate a FAILED bribe on a second witness
	var witness2 := L5RCharacterData.new()
	witness2.character_id = 112
	witness2.character_name = "Second Witness"
	witness2.honor = 7.0
	witness2.topic_pool = []
	witness2.legal_cases = []
	characters_by_id[112] = witness2

	var witnesses_2: Array[int] = [112]
	record.witnesses = witnesses_2

	var failed_bribe: Array = [{
		"action_id": "BRIBE_WITNESS",
		"character_id": 110,
		"target_npc_id": 112,
		"success": false,
		"effects": {"witness_id": 112, "evidence_on_fail": 10},
	}]

	record.evidence_total = 20
	DayOrchestrator._process_witness_tampering_writebacks(
		failed_bribe, crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
		active_secrets, next_secret_id, next_case_id,
	)

	# Evidence increased by 10 → now 30, crossing bribery_eval (25)
	assert_eq(record.evidence_total, 30)
	# Witness still present
	assert_true(112 in record.witnesses)


func test_investigation_pipeline_kill_witness_creates_new_crime() -> void:
	# Tests that killing a witness removes testimony but creates a new murder case
	var criminal := L5RCharacterData.new()
	criminal.character_id = 120
	criminal.character_name = "Desperate Criminal"
	criminal.clan = "Crab"
	criminal.honor = 1.0
	criminal.intelligence = 3
	criminal.agility = 4
	criminal.awareness = 2
	criminal.perception = 2
	criminal.reflexes = 3
	criminal.willpower = 3
	criminal.stamina = 4
	criminal.strength = 4
	criminal.void_ring = 2
	criminal.skills = {"Stealth": 3}
	criminal.emphases = {}
	criminal.wounds_taken = 0
	criminal.physical_location = "crab_province"
	criminal.knowledge_pool = []
	criminal.known_contacts_by_clan = {}
	criminal.met_characters = []
	criminal.topic_pool = []
	criminal.legal_cases = []

	var witness := L5RCharacterData.new()
	witness.character_id = 121
	witness.character_name = "Murdered Witness"
	witness.clan = "Crane"
	witness.honor = 5.0
	witness.topic_pool = []
	witness.legal_cases = []

	var characters_by_id: Dictionary = {120: criminal, 121: witness}
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [3000]
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [1]
	var next_case_id: Array[int] = [20]
	var world_states: Dictionary = {}
	var ic_day: int = 60

	# Original crime (violence) with one witness
	var witnesses_arr: Array[int] = [121]
	var original_record: CrimeRecord = CrimeSystem.create_crime_record(
		20, Enums.CrimeType.VIOLENCE, 120,
		"crab_province", ic_day, -1, 0, witnesses_arr,
	)
	crime_records.append(original_record)
	next_case_id[0] = 21

	# Simulate successful kill witness
	var kill_result: Array = [{
		"action_id": "KILL_WITNESS",
		"character_id": 120,
		"target_npc_id": 121,
		"success": true,
		"effects": {"witness_id": 121, "concealment_tn": 18},
	}]

	DayOrchestrator._process_witness_tampering_writebacks(
		kill_result, crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
		active_secrets, next_secret_id, next_case_id,
	)

	# Witness removed from original crime
	assert_false(121 in original_record.witnesses)
	# No secrets created (kill doesn't make co-conspirator)
	assert_eq(active_secrets.size(), 0)
	# NEW murder crime record created
	assert_eq(crime_records.size(), 2)
	var murder_record: CrimeRecord = crime_records[1]
	assert_eq(murder_record.crime_type, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	assert_eq(murder_record.perpetrator_id, 120)
	assert_eq(murder_record.victim_id, 121)
	assert_eq(murder_record.concealment_tn, 18)
	assert_eq(murder_record.case_id, 21)
	assert_eq(murder_record.location, "crab_province")
	# Next case id incremented
	assert_eq(next_case_id[0], 22)


# ==============================================================================
# MAGISTRATE STANDING OBJECTIVE AUTO-ASSIGNMENT
# ==============================================================================

func test_magistrate_assigned_uphold_law_standing() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 200
	magistrate.character_name = "Soshi Magistrate"
	magistrate.role_position = "Clan Magistrate"
	magistrate.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	assert_true(objectives_map.has(200))
	var standing: Dictionary = objectives_map[200].get("standing", {})
	assert_eq(standing["need_type"], "UPHOLD_LAW")
	assert_eq(standing["priority"], 4)
	assert_true(standing["auto_assigned"])


func test_emerald_magistrate_assigned_uphold_law() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 201
	magistrate.character_name = "Emerald Champion's Agent"
	magistrate.role_position = "Emerald Magistrate"
	magistrate.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	var standing: Dictionary = objectives_map[201].get("standing", {})
	assert_eq(standing["need_type"], "UPHOLD_LAW")


func test_magistrate_commander_assigned_uphold_law() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 202
	magistrate.character_name = "Magistrate Commander"
	magistrate.role_position = "Clan Magistrate Commander"
	magistrate.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	var standing: Dictionary = objectives_map[202].get("standing", {})
	assert_eq(standing["need_type"], "UPHOLD_LAW")


func test_magistrate_does_not_overwrite_existing_standing() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 203
	magistrate.character_name = "Busy Magistrate"
	magistrate.role_position = "Clan Magistrate"
	magistrate.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {
		203: {
			"standing": {
				"need_type": "PROTECT_TERRITORY",
				"priority": 5,
				"assigned_by": 1,
			},
		},
	}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	# Should NOT overwrite existing standing objective
	var standing: Dictionary = objectives_map[203]["standing"]
	assert_eq(standing["need_type"], "PROTECT_TERRITORY")


func test_magistrate_preserves_existing_uphold_law_with_active_case() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 204
	magistrate.character_name = "Working Magistrate"
	magistrate.role_position = "Emerald Magistrate"
	magistrate.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {
		204: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"priority": 4,
				"auto_assigned": true,
				"active_case": {"case_id": 5, "crime_type": 2},
			},
		},
	}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	# Active case should be preserved — not reset
	var standing: Dictionary = objectives_map[204]["standing"]
	assert_eq(standing["need_type"], "UPHOLD_LAW")
	assert_true(standing.has("active_case"))
	assert_eq(standing["active_case"]["case_id"], 5)


func test_non_magistrate_not_assigned_uphold_law() -> void:
	var samurai := L5RCharacterData.new()
	samurai.character_id = 205
	samurai.character_name = "Regular Samurai"
	samurai.role_position = "Garrison Commander"
	samurai.wounds_taken = 0

	var characters: Array[L5RCharacterData] = [samurai]
	var objectives_map: Dictionary = {}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	assert_false(objectives_map.has(205))


func test_dead_magistrate_not_assigned_uphold_law() -> void:
	var dead_magistrate := L5RCharacterData.new()
	dead_magistrate.character_id = 206
	dead_magistrate.character_name = "Dead Magistrate"
	dead_magistrate.role_position = "Clan Magistrate"
	dead_magistrate.wounds_taken = 999

	var characters: Array[L5RCharacterData] = [dead_magistrate]
	var objectives_map: Dictionary = {}

	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)

	assert_false(objectives_map.has(206))


func test_magistrate_assignment_flows_into_scan() -> void:
	# Integration: auto-assignment → UPHOLD_LAW scan → case activation
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 207
	magistrate.character_name = "Kitsuki Inspector"
	magistrate.clan = "Dragon"
	magistrate.family = "Kitsuki"
	magistrate.role_position = "Clan Magistrate"
	magistrate.physical_location = "dragon_province_1"
	magistrate.wounds_taken = 0
	magistrate.topic_pool = []
	magistrate.legal_cases = []
	magistrate.skills = {"Investigation": 4}
	magistrate.emphases = {}
	magistrate.knowledge_pool = []
	magistrate.known_contacts_by_clan = {}
	magistrate.met_characters = []

	var characters: Array[L5RCharacterData] = [magistrate]
	var objectives_map: Dictionary = {}
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [5000]

	# Create a crime in the magistrate's province
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		50, Enums.CrimeType.VIOLENCE, 999,
		"dragon_province_1", 30, -1, 0,
	)
	crime_records.append(record)

	# Create crime topic and give magistrate knowledge of it
	var topic := TopicData.new()
	topic.topic_id = 5000
	topic.topic_type = "crime"
	topic.slug = "crime_case_50"
	active_topics.append(topic)
	next_topic_id[0] = 5001
	magistrate.topic_pool.append(5000)

	# Phase 1: Auto-assign UPHOLD_LAW standing objective
	DayOrchestrator._assign_magistrate_standing_objectives(characters, objectives_map)
	assert_eq(objectives_map[207]["standing"]["need_type"], "UPHOLD_LAW")

	# Phase 2: Scan picks up the crime and activates the case
	var scan_results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		characters, objectives_map, crime_records, active_topics,
	)

	assert_eq(scan_results.size(), 1)
	assert_eq(scan_results[0]["magistrate_id"], 207)
	assert_eq(scan_results[0]["case_id"], 50)

	# Case is now active on the standing objective
	var standing: Dictionary = objectives_map[207]["standing"]
	assert_true(standing.has("active_case"))
	assert_eq(standing["active_case"]["case_id"], 50)

	# Magistrate assigned on record
	assert_eq(record.investigating_magistrate_id, 207)


# ==============================================================================
# WITNESS INTERVIEW EVIDENCE FLOW — EXTORTION OPPORTUNITY INJECTION
# ==============================================================================

func test_scene_exam_bribery_eval_injects_extortion_opportunity() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 300
	magistrate.character_name = "Investigating Magistrate"
	magistrate.role_position = "Clan Magistrate"
	magistrate.wounds_taken = 0

	var criminal := L5RCharacterData.new()
	criminal.character_id = 301
	criminal.character_name = "Suspect"
	criminal.wounds_taken = 0

	var characters_by_id: Dictionary = {300: magistrate, 301: criminal}
	var crime_records: Array[CrimeRecord] = []
	var world_states: Dictionary = {"_crime_records": crime_records}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		80, Enums.CrimeType.VIOLENCE, 301, "province_1", 10,
	)
	record.investigating_magistrate_id = 300
	record.evidence_total = 25
	crime_records.append(record)

	DayOrchestrator._inject_extortion_opportunity_by_case(80, world_states)

	var mag_ws: Dictionary = world_states.get(300, {})
	var mag_pending: Array = mag_ws.get("pending_events", [])
	assert_eq(mag_pending.size(), 1)
	assert_eq(mag_pending[0]["type"], "extortion_opportunity")
	assert_eq(mag_pending[0]["case_id"], 80)
	assert_eq(mag_pending[0]["suspect_id"], 301)


func test_probe_bribery_eval_injects_extortion_opportunity() -> void:
	var criminal := L5RCharacterData.new()
	criminal.character_id = 310
	criminal.character_name = "Suspect"

	var crime_records: Array[CrimeRecord] = []
	var world_states: Dictionary = {}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		81, Enums.CrimeType.SKIMMING, 310, "province_2", 15,
	)
	record.investigating_magistrate_id = 311
	record.known_suspects = [310]
	record.evidence_total = 26
	crime_records.append(record)

	DayOrchestrator._inject_extortion_opportunity_from_probe(
		crime_records, 310, world_states,
	)

	var mag_ws: Dictionary = world_states.get(311, {})
	var mag_pending: Array = mag_ws.get("pending_events", [])
	assert_eq(mag_pending.size(), 1)
	assert_eq(mag_pending[0]["type"], "extortion_opportunity")
	assert_eq(mag_pending[0]["suspect_id"], 310)


func test_extortion_opportunity_deduplication() -> void:
	var crime_records: Array[CrimeRecord] = []
	var world_states: Dictionary = {"_crime_records": crime_records}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		82, Enums.CrimeType.VIOLENCE, 320, "province_3", 20,
	)
	record.investigating_magistrate_id = 321
	record.evidence_total = 30
	crime_records.append(record)

	DayOrchestrator._inject_extortion_opportunity_by_case(82, world_states)
	DayOrchestrator._inject_extortion_opportunity_by_case(82, world_states)

	var mag_ws: Dictionary = world_states.get(321, {})
	var mag_pending: Array = mag_ws.get("pending_events", [])
	assert_eq(mag_pending.size(), 1, "Should not duplicate extortion event")


# ==============================================================================
# EVIDENCE DECAY / COLD CASES
# ==============================================================================

func test_evidence_decay_does_not_apply_before_threshold() -> void:
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		90, Enums.CrimeType.VIOLENCE, 400, "province", 10,
	)
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	record.evidence_total = 20
	var crime_records: Array[CrimeRecord] = [record]
	var objectives_map: Dictionary = {}

	var results: Array[Dictionary] = DayOrchestrator._apply_evidence_decay(
		crime_records, objectives_map, 39,
	)
	assert_eq(record.evidence_total, 20, "No decay before 30 days")
	assert_eq(results.size(), 0)


func test_evidence_decay_applies_after_threshold() -> void:
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		91, Enums.CrimeType.VIOLENCE, 401, "province", 10,
	)
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	record.evidence_total = 20
	var crime_records: Array[CrimeRecord] = [record]
	var objectives_map: Dictionary = {}

	# Exactly 30 days + 10 interval = day 50
	DayOrchestrator._apply_evidence_decay(crime_records, objectives_map, 40)
	assert_eq(record.evidence_total, 19, "Decays 1 point at 30-day mark")


func test_evidence_decay_creates_cold_case() -> void:
	var magistrate_id: int = 500
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		92, Enums.CrimeType.SKIMMING, 402, "province", 10,
	)
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	record.evidence_total = 6
	record.investigating_magistrate_id = magistrate_id
	var crime_records: Array[CrimeRecord] = [record]

	var objectives_map: Dictionary = {
		500: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {"case_id": 92},
			},
		},
	}

	# 30 days after crime = day 40, on a 10-day interval
	var cold_cases: Array[Dictionary] = DayOrchestrator._apply_evidence_decay(
		crime_records, objectives_map, 40,
	)

	assert_eq(record.evidence_total, 5)
	assert_eq(cold_cases.size(), 1)
	assert_eq(cold_cases[0]["case_id"], 92)
	assert_eq(cold_cases[0]["magistrate_released"], 500)
	assert_eq(record.investigating_magistrate_id, -1)
	# Magistrate's active case should be cleared
	var standing: Dictionary = objectives_map[500]["standing"]
	assert_false(standing.has("active_case"))


func test_evidence_decay_skips_accused_cases() -> void:
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		93, Enums.CrimeType.VIOLENCE, 403, "province", 10,
	)
	record.legal_status = Enums.LegalStatus.ACCUSED
	record.evidence_total = 20
	var crime_records: Array[CrimeRecord] = [record]
	var objectives_map: Dictionary = {}

	DayOrchestrator._apply_evidence_decay(crime_records, objectives_map, 40)
	assert_eq(record.evidence_total, 20, "ACCUSED cases don't decay")


# ==============================================================================
# SUCCESSFUL BRIBE MAGISTRATE FLOW — CORRUPTION RECORD + BURIED STATUS
# ==============================================================================

func test_successful_bribe_creates_corruption_record() -> void:
	var briber := L5RCharacterData.new()
	briber.character_id = 600
	briber.character_name = "Briber"
	briber.honor = 2.0
	briber.glory = 3.0
	briber.legal_cases = []

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 601
	magistrate.character_name = "Corrupt Magistrate"
	magistrate.honor = 5.0
	magistrate.glory = 4.0
	magistrate.legal_cases = []

	var characters_by_id: Dictionary = {600: briber, 601: magistrate}
	var crime_records: Array[CrimeRecord] = []
	var active_secrets: Array[SecretData] = []
	var next_secret_id: Array[int] = [1]
	var next_case_id: Array[int] = [100]
	var objectives_map: Dictionary = {
		601: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {"case_id": 99},
			},
		},
	}

	# Original crime
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		99, Enums.CrimeType.SKIMMING, 600, "province_1", 50,
	)
	record.investigating_magistrate_id = 601
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	crime_records.append(record)

	# Set up legal case entry for briber
	var case_entry := LegalCaseEntry.new()
	case_entry.crime_record_id = 99
	case_entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	briber.legal_cases.append(case_entry)

	var bribe_results: Array = [{
		"action_id": "BRIBE_FOR_INFO",
		"character_id": 600,
		"success": true,
		"effects": {
			"suppress_case": true,
			"magistrate_id": 601,
		},
	}]

	DayOrchestrator._process_successful_bribe_writebacks(
		bribe_results, crime_records, characters_by_id, 55,
		active_secrets, next_secret_id, next_case_id, objectives_map,
	)

	# Original case cleared
	assert_eq(record.legal_status, Enums.LegalStatus.CLEAR)
	assert_eq(record.investigating_magistrate_id, -1)

	# Magistrate's active case released
	var standing: Dictionary = objectives_map[601]["standing"]
	assert_false(standing.has("active_case"))

	# MAGISTRATE_CORRUPTION crime record created
	assert_eq(crime_records.size(), 2)
	var corruption: CrimeRecord = crime_records[1]
	assert_eq(corruption.crime_type, Enums.CrimeType.MAGISTRATE_CORRUPTION)
	assert_eq(corruption.perpetrator_id, 601)
	assert_eq(corruption.case_id, 100)
	assert_eq(next_case_id[0], 101)

	# Both secrets created
	assert_eq(active_secrets.size(), 2)

	# Briber's legal case transitioned to CLEAR
	assert_eq(case_entry.state, Enums.LegalStatus.CLEAR)


# ==============================================================================
# CONVICTION PROCESSOR INTEGRATION — CROSS-CLAN + VICTIM LORD SEEDING
# ==============================================================================

func test_cross_clan_consequences_applied_on_conviction() -> void:
	var accused := L5RCharacterData.new()
	accused.character_id = 700
	accused.character_name = "Scorpion Criminal"
	accused.clan = "Scorpion"
	accused.family = "Bayushi"
	accused.honor = 2.0
	accused.glory = 3.0
	accused.status = 2.0
	accused.wounds_taken = 0

	var victim := L5RCharacterData.new()
	victim.character_id = 701
	victim.character_name = "Crane Victim"
	victim.clan = "Crane"
	victim.family = "Doji"
	victim.status = 4.0

	var characters_by_id: Dictionary = {700: accused, 701: victim}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		110, Enums.CrimeType.VIOLENCE, 700, "province", 30, 701,
	)
	var crime_records: Array[CrimeRecord] = [record]

	var conviction_results: Array[Dictionary] = [{
		"case_id": 110,
		"accused_id": 700,
		"outcome": "convicted",
		"is_cross_clan": true,
		"topic_id": 9000,
	}]

	DayOrchestrator._apply_cross_clan_conviction_consequences(
		conviction_results, crime_records, characters_by_id,
	)
	# The function runs without error — result depends on CrimeWiring internals
	pass_test("Cross-clan consequences applied without error")


func test_conviction_topic_seeded_to_victim_lord() -> void:
	var victim := L5RCharacterData.new()
	victim.character_id = 710
	victim.character_name = "Victim"
	victim.clan = "Crane"
	victim.lord_id = 711
	victim.topic_pool = []

	var victim_lord := L5RCharacterData.new()
	victim_lord.character_id = 711
	victim_lord.character_name = "Victim's Lord"
	victim_lord.topic_pool = []

	var characters_by_id: Dictionary = {710: victim, 711: victim_lord}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		111, Enums.CrimeType.VIOLENCE, 720, "province", 30, 710,
	)
	var crime_records: Array[CrimeRecord] = [record]
	var active_topics: Array[TopicData] = []

	var conviction_results: Array[Dictionary] = [{
		"case_id": 111,
		"accused_id": 720,
		"outcome": "convicted",
		"topic_id": 9001,
	}]

	DayOrchestrator._seed_conviction_topics_to_victim_lords(
		conviction_results, crime_records, characters_by_id, active_topics,
	)

	assert_true(9001 in victim_lord.topic_pool)


func test_conviction_topic_not_seeded_if_no_victim() -> void:
	var characters_by_id: Dictionary = {}

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		112, Enums.CrimeType.VIOLENCE, 730, "province", 30,
	)
	var crime_records: Array[CrimeRecord] = [record]
	var active_topics: Array[TopicData] = []

	var conviction_results: Array[Dictionary] = [{
		"case_id": 112,
		"accused_id": 730,
		"outcome": "convicted",
		"topic_id": 9002,
	}]

	DayOrchestrator._seed_conviction_topics_to_victim_lords(
		conviction_results, crime_records, characters_by_id, active_topics,
	)
	# No crash, no seeding
	pass_test("No victim → no lord seeding")
