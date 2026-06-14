class_name CombatDemo
extends Control
## Stand-in entry point that boots a playable ASCII-map skirmish end-to-end.
##
## The real entry point — the world-map → mission trigger — is design-pending
## (PC world-map travel is on hold, s56/s60). This demo wires the existing
## pipeline directly so a skirmish is actually playable: it builds a small
## hand-made MissionSession (a stone room + a couple of bandits), hands it to a
## CombatScreen, and starts the mission. The player controls a dual-wielding
## Mirumoto bushi so the off-hand attack is exercised.
##
## Controls (handled by AsciiMapView):
##   numpad 1-9 / WASD+QEZC — move (bump into an enemy to attack)
##   numpad 5 / period      — wait
##   S                      — toggle stealth mode (in combat)
##   L                      — look mode (Esc exits)
##   X                      — End Combat (turn-based, field clear)
##   R                      — restart this demo skirmish

const _MAP_W: int = 17
const _MAP_H: int = 13

var _screen: CombatScreen = null
var _status: Label = null


func _ready() -> void:
	_screen = CombatScreen.new()
	_screen.name = "CombatScreen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	_status = Label.new()
	_status.name = "Status"
	_status.position = Vector2(8, 8)
	_status.add_theme_color_override("font_color", Color(1, 1, 0.6))
	add_child(_status)

	_screen.mission_complete.connect(_on_complete)
	_screen.player_died.connect(_on_died)

	_start()


## Build the fixture and boot the mission.
func _start() -> void:
	var player: L5RCharacterData = _make_player()
	var session: MissionSession = _make_session()
	var dice := DiceEngine.new(randi())
	if _screen.start_mission(session, player, dice):
		_status.text = "Skirmish — move with WASD/numpad, bump to attack. X=End Combat, R=restart."
	else:
		_status.text = "Failed to start mission (invalid session)."


func _on_complete() -> void:
	_status.text = "Victory — all enemies defeated. Press R to fight again."


func _on_died() -> void:
	_status.text = "You have fallen. Press R to try again."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_R:
		_screen.end_mission()
		_start()
		get_viewport().set_input_as_handled()


# -- Fixture construction -----------------------------------------------------

## A capable dual-wielding bushi (Mirumoto daisho) so the off-hand swing shows.
func _make_player() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Mirumoto Player"
	c.clan = "Dragon"
	c.family = "Mirumoto"
	c.school = "Mirumoto Bushi"
	c.school_type = Enums.SchoolType.BUSHI
	c.insight_rank = 3
	c.stamina = 3; c.willpower = 3
	c.agility = 4; c.intelligence = 2
	c.reflexes = 4; c.awareness = 3
	c.strength = 3; c.perception = 3
	c.void_ring = 3
	c.current_void_points = 3
	c.wounds_taken = 0
	c.skills = {"Kenjutsu": 4, "Defense": 3, "Athletics": 2, "Iaijutsu": 3}
	c.off_hand_weapon = "wakizashi"  # s40 Dragon daisho
	c.is_pc = true
	return c


## A 17×13 stone room (wall border, FLOOR_STONE interior) with two bandits.
func _make_session() -> MissionSession:
	var m := AsciiMapData.new()
	m.width = _MAP_W
	m.height = _MAP_H
	m.seed_string = "combat_demo"
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	# Wall border.
	for x: int in range(_MAP_W):
		m.set_tile(x, 0, Enums.TileType.WALL_STONE)
		m.set_tile(x, _MAP_H - 1, Enums.TileType.WALL_STONE)
	for y: int in range(_MAP_H):
		m.set_tile(0, y, Enums.TileType.WALL_STONE)
		m.set_tile(_MAP_W - 1, y, Enums.TileType.WALL_STONE)
	# A couple of interior pillars for cover.
	m.set_tile(8, 5, Enums.TileType.WALL_STONE)
	m.set_tile(8, 7, Enums.TileType.WALL_STONE)

	var result: Dictionary = {
		"map": m,
		"entry_pos": Vector2i(2, 6),
		"placements": [
			{"unit_type": "RONIN_BANDIT", "x": 13, "y": 4, "seed": 1},
			{"unit_type": "RONIN_BANDIT", "x": 13, "y": 8, "seed": 2},
		],
		"objective_slots": [],
		"seed_dict": {"seed_type": "SEED_RONIN_BANDIT"},
		"roster": {},
		"environment": {"weather": AsciiMapEnvironment.WeatherState.CLEAR, "fov_modifier": 0},
	}
	return MissionSession.from_builder(result, mini(3, 3), 3)
