extends SceneTree
## Headless runtime driver for the s54.7i Kolat endgame loop.
## Exercises: secrecy scalar helpers, event→delta hooks, the seasonal endgame
## pass (candidate pipeline + response tiers + win check), and the tier-100 purge.
## Run: godot --headless -s tests/verify_kolat_endgame.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _KS := preload("res://simulation/kolat_secrecy.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, name: String, status: float = 3.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.status = status
	c.stamina = 3
	c.willpower = 3
	c.reflexes = 3
	c.awareness = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	return c


func _init() -> void:
	print("--- Kolat Endgame Verification (s54.7i) ---")
	_test_scalar_helpers()
	_test_event_hooks()
	_test_pipeline_and_win()
	_test_response_and_purge()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_scalar_helpers() -> void:
	print("[1] scalar + bundle helpers")
	_ok(_KS.apply_delta(95, 10) == 100, "clamp high")
	_ok(_KS.apply_delta(3, -10) == 0, "clamp low")
	_ok(_KS.exposure_delta(_KS.ExposureEvent.ORG_ASSASSINATION) == 15, "org +15")
	_ok(_KS.exposure_delta(_KS.ExposureEvent.CLOUD_RESURRECT) == -5, "cloud -5")
	_ok(_KS.awareness_delta(_KS.AwarenessEvent.MASTER_INTERROGATED) == 20, "master +20")
	_ok(_KS.response_tier(0) == _KS.ResponseTier.UNAWARE, "tier unaware")
	_ok(_KS.response_tier(30) == _KS.ResponseTier.SUSPICIOUS, "tier suspicious")
	_ok(_KS.response_tier(50) == _KS.ResponseTier.CONFIRMED_THREAT, "tier confirmed")
	_ok(_KS.response_tier(100) == _KS.ResponseTier.FULL_KNOWLEDGE, "tier full")
	_ok(not _KS.is_response_active(29) and _KS.is_response_active(30), "response active at 30")
	var b: Dictionary = _KS.new_bundle()
	_ok(b.has("go_dark") and b.has("purge_done") and b.has("awareness_cases"), "bundle keys")
	_KS.bump(b, "exposure", 15)
	_ok(int(b["exposure"]) == 15, "bump exposure")
	_KS.identify(b, 42)
	_KS.identify(b, 42)
	_ok((b["identified_ids"] as Array).size() == 1 and _KS.is_identified(b, 42), "identify dedup")


func _test_event_hooks() -> void:
	print("[2] event → scalar hooks")
	var chars_by_id: Dictionary = {}
	# A conscious Kolat member (Coin) + a Master (Silk) + a magistrate victim + a plain assassin
	var coin: L5RCharacterData = _mk(1, "Coin Agent")
	coin.kolat_sect = Enums.KolatSect.COIN
	var silk: L5RCharacterData = _mk(2, "Silk Master")
	silk.kolat_sect = Enums.KolatSect.SILK
	silk.is_kolat_master = true
	var magi: L5RCharacterData = _mk(3, "A Magistrate")
	magi.role_position = RoleRegistry.EMERALD_MAGISTRATE
	for c: L5RCharacterData in [coin, silk, magi]:
		chars_by_id[c.character_id] = c

	# --- death exposure (Lotus silences a magistrate, -5) ---
	var b: Dictionary = _KS.new_bundle()
	b["exposure"] = 20
	var deaths: Array = [{
		"cause": "assassination", "character_id": 3, "commissioner_id": 1,
	}]
	_DO._process_kolat_death_exposure(deaths, chars_by_id, b)
	_ok(int(b["exposure"]) == 15, "Lotus death exposure -5")
	# non-Kolat commissioner → no change
	var b2: Dictionary = _KS.new_bundle()
	b2["exposure"] = 20
	_DO._process_kolat_death_exposure([{"cause": "assassination", "character_id": 3, "commissioner_id": 99}], chars_by_id, b2)
	_ok(int(b2["exposure"]) == 20, "non-Kolat death no change")

	# --- conviction secrecy ---
	# Convicted conscious member (Coin): exposure +10
	var rec := CrimeRecord.new()
	rec.case_id = 10
	rec.perpetrator_id = 1
	rec.legal_status = Enums.LegalStatus.DECREED_GUILTY
	var b3: Dictionary = _KS.new_bundle()
	_DO._process_kolat_conviction_secrecy(
		[{"outcome": "convicted", "case_id": 10, "crime_type": Enums.CrimeType.DISHONORABLE_CONDUCT}],
		[rec], chars_by_id, b3)
	_ok(int(b3["exposure"]) == 10, "member conviction +10 exposure")

	# Convicted Master (Silk): exposure +10, awareness +20, identified
	var rec2 := CrimeRecord.new()
	rec2.case_id = 11
	rec2.perpetrator_id = 2
	var b4: Dictionary = _KS.new_bundle()
	_DO._process_kolat_conviction_secrecy(
		[{"outcome": "convicted", "case_id": 11, "crime_type": Enums.CrimeType.DISHONORABLE_CONDUCT}],
		[rec2], chars_by_id, b4)
	_ok(int(b4["exposure"]) == 10 and int(b4["awareness"]) == 20, "master conviction +10/+20")
	_ok(_KS.is_identified(b4, 2), "master identified on conviction")

	# Traced Kolat assassination: exposure +15, awareness +5
	var rec3 := CrimeRecord.new()
	rec3.case_id = 12
	rec3.perpetrator_id = 3  # the assassin (non-Kolat), commissioner is Kolat
	rec3.commissioner_id = 1
	var b5: Dictionary = _KS.new_bundle()
	_DO._process_kolat_conviction_secrecy(
		[{"outcome": "convicted", "case_id": 12, "crime_type": Enums.CrimeType.UNSANCTIONED_COVERT_KILLING}],
		[rec3], chars_by_id, b5)
	_ok(int(b5["exposure"]) == 15 and int(b5["awareness"]) == 5, "traced assassination +15/+5")

	# --- investigation awareness (+5 once per case) ---
	var rec4 := CrimeRecord.new()
	rec4.case_id = 20
	rec4.perpetrator_id = 1  # Kolat member named
	rec4.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	var b6: Dictionary = _KS.new_bundle()
	_DO._process_kolat_investigation_awareness([rec4], chars_by_id, b6)
	_ok(int(b6["awareness"]) == 5, "investigation awareness +5")
	_DO._process_kolat_investigation_awareness([rec4], chars_by_id, b6)
	_ok(int(b6["awareness"]) == 5, "investigation awareness dedup")


func _test_pipeline_and_win() -> void:
	print("[3] candidate pipeline + win condition")
	var chars: Array = []
	var chars_by_id: Dictionary = {}
	var objectives_map: Dictionary = {}
	var world_states: Dictionary = {}
	var cpm: Dictionary = {}

	var tiger: L5RCharacterData = _mk(100, "Tiger")
	tiger.kolat_sect = Enums.KolatSect.TIGER
	tiger.is_kolat_master = true
	var emperor: L5RCharacterData = _mk(101, "Emperor", 10.0)
	emperor.physical_location = "500"
	world_states["emperor_id"] = 101
	# A Kolat courtier at the capital, high court skill — the candidate vehicle.
	var cand: L5RCharacterData = _mk(102, "Doji Courtier", 5.0)
	cand.kolat_sect = Enums.KolatSect.CHRYSANTHEMUM
	cand.physical_location = "500"
	cand.skills = {"Courtier": 6, "Etiquette": 5}
	# A weaker unaffiliated courtier (should NOT be picked — not eligible).
	var rival: L5RCharacterData = _mk(103, "Plain Courtier", 6.0)
	rival.physical_location = "500"
	for c: L5RCharacterData in [tiger, emperor, cand, rival]:
		chars.append(c)
		chars_by_id[c.character_id] = c

	var b: Dictionary = _KS.new_bundle()
	# Pass 1: selects the eligible Kolat courtier, stage → cultivating, installs objective.
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 100, b)
	_ok(int(b["candidate_id"]) == 102, "selects eligible Kolat courtier (not the plain rival)")
	_ok(String(b["pipeline_stage"]) == "cultivating", "stage cultivating")
	_ok(objectives_map.get(102, {}).has("kolat"), "cultivation objective installed")
	_ok(objectives_map[102]["kolat"].get("need_type", "") == "RAISE_DISPOSITION", "cultivation raises disposition (at capital)")
	_ok(int(tiger.special_data.get("kolat_primary_candidate_npc_id", -1)) == 102, "mirrored to Tiger")

	# Candidate reaches a senior court role → positioned.
	cand.role_position = RoleRegistry.SENIOR_COURTIER
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 130, b)
	_ok(String(b["pipeline_stage"]) == "positioned", "stage positioned at senior court role")

	# Candidate wins an Imperial-proximity seat → installed, records the day.
	cand.role_position = RoleRegistry.IMPERIAL_ADVISOR
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 160, b)
	_ok(String(b["pipeline_stage"]) == "installed", "stage installed")
	_ok(int(b["installed_ic_day"]) == 160, "installed day recorded")

	# Before one IC year: no win.
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 200, b)
	_ok(int(b["victory_ic_day"]) < 0, "no win before one IC year")

	# After one full IC year, awareness < 70 → win fires once.
	var win_day: int = 160 + TimeSystem.IC_DAYS_PER_YEAR + 1
	var res: Dictionary = _DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, win_day, b)
	_ok(res.has("kolat_victory"), "win fires after one IC year")
	_ok(int(b["victory_ic_day"]) == win_day, "victory day recorded")
	# Does not re-fire.
	var res2: Dictionary = _DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, win_day + 10, b)
	_ok(not res2.has("kolat_victory"), "win does not re-fire")

	# High awareness blocks the win.
	var b2: Dictionary = _KS.new_bundle()
	b2["candidate_id"] = 102
	b2["pipeline_stage"] = "installed"
	b2["installed_ic_day"] = 160
	b2["awareness"] = 75
	var res3: Dictionary = _DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, win_day, b2)
	_ok(not res3.has("kolat_victory"), "awareness>=70 blocks win")


func _test_response_and_purge() -> void:
	print("[4] Imperial response tiers + purge")
	var chars: Array = []
	var chars_by_id: Dictionary = {}
	var objectives_map: Dictionary = {}
	var world_states: Dictionary = {}
	var cpm: Dictionary = {}

	var tiger: L5RCharacterData = _mk(200, "Tiger2")
	tiger.kolat_sect = Enums.KolatSect.TIGER
	tiger.is_kolat_master = true
	var emperor: L5RCharacterData = _mk(201, "Emperor2", 10.0)
	world_states["emperor_id"] = 201
	# An identified Kolat master to be purged.
	var master: L5RCharacterData = _mk(202, "Doomed Master")
	master.kolat_sect = Enums.KolatSect.LOTUS
	master.is_kolat_master = true
	master.kolat_koku = 500
	master.dirty_koku = 40
	objectives_map[202] = {"kolat": {"need_type": "SPONSOR_INSURGENCY", "source": "kolat_opportunity"}}
	for c: L5RCharacterData in [tiger, emperor, master]:
		chars.append(c)
		chars_by_id[c.character_id] = c
	cpm[202] = 7  # identified member's province

	# Tier 50: Tiger gains the "degrade Imperial task force" priority.
	var b: Dictionary = _KS.new_bundle()
	b["awareness"] = 55
	_KS.identify(b, 202)
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 300, b)
	_ok(world_states.get("imperial_response_active", false), "response active flag set")
	var prio: Array = tiger.special_data.get("kolat_strategic_priorities", [])
	var has_tf: bool = false
	for p: Dictionary in prio:
		if String(p.get("target_description", "")) == "degrade Imperial task force":
			has_tf = true
	_ok(has_tf, "tier50 task-force priority added")
	_ok((world_states.get("kolat_active_provinces", []) as Array).has(7), "kolat-active province surfaced")

	# Tier 90: identified members go dark (kolat slot cleared).
	b["awareness"] = 92
	_DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 330, b)
	_ok(bool(b["go_dark"]), "go_dark set at tier 90")
	_ok(not objectives_map.get(202, {}).has("kolat"), "identified member kolat slot cleared")

	# Tier 100: one-shot purge breaks identified members.
	b["awareness"] = 100
	var res: Dictionary = _DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 360, b)
	_ok(res.has("kolat_purge"), "purge event fired")
	_ok(master.kolat_sect == Enums.KolatSect.NONE and not master.is_kolat_master, "master broken")
	_ok(master.kolat_koku == 0 and master.dirty_koku == 0, "master funds seized")
	_ok(bool(b["purge_done"]), "purge_done set")
	# Does not re-fire.
	var res2: Dictionary = _DO._process_kolat_endgame(chars, chars_by_id, objectives_map, world_states, cpm, 390, b)
	_ok(not res2.has("kolat_purge"), "purge does not re-fire")
