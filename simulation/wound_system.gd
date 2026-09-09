class_name WoundSystem
## Applies and removes wounds from characters. Uses CharacterStats for
## derived values. All damage application goes through here.


static func apply_damage(character: L5RCharacterData, raw_damage: int, reduction: int = -1, ring_deltas: Dictionary = {}) -> Dictionary:
	if reduction < 0:
		reduction = character.armor_reduction
	var final_damage: int = maxi(0, raw_damage - reduction)

	var old_level: Enums.WoundLevel = CharacterStats.get_wound_level(character, ring_deltas)
	character.wounds_taken += final_damage
	var new_level: Enums.WoundLevel = CharacterStats.get_wound_level(character, ring_deltas)

	return {
		"raw_damage": raw_damage,
		"reduction": reduction,
		"final_damage": final_damage,
		"old_wound_level": old_level,
		"new_wound_level": new_level,
		"is_dead": CharacterStats.is_dead(character, ring_deltas),
		"levels_crossed": new_level - old_level,
	}


static func heal_wounds(character: L5RCharacterData, amount: int, ring_deltas: Dictionary = {}) -> Dictionary:
	if CharacterStats.is_dead(character, ring_deltas):
		return {
			"healed": 0,
			"wound_level": Enums.WoundLevel.DEAD,
		}

	var old_wounds: int = character.wounds_taken
	character.wounds_taken = maxi(0, character.wounds_taken - amount)
	var actual_healed: int = old_wounds - character.wounds_taken

	# s56.16 spiritual wounds (Mokumokuren Gaze) are cured normally by magic and
	# natural healing (this generic heal path); clamp the spiritual portion so it can
	# never exceed total wounds. Inert when spiritual_wounds == 0.
	if character.spiritual_wounds > 0:
		character.spiritual_wounds = mini(character.spiritual_wounds, character.wounds_taken)

	return {
		"healed": actual_healed,
		"wound_level": CharacterStats.get_wound_level(character, ring_deltas),
	}


static func apply_falling_damage(character: L5RCharacterData, tiles_fallen: int, dice_engine: DiceEngine) -> Dictionary:
	if tiles_fallen <= 1:
		return apply_damage(character, 0, 0)
	# s4.5.6 (LOCKED): "Falling damage = 1k1 per 2 tiles (10 feet) of height fallen,
	# ROUNDED DOWN to the nearest 2 tiles." Integer division truncates toward zero for
	# non-negative operands, matching the LOCKED worked examples (4 tiles=2k2, 6=3k3,
	# 10=5k5) and correctly rounding an odd tile count down (e.g. 3 tiles -> 1k1, not 2k2).
	var dice_count: int = tiles_fallen / 2
	var result: Dictionary = dice_engine.roll_damage(dice_count, dice_count, 0, 0)
	return apply_damage(character, result["raw"], 0)
