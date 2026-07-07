extends SceneTree
## Runtime driver for wiring KolatSystem.degrade_sleeper_seasonal into the seasonal tick
## (s54.7c, LOCKED: "conditioning_stability is a float 0-100 that degrades passively at a rate
## of 5 points per IC season without contact"). The function encodes this exactly but had ZERO
## production callers -- the daily tick only ran process_sleeper_expiry on MAGICAL (World is
## Truth) sleepers, so Dream-conditioned (psychological) sleepers never degraded: every sleeper
## stayed permanently above the activation floor and the MAINTAIN_SLEEPER_CONTACT loop was inert.
## Verifies the decay (-5 / +season_days), its guards (magical / active-command / non-sleeper
## skipped, floor at 0), the consumed consequence (can_activate_sleeper flips at the floor), the
## restore path that closes the loop (+10 cap 100, overdue reset), and the elapsed-season lengths.
## Run: godot --headless -s tests/verify_sleeper_decay.gd

const _K := preload("res://simulation/kolat_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _psych_sleeper(stability: float = 100.0) -> L5RCharacterData:
	# A Dream-conditioned psychological sleeper: stability >= 0, no active command, not magical.
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.conditioning_stability = stability
	c.active_sleeper_command = {}
	c.sleeper_expiry_ic_day = -1
	c.sleeper_contact_overdue = 0
	return c


func _init() -> void:
	print("--- Kolat Sleeper Seasonal Decay (s54.7c) ---")
	_test_decay_and_guards()
	_test_activation_consequence()
	_test_restore_closes_loop()
	_test_season_lengths()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_decay_and_guards() -> void:
	print("[1] decay -5/season + overdue accrual; guards skip the wrong sleepers")
	var s := _psych_sleeper(100.0)
	_K.degrade_sleeper_seasonal(s, 90)
	_ok(abs(s.conditioning_stability - 95.0) < 0.001, "stability 100 -> 95 (-5)")
	_ok(s.sleeper_contact_overdue == 90, "overdue += season_days (90)")
	_K.degrade_sleeper_seasonal(s, 90)
	_ok(abs(s.conditioning_stability - 90.0) < 0.001, "second season -> 90")
	_ok(s.sleeper_contact_overdue == 180, "overdue accumulates (180)")

	# Floor at 0 (never negative).
	var low := _psych_sleeper(3.0)
	_K.degrade_sleeper_seasonal(low, 90)
	_ok(low.conditioning_stability == 0.0, "stability 3 -> 0 (floored, not negative)")

	# Magical (World is Truth) sleeper: expiry >= 0 -> NOT decayed.
	var magical := _psych_sleeper(100.0)
	magical.sleeper_expiry_ic_day = 130
	_K.degrade_sleeper_seasonal(magical, 90)
	_ok(abs(magical.conditioning_stability - 100.0) < 0.001, "magical sleeper NOT decayed")

	# Active-command sleeper: mid-mission -> NOT decayed.
	var active := _psych_sleeper(100.0)
	active.active_sleeper_command = {"cmd": "kill the daimyo"}
	_K.degrade_sleeper_seasonal(active, 90)
	_ok(abs(active.conditioning_stability - 100.0) < 0.001, "active-command sleeper NOT decayed")

	# Non-sleeper (default stability -1.0) -> is_sleeper false -> NOT touched.
	var ordinary := L5RCharacterData.new()
	ordinary.character_id = 9
	_ok(ordinary.conditioning_stability == -1.0, "ordinary character default stability -1.0")
	# Defaults: stability -1.0, sleeper_contact_overdue -1 (both untouched -> non-sleeper skipped).
	_ok(ordinary.sleeper_contact_overdue == -1, "ordinary character default overdue -1")
	_K.degrade_sleeper_seasonal(ordinary, 90)
	_ok(ordinary.conditioning_stability == -1.0 and ordinary.sleeper_contact_overdue == -1,
		"non-sleeper untouched by decay")


func _test_activation_consequence() -> void:
	print("[2] decay eventually pushes stability below the activation floor (consumed)")
	var s := _psych_sleeper(100.0)
	_ok(_K.can_activate_sleeper(s), "fresh sleeper (100) is activatable")
	# 10 seasons of -5 -> 50.0, which is NOT > ACTIVATION_STABILITY_FLOOR (50) -> unactivatable.
	for _i: int in range(10):
		_K.degrade_sleeper_seasonal(s, 90)
	_ok(abs(s.conditioning_stability - 50.0) < 0.001, "10 seasons -> 50")
	_ok(not _K.can_activate_sleeper(s), "at 50 (not > floor) -> NO LONGER activatable")


func _test_restore_closes_loop() -> void:
	print("[3] MAINTAIN_SLEEPER_CONTACT restores +10 / resets overdue (loop closes)")
	var s := _psych_sleeper(70.0)
	_K.degrade_sleeper_seasonal(s, 90)  # 70 -> 65, overdue 90
	_K.maintain_sleeper_contact(s)
	_ok(abs(s.conditioning_stability - 75.0) < 0.001, "65 + 10 restore -> 75")
	_ok(s.sleeper_contact_overdue == 0, "overdue reset to 0 on contact")
	# Restore is capped at 100.
	var high := _psych_sleeper(95.0)
	_K.maintain_sleeper_contact(high)
	_ok(abs(high.conditioning_stability - 100.0) < 0.001, "restore capped at 100 (95 + 10)")


func _test_season_lengths() -> void:
	print("[4] elapsed-season lengths from SEASON_BOUNDARIES (the season_days passed by the wire)")
	var b: Array = TimeSystem.SEASON_BOUNDARIES
	_ok(b[int(TimeSystem.Season.SPRING) + 1] - b[int(TimeSystem.Season.SPRING)] == 90, "SPRING = 90 days")
	_ok(b[int(TimeSystem.Season.SUMMER) + 1] - b[int(TimeSystem.Season.SUMMER)] == 90, "SUMMER = 90 days")
	_ok(b[int(TimeSystem.Season.AUTUMN) + 1] - b[int(TimeSystem.Season.AUTUMN)] == 60, "AUTUMN = 60 days")
	_ok(b[int(TimeSystem.Season.WINTER) + 1] - b[int(TimeSystem.Season.WINTER)] == 120, "WINTER = 120 days")
