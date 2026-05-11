extends Panel

@onready var high_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/HighTab
@onready var bugei_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/BugeiTab
@onready var merchant_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/Merchant
@onready var low_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/Low

@onready var scroll: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer

@onready var high_content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainerHighContent
@onready var bugei_content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainerBugeiContent
@onready var merchant_content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainerMerchantContent
@onready var low_content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainerLowContent

var tabs: Array[Button] = []
var contents: Array[VBoxContainer] = []

var active_bg: Color = Color("#2e1c14")
var active_border: Color = Color("#6b4a30")
var active_text: Color = Color("#c8a96e")
var inactive_bg: Color = Color("#1a1410")
var inactive_border: Color = Color("#3a3025")
var inactive_text: Color = Color("#8b7355")

var skill_data: Dictionary = {
	"High": [
		"Acting",
		"Artisan: Bonsai",
		"Artisan: Gardening",
		"Artisan: Ikebana",
		"Artisan: Origami",
		"Artisan: Painting",
		"Artisan: Poetry",
		"Artisan: Sculpture",
		"Artisan: Tattooing",
		"Calligraphy",
		"Courtier",
		"Divination",
		"Etiquette",
		"Games: Fortunes & Winds",
		"Games: Go",
		"Games: Kemari",
		"Games: Letters",
		"Games: Sadane",
		"Games: Shogi",
		"Investigation",
		"Lore: Anatomy",
		"Lore: Architecture",
		"Lore: Bushido",
		"Lore: Elements",
		"Lore: Gaijin Culture",
		"Lore: Ghosts",
		"Lore: Heraldry",
		"Lore: History",
		"Lore: Maho",
		"Lore: Nature",
		"Lore: Omens",
		"Lore: Shadowlands",
		"Lore: Shugenja",
		"Lore: Spirit Realms",
		"Lore: Theology",
		"Lore: Underworld",
		"Lore: War",
		"Medicine",
		"Meditation",
		"Perform: Biwa",
		"Perform: Dance",
		"Perform: Drums",
		"Perform: Flute",
		"Perform: Oratory",
		"Perform: Puppeteer",
		"Perform: Samisen",
		"Perform: Song",
		"Perform: Storytelling",
		"Sincerity",
		"Spellcraft",
		"Tea Ceremony"
	],
	"Bugei": [
		"Athletics",
		"Battle",
		"Chain Weapons",
		"Defense",
		"Heavy Weapons",
		"Horsemanship",
		"Hunting",
		"Iaijutsu",
		"Jiujutsu",
		"Kenjutsu",
		"Knives",
		"Kyujutsu",
		"Ninjutsu",
		"Polearms",
		"Spears",
		"Staves",
		"War Fan"
	],
	"Merchant": [
		"Animal Handling",
		"Commerce",
		"Craft: Armorsmithing",
		"Craft: Blacksmithing",
		"Craft: Bowyer",
		"Craft: Brewing",
		"Craft: Carpentry",
		"Craft: Cartography",
		"Craft: Cobbling",
		"Craft: Cooking",
		"Craft: Farming",
		"Craft: Fishing",
		"Craft: Masonry",
		"Craft: Mining",
		"Craft: Poison",
		"Craft: Pottery",
		"Craft: Shipbuilding",
		"Craft: Tailoring",
		"Craft: Weaponsmithing",
		"Craft: Weaving",
		"Engineering",
		"Sailing"
	],
	"Low": [
		"Forgery",
		"Intimidation",
		"Sleight of Hand",
		"Stealth",
		"Temptation"
	]
}

var skill_values: Dictionary = {}

func _ready() -> void:
	tabs = [high_tab, bugei_tab, merchant_tab, low_tab]
	contents = [high_content, bugei_content, merchant_content, low_content]
	
	high_tab.pressed.connect(func() -> void: _switch_tab(0))
	bugei_tab.pressed.connect(func() -> void: _switch_tab(1))
	merchant_tab.pressed.connect(func() -> void: _switch_tab(2))
	low_tab.pressed.connect(func() -> void: _switch_tab(3))
	
	_populate_skills("High", high_content)
	_populate_skills("Bugei", bugei_content)
	_populate_skills("Merchant", merchant_content)
	_populate_skills("Low", low_content)
	
	_switch_tab(0)

func _populate_skills(category: String, container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	var current_group: String = ""
	
	for skill_name in skill_data[category]:
		# Check if this is a sub-skill (contains ":")
		var parts: PackedStringArray = skill_name.split(": ")
		var group_name: String = parts[0] if parts.size() > 1 else ""
		
		# Add a category header when entering a new group
		if group_name != "" and group_name != current_group:
			current_group = group_name
			var header := Label.new()
			header.text = group_name
			header.add_theme_color_override("font_color", Color("#8b7355"))
			header.add_theme_font_size_override("font_size", 14)
			header.add_theme_constant_override("margin_top", 8)
			container.add_child(header)
			
			var sep := HSeparator.new()
			container.add_child(sep)
		elif group_name == "" and current_group != "":
			current_group = ""
		
		skill_values[skill_name] = 0
		var row := _create_skill_row(skill_name)
		container.add_child(row)

func _create_skill_row(skill_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	# Display name — use sub-skill name if it exists, full name otherwise
	var display_name: String = skill_name
	var parts: PackedStringArray = skill_name.split(": ")
	if parts.size() > 1:
		display_name = "  " + parts[1]
	
	var name_label := Label.new()
	name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	
	var value_label := Label.new()
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size.x = 30
	value_label.name = "Value"
	row.add_child(value_label)
	
	var decrease := Button.new()
	decrease.text = "−"
	decrease.custom_minimum_size = Vector2(28, 28)
	decrease.pressed.connect(func() -> void: _change_skill(skill_name, -1, value_label))
	row.add_child(decrease)
	
	var increase := Button.new()
	increase.text = "+"
	increase.custom_minimum_size = Vector2(28, 28)
	increase.pressed.connect(func() -> void: _change_skill(skill_name, 1, value_label))
	row.add_child(increase)
	
	return row

func _change_skill(skill_name: String, amount: int, label: Label) -> void:
	skill_values[skill_name] = clamp(skill_values[skill_name] + amount, 0, 10)
	label.text = str(skill_values[skill_name])

func _switch_tab(index: int) -> void:
	scroll.scroll_vertical = 0
	
	for i in range(tabs.size()):
		if i == index:
			contents[i].visible = true
			_style_tab(tabs[i], true)
		else:
			contents[i].visible = false
			_style_tab(tabs[i], false)

func _style_tab(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.corner_detail = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	if active:
		style.bg_color = active_bg
		style.border_color = active_border
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_bottom = 0
		button.add_theme_color_override("font_color", active_text)
	else:
		style.bg_color = inactive_bg
		style.border_color = inactive_border
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		button.add_theme_color_override("font_color", inactive_text)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
