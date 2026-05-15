class_name CourtCommitmentData
extends Resource
## A court-declared or edict-compelled commitment per GDD s16.4.
## Distinct from CommitmentData (s55.31) — this tracks promises made at court
## or imposed by Imperial Edict, fulfilled through the NPC Decision Engine.

enum CommitmentSource { VOLUNTARY, EDICT }

@export var lord_id: int = -1
@export var topic_id: int = -1
@export var commitment_type: String = ""
@export var resource_amount: int = -1
@export var source: CommitmentSource = CommitmentSource.VOLUNTARY
@export var declared_at_ic_day: int = -1
@export var deadline_ic_day: int = -1
@export var fulfilled: bool = false
@export var good_faith: bool = true
@export var ap_spent_toward: int = 0
@export var witness_ids: Array[int] = []
