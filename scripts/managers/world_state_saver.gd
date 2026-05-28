class_name WorldStateSaver
extends RefCounted
## Persists and restores the full WorldStateData to/from disk.
## Resource-typed arrays are saved via ResourceSaver (one .tres per item).
## Dictionary/primitive state is saved as JSON.
## Call save_world() after each tick and load_world() on startup.

var BASE_DIR: String = "user://saves/world/"

# Sub-directories for Resource collections
const DIR_CHARACTERS := "characters/"
const DIR_TOPICS := "topics/"
const DIR_LETTERS := "letters/"
const DIR_COMMITMENTS := "commitments/"
const DIR_CRIMES := "crimes/"
const DIR_INSURGENCIES := "insurgencies/"
const DIR_COURTS := "courts/"
const DIR_EDICTS := "edicts/"
const DIR_HORDES := "hordes/"
const DIR_SHIPS := "ships/"
const DIR_CHILDREN := "children/"
const DIR_CONSTRUCTIONS := "constructions/"
const DIR_COURT_COMMITMENTS := "court_commitments/"
const DIR_SUCCESSIONS := "successions/"
const DIR_WARS := "wars/"
const DIR_PROVINCES := "provinces/"
const DIR_SETTLEMENTS := "settlements/"
const DIR_SECRETS := "secrets/"
const DIR_FAVORS := "favors/"
const DIR_TATTOOS := "tattoos/"
const DIR_TRADE_ROUTES := "trade_routes/"
const DIR_SPIRITUAL_EVENTS := "spiritual_events/"
const DIR_BLOODSPEAKER_CELLS := "bloodspeaker_cells/"
const DIR_CRAFTED_ITEMS := "crafted_items/"


# ============================================================================
# PUBLIC API
# ============================================================================

func save_world(ws: Node) -> bool:
	var base: String = BASE_DIR
	_ensure_dirs(base)

	var ok: bool = true
	ok = _save_resource_array(ws.characters, base + DIR_CHARACTERS, "character_id") and ok
	ok = _save_resource_array(ws.active_topics, base + DIR_TOPICS, "topic_id") and ok
	ok = _save_resource_array(ws.commitments, base + DIR_COMMITMENTS, "commitment_id") and ok
	ok = _save_resource_array(ws.crime_records, base + DIR_CRIMES, "case_id") and ok
	ok = _save_resource_array(ws.insurgencies, base + DIR_INSURGENCIES, "insurgency_id") and ok
	ok = _save_resource_array(ws.active_courts, base + DIR_COURTS, "court_id") and ok
	ok = _save_resource_array(ws.active_edicts, base + DIR_EDICTS, "edict_id") and ok
	ok = _save_resource_array_by_index(ws.active_hordes, base + DIR_HORDES) and ok
	ok = _save_resource_array(ws.ships, base + DIR_SHIPS, "ship_id") and ok
	ok = _save_resource_array(ws.children, base + DIR_CHILDREN, "child_id") and ok
	ok = _save_resource_array(ws.constructions, base + DIR_CONSTRUCTIONS, "construction_id") and ok
	ok = _save_resource_array_by_index(ws.court_commitments, base + DIR_COURT_COMMITMENTS) and ok
	ok = _save_resource_array(ws.active_successions, base + DIR_SUCCESSIONS, "succession_id") and ok
	ok = _save_resource_array(ws.active_wars, base + DIR_WARS, "war_id") and ok
	ok = _save_resource_array(ws.active_secrets, base + DIR_SECRETS, "secret_id") and ok
	ok = _save_resource_array(ws.tattoos, base + DIR_TATTOOS, "tattoo_id") and ok
	ok = _save_resource_array(ws.spiritual_insurgency_events, base + DIR_SPIRITUAL_EVENTS, "event_id") and ok
	ok = _save_resource_array(ws.bloodspeaker_cells, base + DIR_BLOODSPEAKER_CELLS, "cell_id") and ok
	ok = _save_resource_array(ws.crafted_items, base + DIR_CRAFTED_ITEMS, "item_id") and ok

	# Provinces and settlements use their own ID fields
	ok = _save_resource_array(ws.settlements, base + DIR_SETTLEMENTS, "settlement_id") and ok
	ok = _save_province_dict(ws.provinces, base + DIR_PROVINCES) and ok

	# Favors — may be FavorData Resources or plain Dictionaries depending on source
	ok = _save_favors(ws.favors, base + DIR_FAVORS) and ok

	# Letters — may be LetterData Resources
	ok = _save_letters(ws.pending_letters, base + DIR_LETTERS) and ok

	# Trade routes
	ok = _save_resource_array(ws.trade_routes, base + DIR_TRADE_ROUTES, "route_id") and ok

	# Clans — keyed by clan name
	ok = _save_clans(ws.clans, base) and ok

	# JSON state blob for everything else
	ok = _save_json_state(ws, base) and ok

	return ok


func load_world(ws: Node) -> bool:
	var base: String = BASE_DIR
	if not DirAccess.dir_exists_absolute(base):
		return false

	ws.characters.assign(_load_resource_array(base + DIR_CHARACTERS))
	ws.rebuild_characters_by_id()
	ws.active_topics.assign(_load_resource_array(base + DIR_TOPICS))
	ws.commitments.assign(_load_resource_array(base + DIR_COMMITMENTS))
	ws.crime_records.assign(_load_resource_array(base + DIR_CRIMES))
	ws.insurgencies.assign(_load_resource_array(base + DIR_INSURGENCIES))
	ws.active_courts.assign(_load_resource_array(base + DIR_COURTS))
	ws.active_edicts.assign(_load_resource_array(base + DIR_EDICTS))
	ws.active_hordes.assign(_load_resource_array(base + DIR_HORDES))
	ws.ships.assign(_load_resource_array(base + DIR_SHIPS))
	ws.children.assign(_load_resource_array(base + DIR_CHILDREN))
	ws.constructions.assign(_load_resource_array(base + DIR_CONSTRUCTIONS))
	ws.court_commitments.assign(_load_resource_array(base + DIR_COURT_COMMITMENTS))
	ws.active_successions.assign(_load_resource_array(base + DIR_SUCCESSIONS))
	ws.active_wars.assign(_load_resource_array(base + DIR_WARS))
	ws.active_secrets.assign(_load_resource_array(base + DIR_SECRETS))
	ws.tattoos.assign(_load_resource_array(base + DIR_TATTOOS))
	ws.spiritual_insurgency_events.assign(_load_resource_array(base + DIR_SPIRITUAL_EVENTS))
	ws.bloodspeaker_cells.assign(_load_resource_array(base + DIR_BLOODSPEAKER_CELLS))
	ws.crafted_items.assign(_load_resource_array(base + DIR_CRAFTED_ITEMS))
	ws.settlements.assign(_load_resource_array(base + DIR_SETTLEMENTS))
	ws.provinces = _load_province_dict(base + DIR_PROVINCES)
	ws.favors = _load_favors(base + DIR_FAVORS)
	ws.pending_letters = _load_letters(base + DIR_LETTERS)
	ws.clans = _load_clans(base)
	ws.trade_routes.assign(_load_resource_array(base + DIR_TRADE_ROUTES))

	_load_json_state(ws, base)
	_reconcile_id_counters(ws)

	return true


# ============================================================================
# RESOURCE ARRAY HELPERS
# ============================================================================

func _save_resource_array(arr: Array, dir_path: String, id_field: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	_purge_directory(dir_path)
	var ok: bool = true
	for item: Resource in arr:
		var id_val: int = item.get(id_field)
		var path: String = dir_path + str(id_val) + ".tres"
		var err := ResourceSaver.save(item, path)
		if err != OK:
			push_error("WorldStateSaver: failed to save %s id=%d: %s" % [
				id_field, id_val, error_string(err)])
			ok = false
	return ok


func _save_resource_array_by_index(arr: Array, dir_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	_purge_directory(dir_path)
	var ok: bool = true
	for i: int in range(arr.size()):
		var item: Resource = arr[i]
		var path: String = dir_path + str(i) + ".tres"
		var err := ResourceSaver.save(item, path)
		if err != OK:
			push_error("WorldStateSaver: failed to save index %d in %s: %s" % [
				i, dir_path, error_string(err)])
			ok = false
	return ok


func _load_resource_array(dir_path: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(dir_path + fname)
			if res != null:
				result.append(res)
			else:
				push_warning("WorldStateSaver: Failed to load resource: %s%s" % [dir_path, fname])
		fname = dir.get_next()
	dir.list_dir_end()
	return result


# ============================================================================
# PROVINCE DICT (keyed by province_id)
# ============================================================================

func _save_province_dict(provinces: Dictionary, dir_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	_purge_directory(dir_path)
	var ok: bool = true
	for key: Variant in provinces:
		var prov: ProvinceData = provinces[key]
		var path: String = dir_path + str(prov.province_id) + ".tres"
		var err := ResourceSaver.save(prov, path)
		if err != OK:
			push_error("WorldStateSaver: failed to save province %d" % prov.province_id)
			ok = false
	return ok


func _load_province_dict(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(dir_path + fname)
			if res is ProvinceData:
				result[res.province_id] = res
		fname = dir.get_next()
	dir.list_dir_end()
	return result


# ============================================================================
# CLANS — Dictionary keyed by clan name -> ClanData
# ============================================================================

func _save_clans(clans: Dictionary, base: String) -> bool:
	var clans_path: String = base + "clans.json"
	var data: Dictionary = {}
	for key: Variant in clans:
		var cd: ClanData = clans[key]
		data[str(key)] = {
			"clan_name": cd.clan_name,
			"iron_stockpile": cd.iron_stockpile,
			"arms_stockpile": cd.arms_stockpile,
			"champion_id": cd.champion_id,
			"province_ids": cd.province_ids,
		}
	var file := FileAccess.open(clans_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _load_clans(base: String) -> Dictionary:
	var result: Dictionary = {}
	var clans_path: String = base + "clans.json"
	if not FileAccess.file_exists(clans_path):
		return result
	var file := FileAccess.open(clans_path, FileAccess.READ)
	if file == null:
		return result
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return result
	file.close()
	var data: Dictionary = json.data
	for key: String in data:
		var entry: Dictionary = data[key]
		var cd := ClanData.new()
		cd.clan_name = entry.get("clan_name", "")
		cd.iron_stockpile = float(entry.get("iron_stockpile", 0.0))
		cd.arms_stockpile = float(entry.get("arms_stockpile", 0.0))
		cd.champion_id = int(entry.get("champion_id", -1))
		cd.province_ids = entry.get("province_ids", [])
		result[key] = cd
	return result


# ============================================================================
# FAVORS — handles both FavorData Resources and legacy Dictionaries
# ============================================================================

func _save_favors(favors: Array, dir_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	_purge_directory(dir_path)
	var ok: bool = true
	for i: int in range(favors.size()):
		var item: Variant = favors[i]
		if item is FavorData:
			var path: String = dir_path + str(item.favor_id) + ".tres"
			var err := ResourceSaver.save(item, path)
			if err != OK:
				ok = false
		else:
			var path: String = dir_path + "dict_" + str(i) + ".json"
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(item))
				file.close()
	return ok


func _load_favors(dir_path: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			if fname.ends_with(".tres"):
				var res: Resource = ResourceLoader.load(dir_path + fname)
				if res != null:
					result.append(res)
			elif fname.ends_with(".json"):
				var file := FileAccess.open(dir_path + fname, FileAccess.READ)
				if file:
					var json := JSON.new()
					if json.parse(file.get_as_text()) == OK:
						result.append(json.data)
					file.close()
		fname = dir.get_next()
	dir.list_dir_end()
	return result


# ============================================================================
# LETTERS — LetterData Resources
# ============================================================================

func _save_letters(letters: Array, dir_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	_purge_directory(dir_path)
	var ok: bool = true
	for i: int in range(letters.size()):
		var item: Variant = letters[i]
		if item is LetterData:
			var path: String = dir_path + str(item.letter_id) + ".tres"
			var err := ResourceSaver.save(item, path)
			if err != OK:
				ok = false
		else:
			var path: String = dir_path + "dict_" + str(i) + ".json"
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(item))
				file.close()
	return ok


func _load_letters(dir_path: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			if fname.ends_with(".tres"):
				var res: Resource = ResourceLoader.load(dir_path + fname)
				if res != null:
					result.append(res)
			elif fname.ends_with(".json"):
				var file := FileAccess.open(dir_path + fname, FileAccess.READ)
				if file:
					var json := JSON.new()
					if json.parse(file.get_as_text()) == OK:
						result.append(json.data)
					file.close()
		fname = dir.get_next()
	dir.list_dir_end()
	return result


# ============================================================================
# JSON STATE — all Dictionary and primitive fields
# ============================================================================

func _save_json_state(ws: Node, base: String) -> bool:
	var state: Dictionary = {
		# Time
		"current_tick": ws.time_system.current_tick,
		"start_year": ws.time_system.start_year,

		# ID counters
		"next_case_id": ws.next_case_id[0],
		"next_topic_id": ws.next_topic_id[0],
		"next_insurgency_id": ws.next_insurgency_id[0],
		"next_succession_id": ws.next_succession_id[0],
		"next_company_id": ws.next_company_id[0],
		"next_war_id": ws.next_war_id[0],
		"next_court_id": ws.next_court_id[0],
		"next_edict_id": ws.next_edict_id[0],
		"next_character_id": ws.next_character_id[0],
		"next_settlement_id": ws.next_settlement_id[0],
		"next_construction_id": ws.next_construction_id[0],
		"next_secret_id": ws.next_secret_id[0],
		"next_commitment_id": ws.next_commitment_id[0],
		"next_crisis_id": ws.next_crisis_id[0],
		"next_tattoo_id": ws.next_tattoo_id[0],
		"next_hunt_id": ws.next_hunt_id[0],
		"next_spiritual_event_id": ws.next_spiritual_event_id[0],
		"next_cell_id": ws.next_cell_id[0],
		"next_item_id": ws.next_item_id[0],
		"last_targeted_province_id": ws.last_targeted_province_id[0],

		# Emperor
		"emperor_id": ws.emperor_id,
		"emperor_settlement_id": ws.emperor_settlement_id,
		"emperor_archetype": ws.emperor_archetype,
		"miya_representative_id": ws.miya_representative_id,

		# NPC engine (persistent between ticks)
		"objectives_map": ws.objectives_map,
		"season_meta": ws.season_meta,

		# Supplementary arrays of plain dicts
		"military_data": ws.military_data,
		"successor_map": ws.successor_map,
		"entanglements": ws.entanglements,
		"bound_states": ws.bound_states,
		"active_armies": ws.active_armies,
		"active_sieges": ws.active_sieges,
		"active_tethers": ws.active_tethers,
		"order_states": ws.order_states,
		"military_companies": ws.military_companies,
		"marriages": ws.marriages,
		"active_assassination_ops": ws.active_assassination_ops,
		"active_civil_wars": ws.active_civil_wars,
		"precedent_modifiers": ws.precedent_modifiers,
		"approach_penalties": ws.approach_penalties,
		"active_hunts": ws.active_hunts,
		"active_hostages": ws.active_hostages,

		# Horde counters
		"horde_strength_counters": ws.horde_strength_counters,

		# Collective disposition
		"clan_baselines": ws.clan_baselines,
		"family_baselines": ws.family_baselines,
		"marriage_clan_boosts": ws.marriage_clan_boosts,
		"marriage_family_boosts": ws.marriage_family_boosts,

		# Governance states
		"seiyaku_state": ws.seiyaku_state,
		"togashi_state": ws.togashi_state,
		"phoenix_council_state": ws.phoenix_council_state,
		"worship_state": ws.worship_state,

		# Disposition snapshots
		"disposition_snapshots": ws.disposition_snapshots,
	}

	var path: String = base + "state.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("WorldStateSaver: cannot open %s for writing" % path)
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return true


func _load_json_state(ws: Node, base: String) -> void:
	var path: String = base + "state.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("WorldStateSaver: failed to parse %s" % path)
		return

	var state: Dictionary = json.data

	# Time
	if state.has("current_tick"):
		ws.time_system.current_tick = int(state["current_tick"])
	if state.has("start_year"):
		ws.time_system.start_year = int(state["start_year"])

	# ID counters
	_restore_counter(ws.next_case_id, state, "next_case_id")
	_restore_counter(ws.next_topic_id, state, "next_topic_id")
	_restore_counter(ws.next_insurgency_id, state, "next_insurgency_id")
	_restore_counter(ws.next_succession_id, state, "next_succession_id")
	_restore_counter(ws.next_company_id, state, "next_company_id")
	_restore_counter(ws.next_war_id, state, "next_war_id")
	_restore_counter(ws.next_court_id, state, "next_court_id")
	_restore_counter(ws.next_edict_id, state, "next_edict_id")
	_restore_counter(ws.next_character_id, state, "next_character_id")
	_restore_counter(ws.next_settlement_id, state, "next_settlement_id")
	_restore_counter(ws.next_construction_id, state, "next_construction_id")
	_restore_counter(ws.next_secret_id, state, "next_secret_id")
	_restore_counter(ws.next_commitment_id, state, "next_commitment_id")
	_restore_counter(ws.next_crisis_id, state, "next_crisis_id")
	_restore_counter(ws.next_tattoo_id, state, "next_tattoo_id")
	_restore_counter(ws.next_hunt_id, state, "next_hunt_id")
	_restore_counter(ws.next_spiritual_event_id, state, "next_spiritual_event_id")
	_restore_counter(ws.next_cell_id, state, "next_cell_id")
	_restore_counter(ws.next_item_id, state, "next_item_id")
	_restore_counter(ws.last_targeted_province_id, state, "last_targeted_province_id")

	# Emperor
	ws.emperor_id = int(state.get("emperor_id", -1))
	ws.emperor_settlement_id = int(state.get("emperor_settlement_id", -1))
	ws.emperor_archetype = int(state.get("emperor_archetype", 0))
	ws.miya_representative_id = int(state.get("miya_representative_id", -1))

	# NPC engine
	ws.objectives_map = state.get("objectives_map", {})
	ws.season_meta = state.get("season_meta", {})

	# Supplementary
	ws.military_data = state.get("military_data", {})
	ws.successor_map = state.get("successor_map", {})
	ws.entanglements.assign(state.get("entanglements", []))
	ws.bound_states.assign(state.get("bound_states", []))
	ws.active_armies.assign(state.get("active_armies", []))
	ws.active_sieges.assign(state.get("active_sieges", []))
	ws.active_tethers.assign(state.get("active_tethers", []))
	ws.order_states.assign(state.get("order_states", []))
	ws.military_companies.assign(state.get("military_companies", []))
	ws.marriages.assign(state.get("marriages", []))
	ws.active_assassination_ops.assign(state.get("active_assassination_ops", []))
	ws.active_civil_wars.assign(state.get("active_civil_wars", []))
	ws.precedent_modifiers = state.get("precedent_modifiers", {})
	ws.approach_penalties.assign(state.get("approach_penalties", []))
	ws.active_hunts.assign(state.get("active_hunts", []))
	ws.active_hostages.assign(state.get("active_hostages", []))

	# Horde
	ws.horde_strength_counters = state.get("horde_strength_counters", {})

	# Collective disposition
	ws.clan_baselines = state.get("clan_baselines", {})
	ws.family_baselines = state.get("family_baselines", {})
	ws.marriage_clan_boosts = state.get("marriage_clan_boosts", {})
	ws.marriage_family_boosts = state.get("marriage_family_boosts", {})

	# Governance
	ws.seiyaku_state = state.get("seiyaku_state", {})
	ws.togashi_state = state.get("togashi_state", {})
	ws.phoenix_council_state = state.get("phoenix_council_state", {})
	ws.worship_state = state.get("worship_state", {})
	if ws.worship_state.is_empty() or not ws.worship_state.has("empire_tiers"):
		ws.worship_state = WorshipSystem.make_initial_worship_state()

	# Disposition snapshots
	ws.disposition_snapshots = state.get("disposition_snapshots", {})


# ============================================================================
# UTILITIES
# ============================================================================

func _restore_counter(counter_arr: Array[int], state: Dictionary, key: String) -> void:
	if state.has(key):
		counter_arr[0] = int(state[key])


func _reconcile_id_counters(ws: Node) -> void:
	_ensure_counter_above(ws.next_character_id, ws.characters, "character_id")
	_ensure_counter_above(ws.next_topic_id, ws.active_topics, "topic_id")
	_ensure_counter_above(ws.next_secret_id, ws.active_secrets, "secret_id")
	_ensure_counter_above(ws.next_tattoo_id, ws.tattoos, "tattoo_id")
	_ensure_counter_above(ws.next_cell_id, ws.bloodspeaker_cells, "cell_id")
	_ensure_counter_above(ws.next_settlement_id, ws.settlements, "settlement_id")
	_ensure_counter_above(ws.next_construction_id, ws.constructions, "construction_id")
	_ensure_counter_above(ws.next_court_id, ws.active_courts, "court_id")
	_ensure_counter_above(ws.next_edict_id, ws.active_edicts, "edict_id")
	_ensure_counter_above(ws.next_war_id, ws.active_wars, "war_id")
	_ensure_counter_above(ws.next_succession_id, ws.active_successions, "succession_id")
	_ensure_counter_above(ws.next_commitment_id, ws.commitments, "commitment_id")
	_ensure_counter_above(ws.next_hunt_id, ws.active_hunts, "hunt_id")
	_ensure_counter_above(ws.next_case_id, ws.crime_records, "case_id")
	_ensure_counter_above(ws.next_insurgency_id, ws.insurgencies, "insurgency_id")
	_ensure_counter_above(ws.next_company_id, ws.military_companies, "company_id")
	_ensure_counter_above(ws.next_item_id, ws.crafted_items, "item_id")


func _ensure_counter_above(counter: Array[int], collection: Variant, id_field: String) -> void:
	var max_id: int = counter[0] - 1
	if collection is Array:
		for item: Variant in collection:
			var item_id: int = -1
			if item is Resource and id_field in item:
				item_id = int(item.get(id_field))
			elif item is Dictionary:
				item_id = int(item.get(id_field, -1))
			if item_id >= max_id:
				max_id = item_id
	if max_id >= counter[0]:
		push_warning("WorldStateSaver: Counter '%s' was %d but found ID %d — advancing to %d." % [
			id_field, counter[0], max_id, max_id + 1,
		])
		counter[0] = max_id + 1


func _purge_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _ensure_dirs(base: String) -> void:
	var dirs: Array[String] = [
		base,
		base + DIR_CHARACTERS,
		base + DIR_TOPICS,
		base + DIR_LETTERS,
		base + DIR_COMMITMENTS,
		base + DIR_CRIMES,
		base + DIR_INSURGENCIES,
		base + DIR_COURTS,
		base + DIR_EDICTS,
		base + DIR_HORDES,
		base + DIR_SHIPS,
		base + DIR_CHILDREN,
		base + DIR_CONSTRUCTIONS,
		base + DIR_COURT_COMMITMENTS,
		base + DIR_SUCCESSIONS,
		base + DIR_WARS,
		base + DIR_PROVINCES,
		base + DIR_SETTLEMENTS,
		base + DIR_SECRETS,
		base + DIR_FAVORS,
		base + DIR_TATTOOS,
		base + DIR_TRADE_ROUTES,
		base + DIR_SPIRITUAL_EVENTS,
		base + DIR_BLOODSPEAKER_CELLS,
		base + DIR_CRAFTED_ITEMS,
	]
	for d: String in dirs:
		DirAccess.make_dir_recursive_absolute(d)
