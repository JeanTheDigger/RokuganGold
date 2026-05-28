class_name ArtisanItemData
extends Resource
## Crafted item data per GDD s49.
## Tracks provenance, quality, materials, history, and special qualities.


@export var item_id: int = -1
@export var item_name: String = ""
@export var category: Enums.CraftingCategory = Enums.CraftingCategory.EQUIPMENT
@export var track: Enums.CraftingTrack = Enums.CraftingTrack.CRAFT
@export var skill_used: String = ""

# -- Quality ------------------------------------------------------------------

@export var quality_tier: GiftGivingSystem.QualityTier = GiftGivingSystem.QualityTier.NORMAL

# -- Provenance (creation record) ---------------------------------------------

@export var creator_id: int = -1
@export var creator_clan: String = ""
@export var creator_family: String = ""
@export var creator_school: String = ""
@export var creator_insight_rank: int = 0
@export var creation_ic_day: int = -1
@export var creation_province_id: int = -1

# -- Materials ----------------------------------------------------------------

@export var material_tier: Enums.MaterialTier = Enums.MaterialTier.COMMON
@export var material_name: String = ""
@export var material_origin_province_id: int = -1
@export var material_cost_koku: float = 0.0

# -- Weapon-specific fields ---------------------------------------------------

@export var is_exceptional_weapon: bool = false
@export var is_sacred_weapon: bool = false
@export var special_qualities: Array[Enums.WeaponSpecialQuality] = []
@export var sacred_weapon_clan: String = ""

# -- Artisan-specific fields --------------------------------------------------

@export var subject_description: String = ""

# -- History accumulation -----------------------------------------------------

@export var history_points: int = 0
@export var history_events: Array[Dictionary] = []
@export var current_owner_id: int = -1

# -- Item economics -----------------------------------------------------------

@export var base_cost_koku: float = 0.0
@export var cost_denomination: String = "bu"

# -- Crafting progress (multi-day crafting) -----------------------------------

@export var crafting_ap_required: int = 1
@export var crafting_ap_invested: int = 0
@export var is_complete: bool = false
@export var crafting_roll_total: int = 0


func get_free_raises_from_quality() -> int:
	return GiftGivingSystem.QUALITY_FREE_RAISES.get(quality_tier, 0)


func get_history_tier_bonus() -> int:
	if history_points >= 10:
		return 3
	if history_points >= 6:
		return 2
	if history_points >= 3:
		return 1
	return 0


func get_total_free_raises() -> int:
	return get_free_raises_from_quality() + get_history_tier_bonus()


func add_history_event(event_type: Enums.HistoryEventType, ic_day: int, description: String = "") -> bool:
	for evt: Dictionary in history_events:
		if evt.get("type") == event_type and evt.get("description") == description:
			return false
	var points: int = _history_points_for_type(event_type)
	history_events.append({
		"type": event_type,
		"ic_day": ic_day,
		"description": description,
	})
	history_points += points
	return true


static func _history_points_for_type(event_type: Enums.HistoryEventType) -> int:
	match event_type:
		Enums.HistoryEventType.OWNED_RANK_3:
			return 1
		Enums.HistoryEventType.OWNED_RANK_5:
			return 2
		Enums.HistoryEventType.OWNED_CHAMPION:
			return 3
		Enums.HistoryEventType.USED_IN_BATTLE:
			return 1
		Enums.HistoryEventType.GIFTED_AT_COURT:
			return 1
		Enums.HistoryEventType.SUBJECT_OF_ART:
			return 1
		Enums.HistoryEventType.PRESENT_AT_EVENT:
			return 2
	return 0
