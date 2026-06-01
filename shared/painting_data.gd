class_name PaintingData
extends Resource
## World object for a painting per GDD s57.27.
## craft_progress = -1 means complete or canonized.
## craft_progress >= 0 means composition in progress.
## Zone slots proxied at settlement level until coordinate system (s4.4) exists.

@export var painting_id: int = -1
@export var format: int = 0       # PaintingSystem.Format enum
@export var creator_id: int = -1  # -1 for ancient/unknown works
@export var quality_tier: int = 1  # 1=Normal..5=Legendary
@export var style: int = 2         # PaintingSystem.Style enum (NONE=2)
@export var subject_type: int = 1  # PaintingSystem.SubjectType enum

## subject_id = character_id (portrait/battle), fortune_id (religious),
## clan_id (clan), family_id (clan), topic_id (battle topic link), or -1 (none).
@export var subject_id: int = -1

@export var subject_description: String = ""
@export var framing: bool = true      # true = positive, false = negative
@export var season_affinity: int = -1  # Enums.Season value or -1 for none

## topic_ids carried by this painting (max 2 — emakimono primary user).
@export var topic_ids: Array[int] = []

## IC day composition completed. -1 = not yet complete.
@export var date_completed: int = -1

## craft_progress: -1 = complete. >= 0 = in-progress point accumulation.
@export var craft_progress: int = -1

## Parameters declared at composition start (cannot change mid-composition).
@export var target_quality_tier: int = 1
@export var target_topic_ids: Array[int] = []  # for emakimono with topic link at start

## Display location (settlement proxy for zone).
@export var display_settlement_id: int = -1

## Which slot this occupies: -1=none, or PaintingSystem.DisplaySlot enum value.
@export var display_slot: int = -1

## Emakimono provenance.
@export var copy_of: int = -1    # painting_id this was copied from, -1 = original
@export var is_original: bool = true
@export var generation: int = 0  # 0 for originals, +1 per copy step

## Visitor tracking for Glory ticks.
@export var visitor_count_since_last_tick: int = 0
@export var last_glory_tick_ic_season: int = -1

## Visitor memory: Array of {"char_id": int, "last_visit_ic_day": int}.
## Capped at 200; entries older than 1800 IC days purged.
@export var visitor_memory: Array = []

## IC day when this painting was placed in its current slot (for familiarity decay).
@export var continuous_display_start_ic_day: int = -1

## IC day last composition AP was spent (for byōbu/emakimono degradation check).
@export var ic_day_last_composition_ap: int = -1

## Lifecycle flags.
@export var abandoned_incomplete: bool = false
@export var commission_record_id: int = -1  # -1 = not commissioned through pipeline
