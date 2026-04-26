extends Control

@onready var name_field: LineEdit = $Panel/MarginContainer/VBoxContainer/Name_Field
@onready var password_field: LineEdit = $Panel/MarginContainer/VBoxContainer/Password_Field
@onready var cancel_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/Cancel
@onready var confirm_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/Confirm

signal login_cancelled()

const VALID_STORYTELLERS = {
	"JeanST": "Morbius",
	"ST Shadowfox": "Shadowfox",
	"ST Luke": "booba",
	"ST Raven": "booba",
	"EM Milk": "B0ngwater",
	"EM Aaron": "Skreebo1252!",
	"EM Ladle": "booba",
	"EM Miut": "Miuteatsleaves123"
}

var current_storyteller_name := ""
var login_mode := "player"  # "player" or "storyteller"

func _ready():
	# existing hookups
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	self.visible = false

	# ensure they can take focus
	name_field.focus_mode = Control.FOCUS_ALL
	password_field.focus_mode = Control.FOCUS_ALL

	# TAB toggle between the two fields (works for Tab and Shift+Tab)
	name_field.gui_input.connect(_on_field_gui_input.bind("name"))
	password_field.gui_input.connect(_on_field_gui_input.bind("password"))

func _on_field_gui_input(event: InputEvent, which: String) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			if which == "name":
				password_field.grab_focus()
			else:
				name_field.grab_focus()
			accept_event()  # stop default focus traversal hitting buttons

func open(mode: String = "player") -> void:
	login_mode = mode
	clear_fields()
	self.visible = true
	name_field.grab_focus()

func _on_cancel_pressed() -> void:
	self.visible = false
	emit_signal("login_cancelled")

func _on_confirm_pressed() -> void:
	var character_name: String = name_field.text.strip_edges()
	var password: String = password_field.text.strip_edges()
	if character_name.is_empty() or password.is_empty():
		print("❌ Name or password is empty.")
		return

	match login_mode:
		"storyteller":
			if VALID_STORYTELLERS.has(character_name) and VALID_STORYTELLERS[character_name] == password:
				print("🧙 Storyteller access granted.")
				current_storyteller_name = character_name
				self.visible = false
				get_parent()._start_storyteller_mode(character_name)
			else:
				print("🚫 Invalid Storyteller credentials.")
				self.visible = false
		"player":
			print("🔐 Player login attempt for:", character_name)
			self.visible = false
			NetworkManager.rpc("request_load_character", character_name, password)

func clear_fields():
	name_field.text = ""
	password_field.text = ""
