extends SceneTree
## Runtime driver for the wood-guardian outdoor-degradation stamp fix (s57.28).
## SculptureSystem.apply_outdoor_degradation (live, seasonal at day_orchestrator:35300) weathers a
## WOOD guardian -1 quality tier per WOOD_OUTDOOR_DEGRADATION_DAYS, but early-returns when
## ic_day_placed_outdoor < 0. The ONLY producer of that stamp was SculptureSystem.place_sculpture --
## which the live placement path DayOrchestrator._auto_place_completed_sculpture BYPASSED, so every
## in-game wood guardian kept the -1 default and never weathered (a dead effect). Fix: the inline
## guardian placement now stamps ic_day_placed_outdoor = ic_day for WOOD, mirroring place_sculpture.
## Run: godot --headless -s tests/verify_sculpture_outdoor_degradation.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _SS := preload("res://simulation/sculpture_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _guardian(material: int, tier: int) -> SculptureData:
	var s := SculptureData.new()
	s.sculpture_id = 77
	s.format = _SS.Format.GUARDIAN
	s.material = material
	s.quality_tier = tier
	s.craft_progress = -1  # complete
	s.creator_id = 1
	s.display_settlement_id = 10
	s.paired = false
	return s


func _temple() -> SettlementData:
	var st := SettlementData.new()
	st.settlement_id = 10
	st.settlement_type = Enums.SettlementType.TEMPLE
	st.lord_character_id = 1  # creator is lord -> has_guardian_permission
	st.guardian_slot = -1
	return st


func _init() -> void:
	print("--- Wood-guardian outdoor degradation stamp revived (s57.28) ---")
	_test_pre_fix_dead()
	_test_stamp_and_degrade()
	_test_stone_untouched()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_pre_fix_dead() -> void:
	print("[1] an UNPLACED wood guardian never weathers (the -1 default early-return)")
	var g := _guardian(_SS.MaterialType.WOOD, 3)
	_ok(g.ic_day_placed_outdoor == -1, "fresh sculpture ic_day_placed_outdoor default -1")
	# Without the placement stamp, even after 10x the degradation window, no tier is lost.
	var tier: int = _SS.apply_outdoor_degradation(g, _SS.WOOD_OUTDOOR_DEGRADATION_DAYS * 10)
	_ok(tier == 3 and g.quality_tier == 3, "unplaced wood guardian does not degrade (early-return on -1)")


func _test_stamp_and_degrade() -> void:
	print("[2] placement stamps the outdoor clock -> degradation now fires")
	var g := _guardian(_SS.MaterialType.WOOD, 3)
	var st := _temple()
	_DO._auto_place_completed_sculpture(g, {10: st}, 500)
	_ok(st.guardian_slot == g.sculpture_id, "placed into the guardian slot")
	_ok(g.display_slot == _SS.DisplaySlot.GUARDIAN_SLOT, "display_slot = GUARDIAN_SLOT")
	_ok(g.ic_day_placed_outdoor == 500, "ic_day_placed_outdoor stamped = ic_day (was -1: the bug)")

	# One full degradation window elapsed -> lose exactly one tier (3 -> 2).
	var tier: int = _SS.apply_outdoor_degradation(g, 500 + _SS.WOOD_OUTDOOR_DEGRADATION_DAYS)
	_ok(tier == 2 and g.quality_tier == 2, "one window elapsed -> -1 tier (3 -> 2) — the revived effect")
	# Not yet another full window -> no further loss (clock re-anchored).
	var tier2: int = _SS.apply_outdoor_degradation(g, 500 + _SS.WOOD_OUTDOOR_DEGRADATION_DAYS + 10)
	_ok(tier2 == 2, "sub-window elapsed after re-anchor -> no further loss")
	# Never below tier 1.
	var tier3: int = _SS.apply_outdoor_degradation(g, 500 + _SS.WOOD_OUTDOOR_DEGRADATION_DAYS * 20)
	_ok(tier3 == 1, "floors at quality tier 1 (never destroyed by weathering)")


func _test_stone_untouched() -> void:
	print("[3] a STONE guardian is indoors-durable: no outdoor stamp, no weathering")
	var g := _guardian(_SS.MaterialType.STONE, 4)
	var st := _temple()
	_DO._auto_place_completed_sculpture(g, {10: st}, 500)
	_ok(st.guardian_slot == g.sculpture_id, "stone guardian still placed")
	_ok(g.ic_day_placed_outdoor == -1, "stone guardian NOT stamped (only wood weathers outdoors)")
	var tier: int = _SS.apply_outdoor_degradation(g, 500 + _SS.WOOD_OUTDOOR_DEGRADATION_DAYS * 5)
	_ok(tier == 4 and g.quality_tier == 4, "stone guardian does not weather")
