class_name OniData
extends Resource
## Data model for a procedurally generated Oni per GDD s2.4.8.
## All values are locked at generation — they never change.


## Unique name generated at creation (e.g. "Higareshi no Oni").
@export var oni_name: String = ""

## OniSize enum value.
@export var size: int = Enums.OniSize.SMALL

## OniBodyForm enum value.
@export var body_form: int = Enums.OniBodyForm.HUMANOID

## True if the Winged secondary modifier was applied (any base form).
@export var is_winged: bool = false

## Dominant Ring (Enums.Ring value: EARTH, WATER, FIRE, AIR). Void never.
@export var dominant_ring: int = Enums.Ring.FIRE

## Ring values (Enums.Ring → int). Void always 0.
@export var rings: Dictionary = {}

# -- Mass Battle Stats (derived per LOCKED formula in s2.4.8) ------------------

## MB Health from size table: Small=50, Medium=100, Large=175, Massive=300.
@export var mb_health: int = 50

## MB Attack = size_floor + Fire ring value.
@export var mb_attack: int = 5

## MB Defense = Earth ring + Air ring.
@export var mb_defense: int = 2

## No Morale stat — Oni cannot rout. Always -1 (sentinel for "none").
const MB_MORALE: int = -1

# -- Individual Combat Stats (s2.4.8 LOCKED formulas) -------------------------

## Wounds = Earth × 16.
@export var wounds: int = 16

## Armor TN = Air × 5.
@export var armor_tn: int = 5

## Reduction = Earth × 4. Halved vs jade/crystal/obsidian.
@export var reduction: int = 4

# -- Special Abilities (s2.4.8 Pools 1–3) ------------------------------------

## Fear rating from size: Small=1, Medium=2, Large=3, Massive=5.
@export var fear_rating: int = 1

## OniInvulnerability enum value (Pool 2 — one per Oni).
@export var invulnerability: int = Enums.OniInvulnerability.ARROW_IMMUNITY

## OniSpecialAttack enum value (Pool 3 — one per Oni).
@export var special_attack: int = Enums.OniSpecialAttack.BREATH_WEAPON

## For SPELL_IMMUNITY: how many spells are immune (1d3 = 1–3).
@export var spell_immunity_count: int = 0

# -- Weakness (s2.4.8 Step 6) -------------------------------------------------

## OniWeakness enum value (procedurally generated).
@export var specific_weakness: int = Enums.OniWeakness.FIRE

## For SPECIFIC_WEAPON_TYPE: the weapon type name (e.g. "spears").
@export var weakness_weapon_type: String = ""

## For SPECIFIC_SPELL_SCHOOL: the element name (e.g. "Water").
@export var weakness_spell_school: String = ""

## For NAMED_INDIVIDUAL: the character type (e.g. "Kuni Witch Hunter").
@export var weakness_named_type: String = ""

## True if the specific weakness has been discovered by a scout.
@export var weakness_discovered: bool = false

## IC day this Oni was generated.
@export var ic_day_generated: int = -1
