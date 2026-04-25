extends RefCounted
class_name StrategicTestConfig

const REBELS_FACTION_ID: int = -1
const TEST_FACTION_ID: int = 1
const SITH_FACTION_ID: int = 2

const STARTING_CREDITS: int = 10000
const STARTING_METAL: int = 1000
const STARTING_RARE_METAL: int = 200
const REPUBLIC_PREPATCH7_STARTING_CREDITS: int = 40000

const PLANET_START_CONTROL: int = 100
const PLANET_START_STABILITY: int = 60
const PLANET_BASE_CREDITS_PER_DAY: int = 150
const PLANET_BASE_METAL_PER_DAY: int = 15
const PLANET_BASE_RARE_PER_DAY: int = 2
const PLANET_REQUIRED_GARRISON_GP: int = 5
const PLANET_GARRISON_RECRUIT_RATE_PER_DAY: int = 25
const GARRISON_GP_RECRUIT_COST_CREDITS: int = 100
const GARRISON_RECRUIT_BLOCKADE_COST_MULT_NUM: int = 3
const GARRISON_RECRUIT_BLOCKADE_COST_MULT_DEN: int = 2
const GARRISON_RECRUIT_MIN_CREDITS_BUFFER: int = 0
const GARRISON_RECRUIT_PROGRESS_CAP: int = 300

const TROOP_BLUEPRINTS: Dictionary = {
	"troops_basic": {
		"train_days": 3,
		"credits_cost": 120,
		"metal_cost": 10,
		"rare_cost": 0,
		"gp": 1,
		"upkeep_credits_per_day": 2,
	},
}
const TROOP_MAX_TRAIN_JOBS_PER_PLANET: int = 1
const TROOP_TRAINING_USES_PLANET_CACHE: bool = false

const SHIPYARD_I_TYPE: String = "shipyard_i"
const SHIPYARD_I_BUILD_COST_CREDITS: int = 3000
const SHIPYARD_I_BUILD_COST_METAL: int = 250
const SHIPYARD_I_BUILD_COST_RARE_METAL: int = 30
const SHIPYARD_I_BUILD_TIME_DAYS: int = 6
const SHIPYARD_I_UPKEEP_CREDITS_PER_DAY: int = 30
const SHIPYARD_I_BUILD_SLOTS: int = 1
const SHIPYARD_I_SHIP_POINTS_PER_DAY: int = 5
const SHIPYARD_I_BLOCKED_IF_BLOCKADED: bool = true
const SHIPYARD_I_STATION_SR: int = 0

const SHIP_BLUEPRINTS: Dictionary = {
	"corvette_mk1": {
		"sp_cost": 10,
		"credits_cost": 600,
		"metal_cost": 40,
		"rare_cost": 5,
		"sr": 10,
		"upkeep_credits_per_day": 4,
	},
	"frigate_mk1": {
		"sp_cost": 20,
		"credits_cost": 1100,
		"metal_cost": 75,
		"rare_cost": 10,
		"sr": 20,
		"upkeep_credits_per_day": 7,
	},
	"transport_mk1": {
		"sp_cost": 8,
		"credits_cost": 500,
		"metal_cost": 25,
		"rare_cost": 0,
		"sr": 2,
		"upkeep_credits_per_day": 3,
		"transport_capacity_gp": 10,
		"tags": {"role": "transport"},
	},
}

const DEFENSE_STATION_I_TYPE: String = "defense_station_i"
const DEFENSE_STATION_I_DISPLAY_NAME: String = "Defense Station I"
const DEFENSE_STATION_I_BUILD_COST_CREDITS: int = 2000
const DEFENSE_STATION_I_BUILD_COST_METAL: int = 150
const DEFENSE_STATION_I_BUILD_COST_RARE_METAL: int = 20
const DEFENSE_STATION_I_BUILD_TIME_DAYS: int = 4
const DEFENSE_STATION_I_UPKEEP_CREDITS_PER_DAY: int = 20
const DEFENSE_STATION_I_STATION_SR: int = 15
const DEFENSE_STATION_I_PIRACY_SUPPRESSION: int = 0

const LISTENING_POST_TYPE: String = "listening_post"
const LISTENING_POST_DISPLAY_NAME: String = "Listening Post"
const LISTENING_POST_BUILD_COST_CREDITS: int = 1600
const LISTENING_POST_BUILD_COST_METAL: int = 100
const LISTENING_POST_BUILD_COST_RARE_METAL: int = 20
const LISTENING_POST_BUILD_TIME_DAYS: int = 4
const LISTENING_POST_UPKEEP_CREDITS_PER_DAY: int = 20
const LISTENING_POST_STATION_SR: int = 5

const PATROL_HQ_TYPE: String = "patrol_hq"
const PATROL_HQ_DISPLAY_NAME: String = "Patrol HQ"
const PATROL_HQ_BUILD_COST_CREDITS: int = 2200
const PATROL_HQ_BUILD_COST_METAL: int = 160
const PATROL_HQ_BUILD_COST_RARE_METAL: int = 30
const PATROL_HQ_BUILD_TIME_DAYS: int = 5
const PATROL_HQ_UPKEEP_CREDITS_PER_DAY: int = 25
const PATROL_HQ_STATION_SR: int = 10

const PIRATE_STATE_NONE: int = 0
const PIRATE_STATE_ACTIVITY: int = 1
const PIRATE_STATE_HAVEN: int = 2

const BELT_CLASS_NONE: String = "none"
const BELT_CLASS_METAL: String = "metal"
const BELT_CLASS_RICH_METAL: String = "rich_metal"
const BELT_CLASS_RARE: String = "rare"
const BELT_CLASS_RICH_RARE: String = "rich_rare"

const PLATFORM_TIER_1_COST_CREDITS: int = 800
const PLATFORM_TIER_1_COST_METAL: int = 60
const PLATFORM_TIER_1_COST_RARE_METAL: int = 0
const PLATFORM_TIER_1_BUILD_DAYS: int = 2
const PLATFORM_TIER_1_UPKEEP_CREDITS_PER_DAY: int = 15

const PLATFORM_TIER_2_COST_CREDITS: int = 1200
const PLATFORM_TIER_2_COST_METAL: int = 120
const PLATFORM_TIER_2_COST_RARE_METAL: int = 10
const PLATFORM_TIER_2_BUILD_DAYS: int = 3
const PLATFORM_TIER_2_UPKEEP_CREDITS_PER_DAY: int = 25

const PLATFORM_TIER_3_COST_CREDITS: int = 2000
const PLATFORM_TIER_3_COST_METAL: int = 200
const PLATFORM_TIER_3_COST_RARE_METAL: int = 30
const PLATFORM_TIER_3_BUILD_DAYS: int = 4
const PLATFORM_TIER_3_UPKEEP_CREDITS_PER_DAY: int = 40

const CORVETTE_SR: int = 6
const FRIGATE_SR: int = 18
const PATROL_FULL_MIN_SR: int = 30
const PATROL_LIGHT_MIN_SR: int = 15
const PATROL_FULL_SECURITY_BONUS: int = 10
const PATROL_LIGHT_SECURITY_BONUS: int = 5
const PATROL_MAX_FLEETS_ASSIGNED: int = 2
const PATROL_ASSIGN_ONE_PER_SYSTEM: bool = true
const FLEET_ROLE_IDLE: String = "IDLE"
const FLEET_ROLE_PATROL: String = "PATROL"
const FLEET_MOVE_TRAVEL_DAYS_PER_HOP: int = 1
const FACTION_MAX_MOVEMENT_ORDERS_PER_DAY: int = 2
const FACTION_MAX_SHIP_ENQUEUES_PER_DAY: int = 1

const AI_INVASION_REQUIRED_MIN_GP: int = 5
const AI_INVASION_COOLDOWN_DAYS: int = 10
const AI_INVASION_ESCORT_MIN_EFF_SR: int = 10
const AI_TRACE_BUFFER_SIZE: int = 60
const DEBUG_AI_TRACE_LOGS: bool = false
const DEBUG_AI_INVASION_LOAD_DIAGNOSTICS: bool = false
const LOG_MAX_ID_LIST_TOKENS: int = 8


static func create_default_faction(faction_id: int, faction_name: String) -> Dictionary:
	return {
		"id": faction_id,
		"name": faction_name,
		"credits": STARTING_CREDITS,
		"metal": STARTING_METAL,
		"rare_metal": STARTING_RARE_METAL,
		"owned_planet_ids": [] as Array[int],
	}


static func strategic_planet_defaults() -> Dictionary:
	return {
		"owner_faction_id": TEST_FACTION_ID,
		"control": PLANET_START_CONTROL,
		"stability": PLANET_START_STABILITY,
		"base_credits_per_day": PLANET_BASE_CREDITS_PER_DAY,
		"base_metal_per_day": PLANET_BASE_METAL_PER_DAY,
		"base_rare_per_day": PLANET_BASE_RARE_PER_DAY,
		"required_garrison_gp": PLANET_REQUIRED_GARRISON_GP,
		"current_garrison_gp": PLANET_REQUIRED_GARRISON_GP,
		"garrison_recruit_progress": 0,
		"garrison_recruit_rate": PLANET_GARRISON_RECRUIT_RATE_PER_DAY,
		"garrison_recruit_paused_reason": "",
		"garrison_recruit_last_paid_day": -1,
		"troops": [],
		"troop_gp": 0,
		"troop_training_queue": [],
		"troop_training_progress": 0,
		"ground_engagement": {},
		"last_engagement_end_day": -1,
	}


static func create_engagement_state() -> Dictionary:
	return {
		"active": false,
		"start_day": -1,
		"resolve_day": -1,
		"factions": [],
		"side_a": REBELS_FACTION_ID,
		"side_b": REBELS_FACTION_ID,
		"snapshot": {},
		"last_update_day": -1,
	}


static func create_shipyard_i_instance(owner_faction_id: int, system_id: int) -> Dictionary:
	return {
		"type": SHIPYARD_I_TYPE,
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"sr": SHIPYARD_I_STATION_SR,
		"upkeep_credits_per_day": SHIPYARD_I_UPKEEP_CREDITS_PER_DAY,
		"build_slots": SHIPYARD_I_BUILD_SLOTS,
		"ship_points_per_day": SHIPYARD_I_SHIP_POINTS_PER_DAY,
		"blocked_if_blockaded": SHIPYARD_I_BLOCKED_IF_BLOCKADED,
		"queue": [],
		"current_progress_sp": 0,
		"enabled": true,
		"disabled_days": 0,
	}


static func create_defense_station_i_instance(owner_faction_id: int, system_id: int) -> Dictionary:
	return {
		"type": DEFENSE_STATION_I_TYPE,
		"display_name": DEFENSE_STATION_I_DISPLAY_NAME,
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"cost_credits": DEFENSE_STATION_I_BUILD_COST_CREDITS,
		"cost_metal": DEFENSE_STATION_I_BUILD_COST_METAL,
		"cost_rare_metal": DEFENSE_STATION_I_BUILD_COST_RARE_METAL,
		"build_time_days": DEFENSE_STATION_I_BUILD_TIME_DAYS,
		"upkeep_credits_per_day": DEFENSE_STATION_I_UPKEEP_CREDITS_PER_DAY,
		"sr": DEFENSE_STATION_I_STATION_SR,
		"piracy_suppression": DEFENSE_STATION_I_PIRACY_SUPPRESSION,
		"enabled": true,
		"disabled_days": 0,
	}


static func create_listening_post_instance(owner_faction_id: int, system_id: int) -> Dictionary:
	return {
		"type": LISTENING_POST_TYPE,
		"display_name": LISTENING_POST_DISPLAY_NAME,
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"cost_credits": LISTENING_POST_BUILD_COST_CREDITS,
		"cost_metal": LISTENING_POST_BUILD_COST_METAL,
		"cost_rare_metal": LISTENING_POST_BUILD_COST_RARE_METAL,
		"build_time_days": LISTENING_POST_BUILD_TIME_DAYS,
		"upkeep_credits_per_day": LISTENING_POST_UPKEEP_CREDITS_PER_DAY,
		"sr": LISTENING_POST_STATION_SR,
		"enabled": true,
		"disabled_days": 0,
	}


static func create_patrol_hq_instance(owner_faction_id: int, system_id: int) -> Dictionary:
	return {
		"type": PATROL_HQ_TYPE,
		"display_name": PATROL_HQ_DISPLAY_NAME,
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"cost_credits": PATROL_HQ_BUILD_COST_CREDITS,
		"cost_metal": PATROL_HQ_BUILD_COST_METAL,
		"cost_rare_metal": PATROL_HQ_BUILD_COST_RARE_METAL,
		"build_time_days": PATROL_HQ_BUILD_TIME_DAYS,
		"upkeep_credits_per_day": PATROL_HQ_UPKEEP_CREDITS_PER_DAY,
		"sr": PATROL_HQ_STATION_SR,
		"enabled": true,
		"disabled_days": 0,
	}


static func create_belt_node(belt_class: String, platform_tier: int, owner_faction_id: int) -> Dictionary:
	return {
		"has_belt": belt_class != BELT_CLASS_NONE,
		"belt_class": belt_class,
		"platform_tier": clampi(platform_tier, 0, 3),
		"belt_disabled_days": 0,
		"disabled_days": 0,
		"owner_faction_id": owner_faction_id,
	}


static func create_mining_platform_order(target_tier: int) -> Dictionary:
	var clamped_tier: int = clampi(target_tier, 1, 3)
	match clamped_tier:
		1:
			return {
				"order_type": "build_mining_platform",
				"target_tier": 1,
				"cost_credits": PLATFORM_TIER_1_COST_CREDITS,
				"cost_metal": PLATFORM_TIER_1_COST_METAL,
				"cost_rare_metal": PLATFORM_TIER_1_COST_RARE_METAL,
				"build_days": PLATFORM_TIER_1_BUILD_DAYS,
				"upkeep_credits_per_day": PLATFORM_TIER_1_UPKEEP_CREDITS_PER_DAY,
			}
		2:
			return {
				"order_type": "build_mining_platform",
				"target_tier": 2,
				"cost_credits": PLATFORM_TIER_2_COST_CREDITS,
				"cost_metal": PLATFORM_TIER_2_COST_METAL,
				"cost_rare_metal": PLATFORM_TIER_2_COST_RARE_METAL,
				"build_days": PLATFORM_TIER_2_BUILD_DAYS,
				"upkeep_credits_per_day": PLATFORM_TIER_2_UPKEEP_CREDITS_PER_DAY,
			}
		_:
			return {
				"order_type": "build_mining_platform",
				"target_tier": 3,
				"cost_credits": PLATFORM_TIER_3_COST_CREDITS,
				"cost_metal": PLATFORM_TIER_3_COST_METAL,
				"cost_rare_metal": PLATFORM_TIER_3_COST_RARE_METAL,
				"build_days": PLATFORM_TIER_3_BUILD_DAYS,
				"upkeep_credits_per_day": PLATFORM_TIER_3_UPKEEP_CREDITS_PER_DAY,
			}


static func create_fleet(owner_faction_id: int, sr: int, group_id: String = "main", system_id: int = -1) -> Dictionary:
	return {
		"owner_faction_id": owner_faction_id,
		"sr": sr,
		"group_id": group_id,
		"system_id": system_id,
		"status": "idle",
		"target_system_id": -1,
		"arrival_day": -1,
		"task": {},
		"last_order_day": -1,
		"role": FLEET_ROLE_IDLE,
		"patrol_system_id": -1,
		"ships": [{
			"blueprint_id": "legacy_ship",
			"sr": sr,
			"upkeep_credits_per_day": 0,
		}],
		"readiness": 100,
		"missed_upkeep_days": 0,
		"last_refit_day": -999999,
		"cargo_troop_gp": 0,
		"transport_capacity_gp": 0,
		"landed_planet_id": -1,
	}


static func create_ship_build_order(blueprint_id: String, owner_faction_id: int, system_id: int, started_day: int = -1) -> Dictionary:
	var blueprint: Dictionary = SHIP_BLUEPRINTS.get(blueprint_id, {})
	if blueprint.is_empty():
		return {}
	return {
		"type": "build_ship",
		"blueprint_id": blueprint_id,
		"sp_cost": int(blueprint.get("sp_cost", 0)),
		"owner_faction_id": owner_faction_id,
		"system_id": system_id,
		"costs": {
			"credits": int(blueprint.get("credits_cost", 0)),
			"metal": int(blueprint.get("metal_cost", 0)),
			"rare": int(blueprint.get("rare_cost", 0)),
		},
		"upkeep_credits_per_day": int(blueprint.get("upkeep_credits_per_day", 0)),
		"progress_sp": 0,
		"status": "active",
		"started_day": started_day,
	}
