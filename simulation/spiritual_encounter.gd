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
## see SpiritCombatant), and the remaining positional abilities (paralysis_venom,
## phantom_battle, possession). Hunger-pull, engulf, wail, and fire (Fire Trail +
## Everything Burns, via FireSystem s56.6.6) are wired.

const EXPOSURE_RADIUS_TILES: int = 5   # creatures within this range stack Willpower TN
const FIRST_INSTANCE_ID: int = -10001  # puppet ids count down from here (no real collision)

# Fire Trail (s54.10): the creature's own tile + 8 neighbours, each a 50% ignite.
const _FIRE_TRAIL_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


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
	var engulfed: Dictionary = {}                       # pc_id → captor creature_id (engulf/swarm grab)
	var weather: int = AsciiMapEnvironment.WeatherState.CLEAR  # drives FireSystem spread (s56.6.6)
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

	# 0. Passive positional abilities (s56.16 / s54.10) — fired at the start of the
	#    round. Hunger Pull (Fukuregaki): each character within 4 tiles is dragged
	#    1 tile toward the creature unless they pass an Earth roll vs TN 15.
	_apply_hunger_pull(es, dice)

	# 0b. Engulf crush (s54.10) — an engulfed PC takes the captor's crushing damage
	#     each round until they escape (attempt_engulf_escape) or the captor dies.
	_apply_engulf_crush(es, dice)

	# 0c. Fire damage (s56.6.6 / s54.10) — a PC standing on a burning tile, or set on
	#     fire by Everything Burns, takes 1k1 at the start of the round (armour does
	#     not reduce). Both can stack.
	_apply_fire_damage(es, dice)

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

	# 4. End-of-round fire tick (s56.6.6) — spread to flammable neighbours, then
	#    burn-duration decrement and Burned Out conversion (weather-gated).
	if es.mcs != null and es.mcs.map != null and not es.mcs.map.burning_tiles.is_empty():
		FireSystem.process_round_end(es.mcs.map, es.weather, dice)

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


## Drive one creature's turn. A wail-capable creature (Haraigaki) spends its Complex
## action on the Wail of the Starving (s54.10 / s56.16.6e): every PC within 5 tiles
## rolls Willpower vs TN 20, and failure costs a Willpower Rank via the exposure
## state. Any other creature delegates to the standard NPC AI turn (move + attack).
## The encounter caller routes enemy (creature) turns through this so the AoE/
## positional abilities fire. Returns the action descriptor.
static func creature_turn(es: EncounterState, cid: int, dice: DiceEngine) -> Dictionary:
	var c: L5RCharacterData = es.chars_by_id.get(cid, null)
	if c == null or c.spirit_creature == null or CharacterStats.is_dead(c):
		return {"actions": [], "reason": "not_creature"}
	# Immobile creatures (s54.10 Fukuregaki) do not take an active turn — their threat
	# is the passive Hunger Pull + Engulf crush (process_round). Keeps the engulfer put
	# so the generic AI can't wander it off and release its own grab.
	if c.spirit_creature.has_tag("immobile"):
		return {"actions": [], "reason": "immobile"}
	var ts = es.mcs.turn_states.get(cid, null)
	var wail: Dictionary = SpiritAbilitySystem.wail_effect(c.spirit_creature)
	if not wail.is_empty() and ts != null and ts.can_use_complex():
		ts.consume_complex()
		var cpos: Vector2i = es.mcs.positions.get(cid, Vector2i.ZERO)
		var radius: int = int(wail["radius_tiles"])
		var affected: Array = []
		for pid in es.pc_ids:
			var pc: L5RCharacterData = es.chars_by_id.get(pid, null)
			if pc == null or CharacterStats.is_dead(pc):
				continue
			var ppos: Vector2i = es.mcs.positions.get(pid, Vector2i(9999, 9999))
			if maxi(absi(ppos.x - cpos.x), absi(ppos.y - cpos.y)) > radius:
				continue
			var roll: int = dice.roll_and_keep(pc.willpower, pc.willpower, true).total
			if roll < int(wail["tn"]) and es.exposure.has(pid):
				SpiritualExposureSystem.apply_willpower_loss(es.exposure[pid], int(wail["wp_loss"]))
				affected.append(pid)
		return {"actions": [{"type": "wail", "by": cid, "affected": affected}], "ability": "wail"}
	var result: Dictionary = AsciiMapCombatOrchestrator.execute_npc_turn(es.mcs, cid, c, es.chars_by_id, dice)
	# Fire Trail + Burning Hunger (s54.10 Kagaki): each tile it passes / bites has a
	# 50% chance to ignite if flammable. The encounter does not track the exact path,
	# so ignite flammable tiles adjacent to its post-move position at 50% each.
	if c.spirit_creature.has_tag("fire_trail"):
		_apply_fire_trail(es, cid, dice)
	return result


## PC attempts to break an engulf/swarm grab (a PC action, s54.10). Fukuregaki
## (engulf): a Contested Strength roll vs the captor's Strength. Usai swarm: escape
## if the PC's Water Ring is 3+ OR they spend a Full Move (`full_move`). On success
## the grab is released. Returns {ok, captor, method}.
static func attempt_engulf_escape(es: EncounterState, pc_id: int, dice: DiceEngine, full_move: bool = false) -> Dictionary:
	if not es.engulfed.has(pc_id):
		return {"ok": false, "reason": "not_engulfed"}
	var captor: int = int(es.engulfed[pc_id])
	var pc: L5RCharacterData = es.chars_by_id.get(pc_id, null)
	var cre: L5RCharacterData = es.chars_by_id.get(captor, null)
	if pc == null or CharacterStats.is_dead(pc) or cre == null or CharacterStats.is_dead(cre):
		es.engulfed.erase(pc_id)
		return {"ok": true, "captor": captor, "method": "captor_gone"}
	if cre.spirit_creature.has_tag("swarm"):
		var water: int = CharacterStats.get_ring_value(pc, Enums.Ring.WATER)
		if water >= 3 or full_move:
			es.engulfed.erase(pc_id)
			return {"ok": true, "captor": captor, "method": ("water_ring" if water >= 3 else "full_move")}
		return {"ok": false, "captor": captor, "reason": "need_water3_or_full_move"}
	# Engulf (Fukuregaki): Contested Strength vs the captor's Strength trait.
	var cre_str: int = int(cre.spirit_creature.traits.get("strength", cre.spirit_creature.water))
	var pc_roll: int = dice.roll_and_keep(pc.strength, pc.strength, true).total
	var cre_roll: int = dice.roll_and_keep(cre_str, cre_str, true).total
	if pc_roll >= cre_roll:
		es.engulfed.erase(pc_id)
		return {"ok": true, "captor": captor, "method": "contested_strength"}
	return {"ok": false, "captor": captor, "reason": "lost_contest"}


## PC spends a Simple Action to extinguish the Everything Burns fire on themselves
## (s54.10). Clears the on_fire flag on their combat Participant and consumes the
## Simple Action. Returns {ok, reason}.
static func attempt_extinguish(es: EncounterState, pc_id: int) -> Dictionary:
	var p: IndividualCombat.Participant = es.mcs.combat.participants.get(pc_id, null)
	if p == null or not p.on_fire:
		return {"ok": false, "reason": "not_on_fire"}
	var ts = es.mcs.turn_states.get(pc_id, null)
	if ts == null or not ts.can_use_simple():
		return {"ok": false, "reason": "no_simple_action"}
	ts.consume_simple()
	p.on_fire = false
	return {"ok": true}


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

## Hunger Pull (s54.10 Fukuregaki): each living PC within a puller's radius is
## dragged 1 tile toward it unless they pass an Earth roll vs the resist TN. The
## drag is blocked by the creature's own tile, another occupant, a map edge, or an
## impassable tile (the engulf-on-adjacent grab is deferred — no creature grab state).
static func _apply_hunger_pull(es: EncounterState, dice: DiceEngine) -> void:
	for cid in es.chars_by_id:
		var c: L5RCharacterData = es.chars_by_id[cid]
		if c.spirit_creature == null or CharacterStats.is_dead(c):
			continue
		var hp: Dictionary = SpiritAbilitySystem.hunger_pull_effect(c.spirit_creature)
		if hp.is_empty():
			continue
		var cpos: Vector2i = es.mcs.positions.get(cid, Vector2i(9999, 9999))
		var radius: int = int(hp["radius_tiles"])
		var tn: int = int(hp["resist_tn"])
		var occupied: Dictionary = {}
		for v in es.mcs.positions.values():
			occupied[v] = true
		var engulfer: bool = c.spirit_creature.has_tag("engulf")
		for pid in es.pc_ids:
			var pc: L5RCharacterData = es.chars_by_id.get(pid, null)
			if pc == null or CharacterStats.is_dead(pc) or es.engulfed.has(pid):
				continue  # an engulfed PC is held — not pulled again
			var ppos: Vector2i = es.mcs.positions.get(pid, Vector2i(9999, 9999))
			var d: int = maxi(absi(ppos.x - cpos.x), absi(ppos.y - cpos.y))
			if d == 0 or d > radius:
				continue
			# Auto-grab (s54.10): a character already adjacent to an engulf creature is
			# seized; otherwise resist the pull, and a failed resist drags them 1 tile in.
			if d <= 1:
				if engulfer:
					es.engulfed[pid] = cid
				continue
			var earth: int = CharacterStats.get_earth_ring(pc)
			if dice.roll_and_keep(earth, earth, true).total >= tn:
				continue  # resisted the pull
			var dest := ppos + Vector2i(signi(cpos.x - ppos.x), signi(cpos.y - ppos.y))
			if dest == cpos or occupied.has(dest):
				continue
			if dest.x < 0 or dest.y < 0 or dest.x >= es.mcs.map.width or dest.y >= es.mcs.map.height:
				continue
			if not MovementSystem.is_passable(es.mcs.map.get_tile(dest.x, dest.y)):
				continue
			occupied.erase(ppos)
			occupied[dest] = true
			es.mcs.positions[pid] = dest
			# Dragged adjacent → seized automatically.
			if engulfer and maxi(absi(dest.x - cpos.x), absi(dest.y - cpos.y)) <= 1:
				es.engulfed[pid] = cid

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
## Engulf crush (s54.10): each engulfed PC takes the captor's crushing damage
## (creature damage XkY) per round. The grab releases if the captor dies, the PC
## dies, or the captor is no longer adjacent (e.g. a mobile swarm has moved off).
static func _apply_engulf_crush(es: EncounterState, dice: DiceEngine) -> void:
	for pid in es.engulfed.keys():
		var captor: int = int(es.engulfed[pid])
		var pc: L5RCharacterData = es.chars_by_id.get(pid, null)
		var cre: L5RCharacterData = es.chars_by_id.get(captor, null)
		if pc == null or CharacterStats.is_dead(pc) or cre == null or CharacterStats.is_dead(cre):
			es.engulfed.erase(pid)
			continue
		var ppos: Vector2i = es.mcs.positions.get(pid, Vector2i(9999, 9999))
		var cpos: Vector2i = es.mcs.positions.get(captor, Vector2i(-9999, -9999))
		if maxi(absi(ppos.x - cpos.x), absi(ppos.y - cpos.y)) > 1:
			es.engulfed.erase(pid)  # captor no longer adjacent
			continue
		var cr: SpiritCreatureData = cre.spirit_creature
		var dmg: int = dice.roll_and_keep(cr.damage_rolled, cr.damage_kept, true).total
		WoundSystem.apply_damage(pc, dmg)
		if CharacterStats.is_dead(pc):
			es.engulfed.erase(pid)


## Start-of-round fire damage (s56.6.6 / s54.10): a PC standing on a burning tile
## and/or set on fire (Everything Burns) each takes 1k1, armour does not reduce.
static func _apply_fire_damage(es: EncounterState, dice: DiceEngine) -> void:
	var map: AsciiMapData = es.mcs.map
	for pid in es.pc_ids:
		var pc: L5RCharacterData = es.chars_by_id.get(pid, null)
		if pc == null or CharacterStats.is_dead(pc):
			continue
		var ppos: Vector2i = es.mcs.positions.get(pid, Vector2i(-9999, -9999))
		if map != null and FireSystem.is_burning(map, ppos.x, ppos.y):
			WoundSystem.apply_damage(pc, FireSystem.standing_damage(dice), 0)
			if CharacterStats.is_dead(pc):
				continue
		var p: IndividualCombat.Participant = es.mcs.combat.participants.get(pid, null)
		if p != null and p.on_fire:
			WoundSystem.apply_damage(pc, FireSystem.standing_damage(dice), 0)


## Fire Trail + Burning Hunger (s54.10 Kagaki): each flammable tile on/adjacent to
## the creature's post-move position has a 50% chance to ignite this turn.
static func _apply_fire_trail(es: EncounterState, cid: int, dice: DiceEngine) -> void:
	var map: AsciiMapData = es.mcs.map
	if map == null:
		return
	var cpos: Vector2i = es.mcs.positions.get(cid, Vector2i(-9999, -9999))
	if cpos.x < -9000:
		return
	for off: Vector2i in _FIRE_TRAIL_TILES:
		var fx: int = cpos.x + off.x
		var fy: int = cpos.y + off.y
		if fx < 0 or fy < 0 or fx >= map.width or fy >= map.height:
			continue
		if not AsciiMapData.is_flammable(map.get_tile(fx, fy)):
			continue
		if dice.randf() < 0.5:  # s54.10 Fire Trail: 50% per flammable tile (LOCKED)
			FireSystem.ignite(map, fx, fy)


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
