extends Control

@onready var stat_list_vbox = $Panel/ScrollContainer/StatListVBox
@onready var confirm_button = $Panel/HBoxContainer/Confirm
@onready var cancel_button = $Panel/HBoxContainer/Cancel

var editable_inputs := {}  # key -> Control

func _ready():
	cancel_button.pressed.connect(func(): self.visible = false)
	confirm_button.pressed.connect(_on_confirm_pressed)
	self.visible = false

# === ENTRY POINT ===
func enter_mode(_storyteller_data: Resource) -> void:
	self.visible = true
	editable_inputs.clear()
	_clear_ui()
	_build_identity_section_defaults()
	_build_stat_sections_defaults()
	_build_extended_fields_defaults()

# === BUILD UI ===

func _clear_ui():
	for child in stat_list_vbox.get_children():
		child.queue_free()

func _build_identity_section_defaults():
	_add_section_header("Identity")
	_add_editable_row("name", "Name", "", "string")
	_add_editable_row("clan", "Clan", "", "string")
	_add_editable_row("sect", "Sect", "", "string")
	_add_editable_row("nature", "Nature", "", "string")
	_add_editable_row("demeanor", "Demeanor", "", "string")
	_add_editable_row("path_name", "Path Name", "", "string")
	_add_multiline_row("description", "Description", "")

func _build_stat_sections_defaults():
	_add_section_header("Attributes")
	for stat in ["strength","dexterity","stamina","charisma","manipulation","appearance","perception","intelligence","wits"]:
		_add_editable_row(stat, stat.capitalize(), 1, "int")

	_add_section_header("Virtues")
	for virtue in ["conscience","self_control","courage","conviction","instinct"]:
		_add_editable_row(virtue, virtue.capitalize().replace("_"," "), 1, "int")

	_add_section_header("Mechanics")
	for mech in [
		"path","generation","blood_pool","blood_pool_max","blood_per_turn",
		"willpower_current","willpower_max","experience_points"
	]:
		var default_val := 1
		if mech in ["generation","experience_points"]: default_val = 0
		if mech in ["blood_pool","blood_pool_max"]: default_val = 0
		if mech == "blood_per_turn": default_val = 1
		_add_editable_row(mech, mech.capitalize().replace("_"," "), default_val, "int")
	_add_editable_row("health_index", "Health Index", 7, "int")

	_add_section_header("Disciplines")
	var all_disciplines = [
		"Animalism","Auspex","Celerity","Dominate","Fortitude","Obfuscate","Potence","Presence","Protean","Obtenebration","Thaumaturgy","Vicissitude",
		"Dementation","Chimerstry","Serpentis","Quietus","Necromancy","Mytherceria","Melpominee","Temporis","Obeah","Valeren",
		"Abombwe","Thanatosis","Visceratika"
	]
	for disc in all_disciplines:
		_add_editable_row("disciplines/" + disc, disc, 0, "int")

	_add_section_header("Backgrounds")
	for bg in [
		"allies","contacts","domain","fame","generation_background","haven","herd",
		"influence","mentor","resources","retainers","rituals","status"
	]:
		_add_editable_row(bg, bg.capitalize().replace("_background"," (Background)").replace("_"," "), 0, "int")

	_add_section_header("Abilities")
	var abilities = [
		"alertness","athletics","awareness","brawl","empathy","expression","intimidation","leadership","streetwise","subterfuge",
		"animal_ken","crafts","drive","etiquette","firearms","larceny","melee","performance","stealth","survival",
		"academics","computer","finance","investigation","law","medicine","occult","politics","science","technology"
	]
	for ab in abilities:
		_add_editable_row(ab, ab.capitalize().replace("_"," "), 0, "int")

func _build_extended_fields_defaults():
	_add_section_header("Derangements (JSON Array of strings)")
	_add_json_row("derangements_json", [])

	_add_section_header("Merits (JSON Array of strings)")
	_add_json_row("merits_json", [])

	_add_section_header("Flaws (JSON Array of strings)")
	_add_json_row("flaws_json", [])

	_add_section_header("Blood Bonds (JSON Object: name -> stage 0..3)")
	_add_json_row("blood_bonds_json", {})

	_add_section_header("Vinculum (JSON Object: name -> rating 0..10)")
	_add_json_row("vinculum_json", {})

	_add_section_header("Ability Specialties (JSON Array of \"ability_key:specialty\")")
	_add_json_row("ability_specialties_json", [])

	_add_section_header("Thaumaturgy Paths (JSON Array of \"Path Name:rating\")")
	_add_json_row("thaumaturgy_paths_json", [])

	_add_section_header("Thaumaturgy Rituals (JSON Array of \"level:ritual name\")")
	_add_json_row("thaumaturgy_rituals_json", [])

	_add_section_header("Necromancy Paths (JSON Array of \"Path Name:rating\")")
	_add_json_row("necromancy_paths_json", [])

	_add_section_header("Necromancy Rituals (JSON Array of \"level:ritual name\")")
	_add_json_row("necromancy_rituals_json", [])

# === UI Helpers ===

func _add_section_header(title: String):
	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color.DARK_RED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	stat_list_vbox.add_child(label)

func _add_editable_row(key: String, label_text: String, value, value_type: String):
	var row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)

	var input
	if value_type == "int":
		var sp = SpinBox.new()
		sp.min_value = 0
		sp.max_value = 10
		sp.step = 1
		sp.value = int(value)
		input = sp
	else:
		var le = LineEdit.new()
		le.text = str(value)
		le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		input = le

	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	stat_list_vbox.add_child(row)
	editable_inputs[key] = input

func _add_multiline_row(key: String, label_text: String, value: String):
	var label = Label.new()
	label.text = label_text
	stat_list_vbox.add_child(label)

	var input = TextEdit.new()
	input.text = value
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 120)
	stat_list_vbox.add_child(input)

	editable_inputs[key] = input

func _add_json_row(key: String, value: Variant):
	var input = TextEdit.new()
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.custom_minimum_size = Vector2(0, 140)
	var json_text = JSON.stringify(value, "  ")
	if json_text == "":
		json_text = "[]" if typeof(value) == TYPE_ARRAY else "{}"
	input.text = json_text
	stat_list_vbox.add_child(input)
	editable_inputs[key] = input

# === Confirm ===

func _on_confirm_pressed():
	var character_dict := {}
	var disciplines_dict := {}

	for key in editable_inputs.keys():
		var control = editable_inputs[key]

		# SpinBox values are ints
		if control is SpinBox:
			var ival = int(control.value)
			if key.begins_with("disciplines/"):
				disciplines_dict[key.get_slice("/", 1)] = ival
			else:
				character_dict[key] = ival
			continue

		# TextEdit / LineEdit values are strings
		var text_value = String(control.text)

		# JSON blocks
		if key.ends_with("_json"):
			var trimmed = text_value.strip_edges()
			var real = key.substr(0, key.length() - 5)

			if trimmed == "":
				if real == "blood_bonds" or real == "vinculum":
					character_dict[real] = {}
				else:
					character_dict[real] = []
			else:
				var parsed = JSON.parse_string(trimmed)
				if real == "blood_bonds" or real == "vinculum":
					var out_dict := {}
					if typeof(parsed) == TYPE_DICTIONARY:
						for k in parsed.keys():
							out_dict[String(k)] = int(parsed[k])
					character_dict[real] = out_dict
				else:
					if typeof(parsed) == TYPE_ARRAY:
						character_dict[real] = parsed
					else:
						character_dict[real] = []
			continue

		# Plain strings
		character_dict[key] = text_value

	# Bundle disciplines and set ST flag
	character_dict["disciplines"] = disciplines_dict
	character_dict["is_storyteller"] = false

	# Send to server
	NetworkManager.rpc("request_create_character", character_dict, GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), ""))
	self.visible = false
