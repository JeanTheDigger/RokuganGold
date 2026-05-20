extends GutTest
## Tests for WinterCourtSystem per GDD s55.10.
## Covers: host selection, disqualifiers, archetype weights, delegation pipeline,
## personal invitations, Emperor's Peace, glory rewards, regent substitution.


var _emperor: L5RCharacterData
var _chancellor: L5RCharacterData
var _characters_by_id: Dictionary
var _provinces: Array[ProvinceData]
var _settlements: Array[SettlementData]
var _topics: Array[TopicData]
var _world_state: Dictionary


func before_each() -> void:
	_emperor = _make_character(1, "Emperor", "Imperial", "Hantei", 10.0)
	_emperor.lord_id = -1
	_chancellor = _make_character(2, "Chancellor", "Imperial", "Otomo", 8.0)
	_chancellor.role_position = "Imperial Chancellor"
	_chancellor.lord_id = -1
	_characters_by_id = {1: _emperor, 2: _chancellor}
	_provinces = []
	_settlements = []
	_topics = []
	_world_state = {
		"current_season": TimeSystem.Season.AUTUMN,
		"last_host_clan_years": {},
		"current_ic_year": 5,
		"occupied_province_ids": [],
		"capital_settlement_id": 999,
	}


func _make_character(
	id: int, name: String, clan: String, family: String, status: float,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.clan = clan
	c.family = family
	c.status = status
	c.glory = 3.0
	c.honor = 5.0
	c.lord_id = 0
	c.school_type = Enums.SchoolType.COURTIER
	c.physical_location = "100"
	c.skills = {"Etiquette": 3, "Sincerity": 2, "Courtier": 3, "Perform": 1}
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_province(id: int, clan: String, family: String, stability: float) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.clan = clan
	p.family = family
	p.stability = stability
	return p


func _make_settlement(id: int, province_id: int, stype: Enums.SettlementType) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = stype
	return s


func _make_topic(id: int, provinces: Array[int], momentum: float, topic_type: String = "crisis") -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.provinces_affected = provinces
	t.momentum = momentum
	t.topic_type = topic_type
	t.resolved = false
	return t


func _setup_basic_castle() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	_provinces.append(p)
	var s := _make_settlement(100, 10, Enums.SettlementType.FAMILY_CASTLE)
	_settlements.append(s)
	var daimyo := _make_character(10, "Doji Daimyo", "Crane", "Doji", 7.5)
	daimyo.lord_id = -1
	daimyo.glory = 5.0
	_characters_by_id[10] = daimyo


# -- Host Selection Tests ------------------------------------------------------

func test_select_host_returns_empty_outside_autumn() -> void:
	_setup_basic_castle()
	_world_state["current_season"] = TimeSystem.Season.SPRING
	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.is_empty())


func test_select_host_finds_castle() -> void:
	_setup_basic_castle()
	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_false(result.is_empty())
	assert_eq(result["settlement_id"], 100)
	assert_eq(result["host_clan"], "Crane")


func test_disqualifier_capital_excluded() -> void:
	var p := _make_province(10, "Imperial", "Hantei", 90.0)
	_provinces.append(p)
	var s := _make_settlement(999, 10, Enums.SettlementType.FAMILY_CASTLE)
	_settlements.append(s)
	_world_state["capital_settlement_id"] = 999
	var daimyo := _make_character(10, "Capital Lord", "Imperial", "Hantei", 8.0)
	daimyo.lord_id = -1
	_characters_by_id[10] = daimyo

	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.is_empty())


func test_disqualifier_low_stability_excluded() -> void:
	var p := _make_province(10, "Lion", "Akodo", 25.0)
	_provinces.append(p)
	var s := _make_settlement(100, 10, Enums.SettlementType.FAMILY_CASTLE)
	_settlements.append(s)
	var daimyo := _make_character(10, "Akodo Lord", "Lion", "Akodo", 7.5)
	daimyo.lord_id = -1
	_characters_by_id[10] = daimyo

	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.is_empty())


func test_disqualifier_occupied_province_excluded() -> void:
	_setup_basic_castle()
	_world_state["occupied_province_ids"] = [10]
	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.is_empty())


func test_non_castle_settlement_excluded() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	_provinces.append(p)
	var s := _make_settlement(100, 10, Enums.SettlementType.VILLAGE)
	_settlements.append(s)
	var daimyo := _make_character(10, "Village Head", "Crane", "Doji", 7.5)
	daimyo.lord_id = -1
	_characters_by_id[10] = daimyo

	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.is_empty())


func test_stability_at_threshold_included() -> void:
	var p := _make_province(10, "Lion", "Akodo", 30.0)
	_provinces.append(p)
	var s := _make_settlement(100, 10, Enums.SettlementType.CASTLE)
	_settlements.append(s)
	var daimyo := _make_character(10, "Akodo Lord", "Lion", "Akodo", 7.5)
	daimyo.lord_id = -1
	_characters_by_id[10] = daimyo

	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_false(result.is_empty())


# -- Archetype Weight Tests ----------------------------------------------------

func test_benevolent_weights_crisis_high() -> void:
	var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.BENEVOLENT]
	assert_eq(weights["crisis_relevance"], 20)
	assert_eq(weights["clan_recency"], 15)
	assert_eq(weights["disposition"], 5)


func test_iron_weights_recency_high() -> void:
	var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.IRON]
	assert_eq(weights["clan_recency"], 25)
	assert_eq(weights["crisis_relevance"], 0)


func test_cunning_weights_disposition_high() -> void:
	var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.CUNNING]
	assert_eq(weights["disposition"], 15)
	assert_eq(weights["clan_recency"], 0)


func test_warlike_weights_crisis_highest() -> void:
	var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.WARLIKE]
	assert_eq(weights["crisis_relevance"], 25)
	assert_eq(weights["province_stability"], 0)


func test_tyrant_weights_disposition_and_prestige() -> void:
	var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.TYRANT]
	assert_eq(weights["disposition"], 20)
	assert_eq(weights["family_prestige"], 20)
	assert_eq(weights["clan_recency"], 0)


# -- Scoring Function Tests ----------------------------------------------------

func test_disposition_score_linear() -> void:
	var champion := _make_character(20, "Champ", "Crane", "Doji", 8.0)
	champion.lord_id = -1
	_emperor.disposition_values[20] = 50.0
	var score: float = WinterCourtSystem._score_disposition(
		_emperor, champion, StrategicReview.EmperorArchetype.IRON
	)
	assert_almost_eq(score, 7.5, 0.1)


func test_disposition_score_cunning_bell_curve() -> void:
	var champion := _make_character(20, "Champ", "Crane", "Doji", 8.0)
	champion.lord_id = -1
	_emperor.disposition_values[20] = 0.0
	var neutral_score: float = WinterCourtSystem._score_disposition(
		_emperor, champion, StrategicReview.EmperorArchetype.CUNNING
	)
	_emperor.disposition_values[20] = 100.0
	var extreme_score: float = WinterCourtSystem._score_disposition(
		_emperor, champion, StrategicReview.EmperorArchetype.CUNNING
	)
	assert_gt(neutral_score, extreme_score)
	assert_almost_eq(neutral_score, 10.0, 0.1)


func test_clan_recency_never_hosted() -> void:
	var score: float = WinterCourtSystem._score_clan_recency("Crane", {}, 5)
	assert_almost_eq(score, 10.0, 0.01)


func test_clan_recency_recently_hosted() -> void:
	var score: float = WinterCourtSystem._score_clan_recency("Crane", {"Crane": 4}, 5)
	assert_almost_eq(score, 10.0 / 7.0, 0.1)


func test_clan_recency_capped_at_7_years() -> void:
	var score: float = WinterCourtSystem._score_clan_recency("Crane", {"Crane": 0}, 10)
	assert_almost_eq(score, 10.0, 0.01)


func test_province_stability_score() -> void:
	var p := _make_province(1, "Crane", "Doji", 75.0)
	var score: float = WinterCourtSystem._score_province_stability(p)
	assert_almost_eq(score, 7.5, 0.01)


func test_family_prestige_score() -> void:
	var d := _make_character(20, "Daimyo", "Crane", "Doji", 8.0)
	d.glory = 6.0
	var score: float = WinterCourtSystem._score_family_prestige(d)
	assert_almost_eq(score, 7.0, 0.01)


func test_crisis_relevance_with_topic() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	var t := _make_topic(1, [10], 60.0, "war")
	_topics.append(t)
	var score: float = WinterCourtSystem._score_crisis_relevance(
		p, _topics, StrategicReview.EmperorArchetype.CUNNING
	)
	assert_almost_eq(score, 6.0, 0.01)


func test_crisis_relevance_benevolent_filters_military() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	var t := _make_topic(1, [10], 60.0, "war")
	_topics.append(t)
	var score: float = WinterCourtSystem._score_crisis_relevance(
		p, _topics, StrategicReview.EmperorArchetype.BENEVOLENT
	)
	assert_almost_eq(score, 0.0, 0.01)


func test_crisis_relevance_benevolent_accepts_famine() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	var t := _make_topic(1, [10], 60.0, "famine")
	_topics.append(t)
	var score: float = WinterCourtSystem._score_crisis_relevance(
		p, _topics, StrategicReview.EmperorArchetype.BENEVOLENT
	)
	assert_gt(score, 0.0)


func test_crisis_relevance_warlike_accepts_military() -> void:
	var p := _make_province(10, "Crane", "Doji", 80.0)
	var t := _make_topic(1, [10], 80.0, "war")
	_topics.append(t)
	var score: float = WinterCourtSystem._score_crisis_relevance(
		p, _topics, StrategicReview.EmperorArchetype.WARLIKE
	)
	assert_gt(score, 0.0)


# -- Best Castle Selection Tests -----------------------------------------------

func test_higher_scoring_castle_wins() -> void:
	var p1 := _make_province(10, "Crane", "Doji", 80.0)
	var p2 := _make_province(11, "Lion", "Akodo", 90.0)
	_provinces.append(p1)
	_provinces.append(p2)
	var s1 := _make_settlement(100, 10, Enums.SettlementType.FAMILY_CASTLE)
	var s2 := _make_settlement(101, 11, Enums.SettlementType.CASTLE)
	_settlements.append(s1)
	_settlements.append(s2)
	var d1 := _make_character(10, "Doji Lord", "Crane", "Doji", 7.5)
	d1.lord_id = -1
	d1.glory = 3.0
	var d2 := _make_character(11, "Akodo Lord", "Lion", "Akodo", 8.0)
	d2.lord_id = -1
	d2.glory = 7.0
	_characters_by_id[10] = d1
	_characters_by_id[11] = d2

	_world_state["last_host_clan_years"] = {"Crane": 3, "Lion": 0}

	var result: Dictionary = WinterCourtSystem.select_host_castle(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_false(result.is_empty())
	assert_eq(result["host_clan"], "Lion")


# -- Delegation Tests ----------------------------------------------------------

func test_delegation_capacity_provincial() -> void:
	var cap: Dictionary = WinterCourtSystem.get_delegation_capacity(Enums.LordRank.PROVINCIAL_DAIMYO)
	assert_eq(cap["total"], 70)
	assert_eq(cap["per_clan"], 8)
	assert_eq(cap["personal_invitations"], 3)


func test_delegation_capacity_family() -> void:
	var cap: Dictionary = WinterCourtSystem.get_delegation_capacity(Enums.LordRank.FAMILY_DAIMYO)
	assert_eq(cap["total"], 105)
	assert_eq(cap["per_clan"], 13)


func test_delegation_capacity_champion() -> void:
	var cap: Dictionary = WinterCourtSystem.get_delegation_capacity(Enums.LordRank.CLAN_CHAMPION)
	assert_eq(cap["total"], 150)
	assert_eq(cap["per_clan"], 19)


func test_select_clan_delegation_respects_slots() -> void:
	var champion := _make_character(20, "Crane Champ", "Crane", "Doji", 8.0)
	champion.lord_id = -1
	var vassals: Array[L5RCharacterData] = []
	for i: int in range(10):
		var v := _make_character(100 + i, "Vassal %d" % i, "Crane", "Doji", 3.0)
		v.lord_id = 20
		vassals.append(v)

	var delegation: Array[int] = WinterCourtSystem.select_clan_delegation(
		champion, vassals, 3, [], {}
	)
	assert_eq(delegation.size(), 3)


func test_delegation_scores_courtiers_higher() -> void:
	var champion := _make_character(20, "Champ", "Crane", "Doji", 8.0)
	champion.lord_id = -1
	var courtier := _make_character(100, "Courtier", "Crane", "Doji", 5.0)
	courtier.lord_id = 20
	courtier.school_type = Enums.SchoolType.COURTIER
	var bushi := _make_character(101, "Bushi", "Crane", "Doji", 5.0)
	bushi.lord_id = 20
	bushi.school_type = Enums.SchoolType.BUSHI
	bushi.skills = {"Etiquette": 1, "Sincerity": 0, "Courtier": 0, "Perform": 0}

	var delegation: Array[int] = WinterCourtSystem.select_clan_delegation(
		champion, [courtier, bushi], 1, [], {}
	)
	assert_eq(delegation[0], 100)


func test_yojimbo_pull_in() -> void:
	var champion := _make_character(20, "Champ", "Crane", "Doji", 8.0)
	champion.lord_id = -1
	var courtier := _make_character(100, "Courtier", "Crane", "Doji", 5.0)
	courtier.lord_id = 20
	courtier.school_type = Enums.SchoolType.COURTIER
	var yojimbo := _make_character(101, "Yojimbo", "Crane", "Doji", 3.0)
	yojimbo.lord_id = 20
	yojimbo.school_type = Enums.SchoolType.BUSHI
	yojimbo.operational_superior_id = 100

	var delegation: Array[int] = WinterCourtSystem.select_clan_delegation(
		champion, [courtier, yojimbo], 1, [], {}
	)
	assert_true(100 in delegation)
	assert_true(101 in delegation)


# -- Personal Invitation Tests -------------------------------------------------

func test_personal_invitation_respects_pool_size() -> void:
	var candidates: Array[L5RCharacterData] = []
	for i: int in range(5):
		var c := _make_character(200 + i, "Candidate %d" % i, "Scorpion", "Bayushi", 4.0)
		candidates.append(c)
	_emperor.met_characters = [200, 201, 202, 203, 204]

	var invites: Array[int] = WinterCourtSystem.select_personal_invitations(
		_emperor, StrategicReview.EmperorArchetype.IRON, 3, candidates,
		[], {}, []
	)
	assert_eq(invites.size(), 3)


func test_personal_invitation_excludes_already_invited() -> void:
	var c := _make_character(200, "Already Invited", "Scorpion", "Bayushi", 4.0)
	_emperor.met_characters = [200]

	var invites: Array[int] = WinterCourtSystem.select_personal_invitations(
		_emperor, StrategicReview.EmperorArchetype.IRON, 3, [c],
		[], {}, [200]
	)
	assert_eq(invites.size(), 0)


func test_warlike_personal_invitation_favors_bushi() -> void:
	var bushi := _make_character(200, "Bushi", "Lion", "Akodo", 5.0)
	bushi.school_type = Enums.SchoolType.BUSHI
	var courtier := _make_character(201, "Courtier", "Crane", "Doji", 5.0)
	courtier.school_type = Enums.SchoolType.COURTIER
	_emperor.met_characters = [200, 201]
	_emperor.disposition_values = {200: 0.0, 201: 0.0}

	var invites: Array[int] = WinterCourtSystem.select_personal_invitations(
		_emperor, StrategicReview.EmperorArchetype.WARLIKE, 1, [bushi, courtier],
		[], {}, []
	)
	assert_eq(invites.size(), 1)
	assert_eq(invites[0], 200)


func test_personal_invitation_weights_total_30() -> void:
	for archetype: int in WinterCourtSystem.PERSONAL_INVITATION_WEIGHTS:
		var weights: Dictionary = WinterCourtSystem.PERSONAL_INVITATION_WEIGHTS[archetype]
		var total: int = 0
		for key: String in weights:
			total += int(weights[key])
		assert_eq(total, 30, "Archetype %d weights should total 30" % archetype)


# -- Emperor's Peace Tests -----------------------------------------------------

func test_hostile_action_blocked_at_court() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = 100

	assert_true(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"ATTACK", 100, court, false
	))


func test_covert_action_permitted_at_court() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = 100

	assert_false(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"EAVESDROP", 100, court, false
	))
	assert_false(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"FABRICATE_SECRET", 100, court, false
	))


func test_sanctioned_duel_exempt() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = 100

	assert_false(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"CHALLENGE_TO_DUEL", 100, court, true
	))


func test_unsanctioned_duel_blocked() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = 100

	assert_true(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"CHALLENGE_TO_DUEL", 100, court, false
	))


func test_action_at_different_settlement_not_blocked() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = 100

	assert_false(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"ATTACK", 200, court, false
	))


func test_action_blocked_only_during_active_court() -> void:
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.SCHEDULED
	court.host_settlement_id = 100

	assert_false(WinterCourtSystem.is_action_blocked_by_emperors_peace(
		"ATTACK", 100, court, false
	))


# -- Glory Rewards Tests -------------------------------------------------------

func test_glory_rewards_host_daimyo() -> void:
	_setup_basic_castle()
	var court := CourtSessionData.new()
	court.host_lord_id = 10
	court.host_clan = "Crane"
	court.attendee_ids = [1, 10]

	var rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, _characters_by_id)
	var daimyo_reward: Dictionary = {}
	for r: Dictionary in rewards:
		if r["character_id"] == 10:
			daimyo_reward = r
	assert_false(daimyo_reward.is_empty())
	assert_almost_eq(daimyo_reward["glory_change"], 0.5, 0.01)


func test_glory_rewards_clan_champion_separate() -> void:
	_setup_basic_castle()
	var champion := _make_character(11, "Crane Champ", "Crane", "Doji", 9.0)
	champion.lord_id = -1
	_characters_by_id[11] = champion

	var court := CourtSessionData.new()
	court.host_lord_id = 10
	court.host_clan = "Crane"
	court.attendee_ids = [1, 10, 11]

	var rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, _characters_by_id)
	var champ_reward: Dictionary = {}
	for r: Dictionary in rewards:
		if r["character_id"] == 11:
			champ_reward = r
	assert_false(champ_reward.is_empty())
	assert_almost_eq(champ_reward["glory_change"], 0.3, 0.01)


func test_glory_rewards_host_clan_delegates() -> void:
	_setup_basic_castle()
	var delegate := _make_character(12, "Crane Delegate", "Crane", "Doji", 3.0)
	_characters_by_id[12] = delegate

	var court := CourtSessionData.new()
	court.host_lord_id = 10
	court.host_clan = "Crane"
	court.attendee_ids = [1, 10, 12]

	var rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, _characters_by_id)
	var delegate_reward: Dictionary = {}
	for r: Dictionary in rewards:
		if r["character_id"] == 12:
			delegate_reward = r
	assert_false(delegate_reward.is_empty())
	assert_almost_eq(delegate_reward["glory_change"], 0.1, 0.01)


func test_glory_rewards_non_host_clan_excluded() -> void:
	_setup_basic_castle()
	var lion := _make_character(12, "Lion Delegate", "Lion", "Akodo", 3.0)
	_characters_by_id[12] = lion

	var court := CourtSessionData.new()
	court.host_lord_id = 10
	court.host_clan = "Crane"
	court.attendee_ids = [1, 10, 12]

	var rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, _characters_by_id)
	for r: Dictionary in rewards:
		assert_ne(r["character_id"], 12)


# -- Home Ground Bonus Tests ---------------------------------------------------

func test_home_ground_bonus_for_host_clan() -> void:
	var attendee := _make_character(10, "Crane", "Crane", "Doji", 3.0)
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_clan = "Crane"
	court.attendee_ids = [10]

	assert_eq(WinterCourtSystem.get_home_ground_bonus(attendee, court), 5)


func test_home_ground_bonus_zero_for_other_clan() -> void:
	var attendee := _make_character(10, "Lion", "Lion", "Akodo", 3.0)
	var court := CourtSessionData.new()
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_clan = "Crane"
	court.attendee_ids = [10]

	assert_eq(WinterCourtSystem.get_home_ground_bonus(attendee, court), 0)


func test_home_ground_skill_check() -> void:
	assert_true(WinterCourtSystem.is_home_ground_skill("Etiquette"))
	assert_true(WinterCourtSystem.is_home_ground_skill("Courtier"))
	assert_true(WinterCourtSystem.is_home_ground_skill("Sincerity"))
	assert_false(WinterCourtSystem.is_home_ground_skill("Battle"))


# -- Regent Substitution Tests -------------------------------------------------

func test_regent_needed_when_emperor_dead() -> void:
	var dead_emperor := _make_character(50, "Dead Emperor", "Imperial", "Hantei", 10.0)
	dead_emperor.wounds_current = 999
	_characters_by_id[50] = dead_emperor

	assert_true(WinterCourtSystem.should_use_regent(50, _characters_by_id))


func test_regent_needed_when_emperor_missing() -> void:
	assert_true(WinterCourtSystem.should_use_regent(-1, {}))


func test_regent_not_needed_when_emperor_alive() -> void:
	assert_false(WinterCourtSystem.should_use_regent(1, _characters_by_id))


func test_find_chancellor() -> void:
	var found: L5RCharacterData = WinterCourtSystem.find_imperial_chancellor(_characters_by_id)
	assert_not_null(found)
	assert_eq(found.character_id, 2)


func test_find_chancellor_returns_null_when_none() -> void:
	_characters_by_id.erase(2)
	var found: L5RCharacterData = WinterCourtSystem.find_imperial_chancellor(_characters_by_id)
	assert_null(found)


func test_regent_court_reduced_prestige() -> void:
	_setup_basic_castle()
	var result: Dictionary = WinterCourtSystem.run_winter_court_selection(
		null, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	if not result.get("skipped", false):
		assert_eq(result.get("prestige", 3), WinterCourtSystem.REGENT_PRESTIGE)
		assert_true(result.get("is_regent_court", false))
		assert_true(result.get("no_edicts", false))


func test_regent_skipped_when_no_chancellor() -> void:
	_setup_basic_castle()
	_characters_by_id.erase(2)
	var result: Dictionary = WinterCourtSystem.run_winter_court_selection(
		null, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_true(result.get("skipped", false))
	assert_eq(result.get("reason", ""), "no_chancellor")


# -- Topic Generation Tests ----------------------------------------------------

func test_announcement_topic_generated() -> void:
	var topic_dict: Dictionary = WinterCourtSystem.generate_announcement_topic(10, "Crane", 5)
	assert_eq(topic_dict["topic_type"], "winter_court_announced")
	assert_eq(topic_dict["tier"], TopicData.Tier.TIER_3)
	assert_eq(topic_dict["category"], TopicData.Category.POLITICAL)
	assert_true(topic_dict.get("non_positional", false))
	assert_eq(topic_dict["clan_involved"], "Crane")


# -- Agenda Day Allocation Tests -----------------------------------------------

func test_agenda_day_allocation() -> void:
	var days: Array[int] = WinterCourtSystem.get_agenda_day_allocation()
	assert_eq(days.size(), 3)
	assert_eq(days[0], 45)
	assert_eq(days[1], 35)
	assert_eq(days[2], 25)
	var total: int = days[0] + days[1] + days[2]
	assert_eq(total, 105)


# -- Full Pipeline Tests -------------------------------------------------------

func test_full_pipeline_with_emperor() -> void:
	_setup_basic_castle()
	_emperor.disposition_values[10] = 20.0

	var result: Dictionary = WinterCourtSystem.run_winter_court_selection(
		_emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, _provinces, _settlements, _topics, _world_state
	)
	assert_false(result.get("skipped", false))
	assert_eq(result["host_clan"], "Crane")
	assert_false(result.get("is_regent_court", false))
	assert_false(result.get("no_edicts", false))


func test_invitation_pipeline() -> void:
	_setup_basic_castle()
	for i: int in range(5):
		var v := _make_character(100 + i, "Crane Vassal %d" % i, "Crane", "Doji", 3.0)
		v.lord_id = 10
		_characters_by_id[100 + i] = v

	var host_result: Dictionary = {
		"host_clan": "Crane",
		"host_daimyo_id": 10,
		"clan_champion_id": 10,
		"is_regent_court": false,
	}
	var agenda: Array[int] = []
	var pipeline_result: Dictionary = WinterCourtSystem.run_invitation_pipeline(
		host_result, _emperor, StrategicReview.EmperorArchetype.IRON,
		_characters_by_id, Enums.LordRank.FAMILY_DAIMYO, agenda
	)
	assert_true(pipeline_result.has("all_invited"))
	assert_true(pipeline_result.has("clan_delegations"))
	assert_gt(pipeline_result["all_invited"].size(), 0)


func test_host_selection_weight_totals() -> void:
	for archetype: int in WinterCourtSystem.HOST_SELECTION_WEIGHTS:
		var weights: Dictionary = WinterCourtSystem.HOST_SELECTION_WEIGHTS[archetype]
		var total: int = 0
		for key: String in weights:
			total += int(weights[key])
		assert_eq(total, 50, "Archetype %d weights should total 50" % archetype)


# -- CourtSessionData New Fields Tests -----------------------------------------

func test_court_session_data_has_new_fields() -> void:
	var court := CourtSessionData.new()
	assert_eq(court.is_regent_court, false)
	assert_eq(court.host_family_daimyo_id, -1)
	assert_eq(court.clan_champion_id, -1)
	assert_eq(court.grace_period_days, 0)
	assert_eq(court.no_edicts, false)
	assert_eq(court.announcement_topic_id, -1)


# -- Constants Tests -----------------------------------------------------------

func test_grace_period_days() -> void:
	assert_eq(WinterCourtSystem.GRACE_PERIOD_DAYS, 15)


func test_glory_constants() -> void:
	assert_almost_eq(WinterCourtSystem.GLORY_HOST_FAMILY_DAIMYO, 0.5, 0.01)
	assert_almost_eq(WinterCourtSystem.GLORY_HOST_CLAN_CHAMPION, 0.3, 0.01)
	assert_almost_eq(WinterCourtSystem.GLORY_HOST_CLAN_DELEGATE, 0.1, 0.01)


# -- Skill Bonus (Home Ground +5) Tests ---------------------------------------

func test_skill_bonus_applies_to_host_clan_at_winter_court() -> void:
	var c := _make_character(20, "Crane Courtier", "Crane", "Doji", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {
		"court_type": CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		"host_clan": "Crane",
	}
	var bonus: int = ActionExecutor._get_winter_court_skill_bonus(c, "Etiquette", ctx)
	assert_eq(bonus, WinterCourtSystem.HOST_SKILL_BONUS)


func test_skill_bonus_zero_for_non_host_clan() -> void:
	var c := _make_character(20, "Lion Courtier", "Lion", "Ikoma", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {
		"court_type": CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		"host_clan": "Crane",
	}
	var bonus: int = ActionExecutor._get_winter_court_skill_bonus(c, "Etiquette", ctx)
	assert_eq(bonus, 0)


func test_skill_bonus_zero_for_non_home_ground_skill() -> void:
	var c := _make_character(20, "Crane Bushi", "Crane", "Doji", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {
		"court_type": CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		"host_clan": "Crane",
	}
	var bonus: int = ActionExecutor._get_winter_court_skill_bonus(c, "Kenjutsu", ctx)
	assert_eq(bonus, 0)


func test_skill_bonus_zero_for_non_winter_court() -> void:
	var c := _make_character(20, "Crane Courtier", "Crane", "Doji", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {
		"court_type": CourtSessionData.CourtType.CLAN_CHAMPION_COURT,
		"host_clan": "Crane",
	}
	var bonus: int = ActionExecutor._get_winter_court_skill_bonus(c, "Etiquette", ctx)
	assert_eq(bonus, 0)


func test_skill_bonus_zero_when_no_court() -> void:
	var c := _make_character(20, "Crane Courtier", "Crane", "Doji", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	var bonus: int = ActionExecutor._get_winter_court_skill_bonus(c, "Etiquette", ctx)
	assert_eq(bonus, 0)


func test_skill_bonus_applies_to_courtier_skill() -> void:
	var c := _make_character(20, "Crane Courtier", "Crane", "Doji", 4.0)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_court_at_location = {
		"court_type": CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		"host_clan": "Crane",
	}
	assert_eq(ActionExecutor._get_winter_court_skill_bonus(c, "Courtier", ctx), 5)
	assert_eq(ActionExecutor._get_winter_court_skill_bonus(c, "Sincerity", ctx), 5)


func test_home_ground_skill_recognition() -> void:
	assert_true(WinterCourtSystem.is_home_ground_skill("Etiquette"))
	assert_true(WinterCourtSystem.is_home_ground_skill("Courtier"))
	assert_true(WinterCourtSystem.is_home_ground_skill("Sincerity"))
	assert_false(WinterCourtSystem.is_home_ground_skill("Kenjutsu"))
	assert_false(WinterCourtSystem.is_home_ground_skill("Investigation"))


# -- Summons Letter Dispatching Tests ------------------------------------------

func test_summons_dispatched_to_clan_champions() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ
	var scorpion_champ := _make_character(31, "Scorpion Champion", "Scorpion", "Bayushi", 8.0)
	scorpion_champ.lord_id = -1
	_characters_by_id[31] = scorpion_champ

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [1]

	var count: int = DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	assert_eq(count, 2)
	assert_eq(pending_letters.size(), 2)
	var recipient_ids: Array = []
	for letter: LetterData in pending_letters:
		recipient_ids.append(letter.recipient_id)
		assert_eq(letter.sender_id, _emperor.character_id)
		assert_eq(letter.topic, 500)
	assert_true(30 in recipient_ids)
	assert_true(31 in recipient_ids)


func test_summons_skips_host_clan_champion() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	for letter: LetterData in pending_letters:
		assert_ne(letter.recipient_id, 10, "Host clan champion should not receive summons")


func test_summons_skips_emperor() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	for letter: LetterData in pending_letters:
		assert_ne(letter.recipient_id, _emperor.character_id, "Emperor should not receive summons")


func test_summons_skips_non_champion_characters() -> void:
	_setup_basic_castle()
	var vassal := _make_character(40, "Lion Vassal", "Lion", "Akodo", 4.0)
	vassal.lord_id = 30
	_characters_by_id[40] = vassal

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	for letter: LetterData in pending_letters:
		assert_ne(letter.recipient_id, 40, "Non-champion should not receive summons")


func test_summons_zero_when_no_dice_engine() -> void:
	var count: int = DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		[], null, [1],
	)
	assert_eq(count, 0)


func test_summons_increments_letter_ids() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ
	var crab_champ := _make_character(31, "Crab Champion", "Crab", "Hida", 8.0)
	crab_champ.lord_id = -1
	_characters_by_id[31] = crab_champ

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [100]

	DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	assert_eq(next_letter_id[0], 102)


func test_summons_has_miya_route() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ

	var pending_letters: Array = []
	var dice := DiceEngine.new()
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._dispatch_winter_court_summons(
		_emperor, "Crane", 500, 200, _characters_by_id,
		pending_letters, dice, next_letter_id,
	)
	assert_eq(pending_letters.size(), 1)
	var letter: LetterData = pending_letters[0]
	assert_true(letter.has_miya_route)


# -- Winter Court COURT_ATTENDANCE Commitment Tests ----------------------------

func test_winter_court_creates_attendance_commitments_for_invitees() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ
	var scorpion_champ := _make_character(31, "Scorpion Champion", "Scorpion", "Bayushi", 8.0)
	scorpion_champ.lord_id = -1
	_characters_by_id[31] = scorpion_champ

	var commitments: Array[CommitmentData] = []
	var next_commitment_id: Array[int] = [1]
	var directive: Dictionary = {"lord_id": _emperor.character_id, "host_clan": "Crane"}
	var courts: Array[CourtSessionData] = []
	var topics: Array[TopicData] = []
	var next_court_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]
	var dice := DiceEngine.new()
	var pending_letters: Array[LetterData] = []
	var next_letter_id: Array[int] = [1]

	var result: Dictionary = DayOrchestrator._create_winter_court_from_directive(
		directive, courts, topics, _characters_by_id, next_court_id, 200,
		[], [], {}, StrategicReview.EmperorArchetype.IRON, next_topic_id,
		pending_letters, dice, next_letter_id,
		commitments, next_commitment_id,
	)
	assert_gt(commitments.size(), 0)
	var debtor_ids: Array[int] = []
	for c: CommitmentData in commitments:
		assert_eq(c.commitment_type, Enums.CommitmentType.COURT_ATTENDANCE)
		assert_eq(c.creditor_npc_id, _emperor.character_id)
		assert_eq(c.tier, 2)
		assert_eq(c.source_action_id, "WINTER_COURT_SUMMONS")
		debtor_ids.append(c.debtor_npc_id)
	assert_true(30 in debtor_ids, "Lion Champion should have commitment")
	assert_true(31 in debtor_ids, "Scorpion Champion should have commitment")


func test_winter_court_commitments_have_correct_deadline() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ

	var commitments: Array[CommitmentData] = []
	var next_commitment_id: Array[int] = [1]
	var directive: Dictionary = {"lord_id": _emperor.character_id, "host_clan": "Crane"}
	var courts: Array[CourtSessionData] = []
	var topics: Array[TopicData] = []
	var next_court_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]
	var dice := DiceEngine.new()
	var pending_letters: Array[LetterData] = []
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._create_winter_court_from_directive(
		directive, courts, topics, _characters_by_id, next_court_id, 200,
		[], [], {}, StrategicReview.EmperorArchetype.IRON, next_topic_id,
		pending_letters, dice, next_letter_id,
		commitments, next_commitment_id,
	)
	assert_eq(commitments.size(), 1)
	assert_eq(commitments[0].deadline_ic_day, courts[0].start_ic_day)
	assert_eq(commitments[0].fulfillment_target, courts[0].host_settlement_id)


func test_winter_court_commitment_skips_duplicates() -> void:
	_setup_basic_castle()
	var lion_champ := _make_character(30, "Lion Champion", "Lion", "Akodo", 8.0)
	lion_champ.lord_id = -1
	_characters_by_id[30] = lion_champ

	var existing := CommitmentData.new()
	existing.commitment_type = Enums.CommitmentType.COURT_ATTENDANCE
	existing.debtor_npc_id = 30
	existing.fulfillment_target = int(lion_champ.physical_location) if lion_champ.physical_location.is_valid_int() else -1
	existing.status = Enums.CommitmentStatus.PENDING

	var commitments: Array[CommitmentData] = [existing]
	var next_commitment_id: Array[int] = [1]
	var directive: Dictionary = {"lord_id": _emperor.character_id, "host_clan": "Crane"}
	var courts: Array[CourtSessionData] = []
	var topics: Array[TopicData] = []
	var next_court_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]
	var dice := DiceEngine.new()
	var pending_letters: Array[LetterData] = []
	var next_letter_id: Array[int] = [1]

	DayOrchestrator._create_winter_court_from_directive(
		directive, courts, topics, _characters_by_id, next_court_id, 200,
		[], [], {}, StrategicReview.EmperorArchetype.IRON, next_topic_id,
		pending_letters, dice, next_letter_id,
		commitments, next_commitment_id,
	)
	var attendance_count: int = 0
	for c: CommitmentData in commitments:
		if c.debtor_npc_id == 30 and c.commitment_type == Enums.CommitmentType.COURT_ATTENDANCE:
			attendance_count += 1
	assert_eq(attendance_count, 1, "Should not duplicate existing commitment")


# -- Late Arrival Tests --------------------------------------------------------

func test_late_arrival_adds_delegate_to_winter_court() -> void:
	var court := CourtSessionData.new()
	court.court_id = 1
	court.court_type = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	court.host_settlement_id = 100
	court.host_lord_id = _emperor.character_id
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.grace_period_days = 15
	CourtSystem.add_attendee(court, _emperor.character_id)
	_emperor.physical_location = "100"

	var late_delegate := _make_character(50, "Late Crane", "Crane", "Doji", 4.0)
	late_delegate.physical_location = "100"
	_characters_by_id[50] = late_delegate

	var active_courts: Array[CourtSessionData] = [court]
	var results: Array[Dictionary] = DayOrchestrator._process_court_attendance(
		active_courts, [_emperor, late_delegate], _characters_by_id
	)

	assert_true(50 in court.attendee_ids, "Late delegate should be added to attendee list")
	var found_arrival: bool = false
	for r: Dictionary in results:
		if r.get("character_id", -1) == 50 and r.get("action", "") == "arrived":
			found_arrival = true
	assert_true(found_arrival, "Arrival event should be recorded")


func test_late_arrival_not_added_if_at_different_settlement() -> void:
	var court := CourtSessionData.new()
	court.court_id = 1
	court.court_type = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	court.host_settlement_id = 100
	court.host_lord_id = _emperor.character_id
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	CourtSystem.add_attendee(court, _emperor.character_id)
	_emperor.physical_location = "100"

	var distant := _make_character(51, "Distant Crane", "Crane", "Doji", 4.0)
	distant.physical_location = "200"
	_characters_by_id[51] = distant

	var active_courts: Array[CourtSessionData] = [court]
	DayOrchestrator._process_court_attendance(
		active_courts, [_emperor, distant], _characters_by_id
	)
	assert_false(51 in court.attendee_ids)


# =============================================================================
# Champion Agenda Ordering AI (s55.10 — Agenda Topic Ordering)
# =============================================================================

func _make_topic_for_clan(id: int, clan: String, momentum: float) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.clan_involved = clan
	t.momentum = momentum
	t.resolved = false
	return t


func _make_champion(cid: int, clan: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = clan
	c.lord_id = -1
	c.status = 7.5
	return c


func test_agenda_order_own_clan_first() -> void:
	var host_champion := _make_champion(100, "Crane")
	# Topic 1: Crab crisis (high momentum)
	# Topic 2: Crane crisis (lower momentum)
	# Topic 3: Lion crisis (medium momentum)
	var t1 := _make_topic_for_clan(1, "Crab", 90.0)
	var t2 := _make_topic_for_clan(2, "Crane", 70.0)
	var t3 := _make_topic_for_clan(3, "Lion", 80.0)
	var topics: Array[TopicData] = [t1, t2, t3]
	var topic_ids: Array[int] = [1, 2, 3]
	var result: Array[int] = WinterCourtSystem.order_agenda_for_host(
		topic_ids, topics, "Crane", host_champion, {}
	)
	# Crane topic (id=2) should be slot 1 despite lower momentum.
	assert_eq(result[0], 2, "Own clan crisis must go to slot 1")


func test_agenda_order_rival_clan_last() -> void:
	var host_champion := _make_champion(100, "Crane")
	var rival_champ := _make_champion(200, "Lion")
	host_champion.disposition_values = {200: -50}  # Lion champion at Enemy
	_characters_by_id[200] = rival_champ

	var t1 := _make_topic_for_clan(1, "Crab", 80.0)
	var t2 := _make_topic_for_clan(2, "Lion", 90.0)  # rival, high momentum
	var t3 := _make_topic_for_clan(3, "Scorpion", 70.0)
	var topics: Array[TopicData] = [t1, t2, t3]
	var topic_ids: Array[int] = [1, 2, 3]
	var result: Array[int] = WinterCourtSystem.order_agenda_for_host(
		topic_ids, topics, "Crane", host_champion, _characters_by_id
	)
	# Lion topic (id=2) should be slot 3 despite highest momentum.
	assert_eq(result[2], 2, "Rival clan crisis must go to slot 3")


func test_agenda_order_neutral_topics_by_momentum() -> void:
	var host_champion := _make_champion(100, "Crane")
	var t1 := _make_topic_for_clan(1, "Crab", 60.0)
	var t2 := _make_topic_for_clan(2, "Lion", 80.0)
	var t3 := _make_topic_for_clan(3, "Scorpion", 70.0)
	var topics: Array[TopicData] = [t1, t2, t3]
	var topic_ids: Array[int] = [1, 2, 3]
	var result: Array[int] = WinterCourtSystem.order_agenda_for_host(
		topic_ids, topics, "Crane", host_champion, {}
	)
	# No own-clan or rival topics — sort by descending momentum.
	assert_eq(result[0], 2)  # Lion 80
	assert_eq(result[1], 3)  # Scorpion 70
	assert_eq(result[2], 1)  # Crab 60


func test_agenda_order_single_topic_unchanged() -> void:
	var host_champion := _make_champion(100, "Crane")
	var t1 := _make_topic_for_clan(1, "Crab", 80.0)
	var result: Array[int] = WinterCourtSystem.order_agenda_for_host(
		[1], [t1], "Crane", host_champion, {}
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0], 1)


func test_agenda_order_null_champion_uses_momentum_only() -> void:
	var t1 := _make_topic_for_clan(1, "Crab", 60.0)
	var t2 := _make_topic_for_clan(2, "Lion", 80.0)
	var t3 := _make_topic_for_clan(3, "Scorpion", 70.0)
	var topics: Array[TopicData] = [t1, t2, t3]
	var result: Array[int] = WinterCourtSystem.order_agenda_for_host(
		[1, 2, 3], topics, "Crane", null, {}
	)
	# No champion → can't check disposition; own-clan check still applies but no own clan topic.
	assert_eq(result[0], 2)  # highest momentum first


# -- Emperor's Peace Violation Crime (s57.47 v624) ----------------------------


func _make_active_winter_court(settlement_id: int) -> CourtSessionData:
	var court := CourtSessionData.new()
	court.court_id = 1
	court.court_type = CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.host_settlement_id = settlement_id
	court.host_lord_id = 50
	court.host_clan = "Crane"
	court.attendee_ids = [10, 20, 30, 50]
	return court


func test_peace_violation_creates_crime_record() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	offender.honor = 5.0
	var witness1 := _make_character(20, "Doji Satsume", "Crane", "Doji", 7.0)
	var witness2 := _make_character(30, "Bayushi Shoju", "Scorpion", "Bayushi", 6.0)
	var chars: Dictionary = {10: offender, 20: witness1, 30: witness2, 50: _emperor}
	var court := _make_active_winter_court(100)
	var next_case: Array[int] = [1]
	var next_topic: Array[int] = [500]

	var result: Dictionary = WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, next_case, next_topic, chars
	)

	assert_not_null(result.get("crime_record"))
	var record: CrimeRecord = result["crime_record"]
	assert_eq(record.crime_type, Enums.CrimeType.VIOLATION_EMPERORS_PEACE)
	assert_eq(record.perpetrator_id, 10)
	assert_eq(record.legal_status, Enums.LegalStatus.ACCUSED)
	assert_eq(record.evidence_total, 100)
	assert_eq(CrimeSystem.get_severity(record.crime_type), Enums.CrimeSeverity.CAPITAL)


func test_peace_violation_witnesses_are_all_other_attendees() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	var chars: Dictionary = {10: offender, 20: _make_character(20, "W1", "Crane", "Doji", 5.0), 30: _make_character(30, "W2", "Scorpion", "Bayushi", 5.0), 50: _emperor}
	var court := _make_active_winter_court(100)
	var result: Dictionary = WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, [1], [500], chars
	)
	var record: CrimeRecord = result["crime_record"]
	assert_eq(record.witnesses.size(), 3)
	assert_false(offender.character_id in record.witnesses)


func test_peace_violation_at_act_honor_loss() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	offender.honor = 5.5
	var chars: Dictionary = {10: offender}
	var court := _make_active_winter_court(100)
	court.attendee_ids = [10]
	var honor_before: float = offender.honor

	WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, [1], [500], chars
	)

	assert_lt(offender.honor, honor_before)


func test_peace_violation_generates_tier_1_topic() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	var chars: Dictionary = {10: offender}
	var court := _make_active_winter_court(100)
	court.attendee_ids = [10]

	var result: Dictionary = WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, [1], [500], chars
	)

	var topic: TopicData = result["topic"]
	assert_not_null(topic)
	assert_eq(topic.tier, TopicData.Tier.TIER_1)
	assert_eq(topic.category, TopicData.Category.LEGAL)
	assert_eq(topic.subject_character_id, 10)
	assert_true(topic.title.contains("Emperor's Peace"))


func test_peace_violation_conviction_consequences_match_maho() -> void:
	var consequences: Array = CrimeSystem.CONVICTION_CONSEQUENCES[Enums.CrimeType.VIOLATION_EMPERORS_PEACE]
	var maho: Array = CrimeSystem.CONVICTION_CONSEQUENCES[Enums.CrimeType.MAHO]
	assert_eq(consequences[0], maho[0])  # glory -3.0
	assert_eq(consequences[1], maho[1])  # infamy +5.0
	assert_eq(consequences[2], maho[2])  # status -> 0.0 (-99.0 sentinel)
	assert_eq(consequences[3], maho[3])  # topic tier 1


func test_peace_violation_no_seppuku_offered() -> void:
	assert_false(CrimeSystem.is_seppuku_eligible(Enums.CrimeType.VIOLATION_EMPERORS_PEACE))


func test_peace_violation_emperor_disposition_hit() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	var chars: Dictionary = {10: offender}
	var court := _make_active_winter_court(100)
	court.attendee_ids = [10]

	var result: Dictionary = WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, [1], [500], chars
	)

	assert_eq(result["emperor_disposition_hit"], -15)
	assert_eq(result["offender_clan"], "Lion")


func test_peace_violation_family_daimyo_glory_loss() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	var daimyo := _make_character(40, "Akodo Arasou", "Lion", "Akodo", 7.0)
	daimyo.role_position = "family_daimyo"
	daimyo.glory = 5.0
	var chars: Dictionary = {10: offender, 40: daimyo}
	var court := _make_active_winter_court(100)
	court.attendee_ids = [10]

	WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, [1], [500], chars
	)

	assert_lt(daimyo.glory, 5.0)
	assert_almost_eq(daimyo.glory, 4.0, 0.01)


func test_peace_violation_increments_case_and_topic_ids() -> void:
	var offender := _make_character(10, "Akodo Toturi", "Lion", "Akodo", 6.0)
	var chars: Dictionary = {10: offender}
	var court := _make_active_winter_court(100)
	court.attendee_ids = [10]
	var next_case: Array[int] = [5]
	var next_topic: Array[int] = [100]

	WinterCourtSystem.record_emperors_peace_violation(
		offender, "ATTACK", court, 250, next_case, next_topic, chars
	)

	assert_eq(next_case[0], 6)
	assert_eq(next_topic[0], 101)
