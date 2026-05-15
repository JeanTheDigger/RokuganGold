extends Node
## Server-side character sheet persistence.
## Each character is stored as <save_dir>/<character_id>.tres
## character_id is the stable unique key — never use Resource.name as a file key.

const SAVE_DIR := "user://saves/characters/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# -- Single character ----------------------------------------------------------

func save_character(
	char_data: L5RCharacterData,
	save_dir: String = SAVE_DIR,
) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := save_dir + str(char_data.character_id) + ".tres"
	var err := ResourceSaver.save(char_data, path)
	if err != OK:
		push_error("SaveManager: failed to save character %d (%s)" % [
			char_data.character_id, error_string(err)
		])
		return false
	return true


func load_character(
	character_id: int,
	save_dir: String = SAVE_DIR,
) -> L5RCharacterData:
	var path := save_dir + str(character_id) + ".tres"
	if not FileAccess.file_exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res == null or not res is L5RCharacterData:
		push_error("SaveManager: load failed for character_id %d" % character_id)
		return null
	return res as L5RCharacterData


func delete_character(character_id: int, save_dir: String = SAVE_DIR) -> void:
	var path := save_dir + str(character_id) + ".tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# -- Bulk operations -----------------------------------------------------------

func save_all(
	characters: Array[L5RCharacterData],
	save_dir: String = SAVE_DIR,
) -> int:
	var saved: int = 0
	for c: L5RCharacterData in characters:
		if save_character(c, save_dir):
			saved += 1
	return saved


func load_all(save_dir: String = SAVE_DIR) -> Array[L5RCharacterData]:
	var result: Array[L5RCharacterData] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var id_str: String = fname.trim_suffix(".tres")
			if id_str.is_valid_int():
				var c: L5RCharacterData = load_character(id_str.to_int(), save_dir)
				if c != null:
					result.append(c)
		fname = dir.get_next()
	dir.list_dir_end()
	return result
