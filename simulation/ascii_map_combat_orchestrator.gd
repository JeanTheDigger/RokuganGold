class_name AsciiMapCombatOrchestrator
## ASCII-map combat orchestrator for GDD s40 skirmish mechanics.
## Ties IndividualCombat mechanics to the AsciiMapData tile grid.
## Pure simulation class — no Node inheritance.
##
## One tile = 5 feet (established by MovementSystem).
## Melee range = Chebyshev distance ≤ 1 (adjacent 8 directions).
## Ranged ranges: NOT SPECIFIED in GDD s40 (see Equipment section);
## any enemy in LOS is a valid target — marked PROVISIONAL.
## RANGED_IN_MELEE_PENALTY = -10 is GDD s40 confirmed.


# -- Combat constants (GDD s40) -----------------------------------------------

## Melee reach: adjacent 8 tiles (1 tile = 5 feet; "within 5 feet" = adjacent).
const MELEE_RANGE_TILES: int = 1

## Guard maneuver range: "within 5 feet" = 1 tile (GDD s40).
const GUARD_RANGE_TILES: int = 1

## Ranged attack while within melee range penalty (GDD s40 confirmed).
const RANGED_IN_MELEE_PENALTY: int = -10

## Faction identifiers.
const FACTION_PLAYER: String = "player"
const FACTION_ENEMY: String = "enemy"
const FACTION_NEUTRAL: String = "neutral"

## Stand-up from Prone costs a Simple action (GDD s40: "Simple action").
const STANDUP_ACTION_TYPE: String = "simple"

## Shoji walls can be cut through in one action (GDD s4.4).
const SHOJI_DESTROY_RAISES: int = 0


# =============================================================================
# -- TurnState — per-character action budget tracking -------------------------
# =============================================================================

class TurnState:
	var char_id: int = -1
	## A complex action was used (1 Complex + Free, OR 2 Simple + Free).
	var complex_used: bool = false
	## How many simple actions used (0-2; 2 simple = 1 complex equivalent).
	var simple_used: int = 0
	## Free move action used this turn.
	var free_move_used: bool = false
	## Number of free actions used (1-action items; no hard limit in GDD s40
	## beyond logical constraints per action type).
	var free_actions_used: int = 0
	## Stance was changed this turn (costs a Simple action per GDD s40).
	var stance_changed: bool = false

	func can_use_complex() -> bool:
		return not complex_used and simple_used == 0

	func can_use_simple() -> bool:
		## May use a simple action if no complex used and fewer than 2 simples used.
		return not complex_used and simple_used < 2

	func can_use_free_move() -> bool:
		return not free_move_used

	func consume_complex() -> void:
		complex_used = true

	func consume_simple() -> void:
		simple_used += 1
		if simple_used >= 2:
			complex_used = true  # 2 simples consume the complex slot

	func consume_free_move() -> void:
		free_move_used = true

	func consume_free() -> void:
		free_actions_used += 1

	## Crippled condition: move actions cost one tier higher (GDD s40).
	## Free→Simple, Simple→Complex, Complex already max.
	func effective_move_action(wound_level: int) -> String:
		if wound_level >= Enums.WoundLevel.CRIPPLED:
			return "crippled_upgrade"
		return "normal"

	## Down condition: only free actions allowed; must spend Void Point (GDD s40).
	func is_down_restricted(wound_level: int) -> bool:
		return wound_level >= Enums.WoundLevel.DOWN


# =============================================================================
# -- MapCombatState — full combat state including tile positions ---------------
# =============================================================================

class MapCombatState:
	## Core IndividualCombat state (participants, round, turn order).
	var combat: IndividualCombat.CombatState
	## The ASCII tile map for this encounter.
	var map: AsciiMapData
	## Character tile positions. Key: int (character_id), Value: Vector2i.
	var positions: Dictionary = {}
	## Character factions. Key: int (character_id), Value: String (FACTION_*).
	var factions: Dictionary = {}
	## Per-character turn budgets. Key: int (character_id), Value: TurnState.
	var turn_states: Dictionary = {}
	## Ordered combat log entries for the encounter.
	var combat_log: Array = []
	## Characters who have fled (removed from map, no longer in turn order).
	var fled_ids: Array = []


# =============================================================================
# -- Setup --------------------------------------------------------------------
# =============================================================================

## Create a new MapCombatState and roll initiative for all participants.
## combatants_data: Array of {char: L5RCharacterData, faction: String, x: int, y: int}
static func setup_combat(
	map: AsciiMapData,
	combatants_data: Array,
	dice_engine: DiceEngine,
) -> MapCombatState:
	var mcs := MapCombatState.new()
	mcs.map = map

	var chars_for_combat: Array = []
	var participant_dicts: Array = []
	for entry: Dictionary in combatants_data:
		var c: L5RCharacterData = entry["char"]
		if CharacterStats.is_dead(c):
			continue
		chars_for_combat.append(c)
		mcs.positions[c.character_id] = Vector2i(entry.get("x", 0), entry.get("y", 0))
		mcs.factions[c.character_id] = entry.get("faction", FACTION_NEUTRAL)
		participant_dicts.append({
			"character_id": c.character_id,
			"stance": entry.get("stance", Enums.Stance.ATTACK),
			"initiative_score": 0,
		})

	mcs.combat = IndividualCombat.build_combat_state(participant_dicts)

	# Roll initiative for each participant separately (L5R 4e: Reflexes + roll, per-round).
	for c: L5RCharacterData in chars_for_combat:
		var p: IndividualCombat.Participant = mcs.combat.participants.get(c.character_id, null)
		if p == null:
			continue
		var weapon_name: String = IndividualCombat.pick_best_weapon(c)
		var init_score: int = IndividualCombat.roll_initiative(c, p, dice_engine, weapon_name)
		p.initiative_score = init_score

	# Sort turn order descending by initiative score.
	mcs.combat.turn_order.sort_custom(func(a: int, b: int) -> bool:
		var pa: IndividualCombat.Participant = mcs.combat.participants.get(a, null)
		var pb: IndividualCombat.Participant = mcs.combat.participants.get(b, null)
		var ia: int = pa.initiative_score if pa != null else 0
		var ib: int = pb.initiative_score if pb != null else 0
		return ia > ib
	)

	for cid: int in mcs.combat.participants.keys():
		var ts := TurnState.new()
		ts.char_id = cid
		mcs.turn_states[cid] = ts

	mcs.combat_log.append({
		"type": "combat_started",
		"round": 1,
		"participants": chars_for_combat.map(func(c: L5RCharacterData) -> int: return c.character_id),
	})
	return mcs


# =============================================================================
# -- Movement Helpers ---------------------------------------------------------
# =============================================================================

## BFS flood-fill returning all tiles reachable within move_budget steps.
## Enemy tiles are treated as impassable (block movement through). Ally tiles
## are passable (you can move through an ally's tile).
## Returns Dictionary: Vector2i → cost (int).
static func get_reachable_tiles(
	state: MapCombatState,
	mover_id: int,
	move_budget: int,
) -> Dictionary:
	var start: Vector2i = state.positions.get(mover_id, Vector2i(-1, -1))
	if start.x < 0:
		return {}

	var mover_faction: String = state.factions.get(mover_id, FACTION_NEUTRAL)
	# Build set of enemy positions to block movement through.
	var enemy_tiles: Dictionary = {}
	for cid: int in state.positions.keys():
		if cid == mover_id:
			continue
		var f: String = state.factions.get(cid, FACTION_NEUTRAL)
		if _are_enemies(mover_faction, f):
			var ep: Vector2i = state.positions[cid]
			enemy_tiles[ep] = cid

	var reachable: Dictionary = {}
	reachable[start] = 0
	var queue: Array = [{"pos": start, "cost": 0}]
	var head: int = 0

	while head < queue.size():
		var entry: Dictionary = queue[head]
		head += 1
		var pos: Vector2i = entry["pos"]
		var cost: int = entry["cost"]

		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = pos.x + dx
				var ny: int = pos.y + dy
				var nv := Vector2i(nx, ny)

				# Out of bounds or enemy tile → skip
				if nx < 0 or nx >= state.map.width or ny < 0 or ny >= state.map.height:
					continue
				if enemy_tiles.has(nv):
					continue

				var tile: int = state.map.get_tile(nx, ny)
				var step_cost: int = MovementSystem.terrain_cost(tile)
				if step_cost == 0:
					continue  # impassable

				var new_cost: int = cost + step_cost
				if new_cost > move_budget:
					continue

				if not reachable.has(nv) or reachable[nv] > new_cost:
					reachable[nv] = new_cost
					queue.append({"pos": nv, "cost": new_cost})

	# Remove the starting tile (can't "move" to current position).
	reachable.erase(start)
	return reachable


## Find shortest path from start to goal using BFS with enemy-tile blocking.
## Returns Array of Vector2i waypoints (exclusive of start, inclusive of goal),
## or empty array if unreachable.
static func find_path(
	state: MapCombatState,
	mover_id: int,
	goal: Vector2i,
) -> Array:
	var start: Vector2i = state.positions.get(mover_id, Vector2i(-1, -1))
	if start.x < 0 or start == goal:
		return []

	var mover_faction: String = state.factions.get(mover_id, FACTION_NEUTRAL)
	var enemy_tiles: Dictionary = {}
	for cid: int in state.positions.keys():
		if cid == mover_id:
			continue
		var f: String = state.factions.get(cid, FACTION_NEUTRAL)
		if _are_enemies(mover_faction, f):
			var ep: Vector2i = state.positions[cid]
			enemy_tiles[ep] = true

	# BFS with predecessor tracking.
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = [start]
	visited[start] = true
	var found: bool = false

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		if pos == goal:
			found = true
			break
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nv := Vector2i(pos.x + dx, pos.y + dy)
				if visited.has(nv):
					continue
				if nv.x < 0 or nv.x >= state.map.width or nv.y < 0 or nv.y >= state.map.height:
					continue
				if enemy_tiles.has(nv) and nv != goal:
					continue
				var tile: int = state.map.get_tile(nv.x, nv.y)
				if MovementSystem.terrain_cost(tile) == 0:
					continue
				visited[nv] = true
				came_from[nv] = pos
				queue.append(nv)

	if not found:
		return []

	# Reconstruct path.
	var path: Array = []
	var cur: Vector2i = goal
	while cur != start:
		path.push_front(cur)
		cur = came_from[cur]
	return path


## Return melee-range enemy ids visible from mover_id's position.
static func get_melee_targets(state: MapCombatState, attacker_id: int) -> Array:
	var pos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	if pos.x < 0:
		return []
	var faction: String = state.factions.get(attacker_id, FACTION_NEUTRAL)
	var targets: Array = []
	for cid: int in state.positions.keys():
		if cid == attacker_id:
			continue
		var tf: String = state.factions.get(cid, FACTION_NEUTRAL)
		if not _are_enemies(faction, tf):
			continue
		var tp: Vector2i = state.positions[cid]
		if _chebyshev(pos, tp) <= MELEE_RANGE_TILES:
			targets.append(cid)
	return targets


## Return all enemy ids with clear line of sight from attacker.
## PROVISIONAL: ranged weapon ranges not yet specified (Equipment section blocked).
static func get_ranged_targets(state: MapCombatState, attacker_id: int) -> Array:
	var pos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	if pos.x < 0:
		return []
	var faction: String = state.factions.get(attacker_id, FACTION_NEUTRAL)
	var targets: Array = []
	for cid: int in state.positions.keys():
		if cid == attacker_id:
			continue
		var tf: String = state.factions.get(cid, FACTION_NEUTRAL)
		if not _are_enemies(faction, tf):
			continue
		var tp: Vector2i = state.positions[cid]
		if _chebyshev(pos, tp) > MELEE_RANGE_TILES and _has_los(state.map, pos, tp):
			targets.append(cid)
	return targets


## Returns true if attacker is in melee range of any enemy (for ranged penalty).
static func is_in_melee_range_of_enemy(state: MapCombatState, char_id: int) -> bool:
	return get_melee_targets(state, char_id).size() > 0


# =============================================================================
# -- Execute Actions ----------------------------------------------------------
# =============================================================================

## Change stance. Costs a Simple action (GDD s40).
## Returns result Dictionary.
static func execute_stance_change(
	state: MapCombatState,
	char_id: int,
	new_stance: int,
	character: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_simple():
		return {"success": false, "reason": "no_actions_remaining"}

	p.stance = new_stance as Enums.Stance

	# Full Defense stance: roll Defense now for full_defense_bonus (GDD s40).
	# Called after stance is assigned so any stance-gated logic inside is correct.
	if new_stance == Enums.Stance.FULL_DEFENSE:
		IndividualCombat.roll_full_defense_bonus(character, p, dice_engine)
	ts.consume_simple()
	ts.stance_changed = true

	state.combat_log.append({
		"type": "stance_change",
		"round": state.combat.round_number,
		"char_id": char_id,
		"new_stance": new_stance,
	})
	return {"success": true, "new_stance": new_stance}


## Move within move_budget tiles (already computed by caller for action type).
## Returns result Dictionary including actual tiles moved.
static func execute_move(
	state: MapCombatState,
	char_id: int,
	dest: Vector2i,
	move_budget: int,
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	action_type: String = "free",  # "free", "simple", "complex"
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	# Crippled: move actions upgrade one tier.
	var effective_type: String = action_type
	if wl >= Enums.WoundLevel.CRIPPLED:
		match action_type:
			"free":    effective_type = "simple"
			"simple":  effective_type = "complex"
			"complex": return {"success": false, "reason": "crippled_cannot_complex_move"}

	match effective_type:
		"free":
			if not ts.can_use_free_move():
				return {"success": false, "reason": "free_move_already_used"}
		"simple":
			if not ts.can_use_simple():
				return {"success": false, "reason": "no_simple_actions_remaining"}
		"complex":
			if not ts.can_use_complex():
				return {"success": false, "reason": "no_complex_actions_remaining"}

	# Full Attack stance: can only move toward enemies (GDD s40).
	if p.stance == Enums.Stance.FULL_ATTACK:
		var cur: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
		if not _dest_is_toward_enemy(state, char_id, cur, dest):
			return {"success": false, "reason": "full_attack_must_move_toward_enemy"}

	# Validate that dest is actually reachable within budget.
	var reachable: Dictionary = get_reachable_tiles(state, char_id, move_budget)
	if not reachable.has(dest):
		return {"success": false, "reason": "destination_unreachable"}

	# Blinded simple-move check (GDD s40).
	var fell_prone: bool = false
	if IndividualCombat.has_condition(p, IndividualCombat.CONDITION_BLINDED) and effective_type in ["simple", "complex"]:
		var blind_r: Dictionary = IndividualCombat.resolve_blinded_simple_move(character, p, dice_engine)
		if blind_r.get("fell_prone", false):
			fell_prone = true

	var old_pos: Vector2i = state.positions.get(char_id, Vector2i(0, 0))
	state.positions[char_id] = dest

	match effective_type:
		"free":    ts.consume_free_move()
		"simple":  ts.consume_simple()
		"complex": ts.consume_complex()

	state.combat_log.append({
		"type": "move",
		"round": state.combat.round_number,
		"char_id": char_id,
		"from": old_pos,
		"to": dest,
		"action_type": effective_type,
		"fell_prone": fell_prone,
	})
	return {"success": true, "from": old_pos, "to": dest, "fell_prone": fell_prone}


## Melee attack on target_id. Costs a Complex action.
## maneuver: "" / "increased_damage" / "disarm" / "feint" /
##           "knockdown_biped" / "knockdown_quad" /
##           "called_shot_limb" / "called_shot_hand" / "called_shot_head" /
##           "called_shot_small" / "extra_attack" / "guard"
static func execute_melee_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	raises: int,
	dice_engine: DiceEngine,
	maneuver: String = "",
	spend_void: bool = false,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		# Down: only free actions + must spend Void (GDD s40).
		return _execute_down_attack(state, attacker_id, target_id, attacker, target, weapon_name, dice_engine)

	# Special maneuver: Guard (free action — does not consume complex budget).
	if maneuver == "guard":
		return execute_guard(state, attacker_id, target_id, attacker, target)

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	# Range check.
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, is_being_guarded, weapon_name)

	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, raises, dice_engine,
		false, spend_void, false, maneuver,
		{"opponent_clan": target.clan}
	)

	var log_entry: Dictionary = {
		"type": "melee_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon": weapon_name,
		"maneuver": maneuver,
		"raises": raises,
		"hit": result.get("hit", false),
		"roll": result.get("roll", 0),
		"target_tn": armor_tn,
	}

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, raises, maneuver, result, dice_engine)
		log_entry["damage"] = dmg_result.get("damage", 0)
		log_entry["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)
		result["target_wound_level"] = CharacterStats.get_wound_level(target)

		# Knockdown maneuver: contested Strength if hit.
		if maneuver in ["knockdown_biped", "knockdown_quad"]:
			var kd: Dictionary = IndividualCombat.resolve_knockdown(
				attacker, target, maneuver == "knockdown_quad", dice_engine
			)
			if kd["knocked_down"]:
				IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_PRONE)
			result["knocked_down"] = kd["knocked_down"]
			log_entry["knocked_down"] = kd["knocked_down"]

		# Disarm maneuver: contested Strength if hit.
		if maneuver == "disarm":
			var dr: Dictionary = IndividualCombat.resolve_disarm(attacker, target, dice_engine, weapon_name)
			result["disarmed"] = dr["disarmed"]
			log_entry["disarmed"] = dr["disarmed"]

	ts.consume_complex()
	state.combat_log.append(log_entry)
	_check_and_mark_over(state, target_id, target)
	return result


## Ranged attack on target_id. Costs a Complex action.
static func execute_ranged_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	raises: int,
	dice_engine: DiceEngine,
	spend_void: bool = false,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	# LOS check.
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if not _has_los(state.map, apos, tpos):
		return {"success": false, "reason": "no_line_of_sight"}

	# Weapon must be ranged.
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	if wp.get("melee", true):
		return {"success": false, "reason": "weapon_is_melee"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	# -10 penalty if attacker is within melee range of any enemy (GDD s40).
	var in_melee: bool = is_in_melee_range_of_enemy(state, attacker_id)

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, false, is_being_guarded, weapon_name)

	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, raises, dice_engine,
		in_melee, spend_void, false, "",
		{"opponent_clan": target.clan}
	)

	var log_entry: Dictionary = {
		"type": "ranged_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon": weapon_name,
		"raises": raises,
		"hit": result.get("hit", false),
		"roll": result.get("roll", 0),
		"target_tn": armor_tn,
		"in_melee_penalty": in_melee,
	}

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, raises, "", result, dice_engine)
		log_entry["damage"] = dmg_result.get("damage", 0)
		log_entry["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)
		result["target_wound_level"] = CharacterStats.get_wound_level(target)

	ts.consume_complex()
	state.combat_log.append(log_entry)
	_check_and_mark_over(state, target_id, target)
	return result


## Extra Attack: spend 5 Raises (or 3 with Spinning Blades) on first attack,
## immediately make a second attack at 0 Raises (GDD s40). Free action.
static func execute_extra_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, is_being_guarded, weapon_name)

	var result: Dictionary = IndividualCombat.resolve_extra_attack(
		attacker, a_p, weapon_name, armor_tn, dice_engine, {"opponent_clan": target.clan}
	)

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, 0, "", result, dice_engine)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)

	# Mark success so callers can distinguish from a precondition-failure early return.
	if not result.has("reason"):
		result["success"] = true
	state.combat_log.append({
		"type": "extra_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"hit": result.get("hit", false),
	})
	_check_and_mark_over(state, target_id, target)
	return result


## Guard maneuver: designate an ally to guard. Free action (GDD s40: guard costs 0 Raises).
static func execute_guard(
	state: MapCombatState,
	guardian_id: int,
	target_id: int,
	guardian: L5RCharacterData,
	target: L5RCharacterData,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(guardian_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var g_p: IndividualCombat.Participant = state.combat.participants.get(guardian_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if g_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	if g_p.stance == Enums.Stance.FULL_ATTACK:
		return {"success": false, "reason": "full_attack_cannot_guard"}

	# Must be within 5 feet (1 tile) (GDD s40).
	var gpos: Vector2i = state.positions.get(guardian_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if _chebyshev(gpos, tpos) > GUARD_RANGE_TILES:
		return {"success": false, "reason": "target_too_far"}

	IndividualCombat.resolve_guard(g_p, target_id, guardian, t_p)
	ts.consume_free()

	state.combat_log.append({
		"type": "guard",
		"round": state.combat.round_number,
		"guardian_id": guardian_id,
		"target_id": target_id,
	})
	return {"success": true}


## Grapple initiation: Jiujutsu/Agility vs target Armor TN (GDD s40).
## Costs a Complex action.
static func execute_grapple_initiate(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	# Grapple ignores armor TN bonus — target TN = Reflexes × 5 + 5 (GDD s40).
	var grapple_tn: int = target.reflexes * 5 + 5

	var result: Dictionary = IndividualCombat.initiate_grapple(attacker, a_p, grapple_tn, dice_engine)

	if result.get("apply_grappled_to_target", false):
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_GRAPPLED)
		t_p.grapple_partner_id = attacker_id
		a_p.grapple_partner_id = target_id
		# Immediately resolve control (attacker has it on initiation per GDD s40).
		a_p.grapple_in_control = true
		t_p.grapple_in_control = false

	ts.consume_complex()
	state.combat_log.append({
		"type": "grapple_initiate",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"success": result.get("success", false),
	})
	return result


## Grapple action (hit, throw, take_control). Costs a Complex action.
## action_type: "hit" / "throw" / "take_control"
static func execute_grapple_action(
	state: MapCombatState,
	char_id: int,
	action_type: String,
	character: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	var c_p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if c_p == null:
		return {"success": false, "reason": "participant_missing"}

	if IndividualCombat.CONDITION_GRAPPLED not in c_p.conditions:
		return {"success": false, "reason": "not_in_grapple"}

	var partner_id: int = c_p.grapple_partner_id
	var t_p: IndividualCombat.Participant = state.combat.participants.get(partner_id, null)
	if t_p == null:
		return {"success": false, "reason": "grapple_partner_missing"}

	var result: Dictionary = {}

	match action_type:
		"hit":
			if not c_p.grapple_in_control:
				return {"success": false, "reason": "not_in_control"}
			var dmg: Dictionary = IndividualCombat.grapple_hit(character, dice_engine)
			WoundSystem.apply_damage(target, dmg["damage"])
			result = {"success": true, "damage": dmg["damage"],
				"target_dead": CharacterStats.is_dead(target)}
			_check_and_mark_over(state, partner_id, target)

		"throw":
			if not c_p.grapple_in_control:
				return {"success": false, "reason": "not_in_control"}
			IndividualCombat.grapple_throw(c_p, t_p)
			result = {"success": true, "target_prone": true}

		"take_control":
			var ctrl: Dictionary = IndividualCombat.resolve_grapple_control(character, target, dice_engine)
			if ctrl["attacker_wins"]:
				c_p.grapple_in_control = true
				t_p.grapple_in_control = false
			else:
				c_p.grapple_in_control = false
				t_p.grapple_in_control = true
			result = {"success": ctrl["attacker_wins"], "control_gained": ctrl["attacker_wins"]}

		_:
			return {"success": false, "reason": "unknown_grapple_action"}

	ts.consume_complex()
	state.combat_log.append({
		"type": "grapple_action",
		"round": state.combat.round_number,
		"char_id": char_id,
		"action": action_type,
		"result": result,
	})
	return result


## Stand up from Prone. Costs a Simple action (GDD s40).
static func execute_stand_up(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}

	if IndividualCombat.CONDITION_PRONE not in p.conditions:
		return {"success": false, "reason": "not_prone"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}

	IndividualCombat.remove_condition(p, IndividualCombat.CONDITION_PRONE)
	ts.consume_simple()

	state.combat_log.append({
		"type": "stand_up",
		"round": state.combat.round_number,
		"char_id": char_id,
	})
	return {"success": true}


## Spend a Void Point to add +1k1 to next attack/defense roll (GDD s40).
## Free action.
static func execute_void_spend(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}

	if p.void_spent_this_round:
		return {"success": false, "reason": "void_already_spent_this_round"}

	# Spend VP for +1k1 on next roll (GDD s40). Must check success BEFORE
	# marking the once-per-round slot consumed.
	var result: Dictionary = VoidSystem.spend_for_roll(character)
	if not result.get("success", false):
		return {"success": false, "reason": "no_void_points"}

	p.void_spent_this_round = true
	p.void_roll_pending_rolled = result.get("rolled_bonus", 1)
	p.void_roll_pending_kept = result.get("kept_bonus", 1)
	ts.consume_free()

	state.combat_log.append({
		"type": "void_spend",
		"round": state.combat.round_number,
		"char_id": char_id,
	})
	return {"success": true}


## Break/destroy a fragile tile (shoji, paper wall, bamboo). Complex action.
static func execute_destroy_tile(
	state: MapCombatState,
	char_id: int,
	tx: int,
	ty: int,
	character: L5RCharacterData,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	var pos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if pos.x < 0:
		return {"success": false, "reason": "position_unknown"}

	# Must be adjacent.
	if _chebyshev(pos, Vector2i(tx, ty)) > 1:
		return {"success": false, "reason": "tile_too_far"}

	var tile: int = state.map.get_tile(tx, ty)
	if not AsciiMapData.is_destructible(tile):
		return {"success": false, "reason": "tile_not_destructible"}

	var replacement: int = state.map.destroy_tile(tx, ty)
	ts.consume_complex()

	state.combat_log.append({
		"type": "destroy_tile",
		"round": state.combat.round_number,
		"char_id": char_id,
		"tile_pos": Vector2i(tx, ty),
		"old_tile": tile,
		"new_tile": replacement,
	})
	return {"success": true, "tile_destroyed": tile, "replacement": replacement}


## Flee: character removes themselves from the combat map.
## Costs the full movement budget (Complex action equivalent).
static func execute_flee(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}

	state.positions.erase(char_id)
	state.fled_ids.append(char_id)
	ts.consume_complex()

	state.combat_log.append({
		"type": "flee",
		"round": state.combat.round_number,
		"char_id": char_id,
	})
	return {"success": true}


# =============================================================================
# -- Turn Management ----------------------------------------------------------
# =============================================================================

## Start a character's turn: call IndividualCombat.begin_turn(), reset TurnState.
static func begin_turn(state: MapCombatState, char_id: int) -> void:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p != null:
		IndividualCombat.begin_turn(p)
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts != null:
		ts.complex_used = false
		ts.simple_used = 0
		ts.free_move_used = false
		ts.free_actions_used = 0
		ts.stance_changed = false


## Get the character_id whose turn it currently is.
static func get_current_actor(state: MapCombatState) -> int:
	if state.combat.is_over:
		return -1
	var order: Array = state.combat.turn_order
	var idx: int = state.combat.current_turn_index
	if idx >= order.size():
		return -1
	var cid: int = order[idx]
	# Skip fled or dead participants.
	while (cid in state.fled_ids or _is_participant_out(state, cid)) and idx < order.size() - 1:
		idx += 1
		cid = order[idx]
	# If the final candidate is also out, return -1 (no valid actor).
	if cid in state.fled_ids or _is_participant_out(state, cid):
		return -1
	state.combat.current_turn_index = idx
	return cid


## Advance to the next actor in the turn order.
## When all have acted, advance the round.
static func advance_turn(
	state: MapCombatState,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	state.combat.current_turn_index += 1
	var order_size: int = state.combat.turn_order.size()

	# If all actors have gone, end the round.
	if state.combat.current_turn_index >= order_size:
		return advance_round(state, chars_by_id, dice_engine)

	# Skip fled/dead participants.
	while state.combat.current_turn_index < order_size:
		var cid: int = state.combat.turn_order[state.combat.current_turn_index]
		if cid not in state.fled_ids and not _is_participant_out(state, cid):
			break
		state.combat.current_turn_index += 1

	if state.combat.current_turn_index >= order_size:
		return advance_round(state, chars_by_id, dice_engine)

	var next_actor: int = state.combat.turn_order[state.combat.current_turn_index]
	begin_turn(state, next_actor)

	return {
		"type": "next_turn",
		"actor": next_actor,
		"round": state.combat.round_number,
		"is_over": state.combat.is_over,
	}


## Advance to the next round: reactions, condition recovery, initiative re-roll, re-check combat over.
static func advance_round(
	state: MapCombatState,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Advance reaction phase for all living participants (handles dazed/stunned recovery).
	IndividualCombat.advance_round_reactions(state.combat, chars_by_id, dice_engine)

	# Check if combat is over.
	if IndividualCombat.check_combat_over(state.combat, chars_by_id):
		state.combat_log.append({
			"type": "combat_over",
			"round": state.combat.round_number,
			"winner_id": state.combat.winner_id,
		})
		return {"type": "combat_over", "winner_id": state.combat.winner_id, "is_over": true}

	# Reset per-round participant flags before the new round begins.
	for _p: IndividualCombat.Participant in state.combat.participants.values():
		_p.has_acted_this_round = false
		_p.is_delaying = false
		_p.void_spent_this_round = false
		_p.void_armor_tn_bonus = 0
		_p.void_roll_pending_rolled = 0
		_p.void_roll_pending_kept = 0
		_p.kata_used_this_round.clear()
		_p.extra_attack_used_this_turn = false
		_p.earth_init_trade_amount = 0
		if _p.void_ring_bonus > 0 and not _p.center_stance_bonus_used:
			_p.void_ring_bonus = 0

	state.combat.round_number += 1
	state.combat.current_turn_index = 0

	# Re-roll initiative for all active participants (L5R 4e: initiative re-rolled each round).
	# CENTER stance carry-forward: void bonus from last round applies to this roll.
	for cid: int in state.combat.turn_order:
		if _is_participant_out(state, cid):
			continue
		var c: L5RCharacterData = chars_by_id.get(cid, null)
		if c == null or CharacterStats.is_dead(c):
			continue
		var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if p == null:
			continue
		var weapon_name: String = IndividualCombat.pick_best_weapon(c)
		var init_score: int = IndividualCombat.roll_initiative(c, p, dice_engine, weapon_name)
		p.initiative_score = init_score

	# Re-sort turn order by new initiative scores.
	state.combat.turn_order.sort_custom(func(a: int, b: int) -> bool:
		var pa: IndividualCombat.Participant = state.combat.participants.get(a, null)
		var pb: IndividualCombat.Participant = state.combat.participants.get(b, null)
		var ia: int = pa.initiative_score if pa != null else 0
		var ib: int = pb.initiative_score if pb != null else 0
		return ia > ib
	)

	# Begin first actor's turn.
	var first_actor: int = -1
	for cid: int in state.combat.turn_order:
		if cid not in state.fled_ids and not _is_participant_out(state, cid):
			first_actor = cid
			break

	if first_actor >= 0:
		begin_turn(state, first_actor)

	state.combat_log.append({
		"type": "round_start",
		"round": state.combat.round_number,
		"first_actor": first_actor,
	})

	return {
		"type": "round_advanced",
		"new_round": state.combat.round_number,
		"first_actor": first_actor,
		"is_over": false,
	}


# =============================================================================
# -- NPC AI Turn --------------------------------------------------------------
# =============================================================================

## Execute a full NPC turn using the GDD s40 combat decision model.
## Returns a Dictionary of all actions taken this turn.
static func execute_npc_turn(
	state: MapCombatState,
	npc_id: int,
	npc: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var actions_taken: Array = []
	var ts: TurnState = state.turn_states.get(npc_id, null)
	if ts == null:
		return {"actions": [], "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(npc)
	if CharacterStats.is_dead(npc):
		return {"actions": [], "reason": "dead"}

	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {"actions": [], "reason": "participant_missing"}

	begin_turn(state, npc_id)

	# -- Pick optimal stance -----------------------------------------------
	var stance_result: Dictionary = _npc_pick_stance(state, npc_id, npc, chars_by_id, dice_engine)
	if stance_result.get("changed", false):
		actions_taken.append(stance_result)

	# -- Handle grapple -------------------------------------------------------
	if IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED):
		if p.grapple_in_control:
			# In control: try to hit or throw.
			var partner_id: int = p.grapple_partner_id
			var partner: L5RCharacterData = chars_by_id.get(partner_id, null)
			if partner != null and not CharacterStats.is_dead(partner):
				var ga: Dictionary = execute_grapple_action(state, npc_id, "hit", npc, partner, dice_engine)
				actions_taken.append({"action": "grapple_hit", "result": ga})
		else:
			# Not in control: try to take control.
			var partner_id: int = p.grapple_partner_id
			var partner: L5RCharacterData = chars_by_id.get(partner_id, null)
			if partner != null and not CharacterStats.is_dead(partner):
				var gc: Dictionary = execute_grapple_action(state, npc_id, "take_control", npc, partner, dice_engine)
				actions_taken.append({"action": "grapple_control", "result": gc})
		return {"actions": actions_taken}

	# -- Stand up if prone ----------------------------------------------------
	if IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE):
		if not ts.is_down_restricted(wl) and ts.can_use_simple():
			var su: Dictionary = execute_stand_up(state, npc_id, npc)
			actions_taken.append({"action": "stand_up", "result": su})

	# -- Identify best target -------------------------------------------------
	var melee_targets: Array = get_melee_targets(state, npc_id)
	var ranged_targets: Array = get_ranged_targets(state, npc_id)
	var best_target: int = _npc_pick_target(state, npc_id, melee_targets + ranged_targets, chars_by_id)

	if best_target < 0:
		# No visible target — do nothing (or wait).
		return {"actions": actions_taken}

	var weapon_name: String = IndividualCombat.pick_best_weapon(npc)
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	var is_melee_weapon: bool = wp.get("melee", true)

	# -- Move toward target if needed -----------------------------------------
	var target_in_melee: bool = (best_target in melee_targets)
	var target_in_ranged: bool = (best_target in ranged_targets)

	if not target_in_melee and not target_in_ranged:
		# Move toward target using free move first, then simple if needed.
		var moved: bool = false
		if ts.can_use_free_move() and not ts.is_down_restricted(wl):
			var free_budget: int = MovementSystem.budget(CharacterStats.get_ring_value(npc, Enums.Ring.WATER), MovementSystem.MoveAction.FREE)
			var move_r: Dictionary = _npc_move_toward(state, npc_id, best_target, npc, free_budget, "free", dice_engine)
			if move_r.get("success", false):
				actions_taken.append({"action": "free_move", "result": move_r})
				moved = true
				melee_targets = get_melee_targets(state, npc_id)
				target_in_melee = (best_target in melee_targets)

		if not target_in_melee and ts.can_use_simple() and not ts.is_down_restricted(wl):
			var simple_budget: int = MovementSystem.budget(CharacterStats.get_ring_value(npc, Enums.Ring.WATER), MovementSystem.MoveAction.SIMPLE)
			var move_r: Dictionary = _npc_move_toward(state, npc_id, best_target, npc, simple_budget, "simple", dice_engine)
			if move_r.get("success", false):
				actions_taken.append({"action": "simple_move", "result": move_r})
				melee_targets = get_melee_targets(state, npc_id)
				target_in_melee = (best_target in melee_targets)

	# Re-check targets after movement.
	if not target_in_melee:
		ranged_targets = get_ranged_targets(state, npc_id)
		target_in_ranged = (best_target in ranged_targets)

	# -- Attack ---------------------------------------------------------------
	if target_in_melee or (not is_melee_weapon and target_in_ranged):
		var target_char: L5RCharacterData = chars_by_id.get(best_target, null)
		if target_char != null and not CharacterStats.is_dead(target_char):
			# Extra Attack requires 5 Raises on the first attack (GDD s40:
			# "These Raises confer no other benefits"). Decide upfront so the
			# first attack is made with the correct raise count.
			var skill_name: String = wp.get("skill", "Kenjutsu")
			var skill_rank: int = npc.skills.get(skill_name, 0)
			var use_extra_attack: bool = target_in_melee and skill_rank >= 5

			var atk_result: Dictionary = _npc_execute_attack(
				state, npc_id, best_target, npc, target_char, weapon_name,
				target_in_melee, dice_engine, use_extra_attack
			)
			actions_taken.append({"action": "attack", "result": atk_result})

			# Extra Attack: only valid when 5 raises were declared on the first
			# attack and that attack hit (GDD s40).
			if use_extra_attack and atk_result.get("hit", false) and not CharacterStats.is_dead(target_char):
				var ea: Dictionary = execute_extra_attack(state, npc_id, best_target, npc, target_char, weapon_name, dice_engine)
				if ea.get("success", false):
					actions_taken.append({"action": "extra_attack", "result": ea})
	elif ts.can_use_free_move() and not ts.is_down_restricted(wl):
		# Can still use free move to get closer.
		var free_budget: int = MovementSystem.budget(CharacterStats.get_ring_value(npc, Enums.Ring.WATER), MovementSystem.MoveAction.FREE)
		var move_r: Dictionary = _npc_move_toward(state, npc_id, best_target, npc, free_budget, "free", dice_engine)
		if move_r.get("success", false):
			actions_taken.append({"action": "free_move_late", "result": move_r})

	return {"actions": actions_taken}


# =============================================================================
# -- NPC AI Helpers -----------------------------------------------------------
# =============================================================================

## NPC stance selection: aggressive when at advantage, defensive when wounded.
## Returns {changed: bool, new_stance: int}.
static func _npc_pick_stance(
	state: MapCombatState,
	npc_id: int,
	npc: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(npc_id, null)
	if ts == null or not ts.can_use_simple():
		return {"changed": false}

	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {"changed": false}

	var wl: int = CharacterStats.get_wound_level(npc)
	var desired: int = _npc_desired_stance(npc, wl)

	if p.stance == desired as Enums.Stance:
		return {"changed": false}

	# Only change stance if there's a meaningful reason (not just a marginal preference).
	var result: Dictionary = execute_stance_change(state, npc_id, desired, npc, dice_engine)
	if result.get("success", false):
		return {"changed": true, "new_stance": desired}
	return {"changed": false}


## Determine desired stance for an NPC based on wound level and role (GDD s40 stances).
static func _npc_desired_stance(npc: L5RCharacterData, wound_level: int) -> Enums.Stance:
	if wound_level >= Enums.WoundLevel.HURT:
		return Enums.Stance.DEFENSE
	# High Kenjutsu/combat skill: use Attack stance for Void carry-forward potential.
	var best_combat: int = 0
	for skill_name: String in ["Kenjutsu", "Polearms", "Heavy Weapons", "Jiujutsu"]:
		best_combat = maxi(best_combat, npc.skills.get(skill_name, 0))
	if best_combat >= 4:
		return Enums.Stance.ATTACK
	# Low-skill combatants use CENTER stance: balanced defense with void carry potential.
	return Enums.Stance.CENTER


## Pick the best target: most-wounded (highest wounds_taken) enemy to focus fire.
static func _npc_pick_target(
	state: MapCombatState,
	npc_id: int,
	candidate_ids: Array,
	chars_by_id: Dictionary,
) -> int:
	var best_id: int = -1
	var best_wounds: int = -1
	for cid: int in candidate_ids:
		if cid == npc_id:
			continue
		var c: L5RCharacterData = chars_by_id.get(cid, null)
		if c == null or CharacterStats.is_dead(c):
			continue
		var wt: int = c.wounds_taken
		if wt > best_wounds:
			best_wounds = wt
			best_id = cid
	return best_id


## Move NPC one step toward a target using BFS shortest path.
static func _npc_move_toward(
	state: MapCombatState,
	npc_id: int,
	target_id: int,
	npc: L5RCharacterData,
	budget: int,
	action_type: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	if budget <= 0:
		return {"success": false, "reason": "zero_budget"}

	var path: Array = find_path(state, npc_id, state.positions.get(target_id, Vector2i(-1, -1)))
	if path.is_empty():
		return {"success": false, "reason": "no_path"}

	# Move as far along the path as budget allows (stopping before the target's tile).
	var dest: Vector2i = state.positions.get(npc_id, Vector2i(-1, -1))
	var cost_used: int = 0
	for step: Vector2i in path:
		# Don't step onto the target's tile.
		if step == state.positions.get(target_id, Vector2i(-1, -1)):
			break
		var tile: int = state.map.get_tile(step.x, step.y)
		var step_cost: int = MovementSystem.terrain_cost(tile)
		if step_cost == 0:
			break
		if cost_used + step_cost > budget:
			break
		dest = step
		cost_used += step_cost

	if dest == state.positions.get(npc_id, Vector2i(-1, -1)):
		return {"success": false, "reason": "cannot_advance"}

	return execute_move(state, npc_id, dest, budget, npc, dice_engine, action_type)


## Execute NPC attack with smart raise selection (GDD s40 maneuvers).
## When use_extra_attack is true, declares 5 Raises for Extra Attack (GDD s40:
## "These Raises confer no other benefits"), precluding Increased Damage.
static func _npc_execute_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	target_in_melee: bool,
	dice_engine: DiceEngine,
	use_extra_attack: bool = false,
) -> Dictionary:
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	var is_melee: bool = wp.get("melee", true)

	var skill_name: String = wp.get("skill", "Kenjutsu")
	var skill_rank: int = attacker.skills.get(skill_name, 0)
	var raises: int = 0
	var maneuver: String = ""

	if use_extra_attack:
		# 5 Raises dedicated to Extra Attack; no other raise benefit (GDD s40).
		raises = 5
	elif skill_rank >= 3:
		# 1 Raise for Increased Damage (GDD s40 maneuvers).
		raises = 1
		maneuver = "increased_damage"

	if is_melee or target_in_melee:
		return execute_melee_attack(
			state, attacker_id, target_id, attacker, target,
			weapon_name, raises, dice_engine, maneuver
		)
	else:
		return execute_ranged_attack(
			state, attacker_id, target_id, attacker, target,
			weapon_name, raises, dice_engine
		)


# =============================================================================
# -- Down State Attack (Void Point required, GDD s40) -------------------------
# =============================================================================

static func _execute_down_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Down characters may only take free actions and must spend a Void Point (GDD s40).
	if not VoidSystem.can_spend(attacker):
		return {"success": false, "reason": "down_no_void_points"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	if a_p.void_spent_this_round:
		return {"success": false, "reason": "void_already_spent_this_round"}

	var void_result: Dictionary = VoidSystem.spend_for_roll(attacker)
	if not void_result.get("success", false):
		return {"success": false, "reason": "void_spend_failed"}
	a_p.void_spent_this_round = true

	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, is_being_guarded, weapon_name)

	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, 0, dice_engine, false, false, false, "",
		{"opponent_clan": target.clan}
	)
	result["void_required"] = true

	if result.get("hit", false):
		var dmg: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, 0, "", result, dice_engine)
		result["damage"] = dmg.get("damage", 0)
		result["target_dead"] = dmg.get("dead", false)

	state.combat_log.append({
		"type": "down_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"hit": result.get("hit", false),
	})
	_check_and_mark_over(state, target_id, target)
	return result


# =============================================================================
# -- Internal Helpers ---------------------------------------------------------
# =============================================================================

## Apply a successful hit: resolve damage and apply wounds.
static func _apply_hit(
	state: MapCombatState,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	target: L5RCharacterData,
	weapon_name: String,
	raises: int,
	maneuver: String,
	attack_result: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var feint_bonus: int = 0
	var raises_for_damage: int = 0

	if maneuver == "feint":
		feint_bonus = IndividualCombat.compute_feint_bonus(
			attack_result.get("margin", 0),
			CharacterStats.get_insight_rank(attacker)
		)
	elif maneuver == "increased_damage":
		raises_for_damage = raises

	var dmg: Dictionary = IndividualCombat.resolve_damage(
		attacker, weapon_name, raises_for_damage, feint_bonus, dice_engine, a_p, maneuver == "feint"
	)
	var raw: int = dmg["raw_damage"]

	var wd_result: Dictionary = WoundSystem.apply_damage(target, raw)

	return {
		"damage": wd_result.get("final_damage", raw),
		"wounds": wd_result.get("final_damage", raw),
		"dead": CharacterStats.is_dead(target),
	}


## Check if a character is dead, erase them from the map, and mark combat over
## if no two opposing factions remain. Avoids requiring chars_by_id in hot path.
static func _check_and_mark_over(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> void:
	if not CharacterStats.is_dead(character):
		return
	# Remove the dead combatant from the map immediately.
	state.positions.erase(char_id)
	# Scan remaining positioned combatants; if only one faction remains, combat ends.
	var faction_to_id: Dictionary = {}  # faction -> one surviving char_id
	for cid: int in state.positions.keys():
		var f: String = state.factions.get(cid, FACTION_NEUTRAL)
		faction_to_id[f] = cid
	if faction_to_id.size() <= 1:
		state.combat.is_over = true
		if faction_to_id.size() == 1:
			state.combat.winner_id = faction_to_id.values()[0]


## True if a participant is effectively out of combat (dead or fled).
## Fled characters are already erased from positions, so absence from
## positions is sufficient — no need to exclude fled_ids separately.
static func _is_participant_out(state: MapCombatState, char_id: int) -> bool:
	return not state.positions.has(char_id)


## Chebyshev (chessboard) distance: max(|dx|, |dy|).
static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


## Bresenham line-of-sight check.
## Returns true if no LOS-blocking tile lies between a and b (exclusive of endpoints).
static func _has_los(map: AsciiMapData, a: Vector2i, b: Vector2i) -> bool:
	var x0: int = a.x
	var y0: int = a.y
	var x1: int = b.x
	var y1: int = b.y

	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	var cx: int = x0
	var cy: int = y0

	while true:
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy
		# Check intermediate tiles (not start or end).
		if cx == x1 and cy == y1:
			break
		if AsciiMapData.blocks_los(map.get_tile(cx, cy)):
			return false

	return true


## True if the two factions are enemies.
static func _are_enemies(faction_a: String, faction_b: String) -> bool:
	if faction_a == FACTION_NEUTRAL or faction_b == FACTION_NEUTRAL:
		return false
	return faction_a != faction_b


## True if a guardian is present and within range of target_id.
static func _is_being_guarded(state: MapCombatState, target_id: int) -> bool:
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if tpos.x < 0:
		return false
	for cid: int in state.combat.participants.keys():
		var p: IndividualCombat.Participant = state.combat.participants[cid]
		if p.guarding_id == target_id:
			var gpos: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
			if gpos.x >= 0 and _chebyshev(gpos, tpos) <= GUARD_RANGE_TILES:
				return true
	return false


## True if moving to dest brings mover closer to any enemy (for Full Attack restriction).
static func _dest_is_toward_enemy(
	state: MapCombatState,
	mover_id: int,
	cur: Vector2i,
	dest: Vector2i,
) -> bool:
	for cid: int in state.positions.keys():
		if cid == mover_id:
			continue
		var ef: String = state.factions.get(cid, FACTION_NEUTRAL)
		var mf: String = state.factions.get(mover_id, FACTION_NEUTRAL)
		if not _are_enemies(mf, ef):
			continue
		var ep: Vector2i = state.positions[cid]
		var cur_dist: int = _chebyshev(cur, ep)
		var new_dist: int = _chebyshev(dest, ep)
		if new_dist < cur_dist:
			return true
	return false
