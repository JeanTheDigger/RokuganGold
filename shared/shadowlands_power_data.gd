class_name ShadowlandsPowerData
extends Resource

@export var power_type: Enums.ShadowlandsPowerType = Enums.ShadowlandsPowerType.NONE
@export var tier: Enums.ShadowlandsPowerTier = Enums.ShadowlandsPowerTier.MINOR
## IC day the power was acquired. Sentinel -1 = unknown (legacy / world-gen).
@export var ic_day_acquired: int = -1
