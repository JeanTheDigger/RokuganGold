class_name MissionEntryController
## Bridges the persistent world to ASCII-map mission launches for a PLAYER
## CHARACTER (GDD s56.19, owner-approved 2026-06-06). Pure simulation class —
## no Node inheritance.
##
## This is PC-only. NPCs never use the ASCII map (hard constraint) and PCs never
## run through the NPC decision engine (s60), so mission entry is not an NPC
## ActionID and does not touch the NPC pipeline (no context lists, no
## objective_alignment, no executor).
##
## Two entry paths, classified per seed by MissionEntryPolicy:
##   AUTO             — fires when the PC arrives in a province with an active
##                      AUTO seed (get_auto_launch_seeds). The consuming UI layer
##                      builds the session and calls CombatScreen.start_mission().
##   PLAYER_INITIATED — the PC fires ENGAGE_MISSION (1 AP from banked AP) to
##                      assault a located seed (engage_mission).
##
## Seed inputs are the seed dicts produced by QuestSeedSelector (each carries a
## "seed_type" int). This class filters/validates only; it does not build maps
## or call into the UI (simulation never calls into scenes).

## ENGAGE_MISSION action point cost (GDD s56.19, owner-locked).
const ENGAGE_MISSION_AP_COST: int = 1


## AUTO seeds in the PC's current province that should launch on arrival.
## Returns the subset of `province_seeds` whose seed_type is classified AUTO.
static func get_auto_launch_seeds(province_seeds: Array) -> Array:
	var out: Array = []
	for seed: Dictionary in province_seeds:
		if MissionEntryPolicy.is_auto(seed.get("seed_type", -1)):
			out.append(seed)
	return out


## PLAYER_INITIATED seeds in the PC's current province that the PC may assault.
static func get_engageable_seeds(province_seeds: Array) -> Array:
	var out: Array = []
	for seed: Dictionary in province_seeds:
		if MissionEntryPolicy.is_player_initiated(seed.get("seed_type", -1)):
			out.append(seed)
	return out


## True if `pc` is a player character with enough banked AP to ENGAGE_MISSION.
static func can_engage_mission(pc: L5RCharacterData) -> bool:
	if pc == null or not pc.is_pc:
		return false
	return PcSystem.can_spend_banked_ap(pc, ENGAGE_MISSION_AP_COST)


## PC fires ENGAGE_MISSION against a located PLAYER_INITIATED seed. Validates the
## actor is a PC, the seed is player-initiated, and the PC can pay; spends 1
## banked AP and returns a launch request the UI consumes to start the mission.
## Returns {ok: true, seed: <dict>} or {ok: false, reason: <String>}.
static func engage_mission(pc: L5RCharacterData, seed: Dictionary) -> Dictionary:
	if pc == null or not pc.is_pc:
		return {"ok": false, "reason": "not_a_pc"}
	if not MissionEntryPolicy.is_player_initiated(seed.get("seed_type", -1)):
		# AUTO seeds launch on arrival, not via ENGAGE_MISSION.
		return {"ok": false, "reason": "not_player_initiated"}
	var spend: Dictionary = PcSystem.spend_banked_ap(pc, ENGAGE_MISSION_AP_COST)
	if not spend.get("success", false):
		return {"ok": false, "reason": spend.get("reason", "insufficient_ap")}
	return {"ok": true, "seed": seed}
