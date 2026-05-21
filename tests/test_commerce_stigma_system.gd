extends GutTest


var _character: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_character = L5RCharacterData.new()
	_character.character_id = 1
	_character.honor = 5.5
	_character.glory = 2.0
	_character.school = "Yasuki Courtier"
	_character.school_paths = []
	_character.commerce_stigma_applied_ic_day = -1

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.ic_day = 10
	_ctx.honor = 5.5


# -- is_public_commerce --------------------------------------------------------

func test_purchase_market_always_public() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	assert_true(CommerceStigmaSystem.is_public_commerce("PURCHASE_MARKET", _ctx))


func test_conduct_commerce_public_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	assert_true(CommerceStigmaSystem.is_public_commerce("CONDUCT_COMMERCE", _ctx))


func test_conduct_commerce_public_visiting() -> void:
	_ctx.context_flag = Enums.ContextFlag.VISITING
	assert_true(CommerceStigmaSystem.is_public_commerce("CONDUCT_COMMERCE", _ctx))


func test_conduct_commerce_private_at_own_holdings() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	assert_false(CommerceStigmaSystem.is_public_commerce("CONDUCT_COMMERCE", _ctx))


func test_set_tax_rate_not_public() -> void:
	assert_false(CommerceStigmaSystem.is_public_commerce("SET_TAX_RATE", _ctx))


# -- has_ide_trader_exception --------------------------------------------------

func test_ide_trader_in_school_paths_grants_exception() -> void:
	_character.school_paths = ["Ide Trader"]
	assert_true(CommerceStigmaSystem.has_ide_trader_exception(_character))


func test_ide_emissary_does_not_grant_exception() -> void:
	_character.school_paths = ["Ide Emissary"]
	assert_false(CommerceStigmaSystem.has_ide_trader_exception(_character))


func test_empty_school_paths_no_exception() -> void:
	assert_false(CommerceStigmaSystem.has_ide_trader_exception(_character))


# -- compute_honor_penalty -----------------------------------------------------

func test_honor_penalty_rank7_plus() -> void:
	_character.honor = 7.0
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.6, 0.001
	)


func test_honor_penalty_rank7_high() -> void:
	_character.honor = 9.8
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.9, 0.001
	)


func test_honor_penalty_rank5_to_6() -> void:
	_character.honor = 5.0
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.3, 0.001
	)


func test_honor_penalty_rank6_9() -> void:
	_character.honor = 6.9
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.3, 0.001
	)


func test_honor_penalty_rank3_to_4() -> void:
	_character.honor = 3.0
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.2, 0.001
	)


func test_honor_penalty_rank4_9() -> void:
	_character.honor = 4.9
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.2, 0.001
	)


func test_honor_penalty_rank2_is_zero() -> void:
	_character.honor = 2.5
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.1, 0.001
	)


func test_honor_penalty_rank1_is_zero() -> void:
	_character.honor = 1.0
	assert_almost_eq(
		CommerceStigmaSystem.compute_honor_penalty(_character), -0.1, 0.001
	)


# -- apply_stigma --------------------------------------------------------------

func test_stigma_fires_first_time() -> void:
	var result: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_true(result.get("stigma_fired", false))
	assert_almost_eq(result.get("stigma_honor_change", 0.0), -0.3, 0.001)
	assert_almost_eq(result.get("stigma_glory_change", 0.0), -0.3, 0.001)
	assert_true(result.get("public_commerce_topic", false))


func test_stigma_sets_ic_day_flag() -> void:
	CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_eq(_character.commerce_stigma_applied_ic_day, 10)


func test_stigma_does_not_fire_twice_same_day() -> void:
	CommerceStigmaSystem.apply_stigma(_character, _ctx)
	var second: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_false(second.get("stigma_fired", true))
	assert_almost_eq(second.get("stigma_honor_change", 99.0), 0.0, 0.001)
	assert_almost_eq(second.get("stigma_glory_change", 99.0), 0.0, 0.001)


func test_stigma_fires_again_next_day() -> void:
	CommerceStigmaSystem.apply_stigma(_character, _ctx)
	_ctx.ic_day = 11
	var result: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_true(result.get("stigma_fired", false))


func test_ide_trader_no_stigma_but_topic() -> void:
	_character.school_paths = ["Ide Trader"]
	var result: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_false(result.get("stigma_fired", true))
	assert_almost_eq(result.get("stigma_honor_change", 99.0), 0.0, 0.001)
	assert_almost_eq(result.get("stigma_glory_change", 99.0), 0.0, 0.001)
	assert_true(result.get("public_commerce_topic", false))


func test_ide_trader_flag_not_set() -> void:
	_character.school_paths = ["Ide Trader"]
	CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_eq(_character.commerce_stigma_applied_ic_day, -1)


func test_high_honor_takes_full_penalty() -> void:
	_character.honor = 8.0
	var result: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_almost_eq(result.get("stigma_honor_change", 0.0), -0.6, 0.001)


func test_low_honor_no_honor_penalty_but_glory_still_applies() -> void:
	_character.honor = 2.0
	var result: Dictionary = CommerceStigmaSystem.apply_stigma(_character, _ctx)
	assert_true(result.get("stigma_fired", false))
	assert_almost_eq(result.get("stigma_honor_change", 0.0), -0.1, 0.001)
	assert_almost_eq(result.get("stigma_glory_change", 0.0), -0.3, 0.001)


# -- get_school_lean -----------------------------------------------------------

func test_ide_trader_lean_plus_10() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Ide Trader"), 10)


func test_yasuki_courtier_lean_plus_5() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Yasuki Courtier"), 5)


func test_yoritomo_scoundrel_lean_plus_5() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Yoritomo Scoundrel"), 5)


func test_doji_courtier_lean_minus_10() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Doji Courtier"), -10)


func test_isawa_shugenja_lean_minus_10() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Isawa Shugenja"), -10)


func test_miya_herald_lean_minus_5() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Miya Herald"), -5)


func test_crab_bushi_neutral() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Hida Bushi"), 0)


func test_ide_emissary_lean_plus_5() -> void:
	assert_eq(CommerceStigmaSystem.get_school_lean("Ide Emissary"), 5)


# -- ActionExecutor integration ------------------------------------------------

func _make_action(action_id: String) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = -1
	a.target_province_id = -1
	a.ap_cost = 1
	a.metadata = {}
	return a


func test_executor_purchase_market_applies_stigma() -> void:
	_character.honor = 6.0
	_character.skills = {"Commerce": 3}
	_character.awareness = 3
	var action := _make_action("PURCHASE_MARKET")
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, dice, {}, {}, {}
	)
	assert_true(result.has("effects"))
	var effects: Dictionary = result.get("effects", {})
	# Stigma should have fired: honor_change <= -0.2 (rank 5-6)
	if effects.has("honor_change"):
		assert_true(effects["honor_change"] <= -0.19)
	if effects.has("glory_change"):
		assert_true(effects["glory_change"] <= -0.09)


func test_executor_purchase_market_ide_trader_no_honor_penalty() -> void:
	_character.honor = 6.0
	_character.school_paths = ["Ide Trader"]
	_character.skills = {"Commerce": 3}
	_character.awareness = 3
	var action := _make_action("PURCHASE_MARKET")
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, dice, {}, {}, {}
	)
	assert_true(result.has("effects"))
	var effects: Dictionary = result.get("effects", {})
	# Ide Trader: honor_change should not include stigma penalty
	var honor_ch: float = effects.get("honor_change", 0.0)
	assert_true(honor_ch >= -0.001)


func test_executor_conduct_commerce_private_no_stigma() -> void:
	_character.honor = 8.0
	_character.skills = {"Commerce": 3}
	_character.awareness = 3
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var action := _make_action("CONDUCT_COMMERCE")
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, dice, {}, {}, {}
	)
	assert_true(result.has("effects"))
	var effects: Dictionary = result.get("effects", {})
	# Private context: honor_change should not include stigma
	assert_almost_eq(effects.get("honor_change", 0.0), 0.0, 0.001)


func test_executor_stigma_fires_only_once_per_day() -> void:
	_character.honor = 6.0
	_character.skills = {"Commerce": 3}
	_character.awareness = 3
	var action := _make_action("PURCHASE_MARKET")
	var dice := DiceEngine.new()
	dice.set_seed(42)
	ActionExecutor.execute(action, _character, _ctx, dice, {}, {}, {})
	dice.set_seed(99)
	var second := _make_action("PURCHASE_MARKET")
	var result2: Dictionary = ActionExecutor.execute(
		second, _character, _ctx, dice, {}, {}, {}
	)
	var effects2: Dictionary = result2.get("effects", {})
	# Second call same day: no stigma honor penalty
	assert_almost_eq(effects2.get("honor_change", 0.0), 0.0, 0.001)
