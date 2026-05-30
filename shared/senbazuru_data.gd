class_name SenbazuruData
extends Resource
## World object for a thousand-crane devotional project per GDD s57.26.14–57.26.17.
## state: "active" (in progress), "presented" (complete and presented), "creator_deceased".
## craft_progress tracks whether crane_count < 1000 (not complete) or >= 1000 (complete).

@export var senbazuru_id: int = -1
@export var folder_id: int = -1  # character_id of the folder

## Dedication types (s57.26.14): "Healing", "Protection", "Remembrance", "Atonement"
@export var dedication_type: String = ""

## -1 for Atonement (no recipient). May become -1 if recipient dies after a Healing/Protection
## dedication shifts to Remembrance (original recipient_id is retained for topic text).
@export var recipient_id: int = -1

@export var crane_count: int = 0          # 0 to 1000
@export var total_raises: int = 0         # cumulative Raises across successful sessions
@export var successful_session_count: int = 0

@export var declaration_date: int = -1    # ic_day of declaration
@export var is_complete: bool = false     # true when crane_count >= 1000
@export var completion_date: int = -1     # ic_day, -1 until complete
@export var presentation_date: int = -1  # ic_day, -1 until presented

## "active", "presented", "creator_deceased"
@export var state: String = "active"

## Quality tier at completion (GiftGivingSystem.QualityTier: NORMAL=1..LEGENDARY=5).
## Computed at completion time; -1 until complete.
@export var quality_tier: int = -1


static func compute_quality(total_r: int, session_count: int) -> int:
	## Compute quality tier from average raises (s57.26.16). Returns GiftGivingSystem.QualityTier.
	## Fractional averages round down.
	if session_count <= 0:
		return GiftGivingSystem.QualityTier.NORMAL  # 1
	var avg: int = total_r / session_count
	match avg:
		0:
			return GiftGivingSystem.QualityTier.NORMAL      # 1
		1:
			return GiftGivingSystem.QualityTier.FINE        # 2
		2:
			return GiftGivingSystem.QualityTier.EXCEPTIONAL  # 3
		3:
			return GiftGivingSystem.QualityTier.MASTERWORK   # 4
		_:
			return GiftGivingSystem.QualityTier.LEGENDARY    # 5
