extends GutTest
## Tests for DISSOLVE_MARRIAGE — s57.49.7.


# -- Helpers -------------------------------------------------------------------

func _make_char(id: int, spouse: int = -1, lord: int = -1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Char%d" % id
	c.clan = "Crane"
	c.family = "Doji"
	c.spouse_id = spouse
	c.lord_id = lord
	c.honor = 5.0
	c.glory = 5.0
	return c


func _make_cross_clan_char(id: int, clan: String, family: String, spouse: int = -1, lord: int = -1) -> L5RCharacterData:
	var c := _make_char(id, spouse, lord)
	c.clan = clan
	c.family = family
	return c


func _make_marriage(a_id: int, b_id: int, active: bool = true) -> Dictionary:
	return MarriageSystem.create_marriage(
		a_id, b_id, MarriageSystem.MarriageType.CROSS_CLAN, b_id, 0,
	)


# -- MarriageSystem helpers ----------------------------------------------------

func test_dissolve_marriage_marks_inactive():
	var m: Dictionary = _make_marriage(1, 2)
	assert_true(m["active"])
	MarriageSystem.dissolve_marriage(m)
	assert_false(m["active"])


func test_find_active_marriage_found():
	var m: Dictionary = _make_marriage(10, 20)
	var marriages: Array = [m]
	var found: Dictionary = MarriageSystem.find_active_marriage_for_character(10, marriages)
	assert_false(found.is_empty())
	assert_eq(found["character_a_id"], 10)


func test_find_active_marriage_not_found_when_inactive():
	var m: Dictionary = _make_marriage(10, 20)
	MarriageSystem.dissolve_marriage(m)
	var marriages: Array = [m]
	var found: Dictionary = MarriageSystem.find_active_marriage_for_character(10, marriages)
	assert_true(found.is_empty())


func test_find_active_marriage_by_b_id():
	var m: Dictionary = _make_marriage(10, 20)
	var marriages: Array = [m]
	var found: Dictionary = MarriageSystem.find_active_marriage_for_character(20, marriages)
	assert_false(found.is_empty())


func test_get_dissolution_topic_variant_pathway_1():
	assert_eq(MarriageSystem.get_dissolution_topic_variant(1), "lord_command")


func test_get_dissolution_topic_variant_pathway_2():
	assert_eq(MarriageSystem.get_dissolution_topic_variant(2), "criminal_conviction")


func test_get_dissolution_topic_variant_pathway_3():
	assert_eq(MarriageSystem.get_dissolution_topic_variant(3), "monastic_retirement")


# -- _apply_dissolution pathway 1 (via DayOrchestrator) -----------------------

func test_apply_dissolution_pathway1_marks_marriage_inactive():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var active_topics: Array = []
	var next_topic_id: Array = [500]

	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": 99, "pathway": 1,
	}
	var result: Dictionary = DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, active_topics, next_topic_id,
	)
	assert_true(result["applied"])
	assert_false(marriages[0]["active"])


func test_apply_dissolution_pathway1_clears_spouse_ids():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": 99, "pathway": 1,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500],
	)
	assert_eq(char_a.spouse_id, -1)
	assert_eq(char_b.spouse_id, -1)


func test_apply_dissolution_pathway1_glory_loss():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	char_a.glory = 5.0
	char_b.glory = 5.0
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": 99, "pathway": 1,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500],
	)
	assert_eq(char_a.glory, 4.0)
	assert_eq(char_b.glory, 4.0)


func test_apply_dissolution_pathway2_no_glory_loss():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	char_a.glory = 5.0
	char_b.glory = 5.0
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": -1, "pathway": 2, "convicted_id": 1,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500],
	)
	assert_eq(char_a.glory, 5.0)
	assert_eq(char_b.glory, 5.0)


func test_apply_dissolution_creates_topic():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var active_topics: Array = []
	var next_topic_id: Array = [600]
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": 99, "pathway": 1,
	}
	var result: Dictionary = DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, active_topics, next_topic_id,
	)
	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.topic_type, "marriage_dissolved")
	assert_eq(topic.variant, "lord_command")
	assert_eq(topic.tier, TopicData.Tier.TIER_4)
	assert_eq(result["topic_id"], 600)


func test_apply_dissolution_pathway2_topic_variant():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var active_topics: Array = []
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2,
		"ordering_lord_id": -1, "pathway": 2,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, active_topics, [700],
	)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.variant, "criminal_conviction")


func test_apply_dissolution_fails_missing_ids():
	var chars: Dictionary = {}
	var marriages: Array = []
	var effects: Dictionary = {"spouse_a_id": -1, "spouse_b_id": -1, "pathway": 1}
	var result: Dictionary = DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "missing_spouse_ids")


func test_apply_dissolution_fails_no_active_marriage():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = []  # No marriage record
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2, "pathway": 1,
	}
	var result: Dictionary = DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_active_marriage")


func test_apply_dissolution_cross_clan_clan_baseline_penalty():
	var char_a: L5RCharacterData = _make_cross_clan_char(1, "Crane", "Doji", 2)
	var char_b: L5RCharacterData = _make_cross_clan_char(2, "Lion", "Matsu", 1)
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var clan_baselines: Dictionary = {
		"Crane": {"Lion": 0},
		"Lion": {"Crane": 0},
	}
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2, "pathway": 1,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500], clan_baselines, {},
	)
	assert_eq(clan_baselines["Crane"]["Lion"], MarriageSystem.DISSOLUTION_CLAN_DISP_PENALTY)
	assert_eq(clan_baselines["Lion"]["Crane"], MarriageSystem.DISSOLUTION_CLAN_DISP_PENALTY)


func test_apply_dissolution_same_clan_no_clan_baseline_penalty():
	var char_a: L5RCharacterData = _make_char(1, 2)
	var char_b: L5RCharacterData = _make_char(2, 1)
	# Both Crane.
	var chars: Dictionary = {1: char_a, 2: char_b}
	var marriages: Array = [_make_marriage(1, 2)]
	var clan_baselines: Dictionary = {"Crane": {"Crane": 0}}
	var effects: Dictionary = {
		"spouse_a_id": 1, "spouse_b_id": 2, "pathway": 1,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 100, [], [500], clan_baselines, {},
	)
	# Same clan: no clan-level penalty applied.
	assert_eq(clan_baselines["Crane"]["Crane"], 0)


# -- _auto_dissolve_marriage_on_conviction ------------------------------------

func test_auto_dissolve_treason_conviction():
	var accused: L5RCharacterData = _make_char(5, 10)
	var spouse: L5RCharacterData = _make_char(10, 5)
	var chars: Dictionary = {5: accused, 10: spouse}
	var marriages: Array = [_make_marriage(5, 10)]
	var active_topics: Array = []
	var next_topic_id: Array = [800]
	var conviction_results: Array = [
		{
			"accused_id": 5,
			"outcome": "convicted",
			"crime_type": Enums.CrimeType.TREASON,
		}
	]
	var results: Array = DayOrchestrator._auto_dissolve_marriage_on_conviction(
		conviction_results, chars, marriages, 200, active_topics, next_topic_id,
	)
	assert_eq(results.size(), 1)
	assert_true(results[0]["applied"])
	assert_eq(accused.spouse_id, -1)
	assert_eq(results[0]["pathway"], 2)


func test_auto_dissolve_maho_conviction():
	var accused: L5RCharacterData = _make_char(6, 11)
	var spouse: L5RCharacterData = _make_char(11, 6)
	var chars: Dictionary = {6: accused, 11: spouse}
	var marriages: Array = [_make_marriage(6, 11)]
	var active_topics: Array = []
	var conviction_results: Array = [
		{
			"accused_id": 6,
			"outcome": "convicted",
			"crime_type": Enums.CrimeType.MAHO,
		}
	]
	var results: Array = DayOrchestrator._auto_dissolve_marriage_on_conviction(
		conviction_results, chars, marriages, 200, active_topics, [900],
	)
	assert_true(results[0]["applied"])
	assert_eq(accused.spouse_id, -1)


func test_auto_dissolve_tier2_crime_no_dissolution():
	# Only Tier 1 crimes (TREASON, MAHO) trigger auto-dissolution.
	var accused: L5RCharacterData = _make_char(7, 12)
	var spouse: L5RCharacterData = _make_char(12, 7)
	var chars: Dictionary = {7: accused, 12: spouse}
	var marriages: Array = [_make_marriage(7, 12)]
	var conviction_results: Array = [
		{
			"accused_id": 7,
			"outcome": "convicted",
			"crime_type": Enums.CrimeType.DISHONORABLE_CONDUCT,
		}
	]
	var results: Array = DayOrchestrator._auto_dissolve_marriage_on_conviction(
		conviction_results, chars, marriages, 200, [], [1000],
	)
	assert_eq(results.size(), 0)
	assert_eq(accused.spouse_id, 12)  # Unchanged.


func test_auto_dissolve_skips_unmarried():
	var accused: L5RCharacterData = _make_char(8)  # No spouse.
	var chars: Dictionary = {8: accused}
	var marriages: Array = []
	var conviction_results: Array = [
		{
			"accused_id": 8,
			"outcome": "convicted",
			"crime_type": Enums.CrimeType.TREASON,
		}
	]
	var results: Array = DayOrchestrator._auto_dissolve_marriage_on_conviction(
		conviction_results, chars, marriages, 200, [], [1000],
	)
	assert_eq(results.size(), 0)
