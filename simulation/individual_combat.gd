class_name IndividualCombat
## Individual combat resolution per GDD s40.
## Covers skirmish mechanics, stances, maneuvers, iaijutsu dueling,
## grappling, sumai, and conditional effects. Pure static functions.


# -- Weapon Catalog (s40 — DR examples from s40, full catalog pending s40 Equipment) --
# Format: { rolled: int, kept: int, strength_adds: bool, skill: String, size: String }
# Size: "Small", "Medium", "Large" — affects off-hand penalties, Prone attack modifier.
# NOTE: Only katana DR is explicit in s40. Other entries match L5R 4e Core values;
# confirm against Equipment section when that GDD section is locked.

const WEAPON_CATALOG: Dictionary = {
	# trait: "agility" is standard for melee (s4.5 "Agility for attacks").
	# Iaijutsu duels use Reflexes — handled directly in resolve_duel_strike(), not via this table.
	# material: "wood" weapons (bo, polearms, bows/arrows) burn vs s35 Defense of the Firestorm;
	# "steel" otherwise. The s54 spirit damage filter reads it via WeaponData.material.
	"katana":     {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Kenjutsu",      "size": "Medium", "melee": true,  "trait": "agility", "material": "steel"},
	"wakizashi":  {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Kenjutsu",      "size": "Small",  "melee": true,  "trait": "agility", "material": "steel"},
	"tanto":      {"rolled": 1, "kept": 1, "strength_adds": true,  "skill": "Knives",         "size": "Small",  "melee": true,  "trait": "agility", "material": "steel"},
	"bo":         {"rolled": 2, "kept": 2, "strength_adds": true,  "skill": "Bo",             "size": "Large",  "melee": true,  "trait": "agility", "material": "wood"},
	# can_grapple: s40 "Weapon Grapples" — chain weapons and certain polearms may
	# initiate Grapples using the weapon skill. The naginata is the catalog's
	# grapple-capable polearm; chain weapons (e.g. kusarigama) get can_grapple
	# when added to the catalog with their own DR.
	"naginata":   {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Polearms",       "size": "Large",  "melee": true,  "trait": "agility", "can_grapple": true, "material": "wood"},
	"tetsubo":    {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Heavy Weapons",  "size": "Large",  "melee": true,  "trait": "agility", "material": "steel"},
	"yumi":       {"rolled": 2, "kept": 2, "strength_adds": false, "skill": "Kyujutsu",       "size": "Large",  "melee": false, "trait": "reflexes", "material": "wood"},
	"unarmed":    {"rolled": 1, "kept": 1, "strength_adds": true,  "skill": "Jiujutsu",       "size": "Small",  "melee": true,  "trait": "agility", "material": ""},
	# Off-hand weapons for the s40 dual-wield combinations (DR from s39 Equipment).
	# kama: Mantis paired small weapons (s29.9 "Waves Rush to Shore" uses Knives).
	# war_fan (tessen): Lion katana-and-war-fan (s29.4 "The Commander's Fan").
	"kama":       {"rolled": 0, "kept": 2, "strength_adds": true,  "skill": "Knives",         "size": "Small",  "melee": true,  "trait": "agility", "material": "steel"},
	"war_fan":    {"rolled": 0, "kept": 1, "strength_adds": true,  "skill": "War Fan",        "size": "Small",  "melee": true,  "trait": "agility", "material": "steel"},
}


## Weapon material ("wood" / "steel" / "" for unarmed) for the s35 Defense of the Firestorm
## wooden-weapon burn. Falls back to "steel" (a conjured/unknown weapon does not burn).
static func get_weapon_material(weapon_name: String) -> String:
	return get_weapon_profile(weapon_name).get("material", "steel")

const DEFAULT_WEAPON: Dictionary = {
	"rolled": 2, "kept": 1, "strength_adds": true, "skill": "Kenjutsu", "size": "Medium", "melee": true, "trait": "agility",
}

# -- Stance Constants ----------------------------------------------------------

const STANCE_ARMOR_TN_BONUS: Dictionary = {
	Enums.Stance.ATTACK:       0,
	Enums.Stance.FULL_ATTACK:  -10,
	Enums.Stance.DEFENSE:      0,   # Additional Air+Defense added at compute time
	Enums.Stance.FULL_DEFENSE: 0,   # Additional rolled bonus added at compute time
	Enums.Stance.CENTER:       0,
}

const STANCE_ATTACK_ROLLED_BONUS: Dictionary = {
	Enums.Stance.ATTACK:      0,
	Enums.Stance.FULL_ATTACK: 2,   # +2k1 to attack rolls
	Enums.Stance.DEFENSE:     0,
	Enums.Stance.FULL_DEFENSE: 0,
	Enums.Stance.CENTER:      0,
}

const STANCE_ATTACK_KEPT_BONUS: Dictionary = {
	Enums.Stance.ATTACK:      0,
	Enums.Stance.FULL_ATTACK: 1,
	Enums.Stance.DEFENSE:     0,
	Enums.Stance.FULL_DEFENSE: 0,
	Enums.Stance.CENTER:      0,
}

# -- Maneuver Raise Costs (s40) ------------------------------------------------

const MANEUVER_RAISES: Dictionary = {
	"called_shot_limb":   1,
	"called_shot_hand":   2,
	"called_shot_head":   3,
	"called_shot_small":  4,
	"disarm":             3,
	"extra_attack":       5,
	"feint":              2,
	"guard":              0,
	"increased_damage":   1,  # per extra die; multiple allowed
	"knockdown_biped":    2,
	"knockdown_quad":     4,
}

# -- Movement Constants (s40) --------------------------------------------------

const MOVEMENT_TERRAIN_WATER_PENALTY: Dictionary = {
	"basic":     0,
	"moderate":  1,
	"difficult": 2,
}

const ATHLETICS_TERRAIN_REDUCTION: Dictionary = {
	3: {"basic": 0, "moderate": -1, "difficult": -1},  # Rank 3
	5: {"basic": 0, "moderate": -1, "difficult": -2},  # Rank 5 (eliminates all)
}

# -- Off-hand and Extra Attack Constants (s40) ---------------------------------

# Penalty to off-hand weapon attack by weapon size.
const OFF_HAND_PENALTY: Dictionary = {"Small": -5, "Medium": -10, "Large": -15}
# Dominant hand attack penalty while holding an off-hand weapon (s40).
const DOMINANT_HAND_PENALTY: int = -5
# Blinded Simple Move: Athletics/Agility TN 20 or fall Prone (s40).
const BLINDED_SIMPLE_MOVE_TN: int = 20
# Extra Attack: 5 Raises required (3 with Spinning Blades kata for dual-wielders).
const EXTRA_ATTACK_BASE_RAISES: int = 5
const EXTRA_ATTACK_SPINNING_BLADES_RAISES: int = 3

# -- CombatCondition flags (s40 Conditional Effects) ---------------------------

const CONDITION_BLINDED:   String = "blinded"
const CONDITION_DAZED:     String = "dazed"
const CONDITION_ENTANGLED: String = "entangled"
const CONDITION_FATIGUED:  String = "fatigued"
const CONDITION_GRAPPLED:  String = "grappled"
const CONDITION_MOUNTED:   String = "mounted"
const CONDITION_PRONE:     String = "prone"
const CONDITION_STUNNED:   String = "stunned"
const CONDITION_AFRAID:     String = "afraid"   # s22.3/s02.4 Fear: -1k0 to all rolls while in range
const CONDITION_DEAFENED:   String = "deafened" # s35 Fury of Osano-Wo rider; combat effect deferred (no verbal/hearing mechanic)
# Held/bound/treated-as-Down: the combatant may take no actions on its Turn (the turn loop skips it)
# and is flat-footed (Armor TN 5). Used by the s34/s36/s35/s37 incapacitation spells (Earth bindings,
# Water Suitengu's Embrace, Fire Everburning Rage, Void Essence of Void). Applied as a TIMED condition
# so it runs its full duration (not shed by a recovery roll) and auto-expires in advance_round.
const CONDITION_INCAPACITATED: String = "incapacitated"

# GDD s40 describes striking after first blood as dishonorable and conceding
# a death duel as shameful, but specifies no numeric honor/glory values.
# Removed invented values (-1.0 honor, -0.5 glory). These are blocked on
# Table 2.3 gaining explicit entries for these situations.


# =============================================================================
# -- Participant State ---------------------------------------------------------
# =============================================================================

class Participant:
	var character_id: int = -1
	var stance: Enums.Stance = Enums.Stance.ATTACK
	var initiative_score: int = 0
	var has_acted_this_round: bool = false
	var is_delaying: bool = false
	var actions_remaining: int = 0   # 0 = not their turn yet / done
	var conditions: Array = []
	var timed_conditions: Dictionary = {}  # condition -> expiry round (auto-cleared, not roll-recovered)
	var guarding_id: int = -1        # character_id they're guarding, -1 if none
	var full_defense_bonus: int = 0  # bonus from Full Defense Stance roll
	var grapple_partner_id: int = -1
	var grapple_in_control: bool = false
	var daze_failed_recovery_attempts: int = 0  # tracks TN reduction per s40 ("decreases by 5 each failed attempt")
	var void_ring_bonus: int = 0     # from Center Stance carry-forward
	var center_stance_bonus_used: bool = false
	var fatigue_days: int = 0        # consecutive days without rest
	var void_spent_this_round: bool = false  # once-per-Round Void spend restriction (RAW)
	var void_armor_tn_bonus: int = 0         # from Void spend_for_armor_tn (RAW)
	var void_roll_pending_rolled: int = 0    # pending +N rolled dice from pre-declared Void spend (GDD s40)
	var void_roll_pending_kept: int = 0      # pending +N kept dice from pre-declared Void spend (GDD s40)
	var kata_used_this_turn: Dictionary = {}   # tracks once-per-Turn kata uses by effect_id
	var kata_used_this_round: Dictionary = {}  # tracks once-per-Round kata uses by effect_id
	var active_kiho: Array = []                 # currently-active kiho names (GDD s38; see KihoSystem)
	var active_kiho_expiry: Dictionary = {}     # kiho_name → expiry round (for round-duration buffs)
	var suppressed_disadvantage_expiry: int = -1  # round when Banish All Shadows suppression ends (s38)
	var all_disadvantages_suppressed_expiry: int = -1  # round when Balance of Elements all-suppression ends (s37)
	var taint_benefits_suppressed_expiry: int = -1  # round when Rest, My Brother Taint suppression ends (s38)
	var shadowed_mountain_used: bool = false  # Shadowed Mountain fired this activation (s38)
	var attacked_by_ids: Array = []  # who attacked me since my last Turn (Bishamon's Grasp, s38)
	var initiative_modifier: int = 0  # persistent Initiative delta (Song of the World, s38)
	var facing: Vector2i = Vector2i(0, 0)  # unit heading; (0,0) = unset (s38 arc/cone kiho)
	var inari_breath_round: int = -1  # round Inari's Wrath breath was held (s38); -1 = not holding
	var spirit_regen_suppressed_until: int = -1  # s54.10 Gashadokuro: regen off until this round
	# s54.5 Arugai "Nearly Immortal" / heart_kill: a regenerating oni that can only be truly
	# slain by destroying its heart. Locating it requires Investigation/Perception TN 30 (tearing
	# the chest open); the exposed heart sustains 10 Wounds before the oni dies for good.
	var heart_located: bool = false
	var heart_wounds: int = 0
	var heart_destroyed: bool = false
	var untargetable_revealed_until: int = -1  # s54.10 invisibility/intangibility: targetable through this round after acting
	var ephemeral_form_expiry: int = -1  # s54.10 Ephemeral Form: round the 10-round insubstantial window ends
	var ephemeral_form_used: bool = false  # Ephemeral Form is once-per-encounter (once/day)
	var mimic_expiry: int = -1  # s54.10 Mimic: round the 5-round disguise (untargetable) window ends; broken on attack
	var lure_sprung: bool = false  # s54.10 Konak Jiji lure: false = still disguised as a harmless baby (untargetable)
	var deceptive_weight_pinned: bool = false  # s54.10 Deceptive Weight: pinned (escape = Athletics/Strength TN 40)
	var swallowed_by_id: int = -1  # s54.5 Swallow Whole/Devour: creature id that swallowed me (-1 = none)
	var death_spawn_done: bool = false  # s54.5 spawn-on-death fired (guards against double-spawn)
	var ranged_aoe_used: bool = false  # s54.11 Cauldron Belch etc. once-per-skirmish AoE fired
	var void_locked: bool = false  # s54.12 Furaribi Soul Touch: cannot spend Void Points
	var escalating_poison: Dictionary = {}  # s54.5 Shikage Mind-Breaking/Paralyzing poison {trait,doses,drained}
	var suffocation_escalation: int = 0  # s54.5 Quiet Death Suffocation: per-Round crush damage step (3k3 +1k1/round)
	var spirit_leech: Dictionary = {}  # s54.5 Kommei Spirit Leeching fog {failures, expiry_round}
	var insight_study_target: int = -1  # s54.5 Manesuru Uncanny Insight: id being studied
	var insight_study_rounds: int = 0   # consecutive Complex Actions spent studying that target
	var mirror_origin_id: int = -1      # s54.5 Dark Mirror duplicate: the creature it copied (attacks it first)
	var scream_used: bool = false  # s54.12 Wanyudo Strength of the Dead: once-per-skirmish scream
	var gore_escape_rolled: int = 0  # s54.5 Gore: extra damage dealt when pulling free of the tusks (0 = not gored)
	var gore_escape_kept: int = 0
	var freeze_break_tn: int = 0  # s36 Yuki's Touch: Strength TN to break free of the ice (0 = use the default entangle TN 20)
	var spirit_attack_rolled_bonus: int = 0  # s54.10 Toshigoku auras/Tactical Mastery: +N rolled attack dice (orchestrator sets per-attack, spirit-only)
	var spirit_damage_rolled_bonus: int = 0  # s54.10 Supreme Commander: +N rolled damage dice (spirit-only)
	var spirit_attack_kept_bonus: int = 0  # s54.5 Charge: +N kept attack dice (the kept half of a +NkN charge bonus)
	var spirit_damage_kept_bonus: int = 0  # s54.5 Charge: +N kept damage dice
	var void_dragon_ring: int = -1  # Touch the Void Dragon (s38): boosted Ring (Enums.Ring), -1 = inactive
	# s35/s34/s33/s36 conjured elemental weapons (Katana of Fire, Tetsubo of Earth, Yari of Air,
	# Bo of Water). {} = none; {rolled,kept,skill,trait,school_rank} = a created weapon the wielder
	# uses with their effective School Rank in place of the weapon skill. Read in resolve_attack/
	# resolve_damage; expired in advance_round at conjured_weapon_expiry.
	var conjured_weapon: Dictionary = {}
	var conjured_weapon_expiry: int = -1
	var dual_wielding: bool = false            # true when holding an off-hand weapon
	var off_hand_weapon: String = ""           # name of off-hand weapon ("" = none)
	var earth_trade_amount: int = 0            # Armor TN traded for damage (earth_trade_armor_for_damage)
	var earth_init_trade_amount: int = 0       # Initiative traded for Armor TN (earth_trade_initiative_for_armor)
	var water_trade_armor_amount: int = 0      # Armor TN traded for movement (water_trade_armor_for_movement)
	var guard_kata_bonus: int = 0              # extra Armor TN from void_phoenix_guard_bonus kata
	var extra_attack_used_this_turn: bool = false  # Extra Attack may only be used once per turn
	var off_hand_attack_used_this_turn: bool = false  # Off-hand attack may only be made once per turn (s40)
	# Weapon-grapple state (s40 "Weapon Grapples"): when a character initiates a
	# grapple with a chain weapon / certain polearm, control rolls use the weapon
	# skill and Hit deals weapon damage. Empty/"" = ordinary Jiujutsu grapple.
	var weapon_grapple_skill: String = ""
	var weapon_grapple_weapon: String = ""
	# Free Raises the opponent has banked toward a Disarm against this character
	# (s40: granted when a weapon-grappler loses control of the grapple).
	var disarm_free_raises_pending: int = 0
	# Timed combat modifiers from s30a duration katas (Victory of the River, etc.).
	# Each entry: {kind:String, value:int, expires_round:int, source:String}.
	# expires_round is the round at which it is removed (active through the prior round).
	var timed_modifiers: Array = []
	# Reversal of Fortunes (s36): the round in which this participant last used its
	# re-roll charge (1/round). -1 = never used this skirmish.
	var reversal_used_round: int = -1
	# Disarm maneuver (s40): the character's weapon is on the ground — they fight unarmed
	# until they spend an action to recover it. Cleared by execute_recover_weapon.
	var disarmed: bool = false
	# Gathering Swirl (s33 Air 1): the dropped weapon was telekinetically swept beyond the
	# owner's feet, so it can no longer be recovered (execute_recover_weapon fails). The owner
	# stays unarmed for the skirmish. Set only on an already-disarmed (un-wielded) weapon.
	var weapon_swept: bool = false
	# Victory of the River (s30a): the single opponent currently held under the
	# Armor-TN debuff ("One opponent at a time"); -1 = none.
	var votr_target_id: int = -1
	# On fire (s54.10 Everything Burns / s56.6.6): set by a fire creature's melee
	# hit; takes 1k1 at the start of each round until a Simple Action extinguishes it.
	var on_fire: bool = false
	var absorb_pool: int = 0  # s34 Power of the Earth Dragon: remaining Wounds the ward absorbs (0 = none)
	# s36 Silent Waters: a pre-cast ML<=3 spell held until a physical trigger fires it. {} = none.
	# {spell_id, trigger} — trigger "when_struck" releases it the next time this participant is hit.
	var stored_spell: Dictionary = {}
	# Combat-scoped Ring deltas from in-combat spells (s34 Essence of Earth ring-up, Water
	# ring-downs): {Enums.Ring: int}. The AUTHORITATIVE participant-scoped store; synced to the
	# character's combat_ring_deltas read-bridge so the CharacterStats wound/death chain sees the
	# boost. Lives only on the Participant (destroyed at combat end) -> never leaks persistently.
	var ring_deltas: Dictionary = {}
	var ring_delta_expiry: Dictionary = {}  # {Enums.Ring: expiry_round} for the ring deltas above


## Combat-scoped Ring deltas for a Participant (empty if none). Null-safe.
static func ring_deltas_of(p) -> Dictionary:
	if p == null:
		return {}
	return p.ring_deltas


## Sync the participant's authoritative ring_deltas onto the character's read-bridge so the static
## CharacterStats wound/death chain sees the boost. Call after any ring-delta change. A zero/absent
## delta is removed so the bridge is empty when no ring change is active (the no-leak invariant).
static func sync_ring_deltas(p: Participant, character: L5RCharacterData) -> void:
	if character == null:
		return
	var bridge: Dictionary = {}
	if p != null:
		for ring in p.ring_deltas:
			if int(p.ring_deltas[ring]) != 0:
				bridge[ring] = int(p.ring_deltas[ring])
	character.combat_ring_deltas = bridge


class CombatState:
	var round_number: int = 1
	var participants: Dictionary = {}  # character_id -> Participant
	var turn_order: Array = []    # sorted character_ids by initiative (desc)
	var current_turn_index: int = 0
	var is_over: bool = false
	var winner_id: int = -1


class DuelState:
	var challenger_id: int = -1
	var defender_id: int = -1
	var duel_to_death: bool = false
	var stage: int = 1                # 1=Assessment, 2=Focus, 3=Strike
	var first_striker_id: int = -1    # set during Focus
	var free_raises_first: int = 0    # Free Raises for the first striker
	var simultaneous: bool = false    # kharmic strike flag
	var assessment_bonus_id: int = -1 # who got +1k1 on Focus for winning Assessment by 10+
	var stare_down_penalty_id: int = -1 # who takes -1k0 on Assessment (lost stare-down)
	var conceded_id: int = -1         # who conceded at Assessment
	var struck_after_first_blood: bool = false
	var is_over: bool = false
	var winner_id: int = -1
	var loser_id: int = -1


# =============================================================================
# -- Kata Effect Modifiers (s30a → s40) ----------------------------------------
# =============================================================================

static func _has_kata_effect(character: L5RCharacterData, effect_id: String) -> bool:
	for kata_name: String in character.katas:
		if KataSystem.KATA_DATA.has(kata_name):
			if KataSystem.KATA_DATA[kata_name]["effect_id"] == effect_id:
				return true
	return false


## Returns {flat_bonus, use_void_ring} for initiative kata effects.
## Touch the Void Dragon (s38): +1 to `ring`'s value when it is the participant's active
## environmental boost. The +1 Rank to the Ring's associated Traits manifests as +1k1 on
## attack/initiative rolls and +5 Armor TN / +1 damage die at the call sites below.
static func vd_ring_bonus(participant: Participant, ring: int) -> int:
	return 1 if (participant != null and participant.void_dragon_ring == ring) else 0


static func _get_kata_initiative_modifiers(character: L5RCharacterData, weapon_name: String) -> Dictionary:
	var flat_bonus: int = 0
	var use_void_ring: bool = false
	for kata_name: String in character.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"air_polearm_initiative":
				if get_weapon_profile(weapon_name).get("skill", "") == "Polearms":
					flat_bonus += 3
			"void_initiative_void_ring":
				use_void_ring = true
	return {"flat_bonus": flat_bonus, "use_void_ring": use_void_ring}


## Returns the kata bonus to Armor TN for this participant on the incoming attack.
## Side-effect: marks once-per-Turn kata uses in participant.kata_used_this_turn.
static func _get_kata_armor_tn_bonus(
	character: L5RCharacterData,
	participant: Participant,
	weapon_name: String,
) -> int:
	var bonus: int = 0
	var air_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	var fire_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.FIRE)
	var void_ring: int = character.void_ring
	for kata_name: String in character.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"air_defense_armor_tn":
				if participant.stance == Enums.Stance.DEFENSE:
					bonus += air_ring
			"air_crane_honor_armor":
				var skill: String = get_weapon_profile(weapon_name).get("skill", "")
				if skill in ["Kenjutsu", "Polearms"]:
					bonus += maxi(1, HonorGlorySystem.get_honor_rank(character) - 3)
			"air_stealth_armor_once":
				if not participant.kata_used_this_turn.get("air_stealth_armor_once", false):
					bonus += character.skills.get("Stealth", 0)
					participant.kata_used_this_turn["air_stealth_armor_once"] = true
			"earth_defense_extra_armor":
				if participant.stance in [Enums.Stance.DEFENSE, Enums.Stance.FULL_DEFENSE]:
					bonus += earth_ring
			"earth_trade_armor_for_damage":
				bonus -= participant.earth_trade_amount
			"earth_trade_initiative_for_armor":
				bonus += participant.earth_init_trade_amount
			"fire_full_attack_armor_tn":
				if participant.stance == Enums.Stance.FULL_ATTACK:
					bonus += fire_ring
			"fire_dragon_daisho_armor":
				if participant.dual_wielding and weapon_name == "katana" and participant.off_hand_weapon == "wakizashi":
					bonus += 3
			"void_center_stance_armor":
				if participant.stance == Enums.Stance.CENTER:
					bonus += void_ring
			"water_trade_armor_for_movement":
				bonus -= participant.water_trade_armor_amount
	# void_phoenix_guard_bonus is stored by resolve_guard() on the guarded participant.
	bonus += participant.guard_kata_bonus
	return bonus


## Returns {rolled_bonus, kept_bonus, flat_bonus, use_air_ring, use_strength} for attacks.
## Side-effect: marks once-per-Round/Turn kata uses.
static func _get_kata_attack_modifiers(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
	maneuver: String,
) -> Dictionary:
	var rolled_bonus: int = 0
	var kept_bonus: int = 0
	var flat_bonus: int = 0
	var use_air_ring: bool = false
	var use_strength: bool = false
	var profile: Dictionary = get_weapon_profile(weapon_name)
	var skill: String = profile.get("skill", "")
	var air_ring: int = CharacterStats.get_ring_value(attacker, Enums.Ring.AIR)
	var fire_ring: int = CharacterStats.get_ring_value(attacker, Enums.Ring.FIRE)
	for kata_name: String in attacker.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"air_spear_attack_ring":
				if skill == "Polearms":
					use_air_ring = true
			"air_increased_damage_bonus":
				if maneuver == "increased_damage":
					flat_bonus += air_ring
			"air_called_knockdown_bonus":
				if maneuver in ["called_shot_limb", "called_shot_hand", "called_shot_head",
						"called_shot_small", "knockdown_biped", "knockdown_quad"]:
					flat_bonus += air_ring
			"air_ranged_melee_penalty":
				# Reduces ranged-in-melee penalty by 3 — handled as a flat bonus on the
				# attack roll (the -10 penalty is already applied by the caller; we add back 3).
				flat_bonus += 3  # only meaningful when is_ranged_in_melee; always safe to add
			"fire_full_attack_attack_bonus":
				if attacker_p.stance == Enums.Stance.FULL_ATTACK:
					if not attacker_p.kata_used_this_round.get("fire_full_attack_attack_bonus", false):
						rolled_bonus += fire_ring
						attacker_p.kata_used_this_round["fire_full_attack_attack_bonus"] = true
			"water_strength_for_attack":
				if skill == "Heavy Weapons":
					if not attacker_p.kata_used_this_turn.get("water_strength_for_attack", false):
						use_strength = true
						attacker_p.kata_used_this_turn["water_strength_for_attack"] = true
			"earth_water_movement_penalty":
				# Heavy Weapons: 1 Free Raise for Knockdown (free raise = +5 roll total effectively)
				if skill == "Heavy Weapons" and maneuver in ["knockdown_biped", "knockdown_quad"]:
					flat_bonus += 5
	return {
		"rolled_bonus": rolled_bonus,
		"kept_bonus": kept_bonus,
		"flat_bonus": flat_bonus,
		"use_air_ring": use_air_ring,
		"use_strength": use_strength,
	}


## Returns {rolled_bonus, flat_bonus, use_agility, strength_bonus} for damage rolls.
## Side-effect: marks once-per-Turn kata uses.
static func _get_kata_damage_modifiers(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
	was_feint: bool,
) -> Dictionary:
	var rolled_bonus: int = 0
	var flat_bonus: int = 0
	var use_agility: bool = false
	var strength_bonus: int = 0
	var skill: String = get_weapon_profile(weapon_name).get("skill", "")
	for kata_name: String in attacker.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"earth_heavy_weapons_strength":
				if skill == "Heavy Weapons":
					strength_bonus += 1
			"fire_agility_for_damage":
				if not attacker_p.kata_used_this_turn.get("fire_agility_for_damage", false):
					use_agility = true
					attacker_p.kata_used_this_turn["fire_agility_for_damage"] = true
			"fire_scorpion_feint_damage":
				if was_feint and not attacker_p.kata_used_this_turn.get("fire_scorpion_feint_damage", false):
					flat_bonus += 3
					attacker_p.kata_used_this_turn["fire_scorpion_feint_damage"] = true
			"water_skilled_weapon_damage":
				if attacker.skills.get(skill, 0) >= 3:
					rolled_bonus += 1
			"void_honor_damage":
				if not attacker_p.kata_used_this_turn.get("void_honor_damage", false):
					rolled_bonus += HonorGlorySystem.get_honor_rank(attacker)
					attacker_p.kata_used_this_turn["void_honor_damage"] = true
	return {
		"rolled_bonus": rolled_bonus,
		"flat_bonus": flat_bonus,
		"use_agility": use_agility,
		"strength_bonus": strength_bonus,
	}


## Returns wound TN penalty reduction from katas (earth_wound_tn_reduce kata).
static func _get_kata_wound_penalty_reduction(character: L5RCharacterData) -> int:
	if _has_kata_effect(character, "earth_wound_tn_reduce"):
		return CharacterStats.get_earth_ring(character)
	return 0


# -- Timed combat modifiers (s30a duration katas) -----------------------------
# Generic round-scoped modifier store on a Participant. Each entry is
# {kind, value, expires_round, source}. `kind` selects which roll/value the
# modifier feeds ("armor_tn" today; "all_rolls" / "attack_roll" reserved for the
# Spider / World Is Empty katas). All values and durations are GDD-given (s30a) —
# the system carries no balance numbers of its own.

## expiry_kind: "round" (removed once round_number reaches expires_round) or
## "turn_end" (removed at the end of the holder's own next turn — for "next Turn"
## effects like Strength of the Spider; expires_round is unused for those).
static func add_timed_modifier(p: Participant, kind: String, value: int, expires_round: int, source: String, expiry_kind: String = "round") -> void:
	p.timed_modifiers.append({"kind": kind, "value": value, "expires_round": expires_round, "source": source, "expiry_kind": expiry_kind})


static func get_timed_modifier_total(p: Participant, kind: String) -> int:
	var total: int = 0
	for m: Dictionary in p.timed_modifiers:
		if m.get("kind", "") == kind:
			total += int(m.get("value", 0))
	return total


static func has_timed_modifier_source(p: Participant, source: String) -> bool:
	for m: Dictionary in p.timed_modifiers:
		if m.get("source", "") == source:
			return true
	return false


static func clear_timed_modifiers_by_source(p: Participant, source: String) -> void:
	var kept: Array = []
	for m: Dictionary in p.timed_modifiers:
		if m.get("source", "") != source:
			kept.append(m)
	p.timed_modifiers = kept


## s35 Essence of Fire: "ends all ongoing spell effects." Removes timed modifiers whose source is
## spell-installed (prefix "spell_": spell_buff / spell_invisible / spell_debuff / spell_arrows_flight).
## Kata/kiho/creature modifiers (non-"spell_" sources) are NOT spell effects and are left untouched.
## LIMITATION: spell-applied CONDITIONS (incapacitate/entangle/afraid/blinded) carry no source tag,
## so they cannot be selectively dispelled and are not cleared here.
static func clear_spell_timed_modifiers(p: Participant) -> int:
	var kept: Array = []
	var removed: int = 0
	for m: Dictionary in p.timed_modifiers:
		if String(m.get("source", "")).begins_with("spell_"):
			removed += 1
		else:
			kept.append(m)
	p.timed_modifiers = kept
	return removed


## Remove round-based timed modifiers whose window has closed. Called once per
## participant at the start of each new round (after round_number is incremented).
## Turn-based ("turn_end") modifiers are untouched here.
static func expire_timed_modifiers(p: Participant, round_number: int) -> void:
	var kept: Array = []
	for m: Dictionary in p.timed_modifiers:
		if m.get("expiry_kind", "round") != "round":
			kept.append(m)  # turn-based — not expired by round advancement
		elif int(m.get("expires_round", 0)) > round_number:
			kept.append(m)
	p.timed_modifiers = kept


## Remove active kiho whose round-duration has elapsed (s38: "Lasts Rounds equal to
## [Ring]"). Kiho with no recorded expiry (Air Fist's "one day", indefinite buffs)
## persist for the whole skirmish. Called from the orchestrator's advance_round.
static func expire_active_kiho(p: Participant, round_number: int) -> void:
	for k: String in p.active_kiho_expiry.keys():
		if int(p.active_kiho_expiry[k]) <= round_number:
			p.active_kiho.erase(k)
			p.active_kiho_expiry.erase(k)


## Remove turn-based ("turn_end") timed modifiers from a participant whose turn is
## ending. Called from the orchestrator's advance_turn for the ending actor.
static func expire_turn_modifiers(p: Participant) -> void:
	var kept: Array = []
	for m: Dictionary in p.timed_modifiers:
		if m.get("expiry_kind", "round") != "turn_end":
			kept.append(m)
	p.timed_modifiers = kept


## Striking as Water (s30a, water_attack_stance_movement): "In Attack Stance:
## move 5 additional feet as a Free Action." One tile = 5 ft (MovementSystem), so
## this is +1 tile to the Free-action move budget while in Attack Stance. Public —
## called by the ASCII map orchestrator when computing the Free-move budget.
static func get_kata_free_move_bonus(character: L5RCharacterData, participant: Participant) -> int:
	if participant.stance != Enums.Stance.ATTACK:
		return 0
	if _has_kata_effect(character, "water_attack_stance_movement"):
		return 1
	return 0


## +1 tile (5 ft) to any Move Action while Fire's Fleeting Speed is active (s38 Fire).
static func get_kiho_move_bonus(_character: L5RCharacterData, participant: Participant) -> int:
	if participant != null and "Fire's Fleeting Speed" in participant.active_kiho:
		return 1
	return 0


## s54.x Swift: a spirit creature's Swift rating as a tile move-budget bonus
## (Swift N = +N tiles; 1 tile = 5 ft). 0 for non-spirits / no Swift. PROVISIONAL.
static func get_creature_swift_bonus(character: L5RCharacterData) -> int:
	if character != null and character.spirit_creature != null:
		return character.spirit_creature.swift
	return 0


## The Empire Rests on its Edge (s30a, multi_empire_edge_skill_bonus): while known,
## grants a flat bonus to Kenjutsu/Iaijutsu rolls equal to the wielder's Rank in a
## chosen non-combat High Skill. The GDD picks the skill at acquisition; with no
## choice UI the system resolves it to the character's highest-ranked High Skill
## (optimal, deterministic). The "+2 XP per Rank" progression cost is not modelled.
## Returns the bonus, or 0 if the kata is unknown.
static func get_empire_edge_bonus(character: L5RCharacterData) -> int:
	if "The Empire Rests on its Edge" not in character.katas:
		return 0
	var best: int = 0
	for skill_name: String in character.skills:
		if AdvantageSystem.is_high_skill(skill_name):
			best = maxi(best, int(character.skills[skill_name]))
	return best


## Returns bonus to own Reduction from katas (earth_full_defense, earth_crab variants).
## Public — called by WoundSystem context builders.
static func get_kata_reduction_bonus(
	character: L5RCharacterData,
	participant: Participant,
	weapon_name: String,
) -> int:
	var bonus: int = 0
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	for kata_name: String in character.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"earth_full_defense_reduction":
				if participant.stance == Enums.Stance.FULL_DEFENSE:
					bonus += earth_ring
			"earth_crab_armor_reduction":
				if participant.stance == Enums.Stance.ATTACK and character.armor_tn_bonus > 0:
					bonus += 2
	return bonus


## Returns how much the attacker's katas reduce the defender's Reduction.
## Side-effect: marks once-per-Round kata uses.
static func get_kata_opponent_reduction_penalty(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
) -> int:
	var penalty: int = 0
	var size: String = get_weapon_profile(weapon_name).get("size", "Medium")
	var water_ring: int = CharacterStats.get_ring_value(attacker, Enums.Ring.WATER)
	for kata_name: String in attacker.katas:
		if not KataSystem.KATA_DATA.has(kata_name):
			continue
		var effect_id: String = KataSystem.KATA_DATA[kata_name]["effect_id"]
		match effect_id:
			"water_small_weapon_reduction":
				if size == "Small":
					penalty += 1
			"water_ignore_reduction":
				if not attacker_p.kata_used_this_round.get("water_ignore_reduction", false):
					penalty += water_ring
					attacker_p.kata_used_this_round["water_ignore_reduction"] = true
	return penalty


# =============================================================================
# -- Kiho Effect Modifiers (s38 → s40) -----------------------------------------
# =============================================================================
# Kiho effects apply only while the kiho is ACTIVE (participant.active_kiho),
# unlike katas (passive once known). First wired tranche: persistent passive
# buffs that map onto the existing kata modifier hooks (Armor TN, Initiative,
# wound-penalty). Atemi-delivered, contested-roll, and unique kiho remain
# deferred. Kiho is monk-only (s38a A0).

## effect_ids of the combatant's currently-active kiho (skips kiho with no wired effect).
static func _active_kiho_effect_ids(participant: Participant) -> Array:
	var ids: Array = []
	for kiho_name: String in participant.active_kiho:
		if KihoSystem.KIHO_DATA.has(kiho_name):
			var eid: String = KihoSystem.KIHO_DATA[kiho_name].get("effect_id", "")
			if eid != "":
				ids.append(eid)
	return ids


## Armor TN bonus from active kiho. Soul of the Four Winds: +Insight + Air Ring.
static func _get_kiho_armor_tn_bonus(character: L5RCharacterData, participant: Participant) -> int:
	var bonus: int = 0
	var air_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
	var insight: int = CharacterStats.get_insight_rank(character)
	for effect_id: String in _active_kiho_effect_ids(participant):
		match effect_id:
			"kiho_soul_four_winds_armor":
				bonus += insight + air_ring
			"kiho_musubi_armor":
				# Musubi (s38 Water): + Water Ring + Staves Skill Rank to Armor TN (staff in motion).
				bonus += CharacterStats.get_ring_value(character, Enums.Ring.WATER) + int(character.skills.get("Staves", 0))
	return bonus


## Initiative flat bonus from active kiho. Air Fist: +5 while only unarmed.
static func _get_kiho_initiative_bonus(
	character: L5RCharacterData,
	participant: Participant,
	weapon_name: String,
) -> int:
	var bonus: int = 0
	for effect_id: String in _active_kiho_effect_ids(participant):
		match effect_id:
			"kiho_air_fist_initiative":
				if weapon_name == "" or weapon_name == "unarmed":
					bonus += 5
	return bonus


## Wound-penalty TN reduction from active kiho. Grasp the Earth Dragon: −Earth Ring.
static func _get_kiho_wound_penalty_reduction(character: L5RCharacterData, participant: Participant) -> int:
	var reduction: int = 0
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	for effect_id: String in _active_kiho_effect_ids(participant):
		match effect_id:
			"kiho_grasp_earth_dragon_wound":
				reduction += earth_ring
	return reduction


## Reduction bonus from active kiho. Embrace the Stone: 2× Earth; Partaking the
## Waters: Water Ring.
static func _get_kiho_reduction_bonus(character: L5RCharacterData, participant: Participant) -> int:
	var bonus: int = 0
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	var water_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.WATER)
	for effect_id: String in _active_kiho_effect_ids(participant):
		match effect_id:
			"kiho_embrace_stone_reduction":
				bonus += 2 * earth_ring
			"kiho_partaking_waters_reduction":
				bonus += water_ring
	return bonus


## Total Reduction the defender has against this attack: base armor Reduction +
## kata + active-kiho Reduction, minus the attacker's Reduction-piercing effects,
## floored at 0. Feed this into WoundSystem.apply_damage. (Wires the kata/kiho
## Reduction modifiers, which were computed but never passed into damage before.)
static func total_defender_reduction(
	defender: L5RCharacterData,
	defender_p: Participant,
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
) -> int:
	var base: int = defender.armor_reduction
	var kata: int = get_kata_reduction_bonus(defender, defender_p, weapon_name)
	var kiho: int = _get_kiho_reduction_bonus(defender, defender_p)
	var spell: int = get_timed_modifier_total(defender_p, "reduction")  # s34 Armor of Earth etc.
	var pierce: int = get_kata_opponent_reduction_penalty(attacker, attacker_p, weapon_name)
	return maxi(0, base + kata + kiho + spell - pierce)


## Resolve an atemi-delivered kiho strike (GDD s38). Atemi deal no normal damage —
## only the kiho effect occurs, and armor's Armor TN bonus is DOUBLED against atemi.
## Covers atemi kiho whose effect is an instant, roll-recoverable condition
## (Dazed / Stunned, per the existing s40 condition model). Some require a Contested
## Ring roll after the hit. Returns {ok, hit, effect_applied, condition, ...}.
## Atemi kiho with durations, new condition types, or unique mechanics are not yet
## wired (need timed-condition infrastructure) — they return effect_not_wired.
## round_number enables "timed" atemi effects (s38 kiho that last "Rounds equal to
## X"); pass the current combat round so the timed modifier gets a round-based
## expiry. -1 (default) is fine for instant-condition atemi.
static func resolve_atemi_strike(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	target: L5RCharacterData,
	target_p: Participant,
	kiho_name: String,
	dice_engine: DiceEngine,
	round_number: int = -1,
	auto_hit: bool = false,
) -> Dictionary:
	if not attacker.kiho.has(kiho_name):
		return {"ok": false, "reason": "not_known"}
	var kiho: Dictionary = KihoSystem.KIHO_DATA.get(kiho_name, {})
	if not kiho.get("atemi", false):
		return {"ok": false, "reason": "not_atemi"}
	var spec: Dictionary = kiho.get("atemi_effect", {})
	if spec.is_empty():
		return {"ok": false, "reason": "effect_not_wired"}
	# Activation Void-Point cost (e.g. Falling Star Strike): spent on use (precondition).
	if spec.has("vp_cost"):
		if attacker.current_void_points < int(spec["vp_cost"]):
			return {"ok": false, "reason": "insufficient_void"}
		attacker.current_void_points -= int(spec["vp_cost"])
	# A willing ally (Chi Protection) does not resist — skip the to-hit roll. Otherwise
	# make the unarmed strike; some atemi require extra Raises (Falling Star: 2 Raises).
	if not auto_hit:
		var atemi_tn: int = get_armor_tn(target, target_p, dice_engine) + target.armor_tn_bonus
		var attack: Dictionary = resolve_attack(attacker, attacker_p, "unarmed", atemi_tn, int(spec.get("attack_raises", 0)), dice_engine)
		if not attack.get("hit", false):
			return {"ok": true, "hit": false}
	# Optional Contested Ring roll after the hit.
	if spec.has("contest"):
		var c: Dictionary = spec["contest"]
		var atk_ring: int = CharacterStats.get_ring_value(attacker, c["attacker_ring"])
		var def_ring: int = CharacterStats.get_ring_value(target, c["defender_ring"])
		var atk_roll: DiceResult = dice_engine.roll_and_keep(atk_ring, atk_ring, true)
		var def_roll: DiceResult = dice_engine.roll_and_keep(def_ring, def_ring, true)
		if atk_roll.total < def_roll.total:
			return {"ok": true, "hit": true, "effect_applied": false, "contested_lost": true}

	# Composable atemi effects (s38): a spec may combine direct damage, an auto-Disarm
	# (with optional Void-Point negation), a timed modifier, a wound-rank-equivalent
	# roll penalty, and/or an instant condition. All values are GDD-given per kiho.
	var result: Dictionary = {"ok": true, "hit": true, "effect_applied": true}

	# Normal unarmed damage (atemi that deal real damage, e.g. The Rolling Avalanche:
	# normal unarmed + Earth k0; Falling Star Strike: normal unarmed + a ring component).
	# bonus_ring → +Ring k0 via resolve_damage's raises_for_damage. Normal Reduction.
	if spec.has("normal_damage"):
		var nd: Dictionary = spec["normal_damage"]
		# Bonus unkept (rolled) dice: from a caster Ring, or = the target's Taint Rank
		# (s38 Rest, My Brother: "additional unkept damage dice equal to Taint Rank").
		var bonus: int = 0
		if nd.has("bonus_ring"):
			bonus = CharacterStats.get_ring_value(attacker, nd["bonus_ring"])
		elif nd.get("bonus_target_taint", false):
			bonus = MutationSystem.get_taint_rank(target.taint)
		var ndr: Dictionary = resolve_damage(attacker, "unarmed", bonus, 0, dice_engine, attacker_p)
		var nhit: Dictionary = WoundSystem.apply_damage(target, ndr["raw_damage"], -1)
		result["normal_damage"] = nhit["final_damage"]
		result["target_dead"] = nhit["is_dead"]

	# Direct damage (e.g. Censure of Thunder 1k1, bypassing Reduction). Dice may be
	# fixed (rolled/kept) or ring-scaled (rolled_ring/kept_ring → attacker's ring,
	# the "DR equal to [Ring]" convention = Ring k Ring exploding, e.g. Touch of the Storm).
	if spec.has("damage"):
		var dmg: Dictionary = spec["damage"]
		var rolled: int = CharacterStats.get_ring_value(attacker, dmg["rolled_ring"]) if dmg.has("rolled_ring") else int(dmg.get("rolled", 1))
		var kept: int = CharacterStats.get_ring_value(attacker, dmg["kept_ring"]) if dmg.has("kept_ring") else int(dmg.get("kept", 1))
		var raw: int = dice_engine.roll_and_keep(rolled, kept, true).total
		var reduction: int = 0 if dmg.get("bypass_reduction", false) else -1
		var dr: Dictionary = WoundSystem.apply_damage(target, raw, reduction)
		result["damage"] = dr["final_damage"]
		result["target_dead"] = dr["is_dead"]

	# Auto-Disarm, with optional VP negation (the defender may spend VP to keep the
	# weapon, taking extra damage instead — NPC auto-decides to negate if able).
	if spec.has("disarm"):
		var negated: bool = false
		var neg: Dictionary = spec.get("vp_negate", {})
		if not neg.is_empty() and not target.is_pc and target.current_void_points >= int(neg.get("vp_cost", 99)):
			target.current_void_points -= int(neg.get("vp_cost", 2))
			var bypass: bool = spec.get("damage", {}).get("bypass_reduction", false)
			var raw2: int = dice_engine.roll_and_keep(int(neg.get("extra_rolled", 2)), int(neg.get("extra_kept", 2)), true).total
			var dr2: Dictionary = WoundSystem.apply_damage(target, raw2, 0 if bypass else -1)
			result["disarm_negated"] = true
			result["extra_damage"] = dr2["final_damage"]
			result["target_dead"] = dr2["is_dead"]
			negated = true
		result["disarmed"] = not negated

	# Wound-rank-equivalent timed roll penalty (Stain Upon the Soul: penalty as if at
	# Wound Ranks = attacker's Air Ring, for Insight + Air Rounds). LIMITATION: stacks
	# with the target's actual wound penalty (GDD says the worse one supersedes).
	if spec.has("wound_rank_penalty"):
		var wp: Dictionary = spec["wound_rank_penalty"]
		var rank: int = CharacterStats.get_ring_value(attacker, wp.get("rank_ring", Enums.Ring.AIR))
		var lvl: int = clampi(rank, Enums.WoundLevel.HEALTHY, Enums.WoundLevel.DOWN)
		var penalty: int = int(Enums.WOUND_PENALTIES.get(lvl, 0))
		var dur: int = 0
		for r: int in wp.get("duration_rings", []):
			dur += CharacterStats.get_ring_value(attacker, r)
		if wp.get("duration_insight", false):
			dur += CharacterStats.get_insight_rank(attacker)
		add_timed_modifier(target_p, "all_rolls", penalty, round_number + dur, wp.get("source", "stain_soul"), "round")
		result["wound_rank_penalty"] = penalty

	# Generic timed modifier (e.g. Flame Fist: -3 × Fire Ring to all rolls for Fire
	# Rounds; Earth Palm: -4 damage dice for Earth Rounds). value_flat = a fixed value;
	# otherwise value_mult × the attacker's value_ring.
	if spec.has("timed"):
		var t: Dictionary = spec["timed"]
		var value: int = int(t["value_flat"]) if t.has("value_flat") else int(t.get("value_mult", 1)) * CharacterStats.get_ring_value(attacker, t.get("value_ring", Enums.Ring.FIRE))
		var duration: int = CharacterStats.get_ring_value(attacker, t.get("duration_ring", Enums.Ring.FIRE)) * int(t.get("duration_mult", 1))
		add_timed_modifier(target_p, t.get("kind", "all_rolls"), value, round_number + duration, t.get("source", "atemi_kiho"), "round")
		result["timed_kind"] = t.get("kind", "")
		result["timed_value"] = value

	# Rest, My Brother (s38): a human/formerly-uncorrupted target loses all Shadowlands
	# Taint benefits for caster Earth Ring Rounds. (Oni / inherently-Tainted creatures
	# are s54 and do not exist in tile combat yet, so the human gate always passes.)
	if spec.get("suppress_taint_benefits", false):
		target.taint_benefits_suppressed = true
		target_p.taint_benefits_suppressed_expiry = round_number + CharacterStats.get_ring_value(attacker, Enums.Ring.EARTH)
		result["taint_benefits_suppressed"] = true

	# Heal the struck target (Chi Protection: target regains Wounds equal to the
	# caster's Water Ring — used on a willing ally via auto_hit).
	if spec.has("heal"):
		var hamt: int = CharacterStats.get_ring_value(attacker, spec["heal"].get("ring", Enums.Ring.WATER))
		var hres: Dictionary = WoundSystem.heal_wounds(target, hamt)
		result["healed"] = hres["healed"]

	# Caster Void-Point gain (Void Fist: regain VP on a hit; needs a target with VP).
	# Capped at the caster's Void Ring (max VP).
	if spec.has("caster_vp_gain"):
		if not spec.get("target_vp_required", false) or target.current_void_points > 0:
			var max_vp: int = CharacterStats.get_ring_value(attacker, Enums.Ring.VOID)
			attacker.current_void_points = mini(max_vp, attacker.current_void_points + int(spec["caster_vp_gain"]))
			result["caster_vp_gained"] = int(spec["caster_vp_gain"])

	# Instant condition (Dazed, Stunned, silenced, Blinded). May be gated by its own
	# Contested Ring roll (condition_contest) that does NOT gate the damage — e.g.
	# Falling Star Strike: damage always lands, Blinded only on a won Fire contest.
	if spec.has("condition"):
		var apply_cond: bool = true
		if spec.has("condition_contest"):
			var cc: Dictionary = spec["condition_contest"]
			var ca: int = CharacterStats.get_ring_value(attacker, cc["attacker_ring"])
			var cd: int = CharacterStats.get_ring_value(target, cc["defender_ring"])
			apply_cond = dice_engine.roll_and_keep(ca, ca, true).total >= dice_engine.roll_and_keep(cd, cd, true).total
		if apply_cond:
			apply_condition(target_p, spec["condition"])
			result["condition"] = spec["condition"]
		else:
			result["condition_resisted"] = true

	return result


## Activate a kiho on a combatant for the current skirmish. Validates the kiho is
## known and the active-slot constraint (one Internal/Kharmic/Mystical, unlimited
## Martial — GDD s38). Returns {ok, reason}. The activation cost (Void Point /
## Meditation roll) is the caller's responsibility (orchestrator / NPC AI).
static func activate_kiho(
	character: L5RCharacterData,
	participant: Participant,
	kiho_name: String,
) -> Dictionary:
	if not character.kiho.has(kiho_name):
		return {"ok": false, "reason": "not_known"}
	var slot: Dictionary = KihoSystem.can_activate(kiho_name, participant.active_kiho)
	if not slot.get("ok", false):
		return slot
	participant.active_kiho.append(kiho_name)
	return {"ok": true}


# =============================================================================
# -- Initiative (s40 Stage 1) --------------------------------------------------
# =============================================================================

static func roll_initiative(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
	weapon_name: String = "",
) -> int:
	var kata_init: Dictionary = _get_kata_initiative_modifiers(character, weapon_name)
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)
	# Spell Initiative buff (s35 Warning Flame: +1k0 to Initiative rolls).
	var spell_init_rolled: int = get_timed_modifier_total(participant, "initiative_rolled")
	# Advantage/disadvantage modifiers (s45): CONSUMED Perfection (-5 to score), TOUCH_OF_THE_SPIRIT_REALMS, etc.
	var adv_init: Dictionary = AdvantageSystem.get_skill_bonus(character, "", {"is_combat": true})
	var adv_init_tn: int = AdvantageSystem.get_tn_modifier(character, {"is_combat": true})
	var score: int
	if kata_init["use_void_ring"]:
		# void_initiative_void_ring: roll Void Ring + InsightRank, keep Void Ring (s30a)
		var void_rank: int = character.void_ring
		var insight_rank: int = CharacterStats.get_insight_rank(character)
		var result: DiceResult = dice_engine.roll_and_keep(
			void_rank + insight_rank + adv_init["rolled"] + spell_init_rolled,
			maxi(void_rank + adv_init["kept"], 1))
		score = result.total + wound_penalty
	else:
		var reflexes: int = character.reflexes
		var insight_rank: int = CharacterStats.get_insight_rank(character)
		# Touch the Void Dragon (s38): +1 Rank to Reflexes (Air) = +1k1 Initiative.
		var vd_init: int = vd_ring_bonus(participant, Enums.Ring.AIR)
		var result: DiceResult = dice_engine.roll_and_keep(
			reflexes + insight_rank + adv_init["rolled"] + vd_init + spell_init_rolled,
			maxi(reflexes + adv_init["kept"] + vd_init, 1), true)
		score = result.total + wound_penalty
	score += kata_init["flat_bonus"] + adv_init["free_raises"] * 5 - adv_init_tn
	score += _get_kiho_initiative_bonus(character, participant, weapon_name)
	score += participant.initiative_modifier  # Song of the World (s38), persistent delta

	# Center Stance carry-over adds +10 to Initiative Score for that round only (s40)
	if participant.stance == Enums.Stance.CENTER and not participant.center_stance_bonus_used:
		score += 10
		participant.void_ring_bonus = character.void_ring
	participant.initiative_score = score
	return score


static func build_combat_state(participants_data: Array) -> CombatState:
	var state := CombatState.new()
	for data: Dictionary in participants_data:
		var p := Participant.new()
		p.character_id = data.get("character_id", -1)
		p.stance = data.get("stance", Enums.Stance.ATTACK) as Enums.Stance
		p.initiative_score = data.get("initiative_score", 0)
		state.participants[p.character_id] = p

	_sort_turn_order(state)
	return state


static func _sort_turn_order(state: CombatState) -> void:
	var ids: Array = []
	for cid: int in state.participants.keys():
		ids.append(cid)
	ids.sort_custom(func(a: int, b: int) -> bool:
		return state.participants[a].initiative_score > state.participants[b].initiative_score
	)
	state.turn_order = ids


# =============================================================================
# -- Armor TN Computation (s40) -----------------------------------------------
# =============================================================================

static func get_armor_tn(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
	is_melee_attack: bool = true,
	is_being_guarded: bool = false,
	weapon_name: String = "",
) -> int:
	var base_tn: int = CharacterStats.get_armor_tn(character)
	var stance_mod: int = STANCE_ARMOR_TN_BONUS.get(participant.stance, 0)

	var defense_bonus: int = 0
	if participant.stance == Enums.Stance.DEFENSE:
		# earth_defense_stance_ring kata: use Earth Ring instead of Air Ring for Defense bonus (s30a)
		var def_ring: int
		if _has_kata_effect(character, "earth_defense_stance_ring"):
			def_ring = CharacterStats.get_earth_ring(character)
		else:
			def_ring = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
		var def_rank: int = character.skills.get("Defense", 0)
		defense_bonus = def_ring + def_rank

	var full_def_bonus: int = 0
	if participant.stance == Enums.Stance.FULL_DEFENSE:
		full_def_bonus = participant.full_defense_bonus

	# Guard maneuver: guarding another character costs -5 to own Armor TN (s40)
	var guard_self_mod: int = -5 if participant.guarding_id != -1 else 0

	# Guard maneuver: being guarded grants +10 Armor TN (s40)
	var guard_protection: int = 10 if is_being_guarded else 0

	# Conditional modifiers
	var cond_mod: int = 0
	if CONDITION_GRAPPLED in participant.conditions:
		return 5 + character.armor_tn_bonus  # Grappled: Armor TN = 5 + armor bonuses
	if CONDITION_PRONE in participant.conditions and is_melee_attack:
		# -10 vs melee attacks only (s40: "against melee attacks"); ranged attacks unaffected
		cond_mod -= 10
	if CONDITION_STUNNED in participant.conditions:
		return 5 + character.armor_tn_bonus  # Stunned: Armor TN = 5 + armor bonuses
	if CONDITION_INCAPACITATED in participant.conditions:
		return 5 + character.armor_tn_bonus  # Held/bound/treated-as-Down: flat-footed
	if CONDITION_BLINDED in participant.conditions:
		# Blinded base = Reflexes + 5 (armor still adds)
		return character.reflexes + 5 + character.armor_tn_bonus

	# Kata armor TN bonuses (s30a) and dual-wield bonus (+InsightRank, s40)
	var kata_bonus: int = _get_kata_armor_tn_bonus(character, participant, weapon_name)
	var kiho_bonus: int = _get_kiho_armor_tn_bonus(character, participant)
	var dual_wield_bonus: int = CharacterStats.get_insight_rank(character) if participant.dual_wielding else 0
	# Timed Armor-TN modifiers from s30a duration katas (Victory of the River: -10).
	var timed_armor: int = get_timed_modifier_total(participant, "armor_tn")
	# Touch the Void Dragon (s38): +1 Rank to Reflexes (Air) = +5 Armor TN.
	var vd_armor: int = vd_ring_bonus(participant, Enums.Ring.AIR) * 5
	return base_tn + stance_mod + defense_bonus + full_def_bonus + cond_mod + participant.void_armor_tn_bonus + guard_self_mod + guard_protection + kata_bonus + kiho_bonus + dual_wield_bonus + timed_armor + vd_armor


static func roll_full_defense_bonus(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
) -> int:
	var def_rank: int = character.skills.get("Defense", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)
	# Mutation modifiers (s44): EXTRA_LIMB non-functional applies -1k0 to Defense skill
	var mutation_def: Dictionary = MutationSystem.get_skill_modifiers(character, "Defense")
	# Advantage/disadvantage modifiers (s45): PRODIGY, TOUCH_OF_THE_SPIRIT_REALMS Jigoku, etc.
	var is_school_def: bool = NPCAdvancement.get_school_skills(character).has("Defense")
	var adv_def_ctx: Dictionary = {"is_combat": true, "is_school_skill": is_school_def}
	var adv_def: Dictionary = AdvantageSystem.get_skill_bonus(character, "Defense", adv_def_ctx)
	var adv_def_tn: int = AdvantageSystem.get_tn_modifier(character, adv_def_ctx)
	# Full Defense: Defense/Reflexes — roll (Reflexes + Defense Rank), keep Reflexes (s40)
	var result: DiceResult = dice_engine.roll_and_keep(
		maxi(character.reflexes + def_rank + mutation_def["rolled"] + adv_def["rolled"], 1),
		maxi(character.reflexes + mutation_def["kept"] + adv_def["kept"], 1)
	)
	# Free raises add +5 to effective total; TN penalties reduce it (CONSUMED Perfection = -5)
	var half_result: int = ceili(float(result.total + adv_def["free_raises"] * 5 - adv_def_tn + wound_penalty) / 2.0)
	participant.full_defense_bonus = half_result
	return half_result


# =============================================================================
# -- Attack Resolution (s40) --------------------------------------------------
# =============================================================================

static func get_weapon_profile(weapon_name: String) -> Dictionary:
	return WEAPON_CATALOG.get(weapon_name.to_lower(), DEFAULT_WEAPON)


## True if the named weapon may initiate a Grapple (s40 "Weapon Grapples").
static func weapon_can_grapple(weapon_name: String) -> bool:
	return get_weapon_profile(weapon_name).get("can_grapple", false)


static func resolve_attack(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
	target_armor_tn: int,
	raises: int,
	dice_engine: DiceEngine,
	is_ranged_in_melee: bool = false,
	spend_void: bool = false,
	target_is_mounted: bool = false,
	maneuver: String = "",
	adv_context: Dictionary = {},
	attacker_roll_penalty: int = 0,
	target_is_large: bool = false,
) -> Dictionary:
	var weapon: Dictionary = get_weapon_profile(weapon_name)
	# Conjured elemental weapon (s33-s36): override the wielded profile. The created weapon's
	# skill may be replaced by the caster's effective School Rank ("uses School Rank in place of
	# [skill]"); take the better of the two. Inert for everyone else (conjured_weapon == {}).
	if attacker_p != null and not attacker_p.conjured_weapon.is_empty():
		weapon = attacker_p.conjured_weapon
	var skill_name: String = weapon.get("skill", "Kenjutsu")
	var skill_rank: int = attacker.skills.get(skill_name, 0)
	if attacker_p != null and not attacker_p.conjured_weapon.is_empty():
		skill_rank = maxi(skill_rank, int(attacker_p.conjured_weapon.get("school_rank", 0)))
	var wound_penalty: int = CharacterStats.get_wound_penalty(attacker)
	# s36 Near to Ice / s34 Force of Will: Wound Penalties are negated for the duration (rides the
	# timed-modifier layer, auto-expires). Inert when the buff is absent.
	if attacker_p != null and get_timed_modifier_total(attacker_p, "negate_wound_penalty") > 0:
		wound_penalty = 0

	# Attack roll: Trait + Skill rolled, keep Trait (s4.5 "Agility for attacks").
	var trait_name: String = weapon.get("trait", "agility")
	var trait_value: int = attacker.reflexes if trait_name == "reflexes" else attacker.agility
	var rolled: int = trait_value + skill_rank
	var kept: int = trait_value

	# s56.16: a spirit creature attacks with its fixed stat-block roll (XkY), not the
	# PC trait+skill formula. Applied before kata/void modifiers (creatures have none).
	# Inert for real characters (spirit_creature == null).
	if attacker.spirit_creature != null and attacker.spirit_creature.attack_rolled > 0:
		rolled = attacker.spirit_creature.attack_rolled
		kept = attacker.spirit_creature.attack_kept
		# s54.10 Toshigoku auras (Mob Aggression / Rally / Supreme Commander) and the
		# Ancient General's Tactical Mastery — +N rolled attack dice the orchestrator
		# computed from co-located allies / rounds-engaged. Inert (0) for everyone else.
		rolled += attacker_p.spirit_attack_rolled_bonus
		kept += attacker_p.spirit_attack_kept_bonus

	# Kata attack modifiers (s30a): trait substitution applied before void/stance
	var kata_atk: Dictionary = _get_kata_attack_modifiers(attacker, attacker_p, weapon_name, maneuver)
	if kata_atk["use_air_ring"]:
		var air_ring: int = CharacterStats.get_ring_value(attacker, Enums.Ring.AIR)
		rolled = air_ring + skill_rank
		kept = air_ring
	elif kata_atk["use_strength"]:
		rolled = attacker.strength + skill_rank
		kept = attacker.strength

	# Touch the Void Dragon (s38): +1 Rank (=+1k1) when the attack trait's Ring is boosted.
	# Effective trait ring: Air (air-ring kata / reflexes weapon), Water (strength kata),
	# else Fire (agility weapon).
	var _vd_atk_ring: int = Enums.Ring.AIR if kata_atk["use_air_ring"] else (Enums.Ring.WATER if kata_atk["use_strength"] else (Enums.Ring.FIRE if trait_name == "agility" else Enums.Ring.AIR))
	if vd_ring_bonus(attacker_p, _vd_atk_ring) > 0:
		rolled += 1
		kept += 1

	# Void spend for +1k1 (or +2k2) on attack roll (RAW). Not valid for Damage Rolls.
	# Apply either inline spend_void or pre-declared pending bonus from execute_void_spend.
	var void_used: bool = false
	if attacker_p.void_roll_pending_rolled > 0 or attacker_p.void_roll_pending_kept > 0:
		rolled += attacker_p.void_roll_pending_rolled
		kept += attacker_p.void_roll_pending_kept
		attacker_p.void_roll_pending_rolled = 0
		attacker_p.void_roll_pending_kept = 0
		void_used = true
	elif spend_void and VoidSystem.can_spend(attacker) and not attacker_p.void_spent_this_round:
		var vbonus: Dictionary = VoidSystem.spend_for_roll(attacker)
		if vbonus["success"]:
			rolled += vbonus["rolled_bonus"]
			kept += vbonus["kept_bonus"]
			attacker_p.void_spent_this_round = true
			void_used = true

	# Stance bonuses
	rolled += STANCE_ATTACK_ROLLED_BONUS.get(attacker_p.stance, 0)
	kept += STANCE_ATTACK_KEPT_BONUS.get(attacker_p.stance, 0)

	# Kata dice bonuses applied after stance
	rolled += kata_atk["rolled_bonus"]
	kept += kata_atk["kept_bonus"]

	# Spell weapon-buff attack bonus (s35 Burning Kiss of Steel etc.) — applies to any attack.
	rolled += get_timed_modifier_total(attacker_p, "spell_attack_rolled")
	kept += get_timed_modifier_total(attacker_p, "spell_attack_kept")

	# The World Is Empty (s30a): +Xk0 to Kenjutsu/Iaijutsu attack rolls while active.
	if skill_name == "Kenjutsu" or skill_name == "Iaijutsu":
		rolled += get_timed_modifier_total(attacker_p, "attack_rolled")

	# Mutation modifiers (s44): EXTRA_LIMB non-functional applies -1k0 to weapon skills
	var mutation_atk: Dictionary = MutationSystem.get_skill_modifiers(attacker, skill_name)
	rolled += mutation_atk["rolled"]
	kept += mutation_atk["kept"]

	# Advantage/disadvantage modifiers (s45): TOUCH_OF_THE_SPIRIT_REALMS Jigoku, PRODIGY,
	# HEART_OF_VENGEANCE, CONSUMED Perfection (+5 TN), FAILURE_OF_BUSHIDO Courage, etc.
	var is_school_skill_atk: bool = NPCAdvancement.get_school_skills(attacker).has(skill_name)
	var adv_ctx: Dictionary = {"is_combat": true, "is_school_skill": is_school_skill_atk}
	adv_ctx.merge(adv_context)
	var adv_skill_atk: Dictionary = AdvantageSystem.get_skill_bonus(attacker, skill_name, adv_ctx)
	rolled += adv_skill_atk["rolled"]
	kept += adv_skill_atk["kept"]
	var adv_free_raises_atk: int = adv_skill_atk["free_raises"]
	var adv_tn_atk: int = AdvantageSystem.get_tn_modifier(attacker, adv_ctx)

	# Mounted / Higher Ground: +1k0 against unmounted or lower characters (s40)
	if CONDITION_MOUNTED in attacker_p.conditions and not target_is_mounted:
		rolled += 1

	# s35 Burning Kiss of Steel: the fire-engulfed weapon gives a further +1k1 (on top of the spell's
	# base +1k1, read above) when the opponent is mounted or larger than human size.
	if get_timed_modifier_total(attacker_p, "burning_kiss") > 0 and (target_is_mounted or target_is_large):
		rolled += 1
		kept += 1

	# Conditional modifiers: -3k0 Dazed, -1k1 or -3k3 Blinded, Prone restrictions
	if CONDITION_DAZED in attacker_p.conditions:
		rolled = maxi(0, rolled - 3)
	# Fear (s22.3/s02.4): a frightened combatant suffers -1k0 to all rolls while in range.
	if CONDITION_AFRAID in attacker_p.conditions:
		rolled = maxi(0, rolled - 1)
	# s33 Castle of Air: a defender-imposed -Xk0 penalty on attacks against the warded caster.
	if attacker_roll_penalty != 0:
		rolled = maxi(0, rolled + attacker_roll_penalty)
	if CONDITION_BLINDED in attacker_p.conditions:
		if weapon.get("melee", true):
			rolled = maxi(0, rolled - 1)
			kept = maxi(1, kept - 1)
		else:
			rolled = maxi(0, rolled - 3)
			kept = maxi(1, kept - 3)
	if CONDITION_PRONE in attacker_p.conditions:
		if weapon.get("size", "Medium") == "Large":
			return {"success": false, "reason": "prone_large_weapon_blocked"}
		else:
			rolled = maxi(0, rolled - 2)

	# earth_wound_tn_reduce kata + Grasp the Earth Dragon kiho reduce wound penalty (s30a/s38)
	var kata_wound_reduction: int = _get_kata_wound_penalty_reduction(attacker)
	var kiho_wound_reduction: int = _get_kiho_wound_penalty_reduction(attacker, attacker_p)
	var effective_wound_penalty: int = mini(0, wound_penalty + kata_wound_reduction + kiho_wound_reduction)

	# Center Stance carry-over: +1k1 + Void Ring on the first roll of the turn (s40)
	var flat_bonus: int = effective_wound_penalty - get_condition_roll_penalty(attacker_p)
	if attacker_p.void_ring_bonus > 0 and not attacker_p.center_stance_bonus_used:
		rolled += 1
		kept += 1
		flat_bonus += attacker_p.void_ring_bonus
		attacker_p.center_stance_bonus_used = true

	# Ranged in melee range: -10 flat to total (air_ranged_melee_penalty kata adds back +3)
	if is_ranged_in_melee and not weapon.get("melee", true):
		flat_bonus -= 10

	flat_bonus += kata_atk["flat_bonus"]

	# Timed "all rolls" penalty from s30a Strength of the Spider (-3 next Turn).
	# Covers attack rolls; broader contested-roll coverage is a forward-wire.
	flat_bonus += get_timed_modifier_total(attacker_p, "all_rolls")

	# The Empire Rests on its Edge (s30a): +Rank in the chosen non-combat High Skill
	# to Kenjutsu/Iaijutsu rolls (passive while known). Katana/daisho is implied by
	# the Kenjutsu/Iaijutsu skill gate.
	if skill_name == "Kenjutsu" or skill_name == "Iaijutsu":
		flat_bonus += get_empire_edge_bonus(attacker)

	# Dominant hand attack penalty while holding an off-hand weapon (s40)
	if attacker_p.dual_wielding:
		flat_bonus += DOMINANT_HAND_PENALTY  # -5

	# Advantage free raises add +5 each to roll total; advantage TN penalties reduce it.
	flat_bonus += adv_free_raises_atk * 5
	flat_bonus -= adv_tn_atk

	# Unskilled rolls (skill_rank == 0) do not explode per L5R4e p.78.
	# raises passed directly — roll_check applies raises * 5 to TN.
	var result: Dictionary = dice_engine.roll_check(
		rolled, kept, target_armor_tn, raises, flat_bonus, skill_rank > 0
	)

	return {
		"success": result["success"],
		"hit": result["success"],
		"roll": result["total"],
		"target_tn": result["tn"],
		"margin": result["margin"],
		"raises_called": raises,
		"void_used": void_used,
	}


static func resolve_damage(
	attacker: L5RCharacterData,
	weapon_name: String,
	raises_for_damage: int,
	feint_bonus: int,
	dice_engine: DiceEngine,
	attacker_p: Participant = null,
	was_feint: bool = false,
	bonus_kept: int = 0,
) -> Dictionary:
	var weapon: Dictionary = get_weapon_profile(weapon_name)
	# Conjured elemental weapon (s33-s36): fixed DR, no Strength bonus. Inert otherwise.
	if attacker_p != null and not attacker_p.conjured_weapon.is_empty():
		weapon = attacker_p.conjured_weapon
	var rolled: int = weapon.get("rolled", 2)
	var kept: int = weapon.get("kept", 1) + bonus_kept

	# s54: a spirit/oni creature deals its FIXED stat-block damage (XkY), not the named
	# weapon profile nor Strength-augmented dice. Mirrors the to-hit override in
	# resolve_attack — the orchestrator picks "unarmed" from WEAPON_CATALOG for puppets
	# (SpiritCombatant sets no skills), so without this the creature's real damage
	# (e.g. 10k4) was never used. Inert for real characters (spirit_creature == null).
	var spirit_fixed_damage: bool = false
	if attacker != null and attacker.spirit_creature != null and attacker.spirit_creature.damage_rolled > 0:
		rolled = attacker.spirit_creature.damage_rolled
		kept = attacker.spirit_creature.damage_kept + bonus_kept
		spirit_fixed_damage = true

	# s54.10 Supreme Commander aura: +N rolled damage dice the orchestrator set on the
	# spirit attacker (Musha within 20 tiles of the Ancient General). Inert (0) otherwise.
	if attacker_p != null:
		rolled += attacker_p.spirit_damage_rolled_bonus
		kept += attacker_p.spirit_damage_kept_bonus

	# Advantage/disadvantage modifiers (s45): HANDS_OF_STONE adds +1 kept for unarmed damage
	var dmg_skill: String = weapon.get("skill", "Kenjutsu")
	var is_unarmed_dmg: bool = (dmg_skill == "Jiujutsu")
	var adv_dmg: Dictionary = AdvantageSystem.get_skill_bonus(
		attacker, dmg_skill, {"is_unarmed_damage": is_unarmed_dmg}
	)
	rolled += adv_dmg["rolled"]
	kept += adv_dmg["kept"]

	# Kata damage modifiers (s30a)
	var kata_dmg: Dictionary = {
		"rolled_bonus": 0, "flat_bonus": 0, "use_agility": false, "strength_bonus": 0,
	}
	if attacker_p != null:
		kata_dmg = _get_kata_damage_modifiers(attacker, attacker_p, weapon_name, was_feint)

	# Strength adds to rolled dice for melee weapons (s40: "add Strength to first number")
	# fire_agility_for_damage kata: use Agility instead of Strength (s30a)
	if weapon.get("strength_adds", true) and weapon.get("melee", true) and not spirit_fixed_damage:
		if kata_dmg["use_agility"]:
			rolled += attacker.agility
		else:
			rolled += attacker.strength
		# Touch the Void Dragon (s38): +1 rolled damage die when the damage trait's Ring is
		# boosted (Fire for the agility kata, else Water for Strength).
		rolled += vd_ring_bonus(attacker_p, Enums.Ring.FIRE if kata_dmg["use_agility"] else Enums.Ring.WATER)

	# earth_heavy_weapons_strength kata: +1 extra unkept die of strength (s30a)
	rolled += kata_dmg["strength_bonus"]

	# Increased Damage maneuver: +1k0 per Raise (s40)
	rolled += raises_for_damage

	# Kata extra unkept dice (water_skilled_weapon_damage, void_honor_damage)
	rolled += kata_dmg["rolled_bonus"]

	# Timed damage-dice penalty (s38 Earth Palm Water option: -4 damage dice while active).
	if attacker_p != null:
		rolled = maxi(0, rolled + get_timed_modifier_total(attacker_p, "damage_dice_penalty"))
		# Spell weapon-buff damage bonus (s35 Biting Steel +1k1 etc.).
		rolled += get_timed_modifier_total(attacker_p, "spell_damage_rolled")
		kept += get_timed_modifier_total(attacker_p, "spell_damage_kept")

	# s35 Hungry Blade: while the buff is active, all the wielder's damage dice also explode on an 8 or 9
	# (once each). Inert (false) for everyone else.
	var explode_8: bool = attacker_p != null and get_timed_modifier_total(attacker_p, "hungry_blade") > 0
	# roll_damage handles the dice pool; we pass strength already absorbed above
	var result: Dictionary = dice_engine.roll_damage(rolled, kept, 0, 0, explode_8)
	var total: int = result["raw"] + feint_bonus + kata_dmg["flat_bonus"]

	return {
		"rolled": rolled,
		"kept": kept,
		"raw_damage": total,
		"dice_result": result,
	}


# =============================================================================
# -- Maneuver Resolution (s40) ------------------------------------------------
# =============================================================================

static func resolve_disarm(
	attacker: L5RCharacterData,
	defender: L5RCharacterData,
	dice_engine: DiceEngine,
	weapon_name: String = "",
	attacker_p: Participant = null,
) -> Dictionary:
	# Disarm inflicts 2k1 damage regardless of weapon (s40)
	# air_disarm_normal_damage kata: use normal weapon damage instead (s30a)
	var damage_total: int
	if weapon_name != "" and _has_kata_effect(attacker, "air_disarm_normal_damage"):
		var dmg: Dictionary = resolve_damage(attacker, weapon_name, 0, 0, dice_engine, attacker_p)
		damage_total = dmg["raw_damage"]
	else:
		var dmg_result: Dictionary = dice_engine.roll_damage(2, 1)
		damage_total = dmg_result["raw"]

	# Contested Strength Roll — advantage/disadvantage modifiers (s45) + wound penalties
	var att_wound: int = CharacterStats.get_wound_penalty(attacker)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)
	var att_adv_dis: Dictionary = AdvantageSystem.get_skill_bonus(attacker, "", {"is_combat": true, "is_contested": true})
	var def_adv_dis: Dictionary = AdvantageSystem.get_skill_bonus(defender, "", {"is_combat": true, "is_contested": true})
	var att_tn_dis: int = AdvantageSystem.get_tn_modifier(attacker, {"is_combat": true, "is_contested": true})
	var def_tn_dis: int = AdvantageSystem.get_tn_modifier(defender, {"is_combat": true, "is_contested": true})
	var att_r_dis: DiceResult = dice_engine.roll_and_keep(
		maxi(attacker.strength + att_adv_dis["rolled"], 1), maxi(attacker.strength + att_adv_dis["kept"], 1), false)
	var def_r_dis: DiceResult = dice_engine.roll_and_keep(
		maxi(defender.strength + def_adv_dis["rolled"], 1), maxi(defender.strength + def_adv_dis["kept"], 1), false)
	var att_total_dis: int = att_r_dis.total + att_adv_dis["free_raises"] * 5 - att_tn_dis + att_wound
	var def_total_dis: int = def_r_dis.total + def_adv_dis["free_raises"] * 5 - def_tn_dis + def_wound

	return {
		"damage": damage_total,
		"attacker_strength_roll": att_total_dis,
		"defender_strength_roll": def_total_dis,
		"disarmed": att_total_dis > def_total_dis,
	}


static func compute_feint_bonus(
	attack_margin: int,
	attacker_insight_rank: int,
) -> int:
	# Feint: half the margin (after accounting for the 2 Raises), max = 5 × InsightRank
	var bonus: int = int(float(attack_margin) / 2.0)
	return mini(bonus, 5 * attacker_insight_rank)


static func resolve_knockdown(
	attacker: L5RCharacterData,
	defender: L5RCharacterData,
	is_quadruped: bool,
	dice_engine: DiceEngine,
	bonus_to_attacker: int = 0,  # s54.12 Rhino Furious Charge: +5 = the Free Raise
	def_rolled_bonus: int = 0,  # s34 The Mountain's Feet: +Nk0 knockdown resist (extra rolled dice)
	def_kept_bonus: int = 0,
) -> Dictionary:
	# Advantage/disadvantage modifiers (s45) + wound penalties
	var att_wound: int = CharacterStats.get_wound_penalty(attacker)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)
	var att_adv_kd: Dictionary = AdvantageSystem.get_skill_bonus(attacker, "", {"is_combat": true, "is_contested": true})
	var def_adv_kd: Dictionary = AdvantageSystem.get_skill_bonus(defender, "", {"is_combat": true, "is_contested": true})
	var att_tn_kd: int = AdvantageSystem.get_tn_modifier(attacker, {"is_combat": true, "is_contested": true})
	var def_tn_kd: int = AdvantageSystem.get_tn_modifier(defender, {"is_combat": true, "is_contested": true})
	var att_rolled_kd: int = maxi(attacker.strength + att_adv_kd["rolled"], 1)
	var def_rolled_kd: int = maxi(defender.strength + def_adv_kd["rolled"] + def_rolled_bonus, 1)
	var att_kept_kd: int = maxi(attacker.strength + att_adv_kd["kept"], 1)
	var def_kept_kd: int = maxi(defender.strength + def_adv_kd["kept"] + def_kept_bonus, 1)
	var att_r: DiceResult = dice_engine.roll_and_keep(att_rolled_kd, att_kept_kd, false)
	var def_r: DiceResult = dice_engine.roll_and_keep(def_rolled_kd, def_kept_kd, false)
	var att_total_kd: int = att_r.total + (att_adv_kd["free_raises"] * 5) - att_tn_kd + att_wound + bonus_to_attacker
	var def_total_kd: int = def_r.total + (def_adv_kd["free_raises"] * 5) - def_tn_kd + def_wound + (4 if is_quadruped else 0)
	return {
		"attacker_strength_roll": att_total_kd,
		"defender_strength_roll": def_total_kd,
		"knocked_down": att_total_kd > def_total_kd,
	}


static func resolve_guard(
	guardian_p: Participant,
	target_id: int,
	guardian: L5RCharacterData = null,
	target_p: Participant = null,
) -> void:
	## Guard maneuver (s40): guardian designates one person within 5 feet.
	## The caller must verify stance != Full Attack and target proximity.
	## Sets guarding_id; get_armor_tn() applies +10 to guarded and -5 to guardian.
	guardian_p.guarding_id = target_id
	# void_phoenix_guard_bonus kata: guarded character gains +3 Armor TN (s30a)
	if guardian != null and target_p != null and _has_kata_effect(guardian, "void_phoenix_guard_bonus"):
		target_p.guard_kata_bonus = 3


static func clear_guard(guardian_p: Participant) -> void:
	guardian_p.guarding_id = -1


# =============================================================================
# -- Turn Management (s40) ----------------------------------------------------
# =============================================================================

static func begin_turn(participant: Participant) -> void:
	## Clears once-per-Turn kata tracking at the start of a character's turn.
	## Call this before the character resolves their first action in a round.
	participant.kata_used_this_turn.clear()
	participant.extra_attack_used_this_turn = false
	participant.off_hand_attack_used_this_turn = false
	participant.earth_trade_amount = 0
	participant.water_trade_armor_amount = 0


static func declare_earth_armor_trade(participant: Participant, tn_reduction: int) -> void:
	## Declare how much Armor TN to trade for damage bonus this action (earth_trade_armor_for_damage kata, s30a).
	participant.earth_trade_amount = maxi(0, tn_reduction)


static func declare_earth_initiative_trade(participant: Participant, tn_bonus: int) -> void:
	## Declare how much Initiative score to trade for Armor TN this round (earth_trade_initiative_for_armor kata, s30a).
	participant.earth_init_trade_amount = maxi(0, tn_bonus)


static func declare_water_armor_trade(participant: Participant, tn_reduction: int) -> void:
	## Declare how much Armor TN to trade for movement this action (water_trade_armor_for_movement kata, s30a).
	participant.water_trade_armor_amount = maxi(0, tn_reduction)


static func get_dual_wield_armor_tn_bonus(character: L5RCharacterData, participant: Participant) -> int:
	## Returns +InsightRank Armor TN bonus for dual-wielding (s40).
	## Also included in get_armor_tn() when participant.dual_wielding is true.
	if participant.dual_wielding:
		return CharacterStats.get_insight_rank(character)
	return 0


# =============================================================================
# -- Off-hand and Extra Attack (s40) ------------------------------------------
# =============================================================================

static func resolve_off_hand_attack(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	off_hand_weapon_name: String,
	target_armor_tn: int,
	dice_engine: DiceEngine,
	spend_void: bool = false,
	adv_context: Dictionary = {},
) -> Dictionary:
	## Off-hand weapon attack (s40). Penalty by weapon size: Small=-5, Medium=-10, Large=-15.
	## Dominant hand attacks while holding off-hand weapon take DOMINANT_HAND_PENALTY (-5).
	var weapon: Dictionary = get_weapon_profile(off_hand_weapon_name)
	var skill_name: String = weapon.get("skill", "Kenjutsu")
	var skill_rank: int = attacker.skills.get(skill_name, 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(attacker)
	var size: String = weapon.get("size", "Medium")
	var off_hand_pen: int = OFF_HAND_PENALTY.get(size, -10)

	var rolled: int = attacker.agility + skill_rank
	var kept: int = attacker.agility

	var void_used: bool = false
	if spend_void and VoidSystem.can_spend(attacker) and not attacker_p.void_spent_this_round:
		var vbonus: Dictionary = VoidSystem.spend_for_roll(attacker)
		if vbonus["success"]:
			rolled += vbonus["rolled_bonus"]
			kept += vbonus["kept_bonus"]
			attacker_p.void_spent_this_round = true
			void_used = true

	# Mutation modifiers (s44): EXTRA_LIMB non-functional, etc.
	var mut_off: Dictionary = MutationSystem.get_skill_modifiers(attacker, skill_name)
	rolled += mut_off["rolled"]
	kept += mut_off["kept"]
	# Advantage/disadvantage modifiers (s45): CONSUMED Perfection, HEART_OF_VENGEANCE, etc.
	var is_sch_off: bool = NPCAdvancement.get_school_skills(attacker).has(skill_name)
	var adv_ctx_off: Dictionary = {"is_combat": true, "is_school_skill": is_sch_off}
	adv_ctx_off.merge(adv_context)
	var adv_off: Dictionary = AdvantageSystem.get_skill_bonus(attacker, skill_name, adv_ctx_off)
	var adv_tn_off: int = AdvantageSystem.get_tn_modifier(attacker, adv_ctx_off)
	rolled += adv_off["rolled"]
	kept += adv_off["kept"]

	var flat_bonus: int = wound_penalty - get_condition_roll_penalty(attacker_p) + off_hand_pen
	flat_bonus += adv_off["free_raises"] * 5 - adv_tn_off
	var result: Dictionary = dice_engine.roll_check(rolled, kept, target_armor_tn, 0, flat_bonus, skill_rank > 0)

	return {
		"success": result["success"],
		"hit": result["success"],
		"roll": result["total"],
		"target_tn": result["tn"],
		"margin": result["margin"],
		"off_hand_penalty": off_hand_pen,
		"void_used": void_used,
	}


static func resolve_extra_attack(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
	target_armor_tn: int,
	dice_engine: DiceEngine,
	adv_context: Dictionary = {},
) -> Dictionary:
	## Extra Attack maneuver (s40): spend 5 Raises (3 with Spinning Blades kata for
	## dual-wielders) on the first attack to immediately make a second attack at 0 Raises.
	## May only be used once per turn.
	if attacker_p.extra_attack_used_this_turn:
		return {"success": false, "reason": "extra_attack_already_used"}

	var required_raises: int = EXTRA_ATTACK_BASE_RAISES
	if attacker_p.dual_wielding and _has_kata_effect(attacker, "fire_extra_attack_3_raises"):
		required_raises = EXTRA_ATTACK_SPINNING_BLADES_RAISES

	var attack: Dictionary = resolve_attack(attacker, attacker_p, weapon_name, target_armor_tn, 0, dice_engine,
		false, false, false, "", adv_context)
	attacker_p.extra_attack_used_this_turn = true
	attack["required_raises"] = required_raises
	attack["spinning_blades_active"] = required_raises == EXTRA_ATTACK_SPINNING_BLADES_RAISES
	return attack


# =============================================================================
# -- Move Actions (s40) -------------------------------------------------------
# =============================================================================

static func get_water_ring_for_terrain(
	character: L5RCharacterData,
	terrain: String,
) -> int:
	var water_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.WATER)
	var athletics_rank: int = character.skills.get("Athletics", 0)
	var penalty: int = MOVEMENT_TERRAIN_WATER_PENALTY.get(terrain, 0)

	# Athletics Rank 5 removes all penalties; Rank 3 reduces Moderate to Basic,
	# reduces Difficult penalty from 2 to 1.
	if athletics_rank >= 5:
		penalty = 0
	elif athletics_rank >= 3:
		penalty = maxi(0, penalty - 1)

	return maxi(1, water_ring - penalty)


static func get_free_move_feet(character: L5RCharacterData, terrain: String = "basic") -> int:
	return get_water_ring_for_terrain(character, terrain) * 5


static func get_simple_move_feet(character: L5RCharacterData, terrain: String = "basic") -> int:
	return get_water_ring_for_terrain(character, terrain) * 10


static func get_max_move_feet(character: L5RCharacterData, terrain: String = "basic") -> int:
	return get_water_ring_for_terrain(character, terrain) * 20


static func resolve_blinded_simple_move(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CONDITION_BLINDED not in participant.conditions:
		return {"required": false}
	var athletics: int = character.skills.get("Athletics", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)
	# Advantage/disadvantage modifiers (s45): CONSUMED Perfection, LAME (leg roll), etc.
	var is_sch_ath: bool = NPCAdvancement.get_school_skills(character).has("Athletics")
	var adv_ath: Dictionary = AdvantageSystem.get_skill_bonus(
		character, "Athletics", {"is_combat": true, "is_school_skill": is_sch_ath})
	var adv_ath_tn: int = AdvantageSystem.get_tn_modifier(character, {"is_combat": true})
	var result: Dictionary = dice_engine.roll_check(
		character.agility + athletics + adv_ath["rolled"],
		character.agility + adv_ath["kept"],
		BLINDED_SIMPLE_MOVE_TN, 0, wound_penalty + adv_ath["free_raises"] * 5 - adv_ath_tn, athletics > 0
	)
	if not result["success"]:
		apply_condition(participant, CONDITION_PRONE)
	return {
		"required": true,
		"success": result["success"],
		"roll": result["total"],
		"tn": BLINDED_SIMPLE_MOVE_TN,
		"fell_prone": not result["success"],
	}


# =============================================================================
# -- Conditional Effects (s40) ------------------------------------------------
# =============================================================================

static func apply_condition(participant: Participant, condition: String) -> void:
	if not condition in participant.conditions:
		participant.conditions.append(condition)


static func remove_condition(participant: Participant, condition: String) -> void:
	participant.conditions.erase(condition)


static func has_condition(participant: Participant, condition: String) -> bool:
	return condition in participant.conditions


# Project convention (s56.16 exposure layer): ~10 combat Rounds per minute.
const ROUNDS_PER_MINUTE: int = 10


## Timed condition layer: a condition that runs for a fixed number of Rounds and is
## auto-cleared on expiry, NOT shed by a recovery roll (e.g. Paralysis Venom). The
## condition is also placed in `conditions` so all existing gates (Armor TN, attack
## penalty, can-act) fire unchanged. Keeps the longer of an existing/new timer.
static func apply_timed_condition(participant: Participant, condition: String, expiry_round: int) -> void:
	apply_condition(participant, condition)
	var cur: int = int(participant.timed_conditions.get(condition, -1))
	if expiry_round > cur:
		participant.timed_conditions[condition] = expiry_round


static func is_condition_timed(participant: Participant, condition: String) -> bool:
	return participant.timed_conditions.has(condition)


## Sweep timed conditions whose expiry Round has been reached (called from
## advance_round, beside expire_timed_modifiers / expire_active_kiho).
static func expire_timed_conditions(participant: Participant, round_number: int) -> void:
	for cond: String in participant.timed_conditions.keys():
		if round_number >= int(participant.timed_conditions[cond]):
			participant.timed_conditions.erase(cond)
			remove_condition(participant, cond)


static func get_condition_roll_penalty(participant: Participant) -> int:
	if CONDITION_FATIGUED in participant.conditions:
		return 5 + participant.fatigue_days * 5
	return 0


static func attempt_recover_dazed(
	character: L5RCharacterData,
	participant: Participant,
	attempt_number: int,
	dice_engine: DiceEngine,
) -> bool:
	if CONDITION_DAZED not in participant.conditions:
		return false
	var tn: int = maxi(5, 20 - (attempt_number - 1) * 5)  # TN 20, -5 per prior failure
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	# Advantage/disadvantage modifiers (s45): CONSUMED Perfection applies +5 TN
	var adv_dazed_tn: int = AdvantageSystem.get_tn_modifier(character, {"is_combat": true})
	var result: Dictionary = dice_engine.roll_check(earth_ring, earth_ring, tn, 0, -adv_dazed_tn)
	if result["success"]:
		remove_condition(participant, CONDITION_DAZED)
		return true
	return false


static func attempt_recover_stunned(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
) -> bool:
	if CONDITION_STUNNED not in participant.conditions:
		return false
	var earth_ring: int = CharacterStats.get_earth_ring(character)
	# Advantage/disadvantage modifiers (s45): CONSUMED Perfection applies +5 TN
	var adv_stunned_tn: int = AdvantageSystem.get_tn_modifier(character, {"is_combat": true})
	var result: Dictionary = dice_engine.roll_check(earth_ring, earth_ring, 20, 0, -adv_stunned_tn)
	if result["success"]:
		remove_condition(participant, CONDITION_STUNNED)
		return true
	return false


# =============================================================================
# -- Grappling (s40) ----------------------------------------------------------
# =============================================================================

static func initiate_grapple(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	target_armor_tn: int,
	dice_engine: DiceEngine,
	skill_name: String = "Jiujutsu",
) -> Dictionary:
	# s40 "Weapon Grapples": a chain weapon / certain polearm may initiate a
	# grapple using the Weapon Skill in place of Jiujutsu. Trait stays Agility
	# (consistent with melee weapon attacks). Default is the unarmed Jiujutsu grapple.
	var jiujutsu: int = attacker.skills.get(skill_name, 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(attacker)

	# Mutation modifiers (s44) and Advantage modifiers (s45) for the grapple skill
	var mut_jiu_init: Dictionary = MutationSystem.get_skill_modifiers(attacker, skill_name)
	var is_school_jiu_init: bool = NPCAdvancement.get_school_skills(attacker).has(skill_name)
	var adv_jiu_init: Dictionary = AdvantageSystem.get_skill_bonus(
		attacker, skill_name, {"is_combat": true, "is_school_skill": is_school_jiu_init}
	)
	var adv_jiu_init_tn: int = AdvantageSystem.get_tn_modifier(attacker, {"is_combat": true})
	var grapple_flat: int = wound_penalty + adv_jiu_init["free_raises"] * 5 - adv_jiu_init_tn

	# Grapple initiation ignores armor's Armor TN bonus — target TN = Reflexes × 5 + 5
	var result: Dictionary = dice_engine.roll_check(
		attacker.agility + jiujutsu + mut_jiu_init["rolled"] + adv_jiu_init["rolled"],
		attacker.agility + mut_jiu_init["kept"] + adv_jiu_init["kept"],
		target_armor_tn, 0, grapple_flat, jiujutsu > 0
	)
	if result["success"]:
		# Both attacker and target enter the Grapple on success (s40)
		apply_condition(attacker_p, CONDITION_GRAPPLED)
		return {"success": true, "roll": result["total"], "target_tn": target_armor_tn,
			"apply_grappled_to_target": true}
	return {"success": false, "roll": result["total"], "target_tn": target_armor_tn,
		"apply_grappled_to_target": false}


static func resolve_grapple_control(
	attacker: L5RCharacterData,
	defender: L5RCharacterData,
	dice_engine: DiceEngine,
	att_skill: String = "Jiujutsu",
	def_skill: String = "Jiujutsu",
) -> Dictionary:
	# Contested Jiujutsu/Strength: roll (Strength + Jiujutsu), keep Strength (s4.5 / s40)
	# Unskilled (rank 0) rolls do not explode per L5R4e p.78.
	# s40 "Weapon Grapples": a weapon-grappler uses their Weapon Skill in place of
	# Jiujutsu for control rolls; each side passes their own grapple skill.
	var att_jiu: int = attacker.skills.get(att_skill, 0)
	var def_jiu: int = defender.skills.get(def_skill, 0)
	# Mutation modifiers (s44), Advantage modifiers (s45), and wound penalties
	var att_wound: int = CharacterStats.get_wound_penalty(attacker)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)
	var att_mut_ctrl: Dictionary = MutationSystem.get_skill_modifiers(attacker, att_skill)
	var def_mut_ctrl: Dictionary = MutationSystem.get_skill_modifiers(defender, def_skill)
	var att_sch_jiu: bool = NPCAdvancement.get_school_skills(attacker).has(att_skill)
	var def_sch_jiu: bool = NPCAdvancement.get_school_skills(defender).has(def_skill)
	var att_adv_ctrl: Dictionary = AdvantageSystem.get_skill_bonus(attacker, att_skill,
		{"is_combat": true, "is_school_skill": att_sch_jiu, "opponent_clan": defender.clan})
	var def_adv_ctrl: Dictionary = AdvantageSystem.get_skill_bonus(defender, def_skill,
		{"is_combat": true, "is_school_skill": def_sch_jiu, "opponent_clan": attacker.clan})
	var att_result: DiceResult = dice_engine.roll_and_keep(
		attacker.strength + att_jiu + att_mut_ctrl["rolled"] + att_adv_ctrl["rolled"],
		attacker.strength + att_mut_ctrl["kept"] + att_adv_ctrl["kept"], att_jiu > 0,
	)
	var def_result: DiceResult = dice_engine.roll_and_keep(
		defender.strength + def_jiu + def_mut_ctrl["rolled"] + def_adv_ctrl["rolled"],
		defender.strength + def_mut_ctrl["kept"] + def_adv_ctrl["kept"], def_jiu > 0,
	)
	var att_total: int = att_result.total + att_wound
	var def_total: int = def_result.total + def_wound
	var att_wins: bool = att_total >= def_total  # attacker wins ties (s40)
	return {
		"attacker_roll": att_total,
		"defender_roll": def_total,
		"attacker_wins": att_wins,
	}


static func grapple_hit(
	controller: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Hit in grapple: normal unarmed damage, no raises, no attack roll (s40)
	var result: Dictionary = dice_engine.roll_damage(controller.strength, 1)
	return {"damage": result["raw"]}


static func grapple_throw(controller_p: Participant, target_p: Participant) -> void:
	remove_condition(target_p, CONDITION_GRAPPLED)
	apply_condition(target_p, CONDITION_PRONE)
	target_p.grapple_partner_id = -1
	target_p.grapple_in_control = false
	remove_condition(controller_p, CONDITION_GRAPPLED)   # Bug 8 FIX: throw ends grapple for controller too
	controller_p.grapple_partner_id = -1                 # Bug 8 FIX
	controller_p.grapple_in_control = false              # Bug 8 FIX


# Break (s40, Simple Action): the actor removes themselves from the Grapple. A grapple
# is a two-person bind, so both participants are freed (neither remains Grappled to a
# partner who left). Neither is left Prone (unlike Throw).
static func grapple_break(actor_p: Participant, partner_p: Participant) -> void:
	remove_condition(actor_p, CONDITION_GRAPPLED)
	actor_p.grapple_partner_id = -1
	actor_p.grapple_in_control = false
	if partner_p != null:
		remove_condition(partner_p, CONDITION_GRAPPLED)
		partner_p.grapple_partner_id = -1
		partner_p.grapple_in_control = false


# =============================================================================
# -- Sumai (s40) --------------------------------------------------------------
# =============================================================================

static func resolve_sumai_bout(
	wrestler1: L5RCharacterData,
	wrestler2: L5RCharacterData,
	w1_larger: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Unskilled Jiujutsu (rank 0) rolls do not explode per L5R4e p.78.
	var w1_jiu: int = wrestler1.skills.get("Jiujutsu", 0)
	var w2_jiu: int = wrestler2.skills.get("Jiujutsu", 0)
	# Mutation modifiers (s44), Advantage modifiers (s45), and wound penalties
	var w1_wound: int = CharacterStats.get_wound_penalty(wrestler1)
	var w2_wound: int = CharacterStats.get_wound_penalty(wrestler2)
	var w1_mut: Dictionary = MutationSystem.get_skill_modifiers(wrestler1, "Jiujutsu")
	var w2_mut: Dictionary = MutationSystem.get_skill_modifiers(wrestler2, "Jiujutsu")
	var w1_sch: bool = NPCAdvancement.get_school_skills(wrestler1).has("Jiujutsu")
	var w2_sch: bool = NPCAdvancement.get_school_skills(wrestler2).has("Jiujutsu")
	var w1_adv: Dictionary = AdvantageSystem.get_skill_bonus(wrestler1, "Jiujutsu",
		{"is_combat": true, "is_school_skill": w1_sch, "opponent_clan": wrestler2.clan})
	var w2_adv: Dictionary = AdvantageSystem.get_skill_bonus(wrestler2, "Jiujutsu",
		{"is_combat": true, "is_school_skill": w2_sch, "opponent_clan": wrestler1.clan})
	var w1_rolled: int = wrestler1.strength + w1_jiu + (1 if w1_larger else 0) + w1_mut["rolled"] + w1_adv["rolled"]
	var w2_rolled: int = wrestler2.strength + w2_jiu + w2_mut["rolled"] + w2_adv["rolled"]
	var w1_result: DiceResult = dice_engine.roll_and_keep(w1_rolled, wrestler1.strength + w1_mut["kept"] + w1_adv["kept"], w1_jiu > 0)
	var w2_result: DiceResult = dice_engine.roll_and_keep(w2_rolled, wrestler2.strength + w2_mut["kept"] + w2_adv["kept"], w2_jiu > 0)
	var w1_total: int = w1_result.total + w1_wound
	var w2_total: int = w2_result.total + w2_wound
	var margin: int = abs(w1_total - w2_total)
	var bout_over: bool = margin >= 5
	return {
		"wrestler1_roll": w1_total,
		"wrestler2_roll": w2_total,
		"winner_wrestler1": w1_total > w2_total and bout_over,
		"winner_wrestler2": w2_total > w1_total and bout_over,
		"bout_over": bout_over,
		"continue": not bout_over,
	}


# Resolve a single sumai MATCH between two wrestlers: repeated Contested Jiujutsu(Sumai)/
# Strength bouts until one wins by 5+ (GDD s40 "SUMAI TOURNAMENTS"). Returns the winner.
# A safety cap (rare repeated <5 margins) decides by the last bout's higher roll. No size
# bonus is applied in tournament pairing (the s45 Large advantage is a forward-wire — the
# bout still contests Strength + Jiujutsu, which captures wrestler quality).
static func resolve_sumai_match(
	w1: L5RCharacterData,
	w2: L5RCharacterData,
	dice_engine: DiceEngine,
) -> L5RCharacterData:
	for _i in 40:
		var r: Dictionary = resolve_sumai_bout(w1, w2, false, dice_engine)
		if r["bout_over"]:
			return w1 if r["winner_wrestler1"] else w2
	# Cap reached (persistent near-ties): decide by one more roll's higher total.
	var f: Dictionary = resolve_sumai_bout(w1, w2, false, dice_engine)
	return w1 if f["wrestler1_roll"] >= f["wrestler2_roll"] else w2


# Single-elimination sumai TOURNAMENT (GDD s40 / s27.9 Badger Great Games). Pairs the
# entrants, runs each match to a 5+ decision, advances winners; an odd entrant gets a bye.
# Returns {champion_id, participant_count, rounds} ({} for fewer than 2 entrants).
static func resolve_sumai_tournament(
	participants: Array,
	dice_engine: DiceEngine,
) -> Dictionary:
	if participants.size() < 2:
		return {}
	var bracket: Array = participants.duplicate()
	var rounds: int = 0
	while bracket.size() > 1:
		rounds += 1
		var next_round: Array = []
		var i: int = 0
		while i < bracket.size():
			if i + 1 >= bracket.size():
				next_round.append(bracket[i])  # bye
				i += 1
				continue
			next_round.append(resolve_sumai_match(bracket[i], bracket[i + 1], dice_engine))
			i += 2
		bracket = next_round
	var champ: L5RCharacterData = bracket[0]
	return {
		"champion_id": champ.character_id,
		"participant_count": participants.size(),
		"rounds": rounds,
	}


static func resolve_sumai_stare_down(
	wrestler1: L5RCharacterData,
	wrestler2: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var intim1: int = wrestler1.skills.get("Intimidation", 0)
	var intim2: int = wrestler2.skills.get("Intimidation", 0)
	# Advantage/disadvantage modifiers (s45) + wound penalties
	var w1_wound: int = CharacterStats.get_wound_penalty(wrestler1)
	var w2_wound: int = CharacterStats.get_wound_penalty(wrestler2)
	var w1_sch_i: bool = NPCAdvancement.get_school_skills(wrestler1).has("Intimidation")
	var w2_sch_i: bool = NPCAdvancement.get_school_skills(wrestler2).has("Intimidation")
	var w1_adv_s: Dictionary = AdvantageSystem.get_skill_bonus(
		wrestler1, "Intimidation", {"is_combat": true, "is_contested": true, "is_school_skill": w1_sch_i, "opponent_clan": wrestler2.clan}
	)
	var w2_adv_s: Dictionary = AdvantageSystem.get_skill_bonus(
		wrestler2, "Intimidation", {"is_combat": true, "is_contested": true, "is_school_skill": w2_sch_i, "opponent_clan": wrestler1.clan}
	)
	var w1_tn_s: int = AdvantageSystem.get_tn_modifier(wrestler1, {"is_combat": true, "is_contested": true})
	var w2_tn_s: int = AdvantageSystem.get_tn_modifier(wrestler2, {"is_combat": true, "is_contested": true})
	var w1_rolled_s: int = maxi(wrestler1.willpower + intim1 + w1_adv_s["rolled"], 1)
	var w2_rolled_s: int = maxi(wrestler2.willpower + intim2 + w2_adv_s["rolled"], 1)
	var w1_kept_s: int = maxi(wrestler1.willpower + w1_adv_s["kept"], 1)
	var w2_kept_s: int = maxi(wrestler2.willpower + w2_adv_s["kept"], 1)
	var w1_flat_s: int = w1_adv_s["free_raises"] * 5 - w1_tn_s
	var w2_flat_s: int = w2_adv_s["free_raises"] * 5 - w2_tn_s
	var r1: DiceResult = dice_engine.roll_and_keep(w1_rolled_s, w1_kept_s, intim1 > 0)
	var r2: DiceResult = dice_engine.roll_and_keep(w2_rolled_s, w2_kept_s, intim2 > 0)
	var t1: int = r1.total + w1_flat_s + w1_wound
	var t2: int = r2.total + w2_flat_s + w2_wound
	var wrestler1_wins: bool = t1 >= t2
	var margin: int = abs(t1 - t2)
	return {
		"wrestler1_roll": t1,
		"wrestler2_roll": t2,
		"wrestler1_wins": wrestler1_wins,
		"grants_bonus": margin >= 5,
	}


# =============================================================================
# -- Iaijutsu Pre-Duel Stare-Down (s4.8) --------------------------------------
# =============================================================================

static func resolve_iaijutsu_stare_down(
	challenger: L5RCharacterData,
	defender: L5RCharacterData,
	duel: DuelState,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ch_intim: int = challenger.skills.get("Intimidation", 0)
	var def_intim: int = defender.skills.get("Intimidation", 0)
	# Advantage/disadvantage modifiers (s45) + wound penalties
	var ch_wound: int = CharacterStats.get_wound_penalty(challenger)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)
	var ch_sch_sd: bool = NPCAdvancement.get_school_skills(challenger).has("Intimidation")
	var def_sch_sd: bool = NPCAdvancement.get_school_skills(defender).has("Intimidation")
	var ch_adv_sd: Dictionary = AdvantageSystem.get_skill_bonus(
		challenger, "Intimidation", {"is_combat": true, "is_contested": true, "is_school_skill": ch_sch_sd, "opponent_clan": defender.clan}
	)
	var def_adv_sd: Dictionary = AdvantageSystem.get_skill_bonus(
		defender, "Intimidation", {"is_combat": true, "is_contested": true, "is_school_skill": def_sch_sd, "opponent_clan": challenger.clan}
	)
	var ch_tn_sd: int = AdvantageSystem.get_tn_modifier(challenger, {"is_combat": true, "is_contested": true})
	var def_tn_sd: int = AdvantageSystem.get_tn_modifier(defender, {"is_combat": true, "is_contested": true})
	var ch_rolled_sd: int = maxi(challenger.willpower + ch_intim + ch_adv_sd["rolled"], 1)
	var def_rolled_sd: int = maxi(defender.willpower + def_intim + def_adv_sd["rolled"], 1)
	var ch_kept_sd: int = maxi(challenger.willpower + ch_adv_sd["kept"], 1)
	var def_kept_sd: int = maxi(defender.willpower + def_adv_sd["kept"], 1)
	var ch_r_sd: DiceResult = dice_engine.roll_and_keep(ch_rolled_sd, ch_kept_sd, ch_intim > 0)
	var def_r_sd: DiceResult = dice_engine.roll_and_keep(def_rolled_sd, def_kept_sd, def_intim > 0)
	var ch_total_sd: int = ch_r_sd.total + (ch_adv_sd["free_raises"] * 5) - ch_tn_sd + ch_wound
	var def_total_sd: int = def_r_sd.total + (def_adv_sd["free_raises"] * 5) - def_tn_sd + def_wound
	if ch_total_sd == def_total_sd:
		return {"attempted": true, "resolved": false, "penalty_id": -1}
	var winner_is_challenger: bool = ch_total_sd > def_total_sd
	if winner_is_challenger:
		duel.stare_down_penalty_id = duel.defender_id
	else:
		duel.stare_down_penalty_id = duel.challenger_id
	return {
		"attempted": true,
		"resolved": true,
		"challenger_roll": ch_total_sd,
		"defender_roll": def_total_sd,
		"penalty_id": duel.stare_down_penalty_id,
	}


# =============================================================================
# -- Iaijutsu Dueling (s40) ---------------------------------------------------
# =============================================================================

static func create_duel(
	challenger_id: int,
	defender_id: int,
	to_death: bool = false,
) -> DuelState:
	var duel := DuelState.new()
	duel.challenger_id = challenger_id
	duel.defender_id = defender_id
	duel.duel_to_death = to_death
	return duel


static func resolve_duel_assessment(
	challenger: L5RCharacterData,
	defender: L5RCharacterData,
	duel: DuelState,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Each makes Iaijutsu (Assessment)/Awareness roll; TN = 10 + opponent InsightRank * 5
	var ch_iai: int = challenger.skills.get("Iaijutsu", 0)
	var def_iai: int = defender.skills.get("Iaijutsu", 0)
	var ch_tn: int = 10 + CharacterStats.get_insight_rank(defender) * 5
	var def_tn: int = 10 + CharacterStats.get_insight_rank(challenger) * 5

	var ch_stare_penalty: int = 1 if duel.stare_down_penalty_id == duel.challenger_id else 0
	var def_stare_penalty: int = 1 if duel.stare_down_penalty_id == duel.defender_id else 0

	# Mutation modifiers (s44): EXTRA_LIMB non-functional applies -1k0 to Iaijutsu
	var ch_mut_ass: Dictionary = MutationSystem.get_skill_modifiers(challenger, "Iaijutsu")
	var def_mut_ass: Dictionary = MutationSystem.get_skill_modifiers(defender, "Iaijutsu")

	# Advantage/disadvantage modifiers (s45): CONSUMED, PRODIGY, etc.
	var ch_school_iai: bool = NPCAdvancement.get_school_skills(challenger).has("Iaijutsu")
	var def_school_iai: bool = NPCAdvancement.get_school_skills(defender).has("Iaijutsu")
	var ch_adv_ctx: Dictionary = {"is_combat": true, "is_school_skill": ch_school_iai, "opponent_clan": defender.clan}
	var def_adv_ctx: Dictionary = {"is_combat": true, "is_school_skill": def_school_iai, "opponent_clan": challenger.clan}
	var ch_adv_ass: Dictionary = AdvantageSystem.get_skill_bonus(challenger, "Iaijutsu", ch_adv_ctx)
	var def_adv_ass: Dictionary = AdvantageSystem.get_skill_bonus(defender, "Iaijutsu", def_adv_ctx)
	var ch_tn_ass: int = AdvantageSystem.get_tn_modifier(challenger, ch_adv_ctx)
	var def_tn_ass: int = AdvantageSystem.get_tn_modifier(defender, def_adv_ctx)

	var ch_rolled: int = maxi(challenger.awareness + ch_iai - ch_stare_penalty + ch_mut_ass["rolled"] + ch_adv_ass["rolled"], 1)
	var def_rolled: int = maxi(defender.awareness + def_iai - def_stare_penalty + def_mut_ass["rolled"] + def_adv_ass["rolled"], 1)
	var ch_flat: int = ch_adv_ass["free_raises"] * 5 - ch_tn_ass
	var def_flat: int = def_adv_ass["free_raises"] * 5 - def_tn_ass
	var ch_explodes: bool = ch_iai > 0
	var def_explodes: bool = def_iai > 0
	var ch_wound: int = CharacterStats.get_wound_penalty(challenger)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)

	var ch_result: Dictionary = dice_engine.roll_check(
		ch_rolled, challenger.awareness + ch_mut_ass["kept"] + ch_adv_ass["kept"], ch_tn, 0, ch_flat + ch_wound, ch_explodes
	)
	var def_result: Dictionary = dice_engine.roll_check(
		def_rolled, defender.awareness + def_mut_ass["kept"] + def_adv_ass["kept"], def_tn, 0, def_flat + def_wound, def_explodes
	)

	var ch_learned: Array = []
	var def_learned: Array = []

	# On success, learn one piece of info (+1 per Raise); see s40 for full info list
	if ch_result["success"]:
		ch_learned.append("basic_info")
	if def_result["success"]:
		def_learned.append("basic_info")

	# If one beats the other by 10+, the winner gains +1k1 on Focus roll
	var margin: int = ch_result["total"] - def_result["total"]
	if margin >= 10:
		duel.assessment_bonus_id = duel.challenger_id
	elif margin <= -10:
		duel.assessment_bonus_id = duel.defender_id

	return {
		"challenger_roll": ch_result["total"],
		"defender_roll": def_result["total"],
		"challenger_tn": ch_tn,
		"defender_tn": def_tn,
		"challenger_succeeded": ch_result["success"],
		"defender_succeeded": def_result["success"],
		"assessment_bonus_id": duel.assessment_bonus_id,
		"challenger_learned": ch_learned,
		"defender_learned": def_learned,
	}


static func concede_at_assessment(
	conceder_id: int,
	duel: DuelState,
) -> Dictionary:
	duel.conceded_id = conceder_id
	duel.is_over = true
	if conceder_id == duel.challenger_id:
		duel.winner_id = duel.defender_id
		duel.loser_id = duel.challenger_id
	else:
		duel.winner_id = duel.challenger_id
		duel.loser_id = duel.defender_id
	return {
		"conceded": true,
		"conceder_id": conceder_id,
		"winner_id": duel.winner_id,
		"honor_change": 0.0,
		"glory_change": 0.0,
	}


static func resolve_duel_focus(
	challenger: L5RCharacterData,
	defender: L5RCharacterData,
	duel: DuelState,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Contested Iaijutsu (Focus)/Void Roll
	var ch_iai: int = challenger.skills.get("Iaijutsu", 0)
	var def_iai: int = defender.skills.get("Iaijutsu", 0)

	var ch_rolled: int = ch_iai + challenger.void_ring
	var ch_kept: int = challenger.void_ring
	var def_rolled: int = def_iai + defender.void_ring
	var def_kept: int = defender.void_ring

	# Mutation modifiers (s44): EXTRA_LIMB non-functional applies -1k0 to Iaijutsu
	var ch_mut_foc: Dictionary = MutationSystem.get_skill_modifiers(challenger, "Iaijutsu")
	var def_mut_foc: Dictionary = MutationSystem.get_skill_modifiers(defender, "Iaijutsu")
	ch_rolled += ch_mut_foc["rolled"]
	ch_kept += ch_mut_foc["kept"]
	def_rolled += def_mut_foc["rolled"]
	def_kept += def_mut_foc["kept"]

	# Advantage/disadvantage modifiers (s45): HEART_OF_VENGEANCE, CONSUMED, PRODIGY, etc.
	var ch_school_foc: bool = NPCAdvancement.get_school_skills(challenger).has("Iaijutsu")
	var def_school_foc: bool = NPCAdvancement.get_school_skills(defender).has("Iaijutsu")
	var ch_adv_focus: Dictionary = AdvantageSystem.get_skill_bonus(
		challenger, "Iaijutsu", {"is_combat": true, "is_contested": true, "is_school_skill": ch_school_foc, "opponent_clan": defender.clan}
	)
	var def_adv_focus: Dictionary = AdvantageSystem.get_skill_bonus(
		defender, "Iaijutsu", {"is_combat": true, "is_contested": true, "is_school_skill": def_school_foc, "opponent_clan": challenger.clan}
	)
	ch_rolled += ch_adv_focus["rolled"]
	ch_kept += ch_adv_focus["kept"]
	def_rolled += def_adv_focus["rolled"]
	def_kept += def_adv_focus["kept"]

	# +1k1 bonus from winning Assessment by 10+
	if duel.assessment_bonus_id == duel.challenger_id:
		ch_rolled += 1
		ch_kept += 1
	elif duel.assessment_bonus_id == duel.defender_id:
		def_rolled += 1
		def_kept += 1

	var ch_explodes: bool = ch_iai > 0
	var def_explodes: bool = def_iai > 0
	var ch_wound: int = CharacterStats.get_wound_penalty(challenger)
	var def_wound: int = CharacterStats.get_wound_penalty(defender)
	var ch_result: DiceResult = dice_engine.roll_and_keep(ch_rolled, ch_kept, ch_explodes)
	var def_result: DiceResult = dice_engine.roll_and_keep(def_rolled, def_kept, def_explodes)
	var ch_total: int = ch_result.total + ch_wound
	var def_total: int = def_result.total + def_wound

	var margin: int = ch_total - def_total

	if abs(margin) < 5:
		duel.simultaneous = true
		duel.first_striker_id = -1
		duel.free_raises_first = 0
	elif margin > 0:
		duel.first_striker_id = duel.challenger_id
		duel.free_raises_first = abs(margin) / 5
		duel.simultaneous = false
	else:
		duel.first_striker_id = duel.defender_id
		duel.free_raises_first = abs(margin) / 5
		duel.simultaneous = false

	return {
		"challenger_roll": ch_total,
		"defender_roll": def_total,
		"margin": margin,
		"first_striker_id": duel.first_striker_id,
		"free_raises_for_first": duel.free_raises_first,
		"simultaneous": duel.simultaneous,
	}


static func _iaijutsu_attack(
	striker: L5RCharacterData,
	striker_p: Participant,
	target_tn: int,
	dice_engine: DiceEngine,
	spend_void: bool = false,
) -> Dictionary:
	# Duel strike: Iaijutsu/Reflexes attack roll (s40 — explicit "Iaijutsu/Reflexes attack roll")
	var iai_rank: int = striker.skills.get("Iaijutsu", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(striker)
	var rolled: int = striker.reflexes + iai_rank
	var kept: int = striker.reflexes

	# Center Stance carry-over: +1k1 + Void Ring on the first roll of the turn (s40)
	var flat_bonus: int = wound_penalty - get_condition_roll_penalty(striker_p)
	if striker_p.void_ring_bonus > 0 and not striker_p.center_stance_bonus_used:
		rolled += 1
		kept += 1
		flat_bonus += striker_p.void_ring_bonus
		striker_p.center_stance_bonus_used = true

	# Void spend for +1k1 (or +2k2) on duel strike (RAW). Not valid for Damage Rolls.
	var void_used: bool = false
	if spend_void and VoidSystem.can_spend(striker) and not striker_p.void_spent_this_round:
		var vbonus: Dictionary = VoidSystem.spend_for_roll(striker)
		if vbonus["success"]:
			rolled += vbonus["rolled_bonus"]
			kept += vbonus["kept_bonus"]
			striker_p.void_spent_this_round = true
			void_used = true

	# Mutation modifiers (s44): EXTRA_LIMB non-functional applies -1k0 to weapon skills
	var mutation_iai: Dictionary = MutationSystem.get_skill_modifiers(striker, "Iaijutsu")
	rolled += mutation_iai["rolled"]
	kept += mutation_iai["kept"]

	# Advantage/disadvantage modifiers (s45): HEART_OF_VENGEANCE, PRODIGY, CONSUMED, etc.
	var is_school_iai: bool = NPCAdvancement.get_school_skills(striker).has("Iaijutsu")
	var adv_iai: Dictionary = AdvantageSystem.get_skill_bonus(
		striker, "Iaijutsu", {"is_combat": true, "is_school_skill": is_school_iai}
	)
	rolled += adv_iai["rolled"]
	kept += adv_iai["kept"]
	flat_bonus += adv_iai["free_raises"] * 5
	flat_bonus -= AdvantageSystem.get_tn_modifier(striker, {"is_combat": true, "is_school_skill": is_school_iai})

	# Free Raises from Focus grant effects without raising TN (s40); applied as
	# Increased Damage in resolve_duel_strike(), so raises=0 here.
	# Unskilled Iaijutsu (rank 0) does not explode per L5R4e p.78.
	var result: Dictionary = dice_engine.roll_check(rolled, kept, target_tn, 0, flat_bonus, iai_rank > 0)
	return {
		"success": result["success"],
		"hit": result["success"],
		"roll": result["total"],
		"target_tn": result["tn"],
		"margin": result["margin"],
		"void_used": void_used,
	}


static func resolve_duel_strike(
	first_striker: L5RCharacterData,
	first_striker_p: Participant,
	second_striker: L5RCharacterData,
	second_striker_p: Participant,
	duel: DuelState,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Both duelists in Center Stance for the full duel
	var first_armor_tn: int = get_armor_tn(second_striker, second_striker_p, dice_engine)
	var first_attack: Dictionary = _iaijutsu_attack(
		first_striker, first_striker_p, first_armor_tn, dice_engine
	)

	var first_damage: Dictionary = {}
	var first_wounds: Dictionary = {}
	if first_attack.get("hit", false):
		# Free Raises from Focus applied as Increased Damage (+1k0 per Raise, s40)
		first_damage = resolve_damage(first_striker, "katana", duel.free_raises_first, 0, dice_engine, first_striker_p)
		first_wounds = WoundSystem.apply_damage(second_striker, first_damage["raw_damage"])

	var first_blood_drawn: bool = not duel.duel_to_death and first_attack.get("hit", false)
	var second_may_strike: bool = duel.simultaneous or (
		not duel.simultaneous
		and not CharacterStats.is_dead(second_striker)
		and not first_blood_drawn
	)

	var second_damage: Dictionary = {}
	var second_wounds: Dictionary = {}
	var second_attack: Dictionary = {}
	if second_may_strike:
		var second_armor_tn: int = get_armor_tn(first_striker, first_striker_p, dice_engine)
		second_attack = _iaijutsu_attack(
			second_striker, second_striker_p, second_armor_tn, dice_engine
		)
		if second_attack.get("hit", false):
			second_damage = resolve_damage(second_striker, "katana", 0, 0, dice_engine, second_striker_p)
			second_wounds = WoundSystem.apply_damage(first_striker, second_damage["raw_damage"])

	var first_dead: bool = CharacterStats.is_dead(first_striker)
	var second_dead: bool = CharacterStats.is_dead(second_striker)

	if duel.simultaneous:
		duel.is_over = true
		if first_dead and not second_dead:
			duel.winner_id = second_striker.character_id
			duel.loser_id = first_striker.character_id
		elif second_dead and not first_dead:
			duel.winner_id = first_striker.character_id
			duel.loser_id = second_striker.character_id
		else:
			duel.winner_id = -1
			duel.loser_id = -1
	elif first_blood_drawn:
		duel.winner_id = first_striker.character_id
		duel.loser_id = second_striker.character_id
		duel.is_over = true
	elif second_dead:
		duel.winner_id = first_striker.character_id
		duel.loser_id = second_striker.character_id
		duel.is_over = true
	elif first_dead:
		duel.winner_id = second_striker.character_id
		duel.loser_id = first_striker.character_id
		duel.is_over = true
	elif not duel.duel_to_death and second_attack.get("hit", false):
		duel.winner_id = second_striker.character_id
		duel.loser_id = first_striker.character_id
		duel.is_over = true

	return {
		"simultaneous": duel.simultaneous,
		"first_striker_id": first_striker.character_id if not duel.simultaneous else -1,
		"first_attack": first_attack,
		"first_damage": first_damage,
		"first_wounds": first_wounds,
		"second_attack": second_attack,
		"second_damage": second_damage,
		"second_wounds": second_wounds,
		"winner_id": duel.winner_id,
		"is_over": duel.is_over,
		"first_blood_drawn": first_blood_drawn,
	}


static func resolve_strike_after_first_blood(
	striker: L5RCharacterData,
	striker_p: Participant,
	target: L5RCharacterData,
	target_p: Participant,
	duel: DuelState,
	dice_engine: DiceEngine,
) -> Dictionary:
	duel.struck_after_first_blood = true
	var target_armor_tn: int = get_armor_tn(target, target_p, dice_engine)
	var attack: Dictionary = _iaijutsu_attack(striker, striker_p, target_armor_tn, dice_engine)
	var damage: Dictionary = {}
	var wounds: Dictionary = {}
	if attack.get("hit", false):
		damage = resolve_damage(striker, "katana", 0, 0, dice_engine, striker_p)
		wounds = WoundSystem.apply_damage(target, damage["raw_damage"])
	return {
		"struck_after_first_blood": true,
		"attack": attack,
		"damage": damage,
		"wounds": wounds,
		"honor_change": 0.0,
	}


static func resolve_full_duel(
	challenger: L5RCharacterData,
	defender: L5RCharacterData,
	to_death: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	var duel: DuelState = create_duel(
		challenger.character_id, defender.character_id, to_death
	)
	var ch_p := Participant.new()
	ch_p.character_id = challenger.character_id
	ch_p.stance = Enums.Stance.CENTER
	var def_p := Participant.new()
	def_p.character_id = defender.character_id
	def_p.stance = Enums.Stance.CENTER

	var assessment: Dictionary = resolve_duel_assessment(challenger, defender, duel, dice_engine)
	var focus: Dictionary = resolve_duel_focus(challenger, defender, duel, dice_engine)

	var first_char: L5RCharacterData
	var second_char: L5RCharacterData
	var first_p: Participant
	var second_p: Participant
	if duel.simultaneous or duel.first_striker_id == duel.challenger_id:
		first_char = challenger
		first_p = ch_p
		second_char = defender
		second_p = def_p
	else:
		first_char = defender
		first_p = def_p
		second_char = challenger
		second_p = ch_p

	# Both duelists in Center Stance throughout — by the Strike round (Round 3), they
	# have accumulated the Center Stance +1k1+VoidRing bonus (s40: "primarily useful
	# for iaijutsu dueling"). Set it now so _iaijutsu_attack() can consume it.
	ch_p.void_ring_bonus = challenger.void_ring
	def_p.void_ring_bonus = defender.void_ring

	var strike: Dictionary = resolve_duel_strike(
		first_char, first_p, second_char, second_p, duel, dice_engine
	)

	return {
		"assessment": assessment,
		"focus": focus,
		"strike": strike,
		"winner_id": duel.winner_id,
		"loser_id": duel.loser_id,
		"simultaneous": duel.simultaneous,
		"challenger_id": challenger.character_id,
		"defender_id": defender.character_id,
	}


# =============================================================================
# -- Round Advancement (s40) --------------------------------------------------
# =============================================================================

static func begin_round(state: CombatState) -> void:
	state.round_number += 1
	_sort_turn_order(state)
	state.current_turn_index = 0
	for p: Participant in state.participants.values():
		p.has_acted_this_round = false
		p.is_delaying = false
		p.void_spent_this_round = false
		p.void_armor_tn_bonus = 0
		p.void_roll_pending_rolled = 0
		p.void_roll_pending_kept = 0
		p.kata_used_this_round.clear()
		p.extra_attack_used_this_turn = false
		p.earth_init_trade_amount = 0
		# Expire unconsumed Center Stance bonus — it lasts only the round it's earned (s40).
		# If the bonus was consumed, advance_round_reactions() already cleared it.
		if p.void_ring_bonus > 0 and not p.center_stance_bonus_used:
			p.void_ring_bonus = 0


static func advance_round_reactions(
	state: CombatState,
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Array:
	var events: Array = []
	for cid: int in state.participants:
		var p: Participant = state.participants[cid]
		var c: L5RCharacterData = characters_by_id.get(cid)
		if c == null:
			continue
		# Dazed recovery attempt — TN starts at 20, decreases by 5 per prior failure (s40).
		# A timed condition (e.g. venom) runs its full duration and is not rolled off.
		if CONDITION_DAZED in p.conditions and not is_condition_timed(p, CONDITION_DAZED):
			var recovered: bool = attempt_recover_dazed(c, p, p.daze_failed_recovery_attempts + 1, dice_engine)
			if recovered:
				p.daze_failed_recovery_attempts = 0
				events.append({"type": "condition_cleared", "condition": CONDITION_DAZED, "character_id": cid})
			else:
				p.daze_failed_recovery_attempts += 1
		# Stunned recovery (timed Stun, e.g. Paralysis Venom, is not rolled off)
		if CONDITION_STUNNED in p.conditions and not is_condition_timed(p, CONDITION_STUNNED):
			var recovered: bool = attempt_recover_stunned(c, p, dice_engine)
			if recovered:
				events.append({"type": "condition_cleared", "condition": CONDITION_STUNNED, "character_id": cid})
		# air_initiative_stack kata: +2 Initiative each Reactions Stage (s30a)
		if _has_kata_effect(c, "air_initiative_stack"):
			p.initiative_score += 2
		# Clear Center Stance bonus after reactions
		if p.center_stance_bonus_used:
			p.void_ring_bonus = 0
			p.center_stance_bonus_used = false

	return events


static func check_combat_over(
	state: CombatState,
	characters_by_id: Dictionary,
) -> bool:
	var alive: Array = []
	for cid: int in state.participants:
		var c: L5RCharacterData = characters_by_id.get(cid)
		if c != null and not CharacterStats.is_dead(c):
			alive.append(cid)
	if alive.size() <= 1:
		state.is_over = true
		if alive.size() == 1:
			state.winner_id = alive[0]
		return true
	return false


# =============================================================================
# -- WeaponData Integration (s40) ---------------------------------------------
# =============================================================================

static func get_weapon_data(weapon_name: String) -> WeaponData:
	## Returns a typed WeaponData populated from WEAPON_CATALOG for the given weapon name.
	## Falls back to DEFAULT_WEAPON values if name is unknown.
	var profile: Dictionary = get_weapon_profile(weapon_name)
	var wd := WeaponData.new()
	wd.weapon_name = weapon_name
	wd.rolled = profile.get("rolled", DEFAULT_WEAPON["rolled"])
	wd.kept = profile.get("kept", DEFAULT_WEAPON["kept"])
	wd.strength_adds = profile.get("strength_adds", true)
	wd.skill = profile.get("skill", DEFAULT_WEAPON["skill"])
	wd.size = profile.get("size", DEFAULT_WEAPON["size"])
	wd.melee = profile.get("melee", true)
	wd.attack_trait = profile.get("trait", DEFAULT_WEAPON["trait"])
	return wd


static func pick_best_weapon(character: L5RCharacterData) -> String:
	## Selects the weapon name from WEAPON_CATALOG for which the character has the highest skill rank.
	## Used by the NPC summary roll when no explicit weapon is assigned.
	## Returns "unarmed" for characters with no weapon skills.
	var best_weapon: String = "unarmed"
	var best_score: int = 0
	for weapon_name: String in WEAPON_CATALOG:
		var profile: Dictionary = WEAPON_CATALOG[weapon_name]
		var skill: String = profile.get("skill", "")
		if skill.is_empty():
			continue
		var rank: int = character.skills.get(skill, 0)
		if rank > best_score:
			best_score = rank
			best_weapon = weapon_name
	return best_weapon


# =============================================================================
# -- NPC Summary Combat (s40 — design decision: single-exchange model) --------
# =============================================================================

static func resolve_npc_summary_combat(
	attacker: L5RCharacterData,
	defender: L5RCharacterData,
	dice_engine: DiceEngine,
	attacker_weapon: String = "",
	defender_weapon: String = "",
) -> Dictionary:
	## Single-exchange NPC vs NPC resolution per design decision (summary roll model).
	## Both combatants attack simultaneously in Attack Stance. Damage is applied from
	## successful hits. Winner is determined by wound outcome; roll total breaks ties.
	## Returns winner_id (-1 = tie), wounds delivered to each side, and full roll details.

	var att_wname: String = attacker_weapon if attacker_weapon != "" else pick_best_weapon(attacker)
	var def_wname: String = defender_weapon if defender_weapon != "" else pick_best_weapon(defender)

	var att_p := Participant.new()
	att_p.stance = Enums.Stance.ATTACK
	var def_p := Participant.new()
	def_p.stance = Enums.Stance.ATTACK

	var att_armor_tn: int = get_armor_tn(attacker, att_p, dice_engine)
	var def_armor_tn: int = get_armor_tn(defender, def_p, dice_engine)

	# Pass opponent_clan for HEART_OF_VENGEANCE advantage check (s45).
	var att_attack: Dictionary = resolve_attack(attacker, att_p, att_wname, def_armor_tn, 0, dice_engine,
		false, false, false, "", {"opponent_clan": defender.clan})
	var def_attack: Dictionary = resolve_attack(defender, def_p, def_wname, att_armor_tn, 0, dice_engine,
		false, false, false, "", {"opponent_clan": attacker.clan})

	var att_damage: Dictionary = {}
	var def_damage: Dictionary = {}
	var att_wounds: Dictionary = {}
	var def_wounds: Dictionary = {}

	if att_attack.get("hit", false):
		att_damage = resolve_damage(attacker, att_wname, 0, 0, dice_engine, att_p)
		var def_reduction: int = total_defender_reduction(defender, def_p, attacker, att_p, att_wname)
		def_wounds = WoundSystem.apply_damage(defender, att_damage.get("raw_damage", 0), def_reduction)

	if def_attack.get("hit", false):
		def_damage = resolve_damage(defender, def_wname, 0, 0, dice_engine, def_p)
		var att_reduction: int = total_defender_reduction(attacker, att_p, defender, def_p, def_wname)
		att_wounds = WoundSystem.apply_damage(attacker, def_damage.get("raw_damage", 0), att_reduction)

	var att_dead: bool = CharacterStats.is_dead(attacker)
	var def_dead: bool = CharacterStats.is_dead(defender)

	var winner_id: int = -1
	var loser_id: int = -1

	if att_dead and not def_dead:
		winner_id = defender.character_id
		loser_id = attacker.character_id
	elif def_dead and not att_dead:
		winner_id = attacker.character_id
		loser_id = defender.character_id
	elif not att_dead and not def_dead:
		# Both standing: a hit beats a miss; ties broken by roll total.
		var att_hit: bool = att_attack.get("hit", false)
		var def_hit: bool = def_attack.get("hit", false)
		if att_hit and not def_hit:
			winner_id = attacker.character_id
			loser_id = defender.character_id
		elif def_hit and not att_hit:
			winner_id = defender.character_id
			loser_id = attacker.character_id
		else:
			var att_roll: int = att_attack.get("roll", 0)
			var def_roll: int = def_attack.get("roll", 0)
			if att_roll > def_roll:
				winner_id = attacker.character_id
				loser_id = defender.character_id
			elif def_roll > att_roll:
				winner_id = defender.character_id
				loser_id = attacker.character_id
			# exact tie: winner_id stays -1

	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"attacker_id": attacker.character_id,
		"defender_id": defender.character_id,
		"attacker_weapon": att_wname,
		"defender_weapon": def_wname,
		"attacker_hit": att_attack.get("hit", false),
		"defender_hit": def_attack.get("hit", false),
		"attacker_attack": att_attack,
		"defender_attack": def_attack,
		"attacker_damage": att_damage,
		"defender_damage": def_damage,
		"attacker_wounds": att_wounds,
		"defender_wounds": def_wounds,
		"attacker_dead": att_dead,
		"defender_dead": def_dead,
	}
