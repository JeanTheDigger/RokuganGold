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
@export var ic_day_sent: int = 0
@export var ic_day_arrival: int = 0

# State
@export var delivered: bool = false
@export var is_reply: bool = false

# Forgery tracking (populated by SecretSystem covert actions)
@export var is_forged: bool = false
@export var forged_sender_id: int = -1
@export var forgery_tn: int = 0
@export var forgery_detected: bool = false

# Blockade state
@export var blocked_by_blockade: bool = false

# Route info used for delivery time
@export var province_distance: int = 0
@export var mountain_provinces: int = 0
@export var warzone_provinces: int = 0
@export var ocean_segments: int = 0
@export var has_miya_route: bool = false
