class_name AdvantageData
extends Resource
## Per-entry record for one Advantage from GDD s45.
## Stored in L5RCharacterData.advantages.

@export var advantage_type: Enums.Advantage = Enums.Advantage.NONE
## Point rank of this advantage (used for multi-rank entries such as ALLIES,
## WELL_CONNECTED, MAGIC_RESISTANCE, GENTRY, WEALTHY, etc.).
@export var rank: int = 1
## Entry-specific data. Keys vary by advantage_type — see AdvantageSystem.
## Common keys: "ring" (Enums.Ring), "element" (Enums.Ring), "clan" (String),
## "virtue" (String), "precept" (String), "realm" (String), "fortune" (String),
## "skill" (String), "settlement_id" (int), "target_id" (int),
## "skills" (Array[String]), "focus_type" (String), "focus_id" (int).
@export var metadata: Dictionary = {}
