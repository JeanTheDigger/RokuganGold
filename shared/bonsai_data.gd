class_name BonsaiData
extends Resource
## World object for a bonsai specimen per GDD s57.24.
## Bonsai are collected from provinces, tended monthly, and optionally displayed
## at eligible settlements to provide visitor disposition bonuses.

@export var bonsai_id: int = -1
@export var owner_id: int = -1

## Species name — cosmetic only, no mechanical significance.
@export var species: String = ""

## Province where the specimen was collected. -1 for world-generated bonsai.
@export var collection_province_id: int = -1

## IC day of collection (or world-gen date for pre-existing bonsai).
@export var collection_date: int = -1

## Quality tier: 0=Mundane (pre-death), 1=Normal, 2=Fine, 3=Exceptional,
## 4=Masterwork, 5=Legendary.
@export var quality_tier: int = 1

## Accumulated quality points toward the next tier threshold (s57.24.6 B3).
@export var quality_points: int = 0

## IC month of last successful TEND_BONSAI. -1 = never tended.
@export var last_tended_month: int = -1

## Number of consecutive missed tending months (s57.24.7 B4).
## 1 = warning state, 2 = degradation, 3 at Mundane = death.
@export var consecutive_missed_months: int = 0

## Settlement ID where the bonsai is currently displayed. -1 = not displayed.
@export var display_settlement_id: int = -1

## True when the bonsai has died from neglect (s57.24.7 B4).
@export var is_dead: bool = false

## True for bonsai created during world generation rather than collected by a PC/NPC.
@export var world_generated: bool = false

## Ownership history for provenance tracking.
## Each entry: {"owner_id": int, "acquired_date": int, "relinquished_date": int}
@export var provenance_history: Array = []
