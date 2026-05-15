extends GutTest


var _char: L5RCharacterData
var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.void_ring = 3
	_char.max_void_points = 3
	_char.current_void_points = 3
	_char.enhanced_void = false
	_char.agility = 3
	_char.reflexes = 3
	_char.stamina = 2
	_char.willpower = 2
	_char.strength = 2
	_char.perception = 2
	_char.awareness = 3
	_char.intelligence = 3
	_char.wounds_taken = 0
	_char.skills = {}


# -- can_spend / spend ---------------------------------------------------------

func test_can_spend_when_pool_full() -> void:
	assert_true(VoidSystem.can_spend(_char))


func test_cannot_spend_when_pool_empty() -> void:
	_char.current_void_points = 0
	assert_false(VoidSystem.can_spend(_char))


func test_spend_decrements_pool() -> void:
	VoidSystem.spend(_char)
	assert_eq(_char.current_void_points, 2)


func test_spend_fails_at_zero_and_does_not_go_negative() -> void:
	_char.current_void_points = 0
	var ok: bool = VoidSystem.spend(_char)
	assert_false(ok)
	assert_eq(_char.current_void_points, 0)


# -- recover / restore_full ----------------------------------------------------

func test_recover_adds_points_capped_at_max() -> void:
	_char.current_void_points = 1
	VoidSystem.recover(_char, 5)
	assert_eq(_char.current_void_points, 3)  # capped at max=3


func test_recover_partial() -> void:
	_char.current_void_points = 1
	VoidSystem.recover(_char, 1)
	assert_eq(_char.current_void_points, 2)


func test_restore_full_fills_pool() -> void:
	_char.current_void_points = 0
	VoidSystem.restore_full(_char)
	assert_eq(_char.current_void_points, 3)


# -- roll_bonus ----------------------------------------------------------------

func test_roll_bonus_standard_is_1k1() -> void:
	var bonus: Dictionary = VoidSystem.roll_bonus(_char)
	assert_eq(bonus["rolled"], 1)
	assert_eq(bonus["kept"], 1)


func test_roll_bonus_enhanced_is_2k2() -> void:
	_char.enhanced_void = true
	var bonus: Dictionary = VoidSystem.roll_bonus(_char)
	assert_eq(bonus["rolled"], 2)
	assert_eq(bonus["kept"], 2)


# -- spend_for_roll ------------------------------------------------------------

func test_spend_for_roll_succeeds_and_returns_bonus() -> void:
	var result: Dictionary = VoidSystem.spend_for_roll(_char)
	assert_true(result["success"])
	assert_eq(result["rolled_bonus"], 1)
	assert_eq(result["kept_bonus"], 1)
	assert_eq(_char.current_void_points, 2)


func test_spend_for_roll_fails_when_empty() -> void:
	_char.current_void_points = 0
	var result: Dictionary = VoidSystem.spend_for_roll(_char)
	assert_false(result["success"])
	assert_eq(result["rolled_bonus"], 0)
	assert_eq(result["kept_bonus"], 0)


func test_spend_for_roll_enhanced_gives_2k2() -> void:
	_char.enhanced_void = true
	var result: Dictionary = VoidSystem.spend_for_roll(_char)
	assert_eq(result["rolled_bonus"], 2)
	assert_eq(result["kept_bonus"], 2)


# -- spend_for_wound_reduction -------------------------------------------------

func test_wound_reduction_reduces_by_10() -> void:
	var result: Dictionary = VoidSystem.spend_for_wound_reduction(_char, 25)
	assert_true(result["success"])
	assert_eq(result["reduced_damage"], 15)
	assert_eq(_char.current_void_points, 2)


func test_wound_reduction_cannot_go_below_zero() -> void:
	var result: Dictionary = VoidSystem.spend_for_wound_reduction(_char, 5)
	assert_eq(result["reduced_damage"], 0)


func test_wound_reduction_fails_when_no_void() -> void:
	_char.current_void_points = 0
	var result: Dictionary = VoidSystem.spend_for_wound_reduction(_char, 20)
	assert_false(result["success"])
	assert_eq(result["reduced_damage"], 20)  # unchanged


# -- spend_for_armor_tn --------------------------------------------------------

func test_armor_tn_boost_returns_10() -> void:
	var result: Dictionary = VoidSystem.spend_for_armor_tn(_char)
	assert_true(result["success"])
	assert_eq(result["armor_tn_bonus"], 10)
	assert_eq(_char.current_void_points, 2)


func test_armor_tn_boost_fails_when_no_void() -> void:
	_char.current_void_points = 0
	var result: Dictionary = VoidSystem.spend_for_armor_tn(_char)
	assert_false(result["success"])
	assert_eq(result["armor_tn_bonus"], 0)


# -- spend_for_initiative_bonus ------------------------------------------------

func test_initiative_bonus_returns_10() -> void:
	var result: Dictionary = VoidSystem.spend_for_initiative_bonus(_char)
	assert_true(result["success"])
	assert_eq(result["initiative_bonus"], 10)
	assert_eq(_char.current_void_points, 2)


func test_initiative_bonus_fails_when_no_void() -> void:
	_char.current_void_points = 0
	var result: Dictionary = VoidSystem.spend_for_initiative_bonus(_char)
	assert_false(result["success"])
	assert_eq(result["initiative_bonus"], 0)


# -- IndividualCombat wiring: resolve_attack() with spend_void -----------------

func test_attack_void_spend_increases_roll() -> void:
	_char.skills = {"Kenjutsu": 3}
	var p_no  := IndividualCombat.Participant.new()
	var p_yes := IndividualCombat.Participant.new()
	var total_no: int  = 0
	var total_yes: int = 0
	for i: int in range(20):
		var r_no:  Dictionary = IndividualCombat.resolve_attack(_char, p_no,  "katana", 5, 0, DiceEngine.new(i), false, false)
		_char.current_void_points = 3
		p_yes.void_spent_this_round = false
		var r_yes: Dictionary = IndividualCombat.resolve_attack(_char, p_yes, "katana", 5, 0, DiceEngine.new(i), false, true)
		_char.current_void_points = 3
		total_no  += r_no["roll"]
		total_yes += r_yes["roll"]
	assert_true(total_yes > total_no, "Void spend should increase attack roll totals")


func test_attack_void_spend_marks_participant() -> void:
	_char.skills = {"Kenjutsu": 3}
	var p := IndividualCombat.Participant.new()
	IndividualCombat.resolve_attack(_char, p, "katana", 5, 0, _dice, false, true)
	assert_true(p.void_spent_this_round)


func test_attack_void_not_spent_twice_per_round() -> void:
	_char.skills = {"Kenjutsu": 3}
	var p := IndividualCombat.Participant.new()
	p.void_spent_this_round = true  # already spent this round
	_char.current_void_points = 3
	IndividualCombat.resolve_attack(_char, p, "katana", 5, 0, _dice, false, true)
	assert_eq(_char.current_void_points, 3)  # pool unchanged — not spent again


func test_attack_void_not_spent_when_pool_empty() -> void:
	_char.skills = {"Kenjutsu": 3}
	_char.current_void_points = 0
	var p := IndividualCombat.Participant.new()
	var result: Dictionary = IndividualCombat.resolve_attack(_char, p, "katana", 5, 0, _dice, false, true)
	assert_false(result["void_used"])
	assert_eq(_char.current_void_points, 0)


# -- IndividualCombat wiring: Armor TN Void bonus ------------------------------

func test_void_armor_tn_bonus_applied_in_get_armor_tn() -> void:
	var p := IndividualCombat.Participant.new()
	p.stance = Enums.Stance.ATTACK
	var base_tn: int = IndividualCombat.get_armor_tn(_char, p, _dice)

	var result: Dictionary = VoidSystem.spend_for_armor_tn(_char)
	p.void_armor_tn_bonus = result["armor_tn_bonus"]
	var boosted_tn: int = IndividualCombat.get_armor_tn(_char, p, _dice)
	assert_eq(boosted_tn, base_tn + 10)


func test_begin_round_clears_void_armor_tn_bonus() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 10},
	])
	state.participants[1].void_armor_tn_bonus = 10
	IndividualCombat.begin_round(state)
	assert_eq(state.participants[1].void_armor_tn_bonus, 0)


func test_begin_round_clears_void_spent_this_round() -> void:
	var state: IndividualCombat.CombatState = IndividualCombat.build_combat_state([
		{"character_id": 1, "initiative_score": 10},
	])
	state.participants[1].void_spent_this_round = true
	IndividualCombat.begin_round(state)
	assert_false(state.participants[1].void_spent_this_round)
