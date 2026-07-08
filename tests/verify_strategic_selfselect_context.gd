extends SceneTree
## Runtime driver for the Strategic-Review self-selection top-level plumbing follow-ups (s55.10).
## Three empty-top-level-key / wrong-shape corrections on the SAME injection seam as the war-context fix:
##   (A) known_clan_strengths + taint_topic_province_ids are GLOBAL facts written only on PER-CHARACTER
##       ws sub-dicts by _inject_base_character_context, but OpportunityScanner._scan_military (reached
##       via StrategicReview._evaluate_self_selection -> select_primary_objective with the TOP-LEVEL
##       dict) reads them at top level, where they were empty -> the lord self-selection
##       BUILD_STRONGEST_FORCE / LEVY_TROOPS (rival clan strength) and ELIMINATE_SHADOWLANDS (taint
##       topics) opportunities never fired. Now hoisted to top-level in the injector.
##   (B) current_season is read off the TOP-LEVEL world_state by the court evaluators as an int enum,
##       but was only set per-character as a STRING season name -> the Emperor could never host Winter
##       Court (_evaluate_winter_court_host guards `!= AUTUMN`). Now injected as the int enum.
##   (C) the war-context fix injected RAW WarData into top-level active_wars, but the self-selection
##       consumers (opportunity_scanner `war if war is Dictionary else {}`, objective_progress
##       `if war is Dictionary`) read clan_a/clan_b and SILENTLY no-op on WarData -- so the injection
##       is now the CONTEXT-DICT form (WarSystem.wars_to_context_array).
## Run: godot --headless -s tests/verify_strategic_selfselect_context.gd

const _OS := preload("res://simulation/opportunity_scanner.gd")
const _SR := preload("res://simulation/strategic_review.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _lord(clan: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = clan
	return c


func _has_objective(opps: Array, otype: String) -> bool:
	for o: Variant in opps:
		if o != null and o.objective_type == otype:
			return true
	return false


func _active_war(a: String, b: String) -> WarData:
	var w := WarData.new()
	w.clan_a = a
	w.clan_b = b
	w.is_active = true
	return w


func _init() -> void:
	print("--- Strategic-Review self-selection top-level plumbing (s55.10) ---")
	_test_scan_military_revival()
	_test_current_season()
	_test_war_shape()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_scan_military_revival() -> void:
	print("[1] _scan_military revives BUILD_STRONGEST_FORCE + ELIMINATE_SHADOWLANDS when the top-level keys are present")
	var lord := _lord("Crab")
	# EMPTY top-level world_state (the dead pre-fix state) -> neither opportunity.
	var dead: Array = _OS._scan_military(lord, "MILITARY_DOMINANCE", {})
	_ok(not _has_objective(dead, "BUILD_STRONGEST_FORCE"), "empty ws -> no BUILD_STRONGEST_FORCE (dead)")
	_ok(not _has_objective(dead, "ELIMINATE_SHADOWLANDS"), "empty ws -> no ELIMINATE_SHADOWLANDS (dead)")

	# known_clan_strengths with a rival > mine * 1.3 -> BUILD_STRONGEST_FORCE (Dictionary, type-safe).
	var strong: Array = _OS._scan_military(lord, "MILITARY_DOMINANCE",
		{"known_clan_strengths": {"Crab": 100.0, "Lion": 200.0}})
	_ok(_has_objective(strong, "BUILD_STRONGEST_FORCE"), "rival 2x -> BUILD_STRONGEST_FORCE (revived)")

	# rival only 1.15x -> LEVY_TROOPS band, not BUILD_STRONGEST_FORCE.
	var mid: Array = _OS._scan_military(lord, "BUILD_STRONGEST_FORCE",
		{"known_clan_strengths": {"Crab": 100.0, "Lion": 115.0}})
	_ok(_has_objective(mid, "LEVY_TROOPS"), "rival 1.15x -> LEVY_TROOPS (revived)")
	_ok(not _has_objective(mid, "BUILD_STRONGEST_FORCE"), "rival 1.15x -> not BUILD_STRONGEST_FORCE")

	# taint_topic_province_ids (Array[int], type-safe Variant loop) -> ELIMINATE_SHADOWLANDS.
	var taint: Array = _OS._scan_military(lord, "STRENGTHEN_WALL",
		{"taint_topic_province_ids": [42]})
	_ok(_has_objective(taint, "ELIMINATE_SHADOWLANDS"), "taint topic province -> ELIMINATE_SHADOWLANDS (revived)")


func _test_current_season() -> void:
	print("[2] current_season revives _evaluate_winter_court_host (int-enum top-level, was always 0/SPRING)")
	var emperor := _lord("Imperial")
	var champ := _lord("Crane")
	champ.character_id = 2
	# AUTUMN + a living champion -> the Emperor produces a WINTER_COURT_HOST directive.
	var autumn: Dictionary = _SR._evaluate_winter_court_host(
		emperor, _SR.EmperorArchetype.IRON, [champ], {"current_season": TimeSystem.Season.AUTUMN})
	_ok(not autumn.is_empty() and String(autumn.get("directive", "")) == "WINTER_COURT_HOST",
		"AUTUMN + champion -> WINTER_COURT_HOST (revived)")
	# SPRING (the dead pre-fix default) -> {} at the season guard, champion notwithstanding.
	var spring: Dictionary = _SR._evaluate_winter_court_host(
		emperor, _SR.EmperorArchetype.IRON, [champ], {"current_season": TimeSystem.Season.SPRING})
	_ok(spring.is_empty(), "SPRING -> {} (season guard, the dead default)")
	# Empty world_state defaults to 0 (== SPRING) -> {} (proves the top-level key was absent pre-fix).
	var absent: Dictionary = _SR._evaluate_winter_court_host(
		emperor, _SR.EmperorArchetype.IRON, [champ], {})
	_ok(absent.is_empty(), "no current_season key -> {} (default 0 == SPRING)")


func _test_war_shape() -> void:
	print("[3] active_wars injected as CONTEXT-DICTS (clan_a/clan_b) so the `is Dictionary` consumers fire")
	# The war-context fix now injects wars_to_context_array(...) instead of raw WarData.
	var converted: Array = WarSystem.wars_to_context_array([_active_war("Lion", "Crane")])
	_ok(converted.size() == 1 and converted[0] is Dictionary, "converted entry IS a Dictionary")
	_ok(String(converted[0].get("clan_a", "")) == "Lion" and String(converted[0].get("clan_b", "")) == "Crane",
		"converted entry exposes clan_a/clan_b (what opportunity_scanner / objective_progress read)")
	# The raw form (what the fix used to inject) is NOT a Dictionary -> the `is Dictionary` guards
	# would silently no-op on it, which is exactly why the shape had to be corrected. (Variant-typed
	# local so GDScript doesn't reject the statically-impossible `WarData is Dictionary` at parse time.)
	var raw: Variant = _active_war("Lion", "Crane")
	_ok(not (raw is Dictionary), "raw WarData is NOT a Dictionary (the shape bug)")
	# wars_to_context_array also filters to is_active (matches the per-character g_active_wars form).
	var inactive := WarData.new()
	inactive.clan_a = "Crab"
	inactive.clan_b = "Scorpion"
	inactive.is_active = false
	_ok(WarSystem.wars_to_context_array([inactive]).is_empty(), "inactive war filtered out (is_active gate)")
