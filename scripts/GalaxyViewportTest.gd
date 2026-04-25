extends GalaxyViewport
class_name GalaxyViewportTest

const CanonSystemTestDataResource = preload("res://scripts/data/canon_systems_test.gd")
const GalaxySimulationTestResource = preload("res://scripts/GalaxySimulationTest.gd")
const StrategicTestConfigResource = preload("res://scripts/simulation/StrategicTestConfig.gd")

var _tick_count: int = 0
var _day_count: int = 0
var _simulation: GalaxySimulationTest = GalaxySimulationTestResource.new()
var _active_system_name: String = ""
var _active_planet_name: String = ""
var _selected_system_id: int = -1
var _selected_fleet_id: int = -1

const ACTION_LOG_DIR := "C:/Users/admin/AppData/Roaming/Godot/app_userdata/WorldWriters/StarWarsInterregnum/"
const ACTION_LOG_PATH := ACTION_LOG_DIR + "galaxy_viewport_test_action_log.txt"
const UI_SNAPSHOT_PATH := ACTION_LOG_DIR + "galaxy_viewport_test_ui_snapshot.txt"

@onready var tick_counter_label: Label = $TickPanel/TickCounterLabel
@onready var planet_details_label: RichTextLabel = $SelectionPanel/MarginContainer/SelectionVBox/PlanetDetailsLabel
@onready var actions_log_label: RichTextLabel = $ActionsPanel/MarginContainer/ActionsLog
@onready var fleet_details_label: RichTextLabel = $SelectionPanel/MarginContainer/SelectionVBox/FleetDetailsLabel
@onready var fleet_ids_line_edit: LineEdit = $SelectionPanel/MarginContainer/SelectionVBox/FleetActionRow/FleetIdsLineEdit
@onready var ai_trace_faction_option: OptionButton = $SelectionPanel/MarginContainer/SelectionVBox/AITraceSection/AITraceFactionOption
@onready var ai_trace_tree: Tree = $SelectionPanel/MarginContainer/SelectionVBox/AITraceSection/AITraceTree

func _ready() -> void:
	super._ready()
	DirAccess.make_dir_recursive_absolute(ACTION_LOG_DIR)
	selected_label = $SelectionPanel/MarginContainer/SelectionVBox/SelectionLabel
	_simulation.setup_from_systems(CanonSystemTestDataResource.get_preset_systems(CanonSystemTestDataResource.PRESET_TEST_GALAXY_PREPATCH7))
	if not system_map.planet_double_clicked.is_connected(_on_system_map_planet_double_clicked):
		system_map.planet_double_clicked.connect(_on_system_map_planet_double_clicked)
	if not system_map.planet_selected.is_connected(_on_system_map_planet_selected):
		system_map.planet_selected.connect(_on_system_map_planet_selected)
	if not system_map.fleet_selected.is_connected(_on_system_map_fleet_selected):
		system_map.fleet_selected.connect(_on_system_map_fleet_selected)
	_update_tick_counter_label()
	_sync_galaxy_fleet_visuals()
	_refresh_ai_trace_section()
	_save_ui_snapshot_to_file("ready")


func _on_tick_plus_one_button_pressed() -> void:
	_advance_ticks(1)


func _on_tick_plus_five_button_pressed() -> void:
	_advance_ticks(5)


func _on_tick_plus_ten_button_pressed() -> void:
	_advance_ticks(10)


func _on_tick_plus_fifty_button_pressed() -> void:
	_advance_ticks(50)


func _on_tick_plus_one_hundred_button_pressed() -> void:
	_advance_ticks(100)


func _advance_ticks(tick_count: int) -> void:
	var safe_tick_count: int = maxi(0, tick_count)
	if safe_tick_count <= 0:
		return
	for _tick in range(safe_tick_count):
		_tick_count += 1
		_day_count += 1
		var day_logs: Array[String] = _simulation.advance_day()
		_emit_day_logs(day_logs)
	_update_tick_counter_label()
	_sync_galaxy_fleet_visuals()
	if not _active_system_name.is_empty() and not _active_planet_name.is_empty():
		_update_planet_panel(_active_system_name, _active_planet_name)
	_update_fleet_panel()
	_refresh_ai_trace_section()
	_save_ui_snapshot_to_file("advance_ticks")


func _update_tick_counter_label() -> void:
	tick_counter_label.text = "Tick: %d | Day: %d" % [_tick_count, _day_count]


func _on_system_map_planet_selected(system_name: String, planet_data: Dictionary) -> void:
	var planet_name: String = str(planet_data.get("source_name", planet_data.get("name", "Unknown Planet")))
	selected_label.text = "System: %s | Planet: %s" % [system_name, planet_name]


func _on_system_map_planet_double_clicked(system_name: String, planet_data: Dictionary) -> void:
	var planet_name: String = str(planet_data.get("source_name", planet_data.get("name", ""))).strip_edges()
	if planet_name.is_empty():
		planet_details_label.text = "Planet details unavailable."
		return
	_active_system_name = system_name
	_active_planet_name = planet_name
	var planet_system_id: int = int(planet_data.get("system_id", -1))
	if planet_system_id <= 0:
		var planet_ref: Dictionary = _simulation.get_planet_by_name(system_name, planet_name)
		planet_system_id = int(planet_ref.get("system_id", -1))
	_selected_system_id = planet_system_id
	_selected_fleet_id = -1
	_update_planet_panel(system_name, planet_name)
	_update_fleet_panel()
	_refresh_ai_trace_section()
	_save_ui_snapshot_to_file("planet_double_clicked")


func _on_system_map_fleet_selected(system_name: String, fleet_data: Dictionary) -> void:
	_selected_fleet_id = int(fleet_data.get("fleet_id", -1))
	if selected_label != null:
		selected_label.text = "System: %s | Fleet: %d | Faction: %d" % [
			system_name,
			_selected_fleet_id,
			int(fleet_data.get("owner_faction_id", 0)),
		]
	_update_fleet_panel()


func _update_planet_panel(system_name: String, planet_name: String) -> void:
	planet_details_label.text = _simulation.build_planet_report(system_name, planet_name)
	_save_ui_snapshot_to_file("planet_panel")


func _emit_day_logs(day_logs: Array[String]) -> void:
	if actions_log_label != null:
		for day_log in day_logs:
			actions_log_label.append_text("%s\n" % day_log)
		actions_log_label.scroll_to_line(actions_log_label.get_line_count())
	_append_day_logs_to_file(day_logs)
	_save_ui_snapshot_to_file("day_logs")
	for day_log in day_logs:
		print(day_log)


func _append_day_logs_to_file(day_logs: Array[String]) -> void:
	if day_logs.is_empty():
		return
	var file := FileAccess.open(ACTION_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(ACTION_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open GalaxyViewportTest log file: %s (err %s)" % [ACTION_LOG_PATH, str(FileAccess.get_open_error())])
		return
	file.seek_end()
	for day_log in day_logs:
		file.store_line(day_log)


func on_merge_selected_fleets(fleet_ids: Array[int]) -> void:
	if _selected_system_id <= 0 or fleet_ids.size() < 2:
		return
	var panel_data: Dictionary = _simulation.get_fleet_panel_data_for_system(_selected_system_id)
	var fleets: Array = panel_data.get("fleets", [])
	var owner_faction_id: int = -999999
	for fleet_variant in fleets:
		var fleet: Dictionary = fleet_variant
		var candidate_id: int = int(fleet.get("fleet_id", -1))
		if not fleet_ids.has(candidate_id):
			continue
		if owner_faction_id == -999999:
			owner_faction_id = int(fleet.get("owner_faction_id", StrategicTestConfigResource.NO_OWNER_FACTION_ID))
		elif owner_faction_id != int(fleet.get("owner_faction_id", StrategicTestConfigResource.NO_OWNER_FACTION_ID)):
			return
	var primary_id: int = _simulation.merge_fleets(_selected_system_id, owner_faction_id, fleet_ids)
	if primary_id > 0:
		_selected_fleet_id = primary_id
		_emit_day_logs(_simulation.drain_pending_operation_logs())
		_update_fleet_panel()


func on_split_selected_fleet(fleet_id: int) -> void:
	if fleet_id <= 0:
		return
	var new_fleet_id: int = _simulation.split_fleet_one_ship(fleet_id)
	if new_fleet_id > 0:
		_selected_fleet_id = new_fleet_id
		_emit_day_logs(_simulation.drain_pending_operation_logs())
		_update_fleet_panel()


func _on_merge_selected_button_pressed() -> void:
	var parsed_ids: Array[int] = []
	for token_variant in fleet_ids_line_edit.text.split(","):
		var token: String = str(token_variant).strip_edges()
		if token.is_empty():
			continue
		parsed_ids.append(int(token))
	on_merge_selected_fleets(parsed_ids)


func _on_split_selected_button_pressed() -> void:
	on_split_selected_fleet(_selected_fleet_id)


func _update_fleet_panel() -> void:
	if fleet_details_label == null or _selected_system_id <= 0:
		return
	var panel_data: Dictionary = _simulation.get_fleet_panel_data_for_system(_selected_system_id)
	if panel_data.is_empty():
		fleet_details_label.text = "Fleet details unavailable."
		return
	var lines: Array[String] = []
	lines.append("Fleets in system %s:" % str(panel_data.get("system_name", "Unknown")))
	var fleets: Array = panel_data.get("fleets", [])
	for fleet_variant in fleets:
		var fleet: Dictionary = fleet_variant
		var fleet_id: int = int(fleet.get("fleet_id", -1))
		if _selected_fleet_id < 0:
			_selected_fleet_id = fleet_id
		var marker: String = "*" if fleet_id == _selected_fleet_id else " "
		lines.append("%s Fleet %d owner=%d status=%s readiness=%d base_sr=%d eff_sr=%d" % [
			marker,
			fleet_id,
			int(fleet.get("owner_faction_id", 0)),
			str(fleet.get("status", "idle")),
			int(fleet.get("readiness", 100)),
			int(fleet.get("base_sr", 0)),
			int(fleet.get("effective_sr", 0)),
		])
		for ship_variant in fleet.get("ships", []):
			var ship: Dictionary = ship_variant
			lines.append("    - ship=%s sr=%d upkeep=%d" % [
				str(ship.get("blueprint_id", "")),
				int(ship.get("sr", 0)),
				int(ship.get("upkeep_credits_per_day", 0)),
			])
	fleet_details_label.text = "\n".join(lines)
	_save_ui_snapshot_to_file("fleet_panel")


func _refresh_ai_trace_section() -> void:
	if ai_trace_faction_option == null or ai_trace_tree == null:
		return
	var previous_faction_id: int = -1
	if ai_trace_faction_option.selected >= 0 and ai_trace_faction_option.get_item_count() > 0:
		previous_faction_id = ai_trace_faction_option.get_item_id(ai_trace_faction_option.selected)
	ai_trace_faction_option.clear()
	for faction_id in _simulation.get_simulation_faction_ids():
		if faction_id == StrategicTestConfigResource.NO_OWNER_FACTION_ID:
			continue
		ai_trace_faction_option.add_item("Faction %d" % faction_id, faction_id)
	if ai_trace_faction_option.get_item_count() <= 0:
		ai_trace_tree.clear()
		return
	var selected_index: int = 0
	for index in range(ai_trace_faction_option.get_item_count()):
		if ai_trace_faction_option.get_item_id(index) == previous_faction_id:
			selected_index = index
			break
	ai_trace_faction_option.select(selected_index)
	_render_ai_trace_for_selected_faction()


func _render_ai_trace_for_selected_faction() -> void:
	if ai_trace_tree == null or ai_trace_faction_option == null or ai_trace_faction_option.get_item_count() <= 0:
		return
	var faction_id: int = ai_trace_faction_option.get_item_id(ai_trace_faction_option.selected)
	var entries: Array[Dictionary] = _simulation.get_ai_trace_entries(faction_id)
	ai_trace_tree.columns = 7
	ai_trace_tree.set_column_title(0, "Day")
	ai_trace_tree.set_column_title(1, "Step")
	ai_trace_tree.set_column_title(2, "State")
	ai_trace_tree.set_column_title(3, "Target")
	ai_trace_tree.set_column_title(4, "Transport")
	ai_trace_tree.set_column_title(5, "Decision")
	ai_trace_tree.set_column_title(6, "Reason")
	ai_trace_tree.clear()
	var root: TreeItem = ai_trace_tree.create_item()
	for entry in entries:
		var row: TreeItem = ai_trace_tree.create_item(root)
		row.set_text(0, str(int(entry.get("day", -1))))
		row.set_text(1, str(entry.get("step", "")))
		row.set_text(2, str(entry.get("planner_state", "")))
		row.set_text(3, str(int(entry.get("target_planet_id", -1))))
		row.set_text(4, str(int(entry.get("transport_fleet_id", -1))))
		row.set_text(5, str(entry.get("decision", "none")))
		row.set_text(6, str(entry.get("reason", "ok")))
		var computed: Dictionary = entry.get("computed", {})
		var detail: TreeItem = ai_trace_tree.create_item(row)
		detail.set_text(1, "hop=%d enemy=%d friendly=%d gate=%s" % [
			int(computed.get("hop_distance", -1)),
			int(computed.get("est_enemy_eff_sr", -1)),
			int(computed.get("friendly_eff_sr", -1)),
			str(computed.get("gate_pass", false)),
		])
		detail.set_text(2, "escorts=%s" % str(entry.get("escort_fleet_ids", [])))
		detail.set_text(3, "note=%s" % str(entry.get("note", "")))
		row.collapsed = true


func _on_ai_trace_faction_option_item_selected(_index: int) -> void:
	_render_ai_trace_for_selected_faction()


func _save_ui_snapshot_to_file(trigger: String) -> void:
	var lines: Array[String] = []
	lines.append("trigger=%s" % trigger)
	lines.append("tick=%d day=%d" % [_tick_count, _day_count])
	lines.append("selection=%s" % selected_label.text)
	lines.append("active_system=%s active_planet=%s selected_system_id=%d selected_fleet_id=%d" % [
		_active_system_name,
		_active_planet_name,
		_selected_system_id,
		_selected_fleet_id,
	])
	lines.append("")
	lines.append("[PlanetDetails]")
	lines.append(planet_details_label.text)
	lines.append("")
	lines.append("[FleetDetails]")
	lines.append(fleet_details_label.text)
	lines.append("")
	lines.append("[ActionLog]")
	lines.append(actions_log_label.text)
	var file := FileAccess.open(UI_SNAPSHOT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open GalaxyViewportTest UI snapshot file: %s (err %s)" % [UI_SNAPSHOT_PATH, str(FileAccess.get_open_error())])
		return
	for line in lines:
		file.store_line(line)


func _get_fleet_visual_summary() -> Dictionary:
	return _simulation.build_fleet_summary_by_system_name()


func _sync_galaxy_fleet_visuals() -> void:
	var fleet_summary: Dictionary = _get_fleet_visual_summary()
	system_map.set_system_fleet_state_by_name(fleet_summary)
	if galaxy != null:
		galaxy.set_system_fleet_state_by_name(fleet_summary)
