class_name LetterData
extends Resource
## A single letter in transit or delivered. Per GDD s12.7.

@export var letter_id: int = -1
@export var sender_id: int = -1
@export var recipient_id: int = -1

# Topic carried
@export var topic: int = -1

# Calligraphy roll outcome — 0=fail, 1=success(+1), 2=one raise(+2), 3=two raises(+3)
@export var quality: int = 0

# Computed disposition bonus that fires on arrival
@export var disposition_bonus: int = 0

# Timing
@export var ic_day_sent: int = -1
@export var ic_day_arrival: int = -1

# State
@export var delivered: bool = false
@export var is_reply: bool = false

# Forgery tracking (populated by SecretSystem covert actions)
@export var is_forged: bool = false
@export var forged_sender_id: int = -1
@export var forgery_tn: int = 0
@export var forgery_detected: bool = false
@export var is_order: bool = false
@export var order_applied: bool = false
@export var order_need_type: String = ""
@export var order_target_province_id: int = -1
@export var order_target_npc_id: int = -1
@export var order_target_settlement_id: int = -1
@export var reply_to_forged: bool = false
@export var original_forger_id: int = -1

# Witness report (populated by reactive WRITE_LETTER for witness_report_motivated)
@export var report_case_id: int = -1
@export var report_criminal_id: int = -1

# Commitment intent flags (s55.31 — commitment creation triggers)
@export var visit_intent: bool = false
@export var visit_deadline_ic_day: int = -1
@export var meeting_proposal: bool = false
@export var meeting_settlement_id: int = -1
@export var meeting_deadline_ic_day: int = -1

# Blockade state
@export var blocked_by_blockade: bool = false

# Teaching offer flags (populated by §57.22.12 proactive teaching trigger)
@export var learn_piece_id: int = -1
@export var teacher_initiated: bool = false

# Calligraphy (Cipher) subtext fields — s57.30 LOCKED
# Concealment TN = result of writer's Sincerity/Awareness roll at write time.
# Disposition tier and topic stance are frozen snapshots of the writer's state.
@export var concealment_tn: int = 0
@export var writer_disposition_tier: int = -1  # DispositionTier enum; -1 = unknown
@export var writer_topic_stance: String = ""   # "supports" / "opposes" / "indifferent" / ""
@export var writer_needtype: String = ""        # NeedType driving the letter; "" for players

# Calligraphy (High Rokugani) fields — s57.30 LOCKED
@export var high_rokugani_attempted: bool = false
@export var high_rokugani_bonus: int = 0

# Route info used for delivery time
@export var province_distance: int = 0
@export var mountain_provinces: int = 0
@export var warzone_provinces: int = 0
@export var ocean_segments: int = 0
@export var has_miya_route: bool = false
