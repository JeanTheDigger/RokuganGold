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

## Swallow Whole / Devour (s54.5 Muduro/Kamu/Tsuburu/Utogu): on a wounding melee hit the
## creature wins a Contested Strength to swallow the victim, who then takes
## swallow_damage_rolled k _kept each Round (+1 Taint if swallow_taint) until they escape.
## 0 rolled = the creature has no swallow attack.
@export var swallow_damage_rolled: int = 0
@export var swallow_damage_kept: int = 0
@export var swallow_taint: bool = false

## Creature ranged attack (s54.5 Daku Flaming Bark, Furu Hurl Flaming Blood, etc.): a
## thrown/spat attack option used when an enemy is out of melee but within ranged_range_tiles.
## 0 rolled = the creature has no ranged attack. ranged_fire = sets the target on fire on hit.
@export var ranged_attack_name: String = ""
@export var ranged_attack_rolled: int = 0
@export var ranged_attack_kept: int = 0
@export var ranged_damage_rolled: int = 0
@export var ranged_damage_kept: int = 0
@export var ranged_range_tiles: int = 0
@export var ranged_fire: bool = false
## Web (s54.12 Dokufu/Kumo): the ranged attack Entangles the target on a hit instead of
## dealing damage (escape = Strength TN 20/Round). ranged_damage_rolled is the to-hit dice.
@export var ranged_entangle: bool = false

## AoE ranged variant (s54.11 Cauldron Belch, s54.12 Gout of Flame): when ranged_aoe_radius
## > 0, the ranged attack damages every enemy within that radius of the impact tile.
## ranged_attack_rolled 0 = auto-hit (an explosion, no dodge). ranged_aoe_max_targets 0 =
## unlimited. ranged_aoe_once = once per skirmish.
@export var ranged_aoe_radius: int = 0
@export var ranged_aoe_max_targets: int = 0
@export var ranged_aoe_once: bool = false

## Follow-up attack on a big hit (s54.11 Ghul Throat Attack): if a melee hit deals
## followup_wound_threshold+ Wounds, the creature makes a free bonus attack
## (followup_rolled k _kept to-hit, followup_dmg_rolled k _kept). 0 threshold = none.
@export var followup_wound_threshold: int = 0
@export var followup_rolled: int = 0
@export var followup_kept: int = 0
@export var followup_dmg_rolled: int = 0
@export var followup_dmg_kept: int = 0

## Spawn-on-death (s54.5 Tasu releases spawn; Wakeru splits). On death, add
## death_spawn_count copies of death_spawn_id (another bestiary id) to the live combat.
## "" / 0 = no death spawn. (Tasu's "2k2 spawn" and Wakeru's recursive halving are
## reduced to a small fixed count for skirmish playability — PROVISIONAL.)
@export var death_spawn_id: String = ""
@export var death_spawn_count: int = 0

## Void Rank for the rare Void-using creatures (s54.12 Akeru no Oni: default 1, max 7).
## 0 = no Void (every other creature). Drives the combat puppet's Void Ring + points.
## Charge (s54.5/s54.12): in Full Attack stance, a charge-capable creature closes up to
## Water Ring × charge_move_mult feet and attacks in one turn. charge_simple = the attack is
## a Simple action (elephant/boar/war-dog); charge_atk/dmg_bonus_* = bonus dice (boar +1k1);
## charge_diving = airborne dive (+ the bonus, then self-Prone after). 0 mult = no charge.
@export var charge_move_mult: int = 0
@export var charge_simple: bool = false
@export var charge_atk_bonus: int = 0  # +N k N to the charge attack roll (boar/diving +1k1)
@export var charge_dmg_bonus: int = 0  # +N k N to the charge damage roll (boar +1k1)
@export var charge_diving: bool = false

## Trample (s54.5/s54.12): a melee hit renders the target Prone; if trample_daze_margin > 0
## and the attack beats Armor TN by that margin, also Dazed.
@export var trample_prone: bool = false
@export var trample_daze_margin: int = 0

@export var void_rank: int = 0

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
