class_name SpiritualExposureSystem
## s56.16 per-realm Exposure mechanics — being somewhere you do not belong erodes
## you. Pure simulation class (no Node). PC-only (NPCs never use the ASCII map).
## Operates on a per-character exposure-state Dictionary the (deferred) combat
## turn loop owns; this is the resolver, not the turn loop. All values LOCKED in
## s56.16.6a/6d/6e, 7a, 8a-8c, 9a-9b. Covers the four realms with encounter
## designs (Gaki-do, Toshigoku, Sakkaku, Chikushudo); Meido/Yume-do have none.

const _GAKI := Enums.SpiritRealm.GAKI_DO
const _TOSHI := Enums.SpiritRealm.TOSHIGOKU
const _SAKKAKU := Enums.SpiritRealm.SAKKAKU
const _CHIKU := Enums.SpiritRealm.CHIKUSHUDO

## Rounds between periodic exposure checks (s56.16: 10 min ≈ 100 rounds; Chikushudo
## is per-minute ≈ 10 rounds).
const CHECK_INTERVAL_ROUNDS: Dictionary = {
	Enums.SpiritRealm.GAKI_DO: 100,
	Enums.SpiritRealm.TOSHIGOKU: 100,
	Enums.SpiritRealm.SAKKAKU: 100,
	Enums.SpiritRealm.CHIKUSHUDO: 10,
}

## Starting TN of the first periodic check.
const START_TN: Dictionary = {
	Enums.SpiritRealm.GAKI_DO: 10,
	Enums.SpiritRealm.TOSHIGOKU: 15,
	Enums.SpiritRealm.SAKKAKU: 10,
	Enums.SpiritRealm.CHIKUSHUDO: 10,
}

## TN increase per subsequent check.
const TN_STEP: Dictionary = {
	Enums.SpiritRealm.GAKI_DO: 1,
	Enums.SpiritRealm.TOSHIGOKU: 1,
	Enums.SpiritRealm.SAKKAKU: 2,
	Enums.SpiritRealm.CHIKUSHUDO: 1,
}

const CHIKUSHUDO_PACIFY_FAILURES: int = 5    # s56.16.7a
const TOSHIGOKU_DISENGAGE_TN: int = 15       # s56.16.8b (reduced to 2)
const TOSHIGOKU_REGAIN_TN: int = 20          # s56.16.8b (reduced to 1)
const CRYSTAL_BONUS_ROLLED: int = 2          # s56.16.8a/8d crystal +2k0 (Toshigoku)
const BURUBURU_CHANCE: float = 0.25          # s56.16.6e (lowest WP < 2)
const SAKKAKU_PERMANENT_CHANCE: float = 0.25 # s56.16.9a (any failure at TN 20+)
const CORRUPTED_SHOZAI_TAINT_TN: int = 15    # s56.16.6d (per melee hit)


# ── State ─────────────────────────────────────────────────────────────────────

## Fresh per-character exposure state for an overlap of `realm`.
static func new_state(realm: int, base_willpower: int) -> Dictionary:
	return {
		"realm": realm,
		"base_willpower": base_willpower,
		"checks_made": 0,
		"current_tn": START_TN.get(realm, 10),
		"wp_rank_loss": 0,          # Gaki-do / Toshigoku
		"failures": 0,              # Sakkaku / Chikushudo cumulative
		"init_penalty": 0,          # Chikushudo
		"attack_penalty": 0,        # Chikushudo (-1k0 vs spirit animals)
		"pacified": false,          # Chikushudo (5 failures)
		"lowest_wp_seen": base_willpower,  # Gaki-do (Buruburu) / Toshigoku (8c)
		"transformed": false,       # Gaki-do Muzai / Toshigoku WP0 slaughter
		"any_failure_at_tn20plus": false,  # Sakkaku post
	}


## Effective Willpower Rank after erosion (Gaki-do / Toshigoku).
static func effective_willpower(state: Dictionary) -> int:
	return maxi(0, int(state.get("base_willpower", 0)) - int(state.get("wp_rank_loss", 0)))


# ── Periodic check ────────────────────────────────────────────────────────────

## Resolves one periodic exposure check for `character`. extra_tn = creature
## stacking (Gaki-do: Muzai swarm presence +1 each, Gashadokuro Bone Rattle +2).
## has_crystal = Toshigoku crystal protection (+2k0). advance_tn = false for the
## Toshigoku per-combat trigger roll (rolls at the current passive TN without
## advancing the passive progression). Mutates state. Returns {failed, tn, total}.
static func roll_periodic_check(
		character: L5RCharacterData,
		state: Dictionary,
		dice: DiceEngine,
		extra_tn: int = 0,
		has_crystal: bool = false,
		advance_tn: bool = true) -> Dictionary:
	var realm: int = int(state.get("realm", _GAKI))
	var tn: int = int(state.get("current_tn", 10)) + maxi(0, extra_tn)

	var trait_val: int = _check_trait_value(character, realm)
	var bonus_rolled: int = CRYSTAL_BONUS_ROLLED if (realm == _TOSHI and has_crystal) else 0
	var roll: DiceResult = dice.roll_and_keep(trait_val + bonus_rolled, trait_val, true)
	var failed: bool = roll.total < tn

	if failed:
		_apply_failure(state, realm, tn)

	state["checks_made"] = int(state.get("checks_made", 0)) + 1
	if advance_tn:
		state["current_tn"] = int(state.get("current_tn", 10)) + int(TN_STEP.get(realm, 1))

	return {"failed": failed, "tn": tn, "total": roll.total}


## Toshigoku per-combat-encounter trigger: one extra Willpower roll at the current
## passive TN (does not advance the passive progression), s56.16.8a.
static func toshigoku_combat_trigger(
		character: L5RCharacterData,
		state: Dictionary,
		dice: DiceEngine,
		has_crystal: bool = false) -> Dictionary:
	return roll_periodic_check(character, state, dice, 0, has_crystal, false)


## Direct Willpower-Rank loss not from a periodic check (Gaki-do Haraigaki Wail,
## s56.16.6a/6b). Mutates state; may trigger transformation.
static func apply_willpower_loss(state: Dictionary, amount: int) -> void:
	state["wp_rank_loss"] = int(state.get("wp_rank_loss", 0)) + maxi(0, amount)
	var eff: int = effective_willpower(state)
	state["lowest_wp_seen"] = mini(int(state.get("lowest_wp_seen", eff)), eff)
	if eff <= 0:
		state["transformed"] = true


# ── Toshigoku behavioral thresholds (s56.16.8b) ───────────────────────────────

## Social/damage modifier from being reduced BY 2+ Willpower Ranks (s56.16.8b):
## -1k0 Social, +1k0 damage. Returns {social_rolled, damage_rolled} deltas.
static func toshigoku_combat_modifier(state: Dictionary) -> Dictionary:
	if int(state.get("wp_rank_loss", 0)) >= 2:
		return {"social_rolled": -1, "damage_rolled": 1}
	return {"social_rolled": 0, "damage_rolled": 0}

## Reduced TO 2 (or below) → cannot voluntarily retreat without a Willpower roll.
static func toshigoku_must_roll_to_retreat(state: Dictionary) -> bool:
	return effective_willpower(state) <= 2 and int(state.get("base_willpower", 0)) > 2

## Reduced TO 1 → attacks the nearest target indiscriminately (friend or foe).
static func toshigoku_attacks_indiscriminately(state: Dictionary) -> bool:
	return effective_willpower(state) <= 1 and int(state.get("base_willpower", 0)) > 1

## Disengage roll when reduced to 2 (Willpower vs TN 15).
static func toshigoku_disengage_roll(character: L5RCharacterData, dice: DiceEngine) -> bool:
	var wp: int = character.willpower
	return dice.roll_and_keep(wp, wp, true).total >= TOSHIGOKU_DISENGAGE_TN

## Regain-control-this-round roll when reduced to 1 (Willpower vs TN 20).
static func toshigoku_regain_control_roll(character: L5RCharacterData, dice: DiceEngine) -> bool:
	var wp: int = character.willpower
	return dice.roll_and_keep(wp, wp, true).total >= TOSHIGOKU_REGAIN_TN


# ── Chikushudo pacification (s56.16.7a) ───────────────────────────────────────

## Ally snaps a pacified/tempted character out: a successful Contested Willpower
## removes one failure level. Pass the contested result. Mutates state.
static func chikushudo_snap_out(state: Dictionary, contested_success: bool) -> void:
	if not contested_success:
		return
	var f: int = maxi(0, int(state.get("failures", 0)) - 1)
	state["failures"] = f
	state["init_penalty"] = f
	state["attack_penalty"] = f
	state["pacified"] = f >= CHIKUSHUDO_PACIFY_FAILURES


# ── Recovery outside the overlap ──────────────────────────────────────────────

## Applies recovery for `minutes` spent outside the overlap (s56.16.6a/8c/9a/7a).
##  Gaki-do / Toshigoku: +1 Willpower Rank per 10 minutes.
##  Sakkaku: -1 Compulsion failure per hour.
##  Chikushudo: immediate full recovery (all penalties cleared). Mutates state.
static func recover_outside(state: Dictionary, minutes: int) -> void:
	var realm: int = int(state.get("realm", _GAKI))
	match realm:
		_GAKI, _TOSHI:
			var regained: int = minutes / 10
			state["wp_rank_loss"] = maxi(0, int(state.get("wp_rank_loss", 0)) - regained)
		_SAKKAKU:
			var faded: int = minutes / 60
			state["failures"] = maxi(0, int(state.get("failures", 0)) - faded)
		_CHIKU:
			state["failures"] = 0
			state["init_penalty"] = 0
			state["attack_penalty"] = 0
			state["pacified"] = false


# ── Post-encounter consequences ───────────────────────────────────────────────

## Gaki-do Buruburu attachment (s56.16.6e): true if a Buruburu followed the
## character home (25% when lowest Willpower fell below 2 during the overlap).
static func gaki_buruburu_check(state: Dictionary, dice: DiceEngine) -> bool:
	if int(state.get("lowest_wp_seen", 99)) >= 2:
		return false
	return dice.randf() < BURUBURU_CHANCE

## Toshigoku post-encounter consequences (s56.16.8c). Returns
## {disadvantages: Array[String], duration_seasons: int, permanent: bool}.
static func toshigoku_post_consequences(state: Dictionary) -> Dictionary:
	if bool(state.get("transformed", false)):
		# Reached WP 0; if this is being called the character was rescued.
		return {"disadvantages": ["Brash", "Overconfident"], "duration_seasons": -1, "permanent": true}
	var lowest: int = int(state.get("lowest_wp_seen", 99))
	if lowest <= 1:
		return {"disadvantages": ["Brash", "Overconfident"], "duration_seasons": 1, "permanent": false}
	if lowest == 2:
		return {"disadvantages": ["Brash"], "duration_seasons": 1, "permanent": false}
	return {"disadvantages": [], "duration_seasons": 0, "permanent": false}

## Sakkaku post-encounter consequences (s56.16.9a). Returns
## {obtuse_one_season: bool, permanent_disadvantage: String}.
static func sakkaku_post_consequences(state: Dictionary, dice: DiceEngine) -> Dictionary:
	var result: Dictionary = {"obtuse_one_season": false, "permanent_disadvantage": ""}
	if int(state.get("failures", 0)) >= 4:
		result["obtuse_one_season"] = true
	if bool(state.get("any_failure_at_tn20plus", false)) and dice.randf() < SAKKAKU_PERMANENT_CHANCE:
		var pool: Array[String] = ["Compulsion", "Can't Lie", "Obtuse"]
		result["permanent_disadvantage"] = pool[dice.roll_die(pool.size()) - 1]
	return result


# ── Jigoku-corrupted Shozai-gaki (s56.16.6d) ──────────────────────────────────

## Probability a given Shozai-gaki is Jigoku-corrupted, by province PTL (s56.16.6d).
static func corrupted_shozai_chance(ptl: float) -> float:
	if ptl >= 9.0:
		return 0.50
	if ptl >= 6.0:
		return 0.30
	if ptl >= 3.0:
		return 0.15
	return 0.05

## Taint exposure on a melee hit from a Jigoku-corrupted Shozai-gaki (s56.16.6d):
## Earth roll vs TN 15 or gain 1 Point of Taint. Returns true if Taint is gained.
static func corrupted_shozai_taint_check(character: L5RCharacterData, dice: DiceEngine) -> bool:
	var earth: int = SpellSystem.get_ring_value(character, Enums.Ring.EARTH)
	return dice.roll_and_keep(earth, earth, true).total < CORRUPTED_SHOZAI_TAINT_TN


# ── internal ──────────────────────────────────────────────────────────────────

static func _check_trait_value(character: L5RCharacterData, realm: int) -> int:
	# Sakkaku uses the higher of Awareness or Willpower; the rest use Willpower.
	if realm == _SAKKAKU:
		return maxi(character.awareness, character.willpower)
	return character.willpower


static func _apply_failure(state: Dictionary, realm: int, tn: int) -> void:
	match realm:
		_GAKI:
			state["wp_rank_loss"] = int(state.get("wp_rank_loss", 0)) + 1
			var eff_g: int = effective_willpower(state)
			state["lowest_wp_seen"] = mini(int(state.get("lowest_wp_seen", eff_g)), eff_g)
			if eff_g <= 0:
				state["transformed"] = true
		_TOSHI:
			state["wp_rank_loss"] = int(state.get("wp_rank_loss", 0)) + 1
			var eff_t: int = effective_willpower(state)
			state["lowest_wp_seen"] = mini(int(state.get("lowest_wp_seen", eff_t)), eff_t)
			if eff_t <= 0:
				state["transformed"] = true
		_SAKKAKU:
			state["failures"] = int(state.get("failures", 0)) + 1
			if tn >= 20:
				state["any_failure_at_tn20plus"] = true
		_CHIKU:
			var f: int = int(state.get("failures", 0)) + 1
			state["failures"] = f
			state["init_penalty"] = f
			state["attack_penalty"] = f
			if f >= CHIKUSHUDO_PACIFY_FAILURES:
				state["pacified"] = true
