extends GutTest
## Tests for TravelSystem per GDD s55.29.


func _make_character(id: int, location: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = location
	return c


# -- Distance Lookup -----------------------------------------------------------

func test_set_and_get_distance() -> void:
	TravelSystem.clear_distances()
	TravelSystem.set_distance("castle_a", "castle_b", 5)
	assert_eq(TravelSystem.get_travel_time("castle_a", "castle_b"), 5)
	assert_eq(TravelSystem.get_travel_time("castle_b", "castle_a"), 5)


func test_unknown_distance_returns_default() -> void:
	TravelSystem.clear_distances()
	assert_eq(TravelSystem.get_travel_time("unknown_a", "unknown_b"), 3)


func test_same_location_returns_zero() -> void:
	assert_eq(TravelSystem.get_travel_time("same", "same"), 0)


func test_clear_distances() -> void:
	TravelSystem.clear_distances()
	TravelSystem.set_distance("a", "b", 7)
	TravelSystem.clear_distances()
	assert_eq(TravelSystem.get_travel_time("a", "b"), 3)


# -- begin_travel --------------------------------------------------------------

func test_begin_travel_sets_fields() -> void:
	TravelSystem.clear_distances()
	TravelSystem.set_distance("town_a", "town_b", 4)
	var c := _make_character(1, "town_a")
	var result: Dictionary = TravelSystem.begin_travel(c, "town_b")
	assert_true(result["started"])
	assert_eq(result["travel_days"], 4)
	assert_eq(c.travel_destination, "town_b")
	assert_eq(c.travel_origin, "town_a")
	assert_eq(c.travel_days_remaining, 4)


func test_begin_travel_already_there() -> void:
	var c := _make_character(1, "town_a")
	var result: Dictionary = TravelSystem.begin_travel(c, "town_a")
	assert_false(result["started"])
	assert_eq(result["reason"], "already_there")


func test_begin_travel_no_destination() -> void:
	var c := _make_character(1, "town_a")
	var result: Dictionary = TravelSystem.begin_travel(c, "")
	assert_false(result["started"])
	assert_eq(result["reason"], "no_destination")


func test_begin_travel_minimum_days() -> void:
	TravelSystem.clear_distances()
	var c := _make_character(1, "nearby_a")
	var result: Dictionary = TravelSystem.begin_travel(c, "nearby_b")
	assert_true(result["started"])
	assert_true(result["travel_days"] >= TravelSystem.MINIMUM_TRAVEL_DAYS)


# -- is_traveling --------------------------------------------------------------

func test_is_traveling_true() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	assert_true(TravelSystem.is_traveling(c))


func test_is_traveling_false_no_destination() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = ""
	c.travel_days_remaining = 0
	assert_false(TravelSystem.is_traveling(c))


func test_is_traveling_false_zero_days() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 0
	assert_false(TravelSystem.is_traveling(c))


# -- process_travel_tick -------------------------------------------------------

func test_travel_tick_decrements_days() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_origin = "town_a"
	c.travel_days_remaining = 3
	var chars: Array = [c]
	TravelSystem.process_travel_tick(chars)
	assert_eq(c.travel_days_remaining, 2)


func test_travel_tick_arrival() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_origin = "town_a"
	c.travel_days_remaining = 1
	var chars: Array = [c]
	var arrivals: Array = TravelSystem.process_travel_tick(chars)
	assert_eq(arrivals.size(), 1)
	assert_eq(arrivals[0]["character_id"], 1)
	assert_eq(arrivals[0]["destination"], "town_b")
	assert_true(arrivals[0]["arrived"])
	assert_eq(c.physical_location, "town_b")
	assert_eq(c.travel_destination, "")
	assert_eq(c.travel_days_remaining, 0)


func test_travel_tick_no_travelers() -> void:
	var c := _make_character(1, "town_a")
	var chars: Array = [c]
	var arrivals: Array = TravelSystem.process_travel_tick(chars)
	assert_eq(arrivals.size(), 0)


func test_travel_tick_multiple_characters() -> void:
	var c1 := _make_character(1, "town_a")
	c1.travel_destination = "town_b"
	c1.travel_origin = "town_a"
	c1.travel_days_remaining = 1
	var c2 := _make_character(2, "town_c")
	c2.travel_destination = "town_d"
	c2.travel_origin = "town_c"
	c2.travel_days_remaining = 3
	var chars: Array = [c1, c2]
	var arrivals: Array = TravelSystem.process_travel_tick(chars)
	assert_eq(arrivals.size(), 1)
	assert_eq(arrivals[0]["character_id"], 1)
	assert_eq(c2.travel_days_remaining, 2)


# -- cancel_travel -------------------------------------------------------------

func test_cancel_travel() -> void:
	var c := _make_character(1, "town_a")
	c.travel_origin = "town_a"
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	var result: Dictionary = TravelSystem.cancel_travel(c)
	assert_true(result["cancelled"])
	assert_eq(result["returned_to"], "town_a")
	assert_eq(result["abandoned_destination"], "town_b")
	assert_eq(c.physical_location, "town_a")
	assert_eq(c.travel_destination, "")
	assert_eq(c.travel_days_remaining, 0)


func test_cancel_travel_not_traveling() -> void:
	var c := _make_character(1, "town_a")
	var result: Dictionary = TravelSystem.cancel_travel(c)
	assert_false(result["cancelled"])
	assert_eq(result["reason"], "not_traveling")


# -- change_destination --------------------------------------------------------

func test_change_destination() -> void:
	TravelSystem.clear_distances()
	TravelSystem.set_distance("town_a", "town_c", 5)
	var c := _make_character(1, "town_a")
	c.travel_origin = "town_a"
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	var result: Dictionary = TravelSystem.change_destination(c, "town_c")
	assert_true(result["changed"])
	assert_eq(result["new_destination"], "town_c")
	assert_eq(c.travel_destination, "town_c")


func test_change_destination_empty() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	var result: Dictionary = TravelSystem.change_destination(c, "")
	assert_false(result["changed"])
	assert_eq(result["reason"], "no_destination")


func test_change_destination_same() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	var result: Dictionary = TravelSystem.change_destination(c, "town_b")
	assert_false(result["changed"])
	assert_eq(result["reason"], "same_destination")


# -- context_flag --------------------------------------------------------------

func test_context_flag_traveling() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 2
	assert_eq(TravelSystem.get_context_flag(c), Enums.ContextFlag.TRAVELING)


func test_context_flag_not_traveling() -> void:
	var c := _make_character(1, "town_a")
	assert_eq(TravelSystem.get_context_flag(c), Enums.ContextFlag.AT_OWN_HOLDINGS)


# -- forced_march --------------------------------------------------------------

func test_forced_march_reduces_days() -> void:
	var result: Dictionary = TravelSystem.apply_forced_march(5)
	assert_eq(result["travel_days"], 4)
	assert_eq(result["morale_cost"], TravelSystem.FORCED_MARCH_MORALE_COST)


func test_forced_march_minimum() -> void:
	var result: Dictionary = TravelSystem.apply_forced_march(1)
	assert_eq(result["travel_days"], 1)
	assert_eq(result["morale_cost"], 0)


# -- terrain costs (constants) -------------------------------------------------

func test_terrain_costs_defined() -> void:
	assert_eq(TravelSystem.TERRAIN_COST["plains"], 1)
	assert_eq(TravelSystem.TERRAIN_COST["forest"], 2)
	assert_eq(TravelSystem.TERRAIN_COST["mountains"], 3)
	assert_eq(TravelSystem.TERRAIN_COST["hills"], 3)


func test_river_crossing_costs() -> void:
	assert_eq(TravelSystem.RIVER_CROSSING_COST, 1)
	assert_eq(TravelSystem.SPRING_RIVER_CROSSING_COST, 2)


# -- NPC engine integration ---------------------------------------------------

func test_build_context_sets_traveling_flag() -> void:
	var c := _make_character(1, "town_a")
	c.travel_destination = "town_b"
	c.travel_days_remaining = 2
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		c, {"season": 0, "ic_day": 10}
	)
	assert_eq(ctx.context_flag, Enums.ContextFlag.TRAVELING)


func test_build_context_not_traveling() -> void:
	var c := _make_character(1, "town_a")
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		c, {"season": 0, "ic_day": 10}
	)
	assert_eq(ctx.context_flag, Enums.ContextFlag.AT_OWN_HOLDINGS)


# -- ActionExecutor integration ------------------------------------------------

func test_executor_begin_travel() -> void:
	TravelSystem.clear_distances()
	TravelSystem.set_distance("origin_town", "dest_town", 4)
	var c := _make_character(1, "origin_town")
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "BEGIN_TRAVEL"
	action.target_settlement_id = -1
	action.target_province_id = -1
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 0

	# Simulate destination as a province ID string
	action.target_province_id = 42
	var dice := DiceEngine.new()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, dice, {})
	assert_true(result["success"])
	var effects: Dictionary = result["effects"]
	var travel: Dictionary = effects.get("travel", {})
	assert_true(travel.get("started", false))
	assert_eq(c.travel_destination, "42")


func test_executor_change_destination() -> void:
	TravelSystem.clear_distances()
	var c := _make_character(1, "town_a")
	c.travel_origin = "town_a"
	c.travel_destination = "town_b"
	c.travel_days_remaining = 3
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CHANGE_DESTINATION"
	action.target_province_id = 99
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 0
	var dice := DiceEngine.new()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, dice, {})
	assert_true(result["success"])
	var effects: Dictionary = result["effects"]
	var travel: Dictionary = effects.get("travel", {})
	assert_true(travel.get("changed", false))
	assert_eq(c.travel_destination, "99")


# -- DayOrchestrator integration (travel before wave resolution) ---------------

func test_orchestrator_processes_travel_arrivals() -> void:
	TravelSystem.clear_distances()
	var c := _make_character(1, "town_a")
	c.travel_origin = "town_a"
	c.travel_destination = "town_b"
	c.travel_days_remaining = 1

	var time := TimeSystem.new()
	var dice := DiceEngine.new()
	var chars: Array = [c]
	var chars_by_id: Dictionary = {1: c}
	var result: Dictionary = DayOrchestrator.advance_day(
		time, chars, chars_by_id, {}, {}, {}, {},
		dice, {}, {}, [], {}, [], [], [], [], [], [1], {}, {}, []
	)
	var arrivals: Array = result.get("travel_arrivals", [])
	assert_eq(arrivals.size(), 1)
	assert_eq(arrivals[0]["destination"], "town_b")
	assert_eq(c.physical_location, "town_b")
