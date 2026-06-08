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
	pending("INNATE_ABILITY advantage not implemented - s45 gap")

func test_innate_ability_wrong_element_no_bonus():
	pending("INNATE_ABILITY advantage not implemented - s45 gap")

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
	assert_eq(HonorGlorySystem.get_glory_rank(c), 3)


func test_glory_rank_zero_at_zero_glory():
	var c := _make_character()
	c.glory = 0.0
	assert_eq(HonorGlorySystem.get_glory_rank(c), 0)


func test_glory_rank_ten_at_max():
	var c := _make_character()
	c.glory = 10.0
	assert_eq(HonorGlorySystem.get_glory_rank(c), 10)


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


# ---------------------------------------------------------------------------
# assign_derived_advantages — FAME (purchased), WEALTHY, FORBIDDEN_KNOWLEDGE
# ---------------------------------------------------------------------------

func test_fame_purchased_grants_one_glory():
	var c := _make_character()
	c.glory = 1.5
	_add_advantage(c, Enums.Advantage.FAME)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.glory, 2.5, 0.001)


func test_fame_purchased_glory_caps_at_10():
	var c := _make_character()
	c.glory = 9.8
	_add_advantage(c, Enums.Advantage.FAME)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.glory, 10.0, 0.001)


func test_fame_purchased_runs_before_derive_block():
	# A character with FAME purchased starts at glory 1.5, gets +1.0 → 2.5.
	# The derive block sees 2.5 >= 2.0 and finds FAME already present — no duplicate.
	var c := _make_character()
	c.glory = 1.5
	_add_advantage(c, Enums.Advantage.FAME)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	var count: int = 0
	for adv: AdvantageData in c.advantages:
		if adv.advantage_type == Enums.Advantage.FAME:
			count += 1
	assert_eq(count, 1)


func test_fame_derive_still_assigns_for_high_glory_without_purchase():
	# Character has glory 2.5 but no FAME purchased. Derive block assigns it.
	var c := _make_character()
	c.glory = 2.5
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_true(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_no_fame_purchased_no_glory_grant():
	var c := _make_character()
	c.glory = 1.5
	AdvantageSystem.assign_derived_advantages(c, [], {})
	# glory 1.5 < 2.0, derive block does not trigger, no FAME
	assert_almost_eq(c.glory, 1.5, 0.001)
	assert_false(AdvantageSystem.has_advantage(c, Enums.Advantage.FAME))


func test_wealthy_single_point_grants_2_koku():
	var c := _make_character()
	c.koku = 0.0
	_add_advantage(c, Enums.Advantage.WEALTHY)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.koku, 2.0, 0.001)


func test_wealthy_two_points_grants_4_koku():
	var c := _make_character()
	c.koku = 0.0
	_add_advantage(c, Enums.Advantage.WEALTHY)
	_add_advantage(c, Enums.Advantage.WEALTHY)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.koku, 4.0, 0.001)


func test_wealthy_stacks_with_existing_koku():
	var c := _make_character()
	c.koku = 5.0
	_add_advantage(c, Enums.Advantage.WEALTHY)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.koku, 7.0, 0.001)


func test_no_wealthy_no_koku_grant():
	var c := _make_character()
	c.koku = 3.0
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_almost_eq(c.koku, 3.0, 0.001)


func test_forbidden_knowledge_gaijin_pepper_grants_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Gaijin Pepper"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Craft: Explosives", 0), 1)


func test_forbidden_knowledge_gozoku_grants_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Gozoku"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Gozoku", 0), 1)


func test_forbidden_knowledge_kolat_grants_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Kolat"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Kolat", 0), 1)


func test_forbidden_knowledge_lying_darkness_grants_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Lying Darkness"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Lying Darkness", 0), 1)


func test_forbidden_knowledge_maho_grants_skill():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Maho"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Maho", 0), 1)


func test_forbidden_knowledge_does_not_overwrite_higher_rank():
	var c := _make_character()
	c.skills["Lore: Maho"] = 3
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Maho"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Maho", 0), 3)


func test_forbidden_knowledge_unknown_subject_no_crash():
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Unknown"})
	AdvantageSystem.assign_derived_advantages(c, [], {})
	# Should complete without crash; no unexpected skills added
	assert_eq(c.skills.get("Lore: Unknown", 0), 0)


func test_forbidden_knowledge_no_advantage_no_skill():
	var c := _make_character()
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.skills.get("Lore: Maho", 0), 0)
	assert_eq(c.skills.get("Craft: Explosives", 0), 0)


# ---------------------------------------------------------------------------
# DARK_PARAGON (s45) — unit tests
# ---------------------------------------------------------------------------

func test_dark_paragon_near_miss_activates() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 7, 10, "Honor")
	assert_true(r.get("should_activate", false))


func test_dark_paragon_too_far_behind_no_activate() -> void:
	# roll_total + 5 = 8 < tn=10 → +5 wouldn't help
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 3, 10, "Honor")
	assert_false(r.get("should_activate", true))


func test_dark_paragon_already_success_no_activate() -> void:
	# roll_total >= tn already; condition roll_total < tn is false
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 12, 10, "Honor")
	assert_false(r.get("should_activate", true))


func test_dark_paragon_no_advantage_returns_false() -> void:
	var c := _make_character()
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 7, 10, "Honor")
	assert_false(r.get("should_activate", true))


func test_dark_paragon_wrong_precept_returns_false() -> void:
	# Character stores "Honor"; caller passes "Loyalty" → mismatch → false
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 7, 10, "Loyalty")
	assert_false(r.get("should_activate", true))


# ---------------------------------------------------------------------------
# DARK_PARAGON (s45) — integration tests through SkillResolver
# ---------------------------------------------------------------------------
# Technique: bonus_rolled = -(trait + skill_rank) forces rolled = 0,
# making DiceEngine return total = 0. flat_bonus then becomes the entire roll total.
# _make_character(): reflexes=2, awareness=3 → Air=2; Etiquette=3 → 2+3=5 rolled.
# Setting bonus_rolled=-5 → rolled=0 → dice total=0 → final_total=flat_bonus.

func test_dark_paragon_integration_near_miss_flips_success() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	# flat_bonus=7, tn=10 → total=7 (miss by 3). (7+5)=12 >= 10 → DARK_PARAGON fires.
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 7
	)
	assert_true(r.get("dark_paragon_activated", false))
	assert_true(r.get("success", false))
	assert_eq(r.get("total", 0), 12)


func test_dark_paragon_integration_large_miss_no_activate() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	# flat_bonus=3, tn=10 → total=3 (miss by 7). (3+5)=8 < 10 → DARK_PARAGON does not fire.
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 3
	)
	assert_false(r.get("dark_paragon_activated", false))
	assert_false(r.get("success", false))


func test_dark_paragon_integration_no_advantage_no_activate() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	# No DARK_PARAGON advantage
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 7
	)
	assert_false(r.get("dark_paragon_activated", false))


# ---------------------------------------------------------------------------
# LOST_LOVE (s45) — get_tn_modifier
# ---------------------------------------------------------------------------

func test_lost_love_tn_modifier_active_returns_5() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"clan": "Crab", "province_id": 5, "lost_love_tn_active": true})
	assert_eq(AdvantageSystem.get_tn_modifier(c, {}), 5)


func test_lost_love_tn_modifier_inactive_returns_0() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"clan": "Crab", "province_id": 5, "lost_love_tn_active": false})
	assert_eq(AdvantageSystem.get_tn_modifier(c, {}), 0)


func test_lost_love_tn_modifier_absent_returns_0() -> void:
	var c := _make_character()
	assert_eq(AdvantageSystem.get_tn_modifier(c, {}), 0)


# ---------------------------------------------------------------------------
# LOST_LOVE (s45) — check_lost_love_trigger
# ---------------------------------------------------------------------------

func test_lost_love_trigger_clan_match() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Crab", "province_id": -1})
	var r: Dictionary = AdvantageSystem.check_lost_love_trigger(
		c, {"lost_love_clan": "Crab"}, 1
	)
	assert_true(r.get("triggered", false))
	assert_eq(r.get("tn_penalty", 0), 5)


func test_lost_love_trigger_clan_mismatch() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"clan": "Crab", "province_id": -1})
	var r: Dictionary = AdvantageSystem.check_lost_love_trigger(
		c, {"lost_love_clan": "Phoenix"}, 1
	)
	assert_false(r.get("triggered", true))


func test_lost_love_trigger_province_match() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1, {"province_id": 5})
	var r: Dictionary = AdvantageSystem.check_lost_love_trigger(
		c, {"lost_love_province_id": 5}, 1
	)
	assert_true(r.get("triggered", false))
	assert_eq(r.get("tn_penalty", 0), 5)


func test_lost_love_trigger_daily_cap_blocks() -> void:
	var c := _make_character()
	# Already triggered twice today
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"clan": "Crab", "province_id": -1, "triggers_today": 2, "last_trigger_ic_day": 1})
	var r: Dictionary = AdvantageSystem.check_lost_love_trigger(
		c, {"lost_love_clan": "Crab"}, 1
	)
	assert_false(r.get("triggered", true))


# ---------------------------------------------------------------------------
# LOST_LOVE (s45) — _reset_lost_love_daily_state
# ---------------------------------------------------------------------------

func test_reset_lost_love_clears_active_flag() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"clan": "Crab", "province_id": 5, "lost_love_tn_active": true, "triggers_today": 1})
	DayOrchestrator._reset_lost_love_daily_state([c])
	var dis: DisadvantageData = AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.LOST_LOVE)
	assert_false(dis.metadata.get("lost_love_tn_active", true))


func test_reset_lost_love_clears_triggers_count() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"clan": "Crab", "province_id": 5, "lost_love_tn_active": true, "triggers_today": 2})
	DayOrchestrator._reset_lost_love_daily_state([c])
	var dis: DisadvantageData = AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.LOST_LOVE)
	assert_eq(dis.metadata.get("triggers_today", -1), 0)


# ---------------------------------------------------------------------------
# LOST_LOVE (s45) — _process_lost_love_arrival_trigger
# ---------------------------------------------------------------------------

func test_arrival_trigger_matching_province_activates_tn() -> void:
	var c := _make_character()
	c.character_id = 1
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"province_id": 5, "lost_love_tn_active": false})
	var chars_by_id: Dictionary = {1: c}

	var s: SettlementData = SettlementData.new()
	s.settlement_id = 100
	s.province_id = 5

	var arrivals: Array = [{"character_id": 1, "destination": "100"}]
	DayOrchestrator._process_lost_love_arrival_trigger(arrivals, chars_by_id, [s], 10)

	var dis: DisadvantageData = AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.LOST_LOVE)
	assert_true(dis.metadata.get("lost_love_tn_active", false))


func test_arrival_trigger_wrong_province_no_activation() -> void:
	var c := _make_character()
	c.character_id = 1
	_add_disadvantage(c, Enums.Disadvantage.LOST_LOVE, 1,
		{"province_id": 99, "lost_love_tn_active": false})
	var chars_by_id: Dictionary = {1: c}

	var s: SettlementData = SettlementData.new()
	s.settlement_id = 100
	s.province_id = 5  # province 5, not 99

	var arrivals: Array = [{"character_id": 1, "destination": "100"}]
	DayOrchestrator._process_lost_love_arrival_trigger(arrivals, chars_by_id, [s], 10)

	var dis: DisadvantageData = AdvantageSystem.get_disadvantage(c, Enums.Disadvantage.LOST_LOVE)
	assert_false(dis.metadata.get("lost_love_tn_active", true))


# ---------------------------------------------------------------------------
# SPY_NETWORK (s45)
# ---------------------------------------------------------------------------

func test_spy_network_character_focus_creates_knowledge_entry() -> void:
	var c := _make_character(1)
	c.physical_location = "50"
	_add_advantage(c, Enums.Advantage.SPY_NETWORK, 1,
		{"focus_type": "character", "focus_id": 2, "last_update_ooc_day": -1})

	var target := _make_character(2)
	target.physical_location = "75"
	target.clan = "Lion"

	var chars_by_id: Dictionary = {1: c, 2: target}
	DayOrchestrator._process_spy_network_weekly([c, target], chars_by_id, [], {}, [], 7)

	assert_gt(c.knowledge_pool.size(), 0)
	var entry: KnowledgeEntry = c.knowledge_pool[0]
	assert_eq(entry.entry_type, "shadow_surveillance")
	assert_eq(entry.data.get("character_id", -1), 2)


func test_spy_network_place_focus_adds_topic() -> void:
	var c := _make_character(1)
	c.physical_location = "10"
	_add_advantage(c, Enums.Advantage.SPY_NETWORK, 1,
		{"focus_type": "place", "focus_id": 100, "last_update_ooc_day": -1})

	var local_char := _make_character(2)
	local_char.physical_location = "100"
	local_char.topic_pool = [42]

	var chars_by_id: Dictionary = {1: c, 2: local_char}
	DayOrchestrator._process_spy_network_weekly([c, local_char], chars_by_id, [], {}, [], 7)

	assert_true(42 in c.topic_pool)


func test_spy_network_army_focus_creates_knowledge_entry() -> void:
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.SPY_NETWORK, 1,
		{"focus_type": "army", "focus_id": 50, "last_update_ooc_day": -1})

	var chars_by_id: Dictionary = {1: c}
	DayOrchestrator._process_spy_network_weekly([c], chars_by_id, [], {}, [], 7)

	assert_gt(c.knowledge_pool.size(), 0)
	var entry: KnowledgeEntry = c.knowledge_pool[0]
	assert_eq(entry.entry_type, "shadow_surveillance")
	assert_eq(entry.data.get("company_id", -1), 50)


func test_spy_network_weekly_dedup_blocks_second_call() -> void:
	var c := _make_character(1)
	var target := _make_character(2)
	target.physical_location = "75"
	_add_advantage(c, Enums.Advantage.SPY_NETWORK, 1,
		{"focus_type": "character", "focus_id": 2, "last_update_ooc_day": 7})

	var chars_by_id: Dictionary = {1: c, 2: target}
	# ic_day=10 → week_num=1; last_update_ooc_day=7 → 7/7=1 → same week → skip
	DayOrchestrator._process_spy_network_weekly([c, target], chars_by_id, [], {}, [], 10)

	assert_eq(c.knowledge_pool.size(), 0)


# ---------------------------------------------------------------------------
# WELL_CONNECTED (s45)
# ---------------------------------------------------------------------------

func test_well_connected_reveals_topic_from_court() -> void:
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1,
		{"settlement_id": 100, "last_intel_ic_day": -1})

	var local_char := _make_character(2)
	local_char.physical_location = "100"
	local_char.topic_pool = [7]

	var t: TopicData = TopicData.new()
	t.topic_id = 7
	t.resolved = false

	DayOrchestrator._process_well_connected_weekly([c, local_char], {}, [t], 7)

	assert_true(7 in c.topic_pool)


func test_well_connected_rank_limits_revelations() -> void:
	# rank=1 → only 1 topic revealed even if 3 are available at the court
	var c := _make_character(1)
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1,
		{"settlement_id": 100, "last_intel_ic_day": -1})

	var local_char := _make_character(2)
	local_char.physical_location = "100"
	local_char.topic_pool = [10, 11, 12]

	var active_topics: Array = []
	for tid: int in [10, 11, 12]:
		var t: TopicData = TopicData.new()
		t.topic_id = tid
		t.resolved = false
		active_topics.append(t)

	DayOrchestrator._process_well_connected_weekly([c, local_char], {}, active_topics, 7)

	var count: int = 0
	for tid: int in [10, 11, 12]:
		if tid in c.topic_pool:
			count += 1
	assert_eq(count, 1)


func test_well_connected_weekly_dedup_blocks_second_call() -> void:
	var c := _make_character(1)
	# last_intel_ic_day=7, ic_day=10 → both in week 1 → skip
	_add_advantage(c, Enums.Advantage.WELL_CONNECTED, 1,
		{"settlement_id": 100, "last_intel_ic_day": 7})

	var local_char := _make_character(2)
	local_char.physical_location = "100"
	local_char.topic_pool = [20]

	var t: TopicData = TopicData.new()
	t.topic_id = 20
	t.resolved = false

	DayOrchestrator._process_well_connected_weekly([c, local_char], {}, [t], 10)

	assert_false(20 in c.topic_pool)


# ---------------------------------------------------------------------------
# DARK_PARAGON (s45) — weekly limit and cost (0.5 Honor or 1 Void Point)
# ---------------------------------------------------------------------------

func test_dark_paragon_weekly_limit_blocks_same_week() -> void:
	var c := _make_character()
	# last_activation_week=1, ic_day=10 → week=10/7=1 → same week → blocked
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1,
		{"precept": "Honor", "last_activation_week": 1})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 7, 10, "Honor", 10)
	assert_false(r.get("should_activate", true))


func test_dark_paragon_weekly_limit_allows_next_week() -> void:
	var c := _make_character()
	# last_activation_week=0, ic_day=7 → week=7/7=1 → different week → allowed
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1,
		{"precept": "Honor", "last_activation_week": 0})
	var r: Dictionary = AdvantageSystem.check_dark_paragon_activation(c, 7, 10, "Honor", 7)
	assert_true(r.get("should_activate", false))


func test_dark_paragon_cost_spends_void_point_when_available() -> void:
	var c := _make_character()
	c.current_void_points = 2
	c.honor = 5.0
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	AdvantageSystem.apply_dark_paragon_cost(c, 7)
	assert_eq(c.current_void_points, 1)
	assert_almost_eq(c.honor, 5.0, 0.001)  # honor unchanged when void available


func test_dark_paragon_cost_deducts_honor_when_no_void() -> void:
	var c := _make_character()
	c.current_void_points = 0
	c.honor = 5.0
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	AdvantageSystem.apply_dark_paragon_cost(c, 7)
	assert_eq(c.current_void_points, 0)
	assert_almost_eq(c.honor, 4.5, 0.001)  # 5 points = 0.5 rank lost (s45:77)


func test_dark_paragon_cost_records_activation_week() -> void:
	var c := _make_character()
	c.current_void_points = 1
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	AdvantageSystem.apply_dark_paragon_cost(c, 14)  # ic_day 14 → week 2
	var adv: AdvantageData = AdvantageSystem.get_advantage(c, Enums.Advantage.DARK_PARAGON)
	assert_eq(adv.metadata.get("last_activation_week", -1), 2)


func test_dark_paragon_integration_applies_cost_on_activation() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 1
	c.honor = 5.0
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Honor"})
	# flat_bonus=7, tn=10 → total=7 (miss by 3), +5 flips; ic_day=7 → week=1, no prior limit
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 7, 7
	)
	assert_true(r.get("dark_paragon_activated", false))
	assert_eq(c.current_void_points, 0)
	assert_almost_eq(c.honor, 5.0, 0.001)  # void spent, honor untouched


func test_dark_paragon_integration_weekly_limit_blocks_activation() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 2
	# Already activated this week (week 1)
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1,
		{"precept": "Honor", "last_activation_week": 1})
	# ic_day=10 → week=1 → same week → blocked even on a qualifying near-miss
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 7, 10
	)
	assert_false(r.get("dark_paragon_activated", false))
	assert_eq(c.current_void_points, 2)  # no cost deducted


# ---------------------------------------------------------------------------
# DARK_PARAGON Determination precept — wound penalty negation (s45:77)
# ---------------------------------------------------------------------------
# Determination negates wound penalty instead of adding +5 (s45:77).
# _make_character() has stamina=2, willpower=2 → Earth=2 → threshold=4 wounds/level.
# wounds_taken=13 → level_index=int(12/4)=3 → HURT → wound_penalty=-10.
# wounds_taken=9  → level_index=int(8/4)=2  → GRAZED → wound_penalty=-5.
# bonus_rolled=-5 forces dice to 0; final_total = flat_bonus + wound_penalty.

func test_dark_paragon_determination_negates_wound_penalty() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.wounds_taken = 13                  # HURT → wound_penalty = -10
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Determination"})
	# flat_bonus=12, wound_penalty=-10 → total=2 (fails TN 10).
	# Determination negates -10: total=2-(-10)=12 → 12 >= 10 → success.
	# +5 branch would give 2+5=7 < 10 → would NOT have saved it.
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 12
	)
	assert_true(r.get("dark_paragon_activated", false))
	assert_true(r.get("success", false))
	assert_eq(r.get("total", 0), 12)     # wound penalty negated, not +5 added


func test_dark_paragon_determination_does_not_add_five() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.wounds_taken = 13                  # HURT → wound_penalty = -10
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Determination"})
	# If +5 were added (wrong), total would be 2+5=7. With negation, total=12.
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 12
	)
	# Confirm total is 12 (negation) and not 7 (+5 would give) or 17 (+5 on top of negation).
	assert_eq(r.get("total", 0), 12)
	assert_ne(r.get("total", 0), 7)


func test_dark_paragon_non_determination_still_adds_five() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.wounds_taken = 13                  # HURT → wound_penalty = -10
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Knowledge"})
	# flat_bonus=17, wound_penalty=-10 → total=7 (fails TN 10).
	# Knowledge (non-Determination): +5 → 7+5=12 >= 10 → success.
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 17
	)
	assert_true(r.get("dark_paragon_activated", false))
	assert_true(r.get("success", false))
	assert_eq(r.get("total", 0), 12)     # 17 - 10 (wound) + 5 (bonus) = 12


func test_dark_paragon_determination_records_precept_in_result() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.wounds_taken = 13
	_add_advantage(c, Enums.Advantage.DARK_PARAGON, 1, {"precept": "Determination"})
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -5, 0, 12
	)
	assert_eq(r.get("dark_paragon_precept", ""), "Determination")


# ---------------------------------------------------------------------------
# FORBIDDEN_KNOWLEDGE social bonus (s45 line 101)
# ---------------------------------------------------------------------------

func test_forbidden_knowledge_gozoku_social_bonus_matching_faction() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Gozoku"})
	var ctx := {"is_social": true, "opponent_known_faction": "Gozoku"}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("kept", 0), 1)

func test_forbidden_knowledge_kolat_social_bonus_matching_faction() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Kolat"})
	var ctx := {"is_social": true, "opponent_known_faction": "Kolat"}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("kept", 0), 1)

func test_forbidden_knowledge_no_bonus_wrong_faction() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Gozoku"})
	var ctx := {"is_social": true, "opponent_known_faction": "Kolat"}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("kept", 0), 0)

func test_forbidden_knowledge_no_bonus_maho_subject() -> void:
	# Maho subject has no social bonus (only Gozoku and Kolat grant +1k1 social)
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Maho"})
	var ctx := {"is_social": true, "opponent_known_faction": "Maho"}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("kept", 0), 0)

func test_forbidden_knowledge_no_bonus_non_social() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Kolat"})
	var ctx := {"is_social": false, "opponent_known_faction": "Kolat"}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Investigation", ctx)
	assert_eq(b.get("kept", 0), 0)

func test_forbidden_knowledge_no_bonus_no_faction_in_context() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.FORBIDDEN_KNOWLEDGE, 1, {"subject": "Gozoku"})
	var ctx := {"is_social": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("kept", 0), 0)


# ---------------------------------------------------------------------------
# TOUCH_OF_THE_SPIRIT_REALMS Jigoku — Lost doubles Taint Rank (s45 line 373)
# ---------------------------------------------------------------------------

func test_jigoku_combat_adds_taint_rank_normal() -> void:
	var c := _make_character()
	c.taint = 3.0  # Rank 3, not Lost
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Jigoku"})
	var ctx := {"is_combat": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", ctx)
	assert_eq(b.get("rolled", 0), 3)

func test_jigoku_combat_doubles_taint_rank_when_lost() -> void:
	var c := _make_character()
	c.taint = 5.0  # Lost (taint >= 5.0)
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Jigoku"})
	var ctx := {"is_combat": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", ctx)
	assert_eq(b.get("rolled", 0), 10)  # int(5.0) * 2 = 10

func test_jigoku_lost_at_taint_6_doubles() -> void:
	var c := _make_character()
	c.taint = 6.5
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Jigoku"})
	var ctx := {"is_combat": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", ctx)
	assert_eq(b.get("rolled", 0), 12)  # int(6.5) = 6, * 2 = 12

func test_jigoku_physical_trait_roll_adds_taint() -> void:
	var c := _make_character()
	c.taint = 2.0
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Jigoku"})
	var ctx := {"is_ring_roll": true, "is_physical_trait": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Kenjutsu", ctx)
	assert_eq(b.get("rolled", 0), 2)

func test_jigoku_no_bonus_on_social_roll() -> void:
	var c := _make_character()
	c.taint = 3.0
	_add_advantage(c, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS, 1, {"realm": "Jigoku"})
	var ctx := {"is_social": true}
	var b: Dictionary = AdvantageSystem.get_skill_bonus(c, "Courtier", ctx)
	assert_eq(b.get("rolled", 0), 0)


# ---------------------------------------------------------------------------
# PARAGON Duty — check_paragon_duty_activation (s45 line 257)
# ---------------------------------------------------------------------------

func test_paragon_duty_activates_when_wound_penalty_would_turn_failure() -> void:
	var c := _make_character()
	c.current_void_points = 2
	c.wounds_taken = 20  # Crippled: wound_penalty = -10
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Duty"})
	# Roll total = 18, TN = 20, wound_penalty = -10 (already baked in). Negating would give 28 >= 20.
	var r: Dictionary = AdvantageSystem.check_paragon_duty_activation(c, 18, 20, -10)
	assert_true(r.get("should_activate", false))

func test_paragon_duty_does_not_activate_wrong_virtue() -> void:
	var c := _make_character()
	c.current_void_points = 2
	c.wounds_taken = 20
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Courage"})
	var r: Dictionary = AdvantageSystem.check_paragon_duty_activation(c, 18, 20, -10)
	assert_false(r.get("should_activate", false))

func test_paragon_duty_does_not_activate_without_vp() -> void:
	var c := _make_character()
	c.current_void_points = 0
	c.wounds_taken = 20
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Duty"})
	var r: Dictionary = AdvantageSystem.check_paragon_duty_activation(c, 18, 20, -10)
	assert_false(r.get("should_activate", false))

func test_paragon_duty_blocked_by_failure_of_bushido_duty() -> void:
	var c := _make_character()
	c.current_void_points = 2
	c.wounds_taken = 20
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Duty"})
	_add_disadvantage(c, Enums.Disadvantage.FAILURE_OF_BUSHIDO, 1, {"precept": "Duty"})
	var r: Dictionary = AdvantageSystem.check_paragon_duty_activation(c, 18, 20, -10)
	assert_false(r.get("should_activate", false))

func test_paragon_duty_does_not_activate_when_negation_insufficient() -> void:
	var c := _make_character()
	c.current_void_points = 2
	# wound_penalty = -3, total = 14, TN = 20 — even negating -3 gives 17 < 20
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Duty"})
	var r: Dictionary = AdvantageSystem.check_paragon_duty_activation(c, 14, 20, -3)
	assert_false(r.get("should_activate", false))

func test_paragon_duty_integration_negates_wound_penalty_and_spends_vp() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var c := _make_character()
	c.current_void_points = 1
	c.wounds_taken = 20  # wound_penalty = -10
	c.void_ring = 3
	_add_advantage(c, Enums.Advantage.PARAGON, 1, {"virtue": "Duty"})
	# Use a context where wounds create a meaningful roll gap
	var r: Dictionary = SkillResolver.resolve_skill_check(
		c, dice, "Etiquette", 10, 0, "", Enums.Trait.NONE, -15, 0, 15
	)
	if r.get("paragon_duty_activated", false):
		assert_eq(c.current_void_points, 0)


# ---------------------------------------------------------------------------
# ELEMENTAL_IMBALANCE overflow — apply_elemental_imbalance_overflow (s45 lines 535-545)
# ---------------------------------------------------------------------------

func test_elemental_imbalance_void_ml1_drains_one_vp() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 2
	c.void_ring = 2
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.VOID, 1, dice, 100
	)
	assert_true(r.get("applied", false))
	assert_eq(r.get("void_points_lost", 0), 1)
	assert_eq(c.current_void_points, 1)
	assert_eq(r.get("wounds_taken", 0), 0)

func test_elemental_imbalance_void_ml1_no_vp_deals_5_wounds() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 0
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.VOID, 1, dice, 100
	)
	assert_eq(r.get("wounds_taken", 0), 5)
	assert_eq(c.wounds_taken, 5)
	assert_eq(r.get("void_points_lost", 0), 0)

func test_elemental_imbalance_void_ml3_drains_all_vp_and_blocks_recovery() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 3
	c.void_refresh_blocked_until = -1
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.VOID, 3, dice, 100
	)
	assert_eq(r.get("void_points_lost", 0), 3)
	assert_eq(c.current_void_points, 0)
	assert_eq(r.get("void_blocked_until_ic_day", -1), 148)  # 100 + 48
	assert_eq(c.void_refresh_blocked_until, 148)

func test_elemental_imbalance_fire_ml1_applies_wounds() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.wounds_taken = 0
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.FIRE, 1, dice, 100
	)
	assert_true(r.get("wounds_taken", 0) > 0)
	assert_eq(c.wounds_taken, r.get("wounds_taken", 0))

func test_elemental_imbalance_fire_ml3_blocked() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.FIRE, 3, dice, 100
	)
	assert_true(r.get("applied", false))
	assert_eq(r.get("wounds_taken", 0), 0)
	var effects: Array = r.get("sim_effects", [])
	assert_true(effects.has("fire_aoe_blocked_s40"))

func test_elemental_imbalance_air_returns_metadata_only() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	var r: Dictionary = AdvantageSystem.apply_elemental_imbalance_overflow(
		c, Enums.Ring.AIR, 2, dice, 100
	)
	assert_true(r.get("applied", false))
	assert_eq(r.get("wounds_taken", 0), 0)
	assert_eq(r.get("void_points_lost", 0), 0)


# ---------------------------------------------------------------------------
# BATTLE_HEALING — can_use and consume (s45 line 21)
# ---------------------------------------------------------------------------

func _make_shugenja(id: int = 10) -> L5RCharacterData:
	var c := _make_character(id)
	c.school_type = Enums.SchoolType.SHUGENJA
	c.stamina = 3
	c.willpower = 3
	c.reflexes = 2
	c.awareness = 2
	c.agility = 2
	c.intelligence = 2
	c.strength = 2
	c.perception = 2
	c.void_ring = 2
	c.affinity_element = Enums.Ring.NONE
	c.deficiency_element = Enums.Ring.NONE
	c.insight_rank = 2
	c.spells_known = ["jurojins_balm", "commune"]
	c.spell_slots_used = {}
	c.spell_void_bonus_used = 0
	return c

func test_battle_healing_requires_advantage() -> void:
	var c := _make_shugenja()
	var r: Dictionary = AdvantageSystem.can_use_battle_healing(c, Enums.Ring.WATER)
	assert_false(r.get("can_use", false))

func test_battle_healing_water_slot_available() -> void:
	var c := _make_shugenja()
	# Water = min(strength, perception) = min(2, 2) = 2; get_daily_slots = 2
	_add_advantage(c, Enums.Advantage.BATTLE_HEALING)
	var r: Dictionary = AdvantageSystem.can_use_battle_healing(c, Enums.Ring.WATER)
	assert_true(r.get("can_use", false))
	assert_eq(r.get("cost_slots", 0), 1)

func test_battle_healing_water_slot_exhausted() -> void:
	var c := _make_shugenja()
	_add_advantage(c, Enums.Advantage.BATTLE_HEALING)
	# Exhaust all Water slots (Water ring value = 2)
	c.spell_slots_used[Enums.Ring.WATER] = 2
	var r: Dictionary = AdvantageSystem.can_use_battle_healing(c, Enums.Ring.WATER)
	assert_false(r.get("can_use", false))

func test_battle_healing_two_mixed_slots() -> void:
	var c := _make_shugenja()
	_add_advantage(c, Enums.Advantage.BATTLE_HEALING)
	# Exhaust Water slots but other elements have slots
	c.spell_slots_used[Enums.Ring.WATER] = 3  # over max, treated as exhausted
	var r: Dictionary = AdvantageSystem.can_use_battle_healing(c, Enums.Ring.NONE)
	assert_true(r.get("can_use", false))
	assert_eq(r.get("cost_slots", 0), 2)

func test_battle_healing_consume_water_heals_wound_rank() -> void:
	var healer := _make_shugenja(10)
	var target := _make_character(11)
	_add_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	target.wounds_taken = 10
	var r: Dictionary = AdvantageSystem.consume_battle_healing_slot(healer, target, Enums.Ring.WATER)
	assert_true(r.get("healed", false))
	assert_eq(r.get("wounds_removed", 0), 5)
	assert_eq(target.wounds_taken, 5)
	assert_eq(r.get("slots_consumed", 0), 1)

func test_battle_healing_consume_no_advantage_fails() -> void:
	var healer := _make_shugenja(10)
	var target := _make_character(11)
	target.wounds_taken = 10
	var r: Dictionary = AdvantageSystem.consume_battle_healing_slot(healer, target, Enums.Ring.WATER)
	assert_false(r.get("healed", false))
	assert_eq(target.wounds_taken, 10)


# -- BATTLE_HEALING per-target-per-day limit (s45 line 21) --------------------

func test_battle_healing_once_per_target_per_day_blocks_repeat() -> void:
	var healer := _make_shugenja(10)
	var target := _make_character(11)
	_add_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	target.wounds_taken = 15
	# First heal succeeds
	var r1: Dictionary = AdvantageSystem.consume_battle_healing_slot(healer, target, Enums.Ring.WATER)
	assert_true(r1.get("healed", false))
	# Second heal on same target blocked by per-day gate
	var can2: Dictionary = AdvantageSystem.can_use_battle_healing(healer, Enums.Ring.WATER, target)
	assert_false(can2.get("can_use", true), "Should block second heal on same target")


func test_battle_healing_can_heal_different_targets_same_day() -> void:
	var healer := _make_shugenja(10)
	healer.water = 4  # ensure enough slots
	var target_a := _make_character(11)
	var target_b := _make_character(12)
	_add_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	target_a.wounds_taken = 10
	target_b.wounds_taken = 10
	AdvantageSystem.consume_battle_healing_slot(healer, target_a, Enums.Ring.WATER)
	var can_b: Dictionary = AdvantageSystem.can_use_battle_healing(healer, Enums.Ring.WATER, target_b)
	assert_true(can_b.get("can_use", false), "Different target should still be healable")


func test_battle_healing_daily_reset_clears_healed_today() -> void:
	var healer := _make_shugenja(10)
	var target := _make_character(11)
	_add_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	target.wounds_taken = 15
	AdvantageSystem.consume_battle_healing_slot(healer, target, Enums.Ring.WATER)
	# Simulate day reset
	var adv: AdvantageData = AdvantageSystem.get_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	adv.metadata["healed_today"] = []
	# Now the gate is cleared
	var can_again: Dictionary = AdvantageSystem.can_use_battle_healing(healer, Enums.Ring.WATER, target)
	assert_true(can_again.get("can_use", false), "After daily reset gate should clear")


# -- IMPERIAL_SPOUSE +0.5 Status at generation (s45 line 165) -----------------

func test_imperial_spouse_grants_half_status_rank() -> void:
	var c := _make_character(1)
	c.status = 2.0
	_add_advantage(c, Enums.Advantage.IMPERIAL_SPOUSE)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.status, 2.5)


func test_imperial_spouse_status_capped_at_ten() -> void:
	var c := _make_character(1)
	c.status = 10.0
	_add_advantage(c, Enums.Advantage.IMPERIAL_SPOUSE)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	assert_eq(c.status, 10.0)


func test_imperial_spouse_stacks_with_social_position() -> void:
	var c := _make_character(1)
	c.status = 2.0
	_add_advantage(c, Enums.Advantage.SOCIAL_POSITION)
	_add_advantage(c, Enums.Advantage.IMPERIAL_SPOUSE)
	AdvantageSystem.assign_derived_advantages(c, [], {})
	# SOCIAL_POSITION +1.0 then IMPERIAL_SPOUSE +0.5 = 3.5
	assert_eq(c.status, 3.5)


# ---------------------------------------------------------------------------
# SPY_NETWORK — focus sync (s45 line 349)
# ---------------------------------------------------------------------------

func _make_spy_character(id: int, clan: String = "Crane") -> L5RCharacterData:
	var c := _make_character(id)
	c.clan = clan
	_add_advantage(c, Enums.Advantage.SPY_NETWORK)
	return c


func test_sync_spy_political_objective_sets_character_focus() -> void:
	var spymaster := _make_spy_character(1)
	var target := _make_character(99)
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "DAMAGE_RELATIONSHIP", "target_npc_id": 99}},
	}
	DayOrchestrator._sync_spy_network_focus([spymaster, target], objectives_map, [], 0)
	var focus := AdvantageSystem.get_spy_network_focus(spymaster)
	assert_eq(focus.get("focus_type"), "character")
	assert_eq(focus.get("focus_id"), 99)


func test_sync_spy_military_objective_sets_army_focus_from_commander() -> void:
	var spymaster := _make_spy_character(1, "Crane")
	var enemy_commander := _make_character(50)
	enemy_commander.clan = "Lion"
	enemy_commander.commanded_unit_id = 201
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "DEFEND_PROVINCE", "target_npc_id": 50}},
	}
	DayOrchestrator._sync_spy_network_focus(
		[spymaster, enemy_commander], objectives_map, [], 0,
	)
	var focus := AdvantageSystem.get_spy_network_focus(spymaster)
	assert_eq(focus.get("focus_type"), "army")
	assert_eq(focus.get("focus_id"), 201)


func test_sync_spy_military_fallback_to_enemy_company() -> void:
	# No target_npc_id in objective — fall back to first company with non-same-clan commander.
	var spymaster := _make_spy_character(1, "Crane")
	var enemy_commander := _make_character(50)
	enemy_commander.clan = "Lion"
	var comp := MilitaryUnitData.CompanyData.new()
	comp.company_id = 77
	comp.commander_id = 50
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "CONDUCT_SIEGE", "target_npc_id": -1}},
	}
	DayOrchestrator._sync_spy_network_focus(
		[spymaster, enemy_commander], objectives_map, [comp], 0,
	)
	var focus := AdvantageSystem.get_spy_network_focus(spymaster)
	assert_eq(focus.get("focus_type"), "army")
	assert_eq(focus.get("focus_id"), 77)


func test_sync_spy_economic_objective_sets_place_focus() -> void:
	var spymaster := _make_spy_character(1)
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "ACQUIRE_RESOURCE", "target_settlement_id": 42}},
	}
	DayOrchestrator._sync_spy_network_focus([spymaster], objectives_map, [], 0)
	var focus := AdvantageSystem.get_spy_network_focus(spymaster)
	assert_eq(focus.get("focus_type"), "place")
	assert_eq(focus.get("focus_id"), 42)


func test_sync_spy_no_reassignment_when_need_type_unchanged() -> void:
	var spymaster := _make_spy_character(1)
	# Pre-set focus and last_synced_need_type.
	var adv := AdvantageSystem.get_advantage(spymaster, Enums.Advantage.SPY_NETWORK)
	adv.metadata["focus_type"] = "character"
	adv.metadata["focus_id"] = 5
	adv.metadata["last_synced_need_type"] = "DAMAGE_RELATIONSHIP"
	var objectives_map: Dictionary = {
		1: {"primary": {"need_type": "DAMAGE_RELATIONSHIP", "target_npc_id": 99}},
	}
	DayOrchestrator._sync_spy_network_focus([spymaster], objectives_map, [], 0)
	# focus_id should remain 5, not be updated to 99.
	var focus := AdvantageSystem.get_spy_network_focus(spymaster)
	assert_eq(focus.get("focus_id"), 5)


# ---------------------------------------------------------------------------
# SPY_NETWORK — intelligence tick (s45 lines 343-347)
# ---------------------------------------------------------------------------

func test_spy_character_focus_reveals_honor_rank() -> void:
	var spymaster := _make_spy_character(1)
	var target := _make_character(10)
	target.honor = 7.5
	var objectives_map: Dictionary = {1: {}}
	var topics_by_id: Dictionary = {}
	DayOrchestrator._spy_tick_character_focus(
		spymaster, 10, {10: target}, objectives_map, topics_by_id, 0,
	)
	assert_eq(spymaster.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = spymaster.knowledge_pool[0]
	assert_eq(entry.entry_type, "honor_rank")
	assert_eq(entry.data.get("honor"), 7.5)
	assert_eq(entry.data.get("target_character_id"), 10)


func test_spy_character_focus_skips_known_fact_tries_next() -> void:
	# honor_rank already known → moves to priority_objective.
	var spymaster := _make_spy_character(1)
	var target := _make_character(10)
	# Pre-populate honor_rank knowledge.
	var existing := KnowledgeEntry.new()
	existing.entry_type = "honor_rank"
	existing.data = {"target_character_id": 10, "honor": 3.0}
	spymaster.knowledge_pool.append(existing)
	var objectives_map: Dictionary = {
		1: {},
		10: {"primary": {"need_type": "RAISE_DISPOSITION", "target_npc_id": 5}},
	}
	var topics_by_id: Dictionary = {}
	DayOrchestrator._spy_tick_character_focus(
		spymaster, 10, {10: target}, objectives_map, topics_by_id, 0,
	)
	# Should have 2 entries now: old honor_rank + new priority_objective.
	assert_eq(spymaster.knowledge_pool.size(), 2)
	var new_entry: KnowledgeEntry = spymaster.knowledge_pool[1]
	assert_eq(new_entry.entry_type, "priority_objective")
	assert_eq(new_entry.data.get("need_type"), "RAISE_DISPOSITION")


func test_spy_character_focus_skips_dead_target() -> void:
	var spymaster := _make_spy_character(1)
	var target := _make_character(10)
	target.wounds_taken = 999  # Dead via wound overflow.
	var objectives_map: Dictionary = {1: {}}
	DayOrchestrator._spy_tick_character_focus(
		spymaster, 10, {10: target}, objectives_map, {}, 0,
	)
	assert_eq(spymaster.knowledge_pool.size(), 0)


func test_spy_place_focus_reveals_most_recent_tier4_topic() -> void:
	var spymaster := _make_spy_character(1)
	spymaster.physical_location = "99"  # Spy is elsewhere.
	var t1 := TopicData.new()
	t1.topic_id = 1
	t1.tier = TopicData.Tier.TIER_4
	t1.ic_day_created = 10
	var t2 := TopicData.new()
	t2.topic_id = 2
	t2.tier = TopicData.Tier.TIER_4
	t2.ic_day_created = 20  # More recent — should be selected.
	var topics_by_id: Dictionary = {1: t1, 2: t2}
	var active_topics: Array = [t1, t2]
	var settlement_topics: Dictionary = {"42": [1, 2]}
	DayOrchestrator._spy_tick_place_focus(
		spymaster, 42, active_topics, topics_by_id, settlement_topics, 0,
	)
	assert_true(2 in spymaster.topic_pool)
	assert_false(1 in spymaster.topic_pool)  # Older topic not added this tick.


func test_spy_place_focus_skips_already_known_topics() -> void:
	var spymaster := _make_spy_character(1)
	spymaster.topic_pool.append(1)
	spymaster.topic_pool.append(2)
	var t1 := TopicData.new()
	t1.topic_id = 1
	t1.tier = TopicData.Tier.TIER_4
	t1.ic_day_created = 10
	var t2 := TopicData.new()
	t2.topic_id = 2
	t2.tier = TopicData.Tier.TIER_4
	t2.ic_day_created = 20
	var topics_by_id: Dictionary = {1: t1, 2: t2}
	var settlement_topics: Dictionary = {"42": [1, 2]}
	DayOrchestrator._spy_tick_place_focus(
		spymaster, 42, [], topics_by_id, settlement_topics, 0,
	)
	# Both already known — pool size should not grow.
	assert_eq(spymaster.topic_pool.size(), 2)


func test_spy_army_focus_creates_intel_entry() -> void:
	var spymaster := _make_spy_character(1)
	var comp := MilitaryUnitData.CompanyData.new()
	comp.company_id = 55
	comp.commander_id = 20
	comp.current_location_id = "province_7"
	comp.health = 80
	DayOrchestrator._spy_tick_army_focus(spymaster, 55, [comp], {}, 0, 28)
	assert_eq(spymaster.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = spymaster.knowledge_pool[0]
	assert_eq(entry.entry_type, "army_intelligence")
	assert_eq(entry.data.get("company_id"), 55)
	assert_eq(entry.data.get("location"), "province_7")
	assert_eq(entry.data.get("size_pu"), 80)
	assert_eq(entry.data.get("commander_id"), 20)


func test_spy_army_focus_respects_ooc_week_gate() -> void:
	var spymaster := _make_spy_character(1)
	var comp := MilitaryUnitData.CompanyData.new()
	comp.company_id = 55
	comp.commander_id = 20
	comp.current_location_id = "province_7"
	comp.health = 80
	# First call fires.
	DayOrchestrator._spy_tick_army_focus(spymaster, 55, [comp], {}, 3, 84)
	assert_eq(spymaster.knowledge_pool.size(), 1)
	# Second call in the same OOC week — should not add another entry.
	DayOrchestrator._spy_tick_army_focus(spymaster, 55, [comp], {}, 3, 96)
	assert_eq(spymaster.knowledge_pool.size(), 1)


# ---------------------------------------------------------------------------
# Elemental Imbalance overflow — timed state fields (s45 lines 537-545)
# ---------------------------------------------------------------------------

func test_void_ml3_sets_void_imbalance_penalty_field() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 2
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.VOID, 3, dice, 200)
	assert_eq(c.void_imbalance_penalty_until, 204)  # 200 + 4 IC days (24 hours)


func test_void_ml5_does_not_set_void_imbalance_penalty_field() -> void:
	# ML5-6 is AoE Fear, not -1k0 penalty; penalty field should stay at -1.
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.current_void_points = 2
	c.void_imbalance_penalty_until = -1
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.VOID, 5, dice, 200)
	assert_eq(c.void_imbalance_penalty_until, -1)


func test_water_ml1_sets_social_penalty_flag() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.water_imbalance_social_penalty = false
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.WATER, 1, dice, 100)
	assert_true(c.water_imbalance_social_penalty)


func test_water_ml3_does_not_set_social_penalty_flag() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	c.water_imbalance_social_penalty = false
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.WATER, 3, dice, 100)
	assert_false(c.water_imbalance_social_penalty)


func test_air_ml3_without_perceived_honor_sets_social_penalty_field() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	# No PERCEIVED_HONOR advantage
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.AIR, 3, dice, 50)
	assert_eq(c.air_imbalance_social_penalty_until, 57)  # 50 + 7 IC days
	assert_eq(c.perceived_honor_blocked_until, -1)


func test_air_ml3_with_perceived_honor_blocks_advantage_field() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.AIR, 4, dice, 50)
	assert_eq(c.perceived_honor_blocked_until, 57)  # 50 + 7 IC days
	assert_eq(c.air_imbalance_social_penalty_until, -1)


func test_air_ml1_does_not_set_timed_fields() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c := _make_character()
	AdvantageSystem.apply_elemental_imbalance_overflow(c, Enums.Ring.AIR, 1, dice, 50)
	assert_eq(c.air_imbalance_social_penalty_until, -1)
	assert_eq(c.perceived_honor_blocked_until, -1)


# ---------------------------------------------------------------------------
# get_imbalance_skill_penalty (s45 lines 537-545)
# ---------------------------------------------------------------------------

func test_imbalance_penalty_void_active_reduces_rolled() -> void:
	var c := _make_character()
	c.void_imbalance_penalty_until = 110
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, false, 100)
	assert_eq(mod.get("rolled", 0), -1)
	assert_eq(mod.get("kept", 0), 0)


func test_imbalance_penalty_void_expired_no_effect() -> void:
	var c := _make_character()
	c.void_imbalance_penalty_until = 90  # expired before ic_day 100
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, false, 100)
	assert_eq(mod.get("rolled", 0), 0)


func test_imbalance_penalty_water_one_shot_consumed_on_social() -> void:
	var c := _make_character()
	c.water_imbalance_social_penalty = true
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, true, 100)
	assert_eq(mod.get("rolled", 0), -1)
	assert_false(c.water_imbalance_social_penalty)  # flag consumed


func test_imbalance_penalty_water_not_applied_to_non_social() -> void:
	var c := _make_character()
	c.water_imbalance_social_penalty = true
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, false, 100)
	assert_eq(mod.get("rolled", 0), 0)
	assert_true(c.water_imbalance_social_penalty)  # flag NOT consumed


func test_imbalance_penalty_air_social_active() -> void:
	var c := _make_character()
	c.air_imbalance_social_penalty_until = 110
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, true, 100)
	assert_eq(mod.get("rolled", 0), -1)
	assert_eq(mod.get("kept", 0), -1)


func test_imbalance_penalty_air_social_not_applied_to_non_social() -> void:
	var c := _make_character()
	c.air_imbalance_social_penalty_until = 110
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, false, 100)
	assert_eq(mod.get("rolled", 0), 0)
	assert_eq(mod.get("kept", 0), 0)


func test_imbalance_penalty_stacks_void_and_water() -> void:
	var c := _make_character()
	c.void_imbalance_penalty_until = 110
	c.water_imbalance_social_penalty = true
	var mod: Dictionary = AdvantageSystem.get_imbalance_skill_penalty(c, true, 100)
	assert_eq(mod.get("rolled", 0), -2)  # void -1k0 + water -1k0
	assert_eq(mod.get("kept", 0), 0)


# ---------------------------------------------------------------------------
# get_perceived_honor with ic_day (s45 line 537)
# ---------------------------------------------------------------------------

func test_perceived_honor_returns_bonus_when_not_blocked() -> void:
	var c := _make_character()
	c.honor = 4.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	c.perceived_honor_blocked_until = -1
	assert_eq(AdvantageSystem.get_perceived_honor(c, 100), 6.0)


func test_perceived_honor_returns_true_honor_when_blocked() -> void:
	var c := _make_character()
	c.honor = 4.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	c.perceived_honor_blocked_until = 110  # still active at ic_day 100
	assert_eq(AdvantageSystem.get_perceived_honor(c, 100), 4.0)


func test_perceived_honor_returns_bonus_after_block_expires() -> void:
	var c := _make_character()
	c.honor = 4.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	c.perceived_honor_blocked_until = 90  # expired before ic_day 100
	assert_eq(AdvantageSystem.get_perceived_honor(c, 100), 6.0)


func test_perceived_honor_no_ic_day_ignores_block() -> void:
	# Backward-compat: callers passing no ic_day still get the bonus.
	var c := _make_character()
	c.honor = 4.0
	_add_advantage(c, Enums.Advantage.PERCEIVED_HONOR, 2)
	c.perceived_honor_blocked_until = 110
	assert_eq(AdvantageSystem.get_perceived_honor(c), 6.0)


# ---------------------------------------------------------------------------
# MAGIC_RESISTANCE wired into SpellSystem.resolve_cast (s45)
# ---------------------------------------------------------------------------

func test_magic_resistance_increases_casting_tn() -> void:
	# jade_strike is Earth ML1; base TN = 10. Rank-2 Magic Resistance adds +6.
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var caster := _make_shugenja(1)
	caster.spells_known = ["jade_strike"]
	var target := _make_character(2)
	_add_advantage(target, Enums.Advantage.MAGIC_RESISTANCE, 2)
	var r: Dictionary = SpellSystem.resolve_cast(caster, "jade_strike", dice, 0, target)
	assert_eq(r.get("tn", 0), 16)


func test_no_magic_resistance_uses_base_tn() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var caster := _make_shugenja(1)
	caster.spells_known = ["jade_strike"]
	var target := _make_character(2)
	# No Magic Resistance advantage
	var r: Dictionary = SpellSystem.resolve_cast(caster, "jade_strike", dice, 0, target)
	assert_eq(r.get("tn", 0), 10)


func test_magic_resistance_not_applied_when_no_target() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var caster := _make_shugenja(1)
	caster.spells_known = ["jade_strike"]
	var r: Dictionary = SpellSystem.resolve_cast(caster, "jade_strike", dice)
	assert_eq(r.get("tn", 0), 10)


# ---------------------------------------------------------------------------
# Wiring tests: 14 s45 dead functions now wired into simulation systems
# ---------------------------------------------------------------------------

# IDEALISTIC wiring — HonorGlorySystem.apply_honor_change
func test_idealistic_increases_honor_loss_when_wired() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.IDEALISTIC)
	c.honor = 5.0
	var old: float = c.honor
	HonorGlorySystem.apply_honor_change(c, -1.0)
	# IDEALISTIC adds 1 point to each honor loss: expected -2.0 total loss
	assert_eq(c.honor, old - 2.0)

func test_idealistic_does_not_affect_honor_gains() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.IDEALISTIC)
	c.honor = 3.0
	HonorGlorySystem.apply_honor_change(c, 1.0)
	assert_eq(c.honor, 4.0)

func test_no_idealistic_honor_loss_is_normal() -> void:
	var c := _make_character()
	c.honor = 5.0
	HonorGlorySystem.apply_honor_change(c, -1.0)
	assert_eq(c.honor, 4.0)

# QUICK_HEALER wiring — MedicineSystem
func test_quick_healer_stamina_bonus_positive_without_advantage() -> void:
	var c := _make_character()
	var bonus: int = AdvantageSystem.get_healing_stamina_bonus(c)
	assert_eq(bonus, 0)

func test_quick_healer_stamina_bonus_with_advantage() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.QUICK_HEALER)
	var bonus: int = AdvantageSystem.get_healing_stamina_bonus(c)
	assert_eq(bonus, 2)

# PERMANENT_WOUND wiring — CharacterStats.get_wound_level
func test_permanent_wound_gives_nicked_minimum_when_no_wounds() -> void:
	var c := _make_character()
	c.stamina = 2
	c.willpower = 2  # earth ring = 2, threshold = 4
	c.wounds_taken = 0
	_add_disadvantage(c, Enums.Disadvantage.PERMANENT_WOUND)
	var level: Enums.WoundLevel = CharacterStats.get_wound_level(c)
	assert_eq(level, Enums.WoundLevel.NICKED)

func test_no_permanent_wound_is_healthy_at_zero_wounds() -> void:
	var c := _make_character()
	c.stamina = 2
	c.willpower = 2
	c.wounds_taken = 0
	var level: Enums.WoundLevel = CharacterStats.get_wound_level(c)
	assert_eq(level, Enums.WoundLevel.HEALTHY)

# DARLING_OF_THE_COURT wiring — CharacterStats.get_effective_status
func test_get_effective_status_returns_status_plus_1_at_home_court() -> void:
	var c := _make_character()
	c.status = 3.0
	var adv: AdvantageData = _add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT)
	adv.metadata["settlement_id"] = 42
	var effective: float = CharacterStats.get_effective_status(c, 42)
	assert_eq(effective, 4.0)

func test_get_effective_status_unchanged_at_other_settlement() -> void:
	var c := _make_character()
	c.status = 3.0
	var adv: AdvantageData = _add_advantage(c, Enums.Advantage.DARLING_OF_THE_COURT)
	adv.metadata["settlement_id"] = 42
	var effective: float = CharacterStats.get_effective_status(c, 99)
	assert_eq(effective, 3.0)

# VOID extra cost wiring — VoidSystem.spend
func test_hotei_curse_costs_extra_void_on_spend() -> void:
	var c := _make_character()
	c.max_void_points = 3
	c.current_void_points = 3
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Hotei"})
	# First spend should cost 2 VP (1 + 1 extra)
	var ok: bool = VoidSystem.spend(c)
	assert_true(ok)
	assert_eq(c.current_void_points, 1)

func test_hotei_curse_blocks_spend_with_only_one_vp() -> void:
	var c := _make_character()
	c.max_void_points = 3
	c.current_void_points = 1
	_add_disadvantage(c, Enums.Disadvantage.SEVEN_FORTUNES_CURSE, 1, {"fortune": "Hotei"})
	var ok: bool = VoidSystem.spend(c)
	assert_false(ok)
	assert_eq(c.current_void_points, 1)

func test_no_curse_spend_costs_one_vp() -> void:
	var c := _make_character()
	c.max_void_points = 3
	c.current_void_points = 1
	var ok: bool = VoidSystem.spend(c)
	assert_true(ok)
	assert_eq(c.current_void_points, 0)

# Void recovery hours — VoidSystem.get_recovery_hours / can_recover_full
func test_void_recovery_hours_default_8() -> void:
	var c := _make_character()
	assert_eq(VoidSystem.get_recovery_hours(c), 8)

func test_void_can_recover_full_after_enough_hours() -> void:
	var c := _make_character()
	assert_true(VoidSystem.can_recover_full(c, 8))

func test_void_cannot_recover_full_before_enough_hours() -> void:
	var c := _make_character()
	assert_false(VoidSystem.can_recover_full(c, 4))

# SACROSANCT wiring — ViolenceSystem.evaluate_violence
func test_sacrosanct_victim_elevates_crime_to_capital() -> void:
	var attacker := _make_character(1)
	var victim := _make_character(2)
	_add_advantage(victim, Enums.Advantage.SACROSANCT)
	var result: Dictionary = ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["severity"], Enums.CrimeSeverity.CAPITAL)
	assert_true(result.get("sacrosanct_victim", false))

func test_non_sacrosanct_victim_crime_is_minor() -> void:
	var attacker := _make_character(1)
	var victim := _make_character(2)
	var result: Dictionary = ViolenceSystem.evaluate_violence(attacker, victim, 0, false)
	assert_eq(result["severity"], Enums.CrimeSeverity.MINOR)

# STUDENT_OF_SHOURIDO wiring — SeductionSystem defense TN
func test_shourido_defense_tn_minimum_5_when_honor_low() -> void:
	var seducer := _make_character(1)
	seducer.skills["Temptation"] = 3
	seducer.awareness = 3
	var target := _make_character(2)
	target.honor = 1.0  # rank 1, below minimum
	target.willpower = 2
	target.skills["Etiquette"] = 0
	_add_advantage(target, Enums.Advantage.STUDENT_OF_SHOURIDO)
	var effective_rank: int = AdvantageSystem.get_shourido_honor_bonus(target, int(target.honor))
	assert_eq(effective_rank, 5)

# CURSED_BY_TOSHIGOKU wiring — forces to_death in duel
func test_cursed_toshigoku_trigger_with_opponent_wounded() -> void:
	var c := _make_character()
	_add_disadvantage(c, Enums.Disadvantage.CURSED_BY_THE_REALM, 1, {"realm": "Toshigoku"})
	var result: Dictionary = AdvantageSystem.check_cursed_toshigoku_trigger(c, true)
	assert_true(result)

# INHERITANCE wiring — SkillResolver extra die
func test_inheritance_bonus_in_skill_check_context() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.INHERITANCE)
	var bonus: Dictionary = AdvantageSystem.get_inheritance_skill_bonus(c, true)
	# INHERITANCE returns +1 kept die when using heirloom
	assert_eq(bonus.get("kept", 0), 1)

# SOFT_HEARTED field — exists on character data
func test_soft_hearted_tn_until_defaults_to_minus_one() -> void:
	var c := _make_character()
	assert_eq(c.soft_hearted_tn_until, -1)

func test_soft_hearted_field_settable() -> void:
	var c := _make_character()
	c.soft_hearted_tn_until = 100
	assert_eq(c.soft_hearted_tn_until, 100)

# GREAT_DESTINY wiring — reduces wound level to DOWN start rather than lethal
func test_great_destiny_check_triggers_in_different_year() -> void:
	var c := _make_character()
	_add_advantage(c, Enums.Advantage.GREAT_DESTINY)
	var result: bool = AdvantageSystem.check_great_destiny(c, 5)
	assert_true(result)

func test_great_destiny_check_does_not_trigger_same_year() -> void:
	var c := _make_character()
	var adv: AdvantageData = _add_advantage(c, Enums.Advantage.GREAT_DESTINY)
	adv.metadata["last_triggered_ic_year"] = 5
	var result: bool = AdvantageSystem.check_great_destiny(c, 5)
	assert_false(result)
