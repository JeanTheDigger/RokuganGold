extends SceneTree
## Runtime driver for the province-only activation of the worship tier model
## (Model A, owner-approved 2026-07-06). Verifies: (1) get_worship_tier's ratio
## bands (NONE >=100% / RESTLESS 70-99% / DISPLEASED 40-69% / WRATHFUL <40%),
## including boundaries and scaling to any threshold; and (2) that
## compute_all_province_maluses applies ONLY the province tier -- a province that
## meets its own 10-WP threshold is NOT blanketed by a WRATHFUL family/clan/empire
## aggregate (the deferred-aggregate safety guarantee).
## Run: godot --headless -s tests/verify_worship_tiers.gd

const _W := preload("res://simulation/worship_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _tier(wp: float, threshold: float = 10.0) -> int:
	return int(_W.get_worship_tier(wp, threshold))


func _prov(pid: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.family = "Isawa"
	p.clan = "Phoenix"
	return p


func _init() -> void:
	print("--- Worship Tier Activation (Model A, province-only) ---")
	_test_bands()
	_test_boundaries_and_scaling()
	_test_province_only_application()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_bands() -> void:
	print("[1] ratio bands of the LOCKED 10-WP threshold")
	_ok(_tier(12.0) == int(Enums.WorshipTier.NONE), "12 WP (over) -> NONE")
	_ok(_tier(10.0) == int(Enums.WorshipTier.NONE), "10 WP (met exactly) -> NONE")
	_ok(_tier(9.0) == int(Enums.WorshipTier.RESTLESS), "9 WP (90%) -> RESTLESS")
	_ok(_tier(5.0) == int(Enums.WorshipTier.DISPLEASED), "5 WP (50%) -> DISPLEASED")
	_ok(_tier(2.0) == int(Enums.WorshipTier.WRATHFUL), "2 WP (20%) -> WRATHFUL")
	_ok(_tier(0.0) == int(Enums.WorshipTier.WRATHFUL), "0 WP -> WRATHFUL")


func _test_boundaries_and_scaling() -> void:
	print("[2] band boundaries + scaling to aggregate thresholds")
	# Exact edges: 70% -> RESTLESS, just under -> DISPLEASED; 40% -> DISPLEASED, under -> WRATHFUL.
	_ok(_tier(7.0) == int(Enums.WorshipTier.RESTLESS), "exactly 70% -> RESTLESS")
	_ok(_tier(6.99) == int(Enums.WorshipTier.DISPLEASED), "just under 70% -> DISPLEASED")
	_ok(_tier(4.0) == int(Enums.WorshipTier.DISPLEASED), "exactly 40% -> DISPLEASED")
	_ok(_tier(3.99) == int(Enums.WorshipTier.WRATHFUL), "just under 40% -> WRATHFUL")
	# Scales to any threshold (e.g. the provisional empire 800): 70% and 40% still map.
	_ok(_tier(560.0, 800.0) == int(Enums.WorshipTier.RESTLESS), "560/800 (70%) -> RESTLESS")
	_ok(_tier(320.0, 800.0) == int(Enums.WorshipTier.DISPLEASED), "320/800 (40%) -> DISPLEASED")
	# No obligation defined -> NONE (no divide-by-zero).
	_ok(_tier(0.0, 0.0) == int(Enums.WorshipTier.NONE), "threshold 0 -> NONE")


func _test_province_only_application() -> void:
	print("[3] compute_all_province_maluses applies ONLY the province tier")
	var pid: int = 100
	var provinces: Dictionary = {pid: _prov(pid)}
	var daikoku: int = int(Enums.GreatFortune.DAIKOKU)  # koku domain
	var all_wrathful: Dictionary = {}
	for f: int in range(7):
		all_wrathful[f] = Enums.WorshipTier.WRATHFUL

	# (A) Province meets its own threshold (all NONE), but family/clan/empire are all
	# WRATHFUL. The aggregate blanket is OFF -> the province takes ZERO malus.
	var ws_a: Dictionary = {
		"province_tiers": {pid: {}},  # empty -> every fortune reads NONE
		"family_tiers": {"Isawa": all_wrathful.duplicate()},
		"clan_tiers": {"Phoenix": all_wrathful.duplicate()},
		"empire_tiers": all_wrathful.duplicate(),
	}
	var res_a: Dictionary = _W.compute_all_province_maluses(ws_a, provinces)
	var malus_a: Dictionary = res_a.get(pid, {})
	_ok(malus_a.is_empty(),
		"province meeting its own WP is NOT blanketed by a WRATHFUL aggregate (malus empty)")

	# (B) Province's own Daikoku is DISPLEASED (koku -0.30); empire is WRATHFUL (koku
	# -0.50). Province tier drives it -> -0.30, NOT the empire's -0.50.
	var ws_b: Dictionary = {
		"province_tiers": {pid: {daikoku: Enums.WorshipTier.DISPLEASED}},
		"family_tiers": {"Isawa": all_wrathful.duplicate()},
		"clan_tiers": {"Phoenix": all_wrathful.duplicate()},
		"empire_tiers": all_wrathful.duplicate(),
	}
	var res_b: Dictionary = _W.compute_all_province_maluses(ws_b, provinces)
	var koku_b: float = float(res_b.get(pid, {}).get("koku_modifier", 0.0))
	_ok(abs(koku_b - (-0.30)) < 0.001,
		"province DISPLEASED drives koku -0.30 (not the empire WRATHFUL -0.50); got %.2f" % koku_b)

	# (C) Sanity: the province tier DOES fire when the province itself fails.
	var ws_c: Dictionary = {
		"province_tiers": {pid: {daikoku: Enums.WorshipTier.WRATHFUL}},
		"family_tiers": {}, "clan_tiers": {}, "empire_tiers": {},
	}
	var res_c: Dictionary = _W.compute_all_province_maluses(ws_c, provinces)
	var koku_c: float = float(res_c.get(pid, {}).get("koku_modifier", 0.0))
	_ok(abs(koku_c - (-0.50)) < 0.001,
		"province WRATHFUL fires koku -0.50; got %.2f" % koku_c)
