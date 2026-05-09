class_name HordeData
extends Resource
## Data model for a generated Jigoku Horde per GDD s2.4.4, s2.4.6, s2.4.7.
## Caller owns all mutation; this is a plain data container.


## Which invasion type this horde is (s2.4.6).
@export var invasion_type: int = Enums.InvasionType.JIGOKU_HORDE

## Province ID of the targeted Wall Tower.
@export var target_province_id: int = -1

## Current Shadowlands Strength counter at time of horde formation.
## Each point adds 1 extra Company to the baseline composition (s2.4.4).
@export var strength_at_formation: int = 0

## Generated companies — each entry is a Dictionary matching the company
## format expected by ArmyCombatSystem (unit_type, base stats, etc.).
## Filled by HordeSystem.generate_horde_companies().
@export var companies: Array[Dictionary] = []

## True when an Oni is present (ONI_LED / ONI_LED_SPAWN).
@export var has_oni: bool = false

## Oni stats if has_oni is true. Null otherwise.
@export var oni_data: OniData = null

## True when the Oni has the Spawn special ability (ONI_LED_SPAWN).
@export var has_spawn: bool = false

## IC day this horde was generated.
@export var ic_day_generated: int = -1

## True once this horde has assaulted a tower and the assault is resolved.
@export var assault_resolved: bool = false

## SI hit applied to the tower after assault resolution (s2.4.5).
@export var assault_si_hit: int = 0
