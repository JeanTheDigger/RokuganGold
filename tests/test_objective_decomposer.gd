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


func test_maintain_balance_traveling_with_court_attends() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	_ctx.active_court_at_location = {"settlement_id": 10, "prestige": 3}
	var obj: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ATTEND_COURT")


func test_maintain_balance_traveling_no_court_rests() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var obj: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


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


func test_maximize_prosperity_famine_response_with_surplus() -> void:
	_ctx.is_lord = true
	_ctx.famine_crisis_province_ids = [7]
	_ctx.resource_stockpiles = {"rice": 20.0, "population_pu": 8.0}
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 4
	ps.stability = 90.0
	ps.garrison_pu = 5
	ps.confidence = 2
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "CONDUCT_COMMERCE")
	assert_eq(need.target_province_id, 7)
	assert_eq(need.target_intent, "famine_relief")


func test_maximize_prosperity_famine_no_surplus_skips() -> void:
	_ctx.is_lord = true
	_ctx.famine_crisis_province_ids = [7]
	_ctx.resource_stockpiles = {"rice": 5.0, "population_pu": 8.0}
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 4
	ps.stability = 90.0
	ps.garrison_pu = 5
	ps.confidence = 2
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "CONDUCT_COMMERCE", "Low rice skips famine response")


func test_maximize_prosperity_famine_non_lord_ignores() -> void:
	_ctx.is_lord = false
	_ctx.famine_crisis_province_ids = [7]
	_ctx.resource_stockpiles = {"rice": 20.0, "population_pu": 8.0}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "CONDUCT_COMMERCE", "Non-lords do not share supplies")


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


# -- Military routing covers all 7 objectives ---------------------------------

func test_military_routing() -> void:
	for nt: String in ObjectiveDecomposer.MILITARY_OBJECTIVES:
		var obj: Dictionary = {"need_type": nt}
		var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
		assert_not_null(need, "Military objective %s should produce a need" % nt)


# =============================================================================
# Strengthen Wall (s55.23.1)
# =============================================================================


func _make_wall_status(
	pid: int,
	si: int = 10,
	scout: bool = true,
	scout_age: int = 0,
) -> NPCDataStructures.WallStatus:
	var ws := NPCDataStructures.WallStatus.new()
	ws.province_id = pid
	ws.si = si
	ws.scout_deployed = scout
	ws.scout_report_age = scout_age
	return ws


func _make_wall_province_status(pid: int, confidence: int = 2) -> NPCDataStructures.ProvinceStatus:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = pid
	ps.stability = 80.0
	ps.garrison_pu = 5
	ps.confidence = confidence
	ps.is_wall_province = true
	return ps


func test_strengthen_wall_non_lord_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")
	assert_eq(need.priority, 2)


func test_strengthen_wall_non_lord_at_holdings_with_wall_province() -> void:
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")
	assert_eq(need.target_province_id, 5)


func test_strengthen_wall_non_lord_no_wall_province() -> void:
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_strengthen_wall_lord_stale_intel() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5, 0)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 5)
	assert_eq(need.priority, 3)


func test_strengthen_wall_lord_undergarrisoned() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.target_province_id, 5)


func test_strengthen_wall_lord_scouts_missing() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5, 10, false)
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEPLOY_SCOUTS")
	assert_eq(need.priority, 3)


func test_strengthen_wall_lord_scout_report_stale() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5, 10, true, 2)
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEPLOY_SCOUTS")


func test_strengthen_wall_lord_low_si() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5, 4)
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MAINTAIN_FORTIFICATION")
	assert_eq(need.priority, 3)


func test_strengthen_wall_lord_taint_rank_high() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.max_taint_rank = 3
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MANAGE_TAINT")


func test_strengthen_wall_lord_tea_low() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.tea_stockpile_seasons = 0.5
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MANAGE_TAINT")


func test_strengthen_wall_lord_jade_critical() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.jade_stockpile_critical = true
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "jade")


func test_strengthen_wall_lord_sortie_conditions_met() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.scout_report_elevated_activity = true
	ws.scout_report_age = 0
	ws.garrison_above_minimum = true
	ws.si = 8
	ws.jade_stockpile_critical = false
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ORDER_SHADOWLANDS_SORTIE")
	assert_eq(need.priority, 2)


func test_strengthen_wall_lord_sortie_blocked_jade() -> void:
	_ctx.is_lord = true
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.scout_report_elevated_activity = true
	ws.scout_report_age = 0
	ws.garrison_above_minimum = true
	ws.jade_stockpile_critical = true
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	_ctx.unit_training_counts = {0: 1}
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "ORDER_SHADOWLANDS_SORTIE")


func test_strengthen_wall_lord_train_troops() -> void:
	_ctx.is_lord = true
	_ctx.wall_statuses = [_make_wall_status(5)]
	_ctx.province_statuses = [_make_wall_province_status(5)]
	_ctx.unit_training_counts = {1: 2}
	_ctx.resource_stockpiles = {"arms": 20.0, "iron": 10.0}
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")


func test_strengthen_wall_lord_low_arms() -> void:
	_ctx.is_lord = true
	_ctx.wall_statuses = [_make_wall_status(5)]
	_ctx.province_statuses = [_make_wall_province_status(5)]
	_ctx.resource_stockpiles = {"arms": 5.0, "iron": 10.0}
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "arms")


func test_strengthen_wall_lord_low_iron() -> void:
	_ctx.is_lord = true
	_ctx.wall_statuses = [_make_wall_status(5)]
	_ctx.province_statuses = [_make_wall_province_status(5)]
	_ctx.resource_stockpiles = {"arms": 20.0, "iron": 3.0}
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "iron")


func test_strengthen_wall_lord_all_clear_levy() -> void:
	_ctx.is_lord = true
	_ctx.wall_statuses = [_make_wall_status(5)]
	_ctx.province_statuses = [_make_wall_province_status(5)]
	_ctx.resource_stockpiles = {"arms": 20.0, "iron": 10.0}
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "LEVY_TROOPS")
	assert_eq(need.priority, 1)


# -- Garrison Shortage Escalation Pipeline (s2.4.12–14) -----------------------


func test_strengthen_wall_champion_no_letter_sends_letter() -> void:
	_ctx.is_lord = true
	_ctx.lord_rank = Enums.LordRank.CLAN_CHAMPION
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = -1
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	_ctx.season = 3
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.target_province_id, 5)
	assert_eq(need.priority, 3)


func test_strengthen_wall_champion_letter_sent_same_season_uses_defend() -> void:
	_ctx.is_lord = true
	_ctx.lord_rank = Enums.LordRank.CLAN_CHAMPION
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = 3  # same season — not enough time
	ws.garrison_shortage_courtier_dispatched = false
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	_ctx.season = 3
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")


func test_strengthen_wall_champion_one_season_later_dispatches_courtier() -> void:
	_ctx.is_lord = true
	_ctx.lord_rank = Enums.LordRank.CLAN_CHAMPION
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = 2  # one season ago
	ws.garrison_shortage_courtier_dispatched = false
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	_ctx.season = 3
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DISPATCH_COURTIER")
	assert_eq(need.target_province_id, 5)
	assert_eq(need.priority, 3)


func test_strengthen_wall_champion_courtier_dispatched_falls_back_to_defend() -> void:
	_ctx.is_lord = true
	_ctx.lord_rank = Enums.LordRank.CLAN_CHAMPION
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = 2
	ws.garrison_shortage_courtier_dispatched = true
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	_ctx.season = 3
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.target_province_id, 5)


func test_strengthen_wall_shireikan_no_letter_sends_letter() -> void:
	_ctx.is_lord = true
	_ctx.military_rank = Enums.MilitaryRank.SHIREIKAN
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = -1
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.target_province_id, 5)
	assert_eq(need.priority, 3)


func test_strengthen_wall_shireikan_letter_sent_uses_defend() -> void:
	_ctx.is_lord = true
	_ctx.military_rank = Enums.MilitaryRank.SHIREIKAN
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	ws.garrison_shortage_letter_season = 2
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")


func test_strengthen_wall_non_champion_lord_skips_escalation() -> void:
	_ctx.is_lord = true
	_ctx.lord_rank = Enums.LordRank.FAMILY_DAIMYO
	var ws: NPCDataStructures.WallStatus = _make_wall_status(5)
	ws.minimum_garrison = 5
	var ps: NPCDataStructures.ProvinceStatus = _make_wall_province_status(5)
	ps.garrison_pu = 2
	_ctx.wall_statuses = [ws]
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "STRENGTHEN_WALL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")


# =============================================================================
# Military Dominance (s55.23.2)
# =============================================================================


func test_military_dominance_no_intel_lord() -> void:
	_ctx.is_lord = true
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_military_dominance_no_intel_non_lord() -> void:
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")


func test_military_dominance_clearly_dominant() -> void:
	_ctx.is_lord = true
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 30.0, "crane": 15.0}
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "arms")
	assert_eq(need.priority, 1)


func test_military_dominance_dominant_with_raw_units() -> void:
	_ctx.is_lord = true
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 30.0, "crane": 15.0}
	_ctx.unit_training_counts = {0: 2, 2: 3}
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")


func test_military_dominance_ahead_but_unsafe_levy() -> void:
	_ctx.is_lord = true
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 30.0, "crane": 25.0}
	_ctx.available_levy_pu = 5.0
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "LEVY_TROOPS")
	assert_eq(need.priority, 2)


func test_military_dominance_ahead_no_levy() -> void:
	_ctx.is_lord = true
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 30.0, "crane": 25.0}
	_ctx.available_levy_pu = 0.0
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")


func test_military_dominance_behind_lord() -> void:
	_ctx.is_lord = true
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 20.0, "crane": 25.0}
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "LEVY_TROOPS")
	assert_eq(need.priority, 3)


func test_military_dominance_behind_non_lord() -> void:
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 20.0, "crane": 25.0}
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.priority, 2)


func test_military_dominance_non_lord_ahead() -> void:
	_ctx.clan = "lion"
	_ctx.known_clan_strengths = {"lion": 30.0, "crane": 25.0}
	var obj: Dictionary = {"need_type": "MILITARY_DOMINANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


# =============================================================================
# Eliminate Shadowlands (s55.23.3)
# =============================================================================


func test_eliminate_shadowlands_active_crisis() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 7
	ps.active_crisis_id = 42
	ps.crisis_type = "shadowlands_incursion"
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.target_province_id, 7)
	assert_eq(need.priority, 3)


func test_eliminate_shadowlands_non_shadowlands_crisis_skipped() -> void:
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 7
	ps.active_crisis_id = 42
	ps.crisis_type = "border_conflict"
	_ctx.province_statuses = [ps]
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "DEFEND_PROVINCE")


func test_eliminate_shadowlands_insurgency() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 3
	ps.active_insurgency_id = 10
	_ctx.province_statuses = [ps]
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 3)
	assert_eq(need.priority, 3)


func test_eliminate_shadowlands_taint_topic() -> void:
	_ctx.taint_topic_province_ids = [9]
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 9)
	assert_eq(need.priority, 2)


func test_eliminate_shadowlands_proactive_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")


func test_eliminate_shadowlands_shugenja_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	_ctx.school_type = Enums.SchoolType.SHUGENJA
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")


func test_eliminate_shadowlands_bushi_at_temple() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_TEMPLE
	_ctx.school_type = Enums.SchoolType.BUSHI
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PERFORM_RITUAL")


func test_eliminate_shadowlands_lord_at_holdings() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


func test_eliminate_shadowlands_non_lord_at_holdings() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var obj: Dictionary = {"need_type": "ELIMINATE_SHADOWLANDS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


# =============================================================================
# Maintain Peace (s55.23.4)
# =============================================================================


func test_maintain_peace_active_war() -> void:
	_ctx.clan = "crab"
	_ctx.active_wars = [{"clan_a": "crab", "clan_b": "lion"}]
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_PEACE")
	assert_eq(need.target_clan_id, "lion")
	assert_eq(need.priority, 3)


func test_maintain_peace_rising_tensions_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.escalating_conflicts = [{"topic_id": 42}]
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")
	assert_eq(need.target_topic_id, 42)
	assert_eq(need.priority, 3)


func test_maintain_peace_rising_tensions_not_at_court_with_lord() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.lord_id = 99
	_ctx.escalating_conflicts = [{"topic_id": 42}]
	_ctx.action_log = []
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.target_npc_id, 99)


func test_maintain_peace_rising_tensions_not_at_court_no_lord() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.escalating_conflicts = [{"topic_id": 42}]
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_maintain_peace_preventive_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 30)


func test_maintain_peace_preventive_at_court_all_friendly() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = []
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")


func test_maintain_peace_preventive_at_holdings() -> void:
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_maintain_peace_preventive_traveling_with_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	_ctx.active_court_at_location = {"settlement_id": 10}
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ATTEND_COURT")


func test_maintain_peace_preventive_traveling_no_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var obj: Dictionary = {"need_type": "MAINTAIN_PEACE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


# =============================================================================
# Build Strongest Force (s55.23.5)
# =============================================================================


func test_build_strongest_force_non_lord() -> void:
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 1)


func test_build_strongest_force_raw_units() -> void:
	_ctx.is_lord = true
	_ctx.unit_training_counts = {0: 2, 2: 1}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")
	assert_eq(need.priority, 3)


func test_build_strongest_force_drilled_units() -> void:
	_ctx.is_lord = true
	_ctx.unit_training_counts = {1: 3}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")
	assert_eq(need.priority, 2)


func test_build_strongest_force_iron_unsustainable() -> void:
	_ctx.is_lord = true
	_ctx.can_sustain_iron_upkeep = false
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "iron")


func test_build_strongest_force_levy_when_sustainable() -> void:
	_ctx.is_lord = true
	_ctx.available_levy_pu = 3.0
	_ctx.resource_stockpiles = {"rice": 100.0, "military_upkeep": 5.0}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "LEVY_TROOPS")
	assert_eq(need.priority, 1)


func test_build_strongest_force_levy_blocked_low_rice() -> void:
	_ctx.is_lord = true
	_ctx.available_levy_pu = 3.0
	_ctx.resource_stockpiles = {"rice": 5.0, "military_upkeep": 10.0}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "LEVY_TROOPS")


func test_build_strongest_force_trained_to_veteran() -> void:
	_ctx.is_lord = true
	_ctx.unit_training_counts = {2: 2}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")
	assert_eq(need.priority, 1)


func test_build_strongest_force_all_veteran() -> void:
	_ctx.is_lord = true
	_ctx.unit_training_counts = {3: 5}
	var obj: Dictionary = {"need_type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")
	assert_eq(need.target_resource, "arms")


# -- Succession Marriage (s57.20.2) -------------------------------------------

func test_protect_dependents_succession_unmarried_lord_marriage() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.known_contacts_by_clan = {"Lion": [50]}
	_ctx.dispositions = {50: 10}
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.priority, 3)
	assert_eq(need.target_npc_id, _ctx.character_id)
	assert_eq(need.target_npc_id_secondary, 50)
	assert_eq(need.target_intent, "PROTECT_DEPENDENTS")


func test_protect_dependents_succession_married_lord_vassal_marriage() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = false
	_ctx.marriageable_vassal_ids = [42]
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.known_contacts_by_clan = {"Crane": [60]}
	_ctx.dispositions = {60: 5}
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.priority, 2)
	assert_eq(need.target_npc_id, 42)
	assert_eq(need.target_npc_id_secondary, 60)


func test_protect_dependents_succession_secure_no_marriage() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = false
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.known_contacts_by_clan = {"Lion": [50]}
	_ctx.dispositions = {50: 10}
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE")


func test_protect_dependents_succession_no_contacts_no_marriage() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE")


func test_protect_dependents_crisis_takes_priority_over_succession() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.known_contacts_by_clan = {"Lion": [50]}
	_ctx.dispositions = {50: 10}
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 1
	ps.stability = 20.0
	ps.active_crisis_id = 99
	_ctx.province_statuses = [ps]
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEFEND_PROVINCE")


func test_protect_dependents_not_at_holdings_no_marriage() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.known_contacts_by_clan = {"Lion": [50]}
	_ctx.dispositions = {50: 10}
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE")


func test_protect_dependents_succession_recent_attempt_skips() -> void:
	_ctx.is_lord = true
	_ctx.succession_insecure = true
	_ctx.lord_is_unmarried = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.known_contacts_by_clan = {"Lion": [50]}
	_ctx.dispositions = {50: 10}
	_ctx.ic_day = 50
	_ctx.action_log = [{"action_id": "ARRANGE_MARRIAGE", "character_id": _ctx.character_id, "ic_day": 40}]
	var obj := {"need_type": "PROTECT_DEPENDENTS", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE")


# -- FILL_VACANCY Decomposition (s57.20.3) ------------------------------------

func test_fill_vacancy_non_lord_rest() -> void:
	_ctx.is_lord = false
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


func test_fill_vacancy_not_at_holdings_rest() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


func test_fill_vacancy_no_vacancies_rest() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "REST")


func test_fill_vacancy_picks_highest_priority() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.vacant_positions = [
		{"position_type": "School Master", "priority": 2, "candidate_id": 10, "province_id": -1, "seasons_vacant": 0},
		{"position_type": "Clan Magistrate", "priority": 3, "candidate_id": 20, "province_id": -1, "seasons_vacant": 0},
	]
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "FILL_VACANCY")
	assert_eq(need.target_intent, "Clan Magistrate")
	assert_eq(need.target_npc_id, 20)
	assert_eq(need.priority, 3)


func test_fill_vacancy_escalates_after_two_seasons() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.vacant_positions = [
		{"position_type": "School Master", "priority": 1, "candidate_id": 10, "province_id": -1, "seasons_vacant": 3},
	]
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "FILL_VACANCY")
	assert_eq(need.priority, 2)


func test_fill_vacancy_priority_3_no_escalation() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.vacant_positions = [
		{"position_type": "Clan Magistrate", "priority": 3, "candidate_id": 20, "province_id": -1, "seasons_vacant": 5},
	]
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.priority, 3)


func test_fill_vacancy_same_priority_tiebreak_by_seasons() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.vacant_positions = [
		{"position_type": "School Master", "priority": 2, "candidate_id": 10, "province_id": -1, "seasons_vacant": 1},
		{"position_type": "Temple Head", "priority": 2, "candidate_id": 30, "province_id": -1, "seasons_vacant": 4},
	]
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.target_npc_id, 30)


func test_fill_vacancy_carries_province_id() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.vacant_positions = [
		{"position_type": "Garrison Commander", "priority": 3, "candidate_id": 15, "province_id": 7, "seasons_vacant": 0},
	]
	var obj := {"need_type": "FILL_VACANCY", "priority": 2}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.target_province_id, 7)
