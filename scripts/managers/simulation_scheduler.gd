class_name SimulationScheduler
extends Node
## Fires DayOrchestrator.advance_day() every 6 real hours (4× per real day).
## Tick checkpoints at EST hours: 0, 6, 12, 18.
## Persists last-processed tick to avoid double-firing on restart.

signal tick_completed(result: Dictionary)

const SAVE_PATH: String = "user://simulation/scheduler_state.txt"
const TICK_HOURS: Array[int] = [0, 6, 12, 18]

var _last_processed_tick_key: String = ""
var _processing: bool = false


func _ready() -> void:
	_load_state()
	set_process(true)
	print("[SimulationScheduler] Ready. Last tick: %s" % _last_processed_tick_key)


func _process(_delta: float) -> void:
	if _processing:
		return

	var tick_key: String = _get_current_tick_key()
	if tick_key.is_empty():
		return
	if tick_key == _last_processed_tick_key:
		return

	_processing = true
	print("[SimulationScheduler] Tick triggered: %s" % tick_key)

	var result: Dictionary = WorldState.advance_one_day()

	_last_processed_tick_key = tick_key
	_save_state()
	_processing = false

	var ic_date: String = WorldState.time_system.get_ic_date_string()
	print("[SimulationScheduler] Tick complete: %s → %s" % [tick_key, ic_date])
	tick_completed.emit(result)


func _get_current_tick_key() -> String:
	var utc: Dictionary = Time.get_datetime_dict_from_system(true)
	var est_offset: int = 4 if _is_dst(utc) else 5
	var est_hour: int = (int(utc["hour"]) - est_offset + 24) % 24

	var matched_hour: int = -1
	for h: int in TICK_HOURS:
		if est_hour >= h:
			matched_hour = h

	if matched_hour < 0:
		return ""

	var est_day: int = int(utc["day"])
	var est_month: int = int(utc["month"])
	var est_year: int = int(utc["year"])

	if int(utc["hour"]) < est_offset and est_hour >= 0:
		est_day -= 1
		if est_day < 1:
			est_month -= 1
			if est_month < 1:
				est_month = 12
				est_year -= 1
			est_day = _days_in_month(est_year, est_month)

	return "%04d-%02d-%02d-H%02d" % [est_year, est_month, est_day, matched_hour]


func force_tick() -> Dictionary:
	_processing = true
	var result: Dictionary = WorldState.advance_one_day()
	_last_processed_tick_key = _get_current_tick_key()
	_save_state()
	_processing = false
	tick_completed.emit(result)
	return result


func get_next_tick_est_hour() -> int:
	var utc: Dictionary = Time.get_datetime_dict_from_system(true)
	var est_offset: int = 4 if _is_dst(utc) else 5
	var est_hour: int = (int(utc["hour"]) - est_offset + 24) % 24
	for h: int in TICK_HOURS:
		if est_hour < h:
			return h
	return TICK_HOURS[0]


# -- Persistence ---------------------------------------------------------------

func _save_state() -> void:
	DirAccess.make_dir_recursive_absolute("user://simulation/")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line(_last_processed_tick_key)
		file.store_line(str(WorldState.time_system.current_tick))
		file.close()


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		_last_processed_tick_key = file.get_line().strip_edges()
		var tick_str: String = file.get_line().strip_edges()
		if tick_str.is_valid_int():
			WorldState.time_system.current_tick = tick_str.to_int()
		file.close()
		print("[SimulationScheduler] Restored tick %d from %s" % [
			WorldState.time_system.current_tick, _last_processed_tick_key
		])


# -- DST / Calendar Helpers ----------------------------------------------------

func _is_dst(utc: Dictionary) -> bool:
	var month: int = int(utc["month"])
	var day: int = int(utc["day"])
	var weekday: int = int(utc["weekday"])
	if month < 3 or month > 11:
		return false
	if month > 3 and month < 11:
		return true
	if month == 3:
		return (day - weekday) >= 8
	if month == 11:
		return (day - weekday) < 1
	return false


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
		_:
			return 30
