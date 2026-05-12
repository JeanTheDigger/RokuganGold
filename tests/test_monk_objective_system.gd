extends GutTest
## Tests for MonkObjectiveSystem per GDD s55.11b.
## Covers: monk identification, combat monk detection, standing objective
## assignment, all 5 decomposition trees, context flag routing.


var _monk: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_monk = L5RCharacterData.new()
	_monk.character_id = 1
	_monk.character_name = "Test Monk"
	_monk.clan = "Brotherhood"
	_monk.family = "Shinsei"
	_monk.school = "Brotherhood of Shinsei"
	_monk.school_type = Enums.SchoolType.MONK
	_monk.bushido_virtue = Enums.BushidoVirtue.NONE
	_monk.shourido_virtue = Enums.ShouridoVirtue.NONE
	_monk.honor = 5.0
	_monk.glory = 2.0
	_monk.status = 2.0
	_monk.skills = {"Meditation": 3, "Theology": 2}
	_monk.emphases = {}
	_monk.reflexes = 3
	_monk.awareness = 3
	_monk.stamina = 3
	_monk.willpower = 3
	_monk.agility = 3
	_monk.intelligence = 3
	_monk.strength = 3
	_monk.perception = 3
	_monk.void_ring = 2
	_monk.wounds_taken = 0

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.school_type = Enums.SchoolType.MONK
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	_ctx.province_statuses = []
	_ctx.famine_crisis_province_ids = []
	_ctx.zone_flags = {}


func _make_ctx(flag: int) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school_type = Enums.SchoolType.MONK
	ctx.context_flag = flag
	ctx.province_statuses = []
	ctx.famine_crisis_province_ids = []
	ctx.zone_flags = {}
	return ctx


# =============================================================================
# Monk Identification
# =============================================================================

func test_is_monk_true_for_monk_school_type() -> void:
	assert_true(MonkObjectiveSystem.is_monk(_monk))


func test_is_monk_false_for_bushi() -> void:
	_monk.school_type = Enums.SchoolType.BUSHI
	assert_false(MonkObjectiveSystem.is_monk(_monk))


func test_is_monk_false_for_courtier() -> void:
	_monk.school_type = Enums.SchoolType.COURTIER
	assert_false(MonkObjectiveSystem.is_monk(_monk))


func test_is_monk_false_for_shugenja() -> void:
	_monk.school_type = Enums.SchoolType.SHUGENJA
	assert_false(MonkObjectiveSystem.is_monk(_monk))


# =============================================================================
# Combat Monk Detection
# =============================================================================

func test_is_combat_monk_sohei() -> void:
	_monk.school = "Sohei Order"
	assert_true(MonkObjectiveSystem.is_combat_monk(_monk))


func test_is_combat_monk_yamabushi() -> void:
	_monk.school = "Yamabushi Temple Guards"
	assert_true(MonkObjectiveSystem.is_combat_monk(_monk))


func test_is_combat_monk_false_for_regular_monk() -> void:
	_monk.school = "Brotherhood of Shinsei"
	assert_false(MonkObjectiveSystem.is_combat_monk(_monk))


func test_is_combat_monk_false_for_empty_school() -> void:
	_monk.school = ""
	assert_false(MonkObjectiveSystem.is_combat_monk(_monk))


# =============================================================================
# Objective Type Check
# =============================================================================

func test_is_monk_objective_help_people() -> void:
	assert_true(MonkObjectiveSystem.is_monk_objective("HELP_PEOPLE"))


func test_is_monk_objective_fight_bandits() -> void:
	assert_true(MonkObjectiveSystem.is_monk_objective("FIGHT_BANDITS"))


func test_is_monk_objective_meditate() -> void:
	assert_true(MonkObjectiveSystem.is_monk_objective("MEDITATE_DEEPLY"))


func test_is_monk_objective_train() -> void:
	assert_true(MonkObjectiveSystem.is_monk_objective("TRAIN_MASTERY"))


func test_is_monk_objective_worship() -> void:
	assert_true(MonkObjectiveSystem.is_monk_objective("WORSHIP_KAMI"))


func test_is_monk_objective_false_for_rest() -> void:
	assert_false(MonkObjectiveSystem.is_monk_objective("REST"))


func test_is_monk_objective_false_for_military() -> void:
	assert_false(MonkObjectiveSystem.is_monk_objective("DEFEND_TERRITORY"))


# =============================================================================
# Standing Objective Assignment
# =============================================================================

func test_assign_combat_monk_gets_fight_bandits() -> void:
	_monk.school = "Sohei Order"
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "FIGHT_BANDITS")


func test_assign_jin_monk_gets_help_people() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.JIN
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "HELP_PEOPLE")


func test_assign_chugi_monk_gets_worship() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "WORSHIP_KAMI")


func test_assign_rei_monk_gets_worship() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.REI
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "WORSHIP_KAMI")


func test_assign_gi_monk_gets_train() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.GI
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "TRAIN_MASTERY")


func test_assign_makoto_monk_gets_meditate() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.MAKOTO
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "MEDITATE_DEEPLY")


func test_assign_meiyo_monk_gets_train() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "TRAIN_MASTERY")


func test_assign_yu_monk_gets_fight_bandits() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.YU
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "FIGHT_BANDITS")


func test_assign_no_virtue_gets_meditate() -> void:
	_monk.bushido_virtue = Enums.BushidoVirtue.NONE
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "MEDITATE_DEEPLY")


func test_assign_non_monk_returns_empty() -> void:
	_monk.school_type = Enums.SchoolType.BUSHI
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_true(obj.is_empty())


func test_combat_monk_overrides_virtue() -> void:
	_monk.school = "Sohei Order"
	_monk.bushido_virtue = Enums.BushidoVirtue.JIN
	var obj: Dictionary = MonkObjectiveSystem.assign_standing_objective(_monk)
	assert_eq(obj["need_type"], "FIGHT_BANDITS")


# =============================================================================
# HELP_PEOPLE Decomposition
# =============================================================================

func test_help_people_at_temple() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")


func test_help_people_at_court() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_COURT)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.priority, 1)


func test_help_people_with_famine() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	ctx.famine_crisis_province_ids = [10]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_province_id, 10)
	assert_eq(need.target_intent, "famine_relief")


func test_help_people_with_low_stability() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.stability = 40.0
	ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_province_id, 5)


func test_help_people_traveling_with_famine() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.TRAVELING)
	ctx.famine_crisis_province_ids = [10]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_province_id, -1)


# =============================================================================
# FIGHT_BANDITS Decomposition
# =============================================================================

func test_fight_bandits_with_active_insurgency() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	ctx.active_insurgency_id = 5
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


func test_fight_bandits_with_bandit_crisis() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.stability = 70.0
	ps.crisis_type = "bandit"
	ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 5)


func test_fight_bandits_with_ronin_crisis() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 7
	ps.stability = 70.0
	ps.crisis_type = "ronin"
	ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 7)


func test_fight_bandits_with_low_stability() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 3
	ps.stability = 30.0
	ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 3)


func test_fight_bandits_no_threat_at_temple() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_fight_bandits_no_threat_traveling() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.TRAVELING)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("FIGHT_BANDITS", {}, ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


# =============================================================================
# MEDITATE_DEEPLY Decomposition
# =============================================================================

func test_meditate_at_temple() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("MEDITATE_DEEPLY", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 3)


func test_meditate_at_own_holdings() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("MEDITATE_DEEPLY", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 2)


func test_meditate_at_court() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_COURT)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("MEDITATE_DEEPLY", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 1)


func test_meditate_traveling() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.TRAVELING)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("MEDITATE_DEEPLY", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 1)


# =============================================================================
# TRAIN_MASTERY Decomposition
# =============================================================================

func test_train_at_dojo() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_DOJO)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("TRAIN_MASTERY", {}, ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 3)


func test_train_at_temple() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("TRAIN_MASTERY", {}, ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 2)


func test_train_at_own_holdings() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("TRAIN_MASTERY", {}, ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 2)


func test_train_traveling() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.TRAVELING)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("TRAIN_MASTERY", {}, ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 1)


# =============================================================================
# WORSHIP_KAMI Decomposition
# =============================================================================

func test_worship_at_temple() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("WORSHIP_KAMI", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 3)


func test_worship_at_own_holdings_with_shrine() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	ctx.zone_flags = {"shrine_eligible": true}
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("WORSHIP_KAMI", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 2)


func test_worship_at_own_holdings_without_shrine() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	ctx.zone_flags = {"shrine_eligible": false}
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("WORSHIP_KAMI", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 1)


func test_worship_traveling() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.TRAVELING)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("WORSHIP_KAMI", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 1)


func test_worship_at_court() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_COURT)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("WORSHIP_KAMI", {}, ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 1)


# =============================================================================
# ObjectiveDecomposer Integration
# =============================================================================

func test_decomposer_routes_monk_objectives() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var objective: Dictionary = {"need_type": "MEDITATE_DEEPLY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(objective, ctx)
	assert_not_null(need)
	assert_eq(need.need_type, "PERFORM_RITUAL")


func test_decomposer_routes_help_people() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var objective: Dictionary = {"need_type": "HELP_PEOPLE", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(objective, ctx)
	assert_not_null(need)
	assert_eq(need.need_type, "RAISE_DISPOSITION")


func test_decomposer_routes_fight_bandits() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var objective: Dictionary = {"need_type": "FIGHT_BANDITS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(objective, ctx)
	assert_not_null(need)


func test_decomposer_routes_train_mastery() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_DOJO)
	var objective: Dictionary = {"need_type": "TRAIN_MASTERY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(objective, ctx)
	assert_not_null(need)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 3)


func test_decomposer_routes_worship_kami() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var objective: Dictionary = {"need_type": "WORSHIP_KAMI", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(objective, ctx)
	assert_not_null(need)
	assert_eq(need.need_type, "PERFORM_RITUAL")


# =============================================================================
# Edge Cases
# =============================================================================

func test_decompose_unknown_need_returns_null() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("UNKNOWN", {}, ctx)
	assert_null(need)


func test_need_source_is_monk_decomposition() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_TEMPLE)
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("MEDITATE_DEEPLY", {}, ctx)
	assert_eq(need.source, "monk_decomposition")


func test_famine_priority_over_stability() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	ctx.famine_crisis_province_ids = [10]
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.stability = 30.0
	ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = MonkObjectiveSystem.decompose("HELP_PEOPLE", {}, ctx)
	assert_eq(need.target_province_id, 10)
	assert_eq(need.target_intent, "famine_relief")


func test_worst_stability_finder() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS)
	var ps1 := NPCDataStructures.ProvinceStatus.new()
	ps1.province_id = 1
	ps1.stability = 80.0
	var ps2 := NPCDataStructures.ProvinceStatus.new()
	ps2.province_id = 2
	ps2.stability = 30.0
	var ps3 := NPCDataStructures.ProvinceStatus.new()
	ps3.province_id = 3
	ps3.stability = 50.0
	ctx.province_statuses = [ps1, ps2, ps3]

	var worst: Dictionary = MonkObjectiveSystem._find_worst_stability_province(ctx)
	assert_eq(worst["province_id"], 2)
	assert_eq(worst["stability"], 30.0)
