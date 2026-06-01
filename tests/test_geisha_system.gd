extends GutTest
## Tests for GeishaSystem (s57.45, locked s57.45a).

# ============================================================================
# HELPERS
# ============================================================================

func _make_character(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_okiya(id: int, tier: int = 1, scorpion: bool = true) -> OkiyaData:
	var o := OkiyaData.new()
	o.okiya_id = id
	o.settlement_id = "1000"
	o.tier = tier
	o.is_scorpion_controlled = scorpion
	o.okaasan_id = 200
	o.handler_id = 300
	o.kolat_agent_id = -1
	o.is_active = true
	return o


# ============================================================================
# KOKU COST TESTS
# ============================================================================

func test_koku_cost_tier_1() -> void:
	assert_almost_eq(GeishaSystem.koku_cost_for_tier(1), 0.1, 0.001)


func test_koku_cost_tier_2() -> void:
	assert_almost_eq(GeishaSystem.koku_cost_for_tier(2), 0.3, 0.001)


func test_koku_cost_tier_3() -> void:
	assert_almost_eq(GeishaSystem.koku_cost_for_tier(3), 1.0, 0.001)


func test_koku_cost_tier_0_no_okiya() -> void:
	assert_almost_eq(GeishaSystem.koku_cost_for_tier(0), 0.0, 0.001)


# ============================================================================
# GEISHA ROUTING CHANCE TESTS
# ============================================================================

func test_geisha_base_chance_no_character() -> void:
	# No geisha char, TIER_4 topic (0 steps penalty) → BASE 0.50.
	var p: float = GeishaSystem._geisha_routing_chance(null, _make_character(1), _make_okiya(1), 3)
	assert_almost_eq(p, 0.50, 0.001)


func test_geisha_tier1_topic_penalty_three_steps() -> void:
	# TIER_1 (enum 0) = 3 steps × -0.10 = -0.30.
	var p: float = GeishaSystem._geisha_routing_chance(null, _make_character(1), _make_okiya(1), 0)
	assert_almost_eq(p, 0.20, 0.001)


func test_geisha_chugi_bonus() -> void:
	var geisha := _make_character(99)
	geisha.bushido_virtue = Enums.BushidoVirtue.CHUGI
	# TIER_4 topic, no disp modifiers: BASE + CHUGI_BONUS = 0.65.
	var p: float = GeishaSystem._geisha_routing_chance(geisha, _make_character(1), _make_okiya(1), 3)
	assert_almost_eq(p, 0.65, 0.001)


func test_geisha_jin_penalty() -> void:
	var geisha := _make_character(99)
	geisha.bushido_virtue = Enums.BushidoVirtue.JIN
	# TIER_4: BASE + JIN_PENALTY = 0.35.
	var p: float = GeishaSystem._geisha_routing_chance(geisha, _make_character(1), _make_okiya(1), 3)
	assert_almost_eq(p, 0.35, 0.001)


func test_geisha_ishi_penalty() -> void:
	var geisha := _make_character(99)
	geisha.shourido_virtue = Enums.ShouridoVirtue.ISHI
	var p: float = GeishaSystem._geisha_routing_chance(geisha, _make_character(1), _make_okiya(1), 3)
	assert_almost_eq(p, 0.35, 0.001)


func test_geisha_seigyo_bonus() -> void:
	var geisha := _make_character(99)
	geisha.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var p: float = GeishaSystem._geisha_routing_chance(geisha, _make_character(1), _make_okiya(1), 3)
	assert_almost_eq(p, 0.60, 0.001)


func test_geisha_patron_disp_reduces_chance() -> void:
	var geisha := _make_character(99)
	var patron := _make_character(1)
	geisha.disposition_values[patron.character_id] = 60
	# TIER_4: BASE - 60 × 0.003 = 0.50 - 0.18 = 0.32.
	var p: float = GeishaSystem._geisha_routing_chance(geisha, patron, _make_okiya(1), 3)
	assert_almost_eq(p, 0.32, 0.001)


func test_geisha_okaasan_disp_increases_chance() -> void:
	var geisha := _make_character(99)
	var okiya := _make_okiya(1)
	okiya.okaasan_id = 200
	geisha.disposition_values[200] = 50
	# TIER_4: BASE + 50 × 0.003 = 0.50 + 0.15 = 0.65.
	var p: float = GeishaSystem._geisha_routing_chance(geisha, _make_character(1), okiya, 3)
	assert_almost_eq(p, 0.65, 0.001)


func test_geisha_clamped_to_min() -> void:
	# JIN + TIER_1 penalty + patron high disp → below 0.05.
	var geisha := _make_character(99)
	var patron := _make_character(1)
	geisha.bushido_virtue = Enums.BushidoVirtue.JIN
	geisha.disposition_values[patron.character_id] = 100
	var p: float = GeishaSystem._geisha_routing_chance(geisha, patron, _make_okiya(1), 0)
	assert_almost_eq(p, 0.05, 0.001)


# ============================================================================
# OKAASAN ROUTING CHANCE TESTS
# ============================================================================

func test_okaasan_base_chance_no_character() -> void:
	# TIER_4 → 0 bonus steps, no character modifiers → BASE 0.65.
	var p: float = GeishaSystem._okaasan_routing_chance(null, _make_okiya(1), 3)
	assert_almost_eq(p, 0.65, 0.001)


func test_okaasan_tier1_topic_bonus_three_steps() -> void:
	# TIER_1 (0 enum) = 3 steps × +0.10 = +0.30 → 0.95 (capped).
	var p: float = GeishaSystem._okaasan_routing_chance(null, _make_okiya(1), 0)
	assert_almost_eq(p, 0.95, 0.001)


func test_okaasan_ishi_penalty() -> void:
	var okaasan := _make_character(200)
	okaasan.shourido_virtue = Enums.ShouridoVirtue.ISHI
	# TIER_4: BASE + ISHI_PENALTY = 0.65 - 0.20 = 0.45.
	var p: float = GeishaSystem._okaasan_routing_chance(okaasan, _make_okiya(1), 3)
	assert_almost_eq(p, 0.45, 0.001)


func test_okaasan_seigyo_bonus() -> void:
	var okaasan := _make_character(200)
	okaasan.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var p: float = GeishaSystem._okaasan_routing_chance(okaasan, _make_okiya(1), 3)
	assert_almost_eq(p, 0.80, 0.001)


func test_okaasan_chugi_bonus() -> void:
	var okaasan := _make_character(200)
	okaasan.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var p: float = GeishaSystem._okaasan_routing_chance(okaasan, _make_okiya(1), 3)
	assert_almost_eq(p, 0.75, 0.001)


# ============================================================================
# SEVERITY STEPS TEST
# ============================================================================

func test_severity_steps_tier4() -> void:
	assert_eq(GeishaSystem._severity_steps(3), 0)  # TIER_4 = enum 3


func test_severity_steps_tier3() -> void:
	assert_eq(GeishaSystem._severity_steps(2), 1)


func test_severity_steps_tier2() -> void:
	assert_eq(GeishaSystem._severity_steps(1), 2)


func test_severity_steps_tier1() -> void:
	assert_eq(GeishaSystem._severity_steps(0), 3)


# ============================================================================
# PROCESS GEISHA VISIT — FULL PIPELINE
# ============================================================================

func test_visit_records_visit_count() -> void:
	var patron := _make_character(1)
	var okiya := _make_okiya(10)
	okiya.geisha_ids.clear()
	okiya.okaasan_id = -1
	okiya.handler_id = -1
	var topics_by_id: Dictionary = {}
	var chars: Dictionary = {1: patron}
	# Use a fixed DiceEngine seed so randf() is deterministic.
	var dice := DiceEngine.new()
	GeishaSystem.process_geisha_visit(patron, okiya, 42, topics_by_id, chars, dice)
	assert_eq(patron.okiya_visit_counts.get(10, 0), 1)


func test_visit_disposition_gain_applied_to_assigned_geisha() -> void:
	var patron := _make_character(1)
	var geisha := _make_character(99)
	var okiya := _make_okiya(10)
	okiya.geisha_ids = [99]
	okiya.okaasan_id = -1
	okiya.handler_id = -1
	var chars: Dictionary = {1: patron, 99: geisha}
	var dice := DiceEngine.new()
	GeishaSystem.process_geisha_visit(patron, okiya, 42, {}, chars, dice)
	var disp: int = patron.disposition_values.get(99, 0)
	assert_eq(disp, GeishaSystem.PATRON_VISIT_DISPOSITION_GAIN)


func test_inactive_okiya_skipped() -> void:
	var patron := _make_character(1)
	var okiya := _make_okiya(10)
	okiya.is_active = false
	var result: Dictionary = GeishaSystem.process_geisha_visit(patron, okiya, 42, {}, {1: patron}, DiceEngine.new())
	assert_false(result["geisha_routed"])
	assert_eq(patron.okiya_visit_counts.get(10, 0), 0)


func test_geisha_assign_deterministic() -> void:
	# Same patron always assigned same geisha.
	var patron := _make_character(7)
	var okiya := _make_okiya(10)
	okiya.geisha_ids = [101, 102, 103]
	var g1: int = GeishaSystem._get_or_assign_geisha(patron, okiya)
	patron.assigned_geisha_ids.erase(10)
	var g2: int = GeishaSystem._get_or_assign_geisha(patron, okiya)
	assert_eq(g1, g2)


func test_geisha_assign_persists_in_dictionary() -> void:
	var patron := _make_character(1)
	var okiya := _make_okiya(5)
	okiya.geisha_ids = [200]
	GeishaSystem._get_or_assign_geisha(patron, okiya)
	assert_true(patron.assigned_geisha_ids.has(5))


func test_independent_okiya_no_handler_routing() -> void:
	# handler_id = -1 → handler never receives even if geisha and okaasan route.
	var patron := _make_character(1)
	var okaasan := _make_character(200)
	var okiya := _make_okiya(10)
	okiya.geisha_ids.clear()
	okiya.okaasan_id = 200
	okiya.handler_id = -1
	var chars: Dictionary = {1: patron, 200: okaasan}
	var dice := DiceEngine.new()
	var result: Dictionary = GeishaSystem.process_geisha_visit(patron, okiya, 99, {}, chars, dice)
	assert_false(result["handler_received"])


# ============================================================================
# WORLD GENERATION TESTS
# ============================================================================

func _make_settlement(id: int, s_type: Enums.SettlementType) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = s_type
	return s


func test_city_gets_okiya_tier2() -> void:
	var s := _make_settlement(1000, Enums.SettlementType.CITY)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var clan_map: Dictionary = {"1000": "Lion"}
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], clan_map, dice, next_id)
	assert_eq(okiyas.size(), 1)
	assert_eq((okiyas[0] as OkiyaData).tier, 2)
	assert_eq(s.okiya_tier, 2)
	assert_true(s.has_infrastructure("okiya"))


func test_crane_city_gets_tier3() -> void:
	var s := _make_settlement(1000, Enums.SettlementType.CITY)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1000": "Crane"}, dice, next_id)
	assert_eq((okiyas[0] as OkiyaData).tier, 3)


func test_scorpion_city_gets_tier3() -> void:
	var s := _make_settlement(1000, Enums.SettlementType.CITY)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1000": "Scorpion"}, dice, next_id)
	assert_eq((okiyas[0] as OkiyaData).tier, 3)


func test_family_castle_gets_tier1_for_crab() -> void:
	var s := _make_settlement(1001, Enums.SettlementType.FAMILY_CASTLE)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1001": "Crab"}, dice, next_id)
	assert_eq(okiyas.size(), 1)
	assert_eq((okiyas[0] as OkiyaData).tier, 1)


func test_family_castle_crane_gets_tier2() -> void:
	var s := _make_settlement(1001, Enums.SettlementType.FAMILY_CASTLE)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1001": "Crane"}, dice, next_id)
	assert_eq((okiyas[0] as OkiyaData).tier, 2)


func test_village_gets_no_okiya() -> void:
	var s := _make_settlement(1002, Enums.SettlementType.VILLAGE)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1002": "Lion"}, dice, next_id)
	assert_eq(okiyas.size(), 0)
	assert_eq(s.okiya_tier, 0)


func test_okiya_id_increments() -> void:
	var s1 := _make_settlement(1000, Enums.SettlementType.CITY)
	var s2 := _make_settlement(1001, Enums.SettlementType.CITY)
	var dice := DiceEngine.new()
	var next_id: Array = [1]
	var okiyas: Array = GeishaSystem.generate_initial_okiya([s1, s2], {"1000": "Lion", "1001": "Lion"}, dice, next_id)
	assert_eq(okiyas.size(), 2)
	assert_eq((okiyas[0] as OkiyaData).okiya_id, 1)
	assert_eq((okiyas[1] as OkiyaData).okiya_id, 2)
	assert_eq(next_id[0], 3)


func test_scorpion_territory_mostly_controlled() -> void:
	# Run many trials — >80% should be Scorpion-controlled.
	var controlled: int = 0
	var trials: int = 100
	var dice := DiceEngine.new()
	for _i: int in range(trials):
		var s := _make_settlement(1000, Enums.SettlementType.CITY)
		var next_id: Array = [1]
		var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1000": "Scorpion"}, dice, next_id)
		if (okiyas[0] as OkiyaData).is_scorpion_controlled:
			controlled += 1
	assert_true(controlled >= 75, "Expected ≥75%% Scorpion control in 100 trials, got %d%%" % controlled)


func test_crab_territory_mostly_independent() -> void:
	var controlled: int = 0
	var trials: int = 100
	var dice := DiceEngine.new()
	for _i: int in range(trials):
		var s := _make_settlement(1000, Enums.SettlementType.CITY)
		var next_id: Array = [1]
		var okiyas: Array = GeishaSystem.generate_initial_okiya([s], {"1000": "Crab"}, dice, next_id)
		if (okiyas[0] as OkiyaData).is_scorpion_controlled:
			controlled += 1
	assert_true(controlled <= 40, "Expected ≤40%% Scorpion control in Crab territory, got %d%%" % controlled)


func test_kolat_infiltration_rate_roughly_15pct() -> void:
	var infiltrated: int = 0
	var trials: int = 200
	var dice := DiceEngine.new()
	for _i: int in range(trials):
		var agent_id: int = GeishaSystem._roll_kolat_infiltration(dice)
		if agent_id == -2:
			infiltrated += 1
	# Expect ~15% ± generous margin.
	assert_true(infiltrated >= 10, "Expected ≥10 infiltrations in 200 trials, got %d" % infiltrated)
	assert_true(infiltrated <= 50, "Expected ≤50 infiltrations in 200 trials, got %d" % infiltrated)
