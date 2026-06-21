class_name MahoSpellLibrary
## Maho (blood magic) spell catalogue, transcribed from GDD s43.
##
## Data only: each entry records the spell's Mastery Level, primary Ring, and a
## one-line effect summary (the full text lives in s43). The mechanically-relevant
## fields are mastery_level (drives blood cost = 2×ML and Taint = ML−1) and ring.
## Spell *effects* are almost entirely s40/undead/oni combat mechanics and are NOT
## applied yet (owner-authorized scope 2026-06-09: cost/PTL/crime/evidence only).
##
## `pick_cast_spell()` is the selector used by the seasonal Bloodspeaker cast pass:
## the caster takes the highest-Mastery-Level spell whose Ring they can support
## (ring value ≥ ML) and whose self-blood cost (2×ML wounds) they can survive.

const _A: int = Enums.Ring.AIR
const _E: int = Enums.Ring.EARTH
const _F: int = Enums.Ring.FIRE
const _W: int = Enums.Ring.WATER

## spell_id → {name, mastery_level, ring, effect}
const MAHO_LIBRARY: Dictionary = {
	# -- Mastery Level 1 --
	"bleeding":               {"name": "Bleeding",               "mastery_level": 1, "ring": _F, "effect": "1 Wound/round until bandaged (TN 20) or healed"},
	"blood_rite":             {"name": "Blood Rite",             "mastery_level": 1, "ring": _E, "effect": "heal 1k1 + one physical Trait +1 Rank; target gains 1k1 Taint"},
	"blood_and_darkness":     {"name": "Blood and Darkness",     "mastery_level": 1, "ring": _A, "effect": "30' radius blindness, caster excepted"},
	"disrupt_the_limb":       {"name": "Disrupt the Limb",       "mastery_level": 1, "ring": _W, "effect": "+15 TN to one limb's actions; Lame if a leg"},
	"heart_of_the_damned":    {"name": "Heart of the Damned",    "mastery_level": 1, "ring": _E, "effect": "consume a fresh corpse; heal 2k2 + restore a reduced Ring/Trait"},
	"inspire_fear":           {"name": "Inspire Fear",           "mastery_level": 1, "ring": _A, "effect": "target gains a 3-Point Phobia for 1 hour"},
	"legacy_of_the_dark_one": {"name": "Legacy of the Dark One", "mastery_level": 1, "ring": _A, "effect": "drain 1 Void Point, blocked for the duration"},
	"purge_the_weak":         {"name": "Purge the Weak",         "mastery_level": 1, "ring": _E, "effect": "ruin food/water; eaters fall severely ill (-3k0) for 2 weeks"},
	"sinful_dreams":          {"name": "Sinful Dreams",          "mastery_level": 1, "ring": _A, "effect": "Free Raise on Temptation/Intimidation vs target for 24h"},
	"suck_the_marrow":        {"name": "Suck the Marrow",        "mastery_level": 1, "ring": _E, "effect": "target cannot heal naturally/via Medicine for 1 day"},
	"summon_undead_champion": {"name": "Summon Undead Champion", "mastery_level": 1, "ring": _E, "effect": "animate a corpse as an obedient zombie for 1 hour"},
	"symbol_of_blood":        {"name": "Symbol of Blood",        "mastery_level": 1, "ring": _W, "effect": "ward: intruders -2k0 to physical Actions in 30'"},
	"ward_of_divine_peace":   {"name": "Ward of Divine Peace",   "mastery_level": 1, "ring": _A, "effect": "false calm: -1k0 Awareness/Willpower rolls in 50'"},
	"written_in_blood":       {"name": "Written in Blood",       "mastery_level": 1, "ring": _F, "effect": "hidden conditional blood-message, undetectable until triggered"},
	# -- Mastery Level 2 --
	"caress_of_fu_leng":      {"name": "Caress of Fu Leng",      "mastery_level": 2, "ring": _E, "effect": "instantly corrupt/destroy a jade object"},
	"curse_of_the_clan":      {"name": "Curse of the Clan",      "mastery_level": 2, "ring": _A, "effect": "exaggerate a samurai's clan stereotype for 1 month"},
	"curse_of_the_kansen":    {"name": "Curse of the Kansen",    "mastery_level": 2, "ring": _A, "effect": "-1k0 social rolls, -2k0 vs Temptation for 8h"},
	"curse_unblinking_eye":   {"name": "Curse of the Unblinking Eye", "mastery_level": 2, "ring": _A, "effect": "prevent sleep; Fatigue rolls each night"},
	"curse_of_weakness":      {"name": "Curse of Weakness",      "mastery_level": 2, "ring": _W, "effect": "+10 TN all rolls, -10 Armor TN for 10 rounds"},
	"dark_wings":             {"name": "Dark Wings",             "mastery_level": 2, "ring": _W, "effect": "grow bat wings; fly with Swift 3 for 10 minutes"},
	"drain_the_soul":         {"name": "Drain the Soul",         "mastery_level": 2, "ring": _E, "effect": "reduce target's Stamina Rank by 1"},
	"eternal_unrest":         {"name": "Eternal Unrest",         "mastery_level": 2, "ring": _E, "effect": "prepare corpses for instant later recall (1 month)"},
	"gift_of_the_maker":      {"name": "Gift of the Maker",      "mastery_level": 2, "ring": _F, "effect": "grant a Greater Shadowlands Power for 1 hour"},
	"pain":                   {"name": "Pain",                   "mastery_level": 2, "ring": _E, "effect": "target falls Prone, loses next Turn"},
	"puppet_master":          {"name": "Puppet Master",          "mastery_level": 2, "ring": _F, "effect": "control undead creatures for 4 hours"},
	"spreading_the_darkness": {"name": "Spreading the Darkness", "mastery_level": 2, "ring": _E, "effect": "transfer Taint Points from one person to another"},
	# -- Mastery Level 3 --
	"armor_of_obsidian":      {"name": "Armor of Obsidian",      "mastery_level": 3, "ring": _F, "effect": "kansen shield negates a Jade-keyword spell"},
	"dancing_with_demons":    {"name": "Dancing with Demons",    "mastery_level": 3, "ring": _A, "effect": "ritual dance: grant Advantage or inflict Disadvantage"},
	"death_beyond_life":      {"name": "Death Beyond Life",      "mastery_level": 3, "ring": _E, "effect": "if target dies in 24h, raise them at Down + full Taint Rank"},
	"essence_of_undeath":     {"name": "Essence of Undeath",     "mastery_level": 3, "ring": _E, "effect": "bind a kansen into a corpse as a lasting revenant"},
	"hates_heart":            {"name": "Hate's Heart",           "mastery_level": 3, "ring": _A, "effect": "force murderous rage on the target for 3 rounds"},
	"mists_of_fear":          {"name": "Mists of Fear",          "mastery_level": 3, "ring": _A, "effect": "illusion of the target's worst fear (Fear 5)"},
	"summon_oni":             {"name": "Summon Oni",             "mastery_level": 3, "ring": _E, "effect": "summon an oni from Jigoku, name and contest to control"},
	"symbol_of_bloodspeaker": {"name": "Symbol of the Bloodspeaker", "mastery_level": 3, "ring": _A, "effect": "ward: 4k3 green flame to non-cult intruders in 50'"},
	# -- Mastery Level 4 --
	"burning_blood":          {"name": "Burning Blood",          "mastery_level": 4, "ring": _F, "effect": "boil the blood: DR = Fire Ring, Prone, Fatigued"},
	"chains_of_jigoku":       {"name": "Chains of Jigoku",       "mastery_level": 4, "ring": _E, "effect": "iron manacles immobilize the target for 10 minutes"},
	"no_pure_breaths":        {"name": "No Pure Breaths",        "mastery_level": 4, "ring": _A, "effect": "ravage the lungs: DR kept = Air Ring, +10 TN until healed"},
	"stealing_the_soul":      {"name": "Stealing the Soul",      "mastery_level": 4, "ring": _E, "effect": "drain a Trait Rank from 1 mile via a token"},
	"tomb_of_earth":          {"name": "Tomb of Earth",          "mastery_level": 4, "ring": _E, "effect": "immobilize + 2k2/round; petrify on kill"},
	"truth_is_a_scourge":     {"name": "Truth is a Scourge",     "mastery_level": 4, "ring": _A, "effect": "target cannot lie (Willpower TN 30 to conceal)"},
	# -- Mastery Level 5 --
	"blood_armor":            {"name": "Blood Armor",            "mastery_level": 5, "ring": _E, "effect": "caster takes 25% damage, target takes 75%"},
	"fierce_blood_of_earth":  {"name": "Fierce Blood of the Earth", "mastery_level": 5, "ring": _E, "effect": "kill a helpless victim; full heal + regrow + +1 year"},
	"possession":             {"name": "Possession",             "mastery_level": 5, "ring": _A, "effect": "possess a victim's body for 1 day via name + blood"},
	"strength_of_darkness":   {"name": "Strength of Darkness",   "mastery_level": 5, "ring": _F, "effect": "+1 Earth and physical Traits; see through impairments"},
	"touch_of_death":         {"name": "Touch of Death",         "mastery_level": 5, "ring": _E, "effect": "age target 10 years, 7k7 Wounds"},
	# -- Mastery Level 6 --
	"take_the_body":          {"name": "Take the Body",          "mastery_level": 6, "ring": _A, "effect": "permanently leap the caster's soul into another body"},
}


## s43 maho COMBAT effects — the tile-combat slice of maho spells, encoded in the same effect schema
## the AsciiMapCombatOrchestrator uses for s31–37 spells (kind: status/debuff/buff/damage). A maho-user
## enemy in a PC-present skirmish (Bloodspeaker/cult encounter, s56.14) casts these via
## AsciiMapCombatOrchestrator.execute_cast_maho (no cast roll — maho has none — paying a self-blood
## cost + Taint). Tranche 1: the three that reuse the existing effect functions with zero changes.
## (Damage maho [Burning Blood: DR = TARGET's Fire Ring] needs per-target DR; Bleeding needs a per-round
## DoT tick; Tomb of Earth needs a maintained per-round contest — all deferred to follow-up tranches.)
const MAHO_COMBAT_EFFECTS: Dictionary = {
	# Pain (Earth 2): "falls Prone and cannot act on their next Turn" — incapacitated 1 round (skips the
	# turn + flat-foots defense, subsuming Prone). The Willpower TN 20 "cry out" Honor/Glory rider is a
	# world-sim consequence, not modeled in the skirmish.
	"pain": {"kind": "status", "condition": "incapacitated", "range_tiles": 6, "duration_rounds": 1},
	# Curse of Weakness (Water 2): +10 TN to all rolls (≈ all_rolls −10, the project's TN↔roll-total
	# convention) and −10 Armor TN, for 10 rounds.
	"curse_of_weakness": {"kind": "debuff", "range_tiles": 10, "duration_rounds": 10,
		"mods": [{"kind": "all_rolls", "value": -10}, {"kind": "armor_tn", "value": -10}]},
	# Strength of Darkness (Fire 5): +1 Rank to Earth + the three physical Traits (the combat slice =
	# +1k1 attack via Agility, +1 rolled damage die via Strength), 10 rounds. (The +1 Earth wound-capacity
	# boost and "see through impairments" are not modeled — the attack/damage buff captures the combat value.)
	"strength_of_darkness": {"kind": "buff", "target": "self", "duration_rounds": 10,
		"mods": [{"kind": "spell_attack_rolled", "value": 1}, {"kind": "spell_damage_rolled", "value": 1}]},
	# Burning Blood (Fire 4): boil the blood — DR equal to the TARGET's Fire Ring (per-target, via the
	# damage path's dr_target_ring), then a Willpower TN 20 save or fall Prone. (The secondary "Fatigued"
	# is deferred — the rider applies one condition; the damage + Prone is the core combat effect.)
	"burning_blood": {"kind": "damage", "range_tiles": 10, "dr_target_ring": _F,
		"rider": {"condition": "prone", "save": "willpower_flat", "save_tn": 20}},
	# Bleeding (Fire 1): a malignant kansen reopens an existing wound — 1 Wound/Round at the start of the
	# victim's Turn (ticked in advance_round), indefinitely until bandaged (a future out-of-combat Medicine
	# action) or healed. Requires the target already injured (1+ Wound). Stacks if recast.
	"bleeding": {"kind": "bleed", "range_tiles": 10, "wounds_per_round": 1},
	# Blood and Darkness (Air 1): 30' radius blindness (6 tiles), caster excepted — the AoE gather always
	# excludes the caster. Blinded for 10 rounds.
	"blood_and_darkness": {"kind": "status", "condition": "blinded", "range_tiles": 0, "aoe_radius": 6,
		"aoe_hits": "all", "duration_rounds": 10},
	# Chains of Jigoku (Earth 4): iron manacles immobilize the target — incapacitated for the skirmish
	# (10 minutes ≈ skirmish). Real manacles, so NOT Shadowlands-gated (unlike the s34 elemental bindings).
	"chains_of_jigoku": {"kind": "status", "condition": "incapacitated", "range_tiles": 10,
		"duration_rounds": 9999},
	# Touch of Death (Earth 5): the combat slice is 7k7 Wounds (melee touch). The +10-year aging is the
	# world-sim slice (already wired in the seasonal maho cast), not modeled in the skirmish.
	"touch_of_death": {"kind": "damage", "range_tiles": 1, "dr_rolled": 7, "dr_kept": 7},
	# Inspire Fear (Air 1): a 3-Point Phobia — the target is Afraid (−1k0 to all rolls) for the skirmish,
	# persisting via the spell_afraid modifier. No save (a curse, not an illusion to see through).
	"inspire_fear": {"kind": "fear", "range_tiles": 10, "duration_rounds": 9999},
	# Mists of Fear (Air 3): an illusion of the target's worst fear (Fear 5) — Afraid, resisted by a
	# Willpower TN 30 save (Fear 5 = 5 + 5×5, s22.3).
	"mists_of_fear": {"kind": "fear", "save": "willpower_flat", "save_tn": 30, "range_tiles": 12,
		"duration_rounds": 9999},
}


## Returns the tile-combat effect schema for a maho spell_id, or {} if the spell has no wired combat effect.
static func get_combat_effect(spell_id: String) -> Dictionary:
	return MAHO_COMBAT_EFFECTS.get(spell_id, {})

static func get_spell(spell_id: String) -> Dictionary:
	if not MAHO_LIBRARY.has(spell_id):
		return {}
	var s: Dictionary = (MAHO_LIBRARY[spell_id] as Dictionary).duplicate()
	s["spell_id"] = spell_id
	return s


## True if `caster` can cast a specific spell right now: their Ring supports the
## spell's Mastery Level (ring value ≥ ML) and they survive the self-blood cost
## (2×ML wounds). Used to test one named spell — e.g. the seasonal preference for
## Spreading the Darkness — rather than the highest-ML auto-selection.
static func can_support_spell(caster: L5RCharacterData, spell_id: String) -> bool:
	if caster == null:
		return false
	var s: Dictionary = get_spell(spell_id)
	if s.is_empty():
		return false
	var ml: int = int(s["mastery_level"])
	var remaining: int = CharacterStats.get_total_wound_capacity(caster) - caster.wounds_taken
	if 2 * ml > remaining:
		return false
	return SpellSystem.get_ring_value(caster, int(s["ring"])) >= ml


## True if `caster`'s Ring supports the spell's Mastery Level (ring value ≥ ML),
## ignoring the self-blood survivability check — for spells whose blood/life cost
## is paid by a consumed victim, not the caster (s43 Fierce Blood of the Earth).
static func supports_spell_ring(caster: L5RCharacterData, spell_id: String) -> bool:
	if caster == null:
		return false
	var s: Dictionary = get_spell(spell_id)
	if s.is_empty():
		return false
	return SpellSystem.get_ring_value(caster, int(s["ring"])) >= int(s["mastery_level"])


## All spell ids at a given Mastery Level, in a stable (sorted) order.
static func spell_ids_by_ml(mastery_level: int) -> Array:
	var ids: Array = []
	for sid: String in MAHO_LIBRARY:
		if int(MAHO_LIBRARY[sid]["mastery_level"]) == mastery_level:
			ids.append(sid)
	ids.sort()
	return ids


## Selects the maho spell a cult caster casts on themselves (self-blood model,
## GDD s43: "the caster ... must spill blood"). Returns the highest-Mastery-Level
## spell whose Ring the caster supports (ring value ≥ ML) and whose blood cost
## (2×ML wounds) the caster survives (wounds_taken + 2×ML ≤ total capacity).
## Among spells at the chosen ML, picks the one in the caster's strongest such
## Ring, breaking ties by sorted spell_id. Returns {} if the caster can cast none.
## Generic fallback selector for the seasonal Bloodspeaker cast (victim-blood
## model, owner-authorized 2026-06-10): the cell casts the LOWEST Mastery-Level
## spell its Ring supports — ticking the province (PTL +1, flat) while minimising
## the caster's self-Taint (ML − 1 per cast). The 2×ML blood cost is paid by a
## sacrificed nameless victim, so the caster's own survivability no longer bounds
## the choice. Returns {} only when no spell's Ring is supported at all.
static func pick_cast_spell(caster: L5RCharacterData) -> Dictionary:
	if caster == null:
		return {}
	for ml: int in range(1, 7):  # lowest ML first
		var best_id: String = ""
		var best_ring_val: int = -1
		for sid: String in spell_ids_by_ml(ml):
			var ring: int = int(MAHO_LIBRARY[sid]["ring"])
			var rv: int = SpellSystem.get_ring_value(caster, ring)
			if rv < ml:
				continue  # ring not strong enough to support this ML
			if rv > best_ring_val:
				best_ring_val = rv
				best_id = sid
		if best_id != "":
			return get_spell(best_id)
	return {}
