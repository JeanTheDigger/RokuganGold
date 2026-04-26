extends Resource
class_name CharacterData

@export var is_storyteller: bool = false
@export var possessed_by: String = ""
@export var character_password: String = ""
@export var is_vampire: bool = false
@export var description: String = ""
@export var notes: String = ""
@export var enter_mode: int = 0  # 0=NO_ENTER, 1=ENTER, 2=SHIFT_ENTER


# ===Custom Dice Pool===
@export var custom_pool_1: int = 0
@export var custom_pool_2: int = 0


# === Identity ===
@export var name: String = ""
@export var clan: String = ""
@export var sect: String = ""
@export var nature: String = ""
@export var demeanor: String = ""
@export var path_name: String = "" 
@export var experience_points: int = 0
@export var blood_bonds := {}
@export var blood_bond_last_increment: Dictionary = {} # { "SourceName": "YYYY-MM-DD" }
@export var vinculum := {} 
@export var vinculum_lock_until: Dictionary = {} # other_name -> "YYYY-MM-DD"



# === Zone ===
@export var current_zone: String = ""
@export var current_zone_category: String = ""
@export var current_viewpoint: String = ""
@export var derangements: Array[String] = []

# === Attributes ===
@export var strength: int = 1
@export var dexterity: int = 1
@export var stamina: int = 1
@export var charisma: int = 1
@export var manipulation: int = 1
@export var appearance: int = 1
@export var perception: int = 1
@export var intelligence: int = 1
@export var wits: int = 1

@export var strength_blood_increased: int = 0
@export var dexterity_blood_increased: int = 0
@export var stamina_blood_increased: int = 0

@export var strength_progress: int = 0
@export var dexterity_progress: int = 0
@export var stamina_progress: int = 0
@export var charisma_progress: int = 0
@export var manipulation_progress: int = 0
@export var appearance_progress: int = 0
@export var perception_progress: int = 0
@export var intelligence_progress: int = 0
@export var wits_progress: int = 0


# === Abilities (Talents, Skills, Knowledges) ===
# === Abilities: Talents ===
@export var alertness: int = 0
@export var athletics: int = 0
@export var awareness: int = 0
@export var brawl: int = 0
@export var empathy: int = 0
@export var expression: int = 0
@export var intimidation: int = 0
@export var leadership: int = 0
@export var streetwise: int = 0
@export var subterfuge: int = 0

@export var alertness_progress: int = 0
@export var athletics_progress: int = 0
@export var awareness_progress: int = 0
@export var brawl_progress: int = 0
@export var empathy_progress: int = 0
@export var expression_progress: int = 0
@export var intimidation_progress: int = 0
@export var leadership_progress: int = 0
@export var streetwise_progress: int = 0
@export var subterfuge_progress: int = 0


# === Abilities: Skills ===
@export var animal_ken: int = 0
@export var crafts: int = 0
@export var drive: int = 0
@export var etiquette: int = 0
@export var firearms: int = 0
@export var larceny: int = 0
@export var melee: int = 0
@export var performance: int = 0
@export var stealth: int = 0
@export var survival: int = 0

@export var animal_ken_progress: int = 0
@export var crafts_progress: int = 0
@export var drive_progress: int = 0
@export var etiquette_progress: int = 0
@export var firearms_progress: int = 0
@export var larceny_progress: int = 0
@export var melee_progress: int = 0
@export var performance_progress: int = 0
@export var stealth_progress: int = 0
@export var survival_progress: int = 0


# === Abilities: Knowledges ===
@export var academics: int = 0
@export var computer: int = 0
@export var finance: int = 0
@export var investigation: int = 0
@export var law: int = 0
@export var medicine: int = 0
@export var occult: int = 0
@export var politics: int = 0
@export var science: int = 0
@export var technology: int = 0

@export var academics_progress: int = 0
@export var computer_progress: int = 0
@export var finance_progress: int = 0
@export var investigation_progress: int = 0
@export var law_progress: int = 0
@export var medicine_progress: int = 0
@export var occult_progress: int = 0
@export var politics_progress: int = 0
@export var science_progress: int = 0
@export var technology_progress: int = 0



# === Virtues ===
@export var conscience: int = 0
@export var self_control: int = 0
@export var courage: int = 1
@export var conviction: int = 0
@export var instinct: int = 0

@export var conscience_progress: int = 0
@export var self_control_progress: int = 0
@export var courage_progress: int = 0
@export var conviction_progress: int = 0
@export var instinct_progress: int = 0

# === Morality and Mechanics ===
@export var path: int = 7
@export var path_progress: int = 0
@export var generation: int = 13
@export var blood_pool: int = 10
@export var blood_pool_max: int = 10
@export var blood_per_turn: int = 1
@export var willpower_max: int = 1
@export var willpower_current: int = 1
@export var willpower_max_progress: int = 0  # 0..9999

# === Disciplines ===
@export var disciplines: Dictionary = {} # Example: { "Animalism": 2, "Dominate": 1 }
@export var discipline_progress: Dictionary = {} # Example: { "Animalism": 50, "Dominate": 0 }


# === Backgrounds ===
@export var allies: int = 0
@export var contacts: int = 0
@export var domain: int = 0
@export var fame: int = 0
@export var generation_background: int = 0 # Avoid naming conflict with main 'generation'
@export var haven: int = 0
@export var herd: int = 0
@export var influence: int = 0
@export var mentor: int = 0
@export var resources: int = 0
@export var retainers: int = 0
@export var rituals: int = 0
@export var status: int = 0

@export var allies_progress: int = 0
@export var contacts_progress: int = 0
@export var domain_progress: int = 0
@export var fame_progress: int = 0
@export var generation_background_progress: int = 0
@export var haven_progress: int = 0
@export var herd_progress: int = 0
@export var influence_progress: int = 0
@export var mentor_progress: int = 0
@export var resources_progress: int = 0
@export var retainers_progress: int = 0
@export var rituals_progress: int = 0
@export var status_progress: int = 0


# === Merits and Flaws ===
@export var merits: Array[String] = []  # Example: ["Blush of Health (2)", "Eidetic Memory (2)"]
@export var flaws: Array[String] = []   # Example: ["Deep Sleeper (1)", "Prey Exclusion (1)"]


# === Associated Variables ===

@export var ability_specialties: Array[String] = [] # Compact list of "ability_key:specialty" strings; ability_key matches your ability vars (e.g., melee, animal_ken). Example: ["melee:Knives", "drive:Highway Pursuit"]
@export var thaumaturgy_paths: Array[String] = [] # Compact list of "Path Name:rating" strings; the first entry is the Primary Path. Example: ["Path of Blood:3", "Lure of Flames:2"]
@export var thaumaturgy_rituals: Array[String] = [] # Compact list of "level:ritual name" strings; numeric level first for easy filtering. Example: ["1:Wake with Evening's Freshness", "3:Blood Walk"]
@export var ritae_auctoritas_known: Array[String] = [] # List of Auctoritas Ritae names known. Example: ["Creation Rites", "Vaulderie"]
@export var ritae_ignoblis_known: Array[String] = []  # List of Ignoblis Ritae names known. Example: ["Rite of the Hunt", "Wild Hunt"]

# --- Thaumaturgy Paths ---
@export var thaumaturgy_path_progress: Dictionary = {} # {"Path of Blood": 1250, "Lure of Flames": 0} values 0..9999

# === Necromancy ===
@export var necromancy_paths: Array[String] = [] # Compact list of "Path Name:rating" strings; the first entry is the Primary Path. Example: ["Sepulchre Path:3", "Bone Path:2"]
@export var necromancy_rituals: Array[String] = [] # Compact list of "level:ritual name" strings; numeric level first for easy filtering. Example: ["1:Call of the Hungry Dead", "3:Ex Nihilo"]
@export var necromancy_path_progress: Dictionary = {} # {"Sepulchre Path": 1250, "Bone Path": 0} values 0..9999



# === Inventory and Equipment ===

# General items (trinkets, quest items, consumables, etc.)
@export var inventory_general: Array[String] = []

# Specialized inventories for gear
@export var inventory_armor: Array[String] = []
@export var inventory_weapons: Array[String] = []

# Equipment slots
@export var armor: String = ""      # Currently equipped armor
@export var mainhand: String = ""   # Equipped weapon or held item in main hand
@export var offhand: String = ""    # Equipped weapon or held item in off hand



# === Health ===
@export var health_levels: Array[String] = [ 
	"Healthy", "Bruised", "Hurt", "Injured", "Wounded", "Mauled", "Crippled", "Incapacitated"
]

@export var health_index: int = 0
@export var aggravated_wounds: Array[String] = []  # Example: ["1990-09-21", "1990-09-21", "1990-09-22"]
@export var last_aggravated_heal_date: String = ""  # "YYYY-MM-DD"

@export var is_in_torpor: bool = false

@export var blush_of_life: bool = false


# === Nightly Login Tracking ===

@export var last_time_woken_up: String = "" 
# Stores IC date as "YYYY-MM-DD" string to compare with CalendarManager
@export var last_ap_reset_stamp: String = ""
# Format: "YYYY-MM-DD|1" or "YYYY-MM-DD|2" for first/second half

# === Action Points ===

@export var action_points_max: int = 3
@export var action_points_current: int = 3






func deserialize_from_dict(data: Dictionary) -> void:
	var property_names := []
	for p in get_property_list():
		property_names.append(p.name)

	for key in data.keys():
		if key == "script":
			continue
		if key in property_names:
			set(key, data[key])
		else:
			# 🧪 DEBUG: Log what got skipped
			print("⚠️ Skipped unknown property in deserialize:", key)





func serialize_to_dict() -> Dictionary:
	var dict := {}
	for property in get_property_list():
		var prop_name = property.name
		dict[prop_name] = get(prop_name)
	return dict
