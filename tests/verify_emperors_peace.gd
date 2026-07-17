extends SceneTree
## Runtime driver for wiring the Emperor's Peace at Winter Court (s57.47 v624 / s55.10).
## Before this, is_action_blocked_by_emperors_peace + record_emperors_peace_violation
## were built but had ZERO production callers (the HOSTILE_ACTIONS list even used phantom
## ActionIDs). Verifies: (1) the reconciled action classification (real ActionIDs, covert
## permitted, sanctioned duel exempt); (2) the NPC precondition filter removes the overt
## breach (INTIMIDATE) only at an active Imperial Winter Court, keeping sanctioned duels /
## covert / benign actions and doing nothing at other courts; and (3) the executor-side
## recorder fires the CAPITAL crime + Tier-1 topic + Emperor -15 clan-disposition for an
## attendee who commits a violation, and no-ops for a sanctioned duel / non-attendee /
## no-winter-court / dedup.
## Run: godot --headless -s tests/verify_emperors_peace.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _NPC := preload("res://simulation/npc_decision_engine.gd")
const _WC := preload("res://simulation/winter_court_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, clan: String, role: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "C%d" % cid
	c.clan = clan
	c.family = clan
	c.honor = 5.0
	c.role_position = role
	c.physical_location = "500"
	return c


func _wc(attendees: Array, phase: int = CourtSessionData.CourtPhase.ACTIVE,
		ctype: int = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT) -> CourtSessionData:
	var court := CourtSessionData.new()
	court.court_id = 1
	court.court_type = ctype
	court.phase = phase
	court.host_settlement_id = 500
	court.host_clan = "Crane"
	court.attendee_ids = attendees
	return court


func _opt(aid: String) -> NPCDataStructures.ScoredAction:
	var o := NPCDataStructures.ScoredAction.new()
	o.action_id = aid
	return o


func _ctx_at_court(ctype: int) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {"court_type": ctype, "settlement_id": 500}
	return ctx


func _result(cid: int, aid: String, sanctioned: bool = true) -> Dictionary:
	return {"character_id": cid, "action_id": aid, "effects": {"is_sanctioned": sanctioned}}


func _init() -> void:
	print("--- Emperor's Peace at Winter Court (s57.47 v624 / s55.10) ---")
	_test_classification()
	_test_npc_filter()
	_test_recorder()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_classification() -> void:
	print("[1] action classification + court-object predicate")
	_ok(_WC.is_peace_violating_action("INTIMIDATE", true), "INTIMIDATE is a breach")
	_ok(not _WC.is_peace_violating_action("ISSUE_DUEL_CHALLENGE", true), "sanctioned duel exempt")
	_ok(_WC.is_peace_violating_action("ISSUE_DUEL_CHALLENGE", false), "UNsanctioned duel is a breach")
	_ok(not _WC.is_peace_violating_action("EAVESDROP", true), "covert intrigue permitted")
	_ok(not _WC.is_peace_violating_action("CHARM", true), "benign court action not a breach")
	_ok(not _WC.is_peace_violating_action("COMMISSION_ASSASSINATION", true),
		"assassination excluded (covert, off-site)")
	# Court-object predicate: active winter court + at host + INTIMIDATE -> blocked.
	var court := _wc([10])
	_ok(_WC.is_action_blocked_by_emperors_peace("INTIMIDATE", 500, court, true),
		"blocked at active court host")
	_ok(not _WC.is_action_blocked_by_emperors_peace("INTIMIDATE", 999, court, true),
		"not blocked away from the host settlement")
	court.phase = CourtSessionData.CourtPhase.SCHEDULED
	_ok(not _WC.is_action_blocked_by_emperors_peace("INTIMIDATE", 500, court, true),
		"not blocked at a non-active court")


func _test_npc_filter() -> void:
	print("[2] NPC precondition filter (removes INTIMIDATE only at an active Winter Court)")
	var opts: Array = [_opt("INTIMIDATE"), _opt("ISSUE_DUEL_CHALLENGE"), _opt("CHARM"), _opt("EAVESDROP")]
	var out: Array = _NPC._apply_emperors_peace_precondition_filter(opts, _ctx_at_court(
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT))
	var ids: Array = []
	for o: NPCDataStructures.ScoredAction in out:
		ids.append(o.action_id)
	_ok(not ("INTIMIDATE" in ids), "INTIMIDATE removed at Winter Court")
	_ok("ISSUE_DUEL_CHALLENGE" in ids, "sanctioned duel kept")
	_ok("CHARM" in ids and "EAVESDROP" in ids, "benign + covert actions kept")

	# A non-winter court does NOT trigger the Emperor's Peace.
	var out2: Array = _NPC._apply_emperors_peace_precondition_filter(
		[_opt("INTIMIDATE")], _ctx_at_court(CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT))
	_ok(out2.size() == 1, "INTIMIDATE NOT removed at a provincial court")

	# No court context -> untouched.
	var out3: Array = _NPC._apply_emperors_peace_precondition_filter(
		[_opt("INTIMIDATE")], NPCDataStructures.ContextSnapshot.new())
	_ok(out3.size() == 1, "no active court -> nothing removed")


func _test_recorder() -> void:
	print("[3] executor-side recorder backstop")
	var offender := _char(10, "Lion")
	var champ := _char(11, "Lion", RoleRegistry.CLAN_CHAMPION)
	var fam_daimyo := _char(12, "Lion", RoleRegistry.FAMILY_DAIMYO)
	fam_daimyo.glory = 2.0  # so the -1.0 peace-violation Glory hit is observable
	var emperor := _char(99, "Imperial")
	var by_id: Dictionary = {10: offender, 11: champ, 12: fam_daimyo, 99: emperor}
	var chars: Array = [offender, champ, fam_daimyo, emperor]
	var ws: Dictionary = {"emperor_id": 99}
	var courts: Array = [_wc([10, 11])]  # offender is an attendee

	# A violation (INTIMIDATE by attendee 10) -> CAPITAL crime + Tier-1 topic + -15.
	var crimes: Array = []
	var topics: Array = []
	var ncase: Array = [1]
	var ntopic: Array = [1000]
	_DO._process_emperors_peace_violations(
		[_result(10, "INTIMIDATE")], courts, chars, by_id,
		crimes, ncase, topics, ntopic, 30, ws)
	_ok(crimes.size() == 1, "one CAPITAL crime recorded (got %d)" % crimes.size())
	if crimes.size() == 1:
		var rec: CrimeRecord = crimes[0]
		_ok(rec.crime_type == Enums.CrimeType.VIOLATION_EMPERORS_PEACE, "crime_type = VIOLATION_EMPERORS_PEACE")
		_ok(rec.perpetrator_id == 10 and rec.legal_status == Enums.LegalStatus.ACCUSED, "offender ACCUSED")
	_ok(topics.size() == 1 and topics[0].tier == TopicData.Tier.TIER_1, "Tier-1 topic created")
	_ok(int(emperor.disposition_values.get(11, 0)) == -15,
		"Emperor -15 toward the offender's clan champion (got %d)" % int(emperor.disposition_values.get(11, 0)))
	_ok(offender.honor < 5.0, "offender took at-act honor loss (Pattern B)")
	_ok(abs(fam_daimyo.glory - 1.0) < 0.001, "family daimyo Glory -1.0 (2.0 -> %.2f)" % fam_daimyo.glory)

	# Dedup: a second violation by the same offender records nothing new.
	_DO._process_emperors_peace_violations(
		[_result(10, "INTIMIDATE")], courts, chars, by_id,
		crimes, ncase, topics, ntopic, 31, ws)
	_ok(crimes.size() == 1, "dedup: no second record for the same offender")

	# A SANCTIONED duel by an attendee is exempt -> no crime.
	var crimes2: Array = []
	_DO._process_emperors_peace_violations(
		[_result(11, "ISSUE_DUEL_CHALLENGE", true)], courts, chars, by_id,
		crimes2, [1], [], [1000], 32, ws)
	_ok(crimes2.is_empty(), "sanctioned duel -> no violation")

	# A NON-attendee committing INTIMIDATE at (nominally) the court -> not recorded.
	var outsider := _char(20, "Crab")
	by_id[20] = outsider
	chars.append(outsider)
	var crimes3: Array = []
	_DO._process_emperors_peace_violations(
		[_result(20, "INTIMIDATE")], courts, chars, by_id,
		crimes3, [1], [], [1000], 33, ws)
	_ok(crimes3.is_empty(), "non-attendee -> not a peace violation")

	# No active Winter Court -> recorder no-ops.
	var crimes4: Array = []
	_DO._process_emperors_peace_violations(
		[_result(10, "INTIMIDATE")], [], chars, by_id,
		crimes4, [1], [], [1000], 34, ws)
	_ok(crimes4.is_empty(), "no active Winter Court -> nothing recorded")
