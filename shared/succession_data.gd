class_name SuccessionData
extends Resource

enum SuccessionState {
	PENDING,
	DISPUTED,
	CONFIRMED,
	RESOLVED,
}

enum VacancyCause {
	DEATH,
	RETIREMENT,
	EXILE,
	REMOVAL,
}

@export var succession_id: int = -1
@export var deceased_id: int = -1
@export var position_tier: Enums.LordRank = Enums.LordRank.VILLAGE_HEADMAN
@export var clan: String = ""
@export var family: String = ""
@export var confirming_authority_id: int = -1
@export var state: SuccessionState = SuccessionState.PENDING
@export var cause: VacancyCause = VacancyCause.DEATH
@export var start_tick: int = 0
@export var ticks_elapsed: int = 0
@export var successor_id: int = -1
@export var designated_heir_id: int = -1
@export var candidate_ids: Array[int] = []
@export var contesting_ids: Array[int] = []
@export var suspicious_death: bool = false
@export var settlement_id: String = ""
