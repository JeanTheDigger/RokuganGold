extends GutTest
## Tests for the shrine shide settlement proxy (s57.26b).


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_settlement(type: Enums.SettlementType, shrines: Array = []) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 1
	s.settlement_name = "Test Settlement"
	s.settlement_type = type
	s.worship_locations = shrines
	return s


func _make_character(id: int, origami_rank: int = 0) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.skills["Artisan: Origami"] = origami_rank
	return c


# ---------------------------------------------------------------------------
# has_shrine_slot() — eligibility
# ---------------------------------------------------------------------------

func test_temple_has_shrine_slot() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	assert_true(s.has_shrine_slot())


func test_shinden_has_shrine_slot() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.SHINDEN)
	assert_true(s.has_shrine_slot())


func test_village_with_shrine_has_slot() -> void:
	var shrines: Array = [{"type": "village_shrine", "dedicated": false, "fortune": -1}]
	var s: SettlementData = _make_settlement(Enums.SettlementType.VILLAGE, shrines)
	assert_true(s.has_shrine_slot())


func test_village_with_roadside_shrine_has_slot() -> void:
	var shrines: Array = [{"type": "roadside_shrine", "dedicated": false, "fortune": -1}]
	var s: SettlementData = _make_settlement(Enums.SettlementType.VILLAGE, shrines)
	assert_true(s.has_shrine_slot())


func test_city_without_shrine_no_slot() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CITY)
	assert_false(s.has_shrine_slot())


func test_castle_without_shrine_no_slot() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE)
	assert_false(s.has_shrine_slot())


# ---------------------------------------------------------------------------
# OrigamiSystem.shide_quality_from_raises()
# ---------------------------------------------------------------------------

func test_quality_from_raises_normal() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(0), 0)


func test_quality_from_raises_fine() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(1), 1)


func test_quality_from_raises_exceptional() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(2), 2)


func test_quality_from_raises_masterwork() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(3), 3)


func test_quality_from_raises_legendary() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(4), 4)


func test_quality_from_raises_legendary_cap() -> void:
	assert_eq(OrigamiSystem.shide_quality_from_raises(10), 4)


# ---------------------------------------------------------------------------
# OrigamiSystem.shide_worship_fr()
# ---------------------------------------------------------------------------

func test_worship_fr_no_shide() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = -1
	assert_eq(OrigamiSystem.shide_worship_fr(s), 0)


func test_worship_fr_normal_tier() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 0  # Normal
	assert_eq(OrigamiSystem.shide_worship_fr(s), 0)


func test_worship_fr_fine_tier() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 1  # Fine
	assert_eq(OrigamiSystem.shide_worship_fr(s), 1)


func test_worship_fr_exceptional_tier() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 2  # Exceptional
	assert_eq(OrigamiSystem.shide_worship_fr(s), 2)


func test_worship_fr_masterwork_tier() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 3  # Masterwork
	assert_eq(OrigamiSystem.shide_worship_fr(s), 3)


func test_worship_fr_legendary_tier() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 4  # Legendary
	assert_eq(OrigamiSystem.shide_worship_fr(s), 4)


# ---------------------------------------------------------------------------
# OrigamiSystem.craft_shide()
# ---------------------------------------------------------------------------

func test_craft_shide_creates_item() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var next_id: Array = [1]
	var result: Dictionary = OrigamiSystem.craft_shide(c, 2, next_id)
	assert_eq(result.get("quality_tier"), 2)
	assert_eq(c.items.size(), 1)
	assert_eq((c.items[0] as Dictionary).get("item_type"), "shide")
	assert_eq((c.items[0] as Dictionary).get("quality_tier"), 2)
	assert_eq((c.items[0] as Dictionary).get("uses_remaining"), 1)
	assert_eq(next_id[0], 2)


func test_craft_shide_increments_item_id() -> void:
	var c: L5RCharacterData = _make_character(11, 3)
	var next_id: Array = [5]
	var result: Dictionary = OrigamiSystem.craft_shide(c, 0, next_id)
	assert_eq(result.get("item_id"), 5)
	assert_eq(next_id[0], 6)


func test_craft_shide_stores_crafter_id() -> void:
	var c: L5RCharacterData = _make_character(42, 3)
	var next_id: Array = [1]
	OrigamiSystem.craft_shide(c, 1, next_id)
	assert_eq((c.items[0] as Dictionary).get("crafter_id"), 42)


# ---------------------------------------------------------------------------
# OrigamiSystem.place_shide()
# ---------------------------------------------------------------------------

func test_place_shide_removes_from_inventory() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var item: Dictionary = {
		"item_type": "shide", "item_id": 1, "quality_tier": 2, "uses_remaining": 1,
	}
	c.items.append(item)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	OrigamiSystem.place_shide(c, s, item, 100)
	assert_eq(c.items.size(), 0)


func test_place_shide_updates_settlement() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var item: Dictionary = {
		"item_type": "shide", "item_id": 1, "quality_tier": 2, "uses_remaining": 1,
	}
	c.items.append(item)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	OrigamiSystem.place_shide(c, s, item, 100)
	assert_eq(s.shrine_shide_current_tier, 2)
	assert_eq(s.shrine_shide_quality_tier, 2)
	assert_eq(s.shrine_shide_crafter_id, 10)
	assert_eq(s.shrine_shide_ic_day_placed, 100)


func test_place_shide_returns_success() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var item: Dictionary = {
		"item_type": "shide", "item_id": 1, "quality_tier": 1, "uses_remaining": 1,
	}
	c.items.append(item)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	var result: Dictionary = OrigamiSystem.place_shide(c, s, item, 100)
	assert_true(result.get("success", false))
	assert_eq(result.get("new_tier"), 1)
	assert_eq(result.get("old_tier"), -1)


func test_place_shide_replacement_upgrade_detected() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var item: Dictionary = {
		"item_type": "shide", "item_id": 2, "quality_tier": 3, "uses_remaining": 1,
	}
	c.items.append(item)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 1  # Fine already there
	s.shrine_shide_quality_tier = 1
	var result: Dictionary = OrigamiSystem.place_shide(c, s, item, 200)
	assert_true(result.get("is_replacement_upgrade", false))


func test_place_shide_downgrade_not_upgrade() -> void:
	var c: L5RCharacterData = _make_character(10, 3)
	var item: Dictionary = {
		"item_type": "shide", "item_id": 2, "quality_tier": 0, "uses_remaining": 1,
	}
	c.items.append(item)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_shide_current_tier = 2
	var result: Dictionary = OrigamiSystem.place_shide(c, s, item, 200)
	assert_false(result.get("is_replacement_upgrade", true))


# ---------------------------------------------------------------------------
# OrigamiSystem.try_auto_grant_permission()
# ---------------------------------------------------------------------------

func test_auto_grant_requires_custodian() -> void:
	var c: L5RCharacterData = _make_character(20, 3)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_custodian_id = -1  # no custodian
	var granted: bool = OrigamiSystem.try_auto_grant_permission(c, s, {})
	assert_false(granted)


func test_auto_grant_requires_disposition() -> void:
	var custodian: L5RCharacterData = _make_character(99, 0)
	custodian.disposition_values[20] = -5  # negative toward artisan
	var chars: Dictionary = {99: custodian}
	var c: L5RCharacterData = _make_character(20, 3)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_custodian_id = 99
	var granted: bool = OrigamiSystem.try_auto_grant_permission(c, s, chars)
	assert_false(granted)


func test_auto_grant_requires_rank_2() -> void:
	var custodian: L5RCharacterData = _make_character(99, 0)
	custodian.disposition_values[20] = 5
	var chars: Dictionary = {99: custodian}
	var c: L5RCharacterData = _make_character(20, 1)  # rank 1, below minimum
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_custodian_id = 99
	var granted: bool = OrigamiSystem.try_auto_grant_permission(c, s, chars)
	assert_false(granted)


func test_auto_grant_success() -> void:
	var custodian: L5RCharacterData = _make_character(99, 0)
	custodian.disposition_values[20] = 0  # neutral is enough
	var chars: Dictionary = {99: custodian}
	var c: L5RCharacterData = _make_character(20, 2)  # minimum rank 2
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_custodian_id = 99
	var granted: bool = OrigamiSystem.try_auto_grant_permission(c, s, chars)
	assert_true(granted)
	assert_eq(s.shrine_shide_permission, 20)


func test_auto_grant_dead_custodian_skipped() -> void:
	var custodian: L5RCharacterData = _make_character(99, 0)
	custodian.disposition_values[20] = 10
	custodian.wounds_taken = 999  # dead
	var chars: Dictionary = {99: custodian}
	var c: L5RCharacterData = _make_character(20, 3)
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	s.shrine_custodian_id = 99
	var granted: bool = OrigamiSystem.try_auto_grant_permission(c, s, chars)
	assert_false(granted)


# ---------------------------------------------------------------------------
# Provenance TN table
# ---------------------------------------------------------------------------

func test_provenance_tn_legendary() -> void:
	assert_eq(OrigamiSystem.SHIDE_PROVENANCE_TN.get(4), 15)


func test_provenance_tn_masterwork() -> void:
	assert_eq(OrigamiSystem.SHIDE_PROVENANCE_TN.get(3), 20)


func test_provenance_tn_exceptional() -> void:
	assert_eq(OrigamiSystem.SHIDE_PROVENANCE_TN.get(2), 25)


func test_provenance_tn_fine() -> void:
	assert_eq(OrigamiSystem.SHIDE_PROVENANCE_TN.get(1), 30)


func test_provenance_tn_normal() -> void:
	assert_eq(OrigamiSystem.SHIDE_PROVENANCE_TN.get(0), 35)


# ---------------------------------------------------------------------------
# Constants locked values (s57.26b)
# ---------------------------------------------------------------------------

func test_craft_tn() -> void:
	assert_eq(OrigamiSystem.SHIDE_CRAFT_TN, 15)


func test_grace_days() -> void:
	assert_eq(OrigamiSystem.SHIDE_PERMISSION_GRACE_DAYS, 90)


func test_auto_grant_min_rank() -> void:
	assert_eq(OrigamiSystem.SHIDE_AUTO_GRANT_MIN_RANK, 2)


func test_worship_fr_cap() -> void:
	assert_eq(OrigamiSystem.SHIDE_WORSHIP_FR_CAP, 5)
