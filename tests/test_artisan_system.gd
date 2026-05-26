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
	c.koku = 50.0
	c.physical_location = ""
	c.wounds_taken = 0
	return c


func _make_rank3_char() -> L5RCharacterData:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 10
	c.stamina = 4
	c.willpower = 4
	c.strength = 4
	c.perception = 4
	c.agility = 4
	c.intelligence = 4
	c.reflexes = 4
	c.awareness = 4
	c.void_ring = 3
	c.character_name = "Kakita Artisan"
	return c


func _make_rank5_char() -> L5RCharacterData:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 11
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.perception = 5
	c.agility = 5
	c.intelligence = 5
	c.reflexes = 5
	c.awareness = 5
	c.void_ring = 3
	c.character_name = "Kakita Master"
	return c


# -- Cost in koku conversion ---------------------------------------------------


func test_cost_in_koku_koku() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(25.0, "koku"), 25.0)


func test_cost_in_koku_bu() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(5.0, "bu"), 1.0)


func test_cost_in_koku_zeni() -> void:
	assert_eq(ArtisanSystem.cost_in_koku(50.0, "zeni"), 1.0)


# -- Inventory bridge tests ---------------------------------------------------


func test_create_inventory_item_artwork() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 400
	item.item_name = "Painted Screen"
	item.category = Enums.CraftingCategory.ARTWORK
	item.quality_tier = GiftGivingSystem.QualityTier.FINE
	item.is_complete = true
	var inv: Dictionary = ArtisanSystem.create_inventory_item(item)
	assert_eq(inv.get("item_id"), 400)
	assert_eq(inv.get("category"), InventorySystem.ItemCategory.GIFT)
	assert_eq(inv.get("gift_subtype"), GiftGivingSystem.GiftCategory.ART)
	assert_eq(inv.get("crafted_item_id"), 400)
	assert_eq(inv.get("quality_tier"), GiftGivingSystem.QualityTier.FINE)
	assert_eq(inv.get("size"), InventorySystem.ItemSize.SMALL)


func test_create_inventory_item_weapon() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 401
	item.item_name = "Kakita Blade"
	item.category = Enums.CraftingCategory.WEAPONS
	item.quality_tier = GiftGivingSystem.QualityTier.EXCEPTIONAL
	item.is_complete = true
	var inv: Dictionary = ArtisanSystem.create_inventory_item(item)
	assert_eq(inv.get("category"), InventorySystem.ItemCategory.WEAPON)
	assert_eq(inv.get("gift_subtype"), GiftGivingSystem.GiftCategory.WEAPON)
	assert_eq(inv.get("size"), InventorySystem.ItemSize.MEDIUM)


func test_find_crafted_item() -> void:
	var a := ArtisanItemData.new()
	a.item_id = 800
	var b := ArtisanItemData.new()
	b.item_id = 801
	assert_eq(ArtisanSystem.find_crafted_item([a, b], 801), b)
	assert_null(ArtisanSystem.find_crafted_item([a, b], 999))


func test_craft_writeback_adds_inventory_item() -> void:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 60
	c.skills = {"Artisan: Painting": 5}
	c.items = []
	var results: Array = [{
		"action_id": "CRAFT",
		"character_id": 60,
		"effects": {
			"success": true,
			"requires_item_creation": true,
			"quality_tier": GiftGivingSystem.QualityTier.NORMAL,
			"item_name": "Landscape",
			"category": Enums.CraftingCategory.ARTWORK,
			"skill_name": "Artisan: Painting",
			"material_tier": Enums.MaterialTier.COMMON,
		},
	}]
	DayOrchestrator._process_craft_writebacks(
		results, [], [500], {60: c}, {60: 1}, [], [100], 10,
	)
	assert_eq(c.items.size(), 1)
	assert_eq(c.items[0].get("crafted_item_id"), 500)


func test_gift_transfer_adds_inventory_to_recipient() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 600
	item.is_complete = true
	item.item_name = "Fine Vase"
	item.category = Enums.CraftingCategory.ARTWORK
	item.quality_tier = GiftGivingSystem.QualityTier.FINE
	item.current_owner_id = 1
	var giver := _make_character("Crane", "Doji")
	giver.character_id = 1
	giver.items = [ArtisanSystem.create_inventory_item(item)]
	var recip := _make_character("Lion", "Matsu")
	recip.character_id = 2
	recip.items = []
	var results: Array = [{
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"consume_item_id": 600},
	}]
	DayOrchestrator._process_craft_gift_ownership_transfer(
		results, [item], {1: giver, 2: recip}, {}, 50,
	)
	assert_eq(recip.items.size(), 1)
	assert_eq(recip.items[0].get("crafted_item_id"), 600)


func test_history_bonus_syncs_to_inventory() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 700
	item.is_complete = true
	item.item_name = "Legacy Blade"
	item.category = Enums.CraftingCategory.WEAPONS
	item.quality_tier = GiftGivingSystem.QualityTier.FINE
	item.current_owner_id = 10
	var c := _make_rank3_char()
	c.items = [ArtisanSystem.create_inventory_item(item)]
	var initial_bonus: int = c.items[0].get("history_point_bonus", 0)
	DayOrchestrator._process_crafted_item_history([item], {10: c}, 50)
	var updated_bonus: int = c.items[0].get("history_point_bonus", 0)
	assert_true(updated_bonus >= initial_bonus)
	assert_eq(item.get_history_tier_bonus(), updated_bonus)


# -- History orchestrator tests ------------------------------------------------


func test_history_rank3_owner() -> void:
	var c := _make_rank3_char()
	var item := ArtisanItemData.new()
	item.item_id = 100
	item.is_complete = true
	item.current_owner_id = c.character_id
	DayOrchestrator._process_crafted_item_history([item], {c.character_id: c}, 50)
	assert_true(item.history_points >= 1)


func test_history_rank5_owner() -> void:
	var c := _make_rank5_char()
	var item := ArtisanItemData.new()
	item.item_id = 101
	item.is_complete = true
	item.current_owner_id = c.character_id
	DayOrchestrator._process_crafted_item_history([item], {c.character_id: c}, 50)
	var has_rank5: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.OWNED_RANK_5:
			has_rank5 = true
	assert_true(has_rank5)


func test_history_champion_owner() -> void:
	var c := _make_rank5_char()
	c.status = 7.5
	var item := ArtisanItemData.new()
	item.item_id = 102
	item.is_complete = true
	item.current_owner_id = c.character_id
	DayOrchestrator._process_crafted_item_history([item], {c.character_id: c}, 50)
	var has_champ: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.OWNED_CHAMPION:
			has_champ = true
	assert_true(has_champ)


func test_history_gift_at_court() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 201
	item.is_complete = true
	item.current_owner_id = 1
	var c_giver := _make_character("Crane", "Doji")
	c_giver.character_id = 1
	var c_recip := _make_character("Lion", "Matsu")
	c_recip.character_id = 2
	var results: Array = [{
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"consume_item_id": 201},
	}]
	DayOrchestrator._process_craft_gift_ownership_transfer(
		results, [item], {1: c_giver, 2: c_recip},
		{1: {"context_flag": "AT_COURT"}}, 50,
	)
	var has_court: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.GIFTED_AT_COURT:
			has_court = true
	assert_true(has_court)


func test_history_duel_weapon() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 300
	item.is_complete = true
	item.category = Enums.CraftingCategory.WEAPONS
	item.current_owner_id = 1
	var results: Array = [{
		"action_id": "ISSUE_DUEL_CHALLENGE",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"death_occurred": true},
	}]
	DayOrchestrator._process_craft_duel_history(results, [item], 50)
	var has_battle: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.USED_IN_BATTLE:
			has_battle = true
	assert_true(has_battle)


func test_lord_directed_craft_objective() -> void:
	var lord := _make_character("Crane", "Doji")
	lord.character_id = 50
	lord.status = 6.0
	var vassal := _make_character("Crane", "Kakita")
	vassal.character_id = 51
	vassal.school = "Kakita Artisan"
	vassal.lord_id = lord.character_id
	var result: Dictionary = StrategicReview._select_objective_for_vassal(
		lord, vassal, [], {},
	)
	assert_eq(result.get("need_type"), "CRAFT_ITEM")


# -- Executor koku cost tests --------------------------------------------------


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
	ctx.active_wip_item_id = 999
	var result: Dictionary = ActionExecutor._execute_craft(action, c, ctx, _dice)
	var eff: Dictionary = result.get("effects", {})
	assert_true(eff.get("continues_wip", false))
	assert_false(eff.has("koku_cost"))


# -- WIP pipeline tests -------------------------------------------------------


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
	ctx.active_wip_item_id = 999
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


func test_wip_writeback_creates_item() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 73
	c.skills = {"Craft: Weaponsmithing": 5}
	var crafted: Array = []
	var next_topic: Array[int] = [200]
	var next_item: Array[int] = [900]
	var results: Array = [{
		"action_id": "CRAFT",
		"character_id": 73,
		"effects": {
			"creates_wip": true,
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
			"ap_cost": 126,
		},
	}]
	DayOrchestrator._process_craft_wip_writebacks(
		results, crafted, next_item, {73: c}, {73: 1},
		[], next_topic, _dice, 10,
	)
	assert_eq(crafted.size(), 1)
	assert_false(crafted[0].is_complete)
	assert_eq(crafted[0].crafting_ap_invested, 1)
	assert_eq(crafted[0].item_id, 900)


func test_wip_continue_writeback_invests_ap() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 74
	var wip := ArtisanItemData.new()
	wip.item_id = 910
	wip.is_complete = false
	wip.crafting_ap_required = 100
	wip.crafting_ap_invested = 5
	wip.skill_used = "Craft: Weaponsmithing"
	wip.creator_id = 74
	var results: Array = [{
		"action_id": "CRAFT",
		"character_id": 74,
		"effects": {"continues_wip": true, "wip_item_id": 910},
	}]
	DayOrchestrator._process_craft_wip_writebacks(
		results, [wip], [920], {74: c}, {},
		[], [200], _dice, 11,
	)
	assert_eq(wip.crafting_ap_invested, 6)
	assert_false(wip.is_complete)


func test_wip_completion_creates_inventory_item() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 75
	c.skills = {"Craft: Weaponsmithing": 7}
	c.items = []
	var wip := ArtisanItemData.new()
	wip.item_id = 930
	wip.is_complete = false
	wip.crafting_ap_required = 6
	wip.crafting_ap_invested = 5
	wip.skill_used = "Craft: Weaponsmithing"
	wip.creator_id = 75
	wip.item_name = "Master Katana"
	wip.category = Enums.CraftingCategory.WEAPONS
	wip.material_tier = Enums.MaterialTier.COMMON
	wip.base_cost_koku = 5.0
	wip.cost_denomination = "bu"
	var results: Array = [{
		"action_id": "CRAFT",
		"character_id": 75,
		"effects": {"continues_wip": true, "wip_item_id": 930},
	}]
	DayOrchestrator._process_craft_wip_writebacks(
		results, [wip], [940], {75: c}, {},
		[], [300], _dice, 20,
	)
	assert_true(wip.is_complete)


func test_wip_context_injection() -> void:
	var wip := ArtisanItemData.new()
	wip.item_id = 950
	wip.is_complete = false
	wip.creator_id = 80
	var complete_item := ArtisanItemData.new()
	complete_item.item_id = 951
	complete_item.is_complete = true
	complete_item.creator_id = 81
	var ws: Dictionary = {80: {}, 81: {}}
	DayOrchestrator._inject_wip_context([wip, complete_item], ws)
	assert_eq(ws[80].get("active_wip_item_id", -1), 950)
	assert_eq(ws[81].get("active_wip_item_id", -1), -1)


func test_npc_metadata_detects_wip() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.active_wip_item_id = 960
	var c := _make_character("Crab", "Kaiu")
	c.skills = {"Craft: Weaponsmithing": 5}
	var meta: Dictionary = NPCDecisionEngine._build_craft_metadata(ctx, c)
	assert_eq(meta.get("wip_item_id", -1), 960)
	assert_true(meta.get("can_craft", false))


# -- WIP abandonment tests ----------------------------------------------------


func test_wip_abandoned_on_crafter_death() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 90
	c.wounds_taken = 999
	var wip := ArtisanItemData.new()
	wip.item_id = 990
	wip.is_complete = false
	wip.creator_id = 90
	DayOrchestrator._cleanup_dead_character_references(
		[c], {90: c}, [], [], [], [], [], [], [wip],
	)
	assert_true(wip.is_complete)


func test_wip_abandoned_on_crafter_travel() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 91
	c.travel_destination = "some_settlement"
	c.travel_days_remaining = 5
	var wip := ArtisanItemData.new()
	wip.item_id = 991
	wip.is_complete = false
	wip.creator_id = 91
	var ws: Dictionary = {91: {}}
	DayOrchestrator._inject_wip_context([wip], ws, {91: c})
	assert_true(wip.is_complete)
	assert_eq(ws[91].get("active_wip_item_id", -1), -1)


func test_wip_not_abandoned_if_crafter_stationary() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 92
	c.travel_destination = ""
	c.travel_days_remaining = 0
	var wip := ArtisanItemData.new()
	wip.item_id = 992
	wip.is_complete = false
	wip.creator_id = 92
	var ws: Dictionary = {92: {}}
	DayOrchestrator._inject_wip_context([wip], ws, {92: c})
	assert_false(wip.is_complete)
	assert_eq(ws[92].get("active_wip_item_id", -1), 992)


# -- NPC selection audit tests -------------------------------------------------


func test_craft_filtered_when_no_skill() -> void:
	var c := _make_character("Lion", "Matsu")
	c.character_id = 100
	c.skills = {"Kenjutsu": 5}
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 100
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "CRAFT_ITEM"
	var options: Array = NPCDecisionEngine.generate_options(ctx, need, c)
	var has_craft: bool = false
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "CRAFT":
			has_craft = true
	assert_false(has_craft)


func test_craft_filtered_when_insufficient_koku() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 101
	c.skills = {"Craft: Weaponsmithing": 5}
	c.koku = 0.5
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 101
	ctx.settlement_type = Enums.SettlementType.CASTLE
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "CRAFT_ITEM"
	var options: Array = NPCDecisionEngine.generate_options(ctx, need, c)
	var has_craft: bool = false
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "CRAFT":
			has_craft = true
	assert_false(has_craft)


func test_craft_allowed_when_affordable() -> void:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 102
	c.skills = {"Artisan: Painting": 5}
	c.koku = 50.0
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 102
	ctx.settlement_type = Enums.SettlementType.TOWN
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "CRAFT_ITEM"
	var options: Array = NPCDecisionEngine.generate_options(ctx, need, c)
	var has_craft: bool = false
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "CRAFT":
			has_craft = true
	assert_true(has_craft)


func test_settlement_type_injection() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 103
	c.physical_location = "5"
	var s := SettlementData.new()
	s.settlement_id = 5
	s.settlement_type = Enums.SettlementType.FAMILY_CASTLE
	var ws: Dictionary = {103: {}}
	DayOrchestrator._inject_settlement_type([c], [s], ws)
	assert_eq(ws[103].get("settlement_type", -1), Enums.SettlementType.FAMILY_CASTLE)


func test_settlement_type_skips_traveling() -> void:
	var c := _make_character("Crane", "Kakita")
	c.character_id = 104
	c.physical_location = "6"
	c.travel_destination = "somewhere"
	c.travel_days_remaining = 3
	var s := SettlementData.new()
	s.settlement_id = 6
	s.settlement_type = Enums.SettlementType.CITY
	var ws: Dictionary = {104: {}}
	DayOrchestrator._inject_settlement_type([c], [s], ws)
	assert_eq(ws[104].get("settlement_type", -1), -1)


func test_settlement_type_flows_to_craft_metadata() -> void:
	var c := _make_character("Crab", "Kaiu")
	c.character_id = 105
	c.skills = {"Craft: Weaponsmithing": 5}
	c.koku = 100.0
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.settlement_type = Enums.SettlementType.FAMILY_CASTLE
	ctx.character_id = 105
	var meta: Dictionary = NPCDecisionEngine._build_craft_metadata(ctx, c)
	assert_true(meta.get("can_craft", false))
