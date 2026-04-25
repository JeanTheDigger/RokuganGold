extends Control

@onready var input_box = $WordsInputPanelPanel/VBoxContainer/InputBox
@onready var cancel_button = $WordsInputPanelPanel/VBoxContainer/HBoxContainer/CancelButton
@onready var send_button = $WordsInputPanelPanel/VBoxContainer/HBoxContainer/SendButton

var whisper_target: String = ""
var dragging := false
var drag_offset := Vector2.ZERO
var current_state: String = ""
var character_data  # Stores character info during open state
var custom_zone_payload := {}

var saved_position: Vector2 = Vector2.ZERO
var position_saved: bool = false

func _ready():
	input_box.gui_input.connect(_on_input_box_gui_input)
	cancel_button.pressed.connect(_on_cancel_pressed)
	send_button.pressed.connect(_on_send_pressed)

func enter_state(state_name: String, data, target_name := "") -> void:
	print("📣 enter_state called with:", state_name, target_name)
	print("📦 Incoming data for enter_state:", data)

	current_state = state_name
	character_data = data
	whisper_target = target_name

	_update_prompt_label()

	if state_name == "write_description":
		if character_data != null:
			input_box.text = "Loading description..."
			var name_value = character_data.name
			NetworkManager.request_character_data_for_description(self, name_value)
		else:
			print("❌ character_data is NULL")
			input_box.text = ""
	elif state_name == "write_notes":
		if character_data != null:
			input_box.text = character_data.notes
		else:
			print("❌ character_data is NULL")
			input_box.text = ""
	else:
		input_box.text = ""

	apply_saved_position()
	self.visible = true
	input_box.grab_focus()

	if ["speak", "emote", "whisper", "ooc", "describe"].has(state_name):
		NetworkManager.rpc("report_typing_state", {
			"name": character_data.name,
			"is_typing": true,
			"mode": state_name
		})

func _update_prompt_label() -> void:
	var vbox := $WordsInputPanelPanel/VBoxContainer

	# 🚫 Remove all Label nodes at the top
	for child in vbox.get_children():
		if child is Label:
			vbox.remove_child(child)
			child.queue_free()

	# ✅ Now create a new one
	var label = Label.new()
	label.name = "PromptLabel"
	label.text = _format_state_title(current_state)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color.BLACK
	vbox.add_child(label)
	vbox.move_child(label, 0)

func _format_state_title(state: String) -> String:
	match state:
		"speak": return "Speak"
		"whisper": return "Whisper"
		"emote": return "Emote"
		"ooc": return "Out of Character"
		"tell": return "Tell"
		"secret_move": return "Secret Move"
		"set_password": return "Set Password"
		"write_description": return "Edit Description"
		"write_notes": return "Edit Notes"
		"custom_move_zone_name": return "Custom Zone Name"
		"custom_move_password": return "Custom Zone Password"
		"custom_move_description": return "Custom Zone Description"
		"describe": return "Describe the Scene"
		_: return state.capitalize()

func receive_fresh_description_resource(data: Resource) -> void:
	if current_state == "write_description" and data.name == character_data.name:
		input_box.text = data.description

func _on_send_pressed() -> void:
	var message = input_box.text.strip_edges()

	if message.is_empty():
		print("⚠ Aborted: message is empty")
		return

	if character_data == null:
		print("⚠ Aborted: character_data is null")
		return

	match current_state:
		"speak":
			NetworkManager.rpc("handle_incoming_message", {
				"type": "speak", "speaker": character_data.name, "message": message })
		"whisper":
			if whisper_target == "":
				print("⚠ No whisper target specified")
				return
			NetworkManager.rpc("handle_incoming_message", {
				"type": "whisper", "speaker": character_data.name, "target": whisper_target, "message": message })
		"emote":
			NetworkManager.rpc("handle_incoming_message", {
				"type": "emote", "speaker": character_data.name, "message": message })
		"ooc":
			NetworkManager.rpc("handle_incoming_message", {
				"type": "ooc", "speaker": character_data.name, "message": message })
		"tell":
			if whisper_target == "":
				print("⚠ No tell target specified")
				return
			NetworkManager.rpc("handle_incoming_message", {
				"type": "tell", "speaker": character_data.name, "target": whisper_target, "message": message })
		"secret_move":
			NetworkManager.rpc("request_zone_move_to", character_data.name, message, "secret")
		"set_password":
			if message.length() < 4:
				print("⚠ Password too short.")
				return
			character_data.character_password = message
			NetworkManager.rpc("request_save_character", character_data.serialize_to_dict())
		"write_description":
			NetworkManager.rpc("set_character_description", character_data.name, message)
		"write_notes":
			character_data.notes = message
			NetworkManager.rpc("set_character_notes", character_data.name, message)
		"custom_move_zone_name":
			custom_zone_payload["name"] = message
			enter_state("custom_move_password", character_data)
			return
		"custom_move_password":
			custom_zone_payload["password"] = message
			enter_state("custom_move_description", character_data)
			return
		"custom_move_description":
			custom_zone_payload["description"] = message
			custom_zone_payload["creator"] = character_data.name
			custom_zone_payload["origin_zone"] = character_data.current_zone
			NetworkManager.rpc("request_create_temp_zone", custom_zone_payload)
			custom_zone_payload = {}
			remember_position()
			self.visible = false
			whisper_target = ""
		"describe":
			NetworkManager.rpc("handle_incoming_message", {
				"type": "describe", "speaker": character_data.name, "message": message })



	if ["speak", "emote", "whisper", "ooc", "describe"].has(current_state):
		NetworkManager.rpc("report_typing_state", {
			"name": character_data.name, "is_typing": false, "mode": current_state })

	remember_position()
	self.visible = false
	whisper_target = ""
	print("🧹 Input panel hidden and position remembered")

func _on_cancel_pressed() -> void:
	remember_position()
	self.visible = false
	whisper_target = ""

	if ["speak", "emote", "whisper", "ooc", "describe"].has(current_state):
		NetworkManager.rpc("report_typing_state", {
			"name": character_data.name, "is_typing": false, "mode": current_state })

func _on_input_box_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var mode = SettingsManager.current_enter_mode

		if mode == SettingsManager.EnterMode.ENTER:
			if event.keycode == KEY_ENTER and not event.shift_pressed:
				_on_send_pressed()
				get_tree().root.set_input_as_handled()
			elif event.keycode == KEY_ENTER and event.shift_pressed:
				input_box.insert_text_at_caret("\n")
				get_tree().root.set_input_as_handled()

		elif mode == SettingsManager.EnterMode.SHIFT_ENTER:
			if event.keycode == KEY_ENTER and event.shift_pressed:
				_on_send_pressed()
				get_tree().root.set_input_as_handled()
			elif event.keycode == KEY_ENTER and not event.shift_pressed:
				input_box.insert_text_at_caret("\n")
				get_tree().root.set_input_as_handled()

		elif mode == SettingsManager.EnterMode.NO_ENTER:
			if event.keycode == KEY_ENTER:
				input_box.insert_text_at_caret("\n")
				get_tree().root.set_input_as_handled()



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func remember_position() -> void:
	saved_position = global_position
	position_saved = true

func apply_saved_position() -> void:
	if position_saved:
		global_position = saved_position
	else:
		var viewport_size = get_viewport_rect().size
		global_position = (viewport_size - size) / 2
