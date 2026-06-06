class_name MutationData
extends Resource

@export var mutation_type: Enums.MutationType = Enums.MutationType.NONE
## IC day the mutation manifested. Sentinel -1 = unknown (legacy / world-gen).
@export var ic_day_manifested: int = -1
## Extra Limb only: true when the limb is non-functional (50% chance on gain).
@export var is_non_functional: bool = false
## Distorted Limbs only: "arm" or "leg" (randomly chosen on gain).
@export var affected_limb: String = ""
