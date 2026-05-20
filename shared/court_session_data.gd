class_name CourtSessionData
extends Resource
## A single court session instance per GDD s15.1 and s15.2.
## Tracks lifecycle, attendees, agenda topics, and commitments made.

enum CourtType {
	IMPERIAL_WINTER_COURT,
	CLAN_CHAMPION_COURT,
	PROVINCIAL_FAMILY_COURT,
	PEACE_COURT,
}

enum CourtPhase {
	SCHEDULED,
	ACTIVE,
	CLOSED,
}

@export var court_id: int = -1
@export var court_type: CourtType = CourtType.PROVINCIAL_FAMILY_COURT
@export var phase: CourtPhase = CourtPhase.SCHEDULED
@export var host_lord_id: int = -1
@export var host_settlement_id: int = -1
@export var host_clan: String = ""
@export var start_ic_day: int = -1
@export var duration_ticks: int = 5
@export var elapsed_ticks: int = 0
@export var attendee_ids: Array[int] = []
@export var agenda_topic_ids: Array[int] = []
@export var crisis_trigger_topic_id: int = -1
@export var emperor_present: bool = false
@export var prestige: int = 1
@export var commitments_made: Array[Dictionary] = []
@export var wars_resolved_during: Array[int] = []
@export var is_regent_court: bool = false
@export var host_family_daimyo_id: int = -1
@export var clan_champion_id: int = -1
@export var grace_period_days: int = 0
@export var no_edicts: bool = false
@export var personal_invitation_ids: Array[int] = []
@export var clan_delegation_ids: Dictionary = {}
@export var announcement_topic_id: int = -1
## Peace court link and accumulated willingness modifiers (PEACE_COURT only).
@export var peace_court_war_id: int = -1
@export var willingness_modifier_clan_a: int = 0
@export var willingness_modifier_clan_b: int = 0
@export var pending_performance_requests: Array[Dictionary] = []
@export var next_request_id: int = 0
## Per-character session state for court action modifiers (s15.4).
## Key: character_id (int). Value: Dictionary with counts and TN reductions.
## Fields per entry: charm_count, negotiate_count, tn_reductions (Dictionary of
## target_id -> int), persuade_tn_reductions (Dictionary of target_id -> int).
@export var session_state: Dictionary = {}
## Active proxy mandates for this court session (s16.2).
@export var proxy_mandates: Array[ProxyMandateData] = []
