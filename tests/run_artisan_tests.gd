extends SceneTree
## Minimal test runner for ArtisanSystem.

var _pass_count: int = 0
var _fail_count: int = 0
var _dice: DiceEngine


func _init() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	_test_base_tn_zeni_low()
	_test_base_tn_bu_mid()
	_test_base_tn_koku_high()
	_test_base_tn_over_bracket()
	_test_quality_tier_mundane()
	_test_quality_tier_fine()
	_test_quality_tier_exceptional()
	_test_quality_tier_masterwork()
	_test_quality_tier_legendary()
	_test_crafting_time_metal_zeni()
	_test_crafting_time_glass_bu()
	_test_crafting_time_other_koku()
	_test_ap_cost_katana()
	_test_ap_cost_painting()
	_test_material_availability_village()
	_test_material_availability_city()
	_test_material_availability_capital()
	_test_clan_material_crab()
	_test_exceptional_weapon_rank_7()
	_test_exceptional_weapon_rank_6_fails()
	_test_kaiu_exceptional_at_rank_5()
	_test_sacred_weapon_eligible()
	_test_sacred_weapon_wrong_clan()
	_test_special_quality_allocation()
	_test_sacred_weapon_check()
	_test_resolve_normal_artwork()
	_test_resolve_exceptional_failure()
	_test_create_crafted_item()
	_test_create_wip()
	_test_invest_ap()
	_test_history_points_accumulate()
	_test_history_dedup()
	_test_history_tier_bonus()
	_test_has_any_craft_skill()
	_test_material_free_raises()
	_test_find_crafted_item()

	print("\n=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  FAIL: %s" % msg)


func _make_char(clan: String = "Crab", family: String = "Kaiu") -> L5RCharacterData:
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
	return c


# -- TN tests ------------------------------------------------------------------

func _test_base_tn_zeni_low() -> void:
	_assert(ArtisanSystem.get_base_tn(3.0, "zeni") == 10, "3 zeni -> TN 10")

func _test_base_tn_bu_mid() -> void:
	_assert(ArtisanSystem.get_base_tn(5.0, "bu") == 15, "5 bu -> TN 15")

func _test_base_tn_koku_high() -> void:
	_assert(ArtisanSystem.get_base_tn(25.0, "koku") == 30, "25 koku -> TN 30")

func _test_base_tn_over_bracket() -> void:
	var tn: int = ArtisanSystem.get_base_tn(30.0, "koku")
	_assert(tn == 40, "30 koku -> TN 40 (5 over top bracket -> +5)")

# -- Quality tier tests --------------------------------------------------------

func _test_quality_tier_mundane() -> void:
	var tier := ArtisanSystem.determine_quality_tier(10)
	_assert(tier == GiftGivingSystem.QualityTier.MUNDANE, "roll 10 -> mundane")

func _test_quality_tier_fine() -> void:
	var tier := ArtisanSystem.determine_quality_tier(30)
	_assert(tier == GiftGivingSystem.QualityTier.FINE, "roll 30 -> fine")

func _test_quality_tier_exceptional() -> void:
	var tier := ArtisanSystem.determine_quality_tier(40)
	_assert(tier == GiftGivingSystem.QualityTier.EXCEPTIONAL, "roll 40 -> exceptional")

func _test_quality_tier_masterwork() -> void:
	var tier := ArtisanSystem.determine_quality_tier(50)
	_assert(tier == GiftGivingSystem.QualityTier.MASTERWORK, "roll 50 -> masterwork")

func _test_quality_tier_legendary() -> void:
	var tier := ArtisanSystem.determine_quality_tier(60)
	_assert(tier == GiftGivingSystem.QualityTier.LEGENDARY, "roll 60 -> legendary")

# -- Crafting time tests -------------------------------------------------------

func _test_crafting_time_metal_zeni() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.STEEL, "zeni") == ArtisanSystem.TimeUnit.DAYS,
		"steel+zeni -> days",
	)

func _test_crafting_time_glass_bu() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.METAL_GLASS, "bu") == ArtisanSystem.TimeUnit.DAYS,
		"glass+bu -> days",
	)

func _test_crafting_time_other_koku() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "koku") == ArtisanSystem.TimeUnit.DAYS,
		"other+koku -> days",
	)

# -- AP cost tests -------------------------------------------------------------

func _test_ap_cost_katana() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(25.0, "koku", Enums.MaterialType.STEEL)
	_assert(ap >= 1, "katana AP cost >= 1 (got %d)" % ap)

func _test_ap_cost_painting() -> void:
	var ap: int = ArtisanSystem.get_ap_cost(3.0, "bu", Enums.MaterialType.OTHER)
	_assert(ap >= 1, "painting AP cost >= 1 (got %d)" % ap)

# -- Material availability tests -----------------------------------------------

func _test_material_availability_village() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.VILLAGE)
	_assert(Enums.MaterialTier.COMMON in avail, "village has common materials")
	_assert(Enums.MaterialTier.RARE not in avail, "village no rare materials")

func _test_material_availability_city() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.CITY)
	_assert(Enums.MaterialTier.RARE in avail, "city has rare materials")
	_assert(Enums.MaterialTier.LEGENDARY not in avail, "city no legendary materials")

func _test_material_availability_capital() -> void:
	var avail: Array = ArtisanSystem.get_material_availability(Enums.SettlementType.IMPERIAL_CAPITAL)
	_assert(Enums.MaterialTier.LEGENDARY in avail, "capital has legendary materials")

# -- Clan material tests -------------------------------------------------------

func _test_clan_material_crab() -> void:
	var mat: Dictionary = ArtisanSystem.get_clan_material("Crab")
	_assert(mat.get("name", "") == "Kaiu Steel", "Crab has Kaiu Steel")
	_assert(mat.get("tier") == Enums.MaterialTier.RARE, "Kaiu Steel is Rare tier")

# -- Exceptional weapon tests --------------------------------------------------

func _test_exceptional_weapon_rank_7() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Craft: Weaponsmithing"] = 7
	_assert(ArtisanSystem.can_attempt_exceptional_weapon(c), "rank 7 -> exceptional eligible")

func _test_exceptional_weapon_rank_6_fails() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Craft: Weaponsmithing"] = 6
	_assert(not ArtisanSystem.can_attempt_exceptional_weapon(c), "rank 6 -> not eligible")

func _test_kaiu_exceptional_at_rank_5() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 5
	_assert(ArtisanSystem.can_attempt_exceptional_weapon(c), "Kaiu rank 5 -> eligible")

func _test_sacred_weapon_eligible() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	_assert(ArtisanSystem.can_attempt_sacred_weapon(c), "Crab rank 7 -> sacred eligible")

func _test_sacred_weapon_wrong_clan() -> void:
	var c := _make_char("Spider", "Daigotsu")
	c.skills["Craft: Weaponsmithing"] = 7
	_assert(not ArtisanSystem.can_attempt_sacred_weapon(c), "Spider -> not sacred eligible")

# -- Special quality allocation ------------------------------------------------

func _test_special_quality_allocation() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		6, [Enums.WeaponSpecialQuality.BALANCED, Enums.WeaponSpecialQuality.SIGNATURE] as Array[Enums.WeaponSpecialQuality],
	)
	_assert(result.get("allocated", []).size() == 2, "2 qualities allocated (4+2=6 raises)")
	_assert(result.get("raises_remaining", -1) == 0, "0 raises remaining")

# -- Sacred weapon check -------------------------------------------------------

func _test_sacred_weapon_check() -> void:
	var c := _make_char("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(6, c)
	_assert(result.get("can_forge", false), "Kaiu 6 raises -> can forge sacred")
	var result2: Dictionary = ArtisanSystem.check_sacred_weapon(5, c)
	_assert(not result2.get("can_forge", true), "Kaiu 5 raises -> cannot forge sacred")

# -- Crafting resolution -------------------------------------------------------

func _test_resolve_normal_artwork() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 5
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Artisan: Painting", 15, Enums.MaterialTier.COMMON, false,
	)
	_assert(result.has("total"), "resolve returns total")
	_assert(result.has("quality_tier"), "resolve returns quality_tier")
	_assert(not result.get("item_ruined", true), "normal craft -> not ruined")

func _test_resolve_exceptional_failure() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 5
	c.agility = 1
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Craft: Weaponsmithing", 99, Enums.MaterialTier.COMMON, true,
	)
	_assert(result.get("item_ruined", false), "exceptional failure -> item ruined")

# -- Item creation -------------------------------------------------------------

func _test_create_crafted_item() -> void:
	var c := _make_char("Crane", "Kakita")
	var craft_result := {"quality_tier": GiftGivingSystem.QualityTier.FINE, "total": 30}
	var item: ArtisanItemData = ArtisanSystem.create_crafted_item(
		c, craft_result, 1, "Test Painting", Enums.CraftingCategory.ARTWORK,
		Enums.CraftingTrack.ARTISAN, "Artisan: Painting",
		Enums.MaterialTier.COMMON, "Standard materials", 3.0, "bu", 100,
	)
	_assert(item != null, "created item is not null")
	_assert(item.item_name == "Test Painting", "item name matches")
	_assert(item.quality_tier == GiftGivingSystem.QualityTier.FINE, "quality tier matches")
	_assert(item.is_complete, "item is complete")
	_assert(item.creator_clan == "Crane", "creator clan tracked")

func _test_create_wip() -> void:
	var c := _make_char("Crab", "Kaiu")
	var item: ArtisanItemData = ArtisanSystem.create_work_in_progress(
		c, 2, "WIP Katana", Enums.CraftingCategory.WEAPONS,
		Enums.CraftingTrack.CRAFT, "Craft: Weaponsmithing",
		Enums.MaterialTier.COMMON, "Standard steel", 25.0, "koku",
		Enums.MaterialType.STEEL,
	)
	_assert(item != null, "WIP item is not null")
	_assert(not item.is_complete, "WIP is not complete")
	_assert(item.crafting_ap_required > 0, "WIP has AP cost > 0 (got %d)" % item.crafting_ap_required)

func _test_invest_ap() -> void:
	var c := _make_char("Crab", "Kaiu")
	var item: ArtisanItemData = ArtisanSystem.create_work_in_progress(
		c, 3, "WIP Katana", Enums.CraftingCategory.WEAPONS,
		Enums.CraftingTrack.CRAFT, "Craft: Weaponsmithing",
		Enums.MaterialTier.COMMON, "Standard steel", 25.0, "koku",
		Enums.MaterialType.STEEL,
	)
	var r1: Dictionary = ArtisanSystem.invest_ap(item, 1)
	_assert(r1.get("invested", false), "first AP invested")
	_assert(not r1.get("ready_for_roll", true), "not ready after 1 AP")
	var remaining: int = item.crafting_ap_required - item.crafting_ap_invested
	ArtisanSystem.invest_ap(item, remaining)
	var r2: Dictionary = ArtisanSystem.invest_ap(item, 1)
	_assert(r2.get("ready_for_roll", false), "ready after full AP investment")

# -- History points ------------------------------------------------------------

func _test_history_points_accumulate() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 100, "Test lord")
	_assert(item.history_points == 1, "1 point for rank 3 owner")
	item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, 200, "Battle of X")
	_assert(item.history_points == 2, "2 points total")

func _test_history_dedup() -> void:
	var item := ArtisanItemData.new()
	item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 100, "Same lord")
	item.add_history_event(Enums.HistoryEventType.OWNED_RANK_3, 200, "Same lord")
	_assert(item.history_points == 1, "dedup: same type+description -> 1 point")

func _test_history_tier_bonus() -> void:
	var item := ArtisanItemData.new()
	_assert(item.get_history_tier_bonus() == 0, "0 history -> 0 bonus")
	for i: int in range(3):
		item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, i * 100, "Battle %d" % i)
	_assert(item.get_history_tier_bonus() == 1, "3 points -> tier 1 bonus (+1 FR)")

# -- Utility tests -------------------------------------------------------------

func _test_has_any_craft_skill() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 3
	_assert(ArtisanSystem.has_any_craft_skill(c), "has Artisan: Painting -> true")
	var c2 := _make_char("Lion", "Matsu")
	_assert(not ArtisanSystem.has_any_craft_skill(c2), "no craft skill -> false")

func _test_material_free_raises() -> void:
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.COMMON] == 0, "Common -> 0 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.UNCOMMON] == 1, "Uncommon -> 1 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.RARE] == 2, "Rare -> 2 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.LEGENDARY] == 3, "Legendary -> 3 FR")

func _test_find_crafted_item() -> void:
	var a := ArtisanItemData.new()
	a.item_id = 800
	var b := ArtisanItemData.new()
	b.item_id = 801
	_assert(ArtisanSystem.find_crafted_item([a, b], 801) == b, "finds item 801")
	_assert(ArtisanSystem.find_crafted_item([a, b], 999) == null, "returns null for missing")
