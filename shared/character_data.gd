class_name L5RCharacterData
extends Resource
## Full character sheet per GDD s22.3. Every named character — canonical,
## generated, and player — uses this same structure.

# -- Identity ------------------------------------------------------------------

@export var character_id: int = -1
@export var character_name: String = ""
@export var clan: String = ""
@export var family: String = ""
@export var school: String = ""
@export var school_name: String = ""
@export var school_type: Enums.SchoolType = Enums.SchoolType.BUSHI
@export var school_rank: int = 1
@export var age: int = 16
@export var gender: String = ""
@export var orientation: String = "straight"

# -- The Five Rings & Traits ---------------------------------------------------
# Ring = min(trait1, trait2). Both traits tracked individually per s4.5.2.

@export var stamina: int = 2
@export var willpower: int = 2
@export var strength: int = 2
@export var perception: int = 2
@export var agility: int = 2
@export var intelligence: int = 2
@export var reflexes: int = 2
@export var awareness: int = 2
@export var void_ring: int = 2

# -- Void Points ---------------------------------------------------------------

@export var current_void_points: int = 2
@export var max_void_points: int = 2

# -- Skills --------------------------------------------------------------------
# Dict of { skill_name: String -> rank: int }. Only skills at rank >= 1 present.

@export var skills: Dictionary = {}

# Dict of { skill_name: String -> Array[String] } for emphases.
@export var emphases: Dictionary = {}

# -- Techniques & Special Abilities --------------------------------------------

@export var techniques: Array = []
@export var kiho: Array = []
@export var katas: Array = []

# -- Spells (shugenja only) ----------------------------------------------------

@export var affinity_element: Enums.Ring = Enums.Ring.NONE
@export var deficiency_element: Enums.Ring = Enums.Ring.NONE
@export var spells_known: Array = []

# -- Advantages & Disadvantages ------------------------------------------------

@export var advantages: Array = []
@export var disadvantages: Array = []

# -- Honor, Glory, Status, Infamy (0.0 to 10.0) -------------------------------

@export var honor: float = 3.5
@export var glory: float = 1.0
@export var status: float = 1.0
@export var infamy: float = 0.0
@export var insight_rank: int = 1

# -- Wounds --------------------------------------------------------------------
# Total wounds taken. Wound levels derived from Earth ring at query time.

@export var wounds_taken: int = 0

# -- Shadowlands Taint ---------------------------------------------------------

@export var taint: float = 0.0

# -- Equipment & Outfit --------------------------------------------------------

@export var weapons: Array = []
@export var armor_worn: String = ""
@export var armor_tn_bonus: int = 0
@export var armor_reduction: int = 0
@export var outfit: Array = []
@export var koku: float = 0.0
@export var months_without_stipend: int = 0

# -- Inventory (Section 12.11) -------------------------------------------------
# Item dicts as produced by InventorySystem.create_item / create_gift_item.
# Storage tier and outfit-slot accounting are queried via InventorySystem.
@export var items: Array = []

# -- Personality (Section 19) --------------------------------------------------

@export var bushido_virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE
@export var shourido_virtue: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE

# -- Social & Dynamic Fields ---------------------------------------------------

@export var lord_id: int = -1
@export var operational_superior_id: int = -1
@export var operational_hierarchy_type: Enums.OperationalHierarchyType = Enums.OperationalHierarchyType.NONE
@export var military_rank: Enums.MilitaryRank = Enums.MilitaryRank.NONE
@export var commanded_unit_id: int = -1
@export var assigned_company_id: int = -1
@export var current_objective: String = ""
@export var physical_location: String = ""
@export var travel_destination: String = ""
@export var travel_days_remaining: int = 0
@export var travel_origin: String = ""
@export var role_position: String = ""
@export var designated_heir_id: int = -1
@export var disposition_values: Dictionary = {}
@export var historical_modifiers: Dictionary = {}
@export var temporary_modifiers: Dictionary = {}
@export var cohabitation_days: Dictionary = {}
@export var fear_rating: int = 0
@export var captive_status: String = ""
@export var is_retired_monastic: bool = false
@export var topic_pool: Array = []
@export var topic_positions: Dictionary = {}
@export var active_quest: String = ""
@export var met_characters: Array = []
@export var knowledge_pool: Array = []
@export var known_contacts_by_clan: Dictionary = {}
@export var favors: Array = []

# -- Legal System (Section 11.3.14) --------------------------------------------

@export var legal_cases: Array = []

# -- Courtier Framework Fields -------------------------------------------------

@export var self_reroll: Array = []
@export var granted_reroll: Array = []
@export var enhanced_void: bool = false
@export var precise_memory: bool = false
@export var cadence_trained: bool = false
@export var commerce_honor_exempt: bool = false
@export var intimidation_honor_exempt: bool = false
@export var timed_advantages: Array = []
@export var action_blocks: Array = []
@export var combat_modifiers_pending: Array = []
@export var supply_ledger: Dictionary = {}
@export var from_the_ashes: Dictionary = {}
@export var perfect_gift_targets: Array = []

# -- Theater & Art Tracking ----------------------------------------------------

@export var pieces_seen: Dictionary = {}
@export var learning_progress: Dictionary = {}

# -- Meditation (Section 57.32) ------------------------------------------------

@export var void_refresh_blocked_until: int = -1

# -- Medicine & Rest -----------------------------------------------------------

@export var last_medicine_treatment_ic_day: int = -1
@export var rested_last_night: bool = true

# -- Action Points (Section 14.1) ----------------------------------------------

@export var action_points_current: int = 2
@export var action_points_max: int = 2

# -- Civilian Order Budget -----------------------------------------------------

@export var civilian_order_budget_max: int = 0
@export var civilian_orders_remaining: int = 0

# -- Wind-Down State -----------------------------------------------------------

@export var last_wind_down_method: String = "rest"
@export var wind_down_void_modifier: float = 0.5

# -- Poison Tracking -----------------------------------------------------------

@export var active_poisons: Array = []

# -- Family Web (Section 22.6) -------------------------------------------------
# Generation 1 (self), Generation 2 (parents), and any actively-simulated
# Generation 3 ancestors are full L5RCharacterData. Deceased grandparents
# and great-grandparents are stored as lightweight AncestorRecord entries
# for lineage tracking and cross-clan-marriage detection.

@export var mother_id: int = -1
@export var father_id: int = -1
@export var sibling_ids: Array = []
@export var children_ids: Array = []
## Characters formally adopted for succession purposes (1 AP action, s22.5 Priority 4).
## Distinct from children_ids (biological) so succession can rank them correctly.
@export var adopted_children_ids: Array = []
@export var spouse_id: int = -1
@export var birth_clan: String = ""
@export var birth_family: String = ""
@export var grandparent_records: Array = []
@export var great_grandparent_records: Array = []

# -- Kolat (Section 54.7c) -----------------------------------------------------

@export var kolat_superior_id: int = -1
@export var kolat_sect: Enums.KolatSect = Enums.KolatSect.NONE

# -- Bloodspeaker Cult (Section 56.14) ----------------------------------------

@export var cult_affiliation: bool = false

# -- Hunting (Section 57.38) ---------------------------------------------------

@export var hunt_trophies: Array = []

# -- Animal Companions (Section 57.39) -----------------------------------------

@export var trained_companions: Array = []

# -- Commerce Stigma (Section 57.40) -------------------------------------------

@export var school_paths: Array = []
@export var commerce_stigma_applied_ic_day: int = -1

# -- Sailing (Section 57.42) ---------------------------------------------------

@export var aboard_ship_id: int = -1
@export var passage_request_count_today: int = 0
@export var assigned_ship_id: int = -1

# -- Tattoo Ability State (Section 57.25.11) -----------------------------------

@export var mantis_tattoo: bool = false
@export var ocean_tattoo: bool = false
@export var ocean_last_used_ooc_day: int = -1
@export var phoenix_last_used_ic_day: int = -1
@export var crane_pool: int = 0
@export var kirin_reroll_available: bool = false
@export var active_tattoo_ability: Enums.TattooAbility = Enums.TattooAbility.NONE
@export var is_bald: bool = false

# -- Musha Shugyo (Section 57.48) ---------------------------------------------

@export var musha_shugyo: bool = false
@export var musha_shugyo_end_ic_day: int = -1
@export var original_lord_id: int = -1
@export var permanent_ronin: bool = false

# -- Kami Status (Section 55.10.2.7) ------------------------------------------
# Hidden from all information channels. True only for Togashi.

@export var is_kami: bool = false

# -- Progression (Section 48) -------------------------------------------------

@export var xp_total: int = 0
@export var xp_spent: int = 0
@export var xp_fractional: float = 0.0
@export var progress_bars: Dictionary = {}
@export var training_relationships: Dictionary = {}
@export var atoned_offenses: Array = []

# -- Bodyguard / Yojimbo Assignment -------------------------------------------
@export var assigned_protection_target_id: int = -1


# -- Trait Access Helpers (used by CharacterStats) -----------------------------

func get_trait_value(p_trait: Enums.Trait) -> int:
	match p_trait:
		Enums.Trait.STAMINA: return stamina
		Enums.Trait.WILLPOWER: return willpower
		Enums.Trait.STRENGTH: return strength
		Enums.Trait.PERCEPTION: return perception
		Enums.Trait.AGILITY: return agility
		Enums.Trait.INTELLIGENCE: return intelligence
		Enums.Trait.REFLEXES: return reflexes
		Enums.Trait.AWARENESS: return awareness
		Enums.Trait.VOID: return void_ring
		_: return 0


func set_trait_value(p_trait: Enums.Trait, value: int) -> void:
	match p_trait:
		Enums.Trait.STAMINA: stamina = value
		Enums.Trait.WILLPOWER: willpower = value
		Enums.Trait.STRENGTH: strength = value
		Enums.Trait.PERCEPTION: perception = value
		Enums.Trait.AGILITY: agility = value
		Enums.Trait.INTELLIGENCE: intelligence = value
		Enums.Trait.REFLEXES: reflexes = value
		Enums.Trait.AWARENESS: awareness = value
		Enums.Trait.VOID: void_ring = value
