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
	Enums.SettlementType.FAMILY_CASTLE: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON, Enums.MaterialTier.RARE, Enums.MaterialTier.LEGENDARY],
	Enums.SettlementType.IMPERIAL_CAPITAL: [Enums.MaterialTier.COMMON, Enums.MaterialTier.UNCOMMON, Enums.MaterialTier.RARE, Enums.MaterialTier.LEGENDARY],
}


# -- Clan-specific materials (s49) --------------------------------------------

const CLAN_MATERIALS: Dictionary = {
	"Crab": {"name": "Kaiu Steel", "tier": Enums.MaterialTier.RARE},
	"Crane": {"name": "Kakita Paper", "tier": Enums.MaterialTier.UNCOMMON},
	"Dragon": {"name": "Dragon Jade Dust", "tier": Enums.MaterialTier.RARE},
	"Lion": {"name": "Matsu Leather", "tier": Enums.MaterialTier.UNCOMMON},
	"Phoenix": {"name": "Phoenix-blessed Paper", "tier": Enums.MaterialTier.RARE},
	"Scorpion": {"name": "Shadow-silk", "tier": Enums.MaterialTier.RARE},
	"Unicorn": {"name": "Gaijin Dyes", "tier": Enums.MaterialTier.UNCOMMON},
	"Mantis": {"name": "Deep-sea Materials", "tier": Enums.MaterialTier.RARE},
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
}


# -- Crafting time (s49) ------------------------------------------------------

enum TimeUnit { HOURS, DAYS, WEEKS }

const AP_PER_HOUR: int = 1
const AP_PER_DAY: int = 2
const AP_PER_WEEK: int = 14


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


