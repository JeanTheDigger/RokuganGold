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
@export var season_spawned: int = -1
@export var spread_from_id: int = -1

# s56.13 Relocation Mechanics fields
@export var missions_conducted: int = 0  # missions fired against this insurgency in current province; reset on province change
@export var relocation_delay_remaining: int = 0  # seasons until relocation allowed (Makeshift Stockade delay)
@export var template_type: String = ""  # class_name of last map template used (for restriction checks)
