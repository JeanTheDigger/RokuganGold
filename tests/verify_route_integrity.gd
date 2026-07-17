extends SceneTree
## Runtime driver for consuming the dormant special_data["route_integrity_reduced"] flag (s54.7c).
## The RUN_COURIER_ROUTE failure writeback SET the flag on the Silk Master, but NOTHING ever read
## it (its one repo reference was the write) and nothing ever cleared it -- so a failed courier
## segment silently did nothing. GDD s54.7c:53 (LOCKED): "Failure ... flags route_integrity_reduced
## for that segment, elevating MAINTAIN_KOLAT_NETWORK priority until the segment is repaired or
## abandoned." Now _assign_kolat_standing_objectives promotes MAINTAIN_KOLAT_NETWORK into the kolat
## objective slot at priority 2 (which "precedes the standing objective", s54.7d) while the flag is
## set, only when the slot is free (never clobbering a Tiger directive), and clears the elevation
## when the flag clears (a clean route repairs the segment).
## Run: godot --headless -s tests/verify_route_integrity.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _silk(cid: int, route_reduced: bool) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.is_kolat_master = true
	c.kolat_sect = Enums.KolatSect.SILK
	if route_reduced:
		c.special_data["route_integrity_reduced"] = true
	return c


func _coin(cid: int, route_reduced: bool) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.is_kolat_master = true
	c.kolat_sect = Enums.KolatSect.COIN
	if route_reduced:
		c.special_data["route_integrity_reduced"] = true
	return c


func _assign(chars: Array) -> Dictionary:
	var omap: Dictionary = {}
	_DO._assign_kolat_standing_objectives(chars, omap, {})
	return omap


func _init() -> void:
	print("--- route_integrity_reduced -> MAINTAIN_KOLAT_NETWORK elevation (s54.7c) ---")
	_test_elevates()
	_test_no_flag_no_elevation()
	_test_clears_on_repair()
	_test_respects_tiger_directive()
	_test_non_silk_unaffected()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_elevates() -> void:
	print("[1] Silk Master with a failed route -> kolat slot MAINTAIN_KOLAT_NETWORK @ priority 2")
	var omap := _assign([_silk(1, true)])
	var kolat: Dictionary = omap.get(1, {}).get("kolat", {})
	_ok(kolat.get("need_type", "") == "MAINTAIN_KOLAT_NETWORK", "kolat slot = MAINTAIN_KOLAT_NETWORK")
	_ok(int(kolat.get("priority", -1)) == 2, "priority 2 (precedes standing, s54.7d)")
	_ok(String(kolat.get("source", "")) == "route_integrity", "source route_integrity")
	# The flat standing mandate is still assigned too.
	_ok(omap.get(1, {}).get("standing", {}).get("need_type", "") == "MAINTAIN_KOLAT_NETWORK",
		"standing mandate still assigned")


func _test_no_flag_no_elevation() -> void:
	print("[2] Silk Master with a clean network -> no kolat elevation")
	var omap := _assign([_silk(2, false)])
	_ok(omap.get(2, {}).get("kolat", {}).is_empty(), "no kolat elevation when flag unset")


func _test_clears_on_repair() -> void:
	print("[3] flag cleared (segment repaired) -> the route_integrity elevation is removed")
	var c := _silk(3, true)
	var omap: Dictionary = {}
	_DO._assign_kolat_standing_objectives([c], omap, {})
	_ok(not omap.get(3, {}).get("kolat", {}).is_empty(), "elevated while flag set")
	# Repair: clear the flag (as a clean RUN_COURIER_ROUTE does) and re-run assignment.
	c.special_data.erase("route_integrity_reduced")
	_DO._assign_kolat_standing_objectives([c], omap, {})
	_ok(omap.get(3, {}).get("kolat", {}).is_empty(), "route_integrity elevation cleared on repair")


func _test_respects_tiger_directive() -> void:
	print("[4] a Tiger directive already in the kolat slot is NOT clobbered")
	var c := _silk(4, true)
	var omap: Dictionary = {4: {"kolat": {"need_type": "ELIMINATE_CHARACTER", "priority": 3, "source": "tiger_directive"}}}
	_DO._assign_kolat_standing_objectives([c], omap, {})
	var kolat: Dictionary = omap.get(4, {}).get("kolat", {})
	_ok(kolat.get("need_type", "") == "ELIMINATE_CHARACTER" and String(kolat.get("source", "")) == "tiger_directive",
		"Tiger directive preserved (route-integrity only fills a free slot)")


func _test_non_silk_unaffected() -> void:
	print("[5] a non-Silk Master (Coin) with the flag set gets no route elevation")
	var omap := _assign([_coin(5, true)])
	_ok(omap.get(5, {}).get("kolat", {}).is_empty(), "Coin master: no route_integrity elevation")
