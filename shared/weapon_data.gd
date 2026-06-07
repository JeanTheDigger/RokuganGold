class_name WeaponData
extends Resource
## Typed data class for a weapon per GDD s40.
## Replaces the Dictionary entries in IndividualCombat.WEAPON_CATALOG for character inventory use.

# DR format: attacker rolls `rolled + Strength` dice (if strength_adds), keeps `kept`.
@export var weapon_name: String = ""
@export var rolled: int = 2        # base rolled dice (before Strength addition)
@export var kept: int = 1          # kept dice
@export var strength_adds: bool = true
@export var skill: String = "Kenjutsu"
@export var size: String = "Medium"  # "Small" / "Medium" / "Large" (affects off-hand penalties, Prone)
@export var melee: bool = true
@export var attack_trait: String = "agility"  # "agility"/"reflexes" ('trait' is reserved in Godot 4.6)
