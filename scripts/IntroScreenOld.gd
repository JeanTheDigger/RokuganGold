extends Control

# === UI Nodes ===
@onready var storyteller_button = $ButtonMenu/StorytellerButton
@onready var words_input_panel = $WordsInputPanel
@onready var name_input_box = $WordsInputPanel/WordsInputPanelPanel/VBoxContainer/InputBox
@onready var confirm_button = $WordsInputPanel/WordsInputPanelPanel/VBoxContainer/HBoxContainer/SendButton

@onready var load_button = $ButtonMenu/LoadCharacterButton
@onready var login_ui = $LoginUI
@onready var new_character_button = $ButtonMenu/NewCharacterButton

# === Internal State ===
var storyteller_name = "Storyteller"  # Default fallback

# === CELLPHONE SUPPORT ===
var _is_web := false
var _is_mobile_web := false
var _vk_available := false

func _init_cellphone_support():
	# Platform capability detection
	_is_web = OS.has_feature("web")
	_vk_available = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)

	# Basic user agent test for mobile browsers when on Web
	if _is_web and Engine.has_singleton("JavaScriptBridge"):
		_is_mobile_web = JavaScriptBridge.eval("""
			(() => /Android|iPhone|iPad|iPod|Opera Mini|IEMobile|Mobile/i.test(navigator.userAgent))()
		""")

	# Only wire hooks if actually on mobile web and VK is available
	if _is_web and _is_mobile_web and _vk_available:
		_setup_virtual_keyboard_hooks(self)

	# Defensive enable on a known input box if the engine exposes it
	if name_input_box.has_method("set_virtual_keyboard_enabled"):
		name_input_box.set_virtual_keyboard_enabled(true)
	elif "virtual_keyboard_enabled" in name_input_box:
		name_input_box.virtual_keyboard_enabled = true

func _setup_virtual_keyboard_hooks(root: Node) -> void:
	for child in root.get_children():
		if child is LineEdit or child is TextEdit:
			_connect_vk_for_control(child)
		if child.get_child_count() > 0:
			_setup_virtual_keyboard_hooks(child)

func _connect_vk_for_control(ctrl: Control) -> void:
	# Some controls expose this property
	if "virtual_keyboard_enabled" in ctrl:
		ctrl.virtual_keyboard_enabled = true

	# Show on focus, hide on blur
	if not ctrl.is_connected("focus_entered", Callable(self, "_on_vk_focus_entered")):
		ctrl.focus_entered.connect(_on_vk_focus_entered.bind(ctrl))
	if not ctrl.is_connected("focus_exited", Callable(self, "_on_vk_focus_exited")):
		ctrl.focus_exited.connect(_on_vk_focus_exited.bind(ctrl))

func _on_vk_focus_entered(ctrl: Control) -> void:
	if not (_is_web and _is_mobile_web and _vk_available):
		return
	var txt := ""
	if ctrl is LineEdit:
		txt = ctrl.text
	elif ctrl is TextEdit:
		txt = ctrl.text
	var rect := ctrl.get_global_rect()  # hint for keyboard positioning
	DisplayServer.virtual_keyboard_show(txt, rect)

func _on_vk_focus_exited(_ctrl: Control) -> void:
	if not (_is_web and _is_mobile_web and _vk_available):
		return
	DisplayServer.virtual_keyboard_hide()

# === READY ===
func _ready():
	_init_cellphone_support()

	storyteller_button.pressed.connect(_on_storyteller_button_pressed)
	words_input_panel.visible = false
	load_button.pressed.connect(_on_load_character_pressed)
	new_character_button.pressed.connect(_on_new_character_pressed)


func _on_new_character_pressed():
	print("🧬 New Character button pressed.")
	MusicManager.fade_out()
	_connect_to_server_for_character_creation()

func _connect_to_server_for_character_creation():
	multiplayer.multiplayer_peer = null  # ✅ RESET BEFORE RECONNECT
	var peer = ENetMultiplayerPeer.new()
	# "155.138.161.5", 43210
	peer.create_client("127.0.0.1", 43210)
	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(_on_connected_for_character_creation)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)

func _on_connected_for_character_creation():
	print("✅ Connected to server for new character creation.")
	await get_tree().create_timer(0.1).timeout

	var character_creation_scene = load("res://scene/character_creation.tscn")
	if character_creation_scene == null:
		print("❌ Failed to load character creation scene.")
		return

	var character_creation = character_creation_scene.instantiate()
	get_tree().root.add_child(character_creation)

	var old_scene = get_tree().current_scene
	get_tree().current_scene = character_creation
	if old_scene:
		old_scene.queue_free()

	print("🧬 Entered character creation screen.")

func _on_load_character_pressed():
	print("🔁 Load Character button pressed.")
	MusicManager.fade_out()
	_connect_to_server_for_loading()

func _connect_to_server_for_loading():
	multiplayer.multiplayer_peer = null  # ✅ RESET BEFORE RECONNECT
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 43210)
	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(_on_connected_for_loading)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)

func _on_connected_for_loading():
	print("✅ Connected to server for character loading.")
	await get_tree().create_timer(0.1).timeout
	login_ui.visible = true

func _on_storyteller_button_pressed():
	MusicManager.fade_out()
	login_ui.open("storyteller")

	if not login_ui.is_connected("login_cancelled", Callable(self, "_on_login_cancelled")):
		login_ui.login_cancelled.connect(_on_login_cancelled)

func _on_login_cancelled():
	print("🔙 Login cancelled by user.")

func _start_storyteller_mode(st_name: String):
	storyteller_name = st_name
	_connect_to_server()

func _connect_to_server():
	multiplayer.multiplayer_peer = null  # ✅ RESET BEFORE RECONNECT
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("155.138.161.5", 43210)
	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)

func _on_connected():
	print("✅✅✅ _on_connected() CALLED")
	print("🌐 Multiplayer ID:", multiplayer.get_unique_id())
	print("🌐 Is Server:", multiplayer.is_server())
	print("🌐 Node Path:", NetworkManager.get_path())

	await get_tree().create_timer(0.1).timeout

	print("📡 Attempting to RPC: register_character")
	print("🔍 NetworkManager type:", typeof(NetworkManager))
	print("🔍 Is Node?:", NetworkManager is Node)
	print("🔍 NetworkManager ref:", NetworkManager)

	NetworkManager.rpc("register_character", storyteller_name, true)
	print("📡 RPC call finished")

	await get_tree().create_timer(0.2).timeout
	_start_storyteller_mode_final()

func _on_failed():
	print("❌ Connection failed. Staying on intro screen.")

func _on_disconnected():
	print("🔌 Disconnected from server.")

func _start_storyteller_mode_final():
	print("🧪 Starting storyteller mode setup")

	var character := CharacterData.new()
	character.name = storyteller_name
	character.current_zone = "OOC"
	character.is_storyteller = true
	GameManager.character_data = character

	print("✅ CharacterData created")
	print("  - Name:", character.name)
	print("  - Zone:", character.current_zone)
	print("  - Is Storyteller:", character.is_storyteller)

	var peer_id: int = multiplayer.get_unique_id()
	GameManager.peer_to_character_name[peer_id] = character.name
	print("🔗 Registered peer ID", peer_id, "→", character.name)

	var main_scene: Control = load("res://scene/main_ui.tscn").instantiate()
	print("📦 main_ui.tscn loaded and instantiated")

	main_scene.set_character_data(character)
	GameManager.character_uis[character.name] = main_scene
	print("📨 Character data passed to main_ui and UI registered under name")

	get_tree().root.add_child(main_scene)
	print("🌲 Added main_ui to scene tree")

	var old_scene := get_tree().current_scene
	get_tree().current_scene = main_scene
	if old_scene:
		old_scene.queue_free()

	print("🧹 Switched to new main_ui scene")
