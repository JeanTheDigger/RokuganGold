extends SceneTree
## Runtime driver for injecting the war-context keys into the Strategic Review world_state (s53/s55.10).
## StrategicReview.run_seasonal_review's _evaluate_seek_peace / _evaluate_war_readiness read
## `active_wars` and `escalating_conflicts` from the TOP-LEVEL world_states -- but those keys were
## NEVER set there (only on per-character sub-dicts). So SEEK_PEACE was fully dead (its
## `active_wars.is_empty()` guard always fired, even for JIN lords) and WAR_READINESS's primary +
## YU-virtue triggers never fired -- starving the Phoenix Council SIGN_TREATY / DEPLOY_GO_HATAMOTO
## vote flow and the Togashi war/peace alignment check. DayOrchestrator._run_strategic_reviews now
## injects both (values already in scope) before the vassal review loop and erases them after.
## This driver proves the consumers revive when the keys are present.
## Run: godot --headless -s tests/verify_strategic_war_context.gd

const _SR := preload("res://simulation/strategic_review.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _lord(virtue: Enums.BushidoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.bushido_virtue = virtue
	return c


func _has_directive(directives: Array, dtype: int) -> bool:
	for d: Variant in directives:
		if d is Dictionary and int((d as Dictionary).get("directive", -1)) == dtype:
			return true
	return false


func _init() -> void:
	print("--- Strategic Review war-context keys injected (s53/s55.10) ---")
	_test_seek_peace()
	_test_war_readiness()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_seek_peace() -> void:
	print("[1] _evaluate_seek_peace revives when active_wars is present")
	# EMPTY world_state (the dead state pre-fix) -> {} regardless of virtue
	_ok(_SR._evaluate_seek_peace(_lord(Enums.BushidoVirtue.JIN), {}).is_empty(),
		"no active_wars -> {} even for JIN (the dead guard)")
	# active_wars present + JIN -> SEEK_PEACE
	var r := _SR._evaluate_seek_peace(_lord(Enums.BushidoVirtue.JIN), {"active_wars": [WarData.new()]})
	_ok(not r.is_empty() and int(r.get("directive", -1)) == _SR.Directive.SEEK_PEACE,
		"active_wars + JIN -> SEEK_PEACE (revived)")
	# active_wars present + GI (non-JIN, no duration) -> {} (war-duration branch is deferred)
	_ok(_SR._evaluate_seek_peace(_lord(Enums.BushidoVirtue.GI), {"active_wars": [WarData.new()]}).is_empty(),
		"active_wars + GI (no duration) -> {} (JIN-only path)")


func _test_war_readiness() -> void:
	print("[2] _evaluate_war_readiness revives its primary + YU triggers")
	# EMPTY -> {} (dead)
	_ok(_SR._evaluate_war_readiness(_lord(Enums.BushidoVirtue.CHUGI), {}).is_empty(),
		"no keys -> {} (dead)")
	# active_wars present -> WAR_READINESS (primary trigger)
	var r1 := _SR._evaluate_war_readiness(_lord(Enums.BushidoVirtue.CHUGI), {"active_wars": [WarData.new()]})
	_ok(not r1.is_empty() and int(r1.get("directive", -1)) == _SR.Directive.WAR_READINESS,
		"active_wars -> WAR_READINESS (primary trigger revived)")
	# escalating_conflicts present + YU lord (no active_wars) -> WAR_READINESS (YU trigger)
	var r2 := _SR._evaluate_war_readiness(_lord(Enums.BushidoVirtue.YU), {"escalating_conflicts": [{"clan": "Lion"}]})
	_ok(not r2.is_empty() and int(r2.get("directive", -1)) == _SR.Directive.WAR_READINESS,
		"escalating_conflicts + YU -> WAR_READINESS (YU trigger revived)")
	# escalating_conflicts present + non-YU, military_readiness default 1.0 -> {} (elif deferred)
	_ok(_SR._evaluate_war_readiness(_lord(Enums.BushidoVirtue.CHUGI), {"escalating_conflicts": [{"clan": "Lion"}]}).is_empty(),
		"escalating_conflicts + non-YU (military_readiness 1.0) -> {} (elif deferred)")


func _test_end_to_end() -> void:
	print("[3] run_seasonal_review produces SEEK_PEACE + WAR_READINESS when the war-context is injected")
	var jin_lord := _lord(Enums.BushidoVirtue.JIN)
	# With active_wars present (simulating the post-injection world_state) both directives appear.
	var with_war: Array = _SR.run_seasonal_review(jin_lord, [], {}, {"active_wars": [WarData.new()]})
	_ok(_has_directive(with_war, _SR.Directive.SEEK_PEACE), "war present -> SEEK_PEACE in directives")
	_ok(_has_directive(with_war, _SR.Directive.WAR_READINESS), "war present -> WAR_READINESS in directives")
	# Control: with NO war-context (the dead pre-fix world_state) neither appears.
	var no_war: Array = _SR.run_seasonal_review(jin_lord, [], {}, {})
	_ok(not _has_directive(no_war, _SR.Directive.SEEK_PEACE), "no war-context -> no SEEK_PEACE (dead pre-fix)")
	_ok(not _has_directive(no_war, _SR.Directive.WAR_READINESS), "no war-context -> no WAR_READINESS (dead pre-fix)")
