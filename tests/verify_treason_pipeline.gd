extends SceneTree
## Runtime driver for the s11.3.8 treason upstream (detection signals → evidence
## → accusation) and its handoff to the already-wired ConvictionProcessor
## (hearing → conviction/acquittal) + the Signal-5 co-conspirator naming.
## Run: godot --headless -s tests/verify_treason_pipeline.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(id: int, name: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.clan = "Scorpion"
	c.status = 3.0
	return c


func _lord(id: int) -> L5RCharacterData:
	var c := _char(id, "Lord%d" % id)
	c.status = 6.0
	return c


func _traitor(id: int, lord_id: int) -> L5RCharacterData:
	var c := _char(id, "Traitor%d" % id)
	c.kolat_sect = Enums.KolatSect.SILK
	c.lord_id = lord_id
	return c


func _disp_intel(vassal_id: int, toward_id: int, disp: int) -> KnowledgeEntry:
	var ke := KnowledgeEntry.new()
	ke.source = Enums.KnowledgeSource.INTELLIGENCE
	ke.entry_type = "disposition_toward"
	ke.data = {"target_character_id": vassal_id, "toward_character_id": toward_id, "disposition": disp}
	return ke


func _init() -> void:
	print("--- Treason Pipeline Verification (s11.3.8) ---")
	_test_truth_gate()
	_test_signal_accumulation()
	_test_accusation_and_conviction()
	_test_coconspirator_naming()
	_test_acquittal_shield()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_truth_gate() -> void:
	print("[1] truth layer: only conscious lord-bound Kolat qualify")
	var lord := _lord(1)
	var by_id: Dictionary = {1: lord}
	var loyal := _char(2, "Loyal")
	loyal.lord_id = 1
	by_id[2] = loyal
	var traitor := _traitor(3, 1)
	by_id[3] = traitor
	var lordless := _char(4, "Lordless")
	lordless.kolat_sect = Enums.KolatSect.COIN
	by_id[4] = lordless
	var sleeper := _char(5, "Sleeper")
	sleeper.lord_id = 1
	sleeper.trigger_phrase = "the crane flies south"  # dormant sleeper, sect NONE
	by_id[5] = sleeper
	_ok(not _DO._is_conscious_kolat_traitor(loyal, by_id), "loyal vassal excluded")
	_ok(_DO._is_conscious_kolat_traitor(traitor, by_id), "conscious Silk agent with a lord qualifies")
	_ok(not _DO._is_conscious_kolat_traitor(lordless, by_id), "lordless Kolat excluded (no lord to betray)")
	_ok(not _DO._is_conscious_kolat_traitor(sleeper, by_id), "dormant sleeper excluded (unwitting)")
	# No signals → the seasonal pass creates nothing even for a real traitor.
	var records: Array = []
	var res: Array = _DO._process_treason_signals([traitor], by_id, records, [100], {}, 90)
	_ok(res.is_empty() and records.is_empty(), "no observable signal → no record, no case (treason is silent)")


func _test_signal_accumulation() -> void:
	print("[2] signals accumulate LOCKED weights; investigation opens on first signal")
	var lord := _lord(10)
	var traitor := _traitor(11, 10)
	var enemy := _char(12, "LordEnemy")
	var by_id: Dictionary = {10: lord, 11: traitor, 12: enemy}
	# Lord holds enemy at Enemy tier; lord's intel shows the vassal Friend+ toward them.
	lord.disposition_values[12] = -40
	lord.knowledge_pool.append(_disp_intel(11, 12, 45))
	# Lord-assigned objective stalled one season.
	var objectives: Dictionary = {11: {"primary": {"assigned_by": 10, "seasons_without_progress": 2}}}
	var records: Array = []
	var res: Array = _DO._process_treason_signals([traitor], by_id, records, [200], objectives, 90)
	_ok(records.size() == 1, "one TREASON CrimeRecord created")
	if records.size() == 1:
		var r: CrimeRecord = records[0]
		_ok(r.crime_type == Enums.CrimeType.TREASON and r.severity == Enums.CrimeSeverity.CAPITAL, "record is capital treason")
		_ok(r.victim_id == 10, "victim is the betrayed lord")
		_ok(r.legal_status == Enums.LegalStatus.UNDER_INVESTIGATION, "investigation opened")
		_ok(r.evidence_total == 13, "stall(5) + anomaly(8) = 13")
	_ok(res.size() == 2, "two signal results")
	# Second pass same season data: stall fires again (+5), anomaly deduped.
	var res2: Array = _DO._process_treason_signals([traitor], by_id, records, [200], objectives, 180)
	_ok(records.size() == 1, "no duplicate record")
	_ok(records[0].evidence_total == 18, "second stall +5 (18); anomaly pair deduped")
	_ok(res2.size() == 1, "only the stall fired on pass 2")


func _test_accusation_and_conviction() -> void:
	print("[3] threshold 40 → ACCUSED → ConvictionProcessor resolves")
	var lord := _lord(20)
	lord.bushido_virtue = Enums.BushidoVirtue.GI  # names co-conspirators publicly
	var traitor := _traitor(21, 20)
	traitor.honor = 1.0  # low honor → weak testimony
	var by_id: Dictionary = {20: lord, 21: traitor}
	var objectives: Dictionary = {21: {"primary": {"assigned_by": 20, "seasons_without_progress": 1}}}
	var records: Array = []
	# 8 seasons of stalling → 40 evidence → ACCUSED.
	var accused_at: int = -1
	for season: int in range(8):
		_DO._process_treason_signals([traitor], by_id, records, [300], objectives, 90 * (season + 1))
		if records.size() == 1 and records[0].legal_status == Enums.LegalStatus.ACCUSED and accused_at < 0:
			accused_at = season + 1
	_ok(accused_at == 8, "accused exactly when evidence reached 40 (8 stalls × 5)")
	# Once ACCUSED the seasonal pass stops adding (case is in the pipeline).
	_DO._process_treason_signals([traitor], by_id, records, [300], objectives, 900)
	_ok(records[0].evidence_total == 40, "no evidence added while ACCUSED")
	# ConvictionProcessor picks it up (3 days after accusation).
	var dice := DiceEngine.new()
	dice.set_seed(11)
	var topics: Array = []
	var conv: Array = ConvictionProcessor.process_accused_cases(
		records, by_id, dice, 1000, [9000], topics, {21: 20}
	)
	_ok(conv.size() == 1, "conviction pipeline processed the case")
	if conv.size() == 1:
		var outcome: String = str(conv[0].get("outcome", ""))
		# All three are valid resolutions: conviction, acquittal, or the accused
		# demanding trial by combat (resolved downstream by _resolve_pending_trials).
		_ok(outcome in ["convicted", "acquitted", "trial_by_combat_pending"],
			"hearing resolved (%s)" % outcome)


func _test_coconspirator_naming() -> void:
	print("[4] Signal 5: handler named publicly (+45) or kept in IntelDB")
	var lord := _lord(30)
	var handler_lord := _lord(35)
	var convicted := _traitor(31, 30)
	var handler := _traitor(32, 35)
	convicted.kolat_superior_id = 32
	var by_id: Dictionary = {30: lord, 31: convicted, 32: handler, 35: handler_lord}
	var records: Array = []
	# Public naming (GI lord → co_conspirators_named true, as ConvictionProcessor computes).
	var conv_results: Array = [{
		"outcome": "convicted", "crime_type": Enums.CrimeType.TREASON,
		"accused_id": 31, "co_conspirators_named": true,
	}]
	var res: Array = _DO._process_treason_coconspirator_naming(conv_results, records, by_id, [400], 500)
	_ok(res.size() == 1 and bool(res[0].get("named_publicly", false)), "handler named publicly")
	var hrec: CrimeRecord = _DO._find_treason_record(records, 32)
	_ok(hrec != null and hrec.legal_status == Enums.LegalStatus.ACCUSED, "handler immediately ACCUSED (45 >= 40)")
	_ok(hrec != null and hrec.evidence_total == 45, "co-conspirator testimony weight 45")
	# Private naming → lord gains a treason_suspect knowledge entry, no evidence.
	var convicted2 := _traitor(41, 30)
	convicted2.kolat_superior_id = 32
	by_id[41] = convicted2
	var records2: Array = []
	var conv2: Array = [{
		"outcome": "convicted", "crime_type": Enums.CrimeType.TREASON,
		"accused_id": 41, "co_conspirators_named": false,
	}]
	var res2: Array = _DO._process_treason_coconspirator_naming(conv2, records2, by_id, [450], 500)
	_ok(res2.size() == 1 and not bool(res2[0].get("named_publicly", true)), "kept private")
	_ok(records2.is_empty(), "no public evidence when kept private")
	var has_intel: bool = false
	for k: KnowledgeEntry in lord.knowledge_pool:
		if k.entry_type == "treason_suspect" and int(k.data.get("target_character_id", -1)) == 32:
			has_intel = true
	_ok(has_intel, "lord holds the treason_suspect intel entry")


func _test_acquittal_shield() -> void:
	print("[5] political shield: re-accusation needs +20 new evidence past the halved carry-over")
	var lord := _lord(50)
	var traitor := _traitor(51, 50)
	var by_id: Dictionary = {50: lord, 51: traitor}
	var records: Array = []
	# Build an acquitted record with halved evidence 25 (was 50).
	var record: CrimeRecord = _DO._ensure_treason_record(traitor, records, [500], 100)
	record.legal_status = Enums.LegalStatus.ACQUITTED
	record.evidence_total = 25
	# New signal after acquittal → NEW case seeded with the 25 carry-over.
	var objectives: Dictionary = {51: {"primary": {"assigned_by": 50, "seasons_without_progress": 1}}}
	_DO._process_treason_signals([traitor], by_id, records, [500], objectives, 200)
	_ok(record.legal_status == Enums.LegalStatus.UNDER_INVESTIGATION, "re-investigation opened after acquittal")
	_ok(record.evidence_total == 30, "carry-over 25 + stall 5 = 30")
	# 30 < 40 → not accused. Two more stalls → 40, but new-since-acquittal = 15 < 20 → still shielded.
	_DO._process_treason_signals([traitor], by_id, records, [500], objectives, 300)
	_DO._process_treason_signals([traitor], by_id, records, [500], objectives, 400)
	_ok(record.evidence_total == 40 and record.legal_status == Enums.LegalStatus.UNDER_INVESTIGATION,
		"40 total but only +15 new → shield holds")
	# One more (+5 → new evidence 20) → re-accusation allowed.
	_DO._process_treason_signals([traitor], by_id, records, [500], objectives, 500)
	_ok(record.legal_status == Enums.LegalStatus.ACCUSED, "+20 new evidence → re-accused")
