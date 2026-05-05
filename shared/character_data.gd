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
@export var school_type: Enums.SchoolType = Enums.SchoolType.BUSHI
@export var age: int = 16
@export var gender: String = ""

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

@export var void_points_current: int = 2
@export var void_points_max: int = 2

# -- Skills --------------------------------------------------------------------
# Dict of { skill_name: String -> rank: int }. Only skills at rank >= 1 present.

@export var skills: Dictionary = {}

# Dict of { skill_name: String -> Array[String] } for emphases.
@export var emphases: Dictionary = {}

# -- Techniques & Special Abilities --------------------------------------------

@export var techniques: Array[String] = []
@export var kiho: Array[String] = []
@export var katas: Array[String] = []

# -- Spells (shugenja only) ----------------------------------------------------

@export var affinity_element: Enums.Ring = Enums.Ring.VOID
@export var deficiency_element: Enums.Ring = Enums.Ring.VOID
@export var spells_known: Array[String] = []

# -- Advantages & Disadvantages ------------------------------------------------

@export var advantages: Array[String] = []
@export var disadvantages: Array[String] = []

# -- Honor, Glory, Status, Infamy (0.0 to 10.0) -------------------------------

@export var honor: float = 3.5
@export var glory: float = 1.0
@export var status: float = 1.0
@export var infamy: float = 0.0

# -- Wounds --------------------------------------------------------------------
# Total wounds taken. Wound levels derived from Earth ring at query time.

@export var wounds_taken: int = 0

# -- Shadowlands Taint ---------------------------------------------------------

@export var taint: float = 0.0

# -- Equipment & Outfit --------------------------------------------------------

@export var weapons: Array[String] = []
@export var armor_worn: String = ""
@export var armor_tn_bonus: int = 0
@export var armor_reduction: int = 0
@export var outfit: Array[String] = []
@export var koku: float = 0.0

# -- Personality (Section 19) --------------------------------------------------

@export var bushido_virtue: String = ""
@export var shourido_virtue: String = ""

# -- Social & Dynamic Fields ---------------------------------------------------

@export var lord_id: int = -1
@export var operational_superior_id: int = -1
@export var operational_hierarchy_type: String = ""
@export var current_objective: String = ""
@export var physical_location: String = ""
@export var role_position: String = ""
@export var designated_heir_id: int = -1
@export var disposition_values: Dictionary = {}
@export var fear_rating: int = 0
@export var captive_status: String = ""
@export var topic_pool: Array[String] = []
@export var active_quest: String = ""
@export var met_characters: Array[int] = []

# -- Courtier Framework Fields -------------------------------------------------

@export var self_reroll: bool = false
@export var granted_reroll: bool = false
@export var enhanced_void: bool = false
@export var timed_advantages: Array[String] = []
@export var action_blocks: Array[String] = []
@export var combat_modifiers_pending: Array[String] = []
@export var supply_ledger: Dictionary = {}

# -- Theater & Art Tracking ----------------------------------------------------

@export var pieces_seen: Dictionary = {}
@export var learning_progress: Dictionary = {}

# -- Medicine & Rest -----------------------------------------------------------

@export var last_medicine_treatment_ic_day: int = 0
@export var rested_last_night: bool = true

# -- Civilian Order Budget -----------------------------------------------------

@export var civilian_order_budget_max: int = 0
@export var civilian_orders_remaining: int = 0

# -- Wind-Down State -----------------------------------------------------------

@export var last_wind_down_method: String = "rest"
@export var wind_down_void_modifier: float = 0.5

# -- Poison Tracking -----------------------------------------------------------

@export var active_poisons: Array[Dictionary] = []

# -- Family Web ----------------------------------------------------------------

@export var mother_id: int = -1
@export var father_id: int = -1
@export var sibling_ids: Array[int] = []
@export var children_ids: Array[int] = []
@export var spouse_id: int = -1

# -- Progression (Section 48) -------------------------------------------------

@export var xp_total: int = 0
@export var xp_spent: int = 0
@export var progress_bars: Dictionary = {}
@export var training_relationships: Dictionary = {}


# -- Trait Access Helpers (used by CharacterStats) -----------------------------

func get_trait_value(trait: Enums.Trait) -> int:
	match trait:
		Enums.Trait.STAMINA: return stamina
		Enums.Trait.WILLPOWER: return willpower
		Enums.Trait.STRENGTH: return strength
		Enums.Trait.PERCEPTION: return perception
		Enums.Trait.AGILITY: return agility
		Enums.Trait.INTELLIGENCE: return intelligence
		Enums.Trait.REFLEXES: return reflexes
		Enums.Trait.AWARENESS: return awareness
		Enums.Trait.VOID: return void_ring
	return 0
