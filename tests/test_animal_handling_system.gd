extends GutTest


var _dice_engine: DiceEngine
var _trainer: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)

	_trainer = L5RCharacterData.new()
	_trainer.character_id = 1
	_trainer.awareness = 3
	_trainer.skills = {"Animal Handling": 3}
	_trainer.trained_companions = []

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.ic_day = 10
	_ctx.season = 0


# -- get_companion_cap ---------------------------------------------------------

func test_cap_rank_0_is_0() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(0), 0)


func test_cap_rank_1_is_1() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(1), 1)


func test_cap_rank_2_is_1() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(2), 1)


func test_cap_rank_3_is_2() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(3), 2)


func test_cap_rank_5_is_3() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(5), 3)


func test_cap_rank_7_is_4() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(7), 4)


func test_cap_rank_10_is_4() -> void:
	assert_eq(AnimalHandlingSystem.get_companion_cap(10), 4)


# -- count_active_companions / under_cap ---------------------------------------

func test_empty_companions_count_is_0() -> void:
	assert_eq(AnimalHandlingSystem.count_active_companions(_trainer), 0)


func test_under_cap_with_no_companions() -> void:
	assert_true(AnimalHandlingSystem.under_cap(_trainer))


func test_at_cap_with_one_companion_rank1() -> void:
	_trainer.trained_companions = [
		{"companion_id": 1, "is_alive": true, "fully_trained": false}
	]
	# rank 1 = cap 1; 1 companion means AT cap
	assert_false(AnimalHandlingSystem.under_cap(_trainer))


# -- training_tier -------------------------------------------------------------

func test_tier_wild_no_sessions() -> void:
	var comp: Dictionary = {"fully_trained": false, "sessions_completed": 0}
	assert_eq(AnimalHandlingSystem.training_tier(comp), "wild")


func test_tier_wild_two_sessions() -> void:
	var comp: Dictionary = {"fully_trained": false, "sessions_completed": 2}
	assert_eq(AnimalHandlingSystem.training_tier(comp), "wild")


func test_tier_following_three_sessions() -> void:
	var comp: Dictionary = {"fully_trained": false, "sessions_completed": 3}
	assert_eq(AnimalHandlingSystem.training_tier(comp), "following")


func test_tier_trained() -> void:
	var comp: Dictionary = {"fully_trained": true, "sessions_completed": 10}
	assert_eq(AnimalHandlingSystem.training_tier(comp), "trained")


# -- can_train_first_session ---------------------------------------------------

func test_first_session_valid() -> void:
	var result: Dictionary = AnimalHandlingSystem.can_train_first_session(
		_trainer, _ctx, "DOG"
	)
	assert_true(result.get("valid", false))


func test_first_session_fails_no_skill() -> void:
	_trainer.skills = {}
	var result: Dictionary = AnimalHandlingSystem.can_train_first_session(
		_trainer, _ctx, "DOG"
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "no_animal_handling_skill")


func test_first_session_fails_invalid_context() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var result: Dictionary = AnimalHandlingSystem.can_train_first_session(
		_trainer, _ctx, "DOG"
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "invalid_context")


func test_first_session_fails_at_cap() -> void:
	_trainer.skills = {"Animal Handling": 1}  # cap = 1
	_trainer.trained_companions = [
		{"companion_id": 1, "is_alive": true, "fully_trained": true}
	]
	var result: Dictionary = AnimalHandlingSystem.can_train_first_session(
		_trainer, _ctx, "DOG"
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "at_companion_cap")


func test_first_session_fails_invalid_species() -> void:
	var result: Dictionary = AnimalHandlingSystem.can_train_first_session(
		_trainer, _ctx, "DRAGON"
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "invalid_species")


# -- can_train_subsequent_session ----------------------------------------------

func _make_companion(companion_id: int, fully_trained: bool) -> Dictionary:
	return {
		"companion_id": companion_id,
		"name": "Kuro",
		"species": "DOG",
		"owner_id": 1,
		"wound_total": 0,
		"wound_threshold": 5,
		"training_progress": 5,
		"training_threshold": 20,
		"sessions_completed": 3,
		"fully_trained": fully_trained,
		"is_alive": true,
		"rebond_sessions_remaining": 0,
	}


func test_subsequent_session_valid() -> void:
	var comp: Dictionary = _make_companion(10, false)
	var result: Dictionary = AnimalHandlingSystem.can_train_subsequent_session(
		_trainer, _ctx, comp
	)
	assert_true(result.get("valid", false))


func test_subsequent_session_fails_already_trained() -> void:
	var comp: Dictionary = _make_companion(10, true)
	var result: Dictionary = AnimalHandlingSystem.can_train_subsequent_session(
		_trainer, _ctx, comp
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "already_fully_trained")


func test_subsequent_session_fails_dead_companion() -> void:
	var comp: Dictionary = _make_companion(10, false)
	comp["is_alive"] = false
	var result: Dictionary = AnimalHandlingSystem.can_train_subsequent_session(
		_trainer, _ctx, comp
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "companion_not_alive")


func test_subsequent_session_fails_not_owner() -> void:
	var comp: Dictionary = _make_companion(10, false)
	comp["owner_id"] = 999  # different owner
	var result: Dictionary = AnimalHandlingSystem.can_train_subsequent_session(
		_trainer, _ctx, comp
	)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "not_owner")


# -- make_training_roll --------------------------------------------------------

func test_training_roll_returns_required_keys() -> void:
	var result: Dictionary = AnimalHandlingSystem.make_training_roll(
		_trainer, "DOG", _dice_engine
	)
	assert_true(result.has("success"))
	assert_true(result.has("progress_gained"))
	assert_true(result.has("roll_total"))
	assert_true(result.has("tn"))


func test_training_roll_tn_matches_species() -> void:
	var dog_result: Dictionary = AnimalHandlingSystem.make_training_roll(
		_trainer, "DOG", _dice_engine
	)
	assert_eq(dog_result.get("tn", 0), 10)  # DOG TN = 10

	_dice_engine.set_seed(42)
	var warcat_result: Dictionary = AnimalHandlingSystem.make_training_roll(
		_trainer, "WARCAT", _dice_engine
	)
	assert_eq(warcat_result.get("tn", 0), 25)  # WARCAT TN = 25


func test_progress_zero_on_failure() -> void:
	# Force a failure: very low skill vs high TN
	_trainer.skills = {"Animal Handling": 1}
	_trainer.awareness = 1
	_dice_engine.set_seed(1)  # seed producing low rolls
	var result: Dictionary = AnimalHandlingSystem.make_training_roll(
		_trainer, "WARCAT", _dice_engine
	)
	if not result.get("success", false):
		assert_eq(result.get("progress_gained", -1), 0)


# -- create_companion ----------------------------------------------------------

func test_create_companion_fields() -> void:
	var comp: Dictionary = AnimalHandlingSystem.create_companion(
		1, "DOG", 42, "Kuro", 10, 5, 3
	)
	assert_eq(comp.get("companion_id", -1), 42)
	assert_eq(comp.get("name", ""), "Kuro")
	assert_eq(comp.get("species", ""), "DOG")
	assert_eq(comp.get("owner_id", -1), 1)
	assert_true(comp.get("is_alive", false))
	assert_eq(comp.get("training_progress", -1), 3)
	assert_eq(comp.get("wound_threshold", -1), 5)  # DOG wound_threshold = 5


func test_create_companion_fully_trained_if_progress_meets_threshold() -> void:
	# DOG threshold = 20; pass 20 progress → fully_trained
	var comp: Dictionary = AnimalHandlingSystem.create_companion(
		1, "DOG", 42, "Kuro", 10, 5, 20
	)
	assert_true(comp.get("fully_trained", false))


func test_create_companion_not_trained_if_below_threshold() -> void:
	var comp: Dictionary = AnimalHandlingSystem.create_companion(
		1, "DOG", 42, "Kuro", 10, 5, 10
	)
	assert_false(comp.get("fully_trained", true))


# -- apply_training_progress ---------------------------------------------------

func test_apply_progress_increments() -> void:
	var comp: Dictionary = _make_companion(1, false)
	comp["training_progress"] = 5
	AnimalHandlingSystem.apply_training_progress(comp, 8)
	assert_eq(comp.get("training_progress", 0), 13)


func test_apply_progress_completes_training() -> void:
	var comp: Dictionary = _make_companion(1, false)
	comp["training_progress"] = 18
	comp["training_threshold"] = 20
	AnimalHandlingSystem.apply_training_progress(comp, 5)
	assert_true(comp.get("fully_trained", false))


func test_apply_progress_noop_if_already_trained() -> void:
	var comp: Dictionary = _make_companion(1, true)
	comp["training_progress"] = 20
	AnimalHandlingSystem.apply_training_progress(comp, 10)
	assert_eq(comp.get("training_progress", -1), 20)  # should not change


# -- Mastery checks ------------------------------------------------------------

func test_can_command_at_rank5() -> void:
	assert_true(AnimalHandlingSystem.can_command_to_attack(5))


func test_cannot_command_at_rank4() -> void:
	assert_false(AnimalHandlingSystem.can_command_to_attack(4))


func test_no_flee_at_rank7() -> void:
	assert_true(AnimalHandlingSystem.has_no_flee_override(7))


func test_no_flee_at_rank6_is_false() -> void:
	assert_false(AnimalHandlingSystem.has_no_flee_override(6))


# -- School lean helpers -------------------------------------------------------

func test_positive_lean_matsu() -> void:
	assert_true(AnimalHandlingSystem.has_positive_school_lean("Matsu Beastmaster"))


func test_positive_lean_kitsune() -> void:
	assert_true(AnimalHandlingSystem.has_positive_school_lean("Kitsune Shugenja"))


func test_negative_lean_otomo() -> void:
	assert_true(AnimalHandlingSystem.has_negative_school_lean("Otomo Courtier"))


func test_no_lean_generic_courtier() -> void:
	assert_false(AnimalHandlingSystem.has_positive_school_lean("Bayushi Courtier"))
	assert_false(AnimalHandlingSystem.has_negative_school_lean("Bayushi Courtier"))


# -- ActionExecutor integration ------------------------------------------------

func _make_action(meta: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "TRAIN_ANIMAL"
	a.target_npc_id = -1
	a.target_province_id = 5
	a.ap_cost = 1
	a.metadata = meta
	return a


func test_executor_first_session_creates_companion() -> void:
	var action := _make_action({
		"is_first_session": true,
		"species": "DOG",
		"companion_name": "Kuro",
		"new_companion_id": 99,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, _trainer, _ctx, _dice_engine, {}, {}, {}
	)
	assert_true(result.get("success", false))
	assert_eq(result.get("action_id", ""), "TRAIN_ANIMAL")
	assert_true(_trainer.trained_companions.size() > 0)


func test_executor_subsequent_session_advances_progress() -> void:
	var comp: Dictionary = _make_companion(77, false)
	comp["training_progress"] = 5
	_trainer.trained_companions = [comp]
	var action := _make_action({
		"is_first_session": false,
		"companion_id": 77,
		"species": "DOG",
	})
	_dice_engine.set_seed(99)
	var result: Dictionary = ActionExecutor.execute(
		action, _trainer, _ctx, _dice_engine, {}, {}, {}
	)
	assert_true(result.get("success", false))


func test_executor_subsequent_fails_companion_not_found() -> void:
	var action := _make_action({
		"is_first_session": false,
		"companion_id": 999,
		"species": "DOG",
	})
	var result: Dictionary = ActionExecutor.execute(
		action, _trainer, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "companion_not_found")


func test_executor_fails_no_animal_handling_skill() -> void:
	_trainer.skills = {}
	var action := _make_action({
		"is_first_session": true,
		"species": "DOG",
		"companion_name": "Kuro",
	})
	var result: Dictionary = ActionExecutor.execute(
		action, _trainer, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_animal_handling_skill")
