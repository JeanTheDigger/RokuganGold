class_name ArmorData
extends Resource
## Typed data class for worn armor. Stats transcribed from the L5R 4e Equipment
## tables (owner-provided 2026-06-29). GDD s40 specifies Armor TN = (Reflexes × 5)
## + 5 + bonuses from armor; ArmorSystem holds the catalog and the special-rule
## TN penalties (Athletics/Stealth, Agility/Reflexes) that some armor types impose.

@export var armor_name: String = ""
@export var tn_bonus: int = 0       # added to Armor TN (character.armor_tn_bonus mirrors this)
@export var reduction: int = 0      # damage Reduction (character.armor_reduction mirrors this)
@export var is_heavy: bool = false  # heavy-armor flag for technique/advantage interactions
# Special-rule skill-TN penalty kind (see ArmorSystem):
#   "none"                — no penalty
#   "athletics_stealth"   — +5 TN to Athletics & Stealth rolls (Light armor)
#   "agi_ref"             — +5 TN to Agility/Reflexes-trait rolls (Heavy)
#   "agi_ref_iron"        — +10 (or +5 if Strength ≥ 5) to Agility/Reflexes rolls (Tetsu-do)
#   "agi_ref_not_mounted" — +5 to Agility/Reflexes rolls except on horseback (Riding)
@export var penalty_kind: String = "none"
