extends SceneTree
## Runtime driver for s57.27:115 familiarity decay (owner-approved activation 2026-07-08).
## A permanently-displayed work loses visitor impact after 1 IC year of continuous display:
## the visitor disposition bonus reduces 15%/IC year beyond the first, floor 50%; fusuma &
## religious statuary decay at HALF rate (7.5%/yr, floor 75%). PaintingSystem.familiarity_factor
## was dormant (FAMILIARITY_DECAY_RATE deliberately zeroed); now activated with the GDD-stated
## rates and consumed at the painting + garden visitor sites (the clocks
## continuous_display_start_ic_day / installation_date were tracked but never read).
## Run: godot --headless -s tests/verify_familiarity_decay.gd

const _PS := preload("res://simulation/painting_system.gd")

const YEAR: int = 360

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _init() -> void:
	print("--- s57.27:115 familiarity decay activated (painting + garden) ---")
	_test_constants()
	_test_standard_gdd_examples()
	_test_half_rate()
	_test_guards_and_floor()
	_test_scaled_bonus_math()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_constants() -> void:
	print("[1] the GDD-stated rates are activated (no longer zeroed)")
	_ok(_approx(_PS.FAMILIARITY_DECAY_RATE, 0.15), "standard rate 15%")
	_ok(_approx(_PS.FAMILIARITY_DECAY_FLOOR, 0.50), "standard floor 50%")
	_ok(_approx(_PS.FAMILIARITY_DECAY_RATE_HALF, 0.075), "half rate 7.5% (fusuma/statuary)")
	_ok(_approx(_PS.FAMILIARITY_DECAY_FLOOR_HALF, 0.75), "half floor 75%")


func _test_standard_gdd_examples() -> void:
	print("[2] the GDD's own worked examples (Fine kakemono +2)")
	# start at ic_day 0; sample at N years.
	_ok(_approx(_PS.familiarity_factor(1 * YEAR, 0, false), 1.0), "1 IC year -> full (1.0)")
	_ok(_approx(_PS.familiarity_factor(2 * YEAR, 0, false), 0.85), "2 IC years -> 85%")
	_ok(_approx(_PS.familiarity_factor(3 * YEAR, 0, false), 0.70), "3 IC years -> 70%")
	_ok(_approx(_PS.familiarity_factor(4 * YEAR, 0, false), 0.55), "4 IC years -> 55%")
	_ok(_approx(_PS.familiarity_factor(5 * YEAR, 0, false), 0.50), "5 IC years -> 50% floor")
	_ok(_approx(_PS.familiarity_factor(9 * YEAR, 0, false), 0.50), "9 IC years -> still 50% floor")


func _test_half_rate() -> void:
	print("[3] fusuma / religious statuary half-rate (7.5%/yr, floor 75%)")
	_ok(_approx(_PS.familiarity_factor(1 * YEAR, 0, true), 1.0), "half: 1 IC year -> full")
	_ok(_approx(_PS.familiarity_factor(2 * YEAR, 0, true), 0.925), "half: 2 IC years -> 92.5%")
	_ok(_approx(_PS.familiarity_factor(3 * YEAR, 0, true), 0.85), "half: 3 IC years -> 85%")
	_ok(_approx(_PS.familiarity_factor(4 * YEAR, 0, true), 0.775), "half: 4 IC years -> 77.5%")
	_ok(_approx(_PS.familiarity_factor(5 * YEAR, 0, true), 0.75), "half: 5 IC years -> 75% floor reached")
	_ok(_approx(_PS.familiarity_factor(20 * YEAR, 0, true), 0.75), "half: many years -> 75% floor")


func _test_guards_and_floor() -> void:
	print("[4] guards: unset clock, sub-year, floor never breached")
	_ok(_approx(_PS.familiarity_factor(5 * YEAR, -1, false), 1.0), "unset clock (-1) -> no decay (1.0)")
	_ok(_approx(_PS.familiarity_factor(180, 0, false), 1.0), "half a year -> no decay (1.0)")
	_ok(_PS.familiarity_factor(2 * YEAR, 0, false) < 1.0, "past 1 year -> begins decaying (< 1.0)")
	# floor is never breached no matter how long
	var f: float = _PS.familiarity_factor(1000 * YEAR, 0, false)
	_ok(f >= 0.50 and _approx(f, 0.50), "standard floor holds at 50% for extreme age")


func _test_scaled_bonus_math() -> void:
	print("[5] the orchestrator scaling (base_bonus * factor, rounded) matches the GDD table")
	# A Fine kakemono confers +2; at 3 IC years the applied disposition is round(2 * 0.70) = 1 (1.4 -> 1).
	_ok(int(round(2.0 * _PS.familiarity_factor(3 * YEAR, 0, false))) == 1, "+2 at 3yr -> applied +1 (1.4 rounds to 1)")
	# A Masterwork (+4) at 3 IC years: round(4 * 0.70) = 3 (2.8 -> 3).
	_ok(int(round(4.0 * _PS.familiarity_factor(3 * YEAR, 0, false))) == 3, "+4 at 3yr -> applied +3")
	# A Masterwork (+4) at floor: round(4 * 0.50) = 2.
	_ok(int(round(4.0 * _PS.familiarity_factor(9 * YEAR, 0, false))) == 2, "+4 at floor -> applied +2")
	# Fresh (< 1 yr) painting: unchanged.
	_ok(int(round(4.0 * _PS.familiarity_factor(200, 0, false))) == 4, "+4 fresh -> applied +4 (no decay)")
