# res://scripts/ui/PlayerData.gd
extends Node

# === Character Info ===
var character_name := ""
var sect := ""
var clan := ""
var nature := ""
var demeanor := ""
var path := ""
var path_name := ""


# === Attributes ===
var strength := 1
var dexterity := 1
var stamina := 1
var charisma := 1
var manipulation := 1
var appearance := 1
var perception := 1
var intelligence := 1
var wits := 1

# === Abilities: Talents ===
var alertness := 0
var athletics := 0
var awareness := 0
var brawl := 0
var empathy := 0
var expression := 0
var intimidation := 0
var leadership := 0
var streetwise := 0
var subterfuge := 0

# === Abilities: Skills ===
var animal_ken := 0
var crafts := 0
var drive := 0
var etiquette := 0
var firearms := 0
var larceny := 0
var melee := 0
var performance := 0
var stealth := 0
var survival := 0

# === Abilities: Knowledges ===
var academics := 0
var computer := 0
var finance := 0
var investigation := 0
var law := 0
var medicine := 0
var occult := 0
var politics := 0
var science := 0
var technology := 0

# === Disciplines ===
var discipline_1 := 0
var discipline_2 := 0
var discipline_3 := 0
var discipline_1_name := ""
var discipline_2_name := ""
var discipline_3_name := ""

# === Virtues ===
var conscience := 1
var self_control := 1
var courage := 1

# === Flags for path
var uses_conscience := true
var uses_self_control := true
var uses_conviction := false
var uses_instinct := false

# === Backgrounds ===
var allies := 0
var contacts := 0
var domain := 0
var fame := 0
var generation := 0
var haven := 0
var herd := 0
var influence := 0
var mentor := 0
var resources := 0
var retainers := 0
var rituals := 0
var status := 0
