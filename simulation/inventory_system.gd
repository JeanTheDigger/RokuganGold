class_name InventorySystem
## Inventory System per GDD s12.11.
## Tracks items across three storage tiers with size-based capacity limits.


# -- Enums & Constants --------------------------------------------------------

enum StorageTier {
	ON_PERSON,
	CURRENT_QUARTERS,
	HOME_STORAGE,
}

enum ItemCategory {
	DOCUMENT,
	SEAL,
	GIFT,
	WEAPON,
	SCROLL,
	VALUABLE,
	EVIDENCE,
}

enum ItemSize {
	SMALL = 1,
	MEDIUM = 2,
	LARGE = 3,
}

enum Outfit {
	COURT_FORMAL,
	CASUAL,
	TRAVELING,
	LIGHT_ARMOR,
	HEAVY_ARMOR,
}

const OUTFIT_CAPACITY: Dictionary = {
	Outfit.COURT_FORMAL: 3,
	Outfit.CASUAL: 5,
	Outfit.TRAVELING: 8,
	Outfit.LIGHT_ARMOR: 6,
	Outfit.HEAVY_ARMOR: 3,
}

const QUARTERS_CAPACITY: int = 20


# -- Item Structure -----------------------------------------------------------

static func create_gift_item(
	item_id: int,
	name: String,
	gift_subtype: int,
	quality_tier: int = 1,
	size: ItemSize = ItemSize.SMALL,
) -> Dictionary:
	## Convenience wrapper for gift items. `gift_subtype` is a
	## GiftGivingSystem.GiftCategory value stored alongside the inventory
	## ItemCategory so the gift resolver can identify the kind of gift.
	var item: Dictionary = create_item(item_id, name, ItemCategory.GIFT, size, quality_tier)
	item["gift_subtype"] = gift_subtype
	return item


static func create_item(
	item_id: int,
	name: String,
	category: ItemCategory,
	size: ItemSize,
	quality_tier: int = 1,
	is_evidence: bool = false,
) -> Dictionary:
	return {
		"item_id": item_id,
		"name": name,
		"category": category,
		"size": size,
		"quality_tier": quality_tier,
		"is_evidence": is_evidence,
		"storage_tier": StorageTier.ON_PERSON,
		"in_transit": false,
		"transit_destination_id": -1,
	}


# -- Capacity Queries ---------------------------------------------------------

static func get_on_person_capacity(outfit: Outfit) -> int:
	return OUTFIT_CAPACITY.get(outfit, 5)


static func get_used_slots(items: Array[Dictionary], storage_tier: StorageTier) -> int:
	var total: int = 0
	for item: Dictionary in items:
		if item is Dictionary and item.get("storage_tier") == storage_tier and not item.get("in_transit", false):
			total += item.get("size", 1)
	return total


static func can_add_item(items: Array[Dictionary], item: Dictionary, storage_tier: StorageTier, outfit: Outfit = Outfit.CASUAL) -> bool:
	if storage_tier == StorageTier.HOME_STORAGE:
		return true
	var capacity: int = QUARTERS_CAPACITY if storage_tier == StorageTier.CURRENT_QUARTERS else get_on_person_capacity(outfit)
	var used: int = get_used_slots(items, storage_tier)
	return (used + item.get("size", 1)) <= capacity


# -- Transfer Operations ------------------------------------------------------

static func give_directly(items_from: Array[Dictionary], items_to: Array[Dictionary], item_id: int) -> bool:
	var item: Dictionary = _find_item(items_from, item_id)
	if item.is_empty():
		return false
	if item.get("storage_tier") != StorageTier.ON_PERSON:
		return false
	items_from.erase(item)
	item["storage_tier"] = StorageTier.ON_PERSON
	items_to.append(item)
	return true


static func send_by_messenger(items: Array[Dictionary], item_id: int, destination_id: int) -> bool:
	var item: Dictionary = _find_item(items, item_id)
	if item.is_empty():
		return false
	item["in_transit"] = true
	item["transit_destination_id"] = destination_id
	return true


static func receive_from_transit(items: Array[Dictionary], item_id: int) -> bool:
	var item: Dictionary = _find_item(items, item_id)
	if item.is_empty():
		return false
	item["in_transit"] = false
	item["transit_destination_id"] = -1
	item["storage_tier"] = StorageTier.ON_PERSON
	return true


static func move_to_storage(items: Array[Dictionary], item_id: int, target_tier: StorageTier, outfit: Outfit = Outfit.CASUAL) -> bool:
	var item: Dictionary = _find_item(items, item_id)
	if item.is_empty():
		return false
	if target_tier != StorageTier.HOME_STORAGE:
		var capacity: int = QUARTERS_CAPACITY if target_tier == StorageTier.CURRENT_QUARTERS else get_on_person_capacity(outfit)
		var used: int = get_used_slots(items, target_tier)
		if (used + item.get("size", 1)) > capacity:
			return false
	item["storage_tier"] = target_tier
	return true


# -- Destruction --------------------------------------------------------------

static func destroy_item(items: Array[Dictionary], item_id: int) -> bool:
	var item: Dictionary = _find_item(items, item_id)
	if item.is_empty():
		return false
	items.erase(item)
	return true


# -- Covert Acquisition -------------------------------------------------------

static func pickpocket(items_from: Array[Dictionary], items_to: Array[Dictionary], item_id: int) -> bool:
	var item: Dictionary = _find_item(items_from, item_id)
	if item.is_empty():
		return false
	if item.get("storage_tier") != StorageTier.ON_PERSON:
		return false
	items_from.erase(item)
	item["storage_tier"] = StorageTier.ON_PERSON
	items_to.append(item)
	return true


static func search_quarters(items_from: Array[Dictionary], items_to: Array[Dictionary], item_id: int) -> bool:
	var item: Dictionary = _find_item(items_from, item_id)
	if item.is_empty():
		return false
	if item.get("storage_tier") != StorageTier.CURRENT_QUARTERS:
		return false
	items_from.erase(item)
	item["storage_tier"] = StorageTier.ON_PERSON
	items_to.append(item)
	return true


# -- Evidence -----------------------------------------------------------------

static func has_evidence(items: Array[Dictionary]) -> bool:
	for item: Dictionary in items:
		if item is Dictionary and item.get("is_evidence", false):
			return true
	return false


static func get_evidence_items(items: Array[Dictionary]) -> Array[Dictionary]:
	var evidence: Array[Dictionary] = []
	for item: Dictionary in items:
		if item is Dictionary and item.get("is_evidence", false):
			evidence.append(item)
	return evidence


# -- Concealment (court formal overflow) --------------------------------------

static func needs_concealment(items: Array[Dictionary], outfit: Outfit) -> bool:
	if outfit != Outfit.COURT_FORMAL:
		return false
	return get_used_slots(items, StorageTier.ON_PERSON) > get_on_person_capacity(outfit)


# -- Helpers ------------------------------------------------------------------

static func _find_item(items: Array[Dictionary], item_id: int) -> Dictionary:
	for item: Dictionary in items:
		if item is Dictionary and item.get("item_id") == item_id:
			return item
	return {}


static func get_items_in_tier(items: Array[Dictionary], storage_tier: StorageTier) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if item is Dictionary and item.get("storage_tier") == storage_tier and not item.get("in_transit", false):
			result.append(item)
	return result
