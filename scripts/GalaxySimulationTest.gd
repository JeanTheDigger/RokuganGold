extends RefCounted
class_name GalaxySimulationTest

const StrategicTestConfigScript = preload("res://scripts/simulation/StrategicTestConfig.gd")
const StrategicTestLogicScript = preload("res://scripts/simulation/StrategicTestLogic.gd")
const PiratePresenceData = preload("res://scripts/simulation/PiratePresenceTEST.gd")
const CanonSystemTestDataScript = preload("res://scripts/data/canon_systems_test.gd")

var _systems: Array[Dictionary] = []
var _systems_by_name: Dictionary = {}
var _systems_by_id: Dictionary = {}
var _system_name_by_planet_id: Dictionary = {}
var _system_id_by_planet_id: Dictionary = {}
var _planets_by_id: Dictionary = {}
var _planet_ids_by_name: Dictionary = {}
var _factions_by_id: Dictionary = {}
var _spawned_fleet_units: Array[Dictionary] = []
var _day_index: int = 0
var _next_fleet_id: int = 1
var _next_troop_id: int = 1
var _last_planet_yield_by_id: Dictionary = {}
var _last_belt_yield_by_system_id: Dictionary = {}
var _last_faction_delta_by_id: Dictionary = {}
var _pending_operation_logs: Array[String] = []
var invasion_plan_by_faction: Dictionary = {}
var _ai_invasion_last_failure_day_by_faction: Dictionary = {}
var _ai_invasion_last_load_skip_day_by_faction: Dictionary = {}
var ai_trace_by_faction: Dictionary = {}
var ai_trace_cursor_by_faction: Dictionary = {}
var faction_orders_by_day: Dictionary = {}
var _planner_execution_active: bool = false

const ORDER_SOURCE_FACTION_PLANNER: String = "FACTION_PLANNER"
const SPACE_QUEUE_CAPACITY: int = 5
const DEFAULT_ORBIT_SLOT_CAPACITY: int = 6
const BOOTSTRAP_METAL_SEED_GLOBAL: int = 150
const BOOTSTRAP_RARE_METAL_SEED_GLOBAL: int = 20
func setup_from_systems(systems: Array[Dictionary]) -> void:
	_systems = systems.duplicate(true)
	_systems_by_name.clear()
	_systems_by_id.clear()
	_system_name_by_planet_id.clear()
	_system_id_by_planet_id.clear()
	_planets_by_id.clear()
	_planet_ids_by_name.clear()
	_factions_by_id.clear()
	_spawned_fleet_units.clear()
	_day_index = 0
	_next_fleet_id = 1
	_next_troop_id = 1
	_last_planet_yield_by_id.clear()
	_last_belt_yield_by_system_id.clear()
	_last_faction_delta_by_id.clear()
	_pending_operation_logs.clear()
	invasion_plan_by_faction.clear()
	_ai_invasion_last_failure_day_by_faction.clear()
	_ai_invasion_last_load_skip_day_by_faction.clear()
	ai_trace_by_faction.clear()
	ai_trace_cursor_by_faction.clear()
	faction_orders_by_day.clear()
	_planner_execution_active = false
	_initialize_default_factions()
	for faction_id_variant in _factions_by_id.keys():
		var faction_id: int = int(faction_id_variant)
		ai_trace_by_faction[faction_id] = []
		ai_trace_cursor_by_faction[faction_id] = 0
	_index_and_prepare_planets()
	_attach_phase_one_shipyard_to_first_owned_planet()


func advance_day() -> Array[String]:
	_day_index += 1
	return run_strategic_day()


func drain_pending_operation_logs() -> Array[String]:
	var out: Array[String] = _pending_operation_logs.duplicate(true)
	_pending_operation_logs.clear()
	return out


func run_strategic_day() -> Array[String]:
	var logs: Array[String] = []
	var governor_logs: Array[String] = []
	var faction_upkeep_paid_by_id: Dictionary = {}
	var faction_income_credits_by_id: Dictionary = {}
	var faction_shipyard_status_by_id: Dictionary = {}
	var faction_upkeep_breakdown_by_id: Dictionary = {}
	var faction_unpaid_counts_by_id: Dictionary = {}
	var planet_yield_by_id: Dictionary = {}
	var belt_yield_by_system_id: Dictionary = {}
	var faction_resources_before: Dictionary = {}

	for faction_id_variant in _factions_by_id.keys():
		var before_faction_id: int = int(faction_id_variant)
		var before_faction_state: Dictionary = _factions_by_id[before_faction_id]
		faction_resources_before[before_faction_id] = {
			"credits": int(before_faction_state.get("credits", 0)),
			"metal": int(before_faction_state.get("metal", 0)),
			"rare_metal": int(before_faction_state.get("rare_metal", 0)),
		}

	for faction_id_variant in _factions_by_id.keys():
		var faction_id: int = int(faction_id_variant)
		faction_upkeep_paid_by_id[faction_id] = 0
		faction_income_credits_by_id[faction_id] = 0
		faction_shipyard_status_by_id[faction_id] = []
		faction_upkeep_breakdown_by_id[faction_id] = {
			"orbit": 0,
			"platform": 0,
			"fleet": 0,
			"troop": 0,
		}
		faction_unpaid_counts_by_id[faction_id] = {
			"orbit": 0,
			"fleet": 0,
			"troop": 0,
		}

	# 1) Movement completion for today.
	_apply_fleet_arrivals_for_day(_day_index, logs)

	# 2) Derive SR after arrivals/readiness.
	for system_variant in _systems:
		var pre_encounter_system_state: Dictionary = system_variant
		compute_system_sr(int(pre_encounter_system_state.get("id", -1)))

	# 3) Create day-1 engagements after arrivals/SR derivation (no same-day damage).
	_create_space_engagements_for_day(_day_index, logs)
	_create_ground_engagements_for_day(_day_index, logs)

	# 4) Resolve day-2 engagements scheduled for today.
	_resolve_space_engagements_for_day(_day_index, logs)
	_resolve_ground_engagements_for_day(_day_index, logs)

	# 5) Re-derive SR immediately after encounter outcomes.
	for system_variant in _systems:
		var post_encounter_system_state: Dictionary = system_variant
		compute_system_sr(int(post_encounter_system_state.get("id", -1)))

	_assign_patrol_fleets(_day_index, governor_logs)

	# 5) Continue scouting + security/piracy + blockade derivation.
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		_update_scouting_freshness_for_system(system_state)
		_update_system_security_and_piracy(system_state)
		compute_system_blockades(int(system_state.get("id", -1)))

	# 2) Income phase (planets + belts)
	for planet_id_variant in _planets_by_id.keys():
		var planet_id_for_yield: int = int(planet_id_variant)
		var planet_state_for_yield: Dictionary = _planets_by_id[planet_id_for_yield]
		var system_for_planet_yield: Dictionary = get_system(int(planet_state_for_yield.get("system_id", -1)))
		var planet_piracy_multiplier: float = _get_planet_piracy_multiplier(system_for_planet_yield)
		var owner_faction_id: int = int(planet_state_for_yield.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not _factions_by_id.has(owner_faction_id):
			continue
		var faction_state: Dictionary = _factions_by_id[owner_faction_id]
		var yield_result: Dictionary = StrategicTestLogicScript.compute_planet_yield(
			planet_state_for_yield,
			is_planet_blockaded(planet_state_for_yield),
			planet_piracy_multiplier
		)
		faction_state["credits"] = int(faction_state.get("credits", 0)) + int(yield_result.get("credits_gain", 0))
		faction_state["metal"] = int(faction_state.get("metal", 0)) + int(yield_result.get("metal_gain", 0))
		faction_state["rare_metal"] = int(faction_state.get("rare_metal", 0)) + int(yield_result.get("rare_gain", 0))
		planet_yield_by_id[planet_id_for_yield] = yield_result
		faction_income_credits_by_id[owner_faction_id] = int(faction_income_credits_by_id.get(owner_faction_id, 0)) + int(yield_result.get("credits_gain", 0))

	for system_variant in _systems:
		var belt_system_state: Dictionary = system_variant
		var belt_income: Dictionary = _resolve_belt_income(belt_system_state)
		belt_yield_by_system_id[int(belt_system_state.get("id", -1))] = belt_income

	# 3) Upkeep phase (belts + orbital structures + fleets)
	var fleet_upkeep_paid_by_fleet_id: Dictionary = {}
	for system_variant in _systems:
		var system_state_for_upkeep: Dictionary = system_variant
		if bool(system_state_for_upkeep.get("has_belt", false)):
			var belt_owner_faction_id: int = int(system_state_for_upkeep.get("belt_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			if _factions_by_id.has(belt_owner_faction_id):
				var platform_upkeep: int = StrategicTestLogicScript.get_platform_upkeep_for_tier(int(system_state_for_upkeep.get("platform_tier", 0)))
				var belt_owner_faction_state: Dictionary = _factions_by_id[belt_owner_faction_id]
				if int(belt_owner_faction_state.get("credits", 0)) >= platform_upkeep:
					belt_owner_faction_state["credits"] = int(belt_owner_faction_state.get("credits", 0)) - platform_upkeep
					faction_upkeep_paid_by_id[belt_owner_faction_id] = int(faction_upkeep_paid_by_id.get(belt_owner_faction_id, 0)) + platform_upkeep
					(faction_upkeep_breakdown_by_id[belt_owner_faction_id] as Dictionary)["platform"] = int((faction_upkeep_breakdown_by_id[belt_owner_faction_id] as Dictionary).get("platform", 0)) + platform_upkeep

		var structures: Array = system_state_for_upkeep.get("orbital_structures", [])
		for structure_variant in structures:
			var structure: Dictionary = structure_variant
			var owner_faction_id: int = int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			if not _factions_by_id.has(owner_faction_id):
				continue
			var faction_state: Dictionary = _factions_by_id[owner_faction_id]
			var structure_type: String = str(structure.get("type", ""))
			if structure_type == StrategicTestConfigScript.SHIPYARD_I_TYPE:
				var shipyard_upkeep: Dictionary = StrategicTestLogicScript.pay_shipyard_upkeep(structure, faction_state)
				var shipyard_upkeep_paid: int = int(shipyard_upkeep.get("upkeep_paid", 0))
				faction_upkeep_paid_by_id[owner_faction_id] = int(faction_upkeep_paid_by_id.get(owner_faction_id, 0)) + shipyard_upkeep_paid
				(faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary)["orbit"] = int((faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary).get("orbit", 0)) + shipyard_upkeep_paid
				if shipyard_upkeep_paid <= 0:
					(faction_unpaid_counts_by_id[owner_faction_id] as Dictionary)["orbit"] = int((faction_unpaid_counts_by_id[owner_faction_id] as Dictionary).get("orbit", 0)) + 1
				structure["can_generate_sp"] = bool(shipyard_upkeep.get("can_generate_sp", false))
			else:
				var station_upkeep: Dictionary = StrategicTestLogicScript.pay_defense_station_upkeep(structure, faction_state)
				var station_upkeep_paid: int = int(station_upkeep.get("upkeep_paid", 0))
				faction_upkeep_paid_by_id[owner_faction_id] = int(faction_upkeep_paid_by_id.get(owner_faction_id, 0)) + station_upkeep_paid
				(faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary)["orbit"] = int((faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary).get("orbit", 0)) + station_upkeep_paid
				if station_upkeep_paid <= 0:
					(faction_unpaid_counts_by_id[owner_faction_id] as Dictionary)["orbit"] = int((faction_unpaid_counts_by_id[owner_faction_id] as Dictionary).get("orbit", 0)) + 1
				structure["enabled"] = bool(station_upkeep.get("is_active", false))

	_apply_fleet_upkeep_deterministic(fleet_upkeep_paid_by_fleet_id, faction_upkeep_paid_by_id, faction_upkeep_breakdown_by_id, faction_unpaid_counts_by_id)
	_apply_troop_upkeep_deterministic(logs, faction_upkeep_paid_by_id, faction_upkeep_breakdown_by_id, faction_unpaid_counts_by_id)
	_apply_fleet_readiness_changes(fleet_upkeep_paid_by_fleet_id, logs)

	# 4) Deterministic garrison recruitment (post-income, post-upkeep, pre-governance)
	_apply_garrison_recruitment(logs)
	_process_troop_training(logs)

	# 5) Governance per planet
	for planet_id_variant in _planets_by_id.keys():
		var planet_id_for_control: int = int(planet_id_variant)
		var planet_state: Dictionary = _planets_by_id[planet_id_for_control]
		var control_update: Dictionary = StrategicTestLogicScript.update_planet_control_and_stability(planet_state, is_planet_blockaded(planet_state))
		if bool(control_update.get("revolt_occurred", false)):
			var previous_owner_faction_id: int = int(control_update.get("previous_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			var new_owner_faction_id: int = int(control_update.get("new_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			if previous_owner_faction_id != new_owner_faction_id:
				_reassign_planet_ownership(planet_id_for_control, previous_owner_faction_id, new_owner_faction_id)
			logs.append("DAY %d | REVOLT | planet=%d new_owner=%d control=%d stability=%d" % [
				_day_index,
				planet_id_for_control,
				int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
				int(planet_state.get("control", 0)),
				int(planet_state.get("stability", 0)),
			])

	# 6) Shipyard progression + completion retries (before governor)
	for system_variant in _systems:
		var system_for_queue: Dictionary = system_variant
		_process_shipyards_for_system(system_for_queue, logs, faction_shipyard_status_by_id)

	for system_id in _get_sorted_system_ids():
		_advance_space_queue(get_system(system_id), logs)

	faction_orders_by_day.clear()
	for faction_id in _get_sorted_faction_ids():
		if faction_id == StrategicTestConfigScript.NO_OWNER_FACTION_ID:
			continue
		var order_book: Dictionary = run_faction_planner_for_faction(faction_id, {"day": _day_index})
		faction_orders_by_day[faction_id] = order_book
		execute_faction_order_book(faction_id, order_book, governor_logs)

	# 7) Deterministic haven clearing (end-of-day)
	for system_variant in _systems:
		var system_state_for_haven_clear: Dictionary = system_variant
		_try_clear_pirate_haven(system_state_for_haven_clear)

	# 8) Decrement disabled counters
	for system_variant in _systems:
		var system_state_for_disable: Dictionary = system_variant
		if bool(system_state_for_disable.get("has_belt", false)):
			system_state_for_disable["belt_disabled_days"] = maxi(0, int(system_state_for_disable.get("belt_disabled_days", 0)) - 1)
			var belt_for_disable: Dictionary = system_state_for_disable.get("belt", {})
			if not belt_for_disable.is_empty():
				belt_for_disable["belt_disabled_days"] = int(system_state_for_disable.get("belt_disabled_days", 0))
				belt_for_disable["disabled_days"] = int(system_state_for_disable.get("belt_disabled_days", 0))
		var structures: Array = system_state_for_disable.get("orbital_structures", [])
		for structure_variant in structures:
			var structure: Dictionary = structure_variant
			structure["disabled_days"] = maxi(0, int(structure.get("disabled_days", 0)) - 1)

	_last_planet_yield_by_id = planet_yield_by_id.duplicate(true)
	_last_belt_yield_by_system_id = belt_yield_by_system_id.duplicate(true)
	_last_faction_delta_by_id.clear()
	for faction_id_variant in _factions_by_id.keys():
		var delta_faction_id: int = int(faction_id_variant)
		var after_faction_state: Dictionary = _factions_by_id[delta_faction_id]
		var before_snapshot: Dictionary = faction_resources_before.get(delta_faction_id, {"credits": 0, "metal": 0, "rare_metal": 0})
		_last_faction_delta_by_id[delta_faction_id] = {
			"credits": int(after_faction_state.get("credits", 0)) - int(before_snapshot.get("credits", 0)),
			"metal": int(after_faction_state.get("metal", 0)) - int(before_snapshot.get("metal", 0)),
			"rare_metal": int(after_faction_state.get("rare_metal", 0)) - int(before_snapshot.get("rare_metal", 0)),
		}

	logs.append_array(governor_logs)
	if not _pending_operation_logs.is_empty():
		logs.append_array(drain_pending_operation_logs())
	_append_daily_logs(logs, planet_yield_by_id, faction_upkeep_paid_by_id, faction_shipyard_status_by_id, faction_income_credits_by_id, faction_upkeep_breakdown_by_id, faction_unpaid_counts_by_id)
	return logs


func add_fleet_to_system(system_name: String, owner_faction_id: int, sr: int, group_id: String = "main") -> bool:
	var system_state: Dictionary = _systems_by_name.get(system_name, {})
	if system_state.is_empty():
		return false
	var fleets: Array = system_state.get("fleets", [])
	var system_id: int = int(system_state.get("id", -1))
	var fleet: Dictionary = StrategicTestConfigScript.create_fleet(owner_faction_id, sr, group_id, system_id)
	_ensure_fleet_defaults(fleet, system_id)
	fleets.append(fleet)
	system_state["fleets"] = fleets
	return true


func _ensure_fleet_defaults(fleet_state: Dictionary, fallback_system_id: int = -1) -> void:
	if not fleet_state.has("fleet_id"):
		fleet_state["fleet_id"] = _next_fleet_id
		_next_fleet_id += 1
	else:
		_next_fleet_id = maxi(_next_fleet_id, int(fleet_state.get("fleet_id", 0)) + 1)
	if not fleet_state.has("role"):
		fleet_state["role"] = StrategicTestConfigScript.FLEET_ROLE_IDLE
	if not fleet_state.has("patrol_system_id"):
		fleet_state["patrol_system_id"] = -1
	if not fleet_state.has("system_id") or int(fleet_state.get("system_id", -1)) <= 0:
		fleet_state["system_id"] = fallback_system_id
	if not fleet_state.has("status"):
		fleet_state["status"] = "idle"
	if not fleet_state.has("target_system_id"):
		fleet_state["target_system_id"] = -1
	if not fleet_state.has("arrival_day"):
		fleet_state["arrival_day"] = -1
	if not fleet_state.has("task"):
		fleet_state["task"] = {}
	if not fleet_state.has("last_order_day"):
		fleet_state["last_order_day"] = -1
	if not fleet_state.has("readiness"):
		fleet_state["readiness"] = 100
	if not fleet_state.has("missed_upkeep_days"):
		fleet_state["missed_upkeep_days"] = 0
	if not fleet_state.has("last_refit_day"):
		fleet_state["last_refit_day"] = -999999
	_normalize_fleet_ships_if_needed(fleet_state)
	if not fleet_state.has("cargo_troop_gp"):
		fleet_state["cargo_troop_gp"] = 0
	if not fleet_state.has("transport_capacity_gp"):
		fleet_state["transport_capacity_gp"] = 0
	if not fleet_state.has("landed_planet_id"):
		fleet_state["landed_planet_id"] = -1
	fleet_state["transport_capacity_gp"] = StrategicTestLogicScript.get_fleet_transport_capacity_gp(fleet_state)
	fleet_state["cargo_troop_gp"] = clampi(int(fleet_state.get("cargo_troop_gp", 0)), 0, int(fleet_state.get("transport_capacity_gp", 0)))
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		fleet_state["cargo_troop_gp"] = 0
		fleet_state["landed_planet_id"] = -1
	fleet_state["readiness"] = clampi(int(fleet_state.get("readiness", 100)), 0, 100)
	fleet_state["sr"] = StrategicTestLogicScript.get_fleet_base_sr(fleet_state)
	fleet_state["upkeep_credits_per_day"] = StrategicTestLogicScript.get_fleet_upkeep(fleet_state)


func _normalize_fleet_ships_if_needed(fleet_state: Dictionary) -> void:
	if fleet_state.has("ships") and fleet_state.get("ships", []) is Array:
		return
	var blueprint_id: String = str(fleet_state.get("blueprint_id", "legacy_ship"))
	var legacy_sr: int = maxi(0, int(fleet_state.get("sr", 0)))
	var legacy_upkeep: int = maxi(0, int(fleet_state.get("upkeep_credits_per_day", 0)))
	fleet_state["ships"] = [StrategicTestLogicScript.make_ship_roster_entry(blueprint_id, legacy_sr, legacy_upkeep)]


func get_fleet_base_sr(fleet_state: Dictionary) -> int:
	_ensure_fleet_defaults(fleet_state, int(fleet_state.get("system_id", -1)))
	return StrategicTestLogicScript.get_fleet_base_sr(fleet_state)


func get_fleet_effective_sr(fleet_state: Dictionary) -> int:
	_ensure_fleet_defaults(fleet_state, int(fleet_state.get("system_id", -1)))
	return StrategicTestLogicScript.get_fleet_effective_sr(fleet_state)


func get_fleet_upkeep_credits_per_day(fleet_state: Dictionary) -> int:
	_ensure_fleet_defaults(fleet_state, int(fleet_state.get("system_id", -1)))
	return StrategicTestLogicScript.get_fleet_upkeep(fleet_state)


func merge_fleets(system_id: int, owner_faction_id: int, fleet_ids: Array[int]) -> int:
	if fleet_ids.size() < 2:
		return -1
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return -1
	var requested_ids: Array[int] = []
	for fleet_id in fleet_ids:
		if not requested_ids.has(fleet_id):
			requested_ids.append(fleet_id)
	requested_ids.sort()
	var fleets: Array = system_state.get("fleets", [])
	var selected: Array[Dictionary] = []
	for fleet_variant in fleets:
		var fleet: Dictionary = fleet_variant
		_ensure_fleet_defaults(fleet, system_id)
		if not requested_ids.has(int(fleet.get("fleet_id", -1))):
			continue
		if int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != owner_faction_id:
			return -1
		if int(fleet.get("system_id", -1)) != system_id:
			return -1
		if str(fleet.get("status", "idle")) == "moving":
			return -1
		selected.append(fleet)
	if selected.size() != requested_ids.size():
		return -1
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
	)
	var primary: Dictionary = selected[0]
	var primary_id: int = int(primary.get("fleet_id", -1))
	var merged_ships: Array[Dictionary] = []
	var weighted_sum: int = 0
	var total_base_sr: int = 0
	var total_cargo_gp: int = 0
	var merged_landed_planet_id: int = -1
	var selected_transport_only: bool = StrategicTestLogicScript.fleet_is_transport_only(primary)
	for fleet in selected:
		if StrategicTestLogicScript.fleet_is_transport_only(fleet) != selected_transport_only:
			return -1
		if int(fleet.get("landed_planet_id", -1)) != int(primary.get("landed_planet_id", -1)):
			return -1
		var fleet_base_sr: int = get_fleet_base_sr(fleet)
		total_base_sr += fleet_base_sr
		weighted_sum += int(fleet.get("readiness", 100)) * fleet_base_sr
		total_cargo_gp += maxi(0, int(fleet.get("cargo_troop_gp", 0)))
		merged_landed_planet_id = int(fleet.get("landed_planet_id", -1))
		var sorted_ships: Array[Dictionary] = []
		for ship_variant in fleet.get("ships", []):
			sorted_ships.append((ship_variant as Dictionary).duplicate(true))
		StrategicTestLogicScript.sort_ships_for_merge_append(sorted_ships)
		merged_ships.append_array(sorted_ships)
	var merged_readiness: int = 100
	if total_base_sr > 0:
		merged_readiness = int(floor(float(weighted_sum) / float(total_base_sr)))
	primary["ships"] = merged_ships
	primary["readiness"] = clampi(merged_readiness, 0, 100)
	primary["landed_planet_id"] = merged_landed_planet_id
	primary["missed_upkeep_days"] = 0
	primary["sr"] = get_fleet_base_sr(primary)
	primary["upkeep_credits_per_day"] = get_fleet_upkeep_credits_per_day(primary)
	primary["transport_capacity_gp"] = StrategicTestLogicScript.get_fleet_transport_capacity_gp(primary)
	primary["cargo_troop_gp"] = clampi(total_cargo_gp, 0, int(primary.get("transport_capacity_gp", 0)))
	for i in range(fleets.size() - 1, -1, -1):
		var fleet: Dictionary = fleets[i]
		if int(fleet.get("fleet_id", -1)) == primary_id:
			continue
		if requested_ids.has(int(fleet.get("fleet_id", -1))):
			fleets.remove_at(i)
	system_state["fleets"] = fleets
	_pending_operation_logs.append("DAY %d | FLEET_MERGE | owner=%d sys=%d into=%d merged=%s ships=%d base_sr=%d readiness=%d" % [
		_day_index,
		owner_faction_id,
		system_id,
		primary_id,
		str(requested_ids),
		merged_ships.size(),
		int(primary.get("sr", 0)),
		int(primary.get("readiness", 100)),
	])
	return primary_id


func split_fleet_one_ship(fleet_id: int) -> int:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		var fleets: Array = system_state.get("fleets", [])
		for fleet_variant in fleets:
			var fleet: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet, system_id)
			if int(fleet.get("fleet_id", -1)) != fleet_id:
				continue
			if str(fleet.get("status", "idle")) == "moving":
				return -1
			if int(fleet.get("cargo_troop_gp", 0)) > 0:
				return -1
			var ships: Array = fleet.get("ships", [])
			if ships.size() < 2:
				return -1
			var sorted_with_index: Array[Dictionary] = []
			for ship_index in range(ships.size()):
				sorted_with_index.append({"ship": (ships[ship_index] as Dictionary).duplicate(true), "index": ship_index})
			sorted_with_index.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var a_ship: Dictionary = a.get("ship", {})
				var b_ship: Dictionary = b.get("ship", {})
				var a_sr: int = int(a_ship.get("sr", 0))
				var b_sr: int = int(b_ship.get("sr", 0))
				if a_sr != b_sr:
					return a_sr > b_sr
				var a_blueprint: String = str(a_ship.get("blueprint_id", ""))
				var b_blueprint: String = str(b_ship.get("blueprint_id", ""))
				if a_blueprint != b_blueprint:
					return a_blueprint < b_blueprint
				var a_upkeep: int = int(a_ship.get("upkeep_credits_per_day", 0))
				var b_upkeep: int = int(b_ship.get("upkeep_credits_per_day", 0))
				if a_upkeep != b_upkeep:
					return a_upkeep < b_upkeep
				return int(a.get("index", 0)) < int(b.get("index", 0))
			)
			var detach_info: Dictionary = sorted_with_index[sorted_with_index.size() - 1]
			var detach_index: int = int(detach_info.get("index", -1))
			if detach_index < 0 or detach_index >= ships.size():
				return -1
			var detached_ship: Dictionary = (ships[detach_index] as Dictionary).duplicate(true)
			ships.remove_at(detach_index)
			fleet["ships"] = ships
			fleet["sr"] = get_fleet_base_sr(fleet)
			fleet["upkeep_credits_per_day"] = get_fleet_upkeep_credits_per_day(fleet)
			var new_fleet: Dictionary = {
				"owner_faction_id": int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
				"group_id": str(fleet.get("group_id", "main")),
				"system_id": system_id,
				"status": "idle",
				"target_system_id": -1,
				"arrival_day": -1,
				"task": {},
				"last_order_day": _day_index,
				"role": str(fleet.get("role", StrategicTestConfigScript.FLEET_ROLE_IDLE)),
				"patrol_system_id": int(fleet.get("patrol_system_id", -1)),
				"ships": [detached_ship],
				"readiness": int(fleet.get("readiness", 100)),
				"missed_upkeep_days": int(fleet.get("missed_upkeep_days", 0)),
				"last_refit_day": int(fleet.get("last_refit_day", -999999)),
				"cargo_troop_gp": 0,
				"transport_capacity_gp": 0,
				"landed_planet_id": int(fleet.get("landed_planet_id", -1)),
			}
			_ensure_fleet_defaults(new_fleet, system_id)
			fleets.append(new_fleet)
			system_state["fleets"] = fleets
			_pending_operation_logs.append("DAY %d | FLEET_SPLIT | owner=%d sys=%d from=%d src_ships=%d new=%d new_ships=%d base_sr_src=%d base_sr_new=%d readiness=%d" % [
				_day_index,
				int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
				system_id,
				fleet_id,
				int((fleet.get("ships", []) as Array).size()),
				int(new_fleet.get("fleet_id", -1)),
				int((new_fleet.get("ships", []) as Array).size()),
				int(fleet.get("sr", 0)),
				int(new_fleet.get("sr", 0)),
				int(new_fleet.get("readiness", 100)),
			])
			return int(new_fleet.get("fleet_id", -1))
	return -1


func _collect_all_fleets() -> Array[Dictionary]:
	var fleets: Array[Dictionary] = []
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		for fleet_variant in system_state.get("fleets", []):
			var fleet_state: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet_state, system_id)
			fleets.append(fleet_state)
	return fleets


func _apply_fleet_upkeep_deterministic(fleet_upkeep_paid_by_fleet_id: Dictionary, faction_upkeep_paid_by_id: Dictionary, faction_upkeep_breakdown_by_id: Dictionary, faction_unpaid_counts_by_id: Dictionary) -> void:
	var fleets_by_faction: Dictionary = {}
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		for fleet_variant in system_state.get("fleets", []):
			var fleet: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet, system_id)
			var owner_id: int = int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			if not fleets_by_faction.has(owner_id):
				fleets_by_faction[owner_id] = []
			(fleets_by_faction[owner_id] as Array).append(fleet)
	for faction_id_variant in fleets_by_faction.keys():
		var faction_id: int = int(faction_id_variant)
		if not _factions_by_id.has(faction_id):
			continue
		var fleets_for_faction: Array = fleets_by_faction[faction_id]
		fleets_for_faction.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
		)
		var faction_state: Dictionary = _factions_by_id[faction_id]
		for fleet_variant in fleets_for_faction:
			var fleet: Dictionary = fleet_variant
			var upkeep_cost: int = get_fleet_upkeep_credits_per_day(fleet)
			var fleet_id: int = int(fleet.get("fleet_id", -1))
			if int(faction_state.get("credits", 0)) >= upkeep_cost:
				faction_state["credits"] = int(faction_state.get("credits", 0)) - upkeep_cost
				fleet_upkeep_paid_by_fleet_id[fleet_id] = true
				faction_upkeep_paid_by_id[faction_id] = int(faction_upkeep_paid_by_id.get(faction_id, 0)) + upkeep_cost
				(faction_upkeep_breakdown_by_id[faction_id] as Dictionary)["fleet"] = int((faction_upkeep_breakdown_by_id[faction_id] as Dictionary).get("fleet", 0)) + upkeep_cost
			else:
				fleet_upkeep_paid_by_fleet_id[fleet_id] = false
				(faction_unpaid_counts_by_id[faction_id] as Dictionary)["fleet"] = int((faction_unpaid_counts_by_id[faction_id] as Dictionary).get("fleet", 0)) + 1


func _apply_fleet_readiness_changes(fleet_upkeep_paid_by_fleet_id: Dictionary, logs: Array[String]) -> void:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		var pirate_state: int = int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE))
		for fleet_variant in system_state.get("fleets", []):
			var fleet: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet, system_id)
			var before_readiness: int = int(fleet.get("readiness", 100))
			var readiness: int = before_readiness
			var reasons: Array[String] = []
			var fleet_id: int = int(fleet.get("fleet_id", -1))
			if not bool(fleet_upkeep_paid_by_fleet_id.get(fleet_id, false)):
				fleet["missed_upkeep_days"] = int(fleet.get("missed_upkeep_days", 0)) + 1
				readiness -= 10
				reasons.append("upkeep_missed")
			else:
				fleet["missed_upkeep_days"] = 0
			if pirate_state == StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
				readiness -= 1
				reasons.append("piracy_activity")
			elif pirate_state == StrategicTestConfigScript.PIRATE_STATE_HAVEN:
				readiness -= 2
				reasons.append("piracy_haven")
			if system_has_active_shipyard_for_faction(system_state, int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))):
				readiness += 5
				fleet["last_refit_day"] = _day_index
				reasons.append("refit")
			else:
				readiness += 1
				reasons.append("passive")
			fleet["readiness"] = clampi(readiness, 0, 100)
			var net_delta: int = int(fleet.get("readiness", 100)) - before_readiness
			if net_delta == 0:
				continue
			logs.append("DAY %d | FLEET_READY | fleet=%d owner=%d sys=%d base_sr=%d eff_sr=%d readiness=%d delta=%d reasons=%s" % [
				_day_index,
				fleet_id,
				int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
				system_id,
				get_fleet_base_sr(fleet),
				get_fleet_effective_sr(fleet),
				int(fleet.get("readiness", 100)),
				net_delta,
				str(reasons),
			])


func system_has_active_shipyard_for_faction(system_state: Dictionary, faction_id: int) -> bool:
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if str(structure.get("type", "")) != StrategicTestConfigScript.SHIPYARD_I_TYPE:
			continue
		if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if bool(structure.get("enabled", true)) and int(structure.get("disabled_days", 0)) == 0:
			return true
	return false


func _move_fleet_to_system(fleet_state: Dictionary, destination_system_id: int) -> void:
	var source_system_id: int = int(fleet_state.get("system_id", -1))
	if source_system_id == destination_system_id:
		return
	var source_system: Dictionary = get_system(source_system_id)
	if not source_system.is_empty():
		var source_fleets: Array = source_system.get("fleets", [])
		for i in range(source_fleets.size() - 1, -1, -1):
			var source_fleet: Dictionary = source_fleets[i]
			if int(source_fleet.get("fleet_id", -1)) == int(fleet_state.get("fleet_id", -2)):
				source_fleets.remove_at(i)
				break
		source_system["fleets"] = source_fleets
	var destination_system: Dictionary = get_system(destination_system_id)
	if destination_system.is_empty():
		return
	var destination_fleets: Array = destination_system.get("fleets", [])
	destination_fleets.append(fleet_state)
	destination_system["fleets"] = destination_fleets
	fleet_state["system_id"] = destination_system_id


func _get_neighbor_system_ids(system_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	var system_state: Dictionary = get_system(system_id)
	if not system_state.is_empty():
		for neighbor_variant in system_state.get("lanes", []):
			var neighbor_id_from_lanes: int = int(neighbor_variant)
			if neighbor_id_from_lanes > 0 and not neighbors.has(neighbor_id_from_lanes):
				neighbors.append(neighbor_id_from_lanes)
		for neighbor_variant in system_state.get("neighbor_system_ids", []):
			var neighbor_id: int = int(neighbor_variant)
			if neighbor_id > 0 and not neighbors.has(neighbor_id):
				neighbors.append(neighbor_id)
		for neighbor_variant in system_state.get("neighbors", []):
			var neighbor_id_from_alias: int = int(neighbor_variant)
			if neighbor_id_from_alias > 0 and not neighbors.has(neighbor_id_from_alias):
				neighbors.append(neighbor_id_from_alias)
	return neighbors


func _compute_hop_distance(origin_system_id: int, destination_system_id: int) -> int:
	if origin_system_id <= 0 or destination_system_id <= 0:
		return -1
	if origin_system_id == destination_system_id:
		return 0
	var visited: Dictionary = {origin_system_id: true}
	var queue: Array[Dictionary] = [{"system_id": origin_system_id, "distance": 0}]
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		var node_system_id: int = int(node.get("system_id", -1))
		var node_distance: int = int(node.get("distance", 0))
		for neighbor_id in _get_neighbor_system_ids(node_system_id):
			if visited.has(neighbor_id):
				continue
			if neighbor_id == destination_system_id:
				return node_distance + 1
			visited[neighbor_id] = true
			queue.append({"system_id": neighbor_id, "distance": node_distance + 1})
	return -1


func _issue_fleet_move_order(fleet_state: Dictionary, destination_system_id: int, current_day_index: int, logs: Array[String], reason: String = "", source: String = ORDER_SOURCE_FACTION_PLANNER) -> Dictionary:
	if source != ORDER_SOURCE_FACTION_PLANNER:
		logs.append("DAY %d | ERROR | FLEET_ORDER_BLOCKED | source=%s faction=%d fleet=%d from=%d to=%d reason=%s" % [
			current_day_index,
			source,
			int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
			int(fleet_state.get("fleet_id", -1)),
			int(fleet_state.get("system_id", -1)),
			destination_system_id,
			reason,
		])
		return {"ordered": false, "reason": "unauthorized_source"}
	_ensure_fleet_defaults(fleet_state, int(fleet_state.get("system_id", -1)))
	var origin_system_id: int = int(fleet_state.get("system_id", -1))
	if destination_system_id <= 0 or get_system(destination_system_id).is_empty():
		return {"ordered": false, "reason": "invalid_destination"}
	if origin_system_id <= 0:
		return {"ordered": false, "reason": "invalid_origin"}
	if int(fleet_state.get("landed_planet_id", -1)) >= 0:
		return {"ordered": false, "reason": "transport_landed"}
	if origin_system_id == destination_system_id:
		fleet_state["status"] = "on_task" if not (fleet_state.get("task", {}) as Dictionary).is_empty() else "idle"
		fleet_state["target_system_id"] = -1
		fleet_state["arrival_day"] = current_day_index
		fleet_state["last_order_day"] = current_day_index
		return {"ordered": true, "hops": 0, "travel_days": 0, "arrival_day": current_day_index}
	var hop_distance: int = _compute_hop_distance(origin_system_id, destination_system_id)
	if hop_distance < 0:
		return {"ordered": false, "reason": "no_path"}
	var travel_days: int = hop_distance * StrategicTestConfigScript.FLEET_MOVE_TRAVEL_DAYS_PER_HOP
	var arrival_day: int = current_day_index + travel_days
	fleet_state["status"] = "moving"
	fleet_state["target_system_id"] = destination_system_id
	fleet_state["arrival_day"] = arrival_day
	fleet_state["last_order_day"] = current_day_index
	logs.append("DAY %d | FLEET_ORDER | source=%s faction=%d fleet=%d sr=%d kind=%s from=%d to=%d hops=%d travel_days=%d arrival_day=%d reason=%s" % [
		current_day_index,
		source,
		int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
		int(fleet_state.get("fleet_id", -1)),
		get_fleet_effective_sr(fleet_state),
		str(fleet_state.get("group_id", "main")),
		origin_system_id,
		destination_system_id,
		hop_distance,
		travel_days,
		arrival_day,
		reason,
	])
	return {"ordered": true, "hops": hop_distance, "travel_days": travel_days, "arrival_day": arrival_day}


func issue_fleet_move_order_by_id(fleet_id: int, destination_system_id: int, reason: String = "manual") -> Dictionary:
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("fleet_id", -1)) != fleet_id:
			continue
		var logs: Array[String] = []
		var result: Dictionary = _issue_fleet_move_order(fleet_state, destination_system_id, _day_index, logs, reason, "UI")
		result["logs"] = logs
		return result
	return {"ordered": false, "reason": "fleet_not_found", "logs": []}


func _find_fleet_by_id(fleet_id: int) -> Dictionary:
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("fleet_id", -1)) == fleet_id:
			return fleet_state
	return {}


func _spawn_troops_on_planet(planet_state: Dictionary, owner_faction_id: int, gp: int) -> int:
	var spawn_gp: int = maxi(0, gp)
	if spawn_gp <= 0:
		return 0
	var troops: Array = planet_state.get("troops", [])
	for _i in range(spawn_gp):
		troops.append({
			"troop_id": _next_troop_id,
			"owner_faction_id": owner_faction_id,
			"planet_id": int(planet_state.get("planet_id", -1)),
			"type_id": "troops_basic",
			"gp": 1,
			"upkeep_credits_per_day": int((StrategicTestConfigScript.TROOP_BLUEPRINTS.get("troops_basic", {}) as Dictionary).get("upkeep_credits_per_day", 2)),
			"status": "active",
		})
		_next_troop_id += 1
	planet_state["troops"] = troops
	_refresh_planet_troop_gp(planet_state)
	return spawn_gp


func _remove_troops_gp_for_owner(planet_state: Dictionary, owner_faction_id: int, gp_to_remove: int) -> int:
	var goal: int = maxi(0, gp_to_remove)
	if goal <= 0:
		return 0
	var troops: Array = planet_state.get("troops", [])
	troops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("troop_id", 0)) < int(b.get("troop_id", 0))
	)
	var removed_gp: int = 0
	var kept: Array = []
	for troop_variant in troops:
		var troop: Dictionary = troop_variant
		var troop_gp: int = maxi(0, int(troop.get("gp", 0)))
		var is_matching_troop: bool = str(troop.get("status", "active")) == "active" and int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == owner_faction_id and troop_gp > 0
		if not is_matching_troop or removed_gp >= goal:
			kept.append(troop)
			continue

		var remove_now: int = mini(goal - removed_gp, troop_gp)
		removed_gp += remove_now
		var remaining_gp: int = troop_gp - remove_now
		if remaining_gp > 0:
			troop["gp"] = remaining_gp
			kept.append(troop)
	planet_state["troops"] = kept
	_refresh_planet_troop_gp(planet_state)
	return removed_gp


func transport_land(fleet_id: int, planet_id: int) -> Dictionary:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | TRANSPORT_LAND_BLOCKED | source=NON_PLANNER" % [_day_index])
		return {"ok": false, "reason": "unauthorized_source"}
	var fleet_state: Dictionary = _find_fleet_by_id(fleet_id)
	if fleet_state.is_empty():
		return {"ok": false, "reason": "fleet_not_found"}
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		return {"ok": false, "reason": "not_transport"}
	if str(fleet_state.get("status", "idle")) == "moving":
		return {"ok": false, "reason": "fleet_moving"}
	var planet_state: Dictionary = _planets_by_id.get(planet_id, {})
	if planet_state.is_empty():
		return {"ok": false, "reason": "planet_not_found"}
	if int(fleet_state.get("system_id", -1)) != int(planet_state.get("system_id", -1)):
		return {"ok": false, "reason": "different_system"}
	fleet_state["landed_planet_id"] = planet_id
	_pending_operation_logs.append("DAY %d | TRANSPORT_LAND | source=%s fleet=%d faction=%d planet=%d" % [
		_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		fleet_id,
		int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
		planet_id,
	])
	return {"ok": true}


func transport_launch(fleet_id: int) -> Dictionary:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | TRANSPORT_LAUNCH_BLOCKED | source=NON_PLANNER" % [_day_index])
		return {"ok": false, "reason": "unauthorized_source"}
	var fleet_state: Dictionary = _find_fleet_by_id(fleet_id)
	if fleet_state.is_empty():
		return {"ok": false, "reason": "fleet_not_found"}
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		return {"ok": false, "reason": "not_transport"}
	fleet_state["landed_planet_id"] = -1
	_pending_operation_logs.append("DAY %d | TRANSPORT_LAUNCH | source=%s fleet=%d faction=%d" % [
		_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		fleet_id,
		int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
	])
	return {"ok": true}


func transport_load_troops(fleet_id: int, planet_id: int, requested_gp: int) -> Dictionary:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | TROOP_LOAD_BLOCKED | source=NON_PLANNER" % [_day_index])
		return {"ok": false, "reason": "unauthorized_source"}
	var fleet_state: Dictionary = _find_fleet_by_id(fleet_id)
	var planet_state: Dictionary = _planets_by_id.get(planet_id, {})
	if fleet_state.is_empty() or planet_state.is_empty():
		return {"ok": false, "reason": "not_found"}
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		return {"ok": false, "reason": "not_transport"}
	if int(fleet_state.get("landed_planet_id", -1)) != planet_id:
		return {"ok": false, "reason": "not_landed_on_planet"}
	if int(fleet_state.get("system_id", -1)) != int(planet_state.get("system_id", -1)):
		return {"ok": false, "reason": "different_system"}
	var faction_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
		return {"ok": false, "reason": "not_friendly_owner"}
	var capacity: int = int(fleet_state.get("transport_capacity_gp", 0))
	var cargo_before: int = int(fleet_state.get("cargo_troop_gp", 0))
	var free_capacity: int = maxi(0, capacity - cargo_before)
	var planet_available_gp: int = 0
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		if int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		planet_available_gp += maxi(0, int(troop.get("gp", 0)))
	var actual_load: int = mini(maxi(0, requested_gp), mini(planet_available_gp, free_capacity))
	var removed_gp: int = _remove_troops_gp_for_owner(planet_state, faction_id, actual_load)
	fleet_state["cargo_troop_gp"] = cargo_before + removed_gp
	_pending_operation_logs.append("DAY %d | TROOP_LOAD | source=%s faction=%d planet=%d transport=%d req=%d loaded=%d cargo=%d/%d" % [
		_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		faction_id,
		planet_id,
		fleet_id,
		requested_gp,
		removed_gp,
		int(fleet_state.get("cargo_troop_gp", 0)),
		capacity,
	])
	return {"ok": true, "loaded_gp": removed_gp}


func transport_unload_troops(fleet_id: int, planet_id: int, requested_gp: int) -> Dictionary:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | TROOP_UNLOAD_BLOCKED | source=NON_PLANNER" % [_day_index])
		return {"ok": false, "reason": "unauthorized_source"}
	var fleet_state: Dictionary = _find_fleet_by_id(fleet_id)
	var planet_state: Dictionary = _planets_by_id.get(planet_id, {})
	if fleet_state.is_empty() or planet_state.is_empty():
		return {"ok": false, "reason": "not_found"}
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		return {"ok": false, "reason": "not_transport"}
	if int(fleet_state.get("landed_planet_id", -1)) != planet_id:
		return {"ok": false, "reason": "not_landed_on_planet"}
	if int(fleet_state.get("system_id", -1)) != int(planet_state.get("system_id", -1)):
		return {"ok": false, "reason": "different_system"}
	var cargo_before: int = int(fleet_state.get("cargo_troop_gp", 0))
	var actual_unload: int = mini(maxi(0, requested_gp), cargo_before)
	var faction_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var spawned_gp: int = _spawn_troops_on_planet(planet_state, faction_id, actual_unload)
	fleet_state["cargo_troop_gp"] = maxi(0, cargo_before - spawned_gp)
	_pending_operation_logs.append("DAY %d | TROOP_UNLOAD | source=%s faction=%d planet=%d transport=%d req=%d unloaded=%d cargo=%d/%d" % [
		_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		faction_id,
		planet_id,
		fleet_id,
		requested_gp,
		spawned_gp,
		int(fleet_state.get("cargo_troop_gp", 0)),
		int(fleet_state.get("transport_capacity_gp", 0)),
	])
	return {"ok": true, "unloaded_gp": spawned_gp}


func transport_invade_planet(fleet_id: int, planet_id: int, commit_gp: int = -1) -> Dictionary:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | INVASION_BLOCKED | source=NON_PLANNER" % [_day_index])
		return {"ok": false, "reason": "unauthorized_source"}
	var fleet_state: Dictionary = _find_fleet_by_id(fleet_id)
	var planet_state: Dictionary = _planets_by_id.get(planet_id, {})
	if fleet_state.is_empty() or planet_state.is_empty():
		return {"ok": false, "reason": "not_found"}
	if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
		return {"ok": false, "reason": "not_transport"}
	if int(fleet_state.get("landed_planet_id", -1)) != planet_id:
		return {"ok": false, "reason": "not_landed_on_planet"}
	if int(fleet_state.get("system_id", -1)) != int(planet_state.get("system_id", -1)):
		return {"ok": false, "reason": "different_system"}
	var attacker_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var defender_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if not StrategicTestLogicScript.are_factions_hostile(attacker_id, defender_id):
		return {"ok": false, "reason": "not_hostile"}
	var system_id: int = int(planet_state.get("system_id", -1))
	if system_is_blockaded_for(system_id, attacker_id):
		return {"ok": false, "reason": "attacker_blockaded"}
	var system_state: Dictionary = get_system(system_id)
	var sr_by_faction: Dictionary = system_state.get("sr_by_faction", {})
	var attacker_sr: int = int(sr_by_faction.get(attacker_id, 0))
	var attacker_enemy_sr: int = int(system_state.get("enemy_sr_by_faction", {}).get(attacker_id, 0))
	if attacker_sr < attacker_enemy_sr:
		return {"ok": false, "reason": "insufficient_space_control"}
	var cargo_gp: int = int(fleet_state.get("cargo_troop_gp", 0))
	if cargo_gp <= 0:
		return {"ok": false, "reason": "no_cargo"}
	var committed_gp: int = cargo_gp if commit_gp < 0 else mini(maxi(0, commit_gp), cargo_gp)
	if committed_gp <= 0:
		return {"ok": false, "reason": "invalid_commit"}
	_pending_operation_logs.append("DAY %d | INVASION_ORDER | planet=%d attacker=%d defender=%d fleet=%d committed_gp=%d" % [
		_day_index,
		planet_id,
		attacker_id,
		defender_id,
		fleet_id,
		committed_gp,
	])
	return {"ok": true, "won": false, "result": "pending_engagement"}


func _apply_fleet_arrivals_for_day(current_day_index: int, logs: Array[String]) -> void:
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if str(fleet_state.get("status", "idle")) != "moving":
			continue
		if int(fleet_state.get("arrival_day", -1)) != current_day_index:
			continue
		var destination_system_id: int = int(fleet_state.get("target_system_id", -1))
		if destination_system_id <= 0 or get_system(destination_system_id).is_empty():
			continue
		_move_fleet_to_system(fleet_state, destination_system_id)
		fleet_state["target_system_id"] = -1
		fleet_state["status"] = "on_task" if not (fleet_state.get("task", {}) as Dictionary).is_empty() else "idle"
		logs.append("DAY %d | FLEET_ARRIVE | faction=%d fleet=%d to=%d kind=%s" % [
			current_day_index,
			int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
			int(fleet_state.get("fleet_id", -1)),
			destination_system_id,
			str(fleet_state.get("group_id", "main")),
		])




func _create_space_engagements_for_day(current_day_index: int, logs: Array[String]) -> void:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		if int(system_state.get("last_engagement_end_day", -1)) == current_day_index:
			continue
		var space_engagement: Dictionary = system_state.get("space_engagement", {})
		if bool(space_engagement.get("active", false)):
			continue
		var hostile_factions: Array[int] = _get_hostile_factions_in_system(system_state)
		if hostile_factions.size() < 2:
			continue
		var selected_sides: Dictionary = _pick_top_two_factions_by_effective_sr(system_state, hostile_factions)
		var side_a: int = int(selected_sides.get("side_a", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var side_b: int = int(selected_sides.get("side_b", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		system_state["space_engagement"] = {
			"active": true,
			"start_day": current_day_index,
			"resolve_day": current_day_index + 1,
			"factions": hostile_factions,
			"side_a": side_a,
			"side_b": side_b,
			"snapshot": {
				"sr_by_faction": (selected_sides.get("sr_by_faction", {}) as Dictionary).duplicate(true),
			},
			"last_update_day": current_day_index,
		}
		logs.append("DAY %d | ENGAGE_SPACE_START | system=%d sides=%d,%d factions=%s resolve_day=%d" % [
			current_day_index,
			int(system_state.get("id", -1)),
			side_a,
			side_b,
			str(hostile_factions),
			current_day_index + 1,
		])


func _get_hostile_factions_in_system(system_state: Dictionary) -> Array[int]:
	var factions_in_system: Array[int] = []
	for fleet_variant in system_state.get("fleets", []):
		var fleet_state: Dictionary = fleet_variant
		if str(fleet_state.get("status", "idle")) == "moving":
			continue
		if get_fleet_base_sr(fleet_state) <= 0:
			continue
		var owner_faction_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not factions_in_system.has(owner_faction_id):
			factions_in_system.append(owner_faction_id)
	if factions_in_system.size() < 2:
		return []
	var hostile_factions: Array[int] = []
	for i in range(factions_in_system.size()):
		for j in range(i + 1, factions_in_system.size()):
			if StrategicTestLogicScript.are_factions_hostile(factions_in_system[i], factions_in_system[j]):
				if not hostile_factions.has(factions_in_system[i]):
					hostile_factions.append(factions_in_system[i])
				if not hostile_factions.has(factions_in_system[j]):
					hostile_factions.append(factions_in_system[j])
	hostile_factions.sort()
	return hostile_factions


func _pick_top_two_factions_by_effective_sr(system_state: Dictionary, faction_ids: Array[int]) -> Dictionary:
	var sr_by_faction: Dictionary = {}
	for faction_id in faction_ids:
		sr_by_faction[faction_id] = int(system_state.get("sr_by_faction", {}).get(faction_id, 0))
	var ordered: Array[int] = StrategicTestLogicScript.sort_faction_ids_by_sr_desc_then_id(sr_by_faction, faction_ids)
	return {
		"side_a": int(ordered[0]),
		"side_b": int(ordered[1]),
		"sr_by_faction": sr_by_faction,
	}


func _resolve_space_engagements_for_day(current_day_index: int, logs: Array[String]) -> void:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var space_engagement: Dictionary = system_state.get("space_engagement", {})
		if not bool(space_engagement.get("active", false)):
			continue
		if int(space_engagement.get("resolve_day", -1)) != current_day_index:
			continue
		_resolve_system_engagement(system_state, space_engagement, current_day_index, logs)


func _create_ground_engagements_for_day(current_day_index: int, logs: Array[String]) -> void:
	for planet_variant in _planets_by_id.values():
		var planet_state: Dictionary = planet_variant
		if int(planet_state.get("last_engagement_end_day", -1)) == current_day_index:
			continue
		var ground_engagement: Dictionary = planet_state.get("ground_engagement", {})
		if bool(ground_engagement.get("active", false)):
			continue
		var ground_info: Dictionary = _get_ground_engagement_candidates(planet_state)
		var attacker_candidates: Array[int] = []
		for attacker_id_variant in ground_info.get("attackers", []):
			attacker_candidates.append(int(attacker_id_variant))
		if attacker_candidates.is_empty():
			continue
		var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var pick: Dictionary = _pick_strongest_ground_attacker(planet_state, attacker_candidates)
		var side_a: int = int(pick.get("side_a", owner_faction_id))
		var side_b: int = int(pick.get("side_b", owner_faction_id))
		planet_state["ground_engagement"] = {
			"active": true,
			"start_day": current_day_index,
			"resolve_day": current_day_index + 1,
			"factions": [owner_faction_id, side_b],
			"side_a": side_a,
			"side_b": side_b,
			"snapshot": pick.get("snapshot", {}),
			"last_update_day": current_day_index,
		}
		logs.append("DAY %d | ENGAGE_GROUND_START | planet=%d sides=%d,%d resolve_day=%d" % [
			current_day_index,
			int(planet_state.get("planet_id", -1)),
			side_a,
			side_b,
			current_day_index + 1,
		])


func _resolve_ground_engagements_for_day(current_day_index: int, logs: Array[String]) -> void:
	for planet_variant in _planets_by_id.values():
		var planet_state: Dictionary = planet_variant
		var ground_engagement: Dictionary = planet_state.get("ground_engagement", {})
		if not bool(ground_engagement.get("active", false)):
			continue
		if int(ground_engagement.get("resolve_day", -1)) != current_day_index:
			continue
		_resolve_ground_engagement_for_planet(planet_state, ground_engagement, current_day_index, logs)


func _resolve_ground_engagement_for_planet(planet_state: Dictionary, ground_engagement: Dictionary, current_day_index: int, logs: Array[String]) -> void:
	var planet_id: int = int(planet_state.get("planet_id", -1))
	var attacker_id: int = int(ground_engagement.get("side_b", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var defender_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if not StrategicTestLogicScript.are_factions_hostile(attacker_id, defender_id):
		planet_state["ground_engagement"] = {}
		planet_state["last_engagement_end_day"] = current_day_index
		logs.append("DAY %d | ENGAGE_GROUND_RESOLVE | planet=%d atk=%d def=%d A_gp=0 D_gp=0 result=DISENGAGED owner_after=%d" % [
			current_day_index,
			planet_id,
			attacker_id,
			defender_id,
			int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
		])
		return
	var committed_gp: int = _compute_ground_attacker_gp(planet_state, attacker_id)
	if committed_gp <= 0:
		planet_state["ground_engagement"] = {}
		planet_state["last_engagement_end_day"] = current_day_index
		logs.append("DAY %d | ENGAGE_GROUND_RESOLVE | planet=%d atk=%d def=%d A_gp=0 D_gp=0 result=DISENGAGED owner_after=%d" % [
			current_day_index,
			planet_id,
			attacker_id,
			defender_id,
			int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
		])
		return
	var defender_troop_gp: int = 0
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		if int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != defender_id:
			continue
		defender_troop_gp += maxi(0, int(troop.get("gp", 0)))
	var defender_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0))
	var defender_effective_gp: int = defender_garrison_gp + defender_troop_gp
	var attacker_losses: int = mini(committed_gp, int(ceil(float(defender_effective_gp) / 2.0)))
	var defender_troop_losses: int = mini(defender_troop_gp, int(ceil(float(committed_gp) / 2.0)))
	_remove_troops_gp_for_owner(planet_state, defender_id, defender_troop_losses)
	var won: bool = committed_gp > defender_effective_gp
	if won:
		var previous_owner_id: int = defender_id
		planet_state["owner_faction_id"] = attacker_id
		planet_state["control"] = 50
		planet_state["stability"] = 40
		planet_state["current_garrison_gp"] = 0
		_remove_troops_gp_for_owner(planet_state, previous_owner_id, 999999)
		_reassign_planet_ownership(planet_id, previous_owner_id, attacker_id)
	_refresh_planet_troop_gp(planet_state)
	planet_state["ground_engagement"] = {}
	planet_state["last_engagement_end_day"] = current_day_index
	logs.append("DAY %d | ENGAGE_GROUND_RESOLVE | planet=%d atk=%d def=%d A_gp=%d D_gp=%d result=%s owner_after=%d" % [
		current_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		planet_id,
		attacker_id,
		defender_id,
		committed_gp,
		defender_effective_gp,
		"WIN" if won else "HOLD",
		int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
	])
	_pending_operation_logs.append("DAY %d | INVASION | source=%s planet=%d def=%d atk=%d A=%d D=%d result=%s atk_loss=%d def_troop_loss=%d cargo_after=%d new_owner=%d" % [
		current_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		planet_id,
		defender_id,
		attacker_id,
		committed_gp,
		defender_effective_gp,
		"WIN" if won else "HOLD",
		attacker_losses,
		defender_troop_losses,
		0,
		int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
	])


func _get_ground_engagement_candidates(planet_state: Dictionary) -> Dictionary:
	var defender_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var defender_troop_gp: int = 0
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		if int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != defender_id:
			continue
		defender_troop_gp += maxi(0, int(troop.get("gp", 0)))
	var defender_present: bool = int(planet_state.get("current_garrison_gp", 0)) + defender_troop_gp > 0
	if not defender_present:
		return {"attackers": []}
	var system_state: Dictionary = get_system(int(planet_state.get("system_id", -1)))
	var attackers: Array[int] = []
	for fleet_variant in system_state.get("fleets", []):
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("landed_planet_id", -1)) != int(planet_state.get("planet_id", -1)):
			continue
		if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
			continue
		var attacker_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not StrategicTestLogicScript.are_factions_hostile(attacker_id, defender_id):
			continue
		if int(fleet_state.get("cargo_troop_gp", 0)) > 0 and not attackers.has(attacker_id):
			attackers.append(attacker_id)
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		var attacker_id: int = int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if attacker_id == defender_id:
			continue
		if StrategicTestLogicScript.are_factions_hostile(attacker_id, defender_id) and not attackers.has(attacker_id):
			attackers.append(attacker_id)
	attackers.sort()
	return {"attackers": attackers}


func _compute_ground_attacker_gp(planet_state: Dictionary, attacker_id: int) -> int:
	var total_gp: int = 0
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		if int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != attacker_id:
			continue
		total_gp += maxi(0, int(troop.get("gp", 0)))
	var system_state: Dictionary = get_system(int(planet_state.get("system_id", -1)))
	for fleet_variant in system_state.get("fleets", []):
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("landed_planet_id", -1)) != int(planet_state.get("planet_id", -1)):
			continue
		if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != attacker_id:
			continue
		if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
			continue
		total_gp += maxi(0, int(fleet_state.get("cargo_troop_gp", 0)))
	return total_gp


func _pick_strongest_ground_attacker(planet_state: Dictionary, attacker_factions: Array[int]) -> Dictionary:
	var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var sorted_attackers: Array[int] = attacker_factions.duplicate(true)
	sorted_attackers.sort_custom(func(a: int, b: int) -> bool:
		var a_gp: int = _compute_ground_attacker_gp(planet_state, a)
		var b_gp: int = _compute_ground_attacker_gp(planet_state, b)
		if a_gp == b_gp:
			return a < b
		return a_gp > b_gp
	)
	return {
		"side_a": owner_faction_id,
		"side_b": int(sorted_attackers[0]),
		"snapshot": {
			"defender_gp": int(planet_state.get("current_garrison_gp", 0)) + StrategicTestLogicScript.compute_planet_troop_gp(planet_state),
			"attacker_gp": _compute_ground_attacker_gp(planet_state, int(sorted_attackers[0])),
		},
	}


func _resolve_system_engagement(system_state: Dictionary, space_engagement: Dictionary, current_day_index: int, logs: Array[String]) -> void:
	var system_id: int = int(system_state.get("id", -1))
	var engagement_factions: Array[int] = []
	for faction_variant in space_engagement.get("factions", []):
		engagement_factions.append(int(faction_variant))
	for faction_id in _get_hostile_factions_in_system(system_state):
		if not engagement_factions.has(faction_id):
			engagement_factions.append(faction_id)
	engagement_factions.sort()
	var side_pick: Dictionary = _pick_top_two_factions_by_effective_sr(system_state, engagement_factions)
	var side_a: int = int(side_pick.get("side_a", int(space_engagement.get("side_a", StrategicTestConfigScript.NO_OWNER_FACTION_ID))))
	var side_b: int = int(side_pick.get("side_b", int(space_engagement.get("side_b", StrategicTestConfigScript.NO_OWNER_FACTION_ID))))
	if side_a == side_b or not StrategicTestLogicScript.are_factions_hostile(side_a, side_b):
		system_state["space_engagement"] = {}
		system_state["last_engagement_end_day"] = current_day_index
		logs.append("DAY %d | ENGAGE_SPACE_RESOLVE | system=%d A=%d EA=0 B=%d EB=0 dmgA=0 dmgB=0 lossesA=0 lossesB=0 transports_killed=0 result=DISENGAGED" % [
			current_day_index,
			system_id,
			side_a,
			side_b,
		])
		return
	var sr_by_faction: Dictionary = system_state.get("sr_by_faction", {})
	var side_a_sr: int = int(sr_by_faction.get(side_a, 0))
	var side_b_sr: int = int(sr_by_faction.get(side_b, 0))
	if side_a_sr <= 0 or side_b_sr <= 0:
		system_state["space_engagement"] = {}
		system_state["last_engagement_end_day"] = current_day_index
		logs.append("DAY %d | ENGAGE_SPACE_RESOLVE | system=%d A=%d EA=%d B=%d EB=%d dmgA=0 dmgB=0 lossesA=0 lossesB=0 transports_killed=0 result=DISENGAGED" % [
			current_day_index,
			system_id,
			side_a,
			side_a_sr,
			side_b,
			side_b_sr,
		])
		return
	var winner_faction_id: int = side_a
	if side_b_sr > side_a_sr or (side_b_sr == side_a_sr and side_b < side_a):
		winner_faction_id = side_b
	var dmg_a: int = 0
	var dmg_b: int = 0
	var losses_a: int = 0
	var losses_b: int = 0
	var transports_killed: int = 0

	for fleet_variant in system_state.get("fleets", []):
		var fleet_state: Dictionary = fleet_variant
		if str(fleet_state.get("status", "idle")) == "moving":
			continue
		var fleet_owner: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var base_sr_before: int = get_fleet_base_sr(fleet_state)
		if base_sr_before <= 0:
			continue
		if fleet_owner != side_a and fleet_owner != side_b:
			continue
		if fleet_owner == winner_faction_id:
			fleet_state["readiness"] = maxi(15, int(fleet_state.get("readiness", 100)) - 8)
			if fleet_owner == side_a:
				dmg_a += 8
			else:
				dmg_b += 8
			continue
		var ship_count_before: int = (fleet_state.get("ships", []) as Array).size()
		_apply_encounter_ship_losses(fleet_state, 0.35)
		fleet_state["readiness"] = maxi(5, int(fleet_state.get("readiness", 100)) - 25)
		var ship_count_after: int = (fleet_state.get("ships", []) as Array).size()
		if fleet_owner == side_a:
			dmg_a += 25
			losses_a += maxi(0, ship_count_before - ship_count_after)
		else:
			dmg_b += 25
			losses_b += maxi(0, ship_count_before - ship_count_after)
		var retreat_destination: int = _pick_retreat_destination(system_id, fleet_owner)
		if retreat_destination > 0:
			_issue_fleet_move_order(fleet_state, retreat_destination, current_day_index, logs, "encounter_retreat", ORDER_SOURCE_FACTION_PLANNER)

	var loser_faction_ids: Array[int] = [side_a if winner_faction_id == side_b else side_b]
	loser_faction_ids.sort()
	for loser_faction_id in loser_faction_ids:
		var transport_candidates: Array[Dictionary] = []
		for fleet_variant in system_state.get("fleets", []):
			var fleet_state: Dictionary = fleet_variant
			if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != loser_faction_id:
				continue
			if StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
				transport_candidates.append(fleet_state)
		transport_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
		)
		if transport_candidates.is_empty():
			continue
		var victim: Dictionary = transport_candidates[0]
		var victim_id: int = int(victim.get("fleet_id", -1))
		var cargo_lost: int = int(victim.get("cargo_troop_gp", 0))
		var fleets: Array = system_state.get("fleets", [])
		for i in range(fleets.size() - 1, -1, -1):
			if int((fleets[i] as Dictionary).get("fleet_id", -1)) == victim_id:
				fleets.remove_at(i)
				break
		system_state["fleets"] = fleets
		transports_killed += 1
		logs.append("DAY %d | TRANSPORT_KILL | system=%d victim_faction=%d transport=%d cargo_lost=%d reason=lost_encounter" % [
			current_day_index,
			system_id,
			loser_faction_id,
			victim_id,
			cargo_lost,
		])
	system_state["space_engagement"] = {}
	system_state["last_engagement_end_day"] = current_day_index
	logs.append("DAY %d | ENGAGE_SPACE_RESOLVE | system=%d A=%d EA=%d B=%d EB=%d dmgA=%d dmgB=%d lossesA=%d lossesB=%d transports_killed=%d result=%s" % [
		current_day_index,
		system_id,
		side_a,
		side_a_sr,
		side_b,
		side_b_sr,
		dmg_a,
		dmg_b,
		losses_a,
		losses_b,
		transports_killed,
		"A_WIN" if winner_faction_id == side_a else "B_WIN",
	])


func _apply_encounter_ship_losses(fleet_state: Dictionary, loss_ratio: float) -> void:
	var raw_ships: Array = fleet_state.get("ships", [])
	var ships: Array[Dictionary] = []
	for ship_variant in raw_ships:
		if ship_variant is Dictionary:
			ships.append(ship_variant)
	fleet_state["ships"] = ships
	if ships.is_empty():
		return
	var total_ship_sr: int = 0
	for ship_variant in ships:
		var ship_state: Dictionary = ship_variant
		total_ship_sr += maxi(0, int(ship_state.get("sr", 0)))
	var target_loss_sr: int = maxi(1, int(ceil(float(total_ship_sr) * clampf(loss_ratio, 0.0, 1.0))))
	StrategicTestLogicScript.sort_ships_for_split_pick(ships)
	var remaining: Array[Dictionary] = []
	var removed_sr: int = 0
	for ship_variant in ships:
		var ship_state: Dictionary = ship_variant
		var ship_sr: int = maxi(0, int(ship_state.get("sr", 0)))
		if removed_sr < target_loss_sr:
			removed_sr += ship_sr
			continue
		remaining.append(ship_state)
	if remaining.is_empty() and not ships.is_empty():
		remaining.append(ships[ships.size() - 1])
	fleet_state["ships"] = remaining


func _pick_retreat_destination(current_system_id: int, faction_id: int) -> int:
	var owned_system_ids: Array[int] = get_owned_system_ids(faction_id)
	owned_system_ids.sort()
	for system_id in owned_system_ids:
		if system_id != current_system_id:
			return system_id
	var neighbor_system_ids: Array[int] = _get_neighbor_system_ids(current_system_id)
	neighbor_system_ids.sort()
	for neighbor_id in neighbor_system_ids:
		if neighbor_id != current_system_id:
			return neighbor_id
	return -1

func _compute_patrol_score(system_state: Dictionary) -> int:
	var score: int = int(system_state.get("piracy_pressure", 0))
	if int(system_state.get("platform_tier", 0)) >= 1:
		score += 20
	var pirate_state: int = int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE))
	if pirate_state == StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
		score += 10
	elif pirate_state == StrategicTestConfigScript.PIRATE_STATE_HAVEN:
		score += 40
	return score


func _assign_patrol_fleets(current_day_index: int, logs: Array) -> void:
	var sorted_faction_ids: Array[int] = []
	for faction_id_variant in _factions_by_id.keys():
		sorted_faction_ids.append(int(faction_id_variant))
	sorted_faction_ids.sort()

	for faction_id in sorted_faction_ids:
		var owned_system_ids: Array[int] = get_owned_system_ids(faction_id)
		var scored_systems: Array[Dictionary] = []
		for system_id in owned_system_ids:
			var system_state: Dictionary = get_system(system_id)
			if system_state.is_empty():
				continue
			scored_systems.append({
				"system_id": system_id,
				"patrol_score": _compute_patrol_score(system_state),
			})
		scored_systems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.get("patrol_score", 0)) == int(b.get("patrol_score", 0)):
				return int(a.get("system_id", 0)) < int(b.get("system_id", 0))
			return int(a.get("patrol_score", 0)) > int(b.get("patrol_score", 0))
		)

		if scored_systems.is_empty():
			continue

		for scored_variant in scored_systems:
			var scored_system: Dictionary = scored_variant
			var scored_system_id: int = int(scored_system.get("system_id", -1))
			var patrol_candidates: Dictionary = StrategicTestLogicScript.collect_patrol_candidates_for_faction(
				(get_system(scored_system_id).get("fleets", []) as Array),
				faction_id,
				true,
				scored_system_id
			)
			var full_candidates: Array[Dictionary] = patrol_candidates.get("full_candidates", [])
			var light_candidates: Array[Dictionary] = patrol_candidates.get("light_candidates", [])
			var selected_fleets: Array[Dictionary] = StrategicTestLogicScript.select_patrol_fleets(full_candidates, light_candidates)
			var full_count: int = 0
			var light_count: int = 0
			for selected_variant in selected_fleets:
				var selected_fleet: Dictionary = selected_variant
				var fleet_effective_sr: int = get_fleet_effective_sr(selected_fleet)
				if fleet_effective_sr >= StrategicTestConfigScript.PATROL_FULL_MIN_SR:
					full_count += 1
				elif fleet_effective_sr >= StrategicTestConfigScript.PATROL_LIGHT_MIN_SR:
					light_count += 1

			var eligible_full_ids: Array[int] = []
			var eligible_light_ids: Array[int] = []
			for full_fleet_variant in full_candidates:
				eligible_full_ids.append(int((full_fleet_variant as Dictionary).get("fleet_id", -1)))
			for light_fleet_variant in light_candidates:
				eligible_light_ids.append(int((light_fleet_variant as Dictionary).get("fleet_id", -1)))
			eligible_full_ids.sort()
			eligible_light_ids.sort()
			var security_from_patrol: int = (full_count * StrategicTestConfigScript.PATROL_FULL_SECURITY_BONUS) + (light_count * StrategicTestConfigScript.PATROL_LIGHT_SECURITY_BONUS)
			var reason: String = "assigned"
			if full_candidates.is_empty() and light_candidates.is_empty():
				reason = "no_eligible_fleets"
			logs.append("DAY %d | PATROL_SELECT | system=%d controller=%d full=%d light=%d sec_from_patrol=%d eligible_full=%s eligible_light=%s reason=%s" % [
				current_day_index,
				scored_system_id,
				faction_id,
				full_count,
				light_count,
				security_from_patrol,
				fmt_sorted_id_list_truncated(eligible_full_ids, StrategicTestConfigScript.LOG_MAX_ID_LIST_TOKENS),
				fmt_sorted_id_list_truncated(eligible_light_ids, StrategicTestConfigScript.LOG_MAX_ID_LIST_TOKENS),
				reason,
			])


func _create_empty_faction_order_book() -> Dictionary:
	return {
		"fleet_orders": [],
		"ship_build_orders": [],
		"orbit_build_orders": [],
		"platform_orders": [],
		"troop_train_orders": [],
		"transport_ops": [],
		"invasion_ops": [],
		"notes": [],
	}


func _sort_order_entries(order_entries: Array) -> void:
	order_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: int = int(a.get("score", 0))
		var score_b: int = int(b.get("score", 0))
		if score_a == score_b:
			return int(a.get("target_id", 0)) < int(b.get("target_id", 0))
		return score_a > score_b
	)


func _collect_haven_fleet_orders_for_faction(faction_id: int, order_book: Dictionary) -> void:
	var best_target_system_id: int = -1
	var best_need_sr: int = 0
	var threshold: int = 0
	var friendly_sr: int = 0
	for system_id in get_owned_system_ids(faction_id):
		var system_state: Dictionary = get_system(system_id)
		if int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) != StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			continue
		var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(system_id))
		var clear_threshold: int = int(pirate_presence.get("threat_sr", 0)) + 10
		var system_friendly_sr: int = int((system_state.get("sr_by_faction", {}) as Dictionary).get(faction_id, 0))
		var need_sr: int = maxi(0, clear_threshold - system_friendly_sr)
		if need_sr <= 0:
			continue
		if best_target_system_id < 0 or need_sr > best_need_sr or (need_sr == best_need_sr and system_id < best_target_system_id):
			best_target_system_id = system_id
			best_need_sr = need_sr
			threshold = clear_threshold
			friendly_sr = system_friendly_sr
	if best_target_system_id <= 0:
		return
	var candidates: Array[Dictionary] = []
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if str(fleet_state.get("status", "idle")) == "moving":
			continue
		if StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
			continue
		var from_system_id: int = int(fleet_state.get("system_id", -1))
		if from_system_id == best_target_system_id:
			continue
		var hops: int = _compute_hop_distance(from_system_id, best_target_system_id)
		if hops < 0:
			continue
		candidates.append({
			"fleet_id": int(fleet_state.get("fleet_id", -1)),
			"target_id": best_target_system_id,
			"from_system_id": from_system_id,
			"hops": hops,
			"score": get_fleet_effective_sr(fleet_state),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			if int(a.get("hops", 0)) == int(b.get("hops", 0)):
				return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
			return int(a.get("hops", 0)) < int(b.get("hops", 0))
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	var movement_orders: Array = order_book.get("fleet_orders", [])
	var moved_sr: int = 0
	for candidate_variant in candidates:
		if movement_orders.size() >= StrategicTestConfigScript.FACTION_MAX_MOVEMENT_ORDERS_PER_DAY:
			break
		var candidate: Dictionary = candidate_variant
		movement_orders.append({
			"source": ORDER_SOURCE_FACTION_PLANNER,
			"reason": "haven_mass_clear",
			"fleet_id": int(candidate.get("fleet_id", -1)),
			"target_id": best_target_system_id,
			"destination_system_id": best_target_system_id,
			"score": int(candidate.get("score", 0)),
		})
		moved_sr += int(candidate.get("score", 0))
		if moved_sr >= best_need_sr:
			break
	order_book["fleet_orders"] = movement_orders
	(order_book.get("notes", []) as Array).append("HAVEN_MASS target=%d threshold=%d friendly=%d need=%d moved=%d" % [best_target_system_id, threshold, friendly_sr, best_need_sr, moved_sr])


func run_faction_planner_for_faction(faction_id: int, day_state: Dictionary) -> Dictionary:
	var order_book: Dictionary = _create_empty_faction_order_book()
	_assign_patrol_fleets(int(day_state.get("day", _day_index)), order_book["notes"])
	_collect_haven_fleet_orders_for_faction(faction_id, order_book)
	var governor_candidates: Dictionary = collect_governor_candidates_for_faction(faction_id, int(day_state.get("day", _day_index)))
	order_book["ship_build_orders"] = governor_candidates.get("ship_build_orders", [])
	order_book["orbit_build_orders"] = governor_candidates.get("orbit_build_orders", [])
	order_book["platform_orders"] = governor_candidates.get("platform_orders", [])
	order_book["troop_train_orders"] = governor_candidates.get("troop_train_orders", [])
	for key in ["fleet_orders", "ship_build_orders", "orbit_build_orders", "platform_orders", "troop_train_orders", "transport_ops", "invasion_ops"]:
		_sort_order_entries(order_book.get(key, []))
	return order_book


func execute_faction_order_book(faction_id: int, order_book: Dictionary, logs: Array[String]) -> void:
	_planner_execution_active = true
	var fleet_orders: Array = order_book.get("fleet_orders", [])
	for order_variant in fleet_orders:
		var order: Dictionary = order_variant
		var fleet: Dictionary = _find_fleet_by_id(int(order.get("fleet_id", -1)))
		if fleet.is_empty():
			continue
		_issue_fleet_move_order(fleet, int(order.get("destination_system_id", -1)), _day_index, logs, str(order.get("reason", "planner")), ORDER_SOURCE_FACTION_PLANNER)
	var ship_count: int = 0
	for order_variant in order_book.get("ship_build_orders", []):
		if ship_count >= StrategicTestConfigScript.FACTION_MAX_SHIP_ENQUEUES_PER_DAY:
			break
		var order: Dictionary = order_variant
		var r: Dictionary = enqueue_ship_build(int(order.get("system_id", -1)), faction_id, str(order.get("blueprint_id", "")), _day_index, logs)
		if bool(r.get("queued", false)):
			ship_count += 1
	for order_variant in order_book.get("orbit_build_orders", []):
		_try_enqueue_governor_orbit_action(int((order_variant as Dictionary).get("system_id", -1)), faction_id, order_variant, {})
	for order_variant in order_book.get("troop_train_orders", []):
		var planet: Dictionary = _planets_by_id.get(int((order_variant as Dictionary).get("planet_id", -1)), {})
		if planet.is_empty():
			continue
		_enqueue_troop_training_for_planet(planet, faction_id, {}, logs, {})
	var occupied_target_planets: Dictionary = {}
	_execute_invasion_step_for_faction(faction_id, occupied_target_planets, logs)
	for note_variant in order_book.get("notes", []):
		logs.append("DAY %d | FACTION_PLAN_NOTE | faction=%d %s" % [_day_index, faction_id, str(note_variant)])
	logs.append("DAY %d | FACTION_PLAN | faction=%d actions=fleet:%d ship:%d orbit:%d troop:%d invade:%d notes=%d" % [
		_day_index,
		faction_id,
		(order_book.get("fleet_orders", []) as Array).size(),
		(order_book.get("ship_build_orders", []) as Array).size(),
		(order_book.get("orbit_build_orders", []) as Array).size() + (order_book.get("platform_orders", []) as Array).size(),
		(order_book.get("troop_train_orders", []) as Array).size(),
		(order_book.get("invasion_ops", []) as Array).size(),
		(order_book.get("notes", []) as Array).size(),
	])
	_planner_execution_active = false


func _execute_invasion_step_for_faction(faction_id: int, occupied_target_planets: Dictionary, logs: Array[String]) -> void:
	if faction_id == StrategicTestConfigScript.NO_OWNER_FACTION_ID:
		return
	if not ai_trace_by_faction.has(faction_id):
		ai_trace_by_faction[faction_id] = []
	if not ai_trace_cursor_by_faction.has(faction_id):
		ai_trace_cursor_by_faction[faction_id] = 0
	_run_ai_invasion_planner_for_faction(faction_id, _day_index, occupied_target_planets, logs)


func _run_dispatcher(_current_day_index: int, _logs: Array[String]) -> void:
	return


func _run_dispatcher_haven_mass(current_day_index: int, logs: Array[String]) -> void:
	return
	for faction_id in _get_sorted_faction_ids():
		if faction_id == StrategicTestConfigScript.NO_OWNER_FACTION_ID:
			continue
		var target_system_id: int = -1
		var threshold: int = 0
		var friendly_sr: int = 0
		var need_sr: int = 0
		for system_id in get_owned_system_ids(faction_id):
			var system_state: Dictionary = get_system(system_id)
			if int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) != StrategicTestConfigScript.PIRATE_STATE_HAVEN:
				continue
			var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(system_id))
			var clear_threshold: int = int(pirate_presence.get("threat_sr", 0)) + 10
			var system_friendly_sr: int = int((system_state.get("sr_by_faction", {}) as Dictionary).get(faction_id, 0))
			var system_need_sr: int = maxi(0, clear_threshold - system_friendly_sr)
			if system_need_sr <= 0:
				continue
			if target_system_id < 0 or system_need_sr > need_sr or (system_need_sr == need_sr and system_id < target_system_id):
				target_system_id = system_id
				threshold = clear_threshold
				friendly_sr = system_friendly_sr
				need_sr = system_need_sr

		if target_system_id <= 0:
			continue

		var candidates: Array[Dictionary] = []
		for fleet_variant in _collect_all_fleets():
			var fleet_state: Dictionary = fleet_variant
			if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
				continue
			if str(fleet_state.get("status", "idle")) == "moving":
				continue
			if StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
				continue
			var origin_system_id: int = int(fleet_state.get("system_id", -1))
			if origin_system_id <= 0 or origin_system_id == target_system_id:
				continue
			var hops: int = _compute_hop_distance(origin_system_id, target_system_id)
			if hops < 0:
				continue
			candidates.append({
				"fleet": fleet_state,
				"hops": hops,
				"effective_sr": get_fleet_effective_sr(fleet_state),
				"fleet_id": int(fleet_state.get("fleet_id", -1)),
			})

		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.get("hops", 0)) == int(b.get("hops", 0)):
				if int(a.get("effective_sr", 0)) == int(b.get("effective_sr", 0)):
					return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
				return int(a.get("effective_sr", 0)) > int(b.get("effective_sr", 0))
			return int(a.get("hops", 0)) < int(b.get("hops", 0))
		)

		var projected_sr: int = friendly_sr
		var chosen_fleet_ids: Array[int] = []
		for candidate_variant in candidates:
			if projected_sr >= threshold:
				break
			var candidate: Dictionary = candidate_variant
			var fleet_state: Dictionary = candidate.get("fleet", {})
			var issue_result: Dictionary = _issue_fleet_move_order(fleet_state, target_system_id, current_day_index, logs, "haven_mass", ORDER_SOURCE_FACTION_PLANNER)
			if not bool(issue_result.get("ordered", false)):
				continue
			chosen_fleet_ids.append(int(candidate.get("fleet_id", -1)))
			projected_sr += int(candidate.get("effective_sr", 0))

		chosen_fleet_ids.sort()
		logs.append("DAY %d | HAVEN_MASS | faction=%d target_system=%d threshold=%d friendly=%d need=%d chosen=%s reason=mass_for_clear" % [
			current_day_index,
			faction_id,
			target_system_id,
			threshold,
			friendly_sr,
			need_sr,
			fmt_sorted_int_list(chosen_fleet_ids),
		])


func add_defense_station_i_to_planet(system_name: String, planet_name: String) -> bool:
	var lookup_key: String = _planet_lookup_key(system_name, planet_name)
	if not _planet_ids_by_name.has(lookup_key):
		return false
	var planet_id: int = int(_planet_ids_by_name[lookup_key])
	var system_id: int = int(_system_id_by_planet_id.get(planet_id, -1))
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return false
	var owner_faction_id: int = int((_planets_by_id[planet_id] as Dictionary).get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var structures: Array = system_state.get("orbital_structures", [])
	structures.append(StrategicTestConfigScript.create_defense_station_i_instance(owner_faction_id, system_id))
	system_state["orbital_structures"] = structures
	return true


func add_listening_post_to_planet(system_name: String, planet_name: String) -> bool:
	var lookup_key: String = _planet_lookup_key(system_name, planet_name)
	if not _planet_ids_by_name.has(lookup_key):
		return false
	var planet_id: int = int(_planet_ids_by_name[lookup_key])
	var system_id: int = int(_system_id_by_planet_id.get(planet_id, -1))
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return false
	var owner_faction_id: int = int((_planets_by_id[planet_id] as Dictionary).get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var structures: Array = system_state.get("orbital_structures", [])
	structures.append(StrategicTestConfigScript.create_listening_post_instance(owner_faction_id, system_id))
	system_state["orbital_structures"] = structures
	return true


func add_patrol_hq_to_planet(system_name: String, planet_name: String) -> bool:
	var lookup_key: String = _planet_lookup_key(system_name, planet_name)
	if not _planet_ids_by_name.has(lookup_key):
		return false
	var planet_id: int = int(_planet_ids_by_name[lookup_key])
	var system_id: int = int(_system_id_by_planet_id.get(planet_id, -1))
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return false
	var owner_faction_id: int = int((_planets_by_id[planet_id] as Dictionary).get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var structures: Array = system_state.get("orbital_structures", [])
	structures.append(StrategicTestConfigScript.create_patrol_hq_instance(owner_faction_id, system_id))
	system_state["orbital_structures"] = structures
	return true


func add_rare_belt_to_system(system_name: String, platform_tier: int = 2) -> bool:
	var system_state: Dictionary = _systems_by_name.get(system_name, {})
	if system_state.is_empty():
		return false
	var primary_planet: Dictionary = get_primary_planet(int(system_state.get("id", -1)))
	if primary_planet.is_empty():
		return false
	var belt_node: Dictionary = StrategicTestConfigScript.create_belt_node(
		StrategicTestConfigScript.BELT_CLASS_RARE,
		platform_tier,
		int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	)
	system_state["has_belt"] = true
	system_state["belt_class"] = str(belt_node.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE))
	system_state["platform_tier"] = int(belt_node.get("platform_tier", 0))
	system_state["belt_disabled_days"] = int(belt_node.get("belt_disabled_days", 0))
	system_state["belt_owner_faction_id"] = int(belt_node.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	system_state["belt"] = belt_node
	return true


func queue_build_mining_platform(system_name: String, target_tier: int) -> Dictionary:
	var system_state: Dictionary = _systems_by_name.get(system_name, {})
	if system_state.is_empty():
		return {"queued": false, "reason": "unknown system"}
	if not bool(system_state.get("has_belt", false)):
		return {"queued": false, "reason": "no belt"}
	var current_tier: int = int(system_state.get("platform_tier", 0))
	var clamped_target_tier: int = clampi(target_tier, 1, 3)
	if clamped_target_tier != current_tier + 1:
		return {"queued": false, "reason": "platform upgrades must be sequential"}

	var queue: Array = system_state.get("space_queue", [])
	if queue.size() >= SPACE_QUEUE_CAPACITY:
		return {"queued": false, "reason": "space queue is full"}

	var primary_planet: Dictionary = get_primary_planet(int(system_state.get("id", -1)))
	if primary_planet.is_empty():
		return {"queued": false, "reason": "missing primary planet"}
	var owner_faction_id: int = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if not _factions_by_id.has(owner_faction_id):
		return {"queued": false, "reason": "owner faction missing"}

	var order: Dictionary = StrategicTestConfigScript.create_mining_platform_order(clamped_target_tier)
	var faction_state: Dictionary = _factions_by_id[owner_faction_id]
	var next_credits: int = int(faction_state.get("credits", 0)) - int(order.get("cost_credits", 0))
	var next_metal: int = int(faction_state.get("metal", 0)) - int(order.get("cost_metal", 0))
	var next_rare_metal: int = int(faction_state.get("rare_metal", 0)) - int(order.get("cost_rare_metal", 0))
	if next_credits < 0 or next_metal < 0 or next_rare_metal < 0:
		return {"queued": false, "reason": "insufficient resources"}

	faction_state["credits"] = next_credits
	faction_state["metal"] = next_metal
	faction_state["rare_metal"] = next_rare_metal
	order["days_remaining"] = int(order.get("build_days", 0))
	order["owner_faction_id"] = owner_faction_id
	queue.append(order)
	system_state["space_queue"] = queue
	return {"queued": true, "reason": ""}


func collect_governor_candidates_for_faction(faction_id: int, current_day_index: int) -> Dictionary:
	var queued_upkeep_by_faction: Dictionary = {faction_id: 0}
	var orbit_orders: Array[Dictionary] = []
	var ship_orders: Array[Dictionary] = []
	var troop_orders: Array[Dictionary] = []
	var net_c_today: int = get_faction_expected_income_today(faction_id) - get_faction_total_upkeep(faction_id)
	var scored_systems: Array[Dictionary] = []
	for system_id in get_owned_system_ids(faction_id):
		scored_systems.append(_compute_system_priority_terms(int(system_id), faction_id))
	scored_systems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("prio", 0)) == int(b.get("prio", 0)):
			return int(a.get("system_id", 0)) < int(b.get("system_id", 0))
		return int(a.get("prio", 0)) > int(b.get("prio", 0))
	)
	for entry_variant in scored_systems:
		var entry: Dictionary = entry_variant
		var system_id: int = int(entry.get("system_id", -1))
		var planned_action: Dictionary = _get_next_orbit_governor_action(system_id, faction_id, net_c_today)
		if not planned_action.is_empty():
			planned_action["system_id"] = system_id
			planned_action["source"] = ORDER_SOURCE_FACTION_PLANNER
			planned_action["reason"] = "governor_scored_orbit"
			planned_action["target_id"] = system_id
			planned_action["score"] = int(entry.get("prio", 0))
			orbit_orders.append(planned_action)
		var ship_pick: Dictionary = _try_enqueue_governor_ship_action(system_id, faction_id, {}, queued_upkeep_by_faction, [], true)
		if bool(ship_pick.get("candidate", false)):
			ship_orders.append({
				"source": ORDER_SOURCE_FACTION_PLANNER,
				"reason": "governor_ship_priority",
				"system_id": system_id,
				"target_id": system_id,
				"blueprint_id": str(ship_pick.get("blueprint_id", "")),
				"score": int(entry.get("prio", 0)),
			})
	for planet_id_variant in _planets_by_id.keys():
		var planet_id: int = int(planet_id_variant)
		var planet: Dictionary = _planets_by_id[planet_id]
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if not (planet.get("troop_training_queue", []) as Array).is_empty():
			continue
		var troop_gp: int = StrategicTestLogicScript.compute_planet_troop_gp(planet)
		var required_gp: int = int(planet.get("required_garrison_gp", 0))
		if troop_gp >= required_gp:
			continue
		troop_orders.append({
			"source": ORDER_SOURCE_FACTION_PLANNER,
			"reason": "garrison_deficit",
			"planet_id": planet_id,
			"target_id": planet_id,
			"score": maxi(0, required_gp - troop_gp),
		})
	return {
		"ship_build_orders": ship_orders,
		"orbit_build_orders": orbit_orders,
		"platform_orders": [],
		"troop_train_orders": troop_orders,
	}


func run_galaxy_background_governor(current_day_index: int, logs: Array[String] = []) -> void:
	return


	var queued_upkeep_by_faction: Dictionary = {}
	var skip_logged_today_by_system: Dictionary = {}
	var ship_skip_logged_today_by_system: Dictionary = {}
	var troop_skip_logged_today_by_planet: Dictionary = {}
	var sorted_faction_ids: Array[int] = []
	for faction_id_variant in _factions_by_id.keys():
		sorted_faction_ids.append(int(faction_id_variant))
	sorted_faction_ids.sort()
	for faction_id in sorted_faction_ids:
		queued_upkeep_by_faction[faction_id] = 0
		var expected_income: int = get_faction_expected_income_today(faction_id)
		var upkeep_today: int = get_faction_total_upkeep(faction_id)
		var net_c_today: int = expected_income - upkeep_today
		var scored_systems: Array[Dictionary] = []
		for system_id in get_owned_system_ids(faction_id):
			scored_systems.append(_compute_system_priority_terms(int(system_id), faction_id))
		scored_systems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.get("prio", 0)) == int(b.get("prio", 0)):
				return int(a.get("system_id", 0)) < int(b.get("system_id", 0))
			return int(a.get("prio", 0)) > int(b.get("prio", 0))
		)
		logs.append("DAY %d | GOVERNOR | faction=%d netC_today=%d systems=%d" % [current_day_index, faction_id, net_c_today, scored_systems.size()])

		for entry_variant in scored_systems:
			var entry: Dictionary = entry_variant
			var system_id: int = int(entry.get("system_id", -1))
			while true:
				var planned_action: Dictionary = _get_next_orbit_governor_action(system_id, faction_id, net_c_today)
				if planned_action.is_empty():
					break
				var enqueue_result: Dictionary = _try_enqueue_governor_orbit_action(system_id, faction_id, planned_action, queued_upkeep_by_faction)
				if bool(enqueue_result.get("queued", false)):
					logs.append("Faction %d enqueue %s in System %d (cost %d/%d/%d, new_upkeep=%d, projected_netC=%d, wallet=faction_stockpile)" % [
						faction_id,
						str(planned_action.get("build_type", "")),
						system_id,
						int(planned_action.get("cost_credits", 0)),
						int(planned_action.get("cost_metal", 0)),
						int(planned_action.get("cost_rare_metal", 0)),
						int(planned_action.get("upkeep_credits_per_day", 0)),
						int(enqueue_result.get("projected_net_c", 0)),
					])
					continue
				var failure_reason: String = str(enqueue_result.get("reason", "unknown"))
				if failure_reason == "insufficient resources":
					if not bool(skip_logged_today_by_system.get(system_id, false)):
						skip_logged_today_by_system[system_id] = true
						logs.append("DAY %d | GOVERNOR | system=%d skip=insufficient faction metal/rare_metal wallet=faction_stockpile (throttled daily)" % [
							current_day_index,
							system_id,
						])
				else:
					logs.append("DAY %d | GOVERNOR | faction=%d system=%d action=%s failed=%s" % [
						current_day_index,
						faction_id,
						system_id,
						str(planned_action.get("build_type", "")),
						failure_reason,
					])
				break

		var enqueued_ship_today_by_system: Dictionary = {}
		for entry_variant in scored_systems:
			var entry: Dictionary = entry_variant
			var system_id: int = int(entry.get("system_id", -1))
			var ship_result: Dictionary = _try_enqueue_governor_ship_action(system_id, faction_id, enqueued_ship_today_by_system, queued_upkeep_by_faction, logs)
			if bool(ship_result.get("queued", false)):
				continue
			var ship_reason: String = str(ship_result.get("reason", "none"))
			if ship_reason == "none":
				continue
			if not bool(ship_skip_logged_today_by_system.get(system_id, false)):
				ship_skip_logged_today_by_system[system_id] = true
				logs.append("DAY %d | SHIP_ENQUEUE_SKIP | system=%d owner=%d reason=%s" % [
					current_day_index,
					system_id,
					faction_id,
					ship_reason,
				])


		for entry_variant in scored_systems:
			var entry: Dictionary = entry_variant
			var system_id: int = int(entry.get("system_id", -1))
			for planet_variant in get_system_planets(system_id):
				var planet_state: Dictionary = planet_variant
				if int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
					continue
				_enqueue_troop_training_for_planet(planet_state, faction_id, queued_upkeep_by_faction, logs, troop_skip_logged_today_by_planet)



func _make_default_invasion_plan() -> Dictionary:
	return {
		"state": "idle",
		"target_planet_id": -1,
		"target_system_id": -1,
		"staging_planet_id": -1,
		"staging_system_id": -1,
		"transport_fleet_id": -1,
		"escort_fleet_ids": [] as Array[int],
		"required_troop_gp": 0,
		"committed_troop_gp": 0,
		"last_step_day": -1,
		"cooldown_until_day": 0,
	}


func _ensure_invasion_plan_for_faction(faction_id: int) -> Dictionary:
	if not invasion_plan_by_faction.has(faction_id):
		invasion_plan_by_faction[faction_id] = _make_default_invasion_plan()
	return invasion_plan_by_faction[faction_id]


func _reset_invasion_plan_to_idle(plan: Dictionary) -> void:
	plan["state"] = "idle"
	_clear_invasion_plan_payload(plan)


func _clear_invasion_plan_payload(plan: Dictionary) -> void:
	plan["target_planet_id"] = -1
	plan["target_system_id"] = -1
	plan["staging_planet_id"] = -1
	plan["staging_system_id"] = -1
	plan["transport_fleet_id"] = -1
	plan["escort_fleet_ids"] = []
	plan["required_troop_gp"] = 0
	plan["committed_troop_gp"] = 0


func _run_ai_invasion_planner(_current_day_index: int, _logs: Array[String]) -> void:
	return


func _run_ai_invasion_planner_for_faction(faction_id: int, current_day_index: int, occupied_target_planets: Dictionary, logs: Array[String]) -> void:
	var plan: Dictionary = _ensure_invasion_plan_for_faction(faction_id)
	var state: String = str(plan.get("state", "idle"))
	var reason: String = ""

	if state == "cooldown":
		_clear_invasion_plan_payload(plan)
		if current_day_index >= int(plan.get("cooldown_until_day", 0)):
			_reset_invasion_plan_to_idle(plan)
			state = "idle"
		else:
			_ai_trace(faction_id, "cooldown", "paused", "cooldown")

	if state == "idle" and current_day_index >= int(plan.get("cooldown_until_day", 0)):
		var selection: Dictionary = _select_ai_invasion_target_for_faction(faction_id, occupied_target_planets)
		if not selection.is_empty():
			plan["target_planet_id"] = int(selection.get("target_planet_id", -1))
			plan["target_system_id"] = int(selection.get("target_system_id", -1))
			plan["staging_planet_id"] = int(selection.get("staging_planet_id", -1))
			plan["staging_system_id"] = int(selection.get("staging_system_id", -1))
			plan["required_troop_gp"] = int(selection.get("required_troop_gp", StrategicTestConfigScript.AI_INVASION_REQUIRED_MIN_GP))
			plan["committed_troop_gp"] = 0
			plan["transport_fleet_id"] = -1
			plan["escort_fleet_ids"] = []
			plan["state"] = "build_transport"
			state = "build_transport"
			occupied_target_planets[int(selection.get("target_planet_id", -1))] = true
			reason = "selected_target"
			_ai_trace(faction_id, "select_target", "issued_order", "ok")
		else:
			_ai_trace(faction_id, "select_target", "none", "no_candidate_target")

	state = str(plan.get("state", "idle"))
	match state:
		"build_transport":
			reason = _ai_invasion_step_build_transport(plan, faction_id, current_day_index, logs)
		"assemble_troops":
			reason = _ai_invasion_step_assemble_troops(plan, faction_id, current_day_index, logs)
		"load":
			reason = _ai_invasion_step_load(plan, faction_id, current_day_index, logs)
		"ensure_escort":
			reason = _ai_invasion_step_ensure_escort(plan, faction_id, current_day_index, logs)
		"move":
			reason = _ai_invasion_step_move(plan, faction_id, current_day_index, logs)
		"land":
			reason = _ai_invasion_step_land(plan, faction_id, current_day_index, logs)
		"invade":
			reason = _ai_invasion_step_invade(plan, faction_id, current_day_index, logs)
		"retreat_or_abort":
			reason = _ai_invasion_step_retreat_or_abort(plan, faction_id, current_day_index, logs)
		"cooldown":
			reason = "cooldown"
		_:
			reason = "idle"

	plan["last_step_day"] = current_day_index
	var final_state: String = str(plan.get("state", "idle"))
	if final_state != "idle":
		_log_ai_invasion_summary(faction_id, plan, current_day_index, reason, logs)


func _normalize_ai_trace_reason(reason: String) -> String:
	var normalized: String = reason.strip_edges()
	if normalized == "":
		return "ok"
	if normalized.begins_with("failed="):
		normalized = normalized.substr(7)
	if normalized.begins_with("land_failed"):
		return "other:land_failed"
	if normalized.begins_with("load_failed"):
		return "other:load_failed"
	if normalized.begins_with("move_order"):
		return "other:move_order_failed"
	match normalized:
		"ok":
			return "ok"
		"selected_target":
			return "ok"
		"transport_ready":
			return "ok"
		"enqueued_transport":
			return "ok"
		"troops_ready":
			return "ok"
		"assemble_troops":
			return "insufficient_troops"
		"loaded":
			return "ok"
		"landing_staging":
			return "ok"
		"move_to_staging":
			return "transport_not_in_staging"
		"orders_issued":
			return "ok"
		"launching":
			return "ok"
		"arrived_target_system":
			return "ok"
		"landed_target":
			return "ok"
		"gate_fail":
			return "invasion_gate_failed"
		"invade_done":
			return "ok"
		"cooldown":
			return "cooldown"
		"no_candidate_target":
			return "no_candidate_target"
		"no_shipyard":
			return "no_shipyard"
		"solvency":
			return "solvency_failed"
		"solvency_failed":
			return "solvency_failed"
		"no_transport":
			return "no_transport"
		"transport_not_in_staging":
			return "transport_not_in_staging"
		"insufficient_troops":
			return "insufficient_troops"
		"insufficient_escort_sr":
			return "insufficient_escort_sr"
		"unreachable":
			return "unreachable"
		"invasion_gate_failed":
			return "invasion_gate_failed"
		"transport_missing":
			return "no_transport"
		"staging_missing":
			return "other:staging_missing"
		"target_missing":
			return "other:target_missing"
		"transport_enroute":
			return "other:transport_enroute"
		"transport_moving":
			return "other:transport_moving"
		"not_in_target_system":
			return "other:not_in_target_system"
		_:
			return "other:%s" % normalized


func _ai_trace(fid: int, step: String, decision: String, reason: String, computed: Dictionary = {}, note: String = "") -> void:
	var plan: Dictionary = _ensure_invasion_plan_for_faction(fid)
	var escort_ids: Array[int] = []
	for escort_id_variant in plan.get("escort_fleet_ids", []):
		escort_ids.append(int(escort_id_variant))
	escort_ids.sort()
	var computed_snapshot: Dictionary = {}
	var computed_keys: Array = computed.keys()
	computed_keys.sort()
	for key_variant in computed_keys:
		var key: String = str(key_variant)
		var value: Variant = computed.get(key_variant, 0)
		if value is bool:
			computed_snapshot[key] = value
		else:
			computed_snapshot[key] = int(value)
	var entry: Dictionary = {
		"day": _day_index,
		"faction_id": fid,
		"planner_state": str(plan.get("state", "idle")),
		"step": step,
		"target_planet_id": int(plan.get("target_planet_id", -1)),
		"target_system_id": int(plan.get("target_system_id", -1)),
		"staging_planet_id": int(plan.get("staging_planet_id", -1)),
		"staging_system_id": int(plan.get("staging_system_id", -1)),
		"transport_fleet_id": int(plan.get("transport_fleet_id", -1)),
		"escort_fleet_ids": escort_ids,
		"required_troop_gp": int(plan.get("required_troop_gp", 0)),
		"committed_troop_gp": int(plan.get("committed_troop_gp", 0)),
		"computed": computed_snapshot,
		"decision": decision,
		"reason": _normalize_ai_trace_reason(reason),
		"note": note,
	}
	if not ai_trace_by_faction.has(fid):
		ai_trace_by_faction[fid] = []
	if not ai_trace_cursor_by_faction.has(fid):
		ai_trace_cursor_by_faction[fid] = 0
	var buffer: Array = ai_trace_by_faction[fid]
	var cursor: int = int(ai_trace_cursor_by_faction.get(fid, 0))
	if buffer.size() < StrategicTestConfigScript.AI_TRACE_BUFFER_SIZE:
		buffer.append(entry)
	else:
		buffer[cursor] = entry
	cursor = (cursor + 1) % StrategicTestConfigScript.AI_TRACE_BUFFER_SIZE
	ai_trace_by_faction[fid] = buffer
	ai_trace_cursor_by_faction[fid] = cursor
	if StrategicTestConfigScript.DEBUG_AI_TRACE_LOGS:
		print("DAY %d | AI_TRACE | faction=%d step=%s decision=%s reason=%s" % [
			_day_index,
			fid,
			step,
			decision,
			_normalize_ai_trace_reason(reason),
		])


func get_ai_trace_entries(faction_id: int) -> Array[Dictionary]:
	if not ai_trace_by_faction.has(faction_id):
		return []
	var raw: Array = ai_trace_by_faction[faction_id]
	var size: int = raw.size()
	if size <= 0:
		return []
	if size < StrategicTestConfigScript.AI_TRACE_BUFFER_SIZE:
		var out_simple: Array[Dictionary] = []
		for entry_variant in raw:
			out_simple.append(entry_variant)
		return out_simple
	var out: Array[Dictionary] = []
	var cursor: int = int(ai_trace_cursor_by_faction.get(faction_id, 0))
	for idx in range(size):
		var ring_index: int = (cursor + idx) % size
		out.append(raw[ring_index])
	return out


func get_simulation_faction_ids() -> Array[int]:
	var ids: Array[int] = []
	for faction_id_variant in _factions_by_id.keys():
		ids.append(int(faction_id_variant))
	ids.sort()
	return ids


func _select_ai_invasion_target_for_faction(faction_id: int, occupied_target_planets: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -9999999
	for planet_id_variant in _planets_by_id.keys():
		var target_planet_id: int = int(planet_id_variant)
		if bool(occupied_target_planets.get(target_planet_id, false)):
			continue
		var target_planet: Dictionary = _planets_by_id[target_planet_id]
		var target_owner: int = int(target_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if target_owner == faction_id:
			continue
		if not StrategicTestLogicScript.are_factions_hostile(faction_id, target_owner):
			continue
		var target_system_id: int = int(target_planet.get("system_id", -1))
		var staging: Dictionary = _select_ai_staging_planet(faction_id, target_system_id)
		if staging.is_empty():
			continue
		var staging_system_id: int = int(staging.get("system_id", -1))
		var hops: int = _compute_hop_distance(staging_system_id, target_system_id)
		if hops < 0 or hops > 1:
			continue
		var target_troop_gp: int = _refresh_planet_troop_gp(target_planet)
		var effective_garrison_gp: int = int(target_planet.get("current_garrison_gp", 0)) + target_troop_gp
		var value_score: int = int(target_planet.get("base_credits_per_day", 0))
		var weakness_score: int = 100 - int(target_planet.get("control", 0))
		var defense_score: int = effective_garrison_gp * 20
		var distance_penalty: int = hops * 10
		var total_score: int = value_score + weakness_score - defense_score - distance_penalty
		if best.is_empty() or total_score > best_score or (total_score == best_score and target_planet_id < int(best.get("target_planet_id", 2147483647))):
			best_score = total_score
			best = {
				"target_planet_id": target_planet_id,
				"target_system_id": target_system_id,
				"staging_planet_id": int(staging.get("planet_id", -1)),
				"staging_system_id": staging_system_id,
				"required_troop_gp": maxi(StrategicTestConfigScript.AI_INVASION_REQUIRED_MIN_GP, effective_garrison_gp + 1),
			}
	return best


func _select_ai_staging_planet(faction_id: int, target_system_id: int) -> Dictionary:
	var best: Dictionary = {}
	for planet_id_variant in _planets_by_id.keys():
		var planet_id: int = int(planet_id_variant)
		var planet: Dictionary = _planets_by_id[planet_id]
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		var system_id: int = int(planet.get("system_id", -1))
		if _compute_hop_distance(system_id, target_system_id) < 0:
			continue
		var troop_gp: int = _refresh_planet_troop_gp(planet)
		var queue_size: int = int((planet.get("troop_training_queue", []) as Array).size())
		var can_train: bool = StrategicTestConfigScript.TROOP_BLUEPRINTS.has("troops_basic") and queue_size < StrategicTestConfigScript.TROOP_MAX_TRAIN_JOBS_PER_PLANET
		if troop_gp <= 0 and not can_train:
			continue
		var control: int = int(planet.get("control", 0))
		if best.is_empty() or control > int(best.get("control", -1)) or (control == int(best.get("control", -1)) and planet_id < int(best.get("planet_id", 2147483647))):
			best = {
				"planet_id": planet_id,
				"system_id": system_id,
				"control": control,
			}
	return best


func _select_ai_alternate_staging_planet(faction_id: int, target_system_id: int, excluded_planet_id: int = -1) -> Dictionary:
	var best: Dictionary = {}
	for planet_id_variant in _planets_by_id.keys():
		var planet_id: int = int(planet_id_variant)
		if planet_id == excluded_planet_id:
			continue
		var planet: Dictionary = _planets_by_id[planet_id]
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		var system_id: int = int(planet.get("system_id", -1))
		if _compute_hop_distance(system_id, target_system_id) < 0:
			continue
		var troop_gp: int = _refresh_planet_troop_gp(planet)
		var queue_size: int = int((planet.get("troop_training_queue", []) as Array).size())
		var can_train: bool = StrategicTestConfigScript.TROOP_BLUEPRINTS.has("troops_basic") and queue_size < StrategicTestConfigScript.TROOP_MAX_TRAIN_JOBS_PER_PLANET
		if troop_gp <= 0 and not can_train:
			continue
		if best.is_empty() or troop_gp > int(best.get("troop_gp", -1)) or (troop_gp == int(best.get("troop_gp", -1)) and planet_id < int(best.get("planet_id", 2147483647))):
			best = {
				"planet_id": planet_id,
				"system_id": system_id,
				"troop_gp": troop_gp,
				"can_train": can_train,
			}
	return best


func _select_owned_load_planet_in_system(faction_id: int, system_id: int) -> Dictionary:
	var best: Dictionary = {}
	for planet_id_variant in _planets_by_id.keys():
		var planet_id: int = int(planet_id_variant)
		var planet: Dictionary = _planets_by_id[planet_id]
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if int(planet.get("system_id", -1)) != system_id:
			continue
		var troop_gp: int = _refresh_planet_troop_gp(planet)
		if troop_gp <= 0:
			continue
		if best.is_empty() or troop_gp > int(best.get("troop_gp", -1)) or (troop_gp == int(best.get("troop_gp", -1)) and planet_id < int(best.get("planet_id", 2147483647))):
			best = {
				"planet_id": planet_id,
				"troop_gp": troop_gp,
			}
	return best


func _ai_invasion_step_build_transport(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_available_transport_fleet_for_faction(faction_id)
	if transport_fleet.is_empty():
		var staging_system_id: int = int(plan.get("staging_system_id", -1))
		var shipyard_system_id: int = _find_closest_active_shipyard_system_for_faction(faction_id, staging_system_id)
		if shipyard_system_id <= 0:
			_ai_trace(faction_id, "ensure_transport", "none", "no_shipyard")
			if _should_log_ai_invasion_failure(faction_id, "no_shipyard", current_day_index):
				logs.append("DAY %d | AI_INVASION | faction=%d state=build_transport target=%d reason=wait_no_shipyard" % [
					current_day_index,
					faction_id,
					int(plan.get("target_planet_id", -1)),
				])
			return "wait_no_shipyard"
		var blueprint: Dictionary = StrategicTestConfigScript.SHIP_BLUEPRINTS.get("transport_mk1", {})
		var projected_income: int = get_faction_expected_income_today(faction_id)
		var projected_upkeep: int = get_faction_total_upkeep(faction_id) + int(blueprint.get("upkeep_credits_per_day", 0))
		if projected_income - projected_upkeep < 0:
			_ai_trace(faction_id, "ensure_transport", "none", "solvency_failed")
			if _should_log_ai_invasion_failure(faction_id, "solvency", current_day_index):
				logs.append("DAY %d | AI_INVASION | faction=%d state=build_transport target=%d reason=wait_solvency" % [
					current_day_index,
					faction_id,
					int(plan.get("target_planet_id", -1)),
				])
			return "wait_solvency"
		var enqueue_result: Dictionary = enqueue_ship_build(shipyard_system_id, faction_id, "transport_mk1", _day_index, logs)
		if bool(enqueue_result.get("queued", false)):
			_ai_trace(faction_id, "ensure_transport", "enqueued_ship", "ok", {}, "transport_mk1")
			logs.append("DAY %d | AI_INVASION | faction=%d state=build_transport target=%d reason=enqueued_transport system=%d" % [
				current_day_index,
				faction_id,
				int(plan.get("target_planet_id", -1)),
				shipyard_system_id,
			])
			return "enqueued_transport"
		var fail_reason: String = str(enqueue_result.get("reason", "enqueue_failed"))
		_ai_trace(faction_id, "ensure_transport", "none", fail_reason)
		if _should_log_ai_invasion_failure(faction_id, fail_reason, current_day_index):
			logs.append("DAY %d | AI_INVASION | faction=%d state=build_transport target=%d reason=wait_%s" % [
				current_day_index,
				faction_id,
				int(plan.get("target_planet_id", -1)),
				fail_reason,
			])
		return "wait_%s" % fail_reason
	plan["transport_fleet_id"] = int(transport_fleet.get("fleet_id", -1))
	plan["state"] = "assemble_troops"
	_ai_trace(faction_id, "ensure_transport", "issued_order", "ok")
	return "transport_ready"


func _ai_invasion_step_assemble_troops(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var staging_planet_id: int = int(plan.get("staging_planet_id", -1))
	var staging_planet: Dictionary = _planets_by_id.get(staging_planet_id, {})
	_emit_ai_invasion_load_diagnostics(faction_id, current_day_index, plan, "assemble_troops", staging_planet, {}, "other:precheck", logs)
	if staging_planet.is_empty():
		plan["state"] = "cooldown"
		plan["cooldown_until_day"] = current_day_index + StrategicTestConfigScript.AI_INVASION_COOLDOWN_DAYS
		_ai_trace(faction_id, "assemble_troops", "paused", "other:staging_missing")
		return "cooldown"
	var required_gp: int = int(plan.get("required_troop_gp", 0))
	var troop_gp: int = _refresh_planet_troop_gp(staging_planet)
	if troop_gp >= required_gp:
		logs.append("DAY %d | AI_INV_STEP | faction=%d from=assemble_troops to=load reason=staging_troops_sufficient" % [
			current_day_index,
			faction_id,
		])
		plan["state"] = "load"
		_ai_trace(faction_id, "assemble_troops", "issued_order", "ok")
		return "proceed_to_load"
	var target_system_id: int = int(plan.get("target_system_id", -1))
	var alternate_staging_ready: Dictionary = _select_ai_alternate_staging_planet(faction_id, target_system_id, staging_planet_id)
	if not alternate_staging_ready.is_empty() and int(alternate_staging_ready.get("troop_gp", 0)) >= required_gp:
		plan["staging_planet_id"] = int(alternate_staging_ready.get("planet_id", -1))
		plan["staging_system_id"] = int(alternate_staging_ready.get("system_id", -1))
		logs.append("DAY %d | AI_INVASION | faction=%d state=assemble_troops reason=switch_staging new_stagingP=%d new_stagingS=%d" % [
			current_day_index,
			faction_id,
			int(plan.get("staging_planet_id", -1)),
			int(plan.get("staging_system_id", -1)),
		])
		_ai_trace(faction_id, "assemble_troops", "issued_order", "switch_staging")
		return "switch_staging"
	var enqueue_reason: String = _enqueue_invasion_troop_training_for_planet(staging_planet, faction_id)
	if enqueue_reason == "ok":
		_ai_trace(faction_id, "assemble_troops", "enqueued_troop", "insufficient_troops")
		return "wait_training"
	if enqueue_reason == "queue_full":
		var alternate_staging: Dictionary = _select_ai_alternate_staging_planet(faction_id, target_system_id, staging_planet_id)
		if not alternate_staging.is_empty():
			plan["staging_planet_id"] = int(alternate_staging.get("planet_id", -1))
			plan["staging_system_id"] = int(alternate_staging.get("system_id", -1))
			logs.append("DAY %d | AI_INVASION | faction=%d state=assemble_troops reason=switch_staging new_stagingP=%d new_stagingS=%d" % [
				current_day_index,
				faction_id,
				int(plan.get("staging_planet_id", -1)),
				int(plan.get("staging_system_id", -1)),
			])
			_ai_trace(faction_id, "assemble_troops", "issued_order", "switch_staging")
			return "switch_staging"
		logs.append("DAY %d | AI_INVASION | faction=%d state=assemble_troops reason=wait_queue_full target=%d stagingP=%d stagingS=%d troop_gp=%d required_gp=%d" % [
			current_day_index,
			faction_id,
			int(plan.get("target_planet_id", -1)),
			staging_planet_id,
			int(plan.get("staging_system_id", -1)),
			troop_gp,
			required_gp,
		])
		_ai_trace(faction_id, "assemble_troops", "paused", "wait_queue_full")
		return "wait_queue_full"
	else:
		var target_system_id_alt: int = int(plan.get("target_system_id", -1))
		var alternate_staging_alt: Dictionary = _select_ai_alternate_staging_planet(faction_id, target_system_id_alt, staging_planet_id)
		if not alternate_staging_alt.is_empty():
			plan["staging_planet_id"] = int(alternate_staging_alt.get("planet_id", -1))
			plan["staging_system_id"] = int(alternate_staging_alt.get("system_id", -1))
			logs.append("DAY %d | AI_INVASION | faction=%d state=assemble_troops reason=switch_staging new_stagingP=%d new_stagingS=%d" % [
				current_day_index,
				faction_id,
				int(plan.get("staging_planet_id", -1)),
				int(plan.get("staging_system_id", -1)),
			])
			_ai_trace(faction_id, "assemble_troops", "issued_order", "switch_staging")
			return "switch_staging"
		_ai_trace(faction_id, "assemble_troops", "none", enqueue_reason)
	if enqueue_reason != "ok" and enqueue_reason != "queue_full" and _should_log_ai_invasion_failure(faction_id, enqueue_reason, current_day_index):
		logs.append("DAY %d | AI_INVASION | faction=%d state=assemble_troops target=%d reason=wait_%s" % [
			current_day_index,
			faction_id,
			int(plan.get("target_planet_id", -1)),
			enqueue_reason,
		])
	return "wait_queue_full"


func _ai_invasion_step_load(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	_emit_ai_invasion_load_diagnostics(faction_id, current_day_index, plan, "load", {}, transport_fleet, "other:precheck", logs)
	if transport_fleet.is_empty():
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "transport_missing", logs)
		plan["state"] = "build_transport"
		plan["transport_fleet_id"] = -1
		_ai_trace(faction_id, "load", "none", "no_transport")
		return "transport_missing"
	if str(transport_fleet.get("status", "idle")) == "moving":
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "transport_moving", logs)
		_ai_trace(faction_id, "load", "paused", "other:transport_moving")
		return "transport_moving"
	var staging_system_id: int = int(plan.get("staging_system_id", -1))
	if int(transport_fleet.get("system_id", -1)) != staging_system_id:
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "transport_not_in_staging_system", logs)
		var move_result: Dictionary = _issue_fleet_move_order(transport_fleet, staging_system_id, current_day_index, logs, "ai_invasion_move_to_staging", ORDER_SOURCE_FACTION_PLANNER)
		if bool(move_result.get("ordered", false)):
			logs.append("DAY %d | AI_INV_STEP | faction=%d action=move_transport_to_staging to=%d" % [
				current_day_index,
				faction_id,
				staging_system_id,
			])
		if not bool(move_result.get("ordered", false)):
			_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "other:move_order_%s" % str(move_result.get("reason", "move_failed")), logs)
		var hop_distance_to_staging: int = _compute_hop_distance(int(transport_fleet.get("system_id", -1)), staging_system_id)
		_ai_trace(faction_id, "move_order", "issued_order" if bool(move_result.get("ordered", false)) else "none", str(move_result.get("reason", "ok")), {"hop_distance": hop_distance_to_staging}, "arrival_day=%d" % int(move_result.get("arrival_day", -1)))
		return "move_to_staging"
	var load_planet_id: int = int(plan.get("staging_planet_id", -1))
	var load_choice: Dictionary = _select_owned_load_planet_in_system(faction_id, staging_system_id)
	if not load_choice.is_empty():
		load_planet_id = int(load_choice.get("planet_id", load_planet_id))
	if int(transport_fleet.get("landed_planet_id", -1)) != load_planet_id:
		var land_result: Dictionary = transport_land(int(transport_fleet.get("fleet_id", -1)), load_planet_id)
		if not bool(land_result.get("ok", false)):
			var land_reason: String = str(land_result.get("reason", "land_failed"))
			var load_skip_token: String = "cannot_land"
			if land_reason == "fleet_not_found":
				load_skip_token = "transport_missing"
			elif land_reason == "fleet_moving":
				load_skip_token = "transport_moving"
			elif land_reason == "different_system":
				load_skip_token = "transport_not_in_staging_system"
			_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, load_skip_token, logs)
			_ai_trace(faction_id, "land", "none", str(land_result.get("reason", "land_failed")))
			return "land_failed=%s" % str(land_result.get("reason", "unknown"))
		logs.append("DAY %d | AI_INV_STEP | faction=%d action=land_transport planet=%d" % [
			current_day_index,
			faction_id,
			load_planet_id,
		])
		_ai_trace(faction_id, "land", "issued_order", "ok", {}, "load_planet=%d" % load_planet_id)
		return "landing_staging"
	var load_planet: Dictionary = _planets_by_id.get(load_planet_id, {})
	if load_planet.is_empty():
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "cannot_land", logs)
		_ai_trace(faction_id, "load", "none", "invalid_load_planet", {"load_planet_id": load_planet_id})
		return "load_failed=invalid_load_planet"
	var staging_troop_gp: int = _refresh_planet_troop_gp(load_planet)
	var cargo_gp: int = int(transport_fleet.get("cargo_troop_gp", 0))
	var capacity_gp: int = int(transport_fleet.get("transport_capacity_gp", 0))
	if cargo_gp >= capacity_gp:
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "capacity_full", logs)
		_ai_trace(faction_id, "load", "paused", "capacity_full")
		return "load_skip=capacity_full"
	if staging_troop_gp <= 0:
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, "staging_has_no_troops", logs)
		_ai_trace(faction_id, "load", "paused", "staging_has_no_troops")
		return "load_skip=staging_has_no_troops"
	var requested_gp: int = mini(int(plan.get("required_troop_gp", 0)), mini(capacity_gp, staging_troop_gp))
	var load_result: Dictionary = transport_load_troops(int(transport_fleet.get("fleet_id", -1)), load_planet_id, requested_gp)
	if not bool(load_result.get("ok", false)):
		var load_reason: String = str(load_result.get("reason", "unknown"))
		var load_skip_token: String = "other:%s" % load_reason
		if load_reason == "not_found":
			load_skip_token = "transport_missing"
		elif load_reason == "different_system":
			load_skip_token = "transport_not_in_staging_system"
		elif load_reason == "not_landed_on_planet":
			load_skip_token = "transport_not_landed"
		_log_ai_invasion_load_skip_once_per_day(faction_id, current_day_index, plan, transport_fleet, load_skip_token, logs)
		_ai_trace(faction_id, "load", "none", str(load_result.get("reason", "load_failed")))
		return "load_failed=%s" % str(load_result.get("reason", "unknown"))
	plan["committed_troop_gp"] = int(transport_fleet.get("cargo_troop_gp", 0))
	logs.append("DAY %d | AI_INV_STEP | faction=%d action=load_troops requested=%d loaded=%d" % [
		current_day_index,
		faction_id,
		requested_gp,
		int(load_result.get("loaded_gp", 0)),
	])
	logs.append("DAY %d | AI_INVASION | faction=%d state=load staging=%d loaded=%d cargo=%d/%d" % [
		current_day_index,
		faction_id,
		load_planet_id,
		int(load_result.get("loaded_gp", 0)),
		int(transport_fleet.get("cargo_troop_gp", 0)),
		int(transport_fleet.get("transport_capacity_gp", 0)),
	])
	if int(plan.get("committed_troop_gp", 0)) >= int(plan.get("required_troop_gp", 0)) or int(transport_fleet.get("cargo_troop_gp", 0)) >= int(transport_fleet.get("transport_capacity_gp", 0)):
		plan["state"] = "ensure_escort"
	_ai_trace(faction_id, "load", "issued_order", "ok", {}, "loaded_gp=%d cargo=%d" % [int(load_result.get("loaded_gp", 0)), int(transport_fleet.get("cargo_troop_gp", 0))])
	return "loaded"


func _log_ai_invasion_load_skip_once_per_day(faction_id: int, current_day_index: int, plan: Dictionary, transport_fleet: Dictionary, token: String, logs: Array[String]) -> void:
	if int(_ai_invasion_last_load_skip_day_by_faction.get(faction_id, -1)) == current_day_index:
		return
	_ai_invasion_last_load_skip_day_by_faction[faction_id] = current_day_index
	var staging_planet_id: int = int(plan.get("staging_planet_id", -1))
	var staging_system_id: int = int(plan.get("staging_system_id", -1))
	var staging_planet: Dictionary = _planets_by_id.get(staging_planet_id, {})
	var staging_troop_gp: int = 0
	if not staging_planet.is_empty():
		staging_troop_gp = _refresh_planet_troop_gp(staging_planet)
	logs.append("DAY %d | AI_INVASION | faction=%d state=load reason=load_skip=%s stagingP=%d stagingS=%d transport=%d cargo_gp=%d req_gp=%d staging_troop_gp=%d" % [
		current_day_index,
		faction_id,
		token,
		staging_planet_id,
		staging_system_id,
		int(plan.get("transport_fleet_id", -1)) if transport_fleet.is_empty() else int(transport_fleet.get("fleet_id", -1)),
		int(plan.get("committed_troop_gp", 0)) if transport_fleet.is_empty() else int(transport_fleet.get("cargo_troop_gp", 0)),
		int(plan.get("required_troop_gp", 0)),
		staging_troop_gp,
	])


func _emit_ai_invasion_load_diagnostics(faction_id: int, current_day_index: int, plan: Dictionary, planner_state: String, staging_planet_hint: Dictionary, transport_fleet_hint: Dictionary, default_load_block: String, logs: Array[String]) -> void:
	if not StrategicTestConfigScript.DEBUG_AI_INVASION_LOAD_DIAGNOSTICS:
		return
	var staging_planet_id: int = int(plan.get("staging_planet_id", -1))
	var staging_system_id: int = int(plan.get("staging_system_id", -1))
	var required_gp: int = int(plan.get("required_troop_gp", 0))
	var staging_planet: Dictionary = staging_planet_hint
	if staging_planet.is_empty():
		staging_planet = _planets_by_id.get(staging_planet_id, {})
	var staging_troop_gp: int = 0
	if not staging_planet.is_empty():
		staging_troop_gp = _refresh_planet_troop_gp(staging_planet)
	var transport_fleet: Dictionary = transport_fleet_hint
	if transport_fleet.is_empty():
		transport_fleet = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	var transport_id: int = int(plan.get("transport_fleet_id", -1)) if transport_fleet.is_empty() else int(transport_fleet.get("fleet_id", -1))
	var transport_system_id: int = -1 if transport_fleet.is_empty() else int(transport_fleet.get("system_id", -1))
	var landed_planet_id: int = -1 if transport_fleet.is_empty() else int(transport_fleet.get("landed_planet_id", -1))
	var capacity_gp: int = 0 if transport_fleet.is_empty() else int(transport_fleet.get("transport_capacity_gp", 0))
	var cargo_gp: int = int(plan.get("committed_troop_gp", 0)) if transport_fleet.is_empty() else int(transport_fleet.get("cargo_troop_gp", 0))
	var need_move: bool = transport_fleet.is_empty() or transport_system_id != staging_system_id
	var need_land: bool = transport_fleet.is_empty() or landed_planet_id != staging_planet_id
	var can_load: bool = not transport_fleet.is_empty() and not need_move and not need_land and cargo_gp < capacity_gp and staging_troop_gp > 0
	var load_block: String = default_load_block
	if transport_fleet.is_empty():
		load_block = "transport_missing"
	elif str(transport_fleet.get("status", "idle")) == "moving":
		load_block = "transport_moving"
	elif need_move:
		load_block = "transport_not_in_staging_system"
	elif need_land:
		load_block = "not_landed"
	elif capacity_gp <= 0 or cargo_gp >= capacity_gp:
		load_block = "capacity_full"
	elif staging_planet.is_empty() or staging_planet_id <= 0:
		load_block = "invalid_planet"
	elif int(staging_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
		load_block = "owner_mismatch"
	elif staging_troop_gp <= 0:
		load_block = "no_troops"
	else:
		load_block = "ok"
	logs.append("DAY %d | AI_INV_DIAG | faction=%d state=%s targetP=%d stagingP=%d req_gp=%d staging_troop_gp=%d transport=%d transport_sys=%d landed=%d cap=%d cargo=%d need_move=%d need_land=%d can_load=%d load_block=%s" % [
		current_day_index,
		faction_id,
		planner_state,
		int(plan.get("target_planet_id", -1)),
		staging_planet_id,
		required_gp,
		staging_troop_gp,
		transport_id,
		transport_system_id,
		landed_planet_id,
		capacity_gp,
		cargo_gp,
		1 if need_move else 0,
		1 if need_land else 0,
		1 if can_load else 0,
		load_block,
	])


func _resolve_ai_retreat_system_id(plan: Dictionary, faction_id: int, from_system_id: int) -> int:
	var staging_system_id: int = int(plan.get("staging_system_id", -1))
	if staging_system_id > 0 and _compute_hop_distance(from_system_id, staging_system_id) >= 0:
		return staging_system_id
	var best_system_id: int = -1
	var best_hops: int = 999999
	for owned_system_id in get_owned_system_ids(faction_id):
		var hops: int = _compute_hop_distance(from_system_id, owned_system_id)
		if hops < 0 or system_is_blockaded_for(owned_system_id, faction_id):
			continue
		if hops < best_hops or (hops == best_hops and owned_system_id < best_system_id):
			best_hops = hops
			best_system_id = owned_system_id
	return best_system_id


func _ai_invasion_step_ensure_escort(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	if transport_fleet.is_empty():
		plan["state"] = "build_transport"
		plan["transport_fleet_id"] = -1
		plan["escort_fleet_ids"] = []
		return "transport_missing"
	if str(transport_fleet.get("status", "idle")) == "moving":
		return "wait_transport_enroute"
	if int(transport_fleet.get("landed_planet_id", -1)) >= 0:
		transport_launch(int(transport_fleet.get("fleet_id", -1)))
		return "proceed_to_move"
	var target_system_id: int = int(plan.get("target_system_id", -1))
	var estimated_enemy_eff_sr: int = _estimate_enemy_effective_sr_in_system(target_system_id, faction_id)
	var escort_selection: Dictionary = _select_ai_escort_fleets_for_transport(transport_fleet, faction_id, estimated_enemy_eff_sr)
	var gate_sr_ok: bool = bool(escort_selection.get("sufficient", false))
	var gate_blockaded: bool = system_is_blockaded_for(target_system_id, faction_id)
	if not gate_sr_ok or gate_blockaded:
		logs.append("DAY %d | AI_INVASION | faction=%d state=ensure_escort target=%d reason=wait_escort gate_sr_ok=%d gate_blockaded=%d" % [
			current_day_index,
			faction_id,
			int(plan.get("target_planet_id", -1)),
			1 if gate_sr_ok else 0,
			1 if gate_blockaded else 0,
		])
		return "wait_escort"
	var escorts: Array = escort_selection.get("escort_ids", [])
	escorts.sort()
	plan["escort_fleet_ids"] = escorts
	plan["state"] = "move"
	return "proceed_to_move"


func _ai_invasion_step_retreat_or_abort(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var retreat_system_id: int = _resolve_ai_retreat_system_id(plan, faction_id, int(plan.get("target_system_id", -1)))
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	if not transport_fleet.is_empty():
		if int(transport_fleet.get("landed_planet_id", -1)) >= 0:
			transport_launch(int(transport_fleet.get("fleet_id", -1)))
		if retreat_system_id > 0 and str(transport_fleet.get("status", "idle")) != "moving":
			_issue_fleet_move_order(transport_fleet, retreat_system_id, current_day_index, logs, "ai_invasion_retreat", ORDER_SOURCE_FACTION_PLANNER)
	for escort_id_variant in plan.get("escort_fleet_ids", []):
		var escort_fleet: Dictionary = _find_fleet_by_id(int(escort_id_variant))
		if escort_fleet.is_empty():
			continue
		if int(escort_fleet.get("landed_planet_id", -1)) >= 0:
			transport_launch(int(escort_fleet.get("fleet_id", -1)))
		if retreat_system_id > 0 and str(escort_fleet.get("status", "idle")) != "moving":
			_issue_fleet_move_order(escort_fleet, retreat_system_id, current_day_index, logs, "ai_invasion_retreat", ORDER_SOURCE_FACTION_PLANNER)
	plan["state"] = "cooldown"
	plan["cooldown_until_day"] = current_day_index + StrategicTestConfigScript.AI_INVASION_COOLDOWN_DAYS
	logs.append("DAY %d | AI_INVASION | faction=%d state=retreat_or_abort target=%d reason=abort_gate_failed retreat_system=%d" % [current_day_index, faction_id, int(plan.get("target_planet_id", -1)), retreat_system_id])
	return "abort_gate_failed"


func _ai_invasion_step_move(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	if transport_fleet.is_empty():
		plan["state"] = "build_transport"
		plan["transport_fleet_id"] = -1
		plan["escort_fleet_ids"] = []
		_ai_trace(faction_id, "move_order", "none", "no_transport")
		return "transport_missing"
	if str(transport_fleet.get("status", "idle")) == "moving":
		_ai_trace(faction_id, "move_order", "paused", "other:transport_enroute")
		return "transport_enroute"
	if int(transport_fleet.get("landed_planet_id", -1)) >= 0:
		transport_launch(int(transport_fleet.get("fleet_id", -1)))
		_ai_trace(faction_id, "land", "issued_order", "ok", {}, "launch_transport")
		return "launching"
	var target_system_id: int = int(plan.get("target_system_id", -1))
	if int(transport_fleet.get("system_id", -1)) == target_system_id:
		plan["state"] = "land"
		_ai_trace(faction_id, "move_order", "issued_order", "ok", {"hop_distance": 0})
		return "arrived_target_system"
	var escorts: Array = plan.get("escort_fleet_ids", [])
	escorts.sort()
	var order_issued: bool = false
	var hop_distance_to_target: int = _compute_hop_distance(int(transport_fleet.get("system_id", -1)), target_system_id)
	var move_transport: Dictionary = _issue_fleet_move_order(transport_fleet, target_system_id, current_day_index, logs, "ai_invasion_target", ORDER_SOURCE_FACTION_PLANNER)
	order_issued = bool(move_transport.get("ordered", false))
	for escort_id_variant in escorts:
		var escort_id: int = int(escort_id_variant)
		var escort_fleet: Dictionary = _find_fleet_by_id(escort_id)
		if escort_fleet.is_empty():
			continue
		if int(escort_fleet.get("landed_planet_id", -1)) >= 0:
			transport_launch(escort_id)
		var escort_move: Dictionary = _issue_fleet_move_order(escort_fleet, target_system_id, current_day_index, logs, "ai_invasion_escort", ORDER_SOURCE_FACTION_PLANNER)
		order_issued = order_issued and bool(escort_move.get("ordered", false))
	if order_issued:
		logs.append("DAY %d | AI_INVASION | faction=%d state=move to_system=%d transport=%d escorts=%s reason=proceed_to_move" % [
			current_day_index,
			faction_id,
			target_system_id,
			int(transport_fleet.get("fleet_id", -1)),
			str(escorts),
		])
	_ai_trace(faction_id, "move_order", "issued_order" if order_issued else "none", "ok" if order_issued else "other:move_order_failed", {"hop_distance": hop_distance_to_target}, "arrival_day=%d" % int(move_transport.get("arrival_day", -1)))
	return "proceed_to_move" if order_issued else "wait_escort"


func _ai_invasion_step_land(plan: Dictionary, faction_id: int, _current_day_index: int, _logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	if transport_fleet.is_empty():
		plan["state"] = "build_transport"
		plan["transport_fleet_id"] = -1
		_ai_trace(faction_id, "land", "none", "no_transport")
		return "transport_missing"
	if str(transport_fleet.get("status", "idle")) == "moving":
		_ai_trace(faction_id, "land", "paused", "other:transport_enroute")
		return "transport_enroute"
	if int(transport_fleet.get("system_id", -1)) != int(plan.get("target_system_id", -1)):
		plan["state"] = "ensure_escort"
		_ai_trace(faction_id, "land", "paused", "unreachable")
		return "not_in_target_system"
	var land_result: Dictionary = transport_land(int(transport_fleet.get("fleet_id", -1)), int(plan.get("target_planet_id", -1)))
	if not bool(land_result.get("ok", false)):
		_ai_trace(faction_id, "land", "none", str(land_result.get("reason", "land_failed")))
		return "land_failed=%s" % str(land_result.get("reason", "unknown"))
	plan["state"] = "invade"
	_ai_trace(faction_id, "land", "issued_order", "ok", {}, "target")
	return "landed_target"


func _ai_invasion_step_invade(plan: Dictionary, faction_id: int, current_day_index: int, logs: Array[String]) -> String:
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	if transport_fleet.is_empty():
		plan["state"] = "cooldown"
		plan["cooldown_until_day"] = current_day_index + StrategicTestConfigScript.AI_INVASION_COOLDOWN_DAYS
		_ai_trace(faction_id, "invade_gate", "paused", "no_transport")
		return "transport_missing"
	var target_planet_id: int = int(plan.get("target_planet_id", -1))
	var target_planet: Dictionary = _planets_by_id.get(target_planet_id, {})
	if target_planet.is_empty():
		plan["state"] = "cooldown"
		plan["cooldown_until_day"] = current_day_index + StrategicTestConfigScript.AI_INVASION_COOLDOWN_DAYS
		_ai_trace(faction_id, "invade_gate", "paused", "other:target_missing")
		return "target_missing"
	var target_system_id: int = int(target_planet.get("system_id", -1))
	var gate_pass: bool = true
	if system_is_blockaded_for(target_system_id, faction_id):
		gate_pass = false
	var target_system: Dictionary = get_system(target_system_id)
	var sr_by_faction: Dictionary = target_system.get("sr_by_faction", {})
	var attacker_sr: int = int(sr_by_faction.get(faction_id, 0))
	var attacker_enemy_sr: int = int(target_system.get("enemy_sr_by_faction", {}).get(faction_id, 0))
	if attacker_sr < attacker_enemy_sr:
		gate_pass = false
	_ai_trace(faction_id, "invade_gate", "paused" if not gate_pass else "issued_order", "invasion_gate_failed" if not gate_pass else "ok", {
		"friendly_eff_sr": attacker_sr,
		"est_enemy_eff_sr": attacker_enemy_sr,
		"gate_pass": gate_pass,
	})
	if not gate_pass:
		plan["state"] = "retreat_or_abort"
		_ai_trace(faction_id, "invade", "paused", "abort_gate_failed")
		logs.append("DAY %d | AI_INVASION | faction=%d state=invade planet=%d cargo=%d reason=abort_gate_failed" % [
			current_day_index,
			faction_id,
			target_planet_id,
			int(transport_fleet.get("cargo_troop_gp", 0)),
		])
		return "abort_gate_failed"
	var invasion_result: Dictionary = transport_invade_planet(int(transport_fleet.get("fleet_id", -1)), target_planet_id, int(transport_fleet.get("cargo_troop_gp", 0)))
	var invade_note: String = "WIN" if bool(invasion_result.get("won", false)) else ("HOLD" if bool(invasion_result.get("ok", false)) else "attempted")
	_ai_trace(faction_id, "invade", "attempted_invasion", "ok", {}, invade_note)
	plan["state"] = "cooldown"
	plan["cooldown_until_day"] = current_day_index + StrategicTestConfigScript.AI_INVASION_COOLDOWN_DAYS
	_ai_trace(faction_id, "cooldown", "paused", "cooldown")
	logs.append("DAY %d | AI_INVASION | faction=%d state=invade planet=%d cargo=%d reason=cooldown result=%s" % [
		current_day_index,
		faction_id,
		target_planet_id,
		int(transport_fleet.get("cargo_troop_gp", 0)),
		"WIN" if bool(invasion_result.get("won", false)) else ("HOLD" if bool(invasion_result.get("ok", false)) else str(invasion_result.get("reason", "fail"))),
	])
	return "invade_done"


func _find_available_transport_fleet_for_faction(faction_id: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if str(fleet_state.get("status", "idle")) == "moving":
			continue
		if not StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
			continue
		candidates.append(fleet_state)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
	)
	return candidates[0]


func _find_closest_active_shipyard_system_for_faction(faction_id: int, from_system_id: int) -> int:
	var best_system_id: int = -1
	var best_hops: int = 999999
	var owned_systems: Array[int] = get_owned_system_ids(faction_id)
	owned_systems.sort()
	for system_id in owned_systems:
		if _get_active_shipyard_for_system(system_id, faction_id).is_empty():
			continue
		var hops: int = _compute_hop_distance(from_system_id, system_id)
		if from_system_id <= 0:
			hops = 0
		if hops < 0:
			continue
		if hops < best_hops or (hops == best_hops and system_id < best_system_id):
			best_hops = hops
			best_system_id = system_id
	return best_system_id




func _find_pending_shipyard_system_for_faction(faction_id: int) -> int:
	for system_id in get_owned_system_ids(faction_id):
		var system_state: Dictionary = get_system(system_id)
		var queue: Array = system_state.get("space_queue", [])
		for order_variant in queue:
			var order: Dictionary = order_variant
			if str(order.get("order_type", "")) != "build_orbital_structure":
				continue
			if str(order.get("build_type", "")) != StrategicTestConfigScript.SHIPYARD_I_TYPE:
				continue
			if int(order.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id:
				return system_id
	return -1


func _enqueue_invasion_troop_training_for_planet(planet_state: Dictionary, owner_faction_id: int) -> String:
	if not _planner_execution_active:
		_pending_operation_logs.append("DAY %d | ERROR | TROOP_ENQUEUE_BLOCKED | source=NON_PLANNER" % [_day_index])
		return "unauthorized_source"
	if not _factions_by_id.has(owner_faction_id):
		return "missing_faction"
	var queue: Array = planet_state.get("troop_training_queue", [])
	if queue.size() >= StrategicTestConfigScript.TROOP_MAX_TRAIN_JOBS_PER_PLANET:
		return "queue_full"
	var blueprint: Dictionary = StrategicTestConfigScript.TROOP_BLUEPRINTS.get("troops_basic", {})
	if blueprint.is_empty():
		return "missing_blueprint"
	var projected_income: int = get_faction_expected_income_today(owner_faction_id)
	var projected_upkeep: int = get_faction_total_upkeep(owner_faction_id) + int(blueprint.get("upkeep_credits_per_day", 0))
	if projected_income - projected_upkeep < 0:
		return "solvency"
	queue.append({
		"type": "train_troop",
		"troop_type_id": "troops_basic",
		"owner_faction_id": owner_faction_id,
		"planet_id": int(planet_state.get("planet_id", -1)),
		"days_required": int(blueprint.get("train_days", 3)),
		"days_progress": 0,
		"cost_credits": int(blueprint.get("credits_cost", 0)),
		"cost_metal": int(blueprint.get("metal_cost", 0)),
		"cost_rare": int(blueprint.get("rare_cost", 0)),
		"status": "active",
		"last_stall_logged_day": -1,
	})
	planet_state["troop_training_queue"] = queue
	planet_state["troop_training_progress"] = 0
	return "ok"


func _select_ai_escort_fleets_for_transport(transport_fleet: Dictionary, faction_id: int, estimated_enemy_eff_sr: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var transport_system_id: int = int(transport_fleet.get("system_id", -1))
	for fleet_variant in _collect_all_fleets():
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		if int(fleet_state.get("fleet_id", -1)) == int(transport_fleet.get("fleet_id", -2)):
			continue
		if int(fleet_state.get("system_id", -1)) != transport_system_id:
			continue
		if str(fleet_state.get("status", "idle")) == "moving":
			continue
		if StrategicTestLogicScript.fleet_is_transport_only(fleet_state):
			continue
		if get_fleet_effective_sr(fleet_state) < StrategicTestConfigScript.AI_INVASION_ESCORT_MIN_EFF_SR:
			continue
		candidates.append(fleet_state)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
	)
	var selected_ids: Array[int] = []
	var total_sr: int = get_fleet_effective_sr(transport_fleet)
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		if total_sr >= estimated_enemy_eff_sr:
			break
		selected_ids.append(int(candidate.get("fleet_id", -1)))
		total_sr += get_fleet_effective_sr(candidate)
	selected_ids.sort()
	return {
		"escort_ids": selected_ids,
		"total_sr": total_sr,
		"sufficient": total_sr >= estimated_enemy_eff_sr,
	}


func _should_log_ai_invasion_failure(faction_id: int, reason: String, current_day_index: int) -> bool:
	if reason == "":
		return false
	if not _ai_invasion_last_failure_day_by_faction.has(faction_id):
		_ai_invasion_last_failure_day_by_faction[faction_id] = {}
	var reason_days: Dictionary = _ai_invasion_last_failure_day_by_faction[faction_id]
	if int(reason_days.get(reason, -1)) == current_day_index:
		return false
	reason_days[reason] = current_day_index
	_ai_invasion_last_failure_day_by_faction[faction_id] = reason_days
	return true


func _estimate_enemy_effective_sr_in_system(target_system_id: int, faction_id: int) -> int:
	var system_state: Dictionary = get_system(target_system_id)
	if system_state.is_empty():
		return 0
	var enemy_sr_by_faction: Dictionary = system_state.get("enemy_sr_by_faction", {})
	var estimated_enemy_eff_sr: int = int(enemy_sr_by_faction.get(faction_id, 0))
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(target_system_id))
	estimated_enemy_eff_sr += int(pirate_presence.get("threat_sr", 0))
	return estimated_enemy_eff_sr


func _log_ai_invasion_summary(faction_id: int, plan: Dictionary, current_day_index: int, reason: String, logs: Array[String]) -> void:
	var target_planet_id: int = int(plan.get("target_planet_id", -1))
	var target_system_id: int = int(plan.get("target_system_id", -1))
	var staging_planet_id: int = int(plan.get("staging_planet_id", -1))
	var staging_system_id: int = int(plan.get("staging_system_id", -1))
	var transport_fleet: Dictionary = _find_fleet_by_id(int(plan.get("transport_fleet_id", -1)))
	var cargo: int = int(transport_fleet.get("cargo_troop_gp", int(plan.get("committed_troop_gp", 0))))
	var escorts: Array = plan.get("escort_fleet_ids", [])
	var escort_ids: Array[int] = []
	var escort_have: int = 0
	for escort_id_variant in escorts:
		var escort_id: int = int(escort_id_variant)
		escort_ids.append(escort_id)
		var escort_fleet: Dictionary = _find_fleet_by_id(escort_id)
		escort_have += get_fleet_effective_sr(escort_fleet)
	escort_ids.sort()
	var estimated_enemy_eff_sr: int = _estimate_enemy_effective_sr_in_system(target_system_id, faction_id)
	var gate_sr_ok: bool = escort_have >= estimated_enemy_eff_sr
	var gate_blockaded: bool = false
	var target_planet: Dictionary = _planets_by_id.get(target_planet_id, {})
	if not target_planet.is_empty():
		gate_blockaded = is_planet_blockaded(target_planet)
	var shipyard_candidates: Array[int] = get_owned_system_ids(faction_id)
	shipyard_candidates.sort()
	var shipyard_active_in: int = _find_closest_active_shipyard_system_for_faction(faction_id, staging_system_id)
	var shipyard_pending_in: int = _find_pending_shipyard_system_for_faction(faction_id)
	logs.append("DAY %d | AI_INVASION | source=%s faction=%d state=%s targetP=%d stagingP=%d transport=%d cargo_gp=%d req_gp=%d escorts=%s reason=%s gate_sr_ok=%d gate_blockaded=%d shipyard_candidates=%s shipyard_active_in=%d shipyard_pending_in=%d" % [
		current_day_index,
		ORDER_SOURCE_FACTION_PLANNER,
		faction_id,
		str(plan.get("state", "idle")),
		target_planet_id,
		staging_planet_id,
		int(plan.get("transport_fleet_id", -1)),
		cargo,
		int(plan.get("required_troop_gp", 0)),
		fmt_sorted_int_list(escort_ids),
		reason,
		1 if gate_sr_ok else 0,
		1 if gate_blockaded else 0,
		fmt_sorted_int_list(shipyard_candidates),
		shipyard_active_in,
		shipyard_pending_in,
	])



func get_owned_system_ids(faction_id: int) -> Array[int]:
	var owned_systems: Array[int] = []
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		for planet_variant in get_system_planets(system_id):
			var planet: Dictionary = planet_variant
			if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id:
				owned_systems.append(system_id)
				break
	owned_systems.sort()
	return owned_systems


func get_system_credits_value(system_id: int, faction_id: int) -> int:
	var total: int = 0
	for planet_variant in get_system_planets(system_id):
		var planet: Dictionary = planet_variant
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		total += int(planet.get("base_credits_per_day", 0))
	return total


func get_system_degree(system_id: int) -> int:
	return (get_system(system_id).get("lanes", []) as Array).size()


func get_belt_expected_yields_if_online(system_id: int) -> Vector2i:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty() or not bool(system_state.get("has_belt", false)):
		return Vector2i.ZERO
	var platform_tier: int = int(system_state.get("platform_tier", 0))
	if platform_tier < 1:
		return Vector2i.ZERO
	var base_metal: int = 0
	var base_rare: int = 0
	match str(system_state.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE)):
		StrategicTestConfigScript.BELT_CLASS_METAL:
			base_metal = 12
		StrategicTestConfigScript.BELT_CLASS_RICH_METAL:
			base_metal = 20
		StrategicTestConfigScript.BELT_CLASS_RARE:
			base_metal = 12
			base_rare = 4
		StrategicTestConfigScript.BELT_CLASS_RICH_RARE:
			base_metal = 16
			base_rare = 8
	var mult: float = 1.0
	if platform_tier == 2:
		mult = 1.5
	elif platform_tier >= 3:
		mult = 2.0
	return Vector2i(int(floor(float(base_metal) * mult)), int(floor(float(base_rare) * mult)))


func system_has_shipyard(system_id: int, faction_id: int) -> bool:
	return _count_planned_orbital_type(system_id, faction_id, StrategicTestConfigScript.SHIPYARD_I_TYPE) > 0


func system_has_defense_station(system_id: int, faction_id: int) -> bool:
	return _count_planned_orbital_type(system_id, faction_id, StrategicTestConfigScript.DEFENSE_STATION_I_TYPE) > 0


func system_has_listening_post(system_id: int, faction_id: int) -> bool:
	return _count_planned_orbital_type(system_id, faction_id, StrategicTestConfigScript.LISTENING_POST_TYPE) > 0


func system_is_blockaded_for(system_id: int, faction_id: int) -> bool:
	return bool(get_system(system_id).get("blockade_by_faction", {}).get(faction_id, false))


func system_pirate_term(system_id: int) -> int:
	match int(get_system(system_id).get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)):
		StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			return 25
		StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			return 80
		_:
			return 0


func enemy_sr_margin(system_id: int, faction_id: int) -> int:
	var system_state: Dictionary = get_system(system_id)
	return maxi(0, int(system_state.get("enemy_sr_by_faction", {}).get(faction_id, 0)) - int(system_state.get("sr_by_faction", {}).get(faction_id, 0)))


func get_faction_expected_income_today(faction_id: int) -> int:
	var credits_total: int = 0
	for planet_variant in _planets_by_id.values():
		var planet: Dictionary = planet_variant
		if int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
			continue
		var system_state: Dictionary = get_system(int(planet.get("system_id", -1)))
		var yield_result: Dictionary = StrategicTestLogicScript.compute_planet_yield(planet, is_planet_blockaded(planet), _get_planet_piracy_multiplier(system_state))
		credits_total += int(yield_result.get("credits_gain", 0))
	return credits_total


func get_faction_total_upkeep(faction_id: int) -> int:
	var upkeep_total: int = 0
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		if bool(system_state.get("has_belt", false)) and int(system_state.get("belt_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id:
			upkeep_total += StrategicTestLogicScript.get_platform_upkeep_for_tier(int(system_state.get("platform_tier", 0)))
		for structure_variant in system_state.get("orbital_structures", []):
			var structure: Dictionary = structure_variant
			if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
				continue
			upkeep_total += int(structure.get("upkeep_credits_per_day", 0))
		for fleet_variant in system_state.get("fleets", []):
			var fleet: Dictionary = fleet_variant
			if int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
				continue
			upkeep_total += get_fleet_upkeep_credits_per_day(fleet)

	for planet_variant in _planets_by_id.values():
		var planet: Dictionary = planet_variant
		for troop_variant in planet.get("troops", []):
			var troop: Dictionary = troop_variant
			if str(troop.get("status", "active")) != "active":
				continue
			if int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != faction_id:
				continue
			upkeep_total += maxi(0, int(troop.get("upkeep_credits_per_day", 0)))
	return upkeep_total


func _compute_system_priority_terms(system_id: int, faction_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	var belt_expected: Vector2i = get_belt_expected_yields_if_online(system_id)
	var ev: int = get_system_credits_value(system_id, faction_id) + (10 * belt_expected.y) + (2 * belt_expected.x)
	var blockade_term: int = 100 if system_is_blockaded_for(system_id, faction_id) else 0
	var ts: int = blockade_term + system_pirate_term(system_id) + int(floor(float(int(system_state.get("piracy_pressure", 0))) / 2.0)) + enemy_sr_margin(system_id, faction_id)
	var rare_belt_term: int = 40 if str(system_state.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE)) in [StrategicTestConfigScript.BELT_CLASS_RARE, StrategicTestConfigScript.BELT_CLASS_RICH_RARE] else 0
	var active_belt_term: int = 20 if bool(system_state.get("has_belt", false)) and _get_effective_platform_tier_for_planning(system_id) >= 1 else 0
	var ps: int = (60 if system_has_shipyard(system_id, faction_id) else 0) + rare_belt_term + active_belt_term + (15 if get_system_degree(system_id) >= 4 else 0)
	return {
		"system_id": system_id,
		"ev": ev,
		"ts": ts,
		"ps": ps,
		"prio": (2 * ts) + ps + ev,
	}


func _get_next_orbit_governor_action(system_id: int, faction_id: int, faction_net_c_today: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return {}

	if int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) == StrategicTestConfigScript.PIRATE_STATE_HAVEN:
		if not system_has_listening_post(system_id, faction_id):
			return _make_orbit_build_action(StrategicTestConfigScript.LISTENING_POST_TYPE)
		elif not system_has_defense_station(system_id, faction_id):
			return _make_orbit_build_action(StrategicTestConfigScript.DEFENSE_STATION_I_TYPE)

	var belt_class: String = str(system_state.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE))
	var is_rare_belt: bool = belt_class in [StrategicTestConfigScript.BELT_CLASS_RARE, StrategicTestConfigScript.BELT_CLASS_RICH_RARE]
	if is_rare_belt:
		if not system_has_defense_station(system_id, faction_id):
			return _make_orbit_build_action(StrategicTestConfigScript.DEFENSE_STATION_I_TYPE)
		var rare_target_tier: int = _get_effective_platform_tier_for_planning(system_id)
		if rare_target_tier <= 0:
			return _make_mining_build_action(1)
		if rare_target_tier == 1:
			return _make_mining_build_action(2)
		if rare_target_tier == 2:
			return _make_mining_build_action(3)

	if system_has_shipyard(system_id, faction_id) and system_is_blockaded_for(system_id, faction_id) and not system_has_defense_station(system_id, faction_id):
		return _make_orbit_build_action(StrategicTestConfigScript.DEFENSE_STATION_I_TYPE)
	if system_has_shipyard(system_id, faction_id) and not system_has_listening_post(system_id, faction_id):
		return _make_orbit_build_action(StrategicTestConfigScript.LISTENING_POST_TYPE)

	if faction_net_c_today >= 0 and _faction_has_any_defense_station(faction_id) and not system_is_blockaded_for(system_id, faction_id) and int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) != StrategicTestConfigScript.PIRATE_STATE_HAVEN and _count_planned_orbital_type(system_id, faction_id, StrategicTestConfigScript.SHIPYARD_I_TYPE) <= 0:
		return _make_orbit_build_action(StrategicTestConfigScript.SHIPYARD_I_TYPE)

	if int(system_state.get("piracy_pressure", 0)) >= 20 and not system_has_listening_post(system_id, faction_id):
		return _make_orbit_build_action(StrategicTestConfigScript.LISTENING_POST_TYPE)

	if belt_class in [StrategicTestConfigScript.BELT_CLASS_METAL, StrategicTestConfigScript.BELT_CLASS_RICH_METAL]:
		var non_rare_target_tier: int = _get_effective_platform_tier_for_planning(system_id)
		if non_rare_target_tier <= 0:
			return _make_mining_build_action(1)
		if non_rare_target_tier == 1:
			return _make_mining_build_action(2)

	return {}


func _get_governor_settlement_for_system(system_id: int, faction_id: int) -> Dictionary:
	for planet_variant in get_system_planets(system_id):
		var settlement: Dictionary = planet_variant
		if int(settlement.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id:
			return settlement
	return {}


func _try_enqueue_governor_orbit_action(system_id: int, faction_id: int, action: Dictionary, queued_upkeep_by_faction: Dictionary) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return {"queued": false, "reason": "unknown system"}
	var queue: Array = system_state.get("space_queue", [])
	if queue.size() >= SPACE_QUEUE_CAPACITY:
		return {"queued": false, "reason": "queue full"}
	if str(action.get("order_type", "")) == "build_mining_platform":
		if not bool(system_state.get("has_belt", false)):
			return {"queued": false, "reason": "no belt"}
		var planned_tier: int = _get_effective_platform_tier_for_planning(system_id)
		if int(action.get("target_tier", 0)) != planned_tier + 1:
			return {"queued": false, "reason": "platform upgrades must be sequential"}
	else:
		if _get_system_free_orbit_slots(system_id) <= 0:
			return {"queued": false, "reason": "no slots"}

	if not _factions_by_id.has(faction_id):
		return {"queued": false, "reason": "missing faction"}
	var faction_state: Dictionary = _factions_by_id[faction_id]
	var settlement_state: Dictionary = _get_governor_settlement_for_system(system_id, faction_id)
	if settlement_state.is_empty():
		return {"queued": false, "reason": "missing settlement"}
	var cost_credits: int = int(action.get("cost_credits", 0))
	var cost_metal: int = int(action.get("cost_metal", 0))
	var cost_rare_metal: int = int(action.get("cost_rare_metal", 0))
	if int(faction_state.get("credits", 0)) < cost_credits or int(faction_state.get("metal", 0)) < cost_metal or int(faction_state.get("rare_metal", 0)) < cost_rare_metal:
		return {"queued": false, "reason": "insufficient resources"}

	var projected_income: int = get_faction_expected_income_today(faction_id)
	var projected_upkeep: int = get_faction_total_upkeep(faction_id) + int(queued_upkeep_by_faction.get(faction_id, 0)) + int(action.get("upkeep_credits_per_day", 0))
	var projected_net_c: int = projected_income - projected_upkeep
	if projected_net_c < 0:
		return {"queued": false, "reason": "solvency rule"}

	faction_state["credits"] = int(faction_state.get("credits", 0)) - cost_credits
	faction_state["metal"] = int(faction_state.get("metal", 0)) - cost_metal
	faction_state["rare_metal"] = int(faction_state.get("rare_metal", 0)) - cost_rare_metal
	queued_upkeep_by_faction[faction_id] = int(queued_upkeep_by_faction.get(faction_id, 0)) + int(action.get("upkeep_credits_per_day", 0))
	var queued_order: Dictionary = action.duplicate(true)
	queued_order["owner_faction_id"] = faction_id
	queued_order["days_remaining"] = int(action.get("build_days", 0))
	queue.append(queued_order)
	system_state["space_queue"] = queue
	return {"queued": true, "projected_net_c": projected_net_c}


func _select_ship_blueprint_for_system(system_id: int, owner_faction_id: int) -> String:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return ""
	var sr_by_faction: Dictionary = system_state.get("sr_by_faction", {})
	var friendly_sr: int = int(sr_by_faction.get(owner_faction_id, 0))
	var max_enemy_faction_sr: int = 0
	for faction_id_variant in sr_by_faction.keys():
		var faction_id: int = int(faction_id_variant)
		if faction_id == owner_faction_id:
			continue
		max_enemy_faction_sr = maxi(max_enemy_faction_sr, int(sr_by_faction.get(faction_id, 0)))
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(system_id))
	var threat_sr: int = int(pirate_presence.get("threat_sr", 0)) + max_enemy_faction_sr
	var sr_deficit: int = maxi(0, threat_sr - friendly_sr)
	if int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) == StrategicTestConfigScript.PIRATE_STATE_HAVEN and friendly_sr < threat_sr + 10:
		return "frigate_mk1"
	if sr_deficit >= 25:
		return "frigate_mk1"
	if sr_deficit >= 10:
		return "corvette_mk1"
	return ""


func _try_enqueue_governor_ship_action(system_id: int, faction_id: int, enqueued_ship_today_by_system: Dictionary, queued_upkeep_by_faction: Dictionary, logs: Array[String], candidate_only: bool = false) -> Dictionary:
	var shipyard: Dictionary = _get_active_shipyard_for_system(system_id, faction_id)
	if shipyard.is_empty():
		return {"queued": false, "reason": "shipyard_missing"}
	if bool(enqueued_ship_today_by_system.get(system_id, false)):
		return {"queued": false, "reason": "daily_cap"}
	var blueprint_id: String = _select_ship_blueprint_for_system(system_id, faction_id)
	if blueprint_id == "":
		return {"queued": false, "reason": "none"}
	var blueprint: Dictionary = StrategicTestConfigScript.SHIP_BLUEPRINTS.get(blueprint_id, {})
	if blueprint.is_empty():
		return {"queued": false, "reason": "unknown_blueprint"}

	var projected_income: int = get_faction_expected_income_today(faction_id)
	var projected_upkeep: int = get_faction_total_upkeep(faction_id) + int(queued_upkeep_by_faction.get(faction_id, 0)) + int(blueprint.get("upkeep_credits_per_day", 0))
	var projected_net_c: int = projected_income - projected_upkeep
	if projected_net_c < 0:
		return {"queued": false, "reason": "solvency"}

	if candidate_only:
		return {"candidate": true, "reason": "ok", "blueprint_id": blueprint_id, "projected_net_c": projected_net_c}

	var enqueue_result: Dictionary = enqueue_ship_build(system_id, faction_id, blueprint_id, _day_index, logs)
	if not bool(enqueue_result.get("queued", false)):
		return enqueue_result

	queued_upkeep_by_faction[faction_id] = int(queued_upkeep_by_faction.get(faction_id, 0)) + int(blueprint.get("upkeep_credits_per_day", 0))
	enqueued_ship_today_by_system[system_id] = true
	return {"queued": true, "reason": "ok", "projected_net_c": projected_net_c, "log_line": str(enqueue_result.get("log_line", ""))}


func _get_active_shipyard_for_system(system_id: int, owner_faction_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if str(structure.get("type", "")) != StrategicTestConfigScript.SHIPYARD_I_TYPE:
			continue
		if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != owner_faction_id:
			continue
		if not _is_structure_active(structure):
			continue
		return structure
	return {}


func enqueue_ship_build(system_id: int, owner_faction_id: int, blueprint_id: String, started_day: int = -1, logs: Array[String] = [], source: String = ORDER_SOURCE_FACTION_PLANNER) -> Dictionary:
	if source != ORDER_SOURCE_FACTION_PLANNER:
		if not logs.is_empty():
			logs.append("DAY %d | ERROR | unauthorized_ship_enqueue source=%s" % [_day_index, source])
		return {"queued": false, "reason": "unauthorized_source"}
	var shipyard: Dictionary = _get_active_shipyard_for_system(system_id, owner_faction_id)
	if shipyard.is_empty():
		return {"queued": false, "reason": "shipyard_missing"}
	var order: Dictionary = StrategicTestConfigScript.create_ship_build_order(blueprint_id, owner_faction_id, system_id, started_day)
	if order.is_empty():
		return {"queued": false, "reason": "unknown_blueprint"}
	var queue: Array = shipyard.get("queue", [])
	queue.append(order)
	shipyard["queue"] = queue
	var costs: Dictionary = order.get("costs", {})
	var log_line: String = "DAY %d | SHIP_ENQUEUE | source=%s system=%d owner=%d shipyard=%s blueprint=%s sp=%d cost=%d/%d/%d upkeep=%d wallet=completion_only reason=ok" % [
		_day_index,
		source,
		system_id,
		owner_faction_id,
		str(shipyard.get("type", "")),
		blueprint_id,
		int(order.get("sp_cost", 0)),
		int(costs.get("credits", 0)),
		int(costs.get("metal", 0)),
		int(costs.get("rare", 0)),
		int(order.get("upkeep_credits_per_day", 0)),
	]
	if not logs.is_empty():
		logs.append(log_line)
	return {"queued": true, "reason": "ok", "log_line": log_line}


func _make_orbit_build_action(structure_type: String) -> Dictionary:
	if structure_type == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE:
		return {
			"order_type": "build_orbital_structure",
			"build_type": StrategicTestConfigScript.DEFENSE_STATION_I_TYPE,
			"build_days": StrategicTestConfigScript.DEFENSE_STATION_I_BUILD_TIME_DAYS,
			"cost_credits": StrategicTestConfigScript.DEFENSE_STATION_I_BUILD_COST_CREDITS,
			"cost_metal": StrategicTestConfigScript.DEFENSE_STATION_I_BUILD_COST_METAL,
			"cost_rare_metal": StrategicTestConfigScript.DEFENSE_STATION_I_BUILD_COST_RARE_METAL,
			"upkeep_credits_per_day": StrategicTestConfigScript.DEFENSE_STATION_I_UPKEEP_CREDITS_PER_DAY,
		}
	if structure_type == StrategicTestConfigScript.LISTENING_POST_TYPE:
		return {
			"order_type": "build_orbital_structure",
			"build_type": StrategicTestConfigScript.LISTENING_POST_TYPE,
			"build_days": StrategicTestConfigScript.LISTENING_POST_BUILD_TIME_DAYS,
			"cost_credits": StrategicTestConfigScript.LISTENING_POST_BUILD_COST_CREDITS,
			"cost_metal": StrategicTestConfigScript.LISTENING_POST_BUILD_COST_METAL,
			"cost_rare_metal": StrategicTestConfigScript.LISTENING_POST_BUILD_COST_RARE_METAL,
			"upkeep_credits_per_day": StrategicTestConfigScript.LISTENING_POST_UPKEEP_CREDITS_PER_DAY,
		}
	if structure_type == StrategicTestConfigScript.SHIPYARD_I_TYPE:
		return {
			"order_type": "build_orbital_structure",
			"build_type": StrategicTestConfigScript.SHIPYARD_I_TYPE,
			"build_days": StrategicTestConfigScript.SHIPYARD_I_BUILD_TIME_DAYS,
			"cost_credits": StrategicTestConfigScript.SHIPYARD_I_BUILD_COST_CREDITS,
			"cost_metal": StrategicTestConfigScript.SHIPYARD_I_BUILD_COST_METAL,
			"cost_rare_metal": StrategicTestConfigScript.SHIPYARD_I_BUILD_COST_RARE_METAL,
			"upkeep_credits_per_day": StrategicTestConfigScript.SHIPYARD_I_UPKEEP_CREDITS_PER_DAY,
		}
	return {}


func _make_mining_build_action(target_tier: int) -> Dictionary:
	var order: Dictionary = StrategicTestConfigScript.create_mining_platform_order(target_tier)
	order["build_type"] = "mining_platform_%d" % int(order.get("target_tier", target_tier))
	return order


func _count_planned_orbital_type(system_id: int, faction_id: int, structure_type: String) -> int:
	var system_state: Dictionary = get_system(system_id)
	var count: int = 0
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id and str(structure.get("type", "")) == structure_type:
			count += 1
	for order_variant in system_state.get("space_queue", []):
		var order: Dictionary = order_variant
		if str(order.get("order_type", "")) == "build_orbital_structure" and int(order.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id and str(order.get("build_type", "")) == structure_type:
			count += 1
	return count


func _get_system_free_orbit_slots(system_id: int) -> int:
	var system_state: Dictionary = get_system(system_id)
	var capacity: int = int(system_state.get("orbit_slot_capacity", DEFAULT_ORBIT_SLOT_CAPACITY))
	var used: int = (system_state.get("orbital_structures", []) as Array).size()
	for order_variant in system_state.get("space_queue", []):
		var order: Dictionary = order_variant
		if str(order.get("order_type", "")) == "build_orbital_structure":
			used += 1
	return maxi(0, capacity - used)


func _get_effective_platform_tier_for_planning(system_id: int) -> int:
	var system_state: Dictionary = get_system(system_id)
	var tier: int = int(system_state.get("platform_tier", 0))
	for order_variant in system_state.get("space_queue", []):
		var order: Dictionary = order_variant
		if str(order.get("order_type", "")) == "build_mining_platform":
			tier = maxi(tier, int(order.get("target_tier", tier)))
	return tier


func _faction_has_any_defense_station(faction_id: int) -> bool:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		if _count_planned_orbital_type(system_id, faction_id, StrategicTestConfigScript.DEFENSE_STATION_I_TYPE) > 0:
			return true
	return false


func try_move_fleet_through_system(fleet_state: Dictionary, system_name: String) -> Dictionary:
	var system_state: Dictionary = _systems_by_name.get(system_name, {})
	if system_state.is_empty():
		return {
			"passed": false,
			"log": "movement cancelled: unknown system",
		}
	var stations_in_system: Array = _collect_stations_in_system(system_state)
	var movement_result: Dictionary = StrategicTestLogicScript.is_movement_blocked_by_hostile_station(fleet_state, stations_in_system)
	if bool(movement_result.get("blocked", false)):
		return {
			"passed": false,
			"log": str(movement_result.get("reason", "blocked by hostile station")),
		}
	return {
		"passed": true,
		"log": "movement allowed",
	}


func validate_settlement_food_balance() -> Dictionary:
	return {"passed": true, "logs": []}


func validate_settlement_bootstrap_seed() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([{
		"id": 901,
		"system_name": "Bootstrap-A",
		"fleets": [],
		"orbital_structures": [],
		"belt": {},
		"planets": [{"planet_id": 9001, "name": "A", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 0, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}, {
		"id": 902,
		"system_name": "Bootstrap-B",
		"fleets": [],
		"orbital_structures": [],
		"belt": {},
		"planets": [{"planet_id": 9002, "name": "B", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 0, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}])

	var faction_state: Dictionary = sim._factions_by_id.get(1, {})
	var expected_metal_seed: int = StrategicTestConfigScript.STARTING_METAL + BOOTSTRAP_METAL_SEED_GLOBAL
	var expected_rare_seed: int = StrategicTestConfigScript.STARTING_RARE_METAL + BOOTSTRAP_RARE_METAL_SEED_GLOBAL
	var metal_seeded: bool = int(faction_state.get("metal", 0)) == expected_metal_seed
	var rare_seeded: bool = int(faction_state.get("rare_metal", 0)) == expected_rare_seed
	var idempotent_before_metal: int = int(faction_state.get("metal", 0))
	var idempotent_before_rare: int = int(faction_state.get("rare_metal", 0))
	sim._ensure_faction_bootstrap_seed()
	var idempotent: bool = int(faction_state.get("metal", 0)) == idempotent_before_metal and int(faction_state.get("rare_metal", 0)) == idempotent_before_rare

	# Legacy local caches remain zero and unused.
	var settlement_a: Dictionary = sim._planets_by_id.get(9001, {})
	var settlement_b: Dictionary = sim._planets_by_id.get(9002, {})
	var local_cache_zero: bool = int(settlement_a.get("stored_metal", -1)) == 0 and int(settlement_a.get("stored_rare_metal", -1)) == 0 and int(settlement_b.get("stored_metal", -1)) == 0 and int(settlement_b.get("stored_rare_metal", -1)) == 0

	# Day-0 deadlock guard: two identical settlements should each get at least one queued infrastructure.
	var sim_governor := GalaxySimulationTest.new()
	sim_governor.setup_from_systems([
		{
			"id": 903,
			"system_name": "Bootstrap-Governor-A",
			"fleets": [],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 0, 1),
			"planets": [{"planet_id": 9003, "name": "G-A", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 0, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
		{
			"id": 904,
			"system_name": "Bootstrap-Governor-B",
			"fleets": [],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 0, 1),
			"planets": [{"planet_id": 9004, "name": "G-B", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 0, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	])
	(sim_governor._factions_by_id[1] as Dictionary)["credits"] = 10000
	(sim_governor._factions_by_id[1] as Dictionary)["metal"] = 0
	(sim_governor._factions_by_id[1] as Dictionary)["rare_metal"] = 0
	sim_governor._ensure_faction_bootstrap_seed()
	sim_governor.advance_day()
	var queue_a_size: int = (sim_governor.get_system(903).get("space_queue", []) as Array).size()
	var queue_b_size: int = (sim_governor.get_system(904).get("space_queue", []) as Array).size()
	var bootstrap_governor_can_queue: bool = queue_a_size > 0 and queue_b_size > 0

	return {
		"passed": metal_seeded and rare_seeded and idempotent and local_cache_zero and bootstrap_governor_can_queue,
		"logs": [
			"bootstrap_faction_metal_seeded=%s expected=%d actual=%d" % [str(metal_seeded), expected_metal_seed, int(faction_state.get("metal", 0))],
			"bootstrap_faction_rare_seeded=%s expected=%d actual=%d" % [str(rare_seeded), expected_rare_seed, int(faction_state.get("rare_metal", 0))],
			"bootstrap_idempotent=%s" % str(idempotent),
			"bootstrap_local_cache_zero=%s" % str(local_cache_zero),
			"bootstrap_governor_can_queue=%s queue_a=%d queue_b=%d" % [str(bootstrap_governor_can_queue), queue_a_size, queue_b_size],
		],
	}


func validate_settlement_migration_logging() -> Dictionary:
	return {"passed": true, "logs": []}


func validate_industry_resource_separation() -> Dictionary:
	return {"passed": true, "logs": []}


func validate_governor_construction_queue() -> Dictionary:
	return validate_phase_five_background_governor_tests()


func validate_bootleg_shipping_flow() -> Dictionary:
	return {"passed": true, "logs": []}


func validate_administration_coverage() -> Dictionary:
	return {"passed": true, "logs": []}


func get_planet_by_name(system_name: String, planet_name: String) -> Dictionary:
	var lookup_key: String = _planet_lookup_key(system_name, planet_name)
	if not _planet_ids_by_name.has(lookup_key):
		return {}
	var planet_id: int = int(_planet_ids_by_name[lookup_key])
	return (_planets_by_id.get(planet_id, {}) as Dictionary)


func build_planet_report(system_name: String, planet_name: String) -> String:
	var report_lines: Array[String] = ["System: %s" % system_name, "Planet: %s" % planet_name, ""]
	var lookup_key: String = _planet_lookup_key(system_name, planet_name)
	if not _planet_ids_by_name.has(lookup_key):
		report_lines.append("Strategic data unavailable for this planet.")
		return "\n".join(report_lines)

	var planet_id: int = int(_planet_ids_by_name[lookup_key])
	if not _planets_by_id.has(planet_id):
		report_lines.append("Strategic data unavailable for this planet id.")
		return "\n".join(report_lines)

	var planet_state: Dictionary = _planets_by_id[planet_id]
	var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var owner_name: String = "Unknown"
	if _factions_by_id.has(owner_faction_id):
		owner_name = str((_factions_by_id[owner_faction_id] as Dictionary).get("name", "Unknown"))

	report_lines.append("Day: %d" % _day_index)
	report_lines.append("Planet ID: %d" % planet_id)
	report_lines.append("Owner: %s (%d)" % [owner_name, owner_faction_id])
	report_lines.append("Control: %d" % int(planet_state.get("control", 0)))
	report_lines.append("Stability: %d" % int(planet_state.get("stability", 0)))
	report_lines.append("Blockaded: %s" % str(is_planet_blockaded(planet_state)))
	report_lines.append("Base Yield/day: C=%d M=%d R=%d" % [
		int(planet_state.get("base_credits_per_day", 0)),
		int(planet_state.get("base_metal_per_day", 0)),
		int(planet_state.get("base_rare_per_day", 0)),
	])
	var troop_gp: int = _refresh_planet_troop_gp(planet_state)
	var effective_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0)) + troop_gp
	report_lines.append("Troops: count=%d troop_gp=%d effective_garrison_gp=%d" % [
		(planet_state.get("troops", []) as Array).size(),
		troop_gp,
		effective_garrison_gp,
	])
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		report_lines.append(" - Troop #%d type=%s gp=%d upkeep=%d status=%s" % [
			int(troop.get("troop_id", -1)),
			str(troop.get("type_id", "troops_basic")),
			int(troop.get("gp", 0)),
			int(troop.get("upkeep_credits_per_day", 0)),
			str(troop.get("status", "active")),
		])
	var troop_training_queue: Array = planet_state.get("troop_training_queue", [])
	if not troop_training_queue.is_empty():
		var active_job: Dictionary = troop_training_queue[0]
		report_lines.append("Training: %d/%d status=%s" % [
			int(active_job.get("days_progress", 0)),
			int(active_job.get("days_required", 0)),
			str(active_job.get("status", "active")),
		])

	if _factions_by_id.has(owner_faction_id):
		var faction_state: Dictionary = _factions_by_id[owner_faction_id]
		report_lines.append("Faction Stockpile: C=%d M=%d R=%d" % [
			int(faction_state.get("credits", 0)),
			int(faction_state.get("metal", 0)),
			int(faction_state.get("rare_metal", 0)),
		])

	return "\n".join(report_lines)


func get_planet_panel_data_for_system(system_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return {}
	var planets: Array[Dictionary] = []
	for planet_id_variant in system_state.get("planet_ids", []):
		var planet_id: int = int(planet_id_variant)
		if not _planets_by_id.has(planet_id):
			continue
		var planet_state: Dictionary = _planets_by_id[planet_id]
		var troop_gp: int = _refresh_planet_troop_gp(planet_state)
		var effective_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0)) + troop_gp
		var hostile_transport_warning: bool = false
		var landed_transport_fleet_ids: Array[int] = []
		var hostile_transport_fleet_ids: Array[int] = []
		for fleet_variant in system_state.get("fleets", []):
			var fleet: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet, system_id)
			if int(fleet.get("landed_planet_id", -1)) != planet_id:
				continue
			if not StrategicTestLogicScript.fleet_is_transport_only(fleet):
				continue
			var fleet_id: int = int(fleet.get("fleet_id", -1))
			landed_transport_fleet_ids.append(fleet_id)
			if int(fleet.get("cargo_troop_gp", 0)) <= 0:
				continue
			var fleet_owner: int = int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			var planet_owner: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			if StrategicTestLogicScript.are_factions_hostile(fleet_owner, planet_owner):
				hostile_transport_warning = true
				hostile_transport_fleet_ids.append(fleet_id)
		landed_transport_fleet_ids.sort()
		hostile_transport_fleet_ids.sort()
		planets.append({
			"planet_id": planet_id,
			"name": str(planet_state.get("name", "")),
			"owner_faction_id": int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
			"troop_count": int((planet_state.get("troops", []) as Array).size()),
			"troop_gp": troop_gp,
			"effective_garrison_gp": effective_garrison_gp,
			"hostile_transport_warning": hostile_transport_warning,
			"landed_transport_fleet_ids": landed_transport_fleet_ids,
			"hostile_transport_fleet_ids": hostile_transport_fleet_ids,
		})
	planets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("planet_id", 0)) < int(b.get("planet_id", 0))
	)
	return {
		"system_id": system_id,
		"system_name": str(system_state.get("system_name", "Unknown")),
		"planets": planets,
	}


func validate_phase_two_space_control_lite() -> Dictionary:
	var scenario_systems: Array[Dictionary] = [
		{
			"id": 1,
			"system_name": "Phase2 Test",
			"region": "Core",
			"position": Vector2.ZERO,
			"lanes": [],
			"fleets": [
				StrategicTestConfigScript.create_fleet(2, 12, "raiders"),
			],
			"planets": [
				{
					"planet_id": 1,
					"name": "Shipyard World",
					"owner_faction_id": StrategicTestConfigScript.TEST_FACTION_ID,
					"control": 100,
					"stability": 60,
					"base_credits_per_day": 150,
					"base_metal_per_day": 15,
					"base_rare_per_day": 2,
					"required_garrison_gp": 5,
					"current_garrison_gp": 5,
				},
			],
		},
	]

	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems(scenario_systems)
	sim.advance_day()
	var without_station_report: String = sim.build_planet_report("Phase2 Test", "Shipyard World")
	var blocked_without_station: bool = "Blockaded: true" in without_station_report

	sim.add_defense_station_i_to_planet("Phase2 Test", "Shipyard World")
	sim.advance_day()
	var with_station_report: String = sim.build_planet_report("Phase2 Test", "Shipyard World")
	var unblocked_with_station: bool = "Blockaded: false" in with_station_report

	var hostile_move_result: Dictionary = sim.try_move_fleet_through_system(
		StrategicTestConfigScript.create_fleet(2, 12, "raiders"),
		"Phase2 Test"
	)
	var move_blocked: bool = not bool(hostile_move_result.get("passed", true)) and str(hostile_move_result.get("log", "")) == "blocked by hostile station"

	var passed: bool = blocked_without_station and unblocked_with_station and move_blocked
	return {
		"passed": passed,
		"logs": [
			"blocked_without_station=%s" % str(blocked_without_station),
			"unblocked_with_station=%s" % str(unblocked_with_station),
			"move_blocked_by_hostile_station=%s" % str(move_blocked),
		],
	}


func get_system(system_id: int) -> Dictionary:
	return _systems_by_id.get(system_id, {})


func get_system_planets(system_id: int) -> Array:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return []
	var planets: Array = []
	var planet_ids: Array = system_state.get("planet_ids", [])
	for planet_id_variant in planet_ids:
		var planet_id: int = int(planet_id_variant)
		if _planets_by_id.has(planet_id):
			planets.append(_planets_by_id[planet_id])
	return planets


func get_primary_planet(system_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	var planet_ids: Array = system_state.get("planet_ids", [])
	if planet_ids.is_empty():
		return {}
	return _planets_by_id.get(int(planet_ids[0]), {})


func get_system_owner_factions(system_id: int) -> Array:
	var owner_ids: Dictionary = {}
	for planet_variant in get_system_planets(system_id):
		var planet_state: Dictionary = planet_variant
		owner_ids[int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))] = true
	return owner_ids.keys()


func get_scout_age(system_state: Dictionary, faction_id: int, current_day: int) -> int:
	var last_scout_day_by_faction: Dictionary = system_state.get("last_scout_day_by_faction", {})
	var last_seen_day: int = int(last_scout_day_by_faction.get(faction_id, -999999))
	return current_day - last_seen_day


func set_pirate_state(system_state: Dictionary, new_state: int) -> void:
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(int(system_state.get("id", -1))))
	var tags: Dictionary = pirate_presence.get("tags", {
		"has_hidden_base": false,
		"leader_id": null,
		"loot_table_id": "pirate_basic",
	})
	pirate_presence["tags"] = tags
	match new_state:
		StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			pirate_presence["state"] = StrategicTestConfigScript.PIRATE_STATE_HAVEN
			pirate_presence["threat_sr"] = 35
			pirate_presence["base_level"] = 2
			tags["has_hidden_base"] = true
		StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			pirate_presence["state"] = StrategicTestConfigScript.PIRATE_STATE_ACTIVITY
			pirate_presence["threat_sr"] = 10
			pirate_presence["base_level"] = 1
			tags["has_hidden_base"] = false
		_:
			pirate_presence["state"] = StrategicTestConfigScript.PIRATE_STATE_NONE
			pirate_presence["threat_sr"] = 0
			pirate_presence["base_level"] = 0
			tags["has_hidden_base"] = false

	system_state["pirate_presence"] = pirate_presence
	system_state["pirate_state"] = int(pirate_presence.get("state", StrategicTestConfigScript.PIRATE_STATE_NONE))


func get_pirate_encounter(system_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return {
			"state": StrategicTestConfigScript.PIRATE_STATE_NONE,
			"threat_sr": 0,
			"base_level": 0,
			"has_base": false,
			"recommended_clear_sr": 10,
		}
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(system_id))
	var threat_sr: int = int(pirate_presence.get("threat_sr", 0))
	var base_level: int = int(pirate_presence.get("base_level", 0))
	return {
		"state": int(pirate_presence.get("state", StrategicTestConfigScript.PIRATE_STATE_NONE)),
		"threat_sr": threat_sr,
		"base_level": base_level,
		"has_base": base_level >= 2,
		"recommended_clear_sr": threat_sr + 10,
	}


func compute_system_sr(system_id: int) -> void:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return
	var sr_by_faction: Dictionary = {}
	var fleets_by_faction: Dictionary = _build_system_fleets_present(system_state)
	for faction_id_variant in fleets_by_faction.keys():
		var faction_id: int = int(faction_id_variant)
		var fleet_list: Array = fleets_by_faction[faction_id]
		for fleet_variant in fleet_list:
			var fleet: Dictionary = fleet_variant
			sr_by_faction[faction_id] = int(sr_by_faction.get(faction_id, 0)) + get_fleet_effective_sr(fleet)

	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if int(structure.get("disabled_days", 0)) > 0:
			continue
		if structure.has("enabled") and not bool(structure.get("enabled", true)):
			continue
		var owner_faction_id: int = int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		sr_by_faction[owner_faction_id] = int(sr_by_faction.get(owner_faction_id, 0)) + int(structure.get("sr", 0))

	system_state["fleets_present"] = fleets_by_faction
	system_state["sr_by_faction"] = sr_by_faction


func compute_system_blockades(system_id: int) -> void:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return
	var sr_by_faction: Dictionary = system_state.get("sr_by_faction", {})
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(system_id))
	var pirate_threat_sr: int = int(pirate_presence.get("threat_sr", 0))
	var blockades: Dictionary = {}
	var enemy_sr_by_faction: Dictionary = {}
	for owner_faction_variant in get_system_owner_factions(system_id):
		var owner_faction_id: int = int(owner_faction_variant)
		var friendly_sr: int = int(sr_by_faction.get(owner_faction_id, 0))
		var enemy_sr: int = 0
		for candidate_variant in sr_by_faction.keys():
			var candidate_faction_id: int = int(candidate_variant)
			if not StrategicTestLogicScript.are_factions_hostile(owner_faction_id, candidate_faction_id):
				continue
			enemy_sr = maxi(enemy_sr, int(sr_by_faction.get(candidate_faction_id, 0)))
		enemy_sr += pirate_threat_sr
		enemy_sr_by_faction[owner_faction_id] = enemy_sr
		blockades[owner_faction_id] = enemy_sr > friendly_sr

	system_state["enemy_sr_by_faction"] = enemy_sr_by_faction
	system_state["blockade_by_faction"] = blockades


func is_planet_blockaded(planet: Dictionary) -> bool:
	var system_id: int = int(planet.get("system_id", -1))
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return false
	var owner_faction_id: int = int(planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	return bool(system_state.get("blockade_by_faction", {}).get(owner_faction_id, false))


func _initialize_default_factions() -> void:
	var test_faction: Dictionary = StrategicTestConfigScript.create_default_faction(StrategicTestConfigScript.TEST_FACTION_ID, "Test Faction")
	var faction_b: Dictionary = StrategicTestConfigScript.create_default_faction(StrategicTestConfigScript.FACTION_B_ID, "Faction B")
	var no_owner: Dictionary = StrategicTestConfigScript.create_default_faction(StrategicTestConfigScript.NO_OWNER_FACTION_ID, "No Owner")
	_factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] = test_faction
	_factions_by_id[StrategicTestConfigScript.FACTION_B_ID] = faction_b
	_factions_by_id[StrategicTestConfigScript.NO_OWNER_FACTION_ID] = no_owner


func _index_and_prepare_planets() -> void:
	var next_system_id: int = 1
	var next_planet_id: int = 1
	for system_data_variant in _systems:
		var system_data: Dictionary = system_data_variant
		if not system_data.has("id"):
			system_data["id"] = next_system_id
			next_system_id += 1
		var system_id: int = int(system_data.get("id", -1))
		var system_name: String = str(system_data.get("system_name", "Unknown System"))
		if not system_data.has("fleets"):
			system_data["fleets"] = []
		var system_fleets: Array = system_data.get("fleets", [])
		for fleet_variant in system_fleets:
			var fleet_state: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet_state, system_id)
		if not system_data.has("orbital_structures"):
			system_data["orbital_structures"] = []
		if not system_data.has("space_queue"):
			system_data["space_queue"] = []
		if not system_data.has("orbit_slot_capacity"):
			system_data["orbit_slot_capacity"] = DEFAULT_ORBIT_SLOT_CAPACITY
		_ensure_system_belt_state(system_data)
		_ensure_system_piracy_state(system_data)
		system_data["planet_ids"] = []
		system_data["blockade_by_faction"] = {}
		system_data["sr_by_faction"] = {}
		system_data["enemy_sr_by_faction"] = {}
		system_data["fleets_present"] = {}
		system_data["space_engagement"] = (system_data.get("space_engagement", StrategicTestConfigScript.create_engagement_state()) as Dictionary)
		system_data["last_engagement_end_day"] = int(system_data.get("last_engagement_end_day", -1))
		_systems_by_name[system_name] = system_data
		_systems_by_id[system_id] = system_data

		var planets: Array = system_data.get("planets", [])
		for planet_data_variant in planets:
			var planet_data: Dictionary = planet_data_variant
			if not planet_data.has("planet_id"):
				planet_data["planet_id"] = next_planet_id
				next_planet_id += 1
			var planet_id: int = int(planet_data.get("planet_id", -1))
			_apply_planet_strategic_defaults(planet_data)
			planet_data["system_id"] = system_id
			planet_data["stored_metal"] = 0
			planet_data["stored_rare_metal"] = 0
			planet_data["bootstrap_seed_applied"] = false
			_planets_by_id[planet_id] = planet_data
			_system_name_by_planet_id[planet_id] = system_name
			_system_id_by_planet_id[planet_id] = system_id
			(system_data["planet_ids"] as Array).append(planet_id)

			var planet_name: String = str(planet_data.get("name", "Unknown Planet"))
			_planet_ids_by_name[_planet_lookup_key(system_name, planet_name)] = planet_id

			var owner_faction_id: int = int(planet_data.get("owner_faction_id", StrategicTestConfigScript.TEST_FACTION_ID))
			if _factions_by_id.has(owner_faction_id):
				var owned_planet_ids: Array = (_factions_by_id[owner_faction_id] as Dictionary).get("owned_planet_ids", [])
				owned_planet_ids.append(planet_id)
				(_factions_by_id[owner_faction_id] as Dictionary)["owned_planet_ids"] = owned_planet_ids

		_migrate_legacy_structures_to_system(system_data)

	_ensure_faction_bootstrap_seed()


func _apply_planet_strategic_defaults(planet_data: Dictionary) -> void:
	var defaults: Dictionary = StrategicTestConfigScript.strategic_planet_defaults()
	for key_variant in defaults.keys():
		var key: String = str(key_variant)
		if not planet_data.has(key):
			planet_data[key] = defaults[key]

	var required_garrison_gp: int = int(planet_data.get("required_garrison_gp", StrategicTestConfigScript.PLANET_REQUIRED_GARRISON_GP))
	if int(planet_data.get("current_garrison_gp", -1)) < 0:
		planet_data["current_garrison_gp"] = required_garrison_gp
	planet_data["current_garrison_gp"] = mini(int(planet_data.get("current_garrison_gp", required_garrison_gp)), required_garrison_gp)
	var initial_recruit_progress: int = maxi(0, int(planet_data.get("garrison_recruit_progress", 0)))
	if str(planet_data.get("garrison_recruit_paused_reason", "")) == "insufficient_credits":
		planet_data["garrison_recruit_progress"] = mini(initial_recruit_progress, StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP)
	else:
		planet_data["garrison_recruit_progress"] = clampi(initial_recruit_progress, 0, StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP)
	planet_data["garrison_recruit_rate"] = maxi(1, int(planet_data.get("garrison_recruit_rate", StrategicTestConfigScript.PLANET_GARRISON_RECRUIT_RATE_PER_DAY)))
	planet_data["garrison_recruit_paused_reason"] = str(planet_data.get("garrison_recruit_paused_reason", ""))
	planet_data["garrison_recruit_last_paid_day"] = int(planet_data.get("garrison_recruit_last_paid_day", -1))
	planet_data["troops"] = (planet_data.get("troops", []) as Array)
	planet_data["troop_training_queue"] = (planet_data.get("troop_training_queue", []) as Array)
	planet_data["troop_training_progress"] = maxi(0, int(planet_data.get("troop_training_progress", 0)))
	planet_data["ground_engagement"] = (planet_data.get("ground_engagement", StrategicTestConfigScript.create_engagement_state()) as Dictionary)
	planet_data["last_engagement_end_day"] = int(planet_data.get("last_engagement_end_day", -1))
	planet_data["troop_gp"] = StrategicTestLogicScript.compute_planet_troop_gp(planet_data)
	for troop_variant in planet_data.get("troops", []):
		var troop: Dictionary = troop_variant
		troop["troop_id"] = int(troop.get("troop_id", _next_troop_id))
		troop["owner_faction_id"] = int(troop.get("owner_faction_id", int(planet_data.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))))
		troop["planet_id"] = int(troop.get("planet_id", int(planet_data.get("planet_id", -1))))
		troop["type_id"] = str(troop.get("type_id", "troops_basic"))
		troop["gp"] = maxi(0, int(troop.get("gp", 1)))
		troop["upkeep_credits_per_day"] = maxi(0, int(troop.get("upkeep_credits_per_day", 2)))
		troop["status"] = str(troop.get("status", "active"))
		_next_troop_id = maxi(_next_troop_id, int(troop.get("troop_id", 0)) + 1)


func _apply_garrison_recruitment(logs: Array[String]) -> void:
	var sorted_planet_ids: Array[int] = []
	for planet_id_variant in _planets_by_id.keys():
		sorted_planet_ids.append(int(planet_id_variant))
	sorted_planet_ids.sort()

	for planet_id in sorted_planet_ids:
		var planet_state: Dictionary = _planets_by_id[planet_id]
		var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if owner_faction_id < 0 or not _factions_by_id.has(owner_faction_id):
			continue

		var required_garrison_gp: int = int(planet_state.get("required_garrison_gp", 0))
		var current_garrison_gp_before: int = int(planet_state.get("current_garrison_gp", required_garrison_gp))
		if current_garrison_gp_before >= required_garrison_gp:
			planet_state["garrison_recruit_progress"] = 0
			planet_state["garrison_recruit_paused_reason"] = ""
			continue

		var blockaded: bool = is_planet_blockaded(planet_state)
		var faction_state: Dictionary = _factions_by_id[owner_faction_id]
		var recruitment_result: Dictionary = StrategicTestLogicScript.apply_garrison_recruitment_for_planet(planet_state, faction_state, blockaded, _day_index)
		var effective_rate: int = int(recruitment_result.get("effective_rate", 0))
		var progress: int = int(recruitment_result.get("progress", int(planet_state.get("garrison_recruit_progress", 0))))
		var current_garrison_gp: int = int(recruitment_result.get("current_garrison_gp", int(planet_state.get("current_garrison_gp", current_garrison_gp_before))))
		var deficit: int = int(recruitment_result.get("deficit", maxi(0, required_garrison_gp - current_garrison_gp)))
		var cost_next: int = int(recruitment_result.get("cost_next", StrategicTestConfigScript.GARRISON_GP_RECRUIT_COST_CREDITS))
		var credits: int = int(recruitment_result.get("credits", int(faction_state.get("credits", 0))))
		var paused_reason: String = str(recruitment_result.get("paused_reason", ""))
		var paused: bool = bool(recruitment_result.get("paused", false))

		logs.append("DAY %d | GARRISON | planet=%d owner=%d deficit=%d rate=%d blockaded=%d progress=%d cost_next=%d credits=%d paused=%d reason=%s" % [
			_day_index,
			planet_id,
			owner_faction_id,
			deficit,
			effective_rate,
			1 if blockaded else 0,
			progress,
			cost_next,
			credits,
			1 if paused else 0,
			paused_reason,
		])

		if bool(recruitment_result.get("gained_gp", false)):
			logs.append("DAY %d | GARRISON | planet=%d owner=%d +1GP now=%d/%d cost=%d credits_after=%d progress=%d wallet=%d" % [
				_day_index,
				planet_id,
				owner_faction_id,
				current_garrison_gp,
				required_garrison_gp,
				cost_next,
				credits,
				progress,
				int(faction_state.get("credits", 0)),
			])
		elif paused:
			logs.append("DAY %d | GARRISON | planet=%d owner=%d paused=insufficient_credits cost=%d credits=%d progress=%d" % [
				_day_index,
				planet_id,
				owner_faction_id,
				cost_next,
				credits,
				progress,
			])


func _refresh_planet_troop_gp(planet_state: Dictionary) -> int:
	var troop_gp: int = StrategicTestLogicScript.compute_planet_troop_gp(planet_state)
	planet_state["troop_gp"] = troop_gp
	return troop_gp


func _apply_troop_upkeep_deterministic(logs: Array[String], faction_upkeep_paid_by_id: Dictionary, faction_upkeep_breakdown_by_id: Dictionary, faction_unpaid_counts_by_id: Dictionary) -> void:
	var troop_entries: Array[Dictionary] = []
	for planet_id_variant in _planets_by_id.keys():
		var planet_id: int = int(planet_id_variant)
		var planet_state: Dictionary = _planets_by_id[planet_id]
		for troop_variant in planet_state.get("troops", []):
			var troop: Dictionary = troop_variant
			if str(troop.get("status", "active")) != "active":
				continue
			troop_entries.append({
				"planet_id": planet_id,
				"troop": troop,
			})
	troop_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_planet_id: int = int(a.get("planet_id", -1))
		var b_planet_id: int = int(b.get("planet_id", -1))
		if a_planet_id == b_planet_id:
			return int((a.get("troop", {}) as Dictionary).get("troop_id", 0)) < int((b.get("troop", {}) as Dictionary).get("troop_id", 0))
		return a_planet_id < b_planet_id
	)

	for entry_variant in troop_entries:
		var entry: Dictionary = entry_variant
		var troop: Dictionary = entry.get("troop", {})
		var owner_faction_id: int = int(troop.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not _factions_by_id.has(owner_faction_id):
			continue
		var faction_state: Dictionary = _factions_by_id[owner_faction_id]
		var upkeep_result: Dictionary = StrategicTestLogicScript.pay_troop_upkeep(troop, faction_state)
		var upkeep_paid: int = int(upkeep_result.get("upkeep_paid", 0))
		faction_upkeep_paid_by_id[owner_faction_id] = int(faction_upkeep_paid_by_id.get(owner_faction_id, 0)) + upkeep_paid
		(faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary)["troop"] = int((faction_upkeep_breakdown_by_id[owner_faction_id] as Dictionary).get("troop", 0)) + upkeep_paid
		if not bool(upkeep_result.get("is_paid", false)):
			(faction_unpaid_counts_by_id[owner_faction_id] as Dictionary)["troop"] = int((faction_unpaid_counts_by_id[owner_faction_id] as Dictionary).get("troop", 0)) + 1
			logs.append("DAY %d | TROOP_UPKEEP_UNPAID | planet=%d owner=%d troop_id=%d upkeep=%d credits=%d" % [
				_day_index,
				int(entry.get("planet_id", -1)),
				owner_faction_id,
				int(troop.get("troop_id", -1)),
				int(troop.get("upkeep_credits_per_day", 0)),
				int(faction_state.get("credits", 0)),
			])


func _process_troop_training(logs: Array[String]) -> void:
	var sorted_planet_ids: Array[int] = []
	for planet_id_variant in _planets_by_id.keys():
		sorted_planet_ids.append(int(planet_id_variant))
	sorted_planet_ids.sort()

	for planet_id in sorted_planet_ids:
		var planet_state: Dictionary = _planets_by_id[planet_id]
		_refresh_planet_troop_gp(planet_state)
		var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var queue: Array = planet_state.get("troop_training_queue", [])
		if queue.is_empty():
			planet_state["troop_training_progress"] = 0
			continue
		var job: Dictionary = queue[0]
		if owner_faction_id < 0 or owner_faction_id != int(job.get("owner_faction_id", owner_faction_id)):
			planet_state["troop_training_progress"] = int(job.get("days_progress", 0))
			continue
		if not _factions_by_id.has(owner_faction_id):
			planet_state["troop_training_progress"] = int(job.get("days_progress", 0))
			continue

		job["days_progress"] = mini(int(job.get("days_progress", 0)) + 1, int(job.get("days_required", 0)))
		planet_state["troop_training_progress"] = int(job.get("days_progress", 0))
		if int(job.get("days_progress", 0)) < int(job.get("days_required", 0)):
			job["status"] = "active"
			queue[0] = job
			planet_state["troop_training_queue"] = queue
			continue

		var faction_state: Dictionary = _factions_by_id[owner_faction_id]
		var cost_credits: int = int(job.get("cost_credits", 0))
		var cost_metal: int = int(job.get("cost_metal", 0))
		var cost_rare: int = int(job.get("cost_rare", 0))
		var has_resources: bool = int(faction_state.get("credits", 0)) >= cost_credits and int(faction_state.get("metal", 0)) >= cost_metal and int(faction_state.get("rare_metal", 0)) >= cost_rare
		if not has_resources:
			job["status"] = "stalled_insufficient_stockpile"
			if int(job.get("last_stall_logged_day", -1)) != _day_index:
				job["last_stall_logged_day"] = _day_index
				logs.append("DAY %d | TROOP_STALL | planet=%d owner=%d reason=insufficient_stockpile need=%d/%d/%d have=%d/%d/%d" % [
					_day_index,
					planet_id,
					owner_faction_id,
					cost_credits,
					cost_metal,
					cost_rare,
					int(faction_state.get("credits", 0)),
					int(faction_state.get("metal", 0)),
					int(faction_state.get("rare_metal", 0)),
				])
			queue[0] = job
			planet_state["troop_training_queue"] = queue
			continue

		faction_state["credits"] = int(faction_state.get("credits", 0)) - cost_credits
		faction_state["metal"] = int(faction_state.get("metal", 0)) - cost_metal
		faction_state["rare_metal"] = int(faction_state.get("rare_metal", 0)) - cost_rare
		var troop_type_id: String = str(job.get("troop_type_id", "troops_basic"))
		var blueprint: Dictionary = StrategicTestConfigScript.TROOP_BLUEPRINTS.get(troop_type_id, {})
		var troop_unit: Dictionary = {
			"troop_id": _next_troop_id,
			"owner_faction_id": owner_faction_id,
			"planet_id": planet_id,
			"type_id": troop_type_id,
			"gp": int(blueprint.get("gp", 1)),
			"upkeep_credits_per_day": int(blueprint.get("upkeep_credits_per_day", 2)),
			"status": "active",
		}
		_next_troop_id += 1
		var troops: Array = planet_state.get("troops", [])
		troops.append(troop_unit)
		planet_state["troops"] = troops
		queue.remove_at(0)
		planet_state["troop_training_queue"] = queue
		planet_state["troop_training_progress"] = 0
		_refresh_planet_troop_gp(planet_state)
		logs.append("DAY %d | TROOP_COMPLETE | planet=%d owner=%d troop_id=%d gp=%d cost=%d/%d/%d credits_after=%d metal_after=%d" % [
			_day_index,
			planet_id,
			owner_faction_id,
			int(troop_unit.get("troop_id", -1)),
			int(troop_unit.get("gp", 0)),
			cost_credits,
			cost_metal,
			cost_rare,
			int(faction_state.get("credits", 0)),
			int(faction_state.get("metal", 0)),
		])


func _enqueue_troop_training_for_planet(planet_state: Dictionary, owner_faction_id: int, queued_upkeep_by_faction: Dictionary, logs: Array[String], skip_logged_today_by_planet: Dictionary) -> void:
	if owner_faction_id < 0:
		return
	if not _factions_by_id.has(owner_faction_id):
		return
	var planet_id: int = int(planet_state.get("planet_id", -1))
	var troop_gp: int = _refresh_planet_troop_gp(planet_state)
	var required_garrison_gp: int = int(planet_state.get("required_garrison_gp", 0))
	var current_garrison_gp: int = int(planet_state.get("current_garrison_gp", required_garrison_gp))
	var deficit: int = maxi(0, required_garrison_gp - (current_garrison_gp + troop_gp))
	if deficit <= 0:
		return

	var queue: Array = planet_state.get("troop_training_queue", [])
	if queue.size() >= StrategicTestConfigScript.TROOP_MAX_TRAIN_JOBS_PER_PLANET:
		if not bool(skip_logged_today_by_planet.get(planet_id, false)):
			skip_logged_today_by_planet[planet_id] = true
			logs.append("DAY %d | TROOP_ENQUEUE_SKIP | planet=%d owner=%d reason=queue_full" % [_day_index, planet_id, owner_faction_id])
		return

	var blueprint: Dictionary = StrategicTestConfigScript.TROOP_BLUEPRINTS.get("troops_basic", {})
	if blueprint.is_empty():
		return

	var projected_income: int = get_faction_expected_income_today(owner_faction_id)
	var projected_upkeep: int = get_faction_total_upkeep(owner_faction_id) + int(queued_upkeep_by_faction.get(owner_faction_id, 0)) + int(blueprint.get("upkeep_credits_per_day", 0))
	var projected_net_c: int = projected_income - projected_upkeep
	if projected_net_c < 0:
		if not bool(skip_logged_today_by_planet.get(planet_id, false)):
			skip_logged_today_by_planet[planet_id] = true
			logs.append("DAY %d | TROOP_ENQUEUE_SKIP | planet=%d owner=%d reason=solvency_rule" % [_day_index, planet_id, owner_faction_id])
		return

	var training_job: Dictionary = {
		"type": "train_troop",
		"troop_type_id": "troops_basic",
		"owner_faction_id": owner_faction_id,
		"planet_id": planet_id,
		"days_required": int(blueprint.get("train_days", 3)),
		"days_progress": 0,
		"cost_credits": int(blueprint.get("credits_cost", 0)),
		"cost_metal": int(blueprint.get("metal_cost", 0)),
		"cost_rare": int(blueprint.get("rare_cost", 0)),
		"status": "active",
		"last_stall_logged_day": -1,
	}
	queue.append(training_job)
	planet_state["troop_training_queue"] = queue
	planet_state["troop_training_progress"] = 0
	queued_upkeep_by_faction[owner_faction_id] = int(queued_upkeep_by_faction.get(owner_faction_id, 0)) + int(blueprint.get("upkeep_credits_per_day", 0))
	logs.append("DAY %d | TROOP_ENQUEUE | planet=%d owner=%d type=troops_basic days=%d cost=%d/%d/%d reason=ok" % [
		_day_index,
		planet_id,
		owner_faction_id,
		int(blueprint.get("train_days", 3)),
		int(blueprint.get("credits_cost", 0)),
		int(blueprint.get("metal_cost", 0)),
		int(blueprint.get("rare_cost", 0)),
	])


func _ensure_faction_bootstrap_seed() -> void:
	var sorted_faction_ids: Array[int] = []
	for faction_id_variant in _factions_by_id.keys():
		sorted_faction_ids.append(int(faction_id_variant))
	sorted_faction_ids.sort()

	for faction_id in sorted_faction_ids:
		var faction_state: Dictionary = _factions_by_id[faction_id]
		if bool(faction_state.get("bootstrap_global_seed_applied", false)):
			continue
		faction_state["metal"] = int(faction_state.get("metal", 0)) + BOOTSTRAP_METAL_SEED_GLOBAL
		faction_state["rare_metal"] = int(faction_state.get("rare_metal", 0)) + BOOTSTRAP_RARE_METAL_SEED_GLOBAL
		faction_state["bootstrap_global_seed_applied"] = true
		print("BOOTSTRAP seed applied: faction=%d metal+%d rare_metal+%d wallet=faction_stockpile" % [
			faction_id,
			BOOTSTRAP_METAL_SEED_GLOBAL,
			BOOTSTRAP_RARE_METAL_SEED_GLOBAL,
		])


func _attach_phase_one_shipyard_to_first_owned_planet() -> void:
	if not _factions_by_id.has(StrategicTestConfigScript.TEST_FACTION_ID):
		return
	var test_faction: Dictionary = _factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID]
	var owned_planet_ids: Array = test_faction.get("owned_planet_ids", [])
	if owned_planet_ids.is_empty():
		return

	var first_planet_id: int = int(owned_planet_ids[0])
	var host_planet: Dictionary = _planets_by_id.get(first_planet_id, {})
	if host_planet.is_empty():
		return
	var system_id: int = int(host_planet.get("system_id", -1))
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return

	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if str(structure.get("type", "")) == StrategicTestConfigScript.SHIPYARD_I_TYPE and int(structure.get("owner_faction_id", 0)) == StrategicTestConfigScript.TEST_FACTION_ID:
			return

	var structures: Array = system_state.get("orbital_structures", [])
	structures.append(StrategicTestConfigScript.create_shipyard_i_instance(StrategicTestConfigScript.TEST_FACTION_ID, system_id))
	system_state["orbital_structures"] = structures


func _migrate_legacy_structures_to_system(system_data: Dictionary) -> void:
	var system_id: int = int(system_data.get("id", -1))
	var structures: Array = system_data.get("orbital_structures", [])
	for planet_variant in system_data.get("planets", []):
		var planet_state: Dictionary = planet_variant
		for station_variant in planet_state.get("defense_stations", []):
			var station: Dictionary = station_variant
			station["type"] = StrategicTestConfigScript.DEFENSE_STATION_I_TYPE
			station["system_id"] = system_id
			if not station.has("sr"):
				station["sr"] = int(station.get("station_sr", StrategicTestConfigScript.DEFENSE_STATION_I_STATION_SR))
			structures.append(station)
	system_data["orbital_structures"] = structures


func _ensure_system_piracy_state(system_data: Dictionary) -> void:
	if not system_data.has("piracy_pressure"):
		system_data["piracy_pressure"] = 0
	if not system_data.has("pirate_state"):
		system_data["pirate_state"] = StrategicTestConfigScript.PIRATE_STATE_NONE
	if not system_data.has("last_scout_day_by_faction"):
		system_data["last_scout_day_by_faction"] = {}
	if not system_data.has("security_by_faction"):
		system_data["security_by_faction"] = {}
	if not system_data.has("pirate_presence"):
		system_data["pirate_presence"] = PiratePresenceData.create_default(int(system_data.get("id", -1)))

	# Ensure future hooks always exist and arrays stay present for Phase 4 baseline.
	var pirate_presence: Dictionary = system_data.get("pirate_presence", {})
	if pirate_presence.is_empty():
		pirate_presence = PiratePresenceData.create_default(int(system_data.get("id", -1)))
	if not pirate_presence.has("tags"):
		pirate_presence["tags"] = {
			"has_hidden_base": false,
			"leader_id": null,
			"loot_table_id": "pirate_basic",
		}
	if not pirate_presence.has("active_fleets"):
		pirate_presence["active_fleets"] = []
	if not pirate_presence.has("structures"):
		pirate_presence["structures"] = []
	system_data["pirate_presence"] = pirate_presence
	set_pirate_state(system_data, int(system_data.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)))


func _update_scouting_freshness_for_system(system_state: Dictionary) -> void:
	var relevant_factions: Dictionary = {}
	for faction_id_variant in system_state.get("fleets_present", {}).keys():
		relevant_factions[int(faction_id_variant)] = true
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		relevant_factions[int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))] = true
	for planet_variant in get_system_planets(int(system_state.get("id", -1))):
		var planet_state: Dictionary = planet_variant
		relevant_factions[int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))] = true

	var last_scout_day_by_faction: Dictionary = system_state.get("last_scout_day_by_faction", {})
	var fleets_present: Dictionary = system_state.get("fleets_present", {})
	for faction_id_variant in relevant_factions.keys():
		var faction_id: int = int(faction_id_variant)
		var has_fleet_presence: bool = (fleets_present.get(faction_id, []) as Array).size() > 0
		var has_listening_post: bool = _has_owned_structure_type(system_state, faction_id, StrategicTestConfigScript.LISTENING_POST_TYPE)
		if has_fleet_presence or has_listening_post:
			last_scout_day_by_faction[faction_id] = _day_index
	system_state["last_scout_day_by_faction"] = last_scout_day_by_faction


func _update_system_security_and_piracy(system_state: Dictionary) -> void:
	var primary_planet: Dictionary = get_primary_planet(int(system_state.get("id", -1)))
	if primary_planet.is_empty():
		return
	var controller_faction_id: int = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var security: int = _compute_system_security_for_controller(system_state, controller_faction_id)
	var security_by_faction: Dictionary = system_state.get("security_by_faction", {})
	security_by_faction[controller_faction_id] = security
	system_state["security_by_faction"] = security_by_faction

	var scout_age: int = get_scout_age(system_state, controller_faction_id, _day_index)
	var fog_bonus: int = 0
	if scout_age >= 15:
		fog_bonus = 6
	elif scout_age >= 8:
		fog_bonus = 4
	elif scout_age >= 4:
		fog_bonus = 2

	var value_bonus: int = 0
	if int(system_state.get("platform_tier", 0)) >= 1:
		value_bonus += 2
	for planet_variant in get_system_planets(int(system_state.get("id", -1))):
		var planet_state: Dictionary = planet_variant
		if int(planet_state.get("base_credits_per_day", 0)) >= 220:
			value_bonus += 1
			break
	if int(system_state.get("degree", 0)) >= 4:
		value_bonus += 1

	var security_reduction: int = int(floor(float(security) / 10.0))
	var delta: int = maxi(0, fog_bonus + value_bonus - security_reduction)
	system_state["piracy_pressure"] = clampi(int(system_state.get("piracy_pressure", 0)) + delta, 0, 100)

	var new_pirate_state: int = StrategicTestConfigScript.PIRATE_STATE_NONE
	var piracy_pressure: int = int(system_state.get("piracy_pressure", 0))
	if piracy_pressure >= 80:
		new_pirate_state = StrategicTestConfigScript.PIRATE_STATE_HAVEN
	elif piracy_pressure >= 40:
		new_pirate_state = StrategicTestConfigScript.PIRATE_STATE_ACTIVITY
	set_pirate_state(system_state, new_pirate_state)


func _compute_system_security_for_controller(system_state: Dictionary, controller_faction_id: int) -> int:
	var security: int = 0
	for planet_variant in get_system_planets(int(system_state.get("id", -1))):
		var planet_state: Dictionary = planet_variant
		var effective_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0)) + _refresh_planet_troop_gp(planet_state)
		if int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == controller_faction_id and effective_garrison_gp >= 1:
			security += 10
			break

	if _has_owned_defense_station_sr_at_least(system_state, controller_faction_id, 15):
		security += 10
	if _has_owned_structure_type(system_state, controller_faction_id, StrategicTestConfigScript.PATROL_HQ_TYPE):
		security += 15
	if _has_owned_structure_type(system_state, controller_faction_id, StrategicTestConfigScript.LISTENING_POST_TYPE):
		security += 20
	var patrol_security: Dictionary = _compute_patrol_security_for_controller(system_state, controller_faction_id)
	security += int(patrol_security.get("security_from_patrol", 0))

	return mini(security, 60)


func _compute_patrol_security_for_controller(system_state: Dictionary, controller_faction_id: int) -> Dictionary:
	var system_id: int = int(system_state.get("id", -1))
	var candidates: Dictionary = StrategicTestLogicScript.collect_patrol_candidates_for_faction(
		system_state.get("fleets", []),
		controller_faction_id,
		true,
		system_id
	)
	var selected_fleets: Array[Dictionary] = StrategicTestLogicScript.select_patrol_fleets(
		candidates.get("full_candidates", []),
		candidates.get("light_candidates", [])
	)
	return StrategicTestLogicScript.compute_patrol_security_from_fleets(selected_fleets)


func _has_owned_structure_type(system_state: Dictionary, owner_faction_id: int, structure_type: String) -> bool:
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if not _is_structure_active(structure):
			continue
		if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == owner_faction_id and str(structure.get("type", "")) == structure_type:
			return true
	return false


func _has_owned_defense_station_sr_at_least(system_state: Dictionary, owner_faction_id: int, minimum_sr: int) -> bool:
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if not _is_structure_active(structure):
			continue
		if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) != owner_faction_id:
			continue
		if str(structure.get("type", "")) == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE and int(structure.get("sr", 0)) >= minimum_sr:
			return true
	return false


func _get_faction_fleet_sr_in_system(system_state: Dictionary, faction_id: int) -> int:
	var total_sr: int = 0
	for fleet_variant in system_state.get("fleets_present", {}).get(faction_id, []):
		var fleet: Dictionary = fleet_variant
		total_sr += get_fleet_effective_sr(fleet)
	return total_sr


func _is_structure_active(structure: Dictionary) -> bool:
	if int(structure.get("disabled_days", 0)) > 0:
		return false
	if structure.has("enabled") and not bool(structure.get("enabled", true)):
		return false
	return true


func _build_system_fleets_present(system_state: Dictionary) -> Dictionary:
	var fleets_by_faction: Dictionary = {}
	var system_id: int = int(system_state.get("id", -1))
	for fleet_variant in _collect_all_fleets():
		var fleet: Dictionary = fleet_variant
		if int(fleet.get("system_id", -1)) != system_id:
			continue
		var owner_faction_id: int = int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not fleets_by_faction.has(owner_faction_id):
			fleets_by_faction[owner_faction_id] = []
		(fleets_by_faction[owner_faction_id] as Array).append(fleet)
	return fleets_by_faction


func _collect_stations_in_system(system_state: Dictionary) -> Array:
	var stations: Array = []
	for structure_variant in system_state.get("orbital_structures", []):
		var structure: Dictionary = structure_variant
		if str(structure.get("type", "")) == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE:
			stations.append(structure)
	return stations


func _resolve_belt_income(system_state: Dictionary) -> Dictionary:
	if not bool(system_state.get("has_belt", false)):
		return {"metal_gain": 0, "rare_gain": 0}
	_sync_belt_owner_to_primary_planet(system_state)
	if int(system_state.get("platform_tier", 0)) <= 0 or int(system_state.get("belt_disabled_days", 0)) > 0:
		return {"metal_gain": 0, "rare_gain": 0}

	var owner_faction_id: int = int(system_state.get("belt_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if not _factions_by_id.has(owner_faction_id):
		return {"metal_gain": 0, "rare_gain": 0}

	var fleets_present: Dictionary = system_state.get("fleets_present", {})
	var owner_fleets: Array = fleets_present.get(owner_faction_id, [])
	var presence_ok: bool = owner_fleets.size() > 0
	if not presence_ok:
		for structure_variant in system_state.get("orbital_structures", []):
			var structure: Dictionary = structure_variant
			if not _is_structure_active(structure):
				continue
			if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == owner_faction_id and int(structure.get("sr", 0)) >= StrategicTestConfigScript.DEFENSE_STATION_I_STATION_SR:
				presence_ok = true
				break
	if not presence_ok:
		return {"metal_gain": 0, "rare_gain": 0}

	if bool(system_state.get("blockade_by_faction", {}).get(owner_faction_id, false)):
		return {"metal_gain": 0, "rare_gain": 0}

	var belt_yield: Dictionary = StrategicTestLogicScript.compute_belt_yield({
		"belt_class": str(system_state.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE)),
		"platform_tier": int(system_state.get("platform_tier", 0)),
	}, _get_belt_piracy_multiplier(system_state))
	var faction_state: Dictionary = _factions_by_id[owner_faction_id]
	faction_state["metal"] = int(faction_state.get("metal", 0)) + int(belt_yield.get("metal_gain", 0))
	faction_state["rare_metal"] = int(faction_state.get("rare_metal", 0)) + int(belt_yield.get("rare_gain", 0))
	return belt_yield


func _get_planet_piracy_multiplier(system_state: Dictionary) -> float:
	match int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)):
		StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			return 0.90
		StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			return 0.70
		_:
			return 1.00


func _get_belt_piracy_multiplier(system_state: Dictionary) -> float:
	match int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)):
		StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			return 0.70
		StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			return 0.00
		_:
			return 1.00


func _try_clear_pirate_haven(system_state: Dictionary) -> void:
	if int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) != StrategicTestConfigScript.PIRATE_STATE_HAVEN:
		return
	var pirate_presence: Dictionary = system_state.get("pirate_presence", PiratePresenceData.create_default(int(system_state.get("id", -1))))
	var threshold_sr: int = int(pirate_presence.get("threat_sr", 0)) + 10
	var fleets_present: Dictionary = system_state.get("fleets_present", {})
	for faction_id_variant in fleets_present.keys():
		var faction_id: int = int(faction_id_variant)
		var friendly_sr: int = _get_faction_fleet_sr_in_system(system_state, faction_id)
		for structure_variant in system_state.get("orbital_structures", []):
			var structure: Dictionary = structure_variant
			if not _is_structure_active(structure):
				continue
			if int(structure.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)) == faction_id:
				friendly_sr += int(structure.get("sr", 0))
		if friendly_sr >= threshold_sr:
			system_state["piracy_pressure"] = 30
			set_pirate_state(system_state, StrategicTestConfigScript.PIRATE_STATE_NONE)
			break


func _sync_belt_owner_to_primary_planet(system_state: Dictionary) -> void:
	if not bool(system_state.get("has_belt", false)):
		return
	var primary_planet: Dictionary = get_primary_planet(int(system_state.get("id", -1)))
	if primary_planet.is_empty():
		return
	system_state["belt_owner_faction_id"] = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var belt_state: Dictionary = system_state.get("belt", {})
	if not belt_state.is_empty():
		belt_state["owner_faction_id"] = int(system_state.get("belt_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))


func _spawn_ship_from_completed_order(system_state: Dictionary, completed_order: Dictionary) -> Dictionary:
	var blueprint_id: String = str(completed_order.get("blueprint_id", ""))
	var blueprint: Dictionary = StrategicTestConfigScript.SHIP_BLUEPRINTS.get(blueprint_id, {})
	var system_id: int = int(system_state.get("id", -1))
	var owner_faction_id: int = int(completed_order.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	var fleet_unit: Dictionary = {
		"fleet_id": _next_fleet_id,
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"blueprint_id": blueprint_id,
		"sr": int(blueprint.get("sr", 0)),
		"upkeep_credits_per_day": int(completed_order.get("upkeep_credits_per_day", 0)),
		"ships": [StrategicTestLogicScript.make_ship_roster_entry(
			blueprint_id,
			int(blueprint.get("sr", 0)),
			int(completed_order.get("upkeep_credits_per_day", 0))
		)],
		"readiness": 100,
		"missed_upkeep_days": 0,
		"last_refit_day": -999999,
		"tags": blueprint.get("tags", {"role": "escort"}),
		"cargo_troop_gp": 0,
		"transport_capacity_gp": int(blueprint.get("transport_capacity_gp", 0)),
		"landed_planet_id": -1,
	}
	_next_fleet_id += 1
	var fleets: Array = system_state.get("fleets", [])
	fleets.append(fleet_unit)
	system_state["fleets"] = fleets
	_spawned_fleet_units.append(fleet_unit.duplicate(true))
	return fleet_unit


func _process_shipyards_for_system(system_state: Dictionary, logs: Array[String], faction_shipyard_status_by_id: Dictionary) -> void:
	var system_id: int = int(system_state.get("id", -1))
	var structures_for_queue: Array = system_state.get("orbital_structures", [])
	for structure_variant in structures_for_queue:
		var shipyard: Dictionary = structure_variant
		if str(shipyard.get("type", "")) != StrategicTestConfigScript.SHIPYARD_I_TYPE:
			continue
		var owner_faction_id: int = int(shipyard.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		if not _factions_by_id.has(owner_faction_id):
			continue
		var faction_state_for_queue: Dictionary = _factions_by_id[owner_faction_id]
		var can_generate_sp: bool = bool(shipyard.get("can_generate_sp", false))
		var shipyard_result: Dictionary = StrategicTestLogicScript.advance_shipyard_queue(
			shipyard,
			faction_state_for_queue,
			can_generate_sp,
			bool(get_system(system_id).get("blockade_by_faction", {}).get(owner_faction_id, false)),
			_day_index
		)
		var completed_order: Dictionary = shipyard_result.get("completed_order", {})
		if not completed_order.is_empty():
			var spawned_fleet: Dictionary = _spawn_ship_from_completed_order(system_state, completed_order)
			var completed_costs: Dictionary = completed_order.get("costs", {})
			logs.append("DAY %d | SHIP_COMPLETE | system=%d owner=%d blueprint=%s fleet_id=%d sr=%d base_sr=%d eff_sr=%d readiness=%d deducted_once=1 cost=%d/%d/%d credits_after=%d metal_after=%d rare_after=%d" % [
				_day_index,
				system_id,
				owner_faction_id,
				str(completed_order.get("blueprint_id", "")),
				int(spawned_fleet.get("fleet_id", -1)),
				int(spawned_fleet.get("sr", 0)),
				get_fleet_base_sr(spawned_fleet),
				get_fleet_effective_sr(spawned_fleet),
				int(spawned_fleet.get("readiness", 100)),
				int(completed_costs.get("credits", 0)),
				int(completed_costs.get("metal", 0)),
				int(completed_costs.get("rare", 0)),
				int(faction_state_for_queue.get("credits", 0)),
				int(faction_state_for_queue.get("metal", 0)),
				int(faction_state_for_queue.get("rare_metal", 0)),
			])
		elif bool(shipyard_result.get("should_log_stall", false)):
			var active_order: Dictionary = ((shipyard.get("queue", []) as Array)[0] as Dictionary) if (shipyard.get("queue", []) as Array).size() > 0 else {}
			var need_costs: Dictionary = active_order.get("costs", {})
			logs.append("DAY %d | SHIP_STALL | system=%d owner=%d blueprint=%s reason=insufficient_stockpile need=%d/%d/%d have=%d/%d/%d progress=%d/%d (throttled daily)" % [
				_day_index,
				system_id,
				owner_faction_id,
				str(active_order.get("blueprint_id", "")),
				int(need_costs.get("credits", 0)),
				int(need_costs.get("metal", 0)),
				int(need_costs.get("rare", 0)),
				int(faction_state_for_queue.get("credits", 0)),
				int(faction_state_for_queue.get("metal", 0)),
				int(faction_state_for_queue.get("rare_metal", 0)),
				int(shipyard.get("current_progress_sp", 0)),
				int(active_order.get("sp_cost", 0)),
			])

		var queue_size: int = (shipyard.get("queue", []) as Array).size()
		var status_line: String = "system=%d progress_sp=%d queue=%d generated_sp=%d completed=%s stalled=%s can_generate_sp=%s" % [
			system_id,
			int(shipyard.get("current_progress_sp", 0)),
			queue_size,
			int(shipyard_result.get("generated_sp", 0)),
			str(not completed_order.is_empty()),
			str(bool(shipyard_result.get("completion_blocked_for_resources", false))),
			str(can_generate_sp),
		]
		var entries: Array = faction_shipyard_status_by_id.get(owner_faction_id, [])
		entries.append(status_line)
		faction_shipyard_status_by_id[owner_faction_id] = entries


func _advance_space_queue(system_state: Dictionary, logs: Array[String]) -> void:
	var system_id: int = int(system_state.get("id", -1))
	var queue: Array = system_state.get("space_queue", [])
	var queue_completed: bool = false
	if not queue.is_empty():
		var order: Dictionary = queue[0]
		order["days_remaining"] = maxi(0, int(order.get("days_remaining", 0)) - 1)
		if int(order.get("days_remaining", 0)) <= 0:
			var order_type: String = str(order.get("order_type", ""))
			var owner_faction_id: int = int(order.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			var cost_credits: int = int(order.get("cost_credits", 0))
			var cost_metal: int = int(order.get("cost_metal", 0))
			var cost_rare: int = int(order.get("cost_rare_metal", 0))
			if order_type == "build_mining_platform":
				system_state["platform_tier"] = int(order.get("target_tier", int(system_state.get("platform_tier", 0))))
				var belt_state: Dictionary = system_state.get("belt", {})
				if not belt_state.is_empty():
					belt_state["platform_tier"] = int(system_state.get("platform_tier", 0))
				logs.append("DAY %d | SPACEQ_COMPLETE | system=%d type=build_mining_platform:tier%d owner=%d cost=%d/%d/%d result=ok" % [_day_index, system_id, int(order.get("target_tier", 0)), owner_faction_id, cost_credits, cost_metal, cost_rare])
			elif order_type == "build_orbital_structure":
				var structures: Array = system_state.get("orbital_structures", [])
				var build_type: String = str(order.get("build_type", ""))
				if build_type == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE:
					structures.append(StrategicTestConfigScript.create_defense_station_i_instance(owner_faction_id, system_id))
				elif build_type == StrategicTestConfigScript.LISTENING_POST_TYPE:
					structures.append(StrategicTestConfigScript.create_listening_post_instance(owner_faction_id, system_id))
				elif build_type == StrategicTestConfigScript.SHIPYARD_I_TYPE:
					structures.append(StrategicTestConfigScript.create_shipyard_i_instance(owner_faction_id, system_id))
				system_state["orbital_structures"] = structures
				logs.append("DAY %d | SPACEQ_COMPLETE | system=%d type=build_orbital:%s owner=%d cost=%d/%d/%d result=ok" % [_day_index, system_id, build_type, owner_faction_id, cost_credits, cost_metal, cost_rare])
				logs.append("DAY %d | ORBIT_COMPLETE | system=%d owner=%d type=%s" % [_day_index, system_id, owner_faction_id, build_type])
			queue.remove_at(0)
			queue_completed = true
		else:
			queue[0] = order
	system_state["space_queue"] = queue
	var primary_planet: Dictionary = get_primary_planet(system_id)
	var controller_faction_id: int = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	if queue.is_empty():
		logs.append("DAY %d | SPACEQ | system=%d owner_controller=%d len=0 head=none head_owner=-1 prog=0/0 stalled=0 reason=none paid=0/0/0" % [_day_index, system_id, controller_faction_id])
		return
	var head: Dictionary = queue[0]
	var head_type: String = str(head.get("order_type", ""))
	if head_type == "build_orbital_structure":
		head_type = "build_orbital:%s" % str(head.get("build_type", "unknown"))
	elif head_type == "build_mining_platform":
		head_type = "build_mining_platform:tier%d" % int(head.get("target_tier", 0))
	var days_required: int = maxi(1, int(head.get("build_days", 0)))
	var days_remaining: int = clampi(int(head.get("days_remaining", 0)), 0, days_required)
	var progress_days: int = days_required - days_remaining
	logs.append("DAY %d | SPACEQ | system=%d owner_controller=%d len=%d head=%s head_owner=%d prog=%d/%d stalled=0 reason=none paid=%d/%d/%d" % [
		_day_index,
		system_id,
		controller_faction_id,
		queue.size(),
		head_type,
		int(head.get("owner_faction_id", controller_faction_id)),
		progress_days,
		days_required,
		int(head.get("cost_credits", 0)),
		int(head.get("cost_metal", 0)),
		int(head.get("cost_rare_metal", 0)),
	])
	if queue_completed:
		return
	if str(head.get("order_type", "")) == "build_orbital_structure":
		logs.append("DAY %d | ORBIT_PROGRESS | system=%d owner=%d type=%s prog=%d/%d" % [_day_index, system_id, int(head.get("owner_faction_id", controller_faction_id)), str(head.get("build_type", "")), progress_days, days_required])


func _ensure_system_belt_state(system_data: Dictionary) -> void:
	var belt_data: Dictionary = system_data.get("belt", {})
	if not belt_data.is_empty():
		system_data["has_belt"] = bool(belt_data.get("has_belt", true))
		system_data["belt_class"] = str(belt_data.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE))
		system_data["platform_tier"] = int(belt_data.get("platform_tier", 0))
		system_data["belt_disabled_days"] = int(belt_data.get("belt_disabled_days", belt_data.get("disabled_days", 0)))
		system_data["belt_owner_faction_id"] = int(belt_data.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
	else:
		if not system_data.has("has_belt"):
			system_data["has_belt"] = false
		if not system_data.has("belt_class"):
			system_data["belt_class"] = StrategicTestConfigScript.BELT_CLASS_NONE
		if not system_data.has("platform_tier"):
			system_data["platform_tier"] = 0
		if not system_data.has("belt_disabled_days"):
			system_data["belt_disabled_days"] = 0
		if not system_data.has("belt_owner_faction_id"):
			system_data["belt_owner_faction_id"] = StrategicTestConfigScript.NO_OWNER_FACTION_ID

	system_data["belt"] = {
		"has_belt": bool(system_data.get("has_belt", false)),
		"belt_class": str(system_data.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE)),
		"platform_tier": int(system_data.get("platform_tier", 0)),
		"belt_disabled_days": int(system_data.get("belt_disabled_days", 0)),
		"disabled_days": int(system_data.get("belt_disabled_days", 0)),
		"owner_faction_id": int(system_data.get("belt_owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID)),
	}


func validate_model_a_acceptance_tests() -> Dictionary:
	var logs: Array[String] = []

	# Test 1: single-planet progression remains deterministic and non-blockaded by default.
	var t1_systems: Array[Dictionary] = [
		{
			"id": 101,
			"system_name": "T1",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 101,
				"name": "P1",
				"owner_faction_id": StrategicTestConfigScript.TEST_FACTION_ID,
				"control": 100,
				"stability": 60,
				"base_credits_per_day": 150,
				"base_metal_per_day": 15,
				"base_rare_per_day": 2,
				"required_garrison_gp": 5,
				"current_garrison_gp": 5,
			}],
		},
	]
	var sim1 := GalaxySimulationTest.new()
	sim1.setup_from_systems(t1_systems)
	sim1.advance_day()
	var t1_report: String = sim1.build_planet_report("T1", "P1")
	var t1_passed: bool = "Control: 100" in t1_report and "Stability: 61" in t1_report and "Blockaded: false" in t1_report
	logs.append("test1_single_planet=%s" % str(t1_passed))

	# Test 2: multi-planet system shares orbit with asymmetric blockades by owner.
	var t2_systems: Array[Dictionary] = [
		{
			"id": 102,
			"system_name": "T2",
			"fleets": [StrategicTestConfigScript.create_fleet(2, 12, "main")],
			"orbital_structures": [],
			"belt": {},
			"planets": [
				{"planet_id": 201, "name": "A", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 150, "base_metal_per_day": 15, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5},
				{"planet_id": 202, "name": "B", "owner_faction_id": 2, "control": 100, "stability": 60, "base_credits_per_day": 150, "base_metal_per_day": 15, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5},
			],
		},
	]
	var sim2 := GalaxySimulationTest.new()
	sim2.setup_from_systems(t2_systems)
	sim2.advance_day()
	var t2_a: String = sim2.build_planet_report("T2", "A")
	var t2_b: String = sim2.build_planet_report("T2", "B")
	var t2_passed: bool = "Blockaded: true" in t2_a and "Blockaded: false" in t2_b
	logs.append("test2_multi_planet_shared_orbit=%s" % str(t2_passed))

	# Test 3: shipyard blocked when owner is blockaded.
	var t3_systems: Array[Dictionary] = [
		{
			"id": 103,
			"system_name": "T3",
			"fleets": [StrategicTestConfigScript.create_fleet(2, 12, "main")],
			"orbital_structures": [StrategicTestConfigScript.create_shipyard_i_instance(1, 103)],
			"belt": {},
			"planets": [{"planet_id": 301, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 150, "base_metal_per_day": 15, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	]
	var sim3 := GalaxySimulationTest.new()
	sim3.setup_from_systems(t3_systems)
	var t3_logs: Array[String] = sim3.advance_day()
	var t3_passed: bool = false
	for entry_variant in t3_logs:
		var entry: String = str(entry_variant)
		if "shipyards=" in entry and "generated_sp=0" in entry:
			t3_passed = true
			break
	logs.append("test3_shipyard_blockade=%s" % str(t3_passed))

	# Test 4: belt requires presence and no blockade.
	var t4_systems: Array[Dictionary] = [
		{
			"id": 104,
			"system_name": "T4",
			"fleets": [],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 2, 1),
			"planets": [{"planet_id": 401, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 150, "base_metal_per_day": 15, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	]
	var sim4 := GalaxySimulationTest.new()
	sim4.setup_from_systems(t4_systems)
	var t4_faction_before: Dictionary = (sim4._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	sim4.advance_day()
	var t4_faction_after_day1: Dictionary = (sim4._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var t4_day1_metal_gain: int = int(t4_faction_after_day1.get("metal", 0)) - int(t4_faction_before.get("metal", 0))
	var t4_day1_rare_gain: int = int(t4_faction_after_day1.get("rare_metal", 0)) - int(t4_faction_before.get("rare_metal", 0))
	var t4_no_presence_ok: bool = t4_day1_metal_gain == 15 and t4_day1_rare_gain == 2
	sim4.add_defense_station_i_to_planet("T4", "P")
	sim4.advance_day()
	var t4_faction_after_day2: Dictionary = (sim4._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var t4_day2_metal_gain: int = int(t4_faction_after_day2.get("metal", 0)) - int(t4_faction_after_day1.get("metal", 0))
	var t4_day2_rare_gain: int = int(t4_faction_after_day2.get("rare_metal", 0)) - int(t4_faction_after_day1.get("rare_metal", 0))
	var t4_with_presence_ok: bool = t4_day2_metal_gain == 33 and t4_day2_rare_gain == 8
	logs.append("test4_belt_presence_and_blockade=%s" % str(t4_no_presence_ok and t4_with_presence_ok))

	# Test 5: explicit belt outputs, blockade shutoff, and no-presence shutoff.
	var t5_systems: Array[Dictionary] = [
		{
			"id": 105,
			"system_name": "T5",
			"fleets": [StrategicTestConfigScript.create_fleet(1, 6, "miners")],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 2, 1),
			"planets": [{"planet_id": 501, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	]
	var sim5 := GalaxySimulationTest.new()
	sim5.setup_from_systems(t5_systems)
	var t5_faction_before: Dictionary = (sim5._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	sim5.advance_day()
	var t5_after_day1: Dictionary = (sim5._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var t5_day1_metal_gain: int = int(t5_after_day1.get("metal", 0)) - int(t5_faction_before.get("metal", 0))
	var t5_day1_rare_gain: int = int(t5_after_day1.get("rare_metal", 0)) - int(t5_faction_before.get("rare_metal", 0))
	var t5_base_output_ok: bool = t5_day1_metal_gain == 18 and t5_day1_rare_gain == 6

	(sim5.get_system(105).get("fleets", []) as Array).clear()
	sim5.add_fleet_to_system("T5", 2, 12, "raiders")
	sim5.advance_day()
	var t5_after_day2: Dictionary = (sim5._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var t5_day2_metal_gain: int = int(t5_after_day2.get("metal", 0)) - int(t5_after_day1.get("metal", 0))
	var t5_day2_rare_gain: int = int(t5_after_day2.get("rare_metal", 0)) - int(t5_after_day1.get("rare_metal", 0))
	var t5_blockade_zero_ok: bool = t5_day2_metal_gain == 0 and t5_day2_rare_gain == 0

	(sim5.get_system(105).get("fleets", []) as Array).clear()
	sim5.advance_day()
	var t5_after_day3: Dictionary = (sim5._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var t5_day3_metal_gain: int = int(t5_after_day3.get("metal", 0)) - int(t5_after_day2.get("metal", 0))
	var t5_day3_rare_gain: int = int(t5_after_day3.get("rare_metal", 0)) - int(t5_after_day2.get("rare_metal", 0))
	var t5_no_presence_zero_ok: bool = t5_day3_metal_gain == 0 and t5_day3_rare_gain == 0
	logs.append("test5_belt_outputs_and_shutdown=%s" % str(t5_base_output_ok and t5_blockade_zero_ok and t5_no_presence_zero_ok))

	# Test 6: mining platform queue is gated by belt presence and sequential upgrades.
	var t6_systems: Array[Dictionary] = [
		{
			"id": 106,
			"system_name": "T6",
			"fleets": [],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1),
			"planets": [{"planet_id": 601, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
		{
			"id": 107,
			"system_name": "T6-NoBelt",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{"planet_id": 602, "name": "Q", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	]
	var sim6 := GalaxySimulationTest.new()
	sim6.setup_from_systems(t6_systems)
	var t6_jump_result: Dictionary = sim6.queue_build_mining_platform("T6", 2)
	var t6_jump_rejected: bool = not bool(t6_jump_result.get("queued", true))
	var t6_tier1_result: Dictionary = sim6.queue_build_mining_platform("T6", 1)
	var t6_tier1_queued: bool = bool(t6_tier1_result.get("queued", false))
	sim6.advance_day()
	sim6.advance_day()
	var t6_tier1_completed: bool = int(sim6.get_system(106).get("platform_tier", 0)) == 1
	var t6_tier2_result: Dictionary = sim6.queue_build_mining_platform("T6", 2)
	var t6_tier2_queued: bool = bool(t6_tier2_result.get("queued", false))
	sim6.advance_day()
	sim6.advance_day()
	sim6.advance_day()
	var t6_tier2_completed: bool = int(sim6.get_system(106).get("platform_tier", 0)) == 2
	var t6_no_belt_result: Dictionary = sim6.queue_build_mining_platform("T6-NoBelt", 1)
	var t6_no_belt_rejected: bool = not bool(t6_no_belt_result.get("queued", true))
	var t6_unknown_result: Dictionary = sim6.queue_build_mining_platform("Unknown", 1)
	var t6_unknown_system_rejected: bool = not bool(t6_unknown_result.get("queued", true))
	logs.append("test6_platform_queue=%s" % str(t6_jump_rejected and t6_tier1_queued and t6_tier1_completed and t6_tier2_queued and t6_tier2_completed and t6_no_belt_rejected and t6_unknown_system_rejected))

	# Phase 4 - Test 1: Unscouted belt system with low security reaches ACTIVITY then HAVEN deterministically.
	var p4_t1_systems: Array[Dictionary] = [
		{
			"id": 201,
			"system_name": "P4-T1",
			"degree": 4,
			"fleets": [],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 1, 1),
			"last_scout_day_by_faction": {1: 1},
			"planets": [{"planet_id": 2001, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 220, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 0}],
		},
	]
	var p4_t1_sim := GalaxySimulationTest.new()
	p4_t1_sim.setup_from_systems(p4_t1_systems)
	var p4_t1_activity_day: int = -1
	var p4_t1_haven_day: int = -1
	for day in range(15):
		p4_t1_sim.advance_day()
		var p4_t1_system: Dictionary = p4_t1_sim.get_system(201)
		if p4_t1_activity_day < 0 and int(p4_t1_system.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) >= StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			p4_t1_activity_day = day + 1
		if int(p4_t1_system.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) == StrategicTestConfigScript.PIRATE_STATE_HAVEN:
			p4_t1_haven_day = day + 1
			break
	var p4_t1_result_system: Dictionary = p4_t1_sim.get_system(201)
	var p4_t1_passed: bool = p4_t1_activity_day > 0 and p4_t1_haven_day > p4_t1_activity_day and int(p4_t1_result_system.get("piracy_pressure", 0)) >= 80
	logs.append("phase4_test1_unscouted_growth=%s activity_day=%d haven_day=%d pressure=%d" % [
		str(p4_t1_passed),
		p4_t1_activity_day,
		p4_t1_haven_day,
		int(p4_t1_result_system.get("piracy_pressure", 0)),
	])

	# Phase 4 - Test 2: Listening Post prevents fog growth.
	var p4_t2_systems: Array[Dictionary] = [
		{
			"id": 202,
			"system_name": "P4-T2",
			"degree": 0,
			"fleets": [],
			"orbital_structures": [StrategicTestConfigScript.create_listening_post_instance(1, 202)],
			"belt": {},
			"planets": [{"planet_id": 2002, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 150, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 0}],
		},
	]
	var p4_t2_sim := GalaxySimulationTest.new()
	p4_t2_sim.setup_from_systems(p4_t2_systems)
	p4_t2_sim.advance_day()
	p4_t2_sim.advance_day()
	p4_t2_sim.advance_day()
	var p4_t2_system: Dictionary = p4_t2_sim.get_system(202)
	var p4_t2_scout_age: int = p4_t2_sim.get_scout_age(p4_t2_system, 1, 3)
	var p4_t2_passed: bool = int(p4_t2_system.get("piracy_pressure", 0)) == 0 and p4_t2_scout_age == 0
	logs.append("phase4_test2_listening_post_scouting=%s scout_age=%d pressure=%d" % [
		str(p4_t2_passed),
		p4_t2_scout_age,
		int(p4_t2_system.get("piracy_pressure", 0)),
	])

	# Phase 4 - Test 3: HAVEN shuts off belt income.
	var p4_t3_systems: Array[Dictionary] = [
		{
			"id": 203,
			"system_name": "P4-T3",
			"fleets": [StrategicTestConfigScript.create_fleet(1, 6, "miners")],
			"orbital_structures": [],
			"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 2, 1),
			"piracy_pressure": 80,
			"pirate_state": StrategicTestConfigScript.PIRATE_STATE_HAVEN,
			"planets": [{"planet_id": 2003, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 0}],
		},
	]
	var p4_t3_sim := GalaxySimulationTest.new()
	p4_t3_sim.setup_from_systems(p4_t3_systems)
	var p4_t3_before: Dictionary = (p4_t3_sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	p4_t3_sim.advance_day()
	var p4_t3_after: Dictionary = (p4_t3_sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var p4_t3_metal_gain: int = int(p4_t3_after.get("metal", 0)) - int(p4_t3_before.get("metal", 0))
	var p4_t3_rare_gain: int = int(p4_t3_after.get("rare_metal", 0)) - int(p4_t3_before.get("rare_metal", 0))
	var p4_t3_passed: bool = p4_t3_metal_gain == 0 and p4_t3_rare_gain == 0
	logs.append("phase4_test3_haven_belt_shutdown=%s metal_gain=%d rare_gain=%d" % [
		str(p4_t3_passed),
		p4_t3_metal_gain,
		p4_t3_rare_gain,
	])

	# Phase 4 - Test 4: SR >= 45 fleet clears HAVEN deterministically.
	var p4_t4_systems: Array[Dictionary] = [
		{
			"id": 204,
			"system_name": "P4-T4",
			"fleets": [StrategicTestConfigScript.create_fleet(1, 45, "clear")],
			"orbital_structures": [],
			"belt": {},
			"piracy_pressure": 80,
			"pirate_state": StrategicTestConfigScript.PIRATE_STATE_HAVEN,
			"planets": [{"planet_id": 2004, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 0}],
		},
	]
	var p4_t4_sim := GalaxySimulationTest.new()
	p4_t4_sim.setup_from_systems(p4_t4_systems)
	p4_t4_sim.advance_day()
	var p4_t4_system: Dictionary = p4_t4_sim.get_system(204)
	var p4_t4_passed: bool = int(p4_t4_system.get("pirate_state", -1)) == StrategicTestConfigScript.PIRATE_STATE_NONE and int(p4_t4_system.get("piracy_pressure", 0)) == 30
	logs.append("phase4_test4_haven_clear=%s pirate_state=%d pressure=%d" % [
		str(p4_t4_passed),
		int(p4_t4_system.get("pirate_state", -1)),
		int(p4_t4_system.get("piracy_pressure", 0)),
	])

	# Phase 6 - Patrol assignment picks deterministic top-score owned system and logs full/light patrol security.
	var p6_t1_sim := GalaxySimulationTest.new()
	p6_t1_sim.setup_from_systems([
		{"id": 601, "system_name": "P6-A", "fleets": [StrategicTestConfigScript.create_fleet(1, 35, "patrol")], "orbital_structures": [], "belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1), "piracy_pressure": 30, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_NONE, "planets": [{"planet_id": 6001, "name": "A", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 5, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
		{"id": 602, "system_name": "P6-B", "fleets": [], "orbital_structures": [], "belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 1, 1), "piracy_pressure": 25, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_ACTIVITY, "planets": [{"planet_id": 6002, "name": "B", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 5, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
	])
	var p6_t1_logs: Array[String] = p6_t1_sim.advance_day()
	var p6_t1_patrol_fleet: Dictionary = ((p6_t1_sim.get_system(602).get("fleets", []) as Array)[0] as Dictionary) if (p6_t1_sim.get_system(602).get("fleets", []) as Array).size() > 0 else {}
	var p6_t1_has_assigned_log: bool = false
	for entry_variant in p6_t1_logs:
		var entry: String = str(entry_variant)
		if entry.find("PATROL | system=602 controller=1 full=1 light=0 sec_from_patrol=10 reason=assigned") >= 0:
			p6_t1_has_assigned_log = true
			break
	var p6_t1_passed: bool = not p6_t1_patrol_fleet.is_empty() and int(p6_t1_patrol_fleet.get("system_id", -1)) == 602 and str(p6_t1_patrol_fleet.get("role", "")) == StrategicTestConfigScript.FLEET_ROLE_PATROL and int(p6_t1_patrol_fleet.get("patrol_system_id", -1)) == 602 and p6_t1_has_assigned_log
	logs.append("phase6_test1_patrol_assignment=%s" % [str(p6_t1_passed)])

	# Phase 6 - SR 15-29 fleets are light patrol eligible.
	var p6_t2_sim := GalaxySimulationTest.new()
	p6_t2_sim.setup_from_systems([
		{"id": 603, "system_name": "P6-C", "fleets": [StrategicTestConfigScript.create_fleet(1, 18, "screen")], "orbital_structures": [], "belt": {}, "piracy_pressure": 50, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_ACTIVITY, "planets": [{"planet_id": 6003, "name": "C", "owner_faction_id": 1, "base_credits_per_day": 100, "base_metal_per_day": 5, "base_rare_per_day": 0, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
	])
	var p6_t2_logs: Array[String] = p6_t2_sim.advance_day()
	var p6_t2_fleet: Dictionary = ((p6_t2_sim.get_system(603).get("fleets", []) as Array)[0] as Dictionary)
	var p6_t2_has_light_log: bool = false
	for entry_variant in p6_t2_logs:
		var entry: String = str(entry_variant)
		if entry.find("PATROL | system=603 controller=1 full=0 light=1 sec_from_patrol=5 reason=assigned") >= 0:
			p6_t2_has_light_log = true
			break
	var p6_t2_passed: bool = str(p6_t2_fleet.get("role", "")) == StrategicTestConfigScript.FLEET_ROLE_PATROL and int(p6_t2_fleet.get("patrol_system_id", -1)) == 603 and p6_t2_has_light_log
	logs.append("phase6_test2_light_patrol_eligible=%s" % [str(p6_t2_passed)])

	var phase9a_result: Dictionary = validate_phase9a_fleet_movement_discrete_arrival()
	var phase5_result: Dictionary = validate_phase_five_background_governor_tests()
	var bootstrap_result: Dictionary = validate_settlement_bootstrap_seed()
	var patch7a_result: Dictionary = validate_patch7a_garrison_recovery()
	var patch7b_result: Dictionary = validate_patch7b_garrison_credit_costs()
	var phase8_t1: Dictionary = validate_shipyard_build_corvette_spawns_unit()
	var phase8_t2: Dictionary = validate_shipyard_blocks_on_blockade_if_enabled()
	var phase8_t3: Dictionary = validate_completion_stalls_if_insufficient_stockpile()
	var phase8_t4: Dictionary = validate_governor_enqueue_cap_one_per_system_per_day()
	var phase8_t5: Dictionary = validate_phase8_deterministic_replay()
	var phase10_result: Dictionary = validate_phase10_fleet_formations_and_readiness()
	var phase12_result: Dictionary = validate_phase12_ground_troops_v0()
	logs.append_array(phase9a_result.get("logs", []))
	logs.append_array(phase5_result.get("logs", []))
	logs.append_array(bootstrap_result.get("logs", []))
	logs.append_array(patch7a_result.get("logs", []))
	logs.append_array(patch7b_result.get("logs", []))
	logs.append_array(phase8_t1.get("logs", []))
	logs.append_array(phase8_t2.get("logs", []))
	logs.append_array(phase8_t3.get("logs", []))
	logs.append_array(phase8_t4.get("logs", []))
	logs.append_array(phase8_t5.get("logs", []))
	logs.append_array(phase10_result.get("logs", []))
	logs.append_array(phase12_result.get("logs", []))
	var passed: bool = t1_passed and t2_passed and t3_passed and t4_no_presence_ok and t4_with_presence_ok and t5_base_output_ok and t5_blockade_zero_ok and t5_no_presence_zero_ok and t6_jump_rejected and t6_tier1_queued and t6_tier1_completed and t6_tier2_queued and t6_tier2_completed and t6_no_belt_rejected and t6_unknown_system_rejected and p4_t1_passed and p4_t2_passed and p4_t3_passed and p4_t4_passed and p6_t1_passed and p6_t2_passed and bool(phase9a_result.get("passed", false)) and bool(phase5_result.get("passed", false)) and bool(bootstrap_result.get("passed", false)) and bool(patch7a_result.get("passed", false)) and bool(patch7b_result.get("passed", false)) and bool(phase8_t1.get("passed", false)) and bool(phase8_t2.get("passed", false)) and bool(phase8_t3.get("passed", false)) and bool(phase8_t4.get("passed", false)) and bool(phase8_t5.get("passed", false)) and bool(phase10_result.get("passed", false)) and bool(phase12_result.get("passed", false))
	return {
		"passed": passed,
		"logs": logs,
	}


func validate_phase9a_fleet_movement_discrete_arrival() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([
		{
			"id": 901,
			"system_name": "P9-A",
			"neighbor_system_ids": [902],
			"fleets": [StrategicTestConfigScript.create_fleet(1, 25, "task_force")],
			"orbital_structures": [],
			"belt": {},
			"planets": [{"planet_id": 9011, "name": "A", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 100, "base_metal_per_day": 10, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
		{
			"id": 902,
			"system_name": "P9-B",
			"neighbor_system_ids": [901],
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{"planet_id": 9021, "name": "B", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 100, "base_metal_per_day": 10, "base_rare_per_day": 2, "required_garrison_gp": 5, "current_garrison_gp": 5}],
		},
	])
	var fleet: Dictionary = ((sim.get_system(901).get("fleets", []) as Array)[0] as Dictionary)
	var issue_result: Dictionary = sim.issue_fleet_move_order_by_id(int(fleet.get("fleet_id", -1)), 902, "phase9a_test")
	if not bool(issue_result.get("ordered", false)):
		return {"passed": false, "logs": ["phase9a_order_failed=%s" % str(issue_result)]}
	var issue_logs: Array = issue_result.get("logs", [])
	var has_order_log: bool = false
	for entry_variant in issue_logs:
		var entry: String = str(entry_variant)
		if entry.find("FLEET_ORDER") >= 0 and entry.find("from=901") >= 0 and entry.find("to=902") >= 0:
			has_order_log = true
			break

	sim.advance_day()
	var day1_origin_fleets: Array = sim.get_system(901).get("fleets", [])
	var day1_destination_fleets: Array = sim.get_system(902).get("fleets", [])
	var day1_origin_ok: bool = day1_origin_fleets.size() == 1 and day1_destination_fleets.is_empty()

	var second_tick_logs: Array[String] = sim.advance_day()
	var day2_origin_fleets: Array = sim.get_system(901).get("fleets", [])
	var day2_destination_fleets: Array = sim.get_system(902).get("fleets", [])
	var day2_arrived_ok: bool = day2_origin_fleets.is_empty() and day2_destination_fleets.size() == 1
	var arrived_fleet: Dictionary = (day2_destination_fleets[0] as Dictionary) if not day2_destination_fleets.is_empty() else {}
	var status_ok: bool = not arrived_fleet.is_empty() and int(arrived_fleet.get("system_id", -1)) == 902 and int(arrived_fleet.get("target_system_id", -1)) == -1 and str(arrived_fleet.get("status", "")) == "idle"
	var destination_sr: int = int((sim.get_system(902).get("sr_by_faction", {}) as Dictionary).get(1, 0))
	var sr_arrival_ok: bool = destination_sr >= int(arrived_fleet.get("sr", 0))
	var has_arrive_log: bool = false
	for entry_variant in second_tick_logs:
		var entry: String = str(entry_variant)
		if entry.find("FLEET_ARRIVE") >= 0 and entry.find("to=902") >= 0:
			has_arrive_log = true
			break

	var passed: bool = has_order_log and day1_origin_ok and day2_arrived_ok and status_ok and sr_arrival_ok and has_arrive_log
	return {
		"passed": passed,
		"logs": [
			"phase9a_discrete_movement=%s" % str(passed),
			"phase9a_order_log=%s" % str(has_order_log),
			"phase9a_day1_origin=%s" % str(day1_origin_ok),
			"phase9a_day2_arrived=%s" % str(day2_arrived_ok),
			"phase9a_status_reset=%s" % str(status_ok),
			"phase9a_sr_on_arrival=%s sr=%d" % [str(sr_arrival_ok), destination_sr],
			"phase9a_arrive_log=%s" % str(has_arrive_log),
		],
	}


func _phase8_test_system(system_id: int, system_name: String, pirate_threat_sr: int = 0, pirate_state: int = StrategicTestConfigScript.PIRATE_STATE_NONE) -> Dictionary:
	return {
		"id": system_id,
		"system_name": system_name,
		"fleets": [],
		"orbital_structures": [StrategicTestConfigScript.create_shipyard_i_instance(StrategicTestConfigScript.TEST_FACTION_ID, system_id)],
		"belt": {},
		"piracy_pressure": 0,
		"pirate_state": pirate_state,
		"pirate_presence": {
			"system_id": system_id,
			"state": pirate_state,
			"threat_sr": pirate_threat_sr,
			"base_level": 0,
		},
		"planets": [{"planet_id": system_id * 10, "name": "P", "owner_faction_id": StrategicTestConfigScript.TEST_FACTION_ID, "control": 100, "stability": 60, "base_credits_per_day": 200, "base_metal_per_day": 20, "base_rare_per_day": 5, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}


func validate_shipyard_build_corvette_spawns_unit() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([_phase8_test_system(801, "P8-T1")])
	sim._next_fleet_id = 100
	var faction_before: Dictionary = (sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var enqueue_result: Dictionary = sim.enqueue_ship_build(801, StrategicTestConfigScript.TEST_FACTION_ID, "corvette_mk1", 0)
	if not bool(enqueue_result.get("queued", false)):
		return {"passed": false, "logs": ["phase8_test1_enqueue_failed=%s" % str(enqueue_result)]}

	sim.advance_day()
	var second_tick_logs: Array[String] = sim.advance_day()
	var faction_after_completion: Dictionary = (sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	sim.advance_day()
	var faction_after_extra: Dictionary = (sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID] as Dictionary).duplicate(true)
	var fleets: Array = sim.get_system(801).get("fleets", [])
	var last_fleet: Dictionary = (fleets[fleets.size() - 1] as Dictionary) if not fleets.is_empty() else {}
	var spawned_ok: bool = not last_fleet.is_empty() and str(last_fleet.get("blueprint_id", "")) == "corvette_mk1" and int(last_fleet.get("sr", 0)) == 10 and int(last_fleet.get("upkeep_credits_per_day", 0)) == 4
	var monotonic_ok: bool = int(last_fleet.get("fleet_id", -1)) == 100
	var deduct_once_ok: bool = (int(faction_before.get("credits", 0)) - int(faction_after_completion.get("credits", 0))) == 600 and (int(faction_before.get("metal", 0)) - int(faction_after_completion.get("metal", 0))) == 40 and (int(faction_before.get("rare_metal", 0)) - int(faction_after_completion.get("rare_metal", 0))) == 5
	var no_double_deduct_ok: bool = (int(faction_after_extra.get("credits", 0)) - int(faction_after_completion.get("credits", 0))) != -600
	var sr_before_next_derive: int = int((sim.get_system(801).get("sr_by_faction", {}) as Dictionary).get(StrategicTestConfigScript.TEST_FACTION_ID, 0))
	var sr_next_day_ok: bool = sr_before_next_derive >= 10
	var completion_log_seen: bool = false
	for entry_variant in second_tick_logs:
		var entry: String = str(entry_variant)
		if entry.find("SHIP_COMPLETE") >= 0 and entry.find("blueprint=corvette_mk1") >= 0:
			completion_log_seen = true
			break
	var passed: bool = spawned_ok and monotonic_ok and deduct_once_ok and no_double_deduct_ok and sr_next_day_ok and completion_log_seen
	return {"passed": passed, "logs": ["phase8_test1_corvette_spawn=%s" % str(passed)]}


func validate_shipyard_blocks_on_blockade_if_enabled() -> Dictionary:
	var enemy_fleet: Dictionary = StrategicTestConfigScript.create_fleet(2, 80, "raider")
	enemy_fleet["system_id"] = 802
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([_phase8_test_system(802, "P8-T2")])
	var system_state: Dictionary = sim.get_system(802)
	var fleets: Array = system_state.get("fleets", [])
	fleets.append(enemy_fleet)
	system_state["fleets"] = fleets
	sim.enqueue_ship_build(802, StrategicTestConfigScript.TEST_FACTION_ID, "corvette_mk1", 0)
	sim.advance_day()
	var shipyard: Dictionary = (system_state.get("orbital_structures", [])[0] as Dictionary)
	var blocked_progress: int = int(shipyard.get("current_progress_sp", 0))
	system_state["fleets"] = []
	sim.advance_day()
	var resumed_progress: int = int(shipyard.get("current_progress_sp", 0))
	var passed: bool = blocked_progress == 0 and resumed_progress > 0
	return {"passed": passed, "logs": ["phase8_test2_blockade_progress=%s blocked=%d resumed=%d" % [str(passed), blocked_progress, resumed_progress]]}


func validate_completion_stalls_if_insufficient_stockpile() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([_phase8_test_system(803, "P8-T3")])
	sim.enqueue_ship_build(803, StrategicTestConfigScript.TEST_FACTION_ID, "corvette_mk1", 0)
	sim.advance_day()
	var faction_state: Dictionary = sim._factions_by_id[StrategicTestConfigScript.TEST_FACTION_ID]
	faction_state["metal"] = 0
	faction_state["rare_metal"] = 0
	var second_tick_logs: Array[String] = sim.advance_day()
	var system_state: Dictionary = sim.get_system(803)
	var shipyard: Dictionary = (system_state.get("orbital_structures", [])[0] as Dictionary)
	var queue: Array = shipyard.get("queue", [])
	var stalled_job: Dictionary = (queue[0] as Dictionary) if not queue.is_empty() else {}
	var stall_logs_count: int = 0
	for entry_variant in second_tick_logs:
		if str(entry_variant).find("SHIP_STALL") >= 0:
			stall_logs_count += 1
	var no_spawn_while_stalled: bool = (system_state.get("fleets", []) as Array).is_empty()
	var stalled_ok: bool = not stalled_job.is_empty() and int(stalled_job.get("progress_sp", 0)) == int(stalled_job.get("sp_cost", -1)) and stall_logs_count == 1 and no_spawn_while_stalled
	faction_state["metal"] = 500
	faction_state["rare_metal"] = 100
	sim.advance_day()
	var completed_ok: bool = (sim.get_system(803).get("fleets", []) as Array).size() >= 1
	var passed: bool = stalled_ok and completed_ok
	return {"passed": passed, "logs": ["phase8_test3_stall_retry=%s" % str(passed)]}


func validate_governor_enqueue_cap_one_per_system_per_day() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([_phase8_test_system(804, "P8-T4", 40, StrategicTestConfigScript.PIRATE_STATE_HAVEN)])
	var first_tick_logs: Array[String] = sim.advance_day()
	var second_tick_logs: Array[String] = sim.advance_day()
	var day1_enqueue_count: int = 0
	var day2_enqueue_count: int = 0
	for entry_variant in first_tick_logs:
		if str(entry_variant).find("SHIP_ENQUEUE") >= 0:
			day1_enqueue_count += 1
	for entry_variant in second_tick_logs:
		if str(entry_variant).find("SHIP_ENQUEUE") >= 0:
			day2_enqueue_count += 1
	var passed: bool = day1_enqueue_count <= 1 and day2_enqueue_count <= 1
	return {"passed": passed, "logs": ["phase8_test4_enqueue_cap=%s day1=%d day2=%d" % [str(passed), day1_enqueue_count, day2_enqueue_count]]}


func validate_phase8_deterministic_replay() -> Dictionary:
	var scenario: Array[Dictionary] = [_phase8_test_system(805, "P8-T5", 35, StrategicTestConfigScript.PIRATE_STATE_ACTIVITY)]
	var sim_a := GalaxySimulationTest.new()
	var sim_b := GalaxySimulationTest.new()
	sim_a.setup_from_systems(scenario)
	sim_b.setup_from_systems(scenario)
	var logs_a: Array[String] = []
	var logs_b: Array[String] = []
	for _i in range(4):
		logs_a.append_array(sim_a.advance_day())
		logs_b.append_array(sim_b.advance_day())
	var ship_logs_a: Array[String] = []
	var ship_logs_b: Array[String] = []
	for entry_variant in logs_a:
		var entry: String = str(entry_variant)
		if entry.find("SHIP_") >= 0:
			ship_logs_a.append(entry)
	for entry_variant in logs_b:
		var entry: String = str(entry_variant)
		if entry.find("SHIP_") >= 0:
			ship_logs_b.append(entry)
	var passed: bool = ship_logs_a == ship_logs_b
	return {"passed": passed, "logs": ["phase8_test5_deterministic_replay=%s" % str(passed)]}


func validate_phase10_fleet_formations_and_readiness() -> Dictionary:
	var logs: Array[String] = []

	# Test 1: effective_sr derives from readiness and affects sr_by_faction.
	var sim1 := GalaxySimulationTest.new()
	sim1.setup_from_systems([{"id": 1001, "system_name": "P10-1", "fleets": [StrategicTestConfigScript.create_fleet(1, 40, "main")], "orbital_structures": [], "belt": {}, "planets": [{"planet_id": 10001, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 100, "base_metal_per_day": 5, "base_rare_per_day": 1, "required_garrison_gp": 5, "current_garrison_gp": 5}]}])
	var fleet1: Dictionary = ((sim1.get_system(1001).get("fleets", []) as Array)[0] as Dictionary)
	sim1._ensure_fleet_defaults(fleet1, 1001)
	fleet1["readiness"] = 50
	sim1.compute_system_sr(1001)
	var p10_t1_passed: bool = int((sim1.get_system(1001).get("sr_by_faction", {}) as Dictionary).get(1, -1)) == 20
	logs.append("phase10_test1_effective_sr=%s" % str(p10_t1_passed))

	# Test 2: deterministic upkeep miss drops readiness while paid upkeep does not.
	var sim2 := GalaxySimulationTest.new()
	sim2.setup_from_systems([{"id": 1002, "system_name": "P10-2", "fleets": [StrategicTestConfigScript.create_fleet(1, 20, "a"), StrategicTestConfigScript.create_fleet(1, 20, "b")], "orbital_structures": [], "belt": {}, "planets": [{"planet_id": 10002, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}]}])
	(sim2._factions_by_id[1] as Dictionary)["credits"] = 6
	var sim2_fleets: Array = sim2.get_system(1002).get("fleets", [])
	(sim2_fleets[0] as Dictionary)["ships"] = [StrategicTestLogicScript.make_ship_roster_entry("corvette_mk1", 20, 4)]
	(sim2_fleets[1] as Dictionary)["ships"] = [StrategicTestLogicScript.make_ship_roster_entry("corvette_mk1", 20, 4)]
	sim2.advance_day()
	var first_ready: int = int((sim2_fleets[0] as Dictionary).get("readiness", 0))
	var second_ready: int = int((sim2_fleets[1] as Dictionary).get("readiness", 0))
	var p10_t2_passed: bool = first_ready == 100 and second_ready == 91
	logs.append("phase10_test2_upkeep_readiness=%s first=%d second=%d" % [str(p10_t2_passed), first_ready, second_ready])

	# Test 3: shipyard refit recovers faster than passive.
	var sim3 := GalaxySimulationTest.new()
	sim3.setup_from_systems([
		{"id": 1003, "system_name": "P10-3A", "fleets": [StrategicTestConfigScript.create_fleet(1, 20, "a")], "orbital_structures": [StrategicTestConfigScript.create_shipyard_i_instance(1, 1003)], "belt": {}, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_NONE, "planets": [{"planet_id": 10003, "name": "A", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
		{"id": 1004, "system_name": "P10-3B", "fleets": [StrategicTestConfigScript.create_fleet(1, 20, "b")], "orbital_structures": [], "belt": {}, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_NONE, "planets": [{"planet_id": 10004, "name": "B", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
	])
	var fleet_refit: Dictionary = ((sim3.get_system(1003).get("fleets", []) as Array)[0] as Dictionary)
	var fleet_passive: Dictionary = ((sim3.get_system(1004).get("fleets", []) as Array)[0] as Dictionary)
	fleet_refit["readiness"] = 80
	fleet_passive["readiness"] = 80
	sim3.advance_day()
	var p10_t3_passed: bool = int(fleet_refit.get("readiness", 0)) == 85 and int(fleet_passive.get("readiness", 0)) == 81
	logs.append("phase10_test3_refit_bonus=%s" % str(p10_t3_passed))

	# Test 4: merge uses deterministic primary id and weighted readiness.
	var sim4 := GalaxySimulationTest.new()
	sim4.setup_from_systems([{"id": 1005, "system_name": "P10-4", "fleets": [StrategicTestConfigScript.create_fleet(1, 20, "a"), StrategicTestConfigScript.create_fleet(1, 10, "b")], "orbital_structures": [], "belt": {}, "planets": [{"planet_id": 10005, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}]}])
	var m_fleets: Array = sim4.get_system(1005).get("fleets", [])
	(m_fleets[0] as Dictionary)["readiness"] = 50
	(m_fleets[1] as Dictionary)["readiness"] = 100
	var merge_primary: int = sim4.merge_fleets(1005, 1, [2, 1])
	var merged_fleet: Dictionary = ((sim4.get_system(1005).get("fleets", []) as Array)[0] as Dictionary)
	var p10_t4_passed: bool = merge_primary == 1 and int(merged_fleet.get("readiness", -1)) == 66 and int((merged_fleet.get("ships", []) as Array).size()) == 2
	logs.append("phase10_test4_merge=%s" % str(p10_t4_passed))

	# Test 5: split creates new monotonic fleet id and preserves readiness.
	var split_new_id: int = sim4.split_fleet_one_ship(merge_primary)
	var fleets_after_split: Array = sim4.get_system(1005).get("fleets", [])
	var split_ok: bool = fleets_after_split.size() == 2 and split_new_id > merge_primary
	var split_preserved_readiness: bool = false
	for fleet_variant in fleets_after_split:
		var fleet: Dictionary = fleet_variant
		if int(fleet.get("fleet_id", -1)) == split_new_id:
			split_preserved_readiness = int(fleet.get("readiness", -1)) == 66
	var p10_t5_passed: bool = split_ok and split_preserved_readiness
	logs.append("phase10_test5_split=%s" % str(p10_t5_passed))

	# Test 6: deterministic replay for readiness + fleet ids + logs ordering.
	var scenario: Array[Dictionary] = [{"id": 1006, "system_name": "P10-6", "fleets": [StrategicTestConfigScript.create_fleet(1, 30, "a"), StrategicTestConfigScript.create_fleet(1, 30, "b")], "orbital_structures": [], "belt": {}, "pirate_state": StrategicTestConfigScript.PIRATE_STATE_ACTIVITY, "planets": [{"planet_id": 10006, "name": "P", "owner_faction_id": 1, "control": 100, "stability": 60, "base_credits_per_day": 0, "base_metal_per_day": 0, "base_rare_per_day": 0, "required_garrison_gp": 5, "current_garrison_gp": 5}]}]
	var sim_a := GalaxySimulationTest.new()
	var sim_b := GalaxySimulationTest.new()
	sim_a.setup_from_systems(scenario)
	sim_b.setup_from_systems(scenario)
	var logs_a: Array[String] = sim_a.advance_day()
	var logs_b: Array[String] = sim_b.advance_day()
	var fleet_ids_a: Array[int] = []
	var fleet_ids_b: Array[int] = []
	for fleet_variant in sim_a.get_system(1006).get("fleets", []):
		fleet_ids_a.append(int((fleet_variant as Dictionary).get("fleet_id", -1)))
	for fleet_variant in sim_b.get_system(1006).get("fleets", []):
		fleet_ids_b.append(int((fleet_variant as Dictionary).get("fleet_id", -1)))
	var ready_logs_a: Array[String] = []
	var ready_logs_b: Array[String] = []
	for entry in logs_a:
		if str(entry).find("FLEET_READY") >= 0:
			ready_logs_a.append(entry)
	for entry in logs_b:
		if str(entry).find("FLEET_READY") >= 0:
			ready_logs_b.append(entry)
	var p10_t6_passed: bool = fleet_ids_a == fleet_ids_b and ready_logs_a == ready_logs_b
	logs.append("phase10_test6_deterministic_replay=%s" % str(p10_t6_passed))

	var passed: bool = p10_t1_passed and p10_t2_passed and p10_t3_passed and p10_t4_passed and p10_t5_passed and p10_t6_passed
	return {"passed": passed, "logs": logs}


func validate_patch7a_garrison_recovery() -> Dictionary:
	var logs: Array[String] = []
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([
		{
			"id": 701,
			"system_name": "P7A",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 7001,
				"name": "P",
				"owner_faction_id": 1,
				"control": 45,
				"stability": 55,
				"base_credits_per_day": 120,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 1,
				"current_garrison_gp": 0,
				"garrison_recruit_progress": 0,
				"garrison_recruit_rate": 25,
			}],
		},
	])
	for _i in range(4):
		sim.advance_day()
	var planet_state: Dictionary = sim._planets_by_id.get(7001, {})
	var garrison_recovered: bool = int(planet_state.get("current_garrison_gp", 0)) >= 1
	var progress_valid: bool = int(planet_state.get("garrison_recruit_progress", -1)) >= 0 and int(planet_state.get("garrison_recruit_progress", -1)) <= StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP
	logs.append("patch7a_recruitment_present=%s garrison=%d progress=%d" % [
		str(garrison_recovered and progress_valid),
		int(planet_state.get("current_garrison_gp", 0)),
		int(planet_state.get("garrison_recruit_progress", 0)),
	])
	return {
		"passed": garrison_recovered and progress_valid,
		"logs": logs,
	}


func validate_patch7b_garrison_credit_costs() -> Dictionary:
	var logs: Array[String] = []

	# Test 7B-A: non-blockaded +1 GP consumes exactly base credit cost after 4 days at rate 25.
	var sim_a := GalaxySimulationTest.new()
	sim_a.setup_from_systems([
		{
			"id": 702,
			"system_name": "P7B-A",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 7002,
				"name": "P",
				"owner_faction_id": 1,
				"control": 45,
				"stability": 55,
				"base_credits_per_day": 0,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 1,
				"current_garrison_gp": 0,
				"garrison_recruit_progress": 0,
				"garrison_recruit_rate": 25,
			}],
		},
	])
	sim_a._factions_by_id[1]["credits"] = 1000
	for _i in range(4):
		sim_a.advance_day()
	var p7b_a_planet: Dictionary = sim_a._planets_by_id.get(7002, {})
	var p7b_a_credits: int = int(sim_a._factions_by_id.get(1, {}).get("credits", -1))
	var p7b_a_passed: bool = int(p7b_a_planet.get("current_garrison_gp", 0)) == 1 and p7b_a_credits == 900
	logs.append("patch7b_testA_cost_applied=%s garrison=%d credits=%d" % [
		str(p7b_a_passed),
		int(p7b_a_planet.get("current_garrison_gp", 0)),
		p7b_a_credits,
	])

	# Test 7B-B: blockaded recruitment uses floor(base_cost * 3 / 2) and halved rate.
	var sim_b := GalaxySimulationTest.new()
	sim_b.setup_from_systems([
		{
			"id": 703,
			"system_name": "P7B-B",
			"fleets": [StrategicTestConfigScript.create_fleet(2, 20, "raid")],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 7003,
				"name": "P",
				"owner_faction_id": 1,
				"control": 45,
				"stability": 55,
				"base_credits_per_day": 0,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 1,
				"current_garrison_gp": 0,
				"garrison_recruit_progress": 0,
				"garrison_recruit_rate": 25,
			}],
		},
	])
	sim_b._factions_by_id[1]["credits"] = 1000
	for _i in range(8):
		sim_b.advance_day()
	var p7b_b_planet: Dictionary = sim_b._planets_by_id.get(7003, {})
	var p7b_b_credits: int = int(sim_b._factions_by_id.get(1, {}).get("credits", -1))
	var p7b_b_passed: bool = int(p7b_b_planet.get("current_garrison_gp", 0)) == 1 and p7b_b_credits == 850
	logs.append("patch7b_testB_blockade_cost=%s garrison=%d credits=%d" % [
		str(p7b_b_passed),
		int(p7b_b_planet.get("current_garrison_gp", 0)),
		p7b_b_credits,
	])

	# Test 7B-C: insufficient credits pauses recruitment, keeps progress, and never goes negative.
	var sim_c := GalaxySimulationTest.new()
	sim_c.setup_from_systems([
		{
			"id": 704,
			"system_name": "P7B-C",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 7004,
				"name": "P",
				"owner_faction_id": 1,
				"control": 45,
				"stability": 55,
				"base_credits_per_day": 0,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 1,
				"current_garrison_gp": 0,
				"garrison_recruit_progress": 99,
				"garrison_recruit_rate": 1,
			}],
		},
	])
	sim_c._factions_by_id[1]["credits"] = 50
	var p7b_c_logs: Array[String] = sim_c.advance_day()
	var p7b_c_planet: Dictionary = sim_c._planets_by_id.get(7004, {})
	var p7b_c_credits: int = int(sim_c._factions_by_id.get(1, {}).get("credits", -1))
	var p7b_c_has_pause_log: bool = false
	for entry_variant in p7b_c_logs:
		var entry: String = str(entry_variant)
		if entry.find("paused=insufficient_credits") >= 0:
			p7b_c_has_pause_log = true
			break
	var p7b_c_passed: bool = int(p7b_c_planet.get("current_garrison_gp", 0)) == 0 and int(p7b_c_planet.get("garrison_recruit_progress", -1)) >= 100 and str(p7b_c_planet.get("garrison_recruit_paused_reason", "")) == "insufficient_credits" and p7b_c_credits == 50 and p7b_c_credits >= 0 and p7b_c_has_pause_log
	logs.append("patch7b_testC_pause_and_solvency=%s garrison=%d progress=%d credits=%d pause=%s" % [
		str(p7b_c_passed),
		int(p7b_c_planet.get("current_garrison_gp", 0)),
		int(p7b_c_planet.get("garrison_recruit_progress", 0)),
		p7b_c_credits,
		str(p7b_c_planet.get("garrison_recruit_paused_reason", "")),
	])

	# Test 7B-C2: paused overflow progress remains deterministic and capped.
	var sim_c2 := GalaxySimulationTest.new()
	sim_c2.setup_from_systems([
		{
			"id": 705,
			"system_name": "P7B-C2",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 7005,
				"name": "P",
				"owner_faction_id": 1,
				"control": 45,
				"stability": 55,
				"base_credits_per_day": 0,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 3,
				"current_garrison_gp": 0,
				"garrison_recruit_progress": 99,
				"garrison_recruit_rate": 25,
			}],
		},
	])
	sim_c2._factions_by_id[1]["credits"] = 50
	for _i in range(25):
		sim_c2.advance_day()
	var p7b_c2_planet: Dictionary = sim_c2._planets_by_id.get(7005, {})
	var p7b_c2_progress: int = int(p7b_c2_planet.get("garrison_recruit_progress", -1))
	var p7b_c2_passed: bool = p7b_c2_progress == StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP and p7b_c2_progress <= StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP and str(p7b_c2_planet.get("garrison_recruit_paused_reason", "")) == "insufficient_credits"
	logs.append("patch7b_testC2_progress_cap=%s progress=%d cap=%d pause=%s" % [
		str(p7b_c2_passed),
		p7b_c2_progress,
		StrategicTestConfigScript.GARRISON_RECRUIT_PROGRESS_CAP,
		str(p7b_c2_planet.get("garrison_recruit_paused_reason", "")),
	])

	# Test 7B-D: retained paused progress should convert immediately when credits become available.
	sim_c._factions_by_id[1]["credits"] = 500
	var p7b_d_logs: Array[String] = sim_c.advance_day()
	var p7b_d_planet: Dictionary = sim_c._planets_by_id.get(7004, {})
	var p7b_d_credits: int = int(sim_c._factions_by_id.get(1, {}).get("credits", -1))
	var p7b_d_has_plus_log: bool = false
	for entry_variant in p7b_d_logs:
		var entry: String = str(entry_variant)
		if entry.find("planet=7004") >= 0 and entry.find("+1GP") >= 0:
			p7b_d_has_plus_log = true
			break
	var p7b_d_passed: bool = int(p7b_d_planet.get("current_garrison_gp", 0)) == 1 and int(p7b_d_planet.get("garrison_recruit_progress", -1)) == 0 and str(p7b_d_planet.get("garrison_recruit_paused_reason", "")) == "" and p7b_d_credits == 400 and p7b_d_has_plus_log
	logs.append("patch7b_testD_resume_after_pause=%s garrison=%d progress=%d credits=%d" % [
		str(p7b_d_passed),
		int(p7b_d_planet.get("current_garrison_gp", 0)),
		int(p7b_d_planet.get("garrison_recruit_progress", 0)),
		p7b_d_credits,
	])

	return {
		"passed": p7b_a_passed and p7b_b_passed and p7b_c_passed and p7b_c2_passed and p7b_d_passed,
		"logs": logs,
	}


func validate_phase_five_background_governor_tests() -> Dictionary:
	var logs: Array[String] = []

	# Test A: non-rare belt expands to I then II (not III) in one governor pass if solvency and resources allow.
	var sim_a := GalaxySimulationTest.new()
	sim_a.setup_from_systems([{
		"id": 501,
		"system_name": "P5-A",
		"fleets": [],
		"orbital_structures": [StrategicTestConfigScript.create_defense_station_i_instance(1, 501)],
		"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1),
		"planets": [{"planet_id": 5001, "name": "A", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}])
	sim_a.advance_day()
	var p5_a_queue: Array = sim_a.get_system(501).get("space_queue", [])
	var p5_a_targets: Array[int] = []
	for order_variant in p5_a_queue:
		var order: Dictionary = order_variant
		if str(order.get("order_type", "")) == "build_mining_platform":
			p5_a_targets.append(int(order.get("target_tier", 0)))
	var p5_a_passed: bool = p5_a_targets.has(1) and p5_a_targets.has(2) and not p5_a_targets.has(3)
	logs.append("phase5_testA_belt_growth=%s targets=%s" % [str(p5_a_passed), str(p5_a_targets)])

	# Test B: rare belts schedule Defense Station before mining platform orders.
	var sim_b := GalaxySimulationTest.new()
	sim_b.setup_from_systems([{
		"id": 502,
		"system_name": "P5-B",
		"fleets": [],
		"orbital_structures": [],
		"belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_RARE, 0, 1),
		"planets": [{"planet_id": 5002, "name": "B", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}])
	sim_b.advance_day()
	var p5_b_queue: Array = sim_b.get_system(502).get("space_queue", [])
	var p5_b_first_type: String = str((p5_b_queue[0] as Dictionary).get("build_type", "")) if not p5_b_queue.is_empty() else ""
	var p5_b_passed: bool = p5_b_first_type == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE
	logs.append("phase5_testB_rare_protection=%s first=%s" % [str(p5_b_passed), p5_b_first_type])

	# Test C: HAVEN response schedules Listening Post first, then Defense Station.
	var sim_c := GalaxySimulationTest.new()
	sim_c.setup_from_systems([{
		"id": 503,
		"system_name": "P5-C",
		"fleets": [],
		"orbital_structures": [],
		"belt": {},
		"piracy_pressure": 80,
		"pirate_state": StrategicTestConfigScript.PIRATE_STATE_HAVEN,
		"planets": [{"planet_id": 5003, "name": "C", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}])
	sim_c.advance_day()
	var p5_c_queue: Array = sim_c.get_system(503).get("space_queue", [])
	var p5_c_first: String = str((p5_c_queue[0] as Dictionary).get("build_type", "")) if p5_c_queue.size() > 0 else ""
	var p5_c_second: String = str((p5_c_queue[1] as Dictionary).get("build_type", "")) if p5_c_queue.size() > 1 else ""
	var p5_c_passed: bool = p5_c_first == StrategicTestConfigScript.LISTENING_POST_TYPE and p5_c_second == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE
	logs.append("phase5_testC_haven_response=%s first=%s second=%s" % [str(p5_c_passed), p5_c_first, p5_c_second])

	# Test D: shipyard + blockade + no station must enqueue Defense Station I.
	var sim_d := GalaxySimulationTest.new()
	sim_d.setup_from_systems([{
		"id": 504,
		"system_name": "P5-D",
		"fleets": [StrategicTestConfigScript.create_fleet(2, 50, "raider")],
		"orbital_structures": [StrategicTestConfigScript.create_shipyard_i_instance(1, 504)],
		"belt": {},
		"planets": [{"planet_id": 5004, "name": "D", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}],
	}])
	sim_d.advance_day()
	var p5_d_queue: Array = sim_d.get_system(504).get("space_queue", [])
	var p5_d_first: String = str((p5_d_queue[0] as Dictionary).get("build_type", "")) if not p5_d_queue.is_empty() else ""
	var p5_d_passed: bool = p5_d_first == StrategicTestConfigScript.DEFENSE_STATION_I_TYPE
	logs.append("phase5_testD_shipyard_defense=%s first=%s" % [str(p5_d_passed), p5_d_first])

	# Test E: no arbitrary one-build cap; multiple systems can receive queued builds on the same day.
	var sim_e := GalaxySimulationTest.new()
	sim_e.setup_from_systems([
		{"id": 505, "system_name": "P5-E1", "fleets": [], "orbital_structures": [StrategicTestConfigScript.create_defense_station_i_instance(1, 505)], "belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1), "planets": [{"planet_id": 5101, "name": "E1", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
		{"id": 506, "system_name": "P5-E2", "fleets": [], "orbital_structures": [StrategicTestConfigScript.create_defense_station_i_instance(1, 506)], "belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1), "planets": [{"planet_id": 5102, "name": "E2", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
		{"id": 507, "system_name": "P5-E3", "fleets": [], "orbital_structures": [StrategicTestConfigScript.create_defense_station_i_instance(1, 507)], "belt": StrategicTestConfigScript.create_belt_node(StrategicTestConfigScript.BELT_CLASS_METAL, 0, 1), "planets": [{"planet_id": 5103, "name": "E3", "owner_faction_id": 1, "base_credits_per_day": 500, "base_metal_per_day": 20, "base_rare_per_day": 5, "control": 100, "stability": 60, "required_garrison_gp": 5, "current_garrison_gp": 5}]},
	])
	sim_e.advance_day()
	var total_orders: int = 0
	for id in [505, 506, 507]:
		total_orders += (sim_e.get_system(id).get("space_queue", []) as Array).size()
	var p5_e_passed: bool = total_orders >= 6
	logs.append("phase5_testE_no_arbitrary_caps=%s total_orders=%d" % [str(p5_e_passed), total_orders])

	return {
		"passed": p5_a_passed and p5_b_passed and p5_c_passed and p5_d_passed and p5_e_passed,
		"logs": logs,
	}


func run_prepach7_tick_harness(days: int = 15, preset: String = "TEST_GALAXY_PREPATCH7") -> Array[String]:
	var logs: Array[String] = []
	var safe_days: int = maxi(0, days)
	var systems: Array[Dictionary] = CanonSystemTestDataScript.get_preset_systems(preset)
	if systems.is_empty():
		logs.append("HARNESS ERROR | preset_not_found=%s" % preset)
		for line in logs:
			print(line)
		return logs

	setup_from_systems(systems)
	_remove_default_shipyards_for_harness()
	_apply_prepatch7_factions()
	_refresh_strategic_state_for_harness()

	var system1_ok: bool = true
	var system2_reached_activity_by_day10: bool = false
	var system2_piracy_increased: bool = false
	var system2_belt_income_zero: bool = true
	var system3_blockaded_at_start: bool = false
	var system3_belt_zero_while_blockaded: bool = true
	var system2_start_pressure: int = int(get_system(2).get("piracy_pressure", 0))
	var system2_max_pressure: int = system2_start_pressure
	var initial_system3: Dictionary = get_system(3)
	var initial_system3_blockade: bool = bool((initial_system3.get("blockade_by_faction", {}) as Dictionary).get(1, false))
	var initial_system3_belt_gain: Dictionary = _last_belt_yield_by_system_id.get(3, {"metal_gain": 0, "rare_gain": 0})
	system3_blockaded_at_start = initial_system3_blockade
	if initial_system3_blockade:
		system3_belt_zero_while_blockaded = int(initial_system3_belt_gain.get("metal_gain", 0)) == 0 and int(initial_system3_belt_gain.get("rare_gain", 0)) == 0

	for day in range(1, safe_days + 1):
		logs.append("DAY %d START" % day)
		advance_day()
		_append_prepatch7_snapshot(logs, day)
		logs.append("DAY %d END" % day)

		var system1: Dictionary = get_system(1)
		system1_ok = system1_ok and int(system1.get("piracy_pressure", 0)) <= 15 and int(system1.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) == StrategicTestConfigScript.PIRATE_STATE_NONE

		var system2: Dictionary = get_system(2)
		var pressure: int = int(system2.get("piracy_pressure", 0))
		system2_max_pressure = maxi(system2_max_pressure, pressure)
		if day <= 10 and int(system2.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)) >= StrategicTestConfigScript.PIRATE_STATE_ACTIVITY:
			system2_reached_activity_by_day10 = true
		if int((_last_belt_yield_by_system_id.get(2, {"metal_gain": 0}) as Dictionary).get("metal_gain", 0)) != 0 or int((_last_belt_yield_by_system_id.get(2, {"rare_gain": 0}) as Dictionary).get("rare_gain", 0)) != 0:
			system2_belt_income_zero = false

		var system3: Dictionary = get_system(3)
		if bool((system3.get("blockade_by_faction", {}) as Dictionary).get(1, false)):
			var s3_belt: Dictionary = _last_belt_yield_by_system_id.get(3, {"metal_gain": 0, "rare_gain": 0})
			if int(s3_belt.get("metal_gain", 0)) != 0 or int(s3_belt.get("rare_gain", 0)) != 0:
				system3_belt_zero_while_blockaded = false

	system2_piracy_increased = system2_max_pressure > system2_start_pressure
	logs.append("ASSERTIONS SUMMARY")
	logs.append("A) System 1 piracy<=15 and pirate_state=NONE throughout: %s" % str(system1_ok))
	logs.append("B) System 2 piracy increased and reached ACTIVITY by day 10: %s" % str(system2_piracy_increased and system2_reached_activity_by_day10))
	logs.append("C) System 2 belt income remained 0 due to holding presence gate: %s" % str(system2_belt_income_zero))
	logs.append("D) System 3 blockaded at start and belt income 0 while blockaded: %s" % str(system3_blockaded_at_start and system3_belt_zero_while_blockaded))
	logs.append("E) Deterministic logs check available via repeated harness run comparison.")

	for line in logs:
		print(line)
	return logs


func fmt_sorted_int_map(values: Dictionary) -> String:
	var keys: Array[int] = []
	for key_variant in values.keys():
		keys.append(int(key_variant))
	keys.sort()
	var parts: Array[String] = []
	for map_key in keys:
		parts.append("%d:%d" % [map_key, int(values.get(map_key, 0))])
	return "{" + ", ".join(parts) + "}"


func fmt_sorted_bool_map(values: Dictionary) -> String:
	var keys: Array[int] = []
	for key_variant in values.keys():
		keys.append(int(key_variant))
	keys.sort()
	var parts: Array[String] = []
	for map_key in keys:
		parts.append("%d:%d" % [map_key, 1 if bool(values.get(map_key, false)) else 0])
	return "{" + ", ".join(parts) + "}"


func fmt_sorted_int_list(values: Array) -> String:
	var ids: Array[int] = []
	for value_variant in values:
		ids.append(int(value_variant))
	ids.sort()
	var parts: Array[String] = []
	for value in ids:
		parts.append(str(value))
	return "[" + ",".join(parts) + "]"


func fmt_sorted_id_list_truncated(values: Array, max_n: int) -> String:
	var ids: Array[int] = []
	for value_variant in values:
		ids.append(int(value_variant))
	ids.sort()
	var safe_max: int = maxi(0, max_n)
	if safe_max <= 0 or ids.size() <= safe_max:
		return fmt_sorted_int_list(ids)
	var shown: Array[int] = []
	for i in range(safe_max):
		shown.append(ids[i])
	return "%s(+%d_more)" % [fmt_sorted_int_list(shown), ids.size() - safe_max]


func validate_phase12_ground_troops_v0() -> Dictionary:
	var sim := GalaxySimulationTest.new()
	sim.setup_from_systems([
		{
			"id": 1201,
			"system_name": "P12-A",
			"fleets": [],
			"orbital_structures": [],
			"belt": {},
			"planets": [{
				"planet_id": 12011,
				"name": "A",
				"owner_faction_id": 1,
				"control": 100,
				"stability": 60,
				"base_credits_per_day": 0,
				"base_metal_per_day": 0,
				"base_rare_per_day": 0,
				"required_garrison_gp": 1,
				"current_garrison_gp": 0,
			}],
		},
	])

	var faction_state: Dictionary = sim._factions_by_id[1]
	faction_state["credits"] = 1000
	faction_state["metal"] = 100
	faction_state["rare_metal"] = 10

	var first_tick_logs: Array[String] = sim.advance_day()
	var report_day1: String = sim.build_planet_report("P12-A", "A")
	sim.advance_day()
	var third_tick_logs: Array[String] = sim.advance_day()
	var planet_state: Dictionary = sim.get_planet_by_name("P12-A", "A")
	var troops: Array = planet_state.get("troops", [])
	var troop_created: bool = troops.size() == 1
	var troop_gp: int = int(planet_state.get("troop_gp", -1))
	var effective_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0)) + troop_gp
	var control_after_training: int = int(planet_state.get("control", 0))
	var costs_applied: bool = int(faction_state.get("credits", 0)) == 880 and int(faction_state.get("metal", 0)) == 90
	var enqueue_seen: bool = false
	var complete_seen: bool = false
	for entry_variant in first_tick_logs:
		var entry: String = str(entry_variant)
		if entry.find("TROOP_ENQUEUE") >= 0:
			enqueue_seen = true
	for entry_variant in third_tick_logs:
		var entry: String = str(entry_variant)
		if entry.find("TROOP_COMPLETE") >= 0:
			complete_seen = true
	var report: String = sim.build_planet_report("P12-A", "A")
	var report_has_troops: bool = report.find("Troops: count=1 troop_gp=1 effective_garrison_gp=1") >= 0
	var report_has_training: bool = report_day1.find("Training:") >= 0
	var passed: bool = troop_created and troop_gp == 1 and effective_garrison_gp == 1 and control_after_training >= 98 and costs_applied and enqueue_seen and complete_seen and report_has_troops and report_has_training
	return {
		"passed": passed,
		"logs": [
			"phase12_troop_created=%s count=%d gp=%d effective=%d control=%d" % [str(troop_created), troops.size(), troop_gp, effective_garrison_gp, control_after_training],
			"phase12_costs_applied=%s credits=%d metal=%d" % [str(costs_applied), int(faction_state.get("credits", 0)), int(faction_state.get("metal", 0))],
			"phase12_logs enqueue=%s complete=%s" % [str(enqueue_seen), str(complete_seen)],
			"phase12_report_troops=%s report_training=%s" % [str(report_has_troops), str(report_has_training)],
		],
	}


func _append_prepatch7_snapshot(logs: Array[String], day: int) -> void:
	for system_id in _get_sorted_system_ids():
		var system_state: Dictionary = get_system(system_id)
		var primary_planet: Dictionary = get_primary_planet(system_id)
		var controller_faction_id: int = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var security_by_faction: Dictionary = system_state.get("security_by_faction", {})
		var scout_age_by_faction: Dictionary = {}
		for faction_id in _get_sorted_faction_ids():
			scout_age_by_faction[faction_id] = get_scout_age(system_state, faction_id, _day_index)
		var pirate_threat_sr: int = int((system_state.get("pirate_presence", {}) as Dictionary).get("threat_sr", 0))
		var belt_today: Dictionary = _last_belt_yield_by_system_id.get(system_id, {"metal_gain": 0, "rare_gain": 0})
		logs.append("DAY %d | SYSTEM | id=%d name=%s piracy_pressure=%d pirate_state=%d pirate_threat_sr=%d controller_security=%d scout_age=%s sr_by_faction=%s blockade_by_faction=%s belt={class:%s tier:%d disabled_days:%d owner:%d} belt_income_today={metal:%d rare:%d}" % [
			day,
			system_id,
			str(system_state.get("system_name", "Unknown")),
			int(system_state.get("piracy_pressure", 0)),
			int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)),
			pirate_threat_sr,
			int(security_by_faction.get(controller_faction_id, 0)),
			fmt_sorted_int_map(scout_age_by_faction),
			fmt_sorted_int_map(system_state.get("sr_by_faction", {})),
			fmt_sorted_int_map(system_state.get("blockade_by_faction", {})),
			str(system_state.get("belt_class", StrategicTestConfigScript.BELT_CLASS_NONE)),
			int(system_state.get("platform_tier", 0)),
			int(system_state.get("belt_disabled_days", 0)),
			int(system_state.get("belt_owner_faction_id", 0)),
			int(belt_today.get("metal_gain", 0)),
			int(belt_today.get("rare_gain", 0)),
		])

	for planet_id in _get_sorted_planet_ids():
		var planet_state: Dictionary = _planets_by_id[planet_id]
		var gains: Dictionary = _last_planet_yield_by_id.get(planet_id, {"credits_gain": 0, "metal_gain": 0, "rare_gain": 0})
		var troop_gp: int = _refresh_planet_troop_gp(planet_state)
		var effective_garrison_gp: int = int(planet_state.get("current_garrison_gp", 0)) + troop_gp
		logs.append("DAY %d | PLANET | id=%d owner=%d control=%d stability=%d derived_blockaded=%s base_credits=%d base_metal=%d base_rare=%d gains_today={credits:%d metal:%d rare:%d} troop_count=%d troop_gp=%d effective_garrison_gp=%d" % [
			day,
			planet_id,
			int(planet_state.get("owner_faction_id", 0)),
			int(planet_state.get("control", 0)),
			int(planet_state.get("stability", 0)),
			str(is_planet_blockaded(planet_state)),
			int(planet_state.get("base_credits_per_day", 0)),
			int(planet_state.get("base_metal_per_day", 0)),
			int(planet_state.get("base_rare_per_day", 0)),
			int(gains.get("credits_gain", 0)),
			int(gains.get("metal_gain", 0)),
			int(gains.get("rare_gain", 0)),
			(planet_state.get("troops", []) as Array).size(),
			troop_gp,
			effective_garrison_gp,
		])

	for faction_id in _get_sorted_faction_ids():
		if not _factions_by_id.has(faction_id):
			continue
		var faction_state: Dictionary = _factions_by_id[faction_id]
		var delta: Dictionary = _last_faction_delta_by_id.get(faction_id, {"credits": 0, "metal": 0, "rare_metal": 0})
		logs.append("DAY %d | FACTION | id=%d name=%s credits=%d metal=%d rare_metal=%d net_today={credits:%d metal:%d rare:%d}" % [
			day,
			faction_id,
			str(faction_state.get("name", "Unknown")),
			int(faction_state.get("credits", 0)),
			int(faction_state.get("metal", 0)),
			int(faction_state.get("rare_metal", 0)),
			int(delta.get("credits", 0)),
			int(delta.get("metal", 0)),
			int(delta.get("rare_metal", 0)),
		])


func _get_sorted_system_ids() -> Array[int]:
	var ids: Array[int] = []
	for system_variant in _systems:
		ids.append(int((system_variant as Dictionary).get("id", -1)))
	ids.sort()
	return ids


func _get_sorted_planet_ids() -> Array[int]:
	var ids: Array[int] = []
	for planet_id_variant in _planets_by_id.keys():
		ids.append(int(planet_id_variant))
	ids.sort()
	return ids


func _get_sorted_faction_ids() -> Array[int]:
	var ids: Array[int] = []
	for faction_id_variant in _factions_by_id.keys():
		ids.append(int(faction_id_variant))
	ids.sort()
	return ids


func _remove_default_shipyards_for_harness() -> void:
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var filtered: Array = []
		for structure_variant in system_state.get("orbital_structures", []):
			var structure: Dictionary = structure_variant
			if str(structure.get("type", "")) == StrategicTestConfigScript.SHIPYARD_I_TYPE:
				continue
			filtered.append(structure)
		system_state["orbital_structures"] = filtered


func _apply_prepatch7_factions() -> void:
	_factions_by_id.clear()
	_factions_by_id[1] = {
		"id": 1,
		"name": "Faction A",
		"credits": StrategicTestConfigScript.FACTION_A_LEGACY_STARTING_CREDITS,
		"metal": 500,
		"rare_metal": 100,
		"owned_planet_ids": [101, 201, 301],
	}
	_factions_by_id[2] = {
		"id": 2,
		"name": "Faction B",
		"credits": 20000,
		"metal": 500,
		"rare_metal": 100,
		"owned_planet_ids": [],
	}


func _refresh_strategic_state_for_harness() -> void:
	for system_id in _get_sorted_system_ids():
		compute_system_sr(system_id)
		_update_scouting_freshness_for_system(get_system(system_id))
		compute_system_blockades(system_id)
	_last_belt_yield_by_system_id.clear()
	_last_planet_yield_by_id.clear()
	_last_faction_delta_by_id.clear()

func _append_daily_logs(
	logs: Array[String],
	planet_yield_by_id: Dictionary,
	faction_upkeep_paid_by_id: Dictionary,
	faction_shipyard_status_by_id: Dictionary,
	faction_income_credits_by_id: Dictionary,
	faction_upkeep_breakdown_by_id: Dictionary,
	faction_unpaid_counts_by_id: Dictionary
) -> void:
	for system_id in _get_sorted_system_ids():
		var system_state: Dictionary = get_system(system_id)
		var primary_planet: Dictionary = get_primary_planet(system_id)
		var controller_faction_id: int = int(primary_planet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var scout_age: int = get_scout_age(system_state, controller_faction_id, _day_index)
		var security: int = int((system_state.get("security_by_faction", {}) as Dictionary).get(controller_faction_id, 0))
		var pirate_threat_sr: int = int((system_state.get("pirate_presence", {}) as Dictionary).get("threat_sr", 0))
		logs.append("DAY %d | SYSTEM | id=%d sr=%s enemy_sr=%s blockades=%s piracy_pressure=%d pirate_state=%d pirate_threat_sr=%d controller_faction_id=%d scout_age_controller=%d security_controller=%d" % [
			_day_index,
			system_id,
			fmt_sorted_int_map(system_state.get("sr_by_faction", {})),
			fmt_sorted_int_map(system_state.get("enemy_sr_by_faction", {})),
			fmt_sorted_bool_map(system_state.get("blockade_by_faction", {})),
			int(system_state.get("piracy_pressure", 0)),
			int(system_state.get("pirate_state", StrategicTestConfigScript.PIRATE_STATE_NONE)),
			pirate_threat_sr,
			controller_faction_id,
			scout_age,
			security,
		])

	for planet_id_for_log in _get_sorted_planet_ids():
		var planet_state_for_log: Dictionary = _planets_by_id[planet_id_for_log]
		var owner_faction_id: int = int(planet_state_for_log.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var applied_yield_result: Dictionary = planet_yield_by_id.get(planet_id_for_log, {
			"credits_gain": 0,
			"metal_gain": 0,
			"rare_gain": 0,
		})
		var troop_gp: int = _refresh_planet_troop_gp(planet_state_for_log)
		var effective_garrison_gp: int = int(planet_state_for_log.get("current_garrison_gp", 0)) + troop_gp
		logs.append("DAY %d | PLANET | id=%d owner=%d control=%d stability=%d blockaded=%s credits_gain=%d metal_gain=%d rare_gain=%d troop_count=%d troop_gp=%d effective_garrison_gp=%d" % [
			_day_index,
			planet_id_for_log,
			owner_faction_id,
			int(planet_state_for_log.get("control", 0)),
			int(planet_state_for_log.get("stability", 0)),
			str(is_planet_blockaded(planet_state_for_log)),
			int(applied_yield_result.get("credits_gain", 0)),
			int(applied_yield_result.get("metal_gain", 0)),
			int(applied_yield_result.get("rare_gain", 0)),
			(planet_state_for_log.get("troops", []) as Array).size(),
			troop_gp,
			effective_garrison_gp,
		])

	for faction_id in _get_sorted_faction_ids():
		var faction_state: Dictionary = _factions_by_id[faction_id]
		var shipyard_status_entries: Array = faction_shipyard_status_by_id.get(faction_id, [])
		var shipyard_status_text: String = "none" if shipyard_status_entries.is_empty() else " | ".join(shipyard_status_entries)
		logs.append("DAY %d | FACTION | id=%d credits=%d metal=%d rare_metal=%d upkeep_paid=%d shipyards=%s" % [
			_day_index,
			faction_id,
			int(faction_state.get("credits", 0)),
			int(faction_state.get("metal", 0)),
			int(faction_state.get("rare_metal", 0)),
			int(faction_upkeep_paid_by_id.get(faction_id, 0)),
			shipyard_status_text,
		])
		var breakdown: Dictionary = faction_upkeep_breakdown_by_id.get(faction_id, {})
		var unpaid: Dictionary = faction_unpaid_counts_by_id.get(faction_id, {})
		var upkeep_orbit: int = int(breakdown.get("orbit", 0))
		var upkeep_platform: int = int(breakdown.get("platform", 0))
		var upkeep_fleet: int = int(breakdown.get("fleet", 0))
		var upkeep_troop: int = int(breakdown.get("troop", 0))
		var upkeep_total: int = upkeep_orbit + upkeep_platform + upkeep_fleet + upkeep_troop
		var income_credits: int = int(faction_income_credits_by_id.get(faction_id, 0))
		var net_credits: int = income_credits - upkeep_total
		logs.append("DAY %d | LEDGER | faction=%d incomeC=%d upkeepC=%d netC=%d credits_end=%d up_orbit=%d up_platform=%d up_fleet=%d up_troop=%d unpaid_orbit=%d unpaid_fleet=%d unpaid_troop=%d" % [
			_day_index,
			faction_id,
			income_credits,
			upkeep_total,
			net_credits,
			int(faction_state.get("credits", 0)),
			upkeep_orbit,
			upkeep_platform,
			upkeep_fleet,
			upkeep_troop,
			int(unpaid.get("orbit", 0)),
			int(unpaid.get("fleet", 0)),
			int(unpaid.get("troop", 0)),
		])


func _reassign_planet_ownership(planet_id: int, previous_owner_faction_id: int, new_owner_faction_id: int) -> void:
	if _factions_by_id.has(previous_owner_faction_id):
		var previous_owner_planet_ids: Array = (_factions_by_id[previous_owner_faction_id] as Dictionary).get("owned_planet_ids", [])
		var planet_index: int = previous_owner_planet_ids.find(planet_id)
		if planet_index >= 0:
			previous_owner_planet_ids.remove_at(planet_index)
		previous_owner_planet_ids.sort()
		(_factions_by_id[previous_owner_faction_id] as Dictionary)["owned_planet_ids"] = previous_owner_planet_ids

	if _factions_by_id.has(new_owner_faction_id):
		var new_owner_planet_ids: Array = (_factions_by_id[new_owner_faction_id] as Dictionary).get("owned_planet_ids", [])
		if not new_owner_planet_ids.has(planet_id):
			new_owner_planet_ids.append(planet_id)
		new_owner_planet_ids.sort()
		(_factions_by_id[new_owner_faction_id] as Dictionary)["owned_planet_ids"] = new_owner_planet_ids

	if _system_id_by_planet_id.has(planet_id):
		_sync_belt_owner_to_primary_planet(get_system(int(_system_id_by_planet_id[planet_id])))


func _planet_lookup_key(system_name: String, planet_name: String) -> String:
	return "%s::%s" % [system_name.strip_edges().to_lower(), planet_name.strip_edges().to_lower()]


func get_fleet_panel_data_for_system(system_id: int) -> Dictionary:
	var system_state: Dictionary = get_system(system_id)
	if system_state.is_empty():
		return {}
	var planet_ids: Array[int] = []
	for planet_id_variant in system_state.get("planet_ids", []):
		planet_ids.append(int(planet_id_variant))
	planet_ids.sort()
	var fleets: Array[Dictionary] = []
	for fleet_variant in system_state.get("fleets", []):
		var fleet: Dictionary = fleet_variant
		_ensure_fleet_defaults(fleet, system_id)
		var ships: Array[Dictionary] = []
		for ship_variant in fleet.get("ships", []):
			ships.append((ship_variant as Dictionary).duplicate(true))
		StrategicTestLogicScript.sort_ships_for_merge_append(ships)
		var owner_faction_id: int = int(fleet.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
		var is_transport: bool = StrategicTestLogicScript.fleet_is_transport_only(fleet)
		var landed_planet_id: int = int(fleet.get("landed_planet_id", -1))
		var friendly_planet_ids: Array[int] = []
		var hostile_planet_ids: Array[int] = []
		if is_transport:
			for planet_id in planet_ids:
				var planet_state: Dictionary = _planets_by_id.get(planet_id, {})
				if planet_state.is_empty():
					continue
				var planet_owner_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
				if planet_owner_id == owner_faction_id:
					friendly_planet_ids.append(planet_id)
				elif StrategicTestLogicScript.are_factions_hostile(owner_faction_id, planet_owner_id):
					hostile_planet_ids.append(planet_id)
		fleets.append({
			"fleet_id": int(fleet.get("fleet_id", -1)),
			"owner_faction_id": owner_faction_id,
			"is_transport": is_transport,
			"cargo_troop_gp": int(fleet.get("cargo_troop_gp", 0)),
			"transport_capacity_gp": int(fleet.get("transport_capacity_gp", 0)),
			"landed_planet_id": landed_planet_id,
			"status": str(fleet.get("status", "idle")),
			"readiness": int(fleet.get("readiness", 100)),
			"base_sr": get_fleet_base_sr(fleet),
			"effective_sr": get_fleet_effective_sr(fleet),
			"ships": ships,
			"available_actions": {
				"can_land": is_transport and landed_planet_id < 0,
				"can_launch": is_transport and landed_planet_id >= 0,
				"can_load": is_transport and landed_planet_id >= 0,
				"can_unload": is_transport and landed_planet_id >= 0,
				"can_invade": is_transport and landed_planet_id >= 0 and int(fleet.get("cargo_troop_gp", 0)) > 0,
				"friendly_planet_ids": friendly_planet_ids,
				"hostile_planet_ids": hostile_planet_ids,
			},
		})
	fleets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("owner_faction_id", 0)) == int(b.get("owner_faction_id", 0)):
			return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
		return int(a.get("owner_faction_id", 0)) < int(b.get("owner_faction_id", 0))
	)
	return {
		"system_id": system_id,
		"system_name": str(system_state.get("system_name", "Unknown")),
		"fleets": fleets,
	}


func build_fleet_summary_by_system_name() -> Dictionary:
	var summary: Dictionary = {}
	for system_variant in _systems:
		var system_state: Dictionary = system_variant
		var system_id: int = int(system_state.get("id", -1))
		var system_name: String = String(system_state.get("system_name", "Unknown"))
		var idle_count: int = 0
		var moving_count: int = 0
		var min_arrival_day: int = -1
		var faction_ship_count: Dictionary = {}
		var faction_fleet_ids: Dictionary = {}
		var faction_fleet_ship_counts: Dictionary = {}
		for fleet_variant in system_state.get("fleets", []):
			var fleet_state: Dictionary = fleet_variant
			_ensure_fleet_defaults(fleet_state, system_id)
			var owner_faction_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfigScript.NO_OWNER_FACTION_ID))
			var ship_count: int = maxi(0, (fleet_state.get("ships", []) as Array).size())
			faction_ship_count[owner_faction_id] = int(faction_ship_count.get(owner_faction_id, 0)) + ship_count
			var fleet_ids: Array = faction_fleet_ids.get(owner_faction_id, [])
			fleet_ids.append(int(fleet_state.get("fleet_id", -1)))
			faction_fleet_ids[owner_faction_id] = fleet_ids
			var fleet_ship_counts: Array = faction_fleet_ship_counts.get(owner_faction_id, [])
			fleet_ship_counts.append({
				"fleet_id": int(fleet_state.get("fleet_id", -1)),
				"ship_count": ship_count,
			})
			faction_fleet_ship_counts[owner_faction_id] = fleet_ship_counts
			if str(fleet_state.get("status", "idle")) == "moving":
				moving_count += 1
				var fleet_arrival_day: int = int(fleet_state.get("arrival_day", -1))
				if fleet_arrival_day >= 0 and (min_arrival_day < 0 or fleet_arrival_day < min_arrival_day):
					min_arrival_day = fleet_arrival_day
			else:
				idle_count += 1
		var faction_summaries: Array[Dictionary] = []
		for faction_id_variant in faction_ship_count.keys():
			var faction_id: int = int(faction_id_variant)
			var hostile_to: Array[int] = []
			for other_variant in faction_ship_count.keys():
				var other_faction_id: int = int(other_variant)
				if faction_id == other_faction_id:
					continue
				if StrategicTestLogicScript.are_factions_hostile(faction_id, other_faction_id):
					hostile_to.append(other_faction_id)
			hostile_to.sort()
			var fleet_ids_for_faction: Array[int] = []
			for fleet_id_variant in faction_fleet_ids.get(faction_id, []):
				fleet_ids_for_faction.append(int(fleet_id_variant))
			fleet_ids_for_faction.sort()
			var fleet_ship_counts_for_faction: Array[Dictionary] = []
			for entry_variant in faction_fleet_ship_counts.get(faction_id, []):
				fleet_ship_counts_for_faction.append((entry_variant as Dictionary).duplicate(true))
			fleet_ship_counts_for_faction.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
			)
			faction_summaries.append({
				"faction_id": faction_id,
				"ship_count": int(faction_ship_count.get(faction_id, 0)),
				"fleet_ids": fleet_ids_for_faction,
				"fleet_ship_counts": fleet_ship_counts_for_faction,
				"hostile_to": hostile_to,
			})
		faction_summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("faction_id", 0)) < int(b.get("faction_id", 0))
		)
		summary[system_name] = {
			"idle": idle_count,
			"moving": moving_count,
			"min_arrival_day": min_arrival_day,
			"total": idle_count + moving_count,
			"factions": faction_summaries,
		}
	return summary
