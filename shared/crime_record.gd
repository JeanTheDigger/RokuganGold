class_name CrimeRecord
extends Resource
## A single crime event in the world. The system always knows who committed
## the crime — investigation is players/NPCs discovering what the system knows.
## Per GDD s57.47: CrimeRecord exists at world level.

@export var case_id: int = -1
@export var crime_type: Enums.CrimeType = Enums.CrimeType.OTHER
@export var severity: Enums.CrimeSeverity = Enums.CrimeSeverity.MINOR
@export var perpetrator_id: int = -1
@export var victim_id: int = -1
@export var location: String = ""
@export var ic_day_committed: int = -1
@export var legal_status: Enums.LegalStatus = Enums.LegalStatus.NONE
@export var concealment_tn: int = 0
@export var evidence_total: int = 0
@export var investigating_magistrate_id: int = -1
@export var ic_day_conviction: int = -1
@export var seppuku_offered: bool = false
@export var seppuku_accepted: bool = false
@export var witnesses: Array[int] = []
@export var known_suspects: Array[int] = []
@export var escalation_count: int = 0
@export var skimming_amount: float = 0.0
@export var commissioner_id: int = -1
