extends Node

const CHAT_DIVIDER := "[color=gray]────────────────────[/color]\n"

func process_speak(data: Dictionary) -> void:
	var speaker_name: String = data.get("speaker", "")
	var message: String = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name):
		print("❌ Unknown speaker for speak:", speaker_name)
		return

	var speaker_data = GameManager.character_data_by_name[speaker_name]
	var zone_name: String = speaker_data.current_zone
	var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone: Array = zone_data.get("characters", [])

	# Neighborhood restrictions are disabled when the group system is unavailable.
	# Normal non-neighborhood broadcast
	var formatted: String = CHAT_DIVIDER + "[b]%s says:[/b] %s" % [speaker_name, message]
	print(formatted)
	var packet: Dictionary = {
		"message": formatted,
		"speaker": speaker_name,
		"jingle": true
	}
	var notified_peers := {}
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		var char_name: String = char_data.name
		var peer_id: int = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true



func process_whisper(data: Dictionary) -> void:
	var speaker_name: String = data.get("speaker", "")
	var target_name: String = data.get("target", "")
	var message: String = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name) or not GameManager.character_data_by_name.has(target_name):
		print("❌ Whisper speaker or target not found.")
		return

	var speaker_data = GameManager.character_data_by_name[speaker_name]
	var zone_name: String = speaker_data.current_zone
	var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone: Array = zone_data.get("characters", [])

	# Neighborhood restrictions are disabled when the group system is unavailable.
	# Normal non-neighborhood whisper behavior
	var formatted: String = CHAT_DIVIDER + "[i]%s whispers to %s:[/i] %s" % [speaker_name, target_name, message]
	print(formatted)
	var packet: Dictionary = {
		"message": formatted,
		"speaker": speaker_name,
		"jingle": true
	}

	var speaker_peer: int = GameManager.character_peers.get(speaker_name, -1)
	var target_peer: int = GameManager.character_peers.get(target_name, -1)
	var notified_peers: Dictionary = {}

	if speaker_peer != -1:
		get_node("/root/NetworkManager").rpc_id(speaker_peer, "receive_message", packet)
		notified_peers[speaker_peer] = true

	if target_peer != -1 and target_peer != speaker_peer:
		get_node("/root/NetworkManager").rpc_id(target_peer, "receive_message", packet)
		notified_peers[target_peer] = true

	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		var cname: String = char_data.name
		if cname == speaker_name or cname == target_name:
			continue
		if char_data.is_storyteller:
			var peer_id: int = GameManager.character_peers.get(cname, -1)
			if peer_id != -1 and not notified_peers.has(peer_id):
				get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
				notified_peers[peer_id] = true



func process_emote(data: Dictionary) -> void:
	var speaker_name: String = data.get("speaker", "")
	var message: String = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name):
		print("❌ Unknown speaker for emote:", speaker_name)
		return

	var speaker_data = GameManager.character_data_by_name[speaker_name]
	var zone_name: String = speaker_data.current_zone
	var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone: Array = zone_data.get("characters", [])

	# Neighborhood restrictions are disabled when the group system is unavailable.
	# Normal non-neighborhood broadcast
	var formatted: String = CHAT_DIVIDER + "[i]%s %s[/i]" % [speaker_name, message]
	print(formatted)
	var packet: Dictionary = {
		"message": formatted,
		"speaker": speaker_name,
		"jingle": true
	}

	var notified_peers := {}
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		var char_name: String = char_data.name
		var peer_id: int = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true



func process_ooc(data: Dictionary) -> void:
	var speaker_name = data.get("speaker", "")
	var message = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name):
		print("❌ Unknown speaker for ooc:", speaker_name)
		return

	var speaker_data = GameManager.character_data_by_name[speaker_name]
	var zone = speaker_data.current_zone
	var characters_in_zone = ZoneManager.zones.get(zone, {}).get("characters", [])

	var formatted = CHAT_DIVIDER + "(( %s: %s ))" % [speaker_name, message]
	print(formatted)
	var packet = {
		"message": formatted,
		"speaker": speaker_name,
		"jingle": true
	}

	var notified_peers := {}
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		var char_name = char_data.name
		var peer_id = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true


func process_tell(data: Dictionary) -> void:
	var speaker_name = data.get("speaker", "")
	var target_name = data.get("target", "")
	var message = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name) \
	or not GameManager.character_data_by_name.has(target_name):
		print("❌ Tell speaker or target not found.")
		return

	var speaker_peer = GameManager.character_peers.get(speaker_name, -1)
	var target_peer = GameManager.character_peers.get(target_name, -1)

	if speaker_peer == -1 and target_peer == -1:
		print("❌ Tell failed: no valid peers found.")
		return

	var to_sender = {
		"message": CHAT_DIVIDER + "[i]To %s:[/i] %s" % [target_name, message],
		"speaker": speaker_name,
		"jingle": true
	}

	var to_target = {
		"message": CHAT_DIVIDER + "[i]%s tells you:[/i] %s" % [speaker_name, message],
		"speaker": speaker_name,
		"jingle": true
	}

	if speaker_peer != -1:
		get_node("/root/NetworkManager").rpc_id(speaker_peer, "receive_message", to_sender)

	if target_peer != -1:
		get_node("/root/NetworkManager").rpc_id(target_peer, "receive_message", to_target)


func process_dicethrow(data: Dictionary) -> void:
	var speaker_name = data.get("speaker", "")
	var attr_name = data.get("attribute", "")
	var attr_value = data.get("attribute_value", 0)
	var ability_name = data.get("ability", "")
	var ability_value = data.get("ability_value", 0)
	var difficulty = data.get("difficulty", 6)
	var used_specialization: bool = data.get("used_specialization", false)
	var used_willpower: bool = data.get("used_willpower", false)

	var raw_rolls = data.get("rolls", [])
	var rolls: Array[int] = []
	for item in raw_rolls:
		if typeof(item) == TYPE_INT:
			rolls.append(item)

	var char_data = GameManager.character_data_by_name.get(speaker_name)
	if char_data == null:
		print("❌ DiceThrow: Character not found:", speaker_name)
		return

	var zone = char_data.current_zone
	var zone_data = ZoneManager.zones.get(zone, {})
	var characters_in_zone = zone_data.get("characters", [])
	var is_neighborhood = zone_data.get("is_neighborhood", false)

	# === Trust server math (with safe fallbacks) ===
	var successes_before: int = int(data.get("successes", 0))  # after doubling, before ones cancellation
	var ones_count: int = int(data.get("ones_count", 0))
	var effective_ones: int = int(data.get("effective_ones", (ones_count - 1) if (used_specialization and ones_count > 0) else ones_count))
	var net_successes: int = int(data.get("net_successes", successes_before - effective_ones))
	var is_botch: bool = bool(data.get("is_botch", successes_before == 0 and ones_count > 0))
	var total_dice: int = int(data.get("total_dice", rolls.size()))

	# === Build per-die text, annotating doubled dice ===
	var roll_texts: Array[String] = []
	for roll in rolls:
		if roll == 1:
			roll_texts.append("[color=red]1[/color]")
		elif roll >= difficulty:
			var doubled := false
			if used_specialization:
				if roll == 10:
					doubled = true
				elif ability_value >= 5 and roll == 9 and difficulty <= 9:
					doubled = true
			if doubled:
				roll_texts.append("[color=green]%d[/color]x2" % roll)
			else:
				roll_texts.append("[color=green]%d[/color]" % roll)
		else:
			roll_texts.append(str(roll))

	# === Result string (keep your tiers) ===
	var result_text := ""
	if is_botch:
		result_text = "[b][color=red]BOTCHED![/color][/b]"
	elif net_successes <= 0:
		result_text = "[b][color=red]Failure[/color][/b]"
	elif net_successes == 1:
		result_text = "[b][color=green]1 Success[/color][/b] – [i]Marginal Success[/i]"
	elif net_successes == 2:
		result_text = "[b][color=green]2 Successes[/color][/b] – [i]Moderate Success[/i]"
	elif net_successes == 3:
		result_text = "[b][color=green]3 Successes[/color][/b] – [i]Complete Success[/i]"
	elif net_successes == 4:
		result_text = "[b][color=green]4 Successes[/color][/b] – [i]Exceptional Success[/i]"
	else:
		result_text = "[b][color=green]%d Successes[/color][/b] – [i]Phenomenal Success[/i]" % net_successes

	# === Compose message ===
	var msg := ""
	msg += CHAT_DIVIDER
	msg += "[b]%s[/b] rolls:\n" % speaker_name
	msg += "Attribute: [b]%s[/b]  Dice: %d\n" % [attr_name.capitalize() if attr_name != "" else "?", attr_value]
	msg += "Ability: [b]%s[/b]  Dice: %d\n" % [ability_name.capitalize() if ability_name != "" else "?", ability_value]
	msg += "Rolling [b]%d[/b] Dice at Difficulty [b]%d[/b]\n" % [total_dice, difficulty]

	# === Notes ===
	if used_specialization:
		var spec_note := "Specialization active: 10s count double"
		if ability_value >= 5 and difficulty <= 9:
			spec_note += ", 9s count double"
		spec_note += ", first 1 ignored"
		msg += "[i]%s[/i]\n" % spec_note

	if used_willpower:
		msg += "[i]Willpower used: +1 automatic success[/i]\n"

	if data.has("penalty_reason"):
		msg += "[i]%s[/i]\n" % data["penalty_reason"]

	# === Rolls + Result ===
	msg += "[b]Rolls:[/b] %s\n" % ", ".join(roll_texts)
	msg += "\n%s" % result_text

	# === Send to clients in zone ===
	var packet := { "message": msg }
	var notified_peers := {}
	if is_neighborhood:
		# Neighborhood restrictions are disabled when the group system is unavailable.
		pass

	for zone_member_data in characters_in_zone:
		if not zone_member_data or not zone_member_data.has_method("get"):
			continue
		var char_name = zone_member_data.name
		if is_neighborhood:
			var allow_neighborhood: bool = true
			if not allow_neighborhood:
				continue
		var peer_id = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true




func process_private_dicethrow(data: Dictionary) -> void:
	var speaker_name = data.get("speaker", "")
	var attr_name = data.get("attribute", "")
	var attr_value = data.get("attribute_value", 0)
	var ability_name = data.get("ability", "")
	var ability_value = data.get("ability_value", 0)
	var difficulty = data.get("difficulty", 6)
	var used_specialization: bool = data.get("used_specialization", false)

	var raw_rolls = data.get("rolls", [])
	var rolls: Array[int] = []
	for item in raw_rolls:
		if typeof(item) == TYPE_INT:
			rolls.append(item)

	var char_data = GameManager.character_data_by_name.get(speaker_name)
	if char_data == null:
		print("❌ DiceThrow: Character not found:", speaker_name)
		return

	var zone = char_data.current_zone
	var characters_in_zone = ZoneManager.zones.get(zone, {}).get("characters", [])

	# === Trust server math (with safe fallbacks) ===
	var successes_before: int = int(data.get("successes", 0))  # after specialization doubling, before ones cancellation
	var ones_count: int = int(data.get("ones_count", 0))
	var effective_ones: int = int(data.get("effective_ones", (ones_count - 1) if (used_specialization and ones_count > 0) else ones_count))
	var net_successes: int = int(data.get("net_successes", successes_before - effective_ones))
	var is_botch: bool = bool(data.get("is_botch", successes_before == 0 and ones_count > 0))
	var total_dice: int = int(data.get("total_dice", rolls.size()))

	# === Build per-die text, annotating doubled dice ===
	var roll_texts: Array[String] = []
	for roll in rolls:
		if roll == 1:
			roll_texts.append("[color=red]1[/color]")
		elif roll >= difficulty:
			var doubled := false
			if used_specialization:
				if roll == 10:
					doubled = true
				elif ability_value >= 5 and roll == 9 and difficulty <= 9:
					doubled = true
			if doubled:
				roll_texts.append("[color=green]%d[/color]x2" % roll)
			else:
				roll_texts.append("[color=green]%d[/color]" % roll)
		else:
			roll_texts.append(str(roll))

	# === Determine result text ===
	var result_text := ""
	if is_botch:
		result_text = "[b][color=red]BOTCHED![/color][/b]"
	elif net_successes <= 0:
		result_text = "[b][color=red]Failure[/color][/b]"
	elif net_successes == 1:
		result_text = "[b][color=green]1 Success[/color][/b] – [i]Marginal Success[/i]"
	elif net_successes == 2:
		result_text = "[b][color=green]2 Successes[/color][/b] – [i]Moderate Success[/i]"
	elif net_successes == 3:
		result_text = "[b][color=green]3 Successes[/color][/b] – [i]Complete Success[/i]"
	elif net_successes == 4:
		result_text = "[b][color=green]4 Successes[/color][/b] – [i]Exceptional Success[/i]"
	else:
		result_text = "[b][color=green]%d Successes[/color][/b] – [i]Phenomenal Success[/i]" % net_successes

	# === Build final message ===
	var msg := ""
	msg += CHAT_DIVIDER
	msg += "[i](Private Roll)[/i] [b]%s[/b] rolls:\n" % speaker_name
	msg += "Attribute: [b]%s[/b]  Dice: %d\n" % [attr_name.capitalize() if attr_name != "" else "?", attr_value]
	msg += "Ability: [b]%s[/b]  Dice: %d\n" % [ability_name.capitalize() if ability_name != "" else "?", ability_value]
	msg += "Rolling [b]%d[/b] Dice at Difficulty [b]%d[/b]\n" % [total_dice, difficulty]

	# Explicit specialization line
	if used_specialization:
		var spec_note := "Specialization active: 10s count double"
		if ability_value >= 5 and difficulty <= 9:
			spec_note += ", 9s count double"
		spec_note += ", first 1 ignored"
		msg += "[i]%s[/i]\n" % spec_note

	if data.has("penalty_reason"):
		msg += "[i]%s[/i]\n" % data["penalty_reason"]

	msg += "[b]Rolls:[/b] %s\n" % ", ".join(roll_texts)
	msg += "\n%s" % result_text

	var packet := { "message": msg }
	var notified_peers := {}

	for zone_member_data in characters_in_zone:
		if not zone_member_data or not zone_member_data.has_method("get"):
			continue

		var char_name = zone_member_data.name
		var is_storyteller = zone_member_data.is_storyteller

		if char_name == speaker_name or is_storyteller:
			var peer_id = GameManager.character_peers.get(char_name, -1)
			if peer_id != -1 and not notified_peers.has(peer_id):
				get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
				notified_peers[peer_id] = true


func process_virtue_roll(data: Dictionary) -> void:
	var target_name = data.get("speaker", "")
	var virtue_name = data.get("virtue_name", "")
	var virtue_value = data.get("virtue_value", 0)
	var difficulty = data.get("difficulty", 8)
	var rolls: Array = data.get("rolls", [])
	var final_successes = data.get("final_successes", 0)
	var mode = data.get("mode", "path")
	var frenzy_total = data.get("frenzy_total", 0)
	var rotschreck_total = data.get("rotschreck_total", 0)
	var is_botch: bool = data.get("is_botch", false)

	var char_data = GameManager.character_data_by_name.get(target_name)
	if char_data == null:
		print("❌ VirtueRoll: Character not found:", target_name)
		return

	var zone_name = char_data.current_zone
	var zone_data = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone = zone_data.get("characters", [])
	var is_neighborhood = zone_data.get("is_neighborhood", false)

	# === Roll formatting ===
	var roll_texts: Array[String] = []
	for roll in rolls:
		if roll >= difficulty:
			roll_texts.append("[color=green]%d[/color]" % roll)
		elif roll == 1:
			roll_texts.append("[color=red]1[/color]")
		else:
			roll_texts.append(str(roll))

	# === Base display ===
	var result_text := CHAT_DIVIDER
	result_text += "[b]%s[/b] faces a Virtue Test (%s):\n" % [target_name, mode.capitalize()]
	result_text += "Virtue: [b]%s[/b]  Dice: %d  Difficulty: %d\n" % [virtue_name.capitalize(), virtue_value, difficulty]
	if rolls.size() > 0:
		result_text += "[b]Rolls:[/b] %s\n" % ", ".join(roll_texts)
	else:
		result_text += "[b]Rolls:[/b] None\n"

	# === Outcome ===
	match mode:
		"path":
			if is_botch:
				result_text += "\n[b]BOTCH![/b] – Path rating reduced by 1."
			elif final_successes <= 0:
				result_text += "\n[b]Failure[/b] – Path rating reduced by 1."
			elif final_successes == 1:
				result_text += "\n[b]1 Success[/b] – No degeneration."
			else:
				result_text += "\n[b]%d Successes[/b] – No degeneration." % final_successes

		"frenzy":
			if final_successes == -999:
				result_text += "\n[b]Auto-Frenzy[/b] – Character loses control!"
			elif is_botch:
				result_text += "\n[b]BOTCH![/b] – Frenzy triggered!"
			elif final_successes <= 0:
				result_text += "\n[b]Failure[/b] – Frenzy triggered!"
			else:
				result_text += "\n[b]%d Successes[/b] – Gained control. (Frenzy resistance %d/5)" % [final_successes, frenzy_total]

		"rotschreck":
			if final_successes == -999:
				result_text += "\n[b]Auto-Rötschreck[/b] – Character loses control!"
			elif is_botch:
				result_text += "\n[b]BOTCH![/b] – Rötschreck triggered!"
			elif final_successes <= 0:
				result_text += "\n[b]Failure[/b] – Rötschreck triggered!"
			else:
				result_text += "\n[b]%d Successes[/b] – Gained control. (Rötschreck resistance %d/5)" % [final_successes, rotschreck_total]

	# === Message packet ===
	var packet := {
		"message": result_text,
		"type": "virtue_roll",
		"sender": target_name
	}

	# === Send to all in the zone ===
	var notified_peers := {}
	if is_neighborhood:
		# Neighborhood restrictions are disabled when the group system is unavailable.
		pass
	for zone_member_data in characters_in_zone:
		if not zone_member_data or not zone_member_data.has_method("get"):
			continue

		var char_name = zone_member_data.name
		if is_neighborhood:
			var allow_neighborhood: bool = true
			if not allow_neighborhood:
				continue
		var peer_id = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true

func notify_zone_change(event_type: String, character_name: String, zone_name: String) -> void:
	var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone: Array = zone_data.get("characters", [])

	var packet: Dictionary = {}
	match event_type:
		"arrival":
			packet = { "message": CHAT_DIVIDER + "[i]%s has arrived.[/i]" % character_name }
		"departure":
			packet = { "message": CHAT_DIVIDER + "[i]%s has left the area.[/i]" % character_name }
		_:
			print("❌ Unknown zone change event:", event_type)
			return

	var notified_peers: Dictionary = {}

	# Neighborhood restrictions are disabled when the group system is unavailable.
	# Broadcast to everyone in the zone except the mover
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		if char_data.name == character_name:
			continue
		var peer_id: int = GameManager.character_peers.get(char_data.name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true


func notify_disconnect(character_name: String, zone_name: String) -> void:
	var zone_data = ZoneManager.zones.get(zone_name, {})
	if zone_data.get("is_neighborhood", false):
		return  # 🔇 Suppress in neighborhood zones

	var characters_in_zone = zone_data.get("characters", [])
	var packet = {
		"message": CHAT_DIVIDER + "[i]%s seems to grow dull.[/i]" % character_name
	}

	var notified_peers := {}
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		if char_data.name == character_name:
			continue  # 👤 Don't notify the disconnecting character (they're gone)

		var peer_id = GameManager.character_peers.get(char_data.name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			var network = get_node("/root/NetworkManager")

			# 📨 Send visual disconnect message
			network.rpc_id(peer_id, "receive_message", packet)

			# 🕯️ Clean up TypingIndicator state for the disconnecting character
			NetworkManager.rpc_id(peer_id, "remove_typing_character", character_name)

			notified_peers[peer_id] = true



func process_describe(data: Dictionary) -> void:
	var speaker_name = data.get("speaker", "")
	var message = data.get("message", "")

	if not GameManager.character_data_by_name.has(speaker_name):
		print("❌ Unknown speaker for describe:", speaker_name)
		return

	var speaker_data = GameManager.character_data_by_name[speaker_name]
	var zone_name = speaker_data.current_zone
	var zone_data = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone = zone_data.get("characters", [])

	# Neighborhood restrictions are disabled when the group system is unavailable.
	# 🌆 Non-neighborhood zone: broadcast to all in zone
	var formatted = CHAT_DIVIDER + "[i]%s[/i]" % message
	print("🎭 Narration:", formatted)

	var packet = {
		"message": formatted,
		"speaker": speaker_name,
		"jingle": true
	}

	var notified_peers := {}
	for char_data in characters_in_zone:
		if not char_data or not char_data.has_method("get"):
			continue
		var char_name = char_data.name
		var peer_id = GameManager.character_peers.get(char_name, -1)
		if peer_id != -1 and not notified_peers.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified_peers[peer_id] = true


func send_time_message(peer_id: int, ic_date: String, part: String) -> void:
	var divider := "[color=gray]────────────────────[/color]\n"

	# Parse the date string into year, month, day
	var parts := ic_date.split("-")
	if parts.size() != 3:
		print("❌ Invalid date format:", ic_date)
		return

	var year: int = parts[0].to_int()
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()

	# Get the proper suffix (st, nd, rd, th)
	var suffix: String = "th"
	if day % 100 not in [11, 12, 13]:
		match day % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"

	# Month name lookup
	var month_names: PackedStringArray = [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	var month_name: String = month_names[month - 1]

	# Narrative date
	var narrative_date: String = "the %d%s of %s, %d" % [day, suffix, month_name, year]

	# Final message
	var message: String = divider + "[b][Date][/b] It is %s ([i]%s[/i])." % [narrative_date, part]
	var packet := {
		"message": message,
		"speaker": "Time",
		"jingle": false
	}
	NetworkManager.rpc_id(peer_id, "receive_message", packet)


func send_wakeup_message(peer_id: int, message: String) -> void:
	var formatted := CHAT_DIVIDER + "[b]%s[/b]" % message
	var packet := {
		"message": formatted,
		"speaker": "SYSTEM",
		"jingle": false
	}
	NetworkManager.rpc_id(peer_id, "receive_message", packet)

func notify_feed_event(donor_name: String, receiver_name: String) -> void:
	if not GameManager.character_data_by_name.has(donor_name):
		print("❌ notify_feed_event: donor not found:", donor_name)
		return

	var donor_cd = GameManager.character_data_by_name[donor_name]
	var zone_name: String = donor_cd.current_zone
	var zone_data: Dictionary = ZoneManager.zones.get(zone_name, {})
	var characters_in_zone: Array = zone_data.get("characters", [])

	# Always broadcast to everyone in the zone except donor & receiver
	var formatted: String = CHAT_DIVIDER + "[i]%s feeds %s.[/i]" % [donor_name, receiver_name]
	var packet: Dictionary = {
		"message": formatted,
		"speaker": "SYSTEM",
		"jingle": true
	}

	var notified: Dictionary = {}
	for cd in characters_in_zone:
		if not cd or not cd.has_method("get"):
			continue
		var name_in_zone: String = cd.name
		if name_in_zone == donor_name or name_in_zone == receiver_name:
			continue
		var peer_id: int = GameManager.character_peers.get(name_in_zone, -1)
		if peer_id != -1 and not notified.has(peer_id):
			get_node("/root/NetworkManager").rpc_id(peer_id, "receive_message", packet)
			notified[peer_id] = true
