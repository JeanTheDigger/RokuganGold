class_name ShipData
extends Resource
## Data model for a ship per GDD s11.9.
## Caller owns all mutation; this is a plain data container.


@export var ship_id: int = -1

## ShipClass enum value.
@export var ship_class: int = Enums.ShipClass.KOBUNE

## Owning clan name (e.g. "Mantis", "Crab", "Tortoise").
@export var owning_clan: String = ""

## Character ID of the current captain (-1 = no captain).
@export var captain_id: int = -1

## Province ID where this ship is currently located.
@export var current_province_id: int = -1

## Current sub-tile ID (-1 = docked at settlement).
@export var current_subtile_id: int = -1

## Ship name per lore naming convention.
@export var ship_name: String = ""

## Combat stats — initialized from NavalSystem.SHIP_STATS.
@export var health: int = 0
@export var max_health: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var morale: int = 0
@export var morale_defense: int = 0

## Whether this ship is currently destroyed or captured.
@export var is_destroyed: bool = false
@export var is_captured: bool = false
@export var captured_by_clan: String = ""

## Movement state.
@export var is_moving: bool = false
@export var destination_subtile_id: int = -1
@export var movement_days_remaining: int = 0

## Construction cost in koku.
@export var construction_cost: float = 0.0

## Cargo capacity in Rice or Koku units (0.0 = military only).
@export var cargo_capacity: float = 0.0

## IC day this ship was launched.
@export var ic_day_launched: int = -1
