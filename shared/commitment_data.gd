class_name CommitmentData
extends Resource
## A social obligation tracked by the Commitment Registry per GDD s55.31.

@export var commitment_id: int = -1
@export var commitment_type: Enums.CommitmentType = Enums.CommitmentType.COURT_ATTENDANCE
@export var source_action_id: String = ""
@export var creditor_npc_id: int = -1
@export var debtor_npc_id: int = -1
@export var deadline_ic_day: int = -1
@export var fulfillment_target: int = -1
@export var tier: int = 3
@export var status: Enums.CommitmentStatus = Enums.CommitmentStatus.PENDING
@export var witnesses: Array[int] = []
@export var created_ic_day: int = -1
@export var advance_notice_sent: bool = false
@export var notice_ic_day: int = -1
@export var proxy_sent: bool = false
@export var proxy_npc_id: int = -1
@export var crisis_id: int = -1
@export var penalty_records: Array[Dictionary] = []
