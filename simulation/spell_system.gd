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
## Spells carrying the Jade/Crystal property (s31–s37). A jade/crystal-property spell cast at
## a superior_invuln spirit repels it (s54.12 Furaribi rule). PARTIAL — jade_strike is the
## certain entry; the full property list is Phase 2 transcription.
const JADE_CRYSTAL_PROPERTY_SPELLS: Dictionary = {"jade_strike": true}

static func has_jade_or_crystal_property(spell_id: String) -> bool:
	return JADE_CRYSTAL_PROPERTY_SPELLS.get(spell_id, false)

## Phase 2 — per-spell combat effects (s31–s37), transcribed from the GDD. Keyed by spell_id.
## Direct-damage spells across all five rings. Fields:
##   kind        : "damage"
##   dr_rolled / dr_kept : damage roll dice; 0 means "use the spell's element Ring"
##   dr_rolled_bonus : added to the rolled count after the ring substitution (Slayer's Knives: ring+2)
##   range_tiles : single-target reach, OR cast range to an AoE center, in tiles (1 tile = 5 ft); 0 = self-centered
##   aoe_radius  : 0 = single target; >0 = radius in tiles (Chebyshev). Centered on the target tile when
##                 range_tiles>0 (targeted blast), else on the caster (self-centered cone/burst)
##   aoe_hits    : "enemies" (foes only) or "all" (friend + foe)
##   caster_exempt : AoE never damages the caster
##   requires_taint : 0 damage to a target with Taint Rank < 1 (Jade Strike)
##   rider       : optional condition applied to each damaged target —
##                 {condition: "prone"/"dazed"/"fatigued"/"deafened",
##                  save: "none"/"earth_flat"/"stamina_flat"/"earth_contested_air",
##                  save_tn: int (flat saves), duration_rounds: int (0 = roll-recovered/instant)}
## DR routes through the invuln filter as magic (always) + the spell's element kind (fire/water), so
## flame_immune blocks/heals fire spells and water_vulnerable doubles water spells. Cones/diameters are
## modeled as Chebyshev radii (length-or-diameter ÷ 5 = tiles) — an over-application behind the caster,
## since facing is not tracked (same compromise as the kiho cone layer). Multi-round channels and
## weather damage bonuses are deferred to later tranches.
const SPELL_COMBAT_EFFECTS: Dictionary = {
	# --- Fire (s35) ---
	# Coverage extension (2026-06-20): tendril/swarm/dragon-talon damage + Earth grasp.
	"tail_of_the_fire_dragon": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 6, "aoe_radius": 0},  # Fire 2: DR = caster Fire Ring, 30'
	"ravenous_swarms": {"kind": "damage", "dr_rolled": 5, "dr_kept": 3,
		"range_tiles": 6, "aoe_radius": 0},  # Fire 3: 5k3 bolt, 30' (fire-disrupt rider deferred)
	"the_dragons_talon": {"kind": "damage", "dr_rolled": 8, "dr_kept": 6,
		"range_tiles": 20, "aoe_radius": 20, "aoe_hits": "enemies", "caster_exempt": true,
		"target_max_insight": 2, "aoe_max_targets": 10},  # Fire 5: 8k6, up to 10 weak foes, 100'
	"grasp_of_earth": {"kind": "status", "condition": "entangled", "save": "none",
		"range_tiles": 10, "aoe_radius": 0, "duration_rounds": 0},  # Earth 2: stony grip, 50'
	# Coverage extension batch 2 (2026-06-20).
	"envious_flames": {"kind": "damage", "dr_rolled": 2, "dr_kept": 2,
		"range_tiles": 6, "aoe_radius": 0},  # Fire 1: 2k2 unerring lance, 30' (cast-disrupt rider deferred)
	"the_fires_from_within": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 20, "aoe_radius": 0},  # Fire 2: the classic fireball, DR = Fire Ring, 100'
	"the_fist_of_osano_wo": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 10, "aoe_radius": 4, "aoe_hits": "all", "caster_exempt": true},  # Fire 3: DR=Fire Ring, 20' radius
	"earthquake": {"kind": "damage", "dr_rolled": 2, "dr_kept": 1,
		"range_tiles": 0, "aoe_radius": 99, "aoe_hits": "all", "caster_exempt": true,
		"rider": {"condition": "prone", "save": "none"}},  # Earth 5: 2k1 + Prone, caster exempt
	# Coverage extension batch 3 (2026-06-20).
	"striking_the_storm": {"kind": "buff", "target": "self", "duration_rounds": 3,
		"mods": [{"kind": "armor_tn", "value": 20}]},  # Air 3: +20 Armor TN cocoon (deafens self — deferred)
	# Flight (s4.4, owner-defined 2026-06-24: "flight = occupy an empty space"). A "flight"
	# timed modifier lets the caster move over/occupy open spaces (air/void, water) and ignore
	# elevation cliffs and fall/pit hazards. The modifier VALUE is a speed code read by the
	# orchestrator: 1 = Call Upon the Wind (≤10'/Round, Free Move only), 2 = Wings of Fire
	# (Water 1 speed; arms occupied — cannot make weapon attacks), 3 = Wings of the Phoenix
	# (Water×10' Free / Water×20' Simple). Durations: Air 2 = 1 min (10 rounds), Fire 2 = 10 min
	# (100 rounds), Fire 5 = 10 Rounds (GDD-explicit).
	"call_upon_the_wind": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "flight", "value": 1}]},          # Air 2 [CR]: limited flight, Free Move only
	"wings_of_fire": {"kind": "buff", "target": "self", "duration_rounds": 100,
		"mods": [{"kind": "flight", "value": 2}]},          # Fire 2: slow flight, arms occupied
	"wings_of_the_phoenix": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "flight", "value": 3}]},          # Fire 5 [CR]: full flight
	"sapphire_strike": {"kind": "damage", "dr_rolled": 4, "dr_kept": 4, "requires_taint": true,
		"range_tiles": 10, "aoe_radius": 0},  # Earth 4: 4k4 vs jade/crystal-vulnerable only, 50'
	# Coverage extension batch 4 (2026-06-20): conjured elemental weapons (5 min = 50 rounds).
	# Wielder uses effective School Rank for the weapon skill; per-spell Honor/Free-Raise extras deferred.
	"katana_of_fire": {"kind": "conjure_weapon", "dr_rolled": 2, "dr_kept": 2,
		"skill": "Kenjutsu", "duration_rounds": 50},  # Fire 1: DR 2k2 fire blade
	"tetsubo_of_earth": {"kind": "conjure_weapon", "dr_rolled": 2, "dr_kept": 2,
		"skill": "Heavy Weapons", "duration_rounds": 50},  # Earth 1: DR 2k2 stone tetsubo
	"yari_of_air": {"kind": "conjure_weapon", "dr_rolled": 1, "dr_kept": 1,
		"skill": "Spears", "duration_rounds": 50},  # Air 1: DR 1k1 air spear
	"bo_of_water": {"kind": "conjure_weapon", "dr_rolled": 1, "dr_kept": 2,
		"skill": "Staves", "duration_rounds": 50},  # Water 1: DR 1k2 water staff
	# Coverage extension batch 5 (2026-06-20): wound-ward + fortify buffs.
	"the_kamis_strength": {"kind": "buff", "target": "ally", "range_tiles": 6, "duration_rounds": 5,
		"mods": [{"kind": "reduction", "value": 20},
			{"kind": "spell_damage_rolled", "value": "earth_ring"}]},  # Earth 5: Reduction 20 + Strength boost (no-Simple-Move deferred)
	"near_to_ice": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 5,
		"mods": [{"kind": "negate_wound_penalty", "value": 1}]},  # Water 3: Wound Penalties negated
	"force_of_will": {"kind": "buff", "target": "ally", "range_tiles": 10, "duration_rounds": 2,
		"mods": [{"kind": "negate_wound_penalty", "value": 1}]},  # Earth 2: penalties negated (death-immunity deferred)
	# Coverage extension batch 6 (2026-06-20).
	"dart_of_void": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 20, "aoe_radius": 0},  # Void 4: DR = Void Ring, ignores Invuln/Reduction (magic path), 100'
	"earthen_wave": {"kind": "status", "condition": "prone", "save": "strength_contested_earth",
		"range_tiles": 0, "aoe_radius": 5, "aoe_hits": "enemies", "caster_exempt": true,
		"duration_rounds": 0},  # Earth 3: shockwave Knockdown in a line, Contested Strength vs Earth
	"shining_light": {"kind": "buff", "target": "ally", "range_tiles": 6, "duration_rounds": 10,
		"mods": [{"kind": "shining_light", "value": 1}]},  # Fire 3: armor flares — melee attacker takes 2k2 + Blinded
	# Coverage extension batch 8 (2026-06-20): persistent damage zones (per-round standing damage).
	"wall_of_fire": {"kind": "damage_zone", "dr_rolled": 6, "dr_kept": 6, "aoe_radius": 1,
		"range_tiles": 20, "aoe_hits": "all", "duration_rounds": 50},  # Fire 4: 6k6/round, 100'
	"castle_of_fire": {"kind": "damage_zone", "dr_rolled": 6, "dr_kept": 6, "aoe_radius": 6,
		"range_tiles": 0, "aoe_hits": "enemies", "duration_rounds": 10},  # Fire 5: fiery castle, enemies burn
	"enticing_the_dance_of_flame": {"kind": "damage_zone", "dr_rolled": 2, "dr_kept": 1,
		"impact_rolled": 3, "impact_kept": 2, "aoe_radius": 4, "range_tiles": 10,
		"aoe_hits": "all", "duration_rounds": 2},  # Fire 2: 3k2 impact + 2k1/round, 20' radius
	"follow_the_flame": {"kind": "damage", "dr_rolled": 6, "dr_kept": 5,
		"range_tiles": 60, "aoe_radius": 0},  # Fire 5: 6k5 stream of fire, 300' (persistent burn deferred)
	# Air 6 [CR] Wrath of Kaze-no-Kami (Hurricane): whole-map storm, eye (20'=4 tiles) follows the
	# caster. Per minute (= ROUNDS_PER_MINUTE Rounds, owner 2026-06-25) everyone OUTSIDE the eye —
	# all factions — takes 1k1 Wounds, or on a 1-in-10 a 5k5 debris strike that also flings them
	# (knockback, not death — owner choice). Concentration (max 1 hour = 600 rounds); ends if the
	# caster dies. fling_tiles PROVISIONAL (GDD gives no knockback distance for "cast into the winds").
	"wrath_of_kaze_no_kami": {"kind": "hurricane", "eye_radius": 4,
		"minor_rolled": 1, "minor_kept": 1, "major_rolled": 5, "major_kept": 5,
		"major_chance_in": 10, "fling_tiles": 3, "duration_rounds": 600},
	# Water 2 Yuki's Touch: flash-freeze a body of water to 100' (20 tiles) — tiles become solid
	# walkable ice; everyone standing in the water (all factions) is trapped (Entangled), breaking
	# free via Strength vs the caster's Water roll. Deep-water victims drown (owner 2026-06-25).
	"yukis_touch": {"kind": "freeze_water", "range_tiles": 20, "duration_rounds": 9999},
	"whirlpool": {"kind": "whirlpool", "radius": 6, "tn": 30, "duration_rounds": 9999},  # Water 5: open-water vortex — swimmers in the area roll Athletics(Swimming)/Strength TN 30 each Round or drown
	# Fire 6 Curse of the Burning Hand: a Contested-Fire curse on an enemy at 10' (2 tiles). The cursed
	# target is wreathed in flame — each round its OWN allies (same faction) adjacent take 3k3 and the
	# flammable tile underfoot ignites. Never burns the target's attackers. Infinite -> skirmish (owner
	# 2026-06-25). Per-round effect in advance_round; PC-deliberate (not in the NPC offense picker).
	"curse_of_the_burning_hand": {"kind": "curse_burning_hand", "range_tiles": 2, "duration_rounds": 9999},
	# Fire 4 Essence of Fire: the Asahina anti-tampering ward, modeled as a general anti-spell ward
	# (owner 2026-06-25) on the caster + the chosen target (10' = 2 tiles). Each warded duelist has its
	# ongoing spell effects ended and any spell cast AT it suffers −3k0. Skirmish-long. 4-Raise
	# Technique-suppression variant deferred.
	"essence_of_fire": {"kind": "essence_of_fire", "range_tiles": 2, "rolled_penalty": 3, "duration_rounds": 9999},
	# Air 4 Netsuke of Wind: conjure a fully-functional weapon the shugenja chooses from the catalog
	# (owner 2026-06-25) — it gets that weapon's REAL profile (DR + Strength + skill + trait), unlike the
	# fixed-DR elemental conjures. Defaults to the caster's best melee weapon. 1 hour -> skirmish.
	"netsuke_of_wind": {"kind": "conjure_weapon", "real_weapon": true, "duration_rounds": 600},
	# Coverage extension batch 9 (2026-06-20): area wards (enemy-cast TN penalty + spell DR reduction).
	"earths_protection": {"kind": "ward", "aoe_radius": 2, "duration_rounds": 10,
		"ward_elements": [0, 2, 3], "cast_tn_penalty": 10,
		"dr_reduction_rolled": 1, "dr_reduction_kept": 1},  # Earth 3: +10 TN & -1k1 vs Air/Fire/Water in 10'
	"ward_of_thunder": {"kind": "ward", "aoe_radius": 3, "duration_rounds": 50,
		"ward_elements": [2], "cast_tn_penalty": 20},  # Fire 4: +20 TN to hostile Fire within 15'
	"grounding_energy": {"kind": "grounding_energy", "aoe_radius": 4, "duration_rounds": 3},  # Earth 5: anti-maho ward — maho combat spells cannot land on warded allies within 20' (3 rounds)
	# Coverage extension batch 10 (2026-06-20): summoned elemental kami (autonomous ally combatant).
	"rise_air": {"kind": "summon"},    # Air 5: kami, all Physical Traits = Air Ring, Invulnerable
	"rise_earth": {"kind": "summon"},  # Earth 5: kami, all Physical Traits = Earth Ring, Invulnerable
	"rise_fire": {"kind": "summon"},   # Fire 5: kami, Fire Ring traits + sets struck targets on fire
	"rise_water": {"kind": "summon"},  # Water 5: kami, all Physical Traits = Water Ring, Invulnerable
	# Coverage extension batch 11 (2026-06-20).
	"soldiers_of_clay": {"kind": "summon", "summon_kind": "clay_soldier", "count": 10},  # Earth 6: 10 stone warriors
	"be_the_mountain": {"kind": "buff", "target": "ally", "range_tiles": 6, "duration_rounds": 4,
		"mods": [{"kind": "reduction", "value": "be_the_mountain_reduction"}]},  # Earth 2: Reduction 5×rank (max 20)
	"never_alone": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 5,
		"mods": [{"kind": "spell_attack_rolled", "value": "fire_ring"}]},  # Fire 1: +Fire to rolls (conditional expiry deferred)
	"defense_of_the_firestorm": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 5,
		"mods": [{"kind": "armor_tn", "value": 20}]},  # Fire 4: +20 Armor TN flame aura (wooden-weapon burn deferred)
	# === EARTH WAVE A (2026-06-20): debuff path + fear/knockdown resist ===
	"courage_of_the_seven_thunders": {"kind": "buff", "target": "ally", "range_tiles": 6,
		"duration_rounds": 100, "mods": [{"kind": "fear_resist_rolled", "value": 5}]},  # Earth 1: +5k0 Fear resist (minor-clan +3k0 + group + Taint clause deferred)
	"the_mountains_feet": {"kind": "buff", "target": "ally", "range_tiles": 4, "duration_rounds": 50,
		"mods": [{"kind": "knockdown_resist_rolled", "value": 3}]},  # Earth 2: +3k0 resist Knockdown
	"strike_as_stone": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 30,
		"mods": [{"kind": "spell_damage_rolled", "value": 2}]},  # Earth 3: unarmed DR +2k0 (unarmed-only scope approximated)
	"earths_stagnation": {"kind": "debuff", "target": "enemy", "range_tiles": 10, "duration_rounds": 6,
		"mods": [{"kind": "spell_attack_rolled", "value": -2}, {"kind": "move_water_penalty", "value": -1}]},  # Earth 1: -2k0 Agility + -1 Rank movement (move_water_penalty is ADDED to Water in _effective_water_ring, so a reduction is negative — was +1, a sign bug that increased the enemy's movement)
	"earth_becomes_sky": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0, "range_tiles": 20,
		"aoe_radius": 0},  # Earth 2: hurled boulders, DR = Earth Ring (multi-target -1k1 simplified to single)
	# === EARTH WAVE B (2026-06-20): absorption shield + debuff immunity ===
	"power_of_the_earth_dragon": {"kind": "buff", "target": "ally", "range_tiles": 10,
		"duration_rounds": 100, "mods": [{"kind": "absorb_pool", "value": 100}]},  # Earth 6: absorbs 100 Wounds then ends
	"wholeness_of_the_world": {"kind": "buff", "target": "ally", "range_tiles": 4, "duration_rounds": 100,
		"mods": [{"kind": "immune_trait_change", "value": 1}]},  # Earth 2: immune to Trait/Ring-altering effects
	# Coverage extension batch 12 (2026-06-20): save-negates AoE + sun zone/buff.
	"murmur_of_earth": {"kind": "damage", "dr_rolled": 1, "dr_kept": 1, "range_tiles": 0,
		"aoe_radius": 20, "aoe_hits": "all", "caster_exempt": true,
		"save": "agility_flat", "save_tn": 20, "save_negates": true,
		"rider": {"condition": "prone", "save": "none"}},  # Earth 3: Agility TN 20 or 1k1 + Prone (Dazed deferred)
	"maw_of_the_earth": {"kind": "damage", "dr_rolled": 3, "dr_kept": 2, "range_tiles": 8,
		"aoe_radius": 2, "aoe_hits": "all", "caster_exempt": true,
		"save": "reflexes_contested_earth", "save_negates": true,
		"rider": {"condition": "entangled", "save": "none"}},  # Earth 4: Reflexes vs Earth or fall in (3k2 + trapped)
	"the_fires_that_cleanse": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0, "range_tiles": 0,
		"aoe_radius": 6, "aoe_hits": "all", "caster_exempt": true},  # Fire 1: DR=Fire Ring to all in 30' (caster-half deferred)
	"light_of_the_sun": {"kind": "damage_zone", "dr_rolled": 2, "dr_kept": 2, "range_tiles": 20,
		"aoe_radius": 6, "aoe_hits": "all", "duration_rounds": 10},  # Fire 5: 2k2/round in 30' (honor/taint bonus deferred)
	"blessing_of_the_sun": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 3,
		"mods": [{"kind": "negate_wound_penalty", "value": 1}]},  # Fire 4: ignore Fatigue/Wound penalties (Fire-roll scope + cost deferred)
	# Coverage extension batch 13 (2026-06-20).
	"oath_of_the_heavens": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 5,
		"mods": [{"kind": "spell_attack_rolled", "value": 2}]},  # Fire 3: +2k0 Fire rolls (2-target link + shared conditions deferred)
	"balance_of_elements": {"kind": "heal", "heal": "dice", "heal_rolled": 3, "heal_kept": 3,
		"range_tiles": 1},  # Void 4 (Ishiken): heal 3k3 (disadvantage negation deferred)
	"relentless_heat": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 10,
		"mods": [{"kind": "relentless_heat", "value": 1}]},  # Fire 2: melee attacker Fatigued on attempt + Full Attack->Attack
	# Fury's Deafen rider (Stamina TN 15, 2 Rounds) is a bystander AoE within 10' of the TARGET,
	# not a rider on the damaged target — deferred (needs a sub-AoE + a hearing mechanic; Deafened
	# has no combat effect yet). CONDITION_DEAFENED + the timed rider path remain forward-wired.
	"fury_of_osano_wo": {"kind": "damage", "dr_rolled": 5, "dr_kept": 2,
		"range_tiles": 60, "aoe_radius": 0},
	"breath_of_the_fire_dragon": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 0, "aoe_radius": 3, "aoe_hits": "enemies", "caster_exempt": true},
	"destructive_wave": {"kind": "damage", "dr_rolled": 7, "dr_kept": 7,
		"range_tiles": 0, "aoe_radius": 5, "aoe_hits": "all", "caster_exempt": true},
	"beam_of_the_inferno": {"kind": "damage", "dr_rolled": 10, "dr_kept": 10,
		"range_tiles": 40, "aoe_radius": 0},
	# Fire coverage extension (2026-06-20): sunlight/blade attack buffs + two Fire wards.
	"the_breath_of_battle": {"kind": "buff", "target": "ally", "range_tiles": 6, "duration_rounds": 5,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}, {"kind": "spell_attack_kept", "value": 1}, {"kind": "spell_damage_rolled", "value": 1}]},  # Fire 3: +1k1 Agility(attack) + 1k0 damage (sunlight-only requirement not modeled)
	"hungry_blade": {"kind": "buff", "target": "ally", "range_tiles": 10, "duration_rounds": 5,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}]},  # Fire 3: +1k0 attack (explode-on-8 damage mechanic deferred)
	"globe_of_the_everlasting_sun": {"kind": "ward", "aoe_radius": 99, "duration_rounds": 9999,
		"ward_elements": [2], "cast_tn_penalty": 15},  # Fire 6: +15 TN to Fire spells in the area (1-mile = whole skirmish; building fire-immunity not modeled)
	"agashas_shield": {"kind": "ward", "aoe_radius": 6, "duration_rounds": 6,
		"ward_elements": [2], "dr_reduction_rolled": 3},  # Fire 3: hostile Fire-spell DR -3k0 inside (the -4k0 cast-roll dice penalty does not map to the flat-TN ward; not modeled)
	# Fire coverage extension batch 2 (2026-06-20): FireSystem ignite / extinguish.
	"fiery_wrath": {"kind": "ignite_zone", "range_tiles": 20, "aoe_radius": 5},  # Fire 3: ignite all flammable tiles in a 50'×50' area (FireSystem; magical-fire / flesh-spared nuances not modeled)
	"extinguish": {"kind": "extinguish", "aoe_radius": 20},  # Fire 1: snuff non-magical fire in 100' radius — clears burning tiles + on_fire from creatures (magical/non-magical not distinguished)
	"everburning_rage": {"kind": "status", "condition": "incapacitated", "save": "none",
		"range_tiles": 5, "aoe_radius": 0, "duration_rounds": 1},  # Fire 5: target treated as Down (no actual Wounds) for 1 Round
	# --- Air (s33) ---
	# Tempest of Air: Personal, 75' cone, 1k1 + Knockdown (Contested Earth vs caster Air)
	"tempest_of_air": {"kind": "damage", "dr_rolled": 1, "dr_kept": 1,
		"range_tiles": 0, "aoe_radius": 15, "aoe_hits": "enemies", "caster_exempt": true,
		"rider": {"condition": "prone", "save": "earth_contested_air"}},
	# Howl of Isora: Range 100', 40' diameter burst, 3k2 to all + Fatigue (Earth TN 30)
	"howl_of_isora": {"kind": "damage", "dr_rolled": 3, "dr_kept": 2,
		"range_tiles": 20, "aoe_radius": 4, "aoe_hits": "all", "caster_exempt": true,
		"rider": {"condition": "fatigued", "save": "earth_flat", "save_tn": 30}},
	# Slayer's Knives: Range 30' corridor, DR = Air Ring +2k0 + Knockdown (Earth TN 20)
	"slayers_knives": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0, "dr_rolled_bonus": 2,
		"range_tiles": 0, "aoe_radius": 6, "aoe_hits": "enemies", "caster_exempt": true,
		"rider": {"condition": "prone", "save": "earth_flat", "save_tn": 20}},
	# Air coverage extension (2026-06-20): fear-resist buff, fear status, mind hex, invisibility, summon.
	"soul_of_kaze_no_kami": {"kind": "buff", "target": "ally", "range_tiles": 4, "duration_rounds": 100,
		"mods": [{"kind": "fear_resist_rolled", "value": 2}, {"kind": "fear_resist_kept", "value": 2}]},  # Air 3: +2k2 resist Fear (Social-resist + Awareness -2k0 downside out-of-combat, deferred)
	"your_hearts_enemy": {"kind": "status", "condition": "afraid", "save": "willpower_flat", "save_tn": 25,
		"range_tiles": 5, "aoe_radius": 0, "duration_rounds": 5},  # Air 3: Fear 4 illusion (TN 5+4×5=25 per s22.3)
	"whispers_of_the_forgotten": {"kind": "debuff", "target": "enemy", "range_tiles": 10, "duration_rounds": 50,
		"mods": [{"kind": "all_rolls", "value": -5}]},  # Air 4: must call 1 Raise (=+5 TN) on all rolls (disadvantage-count 2-Raise scaling + haunting-past immunity deferred)
	"gift_of_wind": {"kind": "buff", "target": "self", "duration_rounds": 50,
		"mods": [{"kind": "invisible", "value": 1}]},  # Air 4: invisible to non-magical vision; attacking ends it
	"request_to_hato_no_kami": {"kind": "debuff", "target": "enemy", "range_tiles": 30, "duration_rounds": 1,
		"mods": [{"kind": "all_rolls", "value": -1}]},  # Air 2: a summoned bird distracts one enemy (-1k0 for a Round); GM-judgment "distract an enemy" use
	"defender_from_beyond": {"kind": "summon", "summon_kind": "shiryo", "count": 1},  # Air 5 (Kitsu): summon a shiryo ancestor (all Rings 3, Rank 4 skills)
	# Air coverage extension batch 2 (2026-06-20): wound-penalty negation, AoE invisibility, insubstantial.
	"to_seek_the_truth": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 50,
		"mods": [{"kind": "negate_wound_penalty", "value": 1}]},  # Air 1: negates temporary penalties (combat slice = Wound Rank penalties; Technique/social negation out-of-combat)
	"legion_of_the_moon": {"kind": "buff", "target": "ally", "aoe_radius": 2, "duration_rounds": 50,
		"mods": [{"kind": "invisible", "value": 1}]},  # Air 5: every chosen ally within 10' invisible; acting against another reveals that ally (reveal-on-attack)
	"the_eye_shall_not_see": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "invisible", "value": 1}]},  # Air 3: "not invisible" but those nearby do not see the target until a loud/attention-drawing action — modeled as the untargetable + reveal-on-attack (attention-drawing) hook. Concentration ~ skirmish. (The 20' range limit is approximated as full untargetability — combat is usually within 20'.)
	"the_false_legion": {"kind": "buff", "target": "ally", "aoe_radius": 6, "duration_rounds": 9999,
		"mods": [{"kind": "decoy_absorb", "value": 1}]},  # Air 6: up to Air Ring x10 illusory figures fill the area; allies hide among them, so each attack against an ally within the area has the derived 50% chance (real vs identical figure) to strike a figure and accomplish nothing. AoE-ally decoy (reuses the Way-of-Deception absorb + the AoE-ally buff path). Concentration ~ skirmish. (Per-target absorption kept at the derived 50% — the spell's modeled value is AREA coverage, not a higher per-target rate, which would invent a number. radius 6 = 30' PROVISIONAL, a protective cluster within the GDD's 100' figure spread.)
	"essence_of_air": {"kind": "buff", "target": "self", "duration_rounds": 5,
		"mods": [{"kind": "insubstantial", "value": 1}]},  # Air 3: insubstantial — untargetable but cannot attack or cast (Water-halved + pass-through-objects deferred)
	"castle_of_air": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "attacker_penalty", "value": -5}]},  # Air 4: attackers suffer -5k0 (per-round Perception-vs-Air contest simplified to always-on; does not affect spells)
	# Concentration = skirmish-length (duration_rounds 9999) per owner convention (2026-06-20):
	# matches the "while active" kiho/kata precedent — no invented finite round count.
	"blessed_wind": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "ranged_armor_tn", "value": 15}]},  # Air 1: +15 Armor TN vs non-magical ranged while concentrating ("non-magical ranged only" gate not modeled — applies to all ranged)
	# --- Earth (s34) ---
	# Jade Strike: Range 100', single, DR 3k3 ONLY vs Taint Rank 1+ (also a jade-property spell)
	"jade_strike": {"kind": "damage", "dr_rolled": 3, "dr_kept": 3,
		"range_tiles": 20, "aoe_radius": 0, "requires_taint": true},
	# Earth coverage extension (2026-06-20): equipment debuff, group buff, two go-to-ground hides.
	"times_deadly_hand": {"kind": "debuff", "target": "enemy", "range_tiles": 1, "duration_rounds": 9999,
		"mods": [{"kind": "spell_damage_rolled", "value": -2}, {"kind": "spell_damage_kept", "value": -1}]},  # Earth 3: weaken one object — wired as the target's weapon (-2k1 DR); the armor-object variant (-5 Armor TN / -3 Reduction) is the unmodeled alternative
	"sharing_the_strength_of_many": {"kind": "buff", "target": "ally", "aoe_radius": 4, "duration_rounds": 5,
		"mods": [{"kind": "all_rolls", "value": "earth_ring"}]},  # Earth 3: +lowest-Earth to all rolls (approx as caster's Earth Ring; 6-target cap not enforced; combat slice = attack rolls)
	"embrace_of_kenro_ji_jin": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "insubstantial", "value": 1}]},  # Earth 2: dive into the earth — untargetable but cannot attack/cast (move-through-earth / 100yd earth-sight deferred)
	"shelter_of_the_earth": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 9999,
		"mods": [{"kind": "insubstantial", "value": 1}]},  # Earth 3: concealed as a natural object — untargetable but cannot act (modeled like Essence of Air's go-to-ground)
	# Earth bindings (2026-06-20): incapacitate a Tainted/Shadowlands creature (the CONDITION_INCAPACITATED
	# turn-gate skips its Turn + flat-foots it). The Tainted/spirit gate stands in for the GDD's
	# per-spell Earth-rank / realm restrictions; GDD hours/permanent ≈ skirmish-length (9999).
	"minor_binding": {"kind": "status", "condition": "incapacitated", "requires_shadowlands": true,
		"range_tiles": 12, "aoe_radius": 0, "duration_rounds": 9999},  # Earth 1: imprison a minor Tainted Shadowlands creature
	"major_binding": {"kind": "status", "condition": "incapacitated", "requires_shadowlands": true,
		"save": "earth_contested", "range_tiles": 20, "aoe_radius": 0, "duration_rounds": 9999},  # Earth 5: Contested Earth → jade manacles hold any Shadowlands/Tainted creature
	"prison_of_earth": {"kind": "status", "condition": "incapacitated", "requires_shadowlands": true,
		"save": "willpower_contested", "range_tiles": 6, "aoe_radius": 0, "duration_rounds": 9999},  # Earth 6: Contested Willpower → imprison a Jigoku/Gaki/Toshigoku or non-human Tainted creature (the gem-imprison object nuance not modeled)
	# --- Water (s36) ---
	# Strike of the Tsunami: Range 25' cone, 3k3 + Knockdown (Earth TN 15)
	"strike_of_the_tsunami": {"kind": "damage", "dr_rolled": 3, "dr_kept": 3,
		"range_tiles": 0, "aoe_radius": 5, "aoe_hits": "enemies", "caster_exempt": true,
		"rider": {"condition": "prone", "save": "earth_flat", "save_tn": 15}},
	# Water coverage extension (2026-06-20): knockdown, attack buff, two go-to-ground hides, move + init buffs.
	"the_swell_of_the_storm": {"kind": "status", "condition": "prone", "save": "strength_contested_water",
		"range_tiles": 5, "aoe_radius": 0, "duration_rounds": 0},  # Water 1: Contested Strength vs Water → Knockdown
	"surging_soul": {"kind": "buff", "target": "ally", "range_tiles": 2, "duration_rounds": 3,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}, {"kind": "spell_attack_kept", "value": 1}]},  # Water 2: +1k1 Attack rolls (no-Center / must-Move downsides not enforced)
	"sanctuary_of_the_waves": {"kind": "buff", "target": "ally", "range_tiles": 10, "duration_rounds": 10,
		"mods": [{"kind": "insubstantial", "value": 1}]},  # Water 3: submerged + fully protected but cut off — untargetable + cannot act (water-body requirement not enforced)
	"the_inner_ocean": {"kind": "buff", "target": "ally", "range_tiles": 10, "duration_rounds": 50,
		"mods": [{"kind": "insubstantial", "value": 1}]},  # Water 3: transformed to water — untargetable + cannot act (Fire-still-harms downside not modeled)
	"wave_borne_speed": {"kind": "buff", "target": "self", "duration_rounds": 2,
		"mods": [{"kind": "move_water_penalty", "value": 2}]},  # Water 2: Water +2 for movement distance (positive = increase)
	# Coverage clean-wins batch 3 (2026-06-20): magical-healing block + move-debuff + free-move buff.
	"disrupt_the_aura": {"kind": "debuff", "target": "enemy", "range_tiles": 10, "duration_rounds": 9999,
		"mods": [{"kind": "no_magic_heal", "value": 1}]},  # Fire 2: target cannot be healed by magical means (spells/items/Techniques fail); mundane Medicine still works (out-of-combat). 24h ≈ skirmish.
	"suitengus_curse": {"kind": "debuff", "target": "enemy", "range_tiles": 4, "duration_rounds": 10,
		"mods": [{"kind": "move_water_penalty", "value": -1}]},  # Water 1: move as though Water 1 Rank lower (the Reflexes -1 trait change deferred)
	"the_rushing_wave": {"kind": "buff", "target": "ally", "range_tiles": 2, "duration_rounds": 1,
		"mods": [{"kind": "free_move_tiles", "value": 1}]},  # Water 1: Free Move up to Water Ring ×10' (= +Water tiles to the free-move budget, read from the mover's own Water at move time)
	"clarity_of_purpose": {"kind": "buff", "target": "ally", "aoe_radius": 2, "duration_rounds": 2,
		"mods": [{"kind": "initiative_score", "value": 5}]},  # Water 1: all allies within 10' +5 Initiative Score
	"rejuvenating_vapors": {"kind": "cleanse", "range_tiles": 1, "cleanse_cap": 1,
		"cleanse_conditions": ["fatigued"], "cleanse_heal": 0},  # Water 2: removes Fatigue from a touched ally (Void-slot restore is out-of-combat)
	"heart_of_the_water_dragon": {"kind": "buff", "target": "ally", "aoe_radius": 5, "duration_rounds": 5,
		"mods": [{"kind": "heal_on_damage", "value": 1}]},  # Water 4: a buffed target regains 1k1 Wounds whenever damaged
	"strike_of_the_flowing_waters": {"kind": "buff", "target": "ally", "range_tiles": 2, "duration_rounds": 1,
		"mods": [{"kind": "armor_bypass", "value": 1}]},  # Water 4: ignore the target's worn-armor Armor TN (+5 vs non-humans); the spell-ML3-effect bypass not modeled; does NOT negate Reduction or Defense/Full-Defense TN
	"suitengus_embrace": {"kind": "status", "condition": "incapacitated", "save": "none",
		"range_tiles": 5, "aoe_radius": 0, "duration_rounds": 3},  # Water 5: lungs fill with seawater — treated as Down (the per-round Stamina recovery + death-on-2-consecutive-fails deferred; 3-round hold PROVISIONAL)
	# --- Void (s37, Ishiken-only) ---
	# Touch the Emptiness: Range 30', single, 1k1 + Dazed (no save)
	"touch_the_emptiness": {"kind": "damage", "dr_rolled": 1, "dr_kept": 1,
		"range_tiles": 6, "aoe_radius": 0,
		"rider": {"condition": "dazed", "save": "none"}},
	# Void Strike: Range 50', single, DR = caster's Void Ring
	"void_strike": {"kind": "damage", "dr_rolled": 0, "dr_kept": 0,
		"range_tiles": 10, "aoe_radius": 0},
	# The Void's Caress (Void 1, Ishiken): negate one Mental/Spiritual Disadvantage on a touched ally
	# (≤5 points) for 1 minute (~10 rounds). Reuses the Banish All Shadows suppression slot.
	"the_voids_caress": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 10,
		"suppress_disadvantage": "mental_spiritual", "suppress_max_points": 5},
	# Void coverage extension (2026-06-20): Void ward + spirit banishment.
	"banish_the_void": {"kind": "ward", "aoe_radius": 4, "duration_rounds": 5,
		"ward_elements": [4], "cast_tn_penalty": 10},  # Void 3: +10 TN to Void spells in the area (VP-cost-doubling + Shadow effects not modeled; ward owner exempt)
	"draw_closed_the_veil": {"kind": "banish_spirit"},  # Void 4: banish a non-native spirit to its home realm (Contested Void vs Willpower for embodied spirits)
	"essence_of_void": {"kind": "status", "condition": "incapacitated", "save": "void_contested",
		"range_tiles": 10, "aoe_radius": 0, "duration_rounds": 9999},  # Void 4: Contested Void → held immobile, unable to act (Concentration = skirmish; the per-round break roll is the deferred nuance)
	# Void VP manipulation (2026-06-20): gain / restore / steal / lock Void Points.
	"drawing_the_void": {"kind": "gain_void"},  # Void 1: caster gains School Rank +1 Void Points (over-cap allowed; the per-round over-cap decay is deferred)
	"fill_the_emptiness": {"kind": "restore_void", "target": "ally", "range_tiles": 1},  # Void 4: restore a touched ally's Void Points to maximum
	"void_release": {"kind": "steal_void", "range_tiles": 5},  # Void 3: Contested Void → steal 1 Void Point from the target (margin/5 extra deferred)
	# Coverage clean-wins batch 4 (2026-06-20): the two instant-kill spells.
	"consumed_by_five_fires": {"kind": "instant_kill", "range_tiles": 20, "reciprocal": true,
		"fire_immune_blocks": true},  # Fire 5: instantly reduce target to Dead; caster suffers the same Wounds unmitigated (often lethal); cannot target Fire-resistant creatures
	"unmake_the_world": {"kind": "instant_kill", "range_tiles": 10,
		"contested": "earth_contested_void"},  # Void 6: Contested Void vs Earth → target ceases to exist (no reciprocal; the non-magical-object auto-kill + nemuranai ramifications not modeled)
	# Coverage clean-wins batch 5 (2026-06-20): forced-stance lock.
	"haze_of_battle": {"kind": "debuff", "target": "enemy", "range_tiles": 2, "duration_rounds": 5,
		"contested": "willpower_contested_caster_fire",
		"mods": [{"kind": "stance_locked", "value": 1}]},  # Fire 3: forced into Full Attack Stance, cannot switch (Contested Willpower; caster adds Fire Ring); out-of-combat Brash+Contrary not modeled
	# Coverage clean-wins batch 6 (2026-06-20): purify zone (heal pure / harm tainted).
	"heavens_tears": {"kind": "purify_zone", "aoe_radius": 6, "duration_rounds": 2,
		"dr_rolled": 1, "dr_kept": 1},  # Water 2: holy rain centered on caster (30' radius, 2 Rounds) — pure souls (no Taint, Honor 4.0+) healed Water Ring/round; Taint/Shadow corruption suffer 1k1/round; "outdoors only" flavour not gated
	# Coverage clean-wins batch 7 (2026-06-20): guided-arrow auto-hit.
	"arrows_flight": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 3,
		"mods": [{"kind": "ranged_auto_hit", "value": 1}]},  # Air 1: the next bow shot (Kyujutsu) auto-hits within 3 Rounds, ignoring Raises (one-shot; +1 arrow per Raise not modeled; passive kata damage still applies)
	# Coverage clean-wins batch 8 (2026-06-20): AoE-ally mobility buffs (reuse batch-3 free-move + the move hook).
	"ebb_and_flow_of_battle": {"kind": "buff", "target": "ally", "aoe_radius": 10, "duration_rounds": 5,
		"mods": [{"kind": "free_move_tiles", "value": 1}]},  # Water 4: chosen allies within 50' make a Free Move of Water Ring ×10' (= +Water tiles; was a Simple Action)
	"master_of_the_rolling_river": {"kind": "buff", "target": "ally", "aoe_radius": 20, "duration_rounds": 5,
		"mods": [{"kind": "move_water_penalty", "value": 1}, {"kind": "spell_damage_rolled", "value": 1}]},  # Water 4: a unit (≤25 allies) within 100' moves as Water 1 Rank higher AND Strength 1 Rank higher (+1 rolled damage die); the Mass Battle general bonus is deferred
	# Coverage clean-wins batch 9 (2026-06-20): action-economy (one-shot bonus-action pools on TurnState).
	# Reactions-Stage timing modeled as "an extra action on the recipient's next turn" (persists until used).
	"spirit_of_the_water": {"kind": "buff", "target": "ally", "range_tiles": 4, "duration_rounds": 1,
		"mods": [{"kind": "granted_simple", "value": 1}]},  # Water 1: +1 NON-attack Simple Action (a Move is the canonical use); checked only in execute_move so it can't be an attack
	"stand_against_the_waves": {"kind": "buff", "target": "ally", "range_tiles": 2, "duration_rounds": 1,
		"mods": [{"kind": "granted_attacks", "value": 1}]},  # Water 2: +1 attack action (Complex-fallback); checked only in the attack functions, not casting — so it cannot grant a second spell
	"hurried_steps": {"kind": "buff", "target": "self", "duration_rounds": 2,
		"mods": [{"kind": "cast_as_simple", "value": 1}]},  # Fire 2: the next Fire ML<=3 cast costs a Simple instead of a Complex (the -4-Rounds casting-time reduction collapses to "Simple-cost" for ML<=3; ML4+ partial reduction not modeled)
	"the_elements_fury": {"kind": "buff", "target": "self", "duration_rounds": 1,
		"mods": [{"kind": "free_casts", "value": "fire_ring"}]},  # Fire 6: cast Fire-Ring Fire ML<=4 spells, each as a Free Action (slots + rolls still required)
	# Coverage clean-wins batch 10 (2026-06-20): modifier-zone subsystem (roll modifiers by zone membership).
	"blessed_wind_of_lady_sun": {"kind": "modifier_zone", "self_centered": true, "aoe_radius": 1,
		"duration_rounds": 9999, "mods": {"attack_roll_penalty": -1}},  # Air 2: hostile actions in the area suffer -1k0 (combat slice; the +1k0 Void/Awareness + the -2k0 Awareness-hostile are out-of-combat). 10 sq ft -> radius-1 bubble PROVISIONAL. Concentration = skirmish.
	"summoning_the_gale": {"kind": "modifier_zone", "range_tiles": 10, "aoe_radius": 6,
		"duration_rounds": 9999, "mods": {"ranged_armor_tn": 15, "ranged_attack_penalty": -3}},  # Air 3: anti-ranged bubble around a target (30' radius / 50' range) — +15 Armor TN vs ranged (shots in) and -3k0 to ranged attack rolls (shots out; the -3 KEPT half not modeled). Concentration = skirmish.
	# Coverage clean-wins batch 11 (2026-06-20): trait→combat-roll buffs/debuffs via EXISTING hooks
	# (Strength → rolled damage dice, Agility → attack-roll dice). NOT the Earth-ring wound refactor.
	"strength_of_the_tsunami": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 3,
		"mods": [{"kind": "spell_damage_rolled", "value": "water_half"}]},  # Water 2: Strength +half Water Ring → +that many rolled damage dice (faithful for the damage slice; Strength-skill rolls + the "cap at 9" not modeled)
	"death_of_flame": {"kind": "debuff", "target": "enemy", "range_tiles": 20, "duration_rounds": 5,
		"contested": "fire_contested", "mods": [{"kind": "spell_attack_rolled", "value": "neg_fire_ring"}]},  # Fire 4: -Fire Ring Agility (its attack-roll slice; the -Fire Intelligence / spell-suppression half is deferred). Per-Round re-resist simplified to one contested-Fire gate at cast.
	# Coverage clean-wins batch 12 (2026-06-20): LOS-blocking fog (anti-ranged area denial).
	"summon_fog": {"kind": "fog_zone", "range_tiles": 20, "aoe_radius": 10, "duration_rounds": 9999},  # Air 3: 50' radius obscuring fog (visibility -> 5 ft) — blocks LOS for ranged attacks crossing it beyond 1 tile; centered on a target tile within 100'. 1-minute ~ skirmish. (Damp/extinguish-small-flames flavour not modeled.)
	"false_realm": {"kind": "false_realm", "radius": 6, "duration_rounds": 9999},  # Air 4: illusory terrain (100' radius) — screens enemy ranged LOS (caster's faction sees through; no substance, movement unaffected)
	# Coverage clean-wins batch 13 (2026-06-20): per-die damage reduction (self defensive ward).
	"armor_of_the_emperor": {"kind": "buff", "target": "self", "duration_rounds": 5,
		"mods": [{"kind": "per_die_reduction", "value": "earth_school_rank"}]},  # Earth 4: each kept damage die against the caster is reduced by the caster's School Rank, floored at 0 (central melee+ranged path; atemi/charge/spell damage not threaded)
	# Coverage clean-wins batch 14 (2026-06-20): illusion dispel (anti-invisibility / clears fog).
	"draw_back_the_shadow": {"kind": "dispel", "range_tiles": 20, "aoe_radius": 6},  # Air 5: within a 30' radius, dispel illusions — clears combatants' invisibility (Gift of Wind / Legion of the Moon) and removes Summon Fog clouds. Auto for the ML<=4 illusions wired; the ML5-6 contest + the broader non-illusion contested dispel are deferred (no creator/mastery on the timed-modifier layer).
	# Coverage clean-wins batch 15 (2026-06-20): conjured terrain (a barrier that blocks move + LOS).
	"wall_of_earth": {"kind": "wall", "pattern": "line", "range_tiles": 20, "wall_length": 6, "duration_rounds": 9999},  # Earth 4: a straight WALL_STONE barrier centered on a target tile, perpendicular to the approach — blocks movement (enemies path around) and LOS through it; restored on expiry.
	"groves_of_stone": {"kind": "stone_ring", "radius_tiles": 3, "duration_rounds": 10},  # Earth 3: a closed WALL_STONE ring (15') around the caster; enemies clamber over via execute_climb; crumbles (restored) on expiry. The clamber-over action now exists, so the old stalemate blocker is gone.
	# Coverage clean-wins batch 16 (2026-06-20): anti-spell ward (per-target casting-roll penalty).
	"the_kamis_will": {"kind": "buff", "target": "ally", "range_tiles": 6, "duration_rounds": 10,
		"mods": [{"kind": "kamis_will", "value": "earth_ring"}]},  # Earth 5: a warded character — all spells (friend or foe) cast AT them suffer -(Earth Ring)k(Earth Ring) to the casting roll. (The +Willpower and -Social-roll halves are out-of-combat, deferred.)
	# Coverage clean-wins batch 17 (2026-06-20): Armor TN buff + attack buff/debuff (striking_the_storm already wired above).
	"air_kamis_blessing": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "armor_tn", "value": "air_ring"}]},  # Air 3: +Air Ring to Armor TN (the combat slice; the +Air-Ring-to-Awareness-rolls half is out-of-combat). 8-hour morning-meditation buff ~ persists the skirmish.
	"wisdom_of_the_kami": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}]},  # Air 4: +1 Rank in all Skills -> +1 rolled attack die (the combat slice; the broad +1-all-skills out-of-combat utility is not modeled). 1-minute ~ 10 Rounds.
	"judgment_of_yomi": {"kind": "debuff", "target": "enemy", "range_tiles": 10, "duration_rounds": 9999,
		"mods": [{"kind": "spell_attack_rolled", "value": "neg_target_social_spiritual_disadv"}]},  # Water 2: the target takes -1k0 to physical Skill checks (attack rolls) per Social/Spiritual Disadvantage they possess (inert if they have none). Concentration ~ skirmish. (The "Honor TN 20 or cannot move closer" repel is deferred — movement gate.)
	# Coverage clean-wins batch 18 (2026-06-20): Void skill-grant self-buff (the last combat-slice spell).
	"moment_of_clarity": {"kind": "buff", "target": "self", "duration_rounds": 2,
		"mods": [{"kind": "spell_attack_rolled", "value": "void_replace_weapon_skill"}]},  # Void 3: temporary Skill Ranks = Void Ring, REPLACING the existing rank (not cumulative). For a weapon skill the net attack-roll gain is max(0, Void Ring - best current weapon skill) — big for a low-skill caster, nil for an already-skilled one. (Models the combat weapon-skill case; the "any skill" generality is out-of-combat.)
	# Ring-change wave (2026-06-20): in-combat Ring deltas threaded through the wound/death chain
	# (Participant-scoped store + synced character read-bridge — the former Pending Redesign).
	"essence_of_earth": {"kind": "ring_change", "target": "self", "ring": Enums.Ring.EARTH, "delta": 1, "duration_rounds": 100},  # Earth 4: target's Earth Ring +1 Rank (Wounds increased correspondingly); on expiry Wounds return to normal — possibly fatal. 10 min ~ 100 Rounds (persists a normal skirmish, cleared at combat end).
	"the_wolfs_mercy": {"kind": "ring_change", "target": "enemy", "ring": Enums.Ring.EARTH, "delta": -1, "taint_delta": -2, "range_tiles": 10, "duration_rounds": 10},  # Earth 3: target's Earth Ring -1 Rank (-2 if Tainted, min 1) — reduced Wound capacity can immediately kill an already-wounded target. (The accompanying -1 Strength is not modeled.)
	"strike_at_the_roots": {"kind": "ring_change", "target": "enemy", "ring": Enums.Ring.EARTH, "set_to": 1, "contested": "earth_contested", "range_tiles": 10, "duration_rounds": 3},  # Earth 5: Contested Earth -> the target's Earth Ring is reduced to 1 for the duration; may immediately kill if already wounded.
	"facing_your_devils": {"kind": "trait_swap", "target": "enemy", "range_tiles": 6, "duration_rounds": 10},  # Air 5: swap the target's highest/lowest Traits for 10 Rounds -> the resulting RING deltas (esp. a dropping Earth = reduced Wound capacity, possibly fatal). Per-Trait roll changes not modeled.
	# Trait-swap roll models (2026-06-21): the combat-roll slice of trait changes (no trait bridge needed).
	"chi_reversal": {"kind": "debuff", "target": "enemy", "range_tiles": 4, "duration_rounds": 9999,
		"mods": [{"kind": "spell_attack_rolled", "value": "chi_reversal_agility"}]},  # Water 5: flip the target's Fire-pair Traits (Agility<->Intelligence) -> the Agility drop lowers attack rolls (combat slice; the Int change + other pair options are out-of-combat). Inert if the swap wouldn't lower Agility.
	"ebbing_strength": {"kind": "buff", "target": "ally", "range_tiles": 4, "duration_rounds": 3,
		"mods": [{"kind": "spell_damage_rolled", "value": "water_school_rank"}]},  # Water 1: transfer up to (Water School Rank) Strength caster->target -> the ally gains +damage (the benefit slice; the caster's Strength loss is not modeled, near-inert for a non-melee caster).
	# Anti-Taint buff (2026-06-21): Strength of the Crow.
	"strength_of_the_crow": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "taint_resist", "value": 5}]},  # Earth 3: +5k5 to rolls resisting NEW Taint. Read at the in-combat Taint-inflict sites (Gagoze gaze contested Willpower; Pekkle Retributive Taint burst Earth roll). Self-buff (the NPC self-buff path; the GDD "target individual" touch-ally variant is a manual PC option). The s56.16-exposure corrupted-Shozai check (a separate system) is not covered.
	# Clone (2026-06-21): Divide the Soul — a second body that acts independently.
	"divide_the_soul": {"kind": "clone"},  # Void 5: the caster exists in two places; the second manifestation acts independently on the caster's side (effectively two turns/Round). If either dies, both die (shared-death wired). Combined-wounds-on-expiry + the clone's own casting are not modeled (the clone is a melee body; spells_known cleared to prevent recursive cloning).
	# Illusory decoy (2026-06-21): Way of Deception — a perfect mirrored duplicate of the caster.
	"way_of_deception": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [{"kind": "decoy_absorb", "value": 1}]},  # Air 1: an illusory duplicate mirrors the caster perfectly; an enemy can't tell which is real, so each attack against the caster has a derived 50% chance (1 real + 1 identical duplicate) to strike the fake (no effect). Concentration ~ skirmish. (Base 1 duplicate; the Raise-added duplicates that further dilute the odds are not modeled.)
	"severed_from_the_stream": {"kind": "debuff", "target": "enemy", "range_tiles": 5, "duration_rounds": 9999,
		"mods": [{"kind": "void_locked", "value": 1}]},  # Void 2: target cannot spend Void Points (the per-spend Contested-Void roll is simplified to a full lock via execute_void_spend; 5 rounds ≈ skirmish)
	# --- Heal spells (s36 Water) ---
	# kind "heal": restores Wounds to an ally (or self) within reach. heal field:
	#   "margin"          = Wounds equal to the cast roll's margin over TN (Path to Inner Peace)
	#   "water_plus_rank" = Water Ring + effective School Rank, one Round (Regrow the Wound)
	#   "full"            = all Wounds healed (Peace of the Kami)
	# range_tiles 1 = Touch (caster adjacent to the ally; self always allowed). Heals a living
	# ally only (an Out-but-alive target can be restored; the dead cannot).
	"path_to_inner_peace": {"kind": "heal", "heal": "margin", "range_tiles": 1},
	"regrow_the_wound":    {"kind": "heal", "heal": "water_plus_rank", "range_tiles": 1},
	"peace_of_the_kami":   {"kind": "heal", "heal": "full", "range_tiles": 1},
	# --- Status / control (s33/s34/s35) — inflict a condition, no save (GDD: automatic) ---
	# kind "status": applies a condition to each affected target (single or AoE). duration_rounds
	# 0 = persistent/roll-recovered via apply_condition; >0 = timed (auto-expires). Optional save.
	"wind_born_slumbers": {"kind": "status", "condition": "fatigued", "save": "none",
		"range_tiles": 10, "aoe_radius": 0, "duration_rounds": 0},  # Air 2: active target Fatigued
	"whispering_flames": {"kind": "status", "condition": "dazed", "save": "none",
		"range_tiles": 10, "aoe_radius": 2, "aoe_hits": "all", "duration_rounds": 0},  # Fire 3: 10' Daze (all gazers; roll-recovered; immunity not modeled)
	"eyes_of_the_phoenix": {"kind": "status", "condition": "blinded", "save": "none",
		"range_tiles": 5, "aoe_radius": 0, "duration_rounds": 0},  # Fire 4: Blind (allies' Fear-3 burst deferred)
	"wooden_prison": {"kind": "status", "condition": "entangled", "save": "none",
		"range_tiles": 10, "aoe_radius": 0, "duration_rounds": 0},  # Earth 3: Entangle (escape via standard entangle layer)
	# --- Cleanse (s36) ---
	# kind "cleanse": free up to Water Rank living allies in range from Fatigued+Dazed + heal Water Rank.
	"typhoons_surge": {"kind": "cleanse", "range_tiles": 10},  # Water 3
	# --- Reposition (s36) ---
	# kind "reposition" (s36 Hands of the Tides): swap the grid positions of up to Water Ring
	# willing allies, 100' (20-tile) radius centered on caster, instantaneous. Faithful effect =
	# swap a willing pair; NPC use = rescue a wounded ally from melee (see _reposition_best_pair).
	"hands_of_the_tides": {"kind": "reposition", "range_tiles": 20},  # Water 5
	# --- Buffs (s34/s35/s36) — persistent stat bonuses via the round-scoped timed-modifier layer ---
	# kind "buff": target "self" (range ignored) or "ally" (Touch/range). Each mod {kind, value};
	# value = int OR a formula ("water_plus_rank"/"earth_plus_rank"). duration_rounds = GDD rounds
	# (minutes × 10 via the ROUNDS_PER_MINUTE convention). Mod kinds map to the combat roll sites:
	# armor_tn, reduction, spell_attack_rolled/_kept, spell_damage_rolled/_kept, initiative_rolled.
	"armor_of_earth": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "reduction", "value": "earth_plus_rank"}]},  # Earth 1: Reduction = Earth + School Rank
	"hands_of_clay": {"kind": "buff", "target": "self", "duration_rounds": 100,
		"mods": [{"kind": "hands_of_clay", "value": 1}]},  # Earth 2: merge with stone — execute_climb auto-succeeds (cliffs/walls), no fall on a down-climb
	"within_the_waves": {"kind": "buff", "target": "self", "duration_rounds": 100,
		"mods": [{"kind": "within_the_waves", "value": 1}]},  # Water 4: air-bubble sphere — the caster cannot drown on deep water (immune to WATER_DEEP / Yuki's Touch / Whirlpool suffocation)
	"cloak_of_the_miya": {"kind": "buff", "target": "self", "duration_rounds": 5,
		"mods": [{"kind": "armor_tn", "value": "water_plus_rank"}]},  # Water 2: Armor TN += Water + School Rank
	# s37 Altering the Course (Void 2 ishiken): a self buff installing the `multi_void_spend`
	# flag; while active, execute_void_spend lifts the once-per-round cap and may spend several
	# Void Points on one roll (+NkN). 1 minute = 10 rounds. Damage rolls excluded (RAW).
	"altering_the_course": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "multi_void_spend", "value": 1}]},
	# s36 Ever-Changing Waves (Water 5): transform into a natural creature — keep Mental Traits,
	# take the higher of own/creature Physical Traits + the creature's natural body. The combat
	# slice = the Physical-trait maxes as roll deltas (Strength->damage, Agility->attack,
	# Reflexes->Armor TN), computed caster-relative vs the s54.1 bear form. 1 hour ~ skirmish.
	"ever_changing_waves": {"kind": "buff", "target": "self", "duration_rounds": 9999,
		"mods": [
			{"kind": "spell_damage_rolled", "value": "transform_strength"},
			{"kind": "spell_attack_rolled", "value": "transform_agility"},
			{"kind": "armor_tn", "value": "transform_armor_tn"},
		]},
	# s33 Mists of Illusion (Air 2): a stationary visual-only phantom (placed via the dedicated
	# execute_cast_mists path, not this dispatch — a tile placement, not a target-effect).
	"mists_of_illusion": {"kind": "mists", "range_tiles": 4},
	"biting_steel": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "spell_damage_rolled", "value": 1}, {"kind": "spell_damage_kept", "value": 1}]},  # Fire 1: DR +1k1
	"burning_kiss_of_steel": {"kind": "buff", "target": "self", "duration_rounds": 50,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}, {"kind": "spell_attack_kept", "value": 1}]},  # Fire 1: melee attack +1k1 (mounted/larger +2k2 deferred)
	"warning_flame": {"kind": "buff", "target": "ally", "range_tiles": 1, "duration_rounds": 10,
		"mods": [{"kind": "initiative_rolled", "value": 1}]},  # Fire 1: +1k0 Initiative (immune-surprise + Reactions +3 deferred)
	# Hooked buffs (effect read in _apply_hit / execute_melee_attack, not a stat total):
	"the_souls_blade": {"kind": "buff", "target": "self", "duration_rounds": 5,
		"mods": [{"kind": "weapon_stun", "value": 1}]},  # Fire 6: weapon auto-Stuns + overcomes Invulnerability
	"fires_of_purity": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "flame_shroud", "value": 1}]},  # Fire 1: melee attacker takes 2k2; the shrouded one's strikes deal +2k2 (ranged bypasses; ally-target deferred)
	"reversal_of_fortunes": {"kind": "buff", "target": "self", "duration_rounds": 3,
		"mods": [{"kind": "reroll", "value": 1}]},  # Water 1: re-roll one missed attack/round (broader re-rolls forward-wired)
}

static func get_combat_effect(spell_id: String) -> Dictionary:
	return SPELL_COMBAT_EFFECTS.get(spell_id, {})


## s37 Altering the Course — the persistent-world / UI "activate" action (the combat layer uses
## the SPELL_COMBAT_EFFECTS buff instead). Ishiken-only; rolls the cast vs TN and consumes a Void
## slot (via resolve_cast). On success the caster's `altering_course_ic_day` is set to the current
## tick, so for the rest of that IC-day window a SkillResolver roll may spend multiple Void Points
## (+NkN) via context["spend_void"]/["void_points"] instead of the normal one-per-roll cap.
## Returns the resolve_cast result dict plus {activated: bool, active_ic_day: int}.
static func activate_altering_the_course(
	character: L5RCharacterData, dice: DiceEngine, ic_day: int
) -> Dictionary:
	if not can_cast(character, "altering_the_course"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var res: Dictionary = resolve_cast(character, "altering_the_course", dice, 0, null, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		character.altering_course_ic_day = ic_day
		res["active_ic_day"] = ic_day
	return res


## s33 Cloak of Night (Air 1) — the cast action (UI or NPC trigger). Cast on an object held by
## `carrier` (default the caster). On a successful cast the carrier's object is magically invisible
## to vision for this IC-day window: a normal Investigation search (SecretSystem.resolve_search_person)
## auto-fails; only magical detection finds it (higher-ML auto, equal-ML Air 1 contested vs the stored
## cast total). Returns the resolve_cast result + {activated, carrier_id}.
static func activate_cloak_of_night(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	carrier: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "cloak_of_night"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var holder: L5RCharacterData = carrier if carrier != null else caster
	var res: Dictionary = resolve_cast(caster, "cloak_of_night", dice, 0, null, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		holder.cloak_of_night_ic_day = ic_day
		holder.cloak_of_night_strength = int(res.get("total", 0))
		res["carrier_id"] = holder.character_id
	return res


## s33 Garbled Tongue (Air 3, Illusion) — 30', 2 conversing persons (one may be the caster). Air kami
## lay a false second layer of speech over a conversation: everyone except the participants hears the
## false version, so eavesdroppers cannot lift the conversation's topics. A shugenja may pierce it by
## winning a Contested School Rank/Air roll against the caster. Stamps the per-tick garble (5-min RAW
## ~ per-tick) on BOTH conversing persons — person_a and person_b (person_b defaults to the caster, so
## the common "caster + ally" case passes only person_a; pass both to garble two OTHER people's chat).
## The pierce TN is the caster's frozen School Rank/Air contest total. Requires person_a.
static func activate_garbled_tongue(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	person_a: L5RCharacterData = null, person_b: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "garbled_tongue"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if person_a == null:
		return {"success": false, "activated": false, "reason": "no_target"}
	var p2: L5RCharacterData = person_b if person_b != null else caster
	var res: Dictionary = resolve_cast(caster, "garbled_tongue", dice, 0, person_a, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		# Freeze the caster's School Rank/Air contest pool as the pierce TN.
		var air: int = get_ring_value(caster, Enums.Ring.AIR)
		var strength: int = dice.roll_and_keep(air + caster.insight_rank, air, true).total
		var protected_ids: Array = []
		for person: L5RCharacterData in [person_a, p2]:
			if person == null:
				continue
			person.garbled_tongue_ic_day = ic_day
			person.garbled_tongue_strength = strength
			if person.character_id not in protected_ids:
				protected_ids.append(person.character_id)
		res["protected_ids"] = protected_ids
		res["strength"] = strength
	return res


## s33 Whispering Wind (Air 2, Divination) — 20', 1 target individual, instantaneous. Air kami judge
## whether the target's last statement was true or false — by SINCERITY, not objective fact (a target
## who believes their words is judged truthful, so unknowingly-spread false_info reads as "true"). The
## sim's only tracked DELIBERATE lie is a fabricated secret (SecretData.fabricated, authored by
## fabricator_id), so the verdict is "lie" when the target is the author of a live fabrication, else
## "true". Concrete counter: for each fabricated secret the caster ALREADY knows that this target
## authored, the secret_id is flagged detected-false on the caster (added to detected_false_secret_ids
## AND recorded as a secret_detected_false knowledge entry) — the caster then drops it from their own
## EXPOSE/blackmail pool (known_secrets injection filters it). Callable cast (future cast UI / a
## deliberate caster), not NPC-auto-fired.
static func activate_whispering_wind(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine, ic_day: int,
	active_secrets: Array = [], current_season: int = -1
) -> Dictionary:
	if not can_cast(caster, "whispering_wind"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if target == null:
		return {"success": false, "activated": false, "reason": "no_target"}
	var res: Dictionary = resolve_cast(caster, "whispering_wind", dice, 0, target, ic_day)
	res["activated"] = res.get("success", false)
	if not res.get("success", false):
		return res
	# The target's "last statement" is a deliberate lie iff they authored a live fabrication.
	var authored: Array = []
	for s: SecretData in active_secrets:
		if s.fabricated and s.fabricator_id == target.character_id:
			authored.append(s)
	res["verdict"] = "lie" if not authored.is_empty() else "true"
	# Concrete counter + record: flag the target's lies the caster already knows.
	var detected: Array = []
	for s: SecretData in authored:
		if caster.character_id in s.known_by_ids and s.secret_id not in caster.detected_false_secret_ids:
			caster.detected_false_secret_ids.append(s.secret_id)
			var entry := KnowledgeEntry.new()
			entry.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
			entry.entry_type = "secret_detected_false"
			entry.data = {
				"secret_id": s.secret_id, "subject_id": s.subject_id,
				"fabricator_id": target.character_id,
			}
			entry.season_acquired = current_season
			caster.knowledge_pool.append(entry)
			detected.append(s.secret_id)
	res["detected_secret_ids"] = detected
	return res


## s37 Drink of Your Essence (Void 2, Ishiken-only) — 30', 1 target, instantaneous. Examines the
## target's pattern within the Void: the caster learns the target's five Ring Ranks (not Traits),
## current Wound penalty, and a one-word summation of present mood. Recorded as a single deduped
## essence_reading KnowledgeEntry on the caster (re-reading the same target replaces the old reading).
## Mood is derived from grounded state (the sim has no mood model): "hostile" when the target regards
## the caster at Rival tier or worse, "confused" when their will is subverted (active sleeper command
## or possession), else "composed". Callable cast (future cast UI / a deliberate caster), not auto-fired.
static func activate_drink_of_your_essence(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine, ic_day: int,
	current_season: int = -1
) -> Dictionary:
	if not can_cast(caster, "drink_of_your_essence"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if target == null:
		return {"success": false, "activated": false, "reason": "no_target"}
	var res: Dictionary = resolve_cast(caster, "drink_of_your_essence", dice, 0, target, ic_day)
	res["activated"] = res.get("success", false)
	if not res.get("success", false):
		return res
	var ring_ranks: Dictionary = {
		"air": get_ring_value(target, Enums.Ring.AIR),
		"earth": get_ring_value(target, Enums.Ring.EARTH),
		"fire": get_ring_value(target, Enums.Ring.FIRE),
		"water": get_ring_value(target, Enums.Ring.WATER),
		"void": get_ring_value(target, Enums.Ring.VOID),
	}
	var wound_penalty: int = CharacterStats.get_wound_penalty(target)
	var mood: String = "composed"
	if int(target.disposition_values.get(caster.character_id, 0)) <= -11:
		mood = "hostile"
	elif not target.active_sleeper_command.is_empty() or not target.possession_affliction.is_empty():
		mood = "confused"
	# Deduped record: replace any prior essence_reading of this target.
	for i: int in range(caster.knowledge_pool.size() - 1, -1, -1):
		var e: KnowledgeEntry = caster.knowledge_pool[i]
		if e.entry_type == "essence_reading" and int(e.data.get("target_id", -1)) == target.character_id:
			caster.knowledge_pool.remove_at(i)
	var entry := KnowledgeEntry.new()
	entry.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
	entry.entry_type = "essence_reading"
	entry.data = {
		"target_id": target.character_id,
		"ring_ranks": ring_ranks,
		"wound_penalty": wound_penalty,
		"mood": mood,
	}
	entry.season_acquired = current_season
	caster.knowledge_pool.append(entry)
	res["ring_ranks"] = ring_ranks
	res["wound_penalty"] = wound_penalty
	res["mood"] = mood
	return res


## s33 Wind of the Moon (Air 6) — 50', 1 target, 1 minute. Advanced telepathy: the caster reads the
## target's surface thoughts AND transmits their own thoughts into the target's mind; the target is
## unaware of the contact and believes the implanted thoughts are their own. Requires the target's
## name + a Contested Air Roll (telepathy reads the TRUE thought, so the read is deception-proof —
## unlike a PROBE, no false_info can deceive it). Two halves:
##   READ — records the target's true standing objective (priority_objective) AND their true
##          disposition toward the caster (disposition_toward) as deduped intelligence on the caster.
##          Guaranteed accurate (the kami read the mind, not the mouth).
##   TRANSMIT — implants one thought: the target's disposition toward the caster warms by
##          WIND_OF_MOON_IMPLANT (the target believes the warmth is their own feeling, so NO
##          manipulation/honor cost fires — it is undetectable suggestion, not overt persuasion).
## Failure on the Contested Air Roll breaks contact (no read, no implant). PROVISIONAL: the +5
## implant magnitude (matches a full successful CHARM, s15.4a) — flagged for owner override.
## Callable via a deliberate PROBE augment (not auto-cast); consumes a spell slot.
const WIND_OF_MOON_IMPLANT: int = 5

static func activate_wind_of_the_moon(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target_objective: Dictionary = {}, current_season: int = -1
) -> Dictionary:
	if not can_cast(caster, "wind_of_the_moon"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if target == null:
		return {"success": false, "activated": false, "reason": "no_target"}
	var res: Dictionary = resolve_cast(caster, "wind_of_the_moon", dice, 0, target, ic_day)
	res["activated"] = res.get("success", false)
	if not res.get("success", false):
		return res
	# Contested Air Roll — telepathy is resisted by the target's will (Air). Failure breaks contact.
	var caster_air: int = get_ring_value(caster, Enums.Ring.AIR)
	var target_air: int = get_ring_value(target, Enums.Ring.AIR)
	var attack: DiceResult = dice.roll_and_keep(caster_air, caster_air, true)
	var defend: DiceResult = dice.roll_and_keep(target_air, target_air, true)
	if attack.total <= defend.total:
		res["contact"] = false
		return res
	res["contact"] = true
	# READ (deception-proof): record the target's true standing objective + true disposition.
	var need_type: String = String(target_objective.get("need_type", ""))
	if not need_type.is_empty():
		var obj_entry := KnowledgeEntry.new()
		obj_entry.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
		obj_entry.entry_type = "priority_objective"
		obj_entry.data = {"target_character_id": target.character_id, "need_type": need_type}
		obj_entry.season_acquired = current_season
		InformationSystem.update_intelligence_knowledge(caster, obj_entry)
	var disp_entry := KnowledgeEntry.new()
	disp_entry.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
	disp_entry.entry_type = "disposition_toward"
	disp_entry.data = {
		"target_character_id": target.character_id,
		"toward_id": caster.character_id,
		"disposition": int(target.disposition_values.get(caster.character_id, 0)),
	}
	disp_entry.season_acquired = current_season
	InformationSystem.update_intelligence_knowledge(caster, disp_entry)
	# TRANSMIT: implant a thought — the target's regard for the caster warms (believed self-generated).
	var cur: int = int(target.disposition_values.get(caster.character_id, 0))
	target.disposition_values[caster.character_id] = clampi(cur + WIND_OF_MOON_IMPLANT, -100, 100)
	res["implanted_disposition"] = WIND_OF_MOON_IMPLANT
	return res


## s36 Sympathetic Energies (Water 1) — Range 25', transfer one existing spell effect from the
## caster to a willing target. A "spell effect" in the world-sim is a day buff (the standard model
## for any sub-IC-day spell); this moves one named day buff off the caster and onto the willing
## target (cleared from the caster, set on the target). PC-callable (the future cast UI picks the
## effect + a willing target); no NPC vehicle — it is a meta-utility with no decision trigger.
## The 3-Raise "between two other willing targets" variant is not modeled (caster-to-target only).
static func activate_sympathetic_energies(
	caster: L5RCharacterData, target: L5RCharacterData, buff_id: String,
	dice: DiceEngine, ic_day: int
) -> Dictionary:
	if not can_cast(caster, "sympathetic_energies"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if target == null or CharacterStats.is_dead(target):
		return {"success": false, "activated": false, "reason": "no_target"}
	if not caster.has_day_buff(buff_id):
		return {"success": false, "activated": false, "reason": "caster_lacks_effect"}
	# Willing target: the caster themselves, or anyone not hostile toward the caster.
	if target.character_id != caster.character_id \
			and target.disposition_values.get(caster.character_id, 0) < 0:
		return {"success": false, "activated": false, "reason": "target_unwilling"}
	var res: Dictionary = resolve_cast(caster, "sympathetic_energies", dice, 0, target, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		caster.clear_day_buff(buff_id)
		target.set_day_buff(buff_id)
		res["transferred_buff"] = buff_id
		res["target_id"] = target.character_id
	return res


## s36 The Path Not Taken (Water 4) — Personal. Select one Ring to weaken and one to strengthen,
## then transfer `count` UNUSED daily spell slots from the weakened Ring to the strengthened one for
## the rest of the IC day (the strengthened Ring can cast `count` more spells of its element). Applied
## via the per-Ring spell_slot_adjustment, reset with the slot counters each day. PC-callable (the cast
## UI picks the Rings + count); no NPC vehicle (a slot-economy utility with no decision trigger).
static func activate_the_path_not_taken(
	caster: L5RCharacterData, weak_ring: int, strong_ring: int, count: int,
	dice: DiceEngine, ic_day: int
) -> Dictionary:
	if not can_cast(caster, "the_path_not_taken"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if weak_ring == strong_ring or count < 1:
		return {"success": false, "activated": false, "reason": "invalid_transfer"}
	# Cast first (consumes a Water slot), then move from the weakened Ring's remaining unused slots.
	var res: Dictionary = resolve_cast(caster, "the_path_not_taken", dice, 0, null, ic_day)
	res["activated"] = res.get("success", false)
	if not res.get("success", false):
		return res
	var unused: int = get_daily_slots(caster, weak_ring) - get_slots_used(caster, weak_ring)
	var moved: int = clampi(count, 0, maxi(0, unused))
	if moved <= 0:
		res["transferred"] = 0
		res["reason"] = "no_unused_slots"
		return res
	caster.spell_slot_adjustment[weak_ring] = int(caster.spell_slot_adjustment.get(weak_ring, 0)) - moved
	caster.spell_slot_adjustment[strong_ring] = int(caster.spell_slot_adjustment.get(strong_ring, 0)) + moved
	res["transferred"] = moved
	res["weak_ring"] = weak_ring
	res["strong_ring"] = strong_ring
	return res


## s33 Voice of the Wind (Air 1) — Touch, 1 target. On a successful cast the target gains the
## spoken-social buff for the IC day (SkillResolver reads voice_of_the_wind_ic_day: +1k0 to
## spoken Social Skill Rolls, +1k1 on a voice Perform Roll). Self-cast when target is null.
## Usable wherever a social roll fires — court on the ASCII map or a UI conversation alike.
static func activate_voice_of_the_wind(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "voice_of_the_wind"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "voice_of_the_wind", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.voice_of_the_wind_ic_day = ic_day
		res["target_id"] = beneficiary.character_id
	return res


## s34 Soul of Stone (Earth 1, Defense) — Touch, 1 target. On a successful cast the target's
## soul is fortified like stone: +3k0 to resist coercive social manipulation, -1k0 to its own
## Awareness social-influence rolls. Day buff ("soul_of_stone"), cleared by the daily orchestrator
## pass (1-hour RAW duration ~ the OOC day). Self-cast when target is null. The resist works
## wherever a manipulation roll resolves — court on the ASCII map or a UI exchange.
static func activate_soul_of_stone(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "soul_of_stone"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "soul_of_stone", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("soul_of_stone")
		res["target_id"] = beneficiary.character_id
	return res


## s33 Touch of Air's Grace (Air 3, Illusion) — Touch, 1 target. On a successful cast the
## target's beauty is enhanced for the IC day: negates Disturbing Countenance (its +5 social
## TN penalty), or — if the target lacks it — grants the Dangerous Beauty effect. Self-cast when
## target is null. The Benten's Curse/Blessing half is inert (those traits are not modelled).
static func activate_touch_of_airs_grace(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "touch_of_airs_grace"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "touch_of_airs_grace", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("touch_of_airs_grace")
		res["target_id"] = beneficiary.character_id
	return res


## s33 Wolf's Proposal (Air 2, Illusion) — Personal/Self (the 2-Raise variant may target an ally
## via `target`). On a successful cast the beneficiary appears more honorable: their Honor Rank
## reads 3 higher for any roll that discerns it (AdvantageSystem.get_perceived_honor). Day buff
## ("wolfs_proposal"), cleared by the daily orchestrator pass (10-minute RAW duration ~ the OOC day).
static func activate_wolfs_proposal(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "wolfs_proposal"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "wolfs_proposal", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("wolfs_proposal")
		res["target_id"] = beneficiary.character_id
	return res


## s36 Wisdom & Clarity (Water 2) — Personal/Self (2-Raise variant may target another), 1 hour ~ the
## IC day. Reading speed doubles + perfect recall of everything read. The faithful sim slice is sharper
## Lore (research/recall): SkillResolver reads the "wisdom_and_clarity" day buff and adds +1k0 to Lore
## skill rolls that tick. Does NOT aid comprehension (ciphers/languages stay indecipherable — cipher
## cracking never routes through Lore). Day buff, cleared by the daily orchestrator pass.
static func activate_wisdom_and_clarity(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "wisdom_and_clarity"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "wisdom_and_clarity", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("wisdom_and_clarity")
		res["target_id"] = beneficiary.character_id
	return res


## s34 Jurojin's Balm (Earth 1) — Touch, 1 target. On a successful cast the beneficiary may
## re-roll a failed Stamina save to resist any poison or toxin with +2k0 for the day (the
## "jurojins_balm" day buff, read by DiseaseSystem.resolve_poison_resist_roll). Self-cast when
## target is null. The "cures drunkenness / prevents intoxication" half is inert (no intoxication
## system). 1-hour RAW duration ~ the OOC day.
static func activate_jurojins_balm(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "jurojins_balm"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "jurojins_balm", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("jurojins_balm")
		res["target_id"] = beneficiary.character_id
	return res


## s34 Jurojin's Curse (Earth 2) — 30', one target creature. A DEBUFF: removes Jurojin's
## protection so the target's Earth reads 3 Ranks lower (min 1) for resisting disease or poison
## (the "jurojins_curse" day buff, consumed by DiseaseSystem's resist saves). The "healing
## injuries" half is inert (healing is not Earth-derived in the sim). Requires an enemy target.
static func activate_jurojins_curse(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine, ic_day: int
) -> Dictionary:
	if not can_cast(caster, "jurojins_curse"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if target == null:
		return {"success": false, "activated": false, "reason": "no_target"}
	var res: Dictionary = resolve_cast(caster, "jurojins_curse", dice, 0, target, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		target.set_day_buff("jurojins_curse")
		res["target_id"] = target.character_id
	return res


## s35 Mental Quickness (Fire 2) — Touch, 1 ITEM (not a person). On a successful cast the item is
## imbued ("mental_quickness_imbued" flag on the item dict) for the day, so whoever's inventory
## currently holds it has Intelligence +3 on Int-based rolls (SkillResolver). The buff follows the
## item: give it away and the new owner benefits. `item` is the target item Dictionary (a live
## reference in some character's `items` array); the spell MUST target an item.
static func activate_mental_quickness(
	caster: L5RCharacterData, item: Dictionary, dice: DiceEngine, ic_day: int
) -> Dictionary:
	if not can_cast(caster, "mental_quickness"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if item.is_empty():
		return {"success": false, "activated": false, "reason": "no_item_target"}
	var res: Dictionary = resolve_cast(caster, "mental_quickness", dice, 0, null, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		item["mental_quickness_imbued"] = true
		res["item_id"] = item.get("item_id", -1)
		# s35 (owner 2026-06-25): the carrier gets +3 Intelligence on their NEXT Int-trait roll this
		# IC day (the "10 minutes" = one roll). Set on the caster (who fires it for themselves);
		# consumed by SkillResolver. Requires ic_day >= 0 (the world-sim / AP-action tick).
		if ic_day >= 0:
			caster.mental_quickness_ic_day = ic_day
	return res


## s36 Power of the Ocean (Water 5, Defense) — Touch, 1 willing target, Duration: Days equal to
## School Rank (+1 day per 3 Raises). A MULTI-DAY sustain ritual (not a sub-day day-buff — it gets
## dedicated expiry fields on the target, swept by DayOrchestrator._process_power_of_the_ocean).
## While active the target: (1) recovers 2 x caster Water Ring Wounds/hour (= /24h = a full daily
## heal, owner ruling) via DayOrchestrator's daily pass; (2) "requires no food/drink/sleep" so it
## COUNTS AS RESTED (owner ruling) and receives the normal rest-gated recovery (Void refresh +
## natural healing, and anything else gated on rest) without sleeping, overriding the rest system's
## flip-to-false for combat/travel; (3) may replenish Void to full as an on-demand Simple Action,
## School-Rank times (power_of_ocean_void_uses, via execute_replenish_void_ocean in tile combat).
## After it expires the target lapses into complete exhaustion (0 AP, no actions) for exactly half the
## duration. Self-cast when target is null (the caster is a willing target). INERT half: "a shugenja
## regains spell slots at sunrise regardless of rest" is already the daily default (every living
## character's slots reset each IC day via ActionPointSystem.reset_daily_ap). Requires ic_day >= 0.
static func activate_power_of_the_ocean(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null, raises: int = 0
) -> Dictionary:
	if not can_cast(caster, "power_of_the_ocean"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if ic_day < 0:
		return {"success": false, "activated": false, "reason": "needs_ic_day"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "power_of_the_ocean", dice, raises, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		# "School Rank" = raw insight (school) rank per owner ruling — no element adjustment. Drives
		# both the duration (+1 day per 3 Raises) and the on-demand Void-replenish budget. The Wounds
		# heal scales off the caster's Water RING (get_ring_value), not School Rank.
		var school_rank: int = caster.insight_rank
		var duration: int = maxi(1, school_rank + int(raises / 3))
		var half: int = int(duration / 2)
		beneficiary.power_of_ocean_until_ic_day = ic_day + duration - 1
		beneficiary.power_of_ocean_aftermath_until_ic_day = beneficiary.power_of_ocean_until_ic_day + half
		beneficiary.power_of_ocean_heal_per_day = 2 * get_ring_value(caster, Enums.Ring.WATER) * 24
		beneficiary.power_of_ocean_void_uses = school_rank
		res["target_id"] = beneficiary.character_id
		res["duration_days"] = duration
		res["aftermath_days"] = half
		res["heal_per_day"] = beneficiary.power_of_ocean_heal_per_day
		res["void_uses"] = school_rank
	return res


## s34 Earth's Touch (Earth 1, Defense) — Touch, 1 target, Duration 1 hour (~ the OOC day, per the
## day-buff convention). Strengthens ONE of the target's Earth Traits (caster's choice — Stamina OR
## Willpower) by +1 for the day WITHOUT raising the Earth Ring. Stored as a trait-tagged day buff
## ("earths_touch_stamina" / "earths_touch_willpower"); SkillResolver adds +1 to that trait at roll
## resolution ONLY (so the Earth Ring = min(Stamina, Willpower) off the stored fields stays untouched,
## per the GDD), and DiseaseSystem adds +1 to Stamina-keyed poison/disease resist rolls when Stamina
## is the choice. Self-cast when target is null. trait_choice must be STAMINA or WILLPOWER.
static func activate_earths_touch(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null, trait_choice: Enums.Trait = Enums.Trait.STAMINA
) -> Dictionary:
	if not can_cast(caster, "earths_touch"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	if trait_choice != Enums.Trait.STAMINA and trait_choice != Enums.Trait.WILLPOWER:
		return {"success": false, "activated": false, "reason": "invalid_trait"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "earths_touch", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		var buff_id: String = "earths_touch_stamina" if trait_choice == Enums.Trait.STAMINA \
			else "earths_touch_willpower"
		beneficiary.set_day_buff(buff_id)
		res["target_id"] = beneficiary.character_id
		res["trait"] = trait_choice
	return res


## s34 Stone's Endurance (Earth 1, Travel) — Self or Touch, 1 target creature, 6 hours. The target is
## considered to have Stamina 1 Rank higher for rolls/effects specifically keying on Stamina (poison
## resistance, drowning duration, etc.) and is immune to Fatigue from lack of rest. The +1-Stamina half
## is LIVE: a per-tick day buff read by SkillResolver on any Stamina-keyed roll — the SAME hook as
## Earth's Touch's Stamina option, and non-stacking with it (the Stamina boost caps at +1 from this
## family, since the GDD gives no stacking rule). The Fatigue-immunity and the expiry-Fatigue downside
## are forward-wiring: the world-sim has no "Fatigue from lack of rest" state to grant immunity to or
## to apply on expiry, and the 6h/24h durations collapse to the per-IC-day buff convention (cleared by
## the daily orchestrator pass). Self-cast when target is null.
static func activate_stones_endurance(
	caster: L5RCharacterData, dice: DiceEngine, ic_day: int,
	target: L5RCharacterData = null
) -> Dictionary:
	if not can_cast(caster, "stones_endurance"):
		return {"success": false, "activated": false, "reason": "cannot_cast"}
	var beneficiary: L5RCharacterData = target if target != null else caster
	var res: Dictionary = resolve_cast(caster, "stones_endurance", dice, 0, beneficiary, ic_day)
	res["activated"] = res.get("success", false)
	if res.get("success", false):
		beneficiary.set_day_buff("stones_endurance")
		res["target_id"] = beneficiary.character_id
	return res


## s33 Cloud the Mind (Air 5) — blasphemous memory tampering (owner-simplified design: no
## day-granular timestamps). On a successful Contested Air (caster) vs Earth (target) roll the
## target's known topics are wiped COMPLETELY; the caster may implant chosen topics — real
## existing IDs and/or pre-fabricated ones the caller created (passed in implant_topic_ids).
## The Air slot is consumed on the attempt; the blasphemous Table 2.3 Honor loss is applied here.
## The detectable-dishonor CrimeRecord + the covert topic are created by the caller's writeback
## (which holds next_case_id / active_topics), matching the KILL_WITNESS pattern.
## Returns {success, contested, caster_total, target_total, wiped_count, implanted, honor_delta}.
static func resolve_cloud_the_mind(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine,
	implant_topic_ids: Array = [],
) -> Dictionary:
	if not can_cast(caster, "cloud_the_mind"):
		return {"success": false, "reason": "cannot_cast"}
	consume_slot(caster, Enums.Ring.AIR)  # Air spell slot used on the attempt
	var c_air: int = get_ring_value(caster, Enums.Ring.AIR)
	var t_earth: int = get_ring_value(target, Enums.Ring.EARTH)
	var c_roll: DiceResult = dice.roll_and_keep(c_air, c_air, true, false)
	var t_roll: DiceResult = dice.roll_and_keep(t_earth, t_earth, true, false)
	if c_roll.total <= t_roll.total:  # ties go to the target (RAW: resistance)
		return {"success": false, "contested": true,
			"caster_total": c_roll.total, "target_total": t_roll.total}
	var wiped: int = target.topic_pool.size()
	target.topic_pool.clear()
	var implanted: int = 0
	for tid: int in implant_topic_ids:
		if tid not in target.topic_pool:
			target.topic_pool.append(tid)
			implanted += 1
	var honor_rank: int = HonorGlorySystem.get_honor_rank(caster)
	var honor_delta: float = CrimeSystem.get_blasphemous_at_act_honor_loss(honor_rank)
	HonorGlorySystem.apply_honor_change(caster, honor_delta)
	return {"success": true, "contested": true,
		"caster_total": c_roll.total, "target_total": t_roll.total,
		"wiped_count": wiped, "implanted": implanted, "honor_delta": honor_delta}


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
	"legacy_of_kaze_no_kami":     {"e": 0, "m": 1, "s": 0},   # spirit-bird message — sender delivers letters instantly (LetterSystem.write_letter)
	"natures_touch":              {"e": 0, "m": 1, "s": 3},
	"tempest_of_air":             {"e": 0, "m": 1, "s": 0},
	"token_of_memory":            {"e": 0, "m": 1, "s": 0},   # visual fake object on the map — wired (execute_token_of_memory)
	"to_seek_the_truth":          {"e": 0, "m": 1, "s": 0},   # clears temporary mental/social penalties — COMBAT_ONLY
	"voice_of_the_wind":          {"e": 0, "m": 1, "s": 0},   # WIRED (court actions): a shugenja deliberately casts it opening a court action; +1k0 to spoken Social rolls that tick
	"way_of_deception":           {"e": 0, "m": 1, "s": 0},
	"yari_of_air":                {"e": 0, "m": 1, "s": 0},
	# ML2
	"bentens_touch":              {"e": 0, "m": 2, "s": 15},
	"blessed_wind_of_lady_sun":   {"e": 0, "m": 2, "s": 0},  # concentration area aura — COMBAT_ONLY
	"call_upon_the_wind":         {"e": 0, "m": 2, "s": 0},
	"elemental_cipher":           {"e": 0, "m": 2, "s": 0},   # WIRED (letter system): a known sender auto-enciphers their letters; an interceptor learns nothing unless a shugenja cracks Spellcraft/Int vs the cast total
	"flight_of_doves":            {"e": 0, "m": 2, "s": 0},   # WIRED (performance): performer/ally caster grants the storyteller Air-ring Free Raises on PUBLIC_PERFORMANCE
	"freedom_of_the_air":         {"e": 0, "m": 2, "s": 14},  # Compels hostile spirits out for Air Ring hours — SPIRIT_BIND
	"garbled_tongue":             {"e": 0, "m": 3, "s": 0},   # WIRED (court actions): shugenja garbles a court exchange; the tick's conversations are opaque to eavesdroppers
	"heart_betrays_eyes":         {"e": 0, "m": 2, "s": 0},   # target perceives unusual as normal; maintains illusion — COMBAT_ONLY
	"hidden_visage":              {"e": 0, "m": 2, "s": 0},
	"the_kamis_whisper":          {"e": 0, "m": 2, "s": 0},   # false-sound distraction — wired in CombatController.cast_kamis_whisper
	"mists_of_illusion":          {"e": 0, "m": 2, "s": 0},
	"quiescence_of_air":          {"e": 0, "m": 2, "s": 0},
	"request_to_hato_no_kami":    {"e": 0, "m": 2, "s": 0},   # WIRED (combat): summoned bird distracts one enemy, -1k0 for a Round
	"secrets_on_the_wind":        {"e": 0, "m": 2, "s": 17},
	"whispering_wind":            {"e": 0, "m": 2, "s": 17},   # WIRED (PROBE writeback): a shugenja who PROBEs a target divines if their last statement was a lie, flags known fabrications
	"wind_born_slumbers":         {"e": 0, "m": 2, "s": 0},
	"wolfs_proposal":             {"e": 0, "m": 2, "s": 0},   # WIRED (court actions): shugenja casts it opening a court action; +3 perceived Honor Rank that day
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
	"touch_of_airs_grace":        {"e": 0, "m": 3, "s": 0},   # WIRED (court actions): shugenja makes self attractive opening a court action (negate Disturbing Countenance / grant Dangerous Beauty)
	"your_hearts_enemy":          {"e": 0, "m": 3, "s": 0},   # manifests Fear 4 illusion attack — COMBAT_ONLY
	# ML4
	"call_the_spirit":            {"e": 0, "m": 4, "s": 5},
	"castle_of_air":              {"e": 0, "m": 4, "s": 0},
	"false_realm":                {"e": 0, "m": 4, "s": 0},   # WIRED (false_realm zone): illusory terrain screens enemy ranged LOS (caster's faction sees through; no substance, movement unaffected)
	"funeral_rites":              {"e": 0, "m": 4, "s": 17},  # speaks with departed spirit for information — INFORMATION_GATHER
	"gift_of_wind":               {"e": 0, "m": 4, "s": 0},
	"howl_of_isora":              {"e": 0, "m": 4, "s": 0},  # one-time damage blast — COMBAT_ONLY
	"know_the_mind":              {"e": 0, "m": 4, "s": 17},
	"look_into_the_soul":         {"e": 0, "m": 4, "s": 17},  # Divination: reveals target's 2 lowest Rings — INFORMATION_GATHER
	"netsuke_of_wind":            {"e": 0, "m": 4, "s": 0},   # conjure a real-profile weapon — wired (SPELL_COMBAT_EFFECTS "conjure_weapon" real_weapon)
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
	"facing_your_devils":         {"e": 0, "m": 5, "s": 0},   # WIRED (combat): trait-swap -> ring-change debuff (Earth drop = wound reduction)
	"legion_of_the_moon":         {"e": 0, "m": 5, "s": 0},
	"slayers_knives":             {"e": 0, "m": 5, "s": 0},
	# ML6
	"rise_air":                   {"e": 0, "m": 6, "s": 0},
	"the_false_legion":           {"e": 0, "m": 6, "s": 0},
	"piercing_the_heavens":       {"e": 0, "m": 6, "s": 0},
	"wind_of_the_moon":           {"e": 0, "m": 6, "s": 0},   # WIRED (PROBE augment): deception-proof telepathic read of true objective+disposition + implants +5 disposition (believed self-generated)
	"the_world_is_truth":         {"e": 0, "m": 6, "s": 0},   # Kolat sleeper install — wired as the CAST_WORLD_IS_TRUTH world-sim ActionID (s54.7/s33), NOT a tile-combat effect (so s:0 is correct)
	"wrath_of_kaze_no_kami":      {"e": 0, "m": 6, "s": 0},   # hurricane storm zone — wired (SPELL_COMBAT_EFFECTS "hurricane")

	# === EARTH (s34) ===
	# ML1
	"armor_of_earth":                {"e": 1, "m": 1, "s": 0},
	"courage_of_the_seven_thunders": {"e": 1, "m": 1, "s": 0},
	"earths_stagnation":             {"e": 1, "m": 1, "s": 0},
	"earths_touch":                  {"e": 1, "m": 1, "s": 0},  # Trait boost 1h — buff, not healing
	"elemental_ward":                {"e": 1, "m": 1, "s": 10},
	"jade_strike":                   {"e": 1, "m": 1, "s": 0},
	"jurojins_balm":                 {"e": 1, "m": 1, "s": 0},  # WIRED (CAST_PROTECTIVE_WARD): disease/poison resist buff
	"minor_binding":                 {"e": 1, "m": 1, "s": 0},
	"soul_of_stone":                 {"e": 1, "m": 1, "s": 0},   # WIRED (CAST_PROTECTIVE_WARD): resist court manipulation buff
	"stones_endurance":              {"e": 1, "m": 1, "s": 0},   # WIRED (CAST_PROTECTIVE_WARD): fatigue resist buff
	"tetsubo_of_earth":              {"e": 1, "m": 1, "s": 0},
	# ML2
	"be_the_mountain":               {"e": 1, "m": 2, "s": 0},
	"earth_becomes_sky":             {"e": 1, "m": 2, "s": 0},
	"embrace_of_kenro_ji_jin":       {"e": 1, "m": 2, "s": 0},
	"force_of_will":                 {"e": 1, "m": 2, "s": 0},
	"grasp_of_earth":                {"e": 1, "m": 2, "s": 0},
	"hands_of_clay":                 {"e": 1, "m": 2, "s": 0},   # WIRED (combat buff): climbs auto-succeed (execute_climb)
	"jurojins_curse":                {"e": 1, "m": 2, "s": 0},
	"rites_of_preservation":         {"e": 1, "m": 2, "s": 12},
	"taming_the_beast":              {"e": 1, "m": 2, "s": 0},   # WIRED (combat): pacify a natural creature (Contested Earth -> FACTION_NEUTRAL)
	"the_mountains_feet":            {"e": 1, "m": 2, "s": 0},   # 1h knockdown resistance stance — COMBAT_ONLY
	"wholeness_of_the_world":        {"e": 1, "m": 2, "s": 0},  # Ring/Trait resistance — buff, not healing
	"whispers_of_the_land":          {"e": 1, "m": 2, "s": 17},
	# ML3
	"bonds_of_ningen_do":            {"e": 1, "m": 3, "s": 14},
	"earth_kamis_blessing":          {"e": 1, "m": 3, "s": 15},
	"earths_protection":             {"e": 1, "m": 3, "s": 0},
	"earthen_wave":                  {"e": 1, "m": 3, "s": 0},
	"groves_of_stone":               {"e": 1, "m": 3, "s": 0},   # WIRED (combat): WALL_STONE ring around caster, climbable, crumbles on expiry
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
	"the_earth_flows":               {"e": 1, "m": 4, "s": 0},   # WIRED (mass battle): a Battle shugenja (company commander) on a side casts it pre-battle for a flat attack bonus (EARTH_FLOWS_ATTACK_BONUS, PROVISIONAL)
	"tomb_of_jade":                  {"e": 1, "m": 4, "s": 2},
	"wall_of_earth":                 {"e": 1, "m": 4, "s": 0},
	# ML5
	"drawing_on_the_mountain":       {"e": 1, "m": 5, "s": 0},  # siege wall-hardening — wired (day_orchestrator storm-assault defense bonus)
	"earthquake":                    {"e": 1, "m": 5, "s": 0},
	"grounding_energy":              {"e": 1, "m": 5, "s": 0},   # WIRED (grounding_energy zone): anti-maho ward — maho combat spells cannot land on warded allies (TN-bump reinterpreted as area immunity; maho is roll-less)
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
	"mental_quickness":              {"e": 2, "m": 2, "s": 0},   # +3 Int (one-shot) on next Int roll — wired (SkillResolver, set by activate_mental_quickness)
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
	"essence_of_fire":               {"e": 2, "m": 4, "s": 0},   # anti-spell duel ward — wired (SPELL_COMBAT_EFFECTS "essence_of_fire")
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
	"curse_of_the_burning_hand":     {"e": 2, "m": 6, "s": 0},   # curse: burns the target's own allies — wired (SPELL_COMBAT_EFFECTS "curse_burning_hand")
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
	"sympathetic_energies":          {"e": 3, "m": 1, "s": 0},   # WIRED (PC-callable): transfer a day-buff spell effect to a willing target  # Transfers a spell effect — not healing
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
	"wisdom_and_clarity":            {"e": 3, "m": 2, "s": 0},   # WIRED (court actions): shugenja casts it opening a court action; +1k0 Lore recall that day
	"yukis_touch":                   {"e": 3, "m": 2, "s": 0},   # freeze-water trap — wired (SPELL_COMBAT_EFFECTS "freeze_water")
	# ML3
	"endless_deluge":                {"e": 3, "m": 3, "s": 16},
	"near_to_ice":                   {"e": 3, "m": 3, "s": 0},
	"regrow_the_wound":              {"e": 3, "m": 3, "s": 1},
	"sanctuary_of_the_waves":        {"e": 3, "m": 3, "s": 0},
	"silent_waters":                 {"e": 3, "m": 3, "s": 0},   # WIRED (execute_silent_waters): hold a 2nd ML<=3 combat spell, auto-fires when the caster is next struck
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
	"the_path_not_taken":            {"e": 3, "m": 4, "s": 0},   # WIRED (PC-callable): transfer unused daily spell slots between Rings for the day   # transfers a spell slot to ally — COMBAT_ONLY
	"within_the_waves":              {"e": 3, "m": 4, "s": 0},   # WIRED (self buff): air-bubble — immune to WATER_DEEP / Yuki's Touch / Whirlpool drowning
	# ML5
	"chi_reversal":                  {"e": 3, "m": 5, "s": 0},
	"ever_changing_waves":           {"e": 3, "m": 5, "s": 0},
	"the_final_bond":                {"e": 3, "m": 5, "s": 17},
	"hands_of_the_tides":            {"e": 3, "m": 5, "s": 0},
	"open_the_waves":                {"e": 3, "m": 5, "s": 11},
	"power_of_the_ocean":            {"e": 3, "m": 5, "s": 0},
	"suitengus_embrace":             {"e": 3, "m": 5, "s": 0},
	"whirlpool":                     {"e": 3, "m": 5, "s": 0},   # WIRED (whirlpool zone): open-water vortex — swimmers in area drown on a failed Athletics(Swimming)/Strength TN 30 each Round
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
	# s36 The Path Not Taken: a daily Ring-slot transfer adjusts the allotment (floored at 0).
	return maxi(0, get_ring_value(character, ring) + int(character.spell_slot_adjustment.get(ring, 0)))


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
		target: L5RCharacterData = null, ic_day: int = -1, extra_tn: int = 0,
		roll_penalty: int = 0, rolled_only_penalty: int = 0) -> Dictionary:
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
	# MAGIC_RESISTANCE (s45): target's advantage adds +3 TN per rank to spells targeting them.
	var magic_resist_tn: int = AdvantageSystem.get_magic_resistance_tn(target) if target != null else 0
	# extra_tn: environmental ward penalty (s34 Earth's Protection / s35 Ward of Thunder), applied
	# by the orchestrator when a hostile spell is cast inside an enemy ward of the matching element.
	var tn: int = get_casting_tn(ml) + (raises * 5) - (wrath_bonus * 5) + magic_resist_tn + extra_tn
	# Creature Magic Resistance (s54.10/s54.12): +TN to spells cast at a spirit/oni, element-gated.
	if target != null and target.spirit_creature != null \
			and target.spirit_creature.spell_tn_bonus > 0 \
			and (target.spirit_creature.spell_tn_bonus_element < 0 \
				or target.spirit_creature.spell_tn_bonus_element == cast_ring):
		tn += target.spirit_creature.spell_tn_bonus
	# MASTER_OF_BLOOD (s44 line 117): all non-maho spells suffer +10 TN for the caster.
	# Every SpellSystem spell is non-maho, so the check is unconditional.
	if MutationSystem.has_power(character, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD):
		tn += 10
	# roll_penalty: −XkX to the casting roll (s34 The Kami's Will — a target's anti-spell ward),
	# applied by the orchestrator when a spell is cast AT a warded character. Floors at 1k1.
	# roll_penalty: −XkX (rolled AND kept), s34 The Kami's Will. rolled_only_penalty: −Nk0 (rolled
	# only), s35 Essence of Fire (a spell cast at a warded duelist loses N rolled dice, same kept).
	var roll_dice: int = maxi(1, ring_val + eff_rank - roll_penalty - rolled_only_penalty)
	var keep_dice: int = maxi(1, ring_val - roll_penalty)
	var wound_pen: int = CharacterStats.get_wound_penalty(character)
	# Slot consumed on attempt regardless of outcome
	consume_slot(character, cast_ring)
	var roll_result: DiceResult = dice.roll_and_keep(roll_dice, keep_dice)
	var total: int = roll_result.total + wound_pen
	var margin: int = total - tn

	# ELEMENTAL_IMBALANCE overflow (s45 lines 535-545): when casting the imbalanced element,
	# caster must roll Willpower (TN 15 + 5 × (rank-1)). On failure the element surges.
	var imbalance_result: Dictionary = {}
	var imb_check: Dictionary = AdvantageSystem.check_elemental_imbalance_trigger(character, cast_ring)
	if imb_check.get("triggered", false):
		var imb_tn: int = imb_check.get("tn", 15)
		var wil_val: int = character.willpower if character.willpower > 0 else 1
		var wil_roll: DiceResult = dice.roll_and_keep(wil_val, wil_val)
		if (wil_roll.total + wound_pen) < imb_tn:
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
## Produces personality_insight KnowledgeEntries. (s33, s37)
const INFORMATION_GATHER_GROUP_A: Array[String] = [
	"know_the_mind",       # Air ML4: reads thoughts
	"look_into_the_soul",  # Air ML4: reads 2 lowest Rings
	"see_through_lies",    # Void ML1, Ishiken: reads Advantage/Disadvantage
	"echoes_in_the_void",  # Void ML3, Ishiken: hear target's thoughts (concentration, 25' range)
]

## Group B: remote location-scrying divination. No co-location required.
## Produces location_intelligence KnowledgeEntries. (s33, s36)
## the_final_bond requires caster to be immediate family or close friend (disposition >= 31)
## of the target; locate-only (spotted_characters = [target_id], not full settlement scan).
const INFORMATION_GATHER_GROUP_B: Array[String] = [
	"boundless_sight",       # Void ML1, Ishiken: see+hear 50-mile range
	"reflective_pool",       # Water ML2: visual 10-mile range
	"dominion_of_suitengu",  # Water ML4: visual 100-mile range, coastal only
	"the_final_bond",        # Water ML5: locate one person (immediate family or close friend)
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
