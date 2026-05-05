class_name DiceEngine
## The single authoritative entry point for all dice rolling in the game.
## Every system that needs randomness calls through here. No other file
## should call randi(), randf(), or RandomNumberGenerator methods directly.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


# -- Core Roll & Keep ----------------------------------------------------------

func roll_and_keep(rolled: int, kept: int, explodes: bool = true) -> DiceResult:
	if rolled <= 0 or kept <= 0:
		return DiceResult.new([], [], 0)

	if kept > rolled:
		kept = rolled

	# L5R4e 10-dice cap: never roll or keep more than 10. Each excess die
	# converts to a flat +2 bonus on the final total.
	var overflow_bonus: int = 0
	if rolled > 10:
		overflow_bonus += (rolled - 10) * 2
		rolled = 10
	if kept > 10:
		overflow_bonus += (kept - 10) * 2
		kept = 10

	var all_dice: Array[int] = []
	var explosion_count: int = 0

	for i: int in range(rolled):
		var die_total: int = 0
		var face: int = _roll_d10()
		die_total += face
		if explodes:
			while face == 10:
				face = _roll_d10()
				die_total += face
				explosion_count += 1
		all_dice.append(die_total)

	all_dice.sort()
	all_dice.reverse()

	var kept_dice: Array[int] = []
	var dropped_dice: Array[int] = []

	for i: int in range(all_dice.size()):
		if i < kept:
			kept_dice.append(all_dice[i])
		else:
			dropped_dice.append(all_dice[i])

	return DiceResult.new(kept_dice, dropped_dice, explosion_count, overflow_bonus)


# -- Raw Check Against TN ------------------------------------------------------

func roll_check(rolled: int, kept: int, tn: int, raises: int = 0, bonus: int = 0, explodes: bool = true) -> Dictionary:
	var effective_tn: int = tn + (raises * 5)
	var result: DiceResult = roll_and_keep(rolled, kept, explodes)
	var final_total: int = result.total + bonus
	var success: bool = final_total >= effective_tn

	return {
		"success": success,
		"total": final_total,
		"tn": effective_tn,
		"margin": final_total - effective_tn,
		"dice": result,
	}


# -- Skill Check (handles unskilled rule) -------------------------------------
# L5R4e p.78: Unskilled rolls (skill_rank == 0) do NOT explode.
# Rolled = trait + skill_rank, Kept = trait.

func roll_skill_check(trait_value: int, skill_rank: int, tn: int, raises: int = 0, bonus: int = 0) -> Dictionary:
	var rolled: int = trait_value + skill_rank
	var kept: int = trait_value
	var explodes: bool = skill_rank > 0
	return roll_check(rolled, kept, tn, raises, bonus, explodes)


# -- Contested Roll ------------------------------------------------------------

func contested_roll(
	rolled_a: int, kept_a: int,
	rolled_b: int, kept_b: int,
	bonus_a: int = 0, bonus_b: int = 0,
	explodes: bool = true
) -> Dictionary:
	var result_a: DiceResult = roll_and_keep(rolled_a, kept_a, explodes)
	var result_b: DiceResult = roll_and_keep(rolled_b, kept_b, explodes)
	var total_a: int = result_a.total + bonus_a
	var total_b: int = result_b.total + bonus_b

	var winner: String = "a"
	if total_b > total_a:
		winner = "b"
	elif total_a == total_b:
		winner = "tie"

	return {
		"winner": winner,
		"total_a": total_a,
		"total_b": total_b,
		"dice_a": result_a,
		"dice_b": result_b,
	}


# -- Initiative ----------------------------------------------------------------

func roll_initiative(reflexes: int, insight_rank: int) -> DiceResult:
	return roll_and_keep(reflexes + insight_rank, reflexes)


# -- Damage Roll ---------------------------------------------------------------

func roll_damage(rolled: int, kept: int, strength_bonus: int = 0, reduction: int = 0) -> Dictionary:
	var result: DiceResult = roll_and_keep(rolled + strength_bonus, kept)
	var raw_damage: int = result.total
	var final_damage: int = maxi(0, raw_damage - reduction)

	return {
		"raw": raw_damage,
		"reduction": reduction,
		"final": final_damage,
		"dice": result,
	}


# -- Raw d10 (private) --------------------------------------------------------

func _roll_d10() -> int:
	return _rng.randi_range(1, 10)
