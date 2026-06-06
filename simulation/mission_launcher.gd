class_name MissionLauncher
## Headless bridge from a mission launch request to a ready-to-run MissionSession
## (GDD s56.19). Pure simulation class — no Node inheritance.
##
## The entry flow is:
##   MissionEntryController  → a launch request (the chosen seed dict)
##   MissionLauncher         → builds the MissionSession for that seed + province
##   CombatScreen.start_mission(session, player, dice)   ← UI/session layer
##
## This class performs the headless half (build the session). The final
## start_mission() call lives in the UI/session layer because simulation never
## calls into scenes.

## Build a MissionSession for a launch-request seed in the given province.
## Returns null when the mission cannot be assembled (e.g. roster not ready, or
## the produced session is invalid). water_ring is the PC's Water Ring
## (min(Strength, Perception), s4.5); perception drives field-of-view radius.
static func build_session(
		seed_dict: Dictionary,
		province: ProvinceData,
		province_history: Array,
		seed_str: String,
		player: L5RCharacterData,
) -> MissionSession:
	if seed_dict.is_empty() or province == null or player == null:
		return null
	var result: Dictionary = MissionBuilder.assemble(
		province, province_history, seed_dict, seed_str)
	if result.is_empty():
		# roster_ready false (encounter design blocked) → no mission.
		return null
	var water_ring: int = mini(player.strength, player.perception)
	var session: MissionSession = MissionSession.from_builder(
		result, water_ring, player.perception)
	if not session.is_valid():
		return null
	return session
