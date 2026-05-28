extends GutTest
## Tests for MarriageSystem per GDD s22.7.


# -- Marriage creation tests --------------------------------------------------

func test_create_marriage():
	var m := MarriageSystem.create_marriage(1, 2, MarriageSystem.MarriageType.CROSS_CLAN, 2, 100)
	assert_eq(m["character_a_id"], 1)
	assert_eq(m["character_b_id"], 2)
	assert_eq(m["marriage_type"], MarriageSystem.MarriageType.CROSS_CLAN)
	assert_eq(m["moving_character_id"], 2)
	assert_true(m["active"])


# -- Boost tests --------------------------------------------------------------

func test_cross_clan_boosts():
	var boosts := MarriageSystem.get_marriage_boosts(MarriageSystem.MarriageType.CROSS_CLAN)
	assert_eq(boosts["clan_boost"], 8)
	assert_eq(boosts["family_boost"], 5)
	assert_true(boosts["favor_owed"])


func test_between_families_boosts():
	var boosts := MarriageSystem.get_marriage_boosts(MarriageSystem.MarriageType.BETWEEN_FAMILIES)
	assert_eq(boosts["clan_boost"], 0)
	assert_eq(boosts["family_boost"], 5)
	assert_false(boosts["favor_owed"])


func test_within_family_no_boosts():
	var boosts := MarriageSystem.get_marriage_boosts(MarriageSystem.MarriageType.WITHIN_FAMILY)
	assert_eq(boosts["clan_boost"], 0)
	assert_eq(boosts["family_boost"], 0)
	assert_false(boosts["favor_owed"])


func test_birth_family_floors():
	var floors := MarriageSystem.get_birth_family_floors()
	assert_eq(floors["birth_family_floor"], 15)
	assert_eq(floors["birth_clan_floor"], 8)


# -- Boost decay tests --------------------------------------------------------

func test_clan_boost_decay():
	assert_eq(MarriageSystem.decay_clan_boost(8, 0), 8)
	assert_eq(MarriageSystem.decay_clan_boost(8, 10), 7)
	assert_eq(MarriageSystem.decay_clan_boost(8, 80), 0)


func test_clan_boost_decay_capped_at_zero():
	assert_eq(MarriageSystem.decay_clan_boost(8, 200), 0)


func test_family_boost_decay():
	assert_eq(MarriageSystem.decay_family_boost(5, 0), 5)
	assert_eq(MarriageSystem.decay_family_boost(5, 8), 4)
	assert_eq(MarriageSystem.decay_family_boost(5, 40), 0)


func test_clan_boost_cap():
	assert_eq(MarriageSystem.CLAN_BOOST_CAP, 20)


func test_family_boost_cap():
	assert_eq(MarriageSystem.FAMILY_BOOST_CAP, 15)


# -- Pregnancy tests ----------------------------------------------------------

func test_pregnancy_chance_hostile():
	assert_eq(MarriageSystem.get_pregnancy_chance(-50), 0.0)


func test_pregnancy_chance_stranger():
	assert_eq(MarriageSystem.get_pregnancy_chance(0), 0.05)


func test_pregnancy_chance_friend():
	assert_eq(MarriageSystem.get_pregnancy_chance(45), 0.15)


func test_pregnancy_chance_close():
	assert_eq(MarriageSystem.get_pregnancy_chance(80), 0.25)


func test_pregnancy_check_success():
	assert_true(MarriageSystem.check_pregnancy(45, 0.10))


func test_pregnancy_check_failure():
	assert_false(MarriageSystem.check_pregnancy(45, 0.20))


# -- Gempuku tests ------------------------------------------------------------

func test_gempuku_eligible():
	assert_true(MarriageSystem.is_gempuku_eligible(0, 72))


func test_gempuku_not_eligible():
	assert_false(MarriageSystem.is_gempuku_eligible(0, 71))


# -- Proposal evaluation tests ------------------------------------------------

func test_evaluate_proposal_friendly():
	var score := MarriageSystem.evaluate_proposal(40, 10, 2, false)
	# 40 + 10 + 0 = 50 (favor_tier and military_objective zeroed)
	assert_eq(score, 50)


func test_evaluate_proposal_with_military_objective():
	var score := MarriageSystem.evaluate_proposal(30, 5, 1, true)
	# 30 + 5 + 0 + 0 = 35
	assert_eq(score, 35)


# -- Benten festival tests ----------------------------------------------------

func test_benten_festival_day():
	# Month 11, day 9 → day of year = (11-1)*30 + (9-1) = 308
	assert_true(MarriageSystem.is_benten_festival(308))


func test_not_benten_festival():
	assert_false(MarriageSystem.is_benten_festival(100))
