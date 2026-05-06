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

	# Eight scoring components per s55.4 Phase 5
	var objective_alignment: float = 0.0
	var disposition_modifier: float = 0.0
	var personality_lean: float = 0.0
	var competence_modifier: float = 0.0
	var urgency_bonus: float = 0.0
	var standing_influence: float = 0.0
	var topic_position_modifier: float = 0.0
	var resource_modifier: float = 0.0

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
		)


class ContextSnapshot:
	# Identity
	var character_id: int = -1
	var character_name: String = ""
	var clan: String = ""
	var family: String = ""
	var school_type: Enums.SchoolType = Enums.SchoolType.BUSHI
	var is_lord: bool = false

	# Location & situation
	var location_id: String = ""
	var context_flag: Enums.ContextFlag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var season: int = 0
	var ic_day: int = 0

	# Stats
	var skill_ranks: Dictionary = {}
	var honor: float = 0.0
	var glory: float = 0.0
	var status: float = 0.0
	var insight_rank: int = 1

	# Social knowledge
	var characters_present: Array[int] = []
	var dispositions: Dictionary = {}
	var known_topics: Array[int] = []
	var known_positions: Dictionary = {}
	var known_objectives: Dictionary = {}
	var known_contacts: Array[int] = []
	var contact_clans: Dictionary = {}
	var met_characters: Array[int] = []

	# Lord-tier fields
	var resource_stockpiles: Dictionary = {}
	var province_statuses: Array = []

	# State
	var pending_events: Array = []
	var ap_remaining: int = 0
	var action_log: Array[Dictionary] = []

	# Personality
	var bushido_virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE
	var shourido_virtue: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE


class ProvinceStatus:
	var province_id: int = -1
	var stability: float = 100.0
	var garrison_pu: int = 0
	var active_crisis_id: int = -1
	var active_insurgency_id: int = -1
	var rice_stockpile: float = 0.0
	var last_report_ic_day: int = -1
	var confidence: int = 0  # 0=stale, 1=recent, 2=fresh


# -- Competence Modifier Table (s55.5) -----------------------------------------

const COMPETENCE_TABLE: Dictionary = {
	0: -20,
	1: -10,
	2: -5,
	3: 0,
	4: 5,
	5: 10,
	6: 15,
	7: 20,
}

static func get_competence_modifier(skill_rank: int) -> int:
	if skill_rank >= 7:
		return 20
	if COMPETENCE_TABLE.has(skill_rank):
		return COMPETENCE_TABLE[skill_rank]
	return -20
