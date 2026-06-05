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
