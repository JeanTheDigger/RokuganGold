class_name SimulationScheduler
extends Node
## Fires DayOrchestrator.advance_day() every 6 real hours (4× per real day).
## Tick checkpoints at EST hours: 0, 6, 12, 18.
## Persists last-processed tick to avoid double-firing on restart.

signal tick_completed(result: Dictionary)

const SAVE_PATH: String = "user://simulation/scheduler_state.txt"
const TICK_HOURS: Array[int] = [0, 6, 12, 18]

const _WorldBootstrap := preload("res://simulation/world_bootstrap.gd")

var _last_processed_tick_key: String = ""
var _processing: bool = false
var _world_saver: WorldStateSaver = WorldStateSaver.new()


func _ready() -> void:
	_load_state()
	_load_world_state()
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
	_save_world_state()


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


func _save_world_state() -> void:
	if _world_saver.save_world(WorldState):
		print("[SimulationScheduler] World state saved.")
	else:
		push_error("[SimulationScheduler] World state save failed.")


func _load_world_state() -> void:
	if _world_saver.load_world(WorldState):
		WorldState.rebuild_characters_by_id()
		WorldState.world_states.clear()
		WorldState.character_province_map.clear()
		print("[SimulationScheduler] World state loaded (%d characters, %d provinces)." % [
			WorldState.characters.size(),
			WorldState.provinces.size(),
		])
	else:
		print("[SimulationScheduler] No saved world state found — bootstrapping world.")
		_bootstrap_fresh_world()


func _bootstrap_fresh_world() -> void:
	WorldState.time_system.current_tick = 0
	_last_processed_tick_key = ""
	var dice := DiceEngine.new()
	dice.set_seed(1120)

	var result: Dictionary = _WorldBootstrap.bootstrap_world(dice)

	var chars: Array = result.get("characters", [])
	WorldState.characters.clear()
	for c: L5RCharacterData in chars:
		WorldState.characters.append(c)
	WorldState.rebuild_characters_by_id()

	WorldState.provinces = result.get("provinces", {})

	var settlements: Array = result.get("settlements", [])
	WorldState.settlements.clear()
	for s: SettlementData in settlements:
		WorldState.settlements.append(s)

	WorldState.clans = result.get("clans", {})

	var mil: Dictionary = result.get("military_data", {})
	WorldState.military_companies.assign(mil.get("companies", []))
	WorldState.next_company_id[0] = mil.get("next_company_id", 1)

	WorldState.emperor_id = result.get("emperor_id", -1)
	var emperor: L5RCharacterData = WorldState.characters_by_id.get(WorldState.emperor_id)
	if emperor != null:
		if not emperor.physical_location.is_empty():
			WorldState.emperor_settlement_id = emperor.physical_location.to_int()
		WorldState.emperor_archetype = StrategicReview.derive_emperor_archetype(emperor)
	WorldState.miya_representative_id = result.get("herald_id", -1)

	WorldState.next_character_id[0] = result.get("next_character_id", 10000)
	WorldState.next_settlement_id[0] = result.get("next_settlement_id", 5000)

	var clan_champions: Dictionary = result.get("clan_champions", {})
	for clan_name: String in clan_champions:
		var cd: ClanData = WorldState.clans.get(clan_name)
		if cd != null:
			cd.champion_id = clan_champions[clan_name]

	var bs_cells: Array = result.get("bloodspeaker_cells", [])
	WorldState.bloodspeaker_cells.clear()
	for cell: BloodspeakerCellData in bs_cells:
		WorldState.bloodspeaker_cells.append(cell)
	WorldState.next_cell_id[0] = result.get("next_cell_id", 1)

	var bs_insurgencies: Array = result.get("bloodspeaker_insurgencies", [])
	for ins: InsurgencyData in bs_insurgencies:
		WorldState.insurgencies.append(ins)
	WorldState.next_insurgency_id[0] = result.get("next_insurgency_id", 1)

	var togashi_ws: Dictionary = _build_togashi_bootstrap_state(result)
	TogashiOversight.initialize_from_world_state(WorldState.togashi_state, togashi_ws)

	_save_world_state()
	print("[SimulationScheduler] World bootstrapped: %d characters, %d provinces, %d settlements, %d cells." % [
		WorldState.characters.size(),
		WorldState.provinces.size(),
		WorldState.settlements.size(),
		WorldState.bloodspeaker_cells.size(),
	])


func _build_togashi_bootstrap_state(result: Dictionary) -> Dictionary:
	var companies: Array = result.get("military_data", {}).get("companies", [])
	var clan_strengths: Dictionary = {}
	for comp: Dictionary in companies:
		var clan: String = comp.get("clan", "")
		if not clan.is_empty():
			clan_strengths[clan] = clan_strengths.get(clan, 0.0) + float(comp.get("current_health", 100))
	var provinces: Dictionary = result.get("provinces", {})
	var max_ptl: float = 0.0
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		if prov.family != "Hiruma" and prov.province_taint_level > max_ptl:
			max_ptl = prov.province_taint_level
	return {
		"clan_strengths": clan_strengths,
		"active_inter_clan_wars": 0,
		"emperor_vacant": result.get("emperor_id", -1) < 0,
		"provinces_in_rebellion": 0,
		"failing_worship_provinces": 0,
		"realm_overlaps_empire_wide": 0,
		"realm_overlap_in_dragon_territory": false,
		"max_non_shadowlands_ptl": max_ptl,
		"wall_breach_active": false,
		"shadowlands_incursion_tier": 0,
		"crab_military_readiness": 1.0,
	}


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
