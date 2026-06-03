class_name DisadvantageData
extends Resource
## Per-entry record for one Disadvantage from GDD s45.
## Stored in L5RCharacterData.disadvantages.

@export var disadvantage_type: Enums.Disadvantage = Enums.Disadvantage.NONE
## Point rank (used for multi-rank entries such as ANTISOCIAL, BOUNTY,
## COMPULSION, PHOBIA, MAGIC_RESISTANCE-equivalent cursed variants, etc.).
@export var rank: int = 1
## Entry-specific data. Keys vary by disadvantage_type — see AdvantageSystem.
## Common keys: "subject" (String), "location_tags" (Array[String]),
## "situation_tags" (Array[String]), "element" (Enums.Ring), "virtue" (String),
## "realm" (String), "fortune" (String), "skill" (String), "trait" (Enums.Trait),
## "target_id" (int), "enemy_id" (int), "fortune_type" (String),
## "trigger_ic_day" (int), "prank_pool_used" (Array[int]).
@export var metadata: Dictionary = {}
