extends GutTest
## Tests for AdvantageSystem (GDD s45).


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_character(id: int = 1) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Test Samurai"
	c.clan = "Crane"
	c.family = "Doji"
	c.school = "Doji Courtier"
	c.school_type = Enums.SchoolType.COURTIER
	c.school_rank = 2
	c.insight_rank = 2
	c.status = 3.0
	c.honor = 4.0
	c.glory = 2.0
	c.stamina = 2
	c.willpower = 2
	c.strength = 2
	c.perception = 3
	c.agility = 2
	c.intelligence = 3
	c.reflexes = 2
	c.awareness = 3
	c.void_ring = 2
	c.taint = 0.0
	c.wounds_taken = 0
	c.skills = {"Etiquette": 3, "Courtier": 3}
	c.advantages = []
	c.disadvantages = []
	return c


func _add_advantage(c: L5RCharacterData, type: Enums.Advantage, rank: int = 1, meta: Dictionary = {}) -> AdvantageData:
	var adv: AdvantageData = AdvantageData.new()
	adv.advantage_type = type
	adv.rank = rank
	adv.metadata = meta.duplicate()
	c.advantages.append(adv)
	return adv


func _add_disadvantage(c: L5RCharacterData, type: Enums.Disadvantage, rank: int = 1, meta: Dictionary = {}) -> DisadvantageData:
	var dis: DisadvantageData = DisadvantageData.new()
	dis.disadvantage_type = type
	dis.rank = rank
	dis.metadata = meta.duplicate()
	c.disadvantages.append(dis)
	return dis


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

func test_has_advantage_true():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FAME)
	assert_true(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_has_advantage_false_when_absent():
	var c := _make_character()
	assert_false(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_get_advantage_returns_data():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.MAGIC_RESISTANCE, 2)
	var adv: AdvantageData = AdvantageSystem.get_advantage(c, Enums.Advantage.MAGIC_RESISTANCE)
	assert_not_null(adv)
	assert_eq(adv.rank, 2)


func test_get_advantage_returns_null_when_absent():
	var c := _make_character()
	assert_null(AdvantageSystem.get_advantage(c, Enums.Advantage.FAME))


func test_has_disadvantage_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA)
	assert_true(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.PHOBIA))


func test_has_disadvantage_false_when_absent():
	var c := _make_character()
	assert_false(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.PHOBIA))


func test_get_disadvantage_returns_data():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.COMPULSION, 2, {"subject": "sake"})
	var dis: DisadvantageData = AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.COMPULSION)
	assert_not_null(dis)
	assert_eq(dis.rank, 2)
	assert_eq(dis.metadata.get("subject", ""), "sake")


func test_get_disadvantage_returns_null_when_absent():
	var c := _make_character()
	assert_null(AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.COMPULSION))


func test_has_advantage_picks_correct_type():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FAME)
	_add_advantage(c, Enums.Advantage.QUICK_HEALER)
	assert_true(AdvantageSystem.has_advantage(c, Enums.Advantage.QUICK_HEALER))
	assert_false(AdvantageSystem.has_advantage(c, Enums.Advantage.BLAND))


# ---------------------------------------------------------------------------
# get_skill_bonus
# ---------------------------------------------------------------------------

func test_skill_bonus_no_advantages_returns_zero():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {})
	assert_eq(result["rolled"], 0)
	assert_eq(result["kept"], 0)
	assert_eq(result["free_raises"], 0)


func test_innate_ability_fire_grants_rolled_bonus():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INNATE_ABILITY, 1, {"ring": Enums.Ring.FIRE})
	var ctx: Dictionary = {"element": Enums.Ring.FIRE}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", ctx)
	assert_gt(result["rolled"], 0)


func test_innate_ability_wrong_element_no_bonus():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INNATE_ABILITY, 1, {"ring": Enums.Ring.FIRE})
	var ctx: Dictionary = {"element": Enums.Ring.WATER}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", ctx)
	assert_eq(result["rolled"], 0)


func test_sage_grants_free_raise_on_lore_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SAGE)
	var ctx: Dictionary = {"is_lore_skill": true}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Lore: History", ctx)
	assert_gt(result["free_raises"], 0)


func test_sage_no_bonus_on_non_lore():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SAGE)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", {})
	assert_eq(result["free_raises"], 0)
	assert_eq(result["rolled"], 0)


func test_sensation_grants_free_raise_on_perform():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SENSATION)
	var ctx: Dictionary = {"is_perform_skill": true}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Perform: Singing", ctx)
	assert_gt(result["free_raises"], 0)


func test_crafty_grants_free_raise_on_low_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.CRAFTY)
	var ctx: Dictionary = {"is_low_skill": true}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Commerce", ctx)
	assert_gt(result["free_raises"], 0)


func test_balance_rolled_bonus_on_resist_when_honor_adding():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.BALANCE)
	var ctx: Dictionary = {"is_resist_temptation": true, "honor_rank_adding": true}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", ctx)
	assert_gt(result["rolled"], 0)


func test_balance_no_bonus_without_honor_adding():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.BALANCE)
	var ctx: Dictionary = {"is_resist_temptation": true, "honor_rank_adding": false}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", ctx)
	assert_eq(result["rolled"], 0)


func test_soul_of_artistry_bonus_on_artisan():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SOUL_OF_ARTISTRY)
	var ctx: Dictionary = {"is_artisan_skill": true}
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Artisan: Painting", ctx)
	assert_gt(result["free_raises"] + result["rolled"] + result["kept"], 0)


func test_multiple_advantages_stack():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SAGE)
	_add_advantage(c, Enums.Advantage.CRAFTY)
	var ctx_lore: Dictionary = {"is_lore_skill": true}
	var lore_result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Lore: History", ctx_lore)
	assert_gt(lore_result["free_raises"], 0)
	var ctx_low: Dictionary = {"is_low_skill": true}
	var low_result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Commerce", ctx_low)
	assert_gt(low_result["free_raises"], 0)


# ---------------------------------------------------------------------------
# get_tn_modifier
# ---------------------------------------------------------------------------

func test_tn_modifier_no_disadvantages_zero():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_tn_modifier(c, {}), 0)


func test_disturbing_countenance_raises_social_tn():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DISTURBING_COUNTENANCE)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_social": true})
	assert_gt(mod, 0)


func test_disturbing_countenance_no_effect_on_non_social():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DISTURBING_COUNTENANCE)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_social": false})
	assert_eq(mod, 0)


func test_phobia_raises_tn_on_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 1, {"situation_tags": ["fire"]})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"situation_tags": ["fire", "battle"]})
	assert_gt(mod, 0)


func test_phobia_no_effect_on_non_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 1, {"situation_tags": ["fire"]})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"situation_tags": ["water"]})
	assert_eq(mod, 0)


func test_phobia_rank2_higher_tn_penalty():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 2, {"situation_tags": ["undead"]})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"situation_tags": ["undead"]})
	assert_eq(mod, 10)  # 5 * rank


func test_lame_raises_tn_on_leg_agility():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LAME)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_leg_agility_roll": true})
	assert_eq(mod, 10)


func test_wanderer_raises_tn_on_navigation():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.WANDERER)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_navigation": true})
	assert_eq(mod, 15)


func test_wanderer_no_tn_on_non_navigation():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.WANDERER)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {})
	assert_eq(mod, 0)


func test_anachronism_raises_social_tn():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ANACHRONISM)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_social": true})
	assert_gt(mod, 0)


func test_bland_advantage_raises_tn_when_active():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.BLAND)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"bland_active": true})
	assert_gt(mod, 0)


func test_bland_no_tn_without_activation():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.BLAND)
	var mod: int = AdvantageSystem.get_tn_modifier(c, {})
	assert_eq(mod, 0)


# ---------------------------------------------------------------------------
# get_wound_tn_modifier
# ---------------------------------------------------------------------------

func test_wound_modifier_default_zero():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_wound_tn_modifier(c), 0)


func test_strength_of_earth_grants_positive_modifier():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.STRENGTH_OF_THE_EARTH)
	assert_eq(AdvantageSystem.get_wound_tn_modifier(c), 3)


func test_low_pain_threshold_gives_negative_modifier():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOW_PAIN_THRESHOLD)
	assert_eq(AdvantageSystem.get_wound_tn_modifier(c), -5)


func test_strength_of_earth_and_low_pain_stack():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.STRENGTH_OF_THE_EARTH)
	_add_disadvantage(c, Enums.Disadvantage.LOW_PAIN_THRESHOLD)
	assert_eq(AdvantageSystem.get_wound_tn_modifier(c), -2)


# ---------------------------------------------------------------------------
# get_unskilled_rank_bonus
# ---------------------------------------------------------------------------

func test_unskilled_bonus_zero_without_advantages():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Kenjutsu", {}), 0)


func test_crab_hands_unskilled_bonus_on_weapon_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.CRAB_HANDS)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Kenjutsu", {"is_weapon_skill": true}), 1)


func test_crab_hands_no_bonus_on_non_weapon():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.CRAB_HANDS)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Etiquette", {}), 0)


func test_crafty_unskilled_bonus_on_low_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.CRAFTY)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Commerce", {"is_low_skill": true}), 1)


func test_sage_unskilled_bonus_on_lore():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SAGE)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Lore: History", {}), 1)


func test_sensation_unskilled_bonus_on_perform():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SENSATION)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Perform: Singing", {"is_perform_skill": true}), 1)


func test_soul_of_artistry_unskilled_bonus_on_artisan():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SOUL_OF_ARTISTRY)
	assert_eq(AdvantageSystem.get_unskilled_rank_bonus(c, "Artisan: Pottery", {"is_artisan_skill": true}), 1)


# ---------------------------------------------------------------------------
# check_compulsion_trigger
# ---------------------------------------------------------------------------

func test_compulsion_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_compulsion_trigger(c, ["sake_house"])
	assert_false(result["triggered"])


func test_compulsion_triggered_on_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.COMPULSION, 1, {"location_tags": ["sake_house"]})
	var result: Dictionary = AdvantageSystem.check_compulsion_trigger(c, ["sake_house", "market"])
	assert_true(result["triggered"])
	assert_eq(result["tn"], 15)


func test_compulsion_rank2_higher_tn():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.COMPULSION, 2, {"location_tags": ["gambling"]})
	var result: Dictionary = AdvantageSystem.check_compulsion_trigger(c, ["gambling"])
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


func test_compulsion_not_triggered_on_non_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.COMPULSION, 1, {"location_tags": ["sake_house"]})
	var result: Dictionary = AdvantageSystem.check_compulsion_trigger(c, ["temple", "sacred"])
	assert_false(result["triggered"])


# ---------------------------------------------------------------------------
# check_phobia_trigger
# ---------------------------------------------------------------------------

func test_phobia_not_active_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_phobia_trigger(c, ["fire"])
	assert_false(result["active"])


func test_phobia_active_on_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 1, {"situation_tags": ["fire"]})
	var result: Dictionary = AdvantageSystem.check_phobia_trigger(c, ["fire"])
	assert_true(result["active"])
	assert_eq(result["tn_penalty"], 5)


func test_phobia_rank2_higher_penalty():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 2, {"situation_tags": ["undead"]})
	var result: Dictionary = AdvantageSystem.check_phobia_trigger(c, ["undead"])
	assert_true(result["active"])
	assert_eq(result["tn_penalty"], 10)


func test_phobia_not_active_on_non_matching_tag():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PHOBIA, 1, {"situation_tags": ["fire"]})
	var result: Dictionary = AdvantageSystem.check_phobia_trigger(c, ["water"])
	assert_false(result["active"])


# ---------------------------------------------------------------------------
# check_rumormonger_trigger
# ---------------------------------------------------------------------------

func test_rumormonger_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_rumormonger_trigger(c, 3.0)
	assert_false(result["triggered"])


func test_rumormonger_always_triggered_with_disadvantage():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.RUMORMONGER)
	var result: Dictionary = AdvantageSystem.check_rumormonger_trigger(c, 3.0)
	assert_true(result["triggered"])


func test_rumormonger_tn_scaled_by_glory_rank():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.RUMORMONGER)
	var result: Dictionary = AdvantageSystem.check_rumormonger_trigger(c, 4.0)
	assert_eq(result["tn"], 20)


func test_rumormonger_tn_zero_when_no_glory_around():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.RUMORMONGER)
	var result: Dictionary = AdvantageSystem.check_rumormonger_trigger(c, 0.0)
	assert_eq(result["tn"], 0)


# ---------------------------------------------------------------------------
# check_contrary_trigger
# ---------------------------------------------------------------------------

func test_contrary_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_contrary_trigger(c, 3.0)
	assert_false(result["triggered"])


func test_contrary_always_triggered_with_disadvantage():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = AdvantageSystem.check_contrary_trigger(c, 3.0)
	assert_true(result["triggered"])


func test_contrary_tn_scaled_by_glory_rank():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONTRARY)
	var result: Dictionary = AdvantageSystem.check_contrary_trigger(c, 4.0)
	assert_eq(result["tn"], 20)


# ---------------------------------------------------------------------------
# check_true_love_constraint
# ---------------------------------------------------------------------------

func test_true_love_no_constraint_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_true_love_constraint(c, true)
	assert_false(result["void_cost_required"])


func test_true_love_void_required_when_harming():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.TRUE_LOVE, 1, {"target_id": 42})
	var result: Dictionary = AdvantageSystem.check_true_love_constraint(c, true)
	assert_true(result["void_cost_required"])


func test_true_love_no_void_when_not_harming():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.TRUE_LOVE, 1, {"target_id": 42})
	var result: Dictionary = AdvantageSystem.check_true_love_constraint(c, false)
	assert_false(result["void_cost_required"])


# ---------------------------------------------------------------------------
# check_lost_love_trigger
# ---------------------------------------------------------------------------

func test_lost_love_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_clan": "Crane"}, 1)
	assert_false(result["triggered"])


func test_lost_love_triggered_on_matching_clan():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Lion"})
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_clan": "Lion"}, 1)
	assert_true(result["triggered"])
	assert_eq(result["tn_penalty"], 5)


func test_lost_love_not_triggered_on_different_clan():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Lion"})
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_clan": "Crane"}, 1)
	assert_false(result["triggered"])


func test_lost_love_triggered_on_death_province():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"province_id": 5})
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_province_id": 5}, 1)
	assert_true(result["triggered"])


func test_lost_love_max_two_per_day():
	var c := _make_character()
	var dis: DisadvantageData = _add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Lion"})
	dis.metadata["triggers_today"] = 2
	dis.metadata["last_trigger_ic_day"] = 1
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_clan": "Lion"}, 1)
	assert_false(result["triggered"])


func test_lost_love_resets_trigger_count_on_new_day():
	var c := _make_character()
	var dis: DisadvantageData = _add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Lion"})
	dis.metadata["triggers_today"] = 2
	dis.metadata["last_trigger_ic_day"] = 1
	# Different IC day — count should reset
	var result: Dictionary = AdvantageSystem.check_lost_love_trigger(c, {"lost_love_clan": "Lion"}, 2)
	assert_true(result["triggered"])


# ---------------------------------------------------------------------------
# get_glory_rank
# ---------------------------------------------------------------------------

func test_glory_rank_is_int_floor_of_glory():
	var c := _make_character()
	c.glory = 3.7
	assert_eq(AdvantageSystem.get_glory_rank(c), 3)


func test_glory_rank_zero_at_zero_glory():
	var c := _make_character()
	c.glory = 0.0
	assert_eq(AdvantageSystem.get_glory_rank(c), 0)


func test_glory_rank_ten_at_max():
	var c := _make_character()
	c.glory = 10.0
	assert_eq(AdvantageSystem.get_glory_rank(c), 10)


# ---------------------------------------------------------------------------
# get_magic_resistance_tn
# ---------------------------------------------------------------------------

func test_magic_resistance_zero_without_advantage():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_magic_resistance_tn(c), 0)


func test_magic_resistance_rank1_returns_3():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.MAGIC_RESISTANCE, 1)
	assert_eq(AdvantageSystem.get_magic_resistance_tn(c), 3)


func test_magic_resistance_rank2_returns_6():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.MAGIC_RESISTANCE, 2)
	assert_eq(AdvantageSystem.get_magic_resistance_tn(c), 6)


# ---------------------------------------------------------------------------
# get_wrath_of_kami_bonus
# ---------------------------------------------------------------------------

func test_wrath_of_kami_zero_without_disadvantage():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_wrath_of_kami_bonus(c, Enums.Ring.FIRE), 0)


func test_wrath_of_kami_grants_free_raise_on_marked_element():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.WRATH_OF_THE_KAMI, 1, {"element": Enums.Ring.WATER})
	assert_eq(AdvantageSystem.get_wrath_of_kami_bonus(c, Enums.Ring.WATER), 1)


func test_wrath_of_kami_zero_on_unmarked_element():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.WRATH_OF_THE_KAMI, 1, {"element": Enums.Ring.WATER})
	assert_eq(AdvantageSystem.get_wrath_of_kami_bonus(c, Enums.Ring.FIRE), 0)


# ---------------------------------------------------------------------------
# Elemental imbalance
# ---------------------------------------------------------------------------

func test_elemental_imbalance_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(c, Enums.Ring.FIRE)
	assert_false(result["triggered"])


func test_elemental_imbalance_triggered_on_matching_element():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ELEMENTAL_IMBALANCE, 1, {"element": Enums.Ring.FIRE})
	var result: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(c, Enums.Ring.FIRE)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 15)


func test_elemental_imbalance_rank2_higher_tn():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ELEMENTAL_IMBALANCE, 2, {"element": Enums.Ring.EARTH})
	var result: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(c, Enums.Ring.EARTH)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


func test_elemental_imbalance_not_triggered_on_different_element():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ELEMENTAL_IMBALANCE, 1, {"element": Enums.Ring.FIRE})
	var result: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(c, Enums.Ring.AIR)
	assert_false(result["triggered"])


# ---------------------------------------------------------------------------
# Behavioral triggers (brash, cant_lie, soft_hearted, overconfident)
# ---------------------------------------------------------------------------

func test_brash_not_triggered_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_brash_trigger(c, true)
	assert_false(result["triggered"])


func test_brash_triggered_when_threatened():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BRASH)
	var result: Dictionary = AdvantageSystem.check_brash_trigger(c, true)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 25)


func test_brash_not_triggered_when_not_threatened():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BRASH)
	var result: Dictionary = AdvantageSystem.check_brash_trigger(c, false)
	assert_false(result["triggered"])


func test_cant_lie_triggered_when_lie_detected():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CANT_LIE)
	var result: Dictionary = AdvantageSystem.check_cant_lie_trigger(c, true)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


func test_soft_hearted_triggered_before_killing_human():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SOFT_HEARTED)
	var result: Dictionary = AdvantageSystem.check_soft_hearted_trigger(c, true)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


func test_overconfident_triggered_when_outnumbered():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.OVERCONFIDENT)
	var result: Dictionary = AdvantageSystem.check_overconfident_trigger(c, true)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


# ---------------------------------------------------------------------------
# get_target_detection_tn_bonus / get_target_temptation_bonus
# ---------------------------------------------------------------------------

func test_shadowed_heart_raises_detection_tn():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SHADOWED_HEART)
	assert_eq(AdvantageSystem.get_target_detection_tn_bonus(c), 5)


func test_no_shadowed_heart_zero_detection_bonus():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_target_detection_tn_bonus(c), 0)


func test_dangerous_beauty_grants_rolled_to_attacker_matching_gender():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DANGEROUS_BEAUTY)
	assert_eq(AdvantageSystem.get_target_temptation_bonus(c, true), 1)


func test_dangerous_beauty_no_bonus_to_non_matching_gender():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DANGEROUS_BEAUTY)
	assert_eq(AdvantageSystem.get_target_temptation_bonus(c, false), 0)


# ---------------------------------------------------------------------------
# get_attacker_bonus_from_target (GULLIBLE)
# ---------------------------------------------------------------------------

func test_gullible_grants_kept_bonus_to_sincerity_deceit():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.GULLIBLE)
	var result: Dictionary = AdvantageSystem.get_attacker_bonus_from_target(c, "Sincerity", {"is_deceit": true})
	assert_gt(result["kept"], 0)


func test_gullible_no_bonus_to_non_deceit():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.GULLIBLE)
	var result: Dictionary = AdvantageSystem.get_attacker_bonus_from_target(c, "Sincerity", {"is_deceit": false})
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# SPY_NETWORK helpers
# ---------------------------------------------------------------------------

func test_spy_network_focus_empty_without_advantage():
	var c := _make_character()
	assert_true(AdvantageSystem.get_spy_network_focus(c).is_empty())


func test_spy_network_focus_returns_metadata():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SPY_NETWORK, 1, {"focus_type": "character", "focus_id": 5})
	var focus: Dictionary = AdvantageSystem.get_spy_network_focus(c)
	assert_eq(focus["focus_type"], "character")
	assert_eq(focus["focus_id"], 5)


func test_set_spy_network_focus_writes_metadata():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.SPY_NETWORK)
	AdvantageSystem.set_spy_network_focus(c, "place", 99, 42)
	var focus: Dictionary = AdvantageSystem.get_spy_network_focus(c)
	assert_eq(focus["focus_type"], "place")
	assert_eq(focus["focus_id"], 99)


func test_set_spy_network_focus_noop_without_advantage():
	var c := _make_character()
	AdvantageSystem.set_spy_network_focus(c, "army", 7, 1)
	assert_true(AdvantageSystem.get_spy_network_focus(c).is_empty())


# ---------------------------------------------------------------------------
# WELL_CONNECTED helpers
# ---------------------------------------------------------------------------

func test_well_connected_empty_without_advantage():
	var c := _make_character()
	assert_true(AdvantageSystem.get_well_connected_courts(c).is_empty())


func test_well_connected_returns_settlement_ids():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1, {"settlement_id": 10})
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1, {"settlement_id": 20})
	var courts: Array = AdvantageSystem.get_well_connected_courts(c)
	assert_eq(courts.size(), 2)
	assert_true(10 in courts)
	assert_true(20 in courts)


func test_well_connected_skips_invalid_settlement():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1, {"settlement_id": -1})
	var courts: Array = AdvantageSystem.get_well_connected_courts(c)
	assert_true(courts.is_empty())


# ---------------------------------------------------------------------------
# assign_derived_advantages (world gen)
# ---------------------------------------------------------------------------

func test_ishiken_do_assigned_to_ishiken_school():
	var c := _make_character()
	c.school = "Isawa Ishiken"
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_advantage(c, Enums.Advantage.ISHIKEN_DO))


func test_ishiken_do_not_assigned_to_other_schools():
	var c := _make_character()
	c.school = "Doji Courtier"
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_false(AdvantageSystem.has_advantage(c, Enums.Advantage.ISHIKEN_DO))


func test_fame_assigned_when_glory_at_least_two():
	var c := _make_character()
	c.glory = 2.0
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_fame_not_assigned_when_glory_below_two():
	var c := _make_character()
	c.glory = 1.5
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_false(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_shadowlands_taint_assigned_when_taint_positive():
	var c := _make_character()
	c.taint = 0.5
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.SHADOWLANDS_TAINT))


func test_shadowlands_taint_not_assigned_when_taint_zero():
	var c := _make_character()
	c.taint = 0.0
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_false(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.SHADOWLANDS_TAINT))


func test_hostage_disadvantage_assigned_when_in_active_hostages():
	var c := _make_character(5)
	var hostages: Array = [{"hostage_id": 5, "holder_id": 10}]
	AdvantageSystem.assign_derived_advantages(c, hostages, {})
	assert_true(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.HOSTAGE))


func test_hostage_disadvantage_not_assigned_when_not_in_hostages():
	var c := _make_character(5)
	var hostages: Array = [{"hostage_id": 99}]
	AdvantageSystem.assign_derived_advantages(c, hostages, {})
	assert_false(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.HOSTAGE))


func test_dishonored_assigned_when_honor_below_one_with_lord():
	var c := _make_character()
	c.honor = 0.5
	c.role_position = ""
	c.lord_id = 10
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.DISHONORED))


func test_dishonored_not_assigned_when_honor_sufficient():
	var c := _make_character()
	c.honor = 1.5
	c.lord_id = 10
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_false(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.DISHONORED))


func test_social_disadvantage_assigned_when_status_below_half():
	var c := _make_character()
	c.status = 0.0
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.SOCIAL_DISADVANTAGE))


func test_social_disadvantage_not_assigned_when_status_sufficient():
	var c := _make_character()
	c.status = 1.0
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_false(AdvantageSystem.has_disadvantage(c, Enums.Disadvantage.SOCIAL_DISADVANTAGE))


func test_assign_derived_advantages_no_duplicates():
	var c := _make_character()
	c.glory = 2.5
	AdvantageSystem.assign_derived_advantages(c, [], {})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	var count: int = 0
	for adv: AdvantageData in c.advantages:
		if adv.advantage_type == Enums.Advantage.FAME:
			count += 1
	assert_eq(count, 1)


# ---------------------------------------------------------------------------
# get_healing_stamina_bonus / has_permanent_wound / get_honor_loss_increase
# ---------------------------------------------------------------------------

func test_quick_healer_stamina_bonus():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.QUICK_HEALER)
	assert_eq(AdvantageSystem.get_healing_stamina_bonus(c), 2)


func test_no_quick_healer_zero_bonus():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_healing_stamina_bonus(c), 0)


func test_permanent_wound_true_when_disadvantage_present():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.PERMANENT_WOUND)
	assert_true(AdvantageSystem.has_permanent_wound(c))


func test_permanent_wound_false_without_disadvantage():
	var c := _make_character()
	assert_false(AdvantageSystem.has_permanent_wound(c))


func test_idealistic_honor_loss_increase():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.IDEALISTIC)
	assert_almost_eq(AdvantageSystem.get_honor_loss_increase(c), 1.0, 0.01)


func test_no_idealistic_zero_honor_increase():
	var c := _make_character()
	assert_almost_eq(AdvantageSystem.get_honor_loss_increase(c), 0.0, 0.01)


# ---------------------------------------------------------------------------
# get_melee_damage_penalty
# ---------------------------------------------------------------------------

func test_small_grants_melee_damage_penalty():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SMALL)
	assert_eq(AdvantageSystem.get_melee_damage_penalty(c), -1)


func test_no_small_no_damage_penalty():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_melee_damage_penalty(c), 0)
