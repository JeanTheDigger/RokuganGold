extends SceneTree
## Runtime driver for the s4.3.21 four-level worship-malus activation (owner-approved 2026-07-08).
## compute_all_province_maluses previously applied ONLY the province tier (family/clan/empire tiers
## were computed + stored but never read — the aggregate layer was deferred). Now it takes the WORST
## of {province, family, clan, empire} per Fortune, so a failing clan-wide worship blankets the malus
## onto every member province (the GDD four-level design; thresholds 60/150/800 are GDD-STATED but
## flagged PROVISIONAL). No values invented.
## Run: godot --headless -s tests/verify_worship_four_level.gd

const _WS := preload("res://simulation/worship_system.gd")
const _PD := preload("res://shared/province_data.gd")
const _EN := preload("res://shared/enums.gd")

const BENTEN: int = 0  # GreatFortune.BENTEN

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _prov(pid: int, clan: String, family: String) -> ProvinceData:
	var p: ProvinceData = _PD.new()
	p.province_id = pid
	p.clan = clan
	p.family = family
	return p


## Build a minimal worship_state with the four tier maps. Each *_tier arg is the Benten(0) tier for
## that scope (all other fortunes NONE).
func _state(prov_tier: int, fam_tier: int, clan_tier: int, emp_tier: int) -> Dictionary:
	var none := {}
	for f in range(_WS.GREAT_FORTUNE_COUNT):
		none[f] = _EN.WorshipTier.NONE
	var p := none.duplicate()
	p[BENTEN] = prov_tier
	var fam := none.duplicate()
	fam[BENTEN] = fam_tier
	var cl := none.duplicate()
	cl[BENTEN] = clan_tier
	var emp := none.duplicate()
	emp[BENTEN] = emp_tier
	return {
		"province_tiers": {1: p},
		"family_tiers": {"Hida": fam},
		"clan_tiers": {"Crab": cl},
		"empire_tiers": emp,
	}


func _benten_malus(combined: Dictionary) -> float:
	return float(combined.get("pop_growth_modifier", 0.0))


func _init() -> void:
	print("--- s4.3.21 four-level worship maluses activated ---")
	_test_worst_tier_ordering()
	_test_family_blankets()
	_test_clan_blankets()
	_test_empire_blankets()
	_test_worst_wins_over_province()
	_test_all_none_no_malus()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_worst_tier_ordering() -> void:
	print("[1] get_worst_tier = max severity (NONE<RESTLESS<DISPLEASED<WRATHFUL)")
	var N := _EN.WorshipTier.NONE
	var R := _EN.WorshipTier.RESTLESS
	var D := _EN.WorshipTier.DISPLEASED
	var W := _EN.WorshipTier.WRATHFUL
	_ok(_WS.get_worst_tier(N, N, N, N) == N, "all NONE -> NONE")
	_ok(_WS.get_worst_tier(R, N, N, N) == R, "one RESTLESS -> RESTLESS")
	_ok(_WS.get_worst_tier(R, N, W, N) == W, "clan WRATHFUL dominates -> WRATHFUL")
	_ok(_WS.get_worst_tier(N, D, N, R) == D, "family DISPLEASED beats empire RESTLESS")


func _test_family_blankets() -> void:
	print("[2] a failing FAMILY blankets its provinces (province fine)")
	var provs := {1: _prov(1, "Crab", "Hida")}
	var st := _state(_EN.WorshipTier.NONE, _EN.WorshipTier.WRATHFUL, _EN.WorshipTier.NONE, _EN.WorshipTier.NONE)
	var res: Dictionary = _WS.compute_all_province_maluses(st, provs)
	# Benten WRATHFUL -> pop_growth_modifier -1.0, blanketed from the family tier.
	_ok(_approx(_benten_malus(res.get(1, {})), -1.0), "family WRATHFUL -> province gets -1.0 pop growth")
	_ok(res.get(1, {}).get("marriage_auto_fail", false) == true, "family WRATHFUL -> marriage_auto_fail flag")


func _test_clan_blankets() -> void:
	print("[3] a failing CLAN blankets its provinces")
	var provs := {1: _prov(1, "Crab", "Hida")}
	var st := _state(_EN.WorshipTier.NONE, _EN.WorshipTier.NONE, _EN.WorshipTier.DISPLEASED, _EN.WorshipTier.NONE)
	var res: Dictionary = _WS.compute_all_province_maluses(st, provs)
	_ok(_approx(_benten_malus(res.get(1, {})), -0.50), "clan DISPLEASED -> province gets -0.50 pop growth")


func _test_empire_blankets() -> void:
	print("[4] a failing EMPIRE blankets every province")
	var provs := {1: _prov(1, "Crab", "Hida")}
	var st := _state(_EN.WorshipTier.NONE, _EN.WorshipTier.NONE, _EN.WorshipTier.NONE, _EN.WorshipTier.RESTLESS)
	var res: Dictionary = _WS.compute_all_province_maluses(st, provs)
	_ok(_approx(_benten_malus(res.get(1, {})), -0.25), "empire RESTLESS -> province gets -0.25 pop growth")


func _test_worst_wins_over_province() -> void:
	print("[5] the WORST tier wins even when the province is only mildly displeased")
	var provs := {1: _prov(1, "Crab", "Hida")}
	# province RESTLESS (-0.25) but family WRATHFUL (-1.0) -> worst = WRATHFUL.
	var st := _state(_EN.WorshipTier.RESTLESS, _EN.WorshipTier.WRATHFUL, _EN.WorshipTier.NONE, _EN.WorshipTier.NONE)
	var res: Dictionary = _WS.compute_all_province_maluses(st, provs)
	_ok(_approx(_benten_malus(res.get(1, {})), -1.0), "province RESTLESS + family WRATHFUL -> -1.0 (worst wins)")


func _test_all_none_no_malus() -> void:
	print("[6] all tiers NONE -> no malus (empty combined)")
	var provs := {1: _prov(1, "Crab", "Hida")}
	var st := _state(_EN.WorshipTier.NONE, _EN.WorshipTier.NONE, _EN.WorshipTier.NONE, _EN.WorshipTier.NONE)
	var res: Dictionary = _WS.compute_all_province_maluses(st, provs)
	_ok(res.get(1, {}).is_empty(), "all NONE -> empty combined (no malus)")


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
