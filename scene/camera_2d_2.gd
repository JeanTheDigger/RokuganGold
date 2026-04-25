extends Camera2D

@export var pan_speed := 900.0
var pan_dir := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
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


func _process(delta: float) -> void:
	if pan_dir != Vector2.ZERO:
		position += pan_dir.normalized() * pan_speed * delta
