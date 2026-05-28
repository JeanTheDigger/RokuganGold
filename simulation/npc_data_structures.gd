class_name NPCDataStructures
## Data structures for the NPC Decision Engine per GDD s55.3.
## These are plain data containers — no simulation logic.


class ImmediateNeed:
	var need_type: String = ""
	var priority: int = 2
	var target_npc_id: int = -1
	var target_npc_id_secondary: int = -1
	var target_settlement_id: int = -1
	var target_province_id: int = -1
	var target_clan_id: String = ""
	var target_topic_id: int = -1
	var target_resource: String = ""
	var target_army_id: int = -1
	var target_intent: String = ""
	var threshold: float = 0.0
	var threshold_type: String = ""
	var source: String = ""


class ScoredAction:
	var action_id: String = ""
	var target_npc_id: int = -1
	var target_npc_id_secondary: int = -1
	var target_settlement_id: int = -1
	var target_province_id: int = -1
	var ap_cost: int = 1
	var is_order: bool = false
	var metadata: Dictionary = {}

	# Eight base scoring components per s55.4 Phase 5
	var objective_alignment: float = 0.0
	var disposition_modifier: float = 0.0
	var personality_lean: float = 0.0
	var competence_modifier: float = 0.0
	var urgency_bonus: float = 0.0
	var standing_influence: float = 0.0
	var topic_position_modifier: float = 0.0
	var resource_modifier: float = 0.0

	# Additional scoring modifiers from wired subsystems
	var approach_modifier: float = 0.0
	var commitment_at_risk: float = 0.0
	var travel_redirect_penalty: float = 0.0
	var confidence_penalty: float = 0.0
	var stale_intel_bonus: float = 0.0
	var festival_modifier: float = 0.0
	var deception_defense_penalty: float = 0.0
	var honor_covert_penalty: float = 0.0
	var virtue_covert_modifier: float = 0.0

	func get_total_score() -> float:
		return (
			objective_alignment
			+ disposition_modifier
			+ personality_lean
			+ competence_modifier
			+ urgency_bonus
			+ standing_influence
			+ topic_position_modifier
			+ resource_modifier
			+ approach_modifier
			+ commitment_at_risk
			+ travel_redirect_penalty
			+ confidence_penalty
			+ stale_intel_bonus
			+ festival_modifier
			+ deception_defense_penalty
			+ honor_covert_penalty
			+ virtue_covert_modifier
		)


class ContextSnapshot:
	# Identity
	var character_id: int = -1
	var character_name: String = ""
	var clan: String = ""
	var family: String = ""
	var school: String = ""
	var school_type: Enums.SchoolType = Enums.SchoolType.BUSHI
	var is_lord: bool = false
	var lord_rank: Enums.LordRank = Enums.LordRank.VILLAGE_HEADMAN
	var civilian_orders_remaining: int = 0

	# Location & situation
	var location_id: String = ""
	var context_flag: Enums.ContextFlag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var season: int = 0
	var ic_day: int = 0
	var zone_subtype: Enums.ZoneSubtype = Enums.ZoneSubtype.OHIROMA
	var zone_flags: Dictionary = {}
	var sublocation: Enums.Sublocation = Enums.Sublocation.PUBLIC

	# Lord & court (s55.34)
	var lord_id: int = -1
	var active_court_at_location: Dictionary = {}
	var upcoming_courts: Array = []
	var held_leverage: Array = []
	var known_npc_locations: Dictionary = {}
	var court_session_state: Dictionary = {}
	var court_settlement_id: int = -1

	# Stats
	var skill_ranks: Dictionary = {}
	var honor: float = 0.0
	var glory: float = 0.0
	var status: float = 0.0
	var insight_rank: int = 1

	# Social knowledge
	var characters_present: Array = []
	var dispositions: Dictionary = {}
	var disposition_values: Dictionary = {}
	var known_topics: Array = []
	var known_positions: Dictionary = {}
	var known_topic_types: Dictionary = {}
	var known_objectives: Dictionary = {}
	var known_contacts: Array = []
	var contact_clans: Dictionary = {}
	var known_contacts_by_clan: Dictionary = {}
	var met_characters: Array = []
	var knowledge_pool: Array = []
	var known_secrets: Array = []

	# Lord-tier fields
	var resource_stockpiles: Dictionary = {}
	var province_statuses: Array = []
	var feasibility_data: Dictionary = {}

	# Vacancy detection (s57.20.3)
	var vacant_positions: Array = []

	# Marriage (s22.7)
	var marriageable_vassal_ids: Array = []
	var succession_insecure: bool = false
	var lord_is_unmarried: bool = false

	# Military
	var military_rank: Enums.MilitaryRank = Enums.MilitaryRank.NONE
	var commanded_unit_id: int = -1
	var assigned_company_id: int = -1

	# Wall management (s55.23)
	var wall_statuses: Array = []
	# Precomputed garrison shortage personality modifier per known contact
	# (character_id → float from WallSystem personality table, s2.4.12–13).
	# Populated only for characters with wall_statuses; empty otherwise.
	var contact_garrison_scores: Dictionary = {}

	# Military intelligence (s55.23)
	var known_clan_strengths: Dictionary = {}
	var unit_training_counts: Dictionary = {}
	var available_levy_pu: float = 0.0
	var can_sustain_iron_upkeep: bool = true

	# Conflict state (s55.23)
	var active_wars: Array = []
	var escalating_conflicts: Array = []

	# Insurgency context (convenience field populated from ProvinceStatus)
	var active_insurgency_id: int = -1

	# Shadowlands intelligence (s55.23)
	var taint_topic_province_ids: Array = []

	# Famine crisis intelligence
	var famine_crisis_province_ids: Array = []

	# Infrastructure intelligence (s4.3.22)
	var worship_failing_province_ids: Array = []
	var border_province_ids_without_fort: Array = []
	var surplus_pu_province_ids: Array = []
	var is_coastal: bool = false
	var has_naval_assets: bool = false
	var has_naval_threat: bool = false

	# Festival state (s11.5)
	var is_ceasefire_day: bool = false
	var is_labor_halt_day: bool = false
	var is_taian: bool = false
	var is_inauspicious_for_social: bool = false
	var festival_honor_gain: float = 0.0
	var festival_has_lion_honor: bool = false
	var festival_glory_poetry: float = 0.0
	var festival_glory_martial: float = 0.0
	var is_hostage: bool = false

	# Urgency evaluation fields
	var expiring_favor_ids: Array = []
	var starvation_province_ids: Array = []
	var cut_supply_army_ids: Array = []
	var besieged_settlement_health_pct: float = 1.0
	var objective_stalled_seasons: int = 0

	# Atonement (s4.6)
	var self_offenses: Array = []

	# State
	var pending_events: Array = []
	var ap_remaining: int = 0
	var action_log: Array = []

	# Personality
	var bushido_virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE
	var shourido_virtue: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE

	# Phoenix-specific governance (s55.10.3.7)
	var phoenix_champion_authority: bool = false

	# Champion conclusion candidates for lord-tier Phase 2 combined pool (s57.54.10b).
	# Populated by day_orchestrator for Family Daimyo and higher.
	# Format: [{"need_type": String, "score": int, "source": String,
	#            "conclusion_type": int, "target_clan_id": int, "is_forced": bool}, ...]
	var champion_conclusion_candidates: Array = []
	# Local Tier 3+ need candidates from known_topics converted to NeedType candidates.
	# Populated by day_orchestrator alongside champion_conclusion_candidates.
	var local_tier3_candidates: Array = []


class ProvinceStatus:
	const CONFIDENCE_STALE: int = 0
	const CONFIDENCE_RECENT: int = 1
	const CONFIDENCE_FRESH: int = 2

	var province_id: int = -1
	var clan: String = ""
	var stability: float = 100.0
	var garrison_pu: int = 0
	var total_settlement_pu: int = 0
	var has_field_army_nearby: bool = false
	var has_alliance_protection: bool = false
	var active_crisis_id: int = -1
	var active_insurgency_id: int = -1
	var insurgency_type: String = ""
	var rice_stockpile: float = 0.0
	var starvation_stage: int = 0
	var last_report_ic_day: int = -1
	var confidence: int = CONFIDENCE_STALE
	var is_wall_province: bool = false
	var crisis_type: String = ""
	var province_taint_level: float = 0.0


class WallStatus:
	var province_id: int = -1
	var si: int = 10
	var ss: int = 0  # Shadowlands Strength (per GDD s2.4.10) — from ProvinceData.shadowlands_strength
	var scout_deployed: bool = false
	var scout_report_age: int = 0
	var max_taint_rank: int = 0
	var tea_stockpile_seasons: float = 2.0
	var jade_stockpile_critical: bool = false
	var scout_report_elevated_activity: bool = false
	var garrison_above_minimum: bool = true
	var minimum_garrison: int = 0
	var garrison_shortage_letter_season: int = -1  # -1 = no letter campaign started
	var garrison_shortage_courtier_dispatched: bool = false
	var garrison_shortage_courtier_refused: bool = false
