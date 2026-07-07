extends SceneTree
## Runtime driver for fixing the dormant _process_siege_war_scores consumer (s53, LOCKED).
## It read military_daily["siege_results"] for `resolved == "attacker_victory"` and `attacker_clan`
## -- keys NOTHING in the codebase ever produces -- so it NEVER fired and the SCORE_SHIFTS
## siege_won_attacker [12,8] / siege_won_defender [8,5] were dead. Now consumes the real
## storm_assault_results (victor attacker/defender + army ids), resolving clans via _get_army_clan
## and the war via ally-aware get_war_between, applying the shift to the winning side's principal clan.
## Run: godot --headless -s tests/verify_siege_war_score.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _war(a: String, b: String) -> WarData:
	var w := WarData.new()
	w.war_id = 1
	w.clan_a = a
	w.clan_b = b
	w.is_active = true
	w.war_score_a = 50
	w.war_score_b = 50
	return w


func _co(army_id: int, clan: String) -> Dictionary:
	return {"army_id": army_id, "clan_name": clan}


func _storm(victor: String, atk_army: int, def_army: int) -> Dictionary:
	return {
		"siege_settlement_id": 500, "victor": victor,
		"attacker_army_id": atk_army, "defender_army_id": def_army,
	}


func _init() -> void:
	print("--- Siege storm-assault -> War Score shift (s53) ---")
	_test_attacker_win()
	_test_defender_win()
	_test_ally_victor()
	_test_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_attacker_win() -> void:
	print("[1] attacker storms the wall -> siege_won_attacker (+12 / -8)")
	var war := _war("Lion", "Crane")            # Lion = a, Crane = b
	var companies: Array = [_co(100, "Lion"), _co(200, "Crane")]
	var results: Array = []
	_DO._process_siege_war_scores([_storm("attacker", 100, 200)], [war], companies, results)
	_ok(war.war_score_a == 62, "Lion (attacker, side a) +12 -> 62 (got %d)" % war.war_score_a)
	_ok(war.war_score_b == 42, "Crane (defender, side b) -8 -> 42 (got %d)" % war.war_score_b)
	_ok(results.size() == 1 and results[0].get("event", "") == "siege_won_attacker", "result event recorded")


func _test_defender_win() -> void:
	print("[2] defender repels the assault -> siege_won_defender (+8 / -5)")
	var war := _war("Lion", "Crane")
	var companies: Array = [_co(100, "Lion"), _co(200, "Crane")]
	var results: Array = []
	_DO._process_siege_war_scores([_storm("defender", 100, 200)], [war], companies, results)
	_ok(war.war_score_b == 58, "Crane (defender, side b) +8 -> 58 (got %d)" % war.war_score_b)
	_ok(war.war_score_a == 45, "Lion (attacker, side a) -5 -> 45 (got %d)" % war.war_score_a)


func _test_ally_victor() -> void:
	print("[3] an ALLIED attacker's win lands on that side's principal clan")
	var war := _war("Crab", "Scorpion")         # Crab = a, Scorpion = b
	war.allied_clans_a = ["Crane"]              # Crane fights on Crab's side
	var companies: Array = [_co(100, "Crane"), _co(200, "Scorpion")]
	var results: Array = []
	_DO._process_siege_war_scores([_storm("attacker", 100, 200)], [war], companies, results)
	_ok(war.war_score_a == 62, "principal Crab (side a) gains +12 for its ally's siege win (got %d)" % war.war_score_a)
	_ok(war.war_score_b == 42, "Scorpion (side b) -8 (got %d)" % war.war_score_b)


func _test_guards() -> void:
	print("[4] guards: no war / same clan / unknown army -> no shift")
	# No war between the besieging clans.
	var war := _war("Dragon", "Phoenix")
	var companies: Array = [_co(100, "Lion"), _co(200, "Crane")]
	var results: Array = []
	_DO._process_siege_war_scores([_storm("attacker", 100, 200)], [war], companies, results)
	_ok(war.war_score_a == 50 and war.war_score_b == 50 and results.is_empty(),
		"Lion-vs-Crane siege does not touch the Dragon-Phoenix war")

	# Same clan on both sides (civil siege with no cross-clan war) -> nothing.
	var war2 := _war("Lion", "Crane")
	_DO._process_siege_war_scores([_storm("attacker", 100, 100)], [war2], [_co(100, "Lion")], [])
	_ok(war2.war_score_a == 50, "same-clan attacker/defender -> no shift")

	# Unknown army id -> empty clan -> nothing.
	var war3 := _war("Lion", "Crane")
	var results3: Array = []
	_DO._process_siege_war_scores([_storm("attacker", 999, 200)], [war3], [_co(200, "Crane")], results3)
	_ok(war3.war_score_a == 50 and results3.is_empty(), "unknown attacker army -> no shift")

	# Neither victor -> nothing.
	var war4 := _war("Lion", "Crane")
	_DO._process_siege_war_scores([_storm("ongoing", 100, 200)], [war4],
		[_co(100, "Lion"), _co(200, "Crane")], [])
	_ok(war4.war_score_a == 50, "non-victory storm result -> no shift")
