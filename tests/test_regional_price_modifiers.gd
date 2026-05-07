extends GutTest


# -- Territory Modifier Lookup -------------------------------------------------

func test_crab_weapons_discount():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Crab", "Weapons")
	assert_almost_eq(mod, -0.20, 0.001)


func test_crab_food_surcharge():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Crab", "Food")
	assert_almost_eq(mod, 0.20, 0.001)


func test_crane_silk_discount():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Crane", "Silk")
	assert_almost_eq(mod, -0.10, 0.001)


func test_mantis_spices_discount():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Mantis", "Spices")
	assert_almost_eq(mod, -0.30, 0.001)


func test_phoenix_weapons_surcharge():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Phoenix", "Weapons")
	assert_almost_eq(mod, 0.20, 0.001)


func test_scorpion_food_discount():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Scorpion", "Food")
	assert_almost_eq(mod, -0.30, 0.001)


func test_unicorn_yumi_discount():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Unicorn", "Yumi")
	assert_almost_eq(mod, -0.20, 0.001)


func test_unknown_clan_zero():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Minor", "Weapons")
	assert_almost_eq(mod, 0.0, 0.001)


func test_unknown_item_zero():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Crab", "Shoes")
	assert_almost_eq(mod, 0.0, 0.001)


# -- Final Price Computation ---------------------------------------------------

func test_final_price_with_territory_discount():
	var price: float = RegionalPriceModifiers.compute_final_price(10.0, "Crab", "Weapons", 0)
	assert_almost_eq(price, 8.0, 0.01, "10 * 0.8 = 8")


func test_final_price_with_territory_surcharge():
	var price: float = RegionalPriceModifiers.compute_final_price(10.0, "Crab", "Food", 0)
	assert_almost_eq(price, 12.0, 0.01, "10 * 1.2 = 12")


func test_final_price_with_commerce_skill():
	var price: float = RegionalPriceModifiers.compute_final_price(10.0, "Crab", "Weapons", 15)
	# 10 * 0.8 = 8.0, then * 0.9 = 7.2
	assert_almost_eq(price, 7.2, 0.01)


func test_final_price_commerce_fail_no_reduction():
	var price: float = RegionalPriceModifiers.compute_final_price(10.0, "Crab", "Weapons", 14)
	assert_almost_eq(price, 8.0, 0.01, "Commerce fail = no reduction")


func test_final_price_no_modifiers():
	var price: float = RegionalPriceModifiers.compute_final_price(10.0, "Minor", "Shoes", 0)
	assert_almost_eq(price, 10.0, 0.01)


func test_final_price_never_negative():
	var price: float = RegionalPriceModifiers.compute_final_price(0.5, "Scorpion", "Dice", 20)
	assert_true(price >= 0.0)


# -- All Modifiers for Clan ---------------------------------------------------

func test_get_all_modifiers_crab():
	var mods: Dictionary = RegionalPriceModifiers.get_all_modifiers_for_clan("Crab")
	assert_true(mods.has("Weapons"))
	assert_true(mods.has("Food"))
	assert_true(mods.has("Spices"))


func test_get_all_modifiers_unknown():
	var mods: Dictionary = RegionalPriceModifiers.get_all_modifiers_for_clan("Minor")
	assert_eq(mods.size(), 0)


# -- All 8 Clans Have Entries --------------------------------------------------

func test_all_clans_have_modifiers():
	for clan: String in ["Crab", "Crane", "Dragon", "Lion", "Mantis", "Phoenix", "Scorpion", "Unicorn"]:
		var mods: Dictionary = RegionalPriceModifiers.get_all_modifiers_for_clan(clan)
		assert_true(mods.size() > 0, "%s should have modifiers" % clan)


# -- Mantis Jade Finger Surcharge (rare item) ----------------------------------

func test_mantis_jade_finger_surcharge():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Mantis", "Jade Finger")
	assert_almost_eq(mod, 0.50, 0.001, "Jade Finger is rare (+50%) in Mantis territory")


# -- Dragon Specific -----------------------------------------------------------

func test_dragon_tattoo_needles():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Dragon", "Tattoo Needles")
	assert_almost_eq(mod, -0.30, 0.001)


func test_dragon_divination_kit():
	var mod: float = RegionalPriceModifiers.get_territory_modifier("Dragon", "Divination Kit")
	assert_almost_eq(mod, -0.30, 0.001)
