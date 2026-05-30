class_name WorldStateData
extends Node
## Authoritative world state singleton. Holds all persistent data arrays
## that DayOrchestrator.advance_day() needs. Other systems read from here.


# -- Core Collections ----------------------------------------------------------

var time_system: TimeSystem = TimeSystem.new(1120, 0)
var dice_engine: DiceEngine = DiceEngine.new()

var characters: Array[L5RCharacterData] = []
var characters_by_id: Dictionary = {}
var provinces: Dictionary = {}
var settlements: Array[SettlementData] = []
var clans: Dictionary = {}

# -- NPC Engine State ----------------------------------------------------------

var world_states: Dictionary = {}
var objectives_map: Dictionary = {}
var scoring_tables: Dictionary = {}
var filter_data: Dictionary = {}
var action_skill_map: Dictionary = {}
var action_log: Array[Dictionary] = []
var season_meta: Dictionary = {}

# -- Subsystem State -----------------------------------------------------------

var active_topics: Array[TopicData] = []
var pending_letters: Array = []
var approach_penalties: Array[Dictionary] = []
var commitments: Array[CommitmentData] = []
var crime_records: Array[CrimeRecord] = []
var insurgencies: Array[InsurgencyData] = []
var favors: Array = []

# -- ID Counters (wrapped in arrays for pass-by-reference) ---------------------

var next_case_id: Array[int] = [1]
var next_topic_id: Array[int] = [1000]
var next_insurgency_id: Array[int] = [1]

# -- Supplementary Dictionaries ------------------------------------------------

var military_data: Dictionary = {}
var character_province_map: Dictionary = {}
var death_events: Array[Dictionary] = []
var successor_map: Dictionary = {}
var active_successions: Array[SuccessionData] = []
var next_succession_id: Array[int] = [1]
var entanglements: Array[Dictionary] = []
var bound_states: Array[Dictionary] = []

# -- Military Phase 2 State (s11.7) -------------------------------------------
var active_armies: Array[Dictionary] = []
var active_sieges: Array[Dictionary] = []
var active_tethers: Array[Dictionary] = []
var order_states: Array[Dictionary] = []
var military_companies: Array[Dictionary] = []
var next_company_id: Array[int] = [1]
var active_wars: Array[WarData] = []
var next_war_id: Array[int] = [1]
var trade_routes: Array = []

# -- Court Sessions (s15.1) ----------------------------------------------------
var active_courts: Array[CourtSessionData] = []
var next_court_id: Array[int] = [1]

# -- Imperial Edicts (s15.1, s15.2) --------------------------------------------
var active_edicts: Array[EdictData] = []
var next_edict_id: Array[int] = [1]

# -- Jigoku Horde System (s2.4.4–s2.4.8) --------------------------------------
var active_hordes: Array[HordeData] = []
var horde_strength_counters: Dictionary = {}
var last_targeted_province_id: Array[int] = [-1]

# -- Naval System (s11.9) -----------------------------------------------------
var ships: Array[ShipData] = []

# -- Gempukku / Population (s52) -----------------------------------------------
var children: Array[ChildRecord] = []
var next_character_id: Array[int] = [10000]

# -- Otomo Seiyaku (s55.22b) ---------------------------------------------------
var seiyaku_state: Dictionary = OtomoSeiyakuSystem.make_initial_state()

# -- Marriages (s22.7) --------------------------------------------------------
var marriages: Array[Dictionary] = []

# -- Construction Queue (s4.3.22) ----------------------------------------------
var constructions: Array[ConstructionData] = []
var next_settlement_id: Array[int] = [5000]
var next_construction_id: Array[int] = [1]

# -- Court Commitments (s16.4) ------------------------------------------------
var court_commitments: Array[CourtCommitmentData] = []

# -- Dragon Clan Governance (s55.10.2) ----------------------------------------
var togashi_state: Dictionary = TogashiOversight.make_initial_state()

# -- Phoenix Clan Governance (s55.10.3) ---------------------------------------
var phoenix_council_state: Dictionary = PhoenixCouncil.make_initial_state()

# -- Assassination Operations (s12.8) -----------------------------------------
var active_assassination_ops: Array[Dictionary] = []

# -- Approach Evaluation Snapshots (s55.30.3) ---------------------------------
var disposition_snapshots: Dictionary = {}

# -- Secrets (s12.8) ----------------------------------------------------------
var active_secrets: Array[SecretData] = []
var next_secret_id: Array[int] = [1]

# -- Hostages (s22.9) ---------------------------------------------------------
var active_hostages: Array[Dictionary] = []

# -- Tattoos (s57.25) ---------------------------------------------------------
var tattoos: Array[TattooData] = []
var next_tattoo_id: Array[int] = [1]

# -- Hunts (s57.38) -----------------------------------------------------------
var active_hunts: Array[Dictionary] = []
var next_hunt_id: Array[int] = [1]

# -- Spiritual Insurgency (s56.16) -------------------------------------------
var spiritual_insurgency_events: Array = []
var next_spiritual_event_id: Array[int] = [1]

# -- Bloodspeaker Cult Network (s56.14) --------------------------------------
var bloodspeaker_cells: Array[BloodspeakerCellData] = []
var next_cell_id: Array[int] = [1]

# -- Artisan & Crafting (s49) -------------------------------------------------
var crafted_items: Array[ArtisanItemData] = []
var next_item_id: Array[int] = [1]

# -- Theater Pieces (s57.22) --------------------------------------------------
var theater_pieces: Array[TheaterPieceData] = []
var next_piece_id: Array[int] = [1]

# -- Senbazuru Projects (s57.26) ----------------------------------------------
var active_senbazurus: Array[SenbazuruData] = []
var next_senbazuru_id: Array[int] = [1]

# -- Commitments ID Counter (s55.31) ------------------------------------------
var next_commitment_id: Array[int] = [1]

# -- Crisis ID Counter ---------------------------------------------------------
var next_crisis_id: Array[int] = [1]

# -- Intra-Clan Civil War (s53.2) ---------------------------------------------
var active_civil_wars: Array[Dictionary] = []
var precedent_modifiers: Dictionary = {}

# -- Kami Worship (s4.3.21) ---------------------------------------------------
var worship_state: Dictionary = WorshipSystem.make_initial_worship_state()

# -- Collective Disposition (s12.2b) -------------------------------------------
# Clan-to-clan and family-to-family baselines keyed by sorted "a||b" strings.
# Initialized to the locked PROVISIONAL pre-Scorpion-Coup starting values.
# Mutated by CollectiveDisposition event helpers as the simulation runs —
# they never decay, only deliberate events shift them.

var clan_baselines: Dictionary = {}
var family_baselines: Dictionary = {}

# Decaying marriage boosts (s22.7) tracked separately from permanent baselines.
# Each entry: {"value": int, "seasons_acc": int} keyed by CollectiveDisposition.make_pair_key().
var marriage_clan_boosts: Dictionary = {}
var marriage_family_boosts: Dictionary = {}

# -- Imperial Capital (s11.5b) -------------------------------------------------
# Identifies the Emperor character and the settlement holding the Imperial
# rice stockpile. -1 sentinels mean "not yet assigned" — Miya's Blessing
# will not fire until both are set.

var emperor_id: int = -1
var emperor_settlement_id: int = -1
var emperor_archetype: int = StrategicReview.EmperorArchetype.IRON
var miya_representative_id: int = -1


func _ready() -> void:
	var fresh: Dictionary = CollectiveDisposition.make_starting_baselines()
	clan_baselines = fresh["clan"]
	family_baselines = fresh["family"]
	_load_npc_scoring_tables()
	print("[WorldState] Initialized.")


func _load_npc_scoring_tables() -> void:
	var base: String = "res://systems/npc_engine/data/tables/"
	scoring_tables = {
		"objective_alignment": _load_json(base + "objective_alignment.json"),
		"personality_lean": _load_json(base + "personality_lean.json"),
		"competence_table": _load_json(base + "competence_table.json"),
		"disposition_tiers": _load_json(base + "disposition_tiers.json"),
		"urgency_rules": _load_json(base + "urgency_rules.json"),
		"topic_position_alignment": _load_json(base + "topic_position_alignment.json"),
		"action_skill_map": _load_json(base + "action_skill_map.json"),
	}
	filter_data = {
		"personality_filter": _load_json(base + "personality_filter.json"),
	}
	action_skill_map = scoring_tables.get("action_skill_map", {})


static func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("WorldState: JSON file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("WorldState: Failed to open JSON file: %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("WorldState: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data


func rebuild_characters_by_id() -> void:
	characters_by_id.clear()
	for c: L5RCharacterData in characters:
		characters_by_id[c.character_id] = c


func _sync_wars_to_world_states() -> void:
	world_states["active_wars"] = WarSystem.wars_to_context_array(active_wars)
	world_states["province_data"] = provinces.values()
	world_states["settlements"] = settlements
	world_states["clan_baselines"] = clan_baselines
	world_states["family_baselines"] = family_baselines
	world_states["marriage_clan_boosts"] = marriage_clan_boosts
	world_states["marriage_family_boosts"] = marriage_family_boosts
	world_states["emperor_id"] = emperor_id
	world_states["emperor_archetype"] = emperor_archetype


func advance_one_day() -> Dictionary:
	_sync_wars_to_world_states()
	var result: Dictionary = DayOrchestrator.advance_day(
		time_system,
		characters,
		characters_by_id,
		world_states,
		objectives_map,
		scoring_tables,
		filter_data,
		dice_engine,
		action_skill_map,
		provinces,
		action_log,
		season_meta,
		active_topics,
		pending_letters,
		approach_penalties,
		commitments,
		crime_records,
		next_case_id,
		military_data,
		character_province_map,
		next_topic_id,
		death_events,
		successor_map,
		favors,
		insurgencies,
		next_insurgency_id,
		settlements,
		_build_miya_inputs(),
		active_successions,
		next_succession_id,
		entanglements,
		bound_states,
		active_armies,
		active_sieges,
		active_tethers,
		order_states,
		military_companies,
		clans,
		active_wars,
		trade_routes,
		next_war_id,
		active_courts,
		next_court_id,
		active_edicts,
		next_edict_id,
		active_hordes,
		horde_strength_counters,
		last_targeted_province_id,
		ships,
		children,
		next_character_id,
		seiyaku_state,
		marriages,
		worship_state,
		constructions,
		next_settlement_id,
		next_construction_id,
		court_commitments,
		togashi_state,
		phoenix_council_state,
		active_civil_wars,
		precedent_modifiers,
		next_company_id,
		active_secrets,
		next_secret_id,
		active_hostages,
		active_assassination_ops,
		next_commitment_id,
		next_crisis_id,
		disposition_snapshots,
		tattoos,
		next_tattoo_id,
		active_hunts,
		next_hunt_id,
		spiritual_insurgency_events,
		next_spiritual_event_id,
		bloodspeaker_cells,
		next_cell_id,
		crafted_items,
		next_item_id,
		theater_pieces,
		next_piece_id,
		active_senbazurus,
		next_senbazuru_id,
	)
	_apply_succession_updates(result)
	return result


func _apply_succession_updates(result: Dictionary) -> void:
	var applied: Array = result.get("succession_applied", [])
	for entry: Dictionary in applied:
		if entry.get("is_emperor", false):
			emperor_id = entry.get("successor_id", -1)
			emperor_archetype = world_states.get(
				"emperor_archetype", StrategicReview.EmperorArchetype.IRON
			)
			var new_emp: L5RCharacterData = characters_by_id.get(emperor_id)
			if new_emp != null and not new_emp.physical_location.is_empty():
				emperor_settlement_id = new_emp.physical_location.to_int()


func _build_miya_inputs() -> Dictionary:
	## Assembles the Miya's Blessing inputs dict for this world. Returns an
	## empty dict (no-op) when the Imperial capital isn't fully set up.
	if emperor_id < 0 or emperor_settlement_id < 0:
		return {}
	var emperor: L5RCharacterData = characters_by_id.get(emperor_id)
	if emperor == null:
		return {}
	var emperor_settlement: SettlementData = null
	for s: SettlementData in settlements:
		if s.settlement_id == emperor_settlement_id:
			emperor_settlement = s
			break
	if emperor_settlement == null:
		return {}
	return {
		"emperor_archetype": emperor_archetype,
		"emperor_id": emperor_id,
		"emperor_settlement_id": emperor_settlement_id,
		"otosan_uchi_pu": float(emperor_settlement.population_pu),
		"miya_representative_id": miya_representative_id,
		# Tax income is resolved from season_meta inside DayOrchestrator —
		# don't override it here.
	}
