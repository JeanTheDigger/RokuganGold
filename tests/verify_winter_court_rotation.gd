extends SceneTree
## Runtime driver for the s55.10 Winter-Court HOST ROTATION activation (owner-approved 2026-07-08).
## _evaluate_winter_court_host scores each clan by seasons-since-last-hosted =
## current_season_index - last_host_seasons[clan]. Both were phantom keys (zero producers), so the
## rotation term was a CONSTANT for every clan (0 - (-100) = 100 -> capped 20 -> +15 each) and never
## differentiated. Fix: inject the monotonic current_season_index (TimeSystem.get_absolute_season) and
## maintain last_host_seasons (written on court creation). With archetype IRON (0 preference) and equal
## disposition/crisis, the rotation term is the sole differentiator, so we can isolate it.
## Run: godot --headless -s tests/verify_winter_court_rotation.gd

const _SR := preload("res://simulation/strategic_review.gd")
const _CH := preload("res://shared/character_data.gd")
const _TS := preload("res://simulation/time_system.gd")

const AUTUMN: int = 2  # Season.AUTUMN
const SPRING: int = 0

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _champ(cid: int, clan: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.clan = clan
	c.status = 7.0
	return c


func _emperor() -> L5RCharacterData:
	var e: L5RCharacterData = _CH.new()
	e.character_id = 1
	e.clan = "Imperial"
	return e


## IRON archetype -> _archetype_host_preference == 0; empty disposition/crisis -> those terms are 0;
## so the rotation term (current_season_index - last_host_seasons[clan]) is the SOLE differentiator.
func _state(season: int, season_index: int, last_host: Dictionary) -> Dictionary:
	return {
		"current_season": season,
		"current_season_index": season_index,
		"last_host_seasons": last_host,
		"crisis_momentum_by_clan": {},
	}


func _host(champs: Array, st: Dictionary) -> Dictionary:
	return _SR._evaluate_winter_court_host(
		_emperor(), _SR.EmperorArchetype.IRON, champs, st,
	)


func _init() -> void:
	print("--- s55.10 Winter-Court host rotation activated ---")
	var crab := _champ(10, "Crab")
	var crane := _champ(20, "Crane")

	print("[1] the never-hosted / long-ago clan is preferred over a recently-hosted one")
	# Crab hosted THIS absolute season (40), Crane never (-100 default).
	var r1 := _host([crab, crane], _state(AUTUMN, 40, {"Crab": 40}))
	_ok(r1.get("directive", "") == "WINTER_COURT_HOST", "returns a WINTER_COURT_HOST directive")
	_ok(r1.get("host_clan", "") == "Crane", "Crab just hosted -> Crane (never hosted) is chosen")

	print("[2] swap the recency -> the choice flips (proves the term is live, not constant)")
	var r2 := _host([crab, crane], _state(AUTUMN, 40, {"Crane": 40}))
	_ok(r2.get("host_clan", "") == "Crab", "Crane just hosted -> Crab is chosen")

	print("[3] longer-ago-hosted clan beats a more-recently-hosted one")
	# Crab hosted 4 seasons ago (36), Crane 20 seasons ago (20). Crane waited longer -> Crane.
	var r3 := _host([crab, crane], _state(AUTUMN, 40, {"Crab": 36, "Crane": 20}))
	_ok(r3.get("host_clan", "") == "Crane", "Crane (20 seasons ago) beats Crab (4 seasons ago)")

	print("[4] pre-fix phantom state (no keys) -> no differentiation (both hit the -100 default -> tie)")
	# Without the injected index / tracker, both clans get 0 - (-100) = 100 -> capped 20 -> +15 (equal).
	# best_score uses strict >, so the FIRST-iterated clan wins -> the term was inert.
	var r4a := _host([crab, crane], {"current_season": AUTUMN})
	var r4b := _host([crane, crab], {"current_season": AUTUMN})
	_ok(r4a.get("host_clan", "") == "Crab" and r4b.get("host_clan", "") == "Crane",
		"no rotation data -> iteration order decides (the dead pre-fix behavior)")

	print("[5] non-AUTUMN guard: Winter Court is only proposed in Autumn")
	var r5 := _host([crab, crane], _state(SPRING, 40, {"Crab": 40}))
	_ok(r5.is_empty(), "SPRING -> {} (no host directive)")

	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
