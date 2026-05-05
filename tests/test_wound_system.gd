extends GutTest


var _char: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_char = L5RCharacterData.new()
	_engine = DiceEngine.new(42)


# -- apply_damage --------------------------------------------------------------

func test_damage_reduces_by_armor() -> void:
	var result: Dictionary = WoundSystem.apply_damage(_char, 10, 3)
	assert_eq(result["final_damage"], 7)
	assert_eq(_char.wounds_taken, 7)


func test_damage_uses_character_reduction_by_default() -> void:
	_char.armor_reduction = 5
	var result: Dictionary = WoundSystem.apply_damage(_char, 8)
	assert_eq(result["final_damage"], 3)


func test_damage_cannot_go_negative() -> void:
	var result: Dictionary = WoundSystem.apply_damage(_char, 2, 10)
	assert_eq(result["final_damage"], 0)
	assert_eq(_char.wounds_taken, 0)


func test_damage_tracks_wound_level_change() -> void:
	# Earth 2, threshold 4
	var result: Dictionary = WoundSystem.apply_damage(_char, 12, 0)
	assert_eq(result["old_wound_level"], Enums.WoundLevel.HEALTHY)
	assert_eq(result["new_wound_level"], Enums.WoundLevel.HURT)
	assert_eq(result["levels_crossed"], 3)


func test_lethal_damage_kills() -> void:
	var result: Dictionary = WoundSystem.apply_damage(_char, 100, 0)
	assert_true(result["is_dead"])
	assert_true(CharacterStats.is_dead(_char))


func test_cumulative_damage() -> void:
	WoundSystem.apply_damage(_char, 3, 0)
	assert_eq(_char.wounds_taken, 3)
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)

	WoundSystem.apply_damage(_char, 2, 0)
	assert_eq(_char.wounds_taken, 5)
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.NICKED)


# -- heal_wounds ---------------------------------------------------------------

func test_heal_reduces_wounds() -> void:
	_char.wounds_taken = 10
	var result: Dictionary = WoundSystem.heal_wounds(_char, 5)
	assert_eq(result["healed"], 5)
	assert_eq(_char.wounds_taken, 5)


func test_heal_cannot_go_below_zero() -> void:
	_char.wounds_taken = 3
	var result: Dictionary = WoundSystem.heal_wounds(_char, 10)
	assert_eq(result["healed"], 3)
	assert_eq(_char.wounds_taken, 0)


func test_heal_dead_character_does_nothing() -> void:
	_char.wounds_taken = 999
	assert_true(CharacterStats.is_dead(_char))
	var result: Dictionary = WoundSystem.heal_wounds(_char, 50)
	assert_eq(result["healed"], 0)
	assert_eq(result["wound_level"], Enums.WoundLevel.DEAD)


# -- apply_falling_damage ------------------------------------------------------

func test_fall_one_tile_no_damage() -> void:
	var result: Dictionary = WoundSystem.apply_falling_damage(_char, 1, _engine)
	assert_eq(result["final_damage"], 0)


func test_fall_four_tiles_rolls_2k2() -> void:
	var result: Dictionary = WoundSystem.apply_falling_damage(_char, 4, _engine)
	assert_true(result["final_damage"] >= 0)
	assert_true(_char.wounds_taken >= 0)


func test_fall_ten_tiles_can_kill() -> void:
	_engine.set_seed(999)
	# 10 tiles / 2 = 5k5, can easily exceed 32 wound capacity (Earth 2)
	var killed: bool = false
	for i: int in range(50):
		var test_char: L5RCharacterData = L5RCharacterData.new()
		_engine.set_seed(i)
		WoundSystem.apply_falling_damage(test_char, 10, _engine)
		if CharacterStats.is_dead(test_char):
			killed = true
			break
	assert_true(killed, "A 10-tile fall should be capable of killing an Earth 2 character")
