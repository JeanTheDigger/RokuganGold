extends Node

@export var zoom_step := 0.1
@export var min_zoom := 0.05
@export var max_zoom := 2.5
@export var pan_speed := 3000.0

var pan_dir := Vector2.ZERO
var camera: Camera2D = null


func _ready() -> void:
	# SubViewport contents are created one frame later
	await get_tree().process_frame
	_resolve_camera()


func _resolve_camera() -> void:
	camera = get_node_or_null("../SubViewportContainer/SubViewport/MapRoot/Camera2D")
	if camera == null:
		push_error("InputRouter: Camera2D not found at expected path")


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return

	# --- Zoom ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(zoom_step)        # zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-zoom_step)       # zoom out


	# --- Pan ---
	if event is InputEventKey:
		if event.is_action_pressed("pan_left"):
			pan_dir.x = -1
		elif event.is_action_pressed("pan_right"):
			pan_dir.x = 1
		elif event.is_action_released("pan_left") or event.is_action_released("pan_right"):
			pan_dir.x = 0

		if event.is_action_pressed("pan_up"):
			pan_dir.y = -1
		elif event.is_action_pressed("pan_down"):
			pan_dir.y = 1
		elif event.is_action_released("pan_up") or event.is_action_released("pan_down"):
			pan_dir.y = 0


func _apply_zoom(delta: float) -> void:
	var new_zoom := camera.zoom.x + delta
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(new_zoom, new_zoom)


func _process(delta: float) -> void:
	if camera == null:
		return

	if pan_dir != Vector2.ZERO:
		camera.position += pan_dir.normalized() * pan_speed * delta
