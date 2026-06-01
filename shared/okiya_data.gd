class_name OkiyaData
extends Resource
## Data model for a single okiya (geisha house) per GDD s57.45.

@export var okiya_id: int = -1
## settlement_id stored as String to match physical_location convention.
@export var settlement_id: String = ""
## Quality tier: 1=Provincial, 2=Established, 3=Famous (s57.45.3, locked s57.45a A1–A3).
@export var tier: int = 1
@export var is_scorpion_controlled: bool = false
## NPC ID of the house mistress. -1 if not yet assigned.
@export var okaasan_id: int = -1
## NPC IDs of resident geisha. Empty if none generated.
@export var geisha_ids: Array[int] = []
## Bayushi handler NPC ID. -1 if Independent okiya.
@export var handler_id: int = -1
## Kolat Silk embedded agent NPC ID. -1 if none.
@export var kolat_agent_id: int = -1
@export var is_active: bool = true
