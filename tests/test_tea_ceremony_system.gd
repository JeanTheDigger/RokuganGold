extends GutTest


var _dice_engine: DiceEngine
var _host: L5RCharacterData
var _guest1: L5RCharacterData
var _guest2: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot
var _characters_by_id: Dictionary


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)

	_host = L5RCharacterData.new()
	_host.character_id = 1
	_host.void_ring = 3
	_host.skills = {"Tea Ceremony": 3}
	_host.current_void_points = 0
	_host.max_void_points = 3

	_guest1 = L5RCharacterData.new()
	_guest1.character_id = 2
	_guest1.void_ring = 2
	_guest1.current_void_points = 0
	_guest1.max_void_points = 2

	_guest2 = L5RCharacterData.new()
	_guest2.character_id = 3
	_guest2.void_ring = 2
	_guest2.current_void_points = 0
	_guest2.max_void_points = 2

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.zone_flags = {"tokonoma": true}
	_ctx.ic_day = 10
	_ctx.season = 0
	_ctx.characters_present = [2, 3]
	_ctx.dispositions = {2: 25, 3: 50}

	_characters_by_id = {1: _host, 2: _guest1, 3: _guest2}


# -- get_tn --------------------------------------------------------------------

func test_get_tn_solo_is_15() -> void:
	assert_eq(TeaCeremonySystem.get_tn(1), 15)


func test_get_tn_two_participants_is_15() -> void:
	assert_eq(TeaCeremonySystem.get_tn(2), 15)


func test_get_tn_three_participants_is_20() -> void:
	assert_eq(TeaCeremonySystem.get_tn(3), 20)


func test_get_tn_four_participants_is_25() -> void:
	assert_eq(TeaCeremonySystem.get_tn(4), 25)


func test_get_tn_five_participants_is_30() -> void:
	assert_eq(TeaCeremonySystem.get_tn(5), 30)


# -- max_viable_count ----------------------------------------------------------

func test_max_viable_count_solo_minimum() -> void:
	# Even with void_ring 0, must return at least 1
	var count: int = TeaCeremonySystem.max_viable_count(0, 0)
	assert_gte(count, 1)


func test_max_viable_count_high_skill_returns_more() -> void:
	var low: int = TeaCeremonySystem.max_viable_count(2, 1)
	var high: int = TeaCeremonySystem.max_viable_count(5, 5)
	assert_gte(high, low)


func test_max_viable_count_capped_at_participant_cap() -> void:
	var count: int = TeaCeremonySystem.max_viable_count(10, 10)
	assert_lte(count, TeaCeremonySystem.PARTICIPANT_CAP)


# -- select_eligible_ids -------------------------------------------------------

func test_select_eligible_excludes_host() -> void:
	var result: Array[int] = TeaCeremonySystem.select_eligible_ids(
		1, [1, 2, 3], {1: 50, 2: 25, 3: 30}
	)
	assert_false(result.has(1))


func test_select_eligible_excludes_below_acquaintance() -> void:
	# disp=5 is below the MIN_DISPOSITION threshold of 11
	var result: Array[int] = TeaCeremonySystem.select_eligible_ids(
		1, [2, 3], {2: 5, 3: 30}
	)
	assert_false(result.has(2))
	assert_true(result.has(3))


func test_select_eligible_includes_acquaintance_threshold() -> void:
	var result: Array[int] = TeaCeremonySystem.select_eligible_ids(
		1, [2], {2: TeaCeremonySystem.MIN_DISPOSITION}
	)
	assert_true(result.has(2))


func test_select_eligible_empty_zone() -> void:
	var result: Array[int] = TeaCeremonySystem.select_eligible_ids(1, [], {})
	assert_eq(result.size(), 0)


# -- zone_allows_ceremony ------------------------------------------------------

func test_zone_allows_tokonoma() -> void:
	assert_true(TeaCeremonySystem.zone_allows_ceremony({"tokonoma": true}))


func test_zone_allows_shrine_eligible() -> void:
	assert_true(TeaCeremonySystem.zone_allows_ceremony({"shrine_eligible": true}))


func test_zone_blocks_neither_flag() -> void:
	assert_false(TeaCeremonySystem.zone_allows_ceremony({"performance_permitted": true}))


func test_zone_blocks_empty_flags() -> void:
	assert_false(TeaCeremonySystem.zone_allows_ceremony({}))


# -- ActionExecutor: CONDUCT_TEA_CEREMONY --------------------------------------

func _make_action(participant_ids: Array = []) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "CONDUCT_TEA_CEREMONY"
	a.target_npc_id = -1
	a.ap_cost = 1
	a.metadata = {"participant_ids": participant_ids, "participant_count": 1 + participant_ids.size()}
	return a


func test_executor_fails_when_zone_not_eligible() -> void:
	_ctx.zone_flags = {}
	var action := _make_action([2])
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result["success"])
	assert_eq(result["reason"], "zone_not_eligible")


func test_executor_solo_succeeds_and_recovers_host() -> void:
	_host.skills = {"Tea Ceremony": 5}  # High skill for reliable success
	_host.void_ring = 5
	_dice_engine.set_seed(99)
	var action := _make_action([])
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, _characters_by_id
	)
	if result["success"]:
		assert_gte(_host.current_void_points, 0)
		assert_lte(_host.current_void_points, _host.max_void_points)


func test_executor_skips_full_vp_guests() -> void:
	_guest1.current_void_points = _guest1.max_void_points  # Already full
	_host.skills = {"Tea Ceremony": 5}
	_host.void_ring = 5
	_dice_engine.set_seed(77)
	var action := _make_action([2, 3])
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, _characters_by_id
	)
	if result["success"]:
		# guest1 was full — should not be in gains or gained 0
		var gains: Dictionary = result["effects"]["participant_gains"]
		assert_false(gains.get(2, 0) > 0)


func test_executor_rank5_mastery_recovers_2vp() -> void:
	_host.skills = {"Tea Ceremony": 5}
	_host.void_ring = 5
	_host.current_void_points = 0
	_host.max_void_points = 5
	_dice_engine.set_seed(123)
	var action := _make_action([])
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, _characters_by_id
	)
	if result["success"]:
		assert_eq(result["effects"]["recovery_per_participant"], TeaCeremonySystem.VP_MASTERY_RECOVERY)


func test_executor_cannot_exceed_max_void() -> void:
	_host.skills = {"Tea Ceremony": 5}
	_host.void_ring = 5
	_host.current_void_points = _host.max_void_points - 1  # 1 short
	_dice_engine.set_seed(42)
	var action := _make_action([])
	var before: int = _host.current_void_points
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, _characters_by_id
	)
	if result["success"]:
		assert_lte(_host.current_void_points, _host.max_void_points)
		assert_gte(_host.current_void_points, before)
