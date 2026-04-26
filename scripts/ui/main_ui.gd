extends Control

var local_character_name: String = ""
const ACTION_LOG_DIR := "user://StarWarsProject/logs/"
const ACTION_LOG_PATH := ACTION_LOG_DIR + "action_log.txt"



func set_character_data(character_name: String) -> void:
	# Disconnect previous message signal if needed
	if not local_character_name.is_empty() and NetworkManager.is_connected("message_received", Callable(self, "_on_message_received")):
		NetworkManager.disconnect("message_received", Callable(self, "_on_message_received"))

	local_character_name = character_name

	# Propagate data to subpanels
	$TextPanel/InputButtons.set_character_data(local_character_name)
	$ActionPanel.set_character_data(local_character_name)

	# Register this UI for the character
	GameManager.character_uis[local_character_name] = self

	# Connect signal safely
	if not NetworkManager.is_connected("message_received", Callable(self, "_on_message_received")):
		NetworkManager.connect("message_received", Callable(self, "_on_message_received"))

	print("📘 Registered UI for", local_character_name)

	# Request zone image once UI is fully prepared
	NetworkManager.rpc("request_zone_viewpoint_data", local_character_name)
	



func _ready():
	DirAccess.make_dir_recursive_absolute(ACTION_LOG_DIR)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_server_disconnected)
	
	# Prevent word wrapping in the tooltip
	var tt := $TypingTooltip
	if tt:
		# Works for Label and RichTextLabel in Godot 4.x
		tt.autowrap_mode = TextServer.AUTOWRAP_OFF


	$Decoration1/TypingIndicator.connect("gui_input", Callable(self, "_on_TypingIndicator_gui_input"))

	var image_rect: TextureRect = $ZoneImagePanel/ViewpointImage
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		
	NetworkManager.typing_update_received.connect(_on_typing_update_received)
	NetworkManager.zone_meta_received.connect(_on_zone_meta_received)

func _on_server_disconnected():
	print("💀 Disconnected from server.")
	_on_message_received({"message": "[i]The world grows dark around you.[/i]"})


func _on_storyteller_tab_pressed() -> void:
	var buttons_container = $ActionPanel/ButtonsContainer

	# Clear any existing buttons
	for child in buttons_container.get_children():
		child.queue_free()

	var actions = [
		"Create Character",
		"Possess",
		"Release",
		"Delete",
		"Teleport",
		"Teleport to Character",
		"Summon Character",
		"Test Path",
		"Test Frenzy",
		"Test Rötschreck",
		"Edit Character",
		"Describe",
		"Post Order",
		"Damage",
	]

	for action in actions:
		var button = Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(150, 30)
		button.pressed.connect(func():
			match action:
				"Create Character":
					var panel = get_node_or_null("CreateCharacterUI")
					if panel:
						panel.enter_mode(local_character_name)
					else:
						print("⚠️ CreateCharacterUI not found.")

				"Possess":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						print("✅ Possess button clicked")
						panel.enter_state("possess", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")

				"Release":
					print("🔁 Release clicked")
					get_node("/root/NetworkManager").rpc("request_release_control")
					
				"Delete":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						print("🗑️ Delete button clicked")
						panel.enter_state("delete", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")
						
				"Teleport":
					var panel = get_node_or_null("LocationSelection")
					if panel:
						print("🌀 Teleport button clicked")
						panel.enter(local_character_name, "teleport")
					else:
						print("⚠️ LocationSelection panel not found.")
						
				"Teleport to Character":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						print("🧭 Teleport to Character clicked")
						panel.enter_state("teleport_to_character", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")
						
				"Summon Character":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						print("🧲 Summon Character clicked")
						panel.enter_state("summon", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")
						
				"Test Path":
					var virtue_tester = get_node_or_null("STVirtueTester")
					if virtue_tester:
						virtue_tester.visible = true
						virtue_tester.enter_mode("path", local_character_name)
					else:
						print("⚠️ STVirtueTester not found under MainUI.")
						
				"Test Frenzy":
					var virtue_tester = get_node_or_null("STVirtueTester")
					if virtue_tester:
						virtue_tester.visible = true
						virtue_tester.enter_mode("frenzy", local_character_name)
					else:
						print("⚠️ STVirtueTester not found under MainUI.")
						
				"Test Rötschreck":
					var virtue_tester = get_node_or_null("STVirtueTester")
					if virtue_tester:
						virtue_tester.visible = true
						virtue_tester.enter_mode("rotschreck", local_character_name)
					else:
						print("⚠️ STVirtueTester not found under MainUI.")
						
				"Edit Character":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						print("✏️ Edit Character clicked")
						panel.enter_state("edit", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")
				"Describe":
					var panel = get_node_or_null("WordsInputPanel")
					if panel:
						print("📝 Describe Scene clicked")
						panel.enter_state("describe", local_character_name)
					else:
						print("⚠️ WordsInputPanel not found.")
				"Damage":
					var panel = get_node_or_null("PlayerSelection")
					if panel:
						panel.enter_state("STDamage", local_character_name)
					else:
						print("⚠️ PlayerSelection panel not found.")









		)
		buttons_container.add_child(button)


func update_viewpoint_image(path: String) -> void:
	print("🖼 Trying to load image from path:", path)
	if path == "":
		print("⚠ No path provided for viewpoint image.")
		return

	var tex = load(path)
	if tex and $ZoneImagePanel/ViewpointImage is TextureRect:
		$ZoneImagePanel/ViewpointImage.texture = tex
		print("🖼 Loaded image:", path)
	else:
		print("❌ Failed to load or apply image:", path)


func _on_message_received(data: Dictionary) -> void:
	var message = data.get("message", "")
	print("🧠 _on_message_received triggered in MainUI:", message)
	_append_message_to_action_log(message)
	var display_text = $TextPanel/DisplayText
	var sb = null
	var was_at_bottom := true
	var previous_scroll_value := 0.0
	if display_text is RichTextLabel and display_text.has_method("get_v_scroll_bar"):
		sb = display_text.get_v_scroll_bar()
		if sb:
			previous_scroll_value = sb.value
			was_at_bottom = (sb.value + sb.page) >= (sb.max_value - 1.0)
	if display_text is RichTextLabel and display_text.has_method("append_text"):
		display_text.append_text("\n" + message)
	else:
		display_text.text += "\n" + message
	if sb and not was_at_bottom:
		sb.value = previous_scroll_value


func _append_message_to_action_log(message: String) -> void:
	if message == "":
		return
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


func play_zone_description_audio(sound_path: String) -> void:
	if sound_path == "":
		print("⚠ No sound path provided for zone description.")
		return

	var stream = load(sound_path)
	if stream and $AudioPlayer:
		$AudioPlayer.stream = stream
		$AudioPlayer.play()
		print("🔊 Playing zone description audio:", sound_path)
	else:
		print("❌ Failed to load or play zone description audio:", sound_path)

func set_narrator_volume_db(value: float) -> void:
	if $AudioPlayer:
		$AudioPlayer.volume_db = value

var typers_in_zone := {}  # name → true/false

func _on_typing_update_received(data: Dictionary) -> void:
	var typer_name: String = data.get("name", "")
	var is_typing: bool = data.get("is_typing", false)
	var local_name: String = local_character_name
	
	print("📨 Typing update received from:", typer_name, "is_typing:", is_typing)

	if typer_name == local_name:
		return  # Ignore your own typing

	if is_typing:
		typers_in_zone[typer_name] = true
	else:
		typers_in_zone.erase(typer_name)

	update_typing_indicator()

func update_typing_indicator():
	var someone_typing = typers_in_zone.size() > 0
	$Decoration1/TypingIndicator.texture = preload("res://Image/UI/CandleLit.png") if someone_typing else preload("res://Image/UI/CandleUnlit.png")

func _on_TypingIndicator_mouse_entered():
	if typers_in_zone.size() == 0:
		return

	var names := typers_in_zone.keys()
	names.sort()
	# Replace spaces with non-breaking spaces so names don’t split
	for i in range(names.size()):
		names[i] = names[i].replace(" ", "\u00A0")

	var display_text := "\n".join(names)
	print("🧾 Tooltip content:", display_text)

	var tt := $TypingTooltip
	if tt:
		tt.autowrap_mode = TextServer.AUTOWRAP_OFF
		tt.text = display_text
		tt.visible = true
		tt.reset_size()  # fit to content so it won’t wrap
		tt.global_position = get_viewport().get_mouse_position() + Vector2(12, 12)


func _on_TypingIndicator_mouse_exited():
	$TypingTooltip.visible = false


func _process(_delta):
	if $TypingTooltip.visible:
		$TypingTooltip.global_position = get_viewport().get_mouse_position() + Vector2(12, 12)


func _on_TypingIndicator_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if $TypingTooltip.visible:
			$TypingTooltip.visible = false
			return

		if typers_in_zone.size() == 0:
			return

		var names := typers_in_zone.keys()
		names.sort()
		for i in range(names.size()):
			names[i] = names[i].replace(" ", "\u00A0")

		var tt := $TypingTooltip
		if tt:
			tt.autowrap_mode = TextServer.AUTOWRAP_OFF
			tt.text = "\n".join(names)
			tt.visible = true
			tt.reset_size()  # fit to content so it won’t wrap
			tt.global_position = get_viewport().get_mouse_position() + Vector2(12, 12)





func show_character_display(character_name: String, description: String, image_bytes: PackedByteArray) -> void:
	var character_display := $CharacterDisplay

	if not is_instance_valid(character_display):
		print("❌ CharacterDisplay node not found!")
		return

	# 🖼 Load the image from the byte array
	character_display.display_image(image_bytes)

	# 📝 Set the description text, if the method exists
	if character_display.has_method("set_description_text"):
		character_display.set_description_text(character_name, description)

	# ✅ Make sure the panel is visible
	character_display.visible = true
	print("📣 CharacterDisplay is now visible")


func _on_zone_meta_received(_category: String, is_neighborhood: bool) -> void:
	var ind := $ZoneImagePanel/NeighIndicator
	if is_instance_valid(ind):
		ind.visible = is_neighborhood
