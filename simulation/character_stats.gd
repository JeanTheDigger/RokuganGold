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
	# L5R4e Core p.108: Rank 1 at 0, Rank 2 at 150, then +25 per rank.
	if insight >= 350:
		return 10
	if insight >= 325:
		return 9
	if insight >= 300:
		return 8
	if insight >= 275:
		return 7
	if insight >= 250:
		return 6
	if insight >= 225:
		return 5
	if insight >= 200:
		return 4
	if insight >= 175:
		return 3
	if insight >= 150:
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
	# s56.16 spirit creatures use their explicit stat-block wound track (wounds_dead
	# + per-level wound_thresholds), not the PC Earth×2 formula. Inert for real chars.
	if character.spirit_creature != null and character.spirit_creature.wounds_dead > 0:
		return _spirit_wound_level(character)

	var threshold: int = get_wound_threshold_per_level(character)
	if threshold <= 0:
		return Enums.WoundLevel.DEAD

	var has_permanent_wound: bool = AdvantageSystem.has_permanent_wound(character)

	if character.wounds_taken <= 0:
		# PERMANENT_WOUND (s45): first wound box is always occupied — minimum NICKED.
		if has_permanent_wound:
			return Enums.WoundLevel.NICKED
		return Enums.WoundLevel.HEALTHY

	var levels: Array = [
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

	# Each level holds `threshold` wound boxes. Wounds 1–threshold fill Healthy,
	# threshold+1 through threshold*2 fill Nicked, etc. The penalty applies once
	# wounds spill into a new level.
	var level_index: int = int((character.wounds_taken - 1) / threshold)
	level_index = mini(level_index, levels.size() - 1)
	var level: Enums.WoundLevel = levels[level_index]
	# PERMANENT_WOUND floors the wound level at NICKED.
	if has_permanent_wound and level == Enums.WoundLevel.HEALTHY:
		return Enums.WoundLevel.NICKED
	return level


static func get_wound_penalty(character: L5RCharacterData) -> int:
	return Enums.WOUND_PENALTIES[get_wound_level(character)]


static func get_total_wound_capacity(character: L5RCharacterData) -> int:
	# s56.16 spirit creatures: death at their explicit wounds_dead.
	if character.spirit_creature != null and character.spirit_creature.wounds_dead > 0:
		return character.spirit_creature.wounds_dead
	# 8 wound levels before Dead (Healthy through Out), each Earth*2
	return get_wound_threshold_per_level(character) * 8


## s56.16 spirit wound level: DEAD at wounds_dead; otherwise the level index =
## how many cumulative wound_thresholds the wounds have exceeded (falls back to a
## proportional split across the 8 living levels if the creature has no thresholds).
static func _spirit_wound_level(character: L5RCharacterData) -> Enums.WoundLevel:
	var cr: SpiritCreatureData = character.spirit_creature
	var w: int = character.wounds_taken
	if w >= cr.wounds_dead:
		return Enums.WoundLevel.DEAD
	if w <= 0:
		return Enums.WoundLevel.HEALTHY
	var levels: Array = [
		Enums.WoundLevel.HEALTHY, Enums.WoundLevel.NICKED, Enums.WoundLevel.GRAZED,
		Enums.WoundLevel.HURT, Enums.WoundLevel.INJURED, Enums.WoundLevel.CRIPPLED,
		Enums.WoundLevel.DOWN, Enums.WoundLevel.OUT,
	]
	var idx: int = 0
	if cr.wound_thresholds.is_empty():
		idx = int(float(w) / float(cr.wounds_dead) * float(levels.size()))
	else:
		for th in cr.wound_thresholds:
			if w > int(th):
				idx += 1
	idx = clampi(idx, 0, levels.size() - 1)
	return levels[idx]


static func is_dead(character: L5RCharacterData) -> bool:
	return get_wound_level(character) == Enums.WoundLevel.DEAD


# DARLING_OF_THE_COURT (s45): +1 effective Status at a specific court settlement.
# Use instead of character.status for court-context social calculations.
static func get_effective_status(character: L5RCharacterData, settlement_id: int = -1) -> float:
	return character.status + float(AdvantageSystem.get_darling_status_bonus(character, settlement_id))
