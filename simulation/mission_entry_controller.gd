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


## Headless launch DECISION for a PC's pending arrival (persisted by the daily
## _process_pc_mission_arrivals pass). Pure simulation — decides WHAT the session
## layer should do, without instantiating any scene. Returns:
##   {has_mission: false}                              — nothing pending
##   {has_mission: true, province_id: int,
##    auto_launch: <seed dict or {}>,                  — first AUTO seed to launch on arrival
##    engageable: Array}                               — PLAYER_INITIATED seeds the PC may assault
## The UI layer instantiates the mission for `auto_launch` (if non-empty) and lists
## `engageable` for ENGAGE_MISSION. Call consume_pending_arrival() once handled.
static func resolve_arrival_launch(pc: L5RCharacterData) -> Dictionary:
	if pc == null or not pc.is_pc:
		return {"has_mission": false}
	var pending: Dictionary = pc.pending_arrival_mission
	if pending.is_empty():
		return {"has_mission": false}
	var auto_seeds: Array = pending.get("auto_seeds", [])
	var engageable: Array = pending.get("engageable_seeds", [])
	# AUTO seeds are already policy-classified by the producer; the first is the one
	# that launches on arrival (a province surfaces at most one AUTO seed in practice,
	# but guard for order determinism by taking the first).
	var auto_launch: Dictionary = auto_seeds[0] if not auto_seeds.is_empty() else {}
	return {
		"has_mission": true,
		"province_id": int(pending.get("province_id", -1)),
		"auto_launch": auto_launch,
		"engageable": engageable,
	}


## Clear the PC's pending arrival mission once the session/UI layer has consumed it
## (launched the AUTO mission / presented the engageable list). Idempotent.
static func consume_pending_arrival(pc: L5RCharacterData) -> void:
	if pc != null:
		pc.pending_arrival_mission = {}


## Classify a finished mission into a MissionOutcome (s56.13.1, LOCKED) from the
## combat facts the runtime observed. Pure simulation — no combat state of its own.
## Precedence follows the LOCKED enum semantics:
##   all enemies defeated                       -> FULL_SUCCESS
##   else player died (defenders held)          -> FAILURE
##   else spotted inside the objective space     -> RETREAT_INSIDE
##   else reached the objective space (and left) -> PARTIAL_SUCCESS
##   else (never reached it)                     -> RETREAT_OUTSIDE
## Returns an InsurgencyRelocationSystem.MissionOutcome int, ready for
## apply_mission_outcome().
static func classify_mission_outcome(
	all_enemies_defeated: bool,
	player_died: bool,
	reached_objective_space: bool,
	spotted_inside_objective: bool,
) -> int:
	if all_enemies_defeated:
		return InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS
	if player_died:
		return InsurgencyRelocationSystem.MissionOutcome.FAILURE
	if spotted_inside_objective:
		return InsurgencyRelocationSystem.MissionOutcome.RETREAT_INSIDE
	if reached_objective_space:
		return InsurgencyRelocationSystem.MissionOutcome.PARTIAL_SUCCESS
	return InsurgencyRelocationSystem.MissionOutcome.RETREAT_OUTSIDE


## Apply a completed PC mission's outcome back to the persistent world (s56.13
## Relocation, LOCKED). Pure simulation — the session/runtime supplies the combat
## result (outcome + kills + template used); this is the sim-side writeback that was
## built (InsurgencyRelocationSystem) but had no caller. Mutates the insurgency's
## strength + relocation bookkeeping via the LOCKED evaluate_relocation; a defeated
## insurgency (strength <= 0) is removed by the existing daily purge.
##
## same_province is fixed true because adjacent_relocation_chance is a PROVISIONAL
## 0.0 (s56.13.2, pending playtest) — no adjacent relocation occurs yet; when that
## value lands, the caller rolls it and passes the result. PC-side rewards
## (Glory/Honor for clearing a mission) are NOT applied here — that reward schedule
## is not specified in the GDD and is deferred to an owner decision.
##
## insurgency may be null (road-encounter / non-insurgency seeds) → no-op writeback.
## Returns {applied: bool, strength_after: int, defeated: bool,
##          relocation_triggered: bool, reason?: String}.
static func apply_mission_outcome(
	seed: Dictionary,
	insurgency: InsurgencyData,
	outcome: int,
	kills: int,
	template_used: String,
) -> Dictionary:
	if insurgency == null:
		return {"applied": false, "reason": "no_insurgency_backing",
			"strength_after": 0, "defeated": false, "relocation_triggered": false}
	insurgency.missions_conducted += 1
	var reloc: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		insurgency, outcome, kills, template_used, true, [],
	)
	insurgency.strength = int(reloc.get("strength_after", insurgency.strength))
	insurgency.template_type = template_used
	var delay: int = int(reloc.get("delay_seasons", 0))
	if delay > 0:
		insurgency.relocation_delay_remaining = delay
	if reloc.get("reset_province", false):
		insurgency.missions_conducted = 0
	return {
		"applied": true,
		"strength_after": insurgency.strength,
		"defeated": insurgency.strength <= 0,
		"relocation_triggered": bool(reloc.get("triggers", false)),
	}


## Capstone headless entry the session/runtime layer calls when a PC mission ends:
## resolve the seed's insurgency (via source_insurgency_id), classify the outcome from
## the reported combat facts, and apply the world writeback — one call, all sim-side.
## The caller supplies the world insurgency array (session state), the combat facts,
## the kill count, and the template used. Returns the apply_mission_outcome result dict
## augmented with the classified "outcome". Road-encounter seeds (source_insurgency_id
## -1) resolve to a null insurgency → world writeback is a no-op (PC rewards deferred).
static func resolve_and_apply_outcome(
	seed_dict: Dictionary,
	insurgencies: Array,
	all_enemies_defeated: bool,
	player_died: bool,
	reached_objective_space: bool,
	spotted_inside_objective: bool,
	kills: int,
	template_used: String,
) -> Dictionary:
	var insurgency: InsurgencyData = _find_insurgency(
		insurgencies, int(seed_dict.get("source_insurgency_id", -1)),
	)
	var outcome: int = classify_mission_outcome(
		all_enemies_defeated, player_died, reached_objective_space, spotted_inside_objective,
	)
	var applied: Dictionary = apply_mission_outcome(seed_dict, insurgency, outcome, kills, template_used)
	applied["outcome"] = outcome
	return applied


static func _find_insurgency(insurgencies: Array, insurgency_id: int) -> InsurgencyData:
	if insurgency_id < 0:
		return null
	for iv: Variant in insurgencies:
		if iv is InsurgencyData and (iv as InsurgencyData).insurgency_id == insurgency_id:
			return iv as InsurgencyData
	return null
