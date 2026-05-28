extends GutTest
## Tests for ArtisanSystem (s49 — Artisan & Crafting System).


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


# -- Cost-based TN tests -------------------------------------------------------

func test_base_tn_zeni_low() -> void:
	assert_eq(ArtisanSystem.get_base_tn(5.0, "zeni"), 10)

func test_base_tn_zeni_mid() -> void:
	assert_eq(ArtisanSystem.get_base_tn(15.0, "zeni"), 15)

func test_base_tn_zeni_high() -> void:
	assert_eq(ArtisanSystem.get_base_tn(50.0, "zeni"), 20)

func test_base_tn_zeni_over() -> void:
	assert_eq(ArtisanSystem.get_base_tn(60.0, "zeni"), 35)

func test_base_tn_bu_low() -> void:
	assert_eq(ArtisanSystem.get_base_tn(3.0, "bu"), 15)

func test_base_tn_bu_mid() -> void:
	assert_eq(ArtisanSystem.get_base_tn(15.0, "bu"), 20)

func test_base_tn_bu_high() -> void:
	assert_eq(ArtisanSystem.get_base_tn(50.0, "bu"), 25)

func test_base_tn_bu_over() -> void:
	assert_eq(ArtisanSystem.get_base_tn(55.0, "bu"), 35)

func test_base_tn_koku_low() -> void:
	assert_eq(ArtisanSystem.get_base_tn(5.0, "koku"), 20)

func test_base_tn_koku_mid() -> void:
	assert_eq(ArtisanSystem.get_base_tn(15.0, "koku"), 25)

func test_base_tn_koku_high() -> void:
	assert_eq(ArtisanSystem.get_base_tn(25.0, "koku"), 30)

func test_base_tn_koku_over() -> void:
	assert_eq(ArtisanSystem.get_base_tn(35.0, "koku"), 45)


# -- Quality tier tests --------------------------------------------------------

func test_quality_mundane() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(10), GiftGivingSystem.QualityTier.MUNDANE)

func test_quality_normal() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(15), GiftGivingSystem.QualityTier.NORMAL)

func test_quality_fine() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(25), GiftGivingSystem.QualityTier.FINE)

func test_quality_exceptional() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(35), GiftGivingSystem.QualityTier.EXCEPTIONAL)

func test_quality_masterwork() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(45), GiftGivingSystem.QualityTier.MASTERWORK)

func test_quality_legendary() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(55), GiftGivingSystem.QualityTier.LEGENDARY)

func test_quality_between_tiers() -> void:
	assert_eq(ArtisanSystem.determine_quality_tier(30), GiftGivingSystem.QualityTier.FINE)


# -- Crafting time tests -------------------------------------------------------

func test_time_unit_steel_koku() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.STEEL, "koku"),
		ArtisanSystem.TimeUnit.WEEKS)

func test_time_unit_steel_bu() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.STEEL, "bu"),
		ArtisanSystem.TimeUnit.DAYS)

func test_time_unit_metal_any() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.METAL_GLASS, "koku"),
		ArtisanSystem.TimeUnit.DAYS)

func test_time_unit_other_zeni() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "zeni"),
		ArtisanSystem.TimeUnit.HOURS)

func test_time_unit_other_koku() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "koku"),
		ArtisanSystem.TimeUnit.DAYS)

func test_time_units_katana() -> void:
	assert_true(ArtisanSystem.get_time_units(25.0, "koku") > 0)

func test_time_units_minimum() -> void:
	assert_true(ArtisanSystem.get_time_units(1.0, "zeni") >= 1)

func test_ap_cost_katana() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(25.0, "koku", Enums.MaterialType.STEEL)
	assert_true(ap >= 2)

func test_ap_cost_painting() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(3.0, "bu", Enums.MaterialType.OTHER)
	assert_true(ap >= 1)

func test_ap_cost_exceptional_katana() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(75.0, "koku", Enums.MaterialType.STEEL)
	assert_true(ap >= 3)


# -- Material availability tests -----------------------------------------------

func test_village_only_common() -> void:
	var avail: Array = ArtisanSystem.MATERIAL_AVAILABILITY[Enums.SettlementType.VILLAGE]
	assert_eq(avail, [Enums.MaterialTier.COMMON])
	assert_false(avail.has(Enums.MaterialTier.RARE))

func test_town_common_and_uncommon() -> void:
	var avail: Array = ArtisanSystem.MATERIAL_AVAILABILITY[Enums.SettlementType.TOWN]
	assert_true(avail.has(Enums.MaterialTier.COMMON))
	assert_true(avail.has(Enums.MaterialTier.UNCOMMON))
	assert_false(avail.has(Enums.MaterialTier.RARE))

func test_city_up_to_rare() -> void:
	var avail: Array = ArtisanSystem.MATERIAL_AVAILABILITY[Enums.SettlementType.CITY]
	assert_true(avail.has(Enums.MaterialTier.RARE))

func test_family_castle_all_tiers() -> void:
	var avail: Array = ArtisanSystem.MATERIAL_AVAILABILITY[Enums.SettlementType.FAMILY_CASTLE]
	assert_true(avail.has(Enums.MaterialTier.LEGENDARY))

func test_imperial_capital_all_tiers() -> void:
	var avail: Array = ArtisanSystem.MATERIAL_AVAILABILITY[Enums.SettlementType.IMPERIAL_CAPITAL]
	assert_true(avail.has(Enums.MaterialTier.LEGENDARY))

func test_material_available_check() -> void:
	assert_true(ArtisanSystem.is_material_available(
		Enums.MaterialTier.COMMON, Enums.SettlementType.VILLAGE))
	assert_false(ArtisanSystem.is_material_available(
		Enums.MaterialTier.RARE, Enums.SettlementType.VILLAGE))


# -- Clan material tests -------------------------------------------------------

func test_crab_clan_material() -> void:
	var mat: Dictionary = ArtisanSystem.CLAN_MATERIALS["Crab"]
	assert_eq(mat["name"], "Kaiu Steel")
	assert_eq(mat["tier"], Enums.MaterialTier.RARE)

func test_crane_clan_material() -> void:
	var mat: Dictionary = ArtisanSystem.CLAN_MATERIALS["Crane"]
	assert_eq(mat["name"], "Kakita Paper")

func test_unknown_clan_no_material() -> void:
	assert_false(ArtisanSystem.CLAN_MATERIALS.has("Spider"))


# -- Exceptional weapon tests --------------------------------------------------

func test_exceptional_weapon_rank_7() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Craft: Weaponsmithing"] = 7
	assert_true(ArtisanSystem.can_attempt_exceptional_weapon(c))

func test_exceptional_weapon_rank_6_fails() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Craft: Weaponsmithing"] = 6
	assert_false(ArtisanSystem.can_attempt_exceptional_weapon(c))

func test_kaiu_exceptional_at_rank_5() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 5
	assert_true(ArtisanSystem.can_attempt_exceptional_weapon(c))

func test_tsi_exceptional_at_rank_5() -> void:
	var c := _make_character("Mantis", "Tsi")
	c.skills["Craft: Weaponsmithing"] = 5
	assert_true(ArtisanSystem.can_attempt_exceptional_weapon(c))
	c.skills["Craft: Weaponsmithing"] = 4
	assert_false(ArtisanSystem.can_attempt_exceptional_weapon(c))


# -- Sacred weapon tests -------------------------------------------------------

func test_sacred_weapon_requires_exceptional() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 4
	assert_false(ArtisanSystem.can_attempt_sacred_weapon(c))

func test_sacred_weapon_kaiu_eligible() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	assert_true(ArtisanSystem.can_attempt_sacred_weapon(c))

func test_sacred_weapon_wrong_clan() -> void:
	var c := _make_character("Spider", "Daigotsu")
	c.skills["Craft: Weaponsmithing"] = 7
	assert_false(ArtisanSystem.can_attempt_sacred_weapon(c))


# -- Exceptional TN tests -----------------------------------------------------

func test_exceptional_tn_katana() -> void:
	var base: int = ArtisanSystem.get_base_tn(25.0, "koku")
	var exc: int = ArtisanSystem.get_exceptional_tn(25.0)
	assert_true(exc > base)


# -- Special quality allocation ------------------------------------------------

func test_allocate_balanced() -> void:
	var requested: Array[Enums.WeaponSpecialQuality] = [Enums.WeaponSpecialQuality.BALANCED]
	var alloc: Dictionary = ArtisanSystem.allocate_special_qualities(4, requested)
	assert_eq(alloc.get("allocated", []).size(), 1)
	assert_eq(alloc["raises_spent"], 4)

func test_allocate_insufficient_raises() -> void:
	var requested: Array[Enums.WeaponSpecialQuality] = [Enums.WeaponSpecialQuality.RADIANT]
	var alloc: Dictionary = ArtisanSystem.allocate_special_qualities(3, requested)
	assert_eq(alloc.get("allocated", []).size(), 0)

func test_allocate_multiple_qualities() -> void:
	var requested: Array[Enums.WeaponSpecialQuality] = [
		Enums.WeaponSpecialQuality.BALANCED, Enums.WeaponSpecialQuality.SWIFT]
	var alloc: Dictionary = ArtisanSystem.allocate_special_qualities(10, requested)
	assert_eq(alloc.get("allocated", []).size(), 2)
	assert_eq(alloc["raises_spent"], 8)


# -- Sacred weapon check -------------------------------------------------------

func test_sacred_weapon_check_kaiu() -> void:
	var c := _make_character("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(10, c)
	assert_true(result.get("can_forge", false))
	assert_eq(result.get("raise_cost"), 6)
	assert_eq(result.get("sacred_name"), "Kaiu Blade")

func test_sacred_weapon_check_non_kaiu() -> void:
	var c := _make_character("Crane", "Kakita")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(10, c)
	assert_true(result.get("can_forge", false))
	assert_eq(result.get("raise_cost"), 7)

func test_sacred_weapon_check_insufficient_raises() -> void:
	var c := _make_character("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(5, c)
	assert_false(result.get("can_forge", false))


# -- Core resolve_crafting tests -----------------------------------------------

func test_resolve_normal_artwork() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 5
	c.awareness = 4
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Artisan: Painting", 15,
		Enums.MaterialTier.COMMON, false, 0)
	assert_true(result.has("quality_tier"))
	assert_false(result.get("item_ruined", false))

func test_resolve_exceptional_failure_ruins_item() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	c.agility = 2
	_dice.set_seed(1)
	var tn: int = ArtisanSystem.get_exceptional_tn(25.0)
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Craft: Weaponsmithing", tn,
		Enums.MaterialTier.RARE, true, 0)
	if not result.get("success", false):
		assert_true(result.get("item_ruined", false),
			"Failed exceptional attempt should ruin item")

func test_resolve_material_free_raises_increase_effective_total() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 3
	c.awareness = 3
	_dice.set_seed(99)
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Artisan: Painting", 15,
		Enums.MaterialTier.RARE, false, 0)
	assert_eq(result.get("material_fr"), 2)
	assert_true(result["effective_total"] >= result["total"] + 10,
		"Rare materials should add at least 10 to effective total")


# -- Item creation tests -------------------------------------------------------

func test_create_crafted_item() -> void:
	var c := _make_character("Crane", "Kakita")
	var craft_result: Dictionary = {"quality_tier": GiftGivingSystem.QualityTier.FINE, "total": 28}
	var item: ArtisanItemData = ArtisanSystem.create_crafted_item(
		c, craft_result, 1, "Small Painting", Enums.CraftingCategory.ARTWORK,
		Enums.CraftingTrack.ARTISAN, "Artisan: Painting",
		Enums.MaterialTier.COMMON, "Standard paper", 3.0, "bu", 100, 5)
	assert_eq(item.item_id, 1)
	assert_eq(item.quality_tier, GiftGivingSystem.QualityTier.FINE)
	assert_eq(item.creator_clan, "Crane")
	assert_true(item.is_complete)
	assert_eq(item.creation_ic_day, 100)

func test_create_work_in_progress() -> void:
	var c := _make_character("Crab", "Kaiu")
	var item: ArtisanItemData = ArtisanSystem.create_work_in_progress(
		c, 2, "Katana", Enums.CraftingCategory.WEAPONS,
		Enums.CraftingTrack.CRAFT, "Craft: Weaponsmithing",
		Enums.MaterialTier.RARE, "Kaiu Steel", 25.0, "koku",
		Enums.MaterialType.STEEL)
	assert_false(item.is_complete)
	assert_true(item.crafting_ap_required > 1)
	assert_eq(item.crafting_ap_invested, 0)

func test_invest_ap_in_wip() -> void:
	var c := _make_character("Crab", "Kaiu")
	var item: ArtisanItemData = ArtisanSystem.create_work_in_progress(
		c, 3, "Katana", Enums.CraftingCategory.WEAPONS,
		Enums.CraftingTrack.CRAFT, "Craft: Weaponsmithing",
		Enums.MaterialTier.COMMON, "Iron", 25.0, "koku",
		Enums.MaterialType.STEEL)
	var result: Dictionary = ArtisanSystem.invest_ap(item, 1)
	assert_true(result["invested"])
	assert_eq(result["ap_invested"], 1)
	assert_false(result["ready_for_roll"])

func test_invest_ap_reaches_ready() -> void:
	var c := _make_character("Crane", "Kakita")
	var item: ArtisanItemData = ArtisanSystem.create_work_in_progress(
		c, 4, "Painting", Enums.CraftingCategory.ARTWORK,
		Enums.CraftingTrack.ARTISAN, "Artisan: Painting",
		Enums.MaterialTier.COMMON, "Paper", 3.0, "bu",
		Enums.MaterialType.OTHER)
	var result: Dictionary = ArtisanSystem.invest_ap(item, item.crafting_ap_required)
	assert_true(result["ready_for_roll"])


# -- History point tests -------------------------------------------------------

func test_history_points_owned_rank_3() -> void:
	var item := ArtisanItemData.new()
	var added: bool = item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 100, "Doji Haruki")
	assert_true(added)
	assert_eq(item.history_points, 1)
	assert_eq(item.get_history_tier_bonus(), 0)

func test_history_points_accumulate_to_notable() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 100, "Owner A")
	item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 200, "Owner B")
	item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, 300, "Battle X")
	assert_eq(item.history_points, 3)
	assert_eq(item.get_history_tier_bonus(), 1)

func test_history_points_no_duplicate() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, 100, "Battle X")
	var added: bool = item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, 100, "Battle X")
	assert_false(added)
	assert_eq(item.history_points, 1)

func test_history_points_champion_owner() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 100, "Akodo Toturi")
	assert_eq(item.history_points, 3)
	assert_eq(item.get_history_tier_bonus(), 1)

func test_history_tier_storied() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 100, "A")
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 200, "B")
	assert_eq(item.history_points, 6)
	assert_eq(item.get_history_tier_bonus(), 2)

func test_history_tier_legendary() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 100, "A")
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 200, "B")
	item.add_history_event(Enums.HistoryEventType.PRESENT_AT_EVENT, 300, "C")
	item.add_history_event(Enums.HistoryEventType.PRESENT_AT_EVENT, 400, "D")
	assert_eq(item.history_points, 10)
	assert_eq(item.get_history_tier_bonus(), 3)

func test_total_free_raises_quality_plus_history() -> void:
	var item := ArtisanItemData.new()
	item.quality_tier = GiftGivingSystem.QualityTier.MASTERWORK
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 100, "A")
	item.add_history_event(Enums.HistoryEventType.OWNED_CHAMPION, 200, "B")
	item.add_history_event(Enums.HistoryEventType.PRESENT_AT_EVENT, 300, "C")
	item.add_history_event(Enums.HistoryEventType.PRESENT_AT_EVENT, 400, "D")
	assert_eq(item.get_total_free_raises(), 6)


# -- Utility tests -------------------------------------------------------------

func test_has_any_craft_skill() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 3
	assert_true(ArtisanSystem.has_any_craft_skill(c))

func test_has_no_craft_skill() -> void:
	var c := _make_character("Lion", "Matsu")
	assert_false(ArtisanSystem.has_any_craft_skill(c))

func test_get_best_craft_skill() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 3
	c.skills["Artisan: Poetry"] = 5
	assert_eq(ArtisanSystem.get_best_craft_skill(c), "Artisan: Poetry")


# -- Cost in koku conversion ---------------------------------------------------

func test_cost_in_koku_koku() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(25.0, "koku"), 25.0)

func test_cost_in_koku_bu() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(5.0, "bu"), 1.0)

func test_cost_in_koku_zeni() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(50.0, "zeni"), 1.0)


# -- find_crafted_item ---------------------------------------------------------

func test_find_crafted_item() -> void:
	var a := ArtisanItemData.new()
	a.item_id = 800
	var b := ArtisanItemData.new()
	b.item_id = 801
	assert_eq(ArtisanSystem.find_crafted_item([a, b], 801), b)
	assert_null(ArtisanSystem.find_crafted_item([a, b], 999))


# -- Executor tests (GDD-sourced crafting resolution) --------------------------

func test_executor_immediate_sets_koku_cost() -> void:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 72
	c.skills = {"Artisan: Painting": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {
		"can_craft": true,
		"skill_name": "Artisan: Painting",
		"base_tn": 15,
		"material_tier": Enums.MaterialTier.COMMON,
		"material_name": "",
		"is_exceptional": false,
		"item_name": "Quick Sketch",
		"category": Enums.CraftingCategory.ARTWORK,
		"track": Enums.CraftingTrack.ARTISAN,
		"denomination": "zeni",
		"base_cost": 3.0,
		"material_type": Enums.MaterialType.OTHER,
	}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.has("koku_cost"))
	assert_true(eff.get("koku_cost", 0.0) > 0.0)


func test_executor_wip_sets_koku_cost() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 70
	c.skills = {"Craft: Weaponsmithing": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {
		"can_craft": true,
		"skill_name": "Craft: Weaponsmithing",
		"base_tn": 25,
		"material_tier": Enums.MaterialTier.COMMON,
		"material_name": "Standard steel",
		"is_exceptional": false,
		"item_name": "WIP Katana",
		"category": Enums.CraftingCategory.WEAPONS,
		"track": Enums.CraftingTrack.CRAFT,
		"denomination": "koku",
		"base_cost": 25.0,
		"material_type": Enums.MaterialType.STEEL,
	}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.get("creates_wip", false))
	assert_eq(eff.get("koku_cost", 0.0), 25.0)


func test_executor_exceptional_koku_cost_tripled() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 70
	c.skills = {"Craft: Weaponsmithing": 7}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {
		"can_craft": true,
		"skill_name": "Craft: Weaponsmithing",
		"base_tn": 30,
		"material_tier": Enums.MaterialTier.COMMON,
		"material_name": "Standard steel",
		"is_exceptional": true,
		"item_name": "Exceptional Katana",
		"category": Enums.CraftingCategory.WEAPONS,
		"track": Enums.CraftingTrack.CRAFT,
		"denomination": "koku",
		"base_cost": 25.0,
		"material_type": Enums.MaterialType.STEEL,
	}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	assert_eq(result.get("effects", {}).get("koku_cost", 0.0), 75.0)


func test_executor_continue_wip_no_koku_cost() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 71
	c.skills = {"Craft: Weaponsmithing": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {"wip_item_id": 999, "can_craft": true}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 11
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.get("continues_wip", false))
	assert_false(eff.has("koku_cost"))


func test_executor_creates_wip_for_multi_day() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 70
	c.skills = {"Craft: Weaponsmithing": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {
		"can_craft": true,
		"skill_name": "Craft: Weaponsmithing",
		"base_tn": 25,
		"material_tier": Enums.MaterialTier.COMMON,
		"material_name": "Standard steel",
		"is_exceptional": false,
		"item_name": "WIP Katana",
		"category": Enums.CraftingCategory.WEAPONS,
		"track": Enums.CraftingTrack.CRAFT,
		"denomination": "koku",
		"base_cost": 25.0,
		"material_type": Enums.MaterialType.STEEL,
	}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	ctx.season = 0
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	assert_true(result.get("effects", {}).get("creates_wip", false))


func test_executor_continues_wip() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 71
	c.skills = {"Craft: Weaponsmithing": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {"wip_item_id": 999, "can_craft": true}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 11
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	assert_true(result.get("effects", {}).get("continues_wip", false))
	assert_eq(result.get("effects", {}).get("wip_item_id", -1), 999)


func test_executor_resolves_single_day_immediately() -> void:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 72
	c.skills = {"Artisan: Painting": 5}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "CRAFT"
	action.metadata = {
		"can_craft": true,
		"skill_name": "Artisan: Painting",
		"base_tn": 15,
		"material_tier": Enums.MaterialTier.COMMON,
		"material_name": "",
		"is_exceptional": false,
		"item_name": "Quick Sketch",
		"category": Enums.CraftingCategory.ARTWORK,
		"track": Enums.CraftingTrack.ARTISAN,
		"denomination": "zeni",
		"base_cost": 3.0,
		"material_type": Enums.MaterialType.OTHER,
	}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.get("requires_item_creation", false))
	assert_false(eff.get("creates_wip", false))


# -- Helper --------------------------------------------------------------------

func _make_character(clan: String, family: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = clan
	c.family = family
	c.school = ""
	c.skills = {}
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.agility = 3
	c.intelligence = 3
	c.reflexes = 3
	c.awareness = 3
	c.void_ring = 2
	c.honor = 5.0
	c.glory = 3.0
	c.status = 3.0
	c.koku = 50.0
	c.physical_location = ""
	c.wounds_taken = 0
	return c
