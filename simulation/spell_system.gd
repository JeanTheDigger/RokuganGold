class_name SpellSystem
## s31-s37 Spell system: data library and world-simulation casting mechanics.
## Plain GDScript class — no extends Node.

enum SpellSimEffect {
	COMBAT_ONLY,       ## 0 — meaningful only in ASCII map combat
	HEAL_WOUNDS,       ## 1 — reduce wound rank on target
	REMOVE_TAINT,      ## 2 — reduce taint on character or province PTL
	DETECT_PRESENCE,   ## 3 — detect kami, spirits, or maho residue
	COMMUNE_KAMI,      ## 4 — commune with local kami (worship economy)
	SUMMON_KAMI,       ## 5 — summon a kami to manifest
	COMMAND_KAMI,      ## 6 — command a summoned or local kami
	TRANSMUTE_MATERIAL,## 7 — change material properties (crafting aid)
	PURIFY_AREA,       ## 8 — purify tainted ground, reduce province PTL
	REVEAL_DECEPTION,  ## 9 — pierce illusions, detect lies, reveal true nature
	WARD_CREATION,     ## 10 — create protective elemental ward at location
	TRAVEL_AID,        ## 11 — assist or speed overland travel
	PRESERVATION,      ## 12 — preserve corpse or item against decay
	DISPEL_MAGIC,      ## 13 — end another spell or magical binding
	SPIRIT_BIND,       ## 14 — bind a spirit (aids insurgency suppression)
	RITUAL_HONOR,      ## 15 — grants honor/glory bonus during worship ritual
	WEATHER_SHIFT,     ## 16 — alter weather conditions (affects travel TN)
	INFORMATION_GATHER,## 17 — gain information about distant location or person
}

## Spell library.
## Keys: snake_case spell ID  Values: {e=element int, m=mastery_level, s=SpellSimEffect int,
##   u=is_universal (true only), i=ishiken_only (true only), omit absent booleans}
## Element ints: -1=universal/NONE, 0=AIR, 1=EARTH, 2=FIRE, 3=WATER, 4=VOID
## SpellSimEffect ints: 0=COMBAT_ONLY, 1=HEAL, 2=REMOVE_TAINT, 3=DETECT, 4=COMMUNE,
##   5=SUMMON, 6=COMMAND, 7=TRANSMUTE, 8=PURIFY, 9=REVEAL, 10=WARD, 11=TRAVEL,
##   12=PRESERVE, 13=DISPEL, 14=BIND, 15=RITUAL, 16=WEATHER, 17=INFO
const SPELL_LIBRARY: Dictionary = {
	# === UNIVERSAL (s32) — available to all shugenja ===
	"sense":     {"e": -1, "m": 1, "s": 3,  "u": true},
	"commune":   {"e": -1, "m": 1, "s": 4,  "u": true},
	"summon":    {"e": -1, "m": 2, "s": 5,  "u": true},
	"command":   {"e": -1, "m": 3, "s": 6,  "u": true},
	"transmute": {"e": -1, "m": 4, "s": 7,  "u": true},

	# === AIR (s33) ===
	# ML1
	"arrows_flight":              {"e": 0, "m": 1, "s": 0},
	"blessed_wind":               {"e": 0, "m": 1, "s": 0},  # concentration ranged defense — COMBAT_ONLY
	"by_the_light_of_the_moon":   {"e": 0, "m": 1, "s": 0},
	"cloak_of_night":             {"e": 0, "m": 1, "s": 0},
	"gathering_swirl":            {"e": 0, "m": 1, "s": 0},
	"legacy_of_kaze_no_kami":     {"e": 0, "m": 1, "s": 0},
	"natures_touch":              {"e": 0, "m": 1, "s": 3},
	"tempest_of_air":             {"e": 0, "m": 1, "s": 0},
	"token_of_memory":            {"e": 0, "m": 1, "s": 0},   # memory illusion; perception bonus — COMBAT_ONLY
	"to_seek_the_truth":          {"e": 0, "m": 1, "s": 0},   # clears temporary mental/social penalties — COMBAT_ONLY
	"voice_of_the_wind":          {"e": 0, "m": 1, "s": 0},   # social skill bonus for caster — COMBAT_ONLY
	"way_of_deception":           {"e": 0, "m": 1, "s": 0},
	"yari_of_air":                {"e": 0, "m": 1, "s": 0},
	# ML2
	"bentens_touch":              {"e": 0, "m": 2, "s": 15},
	"blessed_wind_of_lady_sun":   {"e": 0, "m": 2, "s": 0},  # concentration area aura — COMBAT_ONLY
	"call_upon_the_wind":         {"e": 0, "m": 2, "s": 0},
	"elemental_cipher":           {"e": 0, "m": 2, "s": 0},   # encrypts writing (passive protection, no active gather) — COMBAT_ONLY
	"flight_of_doves":            {"e": 0, "m": 2, "s": 0},   # entertainment illusion — COMBAT_ONLY
	"freedom_of_the_air":         {"e": 0, "m": 2, "s": 14},  # Compels hostile spirits out for Air Ring hours — SPIRIT_BIND
	"garbled_tongue":             {"e": 0, "m": 2, "s": 0},
	"heart_betrays_eyes":         {"e": 0, "m": 2, "s": 0},   # target perceives unusual as normal; maintains illusion — COMBAT_ONLY
	"hidden_visage":              {"e": 0, "m": 2, "s": 0},
	"the_kamis_whisper":          {"e": 0, "m": 2, "s": 0},   # creates false sounds — COMBAT_ONLY
	"mists_of_illusion":          {"e": 0, "m": 2, "s": 0},
	"quiescence_of_air":          {"e": 0, "m": 2, "s": 0},
	"request_to_hato_no_kami":    {"e": 0, "m": 2, "s": 0},   # concentration bird command — COMBAT_ONLY
	"secrets_on_the_wind":        {"e": 0, "m": 2, "s": 17},
	"whispering_wind":            {"e": 0, "m": 2, "s": 17},
	"wind_born_slumbers":         {"e": 0, "m": 2, "s": 0},
	"wolfs_proposal":             {"e": 0, "m": 2, "s": 0},
	# ML3
	"air_kamis_blessing":         {"e": 0, "m": 3, "s": 15},
	"essence_of_air":             {"e": 0, "m": 3, "s": 0},
	"the_eye_shall_not_see":      {"e": 0, "m": 3, "s": 0},
	"mask_of_wind":               {"e": 0, "m": 3, "s": 0},
	"master_clouds_eyes":         {"e": 0, "m": 3, "s": 17},
	"soul_of_kaze_no_kami":       {"e": 0, "m": 3, "s": 0},
	"striking_the_storm":         {"e": 0, "m": 3, "s": 0},
	"summoning_the_gale":         {"e": 0, "m": 3, "s": 0},  # concentration area wind block — COMBAT_ONLY
	"summon_fog":                 {"e": 0, "m": 3, "s": 0},  # concentration fog ("while maintained") — COMBAT_ONLY
	"touch_of_airs_grace":        {"e": 0, "m": 3, "s": 0},
	"your_hearts_enemy":          {"e": 0, "m": 3, "s": 0},   # manifests Fear 4 illusion attack — COMBAT_ONLY
	# ML4
	"call_the_spirit":            {"e": 0, "m": 4, "s": 5},
	"castle_of_air":              {"e": 0, "m": 4, "s": 0},
	"false_realm":                {"e": 0, "m": 4, "s": 0},
	"funeral_rites":              {"e": 0, "m": 4, "s": 17},  # speaks with departed spirit for information — INFORMATION_GATHER
	"gift_of_wind":               {"e": 0, "m": 4, "s": 0},
	"howl_of_isora":              {"e": 0, "m": 4, "s": 0},  # one-time damage blast — COMBAT_ONLY
	"know_the_mind":              {"e": 0, "m": 4, "s": 17},
	"look_into_the_soul":         {"e": 0, "m": 4, "s": 17},  # Divination: reveals target's 2 lowest Rings — INFORMATION_GATHER
	"netsuke_of_wind":            {"e": 0, "m": 4, "s": 0},
	"seeking_the_way":            {"e": 0, "m": 4, "s": 0},   # hides caster's tracks — COMBAT_ONLY
	"symbol_of_air":              {"e": 0, "m": 4, "s": 10},
	"tenjins_ear":                {"e": 0, "m": 4, "s": 0},   # language comprehension buff — COMBAT_ONLY
	"whispers_of_the_forgotten":  {"e": 0, "m": 4, "s": 0},   # psychic fear/disorientation — COMBAT_ONLY
	"wisdom_of_the_kami":         {"e": 0, "m": 4, "s": 0},   # temporary skill rating bonus — COMBAT_ONLY
	# ML5
	"cloud_the_mind":             {"e": 0, "m": 5, "s": 0},
	"defender_from_beyond":       {"e": 0, "m": 5, "s": 0},
	"draw_back_the_shadow":       {"e": 0, "m": 5, "s": 0},   # Dispels illusions ML4 and below — combat duration
	"echoes_on_the_breeze":       {"e": 0, "m": 5, "s": 17},
	"facing_your_devils":         {"e": 0, "m": 5, "s": 0},
	"legion_of_the_moon":         {"e": 0, "m": 5, "s": 0},
	"slayers_knives":             {"e": 0, "m": 5, "s": 0},
	# ML6
	"rise_air":                   {"e": 0, "m": 6, "s": 0},
	"the_false_legion":           {"e": 0, "m": 6, "s": 0},
	"piercing_the_heavens":       {"e": 0, "m": 6, "s": 0},
	"wind_of_the_moon":           {"e": 0, "m": 6, "s": 0},
	"the_world_is_truth":         {"e": 0, "m": 6, "s": 0},   # Kolat memory rewrite; blocked on s54.7 — COMBAT_ONLY
	"wrath_of_kaze_no_kami":      {"e": 0, "m": 6, "s": 0},

	# === EARTH (s34) ===
	# ML1
	"armor_of_earth":                {"e": 1, "m": 1, "s": 0},
	"courage_of_the_seven_thunders": {"e": 1, "m": 1, "s": 0},
	"earths_stagnation":             {"e": 1, "m": 1, "s": 0},
	"earths_touch":                  {"e": 1, "m": 1, "s": 0},  # Trait boost 1h — buff, not healing
	"elemental_ward":                {"e": 1, "m": 1, "s": 10},
	"jade_strike":                   {"e": 1, "m": 1, "s": 0},
	"jurojins_balm":                 {"e": 1, "m": 1, "s": 0},  # Poison resist 1h — buff, not healing
	"minor_binding":                 {"e": 1, "m": 1, "s": 0},
	"soul_of_stone":                 {"e": 1, "m": 1, "s": 0},
	"stones_endurance":              {"e": 1, "m": 1, "s": 0},
	"tetsubo_of_earth":              {"e": 1, "m": 1, "s": 0},
	# ML2
	"be_the_mountain":               {"e": 1, "m": 2, "s": 0},
	"earth_becomes_sky":             {"e": 1, "m": 2, "s": 0},
	"embrace_of_kenro_ji_jin":       {"e": 1, "m": 2, "s": 0},
	"force_of_will":                 {"e": 1, "m": 2, "s": 0},
	"grasp_of_earth":                {"e": 1, "m": 2, "s": 0},
	"hands_of_clay":                 {"e": 1, "m": 2, "s": 0},
	"jurojins_curse":                {"e": 1, "m": 2, "s": 0},
	"rites_of_preservation":         {"e": 1, "m": 2, "s": 12},
	"taming_the_beast":              {"e": 1, "m": 2, "s": 0},
	"the_mountains_feet":            {"e": 1, "m": 2, "s": 0},   # 1h knockdown resistance stance — COMBAT_ONLY
	"wholeness_of_the_world":        {"e": 1, "m": 2, "s": 0},  # Ring/Trait resistance — buff, not healing
	"whispers_of_the_land":          {"e": 1, "m": 2, "s": 17},
	# ML3
	"bonds_of_ningen_do":            {"e": 1, "m": 3, "s": 14},
	"earth_kamis_blessing":          {"e": 1, "m": 3, "s": 15},
	"earths_protection":             {"e": 1, "m": 3, "s": 0},
	"earthen_wave":                  {"e": 1, "m": 3, "s": 0},
	"groves_of_stone":               {"e": 1, "m": 3, "s": 0},
	"murmur_of_earth":               {"e": 1, "m": 3, "s": 0},   # earthquake/terrain damage — COMBAT_ONLY
	"purge_the_taint":               {"e": 1, "m": 3, "s": 8},
	"sharing_the_strength_of_many":  {"e": 1, "m": 3, "s": 0},
	"shelter_of_the_earth":          {"e": 1, "m": 3, "s": 0},
	"strength_of_the_crow":          {"e": 1, "m": 3, "s": 0},
	"strike_as_stone":               {"e": 1, "m": 3, "s": 0},
	"times_deadly_hand":             {"e": 1, "m": 3, "s": 0},
	"the_wolfs_mercy":               {"e": 1, "m": 3, "s": 0},
	"wooden_prison":                 {"e": 1, "m": 3, "s": 0},
	# ML4
	"armor_of_the_emperor":          {"e": 1, "m": 4, "s": 0},
	"earth_dragons_ward":            {"e": 1, "m": 4, "s": 10},
	"essence_of_earth":              {"e": 1, "m": 4, "s": 0},
	"maw_of_the_earth":              {"e": 1, "m": 4, "s": 0},
	"sapphire_strike":               {"e": 1, "m": 4, "s": 0},
	"symbol_of_earth":               {"e": 1, "m": 4, "s": 10},
	"the_earth_flows":               {"e": 1, "m": 4, "s": 0},
	"tomb_of_jade":                  {"e": 1, "m": 4, "s": 2},
	"wall_of_earth":                 {"e": 1, "m": 4, "s": 0},
	# ML5
	"drawing_on_the_mountain":       {"e": 1, "m": 5, "s": 0},  # Structure wound/reduction buff — not healing
	"earthquake":                    {"e": 1, "m": 5, "s": 0},
	"grounding_energy":              {"e": 1, "m": 5, "s": 0},   # Anti-maho TN boost 3 rounds — combat only
	"major_binding":                 {"e": 1, "m": 5, "s": 0},
	"strike_at_the_roots":           {"e": 1, "m": 5, "s": 0},
	"the_kamis_strength":            {"e": 1, "m": 5, "s": 0},
	"the_kamis_will":                {"e": 1, "m": 5, "s": 0},   # Willpower boost + spell resistance buff — COMBAT_ONLY
	# ML6
	"essence_of_jade":               {"e": 1, "m": 6, "s": 10},
	"power_of_the_earth_dragon":     {"e": 1, "m": 6, "s": 0},
	"prison_of_earth":               {"e": 1, "m": 6, "s": 0},
	"rise_earth":                    {"e": 1, "m": 6, "s": 0},
	"soldiers_of_clay":              {"e": 1, "m": 6, "s": 0},

	# === FIRE (s35) ===
	# ML1
	"biting_steel":                  {"e": 2, "m": 1, "s": 0},
	"burning_kiss_of_steel":         {"e": 2, "m": 1, "s": 0},
	"elemental_crucible":            {"e": 2, "m": 1, "s": 7},
	"envious_flames":                {"e": 2, "m": 1, "s": 0},
	"extinguish":                    {"e": 2, "m": 1, "s": 0},   # Dismisses fire kami / extinguishes fire — instantaneous combat
	"fire_kamis_blessing":           {"e": 2, "m": 1, "s": 15},
	"fires_of_purity":               {"e": 2, "m": 1, "s": 15},
	"the_fires_that_cleanse":        {"e": 2, "m": 1, "s": 0},
	"fury_of_osano_wo":              {"e": 2, "m": 1, "s": 0},
	"gift_of_amaterasu":             {"e": 2, "m": 1, "s": 15},
	"katana_of_fire":                {"e": 2, "m": 1, "s": 0},
	"never_alone":                   {"e": 2, "m": 1, "s": 0},
	"osano_wos_blessing":            {"e": 2, "m": 1, "s": 15},
	"the_raging_forge":              {"e": 2, "m": 1, "s": 7},
	"warning_flame":                 {"e": 2, "m": 1, "s": 3},
	# ML2
	"disrupt_the_aura":              {"e": 2, "m": 2, "s": 0},
	"enticing_the_dance_of_flame":   {"e": 2, "m": 2, "s": 0},
	"the_fires_from_within":         {"e": 2, "m": 2, "s": 0},
	"hurried_steps":                 {"e": 2, "m": 2, "s": 0},   # 2-round casting speed reduction — COMBAT_ONLY
	"mental_quickness":              {"e": 2, "m": 2, "s": 0},
	"purity_of_shinsei":             {"e": 2, "m": 2, "s": 15},
	"relentless_heat":               {"e": 2, "m": 2, "s": 0},
	"tail_of_the_fire_dragon":       {"e": 2, "m": 2, "s": 0},
	"ward_of_purity":                {"e": 2, "m": 2, "s": 10},
	"wings_of_fire":                 {"e": 2, "m": 2, "s": 0},   # 10-min slow flight at Water 1 speed; too slow for overland — COMBAT_ONLY
	# ML3
	"agashas_shield":                {"e": 2, "m": 3, "s": 0},
	"breath_of_the_fire_dragon":     {"e": 2, "m": 3, "s": 0},
	"fiery_wrath":                   {"e": 2, "m": 3, "s": 0},
	"the_fist_of_osano_wo":          {"e": 2, "m": 3, "s": 0},
	"haze_of_battle":                {"e": 2, "m": 3, "s": 0},
	"hungry_blade":                  {"e": 2, "m": 3, "s": 0},
	"oath_of_the_heavens":           {"e": 2, "m": 3, "s": 15},
	"ravenous_swarms":               {"e": 2, "m": 3, "s": 0},
	"shining_light":                 {"e": 2, "m": 3, "s": 0},
	"the_breath_of_battle":          {"e": 2, "m": 3, "s": 0},
	"whispering_flames":             {"e": 2, "m": 3, "s": 0},   # fire daze attack — COMBAT_ONLY
	# ML4
	"blessing_of_the_sun":           {"e": 2, "m": 4, "s": 15},
	"death_of_flame":                {"e": 2, "m": 4, "s": 0},
	"defense_of_the_firestorm":      {"e": 2, "m": 4, "s": 0},
	"essence_of_fire":               {"e": 2, "m": 4, "s": 0},
	"eyes_of_the_phoenix":           {"e": 2, "m": 4, "s": 0},   # blind/fear burst — COMBAT_ONLY
	"the_mending_forge":             {"e": 2, "m": 4, "s": 7},
	"symbol_of_fire":                {"e": 2, "m": 4, "s": 10},
	"wall_of_fire":                  {"e": 2, "m": 4, "s": 0},
	"ward_of_thunder":               {"e": 2, "m": 4, "s": 10},
	# ML5
	"castle_of_fire":                {"e": 2, "m": 5, "s": 0},
	"consumed_by_five_fires":        {"e": 2, "m": 5, "s": 0},
	"destructive_wave":              {"e": 2, "m": 5, "s": 0},
	"the_dragons_talon":             {"e": 2, "m": 5, "s": 0},
	"everburning_rage":              {"e": 2, "m": 5, "s": 0},
	"follow_the_flame":              {"e": 2, "m": 5, "s": 0},   # fire damage / elemental tracking — COMBAT_ONLY
	"light_of_the_sun":              {"e": 2, "m": 5, "s": 15},
	"wings_of_the_phoenix":          {"e": 2, "m": 5, "s": 0},   # 10-round combat flight — COMBAT_ONLY
	# ML6
	"beam_of_the_inferno":           {"e": 2, "m": 6, "s": 0},
	"curse_of_the_burning_hand":     {"e": 2, "m": 6, "s": 0},
	"globe_of_the_everlasting_sun":  {"e": 2, "m": 6, "s": 0},
	"rise_fire":                     {"e": 2, "m": 6, "s": 0},
	"the_elements_fury":             {"e": 2, "m": 6, "s": 0},
	"the_souls_blade":               {"e": 2, "m": 6, "s": 0},

	# === WATER (s36) ===
	# ML1
	"bo_of_water":                   {"e": 3, "m": 1, "s": 0},
	"clarity_of_purpose":            {"e": 3, "m": 1, "s": 0},
	"ebbing_strength":               {"e": 3, "m": 1, "s": 0},
	"path_to_inner_peace":           {"e": 3, "m": 1, "s": 15},
	"purification_of_the_kami":      {"e": 3, "m": 1, "s": 15},
	"reflections_of_pan_ku":         {"e": 3, "m": 1, "s": 17},
	"reversal_of_fortunes":          {"e": 3, "m": 1, "s": 0},
	"speed_of_the_waterfall":        {"e": 3, "m": 1, "s": 11},
	"spirit_of_the_water":           {"e": 3, "m": 1, "s": 3},
	"suitengus_curse":               {"e": 3, "m": 1, "s": 0},
	"sympathetic_energies":          {"e": 3, "m": 1, "s": 0},  # Transfers a spell effect — not healing
	"the_rushing_wave":              {"e": 3, "m": 1, "s": 0},
	"the_swell_of_the_storm":        {"e": 3, "m": 1, "s": 0},  # one-time knockdown — COMBAT_ONLY
	# ML2
	"cloak_of_the_miya":             {"e": 3, "m": 2, "s": 0},   # 5-round Armor TN defensive boost — COMBAT_ONLY
	"heavens_tears":                 {"e": 3, "m": 2, "s": 0},  # per-round brief deluge, outdoors only — COMBAT_ONLY
	"inaris_blessing":               {"e": 3, "m": 2, "s": 15},
	"judgment_of_yomi":              {"e": 3, "m": 2, "s": 0},   # behavioral/social debuff — COMBAT_ONLY
	"reflective_pool":               {"e": 3, "m": 2, "s": 17},
	"rejuvenating_vapors":           {"e": 3, "m": 2, "s": 0},  # Fatigue removal / Void slot restore — not wound healing
	"stand_against_the_waves":       {"e": 3, "m": 2, "s": 0},
	"strength_of_the_tsunami":       {"e": 3, "m": 2, "s": 0},
	"surging_soul":                  {"e": 3, "m": 2, "s": 0},
	"the_ties_that_bind":            {"e": 3, "m": 2, "s": 17},
	"wave_borne_speed":              {"e": 3, "m": 2, "s": 0},   # 2-round Water Ring movement boost — COMBAT_ONLY
	"wisdom_and_clarity":            {"e": 3, "m": 2, "s": 0},   # reading speed buff — COMBAT_ONLY
	"yukis_touch":                   {"e": 3, "m": 2, "s": 0},
	# ML3
	"endless_deluge":                {"e": 3, "m": 3, "s": 16},
	"near_to_ice":                   {"e": 3, "m": 3, "s": 0},
	"regrow_the_wound":              {"e": 3, "m": 3, "s": 1},
	"sanctuary_of_the_waves":        {"e": 3, "m": 3, "s": 0},
	"silent_waters":                 {"e": 3, "m": 3, "s": 0},
	"strike_of_the_tsunami":         {"e": 3, "m": 3, "s": 0},
	"the_inner_ocean":               {"e": 3, "m": 3, "s": 15},
	"typhoons_surge":                {"e": 3, "m": 3, "s": 0},
	"visions_of_the_future":         {"e": 3, "m": 3, "s": 17},
	"walking_upon_the_waves":        {"e": 3, "m": 3, "s": 11},
	"water_kamis_blessing":          {"e": 3, "m": 3, "s": 15},
	# ML4
	"dominion_of_suitengu":          {"e": 3, "m": 4, "s": 17},  # Divination: scry between water bodies — INFORMATION_GATHER
	"ebb_and_flow_of_battle":        {"e": 3, "m": 4, "s": 0},
	"heart_of_the_water_dragon":     {"e": 3, "m": 4, "s": 0},
	"master_of_the_rolling_river":   {"e": 3, "m": 4, "s": 0},   # 5-min military unit buff; battlefield scale — COMBAT_ONLY
	"the_mirrors_smile":             {"e": 3, "m": 4, "s": 0},   # physical disguise transformation — COMBAT_ONLY
	"seed_of_qanan":                 {"e": 3, "m": 4, "s": 15},
	"steed_of_the_ebbing_tides":     {"e": 3, "m": 4, "s": 11},
	"strike_of_the_flowing_waters":  {"e": 3, "m": 4, "s": 0},
	"symbol_of_water":               {"e": 3, "m": 4, "s": 10},
	"the_emperors_road":             {"e": 3, "m": 4, "s": 11},
	"the_path_not_taken":            {"e": 3, "m": 4, "s": 0},   # transfers a spell slot to ally — COMBAT_ONLY
	"within_the_waves":              {"e": 3, "m": 4, "s": 0},
	# ML5
	"chi_reversal":                  {"e": 3, "m": 5, "s": 0},
	"ever_changing_waves":           {"e": 3, "m": 5, "s": 0},
	"the_final_bond":                {"e": 3, "m": 5, "s": 17},
	"hands_of_the_tides":            {"e": 3, "m": 5, "s": 0},
	"open_the_waves":                {"e": 3, "m": 5, "s": 11},
	"power_of_the_ocean":            {"e": 3, "m": 5, "s": 0},
	"suitengus_embrace":             {"e": 3, "m": 5, "s": 0},
	"whirlpool":                     {"e": 3, "m": 5, "s": 0},
	# ML6
	"breath_of_mist":                {"e": 3, "m": 6, "s": 16},
	"opening_the_veil":              {"e": 3, "m": 6, "s": 0},
	"peace_of_the_kami":             {"e": 3, "m": 6, "s": 15},
	"rise_water":                    {"e": 3, "m": 6, "s": 0},
	"waters_sweet_clarity":          {"e": 3, "m": 6, "s": 17},

	# === VOID (s37) — restricted to Isawa Ishiken ===
	# ML1
	"boundless_sight":               {"e": 4, "m": 1, "s": 17, "i": true},
	"drawing_the_void":              {"e": 4, "m": 1, "s": 0,  "i": true},
	"flow_through_the_void":         {"e": 4, "m": 1, "s": 7,  "i": true},  # permanent elemental transmutation — TRANSMUTE_MATERIAL
	"see_through_lies":              {"e": 4, "m": 1, "s": 17, "i": true},  # reveals target's highest Advantage or Disadvantage — INFORMATION_GATHER
	"sense_void":                    {"e": 4, "m": 1, "s": 3,  "i": true},
	"touch_the_emptiness":           {"e": 4, "m": 1, "s": 0,  "i": true},
	"the_voids_caress":              {"e": 4, "m": 1, "s": 0,  "i": true},
	"witness_the_untold":            {"e": 4, "m": 1, "s": 17, "i": true},
	# ML2
	"altering_the_course":           {"e": 4, "m": 2, "s": 0,  "i": true},
	"balance_in_all":                {"e": 4, "m": 2, "s": 15, "i": true},
	"commune_with_the_void":         {"e": 4, "m": 2, "s": 4,  "i": true},
	"drink_of_your_essence":         {"e": 4, "m": 2, "s": 0,  "i": true},
	"strengthen_the_void":           {"e": 4, "m": 2, "s": 15, "i": true},
	"the_empty_voice":               {"e": 4, "m": 2, "s": 0,  "i": true},  # allows silent casting — COMBAT_ONLY
	"false_whispers":                {"e": 4, "m": 2, "s": 0,  "i": true},  # makes target repeat one sentence verbatim — COMBAT_ONLY
	"reach_through_the_void":        {"e": 4, "m": 2, "s": 0,  "i": true},  # telekinesis — COMBAT_ONLY
	"severed_from_the_stream":       {"e": 4, "m": 2, "s": 0,  "i": true},
	# ML3
	"banish_the_void":               {"e": 4, "m": 3, "s": 0,  "i": true},  # Thickens Void veil 5 rounds — combat only
	"echoes_in_the_void":            {"e": 4, "m": 3, "s": 17, "i": true},
	"kharmic_intent":                {"e": 4, "m": 3, "s": 0,  "i": true},  # shares Void Points with ally — COMBAT_ONLY
	"moment_of_clarity":             {"e": 4, "m": 3, "s": 0,  "i": true},
	"read_the_essence":              {"e": 4, "m": 3, "s": 3,  "i": true},
	"void_release":                  {"e": 4, "m": 3, "s": 0,  "i": true},  # Transfers Void Points — not a dispel, combat aid
	# ML4
	"balance_of_elements":           {"e": 4, "m": 4, "s": 15, "i": true},
	"dart_of_void":                  {"e": 4, "m": 4, "s": 0,  "i": true},
	"draw_closed_the_veil":          {"e": 4, "m": 4, "s": 0,  "i": true},
	"essence_of_void":               {"e": 4, "m": 4, "s": 0,  "i": true},
	"fill_the_emptiness":            {"e": 4, "m": 4, "s": 0,  "i": true},  # Restores Void Points — not wound healing
	"void_strike":                   {"e": 4, "m": 4, "s": 0,  "i": true},
	# ML5
	"divide_the_soul":               {"e": 4, "m": 5, "s": 0,  "i": true},
	"reforge":                       {"e": 4, "m": 5, "s": 7,  "i": true},
	"unbound_essence":               {"e": 4, "m": 5, "s": 0,  "i": true},  # Randomly reorders Rings 1h — no trackable sim state
	# ML6
	"ring_of_the_void":              {"e": 4, "m": 6, "s": 0,  "i": true},
	"rise_from_the_ashes":           {"e": 4, "m": 6, "s": 1,  "i": true},
	"unmake_the_world":              {"e": 4, "m": 6, "s": 0,  "i": true},
}

## PROVISIONAL — actual school curricula require s28/s29 review.
## All shugenja start with Sense and Commune (universal ML1) plus element-appropriate ML1 spells.
const _DEFAULT_STARTING_SPELLS: Array = ["sense", "commune"]

const _SCHOOL_STARTING_SPELLS: Dictionary = {
	## Air-primary schools
	"Doji Shugenja":    ["sense", "commune", "to_seek_the_truth", "bentens_touch"],
	"Asako Shugenja":   ["sense", "commune", "to_seek_the_truth", "token_of_memory"],
	"Moshi Shugenja":   ["sense", "commune", "gift_of_amaterasu", "fire_kamis_blessing"],
	## Earth-primary schools
	"Kuni Shugenja":    ["sense", "commune", "jade_strike", "jurojins_balm"],
	"Isawa Shugenja":   ["sense", "commune", "summon", "command"],
	"Agasha Shugenja":  ["sense", "commune", "earths_touch", "jurojins_balm"],
	## Fire-primary schools
	"Shiba Shugenja":   ["sense", "commune", "fire_kamis_blessing", "fires_of_purity"],
	"Tamori Shugenja":  ["sense", "commune", "elemental_crucible", "the_raging_forge"],
	## Water-primary schools
	"Yogo Shugenja":    ["sense", "commune", "path_to_inner_peace", "purification_of_the_kami"],
	"Iuchi Shugenja":   ["sense", "commune", "speed_of_the_waterfall", "cloak_of_the_miya"],
	"Kitsu Shugenja":   ["sense", "commune", "sympathetic_energies", "judgment_of_yomi"],
	## Void school
	"Isawa Ishiken":    ["sense", "commune", "sense_void", "boundless_sight", "see_through_lies"],
}


## Returns the Ring rank for a given element on a character.
static func get_ring_value(character: L5RCharacterData, ring: int) -> int:
	match ring:
		0: return mini(character.reflexes, character.awareness)    # AIR
		1: return mini(character.stamina, character.willpower)     # EARTH
		2: return mini(character.agility, character.intelligence)  # FIRE
		3: return mini(character.strength, character.perception)   # WATER
		4: return character.void_ring                              # VOID
	return 0


## Returns effective school rank accounting for affinity (+1) and deficiency (-1, min 0).
static func get_effective_school_rank(character: L5RCharacterData, ring: int) -> int:
	var rank: int = character.insight_rank
	if character.affinity_element == ring:
		rank += 1
	if character.deficiency_element == ring:
		rank = maxi(0, rank - 1)
	return rank


## Returns the casting TN for a given mastery level: 5 + (5 × ml).
static func get_casting_tn(mastery_level: int) -> int:
	return 5 + (5 * mastery_level)


## Returns the best ring for casting a given spell for this character.
## Universal spells (e=-1) choose whichever non-void ring gives the highest roll pool.
static func get_best_cast_ring(character: L5RCharacterData, spell_id: String) -> int:
	if not SPELL_LIBRARY.has(spell_id):
		return -1
	var el: int = SPELL_LIBRARY[spell_id].get("e", -1)
	if el >= 0:
		return el
	# Universal: pick non-void ring with highest (ring_val + eff_rank)
	var best_ring: int = 0
	var best_pool: int = -1
	for r: int in [0, 1, 2, 3]:
		var rv: int = get_ring_value(character, r)
		var er: int = get_effective_school_rank(character, r)
		var pool: int = rv + er
		if pool > best_pool:
			best_pool = pool
			best_ring = r
	return best_ring


## Returns the daily spell slot count for the given element ring value.
static func get_daily_slots(character: L5RCharacterData, ring: int) -> int:
	return get_ring_value(character, ring)


## Returns how many elemental slots have been consumed today for a ring.
static func get_slots_used(character: L5RCharacterData, ring: int) -> int:
	return character.spell_slots_used.get(ring, 0)


## Returns how many void bonus slots (any element) have been used today.
static func get_void_bonus_used(character: L5RCharacterData) -> int:
	return character.spell_void_bonus_used


## Returns true if the character has a slot available for the given ring.
static func can_afford_slot(character: L5RCharacterData, ring: int) -> bool:
	var used: int = get_slots_used(character, ring)
	if used < get_daily_slots(character, ring):
		return true
	# Fall back to void bonus slots
	return character.spell_void_bonus_used < get_daily_slots(character, 4)  # 4 = VOID ring


## Consumes one slot for the given ring, using void bonus if primary slots exhausted.
## Writes directly to character.spell_slots_used / spell_void_bonus_used.
static func consume_slot(character: L5RCharacterData, ring: int) -> void:
	var used_count: int = character.spell_slots_used.get(ring, 0)
	if used_count < get_daily_slots(character, ring):
		character.spell_slots_used[ring] = used_count + 1
	else:
		character.spell_void_bonus_used += 1


## Returns true if this character can cast the given spell right now.
static func can_cast(character: L5RCharacterData, spell_id: String) -> bool:
	if not SPELL_LIBRARY.has(spell_id):
		return false
	var spell: Dictionary = SPELL_LIBRARY[spell_id]
	var ml: int = spell.get("m", 1)
	var ring: int = spell.get("e", -1)
	# Void spells: Isawa Ishiken restriction
	if spell.get("i", false):
		if character.school != "Isawa Ishiken":
			var has_school: bool = false
			for sp: String in character.school_paths:
				if sp == "Isawa Ishiken":
					has_school = true
					break
			if not has_school:
				return false
	# Must know the spell
	if not (spell_id in character.spells_known):
		return false
	# School rank must meet mastery level
	if character.insight_rank < ml:
		return false
	# Must have a slot available
	var cast_ring: int = ring if ring >= 0 else get_best_cast_ring(character, spell_id)
	return can_afford_slot(character, cast_ring)


## Resolves a casting attempt in world simulation (1 AP, abstracted from combat rounds).
## Consumes a slot on both success and failure per GDD s31.
## Returns: {success, total, tn, margin, spell_id, sim_effect, cast_ring, raises, imbalance_overflow}
static func resolve_cast(character: L5RCharacterData, spell_id: String,
		dice: DiceEngine, raises: int = 0,
		target: L5RCharacterData = null, ic_day: int = -1) -> Dictionary:
	if not SPELL_LIBRARY.has(spell_id):
		return {"success": false, "error": "unknown_spell"}
	var spell: Dictionary = SPELL_LIBRARY[spell_id]
	var ml: int = spell.get("m", 1)
	var ring: int = spell.get("e", -1)
	var cast_ring: int = ring if ring >= 0 else get_best_cast_ring(character, spell_id)
	var ring_val: int = get_ring_value(character, cast_ring)
	var eff_rank: int = get_effective_school_rank(character, cast_ring)
	# WRATH_OF_THE_KAMI (s45): target's curse grants caster one Free Raise on the casting roll.
	var wrath_bonus: int = AdvantageSystem.get_wrath_of_kami_bonus(target, cast_ring) if target != null else 0
	var tn: int = get_casting_tn(ml) + (raises * 5) - (wrath_bonus * 5)
	# MASTER_OF_BLOOD (s44 line 117): all non-maho spells suffer +10 TN for the caster.
	# Every SpellSystem spell is non-maho, so the check is unconditional.
	if MutationSystem.has_power(character, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD):
		tn += 10
	var roll_dice: int = ring_val + eff_rank
	var keep_dice: int = ring_val
	# Slot consumed on attempt regardless of outcome
	consume_slot(character, cast_ring)
	var roll_result: DiceResult = dice.roll_and_keep(roll_dice, keep_dice)
	var total: int = roll_result.total
	var margin: int = total - tn

	# ELEMENTAL_IMBALANCE overflow (s45 lines 535-545): when casting the imbalanced element,
	# caster must roll Willpower (TN 15 + 5 × (rank-1)). On failure the element surges.
	var imbalance_result: Dictionary = {}
	var imb_check: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(character, cast_ring)
	if imb_check.get("triggered", false):
		var imb_tn: int = imb_check.get("tn", 15)
		var wil_val: int = character.willpower if character.willpower > 0 else 1
		var wil_roll: DiceResult = dice.roll_and_keep(wil_val, wil_val)
		if wil_roll.total < imb_tn:
			imbalance_result = AdvantageSystem.apply_elemental_imbalance_overflow(
				character, cast_ring, ml, dice, ic_day
			)

	return {
		"success": margin >= 0,
		"total": total,
		"tn": tn,
		"margin": margin,
		"spell_id": spell_id,
		"sim_effect": spell.get("s", SpellSimEffect.COMBAT_ONLY),
		"cast_ring": cast_ring,
		"raises": raises,
		"wrath_of_kami_bonus": wrath_bonus,
		"imbalance_overflow": imbalance_result,
	}


## Apply healing from a successful HEAL_WOUNDS cast. Returns {healed_wounds}.
## Healing amount: base by spell + 1 per 5 margin (PROVISIONAL formula).
static func apply_healing(target: L5RCharacterData, spell_id: String,
		margin: int) -> Dictionary:
	var base: int = _healing_base(spell_id)
	var healed: int = base + (margin / 5)
	if healed <= 0:
		return {"healed_wounds": 0}
	var before: int = target.wounds_taken
	target.wounds_taken = maxi(0, target.wounds_taken - healed)
	return {"healed_wounds": before - target.wounds_taken}


## Apply taint removal from a REMOVE_TAINT cast. Returns {taint_removed}.
## Removal amount: base by spell + 0.1 per margin point (PROVISIONAL formula).
static func apply_taint_removal(target: L5RCharacterData, spell_id: String,
		margin: int) -> Dictionary:
	var base: float = _taint_base(spell_id)
	var removed: float = base + float(margin) * 0.1
	if removed <= 0.0:
		return {"taint_removed": 0.0}
	var before: float = target.taint
	target.taint = maxf(0.0, target.taint - removed)
	return {"taint_removed": before - target.taint}


## Apply area purification from a PURIFY_AREA cast (s34 purge_the_taint).
## Reduces province PTL. Amount: base by spell + 0.1 per margin point (PROVISIONAL formula).
## Returns {ptl_reduced}.
static func apply_purify_area(province: ProvinceData, spell_id: String,
		margin: int) -> Dictionary:
	var base: float = _purify_base(spell_id)
	var reduced: float = base + float(margin) * 0.1
	if reduced <= 0.0:
		return {"ptl_reduced": 0.0}
	var before: float = province.province_taint_level
	province.province_taint_level = maxf(0.0, province.province_taint_level - reduced)
	return {"ptl_reduced": before - province.province_taint_level}


## Evaluate spirit detection result vs province PTL. Returns {detected, province_ptl}.
## Detection TN from GDD design decision #5: Perception + Lore: Shadowlands vs (PTL × 5).
static func apply_spirit_detection(margin: int, province_ptl: float) -> Dictionary:
	# The Sense spell roll feeds into the PTL-detection pipeline.
	# detect_tn is the target: PTL * 5 relative to base casting TN (ML1=10).
	var detect_tn_offset: int = int(province_ptl * 5.0) - get_casting_tn(1)
	var detected: bool = margin >= detect_tn_offset
	return {"detected": detected, "province_ptl": province_ptl}


## Evaluate ward creation attempt (s34 essence_of_jade).
## Gate: cannot ward a character who has at least 1 full Rank of Taint (taint >= 1.0).
## When blocked, the jade spirits' recoil reveals the caster's Taint to themselves.
## The ward's protective effect (Taint immunity for 10 rounds per GDD s34) is combat-only;
## no simulation-duration wiring exists until s40 individual combat is implemented.
## Returns {ward_applied: bool, taint_revealed: bool}.
static func apply_ward_creation(character: L5RCharacterData, _spell_id: String) -> Dictionary:
	var taint_rank: int = MutationSystem.get_taint_rank(character.taint)
	if taint_rank >= 1:
		# s34: jade spirits recoil — ward blocked and caster learns of their own Taint.
		return {"ward_applied": false, "taint_revealed": true}
	return {"ward_applied": true, "taint_revealed": false}


## Realms that each binding spell can suppress per GDD s34.
## bonds_of_ningen_do: "Affects creatures from Sakkaku, Chikushudo, Gaki-Do, Toshigoku,
##   or Yume-Do." (s34 ML3 — explicitly excludes Meido and Shadowlands/Jigoku creatures)
## freedom_of_the_air: "kansen, ghosts, and other hostile disembodied spirits within are
##   compelled to leave" — realm-agnostic per GDD s33 ML2; affects all 6 SpiritRealm types.
##   Duration: Air Ring hours. Classified SPIRIT_BIND for REALM_OVERLAP suppression.
## minor_binding / major_binding: bind Shadowlands/Tainted creatures (2h/12h combat
##   duration only) — COMBAT_ONLY, no REALM_OVERLAP suppression effect.
## All realms here correspond to SpiritualInsurgencyData REALM_OVERLAP event types only.
const BINDABLE_REALMS: Dictionary = {
	"bonds_of_ningen_do": [
		Enums.SpiritRealm.GAKI_DO,
		Enums.SpiritRealm.TOSHIGOKU,
		Enums.SpiritRealm.CHIKUSHUDO,
		Enums.SpiritRealm.SAKKAKU,
		Enums.SpiritRealm.YUME_DO,
	],
	"freedom_of_the_air": [
		Enums.SpiritRealm.GAKI_DO,
		Enums.SpiritRealm.TOSHIGOKU,
		Enums.SpiritRealm.CHIKUSHUDO,
		Enums.SpiritRealm.SAKKAKU,
		Enums.SpiritRealm.YUME_DO,
		Enums.SpiritRealm.MEIDO,
	],
}


## Returns true if the spell can bind a spirit of the given realm type.
static func can_bind_realm(spell_id: String, realm: Enums.SpiritRealm) -> bool:
	var bindable: Array = BINDABLE_REALMS.get(spell_id, [])
	return realm in bindable


## Find the first active REALM_OVERLAP spiritual insurgency event at the province that
## this spell can bind. Returns the SpiritualInsurgencyData or null.
## Used by _process_ritual_spell_writebacks to apply SPIRIT_BIND suppression (s34, s56.16).
static func find_bindable_spirit_event(
		spell_id: String,
		province_id: int,
		spiritual_insurgency_events: Array,
) -> SpiritualInsurgencyData:
	for event: Variant in spiritual_insurgency_events:
		if event is not SpiritualInsurgencyData:
			continue
		if event.resolved:
			continue
		if event.province_id != province_id:
			continue
		if event.event_type != Enums.SpiritualEventType.REALM_OVERLAP:
			continue
		if can_bind_realm(spell_id, event.realm):
			return event
	return null


## Returns all spell IDs in spells_known matching a given SpellSimEffect.
static func get_spells_by_sim_effect(character: L5RCharacterData,
		effect: SpellSimEffect) -> Array[String]:
	var result: Array[String] = []
	for spell_id: String in character.spells_known:
		if not SPELL_LIBRARY.has(spell_id):
			continue
		if SPELL_LIBRARY[spell_id].get("s", SpellSimEffect.COMBAT_ONLY) == effect:
			result.append(spell_id)
	return result


## Returns the highest-mastery-level spell with a given effect, or "" if none.
static func get_best_spell_by_effect(character: L5RCharacterData,
		effect: SpellSimEffect) -> String:
	var best: String = ""
	var best_ml: int = -1
	for spell_id: String in character.spells_known:
		if not SPELL_LIBRARY.has(spell_id):
			continue
		var spell: Dictionary = SPELL_LIBRARY[spell_id]
		if spell.get("s", SpellSimEffect.COMBAT_ONLY) != effect:
			continue
		var ml: int = spell.get("m", 0)
		if ml > best_ml:
			best_ml = ml
			best = spell_id
	return best


## Group A: person-intelligence divination — caster must be co-located with target.
## Produces personality_insight KnowledgeEntries. (s33-s37)
const INFORMATION_GATHER_GROUP_A: Array[String] = [
	"know_the_mind",       # Air ML4: reads thoughts
	"look_into_the_soul",  # Air ML4: reads 2 lowest Rings
	"see_through_lies",    # Void ML1, Ishiken: reads Advantage/Disadvantage
]

## Group B: remote location-scrying divination. No co-location required.
## Produces location_intelligence KnowledgeEntries. (s33-s36)
const INFORMATION_GATHER_GROUP_B: Array[String] = [
	"boundless_sight",       # Void ML1, Ishiken: see+hear 50-mile range
	"reflective_pool",       # Water ML2: visual 10-mile range
	"dominion_of_suitengu",  # Water ML4: visual 100-mile range, coastal only
]

## Returns the best INFORMATION_GATHER spell usable by the NPC decision pipeline
## (Group A or Group B only — other INFORMATION_GATHER spells produce no persistent
## knowledge in the simulation and are excluded from NPC selection).
## Prefers Group B (higher max ML: dominion ML4 > look_into_soul ML4 tie-break).
## If no processable spell is known, returns "".
static func get_best_npc_information_spell(character: L5RCharacterData) -> String:
	var best: String = ""
	var best_ml: int = -1
	for spell_id: String in character.spells_known:
		if not SPELL_LIBRARY.has(spell_id):
			continue
		if not (spell_id in INFORMATION_GATHER_GROUP_A or \
				spell_id in INFORMATION_GATHER_GROUP_B):
			continue
		var ml: int = SPELL_LIBRARY[spell_id].get("m", 0)
		if ml > best_ml:
			best_ml = ml
			best = spell_id
	return best


static func get_best_healing_spell(character: L5RCharacterData) -> String:
	return get_best_spell_by_effect(character, SpellSimEffect.HEAL_WOUNDS)


static func get_best_taint_removal_spell(character: L5RCharacterData) -> String:
	return get_best_spell_by_effect(character, SpellSimEffect.REMOVE_TAINT)


static func get_best_purify_spell(character: L5RCharacterData) -> String:
	return get_best_spell_by_effect(character, SpellSimEffect.PURIFY_AREA)


static func get_best_detection_spell(character: L5RCharacterData) -> String:
	return get_best_spell_by_effect(character, SpellSimEffect.DETECT_PRESENCE)


static func get_best_ritual_spell(character: L5RCharacterData) -> String:
	return get_best_spell_by_effect(character, SpellSimEffect.RITUAL_HONOR)


## Returns the AsciiMapEnvironment.WeatherState int written to the province by a
## WEATHER_SHIFT spell. Locked in s31-37a A80/A82.
## Returns 0 (CLEAR) for any spell without a province weather write.
static func get_weather_shift_state(spell_id: String) -> int:
	match spell_id:
		"endless_deluge": return 3   # WeatherState.STORM — A80
		"breath_of_mist": return 5   # WeatherState.MIST  — A82
	return 0  # WeatherState.CLEAR (no province write)


## Returns how many IC days the province weather state persists after casting.
## Locked in s31-37a A81/A83.
static func get_weather_shift_duration_days(spell_id: String) -> int:
	match spell_id:
		"endless_deluge": return 1   # 12 hours → rounds up to 1 IC day tick — A81
		"breath_of_mist": return 1   # Water Ring hours → ≤10h → 1 IC day tick — A83
	return 1


## Assign starting spells to a shugenja. Call once at character creation.
## PROVISIONAL — curricula pending s28/s29 review.
static func assign_starting_spells(character: L5RCharacterData, school: String) -> void:
	var starting: Array = _SCHOOL_STARTING_SPELLS.get(school, _DEFAULT_STARTING_SPELLS)
	for spell_id: Variant in starting:
		var sid: String = str(spell_id)
		if SPELL_LIBRARY.has(sid) and not (sid in character.spells_known):
			character.spells_known.append(sid)


## Returns true if a character is a shugenja school type.
static func is_shugenja(character: L5RCharacterData) -> bool:
	return character.school_type == Enums.SchoolType.SHUGENJA


## Returns all spell IDs for a given element and mastery level.
static func get_spells_for_element_ml(element: int, mastery_level: int) -> Array[String]:
	var result: Array[String] = []
	for spell_id: String in SPELL_LIBRARY:
		var spell: Dictionary = SPELL_LIBRARY[spell_id]
		if spell.get("e", -1) == element and spell.get("m", 0) == mastery_level:
			result.append(spell_id)
	return result


## -- Internal helpers --

static func _healing_base(spell_id: String) -> int:
	## PROVISIONAL: base wound reduction per spell (GDD s34/s36 do not specify amounts).
	## Only spells classified HEAL_WOUNDS (s=1) should appear here.
	match spell_id:
		"regrow_the_wound":    return 2  # Water ML3 — wounds per round (scaled at resolution)
		"rise_from_the_ashes": return 3  # Void ML6 — restores prior state, undoing injuries
	return 1


static func _taint_base(spell_id: String) -> float:
	## PROVISIONAL: base taint reduction per spell (GDD s34 specifies these spells
	## reduce character taint; amounts not numerically specified).
	match spell_id:
		"tomb_of_jade":   return 1.5
	return 0.5


static func _purify_base(spell_id: String) -> float:
	## PROVISIONAL: base province PTL reduction per PURIFY_AREA spell
	## (GDD s34 specifies purge_the_taint removes taint from land; amount not specified).
	match spell_id:
		"purge_the_taint": return 1.0
	return 0.5
