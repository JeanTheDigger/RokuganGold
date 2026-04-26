extends Control

@onready var stat_list_vbox: VBoxContainer = $Panel/ScrollContainer/StatListVBox
@onready var confirm_button: Button = $Panel/HBoxContainer/Confirm
@onready var cancel_button: Button = $Panel/HBoxContainer/Cancel

var editable_inputs: Dictionary = {}      # key -> Control
var target_character_name: String = ""


# ---- helpers ----
func _as_int(v: Variant) -> int:
	match typeof(v):
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			var f: float = float(v)
			return 0 if is_nan(f) else int(f)
		TYPE_STRING:
			var s: String = String(v).strip_edges()
			return int(s.to_float()) if s.is_valid_float() or s.is_valid_int() else 0
		_:
			return 0

func _get_text_from_control(ctrl: Control) -> String:
	if ctrl is LineEdit:
		return (ctrl as LineEdit).text
	if ctrl is TextEdit:
		return (ctrl as TextEdit).text
	# Unexpected type; avoid Nil.text crash and help us find it
	print("⚠ Non-text control in editable_inputs for a text field:", ctrl)
	return ""


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false


func _on_cancel_pressed() -> void:
	visible = false


func show_character(data: Resource) -> void:
	visible = true
	target_character_name = data.name
	editable_inputs.clear()
	_clear_ui()
	_build_identity_section(data)
	_build_stat_sections(data)
	_build_extended_fields(data)


func _clear_ui() -> void:
	for c in stat_list_vbox.get_children():
		c.queue_free()


# ---------- UI build ----------
func _build_identity_section(data: Resource) -> void:
	_add_section_header("Identity")
	var fields: Array = [
		["name", data.name],
		["clan", data.clan],
		["sect", data.sect],
		["nature", data.nature],
		["demeanor", data.demeanor],
		["path_name", data.path_name],
		["is_vampire", str(data.is_vampire)],
	]
	for f in fields:
		var key: String = String(f[0])
		_add_editable_row(key, key.capitalize().replace("_", " "), str(f[1]), "string")
	_add_multiline_row("description", "Description", str(data.description))


func _build_stat_sections(data: Resource) -> void:
	_add_section_header("Attributes")
	for stat in ["strength","dexterity","stamina","charisma","manipulation","appearance","perception","intelligence","wits"]:
		_add_editable_row(stat, stat.capitalize(), _as_int(data.get(stat)), "int")

	_add_section_header("Virtues")
	for v in ["conscience","self_control","courage","conviction","instinct"]:
		_add_editable_row(v, v.capitalize().replace("_"," "), _as_int(data.get(v)), "int")

	_add_section_header("Mechanics")
	for m in ["path","generation","blood_pool","blood_pool_max","blood_per_turn","willpower_current","willpower_max","experience_points"]:
		_add_editable_row(m, m.capitalize().replace("_"," "), _as_int(data.get(m)), "int")

	_add_editable_row("health_index", "Health Index", _as_int(data.health_index), "int")

	_add_section_header("Disciplines")
	var all_disciplines: Array[String] = [
		"Animalism","Auspex","Celerity","Dominate","Fortitude","Obfuscate","Potence","Presence","Protean","Obtenebration","Thaumaturgy","Vicissitude",
		"Dementation","Chimerstry","Serpentis","Quietus","Necromancy","Mytherceria","Melpominee","Temporis","Obeah","Valeren",
		"Abombwe","Thanatosis","Visceratika"
	]
	for d in all_disciplines:
		var v: int = 0
		if typeof(data.disciplines) == TYPE_DICTIONARY and data.disciplines.has(d):
			v = _as_int(data.disciplines[d])
		_add_editable_row("disciplines/" + d, d, v, "int")

	_add_section_header("Backgrounds")
	for bg in ["allies","contacts","domain","fame","generation_background","haven","herd","influence","mentor","resources","retainers","rituals","status"]:
		_add_editable_row(bg, bg.capitalize().replace("_background"," (Background)").replace("_"," "), _as_int(data.get(bg)), "int")

	_add_section_header("Abilities")
	var abilities: Array[String] = [
		"alertness","athletics","awareness","brawl","empathy","expression","intimidation","leadership","streetwise","subterfuge",
		"animal_ken","crafts","drive","etiquette","firearms","larceny","melee","performance","stealth","survival",
		"academics","computer","finance","investigation","law","medicine","occult","politics","science","technology"
	]
	for ab in abilities:
		_add_editable_row(ab, ab.capitalize().replace("_"," "), _as_int(data.get(ab)), "int")


func _build_extended_fields(data: Resource) -> void:
	_add_section_header("Derangements (JSON Array of strings)")
	if typeof(data.derangements) == TYPE_ARRAY:
		_add_json_row("derangements_json", data.derangements)
	else:
		_add_json_row("derangements_json", [])

	_add_section_header("Merits (JSON Array of strings)")
	if typeof(data.merits) == TYPE_ARRAY:
		_add_json_row("merits_json", data.merits)
	else:
		_add_json_row("merits_json", [])

	_add_section_header("Flaws (JSON Array of strings)")
	if typeof(data.flaws) == TYPE_ARRAY:
		_add_json_row("flaws_json", data.flaws)
	else:
		_add_json_row("flaws_json", [])

	_add_section_header("Blood Bonds (JSON Object: name -> stage 0..3)")
	if typeof(data.blood_bonds) == TYPE_DICTIONARY:
		_add_json_row("blood_bonds_json", data.blood_bonds)
	else:
		_add_json_row("blood_bonds_json", {})

	_add_section_header("Vinculum (JSON Object: name -> rating 0..10)")
	if typeof(data.vinculum) == TYPE_DICTIONARY:
		_add_json_row("vinculum_json", data.vinculum)
	else:
		_add_json_row("vinculum_json", {})

	_add_section_header("Ability Specialties (JSON Array of \"ability_key:specialty\")")
	if typeof(data.ability_specialties) == TYPE_ARRAY:
		_add_json_row("ability_specialties_json", data.ability_specialties)
	else:
		_add_json_row("ability_specialties_json", [])

	_add_section_header("Thaumaturgy Paths (JSON Array of \"Path Name:rating\")")
	if typeof(data.thaumaturgy_paths) == TYPE_ARRAY:
		_add_json_row("thaumaturgy_paths_json", data.thaumaturgy_paths)
	else:
		_add_json_row("thaumaturgy_paths_json", [])

	_add_section_header("Thaumaturgy Rituals (JSON Array of \"level:ritual name\")")
	if typeof(data.thaumaturgy_rituals) == TYPE_ARRAY:
		_add_json_row("thaumaturgy_rituals_json", data.thaumaturgy_rituals)
	else:
		_add_json_row("thaumaturgy_rituals_json", [])

	_add_section_header("Necromancy Paths (JSON Array of \"Path Name:rating\")")
	if typeof(data.necromancy_paths) == TYPE_ARRAY:
		_add_json_row("necromancy_paths_json", data.necromancy_paths)
	else:
		_add_json_row("necromancy_paths_json", [])

	_add_section_header("Necromancy Rituals (JSON Array of \"level:ritual name\")")
	if typeof(data.necromancy_rituals) == TYPE_ARRAY:
		_add_json_row("necromancy_rituals_json", data.necromancy_rituals)
	else:
		_add_json_row("necromancy_rituals_json", [])


# ---------- row builders ----------
func _add_section_header(title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color.DARK_RED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 16)
	stat_list_vbox.add_child(l)


func _add_editable_row(key: String, label_text: String, value: Variant, value_type: String) -> void:
	var row := HBoxContainer.new()

	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(180, 0)
	row.add_child(lab)

	var input: Control
	if value_type == "int":
		var sb := SpinBox.new()
		sb.step = 1.0
		sb.min_value = -1000000.0   # finite bounds to avoid NaN
		sb.max_value =  1000000.0
		sb.allow_lesser = true
		sb.allow_greater = true
		sb.value = _as_int(value)
		input = sb
	else:
		var le := LineEdit.new()
		le.text = str(value)
		le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		input = le

	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	stat_list_vbox.add_child(row)
	editable_inputs[key] = input


func _add_multiline_row(key: String, label_text: String, value: String) -> void:
	var l := Label.new()
	l.text = label_text
	stat_list_vbox.add_child(l)

	var te := TextEdit.new()
	te.text = value
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.custom_minimum_size = Vector2(0, 120)
	stat_list_vbox.add_child(te)
	editable_inputs[key] = te


func _add_json_row(key: String, value: Variant) -> void:
	var te := TextEdit.new()
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(0, 140)
	var json_text: String = JSON.stringify(value, "  ")
	if json_text == "":
		if typeof(value) == TYPE_ARRAY:
			json_text = "[]"
		else:
			json_text = "{}"
	te.text = json_text
	stat_list_vbox.add_child(te)
	editable_inputs[key] = te


# ---------- submit ----------
func _on_confirm_pressed() -> void:
	var change_dict: Dictionary = {}
	var disciplines_out: Dictionary = {}

	for key in editable_inputs.keys():
		var ctrl: Control = editable_inputs[key]

		if ctrl is SpinBox:
			var ival: int = _as_int((ctrl as SpinBox).value)
			if key.begins_with("disciplines/"):
				disciplines_out[key.get_slice("/", 1)] = ival
			else:
				change_dict[key] = ival
			continue

		var text_val: String = _get_text_from_control(ctrl)  # safe getter

		if key.ends_with("_json"):
			var trimmed: String = text_val.strip_edges()
			var real_key: String = key.substr(0, key.length() - 5)

			if trimmed == "":
				if real_key in ["blood_bonds", "vinculum"]:
					change_dict[real_key] = {}
				else:
					change_dict[real_key] = []
			else:
				var parsed: Variant = JSON.parse_string(trimmed)
				if real_key in ["blood_bonds", "vinculum"]:
					var out: Dictionary = {}
					if typeof(parsed) == TYPE_DICTIONARY:
						for k in (parsed as Dictionary).keys():
							out[String(k)] = _as_int((parsed as Dictionary)[k])
					change_dict[real_key] = out
				else:
					if typeof(parsed) == TYPE_ARRAY:
						change_dict[real_key] = parsed
					else:
						change_dict[real_key] = []
			continue

		# ✅ Convert boolean string for is_vampire
		if key == "is_vampire":
			change_dict[key] = text_val.to_lower() == "true"
		else:
			change_dict[key] = text_val

	change_dict["disciplines"] = disciplines_out

	print("🛠 Submitting changes to character:", target_character_name)
	NetworkManager.rpc("request_edit_character", target_character_name, change_dict)
	visible = false


func load_character(character_name: String) -> void:
	target_character_name = character_name
	editable_inputs.clear()
	_clear_ui()
	NetworkManager.rpc("request_character_data_for_edit", character_name)


func receive_character_data(data: Resource) -> void:
	show_character(data)
