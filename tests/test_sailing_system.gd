extends GutTest
## GUT tests for SailingSystem (simulation/sailing_system.gd). GDD s57.42 / s57.43 / s57.42a.


func _char(id: int, sailing: int = 0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.skills = {"Sailing": sailing} if sailing > 0 else {}
	c.status = 1.0
	return c


func _ship(ship_class: int = Enums.ShipClass.KOBUNE) -> ShipData:
	var s := ShipData.new()
	s.ship_id = 1
	s.ship_class = ship_class
	return s


# === Captain requirements (s57.42.3) ===

func test_min_sailing_by_class() -> void:
	assert_eq(SailingSystem.min_sailing_for_class(Enums.ShipClass.SAMPAN), 1)
	assert_eq(SailingSystem.min_sailing_for_class(Enums.ShipClass.KOBUNE), 1)
	assert_eq(SailingSystem.min_sailing_for_class(Enums.ShipClass.SENGOKOBUNE), 3)
	assert_eq(SailingSystem.min_sailing_for_class(Enums.ShipClass.KOUTETSUKAN), 4)
	assert_eq(SailingSystem.min_sailing_for_class(Enums.ShipClass.ATAKEBUNE), 4)


func test_captain_meets_requirement() -> void:
	assert_true(SailingSystem.captain_meets_requirement(_char(1, 1), Enums.ShipClass.KOBUNE))
	assert_false(SailingSystem.captain_meets_requirement(_char(1, 0), Enums.ShipClass.KOBUNE))
	assert_false(SailingSystem.captain_meets_requirement(_char(1, 3), Enums.ShipClass.KOUTETSUKAN))
	assert_true(SailingSystem.captain_meets_requirement(_char(1, 4), Enums.ShipClass.KOUTETSUKAN))


func test_self_captain_penalty() -> void:
	assert_eq(SailingSystem.self_captain_penalty(_char(1, 0), Enums.ShipClass.KOBUNE), -2,
		"under-qualified self-captain takes −2k0")
	assert_eq(SailingSystem.self_captain_penalty(_char(1, 1), Enums.ShipClass.KOBUNE), 0)


# === Captain succession (s57.42.5) ===

func test_acting_captain_picks_highest_sailing() -> void:
	var crew: Array = [_char(10, 1), _char(11, 3), _char(12, 2)]
	assert_eq(SailingSystem.select_acting_captain(crew), 11)


func test_acting_captain_tiebreak_insight() -> void:
	var a := _char(20, 2); a.intelligence = 5; a.void_ring = 5  # higher insight
	var b := _char(21, 2)
	assert_eq(SailingSystem.select_acting_captain([b, a]), 20,
		"ties on Sailing broken by Insight")


func test_acting_captain_none_when_no_sailing() -> void:
	assert_eq(SailingSystem.select_acting_captain([_char(30, 0), _char(31, 0)]), -1,
		"no crew with Sailing → catastrophic peril (-1)")


func test_acting_captain_skips_dead() -> void:
	var dead := _char(40, 5); dead.wounds_taken = 9999
	var alive := _char(41, 1)
	assert_eq(SailingSystem.select_acting_captain([dead, alive]), 41)


# === REQUEST_PASSAGE acceptance (s57.42.7) ===

func test_standing_orders_hard_refuse() -> void:
	var cap := _char(1, 2)
	var r := SailingSystem.evaluate_passage_request(cap, 50, 10.0, true, true)
	assert_false(r["accepted"])
	assert_eq(r["reason"], "standing_orders")


func test_schedule_incompatible_hard_refuse() -> void:
	var cap := _char(1, 2)
	var r := SailingSystem.evaluate_passage_request(cap, 50, 10.0, false, false)
	assert_false(r["accepted"])
	assert_eq(r["reason"], "schedule_incompatible")


func test_free_passage_at_acquaintance() -> void:
	var cap := _char(1, 2)
	var r := SailingSystem.evaluate_passage_request(cap, 11, 0.0, true, false)
	assert_true(r["accepted"], "Acquaintance+ rides free")
	assert_eq(r["reason"], "disposition")


func test_low_disposition_needs_compensation() -> void:
	var cap := _char(1, 2)  # no helpful virtue
	# disposition 5, gap to 11 = 6; 2 koku is not enough.
	var r1 := SailingSystem.evaluate_passage_request(cap, 5, 2.0, true, false)
	assert_false(r1["accepted"], "small offer fails to bridge the gap")
	# 6 koku bridges the gap.
	var r2 := SailingSystem.evaluate_passage_request(cap, 5, 6.0, true, false)
	assert_true(r2["accepted"])
	assert_eq(r2["reason"], "compensation")


func test_jin_lean_helps_struggling_traveler() -> void:
	var cap := _char(1, 2); cap.bushido_virtue = Enums.BushidoVirtue.JIN
	# disposition 5, gap 6, no koku, but Jin +5 lean → 5 < 6 still short.
	assert_false(SailingSystem.evaluate_passage_request(cap, 5, 0.0, true, false)["accepted"])
	# disposition 6, gap 5, Jin +5 lean bridges it with no koku.
	assert_true(SailingSystem.evaluate_passage_request(cap, 6, 0.0, true, false)["accepted"])


func test_rei_high_status_lean() -> void:
	var cap := _char(1, 2); cap.bushido_virtue = Enums.BushidoVirtue.REI
	var high := SailingSystem.evaluate_passage_request(cap, 9, 0.0, true, false, 5.0)
	assert_true(high["accepted"], "Rei accepts a high-status requester (gap 2, +2 lean)")


# === Refusal / throttle / cooldown ===

func test_refusal_disposition_shift() -> void:
	assert_eq(SailingSystem.refusal_disposition_shift(false), 0, "polite refusal: no shift")
	assert_eq(SailingSystem.refusal_disposition_shift(true, 3), -3)
	assert_eq(SailingSystem.refusal_disposition_shift(true, 9), -3, "clamped to −3")


func test_request_throttle_and_cooldown() -> void:
	assert_true(SailingSystem.can_request_passage(0, 5, -1))
	assert_false(SailingSystem.can_request_passage(2, 5, -1), "2/day throttle")
	assert_false(SailingSystem.can_request_passage(0, 5, 5), "same-day refusal cooldown")
	assert_true(SailingSystem.can_request_passage(0, 6, 5), "cooldown clears next IC day")


# === Embarkation (s57.42.8) ===

func test_board_only_colocated_passengers() -> void:
	var ship := _ship()
	var here := _char(50); here.physical_location = "port_a"
	var elsewhere := _char(51); elsewhere.physical_location = "port_b"
	var boarded := SailingSystem.board_passengers(ship, [here, elsewhere], "port_a")
	assert_eq(boarded, [50], "only the co-located passenger boards")
	assert_eq(here.aboard_ship_id, 1)
	assert_eq(elsewhere.aboard_ship_id, -1, "absent passenger left behind")


func test_disembark_clears_and_places() -> void:
	var p := _char(60); p.aboard_ship_id = 1
	SailingSystem.disembark(p, "port_dest")
	assert_eq(p.aboard_ship_id, -1)
	assert_eq(p.physical_location, "port_dest")


# === Voyage formulas (s57.43) ===

func test_pirate_interception_chance() -> void:
	assert_almost_eq(SailingSystem.pirate_interception_chance(3), 0.30, 0.001)
	assert_almost_eq(SailingSystem.pirate_interception_chance(8), 0.80, 0.001)
	assert_eq(SailingSystem.pirate_interception_chance(0), 0.0)


func test_interception_resolution() -> void:
	assert_eq(SailingSystem.interception_resolution(2), "deck_skirmish")
	assert_eq(SailingSystem.interception_resolution(4), "naval_mass_battle")
	assert_eq(SailingSystem.interception_resolution(0), "none")


func test_shipwreck_landfall_chance() -> void:
	assert_almost_eq(SailingSystem.shipwreck_landfall_chance(1), 0.10, 0.001)
	assert_almost_eq(SailingSystem.shipwreck_landfall_chance(1, true), 0.30, 0.001)
	assert_almost_eq(SailingSystem.shipwreck_landfall_chance(2), 0.25, 0.001)
	assert_almost_eq(SailingSystem.shipwreck_landfall_chance(4), 0.60, 0.001)
	assert_almost_eq(SailingSystem.shipwreck_landfall_chance(6), 0.60, 0.001, "capped at 60%")
	assert_eq(SailingSystem.shipwreck_landfall_chance(7), 0.0, "past the 6-day ceiling = lost")
