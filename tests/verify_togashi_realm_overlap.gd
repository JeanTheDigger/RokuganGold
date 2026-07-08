extends SceneTree
## Runtime driver for wiring the Togashi Oversight realm-overlap facts (s55.10.2 SPIRITUAL_HEALTH).
## _build_togashi_world_state (the SOLE producer of the oversight world_state) HARDCODED
## "realm_overlaps_empire_wide": 0 and "realm_overlap_in_dragon_territory": false, so the Dragon
## Champion's two realm-overlap concern triggers were permanently dead (only failing_worship +
## max_non_shadowlands_ptl could fire the SPIRITUAL_HEALTH concern). They are now computed from the
## live SpiritualInsurgencySystem events (active REALM_OVERLAP count empire-wide; whether any is in a
## Dragon-clan province). No invented values -- plain facts; thresholds are GDD-locked in the consumer.
## Run: godot --headless -s tests/verify_togashi_realm_overlap.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _TO := preload("res://simulation/togashi_oversight.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _prov(pid: int, clan: String, ptl: float = 0.0, insurg: int = -1, sl: float = 0.0, stab: float = 80.0) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	p.province_taint_level = ptl  # keep max_non_shadowlands_ptl off by default
	p.active_insurgency_id = insurg
	p.shadowlands_strength = sl
	p.stability = stab
	return p


func _overlap(pid: int, resolved: bool = false, etype: int = Enums.SpiritualEventType.REALM_OVERLAP) -> SpiritualInsurgencyData:
	var e := SpiritualInsurgencyData.new()
	e.province_id = pid
	e.event_type = etype as Enums.SpiritualEventType
	e.resolved = resolved
	return e


func _build(spiritual_events: Array) -> Dictionary:
	# EMPTY world_states (no dead "province_data" key) + a REAL provinces Dictionary:
	# 1000=Dragon, 1001/1002=Lion. This proves the builder reads the real provinces param
	# (if it still read the dead top-level key, province_clan would be empty and the
	# Dragon-territory check below would always be false).
	var provinces: Dictionary = {1000: _prov(1000, "Dragon"), 1001: _prov(1001, "Lion"), 1002: _prov(1002, "Lion")}
	return _DO._build_togashi_world_state({}, [], {}, spiritual_events, provinces)


func _war(a: String, b: String) -> WarData:
	var w := WarData.new()
	w.clan_a = a
	w.clan_b = b
	w.is_active = true
	return w


func _init() -> void:
	print("--- Togashi realm-overlap facts wired from spiritual insurgency events (s55.10.2) ---")
	_test_producer()
	_test_consumer()
	_test_province_source()
	_test_inter_clan_wars()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_inter_clan_wars() -> void:
	print("[4] active_inter_clan_wars counts the real active_wars param (was reading a dead top-level key)")
	# emperor_id set so emperor_vacant is false -> isolates the inter-clan-wars trigger.
	var w2: Dictionary = _DO._build_togashi_world_state({"emperor_id": 1}, [], {}, [], {}, [_war("Lion", "Crane"), _war("Crab", "Scorpion")])
	_ok(int(w2["active_inter_clan_wars"]) == 2, "2 real wars -> count 2")
	_ok(_TO.imperial_cohesion_concern_fires(w2) == true, "2 inter-clan wars fire IMPERIAL_COHESION")
	var w1: Dictionary = _DO._build_togashi_world_state({"emperor_id": 1}, [], {}, [], {}, [_war("Lion", "Crane")])
	_ok(int(w1["active_inter_clan_wars"]) == 1, "1 real war -> count 1")
	_ok(_TO.imperial_cohesion_concern_fires(w1) == false, "1 inter-clan war below threshold -> IMPERIAL_COHESION silent")
	# A same-clan (malformed) war entry is not counted as inter-clan.
	var w0: Dictionary = _DO._build_togashi_world_state({"emperor_id": 1}, [], {}, [], {}, [_war("Lion", "Lion")])
	_ok(int(w0["active_inter_clan_wars"]) == 0, "same-clan war not counted as inter-clan")


func _test_producer() -> void:
	print("[1] _build_togashi_world_state computes the two realm facts (was hardcoded 0/false)")
	# No events -> 0/false (no regression vs the old hardcoded behavior)
	var w0: Dictionary = _build([])
	_ok(int(w0["realm_overlaps_empire_wide"]) == 0, "no events -> count 0")
	_ok(bool(w0["realm_overlap_in_dragon_territory"]) == false, "no events -> dragon false")

	# Two active overlaps in Lion provinces -> count 2, dragon false
	var w1: Dictionary = _build([_overlap(1001), _overlap(1002)])
	_ok(int(w1["realm_overlaps_empire_wide"]) == 2, "2 Lion overlaps -> count 2")
	_ok(bool(w1["realm_overlap_in_dragon_territory"]) == false, "2 Lion overlaps -> dragon false")

	# One active overlap in the Dragon province -> dragon true
	var w2: Dictionary = _build([_overlap(1000)])
	_ok(int(w2["realm_overlaps_empire_wide"]) == 1, "1 Dragon overlap -> count 1")
	_ok(bool(w2["realm_overlap_in_dragon_territory"]) == true, "1 Dragon overlap -> dragon true")

	# A RESOLVED overlap is not counted
	var w3: Dictionary = _build([_overlap(1000, true), _overlap(1001, false)])
	_ok(int(w3["realm_overlaps_empire_wide"]) == 1, "resolved excluded -> count 1")
	_ok(bool(w3["realm_overlap_in_dragon_territory"]) == false, "resolved Dragon overlap not counted -> dragon false")

	# A non-REALM_OVERLAP event (ELEMENTAL_IMBALANCE) is not counted
	var w4: Dictionary = _build([_overlap(1000, false, Enums.SpiritualEventType.ELEMENTAL_IMBALANCE)])
	_ok(int(w4["realm_overlaps_empire_wide"]) == 0, "ELEMENTAL_IMBALANCE not counted -> 0")
	_ok(bool(w4["realm_overlap_in_dragon_territory"]) == false, "ELEMENTAL_IMBALANCE not counted -> dragon false")


func _test_consumer() -> void:
	print("[2] TogashiOversight.spiritual_health_concern_fires now reacts to the realm facts")
	# Clean baseline (no worship failures, no PTL, no overlaps) -> concern does NOT fire
	var w0: Dictionary = _build([])
	_ok(_TO.spiritual_health_concern_fires(w0) == false, "no triggers -> concern silent")

	# A single Dragon-territory overlap fires the concern by itself (was dead)
	var w_dragon: Dictionary = _build([_overlap(1000)])
	_ok(_TO.spiritual_health_concern_fires(w_dragon) == true, "Dragon-territory overlap fires the concern")

	# 3 empire-wide overlaps (REALM_OVERLAPS_EMPIRE_WIDE threshold) fire the concern
	var w_empire: Dictionary = _build([_overlap(1001), _overlap(1002), _overlap(1001)])
	_ok(_TO.spiritual_health_concern_fires(w_empire) == true, "3 empire-wide overlaps fire the concern")

	# 2 empire-wide overlaps (below the >=3 threshold, none in Dragon land) do NOT fire
	var w_below: Dictionary = _build([_overlap(1001), _overlap(1002)])
	_ok(_TO.spiritual_health_concern_fires(w_below) == false, "2 non-Dragon overlaps below threshold -> silent")


func _test_province_source() -> void:
	print("[3] province-derived facts now read the real provinces param (were reading a dead top-level key)")
	# EMPTY world_states + real provinces: a Lion province at PTL 5.0, one in rebellion, one wall breach.
	var provinces: Dictionary = {
		2000: _prov(2000, "Lion", 5.0, 42, 0.0, 80.0),          # PTL 5 -> max_non_shadowlands_ptl
		2001: _prov(2001, "Crab", 0.0, -1, 3.0, 20.0),          # SL strength + low stability -> wall breach
	}
	var w: Dictionary = _DO._build_togashi_world_state({}, [], {}, [], provinces)
	_ok(int(w["provinces_in_rebellion"]) == 1, "rebellion_count reads real provinces (1)")
	_ok(is_equal_approx(float(w["max_non_shadowlands_ptl"]), 5.0), "max_non_shadowlands_ptl reads real provinces (5.0)")
	_ok(bool(w["wall_breach_active"]) == true, "wall_breach_active reads real provinces (true)")
	# And with an EMPTY provinces + empty world_states, they safely default (no crash, all off)
	var w0: Dictionary = _DO._build_togashi_world_state({}, [], {}, [], {})
	_ok(int(w0["provinces_in_rebellion"]) == 0, "empty provinces -> rebellion 0 (safe fallback)")
	_ok(bool(w0["wall_breach_active"]) == false, "empty provinces -> wall breach false (safe fallback)")
