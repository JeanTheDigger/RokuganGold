class_name ScoringTableLoader
## Loads and caches the eight JSON scoring tables used by the NPC Decision
## Engine per GDD s55.14. Tables live under res://systems/npc_engine/data/tables/.

const TABLE_PATH: String = "res://systems/npc_engine/data/tables/"

const TABLE_NAMES: Array[String] = [
	"objective_alignment",
	"personality_lean",
	"personality_filter",
	"action_skill_map",
	"competence_table",
	"disposition_tiers",
	"urgency_rules",
	"topic_position_alignment",
]

var _cache: Dictionary = {}
var _loaded: bool = false


func load_all() -> bool:
	_cache.clear()
	var all_ok: bool = true
	for table_name: String in TABLE_NAMES:
		var data: Variant = _load_json(TABLE_PATH + table_name + ".json")
		if data == null:
			all_ok = false
			_cache[table_name] = {}
		else:
			_cache[table_name] = data
	_loaded = all_ok
	return all_ok


func get_table(table_name: String) -> Variant:
	if _cache.has(table_name):
		return _cache[table_name]
	return {}


func get_scoring_tables() -> Dictionary:
	return {
		"objective_alignment": get_table("objective_alignment"),
		"personality_lean": get_table("personality_lean"),
		"personality_filter": get_table("personality_filter"),
		"action_skill_map": get_table("action_skill_map"),
		"competence_table": get_table("competence_table"),
		"disposition_tiers": get_table("disposition_tiers"),
		"urgency_rules": get_table("urgency_rules"),
		"topic_position_alignment": get_table("topic_position_alignment"),
	}


func get_filter_data() -> Dictionary:
	return get_table("personality_filter")


func is_loaded() -> bool:
	return _loaded


static func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return null
	return json.data
