extends SceneTree
## Runtime driver for the Emperor FILL_VACANCY key-mismatch fix (s55.10 / s57.20).
## StrategicReview._evaluate_vacancy_fill read the Emperor's vacancy list off a phantom key
## `world_state.get("vacancies", [])` that NOTHING ever writes -> always empty -> the Emperor's
## archetype-gated FILL_VACANCY directive was permanently dead. The producer
## (DayOrchestrator._populate_vacancy_intelligence, run early each tick) writes
## world_states["vacancy_data"] keyed by lord_id, appending the Emperor's court/Governor seats to
## vacancy_data[emperor_id]. Fix: read that canonical key.
## Run: godot --headless -s tests/verify_emperor_vacancy_fill.gd

const _SR := preload("res://simulation/strategic_review.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _emperor() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 7
	return c


func _vacancy() -> Dictionary:
	# A political seat, long vacant (passes any archetype min), high priority.
	return {"position_type": "imperial_advisor", "priority": 5, "seasons_vacant": 99, "candidate_id": -1}


func _init() -> void:
	print("--- Emperor FILL_VACANCY reads the canonical vacancy_data key (s55.10) ---")
	_test()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test() -> void:
	var emp := _emperor()
	var arch: int = _SR.EmperorArchetype.IRON

	print("[1] _evaluate_vacancy_fill revives when vacancy_data[emperor_id] is present")
	# EMPTY world_state (the dead pre-fix state) -> {}.
	_ok(_SR._evaluate_vacancy_fill(emp, arch, {}).is_empty(), "empty ws -> {} (dead)")

	# The OLD phantom key is ignored -> still {} (proves the fix no longer reads `vacancies`).
	_ok(_SR._evaluate_vacancy_fill(emp, arch, {"vacancies": [_vacancy()]}).is_empty(),
		"legacy phantom `vacancies` key -> {} (ignored)")

	# The canonical vacancy_data[emperor_id] -> FILL_VACANCY directive (revived).
	var r := _SR._evaluate_vacancy_fill(emp, arch, {"vacancy_data": {7: [_vacancy()]}})
	_ok(not r.is_empty() and String(r.get("directive", "")) == "FILL_VACANCY",
		"vacancy_data[emperor_id] -> FILL_VACANCY (revived)")
	_ok(int(r.get("lord_id", -1)) == 7, "directive targets the emperor")
	_ok((r.get("vacancy", {}) as Dictionary).get("position_type", "") == "imperial_advisor",
		"directive carries the best vacancy")

	# vacancy_data present but keyed to a DIFFERENT lord -> the emperor sees none.
	_ok(_SR._evaluate_vacancy_fill(emp, arch, {"vacancy_data": {99: [_vacancy()]}}).is_empty(),
		"vacancy_data for another lord -> {} (per-lord keying respected)")
