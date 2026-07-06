extends SceneTree
## End-to-end check on the PRODUCTION world (WorldBootstrap), not synthetic
## scenarios: confirms the 12 real Towers + Phase-2 roster exist, then deplete a
## real Tower's jade/tea and taint its stationed Kuni to Rank 4, run the three
## D5/D6/D7 seasonal passes in the same order advance_day uses, and observe live
## behaviour on production data. Run: godot --headless -s tests/verify_wall_live_integration.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _WB := preload("res://simulation/world_bootstrap.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- Wall Live Integration (production world) ---")
	var dice := DiceEngine.new()
	dice.set_seed(777)
	var world: Dictionary = _WB.bootstrap_world(dice)
	var settlements: Array = world["settlements"]
	var provinces: Dictionary = world["provinces"]
	var characters: Array = world["characters"]

	# Real Towers.
	var towers: Array = []
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			towers.append(s)
	_ok(towers.size() == 12, "12 real Wall Towers created (%d)" % towers.size())

	# Real stationed roster: at least one Shireikan and one Kuni Shugenja at a Tower.
	var tower_locs: Dictionary = {}
	for t: SettlementData in towers:
		tower_locs[str(t.settlement_id)] = t
	var shireikan_count: int = 0
	var kuni_at_tower: L5RCharacterData = null
	var kuni_tower: SettlementData = null
	for c: L5RCharacterData in characters:
		if not tower_locs.has(c.physical_location):
			continue
		if c.military_rank == Enums.MilitaryRank.SHIREIKAN:
			shireikan_count += 1
		if c.school == "Kuni Shugenja" and kuni_at_tower == null:
			kuni_at_tower = c
			kuni_tower = tower_locs[c.physical_location]
	_ok(shireikan_count == 2, "2 real Shireikan stationed (%d)" % shireikan_count)
	_ok(kuni_at_tower != null, "a real Kuni Shugenja is stationed at a Tower")
	if kuni_at_tower == null:
		print("--- %d passed, %d failed ---" % [_pass, _fail])
		quit(1 if _fail > 0 else 0)
		return

	# Deplete this Tower's jade + tea, and taint the Kuni to Rank 4.
	kuni_tower.jade_stockpile = 0.0
	kuni_tower.tea_stockpile = 0.0
	var kuni_taint_before: float = kuni_at_tower.taint
	# Give the Kuni Rank-1 taint so it consumes Tea; then a separate garrison-mate
	# at Rank 4 to trigger removal (keep the Kuni present to assess).
	kuni_at_tower.taint = 1.0
	# A Tainted Taisa at the same Tower, pushed to Rank 4 for removal.
	var taisa: L5RCharacterData = null
	for c: L5RCharacterData in characters:
		if c.physical_location == str(kuni_tower.settlement_id) and c.military_rank == Enums.MilitaryRank.TAISA:
			taisa = c
			break
	_ok(taisa != null, "a real Taisa is stationed at the same Tower")
	if taisa != null:
		taisa.taint = 4.0

	# Run the three passes in advance_day's seasonal order.
	var jade_res: Array = _DO._process_wall_jade_resupply(characters, settlements, provinces)
	var tea_res: Array = _DO._process_wall_tea_resupply(characters, settlements)
	var tea_con: Array = _DO._process_wall_tea_consumption(characters, settlements, 90)
	var removals: Array = _DO._process_wall_taint_removal(characters, settlements, provinces)

	# D5: the depleted Tower got jade back (routine target for its garrison).
	_ok(kuni_tower.jade_stockpile > 0.0, "D5: depleted Tower refilled with jade (%.1f)" % kuni_tower.jade_stockpile)
	_ok(not jade_res.is_empty(), "D5: jade resupply reported deliveries")

	# D6: the Kuni (Rank 1) got dosed and is now managed.
	_ok(kuni_at_tower.tea_managed_until_ic_day > 90, "D6: stationed Kuni dosed + managed")
	var tea_delivered: bool = false
	for r: Dictionary in tea_res:
		if float(r.get("tea_delivered", 0.0)) > 0.0:
			tea_delivered = true
	_ok(tea_delivered, "D6: tea resupply delivered to a Tainted Tower")

	# D7: the Rank-4 Taisa was removed off the Wall + detached.
	if taisa != null:
		_ok(taisa.physical_location != str(kuni_tower.settlement_id), "D7: Rank-4 Taisa relocated off the Wall")
		_ok(taisa.operational_superior_id == -1, "D7: removed Taisa detached from hierarchy")
		var removed_taisa: bool = false
		for r: Dictionary in removals:
			if int(r.get("removed_id", -1)) == taisa.character_id:
				removed_taisa = true
		_ok(removed_taisa, "D7: removal reported for the Taisa")

	# Reset the Kuni's taint we borrowed (hygiene; world is discarded anyway).
	kuni_at_tower.taint = kuni_taint_before

	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
