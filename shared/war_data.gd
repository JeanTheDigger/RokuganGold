class_name WarData
extends Resource
## Formal War Status tracking per GDD s53.


enum AuthorityLevel {
	PROVINCIAL_RAID,
	BORDER_CONFLICT,
	FAMILY_WAR,
	CLAN_WAR,
}

enum WarScoreTier {
	DESPERATE,
	LOSING,
	BEHIND,
	AHEAD,
	WINNING,
	DOMINANT,
}


@export var war_id: int = -1
@export var clan_a: String = ""
@export var clan_b: String = ""
@export var authority_level: AuthorityLevel = AuthorityLevel.PROVINCIAL_RAID
@export var war_score_a: int = 50
@export var war_score_b: int = 50
@export var initiator_clan: String = ""
@export var declaring_lord_id: int = -1
@export var target_lord_id: int = -1
@export var ic_day_started: int = -1
@export var seasons_active: int = 0
@export var is_active: bool = true
@export var resolution_type: String = ""
@export var allied_clans_a: Array[String] = []
@export var allied_clans_b: Array[String] = []
@export var provinces_captured_by_a: Array[int] = []
@export var provinces_captured_by_b: Array[int] = []
