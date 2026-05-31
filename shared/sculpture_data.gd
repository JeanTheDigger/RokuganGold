class_name SculptureData
extends Resource
## World object for a sculpture per GDD s57.28.
## craft_progress = -1 means complete.
## craft_progress >= 0 means composition in progress.
## Zone slots proxied at settlement level until coordinate system (s4.4) exists.

@export var sculpture_id: int = -1

## SculptureSystem.Format enum: STATUARY=0, GUARDIAN=1, FIGURINE=2
@export var format: int = 0

@export var creator_id: int = -1  # -1 for ancient/unknown works

## 1=Normal..5=Legendary
@export var quality_tier: int = 1

## SculptureSystem.Material enum: WOOD=0, STONE=1, BRONZE=2
@export var material: int = 0

## SculptureSystem.SubjectType enum
@export var subject_type: int = 0

## fortune_id, character_id, creature_type index, or -1 (none)
@export var subject_id: int = -1

@export var subject_description: String = ""

## IC day composition completed. -1 = not yet complete.
@export var date_completed: int = -1

## craft_progress: -1 = complete. >= 0 = in-progress point accumulation.
@export var craft_progress: int = -1

## Parameters declared at composition start (cannot change mid-composition).
@export var target_quality_tier: int = 1
@export var target_format: int = 0

## Display location (settlement proxy for zone).
## For figurines: -1 means in inventory (not placed). Set on DELIVER_GIFT writeback.
@export var display_settlement_id: int = -1

## Which slot: -1=none, 0=statue_slot, 1=guardian_slot
@export var display_slot: int = -1

## Guardian pair fields (format == GUARDIAN only).
## paired: always true for guardian statues; false otherwise.
@export var paired: bool = false
## pair_intact: both statues exist and the ward is active.
@export var pair_intact: bool = false

## Figurine theme field (format == FIGURINE).
## SculptureSystem.FigurineTheme enum
@export var theme: int = 4  # OTHER=4

## Visitor tracking for Glory ticks (same pattern as PaintingData).
@export var visitor_count_since_last_tick: int = 0
@export var last_glory_tick_ic_season: int = -1

## Visitor memory: Array of {"char_id": int, "last_visit_ic_day": int}.
@export var visitor_memory: Array = []

## IC day last composition AP was spent (for degradation check).
@export var ic_day_last_composition_ap: int = -1

## Wood guardian outdoor degradation tracking.
## IC day this statue was placed outdoors. -1 = indoors or not applicable.
@export var ic_day_placed_outdoor: int = -1

## Lifecycle flags.
@export var abandoned_incomplete: bool = false
@export var commission_record_id: int = -1
