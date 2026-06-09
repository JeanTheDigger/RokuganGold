extends GutTest
## Smoke test: the CombatDemo entry point boots a playable skirmish.

func test_demo_boots_a_running_mission() -> void:
	var demo := CombatDemo.new()
	add_child_autofree(demo)
	# _ready() builds the fixture and starts the mission.
	var screen: CombatScreen = demo.get_node("CombatScreen")
	assert_not_null(screen, "CombatScreen child created")
	var cc: CombatController = screen.get_controller()
	assert_not_null(cc, "mission started with a live CombatController")


func test_demo_session_is_valid() -> void:
	var demo := CombatDemo.new()
	var session: MissionSession = demo._make_session()
	assert_true(session.is_valid(), "fixture session has a passable entry tile")
	assert_eq(session.placements.size(), 2, "two bandit placements")


func test_demo_player_is_dual_wielding() -> void:
	var demo := CombatDemo.new()
	var p: L5RCharacterData = demo._make_player()
	assert_eq(p.off_hand_weapon, "wakizashi", "Mirumoto daisho off-hand set")
