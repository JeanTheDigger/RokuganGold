extends Control

signal selection_made(selection_id: String)

@onready var title_label   : Label        = $Panel/VBoxContainer/Label
@onready var option_button : OptionButton = $Panel/VBoxContainer/OptionButton
@onready var select_button : Button       = $Panel/VBoxContainer/HBoxContainer/Select
@onready var cancel_button : Button       = $Panel/VBoxContainer/HBoxContainer/Cancel

# Panel state
var current_mode: String = ""  # "Derangement" | "ThaumaturgyRitual" | "NecromancyRitual"

# Static data
const DERANGEMENTS := {
	"bipolar_disorder": "Bipolar Disorder",
	"bulimia": "Bulimia",
	"fugue": "Fugue",
	"hysteria": "Hysteria",
	"megalomania": "Megalomania",
	"multiple_personalities": "Multiple Personalities",
	"obsessive_compulsive": "Obsessive-Compulsive",
	"paranoia": "Paranoia",
	"sanguinary_animism": "Sanguinary Animism",
	"schizophrenia": "Schizophrenia"
}

# Use a literal array so it qualifies as a constant expression
const RITUALS_L1 := [
	"Armor of Diamond Serenity",
	"Bind the Accusing Tongue",
	"Blood into Water",
	"Blood Mastery",
	"Blood Rush",
	"Brand",
	"Calling Card",
	"CCTV",
	"Chime of Unseen Spirits",
	"Communicate with Kindred Sire",
	"Defense of the Sacred Haven",
	"Deflection of Wooden Doom",
	"Devil's Touch",
	"Domino of Life",
	"Encrypt Missive",
	"Engaging the Vessel of Transference",
	"Flatline",
	"Horoscope",
	"Illuminate the Trail of Prey",
	"Impressive Visage",
	"Incantation of the Shepherd",
	"Learning the Mind Enslumbered",
	"Purify Blood",
	"Purity of Flesh",
	"Reawakening the Dead Water",
	"Rite of Reclamation",
	"Ritual of Return",
	"Sanctify the Temple",
	"Sanguineous Phial",
	"Sense the Mystical",
	"Sigil of Authority",
	"Strength of Haqim",
	"Tame the Maddening Flame",
	"The Word of the Dark God",
	"Typhon's Brew",
	"Wake with Evening's Freshness",
	"Water Walking",
	"Widow's Spite"
]

const NECROMANCY_RITUALS_L1 := [
	"Call of the Hungry Dead",
	"Death’s Communion",
	"Eldritch Beacon",
	"Final Sight",
	"Foxfire",
	"Insight",
	"Knowing Stone",
	"Minestra di Morte",
	"Preserve Corpse",
	"Pull of the Grave",
	"Ritual of the Smoking Mirror",
	"Word of Insight"
]

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	option_button.item_selected.connect(_on_item_selected)
	_hide_modal()

# =========================
# Public entry points
# =========================

func show_derangement_mode() -> void:
	current_mode = "Derangement"
	title_label.text = "Select a Derangement"
	_populate_derangements()
	_show_modal()

func show_thaumaturgy_ritual_mode() -> void:
	current_mode = "ThaumaturgyRitual"
	title_label.text = "Choose a Ritual"
	_populate_rituals_l1()
	_show_modal()

func show_necromancy_ritual_mode() -> void:
	current_mode = "NecromancyRitual"
	title_label.text = "Choose a Ritual"
	_populate_necromancy_rituals_l1()
	_show_modal()

# =========================
# Internal helpers
# =========================

func _populate_derangements() -> void:
	option_button.clear()

	var pairs: Array = []
	for k in DERANGEMENTS.keys():
		pairs.append({ "key": k, "label": DERANGEMENTS[k] })
	pairs.sort_custom(func(a, b): return String(a["label"]) < String(b["label"]))

	for i in pairs.size():
		var label: String = String(pairs[i]["label"])
		var key: String = String(pairs[i]["key"])
		option_button.add_item(label)
		option_button.set_item_metadata(i, key)

	option_button.selected = -1
	select_button.disabled = true

func _populate_rituals_l1() -> void:
	option_button.clear()
	for i in RITUALS_L1.size():
		var ritual_name: String = String(RITUALS_L1[i])
		option_button.add_item(ritual_name)
		option_button.set_item_metadata(i, ritual_name)

	option_button.selected = -1
	select_button.disabled = true

func _populate_necromancy_rituals_l1() -> void:
	option_button.clear()
	for i in NECROMANCY_RITUALS_L1.size():
		var ritual_name: String = String(NECROMANCY_RITUALS_L1[i])
		option_button.add_item(ritual_name)
		option_button.set_item_metadata(i, ritual_name)

	option_button.selected = -1
	select_button.disabled = true

func _show_modal() -> void:
	self.visible = true
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	self.set_process_input(true)

func _hide_modal() -> void:
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
	self.set_process_input(false)
	select_button.disabled = true
	option_button.selected = -1

# =========================
# Signals
# =========================

func _on_item_selected(_index: int) -> void:
	select_button.disabled = false

func _on_cancel_pressed() -> void:
	_hide_modal()

func _on_select_pressed() -> void:
	var index := option_button.selected
	if index < 0:
		return

	var meta = option_button.get_item_metadata(index)
	var payload := ""

	if current_mode == "Derangement":
		payload = String(meta)  # derangement key
	elif current_mode == "ThaumaturgyRitual":
		payload = String(meta)  # ritual name
	elif current_mode == "NecromancyRitual":
		payload = String(meta)  # ritual name
	else:
		payload = option_button.get_item_text(index)

	_hide_modal()
	emit_signal("selection_made", payload)
