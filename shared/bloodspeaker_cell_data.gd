class_name BloodspeakerCellData
extends Resource
## Data model for a single Bloodspeaker cult cell per GDD s56.14.


@export var cell_id: int = -1
@export var province_id: int = -1
@export var state: Enums.BloodspeakerCellState = Enums.BloodspeakerCellState.DORMANT
@export var strength: int = 1
@export var concealment: int = 8
@export var leader_id: int = -1
@export var parent_cell_id: int = -1
@export var establishment_path: Enums.CellEstablishmentPath = Enums.CellEstablishmentPath.AGENT_INFILTRATION
@export var season_created: int = -1
@export var seasons_dormant: int = 0
@export var seasons_active: int = 0
@export var insurgency_id: int = -1
@export var propagation_count: int = 0
