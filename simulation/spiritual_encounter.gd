class_name SpiritualEncounter
## s56.16 live encounter driver — the per-round SPIRITUAL layer on top of
## AsciiMapCombatOrchestrator. PC-only. Owns: initial creature placement, the
## Restoration Ritual progress per round (s56.16.5b), periodic Exposure checks
## (s56.16.6a/7a/8a/9a, with creature stacking), and the Resolution outcome
## (s56.16.5f). The orchestrator owns movement / turn order / attack resolution
## (the player drives PC + bushi turns; creatures act via execute_npc_turn). The
## damage-filter / armor-bypass / life-drain abilities are wired into the
## orchestrator's _apply_hit; the rest of SpiritAbilitySystem feeds exposure here.
##
## Static-only validated (no Godot runtime here) — driver-verify the turn loop in a
## Godot-equipped session. DEFERRED: mid-combat threat escalation (adding creature
## participants to a live MapCombatState — the risky orchestrator-internal insertion),
## the exact creature to-HIT roll and WOUND-track overrides (PC approximation stands,
## see SpiritCombatant), and the positional abilities (hunger-pull, wail-as-action,
## fire-trail, possession) which the creature turn loop will fire.

const EXPOSURE_RADIUS_TILES: int = 5   # creatures within this range stack Willpower TN
const FIRST_INSTANCE_ID: int = -10001  # puppet ids count down from here (no real collision)


class EncounterState:
	var mcs: AsciiMapCombatOrchestrator.MapCombatState
	var realm: int = Enums.SpiritRealm.GAKI_DO
	var severity: int = Enums.SpiritualSeverity.MILD
	var event: SpiritualInsurgencyData               # banked progress + resolution target
	var pool: Dictionary = {}                          # zone → creature-id arrays
	var chars_by_id: Dictionary = {}                   # id → L5RCharacterData (PCs + puppets)
	var shugenja_ids: Array[int] = []
	var pc_ids: Array[int] = []                         # all player-faction real characters
	var exposure: Dictionary = {}                       # pc_id → SpiritualExposureSystem state
	var ritual_progress: int = 0                        # rounds achieved THIS mission
	var round_number: int = 0
	var next_instance_id: int = -10001  # = SpiritualEncounter.FIRST_INSTANCE_ID
	var heart_pos: Vector2i = Vector2i.ZERO
	var _waves_done: int = 0                            # escalation waves triggered
	var _zone_idx: Dictionary = {}                      # pool zone → next un-spawned index
	var _prev_wounds: Dictionary = {}                   # shugenja_id → wounds_taken last round
	var resolved: bool = false


## Sets up the encounter. party = the player-faction L5RCharacterData (bushi + shugenja);
## shugenja_ids = the subset who perform the ritual. event carries banked ritual
## progress + receives the outcome. pool/entry_pos/heart_pos come from the
## MissionBuilder spiritual package. Places PCs at the entry and the initial
## creatures at/near the heart.
static func start(
		map: AsciiMapData,
		party: Array,
		shugenja_ids: Array,
		realm: int,
		severity: int,
		event: SpiritualInsurgencyData,
		pool: Dictionary,
		entry_pos: Vector2i,
		heart_pos: Vector2i,
		dice: DiceEngine) -> EncounterState:
	var es := EncounterState.new()
	es.realm = realm
	es.severity = severity
	es.event = event
	es.pool = pool

	var combatants: Array = []
	# Player faction at the entry (spread along the row).
	var i: int = 0
	for c in party:
		if c == null or CharacterStats.is_dead(c):
			continue
		es.chars_by_id[c.character_id] = c
		es.pc_ids.append(c.character_id)
		var px: int = clampi(entry_pos.x + i, 0, map.width - 1)
		combatants.append({"char": c, "faction": AsciiMapCombatOrchestrator.FACTION_PLAYER, "x": px, "y": entry_pos.y,
			"stance": Enums.Stance.ATTACK})
		es.exposure[c.character_id] = SpiritualExposureSystem.new_state(realm, c.willpower)
		es._prev_wounds[c.character_id] = c.wounds_taken
		i += 1
	for sid in shugenja_ids:
		es.shugenja_ids.append(int(sid))
	es.heart_pos = heart_pos

	# Initial creatures: the weakest (outer / deception) tier, placed on the heart
	# ring. Escalation brings the deeper tiers as the ritual progresses (s56.16.5e).
	var init_zone: String = _initial_zone(es.pool)
	var init_ids: Array = es.pool.get(init_zone, [])
	var spawn_tiles: Array[Vector2i] = _ring_tiles(map, heart_pos)
	var t: int = 0
	for cid_str in init_ids:
		if t >= spawn_tiles.size():
			break
		var puppet: L5RCharacterData = SpiritCombatant.spawn(realm, String(cid_str), es.next_instance_id)
		if puppet == null:
			continue
		es.next_instance_id -= 1
		es.chars_by_id[puppet.character_id] = puppet
		combatants.append({"char": puppet, "faction": AsciiMapCombatOrchestrator.FACTION_ENEMY,
			"x": spawn_tiles[t].x, "y": spawn_tiles[t].y, "stance": Enums.Stance.ATTACK})
		t += 1
	es._zone_idx[init_zone] = t

	es.mcs = AsciiMapCombatOrchestrator.setup_combat(map, combatants, dice)
	return es


## Advances the spiritual layer one Round. Call once per combat round AFTER the
## orchestrator has resolved that round's turns. Returns
## {round, ritual_progress, ritual_needed, ritual_complete, shugenja_alive}.
static func process_round(es: EncounterState, dice: DiceEngine) -> Dictionary:
	es.round_number += 1
	var needed: int = SpiritualRitualSystem.rounds_remaining(es.event)

	# 1. Restoration ritual — each living shugenja contributes a round. A shugenja
	#    who took damage since last round has their round interrupted (s56.16.5b).
	for sid in es.shugenja_ids:
		var sh: L5RCharacterData = es.chars_by_id.get(sid, null)
		if sh == null or CharacterStats.is_dead(sh):
			continue
		var hit: bool = sh.wounds_taken > int(es._prev_wounds.get(sid, 0))
		es._prev_wounds[sid] = sh.wounds_taken
		if es.ritual_progress >= needed:
			continue
		var rr: Dictionary = SpiritualRitualSystem.resolve_ritual_round(sh, es.event, dice, hit)
		es.ritual_progress += int(rr.get("progress", 0))

	# 2. Escalation (s56.16.5e) — deeper threats appear as the ritual progresses.
	#    Waves trigger at the LOCKED depth-band cutoffs (SpiritualPalette.MIDDLE_BAND/
	#    HEART_BAND), reusing locked values rather than an invented schedule; one
	#    creature per wave, bounded by the pool.
	var waves: Array = _escalation_waves(es.pool)
	var frac: float = float(es.ritual_progress) / float(maxi(1, needed))
	while es._waves_done < waves.size() and frac >= float(waves[es._waves_done]["threshold"]):
		spawn_threat(es, String(waves[es._waves_done]["zone"]), dice)
		es._waves_done += 1

	# 3. Exposure — the passive periodic timer (creature-driven pressure fires from
	#    the creature turn loop). extra_tn = co-located creature stacking (swarm/rattle).
	var interval: int = int(SpiritualExposureSystem.CHECK_INTERVAL_ROUNDS.get(es.realm, 100))
	if interval > 0 and es.round_number % interval == 0:
		for pid in es.pc_ids:
			var pc: L5RCharacterData = es.chars_by_id.get(pid, null)
			if pc == null or CharacterStats.is_dead(pc):
				continue
			var extra: int = _co_located_willpower_tn(es, pid)
			SpiritualExposureSystem.roll_periodic_check(pc, es.exposure[pid], dice, extra)

	var alive: bool = _any_shugenja_alive(es)
	return {
		"round": es.round_number,
		"ritual_progress": es.ritual_progress,
		"ritual_needed": needed,
		"ritual_complete": es.ritual_progress >= needed,
		"shugenja_alive": alive,
	}


## Resolves the encounter outcome (s56.16.5f) and applies it to the event + map
## overlay. current_season feeds the retreat/failure intensity spike. Idempotent.
static func resolve(es: EncounterState, current_season: int = -1) -> Dictionary:
	if es.resolved:
		return {"outcome": es.event.resolution_type}
	es.resolved = true
	var alive: bool = _any_shugenja_alive(es)
	var map: AsciiMapData = es.mcs.map if es.mcs != null else null
	return SpiritualRitualSystem.apply_resolution(es.event, es.ritual_progress, alive, map, current_season)


## Spawns the next un-spawned creature from `zone` into the live encounter, on a
## free tile near the heart. Returns false if the zone is exhausted, the catalogue
## lacks the id, or no free tile is available. Called by the escalation waves.
static func spawn_threat(es: EncounterState, zone: String, dice: DiceEngine) -> bool:
	var ids: Array = es.pool.get(zone, [])
	var idx: int = int(es._zone_idx.get(zone, 0))
	if idx >= ids.size():
		return false
	es._zone_idx[zone] = idx + 1
	var puppet: L5RCharacterData = SpiritCombatant.spawn(es.realm, String(ids[idx]), es.next_instance_id)
	if puppet == null:
		return false
	var tile: Vector2i = _free_tile_near(es.mcs.map, es.heart_pos, es.mcs.positions)
	if tile.x < 0:
		return false
	es.next_instance_id -= 1
	es.chars_by_id[puppet.character_id] = puppet
	return AsciiMapCombatOrchestrator.add_enemy(es.mcs, puppet, tile.x, tile.y, dice)


# ── internal ──────────────────────────────────────────────────────────────────

## The weakest creature tier present (initial spawn).
static func _initial_zone(pool: Dictionary) -> String:
	if pool.has("outer") and not (pool["outer"] as Array).is_empty():
		return "outer"
	if pool.has("deceptions") and not (pool["deceptions"] as Array).is_empty():
		return "deceptions"
	for k in pool:
		if not (pool[k] as Array).is_empty():
			return String(k)
	return ""


## Escalation waves [{zone, threshold}] keyed to the LOCKED depth bands. Depth
## pools (outer/middle/heart) escalate at MIDDLE_BAND then HEART_BAND; Sakkaku
## (deceptions→real_threats) reveals the real threats at the midpoint.
static func _escalation_waves(pool: Dictionary) -> Array:
	if pool.has("outer"):
		var w: Array = []
		if pool.has("middle") and not (pool["middle"] as Array).is_empty():
			w.append({"zone": "middle", "threshold": SpiritualPalette.MIDDLE_BAND})
		if pool.has("heart") and not (pool["heart"] as Array).is_empty():
			w.append({"zone": "heart", "threshold": SpiritualPalette.HEART_BAND})
		return w
	if pool.has("real_threats") and not (pool["real_threats"] as Array).is_empty():
		return [{"zone": "real_threats", "threshold": 0.5}]
	return []


## Nearest free (passable, unoccupied) tile to `center`, searched in expanding
## rings. Returns Vector2i(-1, -1) if none within 6 tiles.
static func _free_tile_near(map: AsciiMapData, center: Vector2i, positions: Dictionary) -> Vector2i:
	var occupied: Dictionary = {}
	for v in positions.values():
		occupied[v] = true
	for r in range(0, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue  # only the current ring's perimeter
				var x: int = center.x + dx
				var y: int = center.y + dy
				if x < 0 or y < 0 or x >= map.width or y >= map.height:
					continue
				var tile := Vector2i(x, y)
				if occupied.has(tile):
					continue
				if MovementSystem.is_passable(map.get_tile(x, y)):
					return tile
	return Vector2i(-1, -1)


static func _any_shugenja_alive(es: EncounterState) -> bool:
	for sid in es.shugenja_ids:
		var sh: L5RCharacterData = es.chars_by_id.get(sid, null)
		if sh != null and not CharacterStats.is_dead(sh):
			return true
	return false


## Sum of Willpower-TN contributions (swarm presence / bone rattle) from spirit
## creatures within EXPOSURE_RADIUS_TILES of the PC (s56.16.6a stacking).
static func _co_located_willpower_tn(es: EncounterState, pc_id: int) -> int:
	var pc_pos: Vector2i = es.mcs.positions.get(pc_id, Vector2i.ZERO)
	var near: Array = []
	for cid in es.chars_by_id:
		var c: L5RCharacterData = es.chars_by_id[cid]
		if c.spirit_creature == null or CharacterStats.is_dead(c):
			continue
		var p: Vector2i = es.mcs.positions.get(cid, Vector2i(9999, 9999))
		if maxi(absi(p.x - pc_pos.x), absi(p.y - pc_pos.y)) <= EXPOSURE_RADIUS_TILES:
			near.append(c.spirit_creature)
	return SpiritAbilitySystem.total_willpower_tn(near)


## Heart tile + its 8 neighbours that are passable (initial creature spawn ring).
static func _ring_tiles(map: AsciiMapData, heart: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x: int = heart.x + dx
			var y: int = heart.y + dy
			if x < 0 or y < 0 or x >= map.width or y >= map.height:
				continue
			if MovementSystem.is_passable(map.get_tile(x, y)):
				out.append(Vector2i(x, y))
	return out
