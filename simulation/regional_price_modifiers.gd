class_name RegionalPriceModifiers
## Clan territory price modifiers per GDD s11.8.
## Applied at character level when purchasing/selling items within clan territory.
## Resolution: (1) clan territory modifier, (2) Commerce skill reduction.


const CLAN_MODIFIERS: Dictionary = {
	"Crab": {
		"Weapons": -0.20,
		"Food": 0.20,
		"Spices": 0.50,
		"Iron": -0.20,
		"Steel": -0.20,
	},
	"Crane": {
		"Silk": -0.10,
		"Fine Paper": -0.10,
		"Small Paintings": -0.30,
		"Tea Sets": -0.10,
	},
	"Dragon": {
		"Food": 0.20,
		"Iron": -0.20,
		"Steel": -0.20,
		"Tattoo Needles": -0.30,
		"Divination Kit": -0.30,
	},
	"Lion": {
		"Armor": -0.10,
		"Weapons": -0.10,
		"Brazier": -0.20,
	},
	"Mantis": {
		"Spices": -0.30,
		"Food": 0.20,
		"Iron": 0.20,
		"Jade Finger": 0.50,
	},
	"Phoenix": {
		"Fine Paper": -0.30,
		"Medicine Kit": -0.30,
		"Weapons": 0.20,
	},
	"Scorpion": {
		"Food": -0.30,
		"Dice": -0.40,
		"Jade Finger": -0.10,
	},
	"Unicorn": {
		"Books": 0.20,
		"Jade": -0.10,
		"Yumi": -0.20,
	},
}

const COMMERCE_TN: int = 15
const COMMERCE_REDUCTION: float = 0.10


static func get_territory_modifier(clan: String, item_category: String) -> float:
	var clan_mods: Dictionary = CLAN_MODIFIERS.get(clan, {})
	return clan_mods.get(item_category, 0.0)


static func compute_final_price(
	base_price: float,
	territory_clan: String,
	item_category: String,
	commerce_roll_total: int,
) -> float:
	var modifier: float = get_territory_modifier(territory_clan, item_category)
	var adjusted: float = base_price * (1.0 + modifier)

	if commerce_roll_total >= COMMERCE_TN:
		adjusted *= (1.0 - COMMERCE_REDUCTION)

	return maxf(adjusted, 0.0)


static func get_all_modifiers_for_clan(clan: String) -> Dictionary:
	return CLAN_MODIFIERS.get(clan, {})
