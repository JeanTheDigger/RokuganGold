extends GutTest


func _make_province(
	id: int,
	stability: float = 100.0,
	garrison: int = 5,
	crisis_id: int = -1,
	insurgency_id: int = -1,
	confidence: int = NPCDataStructures.ProvinceStatus.CONFIDENCE_FRESH,
) -> NPCDataStructures.ProvinceStatus:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = id
	ps.stability = stability
	ps.garrison_pu = garrison
	ps.active_crisis_id = crisis_id
	ps.active_insurgency_id = insurgency_id
	ps.confidence = confidence
	return ps


# -- Scoring -------------------------------------------------------------------

func test_score_stable_province_is_zero() -> void:
	var ps := _make_province(1, 100.0, 5, -1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 0.0)


func test_score_active_crisis() -> void:
	var ps := _make_province(1, 100.0, 5, 1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 100.0)


func test_score_active_insurgency() -> void:
	var ps := _make_province(1, 100.0, 5, -1, 1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 80.0)


func test_score_broken_stability() -> void:
	var ps := _make_province(1, 20.0, 5, -1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 60.0)


func test_score_volatile_stability() -> void:
	var ps := _make_province(1, 40.0, 5, -1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 30.0)


func test_score_restless_stability() -> void:
	var ps := _make_province(1, 70.0, 5, -1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 10.0)


func test_score_garrison_deficit() -> void:
	var ps := _make_province(1, 100.0, 0, -1, -1, 2)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 20.0)


func test_score_stale_information() -> void:
	var ps := _make_province(1, 100.0, 5, -1, -1, 0)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 25.0)


func test_score_multiple_factors_additive() -> void:
	var ps := _make_province(1, 20.0, 0, 1, 1, 0)
	var score: float = ProvinceTriage.score_province(ps)
	# crisis(100) + insurgency(80) + broken(60) + garrison(20) + stale(25)
	assert_eq(score, 285.0)


func test_score_volatile_not_broken() -> void:
	var ps := _make_province(1, 50.0)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 30.0)


func test_score_exactly_25_is_broken() -> void:
	var ps := _make_province(1, 25.0)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 60.0)


func test_score_exactly_75_is_restless() -> void:
	var ps := _make_province(1, 75.0)
	var score: float = ProvinceTriage.score_province(ps)
	assert_eq(score, 10.0)


# -- Triage Ordering -----------------------------------------------------------

func test_triage_returns_sorted_by_score_descending() -> void:
	var provinces: Array = [
		_make_province(1, 80.0),  # restless = 10
		_make_province(2, 20.0),  # broken = 60
		_make_province(3, 40.0),  # volatile = 30
	]

	var results: Array = ProvinceTriage.triage_provinces(provinces)

	assert_eq(results.size(), 3)
	assert_eq(results[0].province_id, 2)
	assert_eq(results[1].province_id, 3)
	assert_eq(results[2].province_id, 1)


func test_triage_empty_array() -> void:
	var results: Array = ProvinceTriage.triage_provinces([])
	assert_eq(results.size(), 0)


func test_get_worst_province_returns_highest_score() -> void:
	var provinces: Array = [
		_make_province(1, 80.0),
		_make_province(2, 100.0, 5, 1),  # crisis = 100
		_make_province(3, 20.0),         # broken = 60
	]

	var worst: ProvinceTriage.TriageResult = ProvinceTriage.get_worst_province(provinces)
	assert_eq(worst.province_id, 2)
	assert_eq(worst.score, 100.0)


func test_get_worst_province_empty_returns_default() -> void:
	var worst: ProvinceTriage.TriageResult = ProvinceTriage.get_worst_province([])
	assert_eq(worst.province_id, -1)
	assert_eq(worst.score, 0.0)


func test_get_top_provinces_limits_count() -> void:
	var provinces: Array = [
		_make_province(1, 20.0),  # 60
		_make_province(2, 40.0),  # 30
		_make_province(3, 70.0),  # 10
	]

	var top: Array = ProvinceTriage.get_top_provinces(provinces, 2)
	assert_eq(top.size(), 2)
	assert_eq(top[0].province_id, 1)
	assert_eq(top[1].province_id, 2)


func test_get_top_provinces_excludes_zero_score() -> void:
	var provinces: Array = [
		_make_province(1, 20.0),   # 60
		_make_province(2, 100.0),  # 0
	]

	var top: Array = ProvinceTriage.get_top_provinces(provinces, 5)
	assert_eq(top.size(), 1)
	assert_eq(top[0].province_id, 1)


# -- Need Determination --------------------------------------------------------

func test_stale_info_recommends_investigate() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, -1, -1, 0)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].recommended_need, "INVESTIGATE_THREAT")


func test_crisis_recommends_defend() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, 1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].recommended_need, "DEFEND_PROVINCE")


func test_low_stability_recommends_patrol() -> void:
	var provinces: Array = [_make_province(1, 40.0, 5, -1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].recommended_need, "PATROL_PROVINCE")


func test_stable_recommends_rest() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, -1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].recommended_need, "REST")


func test_crisis_overrides_stale_for_need() -> void:
	# Known crisis always recommends DEFEND even if info is stale
	var provinces: Array = [_make_province(1, 80.0, 5, 1, -1, 0)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].recommended_need, "DEFEND_PROVINCE")


# -- Priority ------------------------------------------------------------------

func test_crisis_priority_3() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, 1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 3)


func test_insurgency_priority_3() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, -1, 1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 3)


func test_broken_stability_priority_3() -> void:
	var provinces: Array = [_make_province(1, 25.0, 5, -1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 3)


func test_stale_info_priority_2() -> void:
	var provinces: Array = [_make_province(1, 80.0, 5, -1, -1, 0)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 2)


func test_volatile_priority_2() -> void:
	var provinces: Array = [_make_province(1, 50.0, 5, -1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 2)


func test_restless_priority_1() -> void:
	var provinces: Array = [_make_province(1, 70.0, 5, -1, -1, 2)]
	var results: Array = ProvinceTriage.triage_provinces(provinces)
	assert_eq(results[0].priority, 1)


# -- Decomposer Integration ---------------------------------------------------

func test_decomposer_uses_triage_for_prosperity() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = true
	ctx.character_id = 1
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS

	var ps1 := _make_province(10, 80.0, 5, -1, -1, 2)  # restless, score 10
	var ps2 := _make_province(20, 30.0, 0, -1, -1, 0)  # volatile + garrison + stale = 75
	ctx.province_statuses = [ps1, ps2]

	var objective: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var result: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)

	assert_eq(result.target_province_id, 20)


func test_decomposer_triage_falls_through_to_adjust_tax() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = true
	ctx.character_id = 1
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.province_statuses = [_make_province(10, 100.0, 5, -1, -1, 2)]
	ctx.resource_stockpiles = {"rice": 100.0, "population_pu": 10.0}

	var objective: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var result: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)

	assert_eq(result.need_type, "ADJUST_TAX")
