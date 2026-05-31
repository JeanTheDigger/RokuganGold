class_name SettlementData
extends Resource
## Data model for a settlement per GDD s2.3. Holds type, infrastructure,
## and garrison info. Settlements exist within provinces.

@export var settlement_id: int = -1
@export var settlement_name: String = ""
@export var province_id: int = -1
@export var settlement_type: Enums.SettlementType = Enums.SettlementType.VILLAGE
@export var description: String = ""

# -- Infrastructure (named features present) -----------------------------------

@export var infrastructure: Array = []

# -- Resource Stockpiles (per GDD s4.3.7, s4.3.8) ----------------------------

@export var rice_stockpile: float = 0.0
@export var koku_stockpile: float = 0.0

# -- Population (PU breakdown per GDD s4.3.7) ---------------------------------

@export var population_pu: int = 0
@export var farming_pu: int = 0
@export var mining_pu: int = 0
@export var town_pu: int = 0
@export var military_pu: int = 0
@export var garrison_pu: int = 0

# -- Worship Locations (per GDD s4.3.21/s4.3.22) -----------------------------
# Each entry: {"type": "roadside_shrine"|"village_shrine"|"local_shrine"|"temple"|"shinden",
#              "dedicated": bool, "fortune": int (GreatFortune enum, -1 if general)}
@export var worship_locations: Array = []

# -- Wall Tower fields (Fortification Settlement only, per GDD s2.4.2) --------
# Structural Integrity: 0 (breached) to 10 (pristine). Non-wall settlements
# leave this at the default 10 and never mutate it.
@export var wall_si: int = 10
# Jade stockpile at Tower level (separate from clan jade reserve, per s2.4.15).
@export var jade_stockpile: float = 0.0
# Kaiu Reinforcement modifier (s2.4.16): flat decay reduction per season.
# Active only while kaiu_reinforce_seasons_remaining > 0.
@export var kaiu_decay_reduction: float = 0.0
@export var kaiu_reinforce_seasons_remaining: int = 0
# Garrison shortage escalation state (s2.4.13–14): season when Champion/Shireikan
# first sent letters about this shortage; -1 = no campaign started.
@export var garrison_shortage_letter_season: int = -1
# True once a DISPATCH_COURTIER has been sent for the current shortage.
@export var garrison_shortage_courtier_dispatched: bool = false
# True if the most recent courtier was explicitly refused by the Daimyo (s2.4.14).
# Gates the wall-wide emergency declaration trigger (Decision 6).
@export var garrison_shortage_courtier_refused: bool = false


# -- Public Record (per GDD s57.50) -------------------------------------------
# Each entry: {"event_type": String, "ic_day": int, "tier": int,
#              "topic_id": int, "subject_id": int, "zone_subtype": String}
@export var public_record: Array = []

# -- Lord (for permission checks across art/garden systems) -------------------
# Populated by DayOrchestrator from province lord data each day.
@export var lord_character_id: int = -1

# -- Garden Slots (per GDD s57.23a — settlement-level zone proxy) -------------
# Keys: "CASTLE_OUTER_COURTYARD", "TSUBONIWA". Values: garden_id (int) or -1 (empty).
# Only populated for eligible settlement types (FAMILY_CASTLE, CASTLE, CITY).
@export var garden_slots: Dictionary = {}
# Artisan currently holding permission for each zone type slot.
# Keys: "CASTLE_OUTER_COURTYARD", "TSUBONIWA". Values: artisan_id (int) or -1.
@export var garden_permissions: Dictionary = {}
# Bonsai display slot. -1 = empty, otherwise bonsai_id.
# Eligible types: FAMILY_CASTLE, CASTLE, CITY, KEEP, TEMPLE, SHINDEN, MONASTERY.
@export var bonsai_display_slot: int = -1

# -- Painting Slots (per GDD s57.27.4 — settlement-level zone proxy) ----------
# wall_art_slot: kakemono on the wall (tokonoma). -1 = empty, otherwise painting_id.
@export var wall_art_slot: int = -1
# displayed_art_slot: byōbu or prominent display piece. -1 = empty, otherwise painting_id.
@export var displayed_art_slot: int = -1
# fusuma_slot: fusuma sliding door painting. -1 = empty, otherwise painting_id.
@export var fusuma_slot: int = -1
# Permission holders for each painting slot (character_id → true).
@export var wall_art_permissions: Dictionary = {}
@export var displayed_art_permissions: Dictionary = {}
@export var fusuma_permissions: Dictionary = {}

# -- Sculpture Slots (per GDD s57.28.3 — settlement-level zone proxy) ----------
# statue_slot: religious statuary inside shrine/temple. -1 = empty, otherwise sculpture_id.
# Only eligible at TEMPLE, SHINDEN, MONASTERY settlement types (s57.28 section J).
@export var statue_slot: int = -1
# guardian_slot: guardian pair (komainu) at entrance. -1 = empty, otherwise sculpture_id.
# Only eligible at TEMPLE, SHINDEN, MONASTERY settlement types (s57.28 section J).
@export var guardian_slot: int = -1
# Permission holders for statue placement (sculptor_id → true).
@export var statue_permissions: Dictionary = {}
# Permission holders for guardian pair placement (sculptor_id → true).
@export var guardian_permissions: Dictionary = {}


func has_infrastructure(feature: String) -> bool:
	return feature in infrastructure


func is_military() -> bool:
	return settlement_type in Enums.MILITARY_SETTLEMENT_TYPES


func is_religious() -> bool:
	return settlement_type in Enums.RELIGIOUS_SETTLEMENT_TYPES
