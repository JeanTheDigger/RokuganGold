extends SceneTree
## Headless runtime driver for the s2.4 Wall Jade Petal Tea passes (D6).
## Verifies: Shireikan Tea resupply (reserve → tower, priority by Tainted count),
## seasonal dosing with highest-Rank-first rationing, the managed-until window,
## and the periodic-taint-roll suppression while managed.
## Run: godot --headless -s tests/verify_wall_tea.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _tower(id: int, num: int, prov: int, tea: float, garrison: int = 3) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_tower_number = num
	s.province_id = prov
	s.tea_stockpile = tea
	s.garrison_pu = garrison
	s.wall_si = 10
	return s


func _char(id: int, loc: int, taint: float, rank: Enums.MilitaryRank = Enums.MilitaryRank.NONE) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = str(loc)
	c.taint = taint
	c.military_rank = rank
	# Rank-1 taint (1.0) chars roll on a 30-day period; give middling Earth.
	c.stamina = 2
	c.willpower = 2
	return c


func _shireikan(id: int, seat_settlement_id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.military_rank = Enums.MilitaryRank.SHIREIKAN
	c.physical_location = str(seat_settlement_id)
	return c


func _init() -> void:
	print("--- Wall Jade Petal Tea Verification (s2.4 D6) ---")
	_test_season_window()
	_test_consumption_ration()
	_test_resupply()
	_test_suppression()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_season_window() -> void:
	print("[1] managed-until = next season boundary")
	# Boundaries within a year: 0, 90, 180, 240, 360.
	_ok(_DO._days_until_next_season(0) == 90, "day 0 → next boundary 90")
	_ok(_DO._days_until_next_season(90) == 90, "day 90 → next boundary 180")
	_ok(_DO._days_until_next_season(180) == 60, "day 180 → next boundary 240 (autumn 60)")
	_ok(_DO._days_until_next_season(240) == 120, "day 240 → next year 0 (winter 120)")
	_ok(_DO._days_until_next_season(365) == 85, "day 365 (doy 5) → boundary 90 = 85")


func _test_consumption_ration() -> void:
	print("[2] dosing rations highest Taint first")
	var tower := _tower(100, 1, 200, 2.0)  # only 2 doses
	# Three Tainted stationed chars at ranks 3 (taint 3.0), 2, 1.
	var c_hi := _char(10, 100, 3.5)
	var c_mid := _char(11, 100, 2.5)
	var c_lo := _char(12, 100, 1.5)
	var res: Array = _DO._process_wall_tea_consumption([c_hi, c_mid, c_lo], [tower], 0)
	# 2 doses → the two highest-Taint get dosed, lowest goes without.
	_ok(tower.tea_stockpile == 0.0, "stockpile drained to 0")
	_ok(c_hi.tea_managed_until_ic_day == 90 and c_mid.tea_managed_until_ic_day == 90, "top two dosed (managed to 90)")
	_ok(c_lo.tea_managed_until_ic_day == -1, "lowest-Taint goes without (unmanaged)")
	_ok(res.size() == 1 and int(res[0]["dosed"]) == 2 and bool(res[0]["tea_shortage"]), "one shortage report, dosed 2")
	_ok((res[0]["went_without"] as Array) == [12], "went_without lists the lowest char")


func _test_resupply() -> void:
	print("[3] Shireikan Tea resupply by Tainted concentration")
	# Two towers in Southern half; tower 2 has more Tainted chars → higher priority.
	var t1 := _tower(301, 1, 401, 0.0)
	var t2 := _tower(302, 2, 402, 0.0)
	var sh := _shireikan(500, 305)  # seat not a tower id here; seat<=6 → Southern half
	# t1: 1 Tainted; t2: 3 Tainted.
	var chars: Array = [
		sh,
		_char(20, 301, 1.5),
		_char(21, 302, 1.5), _char(22, 302, 2.5), _char(23, 302, 3.5),
	]
	var res: Array = _DO._process_wall_tea_resupply(chars, [t1, t2])
	# Targets: t1 → 1, t2 → 3. Reserve 12 covers both. t2 (higher count) served first.
	_ok(t1.tea_stockpile == 1.0, "t1 refilled to its 1-Tainted target")
	_ok(t2.tea_stockpile == 3.0, "t2 refilled to its 3-Tainted target")
	_ok(res.size() == 2 and int(res[0]["tower"]) == 2, "higher-Tainted tower served first")
	_ok(abs(float(sh.supply_ledger.get("wall_tea_reserve", -1.0)) - 8.0) < 0.001, "reserve 12 - 4 delivered = 8")
	# A tower with no Tainted chars is skipped entirely.
	var t3 := _tower(303, 3, 403, 0.0)
	var res2: Array = _DO._process_wall_tea_resupply([sh, _char(24, 303, 0.0)], [t3])
	_ok(res2.is_empty() and t3.tea_stockpile == 0.0, "no Tainted → no Tea delivered")


func _test_suppression() -> void:
	print("[4] managed char skips periodic taint growth roll")
	var dice := DiceEngine.new()
	dice.set_seed(1)
	# A Rank-1 char with weak Earth (fails often). Managed → no roll fires on its
	# 30-day period day; unmanaged → the roll can fire and grow taint.
	var managed := _char(30, 100, 1.0)
	managed.stamina = 1
	managed.willpower = 1
	managed.tea_managed_until_ic_day = 90  # managed through day 90
	var before: float = managed.taint
	# Day 30 is a roll-period day for Rank 1 (period 30). Managed → skipped.
	var r_managed: Array = _DO._process_periodic_taint_rolls([managed], dice, 30)
	_ok(r_managed.is_empty() and managed.taint == before, "managed char skips its taint roll")
	# Unmanaged control at the same rank/day → its roll fires (result recorded).
	var unmanaged := _char(31, 100, 1.0)
	unmanaged.stamina = 1
	unmanaged.willpower = 1
	unmanaged.tea_managed_until_ic_day = -1
	var r_un: Array = _DO._process_periodic_taint_rolls([unmanaged], dice, 30)
	_ok(r_un.size() == 1 and bool(r_un[0]["taint_roll"]), "unmanaged char makes its taint roll")
	# Expired management (window in the past) → roll fires again.
	managed.tea_managed_until_ic_day = 60
	var r_expired: Array = _DO._process_periodic_taint_rolls([managed], dice, 90)
	_ok(r_expired.size() == 1, "expired management → roll fires (day 90 > until 60)")
