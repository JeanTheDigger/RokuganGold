extends Control

@onready var slider: HSlider = $Panel/VBoxContainer/HBoxContainer/EnterMode
@onready var close_button: Button = $Panel/Close

func _ready() -> void:
	slider.min_value = 0
	slider.max_value = 2
	slider.step = 1
	slider.value = SettingsManager.current_enter_mode
	slider.value_changed.connect(_on_slider_value_changed)
	close_button.pressed.connect(_on_close_pressed)

func _on_slider_value_changed(value: float) -> void:
	var mode := int(value)
	SettingsManager.set_enter_mode(mode)

	match mode:
		SettingsManager.EnterMode.NO_ENTER:
			print("Current Mode: No Enter")
		SettingsManager.EnterMode.ENTER:
			print("Current Mode: Enter")
		SettingsManager.EnterMode.SHIFT_ENTER:
			print("Current Mode: Shift+Enter")

func _on_close_pressed() -> void:
	self.visible = false
