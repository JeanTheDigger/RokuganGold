extends Node

signal calendar_updated(current_date: String, is_second_half: bool)
signal day_changed(current_date: String)  # fires only when a new calendar day begins

const SAVE_PATH: String = "user://calendar/current_date.txt"

var current_date: Date = Date.create(1990, 1, 1)
var is_second_half: bool = false
var _last_checked_day: int = -1

func _ready() -> void:
	print("📅 CalendarManager loaded.")
	_load_saved_date()
	set_process(true)

func _process(_delta: float) -> void:
	var utc_time: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()))
	var is_dst: bool = _is_daylight_saving_time(utc_time)
	var est_hour: int = (int(utc_time["hour"]) - (4 if is_dst else 5) + 24) % 24
	var current_day: int = int(utc_time["day"])

	if est_hour == 0 and _last_checked_day != current_day:
		_last_checked_day = current_day
		_update_calendar()

func _update_calendar() -> void:
	if is_second_half:
		# Finishing second half → advance to the next calendar day
		current_date = _get_next_date(current_date)
		is_second_half = false
		_save_current_date()  # save on full day change
		emit_signal("day_changed", get_current_date_string())
	else:
		# First half → move to second half
		is_second_half = true
		_save_current_date()  # NEW: also save on half toggle

	emit_signal("calendar_updated", get_current_date_string(), is_second_half)

func advance_half_night() -> void:
	_update_calendar()

func get_current_date_string() -> String:
	return "%04d-%02d-%02d" % [current_date.year, current_date.month, current_date.day]

func get_current_date_info() -> Dictionary:
	return {
		"date": get_current_date_string(),
		"is_second_half": is_second_half
	}

func _save_current_date() -> void:
	DirAccess.make_dir_recursive_absolute("user://calendar/")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line(get_current_date_string())
		file.store_line(str(is_second_half).to_lower())  # write lowercase to match loader
		file.close()
		print("💾 Saved date:", get_current_date_string(), "Second half:", is_second_half)

func _load_saved_date() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("❌ No saved date found. Starting from default.")
		_save_current_date()  # create a save file immediately
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var date_line: String = file.get_line()
		var half_line: String = file.get_line()
		file.close()

		var parts: PackedStringArray = date_line.split("-")
		if parts.size() == 3:
			current_date = Date.create(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
			is_second_half = half_line.strip_edges().to_lower() == "true"  # accept any case
			print("📂 Loaded date:", get_current_date_string(), "Second half:", is_second_half)
			emit_signal("calendar_updated", get_current_date_string(), is_second_half)

func _get_next_date(date: Date) -> Date:
	var next_day: int = date.day + 1
	var days_in_month: int = _get_days_in_month(date.year, date.month)
	var new_month: int = date.month
	var new_year: int = date.year

	if next_day > days_in_month:
		next_day = 1
		new_month += 1
		if new_month > 12:
			new_month = 1
			new_year += 1

	return Date.create(new_year, new_month, next_day)

func _get_days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30

func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

func _is_daylight_saving_time(datetime: Dictionary) -> bool:
	var month: int = int(datetime["month"])
	var day: int = int(datetime["day"])
	var weekday: int = int(datetime["weekday"])  # Sunday = 0

	if month < 3 or month > 11:
		return false
	elif month > 3 and month < 11:
		return true
	elif month == 3:
		return (day - weekday) >= 8  # 2nd Sunday of March
	elif month == 11:
		return (day - weekday) < 1   # 1st Sunday of November
	return false

class Date:
	var year: int
	var month: int
	var day: int

	static func create(y: int, m: int, d: int) -> Date:
		var instance := Date.new()
		instance.year = y
		instance.month = m
		instance.day = d
		return instance

func date_plus_days(start_date: String, days: int) -> String:
	var parts: PackedStringArray = start_date.split("-")
	if parts.size() != 3:
		return start_date
	var d: Date = Date.create(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
	for i in range(days):
		d = _get_next_date(d)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
