class_name TrapSystem
## s56.20 Dungeon Traps --- LOCKED (owner-approved 2026-06-16). Pure simulation.
## Hidden hazards on ASCII-map missions. Traps are a DATA layer (dicts on
## AsciiMapData.traps), not tiles, so a hidden trap never renders. The player
## detects them passively, then disarms, routes around, or springs them.
##
## All numeric values are PROVISIONAL (the GDD describes the mechanic but not the
## numbers); calibrated against L5R 4e scale and comparable hazards, to be retuned
## after a live run. Setting basis: Crane Daidoji Hunting:Traps (s29.2 / s11.7).

# -- Enums --------------------------------------------------------------------

enum TrapType { PIT, DART, SNARE, ALARM, DEADFALL }
enum TrapState { HIDDEN, DETECTED, DISARMED, SPRUNG }
# Build quality drives both the detect TN and the disarm TN.
enum Quality { CRUDE, SET, CONCEALED, MASTER }

# -- Constants (PROVISIONAL) --------------------------------------------------

# Detect / disarm TN by build quality (same tier table for both, per the lock).
const QUALITY_TN: Dictionary = {
	Quality.CRUDE:     15,
	Quality.SET:       20,
	Quality.CONCEALED: 25,
	Quality.MASTER:    30,
}

# Passive detection only sees traps within this Chebyshev radius (and in FOV).
const DETECT_RANGE: int = 2

# Pit fall: an Athletics roll vs this TN halves the damage (catch the edge).
const PIT_SAVE_TN: int = 15
# Snare: Entangled; escape via this TN (oni-web parity, s54.5).
const SNARE_ESCAPE_TN: int = 20
# s40 stealth model: a flat-footed target's Armor TN = 5 + armor bonus.
const FLAT_FOOTED_ATN_BASE: int = 5
# Disarming and missing the TN by this much or more springs the trap.
const DISARM_FUMBLE_MARGIN: int = 10

# Damage pools (rolled, kept), exploding.
const PIT_DAMAGE: Vector2i      = Vector2i(2, 2)
const DART_DAMAGE: Vector2i     = Vector2i(2, 2)
const DEADFALL_DAMAGE: Vector2i = Vector2i(3, 2)

# Skill names (canonical, s4.5 skill list).
const SKILL_HUNTING: String        = "Hunting"
const SKILL_SLEIGHT_OF_HAND: String = "Sleight of Hand"
const SKILL_ATHLETICS: String      = "Athletics"

# -- Factory ------------------------------------------------------------------

## Builds a trap dict for AsciiMapData.traps. detect_tn and disarm_tn both come
## from the build quality (the lock uses one tier table for both).
static func make_trap(x: int, y: int, type: int, quality: int = Quality.SET) -> Dictionary:
	var tn: int = QUALITY_TN.get(quality, QUALITY_TN[Quality.SET])
	return {
		"x": x,
		"y": y,
		"type": type,
		"quality": quality,
		"state": TrapState.HIDDEN,
		"detect_tn": tn,
		"disarm_tn": tn,
	}

# -- Classification -----------------------------------------------------------

## Physically loud traps (raise nearby enemy alert when sprung).
static func is_loud(type: int) -> bool:
	return type == TrapType.PIT or type == TrapType.DEADFALL

## Whether springing this trap should alert nearby enemies: loud traps, plus the
## ALARM/tripwire (whose entire purpose is to alert). Dart and Snare are silent.
static func alerts_on_spring(type: int) -> bool:
	return is_loud(type) or type == TrapType.ALARM

# -- Lookup -------------------------------------------------------------------

## Returns the first still-active (HIDDEN or DETECTED) trap at (x, y), or {}.
static func trap_at(map: AsciiMapData, x: int, y: int) -> Dictionary:
	for t: Dictionary in map.traps:
		if t.get("x", -1) == x and t.get("y", -1) == y:
			var st: int = t.get("state", TrapState.HIDDEN)
			if st == TrapState.HIDDEN or st == TrapState.DETECTED:
				return t
	return {}

# -- Detection (passive, per turn) --------------------------------------------

## Rolls a single HIDDEN trap against the character's passive Perception + Hunting
## vs detect_tn. On success flips the trap to DETECTED. Returns true if newly
## detected. No-op for non-HIDDEN traps.
static func attempt_detect(character: L5RCharacterData, trap: Dictionary, dice: DiceEngine) -> bool:
	if trap.get("state", TrapState.HIDDEN) != TrapState.HIDDEN:
		return false
	var rank: int = character.skills.get(SKILL_HUNTING, 0)
	var wound_pen: int = CharacterStats.get_wound_penalty(character)
	var r: Dictionary = dice.roll_check(
		character.perception + rank, character.perception,
		trap.get("detect_tn", 20), 0, wound_pen, rank > 0)
	if r.get("success", false):
		trap["state"] = TrapState.DETECTED
		return true
	return false

# -- Disarm -------------------------------------------------------------------

## Disarms a DETECTED trap: the better of Hunting:Traps or Sleight of Hand vs
## disarm_tn. Success → DISARMED. Missing by DISARM_FUMBLE_MARGIN or more springs
## the trap (resolved via trigger). The caller must verify adjacency + DETECTED.
## Returns { "attempted", "disarmed", "sprung", "margin", "trigger_result" }.
static func attempt_disarm(
		map: AsciiMapData,
		character: L5RCharacterData,
		trap: Dictionary,
		dice: DiceEngine,
		victim_participant: IndividualCombat.Participant = null) -> Dictionary:
	if trap.get("state", TrapState.HIDDEN) != TrapState.DETECTED:
		return {"attempted": false, "disarmed": false, "sprung": false, "reason": "not_detected"}

	var hunting: int = character.skills.get(SKILL_HUNTING, 0)
	var sleight: int = character.skills.get(SKILL_SLEIGHT_OF_HAND, 0)
	var wound_pen: int = CharacterStats.get_wound_penalty(character)
	# Better of the two: Hunting uses Perception, Sleight of Hand uses Agility.
	var use_sleight: bool = (character.agility + sleight) > (character.perception + hunting)
	var rolled: int = (character.agility + sleight) if use_sleight else (character.perception + hunting)
	var kept: int = character.agility if use_sleight else character.perception
	var rank: int = sleight if use_sleight else hunting

	var r: Dictionary = dice.roll_check(
		rolled, kept, trap.get("disarm_tn", 20), 0, wound_pen, rank > 0)
	var margin: int = r.get("margin", 0)

	if r.get("success", false):
		trap["state"] = TrapState.DISARMED
		return {"attempted": true, "disarmed": true, "sprung": false, "margin": margin}

	# Fumble: missing by the fumble margin or more springs the trap on the disarmer.
	if margin <= -DISARM_FUMBLE_MARGIN:
		var trig: Dictionary = trigger(map, character, victim_participant, trap, dice)
		return {"attempted": true, "disarmed": false, "sprung": true,
			"margin": margin, "trigger_result": trig}
	return {"attempted": true, "disarmed": false, "sprung": false, "margin": margin}

# -- Trigger ------------------------------------------------------------------

## Springs the trap on the victim. Sets state SPRUNG, resolves the type-specific
## effect (damage via WoundSystem, Entangled via IndividualCombat, rubble via map
## deltas), and reports whether nearby enemies should be alerted. victim_participant
## may be null (e.g. a non-combatant); the Entangled condition is then skipped.
## Returns { "type", "damage", "entangled", "rubble", "alerts" } plus a wound dict.
static func trigger(
		map: AsciiMapData,
		victim_char: L5RCharacterData,
		victim_participant: IndividualCombat.Participant,
		trap: Dictionary,
		dice: DiceEngine) -> Dictionary:
	trap["state"] = TrapState.SPRUNG
	var type: int = trap.get("type", TrapType.PIT)
	var result: Dictionary = {
		"type": type,
		"damage": 0,
		"entangled": false,
		"rubble": [],
		"alerts": alerts_on_spring(type),
	}

	match type:
		TrapType.PIT:
			var dmg: int = dice.roll_and_keep(PIT_DAMAGE.x, PIT_DAMAGE.y).total
			# Athletics to catch the edge halves the fall damage.
			var save: Dictionary = dice.roll_check(
				victim_char.strength + victim_char.skills.get(SKILL_ATHLETICS, 0),
				victim_char.strength, PIT_SAVE_TN, 0,
				CharacterStats.get_wound_penalty(victim_char),
				victim_char.skills.get(SKILL_ATHLETICS, 0) > 0)
			if save.get("success", false):
				dmg = dmg / 2
			# A fall ignores armor (reduction 0).
			result["wound"] = WoundSystem.apply_damage(victim_char, dmg, 0)
			result["damage"] = result["wound"]["final_damage"]
			result["saved"] = save.get("success", false)

		TrapType.DART:
			# Ranged attack vs the victim's flat-footed Armor TN (5 + armor).
			var atn: int = FLAT_FOOTED_ATN_BASE + victim_char.armor_tn_bonus
			var atk: Dictionary = dice.roll_check(DART_DAMAGE.x, DART_DAMAGE.y, atn)
			if atk.get("success", false):
				var ddmg: int = dice.roll_and_keep(DART_DAMAGE.x, DART_DAMAGE.y).total
				# Armor reduces a dart (default reduction).
				result["wound"] = WoundSystem.apply_damage(victim_char, ddmg)
				result["damage"] = result["wound"]["final_damage"]
				result["hit"] = true
			else:
				result["hit"] = false

		TrapType.SNARE:
			if victim_participant != null:
				IndividualCombat.apply_condition(
					victim_participant, IndividualCombat.CONDITION_ENTANGLED)
				result["entangled"] = true
				result["escape_tn"] = SNARE_ESCAPE_TN

		TrapType.ALARM:
			pass  # No damage — alert only (result["alerts"] is true).

		TrapType.DEADFALL:
			var hdmg: int = dice.roll_and_keep(DEADFALL_DAMAGE.x, DEADFALL_DAMAGE.y).total
			# A collapse ignores armor (reduction 0).
			result["wound"] = WoundSystem.apply_damage(victim_char, hdmg, 0)
			result["damage"] = result["wound"]["final_damage"]
			# The fallen rubble blocks the trap tile.
			var tx: int = trap.get("x", -1)
			var ty: int = trap.get("y", -1)
			if tx >= 0 and ty >= 0:
				map.set_delta(tx, ty, Enums.TileType.RUBBLE)
				result["rubble"] = [Vector2i(tx, ty)]

	return result

# -- Placement gate (PROVISIONAL — pending owner confirmation) ----------------

# Roster unit_type strings whose archetype canonically lays traps: experienced
# human ambushers (skilled bandits, their lord, ronin enforcers) plus scouts.
# The roster groups carry no per-unit skill data, so this allowlist is the
# implementation's stand-in for "the roster contains a Hunting:Traps unit."
# Owner-confirmed 2026-06-16 (expand to bandits/ambushers); rabble/peasant/undead
# units are excluded (no trap-craft). "Crane defensive" units are N/A — these are
# enemy rosters and the player's own clan has no enemy unit type.
# String literals mirror RosterCompositionSystem constants (hardcoded to avoid a
# cross-class const-in-const initializer).
const TRAP_LAYER_UNIT_TYPES: Array = [
	"HIRUMA_SCOUT",
	"NEZUMI_SCOUT",
	"EXPERIENCED_BANDIT",
	"BANDIT_LORD",
	"RONIN_ENFORCER",
]

## True if any roster group is a trap-laying unit type. Handles both the standard
## roster ({"groups":[...]}) and the wall-sortie roster (friendly/enemy groups).
static func roster_has_trap_layer(roster: Dictionary) -> bool:
	for key: String in ["groups", "friendly_groups", "enemy_groups"]:
		for g: Dictionary in roster.get(key, []):
			if g.get("unit_type", "") in TRAP_LAYER_UNIT_TYPES:
				return true
	return false

# -- Placement ----------------------------------------------------------------

# Maximum traps on one map (PROVISIONAL — density scales with seed strength,
# which the lock specifies without a count; ~1 trap per Strength point, capped).
const MAX_TRAPS: int = 6
# Traps cluster within this radius of an objective ("the approach to the
# objective room", s56.20). PROVISIONAL.
const OBJECTIVE_APPROACH_RADIUS: int = 4
# Type frequency for random selection (PROVISIONAL): alarms and pits are common,
# deadfalls rare.
const _TYPE_WEIGHTS: Array = [
	TrapType.PIT, TrapType.PIT,
	TrapType.DART, TrapType.DART,
	TrapType.SNARE,
	TrapType.ALARM, TrapType.ALARM,
	TrapType.DEADFALL,
]

## Build quality from seed strength (PROVISIONAL): tougher seeds set better traps.
static func quality_for_strength(strength: int) -> int:
	if strength >= 7:
		return Quality.MASTER
	if strength >= 5:
		return Quality.CONCEALED
	if strength >= 3:
		return Quality.SET
	return Quality.CRUDE

## Places traps on the map, deterministically from the seed. Gated on the roster
## carrying a trap-laying unit (roster_has_trap_layer) — otherwise no traps.
## Clusters on passable approach tiles around the objective slots (falling back to
## any passable floor when no objective is near). Returns the number placed.
## Count and clustering are PROVISIONAL (see constants). Appends to map.traps.
static func place_traps(map: AsciiMapData, roster: Dictionary, strength: int, seed: int) -> int:
	if not roster_has_trap_layer(roster):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("traps_" + map.seed_string + "_" + str(seed))

	var objectives: Array = map.get("objective_slots") if map.get("objective_slots") != null else []
	var candidates: Array = _gather_trap_candidates(map, objectives)
	if candidates.is_empty():
		return 0

	# Deterministic shuffle.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var quality: int = quality_for_strength(strength)
	var want: int = clampi(strength, 1, MAX_TRAPS)
	var placed: int = 0
	var used: Dictionary = {}
	for pos: Vector2i in candidates:
		if placed >= want:
			break
		var key: String = "%d,%d" % [pos.x, pos.y]
		if used.has(key):
			continue
		used[key] = true
		var type: int = _TYPE_WEIGHTS[rng.randi_range(0, _TYPE_WEIGHTS.size() - 1)]
		map.traps.append(make_trap(pos.x, pos.y, type, quality))
		placed += 1
	return placed


# Passable, non-exit, non-door floor tiles within OBJECTIVE_APPROACH_RADIUS of an
# objective slot. Falls back to all passable floor tiles when no objective exists
# or none has nearby floor. Excludes objective tiles themselves.
static func _gather_trap_candidates(map: AsciiMapData, objectives: Array) -> Array:
	var obj_pts: Array = []
	for o: Dictionary in objectives:
		obj_pts.append(Vector2i(o.get("x", -1), o.get("y", -1)))

	var near: Array = []
	var all_floor: Array = []
	for y in range(map.height):
		for x in range(map.width):
			var tile: int = map.get_tile(x, y)
			if not AsciiMapData.is_passable(tile):
				continue
			if tile == Enums.TileType.ZONE_EXIT or AsciiMapData.is_door(tile):
				continue
			var here := Vector2i(x, y)
			var is_obj: bool = false
			for op: Vector2i in obj_pts:
				if op == here:
					is_obj = true
					break
			if is_obj:
				continue
			all_floor.append(here)
			for op: Vector2i in obj_pts:
				if op.x >= 0 and maxi(absi(op.x - x), absi(op.y - y)) <= OBJECTIVE_APPROACH_RADIUS:
					near.append(here)
					break
	return near if not near.is_empty() else all_floor
