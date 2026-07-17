extends SceneTree
## Runtime driver for s11.5b §5 Cunning-emperor blessing politics — a dormant + design-gated
## arbiter now owner-authorized. MiyaBlessingSystem.apply_cunning_modifier (+10 Need Score to a
## favored clan's provinces, -10 to a disfavored clan's) was BUILT (LOCKED ±10) but had ZERO
## production callers, AND the scored-province entry never carried a `clan` field, so even a manual
## call would have matched nothing. Owner-approved rule (2026-07-09): favored = the clan whose
## champion holds the HIGHEST disposition toward the Emperor, disfavored = the LOWEST (the
## established Emperor<->clan convention via the "highest-status, lord_id==-1 per clan" champion
## proxy). FIX: resource_tick now stamps `clan` on the scored entry; DayOrchestrator computes the
## favored/disfavored clans on the Spring boundary when the archetype is CUNNING and feeds them
## through spring_inputs -> _apply_miya_blessing -> process_annual_blessing, which applies the
## arbiter before selection. No-op for every other archetype and when no clan stands out.
## Run: godot --headless -s tests/verify_miya_cunning.gd

const _MB := preload("res://simulation/miya_blessing_system.gd")
const _SR := preload("res://simulation/strategic_review.gd")
const _CH := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- s11.5b §5 Cunning-emperor blessing politics ---")
	_test_arbiter()
	_test_favored_disfavored_helper()
	_test_end_to_end_selection()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


# -- 1. the LOCKED ±10 arbiter, now matched by the clan field --------------------
func _test_arbiter() -> void:
	print("[1] apply_cunning_modifier: +10 favored clan, -10 disfavored, others unchanged")
	var scored: Array = [
		{"clan": "Crab", "score": 8},
		{"clan": "Lion", "score": 25},
		{"clan": "Crane", "score": 15},
	]
	_MB.apply_cunning_modifier(scored, "Crab", "Lion")
	_ok(int(scored[0]["score"]) == 18, "Crab (favored) 8 -> 18 (+10)")
	_ok(int(scored[1]["score"]) == 15, "Lion (disfavored) 25 -> 15 (-10)")
	_ok(int(scored[2]["score"]) == 15, "Crane (neutral) 15 unchanged")
	# blank names -> no match -> unchanged (the no-standing-difference no-op path)
	var scored2: Array = [{"clan": "Crab", "score": 8}, {"clan": "Lion", "score": 25}]
	_MB.apply_cunning_modifier(scored2, "", "")
	_ok(int(scored2[0]["score"]) == 8 and int(scored2[1]["score"]) == 25, "blank clans -> no change")


# -- 2. the owner-approved favored/disfavored selection --------------------------
func _champ(cid: int, clan: String, status: float, disp_to_emperor: int, emperor_id: int,
		lord_id: int = -1) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.clan = clan
	c.status = status
	c.lord_id = lord_id
	c.disposition_values[emperor_id] = disp_to_emperor
	return c


func _test_favored_disfavored_helper() -> void:
	print("[2] _compute_cunning_blessing_clans: highest champ-disp -> favored, lowest -> disfavored")
	var emp_id := 900
	var emperor: L5RCharacterData = _CH.new()
	emperor.character_id = emp_id
	emperor.clan = "Imperial"
	# Three clan champions (lord_id -1), plus a non-champion Crab with a wild disp (must be ignored),
	# plus the emperor (must be excluded despite lord_id -1).
	var crab := _champ(1, "Crab", 7.0, 50, emp_id)
	var lion := _champ(2, "Lion", 7.0, -30, emp_id)
	var crane := _champ(3, "Crane", 7.0, 10, emp_id)
	var crab_vassal := _champ(4, "Crab", 3.0, -99, emp_id)  # lower status -> not the champion
	var chars := {1: crab, 2: lion, 3: crane, 4: crab_vassal, emp_id: emperor}
	var res: Dictionary = DayOrchestrator._compute_cunning_blessing_clans(chars, emp_id)
	_ok(res["favored"] == "Crab", "favored = Crab (champ disp +50, ignores the -99 vassal)")
	_ok(res["disfavored"] == "Lion", "disfavored = Lion (champ disp -30)")

	# < 2 clans -> no favoritism
	var one := {1: _champ(1, "Crab", 7.0, 50, emp_id), emp_id: emperor}
	var res1: Dictionary = DayOrchestrator._compute_cunning_blessing_clans(one, emp_id)
	_ok(res1["favored"] == "" and res1["disfavored"] == "", "single clan -> no favoritism")

	# all equal disposition -> no favoritism (no real standing difference)
	var eq := {
		1: _champ(1, "Crab", 7.0, 5, emp_id),
		2: _champ(2, "Lion", 7.0, 5, emp_id),
		emp_id: emperor,
	}
	var reseq: Dictionary = DayOrchestrator._compute_cunning_blessing_clans(eq, emp_id)
	_ok(reseq["favored"] == "" and reseq["disfavored"] == "", "all-equal standing -> no favoritism")

	# no emperor -> no favoritism
	var resno: Dictionary = DayOrchestrator._compute_cunning_blessing_clans(chars, -1)
	_ok(resno["favored"] == "" and resno["disfavored"] == "", "no emperor -> no favoritism")


# -- 3. end-to-end: the ±10 flips which provinces the Blessing selects ------------
func _scored(pid: int, clan: String, score: int, stability: float) -> Dictionary:
	return {"province_id": pid, "clan": clan, "score": score, "stability": stability,
		"population_pu": 100.0, "excluded": false}


func _blessing_inputs(archetype: int, favored: String, disfavored: String) -> Dictionary:
	# 2 Crab provinces (low raw score) + 3 Lion (high raw score). Firing inputs: income 200 * 0.10
	# rate -> raw 20 capped MAX_TOTAL 15; stockpile 100, ou_pu 0 -> available 100 -> allocation 15
	# (>= 0.5, fires) -> selects the top-3 by score.
	return {
		"emperor_archetype": archetype,
		"emperor_autumn_tax_income": 200.0,
		"emperor_stockpile": 100.0,
		"otosan_uchi_pu": 0.0,
		"province_settlements": {},
		"cunning_favored_clan": favored,
		"cunning_disfavored_clan": disfavored,
		"scored_provinces": [
			_scored(1, "Crab", 8, 40.0),
			_scored(2, "Crab", 9, 41.0),
			_scored(3, "Lion", 25, 50.0),
			_scored(4, "Lion", 24, 51.0),
			_scored(5, "Lion", 23, 52.0),
		],
	}


func _clan_of(pid: int) -> String:
	return "Crab" if pid <= 2 else "Lion"


func _count_clan(ids: Array, clan: String) -> int:
	var n := 0
	for pid_v in ids:
		if _clan_of(int(pid_v)) == clan:
			n += 1
	return n


func _test_end_to_end_selection() -> void:
	print("[3] end-to-end: Cunning ±10 flips selection; other archetypes ignore the cunning keys")
	# (a) IRON archetype ignores the cunning keys -> raw top-3 are the 3 Lion provinces.
	var iron: Dictionary = _MB.process_annual_blessing(
		_blessing_inputs(_SR.EmperorArchetype.IRON, "Crab", "Lion"))
	_ok(bool(iron.get("fired", false)), "IRON blessing fires")
	var iron_ids: Array = iron.get("selected_province_ids", [])
	_ok(_count_clan(iron_ids, "Lion") == 3 and _count_clan(iron_ids, "Crab") == 0,
		"IRON (cunning keys ignored) -> all 3 Lion selected, 0 Crab")

	# (b) CUNNING favored=Crab / disfavored=Lion -> +10/-10 flips: Crab 8/9 -> 18/19, Lion
	#     25/24/23 -> 15/14/13. top-3 = Crab 19, Crab 18, Lion 15 -> 2 Crab + 1 Lion.
	var cun: Dictionary = _MB.process_annual_blessing(
		_blessing_inputs(_SR.EmperorArchetype.CUNNING, "Crab", "Lion"))
	_ok(bool(cun.get("fired", false)), "CUNNING blessing fires")
	var cun_ids: Array = cun.get("selected_province_ids", [])
	_ok(_count_clan(cun_ids, "Crab") == 2 and _count_clan(cun_ids, "Lion") == 1,
		"CUNNING favored=Crab/disfavored=Lion -> 2 Crab + 1 Lion selected (the ±10 flip)")

	# (c) CUNNING with BLANK clans (the no-standing-difference no-op) -> same as IRON (all Lion).
	var cun_blank: Dictionary = _MB.process_annual_blessing(
		_blessing_inputs(_SR.EmperorArchetype.CUNNING, "", ""))
	var blank_ids: Array = cun_blank.get("selected_province_ids", [])
	_ok(_count_clan(blank_ids, "Lion") == 3,
		"CUNNING with blank clans -> no modifier -> all 3 Lion (no-op)")
