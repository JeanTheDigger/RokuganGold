class_name MilitaryUnitData
## Data structures for the military organizational hierarchy per GDD s57.21.
## Five levels: Company → Legion → Section → Army → Clan.


class CompanyData:
	extends Resource
	@export var company_id: int = -1
	@export var parent_legion_id: int = -1
	@export var commander_id: int = -1
	@export var current_location_id: String = ""
	@export var deployment_status: Enums.DeploymentStatus = Enums.DeploymentStatus.WITH_LEGION
	@export var is_reserve: bool = false
	@export var health: int = 100
	@export var attack: int = 0
	@export var defense: int = 0
	@export var morale: int = 100
	@export var morale_defense: int = 0


class LegionData:
	extends Resource
	@export var legion_id: int = -1
	@export var parent_section_id: int = -1
	@export var commander_id: int = -1
	@export var home_province_id: int = -1
	@export var constituent_companies: Array[int] = []


class SectionData:
	extends Resource
	@export var section_id: int = -1
	@export var parent_army_id: int = -1
	@export var commander_id: int = -1
	@export var constituent_legions: Array[int] = []


class ArmyData:
	extends Resource
	@export var army_id: int = -1
	@export var clan_id: String = ""
	@export var commander_id: int = -1
	@export var constituent_sections: Array[int] = []
