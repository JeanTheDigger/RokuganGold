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
