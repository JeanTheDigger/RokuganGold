extends SceneTree
## Runtime driver for the s57.23a A9 garden-commission abandonment PARTIAL MITIGATION wire.
## An artisan who abandons a vassal garden commission after reaching >= 50% of the target
## quality threshold is punished at HALF the honor/disposition cost (Honor -0.25 / disposition -4)
## instead of the full (-0.5 / -8). Before this wire the live abandonment writeback in
## DayOrchestrator._process_garden_seasonal_maintenance applied the full penalty unconditionally,
## the CommissionRecordData.progress_at_abandonment @export field was written-never-read, and
## GardenSystem.PARTIAL_MITIGATION_THRESHOLD was defined-never-read. All values LOCKED (s57.23a A9);
## the mitigated penalty is exactly half the shipped ABANDONMENT_HONOR_LOSS / ABANDONMENT_DISPOSITION_LOSS.
## This driver exercises: (1) the mitigation constants; (2) end-to-end through the real seasonal pass —
## a >=50%-progress abandonment gets half penalty, a <50% one gets full; (3) the threshold boundary;
## (4) a per-tier threshold (tier 3 -> 70, 50% = 35) so the field is read against target_quality_tier.
## Run: godot --headless -s tests/verify_garden_abandonment_mitigation.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _GS := preload("res://simulation/garden_system.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _COMM := preload("res://shared/commission_record_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk_char(id: int, honor: float = 5.0) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.honor = honor
	c.wounds_taken = 0
	c.is_pc = false
	c.disposition_values = {}
	return c


func _mk_record(tier: int, progress: int) -> CommissionRecordData:
	# A vassal commission poised to abandon: neglect_timer already == completion_window,
	# so one more neglect tick (no AP this season) pushes it over the window.
	var r: CommissionRecordData = _COMM.new()
	r.commission_id = 1
	r.artisan_id = 10
	r.daimyo_id = 20
	r.status = "ACTIVE"
	r.target_quality_tier = tier
	r.cultivation_progress = progress
	r.completion_window = 1
	r.neglect_timer = 1
	r.window_start_date = 0  # begun work; far in the past so "worked_this_season" is false
	return r


func _run_abandonment(tier: int, progress: int) -> Dictionary:
	# Returns {honor_delta, disp_delta} after the real seasonal pass abandons the commission.
	var artisan: L5RCharacterData = _mk_char(10, 5.0)
	var daimyo: L5RCharacterData = _mk_char(20, 5.0)
	artisan.disposition_values = {20: 0}
	var record: CommissionRecordData = _mk_record(tier, progress)
	var by_id: Dictionary = {10: artisan, 20: daimyo}
	# ic_day far past window_start_date so worked_this_season is false -> neglect ticks -> abandon.
	_DO._process_garden_seasonal_maintenance([], [record], by_id, [], [], [0], 1000, 0)
	return {
		"status": record.status,
		"progress_at_abandonment": record.progress_at_abandonment,
		"honor_delta": artisan.honor - 5.0,
		"disp_delta": artisan.disposition_values.get(20, 0),
	}


func _init() -> void:
	print("--- s57.23a A9 garden-commission abandonment partial mitigation ---")
	_test_constants()
	_test_full_penalty_below_threshold()
	_test_half_penalty_at_and_above_threshold()
	_test_per_tier_threshold()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_constants() -> void:
	print("[1] mitigation constants (LOCKED s57.23a A9)")
	_ok(is_equal_approx(_GS.ABANDONMENT_HONOR_LOSS, 0.5), "full honor loss 0.5")
	_ok(_GS.ABANDONMENT_DISPOSITION_LOSS == 8, "full disposition loss 8")
	_ok(is_equal_approx(_GS.PARTIAL_MITIGATION_THRESHOLD, 0.5), "mitigation threshold 0.5")
	# Tier 1 threshold 20 -> 50% cutoff = 10.
	_ok(int(_GS.QUALITY_THRESHOLD.get(1, 0)) == 20, "tier1 threshold 20")


func _test_full_penalty_below_threshold() -> void:
	print("[2] progress < 50% -> FULL penalty")
	# Tier 1 (threshold 20, 50% = 10); progress 5 < 10 -> full -0.5 / -8.
	var r: Dictionary = _run_abandonment(1, 5)
	_ok(r["status"] == "ABANDONED", "commission abandoned")
	_ok(int(r["progress_at_abandonment"]) == 5, "progress_at_abandonment recorded (5)")
	_ok(is_equal_approx(r["honor_delta"], -0.5), "full honor loss -0.5 (was %.3f)" % r["honor_delta"])
	_ok(int(r["disp_delta"]) == -8, "full disposition loss -8 (was %d)" % int(r["disp_delta"]))


func _test_half_penalty_at_and_above_threshold() -> void:
	print("[3] progress >= 50% -> HALF penalty (the mitigation wire)")
	# Tier 1 (50% = 10); progress exactly 10 -> mitigated -0.25 / -4.
	var at: Dictionary = _run_abandonment(1, 10)
	_ok(at["status"] == "ABANDONED", "boundary commission abandoned")
	_ok(is_equal_approx(at["honor_delta"], -0.25), "boundary honor loss -0.25 (was %.3f)" % at["honor_delta"])
	_ok(int(at["disp_delta"]) == -4, "boundary disposition loss -4 (was %d)" % int(at["disp_delta"]))
	# Progress 18 (well above 10) -> still half.
	var above: Dictionary = _run_abandonment(1, 18)
	_ok(is_equal_approx(above["honor_delta"], -0.25), "above-threshold honor loss -0.25")
	_ok(int(above["disp_delta"]) == -4, "above-threshold disposition loss -4")


func _test_per_tier_threshold() -> void:
	print("[4] threshold is per target_quality_tier (tier 3 -> 70, 50% = 35)")
	# Tier 3 threshold 70, cutoff 35. Progress 34 < 35 -> full; 35 -> half.
	var below: Dictionary = _run_abandonment(3, 34)
	_ok(is_equal_approx(below["honor_delta"], -0.5), "tier3 progress 34 -> full -0.5")
	_ok(int(below["disp_delta"]) == -8, "tier3 progress 34 -> full -8")
	var at: Dictionary = _run_abandonment(3, 35)
	_ok(is_equal_approx(at["honor_delta"], -0.25), "tier3 progress 35 -> half -0.25")
	_ok(int(at["disp_delta"]) == -4, "tier3 progress 35 -> half -4")
