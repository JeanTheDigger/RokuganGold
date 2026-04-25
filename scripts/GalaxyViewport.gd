extends Control
class_name GalaxyViewport

@onready var search_field: LineEdit = $PlanetSearch/SearchLineEdit
@onready var selected_label: Label = get_node_or_null("SelectionPanel/MarginContainer/SelectionLabel") as Label
@onready var map_container: SubViewportContainer = $SubViewportContainer
@onready var zoom_out_button: Button = $ZoomOutButton
@onready var system_map: SystemMap = $SubViewportContainer/SubViewport/MapRoot/SystemMap

var galaxy: Galaxy


func _ready() -> void:
	map_container.focus_mode = Control.FOCUS_CLICK

	await get_tree().process_frame
	_resolve_galaxy()

	if galaxy == null:
		push_error("Galaxy (GalaxyMap) not found under SubViewport/MapRoot")
		return

	if not galaxy.planet_selected.is_connected(_on_planet_selected):
		galaxy.planet_selected.connect(_on_planet_selected)

	if not galaxy.planet_double_clicked.is_connected(_on_planet_double_clicked):
		galaxy.planet_double_clicked.connect(_on_planet_double_clicked)

	if not system_map.zoom_out_requested.is_connected(_on_system_map_zoom_out_requested):
		system_map.zoom_out_requested.connect(_on_system_map_zoom_out_requested)

	_set_view_mode(false)
	_sync_galaxy_fleet_visuals()


func _on_sub_viewport_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if search_field.has_focus():
			search_field.release_focus()
		map_container.grab_focus()


func _on_search_button_pressed() -> void:
	if galaxy == null:
		if selected_label != null:
			selected_label.text = "System: Galaxy unavailable"
		return

	if system_map.visible:
		_set_view_mode(false)
		system_map.clear_system()
	_sync_galaxy_fleet_visuals()

	var found: bool = galaxy.select_planet_by_name(search_field.text)
	if not found:
		if selected_label != null:
			selected_label.text = "System: Not found"


func _on_planet_selected(planet_name: String) -> void:
	if selected_label == null:
		return
	selected_label.text = "System: %s" % planet_name
	if galaxy == null:
		return
	var summary: Dictionary = galaxy.get_system_fleet_summary_by_name(planet_name)
	if summary.is_empty():
		return
	var moving_count: int = int(summary.get("moving", 0))
	var idle_count: int = int(summary.get("idle", 0))
	if moving_count > 0:
		var eta_day: int = int(summary.get("min_arrival_day", -1))
		if eta_day >= 0:
			selected_label.text += " | Fleets: %d idle, %d moving (ETA day %d)" % [idle_count, moving_count, eta_day]
		else:
			selected_label.text += " | Fleets: %d idle, %d moving" % [idle_count, moving_count]
	else:
		selected_label.text += " | Fleets: %d" % int(summary.get("total", 0))


func _resolve_galaxy() -> void:
	galaxy = null

	var viewport: SubViewport = get_node_or_null("SubViewportContainer/SubViewport")
	if viewport == null:
		return

	var map_root: Node = viewport.get_node_or_null("MapRoot")
	if map_root == null:
		return

	for child in map_root.get_children():
		if child is Galaxy:
			galaxy = child as Galaxy
			return


func _set_view_mode(show_system_map: bool) -> void:
	if galaxy != null:
		galaxy.visible = not show_system_map
	system_map.visible = show_system_map
	zoom_out_button.visible = show_system_map
	$PlanetSearch.visible = not show_system_map


func _on_planet_double_clicked(system_name: String) -> void:
	if system_map.show_system(system_name):
		if selected_label != null:
			selected_label.text = "System: %s" % system_name
		_set_view_mode(true)


func _on_zoom_out_button_pressed() -> void:
	system_map.request_zoom_out()


func _on_system_map_zoom_out_requested(system_name: String) -> void:
	_set_view_mode(false)
	_sync_galaxy_fleet_visuals()
	system_map.clear_system()
	if galaxy != null:
		galaxy.focus_camera_on_system_by_name(system_name)


func _on_sub_viewport_container_mouse_exited() -> void:
	pass


func _get_fleet_visual_summary() -> Dictionary:
	return {}


func _sync_galaxy_fleet_visuals() -> void:
	if galaxy == null:
		return
	galaxy.set_system_fleet_state_by_name(_get_fleet_visual_summary())
