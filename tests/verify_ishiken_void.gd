extends SceneTree
## Runtime driver for the Isawa Ishiken / Void-spell gate wire (s37:3 LOCKED).
##
## s37:3 (LOCKED): "Void spells are only castable by ishiken -- shugenja with the Ishiken-do
## Advantage." But SpellSystem.can_cast gated Void spells on the SCHOOL STRING "Isawa Ishiken",
## and NOBODY was ever granted ISHIKEN_DO (the grant in AdvantageSystem.assign_derived_advantages
## keyed on the same never-generated school string). The Phoenix Master of Void -- canonically an
## ishiken (one per game) -- was generated with a generic Isawa school + no void spells, so the
## whole Void-spell layer was dead: no NPC could ever cast a Void spell.
##
## FIX (owner-approved "Master of Void only"): (1) can_cast now gates on the ISHIKEN_DO advantage
## (school string kept as a backward-compat OR-fallback); (2) assign_derived_advantages grants
## ISHIKEN_DO to the "Master of Void" role_position; (3) the Master of Void is given the Isawa
## Ishiken starting Void spells at generation. No invented values -- the ISHIKEN_DO gate is the
## LOCKED s37 rule, the starting spell set is the shipped STARTING_SPELLS["Isawa Ishiken"].
## Run: godot --headless -s tests/verify_ishiken_void.gd

const _SS := preload("res://simulation/spell_system.gd")
const _AS := preload("res://simulation/advantage_system.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _ADV := preload("res://shared/advantage_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A rank-5 shugenja with a healthy Void ring who KNOWS a Void spell (but no advantage yet).
func _mk_shugenja(id: int, school: String = "Isawa Shugenja") -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school = school
	c.school_type = Enums.SchoolType.SHUGENJA
	c.insight_rank = 5
	c.void_ring = 3
	c.spells_known = ["sense_void"]  # e:4 (Void), m:1, i:true
	return c


func _grant_ishiken(c: L5RCharacterData) -> void:
	var adv: AdvantageData = _ADV.new()
	adv.advantage_type = Enums.Advantage.ISHIKEN_DO
	c.advantages.append(adv)


func _init() -> void:
	print("--- Isawa Ishiken / Void-spell gate (s37:3) ---")
	_test_cast_gate_on_advantage()
	_test_school_fallback()
	_test_master_of_void_grant()
	_test_end_to_end_master_of_void()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_cast_gate_on_advantage() -> void:
	print("[1] can_cast(void spell): gated on the ISHIKEN_DO advantage")
	var non_ishiken: L5RCharacterData = _mk_shugenja(1)  # Isawa Shugenja, no advantage
	_ok(not _SS.can_cast(non_ishiken, "sense_void"),
		"a plain shugenja (no ISHIKEN_DO, not Ishiken school) CANNOT cast a Void spell")

	var ishiken: L5RCharacterData = _mk_shugenja(2)
	_grant_ishiken(ishiken)
	_ok(_SS.can_cast(ishiken, "sense_void"),
		"the same shugenja WITH ISHIKEN_DO granted CAN cast the Void spell")

	# A non-Void (elemental) spell is unaffected by the gate: a plain shugenja who knows it can cast.
	non_ishiken.spells_known = ["jade_strike"]  # e:1 (Earth), not i:true
	_ok(_SS.can_cast(non_ishiken, "jade_strike"),
		"a non-Void spell is NOT blocked for a non-ishiken (gate is Void-only)")


func _test_school_fallback() -> void:
	print("[2] backward-compat: the Isawa Ishiken school string still qualifies (no advantage)")
	var by_school: L5RCharacterData = _mk_shugenja(3, "Isawa Ishiken")  # school string, no advantage
	_ok(not _AS.has_advantage(by_school, Enums.Advantage.ISHIKEN_DO),
		"fixture has no ISHIKEN_DO advantage (isolates the fallback)")
	_ok(_SS.can_cast(by_school, "sense_void"),
		"a legacy 'Isawa Ishiken' school character can still cast Void spells (OR-fallback)")

	var by_path: L5RCharacterData = _mk_shugenja(4)
	by_path.school_paths = ["Isawa Ishiken"]
	_ok(_SS.can_cast(by_path, "sense_void"),
		"the school_paths fallback also qualifies")


func _test_master_of_void_grant() -> void:
	print("[3] assign_derived_advantages grants ISHIKEN_DO to the Master of Void role")
	var mov: L5RCharacterData = _mk_shugenja(5, "Isawa Shugenja")  # generic Isawa school
	mov.role_position = "Master of Void"
	_ok(not _AS.has_advantage(mov, Enums.Advantage.ISHIKEN_DO), "pre: no advantage yet")
	_AS.assign_derived_advantages(mov, [], {})
	_ok(_AS.has_advantage(mov, Enums.Advantage.ISHIKEN_DO),
		"Master of Void (any Isawa school) is granted ISHIKEN_DO")

	# A different Isawa Master (e.g. Master of Fire) is NOT granted it.
	var mof: L5RCharacterData = _mk_shugenja(6, "Isawa Shugenja")
	mof.role_position = "Master of Fire"
	_AS.assign_derived_advantages(mof, [], {})
	_ok(not _AS.has_advantage(mof, Enums.Advantage.ISHIKEN_DO),
		"a non-Void Master (Master of Fire) is NOT an ishiken")


func _test_end_to_end_master_of_void() -> void:
	print("[4] end-to-end: a generated-style Master of Void KNOWS + CAN cast Void spells")
	# Mirror the world-gen block: generic Isawa school, Void spells assigned via the Ishiken set,
	# then the advantage-derive pass grants ISHIKEN_DO by role.
	var mov: L5RCharacterData = _CHAR.new()
	mov.character_id = 7
	mov.school = "Isawa Shugenja"
	mov.school_type = Enums.SchoolType.SHUGENJA
	mov.insight_rank = 5
	mov.void_ring = 3
	mov.role_position = "Master of Void"
	mov.spells_known = ["sense", "commune", "summon", "command"]  # base Isawa set
	_SS.assign_starting_spells(mov, "Isawa Ishiken")  # append the Void starting spells
	_AS.assign_derived_advantages(mov, [], {})

	_ok("sense_void" in mov.spells_known, "Master of Void now KNOWS a Void spell (sense_void)")
	_ok(_AS.has_advantage(mov, Enums.Advantage.ISHIKEN_DO), "Master of Void has ISHIKEN_DO")
	_ok(_SS.can_cast(mov, "sense_void"), "Master of Void CAN cast a Void spell end-to-end")

	# Contrast: a plain Isawa Shugenja with the same rank/ring but NO void spell + NO advantage.
	var plain: L5RCharacterData = _CHAR.new()
	plain.character_id = 8
	plain.school = "Isawa Shugenja"
	plain.school_type = Enums.SchoolType.SHUGENJA
	plain.insight_rank = 5
	plain.void_ring = 3
	plain.spells_known = ["sense", "commune", "summon", "command"]
	_AS.assign_derived_advantages(plain, [], {})
	_ok(not _AS.has_advantage(plain, Enums.Advantage.ISHIKEN_DO),
		"a plain Isawa Shugenja is NOT an ishiken")
	_ok(not _SS.can_cast(plain, "sense_void"),
		"a plain Isawa Shugenja CANNOT cast a Void spell (doesn't know it + no advantage)")
