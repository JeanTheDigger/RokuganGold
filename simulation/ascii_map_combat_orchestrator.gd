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
## s54.12 Jimen no Oni Trembling Earth: -1k0 to all rolls within 50' (10 tiles).
const TREMBLING_EARTH_TILES: int = 10
const MIMIC_DISGUISE_ROUNDS: int = 5  # s54.10 Mimic: "lasts ... 5 Rounds in battle"
const DECEPTIVE_WEIGHT_ESCAPE_TN: int = 40  # s54.10 Konak Jiji: Athletics/Strength TN 40 to move it
const HEART_LOCATE_TN: int = 30  # s54.5 Arugai: Investigation/Perception TN 30 to find the heart
const HEART_WOUNDS: int = 10     # s54.5 Arugai: the exposed heart sustains 10 Wounds
const BANE_BOLT_RANGE_TILES: int = 10  # s54.5 Sodatsu bolt range 50 ft = 10 tiles
const BANE_BOLT_ROLLED: int = 4        # s54.5 Sodatsu bolt attack roll 4k4
const BANE_BOLT_KEPT: int = 4
const BANE_BOLT_DR_KEPT: int = 2       # PROVISIONAL: "DR equal to Mastery Level" -> ML k 2 (kept unstated)
const BANE_ARMOR_ROUNDS: int = 3       # s54.5 Sodatsu armor mode lasts 3 rounds

## Guard maneuver range: "within 5 feet" = 1 tile (GDD s40).
const GUARD_RANGE_TILES: int = 1
const DISARM_RAISES: int = 3  # s40: Disarm requires 3 Raises (banked Free Raises reduce it)

## Ranged attack while within melee range penalty (GDD s40 confirmed).
const RANGED_IN_MELEE_PENALTY: int = -10

# Cover: a defender sheltering behind a cover-granting furnishing (s4.4) gains
# +5 Armor TN against attacks coming from the covered side. Reuses the s40 cover
# convention (the ruined-structure +5 cover value). A defender tucked below a
# higher lip (s4.4 Z-axis) reuses the same +5 bonus.
const COVER_ARMOR_TN_BONUS: int = 5

## High-ground combat (s4.4 Z-axis; locked by owner 2026-06-23). An attacker at
## least HIGH_GROUND_THRESHOLD levels above the target adds HIGH_GROUND_ATTACK_ROLLED
## rolled die (+1k0) to the attack (melee and ranged).
const HIGH_GROUND_THRESHOLD: int = 1
const HIGH_GROUND_ATTACK_ROLLED: int = 1

## Height-aware line of sight (s4.4 Z-axis). A tile occludes the sightline only when
## its top reaches the interpolated view-ray height between the two endpoints.
## LOS_EYE_HEIGHT lifts both endpoints to standing eye level; an LOS-blocking tile
## (wall/tree) rises LOS_OBSTACLE_HEIGHT (~10 ft) above its own elevation, while open
## ground occludes only by its raw elevation (a ridge can still block). On a flat map
## the formula reduces to the prior behavior exactly (walls block, open ground does not).
const LOS_EYE_HEIGHT: int = 1
const LOS_OBSTACLE_HEIGHT: int = 2

## Climb difficulty by surface material (s4.4 Z-axis; owner-locked 2026-06-23).
## Strength + Athletics vs the material's TN — not all surfaces are equally hard:
## timber/palisade gives handholds, sheer worked stone barely any. Used both for an
## elevation cliff (keyed off the higher tile's terrain) and for scaling a wall
## (keyed off the wall material).
const CLIMB_TN_WOOD: int = 15
const CLIMB_TN_EARTH: int = 20
const CLIMB_TN_STONE: int = 25

## Climb TN for a tile's material. Wood (timber/palisade) easiest, sheer stone
## (rock ledge / masonry wall) hardest, everything natural (earth/grass/rubble)
## in between.
static func _climb_tn_for_tile(tile: int) -> int:
	match tile:
		Enums.TileType.FLOOR_WOOD, Enums.TileType.WALL_WOOD, \
		Enums.TileType.DOOR_WOOD_CLOSED, Enums.TileType.DOOR_WOOD_OPEN:
			return CLIMB_TN_WOOD
		Enums.TileType.FLOOR_STONE, Enums.TileType.WALL_STONE:
			return CLIMB_TN_STONE
		_:
			return CLIMB_TN_EARTH

## Pit/void death hazard (s4.4 Z-axis, Oni Warai chasm; owner-locked 2026-06-23).
## A bottomless void or deep water is lethal — NOT a graduated NkN fall. Being shoved
## toward one by knockback triggers an edge-catch save (Reflexes + Athletics vs
## PIT_EDGE_CATCH_TN): success stops the victim on the brink, failure sends them over
## to their death. Walking off such an edge under one's own movement is already
## prevented (these tiles are impassable, so the mover stops); the only vector is a
## forced shove, which routes through _knockback_target.
const PIT_EDGE_CATCH_TN: int = 20

## Lethal pit tiles: a bottomless chasm (VOID) and deep open water (drowning under
## armor). Both are already impassable for ordinary movement.
static func _is_lethal_pit(tile: int) -> bool:
	return tile == Enums.TileType.VOID or tile == Enums.TileType.WATER_DEEP

## s40 "Weapon Grapples": a weapon-grappler who loses control of the grapple
## hands their opponent 2 Free Raises toward a Disarm Maneuver against them.
const WEAPON_GRAPPLE_LOSE_CONTROL_DISARM_RAISES: int = 2

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
	## s36/s35 action-economy spells — one-shot bonus pools beyond the normal budget.
	## granted_attacks: extra ATTACK actions (Stand Against the Waves). granted_simple: extra
	## NON-attack Simple actions, e.g. a Move (Spirit of the Water). cast_as_simple: the next
	## Fire ML<=3 cast costs a Simple, not a Complex (Hurried Steps). free_casts: Fire ML<=4 casts
	## are Free Actions (The Element's Fury). These persist until used (the Reactions-Stage timing
	## maps to "an extra action on the recipient's next turn") and are NOT cleared by the turn reset.
	var granted_attacks: int = 0
	var granted_simple: int = 0
	var cast_as_simple: int = 0
	var free_casts: int = 0

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
	## Combatant objects by id (id → L5RCharacterData), for ally lookups at attack time.
	var combatants: Dictionary = {}
	## Character tile positions. Key: int (character_id), Value: Vector2i.
	var positions: Dictionary = {}
	## Stacked-floor level per combatant (s4.4 Option B). Key: int (character_id),
	## Value: int level. ABSENT = level 0, so single-level skirmishes never touch this.
	var combatant_levels: Dictionary = {}
	## Character factions. Key: int (character_id), Value: String (FACTION_*).
	var factions: Dictionary = {}
	## Per-character turn budgets. Key: int (character_id), Value: TurnState.
	var turn_states: Dictionary = {}
	## Ordered combat log entries for the encounter.
	var combat_log: Array = []
	## Characters who have fled (removed from map, no longer in turn order).
	var fled_ids: Array = []
	## Allied companion records (GDD s57.46). Key: int (character_id), Value: CompanionData.
	var companion_data: Dictionary = {}
	## companion_ids who started the mission — denominator for morale casualties.
	var companion_started_count: int = 0
	## Mission weather (AsciiMapEnvironment.WeatherState) — drives FireSystem spread
	## and extinguish at round end (s56.6.6). Wind bearing lives on map.wind_dir.
	var weather: int = AsciiMapEnvironment.WeatherState.CLEAR
	## Touch the Void Dragon (s38): terrain-derived Ring (Enums.Ring) for this skirmish; -1 = none.
	var environment_ring: int = -1
	## Per-skirmish dedup for "once per skirmish" atemi (kiho_name → Array[target_id]).
	var once_per_skirmish_atemi: Dictionary = {}
	## Death Touch consecutive-strike chains: "caster_id:target_id" → {count, last_round}.
	var death_touch_chains: Dictionary = {}
	## Sense the Balance reveals: "caster_id:target_id" → Array of revealed Enums ints.
	var sense_known: Dictionary = {}
	## To the Last Breath uses this skirmish: target_id → count (max 2 per target).
	var last_breath_uses: Dictionary = {}
	## s54.10 Ancient General Tactical Mastery: "generalid:targetid" → {count, last_round}
	## (distinct rounds the General has attacked that character; drives the +1k0/+2k0).
	var tactical_engaged: Dictionary = {}
	## s54.10 Ancient General Undying: spawn-key → reform-due round (reforms once).
	var reform_pending: Dictionary = {}
	## s54.10 Ancient General Duelist's Challenge: the active formal duel (other Musha
	## cease attacking while it stands). -1 = no duel; duel_offered = once-per-encounter.
	var duel_challenger_id: int = -1
	var duel_target_id: int = -1
	var duel_offered: bool = false
	## s54.5 spawn-on-death: monotonic counter for unique negative spawn instance ids.
	var spawn_counter: int = 0
	## s37 Divide the Soul: bidirectional caster<->clone link (id -> partner id). If either
	## manifestation dies, both die.
	var divide_soul_pairs: Dictionary = {}
	## s43 Tomb of Earth: maintained per-round contest. target_id -> caster_id. Each Round the caster
	## re-contests (Earth+Insight vs Air+Insight); winning keeps the target immobilized + 2k2, losing
	## frees them (link removed).
	var tomb_links: Dictionary = {}
	## s43 Blood Armor: wearer_id -> victim_id. The wearer channels 75% of its incoming damage into the
	## bonded victim (read in _apply_hit). The bond breaks when the victim dies.
	var blood_armor_links: Dictionary = {}
	## s54.5 Manesuru Dark Mirror: target ids fully studied, target ids already mirrored, count spawned.
	var mirror_studied: Dictionary = {}
	var mirror_spawned: Dictionary = {}
	var mirrors_count: int = 0
	## s54.5 Gagoze Taint Affliction: per-gazer set of victim ids already gazed (once each).
	var taint_gaze_used: Dictionary = {}
	## s35/s34 persistent spell zones (Wall of Fire, Enticing the Dance of Flame, Maw of the Earth,
	## the elemental Symbols). Each: {center:Vector2i, radius:int, kind, dr_rolled, dr_kept, element,
	## faction (owner), hits ("all"/"enemies"), expiry_round (-1 = permanent), spell_id, plus
	## per-kind fields (entry_condition, save, save_tn, tn_penalty for wards)}. Processed each round
	## in advance_round; wards are read at cast time in resolve_cast.
	var spell_zones: Array = []
	## s33 Mists of Illusion: stationary visual-only phantoms — {x, y, caster_id}.
	var illusion_phantoms: Array = []


# =============================================================================
# -- Setup --------------------------------------------------------------------
# =============================================================================

## Create a new MapCombatState and roll initiative for all participants.
## combatants_data: Array of {char: L5RCharacterData, faction: String, x: int, y: int}
static func setup_combat(
	map: AsciiMapData,
	combatants_data: Array,
	dice_engine: DiceEngine,
	environment_ring: int = -1,
	weather: int = AsciiMapEnvironment.WeatherState.CLEAR,
) -> MapCombatState:
	var mcs := MapCombatState.new()
	mcs.map = map
	mcs.environment_ring = environment_ring  # Touch the Void Dragon (s38)
	mcs.weather = weather  # FireSystem spread/extinguish (s56.6.6)

	var chars_for_combat: Array = []
	var participant_dicts: Array = []
	for entry: Dictionary in combatants_data:
		var c: L5RCharacterData = entry["char"]
		if CharacterStats.is_dead(c):
			continue
		c.combat_ring_deltas = {}  # no-leak guarantee: every combat starts with the ring bridge clear
		chars_for_combat.append(c)
		mcs.combatants[c.character_id] = c
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
		# s40 dual-wield schools: flag the Participant from the character's off-hand
		# weapon so the off-hand attack / dominant-hand / two-weapon rules apply.
		if c.off_hand_weapon != "":
			p.dual_wielding = true
			p.off_hand_weapon = c.off_hand_weapon

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

## Free-action move budget (in tiles) for a combatant, including the Striking as
## Water kata bonus (s30a: +5 ft = +1 tile in Attack Stance). Callers (NPC AI,
## companion AI, and the player-facing turn-based move UI) should use this rather
## than MovementSystem.budget(...FREE) directly so the kata is honored uniformly.
static func free_move_budget(state: MapCombatState, char_id: int, character: L5RCharacterData) -> int:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	var water: int = _effective_water_ring(p, character)
	# Flight speed (per spell) replaces the normal ground budget; terrestrial kata/kiho/
	# swift move bonuses do not apply while airborne.
	var fc: int = _flight_code(state, char_id)
	if fc > 0:
		return _flight_free_budget(water, fc)
	var base: int = MovementSystem.budget(water, MovementSystem.MoveAction.FREE)
	if p == null:
		return base
	# s36 The Rushing Wave: Free Move up to Water Ring ×10' (= +Water tiles to the free-move
	# budget, read from the mover's own effective Water at move time, not fixed at cast time).
	var rush: int = water if IndividualCombat.get_timed_modifier_total(p, "free_move_tiles") > 0 else 0
	return base + IndividualCombat.get_kata_free_move_bonus(character, p) + IndividualCombat.get_kiho_move_bonus(character, p) + IndividualCombat.get_creature_swift_bonus(character) + rush


## Water Ring for Move-distance purposes, reduced by any timed move penalty
## (s38 Speed of the Mountains: −2 Ranks for Move Action distance). Floored at 0.
static func _effective_water_ring(p: IndividualCombat.Participant, character: L5RCharacterData) -> int:
	var water: int = CharacterStats.get_ring_value(character, Enums.Ring.WATER)
	if p == null:
		return water
	return maxi(0, water + IndividualCombat.get_timed_modifier_total(p, "move_water_penalty"))


## BFS flood-fill returning all tiles reachable within move_budget steps.
## Enemy tiles are treated as impassable (block movement through). Ally tiles
## are passable (you can move through an ally's tile).
## Returns Dictionary: Vector2i → cost (int).
## True while the combatant is flying (a "flight" timed modifier from a flight spell —
## Call Upon the Wind / Wings of Fire / Wings of the Phoenix). A flyer occupies open
## spaces (open air/void, water) and ignores elevation cliffs and fall/pit hazards.
static func _is_flying(state: MapCombatState, char_id: int) -> bool:
	return _flight_code(state, char_id) > 0


# Flight speed codes (the "flight" timed-modifier value; 1 tile = 5 ft):
const FLIGHT_CALL_UPON_WIND: int = 1   # ≤10'/Round (2 tiles), Free Move only
const FLIGHT_WINGS_OF_FIRE: int = 2    # Water 1 speed; arms occupied (no weapon attacks)
const FLIGHT_WINGS_PHOENIX: int = 3    # Water×10' Free / Water×20' Simple

## The active flight speed code (0 = not flying). Reads the MAX "flight" modifier value
## so a recast (the stronger flight) wins rather than summing into a bogus code.
static func _flight_code(state: MapCombatState, char_id: int) -> int:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return 0
	var code: int = 0
	for m: Dictionary in p.timed_modifiers:
		if m.get("kind", "") == "flight":
			code = maxi(code, int(m.get("value", 0)))
	return code

## Per-turn flight movement budget (tiles) for a FREE move, by speed code. Flight speed
## replaces the normal Water-Ring/ground budget (kata/kiho/swift bonuses are terrestrial).
static func _flight_free_budget(water: int, code: int) -> int:
	match code:
		FLIGHT_CALL_UPON_WIND: return 2                 # ≤10'/Round
		FLIGHT_WINGS_OF_FIRE:  return MovementSystem.budget(1, MovementSystem.MoveAction.FREE)   # Water 1
		FLIGHT_WINGS_PHOENIX:  return clampi(water, 1, 10) * 2  # Water×10'
		_: return 0

## Per-turn flight movement budget (tiles) for a SIMPLE move, by speed code. Call Upon the
## Wind is Free-Move-only → 0 (no fast flight).
static func _flight_simple_budget(water: int, code: int) -> int:
	match code:
		FLIGHT_CALL_UPON_WIND: return 0                 # Free Move only
		FLIGHT_WINGS_OF_FIRE:  return MovementSystem.budget(1, MovementSystem.MoveAction.SIMPLE)  # Water 1
		FLIGHT_WINGS_PHOENIX:  return clampi(water, 1, 10) * 4  # Water×20'
		_: return 0

## Wings of Fire (Fire 2) occupies the caster's arms controlling the wings — they cannot
## make weapon/unarmed attacks while it is active (GDD s35). Spellcasting is unaffected
## (a flying shugenja still casts). The other flight spells do not restrict the arms.
static func _arms_occupied(state: MapCombatState, char_id: int) -> bool:
	return _flight_code(state, char_id) == FLIGHT_WINGS_OF_FIRE

## Per-turn movement budget for a SIMPLE move (flight-aware), mirroring free_move_budget
## for the Simple action. Used by the move-decision sites.
static func simple_move_budget(state: MapCombatState, char_id: int, character: L5RCharacterData) -> int:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	var water: int = _effective_water_ring(p, character)
	var fc: int = _flight_code(state, char_id)
	if fc > 0:
		return _flight_simple_budget(water, fc)
	var base: int = MovementSystem.budget(water, MovementSystem.MoveAction.SIMPLE)
	return base + IndividualCombat.get_kiho_move_bonus(character, p) + IndividualCombat.get_creature_swift_bonus(character)


## When flight ends, the kami set the caster down gently (GDD: Call Upon the Wind
## "drifts harmlessly to the ground"; Wings spells "borne safely to earth"). If the
## (former) flyer is over an open/impassable tile, relocate to the nearest passable,
## unoccupied tile.
static func _flight_safe_landing(state: MapCombatState, char_id: int) -> void:
	var pos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if pos.x < 0 or state.map == null:
		return
	if MovementSystem.is_passable(state.map.get_tile(pos.x, pos.y)):
		return  # already on solid ground
	var occupied: Dictionary = {}
	for cid: int in state.positions:
		if cid != char_id:
			occupied[state.positions[cid]] = true
	for r in range(1, maxi(state.map.width, state.map.height)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := Vector2i(pos.x + dx, pos.y + dy)
				if t.x < 0 or t.y < 0 or t.x >= state.map.width or t.y >= state.map.height:
					continue
				if occupied.has(t):
					continue
				if MovementSystem.is_passable(state.map.get_tile(t.x, t.y)):
					state.positions[char_id] = t
					return


static func get_reachable_tiles(
	state: MapCombatState,
	mover_id: int,
	move_budget: int,
) -> Dictionary:
	var start: Vector2i = state.positions.get(mover_id, Vector2i(-1, -1))
	if start.x < 0:
		return {}

	var mover_faction: String = state.factions.get(mover_id, FACTION_NEUTRAL)
	var flying: bool = _is_flying(state, mover_id)
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
				if flying:
					# A flyer occupies open spaces (air/void, water) — only a solid
					# obstruction (wall/tree/door/furniture/roof) blocks. Uniform cost,
					# and elevation cliffs/ledges are ignored (it flies over them).
					if MovementSystem.is_solid_obstruction(tile):
						continue
					step_cost = 1
				else:
					if step_cost == 0:
						continue  # impassable
					# Elevation face: cannot walk up a cliff or off a ledge (s4.4 Z-axis).
					if MovementSystem.is_cliff_step(state.map, pos.x, pos.y, nx, ny):
						continue

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
	var flying: bool = _is_flying(state, mover_id)
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
				if flying:
					# A flyer routes over open spaces (air/void, water) and ignores
					# cliffs; only a solid obstruction blocks it.
					if MovementSystem.is_solid_obstruction(tile):
						continue
				else:
					if MovementSystem.terrain_cost(tile) == 0:
						continue
					# Elevation face: pathing never routes up a cliff or off a ledge (s4.4 Z-axis).
					if MovementSystem.is_cliff_step(state.map, pos.x, pos.y, nv.x, nv.y):
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
		if not _is_targetable(state, cid):
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
		if not _is_targetable(state, cid):
			continue
		var tp: Vector2i = state.positions[cid]
		if _chebyshev(pos, tp) > MELEE_RANGE_TILES and _has_los(state.map, pos, tp) \
				and not _ray_blocked_by_fog(state, pos, tp):
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
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
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

	# A Fatigued character may not take the Full Attack Stance (GDD s2 Fatigue rules).
	if new_stance == Enums.Stance.FULL_ATTACK and IndividualCombat.CONDITION_FATIGUED in p.conditions:
		return {"success": false, "reason": "fatigued_no_full_attack"}

	# s35 Haze of Battle: a stance-locked target cannot switch away from Full Attack.
	if new_stance != Enums.Stance.FULL_ATTACK \
			and IndividualCombat.get_timed_modifier_total(p, "stance_locked") > 0:
		return {"success": false, "reason": "stance_locked"}

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
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "not_in_combat"}

	# Entangled (s54.12 Web / s56.20 Snare): cannot move until broken free (Strength TN 20).
	if IndividualCombat.CONDITION_ENTANGLED in p.conditions:
		return {"success": false, "reason": "entangled"}

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

	# s36 Spirit of the Water: a granted_simple pool lets one extra NON-attack Simple action (a
	# Move is the canonical use) proceed when the normal budget is spent.
	var using_granted_move: bool = false
	match effective_type:
		"free":
			if not ts.can_use_free_move():
				return {"success": false, "reason": "free_move_already_used"}
		"simple":
			if not ts.can_use_simple():
				if ts.granted_simple > 0:
					using_granted_move = true
				else:
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
	# Facing follows movement (s38 arc/cone kiho).
	var _fp: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if _fp != null and dest != old_pos:
		_fp.facing = Vector2i(signi(dest.x - old_pos.x), signi(dest.y - old_pos.y))

	match effective_type:
		"free":    ts.consume_free_move()
		"simple":
			if using_granted_move:
				ts.granted_simple -= 1
			else:
				ts.consume_simple()
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


## Climb to a destination that normal movement cannot reach (s4.4 Z-axis). Two
## forms, auto-detected from the destination; both cost a Complex action and roll
## Strength + Athletics vs the surface material's TN (wood 15 / earth 20 / stone 25):
##   - ELEVATION CLIFF: an adjacent tile a cliff-step away. TN keyed off the higher
##     tile's terrain. Up relocates on success / stays on failure; down always lands,
##     and a failed roll slips and falls the rest (NkN damage).
##   - WALL SCALE: a tile two steps away in a straight orthogonal line with a single
##     WALL_STONE/WALL_WOOD between. TN keyed off the wall material. Success crosses
##     to the far tile; failure stays put (no fall — you just fail to get over).
## Rejects an impassable/occupied/out-of-range/garbled destination, a non-cliff
## adjacent step (use execute_move), a too-thick wall, or a down-restricted/entangled climber.
static func execute_climb(
	state: MapCombatState,
	char_id: int,
	dest: Vector2i,
	character: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if ts == null or p == null:
		return {"success": false, "reason": "not_in_combat"}
	if IndividualCombat.CONDITION_ENTANGLED in p.conditions:
		return {"success": false, "reason": "entangled"}
	if ts.is_down_restricted(CharacterStats.get_wound_level(character)):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	var cur: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if cur.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if dest.x < 0 or dest.y < 0 or dest.x >= state.map.width or dest.y >= state.map.height:
		return {"success": false, "reason": "out_of_bounds"}
	if not MovementSystem.is_passable(state.map.get_tile(dest.x, dest.y)):
		return {"success": false, "reason": "destination_impassable"}
	for cid: int in state.positions:
		if cid != char_id and state.positions[cid] == dest:
			return {"success": false, "reason": "destination_occupied"}

	var ddx: int = dest.x - cur.x
	var ddy: int = dest.y - cur.y
	var is_wall_scale: bool = false
	var tn: int = CLIMB_TN_EARTH
	var delta: int = 0

	if _chebyshev(cur, dest) == 1:
		# Adjacent: an elevation cliff. TN = the higher tile's terrain.
		if not MovementSystem.is_cliff_step(state.map, cur.x, cur.y, dest.x, dest.y):
			return {"success": false, "reason": "not_a_cliff"}
		delta = MovementSystem.elevation_delta(state.map, cur.x, cur.y, dest.x, dest.y)
		var higher: Vector2i = dest if delta > 0 else cur
		tn = _climb_tn_for_tile(state.map.get_tile(higher.x, higher.y))
	elif (ddx == 0 and abs(ddy) == 2) or (ddy == 0 and abs(ddx) == 2):
		# Two straight steps with a single wall between: scale over it. TN = wall material.
		var midx: int = cur.x + signi(ddx)
		var midy: int = cur.y + signi(ddy)
		var wall_tile: int = state.map.get_tile(midx, midy)
		if wall_tile != Enums.TileType.WALL_STONE and wall_tile != Enums.TileType.WALL_WOOD:
			return {"success": false, "reason": "not_a_scalable_wall"}
		is_wall_scale = true
		tn = _climb_tn_for_tile(wall_tile)
	else:
		return {"success": false, "reason": "invalid_climb_target"}

	ts.consume_complex()
	var res: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Athletics", tn, 0, "", Enums.Trait.STRENGTH)
	var climbed: bool = res.get("success", false)
	var fell: bool = false
	var fall_dmg: int = 0
	var direction: String

	if is_wall_scale:
		# Scaling a wall: success crosses to the far tile; failure stays put.
		direction = "over"
		if climbed:
			state.positions[char_id] = dest
	elif delta > 0:
		# Up: success relocates; failure stays put.
		direction = "up"
		if climbed:
			state.positions[char_id] = dest
	else:
		# Down: always ends at the lower tile; a failed climb slips and falls.
		direction = "down"
		state.positions[char_id] = dest
		if not climbed:
			fell = true
			fall_dmg = _apply_fall_damage(state, char_id, -delta, dice_engine)

	if state.positions[char_id] != cur:
		p.facing = Vector2i(signi(ddx), signi(ddy))
	state.combat_log.append({
		"type": "climb", "round": state.combat.round_number, "char_id": char_id,
		"from": cur, "to": state.positions[char_id], "direction": direction,
		"wall_scale": is_wall_scale, "tn": tn,
		"climbed": climbed, "fell": fell, "fall_damage": fall_dmg,
	})
	return {"success": true, "climbed": climbed, "direction": direction,
		"wall_scale": is_wall_scale, "tn": tn,
		"from": cur, "to": state.positions[char_id], "fell": fell, "fall_damage": fall_dmg}


## The stacked-floor level a combatant currently stands on (s4.4 Option B).
## ABSENT from the dict = level 0 (single-level skirmishes never populate it).
static func get_combatant_level(state: MapCombatState, char_id: int) -> int:
	return int(state.combatant_levels.get(char_id, 0))


## Climb a staircase/ladder to the floor it connects to (s4.4 Option B). A Simple
## Move action (you walk up built stairs — no Athletics roll, unlike a cliff). The
## combatant must stand on a STAIRS tile on their current level; they relocate to the
## same (x,y) on the destination level, where the landing tile must be passable and
## unoccupied by a combatant on THAT level.
static func execute_climb_stairs(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if ts == null or p == null:
		return {"success": false, "reason": "not_in_combat"}
	if IndividualCombat.CONDITION_ENTANGLED in p.conditions:
		return {"success": false, "reason": "entangled"}
	if ts.is_down_restricted(CharacterStats.get_wound_level(character)):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}
	var pos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if pos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	var cur_level: int = get_combatant_level(state, char_id)
	var here: int = state.map.get_tile_at(pos.x, pos.y, cur_level)
	if not AsciiMapData.is_stair(here):
		return {"success": false, "reason": "not_on_stairs"}
	var dest_level: int = state.map.stair_destination_level(pos.x, pos.y, cur_level)
	if dest_level < 0:
		return {"success": false, "reason": "no_destination_level"}
	var landing: int = state.map.get_tile_at(pos.x, pos.y, dest_level)
	if not MovementSystem.is_passable(landing):
		return {"success": false, "reason": "landing_blocked"}
	# Level-aware occupancy: someone already standing at this (x,y) on the dest level.
	for cid: int in state.positions:
		if cid != char_id and state.positions[cid] == pos \
				and get_combatant_level(state, cid) == dest_level:
			return {"success": false, "reason": "landing_occupied"}

	ts.consume_simple()
	state.combatant_levels[char_id] = dest_level
	var direction: String = "up" if dest_level > cur_level else "down"
	state.combat_log.append({
		"type": "climb_stairs", "round": state.combat.round_number, "char_id": char_id,
		"at": pos, "from_level": cur_level, "to_level": dest_level, "direction": direction,
	})
	return {"success": true, "direction": direction, "at": pos,
		"from_level": cur_level, "to_level": dest_level}


## Melee attack on target_id. Costs a Complex action.
## maneuver: "" / "increased_damage" / "disarm" / "feint" /
##           "knockdown_biped" / "knockdown_quad" /
##           "called_shot_limb" / "called_shot_hand" / "called_shot_head" /
##           "called_shot_small" / "extra_attack" / "guard"
# Victory of the River (s30a, multi_victory_river_armor_pierce). All values GDD-given.
const VOTR_SOURCE: String = "victory_of_the_river"
const VOTR_ARMOR_PENALTY: int = -10
const VOTR_DURATION_ROUNDS: int = 3

# Strength of the Spider (s30a, earth_spider_wound_debuff). All values GDD-given.
const SPIDER_SOURCE: String = "strength_of_the_spider"
const SPIDER_WOUND_THRESHOLD: int = 15
const SPIDER_ROLL_PENALTY: int = -3

## Strength of the Spider (s30a): once per Round, a strike dealing 15+ Wounds
## leaves the opponent at -3 to all rolls through their next Turn. Passive — fired
## from execute_melee_attack on a damaging hit; no AI/UI caller needed.
static func _apply_strength_of_the_spider(
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	t_p: IndividualCombat.Participant,
	wounds: int,
) -> void:
	if "Strength of the Spider" not in attacker.katas:
		return
	if wounds < SPIDER_WOUND_THRESHOLD:
		return
	if a_p.kata_used_this_round.has("earth_spider_wound_debuff"):
		return  # once per Round
	a_p.kata_used_this_round["earth_spider_wound_debuff"] = true
	# turn_end expiry: removed when the opponent's own next turn ends (see advance_turn).
	IndividualCombat.add_timed_modifier(t_p, "all_rolls", SPIDER_ROLL_PENALTY, 0, SPIDER_SOURCE, "turn_end")

## On a successful katana/daisho strike by a Victory of the River wielder, the
## target's Armor TN drops -10 vs all attacks AND the wielder's own Armor TN drops
## -10, both for 3 Rounds. "One opponent at a time": switching targets ends the
## prior target's debuff. Re-striking the same target refreshes the 3-round window.
## Passive — fired from execute_melee_attack on hit; no AI/UI caller needed.
static func _apply_victory_of_the_river(
	state: MapCombatState,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	t_p: IndividualCombat.Participant,
	target_id: int,
	weapon_name: String,
) -> void:
	if "Victory of the River" not in attacker.katas:
		return
	if weapon_name not in ["katana", "wakizashi"]:  # the daisho blades (s30a "Katana or daisho only")
		return
	# One opponent at a time: clear the prior target's debuff if switching.
	if a_p.votr_target_id >= 0 and a_p.votr_target_id != target_id:
		var old_t: IndividualCombat.Participant = state.combat.participants.get(a_p.votr_target_id, null)
		if old_t != null:
			IndividualCombat.clear_timed_modifiers_by_source(old_t, VOTR_SOURCE)
	a_p.votr_target_id = target_id
	var expires: int = state.combat.round_number + VOTR_DURATION_ROUNDS
	# Refresh (re-apply resets the window) the target debuff and the wielder's own debuff.
	IndividualCombat.clear_timed_modifiers_by_source(t_p, VOTR_SOURCE)
	IndividualCombat.add_timed_modifier(t_p, "armor_tn", VOTR_ARMOR_PENALTY, expires, VOTR_SOURCE)
	IndividualCombat.clear_timed_modifiers_by_source(a_p, VOTR_SOURCE)
	IndividualCombat.add_timed_modifier(a_p, "armor_tn", VOTR_ARMOR_PENALTY, expires, VOTR_SOURCE)


# The World Is Empty (s30a, multi_world_empty_void_attack). Activation cost =
# Simple Action (owner-set 2026-06-12). All other values GDD-given.
const WIE_SOURCE: String = "the_world_is_empty"

## Activate The World Is Empty: a Simple action that grants +Xk0 to Kenjutsu/
## Iaijutsu attack rolls (X = current Void Points, frozen at activation) for X
## Rounds; 1 Void Point is lost when it ends (handled in advance_round). Requires
## the kata known and at least 1 Void Point; not re-activatable while active.
static func execute_activate_world_is_empty(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}
	if "The World Is Empty" not in character.katas:
		return {"success": false, "reason": "kata_not_known"}
	if IndividualCombat.has_timed_modifier_source(p, WIE_SOURCE):
		return {"success": false, "reason": "already_active"}
	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_action"}
	var x: int = character.current_void_points
	if x < 1:
		return {"success": false, "reason": "no_void_points"}
	ts.consume_simple()
	var expires: int = state.combat.round_number + x  # active X Rounds (round R .. R+X-1)
	IndividualCombat.add_timed_modifier(p, "attack_rolled", x, expires, WIE_SOURCE, "round")
	state.combat_log.append({
		"type": "kata_world_is_empty", "char_id": char_id,
		"bonus": x, "expires_round": expires, "round": state.combat.round_number})
	return {"success": true, "kata": "The World Is Empty", "bonus": x, "expires_round": expires}


## Deduct 1 Void Point from a participant whose The World Is Empty modifier is
## ending this round (s30a "lose 1 Void Point when it ends"). Called in
## advance_round just before the round-based expiry sweep removes the modifier.
static func _process_world_is_empty_expiry(
	state: MapCombatState,
	p: IndividualCombat.Participant,
	chars_by_id: Dictionary,
) -> void:
	for m: Dictionary in p.timed_modifiers:
		if m.get("source", "") != WIE_SOURCE:
			continue
		if m.get("expiry_kind", "round") != "round":
			continue
		if int(m.get("expires_round", 0)) <= state.combat.round_number:
			var c: L5RCharacterData = chars_by_id.get(p.character_id, null)
			if c != null and not CharacterStats.is_dead(c):
				c.current_void_points = maxi(0, c.current_void_points - 1)


# Standing on the Heavens (s30a, multi_standing_heavens_void_reroll). GDD-given.
const SOH_USED_KEY: String = "multi_standing_heavens_void_reroll"

## Standing on the Heavens (s30a) defender reaction: once per Round, when struck,
## the defender may spend 1 Void Point (Free Action) to force the attacker to
## reroll the attack. NPC-only auto-use (a defensive reflex when a VP is available);
## a PC defender chooses via the future turn-based reaction UI, so PCs are skipped.
## Returns {rerolled, result} when the reroll fires, else {}.
static func _maybe_standing_on_heavens(
	defender: L5RCharacterData,
	t_p: IndividualCombat.Participant,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	weapon_name: String,
	armor_tn: int,
	raises: int,
	maneuver: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	if defender.is_pc:
		return {}  # PC reactions are an explicit UI choice, not auto-spent
	if "Standing on the Heavens" not in defender.katas:
		return {}
	if t_p.kata_used_this_round.has(SOH_USED_KEY):
		return {}  # once per Round
	if not VoidSystem.can_spend(defender):
		return {}
	VoidSystem.spend(defender)  # Free Action; spends 1 Void Point
	t_p.kata_used_this_round[SOH_USED_KEY] = true
	var new_result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, raises, dice_engine,
		false, false, false, maneuver, {"opponent_clan": defender.clan}
	)
	return {"rerolled": true, "result": new_result}


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
	bonus_attack: bool = false,
	charge_atk_bonus: int = 0,
	charge_dmg_bonus: int = 0,
	as_simple: bool = false,
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	# s54.10: an invisible/intangible target cannot be struck (Mujina / Ephemeral Form).
	if not _is_targetable(state, target_id):
		return {"success": false, "reason": "target_hidden"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	# s33 Essence of Air: an insubstantial caster cannot interact with physical objects (no attack).
	var a_p_ins: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	if a_p_ins != null and IndividualCombat.get_timed_modifier_total(a_p_ins, "insubstantial") > 0:
		return {"success": false, "reason": "insubstantial"}
	# s35 Wings of Fire: the caster's arms control the wings — no weapon/unarmed attacks.
	if _arms_occupied(state, attacker_id):
		return {"success": false, "reason": "arms_occupied"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		# Down: only free actions + must spend Void (GDD s40).
		return _execute_down_attack(state, attacker_id, target_id, attacker, target, weapon_name, dice_engine)

	# Special maneuver: Guard (Simple Action, GDD s40 — resolved by execute_guard).
	if maneuver == "guard":
		return execute_guard(state, attacker_id, target_id, attacker, target)

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	# Disarmed (s40): the attacker's weapon is on the ground — they swing unarmed until
	# they recover it (execute_recover_weapon), regardless of the weapon the caller passed.
	if a_p.disarmed and weapon_name != "" and weapon_name != "unarmed":
		weapon_name = "unarmed"

	# Dance of the Flames (s38 Fire): unarmed attacks cost a Simple Action, not Complex.
	# Simple-cost attack: Dance of the Flames (unarmed kiho) OR a Simple-economy Charge (s54.5).
	var dance_simple: bool = as_simple or ((weapon_name == "" or weapon_name == "unarmed") and "Dance of the Flames" in a_p.active_kiho)
	# bonus_attack (GDD s54.5 multi-attack second strike, like an off-hand attack): a free
	# extra attack that neither requires nor consumes an action.
	# s36 Stand Against the Waves: a granted_attacks pool lets an attack proceed when the normal
	# action budget is spent (consumes one granted attack instead).
	var using_granted_attack: bool = false
	if not bonus_attack:
		if dance_simple:
			if not ts.can_use_simple():
				if ts.granted_attacks > 0:
					using_granted_attack = true
				else:
					return {"success": false, "reason": "no_simple_actions_remaining"}
		elif not ts.can_use_complex():
			if ts.granted_attacks > 0:
				using_granted_attack = true
			else:
				return {"success": false, "reason": "no_complex_actions_remaining"}

	# Defense/Full Defense stances prohibit attacking entirely (s40) — this is an
	# action-legality check, independent of position, so it precedes the range check.
	if a_p.stance == Enums.Stance.DEFENSE or a_p.stance == Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "defense_cannot_attack"}

	# Range check.
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	# Strike Through the Wind (s38 Air): unarmed melee attacks reach School Rank ×25 ft
	# (= ×5 tiles) by transmitting force through the air, while the kiho is active.
	var melee_range: int = MELEE_RANGE_TILES
	if (weapon_name == "" or weapon_name == "unarmed") and "Strike Through the Wind" in a_p.active_kiho:
		melee_range = maxi(MELEE_RANGE_TILES, CharacterStats.get_insight_rank(attacker) * 5)
	if _chebyshev(apos, tpos) > melee_range:
		return {"success": false, "reason": "out_of_melee_range"}

	# Way of Deception (s33 Air): the defender's illusory duplicate mirrors them perfectly — the
	# enemy can't tell which is real, so an attack has a derived 50% chance (1 real + 1 identical
	# duplicate) to strike the fake and accomplish nothing. The attacker's action is still spent.
	if IndividualCombat.get_timed_modifier_total(t_p, "decoy_absorb") > 0 and dice_engine.randf() < 0.5:
		return {"success": true, "hit": false, "hit_decoy": true,
			"attacker_id": attacker_id, "target_id": target_id}

	# Way of the Willow (s38 Air): the defender may spend a Void Point to interrupt the
	# declared attack with an immediate unarmed counterattack (once per Round). If the
	# counter kills the attacker, the original attack is aborted.
	if _maybe_way_of_the_willow(state, target, t_p, attacker, a_p, dice_engine):
		return {"success": true, "interrupted_by_way_of_the_willow": true, "attacker_dead": true}

	# Shadowed Mountain (s38 Earth): a defender with it active may immediately enter Full
	# Defense Stance just before being attacked (once per activation) — raising this
	# attack's Armor TN. The stance change is sticky (they remain in Full Defense).
	if "Shadowed Mountain" in t_p.active_kiho and not t_p.shadowed_mountain_used \
			and t_p.stance != Enums.Stance.FULL_DEFENSE:
		t_p.stance = Enums.Stance.FULL_DEFENSE
		t_p.shadowed_mountain_used = true

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, is_being_guarded, weapon_name)
	armor_tn += _cover_bonus(state, tpos, apos)

	# s54.10 Toshigoku auras + Ancient General Tactical Mastery: set the spirit
	# attacker's per-attack rolled-die bonuses (always reset to the freshly-computed
	# value so nothing lingers; 0 for non-spirits).
	_set_spirit_attack_auras(state, attacker, a_p, target_id)
	# Charge bonus (s54.5 Goring Charge / Diving Attack): +NkN, stacks on any aura bonus.
	a_p.spirit_attack_rolled_bonus += charge_atk_bonus
	a_p.spirit_attack_kept_bonus += charge_atk_bonus
	a_p.spirit_damage_rolled_bonus += charge_dmg_bonus
	a_p.spirit_damage_kept_bonus += charge_dmg_bonus
	# s54.10: a hidden creature (Mujina / Ephemeral Form) that attacks reveals itself —
	# it is targetable through its next turn.
	_reveal_if_hidden(state, attacker_id, a_p)

	# Relentless Heat (s35 Fire): any opponent who attempts to strike the warded wearer (hit or
	# miss) is Fatigued until their next Turn, and a Full Attack attacker drops to Attack Stance.
	if IndividualCombat.get_timed_modifier_total(t_p, "relentless_heat") > 0:
		IndividualCombat.apply_timed_condition(a_p, IndividualCombat.CONDITION_FATIGUED,
			state.combat.round_number + 1)
		if a_p.stance == Enums.Stance.FULL_ATTACK:
			a_p.stance = Enums.Stance.ATTACK

	# s36 Strike of the Flowing Waters: a buffed attacker ignores the target's worn-armor Armor TN
	# (and an extra -5 vs non-human creatures). Does NOT negate Reduction or Defense-stance bonuses.
	if IndividualCombat.get_timed_modifier_total(a_p, "armor_bypass") > 0:
		armor_tn -= target.armor_tn_bonus
		if target.spirit_creature != null:
			armor_tn -= 5
		armor_tn = maxi(5, armor_tn)
	# s33 Castle of Air: a defender's attacker_penalty buff imposes a -Xk0 attack-roll penalty.
	# s33 Blessed Wind of Lady Sun: a modifier zone penalizes hostile actions made from inside it.
	# s4.4 Z-axis: an attacker on high ground adds +1k0 (a positive value adds rolled dice).
	var atk_pen: int = IndividualCombat.get_timed_modifier_total(t_p, "attacker_penalty") \
		+ _zone_modifier_total(state, attacker_id, "attack_roll_penalty") \
		+ _high_ground_attack_bonus(state, apos, tpos)
	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, raises, dice_engine,
		false, spend_void, false, maneuver,
		{"opponent_clan": target.clan}, atk_pen
	)

	# Reversal of Fortunes (s36): a buffed attacker may re-roll a missed attack once per
	# round, keeping the better result.
	var reversal_rerolled: bool = false
	if not result.get("hit", false) \
			and IndividualCombat.get_timed_modifier_total(a_p, "reroll") > 0 \
			and a_p.reversal_used_round != state.combat.round_number:
		a_p.reversal_used_round = state.combat.round_number
		var rr: Dictionary = IndividualCombat.resolve_attack(
			attacker, a_p, weapon_name, armor_tn, raises, dice_engine,
			false, spend_void, false, maneuver, {"opponent_clan": target.clan}, atk_pen)
		# Keep the better result (a hit wins; otherwise the higher roll).
		if rr.get("hit", false) or int(rr.get("roll", 0)) > int(result.get("roll", 0)):
			result = rr
		reversal_rerolled = true

	# Standing on the Heavens (s30a) defender reaction: a struck defender may force
	# a reroll of the attack (spends 1 VP). The reroll's outcome replaces the original.
	var soh_rerolled: bool = false
	if result.get("hit", false):
		var soh: Dictionary = _maybe_standing_on_heavens(
			target, t_p, attacker, a_p, weapon_name, armor_tn, raises, maneuver, dice_engine)
		if soh.get("rerolled", false):
			result = soh["result"]
			soh_rerolled = true

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
	if soh_rerolled:
		log_entry["standing_heavens_reroll"] = true
	if reversal_rerolled:
		log_entry["reversal_reroll"] = true

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, raises, maneuver, result, dice_engine)
		log_entry["damage"] = dmg_result.get("damage", 0)
		log_entry["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)
		result["target_wound_level"] = CharacterStats.get_wound_level(target)

		# Victory of the River (s30a): a landed katana/daisho strike drops the
		# target's (and the wielder's own) Armor TN -10 for 3 Rounds.
		_apply_victory_of_the_river(state, attacker, a_p, t_p, target_id, weapon_name)

		# The Body is an Anvil (s38 Fire): a landed unarmed strike burns whoever touches
		# the anvil-caster — Fire Ring contact Wounds in either direction.
		_apply_body_is_anvil(attacker, a_p, target, t_p, weapon_name)

		# Burning Blood (s54.5 Furu): a melee attacker who wounds the oni rolls Reflexes
		# (Defense) vs its TN or is splattered for the oni's burning-blood damage.
		if int(dmg_result.get("wounds", 0)) > 0:
			_apply_burning_blood(attacker, target, weapon_name, dice_engine)

		# Swallow Whole / Devour (s54.5): a wounding melee hit by a swallow creature wins a
		# Contested Strength to engulf the victim (per-round damage applied in advance_round).
		if int(dmg_result.get("wounds", 0)) > 0:
			_apply_swallow_whole(state, attacker, attacker_id, target, target_id, weapon_name, dice_engine)

		# Suffocation (s54.5 Quiet Death): a melee hit by a suffocation creature attempts a
		# Grapple (8k4 to initiate); on control the victim takes escalating crush damage
		# (3k3, +1k1 each Round) applied in advance_round, reusing the swallow grapple state.
		_apply_suffocation(state, attacker, attacker_id, target, target_id, weapon_name, dice_engine)

		# Wreathed in Flames (s54.5 Daku): striking the burning oni in melee automatically
		# burns the attacker by weapon size (no save).
		_apply_wreathed_in_flames(attacker, target, weapon_name, dice_engine)

		# Fires of Purity (s35 Fire): flame shroud. A shrouded DEFENDER burns its melee
		# attacker (2k2); a shrouded ATTACKER's melee hit burns the target for an extra 2k2.
		_apply_fires_of_purity(attacker, a_p, target, t_p, weapon_name, dice_engine)
		# Shining Light (s35 Fire): a warded DEFENDER's armor flares when struck in melee —
		# the attacker takes 2k2 and is Blinded. No effect on ranged attacks.
		_apply_shining_light(attacker, a_p, t_p, weapon_name, dice_engine)

		# Abominable Stench (s54.11 Nuppeppo): struck by an armed melee weapon → every living
		# mortal within 20' (4 tiles) rolls Stamina TN 20 or is Fatigued.
		_apply_abominable_stench(state, target, weapon_name, dice_engine)

		# Splatter (s54.5 Byoki): a wounding melee blow against the plague-oni splashes its
		# contagion onto a mortal attacker, who risks the creature's disease (reuses the
		# disease-contraction roll with attacker and creature roles swapped).
		if int(dmg_result.get("wounds", 0)) > 0 and attacker.spirit_creature == null \
				and target.spirit_creature != null and target.spirit_creature.has_tag("splatter"):
			_apply_disease_on_hit(target, attacker, int(dmg_result.get("wounds", 0)), dice_engine)

		# Burning Touch (s54.12 Taki-bi etc.): touching a burning-touch creature in melee
		# sets the toucher on fire ("touches or is touched"). The attack-side direction is
		# handled in _apply_hit; this is the strike-it-in-melee direction.
		if target.spirit_creature != null and target.spirit_creature.has_tag("burning_touch") \
				and a_p != null and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
			a_p.on_fire = true

		# Demon Silk (s54.5 Shikage): a creature who touches the web-covered oni in melee is
		# instantly Entangled (escape TN simplified to the standard 20).
		if target.spirit_creature != null and target.spirit_creature.has_tag("demon_silk") \
				and a_p != null and attacker.spirit_creature == null \
				and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
			IndividualCombat.apply_condition(a_p, IndividualCombat.CONDITION_ENTANGLED)

		# Destiny's Strike (s38 Fire): a struck defender with it active immediately makes
		# a single unarmed counterattack (once per Round).
		_maybe_destiny_strike(state, target, t_p, attacker, a_p, dice_engine)

		# Strength of the Spider (s30a): dealing 15+ Wounds (once/Round) gives the
		# opponent -3 to all rolls during their next Turn.
		_apply_strength_of_the_spider(attacker, a_p, t_p, dmg_result.get("wounds", 0))

		# Knockdown maneuver: contested Strength if hit.
		if maneuver in ["knockdown_biped", "knockdown_quad"]:
			# s34 The Mountain's Feet: defender's knockdown_resist buff adds extra rolled/kept dice.
			var kdr_r: int = IndividualCombat.get_timed_modifier_total(t_p, "knockdown_resist_rolled")
			var kdr_k: int = IndividualCombat.get_timed_modifier_total(t_p, "knockdown_resist_kept")
			var kd: Dictionary = IndividualCombat.resolve_knockdown(
				attacker, target, maneuver == "knockdown_quad", dice_engine, 0, kdr_r, kdr_k
			)
			# Root the Mountain (s38 Earth): forcing the caster to move requires the
			# attacker to also win a Contested Earth Roll, or the knockdown is negated.
			if kd["knocked_down"] and _root_the_mountain_resists(target, t_p, attacker, dice_engine):
				kd["knocked_down"] = false
				result["root_the_mountain_resisted"] = true
			if kd["knocked_down"]:
				IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_PRONE)
			result["knocked_down"] = kd["knocked_down"]
			log_entry["knocked_down"] = kd["knocked_down"]

		# Disarm maneuver (s40, 3 Raises; banked Free Raises reduce the requirement). On a
		# won Contested Strength the target's weapon hits the ground (persistent disarmed
		# state — they fight unarmed until they recover it).
		if maneuver == "disarm":
			# Consume any Free Raises banked toward a Disarm against this target
			# (s40 weapon-grapple lose-control risk / Earthen Fist).
			var disarm_free: int = a_p.disarm_free_raises_pending
			if a_p.disarm_free_raises_pending > 0:
				result["disarm_free_raises_used"] = a_p.disarm_free_raises_pending
				a_p.disarm_free_raises_pending = 0
			if raises + disarm_free >= DISARM_RAISES:
				var dr: Dictionary = IndividualCombat.resolve_disarm(attacker, target, dice_engine, weapon_name, a_p)
				result["disarmed"] = dr["disarmed"]
				log_entry["disarmed"] = dr["disarmed"]
				if dr["disarmed"] and t_p != null:
					t_p.disarmed = true
			else:
				result["disarm_insufficient_raises"] = true

	# Earthen Fist (s38 Earth): if an opponent's melee attack against the caster MISSES,
	# the caster (who must be in Defense/Full Defense) may attempt a Disarm next Turn for
	# no Raises — armed here via the existing disarm_free_raises_pending track.
	if not result.get("hit", false) and "Earthen Fist" in t_p.active_kiho \
			and (t_p.stance == Enums.Stance.DEFENSE or t_p.stance == Enums.Stance.FULL_DEFENSE):
		t_p.disarm_free_raises_pending = 3
		result["earthen_fist_disarm_armed"] = true

	# Bishamon's Grasp (s38): record this attacker on the defender (who attacked me since
	# my last Turn) so the defender can free-grapple them on their Turn.
	if "Bishamon's Grasp" in t_p.active_kiho and attacker_id not in t_p.attacked_by_ids:
		t_p.attacked_by_ids.append(attacker_id)

	# Clear the spirit aura/tactical bonuses so they never leak to a later attack
	# (e.g. an extra-attack or off-hand strike this turn that does not recompute them).
	a_p.spirit_attack_rolled_bonus = 0
	a_p.spirit_damage_rolled_bonus = 0
	a_p.spirit_attack_kept_bonus = 0
	a_p.spirit_damage_kept_bonus = 0

	if not bonus_attack:
		if using_granted_attack:
			ts.granted_attacks -= 1
		elif dance_simple:
			ts.consume_simple()
		else:
			ts.consume_complex()
	state.combat_log.append(log_entry)
	_check_and_mark_over(state, target_id, target)
	return result


## Ranged attack on target_id. Costs a Complex action.
## Deliver an atemi kiho strike (s38): an unarmed Complex-action attack against an
## adjacent target that, on a hit, applies the kiho's atemi_effect (an instant
## condition or a timed modifier) instead of normal damage. Monk-only (only monks
## hold kiho). The roll, doubled atemi Armor TN, optional contest, and effect
## application live in IndividualCombat.resolve_atemi_strike.
static func execute_atemi_strike(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	kiho_name: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}
	if not attacker.kiho.has(kiho_name):
		return {"success": false, "reason": "kiho_not_known"}
	if not KihoSystem.KIHO_DATA.get(kiho_name, {}).get("atemi", false):
		return {"success": false, "reason": "not_atemi"}
	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	if a_p.stance == Enums.Stance.DEFENSE or a_p.stance == Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "defense_cannot_attack"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	# Orchestrator-level atemi targeting gates (s38). As the Breakers: may only target
	# an opponent who has not yet acted this Round, and at most once per skirmish.
	var aspec: Dictionary = KihoSystem.KIHO_DATA.get(kiho_name, {}).get("atemi_effect", {})
	# Chi Protection cannot be used on oneself.
	if attacker_id == target_id and aspec.get("ally_auto_hit", false):
		return {"success": false, "reason": "cannot_target_self"}
	# A willing ally (same faction) does not resist a heal-atemi → auto-hit.
	var auto_hit: bool = aspec.get("ally_auto_hit", false) and state.factions.get(attacker_id, "") == state.factions.get(target_id, "")
	if aspec.get("requires_target_not_acted", false):
		var tts0: TurnState = state.turn_states.get(target_id, null)
		if tts0 != null and (tts0.complex_used or tts0.simple_used > 0 or tts0.free_actions_used > 0):
			return {"success": false, "reason": "target_already_acted"}
	if aspec.get("once_per_skirmish", false):
		if target_id in state.once_per_skirmish_atemi.get(kiho_name, []):
			return {"success": false, "reason": "already_affected_this_skirmish"}

	var r: Dictionary = IndividualCombat.resolve_atemi_strike(
		attacker, a_p, target, t_p, kiho_name, dice_engine, state.combat.round_number, auto_hit)
	# If the atemi could not be delivered (e.g. insufficient Void for the activation
	# cost), do not consume the action — the actor can still take a normal attack.
	if not r.get("ok", false):
		r["success"] = false
		return r
	ts.consume_complex()
	# Orchestrator-applied effect: deny the target one Simple Action this Round
	# (As the Breakers). Marks the target affected for the once-per-skirmish gate.
	if r.get("hit", false) and aspec.get("remove_simple_action", false):
		var tts: TurnState = state.turn_states.get(target_id, null)
		if tts != null:
			tts.simple_used += 1
		if aspec.get("once_per_skirmish", false):
			if not state.once_per_skirmish_atemi.has(kiho_name):
				state.once_per_skirmish_atemi[kiho_name] = []
			state.once_per_skirmish_atemi[kiho_name].append(target_id)
		r["simple_action_removed"] = true
	# Banish All Shadows (s38 Void 4): on a hit, the willing-ally target ignores their
	# highest-point non-Spiritual/non-Social Disadvantage for caster Void Ring Rounds.
	if r.get("hit", false) and aspec.get("suppress_disadvantage", false):
		var hd: DisadvantageData = AdvantageSystem.get_highest_non_spiritual_social_disadvantage(target)
		if hd != null:
			target.suppressed_disadvantage_type = int(hd.disadvantage_type)
			t_p.suppressed_disadvantage_expiry = state.combat.round_number + CharacterStats.get_ring_value(attacker, Enums.Ring.VOID)
			r["suppressed_disadvantage"] = int(hd.disadvantage_type)
		else:
			r["no_suppressable_disadvantage"] = true
	# Sense the Balance (s38 Void 6): on a hit, spend a Void Point to learn the count of
	# the target's Spiritual Advantages OR Disadvantages (caster's choice; metadata
	# sense_choice, NPC default "disadvantage"). On a won Contested Void Roll, also learn
	# the highest-point not-yet-revealed one; repeat uses reveal more until all known.
	if r.get("hit", false) and aspec.get("sense_balance", false):
		if attacker.current_void_points < 1:
			r["sense_no_void"] = true
		else:
			attacker.current_void_points -= 1
			# "caster's choice" of Advantages OR Disadvantages: default Disadvantages
			# (the threat-relevant one). A PC-facing choice param can override later.
			var choice: String = "disadvantage"
			r["sense_choice"] = choice
			r["spiritual_count"] = AdvantageSystem.count_spiritual_advantages(target) if choice == "advantage" else AdvantageSystem.count_spiritual_disadvantages(target)
			var skey: String = "%d:%d" % [attacker_id, target_id]
			var known: Array = state.sense_known.get(skey, [])
			var av: int = CharacterStats.get_ring_value(attacker, Enums.Ring.VOID)
			var tv: int = CharacterStats.get_ring_value(target, Enums.Ring.VOID)
			if dice_engine.roll_and_keep(maxi(1, av), maxi(1, av), true).total >= dice_engine.roll_and_keep(maxi(1, tv), maxi(1, tv), true).total:
				var revealed: int = AdvantageSystem.get_highest_spiritual_advantage(target, known) if choice == "advantage" else AdvantageSystem.get_highest_spiritual_disadvantage(target, known)
				if revealed >= 0:
					known.append(revealed)
					state.sense_known[skey] = known
					r["revealed_type"] = revealed
	# Spin the Kharmic Wheel (s38 Void 8): expend ALL Void Points; the target loses one
	# random Social/Spiritual/Mental Disadvantage and gains a new random one of equal
	# point value (a permanent character change).
	if r.get("hit", false) and aspec.get("spin_kharmic", false):
		if attacker.current_void_points < 1:
			r["spin_no_void"] = true
		else:
			attacker.current_void_points = 0  # expend all remaining
			var swappable: Array = AdvantageSystem.get_swappable_disadvantages(target)
			if swappable.is_empty():
				r["no_swappable_disadvantage"] = true
			else:
				var old_dis: DisadvantageData = swappable[clampi(int(dice_engine.randf() * swappable.size()), 0, swappable.size() - 1)]
				var pts: int = AdvantageSystem.get_disadvantage_points(old_dis)
				var exclude: Array = []
				for d: DisadvantageData in target.disadvantages:
					exclude.append(int(d.disadvantage_type))
				var new_type: int = AdvantageSystem.pick_equal_value_disadvantage(pts, exclude, dice_engine.randf())
				if new_type < 0:
					r["no_equal_value_replacement"] = true
				else:
					target.disadvantages.erase(old_dis)
					var nd := DisadvantageData.new()
					nd.disadvantage_type = new_type
					nd.rank = 1
					target.disadvantages.append(nd)
					r["spin_removed"] = int(old_dis.disadvantage_type)
					r["spin_gained"] = new_type
	# Death Touch (s38 Void 7): 3 atemi strikes on 3 consecutive Rounds, then a Void
	# Point after the 3rd, stamps a delayed affliction (resolved by the world-sim at
	# the next daily tick — ring drain → catatonic → 3 Contested Void → death).
	if aspec.get("death_touch", false):
		var dkey: String = "%d:%d" % [attacker_id, target_id]
		if not r.get("hit", false):
			state.death_touch_chains.erase(dkey)  # a miss breaks the consecutive chain
		else:
			var prev: Dictionary = state.death_touch_chains.get(dkey, {})
			var cnt: int = 1
			if not prev.is_empty() and int(prev.get("last_round", -99)) == state.combat.round_number - 1:
				cnt = int(prev.get("count", 0)) + 1
			state.death_touch_chains[dkey] = {"count": cnt, "last_round": state.combat.round_number}
			r["death_touch_count"] = cnt
			if cnt >= 3:
				if attacker.current_void_points >= 1:
					attacker.current_void_points -= 1
					target.death_touch_affliction = {
						"caster_id": attacker_id,
						"insight_cap": attacker.insight_rank,
						"caster_void": CharacterStats.get_ring_value(attacker, Enums.Ring.VOID),
					}
					r["death_touch_applied"] = true
				else:
					r["death_touch_no_void"] = true
				state.death_touch_chains.erase(dkey)  # sequence resolved (sealed or failed)
	state.combat_log.append({
		"type": "atemi_strike", "round": state.combat.round_number,
		"attacker_id": attacker_id, "target_id": target_id, "kiho": kiho_name,
		"hit": r.get("hit", false), "effect_applied": r.get("effect_applied", false)})
	r["success"] = r.get("ok", false)
	return r


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
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	# s54.10: an invisible/intangible target cannot be shot (Mujina / Ephemeral Form).
	if not _is_targetable(state, target_id):
		return {"success": false, "reason": "target_hidden"}
	# s33 Essence of Air: an insubstantial caster cannot interact with physical objects (no attack).
	var a_p_ins: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	if a_p_ins != null and IndividualCombat.get_timed_modifier_total(a_p_ins, "insubstantial") > 0:
		return {"success": false, "reason": "insubstantial"}
	# s35 Wings of Fire: the caster's arms control the wings — no weapon/unarmed attacks.
	if _arms_occupied(state, attacker_id):
		return {"success": false, "reason": "arms_occupied"}

	# s36 Stand Against the Waves: a granted_attacks pool lets a ranged attack proceed when the
	# normal Complex is spent (consumes one granted attack instead).
	var using_granted_ranged: bool = false
	if not ts.can_use_complex():
		if ts.granted_attacks > 0:
			using_granted_ranged = true
		else:
			return {"success": false, "reason": "no_complex_actions_remaining"}

	# LOS check.
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if not _has_los(state.map, apos, tpos):
		return {"success": false, "reason": "no_line_of_sight"}
	# s33 Summon Fog: a fog cloud crossing the line of fire blocks the shot beyond 5 ft.
	if _ray_blocked_by_fog(state, apos, tpos):
		return {"success": false, "reason": "fog_blocks_los"}

	# Weapon must be ranged.
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	if wp.get("melee", true):
		return {"success": false, "reason": "weapon_is_melee"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	if a_p.stance == Enums.Stance.DEFENSE or a_p.stance == Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "defense_cannot_attack"}
	if a_p.stance == Enums.Stance.FULL_ATTACK:
		return {"success": false, "reason": "full_attack_cannot_ranged_attack"}

	# s54.10: a hidden attacker (Mujina / Ephemeral Form) reveals itself when it shoots.
	_reveal_if_hidden(state, attacker_id, a_p)

	# Way of Deception (s33 Air): a derived 50% chance the shot strikes the defender's illusory
	# duplicate (no effect); the attacker's action is still spent.
	if IndividualCombat.get_timed_modifier_total(t_p, "decoy_absorb") > 0 and dice_engine.randf() < 0.5:
		return {"success": true, "hit": false, "hit_decoy": true,
			"attacker_id": attacker_id, "target_id": target_id}

	# -10 penalty if attacker is within melee range of any enemy (GDD s40).
	var in_melee: bool = is_in_melee_range_of_enemy(state, attacker_id)

	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, false, is_being_guarded, weapon_name)
	armor_tn += _cover_bonus(state, tpos, apos)
	# s33 Blessed Wind: +Armor TN vs non-magical ranged attacks only (ranged path).
	# s33 Summoning the Gale: a target inside an anti-ranged zone is harder to shoot (+15 Armor TN).
	armor_tn += IndividualCombat.get_timed_modifier_total(t_p, "ranged_armor_tn") \
		+ _zone_modifier_total(state, target_id, "ranged_armor_tn")
	# s36 Strike of the Flowing Waters: a buffed attacker ignores the target's worn-armor Armor TN
	# (and an extra -5 vs non-human creatures). Does NOT negate Reduction or Defense-stance bonuses.
	if IndividualCombat.get_timed_modifier_total(a_p, "armor_bypass") > 0:
		armor_tn -= target.armor_tn_bonus
		if target.spirit_creature != null:
			armor_tn -= 5
		armor_tn = maxi(5, armor_tn)

	# s33 Arrow's Flight: a guided bow shot unerringly strikes (Kyujutsu only) and "cannot benefit
	# from Raises or Techniques" — so this shot uses 0 Raises and its hit is forced. One-shot: the
	# modifier is cleared after firing. (Passive kata damage still applies — a minor limitation.)
	var auto_hit: bool = String(wp.get("skill", "")) == "Kyujutsu" \
		and IndividualCombat.get_timed_modifier_total(a_p, "ranged_auto_hit") > 0
	var shot_raises: int = 0 if auto_hit else raises
	# s33 Castle of Air: a defender's attacker_penalty buff imposes a -Xk0 attack-roll penalty.
	# s33 Blessed Wind of Lady Sun (hostile -1k0) + Summoning the Gale (ranged -3k0 from inside the
	# bubble; the -3 KEPT half is not modeled) penalize a shot fired from within a modifier zone.
	var atk_pen: int = IndividualCombat.get_timed_modifier_total(t_p, "attacker_penalty") \
		+ _zone_modifier_total(state, attacker_id, "attack_roll_penalty") \
		+ _zone_modifier_total(state, attacker_id, "ranged_attack_penalty") \
		+ _high_ground_attack_bonus(state, apos, tpos)
	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, weapon_name, armor_tn, shot_raises, dice_engine,
		in_melee, spend_void, false, "",
		{"opponent_clan": target.clan}, atk_pen
	)
	if auto_hit:
		result["hit"] = true
		result["auto_hit"] = true
		IndividualCombat.clear_timed_modifiers_by_source(a_p, "spell_arrows_flight")

	var log_entry: Dictionary = {
		"type": "ranged_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon": weapon_name,
		"raises": shot_raises,
		"hit": result.get("hit", false),
		"roll": result.get("roll", 0),
		"target_tn": armor_tn,
		"in_melee_penalty": in_melee,
	}

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, weapon_name, shot_raises, "", result, dice_engine)
		log_entry["damage"] = dmg_result.get("damage", 0)
		log_entry["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)
		result["target_wound_level"] = CharacterStats.get_wound_level(target)

	if using_granted_ranged:
		ts.granted_attacks -= 1
	else:
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
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
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


## Off-hand attack (s40 "Off-Hand Weapons & Multiple Attacks"). A dual-wielder
## may make one additional attack per turn with their off-hand weapon, at the
## off-hand size penalty (Small -5 / Medium -10 / Large -15). The main attack
## already carries the -5 dominant-hand penalty (resolve_attack) and the two-
## weapon +Insight Armor TN bonus (get_armor_tn) while dual_wielding is set.
static func execute_off_hand_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
	spend_void: bool = false,
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	if not a_p.dual_wielding or a_p.off_hand_weapon == "":
		return {"success": false, "reason": "not_dual_wielding"}
	if a_p.off_hand_attack_used_this_turn:
		return {"success": false, "reason": "off_hand_already_used"}

	var wl: int = CharacterStats.get_wound_level(attacker)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}

	# Defense / Full Defense stances may not attack (s40), same as the main attack.
	if a_p.stance == Enums.Stance.DEFENSE or a_p.stance == Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "defense_cannot_attack"}

	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}

	var off_weapon: String = a_p.off_hand_weapon
	var is_being_guarded: bool = _is_being_guarded(state, target_id)
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, is_being_guarded, off_weapon)

	var result: Dictionary = IndividualCombat.resolve_off_hand_attack(
		attacker, a_p, off_weapon, armor_tn, dice_engine, spend_void, {"opponent_clan": target.clan}
	)
	a_p.off_hand_attack_used_this_turn = true

	if result.get("hit", false):
		var dmg_result: Dictionary = _apply_hit(state, attacker, a_p, target, off_weapon, 0, "", result, dice_engine)
		result["damage"] = dmg_result.get("damage", 0)
		result["wounds_inflicted"] = dmg_result.get("wounds", 0)
		result["target_dead"] = dmg_result.get("dead", false)

	if not result.has("reason"):
		result["success"] = true
	state.combat_log.append({
		"type": "off_hand_attack",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon": off_weapon,
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
	if CharacterStats.is_dead(guardian):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(guardian_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}

	var g_p: IndividualCombat.Participant = state.combat.participants.get(guardian_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if g_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}

	if g_p.stance == Enums.Stance.FULL_ATTACK:
		return {"success": false, "reason": "full_attack_cannot_guard"}

	# Guard is a Simple Action (GDD s40).
	var wl: int = CharacterStats.get_wound_level(guardian)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}

	# Must be within 5 feet (1 tile) (GDD s40).
	var gpos: Vector2i = state.positions.get(guardian_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if _chebyshev(gpos, tpos) > GUARD_RANGE_TILES:
		return {"success": false, "reason": "target_too_far"}

	IndividualCombat.resolve_guard(g_p, target_id, guardian, t_p)
	ts.consume_simple()

	state.combat_log.append({
		"type": "guard",
		"round": state.combat.round_number,
		"guardian_id": guardian_id,
		"target_id": target_id,
	})
	return {"success": true}


## Grapple initiation: Jiujutsu/Agility vs target Armor TN (GDD s40).
## Costs a Complex action.
## Initiate a grapple. Costs a Complex action. weapon_name "" = ordinary Jiujutsu
## grapple; a chain weapon / grapple-capable polearm initiates with the Weapon
## Skill instead (s40 "Weapon Grapples"): control rolls then use that skill and
## Hit deals weapon damage. The lose-control penalty (opponent banks 2 Free Raises
## toward Disarm) is applied in execute_grapple_action's take_control path.
static func execute_grapple_initiate(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
	weapon_name: String = "",
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
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

	# The World Disappears (s38 Void): the floating caster is immune to Grappling.
	if "The World Disappears" in t_p.active_kiho:
		return {"success": false, "reason": "target_immune_to_grapple"}

	# Weapon grapple validation: the named weapon must be grapple-capable (s40).
	var grapple_skill: String = "Jiujutsu"
	if weapon_name != "":
		if not IndividualCombat.weapon_can_grapple(weapon_name):
			return {"success": false, "reason": "weapon_cannot_grapple"}
		grapple_skill = IndividualCombat.get_weapon_profile(weapon_name).get("skill", "Jiujutsu")

	# Grapple ignores armor TN bonus — target TN = Reflexes × 5 + 5 (GDD s40).
	var grapple_tn: int = target.reflexes * 5 + 5

	var result: Dictionary = IndividualCombat.initiate_grapple(attacker, a_p, grapple_tn, dice_engine, grapple_skill)

	if result.get("apply_grappled_to_target", false):
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_GRAPPLED)
		t_p.grapple_partner_id = attacker_id
		a_p.grapple_partner_id = target_id
		# Immediately resolve control (attacker has it on initiation per GDD s40).
		a_p.grapple_in_control = true
		t_p.grapple_in_control = false
		# Record the weapon-grapple so control rolls use the weapon skill and Hit
		# deals weapon damage; the partner grapples bare-handed (Jiujutsu).
		if weapon_name != "":
			a_p.weapon_grapple_skill = grapple_skill
			a_p.weapon_grapple_weapon = weapon_name
		else:
			# Fresh unarmed grapple — clear any stale weapon-grapple state.
			a_p.weapon_grapple_skill = ""
			a_p.weapon_grapple_weapon = ""

	ts.consume_complex()
	state.combat_log.append({
		"type": "grapple_initiate",
		"round": state.combat.round_number,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon": weapon_name,
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
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
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
			var damage_dealt: int = 0
			if c_p.weapon_grapple_weapon != "":
				# Weapon grapple: Hit deals weapon damage, no raises (s40).
				var wdmg: Dictionary = IndividualCombat.resolve_damage(
					character, c_p.weapon_grapple_weapon, 0, 0, dice_engine, c_p)
				damage_dealt = wdmg["raw_damage"]
			else:
				damage_dealt = IndividualCombat.grapple_hit(character, dice_engine)["damage"]
			WoundSystem.apply_damage(target, damage_dealt)
			result = {"success": true, "damage": damage_dealt,
				"target_dead": CharacterStats.is_dead(target)}
			_check_and_mark_over(state, partner_id, target)

		"throw":
			if not c_p.grapple_in_control:
				return {"success": false, "reason": "not_in_control"}
			IndividualCombat.grapple_throw(c_p, t_p)
			result = {"success": true, "target_prone": true}

		"break":
			# Break (Simple Action, s40): remove yourself from the Grapple (both freed).
			if not ts.can_use_simple():
				return {"success": false, "reason": "no_simple_actions_remaining"}
			IndividualCombat.grapple_break(c_p, t_p)
			ts.consume_simple()
			state.combat_log.append({
				"type": "grapple_action", "round": state.combat.round_number,
				"char_id": char_id, "action": "break", "result": {"success": true},
			})
			return {"success": true, "broke_free": true}

		"pass":
			# Pass (Free Action, s40): do nothing, maintain the Grapple and retain control.
			ts.consume_free()
			state.combat_log.append({
				"type": "grapple_action", "round": state.combat.round_number,
				"char_id": char_id, "action": "pass", "result": {"success": true},
			})
			return {"success": true, "passed": true}

		"take_control":
			# Each combatant rolls with their own grapple skill (weapon-grapplers
			# use their Weapon Skill, s40); bare-handed defaults to Jiujutsu.
			var att_skill: String = c_p.weapon_grapple_skill if c_p.weapon_grapple_skill != "" else "Jiujutsu"
			var def_skill: String = t_p.weapon_grapple_skill if t_p.weapon_grapple_skill != "" else "Jiujutsu"
			var ctrl: Dictionary = IndividualCombat.resolve_grapple_control(
				character, target, dice_engine, att_skill, def_skill)
			var prev_in_control: bool = c_p.grapple_in_control
			if ctrl["attacker_wins"]:
				c_p.grapple_in_control = true
				t_p.grapple_in_control = false
			else:
				c_p.grapple_in_control = false
				t_p.grapple_in_control = true
			# s40 weapon-grapple risk: if a weapon-grappler loses control, their
			# opponent banks 2 Free Raises toward a Disarm against them.
			var disarm_raises_granted: bool = false
			if prev_in_control and not ctrl["attacker_wins"] and c_p.weapon_grapple_weapon != "":
				t_p.disarm_free_raises_pending = WEAPON_GRAPPLE_LOSE_CONTROL_DISARM_RAISES
				disarm_raises_granted = true
			result = {
				"success": ctrl["attacker_wins"],
				"control_gained": ctrl["attacker_wins"],
				"disarm_raises_granted": disarm_raises_granted,
			}

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
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
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


## Recover a dropped weapon after a Disarm (s40): a Simple Action that picks the weapon
## back up (it lies at the character's feet — no movement needed). Clears the disarmed state.
static func execute_recover_weapon(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}
	if not p.disarmed:
		return {"success": false, "reason": "not_disarmed"}
	if p.weapon_swept:
		# Gathering Swirl (s33) carried the weapon beyond the owner's feet — nothing to pick up.
		return {"success": false, "reason": "weapon_swept_away"}
	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}
	p.disarmed = false
	ts.consume_simple()
	state.combat_log.append({
		"type": "recover_weapon",
		"round": state.combat.round_number,
		"char_id": char_id,
	})
	return {"success": true}


## s36 Power of the Ocean (Water 5): while the multi-day sustain buff is ACTIVE the target may, as a
## Simple Action, replenish Void Points to full ("equivalent to a full night's rest"), School Rank
## times across the duration (drawn from power_of_ocean_void_uses — the same budget the world-sim
## daily restore uses). Gated on the active window only (power_of_ocean_until_ic_day clears the
## moment the active period ends, so this is unavailable during the exhaustion aftermath).
static func execute_replenish_void_ocean(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if character.power_of_ocean_until_ic_day < 0:
		return {"success": false, "reason": "ocean_not_active"}
	if character.power_of_ocean_void_uses <= 0:
		return {"success": false, "reason": "no_ocean_void_uses_remaining"}
	if character.current_void_points >= character.max_void_points:
		return {"success": false, "reason": "void_already_full"}
	var wl: int = CharacterStats.get_wound_level(character)
	if ts.is_down_restricted(wl):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}
	VoidSystem.restore_full(character)
	character.power_of_ocean_void_uses -= 1
	ts.consume_simple()
	state.combat_log.append({
		"type": "ocean_void_replenish",
		"round": state.combat.round_number,
		"char_id": char_id,
		"uses_remaining": character.power_of_ocean_void_uses,
	})
	return {"success": true, "uses_remaining": character.power_of_ocean_void_uses}


## Arugai "Nearly Immortal" counter-play (s54.5): a Complex Action to tear open a
## regenerating heart_kill oni's chest and locate its tiny heart — Investigation
## (Perception) vs TN 30, requires melee adjacency. On success the heart is exposed
## (heart_located) so subsequent strikes accrue against its 10-Wound track (see _apply_hit).
static func execute_locate_heart(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	target_id: int,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if target == null or target.spirit_creature == null \
			or not target.spirit_creature.has_tag("heart_kill"):
		return {"success": false, "reason": "no_heart"}
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null:
		return {"success": false, "reason": "target_missing"}
	if t_p.heart_destroyed:
		return {"success": false, "reason": "already_dead"}
	if t_p.heart_located:
		return {"success": false, "reason": "already_located"}
	if _chebyshev(state.positions.get(char_id, Vector2i(-999, -999)),
			state.positions.get(target_id, Vector2i(999, 999))) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_range"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	ts.consume_complex()
	var rc: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Investigation", HEART_LOCATE_TN, 0, "",
		Enums.Trait.PERCEPTION)
	var found: bool = rc.get("success", false)
	if found:
		t_p.heart_located = true
	state.combat_log.append({
		"type": "locate_heart",
		"round": state.combat.round_number,
		"char_id": char_id,
		"target_id": target_id,
		"success": found,
	})
	return {"success": found, "heart_located": found, "roll": rc.get("total", 0)}


## s43 Bleeding cure: bandage a bleeding wound shut. The GDD says a bleeding injury "continues
## until bandaged with a successful Medicine (Wounds) roll" — a Complex Action making a Medicine
## (Wound Treatment) / Intelligence roll vs the standard Medicine TN (15, MedicineSystem.BASE_TN —
## reused, not invented). On success the target's bleed (the "maho_bleed" timed modifier) is cleared.
## Self-bandage (healer == target, range 0) or an ally bandaging the bleeder (adjacent, range 1).
static func execute_stop_bleeding(
	state: MapCombatState, healer_id: int, healer: L5RCharacterData,
	target_id: int, target: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	if healer == null or CharacterStats.is_dead(healer):
		return {"success": false, "reason": "healer_invalid"}
	if target == null or CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_invalid"}
	var ts: TurnState = state.turn_states.get(healer_id, null)
	if ts == null or not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	# An ally bandaging the bleeder must be adjacent; self-bandage needs no range check.
	if healer_id != target_id and state.positions.has(healer_id) and state.positions.has(target_id):
		var hp: Vector2i = state.positions[healer_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(hp.x - tp.x), absi(hp.y - tp.y)) > 1:
			return {"success": false, "reason": "out_of_range"}
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null or IndividualCombat.get_timed_modifier_total(t_p, "bleed") <= 0:
		return {"success": false, "reason": "target_not_bleeding"}
	ts.consume_complex()
	var rc: Dictionary = SkillResolver.resolve_skill_check(
		healer, dice_engine, "Medicine", MedicineSystem.BASE_TN, 0, "Wound Treatment",
		Enums.Trait.INTELLIGENCE)
	var ok: bool = rc.get("success", false)
	if ok:
		IndividualCombat.clear_timed_modifiers_by_source(t_p, "maho_bleed")
	state.combat_log.append({
		"type": "stop_bleeding", "round": state.combat.round_number,
		"healer_id": healer_id, "target_id": target_id, "success": ok,
	})
	return {"success": ok, "bleeding_stopped": ok, "roll": rc.get("total", 0)}


## Tile-combat spellcasting (s31–s37 via SpellSystem). A Complex Action: validates the
## caster can cast (known / rank / slot / Ishiken), spends the slot, and resolves the cast
## roll vs TN (incl. creature Magic Resistance, s54). Range is LOS-only for now (GDD spell
## ranges are blocked on map-distance data, like ranged weapons). The per-spell offensive
## EFFECT on success is Phase 2 (the library carries no damage/AoE data yet); Phase 1 wires
## the reactions that fire off the act of casting — Sodatsu's Bane and Magic Resistance.
static func execute_cast_spell(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	spell_id: String,
	target_id: int,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "caster_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not SpellSystem.can_cast(caster, spell_id):
		return {"success": false, "reason": "cannot_cast"}
	# s35 cast-economy: Hurried Steps lets the next Fire ML<=3 cast be a Simple Action; The Element's
	# Fury lets Fire ML<=4 casts be Free Actions (slots/rolls still required). Decided before the
	# action check so a discounted cast doesn't demand the full Complex.
	var sp_elem: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", -1)
	var sp_ml: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("m", 1)
	var use_free_cast: bool = ts.free_casts > 0 and sp_elem == Enums.Ring.FIRE and sp_ml <= 4
	var use_simple_cast: bool = (not use_free_cast) and ts.cast_as_simple > 0 \
		and sp_elem == Enums.Ring.FIRE and sp_ml <= 3
	if use_free_cast:
		pass  # Free Action — no budget required
	elif use_simple_cast:
		if not ts.can_use_simple():
			return {"success": false, "reason": "no_simple_action"}
	elif not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	# s33 Essence of Air: no other spells may be cast while insubstantial.
	var caster_p_ins: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
	if caster_p_ins != null and IndividualCombat.get_timed_modifier_total(caster_p_ins, "insubstantial") > 0:
		return {"success": false, "reason": "insubstantial"}
	if use_free_cast:
		ts.free_casts -= 1
	elif use_simple_cast:
		ts.cast_as_simple -= 1
		ts.consume_simple()
	else:
		ts.consume_complex()
	var ml: int = sp_ml
	# Sodatsu's Bane (s54.5): a spell cast AT a shugenjas_bane creature is absorbed — it has
	# no effect, the caster's slot is still spent, and the oni instantly retaliates.
	if target != null and target.spirit_creature != null \
			and target.spirit_creature.has_tag("shugenjas_bane"):
		SpellSystem.consume_slot(caster, SpellSystem.get_best_cast_ring(caster, spell_id))
		var retal: Dictionary = _sodatsu_bane_retaliate(
			state, target_id, target, caster_id, caster, ml, dice_engine)
		state.combat_log.append({
			"type": "spell_absorbed", "round": state.combat.round_number,
			"caster_id": caster_id, "target_id": target_id, "spell_id": spell_id,
			"mastery": ml, "retaliation": retal,
		})
		return {"success": false, "absorbed": true, "spell_id": spell_id,
			"mastery": ml, "retaliation": retal}
	# Area ward (s34 Earth's Protection / s35 Ward of Thunder): a hostile spell of a warded element
	# cast while the caster stands inside an enemy ward takes a Spell Casting TN penalty.
	var ward_tn: int = _ward_cast_penalty(state, caster_id, spell_id)
	# s34 The Kami's Will: a spell cast AT a warded character has its casting roll cut by −XkX
	# (X = the warder's Earth Ring, stored as the "kamis_will" timed modifier on the target).
	var kw_penalty: int = 0
	if target != null:
		var tgt_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
		if tgt_p != null:
			kw_penalty = IndividualCombat.get_timed_modifier_total(tgt_p, "kamis_will")
	var res: Dictionary = SpellSystem.resolve_cast(caster, spell_id, dice_engine, 0, target, -1, ward_tn, kw_penalty)
	res["spell_id"] = spell_id
	# Furaribi rule (s54.12): a jade/crystal-property spell does not harm a superior_invuln
	# spirit but repels it — it retreats from the area (leaves the encounter).
	if res.get("success", false) and SpellSystem.has_jade_or_crystal_property(spell_id) \
			and target != null and target.spirit_creature != null \
			and target.spirit_creature.has_tag("superior_invuln"):
		state.positions.erase(target_id)
		if target_id not in state.fled_ids:
			state.fled_ids.append(target_id)
		res["spirit_retreated"] = true
		state.combat_log.append({
			"type": "spirit_repelled", "round": state.combat.round_number,
			"caster_id": caster_id, "target_id": target_id, "spell_id": spell_id,
		})
	# Phase 2 — per-spell direct-damage effects (s31–s37, currently Fire tranche).
	var eff: Dictionary = SpellSystem.get_combat_effect(spell_id)
	if res.get("success", false) and eff.get("kind", "") == "damage" \
			and not res.get("spirit_retreated", false):
		res["spell_damage"] = _apply_spell_combat_damage(
			state, caster_id, caster, target_id, target, eff, spell_id, dice_engine)
		state.combat_log.append({
			"type": "spell_damage", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "hits": res["spell_damage"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "heal":
		res["spell_heal"] = _apply_spell_heal(
			state, caster_id, caster, target_id, target, eff, res, dice_engine)
		state.combat_log.append({
			"type": "spell_heal", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "heal": res["spell_heal"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "status":
		res["spell_status"] = _apply_spell_status(
			state, caster_id, caster, target_id, target, eff, dice_engine)
		state.combat_log.append({
			"type": "spell_status", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "status": res["spell_status"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "cleanse":
		res["spell_cleanse"] = _apply_spell_cleanse(state, caster_id, caster, eff, target_id)
		state.combat_log.append({
			"type": "spell_cleanse", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "cleanse": res["spell_cleanse"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "buff":
		res["spell_buff"] = _apply_spell_buff(state, caster_id, caster, target_id, target, eff)
		state.combat_log.append({
			"type": "spell_buff", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "buff": res["spell_buff"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "debuff":
		res["spell_debuff"] = _apply_spell_debuff(
			state, caster_id, caster, target_id, target, eff, dice_engine)
		state.combat_log.append({
			"type": "spell_debuff", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "debuff": res["spell_debuff"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "conjure_weapon":
		res["conjured"] = _apply_spell_conjure_weapon(
			state, caster_id, caster, target_id, eff, spell_id)
		state.combat_log.append({
			"type": "spell_conjure_weapon", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "conjured": res["conjured"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "damage_zone":
		res["zone"] = _apply_spell_zone(
			state, caster_id, caster, target_id, target, eff, spell_id, dice_engine)
		state.combat_log.append({
			"type": "spell_zone", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "zone": res["zone"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "ward":
		res["ward"] = _apply_spell_ward(state, caster_id, eff, spell_id)
		state.combat_log.append({
			"type": "spell_ward", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "ward": res["ward"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "summon":
		res["summon"] = _apply_spell_summon(state, caster_id, caster, eff, spell_id, dice_engine)
		state.combat_log.append({
			"type": "spell_summon", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "summon": res["summon"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "clone":
		res["clone"] = _apply_spell_clone(state, caster_id, caster, dice_engine)
		state.combat_log.append({
			"type": "spell_clone", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "clone": res["clone"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "banish_spirit":
		res["banished"] = _apply_spell_banish_spirit(state, caster_id, caster, target_id, target, dice_engine)
		state.combat_log.append({
			"type": "spell_banish", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "banished": res["banished"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "ignite_zone":
		res["ignited"] = _apply_spell_ignite_zone(state, caster_id, target_id, eff)
		state.combat_log.append({
			"type": "spell_ignite", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "ignited": res["ignited"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "extinguish":
		res["extinguished"] = _apply_spell_extinguish(state, caster_id, eff)
		state.combat_log.append({
			"type": "spell_extinguish", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "extinguished": res["extinguished"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "purify_zone":
		res["purify_zone"] = _apply_spell_purify_zone(state, caster_id, caster, eff, spell_id)
		state.combat_log.append({
			"type": "spell_purify_zone", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "zone": res["purify_zone"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "modifier_zone":
		res["modifier_zone"] = _apply_spell_modifier_zone(state, caster_id, target_id, target, eff, spell_id)
		state.combat_log.append({
			"type": "spell_modifier_zone", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "zone": res["modifier_zone"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "fog_zone":
		res["fog_zone"] = _apply_spell_fog_zone(state, caster_id, target_id, target, eff, spell_id)
		state.combat_log.append({
			"type": "spell_fog_zone", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "zone": res["fog_zone"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "dispel":
		res["dispel"] = _apply_spell_dispel(state, caster_id, target_id, target, eff)
		state.combat_log.append({
			"type": "spell_dispel", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "result": res["dispel"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "wall":
		res["wall"] = _apply_spell_wall(state, caster_id, target_id, target, eff, spell_id)
		state.combat_log.append({
			"type": "spell_wall", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "result": res["wall"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "ring_change":
		res["ring_change"] = _apply_spell_ring_change(state, caster_id, caster, target_id, target, eff, dice_engine)
		state.combat_log.append({
			"type": "spell_ring_change", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "result": res["ring_change"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "gain_void":
		var gained: int = SpellSystem.get_effective_school_rank(caster, Enums.Ring.VOID) + 1
		caster.current_void_points += gained  # over-cap allowed (s37 Drawing the Void)
		res["void_gained"] = gained
	elif res.get("success", false) and eff.get("kind", "") == "restore_void":
		res["void_restored"] = _apply_spell_restore_void(state, caster_id, target_id, target)
	elif res.get("success", false) and eff.get("kind", "") == "steal_void":
		res["void_stolen"] = _apply_spell_steal_void(state, caster_id, caster, target_id, target, dice_engine)
	elif res.get("success", false) and eff.get("kind", "") == "instant_kill":
		res["instant_kill"] = _apply_spell_instant_kill(
			state, caster_id, caster, target_id, target, eff, dice_engine)
		state.combat_log.append({
			"type": "spell_instant_kill", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "result": res["instant_kill"],
		})
	elif res.get("success", false) and eff.get("kind", "") == "reposition":
		res["reposition"] = _apply_spell_reposition(state, caster_id, caster, eff)
		state.combat_log.append({
			"type": "spell_reposition", "round": state.combat.round_number,
			"caster_id": caster_id, "spell_id": spell_id, "result": res["reposition"],
		})
	state.combat_log.append({
		"type": "spell_cast", "round": state.combat.round_number,
		"caster_id": caster_id, "target_id": target_id, "spell_id": spell_id,
		"success": res.get("success", false),
	})
	return res


## Apply a heal-type spell's combat effect (s36 Water). Heals a living ally (or self) within
## reach (Touch = adjacent, or self). Returns {id, healed} or {reason} when it cannot apply.
static func _apply_spell_heal(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, res: Dictionary,
	dice_engine: DiceEngine = null,
) -> Dictionary:
	# Default to self when no target was named.
	var heal_target: L5RCharacterData = target if target != null else caster
	var heal_id: int = target_id if target != null else caster_id
	# Must be a living ally (same faction); cannot heal an enemy or the dead.
	if String(state.factions.get(heal_id, "")) != String(state.factions.get(caster_id, "")):
		return {"reason": "not_an_ally"}
	if CharacterStats.is_dead(heal_target):
		return {"reason": "target_dead"}
	# s35 Disrupt the Aura: a target under no_magic_heal cannot be restored by magical means
	# (spells/items/Techniques auto-fail; mundane Medicine still works, out-of-combat).
	var heal_p: IndividualCombat.Participant = state.combat.participants.get(heal_id, null)
	if heal_p != null and IndividualCombat.get_timed_modifier_total(heal_p, "no_magic_heal") > 0:
		return {"id": heal_id, "healed": 0, "no_magic_heal": true}
	# Touch range: caster adjacent to the ally (self exempt).
	var rng: int = eff.get("range_tiles", 1)
	if heal_id != caster_id and state.positions.has(caster_id) and state.positions.has(heal_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[heal_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	# s43 No Pure Breaths: the +10-TN lung-ravage "cannot end naturally even if damage is healed; any
	# magical healing... restores the lungs and ends the TN penalty." A heal spell that reaches the target
	# (past the ally/alive/range/no_magic_heal gates) IS magical healing, so it clears the debuff
	# regardless of how many wounds it heals — even a 0-wound heal restores the lungs.
	var npb_cured: bool = false
	if heal_p != null:
		var npb_before: int = IndividualCombat.get_timed_modifier_total(heal_p, "all_rolls")
		IndividualCombat.clear_timed_modifiers_by_source(heal_p, "no_pure_breaths")
		npb_cured = IndividualCombat.get_timed_modifier_total(heal_p, "all_rolls") != npb_before
	var amount: int = 0
	match eff.get("heal", ""):
		"margin":
			amount = maxi(0, int(res.get("margin", 0)))
		"water_plus_rank":
			amount = SpellSystem.get_ring_value(caster, Enums.Ring.WATER) \
				+ SpellSystem.get_effective_school_rank(caster, Enums.Ring.WATER)
		"full":
			amount = heal_target.wounds_taken
		"dice":
			# s37 Balance of Elements: heal a fixed dice amount (e.g. 3k3).
			if dice_engine != null:
				amount = dice_engine.roll_and_keep(
					int(eff.get("heal_rolled", 3)), int(eff.get("heal_kept", 3)), true).total
	if amount <= 0:
		return {"id": heal_id, "healed": 0, "no_pure_breaths_cured": npb_cured}
	WoundSystem.heal_wounds(heal_target, amount)
	return {"id": heal_id, "healed": amount, "no_pure_breaths_cured": npb_cured}


## s43 maho cast in tile combat: a maho-user enemy (Bloodspeaker/cult, s56.14) casts a maho spell.
## Maho has NO casting roll (it fires automatically when blood is spilled) — so this auto-succeeds,
## paying the s43 blood cost (2×ML self-Wounds, bypassing armor — the maho-tsukai cuts itself) and
## gaining Taint (Pattern B, pre-applied) up front, then routes the spell's combat effect through the
## same _apply_spell_* functions the s31–37 casts use. World-sim consequences (PTL, CrimeRecord,
## province) belong to the world-sim cast (MahoSystem.resolve_cast), not the skirmish — in a
## PC-present encounter the maho-tsukai is already a known hostile. Returns the effect result dict.
static func execute_cast_maho(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	spell_id: String, target_id: int, target: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	if caster == null or CharacterStats.is_dead(caster):
		return {"success": false, "reason": "caster_dead"}
	var spell: Dictionary = MahoSpellLibrary.get_spell(spell_id)
	if spell.is_empty():
		return {"success": false, "reason": "unknown_maho_spell"}
	var eff: Dictionary = MahoSpellLibrary.get_combat_effect(spell_id)
	if eff.is_empty():
		return {"success": false, "reason": "no_combat_effect"}
	var ts = state.turn_states.get(caster_id, null)
	if ts == null or not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	# Effect-specific preconditions checked BEFORE paying blood (don't waste blood on an invalid cast):
	# Bleeding reopens an existing wound; Blood Armor needs a living ally to sacrifice.
	var _eff_kind: String = String(eff.get("kind", ""))
	if _eff_kind == "bleed" and (target == null or target.wounds_taken < 1):
		return {"success": false, "reason": "target_not_injured"}
	if _eff_kind == "blood_armor" and _nearest_ally_id(state, caster_id) < 0:
		return {"success": false, "reason": "no_sacrifice"}
	# Pattern B: pay the self-blood cost (2×ML Wounds, bypasses armor) + Taint before the effect.
	var ml: int = int(spell.get("mastery_level", 1))
	var blood: int = MahoSystem.total_blood_cost(ml, 0)
	# A rational maho-user does not cut itself to death (the self-blood would Out/kill it). Refuse —
	# the caller falls through to a non-suicidal action. (Sacrificing a captive is the world-sim path.)
	if caster.wounds_taken + blood > CharacterStats.get_total_wound_capacity(caster):
		return {"success": false, "reason": "blood_cost_lethal"}
	WoundSystem.apply_damage(caster, blood, 0)
	caster.taint += float(MahoSystem.taint_gain(ml))
	ts.consume_complex()
	var res: Dictionary = {"success": true, "maho": true, "spell_id": spell_id, "ml": ml,
		"blood_cost": blood}
	match String(eff.get("kind", "")):
		"status":
			res["spell_status"] = _apply_spell_status(
				state, caster_id, caster, target_id, target, eff, dice_engine)
		"debuff":
			res["spell_debuff"] = _apply_spell_debuff(
				state, caster_id, caster, target_id, target, eff, dice_engine)
		"buff":
			res["spell_buff"] = _apply_spell_buff(state, caster_id, caster, target_id, target, eff)
		"damage":
			res["spell_damage"] = _apply_spell_combat_damage(
				state, caster_id, caster, target_id, target, eff, spell_id, dice_engine)
		"bleed":
			res["spell_bleed"] = _apply_maho_bleed(state, caster_id, target_id, target, eff)
		"fear":
			res["spell_fear"] = _apply_maho_fear(
				state, caster_id, caster, target_id, target, eff, dice_engine)
		"tomb":
			res["spell_tomb"] = _apply_maho_tomb(
				state, caster_id, target_id, target, eff, dice_engine)
		"blood_armor":
			res["spell_blood_armor"] = _apply_maho_blood_armor(state, caster_id)
		"drain_soul":
			res["spell_drain_soul"] = _apply_maho_drain_soul(
				state, caster_id, caster, target_id, target, eff, dice_engine)
	state.combat_log.append({"type": "cast_maho", "round": state.combat.round_number,
		"caster_id": caster_id, "spell_id": spell_id, "result": res})
	return res


## Apply a damage-type spell's combat effect (Phase 2). Single-target or self-centered AoE.
## One damage roll per affected target; spirit targets routed through the incoming-damage
## filter as fire+magic (flame_immune blocks/heals; invuln tags let magic through). Returns
## an Array of per-target {id, damage|healed, dead} reports.
static func _apply_spell_combat_damage(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, spell_id: String,
	dice_engine: DiceEngine,
) -> Array:
	var hits: Array = []
	var targets: Array = _gather_spell_targets(state, caster_id, target_id, target, eff)
	# DR uses the spell's element Ring when dr_* is 0; spirit damage filter keyed on that element.
	var element: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", Enums.Ring.FIRE)
	var ering: int = SpellSystem.get_ring_value(caster, element)
	var rolled: int = eff.get("dr_rolled", 0)
	if rolled <= 0:
		rolled = ering
	rolled += int(eff.get("dr_rolled_bonus", 0))
	var kept: int = eff.get("dr_kept", 0)
	if kept <= 0:
		kept = ering
	var kind: String = SpiritAbilitySystem.W_MAGIC
	if element == Enums.Ring.FIRE:
		kind = SpiritAbilitySystem.W_FIRE
	elif element == Enums.Ring.WATER:
		kind = SpiritAbilitySystem.W_WATER
	var needs_taint: bool = eff.get("requires_taint", false)
	for t in targets:
		var ch: L5RCharacterData = t["char"]
		if needs_taint and MutationSystem.get_taint_rank(ch.taint) < 1:
			hits.append({"id": t["id"], "damage": 0, "immune_no_taint": true})
			continue
		# save_negates (s34 Murmur of Earth / Maw of the Earth): a successful save avoids ALL of
		# the spell's damage and rider for this target.
		if eff.get("save_negates", false) \
				and _spell_save_resisted(state, caster, ch, String(eff.get("save", "none")),
					int(eff.get("save_tn", 0)), dice_engine):
			hits.append({"id": t["id"], "damage": 0, "saved": true})
			continue
		# Area ward damage reduction (s34 Earth's Protection): a warded-element spell striking a
		# creature inside an enemy ward loses dice (min 1k1).
		var er: int = rolled
		var ek: int = kept
		# s43 Burning Blood: DR equals the TARGET's Fire Ring (per-target, not the caster's).
		if eff.has("dr_target_ring"):
			var t_ring: int = SpellSystem.get_ring_value(ch, int(eff["dr_target_ring"]))
			er = maxi(1, t_ring)
			ek = maxi(1, t_ring)
		var wred: Array = _ward_dr_reduction(state, caster_id, element,
			state.positions.get(int(t["id"]), Vector2i(-9999, -9999)))
		if wred[0] > 0 or wred[1] > 0:
			er = maxi(1, rolled - int(wred[0]))
			ek = maxi(1, kept - int(wred[1]))
		var dmg: int = dice_engine.roll_and_keep(er, ek, true).total
		if ch.spirit_creature != null:
			var filt: Dictionary = SpiritAbilitySystem.incoming_damage(
				ch.spirit_creature, kind, true)  # spells always read as magic for invuln tags
			if filt.get("heals", false):
				WoundSystem.heal_wounds(ch, dmg)
				hits.append({"id": t["id"], "healed": dmg})
				continue
			dmg = int(round(dmg * filt.get("multiplier", 1.0)))
		WoundSystem.apply_damage(ch, dmg, 0)
		var dead: bool = CharacterStats.is_dead(ch)
		var h: Dictionary = {"id": t["id"], "damage": dmg, "dead": dead}
		# Rider condition (Knockdown/Daze/Fatigue/Deafen) — only on a surviving damaged target.
		var rider: Dictionary = eff.get("rider", {})
		if not rider.is_empty() and not dead:
			h["rider"] = _apply_spell_rider(state, caster, ch, int(t["id"]), rider, dice_engine)
		hits.append(h)
	return hits


# Shared target gatherer for damage/status spells. Single-target (aoe_radius 0) or AoE
# (radius>0; centered on the target tile when ranged, else on the caster). Returns an Array of
# {id, char}; empty when an out-of-range single/aim fizzles. AoE always excludes the caster and
# the dead; "enemies"/"all" honored via aoe_hits.
static func _gather_spell_targets(
	state: MapCombatState, caster_id: int, target_id: int,
	target: L5RCharacterData, eff: Dictionary,
) -> Array:
	var radius: int = eff.get("aoe_radius", 0)
	var rng: int = eff.get("range_tiles", 0)
	var targets: Array = []
	if radius <= 0:
		if target == null:
			return targets
		if rng > 0 and state.positions.has(caster_id) and state.positions.has(target_id):
			var cp: Vector2i = state.positions[caster_id]
			var tp: Vector2i = state.positions[target_id]
			if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
				return targets  # out of range — the cast fizzles (slot already spent)
		targets.append({"id": target_id, "char": target})
		return targets
	# AoE: centered on the target tile when ranged (targeted blast), else on the caster.
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	if rng > 0 and state.positions.has(target_id):
		var caster_pos: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
		var aim: Vector2i = state.positions[target_id]
		if maxi(absi(caster_pos.x - aim.x), absi(caster_pos.y - aim.y)) > rng:
			return targets  # aim point out of cast range
		center = aim
	var hits_all: bool = eff.get("aoe_hits", "enemies") == "all"
	var cf: String = state.factions.get(caster_id, FACTION_PLAYER)
	for cid in state.positions.keys():
		if cid == caster_id:
			continue
		var pos: Vector2i = state.positions[cid]
		if maxi(absi(center.x - pos.x), absi(center.y - pos.y)) > radius:
			continue
		if not hits_all and String(state.factions.get(cid, "")) == cf:
			continue
		var ch = state.combatants.get(cid, null)
		if ch == null or CharacterStats.is_dead(ch):
			continue
		# s35 The Dragon's Talon: the Fire kami only strike weak foes (Insight Rank ≤ N).
		if eff.has("target_max_insight") and ch.insight_rank > int(eff["target_max_insight"]):
			continue
		targets.append({"id": cid, "char": ch})
	# Optional cap on the number of struck targets (e.g. "up to 10 target creatures").
	if eff.has("aoe_max_targets") and targets.size() > int(eff["aoe_max_targets"]):
		targets.resize(int(eff["aoe_max_targets"]))
	return targets


## Apply a status/control spell (s33/s34/s35): inflict a condition on each affected target.
## Conditions map to the existing combat-condition layer (Blinded/Dazed/Fatigued/Entangled).
## duration_rounds 0 = persistent/roll-recovered via apply_condition; >0 = timed (auto-expire).
## An optional save (rider save-types) lets the target resist. Returns per-target {id, status}.
static func _apply_spell_status(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Array:
	var out: Array = []
	var cond: String = eff.get("condition", "")
	var dur: int = eff.get("duration_rounds", 0)
	var save: String = eff.get("save", "none")
	var tn: int = eff.get("save_tn", 0)
	# s34 Earth bindings only affect Tainted creatures or Shadowlands/spirit creatures (others
	# are immune — the manacles find no purchase). Gated by `requires_shadowlands` on the effect.
	var require_shadow: bool = eff.get("requires_shadowlands", false)
	for t in _gather_spell_targets(state, caster_id, target_id, target, eff):
		var p: IndividualCombat.Participant = state.combat.participants.get(int(t["id"]), null)
		if p == null:
			continue
		var tch: L5RCharacterData = t["char"]
		if require_shadow and tch.taint < 1.0 and tch.spirit_creature == null:
			out.append({"id": t["id"], "status": "immune"})
			continue
		if save != "none" and _spell_save_resisted(state, caster, tch, save, tn, dice_engine):
			out.append({"id": t["id"], "status": "resisted"})
			continue
		if dur > 0:
			IndividualCombat.apply_timed_condition(p, cond, state.combat.round_number + dur)
		else:
			IndividualCombat.apply_condition(p, cond)
		out.append({"id": t["id"], "status": cond})
	return out


## Apply a cleanse spell (s36 Typhoon's Surge / Rejuvenating Vapors): free up to `cleanse_cap`
## living allies within range from a set of conditions and heal each `cleanse_heal` Wounds, nearest
## first. Defaults (Typhoon's Surge): cap = Water Rank, conditions = Fatigued + Dazed, heal = Water
## Rank. Rejuvenating Vapors overrides (cap 1, Fatigued only, heal 0).
static func _apply_spell_cleanse(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, eff: Dictionary,
	target_id: int = -1,
) -> Array:
	var out: Array = []
	var rng: int = eff.get("range_tiles", 10)
	var water_rank: int = SpellSystem.get_ring_value(caster, Enums.Ring.WATER)
	var cap: int = int(eff.get("cleanse_cap", water_rank))
	var heal_amt: int = int(eff.get("cleanse_heal", water_rank))
	var conditions: Array = eff.get("cleanse_conditions",
		[IndividualCombat.CONDITION_FATIGUED, IndividualCombat.CONDITION_DAZED])
	var cf: String = String(state.factions.get(caster_id, ""))
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var cands: Array = []
	for cid in state.positions.keys():
		if String(state.factions.get(cid, "")) != cf:
			continue
		var ch = state.combatants.get(cid, null)
		if ch == null or CharacterStats.is_dead(ch):
			continue
		var pos: Vector2i = state.positions[cid]
		var d: int = maxi(absi(center.x - pos.x), absi(center.y - pos.y))
		if d > rng:
			continue
		# The explicitly-targeted ally (single-target Touch cleanse like Rejuvenating Vapors)
		# is cleansed first within the cap, ahead of the merely-nearest.
		if cid == target_id:
			d = -1
		cands.append({"id": cid, "char": ch, "d": d})
	cands.sort_custom(func(a, b): return a["d"] < b["d"])
	for i in mini(cap, cands.size()):
		var c: Dictionary = cands[i]
		var p: IndividualCombat.Participant = state.combat.participants.get(int(c["id"]), null)
		if p != null:
			for cond in conditions:
				IndividualCombat.remove_condition(p, String(cond))
		# Disrupt the Aura (s35): the Wound-restore portion auto-fails, but condition cleansing
		# (Fatigue/Dazed) still works — it is not "restoring Wounds."
		var blocked: bool = p != null and IndividualCombat.get_timed_modifier_total(p, "no_magic_heal") > 0
		var did_heal: int = heal_amt
		if heal_amt > 0 and not blocked:
			WoundSystem.heal_wounds(c["char"], heal_amt)
		elif blocked:
			did_heal = 0
		out.append({"id": c["id"], "cleansed": true, "healed": did_heal})
	return out


## Apply a buff spell (s34/s35/s36): persistent stat bonuses installed on the target's Participant
## via the round-scoped timed-modifier layer (auto-expires in advance_round). target "self" buffs
## the caster (range ignored); "ally" buffs a living same-faction target within Touch/range.
## Each mod is {kind, value} where value is an int or a formula string resolved against the caster.
# =============================================================================
# -- Mists of Illusion (s33 Air 2): stationary visual-only phantom -------------
# =============================================================================

## Place a visual-only phantom at a passable, unoccupied tile within 20' (4 tiles)
## of the caster. A Complex Action; cast roll vs the spell TN; slot consumed. The
## phantom draws a lured enemy's strike when that enemy has no real target
## (execute_npc_turn's no-target branch), wasting the enemy's turn and dispelling
## the phantom (visual-only -> revealed the instant it is struck).
static func execute_cast_mists(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	tx: int, ty: int, dice_engine: DiceEngine,
) -> Dictionary:
	if caster == null or CharacterStats.is_dead(caster):
		return {"success": false, "reason": "caster_dead"}
	if not state.positions.has(caster_id):
		return {"success": false, "reason": "not_in_combat"}
	if not SpellSystem.can_cast(caster, "mists_of_illusion"):
		return {"success": false, "reason": "cannot_cast"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null or not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	if tx < 0 or ty < 0 or tx >= state.map.width or ty >= state.map.height:
		return {"success": false, "reason": "out_of_bounds"}
	var cp: Vector2i = state.positions[caster_id]
	if maxi(absi(tx - cp.x), absi(ty - cp.y)) > 4:
		return {"success": false, "reason": "out_of_range"}
	if not MovementSystem.is_passable(state.map.get_tile(tx, ty)):
		return {"success": false, "reason": "impassable_tile"}
	for pid in state.positions:
		var pp: Vector2i = state.positions[pid]
		if pp.x == tx and pp.y == ty:
			return {"success": false, "reason": "tile_occupied"}
	ts.consume_complex()
	var res: Dictionary = SpellSystem.resolve_cast(caster, "mists_of_illusion", dice_engine)
	if not res.get("success", false):
		return {"success": false, "reason": "cast_failed", "roll": res}
	state.illusion_phantoms.append({"x": tx, "y": ty, "caster_id": caster_id})
	state.combat_log.append({"type": "mists_of_illusion", "round": state.combat.round_number,
		"caster_id": caster_id, "x": tx, "y": ty})
	return {"success": true, "x": tx, "y": ty}


## s33 Gathering Swirl (Air 1) — Complex Action. The Air kami gather a NAMED un-wielded item
## within 20' (4 tiles) and deposit it at a chosen location. The only un-wielded-AND-unattended
## item the combat model tracks is a disarmed character's dropped weapon, so `target_char_id`
## names that owner (the GDD requires naming the specific item; "cannot snatch from another
## person's grasp or person" → the weapon must already be on the ground = the owner is disarmed).
## On a successful cast the weapon is swept beyond the owner's feet (weapon_swept) so they can no
## longer recover it. `dest` records where it was deposited (caster / ally / tile), which must lie
## within the area; the relocation itself is the effect — no recipient is auto-armed (mid-combat
## weapon transfer/proficiency is not modelled).
static func execute_gathering_swirl(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_char_id: int, dest: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if caster == null or CharacterStats.is_dead(caster):
		return {"success": false, "reason": "caster_dead"}
	if not state.positions.has(caster_id):
		return {"success": false, "reason": "not_in_combat"}
	if not SpellSystem.can_cast(caster, "gathering_swirl"):
		return {"success": false, "reason": "cannot_cast"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null or not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	# The named item: a specific disarmed character's dropped weapon, within the 20' area.
	if not state.positions.has(target_char_id):
		return {"success": false, "reason": "target_not_in_combat"}
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_char_id, null)
	if t_p == null:
		return {"success": false, "reason": "target_missing"}
	if not t_p.disarmed:
		# Wielded/sheathed weapons are "in their grasp or on their person" — cannot be snatched.
		return {"success": false, "reason": "no_unwielded_item"}
	if t_p.weapon_swept:
		return {"success": false, "reason": "already_swept"}
	var cp: Vector2i = state.positions[caster_id]
	var tp: Vector2i = state.positions[target_char_id]
	if maxi(absi(tp.x - cp.x), absi(tp.y - cp.y)) > 4:
		return {"success": false, "reason": "out_of_range"}
	# Validate the deposit destination lies within the 20' area (Chebyshev <= 4 from caster).
	var dest_kind: String = String(dest.get("kind", "caster"))
	var dest_pos: Vector2i = cp
	if dest_kind == "ally":
		var ally_id: int = int(dest.get("char_id", -1))
		if not state.positions.has(ally_id):
			return {"success": false, "reason": "dest_ally_not_in_combat"}
		dest_pos = state.positions[ally_id]
	elif dest_kind == "tile":
		dest_pos = Vector2i(int(dest.get("tile_x", -1)), int(dest.get("tile_y", -1)))
		if dest_pos.x < 0 or dest_pos.y < 0 or dest_pos.x >= state.map.width or dest_pos.y >= state.map.height:
			return {"success": false, "reason": "dest_out_of_bounds"}
	if maxi(absi(dest_pos.x - cp.x), absi(dest_pos.y - cp.y)) > 4:
		return {"success": false, "reason": "dest_out_of_area"}
	ts.consume_complex()
	var res: Dictionary = SpellSystem.resolve_cast(caster, "gathering_swirl", dice_engine)
	if not res.get("success", false):
		return {"success": false, "reason": "cast_failed", "roll": res}
	t_p.weapon_swept = true
	state.combat_log.append({"type": "gathering_swirl", "round": state.combat.round_number,
		"caster_id": caster_id, "swept_from": target_char_id,
		"dest_kind": dest_kind, "dest_x": dest_pos.x, "dest_y": dest_pos.y})
	return {"success": true, "swept_from": target_char_id, "dest_kind": dest_kind,
		"dest_x": dest_pos.x, "dest_y": dest_pos.y}

## Nearest visible phantom to an NPC within `reach` tiles (path-distance proxy via
## Chebyshev + LOS), or {} if none. Used by the no-target lure.
static func _nearest_visible_phantom(state: MapCombatState, npc_id: int, reach: int) -> Dictionary:
	if state.illusion_phantoms.is_empty() or not state.positions.has(npc_id):
		return {}
	var np: Vector2i = state.positions[npc_id]
	var best: Dictionary = {}
	var best_d: int = reach + 1
	for ph in state.illusion_phantoms:
		var pp: Vector2i = Vector2i(int(ph["x"]), int(ph["y"]))
		var d: int = maxi(absi(pp.x - np.x), absi(pp.y - np.y))
		if d <= reach and d < best_d and _has_los(state.map, np, pp):
			best = ph
			best_d = d
	return best


static func _apply_spell_buff(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary,
) -> Dictionary:
	# AoE-ally buff (s33 Legion of the Moon): apply the mods to every living same-faction
	# combatant (incl. the caster) within aoe_radius of the caster.
	if int(eff.get("aoe_radius", 0)) > 0 and String(eff.get("target", "self")) == "ally":
		return _apply_spell_buff_aoe(state, caster_id, caster, eff)
	var to_self: bool = eff.get("target", "self") == "self"
	var bid: int = caster_id if to_self else target_id
	var bch: L5RCharacterData = caster if to_self else target
	if bch == null:
		bid = caster_id
		bch = caster
	if not to_self:
		if String(state.factions.get(bid, "")) != String(state.factions.get(caster_id, "")):
			return {"reason": "not_an_ally"}
		if CharacterStats.is_dead(bch):
			return {"reason": "target_dead"}
		var rng: int = eff.get("range_tiles", 1)
		if bid != caster_id and state.positions.has(caster_id) and state.positions.has(bid):
			var cp: Vector2i = state.positions[caster_id]
			var tp: Vector2i = state.positions[bid]
			if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
				return {"reason": "out_of_range"}
	var p: IndividualCombat.Participant = state.combat.participants.get(bid, null)
	if p == null:
		return {"reason": "not_in_combat"}
	var expiry: int = state.combat.round_number + int(eff.get("duration_rounds", 5))
	# s37 The Void's Caress: negate one Mental/Spiritual Disadvantage on the target (≤ max_points) for
	# the duration — reuses the s38 Banish All Shadows suppression field (one slot, read by the combat-roll
	# disadvantage loops via AdvantageSystem._is_suppressed). Cleared at expiry in advance_round.
	if eff.has("suppress_disadvantage"):
		var hd: DisadvantageData = AdvantageSystem.get_highest_mental_or_spiritual_disadvantage(
			bch, int(eff.get("suppress_max_points", 5)))
		if hd != null:
			bch.suppressed_disadvantage_type = int(hd.disadvantage_type)
			p.suppressed_disadvantage_expiry = expiry
			return {"id": bid, "suppressed_disadvantage": int(hd.disadvantage_type), "expires_round": expiry}
		return {"id": bid, "no_suppressable_disadvantage": true}
	var applied: Array = []
	for mod in eff.get("mods", []):
		var mkind: String = String(mod.get("kind", ""))
		var val: int = _resolve_buff_value(caster, mod.get("value", 0))
		if mkind == "absorb_pool":
			# s34 Power of the Earth Dragon: a depleting damage-absorption pool (participant field).
			p.absorb_pool = maxi(p.absorb_pool, val)
		elif mkind == "invisible":
			# s33 Gift of Wind / Legion of the Moon: a dedicated source so attacking can clear
			# just this modifier (_reveal_if_hidden) without dropping other spell buffs.
			IndividualCombat.add_timed_modifier(p, mkind, val, expiry, "spell_invisible")
		elif mkind == "initiative_score":
			# s36 Clarity of Purpose: a persistent Initiative-score delta (no timed expiry; the
			# 2-round GDD duration is approximated as skirmish-length, matching Song of the World).
			p.initiative_modifier += val
		elif mkind == "ranged_auto_hit":
			# s33 Arrow's Flight: a one-shot guided arrow. Dedicated source so execute_ranged_attack
			# can clear just this modifier after the next bow shot (the duration is the firing window).
			IndividualCombat.add_timed_modifier(p, mkind, val, expiry, "spell_arrows_flight")
		elif mkind in ["granted_attacks", "granted_simple", "cast_as_simple", "free_casts"]:
			# s36/s35 action-economy spells: grant one-shot bonus-action pools on the target's
			# TurnState (consumed by the attack/move/cast paths), not timed modifiers.
			var gts: TurnState = state.turn_states.get(bid, null)
			if gts != null:
				gts.set(mkind, int(gts.get(mkind)) + val)
		else:
			IndividualCombat.add_timed_modifier(p, mkind, val, expiry, "spell_buff")
		applied.append({"kind": mkind, "value": val})
	return {"id": bid, "applied": applied, "expires_round": expiry}


## Apply a buff to every living same-faction combatant (incl. the caster) within aoe_radius of the
## caster (s33 Legion of the Moon). Same mod resolution as the single-target path. Returns the list
## of buffed ids.
static func _apply_spell_buff_aoe(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, eff: Dictionary,
) -> Dictionary:
	var radius: int = int(eff.get("aoe_radius", 0))
	var cf: String = String(state.factions.get(caster_id, ""))
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var expiry: int = state.combat.round_number + int(eff.get("duration_rounds", 5))
	var buffed: Array = []
	for cid in state.positions.keys():
		if String(state.factions.get(cid, "")) != cf:
			continue
		var ch = state.combatants.get(cid, null)
		if ch == null or CharacterStats.is_dead(ch):
			continue
		var pos: Vector2i = state.positions[cid]
		if maxi(absi(center.x - pos.x), absi(center.y - pos.y)) > radius:
			continue
		var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if p == null:
			continue
		for mod in eff.get("mods", []):
			var mkind: String = String(mod.get("kind", ""))
			var val: int = _resolve_buff_value(caster, mod.get("value", 0))
			if mkind == "absorb_pool":
				p.absorb_pool = maxi(p.absorb_pool, val)
			elif mkind == "invisible":
				IndividualCombat.add_timed_modifier(p, mkind, val, expiry, "spell_invisible")
			elif mkind == "initiative_score":
				p.initiative_modifier += val  # s36 Clarity of Purpose (persistent delta)
			else:
				IndividualCombat.add_timed_modifier(p, mkind, val, expiry, "spell_buff")
		buffed.append(cid)
	return {"buffed": buffed, "expires_round": expiry}


## Apply a debuff spell to an ENEMY target (s31-37 enemy hexes). Mirrors _apply_spell_buff but
## targets an opposing-faction creature, honors range, and supports an optional contested-roll gate
## (eff "contested" = a save-type the target must LOSE to be afflicted; e.g. earth_contested for
## strike_at_the_roots). Mods carry their (often negative) timed-modifier values. immune_trait_change
## (s34 Wholeness of the World) blocks the debuff entirely.
static func _apply_spell_debuff(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	if String(state.factions.get(target_id, "")) == String(state.factions.get(caster_id, "")):
		return {"reason": "not_an_enemy"}
	var rng: int = int(eff.get("range_tiles", 1))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	var p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if p == null:
		return {"reason": "not_in_combat"}
	# Wholeness of the World (s34): immune to any Trait/Ring-altering effect.
	if IndividualCombat.get_timed_modifier_total(p, "immune_trait_change") > 0:
		return {"reason": "immune_trait_change"}
	# Optional contested gate: the target resists by winning the named save.
	var contested: String = String(eff.get("contested", ""))
	if contested != "" and _spell_save_resisted(
			state, caster, target, contested, int(eff.get("save_tn", 0)), dice_engine):
		return {"reason": "resisted", "id": target_id}
	var expiry: int = state.combat.round_number + int(eff.get("duration_rounds", 5))
	# Optional per-effect modifier source (default shared "spell_debuff"). A distinct source lets a
	# specific debuff be cleared selectively — e.g. No Pure Breaths' "magical healing ends it" cure.
	var dbsrc: String = String(eff.get("source", "spell_debuff"))
	var applied: Array = []
	for mod in eff.get("mods", []):
		var mkind: String = String(mod.get("kind", ""))
		var raw_val = mod.get("value", 0)
		var val: int
		if raw_val is String and raw_val == "neg_target_social_spiritual_disadv":
			# s36 Judgment of Yomi: −1k0 to physical Skill checks (attack rolls) per Social or
			# Spiritual Disadvantage the TARGET possesses (computed from the target, not the caster).
			val = -_count_social_spiritual_disadvantages(target)
		elif raw_val is String and raw_val == "chi_reversal_agility":
			# s36 Chi Reversal: the caster flips the target's Fire-pair Traits (Agility<->Intelligence).
			# The combat slice is the Agility change to attack rolls; clamped <= 0 (the caster only
			# casts when the swap lowers the target's Agility — never accidentally buffs an enemy).
			val = mini(0, target.intelligence - target.agility)
		else:
			val = _resolve_buff_value(caster, raw_val)
		# s35 Haze of Battle: the target is forced into Full Attack Stance immediately and the
		# `stance_locked` timed modifier prevents switching away (execute_stance_change blocks it,
		# _npc_pick_stance short-circuits) until it expires.
		if mkind == "stance_locked":
			p.stance = Enums.Stance.FULL_ATTACK
		IndividualCombat.add_timed_modifier(p, mkind, val, expiry, dbsrc)
		applied.append({"kind": mkind, "value": val})
	return {"id": target_id, "applied": applied, "expires_round": expiry}


# s34 ring-changing spells (Essence of Earth ring-up, Water ring-downs). Applies a combat-scoped
# Ring delta to the target's authoritative Participant store + the synced read-bridge, so the whole
# CharacterStats wound/death chain (capacity, level, penalty, is_dead) sees the change consistently —
# without threading every call site. duration_rounds caps it; on expiry the delta is removed and a
# ring-UP that ended re-evaluates death (wounds return to normal — possibly fatal).
static func _apply_spell_ring_change(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	# target "self" -> the caster; any other ("ally"/"enemy") -> the spell target, range-gated.
	var who: L5RCharacterData = caster
	var who_id: int = caster_id
	if String(eff.get("target", "self")) != "self" and target != null:
		who = target
		who_id = target_id
		var rng: int = int(eff.get("range_tiles", 1))
		if state.positions.has(caster_id) and state.positions.has(target_id):
			var cp: Vector2i = state.positions[caster_id]
			var tp: Vector2i = state.positions[target_id]
			if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
				return {"reason": "out_of_range"}
	var p: IndividualCombat.Participant = state.combat.participants.get(who_id, null)
	if p == null or who == null:
		return {"reason": "not_in_combat"}
	# Optional contested gate (Strike at the Roots: caster must win a Contested Earth roll).
	var contested: String = String(eff.get("contested", ""))
	if contested != "" and _spell_save_resisted(state, caster, who, contested, int(eff.get("save_tn", 0)), dice_engine):
		return {"reason": "resisted", "id": who_id}
	var ring: int = int(eff.get("ring", Enums.Ring.EARTH))
	var base_ring: int = CharacterStats.get_ring_value(who, ring)  # current effective (incl. prior deltas removed below)
	# Determine the delta: an absolute "set_to" (Strike at the Roots -> 1), a Taint-aggravated
	# delta (Wolf's Mercy -> -2 vs a Tainted target), or a flat delta.
	var delta: int = int(eff.get("delta", 0))
	if eff.has("set_to"):
		delta = int(eff["set_to"]) - base_ring
	elif eff.has("taint_delta") and who.taint >= 1.0:
		delta = int(eff["taint_delta"])
	# Floor a ring-down so the effective ring never drops below 1 (GDD "minimum 1" / "reduced to 1";
	# also avoids an Earth-0 threshold-instant-death — the lethality is reduced CAPACITY vs wounds).
	if delta < 0:
		delta = maxi(delta, 1 - base_ring)
	var expiry: int = state.combat.round_number + int(eff.get("duration_rounds", 10))
	p.ring_deltas[ring] = int(p.ring_deltas.get(ring, 0)) + delta
	p.ring_delta_expiry[ring] = expiry
	IndividualCombat.sync_ring_deltas(p, who)
	# A ring-down on an already-wounded target may immediately kill (reduced capacity < wounds).
	var died: bool = delta < 0 and CharacterStats.is_dead(who)
	return {"id": who_id, "ring": ring, "delta": delta, "expires_round": expiry,
		"new_capacity": CharacterStats.get_total_wound_capacity(who), "died_on_apply": died}


# Expire combat ring deltas (s34) whose duration has elapsed: remove the delta, re-sync the bridge,
# and — for a ring-UP that ended — re-check death (wounds return to normal, possibly fatal).
static func _expire_ring_deltas(state: MapCombatState, p: IndividualCombat.Participant, chars_by_id: Dictionary) -> void:
	if p.ring_delta_expiry.is_empty():
		return
	var ch = state.combatants.get(p.character_id, chars_by_id.get(p.character_id, null))
	if ch == null:
		return
	var changed: bool = false
	for ring in p.ring_delta_expiry.keys():
		if state.combat.round_number >= int(p.ring_delta_expiry[ring]):
			p.ring_deltas.erase(ring)
			p.ring_delta_expiry.erase(ring)
			changed = true
	if changed:
		IndividualCombat.sync_ring_deltas(p, ch)
		# The boost is gone: if wounds now exceed base capacity, the character dies (Essence of
		# Earth: "Wounds return to normal — possibly resulting in death"). is_dead now reads base.
		if CharacterStats.is_dead(ch):
			state.combat_log.append({"type": "ring_delta_expiry_death",
				"round": state.combat.round_number, "id": p.character_id})


# s36 Judgment of Yomi: count a character's Social + Spiritual Disadvantages (s45 category catalog).
static func _count_social_spiritual_disadvantages(c: L5RCharacterData) -> int:
	if c == null:
		return 0
	var n: int = 0
	for dd in c.disadvantages:
		if dd == null:
			continue
		var cat: String = AdvantageSystem.get_disadvantage_category(dd.disadvantage_type)
		if cat == "Social" or cat == "Spiritual":
			n += 1
	return n


# Resolve a buff mod value: a raw int, or a GDD formula keyed off the caster's rings/school rank.
# s36 Ever-Changing Waves natural-creature form: the s54.1 base bear (transcribed in
# SpiritBestiary.chikushudo_catalog "spirit_bear"). The GDD allows "any natural creature";
# the iconic strong-bodied combat form is the default. Real s54.1 stats — not invented.
const TRANSFORM_FORM_BEAR: Dictionary = {"strength": 7, "agility": 4, "reflexes": 3}


static func _resolve_buff_value(caster: L5RCharacterData, value) -> int:
	if value is String:
		match value:
			"water_plus_rank":
				return SpellSystem.get_ring_value(caster, Enums.Ring.WATER) \
					+ SpellSystem.get_effective_school_rank(caster, Enums.Ring.WATER)
			"earth_plus_rank":
				return SpellSystem.get_ring_value(caster, Enums.Ring.EARTH) \
					+ SpellSystem.get_effective_school_rank(caster, Enums.Ring.EARTH)
			"earth_ring":
				return SpellSystem.get_ring_value(caster, Enums.Ring.EARTH)
			"transform_strength":
				# s36 Ever-Changing Waves: transform into a natural creature, keeping the higher of
				# own/creature Physical Traits. Strength drives damage dice; the net rolled-damage gain
				# is max(0, formStrength - ownStrength). Form = the s54.1 bear (str 7, agi 4, ref 3).
				return maxi(0, TRANSFORM_FORM_BEAR["strength"] - caster.strength)
			"transform_agility":
				# s36 Ever-Changing Waves: Agility drives attack dice -> max(0, formAgi - ownAgi).
				return maxi(0, TRANSFORM_FORM_BEAR["agility"] - caster.agility)
			"transform_armor_tn":
				# s36 Ever-Changing Waves: Reflexes drives Armor TN (x5) -> max(0, formRef - ownRef) x5.
				return maxi(0, TRANSFORM_FORM_BEAR["reflexes"] - caster.reflexes) * 5
			"air_ring":
				# s33 Air Kami's Blessing: +Air Ring to Armor TN (the combat slice).
				return SpellSystem.get_ring_value(caster, Enums.Ring.AIR)
			"water_school_rank":
				# s36 Ebbing Strength: the caster transfers up to (Water School Rank) Strength.
				return SpellSystem.get_effective_school_rank(caster, Enums.Ring.WATER)
			"void_replace_weapon_skill":
				# s37 Moment of Clarity: temporary Skill Ranks = Void Ring, REPLACING the existing
				# rank (not cumulative). For a weapon skill the net attack-roll gain (a skill rank is
				# a rolled attack die) is max(0, Void Ring − the caster's best current weapon skill).
				var best_ws: int = 0
				for sk in _NPC_WEAPON_SKILLS:
					best_ws = maxi(best_ws, int(caster.skills.get(sk, 0)))
				return maxi(0, SpellSystem.get_ring_value(caster, Enums.Ring.VOID) - best_ws)
			"fire_ring":
				return SpellSystem.get_ring_value(caster, Enums.Ring.FIRE)
			"water_half":
				# s36 Strength of the Tsunami: +half the caster's Water Ring (rounded down) Strength
				# Rank, which adds exactly that many rolled damage dice (Strength → first-number).
				return int(SpellSystem.get_ring_value(caster, Enums.Ring.WATER) / 2)
			"neg_fire_ring":
				# s35 Death of Flame: −Fire Ring to the target's Agility (its attack-roll slice).
				return -SpellSystem.get_ring_value(caster, Enums.Ring.FIRE)
			"earth_school_rank":
				# s34 Armor of the Emperor: per-die reduction = the caster's (Earth) School Rank.
				return SpellSystem.get_effective_school_rank(caster, Enums.Ring.EARTH)
			"be_the_mountain_reduction":
				return mini(20, 5 * SpellSystem.get_effective_school_rank(caster, Enums.Ring.EARTH))
			_:
				return 0
	return int(value)


## Install a conjured elemental weapon (s33 Yari of Air / s34 Tetsubo of Earth / s35 Katana of
## Fire / s36 Bo of Water) on the caster (or a same-faction ally within range). The created weapon
## has the spell's fixed DR and may be wielded with the caster's effective School Rank in place of
## the weapon skill (resolve_attack takes the better). Returns {wielder_id, weapon}. Per-spell
## extras (Katana's Honor-to-damage, Tetsubo/Bo Knockdown Free Raise, Yari Feint/IncDmg Free
## Raise) are deferred. duration_rounds from the effect (5 minutes = 50 rounds).
static func _apply_spell_conjure_weapon(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, eff: Dictionary, spell_id: String,
) -> Dictionary:
	# Beneficiary: a same-faction living participant target (ally grant), else the caster.
	var wielder_id: int = caster_id
	if target_id != caster_id and state.combat.participants.has(target_id):
		var cf: String = state.factions.get(caster_id, FACTION_PLAYER)
		var tch = state.combatants.get(target_id, null)
		if String(state.factions.get(target_id, "")) == cf and tch != null \
				and not CharacterStats.is_dead(tch):
			wielder_id = target_id
	var element: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", Enums.Ring.FIRE)
	var school_rank: int = SpellSystem.get_effective_school_rank(caster, element)
	var weapon: Dictionary = {
		"rolled": int(eff.get("dr_rolled", 2)),
		"kept": int(eff.get("dr_kept", 2)),
		"skill": String(eff.get("skill", "Kenjutsu")),
		"trait": "agility",
		"strength_adds": false,
		"melee": true,
		"school_rank": school_rank,
	}
	var p: IndividualCombat.Participant = state.combat.participants.get(wielder_id)
	if p == null:
		return {}
	p.conjured_weapon = weapon
	p.conjured_weapon_expiry = state.combat.round_number + int(eff.get("duration_rounds", 50))
	return {"wielder_id": wielder_id, "weapon": weapon}


## Register a persistent spell zone (s35 Wall of Fire / Enticing the Dance of Flame / Fiery Wrath,
## s34 Maw of the Earth). Centered on the target tile (ranged) or the caster. Optional immediate
## impact damage (impact_rolled/impact_kept) is applied on cast via _apply_spell_combat_damage-style
## per-target rolls; the standing per-round damage (dr_rolled/dr_kept) is applied in advance_round.
## "entry_save" (e.g. reflexes_flat with save_tn) lets a creature already in the area avoid the first
## tick. Returns {center, radius, expiry_round, impact_hits}.
static func _apply_spell_zone(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, spell_id: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var rng: int = int(eff.get("range_tiles", 0))
	if rng > 0 and state.positions.has(target_id):
		center = state.positions[target_id]
	var radius: int = int(eff.get("aoe_radius", 1))
	var element: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", Enums.Ring.FIRE)
	var dur: int = int(eff.get("duration_rounds", 5))
	var zone: Dictionary = {
		"center": center, "radius": radius, "kind": "damage_zone",
		"dr_rolled": int(eff.get("dr_rolled", 0)), "dr_kept": int(eff.get("dr_kept", 0)),
		"element": element, "faction": String(state.factions.get(caster_id, FACTION_PLAYER)),
		"hits": String(eff.get("aoe_hits", "all")),
		"expiry_round": state.combat.round_number + dur,
		"spell_id": spell_id, "caster_id": caster_id,
	}
	state.spell_zones.append(zone)
	# Optional immediate impact damage (Enticing the Dance: 3k2 on the round it takes effect).
	var impact_hits: Array = []
	if int(eff.get("impact_rolled", 0)) > 0:
		var imp_eff: Dictionary = {
			"dr_rolled": int(eff["impact_rolled"]), "dr_kept": int(eff.get("impact_kept", 2)),
			"range_tiles": rng, "aoe_radius": radius, "aoe_hits": zone["hits"],
			"caster_exempt": true,
		}
		impact_hits = _apply_spell_combat_damage(
			state, caster_id, caster, target_id, target, imp_eff, spell_id, dice_engine)
	return {"center": center, "radius": radius, "expiry_round": zone["expiry_round"],
		"impact_hits": impact_hits}


## Install a purify zone (s36 Heaven's Tears): a holy-rain field, centered on the caster, that each
## Round heals the pure of soul (no Taint, Honor 4.0+) by the caster's Water Ring and damages the
## Tainted/Shadow-corrupted (1k1). Affects ALL combatants in the area by soul state (not faction).
## heal_amount is fixed at the caster's Water Ring at cast time; the per-round work runs in
## _process_spell_zones. ("Outdoors only" is flavour — not gated.)
static func _apply_spell_purify_zone(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, eff: Dictionary, spell_id: String,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var radius: int = int(eff.get("aoe_radius", 6))
	var dur: int = int(eff.get("duration_rounds", 2))
	var heal_amount: int = SpellSystem.get_ring_value(caster, Enums.Ring.WATER)
	var zone: Dictionary = {
		"center": center, "radius": radius, "kind": "purify",
		"heal_amount": heal_amount,
		"dr_rolled": int(eff.get("dr_rolled", 1)), "dr_kept": int(eff.get("dr_kept", 1)),
		"expiry_round": state.combat.round_number + dur,
		"spell_id": spell_id, "caster_id": caster_id,
	}
	state.spell_zones.append(zone)
	return {"center": center, "radius": radius, "heal_amount": heal_amount,
		"expiry_round": zone["expiry_round"]}


## Install a modifier zone (s33 Blessed Wind of Lady Sun / Summoning the Gale): a persistent area
## whose roll modifiers apply to whoever currently STANDS in it (read at roll time via
## _zone_modifier_total, so movement in/out is honored — unlike a one-time timed modifier). Centered
## on the caster (self_centered) or on a designated target tile (range_tiles). The zone is fixed once
## cast (does not follow the caster). Concentration ≈ skirmish (duration_rounds 9999).
static func _apply_spell_modifier_zone(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData,
	eff: Dictionary, spell_id: String,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	if not eff.get("self_centered", false) and target != null and state.positions.has(target_id):
		center = state.positions[target_id]
	var radius: int = int(eff.get("aoe_radius", 1))
	var dur: int = int(eff.get("duration_rounds", 9999))
	var zone: Dictionary = {
		"center": center, "radius": radius, "kind": "modifier",
		"mods": eff.get("mods", {}),
		"hits": String(eff.get("hits", "all")),
		"faction": String(state.factions.get(caster_id, FACTION_PLAYER)),
		"expiry_round": state.combat.round_number + dur,
		"spell_id": spell_id, "caster_id": caster_id,
	}
	state.spell_zones.append(zone)
	return {"center": center, "radius": radius, "mods": zone["mods"],
		"expiry_round": zone["expiry_round"]}


## Sum a modifier-zone roll modifier (mod_key) over every modifier zone the character currently
## stands in. hits == "enemies" restricts a zone to non-caster-faction occupants; "all" affects
## anyone in the radius. Returns 0 when the character is in no relevant zone (the common case).
static func _zone_modifier_total(state: MapCombatState, char_id: int, mod_key: String) -> int:
	if state.spell_zones.is_empty() or not state.positions.has(char_id):
		return 0
	var pos: Vector2i = state.positions[char_id]
	var total: int = 0
	for zone in state.spell_zones:
		if String(zone.get("kind", "")) != "modifier":
			continue
		var mods: Dictionary = zone.get("mods", {})
		if not mods.has(mod_key):
			continue
		var center: Vector2i = zone["center"]
		if maxi(absi(center.x - pos.x), absi(center.y - pos.y)) > int(zone.get("radius", 1)):
			continue
		if String(zone.get("hits", "all")) == "enemies" \
				and String(state.factions.get(char_id, "")) == String(zone.get("faction", "")):
			continue
		total += int(mods[mod_key])
	return total


## Install a fog zone (s33 Summon Fog): a thick obscuring cloud (visibility reduced to 5 ft) that
## blocks line of sight for ranged attacks crossing it beyond one tile. Centered on a designated
## target tile (range_tiles) or the caster. 1-minute ≈ skirmish.
static func _apply_spell_fog_zone(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData,
	eff: Dictionary, spell_id: String,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	if int(eff.get("range_tiles", 0)) > 0 and target != null and state.positions.has(target_id):
		center = state.positions[target_id]
	var radius: int = int(eff.get("aoe_radius", 10))
	var dur: int = int(eff.get("duration_rounds", 9999))
	var zone: Dictionary = {
		"center": center, "radius": radius, "kind": "fog",
		"expiry_round": state.combat.round_number + dur,
		"spell_id": spell_id, "caster_id": caster_id,
	}
	state.spell_zones.append(zone)
	return {"center": center, "radius": radius, "expiry_round": zone["expiry_round"]}


## Dispel (s33 Draw Back the Shadow): within the area, dispel illusions — clear every combatant's
## invisibility (spell_invisible) and remove obscuring fog zones. Auto for the ML≤4 illusions wired
## here (Gift of Wind / Legion of the Moon / Summon Fog); the ML5-6 Contested Air roll and the
## broader "ongoing non-illusion magical effects" contested dispel are deferred (the timed-modifier
## layer stores no creator/mastery to contest against). Indiscriminate within the area (friend + foe).
static func _apply_spell_dispel(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData, eff: Dictionary,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	if int(eff.get("range_tiles", 0)) > 0 and target != null and state.positions.has(target_id):
		center = state.positions[target_id]
	var radius: int = int(eff.get("aoe_radius", 6))
	var revealed: Array = []
	# Clear invisibility from every combatant standing in the area.
	for cid: int in state.positions.keys():
		var pos: Vector2i = state.positions[cid]
		if maxi(absi(pos.x - center.x), absi(pos.y - center.y)) > radius:
			continue
		var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if p == null:
			continue
		if IndividualCombat.get_timed_modifier_total(p, "invisible") > 0:
			IndividualCombat.clear_timed_modifiers_by_source(p, "spell_invisible")
			revealed.append(cid)
	# Remove obscuring fog zones whose center lies within the dispel area.
	var fog_cleared: int = 0
	var surviving: Array = []
	for zone in state.spell_zones:
		if String(zone.get("kind", "")) == "fog":
			var c: Vector2i = zone.get("center", Vector2i.ZERO)
			if maxi(absi(c.x - center.x), absi(c.y - center.y)) <= radius:
				fog_cleared += 1
				continue
		surviving.append(zone)
	state.spell_zones = surviving
	return {"center": center, "radius": radius, "revealed": revealed, "fog_cleared": fog_cleared}


## Conjure a wall barrier (s34 Wall of Earth): a straight line of WALL_STONE tiles centered on a
## target tile, oriented perpendicular to the caster→target approach (so it blocks that approach and
## the LOS along it; enemies path around it via A*). Only passable, unoccupied tiles are walled; the
## originals are saved on a "conjured_terrain" zone and restored on expiry. Movement (is_passable) and
## LOS (blocking walls) honor the new tiles automatically. set_delta is the dynamic-tile channel
## (get_tile reads deltas first); restoring via set_delta(original) returns the tile to its prior look.
static func _apply_spell_wall(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData,
	eff: Dictionary, spell_id: String,
) -> Dictionary:
	var a: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var tgt: Vector2i = a
	if int(eff.get("range_tiles", 0)) > 0 and target != null and state.positions.has(target_id):
		tgt = state.positions[target_id]
	var d: Vector2i = tgt - a
	# Place the barrier at the midpoint between caster and target (a "wall between me and my enemy"),
	# oriented perpendicular to the approach so it separates the two and breaks LOS along the line.
	var b: Vector2i = Vector2i(int((a.x + tgt.x) / 2), int((a.y + tgt.y) / 2))
	var perp: Vector2i = Vector2i(0, 1) if absi(d.x) >= absi(d.y) else Vector2i(1, 0)
	var half: int = int(eff.get("wall_length", 6)) / 2
	var occupied: Dictionary = {}
	for p in state.positions.values():
		occupied[p] = true
	var saved: Array = []
	for k in range(-half, half + 1):
		var t: Vector2i = Vector2i(b.x + perp.x * k, b.y + perp.y * k)
		if t.x < 0 or t.x >= state.map.width or t.y < 0 or t.y >= state.map.height:
			continue
		if occupied.has(t):
			continue  # never wall a combatant's tile
		if not MovementSystem.is_passable(state.map.get_tile(t.x, t.y)):
			continue  # already blocked — nothing to conjure
		saved.append({"pos": t, "original": state.map.get_tile(t.x, t.y)})
		state.map.set_delta(t.x, t.y, Enums.TileType.WALL_STONE)
	var dur: int = int(eff.get("duration_rounds", 9999))
	var zone: Dictionary = {
		"kind": "conjured_terrain", "tiles": saved,
		"expiry_round": state.combat.round_number + dur,
		"spell_id": spell_id, "caster_id": caster_id,
	}
	state.spell_zones.append(zone)
	return {"tiles_placed": saved.size(), "expiry_round": zone["expiry_round"]}


## Restore the original tiles of a conjured-terrain zone (s34 Wall of Earth) when it expires.
static func _restore_conjured_terrain(state: MapCombatState, zone: Dictionary) -> void:
	for entry in zone.get("tiles", []):
		var pos: Vector2i = entry["pos"]
		state.map.set_delta(pos.x, pos.y, int(entry["original"]))


## True when the straight line from a to b passes through any fog zone (s33 Summon Fog) — blocking
## sight/shots beyond 5 ft. Adjacent tiles (≤1) are always visible. Traces the same Bresenham line
## as _has_los; a traced tile within a fog disc blocks the view (including either endpoint in fog).
static func _ray_blocked_by_fog(state: MapCombatState, a: Vector2i, b: Vector2i) -> bool:
	if state.spell_zones.is_empty():
		return false
	if maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1:
		return false  # 5 ft visibility — adjacent is always seen
	var has_fog: bool = false
	for zone in state.spell_zones:
		if String(zone.get("kind", "")) == "fog":
			has_fog = true
			break
	if not has_fog:
		return false
	var cx: int = a.x
	var cy: int = a.y
	var dx: int = absi(b.x - a.x)
	var dy: int = absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx - dy
	while true:
		for zone in state.spell_zones:
			if String(zone.get("kind", "")) != "fog":
				continue
			var c: Vector2i = zone["center"]
			if maxi(absi(c.x - cx), absi(c.y - cy)) <= int(zone.get("radius", 10)):
				return true
		if cx == b.x and cy == b.y:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy
	return false


## Per-round spell-zone processing (called from advance_round). Every living combatant standing in
## a damage zone takes the zone's per-round DR (element ring when dr_* is 0; spirit damage filter
## honored). Expired zones are dropped. The zone owner's faction is exempt when hits == "enemies".
static func _process_spell_zones(state: MapCombatState, dice_engine: DiceEngine) -> void:
	var surviving: Array = []
	for zone in state.spell_zones:
		if int(zone.get("expiry_round", -1)) >= 0 \
				and state.combat.round_number >= int(zone["expiry_round"]):
			# s34 Wall of Earth: restore the original tiles when the conjured barrier crumbles.
			if String(zone.get("kind", "")) == "conjured_terrain":
				_restore_conjured_terrain(state, zone)
			continue
		# s33 modifier zones (Blessed Wind of Lady Sun / Summoning the Gale) have no per-round effect
		# — their modifiers are read at roll time by _zone_modifier_total. Keep them until they expire.
		# s33 fog zones (Summon Fog) likewise have no per-round effect — they block LOS at shot time.
		# s34 conjured terrain (Wall of Earth) is inert per-round — the walled tiles do the work.
		if String(zone.get("kind", "damage_zone")) in ["modifier", "fog", "conjured_terrain"]:
			surviving.append(zone)
			continue
		# s36 Heaven's Tears: a purify field — heal the pure of soul, harm the Tainted, by soul
		# state (all factions). Pure = no Taint AND Honor 4.0+; Tainted/corrupted = Taint Rank 1+.
		if String(zone.get("kind", "damage_zone")) == "purify":
			var pcenter: Vector2i = zone["center"]
			var pradius: int = int(zone.get("radius", 6))
			var pheal: int = int(zone.get("heal_amount", 0))
			var pdr: int = int(zone.get("dr_rolled", 1))
			var pdk: int = int(zone.get("dr_kept", 1))
			for cid in state.positions.keys():
				var ppos: Vector2i = state.positions[cid]
				if maxi(absi(pcenter.x - ppos.x), absi(pcenter.y - ppos.y)) > pradius:
					continue
				var pch = state.combatants.get(cid, null)
				if pch == null or CharacterStats.is_dead(pch):
					continue
				if pch.taint >= 1.0:
					WoundSystem.apply_damage(pch, dice_engine.roll_and_keep(pdr, pdk, true).total, 0)
				elif pch.honor >= 4.0:
					WoundSystem.heal_wounds(pch, pheal)
			surviving.append(zone)
			continue
		var dr_rolled: int = int(zone.get("dr_rolled", 0))
		var dr_kept: int = int(zone.get("dr_kept", 0))
		if dr_rolled > 0:
			var element: int = int(zone.get("element", Enums.Ring.FIRE))
			var dkind: String = SpiritAbilitySystem.W_MAGIC
			if element == Enums.Ring.FIRE:
				dkind = SpiritAbilitySystem.W_FIRE
			elif element == Enums.Ring.WATER:
				dkind = SpiritAbilitySystem.W_WATER
			var center: Vector2i = zone["center"]
			var radius: int = int(zone.get("radius", 1))
			var zfac: String = String(zone.get("faction", ""))
			var enemies_only: bool = String(zone.get("hits", "all")) == "enemies"
			for cid in state.positions.keys():
				if enemies_only and String(state.factions.get(cid, "")) == zfac:
					continue
				var pos: Vector2i = state.positions[cid]
				if maxi(absi(center.x - pos.x), absi(center.y - pos.y)) > radius:
					continue
				var ch = state.combatants.get(cid, null)
				if ch == null or CharacterStats.is_dead(ch):
					continue
				var dmg: int = dice_engine.roll_and_keep(dr_rolled, dr_kept, true).total
				if ch.spirit_creature != null:
					var filt: Dictionary = SpiritAbilitySystem.incoming_damage(
						ch.spirit_creature, dkind, true)
					if filt.get("heals", false):
						WoundSystem.heal_wounds(ch, dmg)
						continue
					dmg = int(round(dmg * filt.get("multiplier", 1.0)))
				WoundSystem.apply_damage(ch, dmg, 0)
		surviving.append(zone)
	state.spell_zones = surviving


## Build an elemental kami stat block (s33-36 Rise, Air/Earth/Fire/Water). All Physical Traits =
## the caster's element Ring; Jiujutsu attack = half Ring (rolled = Ring + Ring/2, keep Ring);
## Wounds as a human with Earth = Ring (wounds_dead 0 → standard track); Invulnerable to mundane
## weapons (partial_invuln). Damage uses DR = Ring (kept 2 — the GDD "DR equal to the Ring" leaves
## the kept dice unstated; PROVISIONAL). A Fire kami also sets struck targets on fire.
static func _build_kami_creature(element: int, ring: int) -> SpiritCreatureData:
	var cr := SpiritCreatureData.new()
	cr.id = "elemental_kami"
	cr.display_name = "Elemental Kami"
	cr.realm = Enums.SpiritRealm.NINGEN_DO
	cr.air = ring
	cr.earth = ring
	cr.fire = ring
	cr.water = ring
	cr.attack_name = "Kami Strike"
	cr.attack_rolled = ring + int(ring / 2.0)
	cr.attack_kept = ring
	cr.damage_rolled = ring
	cr.damage_kept = 2
	cr.armor_tn = ring * 5 + 5
	cr.reduction = 0
	cr.wounds_dead = 0  # standard human wound track from Earth = ring
	var t: Array[String] = ["partial_invuln"]  # Invulnerable: only magic/jade harm it
	if element == Enums.Ring.FIRE:
		t.append("burning_touch")  # struck targets catch fire (+1k1/round via the fire layer)
	cr.tags = t
	return cr


## Summon an elemental kami (s33-36 Rise, X) as an autonomous combatant on the caster's side. A
## player-faction caster registers it as a companion (auto-acts via execute_companion_turn); an
## enemy-faction caster adds it via add_enemy (auto-acts via execute_npc_turn). Spawns on a free
## tile near the caster. Returns {kami_id, faction} or {} if no tile is free.
static func _apply_spell_summon(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	eff: Dictionary, spell_id: String, dice_engine: DiceEngine,
) -> Dictionary:
	var element: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", Enums.Ring.AIR)
	var ring: int = SpellSystem.get_ring_value(caster, element)
	var summon_kind: String = String(eff.get("summon_kind", "kami"))
	var count: int = int(eff.get("count", 1))
	var faction: String = String(state.factions.get(caster_id, FACTION_PLAYER))
	var ids: Array = []
	for _i in range(count):
		var tile: Vector2i = _free_tile_near(state, state.positions.get(caster_id, Vector2i.ZERO))
		if tile.x < 0:
			break
		state.spawn_counter += 1
		var sid: int = -200000 - state.spawn_counter  # unique negative id for summons
		var creature: SpiritCreatureData
		match summon_kind:
			"clay_soldier": creature = _build_clay_soldier(ring)
			"shiryo": creature = _build_shiryo()
			_: creature = _build_kami_creature(element, ring)
		var puppet: L5RCharacterData = SpiritCombatant.to_character_data(creature, sid)
		if faction == FACTION_ENEMY:
			add_enemy(state, puppet, tile.x, tile.y, dice_engine)
		else:
			var comp := CompanionData.new()
			comp.companion_id = sid
			comp.type = CompanionData.CompanionType.NAMED_ALLY
			comp.display_name = puppet.character_name
			comp.character_id = sid
			comp.command = CompanionData.Command.FOLLOW
			comp.command_target_id = caster_id
			comp.yu_rank = 10  # never breaks morale
			add_companion(state, comp, puppet, tile.x, tile.y, dice_engine)
		ids.append(sid)
	return {"summon_ids": ids, "faction": faction, "element": element, "ring": ring,
		"kami_id": (ids[0] if not ids.is_empty() else 0)}


## s37 Divide the Soul: the caster manifests a second body that acts independently on the caster's
## side. The clone is a deep copy of the caster (combat stats, weapons) with fresh Wounds, placed near
## the caster and driven by the companion AI — so the caster effectively acts twice per Round. Shared
## death (if either dies, both die) is wired via state.divide_soul_pairs + _apply_divide_soul_shared_death
## (the operative faithful rule). The clone's spells_known is cleared to prevent recursive self-cloning;
## the GDD "either may cast, only one per Round" nuance and "Wounds combined when the spell ends" (the
## 1-minute duration outlasts a typical skirmish) are not modeled.
static func _apply_spell_clone(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	var tile: Vector2i = _free_tile_near(state, state.positions.get(caster_id, Vector2i.ZERO))
	if tile.x < 0:
		return {"clone_id": 0, "placed": false}
	state.spawn_counter += 1
	var sid: int = -300000 - state.spawn_counter  # unique negative id for clones
	var clone: L5RCharacterData = caster.duplicate(true)
	clone.character_id = sid
	clone.wounds_taken = 0          # a fresh body (Wounds are separate during the spell)
	clone.spells_known = []         # prevent recursive self-cloning
	clone.is_pc = false             # driven by the companion AI, not a player
	clone.character_name = caster.character_name + " (manifestation)"
	var faction: String = String(state.factions.get(caster_id, FACTION_PLAYER))
	if faction == FACTION_ENEMY:
		add_enemy(state, clone, tile.x, tile.y, dice_engine)
	else:
		var comp := CompanionData.new()
		comp.companion_id = sid
		comp.type = CompanionData.CompanionType.NAMED_ALLY
		comp.display_name = clone.character_name
		comp.character_id = sid
		comp.command = CompanionData.Command.FOLLOW
		comp.command_target_id = caster_id
		comp.yu_rank = 10  # never breaks morale
		add_companion(state, comp, clone, tile.x, tile.y, dice_engine)
	# Bidirectional shared-death link.
	state.divide_soul_pairs[caster_id] = sid
	state.divide_soul_pairs[sid] = caster_id
	return {"clone_id": sid, "placed": true, "faction": faction}


## Build a clay soldier (s34 Soldiers of Clay): Traits/Rings = caster's Earth Ring, attacks with a
## jade stone sword as Kenjutsu 4, Reduction = 2× Earth, standard human wound track (NOT
## Invulnerable — collapses when destroyed).
static func _build_clay_soldier(earth_ring: int) -> SpiritCreatureData:
	var cr := SpiritCreatureData.new()
	cr.id = "clay_soldier"
	cr.display_name = "Clay Soldier"
	cr.realm = Enums.SpiritRealm.NINGEN_DO
	cr.air = earth_ring
	cr.earth = earth_ring
	cr.fire = earth_ring
	cr.water = earth_ring
	cr.attack_name = "Stone Sword"
	cr.attack_rolled = earth_ring + 4   # Agility(=Earth Ring) + Kenjutsu 4, keep Agility
	cr.attack_kept = earth_ring
	cr.damage_rolled = 3                 # stone sword (katana-equivalent, jade), fixed
	cr.damage_kept = 2
	cr.armor_tn = earth_ring * 5 + 5
	cr.reduction = earth_ring * 2
	cr.wounds_dead = 0
	return cr


## Banish a non-native spirit (s37 Draw Closed the Veil): a spirit creature is sent to its home
## realm (removed from the encounter). An embodied spirit (a physical body in Ningen-do, i.e. any
## spirit_creature fighting on the tile map) resists with a Contested Willpower vs the caster's Void.
## Reuses the Furaribi/jade-property repel pattern (erase position + fled_ids). Inert vs non-spirits.
static func _apply_spell_banish_spirit(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or target.spirit_creature == null:
		return {"reason": "not_a_spirit"}
	var cv: int = SpellSystem.get_ring_value(caster, Enums.Ring.VOID)
	var tw: int = maxi(1, target.willpower)
	var caster_roll: int = dice_engine.roll_and_keep(cv, cv, true).total
	var target_roll: int = dice_engine.roll_and_keep(tw, tw, true).total
	if target_roll >= caster_roll:
		return {"reason": "resisted", "id": target_id}
	state.positions.erase(target_id)
	if target_id not in state.fled_ids:
		state.fled_ids.append(target_id)
	return {"id": target_id, "banished": true}


## Ignite every flammable tile in an area (s35 Fiery Wrath) via FireSystem. Centered on the target
## tile (ranged) or the caster. The per-round burn + spread is handled by advance_round's FireSystem
## tick. Returns the count of newly-lit tiles. (The "flesh spared / no spread to adjoining structures"
## GDD nuances are not modeled — the tile layer has no flesh, and FireSystem spread is weather-gated.)
static func _apply_spell_ignite_zone(
	state: MapCombatState, caster_id: int, target_id: int, eff: Dictionary,
) -> Dictionary:
	if state.map == null:
		return {"count": 0}
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	if int(eff.get("range_tiles", 0)) > 0 and state.positions.has(target_id):
		center = state.positions[target_id]
	var radius: int = int(eff.get("aoe_radius", 1))
	var count: int = 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if FireSystem.ignite(state.map, center.x + dx, center.y + dy):
				count += 1
	return {"center": center, "radius": radius, "count": count}


## Snuff non-magical fire in an area (s35 Extinguish): clear burning tiles (→ FLOOR_ASH) within the
## radius of the caster and clear the on_fire flag from any creature in range. Returns the counts.
## (The magical/non-magical distinction is not tracked by FireSystem, so all fire in range is cleared.)
static func _apply_spell_extinguish(
	state: MapCombatState, caster_id: int, eff: Dictionary,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var radius: int = int(eff.get("aoe_radius", 20))
	var tiles_cleared: int = 0
	if state.map != null:
		for idx in state.map.burning_tiles.keys():
			var tx: int = int(idx) % state.map.width
			var ty: int = int(idx) / state.map.width
			if maxi(absi(center.x - tx), absi(center.y - ty)) <= radius:
				state.map.set_delta(tx, ty, Enums.TileType.FLOOR_ASH)
				state.map.burning_tiles.erase(idx)
				tiles_cleared += 1
	var creatures_doused: int = 0
	for cid in state.positions.keys():
		var pos: Vector2i = state.positions[cid]
		if maxi(absi(center.x - pos.x), absi(center.y - pos.y)) > radius:
			continue
		var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if p != null and p.on_fire:
			p.on_fire = false
			creatures_doused += 1
	return {"tiles_cleared": tiles_cleared, "creatures_doused": creatures_doused}


## Restore a living ally's Void Points to maximum (s37 Fill the Emptiness). Touch / same-faction.
static func _apply_spell_restore_void(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData,
) -> Dictionary:
	var ally: L5RCharacterData = target if target != null else state.combatants.get(caster_id, null)
	var aid: int = target_id if target != null else caster_id
	if ally == null or CharacterStats.is_dead(ally):
		return {"reason": "target_invalid"}
	if String(state.factions.get(aid, "")) != String(state.factions.get(caster_id, "")):
		return {"reason": "not_an_ally"}
	var before: int = ally.current_void_points
	VoidSystem.restore_full(ally)
	return {"id": aid, "restored": ally.current_void_points - before}


## Steal one Void Point from the target on a won Contested Void roll (s37 Void Release). The caster
## gains the point (over-cap allowed). Inert vs a target with no Void Points.
static func _apply_spell_steal_void(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	if target.current_void_points <= 0:
		return {"reason": "no_void_to_steal"}
	var cv: int = maxi(1, SpellSystem.get_ring_value(caster, Enums.Ring.VOID))
	var tv: int = maxi(1, SpellSystem.get_ring_value(target, Enums.Ring.VOID))
	if dice_engine.roll_and_keep(cv, cv, true).total <= dice_engine.roll_and_keep(tv, tv, true).total:
		return {"reason": "resisted", "id": target_id}
	target.current_void_points -= 1
	caster.current_void_points += 1
	return {"id": target_id, "stolen": 1}


## Instant-kill spell (s35 Consumed by Five Fires / s37 Unmake the World): reduce the target to
## Dead outright. `contested` (e.g. earth_contested_void) gates the kill behind a roll the caster must
## win. `fire_immune_blocks` aborts vs a Fire-resistant creature. `reciprocal` makes the caster suffer
## the same Wounds it inflicted, unmitigated (the suicidal Consumed-by-Five-Fires cost). Wounds
## inflicted = the count needed to bring the (possibly already wounded) target to its Dead threshold.
static func _apply_spell_instant_kill(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	var rng: int = int(eff.get("range_tiles", 10))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	# "Cannot target creatures resistant to Fire" (Consumed by Five Fires).
	if eff.get("fire_immune_blocks", false) and target.spirit_creature != null \
			and (target.spirit_creature.has_tag("flame_immune") \
				or target.spirit_creature.has_tag("fire_resist_mundane")):
		return {"reason": "fire_resistant", "id": target_id}
	# Contested gate: the caster must WIN (the target resists by winning the named contest).
	var contested: String = String(eff.get("contested", ""))
	if contested != "" and _spell_save_resisted(state, caster, target, contested, 0, dice_engine):
		return {"reason": "resisted", "id": target_id}
	# Dead threshold: spirit = wounds_dead; mortal = 8×per-level + 1 (capacity is the Out boundary).
	var dead_thresh: int
	if target.spirit_creature != null and target.spirit_creature.wounds_dead > 0:
		dead_thresh = target.spirit_creature.wounds_dead
	else:
		dead_thresh = CharacterStats.get_total_wound_capacity(target) + 1
	var inflicted: int = maxi(0, dead_thresh - target.wounds_taken)
	target.wounds_taken = dead_thresh
	var out: Dictionary = {"id": target_id, "killed": CharacterStats.is_dead(target), "inflicted": inflicted}
	# Reciprocal self-damage (Consumed by Five Fires): the caster takes the same Wounds, unmitigated.
	if eff.get("reciprocal", false) and inflicted > 0:
		WoundSystem.apply_damage(caster, inflicted, 0)
		out["caster_wounds"] = inflicted
		out["caster_dead"] = CharacterStats.is_dead(caster)
	return out


## Count living enemy combatants melee-adjacent (Chebyshev 1) to a tile, relative to my_faction.
static func _adjacent_enemy_count(state: MapCombatState, pos: Vector2i, my_faction: String) -> int:
	var n: int = 0
	for cid in state.positions.keys():
		if String(state.factions.get(cid, "")) == my_faction:
			continue
		var ch = state.combatants.get(cid, null)
		if ch == null or CharacterStats.is_dead(ch):
			continue
		var ep: Vector2i = state.positions[cid]
		if maxi(absi(pos.x - ep.x), absi(pos.y - ep.y)) == 1:
			n += 1
	return n


## s36 Hands of the Tides — NPC use heuristic. The GDD effect (swap willing targets' grid positions)
## is faithful + unambiguous; the GDD gives no NPC USE policy, so this picks the one clearly-beneficial
## case and nothing else: RESCUE A WOUNDED ALLY FROM MELEE. Returns [rescue, destination] where the
## rescue ally is a HURT+ same-faction unit (the caster itself qualifies — a shugenja fleeing melee)
## with the most adjacent enemies, and the destination is the LEAST-exposed ally to take its place —
## excluding the caster as a destination unless the caster IS the one being rescued (the spell must
## never teleport the casting shugenja INTO melee to save someone else). Fires only when the swap
## strictly reduces the rescued unit's adjacent-enemy exposure. Capped at Water Ring willing targets
## (a 2-of-N swap is a valid GDD "combination"). Returns [] when no such beneficial rescue exists.
static func _reposition_best_pair(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, radius: int,
) -> Array:
	var cf: String = String(state.factions.get(caster_id, ""))
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var max_targets: int = SpellSystem.get_ring_value(caster, Enums.Ring.WATER)
	if max_targets < 2:
		return []
	# Gather candidate willing allies within range, capped at the willing-target count.
	var cands: Array = []  # {id, exp, wounded}
	for aid in state.positions.keys():
		if String(state.factions.get(aid, "")) != cf:
			continue
		var ach = state.combatants.get(aid, null)
		if ach == null or CharacterStats.is_dead(ach):
			continue
		var apos: Vector2i = state.positions[aid]
		if maxi(absi(center.x - apos.x), absi(center.y - apos.y)) > radius:
			continue
		cands.append({
			"id": int(aid),
			"exp": _adjacent_enemy_count(state, apos, cf),
			"wounded": CharacterStats.get_wound_level(ach) >= Enums.WoundLevel.HURT,
		})
		if cands.size() >= max_targets:
			break
	if cands.size() < 2:
		return []
	# Rescue target = the most melee-pressured WOUNDED ally (caster eligible). No wounded-in-melee
	# ally → the spell has no clearly-beneficial NPC use, so don't cast it.
	var rescue: Dictionary = {}
	for c in cands:
		if not c["wounded"] or int(c["exp"]) <= 0:
			continue
		if rescue.is_empty() or int(c["exp"]) > int(rescue["exp"]):
			rescue = c
	if rescue.is_empty():
		return []
	# Destination = least-exposed ally to swap in; never the casting shugenja (unless the shugenja
	# is itself the one being rescued).
	var dest: Dictionary = {}
	for c in cands:
		if int(c["id"]) == int(rescue["id"]):
			continue
		if int(c["id"]) == caster_id and int(rescue["id"]) != caster_id:
			continue
		if dest.is_empty() or int(c["exp"]) < int(dest["exp"]):
			dest = c
	if dest.is_empty():
		return []
	if int(rescue["exp"]) <= int(dest["exp"]):
		return []  # no strictly-beneficial swap
	return [int(rescue["id"]), int(dest["id"])]


## Apply s36 Hands of the Tides: swap the grid positions of the rescue/destination ally pair.
static func _apply_spell_reposition(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData, eff: Dictionary,
) -> Dictionary:
	var radius: int = int(eff.get("range_tiles", 20))
	var pair: Array = _reposition_best_pair(state, caster_id, caster, radius)
	if pair.is_empty():
		return {"swapped": []}
	var a: int = pair[0]
	var b: int = pair[1]
	var pa: Vector2i = state.positions[a]
	state.positions[a] = state.positions[b]
	state.positions[b] = pa
	return {"swapped": [a, b]}


## Build a shiryo ancestor spirit (s33 Defender From Beyond, Kitsu only): the GDD "typical shiryo"
## has the Spirit trait, all Rings at 3, and Rank 4 in relevant Skills. Attacks as Ring 3 + Skill 4
## (keep Ring); katana-equivalent damage; standard human wound track from Earth 3. Not Invulnerable.
static func _build_shiryo() -> SpiritCreatureData:
	var cr := SpiritCreatureData.new()
	cr.id = "shiryo"
	cr.display_name = "Ancestral Shiryo"
	cr.realm = Enums.SpiritRealm.NINGEN_DO  # a Yomi spirit manifesting to aid in Ningen-do
	cr.air = 3
	cr.earth = 3
	cr.fire = 3
	cr.water = 3
	cr.attack_name = "Spirit Blade"
	cr.attack_rolled = 3 + 4  # Ring 3 + Rank 4 relevant Skill, keep Ring
	cr.attack_kept = 3
	cr.damage_rolled = 3      # katana-equivalent
	cr.damage_kept = 2
	cr.armor_tn = 3 * 5 + 5   # Reflexes (= Air Ring 3) × 5 + 5
	cr.reduction = 0
	cr.wounds_dead = 0        # standard human wound track from Earth 3
	return cr


## Register an area ward (s34 Earth's Protection / s35 Ward of Thunder) centered on the caster.
## Stored in spell_zones with kind "ward". ward_elements = the Ring(s) it suppresses; cast_tn =
## TN penalty to a hostile in-area cast of those elements; dr_rolled/dr_kept = damage reduction to
## warded-element spells striking creatures inside. Returns {center, radius, expiry_round}.
static func _apply_spell_ward(
	state: MapCombatState, caster_id: int, eff: Dictionary, spell_id: String,
) -> Dictionary:
	var center: Vector2i = state.positions.get(caster_id, Vector2i.ZERO)
	var dur: int = int(eff.get("duration_rounds", 10))
	var ward: Dictionary = {
		"kind": "ward", "center": center, "radius": int(eff.get("aoe_radius", 2)),
		"ward_elements": eff.get("ward_elements", []),
		"cast_tn": int(eff.get("cast_tn_penalty", 0)),
		"dr_rolled": int(eff.get("dr_reduction_rolled", 0)),
		"dr_kept": int(eff.get("dr_reduction_kept", 0)),
		"caster_id": caster_id, "expiry_round": state.combat.round_number + dur, "spell_id": spell_id,
	}
	state.spell_zones.append(ward)
	return {"center": center, "radius": ward["radius"], "expiry_round": ward["expiry_round"]}


## Ward TN penalty for a spell about to be cast: sum the cast_tn of every active ward NOT owned by
## the caster whose area contains the caster and whose ward_elements include the spell's element.
static func _ward_cast_penalty(state: MapCombatState, caster_id: int, spell_id: String) -> int:
	if state.spell_zones.is_empty():
		return 0
	var element: int = SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("e", -1)
	if element < 0:
		return 0
	var cpos: Vector2i = state.positions.get(caster_id, Vector2i(-9999, -9999))
	var pen: int = 0
	for z in state.spell_zones:
		if String(z.get("kind", "")) != "ward" or int(z.get("caster_id", -1)) == caster_id:
			continue
		if not (element in z.get("ward_elements", [])):
			continue
		var c: Vector2i = z["center"]
		if maxi(absi(c.x - cpos.x), absi(c.y - cpos.y)) <= int(z.get("radius", 0)):
			pen += int(z.get("cast_tn", 0))
	return pen


## Damage reduction (rolled/kept) applied to a warded-element spell striking a creature standing
## inside a ward not owned by the spell's caster. Returns [d_rolled, d_kept] to subtract (min 1k1).
static func _ward_dr_reduction(
	state: MapCombatState, caster_id: int, element: int, target_pos: Vector2i,
) -> Array:
	var dr: int = 0
	var dk: int = 0
	for z in state.spell_zones:
		if String(z.get("kind", "")) != "ward" or int(z.get("caster_id", -1)) == caster_id:
			continue
		if not (element in z.get("ward_elements", [])):
			continue
		var c: Vector2i = z["center"]
		if maxi(absi(c.x - target_pos.x), absi(c.y - target_pos.y)) <= int(z.get("radius", 0)):
			dr += int(z.get("dr_rolled", 0))
			dk += int(z.get("dr_kept", 0))
	return [dr, dk]


# Resolves a damage-spell's condition rider (s31–s37). Returns the applied condition string,
# "resisted" on a successful save, or "" when the target has no Participant.
static func _apply_spell_rider(
	state: MapCombatState, caster: L5RCharacterData, ch: L5RCharacterData,
	cid: int, rider: Dictionary, dice_engine: DiceEngine,
) -> String:
	var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
	if p == null:
		return ""
	if _spell_save_resisted(state, caster, ch, rider.get("save", "none"),
			rider.get("save_tn", 0), dice_engine):
		return "resisted"
	var cond: String = rider.get("condition", "")
	var dur: int = rider.get("duration_rounds", 0)
	if dur > 0:
		IndividualCombat.apply_timed_condition(p, cond, state.combat.round_number + dur)
	else:
		IndividualCombat.apply_condition(p, cond)
	return cond


# Resolves a spell save (rider or status). Returns true if the target resists. Save types:
# "none" (never resists — auto-apply), "earth_flat"/"stamina_flat" (Ring/Trait roll vs save_tn),
# "earth_contested_air" (target Earth vs caster Air; ties go to the target).
static func _spell_save_resisted(
	state: MapCombatState, caster: L5RCharacterData, ch: L5RCharacterData,
	save: String, tn: int, dice_engine: DiceEngine,
) -> bool:
	match save:
		"earth_flat":
			var e: int = SpellSystem.get_ring_value(ch, Enums.Ring.EARTH)
			return dice_engine.roll_and_keep(e, e, true).total >= tn
		"stamina_flat":
			var sta: int = maxi(1, ch.stamina)
			return dice_engine.roll_and_keep(sta, sta, true).total >= tn
		"willpower_flat":
			# s33 Your Heart's Enemy: a Willpower roll vs the Fear TN avoids the AFRAID condition.
			var wil: int = maxi(1, ch.willpower)
			return dice_engine.roll_and_keep(wil, wil, true).total >= tn
		"earth_contested_air":
			var te: int = SpellSystem.get_ring_value(ch, Enums.Ring.EARTH)
			var ca: int = SpellSystem.get_ring_value(caster, Enums.Ring.AIR)
			# Contested: the target must beat the caster's Air roll to avoid the effect.
			return dice_engine.roll_and_keep(te, te, true).total \
				>= dice_engine.roll_and_keep(ca, ca, true).total
		"strength_contested_earth":
			# s34 Earthen Wave: target rolls Raw Strength vs the caster's Earth to avoid Knockdown.
			var ts: int = maxi(1, ch.strength)
			var ce: int = SpellSystem.get_ring_value(caster, Enums.Ring.EARTH)
			return dice_engine.roll_and_keep(ts, ts, true).total \
				>= dice_engine.roll_and_keep(ce, ce, true).total
		"strength_contested_water":
			# s36 The Swell of the Storm: target rolls Raw Strength vs the caster's Water to avoid Knockdown.
			var tsw: int = maxi(1, ch.strength)
			var cw: int = SpellSystem.get_ring_value(caster, Enums.Ring.WATER)
			return dice_engine.roll_and_keep(tsw, tsw, true).total \
				>= dice_engine.roll_and_keep(cw, cw, true).total
		"agility_flat":
			# s34 Murmur of Earth: Agility roll vs a flat TN.
			var ag: int = maxi(1, ch.agility)
			return dice_engine.roll_and_keep(ag, ag, true).total >= tn
		"reflexes_contested_earth":
			# s34 Maw of the Earth: Reflexes vs the caster's Earth to avoid falling in.
			var tr: int = maxi(1, ch.reflexes)
			var me: int = SpellSystem.get_ring_value(caster, Enums.Ring.EARTH)
			return dice_engine.roll_and_keep(tr, tr, true).total \
				>= dice_engine.roll_and_keep(me, me, true).total
		"earth_contested":
			# s34 Major Binding: target Earth vs caster Earth; the target resists if it wins.
			var bte: int = SpellSystem.get_ring_value(ch, Enums.Ring.EARTH)
			var bce: int = SpellSystem.get_ring_value(caster, Enums.Ring.EARTH)
			return dice_engine.roll_and_keep(bte, bte, true).total \
				>= dice_engine.roll_and_keep(bce, bce, true).total
		"earth_contested_void":
			# s37 Unmake the World: caster Void vs target Earth; the caster must WIN, so the target
			# resists when its Earth roll ties or beats the caster's Void roll.
			var ute: int = SpellSystem.get_ring_value(ch, Enums.Ring.EARTH)
			var ucv: int = SpellSystem.get_ring_value(caster, Enums.Ring.VOID)
			return dice_engine.roll_and_keep(maxi(1, ute), maxi(1, ute), true).total \
				>= dice_engine.roll_and_keep(maxi(1, ucv), maxi(1, ucv), true).total
		"fire_contested":
			# s35 Death of Flame: target Fire vs caster Fire; the target resists if it wins.
			var fte: int = SpellSystem.get_ring_value(ch, Enums.Ring.FIRE)
			var fce: int = SpellSystem.get_ring_value(caster, Enums.Ring.FIRE)
			return dice_engine.roll_and_keep(maxi(1, fte), maxi(1, fte), true).total \
				>= dice_engine.roll_and_keep(maxi(1, fce), maxi(1, fce), true).total
		"void_contested":
			# s37 Essence of Void: target Void vs caster Void; the target resists if it wins.
			var tv: int = SpellSystem.get_ring_value(ch, Enums.Ring.VOID)
			var cv: int = SpellSystem.get_ring_value(caster, Enums.Ring.VOID)
			return dice_engine.roll_and_keep(maxi(1, tv), maxi(1, tv), true).total \
				>= dice_engine.roll_and_keep(maxi(1, cv), maxi(1, cv), true).total
		"willpower_contested":
			# s34 Prison of Earth: target Willpower vs caster Willpower; the target resists if it wins.
			var tw2: int = maxi(1, ch.willpower)
			var cw2: int = maxi(1, caster.willpower)
			return dice_engine.roll_and_keep(tw2, tw2, true).total \
				>= dice_engine.roll_and_keep(cw2, cw2, true).total
		"willpower_contested_caster_fire":
			# s35 Haze of Battle: target Willpower vs caster Willpower + Fire Ring (flat bonus to the
			# caster's roll per "caster adds Fire Ring to their roll"); the target resists if it wins.
			var hw: int = maxi(1, ch.willpower)
			var hcw: int = maxi(1, caster.willpower)
			var hcf: int = SpellSystem.get_ring_value(caster, Enums.Ring.FIRE)
			return dice_engine.roll_and_keep(hw, hw, true).total \
				>= dice_engine.roll_and_keep(hcw, hcw, true).total + hcf
		_:
			return false  # "none" — auto-apply
	return false


## Sodatsu no Oni Shugenja's Bane retaliation (s54.5): a Free Action picking one of three
## modes with the absorbed spell's energy. NPC heuristic: heal if wounded, else bolt the
## caster if it is a reachable enemy, else harden its membrane.
static func _sodatsu_bane_retaliate(
	state: MapCombatState,
	sodatsu_id: int,
	sodatsu: L5RCharacterData,
	caster_id: int,
	caster: L5RCharacterData,
	ml: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var s_p: IndividualCombat.Participant = state.combat.participants.get(sodatsu_id, null)
	# (1) Heal 3 × ML Wounds if injured.
	if sodatsu.wounds_taken > 0:
		WoundSystem.heal_wounds(sodatsu, 3 * ml)
		return {"mode": "heal", "wounds_healed": 3 * ml}
	# (2) Bolt the caster: 4k4 attack vs Armor TN, DR = ML (k2 PROVISIONAL), within 50 ft.
	var enemy: bool = state.factions.get(caster_id, FACTION_NEUTRAL) \
			!= state.factions.get(sodatsu_id, FACTION_ENEMY)
	var in_range: bool = _chebyshev(state.positions.get(sodatsu_id, Vector2i(-999, -999)),
			state.positions.get(caster_id, Vector2i(999, 999))) <= BANE_BOLT_RANGE_TILES
	if enemy and in_range and not CharacterStats.is_dead(caster):
		var c_p: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
		var atk: int = dice_engine.roll_and_keep(BANE_BOLT_ROLLED, BANE_BOLT_KEPT, true).total
		var atn: int = IndividualCombat.get_armor_tn(caster, c_p, dice_engine, false)
		if atk >= atn:
			var dmg: int = dice_engine.roll_and_keep(ml, BANE_BOLT_DR_KEPT, true).total
			WoundSystem.apply_damage(caster, dmg, maxi(0, caster.armor_reduction))
			return {"mode": "bolt", "hit": true, "damage": dmg, "target_id": caster_id}
		return {"mode": "bolt", "hit": false, "target_id": caster_id}
	# (3) Harden membrane: +3 × ML Armor TN for 3 rounds (stacks).
	if s_p != null:
		IndividualCombat.add_timed_modifier(s_p, "armor_tn", 3 * ml,
			state.combat.round_number + BANE_ARMOR_ROUNDS, "shugenjas_bane")
	return {"mode": "armor", "armor_bonus": 3 * ml, "rounds": BANE_ARMOR_ROUNDS}


## Spend a Void Point to add +1k1 to next attack/defense roll (GDD s40).
## Free action.
static func execute_void_spend(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	count: int = 1,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}

	# s37 Altering the Course: while active, the once-per-round cap is lifted and several Void
	# Points may be spent on one roll (+NkN). Otherwise the normal one-per-round rule applies.
	var multi: bool = IndividualCombat.get_timed_modifier_total(p, "multi_void_spend") > 0
	if p.void_spent_this_round and not multi:
		return {"success": false, "reason": "void_already_spent_this_round"}

	# s54.12 Furaribi Soul Touch: a touched character cannot spend Void Points.
	# Furaribi Soul Touch (permanent flag) OR s37 Severed from the Stream (timed Void-lock debuff).
	if p.void_locked or IndividualCombat.get_timed_modifier_total(p, "void_locked") > 0:
		return {"success": false, "reason": "void_locked"}

	# Spend VP for +1k1 each on the next roll (GDD s40; +NkN under Altering the Course). Must
	# check success BEFORE marking the once-per-round slot consumed.
	var n: int = maxi(1, count) if multi else 1
	var result: Dictionary = VoidSystem.spend_n_for_roll(character, n)
	if not result.get("success", false):
		return {"success": false, "reason": "no_void_points"}

	p.void_spent_this_round = true
	p.void_roll_pending_rolled += int(result.get("rolled_bonus", 1))
	p.void_roll_pending_kept += int(result.get("kept_bonus", 1))
	ts.consume_free()

	state.combat_log.append({
		"type": "void_spend",
		"round": state.combat.round_number,
		"char_id": char_id,
		"vp_spent": int(result.get("spent", 1)),
	})
	return {"success": true, "vp_spent": int(result.get("spent", 1))}


## Activate a kiho on a combatant during the skirmish, paying its GDD s38 cost.
## IndividualCombat.activate_kiho does the known + active-slot validation but
## leaves the cost to the caller; this is that cost path (s38a, LOCKED). Methods:
##   "void_point"         — Free action; spends one Void Point (auto-succeeds).
##   "meditation_complex" — Complex action; Meditation (Void) roll vs TN 15.
##   "meditation_simple"  — Simple action; Meditation (Void) roll vs TN 30.
## A failed Meditation roll still spends the action (no activation). Atemi kiho
## are strikes (resolve_atemi_strike), not slot buffs, and are not activated here.
static func execute_activate_kiho(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	kiho_name: String,
	method: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}
	if not character.kiho.has(kiho_name):
		return {"success": false, "reason": "kiho_not_known"}
	# Atemi kiho are delivered as a strike (resolve_atemi_strike), not held as a
	# slot buff — they are never "activated" into active_kiho.
	if KihoSystem.activation_options(kiho_name).get("is_atemi", false):
		return {"success": false, "reason": "atemi_not_activatable"}
	# Validate the active-slot constraint before paying any cost.
	var slot: Dictionary = KihoSystem.can_activate(kiho_name, p.active_kiho)
	if not slot.get("ok", false):
		return {"success": false, "reason": slot.get("reason", "slot_unavailable")}

	var wl: int = CharacterStats.get_wound_level(character)
	match method:
		"void_point":
			# Free action (s38a): spend one Void Point as the activation cost.
			if not VoidSystem.can_spend(character):
				return {"success": false, "reason": "no_void_points"}
			VoidSystem.spend(character)
			ts.consume_free()
		"meditation_complex":
			if ts.is_down_restricted(wl):
				return {"success": false, "reason": "down_only_free_actions"}
			if not ts.can_use_complex():
				return {"success": false, "reason": "no_complex_action"}
			var rc: Dictionary = SkillResolver.resolve_skill_check(
				character, dice_engine, "Meditation", KihoSystem.ACTIVATION_TN_COMPLEX)
			ts.consume_complex()
			if not rc.get("success", false):
				state.combat_log.append({
					"type": "kiho_activation_failed", "char_id": char_id,
					"kiho": kiho_name, "round": state.combat.round_number})
				return {"success": false, "reason": "meditation_failed", "action_spent": true}
		"meditation_simple":
			if ts.is_down_restricted(wl):
				return {"success": false, "reason": "down_only_free_actions"}
			if not ts.can_use_simple():
				return {"success": false, "reason": "no_simple_action"}
			var rs: Dictionary = SkillResolver.resolve_skill_check(
				character, dice_engine, "Meditation", KihoSystem.ACTIVATION_TN_SIMPLE)
			ts.consume_simple()
			if not rs.get("success", false):
				state.combat_log.append({
					"type": "kiho_activation_failed", "char_id": char_id,
					"kiho": kiho_name, "round": state.combat.round_number})
				return {"success": false, "reason": "meditation_failed", "action_spent": true}
		_:
			return {"success": false, "reason": "unknown_method"}

	# Cost paid (and any Meditation roll passed) — install the kiho. activate_kiho
	# re-checks known + slot, so this cannot occupy a slot it just failed.
	var act: Dictionary = IndividualCombat.activate_kiho(character, p, kiho_name)
	if not act.get("ok", false):
		return {"success": false, "reason": act.get("reason", "activation_failed")}
	# Shadowed Mountain: a fresh activation re-arms its once-per-activation stance switch.
	if kiho_name == "Shadowed Mountain":
		p.shadowed_mountain_used = false
	# Record a round-based expiry for kiho that "Last Rounds equal to [Ring]" (s38).
	var dur_spec: Dictionary = KihoSystem.KIHO_DATA.get(kiho_name, {}).get("duration", {})
	if not dur_spec.is_empty():
		var dur: int = CharacterStats.get_ring_value(character, dur_spec.get("ring", Enums.Ring.EARTH)) * int(dur_spec.get("mult", 1))
		p.active_kiho_expiry[kiho_name] = state.combat.round_number + dur
	state.combat_log.append({
		"type": "kiho_activated", "char_id": char_id, "kiho": kiho_name,
		"method": method, "round": state.combat.round_number})
	return {"success": true, "kiho": kiho_name, "method": method}


## Basic monk AI (structural — mirrors the other _npc_* heuristics; the GDD gives
## no NPC kiho-activation policy): on its first turn a monk that knows a non-atemi
## buff kiho and has a Void Point activates one (the s38a Free-action method) so a
## monk on a PC mission map actually fights with its kiho up. Returns the action
## dict on activation, else {}.
static func _npc_maybe_activate_kiho(
	state: MapCombatState,
	npc_id: int,
	npc: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if npc.school_type != Enums.SchoolType.MONK:
		return {}
	if npc.kiho.is_empty() or not VoidSystem.can_spend(npc):
		return {}
	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {}
	for k: String in npc.kiho:
		var opts: Dictionary = KihoSystem.activation_options(k)
		if opts.is_empty() or opts.get("is_atemi", false):
			continue
		if not KihoSystem.can_activate(k, p.active_kiho).get("ok", false):
			continue
		if k == "Touch the Void Dragon":
			if state.environment_ring < 0:
				continue  # no terrain Ring to boost — try the next known kiho
			return execute_activate_touch_void_dragon(state, npc_id, npc, "void_point", dice_engine)
		return execute_activate_kiho(state, npc_id, npc, k, "void_point", dice_engine)
	return {}


## Depths of the World (s38 Earth, Complex Action): immediately attempt to recover from
## a non-permanent Condition that allows a recovery roll (Stunned, Dazed). May be used
## even while Stunned (it bypasses the can-act restriction). Returns the recovered list.
static func execute_depths_of_the_world(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("Depths of the World"):
		return {"success": false, "reason": "kiho_not_known"}
	var p: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}
	ts.consume_complex()  # Complex Action — usable even while Stunned (s38)
	var recovered: Array = []
	if IndividualCombat.CONDITION_STUNNED in p.conditions:
		if IndividualCombat.attempt_recover_stunned(caster, p, dice_engine):
			recovered.append("stunned")
	if IndividualCombat.CONDITION_DAZED in p.conditions:
		if IndividualCombat.attempt_recover_dazed(caster, p, p.daze_failed_recovery_attempts + 1, dice_engine):
			recovered.append("dazed")
	state.combat_log.append({
		"type": "depths_of_the_world", "round": state.combat.round_number,
		"caster_id": caster_id, "recovered": recovered})
	return {"success": true, "recovered": recovered}


## To the Last Breath (s38 Void): grant a selected ally within 20 ft (4 tiles) one Void
## Point (capped at their Void Ring). No target may benefit more than twice per skirmish.
static func execute_to_the_last_breath(
	state: MapCombatState,
	caster_id: int,
	target_id: int,
	caster: L5RCharacterData,
	target: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("To the Last Breath"):
		return {"success": false, "reason": "kiho_not_known"}
	if int(state.last_breath_uses.get(target_id, 0)) >= 2:
		return {"success": false, "reason": "target_at_use_limit"}
	var apos: Vector2i = state.positions.get(caster_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0 or _chebyshev(apos, tpos) > 4:
		return {"success": false, "reason": "out_of_range"}
	ts.consume_complex()
	var cap: int = CharacterStats.get_ring_value(target, Enums.Ring.VOID)
	var before: int = target.current_void_points
	target.current_void_points = mini(cap, target.current_void_points + 1)
	state.last_breath_uses[target_id] = int(state.last_breath_uses.get(target_id, 0)) + 1
	return {"success": true, "target_id": target_id, "vp_before": before, "vp_after": target.current_void_points}


## Bishamon's Grasp (s38, while active, Defense/Full Defense only): on the caster's Turn,
## make a free-action Grapple against the first co-located opponent who attacked the caster
## since their last Turn (overrides the Defense-stance no-attack restriction). LIMITATION:
## the single grapple_partner_id models one grapple, so one opponent is grabbed per Turn
## (the GDD's "one per qualifying opponent" multi-grab needs a multi-partner model).
static func execute_bishamons_grasp(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	var c_p: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
	if c_p == null:
		return {"success": false, "reason": "participant_missing"}
	if "Bishamon's Grasp" not in c_p.active_kiho:
		return {"success": false, "reason": "kiho_not_active"}
	if c_p.stance != Enums.Stance.DEFENSE and c_p.stance != Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "requires_defense_stance"}
	if c_p.grapple_partner_id >= 0:
		return {"success": false, "reason": "already_grappling"}
	var cpos: Vector2i = state.positions.get(caster_id, Vector2i(-1, -1))
	for opp_id: int in c_p.attacked_by_ids:
		var opp: L5RCharacterData = chars_by_id.get(opp_id, null)
		var o_p: IndividualCombat.Participant = state.combat.participants.get(opp_id, null)
		if opp == null or o_p == null or CharacterStats.is_dead(opp):
			continue
		var opos: Vector2i = state.positions.get(opp_id, Vector2i(-1, -1))
		if cpos.x < 0 or opos.x < 0 or _chebyshev(cpos, opos) > MELEE_RANGE_TILES:
			continue
		# Free-action grapple (no Complex consumed) — core mirrors execute_grapple_initiate.
		var grapple_tn: int = opp.reflexes * 5 + 5
		var gr: Dictionary = IndividualCombat.initiate_grapple(caster, c_p, grapple_tn, dice_engine, "Jiujutsu")
		if gr.get("apply_grappled_to_target", false):
			IndividualCombat.apply_condition(o_p, IndividualCombat.CONDITION_GRAPPLED)
			o_p.grapple_partner_id = caster_id
			c_p.grapple_partner_id = opp_id
			c_p.grapple_in_control = true
			o_p.grapple_in_control = false
		state.combat_log.append({
			"type": "bishamons_grasp", "round": state.combat.round_number,
			"caster_id": caster_id, "target_id": opp_id, "grappled": gr.get("apply_grappled_to_target", false)})
		return {"success": true, "target_id": opp_id, "grappled": gr.get("apply_grappled_to_target", false)}
	return {"success": false, "reason": "no_qualifying_attacker"}


## Riding the Clouds (s38 Air, while active): a Simple Move Action to leap up to Air Ring
## ×10 ft (= ×2 tiles) to any free passable tile (ignoring terrain cost — it is a jump).
## The kiho is expended after one leap. Returns the new position.
static func execute_riding_the_clouds(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	dest: Vector2i,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {"success": false, "reason": "participant_missing"}
	if "Riding the Clouds" not in p.active_kiho:
		return {"success": false, "reason": "kiho_not_active"}
	if not ts.can_use_simple():
		return {"success": false, "reason": "no_simple_actions_remaining"}
	var pos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if pos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(pos, dest) > CharacterStats.get_ring_value(character, Enums.Ring.AIR) * 2:
		return {"success": false, "reason": "beyond_leap_range"}
	for cid: int in state.positions:
		if cid != char_id and state.positions[cid] == dest:
			return {"success": false, "reason": "tile_occupied"}
	if state.map != null and not MovementSystem.is_passable(state.map.get_tile(dest.x, dest.y)):
		return {"success": false, "reason": "tile_impassable"}
	state.positions[char_id] = dest
	ts.consume_simple()
	p.active_kiho.erase("Riding the Clouds")  # expended after one leap
	state.combat_log.append({
		"type": "riding_the_clouds", "round": state.combat.round_number,
		"char_id": char_id, "leaped_to": dest})
	return {"success": true, "leaped_to": dest}


## Calling the East Wind (s38 Air, Complex Action): leap up to Air Ring ×10 ft (= ×2
## tiles) to a free tile adjacent to the target, then make an unarmed kick with +1k0
## damage (and a Free Raise toward Knockdown, recorded as metadata). Fails if no landing
## tile is reachable within the leap.
static func execute_calling_the_east_wind(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not attacker.kiho.has("Calling the East Wind"):
		return {"success": false, "reason": "kiho_not_known"}
	if ts.is_down_restricted(CharacterStats.get_wound_level(attacker)):
		return {"success": false, "reason": "down_only_free_actions"}
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	var leap_tiles: int = CharacterStats.get_ring_value(attacker, Enums.Ring.AIR) * 2  # Air×10 ft
	var dest: Vector2i = apos
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		dest = Vector2i(-1, -1)
		var occ: Dictionary = {}
		for cid: int in state.positions:
			occ[state.positions[cid]] = true
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var cand: Vector2i = Vector2i(tpos.x + dx, tpos.y + dy)
				if _chebyshev(apos, cand) > leap_tiles or occ.has(cand):
					continue
				if state.map != null and not MovementSystem.is_passable(state.map.get_tile(cand.x, cand.y)):
					continue
				dest = cand
				break
			if dest.x >= 0:
				break
		if dest.x < 0:
			return {"success": false, "reason": "no_leap_landing"}
		state.positions[attacker_id] = dest
	ts.consume_complex()
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, _is_being_guarded(state, target_id), "unarmed")
	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, "unarmed", armor_tn, 0, dice_engine, false, false, false, "", {"opponent_clan": target.clan})
	if result.get("hit", false):
		var dmg: Dictionary = IndividualCombat.resolve_damage(attacker, "unarmed", 1, 0, dice_engine, a_p)  # +1k0 leap bonus
		var red: int = IndividualCombat.total_defender_reduction(target, t_p, attacker, a_p, "unarmed")
		var wd: Dictionary = WoundSystem.apply_damage(target, dmg["raw_damage"], red)
		result["wounds_inflicted"] = wd.get("final_damage", 0)
		result["target_dead"] = CharacterStats.is_dead(target)
	result["leaped_to"] = dest
	result["knockdown_free_raise"] = true
	if not result.has("reason"):
		result["success"] = true
	state.combat_log.append({
		"type": "calling_the_east_wind", "round": state.combat.round_number,
		"attacker_id": attacker_id, "target_id": target_id, "leaped_to": dest, "hit": result.get("hit", false)})
	return result


## Effective facing of a participant: their tracked heading, or — if unset (0,0) — the
## direction toward the nearest living enemy (the owner-chosen NPC default, 2026-06-12).
static func _effective_facing(state: MapCombatState, char_id: int) -> Vector2i:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p != null and p.facing != Vector2i(0, 0):
		return p.facing
	# Face the nearest enemy.
	var my_faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	var mypos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	if mypos.x < 0:
		return Vector2i(1, 0)
	var best: Vector2i = Vector2i(1, 0)
	var best_d: int = 1 << 30
	for cid: int in state.positions:
		if cid == char_id or state.factions.get(cid, FACTION_NEUTRAL) == my_faction:
			continue
		if _is_participant_out(state, cid):
			continue
		var opos: Vector2i = state.positions[cid]
		var d: int = _chebyshev(mypos, opos)
		if d < best_d:
			best_d = d
			best = Vector2i(signi(opos.x - mypos.x), signi(opos.y - mypos.y))
	return best if best != Vector2i(0, 0) else Vector2i(1, 0)


## True if `target` lies in the forward half-arc of `facing` from `origin`, within range.
## (Dot product > 0 = in front; Chebyshev distance gates range.)
static func _in_forward_arc(origin: Vector2i, facing: Vector2i, target: Vector2i, range_tiles: int) -> bool:
	if origin == target or _chebyshev(origin, target) > range_tiles:
		return false
	var d: Vector2i = target - origin
	return d.x * facing.x + d.y * facing.y > 0


## True if `target` lies in a forward cone of the given length that widens linearly to
## `end_half_width` tiles at its far end (Inari's Wrath geometry, s38).
static func _in_cone(origin: Vector2i, facing: Vector2i, target: Vector2i, length_tiles: int, end_half_width: float) -> bool:
	if origin == target or facing == Vector2i(0, 0):
		return false
	var d: Vector2i = target - origin
	# Distance along the facing axis (projection), and perpendicular offset.
	var along: int = d.x * facing.x + d.y * facing.y  # facing is a unit step (incl. diagonals)
	if along <= 0 or along > length_tiles:
		return false
	var perp: float = abs(float(d.x) * float(facing.y) - float(d.y) * float(facing.x))
	# Normalize the diagonal facing length (|facing| is √2 for diagonals) so `along`/`perp`
	# are in tile units, then widen the allowed half-width linearly along the cone.
	var flen: float = sqrt(float(facing.x * facing.x + facing.y * facing.y))
	var along_t: float = float(along) / flen
	var perp_t: float = perp / flen
	return perp_t <= end_half_width * (along_t / float(length_tiles)) + 0.5


## Touch the Void Dragon (s38): maps a TerrainType to the Ring it boosts, per the GDD's
## environment list — mountains=Earth, seashore=Water, plains=Air, desert/volcanic=Fire.
## Terrains the GDD does not name (forest, swamp, hills, river delta) yield -1 (no boost).
static func environment_ring_for_terrain(terrain_type: int) -> int:
	match terrain_type:
		Enums.TerrainType.MOUNTAINS: return Enums.Ring.EARTH
		Enums.TerrainType.COASTAL:   return Enums.Ring.WATER   # seashore
		Enums.TerrainType.PLAINS:    return Enums.Ring.AIR
		Enums.TerrainType.WASTELAND: return Enums.Ring.FIRE    # desert
		_:                           return -1


## Touch the Void Dragon (s38 Void Internal): while active, one Ring and its associated Traits
## are one Rank higher; which Ring depends on the skirmish terrain (set on MapCombatState).
## Routes through the standard activation cost/slot path, then stamps the boosted Ring on the
## caster's Participant — read at the combat-roll hooks (attack/damage/Armor TN/Initiative)
## and by the caster's own kiho Ring rolls.
static func execute_activate_touch_void_dragon(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	method: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	if not character.kiho.has("Touch the Void Dragon"):
		return {"success": false, "reason": "kiho_not_known"}
	if state.environment_ring < 0:
		return {"success": false, "reason": "no_environmental_ring"}
	var act: Dictionary = execute_activate_kiho(state, char_id, character, "Touch the Void Dragon", method, dice_engine)
	if not act.get("success", false):
		return act
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p != null:
		p.void_dragon_ring = state.environment_ring
	act["boosted_ring"] = state.environment_ring
	return act


## Slap the Wave (s38 Water): spend a Void Point (no roll to activate), then everyone in the
## caster's forward-facing arc within Water Ring ×5 ft (= Water tiles) makes a Contested
## Water Roll against the caster or becomes Dazed. Affects all factions in the arc.
static func execute_slap_the_wave(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("Slap the Wave"):
		return {"success": false, "reason": "kiho_not_known"}
	if caster.current_void_points < 1:
		return {"success": false, "reason": "no_void_points"}
	if not state.combat.participants.has(caster_id):
		return {"success": false, "reason": "participant_missing"}
	caster.current_void_points -= 1
	var cpos: Vector2i = state.positions.get(caster_id, Vector2i(-1, -1))
	var facing: Vector2i = _effective_facing(state, caster_id)
	var rng: int = CharacterStats.get_ring_value(caster, Enums.Ring.WATER)  # ×5 ft = ×1 tile
	var cw: int = maxi(1, rng)
	var dazed: Array = []
	for cid: int in state.combat.participants:
		if cid == caster_id:
			continue
		var tc: L5RCharacterData = chars_by_id.get(cid, null)
		if tc == null or CharacterStats.is_dead(tc):
			continue
		var tpos: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
		if tpos.x < 0 or not _in_forward_arc(cpos, facing, tpos, rng):
			continue
		if dice_engine.roll_and_keep(cw, cw, true).total > dice_engine.roll_and_keep(maxi(1, CharacterStats.get_ring_value(tc, Enums.Ring.WATER)), maxi(1, CharacterStats.get_ring_value(tc, Enums.Ring.WATER)), true).total:
			IndividualCombat.apply_condition(state.combat.participants[cid], IndividualCombat.CONDITION_DAZED)
			dazed.append(cid)
	state.combat_log.append({
		"type": "slap_the_wave", "round": state.combat.round_number,
		"caster_id": caster_id, "dazed": dazed})
	return {"success": true, "dazed": dazed}


## Inari's Wrath (s38 Air): Round 1 — spend a Void Point + a Complex Action to hold a deep
## breath. Round 2 — exhale (Complex Action) a freezing cone (School Rank ×5 ft long, ×2 ft
## wide at the end), dealing Air-Ring cold damage (Air k Air, bypassing Reduction) to every
## living creature caught in it. `phase`: "inhale" arms it, "exhale" fires it.
static func execute_inaris_wrath(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	phase: String,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("Inari's Wrath"):
		return {"success": false, "reason": "kiho_not_known"}
	var c_p: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
	if c_p == null:
		return {"success": false, "reason": "participant_missing"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	if phase == "inhale":
		if caster.current_void_points < 1:
			return {"success": false, "reason": "no_void_points"}
		caster.current_void_points -= 1
		c_p.inari_breath_round = state.combat.round_number
		ts.consume_complex()
		return {"success": true, "phase": "inhale", "held_round": c_p.inari_breath_round}
	# exhale
	if c_p.inari_breath_round < 0 or state.combat.round_number <= c_p.inari_breath_round:
		return {"success": false, "reason": "breath_not_held_prior_round"}
	c_p.inari_breath_round = -1
	ts.consume_complex()
	var cpos: Vector2i = state.positions.get(caster_id, Vector2i(-1, -1))
	var facing: Vector2i = _effective_facing(state, caster_id)
	var rank: int = CharacterStats.get_insight_rank(caster)
	var length_tiles: int = maxi(1, rank)  # School Rank ×5 ft = ×1 tile
	var end_half_width: float = float(rank) * 0.4 / 2.0  # ×2 ft wide / 5 ft per tile, half-width
	var air: int = maxi(1, CharacterStats.get_ring_value(caster, Enums.Ring.AIR))
	var hit: Array = []
	for cid: int in state.combat.participants:
		if cid == caster_id:
			continue
		var tc: L5RCharacterData = chars_by_id.get(cid, null)
		if tc == null or CharacterStats.is_dead(tc):
			continue
		var tpos: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
		if tpos.x < 0 or not _in_cone(cpos, facing, tpos, length_tiles, end_half_width):
			continue
		var dmg: int = dice_engine.roll_and_keep(air, air, true).total  # cold damage, DR = Air Ring
		WoundSystem.apply_damage(tc, dmg, 0)  # bypasses Reduction
		hit.append(cid)
	state.combat_log.append({
		"type": "inaris_wrath_exhale", "round": state.combat.round_number,
		"caster_id": caster_id, "hit": hit})
	return {"success": true, "phase": "exhale", "hit": hit}


## Song of the World (s38 Void, Complex Action): target an opponent within 50 ft (10 tiles)
## and win a Contested Void Roll; on success the target's Initiative Score drops 5 and the
## caster's rises 5. Applied as a persistent Initiative modifier (the round re-roll model
## overwrites one-time scores, so the −5/+5 GDD effect maps to a standing delta).
static func execute_song_of_the_world(
	state: MapCombatState,
	caster_id: int,
	target_id: int,
	caster: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("Song of the World"):
		return {"success": false, "reason": "kiho_not_known"}
	var c_p: IndividualCombat.Participant = state.combat.participants.get(caster_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if c_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	var cpos: Vector2i = state.positions.get(caster_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if cpos.x < 0 or tpos.x < 0 or _chebyshev(cpos, tpos) > 10:  # 50 ft = 10 tiles
		return {"success": false, "reason": "out_of_range"}
	ts.consume_complex()
	var cv: int = maxi(1, CharacterStats.get_ring_value(caster, Enums.Ring.VOID))
	var tv: int = maxi(1, CharacterStats.get_ring_value(target, Enums.Ring.VOID))
	var won: bool = dice_engine.roll_and_keep(cv, cv, true).total >= dice_engine.roll_and_keep(tv, tv, true).total
	if won:
		t_p.initiative_modifier -= 5
		c_p.initiative_modifier += 5
	state.combat_log.append({
		"type": "song_of_the_world", "round": state.combat.round_number,
		"caster_id": caster_id, "target_id": target_id, "won": won})
	return {"success": true, "won": won}


## Thunder's Word (s38 Air, Complex Action): the caster shouts a word of power; every
## OTHER living combatant capable of hearing (the whole skirmish — a power-word shout)
## makes a Contested Air Roll against a single caster roll, and those who fail are Dazed.
## Affects allies too (GDD: "All living beings capable of hearing"). Not auto-used by the
## NPC offensive hook (it is self-harming). Returns the caster roll + the Dazed ids.
static func execute_thunders_word(
	state: MapCombatState,
	caster_id: int,
	caster: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(caster):
		return {"success": false, "reason": "character_is_dead"}
	var ts: TurnState = state.turn_states.get(caster_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not caster.kiho.has("Thunder's Word"):
		return {"success": false, "reason": "kiho_not_known"}
	if ts.is_down_restricted(CharacterStats.get_wound_level(caster)):
		return {"success": false, "reason": "down_only_free_actions"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_action"}
	if not state.combat.participants.has(caster_id):
		return {"success": false, "reason": "participant_missing"}
	ts.consume_complex()
	var air: int = maxi(1, CharacterStats.get_ring_value(caster, Enums.Ring.AIR))
	var caster_roll: int = dice_engine.roll_and_keep(air, air, true).total
	var dazed: Array = []
	for cid: int in state.combat.participants:
		if cid == caster_id:
			continue
		var tc: L5RCharacterData = chars_by_id.get(cid, null)
		if tc == null or CharacterStats.is_dead(tc):
			continue
		var ta: int = maxi(1, CharacterStats.get_ring_value(tc, Enums.Ring.AIR))
		if dice_engine.roll_and_keep(ta, ta, true).total < caster_roll:
			IndividualCombat.apply_condition(state.combat.participants[cid], IndividualCombat.CONDITION_DAZED)
			dazed.append(cid)
	state.combat_log.append({
		"type": "thunders_word", "round": state.combat.round_number,
		"caster_id": caster_id, "caster_roll": caster_roll, "dazed": dazed})
	return {"success": true, "caster_roll": caster_roll, "dazed": dazed}


## Hurricane Palm (s38 Air, Complex Action): an unarmed strike that, on a hit, spends a
## Void Point to deal only HALF normal damage but knock the target back 2× Air Ring feet
## (= 2×Air/5 tiles) directly away from the attacker and leave them Prone (even on 0
## Wounds). Stops the knockback at walls / occupied tiles / the map edge.
static func execute_hurricane_palm(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if CharacterStats.is_dead(attacker):
		return {"success": false, "reason": "character_is_dead"}
	if CharacterStats.is_dead(target):
		return {"success": false, "reason": "target_is_dead"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null:
		return {"success": false, "reason": "not_in_combat"}
	if not attacker.kiho.has("Hurricane Palm"):
		return {"success": false, "reason": "kiho_not_known"}
	if attacker.current_void_points < 1:
		return {"success": false, "reason": "no_void_points"}
	if ts.is_down_restricted(CharacterStats.get_wound_level(attacker)):
		return {"success": false, "reason": "down_only_free_actions"}
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if a_p == null or t_p == null:
		return {"success": false, "reason": "participant_missing"}
	if a_p.stance == Enums.Stance.DEFENSE or a_p.stance == Enums.Stance.FULL_DEFENSE:
		return {"success": false, "reason": "defense_cannot_attack"}
	if not ts.can_use_complex():
		return {"success": false, "reason": "no_complex_actions_remaining"}
	var apos: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if apos.x < 0 or tpos.x < 0:
		return {"success": false, "reason": "position_unknown"}
	if _chebyshev(apos, tpos) > MELEE_RANGE_TILES:
		return {"success": false, "reason": "out_of_melee_range"}
	var armor_tn: int = IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, _is_being_guarded(state, target_id), "unarmed")
	var result: Dictionary = IndividualCombat.resolve_attack(
		attacker, a_p, "unarmed", armor_tn, 0, dice_engine, false, false, false, "", {"opponent_clan": target.clan})
	ts.consume_complex()
	if result.get("hit", false):
		attacker.current_void_points -= 1
		var dmg: Dictionary = IndividualCombat.resolve_damage(attacker, "unarmed", 0, 0, dice_engine, a_p)
		var reduction: int = IndividualCombat.total_defender_reduction(target, t_p, attacker, a_p, "unarmed")
		var half: int = int(dmg["raw_damage"]) / 2  # half normal damage, rounded down
		var wd: Dictionary = WoundSystem.apply_damage(target, half, reduction)
		var air: int = CharacterStats.get_ring_value(attacker, Enums.Ring.AIR)
		var kb: int = int(2 * air / 5)  # 2× Air Ring feet → tiles (1 tile = 5 ft)
		# Root the Mountain (s38 Earth): the caster may resist the forced move (knockback)
		# with a Contested Earth Roll; the strike still leaves them Prone in place.
		if kb > 0 and _root_the_mountain_resists(target, t_p, attacker, dice_engine):
			kb = 0
			result["root_the_mountain_resisted"] = true
		result["knockback_to"] = _knockback_target(state, target_id, apos, kb, dice_engine)
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_PRONE)
		result["wounds_inflicted"] = wd.get("final_damage", half)
		result["knockback_tiles"] = kb
		result["prone"] = true
		result["target_dead"] = CharacterStats.is_dead(target)
	if not result.has("reason"):
		result["success"] = true
	state.combat_log.append({
		"type": "hurricane_palm", "round": state.combat.round_number,
		"attacker_id": attacker_id, "target_id": target_id, "hit": result.get("hit", false)})
	return result


## Root the Mountain (s38 Earth): a forced-move target with the kiho active resists when
## it wins a Contested Earth Roll against the attacker. Returns true = the move is negated.
static func _root_the_mountain_resists(
	target: L5RCharacterData,
	t_p: IndividualCombat.Participant,
	attacker: L5RCharacterData,
	dice_engine: DiceEngine,
) -> bool:
	if "Root the Mountain" not in t_p.active_kiho:
		return false
	var te: int = maxi(1, CharacterStats.get_ring_value(target, Enums.Ring.EARTH))
	var ae: int = maxi(1, CharacterStats.get_ring_value(attacker, Enums.Ring.EARTH))
	return dice_engine.roll_and_keep(te, te, true).total >= dice_engine.roll_and_keep(ae, ae, true).total


## Push a target up to `tiles` tiles directly away from `from_pos`, stopping at a wall,
## an occupied tile, or the map edge. Updates and returns the new position. (s38 knockback.)
static func _knockback_target(state: MapCombatState, target_id: int, from_pos: Vector2i, tiles: int, dice_engine: DiceEngine = null) -> Vector2i:
	var tpos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if tiles <= 0 or tpos.x < 0:
		return tpos
	var dx: int = signi(tpos.x - from_pos.x)
	var dy: int = signi(tpos.y - from_pos.y)
	if dx == 0 and dy == 0:
		return tpos
	var flying: bool = _is_flying(state, target_id)
	var occupied: Dictionary = {}
	for cid: int in state.positions:
		if cid != target_id:
			occupied[state.positions[cid]] = true
	var cur: Vector2i = tpos
	var fell_levels: int = 0
	for _n in range(tiles):
		var nxt: Vector2i = Vector2i(cur.x + dx, cur.y + dy)
		if state.map == null:
			break
		var nxt_tile: int = state.map.get_tile(nxt.x, nxt.y)
		# A flyer is shoved over open air / water / pits, hovering — only a solid
		# obstruction stops it, and it never falls or plunges into a pit.
		if flying and not MovementSystem.is_solid_obstruction(nxt_tile):
			if occupied.has(nxt):
				break
			cur = nxt
			continue
		if not MovementSystem.is_passable(nxt_tile):
			# Pit/void edge (s4.4 Z-axis, Oni Warai): a shove toward a bottomless void
			# or deep water gets one chance to catch the brink (Reflexes + Athletics).
			# Failure carries the victim over the edge to their death.
			if _is_lethal_pit(nxt_tile) and dice_engine != null:
				var pit_ch: L5RCharacterData = state.combatants.get(target_id, null)
				if pit_ch != null and not CharacterStats.is_dead(pit_ch):
					var save: Dictionary = SkillResolver.resolve_skill_check(
						pit_ch, dice_engine, "Athletics", PIT_EDGE_CATCH_TN, 0, "",
						Enums.Trait.REFLEXES)
					if not save.get("success", false):
						state.positions[target_id] = cur
						_apply_pit_death(state, target_id, nxt)
						return cur
			break
		if occupied.has(nxt):
			break
		# Elevation face (s4.4 Z-axis): being shoved into an upward cliff stops the
		# knockback (slammed into the face); being shoved off a downward ledge sends
		# the target over the edge — they land on the lower tile and fall.
		var ed: int = MovementSystem.elevation_delta(state.map, cur.x, cur.y, nxt.x, nxt.y)
		if ed >= MovementSystem.CLIFF_THRESHOLD:
			break
		cur = nxt
		if ed <= -MovementSystem.FALL_THRESHOLD:
			fell_levels = -ed
			break
	state.positions[target_id] = cur
	if fell_levels > 0 and dice_engine != null:
		_apply_fall_damage(state, target_id, fell_levels, dice_engine)
	return cur


## Applies falling damage for a drop of `levels` elevation levels (1 level ≈ 5 ft).
## DR = levels k levels exploding — the L5R 4e core rule "1k1 Wounds per 5 ft
## fallen" (model locked by owner 2026-06-23). Like other environmental hazards in
## this layer (FireSystem), a fall bypasses armor Reduction. Returns Wounds dealt.
static func _apply_fall_damage(state: MapCombatState, char_id: int, levels: int, dice_engine: DiceEngine) -> int:
	if levels <= 0 or dice_engine == null:
		return 0
	var ch: L5RCharacterData = state.combatants.get(char_id, null)
	if ch == null or CharacterStats.is_dead(ch):
		return 0
	var n: int = clampi(levels, 1, 10)
	var dmg: int = dice_engine.roll_and_keep(n, n, true).total
	WoundSystem.apply_damage(ch, dmg, 0)
	state.combat_log.append({
		"type": "fall",
		"round": state.combat.round_number,
		"char_id": char_id,
		"levels": levels,
		"damage": dmg,
		"dead": CharacterStats.is_dead(ch),
	})
	return dmg


## Kills a character who was shoved over a lethal pit edge (bottomless void / drowning
## in deep water) and failed the edge-catch save (s4.4 Z-axis, Oni Warai). Unlike a
## graduated fall this is unsurvivable — wounds are set past the Dead threshold.
static func _apply_pit_death(state: MapCombatState, char_id: int, pit_pos: Vector2i) -> void:
	var ch: L5RCharacterData = state.combatants.get(char_id, null)
	if ch == null or CharacterStats.is_dead(ch):
		return
	ch.wounds_taken = CharacterStats.get_total_wound_capacity(ch) + 1
	state.combat_log.append({
		"type": "pit_death",
		"round": state.combat.round_number,
		"char_id": char_id,
		"pit_x": pit_pos.x,
		"pit_y": pit_pos.y,
		"dead": true,
	})


## Way of the Willow (s38 Air): a defender may spend a Void Point to interrupt a declared
## melee attack with an immediate unarmed counterattack (resolved directly, once per Round).
## Returns true if the counter killed the attacker (the caller aborts the original attack).
## LIMITATION: the GDD "Move Action away" alternative and the "has not yet taken their Turn"
## gate are approximated — the NPC default is the counterattack, gated once per Round + VP.
static func _maybe_way_of_the_willow(
	state: MapCombatState,
	defender: L5RCharacterData,
	d_p: IndividualCombat.Participant,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	dice_engine: DiceEngine,
) -> bool:
	if CharacterStats.is_dead(defender) or CharacterStats.is_dead(attacker):
		return false
	if "Way of the Willow" not in d_p.active_kiho:
		return false
	if d_p.kata_used_this_round.get("way_of_the_willow", false):
		return false
	if defender.current_void_points < 1:
		return false
	d_p.kata_used_this_round["way_of_the_willow"] = true
	defender.current_void_points -= 1
	var armor_tn: int = IndividualCombat.get_armor_tn(attacker, a_p, dice_engine, true, false, "unarmed")
	var atk: Dictionary = IndividualCombat.resolve_attack(
		defender, d_p, "unarmed", armor_tn, 0, dice_engine, false, false, false, "", {"opponent_clan": attacker.clan})
	if atk.get("hit", false):
		var dmg: Dictionary = IndividualCombat.resolve_damage(defender, "unarmed", 0, 0, dice_engine, d_p)
		var red: int = IndividualCombat.total_defender_reduction(attacker, a_p, defender, d_p, "unarmed")
		WoundSystem.apply_damage(attacker, dmg["raw_damage"], red)
	state.combat_log.append({
		"type": "way_of_the_willow_interrupt", "round": state.combat.round_number,
		"defender_id": defender.character_id, "attacker_id": attacker.character_id,
		"hit": atk.get("hit", false)})
	return CharacterStats.is_dead(attacker)


## Destiny's Strike (s38 Fire): when struck by a melee attack, a defender with the kiho
## active immediately makes a single unarmed counterattack against the attacker. Resolved
## directly (not via execute_melee_attack) so it cannot recurse; once per Round per
## defender (kata_used_this_round guard). Requires melee range (the attacker just struck).
static func _maybe_destiny_strike(
	state: MapCombatState,
	defender: L5RCharacterData,
	d_p: IndividualCombat.Participant,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	dice_engine: DiceEngine,
) -> void:
	if CharacterStats.is_dead(defender) or CharacterStats.is_dead(attacker):
		return
	if "Destiny's Strike" not in d_p.active_kiho:
		return
	if d_p.kata_used_this_round.get("destiny_strike", false):
		return
	var dpos: Vector2i = state.positions.get(defender.character_id, Vector2i(-1, -1))
	var apos: Vector2i = state.positions.get(attacker.character_id, Vector2i(-1, -1))
	if dpos.x < 0 or apos.x < 0 or _chebyshev(dpos, apos) > MELEE_RANGE_TILES:
		return
	d_p.kata_used_this_round["destiny_strike"] = true
	var armor_tn: int = IndividualCombat.get_armor_tn(attacker, a_p, dice_engine, true, false, "unarmed")
	var atk: Dictionary = IndividualCombat.resolve_attack(
		defender, d_p, "unarmed", armor_tn, 0, dice_engine, false, false, false, "", {"opponent_clan": attacker.clan})
	if atk.get("hit", false):
		var dmg: Dictionary = IndividualCombat.resolve_damage(defender, "unarmed", 0, 0, dice_engine, d_p)
		var red: int = IndividualCombat.total_defender_reduction(attacker, a_p, defender, d_p, "unarmed")
		WoundSystem.apply_damage(attacker, dmg["raw_damage"], red)
	state.combat_log.append({
		"type": "destiny_strike_counter", "round": state.combat.round_number,
		"counterattacker_id": defender.character_id, "target_id": attacker.character_id,
		"hit": atk.get("hit", false)})


## The Body is an Anvil (s38 Fire): on a landed unarmed strike, the anvil-caster's
## burning skin deals Fire Ring Wounds to whoever touches them. If the DEFENDER has
## it active, the unarmed attacker is burned; if the ATTACKER has it active, the
## struck target takes Fire Ring contact Wounds beyond the normal damage. Unarmed only.
static func _apply_body_is_anvil(
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	target: L5RCharacterData,
	t_p: IndividualCombat.Participant,
	weapon_name: String,
) -> void:
	if weapon_name != "" and weapon_name != "unarmed":
		return
	if "The Body is an Anvil" in t_p.active_kiho and not CharacterStats.is_dead(attacker):
		WoundSystem.apply_damage(attacker, CharacterStats.get_ring_value(target, Enums.Ring.FIRE), 0)
	if "The Body is an Anvil" in a_p.active_kiho and not CharacterStats.is_dead(target):
		WoundSystem.apply_damage(target, CharacterStats.get_ring_value(attacker, Enums.Ring.FIRE), 0)


## Fires of Purity (s35 Fire): the flame-shrouded character burns anyone in melee contact —
## 2k2 to whoever strikes them (DEFENDER shrouded) and an extra 2k2 to whoever they strike
## (ATTACKER shrouded). Ranged attacks bypass the shroud (handled by the melee gate).
const FIRES_OF_PURITY_ROLLED: int = 2
const FIRES_OF_PURITY_KEPT: int = 2
static func _apply_fires_of_purity(
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	target: L5RCharacterData,
	t_p: IndividualCombat.Participant,
	weapon_name: String,
	dice_engine: DiceEngine,
) -> void:
	if not IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		return
	if t_p != null and IndividualCombat.get_timed_modifier_total(t_p, "flame_shroud") > 0 \
			and not CharacterStats.is_dead(attacker):
		WoundSystem.apply_damage(attacker,
			dice_engine.roll_and_keep(FIRES_OF_PURITY_ROLLED, FIRES_OF_PURITY_KEPT, true).total, 0)
	if a_p != null and IndividualCombat.get_timed_modifier_total(a_p, "flame_shroud") > 0 \
			and not CharacterStats.is_dead(target):
		WoundSystem.apply_damage(target,
			dice_engine.roll_and_keep(FIRES_OF_PURITY_ROLLED, FIRES_OF_PURITY_KEPT, true).total, 0)


## Shining Light (s35 Fire 3): an armor ward. When the wearer (struck DEFENDER, t_p) is hit in
## melee, the attacker takes 2k2 and is Blinded (the "until Reactions Stage" window maps to the
## standard roll-recovered Blinded). Ranged attacks bypass it. Inert unless t_p is warded.
const SHINING_LIGHT_ROLLED: int = 2
const SHINING_LIGHT_KEPT: int = 2
static func _apply_shining_light(
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	t_p: IndividualCombat.Participant,
	weapon_name: String,
	dice_engine: DiceEngine,
) -> void:
	if not IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		return
	if t_p == null or IndividualCombat.get_timed_modifier_total(t_p, "shining_light") <= 0:
		return
	if CharacterStats.is_dead(attacker):
		return
	WoundSystem.apply_damage(attacker,
		dice_engine.roll_and_keep(SHINING_LIGHT_ROLLED, SHINING_LIGHT_KEPT, true).total, 0)
	if a_p != null:
		IndividualCombat.apply_condition(a_p, IndividualCombat.CONDITION_BLINDED)


## Burning Blood (s54.5 Furu / Furu spawn): when a MELEE attacker wounds a burning-blood
## creature, the attacker rolls Reflexes (Defense) vs the creature's burning_blood_tn or is
## splattered for burning_blood_rolled k _kept damage (armour does not reduce splatter; the
## GDD Taint-exposure roll is a separate system, not applied here). Inert unless the struck
## TARGET is a burning-blood creature. Returns the damage dealt to the attacker (0 = none).
static func _apply_burning_blood(
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	dice: DiceEngine,
) -> int:
	if target.spirit_creature == null or target.spirit_creature.burning_blood_rolled <= 0:
		return 0
	if CharacterStats.is_dead(attacker):
		return 0
	# Ranged attackers are not splattered (must be in melee contact).
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	if not wp.get("melee", true):
		return 0
	var cr: SpiritCreatureData = target.spirit_creature
	var save: int = dice.roll_and_keep(
		attacker.reflexes + attacker.skills.get("Defense", 0), attacker.reflexes, true).total
	if save >= cr.burning_blood_tn:
		return 0  # dodged the splatter
	var dmg: int = dice.roll_and_keep(cr.burning_blood_rolled, cr.burning_blood_kept, true).total
	WoundSystem.apply_damage(attacker, dmg, 0)
	return dmg


## Creature ranged attack (s54.5 Flaming Bark / Hurl Flaming Blood): a Complex-action thrown
## attack using the creature's fixed ranged to-hit (ranged_attack_rolled k _kept) vs the
## target's Armor TN, dealing ranged_damage_rolled k _kept (reduced by the target's armour).
## On a hit, ranged_fire sets the target on fire (FireSystem 1k1/round until extinguished —
## the GDD's exact "2k2 next Round" burn is approximated by the standard on-fire layer).
## Range-gated by ranged_range_tiles (caller already ensured LOS via target_in_ranged).
static func execute_creature_ranged_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var cr: SpiritCreatureData = attacker.spirit_creature
	if cr == null or (cr.ranged_damage_rolled <= 0 and not cr.ranged_entangle):
		return {"ok": false, "reason": "no_ranged_attack"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null or not ts.can_use_complex():
		return {"ok": false, "reason": "no_action"}
	var ap: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var tp_pos: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if ap.x < 0 or tp_pos.x < 0 or _chebyshev(ap, tp_pos) > cr.ranged_range_tiles:
		return {"ok": false, "reason": "out_of_range"}
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null:
		return {"ok": false, "reason": "no_target"}
	ts.consume_complex()
	# ranged_attack_rolled 0 = an auto-hit breath/blast (s54.12 Basan Breathe Flames); else
	# a normal to-hit roll vs Armor TN.
	if cr.ranged_attack_rolled > 0:
		var to_hit: int = dice.roll_and_keep(cr.ranged_attack_rolled, cr.ranged_attack_kept, true).total
		var atn: int = IndividualCombat.get_armor_tn(target, t_p, dice, false, false, "")
		if to_hit < atn:
			return {"ok": true, "hit": false, "roll": to_hit, "armor_tn": atn}
	# Web (s54.12): the ranged hit Entangles instead of dealing damage.
	if cr.ranged_entangle and t_p != null and target.spirit_creature == null:
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_ENTANGLED)
		return {"ok": true, "hit": true, "entangled": true}
	# Damage: spirit ranged damage filtered by the target's armour (mundane reduction).
	var raw: int = dice.roll_and_keep(cr.ranged_damage_rolled, cr.ranged_damage_kept, true).total
	var reduction: int = 0 if target.spirit_creature != null else maxi(0, target.armor_reduction)
	var wd: Dictionary = WoundSystem.apply_damage(target, raw, reduction)
	if cr.ranged_fire and target.spirit_creature == null:
		t_p.on_fire = true
	return {
		"ok": true, "hit": true,
		"wounds": wd.get("final_damage", raw), "set_on_fire": cr.ranged_fire,
		"dead": CharacterStats.is_dead(target),
	}


## AoE ranged attack (s54.11 Cauldron Belch, s54.12 Gout of Flame): a Complex-action blast
## centred on the target tile, damaging every enemy within ranged_aoe_radius. ranged_attack_rolled
## 0 = auto-hit explosion; otherwise one to-hit roll vs the primary's Armor TN gates the whole
## blast. Caps at ranged_aoe_max_targets (0 = unlimited); once-per-skirmish if ranged_aoe_once.
static func execute_creature_aoe_attack(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var cr: SpiritCreatureData = attacker.spirit_creature
	if cr == null or cr.ranged_aoe_radius <= 0:
		return {"ok": false, "reason": "no_aoe"}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null or not ts.can_use_complex():
		return {"ok": false, "reason": "no_action"}
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	if a_p != null and cr.ranged_aoe_once and a_p.ranged_aoe_used:
		return {"ok": false, "reason": "already_used"}
	var ap: Vector2i = state.positions.get(attacker_id, Vector2i(-1, -1))
	var impact: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if ap.x < 0 or impact.x < 0 or _chebyshev(ap, impact) > cr.ranged_range_tiles:
		return {"ok": false, "reason": "out_of_range"}
	ts.consume_complex()
	if a_p != null:
		a_p.ranged_aoe_used = true
	# A to-hit roll (if any) vs the primary target gates the whole blast.
	if cr.ranged_attack_rolled > 0:
		var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
		var atn: int = IndividualCombat.get_armor_tn(attacker, a_p, dice, false, false, "") if t_p == null \
			else IndividualCombat.get_armor_tn(state.combatants.get(target_id, attacker), t_p, dice, false, false, "")
		if dice.roll_and_keep(cr.ranged_attack_rolled, cr.ranged_attack_kept, true).total < atn:
			return {"ok": true, "hit": false}
	# Damage every enemy within the radius (capped).
	var faction: String = state.factions.get(attacker_id, FACTION_NEUTRAL)
	var struck: int = 0
	for cid: int in state.positions.keys():
		if cid == attacker_id or not _are_enemies(faction, state.factions.get(cid, FACTION_NEUTRAL)):
			continue
		if _chebyshev(impact, state.positions[cid]) > cr.ranged_aoe_radius:
			continue
		if cr.ranged_aoe_max_targets > 0 and struck >= cr.ranged_aoe_max_targets:
			break
		var victim: L5RCharacterData = state.combatants.get(cid, null)
		if victim == null or CharacterStats.is_dead(victim):
			continue
		var red: int = 0 if (victim.spirit_creature != null or cr.ranged_aoe_ignores_armor) else maxi(0, victim.armor_reduction)
		WoundSystem.apply_damage(victim, dice.roll_and_keep(cr.ranged_damage_rolled, cr.ranged_damage_kept, true).total, red)
		if cr.ranged_fire and victim.spirit_creature == null:
			var vp: IndividualCombat.Participant = state.combat.participants.get(cid, null)
			if vp != null:
				vp.on_fire = true
		struck += 1
	return {"ok": true, "hit": true, "targets_struck": struck}


## Abominable Stench (s54.11 Nuppeppo): when struck by a bladed/piercing weapon (approximated
## as any armed melee weapon — no weapon damage-type field), the nuppeppo erupts: every living
## mortal within 20' (4 tiles) rolls Stamina TN 20 or is Fatigued. Inert unless the struck
## TARGET is an abominable_stench creature. Returns the number newly Fatigued.
static func _apply_abominable_stench(state: MapCombatState, target: L5RCharacterData, weapon_name: String, dice: DiceEngine) -> int:
	if target.spirit_creature == null or not target.spirit_creature.has_tag("abominable_stench"):
		return 0
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	if not wp.get("melee", true) or weapon_name == "" or weapon_name == "unarmed":
		return 0  # bladed/piercing approximated as an armed melee strike
	var center: Vector2i = state.positions.get(target.character_id, Vector2i(-9999, -9999))
	if center.x < -9000:
		return 0
	var hit: int = 0
	for cid: int in state.positions.keys():
		if cid == target.character_id or _chebyshev(center, state.positions[cid]) > 4:
			continue
		var c: L5RCharacterData = state.combatants.get(cid, null)
		if c == null or CharacterStats.is_dead(c) or c.spirit_creature != null:
			continue  # living mortals only
		var cp: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if cp == null or IndividualCombat.CONDITION_FATIGUED in cp.conditions:
			continue
		if dice.roll_and_keep(maxi(1, c.stamina), maxi(1, c.stamina), true).total < 20:
			IndividualCombat.apply_condition(cp, IndividualCombat.CONDITION_FATIGUED)
			hit += 1
	return hit


## Wreathed in Flames (s54.5 Daku): anyone striking the burning oni in melee automatically
## (no save) takes Wounds by weapon size — unarmed/Small 3k2, Medium 2k1, Large/ranged 0.
## Inert unless the struck TARGET has the wreathed_in_flames tag. Returns damage dealt.
static func _apply_wreathed_in_flames(
	attacker: L5RCharacterData,
	target: L5RCharacterData,
	weapon_name: String,
	dice: DiceEngine,
) -> int:
	if target.spirit_creature == null or not target.spirit_creature.has_tag("wreathed_in_flames"):
		return 0
	if CharacterStats.is_dead(attacker):
		return 0
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	if not wp.get("melee", true):
		return 0  # ranged attacks cause no Wounds
	var size: String = str(wp.get("size", "Medium"))
	var rolled: int = 0
	var kept: int = 0
	if weapon_name == "" or weapon_name == "unarmed" or size == "Small":
		rolled = 3; kept = 2
	elif size == "Large":
		return 0  # Large weapons cause no Wounds
	else:  # Medium (and any unspecified size)
		rolled = 2; kept = 1
	var dmg: int = dice.roll_and_keep(rolled, kept, true).total
	WoundSystem.apply_damage(attacker, dmg, 0)
	return dmg


## Swallow Whole / Devour (s54.5 Muduro/Kamu/Tsuburu/Utogu): on a wounding melee hit the
## swallow creature wins a Contested Strength (creature vs victim) to engulf the victim —
## who is Grappled (creature in control) and takes swallow damage each Round (advance_round)
## until they escape. Inert unless the ATTACKER is a swallow creature. Returns true if
## the victim was newly swallowed.
## Suffocation (s54.5 Quiet Death): a melee hit by a `suffocation` creature attempts to
## Grapple the victim (the creature rolls 8k4 to initiate, vs the victim's Strength). On
## control, the victim is engulfed (reuses the swallow grapple state, swallowed_by_id); the
## per-Round escalating crush (3k3 +1k1/Round) is applied in advance_round and resets when
## control is lost (suffocation_escalation -> 0 on escape). Skips a spirit target.
static func _apply_suffocation(
	state: MapCombatState,
	attacker: L5RCharacterData,
	attacker_id: int,
	target: L5RCharacterData,
	target_id: int,
	weapon_name: String,
	dice: DiceEngine,
) -> bool:
	if attacker.spirit_creature == null or not attacker.spirit_creature.has_tag("suffocation"):
		return false
	if not IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		return false
	if target.spirit_creature != null or CharacterStats.is_dead(target):
		return false
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null or t_p.swallowed_by_id != -1:
		return false
	# Grapple roll 8k4 (the creature's grapple) vs the victim's Strength; victim resists on a tie.
	var cs: int = dice.roll_and_keep(8, 4, true).total
	var vs: int = dice.roll_and_keep(maxi(1, target.strength), maxi(1, target.strength), true).total
	if cs <= vs:
		return false
	t_p.swallowed_by_id = attacker_id
	t_p.suffocation_escalation = 0
	IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_GRAPPLED)
	t_p.grapple_partner_id = attacker_id
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	if a_p != null:
		a_p.grapple_partner_id = target_id
		a_p.grapple_in_control = true
	return true


static func _apply_swallow_whole(
	state: MapCombatState,
	attacker: L5RCharacterData,
	attacker_id: int,
	target: L5RCharacterData,
	target_id: int,
	weapon_name: String,
	dice: DiceEngine,
) -> bool:
	if attacker.spirit_creature == null or attacker.spirit_creature.swallow_damage_rolled <= 0:
		return false
	if not IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		return false
	if CharacterStats.is_dead(target):
		return false
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null or t_p.swallowed_by_id != -1:
		return false
	# Contested Strength: creature vs victim. The victim resists on a tie.
	var cs: int = dice.roll_and_keep(maxi(1, attacker.strength), maxi(1, attacker.strength), true).total
	var vs: int = dice.roll_and_keep(maxi(1, target.strength), maxi(1, target.strength), true).total
	if cs <= vs:
		return false
	t_p.swallowed_by_id = attacker_id
	IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_GRAPPLED)
	t_p.grapple_partner_id = attacker_id
	var a_p: IndividualCombat.Participant = state.combat.participants.get(attacker_id, null)
	if a_p != null:
		a_p.grapple_partner_id = target_id
		a_p.grapple_in_control = true
	return true


## A swallowed victim breaks free with a Contested Strength roll vs the captor (s54.5).
## On success the swallow/grapple state clears for both sides. Public for the PC turn path.
static func attempt_swallow_escape(state: MapCombatState, victim_id: int, victim: L5RCharacterData, dice: DiceEngine) -> Dictionary:
	var vp: IndividualCombat.Participant = state.combat.participants.get(victim_id, null)
	if vp == null or vp.swallowed_by_id == -1:
		return {"success": false, "reason": "not_swallowed"}
	var captor_id: int = vp.swallowed_by_id
	var captor: L5RCharacterData = state.combatants.get(captor_id, null)
	var v_roll: int = dice.roll_and_keep(maxi(1, victim.strength), maxi(1, victim.strength), true).total
	# Suffocation (Quiet Death) contests with the creature's 8k4 grapple; swallow uses Strength.
	var c_roll: int
	if captor != null and captor.spirit_creature != null and captor.spirit_creature.has_tag("suffocation"):
		c_roll = dice.roll_and_keep(8, 4, true).total
	else:
		var c_str: int = maxi(1, captor.strength) if captor != null else 1
		c_roll = dice.roll_and_keep(c_str, c_str, true).total
	if v_roll <= c_roll:
		return {"success": false, "reason": "still_swallowed", "roll": v_roll}
	vp.swallowed_by_id = -1
	vp.grapple_partner_id = -1
	vp.suffocation_escalation = 0  # re-grapple restarts crush at 3k3 (s54.5)
	vp.conditions.erase(IndividualCombat.CONDITION_GRAPPLED)
	var cp: IndividualCombat.Participant = state.combat.participants.get(captor_id, null)
	if cp != null:
		cp.grapple_partner_id = -1
		cp.grapple_in_control = false
	return {"success": true, "roll": v_roll}


## Break free of Entangled (s54.12 Web / s56.20 Snare): a Strength roll vs TN 20. On success
## the condition is removed. Public for the PC turn path; NPCs auto-attempt via execute_npc_turn.
static func attempt_entangle_escape(state: MapCombatState, char_id: int, character: L5RCharacterData, dice: DiceEngine) -> Dictionary:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null or IndividualCombat.CONDITION_ENTANGLED not in p.conditions:
		return {"success": false, "reason": "not_entangled"}
	var roll: int = dice.roll_and_keep(maxi(1, character.strength), maxi(1, character.strength), true).total
	if roll >= 20:
		p.conditions.erase(IndividualCombat.CONDITION_ENTANGLED)
		# Gore (s54.5): pulling free of the tusks deals the gore-escape damage.
		var gore_dmg: int = 0
		if p.gore_escape_rolled > 0:
			gore_dmg = dice.roll_and_keep(p.gore_escape_rolled, p.gore_escape_kept, true).total
			WoundSystem.apply_damage(character, gore_dmg, maxi(0, character.armor_reduction))
			p.gore_escape_rolled = 0
			p.gore_escape_kept = 0
		return {"success": true, "roll": roll, "gore_damage": gore_dmg}
	return {"success": false, "roll": roll}


## First known OFFENSIVE atemi kiho whose effect is encoded (so the strike actually
## applies something). Skips ally-targeted (heal) atemi like Chi Protection — those
## must not be delivered to the enemy best_target. Returns "" if the monk knows none.
## Used by execute_npc_turn against an enemy target.
static func _npc_pick_atemi(npc: L5RCharacterData) -> String:
	for k: String in npc.kiho:
		var data: Dictionary = KihoSystem.KIHO_DATA.get(k, {})
		if not data.get("atemi", false):
			continue
		var eff: Dictionary = data.get("atemi_effect", {})
		# Skip ally-targeted (heal/buff), pure-info, and non-combat-effect atemi —
		# none help win the current fight, so the offensive hook should not pick them.
		if eff.is_empty() or eff.get("ally_auto_hit", false) or eff.get("info_only", false) or eff.get("non_combat_effect", false):
			continue
		return k
	return ""


## Break/destroy a fragile tile (shoji, paper wall, bamboo). Complex action.
static func execute_destroy_tile(
	state: MapCombatState,
	char_id: int,
	tx: int,
	ty: int,
	character: L5RCharacterData,
) -> Dictionary:
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
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
	if CharacterStats.is_dead(character):
		return {"success": false, "reason": "character_is_dead"}
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
		p.attacked_by_ids.clear()  # "since the last Turn" resets (Bishamon's Grasp, s38)
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


## Delay the current actor's Turn (s40): the next-highest character acts now,
## and the delaying character gets their chance later in the same Round (and may
## delay again). Turns cannot be saved across Rounds. Returns the new current
## actor, or {"success": false} if there is no later character to delay to (the
## lowest-Initiative character must eventually act).
static func execute_delay(
	state: MapCombatState,
	actor_id: int,
) -> Dictionary:
	if state.combat.is_over:
		return {"success": false, "reason": "combat_over"}
	if get_current_actor(state) != actor_id:
		return {"success": false, "reason": "not_current_actor"}

	var order: Array = state.combat.turn_order
	var idx: int = state.combat.current_turn_index
	# Find the next valid (not fled, not out) actor after the delayer.
	var j: int = idx + 1
	while j < order.size():
		var cand: int = order[j]
		if cand not in state.fled_ids and not _is_participant_out(state, cand):
			break
		j += 1
	if j >= order.size():
		# No later character remains this Round — the delayer must act.
		return {"success": false, "reason": "no_later_actor"}

	# Swap the delayer with that next valid actor: they act now, the delayer
	# slides to the later slot (where they may act or delay again).
	var delayer: int = order[idx]
	order[idx] = order[j]
	order[j] = delayer

	var dp: IndividualCombat.Participant = state.combat.participants.get(delayer, null)
	if dp != null:
		dp.is_delaying = true

	var new_actor: int = get_current_actor(state)
	if new_actor >= 0:
		begin_turn(state, new_actor)
	state.combat_log.append({
		"type": "delay_turn",
		"round": state.combat.round_number,
		"delayer_id": actor_id,
		"now_acting_id": new_actor,
	})
	return {"success": true, "delayer_id": actor_id, "actor": new_actor}


## Advance to the next actor in the turn order.
## When all have acted, advance the round.
static func advance_turn(
	state: MapCombatState,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Expire turn-scoped timed modifiers on the actor whose turn is now ending
	# (s30a Strength of the Spider "next Turn"). The ending actor is the current
	# index before we advance past it.
	if state.combat.current_turn_index < state.combat.turn_order.size():
		var ending_id: int = state.combat.turn_order[state.combat.current_turn_index]
		var ending_p: IndividualCombat.Participant = state.combat.participants.get(ending_id, null)
		if ending_p != null:
			IndividualCombat.expire_turn_modifiers(ending_p)

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


## Auto-resolve the current actor's turn and advance, dispatching by actor kind.
## The external loop calls this repeatedly: it resolves enemy NPCs
## (execute_npc_turn) and allied companions (execute_companion_turn) automatically,
## and yields control on a player turn. Companion morale is refreshed from current
## casualties before each non-player turn. Returns one of:
##   {"over": true}                          — combat is over
##   {"no_actor": true}                       — no valid actor remains
##   {"awaiting_player": true, "actor": id}    — a PC must act (caller takes input)
##   {actor_type: "companion"|"npc", actor, actions, ...}  — resolved + advanced
static func resolve_current_turn(
	state: MapCombatState,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if state.combat.is_over:
		return {"over": true}
	var actor: int = get_current_actor(state)
	if actor < 0:
		return {"no_actor": true}
	# A player character (player-faction, not a companion) yields to input.
	if state.factions.get(actor, FACTION_NEUTRAL) == FACTION_PLAYER \
			and not state.companion_data.has(actor):
		return {"awaiting_player": true, "actor": actor}
	var character: L5RCharacterData = chars_by_id.get(actor, null)
	if character == null or CharacterStats.is_dead(character):
		advance_turn(state, chars_by_id, dice_engine)
		return {"skipped": actor}
	# Refresh companion morale from the current casualty state before they act.
	update_companion_morale(state, chars_by_id)
	var result: Dictionary
	if state.companion_data.has(actor):
		result = execute_companion_turn(state, actor, character, chars_by_id, dice_engine)
		result["actor_type"] = "companion"
	else:
		result = execute_npc_turn(state, actor, character, chars_by_id, dice_engine)
		result["actor_type"] = "npc"
	result["actor"] = actor
	advance_turn(state, chars_by_id, dice_engine)
	return result


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
		# No-leak guard: clear every combatant's ring-delta bridge when combat ends, so a
		# lingering s34 ring boost never bleeds into the world-sim after the encounter.
		for _cid in state.combatants:
			var _cc = state.combatants[_cid]
			if _cc != null:
				_cc.combat_ring_deltas = {}
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
		_p.off_hand_attack_used_this_turn = false
		_p.earth_init_trade_amount = 0
		if _p.void_ring_bonus > 0 and not _p.center_stance_bonus_used:
			_p.void_ring_bonus = 0

	state.combat.round_number += 1
	state.combat.current_turn_index = 0

	# Expire round-based timed modifiers (s30a duration katas) for the new round.
	# The World Is Empty deducts 1 VP as its modifier ends (before removal).
	for _tp: IndividualCombat.Participant in state.combat.participants.values():
		_process_world_is_empty_expiry(state, _tp, chars_by_id)
		var _was_flying: bool = IndividualCombat.get_timed_modifier_total(_tp, "flight") > 0
		IndividualCombat.expire_timed_modifiers(_tp, state.combat.round_number)
		# Flight ended this round → set the (former) flyer down gently (GDD safe landing).
		if _was_flying and IndividualCombat.get_timed_modifier_total(_tp, "flight") <= 0:
			_flight_safe_landing(state, _tp.character_id)
		IndividualCombat.expire_active_kiho(_tp, state.combat.round_number)
		IndividualCombat.expire_timed_conditions(_tp, state.combat.round_number)
		_expire_ring_deltas(state, _tp, chars_by_id)  # s34 ring spells — wounds return to normal on expiry
		# Conjured elemental weapon (s33-s36) dissipates when its duration ends.
		if _tp.conjured_weapon_expiry >= 0 and _tp.conjured_weapon_expiry <= state.combat.round_number:
			_tp.conjured_weapon = {}
			_tp.conjured_weapon_expiry = -1
		# Banish All Shadows suppression ends — restore the Disadvantage's effects.
		if _tp.suppressed_disadvantage_expiry >= 0 and _tp.suppressed_disadvantage_expiry <= state.combat.round_number:
			var _sc: L5RCharacterData = chars_by_id.get(_tp.character_id, null)
			if _sc != null:
				_sc.suppressed_disadvantage_type = -1
			_tp.suppressed_disadvantage_expiry = -1
		# Rest, My Brother suppression ends — restore the Taint benefits.
		if _tp.taint_benefits_suppressed_expiry >= 0 and _tp.taint_benefits_suppressed_expiry <= state.combat.round_number:
			var _tc: L5RCharacterData = chars_by_id.get(_tp.character_id, null)
			if _tc != null:
				_tc.taint_benefits_suppressed = false
			_tp.taint_benefits_suppressed_expiry = -1
		# Way of the Earth (s38 Earth): each Round, a grappled opponent of the caster
		# suffers the caster's Earth Ring in Wounds (Reactions Stage).
		if "Way of the Earth" in _tp.active_kiho and _tp.grapple_partner_id >= 0:
			var _woe_c: L5RCharacterData = chars_by_id.get(_tp.character_id, null)
			var _woe_p: L5RCharacterData = chars_by_id.get(_tp.grapple_partner_id, null)
			if _woe_c != null and _woe_p != null and not CharacterStats.is_dead(_woe_p):
				WoundSystem.apply_damage(_woe_p, CharacterStats.get_ring_value(_woe_c, Enums.Ring.EARTH), 0)
		# Ride the Water Dragon (s38 Water): recover Water Ring Wounds each Round (Reactions Stage).
		if "Ride the Water Dragon" in _tp.active_kiho:
			var _rwd_c: L5RCharacterData = chars_by_id.get(_tp.character_id, null)
			if _rwd_c != null and not CharacterStats.is_dead(_rwd_c):
				WoundSystem.heal_wounds(_rwd_c, CharacterStats.get_ring_value(_rwd_c, Enums.Ring.WATER))
		# s43 Bleeding: a maho kansen makes an injured wound bleed — N Wounds/Round at the start of the
		# victim's Turn, indefinitely until bandaged (a future out-of-combat Medicine action) or healed.
		var _bleed_amt: int = IndividualCombat.get_timed_modifier_total(_tp, "bleed")
		if _bleed_amt > 0:
			var _bl_c: L5RCharacterData = chars_by_id.get(_tp.character_id, state.combatants.get(_tp.character_id, null))
			if _bl_c != null and not CharacterStats.is_dead(_bl_c):
				WoundSystem.apply_damage(_bl_c, _bleed_amt, 0)
		# Gashadokuro Regeneration (s54.10): recover 10 Wounds at the start of each round,
		# UNLESS a Wound threshold was crossed within the last 3 rounds (a section
		# collapsed — _apply_hit set spirit_regen_suppressed_until).
		var _rg_c: L5RCharacterData = state.combatants.get(_tp.character_id, null)
		if _rg_c != null and _rg_c.spirit_creature != null and not CharacterStats.is_dead(_rg_c) \
				and not _tp.heart_destroyed \
				and _tp.spirit_regen_suppressed_until < state.combat.round_number:
			var _rg_amt: int = SpiritAbilitySystem.regeneration_amount(_rg_c.spirit_creature)
			if _rg_amt > 0:
				WoundSystem.heal_wounds(_rg_c, _rg_amt)
		# Swallow Whole / Devour (s54.5): a swallowed victim takes the captor's swallow
		# damage each Round (+1 Taint if swallow_taint); released if the captor dies.
		if _tp.swallowed_by_id != -1:
			var _sv: L5RCharacterData = chars_by_id.get(_tp.character_id, state.combatants.get(_tp.character_id, null))
			var _cap: L5RCharacterData = state.combatants.get(_tp.swallowed_by_id, null)
			if _sv == null or CharacterStats.is_dead(_sv) or _cap == null or CharacterStats.is_dead(_cap):
				_tp.swallowed_by_id = -1
				_tp.grapple_partner_id = -1
				_tp.suffocation_escalation = 0
				_tp.conditions.erase(IndividualCombat.CONDITION_GRAPPLED)
			elif _cap.spirit_creature != null and _cap.spirit_creature.has_tag("suffocation"):
				# Quiet Death: escalating crush 3k3, +1k1 each successive Round of control.
				var _esc: int = _tp.suffocation_escalation
				var _sfd: int = dice_engine.roll_and_keep(3 + _esc, 3 + _esc, true).total
				WoundSystem.apply_damage(_sv, _sfd, 0)
				_tp.suffocation_escalation += 1
			elif _cap.spirit_creature != null:
				var _sd: int = dice_engine.roll_and_keep(
					_cap.spirit_creature.swallow_damage_rolled,
					_cap.spirit_creature.swallow_damage_kept, true).total
				WoundSystem.apply_damage(_sv, _sd, 0)
				if _cap.spirit_creature.swallow_taint:
					_sv.taint = minf(100.0, _sv.taint + 1.0)
		# Escalating poison (s54.5 Shikage Mind-Breaking / Paralyzing): per-Round Stamina
		# TN 20 (+5/dose) or drain another Rank, until the victim saves or the Trait hits 0
		# (Willpower 0 → mind-controlled, Reflexes 0 → paralyzed = incapacitated for the skirmish).
		if not _tp.escalating_poison.is_empty():
			var _ep_v: L5RCharacterData = chars_by_id.get(_tp.character_id, state.combatants.get(_tp.character_id, null))
			if _ep_v == null or CharacterStats.is_dead(_ep_v):
				_tp.escalating_poison = {}
			else:
				var _ep_trait: String = str(_tp.escalating_poison.get("trait", ""))
				var _ep_res: Dictionary = DiseaseSystem.escalating_tick(_ep_v, _tp.escalating_poison, dice_engine)
				if bool(_ep_res.get("incapacitated", false)):
					_apply_escalating_incapacitation(state, _tp, _ep_v, _ep_trait)
				if bool(_ep_res.get("ended", false)):
					_tp.escalating_poison = {}
		# Spirit Leeching (s54.5 Kommei): per-Round Stamina TN 25 to hold breath; on a failure,
		# Willpower TN 25, and two total Willpower failures devour the soul (instant death).
		if not _tp.spirit_leech.is_empty():
			var _sl_v: L5RCharacterData = chars_by_id.get(_tp.character_id, state.combatants.get(_tp.character_id, null))
			if _sl_v == null or CharacterStats.is_dead(_sl_v) or state.combat.round_number >= int(_tp.spirit_leech.get("expiry", 0)):
				_tp.spirit_leech = {}
			else:
				var _sl_sta: int = maxi(1, _sl_v.stamina)
				if dice_engine.roll_and_keep(_sl_sta, _sl_sta, true).total < 25:
					var _sl_wp: int = maxi(1, _sl_v.willpower)
					if dice_engine.roll_and_keep(_sl_wp, _sl_wp, true).total < 25:
						_tp.spirit_leech["failures"] = int(_tp.spirit_leech.get("failures", 0)) + 1
						if int(_tp.spirit_leech["failures"]) >= 2:
							WoundSystem.apply_damage(_sl_v, 9999, 0)  # soul devoured -> instant death
							_tp.spirit_leech = {}
		# Fire (s56.6.6 / s54.10 Everything Burns): a participant standing on a burning
		# tile and/or set on fire takes 1k1 each round; armour does not reduce.
		# flame_immune spirit creatures (Kagaki) take no fire damage.
		var _fc: L5RCharacterData = chars_by_id.get(_tp.character_id, null)
		if _fc != null and not CharacterStats.is_dead(_fc) \
				and not (_fc.spirit_creature != null and _fc.spirit_creature.has_tag("flame_immune")):
			var _fpos: Vector2i = state.positions.get(_tp.character_id, Vector2i(-9999, -9999))
			if FireSystem.is_burning(state.map, _fpos.x, _fpos.y):
				WoundSystem.apply_damage(_fc, _fire_damage_for(_fc, dice_engine), 0)
			if _tp.on_fire and not CharacterStats.is_dead(_fc):
				WoundSystem.apply_damage(_fc, _fire_damage_for(_fc, dice_engine), 0)

	# End-of-round fire spread/extinguish (s56.6.6) — no-op when nothing is burning.
	if not state.map.burning_tiles.is_empty():
		FireSystem.process_round_end(state.map, state.weather, dice_engine)

	# s43 Tomb of Earth: maintained per-round contest. Each Round the caster re-contests (Earth+Insight
	# vs the target's Air+Insight); winning keeps the target immobilized and deals 2k2, losing frees them.
	# The tomb collapses if either party dies. No-op when no tombs are active.
	for tid in state.tomb_links.keys():
		var _tomb_cid: int = int(state.tomb_links[tid])
		var _tomb_t: L5RCharacterData = chars_by_id.get(tid, state.combatants.get(tid, null))
		var _tomb_c: L5RCharacterData = chars_by_id.get(_tomb_cid, state.combatants.get(_tomb_cid, null))
		var _tomb_tp: IndividualCombat.Participant = state.combat.participants.get(tid, null)
		if _tomb_t == null or _tomb_c == null or _tomb_tp == null \
				or CharacterStats.is_dead(_tomb_t) or CharacterStats.is_dead(_tomb_c):
			if _tomb_tp != null:
				_tomb_tp.conditions.erase(IndividualCombat.CONDITION_INCAPACITATED)
			state.tomb_links.erase(tid)
			continue
		var _ce: int = maxi(1, CharacterStats.get_ring_value(_tomb_c, Enums.Ring.EARTH))
		var _ta: int = maxi(1, CharacterStats.get_ring_value(_tomb_t, Enums.Ring.AIR))
		var _croll: int = dice_engine.roll_and_keep(_ce, _ce, true).total + _tomb_c.insight_rank
		var _troll: int = dice_engine.roll_and_keep(_ta, _ta, true).total + _tomb_t.insight_rank
		if _croll >= _troll:
			if IndividualCombat.CONDITION_INCAPACITATED not in _tomb_tp.conditions:
				_tomb_tp.conditions.append(IndividualCombat.CONDITION_INCAPACITATED)
			WoundSystem.apply_damage(_tomb_t, dice_engine.roll_and_keep(2, 2, true).total, 0)
		else:
			_tomb_tp.conditions.erase(IndividualCombat.CONDITION_INCAPACITATED)
			state.tomb_links.erase(tid)

	# Persistent spell zones (Wall of Fire, Enticing the Dance of Flame, etc.) — no-op when empty.
	if not state.spell_zones.is_empty():
		_process_spell_zones(state, dice_engine)

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
# True if a spell with this combat effect can reach the target tile from the caster.
# Ranged single / aimed AoE: distance <= range_tiles. Self-centered AoE: distance <= radius.
static func _spell_reaches(
	state: MapCombatState, caster_id: int, target_id: int, eff: Dictionary,
) -> bool:
	if not state.positions.has(caster_id) or not state.positions.has(target_id):
		return false
	var cp: Vector2i = state.positions[caster_id]
	var tp: Vector2i = state.positions[target_id]
	var d: int = maxi(absi(cp.x - tp.x), absi(cp.y - tp.y))
	var rng: int = eff.get("range_tiles", 0)
	var rad: int = eff.get("aoe_radius", 0)
	if rng > 0:
		return d <= rng
	if rad > 0:
		return d <= rad
	return d <= 1


## NPC shugenja spell-cast hook (PC-present skirmish). Structural AI — the GDD gives no NPC
## combat spell policy (same class as _npc_pick_atemi / _npc_maybe_activate_kiho). Priority:
## (1) offensive damage/status at best_target if a known castable spell reaches it (highest ML);
## (2) heal self when HURT+, else an adjacent wounded ally; (3) self-buff if not already buffed.
## Casting is a Complex action; execute_cast_spell spends it + the slot. Returns {cast, ...}.
static func _npc_maybe_cast_spell(
	state: MapCombatState, npc_id: int, npc: L5RCharacterData,
	best_target: int, chars_by_id: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if npc.spells_known.is_empty():
		return {}
	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {}
	# (1) Offensive: best castable damage/status spell that reaches the chosen enemy.
	if best_target >= 0:
		var best_off: String = ""
		var best_ml: int = -1
		for sid in npc.spells_known:
			var eff: Dictionary = SpellSystem.get_combat_effect(sid)
			var k: String = eff.get("kind", "")
			if k != "damage" and k != "status":
				continue
			if not SpellSystem.can_cast(npc, sid):
				continue
			if not _spell_reaches(state, npc_id, best_target, eff):
				continue
			var ml: int = SpellSystem.SPELL_LIBRARY.get(sid, {}).get("m", 1)
			if ml > best_ml:
				best_ml = ml
				best_off = sid
		if best_off != "":
			var tc: L5RCharacterData = chars_by_id.get(best_target, state.combatants.get(best_target, null))
			var r: Dictionary = execute_cast_spell(state, npc_id, npc, best_off, best_target, tc, dice_engine)
			r["cast"] = r.get("success", false) or r.get("absorbed", false)
			r["spell_id"] = best_off
			return r
	# (2) Heal: self when HURT or worse, else an adjacent wounded ally.
	var heal_id: int = -1
	if CharacterStats.get_wound_level(npc) >= Enums.WoundLevel.HURT:
		heal_id = npc_id
	else:
		var cf: String = String(state.factions.get(npc_id, ""))
		var cpos: Vector2i = state.positions.get(npc_id, Vector2i.ZERO)
		for aid in state.positions.keys():
			if aid == npc_id or String(state.factions.get(aid, "")) != cf:
				continue
			var ach = state.combatants.get(aid, null)
			if ach == null or CharacterStats.is_dead(ach) or ach.wounds_taken <= 0:
				continue
			var apos: Vector2i = state.positions[aid]
			if maxi(absi(cpos.x - apos.x), absi(cpos.y - apos.y)) <= 1:
				heal_id = aid
				break
	if heal_id >= 0:
		for sid in npc.spells_known:
			if SpellSystem.get_combat_effect(sid).get("kind", "") != "heal":
				continue
			if not SpellSystem.can_cast(npc, sid):
				continue
			var hc: L5RCharacterData = npc if heal_id == npc_id else chars_by_id.get(heal_id, state.combatants.get(heal_id, null))
			var hr: Dictionary = execute_cast_spell(state, npc_id, npc, sid, heal_id, hc, dice_engine)
			hr["cast"] = hr.get("success", false)
			hr["spell_id"] = sid
			return hr
	# (2b) Support reposition (s36 Hands of the Tides): pull a melee-pressured ally to a safer ally's
	# tile. Only fires when a strictly-beneficial swap exists (no pointless casts). Structural AI —
	# GDD specifies no NPC use policy for the spell, only its mechanic.
	for sid in npc.spells_known:
		if SpellSystem.get_combat_effect(sid).get("kind", "") != "reposition":
			continue
		if not SpellSystem.can_cast(npc, sid):
			continue
		if _reposition_best_pair(state, npc_id, npc, int(SpellSystem.get_combat_effect(sid).get("range_tiles", 20))).is_empty():
			continue
		var rr: Dictionary = execute_cast_spell(state, npc_id, npc, sid, npc_id, npc, dice_engine)
		rr["cast"] = rr.get("success", false)
		rr["spell_id"] = sid
		return rr
	# (3) Self-buff if not already buffed.
	if not IndividualCombat.has_timed_modifier_source(p, "spell_buff"):
		for sid in npc.spells_known:
			var eff2: Dictionary = SpellSystem.get_combat_effect(sid)
			if eff2.get("kind", "") != "buff" or eff2.get("target", "self") != "self":
				continue
			if not SpellSystem.can_cast(npc, sid):
				continue
			var br: Dictionary = execute_cast_spell(state, npc_id, npc, sid, npc_id, npc, dice_engine)
			br["cast"] = br.get("success", false)
			br["spell_id"] = sid
			return br
	return {}


## s43 Bleeding: apply a per-round bleed (N Wounds/Round, ticked in advance_round) to an already-injured
## target. Requires the target to have at least 1 Wound (the kansen reopens an existing injury). Stacks
## if recast. The "bandage with Medicine to stop it" cure is a future out-of-combat action.
static func _apply_maho_bleed(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData, eff: Dictionary,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	if target.wounds_taken < 1:
		return {"reason": "target_not_injured"}
	var rng: int = int(eff.get("range_tiles", 10))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	var p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if p == null:
		return {"reason": "not_in_combat"}
	var wpr: int = int(eff.get("wounds_per_round", 1))
	IndividualCombat.add_timed_modifier(p, "bleed", wpr, state.combat.round_number + 9999, "maho_bleed")
	return {"id": target_id, "bleed_per_round": wpr}


## s43 Drain the Soul (Earth 2): reduce the target's Stamina by 1. The COMBAT-relevant effect is the
## lowered wound capacity, which only manifests when Stamina is the Earth-determining trait
## (stamina <= willpower) — reducing a higher Stamina does not change Earth, so no combat effect (faithful,
## not invented). When it applies, routes through the s34 ring-change mechanism (-1 Earth, floored at 1,
## capacity drop, possibly lethal on an already-wounded target).
static func _apply_maho_drain_soul(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	var rng: int = int(eff.get("range_tiles", 10))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	if target.stamina > target.willpower:
		return {"id": target_id, "no_capacity_change": true}
	var rc_eff: Dictionary = {"target": "enemy", "ring": Enums.Ring.EARTH, "delta": -1,
		"range_tiles": rng, "duration_rounds": int(eff.get("duration_rounds", 9999))}
	return _apply_spell_ring_change(state, caster_id, caster, target_id, target, rc_eff, dice_engine)


## Nearest living same-faction ally (excluding self), or -1 if none. Used for Blood Armor's sacrifice.
static func _nearest_ally_id(state: MapCombatState, who_id: int) -> int:
	var cf: String = String(state.factions.get(who_id, ""))
	var cpos: Vector2i = state.positions.get(who_id, Vector2i.ZERO)
	var best: int = -1
	var bestd: int = 1 << 30
	for oid in state.positions.keys():
		if int(oid) == who_id:
			continue
		if String(state.factions.get(oid, "")) != cf:
			continue
		var oc: L5RCharacterData = state.combatants.get(oid, null)
		if oc == null or CharacterStats.is_dead(oc):
			continue
		var op: Vector2i = state.positions[oid]
		var d: int = maxi(absi(op.x - cpos.x), absi(op.y - cpos.y))
		if d < bestd:
			bestd = d
			best = int(oid)
	return best


## s43 Blood Armor (Earth 5): the wearer bonds the nearest living ally as a sacrifice — from then on the
## wearer channels 75% of its incoming damage into that victim (handled in _apply_hit), keeping only 25%.
static func _apply_maho_blood_armor(state: MapCombatState, caster_id: int) -> Dictionary:
	var victim_id: int = _nearest_ally_id(state, caster_id)
	if victim_id < 0:
		return {"reason": "no_sacrifice"}
	state.blood_armor_links[caster_id] = victim_id
	return {"id": caster_id, "victim_id": victim_id}


## s43 Tomb of Earth (Earth 4): entomb the target — immobilize (incapacitated) + an initial 2k2, and
## establish a maintained per-round contest (processed in advance_round). Cannot affect a target with 1+
## full Rank of Taint (the earth will not hold the corrupt). The petrify-on-kill flavour is not modeled.
static func _apply_maho_tomb(
	state: MapCombatState, caster_id: int, target_id: int, target: L5RCharacterData,
	eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	if MutationSystem.get_taint_rank(target.taint) >= 1:
		return {"reason": "taint_immune"}
	var rng: int = int(eff.get("range_tiles", 10))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp2: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp2.x), absi(cp.y - tp2.y)) > rng:
			return {"reason": "out_of_range"}
	var p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if p == null:
		return {"reason": "not_in_combat"}
	if IndividualCombat.CONDITION_INCAPACITATED not in p.conditions:
		p.conditions.append(IndividualCombat.CONDITION_INCAPACITATED)
	var dmg: int = dice_engine.roll_and_keep(2, 2, true).total
	WoundSystem.apply_damage(target, dmg, 0)
	state.tomb_links[target_id] = caster_id
	return {"id": target_id, "immobilized": true, "damage": dmg}


## s43 Inspire Fear / Mists of Fear: a maho-induced fear — the target is Afraid (−1k0 to all rolls) for
## the duration, persisting independently of proximity via the `spell_afraid` timed modifier (which
## apply_fear_checks reads to keep AFRAID active). Optional Willpower save (Mists of Fear). Sets AFRAID
## immediately so it bites before the target's next fear check.
static func _apply_maho_fear(
	state: MapCombatState, caster_id: int, caster: L5RCharacterData,
	target_id: int, target: L5RCharacterData, eff: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if target == null or CharacterStats.is_dead(target):
		return {"reason": "no_target"}
	var rng: int = int(eff.get("range_tiles", 10))
	if state.positions.has(caster_id) and state.positions.has(target_id):
		var cp: Vector2i = state.positions[caster_id]
		var tp: Vector2i = state.positions[target_id]
		if maxi(absi(cp.x - tp.x), absi(cp.y - tp.y)) > rng:
			return {"reason": "out_of_range"}
	var save: String = String(eff.get("save", "none"))
	if save != "none" and _spell_save_resisted(
			state, caster, target, save, int(eff.get("save_tn", 0)), dice_engine):
		return {"id": target_id, "fear": "resisted"}
	var p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if p == null:
		return {"reason": "not_in_combat"}
	var dur: int = int(eff.get("duration_rounds", 9999))
	IndividualCombat.add_timed_modifier(p, "spell_afraid", 1, state.combat.round_number + dur, "maho_fear")
	if IndividualCombat.CONDITION_AFRAID not in p.conditions:
		p.conditions.append(IndividualCombat.CONDITION_AFRAID)
	return {"id": target_id, "afraid": true}


## s43 maho-user enemy cast (Bloodspeaker/cult, s56.14). Mirrors _npc_maybe_cast_spell but for maho:
## gated on cult_affiliation (a maho-user), no cast roll, Ring-supported spell selection. (1) highest-ML
## status/debuff maho that reaches the chosen enemy; else (2) a self-buff if not already buffed. Returns
## the execute_cast_maho result (with `success`), or {} if nothing was cast. The blood-cost-lethal guard
## inside execute_cast_maho keeps a near-dead maho-user from cutting itself to death.
static func _npc_maybe_cast_maho(
	state: MapCombatState, npc_id: int, npc: L5RCharacterData,
	best_target: int, chars_by_id: Dictionary, dice_engine: DiceEngine,
) -> Dictionary:
	if npc == null or not npc.cult_affiliation:
		return {}
	var ts = state.turn_states.get(npc_id, null)
	if ts == null or not ts.can_use_complex():
		return {}
	# (1) Offense: the highest-ML status/debuff maho the caster's Ring supports, reaching the target.
	if best_target >= 0:
		var best_off: String = ""
		var best_ml: int = -1
		for sid in MahoSpellLibrary.MAHO_COMBAT_EFFECTS:
			var eff: Dictionary = MahoSpellLibrary.MAHO_COMBAT_EFFECTS[sid]
			var k: String = String(eff.get("kind", ""))
			if k != "status" and k != "debuff" and k != "damage" and k != "bleed" and k != "fear" \
					and k != "tomb" and k != "drain_soul":
				continue
			if not MahoSpellLibrary.supports_spell_ring(npc, sid):
				continue
			# Bleeding only works on an already-injured target — skip it on a healthy one.
			if k == "bleed":
				var tc0: L5RCharacterData = chars_by_id.get(best_target, state.combatants.get(best_target, null))
				if tc0 == null or tc0.wounds_taken < 1:
					continue
			if not _spell_reaches(state, npc_id, best_target, eff):
				continue
			var ml: int = int(MahoSpellLibrary.get_spell(sid).get("mastery_level", 1))
			if ml > best_ml:
				best_ml = ml
				best_off = sid
		if best_off != "":
			var tc: L5RCharacterData = chars_by_id.get(best_target, state.combatants.get(best_target, null))
			var r: Dictionary = execute_cast_maho(state, npc_id, npc, best_off, best_target, tc, dice_engine)
			if r.get("success", false):
				return r
	# (2a) Blood Armor: a self-protective cast — bond an ally to soak 75% of incoming damage. Cast when
	# supportable, a sacrifice is present (the upfront precondition gates it), and not already armored.
	if MahoSpellLibrary.MAHO_COMBAT_EFFECTS.has("blood_armor") \
			and MahoSpellLibrary.supports_spell_ring(npc, "blood_armor") \
			and not state.blood_armor_links.has(npc_id):
		var ba: Dictionary = execute_cast_maho(state, npc_id, npc, "blood_armor", npc_id, npc, dice_engine)
		if ba.get("success", false):
			return ba
	# (2b) Self-buff if not already buffed.
	for sid in MahoSpellLibrary.MAHO_COMBAT_EFFECTS:
		var eff2: Dictionary = MahoSpellLibrary.MAHO_COMBAT_EFFECTS[sid]
		if String(eff2.get("kind", "")) != "buff" or String(eff2.get("target", "self")) != "self":
			continue
		if not MahoSpellLibrary.supports_spell_ring(npc, sid):
			continue
		var bp: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
		if bp != null and IndividualCombat.get_timed_modifier_total(bp, "spell_attack_rolled") > 0:
			continue  # already buffed
		var br: Dictionary = execute_cast_maho(state, npc_id, npc, sid, npc_id, npc, dice_engine)
		if br.get("success", false):
			return br
	return {}


static func execute_npc_turn(
	state: MapCombatState,
	npc_id: int,
	npc: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var actions_taken: Array = []
	# A dead NPC is skipped regardless of turn-state registration.
	if CharacterStats.is_dead(npc):
		return {"actions": [], "reason": "dead"}

	var ts: TurnState = state.turn_states.get(npc_id, null)
	if ts == null:
		return {"actions": [], "reason": "not_in_combat"}

	var wl: int = CharacterStats.get_wound_level(npc)

	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {"actions": [], "reason": "participant_missing"}

	begin_turn(state, npc_id)

	# Held / bound / treated-as-Down (s34/s35/s36/s37 incapacitation spells): the combatant
	# may take no Actions on its Turn. Skip it entirely (the timed condition auto-expires in
	# advance_round). Passive effects (fire/zone damage, others' attacks) still apply to it.
	if IndividualCombat.CONDITION_INCAPACITATED in p.conditions:
		return {"actions": [], "reason": "incapacitated"}

	# -- Fear (s22.3/s02.4): resist nearby Fear sources or fight afraid (-1k0). --
	apply_fear_checks(state, npc_id, npc, dice_engine)

	# -- Bleeding: a bleeding NPC with Medicine bandages the wound shut (s43 Bleeding cure) before
	# anything offensive — it is a steady per-round drain. Self-bandage (Complex Action); forgoes the
	# turn's attack. Gated on an active bleed + Medicine >= 1 + an available Complex.
	if ts.can_use_complex() and int(npc.skills.get("Medicine", 0)) >= 1 \
			and IndividualCombat.get_timed_modifier_total(p, "bleed") > 0:
		var bw: Dictionary = execute_stop_bleeding(state, npc_id, npc, npc_id, npc, dice_engine)
		actions_taken.append({"action": "stop_bleeding", "result": bw})
		return {"actions": actions_taken}

	# -- Duelist's Challenge (s54.10): lift a finished duel, let the General issue one
	# (free), and make ceasefire-bound Musha hold their attacks while a duel stands.
	_clear_duel_if_over(state, chars_by_id)
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("duel_offer"):
		var duel_r: Dictionary = _npc_maybe_offer_duel(state, npc_id, npc)
		if not duel_r.is_empty():
			actions_taken.append({"action": "duel_challenge", "result": duel_r})
	if _duel_ceasefire_blocks(state, npc_id, npc):
		actions_taken.append({"action": "duel_ceasefire_hold"})
		return {"actions": actions_taken}

	# -- Shapeshifter: turn insubstantial when threatened (s54.10 Ephemeral Form) --
	# Free Action; once per encounter. No-op for creatures without the ability.
	_npc_maybe_activate_ephemeral_form(state, npc, p)

	# -- Shugenja: cast a spell (offense at the target, heal/buff otherwise) -----
	# Structural AI — runs BEFORE the stance pick because casting is the turn's Complex
	# action: a Simple spent on a stance change would forbid the Complex (1 Complex OR
	# 2 Simple). A grappled caster can't gesture; prone casting is allowed (no stand needed).
	# -- Maho-user cast (s43 maho in tile combat) ---------------------------
	# A cult/Bloodspeaker maho-user (cult_affiliation) casts a maho combat spell — no roll, paying
	# self-blood. Runs before the shugenja-spell block; maho-users carry no shugenja spells_known so
	# the two never conflict. Grappled can't gesture; prone is allowed.
	if npc.cult_affiliation and ts.can_use_complex() \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED):
		var maho_best: int = _npc_pick_target(
			state, npc_id, get_melee_targets(state, npc_id) + get_ranged_targets(state, npc_id), chars_by_id)
		var maho_r: Dictionary = _npc_maybe_cast_maho(state, npc_id, npc, maho_best, chars_by_id, dice_engine)
		if maho_r.get("success", false):
			actions_taken.append({"action": "cast_maho", "result": maho_r})
			return {"actions": actions_taken}

	if not npc.spells_known.is_empty() and ts.can_use_complex() \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED):
		var cast_best: int = _npc_pick_target(
			state, npc_id, get_melee_targets(state, npc_id) + get_ranged_targets(state, npc_id), chars_by_id)
		var cast_r: Dictionary = _npc_maybe_cast_spell(state, npc_id, npc, cast_best, chars_by_id, dice_engine)
		if cast_r.get("cast", false):
			actions_taken.append({"action": "cast_spell", "result": cast_r})
			return {"actions": actions_taken}

	# -- Guard a wounded, threatened adjacent ally (s40, Simple Action) -------
	# Bodyguard reflex: raise a hurt ally's Armor TN (+10) at -5 to its own. Runs before
	# the stance pick — Guard is a Simple Action, so the NPC commits its turn to protecting
	# the ally and forgoes its own attack. Skipped while grappled or prone (handled below).
	if not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED) \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE):
		var guard_r: Dictionary = _npc_maybe_guard(state, npc_id, npc, chars_by_id)
		if not guard_r.is_empty():
			actions_taken.append({"action": "guard", "result": guard_r})
			return {"actions": actions_taken}

	# -- Auto-climb toward an enemy blocked by a cliff/wall (s4.4 Z-axis) ------
	# Decided BEFORE the stance pick: climb is the turn's Complex action, and a stance change
	# (a Simple) would forbid the Complex this turn (1 Complex OR 2 Simple). Only fires when
	# there is NO normal walking route to the nearest enemy (find_path empty — genuinely walled
	# or cliffed off) AND a cliff/wall scale strictly closes the gap, so the NPC never climbs
	# when it could just walk around. Skipped while grappled/prone/down-restricted.
	if ts.can_use_complex() and not ts.is_down_restricted(wl) \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED) \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE):
		var ne: Vector2i = _nearest_enemy_pos(state, npc_id)
		if ne.x >= 0 and find_path(state, npc_id, ne).is_empty():
			var eclimb: Dictionary = _npc_maybe_climb_toward(state, npc_id, ne, npc, dice_engine)
			if eclimb.get("success", false):
				actions_taken.append({"action": "climb", "result": eclimb})
				return {"actions": actions_taken}

	# -- Pick optimal stance -----------------------------------------------
	var stance_result: Dictionary = _npc_pick_stance(state, npc_id, npc, chars_by_id, dice_engine)
	if stance_result.get("changed", false):
		actions_taken.append(stance_result)

	# -- Monk: buff up with a kiho at the start of the fight (s38/s38a) --------
	# Free action (Void Point), so it does not consume the move/attack budget.
	if p.active_kiho.is_empty():
		var kiho_r: Dictionary = _npc_maybe_activate_kiho(state, npc_id, npc, dice_engine)
		if kiho_r.get("success", false):
			actions_taken.append(kiho_r)

	# -- The World Is Empty (s30a): a WIE bushi powers up on round 1 (Simple
	# action), forgoing this turn's attack so the +Xk0 covers the rest of the
	# fight. Basic heuristic (the GDD gives no NPC activation policy); VP>=2 so the
	# buff outlasts the turn spent activating it.
	if state.combat.round_number == 1 and npc.current_void_points >= 2 \
			and "The World Is Empty" in npc.katas \
			and not IndividualCombat.has_timed_modifier_source(p, WIE_SOURCE):
		var wie_r: Dictionary = execute_activate_world_is_empty(state, npc_id, npc)
		if wie_r.get("success", false):
			actions_taken.append(wie_r)
			return {"actions": actions_taken, "activated_world_is_empty": true}

	# -- Handle grapple -------------------------------------------------------
	if IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED):
		# s54.10 Deceptive Weight: a pinned victim struggles free with Athletics/Strength
		# vs TN 40 (not the normal grapple contest).
		if p.deceptive_weight_pinned and not p.grapple_in_control:
			var esc: Dictionary = attempt_deceptive_weight_escape(state, npc_id, npc, dice_engine)
			actions_taken.append({"action": "deceptive_weight_escape", "result": esc})
			return {"actions": actions_taken}
		# s54.5 Swallow Whole/Devour: a swallowed victim struggles free (Contested Strength).
		if p.swallowed_by_id != -1:
			var sesc: Dictionary = attempt_swallow_escape(state, npc_id, npc, dice_engine)
			actions_taken.append({"action": "swallow_escape", "result": sesc})
			return {"actions": actions_taken}
		if p.grapple_in_control:
			# In control: try to hit or throw.
			var partner_id: int = p.grapple_partner_id
			var partner: L5RCharacterData = chars_by_id.get(partner_id, null)
			if partner != null and not CharacterStats.is_dead(partner):
				var ga: Dictionary = execute_grapple_action(state, npc_id, "hit", npc, partner, dice_engine)
				actions_taken.append({"action": "grapple_hit", "result": ga})
		else:
			# Not in control: a dedicated grappler contests control; a weapon-fighter who
			# got grabbed breaks free (Simple, s40) to return to its weapon next turn.
			var partner_id: int = p.grapple_partner_id
			var partner: L5RCharacterData = chars_by_id.get(partner_id, null)
			if partner != null and not CharacterStats.is_dead(partner):
				if _npc_should_grapple(npc):
					var gc: Dictionary = execute_grapple_action(state, npc_id, "take_control", npc, partner, dice_engine)
					actions_taken.append({"action": "grapple_control", "result": gc})
				else:
					var gb: Dictionary = execute_grapple_action(state, npc_id, "break", npc, partner, dice_engine)
					actions_taken.append({"action": "grapple_break", "result": gb})
		return {"actions": actions_taken}

	# -- Stand up if prone ----------------------------------------------------
	if IndividualCombat.has_condition(p, IndividualCombat.CONDITION_PRONE):
		if not ts.is_down_restricted(wl) and ts.can_use_simple():
			var su: Dictionary = execute_stand_up(state, npc_id, npc)
			actions_taken.append({"action": "stand_up", "result": su})

	# -- Recover a disarmed weapon (s40): pick it back up (Simple) rather than fight
	# unarmed. Spends the Simple, so no Complex attack this turn — the Disarm's tempo cost.
	# A weapon swept away by Gathering Swirl (s33) can't be recovered, so don't try.
	if p.disarmed and not p.weapon_swept and not ts.is_down_restricted(wl) and ts.can_use_simple():
		var rw: Dictionary = execute_recover_weapon(state, npc_id, npc)
		if rw.get("success", false):
			actions_taken.append({"action": "recover_weapon", "result": rw})

	# -- Defensive stance: hold and turtle ------------------------------------
	# Defense / Full Defense Stance cannot attack (GDD s40). A wounded NPC that
	# committed to a defensive stance holds position (it already gained the
	# Armor TN benefit from the stance change) and relies on its allies rather
	# than attempting a doomed attack.
	if p.stance == Enums.Stance.DEFENSE or p.stance == Enums.Stance.FULL_DEFENSE:
		return {"actions": actions_taken}

	# -- Identify best target -------------------------------------------------
	var melee_targets: Array = get_melee_targets(state, npc_id)
	var ranged_targets: Array = get_ranged_targets(state, npc_id)
	var best_target: int = _npc_pick_target(state, npc_id, melee_targets + ranged_targets, chars_by_id)

	# Duelist's Challenge (s54.10): the challenger focuses its chosen opponent when in reach.
	if npc_id == state.duel_challenger_id and state.duel_target_id in (melee_targets + ranged_targets):
		best_target = state.duel_target_id

	if best_target < 0:
		# Mists of Illusion (s33): with no real target in sight, a visible phantom within
		# reach lures the NPC — it drifts to the illusion and strikes it (visual-only, so it
		# is revealed the instant it is struck), wasting the turn. This is the spell's faithful
		# use: a stationary visual decoy fools an enemy only when it cannot compare it to the
		# real thing (the PC has broken line of sight).
		var lure_reach: int = free_move_budget(state, npc_id, npc)
		var phantom: Dictionary = _nearest_visible_phantom(state, npc_id, lure_reach + 1)
		if not phantom.is_empty():
			var pt: Vector2i = Vector2i(int(phantom["x"]), int(phantom["y"]))
			var npd: Vector2i = state.positions[npc_id]
			if maxi(absi(pt.x - npd.x), absi(pt.y - npd.y)) > 1:
				execute_move(state, npc_id, pt, lure_reach, npc, dice_engine, "free")
				npd = state.positions[npc_id]
			if maxi(absi(pt.x - npd.x), absi(pt.y - npd.y)) <= 1:
				var ts_l: TurnState = state.turn_states.get(npc_id, null)
				if ts_l != null and ts_l.can_use_complex():
					ts_l.consume_complex()
				state.illusion_phantoms.erase(phantom)
				actions_taken.append({"type": "attack_illusion", "x": pt.x, "y": pt.y, "dispelled": true})
		return {"actions": actions_taken}

	var weapon_name: String = IndividualCombat.pick_best_weapon(npc)
	var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
	var is_melee_weapon: bool = wp.get("melee", true)

	# -- Move toward target if needed -----------------------------------------
	var target_in_melee: bool = (best_target in melee_targets)
	var target_in_ranged: bool = (best_target in ranged_targets)

	# Charge (s54.5/s54.12): a charge-capable creature out of melee but within charge range
	# enters Full Attack (if able) and closes + strikes in one turn.
	if npc.spirit_creature != null and npc.spirit_creature.charge_move_mult > 0 \
			and not target_in_melee \
			and IndividualCombat.CONDITION_ENTANGLED not in p.conditions:
		var chg: Dictionary = execute_charge(state, npc_id, best_target, npc, chars_by_id.get(best_target, state.combatants.get(best_target, null)), dice_engine)
		if chg.get("charged", false):
			actions_taken.append({"action": "charge", "result": chg})
			return {"actions": actions_taken}

	# Entangled (s54.12 Web / s56.20 Snare): an entangled NPC that can't reach a target
	# struggles to break free (Strength TN 20) instead of a futile move.
	if IndividualCombat.CONDITION_ENTANGLED in p.conditions and not target_in_melee:
		var eesc: Dictionary = attempt_entangle_escape(state, npc_id, npc, dice_engine)
		actions_taken.append({"action": "entangle_escape", "result": eesc})
		return {"actions": actions_taken}

	if not target_in_melee and not target_in_ranged:
		# Move toward target using free move first, then simple if needed.
		var moved: bool = false
		if ts.can_use_free_move() and not ts.is_down_restricted(wl):
			var free_budget: int = free_move_budget(state, npc_id, npc)
			var move_r: Dictionary = _npc_move_toward(state, npc_id, best_target, npc, free_budget, "free", dice_engine)
			if move_r.get("success", false):
				actions_taken.append({"action": "free_move", "result": move_r})
				moved = true
				melee_targets = get_melee_targets(state, npc_id)
				target_in_melee = (best_target in melee_targets)

		if not target_in_melee and ts.can_use_simple() and not ts.is_down_restricted(wl):
			var simple_budget: int = simple_move_budget(state, npc_id, npc)
			var move_r: Dictionary = _npc_move_toward(state, npc_id, best_target, npc, simple_budget, "simple", dice_engine)
			if move_r.get("success", false):
				actions_taken.append({"action": "simple_move", "result": move_r})
				melee_targets = get_melee_targets(state, npc_id)
				target_in_melee = (best_target in melee_targets)

	# Re-check targets after movement.
	if not target_in_melee:
		ranged_targets = get_ranged_targets(state, npc_id)
		target_in_ranged = (best_target in ranged_targets)

	# -- Creature melee multi-target attack (s54.12 blue whale Tail Smash / Yamato no Orochi
	# Torso Bludgeon): strikes the primary target + everyone within ranged_aoe_radius of it
	# when adjacent. Reuses execute_creature_aoe_attack (range gate = ranged_range_tiles = 1).
	# Only fires when 2+ enemies cluster near the primary — otherwise it falls through to the
	# normal attack (e.g. the Orochi bites instead of bludgeoning a lone foe, per GDD choice).
	if npc.spirit_creature != null and npc.spirit_creature.melee_aoe \
			and npc.spirit_creature.ranged_aoe_radius > 0 and target_in_melee \
			and not (npc.spirit_creature.ranged_aoe_once and p.ranged_aoe_used) \
			and _enemies_within(state, npc_id, best_target, npc.spirit_creature.ranged_aoe_radius) >= 2:
		var maoe: Dictionary = execute_creature_aoe_attack(state, npc_id, best_target, npc, dice_engine)
		if maoe.get("ok", false):
			actions_taken.append({"action": "creature_melee_aoe", "result": maoe})
			return {"actions": actions_taken}

	# -- Creature AoE attack (s54.11 Cauldron Belch / s54.12 Gout of Flame): a fire blast
	# centred on a target in LOS + range, damaging everyone nearby. Preferred over a single
	# strike when available (and not yet used, for once-per-skirmish blasts).
	if npc.spirit_creature != null and npc.spirit_creature.ranged_aoe_radius > 0 \
			and not npc.spirit_creature.melee_aoe \
			and not target_in_melee and target_in_ranged \
			and not (npc.spirit_creature.ranged_aoe_once and p.ranged_aoe_used):
		var aoe: Dictionary = execute_creature_aoe_attack(state, npc_id, best_target, npc, dice_engine)
		if aoe.get("ok", false):
			actions_taken.append({"action": "creature_aoe", "result": aoe})
			return {"actions": actions_taken}

	# -- Creature ranged attack (s54.5 Flaming Bark / Hurl Flaming Blood): a creature with
	# a thrown/spat attack fires at a target that is in LOS + range but not in melee reach.
	if npc.spirit_creature != null \
			and (npc.spirit_creature.ranged_damage_rolled > 0 or npc.spirit_creature.ranged_entangle) \
			and npc.spirit_creature.ranged_aoe_radius == 0 \
			and not target_in_melee and target_in_ranged:
		var rtgt: L5RCharacterData = chars_by_id.get(best_target, state.combatants.get(best_target, null))
		if rtgt != null and not CharacterStats.is_dead(rtgt):
			var rr: Dictionary = execute_creature_ranged_attack(state, npc_id, best_target, npc, rtgt, dice_engine)
			if rr.get("ok", false):
				actions_taken.append({"action": "creature_ranged", "result": rr})
				return {"actions": actions_taken}

	# -- Lure (s54.10 Konak Jiji): a disguised "baby" waits; if a victim is adjacent it
	# springs the deceptive-weight trap (auto-hit + pin + venom) or is seen through. Either
	# way the disguised creature's turn ends here (it does nothing else while luring).
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("lure") \
			and not p.lure_sprung:
		var lure_r: Dictionary = _npc_maybe_spring_lure(state, npc_id, npc, chars_by_id, dice_engine)
		if not lure_r.is_empty():
			actions_taken.append({"action": "lure", "result": lure_r})
			return {"actions": actions_taken}

	# -- Mimic (s54.10): a hurt shapeshifter (Kitsune/Bakeneko) assumes another form to
	# escape — untargetable for 5 Rounds or until it attacks. The disguise is the turn's
	# Complex action.
	if npc.spirit_creature != null:
		var mim: Dictionary = _npc_maybe_mimic(state, npc_id, npc)
		if mim.get("success", false):
			actions_taken.append({"action": "mimic", "result": mim})
			return {"actions": actions_taken}

	# -- Possession (s54.10/s54.2): a possessing spirit in melee with a valid victim
	# seeds a cross-encounter possession affliction (resolved in the world-sim) instead
	# of attacking. Kitsune-tsuki requires a Down/Out victim; Shozai/Buruburu may try any.
	if target_in_melee and npc.spirit_creature != null:
		var poss: Dictionary = _npc_maybe_possess(state, npc_id, best_target, npc, chars_by_id, dice_engine)
		if poss.get("success", false):
			actions_taken.append({"action": "possession", "result": poss})
			return {"actions": actions_taken}

	# -- Strength of the Dead (s54.12 Wanyudo): a once-per-skirmish scream that Stuns nearby
	# mortal enemies (Contested Willpower).
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("strength_of_the_dead") and not p.scream_used:
		var scr: Dictionary = _npc_maybe_scream(state, npc_id, npc, dice_engine)
		if scr.get("success", false):
			actions_taken.append({"action": "scream", "result": scr})
			return {"actions": actions_taken}

	# -- Taint Affliction (s54.5 Gagoze): a Complex-action burning gaze that, on a won
	# Contested Willpower, inflicts 1 full Rank of Taint on a mortal enemy (once each).
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("taint_affliction"):
		var gaze: Dictionary = _npc_maybe_taint_gaze(state, npc_id, npc, chars_by_id, dice_engine)
		if gaze.get("success", false):
			actions_taken.append({"action": "taint_gaze", "result": gaze})
			return {"actions": actions_taken}

	# -- Spirit Leeching (s54.5 Kommei): a Simple-action soul-fog on adjacent mortal enemies;
	# the per-Round Stamina/Willpower death resolution runs in advance_round.
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("spirit_leeching"):
		var fog: Dictionary = _npc_maybe_spirit_leech(state, npc_id, npc, dice_engine)
		if fog.get("success", false):
			actions_taken.append({"action": "spirit_leech", "result": fog})
			return {"actions": actions_taken}

	# -- Dark Mirror (s54.5 Manesuru): study an enemy across two consecutive Complex Actions
	# (Uncanny Insight), then spawn a duplicate of it (Spawn Dark Mirror). Its MO over attacking.
	if npc.spirit_creature != null and npc.spirit_creature.has_tag("spawn_dark_mirror") and best_target >= 0:
		var dm: Dictionary = _npc_maybe_dark_mirror(state, npc_id, best_target, npc, dice_engine)
		if dm.get("success", false):
			actions_taken.append({"action": dm.get("kind", "dark_mirror"), "result": dm})
			return {"actions": actions_taken}

	# -- Atemi (s38): a monk in melee delivers a known (encoded) atemi kiho instead
	# of a normal strike, applying its condition/timed debuff. Basic heuristic (the
	# GDD gives no NPC atemi policy); the atemi is the turn's Complex action.
	if target_in_melee and npc.school_type == Enums.SchoolType.MONK:
		var atemi_name: String = _npc_pick_atemi(npc)
		if atemi_name != "":
			var atemi_tgt: L5RCharacterData = chars_by_id.get(best_target, null)
			if atemi_tgt != null and not CharacterStats.is_dead(atemi_tgt):
				var atemi_res: Dictionary = execute_atemi_strike(
					state, npc_id, best_target, npc, atemi_tgt, atemi_name, dice_engine)
				if atemi_res.get("success", false):
					actions_taken.append({"action": "atemi", "result": atemi_res})
					return {"actions": actions_taken}

	# -- vs-Prone Trample (s54.12 Rhino): a special Simple attack used only against a Prone
	# target (8k4 / 10k4), via a temporary profile swap (like the multi-attack second strike).
	if target_in_melee and npc.spirit_creature != null and npc.spirit_creature.vs_prone_atk_rolled > 0:
		var ptc: L5RCharacterData = chars_by_id.get(best_target, null)
		var ptp: IndividualCombat.Participant = state.combat.participants.get(best_target, null)
		if ptc != null and ptp != null and not CharacterStats.is_dead(ptc) \
				and IndividualCombat.CONDITION_PRONE in ptp.conditions and ts.can_use_simple():
			var sc: SpiritCreatureData = npc.spirit_creature
			var _oar: int = sc.attack_rolled; var _oak: int = sc.attack_kept
			var _odr: int = sc.damage_rolled; var _odk: int = sc.damage_kept
			sc.attack_rolled = sc.vs_prone_atk_rolled; sc.attack_kept = sc.vs_prone_atk_kept
			sc.damage_rolled = sc.vs_prone_dmg_rolled; sc.damage_kept = sc.vs_prone_dmg_kept
			var tr: Dictionary = execute_melee_attack(
				state, npc_id, best_target, npc, ptc, IndividualCombat.pick_best_weapon(npc), 0, dice_engine,
				"", false, false, 0, 0, true)
			sc.attack_rolled = _oar; sc.attack_kept = _oak; sc.damage_rolled = _odr; sc.damage_kept = _odk
			actions_taken.append({"action": "vs_prone_trample", "result": tr})
			return {"actions": actions_taken}

	# -- Grapple initiation (s40): a dedicated Jiujutsu grappler seizes an adjacent enemy
	# (Complex Action) instead of striking — the grappled-state loop (hit/take_control/
	# escape) is handled on later turns. Structural AI; the GDD gives no NPC policy.
	if target_in_melee and npc.spirit_creature == null and ts.can_use_complex() \
			and not IndividualCombat.has_condition(p, IndividualCombat.CONDITION_GRAPPLED) \
			and _npc_should_grapple(npc):
		var gtgt: L5RCharacterData = chars_by_id.get(best_target, null)
		if gtgt != null and not CharacterStats.is_dead(gtgt):
			var gi: Dictionary = execute_grapple_initiate(state, npc_id, best_target, npc, gtgt, dice_engine)
			actions_taken.append({"action": "grapple_initiate", "result": gi})
			return {"actions": actions_taken}

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

			# Off-hand swing (s40): a dual-wielding NPC always makes its free
			# off-hand attack when adjacent and the target still stands — it is
			# pure extra damage at the off-hand size penalty.
			if p.dual_wielding and p.off_hand_weapon != "" and target_in_melee \
					and not p.off_hand_attack_used_this_turn \
					and not CharacterStats.is_dead(target_char):
				var oh: Dictionary = execute_off_hand_attack(state, npc_id, best_target, npc, target_char, dice_engine)
				if oh.get("success", false):
					actions_taken.append({"action": "off_hand_attack", "result": oh})

			# Multi-attack (s54.5): an oni/creature with two attacks makes its second
			# Simple strike with the secondary profile. Field-swap so the to-hit AND
			# damage overrides (both read spirit_creature) use attack2, then restore.
			var mcr: SpiritCreatureData = npc.spirit_creature
			if mcr != null and mcr.has_tag("multi_attack") and mcr.has_second_attack() \
					and target_in_melee and not CharacterStats.is_dead(target_char):
				var s_ar: int = mcr.attack_rolled
				var s_ak: int = mcr.attack_kept
				var s_dr: int = mcr.damage_rolled
				var s_dk: int = mcr.damage_kept
				mcr.attack_rolled = mcr.attack2_rolled
				mcr.attack_kept = mcr.attack2_kept
				mcr.damage_rolled = mcr.damage2_rolled
				mcr.damage_kept = mcr.damage2_kept
				# bonus_attack=true: a free second strike (no action gate/consume),
				# the way the off-hand attack above is a bonus.
				var atk2: Dictionary = execute_melee_attack(
					state, npc_id, best_target, npc, target_char, weapon_name,
					0, dice_engine, "", false, true)
				mcr.attack_rolled = s_ar
				mcr.attack_kept = s_ak
				mcr.damage_rolled = s_dr
				mcr.damage_kept = s_dk
				actions_taken.append({"action": "multi_attack", "result": atk2})
				# Tail Swipe (s54.5 Arugai): the tail (second) attack may Knockdown with a
				# Free Raise. Contested Strength (+5 = the Free Raise); on a hit → Prone.
				if mcr.has_tag("tail_knockdown") and atk2.get("hit", false) \
						and not CharacterStats.is_dead(target_char):
					var _tk_p: IndividualCombat.Participant = state.combat.participants.get(best_target, null)
					if _tk_p != null:
						var _tk: Dictionary = IndividualCombat.resolve_knockdown(npc, target_char, false, dice_engine, 5)
						if _tk.get("knocked_down", false):
							IndividualCombat.apply_condition(_tk_p, IndividualCombat.CONDITION_PRONE)
							actions_taken.append({"action": "tail_swipe_knockdown", "target": best_target})
	elif ts.can_use_free_move() and not ts.is_down_restricted(wl):
		# Can still use free move to get closer.
		var free_budget: int = free_move_budget(state, npc_id, npc)
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

	# s35 Haze of Battle: locked into Full Attack — do not waste a Simple attempting a change.
	if IndividualCombat.get_timed_modifier_total(p, "stance_locked") > 0:
		return {"changed": false}

	var wl: int = CharacterStats.get_wound_level(npc)
	var desired: Enums.Stance = _npc_desired_stance(state, npc_id, npc, wl, chars_by_id)

	if p.stance == desired:
		return {"changed": false}

	# Only change stance if there's a meaningful reason (not just a marginal preference).
	var result: Dictionary = execute_stance_change(state, npc_id, desired, npc, dice_engine)
	if result.get("success", false):
		return {"changed": true, "new_stance": desired}
	return {"changed": false}


## Determine desired stance for an NPC based on wound level and role (GDD s40 stances).
## Wounded NPCs choose contextually (per design owner): a defensive stance is a
## commitment to NOT attack (s40), so it is only worthwhile when something else can
## finish the fight. Factors: the character's Defense aptitude (school skill / Defense
## rank vs their best attack skill), whether a living ally remains in the fight, and
## whether the threat is a ranged attacker (raising Armor TN to weather arrows while
## an ally closes). A lone wounded combatant fights on (CENTER) rather than turtling.
static func _npc_desired_stance(
	state: MapCombatState,
	npc_id: int,
	npc: L5RCharacterData,
	wound_level: int,
	chars_by_id: Dictionary,
) -> Enums.Stance:
	var best_combat: int = 0
	for skill_name: String in ["Kenjutsu", "Polearms", "Heavy Weapons", "Jiujutsu"]:
		best_combat = maxi(best_combat, npc.skills.get(skill_name, 0))

	if wound_level < Enums.WoundLevel.HURT:
		# Healthy: high-skill combatants press the attack (Void carry-forward);
		# low-skill combatants use CENTER for balanced defense.
		if best_combat >= 4:
			return Enums.Stance.ATTACK
		return Enums.Stance.CENTER

	# DOWN or worse is handled by the free-action path in resolve_npc_turn; the
	# stance choice is moot (no normal actions). Return a nominal aggressive stance.
	if wound_level >= Enums.WoundLevel.DOWN:
		return Enums.Stance.ATTACK

	# HURT / INJURED / CRIPPLED — contextual.
	var has_ally: bool = _npc_has_living_ally(state, npc_id, chars_by_id)
	if not has_ally:
		# Alone: no one is coming to help — turtling is slow death. Fight on with
		# CENTER (defensive lean, but still able to attack and close distance).
		return Enums.Stance.CENTER

	# Has a living ally. Turtle (DEFENSE) when the character is a Defense specialist
	# or when facing a ranged threat (raise Armor TN, let the ally engage). Otherwise
	# keep fighting in CENTER — a better attacker contributes more than a weak turtle.
	var def_rank: int = npc.skills.get("Defense", 0)
	var is_school_defense: bool = NPCAdvancement.get_school_skills(npc).has("Defense")
	var defense_specialist: bool = is_school_defense or def_rank >= best_combat
	var threat_ranged: bool = _npc_primary_threat_is_ranged(state, npc_id, chars_by_id)
	if defense_specialist or threat_ranged:
		return Enums.Stance.DEFENSE
	return Enums.Stance.CENTER


## True if a living same-faction combatant other than the NPC remains positioned
## on the map (i.e., the NPC is not the last one standing on its side).
static func _npc_has_living_ally(
	state: MapCombatState,
	npc_id: int,
	chars_by_id: Dictionary,
) -> bool:
	var my_faction: String = state.factions.get(npc_id, FACTION_NEUTRAL)
	for cid: int in state.positions.keys():
		if cid == npc_id:
			continue
		if state.factions.get(cid, FACTION_NEUTRAL) != my_faction:
			continue
		var c: L5RCharacterData = chars_by_id.get(cid, null)
		if c == null or CharacterStats.is_dead(c):
			continue
		return true
	return false


## True if any living enemy combatant's best weapon is a ranged weapon (a bow).
## Used to bias a wounded-with-ally NPC toward Defense to weather incoming fire.
static func _npc_primary_threat_is_ranged(
	state: MapCombatState,
	npc_id: int,
	chars_by_id: Dictionary,
) -> bool:
	var my_faction: String = state.factions.get(npc_id, FACTION_NEUTRAL)
	for cid: int in state.positions.keys():
		if cid == npc_id:
			continue
		var their_faction: String = state.factions.get(cid, FACTION_NEUTRAL)
		if not _are_enemies(my_faction, their_faction):
			continue
		var c: L5RCharacterData = chars_by_id.get(cid, null)
		if c == null or CharacterStats.is_dead(c):
			continue
		var weapon_name: String = IndividualCombat.pick_best_weapon(c)
		var wp: Dictionary = IndividualCombat.get_weapon_profile(weapon_name)
		if not wp.get("melee", true):
			return true
	return false


## Pick the best target: most-wounded (highest wounds_taken) enemy to focus fire.
static func _npc_pick_target(
	state: MapCombatState,
	npc_id: int,
	candidate_ids: Array,
	chars_by_id: Dictionary,
) -> int:
	# Dark Mirror (s54.5 Manesuru): a duplicate attacks the creature it copied first, while alive.
	var self_p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if self_p != null and self_p.mirror_origin_id >= 0 and self_p.mirror_origin_id in candidate_ids:
		var origin: L5RCharacterData = chars_by_id.get(self_p.mirror_origin_id, null)
		if origin != null and not CharacterStats.is_dead(origin):
			return self_p.mirror_origin_id
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


## NPC auto-climb toward an otherwise-unreachable goal (s4.4 Z-axis). When normal
## movement can't close on `tpos` because a cliff or wall blocks the direct approach,
## scale it: considers the 8 adjacent elevation-cliff steps and the 4 two-step
## wall-scales (over a single WALL_STONE/WALL_WOOD), and climbs the one that STRICTLY
## reduces Chebyshev distance to the goal. Climb is the turn's Complex action, so the
## caller ends the turn after a successful climb. Returns execute_climb's result, or {}
## when no distance-reducing climb is available. Structural AI — the GDD gives no NPC
## climb policy; the climb/fall values are all owner-locked.
static func _npc_maybe_climb_toward(
	state: MapCombatState, mover_id: int, tpos: Vector2i,
	mover: L5RCharacterData, dice_engine: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(mover_id, null)
	if ts == null or not ts.can_use_complex() or state.map == null:
		return {}
	var cur: Vector2i = state.positions.get(mover_id, Vector2i(-1, -1))
	if cur.x < 0 or tpos.x < 0:
		return {}
	var cur_dist: int = maxi(absi(tpos.x - cur.x), absi(tpos.y - cur.y))
	if cur_dist <= 1:
		return {}  # already adjacent to the goal
	var occupied: Dictionary = {}
	for cid: int in state.positions:
		if cid != mover_id:
			occupied[state.positions[cid]] = true
	# Candidates: 8 adjacent cliff tiles + 4 two-step wall-scale tiles.
	var cands: Array[Vector2i] = []
	for ax in [-1, 0, 1]:
		for ay in [-1, 0, 1]:
			if ax != 0 or ay != 0:
				cands.append(Vector2i(cur.x + ax, cur.y + ay))
	cands.append(Vector2i(cur.x + 2, cur.y)); cands.append(Vector2i(cur.x - 2, cur.y))
	cands.append(Vector2i(cur.x, cur.y + 2)); cands.append(Vector2i(cur.x, cur.y - 2))
	var best_dest: Vector2i = Vector2i(-1, -1)
	var best_dist: int = cur_dist
	for d: Vector2i in cands:
		if d.x < 0 or d.y < 0 or d.x >= state.map.width or d.y >= state.map.height:
			continue
		if occupied.has(d) or not MovementSystem.is_passable(state.map.get_tile(d.x, d.y)):
			continue
		var ddx: int = d.x - cur.x
		var ddy: int = d.y - cur.y
		var climbable: bool = false
		if maxi(absi(ddx), absi(ddy)) == 1:
			climbable = MovementSystem.is_cliff_step(state.map, cur.x, cur.y, d.x, d.y)
		elif (ddx == 0 and absi(ddy) == 2) or (ddy == 0 and absi(ddx) == 2):
			var midt: int = state.map.get_tile(cur.x + signi(ddx), cur.y + signi(ddy))
			climbable = (midt == Enums.TileType.WALL_STONE or midt == Enums.TileType.WALL_WOOD)
		if not climbable:
			continue
		var nd: int = maxi(absi(tpos.x - d.x), absi(tpos.y - d.y))
		if nd < best_dist:
			best_dist = nd
			best_dest = d
	if best_dest.x < 0:
		return {}
	return execute_climb(state, mover_id, best_dest, mover, dice_engine)


## Execute NPC attack with smart raise selection (GDD s40 maneuvers).
## When use_extra_attack is true, declares 5 Raises for Extra Attack (GDD s40:
## "These Raises confer no other benefits"), precluding Increased Damage.
# Knockdown is worthwhile only against a STANDING, competent melee fighter (dropping a
# weakling Prone wastes the 2 Raises). Structural AI heuristic — the GDD gives no NPC policy.
const _NPC_KNOCKDOWN_SKILLS: Array = ["Kenjutsu", "Iaijutsu", "Jiujutsu", "Polearms", "Heavy Weapons", "Knives"]
static func _npc_should_knockdown(state: MapCombatState, target_id: int, target: L5RCharacterData) -> bool:
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null or IndividualCombat.has_condition(t_p, IndividualCombat.CONDITION_PRONE):
		return false  # already Prone — nothing to gain
	var best: int = 0
	for sk: String in _NPC_KNOCKDOWN_SKILLS:
		best = maxi(best, int(target.skills.get(sk, 0)))
	return best >= 3  # a competent melee opponent worth disrupting


# Disarm is worthwhile only against a still-armed, HIGH-threat melee fighter (best melee
# skill >= 4). A weapon strip neutralizes them for a turn (recovery costs an action) and
# leaves them fighting unarmed. Structural AI heuristic — the GDD gives no NPC policy.
static func _npc_should_disarm(state: MapCombatState, target_id: int, target: L5RCharacterData) -> bool:
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target_id, null)
	if t_p == null or t_p.disarmed:
		return false  # already weaponless
	if IndividualCombat.pick_best_weapon(target) == "unarmed":
		return false  # nothing to disarm (unarmed fighter)
	var best: int = 0
	for sk: String in _NPC_KNOCKDOWN_SKILLS:
		best = maxi(best, int(target.skills.get(sk, 0)))
	return best >= 4  # a dangerous armed opponent worth stripping


# A dedicated grappler initiates a Grapple only when Jiujutsu is its best combat skill
# (a katana-5/jiujutsu-4 samurai keeps the sword). Jiujutsu >= 4 so the grapple roll holds.
# Structural AI heuristic — the GDD gives no NPC policy.
const _NPC_WEAPON_SKILLS: Array = ["Kenjutsu", "Iaijutsu", "Polearms", "Heavy Weapons", "Knives", "Kyujutsu", "War Fan"]
static func _npc_should_grapple(npc: L5RCharacterData) -> bool:
	var jj: int = int(npc.skills.get("Jiujutsu", 0))
	if jj < 4:
		return false
	var best_weapon: int = 0
	for sk: String in _NPC_WEAPON_SKILLS:
		best_weapon = maxi(best_weapon, int(npc.skills.get(sk, 0)))
	return jj >= best_weapon


# Position of the nearest living enemy (different faction) to `who_id` by Chebyshev
# distance, or (-1,-1) if none. Ignores LOS — used by the auto-climb pursuer to find an
# enemy it cannot currently see across an obstacle (s4.4 Z-axis).
static func _nearest_enemy_pos(state: MapCombatState, who_id: int) -> Vector2i:
	var wpos: Vector2i = state.positions.get(who_id, Vector2i(-1, -1))
	if wpos.x < 0:
		return Vector2i(-1, -1)
	var my_faction: String = String(state.factions.get(who_id, ""))
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for eid in state.positions.keys():
		if String(state.factions.get(eid, "")) == my_faction:
			continue
		var ech = state.combatants.get(eid, null)
		if ech == null or CharacterStats.is_dead(ech):
			continue
		var d: int = maxi(absi(wpos.x - state.positions[eid].x), absi(wpos.y - state.positions[eid].y))
		if d < best_d:
			best_d = d
			best = state.positions[eid]
	return best


# True if a living enemy of `faction` is adjacent (within 1 tile) to the character at `who_id`.
static func _enemy_adjacent_to(state: MapCombatState, who_id: int, faction: String) -> bool:
	var wpos: Vector2i = state.positions.get(who_id, Vector2i(-9999, -9999))
	for eid in state.positions.keys():
		if String(state.factions.get(eid, "")) == faction:
			continue
		var ech = state.combatants.get(eid, null)
		if ech == null or CharacterStats.is_dead(ech):
			continue
		if _chebyshev(wpos, state.positions[eid]) <= MELEE_RANGE_TILES:
			return true
	return false


# Guard a wounded, threatened adjacent ally (s40, free action). Picks the first living
# same-faction ally within Guard range (1 tile) at wound level HURT+ who has an adjacent
# enemy. Returns {guarded, result} or {}. Structural AI — the GDD gives no NPC policy.
static func _npc_maybe_guard(
	state: MapCombatState, npc_id: int, npc: L5RCharacterData, chars_by_id: Dictionary,
) -> Dictionary:
	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if p == null:
		return {}
	if p.stance == Enums.Stance.FULL_ATTACK:
		return {}  # cannot Guard in Full Attack Stance (GDD s40)
	var cf: String = String(state.factions.get(npc_id, ""))
	var npos: Vector2i = state.positions.get(npc_id, Vector2i(-9999, -9999))
	for aid in state.positions.keys():
		if aid == npc_id or String(state.factions.get(aid, "")) != cf:
			continue
		var ach = chars_by_id.get(aid, state.combatants.get(aid, null))
		if ach == null or CharacterStats.is_dead(ach):
			continue
		if CharacterStats.get_wound_level(ach) < Enums.WoundLevel.HURT:
			continue
		if _chebyshev(npos, state.positions[aid]) > GUARD_RANGE_TILES:
			continue
		if not _enemy_adjacent_to(state, aid, cf):
			continue
		var g: Dictionary = execute_guard(state, npc_id, aid, npc, ach)
		if g.get("success", false):
			return {"guarded": aid, "result": g}
	return {}


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
	elif (is_melee or target_in_melee) and skill_rank >= 5 \
			and _npc_should_disarm(state, target_id, target):
		# Disarm (3 Raises): a very skilled attacker strips a dangerous ARMED foe's weapon
		# (persistent — they fight unarmed until they recover it). Gated on skill 5+ so the
		# 3-Raise (+15 TN) bump is affordable. Structural AI (GDD gives no NPC policy).
		raises = 3
		maneuver = "disarm"
	elif (is_melee or target_in_melee) and skill_rank >= 4 \
			and _npc_should_knockdown(state, target_id, target):
		# Knockdown (2 Raises, biped): a capable attacker drops a standing melee threat
		# Prone (normal damage + Contested Strength). Structural AI — the GDD gives no NPC
		# maneuver policy. Gated on skill 4+ so the 2-Raise TN bump is affordable.
		raises = 2
		maneuver = "knockdown_biped"
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
	a_p.void_roll_pending_rolled = void_result.get("rolled_bonus", 1)
	a_p.void_roll_pending_kept = void_result.get("kept_bonus", 1)

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

	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts != null:
		ts.consume_free()

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
# -- Allied Companions (GDD s57.46) -------------------------------------------
# =============================================================================
# Companions are friendly participants (FACTION_PLAYER) added to the skirmish.
# On their turn, CompanionSystem.decide_action() picks the standing command and
# this layer translates it into grid movement + attacks, reusing the NPC helpers.

## Add a companion to an active skirmish as a player-faction participant.
## `character` is the companion's stat sheet (doshin use a generated sheet).
## Rolls initiative, inserts into the turn order, and registers the CompanionData.
static func add_companion(
	state: MapCombatState,
	companion: CompanionData,
	character: L5RCharacterData,
	x: int, y: int,
	dice_engine: DiceEngine,
) -> bool:
	var cid: int = character.character_id
	if state.combat.participants.has(cid):
		return false
	state.combatants[cid] = character
	state.positions[cid] = Vector2i(x, y)
	state.factions[cid] = FACTION_PLAYER
	var p := IndividualCombat.Participant.new()
	p.character_id = cid
	p.stance = Enums.Stance.ATTACK
	p.initiative_score = IndividualCombat.roll_initiative(
		character, p, dice_engine, IndividualCombat.pick_best_weapon(character))
	state.combat.participants[cid] = p
	state.combat.turn_order.append(cid)
	state.combat.turn_order.sort_custom(func(a: int, b: int) -> bool:
		var pa: IndividualCombat.Participant = state.combat.participants.get(a, null)
		var pb: IndividualCombat.Participant = state.combat.participants.get(b, null)
		var ia: int = pa.initiative_score if pa != null else 0
		var ib: int = pb.initiative_score if pb != null else 0
		return ia > ib
	)
	var ts := TurnState.new()
	ts.char_id = cid
	state.turn_states[cid] = ts
	state.companion_data[cid] = companion
	state.companion_started_count += 1
	return true


## Add an enemy combatant to a LIVE encounter (mid-combat spawn — e.g. s56.16
## spirit-threat escalation). Mirrors add_companion's participant insertion
## (initiative roll, turn-order re-sort, TurnState) but FACTION_ENEMY with no
## companion bookkeeping. Returns false if the id is already a participant.
static func add_enemy(
	state: MapCombatState,
	character: L5RCharacterData,
	x: int, y: int,
	dice_engine: DiceEngine,
) -> bool:
	var cid: int = character.character_id
	if state.combat.participants.has(cid):
		return false
	state.combatants[cid] = character
	state.positions[cid] = Vector2i(x, y)
	state.factions[cid] = FACTION_ENEMY
	var p := IndividualCombat.Participant.new()
	p.character_id = cid
	p.stance = Enums.Stance.ATTACK
	p.initiative_score = IndividualCombat.roll_initiative(
		character, p, dice_engine, IndividualCombat.pick_best_weapon(character))
	state.combat.participants[cid] = p
	state.combat.turn_order.append(cid)
	state.combat.turn_order.sort_custom(func(a: int, b: int) -> bool:
		var pa: IndividualCombat.Participant = state.combat.participants.get(a, null)
		var pb: IndividualCombat.Participant = state.combat.participants.get(b, null)
		var ia: int = pa.initiative_score if pa != null else 0
		var ib: int = pb.initiative_score if pb != null else 0
		return ia > ib
	)
	var ts := TurnState.new()
	ts.char_id = cid
	state.turn_states[cid] = ts
	return true


## Recompute morale for every companion from the allied-casualty fraction
## (companions dead or fled ÷ companions who started). Call after casualties.
static func update_companion_morale(state: MapCombatState, chars_by_id: Dictionary) -> void:
	if state.companion_started_count <= 0:
		return
	var down: int = 0
	for cid: int in state.companion_data.keys():
		var ch: L5RCharacterData = chars_by_id.get(cid, null)
		var dead: bool = ch != null and CharacterStats.is_dead(ch)
		if dead or cid in state.fled_ids:
			down += 1
	var frac: float = float(down) / float(state.companion_started_count)
	for cid: int in state.companion_data.keys():
		CompanionSystem.update_morale(state.companion_data[cid], frac)


## Resolve a companion's turn: pick the standing command via the AI priority
## stack, then translate it to grid behavior. Returns {actions, command}.
static func execute_companion_turn(
	state: MapCombatState,
	cid: int,
	character: L5RCharacterData,
	chars_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var companion: CompanionData = state.companion_data.get(cid, null)
	if companion == null:
		return {"actions": [], "reason": "not_a_companion"}
	if CharacterStats.is_dead(character) or cid in state.fled_ids:
		return {"actions": [], "reason": "out"}
	var ts: TurnState = state.turn_states.get(cid, null)
	if ts == null:
		return {"actions": [], "reason": "not_in_combat"}

	begin_turn(state, cid)
	# Held / bound / treated-as-Down (incapacitation spells): the companion takes no Actions.
	var ip: IndividualCombat.Participant = state.combat.participants.get(cid, null)
	if ip != null and IndividualCombat.CONDITION_INCAPACITATED in ip.conditions:
		return {"actions": [], "reason": "incapacitated"}
	# Fear (s22.3/s02.4): a companion near an enemy Fear source resists or fights afraid.
	apply_fear_checks(state, cid, character, dice_engine)
	var cmd: int = CompanionSystem.decide_action(companion)
	var actions: Array = []

	# -- Bleeding: a bleeding companion with Medicine bandages the wound shut (s43 Bleeding cure) —
	# self-bandage (Complex Action), before its kiho/attack. Skipped while retreating/broken.
	if cmd != CompanionData.Command.RETREAT and ts.can_use_complex() \
			and int(character.skills.get("Medicine", 0)) >= 1 and ip != null \
			and IndividualCombat.get_timed_modifier_total(ip, "bleed") > 0:
		var cbw: Dictionary = execute_stop_bleeding(state, cid, character, cid, character, dice_engine)
		actions.append({"action": "stop_bleeding", "result": cbw})
		return {"actions": actions}

	# -- Monk companion: buff up with a kiho at the start of the fight (s38/s38a).
	# Free action (Void Point), so it does not consume the move/attack budget; a
	# retreating/broken companion does not stop to buff. Same gate as NPC monks.
	if cmd != CompanionData.Command.RETREAT:
		var cp: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if cp != null and cp.active_kiho.is_empty():
			var kr: Dictionary = _npc_maybe_activate_kiho(state, cid, character, dice_engine)
			if kr.get("success", false):
				actions.append(kr)

	# -- Shugenja companion: cast a spell (offense at an enemy, heal/buff otherwise)
	# before melee. Casting is the turn's Complex action; a grappled caster is skipped.
	# A retreating/broken companion does not stop to cast.
	if cmd != CompanionData.Command.RETREAT and not character.spells_known.is_empty():
		var scp: IndividualCombat.Participant = state.combat.participants.get(cid, null)
		if ts.can_use_complex() and scp != null \
				and not IndividualCombat.has_condition(scp, IndividualCombat.CONDITION_GRAPPLED):
			var cbest: int = _npc_pick_target(
				state, cid, get_melee_targets(state, cid) + get_ranged_targets(state, cid), chars_by_id)
			var cast_r: Dictionary = _npc_maybe_cast_spell(state, cid, character, cbest, chars_by_id, dice_engine)
			if cast_r.get("cast", false):
				actions.append({"action": "cast_spell", "result": cast_r})
				return {"actions": actions, "command": cmd}

	# RETREAT / BROKEN-FLEE: move toward the nearest exit; leave if reached.
	if cmd == CompanionData.Command.RETREAT:
		var exit_tile: Vector2i = _nearest_exit_tile(state, cid)
		if exit_tile.x >= 0 and state.positions.get(cid) == exit_tile:
			state.positions.erase(cid)
			if cid not in state.fled_ids:
				state.fled_ids.append(cid)
			actions.append({"action": "fled"})
			return {"actions": actions, "command": cmd}
		var goal: Vector2i = exit_tile if exit_tile.x >= 0 else _away_from_enemies_tile(state, cid)
		var mv: Dictionary = _companion_step_toward(state, cid, goal, character, dice_engine)
		if mv.get("success", false):
			actions.append({"action": "retreat_move", "result": mv})
		return {"actions": actions, "command": cmd}

	# PROTECT (s57.46) -> Guard (s40): a yojimbo commanded to protect a charge interposes,
	# raising the charge's Armor TN (+10, -5 to its own) when adjacent and the charge is
	# threatened by an enemy. Guard is a Simple Action, so the yojimbo forgoes its attack.
	if cmd == CompanionData.Command.PROTECT and ts.can_use_simple():
		var ward_id: int = companion.command_target_id
		var ward: L5RCharacterData = chars_by_id.get(ward_id, state.combatants.get(ward_id, null))
		if ward != null and not CharacterStats.is_dead(ward) \
				and _chebyshev(state.positions.get(cid, Vector2i(-9999, -9999)),
					state.positions.get(ward_id, Vector2i(-9999, -9999))) <= GUARD_RANGE_TILES \
				and _enemy_adjacent_to(state, ward_id, String(state.factions.get(cid, ""))):
			var gw: Dictionary = execute_guard(state, cid, ward_id, character, ward)
			if gw.get("success", false):
				actions.append({"action": "guard", "result": gw})
				return {"actions": actions, "command": cmd}

	# Engage an adjacent enemy (REACT / fight-through), unless doshin samurai-avoidance.
	var melee: Array = get_melee_targets(state, cid)
	if not melee.is_empty():
		var tgt_id: int = _companion_pick_enemy(state, companion, melee, chars_by_id)
		if tgt_id >= 0:
			var tc: L5RCharacterData = chars_by_id.get(tgt_id, null)
			if tc != null and not CharacterStats.is_dead(tc):
				var atk: Dictionary = _npc_execute_attack(
					state, cid, tgt_id, character, tc,
					IndividualCombat.pick_best_weapon(character), true, dice_engine, false)
				actions.append({"action": "attack", "result": atk})
				return {"actions": actions, "command": cmd}

	# No adjacent enemy: move toward the command's goal tile.
	var goal_tile: Vector2i = _companion_goal_tile(state, companion, cmd)
	if goal_tile.x >= 0 and state.positions.get(cid) != goal_tile:
		var mv2: Dictionary = _companion_step_toward(state, cid, goal_tile, character, dice_engine)
		if mv2.get("success", false):
			actions.append({"action": "move", "result": mv2})
		elif ts.can_use_complex():
			# Blocked by a cliff or wall — scale it toward the goal (s4.4 Z-axis). Climb is the
			# turn's Complex action, so the companion commits its turn to getting over the obstacle.
			var cclimb: Dictionary = _npc_maybe_climb_toward(state, cid, goal_tile, character, dice_engine)
			if cclimb.get("success", false):
				actions.append({"action": "climb", "result": cclimb})
	return {"actions": actions, "command": cmd}


## The tile a companion should move toward for its command. (-1,-1) = stay put.
static func _companion_goal_tile(state: MapCombatState, companion: CompanionData, cmd: int) -> Vector2i:
	match cmd:
		CompanionData.Command.HOLD, CompanionData.Command.GUARD_EXIT, \
		CompanionData.Command.IDENTIFY, CompanionData.Command.SEARCH_AREA, \
		CompanionData.Command.INVESTIGATE:
			# GUARD_EXIT moves to its tile; once there it holds. The investigate/
			# identify/search resolutions are deferred (non-combat).
			if cmd == CompanionData.Command.GUARD_EXIT:
				return companion.command_target_tile
			return Vector2i(-1, -1)
		CompanionData.Command.MOVE_TO:
			return companion.command_target_tile
		CompanionData.Command.PROTECT:
			return state.positions.get(companion.command_target_id, Vector2i(-1, -1))
		_:  # FOLLOW (default): trail the player.
			return _player_tile(state)


## Pick an adjacent enemy to attack, honoring doshin samurai-avoidance.
static func _companion_pick_enemy(
	state: MapCombatState,
	companion: CompanionData,
	candidates: Array,
	chars_by_id: Dictionary,
) -> int:
	for tid: int in candidates:
		var tc: L5RCharacterData = chars_by_id.get(tid, null)
		if tc == null:
			continue
		var is_samurai: bool = tc.school_type != Enums.SchoolType.NINJA and not tc.school.is_empty()
		if not CompanionSystem.will_engage_samurai(companion, is_samurai, false, false):
			continue
		return tid
	return -1


## Step a companion toward a goal tile using free + simple move budgets.
static func _companion_step_toward(
	state: MapCombatState,
	cid: int,
	goal: Vector2i,
	character: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var path: Array = find_path(state, cid, goal)
	if path.is_empty():
		return {"success": false, "reason": "no_path"}
	var budget: int = free_move_budget(state, cid, character)
	var dest: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
	var cost: int = 0
	for step: Vector2i in path:
		# Don't step onto an occupied goal tile (e.g. trailing the player).
		if step == goal and _player_id_at(state, goal) >= 0:
			break
		var tcost: int = MovementSystem.terrain_cost(state.map.get_tile(step.x, step.y))
		if tcost == 0 or cost + tcost > budget:
			break
		dest = step
		cost += tcost
	if dest == state.positions.get(cid, Vector2i(-1, -1)):
		return {"success": false, "reason": "cannot_advance"}
	return execute_move(state, cid, dest, budget, character, dice_engine, "free")


static func _player_tile(state: MapCombatState) -> Vector2i:
	for cid: int in state.positions.keys():
		if state.factions.get(cid) == FACTION_PLAYER and not state.companion_data.has(cid):
			return state.positions[cid]
	return Vector2i(-1, -1)


static func _player_id_at(state: MapCombatState, tile: Vector2i) -> int:
	for cid: int in state.positions.keys():
		if state.positions[cid] == tile:
			return cid
	return -1


## Nearest ZONE_EXIT tile to a character, or (-1,-1) if the map has none.
static func _nearest_exit_tile(state: MapCombatState, cid: int) -> Vector2i:
	var here: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
	if here.x < 0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for y: int in range(state.map.height):
		for x: int in range(state.map.width):
			if state.map.get_tile(x, y) == Enums.TileType.ZONE_EXIT:
				var d: int = _chebyshev(here, Vector2i(x, y))
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


## Fallback retreat goal when the map has no exit: move directly away from the
## nearest enemy.
static func _away_from_enemies_tile(state: MapCombatState, cid: int) -> Vector2i:
	var here: Vector2i = state.positions.get(cid, Vector2i(-1, -1))
	var my_faction: String = state.factions.get(cid, FACTION_PLAYER)
	var nearest := Vector2i(-1, -1)
	var nd: int = 1 << 30
	for other: int in state.positions.keys():
		if _are_enemies(my_faction, state.factions.get(other, FACTION_NEUTRAL)):
			var d: int = _chebyshev(here, state.positions[other])
			if d < nd:
				nd = d
				nearest = state.positions[other]
	if nearest.x < 0:
		return here
	return here + (here - nearest).sign()


# =============================================================================
# -- Internal Helpers ---------------------------------------------------------
# =============================================================================

## s54.10 Toshigoku group auras + Ancient General Tactical Mastery. Computes the
## spirit attacker's per-attack rolled-die bonuses (attack and damage) from its
## co-located allies and rounds engaged, and stamps them on a_p. Always sets a
## fresh value (0 for non-spirits) so nothing lingers across attacks.
static func _set_spirit_attack_auras(
	state: MapCombatState,
	attacker: L5RCharacterData,
	a_p: IndividualCombat.Participant,
	target_id: int,
) -> void:
	a_p.spirit_attack_rolled_bonus = 0
	a_p.spirit_damage_rolled_bonus = 0
	a_p.spirit_attack_kept_bonus = 0
	a_p.spirit_damage_kept_bonus = 0
	var cr: SpiritCreatureData = attacker.spirit_creature
	if cr == null:
		return
	var apos: Vector2i = state.positions.get(attacker.character_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(attacker.character_id, FACTION_NEUTRAL)
	var atk_bonus: int = 0
	var dmg_bonus: int = 0

	# Count co-faction living spirit allies within the various aura radii.
	var mob_count: int = 1 if SpiritAbilitySystem.has_mob_aggression(cr) else 0
	var rally_in_range: bool = false
	var supreme_in_range: bool = false
	for cid: int in state.combat.participants:
		if cid == attacker.character_id:
			continue
		if state.factions.get(cid, FACTION_NEUTRAL) != faction:
			continue
		var ally: L5RCharacterData = _ally_lookup(state, cid)
		if ally == null or ally.spirit_creature == null or CharacterStats.is_dead(ally):
			continue
		var d: int = _chebyshev(apos, state.positions.get(cid, Vector2i(-9999, -9999)))
		if mob_count > 0 and d <= SpiritAbilitySystem.MOB_RADIUS \
				and SpiritAbilitySystem.has_mob_aggression(ally.spirit_creature):
			mob_count += 1
		if d <= SpiritAbilitySystem.RALLY_RADIUS and SpiritAbilitySystem.is_rally_source(ally.spirit_creature):
			rally_in_range = true
		if d <= SpiritAbilitySystem.SUPREME_COMMANDER_RADIUS \
				and SpiritAbilitySystem.is_supreme_commander(ally.spirit_creature):
			supreme_in_range = true

	# Mob Aggression: 3+ mob_frenzy creatures within 5 tiles → +1k0 Attack each.
	if SpiritAbilitySystem.has_mob_aggression(cr) and mob_count >= SpiritAbilitySystem.MOB_MIN_COUNT:
		atk_bonus += 1
	# Rally: a Musha Soldier within 10 tiles of a rallying Commander → +1k0 Attack.
	if rally_in_range and cr.id == "musha_soldier":
		atk_bonus += 1
	# Supreme Commander: any Musha within 20 tiles of the Ancient General → +1k0 Attack
	# AND +1k0 Damage (the General's own attacks are not self-buffed).
	if supreme_in_range and SpiritAbilitySystem.is_toshigoku_musha(cr):
		atk_bonus += 1
		dmg_bonus += 1
	# Tactical Mastery (the Ancient General itself, adapts): +1k0 after 3 rounds vs a
	# target, +2k0 after 6. Track distinct rounds engaged against this target.
	if cr.has_tag("adapts") and target_id >= 0:
		var key: String = "%d:%d" % [attacker.character_id, target_id]
		var rec: Dictionary = state.tactical_engaged.get(key, {"count": 0, "last_round": -1})
		if int(rec["last_round"]) != state.combat.round_number:
			rec["count"] = int(rec["count"]) + 1
			rec["last_round"] = state.combat.round_number
			state.tactical_engaged[key] = rec
		atk_bonus += SpiritAbilitySystem.tactical_mastery_bonus(cr, int(rec["count"]))

	a_p.spirit_attack_rolled_bonus = atk_bonus
	a_p.spirit_damage_rolled_bonus = dmg_bonus


## Look up a combatant L5RCharacterData by id from the state's combatants map
## (populated by setup_combat / add_enemy / add_companion). Used to resolve a
## spirit attacker's co-located allies at attack time.
static func _ally_lookup(state: MapCombatState, cid: int) -> L5RCharacterData:
	return state.combatants.get(cid, null)


## s54.10 invisibility/intangibility: an invisible (Mujina) or insubstantial
## (Ephemeral Form) creature cannot be targeted by attacks unless it has just acted
## (revealed itself) — "can only be wounded if it chooses to be tangible or is caught
## by surprise." Returns true for everyone else (inert for real characters).
static func _is_targetable(state: MapCombatState, cid: int) -> bool:
	var c: L5RCharacterData = state.combatants.get(cid, null)
	if c == null:
		return true
	var p: IndividualCombat.Participant = state.combat.participants.get(cid, null)
	if p == null:
		return true
	var rnd: int = state.combat.round_number
	# Character invisibility (s33 Gift of Wind / Legion of the Moon): untargetable while the
	# invisible buff holds. Attacking clears the buff (_reveal_if_hidden), so it ends on offense.
	if IndividualCombat.get_timed_modifier_total(p, "invisible") > 0 \
			and p.untargetable_revealed_until < rnd:
		return false
	# Insubstantial (s33 Essence of Air): untargetable while incorporeal (cannot attack/cast either).
	if IndividualCombat.get_timed_modifier_total(p, "insubstantial") > 0:
		return false
	if c.spirit_creature == null:
		return true
	if p.untargetable_revealed_until >= rnd:
		return true  # acted/became tangible this round — targetable until its next turn
	if SpiritAbilitySystem.is_at_will_hidden(c.spirit_creature):
		return false  # Mujina: invisible/intangible at will, persistent
	if SpiritAbilitySystem.has_ephemeral_form(c.spirit_creature) and p.ephemeral_form_expiry >= rnd:
		return false  # within the 10-round Ephemeral Form window
	if c.spirit_creature.has_tag("mimic") and p.mimic_expiry >= rnd:
		return false  # disguised (Mimic) — reads as one of the enemy's own
	if c.spirit_creature.has_tag("lure") and not p.lure_sprung:
		return false  # Konak Jiji disguised as a harmless abandoned baby
	return true


## Fear (s22.3 LOCKED / s02.4): at the start of a combatant's turn, the scariest enemy
## creature whose Fear range (Fear × 5 ft = Fear tiles) covers them forces a Willpower
## check vs TN = 5 + Fear × 5 (s22.3 character-sheet definition). On failure the
## combatant gains the AFRAID condition (-1k0 to all rolls); resisting or leaving every
## Fear source's range clears it. Public so the PC turn path may call it too.
## NOTE: s02.4 states the TN as 10 + Fear × 5; this implements the LOCKED s22.3 value
## (5 + Fear × 5) and flags the discrepancy for owner adjudication. Fear-immunity
## (s29.4 "Immune-to-Fear", s29.14 Strength of Indra) is not yet modelled (no flag).
static func apply_fear_checks(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	dice: DiceEngine,
) -> void:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null or character == null or CharacterStats.is_dead(character):
		return
	var cpos: Vector2i = state.positions.get(char_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	# Trembling Earth (s54.12 Jimen no Oni): a trembling_earth enemy within 50' (10 tiles)
	# imposes -1k0 to all rolls (no save). NOT a Fear effect — physical, so it bypasses
	# Immune-to-Fear. Modelled with the same AFRAID -1k0 condition as Fear.
	var tremor: bool = false
	for oid: int in state.combat.participants:
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		var ts: L5RCharacterData = state.combatants.get(oid, null)
		if ts == null or CharacterStats.is_dead(ts) or ts.spirit_creature == null:
			continue
		if ts.spirit_creature.has_tag("trembling_earth") \
				and _chebyshev(cpos, state.positions.get(oid, Vector2i(-9999, -9999))) <= TREMBLING_EARTH_TILES:
			tremor = true
			break
	# Aura of Heat (s54.12 Taki-bi): a non-Fatigued character within 10' (2 tiles) of an
	# aura_of_heat creature becomes Fatigued by heatstroke (persists — not cleared by leaving).
	if IndividualCombat.CONDITION_FATIGUED not in p.conditions:
		for oid: int in state.combat.participants:
			if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
				continue
			var hs: L5RCharacterData = state.combatants.get(oid, null)
			if hs == null or CharacterStats.is_dead(hs) or hs.spirit_creature == null:
				continue
			if hs.spirit_creature.has_tag("aura_of_heat") \
					and _chebyshev(cpos, state.positions.get(oid, Vector2i(-9999, -9999))) <= 2:
				IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_FATIGUED)
				break

	# Fear: highest Fear among enemy combatants whose range covers this character. A Fear
	# source is a creature's stat-block Fear OR a character's own fear_rating (s22.3 Terrible
	# Appearance etc.). Range = Fear × 5 ft = Fear tiles. Immune-to-Fear (s29.4) skips this.
	var afraid: bool = false
	if not character.immune_to_fear:
		var max_fear: int = 0
		for oid: int in state.combat.participants:
			if oid == char_id:
				continue
			if not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
				continue
			var src: L5RCharacterData = state.combatants.get(oid, null)
			if src == null or CharacterStats.is_dead(src):
				continue
			var f: int = maxi(src.fear_rating, src.spirit_creature.fear if src.spirit_creature != null else 0)
			if f <= 0:
				continue
			if _chebyshev(cpos, state.positions.get(oid, Vector2i(-9999, -9999))) <= f:
				max_fear = maxi(max_fear, f)
		if max_fear > 0:
			# Resist: Willpower (+ Kshatriya Strength of Indra rank bonus) keep Willpower,
			# plus Courage of Shiva's +1k1, vs TN 5 + Fear × 5 (s22.3 LOCKED).
			var wp: int = maxi(1, character.willpower + character.fear_resist_willpower_bonus)
			# s34 Courage of the Seven Thunders: a fear_resist buff adds +Nk0 (rolled/kept) to the roll.
			var fr_roll: int = IndividualCombat.get_timed_modifier_total(p, "fear_resist_rolled")
			var fr_kept: int = IndividualCombat.get_timed_modifier_total(p, "fear_resist_kept")
			var resist: int = dice.roll_and_keep(
				wp + character.fear_resist_rolled_bonus + fr_roll,
				wp + character.fear_resist_kept_bonus + fr_kept, true).total
			if resist < 5 + max_fear * 5:
				afraid = true
	# s43 Inspire Fear / Mists of Fear: a maho-induced fear persists independently of proximity for its
	# duration via the `spell_afraid` timed modifier — keep AFRAID while it is active.
	var spell_afraid: bool = IndividualCombat.get_timed_modifier_total(p, "spell_afraid") > 0
	# Single set/clear: AFRAID if the Fear roll failed this turn OR a tremor source is near OR a maho fear
	# spell is active.
	if afraid or tremor or spell_afraid:
		if IndividualCombat.CONDITION_AFRAID not in p.conditions:
			p.conditions.append(IndividualCombat.CONDITION_AFRAID)
	else:
		p.conditions.erase(IndividualCombat.CONDITION_AFRAID)


## s54.10/s54.2 Possession: a possessing spirit (Shozai-gaki / Buruburu / Kitsune-tsuki)
## adjacent to a valid victim spends a Complex action to attempt possession. Kitsune-tsuki
## requires the victim sleeping or Down/Out (TN-25 Willpower or possessed); Shozai/Buruburu
## Charge (s54.5/s54.12): a charge-capable creature in Full Attack stance closes up to
## Water Ring × charge_move_mult feet (÷5 = tiles) toward a target and attacks in one turn.
## Enters Full Attack only if able (action economy); a charge_simple attack costs a Simple,
## else a Complex; charge_atk/dmg_bonus add +NkN; a diving charger ends Prone. Returns {} if
## it cannot/should not charge (caller falls back to a normal approach). Charge fires only
## when the target is beyond melee reach but within charge range (closing the gap is the point).
static func execute_charge(
	state: MapCombatState,
	npc_id: int,
	target_id: int,
	npc: L5RCharacterData,
	target: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var cr: SpiritCreatureData = npc.spirit_creature
	if cr == null or cr.charge_move_mult <= 0:
		return {}
	var ts: TurnState = state.turn_states.get(npc_id, null)
	var p: IndividualCombat.Participant = state.combat.participants.get(npc_id, null)
	if ts == null or p == null:
		return {}
	var ap: Vector2i = state.positions.get(npc_id, Vector2i(-1, -1))
	var tp: Vector2i = state.positions.get(target_id, Vector2i(-1, -1))
	if ap.x < 0 or tp.x < 0:
		return {}
	var charge_tiles: int = int(CharacterStats.get_ring_value(npc, Enums.Ring.WATER) * cr.charge_move_mult / 5.0)
	if charge_tiles < 1:
		return {}
	var dist: int = _chebyshev(ap, tp)
	# already adjacent (use normal attack) or too far to reach even with the charge → no charge.
	if dist <= MELEE_RANGE_TILES or dist > charge_tiles + MELEE_RANGE_TILES:
		return {}
	# Enter Full Attack stance — only if able this turn (the GDD gate); a Fatigued creature
	# may not take Full Attack, so it cannot charge.
	if p.stance != Enums.Stance.FULL_ATTACK:
		if not ts.can_use_simple() or IndividualCombat.CONDITION_FATIGUED in p.conditions:
			return {}
		p.stance = Enums.Stance.FULL_ATTACK
		ts.consume_simple()
	# The charge attack must be affordable after the (possible) stance change.
	if cr.charge_simple:
		if not ts.can_use_simple():
			return {}
	elif not ts.can_use_complex():
		return {}
	# Charge move toward the target (free move, up to the charge distance).
	_npc_move_toward(state, npc_id, target_id, npc, charge_tiles, "free", dice)
	if not (target_id in get_melee_targets(state, npc_id)):
		return {"ok": true, "charged": true, "reached": false}
	var res: Dictionary = execute_melee_attack(
		state, npc_id, target_id, npc, target, IndividualCombat.pick_best_weapon(npc), 0, dice,
		"", false, false, cr.charge_atk_bonus, cr.charge_dmg_bonus, cr.charge_simple)
	# Diving Attack (s54.5 Nairu): after the dive the creature is no longer flying → Prone.
	if cr.charge_diving:
		IndividualCombat.apply_condition(p, IndividualCombat.CONDITION_PRONE)
	return {"ok": true, "charged": true, "reached": true, "attack": res, "diving": cr.charge_diving}


## Strength of the Dead (s54.12 Wanyudo): a Complex-action scream — every mortal enemy within
## 50' (10 tiles) rolls Contested Willpower vs the creature or is Stunned. Once per skirmish.
static func _npc_maybe_scream(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null or p.scream_used:
		return {}
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null or not ts.can_use_complex():
		return {}
	var cpos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	# Need at least one mortal enemy in range to be worth screaming.
	var in_range: Array = []
	for oid: int in state.positions.keys():
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		var v: L5RCharacterData = state.combatants.get(oid, null)
		if v == null or CharacterStats.is_dead(v) or v.spirit_creature != null:
			continue
		if _chebyshev(cpos, state.positions[oid]) <= 10:
			in_range.append(oid)
	if in_range.is_empty():
		return {}
	ts.consume_complex()
	p.scream_used = true
	var cw: int = maxi(1, character.willpower)
	var stunned: int = 0
	for oid: int in in_range:
		var v: L5RCharacterData = state.combatants.get(oid, null)
		var vw: int = maxi(1, v.willpower)
		if dice.roll_and_keep(cw, cw, true).total > dice.roll_and_keep(vw, vw, true).total:
			var vp: IndividualCombat.Participant = state.combat.participants.get(oid, null)
			if vp != null:
				IndividualCombat.apply_condition(vp, IndividualCombat.CONDITION_STUNNED)
				stunned += 1
	return {"success": true, "stunned": stunned}


## Spirit Leeching (s54.5 Kommei): a Simple-action soul-fog. Marks each mortal enemy within
## 5 ft (1 tile) with a spirit_leech affliction lasting the oni's Air Ring in Rounds. Each
## Round (advance_round) the victim rolls Stamina TN 25 to hold their breath; on a failure
## (inhale) a Willpower TN 25 roll, and two total Willpower failures devour the soul -> death.
## (The shapeshift-into-victim and Spirit Trading body-swap are blocked on the disguise layer.)
static func _npc_maybe_spirit_leech(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	_dice: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null or not ts.can_use_simple():
		return {}
	var cpos: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	var air: int = CharacterStats.get_ring_value(character, Enums.Ring.AIR)
	var expiry: int = state.combat.round_number + maxi(1, air)
	var caught: int = 0
	for oid: int in state.positions.keys():
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		var v: L5RCharacterData = state.combatants.get(oid, null)
		if v == null or CharacterStats.is_dead(v) or v.spirit_creature != null:
			continue
		if _chebyshev(cpos, state.positions[oid]) > 1:
			continue
		var vp: IndividualCombat.Participant = state.combat.participants.get(oid, null)
		if vp == null or not vp.spirit_leech.is_empty():
			continue
		vp.spirit_leech = {"failures": 0, "expiry": expiry}
		caught += 1
	if caught == 0:
		return {}
	ts.consume_simple()
	return {"success": true, "caught": caught}


## Dark Mirror (s54.5 Manesuru). Two-stage: Uncanny Insight (study a target across two
## consecutive Complex Actions) then Spawn Dark Mirror (a Complex Action that creates a
## duplicate of a fully-studied target). The duplicate is a deep copy of the target with no
## Void (cannot use Void techniques/spells) and the Manesuru's Taint Rank; it joins the enemy
## faction and attacks its original first. Capped at the Manesuru's Taint Rank, once per
## target. Returns {success, kind} ("uncanny_insight" while studying, "spawn_dark_mirror" on
## a spawn) or {} if neither could act.
static func _npc_maybe_dark_mirror(
	state: MapCombatState,
	char_id: int,
	best_target: int,
	character: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts == null or not ts.can_use_complex():
		return {}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null:
		return {}
	var cap: int = maxi(1, character.spirit_creature.taint_rank)
	# 1) Spawn from any fully-studied, not-yet-mirrored target while under the Taint-Rank cap.
	if state.mirrors_count < cap:
		for sid_key in state.mirror_studied.keys():
			var sid: int = int(sid_key)
			if state.mirror_spawned.has(sid):
				continue
			var orig: L5RCharacterData = state.combatants.get(sid, null)
			if orig == null or CharacterStats.is_dead(orig):
				continue
			var center: Vector2i = state.positions.get(char_id, Vector2i(-1, -1))
			var tile: Vector2i = _free_tile_near(state, center)
			if tile.x < 0:
				continue
			var dup: L5RCharacterData = orig.duplicate(true)
			state.spawn_counter += 1
			dup.character_id = -900000 - state.spawn_counter
			dup.is_pc = false
			# duplicate(true) deep-copies Traits, Skills, techniques/katas/kiho and Wounds
			# (GDD: "all the target's ... Skills ... and School/Path Techniques"). The mirror
			# has no Void (so it cannot cast spells / use Void techniques) and the Manesuru's
			# Taint; spells_known is cleared explicitly (GDD: "cannot cast spells").
			dup.void_ring = 0
			dup.current_void_points = 0
			dup.spells_known = []
			dup.taint = float(cap)
			if not add_enemy(state, dup, tile.x, tile.y, dice):
				continue
			var dp: IndividualCombat.Participant = state.combat.participants.get(dup.character_id, null)
			if dp != null:
				dp.mirror_origin_id = sid
			state.mirror_spawned[sid] = true
			state.mirrors_count += 1
			ts.consume_complex()
			return {"success": true, "kind": "spawn_dark_mirror", "mirror_id": dup.character_id, "origin_id": sid}
	# 2) Otherwise study the current target (Complex). Two consecutive rounds completes it.
	if best_target < 0 or state.mirror_studied.has(best_target):
		return {}
	if p.insight_study_target == best_target:
		p.insight_study_rounds += 1
	else:
		p.insight_study_target = best_target
		p.insight_study_rounds = 1
	ts.consume_complex()
	var done: bool = p.insight_study_rounds >= 2
	if done:
		state.mirror_studied[best_target] = true
	return {"success": true, "kind": "uncanny_insight", "studied": done, "target": best_target}


## Taint Affliction (s54.5 Gagoze): a Complex-action burning gaze. Picks the nearest mortal
## enemy not yet gazed; Contested Willpower (oni vs victim). Oni wins → victim gains 1 full
## Rank of Taint (feeds the MutationSystem periodic-taint + Channel-3 detection pipelines).
## Victim wins → Taint averted (the GDD 24h Fire/Earth Ring penalty is not modelled — no
## cross-encounter Ring-debuff layer). Once per individual ever. Returns {} if not attempted.
static func _npc_maybe_taint_gaze(
	state: MapCombatState,
	gazer_id: int,
	gazer: L5RCharacterData,
	chars_by_id: Dictionary,
	dice: DiceEngine,
) -> Dictionary:
	var ts: TurnState = state.turn_states.get(gazer_id, null)
	if ts == null or not ts.can_use_complex():
		return {}
	var used: Dictionary = state.taint_gaze_used.get(gazer_id, {})
	var faction: String = state.factions.get(gazer_id, FACTION_NEUTRAL)
	var pos: Vector2i = state.positions.get(gazer_id, Vector2i(-1, -1))
	if pos.x < 0:
		return {}
	# nearest mortal (non-spirit) living enemy not yet gazed
	var victim_id: int = -1
	var best_d: int = 1 << 30
	for cid: int in state.positions.keys():
		if cid == gazer_id or used.has(cid):
			continue
		if not _are_enemies(faction, state.factions.get(cid, FACTION_NEUTRAL)):
			continue
		var vc: L5RCharacterData = state.combatants.get(cid, chars_by_id.get(cid, null))
		if vc == null or CharacterStats.is_dead(vc) or vc.spirit_creature != null:
			continue
		var d: int = _chebyshev(pos, state.positions[cid])
		if d < best_d:
			best_d = d
			victim_id = cid
	if victim_id < 0:
		return {}
	var victim: L5RCharacterData = state.combatants.get(victim_id, chars_by_id.get(victim_id, null))
	ts.consume_complex()
	used[victim_id] = true
	state.taint_gaze_used[gazer_id] = used
	var ow: int = dice.roll_and_keep(maxi(1, gazer.willpower), maxi(1, gazer.willpower), true).total
	# s37 Strength of the Crow: +taint_resist k taint_resist to the victim's roll to resist new Taint.
	var v_gp = state.combat.participants.get(victim_id, null)
	var v_tr: int = IndividualCombat.get_timed_modifier_total(v_gp, "taint_resist") if v_gp != null else 0
	var vw: int = dice.roll_and_keep(maxi(1, victim.willpower + v_tr), maxi(1, victim.willpower + v_tr), true).total
	if ow > vw:
		victim.taint = minf(100.0, victim.taint + 1.0)
		return {"success": true, "victim": victim_id, "tainted": true}
	return {"success": true, "victim": victim_id, "tainted": false}


## roll Contested Willpower. On success a cross-encounter possession_affliction is seeded on
## the victim (resolved in the world-sim by DayOrchestrator). Returns {} if not attempted.
static func _npc_maybe_possess(
	state: MapCombatState,
	attacker_id: int,
	target_id: int,
	attacker: L5RCharacterData,
	chars_by_id: Dictionary,
	dice: DiceEngine,
) -> Dictionary:
	var cr: SpiritCreatureData = attacker.spirit_creature
	if cr == null:
		return {}
	var kind: String = SpiritAbilitySystem.possession_kind(cr)
	if kind == "":
		return {}
	var ts: TurnState = state.turn_states.get(attacker_id, null)
	if ts == null or not ts.can_use_complex():
		return {}
	var victim: L5RCharacterData = chars_by_id.get(target_id, null)
	if victim == null or CharacterStats.is_dead(victim):
		return {}
	if victim.spirit_creature != null:
		return {}  # spirits are not possessed
	if not victim.possession_affliction.is_empty():
		return {}  # already possessed
	if SpiritAbilitySystem.possession_requires_incapacitated(cr) \
			and CharacterStats.get_wound_level(victim) < Enums.WoundLevel.DOWN:
		return {}
	ts.consume_complex()
	var possessed: bool = false
	if kind == "kitsune_tsuki":
		# Victim resists with Willpower vs TN 25; possessed if they fail (s54.10).
		var vw: int = maxi(1, victim.willpower)
		possessed = dice.roll_and_keep(vw, vw, true).total < SpiritAbilitySystem.KITSUNE_TSUKI_POSSESS_TN
	else:
		# Contested Willpower: possessor vs victim.
		var aw: int = maxi(1, attacker.willpower)
		var vw2: int = maxi(1, victim.willpower)
		possessed = dice.roll_and_keep(aw, aw, true).total > dice.roll_and_keep(vw2, vw2, true).total
	if not possessed:
		return {"success": true, "possessed": false, "target_id": target_id, "kind": kind}
	victim.possession_affliction = {
		"kind": kind,
		"possessor_id": attacker_id,
		"possessor_willpower": maxi(1, attacker.willpower),
	}
	return {"success": true, "possessed": true, "target_id": target_id, "kind": kind}


## s54.10: a hidden creature that takes an offensive action becomes targetable until
## its next turn (revealed_until = current round + 1). No-op for non-hidden creatures.
static func _reveal_if_hidden(state: MapCombatState, cid: int, p: IndividualCombat.Participant) -> void:
	if p == null:
		return
	# Character invisibility (s33 Gift of Wind): attacking another person ends the spell entirely.
	if IndividualCombat.get_timed_modifier_total(p, "invisible") > 0:
		IndividualCombat.clear_timed_modifiers_by_source(p, "spell_invisible")
	var c: L5RCharacterData = state.combatants.get(cid, null)
	if c == null or c.spirit_creature == null:
		return
	var rnd: int = state.combat.round_number
	# Mimic: attacking blows the disguise permanently (until recast).
	if c.spirit_creature.has_tag("mimic") and p.mimic_expiry >= rnd:
		p.mimic_expiry = -1
	var hidden: bool = SpiritAbilitySystem.is_at_will_hidden(c.spirit_creature) \
		or (SpiritAbilitySystem.has_ephemeral_form(c.spirit_creature) and p.ephemeral_form_expiry >= rnd)
	if hidden:
		p.untargetable_revealed_until = rnd + 1


## s54.10 Mimic (Kitsune / Bakeneko): a wounded shapeshifter assumes another form
## (Complex Action) and reads as one of the enemy's own — untargetable for 5 Rounds or
## until it attacks. NPC auto-activation when threatened, hurt, and not already disguised.
## No-op for creatures without the ability. Returns {} if not attempted.
static func _npc_maybe_mimic(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
) -> Dictionary:
	if character.spirit_creature == null or not character.spirit_creature.has_tag("mimic"):
		return {}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	var ts: TurnState = state.turn_states.get(char_id, null)
	if p == null or ts == null or not ts.can_use_complex():
		return {}
	if p.mimic_expiry >= state.combat.round_number:
		return {}  # already disguised
	if CharacterStats.get_wound_level(character) < Enums.WoundLevel.HURT:
		return {}  # only disguises to escape once hurt
	var apos: Vector2i = state.positions.get(char_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	var threatened: bool = false
	for oid: int in state.positions.keys():
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		if _chebyshev(apos, state.positions[oid]) <= MELEE_RANGE_TILES:
			threatened = true
			break
	if not threatened:
		return {}
	ts.consume_complex()
	p.mimic_expiry = state.combat.round_number + MIMIC_DISGUISE_ROUNDS
	return {"success": true, "action": "mimic", "char_id": char_id, "expiry": p.mimic_expiry}


## s54.10 Ancient General Duelist's Challenge (duel_offer): once per encounter the
## General challenges one enemy to formal combat; while the duel stands, all OTHER
## Toshigoku Musha (the General's faction allies) cease attacking. A free declaration at
## the start of its turn. Returns the challenge info, or {} if not offered.
static func _npc_maybe_offer_duel(state: MapCombatState, char_id: int, character: L5RCharacterData) -> Dictionary:
	var cr: SpiritCreatureData = character.spirit_creature
	if cr == null or not cr.has_tag("duel_offer") or state.duel_offered:
		return {}
	if state.duel_challenger_id >= 0:
		return {}  # a duel is already running
	var apos: Vector2i = state.positions.get(char_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	# Challenge the nearest living enemy in line of sight.
	var best: int = -1
	var best_d: int = 1 << 30
	for oid: int in state.combat.participants:
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		var v: L5RCharacterData = state.combatants.get(oid, null)
		if v == null or CharacterStats.is_dead(v):
			continue
		var d: int = _chebyshev(apos, state.positions.get(oid, Vector2i(9999, 9999)))
		if d < best_d:
			best_d = d
			best = oid
	if best < 0:
		return {}
	state.duel_challenger_id = char_id
	state.duel_target_id = best
	state.duel_offered = true
	return {"challenger_id": char_id, "target_id": best}


## True if an active duel forbids `char_id` from attacking: a Toshigoku Musha on the
## challenger's faction that is neither the challenger nor the challenged target ceases
## attacking while the duel stands (s54.10).
static func _duel_ceasefire_blocks(state: MapCombatState, char_id: int, character: L5RCharacterData) -> bool:
	if state.duel_challenger_id < 0:
		return false
	if char_id == state.duel_challenger_id or char_id == state.duel_target_id:
		return false
	if character.spirit_creature == null or not SpiritAbilitySystem.is_toshigoku_musha(character.spirit_creature):
		return false
	# Only the challenger's own faction holds (the challenged side fights freely).
	return state.factions.get(char_id, FACTION_NEUTRAL) == state.factions.get(state.duel_challenger_id, FACTION_NEUTRAL)


## Clears the active duel when either duelist is dead/out or has fled (ceasefire lifts).
static func _clear_duel_if_over(state: MapCombatState, chars_by_id: Dictionary) -> void:
	if state.duel_challenger_id < 0:
		return
	var a: L5RCharacterData = chars_by_id.get(state.duel_challenger_id, state.combatants.get(state.duel_challenger_id, null))
	var b: L5RCharacterData = chars_by_id.get(state.duel_target_id, state.combatants.get(state.duel_target_id, null))
	var a_done: bool = a == null or CharacterStats.is_dead(a) or state.duel_challenger_id in state.fled_ids
	var b_done: bool = b == null or CharacterStats.is_dead(b) or state.duel_target_id in state.fled_ids
	if a_done or b_done:
		state.duel_challenger_id = -1
		state.duel_target_id = -1


## s54.10 Konak Jiji Lure + Deceptive Weight. While disguised (lure_sprung == false) the
## creature is an untargetable "abandoned baby" and does nothing on its turn UNLESS a
## living non-spirit enemy is adjacent (has approached/reached for it). Then the victim
## rolls Willpower vs the creature's Awareness (Contested — no invented TN): success sees
## through it (creature revealed, targetable, fights normally); failure springs the trap —
## an automatic claw hit (no attack roll), a 400 lb pin (grapple, escape Athletics/Strength
## TN 40), and the paralysis venom (Stunned for Water minutes). Returns {} if not a lure.
static func _npc_maybe_spring_lure(
	state: MapCombatState,
	char_id: int,
	character: L5RCharacterData,
	chars_by_id: Dictionary,
	dice: DiceEngine,
) -> Dictionary:
	var cr: SpiritCreatureData = character.spirit_creature
	if cr == null or not cr.has_tag("lure"):
		return {}
	var p: IndividualCombat.Participant = state.combat.participants.get(char_id, null)
	if p == null or p.lure_sprung:
		return {}  # already sprung/revealed — behaves as a normal combatant
	# Find an adjacent living non-spirit enemy (someone who reached for the babe).
	var apos: Vector2i = state.positions.get(char_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(char_id, FACTION_NEUTRAL)
	var victim_id: int = -1
	for oid: int in state.positions.keys():
		if oid == char_id or not _are_enemies(faction, state.factions.get(oid, FACTION_NEUTRAL)):
			continue
		var v: L5RCharacterData = state.combatants.get(oid, null)
		if v == null or v.spirit_creature != null or CharacterStats.is_dead(v):
			continue
		if _chebyshev(apos, state.positions[oid]) <= MELEE_RANGE_TILES:
			victim_id = oid
			break
	if victim_id < 0:
		return {"waited": true}  # stays disguised; the passive baby does nothing this turn
	var victim: L5RCharacterData = chars_by_id.get(victim_id, state.combatants.get(victim_id, null))
	if victim == null:
		return {"waited": true}
	# Contested: victim Willpower vs creature Awareness (stat-block values; no invented TN).
	var vw: int = maxi(1, victim.willpower)
	var caw: int = maxi(1, int(cr.traits.get("awareness", cr.air)))
	if dice.roll_and_keep(vw, vw, true).total >= dice.roll_and_keep(caw, caw, true).total:
		p.lure_sprung = true  # saw through it — now a revealed, targetable combatant
		return {"sprung": false, "resisted": true, "victim_id": victim_id}
	# Trap springs: auto-hit (no roll) + pin + venom.
	p.lure_sprung = true
	var dmg: int = dice.roll_and_keep(cr.damage_rolled, cr.damage_kept, true).total
	WoundSystem.apply_damage(victim, dmg, victim.armor_reduction)
	var vp: IndividualCombat.Participant = state.combat.participants.get(victim_id, null)
	if vp != null:
		IndividualCombat.apply_condition(vp, IndividualCombat.CONDITION_GRAPPLED)
		vp.grapple_partner_id = char_id
		vp.deceptive_weight_pinned = true
		p.grapple_partner_id = victim_id
		p.grapple_in_control = true
		var venom_min: int = SpiritAbilitySystem.paralysis_venom_minutes(cr)
		if venom_min > 0:
			IndividualCombat.apply_timed_condition(
				vp, IndividualCombat.CONDITION_STUNNED,
				state.combat.round_number + venom_min * IndividualCombat.ROUNDS_PER_MINUTE)
	var ts: TurnState = state.turn_states.get(char_id, null)
	if ts != null:
		ts.consume_complex()
	return {"sprung": true, "victim_id": victim_id, "damage": dmg}


## s54.10 Deceptive Weight escape: a pinned victim breaks free with an Athletics/Strength
## roll vs TN 40 (Strength trait + Athletics skill; cooperative allowed — single-character
## here). On success the grapple/pin clears for both sides. Public for the PC turn path.
static func attempt_deceptive_weight_escape(
	state: MapCombatState,
	victim_id: int,
	victim: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var vp: IndividualCombat.Participant = state.combat.participants.get(victim_id, null)
	if vp == null or not vp.deceptive_weight_pinned:
		return {"success": false, "reason": "not_pinned"}
	var roll: int = dice.roll_and_keep(
		victim.strength + victim.skills.get("Athletics", 0), victim.strength, true).total
	if roll < DECEPTIVE_WEIGHT_ESCAPE_TN:
		return {"success": false, "reason": "still_pinned", "roll": roll}
	var captor_id: int = vp.grapple_partner_id
	vp.deceptive_weight_pinned = false
	vp.grapple_partner_id = -1
	vp.conditions.erase(IndividualCombat.CONDITION_GRAPPLED)
	var cp: IndividualCombat.Participant = state.combat.participants.get(captor_id, null)
	if cp != null:
		cp.grapple_partner_id = -1
		cp.grapple_in_control = false
	return {"success": true, "roll": roll}


## s54.10 Ephemeral Form (Kitsune etc.): a threatened shapeshifter turns insubstantial
## for 10 Rounds, once per encounter. NPC auto-activation (Free Action) at the start of
## its turn when an enemy is adjacent. No-op for creatures without the ability.
static func _npc_maybe_activate_ephemeral_form(state: MapCombatState, character: L5RCharacterData, p: IndividualCombat.Participant) -> void:
	if character.spirit_creature == null or p == null:
		return
	if not SpiritAbilitySystem.has_ephemeral_form(character.spirit_creature) or p.ephemeral_form_used:
		return
	# Threatened: any living enemy adjacent.
	var apos: Vector2i = state.positions.get(character.character_id, Vector2i(-9999, -9999))
	var faction: String = state.factions.get(character.character_id, FACTION_NEUTRAL)
	var threatened: bool = false
	for cid: int in state.positions.keys():
		if cid == character.character_id:
			continue
		if not _are_enemies(faction, state.factions.get(cid, FACTION_NEUTRAL)):
			continue
		if _chebyshev(apos, state.positions[cid]) <= MELEE_RANGE_TILES:
			threatened = true
			break
	if threatened:
		p.ephemeral_form_expiry = state.combat.round_number + SpiritAbilitySystem.EPHEMERAL_FORM_ROUNDS
		p.ephemeral_form_used = true


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

	# Striking Through the Void (s38 Void): the caster may spend a Void Point on an
	# unarmed damage roll for +1k1 (one Void Point per attack). NPC auto-spends if able.
	var stv_rolled: int = 0
	var stv_kept: int = 0
	if (weapon_name == "" or weapon_name == "unarmed") and "Striking Through the Void" in a_p.active_kiho \
			and attacker.current_void_points >= 1:
		attacker.current_void_points -= 1
		stv_rolled = 1
		stv_kept = 1

	var dmg: Dictionary = IndividualCombat.resolve_damage(
		attacker, weapon_name, raises_for_damage + stv_rolled, feint_bonus, dice_engine, a_p, maneuver == "feint", stv_kept
	)
	var raw: int = dmg["raw_damage"]

	# Reduction: base armor + kata/active-kiho Reduction − attacker piercing (s30a/s38).
	var t_p: IndividualCombat.Participant = state.combat.participants.get(target.character_id, null)
	var reduction: int = target.armor_reduction
	if t_p != null:
		reduction = IndividualCombat.total_defender_reduction(target, t_p, attacker, a_p, weapon_name)
		# Rising Mountain (s38 Earth): the defender gains Reduction = 2× the attacker's
		# Raises on this offensive action (spells excluded — this is a weapon strike).
		if "Rising Mountain" in t_p.active_kiho and raises > 0:
			reduction += 2 * raises

	# s56.16 spirit-encounter hooks (inert for real characters):
	#  - A spirit attacker whose attack bypasses armor (Shozai Claw / spirit_strike /
	#    gaze) ignores the target's Reduction.
	#  - A spirit TARGET filters incoming damage by weapon kind (incorporeal /
	#    partial-invuln / Pekkle-half / Kagaki fire-immune) AND uses its kind-gated
	#    Reduction (Usai-gaki Swarm: Reduction 10 vs normal weapons only — magic/
	#    jade/crystal bypass it). Weapon kind is read from the attacker's WeaponData
	#    .material via _weapon_kind() (steel/"" = mundane, the common case); only
	#    jade/crystal/magic weapons pierce invulnerability, so an ordinary blade
	#    still cannot permanently destroy a spirit (the ritual is the win condition).
	if attacker.spirit_creature != null and SpiritAbilitySystem.attack_bypasses_armor(attacker.spirit_creature):
		reduction = 0
	if target.spirit_creature != null:
		var w_kind: String = _weapon_kind(attacker, weapon_name)
		# The Soul's Blade (s35 Fire 6): the enchanted weapon overcomes Invulnerability —
		# read it as magic so the invuln tags let the damage through.
		if IndividualCombat.get_timed_modifier_total(a_p, "weapon_stun") > 0:
			w_kind = SpiritAbilitySystem.W_MAGIC
		# A spirit's Reduction is its creature stat, kind-gated — not armor mechanics.
		# reduction_for_kind() == armor_reduction for mundane (matches the puppet's
		# value) and 0 for a swarm struck by a non-mundane weapon. Skip when the
		# attack already bypasses Reduction (reduction zeroed above).
		if reduction > 0:
			reduction = SpiritAbilitySystem.reduction_for_kind(target.spirit_creature, w_kind)
		# Protection of Yomi (Major Shapeshifter, s54.10): Reduction 5, stacks with natural.
		reduction += SpiritAbilitySystem.protection_of_yomi_reduction(target.spirit_creature)
		var filt: Dictionary = SpiritAbilitySystem.incoming_damage(target.spirit_creature, w_kind)
		raw = 0 if filt["heals"] else int(round(float(raw) * float(filt["multiplier"])))
	# Armor of the Emperor (s34 Earth 4): each individual kept damage die against the warded
	# target has its total reduced by the caster's School Rank, floored at 0 — so the amount
	# removed is Σ min(die, N) over the kept damage dice. Stacks with armor Reduction. Covers
	# the central melee+ranged path (atemi/charge/spirit-filtered damage not threaded).
	if t_p != null and raw > 0:
		var pdr: int = IndividualCombat.get_timed_modifier_total(t_p, "per_die_reduction")
		if pdr > 0:
			var dres = dmg.get("dice_result", {})
			var dice_obj = dres.get("dice", null) if dres is Dictionary else null
			if dice_obj != null:
				var removed: int = 0
				for die_v in dice_obj.kept_dice:
					removed += mini(int(die_v), pdr)
				raw = maxi(0, raw - removed)
	# Power of the Earth Dragon (s34): an absorption ward soaks incoming Wounds (post-Reduction)
	# until its pool (100 base) is exhausted, then ends.
	if t_p != null and t_p.absorb_pool > 0 and raw > 0:
		var net: int = maxi(0, raw - reduction)
		var soaked: int = mini(net, t_p.absorb_pool)
		t_p.absorb_pool -= soaked
		raw = maxi(0, raw - soaked)
	# s43 Blood Armor (Earth 5): a blood-armored wearer channels 75% of incoming damage into its bonded
	# victim (direct, bypassing the victim's armor — it is blood magic), keeping only 25% for itself
	# (which its own Reduction still mitigates). The bond breaks if the victim is gone.
	if raw > 0 and state.blood_armor_links.has(target.character_id):
		var _ba_vid: int = int(state.blood_armor_links[target.character_id])
		var _ba_victim: L5RCharacterData = state.combatants.get(_ba_vid, null)
		if _ba_victim != null and not CharacterStats.is_dead(_ba_victim) and _ba_vid != target.character_id:
			var _ba_redirect: int = int(raw * 0.75)
			if _ba_redirect > 0:
				WoundSystem.apply_damage(_ba_victim, _ba_redirect, 0)
				raw = raw - _ba_redirect
		else:
			state.blood_armor_links.erase(target.character_id)
	var wd_result: Dictionary = WoundSystem.apply_damage(target, raw, reduction)

	# The Soul's Blade (s35 Fire 6): every target hit by the enchanted weapon is Stunned.
	if t_p != null and IndividualCombat.get_timed_modifier_total(a_p, "weapon_stun") > 0 \
			and not CharacterStats.is_dead(target):
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_STUNNED)

	# Heart of the Water Dragon (s36): a buffed target instantly regains 1k1 Wounds whenever it
	# suffers damage during the duration. Fires only when actual Wounds landed and it survived.
	if t_p != null and not CharacterStats.is_dead(target) \
			and IndividualCombat.get_timed_modifier_total(t_p, "heal_on_damage") > 0 \
			and IndividualCombat.get_timed_modifier_total(t_p, "no_magic_heal") <= 0 \
			and int(wd_result.get("final_damage", 0)) > 0:
		WoundSystem.heal_wounds(target, dice_engine.roll_and_keep(1, 1, true).total)

	# Arugai "Nearly Immortal" / heart_kill (s54.5): the oni's wounds heal almost instantly,
	# so body damage can never slay it — only destroying its heart can. While the heart is
	# hidden, body Wounds are clamped just below Dead (regen heals them). Once a character has
	# torn the chest open (execute_locate_heart, Investigation/Perception TN 30), strikes hit
	# the exposed heart instead; after it sustains 10 Wounds the oni dies for good.
	if t_p != null and target.spirit_creature != null \
			and target.spirit_creature.has_tag("heart_kill") and not t_p.heart_destroyed:
		var fd: int = int(wd_result.get("final_damage", 0))
		if t_p.heart_located:
			# Strikes land on the exposed heart; the body wound is irrelevant (undo it). The
			# heart is an exposed organ, not shielded by the oni's hide, so it takes the strike's
			# pre-Reduction Wounds (otherwise a Reduction-20 heart would be unkillable, defeating
			# the "only the heart can slay it" rule — the one reading consistent with GDD intent).
			target.wounds_taken = maxi(0, target.wounds_taken - fd)
			t_p.heart_wounds += maxi(0, raw)
			if t_p.heart_wounds >= HEART_WOUNDS:
				t_p.heart_destroyed = true
				target.wounds_taken = maxi(target.wounds_taken, target.spirit_creature.wounds_dead)
		elif target.spirit_creature.wounds_dead > 0:
			# Heart hidden: cannot die. Hold body just below Dead (regen restores it).
			target.wounds_taken = mini(target.wounds_taken, target.spirit_creature.wounds_dead - 1)

	# Mokumokuren Gaze (s54.10): the Wounds it inflicts are spiritual — untreatable by
	# Medicine (magic/natural healing cure them normally). Tag the dealt portion.
	if attacker.spirit_creature != null and target.spirit_creature == null \
			and SpiritAbilitySystem.deals_unhealable_spiritual_damage(attacker.spirit_creature):
		var sp_dealt: int = wd_result.get("final_damage", 0)
		if sp_dealt > 0:
			target.spiritual_wounds = mini(target.wounds_taken, target.spiritual_wounds + sp_dealt)

	# Gashadokuro Regeneration (s54.10): pushing the creature past a Wound threshold
	# collapses a section, stopping its per-round regen for 3 rounds. levels_crossed > 0
	# means a threshold was crossed by this hit.
	if target.spirit_creature != null and t_p != null \
			and SpiritAbilitySystem.regen_suppressible(target.spirit_creature) \
			and int(wd_result.get("levels_crossed", 0)) > 0:
		t_p.spirit_regen_suppressed_until = state.combat.round_number + SpiritAbilitySystem.REGEN_SUPPRESS_ROUNDS

	# Spirit attacker on-hit self-heal (O-Toyo Destroyer of Life, s54.10).
	if attacker.spirit_creature != null and raw > 0:
		var heal: int = SpiritAbilitySystem.on_hit_self_heal(attacker.spirit_creature)
		if heal > 0:
			WoundSystem.heal_wounds(attacker, heal)

	# Everything Burns (s54.10 Kagaki): a successful melee hit by a fire creature
	# sets the target on fire — 1k1 at the start of each round (SpiritualEncounter
	# applies it) until a Simple Action extinguishes it. fire_trail tags the Kagaki,
	# whose only attack is the melee Flame Bite (no ranged fire creature exists).
	if attacker.spirit_creature != null and t_p != null \
			and (attacker.spirit_creature.has_tag("fire_trail") or attacker.spirit_creature.has_tag("burning_touch") \
				or attacker.spirit_creature.has_tag("burning_saliva")):
		t_p.on_fire = true

	# Soul Touch (s54.12 Furaribi): a touched character cannot spend Void Points (the GDD
	# 24h duration / Stamina-roll lockout is the cross-encounter portion, not modelled — this
	# is the in-combat lockout). Inert unless the ATTACKER is a soul_touch creature.
	if attacker.spirit_creature != null and t_p != null and target.spirit_creature == null \
			and attacker.spirit_creature.has_tag("soul_touch"):
		t_p.void_locked = true

	# Paralysis Venom (s54.10 Konak Jiji): a successful hit Stuns the target for
	# Water minutes (no save), modelled as a timed Stunned condition that expires
	# rather than being rolled off. Skip if the target is itself a spirit.
	if attacker.spirit_creature != null and t_p != null and target.spirit_creature == null:
		var venom_min: int = SpiritAbilitySystem.paralysis_venom_minutes(attacker.spirit_creature)
		if venom_min > 0:
			var expiry: int = state.combat.round_number + venom_min * IndividualCombat.ROUNDS_PER_MINUTE
			IndividualCombat.apply_timed_condition(t_p, IndividualCombat.CONDITION_STUNNED, expiry)

	# Trample (s54.5/s54.12): a melee hit renders the target Prone; +Dazed if the attack beat
	# the target's Armor TN by trample_daze_margin (Utogu 10).
	if attacker.spirit_creature != null and t_p != null and target.spirit_creature == null \
			and attacker.spirit_creature.trample_prone \
			and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_PRONE)
		var _tdm: int = attacker.spirit_creature.trample_daze_margin
		if _tdm > 0 and int(attack_result.get("margin", 0)) >= _tdm:
			IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_DAZED)

	# Furious Charge Knockdown (s54.12 Rhino): a Full-Attack melee hit attempts a Knockdown
	# (Contested Strength, quadruped, + a Free Raise = +5) → target Prone.
	if attacker.spirit_creature != null and attacker.spirit_creature.charge_knockdown and t_p != null \
			and target.spirit_creature == null and a_p.stance == Enums.Stance.FULL_ATTACK \
			and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		var _kd: Dictionary = IndividualCombat.resolve_knockdown(attacker, target, true, dice_engine, 5)
		if _kd.get("knocked_down", false):
			IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_PRONE)

	# Gore (s54.5 Munemitsu): a melee hit sticks the victim on the tusks (Entangled); pulling
	# free later deals extra damage (applied in attempt_entangle_escape).
	if attacker.spirit_creature != null and t_p != null and target.spirit_creature == null \
			and attacker.spirit_creature.gore_escape_rolled > 0 \
			and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true):
		IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_ENTANGLED)
		t_p.gore_escape_rolled = attacker.spirit_creature.gore_escape_rolled
		t_p.gore_escape_kept = attacker.spirit_creature.gore_escape_kept

	# Stunning Jolt (s54.12 Hinotama): a touch forces a Stamina TN 20 roll — Dazed on success,
	# Stunned on failure (both roll-recoverable).
	if attacker.spirit_creature != null and t_p != null and target.spirit_creature == null \
			and attacker.spirit_creature.has_tag("stunning_jolt"):
		if dice_engine.roll_and_keep(maxi(1, target.stamina), maxi(1, target.stamina), true).total >= 20:
			IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_DAZED)
		else:
			IndividualCombat.apply_condition(t_p, IndividualCombat.CONDITION_STUNNED)

	# Void Leech (s54.12 Kukanchi no Kansen): a wounding hit drains 1 Void Point from the
	# victim and heals the creature 15 Wounds. (The GDD "if a damage die explodes" gate is
	# simplified to any wounding hit — the exploding-die detail is internal to the roll.)
	if attacker.spirit_creature != null and target.spirit_creature == null and raw > 0 \
			and attacker.spirit_creature.has_tag("void_leech"):
		if target.current_void_points > 0:
			target.current_void_points -= 1
		WoundSystem.heal_wounds(attacker, 15)

	# Sap the Void (s54.12 Akeru no Oni): on a Claw hit, an Opposed Void Roll saps 1 Void Point
	# from the target, which the Akeru adds to its own pool (max = its Void Ring).
	if attacker.spirit_creature != null and target.spirit_creature == null and raw > 0 \
			and attacker.spirit_creature.has_tag("sap_the_void") and target.current_void_points > 0:
		var av: int = maxi(1, attacker.void_ring)
		var tv: int = maxi(1, target.void_ring)
		if dice_engine.roll_and_keep(av, av, true).total > dice_engine.roll_and_keep(tv, tv, true).total:
			target.current_void_points -= 1
			attacker.current_void_points = mini(attacker.void_ring, attacker.current_void_points + 1)

	# Throat Attack / follow-up (s54.11 Ghul): a melee hit dealing followup_wound_threshold+
	# Wounds triggers a free bonus attack. Applied directly (does not recurse into _apply_hit).
	if attacker.spirit_creature != null and attacker.spirit_creature.followup_wound_threshold > 0 \
			and not CharacterStats.is_dead(target) \
			and IndividualCombat.get_weapon_profile(weapon_name).get("melee", true) \
			and int(wd_result.get("final_damage", 0)) >= attacker.spirit_creature.followup_wound_threshold:
		var fc: SpiritCreatureData = attacker.spirit_creature
		var fhit: int = dice_engine.roll_and_keep(fc.followup_rolled, fc.followup_kept, true).total
		if fhit >= IndividualCombat.get_armor_tn(target, t_p, dice_engine, true, false, ""):
			var fred: int = 0 if target.spirit_creature != null else maxi(0, target.armor_reduction)
			WoundSystem.apply_damage(target, dice_engine.roll_and_keep(fc.followup_dmg_rolled, fc.followup_dmg_kept, true).total, fred)

	# Disease (s54.5/s54.11): a wounding hit by Byoki/Shikko/plague-zombie can infect a
	# mortal target (cross-encounter drain resolved in the world-sim).
	if attacker.spirit_creature != null and target.spirit_creature == null and raw > 0 \
			and not CharacterStats.is_dead(target):
		_apply_disease_on_hit(attacker, target, int(wd_result.get("final_damage", 0)), dice_engine)

	# Poison / venom (s54.11/s54.12): a hit by a poison creature drains a Trait (Strength for
	# stingers, Stamina for bites). poison_bite (komodo) allows a Stamina TN 20 save; the
	# stinger poisons (Gakimushi) have no save. Cross-encounter restore in the world-sim.
	if attacker.spirit_creature != null and target.spirit_creature == null and raw > 0 \
			and not CharacterStats.is_dead(target):
		var pc: SpiritCreatureData = attacker.spirit_creature
		if pc.has_tag("poisonous_stinger") or pc.has_tag("poison_stinger"):
			DiseaseSystem.apply_poison(target, "strength")
		elif pc.has_tag("poison_stamina"):
			DiseaseSystem.apply_poison(target, "stamina")
		elif pc.has_tag("poison_bite"):
			if not DiseaseSystem.resolve_poison_resist_roll(target, 20, dice_engine):
				DiseaseSystem.apply_poison(target, "stamina")
		# Escalating poison (s54.5 Shikage): −1 Rank now + a per-Round Stamina TN 20 (+5/dose)
		# drain until the victim saves or the Trait hits 0 (Willpower 0 → mind-controlled,
		# Reflexes 0 → paralyzed). Each sting stacks a dose. The per-Round tick runs in
		# advance_round. The creature delivers its mind-breaking poison (Willpower); paralyzing
		# (Reflexes) is the alternate. A target already paralyzed/mind-controlled is skipped.
		var esc_trait: String = ""
		if pc.has_tag("mind_breaking_poison"):
			esc_trait = "willpower"
		elif pc.has_tag("paralyzing_poison"):
			esc_trait = "reflexes"
		if esc_trait != "" and t_p != null and not t_p.conditions.has(IndividualCombat.CONDITION_STUNNED):
			t_p.escalating_poison = DiseaseSystem.escalating_apply(target, t_p.escalating_poison, esc_trait)
			if DiseaseSystem._get_trait(target, esc_trait) <= 0:
				# Immediate collapse to 0 on the application — incapacitate now.
				_apply_escalating_incapacitation(state, t_p, target, esc_trait)

	# Feed Upon the Soul (s54.12 Kyoso no Oni spawn): killing a foe instantly heals the
	# creature 5 × the slain enemy's Insight Rank.
	if attacker.spirit_creature != null and attacker.spirit_creature.has_tag("feed_upon_soul") \
			and target.spirit_creature == null and CharacterStats.is_dead(target):
		WoundSystem.heal_wounds(attacker, 5 * CharacterStats.get_insight_rank(target))

	# Spawn-on-death (s54.5): Tasu releases spawn, Wakeru splits into lesser copies when
	# slain. Fires once, when this hit kills a death_spawn creature.
	if t_p != null and target.spirit_creature != null \
			and target.spirit_creature.death_spawn_id != "" \
			and not t_p.death_spawn_done and CharacterStats.is_dead(target):
		t_p.death_spawn_done = true
		_spawn_on_death(state, target, dice_engine)

	# Retributive Taint (s54.5 Pekkle): a slain Pekkle bursts in a 10-ft (2-tile) radius —
	# every living mortal in the area rolls Earth TN 30 or gains 1–10 points of Taint.
	if t_p != null and target.spirit_creature != null \
			and target.spirit_creature.has_tag("retributive_taint") \
			and not t_p.death_spawn_done and CharacterStats.is_dead(target):
		t_p.death_spawn_done = true
		_apply_retributive_taint(state, target, dice_engine)

	# Divide the Soul (s37 Void): if either manifestation dies, both die.
	if CharacterStats.is_dead(target) and state.divide_soul_pairs.has(target.character_id):
		_apply_divide_soul_shared_death(state, target.character_id)

	return {
		"damage": wd_result.get("final_damage", raw),
		"wounds": wd_result.get("final_damage", raw),
		"dead": CharacterStats.is_dead(target),
	}


## s37 Divide the Soul shared death: when one manifestation (caster or clone) dies, the partner
## dies too. Sets the partner's Wounds lethal and breaks the link (idempotent — the partner's own
## death does not re-fire because the link is erased before the partner is killed).
static func _apply_divide_soul_shared_death(state: MapCombatState, dead_id: int) -> void:
	var partner_id: int = int(state.divide_soul_pairs.get(dead_id, 0))
	# Break the bidirectional link first so killing the partner does not recurse.
	state.divide_soul_pairs.erase(dead_id)
	state.divide_soul_pairs.erase(partner_id)
	var partner = state.combatants.get(partner_id, null)
	if partner != null and not CharacterStats.is_dead(partner):
		partner.wounds_taken = maxi(partner.wounds_taken, CharacterStats.get_total_wound_capacity(partner) + 1)


## Disease contraction (s54.5/s54.11): a wounding hit by a disease creature may infect a
## mortal target. Byoki Plague Bearer — Contested Earth (oni vs victim). Shikko Diseased
## Touch — victim Stamina roll vs wounds inflicted. Plague zombie Plague Carrier — 1-in-5.
## Seeds DiseaseSystem.contract on success (ic_day -1; the world-sim anchors the clock).
static func _apply_disease_on_hit(attacker: L5RCharacterData, target: L5RCharacterData, wounds: int, dice: DiceEngine) -> void:
	var cr: SpiritCreatureData = attacker.spirit_creature
	if DiseaseSystem.is_diseased(target):
		return
	if cr.has_tag("plague_bearer"):
		var oe: int = mini(attacker.stamina, attacker.willpower)
		var ve: int = mini(target.stamina, target.willpower)
		if dice.roll_and_keep(maxi(1, oe), maxi(1, oe), true).total > dice.roll_and_keep(maxi(1, ve), maxi(1, ve), true).total:
			DiseaseSystem.contract(target, DiseaseSystem.Type.PLAGUE_BEARER, attacker.character_id)
	elif cr.has_tag("diseased_touch"):
		# Victim resists with a Stamina roll vs the wounds inflicted; failure → infection.
		if dice.roll_and_keep(maxi(1, target.stamina), maxi(1, target.stamina), true).total < wounds:
			DiseaseSystem.contract(target, DiseaseSystem.Type.DISEASED_TOUCH, attacker.character_id)
	elif cr.has_tag("plague_carrier"):
		if dice.roll_die(5) == 1:  # 1-in-5 chance
			DiseaseSystem.contract(target, DiseaseSystem.Type.PLAGUE_CARRIER, attacker.character_id)


## s54.5 Shikage escalating-poison end state: the Trait reached 0. Willpower 0 → mind-controlled
## (obeys commands, even suicidal — 24h); Reflexes 0 → paralyzed (12h). Both are modelled as a
## timed Stunned condition (can't act, does NOT roll off — expires by duration) for the GDD
## duration, effectively the rest of the skirmish. The full mind-control puppeteering (the
## possessor directing the victim's actions) is not modelled — the victim is incapacitated.
static func _apply_escalating_incapacitation(state: MapCombatState, t_p: IndividualCombat.Participant, _victim: L5RCharacterData, trait_name: String) -> void:
	var minutes: int = 1440 if trait_name == "willpower" else 720  # 24h mind-control / 12h paralysis
	var expiry: int = state.combat.round_number + minutes * IndividualCombat.ROUNDS_PER_MINUTE
	IndividualCombat.apply_timed_condition(t_p, IndividualCombat.CONDITION_STUNNED, expiry)


## Counts living enemies of `attacker_id` within `radius` (Chebyshev) of the center tile,
## including a co-located primary at center_id. Used to gate melee multi-target AoE (only
## worth it against a cluster).
static func _enemies_within(state: MapCombatState, attacker_id: int, center_id: int, radius: int) -> int:
	var center: Vector2i = state.positions.get(center_id, Vector2i(-9999, -9999))
	if center.x < -9000:
		return 0
	var faction: String = state.factions.get(attacker_id, FACTION_NEUTRAL)
	var n: int = 0
	for cid: int in state.positions.keys():
		if cid == attacker_id or not _are_enemies(faction, state.factions.get(cid, FACTION_NEUTRAL)):
			continue
		var v: L5RCharacterData = state.combatants.get(cid, null)
		if v == null or CharacterStats.is_dead(v):
			continue
		if _chebyshev(center, state.positions[cid]) <= radius:
			n += 1
	return n


## Maps the attacker's equipped weapon material to a SpiritAbilitySystem weapon kind for the
## s54 spirit/oni damage filter (incorporeal, invulnerability, kind-gated Reduction). Reads
## the matching WeaponData in attacker.weapons by name; "" / "steel" -> mundane (the common
## case, faithful — ordinary weapons cannot pierce a spirit's invulnerability). Recognised
## materials: jade, crystal, obsidian, magic, fire, water.
static func _weapon_kind(attacker: L5RCharacterData, weapon_name: String) -> String:
	if attacker == null:
		return SpiritAbilitySystem.W_MUNDANE
	for w: WeaponData in attacker.weapons:
		if w != null and w.weapon_name == weapon_name:
			match w.material.to_lower():
				"jade":     return SpiritAbilitySystem.W_JADE
				"crystal":  return SpiritAbilitySystem.W_CRYSTAL
				"obsidian": return SpiritAbilitySystem.W_OBSIDIAN
				"magic":    return SpiritAbilitySystem.W_MAGIC
				"fire":     return SpiritAbilitySystem.W_FIRE
				"water":    return SpiritAbilitySystem.W_WATER
			break
	return SpiritAbilitySystem.W_MUNDANE


## Fire damage for a character this round: base standing damage (1k1) plus the s54.5/s54.12
## fire_susceptible bonus (+2k2 — Quiet Death's flesh combusts) for any fire source.
static func _fire_damage_for(c: L5RCharacterData, dice: DiceEngine) -> int:
	# Base per-round burn is 1k1 (FireSystem.standing_damage). Fire vulnerabilities add
	# extra dice to that roll (folded into the pool — "+NkM", not a separate roll, so a
	# "+1k0" actually grants an extra rolled die rather than rolling 1-keep-0 = nothing).
	var rolled: int = 1
	var kept: int = 1
	if c.spirit_creature != null:
		if c.spirit_creature.has_tag("fire_susceptible"):
			rolled += 2  # +2k2 (s54.5 Quiet Death: "additional +2k2 from fire")
			kept += 2
		elif c.spirit_creature.has_tag("water_vulnerable_fire"):
			rolled += 1  # +1k0 mundane fire (s54.12 Mizu no Oni / Oyuchi no Kansen)
	return dice.roll_and_keep(rolled, kept, true).total


## Spawn-on-death (s54.5): adds death_spawn_count copies of death_spawn_id near the slain
## creature's tile, on the same faction, via add_enemy. The spawn ids are unique negative
## (state.spawn_counter). Tasu → tasu_spawn ×N; Wakeru → wakeru_lesser ×N (the lesser copy
## has no further death_spawn_id, so the split is one generation — full recursive halving
## is not modelled). Returns the number spawned.
static func _spawn_on_death(state: MapCombatState, dead_creature: L5RCharacterData, dice: DiceEngine) -> int:
	var cr: SpiritCreatureData = dead_creature.spirit_creature
	var faction: String = state.factions.get(dead_creature.character_id, FACTION_ENEMY)
	var center: Vector2i = state.positions.get(dead_creature.character_id, Vector2i(0, 0))
	var made: int = 0
	for i in range(maxi(0, cr.death_spawn_count)):
		var tile: Vector2i = _free_tile_near(state, center)
		if tile.x < 0:
			break
		state.spawn_counter += 1
		var inst_id: int = -900000 - state.spawn_counter
		var pup: L5RCharacterData = SpiritCombatant.spawn_by_id(cr.death_spawn_id, inst_id)
		if pup == null:
			break
		if add_enemy(state, pup, tile.x, tile.y, dice):
			# keep the offspring on the parent's faction (Wakeru split, Tasu brood)
			state.factions[inst_id] = faction
			made += 1
	return made


## Retributive Taint (s54.5 Pekkle): on death, every living mortal within 2 tiles (10 ft)
## rolls Earth TN 30 or gains 1–10 points of Taint. Returns the number of victims tainted.
static func _apply_retributive_taint(state: MapCombatState, dead_creature: L5RCharacterData, dice: DiceEngine) -> int:
	var center: Vector2i = state.positions.get(dead_creature.character_id, Vector2i(-1, -1))
	if center.x < 0:
		return 0
	var tainted: int = 0
	for cid: int in state.positions.keys():
		if cid == dead_creature.character_id:
			continue
		if _chebyshev(center, state.positions[cid]) > 2:
			continue
		var c: L5RCharacterData = state.combatants.get(cid, null)
		if c == null or CharacterStats.is_dead(c) or c.spirit_creature != null:
			continue
		var earth: int = mini(c.stamina, c.willpower)
		# s37 Strength of the Crow: +taint_resist k taint_resist to resist new Taint.
		var c_pp = state.combat.participants.get(cid, null)
		var c_tr: int = IndividualCombat.get_timed_modifier_total(c_pp, "taint_resist") if c_pp != null else 0
		if dice.roll_and_keep(maxi(1, earth + c_tr), maxi(1, earth + c_tr), true).total < 30:
			c.taint = minf(100.0, c.taint + float(dice.roll_die(10)))
			tainted += 1
	return tainted


## Nearest free (passable, unoccupied) tile to `center` via expanding-ring search.
## Returns (-1,-1) if none within a small radius.
static func _free_tile_near(state: MapCombatState, center: Vector2i) -> Vector2i:
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var t := Vector2i(center.x + dx, center.y + dy)
				if t.x < 0 or t.y < 0 or t.x >= state.map.width or t.y >= state.map.height:
					continue
				if not MovementSystem.is_passable(state.map.get_tile(t.x, t.y)):
					continue
				var occupied := false
				for pos: Vector2i in state.positions.values():
					if pos == t:
						occupied = true
						break
				if not occupied:
					return t
	return Vector2i(-1, -1)


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


## Cover bonus to Armor TN: a defender shielded by a cover-granting furnishing
## (s4.4) on the tile immediately toward the attacker gains +COVER_ARMOR_TN_BONUS.
## tpos = target position, apos = attacker position.
static func _cover_bonus(state: MapCombatState, tpos: Vector2i, apos: Vector2i) -> int:
	var dx: int = signi(apos.x - tpos.x)
	var dy: int = signi(apos.y - tpos.y)
	if dx == 0 and dy == 0:
		return 0
	var cx: int = tpos.x + dx
	var cy: int = tpos.y + dy
	if cx < 0 or cy < 0 or cx >= state.map.width or cy >= state.map.height:
		return 0
	if AsciiMapData.grants_cover(state.map.get_tile(cx, cy)):
		return COVER_ARMOR_TN_BONUS
	# Elevation cover (s4.4 Z-axis): a defender below the attacker, tucked at the
	# base of a rise (the tile toward the attacker is a higher lip), is shielded.
	# Same +5 — cover does not stack with furniture cover.
	if state.map.has_elevation():
		var t_elev: int = state.map.elevation_at(tpos.x, tpos.y)
		if state.map.elevation_at(apos.x, apos.y) > t_elev \
				and state.map.elevation_at(cx, cy) > t_elev:
			return COVER_ARMOR_TN_BONUS
	return 0


## High-ground attack bonus (s4.4 Z-axis): +HIGH_GROUND_ATTACK_ROLLED rolled die
## (+1k0) when the attacker stands at least HIGH_GROUND_THRESHOLD levels above the
## target. 0 on a flat map. Returned as a positive attacker_roll_penalty — which
## adds rolled dice (resolve_attack: rolled = max(0, rolled + attacker_roll_penalty)).
static func _high_ground_attack_bonus(state: MapCombatState, apos: Vector2i, tpos: Vector2i) -> int:
	if state.map == null or not state.map.has_elevation():
		return 0
	var d: int = state.map.elevation_at(apos.x, apos.y) - state.map.elevation_at(tpos.x, tpos.y)
	return HIGH_GROUND_ATTACK_ROLLED if d >= HIGH_GROUND_THRESHOLD else 0


## Bresenham line-of-sight check, elevation-aware (s4.4 Z-axis).
## Returns true if no tile occludes the sightline between a and b (endpoints excluded).
## Flat map (no elevation grid): any LOS-blocking tile strictly between blocks — exactly
## the prior behavior. Elevated map: a tile occludes only when its top reaches the
## interpolated view-ray height, so a viewer on high ground sees over low obstacles.
static func _has_los(map: AsciiMapData, a: Vector2i, b: Vector2i) -> bool:
	var pts: Array = _bresenham_points(a, b)
	var n: int = pts.size()
	if n <= 2:
		return true

	if not map.has_elevation():
		for i in range(1, n - 1):
			if AsciiMapData.blocks_los(map.get_tile(pts[i].x, pts[i].y)):
				return false
		return true

	# Height-aware: interpolate eye-level height along the ray; a tile blocks when its
	# top (elevation, +LOS_OBSTACLE_HEIGHT for walls/trees) reaches that height.
	var a_eye: float = float(map.elevation_at(a.x, a.y) + LOS_EYE_HEIGHT)
	var b_eye: float = float(map.elevation_at(b.x, b.y) + LOS_EYE_HEIGHT)
	for i in range(1, n - 1):
		var p: Vector2i = pts[i]
		var t: float = float(i) / float(n - 1)
		var line_h: float = a_eye + (b_eye - a_eye) * t
		var top: float = float(map.elevation_at(p.x, p.y))
		if AsciiMapData.blocks_los(map.get_tile(p.x, p.y)):
			top += float(LOS_OBSTACLE_HEIGHT)
		if top >= line_h:
			return false
	return true


## Bresenham point list from a to b inclusive (a is pts[0], b is pts[n-1]).
static func _bresenham_points(a: Vector2i, b: Vector2i) -> Array:
	var pts: Array = []
	var x0: int = a.x
	var y0: int = a.y
	var dx: int = abs(b.x - x0)
	var dy: int = abs(b.y - y0)
	var sx: int = 1 if x0 < b.x else -1
	var sy: int = 1 if y0 < b.y else -1
	var err: int = dx - dy
	var cx: int = x0
	var cy: int = y0
	while true:
		pts.append(Vector2i(cx, cy))
		if cx == b.x and cy == b.y:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy
	return pts


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
