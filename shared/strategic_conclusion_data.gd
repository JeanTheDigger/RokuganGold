class_name StrategicConclusionData
extends Resource
## Strategic Conclusion data schema per GDD s57.54.4.
## Produced by Clan Champion seasonal evaluation and stored on ClanData.


enum ConclusionType {
	AGGRESSIVE_POSTURE,
	LAUNCH_OFFENSIVE,
	SUPPRESS_INSTABILITY,
	SUPPORT_SHADOWLANDS,
	DEFEND_TERRITORY,
	PURSUE_ALLIANCE,
	SEEK_PEACE,
	UNDERMINE_POSITION,
	STRENGTHEN_COURT,
	COMPLY_EDICT,
	SECURE_RESOURCE,
	DEVELOP_INFRASTRUCTURE,
	RECOVER_DAMAGE,
	RESTORE_WORSHIP,
	RESPOND_SPIRITUAL_CRISIS,
	BUILD_CULTURAL_PRESTIGE,
}

enum Domain {
	MILITARY,
	DIPLOMATIC,
	ECONOMIC,
	SPIRITUAL,
	SOCIAL,
}

enum WarObjective {
	NONE = -1,
	CONQUER,
	HUMILIATE,
	DESTROY,
	PUNISH,
}


@export var conclusion_id: int = -1
@export var conclusion_type: ConclusionType = ConclusionType.SUPPRESS_INSTABILITY
@export var domain: Domain = Domain.MILITARY
# Required for: AGGRESSIVE_POSTURE, LAUNCH_OFFENSIVE, DEFEND_TERRITORY,
# PURSUE_ALLIANCE, SEEK_PEACE, UNDERMINE_POSITION. Null (-1) for others.
@export var target_clan_id: int = -1
# Only for LAUNCH_OFFENSIVE.
@export var war_objective: WarObjective = WarObjective.NONE
# province_id for CONQUER, target_id for DESTROY, topic_id for PUNISH; -1 otherwise.
@export var war_objective_target: int = -1
# Only for COMPLY_EDICT.
@export var edict_id: int = -1
@export var score: int = 0
@export var source_topic_ids: Array = []
@export var is_forced: bool = false
@export var is_continuation: bool = false
@export var season_originated: int = -1
