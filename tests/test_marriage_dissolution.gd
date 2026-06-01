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
	assert_eq(char_a.glory, 4.5)  # s57.49b: DISSOLUTION_GLORY_LOSS_SPOUSE = -0.5
	assert_eq(char_b.glory, 4.5)


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


# -- Pathway 3: Monastic Retirement -------------------------------------------

func test_get_dissolution_topic_variant_pathway_3():
	assert_eq(MarriageSystem.get_dissolution_topic_variant(3), "monastic_retirement")


func test_auto_dissolve_monastic_retirement_marks_inactive():
	var retiree: L5RCharacterData = _make_char(20, 21)
	var spouse: L5RCharacterData = _make_char(21, 20)
	retiree.is_retired_monastic = true
	var chars: Dictionary = {20: retiree, 21: spouse}
	var marriages: Array = [_make_marriage(20, 21)]
	var results: Array = DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, marriages, 300, [], [1100],
	)
	assert_eq(results.size(), 1)
	assert_true(results[0]["applied"])
	assert_false(marriages[0]["active"])


func test_auto_dissolve_monastic_retirement_clears_spouse_ids():
	var retiree: L5RCharacterData = _make_char(22, 23)
	var spouse: L5RCharacterData = _make_char(23, 22)
	retiree.is_retired_monastic = true
	var chars: Dictionary = {22: retiree, 23: spouse}
	var marriages: Array = [_make_marriage(22, 23)]
	DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, marriages, 300, [], [1100],
	)
	assert_eq(retiree.spouse_id, -1)
	assert_eq(spouse.spouse_id, -1)


func test_auto_dissolve_monastic_retirement_no_glory_loss():
	var retiree: L5RCharacterData = _make_char(24, 25)
	var spouse: L5RCharacterData = _make_char(25, 24)
	retiree.glory = 5.0
	spouse.glory = 5.0
	retiree.is_retired_monastic = true
	var chars: Dictionary = {24: retiree, 25: spouse}
	var marriages: Array = [_make_marriage(24, 25)]
	DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, marriages, 300, [], [1100],
	)
	assert_eq(retiree.glory, 5.0)
	assert_eq(spouse.glory, 5.0)


func test_auto_dissolve_monastic_retirement_topic_variant():
	var retiree: L5RCharacterData = _make_char(26, 27)
	var spouse: L5RCharacterData = _make_char(27, 26)
	retiree.is_retired_monastic = true
	var chars: Dictionary = {26: retiree, 27: spouse}
	var marriages: Array = [_make_marriage(26, 27)]
	var active_topics: Array = []
	DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, marriages, 300, active_topics, [1200],
	)
	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.variant, "monastic_retirement")


func test_auto_dissolve_monastic_skips_unmarried():
	var retiree: L5RCharacterData = _make_char(28)  # No spouse.
	retiree.is_retired_monastic = true
	var chars: Dictionary = {28: retiree}
	var results: Array = DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, [], 300, [], [1100],
	)
	assert_eq(results.size(), 0)


func test_auto_dissolve_monastic_skips_non_retired():
	var char_a: L5RCharacterData = _make_char(29, 30)
	var char_b: L5RCharacterData = _make_char(30, 29)
	# is_retired_monastic stays false (default)
	var chars: Dictionary = {29: char_a, 30: char_b}
	var marriages: Array = [_make_marriage(29, 30)]
	var results: Array = DayOrchestrator._auto_dissolve_on_monastic_retirement(
		chars, marriages, 300, [], [1100],
	)
	assert_eq(results.size(), 0)
	assert_eq(char_a.spouse_id, 30)  # Unchanged.


# -- Pathway 4: Imperial Decree -----------------------------------------------

func test_get_dissolution_topic_variant_pathway_4():
	assert_eq(MarriageSystem.get_dissolution_topic_variant(4), "imperial_decree")


func test_apply_dissolution_pathway4_marks_inactive():
	var char_a: L5RCharacterData = _make_char(40, 41)
	var char_b: L5RCharacterData = _make_char(41, 40)
	var chars: Dictionary = {40: char_a, 41: char_b}
	var marriages: Array = [_make_marriage(40, 41)]
	var effects: Dictionary = {
		"spouse_a_id": 40, "spouse_b_id": 41,
		"ordering_lord_id": 99, "pathway": 4,
	}
	var result: Dictionary = DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 400, [], [2000],
	)
	assert_true(result["applied"])
	assert_false(marriages[0]["active"])


func test_apply_dissolution_pathway4_no_glory_loss():
	var char_a: L5RCharacterData = _make_char(42, 43)
	var char_b: L5RCharacterData = _make_char(43, 42)
	char_a.glory = 5.0
	char_b.glory = 5.0
	var chars: Dictionary = {42: char_a, 43: char_b}
	var marriages: Array = [_make_marriage(42, 43)]
	var effects: Dictionary = {
		"spouse_a_id": 42, "spouse_b_id": 43,
		"ordering_lord_id": 99, "pathway": 4,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 400, [], [2000],
	)
	assert_eq(char_a.glory, 5.0)
	assert_eq(char_b.glory, 5.0)


func test_apply_dissolution_pathway4_topic_variant():
	var char_a: L5RCharacterData = _make_char(44, 45)
	var char_b: L5RCharacterData = _make_char(45, 44)
	var chars: Dictionary = {44: char_a, 45: char_b}
	var marriages: Array = [_make_marriage(44, 45)]
	var active_topics: Array = []
	var effects: Dictionary = {
		"spouse_a_id": 44, "spouse_b_id": 45,
		"ordering_lord_id": 99, "pathway": 4,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 400, active_topics, [2100],
	)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.variant, "imperial_decree")


func test_apply_dissolution_pathway4_no_clan_penalty():
	var char_a: L5RCharacterData = _make_cross_clan_char(46, "Crane", "Doji", 47)
	var char_b: L5RCharacterData = _make_cross_clan_char(47, "Lion", "Matsu", 46)
	var chars: Dictionary = {46: char_a, 47: char_b}
	var marriages: Array = [_make_marriage(46, 47)]
	var clan_baselines: Dictionary = {
		"Crane": {"Lion": 0},
		"Lion": {"Crane": 0},
	}
	var effects: Dictionary = {
		"spouse_a_id": 46, "spouse_b_id": 47,
		"ordering_lord_id": 99, "pathway": 4,
	}
	DayOrchestrator._apply_dissolution(
		effects, chars, marriages, 400, [], [2000], clan_baselines, {},
	)
	assert_eq(clan_baselines["Crane"]["Lion"], 0)
	assert_eq(clan_baselines["Lion"]["Crane"], 0)


# -- Pathway 4: Imperial war-marriage detection --------------------------------

func _make_war(clan_a: String, clan_b: String, active: bool = true) -> WarData:
	var w := WarData.new()
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.is_active = active
	return w


func test_evaluate_war_marriages_produces_directive():
	var emperor: L5RCharacterData = _make_char(1)
	emperor.character_id = 1
	var char_a: L5RCharacterData = _make_cross_clan_char(50, "Crane", "Doji", 51)
	var char_b: L5RCharacterData = _make_cross_clan_char(51, "Lion", "Matsu", 50)
	var chars: Dictionary = {50: char_a, 51: char_b}
	var marriages: Array = [_make_marriage(50, 51)]
	var wars: Array = [_make_war("Crane", "Lion")]
	var result: Array = StrategicReview._evaluate_war_marriages(
		emperor, marriages, wars, chars,
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["directive"], "IMPERIAL_DISSOLVE_MARRIAGE")
	assert_eq(result[0]["spouse_a_id"], 50)
	assert_eq(result[0]["spouse_b_id"], 51)


func test_evaluate_war_marriages_skips_same_clan():
	var emperor: L5RCharacterData = _make_char(1)
	var char_a: L5RCharacterData = _make_char(52, 53)
	var char_b: L5RCharacterData = _make_char(53, 52)
	# Both Crane — no cross-clan war-marriage.
	var chars: Dictionary = {52: char_a, 53: char_b}
	var marriages: Array = [_make_marriage(52, 53)]
	var wars: Array = [_make_war("Crane", "Lion")]
	var result: Array = StrategicReview._evaluate_war_marriages(
		emperor, marriages, wars, chars,
	)
	assert_eq(result.size(), 0)


func test_evaluate_war_marriages_skips_no_active_war():
	var emperor: L5RCharacterData = _make_char(1)
	var char_a: L5RCharacterData = _make_cross_clan_char(54, "Crane", "Doji", 55)
	var char_b: L5RCharacterData = _make_cross_clan_char(55, "Lion", "Matsu", 54)
	var chars: Dictionary = {54: char_a, 55: char_b}
	var marriages: Array = [_make_marriage(54, 55)]
	var wars: Array = [_make_war("Crane", "Lion", false)]  # Inactive war.
	var result: Array = StrategicReview._evaluate_war_marriages(
		emperor, marriages, wars, chars,
	)
	assert_eq(result.size(), 0)


func test_evaluate_war_marriages_skips_inactive_marriage():
	var emperor: L5RCharacterData = _make_char(1)
	var char_a: L5RCharacterData = _make_cross_clan_char(56, "Crane", "Doji", 57)
	var char_b: L5RCharacterData = _make_cross_clan_char(57, "Lion", "Matsu", 56)
	var chars: Dictionary = {56: char_a, 57: char_b}
	var m: Dictionary = _make_marriage(56, 57)
	MarriageSystem.dissolve_marriage(m)  # Mark inactive.
	var marriages: Array = [m]
	var wars: Array = [_make_war("Crane", "Lion")]
	var result: Array = StrategicReview._evaluate_war_marriages(
		emperor, marriages, wars, chars,
	)
	assert_eq(result.size(), 0)


func test_evaluate_war_marriages_non_belligerent_clans_not_dissolved():
	var emperor: L5RCharacterData = _make_char(1)
	var char_a: L5RCharacterData = _make_cross_clan_char(58, "Crane", "Doji", 59)
	var char_b: L5RCharacterData = _make_cross_clan_char(59, "Scorpion", "Bayushi", 58)
	var chars: Dictionary = {58: char_a, 59: char_b}
	var marriages: Array = [_make_marriage(58, 59)]
	var wars: Array = [_make_war("Crane", "Lion")]  # Scorpion not at war here.
	var result: Array = StrategicReview._evaluate_war_marriages(
		emperor, marriages, wars, chars,
	)
	assert_eq(result.size(), 0)


# -- Phoenix Champion Stage 4 accept/refuse (s55.10.3.5) ----------------------

func _make_phoenix_champion(id: int, virtue: Enums.BushidoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "ShibaChampion"
	c.clan = "Phoenix"
	c.family = "Shiba"
	c.lord_id = -1  # Champion has no lord.
	c.honor = 5.0
	c.glory = 5.0
	c.status = 7.0
	c.bushido_virtue = virtue
	return c


func _make_elemental_master(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "ElementalMaster"
	c.clan = "Phoenix"
	c.family = "Isawa"
	c.lord_id = -1
	c.honor = 5.0
	c.glory = 5.0
	c.status = 6.0
	c.role_position = "Master of Fire"
	return c


func _make_phoenix_state_stage4() -> Dictionary:
	return {"defiance_stage": 4}


func test_phoenix_champion_meiyo_accepts_removal():
	var champion: L5RCharacterData = _make_phoenix_champion(200, Enums.BushidoVirtue.MEIYO)
	var master: L5RCharacterData = _make_elemental_master(201)
	var chars: Array = [champion, master]
	var chars_by_id: Dictionary = {200: champion, 201: master}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var active_successions: Array = []
	var next_succession_id: Array = [1]
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
		[], {}, 0, {}, -1,
		active_successions, next_succession_id,
	)
	assert_true(result.get("champion_accepted_removal", false))
	assert_false(result.has("champion_defiance_civil_war_triggered"))
	assert_true(champion.is_retired_monastic)
	assert_eq(int(phoenix_state.get("defiance_stage", -1)), 0)


func test_phoenix_champion_chugi_accepts_removal():
	var champion: L5RCharacterData = _make_phoenix_champion(202, Enums.BushidoVirtue.CHUGI)
	var chars: Array = [champion]
	var chars_by_id: Dictionary = {202: champion}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var active_successions: Array = []
	var next_succession_id: Array = [1]
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
		[], {}, 0, {}, -1,
		active_successions, next_succession_id,
	)
	assert_true(result.get("champion_accepted_removal", false))
	assert_true(champion.is_retired_monastic)
	assert_eq(int(phoenix_state.get("defiance_stage", -1)), 0)


func test_phoenix_champion_rei_accepts_removal():
	var champion: L5RCharacterData = _make_phoenix_champion(203, Enums.BushidoVirtue.REI)
	var chars: Array = [champion]
	var chars_by_id: Dictionary = {203: champion}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var active_successions: Array = []
	var next_succession_id: Array = [1]
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
		[], {}, 0, {}, -1,
		active_successions, next_succession_id,
	)
	assert_true(result.get("champion_accepted_removal", false))
	assert_true(champion.is_retired_monastic)


func test_phoenix_champion_acceptance_creates_succession():
	var champion: L5RCharacterData = _make_phoenix_champion(204, Enums.BushidoVirtue.MEIYO)
	var chars: Array = [champion]
	var chars_by_id: Dictionary = {204: champion}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var active_successions: Array = []
	var next_succession_id: Array = [5]
	var dice := DiceEngine.new(42)
	DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
		[], {}, 0, {}, -1,
		active_successions, next_succession_id,
	)
	assert_eq(active_successions.size(), 1)
	var succ: SuccessionData = active_successions[0] as SuccessionData
	assert_not_null(succ)
	assert_eq(succ.cause, SuccessionData.VacancyCause.RETIREMENT)
	assert_eq(succ.succession_id, 5)
	assert_eq(next_succession_id[0], 6)


func test_phoenix_champion_ketsui_refuses_removal():
	var champion: L5RCharacterData = _make_phoenix_champion(205, Enums.BushidoVirtue.KETSUI)
	var master: L5RCharacterData = _make_elemental_master(206)
	var chars: Array = [champion, master]
	var chars_by_id: Dictionary = {205: champion, 206: master}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var active_successions: Array = []
	var next_succession_id: Array = [1]
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
		[], {}, 0, {}, -1,
		active_successions, next_succession_id,
	)
	assert_false(result.get("champion_accepted_removal", false))
	assert_false(champion.is_retired_monastic)
	# defiance_stage NOT reset.
	assert_eq(int(phoenix_state.get("defiance_stage", -1)), 4)
	assert_true(result.has("champion_defiance_civil_war_triggered"))


func test_phoenix_champion_ishi_refuses_removal():
	var champion: L5RCharacterData = _make_phoenix_champion(207, Enums.BushidoVirtue.ISHI)
	var master: L5RCharacterData = _make_elemental_master(208)
	var chars: Array = [champion, master]
	var chars_by_id: Dictionary = {207: champion, 208: master}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
	)
	assert_false(champion.is_retired_monastic)
	assert_eq(int(phoenix_state.get("defiance_stage", -1)), 4)
	assert_true(result.has("champion_defiance_civil_war_triggered"))


func test_phoenix_champion_no_master_accepts_gracefully():
	# When no senior master exists on the refusal path, no civil war fires.
	var champion: L5RCharacterData = _make_phoenix_champion(209, Enums.BushidoVirtue.KETSUI)
	var chars: Array = [champion]
	var chars_by_id: Dictionary = {209: champion}
	var phoenix_state: Dictionary = _make_phoenix_state_stage4()
	var dice := DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		phoenix_state, [], chars, chars_by_id, dice,
		[], [100], 360,
	)
	# No crash; civil war silently skipped (no master to be authority).
	assert_false(result.get("champion_accepted_removal", false))
	assert_false(result.has("champion_defiance_civil_war_triggered"))


# -- _build_dissolve_marriage_metadata targeting gate (s57.49.7) --------------

func _make_dissolve_ctx(lord_id: int, disp: Dictionary = {}) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = lord_id
	ctx.character_name = "Lord%d" % lord_id
	ctx.clan = "Crane"
	ctx.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	ctx.disposition_values = disp
	return ctx


func _make_dissolve_need() -> NPCDataStructures.ImmediateNeed:
	var n := NPCDataStructures.ImmediateNeed.new()
	n.need_type = "DAMAGE_RELATIONSHIP"
	n.target_npc_id = -1
	return n


func test_dissolve_metadata_gate_passes_on_enemy_spouse_disp():
	# Lord has Enemy-tier disp toward spouse directly → gate passes.
	var vassal: L5RCharacterData = _make_cross_clan_char(10, "Lion", "Matsu", -1, 1)
	var spouse: L5RCharacterData = _make_cross_clan_char(20, "Lion", "Matsu", -1, 99)
	vassal.spouse_id = 20
	var ctx := _make_dissolve_ctx(1, {20: -35, 99: 0})
	var chars_by_id: Dictionary = {1: _make_char(1, -1, -1), 10: vassal, 20: spouse}
	chars_by_id[1].lord_id = -1
	vassal.lord_id = 1
	var meta: Dictionary = NPCDecisionEngine._build_dissolve_marriage_metadata(
		_make_dissolve_need(), ctx, chars_by_id,
	)
	assert_eq(meta.get("spouse_a_id", -1), 10)
	assert_eq(meta.get("spouse_b_id", -1), 20)


func test_dissolve_metadata_gate_passes_on_enemy_spouse_lord_disp():
	# Lord has neutral disp toward spouse but Enemy-tier toward spouse's lord → gate passes (s57.49.7).
	var vassal: L5RCharacterData = _make_cross_clan_char(11, "Lion", "Matsu", -1, 1)
	var spouse: L5RCharacterData = _make_cross_clan_char(21, "Lion", "Matsu", -1, 50)
	var spouse_lord: L5RCharacterData = _make_cross_clan_char(50, "Lion", "Akodo", -1, -1)
	vassal.spouse_id = 21
	var ctx := _make_dissolve_ctx(1, {21: 0, 50: -40})
	var chars_by_id: Dictionary = {
		1: _make_char(1, -1, -1), 11: vassal, 21: spouse, 50: spouse_lord
	}
	vassal.lord_id = 1
	var meta: Dictionary = NPCDecisionEngine._build_dissolve_marriage_metadata(
		_make_dissolve_need(), ctx, chars_by_id,
	)
	assert_eq(meta.get("spouse_a_id", -1), 11)
	assert_eq(meta.get("spouse_b_id", -1), 21)


func test_dissolve_metadata_gate_blocked_when_both_neutral():
	# Lord has neutral disp toward both spouse and spouse's lord → gate does not pass, fallback returns -1.
	var vassal: L5RCharacterData = _make_cross_clan_char(12, "Lion", "Matsu", -1, 1)
	var spouse: L5RCharacterData = _make_cross_clan_char(22, "Lion", "Matsu", -1, 50)
	var spouse_lord: L5RCharacterData = _make_cross_clan_char(50, "Lion", "Akodo", -1, -1)
	vassal.spouse_id = 22
	var ctx := _make_dissolve_ctx(1, {22: -10, 50: 5})
	var chars_by_id: Dictionary = {
		1: _make_char(1, -1, -1), 12: vassal, 22: spouse, 50: spouse_lord
	}
	vassal.lord_id = 1
	var meta: Dictionary = NPCDecisionEngine._build_dissolve_marriage_metadata(
		_make_dissolve_need(), ctx, chars_by_id,
	)
	assert_eq(meta.get("spouse_a_id", -1), -1)
