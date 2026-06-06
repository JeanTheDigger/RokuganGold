class_name VoidSystem
## Void Point spending per L5R 4e RAW.
##
## Effects (once per Round per character, except School Technique spends):
##   1. +1k1 (or +2k2 if enhanced_void) to Skill/Trait/Ring/Spell Casting roll.
##      Declared before the roll. NOT valid for Damage Rolls.
##   2. Temporarily raise a Skill from 0 to 1 (avoids Unskilled Roll penalties).
##   3. Reduce Wounds from one damage source by 10 (declared after damage total).
##   4. +10 Armor TN for one Round (declared at beginning of Round).
##   5. +10 Initiative Score for duration of skirmish (beginning of Round).
##   6. Exchange Initiative Score with one willing target (one spend only).
##
## Once-per-Round tracking: callers must set Participant.void_spent_this_round = true
## after any successful spend in combat. begin_round() clears it each round.
## enhanced_void flag on character grants +2k2 instead of +1k1 (school techniques).


# -- Core pool management ------------------------------------------------------

static func can_spend(character: L5RCharacterData) -> bool:
	return character.current_void_points > 0


static func spend(character: L5RCharacterData) -> bool:
	# HOTEI'S BLESSING CURSE variant (s45): each spend costs 1 extra VP.
	var extra_cost: int = AdvantageSystem.get_extra_void_cost(character)
	if character.current_void_points <= extra_cost:
		return false
	character.current_void_points -= (1 + extra_cost)
	return true


## HOTEI'S BLESSING protection variant (s45): contested Void vs TN 10.
## On success, the VP is NOT consumed. Returns {success, protected}.
static func try_spend_protected(character: L5RCharacterData, dice_engine: DiceEngine) -> Dictionary:
	var protection: Dictionary = AdvantageSystem.check_hotei_void_protection(character)
	if not protection.get("protected", false):
		var spent: bool = spend(character)
		return {"success": spent, "protected": false}
	# Contested Void roll vs TN 10.
	var wound_pen: int = CharacterStats.get_wound_penalty(character)
	var roll: Dictionary = dice_engine.roll_check(
		character.void_ring, character.void_ring, 10, 0, wound_pen, true, false
	)
	if roll.get("success", false):
		return {"success": true, "protected": true}
	var spent: bool = spend(character)
	return {"success": spent, "protected": false}


## Returns the number of hours of rest required to fully recover VP (s45).
static func get_recovery_hours(character: L5RCharacterData) -> int:
	return AdvantageSystem.get_void_recovery_hours(character)


## Returns true if the character has rested enough hours to fully recover.
static func can_recover_full(character: L5RCharacterData, hours_rested: int) -> bool:
	return hours_rested >= get_recovery_hours(character)


static func recover(character: L5RCharacterData, amount: int) -> void:
	character.current_void_points = mini(
		character.current_void_points + amount,
		character.max_void_points,
	)


static func restore_full(character: L5RCharacterData) -> void:
	character.current_void_points = character.max_void_points


# -- Roll bonus ----------------------------------------------------------------

# Returns {rolled: int, kept: int} dice bonus for a Void roll spend.
# enhanced_void = true applies the school-technique +2k2 variant.
static func roll_bonus(character: L5RCharacterData) -> Dictionary:
	if character.enhanced_void:
		return {"rolled": 2, "kept": 2}
	return {"rolled": 1, "kept": 1}


# Spend for +1k1 (or +2k2) on a Skill/Trait/Ring/Spell roll.
# Returns {success, rolled_bonus, kept_bonus}.
# NOT valid for Damage Rolls (RAW explicit restriction).
# Caller must set Participant.void_spent_this_round = true after a successful spend in combat.
static func spend_for_roll(character: L5RCharacterData) -> Dictionary:
	if not spend(character):
		return {"success": false, "rolled_bonus": 0, "kept_bonus": 0}
	var bonus: Dictionary = roll_bonus(character)
	return {"success": true, "rolled_bonus": bonus["rolled"], "kept_bonus": bonus["kept"]}


# -- Wound reduction -----------------------------------------------------------

# Spend to reduce Wounds from one damage source by 10 (declared after damage total).
# Returns {success, reduced_damage}.
# Caller must set Participant.void_spent_this_round = true after a successful spend in combat.
static func spend_for_wound_reduction(character: L5RCharacterData, raw_damage: int) -> Dictionary:
	if not spend(character):
		return {"success": false, "reduced_damage": raw_damage}
	return {"success": true, "reduced_damage": maxi(0, raw_damage - 10)}


# -- Armor TN boost ------------------------------------------------------------

# Spend for +10 Armor TN for one Round (declared at beginning of Round).
# Returns {success, armor_tn_bonus}.
# Caller applies result["armor_tn_bonus"] to Participant.void_armor_tn_bonus
# and sets Participant.void_spent_this_round = true.
static func spend_for_armor_tn(character: L5RCharacterData) -> Dictionary:
	if not spend(character):
		return {"success": false, "armor_tn_bonus": 0}
	return {"success": true, "armor_tn_bonus": 10}


# -- Initiative boost ----------------------------------------------------------

# Spend for +10 Initiative Score for duration of skirmish (beginning of Round).
# Returns {success, initiative_bonus}.
# Caller applies result["initiative_bonus"] to Participant.initiative_score
# and sets Participant.void_spent_this_round = true.
static func spend_for_initiative_bonus(character: L5RCharacterData) -> Dictionary:
	if not spend(character):
		return {"success": false, "initiative_bonus": 0}
	return {"success": true, "initiative_bonus": 10}
