extends Node

var peer: ENetMultiplayerPeer  # Declare at the top like you're doing

func _ready():
	# Initialize the ENet server
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(43210, 32)

	if result != OK:
		print("❌ Failed to start server")
		return

	multiplayer.multiplayer_peer = peer
	print("✅ Server started on port 43210")

	# Connect signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Debug — Check for NetworkManager
	var netman_node = get_node_or_null("/root/NetworkManager")
	print("🧠 Checking for NetworkManager:", netman_node)

	# If not already added by Autoload, inject it manually
	if netman_node == null:
		var netman = preload("res://scripts/managers/NetworkManager.gd").new()
		netman.name = "NetworkManager"
		get_tree().root.add_child(netman)
		print("✅ NetworkManager was missing — created manually.")

func _on_peer_connected(id: int):
	print("🔌 Player connected with ID: %d" % id)

func _on_peer_disconnected(id: int):
	print("🔌 Player disconnected: %d" % id)

	var netman := get_node_or_null("/root/NetworkManager")
	if netman:
		netman.handle_peer_disconnected(id)
