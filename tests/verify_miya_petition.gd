extends SceneTree
## Runtime driver for the s11.5b §4.3 Miya's Blessing Winter-Court petition activation (owner-approved
## 2026-07-08). compute_need_score already CONSUMED a `petition_bonus` input and compute_petition_bonus
## computed the +8/+2-per-raise value, but NOTHING ran the petitions -- the input was always {}, so the
## whole Winter-Court-influence layer was dead. Fix: _process_miya_blessing_petitions resolves the
## petitions (Miya rep present, each clan's best Status-3.0+ courtier rolls Courtier(Manipulation)/
## Awareness vs TN 25 for its neediest home province, +8/+2 per raise) and feeds the per-province
## bonuses into the Spring blessing.
## Run: godot --headless -s tests/verify_miya_petition.gd

const _MB := preload("res://simulation/miya_blessing_system.gd")
const _CH := preload("res://shared/character_data.gd")
const _PD := preload("res://shared/province_data.gd")
const _CS := preload("res://shared/court_session_data.gd")
const _DE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _courtier(cid: int, clan: String, family: String, status: float, courtier_rank: int, awr: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.clan = clan
	c.family = family
	c.status = status
	c.awareness = awr
	c.skills = {"Courtier": courtier_rank}
	return c


func _prov(pid: int, clan: String, stability: float) -> ProvinceData:
	var p: ProvinceData = _PD.new()
	p.province_id = pid
	p.clan = clan
	p.stability = stability
	return p


func _winter_court(attendees: Array, active: bool) -> CourtSessionData:
	var c: CourtSessionData = _CS.new()
	c.court_type = _CS.CourtType.IMPERIAL_WINTER_COURT
	c.phase = _CS.CourtPhase.ACTIVE if active else _CS.CourtPhase.SCHEDULED
	c.attendee_ids = attendees
	return c


func _init() -> void:
	print("--- s11.5b §4.3 Miya's Blessing Winter-Court petition activated ---")
	_test_constants_and_arbiter()
	_test_need_score_consumes_petition()
	_test_neediest_province_selection()
	_test_full_petition_flow()
	_test_gates()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_constants_and_arbiter() -> void:
	print("[1] GDD-locked constants + compute_petition_bonus (+8 base, +2/raise; 0 on failure)")
	_ok(_MB.PETITION_TN == 25, "TN 25")
	_ok(_approx(_MB.PETITION_MIN_STATUS, 3.0), "min Status 3.0")
	_ok(_MB.compute_petition_bonus(true, 0) == 8, "success no raises -> +8")
	_ok(_MB.compute_petition_bonus(true, 2) == 12, "success 2 raises -> +12")
	_ok(_MB.compute_petition_bonus(false, 5) == 0, "failure -> 0 (regardless of raises)")


func _test_need_score_consumes_petition() -> void:
	print("[2] compute_need_score adds petition_bonus (the consumer was live, the producer was not)")
	var base: int = _MB.compute_need_score({"stability": 100.0})
	var with_pet: int = _MB.compute_need_score({"stability": 100.0, "petition_bonus": 12})
	_ok(with_pet - base == 12, "a +12 petition raises the Need Score by exactly 12")


func _test_neediest_province_selection() -> void:
	print("[3] a clan lobbies for its LOWEST-stability home province (greatest need)")
	var provs := {
		1: _prov(1, "Crab", 20.0),   # neediest Crab
		2: _prov(2, "Crab", 80.0),
		3: _prov(3, "Crane", 30.0),
	}
	_ok(DayOrchestrator._miya_neediest_province_for_clan("Crab", provs) == 1, "Crab -> province 1 (stability 20)")
	_ok(DayOrchestrator._miya_neediest_province_for_clan("Crane", provs) == 3, "Crane -> province 3")
	_ok(DayOrchestrator._miya_neediest_province_for_clan("Lion", provs) == -1, "no Lion province -> -1")


func _test_full_petition_flow() -> void:
	print("[4] full flow: Miya present -> each clan petitions its neediest province")
	var dice: DiceEngine = _DE.new(4242)
	var miya := _courtier(99, "Crane", "Miya", 5.0, 5, 4)   # the required Miya representative
	var crab := _courtier(10, "Crab", "Hida", 6.0, 8, 6)    # strong petitioner -> near-certain success
	var provs := {
		1: _prov(1, "Crab", 15.0),   # neediest Crab
		2: _prov(2, "Crab", 90.0),
	}
	var court := _winter_court([99, 10], true)
	var chars := {99: miya, 10: crab}
	var res: Dictionary = DayOrchestrator._process_miya_blessing_petitions([court], chars, provs, dice)
	_ok(res.has(1), "the neediest Crab province (1) was petitioned")
	_ok(not res.has(2), "the healthy Crab province (2) was NOT petitioned (one per clan, neediest)")
	_ok(int(res.get(1, -1)) >= 8, "a strong petitioner succeeds -> bonus >= +8 (got %d)" % int(res.get(1, -1)))


func _test_gates() -> void:
	print("[5] gates: Miya-absent -> no petitions; Status<3.0 -> no petitions; inactive court -> none")
	var dice: DiceEngine = _DE.new(77)
	var crab := _courtier(10, "Crab", "Hida", 6.0, 8, 6)
	var provs := {1: _prov(1, "Crab", 15.0)}

	# No Miya representative present.
	var court_no_miya := _winter_court([10], true)
	var r1: Dictionary = DayOrchestrator._process_miya_blessing_petitions(
		[court_no_miya], {10: crab}, provs, dice)
	_ok(r1.is_empty(), "no Miya rep present -> no petitions")

	# Miya present but only a Status < 3.0 attendee.
	var miya := _courtier(99, "Crane", "Miya", 5.0, 5, 4)
	var low := _courtier(11, "Crab", "Hida", 2.0, 8, 6)  # Status 2.0 < 3.0
	var court_low := _winter_court([99, 11], true)
	var r2: Dictionary = DayOrchestrator._process_miya_blessing_petitions(
		[court_low], {99: miya, 11: low}, provs, dice)
	_ok(r2.is_empty(), "only a Status-2.0 attendee -> no eligible petitioner")

	# Court not active (scheduled).
	var court_inactive := _winter_court([99, 10], false)
	var r3: Dictionary = DayOrchestrator._process_miya_blessing_petitions(
		[court_inactive], {99: miya, 10: crab}, provs, dice)
	_ok(r3.is_empty(), "inactive (scheduled) Winter Court -> no petitions")


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
