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
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.METAL_GLASS, "zeni"),
		ArtisanSystem.TimeUnit.DAYS)

func test_time_unit_other_zeni() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "zeni"),
		ArtisanSystem.TimeUnit.HOURS)

func test_time_unit_other_koku() -> void:
	assert_eq(ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "koku"),
		ArtisanSystem.TimeUnit.DAYS)

func test_time_units_katana() -> void:
	assert_eq(ArtisanSystem.get_time_units(25.0, "koku"), 9)

func test_time_units_minimum() -> void:
	assert_eq(ArtisanSystem.get_time_units(1.0, "zeni"), 1)

func test_ap_cost_katana() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(25.0, "koku", Enums.MaterialType.STEEL)
	assert_eq(ap, 9 * 14)

func test_ap_cost_painting() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(3.0, "bu", Enums.MaterialType.OTHER)
	assert_eq(ap, 1)

func test_ap_cost_exceptional_katana() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(75.0, "koku", Enums.MaterialType.STEEL)
	assert_eq(ap, 25 * 14)


# -- Material availability tests -----------------------------------------------

func test_village_only_common() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.VILLAGE)
	assert_true(Enums.MaterialTier.COMMON in avail)
	assert_false(Enums.MaterialTier.UNCOMMON in avail)

func test_town_common_and_uncommon() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.TOWN)
	assert_true(Enums.MaterialTier.COMMON in avail)
	assert_true(Enums.MaterialTier.UNCOMMON in avail)
	assert_false(Enums.MaterialTier.RARE in avail)

func test_city_up_to_rare() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.CITY)
	assert_true(Enums.MaterialTier.RARE in avail)
	assert_false(Enums.MaterialTier.LEGENDARY in avail)

func test_family_castle_all_tiers() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.FAMILY_CASTLE)
	assert_true(Enums.MaterialTier.LEGENDARY in avail)

func test_imperial_capital_all_tiers() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.IMPERIAL_CAPITAL)
	assert_true(Enums.MaterialTier.LEGENDARY in avail)

func test_material_available_check() -> void:
	assert_true(ArtisanSystem.is_material_available(Enums.MaterialTier.COMMON, Enums.SettlementType.VILLAGE))
	assert_false(ArtisanSystem.is_material_available(Enums.MaterialTier.RARE, Enums.SettlementType.VILLAGE))


# -- Clan material tests -------------------------------------------------------

func test_crab_clan_material() -> void:
	var mat: Dictionary = ArtisanSystem.get_clan_material("Crab")
	assert_eq(mat.get("name"), "Kaiu Steel")
	assert_eq(mat.get("tier"), Enums.MaterialTier.RARE)

func test_crane_clan_material() -> void:
	var mat: Dictionary = ArtisanSystem.get_clan_material("Crane")
	assert_eq(mat.get("name"), "Kakita Paper")

func test_unknown_clan_no_material() -> void:
	var mat: Dictionary = ArtisanSystem.get_clan_material("Nonexistent")
	assert_true(mat.is_empty())


# -- Exceptional weapon eligibility tests --------------------------------------

func test_exceptional_weapon_rank_7() -> void:
	var c := _make_character("Lion", "Matsu")
	c.skills["Craft: Weaponsmithing"] = 7
	assert_true(ArtisanSystem.can_attempt_exceptional_weapon(c))

func test_exceptional_weapon_rank_6_fails() -> void:
	var c := _make_character("Lion", "Matsu")
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


# -- Sacred weapon eligibility tests -------------------------------------------

func test_sacred_weapon_requires_exceptional() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 4
	assert_false(ArtisanSystem.can_attempt_sacred_weapon(c))

func test_sacred_weapon_kaiu_eligible() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	assert_true(ArtisanSystem.can_attempt_sacred_weapon(c))

func test_sacred_weapon_wrong_clan() -> void:
	var c := _make_character("Ronin", "Ronin")
	c.skills["Craft: Weaponsmithing"] = 9
	assert_false(ArtisanSystem.can_attempt_sacred_weapon(c))


# -- Exceptional TN tests -----------------------------------------------------

func test_exceptional_tn_katana() -> void:
	var tn: int = ArtisanSystem.get_exceptional_tn(25.0)
	assert_eq(tn, ArtisanSystem.get_base_tn(75.0, "koku"))


# -- Special quality allocation tests ------------------------------------------

func test_allocate_balanced() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		5, [Enums.WeaponSpecialQuality.BALANCED])
	assert_eq(result["allocated"].size(), 1)
	assert_eq(result["raises_spent"], 4)

func test_allocate_insufficient_raises() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		3, [Enums.WeaponSpecialQuality.BALANCED])
	assert_eq(result["allocated"].size(), 0)

func test_allocate_multiple_qualities() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		7, [Enums.WeaponSpecialQuality.SIGNATURE, Enums.WeaponSpecialQuality.BALANCED])
	assert_eq(result["allocated"].size(), 2)
	assert_eq(result["raises_spent"], 6)

func test_allocate_partial_when_insufficient() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		5, [Enums.WeaponSpecialQuality.SIGNATURE, Enums.WeaponSpecialQuality.TRUE_QUALITY])
	assert_eq(result["allocated"].size(), 1)
	assert_true(Enums.WeaponSpecialQuality.SIGNATURE in result["allocated"])


# -- Sacred weapon check tests -------------------------------------------------

func test_sacred_weapon_check_kaiu() -> void:
	var c := _make_character("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(7, c)
	assert_true(result["can_forge"])
	assert_eq(result["raise_cost"], 6)
	assert_eq(result["sacred_name"], "Kaiu Blade")

func test_sacred_weapon_check_non_kaiu() -> void:
	var c := _make_character("Crane", "Kakita")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(7, c)
	assert_true(result["can_forge"])
	assert_eq(result["raise_cost"], 7)

func test_sacred_weapon_check_insufficient_raises() -> void:
	var c := _make_character("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(5, c)
	assert_false(result["can_forge"])


# -- Crafting resolution tests -------------------------------------------------

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


# -- NPC craft selection tests -------------------------------------------------

func test_npc_select_artwork() -> void:
	var c := _make_character("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 4
	var result: Dictionary = ArtisanSystem.npc_select_craft_action(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.ARTWORK)
	assert_true(result["can_craft"])
	assert_eq(result["skill_name"], "Artisan: Painting")
	assert_eq(result["track"], Enums.CraftingTrack.ARTISAN)

func test_npc_select_no_skill() -> void:
	var c := _make_character("Lion", "Matsu")
	var result: Dictionary = ArtisanSystem.npc_select_craft_action(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.ARTWORK)
	assert_false(result["can_craft"])

func test_npc_select_weapon_exceptional() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	var result: Dictionary = ArtisanSystem.npc_select_craft_action(
		c, Enums.SettlementType.FAMILY_CASTLE, Enums.CraftingCategory.WEAPONS)
	assert_true(result["can_craft"])
	assert_true(result["is_exceptional"])

func test_npc_best_material_clan_specific() -> void:
	var c := _make_character("Crab", "Kaiu")
	var mat: Dictionary = ArtisanSystem.select_best_material_for_npc(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.WEAPONS)
	assert_eq(mat["name"], "Kaiu Steel")
	assert_eq(mat["tier"], Enums.MaterialTier.RARE)

func test_npc_best_material_falls_back() -> void:
	var c := _make_character("Lion", "Matsu")
	var mat: Dictionary = ArtisanSystem.select_best_material_for_npc(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.WEAPONS)
	assert_eq(mat["tier"], Enums.MaterialTier.RARE)


# -- Utility tests -------------------------------------------------------------

func test_is_artisan_school() -> void:
	var c := _make_character("Crane", "Kakita")
	c.school = "Kakita Artisan"
	assert_true(ArtisanSystem.is_artisan_school(c))

func test_is_smith_school() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.school = "Kaiu Engineer"
	assert_true(ArtisanSystem.is_smith_school(c))

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
	c.physical_location = ""
	c.wounds_taken = 0
	return c
