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


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — INNER_GIFT Empathy (advantage)
# ---------------------------------------------------------------------------

func test_inner_gift_empathy_kept_bonus_on_courtier_sensing():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INNER_GIFT, 1, {"gift": "Empathy"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", {"is_sensing_feelings": true})
	assert_eq(result["kept"], 1)


func test_inner_gift_empathy_no_bonus_without_sensing_context():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INNER_GIFT, 1, {"gift": "Empathy"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", {})
	assert_eq(result["kept"], 0)


func test_inner_gift_empathy_no_bonus_on_wrong_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INNER_GIFT, 1, {"gift": "Empathy"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {"is_sensing_feelings": true})
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — ANTISOCIAL disadvantage
# ---------------------------------------------------------------------------

func test_antisocial_rank1_minus_1k0_on_social():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ANTISOCIAL, 1)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {"is_social": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], 0)


func test_antisocial_rank2_minus_1k1_on_social():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ANTISOCIAL, 2)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {"is_social": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_antisocial_no_effect_on_non_social():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.ANTISOCIAL, 1)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", {})
	assert_eq(result["rolled"], 0)
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — BAD_EYESIGHT disadvantage
# ---------------------------------------------------------------------------

func test_bad_eyesight_minus_1k1_on_perception_based():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BAD_EYESIGHT)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation", {"is_perception_based": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_bad_eyesight_no_effect_on_non_perception():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BAD_EYESIGHT)
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {})
	assert_eq(result["rolled"], 0)
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — BAD_FORTUNE Moto Curse
# ---------------------------------------------------------------------------

func test_bad_fortune_moto_curse_minus_1k0_resist_taint():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Moto_Curse"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", {"is_resist_taint": true})
	assert_eq(result["rolled"], -1)


func test_bad_fortune_moto_curse_no_effect_on_non_taint():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Moto_Curse"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {})
	assert_eq(result["rolled"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — CONSUMED sub-types (Control / Strength / Will)
# ---------------------------------------------------------------------------

func test_consumed_control_minus_1k1_etiquette():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Control"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_consumed_control_minus_1k1_sincerity():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Control"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Sincerity", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_consumed_control_no_effect_on_other_skills():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Control"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", {})
	assert_eq(result["rolled"], 0)
	assert_eq(result["kept"], 0)


func test_consumed_strength_minus_1k0_etiquette():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Strength"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], 0)


func test_consumed_will_minus_1k1_courtier():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Will"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_consumed_will_minus_1k1_temptation():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Will"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Temptation", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — CURSED_BY_THE_REALM sub-types
# ---------------------------------------------------------------------------

func test_cursed_chikushudo_minus_1k1_animal_handling():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Chikushudo"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Animal Handling", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_cursed_jigoku_minus_1k1_resist_taint():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Jigoku"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", {"is_resist_taint": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_cursed_maigo_no_musha_minus_1k1_vs_spirit():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Maigo_no_Musha"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", {"opponent_is_spirit": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_cursed_meido_minus_1k0_perception_when_unoccupied():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Meido"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation", {"is_perception_based": true, "is_unoccupied": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], 0)


func test_cursed_meido_no_effect_when_occupied():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Meido"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation", {"is_perception_based": true, "is_unoccupied": false})
	assert_eq(result["rolled"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_skill_bonus — SEVEN_FORTUNES_CURSE sub-types
# ---------------------------------------------------------------------------

func test_seven_fortunes_curse_daikoku_minus_1k1_commerce():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Daikoku"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Commerce", {})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_seven_fortunes_curse_ebisu_minus_1k1_social_vs_commoner():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Ebisu"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {"is_social": true, "opponent_is_commoner": true})
	assert_eq(result["rolled"], -1)
	assert_eq(result["kept"], -1)


func test_seven_fortunes_curse_ebisu_no_effect_vs_samurai():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Ebisu"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "Etiquette", {"is_social": true, "opponent_is_commoner": false})
	assert_eq(result["rolled"], 0)


func test_seven_fortunes_curse_jurojin_minus_2k0_resist_disease():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Jurojin"})
	var result: Dictionary = AdvantageSystem.get_skill_bonus(c, "any", {"is_resist_disease_or_poison": true})
	assert_eq(result["rolled"], -2)
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_tn_modifier — DOUBT
# ---------------------------------------------------------------------------

func test_doubt_plus5_tn_on_chosen_school_skill():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DOUBT, 1, {"skill": "Kenjutsu"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Kenjutsu"})
	assert_eq(mod, 5)


func test_doubt_no_effect_on_other_skills():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DOUBT, 1, {"skill": "Kenjutsu"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Etiquette"})
	assert_eq(mod, 0)


# ---------------------------------------------------------------------------
# s45 gap: get_tn_modifier — CONSUMED Perfection
# ---------------------------------------------------------------------------

func test_consumed_perfection_plus5_tn_all_rolls():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Perfection"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {})
	assert_eq(mod, 5)


func test_consumed_non_perfection_no_universal_tn_penalty():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Control"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {})
	assert_eq(mod, 0)


# ---------------------------------------------------------------------------
# s45 gap: get_tn_modifier — CURSED_BY_THE_REALM Tengoku
# ---------------------------------------------------------------------------

func test_cursed_tengoku_plus10_tn_in_celestial_temple():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Tengoku"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"is_in_celestial_temple": true})
	assert_eq(mod, 10)


func test_cursed_tengoku_no_effect_outside_temple():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Tengoku"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {})
	assert_eq(mod, 0)


# ---------------------------------------------------------------------------
# s45 gap: get_tn_modifier — SEVEN_FORTUNES_CURSE Benten / Fukurokujin
# ---------------------------------------------------------------------------

func test_seven_fortunes_curse_benten_plus10_tn_etiquette():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Benten"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Etiquette"})
	assert_eq(mod, 10)


func test_seven_fortunes_curse_benten_no_effect_on_non_etiquette():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Benten"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Courtier"})
	assert_eq(mod, 0)


func test_seven_fortunes_curse_fukurokujin_plus5_tn_lore():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Fukurokujin"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Lore: History"})
	assert_eq(mod, 5)


func test_seven_fortunes_curse_fukurokujin_no_effect_on_non_lore():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Fukurokujin"})
	var mod: int = AdvantageSystem.get_tn_modifier(c, {"skill_name": "Kenjutsu"})
	assert_eq(mod, 0)


# ---------------------------------------------------------------------------
# s45 gap: is_void_spend_blocked — CONSUMED Determination and FAILURE_OF_BUSHIDO
# ---------------------------------------------------------------------------

func test_consumed_determination_blocks_void_enhance():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Determination"})
	assert_true(AdvantageSystem.is_void_spend_blocked(c, {"is_void_enhance": true}))


func test_consumed_determination_allows_technique_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Determination"})
	assert_false(AdvantageSystem.is_void_spend_blocked(c, {"is_void_enhance": false}))


func test_failure_of_bushido_honesty_blocks_sincere_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Honesty"})
	assert_true(AdvantageSystem.is_void_spend_blocked(c, {"is_honest_sincerity": true}))


func test_failure_of_bushido_honesty_allows_other_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Honesty"})
	assert_false(AdvantageSystem.is_void_spend_blocked(c, {"is_honest_sincerity": false}))


func test_failure_of_bushido_duty_blocks_wound_negate_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Duty"})
	assert_true(AdvantageSystem.is_void_spend_blocked(c, {"is_negate_wounds": true}))


func test_failure_of_bushido_duty_allows_other_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Duty"})
	assert_false(AdvantageSystem.is_void_spend_blocked(c, {"is_negate_wounds": false}))


# ---------------------------------------------------------------------------
# s45 gap: get_extra_void_cost — SEVEN_FORTUNES_CURSE Hotei
# ---------------------------------------------------------------------------

func test_hotei_curse_costs_one_extra_void():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Hotei"})
	assert_eq(AdvantageSystem.get_extra_void_cost(c), 1)


func test_no_hotei_zero_extra_void_cost():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_extra_void_cost(c), 0)


func test_other_fortune_curse_zero_extra_void_cost():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Benten"})
	assert_eq(AdvantageSystem.get_extra_void_cost(c), 0)


# ---------------------------------------------------------------------------
# s45 gap: check_consumed_trigger — Insight and Knowledge sub-types
# ---------------------------------------------------------------------------

func test_consumed_insight_triggers_on_school_skill():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Insight"})
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Insight", {"is_school_skill": true})
	assert_true(result["triggered"])
	assert_eq(result["tn"], 20)


func test_consumed_insight_no_trigger_without_school_skill_context():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Insight"})
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Insight", {})
	assert_false(result["triggered"])


func test_consumed_knowledge_triggers_on_new_topic():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Knowledge"})
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Knowledge", {"is_new_topic": true})
	assert_true(result["triggered"])
	assert_eq(result["tn"], 25)


func test_consumed_knowledge_no_trigger_without_new_topic():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Knowledge"})
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Knowledge", {})
	assert_false(result["triggered"])


func test_consumed_trigger_wrong_precept_type_no_trigger():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CONSUMED, 1, {"precept": "Insight"})
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Knowledge", {"is_school_skill": true})
	assert_false(result["triggered"])


func test_consumed_trigger_no_disadvantage_no_trigger():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_consumed_trigger(c, "Insight", {"is_school_skill": true})
	assert_false(result["triggered"])


# ---------------------------------------------------------------------------
# s45 gap: check_cursed_toshigoku_trigger
# ---------------------------------------------------------------------------

func test_cursed_toshigoku_triggers_when_opponent_wounded():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Toshigoku"})
	var result: Dictionary = AdvantageSystem.check_cursed_toshigoku_trigger(c, true)
	assert_true(result["triggered"])
	assert_eq(result["tn"], 15)


func test_cursed_toshigoku_no_trigger_when_opponent_healthy():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Toshigoku"})
	var result: Dictionary = AdvantageSystem.check_cursed_toshigoku_trigger(c, false)
	assert_false(result["triggered"])


func test_cursed_toshigoku_no_trigger_without_disadvantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.check_cursed_toshigoku_trigger(c, true)
	assert_false(result["triggered"])


func test_cursed_other_realm_no_toshigoku_trigger():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Jigoku"})
	var result: Dictionary = AdvantageSystem.check_cursed_toshigoku_trigger(c, true)
	assert_false(result["triggered"])


# ---------------------------------------------------------------------------
# s45 gap: check_great_destiny
# ---------------------------------------------------------------------------

func test_great_destiny_true_when_different_year():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.GREAT_DESTINY, 1, {"last_triggered_ic_year": 1000})
	assert_true(AdvantageSystem.check_great_destiny(c, 1001))


func test_great_destiny_false_when_same_year():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.GREAT_DESTINY, 1, {"last_triggered_ic_year": 1000})
	assert_false(AdvantageSystem.check_great_destiny(c, 1000))


func test_great_destiny_true_when_never_triggered():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.GREAT_DESTINY)
	assert_true(AdvantageSystem.check_great_destiny(c, 1000))


func test_great_destiny_false_without_advantage():
	var c := _make_character()
	assert_false(AdvantageSystem.check_great_destiny(c, 1000))


# ---------------------------------------------------------------------------
# s45 gap: get_darling_status_bonus
# ---------------------------------------------------------------------------

func test_darling_returns_1_for_matching_settlement():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT, 1, {"settlement_id": 42})
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 42), 1)


func test_darling_returns_0_for_different_settlement():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT, 1, {"settlement_id": 42})
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 99), 0)


func test_darling_returns_0_without_advantage():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 42), 0)


func test_darling_multiple_courts_returns_1_for_each():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT, 1, {"settlement_id": 10})
	_add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT, 1, {"settlement_id": 20})
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 10), 1)
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 20), 1)
	assert_eq(AdvantageSystem.get_darling_status_bonus(c, 30), 0)


# ---------------------------------------------------------------------------
# s45 gap: can_use_void_versatility
# ---------------------------------------------------------------------------

func test_void_versatility_true_for_matching_ring():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.VOID_VERSATILITY, 1, {"ring": Enums.Ring.FIRE})
	assert_true(AdvantageSystem.can_use_void_versatility(c, Enums.Ring.FIRE))


func test_void_versatility_false_for_different_ring():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.VOID_VERSATILITY, 1, {"ring": Enums.Ring.FIRE})
	assert_false(AdvantageSystem.can_use_void_versatility(c, Enums.Ring.WATER))


func test_void_versatility_false_without_advantage():
	var c := _make_character()
	assert_false(AdvantageSystem.can_use_void_versatility(c, Enums.Ring.FIRE))


# ---------------------------------------------------------------------------
# s45 gap: get_hero_recognition_tn_modifier
# ---------------------------------------------------------------------------

func test_hero_of_the_people_minus10_for_non_samurai_recognizer():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.HERO_OF_THE_PEOPLE)
	assert_eq(AdvantageSystem.get_hero_recognition_tn_modifier(c, true), -10)


func test_hero_of_the_people_zero_for_samurai_recognizer():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.HERO_OF_THE_PEOPLE)
	assert_eq(AdvantageSystem.get_hero_recognition_tn_modifier(c, false), 0)


func test_hero_of_the_people_zero_without_advantage():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_hero_recognition_tn_modifier(c, true), 0)


# ---------------------------------------------------------------------------
# s45 gap: get_inheritance_skill_bonus
# ---------------------------------------------------------------------------

func test_inheritance_plus_1k1_when_using_heirloom():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INHERITANCE)
	var result: Dictionary = AdvantageSystem.get_inheritance_skill_bonus(c, true)
	assert_eq(result["rolled"], 0)
	assert_eq(result["kept"], 1)


func test_inheritance_zero_when_not_using_heirloom():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INHERITANCE)
	var result: Dictionary = AdvantageSystem.get_inheritance_skill_bonus(c, false)
	assert_eq(result["kept"], 0)


func test_inheritance_zero_without_advantage():
	var c := _make_character()
	var result: Dictionary = AdvantageSystem.get_inheritance_skill_bonus(c, true)
	assert_eq(result["kept"], 0)


# ---------------------------------------------------------------------------
# s45 gap: get_void_recovery_hours
# ---------------------------------------------------------------------------

func test_touch_yume_do_returns_4_hours():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Yume-do"})
	assert_eq(AdvantageSystem.get_void_recovery_hours(c), 4)


func test_cursed_yume_do_returns_10_hours():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Yume-do"})
	assert_eq(AdvantageSystem.get_void_recovery_hours(c), 10)


func test_default_void_recovery_8_hours():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_void_recovery_hours(c), 8)


func test_touch_other_realm_still_returns_default():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Tengoku"})
	assert_eq(AdvantageSystem.get_void_recovery_hours(c), 8)


# ---------------------------------------------------------------------------
# s45 gap: assign_derived_advantages — BLACK_SHEEP disposition penalties
# ---------------------------------------------------------------------------

func test_black_sheep_family_member_gets_minus40_disposition():
	var black_sheep := _make_character(1)
	black_sheep.clan = "Crane"
	black_sheep.family = "Doji"
	_add_disadvantage(black_sheep, Enums.Disadvantage.BLACK_SHEEP)

	var family_member := _make_character(2)
	family_member.clan = "Crane"
	family_member.family = "Doji"

	var chars_by_id: Dictionary = {1: black_sheep, 2: family_member}
	AdvantageSystem.assign_derived_advantages(black_sheep, [], chars_by_id)

	assert_eq(family_member.disposition_values.get(1, 0), -40)


func test_black_sheep_clan_member_gets_minus20_disposition():
	var black_sheep := _make_character(1)
	black_sheep.clan = "Crane"
	black_sheep.family = "Doji"
	_add_disadvantage(black_sheep, Enums.Disadvantage.BLACK_SHEEP)

	var clan_member := _make_character(3)
	clan_member.clan = "Crane"
	clan_member.family = "Kakita"  # different family, same clan

	var chars_by_id: Dictionary = {1: black_sheep, 3: clan_member}
	AdvantageSystem.assign_derived_advantages(black_sheep, [], chars_by_id)

	assert_eq(clan_member.disposition_values.get(1, 0), -20)


func test_black_sheep_does_not_affect_self():
	var black_sheep := _make_character(1)
	black_sheep.clan = "Crane"
	black_sheep.family = "Doji"
	_add_disadvantage(black_sheep, Enums.Disadvantage.BLACK_SHEEP)

	var chars_by_id: Dictionary = {1: black_sheep}
	AdvantageSystem.assign_derived_advantages(black_sheep, [], chars_by_id)

	assert_eq(black_sheep.disposition_values.get(1, 0), 0)


func test_black_sheep_no_effect_without_disadvantage():
	var target := _make_character(1)
	target.clan = "Crane"
	target.family = "Doji"

	var family_member := _make_character(2)
	family_member.clan = "Crane"
	family_member.family = "Doji"

	var chars_by_id: Dictionary = {1: target, 2: family_member}
	AdvantageSystem.assign_derived_advantages(target, [], chars_by_id)

	assert_eq(family_member.disposition_values.get(1, 0), 0)


func test_black_sheep_penalty_clamped_at_minus100():
	var black_sheep := _make_character(1)
	black_sheep.clan = "Crane"
	black_sheep.family = "Doji"
	_add_disadvantage(black_sheep, Enums.Disadvantage.BLACK_SHEEP)

	var family_member := _make_character(2)
	family_member.clan = "Crane"
	family_member.family = "Doji"
	family_member.disposition_values[1] = -75  # pre-existing negative disposition

	var chars_by_id: Dictionary = {1: black_sheep, 2: family_member}
	AdvantageSystem.assign_derived_advantages(black_sheep, [], chars_by_id)

	assert_eq(family_member.disposition_values.get(1, 0), -100)  # clamped at floor


# ===========================================================================
# s45 Gap-fill tests (added 2026-06-03)
# ===========================================================================

# --- PARAGON Compassion ---

func test_paragon_compassion_grants_2k2_when_void_and_lower_status():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Compassion"})
	var ctx := {"is_void_spend": true, "is_acting_for_lower_status": true}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(r["rolled"], 2)
	assert_eq(r["kept"], 2)


func test_paragon_compassion_no_bonus_without_lower_status():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Compassion"})
	var ctx := {"is_void_spend": true, "is_acting_for_lower_status": false}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(r["rolled"], 0)
	assert_eq(r["kept"], 0)


func test_paragon_compassion_no_bonus_without_void_spend():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Compassion"})
	var ctx := {"is_void_spend": false, "is_acting_for_lower_status": true}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(r["rolled"], 0)
	assert_eq(r["kept"], 0)


# --- SEVEN_FORTUNES_BLESSING Jurojin ---

func test_blessing_jurojin_grants_2k0_resist_disease():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Jurojin"})
	var ctx := {"is_resist_disease_or_poison": true}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Stamina", ctx)
	assert_eq(r["rolled"], 2)
	assert_eq(r["kept"], 0)


func test_blessing_jurojin_no_bonus_without_resist_flag():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Jurojin"})
	var ctx: Dictionary = {}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Medicine", ctx)
	assert_eq(r["rolled"], 0)


# --- SEVEN_FORTUNES_BLESSING Hotei ---

func test_blessing_hotei_grants_2_free_raises_contested():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Hotei"})
	var ctx := {"is_contested": true}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(r["free_raises"], 2)


func test_blessing_hotei_no_free_raises_non_contested():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Hotei"})
	var ctx: Dictionary = {}
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(r["free_raises"], 0)


# --- SWORN_ENEMY void block ---

func test_sworn_enemy_blocks_void_against_nemesis():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"nemesis_id": 99})
	var ctx := {"opponent_id": 99}
	assert_true(AdvantageSystem.is_void_spend_blocked(c, ctx))


func test_sworn_enemy_does_not_block_void_against_other():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"nemesis_id": 99})
	var ctx := {"opponent_id": 55}
	assert_false(AdvantageSystem.is_void_spend_blocked(c, ctx))


func test_sworn_enemy_does_not_block_when_no_opponent():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"nemesis_id": 99})
	assert_false(AdvantageSystem.is_void_spend_blocked(c, {}))


# --- requires_void_to_act ---

func test_requires_void_insensitive_at_personal_risk():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.INSENSITIVE)
	var ctx := {"is_acting_at_personal_risk_for_other": true}
	assert_true(AdvantageSystem.requires_void_to_act(c, ctx))


func test_requires_void_insensitive_not_at_risk():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.INSENSITIVE)
	var ctx: Dictionary = {}
	assert_false(AdvantageSystem.requires_void_to_act(c, ctx))


func test_requires_void_fob_compassion_lower_status():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Compassion"})
	var ctx := {"is_acting_for_lower_status": true}
	assert_true(AdvantageSystem.requires_void_to_act(c, ctx))


func test_requires_void_fob_compassion_same_status():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"virtue": "Compassion"})
	var ctx: Dictionary = {}
	assert_false(AdvantageSystem.requires_void_to_act(c, ctx))


func test_requires_void_no_relevant_disadvantage():
	var c := _make_character(1)
	assert_false(AdvantageSystem.requires_void_to_act(c, {"is_acting_at_personal_risk_for_other": true}))


# --- check_hotei_void_protection ---

func test_hotei_void_protection_present():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Hotei"})
	assert_true(AdvantageSystem.check_hotei_void_protection(c))


func test_hotei_void_protection_absent_other_fortune():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SEVEN_FORTUNES_BLESSING, 1, {"fortune": "Benten"})
	assert_false(AdvantageSystem.check_hotei_void_protection(c))


func test_hotei_void_protection_absent_no_advantage():
	var c := _make_character(1)
	assert_false(AdvantageSystem.check_hotei_void_protection(c))


# --- get_glory_multiplier ---

func test_glory_multiplier_normal_character():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_glory_multiplier(c), 1.0)


func test_glory_multiplier_ascetic_samurai():
	var c := _make_character(1)
	c.school_type = Enums.SchoolType.COURTIER
	_add_disadvantage(c, Enums.Disadvantage.ASCETIC)
	assert_eq(AdvantageSystem.get_glory_multiplier(c), 0.5)


func test_glory_multiplier_ascetic_monk():
	var c := _make_character(1)
	c.school_type = Enums.SchoolType.MONK
	_add_disadvantage(c, Enums.Disadvantage.ASCETIC)
	assert_eq(AdvantageSystem.get_glory_multiplier(c), 0.25)


# --- get_recognition_tn ---

func test_recognition_tn_no_bounty():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_recognition_tn(c), -1)


func test_recognition_tn_rank1_returns_25():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 1)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 25)


func test_recognition_tn_rank2_returns_15():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 2)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 15)


func test_recognition_tn_rank3_returns_10():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 3)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 10)


# --- get_tactician_modifier ---

func test_tactician_modifier_present():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.TACTICIAN)
	assert_eq(AdvantageSystem.get_tactician_modifier(c), 5)


func test_tactician_modifier_absent():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_tactician_modifier(c), 0)


# --- get_perceived_honor ---

func test_perceived_honor_no_advantage():
	var c := _make_character(1)
	c.honor = 4.0
	assert_eq(AdvantageSystem.get_perceived_honor(c), 4.0)


func test_perceived_honor_rank1():
	var c := _make_character(1)
	c.honor = 4.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 1)
	assert_eq(AdvantageSystem.get_perceived_honor(c), 5.0)


func test_perceived_honor_rank2():
	var c := _make_character(1)
	c.honor = 3.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	assert_eq(AdvantageSystem.get_perceived_honor(c), 5.0)


# --- is_navigation_immune ---

func test_navigation_immune_known_territory():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.WAY_OF_THE_LAND)
	assert_true(AdvantageSystem.is_navigation_immune(c, {"is_known_territory": true}))


func test_navigation_immune_unknown_territory():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.WAY_OF_THE_LAND)
	assert_false(AdvantageSystem.is_navigation_immune(c, {}))


func test_navigation_immune_no_advantage():
	var c := _make_character(1)
	assert_false(AdvantageSystem.is_navigation_immune(c, {"is_known_territory": true}))


# --- get_die_explosion_cap ---

func test_die_explosion_cap_gaijin_name_social():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.GAIJIN_NAME)
	assert_eq(AdvantageSystem.get_die_explosion_cap(c, {"is_social": true}), 1)


func test_die_explosion_cap_gaijin_name_non_social():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.GAIJIN_NAME)
	assert_eq(AdvantageSystem.get_die_explosion_cap(c, {}), 0)


func test_die_explosion_cap_no_gaijin_name():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_die_explosion_cap(c, {"is_social": true}), 0)


# --- get_spirit_realm_glory_bonus ---

func test_spirit_realm_glory_bonus_maigo_over_3():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Maigo_no_Musha"})
	assert_eq(AdvantageSystem.get_spirit_realm_glory_bonus(c, 4.0), 1)


func test_spirit_realm_glory_bonus_maigo_exactly_3():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Maigo_no_Musha"})
	assert_eq(AdvantageSystem.get_spirit_realm_glory_bonus(c, 3.0), 0)


func test_spirit_realm_glory_bonus_other_realm():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Yomi"})
	assert_eq(AdvantageSystem.get_spirit_realm_glory_bonus(c, 5.0), 0)


# --- is_glory_treated_as_infamy_by ---

func test_glory_as_infamy_matching_sect():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CAST_OUT, 1, {"sect": "Brotherhood_of_Shinsei"})
	assert_true(AdvantageSystem.is_glory_treated_as_infamy_by(c, "Brotherhood_of_Shinsei"))


func test_glory_as_infamy_different_sect():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CAST_OUT, 1, {"sect": "Brotherhood_of_Shinsei"})
	assert_false(AdvantageSystem.is_glory_treated_as_infamy_by(c, "Kolat"))


func test_glory_as_infamy_no_cast_out():
	var c := _make_character(1)
	assert_false(AdvantageSystem.is_glory_treated_as_infamy_by(c, "Brotherhood_of_Shinsei"))


# --- is_high_skill and get_high_skill_xp_multiplier ---

func test_is_high_skill_lore():
	assert_true(AdvantageSystem.is_high_skill("Lore: Heraldry"))
	assert_true(AdvantageSystem.is_high_skill("Lore: Theology"))


func test_is_high_skill_games():
	assert_true(AdvantageSystem.is_high_skill("Games: Go"))


func test_is_high_skill_explicit_list():
	assert_true(AdvantageSystem.is_high_skill("Etiquette"))
	assert_true(AdvantageSystem.is_high_skill("Sincerity"))
	assert_true(AdvantageSystem.is_high_skill("Investigation"))


func test_is_high_skill_low_skill():
	assert_false(AdvantageSystem.is_high_skill("Athletics"))
	assert_false(AdvantageSystem.is_high_skill("Stealth"))
	assert_false(AdvantageSystem.is_high_skill("Kenjutsu"))


func test_obtuse_doubles_high_skill_xp():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.OBTUSE)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Etiquette"), 2)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Lore: Heraldry"), 2)


func test_obtuse_no_doubling_investigation_medicine():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.OBTUSE)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Investigation"), 1)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Medicine"), 1)


func test_obtuse_no_doubling_low_skills():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.OBTUSE)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Athletics"), 1)


func test_obtuse_absent_returns_1():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_high_skill_xp_multiplier(c, "Etiquette"), 1)


# --- check_sakkaku_monthly_prank ---

func test_sakkaku_prank_triggers_once_per_month():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Sakkaku"})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 7)
	assert_true(r["triggered"])
	assert_ne(r["prank"], "")


func test_sakkaku_prank_does_not_trigger_same_month():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1,
		{"realm": "Sakkaku", "last_prank_month": 7})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 7)
	assert_false(r["triggered"])


func test_sakkaku_prank_different_month_triggers_again():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1,
		{"realm": "Sakkaku", "last_prank_month": 6})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 7)
	assert_true(r["triggered"])


func test_sakkaku_prank_no_cursed_disadvantage():
	var c := _make_character(1)
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 7)
	assert_false(r["triggered"])


func test_sakkaku_prank_wrong_realm():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Meido"})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 7)
	assert_false(r["triggered"])


func test_sakkaku_prank_deterministic_same_character_month():
	var c := _make_character(42)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Sakkaku"})
	var r1: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 5)
	var r2: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 5)
	assert_eq(r1["prank"], r2["prank"])


# --- check_lingering_misfortune ---

func test_lingering_misfortune_narrow_success_triggers():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Lingering_Misfortune"})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 3, 5)
	assert_true(r["triggered"])


func test_lingering_misfortune_margin_zero_triggers():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Lingering_Misfortune"})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 0, 5)
	assert_true(r["triggered"])


func test_lingering_misfortune_wide_success_does_not_trigger():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Lingering_Misfortune"})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 5, 5)
	assert_false(r["triggered"])


func test_lingering_misfortune_failure_does_not_trigger():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Lingering_Misfortune"})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, -3, 5)
	assert_false(r["triggered"])


func test_lingering_misfortune_same_month_does_not_retrigger():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1,
		{"type": "Lingering_Misfortune", "last_misfortune_month": 5})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 2, 5)
	assert_false(r["triggered"])


func test_lingering_misfortune_wrong_type():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BAD_FORTUNE, 1, {"type": "Moto_Curse"})
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 2, 5)
	assert_false(r["triggered"])


func test_lingering_misfortune_no_disadvantage():
	var c := _make_character(1)
	var r: Dictionary = AdvantageSystem.check_lingering_misfortune(c, 2, 5)
	assert_false(r["triggered"])


# -- s45 Wiring Integration Tests (ASCETIC, BOUNTY, Sakkaku orchestrator) ------

func test_ascetic_glory_multiplier_samurai():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.ASCETIC)
	assert_almost_eq(AdvantageSystem.get_glory_multiplier(c), 0.5, 0.001,
		"samurai ASCETIC glory multiplier must be 0.5")


func test_ascetic_glory_multiplier_monk():
	var c := _make_character(1)
	c.school_type = Enums.SchoolType.MONK
	_add_disadvantage(c, Enums.Disadvantage.ASCETIC)
	assert_almost_eq(AdvantageSystem.get_glory_multiplier(c), 0.25, 0.001,
		"monk ASCETIC glory multiplier must be 0.25")


func test_no_ascetic_multiplier_is_one():
	var c := _make_character(1)
	assert_almost_eq(AdvantageSystem.get_glory_multiplier(c), 1.0, 0.001,
		"non-ASCETIC glory multiplier must be 1.0")


func test_bounty_rank1_tn_is_25():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 1)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 25)


func test_bounty_rank2_tn_is_15():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 2)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 15)


func test_bounty_rank3_tn_is_10():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BOUNTY, 3)
	assert_eq(AdvantageSystem.get_recognition_tn(c), 10)


func test_no_bounty_recognition_tn_is_minus1():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_recognition_tn(c), -1)


func test_tactician_modifier_is_5():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.TACTICIAN)
	assert_eq(AdvantageSystem.get_tactician_modifier(c), 5)


func test_no_tactician_modifier_is_0():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_tactician_modifier(c), 0)


func test_sakkaku_prank_triggered_new_month():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Sakkaku"})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 3)
	assert_true(r["triggered"])
	assert_ne(r["prank"], "", "prank name must be non-empty")


func test_sakkaku_prank_not_retriggered_same_month():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1,
		{"realm": "Sakkaku", "last_prank_month": 3})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 3)
	assert_false(r["triggered"])


func test_sakkaku_prank_fires_new_month_after_previous():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1,
		{"realm": "Sakkaku", "last_prank_month": 2})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 3)
	assert_true(r["triggered"])


func test_sakkaku_prank_deterministic_same_inputs():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Sakkaku"})
	var r1: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 5)
	# Reset metadata to allow re-trigger
	c.disadvantages[0].metadata["last_prank_month"] = -1
	var r2: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 5)
	assert_eq(r1["prank"], r2["prank"], "Same inputs must produce same prank")


func test_sakkaku_no_realm_mismatch():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Gaki_do"})
	var r: Dictionary = AdvantageSystem.check_sakkaku_monthly_prank(c, 3)
	assert_false(r["triggered"], "Non-Sakkaku realm must not trigger Sakkaku prank")


# ---------------------------------------------------------------------------
# BLIND — get_skill_bonus Perception penalty (s45)
# ---------------------------------------------------------------------------

func test_blind_penalises_perception_based_rolls():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BLIND)
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation",
		{"is_perception_based": true})
	assert_eq(r["rolled"], -1)
	assert_eq(r["kept"], -1)


func test_blind_no_penalty_when_not_perception_based():
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BLIND)
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", {})
	assert_eq(r["rolled"], 0)
	assert_eq(r["kept"], 0)


func test_blind_and_bad_eyesight_do_not_double_penalise():
	# Both carry the same -1k1 gate; stacking both deals -2k2 (each applies independently)
	var c := _make_character(1)
	_add_disadvantage(c, Enums.Disadvantage.BLIND)
	_add_disadvantage(c, Enums.Disadvantage.BAD_EYESIGHT)
	var r: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation",
		{"is_perception_based": true})
	assert_eq(r["rolled"], -2, "Both penalties stack independently")
	assert_eq(r["kept"], -2)


# ---------------------------------------------------------------------------
# STRATEGIST — query functions (s45)
# ---------------------------------------------------------------------------

func test_strategist_winning_modifier_is_2():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.STRATEGIST)
	assert_eq(AdvantageSystem.get_strategist_winning_modifier(c), 2)


func test_strategist_battle_modifier_is_1():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.STRATEGIST)
	assert_eq(AdvantageSystem.get_strategist_battle_modifier(c), 1)


func test_no_strategist_winning_modifier_is_0():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_strategist_winning_modifier(c), 0)


func test_no_strategist_battle_modifier_is_0():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_strategist_battle_modifier(c), 0)


# ---------------------------------------------------------------------------
# STUDENT_OF_SHOURIDO — get_shourido_honor_bonus (s45)
# ---------------------------------------------------------------------------

func test_shourido_returns_5_when_honor_rank_below_5():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.STUDENT_OF_SHOURIDO)
	assert_eq(AdvantageSystem.get_shourido_honor_bonus(c, 3), 5)


func test_shourido_returns_honor_rank_when_above_5():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.STUDENT_OF_SHOURIDO)
	assert_eq(AdvantageSystem.get_shourido_honor_bonus(c, 7), 7)


func test_shourido_returns_5_when_honor_rank_equals_5():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.STUDENT_OF_SHOURIDO)
	assert_eq(AdvantageSystem.get_shourido_honor_bonus(c, 5), 5)


func test_no_shourido_returns_honor_rank_unchanged():
	var c := _make_character(1)
	assert_eq(AdvantageSystem.get_shourido_honor_bonus(c, 4), 4)


# ---------------------------------------------------------------------------
# BLOOD_OF_OSANO_WO — has_weather_immunity (s45)
# ---------------------------------------------------------------------------

func test_blood_of_osano_wo_grants_weather_immunity():
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.BLOOD_OF_OSANO_WO)
	assert_true(AdvantageSystem.has_weather_immunity(c))


func test_no_blood_of_osano_wo_no_weather_immunity():
	var c := _make_character(1)
	assert_false(AdvantageSystem.has_weather_immunity(c))


# ---------------------------------------------------------------------------
# FOOL_IMPRESSION wiring — DayOrchestrator._apply_fool_impression (s45)
# ---------------------------------------------------------------------------

func _make_sakkaku_prank(effect: String, meta: Dictionary = {}) -> Dictionary:
	return {"prank": effect, "metadata": meta, "triggered": true}


func test_fool_impression_applies_disposition_penalty_to_met_character():
	var afflicted := _make_character(10)
	afflicted.clan = "Scorpion"
	var target := _make_character(20)
	target.disposition_values[10] = 0
	afflicted.met_characters.append(20)
	var chars_by_id: Dictionary = {10: afflicted, 20: target}
	DayOrchestrator._apply_fool_impression(afflicted, {"disposition_loss": -5}, 3, chars_by_id)
	assert_eq(target.disposition_values.get(10, 0), -5)


func test_fool_impression_clamps_disposition_at_minus100():
	var afflicted := _make_character(10)
	var target := _make_character(20)
	target.disposition_values[10] = -98
	afflicted.met_characters.append(20)
	var chars_by_id: Dictionary = {10: afflicted, 20: target}
	DayOrchestrator._apply_fool_impression(afflicted, {"disposition_loss": -5}, 3, chars_by_id)
	assert_eq(target.disposition_values.get(10, 0), -100)


func test_fool_impression_skips_dead_met_characters():
	var afflicted := _make_character(10)
	var dead := _make_character(20)
	dead.wounds_taken = 99
	dead.stamina = 2
	afflicted.met_characters.append(20)
	var chars_by_id: Dictionary = {10: afflicted, 20: dead}
	DayOrchestrator._apply_fool_impression(afflicted, {"disposition_loss": -5}, 3, chars_by_id)
	# Dead character should not receive disposition change
	assert_eq(dead.disposition_values.get(10, 0), 0)


func test_fool_impression_no_met_characters_does_not_crash():
	var afflicted := _make_character(10)
	var chars_by_id: Dictionary = {10: afflicted}
	# Should not crash when met_characters is empty
	DayOrchestrator._apply_fool_impression(afflicted, {"disposition_loss": -5}, 3, chars_by_id)


# ---------------------------------------------------------------------------
# WAY_OF_THE_LAND wiring — WRONG_PATH prank in known territory (s45)
# ---------------------------------------------------------------------------

func test_wrong_path_blocked_by_way_of_the_land_in_own_clan_territory():
	var c := _make_character(5)
	c.clan = "Crab"
	c.travel_days_remaining = 10
	_add_advantage(c, Enums.Advantage.WAY_OF_THE_LAND)
	var prank: Dictionary = _make_sakkaku_prank("WRONG_PATH", {"travel_extra_days": 2})
	# Character province is owned by Crab — known territory
	var char_province_map: Dictionary = {5: 1}
	var province_clan_map: Dictionary = {1: "Crab"}
	DayOrchestrator._apply_sakkaku_prank(c, prank, 3, 90, {}, char_province_map, province_clan_map)
	assert_eq(c.travel_days_remaining, 10, "WAY_OF_THE_LAND blocks WRONG_PATH in own territory")


func test_wrong_path_applies_outside_own_clan_territory():
	var c := _make_character(5)
	c.clan = "Crab"
	c.travel_days_remaining = 10
	_add_advantage(c, Enums.Advantage.WAY_OF_THE_LAND)
	var prank: Dictionary = _make_sakkaku_prank("WRONG_PATH", {"travel_extra_days": 2})
	# Character province is owned by Lion — not known territory
	var char_province_map: Dictionary = {5: 2}
	var province_clan_map: Dictionary = {2: "Lion"}
	DayOrchestrator._apply_sakkaku_prank(c, prank, 3, 90, {}, char_province_map, province_clan_map)
	assert_eq(c.travel_days_remaining, 12, "WRONG_PATH applies outside known territory")


func test_wrong_path_applies_without_way_of_the_land():
	var c := _make_character(5)
	c.clan = "Crab"
	c.travel_days_remaining = 10
	# No WAY_OF_THE_LAND advantage
	var prank: Dictionary = _make_sakkaku_prank("WRONG_PATH", {"travel_extra_days": 3})
	var char_province_map: Dictionary = {5: 1}
	var province_clan_map: Dictionary = {1: "Crab"}
	DayOrchestrator._apply_sakkaku_prank(c, prank, 3, 90, {}, char_province_map, province_clan_map)
	assert_eq(c.travel_days_remaining, 13, "WRONG_PATH applies without WAY_OF_THE_LAND even in own territory")


# ---------------------------------------------------------------------------
# PERCEIVED_HONOR wiring — honor_bonus in bribe/intimidate/extort (s45)
# ---------------------------------------------------------------------------

func test_perceived_honor_raises_effective_honor_bonus_for_bribe_witness():
	# Witness with honor 2.0 + PERCEIVED_HONOR rank 2 → effective honor 4.0 → bonus 20
	# Without PERCEIVED_HONOR: honor 2.0 → int(2.0) = 2 → bonus 10
	var witness := _make_character(20)
	witness.honor = 2.0
	_add_advantage(witness, Enums.Advantage.PERCEIVED_HONOR, 2)
	var effective: float = AdvantageSystem.get_perceived_honor(witness)
	assert_eq(effective, 4.0)
	assert_eq(int(effective) * 5, 20, "Honor bonus with PERCEIVED_HONOR rank 2 should be 20")


func test_perceived_honor_no_advantage_uses_actual_honor():
	var witness := _make_character(20)
	witness.honor = 3.5
	var effective: float = AdvantageSystem.get_perceived_honor(witness)
	assert_eq(effective, 3.5)
	assert_eq(int(effective) * 5, 15, "Honor bonus without PERCEIVED_HONOR uses actual rank")


# ---------------------------------------------------------------------------
# s45 additional query functions — batch 2
# ---------------------------------------------------------------------------

func test_has_absolute_direction_true():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ABSOLUTE_DIRECTION)
	assert_true(AdvantageSystem.has_absolute_direction(c))


func test_has_absolute_direction_false():
	var c := _make_character()
	assert_false(AdvantageSystem.has_absolute_direction(c))


func test_can_read_lips_true():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.READ_LIPS)
	assert_true(AdvantageSystem.can_read_lips(c))


func test_can_read_lips_false():
	var c := _make_character()
	assert_false(AdvantageSystem.can_read_lips(c))


func test_get_read_lips_tn_base():
	# GDD s45 line 279-281: TN 15 at 0-19 feet (0 full 20-foot increments)
	assert_eq(AdvantageSystem.get_read_lips_tn(0), 15)


func test_get_read_lips_tn_one_increment():
	# 20 feet = 1 increment → TN 15 + 5 = 20
	assert_eq(AdvantageSystem.get_read_lips_tn(20), 20)


func test_get_read_lips_tn_three_increments():
	# 60 feet = 3 increments → TN 15 + 15 = 30
	assert_eq(AdvantageSystem.get_read_lips_tn(60), 30)


func test_character_knows_language_true():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.LANGUAGES, 1, {"language": "Yobanjin"})
	assert_true(AdvantageSystem.character_knows_language(c, "Yobanjin"))


func test_character_knows_language_false_when_absent():
	var c := _make_character()
	assert_false(AdvantageSystem.character_knows_language(c, "Yobanjin"))


func test_character_knows_language_false_when_different_language():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.LANGUAGES, 1, {"language": "Naga"})
	assert_false(AdvantageSystem.character_knows_language(c, "Yobanjin"))


func test_get_known_languages_empty():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_known_languages(c).size(), 0)


func test_get_known_languages_multiple():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.LANGUAGES, 1, {"language": "Yobanjin"})
	_add_advantage(c, Enums.Advantage.LANGUAGES, 3, {"language": "Naga"})
	var langs := AdvantageSystem.get_known_languages(c)
	assert_eq(langs.size(), 2)
	assert_true("Yobanjin" in langs)
	assert_true("Naga" in langs)


func test_is_school_advancement_blocked_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.FORCED_RETIREMENT)
	assert_true(AdvantageSystem.is_school_advancement_blocked(c))


func test_is_school_advancement_blocked_false():
	var c := _make_character()
	assert_false(AdvantageSystem.is_school_advancement_blocked(c))


func test_get_obligation_tier_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_obligation_tier(c), 0)


func test_get_obligation_tier_minor():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.OBLIGATION, 1, {"tier": 3})
	assert_eq(AdvantageSystem.get_obligation_tier(c), 3)


func test_get_obligation_tier_major():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.OBLIGATION, 1, {"tier": 6})
	assert_eq(AdvantageSystem.get_obligation_tier(c), 6)


func test_get_debt_tier_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_debt_tier(c), 0)


func test_get_debt_tier_quarter_stipend():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DEBT, 1, {"tier": 1})
	assert_eq(AdvantageSystem.get_debt_tier(c), 1)


func test_get_debt_tier_exceeds_stipend():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DEBT, 1, {"tier": 3})
	assert_eq(AdvantageSystem.get_debt_tier(c), 3)


func test_has_dark_secret_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.DARK_SECRET)
	assert_true(AdvantageSystem.has_dark_secret(c))


func test_has_dark_secret_false():
	var c := _make_character()
	assert_false(AdvantageSystem.has_dark_secret(c))


func test_is_blackmailed_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.BLACKMAILED)
	assert_true(AdvantageSystem.is_blackmailed(c))


func test_is_blackmailed_false():
	var c := _make_character()
	assert_false(AdvantageSystem.is_blackmailed(c))


func test_get_blackmail_target_id_found():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.BLACKMAIL, 1, {"target_id": 42})
	assert_eq(AdvantageSystem.get_blackmail_target_id(c), 42)


func test_get_blackmail_target_id_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_blackmail_target_id(c), -1)


func test_is_void_kiho_blocked_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.UNCENTERED)
	assert_true(AdvantageSystem.is_void_kiho_blocked(c))


func test_is_void_kiho_blocked_false():
	var c := _make_character()
	assert_false(AdvantageSystem.is_void_kiho_blocked(c))


func test_can_study_multiple_schools_true():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.MULTIPLE_SCHOOLS)
	assert_true(AdvantageSystem.can_study_multiple_schools(c))


func test_can_study_multiple_schools_false():
	var c := _make_character()
	assert_false(AdvantageSystem.can_study_multiple_schools(c))


func test_get_elemental_blessing_ring_found():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ELEMENTAL_BLESSING, 1, {"ring": int(Enums.Ring.EARTH)})
	assert_eq(AdvantageSystem.get_elemental_blessing_ring(c), int(Enums.Ring.EARTH))


func test_get_elemental_blessing_ring_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_elemental_blessing_ring(c), -1)


func test_get_trait_xp_discount_elemental_blessing_matching_ring():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ELEMENTAL_BLESSING, 1, {"ring": int(Enums.Ring.EARTH)})
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.EARTH), 1)


func test_get_trait_xp_discount_elemental_blessing_non_matching_ring():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ELEMENTAL_BLESSING, 1, {"ring": int(Enums.Ring.EARTH)})
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.FIRE), 0)


func test_get_trait_xp_discount_enlightened_void():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ENLIGHTENED)
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.VOID), 2)


func test_get_trait_xp_discount_enlightened_non_void_ring():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.ENLIGHTENED)
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.AIR), 0)


func test_get_trait_xp_discount_no_advantage():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.EARTH), 0)
	assert_eq(AdvantageSystem.get_trait_xp_discount(c, Enums.Ring.VOID), 0)


func test_get_wealth_koku_bonus_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_wealth_koku_bonus(c), 0)


func test_get_wealth_koku_bonus_one_rank():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.WEALTHY)
	assert_eq(AdvantageSystem.get_wealth_koku_bonus(c), 2)


func test_get_wealth_koku_bonus_multiple_ranks():
	# 3 WEALTHY entries → 3 × 2 = 6 koku bonus
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.WEALTHY)
	_add_advantage(c, Enums.Advantage.WEALTHY)
	_add_advantage(c, Enums.Advantage.WEALTHY)
	assert_eq(AdvantageSystem.get_wealth_koku_bonus(c), 6)


func test_get_forbidden_knowledge_type_found():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Kolat"})
	assert_eq(AdvantageSystem.get_forbidden_knowledge_type(c), "Kolat")


func test_get_forbidden_knowledge_type_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_forbidden_knowledge_type(c), "")


func test_get_sworn_enemy_id_found():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"enemy_id": 77, "is_nemesis": false})
	assert_eq(AdvantageSystem.get_sworn_enemy_id(c), 77)


func test_get_sworn_enemy_id_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_sworn_enemy_id(c), -1)


func test_is_enemy_nemesis_true():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"enemy_id": 77, "is_nemesis": true})
	assert_true(AdvantageSystem.is_enemy_nemesis(c, 77))


func test_is_enemy_nemesis_false_non_nemesis():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"enemy_id": 77, "is_nemesis": false})
	assert_false(AdvantageSystem.is_enemy_nemesis(c, 77))


func test_is_enemy_nemesis_false_wrong_enemy():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.SWORN_ENEMY, 1, {"enemy_id": 77, "is_nemesis": true})
	assert_false(AdvantageSystem.is_enemy_nemesis(c, 99))


func test_get_jealousy_target_id_found():
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.JEALOUSY, 1, {"target_id": 55})
	assert_eq(AdvantageSystem.get_jealousy_target_id(c), 55)


func test_get_jealousy_target_id_none():
	var c := _make_character()
	assert_eq(AdvantageSystem.get_jealousy_target_id(c), -1)


# ---------------------------------------------------------------------------
# ELEMENTAL_BLESSING / ENLIGHTENED wired into NPCAdvancement ring cost (s45)
# ---------------------------------------------------------------------------

func test_elemental_blessing_reduces_ring_progress_cost():
	var c := _make_character()
	c.stamina = 2
	c.willpower = 2
	# Earth ring rank 2 costs RING_PROGRESS_COST[2] = 12000 normally.
	# With ELEMENTAL_BLESSING (Earth), discount = 1 XP × 200 progress = 200.
	# Effective cost = 12000 - 200 = 11800.
	_add_advantage(c, Enums.Advantage.ELEMENTAL_BLESSING, 1, {"ring": int(Enums.Ring.EARTH)})
	var result: Dictionary = NPCAdvancement._try_spend_on_ring(c, Enums.Ring.EARTH, 11800)
	assert_eq(result["spent"], 11800)
	assert_true(result["advanced"])


func test_elemental_blessing_no_discount_on_other_ring():
	var c := _make_character()
	c.reflexes = 2
	c.awareness = 2
	# Air ring rank 2 costs 12000. Blessed element is Earth, so no discount.
	_add_advantage(c, Enums.Advantage.ELEMENTAL_BLESSING, 1, {"ring": int(Enums.Ring.EARTH)})
	var result: Dictionary = NPCAdvancement._try_spend_on_ring(c, Enums.Ring.AIR, 11800)
	# 11800 < 12000, so should not advance
	assert_false(result["advanced"])


func test_enlightened_reduces_void_ring_progress_cost():
	var c := _make_character()
	c.void_ring = 2
	# Void ring rank 2 costs RING_PROGRESS_COST[2] = 12000 normally.
	# With ENLIGHTENED, discount = 2 XP × 200 progress = 400.
	# Effective cost = 12000 - 400 = 11600.
	_add_advantage(c, Enums.Advantage.ENLIGHTENED)
	var result: Dictionary = NPCAdvancement._try_spend_on_ring(c, Enums.Ring.VOID, 11600)
	assert_eq(result["spent"], 11600)
	assert_true(result["advanced"])


func test_enlightened_no_discount_on_non_void_ring():
	var c := _make_character()
	c.agility = 2
	c.intelligence = 2
	# Fire ring rank 2 costs 12000. ENLIGHTENED only helps Void.
	_add_advantage(c, Enums.Advantage.ENLIGHTENED)
	var result: Dictionary = NPCAdvancement._try_spend_on_ring(c, Enums.Ring.FIRE, 11600)
	assert_false(result["advanced"])
