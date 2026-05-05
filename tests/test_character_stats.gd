extends GutTest


var _char: L5RCharacterData


func before_each() -> void:
	_char = L5RCharacterData.new()
	# Default: all traits at 2


# -- Ring calculation ----------------------------------------------------------

func test_ring_is_min_of_two_traits() -> void:
	_char.reflexes = 3
	_char.awareness = 2
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.AIR), 2)


func test_ring_with_equal_traits() -> void:
	_char.stamina = 4
	_char.willpower = 4
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.EARTH), 4)


func test_void_ring_is_single_trait() -> void:
	_char.void_ring = 3
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.VOID), 3)


func test_all_four_rings() -> void:
	_char.reflexes = 3
	_char.awareness = 4
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.AIR), 3)

	_char.stamina = 2
	_char.willpower = 5
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.EARTH), 2)

	_char.agility = 4
	_char.intelligence = 3
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.FIRE), 3)

	_char.strength = 2
	_char.perception = 2
	assert_eq(CharacterStats.get_ring_value(_char, Enums.Ring.WATER), 2)


# -- Insight -------------------------------------------------------------------

func test_insight_base_all_twos_no_skills() -> void:
	# All 5 rings at 2 = 10 * 10 = 100, 0 skill ranks
	var insight: int = CharacterStats.get_insight(_char)
	assert_eq(insight, 100)


func test_insight_with_skills() -> void:
	_char.skills = {"Kenjutsu": 3, "Etiquette": 2, "Courtier": 1}
	# Rings: 5 * 2 = 10, *10 = 100. Skills: 3+2+1=6. Total: 106
	assert_eq(CharacterStats.get_insight(_char), 106)


func test_insight_rank_thresholds() -> void:
	# 100 insight -> rank 1 (below 150)
	assert_eq(CharacterStats.get_insight_rank(_char), 1)

	# Raise all traits to 3 -> rings all 3 -> 15*10=150 -> Rank 2
	_char.stamina = 3
	_char.willpower = 3
	_char.strength = 3
	_char.perception = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.reflexes = 3
	_char.awareness = 3
	_char.void_ring = 3
	assert_eq(CharacterStats.get_insight(_char), 150)
	assert_eq(CharacterStats.get_insight_rank(_char), 2)


func test_insight_rank_boundaries() -> void:
	# L5R4e Core p.108: Rank 2 at 150, +25 per rank after that
	_char.skills = {}

	# 149 -> Rank 1. Need rings summing to 14 + 9 skills = 149
	# All traits 3 except void 2: rings = 3+3+3+3+2 = 14 -> 140. Need 9 skill ranks.
	_char.stamina = 3
	_char.willpower = 3
	_char.strength = 3
	_char.perception = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.reflexes = 3
	_char.awareness = 3
	_char.void_ring = 2
	_char.skills = {"Kenjutsu": 5, "Etiquette": 4}
	assert_eq(CharacterStats.get_insight(_char), 149)
	assert_eq(CharacterStats.get_insight_rank(_char), 1)

	# Add 1 skill rank -> 150 -> Rank 2
	_char.skills = {"Kenjutsu": 5, "Etiquette": 5}
	assert_eq(CharacterStats.get_insight(_char), 150)
	assert_eq(CharacterStats.get_insight_rank(_char), 2)

	# 175 -> Rank 3
	_char.void_ring = 3
	_char.skills = {"Kenjutsu": 5, "Etiquette": 5, "Courtier": 5, "Lore: Heraldry": 5, "Sincerity": 5}
	assert_eq(CharacterStats.get_insight(_char), 175)
	assert_eq(CharacterStats.get_insight_rank(_char), 3)


# -- Armor TN ------------------------------------------------------------------

func test_armor_tn_base() -> void:
	# Reflexes 2: (2*5) + 5 = 15
	assert_eq(CharacterStats.get_armor_tn(_char), 15)


func test_armor_tn_with_armor_bonus() -> void:
	_char.reflexes = 3
	_char.armor_tn_bonus = 5
	# (3*5) + 5 + 5 = 25
	assert_eq(CharacterStats.get_armor_tn(_char), 25)


# -- Initiative ----------------------------------------------------------------

func test_initiative_rolled() -> void:
	_char.reflexes = 3
	# Insight rank 1 (all 2s except reflexes 3). rolled = 3 + 1 = 4
	assert_eq(CharacterStats.get_initiative_rolled(_char), 4)


func test_initiative_kept_equals_reflexes() -> void:
	_char.reflexes = 4
	assert_eq(CharacterStats.get_initiative_kept(_char), 4)


# -- Wound levels --------------------------------------------------------------

func test_healthy_at_zero_wounds() -> void:
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)


func test_nicked_after_threshold() -> void:
	# Earth 2, threshold = 4. At 4 wounds -> still Healthy (boxes 1-4 filled).
	# Wound 5 is the first in Nicked.
	_char.wounds_taken = 4
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)

	_char.wounds_taken = 5
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.NICKED)


func test_wound_level_progression() -> void:
	# Earth 2, threshold = 4 per level.
	# Each level holds wounds: Healthy 1-4, Nicked 5-8, Grazed 9-12, etc.
	_char.wounds_taken = 1
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)

	_char.wounds_taken = 4
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)

	_char.wounds_taken = 5
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.NICKED)

	_char.wounds_taken = 8
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.NICKED)

	_char.wounds_taken = 9
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.GRAZED)

	_char.wounds_taken = 13
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HURT)

	_char.wounds_taken = 17
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.INJURED)

	_char.wounds_taken = 21
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.CRIPPLED)

	_char.wounds_taken = 25
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.DOWN)

	_char.wounds_taken = 29
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.OUT)

	_char.wounds_taken = 33
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.DEAD)


func test_wound_penalties() -> void:
	assert_eq(CharacterStats.get_wound_penalty(_char), 0)

	# 5 wounds -> Nicked -> -3
	_char.wounds_taken = 5
	assert_eq(CharacterStats.get_wound_penalty(_char), -3)

	# 13 wounds -> Hurt -> -10
	_char.wounds_taken = 13
	assert_eq(CharacterStats.get_wound_penalty(_char), -10)


func test_dead_is_permanent() -> void:
	_char.wounds_taken = 999
	assert_true(CharacterStats.is_dead(_char))


func test_total_wound_capacity() -> void:
	# Earth 2, threshold 4, 8 levels = 32
	assert_eq(CharacterStats.get_total_wound_capacity(_char), 32)

	_char.stamina = 4
	_char.willpower = 3
	# Earth = min(4,3) = 3, threshold = 6, capacity = 48
	assert_eq(CharacterStats.get_total_wound_capacity(_char), 48)


func test_higher_earth_more_resilient() -> void:
	_char.stamina = 5
	_char.willpower = 5
	# Earth 5, threshold = 10. At 10 wounds -> still Healthy (boxes 1-10 filled).
	# Wound 11 enters Nicked.
	_char.wounds_taken = 10
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.HEALTHY)

	_char.wounds_taken = 11
	assert_eq(CharacterStats.get_wound_level(_char), Enums.WoundLevel.NICKED)
