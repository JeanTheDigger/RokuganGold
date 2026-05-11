extends Control

@onready var background_panel: PanelContainer = $BackgroundPanel
@onready var form_panel: Panel = $BackgroundPanel/Panel
@onready var continue_button: Button = $BackgroundPanel/Panel/MarginContainer/VBoxContainer/MarginContainer/Continue

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	continue_button.disabled = true
	
	var shader_mat: ShaderMaterial = background_panel.material
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Phase 1 — Form fades, swirl intensifies (0–1.5s)
	tween.tween_property(form_panel, "modulate:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("swirl_strength", val),
		1.5, 8.0, 1.5
	).set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("inner_radius", val),
		0.15, 0.0, 1.5
	).set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("outer_radius", val),
		0.5, 0.15, 1.5
	).set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("mist_density", val),
		0.08, 0.25, 1.5
	).set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("mist_speed", val),
		0.15, 0.6, 1.5
	).set_ease(Tween.EASE_IN)
	
	# Phase 2 — Particles build up (1.0–2.0s)
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("sparkle_intensity", val),
		0.3, 1.0, 1.0
	).set_delay(1.0).set_ease(Tween.EASE_IN)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("particle_intensity", val),
		0.15, 0.8, 1.0
	).set_delay(1.0).set_ease(Tween.EASE_IN)
	
	# Explosion outward
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("outer_radius", val),
		0.15, 1.5, 0.6
	).set_delay(1.8).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("inner_radius", val),
		0.0, 1.5, 0.6
	).set_delay(1.8).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("mist_density", val),
		0.25, 0.6, 0.5
	).set_delay(1.8).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("sparkle_intensity", val),
		1.0, 3.0, 0.5
	).set_delay(1.8).set_ease(Tween.EASE_OUT)
	
	tween.tween_method(
		func(val: float) -> void: shader_mat.set_shader_parameter("particle_intensity", val),
		0.8, 3.0, 0.5
	).set_delay(1.8).set_ease(Tween.EASE_OUT)
	
	# Phase 3 — Gold flash then fade to black
	tween.tween_property(self, "modulate", Color(2.0, 1.8, 1.4, 1.0), 0.5)\
		.set_delay(2.2).set_ease(Tween.EASE_IN)
	
	tween.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.5)\
		.set_delay(2.7).set_ease(Tween.EASE_IN)
	
	# Phase 4 — Change scene (stays in parallel mode, just uses delay)
	tween.tween_callback(
		func() -> void: get_tree().change_scene_to_file("res://scenes/CharacterCreation2.tscn")
	).set_delay(3.5)
