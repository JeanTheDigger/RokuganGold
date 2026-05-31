class_name GardenData
extends Resource
## World object for a garden per GDD s57.23.
## Gardens occupy a zone slot at a settlement (CASTLE_OUTER_COURTYARD or TSUBONIWA),
## are cultivated over multiple seasons, and generate visitor disposition bonuses.
## Zone slots are proxied at settlement level until the coordinate/zone system (s4.4) exists.

@export var garden_id: int = -1

## Zone type: "CASTLE_OUTER_COURTYARD" or "TSUBONIWA"
@export var zone_type: String = ""

@export var settlement_id: int = -1
@export var creator_id: int = -1

## Quality tier at completion (1=Normal, 2=Fine, 3=Exceptional, 4=Masterwork, 5=Legendary).
## Set at creation from the target_quality_tier of the CommissionRecord.
@export var quality_tier: int = 1

## Current tier — may degrade below quality_tier through failed maintenance.
@export var current_tier: int = 1

## IC day of installation (when commission completed).
@export var installation_date: int = -1

## IC season of last successful MAINTAIN_GARDEN. -1 = never maintained.
@export var last_maintained_season: int = -1

## Raises used at the final CULTIVATE_GARDEN roll that completed the garden.
## Determines permanent quality upgrade above base tier (s57.23.5, A3).
@export var completion_raises: int = 0

## Visitor count since the last Glory tick. Resets to 0 after each 5-visitor tick.
@export var visitor_count_since_last_tick: int = 0

## IC season of the last Glory tick. -1 = never ticked.
@export var last_glory_tick_season: int = -1

## ID of the CommissionRecordData that produced this garden. -1 = uncommissioned.
@export var commission_record_id: int = -1

## True when the garden has been destroyed (neglect, forced removal, voluntary removal).
@export var destroyed: bool = false

## IC day of destruction. -1 if not destroyed.
@export var destruction_date: int = -1

## Reason for destruction. One of: "NEGLECT", "MAINTENANCE_FAILURE",
## "FORCED_REMOVAL", "VOLUNTARY_REMOVAL".
@export var destruction_cause: String = ""

## Visitor memory for disposition bonus tracking and destruction topic propagation.
## Each entry: {"character_id": int, "visit_date": int}
## Bounded to 200 entries; entries older than 1800 IC days are purged.
@export var visitor_memory: Array = []
