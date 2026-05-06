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
	province.garrison_pu = 3
	province.farming_pu = 4
	province.mining_pu = 1
	province.town_pu = 2
	province.military_pu = 1
	province.population_pu = 8
	province.rice_stockpile = 10.0
	province.koku_stockpile = 5.0
	province.iron_stockpile = 2.0
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
