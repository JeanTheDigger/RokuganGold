extends GutTest
## Tests for SaveManager — character sheet persistence.
## Uses a scratch directory (user://test_saves/) isolated from production data.

const SaveManagerScript = preload("res://scripts/managers/SaveManager.gd")
const TEST_DIR := "user://test_saves/characters/"


var _sm: Node


func before_each() -> void:
	_sm = SaveManagerScript.new()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_each() -> void:
	_sm.queue_free()
	_purge_test_dir()


func _purge_test_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(TEST_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _make_character(id: int, name: String = "Test") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.clan = "Crab"
	c.family = "Hida"
	c.school = "Hida Bushi"
	c.stamina = 3
	c.honor = 3.5
	return c


# -- save_character ------------------------------------------------------------

func test_save_character_returns_true_on_success() -> void:
	var c := _make_character(42)
	var ok: bool = _sm.save_character(c, TEST_DIR)
	assert_true(ok, "save_character should return true on success")


func test_save_character_creates_file_keyed_by_character_id() -> void:
	var c := _make_character(99)
	_sm.save_character(c, TEST_DIR)
	assert_true(
		FileAccess.file_exists(TEST_DIR + "99.tres"),
		"File should be named <character_id>.tres"
	)


func test_save_does_not_create_file_named_after_resource_name() -> void:
	var c := _make_character(99)
	c.resource_name = "some_other_name"
	_sm.save_character(c, TEST_DIR)
	assert_false(
		FileAccess.file_exists(TEST_DIR + "some_other_name.tres"),
		"File must not use Resource.name as key"
	)


# -- load_character ------------------------------------------------------------

func test_load_character_returns_null_for_missing_id() -> void:
	var result: L5RCharacterData = _sm.load_character(99999, TEST_DIR)
	assert_null(result, "Missing character_id should return null")


func test_load_character_round_trips_correctly() -> void:
	var original := _make_character(7, "Hida Kisada")
	original.strength = 4
	original.glory = 6.0
	_sm.save_character(original, TEST_DIR)

	var loaded: L5RCharacterData = _sm.load_character(7, TEST_DIR)
	assert_not_null(loaded, "Loaded character should not be null")
	assert_eq(loaded.character_id, 7, "character_id must survive round-trip")
	assert_eq(loaded.character_name, "Hida Kisada", "character_name must survive round-trip")
	assert_eq(loaded.clan, "Crab", "clan must survive round-trip")
	assert_eq(loaded.strength, 4, "trait value must survive round-trip")
	assert_eq(loaded.glory, 6.0, "glory must survive round-trip")


func test_load_character_is_l5r_character_data() -> void:
	var c := _make_character(5)
	_sm.save_character(c, TEST_DIR)
	var loaded: L5RCharacterData = _sm.load_character(5, TEST_DIR)
	assert_true(loaded is L5RCharacterData, "Loaded resource must be L5RCharacterData")


# -- delete_character ----------------------------------------------------------

func test_delete_removes_file() -> void:
	var c := _make_character(11)
	_sm.save_character(c, TEST_DIR)
	assert_true(FileAccess.file_exists(TEST_DIR + "11.tres"), "File should exist before delete")
	_sm.delete_character(11, TEST_DIR)
	assert_false(FileAccess.file_exists(TEST_DIR + "11.tres"), "File should be gone after delete")


func test_delete_nonexistent_character_does_not_error() -> void:
	_sm.delete_character(99999, TEST_DIR)
	pass  # No error = pass


# -- save_all / load_all -------------------------------------------------------

func test_save_all_returns_count_of_saved_characters() -> void:
	var chars: Array[L5RCharacterData] = [
		_make_character(100),
		_make_character(101),
		_make_character(102),
	]
	var count: int = _sm.save_all(chars, TEST_DIR)
	assert_eq(count, 3, "save_all should return 3 for 3 characters")


func test_load_all_returns_all_saved_characters() -> void:
	var chars: Array[L5RCharacterData] = [
		_make_character(200),
		_make_character(201),
		_make_character(202),
	]
	_sm.save_all(chars, TEST_DIR)
	var loaded: Array[L5RCharacterData] = _sm.load_all(TEST_DIR)
	assert_eq(loaded.size(), 3, "load_all should find all 3 saved characters")


func test_load_all_restores_correct_ids() -> void:
	var chars: Array[L5RCharacterData] = [
		_make_character(300),
		_make_character(301),
	]
	_sm.save_all(chars, TEST_DIR)
	var loaded: Array[L5RCharacterData] = _sm.load_all(TEST_DIR)
	var ids: Array[int] = []
	for c: L5RCharacterData in loaded:
		ids.append(c.character_id)
	ids.sort()
	assert_eq(ids, [300, 301], "Loaded IDs must match saved IDs")


func test_load_all_returns_empty_for_empty_directory() -> void:
	var loaded: Array[L5RCharacterData] = _sm.load_all(TEST_DIR)
	assert_eq(loaded.size(), 0, "Empty directory should yield no characters")


func test_save_all_overwrites_existing_file_with_updated_data() -> void:
	var c := _make_character(400, "Hiruma Scout")
	_sm.save_character(c, TEST_DIR)

	c.stamina = 5
	var batch: Array[L5RCharacterData] = [c]
	_sm.save_all(batch, TEST_DIR)

	var loaded: L5RCharacterData = _sm.load_character(400, TEST_DIR)
	assert_eq(loaded.stamina, 5, "Overwrite should persist updated stamina")
