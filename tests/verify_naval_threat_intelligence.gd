extends SceneTree
## Runtime driver for the has_naval_threat producer fix (s57.18).
## DayOrchestrator._populate_infrastructure_intelligence built `naval_threatened_clans` by iterating
## `world_states.get("active_wars", [])` at the TOP level -- but this runs early in advance_day (~:158),
## long before top-level active_wars is briefly set (only during the seasonal strategic reviews at
## ~:12859, then erased). So the read always saw [] -> naval_threatened_clans permanently empty ->
## ws["has_naval_threat"] always false -> the objective_decomposer COMMISSION_SHIP defensive-ship branch
## (is_coastal AND has_naval_threat AND NOT has_naval_assets) never fired. Fix: iterate the real
## active_wars param (WarData array -- the loop already expects `w is WarData`).
## Run: godot --headless -s tests/verify_naval_threat_intelligence.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _ship(clan: String) -> ShipData:
	var s := ShipData.new()
	s.owning_clan = clan
	s.is_destroyed = false
	return s


func _war(a: String, b: String) -> WarData:
	var w := WarData.new()
	w.clan_a = a
	w.clan_b = b
	w.is_active = true
	return w


func _threatened(active_wars: Array, ships: Array) -> Dictionary:
	var ws: Dictionary = {}
	# provinces / settlements / worship empty -- we only exercise the naval branch.
	_DO._populate_infrastructure_intelligence(ws, {}, [], ships, {}, [], active_wars)
	return ws.get("_naval_threatened_clans", {})


func _init() -> void:
	print("--- has_naval_threat producer reads the real active_wars param (s57.18) ---")
	_test()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test() -> void:
	print("[1] _populate_infrastructure_intelligence populates _naval_threatened_clans from active_wars")
	var ships: Array = [_ship("Crab")]  # only Crab has a navy

	# EMPTY active_wars (the dead pre-fix state at :158) -> nobody threatened.
	var dead: Dictionary = _threatened([], ships)
	_ok(dead.is_empty(), "no wars -> _naval_threatened_clans empty (matches the dead pre-fix)")

	# Crab (navy) at war with Lion (no navy) -> Lion is naval-threatened, Crab is not.
	var t: Dictionary = _threatened([_war("Crab", "Lion")], ships)
	_ok(t.has("Lion"), "Lion at war with a naval Crab -> Lion naval-threatened (revived)")
	_ok(not t.has("Crab"), "Crab (the naval side) is not itself threatened by the landlocked Lion")

	# Two non-naval clans at war -> neither threatened (no navy on either side).
	var t2: Dictionary = _threatened([_war("Lion", "Crane")], ships)
	_ok(t2.is_empty(), "two landlocked clans at war -> nobody naval-threatened")

	# An INACTIVE war is still iterated by the WarData loop, but a war between a naval and non-naval
	# clan threatens the non-naval side regardless of is_active (the loop guards only on `is WarData`).
	# The active-war set passed in production (_remove_resolved_wars keeps it active) is the real gate;
	# here we confirm the naval logic itself, using an active war.
	var t3: Dictionary = _threatened([_war("Lion", "Crab")], ships)  # clan order swapped
	_ok(t3.has("Lion") and not t3.has("Crab"), "naval detection is order-independent (clan_b naval)")
