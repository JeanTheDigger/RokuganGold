class_name CharacterStats
## Pure functions for computing derived character values from L5RCharacterData.
## No state — all methods take a character and return a value.


static func get_ring_value(character: L5RCharacterData, ring: Enums.Ring) -> int:
	if ring == Enums.Ring.VOID:
		return character.void_ring
	var traits: Array = Enums.RING_TRAITS[ring]
	var t1: int = character.get_trait_value(traits[0])
	var t2: int = character.get_trait_value(traits[1])
	return mini(t1, t2)


static func get_earth_ring(character: L5RCharacterData) -> int:
	return get_ring_value(character, Enums.Ring.EARTH)


static func get_total_skill_ranks(character: L5RCharacterData) -> int:
	var total: int = 0
	for rank: int in character.skills.values():
		total += rank
	return total


static func get_insight(character: L5RCharacterData) -> int:
	var rings_sum: int = 0
	for ring: Enums.Ring in [Enums.Ring.AIR, Enums.Ring.EARTH, Enums.Ring.FIRE, Enums.Ring.WATER, Enums.Ring.VOID]:
		rings_sum += get_ring_value(character, ring)
	return (rings_sum * 10) + get_total_skill_ranks(character)


static func get_insight_rank(character: L5RCharacterData) -> int:
	var insight: int = get_insight(character)
	if insight >= 325:
		return 10
	if insight >= 300:
		return 9
	if insight >= 275:
		return 8
	if insight >= 250:
		return 7
	if insight >= 225:
		return 6
	if insight >= 200:
		return 5
	if insight >= 175:
		return 4
	if insight >= 150:
		return 3
	if insight >= 125:
		return 2
	return 1


static func get_armor_tn(character: L5RCharacterData) -> int:
	return (character.reflexes * 5) + 5 + character.armor_tn_bonus


static func get_initiative_rolled(character: L5RCharacterData) -> int:
	return character.reflexes + get_insight_rank(character)


static func get_initiative_kept(character: L5RCharacterData) -> int:
	return character.reflexes


# -- Wound System Queries ------------------------------------------------------

static func get_wound_threshold_per_level(character: L5RCharacterData) -> int:
	return get_earth_ring(character) * 2


static func get_wound_level(character: L5RCharacterData) -> Enums.WoundLevel:
	var threshold: int = get_wound_threshold_per_level(character)
	if threshold <= 0:
		return Enums.WoundLevel.DEAD

	var levels: Array[Enums.WoundLevel] = [
		Enums.WoundLevel.HEALTHY,
		Enums.WoundLevel.NICKED,
		Enums.WoundLevel.GRAZED,
		Enums.WoundLevel.HURT,
		Enums.WoundLevel.INJURED,
		Enums.WoundLevel.CRIPPLED,
		Enums.WoundLevel.DOWN,
		Enums.WoundLevel.OUT,
		Enums.WoundLevel.DEAD,
	]

	var level_index: int = character.wounds_taken / threshold
	if character.wounds_taken > 0 and character.wounds_taken % threshold == 0:
		level_index = mini(level_index, levels.size() - 1)
	else:
		level_index = mini(level_index, levels.size() - 1)
	return levels[level_index]


static func get_wound_penalty(character: L5RCharacterData) -> int:
	return Enums.WOUND_PENALTIES[get_wound_level(character)]


static func get_total_wound_capacity(character: L5RCharacterData) -> int:
	# 8 wound levels before Dead (Healthy through Out), each Earth*2
	return get_wound_threshold_per_level(character) * 8


static func is_dead(character: L5RCharacterData) -> bool:
	return get_wound_level(character) == Enums.WoundLevel.DEAD
