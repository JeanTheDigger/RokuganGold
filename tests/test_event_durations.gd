extends GutTest


# ==============================================================================
# OOC Durations
# ==============================================================================

func test_mass_battle_1_ooc_day() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.MASS_BATTLE), 1)


func test_siege_min_15_ooc_days() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.SIEGE, "min"), 15)


func test_siege_max_30_ooc_days() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.SIEGE, "max"), 30)


func test_court_season_30_ooc_days() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.COURT_SEASON), 30)


func test_festival_3_ooc_days() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.FESTIVAL), 3)


func test_diplomatic_summit_min_5() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.DIPLOMATIC_SUMMIT, "min"), 5)


func test_diplomatic_summit_max_7() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.DIPLOMATIC_SUMMIT, "max"), 7)


func test_tournament_min_3() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.TOURNAMENT, "min"), 3)


func test_tournament_max_5() -> void:
	assert_eq(EventDurations.get_ooc_duration(EventDurations.EventType.TOURNAMENT, "max"), 5)


# ==============================================================================
# IC Durations (OOC × 4)
# ==============================================================================

func test_mass_battle_4_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.MASS_BATTLE), 4)


func test_siege_min_60_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.SIEGE, "min"), 60)


func test_siege_max_120_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.SIEGE, "max"), 120)


func test_court_season_120_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.COURT_SEASON), 120)


func test_festival_12_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.FESTIVAL), 12)


func test_summit_min_20_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.DIPLOMATIC_SUMMIT, "min"), 20)


func test_summit_max_28_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.DIPLOMATIC_SUMMIT, "max"), 28)


func test_tournament_min_12_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.TOURNAMENT, "min"), 12)


func test_tournament_max_20_ic_days() -> void:
	assert_eq(EventDurations.get_ic_duration(EventDurations.EventType.TOURNAMENT, "max"), 20)


# ==============================================================================
# IC Ticks (alias)
# ==============================================================================

func test_ic_ticks_equals_ic_duration() -> void:
	assert_eq(
		EventDurations.get_ic_ticks(EventDurations.EventType.SIEGE, "max"),
		EventDurations.get_ic_duration(EventDurations.EventType.SIEGE, "max")
	)


# ==============================================================================
# Variable Duration
# ==============================================================================

func test_mass_battle_fixed_duration() -> void:
	assert_false(EventDurations.is_variable_duration(EventDurations.EventType.MASS_BATTLE))


func test_siege_variable_duration() -> void:
	assert_true(EventDurations.is_variable_duration(EventDurations.EventType.SIEGE))


func test_court_fixed_duration() -> void:
	assert_false(EventDurations.is_variable_duration(EventDurations.EventType.COURT_SEASON))


func test_festival_fixed_duration() -> void:
	assert_false(EventDurations.is_variable_duration(EventDurations.EventType.FESTIVAL))


func test_summit_variable_duration() -> void:
	assert_true(EventDurations.is_variable_duration(EventDurations.EventType.DIPLOMATIC_SUMMIT))


func test_tournament_variable_duration() -> void:
	assert_true(EventDurations.is_variable_duration(EventDurations.EventType.TOURNAMENT))


# ==============================================================================
# Ratio Constant
# ==============================================================================

func test_ooc_to_ic_ratio() -> void:
	assert_eq(EventDurations.OOC_TO_IC_RATIO, 4)


# ==============================================================================
# Get All Durations
# ==============================================================================

func test_get_all_durations_returns_all_types() -> void:
	var all: Dictionary = EventDurations.get_all_durations()
	assert_eq(all.size(), 6)


func test_get_all_durations_contains_ic_and_ooc() -> void:
	var all: Dictionary = EventDurations.get_all_durations()
	var siege: Dictionary = all[EventDurations.EventType.SIEGE]
	assert_eq(siege["ooc_min"], 15)
	assert_eq(siege["ooc_max"], 30)
	assert_eq(siege["ic_min"], 60)
	assert_eq(siege["ic_max"], 120)
