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
