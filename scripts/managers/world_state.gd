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

# -- Collective Disposition (s12.2b) -------------------------------------------
# Clan-to-clan and family-to-family baselines keyed by sorted "a||b" strings.
# Initialized to the locked PROVISIONAL pre-Scorpion-Coup starting values.
# Mutated by CollectiveDisposition event helpers as the simulation runs —
# they never decay, only deliberate events shift them.

var clan_baselines: Dictionary = {}
var family_baselines: Dictionary = {}

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
	print("[WorldState] Initialized.")


func rebuild_characters_by_id() -> void:
	characters_by_id.clear()
	for c: L5RCharacterData in characters:
		characters_by_id[c.character_id] = c


func advance_one_day() -> Dictionary:
	return DayOrchestrator.advance_day(
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
	)


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
