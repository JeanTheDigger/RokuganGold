class_name ConstructionData
extends Resource

enum ConstructionType {
	VILLAGE,
	FORTIFICATION,
	SHRINE_ROADSIDE,
	SHRINE_VILLAGE,
	SHRINE_LOCAL,
	TEMPLE,
	SHINDEN,
	MONASTERY,
	SHIP,
}

@export var construction_id: int = -1
@export var construction_type: ConstructionType = ConstructionType.VILLAGE
@export var ordering_lord_id: int = -1
@export var province_id: int = -1
@export var settlement_id: int = -1  # target settlement for shrine, -1 for new settlements
@export var koku_committed: float = 0.0
@export var pu_committed: float = 0.0
@export var rice_committed: float = 0.0
@export var seasons_remaining: int = 1
@export var seasons_total: int = 1
@export var ic_day_started: int = -1
@export var is_dedicated: bool = false
@export var dedicated_fortune: int = -1  # GreatFortune enum, -1 if general
@export var ship_class: int = -1  # ShipClass enum, -1 if not a ship
@export var is_complete: bool = false
