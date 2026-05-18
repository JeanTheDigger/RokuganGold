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


# -- Doji R1a: Honor-gated Free Raise (s29.15.4) ------------------------------

func test_doji_courtier_free_raise_on_courtier_skill() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Courtier"), 1)


func test_doji_courtier_free_raise_on_sincerity() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Sincerity"), 1)


func test_doji_courtier_free_raise_on_etiquette() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Etiquette"), 1)


func test_doji_courtier_no_free_raise_below_honor_threshold() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 5.9
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Courtier"), 0)


func test_doji_courtier_no_free_raise_on_other_skill() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Investigation"), 0)


func test_non_doji_no_free_raise() -> void:
	_char.school = "Bayushi Courtier"
	_char.honor = 8.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Courtier"), 0)


func test_doji_free_raise_on_sub_skill() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.0
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Etiquette: Courtesy"), 1)


# -- Yasuki R1a: Commerce Free Raise (s29.15.2) -------------------------------

func test_yasuki_free_raise_on_commerce() -> void:
	_char.school = "Yasuki Courtier"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Commerce"), 1)


func test_yasuki_no_free_raise_on_courtier() -> void:
	_char.school = "Yasuki Courtier"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Courtier"), 0)


# -- Kitsuki R1a: Investigation Free Raise (s29.15.6) -------------------------

func test_kitsuki_free_raise_on_investigation() -> void:
	_char.school = "Kitsuki Investigator"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Investigation"), 1)


func test_kitsuki_free_raise_on_investigation_sub_skill() -> void:
	_char.school = "Kitsuki Investigator"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Investigation: Notice"), 1)


func test_kitsuki_no_free_raise_on_courtier() -> void:
	_char.school = "Kitsuki Investigator"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Courtier"), 0)


# -- Asako R1a: Lore Free Raise (s29.15.10) -----------------------------------

func test_asako_free_raise_on_lore() -> void:
	_char.school = "Asako Loremaster"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Lore"), 1)


func test_asako_free_raise_on_lore_sub_skill() -> void:
	_char.school = "Asako Loremaster"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Lore: History"), 1)
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Lore: Theology"), 1)
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Lore: Shadowlands"), 1)


func test_asako_no_free_raise_on_etiquette() -> void:
	_char.school = "Asako Loremaster"
	assert_eq(SkillResolver.get_technique_free_raises(_char, "Etiquette"), 0)


func test_doji_free_raise_adds_flat_bonus_to_skill_check() -> void:
	_char.school = "Doji Courtier"
	_char.honor = 6.5
	_char.awareness = 3
	_char.skills = {"Courtier": 3}
	_engine.set_seed(100)
	var with_fr: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Courtier", 15
	)
	assert_eq(with_fr["technique_free_raises"], 1)
	_char.honor = 5.0
	_engine.set_seed(100)
	var without_fr: Dictionary = SkillResolver.resolve_skill_check(
		_char, _engine, "Courtier", 15
	)
	assert_eq(without_fr["technique_free_raises"], 0)
	assert_eq(with_fr["total"] - without_fr["total"], 5)


# -- Deception Defense Bonus (s29.15.6 Kitsuki R2, s29.15.2 Yasuki R4) --------

func test_kitsuki_r2_deception_defense_bonus() -> void:
	_char.school = "Kitsuki Investigator"
	_char.stamina = 3
	_char.willpower = 3
	_char.strength = 3
	_char.perception = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.reflexes = 3
	_char.awareness = 3
	_char.void_ring = 3
	_char.skills = {"Investigation": 3, "Etiquette": 2, "Courtier": 2}
	var rank: int = CharacterStats.get_insight_rank(_char)
	assert_true(rank >= 2, "Test character should be Rank 2+")
	var bonus: int = SkillResolver.get_deception_defense_bonus(_char)
	assert_eq(bonus, 5 * rank)


func test_kitsuki_r1_no_deception_defense() -> void:
	var low_char := L5RCharacterData.new()
	low_char.school = "Kitsuki Investigator"
	var rank: int = CharacterStats.get_insight_rank(low_char)
	assert_eq(rank, 1, "Default traits give Rank 1")
	assert_eq(SkillResolver.get_deception_defense_bonus(low_char), 0)


func test_yasuki_r4_deception_defense_bonus() -> void:
	_char.school = "Yasuki Courtier"
	_char.stamina = 4
	_char.willpower = 4
	_char.strength = 4
	_char.perception = 4
	_char.agility = 4
	_char.intelligence = 4
	_char.reflexes = 4
	_char.awareness = 4
	_char.void_ring = 4
	_char.skills = {"Commerce": 5, "Courtier": 4, "Etiquette": 4, "Sincerity": 3, "Investigation": 2}
	var rank: int = CharacterStats.get_insight_rank(_char)
	assert_true(rank >= 4, "Test character should be Rank 4+")
	var bonus: int = SkillResolver.get_deception_defense_bonus(_char)
	assert_eq(bonus, 5 * rank)


func test_yasuki_below_r4_no_deception_defense() -> void:
	_char.school = "Yasuki Courtier"
	_char.stamina = 3
	_char.willpower = 3
	_char.strength = 3
	_char.perception = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.reflexes = 3
	_char.awareness = 3
	_char.void_ring = 3
	_char.skills = {"Commerce": 3, "Courtier": 2}
	var rank: int = CharacterStats.get_insight_rank(_char)
	assert_true(rank < 4, "Test character should be below Rank 4")
	assert_eq(SkillResolver.get_deception_defense_bonus(_char), 0)


func test_non_qualifying_school_no_deception_defense() -> void:
	_char.school = "Bayushi Courtier"
	_char.awareness = 5
	_char.intelligence = 5
	_char.skills = {"Courtier": 5, "Sincerity": 5, "Etiquette": 5}
	assert_eq(SkillResolver.get_deception_defense_bonus(_char), 0)


func test_deceptive_action_ids_list() -> void:
	assert_true("GOSSIP" in SkillResolver.DECEPTIVE_ACTION_IDS)
	assert_true("FABRICATE_SECRET" in SkillResolver.DECEPTIVE_ACTION_IDS)
	assert_false("CHARM" in SkillResolver.DECEPTIVE_ACTION_IDS)
	assert_false("INTIMIDATE" in SkillResolver.DECEPTIVE_ACTION_IDS)


# -- Asako R2: From the Ashes (s29.15.10) --------------------------------------

func _make_asako_loremaster() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.school = "Asako Loremaster"
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.agility = 3
	c.intelligence = 3
	c.reflexes = 3
	c.awareness = 3
	c.void_ring = 3
	c.skills = {"Lore: History": 4, "Courtier": 3, "Etiquette": 3}
	return c


func test_ashes_bonus_on_social_skill() -> void:
	_char.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 10}
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Courtier"), 2)
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Sincerity"), 2)
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Etiquette"), 2)
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Etiquette: Courtesy"), 2)


func test_ashes_no_bonus_on_non_social_skill() -> void:
	_char.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 10}
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Investigation"), 0)
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Lore: History"), 0)
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Commerce"), 0)


func test_ashes_no_bonus_when_inactive() -> void:
	assert_true(_char.from_the_ashes.is_empty())
	assert_eq(SkillResolver._get_ashes_bonus_for_skill(_char, "Courtier"), 0)


func test_activate_from_the_ashes_success() -> void:
	var loremaster: L5RCharacterData = _make_asako_loremaster()
	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.activate_from_the_ashes(
		loremaster, _engine, "court_1", 5
	)
	assert_true(result["success"])
	assert_eq(loremaster.from_the_ashes.get("location_id", ""), "court_1")
	assert_eq(loremaster.from_the_ashes.get("expires_ic_day", -1), 7)


func test_activate_from_the_ashes_wrong_school() -> void:
	_char.school = "Doji Courtier"
	var result: Dictionary = SkillResolver.activate_from_the_ashes(
		_char, _engine, "court_1", 5
	)
	assert_false(result["success"])
	assert_eq(result["reason"], "wrong_school")


func test_activate_from_the_ashes_rank_too_low() -> void:
	var c := L5RCharacterData.new()
	c.school = "Asako Loremaster"
	var result: Dictionary = SkillResolver.activate_from_the_ashes(
		c, _engine, "court_1", 5
	)
	assert_false(result["success"])
	assert_eq(result["reason"], "rank_too_low")


func test_check_expiry_clears_on_wrong_location() -> void:
	_char.school = "Asako Loremaster"
	_char.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 10}
	var result: Dictionary = SkillResolver.check_from_the_ashes_expiry(
		_char, _engine, "court_2", 5
	)
	assert_eq(result["action"], "cleared_wrong_location")
	assert_true(_char.from_the_ashes.is_empty())


func test_check_expiry_still_active() -> void:
	_char.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 10}
	var result: Dictionary = SkillResolver.check_from_the_ashes_expiry(
		_char, _engine, "court_1", 8
	)
	assert_eq(result["action"], "still_active")


func test_check_expiry_refreshes_on_expire() -> void:
	var loremaster: L5RCharacterData = _make_asako_loremaster()
	loremaster.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 5}
	_engine.set_seed(42)
	var result: Dictionary = SkillResolver.check_from_the_ashes_expiry(
		loremaster, _engine, "court_1", 5
	)
	assert_true(result.get("success", false), "Should auto-refresh on expiry")
	assert_eq(loremaster.from_the_ashes.get("expires_ic_day", -1), 7)


func test_ashes_bonus_adds_rolled_dice_to_skill_check() -> void:
	var loremaster: L5RCharacterData = _make_asako_loremaster()
	loremaster.from_the_ashes = {"location_id": "court_1", "expires_ic_day": 99}
	_engine.set_seed(100)
	var with_buff: Dictionary = SkillResolver.resolve_skill_check(
		loremaster, _engine, "Courtier", 15
	)
	loremaster.from_the_ashes = {}
	_engine.set_seed(100)
	var without_buff: Dictionary = SkillResolver.resolve_skill_check(
		loremaster, _engine, "Courtier", 15
	)
	assert_true(with_buff["total"] >= without_buff["total"],
		"+2k0 should increase or maintain roll total")
