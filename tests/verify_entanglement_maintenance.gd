extends SceneTree
## Runtime driver for routing re-seduction of an existing entanglement through the dormant
## SeductionSystem.maintain_entanglement arbiter (s12.8 line 273, LOCKED: "Contact that resets
## the maintenance window: any Seduction ActionID (any of the five) targeting the same person").
## Before this fix, _process_seduction_entanglements treated a re-seduction against an existing
## non-broken entanglement as a duplicate to SKIP -- so entanglements could only ever decay
## (check_maintenance) and never be maintained, and maintain_entanglement had ZERO callers.
## Verifies: a re-seduction refreshes an active/neglected entanglement (state ACTIVE, missed
## windows 0, window reset) WITHOUT creating a duplicate; a new target creates a fresh
## entanglement; a BROKEN entanglement does not block a fresh one; a failed/non-creating result
## does nothing.
## Run: godot --headless -s tests/verify_entanglement_maintenance.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _S := preload("res://simulation/seduction_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _seduce(seducer: int, target: int, creates: bool = true, success: bool = true) -> Dictionary:
	return {
		"action_id": "SEDUCE_FOR_INFO", "success": success,
		"character_id": seducer, "target_npc_id": target,
		"effects": {"creates_entanglement": creates},
	}


func _ent(seducer: int, target: int, state: int, last_maintained: int, missed: int) -> Dictionary:
	return {
		"seducer_id": seducer, "target_id": target, "state": state,
		"created_ic_day": 0, "last_maintained_ic_day": last_maintained,
		"missed_windows": missed, "variant": _S.SeductionVariant.SEDUCE,
	}


func _run(results: Array, ents: Array, ic_day: int) -> void:
	_DO._process_seduction_entanglements(results, ents, ic_day, {})


func _letter(sender: int, recipient: int, sent: int) -> LetterData:
	var l := LetterData.new()
	l.sender_id = sender
	l.recipient_id = recipient
	l.ic_day_sent = sent
	return l


func _init() -> void:
	print("--- Entanglement Maintenance via re-seduction + letter (s12.8 line 273) ---")
	_test_reseduce_maintains()
	_test_new_and_broken()
	_test_noops()
	_test_letter_maintenance()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_letter_maintenance() -> void:
	print("[4] a letter to the entangled target this tick resets the window")
	# A neglected entanglement (1 -> 2); a letter 1 -> 2 sent this tick maintains it.
	var ents: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_DO._maintain_entanglements_from_letters([_letter(1, 2, 50)], ents, 50)
	var e: Dictionary = ents[0]
	_ok(int(e.get("state", -1)) == _S.EntanglementState.ACTIVE, "letter -> state ACTIVE")
	_ok(int(e.get("missed_windows", -1)) == 0, "letter -> missed_windows reset")
	_ok(int(e.get("last_maintained_ic_day", -1)) == 50, "letter -> window reset to ic_day 50")

	# A letter sent on a PRIOR tick (ic_day_sent != ic_day) does NOT re-maintain.
	var ents2: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_DO._maintain_entanglements_from_letters([_letter(1, 2, 30)], ents2, 50)
	_ok(int((ents2[0] as Dictionary).get("missed_windows", -1)) == 2, "stale letter (prior tick) -> not maintained")

	# A letter to a DIFFERENT person does not maintain the entanglement.
	var ents3: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_DO._maintain_entanglements_from_letters([_letter(1, 9, 50)], ents3, 50)
	_ok(int((ents3[0] as Dictionary).get("missed_windows", -1)) == 2, "letter to a different person -> not maintained")

	# A letter never revives a BROKEN entanglement.
	var ents4: Array = [_ent(1, 2, _S.EntanglementState.BROKEN, 0, 3)]
	_DO._maintain_entanglements_from_letters([_letter(1, 2, 50)], ents4, 50)
	_ok(int((ents4[0] as Dictionary).get("state", -1)) == _S.EntanglementState.BROKEN, "letter does NOT revive a BROKEN entanglement")


func _test_reseduce_maintains() -> void:
	print("[1] re-seduction refreshes an existing entanglement (no duplicate)")
	# A neglected entanglement (2 missed windows, last maintained day 0); re-seduce on day 50.
	var ents: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_run([_seduce(1, 2)], ents, 50)
	_ok(ents.size() == 1, "no duplicate created (still 1 entanglement)")
	var e: Dictionary = ents[0]
	_ok(int(e.get("state", -1)) == _S.EntanglementState.ACTIVE, "state refreshed to ACTIVE")
	_ok(int(e.get("missed_windows", -1)) == 0, "missed_windows reset to 0")
	_ok(int(e.get("last_maintained_ic_day", -1)) == 50, "maintenance window reset to ic_day 50")


func _test_new_and_broken() -> void:
	print("[2] new target creates fresh; a BROKEN entanglement does not block a fresh one")
	# New target -> new entanglement.
	var ents: Array = [_ent(1, 2, _S.EntanglementState.ACTIVE, 40, 0)]
	_run([_seduce(1, 3)], ents, 50)
	_ok(ents.size() == 2, "seducing a new target creates a second entanglement")

	# Broken entanglement with target 4 -> a fresh SEDUCE creates a NEW (broken doesn't block).
	var ents2: Array = [_ent(1, 4, _S.EntanglementState.BROKEN, 0, 3)]
	_run([_seduce(1, 4)], ents2, 50)
	_ok(ents2.size() == 2, "broken entanglement does not block a fresh one (re-seduction allowed)")
	# The broken one is untouched (not revived); the new one is ACTIVE.
	var active_count: int = 0
	var broken_count: int = 0
	for ent_v: Variant in ents2:
		var st: int = int((ent_v as Dictionary).get("state", -1))
		if st == _S.EntanglementState.ACTIVE:
			active_count += 1
		elif st == _S.EntanglementState.BROKEN:
			broken_count += 1
	_ok(active_count == 1 and broken_count == 1, "old broken stays broken, new one is ACTIVE")


func _test_noops() -> void:
	print("[3] failed / non-creating results do not maintain")
	# Failed seduction -> no maintenance (entanglement untouched).
	var ents: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_run([_seduce(1, 2, true, false)], ents, 50)
	_ok(int((ents[0] as Dictionary).get("missed_windows", -1)) == 2, "failed seduce -> not maintained")

	# Success but no creates_entanglement effect -> no maintenance.
	var ents2: Array = [_ent(1, 2, _S.EntanglementState.NEGLECTED, 0, 2)]
	_run([_seduce(1, 2, false, true)], ents2, 50)
	_ok(int((ents2[0] as Dictionary).get("missed_windows", -1)) == 2, "no creates_entanglement -> not maintained")
