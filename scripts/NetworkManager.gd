extends Node

signal zone_character_list_received(names: Array)

signal all_character_names_received(names: Array)

const CHAT_DIVIDER := "[color=gray]────────────────────[/color]\n"

const EDIT_LOG_DIR := "user://logs/"
const EDIT_LOG_PATH := EDIT_LOG_DIR + "character_edits.txt"

func _ready():
	print("🌐 NetworkManager _ready() called")
	print("🌐 Multiplayer ID:", multiplayer.get_unique_id())
	print("🌐 Is Server:", multiplayer.is_server())
	print("🌐 Node Path:", get_path())
	DirAccess.make_dir_recursive_absolute(EDIT_LOG_DIR)



@rpc("any_peer")
func register_character(char_name: String, is_storyteller: bool):
	print("Register_Character_Called_Offline")
	if not multiplayer.is_server():
		return
		
	print("📥 register_character() CALLED")
	print("🔐 Is server?:", multiplayer.is_server())
	print("Registering character:")
	print("  - Name: ", char_name)
	print("  - Is Storyteller: ", is_storyteller)

	# === Create and register character ===
	var char_data = CharacterData.new()
	print("🧪 CharacterData type:", typeof(char_data))
	print("🧪 Is character_data a Resource?", char_data is Resource)
	print("🧪 Is character_data a Node?", char_data is Node)

	char_data.name = char_name
	char_data.is_storyteller = is_storyteller
	char_data.current_zone = "OOC"

	# === Add to global registries
	GameManager.character_data_by_name[char_name] = char_data
	var peer_id = multiplayer.get_remote_sender_id()
	GameManager.character_peers[char_name] = peer_id
	GameManager.peer_to_character_name[peer_id] = char_name
	print("🧠 Mapping peer → name:", peer_id, "→", GameManager.peer_to_character_name[peer_id])
	print("📜 Full peer_to_character_name:", GameManager.peer_to_character_name)

	# === Add character to their starting zone (OOC)
	ZoneManager.zones["OOC"]["characters"].append(char_data)
	print("✅ Server added", char_data.name, "to OOC")
	print("📋 Server characters in OOC:", ZoneManager.zones["OOC"]["characters"])

	# Note: You'll need to manually send char_data back to the client if you want the UI to display it
signal message_received(data: Dictionary)

@rpc("authority")
func receive_message(data: Dictionary):
	if multiplayer.is_server():
		print("📨 [Server] Received message (not emitting)")
		return

	var content = data.get("message", "")

	# UI display
	var local_name: String = GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), "")
	if not local_name.is_empty():
		var ui = GameManager.character_uis.get(local_name, null)
		if ui and ui.has_method("display_message"):
			ui.display_message(content)

	# Emit full packet (not just content) to audio layer
	emit_signal("message_received", data)  # data = Dictionary






@rpc("any_peer")
func handle_incoming_message(data: Dictionary):
	if not multiplayer.is_server():
		return

	var message_type = data.get("type", "")

	match message_type:
		"speak":
			MessagesManager.process_speak(data)
		"whisper":
			MessagesManager.process_whisper(data)
		"emote":
			MessagesManager.process_emote(data)
		"ooc":
			MessagesManager.process_ooc(data)
		"tell":
			MessagesManager.process_tell(data)
		"describe":
			MessagesManager.process_describe(data)
		_:
			print("❌ Unknown message type received:", message_type)




signal zone_name_received(zone_name: String)
signal zone_description_received(desc: String)

@rpc("any_peer")
func request_zone_name(char_name: String):
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(char_name):
		return
	var zone_name = GameManager.character_data_by_name[char_name].current_zone
	var peer_id = GameManager.character_peers.get(char_name, -1)
	if peer_id != -1:
		rpc_id(peer_id, "receive_zone_name", zone_name)

@rpc("any_peer")
func request_zone_character_list(char_name: String):
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(char_name):
		print("❌ Unknown character")
		return

	var peer_id = GameManager.character_peers.get(char_name, -1)
	if peer_id == -1:
		print("❌ No peer found for", char_name)
		return

	var mode = GameManager.current_mode_by_peer.get(peer_id, "whisper")
	print("🛰️  Mode for", char_name, "is", mode)
	var zone_name = GameManager.character_data_by_name[char_name].current_zone
	var zone_data = ZoneManager.zones.get(zone_name, {})
	var characters = zone_data.get("characters", [])
	var is_neighborhood = zone_data.get("is_neighborhood", false)

	if is_neighborhood:
		rpc_id(peer_id, "receive_zone_character_list", ["The city stretches all around you."])
		return

	print("🗺️  Characters in zone '%s':" % zone_name)
	for character in characters:
		print("  -", character.name, "| is_storyteller:", character.is_storyteller)

	var names := []
	for char_data in characters:
		if char_data.name == char_name:
			continue  # Skip self

		if mode == "possess":
			if not char_data.is_storyteller and not GameManager.possessed_characters.has(char_data.name):
				names.append(char_data.name)
		else:
			names.append(char_data.name)

	print("🎯 Final selectable names:", names)
	rpc_id(peer_id, "receive_zone_character_list", names)


@rpc("any_peer")
func request_zone_description(char_name: String):
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(char_name):
		print("❌ Unknown character:", char_name)
		return

	var char_data = GameManager.character_data_by_name[char_name]
	var zone_id = char_data.current_zone
	var viewpoint_id = char_data.current_viewpoint

	if not ZoneManager.zones.has(zone_id):
		print("❌ Unknown zone:", zone_id)
		return

	var zone_data = ZoneManager.zones[zone_id]
	var viewpoints_dict = zone_data.get("viewpoints", {})

	var viewpoint_data = viewpoints_dict.get(viewpoint_id, null)

	var description = ""
	var sound_path = ""

	if viewpoint_data != null:
		description = viewpoint_data.get("description", "No description available.")
		sound_path = viewpoint_data.get("sound_path", "")
	else:
		description = "(This viewpoint has no description.)"
		print("⚠ Viewpoint missing from zone definition.")

	var peer_id = GameManager.character_peers.get(char_name, -1)
	if peer_id != -1:
		var packet = {
			"description": description,
			"sound_path": sound_path
		}
		rpc_id(peer_id, "receive_zone_description", packet)
	else:
		print("⚠ No peer ID found for", char_name)



@rpc("authority")
func receive_zone_name(zone_name: String):
	emit_signal("zone_name_received", zone_name)

@rpc("authority")
func receive_zone_character_list(names: Array):
	emit_signal("zone_character_list_received", names)

@rpc("authority")
func receive_zone_description(data: Dictionary):
	emit_signal("zone_description_received", data)

@rpc("any_peer")
func request_zone_move_to(character_name: String, target_zone_or_character: String, move_reason: String = "standard") -> void:
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(character_name):
		print("❌ Move request from unknown character:", character_name)
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0:  # 0 means called directly on server (not via RPC)
		match move_reason:
			"standard", "secret", "load":
				if not _sender_is_owner_or_st(sender_id, character_name):
					print("❌ Move denied — sender does not own character:", character_name)
					return
			"teleport", "to_character", "spawn":
				var sname := GameManager.peer_to_character_name.get(sender_id, "")
				var sdata: CharacterData = GameManager.character_data_by_name.get(sname, null)
				if sdata == null or not sdata.is_storyteller:
					print("❌ Teleport/spawn denied — not a storyteller")
					return

	var char_data = GameManager.character_data_by_name[character_name]
	var old_zone = char_data.current_zone
	var final_target_zone := ""

	match move_reason:
		"standard":
			var current_zone_data: Dictionary = ZoneManager.zones.get(old_zone, {}) as Dictionary
			var connected_zones: Array = current_zone_data.get("connected_zones", []) as Array
			if target_zone_or_character not in connected_zones:
				print("❌ Illegal move from", old_zone, "to", target_zone_or_character)
				return
			final_target_zone = target_zone_or_character

		"spawn", "teleport":
			final_target_zone = target_zone_or_character

		"load":
			print("📥 Load move: skipping connection check between", old_zone, "and", target_zone_or_character)
			final_target_zone = target_zone_or_character

		"to_character":
			if not GameManager.character_data_by_name.has(target_zone_or_character):
				print("❌ Cannot teleport to unknown character:", target_zone_or_character)
				return
			var target_char = GameManager.character_data_by_name[target_zone_or_character]
			final_target_zone = target_char.current_zone

		"summon":
			var summon_peer_id = multiplayer.get_remote_sender_id()
			var summoner_name = GameManager.peer_to_character_name.get(summon_peer_id, "")
			var summoner_data = GameManager.character_data_by_name.get(summoner_name, null)

			if summoner_data == null or not summoner_data.is_storyteller:
				print("❌ Summon denied - not a storyteller")
				return

			final_target_zone = summoner_data.current_zone

		"secret":
			var password := target_zone_or_character.to_lower()
			var match_found := false

			for zone_name in ZoneManager.zones:
				var zone: Dictionary = ZoneManager.zones[zone_name] as Dictionary
				var passwords: Array = zone.get("secret_entry_passwords", []) as Array
				var allowed_origins: Array = zone.get("accessible_from_zones", []) as Array

				for pw in passwords:
					if String(pw).to_lower() == password and old_zone in allowed_origins:
						final_target_zone = zone_name
						match_found = true
						break
				if match_found:
					break

			if not match_found:
				print("❌ Invalid secret move attempt from", old_zone, "with password:", password)
				return
		_:
			print("❌ Unknown move reason:", move_reason)
			return

	# === Move character to resolved zone ===
	ZoneManager.move_character_to_zone(char_data, final_target_zone)

	# ✅ Validate or auto-reset viewpoint if it's invalid in the new zone
	var zone_dict_for_vp: Dictionary = ZoneManager.zones.get(final_target_zone, {}) as Dictionary
	var viewpoints_dict: Dictionary = zone_dict_for_vp.get("viewpoints", {}) as Dictionary
	var valid_viewpoints: Array = viewpoints_dict.keys() as Array
	if valid_viewpoints.find(char_data.current_viewpoint) == -1:
		if valid_viewpoints.size() > 0:
			char_data.current_viewpoint = String(valid_viewpoints[0])
			print("🔄 Auto-switched viewpoint to:", char_data.current_viewpoint)
		else:
			char_data.current_viewpoint = ""
			print("⚠ No valid viewpoints in zone:", final_target_zone)

	print("📦 Moved", character_name, "from", old_zone, "to", final_target_zone, "due to", move_reason)

	var peer_id = GameManager.character_peers.get(character_name, -1)
	if peer_id != -1:
		rpc_id(peer_id, "receive_zone_name", final_target_zone)

		var zone_dict: Dictionary = ZoneManager.zones.get(final_target_zone, {}) as Dictionary

		# ✅ NEW: send zone meta (category + is_neighborhood)
		var category: String = zone_dict.get("category", "")
		var is_neighborhood: bool = zone_dict.get("is_neighborhood", false)
		rpc_id(peer_id, "receive_zone_meta", {
			"category": category,
			"is_neighborhood": is_neighborhood
		})

		if not zone_dict.get("is_neighborhood", false):
			var characters: Array = zone_dict.get("characters", []) as Array
			var names: Array[String] = []
			for other_char in characters:
				if other_char and other_char.name != character_name:
					names.append(other_char.name)
			rpc_id(peer_id, "receive_zone_character_list", names)

		var vp_id: String = String(char_data.current_viewpoint)
		var vp_data: Dictionary = viewpoints_dict.get(vp_id, {}) as Dictionary
		var img_path: String = vp_data.get("image_path", "") as String

		rpc_id(peer_id, "receive_viewpoint_image", {
			"image_path": img_path,
			"char_name": character_name
		})

		send_character_data_to_peer(char_data, peer_id)

signal zone_meta_received(category: String, is_neighborhood: bool)

@rpc("authority")
func receive_zone_meta(payload: Dictionary) -> void:
	var category: String = String(payload.get("category", ""))
	var is_neighborhood: bool = bool(payload.get("is_neighborhood", false))
	emit_signal("zone_meta_received", category, is_neighborhood)




@rpc("any_peer")
func request_create_character(data: Dictionary, st_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	print("🧾 Received character creation request from:", st_name, "(peer ID:", sender_id, ")")
	print("📥 Raw data:", data)

	# Validate Storyteller
	if st_name == "":
		print("❌ No Storyteller name provided")
		return
	var sender_data: CharacterData = GameManager.character_data_by_name.get(st_name, null)
	if sender_data == null or not sender_data.is_storyteller:
		print("❌ Creation denied - not a registered Storyteller")
		return

	# Name checks
	var new_name: String = String(data.get("name", "")).strip_edges()
	if new_name == "":
		print("❌ Creation failed - no name provided")
		return
	if GameManager.character_data_by_name.has(new_name):
		print("❌ Character already exists:", new_name)
		return

	var new_char: CharacterData = CharacterData.new()

	# Cache exported property names to avoid invalid assignments
	var prop_names: Dictionary = {}
	for p in new_char.get_property_list():
		var pd: Dictionary = p
		prop_names[String(pd.get("name", ""))] = true

	# Identity
	if prop_names.has("name"):
		new_char.name = new_name
	if prop_names.has("clan"):
		new_char.clan = String(data.get("clan", ""))
	if prop_names.has("sect"):
		new_char.sect = String(data.get("sect", ""))
	if prop_names.has("nature"):
		new_char.nature = String(data.get("nature", ""))
	if prop_names.has("demeanor"):
		new_char.demeanor = String(data.get("demeanor", ""))
	if prop_names.has("path_name"):
		new_char.path_name = String(data.get("path_name", ""))
	if prop_names.has("description"):
		new_char.description = String(data.get("description", ""))

	# Spawn where the ST is
	if prop_names.has("current_zone"):
		new_char.current_zone = sender_data.current_zone
	if prop_names.has("current_zone_category"):
		new_char.current_zone_category = sender_data.current_zone_category
	if prop_names.has("is_storyteller"):
		new_char.is_storyteller = false

	# Attributes
	for attr in ["strength","dexterity","stamina","charisma","manipulation","appearance","perception","intelligence","wits"]:
		if prop_names.has(attr):
			var v_any: Variant = data.get(attr, 1)
			var v: int
			if typeof(v_any) == TYPE_INT:
				v = v_any
			else:
				v = int(v_any)
			new_char.set(attr, clampi(v, 0, 10))

	# Virtues
	for virtue in ["conscience","self_control","courage","conviction","instinct"]:
		if prop_names.has(virtue):
			var v_any2: Variant = data.get(virtue, 1)
			var v2: int
			if typeof(v_any2) == TYPE_INT:
				v2 = v_any2
			else:
				v2 = int(v_any2)
			new_char.set(virtue, clampi(v2, 0, 10))

	# Mechanics
	if prop_names.has("path"):
		var v_path_any: Variant = data.get("path", 1)
		var v_path: int
		if typeof(v_path_any) == TYPE_INT:
			v_path = v_path_any
		else:
			v_path = int(v_path_any)
		new_char.path = clampi(v_path, 0, 10)

	if prop_names.has("generation"):
		var v_gen_any: Variant = data.get("generation", 0)
		var v_gen: int
		if typeof(v_gen_any) == TYPE_INT:
			v_gen = v_gen_any
		else:
			v_gen = int(v_gen_any)
		new_char.generation = clampi(v_gen, 3, 13)

	if prop_names.has("blood_pool"):
		var v_bp_any: Variant = data.get("blood_pool", 0)
		var v_bp: int
		if typeof(v_bp_any) == TYPE_INT:
			v_bp = v_bp_any
		else:
			v_bp = int(v_bp_any)
		new_char.blood_pool = clampi(v_bp, 0, 50)

	if prop_names.has("blood_pool_max"):
		var v_bpm_any: Variant = data.get("blood_pool_max", 0)
		var v_bpm: int
		if typeof(v_bpm_any) == TYPE_INT:
			v_bpm = v_bpm_any
		else:
			v_bpm = int(v_bpm_any)
		new_char.blood_pool_max = clampi(v_bpm, 0, 50)

	if prop_names.has("blood_per_turn"):
		var v_bpt_any: Variant = data.get("blood_per_turn", 1)
		var v_bpt: int
		if typeof(v_bpt_any) == TYPE_INT:
			v_bpt = v_bpt_any
		else:
			v_bpt = int(v_bpt_any)
		new_char.blood_per_turn = clampi(v_bpt, 0, 10)

	if prop_names.has("willpower_current"):
		var v_wpc_any: Variant = data.get("willpower_current", 0)
		var v_wpc: int
		if typeof(v_wpc_any) == TYPE_INT:
			v_wpc = v_wpc_any
		else:
			v_wpc = int(v_wpc_any)
		new_char.willpower_current = clampi(v_wpc, 0, 10)

	if prop_names.has("willpower_max"):
		var v_wpm_any: Variant = data.get("willpower_max", 0)
		var v_wpm: int
		if typeof(v_wpm_any) == TYPE_INT:
			v_wpm = v_wpm_any
		else:
			v_wpm = int(v_wpm_any)
		new_char.willpower_max = clampi(v_wpm, 0, 10)

	if prop_names.has("experience_points"):
		var v_xp_any: Variant = data.get("experience_points", 0)
		var v_xp: int
		if typeof(v_xp_any) == TYPE_INT:
			v_xp = v_xp_any
		else:
			v_xp = int(v_xp_any)
		new_char.experience_points = clampi(v_xp, 0, 9999)

	if prop_names.has("health_index"):
		var v_hi_any: Variant = data.get("health_index", 7)
		var v_hi: int
		if typeof(v_hi_any) == TYPE_INT:
			v_hi = v_hi_any
		else:
			v_hi = int(v_hi_any)
		new_char.health_index = clampi(v_hi, 0, 999)

	# Abilities
	var all_abilities: Array[String] = [
		"alertness","athletics","awareness","brawl","empathy","expression","intimidation","leadership","streetwise","subterfuge",
		"animal_ken","crafts","drive","etiquette","firearms","larceny","melee","performance","stealth","survival",
		"academics","computer","finance","investigation","law","medicine","occult","politics","science","technology"
	]
	for ab in all_abilities:
		if prop_names.has(ab):
			var v_any3: Variant = data.get(ab, 0)
			var v3: int
			if typeof(v_any3) == TYPE_INT:
				v3 = v_any3
			else:
				v3 = int(v_any3)
			new_char.set(ab, clampi(v3, 0, 10))

	# Backgrounds
	var bgs: Array[String] = [
		"allies","contacts","domain","fame","generation_background","haven","herd",
		"influence","mentor","resources","retainers","rituals","status"
	]
	for bg in bgs:
		if prop_names.has(bg):
			var v_any4: Variant = data.get(bg, 0)
			var v4: int
			if typeof(v_any4) == TYPE_INT:
				v4 = v_any4
			else:
				v4 = int(v_any4)
			new_char.set(bg, clampi(v4, 0, 10))

	# Disciplines
	if prop_names.has("disciplines") and data.has("disciplines"):
		var disc_data: Dictionary = data.get("disciplines", {})
		if typeof(disc_data) == TYPE_DICTIONARY:
			if typeof(new_char.disciplines) != TYPE_DICTIONARY:
				new_char.disciplines = {}
			for disc in disc_data.keys():
				var raw_val: Variant = disc_data[disc]
				var val: int
				if typeof(raw_val) == TYPE_INT:
					val = raw_val
				else:
					val = int(raw_val)
				new_char.disciplines[String(disc)] = clampi(val, 0, 10)

	# Extended containers with explicit coercion

	# Dicts with int values
	if prop_names.has("blood_bonds"):
		var bb_in: Variant = data.get("blood_bonds", {})
		if typeof(bb_in) == TYPE_DICTIONARY:
			var bb_out: Dictionary = {}
			for k in bb_in.keys():
				bb_out[String(k)] = int(bb_in[k])
			new_char.blood_bonds = bb_out

	if prop_names.has("vinculum"):
		var vin_in: Variant = data.get("vinculum", {})
		if typeof(vin_in) == TYPE_DICTIONARY:
			var vin_out: Dictionary = {}
			for k in vin_in.keys():
				vin_out[String(k)] = int(vin_in[k])
			new_char.vinculum = vin_out

	# Arrays that must be Array[String]
	if prop_names.has("derangements"):
		var der_in: Variant = data.get("derangements", [])
		if typeof(der_in) == TYPE_ARRAY:
			var der_out: Array[String] = []
			for e in der_in:
				der_out.append(String(e))
			new_char.derangements = der_out

	if prop_names.has("merits"):
		var mer_in: Variant = data.get("merits", [])
		if typeof(mer_in) == TYPE_ARRAY:
			var mer_out: Array[String] = []
			for e in mer_in:
				mer_out.append(String(e))
			new_char.merits = mer_out

	if prop_names.has("flaws"):
		var flw_in: Variant = data.get("flaws", [])
		if typeof(flw_in) == TYPE_ARRAY:
			var flw_out: Array[String] = []
			for e in flw_in:
				flw_out.append(String(e))
			new_char.flaws = flw_out

	if prop_names.has("ability_specialties"):
		var spec_in: Variant = data.get("ability_specialties", [])
		if typeof(spec_in) == TYPE_ARRAY:
			var spec_out: Array[String] = []
			for e in spec_in:
				spec_out.append(String(e))
			new_char.ability_specialties = spec_out

	if prop_names.has("thaumaturgy_paths"):
		var tpaths_in: Variant = data.get("thaumaturgy_paths", [])
		if typeof(tpaths_in) == TYPE_ARRAY:
			var tpaths_out: Array[String] = []
			for e in tpaths_in:
				tpaths_out.append(String(e))
			new_char.thaumaturgy_paths = tpaths_out

	if prop_names.has("thaumaturgy_rituals"):
		var trits_in: Variant = data.get("thaumaturgy_rituals", [])
		if typeof(trits_in) == TYPE_ARRAY:
			var trits_out: Array[String] = []
			for e in trits_in:
				trits_out.append(String(e))
			new_char.thaumaturgy_rituals = trits_out

	if prop_names.has("necromancy_paths"):
		var npaths_in: Variant = data.get("necromancy_paths", [])
		if typeof(npaths_in) == TYPE_ARRAY:
			var npaths_out: Array[String] = []
			for e in npaths_in:
				npaths_out.append(String(e))
			new_char.necromancy_paths = npaths_out

	if prop_names.has("necromancy_rituals"):
		var nrits_in: Variant = data.get("necromancy_rituals", [])
		if typeof(nrits_in) == TYPE_ARRAY:
			var nrits_out: Array[String] = []
			for e in nrits_in:
				nrits_out.append(String(e))
			new_char.necromancy_rituals = nrits_out

	# Optional other typed arrays you use elsewhere
	if prop_names.has("ritae_auctoritas_known"):
		var ra_in: Variant = data.get("ritae_auctoritas_known", [])
		if typeof(ra_in) == TYPE_ARRAY:
			var ra_out: Array[String] = []
			for e in ra_in:
				ra_out.append(String(e))
			new_char.ritae_auctoritas_known = ra_out

	if prop_names.has("ritae_ignoblis_known"):
		var ri_in: Variant = data.get("ritae_ignoblis_known", [])
		if typeof(ri_in) == TYPE_ARRAY:
			var ri_out: Array[String] = []
			for e in ri_in:
				ri_out.append(String(e))
			new_char.ritae_ignoblis_known = ri_out

	if prop_names.has("inventory"):
		var inv_in: Variant = data.get("inventory", [])
		if typeof(inv_in) == TYPE_ARRAY:
			var inv_out: Array[String] = []
			for e in inv_in:
				inv_out.append(String(e))
			new_char.inventory = inv_out

	if prop_names.has("health_levels"):
		var hl_in: Variant = data.get("health_levels", [])
		if typeof(hl_in) == TYPE_ARRAY:
			var hl_out: Array[String] = []
			for e in hl_in:
				hl_out.append(String(e))
			new_char.health_levels = hl_out

	# Register
	GameManager.character_data_by_name[new_char.name] = new_char
	GameManager.character_peers[new_char.name] = -1
	print("✅ Registered character:", new_char.name)
	print("🧭 Zone:", new_char.current_zone)
	print("🗺️  All characters now:", GameManager.character_data_by_name.keys())

	# Place in zone
	request_zone_move_to(new_char.name, new_char.current_zone, "spawn")

	# Notify creator
	rpc_id(sender_id, "receive_message", { "message": "[b]Character created:[/b] " + new_char.name })


@rpc("any_peer")
func request_possess(target_name: String):
	if not multiplayer.is_server():
		print("🚫 Not server — ignoring possession request.")
		return

	var sender_id = multiplayer.get_remote_sender_id()
	print("📩 Possession request from peer:", sender_id)

	var current_name = GameManager.peer_to_character_name.get(sender_id, "")
	print("🧠 Current character name for sender:", current_name)
	if current_name == "":
		print("❌ No mapped character name for sender")
		return

	var st_data = GameManager.character_data_by_name.get(current_name, null)
	var target_data = GameManager.character_data_by_name.get(target_name, null)

	if st_data == null:
		print("❌ ST character data not found for:", current_name)
		return
	if not st_data.is_storyteller:
		print("❌ Possession denied — not a storyteller:", current_name)
		return
	if target_data == null:
		print("❌ Target character not found:", target_name)
		return
	if target_data.possessed_by != "":
		print("❌ Target already possessed:", target_data.possessed_by)
		return

	# ✅ Store original ST data and mark possession
	GameManager.storyteller_original_forms[current_name] = st_data
	GameManager.possessed_characters[current_name] = target_data.name
	target_data.possessed_by = current_name

	print("💾 Stored original ST data under:", current_name)
	print("📌 Marked", current_name, "as now possessing", target_data.name)

	# 🔁 Update mappings
	GameManager.character_peers[target_data.name] = sender_id
	GameManager.peer_to_character_name[sender_id] = target_data.name
	GameManager.name_to_peer[target_data.name] = sender_id

	print("🧠", current_name, "is now possessing", target_data.name)
	print("📦 character_peers:", GameManager.character_peers)
	print("📦 peer_to_character_name:", GameManager.peer_to_character_name)

	# 📨 Notify client
	rpc_id(sender_id, "receive_message", {
		"message": "[i]You are now possessing " + target_data.name + "[/i]"
	})

	# 🔁 Send character data to client
	var serialized = serialize_character_data(target_data)
	print("📤 Sending possessed data to client for:", target_data.name)
	rpc_id(sender_id, "update_character_data_from_possession", serialized)

func serialize_character_data(data: CharacterData) -> Dictionary:
	var dict := {}
	for property in data.get_property_list():
		var prop_name = property.name
		if prop_name == "script":
			continue  # Never serialize script reference
		dict[prop_name] = data.get(prop_name)
	return dict



func deserialize_character_data(dict: Dictionary) -> CharacterData:
	var new_data = CharacterData.new()
	new_data.set_path("")  # ✨ Clears identity conflict

	for key in dict.keys():
		if key in new_data:
			var value = dict[key]

			# Prevent cyclic resource inclusion
			if typeof(value) == TYPE_OBJECT and value is Resource:
				print("⚠️ Skipping resource assignment for:", key)
				continue

			# This is safe and required
			new_data.set(key, value)
		else:
			print("⚠️ Unknown property during deserialization:", key)

	return new_data


func _sender_is_owner_or_st(sender_id: int, char_name: String) -> bool:
	var sender_name: String = GameManager.peer_to_character_name.get(sender_id, "")
	if sender_name == char_name:
		return true
	var sender_data: CharacterData = GameManager.character_data_by_name.get(sender_name, null)
	return sender_data != null and sender_data.is_storyteller








@rpc("authority")
func update_character_data_from_possession(data_dict: Dictionary) -> void:
	call_deferred("_delayed_update_character_data", data_dict)


func _delayed_update_character_data(data_dict: Dictionary) -> void:
	await get_tree().process_frame  # Wait one frame to ensure MainUI is ready

	var main_ui = get_node_or_null("/root/MainUI")
	if main_ui == null:
		print("❌ MainUI still not found — aborting character update")
		return

	var restored_name = data_dict.get("name", "UNKNOWN")
	print("🧠 update_character_data_from_possession triggered for:", restored_name)

	var new_data = deserialize_character_data(data_dict)

	# ✅ Update peer name mapping on client
	var my_peer_id = multiplayer.get_unique_id()
	var old_local_name := GameManager.peer_to_character_name.get(my_peer_id, "")
	GameManager.peer_to_character_name[my_peer_id] = new_data.name
	print("📌 Updated peer_to_character_name[", my_peer_id, "] =", new_data.name)

	# Remove stale character_uis entry for the previous name
	if not old_local_name.is_empty() and old_local_name != new_data.name:
		GameManager.character_uis.erase(old_local_name)

	# ✅ Apply data to UI
	main_ui.set_character_data(new_data.name)




@rpc("any_peer")
func request_release_control():
	if not multiplayer.is_server():
		print("🚫 Not server — aborting release.")
		return

	var sender_id = multiplayer.get_remote_sender_id()
	print("🛰️ request_release_control from peer:", sender_id)

	var current_name = GameManager.peer_to_character_name.get(sender_id, "")
	print("🧾 Lookup peer_to_character_name[", sender_id, "] =", current_name)
	if current_name == "":
		print("❌ Unknown sender — no character mapped to peer ID.")
		return

	var possessed_data: CharacterData = GameManager.character_data_by_name.get(current_name, null)
	if possessed_data == null:
		print("❌ No CharacterData found for current_name:", current_name)
		return

	var st_name = possessed_data.possessed_by
	print("🧾 possessed_by =", st_name)
	if st_name == "":
		print("❌ Character is not currently possessed by anyone.")
		return

	var original_data: CharacterData = GameManager.storyteller_original_forms.get(st_name, null)
	if original_data == null:
		print("❌ No original data found for ST:", st_name)
		print("🧾 storyteller_original_forms keys:", GameManager.storyteller_original_forms.keys())
		return

	print("🧠 Releasing possession:")
	print("    ST name      :", st_name)
	print("    Possessed    :", current_name)
	print("    Original name:", original_data.name)

	# 🧹 Clear NPC possession flag
	possessed_data.possessed_by = ""
	print("🧹 Cleared possessed_by on:", current_name)

	# 🔁 Reassign peer control to the original ST
	GameManager.character_peers[original_data.name] = sender_id
	GameManager.peer_to_character_name[sender_id] = original_data.name
	GameManager.name_to_peer[original_data.name] = sender_id

	# 🧼 Cleanup tracking
	GameManager.possessed_characters.erase(st_name)
	GameManager.storyteller_original_forms.erase(st_name)

	print("✅ Released possession:")
	print("    Reassigned control to:", original_data.name)
	print("📦 character_peers:", GameManager.character_peers)
	print("📦 peer_to_character_name:", GameManager.peer_to_character_name)

	# 🔁 Send data back to client
	var serialized = serialize_character_data(original_data)
	print("📤 Sending character data back to client:", serialized.get("name", "UNKNOWN"))
	rpc_id(sender_id, "update_character_data_from_possession", serialized)

	rpc_id(sender_id, "receive_message", {
		"message": "[i]You have returned to your original form.[/i]"
	})







func send_character_data_to_peer(char_data: CharacterData, peer_id: int):
	# ✅ Ensure name <-> peer mapping is registered
	GameManager.name_to_peer[char_data.name] = peer_id
	GameManager.peer_to_character_name[peer_id] = char_data.name

	# 📦 Send serialized character data to client
	var dict = serialize_character_data(char_data)
	rpc_id(peer_id, "update_character_data_from_possession", dict)


@rpc("any_peer")
func set_peer_mode(mode: String):
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	GameManager.current_mode_by_peer[peer_id] = mode


@rpc("any_peer")
func request_delete_character(target_name: String):
	if not multiplayer.is_server():
		return

	var peer_id = multiplayer.get_remote_sender_id()
	var sender_name = GameManager.peer_to_character_name.get(peer_id, "")
	var sender_data = GameManager.character_data_by_name.get(sender_name, null)
	var target_data = GameManager.character_data_by_name.get(target_name, null)

	if sender_data == null or not sender_data.is_storyteller:
		print("❌ Not authorized to delete:", sender_name)
		return

	if target_data == null:
		print("❌ Target does not exist:", target_name)
		return

	if target_data.is_storyteller:
		print("❌ Cannot delete storyteller characters")
		return

	if target_data.possessed_by != "":
		print("❌ Cannot delete a possessed character")
		return

	# Remove from zone
	var zone = target_data.current_zone
	if ZoneManager.zones.has(zone):
		ZoneManager.zones[zone]["characters"] = ZoneManager.zones[zone]["characters"].filter(
			func(c): return c.name != target_name
		)

	# Remove from registries
	GameManager.character_data_by_name.erase(target_name)
	GameManager.character_peers.erase(target_name)

	print("🗑️ Deleted character:", target_name)

	rpc_id(peer_id, "receive_message", {
		"message": "[i]Deleted character: %s[/i]" % target_name
	})

signal stat_value_received(stat_name: String, value: int)

# === SERVER: Receives request and responds ===
@rpc("any_peer")
func request_stat_value_server(_peer_id: int, character_name: String, stat_name: String) -> void:
	if not multiplayer.is_server():
		return

	var actual_sender := multiplayer.get_remote_sender_id()
	var character_data = GameManager.character_data_by_name.get(character_name, null)
	if character_data == null:
		print("⚠ Unknown character:", character_name)
		return

	var value = _resolve_stat_value(character_data, stat_name)
	rpc_id(actual_sender, "receive_stat_value", stat_name, value)


func _resolve_stat_value(character_data: Resource, stat_name: Variant) -> int:
	if typeof(stat_name) != TYPE_STRING:
		print("❌ Stat name is not a string:", stat_name)
		return 0

	var lower_name: String = stat_name.to_lower().replace(" ", "_")

	# === Check if it's an actual exported property on the CharacterData ===
	for prop in character_data.get_property_list():
		if prop.name == lower_name:
			return character_data.get(lower_name)

	# === Fallback to abilities dictionary ===
	if character_data.has_method("get"):  # Not needed if safe, but extra check
		var abilities: Dictionary = character_data.get("abilities") if character_data.has_property("abilities") else {}

		if typeof(abilities) == TYPE_DICTIONARY:
			if abilities.has(stat_name):
				return abilities[stat_name]
			var normalized_key: String = lower_name
			if abilities.has(normalized_key):
				return abilities[normalized_key]

	print("⚠ Stat not found on character:", stat_name)
	return 0






@rpc("any_peer")
func request_dice_roll(character_name: String, attr_name: String, ability_name: String, difficulty: int, mode: int, custom_pool_1 := 0, custom_pool_2 := 0, use_specialization: bool = false, use_willpower: bool = false) -> void:
	if not multiplayer.is_server():
		return

	var character_data = GameManager.character_data_by_name.get(character_name, null)
	if character_data == null:
		print("❌ Character not found for roll:", character_name)
		return

	var dice_sender_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(dice_sender_id, character_name):
		print("❌ Dice roll denied — sender does not own character:", character_name)
		return

	var attr_val := 0
	var ability_val := 0
	var total_dice := 0
	var penalty := 0

	# === Determine dice pool ===
	var is_custom := (attr_name == "Custom" and ability_name == "Custom")
	if is_custom:
		attr_val = clamp(custom_pool_1, 0, 20)
		ability_val = clamp(custom_pool_2, 0, 20)
	else:
		attr_val = _resolve_stat_value(character_data, attr_name)
		ability_val = _resolve_stat_value(character_data, ability_name)

		# Apply wound penalties
		match character_data.health_index:
			2, 3:
				penalty = 1
			4, 5:
				penalty = 2
			6:
				penalty = 5
			7:
				penalty = 999  # Incapacitated

	total_dice = max(0, attr_val + ability_val - penalty)

	# === Specialization eligibility ===
	var spec_active := use_specialization and not is_custom and ability_val >= 4

	# === Willpower bonus ===
	var bonus_successes := 0
	if use_willpower and not is_custom and character_data.willpower_current > 0:
		character_data.willpower_current -= 1
		bonus_successes = 1
		GameManager.emit_signal("character_updated", character_name)

	# === Roll dice ===
	var rolls: Array[int] = []
	var successes := 0  # successes before cancellation by ones (includes specialization doubling)
	var ones_count := 0
	var rand = RandomNumberGenerator.new()
	rand.randomize()

	for i in total_dice:
		var roll = rand.randi_range(1, 10)
		rolls.append(roll)

		if roll == 1:
			ones_count += 1

		# Base success check
		if roll >= difficulty:
			successes += 1

			# Specialization bonuses
			if spec_active:
				if roll == 10:
					successes += 1
				elif ability_val >= 5 and roll == 9 and difficulty <= 9:
					successes += 1

	successes += bonus_successes

	# First 1 is ignored when specialization is active
	var effective_ones := ones_count
	if spec_active and ones_count > 0:
		effective_ones = ones_count - 1

	var net_successes := successes - effective_ones

	# Botch logic: unchanged — still based on zero successes and at least one 1
	var is_botch := successes == 0 and ones_count > 0

	# === Interpret result ===
	var result_type := ""
	if is_botch:
		result_type = "Botch"
	elif net_successes <= 0:
		result_type = "Failure"
	elif net_successes == 1:
		result_type = "Marginal Success"
	elif net_successes == 2:
		result_type = "Moderate Success"
	elif net_successes == 3:
		result_type = "Complete Success"
	elif net_successes == 4:
		result_type = "Exceptional Success"
	else:
		result_type = "Phenomenal Success"

	# === Prepare data packet ===
	var data := {
		"speaker": character_name,
		"attribute": attr_name,
		"attribute_value": attr_val,
		"ability": ability_name,
		"ability_value": ability_val,
		"difficulty": difficulty,
		"rolls": rolls,
		"successes": successes,            # before cancellation (after specialization doubling + Willpower)
		"ones_count": ones_count,
		"effective_ones": effective_ones,  # after ignoring first 1 if specialization is active
		"net_successes": net_successes,
		"is_botch": is_botch,
		"result_type": result_type,
		"used_specialization": spec_active,
		"used_willpower": use_willpower,
		"bonus_successes": bonus_successes,
		"total_dice": total_dice
	}

	# === Optional penalty reason ===
	if not is_custom:
		var penalty_text := ""
		match character_data.health_index:
			2, 3:
				penalty_text = "(-1 die due to wounds)"
			4, 5:
				penalty_text = "(-2 dice due to wounds)"
			6:
				penalty_text = "(-5 dice due to wounds)"
			7:
				penalty_text = "Roll reduced to 0 — Incapacitated"
		if penalty_text != "":
			data["penalty_reason"] = penalty_text

	# === Send to processing
	match mode:
		0:
			MessagesManager.process_dicethrow(data)
		1:
			MessagesManager.process_private_dicethrow(data)
		_:
			print("⚠ Unknown dice roll mode:", mode)




@rpc("any_peer")
func request_zone_viewpoint_data(char_name: String) -> void:
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(char_name):
		print("❌ Unknown character:", char_name)
		return

	var char_data = GameManager.character_data_by_name[char_name]
	var zone_id = char_data.current_zone
	var viewpoint_id = char_data.current_viewpoint

	var zone_data = ZoneManager.zones.get(zone_id, {})
	var viewpoint_data = zone_data.get("viewpoints", {}).get(viewpoint_id, {})

	var image_path = viewpoint_data.get("image_path", "")
	var packet := {
		"char_name": char_name,
		"image_path": image_path,
	}

	var peer_id = GameManager.character_peers.get(char_name, -1)
	if peer_id != -1:
		rpc_id(peer_id, "receive_viewpoint_image", packet)


@rpc("any_peer")
func receive_viewpoint_image(data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var char_name = data.get("char_name", "")
	print("🧭 Updating image for:", char_name)

	if not GameManager.character_uis.has(char_name):
		print("❌ No UI found for:", char_name)
		return

	var image_path = data.get("image_path", "")
	if image_path == "":
		print("⚠ No image path provided — skipping load")
		return

	print("🖼 Trying to load image from path:", image_path)

	var texture = load(image_path)
	if texture:
		var ui = GameManager.character_uis[char_name]
		ui.update_viewpoint_image(image_path)
		print("✅ Image updated successfully")
	else:
		print("❌ Failed to load image from:", image_path)








@rpc("any_peer")
func request_change_viewpoint(char_name: String, new_viewpoint: String):
	if not multiplayer.is_server():
		return
	var vp_sender_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(vp_sender_id, char_name):
		print("❌ Viewpoint change denied for:", char_name)
		return
	if not GameManager.character_data_by_name.has(char_name):
		print("❌ Unknown character:", char_name)
		return

	var char_data = GameManager.character_data_by_name[char_name]
	var zone_id = char_data.current_zone

	if not ZoneManager.zones.has(zone_id):
		print("❌ Unknown zone:", zone_id)
		return

	var zone_data = ZoneManager.zones[zone_id]
	var valid_viewpoints = zone_data.get("viewpoints", {}).keys()

	if new_viewpoint not in valid_viewpoints:
		print("❌ Invalid viewpoint:", new_viewpoint)
		return

	char_data.current_viewpoint = new_viewpoint
	print("🔄", char_name, "now viewing:", new_viewpoint)

	# 🖼 Send image path only
	var vp_data = zone_data["viewpoints"].get(new_viewpoint, {})
	var image_path = vp_data.get("image_path", "")

	var peer_id = GameManager.character_peers.get(char_name, -1)
	if peer_id != -1:
		rpc_id(peer_id, "receive_viewpoint_image", {
			"image_path": image_path,
			"char_name": char_name
		})

@rpc("any_peer")
func request_all_character_names(requester_name: String):
	if not multiplayer.is_server():
		return

	if not GameManager.character_data_by_name.has(requester_name):
		print("❌ Tell request from unknown character:", requester_name)
		return

	var peer_id = multiplayer.get_remote_sender_id()
	var all_names := []

	for char_name in GameManager.character_data_by_name.keys():
		if char_name != requester_name:
			all_names.append(char_name)

	rpc_id(peer_id, "receive_all_character_names", all_names)



@rpc("authority")
func receive_all_character_names(names: Array):
	emit_signal("all_character_names_received", names)


@rpc("any_peer")
func request_register_player_character(data: Dictionary):
	print("📥 Received character registration:", data)
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()
	var new_name = data.get("name", "").strip_edges()

	if new_name == "":
		print("❌ Character creation failed - no name provided.")
		return

	if GameManager.character_data_by_name.has(new_name):
		print("❌ Character already exists:", new_name)
		return

	var char_data = CharacterData.new()
	char_data.name = new_name
	char_data.is_storyteller = false
	char_data.current_zone = "OOC"

	# === Identity
	char_data.clan = data.get("clan", "")
	char_data.sect = data.get("sect", "")
	char_data.nature = data.get("nature", "")
	char_data.demeanor = data.get("demeanor", "")
	char_data.path_name = data.get("path_name", "")
	char_data.experience_points = data.get("experience_points", 0)
	char_data.is_vampire = data.get("is_vampire", true)

	# === Attributes
	for attr in ["strength", "dexterity", "stamina", "charisma", "manipulation", "appearance", "perception", "intelligence", "wits"]:
		char_data.set(attr, data.get(attr, 1))

	# === Virtues
	for virtue in ["conscience", "self_control", "courage", "conviction", "instinct"]:
		char_data.set(virtue, data.get(virtue, 0))

	# === Mechanics
	for mech in ["path", "generation", "blood_pool", "blood_pool_max", "blood_per_turn", "willpower_max", "willpower_current"]:
		char_data.set(mech, data.get(mech, 1))

	# === Abilities: Talents, Skills, Knowledges
	var ability_names := [
		"alertness", "athletics", "awareness", "brawl", "empathy", "expression", "intimidation", "leadership", "streetwise", "subterfuge",
		"animal_ken", "crafts", "drive", "etiquette", "firearms", "larceny", "melee", "performance", "stealth", "survival",
		"academics", "computer", "finance", "investigation", "law", "medicine", "occult", "politics", "science", "technology"
	]
	for ability in ability_names:
		char_data.set(ability, data.get(ability, 0))

	# === Ability Specializations (registration only)
	var raw_specs = data.get("ability_specialties", [])
	var ability_specialties_clean: Array[String] = []
	if raw_specs is Array:
		for entry in raw_specs:
			if typeof(entry) == TYPE_STRING and entry != "":
				ability_specialties_clean.append(entry)
	char_data.ability_specialties = ability_specialties_clean
	print("🧩 Specializations:", char_data.ability_specialties)

	# === Backgrounds
	var background_names := [
		"allies", "contacts", "domain", "fame", "generation_background",
		"haven", "herd", "influence", "mentor", "resources",
		"retainers", "rituals", "status"
	]
	for background in background_names:
		char_data.set(background, data.get(background, 0))

	# === Derangements
	var raw_derangements = data.get("derangements", [])
	var clean_derangements: Array[String] = []
	if raw_derangements is Array:
		for d in raw_derangements:
			if typeof(d) == TYPE_STRING:
				clean_derangements.append(d)
	char_data.derangements = clean_derangements

	# === Disciplines
	char_data.disciplines = data.get("disciplines", {})

	# === Thaumaturgy Paths (registration only)
	var raw_paths = data.get("thaumaturgy_paths", [])
	var paths: Array[String] = []
	if raw_paths is Array:
		for entry in raw_paths:
			if typeof(entry) == TYPE_STRING and entry != "":
				paths.append(entry)
	char_data.thaumaturgy_paths = paths

	# === Thaumaturgy Rituals (registration only)
	var raw_rituals = data.get("thaumaturgy_rituals", [])
	var rituals: Array[String] = []
	if raw_rituals is Array:
		for r in raw_rituals:
			if typeof(r) == TYPE_STRING and r != "":
				rituals.append(r)
	char_data.thaumaturgy_rituals = rituals

	# === Necromancy Paths (registration only)
	var raw_necro_paths = data.get("necromancy_paths", [])
	var necro_paths: Array[String] = []
	if raw_necro_paths is Array:
		for entry in raw_necro_paths:
			if typeof(entry) == TYPE_STRING and entry != "":
				necro_paths.append(entry)
	char_data.necromancy_paths = necro_paths

	# === Necromancy Rituals (registration only)
	var raw_necro_rituals = data.get("necromancy_rituals", [])
	var necro_rituals: Array[String] = []
	if raw_necro_rituals is Array:
		for r in raw_necro_rituals:
			if typeof(r) == TYPE_STRING and r != "":
				necro_rituals.append(r)
	char_data.necromancy_rituals = necro_rituals

	# === Merits & Flaws
	char_data.merits = data.get("merits", [])
	char_data.flaws = data.get("flaws", [])
	
	# === Finalize
	GameManager.character_data_by_name[char_data.name] = char_data
	GameManager.character_peers[char_data.name] = sender_id
	GameManager.peer_to_character_name[sender_id] = char_data.name

	ZoneManager.move_character_to_zone(char_data, char_data.current_zone)

	print("✅ Player character registered:", char_data.name)
	print("🧭 Zone:", char_data.current_zone)

	# 🩸 Add this here:
	print("🔍 Final blood values:", {
		"blood_pool": char_data.blood_pool,
		"blood_pool_max": char_data.blood_pool_max,
		"blood_per_turn": char_data.blood_per_turn
	})

	# Send full data back to client
	rpc_id(sender_id, "receive_character_data", serialize_character_data(char_data))




@rpc("authority")
func receive_character_data(data: Dictionary) -> void:
	print("📥 Receiving character data on client:", data.get("name", "Unknown"))
	var character := CharacterData.new()
	character.deserialize_from_dict(data)
	GameManager.peer_to_character_name[multiplayer.get_unique_id()] = character.name
	if SettingsManager:
		SettingsManager.sync_from_character_data(character)
	on_character_received(character)

@rpc("any_peer")
func request_save_character(character_dict: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var char_name = character_dict.get("name", "")
	if char_name == "":
		print("❌ Save failed — no name in dictionary.")
		return

	var save_sender_id := multiplayer.get_remote_sender_id()
	if save_sender_id != 0 and not _sender_is_owner_or_st(save_sender_id, char_name):
		print("❌ Save denied — sender does not own character:", char_name)
		return

	var character = GameManager.character_data_by_name.get(char_name)
	if character == null:
		print("❌ Character not found:", char_name)
		return

	# ✅ Apply updated password if provided
	if character_dict.has("character_password"):
		character.character_password = character_dict["character_password"]
		print("🔐 Server-side password updated for", char_name)

	# 🔽 DO NOT call deserialize_from_dict!
	# Just save the server’s copy as-is — it already contains the latest state
	print("✅ [request_save_character] Saving up-to-date character:", character.name)
	SaveManager.save_character(character)
	print("✅ Character saved:", character.name)





# === CLIENT: Receives stat from server ===
@rpc("any_peer")
func receive_stat_value(stat_name: String, value: int) -> void:
	emit_signal("stat_value_received", stat_name, value)

@rpc("any_peer")
func request_load_character(character_name: String, submitted_password: String) -> void:
	if not multiplayer.is_server():
		return

	var save_path = "user://characters/" + character_name + ".tres"
	if not FileAccess.file_exists(save_path):
		print("❌ No saved character found for:", character_name)
		return

	var char_data := ResourceLoader.load(save_path)
	if char_data == null or not (char_data is CharacterData):
		print("❌ Invalid character file:", character_name)
		return
		
	if char_data.name != character_name:
			if char_data.name.to_lower() == character_name.to_lower():
				print("❌ Name capitalization mismatch for:", character_name, "Expected:", char_data.name)
			else:
				print("❌ Character name mismatch for:", character_name, "Expected:", char_data.name)
			return

	if char_data.character_password != submitted_password:
		print("❌ Incorrect password for:", character_name)
		return

	print("✅ Character loaded:", character_name)

	# 🧠 Register character in GameManager
	var peer_id := multiplayer.get_remote_sender_id()
	GameManager.character_data_by_name[character_name] = char_data
	GameManager.peer_to_character_name[peer_id] = character_name
	GameManager.character_peers[character_name] = peer_id  # ✅ Use correct key

	# 🚚 Move them to their saved zone (teleport bypasses connection checks)
	request_zone_move_to(character_name, char_data.current_zone, "load")

	# 📦 Send character data back to client as a dictionary
	var dict = char_data.serialize_to_dict()
	rpc_id(peer_id, "handle_received_character_data", dict)

@rpc("any_peer")
func handle_received_character_data(data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var character := CharacterData.new()
	character.deserialize_from_dict(data)

	GameManager.peer_to_character_name[multiplayer.get_unique_id()] = character.name

	if Engine.has_singleton("SettingsManager") or SettingsManager:
		SettingsManager.sync_from_character_data(character)

	NetworkManager.on_character_received(character)



func on_character_received(character: CharacterData) -> void:
	var main_ui = load("res://scene/main_ui.tscn").instantiate()
	main_ui.set_character_data(character.name)
	GameManager.character_uis[character.name] = main_ui
	get_tree().root.add_child(main_ui)
	var old_scene = get_tree().current_scene
	get_tree().current_scene = main_ui
	if old_scene:
		old_scene.queue_free()
	print("✅ Main UI loaded for:", character.name)




func handle_peer_disconnected(peer_id: int) -> void:
	print("📴 Handling disconnection for peer:", peer_id)

	var char_name = GameManager.peer_to_character_name.get(peer_id, "")
	if char_name == "":
		print("⚠️ No character for peer:", peer_id)
		return

	var char_data = GameManager.character_data_by_name.get(char_name, null)
	if char_data:
		# 💾 Auto-save only if the character has a password set
		if char_data.character_password != "":
			if has_node("/root/SaveManager"):
				SaveManager.save_character(char_data)
			else:
				print("❌ SaveManager not found — could not auto-save:", char_name)
		else:
			print("🕳 No password — skipping auto-save for:", char_name)

		# Remove from current zone
		var zone_name = char_data.current_zone
		if ZoneManager.zones.has(zone_name):
			var zone_dict = ZoneManager.zones[zone_name]
			zone_dict["characters"] = zone_dict["characters"].filter(
				func(c): return c.name != char_name
			)
			print("🚪 Removed", char_name, "from zone:", zone_name)

		# 🌒 Notify zone of abrupt disconnection
		MessagesManager.notify_disconnect(char_name, zone_name)


	# Clean up GameManager references
	GameManager.character_data_by_name.erase(char_name)
	GameManager.character_peers.erase(char_name)
	GameManager.name_to_peer.erase(char_name)
	GameManager.peer_to_character_name.erase(peer_id)
	GameManager.current_mode_by_peer.erase(peer_id)
	GameManager.character_uis.erase(char_name)

	# Storyteller possession cleanup
	if GameManager.storyteller_original_forms.has(char_name):
		var possessed_name = GameManager.possessed_characters.find_key(char_name)
		if possessed_name:
			GameManager.possessed_characters.erase(possessed_name)
		GameManager.storyteller_original_forms.erase(char_name)

	print("🧹 Finished cleaning up character:", char_name)


@rpc("any_peer")
func set_character_description(character_name: String, description: String) -> void:
	if not multiplayer.is_server():
		return
	var desc_sender_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(desc_sender_id, character_name):
		print("❌ Description update denied for:", character_name)
		return
	var character = GameManager.character_data_by_name.get(character_name)
	if character == null:
		print("❌ Character not found:", character_name)
		return

	character.description = description
	print("✅ [set_character_description] Updated:", character_name, "->", character.description)

	# 🔽 Save it
	var dict: Dictionary = character.serialize_to_dict()
	print("📦 [set_character_description] Serialized Description:", dict.get("description", "MISSING"))
	request_save_character(dict)


################ Description ############

@rpc("any_peer")
func request_character_description(requester_name: String, target_name: String):
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(target_name):
		print("❌ Target not found for description:", target_name)
		return

	var target_data = GameManager.character_data_by_name[target_name]
	var description: String = target_data.description.strip_edges()

	if description.is_empty():
		description = "No description available."

	var requester_peer: int = GameManager.character_peers.get(requester_name, -1)
	if requester_peer == -1:
		print("❌ Could not find peer for:", requester_name)
		return

	# Load the portrait bytes from disk based on character name
	var portrait_path := "user://portraits/%s.png" % target_name
	var portrait_bytes := PackedByteArray()

	if FileAccess.file_exists(portrait_path):
		var file := FileAccess.open(portrait_path, FileAccess.READ)
		if file:
			portrait_bytes = file.get_buffer(file.get_length())
			file.close()
			print("🖼️ Loaded portrait for", target_name)
	else:
		print("⚠️ No portrait image found for", target_name)

	# Send the chat log description with divider
	var packet := {
		"type": "description",
		"speaker": target_name,
		"message": CHAT_DIVIDER + "[b]%s[/b]'s description:\n%s" % [target_name, description]
	}
	rpc_id(requester_peer, "receive_message", packet)

	# Send the character display popup
	rpc_id(requester_peer, "show_character_display", requester_name, target_name, description, portrait_bytes)




@rpc("authority")
func show_character_display(requester_name: String, target_name: String, description: String, image_bytes: PackedByteArray):
	if not GameManager.character_uis.has(requester_name):
		print("⚠️ No local character UI found for:", requester_name)
		return

	var main_ui = GameManager.character_uis[requester_name]
	if not is_instance_valid(main_ui):
		print("⚠️ Main UI invalid for:", requester_name)
		return

	main_ui.show_character_display(target_name, description, image_bytes)

@rpc("any_peer", "reliable")
func request_self_image_preview(requester_name: String) -> void:
	# Verify caller identity
	var sender_peer: int = multiplayer.get_remote_sender_id()
	var mapped_name: String = GameManager.peer_to_character_name.get(sender_peer, "")
	if mapped_name != requester_name:
		print("❌ request_self_image_preview: name mismatch for peer %d" % sender_peer)
		return

	# Load portrait bytes from disk by name
	var portrait_bytes: PackedByteArray = PackedByteArray()
	var portrait_path: String = "user://portraits/%s.png" % requester_name

	if FileAccess.file_exists(portrait_path):
		var file: FileAccess = FileAccess.open(portrait_path, FileAccess.READ)
		if file != null:
			portrait_bytes = file.get_buffer(file.get_length())
			file.close()
			print("🖼️ Loaded self portrait for", requester_name)
	else:
		# Optional fallback: pull bytes from server-side CharacterData if present
		if GameManager.character_data_by_name.has(requester_name):
			var cd: Resource = GameManager.character_data_by_name[requester_name] as Resource
			var v_img: Variant = cd.get("portrait_bytes")
			if typeof(v_img) == TYPE_PACKED_BYTE_ARRAY:
				portrait_bytes = v_img
		if portrait_bytes.is_empty():
			print("⚠️ No portrait image found for", requester_name)

	# Call the same popup. Pass empty description since this is image-only.
	rpc_id(sender_peer, "show_character_display", requester_name, requester_name, "", portrait_bytes)


# === Storyteller Editor ====
@rpc("any_peer")
func request_character_data_for_edit(character_name: String) -> void:
	if not multiplayer.is_server():
		print("❌ request_character_data_for_edit() must only run on the server")
		return

	var sender_peer := multiplayer.get_remote_sender_id()
	if sender_peer == -1:
		print("❌ Invalid sender peer ID — likely called locally on the server")
		return

	var edit_requester_name := GameManager.peer_to_character_name.get(sender_peer, "")
	var edit_requester_data: CharacterData = GameManager.character_data_by_name.get(edit_requester_name, null)
	if edit_requester_data == null or not edit_requester_data.is_storyteller:
		print("❌ Edit data request denied — not a storyteller:", edit_requester_name)
		return

	if not GameManager.character_data_by_name.has(character_name):
		print("❌ Character not found:", character_name)
		return

	var target_data: CharacterData = GameManager.character_data_by_name[character_name]
	var serialized := target_data.serialize_to_dict()

	send_character_data_to_editor.rpc_id(sender_peer, serialized)
	print("📤 Sent character data for editing to peer", sender_peer, "→", character_name)



@rpc("authority")
func send_character_data_to_editor(data: Dictionary) -> void:
	var character_ui = GameManager.character_uis.get(GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), ""), null)
	if character_ui == null:
		print("⚠️ Could not find UI for current character")
		return

	var editable_panel = character_ui.get_node_or_null("CharacterSheetEditableUI")
	if editable_panel == null:
		print("⚠️ Editable panel not found")
		return

	# Create a temporary CharacterData resource and populate it
	var character_resource := CharacterData.new()
	character_resource.deserialize_from_dict(data)
	editable_panel.receive_character_data(character_resource)




######################### ST Editing ##############################

func _ts() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]

func _editor_name_from_peer(pid: int) -> String:
	return GameManager.peer_to_character_name.get(pid, "PEER_%s" % str(pid))

func _log_character_edit_text(editor_peer_id: int, target_before: String, target_after: String, change: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	# Ensure file exists before opening READ_WRITE (which won't create)
	if not FileAccess.file_exists(EDIT_LOG_PATH):
		var nf := FileAccess.open(EDIT_LOG_PATH, FileAccess.WRITE)
		if nf:
			nf.close()
		else:
			push_error("Failed to create edit log file: %s (err %s)" % [EDIT_LOG_PATH, str(FileAccess.get_open_error())])
			return

	var editor_name := _editor_name_from_peer(editor_peer_id)
	var lines: PackedStringArray = []
	lines.append("=== CHARACTER EDIT ===")
	lines.append("Time: %s" % _ts())
	lines.append("Editor: %s (peer %s)" % [editor_name, str(editor_peer_id)])
	lines.append("Target: %s -> %s" % [target_before, target_after])
	lines.append("Change:")
	lines.append(JSON.stringify(change, "  ", true))
	lines.append("") # blank line

	var f := FileAccess.open(EDIT_LOG_PATH, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_string("\n".join(lines) + "\n")
		f.close()
	else:
		push_error("Failed to open edit log file: %s (err %s)" % [EDIT_LOG_PATH, str(FileAccess.get_open_error())])


@rpc("any_peer")
func request_edit_character(character_name: String, change_dict: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if not GameManager.character_data_by_name.has(character_name):
		print("❌ Character not found:", character_name)
		return

	var editor_peer_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(editor_peer_id, character_name):
		print("❌ Edit denied — not owner or storyteller for:", character_name)
		return
	var original_target := character_name

	var character_data: CharacterData = GameManager.character_data_by_name[character_name]

	var property_names: Array[String] = []
	for prop in character_data.get_property_list():
		property_names.append(prop.name)

	for key in change_dict.keys():
		var value = change_dict[key]

		if key == "disciplines":
			if typeof(value) == TYPE_DICTIONARY:
				var new_disc: Dictionary = {}
				for k in value.keys():
					new_disc[String(k)] = int(value[k])
				character_data.disciplines = new_disc
			continue

		if key == "blood_bonds":
			if typeof(value) == TYPE_DICTIONARY:
				var bb: Dictionary = {}
				for k in value.keys():
					bb[String(k)] = int(value[k])
				character_data.blood_bonds = bb
			continue

		if key == "vinculum":
			if typeof(value) == TYPE_DICTIONARY:
				var vc: Dictionary = {}
				for k in value.keys():
					vc[String(k)] = int(value[k])
				character_data.vinculum = vc
			continue

		if key == "derangements" or key == "merits" or key == "flaws" \
			or key == "ability_specialties" or key == "thaumaturgy_paths" or key == "thaumaturgy_rituals" \
			or key == "necromancy_paths" or key == "necromancy_rituals" \
			or key == "ritae_auctoritas_known" or key == "ritae_ignoblis_known" \
			or key == "inventory" or key == "health_levels":
			var arr: Array[String] = []
			if typeof(value) == TYPE_ARRAY:
				for e in value:
					arr.append(String(e))
			if key == "derangements":
				character_data.derangements = arr
			elif key == "merits":
				character_data.merits = arr
			elif key == "flaws":
				character_data.flaws = arr
			elif key == "ability_specialties":
				character_data.ability_specialties = arr
			elif key == "thaumaturgy_paths":
				character_data.thaumaturgy_paths = arr
			elif key == "thaumaturgy_rituals":
				character_data.thaumaturgy_rituals = arr
			elif key == "necromancy_paths":
				character_data.necromancy_paths = arr
			elif key == "necromancy_rituals":
				character_data.necromancy_rituals = arr
			elif key == "ritae_auctoritas_known":
				character_data.ritae_auctoritas_known = arr
			elif key == "ritae_ignoblis_known":
				character_data.ritae_ignoblis_known = arr
			elif key == "inventory":
				character_data.inventory = arr
			elif key == "health_levels":
				character_data.health_levels = arr
			continue

		if property_names.has(key):
			character_data.set(key, value)
		else:
			pass

	var new_name := String(change_dict.get("name", character_name))
	if new_name != "" and new_name != character_name:
		var old_name := character_name

		GameManager.character_data_by_name.erase(old_name)
		GameManager.character_data_by_name[new_name] = character_data

		if GameManager.character_peers.has(old_name):
			var pid: int = int(GameManager.character_peers.get(old_name, -1))
			if pid != -1:
				GameManager.character_peers.erase(old_name)
				GameManager.character_peers[new_name] = pid

				if GameManager.name_to_peer.has(old_name):
					GameManager.name_to_peer.erase(old_name)
					GameManager.name_to_peer[new_name] = pid

				GameManager.peer_to_character_name[pid] = new_name

		character_name = new_name

	print("✅ Edited character:", character_name)

	_log_character_edit_text(editor_peer_id, original_target, character_name, change_dict)

	var renamed_peer_id: int = -1
	if GameManager.character_peers.has(character_name):
		renamed_peer_id = int(GameManager.character_peers.get(character_name, -1))
		if renamed_peer_id != -1:
			var dict = character_data.serialize_to_dict()
			rpc_id(renamed_peer_id, "receive_edited_character_data", dict)

	# If the character was renamed, notify zone peers so their character lists stay current
	if original_target != character_name:
		var zone_name: String = character_data.current_zone
		var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
		var chars_in_zone: Array = zone_data.get("characters", [])
		for zone_peer_id in _peers_in_zone(zone_name):
			if zone_peer_id == renamed_peer_id:
				continue  # already notified via receive_edited_character_data
			var observer_name: String = GameManager.peer_to_character_name.get(zone_peer_id, "")
			var names: Array[String] = []
			for c in chars_in_zone:
				if c and c.name != observer_name:
					names.append(c.name)
			rpc_id(zone_peer_id, "receive_zone_character_list", names)

@rpc
func receive_edited_character_data(dict: Dictionary) -> void:
	var new_data := CharacterData.new()
	new_data.deserialize_from_dict(dict)

	GameManager.peer_to_character_name[multiplayer.get_unique_id()] = new_data.name
	SettingsManager.sync_from_character_data(new_data)

	var main_ui: Control = GameManager.character_uis.get(new_data.name, null)
	if main_ui != null:
		var sheet_ui: Control = main_ui.get_node_or_null("CharacterSheetUI")
		if sheet_ui != null and sheet_ui.visible:
			sheet_ui.show_character(new_data)


# === Character Sheet ====

@rpc("any_peer")
func request_character_data_for_view(character_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var sender_name: String = GameManager.peer_to_character_name.get(sender_id, "")
	var sender_data: CharacterData = GameManager.character_data_by_name.get(sender_name, null)

	if sender_data == null:
		print("⛔ View request denied: sender not registered.")
		return

	if not GameManager.character_data_by_name.has(character_name):
		print("❌ Character not found for view:", character_name)
		return

	var target_data: CharacterData = GameManager.character_data_by_name[character_name]
	var dict: Dictionary = target_data.serialize_to_dict()

	rpc_id(sender_id, "receive_character_data_for_view", dict, character_name)
	print("📤 Sent viewable character data for", character_name, "to", sender_name)


@rpc("authority", "call_local")
func receive_character_data_for_view(dict: Dictionary, character_name: String) -> void:
	print("🛬 Receiving viewable character data for:", character_name)

	var main_ui: Control = GameManager.character_uis.get(character_name, null)
	if main_ui == null:
		print("❌ MainUI not found for", character_name)
		return

	var sheet_ui: Control = main_ui.get_node_or_null("CharacterSheetUI")
	if sheet_ui == null:
		print("❌ CharacterSheetUI not found.")
		return

	var temp_data: CharacterData = CharacterData.new()
	temp_data.deserialize_from_dict(dict)

	sheet_ui.receive_character_data(temp_data)
	sheet_ui.visible = true

var _description_panel_target: Node = null

func request_character_data_for_description(panel_ref: Node, character_name: String) -> void:
	_description_panel_target = panel_ref
	rpc("request_character_data_for_description_only", character_name)

@rpc("any_peer")
func request_character_data_for_description_only(character_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var sender_name: String = GameManager.peer_to_character_name.get(sender_id, "")
	var sender_data: CharacterData = GameManager.character_data_by_name.get(sender_name, null)

	if sender_data == null:
		print("⛔ Description request denied: sender not registered.")
		return

	if not GameManager.character_data_by_name.has(character_name):
		print("❌ Character not found for description:", character_name)
		return

	var target_data: CharacterData = GameManager.character_data_by_name[character_name]
	var dict: Dictionary = serialize_character_data(target_data)

	rpc_id(sender_id, "receive_character_data_for_description_only", dict, character_name)
	print("📤 Sent description character data for", character_name, "to", sender_name)


@rpc("authority", "call_local")
func receive_character_data_for_description_only(dict: Dictionary, character_name: String) -> void:
	print("🛬 Receiving character data (description-only) for:", character_name)

	if _description_panel_target == null or not _description_panel_target.is_inside_tree():
		print("⚠ No valid panel to receive description data.")
		return

	var temp_data: CharacterData = CharacterData.new()
	temp_data.deserialize_from_dict(dict)

	_description_panel_target.receive_fresh_description_resource(temp_data)
	_description_panel_target = null



################# Temporary Zone Related Code ##########################

@rpc("any_peer")
func request_create_temp_zone(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var zone_name: String = payload.get("name", "").strip_edges()
	var password: String = payload.get("password", "").strip_edges()
	var description: String = payload.get("description", "").strip_edges()
	var creator: String = payload.get("creator", "")
	var creator_data: CharacterData = GameManager.character_data_by_name.get(creator, null)
	var origin_zone: String = creator_data.current_zone if creator_data != null else ""

	if zone_name == "" or password == "" or description == "":
		print("❌ Invalid temp zone payload received")
		return

	if ZoneManager.zones.has(zone_name):
		print("⚠ Zone already exists:", zone_name)
		return

	var zone_data: Dictionary = {
		"zone_name": zone_name,
		"default_viewpoint": "Main",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",
				"description": description,
				"sound_path": ""
			}
		},
		"connected_zones": [origin_zone],
		"characters": [],
		"secret_entry_passwords": [password],
		"accessible_from_zones": [origin_zone],
		"Temporary": true
	}

	ZoneManager.zones[zone_name] = zone_data
	ZoneManager.start_temp_zone_cleanup_timer(zone_name)


	# Send this zone to the client who created it
	var peer_id = GameManager.name_to_peer.get(creator, -1)
	if peer_id != -1:
		print("📨 Syncing new temp zone to creator:", creator)
		rpc_id(peer_id, "receive_new_zone_data", zone_name, zone_data)



###################### Moving Code Related ###############################

@rpc("any_peer")
func request_zone_selection_list(character_name: String, mode: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	var char_data = GameManager.character_data_by_name.get(character_name)

	if char_data == null:
		print("⚠ Invalid character in request_zone_selection_list:", character_name)
		return

	var zone_name = char_data.current_zone
	var zone_res = ZoneManager.zones.get(zone_name)

	if zone_res == null:
		print("⚠ Current zone not found on server:", zone_name)
		return

	var result: Array = []

	match mode:
		"zone":
			result = zone_res.connected_zones.duplicate()

		"teleport":
			result = ZoneManager.zones.keys()

		"viewpoint":
			result = zone_res.viewpoints.keys()

		_:
			print("⚠ Unknown mode in request_zone_selection_list:", mode)
			return

	rpc_id(peer_id, "receive_zone_selection_list", character_name, result)


@rpc("authority")
func receive_zone_selection_list(character_name: String, zone_names: Array) -> void:
	var ui = GameManager.character_uis.get(character_name)
	if ui == null:
		print("⚠ UI not found for character:", character_name)
		return

	var selector = ui.get_node_or_null("LocationSelection")
	if selector == null:
		print("⚠ LocationSelector node not found under character UI for:", character_name)
		return

	selector.populate_zone_list(zone_names)


################ SECURITY FOR NAME ##################
@warning_ignore("unused_signal")
signal name_check_result_received(name_taken: bool)

func request_name_check(char_name: String):
	print("[DEBUG] Client sending name check for:", char_name)
	rpc("_server_request_name_check", char_name)

@rpc("any_peer")
func _server_request_name_check(char_name: String):
	if not multiplayer.is_server():
		print("[DEBUG] request_name_check() ignored — not server")
		return

	var path := "user://characters/" + char_name + ".tres"
	var name_taken := FileAccess.file_exists(path)
	print("[DEBUG] Server checking for existing file at:", path, "| Taken:", name_taken)

	var peer_id := multiplayer.get_remote_sender_id()
	print("[DEBUG] Sending result back to peer:", peer_id)
	rpc_id(peer_id, "receive_name_check_result", name_taken)

@rpc("authority")
func receive_name_check_result(name_taken: bool):
	print("[DEBUG] Client received name check result:", name_taken)
	emit_signal("name_check_result_received", name_taken)

################### Note code for players ##########################
@rpc("any_peer")
func set_character_notes(character_name: String, notes: String) -> void:
	if not multiplayer.is_server():
		return
	var notes_sender_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(notes_sender_id, character_name):
		print("❌ Notes update denied for:", character_name)
		return
	var character = GameManager.character_data_by_name.get(character_name)
	if character == null:
		print("❌ Character not found for notes:", character_name)
		return

	character.notes = notes
	print("✅ [set_character_notes] Updated notes for:", character_name)

	var dict: Dictionary = character.serialize_to_dict()
	request_save_character(dict)


############### Someone is Typing Indicator #######################

@rpc("any_peer")
func report_typing_state(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var char_name: String = data.get("name", "")
	var is_typing: bool = data.get("is_typing", false)
	var mode: String = data.get("mode", "")

	if not ["speak", "emote", "whisper", "ooc", "describe"].has(mode):
		return

	var char_data = GameManager.character_data_by_name.get(char_name, null)
	if not char_data:
		print("⚠ Typing state from unknown character:", char_name)
		
		# Still broadcast to everyone — in case you want to show raw names
		for peer_id in GameManager.peer_to_character_name.keys():
			if peer_id != 1:  # skip host if needed
				rpc_id(peer_id, "receive_typing_update", {
					"name": char_name,
					"is_typing": is_typing
				})
		return  # or optionally: skip the return if that's not what you want

	# Normal zone-based broadcast below
	var zone_name = char_data.current_zone
	var zone_data = ZoneManager.zones.get(zone_name, {})

	if zone_data.get("is_neighborhood", false):
		return

	GameManager.typing_state_by_name[char_name] = is_typing

	var characters_in_zone = zone_data.get("characters", [])
	for other_char in characters_in_zone:
		if not other_char or other_char.name == char_name:
			continue

		var peer_id = GameManager.character_peers.get(other_char.name, -1)
		if peer_id != -1:
			rpc_id(peer_id, "receive_typing_update", {
				"name": char_name,
				"is_typing": is_typing
			})


signal typing_update_received(data: Dictionary)

@rpc("authority")
func receive_typing_update(data: Dictionary) -> void:
	emit_signal("typing_update_received", data)

@rpc("authority")
func flush_typing_state():
	var local_name: String = GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), "")
	if local_name.is_empty():
		print("❌ flush_typing_state skipped: no local character")
		return

	var ui = GameManager.character_uis.get(local_name, null)
	if ui:
		ui.typers_in_zone.clear()
		ui.update_typing_indicator()


@rpc("authority")
func remove_typing_character(char_name: String):
	var local_name: String = GameManager.peer_to_character_name.get(multiplayer.get_unique_id(), "")
	if local_name.is_empty():
		print("❌ remove_typing_character skipped: no local character")
		return

	var ui = GameManager.character_uis.get(local_name, null)
	if ui and ui.typers_in_zone.has(char_name):
		ui.typers_in_zone.erase(char_name)
		ui.update_typing_indicator()


################### Zone Category Updater #################

@rpc("authority")
func receive_zone_category(category: String):
	print("🎶 Received zone category:", category)
	MusicManager.update_ambiance_for_category(category)
	
#############################################################


########################## Character Image Saver ########################################

@rpc("any_peer")
func upload_character_image(char_name: String, data: PackedByteArray):
	if not multiplayer.is_server():
		return
	var img_sender_id := multiplayer.get_remote_sender_id()
	if not _sender_is_owner_or_st(img_sender_id, char_name):
		print("❌ Image upload denied — sender does not own character:", char_name)
		return
	var save_dir := "user://portraits/"
	var save_path := save_dir + char_name + ".png"

	DirAccess.make_dir_absolute(save_dir)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()
		print("✅ Portrait saved as", save_path)
	else:
		print("❌ Failed to write portrait for", char_name)

#######################################################################


# === Internal lookup ===

func _peers_in_zone(zone_name: String) -> Array[int]:
	var out: Array[int] = []
	if not ZoneManager.zones.has(zone_name):
		return out
	var zone: Dictionary = ZoneManager.zones[zone_name]
	var chars: Array = zone.get("characters", []) as Array
	for c in chars:
		var nm := ""
		if c and c.has_method("get"):
			nm = str(c.name)
		elif typeof(c) == TYPE_STRING:
			nm = str(c)
		if nm == "":
			continue
		if GameManager.name_to_peer.has(nm):
			var pid := int(GameManager.name_to_peer[nm])
			if pid > 0:
				out.append(pid)
	return out


########################################################################################
