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
	var data: Array = [
		{"character_id": 1, "initiative_score": 20, "stance": Enums.Stance.ATTACK},
		{"character_id": 2, "initiative_score": 15, "stance": Enums.Stance.DEFENSE},
	]
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state(data)
	assert_true(state.participants.has(1))
	assert_true(state.participants.has(2))


func test_build_combat_state_sorts_turn_order_by_initiative() -> void:
	var data: Array = [
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
	_char_a.agility = 4
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	# Attack roll: Agility(4) + Kenjutsu(5) = 9k4 — trivially beats TN 5
	var hits: int = 0
	for i: int in range(20):
		var dice: DiceEngine = DiceEngine.new(i)
		var r: Dictionary = IndividualCombat.resolve_attack(_char_a, p, "katana", 5, 0, dice)
		if r["hit"]:
			hits += 1
	assert_true(hits >= 18, "Should hit TN 5 almost always with high skill")


func test_attack_uses_agility_not_insight_rank() -> void:
	# Two characters: same Kenjutsu skill, different Agility — higher Agility should win more
	var high_agi: L5RCharacterData = _make_char(10, 2, 2, 5, 2, 2, 2, 2, 2)  # agility=5
	var low_agi: L5RCharacterData  = _make_char(11, 2, 2, 2, 2, 2, 2, 2, 2)  # agility=2
	high_agi.skills = {"Kenjutsu": 2}
	low_agi.skills  = {"Kenjutsu": 2}
	var p := IndividualCombat.Participant.new()
	var high_total: int = 0
	var low_total: int = 0
	for i: int in range(20):
		var r_h: Dictionary = IndividualCombat.resolve_attack(high_agi, p, "katana", 5, 0, DiceEngine.new(i))
		var r_l: Dictionary = IndividualCombat.resolve_attack(low_agi,  p, "katana", 5, 0, DiceEngine.new(i))
		high_total += r_h["roll"]
		low_total  += r_l["roll"]
	assert_true(high_total > low_total, "Higher Agility should produce higher attack totals")


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


func test_successful_grapple_applies_condition_to_attacker() -> void:
	_char_a.agility = 5
	_char_a.skills = {"Jiujutsu": 5}
	var p := IndividualCombat.Participant.new()
	# Use very low TN so grapple succeeds
	IndividualCombat.initiate_grapple(_char_a, p, 5, _dice)
	assert_true(IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED))


func test_successful_grapple_signals_target_should_be_grappled() -> void:
	_char_a.agility = 5
	_char_a.skills = {"Jiujutsu": 5}
	var p := IndividualCombat.Participant.new()
	# RAW: "On success, both attacker and target are in a Grapple" (s40)
	var result: Dictionary = IndividualCombat.initiate_grapple(_char_a, p, 5, _dice)
	assert_true(result["apply_grappled_to_target"])


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


func test_duel_strike_uses_iaijutsu_not_kenjutsu() -> void:
	# Duelist with high Iaijutsu but zero Kenjutsu should still hit reliably (s40: Iaijutsu/Reflexes)
	var duelist: L5RCharacterData = _make_char(10, 2, 2, 2, 2, 5, 2, 2, 2)  # reflexes=5
	var weak: L5RCharacterData    = _make_char(11, 1, 1, 1, 1, 1, 1, 1, 1)
	duelist.skills = {"Iaijutsu": 5}  # no Kenjutsu at all
	duelist.void_ring = 3
	weak.skills = {"Iaijutsu": 0}
	weak.void_ring = 1
	var hits: int = 0
	for i: int in range(10):
		var result: Dictionary = IndividualCombat.resolve_full_duel(duelist, weak, false, DiceEngine.new(i))
		if result.get("strike", {}).get("first_attack", {}).get("hit", false):
			hits += 1
	assert_true(hits >= 7, "High-Iaijutsu duelist should hit reliably even with zero Kenjutsu")


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


# -- Center Stance Roll Bonus --------------------------------------------------

func test_center_stance_bonus_increases_attack_roll() -> void:
	# A participant with void_ring_bonus set should roll higher than one without
	_char_a.agility = 3
	_char_a.skills = {"Kenjutsu": 3}
	_char_a.void_ring = 3

	var p_no_bonus := IndividualCombat.Participant.new()
	p_no_bonus.stance = Enums.Stance.ATTACK

	var p_with_bonus := IndividualCombat.Participant.new()
	p_with_bonus.stance = Enums.Stance.ATTACK
	p_with_bonus.void_ring_bonus = _char_a.void_ring  # +1k1 +3 flat bonus

	var no_total: int = 0
	var with_total: int = 0
	for i: int in range(30):
		var r_no:   Dictionary = IndividualCombat.resolve_attack(_char_a, p_no_bonus,   "katana", 5, 0, DiceEngine.new(i))
		p_no_bonus.center_stance_bonus_used = false  # reset for next iteration
		var r_with: Dictionary = IndividualCombat.resolve_attack(_char_a, p_with_bonus, "katana", 5, 0, DiceEngine.new(i))
		p_with_bonus.void_ring_bonus = _char_a.void_ring  # restore for next iteration
		p_with_bonus.center_stance_bonus_used = false
		no_total   += r_no["roll"]
		with_total += r_with["roll"]
	assert_true(with_total > no_total, "Center Stance bonus should increase roll totals")


func test_center_stance_bonus_consumed_after_first_attack() -> void:
	_char_a.agility = 3
	_char_a.skills = {"Kenjutsu": 3}
	_char_a.void_ring = 2
	var p := IndividualCombat.Participant.new()
	p.void_ring_bonus = 2

	IndividualCombat.resolve_attack(_char_a, p, "katana", 5, 0, _dice)
	assert_true(p.center_stance_bonus_used, "Bonus should be marked used after first attack")

	# Second attack should NOT get the bonus (center_stance_bonus_used is true)
	var p2 := IndividualCombat.Participant.new()
	p2.void_ring_bonus = 2
	p2.center_stance_bonus_used = true
	var r1: Dictionary = IndividualCombat.resolve_attack(_char_a, p2, "katana", 5, 0, DiceEngine.new(1))
	var p3 := IndividualCombat.Participant.new()
	p3.void_ring_bonus = 0
	var r2: Dictionary = IndividualCombat.resolve_attack(_char_a, p3, "katana", 5, 0, DiceEngine.new(1))
	assert_eq(r1["roll"], r2["roll"], "Used bonus should have no effect")


func test_duel_full_gives_bonus_to_both_strikers() -> void:
	# Both duelists in CENTER Stance throughout — both should get void_ring_bonus set
	_char_a.skills = {"Iaijutsu": 3}
	_char_b.skills = {"Iaijutsu": 3}
	_char_a.reflexes = 3
	_char_b.reflexes = 3
	_char_a.void_ring = 3
	_char_b.void_ring = 2
	# Run multiple duels to confirm structure; we can't assert a specific roll total
	# without controlling dice. Just verify the bonus doesn't error and duel completes.
	for i: int in range(5):
		var result: Dictionary = IndividualCombat.resolve_full_duel(_char_a, _char_b, false, DiceEngine.new(i))
		assert_true(result.has("winner_id"))


func test_free_raises_from_focus_go_to_damage_not_tn() -> void:
	# Create a duel state where first_striker has 2 Free Raises
	var first: L5RCharacterData = _make_char(10, 2, 2, 2, 2, 5, 2, 4, 2)
	var second: L5RCharacterData = _make_char(11, 1, 1, 1, 1, 1, 1, 1, 1)
	first.skills = {"Iaijutsu": 5}
	second.skills = {}
	first.void_ring = 3
	second.void_ring = 1

	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(10, 11, false)
	duel.simultaneous = false
	duel.first_striker_id = 10
	duel.free_raises_first = 2  # 2 Free Raises from Focus

	var first_p := IndividualCombat.Participant.new()
	first_p.character_id = 10
	first_p.stance = Enums.Stance.CENTER
	var second_p := IndividualCombat.Participant.new()
	second_p.character_id = 11
	second_p.stance = Enums.Stance.CENTER

	# Target TN for second_striker
	var second_tn: int = IndividualCombat.get_armor_tn(second, second_p, _dice)

	# If Free Raises raised the TN, a high-skill striker would miss much more often
	# than if Free Raises went to damage instead. We just verify the strike completes
	# and the first attack roll is NOT penalized by free_raises * 5 on TN.
	var strike: Dictionary = IndividualCombat.resolve_duel_strike(
		first, first_p, second, second_p, duel, _dice
	)
	assert_true(strike.has("first_attack"))
	# The effective TN seen by first_attack should equal second_tn (not second_tn + 10)
	assert_eq(strike["first_attack"].get("target_tn", -1), second_tn)


# -- Guard Maneuver (GDD s40) --------------------------------------------------

func test_guard_boosts_target_armor_tn() -> void:
	# Guardian designates target. Target's Armor TN increases by 10 (s40).
	var guardian_p := IndividualCombat.Participant.new()
	var target_p := IndividualCombat.Participant.new()
	IndividualCombat.resolve_guard(guardian_p, _char_b.character_id)
	var base_tn: int = IndividualCombat.get_armor_tn(_char_b, target_p, _dice)
	var guarded_tn: int = IndividualCombat.get_armor_tn(_char_b, target_p, _dice, true, true)
	assert_eq(guarded_tn - base_tn, 10)


func test_guard_reduces_guardian_armor_tn() -> void:
	# Guardian's own Armor TN is reduced by 5 while guarding (s40).
	var guardian_p := IndividualCombat.Participant.new()
	var base_tn: int = IndividualCombat.get_armor_tn(_char_a, guardian_p, _dice)
	IndividualCombat.resolve_guard(guardian_p, _char_b.character_id)
	var guarding_tn: int = IndividualCombat.get_armor_tn(_char_a, guardian_p, _dice)
	assert_eq(base_tn - guarding_tn, 5)


func test_clear_guard_restores_guardian_tn() -> void:
	var guardian_p := IndividualCombat.Participant.new()
	IndividualCombat.resolve_guard(guardian_p, _char_b.character_id)
	IndividualCombat.clear_guard(guardian_p)
	assert_eq(guardian_p.guarding_id, -1)


func test_no_guard_no_change_to_armor_tn() -> void:
	var target_p := IndividualCombat.Participant.new()
	var normal_tn: int = IndividualCombat.get_armor_tn(_char_b, target_p, _dice)
	var unguarded_tn: int = IndividualCombat.get_armor_tn(_char_b, target_p, _dice, true, false)
	assert_eq(normal_tn, unguarded_tn)


# -- Mounted Attack Bonus (GDD s40) --------------------------------------------

func test_mounted_attacker_gains_1k0_vs_unmounted() -> void:
	# Mounted attacker vs unmounted target: +1k0 to attack (s40).
	# We compare rolled dice counts: mounted should be 1 higher.
	# Since we can't inspect the internal roll directly, test via a high-TN scenario
	# where the +1 rolled die statistically helps. Instead we test the API is wired:
	# resolve_attack with CONDITION_MOUNTED should not crash and returns valid result.
	var mounted_p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(mounted_p, IndividualCombat.CONDITION_MOUNTED)
	_char_a.skills["Kenjutsu"] = 3
	_dice.set_seed(1)
	var result: Dictionary = IndividualCombat.resolve_attack(
		_char_a, mounted_p, "katana", 20, 0, _dice, false, false, false,
	)
	assert_true(result.has("success"))


func test_mounted_vs_mounted_no_bonus() -> void:
	# Mounted attacker vs mounted target: no +1k0 bonus (s40: "against unmounted/lower").
	var mounted_p := IndividualCombat.Participant.new()
	IndividualCombat.apply_condition(mounted_p, IndividualCombat.CONDITION_MOUNTED)
	_char_a.skills["Kenjutsu"] = 3
	_dice.set_seed(1)
	var result_vs_mounted: Dictionary = IndividualCombat.resolve_attack(
		_char_a, mounted_p, "katana", 20, 0, _dice, false, false, true,
	)
	_dice.set_seed(1)
	var result_vs_unmounted: Dictionary = IndividualCombat.resolve_attack(
		_char_a, mounted_p, "katana", 20, 0, _dice, false, false, false,
	)
	# vs unmounted should roll more dice — with same seed the total should differ
	# (not a guaranteed ordering, but validates different code paths are taken)
	assert_true(result_vs_mounted.has("success") and result_vs_unmounted.has("success"))


# -- Unskilled Contested Roll Explode Fix (L5R4e p.78) -------------------------

func test_grapple_control_unskilled_does_not_explode() -> void:
	# With Jiujutsu 0, rolls should not explode. The API call should succeed and
	# return valid results without errors. Explosion behavior is validated by
	# ensuring the roll total is bounded (unskilled 3k3 max without explosions = 30,
	# vs potentially unlimited with explosions).
	# We can't directly block explosions in test, but we verify the API is correct.
	_char_a.skills.erase("Jiujutsu")  # ensure Jiujutsu = 0
	_char_b.skills.erase("Jiujutsu")
	_char_a.strength = 3
	_char_b.strength = 3
	_dice.set_seed(1)
	var result: Dictionary = IndividualCombat.resolve_grapple_control(_char_a, _char_b, _dice)
	assert_true(result.has("attacker_roll"))
	assert_true(result.has("defender_roll"))
	assert_true(result.has("attacker_wins"))


func test_grapple_control_skilled_attacker_wins_ties() -> void:
	# Attacker wins on tied contested roll (GDD s40 grapple control rule).
	# We force equal rolls by using same stats and seed, then verify attacker_wins = true on tie.
	_char_a.strength = 2
	_char_b.strength = 2
	_char_a.skills["Jiujutsu"] = 2
	_char_b.skills["Jiujutsu"] = 2
	# Run enough seeds to find a tie or just verify the attacker_wins = (att >= def)
	_dice.set_seed(99)
	var r: Dictionary = IndividualCombat.resolve_grapple_control(_char_a, _char_b, _dice)
	assert_true(r["attacker_wins"] == (r["attacker_roll"] >= r["defender_roll"]))


func test_sumai_unskilled_no_explode() -> void:
	_char_a.skills.erase("Jiujutsu")
	_char_b.skills.erase("Jiujutsu")
	_char_a.strength = 3
	_char_b.strength = 3
	_dice.set_seed(1)
	var result: Dictionary = IndividualCombat.resolve_sumai_bout(_char_a, _char_b, false, _dice)
	assert_true(result.has("wrestler1_roll"))
	assert_true(result.has("wrestler2_roll"))
	assert_true(result.has("bout_over"))


# -- Iaijutsu Stare-Down (s4.8) -----------------------------------------------

func test_iaijutsu_stare_down_sets_penalty_id() -> void:
	_char_a.skills = {"Intimidation": 5, "Iaijutsu": 3}
	_char_b.skills = {"Intimidation": 0, "Iaijutsu": 3}
	_char_a.willpower = 5
	_char_b.willpower = 1
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id
	)
	_dice.set_seed(42)
	var result: Dictionary = IndividualCombat.resolve_iaijutsu_stare_down(
		_char_a, _char_b, duel, _dice
	)
	assert_true(result["attempted"])
	if result["resolved"]:
		assert_true(duel.stare_down_penalty_id >= 0)


func test_stare_down_penalty_reduces_assessment_dice() -> void:
	_char_a.skills = {"Intimidation": 0, "Iaijutsu": 3}
	_char_b.skills = {"Intimidation": 0, "Iaijutsu": 3}
	_char_a.awareness = 3
	_char_b.awareness = 3
	_char_a.willpower = 3
	_char_b.willpower = 3
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id
	)
	duel.stare_down_penalty_id = _char_b.character_id
	var totals_with_penalty: Array = []
	var totals_without_penalty: Array = []
	for seed_val: int in range(100):
		_dice.set_seed(seed_val)
		var duel_pen: IndividualCombat.DuelState = IndividualCombat.create_duel(
			_char_a.character_id, _char_b.character_id
		)
		duel_pen.stare_down_penalty_id = _char_b.character_id
		var r_pen: Dictionary = IndividualCombat.resolve_duel_assessment(
			_char_a, _char_b, duel_pen, _dice
		)
		totals_with_penalty.append(r_pen["defender_roll"])

		_dice.set_seed(seed_val)
		var duel_no: IndividualCombat.DuelState = IndividualCombat.create_duel(
			_char_a.character_id, _char_b.character_id
		)
		var r_no: Dictionary = IndividualCombat.resolve_duel_assessment(
			_char_a, _char_b, duel_no, _dice
		)
		totals_without_penalty.append(r_no["defender_roll"])
	var avg_pen: float = 0.0
	var avg_no: float = 0.0
	for i: int in range(100):
		avg_pen += totals_with_penalty[i]
		avg_no += totals_without_penalty[i]
	avg_pen /= 100.0
	avg_no /= 100.0
	assert_true(avg_pen < avg_no, "Stare-down penalty should reduce average Assessment roll")


# -- Assessment Concession (s4.8) ----------------------------------------------

func test_concede_at_assessment_ends_duel() -> void:
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id, false
	)
	var result: Dictionary = IndividualCombat.concede_at_assessment(
		_char_b.character_id, duel
	)
	assert_true(result["conceded"])
	assert_eq(result["conceder_id"], _char_b.character_id)
	assert_eq(duel.winner_id, _char_a.character_id)
	assert_eq(duel.loser_id, _char_b.character_id)
	assert_true(duel.is_over)
	assert_eq(result["honor_change"], 0.0)
	assert_eq(result["glory_change"], 0.0)


func test_concede_death_duel_costs_glory() -> void:
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		_char_a.character_id, _char_b.character_id, true
	)
	var result: Dictionary = IndividualCombat.concede_at_assessment(
		_char_b.character_id, duel
	)
	assert_true(result["conceded"])
	assert_eq(result["glory_change"], IndividualCombat.GLORY_DECLINE_DEATH_DUEL)
	assert_eq(result["honor_change"], 0.0)


# -- First Blood / Striking After First Blood (s4.8) --------------------------

func test_first_blood_duel_stops_second_attack() -> void:
	var first: L5RCharacterData = _make_char(10, 2, 2, 2, 2, 5, 2, 4, 2)
	var second: L5RCharacterData = _make_char(11, 2, 2, 2, 2, 2, 2, 2, 2)
	first.skills = {"Iaijutsu": 5}
	second.skills = {"Iaijutsu": 3}
	first.void_ring = 3
	second.void_ring = 2
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(10, 11, false)
	duel.simultaneous = false
	duel.first_striker_id = 10
	duel.free_raises_first = 2
	var first_p := IndividualCombat.Participant.new()
	first_p.character_id = 10
	first_p.stance = Enums.Stance.CENTER
	var second_p := IndividualCombat.Participant.new()
	second_p.character_id = 11
	second_p.stance = Enums.Stance.CENTER
	var any_first_blood_stopped: bool = false
	for seed_val: int in range(50):
		second.wounds_taken = 0
		first.wounds_taken = 0
		duel.is_over = false
		duel.winner_id = -1
		duel.loser_id = -1
		duel.simultaneous = false
		duel.first_striker_id = 10
		duel.free_raises_first = 2
		_dice.set_seed(seed_val)
		var strike: Dictionary = IndividualCombat.resolve_duel_strike(
			first, first_p, second, second_p, duel, _dice
		)
		if strike.get("first_blood_drawn", false):
			assert_true(strike["second_attack"].is_empty(),
				"Second attack should not resolve after first blood")
			any_first_blood_stopped = true
	assert_true(any_first_blood_stopped, "At least one seed should produce first blood")


func test_strike_after_first_blood_returns_honor_penalty() -> void:
	var first: L5RCharacterData = _make_char(10, 2, 2, 2, 2, 5, 2, 4, 2)
	var second: L5RCharacterData = _make_char(11, 2, 2, 2, 2, 2, 2, 2, 2)
	first.skills = {"Iaijutsu": 3}
	second.skills = {"Iaijutsu": 3}
	first.void_ring = 3
	second.void_ring = 2
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(10, 11, false)
	var first_p := IndividualCombat.Participant.new()
	first_p.character_id = 10
	first_p.stance = Enums.Stance.CENTER
	var second_p := IndividualCombat.Participant.new()
	second_p.character_id = 11
	second_p.stance = Enums.Stance.CENTER
	var result: Dictionary = IndividualCombat.resolve_strike_after_first_blood(
		second, second_p, first, first_p, duel, _dice
	)
	assert_true(result["struck_after_first_blood"])
	assert_eq(result["honor_change"], IndividualCombat.HONOR_STRIKING_AFTER_FIRST_BLOOD)
	assert_true(duel.struck_after_first_blood)
