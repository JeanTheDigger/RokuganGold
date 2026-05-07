class_name ClanData
extends Resource
## Clan-level data per GDD s4.3.10. Iron and Arms pool at clan level.


@export var clan_name: String = ""
@export var iron_stockpile: float = 0.0
@export var arms_stockpile: float = 0.0
@export var champion_id: int = -1
@export var province_ids: Array[int] = []
