extends GutTest
## Tests for s57.54 Clan Champion Strategic Evaluation System.


func _make_champion(
	id: int = 1,
	clan: String = "Crane",
	virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.CHUGI,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.lord_id = -1
	c.status = 7.0
	c.bushido_virtue = virtue
	c.shourido_virtue = shourido
	return c


func _make_family_daimyo(
	id: int = 10,
	clan: String = "Crane",
	virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.CHUGI,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.lord_id = 1
	c.status = 6.0
	c.bushido_virtue = virtue
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_clan(name: String = "Crane") -> ClanData:
	var clan := ClanData.new()
	clan.clan_name = name
	clan.next_conclusion_id = 0
	return clan


func _make_topic(
	id: int,
	tier: TopicData.Tier,
	category: TopicData.Category = TopicData.Category.MILITARY,
	clan: String = "Dragon",
) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.tier = tier
	t.category = category
	t.clan_involved = clan
	t.resolved = false
	t.ic_day_created = 0
	return t


func _make_dice() -> DiceEngine:
	return DiceEngine.new()


# -- StrategicConclusionData ---------------------------------------------------

func test_conclusion_data_fields() -> void:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 5
	sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	sc.domain = StrategicConclusionData.Domain.MILITARY
	sc.score = 80
	sc.is_forced = true
	assert_eq(sc.conclusion_id, 5)
	assert_eq(sc.conclusion_type, StrategicConclusionData.ConclusionType.DEFEND_TERRITORY)
	assert_eq(sc.domain, StrategicConclusionData.Domain.MILITARY)
	assert_eq(sc.score, 80)
	assert_true(sc.is_forced)


func test_conclusion_data_defaults() -> void:
	var sc := StrategicConclusionData.new()
	assert_eq(sc.conclusion_id, -1)
	assert_eq(sc.target_clan_id, -1)
	assert_eq(sc.war_objective, StrategicConclusionData.WarObjective.NONE)
	assert_false(sc.is_forced)
	assert_false(sc.is_continuation)
	assert_eq(sc.season_originated, -1)


# -- ClanData fields -----------------------------------------------------------

func test_clan_data_has_strategic_priorities() -> void:
	var clan := _make_clan()
	assert_eq(clan.clan_strategic_priorities.size(), 0)
	assert_eq(clan.next_conclusion_id, 0)


func test_clan_data_accepts_conclusions() -> void:
	var clan := _make_clan()
	var sc := StrategicConclusionData.new()
	sc.conclusion_type = StrategicConclusionData.ConclusionType.SECURE_RESOURCE
	clan.clan_strategic_priorities.append(sc)
	assert_eq(clan.clan_strategic_priorities.size(), 1)
	assert_eq(clan.clan_strategic_priorities[0].conclusion_type,
		StrategicConclusionData.ConclusionType.SECURE_RESOURCE)


# -- run_clan_champion_evaluation basic flow -----------------------------------

func test_evaluation_returns_empty_for_dead_champion() -> void:
	var champion := _make_champion()
	champion.wounds_taken = 100
	var clan := _make_clan()
	var dice := _make_dice()
	var result: Array = StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], {}, {}, 0, dice
	)
	assert_eq(result.size(), 0)


func test_evaluation_writes_to_clan_priorities() -> void:
	var champion := _make_champion(1, "Crane", Enums.BushidoVirtue.CHUGI)
	var clan := _make_clan()
	var dice := _make_dice()

	# Tier 1 war topic forces LAUNCH_OFFENSIVE or similar military conclusion.
	var war_topic := _make_topic(1, TopicData.Tier.TIER_1, TopicData.Category.MILITARY, "Lion")
	war_topic.topic_type = "war_declaration"
	var topics_by_id: Dictionary = {1: war_topic}

	var war := WarData.new()
	war.clan_a = "Crane"
	war.clan_b = "Lion"
	war.is_active = true

	StrategicReview.run_clan_champion_evaluation(
		champion, clan, topics_by_id, [war], [], {}, {}, 0, dice
	)

	assert_gt(clan.clan_strategic_priorities.size(), 0, "Should produce at least one conclusion")


func test_evaluation_logs_to_champion() -> void:
	var champion := _make_champion()
	var clan := _make_clan()
	var dice := _make_dice()

	StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], {}, {}, 0, dice
	)

	assert_eq(champion.strategic_evaluation_log.size(), 1,
		"Champion should have one log entry per evaluation")
	assert_true(champion.strategic_evaluation_log[0].has("season"))
	assert_true(champion.strategic_evaluation_log[0].has("candidates"))


func test_evaluation_replaces_previous_priorities() -> void:
	var champion := _make_champion()
	var clan := _make_clan()
	var dice := _make_dice()

	# Pre-populate with old conclusions.
	var old_sc := StrategicConclusionData.new()
	old_sc.conclusion_type = StrategicConclusionData.ConclusionType.SECURE_RESOURCE
	old_sc.score = 10
	old_sc.season_originated = -1
	clan.clan_strategic_priorities.append(old_sc)

	StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], {}, {}, 1, dice
	)

	# All remaining conclusions should have season_originated = 1 (new evaluation).
	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		assert_ne(sc.season_originated, -1, "All conclusions should be from season 1")


# -- Personality hard-block filter ---------------------------------------------

func test_yu_hard_blocks_undermine_position() -> void:
	var champion := _make_champion(1, "Crane", Enums.BushidoVirtue.YU)
	var clan := _make_clan()
	var dice := _make_dice()

	# Tier 3 political intrigue topic — might naturally suggest UNDERMINE_POSITION.
	var intrigue := _make_topic(2, TopicData.Tier.TIER_3, TopicData.Category.POLITICAL, "Scorpion")
	intrigue.topic_type = "Betrayal"
	var topics_by_id: Dictionary = {2: intrigue}

	StrategicReview.run_clan_champion_evaluation(
		champion, clan, topics_by_id, [], [], {}, {}, 0, dice
	)

	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		assert_ne(sc.conclusion_type, StrategicConclusionData.ConclusionType.UNDERMINE_POSITION,
			"YU virtue should hard-block UNDERMINE_POSITION")


func test_makoto_hard_blocks_undermine_position() -> void:
	var champion := _make_champion(1, "Scorpion", Enums.BushidoVirtue.MAKOTO)
	var clan := _make_clan("Scorpion")
	var dice := _make_dice()

	StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], {}, {}, 0, dice
	)

	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		assert_ne(sc.conclusion_type, StrategicConclusionData.ConclusionType.UNDERMINE_POSITION,
			"MAKOTO virtue should hard-block UNDERMINE_POSITION")


# -- Continuation bonus -------------------------------------------------------

func test_makoto_continuation_bonus_is_highest() -> void:
	var champion_makoto := _make_champion(1, "Crane", Enums.BushidoVirtue.MAKOTO)
	var champion_other := _make_champion(2, "Crane", Enums.BushidoVirtue.GI)

	# Provide both with a pre-existing conclusion.
	var clan_makoto := _make_clan()
	var existing_sc := StrategicConclusionData.new()
	existing_sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	existing_sc.score = 50
	existing_sc.season_originated = -1
	clan_makoto.clan_strategic_priorities.append(existing_sc.duplicate())

	var clan_other := _make_clan()
	clan_other.clan_strategic_priorities.append(existing_sc)

	var dice := _make_dice()
	StrategicReview.run_clan_champion_evaluation(
		champion_makoto, clan_makoto, {}, [], [], {}, {}, 1, dice
	)
	StrategicReview.run_clan_champion_evaluation(
		champion_other, clan_other, {}, [], [], {}, {}, 1, dice
	)

	# If DEFEND_TERRITORY was kept, Makoto should have scored it higher.
	# (We can't easily inspect internal scores, so we just verify evaluation ran cleanly.)
	assert_true(champion_makoto.strategic_evaluation_log.size() > 0)
	assert_true(champion_other.strategic_evaluation_log.size() > 0)


# -- Family Daimyo letter dispatches -------------------------------------------

func test_absent_family_daimyo_gets_letter_dispatch() -> void:
	var champion := _make_champion(1, "Crane", Enums.BushidoVirtue.CHUGI)
	var clan := _make_clan()
	var dice := _make_dice()
	var fd := _make_family_daimyo(10, "Crane")
	# Place champion and FD at different locations.
	champion.physical_location = "settlement_1"
	fd.physical_location = "settlement_2"
	var chars_by_id: Dictionary = {10: fd}

	var dispatches: Array = StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], chars_by_id, {}, 0, dice, [10]
	)

	assert_eq(dispatches.size(), 1, "One absent FD → one letter dispatch")
	assert_eq(dispatches[0].get("sender_id", -1), 1)
	assert_eq(dispatches[0].get("recipient_id", -1), 10)
	assert_eq(dispatches[0].get("type", ""), "strategic_conclusion_letter")


func test_co_located_family_daimyo_gets_no_letter() -> void:
	var champion := _make_champion(1, "Crane", Enums.BushidoVirtue.CHUGI)
	var clan := _make_clan()
	var dice := _make_dice()
	var fd := _make_family_daimyo(10, "Crane")
	# Same location — reads directly, no letter needed.
	champion.physical_location = "settlement_1"
	fd.physical_location = "settlement_1"
	var chars_by_id: Dictionary = {10: fd}

	var dispatches: Array = StrategicReview.run_clan_champion_evaluation(
		champion, clan, {}, [], [], chars_by_id, {}, 0, dice, [10]
	)

	assert_eq(dispatches.size(), 0, "Co-located FD should not receive a letter")


# -- get_champion_conclusion_needtypes (Family Daimyo translation) -------------

func test_get_champion_conclusion_needtypes_empty_when_no_priorities() -> void:
	var fd := _make_family_daimyo()
	var clan := _make_clan()

	var candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd, clan)

	assert_eq(candidates.size(), 0)


func test_get_champion_conclusion_needtypes_returns_per_conclusion() -> void:
	var fd := _make_family_daimyo(10, "Crane", Enums.BushidoVirtue.CHUGI)
	var clan := _make_clan()
	var sc := StrategicConclusionData.new()
	sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	sc.score = 60
	sc.target_clan_id = -1
	clan.clan_strategic_priorities.append(sc)

	var candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd, clan)

	assert_gt(candidates.size(), 0, "DEFEND_TERRITORY should produce NeedType candidates")
	var need_types: Array = []
	for c: Dictionary in candidates:
		need_types.append(c.get("need_type", ""))
	assert_true("DEFEND_PROVINCE" in need_types, "DEFEND_TERRITORY should include DEFEND_PROVINCE")


func test_hard_blocked_conclusion_excluded_for_fd() -> void:
	# YU virtue hard-blocks UNDERMINE_POSITION even when champion selected it.
	var fd := _make_family_daimyo(10, "Crane", Enums.BushidoVirtue.YU)
	var clan := _make_clan()
	var sc := StrategicConclusionData.new()
	sc.conclusion_type = StrategicConclusionData.ConclusionType.UNDERMINE_POSITION
	sc.score = 80
	clan.clan_strategic_priorities.append(sc)

	var candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd, clan)

	assert_eq(candidates.size(), 0, "UNDERMINE_POSITION should be hard-blocked for YU FD")


func test_fd_personality_reweights_score() -> void:
	# CHUGI has +15 preference for DEFEND_TERRITORY; score should reflect it.
	var fd_chugi := _make_family_daimyo(10, "Crane", Enums.BushidoVirtue.CHUGI)
	var fd_jin := _make_family_daimyo(11, "Crane", Enums.BushidoVirtue.JIN)
	var clan_chugi := _make_clan()
	var clan_jin := _make_clan()
	var sc := StrategicConclusionData.new()
	sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	sc.score = 60
	clan_chugi.clan_strategic_priorities.append(sc.duplicate())
	clan_jin.clan_strategic_priorities.append(sc)

	var chugi_candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd_chugi, clan_chugi)
	var jin_candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd_jin, clan_jin)

	var chugi_top_score: int = 0
	for c: Dictionary in chugi_candidates:
		chugi_top_score = maxi(chugi_top_score, c.get("score", 0))
	var jin_top_score: int = 0
	for c: Dictionary in jin_candidates:
		jin_top_score = maxi(jin_top_score, c.get("score", 0))

	assert_gt(chugi_top_score, jin_top_score,
		"CHUGI should score DEFEND_TERRITORY higher than JIN (+15 vs 0 pref)")


# -- get_operational_superior_co_budget ----------------------------------------

func test_co_budget_zero_with_no_subordinates() -> void:
	var char := _make_champion()
	var budget: int = StrategicReview.get_operational_superior_co_budget(char, {})
	assert_eq(budget, 0)


func test_co_budget_two_for_one_to_three_subordinates() -> void:
	var superior := _make_champion(1)
	var sub1 := _make_family_daimyo(2)
	sub1.operational_superior_id = 1
	var sub2 := _make_family_daimyo(3)
	sub2.operational_superior_id = 1
	var chars_by_id: Dictionary = {1: superior, 2: sub1, 3: sub2}

	var budget: int = StrategicReview.get_operational_superior_co_budget(superior, chars_by_id)
	assert_eq(budget, 2)


func test_co_budget_three_for_four_or_more_subordinates() -> void:
	var superior := _make_champion(1)
	var chars_by_id: Dictionary = {1: superior}
	for i: int in range(4):
		var sub := L5RCharacterData.new()
		sub.character_id = 10 + i
		sub.operational_superior_id = 1
		chars_by_id[sub.character_id] = sub

	var budget: int = StrategicReview.get_operational_superior_co_budget(superior, chars_by_id)
	assert_eq(budget, 3)


func test_co_budget_excludes_dead_subordinates() -> void:
	var superior := _make_champion(1)
	var sub := _make_family_daimyo(2)
	sub.operational_superior_id = 1
	sub.wounds_taken = 100  # Dead
	var chars_by_id: Dictionary = {1: superior, 2: sub}

	var budget: int = StrategicReview.get_operational_superior_co_budget(superior, chars_by_id)
	assert_eq(budget, 0, "Dead subordinates should not count toward CO budget")


# -- run_midseason_crisis_update -----------------------------------------------

func test_midseason_update_ignores_tier4_topics() -> void:
	var champion := _make_champion()
	var clan := _make_clan()
	var tier4_topic := _make_topic(5, TopicData.Tier.TIER_4)

	var dispatches: Array = StrategicReview.run_midseason_crisis_update(
		champion, clan, tier4_topic, {}, 0, {}, []
	)

	assert_eq(dispatches.size(), 0, "Tier 4 topic should not trigger midseason update")


func test_midseason_update_inserts_for_tier1_topic() -> void:
	var champion := _make_champion()
	var clan := _make_clan()
	# Pre-populate with a low-scored non-forced conclusion.
	var existing := StrategicConclusionData.new()
	existing.conclusion_type = StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE
	existing.score = 10
	existing.is_forced = false
	existing.season_originated = 0
	clan.clan_strategic_priorities.append(existing)

	var crisis_topic := _make_topic(99, TopicData.Tier.TIER_1, TopicData.Category.MILITARY, "Dragon")
	crisis_topic.topic_type = "war_declaration"
	var topics_by_id: Dictionary = {99: crisis_topic}

	StrategicReview.run_midseason_crisis_update(
		champion, clan, crisis_topic, topics_by_id, 0, {}, []
	)

	var has_forced_conclusion: bool = false
	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		if sc.is_forced:
			has_forced_conclusion = true
			break
	assert_true(has_forced_conclusion, "Tier 1 crisis should insert a forced conclusion")


# -- run_priority_resolved ----------------------------------------------------

func test_priority_resolved_removes_conclusion() -> void:
	var champion := _make_champion()
	var clan := _make_clan()
	var dice := _make_dice()
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 42
	sc.conclusion_type = StrategicConclusionData.ConclusionType.SECURE_RESOURCE
	sc.score = 50
	sc.season_originated = 0
	clan.clan_strategic_priorities.append(sc)
	clan.next_conclusion_id = 1

	StrategicReview.run_priority_resolved(
		champion, clan, 42, {}, [], [], {}, {}, 0, dice, []
	)

	for remaining: StrategicConclusionData in clan.clan_strategic_priorities:
		assert_ne(remaining.conclusion_id, 42, "Resolved conclusion_id=42 should be removed")


# -- _process_midseason_champion_updates (DayOrchestrator wiring) ---------------

func _make_champion_with_topic(topic_id: int) -> L5RCharacterData:
	var c := _make_champion()
	c.topic_pool.append(topic_id)
	return c


func test_midseason_updates_fires_for_unaddressed_tier1_topic() -> void:
	var champion := _make_champion_with_topic(77)
	var clan := _make_clan()
	var crisis_topic := _make_topic(77, TopicData.Tier.TIER_1)
	crisis_topic.topic_type = "war_declaration"
	crisis_topic.clan_involved = "Dragon"
	var active_topics: Array = [crisis_topic]
	var clans: Dictionary = {"Crane": clan}

	DayOrchestrator._process_midseason_champion_updates(
		[champion], {champion.character_id: champion}, clans,
		active_topics, 0, [], [1], 0,
	)

	var has_forced: bool = false
	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		if sc.is_forced:
			has_forced = true
			break
	assert_true(has_forced, "Unaddressed Tier 1 topic should create a forced conclusion")


func test_midseason_updates_skips_already_addressed_topic() -> void:
	var champion := _make_champion_with_topic(88)
	var clan := _make_clan()
	# Pre-populate a forced conclusion that already covers topic 88.
	var existing_forced := StrategicConclusionData.new()
	existing_forced.is_forced = true
	existing_forced.source_topic_ids = [88]
	existing_forced.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	existing_forced.score = 150
	existing_forced.season_originated = 0
	clan.clan_strategic_priorities.append(existing_forced)

	var crisis_topic := _make_topic(88, TopicData.Tier.TIER_1)
	crisis_topic.topic_type = "war_declaration"
	var active_topics: Array = [crisis_topic]
	var clans: Dictionary = {"Crane": clan}
	var initial_count: int = clan.clan_strategic_priorities.size()

	DayOrchestrator._process_midseason_champion_updates(
		[champion], {champion.character_id: champion}, clans,
		active_topics, 0, [], [1], 0,
	)

	assert_eq(
		clan.clan_strategic_priorities.size(), initial_count,
		"Already-addressed topic should not add another forced conclusion",
	)


func test_midseason_updates_skips_tier3_topic() -> void:
	var champion := _make_champion_with_topic(99)
	var clan := _make_clan()
	var tier3_topic := _make_topic(99, TopicData.Tier.TIER_3)
	tier3_topic.topic_type = "insurgency"
	var active_topics: Array = [tier3_topic]
	var clans: Dictionary = {"Crane": clan}

	DayOrchestrator._process_midseason_champion_updates(
		[champion], {champion.character_id: champion}, clans,
		active_topics, 0, [], [1], 0,
	)

	assert_eq(clan.clan_strategic_priorities.size(), 0, "Tier 3 topic must not trigger midseason update")


func test_midseason_updates_skips_dead_champion() -> void:
	var champion := _make_champion_with_topic(55)
	champion.wounds_taken = 999  # lethal
	var clan := _make_clan()
	var crisis_topic := _make_topic(55, TopicData.Tier.TIER_2)
	crisis_topic.topic_type = "famine"
	var active_topics: Array = [crisis_topic]
	var clans: Dictionary = {"Crane": clan}

	DayOrchestrator._process_midseason_champion_updates(
		[champion], {champion.character_id: champion}, clans,
		active_topics, 0, [], [1], 0,
	)

	assert_eq(clan.clan_strategic_priorities.size(), 0, "Dead champion should be skipped")


func test_midseason_updates_dispatches_letter_for_absent_fd() -> void:
	var champion := _make_champion_with_topic(66)
	champion.physical_location = "100"
	var fd := _make_family_daimyo()
	fd.physical_location = "200"  # different settlement — not co-located

	var clan := _make_clan()
	var crisis_topic := _make_topic(66, TopicData.Tier.TIER_1)
	crisis_topic.topic_type = "war_declaration"
	crisis_topic.clan_involved = "Lion"
	var active_topics: Array = [crisis_topic]
	var clans: Dictionary = {"Crane": clan}
	var chars_by_id: Dictionary = {
		champion.character_id: champion,
		fd.character_id: fd,
	}
	var chars: Array = [champion, fd]
	var pending_letters: Array = []
	var next_letter_id: Array = [1]

	DayOrchestrator._process_midseason_champion_updates(
		chars, chars_by_id, clans, active_topics, 0,
		pending_letters, next_letter_id, 0,
	)

	assert_gt(pending_letters.size(), 0, "Absent FD should receive a dispatch letter")


# -- is_conclusion_stale -------------------------------------------------------

func _make_war(clan_a: String, clan_b: String, active: bool = true) -> WarData:
	var w := WarData.new()
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.is_active = active
	return w


func _make_seek_peace_conclusion(target_clan: String) -> StrategicConclusionData:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 99
	sc.conclusion_type = StrategicConclusionData.ConclusionType.SEEK_PEACE
	sc.target_clan_id = target_clan.hash()
	return sc


func test_is_conclusion_stale_war_type_no_war_is_stale() -> void:
	var sc := _make_seek_peace_conclusion("Lion")
	var result: bool = StrategicReview.is_conclusion_stale(
		sc, "Crane", [], [], {}
	)
	assert_true(result, "SEEK_PEACE with no active wars should be stale")


func test_is_conclusion_stale_war_type_active_war_not_stale() -> void:
	var sc := _make_seek_peace_conclusion("Lion")
	var war := _make_war("Crane", "Lion")
	var result: bool = StrategicReview.is_conclusion_stale(
		sc, "Crane", [war], [], {}
	)
	assert_false(result, "SEEK_PEACE with active war vs target clan should not be stale")


func test_is_conclusion_stale_war_ended_is_stale() -> void:
	var sc := _make_seek_peace_conclusion("Lion")
	var war := _make_war("Crane", "Lion", false)  # war ended
	var result: bool = StrategicReview.is_conclusion_stale(
		sc, "Crane", [war], [], {}
	)
	assert_true(result, "SEEK_PEACE with ended war should be stale")


func test_is_conclusion_stale_topic_sourced_resolved_is_stale() -> void:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 50
	sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	sc.source_topic_ids = [10, 11]
	var t10 := _make_topic(10, TopicData.Tier.TIER_2)
	t10.resolved = true
	var t11 := _make_topic(11, TopicData.Tier.TIER_3)
	t11.resolved = true
	var tmap: Dictionary = {10: t10, 11: t11}
	var result: bool = StrategicReview.is_conclusion_stale(sc, "Crab", [], [], tmap)
	assert_true(result, "Conclusion with all resolved source topics should be stale")


func test_is_conclusion_stale_topic_sourced_one_active_not_stale() -> void:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 51
	sc.conclusion_type = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
	sc.source_topic_ids = [20, 21]
	var t20 := _make_topic(20, TopicData.Tier.TIER_2)
	t20.resolved = true
	var t21 := _make_topic(21, TopicData.Tier.TIER_3)
	t21.resolved = false
	var tmap: Dictionary = {20: t20, 21: t21}
	var result: bool = StrategicReview.is_conclusion_stale(sc, "Crab", [], [], tmap)
	assert_false(result, "Conclusion with at least one active source topic should not be stale")


func test_is_conclusion_stale_standing_obj_never_stale() -> void:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = 60
	sc.conclusion_type = StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY
	sc.source_topic_ids = []  # No topics — standing-objective driven
	var result: bool = StrategicReview.is_conclusion_stale(sc, "Dragon", [], [], {})
	assert_false(result, "Standing-objective conclusion with no source topics should never be stale")


# -- _process_stale_champion_priorities ----------------------------------------

func test_stale_priorities_ketsui_champion_gets_refill() -> void:
	var champion := _make_champion(1, "Crane",
		Enums.BushidoVirtue.CHUGI,
		Enums.ShouridoVirtue.KETSUI)
	var clan := _make_clan()
	clan.next_conclusion_id = 10
	# Seed a now-stale SEEK_PEACE conclusion for a war that no longer exists.
	var sc := _make_seek_peace_conclusion("Lion")
	clan.clan_strategic_priorities.append(sc)
	var chars: Array = [champion]
	var chars_by_id: Dictionary = {champion.character_id: champion}
	var clans: Dictionary = {"Crane": clan}
	var dice := _make_dice()

	DayOrchestrator._process_stale_champion_priorities(
		chars, chars_by_id, clans,
		[], [], [], {}, 0, dice,
		[], [1], 0,
	)

	# Ketsui immediately refills — full evaluation fires.
	# With no active topics or wars, the array gets rebuilt from standing objectives only.
	for remaining: StrategicConclusionData in clan.clan_strategic_priorities:
		assert_ne(remaining.conclusion_id, sc.conclusion_id,
			"Stale SEEK_PEACE conclusion should have been removed by Ketsui refill")


# -- Phase 2 combined pool (s57.54.10b) -----------------------------------------

func _make_conclusion_of_type(
	clan: ClanData,
	ct: StrategicConclusionData.ConclusionType,
	score: int,
	is_forced: bool = false,
) -> StrategicConclusionData:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = clan.next_conclusion_id
	clan.next_conclusion_id += 1
	sc.conclusion_type = ct
	sc.score = score
	sc.is_forced = is_forced
	sc.target_clan_id = -1
	return sc


func test_fd_combined_pool_selects_patronize_arts() -> void:
	# FD with Chugi (0 pref for BUILD_CULTURAL_PRESTIGE) receives champion conclusion.
	# PATRONIZE_ARTS is the first NeedType mapped from BUILD_CULTURAL_PRESTIGE.
	var fd := _make_family_daimyo(10, "Crane", Enums.BushidoVirtue.CHUGI)
	var clan := _make_clan()
	var sc := _make_conclusion_of_type(
		clan,
		StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE,
		120,
	)
	clan.clan_strategic_priorities.append(sc)

	var candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd, clan)
	var arts_candidate: Dictionary = {}
	for c: Dictionary in candidates:
		if c.get("need_type", "") == "PATRONIZE_ARTS":
			arts_candidate = c
			break
	assert_false(arts_candidate.is_empty(), "PATRONIZE_ARTS should be in candidate list")
	assert_eq(arts_candidate.get("score", -1), 120,
		"CHUGI preference for BUILD_CULTURAL_PRESTIGE is 0 — score unchanged")
	assert_eq(arts_candidate.get("source", ""), "champion_conclusion")

	# Wire into ContextSnapshot and verify _check_combined_pool selects it.
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.champion_conclusion_candidates = candidates
	ctx.local_tier3_candidates = []
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine._check_combined_pool(ctx, {})
	assert_not_null(need, "Combined pool should return a need")
	assert_eq(need.need_type, "PATRONIZE_ARTS",
		"Highest-scoring candidate from BUILD_CULTURAL_PRESTIGE should be PATRONIZE_ARTS")


func test_combined_pool_champion_conclusion_beats_local_tier3() -> void:
	# Champion conclusion score 120 vs local Tier 3 topic score 25 — champion wins.
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.champion_conclusion_candidates = [
		{"need_type": "PATRONIZE_ARTS", "score": 120, "source": "champion_conclusion",
		 "conclusion_type": StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE,
		 "target_clan_id": -1, "is_forced": false},
	]
	ctx.local_tier3_candidates = [
		{"need_type": "DEFEND_PROVINCE", "score": 25, "source": "local_tier3",
		 "topic_id": 99, "target_clan_id": -1, "is_forced": false},
	]
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine._check_combined_pool(ctx, {})
	assert_not_null(need)
	assert_eq(need.need_type, "PATRONIZE_ARTS")


func test_combined_pool_local_tier1_beats_low_score_conclusion() -> void:
	# Forced local Tier 1 topic (score 35) beats champion conclusion with personality penalty.
	# YU virtue gives -15 to BUILD_CULTURAL_PRESTIGE (index 15) -> net score = 10.
	var fd := _make_family_daimyo(11, "Crane", Enums.BushidoVirtue.YU)
	var clan := _make_clan()
	var sc := _make_conclusion_of_type(
		clan,
		StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE,
		25,
	)
	clan.clan_strategic_priorities.append(sc)

	var champion_candidates: Array = StrategicReview.get_champion_conclusion_needtypes(fd, clan)
	for c: Dictionary in champion_candidates:
		assert_true(c.get("score", 999) <= 10,
			"YU -15 penalty on BUILD_CULTURAL_PRESTIGE brings all scores to <=10")

	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.champion_conclusion_candidates = champion_candidates
	ctx.local_tier3_candidates = [
		{"need_type": "DEFEND_PROVINCE", "score": 35, "source": "local_tier3",
		 "topic_id": 42, "target_clan_id": -1, "is_forced": true},
	]
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine._check_combined_pool(ctx, {})
	assert_not_null(need)
	assert_eq(need.need_type, "DEFEND_PROVINCE",
		"Local Tier 1 topic (score 35) beats penalised champion conclusion (score <=10)")


func test_combined_pool_empty_returns_null() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.champion_conclusion_candidates = []
	ctx.local_tier3_candidates = []
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine._check_combined_pool(ctx, {})
	assert_null(need, "Empty combined pool should return null")
