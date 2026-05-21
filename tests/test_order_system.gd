extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_order_state(
	rank: Enums.MilitaryRank = Enums.MilitaryRank.TAISA,
	is_lord: bool = false,
) -> Dictionary:
	return OrderSystem.create_order_state(1, rank, is_lord)


# -- Create Order State Tests ---------------------------------------------------

func test_create_chui_order_state() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.CHUI)
	assert_eq(s["budget"], 5)
	assert_eq(s["orders_used"], 0)


func test_create_taisa_order_state() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.TAISA)
	assert_eq(s["budget"], 10)


func test_create_shireikan_order_state() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.SHIREIKAN)
	assert_eq(s["budget"], 10)


func test_create_rikugunshokan_order_state() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.RIKUGUNSHOKAN)
	assert_eq(s["budget"], 15)


func test_create_lord_order_state() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.NONE, true)
	assert_eq(s["budget"], 10)


func test_remaining_orders() -> void:
	var s: Dictionary = _make_order_state()
	assert_eq(OrderSystem.get_remaining_orders(s), 10)


func test_reset_daily_orders() -> void:
	var s: Dictionary = _make_order_state()
	s["orders_used"] = 7
	OrderSystem.reset_daily_orders(s)
	assert_eq(s["orders_used"], 0)
	assert_eq(OrderSystem.get_remaining_orders(s), 10)


# -- Issue Order Tests -----------------------------------------------------------

func test_issue_order_same_location_instant() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_scout_order(10, 5)
	var r: Dictionary = OrderSystem.issue_order(s, order, true)
	assert_true(r["success"])
	assert_true(r["instant"])
	assert_eq(r["delivery_days"], 0)
	assert_eq(r["orders_remaining"], 9)


func test_issue_order_remote_has_delay() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_march_order(10, 20)
	var r: Dictionary = OrderSystem.issue_order(s, order, false, 3)
	assert_true(r["success"])
	assert_false(r["instant"])
	assert_eq(r["delivery_days"], 3)


func test_issue_order_insufficient_budget() -> void:
	var s: Dictionary = OrderSystem.create_order_state(1, Enums.MilitaryRank.CHUI)
	# Use all 5 orders
	for i: int in 5:
		var order: Dictionary = OrderSystem.create_scout_order(i + 10, i)
		OrderSystem.issue_order(s, order, true)
	# 6th should fail
	var extra: Dictionary = OrderSystem.create_scout_order(20, 10)
	var r: Dictionary = OrderSystem.issue_order(s, extra, true)
	assert_false(r["success"])
	assert_eq(r["reason"], "insufficient_orders")


func test_issue_standing_patrol() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_patrol_order(10, 5)
	var r: Dictionary = OrderSystem.issue_order(s, order, true)
	assert_true(r["success"])
	assert_eq(s["standing_orders"].size(), 1)
	assert_eq(s["pending_orders"].size(), 0)


func test_issue_non_standing_order_goes_to_pending() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_scout_order(10, 5)
	OrderSystem.issue_order(s, order, false, 2)
	assert_eq(s["pending_orders"].size(), 1)
	assert_eq(s["standing_orders"].size(), 0)


# -- Messenger Delivery Tests ----------------------------------------------------

func test_process_pending_delivers_after_days() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_march_order(10, 20)
	OrderSystem.issue_order(s, order, false, 2)
	# Day 1: still pending
	var d1: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d1.size(), 0)
	assert_eq(s["pending_orders"].size(), 1)
	# Day 2: delivered
	var d2: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d2.size(), 1)
	assert_eq(s["pending_orders"].size(), 0)
	assert_true(d2[0]["delivered"])


func test_process_pending_instant_already_delivered() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_scout_order(10, 5)
	OrderSystem.issue_order(s, order, true)
	# Instant orders go to pending but are already delivered
	var d: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d.size(), 1)


func test_process_multiple_pending() -> void:
	var s: Dictionary = _make_order_state()
	var o1: Dictionary = OrderSystem.create_march_order(10, 20)
	var o2: Dictionary = OrderSystem.create_march_order(11, 21)
	OrderSystem.issue_order(s, o1, false, 1)
	OrderSystem.issue_order(s, o2, false, 3)
	# Day 1: o1 delivers
	var d1: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d1.size(), 1)
	assert_eq(s["pending_orders"].size(), 1)
	# Day 2: still waiting
	var d2: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d2.size(), 0)
	# Day 3: o2 delivers
	var d3: Array = OrderSystem.process_pending_orders(s)
	assert_eq(d3.size(), 1)


# -- Standing Order Tests --------------------------------------------------------

func test_cancel_standing_order() -> void:
	var s: Dictionary = _make_order_state()
	var order: Dictionary = OrderSystem.create_patrol_order(10, 5)
	OrderSystem.issue_order(s, order, true)
	assert_eq(s["standing_orders"].size(), 1)
	var r: Dictionary = OrderSystem.cancel_standing_order(s, 10)
	assert_true(r["cancelled"])
	assert_eq(s["standing_orders"].size(), 0)


func test_cancel_standing_order_not_found() -> void:
	var s: Dictionary = _make_order_state()
	var r: Dictionary = OrderSystem.cancel_standing_order(s, 99)
	assert_false(r["cancelled"])


func test_get_standing_orders() -> void:
	var s: Dictionary = _make_order_state()
	var o1: Dictionary = OrderSystem.create_patrol_order(10, 5)
	var o2: Dictionary = OrderSystem.create_patrol_order(11, 6)
	OrderSystem.issue_order(s, o1, true)
	OrderSystem.issue_order(s, o2, true)
	var standing: Array = OrderSystem.get_standing_orders(s)
	assert_eq(standing.size(), 2)


# -- Messenger Travel Time Tests -------------------------------------------------

func test_messenger_travel_time_adjacent() -> void:
	assert_eq(OrderSystem.compute_messenger_travel_time(1), 1)


func test_messenger_travel_time_distant() -> void:
	assert_eq(OrderSystem.compute_messenger_travel_time(5), 5)


func test_messenger_travel_time_minimum_1() -> void:
	assert_eq(OrderSystem.compute_messenger_travel_time(0), 1)


# -- Order Creation Helpers ------------------------------------------------------

func test_create_scout_order() -> void:
	var o: Dictionary = OrderSystem.create_scout_order(10, 5)
	assert_eq(o["order_type"], OrderSystem.OrderType.SCOUT)
	assert_eq(o["target_character_id"], 10)
	assert_eq(o["target_location_id"], 5)


func test_create_patrol_order_is_standing() -> void:
	var o: Dictionary = OrderSystem.create_patrol_order(10, 5)
	assert_true(o["is_standing"])


func test_create_march_order() -> void:
	var o: Dictionary = OrderSystem.create_march_order(10, 20)
	assert_eq(o["order_type"], OrderSystem.OrderType.MARCH_TO)
	assert_eq(o["target_location_id"], 20)
