extends GutTest
## Tests for ImperialEdictSystem — Imperial Edict issuance and compliance
## per GDD s15.1, s15.2, s55.10.1.


# -- Helpers -------------------------------------------------------------------

func _make_emperor(id: int = 1, clan: String = "Imperial") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = 10.0
	return c


func _make_topic(
	id: int,
	momentum: float,
	topic_type: String = "",
	category: TopicData.Category = TopicData.Category.POLITICAL,
	clan: String = "",
	tier: TopicData.Tier = TopicData.Tier.TIER_3,
) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.momentum = momentum
	t.topic_type = topic_type
	t.category = category
	t.clan_involved = clan
	t.tier = tier
	return t


func _make_war(id: int, clan_a: String, clan_b: String, seasons: int = 3) -> WarData:
	var w := WarData.new()
	w.war_id = id
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.seasons_active = seasons
	w.war_score_a = 50
	w.war_score_b = 50
	return w


# =============================================================================
# EDICT CREATION
# =============================================================================

func test_create_edict():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50, 10
	)
	assert_eq(e.edict_id, 1)
	assert_eq(e.edict_type, EdictData.EdictType.CEASE_HOSTILITIES)
	assert_eq(e.emperor_id, 100)
	assert_eq(e.ic_day_issued, 50)
	assert_eq(e.court_id, 10)
	assert_true(e.is_active)


func test_create_edict_default_court():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 50
	)
	assert_eq(e.court_id, -1)


# =============================================================================
# WINTER COURT EDICT GENERATION
# =============================================================================

func test_generate_edicts_war_topic():
	var emperor := _make_emperor()
	var war := _make_war(10, "Lion", "Crane", 3)
	var topic := _make_topic(10, 80.0, "war", TopicData.Category.MILITARY, "Lion")
	var wars: Array[WarData] = [war]
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT,
		[10], topics, wars, next_id, 100
	)
	assert_eq(edicts.size(), 1)
	assert_eq(edicts[0].edict_type, EdictData.EdictType.CEASE_HOSTILITIES)
	assert_eq(edicts[0].target_war_id, 10)


func test_generate_edicts_warlike_blocks_ceasefire():
	var emperor := _make_emperor()
	var war := _make_war(10, "Lion", "Crane")
	var topic := _make_topic(10, 80.0, "war", TopicData.Category.MILITARY, "Lion")
	var wars: Array[WarData] = [war]
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.WARLIKE,
		[10], topics, wars, next_id, 100
	)
	assert_eq(edicts.size(), 0, "Warlike emperor won't issue ceasefire")


func test_generate_edicts_famine_topic():
	var emperor := _make_emperor()
	var topic := _make_topic(5, 60.0, "famine", TopicData.Category.ECONOMIC, "Crab")
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT,
		[5], topics, [], next_id, 100
	)
	assert_eq(edicts.size(), 1)
	assert_eq(edicts[0].edict_type, EdictData.EdictType.TAX_REFORM)
	assert_eq(edicts[0].target_clan, "Crab")


func test_generate_edicts_tier1_general_decree():
	var emperor := _make_emperor()
	var topic := _make_topic(7, 90.0, "crisis", TopicData.Category.SUPERNATURAL, "", TopicData.Tier.TIER_1)
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		[7], topics, [], next_id, 100
	)
	assert_true(edicts.size() >= 1)
	assert_eq(edicts[0].edict_type, EdictData.EdictType.GENERAL_DECREE)


func test_generate_edicts_respects_max():
	var emperor := _make_emperor()
	var topics: Array[TopicData] = []
	var agenda: Array[int] = []
	for i in range(5):
		var t := _make_topic(i, 90.0, "crisis", TopicData.Category.POLITICAL, "", TopicData.Tier.TIER_1)
		topics.append(t)
		agenda.append(i)
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		agenda, topics, [], next_id, 100
	)
	assert_true(edicts.size() <= ImperialEdictSystem.MAX_EDICTS_PER_WINTER_COURT)


func test_generate_edicts_iron_issues_more():
	var emperor := _make_emperor()
	var topics: Array[TopicData] = []
	var agenda: Array[int] = []
	for i in range(3):
		var t := _make_topic(i, 90.0, "crisis", TopicData.Category.POLITICAL, "", TopicData.Tier.TIER_1)
		topics.append(t)
		agenda.append(i)
	var next_id_iron: Array[int] = [1]
	var next_id_benevolent: Array[int] = [100]

	var iron_edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		agenda, topics, [], next_id_iron, 100
	)
	var benevolent_edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT,
		agenda, topics, [], next_id_benevolent, 100
	)
	assert_true(iron_edicts.size() >= benevolent_edicts.size(),
		"Iron emperor issues at least as many edicts")


func test_generate_edicts_skips_resolved():
	var emperor := _make_emperor()
	var topic := _make_topic(1, 80.0, "war", TopicData.Category.MILITARY, "Lion")
	topic.resolved = true
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		[1], topics, [], next_id, 100
	)
	assert_eq(edicts.size(), 0)


func test_ceasefire_requires_minimum_seasons():
	var emperor := _make_emperor()
	var war := _make_war(10, "Lion", "Crane", 1)
	var topic := _make_topic(10, 80.0, "war", TopicData.Category.MILITARY, "Lion")
	var wars: Array[WarData] = [war]
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		[10], topics, wars, next_id, 100
	)
	assert_eq(edicts.size(), 0, "Iron emperor waits 2+ seasons for ceasefire")


func test_benevolent_ceasefire_ignores_duration():
	var emperor := _make_emperor()
	var war := _make_war(10, "Lion", "Crane", 1)
	var topic := _make_topic(10, 80.0, "war", TopicData.Category.MILITARY, "Lion")
	var wars: Array[WarData] = [war]
	var topics: Array[TopicData] = [topic]
	var next_id: Array[int] = [1]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT,
		[10], topics, wars, next_id, 100
	)
	assert_eq(edicts.size(), 1, "Benevolent emperor issues ceasefire regardless of duration")


# =============================================================================
# COMPLIANCE
# =============================================================================

func test_record_compliance():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.compliance_by_clan = {"Lion": EdictData.ComplianceStatus.PENDING, "Crane": EdictData.ComplianceStatus.PENDING}
	ImperialEdictSystem.record_compliance(e, "Lion", true)
	assert_false(ImperialEdictSystem.is_clan_defiant(e, "Lion"))
	assert_eq(e.compliance_by_clan["Lion"], EdictData.ComplianceStatus.COMPLIANT)


func test_record_defiance():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.compliance_by_clan = {"Lion": EdictData.ComplianceStatus.PENDING}
	ImperialEdictSystem.record_compliance(e, "Lion", false)
	assert_true(ImperialEdictSystem.is_clan_defiant(e, "Lion"))


func test_get_defiant_clans():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.compliance_by_clan = {
		"Lion": EdictData.ComplianceStatus.DEFIANT,
		"Crane": EdictData.ComplianceStatus.COMPLIANT,
		"Crab": EdictData.ComplianceStatus.DEFIANT,
	}
	var defiant := ImperialEdictSystem.get_defiant_clans(e)
	assert_eq(defiant.size(), 2)
	assert_true("Lion" in defiant)
	assert_true("Crab" in defiant)


func test_are_all_compliant():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.compliance_by_clan = {
		"Lion": EdictData.ComplianceStatus.COMPLIANT,
		"Crane": EdictData.ComplianceStatus.COMPLIANT,
	}
	assert_true(ImperialEdictSystem.are_all_compliant(e))


func test_are_all_compliant_false():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.compliance_by_clan = {
		"Lion": EdictData.ComplianceStatus.COMPLIANT,
		"Crane": EdictData.ComplianceStatus.PENDING,
	}
	assert_false(ImperialEdictSystem.are_all_compliant(e))


# =============================================================================
# DEFIANCE CONSEQUENCES
# =============================================================================

func test_defiance_consequences():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	var result := ImperialEdictSystem.compute_defiance_consequences(e, "Lion")
	assert_eq(result["clan"], "Lion")
	assert_eq(result["honor_cost"], ImperialEdictSystem.DEFIANCE_HONOR_COST)
	assert_eq(result["disposition_from_emperor"], ImperialEdictSystem.DEFIANCE_DISPOSITION_FROM_EMPEROR)
	assert_eq(result["disposition_from_others"], ImperialEdictSystem.DEFIANCE_DISPOSITION_FROM_OTHERS)


# =============================================================================
# APPLY CEASE HOSTILITIES
# =============================================================================

func test_apply_cease_hostilities():
	var war := _make_war(10, "Lion", "Crane")
	var wars: Array[WarData] = [war]
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.target_war_id = 10
	var result := ImperialEdictSystem.apply_cease_hostilities(e, wars)
	assert_true(result.get("resolution", "") == "imperial_edict")
	assert_eq(result["edict_id"], 1)


func test_apply_cease_hostilities_wrong_type():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.TAX_REFORM, 100, 50)
	var result := ImperialEdictSystem.apply_cease_hostilities(e, [])
	assert_false(result.get("applied", true))


func test_apply_cease_hostilities_war_not_found():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	e.target_war_id = 999
	var result := ImperialEdictSystem.apply_cease_hostilities(e, [])
	assert_false(result.get("applied", true))


# =============================================================================
# APPLY CONDEMN CLAN
# =============================================================================

func test_apply_condemn_clan():
	var war := _make_war(10, "Lion", "Crane")
	var wars: Array[WarData] = [war]
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CONDEMN_CLAN, 100, 50)
	e.target_clan = "Lion"
	var result := ImperialEdictSystem.apply_condemn_clan(e, wars)
	assert_true(result.get("applied", false))
	assert_eq(result["war_score_shifts"].size(), 1)
	assert_eq(result["war_score_shifts"][0]["beneficiary"], "Crane")
	assert_eq(result["war_score_shifts"][0]["shift"], ImperialEdictSystem.CONDEMN_WAR_SCORE_SHIFT)


func test_apply_condemn_wrong_type():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.TAX_REFORM, 100, 50)
	var result := ImperialEdictSystem.apply_condemn_clan(e, [])
	assert_false(result.get("applied", true))


# =============================================================================
# TOPIC GENERATION
# =============================================================================

func test_edict_topic_cease_hostilities():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	var topic := ImperialEdictSystem.generate_edict_topic(e)
	assert_eq(topic["topic_type"], "imperial_edict")
	assert_eq(topic["variant"], "cease_hostilities")
	assert_eq(topic["tier"], TopicData.Tier.TIER_1)
	assert_eq(topic["momentum"], 80.0)


func test_edict_topic_tax_reform():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.TAX_REFORM, 100, 50)
	var topic := ImperialEdictSystem.generate_edict_topic(e)
	assert_eq(topic["tier"], TopicData.Tier.TIER_2)
	assert_eq(topic["momentum"], 50.0)


func test_defiance_topic():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50)
	var topic := ImperialEdictSystem.generate_defiance_topic(e, "Lion")
	assert_eq(topic["topic_type"], "edict_defiance")
	assert_eq(topic["tier"], TopicData.Tier.TIER_1)
	assert_true(topic["momentum"] >= 90.0)
	assert_eq(topic["clan_involved"], "Lion")


# =============================================================================
# ARCHETYPE EDICT BEHAVIOR
# =============================================================================

func test_benevolent_wont_condemn():
	assert_false(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.BENEVOLENT,
		EdictData.EdictType.CONDEMN_CLAN, -50
	))


func test_tyrant_condemns_at_rival():
	assert_true(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.TYRANT,
		EdictData.EdictType.CONDEMN_CLAN, -11
	))


func test_iron_condemns_at_enemy():
	assert_true(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.IRON,
		EdictData.EdictType.CONDEMN_CLAN, -31
	))
	assert_false(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.IRON,
		EdictData.EdictType.CONDEMN_CLAN, -10
	))


func test_warlike_authorizes_war():
	assert_true(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.WARLIKE,
		EdictData.EdictType.AUTHORIZE_WAR, 0
	))


func test_benevolent_wont_authorize_war():
	assert_false(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.BENEVOLENT,
		EdictData.EdictType.AUTHORIZE_WAR, 0
	))


func test_only_tyrant_strips_autonomy():
	assert_true(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.TYRANT,
		EdictData.EdictType.STRIP_AUTONOMY, 0
	))
	assert_false(ImperialEdictSystem.would_emperor_issue_edict(
		StrategicReview.EmperorArchetype.IRON,
		EdictData.EdictType.STRIP_AUTONOMY, 0
	))


# =============================================================================
# DEACTIVATION
# =============================================================================

func test_deactivate_edict():
	var e := ImperialEdictSystem.create_edict(1, EdictData.EdictType.GENERAL_DECREE, 100, 50)
	assert_true(e.is_active)
	ImperialEdictSystem.deactivate_edict(e)
	assert_false(e.is_active)


# =============================================================================
# EDICT ID SEQUENCING
# =============================================================================

func test_edict_ids_increment():
	var emperor := _make_emperor()
	var topics: Array[TopicData] = []
	var agenda: Array[int] = []
	for i in range(3):
		var t := _make_topic(i, 90.0, "crisis", TopicData.Category.POLITICAL, "", TopicData.Tier.TIER_1)
		topics.append(t)
		agenda.append(i)
	var next_id: Array[int] = [10]

	var edicts := ImperialEdictSystem.generate_winter_court_edicts(
		emperor, StrategicReview.EmperorArchetype.IRON,
		agenda, topics, [], next_id, 100
	)
	if edicts.size() >= 2:
		assert_true(edicts[1].edict_id > edicts[0].edict_id)
	assert_true(next_id[0] > 10, "Counter incremented")


# =============================================================================
# ORCHESTRATOR WIRING — _generate_court_edicts
# =============================================================================

func _make_court_with_emperor(court_id: int, emperor_id: int) -> CourtSessionData:
	var court := CourtSessionData.new()
	court.court_id = court_id
	court.court_type = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_lord_id = emperor_id
	court.host_clan = "Imperial"
	court.emperor_present = true
	court.duration_ticks = 1
	court.elapsed_ticks = 0
	court.attendee_ids = [emperor_id]
	return court


func test_court_close_generates_edicts_when_emperor_present():
	var emperor := _make_emperor(1)
	emperor.topic_positions[100] = 60.0
	var chars_by_id: Dictionary = {1: emperor}
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
	}
	var war := _make_war(100, "Crane", "Lion", 3)
	var topic := _make_topic(100, 80.0, "war", TopicData.Category.MILITARY, "Crane")
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = [war]
	var court := _make_court_with_emperor(1, 1)
	court.agenda_topic_ids = [100]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	var results := DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 100,
		active_edicts, next_edict_id, active_wars,
		chars_by_id, world_states,
	)
	assert_true(active_edicts.size() > 0, "Edicts should be generated")
	assert_eq(active_edicts[0].edict_type, EdictData.EdictType.CEASE_HOSTILITIES)
	assert_true(results[0].get("edicts_issued", 0) > 0, "Result reports edicts")


func test_court_close_no_edicts_without_emperor():
	var lord := _make_emperor(2)
	lord.status = 6.0
	var chars_by_id: Dictionary = {2: lord}
	var topic := _make_topic(200, 80.0, "war", TopicData.Category.MILITARY, "Crane", TopicData.Tier.TIER_1)
	var active_topics: Array[TopicData] = [topic]
	var court := CourtSessionData.new()
	court.court_id = 2
	court.court_type = CourtSessionData.CourtType.CLAN_CHAMPION_COURT
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_lord_id = 2
	court.emperor_present = false
	court.duration_ticks = 1
	court.elapsed_ticks = 0
	court.agenda_topic_ids = [200]
	court.attendee_ids = [2]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 100,
		active_edicts, next_edict_id, [], chars_by_id, {},
	)
	assert_eq(active_edicts.size(), 0, "No edicts without emperor")


func test_edict_topics_created_on_court_close():
	var emperor := _make_emperor(1)
	emperor.topic_positions[300] = 60.0
	var chars_by_id: Dictionary = {1: emperor}
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
	}
	var war := _make_war(300, "Scorpion", "Lion", 4)
	var topic := _make_topic(300, 80.0, "war", TopicData.Category.MILITARY, "Scorpion")
	var active_topics: Array[TopicData] = [topic]
	var court := _make_court_with_emperor(1, 1)
	court.agenda_topic_ids = [300]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 200,
		active_edicts, next_edict_id, [war],
		chars_by_id, world_states,
	)
	var edict_topics: Array[TopicData] = []
	for t: TopicData in active_topics:
		if t.topic_type == "imperial_edict":
			edict_topics.append(t)
	assert_true(edict_topics.size() > 0, "Edict topic should be created")
	assert_eq(edict_topics[0].category, TopicData.Category.POLITICAL)


# =============================================================================
# COMPLIANCE ENFORCEMENT
# =============================================================================

func _make_clan_lord(id: int, clan: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = 6.0
	c.honor = 5.0
	return c


func test_create_edict_sets_compliance_deadline():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 50
	)
	assert_eq(e.compliance_deadline_ic_day, 80, "50 + 30 = 80")


func test_tax_reform_deadline_is_90_days():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.TAX_REFORM, 100, 50
	)
	assert_eq(e.compliance_deadline_ic_day, 140, "50 + 90 = 140")


func test_condemn_clan_has_no_grace_period():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CONDEMN_CLAN, 100, 50
	)
	assert_eq(e.compliance_deadline_ic_day, -1, "0 grace = no deadline set")


func test_pending_clans_become_defiant_at_deadline():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {
		"Crane": EdictData.ComplianceStatus.PENDING,
		"Lion": EdictData.ComplianceStatus.PENDING,
	}
	var chars: Array[L5RCharacterData] = [_make_clan_lord(10, "Crane"), _make_clan_lord(20, "Lion")]
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = [_make_war(1, "Crane", "Lion")]

	var results := ImperialEdictSystem.process_daily_compliance(edicts, wars, chars, 40)
	assert_eq(results.size(), 2, "Both clans become defiant")
	assert_true(ImperialEdictSystem.is_clan_defiant(e, "Crane"))
	assert_true(ImperialEdictSystem.is_clan_defiant(e, "Lion"))


func test_defiance_applies_honor_cost():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var lord := _make_clan_lord(10, "Crane")
	var initial_honor: float = lord.honor
	var chars: Array[L5RCharacterData] = [lord]
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = [_make_war(1, "Crane", "Lion")]

	ImperialEdictSystem.process_daily_compliance(edicts, wars, chars, 40)
	assert_lt(lord.honor, initial_honor, "Honor should decrease")


func test_ceasefire_auto_compliance_when_war_ended():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {
		"Crane": EdictData.ComplianceStatus.PENDING,
		"Lion": EdictData.ComplianceStatus.PENDING,
	}
	e.target_war_id = 1
	var chars: Array[L5RCharacterData] = []
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = []

	ImperialEdictSystem.process_daily_compliance(edicts, wars, chars, 5)
	assert_true(ImperialEdictSystem.are_all_compliant(e))
	assert_false(e.is_active, "Edict deactivated after full compliance")


func test_compliant_edict_deactivated():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.COMPLIANT}
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = []
	var chars: Array[L5RCharacterData] = []

	ImperialEdictSystem.process_daily_compliance(edicts, wars, chars, 5)
	assert_false(e.is_active)


func test_defiance_topic_generated():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var chars: Array[L5RCharacterData] = [_make_clan_lord(10, "Crane")]
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = [_make_war(1, "Crane", "Lion")]

	var results := ImperialEdictSystem.process_daily_compliance(edicts, wars, chars, 40)
	assert_eq(results.size(), 1)
	var topic_dict: Dictionary = results[0].get("defiance_topic", {})
	assert_false(topic_dict.is_empty())
	assert_eq(topic_dict["topic_type"], "edict_defiance")


func test_orchestrator_creates_defiance_topic_data():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var lord := _make_clan_lord(10, "Crane")
	var chars: Array[L5RCharacterData] = [lord]
	var edicts: Array[EdictData] = [e]
	var wars: Array[WarData] = [_make_war(1, "Crane", "Lion")]
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [500]

	var results := DayOrchestrator._process_edict_compliance(
		edicts, wars, chars, active_topics, next_topic_id, 40,
	)
	assert_eq(results.size(), 1)
	var defiance_topics: Array[TopicData] = []
	for t: TopicData in active_topics:
		if t.topic_type == "edict_defiance":
			defiance_topics.append(t)
	assert_eq(defiance_topics.size(), 1)
	assert_eq(defiance_topics[0].tier, TopicData.Tier.TIER_1)
	assert_eq(defiance_topics[0].momentum, 90.0)


func test_inactive_edict_skipped():
	var e := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	e.is_active = false
	var edicts: Array[EdictData] = [e]
	var results := ImperialEdictSystem.process_daily_compliance(edicts, [], [], 40)
	assert_eq(results.size(), 0)


# =============================================================================
# NPC COMPLIANCE ACTION WIRING
# =============================================================================

func test_comply_action_records_compliance():
	var e := ImperialEdictSystem.create_edict(
		5, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var edicts: Array[EdictData] = [e]
	var day_results: Array = [{
		"action_id": "COMPLY_WITH_EDICT",
		"effects": {
			"requires_edict_compliance": true,
			"edict_id": 5,
			"clan": "Crane",
			"compliant": true,
		},
	}]
	DayOrchestrator._process_edict_compliance_actions(day_results, edicts)
	assert_eq(e.compliance_by_clan["Crane"], EdictData.ComplianceStatus.COMPLIANT)


func test_defy_action_records_defiance():
	var e := ImperialEdictSystem.create_edict(
		6, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10
	)
	e.compliance_by_clan = {"Lion": EdictData.ComplianceStatus.PENDING}
	var edicts: Array[EdictData] = [e]
	var day_results: Array = [{
		"action_id": "DEFY_EDICT",
		"effects": {
			"requires_edict_compliance": true,
			"edict_id": 6,
			"clan": "Lion",
			"compliant": false,
		},
	}]
	DayOrchestrator._process_edict_compliance_actions(day_results, edicts)
	assert_eq(e.compliance_by_clan["Lion"], EdictData.ComplianceStatus.DEFIANT)


func test_comply_action_skips_wrong_edict_id():
	var e := ImperialEdictSystem.create_edict(
		7, EdictData.EdictType.GENERAL_DECREE, 100, 10
	)
	e.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var edicts: Array[EdictData] = [e]
	var day_results: Array = [{
		"effects": {
			"requires_edict_compliance": true,
			"edict_id": 999,
			"clan": "Crane",
			"compliant": true,
		},
	}]
	DayOrchestrator._process_edict_compliance_actions(day_results, edicts)
	assert_eq(e.compliance_by_clan["Crane"], EdictData.ComplianceStatus.PENDING, "No match — unchanged")


func test_personality_lean_favors_compliance_for_chugi():
	var loader := ScoringTableLoader.new()
	loader.load_all()
	var tables: Dictionary = loader.get_scoring_tables()
	var lean_table: Dictionary = tables.get("personality_lean", {})
	var chugi_leans: Dictionary = lean_table.get("CHUGI", {})
	assert_gt(chugi_leans.get("COMPLY_WITH_EDICT", 0), 0, "Chugi should favor compliance")
	assert_lt(chugi_leans.get("DEFY_EDICT", 0), 0, "Chugi should penalize defiance")


func test_personality_lean_favors_defiance_for_ishi():
	var loader := ScoringTableLoader.new()
	loader.load_all()
	var tables: Dictionary = loader.get_scoring_tables()
	var lean_table: Dictionary = tables.get("personality_lean", {})
	var ishi_leans: Dictionary = lean_table.get("ISHI", {})
	assert_lt(ishi_leans.get("COMPLY_WITH_EDICT", 0), 0, "Ishi should penalize compliance")
	assert_gt(ishi_leans.get("DEFY_EDICT", 0), 0, "Ishi should favor defiance")


# =============================================================================
# REACTIVE EDICT EVENT INJECTION
# =============================================================================

func _make_lord(id: int, clan: String, status: float = 7.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = status
	c.lord_id = -1
	return c


func test_inject_edict_reactive_event_for_pending_clan():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10, 5
	)
	edict.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	var lord := _make_lord(50, "Crane")
	var characters: Array[L5RCharacterData] = [lord]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var ws: Dictionary = world_states.get(50, {})
	var events: Array = ws.get("pending_events", [])
	assert_eq(events.size(), 1, "Should inject one reactive event")
	assert_eq(events[0]["need_type"], "RESPOND_TO_EDICT")
	assert_eq(events[0]["target_npc_id"], 1, "target_npc_id carries edict_id")
	assert_eq(events[0]["target_clan_id"], "Crane")
	assert_eq(events[0]["priority"], 1)
	assert_eq(events[0]["source"], "edict_response")


func test_inject_skips_compliant_clans():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Lion": EdictData.ComplianceStatus.COMPLIANT}
	var lord := _make_lord(60, "Lion")
	var characters: Array[L5RCharacterData] = [lord]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var ws: Dictionary = world_states.get(60, {})
	assert_eq(ws.get("pending_events", []).size(), 0, "No event for compliant clan")


func test_inject_skips_defiant_clans():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Scorpion": EdictData.ComplianceStatus.DEFIANT}
	var lord := _make_lord(70, "Scorpion")
	var characters: Array[L5RCharacterData] = [lord]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var ws: Dictionary = world_states.get(70, {})
	assert_eq(ws.get("pending_events", []).size(), 0, "No event for defiant clan")


func test_inject_skips_inactive_edicts():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}
	edict.is_active = false
	var lord := _make_lord(50, "Crane")
	var characters: Array[L5RCharacterData] = [lord]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var ws: Dictionary = world_states.get(50, {})
	assert_eq(ws.get("pending_events", []).size(), 0, "No event for inactive edict")


func test_inject_no_duplicate_for_same_edict():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Crab": EdictData.ComplianceStatus.PENDING}
	var lord := _make_lord(80, "Crab")
	var characters: Array[L5RCharacterData] = [lord]
	var world_states: Dictionary = {
		80: {
			"pending_events": [{
				"need_type": "RESPOND_TO_EDICT",
				"target_npc_id": 1,
				"source": "edict_response",
			}],
		},
	}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var events: Array = world_states[80]["pending_events"]
	assert_eq(events.size(), 1, "Should not duplicate existing edict event")


func test_inject_multiple_edicts_multiple_clans():
	var e1 := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.CEASE_HOSTILITIES, 100, 10, 5
	)
	e1.compliance_by_clan = {
		"Crane": EdictData.ComplianceStatus.PENDING,
		"Lion": EdictData.ComplianceStatus.PENDING,
	}
	var e2 := ImperialEdictSystem.create_edict(
		2, EdictData.EdictType.TAX_REFORM, 100, 10, 5
	)
	e2.compliance_by_clan = {"Crane": EdictData.ComplianceStatus.PENDING}

	var crane_lord := _make_lord(50, "Crane")
	var lion_lord := _make_lord(60, "Lion")
	var characters: Array[L5RCharacterData] = [crane_lord, lion_lord]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [e1, e2]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	var crane_events: Array = world_states.get(50, {}).get("pending_events", [])
	var lion_events: Array = world_states.get(60, {}).get("pending_events", [])
	assert_eq(crane_events.size(), 2, "Crane lord gets 2 edict events")
	assert_eq(lion_events.size(), 1, "Lion lord gets 1 edict event")


func test_inject_picks_highest_status_lord():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Dragon": EdictData.ComplianceStatus.PENDING}
	var minor_lord := _make_lord(40, "Dragon", 5.0)
	var champion := _make_lord(41, "Dragon", 8.0)
	var characters: Array[L5RCharacterData] = [minor_lord, champion]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	assert_false(world_states.has(40), "Minor lord should not get the event")
	var ws: Dictionary = world_states.get(41, {})
	assert_eq(ws.get("pending_events", []).size(), 1, "Champion gets the event")


func test_inject_no_lord_found_skips():
	var edict := ImperialEdictSystem.create_edict(
		1, EdictData.EdictType.GENERAL_DECREE, 100, 10, 5
	)
	edict.compliance_by_clan = {"Phoenix": EdictData.ComplianceStatus.PENDING}
	var vassal := L5RCharacterData.new()
	vassal.character_id = 90
	vassal.clan = "Phoenix"
	vassal.status = 3.0
	vassal.lord_id = 5
	var characters: Array[L5RCharacterData] = [vassal]
	var world_states: Dictionary = {}
	var edicts: Array[EdictData] = [edict]

	DayOrchestrator._inject_edict_reactive_events(edicts, characters, world_states, 10)

	assert_false(world_states.has(90), "No event injected when no lord found")


# =============================================================================
# AGGREGATE OPINION EDICT SELECTION (s16.4)
# =============================================================================

func _make_court(
	court_id: int = 1,
	agenda_ids: Array[int] = [],
) -> CourtSessionData:
	var c := CourtSessionData.new()
	c.court_id = court_id
	c.court_type = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	c.phase = CourtSessionData.CourtPhase.ACTIVE
	c.emperor_present = true
	c.agenda_topic_ids = agenda_ids
	return c


func _make_attendee(
	id: int,
	clan: String = "Crane",
	status: float = 5.0,
	family: String = "",
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.family = family
	c.status = status
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


# -- Emperor Weight ------------------------------------------------------------

func test_emperor_weight_formula():
	var w: float = ImperialEdictSystem.compute_emperor_weight(10.0, 100.0)
	assert_almost_eq(w, 60.0, 0.01)

func test_emperor_weight_zero_relevance():
	var w: float = ImperialEdictSystem.compute_emperor_weight(10.0, 0.0)
	assert_almost_eq(w, 0.0, 0.01)

func test_emperor_weight_half_relevance():
	var w: float = ImperialEdictSystem.compute_emperor_weight(10.0, 50.0)
	assert_almost_eq(w, 30.0, 0.01)


# -- Topic Aggregate -----------------------------------------------------------

func test_aggregate_positive_consensus():
	var topic := _make_topic(1, 50.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 50.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = 40.0
	var lord_b := _make_attendee(3, "Lion", 6.0)
	lord_b.topic_positions[1] = 30.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a, lord_b]
	var agg: float = ImperialEdictSystem.compute_topic_aggregate(topic, attendees, 100)
	assert_true(agg > ImperialEdictSystem.EDICT_POSITIVE_THRESHOLD)

func test_aggregate_negative_consensus():
	var topic := _make_topic(1, 50.0, "war", TopicData.Category.MILITARY, "Lion")
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = -60.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = -40.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a]
	var agg: float = ImperialEdictSystem.compute_topic_aggregate(topic, attendees, 100)
	assert_true(agg < ImperialEdictSystem.EDICT_NEGATIVE_THRESHOLD)

func test_aggregate_divided_no_edict():
	var topic := _make_topic(1, 50.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 10.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = 20.0
	var lord_b := _make_attendee(3, "Lion", 7.0)
	lord_b.topic_positions[1] = -20.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a, lord_b]
	var agg: float = ImperialEdictSystem.compute_topic_aggregate(topic, attendees, 100)
	assert_true(agg > ImperialEdictSystem.EDICT_NEGATIVE_THRESHOLD and agg < ImperialEdictSystem.EDICT_POSITIVE_THRESHOLD)

func test_aggregate_emperor_dominates():
	var topic := _make_topic(1, 80.0, "shadowlands_incursion", TopicData.Category.MILITARY, "Crab", TopicData.Tier.TIER_1)
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 80.0
	var lord_a := _make_attendee(2, "Scorpion", 5.0)
	lord_a.topic_positions[1] = -10.0
	var lord_b := _make_attendee(3, "Crane", 5.0)
	lord_b.topic_positions[1] = -10.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a, lord_b]
	var agg: float = ImperialEdictSystem.compute_topic_aggregate(topic, attendees, 100)
	assert_true(agg > 0.0, "Emperor x3 weight should keep aggregate positive")


# -- Generate Edicts From Aggregate --------------------------------------------

func test_generate_edicts_compelling():
	var topic := _make_topic(1, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var court := _make_court(1, [1])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 50.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = 50.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 1)
	assert_eq(result["aggregates"][0]["direction"], "compelling")
	var edict: EdictData = result["edicts"][0]
	assert_eq(edict.target_topic_id, 1)

func test_generate_edicts_blocking():
	var topic := _make_topic(1, 60.0, "war", TopicData.Category.MILITARY, "Lion")
	var court := _make_court(1, [1])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = -60.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = -50.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 1)
	assert_eq(result["aggregates"][0]["direction"], "blocking")

func test_generate_edicts_no_edict_divided():
	var topic := _make_topic(1, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var court := _make_court(1, [1])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 5.0
	var lord_a := _make_attendee(2, "Crane", 7.0)
	lord_a.topic_positions[1] = -5.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 0)
	assert_eq(result["aggregates"][0]["direction"], "none")

func test_generate_edicts_max_3():
	var topics: Array[TopicData] = []
	var ids: Array[int] = []
	for i: int in range(4):
		var t := _make_topic(i + 1, 80.0 - float(i), "famine", TopicData.Category.POLITICAL, "Crane")
		topics.append(t)
		ids.append(i + 1)
	var court := _make_court(1, ids)
	var emperor := _make_attendee(100, "Imperial", 10.0)
	var lord_a := _make_attendee(2, "Crane", 7.0)
	for t: TopicData in topics:
		emperor.topic_positions[t.topic_id] = 60.0
		lord_a.topic_positions[t.topic_id] = 60.0
	var attendees: Array[L5RCharacterData] = [emperor, lord_a]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.TYRANT, court, attendees,
		topics, active_wars, next_id, 100
	)
	assert_true(result["edicts"].size() <= ImperialEdictSystem.MAX_EDICTS_PER_WINTER_COURT)

func test_generate_edicts_top_3_momentum():
	var t1 := _make_topic(1, 90.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var t2 := _make_topic(2, 50.0, "criminal", TopicData.Category.POLITICAL, "Lion")
	var t3 := _make_topic(3, 30.0, "border_raid", TopicData.Category.MILITARY, "Dragon")
	var t4 := _make_topic(4, 10.0, "famine", TopicData.Category.POLITICAL, "Phoenix")
	var court := _make_court(1, [1, 2, 3, 4])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	for t: TopicData in [t1, t2, t3, t4]:
		emperor.topic_positions[t.topic_id] = 60.0
	var attendees: Array[L5RCharacterData] = [emperor]
	var active_topics: Array[TopicData] = [t1, t2, t3, t4]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["aggregates"].size(), 3, "Only top 3 by momentum evaluated")

func test_famine_edict_type_is_tax_reform():
	var topic := _make_topic(1, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var court := _make_court(1, [1])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 80.0
	var attendees: Array[L5RCharacterData] = [emperor]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 1)
	var edict: EdictData = result["edicts"][0]
	assert_eq(edict.edict_type, EdictData.EdictType.TAX_REFORM)

func test_war_topic_creates_cease_hostilities():
	var topic := _make_topic(1, 60.0, "war", TopicData.Category.MILITARY, "Lion")
	var court := _make_court(1, [1])
	var war := _make_war(1, "Lion", "Crane")
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 80.0
	var attendees: Array[L5RCharacterData] = [emperor]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = [war]
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.IRON, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 1)
	var edict: EdictData = result["edicts"][0]
	assert_eq(edict.edict_type, EdictData.EdictType.CEASE_HOSTILITIES)

func test_archetype_limits_edict_count():
	var topic := _make_topic(1, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var court := _make_court(1, [1])
	var emperor := _make_attendee(100, "Imperial", 10.0)
	emperor.topic_positions[1] = 80.0
	var attendees: Array[L5RCharacterData] = [emperor]
	var active_topics: Array[TopicData] = [topic]
	var active_wars: Array[WarData] = []
	var next_id: Array[int] = [1]
	var result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, court, attendees,
		active_topics, active_wars, next_id, 100
	)
	assert_eq(result["edicts"].size(), 1)


# -- Commitment Type for Crisis ------------------------------------------------

func test_commitment_type_famine():
	var t := _make_topic(1, 50.0, "famine")
	assert_eq(ImperialEdictSystem.get_commitment_type_for_topic(t), "send_supplies")

func test_commitment_type_shadowlands():
	var t := _make_topic(1, 50.0, "shadowlands_incursion")
	assert_eq(ImperialEdictSystem.get_commitment_type_for_topic(t), "send_military_aid")

func test_commitment_type_maho():
	var t := _make_topic(1, 50.0, "maho_cult")
	assert_eq(ImperialEdictSystem.get_commitment_type_for_topic(t), "send_magistrates")

func test_commitment_type_unknown():
	var t := _make_topic(1, 50.0, "unknown_crisis")
	assert_eq(ImperialEdictSystem.get_commitment_type_for_topic(t), "")


# -- Edict Commitment Generation -----------------------------------------------

func test_generate_edict_commitments():
	var topic := _make_topic(1, 50.0, "famine")
	var edict := ImperialEdictSystem.create_edict(1, EdictData.EdictType.TAX_REFORM, 100, 500)
	edict.target_topic_id = 1
	var lord_a := _make_attendee(2, "Crane", 7.0)
	var lord_b := _make_attendee(3, "Lion", 6.0)
	var lords: Array[L5RCharacterData] = [lord_a, lord_b]
	var commitments: Array[CourtCommitmentData] = ImperialEdictSystem.generate_edict_commitments(
		edict, topic, lords, 500, 590
	)
	assert_eq(commitments.size(), 2)
	assert_eq(commitments[0].lord_id, 2)
	assert_eq(commitments[0].commitment_type, "send_supplies")
	assert_eq(commitments[0].source, CourtCommitmentData.CommitmentSource.EDICT)
	assert_eq(commitments[0].deadline_ic_day, 590)
	assert_eq(commitments[1].lord_id, 3)

func test_generate_edict_commitments_unknown_type_empty():
	var topic := _make_topic(1, 50.0, "unknown_type")
	var edict := ImperialEdictSystem.create_edict(1, EdictData.EdictType.GENERAL_DECREE, 100, 500)
	var lords: Array[L5RCharacterData] = [_make_attendee(2)]
	var commitments: Array[CourtCommitmentData] = ImperialEdictSystem.generate_edict_commitments(
		edict, topic, lords, 500, 590
	)
	assert_eq(commitments.size(), 0)


# -- Orchestrator Commitment Wiring --------------------------------------------

func test_court_close_creates_commitments_for_lords():
	var emperor := _make_emperor(1)
	emperor.topic_positions[50] = 60.0
	var lord_a := _make_attendee(10, "Crane", 7.0)
	lord_a.lord_id = -1
	var lord_b := _make_attendee(11, "Lion", 6.0)
	lord_b.lord_id = -1
	var vassal := _make_attendee(12, "Crane", 3.0)
	vassal.lord_id = 10
	var chars_by_id: Dictionary = {1: emperor, 10: lord_a, 11: lord_b, 12: vassal}
	var characters: Array[L5RCharacterData] = [emperor, lord_a, lord_b, vassal]
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
	}
	var topic := _make_topic(50, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var active_topics: Array[TopicData] = [topic]
	var court := _make_court_with_emperor(1, 1)
	court.agenda_topic_ids = [50]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]
	var court_commitments: Array[CourtCommitmentData] = []

	DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 100,
		active_edicts, next_edict_id, [],
		chars_by_id, world_states,
		court_commitments, characters,
	)
	assert_true(court_commitments.size() > 0, "Commitments should be created")
	for cc: CourtCommitmentData in court_commitments:
		assert_eq(cc.source, CourtCommitmentData.CommitmentSource.EDICT)
		assert_eq(cc.commitment_type, "send_supplies")

func test_court_close_commitments_only_for_lords():
	var emperor := _make_emperor(1)
	emperor.topic_positions[50] = 60.0
	var lord := _make_attendee(10, "Crane", 7.0)
	lord.lord_id = -1
	var vassal := _make_attendee(12, "Crane", 3.0)
	vassal.lord_id = 10
	var chars_by_id: Dictionary = {1: emperor, 10: lord, 12: vassal}
	var characters: Array[L5RCharacterData] = [emperor, lord, vassal]
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
	}
	var topic := _make_topic(50, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var active_topics: Array[TopicData] = [topic]
	var court := _make_court_with_emperor(1, 1)
	court.agenda_topic_ids = [50]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]
	var court_commitments: Array[CourtCommitmentData] = []

	DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 100,
		active_edicts, next_edict_id, [],
		chars_by_id, world_states,
		court_commitments, characters,
	)
	for cc: CourtCommitmentData in court_commitments:
		assert_true(cc.lord_id == 1 or cc.lord_id == 10, "Only lord-tier chars get commitments")

func test_no_commitments_when_no_edict():
	var emperor := _make_emperor(1)
	emperor.topic_positions[50] = 5.0
	var chars_by_id: Dictionary = {1: emperor}
	var characters: Array[L5RCharacterData] = [emperor]
	var world_states: Dictionary = {
		"emperor_id": 1,
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
	}
	var topic := _make_topic(50, 60.0, "famine", TopicData.Category.POLITICAL, "Crane")
	var active_topics: Array[TopicData] = [topic]
	var court := _make_court_with_emperor(1, 1)
	court.agenda_topic_ids = [50]
	var active_courts: Array[CourtSessionData] = [court]
	var active_edicts: Array[EdictData] = []
	var next_edict_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]
	var court_commitments: Array[CourtCommitmentData] = []

	DayOrchestrator._process_active_courts(
		active_courts, active_topics, next_topic_id, 100,
		active_edicts, next_edict_id, [],
		chars_by_id, world_states,
		court_commitments, characters,
	)
	assert_eq(court_commitments.size(), 0, "No commitments when aggregate between thresholds")
