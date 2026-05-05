extends GutTest


var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.character_name = "Test NPC"
	_ctx.is_lord = false
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.season = 1
	_ctx.ic_day = 10
	_ctx.honor = 5.0
	_ctx.glory = 3.0
	_ctx.status = 3.0
	_ctx.school_type = Enums.SchoolType.COURTIER
	_ctx.bushido_virtue = Enums.BushidoVirtue.REI
	_ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	_ctx.characters_present = [10, 20, 30]
	_ctx.dispositions = {10: 15, 20: 45, 30: -5}
	_ctx.known_contacts = [10, 20, 30]


# -- Routing -------------------------------------------------------------------

func test_unknown_need_type_passthrough() -> void:
	var obj: Dictionary = {"need_type": "SOME_CUSTOM_NEED", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SOME_CUSTOM_NEED")
	assert_eq(need.priority, 2)


func test_empty_need_type_returns_null() -> void:
	var obj: Dictionary = {}
	var need: Variant = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_null(need)


func test_political_routing() -> void:
	for nt: String in ObjectiveDecomposer.POLITICAL_OBJECTIVES:
		var obj: Dictionary = {"need_type": nt}
		var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
		assert_not_null(need, "Political objective %s should produce a need" % nt)


func test_economic_routing() -> void:
	for nt: String in ObjectiveDecomposer.ECONOMIC_OBJECTIVES:
		var obj: Dictionary = {"need_type": nt}
		var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
		assert_not_null(need, "Economic objective %s should produce a need" % nt)


func test_personal_routing() -> void:
	for nt: String in ObjectiveDecomposer.PERSONAL_OBJECTIVES:
		var obj: Dictionary = {"need_type": nt}
		var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
		assert_not_null(need, "Personal objective %s should produce a need" % nt)


# -- Political: Expand Territory -----------------------------------------------

func test_expand_territory_non_lord_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "EXPAND_TERRITORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 10)


func test_expand_territory_non_lord_at_holdings() -> void:
	var obj: Dictionary = {"need_type": "EXPAND_TERRITORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_expand_territory_lord_with_weak_province() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.stability = 40.0
	ps.confidence = 0
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "EXPAND_TERRITORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_province_id, 5)


# -- Political: Maintain Balance -----------------------------------------------

func test_maintain_balance_at_court_builds_disposition() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 10)


func test_maintain_balance_at_court_all_friends_moves_topic() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.dispositions = {10: 50, 20: 60, 30: 45}
	var obj: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")


func test_maintain_balance_traveling_attends_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var obj: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ATTEND_COURT")


# -- Political: Advance Family -------------------------------------------------

func test_advance_family_at_court_raise_disp() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")


func test_advance_family_at_court_friends_seek_glory() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.dispositions = {10: 50, 20: 60, 30: 45}
	var obj: Dictionary = {"need_type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_GLORY")


func test_advance_family_lord_with_crisis() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 3
	ps.active_crisis_id = 99
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.target_province_id, 3)


# -- Political: Undermine Clan -------------------------------------------------

func test_undermine_clan_at_court_with_target_present() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "UNDERMINE_CLAN", "target_clan_id": "lion"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")


func test_undermine_clan_at_holdings() -> void:
	var obj: Dictionary = {"need_type": "UNDERMINE_CLAN", "target_clan_id": "lion"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")


# -- Political: Accumulate Leverage --------------------------------------------

func test_accumulate_leverage_at_court_few_friends() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.dispositions = {10: 5, 20: 10, 30: -5}
	var obj: Dictionary = {"need_type": "ACCUMULATE_LEVERAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")


func test_accumulate_leverage_at_court_many_friends() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.dispositions = {10: 50, 20: 60, 30: 45}
	var obj: Dictionary = {"need_type": "ACCUMULATE_LEVERAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")


# -- Economic: Maximize Prosperity ---------------------------------------------

func test_maximize_prosperity_non_lord_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")


func test_maximize_prosperity_lord_with_crisis() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 7
	ps.active_crisis_id = 42
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.priority, 3)


func test_maximize_prosperity_lord_stale_info() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 4
	ps.confidence = 0
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")


func test_maximize_prosperity_lord_all_clear() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 4
	ps.stability = 90.0
	ps.garrison_pu = 5
	ps.confidence = 2
	_ctx.province_statuses = [ps]
	_ctx.resource_stockpiles = {"rice": 20.0, "population_pu": 8.0}
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ADJUST_TAX")


# -- Economic: Prevent Shortage ------------------------------------------------

func test_prevent_shortage_non_lord_sends_letter() -> void:
	var obj: Dictionary = {"need_type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_prevent_shortage_lord_rice_critical() -> void:
	_ctx.is_lord = true
	_ctx.resource_stockpiles = {"rice": 0.5, "rice_consumption": 1.0}
	var obj: Dictionary = {"need_type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.priority, 3)
	assert_eq(need.target_resource, "rice")


func test_prevent_shortage_lord_rice_low() -> void:
	_ctx.is_lord = true
	_ctx.resource_stockpiles = {"rice": 1.5, "rice_consumption": 1.0}
	var obj: Dictionary = {"need_type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.priority, 2)


func test_prevent_shortage_lord_all_good() -> void:
	_ctx.is_lord = true
	_ctx.resource_stockpiles = {
		"rice": 10.0, "rice_consumption": 1.0,
		"arms": 10.0, "arms_upkeep": 1.0,
		"iron": 5.0, "koku": 10.0,
	}
	var obj: Dictionary = {"need_type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


# -- Personal: Honor Ancestors -------------------------------------------------

func test_honor_ancestors_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_GLORY")


func test_honor_ancestors_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	var obj: Dictionary = {"need_type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")


func test_honor_ancestors_at_holdings_non_lord() -> void:
	var obj: Dictionary = {"need_type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_honor_ancestors_on_campaign() -> void:
	_ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	var obj: Dictionary = {"need_type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


# -- Personal: Personal Excellence ---------------------------------------------

func test_personal_excellence_at_dojo() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_DOJO
	var obj: Dictionary = {"need_type": "PERSONAL_EXCELLENCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 3)


func test_personal_excellence_courtier_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.school_type = Enums.SchoolType.COURTIER
	var obj: Dictionary = {"need_type": "PERSONAL_EXCELLENCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_GLORY")


func test_personal_excellence_bushi_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.school_type = Enums.SchoolType.BUSHI
	var obj: Dictionary = {"need_type": "PERSONAL_EXCELLENCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_personal_excellence_shugenja_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	_ctx.school_type = Enums.SchoolType.SHUGENJA
	var obj: Dictionary = {"need_type": "PERSONAL_EXCELLENCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 3)


# -- Personal: Live By Bushido -------------------------------------------------

func test_live_by_bushido_low_honor() -> void:
	_ctx.honor = 2.0
	var obj: Dictionary = {"need_type": "LIVE_BY_BUSHIDO"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RESTORE_HONOR")


func test_live_by_bushido_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	var obj: Dictionary = {"need_type": "LIVE_BY_BUSHIDO"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")


func test_live_by_bushido_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "LIVE_BY_BUSHIDO"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_GLORY")


# -- Personal: Accumulate Knowledge --------------------------------------------

func test_accumulate_knowledge_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "ACCUMULATE_KNOWLEDGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")


func test_accumulate_knowledge_at_dojo() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_DOJO
	var obj: Dictionary = {"need_type": "ACCUMULATE_KNOWLEDGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_accumulate_knowledge_shugenja_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	_ctx.school_type = Enums.SchoolType.SHUGENJA
	var obj: Dictionary = {"need_type": "ACCUMULATE_KNOWLEDGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")


# -- Personal: Seek Vengeance --------------------------------------------------

func test_seek_vengeance_target_present() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "SEEK_VENGEANCE", "target_npc_id": 10}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ISSUE_DUEL_CHALLENGE")
	assert_eq(need.target_npc_id, 10)
	assert_eq(need.priority, 3)


func test_seek_vengeance_target_not_present() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "SEEK_VENGEANCE", "target_npc_id": 999}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")


func test_seek_vengeance_no_target_clan_only() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.known_contacts = []
	var obj: Dictionary = {"need_type": "SEEK_VENGEANCE", "target_clan_id": "lion"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")


# -- Personal: Advance Glory --------------------------------------------------

func test_advance_glory_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "ADVANCE_GLORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_GLORY")


func test_advance_glory_under_siege() -> void:
	_ctx.context_flag = Enums.ContextFlag.UNDER_SIEGE
	var obj: Dictionary = {"need_type": "ADVANCE_GLORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "CONDUCT_SORTIE")


# -- Personal: Protect Dependents ----------------------------------------------

func test_protect_dependents_lord_crisis() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 8
	ps.active_crisis_id = 1
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "PROTECT_DEPENDENTS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.priority, 3)


func test_protect_dependents_lord_unstable() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 2
	ps.stability = 60.0
	ps.garrison_pu = 5
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "PROTECT_DEPENDENTS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


func test_protect_dependents_non_lord() -> void:
	var obj: Dictionary = {"need_type": "PROTECT_DEPENDENTS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")


# -- Military: Defend Territory ------------------------------------------------

func test_defend_territory_lord_no_issues() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 1
	ps.stability = 90.0
	ps.garrison_pu = 5
	ps.confidence = 2
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "DEFEND_TERRITORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "EVALUATE_WAR_READINESS")


func test_defend_territory_non_lord() -> void:
	var obj: Dictionary = {"need_type": "DEFEND_TERRITORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


# -- Cross-reference: Elevate Family uses Advance Family -----------------------

func test_elevate_family_matches_advance_family() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj_adv: Dictionary = {"need_type": "ADVANCE_FAMILY"}
	var obj_elev: Dictionary = {"need_type": "ELEVATE_FAMILY"}
	var need_adv: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj_adv, _ctx)
	var need_elev: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj_elev, _ctx)
	assert_eq(need_adv.need_type, need_elev.need_type)


# -- Source tag ----------------------------------------------------------------

func test_decomposed_need_has_source() -> void:
	var obj: Dictionary = {"need_type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.source, "decomposition")


func test_passthrough_preserves_source() -> void:
	var obj: Dictionary = {"need_type": "REST", "source": "standing"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.source, "standing")
