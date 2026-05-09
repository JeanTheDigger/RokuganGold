class_name EdictData
extends Resource
## An Imperial Edict issued by the Emperor per GDD s15.1, s15.2, s55.10.1.
## Edicts are the only truly binding court outcome.

enum EdictType {
	CEASE_HOSTILITIES,
	CONDEMN_CLAN,
	AUTHORIZE_WAR,
	TAX_REFORM,
	APPOINT_POSITION,
	STRIP_AUTONOMY,
	GENERAL_DECREE,
}

enum ComplianceStatus {
	PENDING,
	COMPLIANT,
	DEFIANT,
}

@export var edict_id: int = -1
@export var edict_type: EdictType = EdictType.GENERAL_DECREE
@export var emperor_id: int = -1
@export var ic_day_issued: int = -1
@export var target_clan: String = ""
@export var target_character_id: int = -1
@export var target_war_id: int = -1
@export var target_topic_id: int = -1
@export var description: String = ""
@export var compliance_by_clan: Dictionary = {}
@export var is_active: bool = true
@export var court_id: int = -1
