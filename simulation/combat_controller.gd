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
# -- Disguise / perception-masking (s33/s36, owner-authorized 2026-06-21) ------
# -- Illusion disguise spells let a shugenja PC pass enemy guards in the
# -- stealth approach phase. See-through = Contested Investigation/Perception
# -- (guard) vs Spellcraft/Air (caster) — the GDD's illusion-detection pattern
# -- (seeking_the_way / garbled_tongue). The owner's "harder disguise adds a
# -- bonus" ruling is realized via the spell's own GDD Mastery Level, so no
# -- flat magnitude is invented. the_mirrors_smile (Water 4, a real flesh
# -- change rather than an illusion) has the highest ML, so it is hardest to
# -- see through.
# =============================================================================
const DISGUISE_SPELLS: Array[String] = ["hidden_visage", "mask_of_wind", "the_mirrors_smile"]


# =============================================================================
# -- More illusion / perception spells (s33, owner-authorized 2026-06-21) ------
# -- heart_betrays_eyes: target one guard; their next sighting of the PC is
# --   fooled unless they pass Investigation vs the caster's Air x5 (GDD TN).
# -- quiescence_of_air: a stationary silence sphere — no sound crosses it in
# --   either direction, and a character inside gains 2 Stealth Free Raises.
# -- by_the_light_of_the_moon: reveals HIDDEN traps in the area.
# -- All values are GDD-given (no invented magnitude).
# =============================================================================
const HEART_BETRAYS_RANGE_TILES: int = 10       # GDD 50' / 5
const HEART_BETRAYS_ROUNDS: int = 3             # GDD Duration: three rounds
const QUIESCENCE_RADIUS_TILES: int = 3          # GDD 30' diameter -> 3-tile radius
const QUIESCENCE_ROUNDS: int = 10               # GDD Duration: 10 Rounds
const QUIESCENCE_STEALTH_FREE_RAISES: int = 2   # GDD: 2 Free Raises on Stealth
const MOONLIGHT_REVEAL_RADIUS_TILES: int = 4    # GDD 20' radius / 5
const KAMIS_WHISPER_RANGE_TILES: int = 10       # GDD 50' / 5


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

	## -- Disguise / perception-masking (s33/s36 illusion spells) --------------
	## Active disguise spell id ("" = none). Carried by the PLAYER entity only.
	var disguise_spell_id:    String = ""
	## Caster Spellcraft rank + Air ring, frozen at cast (the see-through pool).
	var disguise_spellcraft:  int = 0
	var disguise_air:         int = 0
	## Spell Mastery Level — the owner-ruled "harder disguise adds a bonus",
	## realized via the spell's own GDD value (no invented magnitude).
	var disguise_resist_bonus: int = 0
	## Per-guard see-through outcome: entity_id -> true (penetrated) / false
	## (fooled). Absence = not yet evaluated. Reset on each fresh disguise.
	var disguise_seethrough:  Dictionary = {}
	## -- seeking_the_way (s33 Air 4): a false trail hides the caster's tracks.
	## Carried by the PLAYER entity. Frozen Spellcraft/Air + ML resist (no invented
	## magnitude). Per-guard misdirect outcome cache: entity_id -> true (fooled) /
	## false (skilled tracker saw through). Reset on each fresh cast.
	var seeking_the_way_active: bool = false
	var seeking_spellcraft:     int = 0
	var seeking_air:            int = 0
	var seeking_resist_bonus:   int = 0
	var seeking_seethrough:     Dictionary = {}
	## -- heart_betrays_eyes (s33): a one-shot, expiring "next sighting fooled"
	## charge placed ON this guard. Expiry round (-1 = none) + frozen caster Air.
	var heart_betrays_until_round: int = -1
	var heart_betrays_air:        int = 0


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

## Active quiescence_of_air silence spheres: {cx, cy, radius, expiry_round}.
var _silence_zones: Array[Dictionary] = []

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

## Combat mode latch (GDD s40.x). False = real-time exploration; true =
## turn-based combat. Latches true on first hostile contact (an enemy reaching
## the ALERT state) and only returns to false through a successful End Combat
## (no aware hostiles remaining + unanimous consent of present PCs).
var _turn_based: bool = false

## End Combat consent state (GDD s40.x). When a PC proposes ending combat and
## no aware hostiles remain, every present, living PC must agree before the
## zone returns to real-time. Keyed by PC entity_id → true (agreed).
var _end_combat_pending: bool = false
var _end_combat_consent: Dictionary = {}

## Last combat mode reported by poll_mode_changed(). Lets the view fire a
## combat_mode_changed signal on the real-time ↔ turn-based transition instead
## of polling every frame.
var _last_reported_mode: bool = false


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
			c.skills = {"Staves": 1}  # farm tools — closest weapon skill (bo uses the Staves skill)

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
			c.skills = {"Staves": 1}

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
		Enums.TileType.FLOOR_GRASS, Enums.TileType.FLOOR_MUD, Enums.TileType.FLOOR_SNOW, Enums.TileType.FLOOR_SAND, Enums.TileType.FLOOR_ASH:
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


# =============================================================================
# -- Combat mode & End Combat (GDD s40.x) -------------------------------------
# =============================================================================

## True when the zone is in turn-based combat mode, false when in real-time
## exploration. Per GDD s40.x, the zone latches into turn-based mode the instant
## a hostile contact occurs (any living enemy reaching the ALERT state) and stays
## there until a successful End Combat. Reading this lazily latches the engage
## trigger so callers never have to poll a separate refresh step.
func is_turn_based() -> bool:
	if _turn_based:
		return true
	for es: EntityState in _entities.values():
		if es.faction == FACTION_ENEMY and es.is_alive and not _is_entity_dead(es) \
				and es.alert_state == AsciiMapEnvironment.AlertState.ALERT:
			_turn_based = true
			return true
	return false


## Returns true exactly once after the combat mode (real-time ↔ turn-based)
## changes value. Evaluates the current mode (forcing the engage latch) and
## compares it to the last reported value, so it is correct regardless of call
## order. The view calls this after each action to fire combat_mode_changed on
## the transition rather than polling every frame.
func poll_mode_changed() -> bool:
	var current: bool = is_turn_based()
	if current == _last_reported_mode:
		return false
	_last_reported_mode = current
	return true


## Entity IDs of enemies that count as "still hostile" for End Combat (GDD s40.x):
## alive and aware (Suspicious or Alert). Unaware, Fleeing, and dead enemies do
## not block ending.
func get_active_hostiles() -> Array[int]:
	var out: Array[int] = []
	for es: EntityState in _entities.values():
		if es.faction != FACTION_ENEMY or not es.is_alive or _is_entity_dead(es):
			continue
		if es.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS \
				or es.alert_state == AsciiMapEnvironment.AlertState.ALERT:
			out.append(es.entity_id)
	return out


## True if any aware hostile enemy remains (End Combat is blocked while true).
func has_active_hostiles() -> bool:
	return not get_active_hostiles().is_empty()


## Entity IDs of present (living) player-characters. These are the PCs whose
## unanimous consent is required to End Combat. Offline/absent PCs are not on
## the map and so are naturally excluded.
func get_present_pc_ids() -> Array[int]:
	var out: Array[int] = []
	for es: EntityState in _entities.values():
		if es.faction == FACTION_PLAYER and es.is_alive and not _is_entity_dead(es):
			out.append(es.entity_id)
	return out


## A PC proposes ending combat. Blocked while aware hostiles remain (GDD s40.x).
## On success, opens a consent poll; every present PC must then agree via
## register_end_combat_consent(). Returns:
##   {"ok": false, "reason": "hostiles_remain", "hostiles": [ids]}  — blocked
##   {"ok": true, "awaiting_consent": [pc_ids]}                     — poll open
func request_end_combat() -> Dictionary:
	var hostiles: Array[int] = get_active_hostiles()
	if not hostiles.is_empty():
		return {"ok": false, "reason": "hostiles_remain", "hostiles": hostiles}
	_end_combat_consent.clear()
	_end_combat_pending = true
	return {"ok": true, "awaiting_consent": get_present_pc_ids()}


## Record a present PC's response to an open End Combat poll. A single decline
## cancels the proposal outright (combat continues). An agreement is tallied and,
## if it completes unanimous present-PC consent with the field still clear,
## finalizes the end of combat. Returns the result of try_finalize_end_combat()
## on agreement, or a cancellation dict on decline.
func register_end_combat_consent(pc_id: int, agree: bool) -> Dictionary:
	if not _end_combat_pending:
		return {"ended": false, "reason": "no_pending_request"}
	if not agree:
		_end_combat_pending = false
		_end_combat_consent.clear()
		return {"ended": false, "cancelled": true, "declined_by": pc_id}
	_end_combat_consent[pc_id] = true
	return try_finalize_end_combat()


## Attempt to finalize an open End Combat poll. Ends combat (returns the zone to
## real-time) only when no aware hostiles remain AND every present PC has agreed.
## If hostiles re-engaged since the request, the poll is cancelled. Returns:
##   {"ended": true}                                            — combat ended
##   {"ended": false, "reason": "no_pending_request"}
##   {"ended": false, "reason": "hostiles_remain"}              — poll cancelled
##   {"ended": false, "reason": "awaiting_consent", "remaining": [pc_ids]}
func try_finalize_end_combat() -> Dictionary:
	if not _end_combat_pending:
		return {"ended": false, "reason": "no_pending_request"}
	if has_active_hostiles():
		_end_combat_pending = false
		_end_combat_consent.clear()
		return {"ended": false, "reason": "hostiles_remain"}
	var remaining: Array[int] = []
	for pc_id: int in get_present_pc_ids():
		if not _end_combat_consent.get(pc_id, false):
			remaining.append(pc_id)
	if not remaining.is_empty():
		return {"ended": false, "reason": "awaiting_consent", "remaining": remaining}
	# Unanimous consent, field clear → return the zone to real-time. The
	# transition is reported by poll_mode_changed()'s last-reported compare.
	_turn_based = false
	_end_combat_pending = false
	_end_combat_consent.clear()
	return {"ended": true}


func _is_adjacent(ax: int, ay: int, bx: int, by: int) -> bool:
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and not (ax == bx and ay == by)


func _fov_radius(perception: int, x: int, y: int) -> int:
	var fov_mod: int = AsciiMapEnvironment.weather_to_fov_modifier(_weather)
	if _is_lookout_tile(x, y):
		return FovSystem.lookout_radius(perception, fov_mod)
	return FovSystem.effective_radius(perception, fov_mod)


func _is_lookout_tile(x: int, y: int) -> bool:
	# Raised ground is a lookout position (s4.4 Z-axis): high ground sees farther.
	if _map.has_elevation() and _map.elevation_at(x, y) > 0:
		return true
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
		# Bump-to-attack is an overt hostile act — any active disguise is blown.
		clear_disguise()
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
	var move_res: Dictionary = {"moved": true, "x": tx, "y": ty}
	_apply_trap_entry(move_res)
	return move_res


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
	# quiescence_of_air: +2 Stealth Free Raises while inside a silence sphere.
	var silence_fr: int = QUIESCENCE_STEALTH_FREE_RAISES if _in_silence(player.x, player.y) else 0
	var roll_result: Dictionary = _dice.roll_check(
		player.character.agility + stealth_rank + stealth_mut["rolled"] + stealth_adv["rolled"],
		player.character.agility + stealth_mut["kept"] + stealth_adv["kept"],
		ground_tn, 0, wound_pen - stealth_adv_tn + (stealth_adv["free_raises"] * 5) + (silence_fr * 5), stealth_rank > 0
	)

	player.x = tx
	player.y = ty
	_player_stealth = roll_result["success"]

	# Successful stealth move makes SILENT noise; failure makes QUIET.
	var noise_level: int = AsciiMapEnvironment.NoiseLevel.SILENT if roll_result["success"] \
			else AsciiMapEnvironment.NoiseLevel.QUIET
	_emit_noise(player.x, player.y, noise_level)
	_check_body_discovery()

	var stealth_res: Dictionary = {
		"moved": true,
		"x": tx, "y": ty,
		"stealth_maintained": roll_result["success"],
		"stealth_roll": roll_result["total"],
		"stealth_tn": ground_tn,
	}
	_apply_trap_entry(stealth_res)
	return stealth_res


# =============================================================================
# -- Traps (s56.20) -----------------------------------------------------------
# All paths no-op when the map carries no traps, so trap-free missions (every
# existing template instance until placement is enabled) are unaffected.
# =============================================================================

## Springs a trap on the tile the player just entered (if any), then runs passive
## detection for the turn. Merges results into the given move-result dict:
##   "trap"           → TrapSystem.trigger() result, if one sprang
##   "traps_detected" → Array of newly-DETECTED trap dicts this turn
func _apply_trap_entry(result: Dictionary) -> void:
	if _map.traps.is_empty():
		return
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return
	var trap: Dictionary = TrapSystem.trap_at(_map, player.x, player.y)
	if not trap.is_empty():
		var trig: Dictionary = TrapSystem.trigger(
			_map, player.character, player.participant, trap, _dice)
		result["trap"] = trig
		_trap_alert(player, trap.get("type", -1))
	var detected: Array = detect_traps()
	if not detected.is_empty():
		result["traps_detected"] = detected


## Emits the appropriate alert noise when a loud / alarm trap springs. Pit and
## Deadfall are LOUD; the Alarm/tripwire is map-wide VERY_LOUD; Dart and Snare
## are silent (no emit).
func _trap_alert(player: EntityState, trap_type: int) -> void:
	if not TrapSystem.alerts_on_spring(trap_type):
		return
	var lvl: int = AsciiMapEnvironment.NoiseLevel.VERY_LOUD \
		if trap_type == TrapSystem.TrapType.ALARM \
		else AsciiMapEnvironment.NoiseLevel.LOUD
	_emit_noise(player.x, player.y, lvl)


## Passive per-turn detection (s56.20): flips HIDDEN traps within DETECT_RANGE
## tiles AND in the player's FOV to DETECTED, via Perception + Hunting vs detect_tn.
## Returns the traps newly detected this call. Idempotent (only HIDDEN traps roll).
func detect_traps() -> Array:
	var out: Array = []
	if _map.traps.is_empty():
		return out
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return out
	var radius: int = _fov_radius(player.character.perception, player.x, player.y)
	for t: Dictionary in _map.traps:
		if t.get("state", TrapSystem.TrapState.HIDDEN) != TrapSystem.TrapState.HIDDEN:
			continue
		var tx: int = t.get("x", -1)
		var ty: int = t.get("y", -1)
		if maxi(absi(tx - player.x), absi(ty - player.y)) > TrapSystem.DETECT_RANGE:
			continue
		if not FovSystem.is_visible(player.x, player.y, tx, ty, radius, _map):
			continue
		if TrapSystem.attempt_detect(player.character, t, _dice):
			out.append(t)
	return out


## Player action: disarm a DETECTED trap on an adjacent tile (delta within 1 in
## each axis; same tile permitted when standing on a detected trap). Better of
## Hunting:Traps or Sleight of Hand vs disarm_tn; a bad fumble springs it.
func try_disarm_trap(dx: int, dy: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"success": false, "reason": "player_dead"}
	if absi(dx) > 1 or absi(dy) > 1:
		return {"success": false, "reason": "not_adjacent"}
	var trap: Dictionary = TrapSystem.trap_at(_map, player.x + dx, player.y + dy)
	if trap.is_empty() or trap.get("state", TrapSystem.TrapState.HIDDEN) != TrapSystem.TrapState.DETECTED:
		return {"success": false, "reason": "no_detected_trap"}
	var r: Dictionary = TrapSystem.attempt_disarm(
		_map, player.character, trap, _dice, player.participant)
	if r.get("sprung", false):
		_trap_alert(player, trap.get("type", -1))
	return r


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

	# Striking is an overt hostile act — any active disguise is blown.
	clear_disguise()

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

	# An open attack is overtly hostile — any active disguise is blown.
	clear_disguise()

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
	# Illusion disguise: a fooled guard reads the player as a friendly and does
	# not register them as an intruder this turn (s33/s36).
	if player_seen and _disguise_suppresses(es):
		player_seen = false
	# heart_betrays_eyes: a charged guard's next sighting is fooled (s33).
	if player_seen and _heart_betrays_suppresses(es):
		player_seen = false
	var just_became_suspicious: bool = false
	if player_seen and es.alert_state != AsciiMapEnvironment.AlertState.FLEEING:
		if es.alert_state == AsciiMapEnvironment.AlertState.UNAWARE:
			es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS
			es.phase_rounds_left = SUSPICIOUS_SEARCH_ROUNDS
			events.append({"type": "player_noticed", "entity_id": es.entity_id, "unit_type": es.unit_type})
			just_became_suspicious = true
		elif es.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS:
			es.alert_state = AsciiMapEnvironment.AlertState.ALERT
			es.alert_rounds_lost = 0
			events.append({"type": "escalated_to_alert", "entity_id": es.entity_id, "unit_type": es.unit_type})
		var player: EntityState = get_player()
		if player != null:
			es.noise_src_x = player.x
			es.noise_src_y = player.y

	# Becoming suspicious is this turn's action; the investigation (and any
	# escalation) begins next turn, not the same turn the contact was noticed.
	if just_became_suspicious:
		return events

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
			# s33 Seeking the Way: a fooled tracker is led the wrong way by the false trail — the
			# search point is mirrored to the far side of the guard (away from the player). Once per
			# guard (cached); a skilled tracker who sees through it tracks the true noise normally.
			if _seeking_misdirects(es):
				var pl: EntityState = get_player()
				if pl != null:
					var dx: int = es.x - pl.x
					var dy: int = es.y - pl.y
					es.noise_src_x = clampi(es.x + dx, 0, _map.width - 1)
					es.noise_src_y = clampi(es.y + dy, 0, _map.height - 1)
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

		# quiescence_of_air: no sound crosses a silence boundary (either way).
		if _silence_blocks(sx, sy, es.x, es.y):
			continue

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
# -- Disguise / perception-masking (s33/s36 illusion spells) ------------------
# =============================================================================

## Apply an illusion disguise spell to the player. The future stealth-command
## UI (or spell-cast action) calls this; PCs may be shugenja per s60.2. Freezes
## the see-through contest pool (Spellcraft + Air ring) and the spell's Mastery
## Level resist bonus. A fresh disguise resets all per-guard see-through results.
func apply_disguise(spell_id: String) -> Dictionary:
	if not DISGUISE_SPELLS.has(spell_id):
		return {"ok": false, "reason": "not_a_disguise_spell"}
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	var ml: int = int(SpellSystem.SPELL_LIBRARY.get(spell_id, {}).get("m", 0))
	player.disguise_spell_id = spell_id
	player.disguise_spellcraft = SkillResolver.get_skill_rank(player.character, "Spellcraft")
	player.disguise_air = SpellSystem.get_ring_value(player.character, Enums.Ring.AIR)
	player.disguise_resist_bonus = ml
	player.disguise_seethrough = {}
	return {"ok": true, "spell_id": spell_id, "resist_bonus": ml}

## Drop the disguise (overt hostile act, or the spell ending). Idempotent.
func clear_disguise() -> void:
	var player: EntityState = get_player()
	if player == null:
		return
	player.disguise_spell_id = ""
	player.disguise_seethrough = {}

func is_disguised() -> bool:
	var player: EntityState = get_player()
	return player != null and player.disguise_spell_id != ""

## True if the player's active disguise prevents guard `es` from registering the
## player as an intruder this turn. The contested see-through is rolled once per
## guard and cached; only UNAWARE/SUSPICIOUS guards can be fooled (a guard already
## ALERT and in combat ignores the disguise).
func _disguise_suppresses(es: EntityState) -> bool:
	var player: EntityState = get_player()
	if player == null or player.disguise_spell_id == "":
		return false
	if es.alert_state >= AsciiMapEnvironment.AlertState.ALERT:
		return false
	if player.disguise_seethrough.has(es.entity_id):
		return not bool(player.disguise_seethrough[es.entity_id])
	var penetrated: bool = _roll_disguise_seethrough(es, player)
	player.disguise_seethrough[es.entity_id] = penetrated
	return not penetrated

## s33 Seeking the Way (Air 4, Illusion): hide the caster's tracks, replacing them with a false trail
## leading in a completely different direction. The future stealth-command UI / a deliberate caster calls
## this. Freezes the Spellcraft/Air contest pool + the ML resist (no invented magnitude); a fooled guard
## that searches the caster's trail is sent the wrong way (see _npc_investigate). Skilled trackers may
## see through it (Hunting/Perception vs Spellcraft/Air). PCs may be shugenja (s60.2).
func cast_seeking_the_way() -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	if not SpellSystem.can_cast(player.character, "seeking_the_way"):
		return {"ok": false, "reason": "cannot_cast"}
	if not SpellSystem.resolve_cast(player.character, "seeking_the_way", _dice).get("success", false):
		return {"ok": false, "reason": "cast_failed"}
	player.seeking_the_way_active = true
	player.seeking_spellcraft = SkillResolver.get_skill_rank(player.character, "Spellcraft")
	player.seeking_air = SpellSystem.get_ring_value(player.character, Enums.Ring.AIR)
	player.seeking_resist_bonus = int(SpellSystem.SPELL_LIBRARY.get("seeking_the_way", {}).get("m", 4))
	player.seeking_seethrough = {}
	return {"ok": true}

## True if the false trail fools guard `es` (Contested Hunting/Perception vs the caster's Spellcraft/Air +
## ML; ties favor the illusion). Rolled once per guard and cached. A guard already ALERT (fighting, not
## tracking) is not misdirected.
func _seeking_misdirects(es: EntityState) -> bool:
	var player: EntityState = get_player()
	if player == null or not player.seeking_the_way_active:
		return false
	if es.alert_state >= AsciiMapEnvironment.AlertState.ALERT:
		return false
	if player.seeking_seethrough.has(es.entity_id):
		return bool(player.seeking_seethrough[es.entity_id])
	var g_perc: int = es.character.perception
	var g_hunt: int = SkillResolver.get_skill_rank(es.character, "Hunting")
	var guard_roll: DiceResult = _dice.roll_and_keep(g_perc + g_hunt, maxi(1, g_perc), true, false)
	var caster_roll: DiceResult = _dice.roll_and_keep(
		player.seeking_air + player.seeking_spellcraft, maxi(1, player.seeking_air), true, false)
	var fooled: bool = guard_roll.total <= caster_roll.total + player.seeking_resist_bonus
	player.seeking_seethrough[es.entity_id] = fooled
	return fooled


## Contested Investigation/Perception (guard) vs Spellcraft/Air + spell Mastery
## Level (caster). The guard penetrates only on a strict win; ties favor the
## disguise (the defender). Returns true if the disguise is seen through.
func _roll_disguise_seethrough(guard: EntityState, player: EntityState) -> bool:
	var g_perc: int = guard.character.perception
	var g_inv: int = SkillResolver.get_skill_rank(guard.character, "Investigation")
	var guard_roll: DiceResult = _dice.roll_and_keep(g_perc + g_inv, maxi(1, g_perc), true, false)
	var c_air: int = player.disguise_air
	var c_spell: int = player.disguise_spellcraft
	var caster_roll: DiceResult = _dice.roll_and_keep(c_air + c_spell, maxi(1, c_air), true, false)
	var caster_total: int = caster_roll.total + player.disguise_resist_bonus
	return guard_roll.total > caster_total


# =============================================================================
# -- heart_betrays_eyes (s33): fool one guard's next sighting ------------------
# =============================================================================

## Place a heart_betrays_eyes charge on a guard within 50' (10 tiles). The guard's
## NEXT sighting of the player is fooled unless they pass Investigation vs the
## caster's Air x5 (GDD TN). Lapses after 3 rounds if unused.
func apply_heart_betrays(target_id: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	var target: EntityState = _entities.get(target_id)
	if target == null or _is_entity_dead(target):
		return {"ok": false, "reason": "invalid_target"}
	if target.faction == FACTION_PLAYER:
		return {"ok": false, "reason": "not_an_enemy"}
	var dist: int = maxi(absi(target.x - player.x), absi(target.y - player.y))
	if dist > HEART_BETRAYS_RANGE_TILES:
		return {"ok": false, "reason": "out_of_range"}
	target.heart_betrays_air = SpellSystem.get_ring_value(player.character, Enums.Ring.AIR)
	target.heart_betrays_until_round = _round + HEART_BETRAYS_ROUNDS
	return {"ok": true, "target_id": target_id, "expiry_round": target.heart_betrays_until_round}

## True if guard `es` is fooled this turn by an active heart_betrays charge. The
## charge is one-shot — consumed on the guard's first spotting attempt whether or
## not it succeeds. Investigation vs caster Air x5; failure = fooled.
func _heart_betrays_suppresses(es: EntityState) -> bool:
	if es.heart_betrays_until_round < 0 or _round > es.heart_betrays_until_round:
		return false
	# Consume the one-shot charge.
	var air_tn: int = es.heart_betrays_air * 5
	es.heart_betrays_until_round = -1
	var inv: Dictionary = _dice.roll_check(
		es.character.perception + SkillResolver.get_skill_rank(es.character, "Investigation"),
		es.character.perception, air_tn, 0, 0,
		SkillResolver.get_skill_rank(es.character, "Investigation") > 0
	)
	return not bool(inv.get("success", false))


# =============================================================================
# -- by_the_light_of_the_moon (s33): reveal hidden traps ----------------------
# =============================================================================

## Reveal all HIDDEN traps within 20' (4 tiles) of the player — flips them to
## DETECTED. Returns {revealed: int, positions: Array[Vector2i]}.
func cast_moonlight_reveal() -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"revealed": 0, "positions": []}
	var revealed: Array[Vector2i] = []
	for t: Dictionary in _map.traps:
		if t.get("state", TrapSystem.TrapState.HIDDEN) != TrapSystem.TrapState.HIDDEN:
			continue
		var tx: int = t.get("x", -1)
		var ty: int = t.get("y", -1)
		if maxi(absi(tx - player.x), absi(ty - player.y)) <= MOONLIGHT_REVEAL_RADIUS_TILES:
			t["state"] = TrapSystem.TrapState.DETECTED
			revealed.append(Vector2i(tx, ty))
	return {"revealed": revealed.size(), "positions": revealed}


# =============================================================================
# -- the_kamis_whisper (s33): false-sound distraction -------------------------
# =============================================================================

## Create a false sound (Air 2, Illusion) at a chosen tile within 50' (10 tiles)
## of the player — a normal speaking voice or natural sound. Guards near the
## point hear it and investigate TOWARD it (away from the player), exactly as a
## real noise: UNAWARE -> SUSPICIOUS, and they path to (tx, ty). A classic
## stealth distraction. "No louder than a normal speaking voice" maps to the
## MODERATE noise level (QUIET = whisper, LOUD = shout). The future stealth-
## command UI / spell-cast action calls this; PCs may be shugenja (s60.2).
func cast_kamis_whisper(tx: int, ty: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	if tx < 0 or ty < 0 or tx >= _map.width or ty >= _map.height:
		return {"ok": false, "reason": "out_of_bounds"}
	var dist: int = maxi(absi(tx - player.x), absi(ty - player.y))
	if dist > KAMIS_WHISPER_RANGE_TILES:
		return {"ok": false, "reason": "out_of_range"}
	# A false sound, not the player's own — guards investigate the point, not the PC.
	_emit_noise(tx, ty, AsciiMapEnvironment.NoiseLevel.MODERATE)
	return {"ok": true, "x": tx, "y": ty}


## s37 False Whispers (Void 2): the target unknowingly repeats the caster's next sentence in their own
## voice. The faithful stealth-layer consumer: a chosen target guard "speaks" at their own position,
## emitting a MODERATE noise that draws OTHER guards toward them (a distraction). Range 30' (6 tiles).
## PCs may be shugenja (s60.2). The future stealth-command UI / a deliberate caster calls this.
func cast_false_whispers(target_id: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	if not SpellSystem.can_cast(player.character, "false_whispers"):
		return {"ok": false, "reason": "cannot_cast"}
	var target: EntityState = _entities.get(target_id)
	if target == null or _is_entity_dead(target):
		return {"ok": false, "reason": "invalid_target"}
	if maxi(absi(target.x - player.x), absi(target.y - player.y)) > 6:
		return {"ok": false, "reason": "out_of_range"}
	if not SpellSystem.resolve_cast(player.character, "false_whispers", _dice).get("success", false):
		return {"ok": false, "reason": "cast_failed"}
	# The target speaks at their own tile — a real sound from a real person, drawing other guards there.
	_emit_noise(target.x, target.y, AsciiMapEnvironment.NoiseLevel.MODERATE)
	return {"ok": true, "target_id": target_id, "x": target.x, "y": target.y}


## s37 Reach Through the Void (Void 2): touch a small object through the Void and move it telekinetically.
## The faithful stealth-layer consumer: silently open or close a door tile at range (50' = 10 tiles) —
## manipulating the latch without approaching (no noise, unlike a bump-open). PCs may be shugenja (s60.2).
func cast_reach_through_the_void(tx: int, ty: int) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	if not SpellSystem.can_cast(player.character, "reach_through_the_void"):
		return {"ok": false, "reason": "cannot_cast"}
	if tx < 0 or ty < 0 or tx >= _map.width or ty >= _map.height:
		return {"ok": false, "reason": "out_of_bounds"}
	if maxi(absi(tx - player.x), absi(ty - player.y)) > 10:
		return {"ok": false, "reason": "out_of_range"}
	var tile: int = _map.get_tile(tx, ty)
	var new_tile: int = -1
	if MovementSystem.is_closed_door(tile):
		new_tile = MovementSystem.open_door(tile)
	elif tile in [Enums.TileType.DOOR_SHOJI_OPEN, Enums.TileType.DOOR_WOOD_OPEN, Enums.TileType.GATE_OPEN]:
		new_tile = MovementSystem.close_door(tile)
	else:
		return {"ok": false, "reason": "no_movable_object"}  # only doors are modeled small objects
	if not SpellSystem.resolve_cast(player.character, "reach_through_the_void", _dice).get("success", false):
		return {"ok": false, "reason": "cast_failed"}
	_map.set_tile(tx, ty, new_tile)  # silent — telekinesis makes no noise
	return {"ok": true, "x": tx, "y": ty, "new_tile": new_tile}


# =============================================================================
# -- quiescence_of_air (s33): stationary silence sphere -----------------------
# =============================================================================

## Create a silence sphere (30' diameter, 10 Rounds). Default-centered on the
## player; pass cx/cy >= 0 to center elsewhere (the GDD 2-Raise relocation).
func apply_silence_zone(cx: int = -1, cy: int = -1) -> Dictionary:
	var player: EntityState = get_player()
	if player == null or _is_entity_dead(player):
		return {"ok": false, "reason": "no_living_player"}
	var zx: int = cx if cx >= 0 else player.x
	var zy: int = cy if cy >= 0 else player.y
	var zone: Dictionary = {
		"cx": zx, "cy": zy,
		"radius": QUIESCENCE_RADIUS_TILES,
		"expiry_round": _round + QUIESCENCE_ROUNDS,
	}
	_silence_zones.append(zone)
	return {"ok": true, "cx": zx, "cy": zy, "expiry_round": zone["expiry_round"]}

## True if (x, y) lies inside any still-active silence sphere.
func _in_silence(x: int, y: int) -> bool:
	for z: Dictionary in _silence_zones:
		if _round > int(z["expiry_round"]):
			continue
		if maxi(absi(x - int(z["cx"])), absi(y - int(z["cy"]))) <= int(z["radius"]):
			return true
	return false

## True if a silence boundary separates the two tiles — sound passes neither way
## (one endpoint inside an active sphere, the other outside).
func _silence_blocks(sx: int, sy: int, ex: int, ey: int) -> bool:
	return _in_silence(sx, sy) != _in_silence(ex, ey)


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
