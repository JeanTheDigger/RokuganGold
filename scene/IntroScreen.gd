extends Control

# === UI Nodes ===
@onready var storyteller_button = $ButtonMenu/StorytellerButton
@onready var words_input_panel = $WordsInputPanel

@onready var load_button = $ButtonMenu/LoadCharacterButton
@onready var login_ui = $LoginUI
@onready var new_character_button = $ButtonMenu/NewCharacterButton

# === Internal State ===
var storyteller_name = "Storyteller"  # Default fallback

# === READY ===
func _ready():

	storyteller_button.pressed.connect(_on_storyteller_button_pressed)
	load_button.pressed.connect(_on_load_character_pressed)
	new_character_button.pressed.connect(_on_new_character_pressed)
	
	pass


func _on_new_character_pressed():
	print("🧬 New Character button pressed.")
	get_tree().change_scene_to_file("res://scene/CharacterCreation.tscn")

func _on_load_character_pressed():
	print("🔁 Load Character button pressed.")
	MusicManager.fade_out()
	_connect_to_server_for_loading()

func _connect_to_server_for_loading():
	multiplayer.multiplayer_peer = null  # ✅ RESET BEFORE RECONNECT
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("155.138.161.5", 43210)
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
