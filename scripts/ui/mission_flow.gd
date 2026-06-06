class_name MissionFlow
extends Node
## UI/session glue for ASCII-map mission entry (GDD s56.19).
##
## ⚠ UNVERIFIED SCAFFOLDING. Written without a Godot runtime — never executed or
## scene-tested. Treat as a starting point: review and run under Godot/GUT before
## relying on it.
##
## Drives mission entry for a player character:
##   • AUTO seeds launch automatically when the PC arrives in a province
##     (on_pc_arrived → first AUTO seed → CombatScreen.start_mission).
##   • PLAYER_INITIATED seeds launch when the PC fires ENGAGE_MISSION (engage()).
##
## This is the integration point a future PC world-map travel system calls: when
## a PC arrives in a province, the world/session layer builds that province's
## active seeds (QuestSeedSelector.select_province_seeds) and calls on_pc_arrived().
## That travel/arrival event source does not exist yet — MissionFlow only defines
## the hook it will call.
##
## One mission runs at a time (the owned CombatScreen). AUTO launches are skipped
## while a mission is already active.

signal mission_launched(seed: Dictionary)
signal mission_complete()
signal player_died()
signal mission_blocked(reason: String)

var _screen: CombatScreen = null
var _dice: DiceEngine = null


## Wire the flow to a CombatScreen and a dice engine. Relays the screen's
## terminal signals upward.
func setup(screen: CombatScreen, dice: DiceEngine) -> void:
	_screen = screen
	_dice = dice
	if _screen == null:
		return
	if not _screen.mission_complete.is_connected(_on_mission_complete):
		_screen.mission_complete.connect(_on_mission_complete)
	if not _screen.player_died.is_connected(_on_player_died):
		_screen.player_died.connect(_on_player_died)


## Called by the world/session layer when `pc` arrives in `province`.
## `active_seeds` is that province's seed list (QuestSeedSelector.select_province_seeds).
## Auto-launches the first AUTO seed if one is present and no mission is active.
## Returns the engageable PLAYER_INITIATED seeds for the UI to offer the player.
func on_pc_arrived(
		pc: L5RCharacterData,
		province: ProvinceData,
		province_history: Array,
		active_seeds: Array,
		seed_str: String,
) -> Array:
	var auto: Array = MissionEntryController.get_auto_launch_seeds(active_seeds)
	if not auto.is_empty():
		_launch(auto[0], province, province_history, pc, seed_str)
	return MissionEntryController.get_engageable_seeds(active_seeds)


## Player fires ENGAGE_MISSION (1 AP) against a located player-initiated seed.
## Spends the AP and launches the mission. Returns true on launch.
func engage(
		pc: L5RCharacterData,
		seed: Dictionary,
		province: ProvinceData,
		province_history: Array,
		seed_str: String,
) -> bool:
	var req: Dictionary = MissionEntryController.engage_mission(pc, seed)
	if not req.get("ok", false):
		mission_blocked.emit(req.get("reason", "cannot_engage"))
		return false
	return _launch(req["seed"], province, province_history, pc, seed_str)


## True when a mission is currently loaded in the screen.
func is_busy() -> bool:
	return _screen != null and _screen.get_controller() != null


func _launch(
		seed: Dictionary,
		province: ProvinceData,
		province_history: Array,
		pc: L5RCharacterData,
		seed_str: String,
) -> bool:
	if _screen == null:
		mission_blocked.emit("no_screen")
		return false
	if is_busy():
		mission_blocked.emit("already_in_mission")
		return false
	var session: MissionSession = MissionLauncher.build_session(
		seed, province, province_history, seed_str, pc)
	if session == null:
		mission_blocked.emit("mission_unavailable")
		return false
	if not _screen.start_mission(session, pc, _dice):
		mission_blocked.emit("start_failed")
		return false
	mission_launched.emit(seed)
	return true


func _on_mission_complete() -> void:
	mission_complete.emit()


func _on_player_died() -> void:
	player_died.emit()
