extends GutTest


var _char: L5RCharacterData


func before_each() -> void:
	_char = L5RCharacterData.new()
	ActionPointSystem.reset_daily_ap(_char)


# -- Constants -----------------------------------------------------------------

func test_ap_per_ic_day_is_two() -> void:
	assert_eq(ActionPointSystem.AP_PER_IC_DAY, 2)


func test_ap_per_real_day_is_eight() -> void:
	assert_eq(ActionPointSystem.AP_PER_REAL_DAY, 8)


# -- Reset ---------------------------------------------------------------------

func test_reset_sets_to_max() -> void:
	_char.action_points_current = 0
	ActionPointSystem.reset_daily_ap(_char)
	assert_eq(_char.action_points_current, 2)
	assert_eq(_char.action_points_max, 2)


# -- Spending ------------------------------------------------------------------

func test_spend_success() -> void:
	var result: Dictionary = ActionPointSystem.spend_ap(_char, 1)
	assert_true(result["success"])
	assert_eq(result["remaining"], 1)
	assert_eq(result["spent"], 1)


func test_spend_all_ap() -> void:
	var result: Dictionary = ActionPointSystem.spend_ap(_char, 2)
	assert_true(result["success"])
	assert_eq(result["remaining"], 0)


func test_spend_insufficient() -> void:
	ActionPointSystem.spend_ap(_char, 2)
	var result: Dictionary = ActionPointSystem.spend_ap(_char, 1)
	assert_false(result["success"])
	assert_eq(result["reason"], "insufficient_ap")
	assert_eq(result["available"], 0)
	assert_eq(result["required"], 1)


func test_spend_more_than_available() -> void:
	var result: Dictionary = ActionPointSystem.spend_ap(_char, 3)
	assert_false(result["success"])
	assert_eq(_char.action_points_current, 2, "AP unchanged on failure")


func test_spend_zero_invalid() -> void:
	var result: Dictionary = ActionPointSystem.spend_ap(_char, 0)
	assert_false(result["success"])
	assert_eq(result["reason"], "invalid_cost")


func test_spend_negative_invalid() -> void:
	var result: Dictionary = ActionPointSystem.spend_ap(_char, -1)
	assert_false(result["success"])
	assert_eq(result["reason"], "invalid_cost")


# -- Can spend -----------------------------------------------------------------

func test_can_spend_true() -> void:
	assert_true(ActionPointSystem.can_spend(_char, 1))
	assert_true(ActionPointSystem.can_spend(_char, 2))


func test_can_spend_false() -> void:
	assert_false(ActionPointSystem.can_spend(_char, 3))


# -- No carryover (simulated) -------------------------------------------------

func test_no_carryover_across_days() -> void:
	# Spend 1 of 2, then reset — should be back to 2, not 3
	ActionPointSystem.spend_ap(_char, 1)
	assert_eq(_char.action_points_current, 1)

	ActionPointSystem.reset_daily_ap(_char)
	assert_eq(_char.action_points_current, 2)


# -- Get remaining -------------------------------------------------------------

func test_get_remaining() -> void:
	assert_eq(ActionPointSystem.get_remaining_ap(_char), 2)
	ActionPointSystem.spend_ap(_char, 1)
	assert_eq(ActionPointSystem.get_remaining_ap(_char), 1)


# -- Dead character handling ---------------------------------------------------

func test_reset_dead_character_gets_zero_ap() -> void:
	_char.stamina = 0
	assert_true(CharacterStats.is_dead(_char), "Character with earth 0 is dead")
	ActionPointSystem.reset_daily_ap(_char)
	assert_eq(_char.action_points_current, 0, "Dead character gets 0 AP")
	assert_eq(_char.action_points_max, 0, "Dead character max AP is 0")


func test_reset_alive_then_dead_clears_ap() -> void:
	ActionPointSystem.reset_daily_ap(_char)
	assert_eq(_char.action_points_current, 2, "Alive character gets normal AP")
	_char.stamina = 0
	ActionPointSystem.reset_daily_ap(_char)
	assert_eq(_char.action_points_current, 0, "Dead character AP cleared on next reset")
