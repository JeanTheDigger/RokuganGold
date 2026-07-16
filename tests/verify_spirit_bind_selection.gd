extends SceneTree
## Runtime driver for the SPIRIT_BIND ritual-selection wire (s56.16 / s34).
##
## The SPIRIT_BIND effect writeback (day_orchestrator ~34047) suppresses one matching, active
## REALM_OVERLAP spiritual-insurgency event at the caster's province when a shugenja casts a
## binding spell (bonds_of_ningen_do / freedom_of_the_air). But the writeback was PERMANENTLY
## DORMANT: the NPC ritual-selection block never chose a SPIRIT_BIND spell (no `spiritual_overlap`
## context existed, and no selection branch read it), so `ritual_spell_id` was never a binding
## spell and the arm never fired -- even after the curriculum patch stocked bonds_of_ningen_do on
## the Kuni.
##
## FIX (structural wire, no invented values): (1) _inject_base_character_context builds
## `spiritual_overlap_province_ids` from the active unresolved REALM_OVERLAP events and injects it
## per-character; (2) ContextSnapshot + build_context carry it; (3) the PERFORM_RITUAL selection
## adds a SPIRIT_BIND branch (below Taint, above ritual-honor) via get_best_castable_spell_by_effect.
## The realm-specific matching + graceful no-op remain in the writeback (find_bindable_spirit_event).
## Run: godot --headless -s tests/verify_spirit_bind_selection.gd

const _NPC := preload("res://simulation/npc_decision_engine.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")
const _SS := preload("res://simulation/spell_system.gd")
const _NDS := preload("res://simulation/npc_data_structures.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _SEV := preload("res://shared/spiritual_insurgency_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A Kuni shugenja whose Earth ring supports casting; rank tunable.
func _mk_kuni(id: int, rank: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = "Crab"
	c.school = "Kuni Shugenja"
	c.school_type = Enums.SchoolType.SHUGENJA
	c.insight_rank = rank
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.spells_known = []
	_SS.assign_starting_spells(c, "Kuni Shugenja")
	return c


func _mk_event(pid: int, etype: Enums.SpiritualEventType, realm: Enums.SpiritRealm, resolved: bool) -> SpiritualInsurgencyData:
	var e: SpiritualInsurgencyData = _SEV.new()
	e.province_id = pid
	e.event_type = etype
	e.realm = realm
	e.resolved = resolved
	return e


# A PERFORM_RITUAL option/need with the given ctx, run through the real _populate_action_metadata.
func _select_ritual(character: L5RCharacterData, overlap_ids: Array, taint_ids: Array) -> String:
	var opt: NPCDataStructures.ScoredAction = _NDS.ScoredAction.new()
	opt.action_id = "PERFORM_RITUAL"
	var need: NPCDataStructures.ImmediateNeed = _NDS.ImmediateNeed.new()
	need.need_type = "PERFORM_RITUAL"
	var ctx: NPCDataStructures.ContextSnapshot = _NDS.ContextSnapshot.new()
	ctx.character_id = character.character_id
	ctx.spiritual_overlap_province_ids = overlap_ids
	ctx.taint_topic_province_ids = taint_ids
	_NPC._populate_action_metadata(opt, need, ctx, character)
	return opt.metadata.get("ritual_spell_id", "")


func _init() -> void:
	print("--- SPIRIT_BIND ritual-selection wire (s56.16) ---")
	_test_selection_helper()
	_test_builder_end_to_end()
	_test_context_plumbing()
	_test_ritual_selection()
	_test_writeback_matcher()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_selection_helper() -> void:
	print("[1] get_best_castable_spell_by_effect(SPIRIT_BIND) for the Kuni curriculum")
	var kuni5: L5RCharacterData = _mk_kuni(1, 5)
	_ok("bonds_of_ningen_do" in kuni5.spells_known, "Kuni knows bonds_of_ningen_do")
	_ok(_SS.get_best_castable_spell_by_effect(kuni5, _SS.SpellSimEffect.SPIRIT_BIND) == "bonds_of_ningen_do",
		"senior Kuni: SPIRIT_BIND -> bonds_of_ningen_do (ML3, castable)")
	var kuni1: L5RCharacterData = _mk_kuni(2, 1)
	_ok(_SS.get_best_castable_spell_by_effect(kuni1, _SS.SpellSimEffect.SPIRIT_BIND) == "",
		"junior Kuni (rank 1): bonds_of_ningen_do (ML3) not castable -> ''")


func _test_builder_end_to_end() -> void:
	print("[2] _inject_base_character_context builds + injects spiritual_overlap_province_ids")
	var kuni: L5RCharacterData = _mk_kuni(10, 5)
	var world_states: Dictionary = {kuni.character_id: {}}
	var events: Array = [
		_mk_event(5, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO, false),   # counts
		_mk_event(5, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.SAKKAKU, false),   # dup province
		_mk_event(7, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.TOSHIGOKU, true),  # resolved -> skip
		_mk_event(8, Enums.SpiritualEventType.ELEMENTAL_IMBALANCE, Enums.SpiritRealm.GAKI_DO, false),  # wrong type
		_mk_event(9, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.YUME_DO, false),   # counts
	]
	# Full positional call through the (now 17-param) injector; everything but characters,
	# world_states and the events is empty/default.
	_DO._inject_base_character_context(
		world_states, [kuni], [], [], [], {}, [],
		0, 0, {}, [], {}, [], {}, [], [], events)
	var injected: Array = world_states[kuni.character_id].get("spiritual_overlap_province_ids", [])
	_ok(5 in injected and 9 in injected, "both active REALM_OVERLAP provinces (5, 9) are present")
	_ok(not (7 in injected), "a RESOLVED overlap province (7) is excluded")
	_ok(not (8 in injected), "an ELEMENTAL_IMBALANCE province (8) is excluded (wrong event type)")
	_ok(injected.count(5) == 1, "the duplicate province (5) is deduped")


func _test_context_plumbing() -> void:
	print("[3] build_context reads spiritual_overlap_province_ids into the snapshot")
	var kuni: L5RCharacterData = _mk_kuni(20, 5)
	var ws: Dictionary = {"spiritual_overlap_province_ids": [3, 4]}
	var ctx: NPCDataStructures.ContextSnapshot = _NPC.build_context(kuni, ws)
	_ok(ctx.spiritual_overlap_province_ids == [3, 4],
		"ctx.spiritual_overlap_province_ids mirrors the injected value")
	# default when absent
	var ctx2: NPCDataStructures.ContextSnapshot = _NPC.build_context(kuni, {})
	_ok(ctx2.spiritual_overlap_province_ids.is_empty(), "defaults to empty when unset")


func _test_ritual_selection() -> void:
	print("[4] PERFORM_RITUAL selection prefers a binding spell on an active overlap")
	var kuni5: L5RCharacterData = _mk_kuni(30, 5)
	# Overlap active, no taint -> SPIRIT_BIND selected.
	_ok(_select_ritual(kuni5, [5], []) == "bonds_of_ningen_do",
		"senior Kuni + overlap + no taint -> bonds_of_ningen_do")
	# Taint AND overlap -> Taint wins (purify is graver; bonds excludes Jigoku anyway).
	_ok(_select_ritual(kuni5, [5], [5]) == "purge_the_taint",
		"senior Kuni + taint + overlap -> purge_the_taint (Taint takes precedence)")
	# No overlap -> SPIRIT_BIND NOT selected; falls through (Kuni has no ritual-honor spell -> detection).
	_ok(_select_ritual(kuni5, [], []) != "bonds_of_ningen_do",
		"senior Kuni + NO overlap -> does NOT pick bonds_of_ningen_do")
	# Junior Kuni + overlap -> bonds not castable -> falls through (not bonds).
	var kuni1: L5RCharacterData = _mk_kuni(31, 1)
	_ok(_select_ritual(kuni1, [5], []) != "bonds_of_ningen_do",
		"junior Kuni (rank 1) + overlap -> falls through (bonds not castable)")


func _test_writeback_matcher() -> void:
	print("[5] find_bindable_spirit_event matches the caster's province + realm (writeback end)")
	var events: Array = [
		_mk_event(5, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO, false),
	]
	var hit: SpiritualInsurgencyData = _SS.find_bindable_spirit_event("bonds_of_ningen_do", 5, events)
	_ok(hit != null and hit.province_id == 5, "bonds_of_ningen_do binds the GAKI_DO overlap at province 5")
	# Wrong province -> no-op (graceful).
	_ok(_SS.find_bindable_spirit_event("bonds_of_ningen_do", 6, events) == null,
		"no matching event at a different province -> null (graceful no-op)")
	# Shadowlands/Jigoku is NOT bindable by bonds_of_ningen_do (s34 exclusion).
	var jigoku: Array = [_mk_event(5, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.JIGOKU, false)]
	_ok(_SS.find_bindable_spirit_event("bonds_of_ningen_do", 5, jigoku) == null,
		"bonds_of_ningen_do does NOT bind a JIGOKU overlap (Shadowlands excluded)")
