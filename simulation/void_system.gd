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
	return character.void_points_current > 0


static func spend(character: L5RCharacterData) -> bool:
	if character.void_points_current <= 0:
		return false
	character.void_points_current -= 1
	return true


static func recover(character: L5RCharacterData, amount: int) -> void:
	character.void_points_current = mini(
		character.void_points_current + amount,
		character.void_points_max,
	)


static func restore_full(character: L5RCharacterData) -> void:
	character.void_points_current = character.void_points_max


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
