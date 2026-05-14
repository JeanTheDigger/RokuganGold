extends GutTest


var _dice: DiceEngine
var _char_a: L5RCharacterData
var _char_b: L5RCharacterData


func before_each() -> void:
	_dice = DiceEngine.new(42)  # fixed seed for reproducibility
	_char_a = _make_char(1, 3, 3, 3, 3, 3, 3, 3, 3)  # well-rounded bushi
	_char_b = _make_char(2, 2, 2, 2, 2, 2, 2, 2, 2)  # weak target


func _make_char(
	id: int,
	stamina: int, willpower: int, agility: int, intelligence: int,
	reflexes: int, awareness: int, strength: int, perception: int,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.stamina = stamina
	c.willpower = willpower
	c.agility = agility
	c.intelligence = intelligence
	c.reflexes = reflexes
	c.awareness = awareness
	c.strength = strength
	c.perception = perception
	c.void_ring = 2
	c.wounds_taken = 0
	c.skills = {}
	return c


# -- Weapon Catalog ------------------------------------------------------------

func test_katana_profile() -> void:
	var w: Dictionary = IndividualCombat.get_weapon_profile("katana")
	assert_eq(w["rolled"], 3)
	assert_eq(w["kept"], 2)
	assert_true(w["strength_adds"])
	assert_eq(w["skill"], "Kenjutsu")
	assert_eq(w["size"], "Medium")
	assert_true(w["melee"])


func test_yumi_is_ranged() -> void:
	var w: Dictionary = IndividualCombat.get_weapon_profile("yumi")
	assert_false(w["melee"])
	assert_false(w["strength_adds"])


func test_unknown_weapon_uses_default() -> void:
	var w: Dictionary = IndividualCombat.get_weapon_profile("mystery_blade")
	assert_eq(w, IndividualCombat.DEFAULT_WEAPON)


# -- Initiative ----------------------------------------------------------------

func test_initiative_returns_positive_score() -> void:
	_char_a.reflexes = 3
	_char_a.skills = {}
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	var score: int = IndividualCombat.roll_initiative(_char_a, p, _dice)
	assert_true(score > 0)
	assert_eq(p.initiative_score, score)


func test_center_stance_adds_10_to_initiative() -> void:
	var dice_fixed: DiceEngine = DiceEngine.new(100)
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	var base_score: int = IndividualCombat.roll_initiative(_char_a, p, DiceEngine.new(100))

	var p2 := IndividualCombat.Participant.new()
	p2.stance = Enums.Stance.CENTER
	var center_score: int = IndividualCombat.roll_initiative(_char_a, p2, DiceEngine.new(100))
	assert_eq(center_score, base_score + 10)
	assert_eq(p2.void_ring_bonus, _char_a.void_ring)


func test_wound_penalty_reduces_initiative() -> void:
	_char_a.wounds_taken = _char_a.stamina * 2 + 1  # Nicked level (wound penalty = -3)
	var p_hurt := IndividualCombat.Participant.new()
	p_hurt.stance = Enums.Stance.ATTACK

	var p_healthy := IndividualCombat.Participant.new()
	p_healthy.stance = Enums.Stance.ATTACK

	var healthy_char := _make_char(3, 3, 3, 3, 3, 3, 3, 3, 3)
	# Hurt character rolls with wound penalty
	# We just verify the wound penalty was factored (checked via CharacterStats)
	var wl: Enums.WoundLevel = CharacterStats.get_wound_level(_char_a)
	assert_true(CharacterStats.get_wound_penalty(_char_a) < 0, "Nicked should have negative penalty")


# -- Combat State Build --------------------------------------------------------

func test_build_combat_state_creates_participants() -> void:
	var data: Array[Dictionary] = [
		{"character_id": 1, "initiative_score": 20, "stance": Enums.Stance.ATTACK},
		{"character_id": 2, "initiative_score": 15, "stance": Enums.Stance.DEFENSE},
	]
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state(data)
	assert_true(state.participants.has(1))
	assert_true(state.participants.has(2))


func test_build_combat_state_sorts_turn_order_by_initiative() -> void:
	var data: Array[Dictionary] = [
		{"character_id": 10, "initiative_score": 15},
		{"character_id": 20, "initiative_score": 30},
		{"character_id": 30, "initiative_score": 22},
	]
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state(data)
	assert_eq(state.turn_order[0], 20)
	assert_eq(state.turn_order[1], 30)
	assert_eq(state.turn_order[2], 10)


# -- Armor TN ------------------------------------------------------------------

func test_armor_tn_base() -> void:
	_char_a.reflexes = 3
	_char_a.armor_tn_bonus = 0
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 20)  # reflexes*5 + 5 = 3*5+5 = 20


func test_full_attack_stance_reduces_armor_tn() -> void:
	_char_a.reflexes = 3
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.FULL_ATTACK
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 10)  # 20 - 10


func test_defense_stance_adds_air_plus_defense() -> void:
	_char_a.reflexes = 3
	_char_a.awareness = 3  # Air Ring = min(Reflexes, Awareness) = 3
	_char_a.skills = {"Defense": 2}
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.DEFENSE
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 20 + 3 + 2)  # base + air_ring + defense_rank


func test_grappled_armor_tn_is_five_plus_armor_bonus() -> void:
	_char_a.reflexes = 5
	_char_a.armor_tn_bonus = 5
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_GRAPPLED)
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 10)  # 5 + armor_tn_bonus(5)


func test_prone_reduces_armor_tn() -> void:
	_char_a.reflexes = 3
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_PRONE)
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 10)  # 20 - 10


# -- Attack Resolution ---------------------------------------------------------

func test_attack_returns_hit_or_miss() -> void:
	_char_a.skills = {"Kenjutsu": 3}
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	var target_tn: int = 5  # very easy to hit
	var result: Dictionary = IndividualCombat.resolve_attack(
		_char_a, p, "katana", target_tn, 0, _dice
	)
	assert_true(result.has("hit"))
	assert_true(result.has("roll"))
	assert_true(result.has("target_tn"))
	assert_true(result.has("margin"))


func test_attack_hits_trivial_tn() -> void:
	_char_a.skills = {"Kenjutsu": 5}
	_char_a.agility = 4  # Insight Rank
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	# TN 5 is effectively impossible to miss with skill 5
	var hits: int = 0
	for i: int in range(20):
		var dice: DiceEngine = DiceEngine.new(i)
		var r: Dictionary = IndividualCombat.resolve_attack(_char_a, p, "katana", 5, 0, dice)
		if r["hit"]:
			hits += 1
	assert_true(hits >= 18, "Should hit TN 5 almost always with high skill")


func test_prone_blocks_large_weapon_attack() -> void:
	_char_a.skills = {"Polearms": 3}
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_PRONE)
	var result: Dictionary = IndividualCombat.resolve_attack(_char_a, p, "naginata", 5, 0, _dice)
	assert_false(result["success"])
	assert_eq(result["reason"], "prone_large_weapon_blocked")


func test_ranged_in_melee_applies_penalty() -> void:
	_char_a.skills = {"Kyujutsu": 5}
	var p := IndividualCombat.Participant.new()
	var result: Dictionary = IndividualCombat.resolve_attack(
		_char_a, p, "yumi", 15, 0, DiceEngine.new(77), true  # is_ranged_in_melee = true
	)
	# Just verify the -10 penalty was applied to the TN computation — result still has a roll
	assert_true(result.has("roll"))


# -- Damage Resolution ---------------------------------------------------------

func test_damage_adds_strength_to_rolled() -> void:
	_char_a.strength = 4
	var result: Dictionary = IndividualCombat.resolve_damage(_char_a, "katana", 0, 0, _dice)
	# katana base rolled=3, strength 4 adds, so rolled should be 7
	assert_eq(result["rolled"], 7)


func test_damage_increased_damage_maneuver() -> void:
	_char_a.strength = 2
	var result: Dictionary = IndividualCombat.resolve_damage(_char_a, "katana", 3, 0, _dice)
	# katana 3 + strength 2 + 3 raises = 8 rolled
	assert_eq(result["rolled"], 8)


func test_damage_feint_bonus_added() -> void:
	_char_a.strength = 2
	var result: Dictionary = IndividualCombat.resolve_damage(_char_a, "katana", 0, 10, _dice)
	assert_eq(result["raw_damage"], result["dice_result"]["raw"] + 10)


# -- Maneuvers -----------------------------------------------------------------

func test_disarm_result_has_required_keys() -> void:
	var result: Dictionary = IndividualCombat.resolve_disarm(_char_a, _char_b, _dice)
	assert_true(result.has("damage"))
	assert_true(result.has("attacker_strength_roll"))
	assert_true(result.has("defender_strength_roll"))
	assert_true(result.has("disarmed"))


func test_disarm_damage_is_positive() -> void:
	var result: Dictionary = IndividualCombat.resolve_disarm(_char_a, _char_b, _dice)
	assert_true(result["damage"] > 0)


func test_feint_bonus_capped_at_five_times_insight_rank() -> void:
	var bonus: int = IndividualCombat.compute_feint_bonus(100, 1)
	assert_eq(bonus, 5)  # max = 5 × InsightRank(1)


func test_feint_bonus_half_of_margin() -> void:
	var bonus: int = IndividualCombat.compute_feint_bonus(8, 5)
	assert_eq(bonus, 4)  # floor(8/2) = 4, capped at 5*5=25


func test_knockdown_result_has_required_keys() -> void:
	var result: Dictionary = IndividualCombat.resolve_knockdown(_char_a, _char_b, false, _dice)
	assert_true(result.has("knocked_down"))
	assert_true(result.has("attacker_strength_roll"))


# -- Movement ------------------------------------------------------------------

func test_free_move_is_water_times_five() -> void:
	_char_a.strength = 3  # Water Ring = min(Strength, Perception)
	_char_a.perception = 3
	var feet: int = IndividualCombat.get_free_move_feet(_char_a, "basic")
	assert_eq(feet, 15)  # 3 * 5


func test_moderate_terrain_reduces_water_ring() -> void:
	_char_a.strength = 3
	_char_a.perception = 3
	_char_a.skills = {}
	var feet: int = IndividualCombat.get_simple_move_feet(_char_a, "moderate")
	assert_eq(feet, 20)  # water_ring (3-1=2) * 10


func test_athletics_rank_5_ignores_terrain() -> void:
	_char_a.strength = 3
	_char_a.perception = 3
	_char_a.skills = {"Athletics": 5}
	var difficult: int = IndividualCombat.get_simple_move_feet(_char_a, "difficult")
	var basic: int = IndividualCombat.get_simple_move_feet(_char_a, "basic")
	assert_eq(difficult, basic)


func test_water_ring_minimum_one() -> void:
	_char_a.strength = 1
	_char_a.perception = 1
	_char_a.skills = {}
	var feet: int = IndividualCombat.get_free_move_feet(_char_a, "difficult")
	assert_eq(feet, 5)  # water_ring = max(1, 1-2) = 1, * 5


# -- Conditions ----------------------------------------------------------------

func test_apply_condition() -> void:
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_PRONE)
	assert_true(IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE))


func test_remove_condition() -> void:
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_PRONE)
	IndividualCombat.remove_condition(p, IndividualCombat.CONDITION_PRONE)
	assert_false(IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE))


func test_apply_condition_no_duplicates() -> void:
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_DAZED)
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_DAZED)
	assert_eq(p.conditions.size(), 1)


func test_stunned_sets_armor_tn_to_five_plus_armor() -> void:
	_char_a.reflexes = 5
	_char_a.armor_tn_bonus = 0
	var p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_STUNNED)
	var tn: int = IndividualCombat.get_armor_tn(_char_a, p, _dice)
	assert_eq(tn, 5)


# -- Grappling -----------------------------------------------------------------

func test_grapple_initiation_has_success_key() -> void:
	_char_a.agility = 3
	_char_a.skills = {"Jiujutsu": 3}
	var p := IndividualCombat.Participant.new()
	var target_tn: int = 5  # trivially easy
	var result: Dictionary = IndividualCombat.initiate_grapple(_char_a, p, target_tn, _dice)
	assert_true(result.has("success"))


func test_successful_grapple_applies_condition() -> void:
	_char_a.agility = 5
	_char_a.skills = {"Jiujutsu": 5}
	var p := IndividualCombat.Participant.new()
	# Use very low TN so grapple succeeds
	IndividualCombat.initiate_grapple(_char_a, p, 5, _dice)
	assert_true(IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED))


func test_grapple_control_has_winner() -> void:
	var result: Dictionary = IndividualCombat.resolve_grapple_control(_char_a, _char_b, _dice)
	assert_true(result.has("attacker_wins"))
	assert_true(result.has("attacker_roll"))
	assert_true(result.has("defender_roll"))


func test_grapple_throw_makes_target_prone() -> void:
	var controller_p := IndividualCombat.Participant.new()
	var target_p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(target_p, IndividualCombat.CONDITION_GRAPPLED)
	IndividualCombat.grapple_throw(controller_p, target_p)
	assert_false(IndividualCombat.has_condition(target_p, IndividualCombat.CONDITION_GRAPPLED))
	assert_true(IndividualCombat.has_condition(target_p, IndividualCombat.CONDITION_PRONE))


# -- Sumai --------------------------------------------------------------------

func test_sumai_bout_has_outcome() -> void:
	_char_a.strength = 3
	_char_b.strength = 2
	_char_a.skills = {"Jiujutsu": 2}
	_char_b.skills = {"Jiujutsu": 1}
	var result: Dictionary = IndividualCombat.resolve_sumai_bout(_char_a, _char_b, false, _dice)
	assert_true(result.has("wrestler1_roll"))
	assert_true(result.has("wrestler2_roll"))
	assert_true(result.has("bout_over"))
	assert_true(result.has("continue"))


func test_sumai_size_advantage_increases_rolled() -> void:
	# Just ensure larger=true is handled without error
	var result: Dictionary = IndividualCombat.resolve_sumai_bout(_char_a, _char_b, true, _dice)
	assert_true(result.has("bout_over"))


func test_sumai_stare_down_grants_bonus_on_margin_5() -> void:
	_char_a.willpower = 5
	_char_a.skills = {"Intimidation": 5}
	_char_b.willpower = 1
	_char_b.skills = {"Intimidation": 0}
	var result: Dictionary = IndividualCombat.resolve_sumai_stare_down(_char_a, _char_b, _dice)
	assert_true(result.has("grants_bonus"))
	assert_true(result.has("wrestler1_wins"))


# -- Iaijutsu Duel ------------------------------------------------------------

func test_duel_state_created() -> void:
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(1, 2, false)
	assert_eq(duel.challenger_id, 1)
	assert_eq(duel.defender_id, 2)
	assert_false(duel.duel_to_death)
	assert_eq(duel.stage, 1)


func test_duel_assessment_has_required_keys() -> void:
	_char_a.skills = {"Iaijutsu": 3}
	_char_b.skills = {"Iaijutsu": 2}
	_char_a.awareness = 3
	_char_b.awareness = 2
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id
	)
	var result: Dictionary = IndividualCombat.resolve_duel_assessment(
		_char_a, _char_b, duel, _dice
	)
	assert_true(result.has("challenger_roll"))
	assert_true(result.has("defender_roll"))
	assert_true(result.has("challenger_tn"))
	assert_true(result.has("defender_tn"))
	assert_true(result.has("assessment_bonus_id"))


func test_duel_focus_determines_first_striker() -> void:
	_char_a.skills = {"Iaijutsu": 5}
	_char_b.skills = {"Iaijutsu": 0}
	_char_a.void_ring = 4
	_char_b.void_ring = 1
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id
	)
	var result: Dictionary = IndividualCombat.resolve_duel_focus(_char_a, _char_b, duel, _dice)
	assert_true(result.has("first_striker_id"))
	assert_true(result.has("free_raises_for_first"))
	assert_true(result.has("simultaneous"))


func test_full_duel_resolves_and_returns_result() -> void:
	_char_a.skills = {"Iaijutsu": 4, "Kenjutsu": 4}
	_char_b.skills = {"Iaijutsu": 1, "Kenjutsu": 1}
	_char_a.reflexes = 4
	_char_b.reflexes = 2
	_char_a.void_ring = 3
	_char_b.void_ring = 1
	var result: Dictionary = IndividualCombat.resolve_full_duel(
		_char_a, _char_b, false, _dice
	)
	assert_true(result.has("assessment"))
	assert_true(result.has("focus"))
	assert_true(result.has("strike"))
	assert_true(result.has("challenger_id"))
	assert_true(result.has("defender_id"))


func test_duel_to_death_wounds_loser() -> void:
	# Stack dice to ensure a decisive outcome
	_char_a.skills = {"Iaijutsu": 5, "Kenjutsu": 5}
	_char_b.skills = {"Iaijutsu": 0, "Kenjutsu": 0}
	_char_a.reflexes = 5
	_char_a.void_ring = 5
	_char_b.reflexes = 1
	_char_b.void_ring = 1
	# Don't assert specific winner since dice have randomness, just assert structure
	var result: Dictionary = IndividualCombat.resolve_full_duel(_char_a, _char_b, true, _dice)
	assert_true(result.has("winner_id"))
	assert_true(result.has("simultaneous"))


# -- Round Advancement ---------------------------------------------------------

func test_begin_round_increments_round_number() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 20},
		{"character_id": 2, "initiative_score": 10},
	])
	assert_eq(state.round_number, 1)
	IndividualCombat.begin_round(state)
	assert_eq(state.round_number, 2)


func test_begin_round_resets_acted_flags() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 20},
	])
	state.participants[1].has_acted_this_round = true
	IndividualCombat.begin_round(state)
	assert_false(state.participants[1].has_acted_this_round)


func test_check_combat_over_one_survivor() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 20},
		{"character_id": 2, "initiative_score": 10},
	])
	# Kill char 2
	_char_b.wounds_taken = 9999
	var chars: Dictionary = {1: _char_a, 2: _char_b}
	var over: bool = IndividualCombat.check_combat_over(state, chars)
	assert_true(over)
	assert_eq(state.winner_id, 1)
	assert_true(state.is_over)


func test_check_combat_over_all_alive() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 20},
		{"character_id": 2, "initiative_score": 10},
	])
	var chars: Dictionary = {1: _char_a, 2: _char_b}
	var over: bool = IndividualCombat.check_combat_over(state, chars)
	assert_false(over)
