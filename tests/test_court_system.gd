extends GutTest
## Tests for CourtSystem — court session lifecycle per GDD s15.1 / s15.2.


# -- Helpers -------------------------------------------------------------------

func _make_topic(id: int, momentum: float, resolved: bool = false) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.momentum = momentum
	t.resolved = resolved
	t.tier = TopicData.Tier.TIER_3
	t.category = TopicData.Category.POLITICAL
	return t


func _make_court(
	id: int = 1,
	court_type: CourtSessionData.CourtType = CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT,
	host_lord_id: int = 100,
	settlement_id: int = 10,
	host_clan: String = "Crane",
) -> CourtSessionData:
	return CourtSystem.create_court(id, court_type, host_lord_id, settlement_id, host_clan, 50)


# =============================================================================
# CREATE COURT
# =============================================================================

func test_create_provincial_court():
	var c := _make_court()
	assert_eq(c.court_id, 1)
	assert_eq(c.court_type, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT)
	assert_eq(c.host_lord_id, 100)
	assert_eq(c.host_settlement_id, 10)
	assert_eq(c.host_clan, "Crane")
	assert_eq(c.phase, CourtSessionData.CourtPhase.SCHEDULED)
	assert_eq(c.duration_ticks, CourtSystem.PROVINCIAL_COURT_MAX_DURATION)
	assert_eq(c.prestige, CourtSystem.PRESTIGE_PROVINCIAL)
	assert_false(c.emperor_present)


func test_create_clan_court():
	var c := CourtSystem.create_court(
		2, CourtSessionData.CourtType.CLAN_CHAMPION_COURT,
		200, 20, "Lion", 100
	)
	assert_eq(c.duration_ticks, CourtSystem.CLAN_COURT_MAX_DURATION)
	assert_eq(c.prestige, CourtSystem.PRESTIGE_CLAN)


func test_create_winter_court():
	var c := CourtSystem.create_court(
		3, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		300, 30, "Crane", 200, -1, true
	)
	assert_eq(c.duration_ticks, CourtSystem.WINTER_COURT_DURATION)
	assert_eq(c.prestige, CourtSystem.PRESTIGE_IMPERIAL)
	assert_true(c.emperor_present)


func test_create_court_custom_duration():
	var c := CourtSystem.create_court(
		4, CourtSessionData.CourtType.CLAN_CHAMPION_COURT,
		200, 20, "Lion", 100, 10
	)
	assert_eq(c.duration_ticks, 10)


# =============================================================================
# OPEN / ADVANCE / CLOSE
# =============================================================================

func test_open_court():
	var c := _make_court()
	assert_eq(c.phase, CourtSessionData.CourtPhase.SCHEDULED)
	CourtSystem.open_court(c, 60)
	assert_eq(c.phase, CourtSessionData.CourtPhase.ACTIVE)
	assert_eq(c.start_ic_day, 60)
	assert_eq(c.elapsed_ticks, 0)


func test_open_court_idempotent():
	var c := _make_court()
	CourtSystem.open_court(c, 60)
	CourtSystem.open_court(c, 70)
	assert_eq(c.start_ic_day, 60, "Should not re-open")


func test_advance_day():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	var r := CourtSystem.advance_court_day(c)
	assert_true(r["advanced"])
	assert_eq(r["elapsed"], 1)
	assert_false(r["should_close"])


func test_advance_to_expiry():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	var result: Dictionary = {}
	for i in range(c.duration_ticks):
		result = CourtSystem.advance_court_day(c)
	assert_true(result["should_close"])
	assert_eq(c.elapsed_ticks, c.duration_ticks)


func test_advance_not_active():
	var c := _make_court()
	var r := CourtSystem.advance_court_day(c)
	assert_false(r["advanced"])


func test_close_court():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	var r := CourtSystem.close_court(c)
	assert_true(r["closed"])
	assert_eq(c.phase, CourtSessionData.CourtPhase.CLOSED)
	assert_eq(r["court_id"], 1)
	assert_eq(r["host_clan"], "Crane")


func test_close_not_active():
	var c := _make_court()
	var r := CourtSystem.close_court(c)
	assert_false(r["closed"])


func test_close_already_closed():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.close_court(c)
	var r := CourtSystem.close_court(c)
	assert_false(r["closed"])


func test_is_active():
	var c := _make_court()
	assert_false(CourtSystem.is_active(c))
	CourtSystem.open_court(c, 50)
	assert_true(CourtSystem.is_active(c))
	CourtSystem.close_court(c)
	assert_false(CourtSystem.is_active(c))


func test_is_expired():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	assert_false(CourtSystem.is_expired(c))
	for i in range(c.duration_ticks):
		CourtSystem.advance_court_day(c)
	assert_true(CourtSystem.is_expired(c))


# =============================================================================
# ATTENDANCE
# =============================================================================

func test_add_attendee():
	var c := _make_court()
	assert_true(CourtSystem.add_attendee(c, 1))
	assert_true(CourtSystem.is_attending(c, 1))
	assert_eq(CourtSystem.get_attendee_count(c), 1)


func test_add_attendee_duplicate():
	var c := _make_court()
	CourtSystem.add_attendee(c, 1)
	assert_false(CourtSystem.add_attendee(c, 1))
	assert_eq(CourtSystem.get_attendee_count(c), 1)


func test_remove_attendee():
	var c := _make_court()
	CourtSystem.add_attendee(c, 1)
	assert_true(CourtSystem.remove_attendee(c, 1))
	assert_false(CourtSystem.is_attending(c, 1))
	assert_eq(CourtSystem.get_attendee_count(c), 0)


func test_remove_attendee_not_present():
	var c := _make_court()
	assert_false(CourtSystem.remove_attendee(c, 999))


func test_multiple_attendees():
	var c := _make_court()
	CourtSystem.add_attendee(c, 1)
	CourtSystem.add_attendee(c, 2)
	CourtSystem.add_attendee(c, 3)
	assert_eq(CourtSystem.get_attendee_count(c), 3)
	CourtSystem.remove_attendee(c, 2)
	assert_eq(CourtSystem.get_attendee_count(c), 2)
	assert_false(CourtSystem.is_attending(c, 2))
	assert_true(CourtSystem.is_attending(c, 1))
	assert_true(CourtSystem.is_attending(c, 3))


# =============================================================================
# AGENDA TOPICS
# =============================================================================

func test_select_agenda_topics_by_momentum():
	var topics: Array[TopicData] = [
		_make_topic(1, 30.0),
		_make_topic(2, 80.0),
		_make_topic(3, 50.0),
		_make_topic(4, 10.0),
	]
	var agenda := CourtSystem.select_agenda_topics(
		topics, CourtSessionData.CourtType.CLAN_CHAMPION_COURT
	)
	assert_eq(agenda.size(), 3)
	assert_eq(agenda[0], 2, "Highest momentum first")
	assert_eq(agenda[1], 3)
	assert_eq(agenda[2], 1)


func test_select_agenda_skips_resolved():
	var topics: Array[TopicData] = [
		_make_topic(1, 90.0, true),
		_make_topic(2, 50.0),
		_make_topic(3, 30.0),
	]
	var agenda := CourtSystem.select_agenda_topics(
		topics, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT
	)
	assert_eq(agenda.size(), 2)
	assert_false(1 in agenda, "Resolved topic excluded")


func test_select_agenda_crisis_trigger_first():
	var topics: Array[TopicData] = [
		_make_topic(1, 90.0),
		_make_topic(2, 50.0),
		_make_topic(3, 30.0),
		_make_topic(4, 10.0),
	]
	var agenda := CourtSystem.select_agenda_topics(
		topics, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 3
	)
	assert_eq(agenda[0], 3, "Crisis trigger topic is first")
	assert_eq(agenda.size(), 3)


func test_select_agenda_fewer_than_max():
	var topics: Array[TopicData] = [_make_topic(1, 20.0)]
	var agenda := CourtSystem.select_agenda_topics(
		topics, CourtSessionData.CourtType.CLAN_CHAMPION_COURT
	)
	assert_eq(agenda.size(), 1)


func test_set_agenda():
	var c := _make_court()
	CourtSystem.set_agenda(c, [10, 20, 30])
	assert_eq(c.agenda_topic_ids.size(), 3)
	assert_eq(c.agenda_topic_ids[0], 10)


# =============================================================================
# CRISIS-TRIGGERED COURT EVALUATION
# =============================================================================

func test_should_call_court_momentum_exceeds_threshold():
	var topics: Array[TopicData] = [_make_topic(1, 60.0)]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	assert_true(result.get("should_call", false))
	assert_eq(result["trigger_topic_id"], 1)


func test_should_call_court_momentum_below_threshold():
	var topics: Array[TopicData] = [_make_topic(1, 20.0)]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	assert_true(result.is_empty())


func test_should_call_court_higher_rank_higher_threshold():
	var topics: Array[TopicData] = [_make_topic(1, 40.0)]
	var result_provincial := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	var result_champion := CourtSystem.should_call_court(
		Enums.LordRank.CLAN_CHAMPION, topics, []
	)
	assert_true(result_provincial.get("should_call", false),
		"Provincial daimyo threshold 25 met by 40")
	assert_true(result_champion.is_empty(),
		"Clan champion threshold 50 not met by 40")


func test_should_call_court_blocked_by_existing():
	var topics: Array[TopicData] = [_make_topic(1, 60.0)]
	var existing := _make_court()
	CourtSystem.open_court(existing, 50)
	var active_courts: Array[CourtSessionData] = [existing]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, active_courts
	)
	assert_true(result.is_empty(), "Should not call court when one is active")


func test_should_call_court_allowed_after_closed():
	var topics: Array[TopicData] = [_make_topic(1, 60.0)]
	var existing := _make_court()
	CourtSystem.open_court(existing, 50)
	CourtSystem.close_court(existing)
	var courts: Array[CourtSessionData] = [existing]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, courts
	)
	assert_true(result.get("should_call", false))


func test_should_call_court_skips_resolved_topics():
	var topics: Array[TopicData] = [_make_topic(1, 60.0, true)]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	assert_true(result.is_empty())


# =============================================================================
# COMMITMENTS
# =============================================================================

func test_record_commitment():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 1)
	CourtSystem.add_attendee(c, 2)
	var r := CourtSystem.record_commitment(c, 1, "AID_CRAB", "Send 3 legions")
	assert_true(r["recorded"])
	assert_eq(c.commitments_made.size(), 1)
	var entry: Dictionary = r["entry"]
	assert_eq(entry["character_id"], 1)
	assert_eq(entry["commitment_type"], "AID_CRAB")
	assert_eq(entry["witnesses"].size(), 2, "All attendees as witnesses")


func test_record_commitment_custom_witnesses():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 1)
	CourtSystem.add_attendee(c, 2)
	CourtSystem.add_attendee(c, 3)
	var witnesses: Array[int] = [2]
	var r := CourtSystem.record_commitment(c, 1, "PEACE", "Accept terms", witnesses)
	assert_eq(r["entry"]["witnesses"].size(), 1)


func test_record_commitment_not_active():
	var c := _make_court()
	var r := CourtSystem.record_commitment(c, 1, "AID", "Help")
	assert_false(r["recorded"])


func test_record_war_resolution():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.record_war_resolution(c, 42)
	assert_eq(c.wars_resolved_during.size(), 1)
	assert_eq(c.wars_resolved_during[0], 42)
	CourtSystem.record_war_resolution(c, 42)
	assert_eq(c.wars_resolved_during.size(), 1, "No duplicates")


# =============================================================================
# CONTEXT HELPERS
# =============================================================================

func test_get_active_court_at_settlement():
	var c1 := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	var c2 := _make_court(2, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, 200, 20, "Lion")
	CourtSystem.open_court(c1, 50)
	var courts: Array[CourtSessionData] = [c1, c2]
	var found := CourtSystem.get_active_court_at_settlement(courts, 10)
	assert_not_null(found)
	assert_eq(found.court_id, 1)
	var not_found := CourtSystem.get_active_court_at_settlement(courts, 20)
	assert_null(not_found, "c2 is SCHEDULED, not active")


func test_get_active_courts():
	var c1 := _make_court(1)
	var c2 := _make_court(2)
	var c3 := _make_court(3)
	CourtSystem.open_court(c1, 50)
	CourtSystem.open_court(c3, 50)
	var courts: Array[CourtSessionData] = [c1, c2, c3]
	var active := CourtSystem.get_active_courts(courts)
	assert_eq(active.size(), 2)


func test_get_upcoming_courts():
	var c1 := _make_court(1)
	c1.start_ic_day = 100
	var c2 := _make_court(2)
	c2.start_ic_day = 50
	var courts: Array[CourtSessionData] = [c1, c2]
	var upcoming := CourtSystem.get_upcoming_courts(courts, 60)
	assert_eq(upcoming.size(), 1)
	assert_eq(upcoming[0].court_id, 1)


func test_to_context_dict():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 1)
	CourtSystem.add_attendee(c, 2)
	var d := CourtSystem.to_context_dict(c)
	assert_eq(d["court_id"], 1)
	assert_eq(d["settlement_id"], 10)
	assert_eq(d["host_clan"], "Crane")
	assert_eq(d["prestige"], CourtSystem.PRESTIGE_PROVINCIAL)
	assert_eq(d["attendee_count"], 2)


func test_character_context_flag():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 5)
	var courts: Array[CourtSessionData] = [c]
	assert_true(CourtSystem.get_character_context_flag(courts, 5))
	assert_false(CourtSystem.get_character_context_flag(courts, 99))


func test_character_context_flag_closed_court():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 5)
	CourtSystem.close_court(c)
	var courts: Array[CourtSessionData] = [c]
	assert_false(CourtSystem.get_character_context_flag(courts, 5),
		"Closed court does not give AT_COURT")


# =============================================================================
# TOPIC GENERATION ON CLOSE
# =============================================================================

func test_close_topic_no_resolution():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.close_court(c)
	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["variant"], "no_resolution")
	assert_eq(topic["tier"], TopicData.Tier.TIER_4)
	assert_eq(topic["momentum"], 5.0)


func test_close_topic_with_commitments():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.record_commitment(c, 1, "AID", "Help")
	CourtSystem.close_court(c)
	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["variant"], "concluded")
	assert_eq(topic["tier"], TopicData.Tier.TIER_4)
	assert_true(topic["momentum"] >= 11.0)


func test_close_topic_clan_court():
	var c := CourtSystem.create_court(
		1, CourtSessionData.CourtType.CLAN_CHAMPION_COURT,
		200, 20, "Lion", 100
	)
	CourtSystem.open_court(c, 100)
	CourtSystem.record_commitment(c, 1, "PEACE", "Accept")
	CourtSystem.close_court(c)
	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["tier"], TopicData.Tier.TIER_3)
	assert_eq(topic["momentum"], 25.0)


func test_close_topic_winter_court():
	var c := CourtSystem.create_court(
		1, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		300, 30, "Crane", 200, -1, true
	)
	CourtSystem.open_court(c, 200)
	CourtSystem.record_commitment(c, 1, "EDICT", "Tax reform")
	CourtSystem.close_court(c)
	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["tier"], TopicData.Tier.TIER_2)
	assert_eq(topic["momentum"], 50.0)


func test_close_topic_war_resolved_upgrades_tier():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.record_war_resolution(c, 42)
	CourtSystem.close_court(c)
	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["tier"], TopicData.Tier.TIER_2,
		"War resolution upgrades topic tier")
	assert_true(topic["momentum"] >= 40.0)


# =============================================================================
# DEFAULT DURATION
# =============================================================================

func test_default_duration_winter():
	assert_eq(CourtSystem.get_default_duration(
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT), 120)


func test_default_duration_clan():
	assert_eq(CourtSystem.get_default_duration(
		CourtSessionData.CourtType.CLAN_CHAMPION_COURT), 14)


func test_default_duration_provincial():
	assert_eq(CourtSystem.get_default_duration(
		CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT), 5)


# =============================================================================
# FULL LIFECYCLE
# =============================================================================

func test_full_lifecycle():
	var c := CourtSystem.create_court(
		1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT,
		100, 10, "Crane", 50
	)
	assert_eq(c.phase, CourtSessionData.CourtPhase.SCHEDULED)

	CourtSystem.open_court(c, 50)
	assert_eq(c.phase, CourtSessionData.CourtPhase.ACTIVE)

	CourtSystem.add_attendee(c, 1)
	CourtSystem.add_attendee(c, 2)
	CourtSystem.add_attendee(c, 3)

	for i in range(3):
		CourtSystem.advance_court_day(c)

	CourtSystem.record_commitment(c, 1, "SEND_AID", "Send rice to Crab")

	for i in range(2):
		var r := CourtSystem.advance_court_day(c)
		if r.get("should_close", false):
			break

	var close_result := CourtSystem.close_court(c)
	assert_true(close_result["closed"])
	assert_eq(close_result["commitments_count"], 1)
	assert_eq(c.phase, CourtSessionData.CourtPhase.CLOSED)

	var topic := CourtSystem.generate_court_close_topic(c)
	assert_eq(topic["variant"], "concluded")


# =============================================================================
# ORCHESTRATOR WIRING — COURT OPENINGS & ATTENDANCE
# =============================================================================

func _make_character(id: int, location: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = location
	c.status = 3.0
	return c


func test_scheduled_court_opens_on_start_day():
	var court := _make_court(1)
	court.start_ic_day = 50
	assert_eq(court.phase, CourtSessionData.CourtPhase.SCHEDULED)
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_openings(courts, 50)
	assert_eq(results.size(), 1)
	assert_true(results[0]["opened"])
	assert_eq(court.phase, CourtSessionData.CourtPhase.ACTIVE)


func test_scheduled_court_does_not_open_before_start():
	var court := _make_court(1)
	court.start_ic_day = 100
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_openings(courts, 50)
	assert_eq(results.size(), 0)
	assert_eq(court.phase, CourtSessionData.CourtPhase.SCHEDULED)


func test_character_auto_attends_when_at_settlement():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	var npc := _make_character(200, "10")
	var chars: Array[L5RCharacterData] = [npc]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "arrived")
	assert_true(200 in court.attendee_ids)


func test_character_departs_when_leaving_settlement():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var npc := _make_character(200, "99")
	var chars: Array[L5RCharacterData] = [npc]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "departed")
	assert_false(200 in court.attendee_ids)


func test_host_not_removed_when_away():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 100)
	var host := _make_character(100, "99")
	var chars: Array[L5RCharacterData] = [host]
	var courts: Array[CourtSessionData] = [court]
	DayOrchestrator._process_court_attendance(courts, chars)
	assert_true(100 in court.attendee_ids, "Host stays in attendee list")


func test_no_duplicate_attendance():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var npc := _make_character(200, "10")
	var chars: Array[L5RCharacterData] = [npc]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 0, "Already attending — no duplicate")
	assert_eq(court.attendee_ids.count(200), 1)


func test_closed_court_skipped_for_attendance():
	var court := _make_court(1)
	CourtSystem.open_court(court, 50)
	CourtSystem.close_court(court)
	var npc := _make_character(200, "10")
	var chars: Array[L5RCharacterData] = [npc]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 0, "Closed court ignored")


# =============================================================================
# EARLY DEPARTURE COSTS
# =============================================================================

func test_guest_departure_applies_disposition_cost():
	var court := _make_court(1, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 100)
	CourtSystem.add_attendee(court, 200)
	var host := _make_character(100, "10")
	var guest := _make_character(200, "99")
	var chars_by_id: Dictionary = {100: host, 200: guest}
	var chars: Array[L5RCharacterData] = [host, guest]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars, chars_by_id)
	var departure: Dictionary = {}
	for r: Dictionary in results:
		if r.get("action") == "departed":
			departure = r
	assert_false(departure.is_empty(), "Guest should depart")
	assert_eq(departure["disposition_cost"], CourtPrioritySystem.GUEST_LEAVING_DISPOSITION_COST)
	var host_disp: int = int(host.disposition_values.get(200, 0))
	assert_eq(host_disp, CourtPrioritySystem.GUEST_LEAVING_DISPOSITION_COST)


func test_guest_departure_no_honor_loss():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var guest := _make_character(200, "99")
	guest.honor = 5.0
	var chars_by_id: Dictionary = {200: guest}
	var chars: Array[L5RCharacterData] = [guest]
	var courts: Array[CourtSessionData] = [court]
	DayOrchestrator._process_court_attendance(courts, chars, chars_by_id)
	assert_eq(guest.honor, 5.0, "Guests lose no honor on departure")


func test_departure_result_includes_costs():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var guest := _make_character(200, "99")
	var host := _make_character(100, "10")
	var chars_by_id: Dictionary = {100: host, 200: guest}
	var chars: Array[L5RCharacterData] = [guest]
	var courts: Array[CourtSessionData] = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars, chars_by_id)
	assert_eq(results.size(), 1)
	assert_true(results[0].has("honor_loss"))
	assert_true(results[0].has("glory_loss"))
	assert_true(results[0].has("disposition_cost"))


# =============================================================================
# WINTER COURT HOST SELECTION WIRING
# =============================================================================

func test_winter_court_host_directive_creates_imperial_court():
	var emperor := _make_character(1, "50")
	emperor.status = 10.0
	emperor.clan = "Imperial"
	var crane_champ := _make_character(10, "20")
	crane_champ.status = 8.0
	crane_champ.clan = "Crane"
	crane_champ.lord_id = -1
	var chars_by_id: Dictionary = {1: emperor, 10: crane_champ}
	var active_courts: Array[CourtSessionData] = []
	var active_topics: Array[TopicData] = []
	var next_court_id: Array[int] = [1]

	var directive: Dictionary = {
		"directive": "WINTER_COURT_HOST",
		"lord_id": 1,
		"host_clan": "Crane",
		"score": 15.0,
	}
	DayOrchestrator._process_strategic_court_calls(
		[directive], active_courts, active_topics,
		chars_by_id, next_court_id, 200,
	)
	assert_eq(active_courts.size(), 1)
	var court: CourtSessionData = active_courts[0]
	assert_eq(court.court_type, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT)
	assert_eq(court.host_clan, "Crane")
	assert_true(court.emperor_present)
	assert_eq(court.host_settlement_id, 20)
	assert_eq(court.duration_ticks, CourtSystem.WINTER_COURT_DURATION)
	assert_true(1 in court.attendee_ids)
	assert_true(10 in court.attendee_ids)


func test_winter_court_not_duplicated():
	var emperor := _make_character(1, "50")
	emperor.status = 10.0
	emperor.clan = "Imperial"
	var lion_champ := _make_character(20, "30")
	lion_champ.status = 8.0
	lion_champ.clan = "Lion"
	lion_champ.lord_id = -1
	var chars_by_id: Dictionary = {1: emperor, 20: lion_champ}
	var existing := CourtSystem.create_court(
		1, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		1, 50, "Imperial", 100, 120, true
	)
	CourtSystem.open_court(existing, 100)
	var active_courts: Array[CourtSessionData] = [existing]
	var next_court_id: Array[int] = [2]

	var directive: Dictionary = {
		"directive": "WINTER_COURT_HOST",
		"lord_id": 1,
		"host_clan": "Lion",
	}
	DayOrchestrator._process_strategic_court_calls(
		[directive], active_courts, [],
		chars_by_id, next_court_id, 200,
	)
	assert_eq(active_courts.size(), 1, "No duplicate Winter Court")


func test_winter_court_starts_30_days_later():
	var emperor := _make_character(1, "50")
	emperor.status = 10.0
	emperor.clan = "Imperial"
	var scorpion := _make_character(30, "40")
	scorpion.status = 8.0
	scorpion.clan = "Scorpion"
	scorpion.lord_id = -1
	var chars_by_id: Dictionary = {1: emperor, 30: scorpion}
	var active_courts: Array[CourtSessionData] = []
	var next_court_id: Array[int] = [1]

	var directive: Dictionary = {
		"directive": "WINTER_COURT_HOST",
		"lord_id": 1,
		"host_clan": "Scorpion",
	}
	DayOrchestrator._process_strategic_court_calls(
		[directive], active_courts, [],
		chars_by_id, next_court_id, 250,
	)
	assert_eq(active_courts[0].start_ic_day, 280, "Starts 30 days after directive")
	assert_eq(active_courts[0].phase, CourtSessionData.CourtPhase.SCHEDULED)


func test_emperor_review_runs_for_emperor():
	var emperor := _make_character(1, "50")
	emperor.status = 10.0
	emperor.clan = "Imperial"
	emperor.lord_id = -1
	var lion := _make_character(10, "20")
	lion.status = 8.0
	lion.clan = "Lion"
	lion.lord_id = -1
	var characters: Array[L5RCharacterData] = [emperor, lion]
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
		"current_season": TimeSystem.Season.AUTUMN,
		"current_season_index": 4,
	}
	var objectives_map: Dictionary = {}
	var results := DayOrchestrator._run_strategic_reviews(
		characters, objectives_map, world_states,
	)
	var has_winter_court: bool = false
	for d: Dictionary in results:
		if d.get("directive", "") == "WINTER_COURT_HOST":
			has_winter_court = true
	assert_true(has_winter_court, "Emperor review should produce WINTER_COURT_HOST in Autumn")
