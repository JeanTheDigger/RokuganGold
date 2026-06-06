class_name CombatController
## ASCII map combat controller per GDD s40, s56.6.3, s54.8, s54.9.
## Implements the roguelike/Dwarf Fortress Adventure Mode model:
##   - Player moves into an adjacent Alert enemy tile = melee attack (bump-to-attack).
##   - NPCs detect noise, investigate, and attack when adjacent.
## Pure simulation class — no Node inheritance.


# =============================================================================
# -- LOCKED constants (s56.6.3) -----------------------------------------------
# =============================================================================

## Detection TN by noise level. Very Loud = automatic (TN 0).
const NOISE_DETECTION_TN: Dictionary = {
	AsciiMapEnvironment.NoiseLevel.QUIET:     20,
	AsciiMapEnvironment.NoiseLevel.MODERATE:  15,
	AsciiMapEnvironment.NoiseLevel.LOUD:      10,
	AsciiMapEnvironment.NoiseLevel.VERY_LOUD: 0,
}

## s56.6.3 LOCKED: 3 rounds of active investigation while SUSPICIOUS.
const SUSPICIOUS_SEARCH_ROUNDS: int = 3
## s56.6.3 LOCKED: 3 rounds to return to post if nothing found.
const SUSPICIOUS_RETURN_ROUNDS: int = 3
## s56.6.3 LOCKED: after 5 rounds without locating player → alarm raised.
const ALERT_ALARM_ROUNDS: int = 5
## s56.6.3 LOCKED: sleeping targets have +10 to their detection TN.
const SLEEPING_DETECTION_BONUS: int = 10
## s56.6.3 LOCKED: enemies in combat have +5 to distant-noise detection TN.
const COMBAT_DETECTION_BONUS: int = 5
## s56.6.3 LOCKED: Investigation/Perception bonus while SUSPICIOUS.
const SUSPICIOUS_SCAN_BONUS: int = 5
## s56.6.3 LOCKED: Stealth (Sneaking) TNs by ground surface type.
const STEALTH_TN_SOFT: int  = 10
const STEALTH_TN_HARD: int  = 15
const STEALTH_TN_NOISY: int = 20


# =============================================================================
# -- LOCKED morale thresholds (s54.8) -----------------------------------------
# =============================================================================

## Fraction of initial enemy count that must be visible-dead to break morale.
const MORALE_THRESHOLDS: Dictionary = {
	"BANDIT_RABBLE":   0.40,
	"REBEL_PEASANT":   0.60,
	"BANDIT_THUG":     0.60,
	"REBEL_ASHIGARU":  0.70,
}
## Unit types whose morale NEVER breaks (s54.8 LOCKED).
const MORALE_UNBREAKABLE: Array[String] = ["REBEL_LEADER"]


# =============================================================================
# -- Investigation styles (s56.6.3 LOCKED categories) -------------------------
# -- "timid", "cautious", "professional", "aggressive", "caller"
# -- Mapping of roster unit types to GDD-specified categories.
# =============================================================================

const INVESTIGATION_STYLE: Dictionary = {
	# s56.6.3 "Bandit Rabble: timid (half speed)"
	"BANDIT_RABBLE":         "timid",
	"REBEL_PEASANT":         "timid",
	# s56.6.3 "Bandit Thug: cautious (find cover + angle)"
	"BANDIT_THUG":           "cautious",
	"BAKEMONO_ARCHER":       "cautious",
	"BAKEMONO_SNEAK":        "cautious",
	# s56.6.3 "Ronin: professional (direct + weapon drawn)"
	"SIMPLE_BANDIT":         "professional",
	"EXPERIENCED_BANDIT":    "professional",
	"REBEL_ASHIGARU":        "professional",
	"BAKEMONO_WARRIOR":      "professional",
	"BAKEMONO_WARMONGER":    "professional",
	"TROLL":                 "professional",
	# s56.6.3 "Samurai: aggressive (full speed + challenge loudly)"
	"BANDIT_LORD":           "aggressive",
	"REBEL_LEADER":          "aggressive",
	"FREE_OGRE":             "aggressive",
	"FREE_OGRE_LEADER":      "aggressive",
	"FREE_OGRE_OVERLORD":    "aggressive",
	# s56.6.3 "Shugenja: non-investigator (calls guards)"
	"BAKEMONO_SHAMAN":       "caller",
}


# =============================================================================
# -- Factions ------------------------------------------------------------------
# =============================================================================

const FACTION_PLAYER:   int = 0
const FACTION_FRIENDLY: int = 1
const FACTION_ENEMY:    int = 2


# =============================================================================
# -- EntityState inner class --------------------------------------------------
# =============================================================================

class EntityState:
	var entity_id:            int = -1
	var character:            L5RCharacterData
	var unit_type:            String = ""
	var faction:              int = CombatController.FACTION_ENEMY
	var x:                    int = 0
	var y:                    int = 0
	## Home patrol position — entity returns here when investigation fails.
	var patrol_x:             int = 0
	var patrol_y:             int = 0
	var alert_state:          int = AsciiMapEnvironment.AlertState.UNAWARE
	var is_alive:             bool = true
	var is_sleeping:          bool = false
	## IndividualCombat.Participant for this entity's current combat state.
	var participant:          IndividualCombat.Participant
	## Position of the last detected noise (navigation target while SUSPICIOUS/ALERT).
	var noise_src_x:          int = -1
	var noise_src_y:          int = -1
	## Rounds remaining in the current alert sub-phase.
	var phase_rounds_left:    int = 0
	## Rounds without locating player while ALERT.
	var alert_rounds_lost:    int = 0
	## True once the alarm has been sounded (VERY_LOUD, map-wide).
	var alarm_sounded:        bool = false
	var morale_broken:        bool = false
	## Whether this entity is actively attacking a target.
	var in_combat:            bool = false
	var combat_target_id:     int = -1
	## Creature wound override: entity dies when wounds_taken >= wounds_dead.
	## 0 means use CharacterStats.is_dead() (human wound levels).
	var wounds_dead:          int = 0
	## s56.6.3 LOCKED investigation style (set from INVESTIGATION_STYLE table).
	var investigation_style:  String = "professional"
	## Movement budget consumed this round.
	var move_budget_used:     int = 0


# =============================================================================
# -- State fields --------------------------------------------------------------
# =============================================================================

var _map:          AsciiMapData
var _dice:         DiceEngine
var _weather:      int = AsciiMapEnvironment.WeatherState.CLEAR
var _is_ravine:    bool = false

## All entities keyed by entity_id.
var _entities:     Dictionary = {}
var _next_id:      int = 1
var _round:        int = 0

## entity_id of the player entity.
var _player_id:    int = -1
## True when the player has activated stealth this round.
var _player_stealth: bool = false

## Running count of all enemies that have died (for morale checks).
var _enemy_deaths_total: int = 0
## Initial enemy count at combat start (for morale threshold).
var _initial_enemy_count: int = 0

## Set of tile positions that currently hold a visible corpse.
var _corpse_positions: Array[Vector2i] = []

## Events collected during the current action (e.g. noise detection from _emit_noise).
## Flushed by advance_npc_turns() and player action methods.
var _pending_noise_events: Array = []

## Mission objective tile positions.
var _objective_slots: Array = []

## Dedup flags — prevent terminal events from firing more than once.
var _mission_complete_notified: bool = false
var _player_died_notified: bool = false


# =============================================================================
# -- Factory ------------------------------------------------------------------
# =============================================================================

## Create a CombatController from a MissionSession and the player's character.
static func create(
		session: MissionSession,
		player_char: L5RCharacterData,
		dice: DiceEngine,
) -> CombatController:
	var cc := CombatController.new()
	cc._map          = session.map
	cc._dice         = dice
	cc._weather      = session.environment.get("weather", AsciiMapEnvironment.WeatherState.CLEAR)
	cc._is_ravine    = session.environment.get("is_ravine", false)
	cc._objective_slots = session.objective_slots

	# Add the player entity.
	var player_id: int = cc._create_entity(player_char, "", FACTION_PLAYER,
			session.entry_pos.x, session.entry_pos.y)
	cc._player_id = player_id

	# Add NPC entities from placements.
	var placements: Array = []
	if session.is_sortie():
		# Friendly units are also tracked.
		for p: Dictionary in session.placements.get("friendly", []):
			var friendly_char := cc._create_unit_character(p.get("unit_type", ""), p.get("seed", 0))
			cc._create_entity(friendly_char, p.get("unit_type", ""),
					FACTION_FRIENDLY, p.get("x", 0), p.get("y", 0))
		placements = session.placements.get("enemy", [])
	else:
		placements = session.placements

	for p: Dictionary in placements:
		var unit_type: String = p.get("unit_type", "SIMPLE_BANDIT")
		var npc_char := cc._create_unit_character(unit_type, p.get("seed", 0))
		var eid: int = cc._create_entity(npc_char, unit_type,
				FACTION_ENEMY, p.get("x", 0), p.get("y", 0))
		var es: EntityState = cc._entities[eid]
		es.is_sleeping    = p.get("is_sleeping", false)
		es.patrol_x       = p.get("x", 0)
		es.patrol_y       = p.get("y", 0)

	cc._initial_enemy_count = cc._count_living_enemies()
	return cc


# =============================================================================
# -- Unit character factory (s54.8 and s54.9 LOCKED stat blocks) --------------
# =============================================================================

## Creates an L5RCharacterData with traits/skills from the LOCKED GDD stat block.
## variance_seed: if nonzero, applies s56.10.0a individual variance (+1 to one trait/skill).
func _create_unit_character(unit_type: String, variance_seed: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = _next_id  # temporary; overwritten by _create_entity
	c.character_name = unit_type

	match unit_type:
		# --- s54.8 LOCKED ---
		"SIMPLE_BANDIT":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 3; c.willpower = 3
			c.agility = 3; c.intelligence = 2
			c.strength = 3; c.perception = 2
			c.void_ring = 2
			c.skills = {"Athletics": 2, "Defense": 1, "Hunting": 3, "Kenjutsu": 3}

		"EXPERIENCED_BANDIT":
			c.reflexes = 3; c.awareness = 2
			c.stamina = 3; c.willpower = 3
			c.agility = 4; c.intelligence = 3
			c.strength = 3; c.perception = 3
			c.void_ring = 3
			c.skills = {"Athletics": 3, "Knives": 3, "Kenjutsu": 4, "Stealth": 3, "Defense": 2}

		"BANDIT_LORD":
			c.reflexes = 4; c.awareness = 3
			c.stamina = 4; c.willpower = 4
			c.agility = 4; c.intelligence = 3
			c.strength = 4; c.perception = 4
			c.void_ring = 3
			c.skills = {"Kenjutsu": 5, "Kyujutsu": 4, "Defense": 3, "Athletics": 3}

		"BANDIT_RABBLE":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.skills = {"Bo": 1}  # farm tools — closest weapon skill

		"BANDIT_THUG":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 3; c.willpower = 3
			c.agility = 3; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.skills = {"Kenjutsu": 2, "Stealth": 1}

		"REBEL_PEASANT":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.skills = {"Bo": 1}

		"REBEL_ASHIGARU":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 2; c.willpower = 2
			c.agility = 3; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.armor_tn_bonus = 5  # ashigaru armor
			c.armor_reduction = 3
			c.skills = {"Polearms": 2, "Defense": 1}

		"REBEL_LEADER":
			c.reflexes = 2; c.awareness = 2
			c.stamina = 3; c.willpower = 3
			c.agility = 3; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.skills = {"Kenjutsu": 2, "Intimidation": 2}

		# --- s54.9 LOCKED ---
		"BAKEMONO_WARRIOR":
			c.reflexes = 3; c.awareness = 1
			c.stamina = 2; c.willpower = 2
			c.agility = 3; c.intelligence = 1
			c.strength = 2; c.perception = 2
			c.void_ring = 1
			c.armor_reduction = 3
			c.skills = {"Kenjutsu": 3, "Athletics": 2}

		"BAKEMONO_ARCHER":
			c.reflexes = 4; c.awareness = 1
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 1
			c.strength = 2; c.perception = 1
			c.void_ring = 1
			c.armor_reduction = 3
			# ATN override: the stat block gives ATN=25, but Ref=4 → 4×5+5=25 ✓
			c.skills = {"Kyujutsu": 2, "Stealth": 2}

		"BAKEMONO_SHAMAN":
			c.reflexes = 2; c.awareness = 1
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 2
			c.strength = 1; c.perception = 2
			c.void_ring = 1
			c.armor_reduction = 4
			c.skills = {"Stealth": 2}  # IR1 spellcaster; spell use not modeled in combat

		"BAKEMONO_SNEAK":
			c.reflexes = 3; c.awareness = 1
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 2
			c.strength = 1; c.perception = 3
			c.void_ring = 1
			c.armor_reduction = 3
			c.skills = {"Stealth": 4, "Knives": 3}

		"BAKEMONO_WARMONGER":
			c.reflexes = 3; c.awareness = 2
			c.stamina = 3; c.willpower = 3
			c.agility = 3; c.intelligence = 2
			c.strength = 3; c.perception = 2
			c.void_ring = 1
			c.armor_tn_bonus = 5  # ATN=25 vs computed Ref=3→20; difference = armor
			c.armor_reduction = 7
			c.skills = {"Kenjutsu": 3, "Athletics": 2}

		"TROLL":
			c.reflexes = 3; c.awareness = 1
			c.stamina = 5; c.willpower = 3
			c.agility = 3; c.intelligence = 3
			c.strength = 5; c.perception = 3
			c.void_ring = 1
			c.armor_reduction = 5
			c.skills = {"Jiujutsu": 3, "Heavy Weapons": 2, "Stealth": 4}

		"FREE_OGRE":
			c.reflexes = 3; c.awareness = 2
			c.stamina = 6; c.willpower = 3
			c.agility = 3; c.intelligence = 3
			c.strength = 6; c.perception = 2
			c.void_ring = 2
			c.armor_tn_bonus = 10  # ATN=30 vs Ref=3→20; natural armor/bulk
			c.armor_reduction = 15
			c.skills = {"Heavy Weapons": 4}

		"FREE_OGRE_LEADER":
			c.reflexes = 3; c.awareness = 3
			c.stamina = 6; c.willpower = 4
			c.agility = 3; c.intelligence = 3
			c.strength = 6; c.perception = 4
			c.void_ring = 2
			c.armor_tn_bonus = 10
			c.armor_reduction = 15
			c.skills = {"Heavy Weapons": 4, "Intimidation": 3}

		"FREE_OGRE_OVERLORD":
			c.reflexes = 4; c.awareness = 4
			c.stamina = 6; c.willpower = 5
			c.agility = 4; c.intelligence = 4
			c.strength = 7; c.perception = 4
			c.void_ring = 3
			c.armor_tn_bonus = 10
			c.armor_reduction = 25
			c.skills = {"Heavy Weapons": 5, "Intimidation": 3}

		_:
			# Fallback: generic human combatant at minimum stats.
			c.reflexes = 2; c.awareness = 2
			c.stamina = 2; c.willpower = 2
			c.agility = 2; c.intelligence = 2
			c.strength = 2; c.perception = 2
			c.void_ring = 2
			c.skills = {"Kenjutsu": 2}

	# s56.10.0a individual variance: +1 to one trait or skill, 30–40% chance.
	if variance_seed != 0 and (variance_seed % 10) < 4:
		_apply_individual_variance(c, unit_type, variance_seed)

	return c


## s56.10.0a: +1 to one appropriate trait or skill, capped at next tier.
func _apply_individual_variance(c: L5RCharacterData, unit_type: String, seed: int) -> void:
	var picks_trait: bool = (seed % 3) == 0
	if picks_trait:
		# +1 to a random trait (not void_ring).
		var trait_idx: int = (seed / 3) % 8
		match trait_idx:
			0: c.reflexes    = mini(c.reflexes    + 1, 5)
			1: c.awareness   = mini(c.awareness   + 1, 5)
			2: c.stamina     = mini(c.stamina     + 1, 5)
			3: c.willpower   = mini(c.willpower   + 1, 5)
			4: c.agility     = mini(c.agility     + 1, 5)
			5: c.intelligence= mini(c.intelligence+ 1, 5)
			6: c.strength    = mini(c.strength    + 1, 5)
			7: c.perception  = mini(c.perception  + 1, 5)
	else:
		# +1 to a skill from this unit's skill set.
		var skill_names: Array = c.skills.keys()
		if skill_names.is_empty():
			return
		var idx: int = (seed / 2) % skill_names.size()
		var sk: String = skill_names[idx]
		c.skills[sk] = mini(c.skills.get(sk, 0) + 1, 5)


# =============================================================================
# -- Entity management --------------------------------------------------------
# =============================================================================

func _create_entity(
		character: L5RCharacterData,
		unit_type: String,
		faction: int,
		px: int, py: int,
) -> int:
	var eid: int = _next_id
	_next_id += 1
	character.character_id = eid

	var es := EntityState.new()
	es.entity_id           = eid
	es.character           = character
	es.unit_type           = unit_type
	es.faction             = faction
	es.x                   = px
	es.y                   = py
	es.patrol_x            = px
	es.patrol_y            = py
	es.participant         = IndividualCombat.Participant.new()
	es.participant.character_id = eid
	es.investigation_style = INVESTIGATION_STYLE.get(unit_type, "professional")

	# Set creature wounds_dead override (s54.9).
	es.wounds_dead = _creature_wounds_dead(unit_type)

	_entities[eid] = es
	return eid


## Creature death threshold overrides from LOCKED stat blocks.
## Returns 0 for humans (use CharacterStats.is_dead()).
func _creature_wounds_dead(unit_type: String) -> int:
	match unit_type:
		"BAKEMONO_WARRIOR":    return 20
		"BAKEMONO_ARCHER":     return 18
		"BAKEMONO_SHAMAN":     return 18
		"BAKEMONO_SNEAK":      return 18
		"BAKEMONO_WARMONGER":  return 45
		"TROLL":               return 90
		"FREE_OGRE":           return 80
		"FREE_OGRE_LEADER":    return 90
		"FREE_OGRE_OVERLORD":  return 100
	return 0


## Returns true if an entity is dead.
func _is_entity_dead(es: EntityState) -> bool:
	if not es.is_alive:
		return true
	if es.wounds_dead > 0:
		return es.character.wounds_taken >= es.wounds_dead
	return CharacterStats.is_dead(es.character)


# =============================================================================
# -- Swift movement (s54.9: some creature types have enhanced movement) --------
# =============================================================================

## Movement budget for one NPC action (Simple Move = WR × 2 tiles).
## Swift N: adds N to Water Ring for movement computation per s54.9.
func _movement_budget(es: EntityState) -> int:
	var swift_bonus: int = _get_swift_bonus(es.unit_type)
	var water_ring: int = CharacterStats.get_ring_value(es.character, Enums.Ring.WATER)
	return MovementSystem.budget(water_ring + swift_bonus, MovementSystem.MoveAction.SIMPLE)


func _get_swift_bonus(unit_type: String) -> int:
	# s54.9 LOCKED: Swift 2 for Bakemono Warrior, Swift 2 for Bakemono Archer,
	# Swift 3 for Bakemono Sneak, Swift 2 for Bakemono Warmonger.
	match unit_type:
		"BAKEMONO_WARRIOR":  return 2
		"BAKEMONO_ARCHER":   return 2
		"BAKEMONO_SNEAK":    return 3
		"BAKEMONO_WARMONGER":return 2
	return 0


# =============================================================================
# -- Ground type → stealth TN (structural mapping) ----------------------------
# =============================================================================

## Returns the stealth TN for the given tile's ground surface (s56.6.3 LOCKED TNs).
## Tile → surface category mapping: structural routing, not a new mechanic.
func _stealth_tn_for_tile(tile: int) -> int:
	match tile:
		Enums.TileType.FLOOR_GRASS, Enums.TileType.FLOOR_MUD,
		Enums.TileType.FLOOR_SNOW, Enums.TileType.FLOOR_SAND,
		Enums.TileType.FLOOR_ASH:
			return STEALTH_TN_SOFT  # 10
		Enums.TileType.RUBBLE, Enums.TileType.CROPS:
			return STEALTH_TN_NOISY  # 20
		_:
			# Stone, wood, tatami, dirt → hard surface
			return STEALTH_TN_HARD  # 15


# =============================================================================
# -- Query helpers ------------------------------------------------------------
# =============================================================================

func get_entity(entity_id: int) -> EntityState:
	return _entities.get(entity_id)


func get_player() -> EntityState:
	return _entities.get(_player_id)


func get_all_entities() -> Array:
	return _entities.values()


func get_enemies_at(px: int, py: int) -> Array:
	var result: Array = []
	for es: EntityState in _entities.values():
		if es.faction == FACTION_ENEMY and es.is_alive and not _is_entity_dead(es) \
				and es.x == px and es.y == py:
			result.append(es)
	return result


func get_round() -> int:
	return _round


func is_mission_complete() -> bool:
	return _count_living_enemies() == 0


## Public wrapper: returns true if the entity with given ID is dead.
func is_entity_dead(entity_id: int) -> bool:
	var es: EntityState = _entities.get(entity_id)
	if es == null:
		return true
	return _is_entity_dead(es)


## Returns true if the player entity is dead or missing.
func is_player_dead() -> bool:
	var p: EntityState = get_player()
	if p == null:
		return true
	return _is_entity_dead(p)


## Returns the player's current map position.
func get_player_pos() -> Vector2i:
	var p: EntityState = get_player()
	if p == null:
		return Vector2i(-1, -1)
	return Vector2i(p.x, p.y)


## Returns all corpse tile positions (for UI rendering).
func get_corpse_positions() -> Array[Vector2i]:
	return _corpse_positions


## Returns display Dictionaries for all non-player entities.
## Keys: entity_id, x, y, unit_type, faction (String), is_alive, alert_state, morale_broken.
func get_entity_display_data() -> Array:
	var result: Array = []
	for es: EntityState in _entities.values():
		if es.faction == FACTION_PLAYER:
			continue
		result.append({
			"entity_id":    es.entity_id,
			"x":            es.x,
			"y":            es.y,
			"unit_type":    es.unit_type,
			"faction":      "friendly" if es.faction == FACTION_FRIENDLY else "enemy",
			"is_alive":     es.is_alive and not _is_entity_dead(es),
			"alert_state":  es.alert_state,
			"morale_broken": es.morale_broken,
		})
	return result


## Returns FoV-visible tiles from the player's position.
func get_visible_tiles() -> Dictionary:
	var player: EntityState = get_player()
	if player == null:
		return {}
	var radius: int = _fov_radius(player.character.perception, player.x, player.y)
	return FovSystem.compute_visible(player.x, player.y, radius, _map)


func _count_living_enemies() -> int:
	var count: int = 0
	for es: EntityState in _entities.values():
		if es.faction == FACTION_ENEMY and es.is_alive and not _is_entity_dead(es):
			count += 1
	return count


func _is_adjacent(ax: int, ay: int, bx: int, by: int) -> bool:
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and not (ax == bx and ay == by)


func _fov_radius(perception: int, x: int, y: int) -> int:
	var fov_mod: int = AsciiMapEnvironment.weather_to_fov_modifier(_weather)
	if _is_lookout_tile(x, y):
		return FovSystem.lookout_radius(perception, fov_mod)
	return FovSystem.effective_radius(perception, fov_mod)


func _is_lookout_tile(x: int, y: int) -> bool:
	var wws: Variant = _map.get("wall_walkways")
	if wws is Array:
		for ww: Dictionary in (wws as Array):
			if x >= ww.get("lx", -1) and x <= ww.get("rx", -1) \
					and y >= ww.get("ly", -1) and y <= ww.get("ry", -1):
				return true
	return false


## Returns the entity at the given tile, or null.
func _entity_at(px: int, py: int, exclude_id: int = -1) -> EntityState:
	for es: EntityState in _entities.values():
		if es.entity_id == exclude_id:
			continue
		if es.is_alive and not _is_entity_dead(es) and es.x == px and es.y == py:
			return es
	return null


# =============================================================================
# -- Player turn API ----------------------------------------------------------
# =============================================================================

## Attempt a normal (non-stealthy) player move or bump-to-attack.
## Returns a Dictionary describing what happened.
## Keys: "moved", "attacked", "opened_door", "exited", "blocked",
##       "target_id" (on attack), "attack_result" (on attack).
func try_move_player(dx: int, dy: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"blocked": true, "reason": "player_dead"}

	var tx: int = player.x + dx
	var ty: int = player.y + dy

	# Bounds check.
	if tx < 0 or ty < 0 or tx >= _map.width or ty >= _map.height:
		return {"blocked": true, "reason": "out_of_bounds"}

	var target_tile: int = _map.get_tile(tx, ty)

	# Closed door → bump opens it, player stays.
	if MovementSystem.is_closed_door(target_tile):
		_map.set_tile(tx, ty, MovementSystem.open_door(target_tile))
		# Door creak originates at the door tile, not the player's current position.
		_emit_noise(tx, ty, AsciiMapEnvironment.NoiseLevel.MODERATE)
		return {"opened_door": true, "door_x": tx, "door_y": ty}

	# Enemy in the target tile → bump-to-attack (checked before zone exit so an
	# enemy guarding the exit can be fought rather than the player slipping past).
	var target_es: EntityState = _entity_at(tx, ty)
	if target_es != null and target_es.faction == FACTION_ENEMY:
		var weapon: String = IndividualCombat.pick_best_weapon(player.character)
		var result: Dictionary = _resolve_melee_attack(player, target_es, weapon, 0)
		_pending_noise_events.append_array(result.get("morale_events", []))
		# Melee noise: MODERATE normally, LOUD if a shout (aggressive attacker).
		_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
		_player_stealth = false
		# Alert the target (it fights back next NPC turn).
		if target_es.is_alive and not _is_entity_dead(target_es):
			target_es.alert_state = AsciiMapEnvironment.AlertState.ALERT
			target_es.alert_rounds_lost = 0
			target_es.in_combat = true
			target_es.combat_target_id = player.entity_id
			target_es.noise_src_x = player.x
			target_es.noise_src_y = player.y
		return {
			"type":          "attacked",
			"attacked":      true,
			"target_id":     target_es.entity_id,
			"unit_type":     target_es.unit_type,
			"damage":        result.get("wounds_final", 0),
			"killed":        result.get("target_killed", false),
			"attack_result": result,
			"player_x":      player.x,
			"player_y":      player.y,
		}

	# Zone exit (only reachable if no enemy is standing on the tile).
	if target_tile == Enums.TileType.ZONE_EXIT:
		return {"exited": true, "exit_x": tx, "exit_y": ty}

	# Normal movement.
	var step: Dictionary = MovementSystem.check_step(_map, player.x, player.y, tx, ty)
	if not step.ok:
		return {"blocked": true, "reason": "impassable"}

	player.x = tx
	player.y = ty
	_player_stealth = false  # Normal move breaks stealth.

	# Walking makes QUIET noise.
	_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.QUIET)
	_check_body_discovery()
	return {"moved": true, "x": tx, "y": ty}


## Attempt a stealthy player move. Returns result including whether stealth was maintained.
func try_stealth_move(dx: int, dy: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"blocked": true, "reason": "player_dead"}

	var tx: int = player.x + dx
	var ty: int = player.y + dy

	if tx < 0 or ty < 0 or tx >= _map.width or ty >= _map.height:
		return {"blocked": true, "reason": "out_of_bounds"}

	var target_tile: int = _map.get_tile(tx, ty)
	if MovementSystem.is_closed_door(target_tile):
		# Stealth doesn't auto-open doors (would make noise).
		return {"blocked": true, "reason": "closed_door"}

	# Enemy in target tile while stealthy → stealth kill prompt (checked before zone
	# exit so an enemy guarding the exit is offered for stealth kill rather than the
	# player slipping past them).
	var target_es: EntityState = _entity_at(tx, ty)
	if target_es != null and target_es.faction == FACTION_ENEMY:
		return {"stealth_kill_available": true, "target_id": target_es.entity_id}

	# Zone exit (only reachable when the tile has no enemy on it).
	if target_tile == Enums.TileType.ZONE_EXIT:
		return {"exited": true, "exit_x": tx, "exit_y": ty}

	var step: Dictionary = MovementSystem.check_step(_map, player.x, player.y, tx, ty)
	if not step.ok:
		return {"blocked": true, "reason": "impassable"}

	# Stealth (Sneaking)/Agility roll vs ground surface TN.
	var ground_tn: int = _stealth_tn_for_tile(target_tile)
	var stealth_rank: int = player.character.skills.get("Stealth", 0)
	var wound_pen: int = CharacterStats.get_wound_penalty(player.character)
	# Mutation modifiers (s44): MASTER_OF_SHADOWS +taint_rank unkept to Stealth
	var stealth_mut: Dictionary = MutationSystem.get_skill_modifiers(player.character, "Stealth")
	# Advantage/disadvantage modifiers (s45): SILENT +1k0 to Stealth
	var stealth_adv: Dictionary = AdvantageSystem.get_skill_bonus(
		player.character, "Stealth", {"is_stealth": true}
	)
	var stealth_adv_tn: int = AdvantageSystem.get_tn_modifier(player.character, {"is_stealth": true})
	var roll_result: Dictionary = _dice.roll_check(
		player.character.agility + stealth_rank + stealth_mut["rolled"] + stealth_adv["rolled"],
		player.character.agility + stealth_mut["kept"] + stealth_adv["kept"],
		ground_tn, 0, wound_pen - stealth_adv_tn + (stealth_adv["free_raises"] * 5), stealth_rank > 0
	)

	player.x = tx
	player.y = ty
	_player_stealth = roll_result["success"]

	# Successful stealth move makes SILENT noise; failure makes QUIET.
	var noise_level: int = AsciiMapEnvironment.NoiseLevel.SILENT if roll_result["success"] \
			else AsciiMapEnvironment.NoiseLevel.QUIET
	_emit_noise(player.x, player.y, noise_level)
	_check_body_discovery()

	return {
		"moved": true,
		"x": tx, "y": ty,
		"stealth_maintained": roll_result["success"],
		"stealth_roll": roll_result["total"],
		"stealth_tn": ground_tn,
	}


## Execute a stealth kill on an adjacent target (s56.6.3 LOCKED).
## Target must be UNAWARE or SLEEPING and adjacent.
## Flat-footed ATN: 5 + armor_tn_bonus (Reflexes contribution removed, s56.6.3).
func execute_stealth_kill(target_id: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"success": false, "reason": "player_dead"}

	var target: EntityState = _entities.get(target_id)
	if target == null or _is_entity_dead(target):
		return {"success": false, "reason": "invalid_target"}
	if not _is_adjacent(player.x, player.y, target.x, target.y):
		return {"success": false, "reason": "not_adjacent"}
	# s56.6.3 LOCKED: stealth kill requires UNAWARE or SLEEPING target only.
	if target.alert_state >= AsciiMapEnvironment.AlertState.SUSPICIOUS:
		return {"success": false, "reason": "target_is_alert"}
	if target.faction != FACTION_ENEMY:
		return {"success": false, "reason": "not_an_enemy"}

	# Stealth (Ambush)/Agility to approach.
	var stealth_rank: int = player.character.skills.get("Stealth", 0)
	var wound_pen: int = CharacterStats.get_wound_penalty(player.character)
	var approach_tn: int = _stealth_tn_for_tile(_map.get_tile(target.x, target.y))
	if target.is_sleeping:
		approach_tn = maxi(5, approach_tn - SLEEPING_DETECTION_BONUS)  # easier approach vs sleeping
	# Mutation modifiers (s44): MASTER_OF_SHADOWS +taint_rank unkept to Stealth
	var stealth_mut_kill: Dictionary = MutationSystem.get_skill_modifiers(player.character, "Stealth")
	# Advantage/disadvantage modifiers (s45): SILENT +1k0 to Stealth
	var stealth_kill_adv: Dictionary = AdvantageSystem.get_skill_bonus(
		player.character, "Stealth", {"is_stealth": true}
	)
	var stealth_kill_adv_tn: int = AdvantageSystem.get_tn_modifier(player.character, {"is_stealth": true})
	var approach_roll: Dictionary = _dice.roll_check(
		player.character.agility + stealth_rank + stealth_mut_kill["rolled"] + stealth_kill_adv["rolled"],
		player.character.agility + stealth_mut_kill["kept"] + stealth_kill_adv["kept"],
		approach_tn, 0, wound_pen - stealth_kill_adv_tn + (stealth_kill_adv["free_raises"] * 5), stealth_rank > 0
	)

	if not approach_roll["success"]:
		# Approach failed → target wakes/alerts, normal combat.
		target.alert_state = AsciiMapEnvironment.AlertState.ALERT
		target.in_combat = true
		target.combat_target_id = player.entity_id
		_player_stealth = false  # Detected during approach — stealth broken.
		_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.LOUD)
		return {
			"success": false,
			"approach_failed": true,
			"approach_roll": approach_roll["total"],
			"approach_tn": approach_tn,
			"target_alerted": true,
		}

	# Flat-footed ATN: 5 + armor_tn_bonus (no Reflexes contribution, s56.6.3).
	var flat_atn: int = 5 + target.character.armor_tn_bonus
	var weapon: String = IndividualCombat.pick_best_weapon(player.character)
	var atk: Dictionary = IndividualCombat.resolve_attack(
		player.character, player.participant, weapon, flat_atn, 0, _dice
	)

	if not atk.get("hit", false):
		# Missed even a flat-footed target → Loud noise, target alarms.
		target.alert_state = AsciiMapEnvironment.AlertState.ALERT
		target.in_combat = true
		target.combat_target_id = player.entity_id
		_player_stealth = false  # Attack blown — stealth broken.
		_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.LOUD)
		return {
			"success": false,
			"attack_failed": true,
			"attack_roll": atk["roll"],
			"flat_atn": flat_atn,
			"target_alerted": true,
		}

	# Hit → resolve damage.
	var dmg: Dictionary = IndividualCombat.resolve_damage(
		player.character, weapon, 0, 0, _dice, player.participant
	)
	var wounds: Dictionary = WoundSystem.apply_damage(
		target.character, dmg["raw_damage"], target.character.armor_reduction
	)

	var target_killed: bool = _is_entity_dead(target)

	if target_killed:
		target.is_alive = false
		_enemy_deaths_total += 1
		# s56.6.3 LOCKED: death on first hit → Quiet noise.
		_add_corpse(target.x, target.y)
		_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.QUIET)
		var morale_events: Array = _check_morale()
		_pending_noise_events.append_array(morale_events)
	else:
		# s56.6.3 LOCKED: survival → Loud noise + immediate propagation.
		target.alert_state = AsciiMapEnvironment.AlertState.ALERT
		target.in_combat = true
		target.combat_target_id = player.entity_id
		_player_stealth = false  # Target survived and is now alert — stealth is broken.
		_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.LOUD)

	return {
		"type":          "stealth_kill",
		"success":       true,
		"unit_type":     target.unit_type,
		"approach_roll": approach_roll["total"],
		"approach_tn":   approach_tn,
		"attack_roll":   atk["roll"],
		"flat_atn":      flat_atn,
		"raw_damage":    dmg["raw_damage"],
		"wounds_applied": wounds["final_damage"],
		"target_killed": target_killed,
		"target_id":     target_id,
	}


## Execute a direct attack on a target (target must be adjacent).
func execute_player_attack(target_id: int, weapon_name: String = "", raises: int = 0) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"success": false, "reason": "player_dead"}

	var target: EntityState = _entities.get(target_id)
	if target == null or _is_entity_dead(target):
		return {"success": false, "reason": "invalid_target"}
	if not _is_adjacent(player.x, player.y, target.x, target.y):
		return {"success": false, "reason": "not_adjacent"}

	var weapon: String = weapon_name if weapon_name != "" \
			else IndividualCombat.pick_best_weapon(player.character)
	var result: Dictionary = _resolve_melee_attack(player, target, weapon, raises)
	_pending_noise_events.append_array(result.get("morale_events", []))

	# Combat noise.
	_emit_noise(player.x, player.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
	_player_stealth = false

	# Make sure the target is alerted and knows who it's fighting.
	# in_combat and combat_target_id must be set even if already ALERT.
	if target.alert_state != AsciiMapEnvironment.AlertState.ALERT:
		target.alert_state = AsciiMapEnvironment.AlertState.ALERT
	target.in_combat = true
	target.combat_target_id = player.entity_id

	return {
		"type":          "attacked",
		"attacked":      true,
		"target_id":     target.entity_id,
		"unit_type":     target.unit_type,
		"damage":        result.get("wounds_final", 0),
		"killed":        result.get("target_killed", false),
		"attack_result": result,
		"player_x":      player.x,
		"player_y":      player.y,
	}


## Wait one action (player passes their turn).
func wait_player() -> Dictionary:
	_player_stealth = false
	# SILENT wait: no noise generated; discard any stale unrelated signals so
	# advance_npc_turns starts from a clean slate.
	_pending_noise_events.clear()
	return {"waited": true, "round": _round}


# =============================================================================
# -- Melee attack resolution (shared) ----------------------------------------
# =============================================================================

func _resolve_melee_attack(
		attacker_es: EntityState,
		defender_es: EntityState,
		weapon: String,
		raises: int,
) -> Dictionary:
	var armor_tn: int = IndividualCombat.get_armor_tn(
		defender_es.character, defender_es.participant, _dice
	)
	var atk: Dictionary = IndividualCombat.resolve_attack(
		attacker_es.character, attacker_es.participant,
		weapon, armor_tn, raises, _dice
	)

	var dmg_dict: Dictionary = {}
	var wounds_dict: Dictionary = {}
	var killed: bool = false
	var morale_events: Array = []

	if atk.get("hit", false):
		dmg_dict = IndividualCombat.resolve_damage(
			attacker_es.character, weapon, 0, 0, _dice, attacker_es.participant
		)
		var reduction: int = defender_es.character.armor_reduction
		wounds_dict = WoundSystem.apply_damage(defender_es.character, dmg_dict["raw_damage"], reduction)
		killed = _is_entity_dead(defender_es)
		if killed:
			defender_es.is_alive = false
			if defender_es.faction == FACTION_ENEMY:
				_enemy_deaths_total += 1
				_add_corpse(defender_es.x, defender_es.y)
				morale_events = _check_morale()

	return {
		"hit":           atk.get("hit", false),
		"attack_roll":   atk.get("roll", 0),
		"armor_tn":      armor_tn,
		"raw_damage":    dmg_dict.get("raw_damage", 0),
		"wounds_final":  wounds_dict.get("final_damage", 0),
		"target_killed": killed,
		"attacker_id":   attacker_es.entity_id,
		"defender_id":   defender_es.entity_id,
		"weapon":        weapon,
		"raises":        raises,
		"morale_events": morale_events,
	}


# =============================================================================
# -- NPC turn processing ------------------------------------------------------
# =============================================================================

## Advance all NPC turns for the current round.
## Returns an Array of event Dictionaries (for UI feedback).
func advance_npc_turns() -> Array:
	_round += 1
	var events: Array = []

	# Flush noise detection events that fired during the player's action.
	events.append_array(_pending_noise_events)
	_pending_noise_events.clear()

	# Roll initiative for all living non-player entities.
	var turn_order: Array = _build_initiative_order()

	for eid: int in turn_order:
		var es: EntityState = _entities.get(eid)
		if es == null or es.faction == FACTION_PLAYER or es.faction == FACTION_FRIENDLY:
			continue
		if not es.is_alive or _is_entity_dead(es):
			continue
		es.move_budget_used = 0
		var turn_events: Array = _npc_turn(es)
		events.append_array(turn_events)
		# Flush any noise events emitted during NPC turns.
		events.append_array(_pending_noise_events)
		_pending_noise_events.clear()

	# After all NPCs move, player body-discovery check.
	_check_body_discovery()
	events.append_array(_pending_noise_events)
	_pending_noise_events.clear()

	# Terminal condition notifications — emitted once per session.
	if not _player_died_notified and is_player_dead():
		_player_died_notified = true
		events.append({"type": "player_died"})
	if not _mission_complete_notified and is_mission_complete():
		_mission_complete_notified = true
		events.append({"type": "mission_complete"})

	return events


func _build_initiative_order() -> Array:
	var pairs: Array = []
	for eid: int in _entities.keys():
		var es: EntityState = _entities[eid]
		if es.faction == FACTION_PLAYER or es.faction == FACTION_FRIENDLY \
				or not es.is_alive or _is_entity_dead(es):
			continue
		var score: int = IndividualCombat.roll_initiative(
			es.character, es.participant, _dice, IndividualCombat.pick_best_weapon(es.character)
		)
		pairs.append({"id": eid, "score": score})

	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)
	var result: Array = []
	for p: Dictionary in pairs:
		result.append(p["id"])
	return result


## Process one NPC's turn. Returns an Array of event Dicts.
func _npc_turn(es: EntityState) -> Array:
	var events: Array = []

	# Morale-broken → flee.
	if es.morale_broken:
		var flee_ev: Dictionary = _npc_flee(es)
		if not flee_ev.is_empty():
			events.append(flee_ev)
		return events

	# Detect player via FoV (all alert states).
	var player_seen: bool = _npc_can_see_player(es)
	if player_seen and es.alert_state != AsciiMapEnvironment.AlertState.FLEEING:
		if es.alert_state == AsciiMapEnvironment.AlertState.UNAWARE:
			es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS
			es.phase_rounds_left = SUSPICIOUS_SEARCH_ROUNDS
			events.append({"type": "player_noticed", "entity_id": es.entity_id, "unit_type": es.unit_type})
		elif es.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS:
			es.alert_state = AsciiMapEnvironment.AlertState.ALERT
			es.alert_rounds_lost = 0
			events.append({"type": "escalated_to_alert", "entity_id": es.entity_id, "unit_type": es.unit_type})
		var player: EntityState = get_player()
		if player != null:
			es.noise_src_x = player.x
			es.noise_src_y = player.y

	# Per-state behavior.
	match es.alert_state:
		AsciiMapEnvironment.AlertState.UNAWARE:
			var ev: Dictionary = _npc_patrol(es)
			if not ev.is_empty():
				events.append(ev)

		AsciiMapEnvironment.AlertState.SUSPICIOUS:
			var ev: Dictionary = _npc_investigate(es)
			if not ev.is_empty():
				events.append(ev)

		AsciiMapEnvironment.AlertState.ALERT:
			if es.investigation_style == "caller" and not es.alarm_sounded:
				# Shugenja / non-investigator: sound alarm immediately.
				var alarm_ev: Dictionary = _raise_alarm(es)
				events.append(alarm_ev)
			else:
				var ev: Dictionary = _npc_pursue_and_attack(es)
				if not ev.is_empty():
					events.append(ev)

				# Re-check after potential movement — NPC may have stepped into LOS.
				if player_seen or _npc_can_see_player(es):
					es.alert_rounds_lost = 0
				else:
					es.alert_rounds_lost += 1
					if es.alert_rounds_lost >= ALERT_ALARM_ROUNDS and not es.alarm_sounded:
						var alarm_ev: Dictionary = _raise_alarm(es)
						events.append(alarm_ev)

	return events


# =============================================================================
# -- NPC patrol (UNAWARE) -----------------------------------------------------
# =============================================================================

func _npc_patrol(es: EntityState) -> Dictionary:
	# Simple: stay on patrol post (no path currently).
	# Future: could implement back-and-forth patrol between two waypoints.
	return {}


# =============================================================================
# -- NPC investigate (SUSPICIOUS) ---------------------------------------------
# =============================================================================

func _npc_investigate(es: EntityState) -> Dictionary:
	var moved: bool = false
	# Search phase (prl > 0): move toward last heard noise position.
	# Return phase (prl <= 0): move toward patrol post. Never both in one turn.
	if es.phase_rounds_left > 0:
		if es.noise_src_x >= 0 and es.noise_src_y >= 0:
			moved = _npc_move_toward(es, es.noise_src_x, es.noise_src_y, _investigation_move_budget(es))
	else:
		moved = _npc_move_toward(es, es.patrol_x, es.patrol_y, _investigation_move_budget(es))

	# After moving: check if the player came into view (move-into-LOS case that
	# _npc_turn's pre-move detection block could not catch). Generate event here.
	if _npc_can_see_player(es):
		es.alert_state = AsciiMapEnvironment.AlertState.ALERT
		es.alert_rounds_lost = 0
		var player: EntityState = get_player()
		if player != null:
			es.noise_src_x = player.x
			es.noise_src_y = player.y
		return {"type": "escalated_to_alert", "entity_id": es.entity_id, "unit_type": es.unit_type}

	# Tick down the phase counter.
	es.phase_rounds_left -= 1
	if es.phase_rounds_left <= -SUSPICIOUS_RETURN_ROUNDS:
		# Return phase exhausted → back to UNAWARE.
		es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE
		es.noise_src_x = -1
		es.noise_src_y = -1
		es.phase_rounds_left = 0
		return {"type": "returned_to_unaware", "entity_id": es.entity_id}

	return {"type": "investigating", "entity_id": es.entity_id, "moved": moved}


func _investigation_move_budget(es: EntityState) -> int:
	match es.investigation_style:
		"timid":
			# s56.6.3 LOCKED: half speed.
			return _movement_budget(es) / 2
		"cautious", "professional", "aggressive", "caller":
			return _movement_budget(es)
	return _movement_budget(es)


# =============================================================================
# -- NPC pursue and attack (ALERT) -------------------------------------------
# =============================================================================

func _npc_pursue_and_attack(es: EntityState) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {}

	# If adjacent → attack.
	if _is_adjacent(es.x, es.y, player.x, player.y):
		var weapon: String = IndividualCombat.pick_best_weapon(es.character)
		var attack_result: Dictionary = _resolve_melee_attack(es, player, weapon, 0)
		_emit_noise(es.x, es.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
		# Aggressive style: shout on attack.
		if es.investigation_style == "aggressive":
			_emit_noise(es.x, es.y, AsciiMapEnvironment.NoiseLevel.LOUD)
		es.in_combat = true
		return {
			"type":          "npc_attacked",
			"entity_id":     es.entity_id,
			"target_id":     player.entity_id,
			"unit_type":     es.unit_type,
			"damage":        attack_result.get("wounds_final", 0),
			"player_killed": attack_result.get("target_killed", false),
			"attack_result": attack_result,
		}

	# Otherwise move toward player.
	var budget: int = _movement_budget(es)
	# Aggressive style: double speed on charge (structural: full-move in L5R = WR × 4).
	if es.investigation_style == "aggressive":
		var water_ring: int = CharacterStats.get_ring_value(es.character, Enums.Ring.WATER)
		var swift: int = _get_swift_bonus(es.unit_type)
		budget = MovementSystem.budget(water_ring + swift, MovementSystem.MoveAction.FULL_MOVE)

	var moved: bool = _npc_move_toward(es, player.x, player.y, budget)

	# After moving, check adjacency again.
	if _is_adjacent(es.x, es.y, player.x, player.y):
		var weapon: String = IndividualCombat.pick_best_weapon(es.character)
		var attack_result: Dictionary = _resolve_melee_attack(es, player, weapon, 0)
		_emit_noise(es.x, es.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
		# Aggressive style: shout on charge-attack.
		if es.investigation_style == "aggressive":
			_emit_noise(es.x, es.y, AsciiMapEnvironment.NoiseLevel.LOUD)
		es.in_combat = true
		return {
			"type":          "npc_attacked",
			"entity_id":     es.entity_id,
			"target_id":     player.entity_id,
			"unit_type":     es.unit_type,
			"damage":        attack_result.get("wounds_final", 0),
			"player_killed": attack_result.get("target_killed", false),
			"attack_result": attack_result,
			"moved_first":   moved,
		}

	return {"type": "npc_moving", "entity_id": es.entity_id, "moved": moved}


# =============================================================================
# -- NPC flee (morale broken) -------------------------------------------------
# =============================================================================

func _npc_flee(es: EntityState) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {}
	# Move away from player.
	var away_x: int = es.x + signi(es.x - player.x)
	var away_y: int = es.y + signi(es.y - player.y)
	away_x = clampi(away_x, 0, _map.width - 1)
	away_y = clampi(away_y, 0, _map.height - 1)

	var step: Dictionary = MovementSystem.check_step(_map, es.x, es.y, away_x, away_y)
	if step.ok:
		es.x = away_x
		es.y = away_y
		# Fled through a zone exit → remove from combat permanently.
		if step.get("is_exit", false):
			es.is_alive = false
			return {"type": "npc_fled", "entity_id": es.entity_id, "unit_type": es.unit_type}
	return {"type": "npc_fleeing", "entity_id": es.entity_id, "unit_type": es.unit_type}


# =============================================================================
# -- BFS movement toward target -----------------------------------------------
# =============================================================================

## Move es toward (tx, ty) using at most budget tiles. Returns true if moved.
func _npc_move_toward(es: EntityState, tx: int, ty: int, budget: int) -> bool:
	if budget <= 0:
		return false
	var path: Array = _bfs_path(es.x, es.y, tx, ty)
	if path.is_empty():
		return false

	var moved: bool = false
	var remaining: int = budget
	for step_vec: Vector2i in path:
		if remaining <= 0:
			break
		var tile: int = _map.get_tile(step_vec.x, step_vec.y)
		# Auto-open doors in path.
		if MovementSystem.is_closed_door(tile):
			_map.set_tile(step_vec.x, step_vec.y, MovementSystem.open_door(tile))
			# Door creak originates at the door tile, not the NPC's current position.
			_emit_noise(step_vec.x, step_vec.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
			# Door opening costs movement.
			remaining -= 1
			continue
		var cost: int = MovementSystem.terrain_cost(tile)
		if cost == 0:
			break
		if remaining < cost:
			break
		# Check no other entity is at that tile.
		if _entity_at(step_vec.x, step_vec.y, es.entity_id) != null:
			break
		es.x = step_vec.x
		es.y = step_vec.y
		remaining -= cost
		moved = true

	return moved


## BFS from (sx, sy) to (tx, ty) on the map. Returns path excluding start.
func _bfs_path(sx: int, sy: int, tx: int, ty: int) -> Array:
	if sx == tx and sy == ty:
		return []

	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array = [Vector2i(sx, sy)]
	visited[Vector2i(sx, sy)] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.x == tx and current.y == ty:
			return _reconstruct_path(came_from, Vector2i(sx, sy), current)

		for dir: Vector2i in [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		]:
			var nx: int = current.x + dir.x
			var ny: int = current.y + dir.y
			var nv: Vector2i = Vector2i(nx, ny)
			if nx < 0 or ny < 0 or nx >= _map.width or ny >= _map.height:
				continue
			if visited.has(nv):
				continue
			var tile: int = _map.get_tile(nx, ny)
			# Treat closed doors as passable (NPC will open them).
			if MovementSystem.terrain_cost(tile) == 0 and not MovementSystem.is_closed_door(tile):
				continue
			visited[nv] = true
			came_from[nv] = current
			queue.append(nv)

	return []  # No path found.


func _reconstruct_path(came_from: Dictionary, start: Vector2i, end: Vector2i) -> Array:
	var path: Array = []
	var current: Vector2i = end
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path


# =============================================================================
# -- Noise emission and detection ---------------------------------------------
# =============================================================================

## Emit noise at position (sx, sy) and trigger detection checks for all
## UNAWARE/SUSPICIOUS enemies within propagation range.
func _emit_noise(sx: int, sy: int, noise_level: int) -> void:
	if noise_level == AsciiMapEnvironment.NoiseLevel.SILENT:
		return

	var reaches: Array = NoiseSystem.compute_noise_reaches(
		_map, sx, sy, noise_level, _weather, _is_ravine
	)

	var tn: int = NOISE_DETECTION_TN.get(noise_level, 0)

	for es: EntityState in _entities.values():
		if es.faction == FACTION_PLAYER:
			continue
		if not es.is_alive or _is_entity_dead(es):
			continue
		if es.alert_state == AsciiMapEnvironment.AlertState.ALERT:
			continue  # Already alert.

		var es_pos: Vector2i = Vector2i(es.x, es.y)

		# Very Loud = automatic (TN 0).
		var detected: bool = false
		if noise_level == AsciiMapEnvironment.NoiseLevel.VERY_LOUD:
			detected = true
		elif reaches.has(es_pos):
			# Make a Perception/Investigation detection roll.
			var bonus: int = SUSPICIOUS_SCAN_BONUS if es.alert_state == \
					AsciiMapEnvironment.AlertState.SUSPICIOUS else 0
			var sleep_pen: int = SLEEPING_DETECTION_BONUS if es.is_sleeping else 0
			var combat_pen: int = COMBAT_DETECTION_BONUS if es.in_combat else 0
			var effective_tn: int = tn + sleep_pen + combat_pen

			var perc: int = es.character.perception
			var invest: int = es.character.skills.get("Investigation", 0)
			var wound_pen_npc: int = CharacterStats.get_wound_penalty(es.character)
			var inv_mut: Dictionary = MutationSystem.get_skill_modifiers(es.character, "Investigation")
			# Advantage/disadvantage modifiers (s45): CONSUMED Perfection, etc.
			var is_sch_inv: bool = NPCAdvancement.get_school_skills(es.character).has("Investigation")
			var adv_inv: Dictionary = AdvantageSystem.get_skill_bonus(
				es.character, "Investigation", {"is_school_skill": is_sch_inv})
			var adv_inv_tn: int = AdvantageSystem.get_tn_modifier(es.character, {})
			var rolled: int = perc + invest + bonus + adv_inv["rolled"] + inv_mut["rolled"]
			var kept: int = perc + adv_inv["kept"] + inv_mut["kept"]
			var inv_flat: int = adv_inv["free_raises"] * 5 - adv_inv_tn + wound_pen_npc
			var roll: Dictionary = _dice.roll_check(rolled, kept, effective_tn, 0, inv_flat, invest > 0)
			detected = roll["success"]

		if detected:
			es.is_sleeping = false
			if es.alert_state == AsciiMapEnvironment.AlertState.UNAWARE:
				es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS
				es.phase_rounds_left = SUSPICIOUS_SEARCH_ROUNDS
				_pending_noise_events.append({
					"type": "noise_detected",
					"entity_id": es.entity_id,
					"unit_type": es.unit_type,
				})
			# s56.6.3 LOCKED: Suspicious→Alert on Loud or Very Loud noise.
			elif es.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS \
					and (noise_level == AsciiMapEnvironment.NoiseLevel.LOUD \
					or noise_level == AsciiMapEnvironment.NoiseLevel.VERY_LOUD):
				es.alert_state = AsciiMapEnvironment.AlertState.ALERT
				es.alert_rounds_lost = 0
				_pending_noise_events.append({
					"type": "escalated_to_alert",
					"entity_id": es.entity_id,
					"unit_type": es.unit_type,
				})
			es.noise_src_x = sx
			es.noise_src_y = sy


# =============================================================================
# -- Body discovery (s56.6.3 LOCKED) ------------------------------------------
# =============================================================================

## Automatic ALERT for any enemy whose vision radius includes a corpse tile.
## Queues "body_spotted" events into _pending_noise_events for UI feedback.
func _check_body_discovery() -> void:
	if _corpse_positions.is_empty():
		return

	for es: EntityState in _entities.values():
		if es.faction == FACTION_PLAYER or es.faction == FACTION_FRIENDLY:
			continue
		if not es.is_alive or _is_entity_dead(es):
			continue
		if es.alert_state == AsciiMapEnvironment.AlertState.ALERT:
			continue

		var perc: int = es.character.perception
		var radius: int = _fov_radius(perc, es.x, es.y)
		var visible: Dictionary = FovSystem.compute_visible(es.x, es.y, radius, _map)

		for corpse_pos: Vector2i in _corpse_positions:
			if visible.has(corpse_pos):
				# Automatic ALERT (s56.6.3 LOCKED).
				es.alert_state = AsciiMapEnvironment.AlertState.ALERT
				es.alert_rounds_lost = 0
				es.noise_src_x = corpse_pos.x
				es.noise_src_y = corpse_pos.y
				_pending_noise_events.append({
					"type":       "body_spotted",
					"entity_id":  es.entity_id,
					"unit_type":  es.unit_type,
					"corpse_x":   corpse_pos.x,
					"corpse_y":   corpse_pos.y,
				})
				break


func _add_corpse(cx: int, cy: int) -> void:
	var pos: Vector2i = Vector2i(cx, cy)
	if not _corpse_positions.has(pos):
		_corpse_positions.append(pos)


# =============================================================================
# -- FoV detection (NPC sees player) -----------------------------------------
# =============================================================================

func _npc_can_see_player(es: EntityState) -> bool:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return false
	if _player_stealth:
		# Player in stealth: enemy must beat stealth with Investigation/Perception.
		# (Stealth roll success was already checked; enemy gets standard FoV check only.)
		return false  # Stealth suppresses NPC detection for this round.

	var perc: int = es.character.perception
	var radius: int = _fov_radius(perc, es.x, es.y)
	return FovSystem.is_visible(es.x, es.y, player.x, player.y, radius, _map)


# =============================================================================
# -- Morale (s54.8 LOCKED) ----------------------------------------------------
# =============================================================================

## Check morale for all living enemies. Returns events for newly broken units.
func _check_morale() -> Array:
	if _initial_enemy_count == 0:
		return []

	var death_fraction: float = float(_enemy_deaths_total) / float(_initial_enemy_count)
	var events: Array = []

	for es: EntityState in _entities.values():
		if es.faction != FACTION_ENEMY:
			continue
		if not es.is_alive or _is_entity_dead(es):
			continue
		if es.morale_broken:
			continue
		if MORALE_UNBREAKABLE.has(es.unit_type):
			continue  # s54.8 LOCKED: REBEL_LEADER never breaks.

		var threshold: float = MORALE_THRESHOLDS.get(es.unit_type, 0.0)
		if threshold > 0.0 and death_fraction >= threshold:
			es.morale_broken = true
			es.alert_state = AsciiMapEnvironment.AlertState.FLEEING
			events.append({"type": "morale_broken", "entity_id": es.entity_id, "unit_type": es.unit_type})

	return events


# =============================================================================
# -- Alarm (s56.6.3 LOCKED) ---------------------------------------------------
# =============================================================================

## Raise a general alarm: immediately sets ALL living non-fleeing enemies to ALERT.
## s56.6.3 LOCKED: the alarm is not a noise event; it is a map-wide command that
## bypasses the two-step noise→detect→escalate chain.
func _raise_alarm(source: EntityState) -> Dictionary:
	source.alarm_sounded = true
	for es: EntityState in _entities.values():
		if es.faction == FACTION_PLAYER or es.faction == FACTION_FRIENDLY:
			continue
		if not es.is_alive or _is_entity_dead(es):
			continue
		if es.alert_state == AsciiMapEnvironment.AlertState.FLEEING:
			continue
		# Mark every entity as alarm_sounded so none can re-raise the alarm later.
		es.alarm_sounded = true
		if es.alert_state != AsciiMapEnvironment.AlertState.ALERT:
			es.alert_state = AsciiMapEnvironment.AlertState.ALERT
			es.alert_rounds_lost = 0
			es.noise_src_x = source.x
			es.noise_src_y = source.y
			es.is_sleeping = false
	return {"type": "alarm_raised", "entity_id": source.entity_id}
