class_name TimeSystem
## Persistent world time per GDD s13. 1 tick = 6 real hours = 1 IC day.
## The Rokugani calendar: 360 IC days/year, 12 months of 30 days.
## Spring 90d, Summer 90d, Autumn 60d, Winter 120d.

enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER,
}

const REAL_HOURS_PER_TICK: int = 6
const IC_DAYS_PER_TICK: int = 1
const TICKS_PER_REAL_DAY: int = 4
const IC_DAYS_PER_MONTH: int = 30
const IC_MONTHS_PER_YEAR: int = 12
const IC_DAYS_PER_YEAR: int = 360

const SPRING_DAYS: int = 90
const SUMMER_DAYS: int = 90
const AUTUMN_DAYS: int = 60
const WINTER_DAYS: int = 120

var current_tick: int = 0
var start_year: int = 1120


func _init(p_start_year: int = 1120, p_start_tick: int = 0) -> void:
	start_year = p_start_year
	current_tick = p_start_tick


func advance_tick() -> void:
	current_tick += 1


func get_ic_day() -> int:
	return current_tick * IC_DAYS_PER_TICK


func get_ic_day_of_year() -> int:
	return get_ic_day() % IC_DAYS_PER_YEAR


func get_ic_year() -> int:
	return start_year + (get_ic_day() / IC_DAYS_PER_YEAR)


func get_ic_month() -> int:
	return (get_ic_day_of_year() / IC_DAYS_PER_MONTH) + 1


func get_ic_day_of_month() -> int:
	return (get_ic_day_of_year() % IC_DAYS_PER_MONTH) + 1


func get_season() -> Season:
	var day_of_year: int = get_ic_day_of_year()
	if day_of_year < SPRING_DAYS:
		return Season.SPRING
	if day_of_year < SPRING_DAYS + SUMMER_DAYS:
		return Season.SUMMER
	if day_of_year < SPRING_DAYS + SUMMER_DAYS + AUTUMN_DAYS:
		return Season.AUTUMN
	return Season.WINTER


func get_season_name() -> String:
	match get_season():
		Season.SPRING: return "Spring"
		Season.SUMMER: return "Summer"
		Season.AUTUMN: return "Autumn"
		Season.WINTER: return "Winter"
	return ""


func is_winter_court() -> bool:
	return get_season() == Season.WINTER


func get_ic_date_string() -> String:
	return "Year %d, Month %d, Day %d (%s)" % [
		get_ic_year(), get_ic_month(), get_ic_day_of_month(), get_season_name()
	]


func get_real_days_elapsed() -> float:
	return float(current_tick) / float(TICKS_PER_REAL_DAY)


const SEASON_BOUNDARIES: Array[int] = [0, 90, 180, 240, 360]


static func get_next_season_start(ic_day: int) -> int:
	var day_of_year: int = ic_day % IC_DAYS_PER_YEAR
	var year_base: int = ic_day - day_of_year
	for boundary: int in SEASON_BOUNDARIES:
		if boundary > day_of_year:
			return year_base + boundary
	return year_base + IC_DAYS_PER_YEAR


static func get_season_after_next_start(ic_day: int) -> int:
	var next: int = get_next_season_start(ic_day)
	return get_next_season_start(next)
