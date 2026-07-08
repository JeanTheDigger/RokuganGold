extends SceneTree
## Runtime driver for wiring the mechanically-computable situational insurgency-spawn modifiers
## (s11.11). InsurgencySystem.get_spawn_chance reads ~11 per-province world_state keys whose modifier
## MAGNITUDES are GDD-locked in the consumer -- but NOBODY ever populated those keys, so the entire
## situational escalation layer was dead (every spawn used only the flat stability-tier base).
## DayOrchestrator._process_insurgencies now produces the 5 cleanly-computable facts (no invented
## values): starvation_stage, under_garrisoned (garrison < pop*0.05, the LOCKED s11.11 threshold),
## empire_at_war, clan_at_war, lord_bushido_virtue.
##
## Section [1] proves the CONSUMER applies each wired key's GDD-locked delta (deterministic).
## Section [2] proves the PRODUCER populates the keys end-to-end through _process_insurgencies, using
## same-seed paired runs so the spawn outcome is a deterministic superset (higher chance spawns
## whenever the lower chance does, given an identical dice stream).
## Run: godot --headless -s tests/verify_insurgency_spawn_modifiers.gd

const _IS := preload("res://simulation/insurgency_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _prov(pid: int, clan: String, coastal: bool, stability: float) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	p.family = ""
	p.is_coastal = coastal
	p.stability = stability
	return p


func _settle(sid: int, pid: int, pop: int, gar: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = pid
	s.population_pu = pop
	s.garrison_pu = gar
	return s


func _war(clan_a: String, clan_b: String) -> WarData:
	var w := WarData.new()
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.is_active = true
	return w


func _lord(cid: int, clan: String, virtue: Enums.BushidoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = clan
	c.family = ""
	c.status = 5.0
	c.bushido_virtue = virtue
	return c


func _init() -> void:
	print("--- insurgency situational spawn modifiers wired (s11.11) ---")
	_test_consumer_values()
	_test_producer_pirate_war()
	_test_producer_starvation()
	_test_producer_jin_lord()
	_test_producer_under_garrisoned()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


# [1] Consumer: each wired key applies its GDD-locked delta.
func _test_consumer_values() -> void:
	print("[1] get_spawn_chance applies each wired key's LOCKED delta")
	var pv := _prov(1, "Lion", false, 30.0)  # VOLATILE-range province
	var V := Enums.StabilityTier.VOLATILE
	# PEASANT_REVOLT base at VOLATILE = 0.25
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv, {}), 0.25),
		"PEASANT VOLATILE base == 0.25")
	# +0.10 at HUNGER
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv,
		{"starvation_stage": ResourceTick.StarvationStage.HUNGER}), 0.35), "PEASANT +HUNGER == 0.35")
	# SHORTAGE is below the HUNGER threshold -> no boost
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv,
		{"starvation_stage": ResourceTick.StarvationStage.SHORTAGE}), 0.25), "PEASANT +SHORTAGE == 0.25 (below threshold)")
	# under_garrisoned +0.10
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv,
		{"under_garrisoned": true}), 0.35), "PEASANT +under_garrisoned == 0.35")
	# JIN lord -0.10
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv,
		{"lord_bushido_virtue": Enums.BushidoVirtue.JIN}), 0.15), "PEASANT +JIN lord == 0.15")
	# all three stack: 0.25 + 0.10 + 0.10 - 0.10 = 0.35
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PEASANT_REVOLT, V, pv,
		{"starvation_stage": ResourceTick.StarvationStage.HUNGER, "under_garrisoned": true,
		"lord_bushido_virtue": Enums.BushidoVirtue.JIN}), 0.35), "PEASANT hunger+ungar+JIN == 0.35")

	# PIRATE_FLEET on a STABLE coastal province (stability 80 -> no <50 bonus)
	var pc := _prov(2, "Crab", true, 80.0)
	var S := Enums.StabilityTier.STABLE
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PIRATE_FLEET, S, pc, {}), 0.0),
		"PIRATE stable-coastal no-war == 0.0")
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PIRATE_FLEET, S, pc,
		{"empire_at_war": true}), 0.05), "PIRATE +empire_at_war == 0.05")
	_ok(is_equal_approx(_IS.get_spawn_chance(Enums.InsurgencyType.PIRATE_FLEET, S, pc,
		{"empire_at_war": true, "clan_at_war": true}), 0.15), "PIRATE +empire+clan_at_war == 0.15")


# [2a] Producer: PIRATE_FLEET spawns ONLY when a war involving the province clan is active.
# no-war chance is deterministically 0.0 (never spawns); war chance 0.15 (spawns for some seeds).
func _test_producer_pirate_war() -> void:
	print("[2a] producer sets empire_at_war/clan_at_war -> PIRATE spawns only with a war")
	var nowar_pirate: int = 0
	var war_pirate: int = 0
	for seed: int in range(0, 200):
		nowar_pirate += _run_count(seed, "Crab", true, 80.0, [], {}, [], Enums.InsurgencyType.PIRATE_FLEET)
		war_pirate += _run_count(seed, "Crab", true, 80.0, [_war("Crab", "Lion")], {}, [],
			Enums.InsurgencyType.PIRATE_FLEET)
	_ok(nowar_pirate == 0, "no-war: PIRATE never spawns (got %d)" % nowar_pirate)
	_ok(war_pirate > 0, "war: PIRATE spawns for some seeds (got %d)" % war_pirate)


# [2b] Producer: reads province.starvation_stage. Same seed -> HUNGER PEASANT is a superset of CLEAR.
func _test_producer_starvation() -> void:
	print("[2b] producer reads province.starvation_stage -> PEASANT spawns >= without it")
	var clear_count: int = 0
	var hunger_count: int = 0
	for seed: int in range(0, 200):
		clear_count += _run_count_starv(seed, ResourceTick.StarvationStage.CLEAR)
		hunger_count += _run_count_starv(seed, ResourceTick.StarvationStage.HUNGER)
	_ok(hunger_count >= clear_count, "HUNGER superset of CLEAR (hunger %d >= clear %d)" % [hunger_count, clear_count])
	_ok(hunger_count > clear_count, "HUNGER strictly more PEASANT spawns (hunger %d > clear %d)" % [hunger_count, clear_count])


# [2c] Producer: reads the province lord's virtue. Same seed -> non-JIN PEASANT is a superset of JIN.
func _test_producer_jin_lord() -> void:
	print("[2c] producer reads province lord virtue -> JIN suppresses PEASANT")
	var jin_count: int = 0
	var gi_count: int = 0
	var jin_lord: Array = [_lord(900, "Crab", Enums.BushidoVirtue.JIN)]
	var gi_lord: Array = [_lord(901, "Crab", Enums.BushidoVirtue.GI)]
	var jin_by_id: Dictionary = {900: jin_lord[0]}
	var gi_by_id: Dictionary = {901: gi_lord[0]}
	for seed: int in range(0, 200):
		jin_count += _run_count(seed, "Crab", false, 30.0, [], jin_by_id, [], Enums.InsurgencyType.PEASANT_REVOLT)
		gi_count += _run_count(seed, "Crab", false, 30.0, [], gi_by_id, [], Enums.InsurgencyType.PEASANT_REVOLT)
	_ok(gi_count >= jin_count, "non-JIN superset of JIN (gi %d >= jin %d)" % [gi_count, jin_count])
	_ok(gi_count > jin_count, "JIN strictly fewer PEASANT spawns (gi %d > jin %d)" % [gi_count, jin_count])


# [2d] Producer: aggregates settlement PU -> under_garrisoned. Same seed -> under-garrisoned superset.
func _test_producer_under_garrisoned() -> void:
	print("[2d] producer aggregates settlement PU -> under_garrisoned boosts PEASANT")
	var ok_gar: int = 0
	var under_gar: int = 0
	# well-garrisoned: pop 100, garrison 10 (10 >= 100*0.05=5) -> not under
	var ok_settle: Array = [_settle(1, 700, 100, 10)]
	# under-garrisoned: pop 100, garrison 2 (2 < 5) -> under
	var under_settle: Array = [_settle(1, 700, 100, 2)]
	for seed: int in range(0, 200):
		ok_gar += _run_count(seed, "Crab", false, 30.0, [], {}, ok_settle, Enums.InsurgencyType.PEASANT_REVOLT, 700)
		under_gar += _run_count(seed, "Crab", false, 30.0, [], {}, under_settle, Enums.InsurgencyType.PEASANT_REVOLT, 700)
	_ok(under_gar >= ok_gar, "under-garrisoned superset of ok (under %d >= ok %d)" % [under_gar, ok_gar])
	_ok(under_gar > ok_gar, "under-garrisoned strictly more PEASANT spawns (under %d > ok %d)" % [under_gar, ok_gar])


# Runs _process_insurgencies for a single fresh province and returns how many insurgencies of `want`
# type spawned. Isolates the producer path end-to-end.
func _run_count(seed: int, clan: String, coastal: bool, stability: float, wars: Array,
		chars_by_id: Dictionary, settles: Array, want: Enums.InsurgencyType, pid: int = 500) -> int:
	var prov := _prov(pid, clan, coastal, stability)
	prov.starvation_stage = ResourceTick.StarvationStage.CLEAR
	var provinces: Dictionary = {pid: prov}
	var insurgencies: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(seed)
	_DO._process_insurgencies(insurgencies, provinces, dice, 0, [1], {}, {}, {}, [1],
		wars, chars_by_id, settles)
	var n: int = 0
	for ins: InsurgencyData in insurgencies:
		if ins.insurgency_type == want:
			n += 1
	return n


func _run_count_starv(seed: int, stage: int) -> int:
	var pid: int = 500
	var prov := _prov(pid, "Crab", false, 30.0)  # VOLATILE, non-coastal
	prov.starvation_stage = stage
	var provinces: Dictionary = {pid: prov}
	var insurgencies: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(seed)
	_DO._process_insurgencies(insurgencies, provinces, dice, 0, [1], {}, {}, {}, [1], [], {}, [])
	var n: int = 0
	for ins: InsurgencyData in insurgencies:
		if ins.insurgency_type == Enums.InsurgencyType.PEASANT_REVOLT:
			n += 1
	return n
