extends GutTest
## Tests for InventorySystem per GDD s12.11.


# -- Helpers ------------------------------------------------------------------

func _make_item(id: int, size: int = 1, tier: int = 0, is_evidence: bool = false) -> Dictionary:
	return InventorySystem.create_item(
		id, "test_item_%d" % id,
		InventorySystem.ItemCategory.DOCUMENT,
		size as InventorySystem.ItemSize,
		1, is_evidence
	)


func _make_on_person(id: int, size: int = 1) -> Dictionary:
	var item := _make_item(id, size)
	item["storage_tier"] = InventorySystem.StorageTier.ON_PERSON
	return item


func _make_in_quarters(id: int, size: int = 1) -> Dictionary:
	var item := _make_item(id, size)
	item["storage_tier"] = InventorySystem.StorageTier.CURRENT_QUARTERS
	return item


# -- Capacity tests -----------------------------------------------------------

func test_court_formal_capacity():
	assert_eq(InventorySystem.get_on_person_capacity(InventorySystem.Outfit.COURT_FORMAL), 3)


func test_traveling_capacity():
	assert_eq(InventorySystem.get_on_person_capacity(InventorySystem.Outfit.TRAVELING), 8)


func test_heavy_armor_capacity():
	assert_eq(InventorySystem.get_on_person_capacity(InventorySystem.Outfit.HEAVY_ARMOR), 3)


func test_used_slots_counts_correctly():
	var items: Array = [_make_on_person(1, 1), _make_on_person(2, 2), _make_in_quarters(3, 3)]
	assert_eq(InventorySystem.get_used_slots(items, InventorySystem.StorageTier.ON_PERSON), 3)
	assert_eq(InventorySystem.get_used_slots(items, InventorySystem.StorageTier.CURRENT_QUARTERS), 3)


func test_can_add_item_within_capacity():
	var items: Array = [_make_on_person(1, 1)]
	var new_item := _make_item(2, 2)
	assert_true(InventorySystem.can_add_item(items, new_item, InventorySystem.StorageTier.ON_PERSON, InventorySystem.Outfit.COURT_FORMAL))


func test_cannot_add_item_over_capacity():
	var items: Array = [_make_on_person(1, 2), _make_on_person(2, 1)]
	var new_item := _make_item(3, 1)
	assert_false(InventorySystem.can_add_item(items, new_item, InventorySystem.StorageTier.ON_PERSON, InventorySystem.Outfit.COURT_FORMAL))


func test_home_storage_always_accepts():
	var items: Array = []
	for i in range(100):
		items.append(_make_item(i, 3))
		items[i]["storage_tier"] = InventorySystem.StorageTier.HOME_STORAGE
	var new_item := _make_item(200, 3)
	assert_true(InventorySystem.can_add_item(items, new_item, InventorySystem.StorageTier.HOME_STORAGE))


func test_quarters_capacity_20():
	var items: Array = []
	for i in range(10):
		items.append(_make_in_quarters(i, 2))  # 10 * 2 = 20 slots used
	var new_item := _make_item(99, 1)
	assert_false(InventorySystem.can_add_item(items, new_item, InventorySystem.StorageTier.CURRENT_QUARTERS))


# -- Transfer tests -----------------------------------------------------------

func test_give_directly():
	var from: Array = [_make_on_person(1)]
	var to: Array = []
	assert_true(InventorySystem.give_directly(from, to, 1))
	assert_eq(from.size(), 0)
	assert_eq(to.size(), 1)
	assert_eq(to[0]["item_id"], 1)


func test_give_directly_fails_if_not_on_person():
	var from: Array = [_make_in_quarters(1)]
	var to: Array = []
	assert_false(InventorySystem.give_directly(from, to, 1))
	assert_eq(from.size(), 1)


func test_give_directly_fails_if_item_missing():
	var from: Array = [_make_on_person(1)]
	var to: Array = []
	assert_false(InventorySystem.give_directly(from, to, 99))


func test_send_by_messenger():
	var items: Array = [_make_on_person(1)]
	assert_true(InventorySystem.send_by_messenger(items, 1, 42))
	assert_true(items[0]["in_transit"])
	assert_eq(items[0]["transit_destination_id"], 42)


func test_receive_from_transit():
	var items: Array = [_make_on_person(1)]
	InventorySystem.send_by_messenger(items, 1, 42)
	assert_true(InventorySystem.receive_from_transit(items, 1))
	assert_false(items[0]["in_transit"])
	assert_eq(items[0]["storage_tier"], InventorySystem.StorageTier.ON_PERSON)


func test_in_transit_items_not_counted_in_slots():
	var items: Array = [_make_on_person(1, 2)]
	InventorySystem.send_by_messenger(items, 1, 42)
	assert_eq(InventorySystem.get_used_slots(items, InventorySystem.StorageTier.ON_PERSON), 0)


# -- Move to storage tests ----------------------------------------------------

func test_move_to_quarters():
	var items: Array = [_make_on_person(1)]
	assert_true(InventorySystem.move_to_storage(items, 1, InventorySystem.StorageTier.CURRENT_QUARTERS))
	assert_eq(items[0]["storage_tier"], InventorySystem.StorageTier.CURRENT_QUARTERS)


func test_move_to_home_storage():
	var items: Array = [_make_on_person(1)]
	assert_true(InventorySystem.move_to_storage(items, 1, InventorySystem.StorageTier.HOME_STORAGE))
	assert_eq(items[0]["storage_tier"], InventorySystem.StorageTier.HOME_STORAGE)


func test_move_to_person_fails_over_capacity():
	var items: Array = [_make_on_person(1, 3), _make_in_quarters(2, 2)]
	assert_false(InventorySystem.move_to_storage(items, 2, InventorySystem.StorageTier.ON_PERSON, InventorySystem.Outfit.COURT_FORMAL))


# -- Destruction tests --------------------------------------------------------

func test_destroy_item():
	var items: Array = [_make_on_person(1), _make_on_person(2)]
	assert_true(InventorySystem.destroy_item(items, 1))
	assert_eq(items.size(), 1)
	assert_eq(items[0]["item_id"], 2)


func test_destroy_nonexistent_fails():
	var items: Array = [_make_on_person(1)]
	assert_false(InventorySystem.destroy_item(items, 99))


# -- Covert acquisition tests -------------------------------------------------

func test_pickpocket():
	var from: Array = [_make_on_person(1)]
	var to: Array = []
	assert_true(InventorySystem.pickpocket(from, to, 1))
	assert_eq(from.size(), 0)
	assert_eq(to.size(), 1)


func test_pickpocket_fails_from_quarters():
	var from: Array = [_make_in_quarters(1)]
	var to: Array = []
	assert_false(InventorySystem.pickpocket(from, to, 1))


func test_search_quarters():
	var from: Array = [_make_in_quarters(1)]
	var to: Array = []
	assert_true(InventorySystem.search_quarters(from, to, 1))
	assert_eq(from.size(), 0)
	assert_eq(to[0]["storage_tier"], InventorySystem.StorageTier.ON_PERSON)


func test_search_quarters_fails_on_person():
	var from: Array = [_make_on_person(1)]
	var to: Array = []
	assert_false(InventorySystem.search_quarters(from, to, 1))


# -- Evidence tests -----------------------------------------------------------

func test_has_evidence():
	var items: Array = [_make_item(1, 1, 0, true)]
	items[0]["storage_tier"] = InventorySystem.StorageTier.ON_PERSON
	assert_true(InventorySystem.has_evidence(items))


func test_no_evidence():
	var items: Array = [_make_on_person(1)]
	assert_false(InventorySystem.has_evidence(items))


func test_get_evidence_items():
	var items: Array = [
		_make_item(1, 1, 0, true),
		_make_on_person(2),
		_make_item(3, 1, 0, true),
	]
	var evidence := InventorySystem.get_evidence_items(items)
	assert_eq(evidence.size(), 2)


# -- Concealment tests --------------------------------------------------------

func test_needs_concealment_court_formal_over():
	var items: Array = [_make_on_person(1, 2), _make_on_person(2, 2)]  # 4 slots, capacity 3
	assert_true(InventorySystem.needs_concealment(items, InventorySystem.Outfit.COURT_FORMAL))


func test_no_concealment_needed_within_capacity():
	var items: Array = [_make_on_person(1, 1), _make_on_person(2, 1)]  # 2 slots, capacity 3
	assert_false(InventorySystem.needs_concealment(items, InventorySystem.Outfit.COURT_FORMAL))


func test_no_concealment_check_non_court_formal():
	var items: Array = [_make_on_person(1, 3), _make_on_person(2, 3)]  # 6 slots, capacity 5 casual
	assert_false(InventorySystem.needs_concealment(items, InventorySystem.Outfit.CASUAL))


# -- Get items by tier --------------------------------------------------------

func test_get_items_in_tier():
	var items: Array = [_make_on_person(1), _make_in_quarters(2), _make_on_person(3)]
	var on_person := InventorySystem.get_items_in_tier(items, InventorySystem.StorageTier.ON_PERSON)
	assert_eq(on_person.size(), 2)
