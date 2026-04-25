extends Node

@onready var sound_player = $SoundPlayer

func _ready():
	NetworkManager.message_received.connect(_on_message_received)

func _on_message_received(data: Dictionary) -> void:
	var speaker = data.get("speaker", "")
	var local_name: String = GameManager.local_character_name
	if local_name.is_empty():
		return

	# 🔇 Suppress sound if it's a system/time message or from yourself
	if speaker != local_name and speaker != "SYSTEM" and speaker != "Time":
		sound_player.play()

func set_volume_db(value: float):
	sound_player.volume_db = value
