extends Node

signal enter_mode_changed(mode: int)

enum EnterMode { NO_ENTER, ENTER, SHIFT_ENTER }
var current_enter_mode: int = EnterMode.NO_ENTER

func _ready():
	print("🛠 SettingsManager loaded")


func set_enter_mode(mode: int) -> void:
	mode = int(mode)
	if current_enter_mode == mode:
		return

	current_enter_mode = mode
	enter_mode_changed.emit(mode)

	print("📤 Calling RPC: request_edit_character →", mode)

	var char_name: String = GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), "")
	if not char_name.is_empty():
		NetworkManager.rpc(
			"request_edit_character",
			char_name,
			{"enter_mode": mode}
		)

func sync_from_character_data(data: CharacterData) -> void:
	current_enter_mode = int(data.enter_mode)
	print("🔄 Sync from character: enter_mode =", current_enter_mode)
	enter_mode_changed.emit(current_enter_mode)
