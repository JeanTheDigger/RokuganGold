extends SceneTree

var ok := 0
var fail := 0
func check(label: String, cond: bool) -> void:
	if cond: ok += 1; print("  PASS  ", label)
	else: fail += 1; print("  FAIL  ", label)

func fighter(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.reflexes = 3; c.awareness = 3; c.stamina = 3; c.willpower = 3
	c.agility = 3; c.intelligence = 3; c.strength = 3; c.perception = 3; c.void_ring = 2
	c.skills = {"Kyujutsu": 3, "Kenjutsu": 3}
	return c

func _initialize() -> void:
	print("=== s40 mount producer + cavalry +1k0 + bow mount-TN ===")
	var dice := DiceEngine.new(271828)
	var I := IndividualCombat
	var O := AsciiMapCombatOrchestrator

	# --- Producer: a `mounted` setup flag sets CONDITION_MOUNTED. ---
	var m := AsciiMapData.new(); m.init_tiles(Enums.TileType.FLOOR_STONE)
	var a := fighter(1); var b := fighter(2)
	var st = O.setup_combat(m, [
		{"char": a, "x": 5, "y": 5, "faction": O.FACTION_ENEMY, "stance": Enums.Stance.ATTACK, "mounted": true},
		{"char": b, "x": 9, "y": 5, "faction": O.FACTION_PLAYER, "stance": Enums.Stance.ATTACK},
	], dice)
	var a_p: IndividualCombat.Participant = st.combat.participants[1]
	var b_p: IndividualCombat.Participant = st.combat.participants[2]
	check("mounted flag -> CONDITION_MOUNTED on the participant", I.CONDITION_MOUNTED in a_p.conditions)
	check("unflagged combatant is NOT mounted", I.CONDITION_MOUNTED not in b_p.conditions)

	# --- Bow mount-TN helper values (owner table) ---
	check("dai_kyu +10 on foot", I.weapon_mount_tn_penalty("dai_kyu", false) == 10)
	check("dai_kyu +0 mounted", I.weapon_mount_tn_penalty("dai_kyu", true) == 0)
	check("yumi +10 mounted", I.weapon_mount_tn_penalty("yumi", true) == 10)
	check("yumi +0 on foot", I.weapon_mount_tn_penalty("yumi", false) == 0)
	check("han_kyu +10 mounted", I.weapon_mount_tn_penalty("han_kyu", true) == 10)
	check("katana (no mount sensitivity) +0", I.weapon_mount_tn_penalty("katana", true) == 0)

	# --- Cavalry +1k0 (now LIVE via the producer): mounted attacker rolls more dice vs unmounted. ---
	var T := 4000
	var mounted_hits := 0; var foot_hits := 0
	for i in range(T):
		# mounted attacker (a_p has CONDITION_MOUNTED) vs unmounted target b at Armor TN 25.
		var rm: Dictionary = I.resolve_attack(a, a_p, "katana", 25, 0, dice, false, false, false, "", {}, 0)
		if rm.get("hit", false): mounted_hits += 1
		# foot attacker (b_p, not mounted) same stats vs Armor TN 25.
		var rf: Dictionary = I.resolve_attack(b, b_p, "katana", 25, 0, dice, false, false, false, "", {}, 0)
		if rf.get("hit", false): foot_hits += 1
	print("  katana hits @TN25: mounted=", mounted_hits, "/", T, " foot=", foot_hits, "/", T, " (cavalry +1k0)")
	check("mounted attacker hits more (the now-live cavalry +1k0)", mounted_hits > foot_hits + 100)

	# --- Bow mount-TN end-to-end: a MOUNTED yumi archer faces +10 Armor TN -> fewer hits. ---
	var mh := 0; var fh := 0
	for i in range(T):
		st.positions[1] = Vector2i(5, 5); st.positions[2] = Vector2i(9, 5)
		b.wounds_taken = 0; a.wounds_taken = 0
		# fresh turn states so each shot has its Complex action.
		st.turn_states[1] = O.TurnState.new(); st.turn_states[1].char_id = 1
		st.turn_states[2] = O.TurnState.new(); st.turn_states[2].char_id = 2
		# mounted archer (attacker_id 1) shooting yumi -> +10 TN to the shot.
		var r_m: Dictionary = O.execute_ranged_attack(st, 1, 2, a, b, "yumi", 0, dice)
		if r_m.get("hit", false): mh += 1
		# foot archer (attacker_id 2) shooting yumi -> no penalty.
		var r_f: Dictionary = O.execute_ranged_attack(st, 2, 1, b, a, "yumi", 0, dice)
		if r_f.get("hit", false): fh += 1
	print("  yumi hits: mounted-archer=", mh, " foot-archer=", fh, " (mounted +10 TN penalty)")
	check("mounted yumi archer hits LESS (the +10 mount-TN penalty)", mh < fh)

	print("=== RESULT: ", ok, " passed / ", fail, " failed ===")
	quit()
