extends SceneTree
## Runtime driver for the Winter Court delegate-selection Perform-skill mismatch fix.
##
## WinterCourtSystem._score_delegate_candidate sums a candidate's court skills (Etiquette +
## Sincerity + Courtier + Perform) to score them for delegation. But "Perform" is a skill CATEGORY
## -- characters store sub-skills ("Perform: Song", "Perform: Dance", ...), never a bare "Perform"
## key -- so skills.get("Perform", 0) was ALWAYS 0, and every candidate's performance ability was
## silently dropped from the score (while still dividing the sum by 4). Fix: resolve to the best
## Perform sub-skill via the canonical NPCDecisionEngine._best_skill_rank helper (same category
## resolution as the Games:Go / Lore precedent). No invented value -- just reading the real skill.
## Run: godot --headless -s tests/verify_winter_court_perform_skill.gd

const _WCS := preload("res://simulation/winter_court_system.gd")
const _NDE := preload("res://simulation/npc_decision_engine.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, skills: Dictionary) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = "Crane"
	c.status = 4.0
	c.skills = skills
	c.wounds_taken = 0
	return c


func _init() -> void:
	print("--- Winter Court delegate Perform-skill resolution ---")
	_test_helper()
	_test_delegate_score_uses_perform()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_helper() -> void:
	print("[1] _best_skill_rank resolves the Perform category to its best sub-skill")
	_ok(_NDE._best_skill_rank("Perform", {"Perform: Song": 5}) == 5, "single sub-skill -> its rank")
	_ok(_NDE._best_skill_rank("Perform", {"Perform: Song": 3, "Perform: Dance": 5}) == 5, "max across sub-skills")
	_ok(_NDE._best_skill_rank("Perform", {}) == 0, "no perform skill -> 0")
	_ok(_NDE._best_skill_rank("Perform", {"Perform": 5}) == 0, "a bare 'Perform' key (non-canonical) -> 0 (needs a colon)")


func _test_delegate_score_uses_perform() -> void:
	print("[2] a candidate with a Perform sub-skill now scores higher than one without")
	var champion: L5RCharacterData = _mk(100, {})
	# Identical candidates except the Perform sub-skill.
	var base: Dictionary = {"Etiquette": 3, "Sincerity": 2, "Courtier": 3}
	var performer_skills: Dictionary = base.duplicate()
	performer_skills["Perform: Song"] = 5
	var performer: L5RCharacterData = _mk(1, performer_skills)
	var non_performer: L5RCharacterData = _mk(2, base.duplicate())
	# Equal disposition so only the court-skill term differs.
	champion.disposition_values[1] = 20.0
	champion.disposition_values[2] = 20.0

	var s_perf: float = _WCS._score_delegate_candidate(performer, champion, [], {})
	var s_none: float = _WCS._score_delegate_candidate(non_performer, champion, [], {})
	_ok(s_perf > s_none, "performer scores strictly higher (Perform now counts): %.3f > %.3f" % [s_perf, s_none])

	# A candidate whose ONLY court skill is a Perform sub-skill scores above one with zero court skills
	# (proves the Perform term is contributing, not silently dropped as before).
	var only_perform: L5RCharacterData = _mk(3, {"Perform: Dance": 5})
	var empty_court: L5RCharacterData = _mk(4, {})
	champion.disposition_values[3] = 0.0
	champion.disposition_values[4] = 0.0
	var s_op: float = _WCS._score_delegate_candidate(only_perform, champion, [], {})
	var s_ec: float = _WCS._score_delegate_candidate(empty_court, champion, [], {})
	_ok(s_op > s_ec, "a pure-Perform candidate outscores a no-court-skill candidate: %.3f > %.3f" % [s_op, s_ec])
