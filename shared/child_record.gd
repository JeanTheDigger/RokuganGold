class_name ChildRecord
extends Resource
## Lightweight pre-gempukku child record per GDD s52 Trigger 2.
## Children exist as placeholders until age 18 IC years (6480 IC days),
## at which point the engine runs the full generation template and
## produces a complete Rank 1 L5RCharacterData.
##
## Fields are the complete list from GDD s52: Name, Father, Mother,
## Date of Birth, Clan, Family, Gender, Orientation, Status.
## No other fields exist until gempukku.

@export var child_id: int = -1
@export var child_name: String = ""
@export var father_id: int = -1
@export var mother_id: int = -1
@export var clan: String = ""
@export var family: String = ""
@export var gender: String = ""
@export var orientation: String = "straight"
@export var ic_day_born: int = -1
@export var is_alive: bool = true

const GEMPUKKU_AGE_DAYS: int = 6480  # 18 IC years × 360 days/year


func get_age_days(current_ic_day: int) -> int:
	if ic_day_born < 0:
		return 0
	return current_ic_day - ic_day_born


func is_gempukku_ready(current_ic_day: int) -> bool:
	if not is_alive:
		return false
	return get_age_days(current_ic_day) >= GEMPUKKU_AGE_DAYS
