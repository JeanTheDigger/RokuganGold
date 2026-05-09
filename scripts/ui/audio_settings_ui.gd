extends Control

@onready var jingle_slider = $AudioSettingUI/VBoxContainer/Jingle/HSlider
@onready var music_slider = $AudioSettingUI/VBoxContainer/Music/HSlider
@onready var narrator_slider = $AudioSettingUI/VBoxContainer/Narrator/HSlider
@onready var ambiance_slider = $AudioSettingUI/VBoxContainer/Ambiance/HSlider
@onready var close_button = $AudioSettingUI/VBoxContainer/Close

func _ready():
	# Set default values (full volume if config not found)
	jingle_slider.value = 100
	music_slider.value = 100
	narrator_slider.value = 100
	ambiance_slider.value = 100

	load_audio_settings()

	# Apply loaded values to sound systems
	_update_jingle_volume(jingle_slider.value)
	_update_narrator_volume(narrator_slider.value)
	_set_bus_volume("Music", slider_to_db(music_slider.value))
	_set_bus_volume("Ambiance", slider_to_db(ambiance_slider.value))

	# Connect each slider to its handler
	jingle_slider.value_changed.connect(_on_jingle_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	narrator_slider.value_changed.connect(_on_narrator_volume_changed)
	ambiance_slider.value_changed.connect(_on_ambiance_volume_changed)

	close_button.pressed.connect(_on_close_pressed)

func _set_bus_volume(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

# Convert slider [0–100] to decibels [-80 to 0]
func slider_to_db(value: float) -> float:
	return lerp(-80.0, 0.0, value / 100.0)

# -------------------
# JINGLE
# -------------------

func _on_jingle_volume_changed(value: float):
	_update_jingle_volume(value)
	save_audio_settings()

func _update_jingle_volume(value: float):
	var player = get_node_or_null("/root/MessageWarningPlayer")
	if player:
		player.set_volume_db(slider_to_db(value))

# -------------------
# MUSIC
# -------------------

func _on_music_volume_changed(value: float):
	_set_bus_volume("Music", slider_to_db(value))
	save_audio_settings()

# -------------------
# NARRATOR
# -------------------

func _on_narrator_volume_changed(value: float):
	_update_narrator_volume(value)
	save_audio_settings()

func _update_narrator_volume(value: float):
	var main_ui = get_node_or_null("/root/MainUI")
	if main_ui:
		main_ui.set_narrator_volume_db(slider_to_db(value))

# -------------------
# AMBIANCE
# -------------------

func _on_ambiance_volume_changed(value: float):
	var db_value: float = slider_to_db(value)
	_set_bus_volume("Ambiance", db_value)

	if MusicManager.has_method("update_ambiance_volume"):
		MusicManager.update_ambiance_volume(db_value)

	save_audio_settings()

func get_current_ambiance_volume_db() -> float:
	return slider_to_db(ambiance_slider.value)

var ambiance_loop_player: AudioStreamPlayer
var ambiance_sfx_player: AudioStreamPlayer

func update_ambiance_volume():
	var settings_node = get_node_or_null("/root/AudioSettings")
	if settings_node:
		var volume_db = settings_node.get_current_ambiance_volume_db()
		ambiance_loop_player.volume_db = volume_db
		ambiance_sfx_player.volume_db = volume_db

# -------------------
# UI ACTIONS
# -------------------

func _on_close_pressed():
	visible = false

# -------------------
# CONFIG SAVE/LOAD
# -------------------

func save_audio_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "jingle_volume", jingle_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "narrator_volume", narrator_slider.value)
	config.set_value("audio", "ambiance_volume", ambiance_slider.value)
	config.save("user://audio_settings.cfg")

func load_audio_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		jingle_slider.value = config.get_value("audio", "jingle_volume", 100)
		music_slider.value = config.get_value("audio", "music_volume", 100)
		narrator_slider.value = config.get_value("audio", "narrator_volume", 100)
		ambiance_slider.value = config.get_value("audio", "ambiance_volume", 100)
