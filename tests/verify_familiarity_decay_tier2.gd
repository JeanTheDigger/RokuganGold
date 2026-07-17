extends SceneTree
## Runtime driver for s57.27:115 familiarity decay TIER 2 — bonsai + sculpture (owner-approved
## 2026-07-08). Tier 1 activated painting + garden (which already had display-start clocks). Tier 2
## adds the missing continuous-display clocks: BonsaiData.display_start_ic_day (set on DISPLAY_BONSAI,
## reset on settlement change; STANDARD rate) and SculptureData.display_start_ic_day (set on placement
## into a statue/guardian slot; HALF rate -- religious statuary per s57.27:115). Both then scale the
## visitor disposition bonus by PaintingSystem.familiarity_factor.
## Run: godot --headless -s tests/verify_familiarity_decay_tier2.gd

const _PS := preload("res://simulation/painting_system.gd")
const _BD := preload("res://shared/bonsai_data.gd")
const _SD := preload("res://shared/sculpture_data.gd")
const _SET := preload("res://shared/settlement_data.gd")
const _SS := preload("res://simulation/sculpture_system.gd")

const YEAR: int = 360
const TEMPLE: int = 9  # SettlementType.TEMPLE (bonsai + statue eligible)

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _temple(sid: int, lord_id: int) -> SettlementData:
	var s: SettlementData = _SET.new()
	s.settlement_id = sid
	s.settlement_type = TEMPLE
	s.lord_character_id = lord_id
	s.statue_slot = -1
	s.guardian_slot = -1
	s.bonsai_display_slot = -1
	return s


func _init() -> void:
	print("--- s57.27:115 familiarity decay TIER 2 (bonsai + sculpture) ---")
	_test_fields_default_unplaced()
	_test_bonsai_display_clock()
	_test_sculpture_placement_clock()
	_test_rate_distinction()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_fields_default_unplaced() -> void:
	print("[1] the new clocks default to -1 (unplaced -> no decay)")
	var b: BonsaiData = _BD.new()
	var sc: SculptureData = _SD.new()
	_ok(b.display_start_ic_day == -1, "BonsaiData.display_start_ic_day default -1")
	_ok(sc.display_start_ic_day == -1, "SculptureData.display_start_ic_day default -1")
	_ok(_approx(_PS.familiarity_factor(5 * YEAR, b.display_start_ic_day, false), 1.0),
		"unplaced bonsai -> factor 1.0 (no decay)")
	_ok(_approx(_PS.familiarity_factor(5 * YEAR, sc.display_start_ic_day, true), 1.0),
		"unplaced sculpture -> factor 1.0 (no decay)")


func _test_bonsai_display_clock() -> void:
	print("[2] DISPLAY_BONSAI stamps the clock; re-display keeps/resets it correctly")
	var bonsai: BonsaiData = _BD.new()
	bonsai.bonsai_id = 5
	bonsai.is_dead = false
	var t1: SettlementData = _temple(100, 0)
	var t2: SettlementData = _temple(200, 0)
	var chars := {}

	var res := [{"action_id": "DISPLAY_BONSAI", "success": true,
		"effects": {"bonsai_id": 5, "settlement_id": 100}}]
	DayOrchestrator._process_bonsai_display_writebacks(res, [bonsai], chars, [t1, t2], 1000)
	_ok(bonsai.display_start_ic_day == 1000, "first display at settlement 100 -> clock = 1000")
	_ok(bonsai.display_settlement_id == 100, "display_settlement_id = 100")

	# Re-display at the SAME settlement on a later day -> clock preserved (continuous display).
	DayOrchestrator._process_bonsai_display_writebacks(res, [bonsai], chars, [t1, t2], 1500)
	_ok(bonsai.display_start_ic_day == 1000, "re-display at same settlement -> clock preserved (1000)")

	# Display at a DIFFERENT settlement -> clock resets.
	var res2 := [{"action_id": "DISPLAY_BONSAI", "success": true,
		"effects": {"bonsai_id": 5, "settlement_id": 200}}]
	DayOrchestrator._process_bonsai_display_writebacks(res2, [bonsai], chars, [t1, t2], 2000)
	_ok(bonsai.display_start_ic_day == 2000, "moved to settlement 200 -> clock reset (2000)")


func _test_sculpture_placement_clock() -> void:
	print("[3] statuary/guardian placement stamps the (half-rate) clock")
	var statuary: SculptureData = _SD.new()
	statuary.sculpture_id = 7
	statuary.creator_id = 42
	statuary.format = _SS.Format.STATUARY
	statuary.display_settlement_id = 300
	var temple_s: SettlementData = _temple(300, 42)  # creator is the lord -> has permission
	DayOrchestrator._auto_place_completed_sculpture(statuary, {300: temple_s}, 900)
	_ok(temple_s.statue_slot == 7, "statuary placed into the statue slot")
	_ok(statuary.display_start_ic_day == 900, "statuary clock stamped at placement (900)")

	var guardian: SculptureData = _SD.new()
	guardian.sculpture_id = 8
	guardian.creator_id = 42
	guardian.format = _SS.Format.GUARDIAN
	guardian.material = _SS.MaterialType.STONE  # stone: no outdoor-weathering, still familiarity-clocked
	guardian.display_settlement_id = 301
	var temple_g: SettlementData = _temple(301, 42)
	DayOrchestrator._auto_place_completed_sculpture(guardian, {301: temple_g}, 950)
	_ok(temple_g.guardian_slot == 8, "guardian placed into the guardian slot")
	_ok(guardian.display_start_ic_day == 950, "guardian clock stamped at placement (950)")


func _test_rate_distinction() -> void:
	print("[4] bonsai uses the STANDARD rate; sculpture uses the HALF (statuary) rate")
	# At 3 IC years: standard -> 0.70, half -> 0.85.
	_ok(_approx(_PS.familiarity_factor(3 * YEAR, 0, false), 0.70), "bonsai (standard) 3yr -> 0.70")
	_ok(_approx(_PS.familiarity_factor(3 * YEAR, 0, true), 0.85), "sculpture (half) 3yr -> 0.85")
	# A +3 bonsai bonus at 3yr -> round(3*0.70)=2; a +3 sculpture -> round(3*0.85)=3.
	_ok(int(round(3.0 * _PS.familiarity_factor(3 * YEAR, 0, false))) == 2, "bonsai +3 at 3yr -> +2")
	_ok(int(round(3.0 * _PS.familiarity_factor(3 * YEAR, 0, true))) == 3, "sculpture +3 at 3yr -> +3 (slower)")
