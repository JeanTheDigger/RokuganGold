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
	var topics: Array = [
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
	var topics: Array = [
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
	var topics: Array = [
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
	var topics: Array = [_make_topic(1, 20.0)]
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
	var topics: Array = [_make_topic(1, 60.0)]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	assert_true(result.get("should_call", false))
	assert_eq(result["trigger_topic_id"], 1)


func test_should_call_court_momentum_below_threshold():
	var topics: Array = [_make_topic(1, 20.0)]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, []
	)
	assert_true(result.is_empty())


func test_should_call_court_higher_rank_higher_threshold():
	var topics: Array = [_make_topic(1, 40.0)]
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
	var topics: Array = [_make_topic(1, 60.0)]
	var existing := _make_court()
	CourtSystem.open_court(existing, 50)
	var active_courts: Array = [existing]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, active_courts
	)
	assert_true(result.is_empty(), "Should not call court when one is active")


func test_should_call_court_allowed_after_closed():
	var topics: Array = [_make_topic(1, 60.0)]
	var existing := _make_court()
	CourtSystem.open_court(existing, 50)
	CourtSystem.close_court(existing)
	var courts: Array = [existing]
	var result := CourtSystem.should_call_court(
		Enums.LordRank.PROVINCIAL_DAIMYO, topics, courts
	)
	assert_true(result.get("should_call", false))


func test_should_call_court_skips_resolved_topics():
	var topics: Array = [_make_topic(1, 60.0, true)]
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
	var witnesses: Array = [2]
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
	var courts: Array = [c1, c2]
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
	var courts: Array = [c1, c2, c3]
	var active := CourtSystem.get_active_courts(courts)
	assert_eq(active.size(), 2)


func test_get_upcoming_courts():
	var c1 := _make_court(1)
	c1.start_ic_day = 100
	var c2 := _make_court(2)
	c2.start_ic_day = 50
	var courts: Array = [c1, c2]
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
	var courts: Array = [c]
	assert_true(CourtSystem.get_character_context_flag(courts, 5))
	assert_false(CourtSystem.get_character_context_flag(courts, 99))


func test_character_context_flag_closed_court():
	var c := _make_court()
	CourtSystem.open_court(c, 50)
	CourtSystem.add_attendee(c, 5)
	CourtSystem.close_court(c)
	var courts: Array = [c]
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
	var courts: Array = [court]
	var results := DayOrchestrator._process_court_openings(courts, 50)
	assert_eq(results.size(), 1)
	assert_true(results[0]["opened"])
	assert_eq(court.phase, CourtSessionData.CourtPhase.ACTIVE)


func test_scheduled_court_does_not_open_before_start():
	var court := _make_court(1)
	court.start_ic_day = 100
	var courts: Array = [court]
	var results := DayOrchestrator._process_court_openings(courts, 50)
	assert_eq(results.size(), 0)
	assert_eq(court.phase, CourtSessionData.CourtPhase.SCHEDULED)


func test_character_auto_attends_when_at_settlement():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	var npc := _make_character(200, "10")
	var chars: Array = [npc]
	var courts: Array = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "arrived")
	assert_true(200 in court.attendee_ids)


func test_character_departs_when_leaving_settlement():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var npc := _make_character(200, "99")
	var chars: Array = [npc]
	var courts: Array = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "departed")
	assert_false(200 in court.attendee_ids)


func test_host_not_removed_when_away():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 100)
	var host := _make_character(100, "99")
	var chars: Array = [host]
	var courts: Array = [court]
	DayOrchestrator._process_court_attendance(courts, chars)
	assert_true(100 in court.attendee_ids, "Host stays in attendee list")


func test_no_duplicate_attendance():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var npc := _make_character(200, "10")
	var chars: Array = [npc]
	var courts: Array = [court]
	var results := DayOrchestrator._process_court_attendance(courts, chars)
	assert_eq(results.size(), 0, "Already attending — no duplicate")
	assert_eq(court.attendee_ids.count(200), 1)


func test_closed_court_skipped_for_attendance():
	var court := _make_court(1)
	CourtSystem.open_court(court, 50)
	CourtSystem.close_court(court)
	var npc := _make_character(200, "10")
	var chars: Array = [npc]
	var courts: Array = [court]
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
	var chars: Array = [host, guest]
	var courts: Array = [court]
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
	var chars: Array = [guest]
	var courts: Array = [court]
	DayOrchestrator._process_court_attendance(courts, chars, chars_by_id)
	assert_eq(guest.honor, 5.0, "Guests lose no honor on departure")


func test_departure_result_includes_costs():
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10)
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 200)
	var guest := _make_character(200, "99")
	var host := _make_character(100, "10")
	var chars_by_id: Dictionary = {100: host, 200: guest}
	var chars: Array = [guest]
	var courts: Array = [court]
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
	var active_courts: Array = []
	var active_topics: Array = []
	var next_court_id: Array = [1]

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
	var active_courts: Array = [existing]
	var next_court_id: Array = [2]

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
	var active_courts: Array = []
	var next_court_id: Array = [1]

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
	var characters: Array = [emperor, lion]
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


# =============================================================================
# CRISIS-TRIGGERED COURT SCHEDULING
# =============================================================================

func _make_lord(id: int, location: String, clan: String, status: float = 6.0) -> L5RCharacterData:
	var c := _make_character(id, location)
	c.clan = clan
	c.status = status
	c.lord_id = -1
	return c


func test_crisis_topic_triggers_court_call():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var topic := _make_topic(1, 30.0)
	var characters: Array = [lord]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [1]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 1)
	assert_true(results[0].get("crisis_called", false))
	assert_eq(results[0]["lord_id"], 100)
	assert_eq(results[0]["trigger_topic_id"], 1)
	assert_eq(courts.size(), 1, "Court should be added to active_courts")
	assert_eq(courts[0].host_lord_id, 100)
	assert_eq(courts[0].crisis_trigger_topic_id, 1)


func test_crisis_court_not_triggered_below_threshold():
	var lord := _make_lord(100, "10", "Lion", 6.0)
	var topic := _make_topic(1, 10.0)
	var characters: Array = [lord]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [1]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 0, "Low momentum should not trigger court")
	assert_eq(courts.size(), 0)


func test_crisis_court_not_triggered_for_non_lords():
	var vassal := _make_character(200, "10")
	vassal.clan = "Scorpion"
	vassal.status = 3.0
	vassal.lord_id = 100
	var topic := _make_topic(1, 50.0)
	var characters: Array = [vassal]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [1]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 0, "Non-lords should not trigger crisis courts")


func test_crisis_court_blocked_by_existing_active_court():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var topic := _make_topic(1, 30.0)
	var existing := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(existing, 45)
	var characters: Array = [lord]
	var courts: Array = [existing]
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [2]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 0, "Active court at settlement blocks new crisis court")


func test_crisis_court_cooldown_prevents_rapid_calls():
	var lord := _make_lord(100, "10", "Dragon", 6.0)
	var topic := _make_topic(1, 30.0)
	var characters: Array = [lord]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {100: {"last_court_called_ic_day": 30}}
	var next_id: Array = [1]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 0, "30-day cooldown should prevent new court")


func test_crisis_court_allowed_after_cooldown():
	var lord := _make_lord(100, "10", "Dragon", 6.0)
	var topic := _make_topic(1, 30.0)
	var characters: Array = [lord]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {100: {"last_court_called_ic_day": 10}}
	var next_id: Array = [1]

	var results := DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(results.size(), 1, "Court should be allowed after 30-day cooldown")


func test_crisis_court_type_matches_lord_status():
	var champion := _make_lord(100, "10", "Lion", 8.0)
	var topic := _make_topic(1, 55.0)
	var characters: Array = [champion]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [1]

	DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	assert_eq(courts.size(), 1)
	assert_eq(courts[0].court_type, CourtSessionData.CourtType.CLAN_CHAMPION_COURT)


func test_crisis_court_tracks_last_court_day():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var topic := _make_topic(1, 30.0)
	var characters: Array = [lord]
	var courts: Array = []
	var topics: Array = [topic]
	var world_states: Dictionary = {}
	var next_id: Array = [1]

	DayOrchestrator._process_crisis_court_calls(
		characters, courts, topics, world_states, next_id, 50,
	)

	var ws: Dictionary = world_states.get(100, {})
	assert_eq(ws.get("last_court_called_ic_day", -1), 50)


# =============================================================================
# STRATEGIC COURT SCHEDULING
# =============================================================================

func test_strategic_call_court_creates_session():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var directives: Array = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 100,
	}]
	var courts: Array = []
	var topics: Array = []
	var chars_by_id: Dictionary = {100: lord}
	var next_id: Array = [1]

	DayOrchestrator._process_strategic_court_calls(
		directives, courts, topics, chars_by_id, next_id, 50,
	)

	assert_eq(courts.size(), 1)
	assert_eq(courts[0].host_lord_id, 100)
	assert_eq(courts[0].start_ic_day, 51, "Strategic court starts next day")
	assert_eq(courts[0].court_type, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT)


func test_strategic_call_court_champion_gets_clan_type():
	var champion := _make_lord(100, "10", "Lion", 8.0)
	var directives: Array = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 100,
	}]
	var courts: Array = []
	var topics: Array = []
	var chars_by_id: Dictionary = {100: champion}
	var next_id: Array = [1]

	DayOrchestrator._process_strategic_court_calls(
		directives, courts, topics, chars_by_id, next_id, 50,
	)

	assert_eq(courts.size(), 1)
	assert_eq(courts[0].court_type, CourtSessionData.CourtType.CLAN_CHAMPION_COURT)


func test_strategic_call_court_blocked_by_active_court():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var existing := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(existing, 45)
	var directives: Array = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 100,
	}]
	var courts: Array = [existing]
	var topics: Array = []
	var chars_by_id: Dictionary = {100: lord}
	var next_id: Array = [2]

	DayOrchestrator._process_strategic_court_calls(
		directives, courts, topics, chars_by_id, next_id, 50,
	)

	assert_eq(courts.size(), 1, "Should not add second court when one is active")


func test_strategic_call_court_tracks_last_court_season():
	var lord := _make_lord(100, "10", "Crane", 6.0)
	var directives: Array = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 100,
	}]
	var courts: Array = []
	var topics: Array = []
	var chars_by_id: Dictionary = {100: lord}
	var next_id: Array = [1]
	var world_states: Dictionary = {}

	DayOrchestrator._process_strategic_court_calls(
		directives, courts, topics, chars_by_id, next_id, 50,
		world_states, 2,
	)

	var ws: Dictionary = world_states.get(100, {})
	assert_eq(ws.get("last_court_season", -1), 2, "Should track season of court call")
	assert_eq(ws.get("last_court_called_ic_day", -1), 50)


func test_status_to_lord_rank_mapping():
	assert_eq(DayOrchestrator._status_to_lord_rank(10.0), Enums.LordRank.IMPERIAL)
	assert_eq(DayOrchestrator._status_to_lord_rank(9.0), Enums.LordRank.IMPERIAL)
	assert_eq(DayOrchestrator._status_to_lord_rank(8.0), Enums.LordRank.CLAN_CHAMPION)
	assert_eq(DayOrchestrator._status_to_lord_rank(7.0), Enums.LordRank.CLAN_CHAMPION)
	assert_eq(DayOrchestrator._status_to_lord_rank(6.0), Enums.LordRank.FAMILY_DAIMYO)
	assert_eq(DayOrchestrator._status_to_lord_rank(5.0), Enums.LordRank.PROVINCIAL_DAIMYO)
	assert_eq(DayOrchestrator._status_to_lord_rank(4.0), Enums.LordRank.CITY_DAIMYO)


# -- Renege Historical Modifier (s15.2) ----------------------------------------

func _make_renege_commitment(lord_id: int, witnesses: Array) -> CourtCommitmentData:
	var c: CourtCommitmentData = CourtCommitmentSystem.create_commitment(
		lord_id, 10, "send_supplies",
		CourtCommitmentData.CommitmentSource.VOLUNTARY,
		100, 200,
	)
	c.witness_ids = witnesses
	return c


func _make_char(id: int, honor: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.honor = honor
	return c


func test_renege_applies_historical_modifier_to_witness() -> void:
	var lord: L5RCharacterData = _make_char(1)
	var witness: L5RCharacterData = _make_char(2)
	var characters_by_id: Dictionary = {1: lord, 2: witness}
	var cc: CourtCommitmentData = _make_renege_commitment(1, [2])
	var topics: Array = []
	var next_id: Array = [1]
	DayOrchestrator._process_commitment_seasonal(
		[cc], [], 201, characters_by_id, topics, next_id,
	)
	assert_true(witness.historical_modifiers.has(1))
	var mods: Array = witness.historical_modifiers[1]
	assert_eq(mods.size(), 1)
	assert_eq(mods[0].get("event_type", ""), "reneged_commitment")


func test_renege_skips_historical_modifier_when_no_witnesses() -> void:
	var lord: L5RCharacterData = _make_char(1)
	var characters_by_id: Dictionary = {1: lord}
	var cc: CourtCommitmentData = _make_renege_commitment(1, [])
	var topics: Array = []
	var next_id: Array = [1]
	DayOrchestrator._process_commitment_seasonal(
		[cc], [], 201, characters_by_id, topics, next_id,
	)
	# Lord's own modifier dict should not have self-entry.
	assert_false(lord.historical_modifiers.has(1))


func test_renege_excludes_reneging_lord_from_own_modifier() -> void:
	var lord: L5RCharacterData = _make_char(1)
	var witness: L5RCharacterData = _make_char(2)
	var characters_by_id: Dictionary = {1: lord, 2: witness}
	# Include lord's own ID in witness list — should be skipped.
	var cc: CourtCommitmentData = _make_renege_commitment(1, [1, 2])
	var topics: Array = []
	var next_id: Array = [1]
	DayOrchestrator._process_commitment_seasonal(
		[cc], [], 201, characters_by_id, topics, next_id,
	)
	# Witness gets modifier; lord does not get self-referential modifier.
	assert_true(witness.historical_modifiers.has(1))
	assert_false(lord.historical_modifiers.has(1))
	assert_eq(DayOrchestrator._status_to_lord_rank(2.0), Enums.LordRank.VILLAGE_HEADMAN)


# =============================================================================
# SESSION STATE TRACKING (s15.4)
# =============================================================================


func test_session_state_initialized_on_first_access() -> void:
	var court := _make_court()
	var state: Dictionary = CourtSystem.get_session_state(court, 1)
	assert_eq(state["charm_count"], 0)
	assert_eq(state["negotiate_count"], 0)
	assert_true(state["tn_reductions"] is Dictionary)
	assert_true(state["persuade_tn_reductions"] is Dictionary)


func test_charm_count_increments() -> void:
	var court := _make_court()
	CourtSystem.increment_charm_count(court, 1)
	assert_eq(CourtSystem.get_charm_count(court, 1), 1)
	CourtSystem.increment_charm_count(court, 1)
	assert_eq(CourtSystem.get_charm_count(court, 1), 2)


func test_negotiate_count_increments() -> void:
	var court := _make_court()
	CourtSystem.increment_negotiate_count(court, 1)
	assert_eq(CourtSystem.get_negotiate_count(court, 1), 1)


func test_tn_reduction_recorded_and_retrieved() -> void:
	var court := _make_court()
	CourtSystem.record_tn_reduction(court, 1, 2, 5)
	assert_eq(CourtSystem.get_tn_reduction(court, 1, 2), 5)
	CourtSystem.record_tn_reduction(court, 1, 2, 5)
	assert_eq(CourtSystem.get_tn_reduction(court, 1, 2), 10)


func test_persuade_tn_reduction_separate_from_general() -> void:
	var court := _make_court()
	CourtSystem.record_tn_reduction(court, 1, 2, 5)
	CourtSystem.record_persuade_tn_reduction(court, 1, 2, 5)
	assert_eq(CourtSystem.get_tn_reduction(court, 1, 2), 5)
	assert_eq(CourtSystem.get_persuade_tn_reduction(court, 1, 2), 5)


func test_session_state_per_character_independent() -> void:
	var court := _make_court()
	CourtSystem.increment_charm_count(court, 1)
	CourtSystem.increment_charm_count(court, 1)
	CourtSystem.increment_charm_count(court, 2)
	assert_eq(CourtSystem.get_charm_count(court, 1), 2)
	assert_eq(CourtSystem.get_charm_count(court, 2), 1)


func test_tn_reduction_default_zero_for_unknown_target() -> void:
	var court := _make_court()
	CourtSystem.record_tn_reduction(court, 1, 2, 5)
	assert_eq(CourtSystem.get_tn_reduction(court, 1, 99), 0)


# =============================================================================
# PROXY MANDATE SYSTEM (s16.2)
# =============================================================================


func test_assign_proxy_mandate_creates_mandate() -> void:
	var court := _make_court()
	var mandate: ProxyMandateData = CourtSystem.assign_proxy_mandate(
		court, 100, 200, 5, true, 20, 50
	)
	assert_not_null(mandate)
	assert_eq(mandate.lord_id, 100)
	assert_eq(mandate.proxy_id, 200)
	assert_eq(mandate.mandate_topic_id, 5)
	assert_true(mandate.decision_authority)
	assert_eq(mandate.depth_limit, 20)
	assert_eq(mandate.court_id, court.court_id)


func test_get_proxy_mandate_finds_by_proxy_id() -> void:
	var court := _make_court()
	CourtSystem.assign_proxy_mandate(court, 100, 200, 5, true, 20, 50)
	CourtSystem.assign_proxy_mandate(court, 101, 201, 6, false, -1, 50)
	var m: ProxyMandateData = CourtSystem.get_proxy_mandate(court, 201)
	assert_not_null(m)
	assert_eq(m.lord_id, 101)
	assert_eq(m.mandate_topic_id, 6)
	assert_false(m.decision_authority)


func test_get_proxy_mandate_returns_null_for_unknown() -> void:
	var court := _make_court()
	var m: ProxyMandateData = CourtSystem.get_proxy_mandate(court, 999)
	assert_null(m)


func test_is_within_mandate_correct_topic_and_amount() -> void:
	var mandate := ProxyMandateData.new()
	mandate.mandate_topic_id = 5
	mandate.decision_authority = true
	mandate.depth_limit = 20
	assert_true(CourtSystem.is_within_mandate(mandate, 5, 15))
	assert_true(CourtSystem.is_within_mandate(mandate, 5, 20))


func test_is_within_mandate_exceeds_depth_limit() -> void:
	var mandate := ProxyMandateData.new()
	mandate.mandate_topic_id = 5
	mandate.decision_authority = true
	mandate.depth_limit = 20
	assert_false(CourtSystem.is_within_mandate(mandate, 5, 21))


func test_is_within_mandate_wrong_topic() -> void:
	var mandate := ProxyMandateData.new()
	mandate.mandate_topic_id = 5
	mandate.decision_authority = true
	mandate.depth_limit = 20
	assert_false(CourtSystem.is_within_mandate(mandate, 6, 15))


func test_is_within_mandate_no_decision_authority() -> void:
	var mandate := ProxyMandateData.new()
	mandate.mandate_topic_id = 5
	mandate.decision_authority = false
	mandate.depth_limit = 20
	assert_false(CourtSystem.is_within_mandate(mandate, 5, 10))


func test_is_within_mandate_unlimited_depth() -> void:
	var mandate := ProxyMandateData.new()
	mandate.mandate_topic_id = 5
	mandate.decision_authority = true
	mandate.depth_limit = -1
	assert_true(CourtSystem.is_within_mandate(mandate, 5, 999))


func test_flag_out_of_mandate() -> void:
	var mandate := ProxyMandateData.new()
	assert_false(mandate.out_of_mandate_flag)
	CourtSystem.flag_out_of_mandate(mandate)
	assert_true(mandate.out_of_mandate_flag)


func test_flag_out_of_mandate_null_safe() -> void:
	CourtSystem.flag_out_of_mandate(null)
	assert_true(true)


# =============================================================================
# POSITION RESISTANCE (s16.4)
# =============================================================================


func test_position_resistance_zero_relevance_full_shift() -> void:
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 0.0)
	assert_almost_eq(result, 12.0, 0.01)


func test_position_resistance_50_relevance_halves_shift() -> void:
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 50.0)
	assert_almost_eq(result, 8.0, 0.01)


func test_position_resistance_100_relevance_halves_shift() -> void:
	var result: float = TopicMomentumSystem.calculate_position_resistance(12.0, 100.0)
	assert_almost_eq(result, 6.0, 0.01)


func test_position_resistance_applied_in_court_effects() -> void:
	var target := _make_char(2)
	target.topic_positions[10] = 0.0
	var characters_by_id: Dictionary = {2: target}
	# Momentum 50 + DISTANT (no clan match) + TIER_3 → relevance = 50.0
	var topic := _make_topic(10, 50.0)
	var topics: Array = [topic]
	var courts: Array = []

	var day_results: Array = [{
		"action_id": "NEGOTIATE",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"disposition_change": 9,
			"target_position_shift": 12.0,
			"_action_metadata": {"topic_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	# relevance = 50 * 1.0 = 50; shift = 12.0 / 1.5 = 8.0
	assert_almost_eq(target.topic_positions[10], 8.0, 0.01)


func test_position_resistance_zero_relevance_in_effects() -> void:
	var target := _make_char(2)
	target.topic_positions[10] = 0.0
	var characters_by_id: Dictionary = {2: target}
	# Momentum 0 → relevance = 0; full shift applied
	var topic := _make_topic(10, 0.0)
	var topics: Array = [topic]
	var courts: Array = []

	var day_results: Array = [{
		"action_id": "PERSUADE",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"disposition_change": 11,
			"target_position_shift": 12.0,
			"_action_metadata": {"topic_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	assert_almost_eq(target.topic_positions[10], 12.0, 0.01)


func test_position_resistance_debate_per_witness() -> void:
	var witness := _make_char(3)
	witness.clan = "Crane"
	witness.topic_positions[10] = 0.0
	var characters_by_id: Dictionary = {1: _make_char(1), 2: _make_char(2), 3: witness}
	# TIER_2, momentum 50, witness same clan → OWN → 50*2.0 = 100 relevance
	var topic := _make_topic(10, 50.0)
	topic.tier = TopicData.Tier.TIER_2
	topic.clan_involved = "Crane"
	var topics: Array = [topic]
	var courts: Array = []

	var day_results: Array = [{
		"action_id": "PUBLIC_DEBATE",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"debate_per_witness": [
				{
					"witness_id": 3,
					"a_disposition_change": 2,
					"b_disposition_change": -2,
					"position_shift_toward_a": 6.0,
				},
			],
			"_action_metadata": {"topic_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	# relevance = 50*2.0 = 100; shift = 6.0 / 2.0 = 3.0
	assert_almost_eq(witness.topic_positions[10], 3.0, 0.01)


func test_session_state_wired_in_effects_charm() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(court, 50)
	var target := _make_char(2)
	var characters_by_id: Dictionary = {1: _make_char(1), 2: target}
	var topics: Array = []
	var courts: Array = [court]

	var day_results: Array = [{
		"action_id": "CHARM",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"disposition_change": 8,
			"_action_metadata": {"court_settlement_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	assert_eq(CourtSystem.get_charm_count(court, 1), 1)


func test_session_state_wired_in_effects_negotiate_tn() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(court, 50)
	var target := _make_char(2)
	var characters_by_id: Dictionary = {1: _make_char(1), 2: target}
	var topics: Array = []
	var courts: Array = [court]

	var day_results: Array = [{
		"action_id": "NEGOTIATE",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"disposition_change": 9,
			"session_tn_reduction": 5,
			"_action_metadata": {"court_settlement_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	assert_eq(CourtSystem.get_negotiate_count(court, 1), 1)
	assert_eq(CourtSystem.get_tn_reduction(court, 1, 2), 5)


func test_session_state_listen_reflect_persuade_tn() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(court, 50)
	var target := _make_char(2)
	var characters_by_id: Dictionary = {1: _make_char(1), 2: target}
	var topics: Array = []
	var courts: Array = [court]

	var day_results: Array = [{
		"action_id": "LISTEN_REFLECT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"disposition_change": 11,
			"persuade_negotiate_tn_reduction": 5,
			"_action_metadata": {"court_settlement_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	assert_eq(CourtSystem.get_persuade_tn_reduction(court, 1, 2), 5)


func test_session_state_failed_action_not_tracked() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(court, 50)
	var characters_by_id: Dictionary = {1: _make_char(1), 2: _make_char(2)}
	var topics: Array = []
	var courts: Array = [court]

	var day_results: Array = [{
		"action_id": "CHARM",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"failed": true,
			"disposition_change": -5,
			"_action_metadata": {"court_settlement_id": 10},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 0, -1,
		StrategicReview.EmperorArchetype.IRON, topics, courts
	)
	assert_eq(CourtSystem.get_charm_count(court, 1), 0)


# =============================================================================
# NPC ENGINE INTEGRATION — Context and Metadata Wiring
# =============================================================================


func test_court_context_flags_set_session_state() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT, 100, 10, "Crane")
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 1)
	CourtSystem.increment_charm_count(court, 1)
	var world_states: Dictionary = {}
	DayOrchestrator._set_court_context_flags([court], world_states)
	var ws: Dictionary = world_states.get(1, {})
	assert_eq(ws.get("court_settlement_id", -1), 10)
	var ss: Dictionary = ws.get("court_session_state", {})
	assert_eq(ss.get("charm_count", 0), 1)


func test_court_context_flags_set_settlement_id() -> void:
	var court := _make_court(1, CourtSessionData.CourtType.CLAN_CHAMPION_COURT, 100, 42, "Lion")
	CourtSystem.open_court(court, 50)
	CourtSystem.add_attendee(court, 5)
	var world_states: Dictionary = {}
	DayOrchestrator._set_court_context_flags([court], world_states)
	assert_eq(world_states[5]["court_settlement_id"], 42)


func test_build_context_reads_court_session_state() -> void:
	var character := _make_char(1)
	character.physical_location = "10"
	var world_state: Dictionary = {
		"court_session_state": {"charm_count": 3, "negotiate_count": 1, "tn_reductions": {}, "persuade_tn_reductions": {}},
		"court_settlement_id": 10,
	}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(character, world_state)
	assert_eq(ctx.court_session_state.get("charm_count", 0), 3)
	assert_eq(ctx.court_settlement_id, 10)


func test_metadata_negotiate_has_session_count() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "NEGOTIATE"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {"charm_count": 0, "negotiate_count": 4, "tn_reductions": {}, "persuade_tn_reductions": {}}
	ctx.court_settlement_id = 10
	ctx.active_court_at_location = {"topics": [5]}
	ctx.known_topics = [5]
	ctx.known_positions = {5: 30.0}
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("session_negotiate_count", -1), 4)
	assert_eq(option.metadata.get("topic_id", -1), 5)
	assert_eq(option.metadata.get("court_settlement_id", -1), 10)
	assert_true(option.metadata.get("has_topic", false))


func test_metadata_charm_has_session_count() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {"charm_count": 2, "negotiate_count": 0, "tn_reductions": {}, "persuade_tn_reductions": {}}
	ctx.court_settlement_id = 10
	ctx.active_court_at_location = {"topics": [5]}
	ctx.known_topics = [5]
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("session_charm_count", -1), 2)
	assert_eq(option.metadata.get("court_settlement_id", -1), 10)
	assert_true(option.metadata.get("has_topic", false))


func test_metadata_impress_has_topic_and_settlement() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "IMPRESS"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {}
	ctx.court_settlement_id = 15
	ctx.active_court_at_location = {"topics": [7]}
	ctx.known_topics = [7]
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_true(option.metadata.get("has_topic", false))
	assert_eq(option.metadata.get("court_settlement_id", -1), 15)
	assert_false(option.metadata.has("topic_id"))


func test_metadata_listen_reflect_has_topic() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "LISTEN_REFLECT"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {}
	ctx.court_settlement_id = 20
	ctx.active_court_at_location = {"topics": [3]}
	ctx.known_topics = [3]
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_true(option.metadata.get("has_topic", false))
	assert_eq(option.metadata.get("court_settlement_id", -1), 20)


func test_metadata_has_topic_false_when_no_known_topics() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {}
	ctx.court_settlement_id = 10
	ctx.active_court_at_location = {"topics": [5, 6]}
	ctx.known_topics = []
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_false(option.metadata.get("has_topic", true))


func test_metadata_public_debate_has_topic_id() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "PUBLIC_DEBATE"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.court_session_state = {}
	ctx.court_settlement_id = 10
	ctx.active_court_at_location = {"topics": [8]}
	ctx.known_topics = [8]
	ctx.known_positions = {8: -20.0}
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("topic_id", -1), 8)
	assert_true(option.metadata.get("has_topic", false))


func test_compute_topic_relevance_distant_clan() -> void:
	var topic := _make_topic(1, 50.0)
	var character := _make_char(1)
	var relevance: float = DayOrchestrator._compute_topic_relevance(topic, character)
	# DISTANT (no clan match): 50 * 1.0 = 50.0, TIER_3 cap 60 → 50.0
	assert_almost_eq(relevance, 50.0, 0.01)


func test_compute_topic_relevance_own_clan() -> void:
	var topic := _make_topic(1, 30.0)
	topic.clan_involved = "Crane"
	var character := _make_char(1)
	character.clan = "Crane"
	var relevance: float = DayOrchestrator._compute_topic_relevance(topic, character)
	# OWN: 30 * 2.0 = 60.0, TIER_3 cap 60 → 60.0
	assert_almost_eq(relevance, 60.0, 0.01)


func test_compute_topic_relevance_null_topic() -> void:
	var character := _make_char(1)
	var relevance: float = DayOrchestrator._compute_topic_relevance(null, character)
	assert_almost_eq(relevance, 0.0, 0.01)


func test_compute_topic_relevance_own_family() -> void:
	var topic := _make_topic(1, 20.0)
	topic.tier = TopicData.Tier.TIER_2
	topic.clan_involved = "Crane"
	topic.family_involved = "Doji"
	var character := _make_char(1)
	character.clan = "Crane"
	character.family = "Doji"
	var relevance: float = DayOrchestrator._compute_topic_relevance(topic, character)
	# OWN: 20*2.0=40 + family_own 20 = 60.0, TIER_2 no cap
	assert_almost_eq(relevance, 60.0, 0.01)
