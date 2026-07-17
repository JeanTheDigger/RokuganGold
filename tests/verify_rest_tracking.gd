extends SceneTree
## Runtime driver for the s57.31.7a / s57.32.2 `rested_last_night` producer fix. The flag gates BOTH
## natural healing (s57.31.7a) and Void Point refresh (s57.32.2) via _counts_as_rested, but NOTHING
## ever wrote it -- it sat at its @export default `true` forever, so every character was permanently
## rested and both systems always fired, ignoring the LOCKED disqualifiers. Fix: DayOrchestrator.
## _process_rest_tracking resets the flag true at each OOC-day boundary and flips it false for any
## character traveling (or arrived) that day -- the LOCKED "continuous travel" disqualifier.
## Run: godot --headless -s tests/verify_rest_tracking.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, dest: String, days_left: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.travel_destination = dest
	c.travel_days_remaining = days_left
	return c


func _init() -> void:
	print("--- s57.31.7a/s57.32.2 rested_last_night producer fix ---")
	_test_boundary_reset()
	_test_travel_flip()
	_test_arrival_flip()
	_test_persistence_and_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_boundary_reset() -> void:
	print("[1] OOC-day boundary (ic_day %% 4 == 0) resets a stationary character's flag to true")
	var c: L5RCharacterData = _mk(1, "", 0)  # not traveling
	c.rested_last_night = false               # left false by a prior window's travel
	_DO._process_rest_tracking([c], [], 4)    # ic_day 4 == boundary
	_ok(c.rested_last_night, "stationary character reset to true at the boundary")
	# A NON-boundary day does NOT reset a false flag (the disqualifier persists across the window).
	var d: L5RCharacterData = _mk(2, "", 0)
	d.rested_last_night = false
	_DO._process_rest_tracking([d], [], 5)    # ic_day 5, not a boundary
	_ok(not d.rested_last_night, "non-boundary day does not reset a false flag (window persistence)")


func _test_travel_flip() -> void:
	print("[2] a traveling character is flipped to false (continuous-travel disqualifier)")
	var c: L5RCharacterData = _mk(1, "Kyuden", 2)  # is_traveling true
	c.rested_last_night = true
	_DO._process_rest_tracking([c], [], 5)         # non-boundary
	_ok(not c.rested_last_night, "traveling character flipped false")
	# On a boundary day: reset true THEN flip false -> traveling on the boundary day counts toward
	# the NEW window (the day's travel disqualifies the coming window, not the one just read).
	var b: L5RCharacterData = _mk(2, "Kyuden", 3)
	b.rested_last_night = true
	_DO._process_rest_tracking([b], [], 8)         # boundary AND traveling
	_ok(not b.rested_last_night, "boundary + traveling: reset-true-then-flip-false = false")


func _test_arrival_flip() -> void:
	print("[3] a character who ARRIVED this day (spent it on the road) is flipped false")
	var c: L5RCharacterData = _mk(1, "", 0)  # no longer traveling (already arrived at line 186)
	c.rested_last_night = true
	var arrivals: Array = [{"character_id": 1, "arrived": true}]
	_DO._process_rest_tracking([c], arrivals, 5)
	_ok(not c.rested_last_night, "arrived-this-day character flipped false despite is_traveling==false")
	# A character NOT in the arrivals list and not traveling is untouched.
	var idle: L5RCharacterData = _mk(2, "", 0)
	idle.rested_last_night = true
	_DO._process_rest_tracking([idle], arrivals, 5)
	_ok(idle.rested_last_night, "an unrelated stationary character stays rested")


func _test_persistence_and_guards() -> void:
	print("[4] full-window persistence, dead-guard, and Power-of-the-Ocean override")
	# Window trace: travel on day 1 -> false; days 2,3 stationary keep it false; day 4 boundary reads
	# false (in real code -> no heal) then resets true.
	var c: L5RCharacterData = _mk(1, "Kyuden", 3)
	c.rested_last_night = true
	_DO._process_rest_tracking([c], [], 1)            # day 1: traveling -> false
	_ok(not c.rested_last_night, "day 1 travel -> false")
	c.travel_destination = ""; c.travel_days_remaining = 0  # arrived; now stationary
	_DO._process_rest_tracking([c], [], 2)            # day 2 stationary
	_DO._process_rest_tracking([c], [], 3)            # day 3 stationary
	_ok(not c.rested_last_night, "false persists across the window (days 2,3 do not reset)")
	_ok(not _DO._counts_as_rested(c, 3), "_counts_as_rested false while unrested (would deny heal/void)")
	_DO._process_rest_tracking([c], [], 4)            # day 4 boundary -> reset true
	_ok(c.rested_last_night, "boundary resets true for the next window")
	# Dead characters are never touched.
	var dead: L5RCharacterData = _mk(9, "Kyuden", 2)  # traveling
	dead.rested_last_night = true
	dead.wounds_taken = 999
	_DO._process_rest_tracking([dead], [], 5)
	_ok(dead.rested_last_night, "dead character untouched (guard) despite traveling")
	# Power of the Ocean (s36): an unrested (traveling) character still counts_as_rested via the spell.
	var poo: L5RCharacterData = _mk(3, "Kyuden", 2)
	poo.rested_last_night = false                     # flipped false by travel
	poo.power_of_ocean_until_ic_day = 100
	_ok(_DO._counts_as_rested(poo, 50), "Power of the Ocean overrides the travel flip (counts_as_rested)")
