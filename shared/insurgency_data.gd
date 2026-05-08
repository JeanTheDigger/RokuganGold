class_name InsurgencyData
extends Resource
## Data model for a province-level insurgency per GDD s11.11.


@export var insurgency_id: int = -1
@export var insurgency_type: Enums.InsurgencyType = Enums.InsurgencyType.MAHO_CULT
@export var province_id: int = -1
@export var settlement_id: int = -1
@export var strength: int = 1
@export var concealment: int = 5
@export var detected: bool = false
@export var seasons_active: int = 0
@export var season_spawned: int = 0
@export var spread_from_id: int = -1
