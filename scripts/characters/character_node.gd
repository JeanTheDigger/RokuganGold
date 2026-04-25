extends Node
class_name CharacterNode

# Identity
var character_name = ""
var current_zone = null
var display_target = null
var player_id = ""
var sect = ""
var clan = ""
var nature = null
var demeanor = null

# Advancement
var experience = 0
var freebie_purchases = []

# Attributes
var Strength = 1
var Dexterity = 1
var Stamina = 1
var Charisma = 1
var Manipulation = 1
var Appearance = 1
var Perception = 1
var Intelligence = 1
var Wits = 1

# Talents
var Alertness = 0
var Athletics = 0
var Awareness = 0
var Brawl = 0
var Empathy = 0
var Expression_Skill = 0
var Intimidation = 0
var Leadership = 0
var Streetwise = 0
var Subterfuge = 0

# Skills
var Animal_Ken = 0
var Crafts = 0
var Drive = 0
var Etiquette = 0
var Firearms = 0
var Melee = 0
var Performance_Skill = 0
var Larceny = 0
var Stealth = 0
var Survival = 0

# Knowledges
var Academics = 0
var Computer = 0
var Finance = 0
var Investigation = 0
var Law = 0
var Medicine = 0
var Occult = 0
var Politics = 0
var Science = 0
var Technology = 0

# Core Disciplines (1–10, capped by Generation)
var Celerity = 0
var Fortitude = 0
var Potence = 0
var Dominate = 0
var Presence = 0
var Auspex = 0
var Obfuscate = 0
var Obtenebration = 0
var Protean = 0
var Animalism = 0
var Vicissitude = 0
var Dementation = 0
var Thaumaturgy = 0
var Necromancy = 0
var Serpentis = 0
var Quietus = 0

# === BACKGROUND RATINGS ===
var allies_rating = 0
var contacts_rating = 0
var domain_rating = 0
var fame_rating = 0
var generation_rating = 0
var haven_rating = 0
var herd_rating = 0
var influence_rating = 0
var mentor_rating = 0
var resources_rating = 0
var retainers_rating = 0
var rituals_rating = 0
var status_rating = 0

# Blood Pool
var blood_pool = 10
var blood_max = 10

# Virtues & Morality
var Conscience = 1
var Self_Control = 1
var Courage = 1
var Conviction = 1
var Instinct = 1
var Humanity = 0
var Willpower = 0
var Willpower_Current = 0

# Flags
var is_storyteller = false
var is_npc = false
