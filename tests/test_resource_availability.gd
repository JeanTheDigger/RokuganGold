extends GutTest


var _char: L5RCharacterData


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.koku = 0.0
	_char.outfit = []


# =============================================================================
# Ratio → Modifier Thresholds
# =============================================================================

func test_free_action_returns_zero() -> void:
	_char.koku = 0.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"REST", _char
	)
	assert_eq(mod, 0.0)


func test_broke_returns_minus_40() -> void:
	_char.koku = 0.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -40.0)


func test_flush_returns_zero() -> void:
	_char.koku = 100.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, 0.0)


func test_comfortable_returns_minus_5() -> void:
	# BRIBE_FOR_INFO costs 5 koku. 15/5 = 3.0 ratio → -5
	_char.koku = 15.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -5.0)


func test_tight_returns_minus_10() -> void:
	# 10/5 = 2.0 ratio → -10
	_char.koku = 10.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -10.0)


func test_barely_returns_minus_15() -> void:
	# 5/5 = 1.0 ratio → -15
	_char.koku = 5.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -15.0)


func test_cannot_afford_returns_minus_25() -> void:
	# 3/5 = 0.6 ratio → -25
	_char.koku = 3.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -25.0)


# =============================================================================
# Boundary Checks
# =============================================================================

func test_exactly_5x_is_flush() -> void:
	# 25/5 = 5.0 → 0
	_char.koku = 25.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, 0.0)


func test_just_below_5x_is_comfortable() -> void:
	# 24.9/5 = 4.98 → -5
	_char.koku = 24.9
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -5.0)


func test_exactly_3x_is_comfortable() -> void:
	_char.koku = 15.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -5.0)


func test_exactly_1_5x_is_tight() -> void:
	# 7.5/5 = 1.5 → -10
	_char.koku = 7.5
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"BRIBE_FOR_INFO", _char
	)
	assert_eq(mod, -10.0)


# =============================================================================
# Gift Actions (koku-based, GDD says variable)
# =============================================================================

func test_deliver_gift_no_koku_broke() -> void:
	_char.koku = 0.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"DELIVER_GIFT", _char
	)
	assert_eq(mod, -40.0)


func test_deliver_gift_with_koku() -> void:
	_char.koku = 10.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"DELIVER_GIFT", _char
	)
	assert_eq(mod, 0.0)


# =============================================================================
# Province-based Actions
# =============================================================================

func test_share_supplies_with_rice() -> void:
	var province: Dictionary = {"rice_stockpile": 10.0}
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"SHARE_SUPPLIES", _char, province
	)
	assert_eq(mod, 0.0)


func test_share_supplies_no_rice() -> void:
	var province: Dictionary = {"rice_stockpile": 0.0}
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"SHARE_SUPPLIES", _char, province
	)
	assert_eq(mod, -40.0)


func test_order_levy_no_troops() -> void:
	var province: Dictionary = {"available_levy_pu": 0.0}
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"ORDER_LEVY", _char, province
	)
	assert_eq(mod, -40.0)


func test_order_levy_with_troops() -> void:
	var province: Dictionary = {"available_levy_pu": 8.0}
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"ORDER_LEVY", _char, province
	)
	assert_eq(mod, 0.0)


# =============================================================================
# Utility Functions
# =============================================================================

func test_has_resource_cost_true() -> void:
	assert_true(ResourceAvailability.has_resource_cost("BRIBE_FOR_INFO"))


func test_has_resource_cost_false() -> void:
	assert_false(ResourceAvailability.has_resource_cost("REST"))


func test_get_resource_cost_exists() -> void:
	var cost: Dictionary = ResourceAvailability.get_resource_cost("BRIBE_FOR_INFO")
	assert_eq(cost["resource_type"], "koku")
	assert_eq(cost["amount"], 5)


func test_get_resource_cost_missing() -> void:
	var cost: Dictionary = ResourceAvailability.get_resource_cost("CHARM")
	assert_true(cost.is_empty())


# =============================================================================
# Multiple Actions
# =============================================================================

func test_purchase_market_cost() -> void:
	_char.koku = 3.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"PURCHASE_MARKET", _char
	)
	# 3/1 = 3.0 → -5
	assert_eq(mod, -5.0)


func test_offer_favor_cost() -> void:
	_char.koku = 2.0
	var mod: float = ResourceAvailability.compute_resource_modifier(
		"OFFER_FAVOR", _char
	)
	# 2/1 = 2.0 → -10
	assert_eq(mod, -10.0)


# =============================================================================
# can_afford (Phase 7 validation)
# =============================================================================

func test_can_afford_free_action() -> void:
	_char.koku = 0.0
	assert_true(ResourceAvailability.can_afford("REST", _char))


func test_can_afford_with_exact_koku() -> void:
	_char.koku = 5.0
	assert_true(ResourceAvailability.can_afford("BRIBE_FOR_INFO", _char))


func test_cannot_afford_insufficient_koku() -> void:
	_char.koku = 4.0
	assert_false(ResourceAvailability.can_afford("BRIBE_FOR_INFO", _char))


func test_can_afford_deliver_gift_with_koku() -> void:
	_char.koku = 1.0
	assert_true(ResourceAvailability.can_afford("DELIVER_GIFT", _char))


func test_cannot_afford_deliver_gift_no_koku() -> void:
	_char.koku = 0.0
	assert_false(ResourceAvailability.can_afford("DELIVER_GIFT", _char))


func test_can_afford_with_province_troops() -> void:
	var province: Dictionary = {"available_levy_pu": 3.0}
	assert_true(ResourceAvailability.can_afford("ORDER_LEVY", _char, province))


func test_cannot_afford_no_troops() -> void:
	var province: Dictionary = {"available_levy_pu": 0.0}
	assert_false(ResourceAvailability.can_afford("ORDER_LEVY", _char, province))
