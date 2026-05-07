class_name TradeRouteData
extends Resource
## Data model for a trade route connecting two provinces per GDD s4.3.18.


@export var route_id: int = -1
@export var province_a_id: int = -1
@export var province_b_id: int = -1
@export var is_naval: bool = false
@export var is_disrupted: bool = false
@export var disruption_reason: String = ""
@export var koku_bonus_per_season: float = 0.1


func connects(province_id: int) -> bool:
	return province_a_id == province_id or province_b_id == province_id


func other_end(province_id: int) -> int:
	if province_a_id == province_id:
		return province_b_id
	if province_b_id == province_id:
		return province_a_id
	return -1
