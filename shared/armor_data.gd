class_name ArmorData
extends Resource
## Typed data class for worn armor per GDD s40.
## GDD s40 specifies Armor TN = (Reflexes × 5) + 5 + bonuses from armor.
## Specific armor types and their TN bonuses are blocked on the Equipment section (not yet in GDD).
## The class provides the structure; the catalog remains empty until that section is locked.

@export var armor_name: String = ""
@export var tn_bonus: int = 0      # added to Armor TN (character.armor_tn_bonus reads this)
@export var is_heavy: bool = false  # heavy armor flag for future technique interactions
