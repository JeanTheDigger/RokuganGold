extends Control

@onready var whisper_button = $WhisperButton
@onready var emote_button = $EmoteButton
@onready var ooc_button = $OOCButton
@onready var tell_button = $TellButton

var character_data  # Passed from main_ui.gd


func set_character_data(data):
	character_data = data


func _on_whisper_pressed():
	var player_selection = $"../../PlayerSelection"
	player_selection.enter_state("whisper", character_data)

	var viewport_size = get_viewport_rect().size
	player_selection.global_position = (viewport_size - player_selection.size) / 2
	player_selection.visible = true


func _on_tell_pressed():
	var player_selection = $"../../PlayerSelection"
	player_selection.enter_state("tell", character_data)

	var viewport_size = get_viewport_rect().size
	player_selection.global_position = (viewport_size - player_selection.size) / 2
	player_selection.visible = true
