extends SceneTree
## Runtime driver for the s15.8 Otomo institutional Gossip/Disclose leans.
## CourtPrioritySystem.get_otomo_lean (GOSSIP -> +15, DISCLOSE -> +10; LOCKED s15.8
## "Otomo Institutional Behavior") had ZERO production callers -- the NPC decision engine
## applies per-action school/family leans in score_all (DISCERN_NEED, ANNOUNCE_HUNT,
## TRAIN_ANIMAL, ...) but no loop added the Otomo lean, so generated Otomo NPCs never
## received their "serpents in the garden" preference. This driver exercises the wire:
## score_all now, for an Otomo NPC (ctx.family == "Otomo"), adds get_otomo_lean(action_id)
## to each option's disposition_modifier. Verified as the Otomo-vs-control delta so it is
## isolated from every other scoring component (base lookup, personality, covert, etc.).
## Run: godot --headless -s tests/verify_otomo_lean.gd

const _NDE := preload("res://simulation/npc_decision_engine.gd")
const _CPS := preload("res://simulation/court_priority_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk_opt(action_id: String) -> NPCDataStructures.ScoredAction:
	var o := NPCDataStructures.ScoredAction.new()
	o.action_id = action_id
	o.target_npc_id = -1
	return o


func _mk_ctx(family: String) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.family = family
	ctx.clan = "Scorpion"
	ctx.school = "Bayushi Courtier"
	ctx.honor = 3.0
	return ctx


# Run score_all on a fresh option set and return {action_id -> disposition_modifier}.
func _score(family: String) -> Dictionary:
	var opts: Array = [_mk_opt("GOSSIP"), _mk_opt("DISCLOSE"), _mk_opt("CHARM")]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"
	_NDE.score_all(opts, need, _mk_ctx(family), {})
	var out: Dictionary = {}
	for o: NPCDataStructures.ScoredAction in opts:
		out[o.action_id] = o.disposition_modifier
	return out


func _init() -> void:
	print("--- s15.8 Otomo Gossip/Disclose institutional lean ---")
	_test_constants()
	_test_otomo_lean_applied()
	_test_non_otomo_control()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_constants() -> void:
	print("[1] arbiter constants (LOCKED s15.8): GOSSIP +15, DISCLOSE +10, others 0")
	_ok(_CPS.get_otomo_lean("GOSSIP") == 15, "GOSSIP lean = 15")
	_ok(_CPS.get_otomo_lean("DISCLOSE") == 10, "DISCLOSE lean = 10")
	_ok(_CPS.get_otomo_lean("CHARM") == 0, "CHARM lean = 0 (not an Otomo lean action)")


func _test_otomo_lean_applied() -> void:
	print("[2] Otomo NPC: GOSSIP/DISCLOSE options gain the lean vs a non-Otomo control")
	var otomo: Dictionary = _score("Otomo")
	var control: Dictionary = _score("Bayushi")  # non-Otomo Scorpion family
	# Delta isolates the Otomo lean from every other (shared) scoring component.
	_ok(float(otomo["GOSSIP"]) - float(control["GOSSIP"]) == 15.0, "GOSSIP: Otomo gets +15 over control")
	_ok(float(otomo["DISCLOSE"]) - float(control["DISCLOSE"]) == 10.0, "DISCLOSE: Otomo gets +10 over control")
	_ok(float(otomo["CHARM"]) - float(control["CHARM"]) == 0.0, "CHARM: no Otomo lean (unchanged)")


func _test_non_otomo_control() -> void:
	print("[3] a non-Otomo family receives no Otomo lean on any action")
	var doji: Dictionary = _score("Doji")
	var bayushi: Dictionary = _score("Bayushi")
	# Two different non-Otomo families score identically for these actions -> no family lean applied.
	_ok(float(doji["GOSSIP"]) == float(bayushi["GOSSIP"]), "GOSSIP identical across non-Otomo families")
	_ok(float(doji["DISCLOSE"]) == float(bayushi["DISCLOSE"]), "DISCLOSE identical across non-Otomo families")
