class_name LegalCaseEntry
extends Resource
## Per-suspect legal case entry per GDD s11.3.14d.
## Tracks one character's relationship to one world-level CrimeRecord.
## Evidence accumulates per suspect — two suspects for the same crime
## may have different evidence totals.


@export var crime_record_id: int = -1
@export var state: Enums.LegalStatus = Enums.LegalStatus.CLEAR
@export var evidence_total: int = 0
@export var evidence_items: Array[Dictionary] = []
@export var accusation_timestamp: int = -1
@export var verdict_timestamp: int = -1
