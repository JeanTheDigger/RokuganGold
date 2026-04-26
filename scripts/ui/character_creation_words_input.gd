extends Control

signal selection_made(selection_id: String)

@onready var label: Label = $Panel/VBoxContainer/Label
@onready var option_editor: TextEdit = $Panel/VBoxContainer/OptionEditor
@onready var select_button: Button = $Panel/VBoxContainer/HBoxContainer/Select
@onready var cancel_button: Button = $Panel/VBoxContainer/HBoxContainer/Cancel

var _current_key: String = ""

func _ready():
	select_button.pressed.connect(_on_select_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	self.visible = false

func show_specialization_mode(ability_key: String, display_name: String) -> void:
	_current_key = ability_key
	label.text = "What is your %s Specialization?" % display_name

	# Re-enable interaction in case it was disabled on the previous selection
	self.process_mode = Node.PROCESS_MODE_INHERIT
	self.set_process_input(true)
	self.mouse_filter = Control.MOUSE_FILTER_STOP

	# Ensure the right widgets are visible
	if has_node("Panel/VBoxContainer/OptionButton"):
		$Panel/VBoxContainer/OptionButton.visible = false
	option_editor.visible = true
	select_button.disabled = false
	cancel_button.disabled = false

	# Show and focus
	self.visible = true
	$Panel.visible = true
	option_editor.text = ""
	option_editor.grab_focus()
	option_editor.set_caret_line(0)
	option_editor.set_caret_column(0)



func _on_select_pressed() -> void:
	var raw := option_editor.text.strip_edges()
	if raw == "":
		option_editor.grab_focus()
		return
	var sanitized := raw.replace(":", "-")
	var payload := "%s:%s" % [_current_key, sanitized]

	# Hide and emit
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
	self.set_process_input(false)
	emit_signal("selection_made", payload)

func _on_cancel_pressed() -> void:
	self.visible = false
