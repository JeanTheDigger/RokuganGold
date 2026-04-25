extends RefCounted
class_name StrategicTestLogic

const StrategicTestConfig = preload("res://scripts/simulation/StrategicTestConfig.gd")

static func compute_planet_yield(planet_state: Dictionary, is_blockaded: bool, piracy_multiplier: float = 1.0) -> Dictionary:
	var control: int = int(planet_state.get("control", 0))
	var stability: int = int(planet_state.get("stability", 0))

	var control_mult: float = float(control) / 100.0
	var stability_mult: float = 0.5 + (float(stability) / 200.0)
	var blockade_mult: float = 0.40 if is_blockaded else 1.00

	var credits_gain: int = int(floor(float(int(planet_state.get("base_credits_per_day", 0))) * control_mult * stability_mult * blockade_mult * piracy_multiplier))
	var metal_gain: int = int(floor(float(int(planet_state.get("base_metal_per_day", 0))) * control_mult * blockade_mult * piracy_multiplier))
	var rare_gain: int = int(floor(float(int(planet_state.get("base_rare_per_day", 0))) * control_mult * blockade_mult * piracy_multiplier))

	return {
		"credits_gain": credits_gain,
		"metal_gain": metal_gain,
		"rare_gain": rare_gain,
	}


static func update_planet_control_and_stability(planet_state: Dictionary, is_blockaded: bool) -> Dictionary:
	var control: int = int(planet_state.get("control", 0))
	var stability: int = int(planet_state.get("stability", 0))
	var required_garrison_gp: int = int(planet_state.get("required_garrison_gp", 0))
	var current_garrison_gp: int = int(planet_state.get("current_garrison_gp", required_garrison_gp))
	var troop_gp: int = compute_planet_troop_gp(planet_state)
	planet_state["troop_gp"] = troop_gp
	var effective_garrison_gp: int = current_garrison_gp + troop_gp

	if effective_garrison_gp >= required_garrison_gp:
		control += 1
	else:
		control -= (required_garrison_gp - effective_garrison_gp)

	if control >= 80:
		stability += 1
	if control <= 30:
		stability -= 1

	if stability >= 70:
		control += 1
	if stability <= 40:
		control -= 1

	if is_blockaded:
		control -= 2
		stability -= 2

	if stability > 60:
		stability -= 1
	if stability < 60:
		stability += 1

	control = clampi(control, 0, 100)
	stability = clampi(stability, 0, 100)

	var revolt_occurred: bool = false
	var previous_owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID))
	var new_owner_faction_id: int = previous_owner_faction_id
	if control == 0:
		revolt_occurred = true
		new_owner_faction_id = previous_owner_faction_id
		control = 50
		stability = 40

	planet_state["control"] = control
	planet_state["stability"] = stability

	return {
		"revolt_occurred": revolt_occurred,
		"previous_owner_faction_id": previous_owner_faction_id,
		"new_owner_faction_id": new_owner_faction_id,
		"control": control,
		"stability": stability,
		"troop_gp": troop_gp,
		"effective_garrison_gp": effective_garrison_gp,
	}


static func compute_planet_troop_gp(planet_state: Dictionary) -> int:
	var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID))
	var troop_gp: int = 0
	for troop_variant in planet_state.get("troops", []):
		var troop: Dictionary = troop_variant
		if str(troop.get("status", "active")) != "active":
			continue
		if int(troop.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID)) != owner_faction_id:
			continue
		troop_gp += maxi(0, int(troop.get("gp", 0)))
	return troop_gp


static func pay_troop_upkeep(troop_state: Dictionary, faction_state: Dictionary) -> Dictionary:
	var upkeep_paid: int = 0
	var upkeep_credits_per_day: int = maxi(0, int(troop_state.get("upkeep_credits_per_day", 0)))
	if int(faction_state.get("credits", 0)) >= upkeep_credits_per_day:
		faction_state["credits"] = int(faction_state.get("credits", 0)) - upkeep_credits_per_day
		upkeep_paid = upkeep_credits_per_day
	return {
		"upkeep_paid": upkeep_paid,
		"is_paid": upkeep_paid >= upkeep_credits_per_day,
	}


static func apply_garrison_recruitment_for_planet(planet_state: Dictionary, faction_state: Dictionary, is_blockaded: bool, current_day: int) -> Dictionary:
	var owner_faction_id: int = int(planet_state.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID))
	if owner_faction_id < 0:
		return {
			"under_garrisoned": false,
			"gained_gp": false,
			"effective_rate": 0,
			"cost_next": 0,
			"paused": false,
			"paused_reason": "",
			"credits": int(faction_state.get("credits", 0)),
		}

	var required_garrison_gp: int = int(planet_state.get("required_garrison_gp", 0))
	var current_garrison_gp: int = int(planet_state.get("current_garrison_gp", required_garrison_gp))
	var recruit_progress: int = maxi(0, int(planet_state.get("garrison_recruit_progress", 0)))
	var recruit_rate: int = maxi(1, int(planet_state.get("garrison_recruit_rate", StrategicTestConfig.PLANET_GARRISON_RECRUIT_RATE_PER_DAY)))

	if current_garrison_gp >= required_garrison_gp:
		planet_state["current_garrison_gp"] = min(current_garrison_gp, required_garrison_gp)
		planet_state["garrison_recruit_progress"] = 0
		planet_state["garrison_recruit_paused_reason"] = ""
		return {
			"under_garrisoned": false,
			"gained_gp": false,
			"effective_rate": 0,
			"cost_next": 0,
			"paused": false,
			"paused_reason": "",
			"credits": int(faction_state.get("credits", 0)),
		}

	var effective_rate: int = recruit_rate
	if is_blockaded:
		effective_rate = maxi(1, recruit_rate / 2)
	var base_cost: int = StrategicTestConfig.GARRISON_GP_RECRUIT_COST_CREDITS
	var cost_next: int = base_cost
	if is_blockaded:
		cost_next = (base_cost * StrategicTestConfig.GARRISON_RECRUIT_BLOCKADE_COST_MULT_NUM) / StrategicTestConfig.GARRISON_RECRUIT_BLOCKADE_COST_MULT_DEN

	recruit_progress = mini(recruit_progress + effective_rate, StrategicTestConfig.GARRISON_RECRUIT_PROGRESS_CAP)
	var gained_gp: bool = false
	var paused: bool = false
	var paused_reason: String = ""
	while recruit_progress >= 100 and current_garrison_gp < required_garrison_gp:
		var faction_credits_before: int = int(faction_state.get("credits", 0))
		if faction_credits_before - cost_next < StrategicTestConfig.GARRISON_RECRUIT_MIN_CREDITS_BUFFER:
			paused = true
			paused_reason = "insufficient_credits"
			planet_state["garrison_recruit_paused_reason"] = paused_reason
			break

		faction_state["credits"] = faction_credits_before - cost_next
		current_garrison_gp += 1
		recruit_progress -= 100
		gained_gp = true
		planet_state["garrison_recruit_paused_reason"] = ""
		planet_state["garrison_recruit_last_paid_day"] = current_day

	current_garrison_gp = min(current_garrison_gp, required_garrison_gp)
	if paused:
		recruit_progress = mini(maxi(100, recruit_progress), StrategicTestConfig.GARRISON_RECRUIT_PROGRESS_CAP)
	else:
		recruit_progress = clampi(recruit_progress, 0, StrategicTestConfig.GARRISON_RECRUIT_PROGRESS_CAP)

	planet_state["current_garrison_gp"] = current_garrison_gp
	planet_state["garrison_recruit_progress"] = recruit_progress
	if not paused and not gained_gp:
		planet_state["garrison_recruit_paused_reason"] = ""

	return {
		"under_garrisoned": true,
		"gained_gp": gained_gp,
		"effective_rate": effective_rate,
		"cost_next": cost_next,
		"paused": paused,
		"paused_reason": paused_reason,
		"credits": int(faction_state.get("credits", 0)),
		"progress": recruit_progress,
		"current_garrison_gp": current_garrison_gp,
		"required_garrison_gp": required_garrison_gp,
		"deficit": maxi(0, required_garrison_gp - current_garrison_gp),
	}


static func pay_shipyard_upkeep(shipyard_state: Dictionary, faction_state: Dictionary) -> Dictionary:
	var upkeep_paid: int = 0
	var upkeep_credits_per_day: int = int(shipyard_state.get("upkeep_credits_per_day", 0))
	if int(faction_state.get("credits", 0)) >= upkeep_credits_per_day:
		faction_state["credits"] = int(faction_state.get("credits", 0)) - upkeep_credits_per_day
		upkeep_paid = upkeep_credits_per_day
		return {
			"upkeep_paid": upkeep_paid,
			"can_generate_sp": true,
		}

	return {
		"upkeep_paid": upkeep_paid,
		"can_generate_sp": false,
	}


static func pay_defense_station_upkeep(station_state: Dictionary, faction_state: Dictionary) -> Dictionary:
	var upkeep_paid: int = 0
	var upkeep_credits_per_day: int = int(station_state.get("upkeep_credits_per_day", 0))
	if int(faction_state.get("credits", 0)) >= upkeep_credits_per_day:
		faction_state["credits"] = int(faction_state.get("credits", 0)) - upkeep_credits_per_day
		upkeep_paid = upkeep_credits_per_day

	return {
		"upkeep_paid": upkeep_paid,
		"is_active": upkeep_paid >= upkeep_credits_per_day,
	}


static func is_movement_blocked_by_hostile_station(fleet_state: Dictionary, stations_in_system: Array) -> Dictionary:
	var fleet_owner_faction_id: int = int(fleet_state.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID))
	for station_variant in stations_in_system:
		var station: Dictionary = station_variant
		var station_owner_faction_id: int = int(station.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID))
		var station_sr: int = int(station.get("sr", 0))
		if are_factions_hostile(station_owner_faction_id, fleet_owner_faction_id) and station_sr >= StrategicTestConfig.DEFENSE_STATION_I_STATION_SR:
			return {
				"blocked": true,
				"reason": "blocked by hostile station",
			}

	return {
		"blocked": false,
		"reason": "",
	}


static func are_factions_hostile(faction_a: int, faction_b: int) -> bool:
	if faction_a == faction_b:
		return false
	if faction_a == StrategicTestConfig.REBELS_FACTION_ID or faction_b == StrategicTestConfig.REBELS_FACTION_ID:
		return true
	return faction_a != faction_b


static func advance_shipyard_queue(
	shipyard_state: Dictionary,
	faction_state: Dictionary,
	can_generate_sp: bool,
	is_blockaded: bool,
	current_day: int
) -> Dictionary:
	var generated_sp: int = 0
	var completion_blocked_for_resources: bool = false
	var completed_order: Dictionary = {}
	var should_log_stall: bool = false
	var did_complete: bool = false

	var queue: Array = shipyard_state.get("queue", [])
	if queue.is_empty():
		return {
			"generated_sp": generated_sp,
			"completed_order": completed_order,
			"completion_blocked_for_resources": completion_blocked_for_resources,
			"should_log_stall": should_log_stall,
		}

	var order: Dictionary = queue[0]
	var required_sp: int = int(order.get("sp_cost", 0))
	var current_progress_sp: int = int(order.get("progress_sp", int(shipyard_state.get("current_progress_sp", 0))))
	if current_progress_sp < required_sp:
		if can_generate_sp:
			var blocked_if_blockaded: bool = bool(shipyard_state.get("blocked_if_blockaded", true))
			if not (is_blockaded and blocked_if_blockaded):
				generated_sp = int(shipyard_state.get("ship_points_per_day", 0))
				current_progress_sp += generated_sp
				order["status"] = "active"

	if current_progress_sp >= required_sp:
		current_progress_sp = required_sp
		var costs: Dictionary = order.get("costs", {})
		var next_credits: int = int(faction_state.get("credits", 0)) - int(costs.get("credits", 0))
		var next_metal: int = int(faction_state.get("metal", 0)) - int(costs.get("metal", 0))
		var next_rare_metal: int = int(faction_state.get("rare_metal", 0)) - int(costs.get("rare", 0))
		if next_credits < 0 or next_metal < 0 or next_rare_metal < 0:
			completion_blocked_for_resources = true
			order["status"] = "stalled_insufficient_stockpile"
			var last_stall_log_day: int = int(order.get("last_stall_log_day", -1))
			if last_stall_log_day != current_day:
				order["last_stall_log_day"] = current_day
				should_log_stall = true
		else:
			faction_state["credits"] = next_credits
			faction_state["metal"] = next_metal
			faction_state["rare_metal"] = next_rare_metal
			completed_order = order.duplicate(true)
			queue.remove_at(0)
			current_progress_sp = 0
			did_complete = true

	if not did_complete:
		order["progress_sp"] = current_progress_sp
		if not queue.is_empty():
			queue[0] = order
	shipyard_state["current_progress_sp"] = current_progress_sp
	shipyard_state["queue"] = queue

	return {
		"generated_sp": generated_sp,
		"completed_order": completed_order,
		"completion_blocked_for_resources": completion_blocked_for_resources,
		"should_log_stall": should_log_stall,
	}


static func compute_belt_yield(belt_state: Dictionary, piracy_multiplier: float = 1.0) -> Dictionary:
	var belt_class: String = str(belt_state.get("belt_class", StrategicTestConfig.BELT_CLASS_NONE))
	var base_metal: int = 0
	var base_rare: int = 0
	match belt_class:
		StrategicTestConfig.BELT_CLASS_METAL:
			base_metal = 12
		StrategicTestConfig.BELT_CLASS_RICH_METAL:
			base_metal = 20
		StrategicTestConfig.BELT_CLASS_RARE:
			base_metal = 12
			base_rare = 4
		StrategicTestConfig.BELT_CLASS_RICH_RARE:
			base_metal = 16
			base_rare = 8

	var platform_tier: int = clampi(int(belt_state.get("platform_tier", 0)), 0, 3)
	var multiplier: float = 0.0
	match platform_tier:
		1:
			multiplier = 1.0
		2:
			multiplier = 1.5
		3:
			multiplier = 2.0

	return {
		"metal_gain": int(floor(float(base_metal) * multiplier * piracy_multiplier)),
		"rare_gain": int(floor(float(base_rare) * multiplier * piracy_multiplier)),
	}


static func get_platform_upkeep_for_tier(platform_tier: int) -> int:
	match clampi(platform_tier, 0, 3):
		1:
			return StrategicTestConfig.PLATFORM_TIER_1_UPKEEP_CREDITS_PER_DAY
		2:
			return StrategicTestConfig.PLATFORM_TIER_2_UPKEEP_CREDITS_PER_DAY
		3:
			return StrategicTestConfig.PLATFORM_TIER_3_UPKEEP_CREDITS_PER_DAY
		_:
			return 0


static func sort_fleets_by_sr_then_id_desc(fleets: Array[Dictionary]) -> void:
	fleets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_eff_sr: int = get_fleet_effective_sr(a)
		var b_eff_sr: int = get_fleet_effective_sr(b)
		if a_eff_sr == b_eff_sr:
			return int(a.get("fleet_id", 0)) < int(b.get("fleet_id", 0))
		return a_eff_sr > b_eff_sr
	)


static func make_ship_roster_entry(blueprint_id: String, sr: int, upkeep_credits_per_day: int) -> Dictionary:
	return {
		"blueprint_id": blueprint_id,
		"sr": maxi(0, sr),
		"upkeep_credits_per_day": maxi(0, upkeep_credits_per_day),
	}


static func sort_ships_for_merge_append(ships: Array[Dictionary]) -> void:
	ships.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_blueprint: String = str(a.get("blueprint_id", ""))
		var b_blueprint: String = str(b.get("blueprint_id", ""))
		if a_blueprint != b_blueprint:
			return a_blueprint < b_blueprint
		var a_sr: int = int(a.get("sr", 0))
		var b_sr: int = int(b.get("sr", 0))
		if a_sr != b_sr:
			return a_sr > b_sr
		return int(a.get("upkeep_credits_per_day", 0)) < int(b.get("upkeep_credits_per_day", 0))
	)


static func sort_ships_for_split_pick(ships: Array[Dictionary]) -> void:
	ships.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_sr: int = int(a.get("sr", 0))
		var b_sr: int = int(b.get("sr", 0))
		if a_sr != b_sr:
			return a_sr > b_sr
		var a_blueprint: String = str(a.get("blueprint_id", ""))
		var b_blueprint: String = str(b.get("blueprint_id", ""))
		if a_blueprint != b_blueprint:
			return a_blueprint < b_blueprint
		return int(a.get("upkeep_credits_per_day", 0)) < int(b.get("upkeep_credits_per_day", 0))
	)


static func get_fleet_base_sr(fleet_state: Dictionary) -> int:
	var total_sr: int = 0
	for ship_variant in fleet_state.get("ships", []):
		var ship_state: Dictionary = ship_variant
		total_sr += maxi(0, int(ship_state.get("sr", 0)))
	return total_sr


static func get_ship_role(ship_state: Dictionary) -> String:
	var blueprint_id: String = str(ship_state.get("blueprint_id", ""))
	var blueprint: Dictionary = StrategicTestConfig.SHIP_BLUEPRINTS.get(blueprint_id, {})
	var tags: Dictionary = blueprint.get("tags", {})
	return str(tags.get("role", "combat"))


static func get_ship_transport_capacity_gp(ship_state: Dictionary) -> int:
	var blueprint_id: String = str(ship_state.get("blueprint_id", ""))
	var blueprint: Dictionary = StrategicTestConfig.SHIP_BLUEPRINTS.get(blueprint_id, {})
	return maxi(0, int(blueprint.get("transport_capacity_gp", 0)))


static func fleet_is_transport_only(fleet_state: Dictionary) -> bool:
	var ships: Array = fleet_state.get("ships", [])
	if ships.is_empty():
		return false
	for ship_variant in ships:
		var ship_state: Dictionary = ship_variant
		if get_ship_role(ship_state) != "transport":
			return false
	return true


static func get_fleet_transport_capacity_gp(fleet_state: Dictionary) -> int:
	if not fleet_is_transport_only(fleet_state):
		return 0
	var capacity_gp: int = 0
	for ship_variant in fleet_state.get("ships", []):
		capacity_gp += get_ship_transport_capacity_gp(ship_variant)
	return capacity_gp


static func get_fleet_upkeep(fleet_state: Dictionary) -> int:
	var total_upkeep: int = 0
	for ship_variant in fleet_state.get("ships", []):
		var ship_state: Dictionary = ship_variant
		total_upkeep += maxi(0, int(ship_state.get("upkeep_credits_per_day", 0)))
	return total_upkeep


static func get_fleet_effective_sr(fleet_state: Dictionary) -> int:
	var base_sr: int = get_fleet_base_sr(fleet_state)
	var readiness: int = clampi(int(fleet_state.get("readiness", 100)), 0, 100)
	return int(floor(float(base_sr * readiness) / 100.0))


static func collect_patrol_candidates_for_faction(
	fleets: Array,
	faction_id: int,
	require_patrol_assignment: bool = false,
	required_system_id: int = -1
) -> Dictionary:
	var full_candidates: Array[Dictionary] = []
	var light_candidates: Array[Dictionary] = []
	for fleet_variant in fleets:
		var fleet_state: Dictionary = fleet_variant
		if int(fleet_state.get("owner_faction_id", StrategicTestConfig.REBELS_FACTION_ID)) != faction_id:
			continue
		if require_patrol_assignment:
			if str(fleet_state.get("role", StrategicTestConfig.FLEET_ROLE_IDLE)) != StrategicTestConfig.FLEET_ROLE_PATROL:
				continue
			if int(fleet_state.get("patrol_system_id", -1)) != required_system_id:
				continue
		var fleet_effective_sr: int = get_fleet_effective_sr(fleet_state)
		if fleet_effective_sr >= StrategicTestConfig.PATROL_FULL_MIN_SR:
			full_candidates.append(fleet_state)
		elif fleet_effective_sr >= StrategicTestConfig.PATROL_LIGHT_MIN_SR:
			light_candidates.append(fleet_state)

	sort_fleets_by_sr_then_id_desc(full_candidates)
	sort_fleets_by_sr_then_id_desc(light_candidates)

	return {
		"full_candidates": full_candidates,
		"light_candidates": light_candidates,
	}


static func select_patrol_fleets(full_candidates: Array[Dictionary], light_candidates: Array[Dictionary]) -> Array[Dictionary]:
	var selected_fleets: Array[Dictionary] = []
	selected_fleets.append_array(full_candidates)
	selected_fleets.append_array(light_candidates)
	var max_fleets_assigned: int = StrategicTestConfig.PATROL_MAX_FLEETS_ASSIGNED
	if max_fleets_assigned > 0 and selected_fleets.size() > max_fleets_assigned:
		selected_fleets = selected_fleets.slice(0, max_fleets_assigned)
	return selected_fleets


static func compute_patrol_security_from_fleets(selected_fleets: Array[Dictionary]) -> Dictionary:
	var full_count: int = 0
	var light_count: int = 0
	for fleet_variant in selected_fleets:
		var fleet_state: Dictionary = fleet_variant
		if get_fleet_effective_sr(fleet_state) >= StrategicTestConfig.PATROL_FULL_MIN_SR:
			full_count += 1
		else:
			light_count += 1

	return {
		"full_count": full_count,
		"light_count": light_count,
		"security_from_patrol": (full_count * StrategicTestConfig.PATROL_FULL_SECURITY_BONUS) + (light_count * StrategicTestConfig.PATROL_LIGHT_SECURITY_BONUS),
	}


static func sort_faction_ids_by_sr_desc_then_id(sr_by_faction: Dictionary, faction_ids: Array[int]) -> Array[int]:
	var ordered: Array[int] = faction_ids.duplicate(true)
	ordered.sort_custom(func(a: int, b: int) -> bool:
		var a_sr: int = int(sr_by_faction.get(a, 0))
		var b_sr: int = int(sr_by_faction.get(b, 0))
		if a_sr == b_sr:
			return a < b
		return a_sr > b_sr
	)
	return ordered
