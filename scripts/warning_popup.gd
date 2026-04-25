extends Panel
class_name WarningPopup

@onready var warning_label = $WarningLabel
@onready var close_button = $CloseButton

func _ready():
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(hide)

func show_warning(text: String):
	warning_label.text = text
	show()
