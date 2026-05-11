extends Control

@onready var background_panel: PanelContainer = $BackgroundPanel

@onready var air_panel: Panel = $AirPanel
@onready var earth_panel: Panel = $EarthPanel
@onready var fire_panel: Panel = $FirePanel
@onready var water_panel: Panel = $WaterPanel
@onready var void_panel: Panel = $VoidPanel
@onready var skill_panel: Panel = $SkillPanel
@onready var advan_panel: Panel = $AdvanDisadPanel

@onready var air_circle: Control = $AirPanel/MarginContainer/VBoxContainer/AirElementCircle
@onready var earth_circle: Control = $EarthPanel/MarginContainer/VBoxContainer/EarthElementCircle
@onready var fire_circle: Control = $FirePanel/MarginContainer/VBoxContainer/FireElementCircle
@onready var water_circle: Control = $WaterPanel/MarginContainer/VBoxContainer/WaterElementCircle
@onready var void_circle: Control = $VoidPanel/MarginContainer/VBoxContainer/VoidElementCircle

@onready var air_content: VBoxContainer = $AirPanel/MarginContainer/VBoxContainer
@onready var earth_content: VBoxContainer = $EarthPanel/MarginContainer/VBoxContainer
@onready var fire_content: VBoxContainer = $FirePanel/MarginContainer/VBoxContainer
@onready var water_content: VBoxContainer = $WaterPanel/MarginContainer/VBoxContainer
@onready var void_content: VBoxContainer = $VoidPanel/MarginContainer/VBoxContainer

func _ready() -> void:
	# Set shader opacity to 0
	var bg_shader: ShaderMaterial = background_panel.material
	bg_shader.set_shader_parameter("opacity", 0.0)
	
	skill_panel.modulate.a = 0.0
	advan_panel.modulate.a = 0.0
	
	air_panel.modulate.a = 1.0
	earth_panel.modulate.a = 1.0
	fire_panel.modulate.a = 1.0
	water_panel.modulate.a = 1.0
	void_panel.modulate.a = 1.0
	
	air_panel.self_modulate.a = 0.0
	earth_panel.self_modulate.a = 0.0
	fire_panel.self_modulate.a = 0.0
	water_panel.self_modulate.a = 0.0
	void_panel.self_modulate.a = 0.0
	
	for child in air_content.get_children():
		if child != air_circle:
			child.modulate.a = 0.0
	for child in earth_content.get_children():
		if child != earth_circle:
			child.modulate.a = 0.0
	for child in fire_content.get_children():
		if child != fire_circle:
			child.modulate.a = 0.0
	for child in water_content.get_children():
		if child != water_circle:
			child.modulate.a = 0.0
	for child in void_content.get_children():
		if child != void_circle:
			child.modulate.a = 0.0
	
	air_circle.modulate.a = 0.0
	earth_circle.modulate.a = 0.0
	fire_circle.modulate.a = 0.0
	water_circle.modulate.a = 0.0
	void_circle.modulate.a = 0.0
	
	await get_tree().process_frame
	await get_tree().process_frame
	_play_intro()

func _play_intro() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	
	var bg_shader: ShaderMaterial = background_panel.material
	
	# Background fades in via shader opacity
	tween.tween_method(
		func(val: float) -> void: bg_shader.set_shader_parameter("opacity", val),
		0.0, 1.0, 2.4
	).set_delay(0.5).set_ease(Tween.EASE_OUT)
	
	# Circles glow in one by one
	tween.tween_property(air_circle, "modulate:a", 1.0, 0.6)\
		.set_delay(0.8).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(earth_circle, "modulate:a", 1.0, 0.6)\
		.set_delay(1.2).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(fire_circle, "modulate:a", 1.0, 0.6)\
		.set_delay(1.6).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(water_circle, "modulate:a", 1.0, 0.6)\
		.set_delay(2.0).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(void_circle, "modulate:a", 1.0, 0.6)\
		.set_delay(2.4).set_ease(Tween.EASE_OUT)
	
	# Panel backgrounds materialize
	tween.tween_property(air_panel, "self_modulate:a", 1.0, 0.8)\
		.set_delay(3.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(earth_panel, "self_modulate:a", 1.0, 0.8)\
		.set_delay(3.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(fire_panel, "self_modulate:a", 1.0, 0.8)\
		.set_delay(3.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(water_panel, "self_modulate:a", 1.0, 0.8)\
		.set_delay(3.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(void_panel, "self_modulate:a", 1.0, 0.8)\
		.set_delay(3.0).set_ease(Tween.EASE_OUT)
	
	# Labels, buttons fade in
	tween.tween_callback(func() -> void: _fade_in_contents()).set_delay(3.2)
	
	tween.tween_property(skill_panel, "modulate:a", 1.0, 1.0)\
		.set_delay(3.4).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(advan_panel, "modulate:a", 1.0, 1.0)\
		.set_delay(3.6).set_ease(Tween.EASE_OUT)

func _fade_in_contents() -> void:
	var content_tween := create_tween()
	content_tween.set_parallel(true)
	
	var all_contents: Array = [air_content, earth_content, fire_content, water_content, void_content]
	var all_circles: Array = [air_circle, earth_circle, fire_circle, water_circle, void_circle]
	
	for i in range(all_contents.size()):
		var container: VBoxContainer = all_contents[i]
		var circle: Control = all_circles[i]
		for child in container.get_children():
			if child != circle:
				content_tween.tween_property(child, "modulate:a", 1.0, 0.8)\
					.set_ease(Tween.EASE_OUT)
