extends Control

@onready var file_picker: FileDialog = $FileDialog
@onready var display_text := get_parent().get_node("TextPanel/DisplayText")

const MAX_FILE_SIZE := 512_000  # 500 KB
var PNG_SIGNATURE := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

func _ready():
	# In browser builds, this will open the native upload picker.
	file_picker.access = FileDialog.ACCESS_FILESYSTEM
	file_picker.filters = PackedStringArray(["*.png ; PNG Images"])
	file_picker.file_selected.connect(_on_file_selected)
	file_picker.canceled.connect(_on_file_dialog_canceled)
	visible = false  # Initially hidden

func open_selector():
	visible = true
	file_picker.popup_centered_ratio(0.8)

func _on_file_selected(path: String) -> void:
	print("📁 File selected:", path)

	# Always make sure popup is closed
	var cleanup := func():
		hide()

	if not path.to_lower().ends_with(".png"):
		_warn("Only PNG files are allowed.")
		cleanup.call()
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_warn("Could not open the file.")
		cleanup.call()
		return

	var file_size: int = file.get_length()
	if file_size > MAX_FILE_SIZE:
		_warn("Image too large. Maximum size is 500 KB.")
		file.close()
		cleanup.call()
		return

	var bytes: PackedByteArray = file.get_buffer(file_size)
	file.close()

	if bytes.size() < 8 or bytes.slice(0, 8) != PNG_SIGNATURE:
		_warn("This is not a valid PNG image.")
		cleanup.call()
		return

	var img := Image.new()
	var err: int = img.load_png_from_buffer(bytes)
	if err != OK:
		_warn("Failed to load PNG image.")
		cleanup.call()
		return

	var max_dim: int = 512
	if img.get_width() > max_dim or img.get_height() > max_dim:
		var scale_ratio: float = min(max_dim / float(img.get_width()), max_dim / float(img.get_height()))
		var new_width: int = int(img.get_width() * scale_ratio)
		var new_height: int = int(img.get_height() * scale_ratio)
		print("📐 Resizing image to:", new_width, "x", new_height)
		img.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
		bytes = img.save_png_to_buffer()

	if bytes.size() > MAX_FILE_SIZE:
		_warn("Resized image is still too large to upload.")
		cleanup.call()
		return

	var char_name: String = GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), "").strip_edges()
	if char_name.is_empty():
		_warn("No active character.")
		cleanup.call()
		return

	NetworkManager.rpc_id(1, "upload_character_image", char_name, bytes)
	print("📤 Sent image to server as:", char_name + ".png")
	cleanup.call()

func _on_file_dialog_canceled():
	print("❌ File dialog canceled.")
	hide()

func _warn(message: String) -> void:
	if is_instance_valid(display_text):
		display_text.append_text("\n[color=red]⚠ %s[/color]" % message)
	else:
		print("⚠ %s" % message)
