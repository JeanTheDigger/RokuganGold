extends GutTest


var _char: L5RCharacterData
var _action_log: Array


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.lord_id = 99
	_action_log = []


# =============================================================================
# Step 1: Active Court Available
# =============================================================================

func test_active_court_returns_attend() -> void:
	var court: Dictionary = {"settlement_id": 10, "prestige": 3}
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		court, [], _char, -1, [], _action_log, 1
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "ATTEND_COURT")
	assert_eq(result["target_settlement_id"], 10)
	assert_eq(result["priority"], 2)


# =============================================================================
# Step 2: Upcoming Court
# =============================================================================

func test_upcoming_court_returns_travel() -> void:
	var upcoming: Array = [
		{"settlement_id": 20, "prestige": 5, "start_ic_day": 30},
	]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, upcoming, _char, -1, [], _action_log, 1
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "TRAVEL_TO")
	assert_eq(result["target_settlement_id"], 20)


func test_upcoming_court_picks_highest_prestige() -> void:
	var upcoming: Array = [
		{"settlement_id": 20, "prestige": 3},
		{"settlement_id": 30, "prestige": 7},
		{"settlement_id": 40, "prestige": 5},
	]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, upcoming, _char, -1, [], _action_log, 1
	)
	assert_eq(result["target_settlement_id"], 30)


# =============================================================================
# Step 3a: Deploy Leverage by Letter
# =============================================================================

func test_leverage_sends_letter_to_target_lord() -> void:
	var leverage: Array = [
		{"secret_id": 1, "target_lord_id": 50},
	]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, 10, leverage, _action_log, 1
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "SEND_LETTER")
	assert_eq(result["target_npc_id"], 50)


func test_leverage_sends_letter_to_target_if_no_lord() -> void:
	var leverage: Array = [
		{"secret_id": 1},
	]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, 10, leverage, _action_log, 1
	)
	assert_eq(result["need_type"], "SEND_LETTER")
	assert_eq(result["target_npc_id"], 10)


# =============================================================================
# Step 3b: Request Lord Call Court
# =============================================================================

func test_request_lord_call_court() -> void:
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, -1, [], _action_log, 1
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "SEND_LETTER")
	assert_eq(result["target_npc_id"], 99)
	assert_eq(result["priority"], 1)


func test_no_duplicate_request_same_season() -> void:
	_action_log = [{
		"character_id": 1,
		"action_id": "SEND_LETTER",
		"target_npc_id": 99,
		"season": 1,
	}]
	_char.lord_id = 99
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, -1, [], _action_log, 1
	)
	# Already requested — should fall through to null (no target to visit)
	assert_null(result)


func test_allows_request_different_season() -> void:
	_action_log = [{
		"character_id": 1,
		"action_id": "SEND_LETTER",
		"target_npc_id": 99,
		"season": 0,
	}]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, -1, [], _action_log, 1
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "SEND_LETTER")
	assert_eq(result["target_npc_id"], 99)


# =============================================================================
# Step 3c: Personal Visit
# =============================================================================

func test_personal_visit_to_target() -> void:
	_char.lord_id = -1
	var known_locs: Dictionary = {10: 42}
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, 10, [], _action_log, 1, known_locs
	)
	assert_not_null(result)
	assert_eq(result["need_type"], "TRAVEL_TO")
	assert_eq(result["target_settlement_id"], 42)


# =============================================================================
# Step 3d: No Alternative — Null
# =============================================================================

func test_no_options_returns_null() -> void:
	_char.lord_id = -1
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, -1, [], _action_log, 1
	)
	assert_null(result)


func test_no_lord_no_target_no_leverage_returns_null() -> void:
	_char.lord_id = -1
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, -1, [], _action_log, 1
	)
	assert_null(result)


# =============================================================================
# Priority Cascade
# =============================================================================

func test_active_court_beats_upcoming() -> void:
	var active: Dictionary = {"settlement_id": 10}
	var upcoming: Array = [{"settlement_id": 20, "prestige": 9}]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		active, upcoming, _char, -1, [], _action_log, 1
	)
	assert_eq(result["need_type"], "ATTEND_COURT")
	assert_eq(result["target_settlement_id"], 10)


func test_upcoming_court_beats_leverage() -> void:
	var upcoming: Array = [{"settlement_id": 20, "prestige": 5}]
	var leverage: Array = [{"secret_id": 1, "target_lord_id": 50}]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, upcoming, _char, 10, leverage, _action_log, 1
	)
	assert_eq(result["need_type"], "TRAVEL_TO")
	assert_eq(result["target_settlement_id"], 20)


func test_leverage_beats_lord_request() -> void:
	var leverage: Array = [{"secret_id": 1, "target_lord_id": 50}]
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		{}, [], _char, 10, leverage, _action_log, 1
	)
	assert_eq(result["need_type"], "SEND_LETTER")
	assert_eq(result["target_npc_id"], 50)
