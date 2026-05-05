extends GutTest


var _time: TimeSystem


func before_each() -> void:
	_time = TimeSystem.new(1120, 0)


# -- Initial state -------------------------------------------------------------

func test_initial_tick_is_zero() -> void:
	assert_eq(_time.current_tick, 0)


func test_initial_date() -> void:
	assert_eq(_time.get_ic_year(), 1120)
	assert_eq(_time.get_ic_month(), 1)
	assert_eq(_time.get_ic_day_of_month(), 1)


func test_initial_season_is_spring() -> void:
	assert_eq(_time.get_season(), TimeSystem.Season.SPRING)


# -- Tick advancement ----------------------------------------------------------

func test_advance_tick_increments() -> void:
	_time.advance_tick()
	assert_eq(_time.current_tick, 1)
	assert_eq(_time.get_ic_day(), 1)


func test_four_ticks_is_four_ic_days() -> void:
	for i: int in range(4):
		_time.advance_tick()
	assert_eq(_time.get_ic_day(), 4)


# -- Season boundaries ---------------------------------------------------------

func test_spring_lasts_90_days() -> void:
	# Day 89 (tick 89) should still be spring
	_time = TimeSystem.new(1120, 89)
	assert_eq(_time.get_season(), TimeSystem.Season.SPRING)

	# Day 90 (tick 90) should be summer
	_time = TimeSystem.new(1120, 90)
	assert_eq(_time.get_season(), TimeSystem.Season.SUMMER)


func test_summer_lasts_90_days() -> void:
	# Day 179 (tick 179) should still be summer
	_time = TimeSystem.new(1120, 179)
	assert_eq(_time.get_season(), TimeSystem.Season.SUMMER)

	# Day 180 (tick 180) should be autumn
	_time = TimeSystem.new(1120, 180)
	assert_eq(_time.get_season(), TimeSystem.Season.AUTUMN)


func test_autumn_lasts_60_days() -> void:
	# Day 239 (tick 239) should still be autumn
	_time = TimeSystem.new(1120, 239)
	assert_eq(_time.get_season(), TimeSystem.Season.AUTUMN)

	# Day 240 (tick 240) should be winter
	_time = TimeSystem.new(1120, 240)
	assert_eq(_time.get_season(), TimeSystem.Season.WINTER)


func test_winter_lasts_120_days() -> void:
	# Day 359 (tick 359) should still be winter
	_time = TimeSystem.new(1120, 359)
	assert_eq(_time.get_season(), TimeSystem.Season.WINTER)


func test_winter_court_flag() -> void:
	_time = TimeSystem.new(1120, 240)
	assert_true(_time.is_winter_court())

	_time = TimeSystem.new(1120, 89)
	assert_false(_time.is_winter_court())


# -- Year rollover -------------------------------------------------------------

func test_year_rolls_over_at_360_days() -> void:
	_time = TimeSystem.new(1120, 360)
	assert_eq(_time.get_ic_year(), 1121)
	assert_eq(_time.get_ic_day_of_year(), 0)
	assert_eq(_time.get_season(), TimeSystem.Season.SPRING)


func test_multi_year_advance() -> void:
	# 720 ticks = 720 IC days = 2 full years
	_time = TimeSystem.new(1120, 720)
	assert_eq(_time.get_ic_year(), 1122)


# -- Month calculations -------------------------------------------------------

func test_month_increments() -> void:
	# Day 30 = month 2
	_time = TimeSystem.new(1120, 30)
	assert_eq(_time.get_ic_month(), 2)
	assert_eq(_time.get_ic_day_of_month(), 1)


func test_month_twelve() -> void:
	# Day 330 = month 12 (last month, winter)
	_time = TimeSystem.new(1120, 330)
	assert_eq(_time.get_ic_month(), 12)


# -- Date string ---------------------------------------------------------------

func test_date_string_format() -> void:
	var date: String = _time.get_ic_date_string()
	assert_true(date.begins_with("Year 1120"))
	assert_true("Spring" in date)


# -- Real time -----------------------------------------------------------------

func test_real_days_elapsed() -> void:
	_time = TimeSystem.new(1120, 8)
	assert_almost_eq(_time.get_real_days_elapsed(), 2.0, 0.001)


func test_full_year_is_90_real_days() -> void:
	_time = TimeSystem.new(1120, 360)
	assert_almost_eq(_time.get_real_days_elapsed(), 90.0, 0.001)
