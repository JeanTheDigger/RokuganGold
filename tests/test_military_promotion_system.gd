extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_candidate(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"character_id": 1,
		"battle_skill": 3,
		"insight_rank": 2,
		"school_rank": 2,
		"glory": 3.0,
		"disposition": 10,
		"personality_virtue": "Yu",
		"battles_commanded": 0,
		"battles_as_chui": 0,
		"battles_as_taisa": 0,
		"is_garrison": false,
	}
	base.merge(overrides, true)
	return base


# -- Battle Record Tests ---------------------------------------------------------

func test_create_battle_record() -> void:
	var r: Dictionary = MilitaryPromotionSystem.create_battle_record()
	assert_eq(r["battles_fought"], 0)
	assert_eq(r["battles_won"], 0)
	assert_eq(r["battles_lost"], 0)
	assert_eq(r["companies_destroyed_under_command"], 0)


func test_record_battle_win() -> void:
	var r: Dictionary = MilitaryPromotionSystem.create_battle_record()
	MilitaryPromotionSystem.record_battle(r, true)
	assert_eq(r["battles_fought"], 1)
	assert_eq(r["battles_won"], 1)
	assert_eq(r["battles_lost"], 0)


func test_record_battle_loss() -> void:
	var r: Dictionary = MilitaryPromotionSystem.create_battle_record()
	MilitaryPromotionSystem.record_battle(r, false, 2)
	assert_eq(r["battles_fought"], 1)
	assert_eq(r["battles_lost"], 1)
	assert_eq(r["companies_destroyed_under_command"], 2)


func test_record_multiple_battles() -> void:
	var r: Dictionary = MilitaryPromotionSystem.create_battle_record()
	MilitaryPromotionSystem.record_battle(r, true)
	MilitaryPromotionSystem.record_battle(r, true)
	MilitaryPromotionSystem.record_battle(r, false, 1)
	assert_eq(r["battles_fought"], 3)
	assert_eq(r["battles_won"], 2)
	assert_eq(r["companies_destroyed_under_command"], 1)


# -- Enlisted Promotion Tests ----------------------------------------------------

func test_can_promote_to_nikutai() -> void:
	assert_true(MilitaryPromotionSystem.can_promote_to_nikutai(2, 1))


func test_cannot_promote_to_nikutai_low_skill() -> void:
	assert_false(MilitaryPromotionSystem.can_promote_to_nikutai(1, 1))


func test_cannot_promote_to_nikutai_no_battles() -> void:
	assert_false(MilitaryPromotionSystem.can_promote_to_nikutai(2, 0))


func test_can_promote_to_gunso() -> void:
	assert_true(MilitaryPromotionSystem.can_promote_to_gunso(2, 1, true))


func test_cannot_promote_to_gunso_no_vacancy() -> void:
	assert_false(MilitaryPromotionSystem.can_promote_to_gunso(2, 1, false))


# -- Officer Eligibility Tests ---------------------------------------------------

func test_eligible_for_chui() -> void:
	assert_true(MilitaryPromotionSystem.is_eligible_for_chui(3))


func test_not_eligible_for_chui_low_battle() -> void:
	assert_false(MilitaryPromotionSystem.is_eligible_for_chui(2))


func test_eligible_for_taisa() -> void:
	assert_true(MilitaryPromotionSystem.is_eligible_for_taisa(4, 1))


func test_not_eligible_for_taisa_low_battle() -> void:
	assert_false(MilitaryPromotionSystem.is_eligible_for_taisa(3, 1))


func test_not_eligible_for_taisa_no_chui_battles() -> void:
	assert_false(MilitaryPromotionSystem.is_eligible_for_taisa(4, 0))


func test_eligible_for_shireikan() -> void:
	assert_true(MilitaryPromotionSystem.is_eligible_for_shireikan(5, 2))


func test_not_eligible_for_shireikan_low_taisa_battles() -> void:
	assert_false(MilitaryPromotionSystem.is_eligible_for_shireikan(5, 1))


func test_eligible_for_rikugunshokan() -> void:
	assert_true(MilitaryPromotionSystem.is_eligible_for_rikugunshokan(5))


func test_not_eligible_for_rikugunshokan() -> void:
	assert_false(MilitaryPromotionSystem.is_eligible_for_rikugunshokan(4))


# -- Chui Scoring Tests ----------------------------------------------------------

func test_chui_score_basic() -> void:
	var score: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, 10, "Yu",
	)
	# 3*30 + 2*20 + 2*15 + 3.0*10 + 10*0.5 + 10*10
	# = 90 + 40 + 30 + 30 + 5 + 100 = 295
	assert_almost_eq(score, 295.0, 0.1)


func test_chui_score_garrison_personality() -> void:
	var standard: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, 10, "Seigyo", false,
	)
	var garrison: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, 10, "Seigyo", true,
	)
	# Seigyo garrison = 10, Seigyo frontline = 4
	assert_true(garrison > standard)


func test_chui_score_higher_battle_wins() -> void:
	var low: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, 10, "",
	)
	var high: float = MilitaryPromotionSystem.score_chui_candidate(
		5, 2, 2, 3.0, 10, "",
	)
	assert_true(high > low)


func test_chui_score_disposition_matters() -> void:
	var low_disp: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, -20, "Yu",
	)
	var high_disp: float = MilitaryPromotionSystem.score_chui_candidate(
		3, 2, 2, 3.0, 40, "Yu",
	)
	assert_true(high_disp > low_disp)


# -- Taisa Scoring Tests ---------------------------------------------------------

func test_taisa_score_basic() -> void:
	var score: float = MilitaryPromotionSystem.score_taisa_candidate(
		4, 3, 2, 4.0, 15, "Chugi",
	)
	# 4*35 + 3*20 + 2*15 + 4.0*10 + 15*0.5 + 8*10
	# = 140 + 60 + 30 + 40 + 7.5 + 80 = 357.5
	assert_almost_eq(score, 357.5, 0.1)


func test_taisa_battles_commanded_matters() -> void:
	var no_battles: float = MilitaryPromotionSystem.score_taisa_candidate(
		4, 3, 0, 4.0, 15, "Yu",
	)
	var experienced: float = MilitaryPromotionSystem.score_taisa_candidate(
		4, 3, 5, 4.0, 15, "Yu",
	)
	assert_true(experienced > no_battles)


# -- Shireikan Scoring Tests -----------------------------------------------------

func test_shireikan_score_dosatsu_top() -> void:
	var dosatsu: float = MilitaryPromotionSystem.score_shireikan_candidate(
		5, 3, 3, 5.0, 20, "Dosatsu",
	)
	var yu: float = MilitaryPromotionSystem.score_shireikan_candidate(
		5, 3, 3, 5.0, 20, "Yu",
	)
	assert_true(dosatsu > yu)


# -- Rikugunshokan Scoring Tests -------------------------------------------------

func test_rikugunshokan_disposition_weighted_heavily() -> void:
	var low_disp: float = MilitaryPromotionSystem.score_rikugunshokan_candidate(
		5, 3, 3, 5.0, -10, "Dosatsu",
	)
	var high_disp: float = MilitaryPromotionSystem.score_rikugunshokan_candidate(
		5, 3, 3, 5.0, 40, "Dosatsu",
	)
	# Disposition weight is 20 (highest among all ranks)
	assert_true(high_disp - low_disp > 20.0)


func test_rikugunshokan_no_battle_count_required() -> void:
	# Political appointment: no minimum battle count
	assert_true(MilitaryPromotionSystem.is_eligible_for_rikugunshokan(5))


# -- Select Best Candidate Tests -------------------------------------------------

func test_select_best_chui() -> void:
	var candidates: Array = [
		_make_candidate({"character_id": 1, "battle_skill": 3, "glory": 2.0}),
		_make_candidate({"character_id": 2, "battle_skill": 5, "glory": 5.0}),
	]
	var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
		candidates, Enums.MilitaryRank.CHUI,
	)
	assert_eq(best["character_id"], 2)


func test_select_best_chui_filters_ineligible() -> void:
	var candidates: Array = [
		_make_candidate({"character_id": 1, "battle_skill": 2}),
		_make_candidate({"character_id": 2, "battle_skill": 3}),
	]
	var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
		candidates, Enums.MilitaryRank.CHUI,
	)
	assert_eq(best["character_id"], 2)


func test_select_best_chui_all_ineligible() -> void:
	var candidates: Array = [
		_make_candidate({"character_id": 1, "battle_skill": 1}),
		_make_candidate({"character_id": 2, "battle_skill": 2}),
	]
	var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
		candidates, Enums.MilitaryRank.CHUI,
	)
	assert_true(best.is_empty())


func test_select_best_taisa() -> void:
	var candidates: Array = [
		_make_candidate({
			"character_id": 1, "battle_skill": 4, "battles_as_chui": 1,
			"battles_commanded": 3, "glory": 5.0,
		}),
		_make_candidate({
			"character_id": 2, "battle_skill": 5, "battles_as_chui": 2,
			"battles_commanded": 5, "glory": 6.0,
		}),
	]
	var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
		candidates, Enums.MilitaryRank.TAISA,
	)
	assert_eq(best["character_id"], 2)


func test_select_best_empty() -> void:
	var candidates: Array = []
	var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
		candidates, Enums.MilitaryRank.CHUI,
	)
	assert_true(best.is_empty())


# -- Demotion Tests --------------------------------------------------------------

func test_should_remove_for_disposition() -> void:
	assert_true(MilitaryPromotionSystem.should_remove_for_disposition(-11))


func test_should_not_remove_above_threshold() -> void:
	assert_false(MilitaryPromotionSystem.should_remove_for_disposition(-10))


func test_apply_demotion() -> void:
	var char_data: Dictionary = {
		"military_rank": Enums.MilitaryRank.TAISA,
		"commanded_unit_id": 5,
	}
	var r: Dictionary = MilitaryPromotionSystem.apply_demotion(char_data)
	assert_eq(char_data["military_rank"], Enums.MilitaryRank.NONE)
	assert_eq(char_data["commanded_unit_id"], -1)
	assert_almost_eq(r["glory_loss"], 0.5, 0.01)
	assert_eq(r["old_rank"], Enums.MilitaryRank.TAISA)


# -- Vacancy Detection Tests -----------------------------------------------------

func test_find_vacancies() -> void:
	var units: Array = [
		{"unit_id": 1, "commander_id": 5, "rank_needed": Enums.MilitaryRank.CHUI},
		{"unit_id": 2, "commander_id": -1, "rank_needed": Enums.MilitaryRank.CHUI},
		{"unit_id": 3, "commander_id": -1, "rank_needed": Enums.MilitaryRank.TAISA},
	]
	var vacancies: Array = MilitaryPromotionSystem.find_vacancies(units)
	assert_eq(vacancies.size(), 2)
	assert_eq(vacancies[0]["unit_id"], 2)
	assert_eq(vacancies[1]["rank_needed"], Enums.MilitaryRank.TAISA)


func test_find_no_vacancies() -> void:
	var units: Array = [
		{"unit_id": 1, "commander_id": 5, "rank_needed": Enums.MilitaryRank.CHUI},
	]
	var vacancies: Array = MilitaryPromotionSystem.find_vacancies(units)
	assert_eq(vacancies.size(), 0)
