extends Control

@onready var buttons_container = $ButtonsContainer
@onready var display_text = $"../TextPanel/DisplayText"

const CHAT_DIVIDER := "[color=gray]────────────────────[/color]\n"
const ACTION_LOG_DIR := "user://StarWarsProject/logs/"
const ACTION_LOG_PATH := ACTION_LOG_DIR + "action_log.txt"

var local_character_name: String = ""

func _ready():
	buttons_container.custom_minimum_size = Vector2(300, 200)


	# Ensure BBCode renders properly.
	if display_text is RichTextLabel:
		display_text.bbcode_enabled = true

	# Connect to signals from the NetworkManager
	if not NetworkManager.is_connected("zone_character_list_received", Callable(self, "_on_zone_character_list_received")):
		NetworkManager.connect("zone_character_list_received", Callable(self, "_on_zone_character_list_received"))

	if not NetworkManager.is_connected("zone_name_received", Callable(self, "_on_zone_name_received")):
		NetworkManager.connect("zone_name_received", Callable(self, "_on_zone_name_received"))

	if not NetworkManager.is_connected("zone_description_received", Callable(self, "_on_zone_description_received")):
		NetworkManager.connect("zone_description_received", Callable(self, "_on_zone_description_received"))

func set_character_data(data):
	local_character_name = data

func _on_tab_changed(tab_index: int) -> void:
	for child in buttons_container.get_children():
		child.queue_free()

	match tab_index:
		0:
			_add_button("Move")
			_add_button("Secret Move")
			_add_button("Temporary Zone")
			_add_button("Where?")
			_add_button("Who?")
			_add_button("View Character")
			_add_button("Description")
			_add_button("Viewpoint")
		1:
			_add_button("Nightly Activities")
			_add_button("Dice Roller")
			_add_button("Dice Roller Custom")
			_add_button("Group")
		2:
			_add_button("Write Description")
			_add_button("Character Sheet")
			_add_button("Inventory")
			_add_button("Notes")
			_add_button("Date")
		3:
			_add_button("Heal")
			_add_button("Physical Attributes")
		4:
			_add_button("Sounds")
			_add_button("Settings")
			_add_button("Image")
			_add_button("See Self-Image")
			_add_button("Save")
		_:
			pass

func _add_button(text: String) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 30)
	button.pressed.connect(func(): _on_button_pressed(text))
	buttons_container.add_child(button)

func _on_button_pressed(action: String) -> void:
	print("Button pressed:", action)

	match action:
		"Move":
			var location_selection = get_parent().get_node("LocationSelection")
			location_selection.enter(local_character_name)
		"Viewpoint":
			var location_selection = get_parent().get_node("LocationSelection")
			location_selection.enter(local_character_name, "viewpoint")
		"Where?":
			NetworkManager.rpc("request_zone_name", local_character_name)
		"Who?":
			NetworkManager.rpc("request_zone_character_list", local_character_name)
		"Description":
			NetworkManager.rpc("request_zone_description", local_character_name)
		"Dice Roller":
			var dice_roller = get_parent().get_node("DiceRollerUI")
			dice_roller.enter_state("roll", local_character_name)
		"Dice Roller Custom":
			var dice_roller = get_parent().get_node("DiceRollerUI")
			dice_roller.enter_state("custom", local_character_name)
		"Character Sheet":
			var sheet_ui = get_parent().get_node("CharacterSheetUI")
			sheet_ui.load_character(local_character_name)
		"Secret Move":
			var words_input = get_parent().get_node("WordsInputPanel")
			words_input.enter_state("secret_move", local_character_name)
		"Save":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			var words_input = get_node("/root/MainUI/WordsInputPanel")
			words_input.enter_state("set_password", local_character_name)
		"Write Description":
			var words_input = get_parent().get_node("WordsInputPanel")
			words_input.enter_state("write_description", local_character_name)
		"View Character":
			var player_selection = get_parent().get_node("PlayerSelection")
			player_selection.enter_state("view_description", local_character_name)
		"Temporary Zone":
			if local_character_name.is_empty():
				_append_to_display("\n No character loaded.")
				return
			var words_input = get_parent().get_node("WordsInputPanel")
			words_input.custom_zone_payload = {}  # reset temp storage
			words_input.enter_state("custom_move_zone_name", local_character_name)
		"Notes":
			var words_input = get_parent().get_node("WordsInputPanel")
			words_input.enter_state("write_notes", local_character_name)
		"Sounds":
			var sound_ui = get_parent().get_node_or_null("AudioSettingsUI")
			if sound_ui:
				sound_ui.visible = true
			else:
				print("⚠️ AudioSettingsUI not found.")
		"Settings":
			var settings_panel = get_parent().get_node_or_null("Settings")
			if settings_panel:
				settings_panel.visible = true
			else:
				print("❌ Settings not found.")
		"Image":
			var file_selector = get_parent().get_node_or_null("FileSelector")
			if file_selector:
				file_selector.show()
				file_selector.open_selector()
			else:
				print("❌ FileSelector not found.")
		"See Self-Image":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			NetworkManager.rpc("request_self_image_preview", local_character_name)
		"Group":
			var group_menu = get_parent().get_node_or_null("GroupMenu")
			if group_menu:
				group_menu.visible = true
			else:
				_append_to_display("\n❌ Group Menu not found.")
		"Date":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			NetworkManager.rpc("request_current_ic_time", local_character_name)
		"Nightly Activities":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			var nightly_ui = get_parent().get_node_or_null("NightlyActivitiesUI")
			if nightly_ui:
				nightly_ui.visible = true
				NetworkManager.rpc("request_nightly_activities_data", local_character_name)
				NetworkManager.rpc("request_group_summary", local_character_name)
			else:
				_append_to_display("\n❌ NightlyActivitiesUI not found.")
		"Heal":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			var heal_panel = get_parent().get_node_or_null("HealPanel")
			if heal_panel:
				heal_panel.visible = true
				if heal_panel.has_method("set_character_data"):
					heal_panel.set_character_data(local_character_name)
			else:
				_append_to_display("\n❌ HealPanel not found.")
		"Inventory":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			var inventory_menu = get_parent().get_node_or_null("InventoryMenu")
			if inventory_menu:
				inventory_menu.visible = true
			else:
				_append_to_display("\n❌ InventoryMenu not found.")
		"Physical Attributes":
			if local_character_name.is_empty():
				_append_to_display("\n❌ No character loaded.")
				return
			var inc_ui = get_parent().get_node_or_null("IncreasePhysicalAttributesUI")
			if inc_ui:
				inc_ui.enter(local_character_name)
			else:
				_append_to_display("\n❌ IncreasePhysicalAttributesUI not found.")
		_:
			_append_to_display("\nPressed: " + action)



# === Signal Handlers from Server ===

func _on_zone_character_list_received(names: Array):
	var msg := ""
	if names.size() == 1 and names[0] == "The city stretches all around you.":
		msg = "The city stretches all around you."
	elif names.is_empty():
		msg = "There is no one of note in this area."
	else:
		msg = "Others in this zone: " + ", ".join(names)

	_append_to_display("\n" + CHAT_DIVIDER + msg)

func _on_zone_name_received(zone_name: String):
	_append_to_display("\n" + CHAT_DIVIDER + " You are currently in: [b]%s[/b]" % zone_name)

func _on_zone_description_received(data: Dictionary):
	var desc = data.get("description", "")
	var sound_path = data.get("sound_path", "")

	_append_to_display("\n" + CHAT_DIVIDER + "[b]Zone Description:[/b]\n" + desc)

	if sound_path != "":
		var main_ui = get_tree().get_root().get_node_or_null("MainUI")
		if main_ui:
			main_ui.play_zone_description_audio(sound_path)
		else:
			print("❌ MainUI not found.")

# === Append helpers (no jump if user scrolled up) ===

func _is_scrolled_to_bottom(rtl: RichTextLabel) -> bool:
	var sb = null
	if rtl.has_method("get_v_scroll_bar"):
		sb = rtl.get_v_scroll_bar()
	elif rtl.has_method("get_v_scroll"):
		sb = rtl.get_v_scroll()
	if sb == null:
		return true
	return (sb.value + sb.page) >= (sb.max_value - 1.0)

func _append_to_display(bbtext: String) -> void:
	var follow := _is_scrolled_to_bottom(display_text)
	_append_message_to_action_log(bbtext)
	# Prefer append_text to avoid reassigning .text which resets scroll.
	if display_text is RichTextLabel and display_text.has_method("append_text"):
		display_text.append_text(bbtext)
	else:
		display_text.text += bbtext
	if follow:
		if display_text.has_method("scroll_to_line"):
			display_text.scroll_to_line(display_text.get_line_count() - 1)
		else:
			var sb = null
			if display_text.has_method("get_v_scroll_bar"):
				sb = display_text.get_v_scroll_bar()
			elif display_text.has_method("get_v_scroll"):
				sb = display_text.get_v_scroll()
			if sb:
				sb.value = sb.max_value


func _append_message_to_action_log(message: String) -> void:
	if message == "":
		return
	DirAccess.make_dir_recursive_absolute(ACTION_LOG_DIR)
	var file := FileAccess.open(ACTION_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(ACTION_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open action log file: %s (err %s)" % [ACTION_LOG_PATH, str(FileAccess.get_open_error())])
		return
	file.seek_end()
	file.store_line(_bbcode_to_plain_text(message))


func _bbcode_to_plain_text(message: String) -> String:
	var regex := RegEx.new()
	var compile_result := regex.compile("\\[[^\\]]+\\]")
	if compile_result != OK:
		return message
	return regex.sub(message, "", true)
