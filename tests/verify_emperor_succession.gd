extends SceneTree
## Runtime driver for the Emperor-succession routing fix (s22.5).
## The dormant SuccessionSystem.evaluate_emperor_succession path never fired
## because no death-event producer sets position_tier (always PROVINCIAL_DAIMYO),
## so _process_lord_deaths ran the Emperor through the generic clan path. This
## verifies: (1) the pure evaluate_emperor_succession ordering, and (2) the full
## round-trip — Emperor death → _process_lord_deaths → CONFIRMED succession →
## _apply_confirmed_successions installs the new emperor_id.
## Run: godot --headless -s tests/verify_emperor_succession.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _SS := preload("res://simulation/succession_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _emperor(id: int, heir: int = -1, children: Array = []) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Emperor"
	c.role_position = RoleRegistry.EMPEROR
	c.clan = "Imperial"
	c.family = "Hantei"
	c.status = 10.0
	c.designated_heir_id = heir
	c.children_ids = children
	return c


func _person(id: int, age: int, clan: String = "Imperial") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Child%d" % id
	c.clan = clan
	c.family = "Hantei"
	c.age = age
	c.status = 3.0
	return c


func _init() -> void:
	print("--- Emperor Succession Verification (s22.5) ---")
	_test_evaluate_ordering()
	_test_process_lord_deaths()
	_test_round_trip_installs_emperor()
	_test_crisis_and_suspicious()
	_test_champion_id_refresh()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_evaluate_ordering() -> void:
	print("[1] evaluate_emperor_succession ordering")
	var heir := _person(2, 40)
	var elder := _person(3, 30)
	var younger := _person(4, 20)
	var by_id: Dictionary = {2: heir, 3: elder, 4: younger}
	# Designated heir wins.
	var emp := _emperor(1, 2, [3, 4])
	by_id[1] = emp
	var r1: Dictionary = _SS.evaluate_emperor_succession(emp, by_id)
	_ok(int(r1["successor_id"]) == 2 and String(r1["method"]) == "designated_heir", "designated heir wins")
	# No heir → eldest child.
	var emp2 := _emperor(1, -1, [3, 4])
	by_id[1] = emp2
	var r2: Dictionary = _SS.evaluate_emperor_succession(emp2, by_id)
	_ok(int(r2["successor_id"]) == 3 and String(r2["method"]) == "eldest_child", "eldest child when no heir")
	# No heir, no children → crisis.
	var emp3 := _emperor(1, -1, [])
	by_id[1] = emp3
	var r3: Dictionary = _SS.evaluate_emperor_succession(emp3, by_id)
	_ok(int(r3["successor_id"]) == -1 and bool(r3["crisis"]), "crisis when no candidate")


func _test_process_lord_deaths() -> void:
	print("[2] _process_lord_deaths routes the Emperor to Imperial succession")
	var heir := _person(2, 40)
	var emp := _emperor(1, 2, [])
	var by_id: Dictionary = {1: emp, 2: heir}
	var chars: Array = [emp, heir]
	var succ_list: Array = []
	var succ_id: Array = [1]
	var topics: Array = []
	var topic_id: Array = [5000]
	var successor_map: Dictionary = {}
	var death_events: Array = [{
		"character_id": 1, "is_lord": true, "suspicious_death": false, "killer_id": -1,
	}]
	_DO._process_lord_deaths(
		death_events, chars, {}, successor_map, succ_list, succ_id, by_id, 100, topics, topic_id
	)
	_ok(succ_list.size() == 1, "one succession created")
	if succ_list.size() == 1:
		var s: SuccessionData = succ_list[0]
		_ok(int(s.position_tier) == int(Enums.LordRank.IMPERIAL), "succession tier = IMPERIAL")
		_ok(s.state == SuccessionData.SuccessionState.CONFIRMED, "orderly heir succession CONFIRMED")
		_ok(int(s.successor_id) == 2, "successor is the designated heir")
	_ok(int(successor_map.get(1, -1)) == 2, "successor_map[emperor] = heir")
	_ok(topics.size() == 1, "a succession topic was created")


func _test_round_trip_installs_emperor() -> void:
	print("[3] round-trip: _apply_confirmed_successions installs new emperor_id")
	var heir := _person(2, 40)
	var emp := _emperor(1, 2, [])
	emp.physical_location = "cap"
	var vassal := _person(9, 25)
	vassal.lord_id = 1
	var by_id: Dictionary = {1: emp, 2: heir, 9: vassal}
	var chars: Array = [emp, heir, vassal]
	var succ_list: Array = []
	var successor_map: Dictionary = {}
	var topics: Array = []
	var death_events: Array = [{"character_id": 1, "is_lord": true, "suspicious_death": false}]
	_DO._process_lord_deaths(
		death_events, chars, {}, successor_map, succ_list, [1], by_id, 100, topics, [6000]
	)
	# Now kill the old Emperor (mark dead) and run the resolution writeback.
	emp.wounds_taken = 99999
	var world_states: Dictionary = {"emperor_id": 1}
	var clans: Dictionary = {}
	var applied: Array = _DO._apply_confirmed_successions(succ_list, chars, by_id, world_states, clans)
	_ok(int(world_states.get("emperor_id", -1)) == 2, "world emperor_id updated to the heir")
	_ok(heir.role_position == RoleRegistry.EMPEROR, "heir now holds the EMPEROR role")
	_ok(heir.status >= 10.0, "heir inherits Emperor status")
	_ok(vassal.lord_id == 2, "Imperial vassal now serves the new Emperor")
	var was_emperor: bool = false
	for r: Dictionary in applied:
		if bool(r.get("is_emperor", false)):
			was_emperor = true
	_ok(was_emperor, "resolution reports an emperor transition")


func _test_crisis_and_suspicious() -> void:
	print("[4] crisis + suspicious → disputed, no auto-confirm")
	# No heir / no children → crisis → disputed, no successor installed.
	var emp := _emperor(1, -1, [])
	var by_id: Dictionary = {1: emp}
	var succ_list: Array = []
	var successor_map: Dictionary = {}
	_DO._process_lord_deaths(
		[{"character_id": 1, "is_lord": true, "suspicious_death": false}],
		[emp], {}, successor_map, succ_list, [1], by_id, 100, [], [7000]
	)
	_ok(succ_list.size() == 1 and (succ_list[0] as SuccessionData).state == SuccessionData.SuccessionState.DISPUTED, "crisis → DISPUTED")
	_ok(not successor_map.has(1), "crisis installs no successor")
	# Assassinated Emperor with a clear heir → disputed (suspicious), not auto-confirmed.
	var heir := _person(2, 40)
	var emp2 := _emperor(1, 2, [])
	var by_id2: Dictionary = {1: emp2, 2: heir}
	var succ_list2: Array = []
	var successor_map2: Dictionary = {}
	_DO._process_lord_deaths(
		[{"character_id": 1, "is_lord": true, "suspicious_death": true}],
		[emp2, heir], {}, successor_map2, succ_list2, [1], by_id2, 100, [], [8000]
	)
	_ok((succ_list2[0] as SuccessionData).state == SuccessionData.SuccessionState.DISPUTED, "suspicious death → DISPUTED even with an heir")
	_ok(not successor_map2.has(1), "disputed succession is not auto-confirmed")


func _test_champion_id_refresh() -> void:
	print("[5] ClanData.champion_id refreshes on a champion's death (role-keyed)")
	# Dead champion + confirmed successor; run the resolution writeback directly.
	var champ := _person(50, 55, "Crab")
	champ.role_position = RoleRegistry.CLAN_CHAMPION
	champ.status = 8.0
	champ.wounds_taken = 99999  # dead
	var heir := _person(51, 30, "Crab")
	var by_id: Dictionary = {50: champ, 51: heir}
	var s := SuccessionData.new()
	s.deceased_id = 50
	s.successor_id = 51
	s.clan = "Crab"
	# Deliberately leave position_tier at its default (the whole point — the old
	# guard keyed on this and never fired).
	s.state = SuccessionData.SuccessionState.CONFIRMED
	var cd := ClanData.new()
	cd.clan_name = "Crab"
	cd.champion_id = 50  # the now-dead champion
	var clans: Dictionary = {"Crab": cd}
	_DO._apply_confirmed_successions([s], [champ, heir], by_id, {}, clans)
	_ok(cd.champion_id == 51, "champion_id updated to the successor (was 50)")
	_ok(heir.role_position == RoleRegistry.CLAN_CHAMPION, "successor holds the Clan Champion role")

	# Control: a non-champion role must NOT touch champion_id.
	var gov := _person(60, 45, "Crab")
	gov.role_position = "Provincial Daimyo"
	gov.wounds_taken = 99999
	var heir2 := _person(61, 30, "Crab")
	var s2 := SuccessionData.new()
	s2.deceased_id = 60
	s2.successor_id = 61
	s2.clan = "Crab"
	s2.state = SuccessionData.SuccessionState.CONFIRMED
	var cd2 := ClanData.new()
	cd2.clan_name = "Crab"
	cd2.champion_id = 99  # untouched marker
	_DO._apply_confirmed_successions([s2], [gov, heir2], {60: gov, 61: heir2}, {}, {"Crab": cd2})
	_ok(cd2.champion_id == 99, "non-champion succession leaves champion_id untouched")
