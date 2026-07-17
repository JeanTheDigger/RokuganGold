extends SceneTree
## Runtime driver for the school_name/school_rank dead-field fix (2nd batch of the 2026-06-12
## school_name migration). school_name was NEVER written (always "") yet 6 production readers used
## it; school_rank was never initialized at generation (stale 1 until the first advancement tick
## self-healed it, spamming rank-up topics). Both broke gates that read them from world-start:
## the APPLY_TATTOO ability gate (>=3), the decorative-slot gate, kata Mirumoto/Kakita reduction,
## and Kolat T1 criteria (>=5/4). Verifies generate_character now sets school_rank == insight_rank
## and the fixed readers work off the canonical .school.
## Run: godot --headless -s tests/verify_school_field_fix.gd

const _WG := preload("res://simulation/world_generator.gd")
const _TS := preload("res://simulation/tattoo_system.gd")
const _KS := preload("res://simulation/kata_system.gd")
const _DICE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _dice(s: int) -> DiceEngine:
	var d: DiceEngine = _DICE.new()
	d.set_seed(s)
	return d


func _init() -> void:
	print("--- school_name/school_rank dead-field fix ---")
	_test_school_rank_init()
	_test_ability_gate()
	_test_kata_reduction()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_school_rank_init() -> void:
	print("[1] generate_character sets school_rank == insight_rank (was stale 1)")
	for rank in [1, 3, 5]:
		var c: L5RCharacterData = _WG.generate_character(
			10 + rank, "Test", "Dragon", "Togashi", "Togashi Tattooed Order", rank, _dice(rank),
		)
		_ok(c != null and c.school == "Togashi Tattooed Order", "rank %d: school string set" % rank)
		_ok(c != null and c.school_rank == c.insight_rank, "rank %d: school_rank == insight_rank (%d/%d)" % [rank, c.school_rank, c.insight_rank])
		_ok(c != null and c.school_rank >= 1, "rank %d: school_rank not stale-1-below-insight" % rank)
	# The dead field itself is untouched (never written) -- proving the fix reads .school, not it.
	var e: L5RCharacterData = _WG.generate_character(99, "T", "Dragon", "Togashi", "Togashi Tattooed Order", 3, _dice(1))
	_ok(e.school_name == "", "school_name remains the never-written dead field")


func _test_ability_gate() -> void:
	print("[2] APPLY_TATTOO ability gate: a computed-Rank-3+ Togashi elder now passes (was always false)")
	# NOTE the generation param is NOT the resulting rank -- get_insight_rank recomputes from
	# rings/skills, so a param-5 Togashi computes to Rank 4 (>=3, a granting elder). We assert on
	# the COMPUTED school_rank (what the fix syncs), not the param.
	var elder: L5RCharacterData = _WG.generate_character(
		200, "Elder", "Dragon", "Togashi", "Togashi Tattooed Order", 5, _dice(7),
	)
	_ok(elder.school_rank >= 3, "the param-5 Togashi computes to a granting rank (%d)" % elder.school_rank)
	# The exact gate the executor calls (action_executor:6371), now off .school + live school_rank.
	_ok(_TS.can_apply_ability_tattoo(elder.school, elder.school_rank, true),
		"computed-Rank-3+ Togashi elder in Togashi territory CAN grant an ability tattoo")
	_ok(not _TS.can_apply_ability_tattoo(elder.school, elder.school_rank, false),
		"same elder OUTSIDE Togashi territory cannot (territory gate)")
	# Pre-fix, school_name="" made is_togashi_school("") false -> gate always failed regardless.
	_ok(not _TS.can_apply_ability_tattoo(elder.school_name, elder.school_rank, true),
		"the dead school_name path would still fail (proving the field WAS the bug)")
	# A junior Togashi (computed rank < 3) cannot grant (rank gate).
	var junior: L5RCharacterData = _WG.generate_character(
		201, "Junior", "Dragon", "Togashi", "Togashi Tattooed Order", 1, _dice(8),
	)
	_ok(junior.school_rank < 3, "param-1 Togashi computes below the granting rank (%d)" % junior.school_rank)
	_ok(not _TS.can_apply_ability_tattoo(junior.school, junior.school_rank, true),
		"junior Togashi cannot grant an ability tattoo (rank < 3)")
	# A non-Togashi legendary artisan cannot.
	var kaiu: L5RCharacterData = _WG.generate_character(
		202, "Kaiu", "Crab", "Kaiu", "Kaiu Engineer", 5, _dice(9),
	)
	_ok(not _TS.can_apply_ability_tattoo(kaiu.school, kaiu.school_rank, true),
		"non-Togashi artisan cannot grant an ability tattoo")


func _test_kata_reduction() -> void:
	print("[3] kata Mirumoto/Kakita ring reduction: now fires off .school (was dead)")
	var miru: L5RCharacterData = _WG.generate_character(
		300, "M", "Dragon", "Mirumoto", "Mirumoto Bushi", 2, _dice(3),
	)
	_ok(_KS._has_mirumoto_kakita_reduction(miru), "Mirumoto Bushi qualifies for the ring reduction")
	var kakita: L5RCharacterData = _WG.generate_character(
		301, "K", "Crane", "Kakita", "Kakita Bushi", 2, _dice(4),
	)
	_ok(_KS._has_mirumoto_kakita_reduction(kakita), "Kakita Bushi qualifies")
	var akodo: L5RCharacterData = _WG.generate_character(
		302, "A", "Lion", "Akodo", "Akodo Bushi", 2, _dice(5),
	)
	_ok(not _KS._has_mirumoto_kakita_reduction(akodo), "Akodo Bushi does NOT (control)")
