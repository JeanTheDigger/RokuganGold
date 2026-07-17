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
@export var start_tick: int = -1
@export var ticks_elapsed: int = 0
# s22.5 transition duration (LOCKED via SuccessionSystem.get_transition_duration): clean +
# confirming-authority disp>=31 -> 7 / clean low-disp -> 14 / disputed -> 60 ticks. Stamped at
# creation (where is_clean + confirming_disp are in scope) so the tick loop uses the canonical
# arbiter's value instead of a divergent inline copy. -1 = unset -> tick loop falls back.
@export var transition_max_ticks: int = -1
@export var successor_id: int = -1
@export var designated_heir_id: int = -1
@export var candidate_ids: Array = []
@export var contesting_ids: Array = []
@export var suspicious_death: bool = false
@export var settlement_id: String = ""
