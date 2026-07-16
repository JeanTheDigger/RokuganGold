extends SceneTree
## Runtime driver for the court-close commitment recording wire (s15.2 / s16.4).
##
## CourtSystem.record_commitment (the sole writer of CourtSessionData.commitments_made) had ZERO
## production callers, so commitments_made was ALWAYS empty -> CourtSystem.generate_court_close_topic
## (called on every court close, day_orchestrator ~21083) ALWAYS returned the generic "no_resolution"
## rumor, even when a lord made a binding public declaration at that court. The higher-tier
## "concluded" outcome topic (Imperial Winter Court TIER_2 / Champion Court TIER_3) could never spawn.
##
## FIX (pure structural wire, no invented values): _process_voluntary_declarations -- which already
## creates a CourtCommitmentData for a successful PUBLIC_DECLARATION with the active `court` in scope
## -- now also calls CourtSystem.record_commitment(court, lord_id, commitment_type, topic.title,
## court.attendee_ids). (record_war_resolution stays DEFERRED: the live war-termination path has no
## court in scope; the only court<->war link is the zero-caller dead-twin peace-court subsystem.)
## Run: godot --headless -s tests/verify_court_commitment_record.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CS := preload("res://simulation/court_system.gd")
const _CSD := preload("res://shared/court_session_data.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _TOPIC := preload("res://shared/topic_data.gd")
const _TS := preload("res://simulation/time_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk_court(cid: int, ctype: CourtSessionData.CourtType, phase: CourtSessionData.CourtPhase) -> CourtSessionData:
	var c: CourtSessionData = _CSD.new()
	c.court_id = cid
	c.court_type = ctype
	c.phase = phase
	c.host_clan = "Crane"
	c.host_settlement_id = 100
	c.attendee_ids = [1, 2]
	c.agenda_topic_ids = []
	c.commitments_made = []
	c.wars_resolved_during = []
	c.start_ic_day = 200
	c.elapsed_ticks = 5
	return c


func _mk_lord(id: int) -> L5RCharacterData:
	var l: L5RCharacterData = _CHAR.new()
	l.character_id = id
	l.status = 6.0  # lord-tier (>= 5.0)
	l.clan = "Crane"
	l.topic_positions = {}
	return l


func _mk_topic(tid: int) -> TopicData:
	var t: TopicData = _TOPIC.new()
	t.topic_id = tid
	t.topic_type = "famine"  # maps to a non-empty commitment_type (send_supplies)
	t.title = "The Crane famine crisis"
	t.resolved = false
	return t


func _init() -> void:
	print("--- court-close commitment recording (s15.2/s16.4) ---")
	_test_record_commitment_arbiter()
	_test_close_topic_variant()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_record_commitment_arbiter() -> void:
	print("[1] record_commitment appends to commitments_made only when ACTIVE")
	var active: CourtSessionData = _mk_court(1, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, CourtSessionData.CourtPhase.ACTIVE)
	var res: Dictionary = _CS.record_commitment(active, 1, "send_supplies", "famine relief", active.attendee_ids)
	_ok(res.get("recorded", false), "recorded on an ACTIVE court")
	_ok(active.commitments_made.size() == 1, "commitments_made now has one entry")
	_ok(active.commitments_made[0].get("witnesses") == active.attendee_ids, "witnesses default to attendees")
	# A non-active court rejects.
	var closing: CourtSessionData = _mk_court(2, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, CourtSessionData.CourtPhase.SCHEDULED)
	var res2: Dictionary = _CS.record_commitment(closing, 1, "send_supplies", "x", [])
	_ok(not res2.get("recorded", true), "rejected on a non-active court")
	_ok(closing.commitments_made.is_empty(), "non-active court records nothing")


func _test_close_topic_variant() -> void:
	print("[2] generate_court_close_topic: no_resolution when empty, concluded + tier when recorded")
	# Empty -> no_resolution TIER_4 (the pre-fix behavior for EVERY court).
	var empty: CourtSessionData = _mk_court(3, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT, CourtSessionData.CourtPhase.ACTIVE)
	var td_empty: Dictionary = _CS.generate_court_close_topic(empty)
	_ok(td_empty.get("variant") == "no_resolution", "empty court -> no_resolution")
	_ok(td_empty.get("tier") == TopicData.Tier.TIER_4, "no_resolution is TIER_4")
	# With a commitment -> concluded, tier escalates by court type.
	var winter: CourtSessionData = _mk_court(4, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT, CourtSessionData.CourtPhase.ACTIVE)
	_CS.record_commitment(winter, 1, "send_supplies", "relief", winter.attendee_ids)
	var td_w: Dictionary = _CS.generate_court_close_topic(winter)
	_ok(td_w.get("variant") == "concluded", "Winter Court with a commitment -> concluded")
	_ok(td_w.get("tier") == TopicData.Tier.TIER_2, "Imperial Winter Court concluded -> TIER_2")
	_ok(td_w.get("commitments_count") == 1, "commitments_count reported")
	var champ: CourtSessionData = _mk_court(5, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, CourtSessionData.CourtPhase.ACTIVE)
	_CS.record_commitment(champ, 1, "send_supplies", "relief", champ.attendee_ids)
	_ok(_CS.generate_court_close_topic(champ).get("tier") == TopicData.Tier.TIER_3, "Champion Court concluded -> TIER_3")


func _test_end_to_end() -> void:
	print("[3] end-to-end: a PUBLIC_DECLARATION at a court records the commitment onto it")
	var lord: L5RCharacterData = _mk_lord(1)
	var topic: TopicData = _mk_topic(500)
	lord.topic_positions[topic.topic_id] = 60.0  # exceeds VOLUNTARY_POSITION_THRESHOLD (50)
	var court: CourtSessionData = _mk_court(6, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, CourtSessionData.CourtPhase.ACTIVE)
	court.attendee_ids = [lord.character_id]
	court.agenda_topic_ids = [topic.topic_id]
	var chars_by_id: Dictionary = {lord.character_id: lord}
	var applied: Array = [{
		"action_id": "PUBLIC_DECLARATION",
		"character_id": lord.character_id,
		"effects": {},
	}]
	var court_commitments: Array = []
	var ts: TimeSystem = _TS.new()
	var created: Array = _DO._process_voluntary_declarations(
		applied, [court], [topic], court_commitments, chars_by_id, 210, ts)
	_ok(created.size() == 1, "a CourtCommitmentData was created for the declaration")
	_ok(court.commitments_made.size() == 1, "the commitment is ALSO recorded onto the court session (the wire)")
	# Now the court closes with the higher-tier concluded topic instead of no_resolution.
	var td: Dictionary = _CS.generate_court_close_topic(court)
	_ok(td.get("variant") == "concluded", "the court now closes as 'concluded', not 'no_resolution'")
	_ok(td.get("tier") == TopicData.Tier.TIER_3, "Champion Court concluded -> TIER_3 (was TIER_4 no_resolution)")
	# A control court with no declaration still closes no_resolution.
	var quiet: CourtSessionData = _mk_court(7, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, CourtSessionData.CourtPhase.ACTIVE)
	_ok(_CS.generate_court_close_topic(quiet).get("variant") == "no_resolution",
		"a court with no declaration still closes no_resolution (control)")
