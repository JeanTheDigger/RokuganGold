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

	if GameManager.character_data:
		NetworkManager.rpc(
			"request_edit_character",
			GameManager.character_data.name,
			{"enter_mode": mode}
		)

func sync_from_character() -> void:
	if GameManager.character_data:
		current_enter_mode = int(GameManager.character_data.enter_mode)
		print("🔄 Sync from character: enter_mode =", current_enter_mode)
		enter_mode_changed.emit(current_enter_mode)
