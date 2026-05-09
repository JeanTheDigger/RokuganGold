class_name CourtSessionData
extends Resource
## A single court session instance per GDD s15.1 and s15.2.
## Tracks lifecycle, attendees, agenda topics, and commitments made.

enum CourtType {
	IMPERIAL_WINTER_COURT,
	CLAN_CHAMPION_COURT,
	PROVINCIAL_FAMILY_COURT,
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
