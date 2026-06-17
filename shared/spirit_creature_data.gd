class_name SpiritCreatureData
extends Resource
## A spirit-realm creature stat block (GDD s54.10 / s54.2), used by the s56.16
## Spiritual Insurgency encounter roster. Pure transcription of LOCKED bestiary
## stats — no invented values. Combat consumption (special abilities, the live
## ASCII-map encounter) is a later tranche; this is the data layer.

## Roster tier per the per-realm roster sections (e.g. s56.16.6b Gaki-do Roster).
enum Tier { SWARM, MID, HEAVY, BOSS, TERRAIN, POST_ENCOUNTER }

@export var id: String = ""
@export var display_name: String = ""
@export var realm: Enums.SpiritRealm = Enums.SpiritRealm.GAKI_DO
@export var tier: Tier = Tier.MID

# Rings.
@export var air: int = 1
@export var earth: int = 1
@export var fire: int = 1
@export var water: int = 1

# Named traits the stat block lists above its Rings (trait_name → rank).
@export var traits: Dictionary = {}

# Combat line.
@export var initiative_rolled: int = 0
@export var initiative_kept: int = 0
@export var attack_name: String = ""
@export var attack_rolled: int = 0
@export var attack_kept: int = 0
@export var damage_rolled: int = 0
@export var damage_kept: int = 0
@export var armor_tn: int = 10
@export var reduction: int = 0

# Optional second attack (multi-attack creatures, e.g. Claws + Bite). 0 rolled = none.
# The combat layer makes this as a second strike when the creature is tagged
# "multi_attack" and has the action budget (GDD s54.5: multi-attack oni attack as a
# Simple Action, so two Simple attacks per Turn).
@export var attack2_name: String = ""
@export var attack2_rolled: int = 0
@export var attack2_kept: int = 0
@export var damage2_rolled: int = 0
@export var damage2_kept: int = 0

# Wound track. wound_thresholds = the penalty-step thresholds (+5/+10…);
# wounds_dead = the terminal threshold (Dead/Dispersed). 0 = not statted.
@export var wound_thresholds: Array[int] = []
@export var wounds_dead: int = 0

## Per-round Wound regeneration (Reactions Stage). 0 = none. Distinct from the
## "regeneration" tag (Gashadokuro, 10/round WITH threshold-cross suppression); this is
## unconditional per-round regen (e.g. Arugai 10, Hasaiki 5 — s54.5 "Nearly Immortal" /
## "Regeneration"). Hourly regens (Sentei) are negligible in a skirmish → left 0.
@export var regen_wounds: int = 0

## Burning Blood (s54.5 Furu / Furu spawn): a melee attacker who WOUNDS this creature
## rolls Reflexes (Defense) vs burning_blood_tn or takes burning_blood_rolled k _kept
## damage. 0 rolled = no burning blood. (Weapon-size TN variation is not modelled — the
## stored TN is the unarmed/Small value, the worst case.)
@export var burning_blood_rolled: int = 0
@export var burning_blood_kept: int = 0
@export var burning_blood_tn: int = 0

@export var fear: int = 0
## Swift rating (L5R keyword the GDD invokes by name, e.g. "Swift 6"). Converted to
## a tile move-budget bonus via the project's fixed 1 tile = 5 ft (MovementSystem):
## Swift N = +N tiles. PROVISIONAL — the GDD names the keyword but states no conversion.
@export var swift: int = 0

# Special-ability tags for the future combat layer (e.g. "incorporeal",
# "swarm_presence", "wail", "hunger_pull", "fire_trail", "famine_only").
@export var tags: Array[String] = []


func has_tag(t: String) -> bool:
	return tags.has(t)


func has_second_attack() -> bool:
	return attack2_rolled > 0
