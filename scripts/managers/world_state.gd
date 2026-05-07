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


func _ready() -> void:
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
	)
