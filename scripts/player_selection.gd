extends Control

@onready var option_button: OptionButton = $Panel/VBoxContainer/OptionButton
@onready var title_label: Label = $Panel/VBoxContainer/Label
@onready var cancel_button: Button = $Panel/VBoxContainer/HBoxContainer/Cancel
@onready var select_button: Button = $Panel/VBoxContainer/HBoxContainer/Select

var character_name: String = ""
var current_mode: String = ""

func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	select_button.pressed.connect(_on_select_pressed)

	if not NetworkManager.is_connected("zone_character_list_received", Callable(self, "_on_receive_zone_character_list")):
		NetworkManager.connect("zone_character_list_received", Callable(self, "_on_receive_zone_character_list"))

	if not NetworkManager.is_connected("all_character_names_received", Callable(self, "_on_receive_all_character_names")):
		NetworkManager.connect("all_character_names_received", Callable(self, "_on_receive_all_character_names"))


func enter_state(mode: String, data: String) -> void:
	current_mode = mode
	character_name = data

	option_button.clear()
	select_button.disabled = true
	title_label.text = "Who do you select?"

	match current_mode:
		"whisper", "possess", "delete", "view_description", "edit":
			NetworkManager.rpc("set_peer_mode", current_mode)
			NetworkManager.rpc("request_zone_character_list", character_name)

		"teleport_to_character", "summon", "tell", "STDamage":
			NetworkManager.rpc("set_peer_mode", current_mode)
			NetworkManager.rpc("request_all_character_names", character_name)

		_:
			print("⚠ Unknown mode passed to PlayerSelection:", current_mode)

	var viewport_size: Vector2 = get_viewport_rect().size
	global_position = (viewport_size - size) / 2
	self.visible = true


func _on_receive_zone_character_list(names: Array) -> void:
	if current_mode not in ["whisper", "possess", "delete", "view_description", "edit"]:
		return
	option_button.clear()
	for char_name_v in names:
		option_button.add_item(String(char_name_v))
	select_button.disabled = option_button.item_count == 0

func _on_receive_all_character_names(names: Array) -> void:
	if current_mode not in ["teleport_to_character", "summon", "tell", "STDamage"]:
		return
	option_button.clear()
	for char_name_v in names:
		var char_name := String(char_name_v)
		if char_name == character_name:
			continue
		option_button.add_item(char_name)
	select_button.disabled = option_button.item_count == 0


func _on_cancel_pressed() -> void:
	self.visible = false

func _on_select_pressed() -> void:
	if option_button.item_count == 0:
		return
	var selected_text: String = option_button.get_item_text(option_button.selected)

	match current_mode:
		"possess":
			NetworkManager.rpc("request_possess", selected_text)
			self.visible = false

		"delete":
			NetworkManager.rpc("request_delete_character", selected_text)
			self.visible = false

		"teleport_to_character":
			NetworkManager.rpc("request_zone_move_to", character_name, selected_text, "to_character")
			self.visible = false

		"summon":
			NetworkManager.rpc("request_zone_move_to", selected_text, character_name, "summon")
			self.visible = false

		"view_description":
			NetworkManager.rpc("request_character_description", character_name, selected_text)
			self.visible = false

		_:
			print("⚠ No selection behavior defined for mode:", current_mode)
			self.visible = false
