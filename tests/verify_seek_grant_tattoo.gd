extends SceneTree
## Runtime driver for the s57.25.7 SEEK_TATTOO / GRANT_TATTOO subsystem wire. Both NeedTypes were
## fully SCORED in objective_alignment.json but NEVER ASSIGNED to any character -- so no Togashi monk
## ever sought an ability tattoo and no elder ever prioritised granting one (the whole s57.25.7 path
## was dead). Fix: a seasons-at-rank urgency tracker (stamped at rank-up), _assign_seek_tattoo /
## _assign_grant_tattoo standing passes (self-correcting), the draw_ability_for_grant helper, and the
## APPLY_TATTOO ability-grant metadata (target/is_ability/ability, consumed by the already-complete
## executor + creation writeback). This driver exercises the pure helpers + both standing passes.
## Run: godot --headless -s tests/verify_seek_grant_tattoo.gd

const _TAT := preload("res://simulation/tattoo_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _TATD := preload("res://shared/tattoo_data.gd")
const _PROV := preload("res://shared/province_data.gd")
const _DICE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, school: String, rank: int, loc: String = "") -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school = school
	c.school_rank = rank
	c.insight_rank = rank
	c.physical_location = loc
	return c


func _ability_tat(recipient: int, ability: int, body: int) -> TattooData:
	var t: TattooData = _TATD.new()
	t.recipient_id = recipient
	t.is_ability_tattoo = true
	t.ability_granted = ability
	t.body_location = body
	return t


func _init() -> void:
	print("--- s57.25.7 SEEK_TATTOO / GRANT_TATTOO subsystem ---")
	_test_helpers()
	_test_seek_pass()
	_test_grant_pass()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_helpers() -> void:
	print("[1] pure helpers: seasons_at_rank_unfilled / is_seeking_tattoo / draw_ability / territory")
	var monk: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1)
	# Untracked (-1) -> urgency 0.
	_ok(_TAT.seasons_at_rank_unfilled(monk, 500) == 0, "untracked rank season -> urgency 0")
	monk.tattoo_rank_reached_season = 0  # absolute season 0
	# ic_day 360 -> absolute season 4 (year1 doy0). 4 - 0 = 4 seasons.
	_ok(_TAT.seasons_at_rank_unfilled(monk, 360) == 4, "4 seasons elapsed -> 4")
	# is_seeking: Togashi rank-1 has allotment 2, no ability tattoos -> seeking.
	_ok(_TAT.is_seeking_tattoo([], monk), "Togashi monk with 0/2 slots is seeking")
	# Non-Togashi never seeks.
	var akodo: L5RCharacterData = _mk(2, "Akodo Bushi", 3)
	_ok(not _TAT.is_seeking_tattoo([], akodo), "non-Togashi never seeks")
	# BLOCKED flag suppresses seeking.
	monk.seek_tattoo_blocked = true
	_ok(not _TAT.is_seeking_tattoo([], monk), "BLOCKED monk does not seek")
	monk.seek_tattoo_blocked = false
	# Filled allotment (2 ability tattoos at rank 1) -> not seeking.
	var filled: Array = [_ability_tat(1, Enums.TattooAbility.MANTIS, 0), _ability_tat(1, Enums.TattooAbility.OCEAN, 1)]
	_ok(not _TAT.is_seeking_tattoo(filled, monk), "Togashi monk with 2/2 slots filled -> not seeking")
	# draw_ability_for_grant excludes owned + returns NONE when all owned.
	var dice: DiceEngine = _DICE.new(1234)
	var owned_two: Array = [_ability_tat(1, Enums.TattooAbility.MANTIS, 0), _ability_tat(1, Enums.TattooAbility.OCEAN, 1)]
	var drawn: int = _TAT.draw_ability_for_grant(owned_two, 1, dice)
	_ok(drawn != Enums.TattooAbility.NONE and drawn != Enums.TattooAbility.MANTIS and drawn != Enums.TattooAbility.OCEAN,
		"draw excludes already-owned abilities")
	# Territory: Dragon-clan province -> true; other clan -> false.
	var dragon_prov: ProvinceData = _PROV.new(); dragon_prov.province_id = 10; dragon_prov.clan = "Dragon"
	var lion_prov: ProvinceData = _PROV.new(); lion_prov.province_id = 11; lion_prov.clan = "Lion"
	var provs: Dictionary = {10: dragon_prov, 11: lion_prov}
	_ok(_DO._in_togashi_territory(1, {1: 10}, provs), "province Dragon -> Togashi territory")
	_ok(not _DO._in_togashi_territory(1, {1: 11}, provs), "province Lion -> not Togashi territory")
	_ok(not _DO._in_togashi_territory(1, {}, provs), "no province mapping -> not Togashi territory")


func _test_seek_pass() -> void:
	print("[2] _assign_seek_tattoo_standing_objectives: assign / revert / BLOCKED / respect non-monk standing")
	var seeker: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1)
	var filled_monk: L5RCharacterData = _mk(2, "Togashi Tattooed Order", 1)
	var magistrate_monk: L5RCharacterData = _mk(3, "Togashi Tattooed Order", 1)
	var chars: Array = [seeker, filled_monk, magistrate_monk]
	var tattoos: Array = [
		_ability_tat(2, Enums.TattooAbility.MANTIS, 0), _ability_tat(2, Enums.TattooAbility.OCEAN, 1),  # 2 filled
	]
	# magistrate_monk holds a non-monk standing (must be respected).
	var objectives_map: Dictionary = {
		3: {"standing": {"need_type": "UPHOLD_LAW", "priority": 2}},
	}
	_DO._assign_seek_tattoo_standing_objectives(chars, objectives_map, tattoos)
	_ok(objectives_map[1]["standing"]["need_type"] == "SEEK_TATTOO", "seeking monk assigned SEEK_TATTOO")
	_ok(not objectives_map.has(2) or objectives_map[2].get("standing", {}).get("need_type", "") != "SEEK_TATTOO",
		"filled monk NOT assigned SEEK_TATTOO")
	_ok(objectives_map[3]["standing"]["need_type"] == "UPHOLD_LAW", "magistrate monk's UPHOLD_LAW respected")
	# Revert: a monk who WAS seeking (SEEK_TATTOO standing) then filled -> revert to PERFORM_RITUAL.
	var reverter: L5RCharacterData = _mk(4, "Togashi Tattooed Order", 1)
	var om2: Dictionary = {4: {"standing": {"need_type": "SEEK_TATTOO", "priority": 3}}}
	var filled4: Array = [_ability_tat(4, Enums.TattooAbility.MANTIS, 0), _ability_tat(4, Enums.TattooAbility.OCEAN, 1)]
	_DO._assign_seek_tattoo_standing_objectives([reverter], om2, filled4)
	_ok(om2[4]["standing"]["need_type"] == "PERFORM_RITUAL", "filled ex-seeker reverts to PERFORM_RITUAL")
	# BLOCKED transition: all 9 locations occupied -> seek_tattoo_blocked set, not seeking.
	var blocked: L5RCharacterData = _mk(5, "Togashi Tattooed Order", 5)
	var all9: Array = []
	for i in 9:
		all9.append(_ability_tat(5, Enums.TattooAbility.MANTIS + i, _TAT.ALL_BODY_LOCATIONS[i]))
	var om3: Dictionary = {}
	_DO._assign_seek_tattoo_standing_objectives([blocked], om3, all9)
	_ok(blocked.seek_tattoo_blocked, "all-9-occupied monk transitions to BLOCKED")


func _test_grant_pass() -> void:
	print("[3] _assign_grant_tattoo_standing_objectives: pick highest-urgency co-located seeker, inject target, gate, revert")
	var dice: DiceEngine = _DICE.new(42)
	var dragon_prov: ProvinceData = _PROV.new(); dragon_prov.province_id = 10; dragon_prov.clan = "Dragon"
	var provs: Dictionary = {10: dragon_prov}
	# Elder: qualified (rank 3, Tattooing 3), in Dragon territory, co-located with two seekers.
	var elder: L5RCharacterData = _mk(100, "Togashi Tattooed Order", 3, "kyuden_togashi")
	elder.skills["Artisan: Tattooing"] = 3
	var seeker_low: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1, "kyuden_togashi")
	seeker_low.tattoo_rank_reached_season = 4       # urgency ~0 at ic_day 360 -> (season4 - 4 = 0)
	var seeker_high: L5RCharacterData = _mk(2, "Togashi Tattooed Order", 1, "kyuden_togashi")
	seeker_high.tattoo_rank_reached_season = 0       # urgency 4 at ic_day 360 -> most urgent
	var chars: Array = [elder, seeker_low, seeker_high]
	var cpm: Dictionary = {100: 10, 1: 10, 2: 10}
	var om: Dictionary = {}
	var ws: Dictionary = {}
	_DO._assign_grant_tattoo_standing_objectives(chars, om, ws, [], cpm, provs, dice, 360)
	_ok(om.get(100, {}).get("standing", {}).get("need_type", "") == "GRANT_TATTOO", "qualified elder assigned GRANT_TATTOO")
	var gt: Dictionary = ws.get(100, {}).get("grant_tattoo_target", {})
	_ok(gt.get("recipient_id", -1) == 2, "grant target = highest-urgency seeker (id 2)")
	_ok(gt.has("body_location") and gt.get("ability", Enums.TattooAbility.NONE) != Enums.TattooAbility.NONE,
		"grant target carries a body_location + a drawn ability")
	# Gate: an UNqualified elder (Tattooing 2) co-located with a seeker does not grant.
	var poor_elder: L5RCharacterData = _mk(101, "Togashi Tattooed Order", 3, "kyuden_togashi")
	poor_elder.skills["Artisan: Tattooing"] = 2
	var om2: Dictionary = {}
	var ws2: Dictionary = {}
	_DO._assign_grant_tattoo_standing_objectives([poor_elder, seeker_high], om2, ws2, [], {101: 10, 2: 10}, provs, dice, 360)
	_ok(om2.get(101, {}).get("standing", {}).get("need_type", "") != "GRANT_TATTOO", "under-skilled elder does not grant")
	# Gate: outside Togashi territory (Lion province) -> no grant.
	var lion: ProvinceData = _PROV.new(); lion.province_id = 11; lion.clan = "Lion"
	var om3: Dictionary = {}
	var ws3: Dictionary = {}
	_DO._assign_grant_tattoo_standing_objectives([elder, seeker_high], om3, ws3, [], {100: 11, 2: 11}, {11: lion}, dice, 360)
	_ok(ws3.get(100, {}).get("grant_tattoo_target", {}).is_empty(), "elder outside Dragon territory does not grant")
	# Revert: an elder holding a stale GRANT_TATTOO with no co-located seeker reverts to PERFORM_RITUAL.
	var lone_elder: L5RCharacterData = _mk(102, "Togashi Tattooed Order", 3, "empty_place")
	lone_elder.skills["Artisan: Tattooing"] = 4
	var om4: Dictionary = {102: {"standing": {"need_type": "GRANT_TATTOO", "priority": 3}}}
	_DO._assign_grant_tattoo_standing_objectives([lone_elder], om4, {}, [], {102: 10}, provs, dice, 360)
	_ok(om4[102]["standing"]["need_type"] == "PERFORM_RITUAL", "elder with no seeker reverts GRANT_TATTOO -> PERFORM_RITUAL")
