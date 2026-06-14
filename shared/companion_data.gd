class_name CompanionData
extends Resource
## Allied NPC companion on the ASCII tactical map (GDD s57.46). One per slot
## (a city-doshin team is a single slot). Serializable; the live grid position,
## rendering, and command-menu input live in the UI/orchestrator layer.

enum CompanionType {
	VILLAGE_DOSHIN,
	CITY_DOSHIN_TEAM,
	DOSHIN_HEADMAN,
	YOJIMBO,
	YORIKI,
	NAMED_ALLY,
}

enum Command {
	FOLLOW,       # default
	HOLD,
	MOVE_TO,
	RETREAT,
	GUARD_EXIT,   # doshin
	IDENTIFY,     # doshin
	SEARCH_AREA,  # doshin
	PROTECT,      # yojimbo
	INVESTIGATE,  # yoriki
}

enum Morale { STEADY, SHAKEN, BROKEN }

@export var companion_id: int = -1
@export var type: CompanionType = CompanionType.NAMED_ALLY
@export var display_name: String = ""
@export var slot: int = -1                     # 1–6
## Linked character sheet for named/samurai companions; -1 for generic doshin.
@export var character_id: int = -1
@export var command: Command = Command.FOLLOW
@export var command_target_tile: Vector2i = Vector2i(-1, -1)  # MOVE_TO / GUARD_EXIT
@export var command_target_id: int = -1        # PROTECT / IDENTIFY target
@export var morale: Morale = Morale.STEADY
@export var team_size: int = 1                 # city doshin team: 2–3
@export var stealth_rank: int = 0              # for noise contribution
@export var yu_rank: int = 0                   # for named/yoriki morale threshold
@export var is_bushi_school: bool = false      # for yoriki morale weighting
@export var home_settlement_id: int = -1       # doshin local knowledge / IDENTIFY
@export var alive: bool = true
