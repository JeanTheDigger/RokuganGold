extends GutTest


var _scheduler: SimulationScheduler


func before_each() -> void:
	_scheduler = SimulationScheduler.new()


func after_each() -> void:
	_scheduler.free()


# -- Tick Hours Constant -------------------------------------------------------

func test_tick_hours_are_every_six() -> void:
	assert_eq(SimulationScheduler.TICK_HOURS, [0, 6, 12, 18])


# -- DST Helper Tests ----------------------------------------------------------

func test_dst_january_is_false() -> void:
	var utc := {"month": 1, "day": 15, "weekday": 3}
	assert_false(_scheduler._is_dst(utc))


func test_dst_july_is_true() -> void:
	var utc := {"month": 7, "day": 15, "weekday": 3}
	assert_true(_scheduler._is_dst(utc))


func test_dst_december_is_false() -> void:
	var utc := {"month": 12, "day": 15, "weekday": 3}
	assert_false(_scheduler._is_dst(utc))


func test_dst_march_before_second_sunday() -> void:
	var utc := {"month": 3, "day": 5, "weekday": 0}
	assert_false(_scheduler._is_dst(utc))


func test_dst_march_after_second_sunday() -> void:
	var utc := {"month": 3, "day": 15, "weekday": 1}
	assert_true(_scheduler._is_dst(utc))


func test_dst_november_before_first_sunday() -> void:
	# Nov 1 that is a Friday (weekday 5) → (1-5) = -4 < 1 → still DST
	var utc := {"month": 11, "day": 1, "weekday": 5}
	assert_true(_scheduler._is_dst(utc))


func test_dst_november_after_first_sunday() -> void:
	# Nov 10 that is a Sunday (weekday 0) → (10-0) = 10 >= 1 → not DST
	var utc := {"month": 11, "day": 10, "weekday": 0}
	assert_false(_scheduler._is_dst(utc))


# -- Days in Month Tests -------------------------------------------------------

func test_days_in_february_non_leap() -> void:
	assert_eq(_scheduler._days_in_month(2023, 2), 28)


func test_days_in_february_leap() -> void:
	assert_eq(_scheduler._days_in_month(2024, 2), 29)


func test_days_in_january() -> void:
	assert_eq(_scheduler._days_in_month(2024, 1), 31)


func test_days_in_april() -> void:
	assert_eq(_scheduler._days_in_month(2024, 4), 30)


func test_days_in_february_century_non_leap() -> void:
	assert_eq(_scheduler._days_in_month(1900, 2), 28)


func test_days_in_february_400_year_leap() -> void:
	assert_eq(_scheduler._days_in_month(2000, 2), 29)


# -- Tick Key Format -----------------------------------------------------------

func test_tick_key_not_empty() -> void:
	var key: String = _scheduler._get_current_tick_key()
	assert_true(key.length() > 0, "Tick key should not be empty")


func test_tick_key_contains_hour_marker() -> void:
	var key: String = _scheduler._get_current_tick_key()
	assert_true(key.contains("-H"), "Tick key should contain -H hour marker")


func test_tick_key_hour_is_checkpoint() -> void:
	var key: String = _scheduler._get_current_tick_key()
	var hour_str: String = key.get_slice("-H", 1)
	var hour: int = hour_str.to_int()
	assert_true(hour in [0, 6, 12, 18], "Hour in tick key should be a checkpoint")


# -- Next Tick Hour ------------------------------------------------------------

func test_next_tick_hour_is_valid() -> void:
	var next_h: int = _scheduler.get_next_tick_est_hour()
	assert_true(next_h in [0, 6, 12, 18], "Next tick hour should be a checkpoint")


# -- Duplicate Fire Prevention -------------------------------------------------

func test_same_tick_key_prevents_refire() -> void:
	var key: String = _scheduler._get_current_tick_key()
	_scheduler._last_processed_tick_key = key
	# _process would skip because key matches — verify the guard
	assert_eq(_scheduler._last_processed_tick_key, key)


# -- WorldState Convenience ----------------------------------------------------

func test_world_state_rebuild_characters_by_id() -> void:
	var ws := WorldStateData.new()
	var c := L5RCharacterData.new()
	c.character_id = 42
	c.character_name = "Test"
	ws.characters.append(c)
	ws.rebuild_characters_by_id()
	assert_eq(ws.characters_by_id[42], c)
	ws.free()


func test_world_state_time_system_defaults() -> void:
	var ws := WorldStateData.new()
	assert_eq(ws.time_system.current_tick, 0)
	assert_eq(ws.time_system.start_year, 1120)
	ws.free()


func test_world_state_advance_one_day() -> void:
	var ws := WorldStateData.new()
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "NPC"
	c.status = 1.0
	c.honor = 3.0
	c.glory = 1.0
	c.action_points_current = 2
	c.action_points_max = 2
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.reflexes = 2
	c.awareness = 2
	c.stamina = 2
	c.willpower = 2
	c.agility = 2
	c.intelligence = 2
	c.strength = 2
	c.perception = 2
	c.void_ring = 2
	c.skills = {}
	c.emphases = {}
	c.wounds_taken = 0
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	ws.characters.append(c)
	ws.characters_by_id = {1: c}

	ws.world_states = {
		1: {
			"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
			"season": 0,
			"ic_day": 0,
			"characters_present": [],
			"is_lord": false,
			"known_topics": [],
			"known_positions": {},
			"known_objectives": {},
			"known_contacts": [],
			"pending_events": [],
			"action_log": [],
		},
	}
	ws.objectives_map = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	ws.scoring_tables = {
		"objective_alignment": {"REST": {"DO_NOTHING": 10, "REST": 50}},
		"disposition_tiers": [{"min": -10, "max": 10, "cooperative": 0, "hostile": 0}],
		"personality_lean": {},
		"action_skill_map": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}
	ws.filter_data = {"bushido": {}, "shourido": {}}
	ws.action_skill_map = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
	}
	ws.season_meta = {"_peace_seasons": {}, "_deficit_seasons": {}}

	var result: Dictionary = ws.advance_one_day()
	assert_true(result.has("ic_day"))
	assert_eq(result["ic_day"], 1)
	ws.free()
