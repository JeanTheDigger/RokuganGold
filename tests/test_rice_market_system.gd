extends GutTest


func _make_settlement(id: int, province_id: int, rice: float = 10.0, pop: int = 1000) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.rice_stockpile = rice
	s.population_pu = pop
	return s


func _make_province(id: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.stability = 80.0
	return p


func _make_route(id: int, a: int, b: int, naval: bool = false) -> TradeRouteData:
	var r := TradeRouteData.new()
	r.route_id = id
	r.province_a_id = a
	r.province_b_id = b
	r.is_naval = naval
	r.koku_bonus_per_season = 0.1
	return r


func _make_character(honor: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.honor = honor
	return c


# -- Surplus Calculation -------------------------------------------------------

func test_surplus_positive():
	var s := _make_settlement(1, 1, 10.0, 4)
	var surplus: float = RiceMarketSystem.compute_surplus(s, 4)
	# need = 4 * 0.25 * 4 = 4.0
	assert_almost_eq(surplus, 6.0, 0.01)


func test_surplus_zero_when_tight():
	var s := _make_settlement(1, 1, 4.0, 1000)
	var surplus: float = RiceMarketSystem.compute_surplus(s, 4)
	assert_almost_eq(surplus, 0.0, 0.01)


func test_surplus_zero_when_deficit():
	var s := _make_settlement(1, 1, 2.0, 1000)
	var surplus: float = RiceMarketSystem.compute_surplus(s, 4)
	assert_almost_eq(surplus, 0.0, 0.01)


# -- Posting Creation ----------------------------------------------------------

func test_create_posting():
	var posting: RicePostingData = RiceMarketSystem.create_posting(1, 10, 5.0, 1.0)
	assert_eq(posting.lord_id, 1)
	assert_eq(posting.province_id, 10)
	assert_almost_eq(posting.quantity, 5.0, 0.01)
	assert_almost_eq(posting.price_per_unit, 1.0, 0.01)


func test_create_posting_respects_floor():
	var posting: RicePostingData = RiceMarketSystem.create_posting(1, 10, 5.0, 0.1)
	assert_almost_eq(posting.price_per_unit, 0.25, 0.01)


# -- Price Adjustment ----------------------------------------------------------

func test_price_rises_on_sale():
	var posting := RicePostingData.new()
	posting.price_per_unit = 1.0
	RiceMarketSystem.adjust_price_after_season(posting, true)
	assert_almost_eq(posting.price_per_unit, 1.25, 0.01)
	assert_eq(posting.seasons_sold, 1)
	assert_eq(posting.seasons_unsold, 0)


func test_price_falls_on_no_sale():
	var posting := RicePostingData.new()
	posting.price_per_unit = 1.0
	RiceMarketSystem.adjust_price_after_season(posting, false)
	assert_almost_eq(posting.price_per_unit, 0.75, 0.01)
	assert_eq(posting.seasons_unsold, 1)


func test_price_does_not_go_below_floor():
	var posting := RicePostingData.new()
	posting.price_per_unit = 0.25
	RiceMarketSystem.adjust_price_after_season(posting, false)
	assert_almost_eq(posting.price_per_unit, 0.25, 0.01)


func test_withdrawal_at_floor_unsold():
	var posting := RicePostingData.new()
	posting.price_per_unit = 0.25
	posting.seasons_unsold = 1
	assert_true(RiceMarketSystem.should_withdraw(posting))


func test_no_withdrawal_above_floor():
	var posting := RicePostingData.new()
	posting.price_per_unit = 0.50
	posting.seasons_unsold = 1
	assert_false(RiceMarketSystem.should_withdraw(posting))


# -- Purchase Priority ---------------------------------------------------------

func test_priority_friend():
	assert_eq(RiceMarketSystem.get_purchase_priority(50), RiceMarketSystem.PRIORITY_FRIEND)
	assert_eq(RiceMarketSystem.get_purchase_priority(31), RiceMarketSystem.PRIORITY_FRIEND)


func test_priority_acquaintance():
	assert_eq(RiceMarketSystem.get_purchase_priority(0), RiceMarketSystem.PRIORITY_ACQUAINTANCE)
	assert_eq(RiceMarketSystem.get_purchase_priority(-10), RiceMarketSystem.PRIORITY_ACQUAINTANCE)


func test_priority_rival():
	assert_eq(RiceMarketSystem.get_purchase_priority(-11), RiceMarketSystem.PRIORITY_RIVAL)
	assert_eq(RiceMarketSystem.get_purchase_priority(-50), RiceMarketSystem.PRIORITY_RIVAL)


func test_cannot_sell_to_blood_enemy():
	assert_false(RiceMarketSystem.can_sell_to(-60))
	assert_true(RiceMarketSystem.can_sell_to(-59))


# -- Purchase Resolution -------------------------------------------------------

func test_resolve_simple_purchase():
	var posting := RiceMarketSystem.create_posting(1, 10, 5.0, 1.0)
	var postings: Array = [posting]
	var orders: Array = [
		{"lord_id": 2, "quantity": 3.0, "koku_budget": 5.0},
	]
	var lookup: Callable = func(_a: int, _b: int) -> int: return 0

	var results: Array = RiceMarketSystem.resolve_purchases(postings, orders, lookup)
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0]["quantity"], 3.0, 0.01)
	assert_almost_eq(results[0]["total_cost"], 3.0, 0.01)


func test_resolve_priority_ordering():
	var posting := RiceMarketSystem.create_posting(1, 10, 3.0, 1.0)
	var postings: Array = [posting]
	var orders: Array = [
		{"lord_id": 2, "quantity": 2.0, "koku_budget": 5.0},
		{"lord_id": 3, "quantity": 2.0, "koku_budget": 5.0},
	]
	# Lord 3 is Friend (priority 1), Lord 2 is Rival (priority 3)
	var lookup: Callable = func(seller_id: int, buyer_id: int) -> int:
		if buyer_id == 3:
			return 50
		return -20

	var results: Array = RiceMarketSystem.resolve_purchases(postings, orders, lookup)
	assert_eq(results.size(), 2)
	assert_eq(results[0]["buyer_id"], 3, "Friend should buy first")
	assert_almost_eq(results[0]["quantity"], 2.0, 0.01)
	assert_eq(results[1]["buyer_id"], 2)
	assert_almost_eq(results[1]["quantity"], 1.0, 0.01, "Only 1.0 left after friend bought 2.0")


func test_resolve_budget_limited():
	var posting := RiceMarketSystem.create_posting(1, 10, 5.0, 2.0)
	var postings: Array = [posting]
	var orders: Array = [
		{"lord_id": 2, "quantity": 5.0, "koku_budget": 4.0},
	]
	var lookup: Callable = func(_a: int, _b: int) -> int: return 0
	var results: Array = RiceMarketSystem.resolve_purchases(postings, orders, lookup)
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0]["quantity"], 2.0, 0.01, "Can only afford 2 units at 2 koku each")


func test_resolve_seller_skips_self():
	var posting := RiceMarketSystem.create_posting(1, 10, 5.0, 1.0)
	var postings: Array = [posting]
	var orders: Array = [
		{"lord_id": 1, "quantity": 3.0, "koku_budget": 5.0},
	]
	var lookup: Callable = func(_a: int, _b: int) -> int: return 50
	var results: Array = RiceMarketSystem.resolve_purchases(postings, orders, lookup)
	assert_eq(results.size(), 0, "Cannot buy from yourself")


# -- Intra-Clan Sharing -------------------------------------------------------

func test_sharing_honor_shortage_small():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(0.5, 1, false), 0.1, 0.01
	)


func test_sharing_honor_shortage_significant():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(2.0, 1, false), 0.2, 0.01
	)


func test_sharing_honor_hunger():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(1.0, 2, false), 0.3, 0.01
	)


func test_sharing_honor_famine():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(1.0, 3, false), 0.5, 0.01
	)


func test_sharing_honor_famine_resolved():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(5.0, 3, true), 1.0, 0.01
	)


func test_sharing_no_honor_when_not_needed():
	assert_almost_eq(
		RiceMarketSystem.compute_sharing_honor(5.0, 0, false), 0.0, 0.01
	)


func test_share_rice_transfers():
	var c := _make_character(5.0)
	var giver_s := _make_settlement(1, 1, 10.0)
	var receiver_s := _make_settlement(2, 2, 0.5, 500)
	var result: Dictionary = RiceMarketSystem.share_rice(c, giver_s, receiver_s, 2.0, 2)
	assert_eq(result["result"], "success")
	assert_true(result["honor_gain"] > 0.0)
	assert_almost_eq(giver_s.rice_stockpile, 8.0, 0.01)
	assert_almost_eq(receiver_s.rice_stockpile, 2.5, 0.01)


func test_share_rice_insufficient():
	var c := _make_character()
	var giver_s := _make_settlement(1, 1, 1.0)
	var receiver_s := _make_settlement(2, 2, 0.5)
	var result: Dictionary = RiceMarketSystem.share_rice(c, giver_s, receiver_s, 5.0, 2)
	assert_eq(result["result"], "insufficient")


func test_share_rice_not_needed():
	var c := _make_character()
	var giver_s := _make_settlement(1, 1, 10.0)
	var receiver_s := _make_settlement(2, 2, 5.0)
	var result: Dictionary = RiceMarketSystem.share_rice(c, giver_s, receiver_s, 2.0, 0)
	assert_eq(result["result"], "not_needed")


# -- Trade Route Koku Bonus ----------------------------------------------------

func test_trade_route_koku_bonus():
	var p := _make_province(1)
	var routes: Array = [
		_make_route(1, 1, 2),
		_make_route(2, 1, 3),
	]
	var koku: float = RiceMarketSystem.compute_trade_route_koku(p, routes)
	assert_almost_eq(koku, 0.2, 0.01)


func test_trade_route_disrupted_no_bonus():
	var p := _make_province(1)
	var r := _make_route(1, 1, 2)
	r.is_disrupted = true
	var routes: Array = [r]
	var koku: float = RiceMarketSystem.compute_trade_route_koku(p, routes)
	assert_almost_eq(koku, 0.0, 0.01)


func test_trade_route_connects():
	var r := _make_route(1, 5, 10)
	assert_true(r.connects(5))
	assert_true(r.connects(10))
	assert_false(r.connects(7))


func test_trade_route_other_end():
	var r := _make_route(1, 5, 10)
	assert_eq(r.other_end(5), 10)
	assert_eq(r.other_end(10), 5)
	assert_eq(r.other_end(7), -1)


func test_get_active_routes():
	var r1 := _make_route(1, 1, 2)
	var r2 := _make_route(2, 1, 3)
	r2.is_disrupted = true
	var r3 := _make_route(3, 2, 3)
	var routes: Array = [r1, r2, r3]
	var active: Array = RiceMarketSystem.get_active_routes_for_province(1, routes)
	assert_eq(active.size(), 1)
	assert_eq(active[0].route_id, 1)


func test_disrupt_and_restore_route():
	var r := _make_route(1, 1, 2)
	RiceMarketSystem.disrupt_route(r, "war")
	assert_true(r.is_disrupted)
	assert_eq(r.disruption_reason, "war")
	RiceMarketSystem.restore_route(r)
	assert_false(r.is_disrupted)
	assert_eq(r.disruption_reason, "")
