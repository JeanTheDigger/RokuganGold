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
	"katana":     {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Kenjutsu",      "size": "Medium", "melee": true,  "trait": "agility"},
	"wakizashi":  {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Kenjutsu",      "size": "Small",  "melee": true,  "trait": "agility"},
	"tanto":      {"rolled": 1, "kept": 1, "strength_adds": true,  "skill": "Knives",         "size": "Small",  "melee": true,  "trait": "agility"},
	"bo":         {"rolled": 2, "kept": 2, "strength_adds": true,  "skill": "Bo",             "size": "Large",  "melee": true,  "trait": "agility"},
	"naginata":   {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Polearms",       "size": "Large",  "melee": true,  "trait": "agility"},
	"tetsubo":    {"rolled": 3, "kept": 2, "strength_adds": true,  "skill": "Heavy Weapons",  "size": "Large",  "melee": true,  "trait": "agility"},
	"yumi":       {"rolled": 2, "kept": 2, "strength_adds": false, "skill": "Kyujutsu",       "size": "Large",  "melee": false, "trait": "agility"},
	"unarmed":    {"rolled": 0, "kept": 1, "strength_adds": true,  "skill": "Jiujutsu",       "size": "Small",  "melee": true,  "trait": "agility"},
}

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

# -- CombatCondition flags (s40 Conditional Effects) ---------------------------

const CONDITION_BLINDED:   String = "blinded"
const CONDITION_DAZED:     String = "dazed"
const CONDITION_ENTANGLED: String = "entangled"
const CONDITION_FATIGUED:  String = "fatigued"
const CONDITION_GRAPPLED:  String = "grappled"
const CONDITION_MOUNTED:   String = "mounted"
const CONDITION_PRONE:     String = "prone"
const CONDITION_STUNNED:   String = "stunned"


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
	var conditions: Array[String] = []
	var guarding_id: int = -1        # character_id they're guarding, -1 if none
	var full_defense_bonus: int = 0  # bonus from Full Defense Stance roll
	var grapple_partner_id: int = -1
	var grapple_in_control: bool = false
	var void_ring_bonus: int = 0     # from Center Stance carry-forward
	var center_stance_bonus_used: bool = false
	var fatigue_days: int = 0        # consecutive days without rest


class CombatState:
	var round_number: int = 1
	var participants: Dictionary = {}  # character_id -> Participant
	var turn_order: Array[int] = []    # sorted character_ids by initiative (desc)
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
	var is_over: bool = false
	var winner_id: int = -1
	var loser_id: int = -1


# =============================================================================
# -- Initiative (s40 Stage 1) --------------------------------------------------
# =============================================================================

static func roll_initiative(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
) -> int:
	var result: DiceResult = dice_engine.roll_initiative(character.reflexes, CharacterStats.get_insight_rank(character))
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)
	var score: int = result.total + wound_penalty

	# Center Stance carry-over adds +10 to Initiative Score for that round only (s40)
	if participant.stance == Enums.Stance.CENTER and not participant.center_stance_bonus_used:
		score += 10
		participant.void_ring_bonus = character.void_ring
	participant.initiative_score = score
	return score


static func build_combat_state(participants_data: Array[Dictionary]) -> CombatState:
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
	var ids: Array[int] = []
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
) -> int:
	var base_tn: int = CharacterStats.get_armor_tn(character)
	var stance_mod: int = STANCE_ARMOR_TN_BONUS.get(participant.stance, 0)

	var defense_bonus: int = 0
	if participant.stance == Enums.Stance.DEFENSE:
		var air_ring: int = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
		var def_rank: int = character.skills.get("Defense", 0)
		defense_bonus = air_ring + def_rank

	var full_def_bonus: int = 0
	if participant.stance == Enums.Stance.FULL_DEFENSE:
		full_def_bonus = participant.full_defense_bonus

	# Conditional modifiers
	var cond_mod: int = 0
	if CONDITION_GRAPPLED in participant.conditions:
		return 5 + character.armor_tn_bonus  # Grappled: Armor TN = 5 + armor bonuses
	if CONDITION_PRONE in participant.conditions:
		cond_mod -= 10  # -10 vs melee attacks while prone
	if CONDITION_STUNNED in participant.conditions:
		return 5 + character.armor_tn_bonus  # Stunned: Armor TN = 5 + armor bonuses
	if CONDITION_BLINDED in participant.conditions:
		# Blinded base = Reflexes + 5 (armor still adds)
		return character.reflexes + 5 + character.armor_tn_bonus

	# Two-weapon bonus: +InsightRank to Armor TN (handled by caller marking dual_wielding)
	return base_tn + stance_mod + defense_bonus + full_def_bonus + cond_mod


static func roll_full_defense_bonus(
	character: L5RCharacterData,
	participant: Participant,
	dice_engine: DiceEngine,
) -> int:
	var def_rank: int = character.skills.get("Defense", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)
	# Full Defense: Defense/Reflexes — roll (Reflexes + Defense Rank), keep Reflexes (s40)
	var result: DiceResult = dice_engine.roll_and_keep(character.reflexes + def_rank, character.reflexes)
	var half_result: int = ceili(float(result.total + wound_penalty) / 2.0)
	participant.full_defense_bonus = half_result
	return half_result


# =============================================================================
# -- Attack Resolution (s40) --------------------------------------------------
# =============================================================================

static func get_weapon_profile(weapon_name: String) -> Dictionary:
	return WEAPON_CATALOG.get(weapon_name.to_lower(), DEFAULT_WEAPON)


static func resolve_attack(
	attacker: L5RCharacterData,
	attacker_p: Participant,
	weapon_name: String,
	target_armor_tn: int,
	raises: int,
	dice_engine: DiceEngine,
	is_ranged_in_melee: bool = false,
) -> Dictionary:
	var weapon: Dictionary = get_weapon_profile(weapon_name)
	var skill_name: String = weapon.get("skill", "Kenjutsu")
	var skill_rank: int = attacker.skills.get(skill_name, 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(attacker)

	# Attack roll: Trait + Skill rolled, keep Trait (s4.5 "Agility for attacks").
	var trait_name: String = weapon.get("trait", "agility")
	var trait_value: int = attacker.reflexes if trait_name == "reflexes" else attacker.agility
	var rolled: int = trait_value + skill_rank
	var kept: int = trait_value

	# Stance bonuses
	rolled += STANCE_ATTACK_ROLLED_BONUS.get(attacker_p.stance, 0)
	kept += STANCE_ATTACK_KEPT_BONUS.get(attacker_p.stance, 0)

	# Conditional modifiers: -3k0 Dazed, -1k1 or -3k3 Blinded, Prone restrictions
	if CONDITION_DAZED in attacker_p.conditions:
		rolled = maxi(0, rolled - 3)
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

	# Center Stance carry-over: +1k1 + Void Ring on the first roll of the turn (s40)
	var flat_bonus: int = wound_penalty
	if attacker_p.void_ring_bonus > 0 and not attacker_p.center_stance_bonus_used:
		rolled += 1
		kept += 1
		flat_bonus += attacker_p.void_ring_bonus
		attacker_p.center_stance_bonus_used = true

	# Ranged in melee range: -10 flat to total
	if is_ranged_in_melee and not weapon.get("melee", true):
		flat_bonus -= 10

	# raises passed directly — roll_check applies raises * 5 to TN
	var result: Dictionary = dice_engine.roll_check(
		rolled, kept, target_armor_tn, raises, flat_bonus
	)

	return {
		"success": result["success"],
		"hit": result["success"],
		"roll": result["total"],
		"target_tn": result["tn"],
		"margin": result["margin"],
		"raises_called": raises,
	}


static func resolve_damage(
	attacker: L5RCharacterData,
	weapon_name: String,
	raises_for_damage: int,
	feint_bonus: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var weapon: Dictionary = get_weapon_profile(weapon_name)
	var rolled: int = weapon.get("rolled", 2)
	var kept: int = weapon.get("kept", 1)

	# Strength adds to rolled dice for melee weapons (s40: "add Strength to first number")
	if weapon.get("strength_adds", true) and weapon.get("melee", true):
		rolled += attacker.strength

	# Increased Damage maneuver: +1k0 per Raise (s40)
	rolled += raises_for_damage

	# roll_damage handles the dice pool; we pass strength already absorbed above
	var result: Dictionary = dice_engine.roll_damage(rolled, kept)
	var total: int = result["raw"] + feint_bonus

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
) -> Dictionary:
	# Disarm inflicts 2k1 damage regardless of weapon (s40)
	var dmg_result: Dictionary = dice_engine.roll_damage(2, 1)

	# Contested Strength Roll
	var contested: Dictionary = dice_engine.contested_roll(
		attacker.strength, attacker.strength,
		defender.strength, defender.strength,
	)

	return {
		"damage": dmg_result["raw"],
		"attacker_strength_roll": contested["total_a"],
		"defender_strength_roll": contested["total_b"],
		"disarmed": contested["winner"] == "a",
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
) -> Dictionary:
	var contested: Dictionary = dice_engine.contested_roll(
		attacker.strength, attacker.strength,
		defender.strength, defender.strength,
	)
	return {
		"attacker_strength_roll": contested["total_a"],
		"defender_strength_roll": contested["total_b"],
		"knocked_down": contested["winner"] == "a",
	}


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


static func get_condition_roll_penalty(participant: Participant) -> int:
	var penalty: int = 0
	if CONDITION_DAZED in participant.conditions:
		return 30  # -3k0 (reduce rolled by 3, see caller)
	if CONDITION_FATIGUED in participant.conditions:
		penalty += 5 + (participant.fatigue_days / 1) * 5
	return penalty


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
	var result: Dictionary = dice_engine.roll_check(earth_ring, earth_ring, tn)
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
	var result: Dictionary = dice_engine.roll_check(earth_ring, earth_ring, 20)
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
) -> Dictionary:
	var jiujutsu: int = attacker.skills.get("Jiujutsu", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(attacker)

	# Grapple initiation ignores armor's Armor TN bonus — target TN = Reflexes × 5 + 5
	var result: Dictionary = dice_engine.roll_skill_check(
		attacker.agility, jiujutsu, target_armor_tn, 0, wound_penalty
	)
	if result["success"]:
		apply_condition(attacker_p, CONDITION_GRAPPLED)
		return {"success": true, "roll": result["total"], "target_tn": target_armor_tn}
	return {"success": false, "roll": result["total"], "target_tn": target_armor_tn}


static func resolve_grapple_control(
	attacker: L5RCharacterData,
	defender: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Contested Jiujutsu/Strength: roll (Strength + Jiujutsu), keep Strength (s4.5 / s40)
	var att_jiu: int = attacker.skills.get("Jiujutsu", 0)
	var def_jiu: int = defender.skills.get("Jiujutsu", 0)
	var contested: Dictionary = dice_engine.contested_roll(
		attacker.strength + att_jiu, attacker.strength,
		defender.strength + def_jiu, defender.strength,
	)
	return {
		"attacker_roll": contested["total_a"],
		"defender_roll": contested["total_b"],
		"attacker_wins": contested["winner"] != "b",  # attacker wins ties
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


# =============================================================================
# -- Sumai (s40) --------------------------------------------------------------
# =============================================================================

static func resolve_sumai_bout(
	wrestler1: L5RCharacterData,
	wrestler2: L5RCharacterData,
	w1_larger: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	var w1_jiu: int = wrestler1.skills.get("Jiujutsu", 0)
	var w2_jiu: int = wrestler2.skills.get("Jiujutsu", 0)
	var w1_rolled: int = wrestler1.strength + w1_jiu + (1 if w1_larger else 0)
	var w2_rolled: int = wrestler2.strength + w2_jiu
	var contested: Dictionary = dice_engine.contested_roll(
		w1_rolled, wrestler1.strength,
		w2_rolled, wrestler2.strength,
	)
	var margin: int = abs(contested["total_a"] - contested["total_b"])
	var bout_over: bool = margin >= 5
	return {
		"wrestler1_roll": contested["total_a"],
		"wrestler2_roll": contested["total_b"],
		"winner_wrestler1": contested["total_a"] > contested["total_b"] and bout_over,
		"winner_wrestler2": contested["total_b"] > contested["total_a"] and bout_over,
		"bout_over": bout_over,
		"continue": not bout_over,
	}


static func resolve_sumai_stare_down(
	wrestler1: L5RCharacterData,
	wrestler2: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var intim1: int = wrestler1.skills.get("Intimidation", 0)
	var intim2: int = wrestler2.skills.get("Intimidation", 0)
	var contested: Dictionary = dice_engine.contested_roll(
		wrestler1.willpower + intim1, wrestler1.willpower,
		wrestler2.willpower + intim2, wrestler2.willpower,
	)
	var margin: int = abs(contested["total_a"] - contested["total_b"])
	return {
		"wrestler1_roll": contested["total_a"],
		"wrestler2_roll": contested["total_b"],
		"wrestler1_wins": contested["winner"] != "b",
		"grants_bonus": margin >= 5,
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

	var ch_result: Dictionary = dice_engine.roll_skill_check(
		challenger.awareness, ch_iai, ch_tn
	)
	var def_result: Dictionary = dice_engine.roll_skill_check(
		defender.awareness, def_iai, def_tn
	)

	var ch_learned: Array[String] = []
	var def_learned: Array[String] = []

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

	# +1k1 bonus from winning Assessment by 10+
	if duel.assessment_bonus_id == duel.challenger_id:
		ch_rolled += 1
		ch_kept += 1
	elif duel.assessment_bonus_id == duel.defender_id:
		def_rolled += 1
		def_kept += 1

	var contested: Dictionary = dice_engine.contested_roll(
		ch_rolled, ch_kept,
		def_rolled, def_kept,
	)

	var margin: int = contested["total_a"] - contested["total_b"]

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
		"challenger_roll": contested["total_a"],
		"defender_roll": contested["total_b"],
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
) -> Dictionary:
	# Duel strike: Iaijutsu/Reflexes attack roll (s40 — explicit "Iaijutsu/Reflexes attack roll")
	var iai_rank: int = striker.skills.get("Iaijutsu", 0)
	var wound_penalty: int = CharacterStats.get_wound_penalty(striker)
	var rolled: int = striker.reflexes + iai_rank
	var kept: int = striker.reflexes

	# Center Stance carry-over: +1k1 + Void Ring on the first roll of the turn (s40)
	var flat_bonus: int = wound_penalty
	if striker_p.void_ring_bonus > 0 and not striker_p.center_stance_bonus_used:
		rolled += 1
		kept += 1
		flat_bonus += striker_p.void_ring_bonus
		striker_p.center_stance_bonus_used = true

	# Free Raises from Focus grant effects without raising TN (s40); they are used
	# for Increased Damage in resolve_duel_strike(), so passes raises=0 here.
	var result: Dictionary = dice_engine.roll_check(rolled, kept, target_tn, 0, flat_bonus)
	return {
		"success": result["success"],
		"hit": result["success"],
		"roll": result["total"],
		"target_tn": result["tn"],
		"margin": result["margin"],
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
		first_damage = resolve_damage(first_striker, "katana", duel.free_raises_first, 0, dice_engine)
		first_wounds = WoundSystem.apply_damage(second_striker, first_damage["raw_damage"])

	# In a kharmic strike, both attack simultaneously
	var second_damage: Dictionary = {}
	var second_wounds: Dictionary = {}
	var second_attack: Dictionary = {}
	if duel.simultaneous or (not duel.simultaneous and not CharacterStats.is_dead(second_striker)):
		var second_armor_tn: int = get_armor_tn(first_striker, first_striker_p, dice_engine)
		second_attack = _iaijutsu_attack(
			second_striker, second_striker_p, second_armor_tn, dice_engine
		)
		if second_attack.get("hit", false):
			second_damage = resolve_damage(second_striker, "katana", 0, 0, dice_engine)
			second_wounds = WoundSystem.apply_damage(first_striker, second_damage["raw_damage"])

	# Determine outcome
	var first_dead: bool = CharacterStats.is_dead(first_striker)
	var second_dead: bool = CharacterStats.is_dead(second_striker)

	if not duel.simultaneous:
		if second_dead:
			duel.winner_id = first_striker.character_id
			duel.loser_id = second_striker.character_id
			duel.is_over = true
		elif first_dead:
			duel.winner_id = second_striker.character_id
			duel.loser_id = first_striker.character_id
			duel.is_over = true
		elif not duel.duel_to_death:
			# First blood: if second struck and hit, duel to first blood is over
			var second_struck: bool = CharacterStats.get_wound_level(second_striker) > Enums.WoundLevel.HEALTHY
			if second_struck:
				duel.winner_id = first_striker.character_id
				duel.loser_id = second_striker.character_id
				duel.is_over = true
	else:
		# Kharmic strike: cause considered dropped, no victor
		duel.is_over = true
		duel.winner_id = -1  # no winner

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
		# Center Stance bonus only lasts one round (s40)
		if p.stance == Enums.Stance.CENTER and p.void_ring_bonus > 0:
			p.center_stance_bonus_used = true


static func advance_round_reactions(
	state: CombatState,
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for cid: int in state.participants:
		var p: Participant = state.participants[cid]
		var c: L5RCharacterData = characters_by_id.get(cid)
		if c == null:
			continue
		# Dazed recovery attempt
		if CONDITION_DAZED in p.conditions:
			var recovered: bool = attempt_recover_dazed(c, p, 1, dice_engine)
			if recovered:
				events.append({"type": "condition_cleared", "condition": CONDITION_DAZED, "character_id": cid})
		# Stunned recovery
		if CONDITION_STUNNED in p.conditions:
			var recovered: bool = attempt_recover_stunned(c, p, dice_engine)
			if recovered:
				events.append({"type": "condition_cleared", "condition": CONDITION_STUNNED, "character_id": cid})
		# Clear Center Stance bonus after reactions
		if p.center_stance_bonus_used:
			p.void_ring_bonus = 0
			p.center_stance_bonus_used = false

	return events


static func check_combat_over(
	state: CombatState,
	characters_by_id: Dictionary,
) -> bool:
	var alive: Array[int] = []
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
