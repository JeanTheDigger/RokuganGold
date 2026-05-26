class_name ArtisanSystem
## Artisan & Crafting resolution per GDD s49.
## Handles crafting rolls, quality tier determination, material bonuses,
## special weapon qualities, provenance creation, and multi-day progress.
##
## Pure simulation class — no Node inheritance.


# -- Cost-based TN table (s49) ------------------------------------------------

const COST_TN_ZENI: Array[Array] = [
	[10, 10], [25, 15], [50, 20],
]
const COST_TN_ZENI_FLOOR: int = 25
const COST_TN_ZENI_STEP: int = 5

const COST_TN_BU: Array[Array] = [
	[10, 15], [20, 20], [50, 25],
]
const COST_TN_BU_FLOOR: int = 30
const COST_TN_BU_STEP: int = 5

const COST_TN_KOKU: Array[Array] = [
	[10, 20], [20, 25], [25, 30],
]
const COST_TN_KOKU_FLOOR: int = 35
const COST_TN_KOKU_STEP: int = 5


# -- Quality tier TN thresholds (s49) -----------------------------------------

const QUALITY_TN_THRESHOLDS: Dictionary = {
	GiftGivingSystem.QualityTier.MUNDANE: 0,
	GiftGivingSystem.QualityTier.NORMAL: 15,
	GiftGivingSystem.QualityTier.FINE: 25,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 35,
	GiftGivingSystem.QualityTier.MASTERWORK: 45,
	GiftGivingSystem.QualityTier.LEGENDARY: 55,
}


# -- Material tier Free Raises (s49) ------------------------------------------

const MATERIAL_FREE_RAISES: Dictionary = {
	Enums.MaterialTier.COMMON: 0,
	Enums.MaterialTier.UNCOMMON: 1,
	Enums.MaterialTier.RARE: 2,
	Enums.MaterialTier.LEGENDARY: 3,
}


# -- Material availability by settlement type (s49) ---------------------------

const MATERIAL_AVAILABILITY: Dictionary = {
	Enums.SettlementType.VILLAGE: [Enums.MaterialTier.COMMON],
	Enums.SettlementType.TOWN: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON],
	Enums.SettlementType.CITY: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON, Enums.MaterialTier.RARE],
	Enums.SettlementType.IMPERIAL_CAPITAL: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON, Enums.MaterialTier.RARE, Enums.MaterialTier.LEGENDARY],
	Enums.SettlementType.CASTLE: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON],
	Enums.SettlementType.FAMILY_CASTLE: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON, Enums.MaterialTier.RARE, Enums.MaterialTier.LEGENDARY],
	Enums.SettlementType.FORTIFICATION: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON],
	Enums.SettlementType.KEEP: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON],
	Enums.SettlementType.WALL_TOWER: [Enums.MaterialTier.COMMON],
	Enums.SettlementType.TEMPLE: [Enums.MaterialTier.COMMON],
	Enums.SettlementType.SHINDEN: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON],
	Enums.SettlementType.MONASTERY: [Enums.MaterialTier.COMMON],
}


# -- Clan-specific materials (s49) --------------------------------------------

const CLAN_MATERIALS: Dictionary = {
	"Crab": {"name": "Kaiu Steel", "tier": Enums.MaterialTier.RARE, "category": Enums.CraftingCategory.WEAPONS},
	"Crane": {"name": "Kakita Paper", "tier": Enums.MaterialTier.UNCOMMON, "category": Enums.CraftingCategory.ARTWORK},
	"Dragon": {"name": "Dragon Jade Dust", "tier": Enums.MaterialTier.RARE, "category": Enums.CraftingCategory.EQUIPMENT},
	"Lion": {"name": "Matsu Leather", "tier": Enums.MaterialTier.UNCOMMON, "category": Enums.CraftingCategory.ARMOR},
	"Phoenix": {"name": "Phoenix-blessed Paper", "tier": Enums.MaterialTier.RARE, "category": Enums.CraftingCategory.ARTWORK},
	"Scorpion": {"name": "Shadow-silk", "tier": Enums.MaterialTier.RARE, "category": Enums.CraftingCategory.EQUIPMENT},
	"Unicorn": {"name": "Gaijin Dyes", "tier": Enums.MaterialTier.UNCOMMON, "category": Enums.CraftingCategory.ARTWORK},
	"Mantis": {"name": "Deep-sea Materials", "tier": Enums.MaterialTier.RARE, "category": Enums.CraftingCategory.EQUIPMENT},
}


# -- Weapon special quality Raise costs (s49) ---------------------------------

const QUALITY_RAISE_COST: Dictionary = {
	Enums.WeaponSpecialQuality.BALANCED: 4,
	Enums.WeaponSpecialQuality.SIGNATURE: 2,
	Enums.WeaponSpecialQuality.SWIFT: 4,
	Enums.WeaponSpecialQuality.TRUE_QUALITY: 6,
	Enums.WeaponSpecialQuality.RADIANT: 6,
	Enums.WeaponSpecialQuality.UNBREAKABLE: 5,
}

const SACRED_WEAPON_RAISE_COST: int = 7
const SACRED_WEAPON_KAIU_RAISE_COST: int = 6

const EXCEPTIONAL_WEAPON_MIN_RANK: int = 7
const EXCEPTIONAL_WEAPON_KAIU_TSI_MIN_RANK: int = 5

const EXCEPTIONAL_COST_MULTIPLIER: int = 3

const KAIU_FAMILIES: Array[String] = ["Kaiu"]
const TSI_FAMILIES: Array[String] = ["Tsi"]
const KAIU_TSI_FAMILIES: Array[String] = ["Kaiu", "Tsi"]

const SACRED_WEAPON_CLANS: Dictionary = {
	"Crab": "Kaiu Blade",
	"Crane": "Kakita Blade",
	"Dragon": "Tamori Blade",
	"Lion": "Akodo Blade",
	"Mantis": "Yoritomo Blade",
	"Phoenix": "Isawa Blade",
	"Scorpion": "Shosuro Blade",
	"Unicorn": "Utaku Blade",
}


# -- Crafting time (s49) ------------------------------------------------------

enum TimeUnit { HOURS, DAYS, WEEKS }

const AP_PER_HOUR: int = 1
const AP_PER_DAY: int = 2
const AP_PER_WEEK: int = 14


# -- Artisan school families (for standing objective assignment) ---------------

const ARTISAN_SCHOOL_KEYWORDS: Array[String] = [
	"Kakita Artisan", "Shiba Artisan", "Doji Magistrate",
]

const SMITH_SCHOOL_KEYWORDS: Array[String] = [
	"Kaiu Engineer", "Tsi Smith",
]


# == PUBLIC API ================================================================


static func get_base_tn(cost: float, denomination: String) -> int:
	var table: Array[Array]
	var floor_tn: int
	var step: int
	var top_bracket: int
	match denomination:
		"zeni":
			table = COST_TN_ZENI
			floor_tn = COST_TN_ZENI_FLOOR
			step = COST_TN_ZENI_STEP
			top_bracket = 50
		"bu":
			table = COST_TN_BU
			floor_tn = COST_TN_BU_FLOOR
			step = COST_TN_BU_STEP
			top_bracket = 50
		_:
			table = COST_TN_KOKU
			floor_tn = COST_TN_KOKU_FLOOR
			step = COST_TN_KOKU_STEP
			top_bracket = 25
	for bracket: Array in table:
		if cost <= bracket[0]:
			return bracket[1]
	var over: int = ceili((cost - top_bracket) / 5.0)
	return floor_tn + over * step


static func get_crafting_time_unit(material_type: Enums.MaterialType, denomination: String) -> TimeUnit:
	match material_type:
		Enums.MaterialType.STEEL:
			if denomination == "koku":
				return TimeUnit.WEEKS
			return TimeUnit.DAYS
		Enums.MaterialType.METAL_GLASS:
			return TimeUnit.DAYS
		_:
			if denomination == "koku":
				return TimeUnit.DAYS
			return TimeUnit.HOURS


static func get_time_units(cost: float, denomination: String) -> int:
	var divisor: int = 3
	match denomination:
		"zeni":
			divisor = 10
		"bu":
			divisor = 5
	return maxi(ceili(cost / divisor), 1)


static func get_ap_cost(cost: float, denomination: String, material_type: Enums.MaterialType) -> int:
	var time_unit: TimeUnit = get_crafting_time_unit(material_type, denomination)
	var units: int = get_time_units(cost, denomination)
	var ap_per_unit: int = AP_PER_HOUR
	match time_unit:
		TimeUnit.DAYS:
			ap_per_unit = AP_PER_DAY
		TimeUnit.WEEKS:
			ap_per_unit = AP_PER_WEEK
	return maxi(units * ap_per_unit, 1)


static func cost_in_koku(base_cost: float, denomination: String) -> float:
	match denomination:
		"koku":
			return base_cost
		"bu":
			return base_cost / 5.0
		"zeni":
			return base_cost / 50.0
	return base_cost


static func determine_quality_tier(roll_total: int) -> GiftGivingSystem.QualityTier:
	if roll_total >= QUALITY_TN_THRESHOLDS[GiftGivingSystem.QualityTier.LEGENDARY]:
		return GiftGivingSystem.QualityTier.LEGENDARY
	if roll_total >= QUALITY_TN_THRESHOLDS[GiftGivingSystem.QualityTier.MASTERWORK]:
		return GiftGivingSystem.QualityTier.MASTERWORK
	if roll_total >= QUALITY_TN_THRESHOLDS[GiftGivingSystem.QualityTier.EXCEPTIONAL]:
		return GiftGivingSystem.QualityTier.EXCEPTIONAL
	if roll_total >= QUALITY_TN_THRESHOLDS[GiftGivingSystem.QualityTier.FINE]:
		return GiftGivingSystem.QualityTier.FINE
	if roll_total >= QUALITY_TN_THRESHOLDS[GiftGivingSystem.QualityTier.NORMAL]:
		return GiftGivingSystem.QualityTier.NORMAL
	return GiftGivingSystem.QualityTier.MUNDANE


static func get_material_availability(settlement_type: Enums.SettlementType) -> Array:
	return MATERIAL_AVAILABILITY.get(settlement_type, [Enums.MaterialTier.COMMON])


static func is_material_available(
	material_tier: Enums.MaterialTier,
	settlement_type: Enums.SettlementType,
) -> bool:
	var available: Array = get_material_availability(settlement_type)
	return material_tier in available


static func get_clan_material(clan: String) -> Dictionary:
	return CLAN_MATERIALS.get(clan, {})


static func can_attempt_exceptional_weapon(
	character: L5RCharacterData,
) -> bool:
	var ws_rank: int = character.skills.get("Craft: Weaponsmithing", 0)
	if _is_kaiu_or_tsi(character):
		return ws_rank >= EXCEPTIONAL_WEAPON_KAIU_TSI_MIN_RANK
	return ws_rank >= EXCEPTIONAL_WEAPON_MIN_RANK


static func can_attempt_sacred_weapon(
	character: L5RCharacterData,
) -> bool:
	if not can_attempt_exceptional_weapon(character):
		return false
	var clan: String = character.clan
	return clan in SACRED_WEAPON_CLANS


static func get_exceptional_tn(base_cost_koku: float) -> int:
	var tripled: float = base_cost_koku * EXCEPTIONAL_COST_MULTIPLIER
	return get_base_tn(tripled, "koku")


static func resolve_crafting(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_name: String,
	base_tn: int,
	material_tier: Enums.MaterialTier,
	is_exceptional_attempt: bool,
	declared_raises: int = 0,
) -> Dictionary:
	var material_fr: int = MATERIAL_FREE_RAISES.get(material_tier, 0)
	var school_fr: int = 0
	if _is_kaiu_or_tsi(character) and is_exceptional_attempt:
		school_fr = 1

	var result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, skill_name, base_tn, declared_raises, "",
	)

	var total: int = result.get("total", 0)
	var success: bool = result.get("success", false)
	var margin: int = total - base_tn

	var effective_total: int = total + (material_fr + school_fr) * 5

	if is_exceptional_attempt and not success:
		return {
			"success": false,
			"total": total,
			"effective_total": effective_total,
			"margin": margin,
			"quality_tier": GiftGivingSystem.QualityTier.MUNDANE,
			"item_ruined": true,
			"material_fr": material_fr,
			"school_fr": school_fr,
			"available_raises": 0,
		}

	var quality: GiftGivingSystem.QualityTier = determine_quality_tier(effective_total)

	var available_raises: int = 0
	if success:
		available_raises = maxi(int(margin / 5.0), 0) + material_fr + school_fr - declared_raises
		available_raises = maxi(available_raises, 0)

	return {
		"success": success,
		"total": total,
		"effective_total": effective_total,
		"margin": margin,
		"quality_tier": quality,
		"item_ruined": false,
		"material_fr": material_fr,
		"school_fr": school_fr,
		"available_raises": available_raises,
	}


static func allocate_special_qualities(
	available_raises: int,
	desired_qualities: Array[Enums.WeaponSpecialQuality],
) -> Dictionary:
	var allocated: Array[Enums.WeaponSpecialQuality] = []
	var remaining: int = available_raises
	for q: Enums.WeaponSpecialQuality in desired_qualities:
		var cost: int = QUALITY_RAISE_COST.get(q, 99)
		if cost <= remaining:
			allocated.append(q)
			remaining -= cost
	return {
		"allocated": allocated,
		"raises_spent": available_raises - remaining,
		"raises_remaining": remaining,
	}


static func check_sacred_weapon(
	available_raises: int,
	character: L5RCharacterData,
) -> Dictionary:
	var cost: int = SACRED_WEAPON_RAISE_COST
	if _is_kaiu_or_tsi(character):
		cost = SACRED_WEAPON_KAIU_RAISE_COST
	var can_forge: bool = available_raises >= cost and character.clan in SACRED_WEAPON_CLANS
	return {
		"can_forge": can_forge,
		"raise_cost": cost,
		"sacred_name": SACRED_WEAPON_CLANS.get(character.clan, ""),
	}


static func create_crafted_item(
	character: L5RCharacterData,
	craft_result: Dictionary,
	item_id: int,
	item_name: String,
	category: Enums.CraftingCategory,
	track: Enums.CraftingTrack,
	skill_used: String,
	material_tier: Enums.MaterialTier,
	material_name: String,
	base_cost_koku: float,
	denomination: String,
	ic_day: int,
	province_id: int = -1,
) -> ArtisanItemData:
	var item := ArtisanItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.category = category
	item.track = track
	item.skill_used = skill_used
	item.quality_tier = craft_result.get("quality_tier", GiftGivingSystem.QualityTier.NORMAL)
	item.creator_id = character.character_id
	item.creator_clan = character.clan
	item.creator_family = character.family
	item.creator_school = character.school
	item.creator_insight_rank = _get_insight_rank(character)
	item.creation_ic_day = ic_day
	item.creation_province_id = province_id
	item.material_tier = material_tier
	item.material_name = material_name
	item.base_cost_koku = base_cost_koku
	item.cost_denomination = denomination
	item.current_owner_id = character.character_id
	item.is_complete = true
	item.crafting_roll_total = craft_result.get("total", 0)
	return item


static func create_work_in_progress(
	character: L5RCharacterData,
	item_id: int,
	item_name: String,
	category: Enums.CraftingCategory,
	track: Enums.CraftingTrack,
	skill_used: String,
	material_tier: Enums.MaterialTier,
	material_name: String,
	base_cost_koku: float,
	denomination: String,
	material_type: Enums.MaterialType,
) -> ArtisanItemData:
	var item := ArtisanItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.category = category
	item.track = track
	item.skill_used = skill_used
	item.creator_id = character.character_id
	item.creator_clan = character.clan
	item.creator_family = character.family
	item.creator_school = character.school
	item.creator_insight_rank = _get_insight_rank(character)
	item.material_tier = material_tier
	item.material_name = material_name
	item.base_cost_koku = base_cost_koku
	item.cost_denomination = denomination
	item.current_owner_id = character.character_id
	item.crafting_ap_required = get_ap_cost(base_cost_koku, denomination, material_type)
	item.crafting_ap_invested = 0
	item.is_complete = false
	return item


static func invest_ap(item: ArtisanItemData, ap_spent: int) -> Dictionary:
	if item.is_complete:
		return {"invested": false, "reason": "already_complete"}
	item.crafting_ap_invested += ap_spent
	var ready: bool = item.crafting_ap_invested >= item.crafting_ap_required
	return {
		"invested": true,
		"ap_invested": item.crafting_ap_invested,
		"ap_required": item.crafting_ap_required,
		"ready_for_roll": ready,
	}


static func select_best_material_for_npc(
	character: L5RCharacterData,
	settlement_type: Enums.SettlementType,
	category: Enums.CraftingCategory,
) -> Dictionary:
	var available: Array = get_material_availability(settlement_type)
	var clan_mat: Dictionary = get_clan_material(character.clan)

	if not clan_mat.is_empty():
		var clan_tier: Enums.MaterialTier = clan_mat.get("tier", Enums.MaterialTier.COMMON)
		var clan_cat: Enums.CraftingCategory = clan_mat.get("category", Enums.CraftingCategory.EQUIPMENT)
		if clan_tier in available and (clan_cat == category or category == Enums.CraftingCategory.EQUIPMENT):
			return {
				"tier": clan_tier,
				"name": clan_mat.get("name", ""),
			}

	var best_tier: Enums.MaterialTier = Enums.MaterialTier.COMMON
	for tier: Enums.MaterialTier in available:
		if tier > best_tier:
			best_tier = tier
	var name_map: Dictionary = {
		Enums.MaterialTier.COMMON: "Standard materials",
		Enums.MaterialTier.UNCOMMON: "Fine materials",
		Enums.MaterialTier.RARE: "Rare materials",
		Enums.MaterialTier.LEGENDARY: "Legendary materials",
	}
	return {
		"tier": best_tier,
		"name": name_map.get(best_tier, "Standard materials"),
	}


static func npc_select_craft_action(
	character: L5RCharacterData,
	settlement_type: Enums.SettlementType,
	category: Enums.CraftingCategory,
) -> Dictionary:
	var skill_name: String = _get_craft_skill_for_category(character, category)
	var skill_rank: int = character.skills.get(skill_name, 0)
	if skill_rank <= 0:
		return {"can_craft": false, "reason": "no_skill"}

	var mat: Dictionary = select_best_material_for_npc(character, settlement_type, category)
	var material_tier: Enums.MaterialTier = mat.get("tier", Enums.MaterialTier.COMMON)

	var is_exceptional: bool = false
	if category == Enums.CraftingCategory.WEAPONS and skill_name == "Craft: Weaponsmithing":
		is_exceptional = can_attempt_exceptional_weapon(character)

	var item_name: String = _pick_item_name(category, character)
	var denomination: String = _pick_denomination(category)
	var base_cost: float = _pick_base_cost(category, denomination)
	var material_type: Enums.MaterialType = _infer_material_type(category)

	var base_tn: int = get_base_tn(base_cost, denomination)
	if is_exceptional:
		base_tn = get_exceptional_tn(base_cost)

	var ap_cost: int = get_ap_cost(base_cost, denomination, material_type)
	var track: Enums.CraftingTrack = Enums.CraftingTrack.CRAFT
	if category == Enums.CraftingCategory.ARTWORK:
		track = Enums.CraftingTrack.ARTISAN

	return {
		"can_craft": true,
		"skill_name": skill_name,
		"base_tn": base_tn,
		"material_tier": material_tier,
		"material_name": mat.get("name", ""),
		"is_exceptional": is_exceptional,
		"item_name": item_name,
		"category": category,
		"track": track,
		"denomination": denomination,
		"base_cost": base_cost,
		"material_type": material_type,
		"ap_cost": ap_cost,
	}


static func is_artisan_school(character: L5RCharacterData) -> bool:
	for keyword: String in ARTISAN_SCHOOL_KEYWORDS:
		if character.school.find(keyword) >= 0:
			return true
	return false


static func is_smith_school(character: L5RCharacterData) -> bool:
	for keyword: String in SMITH_SCHOOL_KEYWORDS:
		if character.school.find(keyword) >= 0:
			return true
	return false


static func has_any_craft_skill(character: L5RCharacterData) -> bool:
	for skill_name: String in character.skills:
		if skill_name.begins_with("Artisan: ") or skill_name.begins_with("Craft: "):
			if character.skills[skill_name] > 0:
				return true
	return false


static func get_best_craft_skill(character: L5RCharacterData) -> String:
	var best_skill: String = ""
	var best_rank: int = 0
	for skill_name: String in character.skills:
		if skill_name.begins_with("Artisan: ") or skill_name.begins_with("Craft: "):
			var rank: int = character.skills[skill_name]
			if rank > best_rank:
				best_rank = rank
				best_skill = skill_name
	return best_skill


static func create_inventory_item(item: ArtisanItemData) -> Dictionary:
	var gift_subtype: int = _crafting_category_to_gift_subtype(item.category)
	var inv_category: int = InventorySystem.ItemCategory.GIFT
	if item.category == Enums.CraftingCategory.WEAPONS:
		inv_category = InventorySystem.ItemCategory.WEAPON
	elif item.category == Enums.CraftingCategory.ARMOR:
		inv_category = InventorySystem.ItemCategory.WEAPON
	var inv_item: Dictionary = InventorySystem.create_item(
		item.item_id,
		item.item_name,
		inv_category,
		InventorySystem.ItemSize.SMALL if item.category == Enums.CraftingCategory.ARTWORK else InventorySystem.ItemSize.MEDIUM,
		item.quality_tier,
	)
	inv_item["gift_subtype"] = gift_subtype
	inv_item["crafted_item_id"] = item.item_id
	inv_item["history_point_bonus"] = item.get_history_tier_bonus()
	return inv_item


static func _crafting_category_to_gift_subtype(category: Enums.CraftingCategory) -> int:
	match category:
		Enums.CraftingCategory.ARTWORK:
			return GiftGivingSystem.GiftCategory.ART
		Enums.CraftingCategory.WEAPONS:
			return GiftGivingSystem.GiftCategory.WEAPON
		Enums.CraftingCategory.ARMOR:
			return GiftGivingSystem.GiftCategory.ARMOR
		Enums.CraftingCategory.EQUIPMENT:
			return GiftGivingSystem.GiftCategory.ACCESSORIES
		Enums.CraftingCategory.ENGINEERING:
			return GiftGivingSystem.GiftCategory.ACCESSORIES
	return GiftGivingSystem.GiftCategory.ART


static func find_crafted_item(crafted_items: Array, item_id: int) -> ArtisanItemData:
	for item: ArtisanItemData in crafted_items:
		if item.item_id == item_id:
			return item
	return null


# == PRIVATE HELPERS ===========================================================


static func _is_kaiu_or_tsi(character: L5RCharacterData) -> bool:
	return character.family in KAIU_TSI_FAMILIES


static func _get_insight_rank(character: L5RCharacterData) -> int:
	return character.skills.get("_insight_rank", 1)


static func _get_craft_skill_for_category(
	character: L5RCharacterData,
	category: Enums.CraftingCategory,
) -> String:
	match category:
		Enums.CraftingCategory.WEAPONS:
			var bow_rank: int = character.skills.get("Craft: Bowyer", 0)
			var ws_rank: int = character.skills.get("Craft: Weaponsmithing", 0)
			if bow_rank > ws_rank:
				return "Craft: Bowyer"
			return "Craft: Weaponsmithing"
		Enums.CraftingCategory.ARMOR:
			return "Craft: Armorsmithing"
		Enums.CraftingCategory.ARTWORK:
			var best: String = "Artisan: Painting"
			var best_rank: int = 0
			for skill_name: String in character.skills:
				if skill_name.begins_with("Artisan: "):
					var rank: int = character.skills[skill_name]
					if rank > best_rank:
						best_rank = rank
						best = skill_name
			return best
		Enums.CraftingCategory.ENGINEERING:
			return "Engineering"
		_:
			for skill_name: String in character.skills:
				if skill_name.begins_with("Craft: "):
					return skill_name
			return "Craft: Weaponsmithing"


static func _pick_item_name(category: Enums.CraftingCategory, character: L5RCharacterData) -> String:
	match category:
		Enums.CraftingCategory.WEAPONS:
			return "Katana"
		Enums.CraftingCategory.ARMOR:
			return "Light Armor"
		Enums.CraftingCategory.ARTWORK:
			var skill: String = _get_craft_skill_for_category(character, category)
			match skill:
				"Artisan: Painting":
					return "Small Painting"
				"Artisan: Poetry":
					return "Poetry Scroll"
				"Artisan: Origami":
					return "Origami Figure"
				"Artisan: Ikebana":
					return "Ikebana Arrangement"
				"Artisan: Sculpture":
					return "Small Sculpture"
				"Artisan: Tattooing":
					return "Tattoo Design"
				"Artisan: Gardening":
					return "Bonkei"
				_:
					return "Artwork"
		_:
			return "Crafted Item"


static func _pick_denomination(category: Enums.CraftingCategory) -> String:
	match category:
		Enums.CraftingCategory.WEAPONS:
			return "koku"
		Enums.CraftingCategory.ARMOR:
			return "koku"
		Enums.CraftingCategory.ARTWORK:
			return "bu"
		_:
			return "bu"


static func _pick_base_cost(category: Enums.CraftingCategory, denomination: String) -> float:
	match category:
		Enums.CraftingCategory.WEAPONS:
			return 25.0
		Enums.CraftingCategory.ARMOR:
			return 15.0
		Enums.CraftingCategory.ARTWORK:
			return 3.0
		_:
			if denomination == "koku":
				return 5.0
			return 5.0


static func _infer_material_type(category: Enums.CraftingCategory) -> Enums.MaterialType:
	match category:
		Enums.CraftingCategory.WEAPONS:
			return Enums.MaterialType.STEEL
		Enums.CraftingCategory.ARMOR:
			return Enums.MaterialType.STEEL
		Enums.CraftingCategory.ARTWORK:
			return Enums.MaterialType.OTHER
		_:
			return Enums.MaterialType.OTHER
