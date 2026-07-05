extends SceneTree
## Headless runtime driver for the s56.1.2 Oni Manifestation roster lift.
## Verifies: BOSS-tier oni selection, solo-boss roster composition, the seed gate
## flipped to roster_ready, and the seed→roster→map→population pipeline.
## Run: godot --headless -s tests/verify_oni_manifestation.gd

const _QSS := preload("res://simulation/quest_seed_selector.gd")
const _RCS := preload("res://simulation/roster_composition_system.gd")
const _MB := preload("res://simulation/mission_builder.gd")
const _OB := preload("res://simulation/oni_bestiary.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- Oni Manifestation Verification (s56.1.2) ---")
	_test_boss_ids()
	_test_roster()
	_test_seed_gate()
	_test_pipeline()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_boss_ids() -> void:
	print("[1] boss_ids")
	var ids: Array = _OB.boss_ids()
	_ok(ids.size() >= 10, "several boss-tier oni (%d)" % ids.size())
	# All returned ids are BOSS tier and resolvable.
	var all_boss: bool = true
	for id: Variant in ids:
		var o: SpiritCreatureData = _OB.get_oni(String(id))
		if o == null or o.tier != SpiritCreatureData.Tier.BOSS:
			all_boss = false
	_ok(all_boss, "every id is a resolvable BOSS-tier oni")
	# Deterministic (sorted) — no spawn-only helpers.
	_ok(not ("tasu_spawn" in ids) and not ("wakeru_lesser" in ids), "spawn helpers excluded")
	_ok(ids == ids.duplicate() and _is_sorted(ids), "sorted / deterministic order")


func _is_sorted(a: Array) -> bool:
	for i: int in range(1, a.size()):
		if String(a[i]) < String(a[i - 1]):
			return false
	return true


func _test_roster() -> void:
	print("[2] roster composition")
	var r: Dictionary = _RCS.compose_roster(_RCS.SEED_ONI_MANIFESTATION, 10, {}, 12345)
	_ok(int(r.get("total_count", -1)) == 1, "solo boss (total 1)")
	_ok(bool(r.get("has_named_npc_slot", false)), "named npc slot")
	_ok(float(r.get("individual_variance_chance", 1.0)) == 0.0, "no variance for a unique boss")
	var groups: Array = r.get("groups", [])
	_ok(groups.size() == 1, "one group")
	if groups.size() == 1:
		var g: Dictionary = groups[0]
		_ok(int(g.get("count", 0)) == 1 and String(g.get("role", "")) == _RCS.ROLE_LEADER, "boss is the leader")
		var oni: SpiritCreatureData = _OB.get_oni(String(g.get("unit_type", "")))
		_ok(oni != null and oni.tier == SpiritCreatureData.Tier.BOSS, "unit_type resolves to a BOSS oni")
	# Deterministic for a fixed seed.
	var r2: Dictionary = _RCS.compose_roster(_RCS.SEED_ONI_MANIFESTATION, 10, {}, 12345)
	_ok(r2["groups"][0]["unit_type"] == groups[0]["unit_type"], "deterministic for fixed seed")


func _test_seed_gate() -> void:
	print("[3] seed gate flipped")
	# Build a province with a detected Maho Cult at Strength 10 → oni seed roster_ready.
	var prov := ProvinceData.new()
	prov.province_id = 1
	prov.clan = "Crab"
	prov.terrain_type = Enums.TerrainType.PLAINS
	prov.province_taint_level = 0.0
	var cult := InsurgencyData.new()
	cult.insurgency_id = 5
	cult.insurgency_type = Enums.InsurgencyType.MAHO_CULT
	cult.strength = 10
	cult.detected = true
	cult.province_id = 1
	var seeds: Array = _QSS.select_province_seeds(prov, [cult], {}, [], 999)
	var oni_seed: Dictionary = {}
	for s: Dictionary in seeds:
		if int(s.get("seed_type", -1)) == _QSS.SEED_ONI_MANIFESTATION:
			oni_seed = s
	_ok(not oni_seed.is_empty(), "oni seed generated for cult Strength 10")
	_ok(bool(oni_seed.get("roster_ready", false)), "roster_ready = true")


func _test_pipeline() -> void:
	print("[4] end-to-end seed→roster→map→population")
	var prov := ProvinceData.new()
	prov.province_id = 2
	prov.clan = "Crab"
	prov.terrain_type = Enums.TerrainType.PLAINS
	var oni_seed: Dictionary = {
		"seed_type": _QSS.SEED_ONI_MANIFESTATION,
		"seed_label": "ONI_MANIFESTATION",
		"strength": 10,
		"options": {},
		"source_insurgency_id": 5,
		"roster_ready": true,
	}
	var pkg: Dictionary = _MB.assemble(prov, [], oni_seed, "oni_test_seed")
	_ok(not pkg.is_empty(), "mission package assembled (not gated out)")
	_ok(pkg.has("map") and pkg["map"] != null, "map generated")
	var placements: Variant = pkg.get("placements", [])
	_ok(placements is Array and (placements as Array).size() >= 1, "boss placed")
	# The placed unit is a BOSS oni at the leader role.
	if placements is Array and (placements as Array).size() >= 1:
		var found_boss: bool = false
		for p: Dictionary in placements:
			var oni: SpiritCreatureData = _OB.get_oni(String(p.get("unit_type", "")))
			if oni != null and oni.tier == SpiritCreatureData.Tier.BOSS:
				found_boss = true
		_ok(found_boss, "placement carries a BOSS oni id (spawnable via SpiritCombatant)")
