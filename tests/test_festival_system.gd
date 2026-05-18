extends GutTest
## Tests for FestivalSystem per GDD s11.5.


# -- Rokuyo cycle tests -------------------------------------------------------

func test_rokuyo_day_1_is_sensho():
	assert_eq(FestivalSystem.get_rokuyo(1), FestivalSystem.Rokuyo.SENSHO)


func test_rokuyo_day_2_is_tomobiki():
	assert_eq(FestivalSystem.get_rokuyo(2), FestivalSystem.Rokuyo.TOMOBIKI)


func test_rokuyo_day_5_is_taian():
	assert_eq(FestivalSystem.get_rokuyo(5), FestivalSystem.Rokuyo.TAIAN)


func test_rokuyo_day_6_is_shakko():
	assert_eq(FestivalSystem.get_rokuyo(6), FestivalSystem.Rokuyo.SHAKKO)


func test_rokuyo_day_7_wraps_to_sensho():
	assert_eq(FestivalSystem.get_rokuyo(7), FestivalSystem.Rokuyo.SENSHO)


func test_rokuyo_day_12_is_shakko():
	assert_eq(FestivalSystem.get_rokuyo(12), FestivalSystem.Rokuyo.SHAKKO)


func test_rokuyo_name_sensho():
	assert_eq(FestivalSystem.get_rokuyo_name(1), "Sensho")


func test_rokuyo_name_taian():
	assert_eq(FestivalSystem.get_rokuyo_name(5), "Taian")


func test_taian_bonus_on_taian_day():
	assert_eq(FestivalSystem.get_taian_bonus(5), 1)


func test_taian_bonus_on_non_taian_day():
	assert_eq(FestivalSystem.get_taian_bonus(1), 0)


func test_butsumetsu_inauspicious():
	assert_true(FestivalSystem.is_inauspicious_for_social(4))


func test_tomobiki_inauspicious():
	assert_true(FestivalSystem.is_inauspicious_for_social(2))


func test_taian_not_inauspicious():
	assert_false(FestivalSystem.is_inauspicious_for_social(5))


func test_sensho_not_inauspicious():
	assert_false(FestivalSystem.is_inauspicious_for_social(1))


# -- Calendar helper tests ----------------------------------------------------

func test_month_day_1():
	assert_eq(FestivalSystem.get_month(1), 1)


func test_month_day_30():
	assert_eq(FestivalSystem.get_month(30), 1)


func test_month_day_31():
	assert_eq(FestivalSystem.get_month(31), 2)


func test_month_day_360():
	assert_eq(FestivalSystem.get_month(360), 12)


func test_day_of_month_first():
	assert_eq(FestivalSystem.get_day_of_month(1), 1)


func test_day_of_month_last():
	assert_eq(FestivalSystem.get_day_of_month(30), 30)


func test_day_of_month_31():
	assert_eq(FestivalSystem.get_day_of_month(31), 1)


func test_season_spring():
	assert_eq(FestivalSystem.get_season(1), 0)


func test_season_summer():
	assert_eq(FestivalSystem.get_season(91), 1)


func test_season_autumn():
	assert_eq(FestivalSystem.get_season(181), 2)


func test_season_winter():
	assert_eq(FestivalSystem.get_season(241), 3)


# -- Canonical festival tests -------------------------------------------------

func test_new_year_festival_on_day_1():
	var fests := FestivalSystem.get_active_festivals(1)
	var names: Array[String] = []
	for f in fests:
		names.append(f["name"])
	assert_true(names.has("New Year's Festival"))


func test_cherry_blossom_on_month1_day15():
	# Month 1, day 15 → IC day 15
	var fests := FestivalSystem.get_active_festivals(15)
	var names: Array[String] = []
	for f in fests:
		names.append(f["name"])
	assert_true(names.has("Cherry Blossom Festival"))


func test_no_festival_on_random_day():
	# Month 2, day 1 → IC day 31 — no festival defined here
	var fests := FestivalSystem.get_active_festivals(31)
	assert_eq(fests.size(), 0)


func test_ceasefire_on_setsuban():
	# Setsuban: month 6, day 8 → IC day (5*30)+8 = 158
	assert_true(FestivalSystem.is_ceasefire_day(158))


func test_no_ceasefire_on_normal_day():
	assert_false(FestivalSystem.is_ceasefire_day(1))


func test_labor_halt_chrysanthemum_start():
	# Month 4, day 6 → IC day (3*30)+6 = 96
	assert_true(FestivalSystem.is_labor_halt_day(96))


func test_labor_halt_chrysanthemum_end():
	# Month 4, day 12 → IC day (3*30)+12 = 102
	assert_true(FestivalSystem.is_labor_halt_day(102))


func test_labor_halt_before_chrysanthemum():
	# Month 4, day 5 → IC day 95
	assert_false(FestivalSystem.is_labor_halt_day(95))


func test_labor_halt_after_chrysanthemum():
	# Month 4, day 13 → IC day 103
	assert_false(FestivalSystem.is_labor_halt_day(103))


func test_marriage_bonus_day():
	# Month 11, day 9 → IC day (10*30)+9 = 309
	assert_true(FestivalSystem.is_marriage_bonus_day(309))


func test_not_marriage_bonus_day():
	assert_false(FestivalSystem.is_marriage_bonus_day(100))


# -- Festival effects tests ---------------------------------------------------

func test_festival_effects_new_year():
	var effects := FestivalSystem.get_festival_effects(1)
	assert_true(effects.has("stability_bonus"))


func test_honor_gain_bon_festival():
	# Bon Festival: month 8, day 28 → IC day (7*30)+28 = 238
	var gain := FestivalSystem.get_honor_gain_festivals(238)
	assert_eq(gain, 0.1)


func test_honor_gain_no_festival():
	var gain := FestivalSystem.get_honor_gain_festivals(31)
	assert_eq(gain, 0.0)


func test_lion_honor_effect_present_on_akodo_festival():
	# Festival of Akodo: month 1, day 20 → IC day 20
	var effects := FestivalSystem.get_festival_effects(20)
	assert_true("lion_honor" in effects)


func test_lion_honor_not_counted_as_generic_honor_gain():
	# lion_honor is clan-gated; get_honor_gain_festivals must not count it
	var gain := FestivalSystem.get_honor_gain_festivals(20)
	assert_eq(gain, 0.0)


func test_glory_gain_ning_panchiman():
	# Ning Panchiman: month 4, day 15 → IC day (3*30)+15 = 105
	var gain := FestivalSystem.get_glory_gain_festivals(105)
	assert_eq(gain, 0.1)


func test_glory_gain_poetry_exchange():
	# Festival of Leaves: month 1, day 10 → IC day 10
	var gain := FestivalSystem.get_glory_gain_festivals(10)
	assert_eq(gain, 0.1)


func test_glory_gain_no_festival():
	var gain := FestivalSystem.get_glory_gain_festivals(31)
	assert_eq(gain, 0.0)


# -- Championship tests -------------------------------------------------------

func test_championship_stages_exist():
	for ct in [
		FestivalSystem.ChampionshipType.EMERALD,
		FestivalSystem.ChampionshipType.JADE,
		FestivalSystem.ChampionshipType.AMETHYST,
		FestivalSystem.ChampionshipType.RUBY,
		FestivalSystem.ChampionshipType.TURQUOISE,
		FestivalSystem.ChampionshipType.TOPAZ,
	]:
		assert_true(FestivalSystem.CHAMPIONSHIP_STAGES.has(ct))


func test_topaz_is_annual():
	assert_true(FestivalSystem.ChampionshipType.TOPAZ in FestivalSystem.ANNUAL_CHAMPIONSHIPS)


func test_emerald_is_vacancy_triggered():
	assert_true(FestivalSystem.is_vacancy_triggered(FestivalSystem.ChampionshipType.EMERALD))


func test_topaz_is_not_vacancy_triggered():
	assert_false(FestivalSystem.is_vacancy_triggered(FestivalSystem.ChampionshipType.TOPAZ))


func _make_candidate(id: int, skills: Dictionary, traits: Dictionary, honor: float = 3.0) -> Dictionary:
	return {
		"character_id": id,
		"championship": FestivalSystem.ChampionshipType.TOPAZ,
		"skill_ranks": skills,
		"traits": traits,
		"honor": honor,
	}


func test_resolve_championship_empty():
	var result := FestivalSystem.resolve_championship([] as Array[Dictionary], null)
	assert_true(result.is_empty())


func test_resolve_championship_single_candidate():
	var candidates: Array[Dictionary] = [
		_make_candidate(1, {"Athletics": 3, "Kenjutsu": 3, "Etiquette": 2},
			{"strength": 3, "agility": 3, "intelligence": 3}),
	]
	var result := FestivalSystem.resolve_championship(candidates, null)
	assert_eq(result["winner_id"], 1)
	assert_true(result["winning_score"] > 0)


func test_resolve_championship_higher_skill_wins():
	var candidates: Array[Dictionary] = [
		_make_candidate(1, {"Athletics": 5, "Kenjutsu": 5, "Etiquette": 5},
			{"strength": 4, "agility": 4, "intelligence": 4}),
		_make_candidate(2, {"Athletics": 1, "Kenjutsu": 1, "Etiquette": 1},
			{"strength": 2, "agility": 2, "intelligence": 2}),
	]
	var result := FestivalSystem.resolve_championship(candidates, null)
	assert_eq(result["winner_id"], 1)


func test_resolve_championship_honor_tiebreak():
	var candidates: Array[Dictionary] = [
		_make_candidate(1, {"Athletics": 3, "Kenjutsu": 3, "Etiquette": 3},
			{"strength": 3, "agility": 3, "intelligence": 3}, 5.0),
		_make_candidate(2, {"Athletics": 3, "Kenjutsu": 3, "Etiquette": 3},
			{"strength": 3, "agility": 3, "intelligence": 3}, 7.0),
	]
	var result := FestivalSystem.resolve_championship(candidates, null)
	assert_eq(result["winner_id"], 2)


func test_resolve_championship_returns_topic_tier_4():
	var candidates: Array[Dictionary] = [
		_make_candidate(1, {"Athletics": 3}, {"strength": 3, "agility": 3, "intelligence": 3}),
	]
	var result := FestivalSystem.resolve_championship(candidates, null)
	assert_eq(result["topic_tier"], 4)


# -- Emperor's Chosen tests ---------------------------------------------------

func test_chosen_positions_count():
	assert_eq(FestivalSystem.CHOSEN_POSITIONS.size(), 4)


func test_chosen_evaluation_weights_sum():
	var total: int = 0
	for key in FestivalSystem.CHOSEN_EVALUATION_WEIGHTS:
		total += FestivalSystem.CHOSEN_EVALUATION_WEIGHTS[key]
	assert_eq(total, 75)


func test_evaluate_chosen_candidate():
	var score := FestivalSystem.evaluate_chosen_candidate(50, 50, 50, 5.0, 5.0, 50)
	assert_true(score > 0.0)


func test_evaluate_chosen_candidate_zero():
	var score := FestivalSystem.evaluate_chosen_candidate(0, 0, 0, 0.0, 0.0, 0)
	assert_eq(score, 0.0)


# -- Local festival generation tests ------------------------------------------

class MockRNG:
	var _value: int = 0
	func randi_range(from: int, to: int) -> int:
		return clampi(_value, from, to)


func test_generate_local_village():
	var rng := MockRNG.new()
	rng._value = 1
	var fests := FestivalSystem.generate_local_festivals("village", "plains", "Crane", rng)
	assert_true(fests.size() >= 1 and fests.size() <= 2)


func test_generate_local_town():
	var rng := MockRNG.new()
	rng._value = 2
	var fests := FestivalSystem.generate_local_festivals("town", "coast", "Mantis", rng)
	assert_true(fests.size() >= 2 and fests.size() <= 3)


func test_generate_local_fortification():
	var rng := MockRNG.new()
	rng._value = 0
	var fests := FestivalSystem.generate_local_festivals("fortification", "mountain", "Dragon", rng)
	assert_true(fests.size() >= 0 and fests.size() <= 1)


func test_local_festival_has_required_fields():
	var rng := MockRNG.new()
	rng._value = 5
	var fests := FestivalSystem.generate_local_festivals("village", "plains", "Lion", rng)
	if fests.size() > 0:
		var f: Dictionary = fests[0]
		assert_true(f.has("name"))
		assert_true(f.has("day_of_year"))
		assert_true(f.has("theme_category"))
		assert_true(f.has("mechanical_effect"))
		assert_false(f["mechanical_effect"])


func test_local_festival_custom_themes():
	var rng := MockRNG.new()
	rng._value = 5
	var themes: Array[String] = ["maritime", "spiritual"]
	var fests := FestivalSystem.generate_local_festivals("town", "coast", "Mantis", rng, themes)
	if fests.size() >= 2:
		assert_eq(fests[0]["theme_category"], "maritime")
		assert_eq(fests[1]["theme_category"], "spiritual")


func test_local_festival_no_duplicate_days():
	var rng := MockRNG.new()
	rng._value = 50
	var fests := FestivalSystem.generate_local_festivals("castle_town", "plains", "Lion", rng)
	var days: Array[int] = []
	for f in fests:
		assert_false(f["day_of_year"] in days)
		days.append(f["day_of_year"])


func test_settlement_festival_count_keys():
	assert_true(FestivalSystem.SETTLEMENT_FESTIVAL_COUNT.has("village"))
	assert_true(FestivalSystem.SETTLEMENT_FESTIVAL_COUNT.has("town"))
	assert_true(FestivalSystem.SETTLEMENT_FESTIVAL_COUNT.has("castle_town"))
	assert_true(FestivalSystem.SETTLEMENT_FESTIVAL_COUNT.has("fortification"))
	assert_true(FestivalSystem.SETTLEMENT_FESTIVAL_COUNT.has("temple"))


func test_theme_words_all_categories_present():
	for cat in FestivalSystem.THEME_CATEGORIES:
		assert_true(FestivalSystem.THEME_WORDS.has(cat), "Missing theme words for: %s" % cat)


func test_theme_words_25_per_category():
	for cat in FestivalSystem.THEME_CATEGORIES:
		var words: Array = FestivalSystem.THEME_WORDS.get(cat, [])
		assert_eq(words.size(), 25, "Expected 25 themes for %s, got %d" % [cat, words.size()])


func test_theme_words_total_300():
	var total: int = 0
	for cat in FestivalSystem.THEME_WORDS:
		total += FestivalSystem.THEME_WORDS[cat].size()
	assert_eq(total, 300)


func test_local_festival_uses_theme_words():
	var rng := MockRNG.new()
	rng._value = 3
	var fests := FestivalSystem.generate_local_festivals("village", "plains", "Lion", rng)
	if fests.size() > 0:
		var name: String = fests[0]["name"]
		var cat: String = fests[0]["theme_category"]
		var words: Array = FestivalSystem.THEME_WORDS.get(cat, [])
		var found: bool = false
		for w in words:
			if w in name:
				found = true
				break
		assert_true(found, "Festival name '%s' should contain a theme word from '%s'" % [name, cat])


func test_local_festival_avoids_canonical_days():
	var rng := MockRNG.new()
	rng._value = 50
	var canonical_days: Array[int] = FestivalSystem._get_canonical_days()
	var fests := FestivalSystem.generate_local_festivals("town", "plains", "Crane", rng)
	for f in fests:
		assert_false(f["day_of_year"] in canonical_days,
			"Local festival on day %d collides with canonical festival" % f["day_of_year"])


func test_canonical_days_cache_populated():
	var days: Array[int] = FestivalSystem._get_canonical_days()
	assert_true(days.size() > 0)
	assert_true(days.size() <= FestivalSystem.CANONICAL_FESTIVALS.size())
