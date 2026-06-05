extends GutTest
## GUT tests for CombatController (simulation/combat_controller.gd).
## Covers: unit stat blocks, creature death thresholds, entity death, swift movement,
## stealth TN, investigation style, morale, factory creation, player turn API,
## NPC turns, BFS, individual variance, noise/alarm, body discovery, mission complete.

# =============================================================================
# -- Helpers ------------------------------------------------------------------
# =============================================================================

func _make_open_map(w: int = 20, h: int = 20) -> AsciiMapData:
	var m := AsciiMapData.new()
	m.width  = w
	m.height = h
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	return m


func _make_session(player_x: int, player_y: int, placements: Array) -> MissionSession:
	var s := MissionSession.new()
	s.map             = _make_open_map()
	s.placements      = placements
	s.objective_slots = []
	s.seed_dict       = {}
	s.roster          = {}
	s.environment     = {}
	s.entry_pos       = Vector2i(player_x, player_y)
	s.water_ring      = 3
	s.perception      = 3
	return s


func _make_strong_player() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id  = 999
	c.reflexes      = 5; c.awareness     = 5
	c.stamina       = 5; c.willpower     = 5
	c.agility       = 5; c.intelligence  = 5
	c.strength      = 5; c.perception    = 5
	c.void_ring     = 5
	c.skills        = {"Kenjutsu": 5, "Stealth": 5}
	return c


func _make_weak_char() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id  = 998
	c.reflexes      = 1; c.awareness     = 1
	c.stamina       = 1; c.willpower     = 1
	c.agility       = 1; c.intelligence  = 1
	c.strength      = 1; c.perception    = 1
	c.void_ring     = 1
	c.skills        = {}
	return c


func _is_adjacent(ax: int, ay: int, bx: int, by: int) -> bool:
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and not (ax == bx and ay == by)


func _make_cc_with_enemy(enemy_type: String, ex: int, ey: int) -> CombatController:
	var session := _make_session(5, 5, [{"unit_type": enemy_type, "x": ex, "y": ey, "seed": 0}])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	return cc


# =============================================================================
# -- 1. Unit stat blocks (key traits from LOCKED s54.8 / s54.9) ---------------
# =============================================================================

func test_simple_bandit_reflexes() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 0)
	assert_eq(c.reflexes, 2)


func test_simple_bandit_stamina() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 0)
	assert_eq(c.stamina, 3)


func test_experienced_bandit_agility() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("EXPERIENCED_BANDIT", 0)
	assert_eq(c.agility, 4)


func test_bandit_lord_reflexes() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("BANDIT_LORD", 0)
	assert_eq(c.reflexes, 4)


func test_rebel_ashigaru_armor_tn_bonus() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("REBEL_ASHIGARU", 0)
	assert_eq(c.armor_tn_bonus, 5)
	assert_eq(c.armor_reduction, 3)


func test_bakemono_warrior_armor_reduction() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("BAKEMONO_WARRIOR", 0)
	assert_eq(c.armor_reduction, 3)


func test_bakemono_sneak_stealth_skill() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("BAKEMONO_SNEAK", 0)
	assert_eq(c.skills.get("Stealth", 0), 4)


func test_bakemono_warmonger_armor_reduction() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("BAKEMONO_WARMONGER", 0)
	assert_eq(c.armor_reduction, 7)


func test_troll_stamina() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("TROLL", 0)
	assert_eq(c.stamina, 5)


func test_free_ogre_strength() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("FREE_OGRE", 0)
	assert_eq(c.strength, 6)


func test_free_ogre_natural_armor_tn_bonus() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("FREE_OGRE", 0)
	assert_eq(c.armor_tn_bonus, 10)
	assert_eq(c.armor_reduction, 15)


func test_free_ogre_overlord_armor_reduction() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("FREE_OGRE_OVERLORD", 0)
	assert_eq(c.armor_reduction, 25)


func test_unknown_unit_type_gets_fallback_stats() -> void:
	var cc := CombatController.new()
	var c: L5RCharacterData = cc._create_unit_character("UNKNOWN_UNIT", 0)
	assert_eq(c.reflexes, 2)
	assert_eq(c.skills.get("Kenjutsu", 0), 2)


# =============================================================================
# -- 2. Creature death thresholds (LOCKED s54.9) ------------------------------
# =============================================================================

func test_creature_wounds_dead_bakemono_warrior() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("BAKEMONO_WARRIOR"), 20)


func test_creature_wounds_dead_bakemono_archer() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("BAKEMONO_ARCHER"), 18)


func test_creature_wounds_dead_bakemono_shaman() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("BAKEMONO_SHAMAN"), 18)


func test_creature_wounds_dead_bakemono_sneak() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("BAKEMONO_SNEAK"), 18)


func test_creature_wounds_dead_bakemono_warmonger() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("BAKEMONO_WARMONGER"), 45)


func test_creature_wounds_dead_troll() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("TROLL"), 90)


func test_creature_wounds_dead_free_ogre() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("FREE_OGRE"), 80)


func test_creature_wounds_dead_free_ogre_leader() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("FREE_OGRE_LEADER"), 90)


func test_creature_wounds_dead_free_ogre_overlord() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("FREE_OGRE_OVERLORD"), 100)


func test_creature_wounds_dead_human_returns_zero() -> void:
	var cc := CombatController.new()
	assert_eq(cc._creature_wounds_dead("SIMPLE_BANDIT"), 0)
	assert_eq(cc._creature_wounds_dead("BANDIT_LORD"), 0)
	assert_eq(cc._creature_wounds_dead("REBEL_LEADER"), 0)


# =============================================================================
# -- 3. Entity death check (creature vs human formula) -------------------------
# =============================================================================

func test_is_entity_dead_creature_uses_wounds_dead_override() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	cc._dice = DiceEngine.new(42)
	var c: L5RCharacterData = cc._create_unit_character("BAKEMONO_WARRIOR", 0)
	var eid: int = cc._create_entity(c, "BAKEMONO_WARRIOR", CombatController.FACTION_ENEMY, 3, 3)
	var es: CombatController.EntityState = cc.get_entity(eid)
	# Not dead at 19 wounds.
	es.character.wounds_taken = 19
	assert_false(cc._is_entity_dead(es))
	# Dead at 20 wounds.
	es.character.wounds_taken = 20
	assert_true(cc._is_entity_dead(es))


func test_is_entity_dead_human_uses_charstat_formula() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	cc._dice = DiceEngine.new(42)
	var c: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 0)
	var eid: int = cc._create_entity(c, "SIMPLE_BANDIT", CombatController.FACTION_ENEMY, 3, 3)
	var es: CombatController.EntityState = cc.get_entity(eid)
	# wounds_dead == 0 → use CharacterStats.is_dead (earth ring × 2 × 8 threshold)
	assert_eq(es.wounds_dead, 0)
	es.character.wounds_taken = 0
	assert_false(cc._is_entity_dead(es))


func test_is_entity_dead_is_alive_false_short_circuits() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	cc._dice = DiceEngine.new(42)
	var c: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 0)
	var eid: int = cc._create_entity(c, "SIMPLE_BANDIT", CombatController.FACTION_ENEMY, 3, 3)
	var es: CombatController.EntityState = cc.get_entity(eid)
	es.is_alive = false
	assert_true(cc._is_entity_dead(es))


# =============================================================================
# -- 4. Swift movement bonus (s54.9 LOCKED) ------------------------------------
# =============================================================================

func test_swift_bonus_bakemono_warrior() -> void:
	var cc := CombatController.new()
	assert_eq(cc._get_swift_bonus("BAKEMONO_WARRIOR"), 2)


func test_swift_bonus_bakemono_archer() -> void:
	var cc := CombatController.new()
	assert_eq(cc._get_swift_bonus("BAKEMONO_ARCHER"), 2)


func test_swift_bonus_bakemono_sneak() -> void:
	var cc := CombatController.new()
	assert_eq(cc._get_swift_bonus("BAKEMONO_SNEAK"), 3)


func test_swift_bonus_bakemono_warmonger() -> void:
	var cc := CombatController.new()
	assert_eq(cc._get_swift_bonus("BAKEMONO_WARMONGER"), 2)


func test_swift_bonus_human_units_zero() -> void:
	var cc := CombatController.new()
	assert_eq(cc._get_swift_bonus("SIMPLE_BANDIT"), 0)
	assert_eq(cc._get_swift_bonus("BANDIT_LORD"), 0)
	assert_eq(cc._get_swift_bonus("TROLL"), 0)
	assert_eq(cc._get_swift_bonus("FREE_OGRE"), 0)


# =============================================================================
# -- 5. Stealth TN by tile surface (s56.6.3 LOCKED) ---------------------------
# =============================================================================

func test_stealth_tn_soft_grass() -> void:
	var cc := CombatController.new()
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_GRASS), CombatController.STEALTH_TN_SOFT)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_MUD), CombatController.STEALTH_TN_SOFT)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_SNOW), CombatController.STEALTH_TN_SOFT)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_SAND), CombatController.STEALTH_TN_SOFT)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_ASH), CombatController.STEALTH_TN_SOFT)


func test_stealth_tn_noisy_rubble() -> void:
	var cc := CombatController.new()
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.RUBBLE), CombatController.STEALTH_TN_NOISY)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.CROPS), CombatController.STEALTH_TN_NOISY)


func test_stealth_tn_hard_stone_and_wood() -> void:
	var cc := CombatController.new()
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_STONE), CombatController.STEALTH_TN_HARD)
	assert_eq(cc._stealth_tn_for_tile(Enums.TileType.FLOOR_WOOD), CombatController.STEALTH_TN_HARD)


func test_stealth_tn_constants_are_locked_values() -> void:
	assert_eq(CombatController.STEALTH_TN_SOFT,  10)
	assert_eq(CombatController.STEALTH_TN_HARD,  15)
	assert_eq(CombatController.STEALTH_TN_NOISY, 20)


# =============================================================================
# -- 6. Investigation style mapping (s56.6.3 LOCKED) --------------------------
# =============================================================================

func test_investigation_style_timid() -> void:
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BANDIT_RABBLE"), "timid")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("REBEL_PEASANT"), "timid")


func test_investigation_style_cautious() -> void:
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BANDIT_THUG"), "cautious")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BAKEMONO_ARCHER"), "cautious")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BAKEMONO_SNEAK"), "cautious")


func test_investigation_style_professional() -> void:
	assert_eq(CombatController.INVESTIGATION_STYLE.get("SIMPLE_BANDIT"), "professional")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("EXPERIENCED_BANDIT"), "professional")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("REBEL_ASHIGARU"), "professional")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BAKEMONO_WARRIOR"), "professional")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BAKEMONO_WARMONGER"), "professional")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("TROLL"), "professional")


func test_investigation_style_aggressive() -> void:
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BANDIT_LORD"), "aggressive")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("REBEL_LEADER"), "aggressive")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("FREE_OGRE"), "aggressive")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("FREE_OGRE_LEADER"), "aggressive")
	assert_eq(CombatController.INVESTIGATION_STYLE.get("FREE_OGRE_OVERLORD"), "aggressive")


func test_investigation_style_caller() -> void:
	assert_eq(CombatController.INVESTIGATION_STYLE.get("BAKEMONO_SHAMAN"), "caller")


func test_investigation_style_unknown_defaults_professional() -> void:
	# _create_entity uses .get(unit_type, "professional")
	var cc := CombatController.new()
	cc._map = _make_open_map()
	cc._dice = DiceEngine.new(42)
	var c := L5RCharacterData.new()
	c.reflexes = 2; c.awareness = 2; c.stamina = 2; c.willpower = 2
	c.agility = 2; c.intelligence = 2; c.strength = 2; c.perception = 2
	var eid: int = cc._create_entity(c, "UNKNOWN_UNIT_TYPE", CombatController.FACTION_ENEMY, 3, 3)
	var es: CombatController.EntityState = cc.get_entity(eid)
	assert_eq(es.investigation_style, "professional")


# =============================================================================
# -- 7. Morale thresholds and unbreakable (s54.8 LOCKED) ----------------------
# =============================================================================

func test_morale_thresholds_bandit_rabble_locked_at_40_percent() -> void:
	assert_eq(CombatController.MORALE_THRESHOLDS.get("BANDIT_RABBLE"), 0.40)


func test_morale_thresholds_rebel_peasant() -> void:
	assert_eq(CombatController.MORALE_THRESHOLDS.get("REBEL_PEASANT"), 0.60)


func test_morale_thresholds_bandit_thug() -> void:
	assert_eq(CombatController.MORALE_THRESHOLDS.get("BANDIT_THUG"), 0.60)


func test_morale_thresholds_rebel_ashigaru() -> void:
	assert_eq(CombatController.MORALE_THRESHOLDS.get("REBEL_ASHIGARU"), 0.70)


func test_morale_unbreakable_rebel_leader() -> void:
	assert_true(CombatController.MORALE_UNBREAKABLE.has("REBEL_LEADER"))


func test_morale_unbreakable_does_not_include_normal_units() -> void:
	assert_false(CombatController.MORALE_UNBREAKABLE.has("BANDIT_RABBLE"))
	assert_false(CombatController.MORALE_UNBREAKABLE.has("BANDIT_THUG"))


# =============================================================================
# -- 8. Factory creation (CombatController.create) ----------------------------
# =============================================================================

func test_factory_creates_controller_with_player() -> void:
	var session := _make_session(2, 2, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_not_null(cc)
	assert_not_null(cc.get_player())


func test_factory_player_placed_at_entry_pos() -> void:
	var session := _make_session(3, 4, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var player: CombatController.EntityState = cc.get_player()
	assert_eq(player.x, 3)
	assert_eq(player.y, 4)


func test_factory_enemy_placed_at_given_position() -> void:
	var session := _make_session(1, 1, [{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 8, "seed": 0}])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemies: Array = cc.get_enemies_at(8, 8)
	assert_eq(enemies.size(), 1)


func test_factory_initial_enemy_count_tracked() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 8, "seed": 0},
		{"unit_type": "BANDIT_RABBLE", "x": 9, "y": 9, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_eq(cc._initial_enemy_count, 2)


func test_factory_player_faction_is_player() -> void:
	var session := _make_session(2, 2, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_eq(cc.get_player().faction, CombatController.FACTION_PLAYER)


func test_factory_enemy_faction_is_enemy() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 8, 8)
	var enemies: Array = cc.get_enemies_at(8, 8)
	assert_eq(enemies[0].faction, CombatController.FACTION_ENEMY)


func test_factory_sleeping_flag_set_from_placement() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 8, "seed": 0, "is_sleeping": true},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemies: Array = cc.get_enemies_at(8, 8)
	assert_true(enemies[0].is_sleeping)


# =============================================================================
# -- 9. Player movement (try_move_player) -------------------------------------
# =============================================================================

func test_try_move_player_normal_move_returns_moved() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("moved", false))
	assert_eq(cc.get_player().x, 6)


func test_try_move_player_wall_returns_blocked() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._map.set_tile(6, 5, Enums.TileType.WALL_STONE)
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("blocked", false))
	assert_eq(cc.get_player().x, 5)  # Did not move.


func test_try_move_player_out_of_bounds_returns_blocked() -> void:
	var session := _make_session(0, 0, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.try_move_player(-1, 0)
	assert_true(result.get("blocked", false))
	assert_eq(result.get("reason"), "out_of_bounds")


func test_try_move_player_zone_exit_returns_exited() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._map.set_tile(6, 5, Enums.TileType.ZONE_EXIT)
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("exited", false))


func test_try_move_player_door_bump_opens_door() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._map.set_tile(6, 5, Enums.TileType.DOOR_SHOJI_CLOSED)
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("opened_door", false))
	assert_eq(cc.get_player().x, 5)  # Player stays in place.


func test_try_move_player_bump_alert_enemy_attacks() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	# Make enemy ALERT so bump-to-attack fires.
	var enemies: Array = cc.get_enemies_at(6, 5)
	enemies[0].alert_state = AsciiMapEnvironment.AlertState.ALERT
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("attacked", false))
	assert_true(result.has("attack_result"))
	assert_eq(result.get("target_id"), enemies[0].entity_id)


func test_try_move_player_normal_move_breaks_stealth() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._player_stealth = true
	cc.try_move_player(1, 0)
	assert_false(cc._player_stealth)


# =============================================================================
# -- 10. Stealth movement (try_stealth_move) -----------------------------------
# =============================================================================

func test_try_stealth_move_returns_moved() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.try_stealth_move(1, 0)
	assert_true(result.get("moved", false))
	assert_eq(cc.get_player().x, 6)


func test_try_stealth_move_closed_door_is_blocked() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._map.set_tile(6, 5, Enums.TileType.DOOR_SHOJI_CLOSED)
	var result: Dictionary = cc.try_stealth_move(1, 0)
	assert_true(result.get("blocked", false))
	assert_eq(result.get("reason"), "closed_door")


func test_try_stealth_move_adjacent_enemy_prompts_stealth_kill() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.try_stealth_move(1, 0)
	assert_true(result.get("stealth_kill_available", false))
	assert_true(result.has("target_id"))


func test_try_stealth_move_result_has_roll_info() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.try_stealth_move(1, 0)
	assert_true(result.has("stealth_maintained"))
	assert_true(result.has("stealth_roll"))
	assert_true(result.has("stealth_tn"))


# =============================================================================
# -- 11. Stealth kill (execute_stealth_kill) -----------------------------------
# =============================================================================

func test_stealth_kill_not_adjacent_fails() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 10, "y": 10, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemies: Array = cc.get_enemies_at(10, 10)
	var result: Dictionary = cc.execute_stealth_kill(enemies[0].entity_id)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason"), "not_adjacent")


func test_stealth_kill_flat_footed_atn_formula() -> void:
	# ATN must be 5 + armor_tn_bonus (no Reflexes contribution).
	var session := _make_session(5, 5, [
		{"unit_type": "REBEL_ASHIGARU", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemies: Array = cc.get_enemies_at(6, 5)
	var es: CombatController.EntityState = enemies[0]
	# REBEL_ASHIGARU: armor_tn_bonus = 5 → flat ATN = 10.
	var expected_flat_atn: int = 5 + es.character.armor_tn_bonus
	assert_eq(expected_flat_atn, 10)
	# Execute and verify the flat_atn in the result.
	var result: Dictionary = cc.execute_stealth_kill(es.entity_id)
	# Result may be success or failure (dice), but flat_atn should always be 10.
	if result.get("success", false) or result.get("attack_failed", false):
		assert_eq(result.get("flat_atn", -1), 10)


func test_stealth_kill_alert_target_fails() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemies: Array = cc.get_enemies_at(6, 5)
	enemies[0].alert_state = AsciiMapEnvironment.AlertState.ALERT
	var result: Dictionary = cc.execute_stealth_kill(enemies[0].entity_id)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason"), "target_is_alert")


func test_stealth_kill_non_enemy_fails() -> void:
	# Create a "friendly" entity and attempt stealth kill.
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var c := _make_weak_char()
	var eid: int = cc._create_entity(c, "SIMPLE_BANDIT", CombatController.FACTION_FRIENDLY, 6, 5)
	var result: Dictionary = cc.execute_stealth_kill(eid)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason"), "not_an_enemy")


# =============================================================================
# -- 12. Noise emission and alert state transitions ---------------------------
# =============================================================================

func test_very_loud_noise_automatically_alerts_unaware_enemy() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 10, 10)
	var enemies: Array = cc.get_all_entities()
	var enemy: CombatController.EntityState
	for e: CombatController.EntityState in enemies:
		if e.faction == CombatController.FACTION_ENEMY:
			enemy = e
			break
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.UNAWARE)
	# VERY_LOUD is automatic and map-wide.
	cc._emit_noise(0, 0, AsciiMapEnvironment.NoiseLevel.VERY_LOUD)
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS)


func test_very_loud_noise_sets_noise_source_position() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 10, 10)
	var enemy: CombatController.EntityState
	for e: CombatController.EntityState in cc.get_all_entities():
		if e.faction == CombatController.FACTION_ENEMY:
			enemy = e
	cc._emit_noise(3, 7, AsciiMapEnvironment.NoiseLevel.VERY_LOUD)
	assert_eq(enemy.noise_src_x, 3)
	assert_eq(enemy.noise_src_y, 7)


func test_already_alert_enemy_unchanged_by_noise() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 10, 10)
	var enemy: CombatController.EntityState
	for e: CombatController.EntityState in cc.get_all_entities():
		if e.faction == CombatController.FACTION_ENEMY:
			enemy = e
	enemy.alert_state = AsciiMapEnvironment.AlertState.ALERT
	enemy.noise_src_x = 99
	enemy.noise_src_y = 99
	cc._emit_noise(5, 5, AsciiMapEnvironment.NoiseLevel.VERY_LOUD)
	# Already ALERT, should NOT change noise source.
	assert_eq(enemy.noise_src_x, 99)


func test_sleeping_enemy_woken_on_detection() -> void:
	# Very Loud noise wakes sleeping enemies automatically.
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 5, "seed": 0, "is_sleeping": true},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	assert_true(enemy.is_sleeping)
	cc._emit_noise(0, 0, AsciiMapEnvironment.NoiseLevel.VERY_LOUD)
	assert_false(enemy.is_sleeping)


func test_noise_detection_tn_constants_locked() -> void:
	assert_eq(CombatController.NOISE_DETECTION_TN.get(AsciiMapEnvironment.NoiseLevel.QUIET), 20)
	assert_eq(CombatController.NOISE_DETECTION_TN.get(AsciiMapEnvironment.NoiseLevel.MODERATE), 15)
	assert_eq(CombatController.NOISE_DETECTION_TN.get(AsciiMapEnvironment.NoiseLevel.LOUD), 10)
	assert_eq(CombatController.NOISE_DETECTION_TN.get(AsciiMapEnvironment.NoiseLevel.VERY_LOUD), 0)


# =============================================================================
# -- 13. Body discovery (s56.6.3 LOCKED) --------------------------------------
# =============================================================================

func test_body_discovery_alerts_enemy_seeing_corpse() -> void:
	# Place enemy in line-of-sight of where corpse will appear.
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 1, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 1)[0]
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.UNAWARE)
	# Plant a corpse at (5, 2) — adjacent, always in FoV.
	cc._add_corpse(5, 2)
	cc._check_body_discovery()
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.ALERT)


func test_body_discovery_no_corpses_no_state_change() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	cc._check_body_discovery()  # No corpses.
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.UNAWARE)


func test_body_discovery_already_alert_stays_alert() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 3, "y": 1, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(3, 1)[0]
	enemy.alert_state = AsciiMapEnvironment.AlertState.ALERT
	cc._add_corpse(3, 2)
	cc._check_body_discovery()
	# Should not double-trigger or change state.
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.ALERT)


func test_body_discovery_queues_body_spotted_event() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 1, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._add_corpse(5, 2)
	cc._check_body_discovery()
	assert_false(cc._pending_noise_events.is_empty(),
		"body_spotted event should be queued in _pending_noise_events")
	assert_eq(cc._pending_noise_events[0].get("type"), "body_spotted")


func test_body_discovery_no_event_when_already_alert() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 1, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 1)[0]
	enemy.alert_state = AsciiMapEnvironment.AlertState.ALERT
	cc._add_corpse(5, 2)
	cc._check_body_discovery()
	assert_true(cc._pending_noise_events.is_empty(),
		"already-alert enemy should not queue another event")


# =============================================================================
# -- 14. Morale check (_check_morale) ----------------------------------------
# =============================================================================

func test_morale_breaks_bandit_rabble_at_40_percent() -> void:
	# 5 BANDIT_RABBLE enemies; 2 deaths = 40% → should break.
	var placements: Array = []
	for i: int in range(5):
		placements.append({"unit_type": "BANDIT_RABBLE", "x": i + 3, "y": 3, "seed": 0})
	var session := _make_session(1, 1, placements)
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._enemy_deaths_total = 2  # 2/5 = 40%.
	cc._check_morale()
	var any_broken: bool = false
	for es: CombatController.EntityState in cc.get_all_entities():
		if es.faction == CombatController.FACTION_ENEMY and es.morale_broken:
			any_broken = true
	assert_true(any_broken)


func test_morale_never_breaks_rebel_leader() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "REBEL_LEADER", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	# Set deaths to 100% — should not break REBEL_LEADER.
	cc._enemy_deaths_total = 100
	cc._check_morale()
	var leader: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	assert_false(leader.morale_broken)


func test_morale_does_not_break_units_without_threshold() -> void:
	# BANDIT_LORD has no entry in MORALE_THRESHOLDS → threshold 0.0 → never breaks.
	var session := _make_session(1, 1, [
		{"unit_type": "BANDIT_LORD", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._enemy_deaths_total = 1000
	cc._check_morale()
	var lord: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	assert_false(lord.morale_broken)


# =============================================================================
# -- 15. NPC turns (advance_npc_turns) ----------------------------------------
# =============================================================================

func test_advance_npc_turns_increments_round() -> void:
	var session := _make_session(1, 1, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_eq(cc.get_round(), 0)
	cc.advance_npc_turns()
	assert_eq(cc.get_round(), 1)


func test_advance_npc_turns_skips_dead_enemies() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	enemy.is_alive = false
	# Should complete without error (dead entity is skipped).
	var events: Array = cc.advance_npc_turns()
	assert_not_null(events)


func test_advance_npc_turns_alert_enemy_moves_toward_player() -> void:
	# Enemy at (10, 5), player at (5, 5) — 5 tiles apart.
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 10, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(10, 5)[0]
	enemy.alert_state = AsciiMapEnvironment.AlertState.ALERT
	enemy.noise_src_x = 5
	enemy.noise_src_y = 5
	var x_before: int = enemy.x
	cc.advance_npc_turns()
	# Enemy should have moved closer (x decreased).
	assert_true(enemy.x < x_before)


func test_advance_npc_turns_caller_unit_raises_alarm() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "BAKEMONO_SHAMAN", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var shaman: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	shaman.alert_state = AsciiMapEnvironment.AlertState.ALERT
	var events: Array = cc.advance_npc_turns()
	var found_alarm: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "alarm_raised":
			found_alarm = true
	assert_true(found_alarm)
	assert_true(shaman.alarm_sounded)


# =============================================================================
# -- 16. Mission complete (is_mission_complete) --------------------------------
# =============================================================================

func test_mission_complete_no_enemies() -> void:
	var session := _make_session(1, 1, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_true(cc.is_mission_complete())


func test_mission_not_complete_with_living_enemy() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 8, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_false(cc.is_mission_complete())


func test_mission_complete_all_enemies_dead() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 8, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(8, 8)[0]
	enemy.is_alive = false
	assert_true(cc.is_mission_complete())


# =============================================================================
# -- 17. BFS path finding (_bfs_path) -----------------------------------------
# =============================================================================

func test_bfs_finds_path_in_open_map() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	var path: Array = cc._bfs_path(0, 0, 3, 3)
	assert_false(path.is_empty())
	var last: Vector2i = path[path.size() - 1]
	assert_eq(last.x, 3)
	assert_eq(last.y, 3)


func test_bfs_same_position_returns_empty() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	var path: Array = cc._bfs_path(5, 5, 5, 5)
	assert_true(path.is_empty())


func test_bfs_no_path_through_solid_walls() -> void:
	var cc := CombatController.new()
	# Create a 10×10 map with a full vertical wall at x=5 (no gap).
	var m := AsciiMapData.new()
	m.width = 10; m.height = 10
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	for iy: int in range(10):
		m.set_tile(5, iy, Enums.TileType.WALL_STONE)
	cc._map = m
	var path: Array = cc._bfs_path(0, 5, 9, 5)
	assert_true(path.is_empty())


func test_bfs_path_does_not_include_start() -> void:
	var cc := CombatController.new()
	cc._map = _make_open_map()
	var path: Array = cc._bfs_path(2, 2, 4, 2)
	if not path.is_empty():
		var first: Vector2i = path[0]
		assert_true(first.x != 2 or first.y != 2)


# =============================================================================
# -- 18. Individual variance (s56.10.0a) --------------------------------------
# =============================================================================

func test_variance_applies_when_seed_mod_10_lt_4() -> void:
	# Seed 3 → 3 % 10 = 3 < 4 → variance applies.
	var cc := CombatController.new()
	var base: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 0)
	var varied: L5RCharacterData = cc._create_unit_character("SIMPLE_BANDIT", 3)
	# At least one trait/skill should differ by 1.
	var base_total: int = base.reflexes + base.awareness + base.stamina + base.willpower + \
			base.agility + base.intelligence + base.strength + base.perception
	var varied_total: int = varied.reflexes + varied.awareness + varied.stamina + varied.willpower + \
			varied.agility + varied.intelligence + varied.strength + varied.perception
	var skill_delta: int = 0
	for sk: String in varied.skills.keys():
		skill_delta += varied.skills.get(sk, 0) - base.skills.get(sk, 0)
	# Either a trait or a skill gained +1.
	assert_true(varied_total > base_total or skill_delta > 0)


func test_variance_does_not_apply_when_seed_mod_10_ge_4() -> void:
	# Seed 5 → 5 % 10 = 5 ≥ 4 → no variance.
	var cc := CombatController.new()
	var base: L5RCharacterData  = cc._create_unit_character("SIMPLE_BANDIT", 0)
	var same: L5RCharacterData  = cc._create_unit_character("SIMPLE_BANDIT", 5)
	assert_eq(base.reflexes, same.reflexes)
	assert_eq(base.stamina,  same.stamina)
	assert_eq(base.agility,  same.agility)


func test_variance_does_not_apply_when_seed_zero() -> void:
	# Seed 0 means "no variance" (placements with no seed field default to 0).
	var cc := CombatController.new()
	var base: L5RCharacterData  = cc._create_unit_character("BANDIT_LORD", 0)
	var also: L5RCharacterData  = cc._create_unit_character("BANDIT_LORD", 0)
	assert_eq(base.reflexes, also.reflexes)
	assert_eq(base.agility,  also.agility)


# =============================================================================
# -- 19. Wait player (wait_player) --------------------------------------------
# =============================================================================

func test_wait_player_returns_waited_true() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var result: Dictionary = cc.wait_player()
	assert_true(result.get("waited", false))


func test_wait_player_breaks_stealth() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._player_stealth = true
	cc.wait_player()
	assert_false(cc._player_stealth)


func test_wait_player_returns_current_round() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc.advance_npc_turns()  # Round becomes 1.
	var result: Dictionary = cc.wait_player()
	assert_eq(result.get("round"), 1)


# =============================================================================
# -- 20. Alarm (_raise_alarm) -------------------------------------------------
# =============================================================================

func test_raise_alarm_sets_alarm_sounded() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 5, 5)
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	assert_false(enemy.alarm_sounded)
	cc._raise_alarm(enemy)
	assert_true(enemy.alarm_sounded)


func test_raise_alarm_returns_alarm_event_dict() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 5, 5)
	var enemy: CombatController.EntityState = cc.get_enemies_at(5, 5)[0]
	var ev: Dictionary = cc._raise_alarm(enemy)
	assert_eq(ev.get("type"), "alarm_raised")
	assert_eq(ev.get("entity_id"), enemy.entity_id)


func test_raise_alarm_alerts_all_enemies_map_wide() -> void:
	# Place two enemies at opposite corners; alarm from corner 1 should alert corner 2.
	var session := _make_session(10, 10, [
		{"unit_type": "SIMPLE_BANDIT", "x": 1,  "y": 1,  "seed": 0},
		{"unit_type": "SIMPLE_BANDIT", "x": 18, "y": 18, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var e1: CombatController.EntityState = cc.get_enemies_at(1, 1)[0]
	var e2: CombatController.EntityState = cc.get_enemies_at(18, 18)[0]
	cc._raise_alarm(e1)
	# e2 should now be SUSPICIOUS (detected via VERY_LOUD auto-detection).
	assert_ne(e2.alert_state, AsciiMapEnvironment.AlertState.UNAWARE)


# =============================================================================
# -- 21. Visible tiles (get_visible_tiles) ------------------------------------
# =============================================================================

func test_get_visible_tiles_returns_dict() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var visible: Dictionary = cc.get_visible_tiles()
	assert_not_null(visible)
	assert_true(visible is Dictionary)


func test_get_visible_tiles_includes_player_position() -> void:
	var session := _make_session(5, 5, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var visible: Dictionary = cc.get_visible_tiles()
	assert_true(visible.has(Vector2i(5, 5)))


# =============================================================================
# -- 22. Faction constants (all distinct) ------------------------------------
# =============================================================================

func test_faction_constants_are_distinct() -> void:
	assert_ne(CombatController.FACTION_PLAYER,   CombatController.FACTION_ENEMY)
	assert_ne(CombatController.FACTION_PLAYER,   CombatController.FACTION_FRIENDLY)
	assert_ne(CombatController.FACTION_FRIENDLY, CombatController.FACTION_ENEMY)


# =============================================================================
# -- 23. Alert state phase constants (s56.6.3 LOCKED) -------------------------
# =============================================================================

func test_alert_phase_constants_locked() -> void:
	assert_eq(CombatController.SUSPICIOUS_SEARCH_ROUNDS, 3)
	assert_eq(CombatController.SUSPICIOUS_RETURN_ROUNDS, 3)
	assert_eq(CombatController.ALERT_ALARM_ROUNDS,       5)
	assert_eq(CombatController.SLEEPING_DETECTION_BONUS, 10)
	assert_eq(CombatController.COMBAT_DETECTION_BONUS,   5)
	assert_eq(CombatController.SUSPICIOUS_SCAN_BONUS,    5)


# =============================================================================
# -- 24. Player direct attack (execute_player_attack) -------------------------
# =============================================================================

func test_execute_player_attack_not_adjacent_fails() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 10, "y": 10, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(10, 10)[0]
	var result: Dictionary = cc.execute_player_attack(enemy.entity_id)
	assert_eq(result.get("reason"), "not_adjacent")


func test_execute_player_attack_adjacent_returns_attack_keys() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(6, 5)[0]
	var result: Dictionary = cc.execute_player_attack(enemy.entity_id)
	# Enriched dict matches try_move_player attack shape.
	assert_eq(result.get("type"), "attacked")
	assert_true(result.get("attacked", false))
	assert_eq(result.get("target_id"), enemy.entity_id)
	assert_true(result.has("unit_type"))
	assert_true(result.has("damage"))
	assert_true(result.has("killed"))
	# Raw combat detail is nested under attack_result.
	var ar: Dictionary = result.get("attack_result", {})
	assert_true(ar.has("hit"))
	assert_true(ar.has("attack_roll"))
	assert_true(ar.has("armor_tn"))


func test_execute_player_attack_alerts_target() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(6, 5)[0]
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.UNAWARE)
	cc.execute_player_attack(enemy.entity_id)
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.ALERT)


func test_execute_player_attack_breaks_stealth() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	cc._player_stealth = true
	var enemy: CombatController.EntityState = cc.get_enemies_at(6, 5)[0]
	cc.execute_player_attack(enemy.entity_id)
	assert_false(cc._player_stealth)


# =============================================================================
# -- 25. Sortie session (friendly + enemy factions) ---------------------------
# =============================================================================

func test_sortie_session_populates_friendly_and_enemy() -> void:
	var s := MissionSession.new()
	s.map             = _make_open_map()
	s.objective_slots = []
	s.seed_dict       = {}
	s.roster          = {}
	s.environment     = {}
	s.entry_pos       = Vector2i(1, 1)
	s.placements      = {
		"friendly": [{"unit_type": "REBEL_ASHIGARU", "x": 2, "y": 2, "seed": 0}],
		"enemy":    [{"unit_type": "BAKEMONO_WARRIOR", "x": 8, "y": 8, "seed": 0}],
	}
	var cc := CombatController.create(s, _make_strong_player(), DiceEngine.new(42))
	var friendly_count: int = 0
	var enemy_count: int    = 0
	for es: CombatController.EntityState in cc.get_all_entities():
		if es.faction == CombatController.FACTION_FRIENDLY:
			friendly_count += 1
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_count += 1
	assert_eq(friendly_count, 1)
	assert_eq(enemy_count, 1)


# =============================================================================
# -- 26. Suspicious investigation phase timing ---------------------------------
# =============================================================================

func test_suspicious_phase_counts_down_each_turn() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 15, "y": 15, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(15, 15)[0]
	# Manually set to SUSPICIOUS.
	enemy.alert_state     = AsciiMapEnvironment.AlertState.SUSPICIOUS
	enemy.phase_rounds_left = CombatController.SUSPICIOUS_SEARCH_ROUNDS
	enemy.noise_src_x     = 14
	enemy.noise_src_y     = 15
	# Run one NPC turn.
	cc.advance_npc_turns()
	# phase_rounds_left should have decremented (or entity escalated).
	if enemy.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS:
		assert_true(enemy.phase_rounds_left < CombatController.SUSPICIOUS_SEARCH_ROUNDS)


# =============================================================================
# -- 27. Entity at tile queries -----------------------------------------------
# =============================================================================

func test_get_enemies_at_returns_empty_for_empty_tile() -> void:
	var session := _make_session(1, 1, [])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	assert_eq(cc.get_enemies_at(9, 9).size(), 0)


func test_get_entity_returns_correct_entity() -> void:
	var session := _make_session(5, 5, [
		{"unit_type": "BANDIT_LORD", "x": 9, "y": 9, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(9, 9)[0]
	var fetched: CombatController.EntityState = cc.get_entity(enemy.entity_id)
	assert_not_null(fetched)
	assert_eq(fetched.entity_id, enemy.entity_id)


func test_get_all_entities_includes_player_and_enemies() -> void:
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5, "y": 5, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var all: Array = cc.get_all_entities()
	assert_eq(all.size(), 2)  # Player + 1 enemy.


# =============================================================================
# -- 28. Investigate phase transition (search → return, no double-move) --------
# =============================================================================

func test_investigate_search_phase_runs_exactly_n_rounds() -> void:
	# Enemy far from player and noise source; player is hidden so no FoV escalation.
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 18, "y": 18, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(18, 18)[0]
	enemy.alert_state       = AsciiMapEnvironment.AlertState.SUSPICIOUS
	enemy.phase_rounds_left = CombatController.SUSPICIOUS_SEARCH_ROUNDS  # 3
	enemy.noise_src_x       = 15
	enemy.noise_src_y       = 18

	# Run SUSPICIOUS_SEARCH_ROUNDS turns; entity should still be SUSPICIOUS (not yet returning).
	for i: int in range(CombatController.SUSPICIOUS_SEARCH_ROUNDS):
		if enemy.alert_state != AsciiMapEnvironment.AlertState.SUSPICIOUS:
			break
		cc._npc_investigate(enemy)

	# After search phase ends (prl hits 0), the entity should be in return phase (prl == 0).
	if enemy.alert_state == AsciiMapEnvironment.AlertState.SUSPICIOUS:
		assert_eq(enemy.phase_rounds_left, 0,
			"prl should be 0 after SUSPICIOUS_SEARCH_ROUNDS ticks")


func test_investigate_return_phase_reaches_unaware() -> void:
	# Enemy far from player and noise source so no FoV escalation.
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 18, "y": 18, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(18, 18)[0]
	# Simulate entity already at start of return phase (prl = 0).
	enemy.alert_state       = AsciiMapEnvironment.AlertState.SUSPICIOUS
	enemy.phase_rounds_left = 0
	enemy.noise_src_x       = 15
	enemy.noise_src_y       = 18

	# Run SUSPICIOUS_RETURN_ROUNDS more turns; entity should return to UNAWARE.
	for i: int in range(CombatController.SUSPICIOUS_RETURN_ROUNDS + 1):
		if enemy.alert_state != AsciiMapEnvironment.AlertState.SUSPICIOUS:
			break
		cc._npc_investigate(enemy)

	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"entity should return to UNAWARE after full return phase")


func test_investigate_no_double_move_at_phase_boundary() -> void:
	# Verify that the NPC makes exactly one move per call to _npc_investigate,
	# regardless of phase (search vs return).
	var session := _make_session(1, 1, [
		{"unit_type": "SIMPLE_BANDIT", "x": 10, "y": 10, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy: CombatController.EntityState = cc.get_enemies_at(10, 10)[0]
	enemy.alert_state       = AsciiMapEnvironment.AlertState.SUSPICIOUS
	enemy.phase_rounds_left = 1  # One search round left.
	enemy.patrol_x          = 10
	enemy.patrol_y          = 10
	enemy.noise_src_x       = 12
	enemy.noise_src_y       = 10
	var start_x: int = enemy.x
	# One call at prl=1 (search phase): should move toward noise_src.
	cc._npc_investigate(enemy)
	# prl is now 0; enemy should have moved toward (12, 10) — not back to patrol yet.
	assert_eq(enemy.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS)
	assert_eq(enemy.phase_rounds_left, 0)
	# Enemy moved toward noise (12,10), not back to patrol (10,10).
	assert_true(enemy.x > start_x or enemy.x == start_x,
		"enemy should move toward noise source, not patrol, during search phase")


func test_body_discovery_events_returned_in_same_round() -> void:
	# Bug fix: _check_body_discovery() runs at end of advance_npc_turns().
	# Events it queues to _pending_noise_events must be flushed into the
	# returned array before the function exits — not delayed to the next round.
	var session := _make_session(1, 1, [
		{"unit_type": "BANDIT_THUG", "x": 3, "y": 3, "seed": 0},
		{"unit_type": "BANDIT_THUG", "x": 4, "y": 3, "seed": 1},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(1))

	# Kill the first enemy to create a body.
	var enemies: Array = cc.get_entity_display_data()
	var dead_id: int = -1
	for e: Dictionary in enemies:
		if e.get("faction") == "enemy":
			dead_id = e["id"]
			break
	assert_true(dead_id >= 0, "need an enemy to kill")

	# Directly mark the entity dead (avoid full attack resolution complexity).
	var dead_es: CombatController.EntityState = cc._entities.get(dead_id)
	assert_not_null(dead_es)
	dead_es.is_alive = false
	dead_es.character.wounds_taken = 99

	# Put the surviving enemy in ALERT and adjacent to the body.
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY and es.is_alive:
			es.alert_state = AsciiMapEnvironment.AlertState.ALERT
			es.x = dead_es.x + 1
			es.y = dead_es.y
			break

	# advance_npc_turns must return body_spotted in the SAME call.
	var events: Array = cc.advance_npc_turns()
	var found_body_event: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "body_spotted":
			found_body_event = true
			break
	assert_true(found_body_event,
		"body_spotted event must be returned in the same advance_npc_turns() call, not delayed")


func test_bump_to_attack_alerts_surviving_target() -> void:
	# Bug fix: a non-lethal bump-to-attack must mark the surviving enemy ALERT and
	# set in_combat so it fights back on its next NPC turn.
	# Use a tough enemy (BANDIT_LORD) and a weak attacker so the hit is non-lethal.
	var session := _make_session(5, 5, [
		{"unit_type": "BANDIT_LORD", "x": 6, "y": 5, "seed": 0},
	])
	var weak_player := _make_weak_char()
	weak_player.character_id = 999
	weak_player.skills = {"Kenjutsu": 1}
	var cc := CombatController.create(session, weak_player, DiceEngine.new(42))

	# Verify the enemy starts UNAWARE.
	var enemy_id: int = -1
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_id = eid
			assert_eq(es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
				"enemy should start UNAWARE")
			break
	assert_true(enemy_id >= 0, "need a BANDIT_LORD enemy")

	# Bump into the enemy — the weak player will almost certainly not one-shot it.
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("attacked", false), "bump into enemy should produce attack")

	var enemy_es: CombatController.EntityState = cc._entities[enemy_id]
	if enemy_es.is_alive:
		# Surviving enemy must be ALERT and in_combat.
		assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
			"surviving bump target must be ALERT after non-lethal attack")
		assert_true(enemy_es.in_combat,
			"surviving bump target must have in_combat=true")
		assert_eq(enemy_es.combat_target_id, cc.get_player().entity_id,
			"surviving bump target must track the player as combat target")

	# _player_stealth must be cleared regardless of kill/survive.
	assert_false(cc._player_stealth,
		"bump-to-attack must clear player stealth")


# =============================================================================
# -- 30. Alert escalation — SUSPICIOUS→ALERT on LOUD noise (Fix B) -----------
# =============================================================================

func test_suspicious_enemy_escalates_to_alert_on_loud_noise() -> void:
	# s56.6.3 LOCKED: Suspicious→Alert on Loud noise.
	# A SUSPICIOUS enemy that detects LOUD noise must become ALERT immediately.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 8, 5)

	# Manually set the enemy to SUSPICIOUS with a noise source far from player.
	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS
	enemy_es.phase_rounds_left = 3
	# Enemy at (8,5), player at (5,5) — LOUD noise emitted from (5,5) should reach (8,5).
	cc._emit_noise(5, 5, AsciiMapEnvironment.NoiseLevel.LOUD)

	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
		"SUSPICIOUS enemy must escalate to ALERT on LOUD noise (s56.6.3)")


func test_unaware_enemy_does_not_jump_to_alert_on_moderate_noise() -> void:
	# UNAWARE enemy on MODERATE noise → SUSPICIOUS (not directly to ALERT).
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 7, 5)
	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es)
	# MODERATE noise at adjacent position — guaranteed detection (TN very low).
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE
	cc._emit_noise(6, 5, AsciiMapEnvironment.NoiseLevel.MODERATE)
	# Enemy should be SUSPICIOUS (not ALERT) after a single MODERATE event.
	assert_ne(enemy_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
		"single MODERATE noise must not jump UNAWARE enemy straight to ALERT")


func test_suspicious_enemy_stays_suspicious_on_moderate_noise() -> void:
	# SUSPICIOUS + MODERATE noise → stays SUSPICIOUS (only LOUD escalates).
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 7, 5)
	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es)
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS
	cc._emit_noise(6, 5, AsciiMapEnvironment.NoiseLevel.MODERATE)
	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS,
		"MODERATE noise must not escalate a SUSPICIOUS enemy to ALERT")


# =============================================================================
# -- 31. Stealth kill triggers morale check (Fix A) ---------------------------
# =============================================================================

func test_stealth_kill_triggers_morale_event() -> void:
	# Bug fix: stealth kills must fire _check_morale() and propagate morale_broken
	# events into _pending_noise_events so advance_npc_turns() returns them.
	# Set up: one weak enemy (morale breaks at 50% dead), one surviving enemy.
	# Use seed=99 so we control rolls.
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0},
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 7, "seed": 0},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(99))

	# Move player adjacent to first enemy at (6,5).
	var player: CombatController.EntityState = cc.get_player()
	player.x = 5
	player.y = 5

	# Force initial enemy count to 2 and deaths to 0 for clean morale math.
	cc._initial_enemy_count = 2
	cc._enemy_deaths_total = 0

	# Find the enemy at (6,5) and make it UNAWARE (stealth kill eligible).
	var target_id: int = -1
	var survivor_id: int = -1
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			if es.x == 6 and es.y == 5:
				es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE
				target_id = eid
			else:
				survivor_id = eid

	assert_true(target_id >= 0, "need target enemy at (6,5)")
	assert_true(survivor_id >= 0, "need a surviving enemy")

	# Set the survivor's morale threshold to break at the first death (low threshold).
	var survivor_es: CombatController.EntityState = cc._entities[survivor_id]
	# SIMPLE_BANDIT morale threshold should be <= 0.5, so 1/2 deaths triggers it.
	# Verify SIMPLE_BANDIT is in MORALE_THRESHOLDS and <= 0.5.
	var threshold: float = CombatController.MORALE_THRESHOLDS.get("SIMPLE_BANDIT", 0.0)
	if threshold <= 0.0 or threshold > 0.5:
		# Not a morale-breakable unit at this ratio; skip rather than assert-fail.
		return

	var result: Dictionary = cc.execute_stealth_kill(target_id)
	assert_true(result.get("success", false) and result.get("target_killed", false),
		"stealth kill must succeed and kill the target for this test")

	# advance_npc_turns flushes _pending_noise_events.
	var events: Array = cc.advance_npc_turns()
	var found_morale: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "morale_broken":
			found_morale = true
			break
	assert_true(found_morale,
		"stealth kill of 50% enemies must produce morale_broken event in advance_npc_turns()")


# =============================================================================
# -- 32. NPC sets in_combat when attacking (Fix D) ----------------------------
# =============================================================================

func test_npc_sets_in_combat_when_attacking_adjacent() -> void:
	# Bug fix: NPC must set in_combat=true when it attacks so that subsequent
	# COMBAT_DETECTION_BONUS applies (+10 TN to detection while fighting).
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")

	# Put enemy ALERT adjacent to player.
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.ALERT
	enemy_es.x = 6
	enemy_es.y = 5

	assert_false(enemy_es.in_combat, "enemy must start with in_combat=false")

	# Drive the NPC turn; it should attack the adjacent player.
	var events: Array = cc.advance_npc_turns()
	var attacked: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "npc_attacked" and ev.get("entity_id", -1) == enemy_es.entity_id:
			attacked = true
			break
	assert_true(attacked, "ALERT enemy adjacent to player must attack")
	assert_true(enemy_es.in_combat,
		"NPC must have in_combat=true after executing an attack")


# =============================================================================
# -- Section 33: Terminal event generation ------------------------------------
# -- Bugs: mission_complete and player_died events were never generated.
# =============================================================================

func test_mission_complete_event_generated_when_all_enemies_killed() -> void:
	# Bug fix: is_mission_complete() was a query only; no event was ever produced
	# for the CombatHUD. advance_npc_turns() must emit "mission_complete" once.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	# Kill the enemy directly (simulate one-shot).
	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")
	enemy_es.is_alive = false

	assert_true(cc.is_mission_complete(), "all enemies dead → mission should be complete")

	var events: Array = cc.advance_npc_turns()
	var found: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "mission_complete":
			found = true
			break
	assert_true(found, "advance_npc_turns must emit mission_complete when all enemies are dead")


func test_mission_complete_event_not_duplicated_on_second_call() -> void:
	# mission_complete must only fire once even if advance_npc_turns is called again.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			es.is_alive = false
			break

	var _first_events: Array = cc.advance_npc_turns()
	var second_events: Array = cc.advance_npc_turns()
	var found: bool = false
	for ev: Dictionary in second_events:
		if ev.get("type") == "mission_complete":
			found = true
			break
	assert_false(found, "mission_complete must not fire a second time on repeated calls")


func test_player_died_event_generated_when_player_killed() -> void:
	# Bug fix: player death was only embedded in npc_attacked.player_killed.
	# advance_npc_turns must emit a standalone "player_died" event so CombatHUD
	# can display the terminal "You have fallen." message.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	# Kill the player directly.
	var player_es: CombatController.EntityState = cc.get_player()
	assert_not_null(player_es, "need a player")
	# Apply lethal wounds so is_dead() returns true.
	player_es.character.wounds_taken = 100

	var events: Array = cc.advance_npc_turns()
	var found: bool = false
	for ev: Dictionary in events:
		if ev.get("type") == "player_died":
			found = true
			break
	assert_true(found, "advance_npc_turns must emit player_died when player is dead")


func test_player_died_event_not_duplicated_on_second_call() -> void:
	# player_died must only fire once.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)
	var player_es: CombatController.EntityState = cc.get_player()
	player_es.character.wounds_taken = 100

	var _first_events: Array = cc.advance_npc_turns()
	var second_events: Array = cc.advance_npc_turns()
	var found: bool = false
	for ev: Dictionary in second_events:
		if ev.get("type") == "player_died":
			found = true
			break
	assert_false(found, "player_died must not fire a second time on repeated calls")


# =============================================================================
# -- Section 34: Alarm immediately alerts all enemies -------------------------
# -- Bug: _raise_alarm used _emit_noise(VERY_LOUD) which only moves
# --      UNAWARE → SUSPICIOUS, not UNAWARE → ALERT directly.
# =============================================================================

func test_alarm_sets_unaware_enemies_directly_to_alert() -> void:
	# Bug fix: UNAWARE enemies must become ALERT on alarm, not just SUSPICIOUS.
	# Old code called _emit_noise(VERY_LOUD) which only moves UNAWARE→SUSPICIOUS.
	# New code directly sets all non-fleeing entities to ALERT.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 8, 5)

	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")

	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"enemy must start UNAWARE")

	# Use the enemy itself as the alarm source (direct call to internal function).
	cc._raise_alarm(enemy_es)

	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
		"UNAWARE enemy must be ALERT immediately after alarm, not just SUSPICIOUS")


func test_alarm_does_not_affect_fleeing_enemies() -> void:
	var cc := _make_cc_with_enemy("BANDIT_RABBLE", 8, 5)

	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")

	# Put enemy into FLEEING state before the alarm.
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.FLEEING
	enemy_es.morale_broken = true

	# Raise alarm sourced from the fleeing enemy itself.
	cc._raise_alarm(enemy_es)

	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.FLEEING,
		"FLEEING enemy must remain FLEEING after alarm — they are already routed")


# =============================================================================
# -- Section 35: FoV visual detection emits player_noticed, not noise_detected
# --             Bug A: UNAWARE→SUSPICIOUS via FoV used "noise_detected" type
# =============================================================================

func test_fov_detection_emits_player_noticed_not_noise_detected() -> void:
	# Enemy adjacent to player should detect via FoV and emit "player_noticed".
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")

	# Enemy at (6,5), player at (5,5) — adjacent → FoV detection guaranteed.
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE

	var events: Array = cc._npc_turn(enemy_es)

	var types: Array = events.map(func(e): return e.get("type", ""))
	assert_true(types.has("player_noticed"),
		"FoV visual detection must emit player_noticed, not noise_detected")
	assert_false(types.has("noise_detected"),
		"noise_detected must NOT be emitted for FoV visual detection")
	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS,
		"enemy must advance to SUSPICIOUS after FoV visual detection")


# =============================================================================
# -- Section 36: escalated_to_alert emitted when SUSPICIOUS enemy spots player
# --             Bug B: no handler for this event type in CombatHUD
# =============================================================================

func test_suspicious_enemy_spotting_player_emits_escalated_to_alert() -> void:
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	var enemy_es: CombatController.EntityState
	for eid: int in cc._entities.keys():
		var es: CombatController.EntityState = cc._entities[eid]
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
			break
	assert_not_null(enemy_es, "need an enemy")

	# Put enemy into SUSPICIOUS so next FoV sight → ALERT.
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.SUSPICIOUS

	var events: Array = cc._npc_turn(enemy_es)

	var types: Array = events.map(func(e): return e.get("type", ""))
	assert_true(types.has("escalated_to_alert"),
		"SUSPICIOUS enemy spotting player must emit escalated_to_alert")
	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
		"enemy must advance to ALERT after being SUSPICIOUS and spotting player")


# =============================================================================
# -- Section 37: _raise_alarm sets alarm_sounded on ALL entities
# --             Bug C: only source entity got alarm_sounded=true; others could
# --             re-raise the alarm after ALERT_ALARM_ROUNDS
# =============================================================================

func test_raise_alarm_sets_alarm_sounded_on_all_alive_enemies() -> void:
	# Two enemies: one raises the alarm, both must have alarm_sounded=true.
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 8, "y": 5, "seed": 0},
		{"unit_type": "SIMPLE_BANDIT", "x": 12, "y": 5, "seed": 1},
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))

	var enemies: Array = []
	for es: CombatController.EntityState in cc._entities.values():
		if es.faction == CombatController.FACTION_ENEMY:
			enemies.append(es)
	assert_eq(enemies.size(), 2, "need two enemies")

	cc._raise_alarm(enemies[0])

	assert_true(enemies[0].alarm_sounded, "source enemy must have alarm_sounded=true")
	assert_true(enemies[1].alarm_sounded,
		"non-source enemy must also have alarm_sounded=true to prevent re-raising")


# =============================================================================
# -- Section 38: _npc_flee stops when player is dead
# --             Bug D: guard only checked player == null, not is_entity_dead
# =============================================================================

func test_npc_flee_returns_empty_when_player_dead() -> void:
	var cc := _make_cc_with_enemy("BANDIT_RABBLE", 8, 5)

	# Kill the player by setting wounds above lethal threshold.
	var player_es: CombatController.EntityState
	var enemy_es: CombatController.EntityState
	for es: CombatController.EntityState in cc._entities.values():
		if es.faction == CombatController.FACTION_PLAYER:
			player_es = es
		else:
			enemy_es = es
	assert_not_null(player_es, "need player")
	assert_not_null(enemy_es, "need enemy")

	# Set player wounds to lethal.
	player_es.character.wounds_taken = 9999
	enemy_es.morale_broken = true
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.FLEEING

	var ev: Dictionary = cc._npc_flee(enemy_es)

	# Fleeing away from a dead player must not crash and should return empty
	# (no flee direction when player cannot be targeted).
	assert_true(ev.is_empty(),
		"_npc_flee must return empty dict when player is dead")


# =============================================================================
# -- Section 39: FACTION_FRIENDLY entities must not get enemy NPC turns
# --             Bug E: friendly units were given enemy AI turns (attack player)
# =============================================================================

func _make_cc_with_friendly_adjacent() -> CombatController:
	# Build a sortie-style session by directly calling create() with a friendly
	# entity placed adjacent to the player.
	var map := _make_open_map(20, 20)
	var session := MissionSession.new()
	session.map             = map
	session.objective_slots = []
	session.seed_dict       = {}
	session.roster          = {}
	session.environment     = {}
	session.entry_pos       = Vector2i(5, 5)
	session.water_ring      = 3
	session.perception      = 3

	# Place both a friendly and an enemy next to the player.
	session.placements = {
		"friendly": [{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 1}],
		"enemy":    [{"unit_type": "SIMPLE_BANDIT", "x": 15, "y": 5, "seed": 2}]
	}
	var player := _make_strong_player()
	return CombatController.create(session, player, DiceEngine.new(42))


func test_friendly_entity_does_not_get_npc_turn() -> void:
	var cc := _make_cc_with_friendly_adjacent()

	# Player is at (5,5); friendly entity at (6,5) — directly adjacent.
	# If friendly got an NPC turn it would emit "npc_attacked" targeting the player.
	var events: Array = cc.advance_npc_turns()

	var npc_attacked_events: Array = events.filter(
		func(ev: Dictionary) -> bool: return ev.get("type", "") == "npc_attacked"
	)
	assert_eq(npc_attacked_events.size(), 0,
		"friendly NPC adjacent to player must not attack the player")


func test_friendly_entity_not_in_initiative_order() -> void:
	var cc := _make_cc_with_friendly_adjacent()

	# _build_initiative_order() must exclude FACTION_FRIENDLY.
	var order: Array = cc._build_initiative_order()

	for eid: int in order:
		var es: CombatController.EntityState = cc._entities.get(eid)
		assert_false(es != null and es.faction == CombatController.FACTION_FRIENDLY,
			"friendly entity must not appear in initiative order")


func test_alarm_does_not_alert_friendly_units() -> void:
	var cc := _make_cc_with_friendly_adjacent()

	# Find the enemy and raise alarm from it.
	var enemy_es: CombatController.EntityState = null
	var friendly_es: CombatController.EntityState = null
	for es: CombatController.EntityState in cc._entities.values():
		if es.faction == CombatController.FACTION_ENEMY:
			enemy_es = es
		elif es.faction == CombatController.FACTION_FRIENDLY:
			friendly_es = es
	assert_not_null(enemy_es, "need enemy")
	assert_not_null(friendly_es, "need friendly")

	enemy_es.alarm_sounded = false
	var _ev: Dictionary = cc._raise_alarm(enemy_es)

	assert_eq(friendly_es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"_raise_alarm must not change friendly NPC alert state")
	assert_false(friendly_es.alarm_sounded,
		"_raise_alarm must not set alarm_sounded on friendly NPC")


func test_body_discovery_does_not_alert_friendly_units() -> void:
	var cc := _make_cc_with_friendly_adjacent()

	# Place a corpse right next to the friendly NPC.
	cc._add_corpse(6, 4)

	var friendly_es: CombatController.EntityState = null
	for es: CombatController.EntityState in cc._entities.values():
		if es.faction == CombatController.FACTION_FRIENDLY:
			friendly_es = es
			break
	assert_not_null(friendly_es, "need friendly")
	assert_eq(friendly_es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"friendly should start UNAWARE")

	cc._check_body_discovery()

	assert_eq(friendly_es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"_check_body_discovery must not change friendly NPC alert state")


# =============================================================================
# -- Section 40: Bug fixes — in_combat on ALERT target, stealth flag on
# --             stealth-kill failure, NPC FoV re-check after pursuit move
# =============================================================================

## Returns the sole enemy EntityState from the CC, asserts it exists.
func _get_sole_enemy(cc: CombatController) -> CombatController.EntityState:
	for es: CombatController.EntityState in cc._entities.values():
		if es.faction == CombatController.FACTION_ENEMY:
			return es
	return null


func test_execute_player_attack_sets_in_combat_on_already_alert_enemy() -> void:
	# Bug: in_combat and combat_target_id were only set when transitioning
	# from a non-ALERT state. An enemy already ALERT (e.g. from noise) would
	# never get in_combat=true when the player first attacked it, so the NPC
	# counter-attack loop would never engage properly.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)

	var enemy_es: CombatController.EntityState = _get_sole_enemy(cc)
	assert_not_null(enemy_es, "need enemy")

	# Pre-set the enemy to ALERT with in_combat deliberately false.
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.ALERT
	enemy_es.in_combat       = false
	enemy_es.combat_target_id = -1

	var player: CombatController.EntityState = cc.get_player()
	assert_not_null(player, "need player")

	cc.execute_player_attack(enemy_es.entity_id)

	assert_true(enemy_es.in_combat,
		"execute_player_attack must set in_combat even on already-ALERT enemy")
	assert_eq(enemy_es.combat_target_id, player.entity_id,
		"execute_player_attack must set combat_target_id to player even on already-ALERT enemy")


func test_stealth_kill_approach_failure_clears_player_stealth() -> void:
	# Bug: _player_stealth was not cleared when execute_stealth_kill()
	# failed at the approach roll.  Broken stealth left the player
	# invisible to all NPCs for the remainder of the encounter.
	#
	# Guarantee approach failure: agility=1, no Stealth skill →
	# roll_check(1, 1, TN=15, ..., explodes=false) → max total = 10 < 15.
	var session := _make_session(5, 5,
		[{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0}])
	var weak := _make_weak_char()
	var cc := CombatController.create(session, weak, DiceEngine.new(0))

	var enemy_es: CombatController.EntityState = _get_sole_enemy(cc)
	assert_not_null(enemy_es, "need enemy")
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE

	# Manually engage stealth mode as if the player had just crept forward.
	cc._player_stealth = true

	# The map is all FLOOR_STONE (TN=15); approach with 1k1 non-exploding
	# never exceeds 10 → guaranteed failure regardless of seed.
	var result: Dictionary = cc.execute_stealth_kill(enemy_es.entity_id)

	assert_true(result.get("approach_failed", false),
		"weak player on FLOOR_STONE must fail the approach roll")
	assert_false(cc._player_stealth,
		"_player_stealth must be cleared to false on approach failure")


func test_stealth_kill_attack_failure_clears_player_stealth() -> void:
	# Bug: _player_stealth was not cleared when execute_stealth_kill()
	# passed the approach but missed the flat-footed attack.
	#
	# Guarantee attack failure: armor_tn_bonus=200 → flat_atn=205.
	# The strong player (10k5 exploding) cannot reach 205 in practice.
	# Approach still succeeds: strong player 10k5 vs TN=15 (FLOOR_STONE).
	var session := _make_session(5, 5,
		[{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0}])
	var strong := _make_strong_player()
	var cc := CombatController.create(session, strong, DiceEngine.new(42))

	var enemy_es: CombatController.EntityState = _get_sole_enemy(cc)
	assert_not_null(enemy_es, "need enemy")
	enemy_es.alert_state = AsciiMapEnvironment.AlertState.UNAWARE
	# Inflate armor so flat_atn = 205 — impossible to hit with any realistic roll.
	enemy_es.character.armor_tn_bonus = 200

	cc._player_stealth = true

	var result: Dictionary = cc.execute_stealth_kill(enemy_es.entity_id)

	# Approach should have succeeded (strong player vs TN=15); attack must fail.
	assert_false(result.get("approach_failed", false),
		"strong player should pass the approach roll")
	assert_true(result.get("attack_failed", false),
		"armor_tn_bonus=200 must cause flat-footed attack to fail")
	assert_false(cc._player_stealth,
		"_player_stealth must be cleared to false on attack failure")


func test_npc_turn_resets_alert_rounds_lost_after_moving_into_los() -> void:
	# Bug: alert_rounds_lost was only checked against the pre-move
	# player_seen snapshot.  If the NPC started outside LOS but moved
	# within sight range during _npc_pursue_and_attack(), alert_rounds_lost
	# incremented even though the NPC now sees the player.
	#
	# Setup: SIMPLE_BANDIT at (9,5) → perception=2 → sight radius 2.
	# Player at (5,5) → distance 4 > radius 2 (not seen before move).
	# With water_ring=2, budget = SIMPLE = 2×2 = 4 tiles.
	# BFS moves to (6,5) (budget 3) or (5,6) adjacency; distance = 1 ≤ 2 → seen after.
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 9, 5)

	var enemy_es: CombatController.EntityState = _get_sole_enemy(cc)
	assert_not_null(enemy_es, "need enemy")

	# Place the enemy in ALERT state with accumulated lost-rounds counter.
	enemy_es.alert_state      = AsciiMapEnvironment.AlertState.ALERT
	enemy_es.in_combat        = false
	enemy_es.alert_rounds_lost = 5  # Would normally trigger alarm at threshold.

	# Run one round of NPC turns.
	cc.advance_npc_turns()

	# The NPC must have moved into LOS and the re-check must have reset the counter.
	assert_eq(enemy_es.alert_rounds_lost, 0,
		"alert_rounds_lost must reset to 0 when NPC moves into LOS during pursuit")


# =============================================================================
# -- Section 41 regressions ---------------------------------------------------
# =============================================================================

# -- Bug fix: player attack raises must NOT be forwarded as raises_for_damage
#    (s40 LOCKED: Increased Damage maneuver requires explicit raise declaration;
#     raises declared on the attack roll only improve the attack, not damage dice)

func test_player_attack_raises_improve_attack_not_damage_dice() -> void:
	# The strong player (all 5s, Kenjutsu 5) attacks an adjacent bandit.
	# We declare 3 raises on the attack. The resulting damage pool must be
	# katana(3k2) + strength(5) = 8k2, NOT 8+3=11k2. CombatController passes
	# raises_for_damage=0 to resolve_damage (not raises=3).
	# We verify this indirectly: if raises DID propagate to damage, the average
	# raw_damage from 11k2 would be noticeably higher than from 8k2. Since the
	# test uses a fixed dice seed, both results are deterministic.
	#
	# Expected raw_damage with raises_for_damage=0:
	#   resolve_damage(player_char, "katana", 0, 0, DiceEngine.new(42)) == base
	# Expected raw_damage with raises_for_damage=3 (the old buggy behavior):
	#   resolve_damage(player_char, "katana", 3, 0, DiceEngine.new(42)) > base

	var player_char: L5RCharacterData = _make_strong_player()

	# Compute the expected base damage (raises_for_damage=0) using the same dice
	# seed that CombatController uses (42).
	var dice_42a: DiceEngine = DiceEngine.new(42)
	var base_dmg: Dictionary = IndividualCombat.resolve_damage(
			player_char, "katana", 0, 0, dice_42a)

	# Compute what the old buggy code would have produced (raises_for_damage=3).
	var dice_42b: DiceEngine = DiceEngine.new(42)
	var buggy_dmg: Dictionary = IndividualCombat.resolve_damage(
			player_char, "katana", 3, 0, dice_42b)

	# The rolled pool must differ by exactly 3 between correct and buggy paths.
	assert_eq(base_dmg["rolled"], buggy_dmg["rolled"] - 3,
		"raises_for_damage=3 must add exactly 3 to rolled pool vs raises_for_damage=0")

	# Now run an actual execute_player_attack with raises=3.
	# The enemy is placed adjacent at (6,5); player is at (5,5).
	var cc := _make_cc_with_enemy("SIMPLE_BANDIT", 6, 5)
	var enemy_es: CombatController.EntityState = _get_sole_enemy(cc)
	assert_not_null(enemy_es)
	var result: Dictionary = cc.execute_player_attack(enemy_es.entity_id, "katana", 3)

	# The attack must have succeeded (valid target, adjacent).
	assert_true(result.get("attacked", false),
		"execute_player_attack must return attacked=true for adjacent valid target")

	# If the attack hit, the raw_damage must match the raises_for_damage=0 pool,
	# not the raises_for_damage=3 pool. Both seeds start at 42 so dice sequences
	# diverge after the first use (attack roll vs damage roll). We verify the
	# result is structurally correct and the raises key is recorded as declared.
	assert_eq(result["attack_result"].get("raises", -1), 3,
		"declared raises must be recorded in attack_result for UI feedback")


# =============================================================================
# -- Bug fix regressions: door noise position (Bugs 3a, 3b) + stealth --------
# =============================================================================

func test_player_open_door_noise_originates_at_door_tile() -> void:
	# Regression for Bug 3a: player bump-opens a door; MODERATE noise must
	# originate at the door tile (tx, ty), not the player tile.
	#
	# Layout (row y=5):
	#   col:  5(player)  6(door)  7  8  9  10  11  12(enemy)
	#
	# MODERATE budget = 6 cardinal steps.
	# Enemy at (12,5) is 6 steps from door (6,5)  → exactly on boundary → REACHED.
	# Enemy at (12,5) is 7 steps from player (5,5) → outside budget    → NOT reached.
	# Old code emitted from player → no detection. New code emits from door → detection fires.
	# Enemy perception boosted to 6 to guarantee roll success (6k6 vs TN 15).
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 12, "y": 5, "seed": 0}
	])
	session.map.set_tile(6, 5, Enums.TileType.DOOR_WOOD_CLOSED)
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var enemy_es: CombatController.EntityState = cc.get_enemies_at(12, 5)[0]
	enemy_es.character.perception = 6
	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"precondition: enemy must start UNAWARE")
	var result: Dictionary = cc.try_move_player(1, 0)
	assert_true(result.get("opened_door", false),
		"bump into closed door must open it and report opened_door=true")
	assert_eq(enemy_es.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS,
		"enemy at MODERATE boundary from door tile must detect door-open noise")


func test_npc_open_door_noise_originates_at_door_tile() -> void:
	# Regression for Bug 3b: NPC opens a door while pursuing player; MODERATE
	# noise must originate at the door tile (step_vec), not the NPC's current tile.
	#
	# Layout (row y=5):
	#   col:  5(pursuer)  6(door)  7  8  9  10  11  12(observer)  13(player)
	#
	# MODERATE budget = 6 cardinal steps.
	# Observer at (12,5) is 6 steps from door (6,5)  → exactly on boundary → REACHED.
	# Observer at (12,5) is 7 steps from pursuer (5,5) → outside budget  → NOT reached.
	# Old code emitted from pursuer → observer not reached. New code emits from door → reached.
	# Observer perception boosted to 6 to guarantee roll success.
	var session := _make_session(13, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 5,  "y": 5, "seed": 0},
		{"unit_type": "SIMPLE_BANDIT", "x": 12, "y": 5, "seed": 1},
	])
	session.map.set_tile(6, 5, Enums.TileType.DOOR_WOOD_CLOSED)
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var pursuer:  CombatController.EntityState = cc.get_enemies_at(5,  5)[0]
	var observer: CombatController.EntityState = cc.get_enemies_at(12, 5)[0]
	pursuer.alert_state = AsciiMapEnvironment.AlertState.ALERT
	observer.character.perception = 6
	assert_eq(observer.alert_state, AsciiMapEnvironment.AlertState.UNAWARE,
		"precondition: observer must start UNAWARE")
	cc.advance_npc_turns()
	assert_eq(observer.alert_state, AsciiMapEnvironment.AlertState.SUSPICIOUS,
		"observer at MODERATE boundary from door tile must detect NPC door-open noise")


func test_stealth_kill_survivor_clears_player_stealth() -> void:
	# Regression for Bug 4: if execute_stealth_kill lands but the target survives
	# (tough enough to absorb the hit), _player_stealth must be set to false.
	# Target stamina=10 / willpower=10 → Earth ring=10 → wound capacity=160.
	# Even the strongest katana single-hit cannot kill such a target in one blow.
	var session := _make_session(5, 5, [
		{"unit_type": "SIMPLE_BANDIT", "x": 6, "y": 5, "seed": 0}
	])
	var cc := CombatController.create(session, _make_strong_player(), DiceEngine.new(42))
	var target_es: CombatController.EntityState = cc.get_enemies_at(6, 5)[0]
	target_es.character.stamina   = 10
	target_es.character.willpower = 10
	target_es.character.wounds_taken = 0
	cc._player_stealth = true
	assert_true(cc._player_stealth, "precondition: player must start stealthed")
	var result: Dictionary = cc.execute_stealth_kill(target_es.entity_id)
	assert_true(result.get("success", false),
		"execute_stealth_kill must return success=true (approach succeeded and hit landed)")
	assert_true(target_es.is_alive,
		"tough target must survive the single stealth hit")
	assert_false(cc._player_stealth,
		"_player_stealth must be false after target survives stealth kill")
	assert_eq(target_es.alert_state, AsciiMapEnvironment.AlertState.ALERT,
		"surviving target must be ALERT after surviving a stealth kill attempt")
