extends GutTest
## Tests for naval system wiring into DayOrchestrator.
## Covers: daily weather rolls, ship movement ticks, deep ocean loss,
## naval battle triggers, post-battle ship mutations, naval war scores,
## naval topic generation.


var _char: L5RCharacterData
var _scoring_tables: Dictionary
var _filter_data: Dictionary
var _action_skill_map: Dictionary


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.character_name = "Test NPC"
	_char.clan = "Crane"
	_char.family = "Doji"
	_char.school_type = Enums.SchoolType.COURTIER
	_char.bushido_virtue = Enums.BushidoVirtue.NONE
	_char.shourido_virtue = Enums.ShouridoVirtue.NONE
	_char.honor = 5.0
	_char.glory = 3.0
	_char.status = 4.0
	_char.skills = {"Courtier": 3, "Etiquette": 3}
	_char.emphases = {}
	_char.reflexes = 3
	_char.awareness = 3
	_char.stamina = 3
	_char.willpower = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.strength = 3
	_char.perception = 3
	_char.void_ring = 2
	_char.wounds_taken = 0
	_char.knowledge_pool = []
	_char.known_contacts_by_clan = {}
	_char.met_characters = []
	ActionPointSystem.reset_daily_ap(_char)

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
		"TRAIN": {"primary": "Battle", "secondary": "Agility"},
	}


func _make_world_state() -> Dictionary:
	return {
		"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
		"season": 1,
		"ic_day": 1,
		"characters_present": [],
		"is_lord": false,
		"known_topics": [],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [],
		"pending_events": [],
		"action_log": [],
	}


func _make_province() -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 10
	p.stability = 70.0
	p.terrain_type = Enums.TerrainType.PLAINS
	return p


func _make_season_meta() -> Dictionary:
	return {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}


func _run_advance_day(
	ships: Array = [],
	active_wars: Array = [],
	extra_chars: Array = [],
) -> Dictionary:
	var time := TimeSystem.new(1120, 0)
	var dice := DiceEngine.new()
	dice.set_seed(42)

	var province: ProvinceData = _make_province()
	var all_chars: Array = [_char]
	all_chars.append_array(extra_chars)
	var chars_by_id: Dictionary = {}
	for c: L5RCharacterData in all_chars:
		chars_by_id[c.character_id] = c

	var ws: Dictionary = _make_world_state()
	var world_states: Dictionary = {}
	for c: L5RCharacterData in all_chars:
		world_states[c.character_id] = ws.duplicate()

	var objectives: Dictionary = {}
	for c: L5RCharacterData in all_chars:
		objectives[c.character_id] = {"primary": {"need_type": "REST", "priority": 3}}

	return DayOrchestrator.advance_day(
		time,                                  # time_system
		all_chars,                             # characters
		chars_by_id,                           # characters_by_id
		world_states,                          # world_states
		objectives,                            # objectives_map
		_scoring_tables,                       # scoring_tables
		_filter_data,                          # filter_data
		dice,                                  # dice_engine
		_action_skill_map,                     # action_skill_map
		{10: province},                        # provinces
		[],               # action_log
		_make_season_meta(),                   # season_meta
		[],                # active_topics
		[],                                    # pending_letters
		[],               # approach_penalties
		[],           # commitments
		[],              # crime_records
		[1],                                   # next_case_id
		{},                                    # military_data
		{},                                    # character_province_map
		[1000],                                # next_topic_id
		[],               # death_events
		{},                                    # successor_map
		[],                                    # favors
		[],           # insurgencies
		[1],                                   # next_insurgency_id
		[],           # settlements
		{},                                    # miya_inputs
		[],           # active_successions
		[1],                                   # next_succession_id
		[],               # entanglements
		[],               # bound_states
		[],               # active_armies
		[],               # active_sieges
		[],               # active_tethers
		[],               # order_states
		[],               # companies
		{},                                    # clans
		active_wars,                           # active_wars
		[],                                    # trade_routes
		[1],                                   # next_war_id
		[],         # active_courts
		[1],                                   # next_court_id
		[],                # active_edicts
		[1],                                   # next_edict_id
		[],                # active_hordes
		{},                                    # horde_strength_counters
		[-1],                                  # last_targeted_province_id
		ships,                                 # ships
	)


# =============================================================================
# Weather Processing
# =============================================================================

func test_advance_day_returns_naval_weather() -> void:
	var result: Dictionary = _run_advance_day()
	assert_true(result.has("naval_weather"))
	var w: int = result["naval_weather"]
	assert_true(w >= 0 and w <= 4, "Weather should be a valid NavalWeather enum")


func test_naval_weather_stored_in_season_meta() -> void:
	var time := TimeSystem.new(1120, 0)
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var season_meta: Dictionary = _make_season_meta()

	var weather: int = DayOrchestrator._process_naval_weather(dice, "spring", season_meta)
	assert_true(season_meta.has("current_naval_weather"))
	assert_eq(season_meta["current_naval_weather"], weather)


func test_naval_weather_valid_range() -> void:
	var dice := DiceEngine.new()
	var season_meta: Dictionary = {}
	for i: int in range(50):
		dice.set_seed(i)
		var w: int = DayOrchestrator._process_naval_weather(dice, "autumn", season_meta)
		assert_true(w >= Enums.NavalWeather.CLEAR and w <= Enums.NavalWeather.TYPHOON)


# =============================================================================
# Ship Movement
# =============================================================================

func test_ship_movement_decrements_days() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship.is_moving = true
	ship.destination_subtile_id = 5
	ship.movement_days_remaining = 3
	ship.current_subtile_id = 1

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var results: Array = DayOrchestrator._process_ship_movement(
		[ship], dice,
	)
	assert_eq(results.size(), 1)
	assert_false(results[0]["arrived"])
	assert_eq(ship.movement_days_remaining, 2)


func test_ship_movement_arrives_at_destination() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship.is_moving = true
	ship.destination_subtile_id = 5
	ship.movement_days_remaining = 1
	ship.current_subtile_id = 1

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var results: Array = DayOrchestrator._process_ship_movement(
		[ship], dice,
	)
	assert_eq(results.size(), 1)
	assert_true(results[0]["arrived"])
	assert_eq(ship.current_subtile_id, 5)
	assert_false(ship.is_moving)
	assert_eq(ship.destination_subtile_id, -1)


func test_ship_movement_skips_destroyed_ships() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship.is_destroyed = true
	ship.is_moving = true
	ship.movement_days_remaining = 1

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_ship_movement(
		[ship], dice,
	)
	assert_eq(results.size(), 0)


func test_ship_movement_skips_captured_ships() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship.is_captured = true
	ship.is_moving = true
	ship.movement_days_remaining = 1

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_ship_movement(
		[ship], dice,
	)
	assert_eq(results.size(), 0)


func test_ship_movement_skips_stationary_ships() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship.is_moving = false

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_ship_movement(
		[ship], dice,
	)
	assert_eq(results.size(), 0)


func test_deep_ocean_loss_possible_for_kobune() -> void:
	var lost_count: int = 0
	for seed_val: int in range(200):
		var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
		ship.is_moving = true
		ship.destination_subtile_id = 99
		ship.movement_days_remaining = 1
		ship.current_subtile_id = 1

		var dice := DiceEngine.new()
		dice.set_seed(seed_val)
		DayOrchestrator._process_ship_movement([ship], dice)
		if ship.is_destroyed:
			lost_count += 1

	assert_true(lost_count > 0, "At least some Kobune should be lost to deep ocean")
	assert_true(lost_count < 200, "Not all Kobune should be lost")


func test_no_deep_ocean_loss_for_sengokobune() -> void:
	for seed_val: int in range(50):
		var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Mantis")
		ship.is_moving = true
		ship.destination_subtile_id = 99
		ship.movement_days_remaining = 1
		ship.current_subtile_id = 1

		var dice := DiceEngine.new()
		dice.set_seed(seed_val)
		DayOrchestrator._process_ship_movement([ship], dice)
		assert_false(ship.is_destroyed)


# =============================================================================
# Naval Battle Triggers
# =============================================================================

func test_no_battle_without_hostile_ships() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.KOBUNE, "Crane")
	ship_b.current_subtile_id = 5

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


func test_no_battle_without_war() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.KOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.KOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


func test_battle_triggers_when_hostile_ships_at_same_subtile() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	dice.set_seed(42)
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 1)
	assert_true(results[0].has("victor"))


func test_no_battle_for_ships_at_different_subtiles() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 6

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


func test_moving_ships_excluded_from_battle_triggers() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5
	ship_b.is_moving = true

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


func test_destroyed_ships_excluded_from_battle_triggers() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5
	ship_b.is_destroyed = true

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


func test_docked_ships_excluded_from_battle_triggers() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = -1
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = -1

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true

	var dice := DiceEngine.new()
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		[ship_a, ship_b], {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 0)


# =============================================================================
# Post-Battle Ship Mutations
# =============================================================================

func test_battle_mutations_update_ship_health() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	dice.set_seed(42)

	var ships: Array = [ship_a, ship_b]
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		ships, {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	assert_eq(results.size(), 1)

	DayOrchestrator._apply_naval_battle_mutations(results, ships, {})

	var any_damaged: bool = ship_a.health < ship_a.max_health or ship_b.health < ship_b.max_health
	assert_true(any_damaged, "At least one ship should take damage")


func test_battle_mutations_mark_destroyed_ships() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	ship_a.health = 1
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	dice.set_seed(42)

	var ships: Array = [ship_a, ship_b]
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		ships, {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	DayOrchestrator._apply_naval_battle_mutations(results, ships, {})

	assert_true(ship_a.is_destroyed or ship_b.is_destroyed,
		"Ship with 1 HP should be destroyed or the other via combat")


func test_battle_mutations_handle_captured_ships() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.MERCHANT_BARGE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	dice.set_seed(42)

	var ships: Array = [ship_a, ship_b]
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		ships, {}, [war], Enums.NavalWeather.CLEAR, dice,
	)
	DayOrchestrator._apply_naval_battle_mutations(results, ships, {})

	assert_true(ship_a.is_captured, "Merchant Barge should auto-surrender and be captured")
	assert_eq(ship_a.captured_by_clan, "Mantis")


func test_captain_death_clears_ship_captain() -> void:
	var captain := L5RCharacterData.new()
	captain.character_id = 100
	captain.character_name = "Captain Test"
	captain.clan = "Crane"
	captain.skills = {"Battle": 1}
	captain.stamina = 2
	captain.willpower = 2
	captain.reflexes = 2
	captain.awareness = 2
	captain.agility = 2
	captain.intelligence = 2
	captain.strength = 2
	captain.perception = 2
	captain.void_ring = 2

	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	ship_a.captain_id = 100
	ship_a.health = 1
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.ATAKEBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var dice := DiceEngine.new()
	dice.set_seed(42)

	var ships: Array = [ship_a, ship_b]
	var chars_by_id: Dictionary = {100: captain}
	var results: Array = DayOrchestrator._process_naval_battle_triggers(
		ships, chars_by_id, [war], Enums.NavalWeather.CLEAR, dice,
	)
	DayOrchestrator._apply_naval_battle_mutations(results, ships, chars_by_id)

	var captain_deaths: Array = results[0].get("captain_deaths", [])
	var any_died: bool = false
	for cd: Dictionary in captain_deaths:
		if cd.get("died", false):
			any_died = true
	if any_died:
		assert_eq(ship_a.captain_id, -1, "Dead captain should be cleared from ship")


# =============================================================================
# Naval War Score Shifts
# =============================================================================

func test_naval_war_score_shift_on_battle() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var battle_result: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
		"attacker_states": [{}, {}],
		"defender_states": [{}, {}],
	}

	var results: Array = DayOrchestrator._process_naval_war_scores(
		[battle_result], [war],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["winning_clan"], "Crane")
	assert_true(results[0]["shift"] > 0)
	assert_true(war.war_score_a > 50, "Winner's war score should increase")


func test_naval_war_score_no_shift_on_draw() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var battle_result: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "draw",
		"attacker_states": [{}],
		"defender_states": [{}],
	}

	var results: Array = DayOrchestrator._process_naval_war_scores(
		[battle_result], [war],
	)
	assert_eq(results.size(), 0)
	assert_eq(war.war_score_a, 50)


func test_naval_battle_size_classification() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var small_battle: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
		"attacker_states": [{}],
		"defender_states": [{}],
	}

	var results: Array = DayOrchestrator._process_naval_war_scores(
		[small_battle], [war],
	)
	assert_eq(results[0]["event"], "minor_battle")


func test_naval_major_battle_classification() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var states: Array = [{}, {}, {}, {}]
	var battle: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
		"attacker_states": states.duplicate(),
		"defender_states": [{}],
	}

	var results: Array = DayOrchestrator._process_naval_war_scores(
		[battle], [war],
	)
	assert_true(results[0]["event"] == "major_battle" or results[0]["event"] == "decisive_battle")


# =============================================================================
# Naval Topic Generation
# =============================================================================

func test_naval_battle_generates_topic() -> void:
	var active_topics: Array = []
	var next_topic_id: Array = [100]

	var battle_result: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
	}

	var topics: Array = DayOrchestrator._generate_naval_battle_topics(
		[battle_result], active_topics, next_topic_id, 10,
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "military")
	assert_eq(topics[0].variant, "naval_battle")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_3)
	assert_eq(topics[0].category, TopicData.Category.MILITARY)
	assert_eq(topics[0].momentum, TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_3))
	assert_eq(next_topic_id[0], 101)


func test_naval_battle_topic_added_to_active_topics() -> void:
	var active_topics: Array = []
	var next_topic_id: Array = [100]

	var battle_result: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "draw",
	}

	DayOrchestrator._generate_naval_battle_topics(
		[battle_result], active_topics, next_topic_id, 10,
	)
	assert_eq(active_topics.size(), 1)


func test_multiple_naval_battles_generate_multiple_topics() -> void:
	var active_topics: Array = []
	var next_topic_id: Array = [100]

	var battle_a: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
	}
	var battle_b: Dictionary = {
		"attacker_clan": "Crab",
		"defender_clan": "Lion",
		"victor": "defender",
	}

	var topics: Array = DayOrchestrator._generate_naval_battle_topics(
		[battle_a, battle_b], active_topics, next_topic_id, 10,
	)
	assert_eq(topics.size(), 2)
	assert_eq(active_topics.size(), 2)
	assert_eq(next_topic_id[0], 102)


func test_naval_topic_slug_format() -> void:
	var active_topics: Array = []
	var next_topic_id: Array = [100]

	var battle: Dictionary = {
		"attacker_clan": "Crane",
		"defender_clan": "Mantis",
		"victor": "attacker",
	}

	var topics: Array = DayOrchestrator._generate_naval_battle_topics(
		[battle], active_topics, next_topic_id, 42,
	)
	assert_eq(topics[0].slug, "naval_battle_crane_vs_mantis_d42")


# =============================================================================
# Hostile Pair Detection
# =============================================================================

func test_find_hostile_pairs_with_war() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true

	var clans_at: Dictionary = {
		"Crane": [],
		"Mantis": [],
	}

	var pairs: Array = DayOrchestrator._find_hostile_naval_pairs(
		clans_at, [war],
	)
	assert_eq(pairs.size(), 1)
	assert_eq(pairs[0][0], "Crane")
	assert_eq(pairs[0][1], "Mantis")


func test_find_hostile_pairs_no_war() -> void:
	var clans_at: Dictionary = {
		"Crane": [],
		"Mantis": [],
	}

	var pairs: Array = DayOrchestrator._find_hostile_naval_pairs(clans_at, [])
	assert_eq(pairs.size(), 0)


func test_find_hostile_pairs_same_clan() -> void:
	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true

	var clans_at: Dictionary = {
		"Crane": [],
	}

	var pairs: Array = DayOrchestrator._find_hostile_naval_pairs(
		clans_at, [war],
	)
	assert_eq(pairs.size(), 0)


# =============================================================================
# Captain Bonus Computation
# =============================================================================

func test_compute_captain_bonus_attack() -> void:
	var captain := L5RCharacterData.new()
	captain.character_id = 10
	captain.skills = {"Battle": 4}
	captain.stamina = 2
	captain.willpower = 2
	captain.reflexes = 2
	captain.awareness = 2
	captain.agility = 4
	captain.intelligence = 4
	captain.strength = 2
	captain.perception = 2
	captain.void_ring = 2

	var bonus: Dictionary = DayOrchestrator._compute_captain_bonus(captain)
	assert_true(bonus.has("bonus_type"))
	assert_true(bonus.has("bonus_value"))
	assert_eq(bonus["bonus_value"], 4)


func test_compute_captain_bonus_no_battle_skill() -> void:
	var captain := L5RCharacterData.new()
	captain.character_id = 10
	captain.skills = {}
	captain.stamina = 3
	captain.willpower = 3
	captain.reflexes = 3
	captain.awareness = 3
	captain.agility = 3
	captain.intelligence = 3
	captain.strength = 3
	captain.perception = 3
	captain.void_ring = 2

	var bonus: Dictionary = DayOrchestrator._compute_captain_bonus(captain)
	assert_true(bonus.is_empty())


# =============================================================================
# Full Integration: advance_day with Ships
# =============================================================================

func test_advance_day_returns_naval_results() -> void:
	var result: Dictionary = _run_advance_day()
	assert_true(result.has("naval_weather"))
	assert_true(result.has("naval_movement_results"))
	assert_true(result.has("naval_battle_results"))
	assert_true(result.has("naval_topics"))


func test_advance_day_with_moving_ship() -> void:
	var ship: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship.is_moving = true
	ship.destination_subtile_id = 5
	ship.movement_days_remaining = 2
	ship.current_subtile_id = 1

	var result: Dictionary = _run_advance_day([ship])
	assert_eq(result["naval_movement_results"].size(), 1)
	assert_false(result["naval_movement_results"][0]["arrived"])
	assert_eq(ship.movement_days_remaining, 1)


func test_advance_day_with_no_ships() -> void:
	var result: Dictionary = _run_advance_day()
	assert_eq(result["naval_movement_results"].size(), 0)
	assert_eq(result["naval_battle_results"].size(), 0)
	assert_eq(result["naval_topics"].size(), 0)


# =============================================================================
# s57.18 Naval NPC Connection
# =============================================================================

func _make_ctx_with_naval(
	has_naval_assets: bool,
	has_pirate_province: bool,
	province_stability: float = 60.0,
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = true
	ctx.has_naval_assets = has_naval_assets
	ctx.is_coastal = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.resource_stockpiles = {"rice": 100.0, "population_pu": 10.0}

	if has_pirate_province:
		var ps := NPCDataStructures.ProvinceStatus.new()
		ps.province_id = 42
		ps.stability = province_stability
		ps.active_insurgency_id = 1
		ps.insurgency_type = "PIRATE_FLEET"
		ps.garrison_pu = 2
		ps.confidence = NPCDataStructures.ProvinceStatus.CONFIDENCE_RECENT
		ctx.province_statuses.append(ps)

	return ctx


func test_ctx_snapshot_has_naval_assets_field() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.has_naval_assets = true
	assert_true(ctx.has_naval_assets)
	ctx.has_naval_assets = false
	assert_false(ctx.has_naval_assets)


func test_province_status_has_insurgency_type_field() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.insurgency_type = "PIRATE_FLEET"
	assert_eq(ps.insurgency_type, "PIRATE_FLEET")


func test_build_province_statuses_populates_insurgency_type() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.active_insurgency_id = 5

	var ins := InsurgencyData.new()
	ins.province_id = 10
	ins.insurgency_type = Enums.InsurgencyType.PIRATE_FLEET

	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [], [ins],
	)
	assert_eq(result.size(), 1)
	var ps: NPCDataStructures.ProvinceStatus = result[0]
	assert_eq(ps.insurgency_type, "PIRATE_FLEET")


func test_build_province_statuses_no_insurgency_leaves_type_empty() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10

	var result: Array = NPCDecisionEngine.build_province_statuses_from_data([pd])
	assert_eq(result.size(), 1)
	assert_eq((result[0] as NPCDataStructures.ProvinceStatus).insurgency_type, "")


func test_s57_18_1_deploy_army_when_pirate_fleet_and_has_ships() -> void:
	var ctx := _make_ctx_with_naval(true, true, 60.0)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer._decompose_protect_dependents(
		{}, ctx,
	)
	assert_eq(need.need_type, "DEPLOY_ARMY",
		"Lord with ships vs pirate fleet should DEPLOY_ARMY")
	assert_eq(need.target_intent, "SUPPRESS_PIRACY")
	assert_eq(need.target_province_id, 42)


func test_s57_18_1_request_aid_when_pirate_fleet_and_no_ships() -> void:
	var ctx := _make_ctx_with_naval(false, true, 60.0)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer._decompose_protect_dependents(
		{}, ctx,
	)
	assert_eq(need.need_type, "REQUEST_AID",
		"Lord without ships vs pirate fleet should REQUEST_AID")
	assert_eq(need.target_intent, "naval_suppression")


func test_s57_18_1_no_pirate_fleet_gives_patrol_province() -> void:
	var ctx := _make_ctx_with_naval(true, false)
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 99
	ps.stability = 60.0
	ps.active_insurgency_id = -1
	ps.insurgency_type = ""
	ps.garrison_pu = 2
	ps.confidence = NPCDataStructures.ProvinceStatus.CONFIDENCE_RECENT
	ctx.province_statuses.append(ps)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer._decompose_protect_dependents(
		{}, ctx,
	)
	assert_eq(need.need_type, "PATROL_PROVINCE",
		"Non-pirate unstable province should still give PATROL_PROVINCE")


func test_s57_18_2_patrol_province_allowed_with_ships() -> void:
	# ProvinceTriage returns PATROL_PROVINCE for stability <= 50
	var ctx := _make_ctx_with_naval(true, true, 40.0)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer._decompose_defend_territory(
		{}, ctx,
	)
	assert_eq(need.need_type, "PATROL_PROVINCE",
		"Lord with ships should be allowed to PATROL_PROVINCE even for pirate threat")


func test_s57_18_2_write_letter_when_no_ships_for_pirate_patrol() -> void:
	# ProvinceTriage returns PATROL_PROVINCE for stability <= 50
	var ctx := _make_ctx_with_naval(false, true, 40.0)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer._decompose_defend_territory(
		{}, ctx,
	)
	assert_eq(need.need_type, "SEND_LETTER",
		"Lord without ships cannot patrol pirate waters — should SEND_LETTER")
	assert_eq(need.target_intent, "report_piracy")


func test_province_has_pirate_fleet_helper_true_case() -> void:
	var ctx := _make_ctx_with_naval(false, true)
	assert_true(ObjectiveDecomposer._province_has_pirate_fleet_insurgency(42, ctx))


func test_province_has_pirate_fleet_helper_false_case() -> void:
	var ctx := _make_ctx_with_naval(false, false)
	assert_false(ObjectiveDecomposer._province_has_pirate_fleet_insurgency(42, ctx))


func test_advance_day_naval_battle_with_war() -> void:
	var ship_a: ShipData = NavalSystem.create_ship(1, Enums.ShipClass.SENGOKOBUNE, "Crane")
	ship_a.current_subtile_id = 5
	var ship_b: ShipData = NavalSystem.create_ship(2, Enums.ShipClass.SENGOKOBUNE, "Mantis")
	ship_b.current_subtile_id = 5

	var war := WarData.new()
	war.war_id = 1
	war.clan_a = "Crane"
	war.clan_b = "Mantis"
	war.is_active = true
	war.war_score_a = 50
	war.war_score_b = 50

	var result: Dictionary = _run_advance_day(
		[ship_a, ship_b],
		[war],
	)

	assert_true(result["naval_battle_results"].size() > 0)
	assert_true(result["naval_topics"].size() > 0)
	var any_damaged: bool = ship_a.health < ship_a.max_health or ship_b.health < ship_b.max_health
	assert_true(any_damaged, "Ships should be damaged after battle")
