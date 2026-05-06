class_name TattooData
extends Resource
## Tattoo world object per GDD s57.25.2.
## One tattoo per body part per character.


@export var tattoo_id: int = -1
@export var recipient_id: int = -1
@export var artist_id: int = -1
@export var quality_tier: Enums.TattooQualityTier = Enums.TattooQualityTier.NORMAL
@export var body_location: Enums.TattooBodyLocation = Enums.TattooBodyLocation.LEFT_WRIST_FOREARM
@export var subject_type: Enums.TattooSubjectType = Enums.TattooSubjectType.IMAGE
@export var subject_description: String = ""
@export var topic_id: int = -1
@export var is_ability_tattoo: bool = false
@export var ability_granted: Enums.TattooAbility = Enums.TattooAbility.NONE
@export var date_applied: int = -1
@export var is_visible: bool = false
