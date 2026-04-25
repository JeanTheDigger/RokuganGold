extends Control

@onready var stat_list_vbox: VBoxContainer = $Panel/ScrollContainer/StatListVBox
@onready var confirm_button: Button = $Panel/HBoxContainer/Confirm

var DERANGEMENTS := {
	"bipolar_disorder": "Bipolar Disorder",
	"bulimia": "Bulimia",
	"fugue": "Fugue",
	"hysteria": "Hysteria",
	"megalomania": "Megalomania",
	"multiple_personalities": "Multiple Personalities",
	"obsessive_compulsive": "Obsessive-Compulsive",
	"paranoia": "Paranoia",
	"sanguinary_animism": "Sanguinary Animism",
	"schizophrenia": "Schizophrenia"
}

var HEALTH_LEVELS := {
	0: "Healthy",
	1: "Bruised",
	2: "Hurt",
	3: "Injured",
	4: "Wounded",
	5: "Mauled",
	6: "Crippled",
	7: "Incapacitated"
}

func _ready() -> void:
	confirm_button.pressed.connect(func(): self.visible = false)
	self.visible = false

func load_character(character_name: String) -> void:
	_clear_ui()
	NetworkManager.rpc("request_character_data_for_view", character_name)

func receive_character_data(data: Resource) -> void:
	show_character(data)

func show_character(data: Resource) -> void:
	print("🧪 Showing Character Sheet:", data.name)
	self.visible = true
	_clear_ui()
	_build_identity_section(data)
	_build_stat_sections(data)

func _clear_ui() -> void:
	for child in stat_list_vbox.get_children():
		child.queue_free()

func _build_identity_section(data: Resource) -> void:
	_add_section_header("Identity")
	var identity_fields: Array = [
		["Name", data.name],
		["Clan", data.clan],
		["Sect", data.sect],
		["Nature", data.nature],
		["Demeanor", data.demeanor],
		["Path Name", data.path_name],
	]
	for item in identity_fields:
		stat_list_vbox.add_child(_create_stat_row(String(item[0]), str(item[1])))

func _build_stat_sections(data: Resource) -> void:
	_add_section_header("Attributes")
	for stat in ["Strength", "Dexterity", "Stamina", "Charisma", "Manipulation", "Appearance", "Perception", "Intelligence", "Wits"]:
		stat_list_vbox.add_child(_create_stat_row(stat, str(data.get(stat.to_lower()))))

	_add_section_header("Virtues")
	for virtue in ["Conscience", "Self_Control", "Courage", "Conviction", "Instinct"]:
		var key: String = virtue.to_lower()
		var value = data.get(key)
		value = 0 if typeof(value) == TYPE_NIL else value
		if int(value) > 0:
			stat_list_vbox.add_child(_create_stat_row(virtue.replace("_", " "), str(value)))

	_add_section_header("Mechanics")
	for mech in [
		"Path",
		"Generation",
		"Blood_Pool",
		"Blood_Pool_Max",
		"Blood_Per_Turn",
		"Willpower_Current",
		"Willpower_Max",
		"Experience_Points"
	]:
		stat_list_vbox.add_child(_create_stat_row(mech.replace("_", " "), str(data.get(mech.to_lower()))))

	var health_index: int = int(data.health_index)
	var health_label: String = HEALTH_LEVELS.get(health_index, "Unknown")
	stat_list_vbox.add_child(_create_stat_row("Health Level", health_label))

	# --- Aggravated Damage count (from dated entries) ---
	var agg_count: int = 0
	var maybe_agg = data.get("aggravated_wounds")
	if typeof(maybe_agg) == TYPE_ARRAY:
		agg_count = (maybe_agg as Array).size()
	stat_list_vbox.add_child(_create_stat_row("Aggravated Damage", str(agg_count)))

	_add_section_header("Disciplines")
	for disc in data.disciplines.keys():
		var value = data.disciplines[disc]
		if int(value) > 0:
			stat_list_vbox.add_child(_create_stat_row(disc, str(value)))

	if data.thaumaturgy_paths.size() > 0:
		_add_section_header("Thaumaturgy Paths")
		for i in range(data.thaumaturgy_paths.size()):
			var entry: String = data.thaumaturgy_paths[i]
			var parts: Array = entry.split(":", false, 1)
			var path_name: String = parts[0]
			var rating: String = parts[1] if parts.size() > 1 else ""
			var label_text: String = path_name + (" (Primary)" if i == 0 else "")
			stat_list_vbox.add_child(_create_stat_row(label_text, rating))

	if data.thaumaturgy_rituals.size() > 0:
		_add_section_header("Thaumaturgy Rituals")
		for entry in data.thaumaturgy_rituals:
			var parts: Array = entry.split(":", false, 1)
			var level_text: String = parts[0]
			var ritual_name: String = parts[1] if parts.size() > 1 else ""
			stat_list_vbox.add_child(_create_stat_row("Level " + level_text, ritual_name))

	if data.necromancy_paths.size() > 0:
		_add_section_header("Necromancy Paths")
		for i in range(data.necromancy_paths.size()):
			var entry: String = data.necromancy_paths[i]
			var parts: Array = entry.split(":", false, 1)
			var path_name: String = parts[0]
			var rating: String = parts[1] if parts.size() > 1 else ""
			var label_text: String = path_name + (" (Primary)" if i == 0 else "")
			stat_list_vbox.add_child(_create_stat_row(label_text, rating))

	if data.necromancy_rituals.size() > 0:
		_add_section_header("Necromancy Rituals")
		for entry in data.necromancy_rituals:
			var parts: Array = entry.split(":", false, 1)
			var level_text: String = parts[0]
			var ritual_name: String = parts[1] if parts.size() > 1 else ""
			stat_list_vbox.add_child(_create_stat_row("Level " + level_text, ritual_name))

	_add_section_header("Backgrounds")
	var background_names: Array = [
		"allies", "contacts", "domain", "fame", "generation_background",
		"haven", "herd", "influence", "mentor", "resources",
		"retainers", "rituals", "status"
	]
	for bg in background_names:
		var value_bg = data.get(bg)
		if int(value_bg) > 0:
			stat_list_vbox.add_child(_create_stat_row(
				bg.capitalize().replace("_background", " (Background)"),
				str(value_bg)
			))

	_add_section_header("Abilities")
	var ability_names: Array = [
		"alertness", "athletics", "awareness", "brawl", "empathy", "expression", "intimidation", "leadership", "streetwise", "subterfuge",
		"animal_ken", "crafts", "drive", "etiquette", "firearms", "larceny", "melee", "performance", "stealth", "survival",
		"academics", "computer", "finance", "investigation", "law", "medicine", "occult", "politics", "science", "technology"
	]
	for ab in ability_names:
		var v = data.get(ab)
		if int(v) > 0:
			stat_list_vbox.add_child(_create_stat_row(
				ab.capitalize().replace("_", " "),
				str(v)
			))

	if data.ability_specialties.size() > 0:
		_add_section_header("Ability Specialties")
		for entry in data.ability_specialties:
			var parts: Array = entry.split(":", false, 1)
			var ability_key: String = parts[0]
			var specialty: String = parts[1] if parts.size() > 1 else ""
			var label_text2: String = ability_key.capitalize().replace("_", " ")
			stat_list_vbox.add_child(_create_stat_row(label_text2, specialty))

	_add_section_header("Merits")
	for merit in data.merits:
		stat_list_vbox.add_child(_create_stat_row(merit, ""))

	_add_section_header("Flaws")
	for flaw in data.flaws:
		stat_list_vbox.add_child(_create_stat_row(flaw, ""))

	if data.derangements.size() > 0:
		_add_section_header("Derangements")
		for d in data.derangements:
			var readable_name: String = DERANGEMENTS.get(d, d.capitalize().replace("_", " "))
			stat_list_vbox.add_child(_create_stat_row(readable_name, ""))

func _add_section_header(title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color.DARK_RED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	stat_list_vbox.add_child(label)

func _create_stat_row(label_text: String, value: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)

	var value_label: Label = Label.new()
	value_label.text = value
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	row.add_child(label)
	row.add_child(value_label)
	return row
