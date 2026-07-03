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
## Years of unnatural life bought with maho (s43 Fierce Blood of the Earth):
## the natural-death roll uses age − life_extension_years as the effective age.
@export var life_extension_years: int = 0
@export var gender: String = ""
@export var orientation: String = "straight"
## s45 CAST_OUT: Brotherhood of Shinsei sect affiliation ("Shintao", "Fortunist", or "").
## Empty for non-monks and non-Brotherhood monks (e.g. Togashi Tattooed Order).
@export var brotherhood_sect: String = ""

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
## Transient — reset to {} / 0 each IC day by ActionPointSystem.reset_daily_ap().
## Not @export: these must not persist across save/load.
var spell_slots_used: Dictionary = {}
var spell_void_bonus_used: int = 0
## s36 The Path Not Taken: per-Ring daily-slot delta (ring -> +/- slots). Added to the Ring's daily
## allotment by SpellSystem.get_daily_slots; reset each IC day with the slot counters above.
var spell_slot_adjustment: Dictionary = {}

# -- Skills --------------------------------------------------------------------
# Dict of { skill_name: String -> rank: int }. Only skills at rank >= 1 present.

@export var skills: Dictionary = {}

# Dict of { skill_name: String -> Array[String] } for emphases.
@export var emphases: Dictionary = {}

# -- Techniques & Special Abilities --------------------------------------------

@export var techniques: Array = []
@export var kiho: Array = []
@export var katas: Array = []
# s38 out-of-combat kiho buffs: kiho_name -> ic_day it was last activated.
# Just-in-time per-tick activation (SkillResolver); an entry == current ic_day
# means the buff is active for that tick. Stale entries are ignored/overwritten.
@export var active_kiho_buffs: Dictionary = {}
# s37 Altering the Course (Void 2, ishiken): the IC day this spell is active for.
# When == the current ic_day, the caster may spend MULTIPLE Void Points on a single
# SkillResolver roll (+NkN) instead of the normal one-per-roll cap. -1 = inactive.
# (1-minute RAW duration modelled per-tick, matching the kiho-buff convention.)
@export var altering_course_ic_day: int = -1
# s35 Mental Quickness (Fire 2): +3 Intelligence on the NEXT Intelligence-trait skill roll this IC
# day (one-shot; the "10 minutes" maps to one roll, owner 2026-06-25). Set on cast, consumed by the
# next Int roll. -1 = inactive.
@export var mental_quickness_ic_day: int = -1
# s33 Cloak of Night (Air 1): a carried/concealed object is magically invisible to vision.
# Active when cloak_of_night_ic_day == the current ic_day (1-hour RAW duration ~ per-tick).
# cloak_of_night_strength = the cast roll total, used as the TN for an equal-ML (Air 1)
# magical-detection contest in resolve_search_person. -1/0 = no cloak.
@export var cloak_of_night_ic_day: int = -1
@export var cloak_of_night_strength: int = 0
# s33 Garbled Tongue (Air 3): the character is a participant in a magically-garbled conversation —
# eavesdroppers hear false speech and cannot lift this conversation's topics unless a shugenja
# pierces it. Active when garbled_tongue_ic_day == the current ic_day (5-min RAW duration ~ per-tick).
# garbled_tongue_strength = the caster's frozen School Rank/Air contest total, the pierce TN an
# eavesdropping shugenja must beat (read in DayOrchestrator._process_eavesdrop_writebacks). -1/0 = none.
@export var garbled_tongue_ic_day: int = -1
@export var garbled_tongue_strength: int = 0
# s33 Whispering Wind (Air 2): secrets this character has personally verified are fabrications (a
# successful Whispering Wind cast on the fabrication's author). Durable detection state (NOT subject
# to knowledge-confidence decay): a flagged secret_id is excluded from this character's known_secrets
# injection, so they never wield a lie they have exposed for EXPOSE_SECRET / blackmail.
@export var detected_false_secret_ids: Array = []
# s33 Voice of the Wind (Air 1): spoken-social buff. Active when == the current ic_day
# (10-minute RAW duration ~ per-tick). Read by SkillResolver: +1k0 to spoken Social
# Skill Rolls and +1k1 on a voice Perform Roll (the granted Voice Advantage). -1 = none.
@export var voice_of_the_wind_ic_day: int = -1
# s33 Piercing the Heavens (Air 6, Phoenix): IC day of the caster's last Fortune communion. The
# spell may be cast at most once per month — this is the monthly guard. -1 = never communed.
@export var piercing_heavens_ic_day: int = -1
# Language barrier (s33 Tenjin's Ear consumer). true = this character speaks a foreign tongue
# (gaijin / Ivory Kingdoms / etc.) not mutually intelligible with Rokugani. Default false (no
# regression): no world-gen population sets it yet — it is owner-pending DATA, not a mechanic.
@export var speaks_foreign: bool = false
# s33 Tenjin's Ear (Air 4, Unicorn): IC day the caster last made foreign speech intelligible. -1 = none.
@export var tenjins_ear_ic_day: int = -1
# Day-long spell buffs (the standard model for any spell whose RAW duration is below the IC-day
# tick — 10 minutes, 1 hour, etc.): a set of active buff IDs that last the rest of the OOC day
# they were cast and are cleared wholesale by the daily orchestrator pass (clear_day_buffs). To
# add one: set_day_buff("<id>") on cast, has_day_buff("<id>") at the read site — no new field or
# clear-line needed. Current IDs: "soul_of_stone" (s34), "touch_of_airs_grace" (s33),
# "wolfs_proposal" (s33), "jurojins_balm"/"jurojins_curse" (s34), "earths_touch_stamina"/
# "earths_touch_willpower" (s34).
@export var active_day_buffs: Dictionary = {}

func set_day_buff(buff_id: String) -> void:
	active_day_buffs[buff_id] = true

func has_day_buff(buff_id: String) -> bool:
	return active_day_buffs.has(buff_id)

func clear_day_buffs() -> void:
	active_day_buffs.clear()

func clear_day_buff(buff_id: String) -> void:
	active_day_buffs.erase(buff_id)

# s36 Power of the Ocean (Water 5): a multi-DAY sustain ritual (unlike the sub-day buffs above, so
# it gets dedicated expiry fields, not active_day_buffs). Managed by DayOrchestrator's daily pass
# (_process_power_of_the_ocean). -1 = inactive. While active (ic_day <= power_of_ocean_until_ic_day)
# the target recovers power_of_ocean_heal_per_day Wounds/day and counts as rested (Void refresh +
# natural healing arrive via the normal rest path — DayOrchestrator._counts_as_rested). When the
# active window ends `until` clears to -1 and the target is exhausted (0 AP — no actions) through
# power_of_ocean_aftermath_until_ic_day (half the duration), after which all four fields clear.
# power_of_ocean_void_uses is the on-demand "replenish Void as a Simple Action, School Rank times"
# reserve, consumed by AsciiMapCombatOrchestrator.execute_replenish_void_ocean (tile combat).
@export var power_of_ocean_until_ic_day: int = -1
@export var power_of_ocean_aftermath_until_ic_day: int = -1
@export var power_of_ocean_heal_per_day: int = 0
@export var power_of_ocean_void_uses: int = 0

# -- Spells (shugenja only) ----------------------------------------------------

@export var affinity_element: Enums.Ring = Enums.Ring.NONE
@export var deficiency_element: Enums.Ring = Enums.Ring.NONE
@export var spells_known: Array[String] = []

# -- Advantages & Disadvantages ------------------------------------------------

@export var advantages: Array[AdvantageData] = []
@export var disadvantages: Array[DisadvantageData] = []

# -- Honor, Glory, Status, Infamy (0.0 to 10.0) -------------------------------

@export var honor: float = 3.5
@export var glory: float = 1.0
@export var status: float = 1.0
@export var infamy: float = 0.0
@export var insight_rank: int = 1

# -- Wounds --------------------------------------------------------------------
# Total wounds taken. Wound levels derived from Earth ring at query time.

@export var wounds_taken: int = 0
## s56.16/s54.10 Mokumokuren Gaze: the portion of wounds_taken that is spiritual and
## cannot be treated with Medicine (magic and natural healing cure them normally).
## Default 0 = inert for everyone. Always <= wounds_taken (clamped on heal).
@export var spiritual_wounds: int = 0
# Senbazuru Healing Free Raises pending consumption (s57.26.17). Cleared after
# the next Medicine/treat_wound roll fires against this character.
@export var pending_healing_fr: int = 0

# -- Shadowlands Taint ---------------------------------------------------------

@export var taint: float = 0.0
@export var mutations: Array[MutationData] = []
@export var shadowlands_powers: Array[ShadowlandsPowerData] = []
## Highest Taint Rank already processed for rank-up mutation/power events.
@export var taint_rank_last_processed: int = 0

# -- Equipment & Outfit --------------------------------------------------------

@export var weapons: Array[WeaponData] = []
# Off-hand weapon name for s40 dual-wield schools (Mirumoto daisho, Yoritomo
# paired kama, Lion katana-and-war-fan). "" = single weapon. Set at world-gen;
# AsciiMapCombatOrchestrator.setup_combat reads it to flag the Participant
# dual_wielding and apply the off-hand / dominant-hand / two-weapon rules.
@export var off_hand_weapon: String = ""
@export var armor_worn: ArmorData = null
@export var armor_tn_bonus: int = 0  # mirrors armor_worn.tn_bonus; kept for fast lookup
@export var armor_reduction: int = 0
@export var outfit: Array = []
# s56.16 spirit-encounter puppet source: set when this character is a SpiritCombatant
# wrapper for a SpiritCreatureData (the live ASCII spiritual encounter). null for
# all real characters. Lets the combat ability/override layer read the creature.
@export var spirit_creature: SpiritCreatureData = null
# Combat-scoped Ring deltas read-bridge ({Enums.Ring: int}) for in-combat ring-changing spells
# (s34 Essence of Earth ring-up, Water ring-downs). The AUTHORITATIVE store is the combat
# Participant (participant-scoped); this is a synced, runtime-only mirror so the static
# CharacterStats wound/death chain can see the boost without threading every call site. NOT
# @export -> never serialized, and rigorously cleared at combat setup/teardown/expiry, so it
# never leaks into the persistent character or the world-sim. Empty outside combat.
var combat_ring_deltas: Dictionary = {}
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
# Otosan Uchi Governor link (s2.3.23): zone_id of the district this character
# governs; "" = not a Governor. Bidirectional with NavigationZoneData.zone_lord_id.
@export var governed_zone_id: String = ""
# IC day this character was appointed to their current position. Drives the
# Sentaku Governor performance review's time-in-office weight (s2.3.23). Set at
# world generation for the initial roster and on APPOINT_TO_POSITION. -1 = never
# appointed / not tracked.
@export var appointed_ic_day: int = -1
# Otosan Uchi access flags (s2.3.23). Standing grants for Imperial residents and
# Tribunal members; otherwise set by the Sentaku access-petition pipeline.
@export var ekohikei_access: bool = false
@export var forbidden_city_access: bool = false
# forbidden_city_access is per-visit: the IC day it auto-clears. -1 = none or a
# standing (permanent) grant that never expires (Imperial residents).
@export var forbidden_city_access_expiry_ic_day: int = -1
# Petition cooldown: petition_type ("ekohikei"/"forbidden_city") → season index of
# the last denial. A resubmission is auto-denied while still in that same season
# (s2.3.23: "resubmit after 1 IC season").
@export var access_petition_denied_season: Dictionary = {}
@export var designated_heir_id: int = -1
@export var disposition_values: Dictionary = {}
@export var historical_modifiers: Dictionary = {}
@export var temporary_modifiers: Dictionary = {}
@export var cohabitation_days: Dictionary = {}
@export var fear_rating: int = 0
## s22.3/s02.4 Fear resistance. immune_to_fear: never affected (s29.4 Matsu's Fury
## "Immune-to-Fear targets" — forward-wired; no granting source yet). The resist
## bonuses are set by Kshatriya Warrior techniques (s29.14): Strength of Indra (R1)
## raises Willpower one Rank vs Fear (willpower_bonus 1); Courage of Shiva (R5) grants
## +1k1 (rolled/kept bonus 1). Read by AsciiMapCombatOrchestrator.apply_fear_checks.
@export var immune_to_fear: bool = false
@export var fear_resist_willpower_bonus: int = 0
@export var fear_resist_rolled_bonus: int = 0
@export var fear_resist_kept_bonus: int = 0
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
## IC days on which this character committed violence outside a duel (s11.3.12).
## Used by ViolenceSystem.count_offenses_in_window() for repeat-offense detection.
@export var violence_offense_days: Array[int] = []

# -- Courtier Framework Fields -------------------------------------------------

@export var self_reroll: Array = []
@export var granted_reroll: Array = []
# s29.15.24: failure_penalty dicts recorded when a granted reroll fires AND the reroll
# also fails (e.g. Ikoma R4 −0.2 Honor to the bard). Drained by a daily orchestrator
# pass that applies each to its target via characters_by_id, then clears.
@export var pending_grant_penalties: Array = []
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

# -- Elemental Imbalance overflow timed states (s45) --------------------------
@export var void_imbalance_penalty_until: int = -1   # IC day; -1 = inactive
@export var water_imbalance_social_penalty: bool = false  # one-shot: -1k0 next social roll
@export var perceived_honor_blocked_until: int = -1  # IC day; -1 = inactive
@export var air_imbalance_social_penalty_until: int = -1  # IC day; -1 = inactive

# -- Soft-Hearted post-kill TN penalty (s45) -----------------------------------
@export var soft_hearted_tn_until: int = -1  # IC day; -1 = inactive; +10 TN all rolls this day

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

# -- Geisha Intelligence System (s57.45) --------------------------------------
## okiya_id (int) → geisha NPC id (int) for the patron's assigned geisha per okiya.
@export var assigned_geisha_ids: Dictionary = {}
## okiya_id (int) → visit count (int) — tracks patron's history at each okiya.
@export var okiya_visit_counts: Dictionary = {}

# -- Poison Tracking -----------------------------------------------------------

@export var active_poisons: Array = []
## Transient combat suppression of one Disadvantage's effects (s38 Banish All
## Shadows). Holds an Enums.Disadvantage int (−1 = none); AdvantageSystem skips this
## Disadvantage in its combat-roll readers while set. Cleared by the orchestrator's
## advance_round at expiry. Not exported — combat-transient state.
var suppressed_disadvantage_type: int = -1
## Transient combat suppression of Shadowlands Taint benefits (s38 Rest, My Brother).
## When true, MutationSystem skips the positive Taint Power/mutation bonuses (not the
## penalties). Cleared by the orchestrator's advance_round at expiry. Not exported.
var taint_benefits_suppressed: bool = false
## Death Touch affliction (s38 kiho, Void 7). Stamped when a caster lands the 3
## consecutive atemi strikes + the post-3rd Void Point. Resolved at the next daily
## tick by DayOrchestrator (ring drain → catatonic → 3 Contested Void → death).
## Keys: caster_id, insight_cap, caster_void. Empty = not afflicted.
@export var death_touch_affliction: Dictionary = {}
## s54.10/s54.2 spirit possession seeded by a tile-combat attempt, resolved in the
## world-sim over days. {kind: "shozai"/"buruburu"/"kitsune_tsuki", possessor_id,
## ic_day_start, expires_ic_day, consecutive_fails, last_shake_day}. Empty = none.
@export var possession_affliction: Dictionary = {}
## s54.5/s54.11 disease seeded by a Byoki/Shikko/plague-zombie hit, draining physical
## Traits over days/weeks until cured. {type:int (DiseaseSystem.Type), source_id,
## last_tick, cures (consecutive Earth saves), onset}. Empty = healthy.
@export var disease_affliction: Dictionary = {}
## s54.11/s54.12 poison/venom (Gakimushi stinger → Strength, komodo/jinmenju → Stamina):
## an immediate Trait drain per hit, restored in the world-sim (sub-day/24h recovery
## collapses to the next daily tick). {trait:String, drained:int}. Empty = unpoisoned.
@export var poison_affliction: Dictionary = {}

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
## True on elevation to a Master seat (s54.7a/h). Hidden.
@export var is_kolat_master: bool = false
## True if this agent carries a Tear of the Oni's Eye — enables TRANSMIT_VIA_TEAR
## (s54.7c/d). All Masters hold a Tear; senior agents may also. Hidden.
@export var holds_tear: bool = false
## Per-Master record dictionaries, koku fields, cover personas, etc. (s54.7h). Hidden.
@export var special_data: Dictionary = {}

# -- Kolat sleeper hidden fields (Section 54.7e/h; installed by conditioning) --
## Spoken phrase that activates the sleeper ("" = not a sleeper).
@export var trigger_phrase: String = ""
## Engine-readable command the sleeper executes on activation ({} = none).
@export var sleeper_command: Dictionary = {}
## 0–100 conditioning stability; -1.0 = not a sleeper. Degrades 5/season untended.
@export var conditioning_stability: float = -1.0
## Populated from sleeper_command when ACTIVATE_SLEEPER fires; {} = dormant.
@export var active_sleeper_command: Dictionary = {}
## IC days since last MAINTAIN_SLEEPER_CONTACT (-1 = not a sleeper).
@export var sleeper_contact_overdue: int = -1
## s33 The World is Truth: a magically-installed sleeper expires on this IC day (the spell's
## 1-month duration, +1 month per 3 Raises). -1 = no expiry (a permanent psychological sleeper,
## or not a sleeper). Cleared with the rest of the sleeper fields when it lapses while dormant.
@export var sleeper_expiry_ic_day: int = -1
## s54.7c CONDUCT_CONDITIONING in-progress accumulation: cumulative session progress (0–100) toward
## installing a permanent psychological sleeper. 0 when not being conditioned or already a sleeper.
@export var conditioning_progress: float = 0.0
## The master currently conditioning this target (-1 = none). A second master's sessions do not
## add to another master's in-progress conditioning.
@export var conditioning_master_id: int = -1

# -- Kolat koku fields (Section 54.7h; Coin/Master use, stored hidden) ---------
## Laundered, untraceable working reserve (Master Coin).
@export var kolat_koku: int = 0
## Collected-but-unlaundered koku (Master Coin).
@export var dirty_koku: int = 0
## Tiger-allocated operational budget for this Master's Sect.
@export var operational_koku: int = 0
## Hidden dual-stance topic positions for conscious Kolat agents (Section 54.7f):
## topic_id → position (−100..+100). Substituted for topic_positions in Phase 5
## scoring when an entry exists. Empty for non-Kolat characters.
@export var kolat_positions: Dictionary = {}

# -- Bloodspeaker Cult (Section 56.14) ----------------------------------------

@export var cult_affiliation: bool = false

# -- Kuroiban / Black Watch (Section 11.3.5) ----------------------------------
## True if this character is a secret member of the Scorpion Kuroiban, the
## covert anti-maho order maintained by the Soshi and Yogo families. Hidden —
## other characters never learn it from observation ("most samurai are not even
## aware of its existence", s11.3.5). Selected at world-gen.
@export var is_kuroiban: bool = false

# -- Hunting (Section 57.38) ---------------------------------------------------

@export var hunt_trophies: Array = []

# -- Animal Companions (Section 57.39) -----------------------------------------

@export var trained_companions: Array = []

# -- Commerce Stigma (Section 57.40) -------------------------------------------

@export var school_paths: Array = []
@export var commerce_stigma_applied_ic_day: int = -1
## s55.27: one CONDUCT_COMMERCE per settlement per character per season. Maps a
## settlement location_id (String) → the absolute-season index of the last commerce
## conducted there. Used by the selection gate + executor hard gate.
@export var commerce_conducted_seasons: Dictionary = {}

# -- Sailing (Section 57.42) ---------------------------------------------------

@export var aboard_ship_id: int = -1
@export var passage_request_count_today: int = 0
@export var assigned_ship_id: int = -1

# Outbound letters written while aboard a ship (s57.43.5): WRITE_LETTER /
# SEND_INVITATION are available AT_SHIP but dispatch is deferred — letters accumulate
# here during the voyage and flush into the pipeline (from the port of arrival) when
# aboard_ship_id clears.
@export var outbound_letter_queue: Array[LetterData] = []

# Shipwreck drift state (s57.43.6): when the ship is wrecked the character is cast
# into an open-ocean drift. drift_day 0 = not adrift; >= 1 = the current drift day
# (a landfall/rescue check + Swimming roll resolve once per IC day). Mantis waters
# raise the day-1 landfall chance.
@export var drift_day: int = 0
@export var drift_in_mantis_waters: bool = false
# s57.43.6 JUMP_OVERBOARD near-shore drift: true when the character went overboard
# within 1 sub-tile of land (coastal). Coastal drift uses the lower swim TN and a
# successful swim reaches shore that day; open-ocean drift (shipwreck / a jump far
# from land) leaves this false. Map-gated: defaults false until water coordinates
# let a caller know the ship is coastal.
@export var drift_near_shore: bool = false

# s55.11 INTERVENE_CAPTAIN: cumulative −1k0 penalty on this captain's subsequent
# intervention rolls this voyage (one per critical failure). Cleared on disembark
# (when the captain's ship next docks). 0 = no penalty.
@export var intervene_crit_penalty: int = 0

# s57.42.7 owner-granted passage (by letter): the named vessel this character has been
# granted passage on and its destination province. When the character is co-located with
# that docked vessel at its port, they board (and the vessel sails toward the destination).
# Cleared on boarding, or if the vessel is destroyed. -1 = no pending grant.
@export var passage_granted_vessel_id: int = -1
@export var passage_granted_destination: int = -1

# -- Tattoo Ability State (Section 57.25.11) -----------------------------------

@export var mantis_tattoo: bool = false
@export var ocean_tattoo: bool = false
@export var ocean_last_used_ooc_day: int = -1
@export var phoenix_last_used_ic_day: int = -1
@export var crane_pool: int = 0
@export var kirin_reroll_available: bool = false
@export var active_tattoo_ability: Enums.TattooAbility = Enums.TattooAbility.NONE
@export var is_bald: bool = false

# -- Topic Detection (Section 57.57) ------------------------------------------
# Updated on: daily conversation participation, letter send, letter receipt.
# Sentinel −1 = never interacted socially.

@export var last_social_ic_day: int = -1

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

# -- Wall-Wide Emergency obligation (s2.4.14 Decision 6) -----------------------
# Set on every Crab lord compelled to respond when a Clan Champion declares a
# Wall-wide emergency. The obligation IC day stamps the declaration (monotonic —
# seasons cycle, so days are used for the one-season window); `contributed` is
# set true when the lord commits troops to the Wall (ASSIGN_GARRISON /
# ORDER_DEPLOY) during the window. A lord still uncontributed one season
# (90 IC days) after the declaration takes the serious/horde-tier honor loss.
@export var wall_emergency_obligation_ic_day: int = -1
@export var wall_emergency_contributed: bool = false

# -- Champion Strategic Evaluation Log (s57.54.4) ------------------------------
# Full scored candidate list from the last Champion evaluation. Not read by any
# game system — debugging and audit only.
@export var strategic_evaluation_log: Array = []

# -- Garden & Bonsai (Section 57.23a) -----------------------------------------
# Zones the character has declined to permit or fill; prevents re-offering the same slot.
# Each entry: {"settlement_id": int, "zone_type": String, "declined_date": int}
@export var declined_garden_zones: Array = []
# Commissions declined by this character as artisan (prevents NPC re-offering same commission).
# Each entry: {"daimyo_id": int, "art_form": String, "declined_date": int, "expires_ic_day": int}
@export var declined_commissions: Array = []
# Active garden/bonsai visitor disposition bonuses received. Prevents duplicate bonuses.
# Each entry: {"garden_id": int, "creator_id": int, "expires_ic_day": int}
@export var active_garden_bonuses: Array = []

# -- Pending Reactive Events ---------------------------------------------------
# Events injected by other systems (FAVOR_REQUESTED, DUEL_CHALLENGE_RECEIVED, etc.)
# Consumed on the next tick by the reactive phase. Also used for offline PC policy.
@export var pending_events: Array = []

# -- PC Integration (Section 60) ----------------------------------------------
@export var is_pc: bool = false
@export var player_id: String = ""
@export var is_logged_in: bool = false
@export var home_settlement_id: int = -1
@export var banked_ap: int = 0
@export var offline_policies: Dictionary = {}
@export var bubble_scene_id: int = -1
@export var bubble_anchor_ic_day: int = -1


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
