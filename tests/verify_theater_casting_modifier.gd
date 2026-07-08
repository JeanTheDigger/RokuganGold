extends SceneTree
## Runtime driver for the theater performance casting-fit + Kyogen gate + raises fix (s57.22).
## The canonical TheaterSystem.resolve_performance_roll applies (a) the s57.22.4 casting-fit TN
## modifier (get_casting_tn_modifier) and (b) the s57.22.3 Kyogen minimum-Acting-rank gate, and folds
## raises into the TN once. ActionExecutor._execute_perform_theater inlined a bare
## `tn = BASE + raises*5` roll that DROPPED both AND double-counted raises (once in tn, again via the
## resolve_skill_check raises arg that roll_check re-adds). Fix: the executor now computes cast_mod via
## the canonical get_casting_tn_modifier, applies the Kyogen gate, and passes 0 raises to
## resolve_skill_check (single count) -- i.e. it now MATCHES resolve_performance_roll exactly.
## This driver proves executor ≡ canonical resolver across configs + anchors the arbiter.
## Run: godot --headless -s tests/verify_theater_casting_modifier.gd

const _AE := preload("res://simulation/action_executor.gd")
const _TS := preload("res://simulation/theater_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(acting: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crab"
	c.family = "Hida"
	c.gender = "male"
	c.awareness = 4
	c.skills = {"Acting": acting}
	return c


func _role_abstract() -> Dictionary:
	return {"subject_type": _TS.SubjectType.ABSTRACT}


func _role_mismatch() -> Dictionary:
	# CHARACTER subject requiring a Crane FEMALE -> a Crab male performer double-mismatches (+10 TN
	# under KABUKI: no Noh mask). Two mismatched features so the penalty (2x CASTING_MISMATCH) is
	# large enough to visibly move a weak performer's success rate.
	return {
		"subject_type": _TS.SubjectType.CHARACTER,
		"clan_requirement": "Crane",
		"gender_requirement": "female",
	}


func _weak_char() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crab"
	c.family = "Hida"
	c.gender = "male"
	c.awareness = 2
	c.skills = {"Acting": 1}
	return c


func _piece(style: int, role: Dictionary) -> TheaterPieceData:
	var p := TheaterPieceData.new()
	p.piece_id = 5
	p.style = style
	p.roles = [role]
	return p


func _action(style: int, role: Dictionary, raises: int) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "PERFORM_THEATER_PIECE"
	a.metadata = {
		"piece_id": 5,
		"piece_style": style,
		"piece_lead_role": role,
		"raises": raises,
		"is_bunraku_performance": false,
	}
	return a


func _ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 200
	ctx.season = 0
	ctx.location_id = "10"
	return ctx


# Run the executor and the canonical resolver with identical dice seeds; return their key outputs.
func _both(style: int, role: Dictionary, raises: int, acting: int, seed: int) -> Dictionary:
	var char_a := _char(acting)
	var char_b := _char(acting)
	var exec := _AE._execute_perform_theater(_action(style, role, raises), char_a, _ctx(), DiceEngine.new(seed))
	var canon := _TS.resolve_performance_roll(char_b, _piece(style, role), DiceEngine.new(seed), raises, 200)
	return {"exec": exec, "canon": canon}


func _init() -> void:
	print("--- Theater casting-fit + Kyogen gate + raises fix routes through canonical (s57.22) ---")
	_test_arbiter()
	_test_equivalence()
	_test_cast_mod_raises_tn()
	_test_kyogen_gate()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] get_casting_tn_modifier: 0 for ABSTRACT, penalty for a KABUKI clan mismatch")
	var performer := _char(3)
	_ok(_TS.get_casting_tn_modifier(performer, _role_abstract(), _TS.Style.KABUKI) == 0,
		"ABSTRACT role -> 0 casting modifier")
	_ok(_TS.get_casting_tn_modifier(performer, _role_mismatch(), _TS.Style.KABUKI) > 0,
		"CHARACTER clan mismatch (KABUKI, no Noh mask) -> positive TN penalty")
	# Noh mask removes the clan mismatch -> back to 0.
	_ok(_TS.get_casting_tn_modifier(performer, _role_mismatch(), _TS.Style.NOH) == 0,
		"Noh mask negates the clan mismatch -> 0")


func _test_equivalence() -> void:
	print("[2] the executor now matches the canonical resolver exactly (no divergence)")
	var mism: int = 0
	for seed in [11, 42, 99, 777, 2024, 31337]:
		# Abstract role (cast_mod 0), various raises.
		for cfg: Array in [[_TS.Style.KABUKI, _role_abstract(), 0, 3],
				[_TS.Style.KABUKI, _role_mismatch(), 0, 4],
				[_TS.Style.KABUKI, _role_abstract(), 2, 5],
				[_TS.Style.KYOGEN, _role_abstract(), 1, 4]]:
			var r: Dictionary = _both(cfg[0], cfg[1], cfg[2], cfg[3], seed)
			var e: Dictionary = r["exec"]
			var c: Dictionary = r["canon"]
			if int(e.get("effects", {}).get("roll_total", -1)) != int(c.get("roll_total", -2)):
				mism += 1
			if bool(e.get("success", false)) != bool(c.get("success", true)):
				mism += 1
	_ok(mism == 0, "executor roll_total & success == resolve_performance_roll across 24 config/seed pairs")


func _test_cast_mod_raises_tn() -> void:
	print("[3] casting penalty raises the TN (fewer successes than the abstract role)")
	# WEAK performer (Acting 1 / Awareness 2), same seeds: a double-mismatch role (+10 TN) succeeds
	# strictly less often than the abstract role -> proves cast_mod is folded into the TN (was dropped).
	var abstract_wins: int = 0
	var mismatch_wins: int = 0
	for seed in range(1, 201):
		var ea := _AE._execute_perform_theater(
			_action(_TS.Style.KABUKI, _role_abstract(), 0), _weak_char(), _ctx(), DiceEngine.new(seed))
		var em := _AE._execute_perform_theater(
			_action(_TS.Style.KABUKI, _role_mismatch(), 0), _weak_char(), _ctx(), DiceEngine.new(seed))
		if bool(ea.get("success", false)):
			abstract_wins += 1
		if bool(em.get("success", false)):
			mismatch_wins += 1
	_ok(mismatch_wins < abstract_wins,
		"mismatch role succeeds less than abstract (%d < %d) -> cast_mod applied" % [mismatch_wins, abstract_wins])


func _test_kyogen_gate() -> void:
	print("[4] Kyogen minimum-Acting-rank gate blocks a low-rank performer")
	# Acting 2 (< KYOGEN_MIN_ACTING_RANK 3) -> blocked in both paths.
	var low := _both(_TS.Style.KYOGEN, _role_abstract(), 0, 2, 55)
	var e_low: Dictionary = low["exec"]
	var c_low: Dictionary = low["canon"]
	_ok(not bool(e_low.get("success", true))
		and e_low.get("effects", {}).get("blocked_reason", "") == "kyogen_acting_rank",
		"executor: Acting 2 Kyogen -> blocked (kyogen_acting_rank)")
	_ok(bool(c_low.get("blocked_kyogen_rank", false)), "canonical: Acting 2 Kyogen -> blocked_kyogen_rank")
	# Acting 4 (>= 3) -> not gate-blocked (may still fail the roll, but no gate block).
	var hi := _both(_TS.Style.KYOGEN, _role_abstract(), 0, 4, 55)
	_ok(hi["exec"].get("effects", {}).get("blocked_reason", "") != "kyogen_acting_rank",
		"executor: Acting 4 Kyogen -> NOT gate-blocked")
	# A KABUKI performer with Acting 2 is fine (gate is Kyogen-only).
	var kab := _both(_TS.Style.KABUKI, _role_abstract(), 0, 2, 55)
	_ok(kab["exec"].get("effects", {}).get("blocked_reason", "") != "kyogen_acting_rank",
		"executor: Acting 2 KABUKI -> not gated (gate is Kyogen-only)")
