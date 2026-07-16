extends SceneTree
## Runtime driver for the owner-approved shugenja starting-spell curriculum patch.
##
## The spell EFFECT writebacks for PURIFY_AREA / REMOVE_TAINT / HEAL_WOUNDS / SPIRIT_BIND were wired
## end-to-end (selection -> resolve_cast -> writeback) but PERMANENTLY DORMANT: no shugenja's starting
## spell set contained a spell of those effects, so get_best_spell_by_effect always returned "" and the
## writeback arms never fired. FIX (owner-approved "minimal curriculum patch"): Kuni Shugenja learn
## purge_the_taint (PURIFY), tomb_of_jade (REMOVE_TAINT), bonds_of_ningen_do (SPIRIT_BIND) -- all Earth,
## their canonical anti-Shadowlands role -- and Iuchi Shugenja learn regrow_the_wound (HEAL, Water).
## Plus get_best_spell_by_effect now gates on can_cast so a junior caster who KNOWS but cannot yet cast
## an ML3/ML4 effect spell falls through to a castable fallback instead of attempting an uncastable ritual.
## Run: godot --headless -s tests/verify_shugenja_curriculum.gd

const _SS := preload("res://simulation/spell_system.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A shugenja whose rings all support casting; rank tunable. Earth = min(stamina,willpower),
# Water = min(strength,perception), so ring 3 gives 3 daily slots on those elements.
func _mk(id: int, rank: int, school: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school = school
	c.school_type = Enums.SchoolType.SHUGENJA
	c.insight_rank = rank
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.spells_known = []
	_SS.assign_starting_spells(c, school)  # populate from the real curriculum table
	return c


func _init() -> void:
	print("--- shugenja starting-spell curriculum patch ---")
	_test_kuni_curriculum()
	_test_iuchi_curriculum()
	_test_can_cast_gate()
	_test_ml1_preserved()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_kuni_curriculum() -> void:
	print("[1] Kuni Shugenja now start knowing the Earth Taint/bind spells")
	var kuni: L5RCharacterData = _mk(1, 5, "Kuni Shugenja")
	_ok("purge_the_taint" in kuni.spells_known, "Kuni knows purge_the_taint (PURIFY_AREA)")
	_ok("tomb_of_jade" in kuni.spells_known, "Kuni knows tomb_of_jade (REMOVE_TAINT)")
	_ok("bonds_of_ningen_do" in kuni.spells_known, "Kuni knows bonds_of_ningen_do (SPIRIT_BIND)")
	# The original set is preserved.
	_ok("jade_strike" in kuni.spells_known and "jurojins_balm" in kuni.spells_known,
		"the original Kuni spells are preserved")


func _test_iuchi_curriculum() -> void:
	print("[2] Iuchi Shugenja now start knowing the Water heal spell")
	var iuchi: L5RCharacterData = _mk(2, 5, "Iuchi Shugenja")
	_ok("regrow_the_wound" in iuchi.spells_known, "Iuchi knows regrow_the_wound (HEAL_WOUNDS)")
	_ok("speed_of_the_waterfall" in iuchi.spells_known, "the original Iuchi spells are preserved")
	# A different Water school does NOT get the heal spell (the assignment is Iuchi-scoped).
	var kitsu: L5RCharacterData = _mk(3, 5, "Kitsu Shugenja")
	_ok(not ("regrow_the_wound" in kitsu.spells_known), "Kitsu does NOT get regrow_the_wound")


func _test_can_cast_gate() -> void:
	print("[3] the production selectors (castable variant) surface an effect spell only when castable")
	# get_best_spell_by_effect stays a PURE library query (highest-ML known, castability-agnostic):
	# a rank-1 Kuni still 'knows' purge_the_taint via the pure query.
	var junior_pure: L5RCharacterData = _mk(9, 1, "Kuni Shugenja")
	_ok(_SS.get_best_spell_by_effect(junior_pure, _SS.SpellSimEffect.PURIFY_AREA) == "purge_the_taint",
		"pure get_best_spell_by_effect is castability-agnostic (returns the known spell)")

	# A senior Kuni (Rank 5) can cast the ML3/ML4 effect spells -> the castable selectors return them.
	var senior: L5RCharacterData = _mk(10, 5, "Kuni Shugenja")
	_ok(_SS.get_best_purify_spell(senior) == "purge_the_taint", "senior Kuni: PURIFY -> purge_the_taint")
	_ok(_SS.get_best_taint_removal_spell(senior) == "tomb_of_jade", "senior Kuni: REMOVE_TAINT -> tomb_of_jade")
	_ok(_SS.get_best_castable_spell_by_effect(senior, _SS.SpellSimEffect.SPIRIT_BIND) == "bonds_of_ningen_do",
		"senior Kuni: SPIRIT_BIND -> bonds_of_ningen_do")

	# A junior Kuni (Rank 1) KNOWS them but cannot cast (rank < ml) -> the castable selectors return "".
	var junior: L5RCharacterData = _mk(11, 1, "Kuni Shugenja")
	_ok(_SS.get_best_purify_spell(junior) == "",
		"junior Kuni (rank 1): purge_the_taint (ML3) not castable -> '' (falls through)")
	_ok(_SS.get_best_taint_removal_spell(junior) == "",
		"junior Kuni (rank 1): tomb_of_jade (ML4) not castable -> ''")

	# A Rank-3 Kuni can cast purge (ML3) but not tomb (ML4): PURIFY selectable, REMOVE_TAINT not.
	var mid: L5RCharacterData = _mk(12, 3, "Kuni Shugenja")
	_ok(_SS.get_best_purify_spell(mid) == "purge_the_taint", "rank-3 Kuni: purge_the_taint (ML3) IS castable")
	_ok(_SS.get_best_taint_removal_spell(mid) == "", "rank-3 Kuni: tomb_of_jade (ML4) not yet castable -> ''")

	# Iuchi heal spell: senior selects it, junior falls through.
	var iuchi5: L5RCharacterData = _mk(13, 5, "Iuchi Shugenja")
	var iuchi1: L5RCharacterData = _mk(14, 1, "Iuchi Shugenja")
	_ok(_SS.get_best_healing_spell(iuchi5) == "regrow_the_wound", "senior Iuchi: HEAL -> regrow_the_wound")
	_ok(_SS.get_best_healing_spell(iuchi1) == "", "junior Iuchi (rank 1): regrow_the_wound (ML3) not castable -> ''")


func _test_ml1_preserved() -> void:
	print("[4] behavior-preserving for the pre-existing ML1 effect spells")
	# sense (DETECT_PRESENCE, ML1) is castable at Rank 1 -> still selected (no regression).
	var r1: L5RCharacterData = _mk(20, 1, "Kuni Shugenja")
	_ok(_SS.get_best_detection_spell(r1) == "sense",
		"rank-1 shugenja: DETECT_PRESENCE -> sense (ML1, castable, unchanged)")
	# A RITUAL_HONOR ML1 starting spell is still surfaced at Rank 1 (Moshi: gift_of_amaterasu).
	var moshi: L5RCharacterData = _mk(21, 1, "Moshi Shugenja")
	var rh: String = _SS.get_best_ritual_spell(moshi)
	_ok(rh != "", "rank-1 Moshi: a RITUAL_HONOR ML1 spell is still selected (%s)" % rh)
