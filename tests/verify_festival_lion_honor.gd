extends SceneTree
## Runtime driver for the s11.5 Festival of Akodo Lion-honor bonus case-mismatch fix.
##
## GDD s11.5:109 (LOCKED): "Festival of Akodo ... Lion characters who participate gain +0.1 Honor."
## _execute_perform_worship applies honor_change = ctx.festival_honor_gain, +0.1 more when
## ctx.festival_has_lion_honor AND character.clan == the Lion clan. But the clan gate read the
## lowercase literal "lion" -- clans are stored capitalized ("Lion") everywhere else in the
## codebase -- so the gate NEVER matched and the Lion honor bonus was DEAD for every Lion samurai
## during their own founding-Kami festival. Fix: "lion" -> "Lion" (no invented value; +0.1 is the
## LOCKED s11.5 magnitude, already in code, gated on a mistyped clan check).
## Run: godot --headless -s tests/verify_festival_lion_honor.gd

const _AE := preload("res://simulation/action_executor.gd")
const _DICE := preload("res://simulation/dice_engine.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk_char(id: int, clan: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = clan
	c.school_type = Enums.SchoolType.COURTIER  # "normal" worship path
	c.void_ring = 3
	c.reflexes = 3
	c.awareness = 3
	c.wounds_taken = 0
	return c


func _mk_ctx(lion_festival: bool, base_honor: float) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 0
	ctx.festival_has_lion_honor = lion_festival
	ctx.festival_honor_gain = base_honor
	return ctx


func _worship_honor(clan: String, lion_festival: bool, base_honor: float) -> float:
	var c: L5RCharacterData = _mk_char(1, clan)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERFORM_WORSHIP"
	action.target_province_id = -1
	action.target_npc_id = -1
	var ctx: NPCDataStructures.ContextSnapshot = _mk_ctx(lion_festival, base_honor)
	ctx.character_id = c.character_id
	var res: Dictionary = _AE._execute_perform_worship(action, c, ctx, _DICE.new(7))
	return float((res.get("effects", {}) as Dictionary).get("honor_change", -999.0))


func _init() -> void:
	print("--- s11.5 Festival of Akodo Lion-honor bonus ---")
	_test_lion_bonus_fires()
	_test_non_lion_and_no_festival()
	_test_stacks_with_base()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_lion_bonus_fires() -> void:
	print("[1] a Lion char during the lion_honor festival gains +0.1 (the revived bonus)")
	# Isolate the lion bonus: base festival honor 0.0.
	var h: float = _worship_honor("Lion", true, 0.0)
	_ok(is_equal_approx(h, 0.1), "Lion + lion_honor festival -> honor_change == 0.1 (was 0.0 dead)")


func _test_non_lion_and_no_festival() -> void:
	print("[2] the bonus is Lion-only and festival-gated")
	_ok(is_equal_approx(_worship_honor("Crane", true, 0.0), 0.0),
		"non-Lion (Crane) during lion_honor festival -> no bonus (0.0)")
	_ok(is_equal_approx(_worship_honor("Lion", false, 0.0), 0.0),
		"Lion with no lion_honor festival active -> no bonus (0.0)")
	# Regression that the OLD lowercase literal is truly gone: a clan literally stored "lion"
	# would be a non-canonical value; the canonical "Lion" is what must match.
	_ok(is_equal_approx(_worship_honor("lion", true, 0.0), 0.0),
		"a lowercase 'lion' clan (non-canonical) does NOT match -> 0.0 (fix keys on canonical 'Lion')")


func _test_stacks_with_base() -> void:
	print("[3] the lion bonus stacks on top of the base festival honor gain")
	# Base festival honor 0.2 (e.g. co-occurring honor_gain festival) + lion 0.1 = 0.3.
	_ok(is_equal_approx(_worship_honor("Lion", true, 0.2), 0.3),
		"Lion + base 0.2 + lion 0.1 -> 0.3")
	_ok(is_equal_approx(_worship_honor("Crane", true, 0.2), 0.2),
		"non-Lion keeps only the base 0.2 (no lion bonus)")
