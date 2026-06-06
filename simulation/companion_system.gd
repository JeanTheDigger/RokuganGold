class_name CompanionSystem
## Allied NPC companion logic for the ASCII tactical map (GDD s57.46, locked
## s57.46a). Pure simulation class — no Node inheritance. Covers slots, the
## command interface, the AI priority stack, morale, noise contribution, doshin
## rules, and death consequences. Live grid rendering, command-menu input, A*
## execution, and turn-loop integration live in the UI/orchestrator layer.

# Hard cap: more than 6 companions becomes a management game → use the mass
# battle grid (s11.7) instead. (s57.46.2)
const MAX_SLOTS: int = 6

# SHAKEN at half the break threshold; BROKEN at the threshold (s57.46.10).
const SHAKEN_FRACTION_OF_THRESHOLD: float = 0.5
const SHAKEN_COMBAT_PENALTY: int = -5

# Doshin teamwork: +5 grapple/restrain at 2+ members (s57.46.3).
const TEAMWORK_GRAPPLE_BONUS: int = 5
# Doshin samurai-avoidance GUARD EXIT penalty (s57.46.11).
const SAMURAI_GUARD_PENALTY: int = -10

# Morale break thresholds (fraction of starting companions lost). -1 = never
# breaks. Yoriki and named allies are computed (school / Yu). (s57.46.10)
const MORALE_THRESHOLDS: Dictionary = {
	CompanionData.CompanionType.VILLAGE_DOSHIN: 0.30,
	CompanionData.CompanionType.CITY_DOSHIN_TEAM: 0.40,
	CompanionData.CompanionType.DOSHIN_HEADMAN: 0.50,
	CompanionData.CompanionType.YOJIMBO: -1.0,
}

# Per-type base noise contribution; doshin bake stealth into their type (s57.46.13).
const DOSHIN_NOISE: Dictionary = {
	CompanionData.CompanionType.VILLAGE_DOSHIN: 1.0,
	CompanionData.CompanionType.CITY_DOSHIN_TEAM: 0.5,
	CompanionData.CompanionType.DOSHIN_HEADMAN: 0.75,
}

const _DOSHIN_TYPES: Array = [
	CompanionData.CompanionType.VILLAGE_DOSHIN,
	CompanionData.CompanionType.CITY_DOSHIN_TEAM,
	CompanionData.CompanionType.DOSHIN_HEADMAN,
]


# === SLOTS (s57.46.2) ========================================================

static func is_doshin(companion: CompanionData) -> bool:
	return companion.type in _DOSHIN_TYPES


## True if another companion can be added (hard cap MAX_SLOTS).
static func can_add_companion(roster: Array) -> bool:
	return roster.size() < MAX_SLOTS


# === COMMANDS (s57.46.5–8) ===================================================

## Commands available to a companion type: universal four + type-specific.
static func available_commands(type: CompanionData.CompanionType) -> Array:
	var cmds: Array = [
		CompanionData.Command.FOLLOW,
		CompanionData.Command.HOLD,
		CompanionData.Command.MOVE_TO,
		CompanionData.Command.RETREAT,
	]
	if type in _DOSHIN_TYPES:
		cmds.append_array([
			CompanionData.Command.GUARD_EXIT,
			CompanionData.Command.IDENTIFY,
			CompanionData.Command.SEARCH_AREA,
		])
	elif type == CompanionData.CompanionType.YOJIMBO:
		cmds.append(CompanionData.Command.PROTECT)
	elif type == CompanionData.CompanionType.YORIKI:
		cmds.append(CompanionData.Command.INVESTIGATE)
	return cmds


## True if `command` may be issued to `companion` right now. A BROKEN companion
## accepts no new commands; a SHAKEN companion may only be told to RETREAT
## (a proactive withdrawal). (s57.46.4 / s57.46.5 RETREAT)
static func can_assign_command(companion: CompanionData, command: int) -> bool:
	if companion.morale == CompanionData.Morale.BROKEN:
		return false
	if companion.morale == CompanionData.Morale.SHAKEN:
		return command == CompanionData.Command.RETREAT
	return command in available_commands(companion.type)


## Assign a command. Returns true on success. command_target_tile / _id are the
## targeting payload (MOVE_TO/GUARD_EXIT use the tile; PROTECT/IDENTIFY use the id).
static func assign_command(
	companion: CompanionData,
	command: int,
	target_tile: Vector2i = Vector2i(-1, -1),
	target_id: int = -1,
) -> bool:
	if not can_assign_command(companion, command):
		return false
	companion.command = command
	companion.command_target_tile = target_tile
	companion.command_target_id = target_id
	return true


# === AI PRIORITY STACK (s57.46.9) ============================================

## The command the companion will execute this round, per the four-level stack:
## SURVIVAL (BROKEN → RETREAT/FLEE) > PLAYER_COMMAND > DEFAULT (FOLLOW). REACT is
## resolved in combat, not here, and does not change the standing command.
static func decide_action(companion: CompanionData) -> CompanionData.Command:
	if companion.morale == CompanionData.Morale.BROKEN:
		return CompanionData.Command.RETREAT
	return companion.command


# === MORALE (s57.46.10) ======================================================

## Break threshold (fraction of starting companions lost) for this companion.
## -1.0 = never breaks (yojimbo). Yoriki and named allies are computed.
static func morale_threshold(companion: CompanionData) -> float:
	if MORALE_THRESHOLDS.has(companion.type):
		return MORALE_THRESHOLDS[companion.type]
	match companion.type:
		CompanionData.CompanionType.YORIKI:
			# Bushi-school yoriki use Yu weighting (high 50% / low 30%);
			# non-bushi yoriki break at 35%.
			if companion.is_bushi_school:
				return 0.50 if companion.yu_rank >= 7 else 0.30
			return 0.35
		CompanionData.CompanionType.NAMED_ALLY:
			# Personality-driven by Yu (s19): 7+ →50%, 4–6 →35%, 1–3 →20%.
			if companion.yu_rank >= 7:
				return 0.50
			if companion.yu_rank >= 4:
				return 0.35
			return 0.20
	return 0.35


## Recompute morale from the allied-casualty fraction (companions killed/broken
## ÷ companions who started). Updates and returns companion.morale. A companion
## that never breaks (threshold < 0) stays STEADY. Morale does not un-break.
static func update_morale(companion: CompanionData, casualty_fraction: float) -> CompanionData.Morale:
	if companion.morale == CompanionData.Morale.BROKEN:
		return CompanionData.Morale.BROKEN
	var threshold: float = morale_threshold(companion)
	if threshold < 0.0:
		companion.morale = CompanionData.Morale.STEADY
		return companion.morale
	if casualty_fraction >= threshold:
		companion.morale = CompanionData.Morale.BROKEN
	elif casualty_fraction >= threshold * SHAKEN_FRACTION_OF_THRESHOLD:
		companion.morale = CompanionData.Morale.SHAKEN
	else:
		companion.morale = CompanionData.Morale.STEADY
	return companion.morale


## SHAKEN clears if the threat is gone (all enemies defeated) or the companion is
## far from the nearest enemy (s57.46.10). BROKEN never clears. Returns morale.
static func relieve_shaken(companion: CompanionData, threat_cleared: bool, tiles_from_enemy: int) -> CompanionData.Morale:
	if companion.morale == CompanionData.Morale.SHAKEN:
		if threat_cleared or tiles_from_enemy >= 10:
			companion.morale = CompanionData.Morale.STEADY
	return companion.morale


## Combat-roll penalty from morale (SHAKEN = −5; otherwise 0).
static func combat_penalty(companion: CompanionData) -> int:
	return SHAKEN_COMBAT_PENALTY if companion.morale == CompanionData.Morale.SHAKEN else 0


# === NOISE (s57.46.13) =======================================================

## Per-event noise radius contribution. Doshin types use their baked-in base;
## other companions reduce a +1.0 base by Stealth rank (1 → +0.5, 2 → +0.25,
## 3+ → +0).
static func noise_contribution(companion: CompanionData) -> float:
	if DOSHIN_NOISE.has(companion.type):
		return DOSHIN_NOISE[companion.type]
	return _stealth_noise(companion.stealth_rank)


static func _stealth_noise(stealth_rank: int) -> float:
	if stealth_rank <= 0:
		return 1.0
	if stealth_rank == 1:
		return 0.5
	if stealth_rank == 2:
		return 0.25
	return 0.0


## Total noise added to every event by a roster of companions.
static func party_noise_contribution(roster: Array) -> float:
	var total: float = 0.0
	for c: CompanionData in roster:
		total += noise_contribution(c)
	return total


# === DOSHIN RULES (s57.46.3 / s57.46.11) =====================================

## Doshin team grapple/restrain bonus (+5 at 2+ members; lost when reduced to 1).
static func teamwork_grapple_bonus(companion: CompanionData) -> int:
	if companion.type == CompanionData.CompanionType.CITY_DOSHIN_TEAM and companion.team_size >= 2:
		return TEAMWORK_GRAPPLE_BONUS
	return 0


## Will a doshin engage a samurai target? Only with an active arrest warrant.
## Village doshin still refuse unless their headman is present and orders it.
## Non-doshin companions are unaffected (return true). (s57.46.11)
static func will_engage_samurai(
	companion: CompanionData,
	target_is_samurai: bool,
	arrest_authorized: bool,
	headman_present: bool,
) -> bool:
	if not is_doshin(companion):
		return true
	if not target_is_samurai:
		return true
	if not arrest_authorized:
		return false
	if companion.type == CompanionData.CompanionType.VILLAGE_DOSHIN:
		return headman_present
	return true  # city doshin / headman: reluctant (−5) but will act


## GUARD EXIT grapple penalty against a fleer (−10 if the fleer is a samurai).
static func guard_exit_penalty(companion: CompanionData, fleer_is_samurai: bool) -> int:
	if fleer_is_samurai and is_doshin(companion):
		return SAMURAI_GUARD_PENALTY
	return 0


# === DEATH CONSEQUENCES (s57.46.14) ==========================================

## World-state consequences of a companion dying on the map. Returns flags the
## caller applies: doshin_loss (increment settlement doshin_losses), named_vacancy
## (FILL_VACANCY on the appointing lord), and a Tier 4 death topic for named NPCs.
static func death_consequences(companion: CompanionData) -> Dictionary:
	var result: Dictionary = {
		"doshin_loss": false,
		"named_vacancy": false,
		"generate_topic": false,
		"settlement_id": companion.home_settlement_id,
		"character_id": companion.character_id,
	}
	if is_doshin(companion):
		result["doshin_loss"] = true
	else:
		# Yojimbo / yoriki / named ally — named character permanent death.
		result["named_vacancy"] = true
		result["generate_topic"] = true
	return result
