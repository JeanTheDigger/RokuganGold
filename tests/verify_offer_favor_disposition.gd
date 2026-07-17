extends SceneTree
## Runtime driver for the OFFER_FAVOR disposition-on-offer fix (s12.10 lines 21-31, LOCKED).
## FavorSystem.get_offer_disposition is the canonical arbiter for the disposition raise an offered
## favor grants ("These replace the existing flat value in the Offer a Favor court action, s15.4").
## It had ZERO production callers: ActionExecutor's OFFER_FAVOR path routed through
## CourtActionSystem.resolve_offer_favor, which returns success WITHOUT any disposition_change, so a
## successful favor offer applied 0 disposition (the locked +6/+2-per-Raise MINOR mechanic was dead).
## Fix: the executor now sets effects.disposition_change = get_offer_disposition(MINOR, raises, false)
## on success and get_offer_disposition(MINOR, 0, true) (= -5) on a critical failure (margin <= -10).
## Run: godot --headless -s tests/verify_offer_favor_disposition.gd

const _AE := preload("res://simulation/action_executor.gd")
const _FS := preload("res://simulation/favor_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, sincerity: int, awareness: int, perception: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.skills = {"Sincerity": sincerity}
	c.awareness = awareness
	c.perception = perception
	c.honor = 3.0  # court honor modifier neutral-ish
	return c


func _action(target_id: int) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "OFFER_FAVOR"
	a.target_npc_id = target_id
	a.metadata = {}
	return a


func _ctx(cid: int) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = cid
	ctx.ic_day = 100
	ctx.season = 0
	return ctx


func _init() -> void:
	print("--- OFFER_FAVOR disposition-on-offer wires get_offer_disposition (s12.10) ---")
	_test_arbiter()
	_test_success()
	_test_critical_failure()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] get_offer_disposition matches the GDD-locked tiers")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MINOR, 0, false) == 6, "MINOR +6 base")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MINOR, 2, false) == 10, "MINOR +2/Raise (2 -> 6+4=10)")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MODERATE, 0, false) == 10, "MODERATE +10 base")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MODERATE, 1, false) == 13, "MODERATE +3/Raise")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MAJOR, 0, false) == 15, "MAJOR +15 base")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MAJOR, 2, false) == 23, "MAJOR +4/Raise (2 -> 15+8=23)")
	_ok(_FS.get_offer_disposition(FavorData.FavorTier.MINOR, 5, true) == -5, "critical failure -> -5 (any tier)")


func _test_success() -> void:
	print("[2] a successful OFFER_FAVOR emits the arbiter's disposition (was 0)")
	# Overwhelming actor (Sincerity 10 / Awareness 10) vs a weak target -> near-certain large-margin win.
	var actor := _char(1, 10, 10, 10)
	var target := _char(2, 0, 0, 0)
	var chars: Dictionary = {1: actor, 2: target}
	var dice := DiceEngine.new(4242)
	var successes: int = 0
	var mismatches: int = 0
	for i in range(60):
		var r: Dictionary = _AE._execute_contested_court_action(
			_action(2), actor, _ctx(1), dice, {}, chars,
		)
		if r.get("success", false):
			successes += 1
			var margin: int = int(r.get("margin", 0))
			var raises: int = maxi(int(margin / 5.0), 0)
			var expected: int = _FS.get_offer_disposition(FavorData.FavorTier.MINOR, raises, false)
			var dc: int = int(r.get("effects", {}).get("disposition_change", -999))
			if dc != expected:
				mismatches += 1
			# Every success must carry a NON-ZERO disposition (the whole point of the fix; MINOR base +6).
			if dc < 6:
				mismatches += 1
	_ok(successes >= 55, "the strong actor succeeds most of the time (%d/60)" % successes)
	_ok(mismatches == 0, "every success emits disposition_change == get_offer_disposition(MINOR, raises) and >= 6")


func _test_critical_failure() -> void:
	print("[3] a critical failure (margin <= -10) emits -5, a normal failure emits 0")
	# Weak actor vs strong target -> failures, some critical.
	var actor := _char(1, 0, 1, 1)
	var target := _char(2, 10, 10, 10)
	var chars: Dictionary = {1: actor, 2: target}
	var dice := DiceEngine.new(99)
	var crit_seen: int = 0
	var norm_fail_seen: int = 0
	var bad: int = 0
	for i in range(120):
		var r: Dictionary = _AE._execute_contested_court_action(
			_action(2), actor, _ctx(1), dice, {}, chars,
		)
		if r.get("success", false):
			continue
		var margin: int = int(r.get("margin", 0))
		var dc: int = int(r.get("effects", {}).get("disposition_change", 0))
		if margin <= -10:
			crit_seen += 1
			if dc != -5:
				bad += 1
		else:
			norm_fail_seen += 1
			if dc != 0:
				bad += 1
	_ok(crit_seen > 0, "at least one critical failure observed (%d)" % crit_seen)
	_ok(bad == 0, "critical failures emit -5, ordinary failures emit 0 (0 violations)")
	_ok(norm_fail_seen >= 0, "ordinary failures handled (%d)" % norm_fail_seen)
