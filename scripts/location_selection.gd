extends Control

@onready var option_button = $Panel/VBoxContainer/OptionButton
@onready var cancel_button = $Panel/VBoxContainer/HBoxContainer/Cancel
@onready var select_button = $Panel/VBoxContainer/HBoxContainer/Select
@onready var label = $Panel/VBoxContainer/Label

var character_name: String = ""
var mode: String = "zone"  # Can be "zone", "viewpoint", or "teleport"

func _ready():
	cancel_button.pressed.connect(_on_cancel_pressed)
	select_button.pressed.connect(_on_select_pressed)

func enter(character: String, new_mode: String = "zone"):
	mode = new_mode
	character_name = character

	option_button.clear()
	select_button.disabled = true

	match mode:
		"zone":
			label.text = "Where do you want to go?"

		"teleport":
			label.text = "Teleport to which zone?"

		"viewpoint":
			label.text = "What do you wish to focus on?"

		_:
			print("⚠ Unknown LocationSelector mode:", mode)
			return

	# Ask the server for zone list based on mode
	NetworkManager.rpc("request_zone_selection_list", character_name, mode)

	# Center this panel
	var viewport_size = get_viewport_rect().size
	global_position = (viewport_size - size) / 2
	self.visible = true

func populate_zone_list(names: Array) -> void:
	option_button.clear()
	for zone_name in names:
		option_button.add_item(zone_name)
	select_button.disabled = names.is_empty()

func _on_cancel_pressed() -> void:
	self.visible = false

func _on_select_pressed():
	if option_button.item_count == 0:
		return

	var selection = option_button.get_item_text(option_button.selected)

	match mode:
		"zone":
			NetworkManager.rpc("request_zone_move_to", character_name, selection, "standard")

		"teleport":
			NetworkManager.rpc("request_zone_move_to", character_name, selection, "teleport")

		"viewpoint":
			NetworkManager.rpc("request_change_viewpoint", character_name, selection)

	self.visible = false
