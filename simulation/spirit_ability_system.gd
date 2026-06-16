class_name SpiritAbilitySystem
## s56.16 / s54.10 spirit-creature special abilities — the pure mechanic layer the
## (deferred) ASCII combat loop hooks into. No Node. Keyed on SpiritCreatureData
## tags. All values LOCKED in the s54 stat blocks. This is the reusable prerequisite
## for the live spiritual combat tranche: the orchestrator integration (spawning
## creatures as participants, the turn loop) will call these from its damage,
## defense, attack, and exposure paths.
##
## Scope: the damage-resolution-critical abilities (immunity / vulnerability /
## armor-bypass / regeneration / on-hit drain) and the exposure-feed contributions
## (swarm presence, bone rattle, wail). DEFERRED to the combat-loop tranche (need
## live grid / turn-state): positional abilities — hunger_pull, engulf, fire_trail
## spread, illusion tiles, possession, paralysis_venom, deceptive_weight, phantom_battle
## tile damage, invisibility, shapeshift disguise, mob_frenzy/rally counts.

# Weapon/damage kinds the damage filter distinguishes (attacker-supplied).
const W_MUNDANE: String = "mundane"
const W_JADE: String = "jade"
const W_CRYSTAL: String = "crystal"
const W_OBSIDIAN: String = "obsidian"
const W_MAGIC: String = "magic"
const W_FIRE: String = "fire"
const W_WATER: String = "water"

const WAIL_TN: int = 20            # s54.10 Haraigaki Wail of the Starving
const WAIL_WP_LOSS: int = 1        # -1 Willpower Rank on a failed Wail save
const HUNGER_PULL_RADIUS: int = 4  # s54.10 Fukuregaki Hunger Pull: within 4 tiles
const HUNGER_PULL_TN: int = 15     # Earth roll to resist the pull
const HUNGER_PULL_DIST: int = 1    # tiles dragged toward the creature on a failed resist
const SWARM_PRESENCE_TN: int = 1   # s54.10 Muzai-gaki: +1 Willpower-TN per creature
const BONE_RATTLE_TN: int = 2      # s56.16.6a Gashadokuro: +2 erosion TN
const LIFE_DRAIN_HEAL: int = 5     # s54.10 O-Toyo Destroyer of Life: +5 Wounds per hit
const BLOOD_DRAIN_WOUNDS: int = 12 # s54.2 Shozai-gaki Blood Draining (alt attack)


# ── Defensive damage filter (the make-or-break mechanic) ──────────────────────

## How much of an incoming hit a creature actually takes, by weapon/damage kind.
## Returns {multiplier: float, heals: bool, no_explode: bool}.
##  multiplier 0.0 = immune; 0.5 = halved; 1.0 = normal; 2.0 = double (vulnerability).
##  heals = the hit restores Wounds instead (Kagaki vs fire).
##  no_explode = damage dice do not explode against this creature (Pekkle).
## Precedence: incorporeal / superior-invuln / mundane-invuln gate by kind first,
## then Pekkle half-damage, then Kagaki fire/water. Multiple filters compose by
## taking the most protective (lowest multiplier) — the GDD never stacks two on one
## creature, so order is academic, but lowest-wins is the safe rule.
static func incoming_damage(creature: SpiritCreatureData, weapon_kind: String) -> Dictionary:
	var mult: float = 1.0
	var heals: bool = false
	var no_explode: bool = false

	# Incorporeal (Muzai-gaki): only magic and crystal harm it; physical passes through.
	if creature.has_tag("incorporeal"):
		if weapon_kind == W_MAGIC or weapon_kind == W_CRYSTAL:
			mult = minf(mult, 1.0)
		else:
			mult = 0.0

	# Superior Invulnerability (Mokumokuren): only magic and jade deal Wounds.
	if creature.has_tag("superior_invuln"):
		if weapon_kind == W_MAGIC or weapon_kind == W_JADE:
			mult = minf(mult, 1.0)
		else:
			mult = 0.0

	# Partial Invulnerability (Kitsune-tsuki, Hengeyokai): mundane weapons do nothing;
	# jade, crystal, obsidian, magic all deal normal damage.
	if creature.has_tag("partial_invuln"):
		if weapon_kind == W_MUNDANE:
			mult = 0.0

	# Pekkle: all damage halved, dice do not explode.
	if creature.has_tag("partial_invuln_half_damage"):
		mult = minf(mult, 0.5)
		no_explode = true

	# Kagaki: immune to fire (fire heals it), double damage from water.
	if creature.has_tag("flame_immune") and weapon_kind == W_FIRE:
		mult = 0.0
		heals = true
	if creature.has_tag("water_vulnerable") and weapon_kind == W_WATER:
		mult = maxf(mult, 2.0)

	return {"multiplier": mult, "heals": heals, "no_explode": no_explode}


## Convenience: is this creature wholly immune to the given weapon kind?
static func is_immune(creature: SpiritCreatureData, weapon_kind: String) -> bool:
	var d: Dictionary = incoming_damage(creature, weapon_kind)
	return d["multiplier"] <= 0.0 and not d["heals"]


## Reduction vs NORMAL weapons only (Usai-gaki Swarm: Reduction 10 against normal
## weapons; the creature's base `reduction` field already holds it). Magic/jade/
## crystal/fire bypass it. Returns the reduction to apply for this weapon kind.
static func reduction_for_kind(creature: SpiritCreatureData, weapon_kind: String) -> int:
	if creature.has_tag("swarm") and weapon_kind != W_MUNDANE:
		return 0  # "Reduction 10 against normal weapons" — non-mundane ignores it
	return creature.reduction


# ── Attack-side ───────────────────────────────────────────────────────────────

## True if the creature's attack bypasses the target's Armor TN bonus AND armor
## Reduction (Shozai-gaki Claw "ignores physical armor"; Kitsune-tsuki Spirit
## Strike; Mokumokuren Gaze; Muzai Spectral Touch). s54.10/s54.2.
static func attack_bypasses_armor(creature: SpiritCreatureData) -> bool:
	return creature.has_tag("ignores_armor") \
		or creature.has_tag("spirit_strike") \
		or creature.has_tag("gaze_attack")


## Spiritual damage that cannot be healed by Medicine (Mokumokuren Gaze Attack —
## "spiritual Wounds, cannot be treated with Medicine; magic and natural healing
## cure them normally"). s54.10.
static func deals_unhealable_spiritual_damage(creature: SpiritCreatureData) -> bool:
	return creature.has_tag("gaze_attack")


## Wounds the attacker heals on a successful hit (O-Toyo Destroyer of Life: +5).
## Blood Drain (Shozai-gaki) is an ALT attack mode the combat layer chooses, not a
## passive on-hit heal — see BLOOD_DRAIN_WOUNDS.
static func on_hit_self_heal(creature: SpiritCreatureData) -> int:
	if creature.has_tag("life_drain"):
		return LIFE_DRAIN_HEAL
	return 0


## True if the creature reforms during the encounter unless the overlap is closed
## (Gashadokuro / Ancient General regeneration; all Spirits reform in their realm).
static func has_regeneration(creature: SpiritCreatureData) -> bool:
	return creature.has_tag("regeneration")


## A spirit reduced to its wound cap is not permanently destroyed — it reforms in
## its realm; only closing the overlap stops manifestation (s54.10 universal rule).
static func reforms_on_death(creature: SpiritCreatureData) -> bool:
	return creature.has_tag("spirit")


# ── Exposure-feed contributions (consumed by SpiritualExposureSystem) ─────────

## A creature's contribution to the Willpower-resistance TN of co-located
## characters (s56.16.6a stacking): Muzai swarm presence +1 each, Gashadokuro
## Bone Rattle +2. The combat loop sums this across co-located creatures and
## passes the total as `extra_tn` to SpiritualExposureSystem.roll_periodic_check.
static func willpower_tn_contribution(creature: SpiritCreatureData) -> int:
	var bonus: int = 0
	if creature.has_tag("swarm_presence"):
		bonus += SWARM_PRESENCE_TN
	if creature.has_tag("bone_rattle"):
		bonus += BONE_RATTLE_TN
	return bonus


## Sums willpower_tn_contribution across an array of co-located SpiritCreatureData.
static func total_willpower_tn(creatures: Array) -> int:
	var total: int = 0
	for c in creatures:
		if c is SpiritCreatureData:
			total += willpower_tn_contribution(c)
	return total


## Haraigaki Wail: characters within 5 tiles roll Willpower vs TN 20 (failure costs
## -1 Willpower Rank + the next Simple Action). Returns {} for non-wailers.
## The combat loop rolls the save and, on failure, calls
## SpiritualExposureSystem.apply_willpower_loss(state, wp_loss).
static func wail_effect(creature: SpiritCreatureData) -> Dictionary:
	if not creature.has_tag("wail"):
		return {}
	return {"tn": WAIL_TN, "wp_loss": WAIL_WP_LOSS, "radius_tiles": 5, "lose_next_simple": true}


## Fukuregaki Hunger Pull (s54.10, Passive, always active): every character within
## 4 tiles is dragged 1 tile toward the creature at the start of each round unless
## they pass an Earth roll vs TN 15. Returns {} for non-pullers. The combat loop
## rolls Earth per nearby character and, on failure, slides them one tile closer.
static func hunger_pull_effect(creature: SpiritCreatureData) -> Dictionary:
	if not creature.has_tag("hunger_pull"):
		return {}
	return {"radius_tiles": HUNGER_PULL_RADIUS, "resist_tn": HUNGER_PULL_TN, "pull": HUNGER_PULL_DIST}
