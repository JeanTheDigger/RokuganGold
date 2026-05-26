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
	_test_npc_select_artwork()
	_test_npc_select_no_skill()
	_test_npc_material_clan_specific()
	_test_npc_material_fallback()
	_test_is_artisan_school()
	_test_is_smith_school()
	_test_has_any_craft_skill()
	_test_material_free_raises()
	_test_history_rank3_check()
	_test_history_rank5_check()
	_test_history_champion_check()
	_test_history_gift_ownership_transfer()
	_test_history_gift_at_court()
	_test_history_duel_weapon()
	_test_lord_directed_craft_objective()
	_test_create_inventory_item_artwork()
	_test_create_inventory_item_weapon()
	_test_craft_writeback_adds_inventory_item()
	_test_gift_transfer_adds_inventory_to_recipient()
	_test_history_bonus_syncs_to_inventory()
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
	_assert(ArtisanSystem.get_base_tn(3.0, "zeni") == 10, "3 zeni → TN 10")

func _test_base_tn_bu_mid() -> void:
	_assert(ArtisanSystem.get_base_tn(5.0, "bu") == 15, "5 bu → TN 15")

func _test_base_tn_koku_high() -> void:
	_assert(ArtisanSystem.get_base_tn(25.0, "koku") == 30, "25 koku → TN 30")

func _test_base_tn_over_bracket() -> void:
	var tn: int = ArtisanSystem.get_base_tn(30.0, "koku")
	_assert(tn == 40, "30 koku → TN 40 (5 over top bracket → +5)")

# -- Quality tier tests --------------------------------------------------------

func _test_quality_tier_mundane() -> void:
	var tier := ArtisanSystem.determine_quality_tier(10)
	_assert(tier == GiftGivingSystem.QualityTier.MUNDANE, "roll 10 → mundane")

func _test_quality_tier_fine() -> void:
	var tier := ArtisanSystem.determine_quality_tier(30)
	_assert(tier == GiftGivingSystem.QualityTier.FINE, "roll 30 → fine")

func _test_quality_tier_exceptional() -> void:
	var tier := ArtisanSystem.determine_quality_tier(40)
	_assert(tier == GiftGivingSystem.QualityTier.EXCEPTIONAL, "roll 40 → exceptional")

func _test_quality_tier_masterwork() -> void:
	var tier := ArtisanSystem.determine_quality_tier(50)
	_assert(tier == GiftGivingSystem.QualityTier.MASTERWORK, "roll 50 → masterwork")

func _test_quality_tier_legendary() -> void:
	var tier := ArtisanSystem.determine_quality_tier(60)
	_assert(tier == GiftGivingSystem.QualityTier.LEGENDARY, "roll 60 → legendary")

# -- Crafting time tests -------------------------------------------------------

func _test_crafting_time_metal_zeni() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.STEEL, "zeni") == ArtisanSystem.TimeUnit.DAYS,
		"steel+zeni → days",
	)

func _test_crafting_time_glass_bu() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.METAL_GLASS, "bu") == ArtisanSystem.TimeUnit.DAYS,
		"glass+bu → days",
	)

func _test_crafting_time_other_koku() -> void:
	_assert(
		ArtisanSystem.get_crafting_time_unit(Enums.MaterialType.OTHER, "koku") == ArtisanSystem.TimeUnit.DAYS,
		"other+koku → days",
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
	_assert(ArtisanSystem.can_attempt_exceptional_weapon(c), "rank 7 → exceptional eligible")

func _test_exceptional_weapon_rank_6_fails() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Craft: Weaponsmithing"] = 6
	_assert(not ArtisanSystem.can_attempt_exceptional_weapon(c), "rank 6 → not eligible")

func _test_kaiu_exceptional_at_rank_5() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 5
	_assert(ArtisanSystem.can_attempt_exceptional_weapon(c), "Kaiu rank 5 → eligible")

func _test_sacred_weapon_eligible() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 7
	_assert(ArtisanSystem.can_attempt_sacred_weapon(c), "Crab rank 7 → sacred eligible")

func _test_sacred_weapon_wrong_clan() -> void:
	var c := _make_char("Spider", "Daigotsu")
	c.skills["Craft: Weaponsmithing"] = 7
	_assert(not ArtisanSystem.can_attempt_sacred_weapon(c), "Spider → not sacred eligible")

# -- Special quality allocation ------------------------------------------------

func _test_special_quality_allocation() -> void:
	var result: Dictionary = ArtisanSystem.allocate_special_qualities(
		6, [Enums.WeaponSpecialQuality.BALANCED, Enums.WeaponSpecialQuality.SIGNATURE],
	)
	_assert(result.get("allocated", []).size() == 2, "2 qualities allocated (4+2=6 raises)")
	_assert(result.get("raises_remaining", -1) == 0, "0 raises remaining")

# -- Sacred weapon check -------------------------------------------------------

func _test_sacred_weapon_check() -> void:
	var c := _make_char("Crab", "Kaiu")
	var result: Dictionary = ArtisanSystem.check_sacred_weapon(6, c)
	_assert(result.get("can_forge", false), "Kaiu 6 raises → can forge sacred")
	var result2: Dictionary = ArtisanSystem.check_sacred_weapon(5, c)
	_assert(not result2.get("can_forge", true), "Kaiu 5 raises → cannot forge sacred")

# -- Crafting resolution -------------------------------------------------------

func _test_resolve_normal_artwork() -> void:
	var c := _make_char("Crane", "Kakita")
	c.skills["Artisan: Painting"] = 5
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Artisan: Painting", 15, Enums.MaterialTier.COMMON, false,
	)
	_assert(result.has("total"), "resolve returns total")
	_assert(result.has("quality_tier"), "resolve returns quality_tier")
	_assert(not result.get("item_ruined", true), "normal craft → not ruined")

func _test_resolve_exceptional_failure() -> void:
	var c := _make_char("Crab", "Kaiu")
	c.skills["Craft: Weaponsmithing"] = 5
	c.traits[Enums.Trait.AGILITY] = 1
	var result: Dictionary = ArtisanSystem.resolve_crafting(
		c, _dice, "Craft: Weaponsmithing", 99, Enums.MaterialTier.COMMON, true,
	)
	_assert(result.get("item_ruined", false), "exceptional failure → item ruined")

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
	_assert(item.history_points == 1, "dedup: same type+description → 1 point")

func _test_history_tier_bonus() -> void:
	var item := ArtisanItemData.new()
	_assert(item.get_history_tier_bonus() == 0, "0 history → 0 bonus")
	for i: int in range(3):
		item.add_history_event(Enums.HistoryEventType.USED_IN_BATTLE, i * 100, "Battle %d" % i)
	_assert(item.get_history_tier_bonus() == 1, "3 points → tier 1 bonus (+1 FR)")

# -- NPC craft selection -------------------------------------------------------

func _test_npc_select_artwork() -> void:
	var c := _make_char("Crane", "Kakita")
	c.school = "Kakita Artisan"
	c.skills["Artisan: Painting"] = 5
	var meta: Dictionary = ArtisanSystem.npc_select_craft_action(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.ARTWORK,
	)
	_assert(meta.get("can_craft", false), "artisan can craft")
	_assert(meta.get("skill_name", "") == "Artisan: Painting", "selects painting skill")

func _test_npc_select_no_skill() -> void:
	var c := _make_char("Crane", "Kakita")
	var meta: Dictionary = ArtisanSystem.npc_select_craft_action(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.ARTWORK,
	)
	_assert(not meta.get("can_craft", true), "no skill → cannot craft")

# -- NPC material selection ----------------------------------------------------

func _test_npc_material_clan_specific() -> void:
	var c := _make_char("Crab", "Kaiu")
	var mat: Dictionary = ArtisanSystem.select_best_material_for_npc(
		c, Enums.SettlementType.CITY, Enums.CraftingCategory.WEAPONS,
	)
	_assert(mat.get("name", "") == "Kaiu Steel", "Crab at city → Kaiu Steel")
	_assert(mat.get("tier") == Enums.MaterialTier.RARE, "Kaiu Steel is Rare")

func _test_npc_material_fallback() -> void:
	var c := _make_char("Crab", "Kaiu")
	var mat: Dictionary = ArtisanSystem.select_best_material_for_npc(
		c, Enums.SettlementType.VILLAGE, Enums.CraftingCategory.WEAPONS,
	)
	_assert(mat.get("tier") == Enums.MaterialTier.COMMON, "village → common (Kaiu Steel not available)")

# -- Utility functions ---------------------------------------------------------

func _test_is_artisan_school() -> void:
	var c := _make_char()
	c.school = "Kakita Artisan"
	_assert(ArtisanSystem.is_artisan_school(c), "Kakita Artisan is artisan")
	c.school = "Bayushi Bushi"
	_assert(not ArtisanSystem.is_artisan_school(c), "Bayushi Bushi is not artisan")

func _test_is_smith_school() -> void:
	var c := _make_char()
	c.school = "Kaiu Engineer"
	_assert(ArtisanSystem.is_smith_school(c), "Kaiu Engineer is smith")
	c.school = "Doji Courtier"
	_assert(not ArtisanSystem.is_smith_school(c), "Doji Courtier is not smith")

func _test_has_any_craft_skill() -> void:
	var c := _make_char()
	c.skills["Craft: Weaponsmithing"] = 3
	_assert(ArtisanSystem.has_any_craft_skill(c), "has craft skill")
	c.skills.clear()
	_assert(not ArtisanSystem.has_any_craft_skill(c), "no craft skill")

func _test_material_free_raises() -> void:
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.COMMON] == 0, "common → 0 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.UNCOMMON] == 1, "uncommon → 1 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.RARE] == 2, "rare → 2 FR")
	_assert(ArtisanSystem.MATERIAL_FREE_RAISES[Enums.MaterialTier.LEGENDARY] == 3, "legendary → 3 FR")


func _make_rank3_char() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 10
	c.clan = "Crane"
	c.family = "Kakita"
	c.school = ""
	c.skills = {}
	c.stamina = 4
	c.willpower = 4
	c.strength = 4
	c.perception = 4
	c.agility = 4
	c.intelligence = 4
	c.reflexes = 4
	c.awareness = 4
	c.void_ring = 3
	c.honor = 5.0
	c.glory = 3.0
	c.status = 3.0
	c.character_name = "Kakita Artisan"
	return c


func _make_rank5_char() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 11
	c.clan = "Crane"
	c.family = "Kakita"
	c.school = ""
	c.skills = {}
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.perception = 5
	c.agility = 5
	c.intelligence = 5
	c.reflexes = 5
	c.awareness = 5
	c.void_ring = 3
	c.honor = 5.0
	c.glory = 3.0
	c.status = 3.0
	c.character_name = "Kakita Master"
	return c


func _test_history_rank3_check() -> void:
	var c := _make_rank3_char()
	var item := ArtisanItemData.new()
	item.item_id = 100
	item.is_complete = true
	item.current_owner_id = c.character_id
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {c.character_id: c}
	DayOrchestrator._process_crafted_item_history(crafted, chars_by_id, 50)
	_assert(item.history_points >= 1, "rank 3 owner adds OWNED_RANK_3 history")


func _test_history_rank5_check() -> void:
	var c := _make_rank5_char()
	var item := ArtisanItemData.new()
	item.item_id = 101
	item.is_complete = true
	item.current_owner_id = c.character_id
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {c.character_id: c}
	DayOrchestrator._process_crafted_item_history(crafted, chars_by_id, 50)
	var has_rank5: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.OWNED_RANK_5:
			has_rank5 = true
	_assert(has_rank5, "rank 5 owner adds OWNED_RANK_5 history")


func _test_history_champion_check() -> void:
	var c := _make_rank5_char()
	c.status = 7.5
	var item := ArtisanItemData.new()
	item.item_id = 102
	item.is_complete = true
	item.current_owner_id = c.character_id
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {c.character_id: c}
	DayOrchestrator._process_crafted_item_history(crafted, chars_by_id, 50)
	var has_champ: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.OWNED_CHAMPION:
			has_champ = true
	_assert(has_champ, "champion owner adds OWNED_CHAMPION history")


func _test_history_gift_ownership_transfer() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 200
	item.is_complete = true
	item.current_owner_id = 1
	var c_giver := _make_char("Crane", "Doji")
	c_giver.character_id = 1
	var c_recip := _make_char("Lion", "Matsu")
	c_recip.character_id = 2
	var results: Array = [{
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"consume_item_id": 200},
	}]
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {1: c_giver, 2: c_recip}
	var ws: Dictionary = {}
	DayOrchestrator._process_craft_gift_ownership_transfer(
		results, crafted, chars_by_id, ws, 50,
	)
	_assert(item.current_owner_id == 2, "gift transfers crafted item ownership")


func _test_history_gift_at_court() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 201
	item.is_complete = true
	item.current_owner_id = 1
	var c_giver := _make_char("Crane", "Doji")
	c_giver.character_id = 1
	var c_recip := _make_char("Lion", "Matsu")
	c_recip.character_id = 2
	var results: Array = [{
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"consume_item_id": 201},
	}]
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {1: c_giver, 2: c_recip}
	var ws: Dictionary = {1: {"context_flag": "AT_COURT"}}
	DayOrchestrator._process_craft_gift_ownership_transfer(
		results, crafted, chars_by_id, ws, 50,
	)
	var has_court: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.GIFTED_AT_COURT:
			has_court = true
	_assert(has_court, "gift at court adds GIFTED_AT_COURT history")


func _test_history_duel_weapon() -> void:
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
	var crafted: Array = [item]
	DayOrchestrator._process_craft_duel_history(results, crafted, 50)
	var has_battle: bool = false
	for evt: Dictionary in item.history_events:
		if evt.get("type") == Enums.HistoryEventType.USED_IN_BATTLE:
			has_battle = true
	_assert(has_battle, "duel to death adds USED_IN_BATTLE to weapon")


func _test_lord_directed_craft_objective() -> void:
	var lord := _make_char("Crane", "Doji")
	lord.character_id = 50
	lord.status = 6.0
	var vassal := _make_char("Crane", "Kakita")
	vassal.character_id = 51
	vassal.school = "Kakita Artisan"
	vassal.lord_id = lord.character_id
	var result: Dictionary = StrategicReview._select_objective_for_vassal(
		lord, vassal, [], {},
	)
	_assert(result.get("need_type") == "CRAFT_ITEM",
		"idle artisan vassal gets CRAFT_ITEM from lord")


func _test_create_inventory_item_artwork() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 400
	item.item_name = "Painted Screen"
	item.category = Enums.CraftingCategory.ARTWORK
	item.quality_tier = GiftGivingSystem.QualityTier.FINE
	item.is_complete = true
	var inv: Dictionary = ArtisanSystem.create_inventory_item(item)
	_assert(inv.get("item_id") == 400, "inventory item_id matches crafted item")
	_assert(inv.get("category") == InventorySystem.ItemCategory.GIFT,
		"artwork maps to GIFT category")
	_assert(inv.get("gift_subtype") == GiftGivingSystem.GiftCategory.ART,
		"artwork maps to ART gift subtype")
	_assert(inv.get("crafted_item_id") == 400,
		"crafted_item_id links back to ArtisanItemData")
	_assert(inv.get("quality_tier") == GiftGivingSystem.QualityTier.FINE,
		"quality tier preserved")
	_assert(inv.get("size") == InventorySystem.ItemSize.SMALL,
		"artwork defaults to SMALL size")


func _test_create_inventory_item_weapon() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 401
	item.item_name = "Kakita Blade"
	item.category = Enums.CraftingCategory.WEAPONS
	item.quality_tier = GiftGivingSystem.QualityTier.EXCEPTIONAL
	item.is_complete = true
	var inv: Dictionary = ArtisanSystem.create_inventory_item(item)
	_assert(inv.get("category") == InventorySystem.ItemCategory.WEAPON,
		"weapon maps to WEAPON category")
	_assert(inv.get("gift_subtype") == GiftGivingSystem.GiftCategory.WEAPON,
		"weapon maps to WEAPON gift subtype")
	_assert(inv.get("size") == InventorySystem.ItemSize.MEDIUM,
		"non-artwork defaults to MEDIUM size")


func _test_craft_writeback_adds_inventory_item() -> void:
	var c := _make_char("Crane", "Kakita")
	c.character_id = 60
	c.skills = {"Artisan: Painting": 5}
	c.items = []
	var crafted: Array = []
	var topics: Array = []
	var next_topic: Array[int] = [100]
	var next_item: Array[int] = [500]
	var result: Dictionary = {
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
	}
	var results: Array = [result]
	var chars: Dictionary = {60: c}
	var prov_map: Dictionary = {60: 1}
	DayOrchestrator._process_craft_writebacks(
		results, crafted, next_item, chars, prov_map, topics, next_topic, 10,
	)
	_assert(c.items.size() == 1, "crafted item added to character inventory")
	_assert(c.items[0].get("crafted_item_id") == 500,
		"inventory item links to crafted_item_id")


func _test_gift_transfer_adds_inventory_to_recipient() -> void:
	var item := ArtisanItemData.new()
	item.item_id = 600
	item.is_complete = true
	item.item_name = "Fine Vase"
	item.category = Enums.CraftingCategory.ARTWORK
	item.quality_tier = GiftGivingSystem.QualityTier.FINE
	item.current_owner_id = 1
	var giver := _make_char("Crane", "Doji")
	giver.character_id = 1
	giver.items = [ArtisanSystem.create_inventory_item(item)]
	var recip := _make_char("Lion", "Matsu")
	recip.character_id = 2
	recip.items = []
	var results: Array = [{
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"consume_item_id": 600},
	}]
	var crafted: Array = [item]
	var chars_by_id: Dictionary = {1: giver, 2: recip}
	DayOrchestrator._process_craft_gift_ownership_transfer(
		results, crafted, chars_by_id, {}, 50,
	)
	_assert(recip.items.size() == 1,
		"recipient gets inventory item on gift transfer")
	_assert(recip.items[0].get("crafted_item_id") == 600,
		"recipient inventory links to crafted_item_id")


func _test_history_bonus_syncs_to_inventory() -> void:
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
	var crafted: Array = [item]
	var chars: Dictionary = {10: c}
	DayOrchestrator._process_crafted_item_history(crafted, chars, 50)
	var updated_bonus: int = c.items[0].get("history_point_bonus", 0)
	_assert(updated_bonus >= initial_bonus,
		"inventory history_point_bonus synced after history accumulation")
	_assert(item.get_history_tier_bonus() == updated_bonus,
		"inventory bonus matches ArtisanItemData live bonus")


func _test_find_crafted_item() -> void:
	var a := ArtisanItemData.new()
	a.item_id = 800
	var b := ArtisanItemData.new()
	b.item_id = 801
	var crafted: Array = [a, b]
	_assert(ArtisanSystem.find_crafted_item(crafted, 801) == b,
		"find_crafted_item returns correct item")
	_assert(ArtisanSystem.find_crafted_item(crafted, 999) == null,
		"find_crafted_item returns null for missing")
