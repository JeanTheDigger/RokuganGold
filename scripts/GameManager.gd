extends Node

# === CLIENT ===
var character_uis := {}  # name → UI node (client only)
var character_data: CharacterData = null  # currently active character on client

# === SERVER ===
var character_data_by_name := {}  # name → CharacterData resource
var character_peers := {}         # name → peer ID
var name_to_peer := {}            # (optional) name → peer ID
var peer_to_character_name := {}  # peer ID → name

# === POSSESSION SYSTEM ===
var possessed_characters := {}  # possessed_name → possessor_name (ST)
var storyteller_original_forms := {}  # possessor_name → original CharacterData

# === MODE TRACKING ===
var current_mode_by_peer := {}  # peer_id → "whisper", "possess", etc.

# === FRENZY TEST TRACKING ===
var frenzy_test_state := {}  # name → int (accumulated successes)
var rotschreck_test_state := {}  # target_name → success count

# === TYPING STATE TRACKING ===
var typing_state_by_name := {}  # name → bool
