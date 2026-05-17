extends GutTest


# -- Helpers ---------------------------------------------------------------------

var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)


func _make_siege(
	rice: float = 2.0,
	civilian_pu: float = 10.0,
	garrison_pu: float = 0.5,
) -> Dictionary:
	return SiegeSystem.create_siege_state(1, 10, 20, rice, civilian_pu, garrison_pu)


# -- Create Siege State Tests ---------------------------------------------------

func test_create_siege_state() -> void:
	var s: Dictionary = _make_siege()
	assert_eq(s["settlement_id"], 1)
	assert_eq(s["attacker_army_id"], 10)
	assert_eq(s["defender_army_id"], 20)
	assert_almost_eq(s["rice_stockpile"], 2.0, 0.001)
	assert_eq(s["ticks_elapsed"], 0)
	assert_eq(s["ticks_since_sortie"], 0)
	assert_false(s["garrison_starved"])
	assert_false(s["siege_ended"])


# -- Daily Consumption Tests ----------------------------------------------------

func test_daily_consumption_castle_town() -> void:
	# 10 PU civilians + 0.5 PU garrison
	var daily: float = SiegeSystem.compute_daily_consumption(10.0, 0.5)
	# 10 * 0.0028 + 0.5 * 0.0039 = 0.028 + 0.00195 = 0.02995
	assert_almost_eq(daily, 0.02995, 0.0001)


func test_daily_consumption_fortification() -> void:
	# 0 civilians, 0.5 PU garrison
	var daily: float = SiegeSystem.compute_daily_consumption(0.0, 0.5)
	assert_almost_eq(daily, 0.00195, 0.0001)


func test_daily_consumption_zero_pu() -> void:
	var daily: float = SiegeSystem.compute_daily_consumption(0.0, 0.0)
	assert_almost_eq(daily, 0.0, 0.0001)


# -- Starvation Timeline Tests --------------------------------------------------

func test_ticks_until_starvation_castle_town() -> void:
	# 2.0 Rice, 10 PU civ + 0.5 PU garrison
	# Daily = 0.02995, ticks = 2.0 / 0.02995 ≈ 66
	var ticks: int = SiegeSystem.compute_ticks_until_starvation(2.0, 10.0, 0.5)
	assert_true(ticks >= 66 and ticks <= 68, "Castle town ~67 ticks, got %d" % ticks)


func test_ticks_until_starvation_town() -> void:
	# 1.0 Rice, 5 PU civ + 0.5 PU garrison
	# Daily = 5*0.0028 + 0.5*0.0039 = 0.014 + 0.00195 = 0.01595
	# ticks = 1.0 / 0.01595 ≈ 62
	var ticks: int = SiegeSystem.compute_ticks_until_starvation(1.0, 5.0, 0.5)
	assert_true(ticks >= 62 and ticks <= 64, "Town ~63 ticks, got %d" % ticks)


func test_ticks_until_starvation_fortification() -> void:
	# 0.5 Rice, 0 PU civ + 0.5 PU garrison
	# Daily = 0.00195, ticks = 0.5 / 0.00195 ≈ 256
	var ticks: int = SiegeSystem.compute_ticks_until_starvation(0.5, 0.0, 0.5)
	assert_true(ticks >= 255 and ticks <= 257, "Fortification ~256 ticks, got %d" % ticks)


func test_ticks_larger_garrison_burns_faster() -> void:
	var standard: int = SiegeSystem.compute_ticks_until_starvation(2.0, 10.0, 0.5)
	var larger: int = SiegeSystem.compute_ticks_until_starvation(2.0, 10.0, 2.0)
	assert_true(larger < standard, "Larger garrison should burn faster")


# -- Starvation Tick Processing -------------------------------------------------

func test_starvation_tick_consumes_rice() -> void:
	var s: Dictionary = _make_siege(2.0, 10.0, 0.5)
	var r: Dictionary = SiegeSystem.process_starvation_tick(s)
	assert_true(r["rice_remaining"] < 2.0)
	assert_false(r["starved"])
	assert_eq(r["ticks_elapsed"], 1)


func test_starvation_tick_starves_at_zero() -> void:
	var s: Dictionary = _make_siege(0.01, 10.0, 0.5)
	# Run until starved
	var starved: bool = false
	for i: int in 10:
		var r: Dictionary = SiegeSystem.process_starvation_tick(s)
		if r["starved"]:
			starved = true
			break
	assert_true(starved, "Should starve with 0.01 rice")
	assert_true(s["garrison_starved"])


func test_starvation_tick_rice_floors_at_zero() -> void:
	var s: Dictionary = _make_siege(0.001, 10.0, 0.5)
	SiegeSystem.process_starvation_tick(s)
	assert_almost_eq(s["rice_stockpile"], 0.0, 0.001)


func test_starvation_tick_increments_counters() -> void:
	var s: Dictionary = _make_siege()
	SiegeSystem.process_starvation_tick(s)
	SiegeSystem.process_starvation_tick(s)
	assert_eq(s["ticks_elapsed"], 2)
	assert_eq(s["ticks_since_sortie"], 2)


# -- Siege Phase Tests ----------------------------------------------------------

func test_siege_phase_early() -> void:
	assert_eq(SiegeSystem.get_siege_phase(1), SiegeSystem.SiegePhase.EARLY)
	assert_eq(SiegeSystem.get_siege_phase(30), SiegeSystem.SiegePhase.EARLY)


func test_siege_phase_mid() -> void:
	assert_eq(SiegeSystem.get_siege_phase(31), SiegeSystem.SiegePhase.MID)
	assert_eq(SiegeSystem.get_siege_phase(60), SiegeSystem.SiegePhase.MID)


func test_siege_phase_late() -> void:
	assert_eq(SiegeSystem.get_siege_phase(61), SiegeSystem.SiegePhase.LATE)
	assert_eq(SiegeSystem.get_siege_phase(100), SiegeSystem.SiegePhase.LATE)


# -- Event Interval Tests -------------------------------------------------------

func test_event_interval_early() -> void:
	assert_eq(
		SiegeSystem.get_event_interval(SiegeSystem.SiegePhase.EARLY),
		10,
	)


func test_event_interval_mid() -> void:
	assert_eq(
		SiegeSystem.get_event_interval(SiegeSystem.SiegePhase.MID),
		7,
	)


func test_event_interval_late() -> void:
	assert_eq(
		SiegeSystem.get_event_interval(SiegeSystem.SiegePhase.LATE),
		5,
	)


# -- Event Firing Tests ----------------------------------------------------------

func test_should_fire_event_at_10() -> void:
	assert_true(SiegeSystem.should_fire_event(10))


func test_should_not_fire_event_at_5_early() -> void:
	assert_false(SiegeSystem.should_fire_event(5))


func test_should_fire_event_at_35_mid() -> void:
	# Mid phase: interval 7. 35 % 7 == 0
	assert_true(SiegeSystem.should_fire_event(35))


func test_should_fire_event_at_65_late() -> void:
	# Late phase: interval 5. 65 % 5 == 0
	assert_true(SiegeSystem.should_fire_event(65))


func test_should_not_fire_at_zero() -> void:
	assert_false(SiegeSystem.should_fire_event(0))


# -- Event Selection Tests -------------------------------------------------------

func test_select_attacker_event() -> void:
	var event: String = SiegeSystem.select_event(_dice, "attacker")
	var valid: Array[String] = ATTACKER_EVENTS_PLUS_MUTUAL()
	assert_has(valid, event)


func test_select_defender_event() -> void:
	var event: String = SiegeSystem.select_event(_dice, "defender")
	var valid: Array[String] = DEFENDER_EVENTS_PLUS_MUTUAL()
	assert_has(valid, event)


func ATTACKER_EVENTS_PLUS_MUTUAL() -> Array[String]:
	var pool: Array[String] = SiegeSystem.ATTACKER_EVENTS.duplicate()
	pool.append_array(SiegeSystem.MUTUAL_EVENTS)
	return pool


func DEFENDER_EVENTS_PLUS_MUTUAL() -> Array[String]:
	var pool: Array[String] = SiegeSystem.DEFENDER_EVENTS.duplicate()
	pool.append_array(SiegeSystem.MUTUAL_EVENTS)
	return pool


# -- Event Resolution Tests ------------------------------------------------------

func test_resolve_smuggling_ring_success() -> void:
	var found: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SiegeSystem.resolve_siege_event(
			_dice, "A1_SMUGGLING_RING", 4, 3,
		)
		if r["success"]:
			assert_eq(r["tick_change"], -10)
			found = true
			break
	assert_true(found, "Should find a successful smuggling intercept")


func test_resolve_smuggling_ring_failure() -> void:
	var found: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SiegeSystem.resolve_siege_event(
			_dice, "A1_SMUGGLING_RING", 2, 1,
		)
		if not r["success"]:
			assert_eq(r["tick_change"], 0)
			found = true
			break
	assert_true(found, "Should find a failed smuggling intercept")


func test_resolve_relief_force_is_strategic() -> void:
	var r: Dictionary = SiegeSystem.resolve_siege_event(
		_dice, "A4_RELIEF_FORCE", 0, 0,
	)
	assert_true(r["is_strategic_decision"])


func test_resolve_contaminate_water_honor_cost() -> void:
	var found: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SiegeSystem.resolve_siege_event(
			_dice, "A6_CONTAMINATE_WATER", 5, 4,
		)
		assert_almost_eq(r["honor_cost"], -0.5, 0.01)
		found = true
		break
	assert_true(found)


func test_resolve_midnight_resupply_success_adds_ticks() -> void:
	var found: bool = false
	for i: int in 100:
		_dice.set_seed(i)
		var r: Dictionary = SiegeSystem.resolve_siege_event(
			_dice, "D1_MIDNIGHT_RESUPPLY", 5, 4,
		)
		if r["success"]:
			assert_eq(r["tick_change"], 15)
			assert_has(r["effects"], "garrison_gains_rice_0_5")
			found = true
			break
	assert_true(found, "Should find a successful resupply")


func test_resolve_treachery_is_special() -> void:
	var r: Dictionary = SiegeSystem.resolve_siege_event(
		_dice, "M1_TREACHERY_WITHIN", 0, 0,
	)
	assert_true(r["is_special"])


# -- Storm Assault Tests ---------------------------------------------------------

func test_storm_defense_bonus() -> void:
	# Urban (+3) + Fortification (+5) = +8
	assert_eq(SiegeSystem.get_storm_defense_bonus(), 8)


func test_garrison_effective_defense_with_fortification() -> void:
	# Base 5 (garrison) + Urban 3 + Fort 5 = 13
	var eff: int = SiegeSystem.compute_garrison_effective_defense(5)
	assert_eq(eff, 13)


func test_storm_defense_bonus_town_no_fortification() -> void:
	# GDD s11.7: towns have Urban +3 only, no fortification bonus
	assert_eq(SiegeSystem.get_storm_defense_bonus(false), 3)


func test_garrison_effective_defense_town_no_fortification() -> void:
	# Town: Base 5 + Urban 3 = 8 (no fortification +5)
	var eff: int = SiegeSystem.compute_garrison_effective_defense(5, false)
	assert_eq(eff, 8)


# -- Honor Cowardice Tests ------------------------------------------------------

func test_honor_no_loss_before_threshold() -> void:
	var loss: float = SiegeSystem.compute_honor_loss(25, "default")
	assert_almost_eq(loss, 0.0, 0.001)


func test_honor_loss_after_default_threshold() -> void:
	# 30 + 10 = tick 40, should have 1.0 loss
	var loss: float = SiegeSystem.compute_honor_loss(40, "default")
	assert_almost_eq(loss, 1.0, 0.001)


func test_honor_loss_after_two_intervals() -> void:
	# 30 + 20 = tick 50, should have 2.0 loss
	var loss: float = SiegeSystem.compute_honor_loss(50, "default")
	assert_almost_eq(loss, 2.0, 0.001)


func test_honor_loss_aggressive_earlier() -> void:
	# Threshold 20, tick 30 = 1.0 loss
	var loss: float = SiegeSystem.compute_honor_loss(30, "aggressive")
	assert_almost_eq(loss, 1.0, 0.001)
	# Default would have 0.0 at tick 30
	var default_loss: float = SiegeSystem.compute_honor_loss(30, "default")
	assert_almost_eq(default_loss, 0.0, 0.001)


func test_honor_loss_pragmatic_later() -> void:
	# Threshold 45, tick 40 = 0.0 loss
	var loss: float = SiegeSystem.compute_honor_loss(40, "pragmatic")
	assert_almost_eq(loss, 0.0, 0.001)
	# Tick 55 = 1.0 loss
	var loss55: float = SiegeSystem.compute_honor_loss(55, "pragmatic")
	assert_almost_eq(loss55, 1.0, 0.001)


func test_process_honor_cowardice_incremental_loss() -> void:
	var s: Dictionary = _make_siege()
	s["ticks_since_sortie"] = 40
	var r: Dictionary = SiegeSystem.process_honor_cowardice(s, "default")
	assert_almost_eq(r["total_honor_loss"], 1.0, 0.001)
	assert_almost_eq(r["new_honor_loss"], 1.0, 0.001)


func test_process_honor_no_double_loss() -> void:
	var s: Dictionary = _make_siege()
	s["ticks_since_sortie"] = 40
	SiegeSystem.process_honor_cowardice(s, "default")
	# Same tick count — no new loss
	var r: Dictionary = SiegeSystem.process_honor_cowardice(s, "default")
	assert_almost_eq(r["new_honor_loss"], 0.0, 0.001)


func test_reset_sortie_counter() -> void:
	var s: Dictionary = _make_siege()
	s["ticks_since_sortie"] = 50
	s["honor_loss_accumulated"] = 2.0
	SiegeSystem.reset_sortie_counter(s)
	assert_eq(s["ticks_since_sortie"], 0)
	assert_almost_eq(s["honor_loss_accumulated"], 0.0, 0.001)


# -- Sortie Terrain Tests -------------------------------------------------------

func test_sortie_terrain_has_urban_only() -> void:
	var r: Dictionary = SiegeSystem.compute_sortie_terrain_bonus()
	assert_eq(r["defender_defense_bonus"], 3)
	assert_eq(r["fortification_bonus"], 0)


# -- Siege End Tests ------------------------------------------------------------

func test_siege_end_on_starvation() -> void:
	var s: Dictionary = _make_siege(0.001, 10.0, 0.5)
	SiegeSystem.process_starvation_tick(s)
	var r: Dictionary = SiegeSystem.check_siege_end(s)
	assert_true(r["ended"])
	assert_eq(r["reason"], "starvation")


func test_siege_not_ended_with_food() -> void:
	var s: Dictionary = _make_siege(2.0, 10.0, 0.5)
	var r: Dictionary = SiegeSystem.check_siege_end(s)
	assert_false(r["ended"])


func test_end_siege_manual() -> void:
	var s: Dictionary = _make_siege()
	SiegeSystem.end_siege(s, "retreat")
	assert_true(s["siege_ended"])
	assert_eq(s["end_reason"], "retreat")


# -- Full Tick Tests -------------------------------------------------------------

func test_full_tick_advances_state() -> void:
	var s: Dictionary = _make_siege()
	var r: Dictionary = SiegeSystem.process_siege_tick(s, _dice, "default")
	assert_false(r["ended"])
	assert_eq(s["ticks_elapsed"], 1)


func test_full_tick_already_ended() -> void:
	var s: Dictionary = _make_siege()
	SiegeSystem.end_siege(s, "retreat")
	var r: Dictionary = SiegeSystem.process_siege_tick(s, _dice, "default")
	assert_true(r["already_ended"])


func test_full_tick_fires_event_at_10() -> void:
	var s: Dictionary = _make_siege()
	var event_tick: Dictionary = {}
	for i: int in 10:
		var r: Dictionary = SiegeSystem.process_siege_tick(s, _dice, "default")
		if r["event"]["should_fire"]:
			event_tick = r["event"]
			break
	assert_true(event_tick.get("should_fire", false), "Event should fire at tick 10")


func test_full_siege_until_starvation() -> void:
	var s: Dictionary = _make_siege(0.1, 1.0, 0.5)
	var ended: bool = false
	for i: int in 200:
		var r: Dictionary = SiegeSystem.process_siege_tick(s, _dice, "default")
		if r.get("ended", false):
			ended = true
			assert_eq(r["end_reason"], "starvation")
			break
	assert_true(ended, "Siege should end from starvation")


func test_event_tick_change_applied() -> void:
	var s: Dictionary = _make_siege(2.0, 10.0, 0.5)
	var before: float = s["rice_stockpile"]
	SiegeSystem.apply_event_tick_change(s, -10)
	assert_true(s["rice_stockpile"] < before)


func test_event_tick_change_positive() -> void:
	var s: Dictionary = _make_siege(2.0, 10.0, 0.5)
	var before: float = s["rice_stockpile"]
	SiegeSystem.apply_event_tick_change(s, 15)
	assert_true(s["rice_stockpile"] > before)


# -- Tether Collapse Tests -------------------------------------------------------

func test_tether_broken_ends_siege() -> void:
	# GDD s11.7: "if that tether is cut... the siege collapses"
	assert_true(
		SiegeSystem.check_tether_ends_siege(SupplyTetherSystem.TetherState.BROKEN),
	)


func test_tether_solid_does_not_end_siege() -> void:
	assert_false(
		SiegeSystem.check_tether_ends_siege(SupplyTetherSystem.TetherState.SOLID),
	)


func test_tether_threatened_does_not_end_siege() -> void:
	assert_false(
		SiegeSystem.check_tether_ends_siege(SupplyTetherSystem.TetherState.THREATENED),
	)
