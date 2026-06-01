class_name ClanData
extends Resource
## Clan-level data per GDD s4.3.10. Iron and Arms pool at clan level.


@export var clan_name: String = ""
@export var iron_stockpile: float = 0.0
@export var arms_stockpile: float = 0.0
@export var champion_id: int = -1
@export var province_ids: Array = []
# Strategic conclusions broadcast by Clan Champion per GDD s57.54.4.
# Persists between seasonal reviews until replaced. Empty = no Champion direction.
@export var clan_strategic_priorities: Array[StrategicConclusionData] = []
# Per-clan counter for assigning unique conclusion_ids. Auto-increments each evaluation.
@export var next_conclusion_id: int = 0
