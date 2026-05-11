extends Panel

@onready var adv_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/AdvantagesTab
@onready var dis_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer/DisadvantagesTab

@onready var physical_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer2/PhysicalTab
@onready var mental_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer2/MentalTab
@onready var social_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer2/SocialTab
@onready var mystical_tab: Button = $MarginContainer/VBoxContainer/HBoxContainer2/MysticalTab

@onready var scroll: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainerContent

var type_tabs: Array[Button] = []
var category_tabs: Array[Button] = []

var current_type: String = "Advantages"
var current_category: String = "Physical"

var active_bg: Color = Color("#2e1c14")
var active_border: Color = Color("#6b4a30")
var active_text: Color = Color("#c8a96e")
var inactive_bg: Color = Color("#1a1410")
var inactive_border: Color = Color("#3a3025")
var inactive_text: Color = Color("#8b7355")

var selected: Dictionary = {}

var trait_data: Dictionary = {
	"Advantages": {
		"Physical": [
			{"name": "Bland", "cost": "2"},
			{"name": "Crab Hands", "cost": "3"},
			{"name": "Dangerous Beauty", "cost": "3"},
			{"name": "Iron Heart Native", "cost": "2"},
			{"name": "Large", "cost": "4"},
			{"name": "Naga Ancestry", "cost": "7"},
			{"name": "Prodigy", "cost": "12"},
			{"name": "Quick", "cost": "6"},
			{"name": "Quick Healer", "cost": "3"},
			{"name": "Ruined City Shadow", "cost": "3"},
			{"name": "Silent", "cost": "3"},
			{"name": "Voice", "cost": "3"}
		],
		"Mental": [
			{"name": "Absolute Direction", "cost": "1"},
			{"name": "Balance", "cost": "2"},
			{"name": "Clear Thinker", "cost": "3"},
			{"name": "Crafty", "cost": "3"},
			{"name": "Daredevil", "cost": "3"},
			{"name": "Dark Paragon", "cost": "5"},
			{"name": "Forbidden Knowledge", "cost": "5"},
			{"name": "Great Potential", "cost": "5"},
			{"name": "Heartless", "cost": "4"},
			{"name": "Higher Purpose", "cost": "3"},
			{"name": "Irreproachable", "cost": "2"},
			{"name": "Languages (Human)", "cost": "1"},
			{"name": "Languages (Non-Human)", "cost": "3"},
			{"name": "Laughing Plains Native", "cost": "2"},
			{"name": "Paragon", "cost": "7"},
			{"name": "Precise Memory", "cost": "3"},
			{"name": "Read Lips", "cost": "4"},
			{"name": "Sacred Forest Native", "cost": "2"},
			{"name": "Sage", "cost": "4"},
			{"name": "Sage of the Sword and Fan", "cost": "7"},
			{"name": "Shadowed Heart", "cost": "5"},
			{"name": "Soul of Artistry", "cost": "4"},
			{"name": "Strategist", "cost": "5"},
			{"name": "Student of Shourido", "cost": "9"},
			{"name": "Tactician", "cost": "4"},
			{"name": "Virtuous", "cost": "3"},
			{"name": "Wary", "cost": "3"},
			{"name": "Watanu-Trained", "cost": "1"},
			{"name": "Way of the Land", "cost": "2"}
		],
		"Social": [
			{"name": "Allies (Minor Influence, Would Help)", "cost": "2"},
			{"name": "Allies (Minor Influence, Risk Honor)", "cost": "3"},
			{"name": "Allies (Minor Influence, Anything)", "cost": "5"},
			{"name": "Allies (Moderate Influence, Would Help)", "cost": "3"},
			{"name": "Allies (Moderate Influence, Risk Honor)", "cost": "4"},
			{"name": "Allies (Moderate Influence, Anything)", "cost": "6"},
			{"name": "Allies (Major Influence, Would Help)", "cost": "5"},
			{"name": "Allies (Major Influence, Risk Honor)", "cost": "6"},
			{"name": "Allies (Major Influence, Anything)", "cost": "8"},
			{"name": "Blackmail", "cost": "1"},
			{"name": "Blissful Betrothal", "cost": "3"},
			{"name": "Broken Wave Citizen", "cost": "3"},
			{"name": "Dark Edge Native", "cost": "2"},
			{"name": "Darling of the Court", "cost": "2"},
			{"name": "Different School", "cost": "5"},
			{"name": "Fame", "cost": "3"},
			{"name": "Gaijin Gear", "cost": "5"},
			{"name": "Gentry (Village)", "cost": "8"},
			{"name": "Gentry (Large Village)", "cost": "15"},
			{"name": "Gentry (Unique Holding)", "cost": "18"},
			{"name": "Gentry (Town)", "cost": "20"},
			{"name": "Gentry (City)", "cost": "25"},
			{"name": "Gentry (Province)", "cost": "30"},
			{"name": "Heart of Vengeance", "cost": "5"},
			{"name": "Hero of the People", "cost": "2"},
			{"name": "Imperial City Citizen", "cost": "2"},
			{"name": "Imperial City Veteran", "cost": "2"},
			{"name": "Imperial Scribe", "cost": "4"},
			{"name": "Imperial Spouse", "cost": "5"},
			{"name": "Inheritance", "cost": "5"},
			{"name": "Inheritance: Asahina Blade", "cost": "9"},
			{"name": "Inheritance: Kobune", "cost": "10"},
			{"name": "Inheritance: Trained Falcon", "cost": "2"},
			{"name": "Inheritance: Water Hammer Armor (Ashigaru)", "cost": "4"},
			{"name": "Inheritance: Water Hammer Armor (Light)", "cost": "7"},
			{"name": "Inheritance: Water Hammer Armor (Heavy)", "cost": "12"},
			{"name": "Inheritance: Water Hammer Armor (Riding)", "cost": "15"},
			{"name": "Leadership", "cost": "6"},
			{"name": "Multiple Schools", "cost": "10"},
			{"name": "Naishou Citizen", "cost": "3"},
			{"name": "Nikesake Citizen", "cost": "3"},
			{"name": "Perceived Honor (Rank 1)", "cost": "3"},
			{"name": "Perceived Honor (Rank 2)", "cost": "6"},
			{"name": "Perceived Honor (Rank 3)", "cost": "9"},
			{"name": "Sacred Weapon (Crab: Kaiu Blade)", "cost": "6"},
			{"name": "Sacred Weapon (Crane: Kakita Blade)", "cost": "5"},
			{"name": "Sacred Weapon (Dragon: Twin Sister Blades)", "cost": "3"},
			{"name": "Sacred Weapon (Lion: Akodo Blade)", "cost": "6"},
			{"name": "Sacred Weapon (Mantis: Storm Kama)", "cost": "6"},
			{"name": "Sacred Weapon (Phoenix: Inquisitor's Strike)", "cost": "6"},
			{"name": "Sacred Weapon (Scorpion: Shosuro Blade)", "cost": "5"},
			{"name": "Sacred Weapon (Spider: Black Steel Blade)", "cost": "6"},
			{"name": "Sacred Weapon (Unicorn: Moto Scimitar)", "cost": "6"},
			{"name": "Sacred Weapon (Owl Blade)", "cost": "6"},
			{"name": "Sacrosanct", "cost": "4"},
			{"name": "Sensation", "cost": "3"},
			{"name": "Servant", "cost": "5"},
			{"name": "Social Position", "cost": "6"},
			{"name": "Stolen Identity", "cost": "6"},
			{"name": "Water Hammer Citizen", "cost": "3"},
			{"name": "Wealthy (Rank 1)", "cost": "1"},
			{"name": "Wealthy (Rank 2)", "cost": "2"},
			{"name": "Wealthy (Rank 3)", "cost": "3"},
			{"name": "Well-Connected (Rank 1)", "cost": "3"},
			{"name": "Well-Connected (Rank 2)", "cost": "6"},
			{"name": "Well-Connected (Rank 3)", "cost": "9"},
			{"name": "Zakyo Toshi Citizen", "cost": "3"}
		],
		"Mystical": [
			{"name": "Battle Healing", "cost": "5"},
			{"name": "Blood of Osano-Wo", "cost": "4"},
			{"name": "Child of Chikushudo", "cost": "7"},
			{"name": "Chosen by the Oracles", "cost": "6"},
			{"name": "Elemental Blessing", "cost": "4"},
			{"name": "Enlightened", "cost": "6"},
			{"name": "Friend of the Brotherhood", "cost": "5"},
			{"name": "Friend of the Elements", "cost": "4"},
			{"name": "Friendly Kami", "cost": "5"},
			{"name": "Great Destiny", "cost": "5"},
			{"name": "Inari's Blessing", "cost": "3"},
			{"name": "Inner Gift", "cost": "7"},
			{"name": "Ishiken-Do", "cost": "8"},
			{"name": "Kharmic Tie (1 Point)", "cost": "1"},
			{"name": "Kharmic Tie (2 Points)", "cost": "2"},
			{"name": "Kharmic Tie (3 Points)", "cost": "3"},
			{"name": "Kharmic Tie (4 Points)", "cost": "4"},
			{"name": "Kharmic Tie (5 Points)", "cost": "5"},
			{"name": "Luck (Rank 1)", "cost": "3"},
			{"name": "Luck (Rank 2)", "cost": "6"},
			{"name": "Luck (Rank 3)", "cost": "9"},
			{"name": "Magic Resistance (Rank 1)", "cost": "2"},
			{"name": "Magic Resistance (Rank 2)", "cost": "4"},
			{"name": "Magic Resistance (Rank 3)", "cost": "6"},
			{"name": "Medium", "cost": "4"},
			{"name": "Reincarnated", "cost": "6"},
			{"name": "Seven Fortunes' Blessing: Benten", "cost": "4"},
			{"name": "Seven Fortunes' Blessing: Bishamon", "cost": "5"},
			{"name": "Seven Fortunes' Blessing: Daikoku", "cost": "4"},
			{"name": "Seven Fortunes' Blessing: Ebisu", "cost": "4"},
			{"name": "Seven Fortunes' Blessing: Fukurokujin", "cost": "4"},
			{"name": "Seven Fortunes' Blessing: Hotei", "cost": "4"},
			{"name": "Seven Fortunes' Blessing: Jurojin", "cost": "4"},
			{"name": "Touch of the Spirit Realms: Chikushudo", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Gaki-do", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Jigoku", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Maigo no Musha", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Meido", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Sakkaku", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Tengoku", "cost": "5"},
			{"name": "Touch of the Spirit Realms: Toshigoku", "cost": "8"},
			{"name": "Touch of the Spirit Realms: Yomi", "cost": "7"},
			{"name": "Touch of the Spirit Realms: Yume-do", "cost": "5"},
			{"name": "Void Versatility", "cost": "4"}
		]
	},
	"Disadvantages": {
		"Physical": [
			{"name": "Bad Eyesight", "cost": "3"},
			{"name": "Bad Health", "cost": "4"},
			{"name": "Blind", "cost": "6"},
			{"name": "Disturbing Countenance", "cost": "3"},
			{"name": "Epilepsy", "cost": "4"},
			{"name": "Lame", "cost": "4"},
			{"name": "Low Pain Threshold", "cost": "4"},
			{"name": "Missing Limb", "cost": "6"},
			{"name": "Permanent Wound", "cost": "4"},
			{"name": "Small", "cost": "3"},
			{"name": "Weakness", "cost": "6"}
		],
		"Mental": [
			{"name": "Ascetic", "cost": "2"},
			{"name": "Brash", "cost": "3"},
			{"name": "Can't Lie", "cost": "2"},
			{"name": "Compulsion (TN 15)", "cost": "2"},
			{"name": "Compulsion (TN 20)", "cost": "3"},
			{"name": "Compulsion (TN 25)", "cost": "4"},
			{"name": "Consumed: Control", "cost": "4"},
			{"name": "Consumed: Determination", "cost": "6"},
			{"name": "Consumed: Insight", "cost": "4"},
			{"name": "Consumed: Knowledge", "cost": "4"},
			{"name": "Consumed: Perfection", "cost": "5"},
			{"name": "Consumed: Strength", "cost": "5"},
			{"name": "Consumed: Will", "cost": "4"},
			{"name": "Contrary", "cost": "3"},
			{"name": "Disbeliever", "cost": "3"},
			{"name": "Doubt", "cost": "4"},
			{"name": "Driven", "cost": "2"},
			{"name": "Failure of Bushido: Compassion", "cost": "3"},
			{"name": "Failure of Bushido: Courage", "cost": "4"},
			{"name": "Failure of Bushido: Courtesy", "cost": "4"},
			{"name": "Failure of Bushido: Duty", "cost": "6"},
			{"name": "Failure of Bushido: Honesty", "cost": "3"},
			{"name": "Failure of Bushido: Honor", "cost": "3"},
			{"name": "Failure of Bushido: Sincerity", "cost": "4"},
			{"name": "Fascination", "cost": "1"},
			{"name": "Frail Mind", "cost": "3"},
			{"name": "Greedy", "cost": "3"},
			{"name": "Gullible", "cost": "4"},
			{"name": "Idealistic", "cost": "2"},
			{"name": "Insensitive", "cost": "2"},
			{"name": "Jealousy", "cost": "3"},
			{"name": "Lost Love", "cost": "3"},
			{"name": "Obtuse", "cost": "3"},
			{"name": "Overconfident", "cost": "3"},
			{"name": "Phobia (Rank 1)", "cost": "1"},
			{"name": "Phobia (Rank 2)", "cost": "2"},
			{"name": "Phobia (Rank 3)", "cost": "3"},
			{"name": "Sleeper Agent", "cost": "5"},
			{"name": "Soft-Hearted", "cost": "2"},
			{"name": "True Love", "cost": "3"}
		],
		"Social": [
			{"name": "Anachronism", "cost": "2"},
			{"name": "Antisocial (Minor)", "cost": "2"},
			{"name": "Antisocial (Major)", "cost": "4"},
			{"name": "Bitter Betrothal", "cost": "2"},
			{"name": "Black Sheep", "cost": "3"},
			{"name": "Blackmailed", "cost": "1"},
			{"name": "Bounty (Minor Offense)", "cost": "2"},
			{"name": "Bounty (Serious Offense)", "cost": "4"},
			{"name": "Bounty (Heinous Act)", "cost": "6"},
			{"name": "Broken Wave Stigma", "cost": "2"},
			{"name": "Cast Out (Single Temple)", "cost": "1"},
			{"name": "Cast Out (Major Sect)", "cost": "3"},
			{"name": "Dark Edge Reputation", "cost": "2"},
			{"name": "Dark Secret", "cost": "4"},
			{"name": "Debt (Quarter Stipend)", "cost": "2"},
			{"name": "Debt (Full Stipend)", "cost": "4"},
			{"name": "Debt (Major)", "cost": "8"},
			{"name": "Dependent", "cost": "3"},
			{"name": "Dishonored", "cost": "5"},
			{"name": "Forced Retirement", "cost": "4"},
			{"name": "Gaijin Name", "cost": "1"},
			{"name": "Hostage", "cost": "3"},
			{"name": "Imperial City Stigma", "cost": "4"},
			{"name": "Infamous", "cost": "2"},
			{"name": "Lechery", "cost": "2"},
			{"name": "Member of the Chrysanthemum Court", "cost": "5"},
			{"name": "Nikesake Stigma", "cost": "4"},
			{"name": "Obligation (Minor)", "cost": "3"},
			{"name": "Obligation (Major)", "cost": "6"},
			{"name": "Ruined City Survivor", "cost": "4"},
			{"name": "Rumormonger", "cost": "4"},
			{"name": "Social Disadvantage", "cost": "3"},
			{"name": "Sworn Enemy", "cost": "3"},
			{"name": "Wanderer", "cost": "2"},
			{"name": "Water Hammer Stigma", "cost": "2"},
			{"name": "Zakyo Toshi Stigma", "cost": "3"}
		],
		"Mystical": [
			{"name": "Bad Fortune: Secret Love", "cost": "3"},
			{"name": "Bad Fortune: Disfigurement", "cost": "3"},
			{"name": "Bad Fortune: Evil Eye", "cost": "3"},
			{"name": "Bad Fortune: Allergy", "cost": "3"},
			{"name": "Bad Fortune: Lingering Misfortune", "cost": "3"},
			{"name": "Bad Fortune: Unknown Enemy", "cost": "3"},
			{"name": "Bad Fortune: Moto Curse", "cost": "4"},
			{"name": "Bad Fortune: Yogo Curse", "cost": "4"},
			{"name": "Cursed by the Realm: Chikushudo", "cost": "4"},
			{"name": "Cursed by the Realm: Gaki-do", "cost": "4"},
			{"name": "Cursed by the Realm: Jigoku", "cost": "4"},
			{"name": "Cursed by the Realm: Maigo no Musha", "cost": "4"},
			{"name": "Cursed by the Realm: Meido", "cost": "4"},
			{"name": "Cursed by the Realm: Sakkaku", "cost": "4"},
			{"name": "Cursed by the Realm: Tengoku", "cost": "4"},
			{"name": "Cursed by the Realm: Toshigoku", "cost": "4"},
			{"name": "Cursed by the Realm: Yomi", "cost": "4"},
			{"name": "Cursed by the Realm: Yume-do", "cost": "4"},
			{"name": "Dark Fate", "cost": "3"},
			{"name": "Elemental Imbalance (Rank 1)", "cost": "2"},
			{"name": "Elemental Imbalance (Rank 2)", "cost": "4"},
			{"name": "Elemental Imbalance (Rank 3)", "cost": "6"},
			{"name": "Enlightened Madness (TN 20)", "cost": "4"},
			{"name": "Enlightened Madness (TN 30)", "cost": "6"},
			{"name": "Haunted", "cost": "3"},
			{"name": "Lord Moon's Curse (Rank 1)", "cost": "3"},
			{"name": "Lord Moon's Curse (Rank 2)", "cost": "5"},
			{"name": "Lord Moon's Curse (Rank 3)", "cost": "7"},
			{"name": "Momoku", "cost": "8"},
			{"name": "Seven Fortunes' Curse: Benten", "cost": "3"},
			{"name": "Seven Fortunes' Curse: Bishamon", "cost": "3"},
			{"name": "Seven Fortunes' Curse: Daikoku", "cost": "3"},
			{"name": "Seven Fortunes' Curse: Ebisu", "cost": "3"},
			{"name": "Seven Fortunes' Curse: Fukurokujin", "cost": "3"},
			{"name": "Seven Fortunes' Curse: Hotei", "cost": "6"},
			{"name": "Seven Fortunes' Curse: Jurojin", "cost": "3"},
			{"name": "Shadowlands Taint", "cost": "4"},
			{"name": "Touch of the Void", "cost": "3"},
			{"name": "Uncentered (Clan Monk)", "cost": "2"},
			{"name": "Uncentered (Brotherhood)", "cost": "4"},
			{"name": "Unlucky (Rank 1)", "cost": "2"},
			{"name": "Unlucky (Rank 2)", "cost": "4"},
			{"name": "Unlucky (Rank 3)", "cost": "6"},
			{"name": "Wrath of the Kami", "cost": "3"}
		]
	}
}

func _ready() -> void:
	type_tabs = [adv_tab, dis_tab]
	category_tabs = [physical_tab, mental_tab, social_tab, mystical_tab]
	
	adv_tab.pressed.connect(func() -> void: _switch_type("Advantages"))
	dis_tab.pressed.connect(func() -> void: _switch_type("Disadvantages"))
	
	physical_tab.pressed.connect(func() -> void: _switch_category("Physical"))
	mental_tab.pressed.connect(func() -> void: _switch_category("Mental"))
	social_tab.pressed.connect(func() -> void: _switch_category("Social"))
	mystical_tab.pressed.connect(func() -> void: _switch_category("Mystical"))
	
	_switch_type("Advantages")
	_switch_category("Physical")

func _switch_type(type: String) -> void:
	current_type = type
	_style_tab(adv_tab, type == "Advantages")
	_style_tab(dis_tab, type == "Disadvantages")
	_refresh_list()

func _switch_category(category: String) -> void:
	current_category = category
	var categories: Array[String] = ["Physical", "Mental", "Social", "Mystical"]
	for i in range(category_tabs.size()):
		_style_tab(category_tabs[i], categories[i] == category)
	_refresh_list()

func _refresh_list() -> void:
	scroll.scroll_vertical = 0
	
	for child in content.get_children():
		child.queue_free()
	
	var items: Array = trait_data[current_type][current_category]
	
	for item in items:
		var item_name: String = item["name"]
		var item_cost: String = item["cost"]
		var key: String = current_type + ":" + item_name
		if not selected.has(key):
			selected[key] = false
		
		var row := _create_trait_row(item_name, item_cost, key)
		content.add_child(row)

func _create_trait_row(trait_name: String, cost: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var name_label := Label.new()
	name_label.text = trait_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	
	var cost_label := Label.new()
	cost_label.text = cost + " pts"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size.x = 60
	cost_label.add_theme_color_override("font_color", Color("#8b7355"))
	row.add_child(cost_label)
	
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = selected[key]
	toggle.custom_minimum_size = Vector2(70, 26)
	
	if selected[key]:
		toggle.text = "Selected"
	else:
		toggle.text = "Select"
	
	toggle.toggled.connect(func(pressed: bool) -> void:
		selected[key] = pressed
		if pressed:
			toggle.text = "Selected"
			toggle.add_theme_color_override("font_color", Color("#c8a96e"))
		else:
			toggle.text = "Select"
			toggle.remove_theme_color_override("font_color")
	)
	
	row.add_child(toggle)
	
	return row

func _style_tab(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.corner_detail = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	
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

func get_selected() -> Dictionary:
	var result: Dictionary = {"Advantages": [], "Disadvantages": []}
	for key in selected:
		if selected[key]:
			var parts: PackedStringArray = key.split(":")
			var type: String = parts[0]
			var trait_name: String = parts[1]
			result[type].append(trait_name)
	return result

func get_total_cost() -> Dictionary:
	var adv_cost: int = 0
	var dis_cost: int = 0
	for key in selected:
		if selected[key]:
			var parts: PackedStringArray = key.split(":")
			var type: String = parts[0]
			var trait_name: String = parts[1]
			for category in trait_data[type]:
				for item in trait_data[type][category]:
					if item["name"] == trait_name:
						var cost_str: String = item["cost"]
						if cost_str.is_valid_int():
							if type == "Advantages":
								adv_cost += int(cost_str)
							else:
								dis_cost += int(cost_str)
	return {"advantages": adv_cost, "disadvantages": dis_cost}
