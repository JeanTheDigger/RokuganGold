extends GutTest


var _char: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_char = L5RCharacterData.new()
	_engine = DiceEngine.new(42)


# -- Trait lookup --------------------------------------------------------------

func test_kenjutsu_uses_agility() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Kenjutsu"), Enums.Trait.AGILITY)


func test_courtier_uses_awareness() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Courtier"), Enums.Trait.AWARENESS)


func test_investigation_uses_perception() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Investigation"), Enums.Trait.PERCEPTION)


func test_defense_uses_reflexes() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Defense"), Enums.Trait.REFLEXES)


func test_athletics_uses_strength() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Athletics"), Enums.Trait.STRENGTH)


func test_intimidation_uses_willpower() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Intimidation"), Enums.Trait.WILLPOWER)


func test_meditation_uses_void() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Meditation"), Enums.Trait.VOID)


# -- Sub-skill trait overrides -------------------------------------------------

func test_perform_dance_uses_agility() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Perform: Dance"), Enums.Trait.AGILITY)


func test_perform_oratory_uses_awareness() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Perform: Oratory"), Enums.Trait.AWARENESS)


func test_games_go_uses_intelligence() -> void:
	assert_eq(SkillResolver.get_trait_for_skill("Games: Go"), Enums.Trait.INTELLIGENCE)


func test_unknown_sub_skill_uses_parent() -> void:
	# "Lore: Heraldry" should fall back to Lore -> Intelligence
	assert_eq(SkillResolver.get_trait_for_skill("Lore: Heraldry"), Enums.Trait.INTELLIGENCE)


# -- Skill rank lookup ---------------------------------------------------------

func test_get_rank_present() -> void:
	_char.skills = {"Kenjutsu": 3}
	assert_eq(SkillResolver.get_skill_rank(_char, "Kenjutsu"), 3)


func test_get_rank_absent() -> void:
	assert_eq(SkillResolver.get_skill_rank(_char, "Kenjutsu"), 0)


func test_get_rank_sub_skill_falls_back_to_parent() -> void:
	_char.skills = {"Lore": 4}
	assert_eq(SkillResolver.get_skill_rank(_char, "Lore: History"), 4)


# -- Emphasis check ------------------------------------------------------------

func test_has_emphasis_present() -> void:
	_char.emphases = {"Kenjutsu": ["Katana"]}
	assert_true(SkillResolver.has_emphasis(_char, "Kenjutsu", "Katana"))


func test_has_emphasis_absent() -> void:
	_char.emphases = {"Kenjutsu": ["Katana"]}
	assert_false(SkillResolver.has_emphasis(_char, "Kenjutsu", "No-dachi"))


func test_has_emphasis_missing_skill() -> void:
	assert_false(SkillResolver.has_emphasis(_char, "Kenjutsu", "Katana"))


# -- Full skill check resolution -----------------------------------------------

func test_resolve_uses_correct_trait_and_skill() -> void:
	_char.agility = 4
	_char.skills = {"Kenjutsu": 3}
	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15
	)
	assert_eq(result["trait_used"], Enums.Trait.AGILITY)
	assert_eq(result["skill_rank"], 3)
	# 4+3=7 rolled, keep 4
	assert_eq(result["dice"].kept_dice.size(), 4)


func test_resolve_unskilled_no_explode() -> void:
	_char.agility = 3
	# No Kenjutsu skill -> unskilled, 3k3 no exploding
	for i: int in range(100):
		_engine.set_seed(i)
		var result: Dictionary = SkillResolver.resolve_skill_check(
			_char, _engine, "Kenjutsu", 15
		)
		for die_value: int in result["dice"].kept_dice:
			assert_true(die_value <= 10, "Unskilled should not explode")


func test_resolve_applies_wound_penalty() -> void:
	_char.agility = 3
	_char.skills = {"Kenjutsu": 3}
	_char.wounds_taken = 5  # Nicked with Earth 2 -> -3 penalty

	_engine.set_seed(42)
	var wounded: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15
	)

	_char.wounds_taken = 0
	_engine.set_seed(42)
	var healthy: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15
	)

	assert_eq(wounded["wound_penalty"], -3)
	assert_eq(wounded["total"], healthy["total"] - 3)


func test_resolve_with_emphasis() -> void:
	_char.agility = 3
	_char.skills = {"Kenjutsu": 3}
	_char.emphases = {"Kenjutsu": ["Katana"]}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15, 0, "Katana"
	)
	assert_true(result["emphasis_applied"])


func test_resolve_without_matching_emphasis() -> void:
	_char.agility = 3
	_char.skills = {"Kenjutsu": 3}
	_char.emphases = {"Kenjutsu": ["Katana"]}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15, 0, "No-dachi"
	)
	assert_false(result["emphasis_applied"])


func test_resolve_trait_override() -> void:
	_char.strength = 5
	_char.agility = 2
	_char.skills = {"Kenjutsu": 3}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15, 0, "", Enums.Trait.STRENGTH
	)
	# Should use Strength 5 instead of Agility 2
	assert_eq(result["trait_used"], Enums.Trait.STRENGTH)
	assert_eq(result["dice"].kept_dice.size(), 5)


func test_resolve_raises_increase_tn() -> void:
	_char.agility = 3
	_char.skills = {"Kenjutsu": 3}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Kenjutsu", 15, 2
	)
	assert_eq(result["tn"], 25)


# -- Contested check -----------------------------------------------------------

func test_contested_check_returns_winner() -> void:
	var char_a: L5RCharacterData = L5RCharacterData.new()
	var char_b: L5RCharacterData = L5RCharacterData.new()
	char_a.awareness = 4
	char_a.skills = {"Courtier": 5}
	char_b.awareness = 3
	char_b.skills = {"Etiquette": 3}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_contested_check(
		char_a, char_b, _engine, "Courtier", "Etiquette"
	)
	assert_true(result["winner"] in ["a", "b", "tie"])
	assert_true(result.has("total_a"))
	assert_true(result.has("total_b"))


func test_contested_check_applies_wound_penalties() -> void:
	var char_a: L5RCharacterData = L5RCharacterData.new()
	var char_b: L5RCharacterData = L5RCharacterData.new()
	char_a.awareness = 3
	char_a.skills = {"Courtier": 3}
	char_a.wounds_taken = 5  # Nicked -> -3
	char_b.awareness = 3
	char_b.skills = {"Etiquette": 3}

	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.resolve_contested_check(
		char_a, char_b, _engine, "Courtier", "Etiquette"
	)
	assert_eq(result["wound_penalty_a"], -3)
	assert_eq(result["wound_penalty_b"], 0)
