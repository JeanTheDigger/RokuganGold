class_name MutationSystem
## s44 Shadowlands Mutations & Powers
## Pure simulation — no Node inheritance.
##
## Taint rank thresholds (s42):
##   0.0–0.9 = Rank 0  (no mechanical status)
##   1.0–1.9 = Rank 1
##   2.0–2.9 = Rank 2  (+1 Minor power on rank-up)
##   3.0–3.9 = Rank 3  (-1k0 Social, +1 power, +1 mutation)
##   4.0–4.9 = Rank 4  (-2k0 Social, Void max-1, +2 powers (1+ Major), +1 mutation)
##   5.0+    = Rank 5  (Lost)
##
## Periodic taint roll periods:
##   Rank 0–1: every 30 IC days (monthly)
##   Rank 2:   every 15 IC days (twice/month)
##   Rank 3:   every  7 IC days (weekly)
##   Rank 4:   every  1 IC day  (daily)
##   Rank 5:   no periodic roll (Lost — no further natural gain from rolls)


# ---------------------------------------------------------------------------
# Taint rank helpers
# ---------------------------------------------------------------------------

static func get_taint_rank(taint: float) -> int:
	if taint >= 5.0:
		return 5
	return int(taint)


## Returns the IC-day interval between periodic taint rolls for a given rank.
static func get_roll_period(taint_rank: int) -> int:
	match taint_rank:
		0, 1: return 30
		2:    return 15
		3:    return 7
		4:    return 1
		_:    return 0  # Rank 5 (Lost) — no roll


## TN for the periodic Earth taint roll (s42): TN = 5 + (5 × Rank).
static func get_roll_tn(taint_rank: int) -> int:
	return 5 + (5 * taint_rank)


## TN for the taint roll when using a Shadowlands Power.
static func get_power_use_tn(tier: Enums.ShadowlandsPowerTier) -> int:
	match tier:
		Enums.ShadowlandsPowerTier.MAJOR, Enums.ShadowlandsPowerTier.AKUTENSHI:
			return 20  # Akutenshi treated as Major (s44)
		_:
			return 15  # Minor


# ---------------------------------------------------------------------------
# Power pools by tier
# ---------------------------------------------------------------------------

const MINOR_POWERS: Array[Enums.ShadowlandsPowerType] = [
	Enums.ShadowlandsPowerType.ABOVE_THE_ELEMENTS,
	Enums.ShadowlandsPowerType.BLACKENED_CLAWS,
	Enums.ShadowlandsPowerType.BLESSING_OF_THE_DARK_ONE,
	Enums.ShadowlandsPowerType.BLOOD_KNOWS_BLOOD,
	Enums.ShadowlandsPowerType.CALLIGRAPHY_OF_THOUGHT,
	Enums.ShadowlandsPowerType.CHILD_OF_DARKNESS,
	Enums.ShadowlandsPowerType.EYES_OF_HELL,
	Enums.ShadowlandsPowerType.FEAR_POWER,
	Enums.ShadowlandsPowerType.JADE_SENSE,
	Enums.ShadowlandsPowerType.MASTER_OF_BLOOD,
	Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS,
	Enums.ShadowlandsPowerType.MIND_OF_DARKNESS,
	Enums.ShadowlandsPowerType.MONSTROUS_STRENGTH,
	Enums.ShadowlandsPowerType.SENSE_PURITY,
	Enums.ShadowlandsPowerType.UNCANNY_SPEED,
	Enums.ShadowlandsPowerType.UNHOLY_STAMINA,
]

const MAJOR_POWERS: Array[Enums.ShadowlandsPowerType] = [
	Enums.ShadowlandsPowerType.ARMOR_OF_DEATH,
	Enums.ShadowlandsPowerType.BESIDE_THE_DARKNESS,
	Enums.ShadowlandsPowerType.BEYOND_THE_ELEMENTS,
	Enums.ShadowlandsPowerType.BLOOD_DOMINATION,
	Enums.ShadowlandsPowerType.BLOOD_SHOUTING,
	Enums.ShadowlandsPowerType.CHOSEN_OF_FU_LENG,
	Enums.ShadowlandsPowerType.DISRUPT_THE_CHI,
	Enums.ShadowlandsPowerType.DRAWING_OUT_THE_DARKNESS,
	Enums.ShadowlandsPowerType.EVADE_THE_UNWORTHY,
	Enums.ShadowlandsPowerType.FATHER_OF_LIES,
	Enums.ShadowlandsPowerType.FEEDING_ON_FLESH,
	Enums.ShadowlandsPowerType.FLIGHT_OF_DARKNESS,
	Enums.ShadowlandsPowerType.PROTECTION_OF_THE_DARK,
	Enums.ShadowlandsPowerType.STRENGTH_OF_MADNESS,
	Enums.ShadowlandsPowerType.STRENGTH_OF_THE_DARK_ONE,
	Enums.ShadowlandsPowerType.THY_MASTERS_WILL,
	Enums.ShadowlandsPowerType.UNDEAD_STRENGTH,
	Enums.ShadowlandsPowerType.UNEARTHLY_REGENERATION,
	Enums.ShadowlandsPowerType.UNHOLY_BEAUTY,
]

const ALL_MUTATIONS: Array[Enums.MutationType] = [
	Enums.MutationType.ALBINISM,
	Enums.MutationType.BEAST_OF_FU_LENG,
	Enums.MutationType.CHITINOUS_ARMOR,
	Enums.MutationType.DEMONIC_EYES,
	Enums.MutationType.DISCOLORED_SKIN,
	Enums.MutationType.DISTORTED_LIMBS,
	Enums.MutationType.EXTRA_DIGIT,
	Enums.MutationType.EXTRA_EYE,
	Enums.MutationType.EXTRA_LIMB,
	Enums.MutationType.FORKED_TONGUE,
	Enums.MutationType.FOUL_ODOR,
	Enums.MutationType.JIGOKUS_BLOOD,
	Enums.MutationType.TENTACLES,
	Enums.MutationType.TOUGH_HIDE,
	Enums.MutationType.UNDEAD_VISAGE,
	Enums.MutationType.VILE_TEETH,
	Enums.MutationType.WINGS,
]


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

static func has_mutation(character: L5RCharacterData, mt: Enums.MutationType) -> bool:
	for m: MutationData in character.mutations:
		if m.mutation_type == mt:
			return true
	return false


static func has_power(character: L5RCharacterData, pt: Enums.ShadowlandsPowerType) -> bool:
	for p: ShadowlandsPowerData in character.shadowlands_powers:
		if p.power_type == pt:
			return true
	return false


static func is_lost(character: L5RCharacterData) -> bool:
	return character.taint >= 5.0


# ---------------------------------------------------------------------------
# Gain / assign helpers
# ---------------------------------------------------------------------------

## Adds a mutation to the character, applying secondary effects.
static func gain_mutation(
	character: L5RCharacterData,
	mt: Enums.MutationType,
	dice: DiceEngine,
	ic_day: int = -1,
) -> MutationData:
	if has_mutation(character, mt):
		return null  # already have it

	var md := MutationData.new()
	md.mutation_type = mt
	md.ic_day_manifested = ic_day

	match mt:
		Enums.MutationType.DISTORTED_LIMBS:
			md.affected_limb = "leg" if dice.rand_int_range(0, 1) == 0 else "arm"
			if md.affected_limb == "leg":
				_add_lame_disadvantage(character)

		Enums.MutationType.EXTRA_LIMB:
			md.is_non_functional = dice.rand_int_range(0, 1) == 0

	character.mutations.append(md)
	return md


## Adds a Shadowlands power to the character, applying secondary effects.
## Returns null if the character already has the power.
static func gain_power(
	character: L5RCharacterData,
	pt: Enums.ShadowlandsPowerType,
	tier: Enums.ShadowlandsPowerTier,
	dice: DiceEngine,
	ic_day: int = -1,
) -> ShadowlandsPowerData:
	if has_power(character, pt):
		return null

	var pd := ShadowlandsPowerData.new()
	pd.power_type = pt
	pd.tier = tier
	pd.ic_day_acquired = ic_day

	# Immediate secondary effects on acquisition
	match pt:
		Enums.ShadowlandsPowerType.UNHOLY_BEAUTY:
			# All physical mutations fade away (s44)
			character.mutations.clear()

		Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS:
			# Gain DISCOLORED_SKIN if not already possessed (s44)
			if not has_mutation(character, Enums.MutationType.DISCOLORED_SKIN):
				gain_mutation(character, Enums.MutationType.DISCOLORED_SKIN, dice, ic_day)

	character.shadowlands_powers.append(pd)
	return pd


## Selects a random power not already held from the given candidate pool.
## Returns ShadowlandsPowerType.NONE if all powers in the pool are held.
static func _pick_power_from_pool(
	character: L5RCharacterData,
	pool: Array[Enums.ShadowlandsPowerType],
	dice: DiceEngine,
) -> Enums.ShadowlandsPowerType:
	var candidates: Array[Enums.ShadowlandsPowerType] = []
	for pt: Enums.ShadowlandsPowerType in pool:
		if not has_power(character, pt):
			candidates.append(pt)
	if candidates.is_empty():
		return Enums.ShadowlandsPowerType.NONE
	return candidates[dice.rand_int_range(0, candidates.size() - 1)]


## Selects a random mutation not already held.
static func _pick_mutation(
	character: L5RCharacterData,
	dice: DiceEngine,
) -> Enums.MutationType:
	var candidates: Array[Enums.MutationType] = []
	for mt: Enums.MutationType in ALL_MUTATIONS:
		if not has_mutation(character, mt):
			candidates.append(mt)
	if candidates.is_empty():
		return Enums.MutationType.NONE
	return candidates[dice.rand_int_range(0, candidates.size() - 1)]


## Selects from the combined Minor+Major pool.
static func _pick_any_power(
	character: L5RCharacterData,
	dice: DiceEngine,
) -> Enums.ShadowlandsPowerType:
	var combined: Array[Enums.ShadowlandsPowerType] = []
	combined.append_array(MINOR_POWERS)
	combined.append_array(MAJOR_POWERS)
	return _pick_power_from_pool(character, combined, dice)


# ---------------------------------------------------------------------------
# Rank-up processing  (called daily by DayOrchestrator when rank increases)
# ---------------------------------------------------------------------------

## Process a taint rank-up from old_rank to new_rank.
## Returns a Dictionary of what was gained (for logging / topic generation).
static func process_rank_up(
	character: L5RCharacterData,
	new_rank: int,
	dice: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var gained_mutations: Array = []
	var gained_powers: Array = []

	match new_rank:
		2:
			# +1 Minor power (GDD: "most often Minor" — no probability split specified)
			var pt: Enums.ShadowlandsPowerType = _pick_power_from_pool(
				character, MINOR_POWERS, dice
			)
			if pt != Enums.ShadowlandsPowerType.NONE:
				var pd: ShadowlandsPowerData = gain_power(
					character, pt, Enums.ShadowlandsPowerTier.MINOR, dice, ic_day
				)
				if pd != null:
					gained_powers.append(pt)

		3:
			# +1 power (Minor or Major), +1 mutation
			var combined: Array[Enums.ShadowlandsPowerType] = []
			combined.append_array(MINOR_POWERS)
			combined.append_array(MAJOR_POWERS)
			var pt: Enums.ShadowlandsPowerType = _pick_power_from_pool(character, combined, dice)
			if pt != Enums.ShadowlandsPowerType.NONE:
				var tier: Enums.ShadowlandsPowerTier = (
					Enums.ShadowlandsPowerTier.MINOR
					if MINOR_POWERS.has(pt)
					else Enums.ShadowlandsPowerTier.MAJOR
				)
				var pd: ShadowlandsPowerData = gain_power(character, pt, tier, dice, ic_day)
				if pd != null:
					gained_powers.append(pt)

			var mt: Enums.MutationType = _pick_mutation(character, dice)
			if mt != Enums.MutationType.NONE:
				var mdata: MutationData = gain_mutation(character, mt, dice, ic_day)
				if mdata != null:
					gained_mutations.append(mt)

		4:
			# +2 powers (first must be Major), +1 mutation
			# First power — guaranteed Major
			var pt_major: Enums.ShadowlandsPowerType = _pick_power_from_pool(
				character, MAJOR_POWERS, dice
			)
			if pt_major != Enums.ShadowlandsPowerType.NONE:
				var pd: ShadowlandsPowerData = gain_power(
					character, pt_major, Enums.ShadowlandsPowerTier.MAJOR, dice, ic_day
				)
				if pd != null:
					gained_powers.append(pt_major)

			# Second power — any (Minor or Major)
			var pt2: Enums.ShadowlandsPowerType = _pick_any_power(character, dice)
			if pt2 != Enums.ShadowlandsPowerType.NONE:
				var tier2: Enums.ShadowlandsPowerTier = (
					Enums.ShadowlandsPowerTier.MINOR
					if MINOR_POWERS.has(pt2)
					else Enums.ShadowlandsPowerTier.MAJOR
				)
				var pd2: ShadowlandsPowerData = gain_power(character, pt2, tier2, dice, ic_day)
				if pd2 != null:
					gained_powers.append(pt2)

			var mt: Enums.MutationType = _pick_mutation(character, dice)
			if mt != Enums.MutationType.NONE:
				var mdata: MutationData = gain_mutation(character, mt, dice, ic_day)
				if mdata != null:
					gained_mutations.append(mt)

		5:
			# Lost: 0–3 mutations, 0–3 powers (Minor or Major pool only)
			var num_mutations: int = dice.rand_int_range(0, 3)
			var num_powers: int = dice.rand_int_range(0, 3)
			for _i: int in range(num_mutations):
				var mt: Enums.MutationType = _pick_mutation(character, dice)
				if mt != Enums.MutationType.NONE:
					var mdata: MutationData = gain_mutation(character, mt, dice, ic_day)
					if mdata != null:
						gained_mutations.append(mt)
			for _i: int in range(num_powers):
				var pt: Enums.ShadowlandsPowerType = _pick_any_power(character, dice)
				if pt != Enums.ShadowlandsPowerType.NONE:
					var tier: Enums.ShadowlandsPowerTier = (
						Enums.ShadowlandsPowerTier.MINOR
						if MINOR_POWERS.has(pt)
						else Enums.ShadowlandsPowerTier.MAJOR
					)
					var pd: ShadowlandsPowerData = gain_power(character, pt, tier, dice, ic_day)
					if pd != null:
						gained_powers.append(pt)

			# Mental traits collapse to 1 (s42 "Lost" rule) — flag for UI/logging
			# Mechanical enforcement (trait → 1) deferred to individual combat s40
			# which reads trait values. We record the rank change; no mutation here.

	return {"gained_mutations": gained_mutations, "gained_powers": gained_powers, "new_rank": new_rank}


# ---------------------------------------------------------------------------
# Periodic taint roll  (called daily by DayOrchestrator)
# ---------------------------------------------------------------------------

## Returns true if a periodic taint roll should fire today.
static func should_roll_today(character: L5RCharacterData, ic_day: int) -> bool:
	var rank: int = get_taint_rank(character.taint)
	var period: int = get_roll_period(rank)
	if period == 0:
		return false  # Rank 5 — no roll
	if ic_day < 0:
		return false
	return (ic_day % period) == 0


## Resolve a periodic Earth taint roll. Returns a result dict.
## Caller must pass the character's Earth ring value.
static func resolve_periodic_taint_roll(
	character: L5RCharacterData,
	earth_ring: int,
	dice: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var rank: int = get_taint_rank(character.taint)
	var tn: int = get_roll_tn(rank)
	var result: Dictionary = dice.roll_skill_check(earth_ring, 0, 0)
	var success: bool = result["total"] >= tn
	if not success:
		character.taint += 1.0

	return {
		"character_id": character.character_id,
		"taint_roll": true,
		"taint_rank": rank,
		"tn": tn,
		"roll_total": result["total"],
		"success": success,
		"taint_gained": 0 if success else 1,
		"taint_after": character.taint,
	}


## Resolve the taint roll forced by using a Shadowlands Power.
## Returns a result dict. Caller must pass the Earth ring value.
static func resolve_power_use_taint_roll(
	character: L5RCharacterData,
	earth_ring: int,
	power_tier: Enums.ShadowlandsPowerTier,
	dice: DiceEngine,
) -> Dictionary:
	var tn: int = get_power_use_tn(power_tier)
	var result: Dictionary = dice.roll_skill_check(earth_ring, 0, 0)
	var success: bool = result["total"] >= tn
	if not success:
		character.taint += 1.0

	return {
		"character_id": character.character_id,
		"power_taint_roll": true,
		"power_tier": power_tier,
		"tn": tn,
		"roll_total": result["total"],
		"success": success,
		"taint_gained": 0 if success else 1,
		"taint_after": character.taint,
	}


# ---------------------------------------------------------------------------
# Skill modifier interface  (called by SkillResolver)
# ---------------------------------------------------------------------------

## Returns {rolled: int, kept: int, tn: int} adjustments from mutations and
## powers for a given skill roll. All values are deltas (positive = benefit,
## negative = penalty). tn positive = harder.
static func get_skill_modifiers(
	character: L5RCharacterData,
	skill_name: String,
	emphasis_name: String = "",
	context: Dictionary = {},
) -> Dictionary:
	var dr: int = 0  # rolled dice delta
	var dk: int = 0  # kept dice delta
	var dtn: int = 0  # TN delta

	var taint_rank: int = get_taint_rank(character.taint)
	var is_social: bool = _is_social_skill(skill_name)
	var is_perception_based: bool = _is_perception_based(skill_name)
	var is_stealth: bool = skill_name == "Stealth"
	var is_strength_based: bool = _is_strength_based(skill_name)
	var is_temptation: bool = skill_name == "Temptation"
	var is_intimidation: bool = skill_name == "Intimidation"
	var is_sincerity_deceit: bool = (skill_name == "Sincerity" and emphasis_name == "Deceit")

	# --- Mutations ---

	# ALBINISM: -1k0 Social if true appearance is known
	if has_mutation(character, Enums.MutationType.ALBINISM) and is_social:
		if context.get("appearance_known", false):
			dr -= 1

	# DISCOLORED_SKIN: +5 TN all Social rolls
	if has_mutation(character, Enums.MutationType.DISCOLORED_SKIN) and is_social:
		dtn += 5

	# DISTORTED_LIMBS (arm): -3k0 to rolls made with that arm
	if is_social:
		pass  # arm rolls are physical actions (s40), not skill rolls
	for m: MutationData in character.mutations:
		if m.mutation_type == Enums.MutationType.DISTORTED_LIMBS and m.affected_limb == "arm":
			if context.get("uses_distorted_arm", false):
				dr -= 3

	# EXTRA_DIGIT: -1k0 Social
	if has_mutation(character, Enums.MutationType.EXTRA_DIGIT) and is_social:
		dr -= 1

	# EXTRA_EYE: +1k0 Perception / Perception-based (eye must be uncovered)
	if has_mutation(character, Enums.MutationType.EXTRA_EYE) and is_perception_based:
		if context.get("extra_eye_uncovered", true):  # uncovered by default for NPC context
			dr += 1

	# EXTRA_LIMB (non-functional): -1k0 Agility-based and Reflexes-based
	for m: MutationData in character.mutations:
		if m.mutation_type == Enums.MutationType.EXTRA_LIMB and m.is_non_functional:
			if _is_agility_or_reflexes_based(skill_name):
				dr -= 1

	# FOUL_ODOR: -1k0 Social
	if has_mutation(character, Enums.MutationType.FOUL_ODOR) and is_social:
		dr -= 1

	# TOUGH_HIDE: -2k0 Social
	if has_mutation(character, Enums.MutationType.TOUGH_HIDE) and is_social:
		dr -= 2

	# --- Powers ---

	# MASTER_OF_SHADOWS: add Taint Rank in unkept dice to Stealth
	if has_power(character, Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS) and is_stealth:
		dr += taint_rank

	# MONSTROUS_STRENGTH: -1k0 Social; add Taint Rank unkept to Strength rolls
	if has_power(character, Enums.ShadowlandsPowerType.MONSTROUS_STRENGTH):
		if is_social:
			dr -= 1
		if is_strength_based:
			dr += taint_rank

	# FATHER_OF_LIES: add Taint Rank in kept dice to Temptation, Intimidation, Sincerity:Deceit
	if has_power(character, Enums.ShadowlandsPowerType.FATHER_OF_LIES):
		if is_temptation or is_intimidation or is_sincerity_deceit:
			dk += taint_rank

	return {"rolled": dr, "kept": dk, "tn": dtn}


# ---------------------------------------------------------------------------
# Maho interaction  (called by MahoSystem.resolve_cast)
# ---------------------------------------------------------------------------

## Returns modified blood cost and taint gain for MASTER_OF_BLOOD holders.
## If the character doesn't have the power, returns the original values unchanged.
static func apply_master_of_blood(
	character: L5RCharacterData,
	base_blood_cost: int,
	base_taint_gain: int,
) -> Dictionary:
	if not has_power(character, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD):
		return {"blood_cost": base_blood_cost, "taint_gain": base_taint_gain}

	var earth_ring: int = mini(character.stamina, character.willpower)
	var new_cost: int = maxi(1, base_blood_cost - 1)  # one fewer Wound (min 1)
	var new_gain: int = maxi(1, base_taint_gain - earth_ring)  # reduced by Earth (min 1)
	return {"blood_cost": new_cost, "taint_gain": new_gain}


# ---------------------------------------------------------------------------
# Social roll TN penalty helper (for DayOrchestrator / NPC context injection)
# ---------------------------------------------------------------------------

## Returns the total -Xk0 Social roll penalty from active mutations and powers.
## Positive = penalty (worse for the character).
static func get_social_rolled_penalty(character: L5RCharacterData) -> int:
	var penalty: int = 0
	if has_mutation(character, Enums.MutationType.ALBINISM):
		penalty += 1  # only if appearance_known; caller must check context
	if has_mutation(character, Enums.MutationType.EXTRA_DIGIT):
		penalty += 1
	if has_mutation(character, Enums.MutationType.FOUL_ODOR):
		penalty += 1
	if has_mutation(character, Enums.MutationType.TOUGH_HIDE):
		penalty += 2
	if has_power(character, Enums.ShadowlandsPowerType.MONSTROUS_STRENGTH):
		penalty += 1
	return penalty


## Returns the total Social TN penalty from active mutations (flat TN modifiers).
static func get_social_tn_penalty(character: L5RCharacterData) -> int:
	var penalty: int = 0
	if has_mutation(character, Enums.MutationType.DISCOLORED_SKIN):
		penalty += 5
	return penalty


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

const SOCIAL_SKILLS: Array[String] = [
	"Acting", "Courtier", "Etiquette", "Sincerity", "Intimidation", "Temptation",
]

const PERCEPTION_SKILLS: Array[String] = [
	"Investigation", "Medicine", "Hunting",
]

const STRENGTH_SKILLS: Array[String] = [
	"Athletics", "Commerce",
]

const AGILITY_SKILLS: Array[String] = [
	"Defense", "Kenjutsu", "Iaijutsu", "Kyujutsu", "Jiujutsu", "Knives",
	"Heavy Weapons", "Polearms", "Spears", "Staves",
]

const REFLEXES_SKILLS: Array[String] = [
	"Stealth",
]


static func _is_social_skill(skill_name: String) -> bool:
	return SOCIAL_SKILLS.has(skill_name)


static func _is_perception_based(skill_name: String) -> bool:
	return PERCEPTION_SKILLS.has(skill_name)


static func _is_strength_based(skill_name: String) -> bool:
	return STRENGTH_SKILLS.has(skill_name)


static func _is_agility_or_reflexes_based(skill_name: String) -> bool:
	return AGILITY_SKILLS.has(skill_name) or REFLEXES_SKILLS.has(skill_name)


static func _add_lame_disadvantage(character: L5RCharacterData) -> void:
	for d: DisadvantageData in character.disadvantages:
		if d.disadvantage_type == Enums.Disadvantage.LAME:
			return  # already has it
	var d := DisadvantageData.new()
	d.disadvantage_type = Enums.Disadvantage.LAME
	d.rank = 1
	d.metadata = {}
	character.disadvantages.append(d)
