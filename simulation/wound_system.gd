class_name WoundSystem
## Applies and removes wounds from characters. Uses CharacterStats for
## derived values. All damage application goes through here.


static func apply_damage(character: L5RCharacterData, raw_damage: int, reduction: int = -1) -> Dictionary:
	if reduction < 0:
		reduction = character.armor_reduction
	var final_damage: int = maxi(0, raw_damage - reduction)

	var old_level: Enums.WoundLevel = CharacterStats.get_wound_level(character)
	character.wounds_taken += final_damage
	var new_level: Enums.WoundLevel = CharacterStats.get_wound_level(character)

	return {
		"raw_damage": raw_damage,
		"reduction": reduction,
		"final_damage": final_damage,
		"old_wound_level": old_level,
		"new_wound_level": new_level,
		"is_dead": CharacterStats.is_dead(character),
		"levels_crossed": new_level - old_level,
	}


static func heal_wounds(character: L5RCharacterData, amount: int) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {
			"healed": 0,
			"wound_level": Enums.WoundLevel.DEAD,
		}

	var old_wounds: int = character.wounds_taken
	character.wounds_taken = maxi(0, character.wounds_taken - amount)
	var actual_healed: int = old_wounds - character.wounds_taken

	return {
		"healed": actual_healed,
		"wound_level": CharacterStats.get_wound_level(character),
	}


static func apply_falling_damage(character: L5RCharacterData, tiles_fallen: int, dice_engine: DiceEngine) -> Dictionary:
	if tiles_fallen <= 1:
		return apply_damage(character, 0, 0)
	var dice_count: int = ceili(float(tiles_fallen) / 2.0)
	var result: Dictionary = dice_engine.roll_damage(dice_count, dice_count, 0, 0)
	return apply_damage(character, result["raw"], 0)
