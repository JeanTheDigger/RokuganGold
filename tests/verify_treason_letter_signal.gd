extends SceneTree
## Runtime driver for the s11.3.8 INTERCEPTED_LETTER treason signal wired off
## letter interception (_process_intercept_letter_writebacks). An INTERCEPT_LETTER
## that surfaces correspondence between two conscious lord-bound Kolat conspirators
## adds INTERCEPTED_LETTER hard evidence (weight 50, LOCKED) to each conspirator's
## TREASON record -- 50 >= the accusation threshold 40, so a single network letter
## accuses. Deduped per letter_id; a one-Kolat-party or unreadable/ciphered letter
## adds nothing.
## Run: godot --headless -s tests/verify_treason_letter_signal.gd

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


func _letter(id: int, sender: int, recipient: int, topic: int) -> LetterData:
	var l := LetterData.new()
	l.letter_id = id
	l.sender_id = sender
	l.recipient_id = recipient
	l.topic = topic
	l.delivered = false
	return l


func _intercept_result(interceptor: int, target: int) -> Dictionary:
	return {
		"action_id": "INTERCEPT_LETTER",
		"success": true,
		"character_id": interceptor,
		"target_npc_id": target,
	}


func _init() -> void:
	print("--- INTERCEPTED_LETTER Treason Signal Verification (s11.3.8) ---")
	_test_both_kolat_accuses()
	_test_one_kolat_party_nothing()
	_test_dedup_no_double_count()
	_test_ciphered_unreadable_nothing()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_both_kolat_accuses() -> void:
	print("[1] both correspondents conscious Kolat traitors -> +50 to each, accused")
	var lord_a := _lord(1)
	var lord_b := _lord(2)
	var sender := _traitor(3, 1)     # conscious Silk agent, lord 1
	var recipient := _traitor(4, 2)  # conscious Silk agent, lord 2
	var interceptor := _char(5, "Spy")
	var by_id: Dictionary = {1: lord_a, 2: lord_b, 3: sender, 4: recipient, 5: interceptor}
	var pending: Array = [_letter(70, 3, 4, 9)]  # topic 9, Kolat network correspondence
	var results: Array = [_intercept_result(5, 3)]  # interceptor reads a letter to/from sender
	var records: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(7)
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [100], 90)

	var rec_s: CrimeRecord = _DO._find_treason_record(records, 3)
	var rec_r: CrimeRecord = _DO._find_treason_record(records, 4)
	_ok(rec_s != null and rec_r != null, "a TREASON record exists for both conspirators")
	_ok(rec_s != null and rec_s.crime_type == Enums.CrimeType.TREASON \
			and rec_s.severity == Enums.CrimeSeverity.CAPITAL, "sender record is capital treason")
	_ok(rec_s != null and rec_s.evidence_total == 50, "sender evidence jumps 50 (INTERCEPTED_LETTER)")
	_ok(rec_r != null and rec_r.evidence_total == 50, "recipient evidence jumps 50")
	_ok(rec_s != null and rec_s.legal_status == Enums.LegalStatus.ACCUSED, "sender accused (50 >= 40)")
	_ok(rec_r != null and rec_r.legal_status == Enums.LegalStatus.ACCUSED, "recipient accused (50 >= 40)")
	_ok(rec_s != null and rec_s.victim_id == 1 and rec_r != null and rec_r.victim_id == 2,
		"each record's victim is that conspirator's own betrayed lord")
	# The read still happened: the interceptor learned the letter's topic.
	_ok(9 in interceptor.topic_pool, "interceptor learned the letter topic (read intact)")


func _test_one_kolat_party_nothing() -> void:
	print("[2] only one Kolat party -> no evidence")
	var lord := _lord(10)
	var traitor := _traitor(11, 10)  # Kolat
	var loyal := _char(12, "Loyal")  # NOT Kolat
	loyal.lord_id = 10
	var interceptor := _char(13, "Spy")
	var by_id: Dictionary = {10: lord, 11: traitor, 12: loyal, 13: interceptor}
	var pending: Array = [_letter(71, 11, 12, 8)]  # traitor -> loyal (one Kolat party only)
	var results: Array = [_intercept_result(13, 11)]
	var records: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(7)
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [200], 90)
	_ok(records.is_empty(), "no treason record created (only one Kolat correspondent)")
	_ok(8 in interceptor.topic_pool, "the letter was still read (topic learned)")


func _test_dedup_no_double_count() -> void:
	print("[3] re-intercepting the SAME letter never double-counts (dedup)")
	var lord_a := _lord(20)
	var lord_b := _lord(21)
	var sender := _traitor(22, 20)
	var recipient := _traitor(23, 21)
	var interceptor := _char(24, "Spy")
	var by_id: Dictionary = {20: lord_a, 21: lord_b, 22: sender, 23: recipient, 24: interceptor}
	var pending: Array = [_letter(77, 22, 23, 5)]
	var results: Array = [_intercept_result(24, 22)]
	var records: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(7)
	# First interception: both accused at 50.
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [300], 90)
	var rec: CrimeRecord = _DO._find_treason_record(records, 22)
	_ok(rec != null and rec.evidence_total == 50, "first interception -> 50")
	# Re-intercept the same letter: the ACCUSED guard already blocks re-add.
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [300], 120)
	_ok(records.size() == 2, "no duplicate records on re-intercept")
	_ok(rec != null and rec.evidence_total == 50, "re-intercept while ACCUSED does not double-count")
	# Force the letter_id dedup branch itself: flip the record back below the ACCUSED
	# guard so the code reaches the dedup loop; the same letter_id must still add nothing.
	if rec != null:
		rec.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [300], 150)
	_ok(rec != null and rec.evidence_total == 50, "letter_id dedup blocks re-add (still 50, not 100)")


func _test_ciphered_unreadable_nothing() -> void:
	print("[4] ciphered letter a non-shugenja can't crack -> no read, no evidence")
	var lord_a := _lord(30)
	var lord_b := _lord(31)
	var sender := _traitor(32, 30)
	var recipient := _traitor(33, 31)
	var interceptor := _char(34, "Spy")  # no Spellcraft -> cannot crack a cipher
	var by_id: Dictionary = {30: lord_a, 31: lord_b, 32: sender, 33: recipient, 34: interceptor}
	var letter: LetterData = _letter(78, 32, 33, 6)
	letter.elemental_cipher = true
	letter.cipher_cast_total = 40  # unreachable for a non-shugenja
	var pending: Array = [letter]
	var results: Array = [_intercept_result(34, 32)]
	var records: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(7)
	_DO._process_intercept_letter_writebacks(results, pending, by_id, 0, dice, records, [400], 90)
	_ok(records.is_empty(), "ciphered-unreadable letter adds no treason evidence")
	_ok(not (6 in interceptor.topic_pool), "cipher held: interceptor never read the letter")
