extends GutTest


var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.clan = "Scorpion"
	_ctx.is_lord = false
	_ctx.lord_id = 100
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = []
	_ctx.dispositions = {}
	_ctx.disposition_values = {}
	_ctx.known_contacts_by_clan = {}
	_ctx.held_leverage = []
	_ctx.knowledge_pool = []
	_ctx.active_wars = []
	_ctx.unit_training_counts = {}


# =============================================================================
# BREAK_ALLIANCE
# =============================================================================

func test_break_alliance_no_contacts_identifies() -> void:
	var obj: Dictionary = {"need_type": "BREAK_ALLIANCE", "target_clan_id": "Crane", "target_clan_id_secondary": "Lion"}
	_ctx.known_contacts_by_clan = {}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")
	assert_eq(need.target_clan_id, "Crane")


func test_break_alliance_missing_one_side_identifies() -> void:
	var obj: Dictionary = {"need_type": "BREAK_ALLIANCE", "target_clan_id": "Crane", "target_clan_id_secondary": "Lion"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")
	assert_eq(need.target_clan_id, "Lion")


func test_break_alliance_no_intel_gathers() -> void:
	var obj: Dictionary = {"need_type": "BREAK_ALLIANCE", "target_clan_id": "Crane", "target_clan_id_secondary": "Lion"}
	_ctx.known_contacts_by_clan = {"Crane": [10], "Lion": [20]}
	_ctx.knowledge_pool = []
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 10)


func test_break_alliance_at_court_with_leverage() -> void:
	var obj: Dictionary = {"need_type": "BREAK_ALLIANCE", "target_clan_id": "Crane", "target_clan_id_secondary": "Lion"}
	_ctx.known_contacts_by_clan = {"Crane": [10], "Lion": [20]}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "disposition_observation"
	entry.data = {"target_character_id": 10}
	_ctx.knowledge_pool = [entry]
	_ctx.held_leverage = [{"target_id": 10}]
	_ctx.characters_present = [20]
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")
	assert_eq(need.priority, 3)


func test_break_alliance_at_court_no_leverage_acquires() -> void:
	var obj: Dictionary = {"need_type": "BREAK_ALLIANCE", "target_clan_id": "Crane", "target_clan_id_secondary": "Lion"}
	_ctx.known_contacts_by_clan = {"Crane": [10], "Lion": [20]}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "disposition_observation"
	entry.data = {"target_character_id": 10}
	_ctx.knowledge_pool = [entry]
	_ctx.held_leverage = []
	_ctx.characters_present = [10]
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")
	assert_eq(need.target_npc_id, 10)


# =============================================================================
# SECURE_ALLIANCE
# =============================================================================

func test_secure_alliance_no_contacts_identifies() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")
	assert_eq(need.target_clan_id, "Crane")


func test_secure_alliance_at_court_with_contact_raises_disposition() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	_ctx.characters_present = [10]
	_ctx.disposition_values = {10: 20.0}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 10)


func test_secure_alliance_high_disposition_arranges_marriage() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	_ctx.characters_present = [10]
	_ctx.disposition_values = {10: 55.0}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.priority, 3)


func test_secure_alliance_at_court_contact_absent_sends_letter() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	_ctx.characters_present = []
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.target_npc_id, 10)


func test_secure_alliance_at_holdings_low_disposition_sends_letter() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	_ctx.disposition_values = {10: 20.0}
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEND_LETTER")


func test_secure_alliance_visiting_with_contact_raises_disposition() -> void:
	var obj: Dictionary = {"need_type": "SECURE_ALLIANCE", "target_clan_id": "Crane"}
	_ctx.known_contacts_by_clan = {"Crane": [10]}
	_ctx.characters_present = [10]
	_ctx.disposition_values = {10: 20.0}
	_ctx.context_flag = Enums.ContextFlag.VISITING
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 10)


# =============================================================================
# ISOLATE_CHARACTER
# =============================================================================

func test_isolate_no_allies_gathers_intel() -> void:
	var obj: Dictionary = {"need_type": "ISOLATE_CHARACTER", "target_npc_id": 50}
	_ctx.knowledge_pool = []
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 50)


func test_isolate_fresh_intel_no_allies_returns_null() -> void:
	var obj: Dictionary = {"need_type": "ISOLATE_CHARACTER", "target_npc_id": 50}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "disposition_observation"
	entry.data = {"target_id": 50}
	entry.confidence = Enums.KnowledgeConfidence.FRESH
	_ctx.knowledge_pool = [entry]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_null(need)


func test_isolate_with_allies_at_court_gossips() -> void:
	var obj: Dictionary = {"need_type": "ISOLATE_CHARACTER", "target_npc_id": 50}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "disposition_observation"
	entry.data = {"observer_id": 50, "target_id": 60, "disposition": 30.0}
	_ctx.knowledge_pool = [entry]
	_ctx.disposition_values = {60: -5.0}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = []
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")


func test_isolate_weakest_ally_present_persuades() -> void:
	var obj: Dictionary = {"need_type": "ISOLATE_CHARACTER", "target_npc_id": 50}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "disposition_observation"
	entry.data = {"observer_id": 50, "target_id": 60, "disposition": 30.0}
	_ctx.knowledge_pool = [entry]
	_ctx.disposition_values = {60: -5.0}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = [60]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")
	assert_eq(need.target_npc_id, 60)


# =============================================================================
# GAIN_WINTER_COURT_INVITATION
# =============================================================================

func test_gain_invitation_at_court_raises_disposition() -> void:
	var obj: Dictionary = {"need_type": "GAIN_WINTER_COURT_INVITATION"}
	_ctx.lord_id = 100
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = [100]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 100)


func test_gain_invitation_not_at_court_seeks_court() -> void:
	var obj: Dictionary = {"need_type": "GAIN_WINTER_COURT_INVITATION"}
	_ctx.lord_id = 100
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.active_court_at_location = {"id": 1}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ATTEND_COURT")


# =============================================================================
# APPOINT_TO_POSITION
# =============================================================================

func test_appoint_at_court_persuades_authority() -> void:
	var obj: Dictionary = {"need_type": "APPOINT_TO_POSITION", "target_npc_id": 30, "authority_id": 200}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = [200]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")
	assert_eq(need.target_npc_id, 200)
	assert_eq(need.priority, 3)


func test_appoint_authority_absent_moves_topic() -> void:
	var obj: Dictionary = {"need_type": "APPOINT_TO_POSITION", "target_npc_id": 30, "authority_id": 200}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = []
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "MOVE_TOPIC_POSITION")


# =============================================================================
# REMOVE_FROM_POSITION
# =============================================================================

func test_remove_with_leverage_at_court_exposes() -> void:
	var obj: Dictionary = {"need_type": "REMOVE_FROM_POSITION", "target_npc_id": 50}
	_ctx.held_leverage = [{"target_id": 50}]
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")
	assert_eq(need.target_npc_id, 50)


func test_remove_no_leverage_acquires() -> void:
	var obj: Dictionary = {"need_type": "REMOVE_FROM_POSITION", "target_npc_id": 50}
	_ctx.held_leverage = []
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = [50]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")
	assert_eq(need.target_npc_id, 50)


# =============================================================================
# RESOLVE_CLAN_WAR
# =============================================================================

func test_resolve_war_no_contacts_identifies() -> void:
	var obj: Dictionary = {"need_type": "RESOLVE_CLAN_WAR", "target_clan_id": "Lion"}
	_ctx.known_contacts_by_clan = {}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "IDENTIFY_CONTACT")
	assert_eq(need.target_clan_id, "Lion")


func test_resolve_war_contact_present_negotiates() -> void:
	var obj: Dictionary = {"need_type": "RESOLVE_CLAN_WAR", "target_clan_id": "Lion"}
	_ctx.known_contacts_by_clan = {"Lion": [30]}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.characters_present = [30]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "SEEK_PEACE")
	assert_eq(need.priority, 3)


# =============================================================================
# EXPOSE_SECRET
# =============================================================================

func test_expose_with_leverage_at_court() -> void:
	var obj: Dictionary = {"need_type": "EXPOSE_SECRET", "target_npc_id": 50}
	_ctx.held_leverage = [{"target_id": 50}]
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")
	assert_eq(need.priority, 3)


func test_expose_no_leverage_acquires() -> void:
	var obj: Dictionary = {"need_type": "EXPOSE_SECRET", "target_npc_id": 50}
	_ctx.held_leverage = []
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")


# =============================================================================
# CONQUER_PROVINCE
# =============================================================================

func test_conquer_non_lord_on_campaign_fights() -> void:
	var obj: Dictionary = {"need_type": "CONQUER_PROVINCE", "target_province_id": 5}
	_ctx.is_lord = false
	_ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_TROOPS")
	assert_eq(need.priority, 3)


func test_conquer_non_lord_at_home_trains() -> void:
	var obj: Dictionary = {"need_type": "CONQUER_PROVINCE", "target_province_id": 5}
	_ctx.is_lord = false
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "TRAIN_SKILL")


func test_conquer_lord_low_readiness_levies() -> void:
	var obj: Dictionary = {"need_type": "CONQUER_PROVINCE", "target_province_id": 5}
	_ctx.is_lord = true
	_ctx.active_wars = []
	_ctx.unit_training_counts = {1: 5, 2: 3}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "LEVY_TROOPS")


func test_conquer_lord_war_active_high_readiness_orders_battle() -> void:
	var obj: Dictionary = {"need_type": "CONQUER_PROVINCE", "target_province_id": 5}
	_ctx.is_lord = true
	_ctx.active_wars = [{"id": 1}]
	_ctx.unit_training_counts = {3: 5, 4: 3, 5: 2}
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DEPLOY_ARMY")
	assert_eq(need.target_province_id, 5)


# =============================================================================
# INCREASE_KOKU
# =============================================================================

func test_increase_koku_non_lord_at_home_commerces() -> void:
	var obj: Dictionary = {"need_type": "INCREASE_KOKU", "target_province_id": 3}
	_ctx.is_lord = false
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "CONDUCT_COMMERCE")


func test_increase_koku_lord_stable_adjusts_tax() -> void:
	var obj: Dictionary = {"need_type": "INCREASE_KOKU", "target_province_id": 3}
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 3
	ps.stability = 70.0
	_ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ADJUST_TAX")


func test_increase_koku_lord_low_stability_patrols() -> void:
	var obj: Dictionary = {"need_type": "INCREASE_KOKU", "target_province_id": 3}
	_ctx.is_lord = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 3
	ps.stability = 30.0
	_ctx.province_statuses = [ps]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


# =============================================================================
# AVENGE
# =============================================================================

func test_avenge_target_present_duels() -> void:
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 50, "variant": "death"}
	_ctx.characters_present = [50]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "CHALLENGE_TO_DUEL")
	assert_eq(need.target_npc_id, 50)
	assert_eq(need.priority, 3)


func test_avenge_disgrace_variant_exposes() -> void:
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 50, "variant": "disgrace"}
	_ctx.characters_present = [50]
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")


func test_avenge_target_absent_gathers() -> void:
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 50, "variant": "death"}
	_ctx.characters_present = []
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = PrimaryObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 50)


# =============================================================================
# Routing through ObjectiveDecomposer
# =============================================================================

func test_routes_through_main_decomposer() -> void:
	var obj: Dictionary = {"need_type": "EXPOSE_SECRET", "target_npc_id": 50}
	_ctx.held_leverage = [{"target_id": 50}]
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "DAMAGE_RELATIONSHIP")


func test_standing_still_routes_correctly() -> void:
	_ctx.is_lord = true
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 1
	ps.stability = 90.0
	ps.garrison_pu = 5
	ps.confidence = 2
	_ctx.province_statuses = [ps]
	_ctx.resource_stockpiles = {"rice": 20.0, "population_pu": 8.0}
	var obj: Dictionary = {"need_type": "MAXIMIZE_PROSPERITY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, _ctx)
	assert_eq(need.need_type, "ADJUST_TAX")
