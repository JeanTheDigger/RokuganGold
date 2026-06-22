class_name KolatSystem
## Kolat conspiracy headless subsystems (GDD s54.7 / s54.7c / s54.7e / s54.7h,
## locked s54.7j). Pure simulation class — no Node inheritance. Tranche 1:
## sleeper conditioning, the koku pipeline, dead-drop concealment, Eye
## contention, and disruption-funding costs. Master selection at world-gen and
## the full NeedType/ActionID NPC-engine pipeline are deferred.

# Sleeper conditioning (s54.7c/e).
const CONDITIONING_SESSIONS_PER_WILLPOWER: int = 3
const STABILITY_FULL: float = 100.0
const STABILITY_SEASONAL_DECAY: float = 5.0
const STABILITY_CONTACT_RESTORE: float = 10.0
const ACTIVATION_STABILITY_FLOOR: float = 50.0  # must be > this to activate
const CONDITIONING_HONOR_COST: float = -3.0      # applied once on completion
const SLEEPER_COMMAND_MAX_WORDS: int = 5

# s33 The World is Truth (Air 6, Kolat): a magical single-cast sleeper install — an alternative to
# the multi-session psychological CONDUCT_CONDITIONING path. GDD duration 1 month (+1 month per 3
# Raises); the rewritten memories fade when the month lapses (vs the permanent psychological sleeper).
const WORLD_IS_TRUTH_ID: String = "the_world_is_truth"
const WORLD_IS_TRUTH_MASTERY: int = 6

# Koku pipeline (s54.7c/h).
const LAUNDER_PER_AP: int = 5
const VAULT_MIN_RESERVE: int = 50

# Dead-drop concealment (s54.7c).
const DEAD_DROP_FREE_VISITS_PER_SEASON: int = 3

# Disruption funding (s54.7c).
const SPONSOR_INSURGENCY_KOKU_PER_STRENGTH: int = 10
const BRIBE_GARRISON_KOKU_PER_SEASON: int = 5


# === SECT / MASTER HELPERS ===================================================

## Sect → Kolat standing-objective NeedType (s54.7b standing-objective table).
## Three mappings are pinned explicitly by the GDD (s54.7c prose names the Sect):
##   Silk → MAINTAIN_KOLAT_NETWORK, Coin → MANAGE_KOLAT_FUNDS, Dream → MAINTAIN_SLEEPER.
## Five more are structural name-matches — each Sect's s54.7b mandate sentence
## restates exactly one already-defined NeedType in objective_alignment.json:
##   Tiger "maintain the secrecy of the organisation" → MONITOR_KOLAT_SECURITY,
##   Chrysanthemum "advance warning of every Imperial decision" → MONITOR_IMPERIAL_COURT,
##   Cloud "preserve forbidden knowledge" → MAINTAIN_CLOUD_ARCHIVE,
##   Jade "prevent supernatural corruption" → ASSESS_SUPERNATURAL_THREAT,
##   Steel "keep the Hidden Temple secure" → MONITOR_TEMPLE_PERIMETER.
## Lotus → MAINTAIN_DEAD_DROP_SCHEDULE: owner decision 2026-06-06. Lotus is
## reactive (it executes Tiger's elimination assignments delivered via dead drop),
## so its self-generated standing is keeping that assignment channel ready.
## Roc is explicitly inactive at launch (s54.7b: "no standing mandate assigned") → "".
const SECT_STANDING_NEEDTYPE: Dictionary = {
	Enums.KolatSect.TIGER: "MONITOR_KOLAT_SECURITY",
	Enums.KolatSect.CHRYSANTHEMUM: "MONITOR_IMPERIAL_COURT",
	Enums.KolatSect.SILK: "MAINTAIN_KOLAT_NETWORK",
	Enums.KolatSect.COIN: "MANAGE_KOLAT_FUNDS",
	Enums.KolatSect.CLOUD: "MAINTAIN_CLOUD_ARCHIVE",
	Enums.KolatSect.JADE: "ASSESS_SUPERNATURAL_THREAT",
	Enums.KolatSect.DREAM: "MAINTAIN_SLEEPER",
	Enums.KolatSect.STEEL: "MONITOR_TEMPLE_PERIMETER",
	Enums.KolatSect.LOTUS: "MAINTAIN_DEAD_DROP_SCHEDULE",  # owner decision 2026-06-06
	Enums.KolatSect.ROC: "",     # inactive at launch (s54.7b)
}


## The Master's Sect standing-objective NeedType, or "" when none applies
## (Roc is inactive at launch).
static func standing_needtype_for_sect(sect: int) -> String:
	return String(SECT_STANDING_NEEDTYPE.get(sect, ""))


static func is_kolat(character: L5RCharacterData) -> bool:
	return character.kolat_sect != Enums.KolatSect.NONE


static func is_master(character: L5RCharacterData) -> bool:
	return character.is_kolat_master


static func is_sleeper(character: L5RCharacterData) -> bool:
	return character.conditioning_stability >= 0.0


# === SLEEPER CONDITIONING (s54.7c / s54.7e) ==================================

## Number of CONDUCT_CONDITIONING sessions to fully condition a target
## (Willpower × 3, s54.7c).
static func sessions_required(target: L5RCharacterData) -> int:
	return maxi(1, target.willpower * CONDITIONING_SESSIONS_PER_WILLPOWER)


## Conditioning progress (0–100) added per fully-successful session.
static func progress_per_session(target: L5RCharacterData) -> float:
	return STABILITY_FULL / float(sessions_required(target))


## Resolve one conditioning session (s54.7c): repeated contested Willpower
## (target) vs Temptation + Intelligence (Dream Master) until one side wins three
## in a row. Master 3-in-a-row → the session progresses; target 3-in-a-row → the
## session fails (the Master must wait). Returns {progressed: bool}.
static func resolve_conditioning_session(
	dream_master: L5RCharacterData,
	target: L5RCharacterData,
	dice: DiceEngine,
) -> Dictionary:
	var master_streak: int = 0
	var target_streak: int = 0
	var temptation: int = dream_master.skills.get("Temptation", 0)
	var dm_int: int = dream_master.intelligence
	var t_wil: int = target.willpower
	# Cap the loop defensively; three-in-a-row resolves quickly in practice.
	for _i: int in range(50):
		var m_roll: int = dice.roll_and_keep(temptation + dm_int, maxi(1, dm_int)).total
		var t_roll: int = dice.roll_and_keep(t_wil, maxi(1, t_wil)).total
		if m_roll >= t_roll:
			master_streak += 1
			target_streak = 0
		else:
			target_streak += 1
			master_streak = 0
		if master_streak >= 3:
			return {"progressed": true}
		if target_streak >= 3:
			return {"progressed": false}
	return {"progressed": false}


## Completion handler (s54.7c): install the four hidden sleeper fields on the
## target, register contact tracking, and apply the one-time conditioning Honor
## cost to the Dream Master. `command` is the engine-readable sleeper command.
static func complete_conditioning(
	target: L5RCharacterData,
	dream_master: L5RCharacterData,
	trigger_phrase: String,
	command: Dictionary,
) -> void:
	target.trigger_phrase = trigger_phrase
	target.sleeper_command = command
	target.conditioning_stability = STABILITY_FULL
	target.active_sleeper_command = {}
	target.sleeper_contact_overdue = 0
	HonorGlorySystem.apply_honor_change(dream_master, CONDITIONING_HONOR_COST)


## s33 The World is Truth — resolve the Contested Insight/Air cast (caster vs target). Caster rolls
## (Insight Rank + Air Ring, keep Air Ring); the target resists with (Willpower + Air Ring, keep Air
## Ring) — the mental-domination resist convention (the GDD names "Contested Insight/Air vs the
## target" without the target's resist Trait). Returns {success, caster_total, target_total}.
static func resolve_world_is_truth_cast(
	caster: L5RCharacterData, target: L5RCharacterData, dice: DiceEngine,
) -> Dictionary:
	var c_air: int = SpellSystem.get_ring_value(caster, Enums.Ring.AIR)
	var t_air: int = SpellSystem.get_ring_value(target, Enums.Ring.AIR)
	var c_roll: int = dice.roll_and_keep(maxi(1, caster.insight_rank + c_air), maxi(1, c_air)).total
	var t_roll: int = dice.roll_and_keep(maxi(1, target.willpower + t_air), maxi(1, t_air)).total
	return {"success": c_roll >= t_roll, "caster_total": c_roll, "target_total": t_roll}


## s33 The World is Truth — install the magically-rewritten sleeper. Same hidden fields as
## complete_conditioning, but with a 1-month expiry (+1 month per 3 Raises) instead of permanent
## psychological stability. Honor is applied by the caller (the executor).
static func install_world_is_truth_sleeper(
	target: L5RCharacterData, trigger_phrase: String, command: Dictionary, raises: int, ic_day: int,
) -> void:
	target.trigger_phrase = trigger_phrase
	target.sleeper_command = command
	target.conditioning_stability = STABILITY_FULL
	target.active_sleeper_command = {}
	target.sleeper_contact_overdue = 0
	var months: int = 1 + int(raises / 3)
	target.sleeper_expiry_ic_day = ic_day + TimeSystem.IC_DAYS_PER_MONTH * months


## s33 Daily expiry pass: a DORMANT magically-installed sleeper whose month has lapsed reverts —
## the rewritten memories fade and all sleeper fields clear. Active sleepers (activated mid-window,
## the command runs to completion) and permanent psychological sleepers (expiry -1) are untouched.
## Returns true if it expired this tick.
static func process_sleeper_expiry(sleeper: L5RCharacterData, ic_day: int) -> bool:
	if sleeper.sleeper_expiry_ic_day < 0:
		return false
	if not sleeper.active_sleeper_command.is_empty():
		return false
	if ic_day < sleeper.sleeper_expiry_ic_day:
		return false
	sleeper.trigger_phrase = ""
	sleeper.sleeper_command = {}
	sleeper.conditioning_stability = -1.0
	sleeper.sleeper_contact_overdue = -1
	sleeper.sleeper_expiry_ic_day = -1
	return true


## Seasonal degradation pass (s54.7e): stability −5, contact-overdue += season
## length. Runs as background processing over every sleeper. No-op on non-sleepers
## and on already-activated sleepers (stability is no longer evaluated once active).
static func degrade_sleeper_seasonal(sleeper: L5RCharacterData, season_days: int) -> void:
	if not is_sleeper(sleeper):
		return
	if not sleeper.active_sleeper_command.is_empty():
		return
	if sleeper.sleeper_expiry_ic_day >= 0:
		return  # s33 magical (World is Truth) sleepers expire on their own clock, not psychological decay
	sleeper.conditioning_stability = maxf(0.0, sleeper.conditioning_stability - STABILITY_SEASONAL_DECAY)
	sleeper.sleeper_contact_overdue += maxi(0, season_days)


## MAINTAIN_SLEEPER_CONTACT effect (s54.7c): reset contact-overdue and restore
## stability +10 (capped). The only action that services both metrics together.
static func maintain_sleeper_contact(sleeper: L5RCharacterData) -> void:
	if not is_sleeper(sleeper):
		return
	sleeper.sleeper_contact_overdue = 0
	sleeper.conditioning_stability = minf(STABILITY_FULL, sleeper.conditioning_stability + STABILITY_CONTACT_RESTORE)


## A sleeper may be activated only if dormant and stability is above the floor
## (s54.7c: "above 50 and dormant").
static func can_activate_sleeper(sleeper: L5RCharacterData) -> bool:
	if not is_sleeper(sleeper):
		return false
	if not sleeper.active_sleeper_command.is_empty():
		return false
	return sleeper.conditioning_stability > ACTIVATION_STABILITY_FLOOR


## ACTIVATE_SLEEPER (s54.7e): if the spoken phrase matches and the sleeper can be
## activated, populate active_sleeper_command from the stored command. Returns
## {ok, reason}. The override loop itself runs in the NPC engine (deferred).
static func activate_sleeper(sleeper: L5RCharacterData, spoken_phrase: String) -> Dictionary:
	if not is_sleeper(sleeper):
		return {"ok": false, "reason": "not_a_sleeper"}
	if spoken_phrase != sleeper.trigger_phrase or sleeper.trigger_phrase == "":
		return {"ok": false, "reason": "phrase_mismatch"}
	if not can_activate_sleeper(sleeper):
		return {"ok": false, "reason": "cannot_activate"}
	sleeper.active_sleeper_command = sleeper.sleeper_command.duplicate(true)
	return {"ok": true}


## Five-word constraint on the spoken command (s54.7c/e).
static func is_valid_command_phrase(spoken: String) -> bool:
	if spoken.strip_edges().is_empty():
		return false
	return spoken.strip_edges().split(" ", false).size() <= SLEEPER_COMMAND_MAX_WORDS


# === KOKU PIPELINE (s54.7c / s54.7h) =========================================

## UNDERREPORT_KOKU result: extracted koku enters dirty_koku (not yet spendable).
static func add_dirty_koku(coin: L5RCharacterData, amount: int) -> void:
	coin.dirty_koku += maxi(0, amount)


## LAUNDER_KOKU (s54.7c): move up to 5 koku per AP from dirty_koku into the
## spendable kolat_koku reserve. Returns the amount laundered this AP.
static func launder_koku(coin: L5RCharacterData) -> int:
	var amount: int = mini(LAUNDER_PER_AP, coin.dirty_koku)
	coin.dirty_koku -= amount
	coin.kolat_koku += amount
	return amount


## TRANSFER_KOLAT_FUNDS (s54.7c): deposit clean koku from Master Coin's reserve
## into the Hidden Temple vault. Returns the amount deposited.
static func transfer_to_vault(coin: L5RCharacterData, temple: SettlementData, amount: int) -> int:
	var moved: int = clampi(amount, 0, coin.kolat_koku)
	coin.kolat_koku -= moved
	temple.temple_vault_koku = maxi(0, temple.temple_vault_koku) + moved
	return moved


## Tiger allocation (s54.7c/h): SEND_KOLAT_DIRECTIVE decrements the vault and
## credits the receiving Master's operational_koku. Returns the amount allocated
## (0 if the vault lacks the funds).
static func allocate_from_vault(temple: SettlementData, master: L5RCharacterData, amount: int) -> int:
	if amount <= 0 or temple.temple_vault_koku < amount:
		return 0
	temple.temple_vault_koku -= amount
	master.operational_koku += amount
	return amount


## True if the vault is below the seasonal minimum reserve (fires MANAGE_KOLAT_FUNDS).
static func vault_below_threshold(temple: SettlementData, threshold: int = VAULT_MIN_RESERVE) -> bool:
	return temple.temple_vault_koku < threshold


# === DISRUPTION FUNDING (s54.7c) =============================================

## SPONSOR_INSURGENCY koku cost (10 per Strength point seeded/added).
static func sponsor_insurgency_cost(strength_points: int) -> int:
	return maxi(0, strength_points) * SPONSOR_INSURGENCY_KOKU_PER_STRENGTH


## BRIBE_GARRISON_COMMANDER ongoing koku cost per season.
static func bribe_garrison_cost_per_season() -> int:
	return BRIBE_GARRISON_KOKU_PER_SEASON


## True if `reserve` can fund a disruption of `cost` koku (kolat_koku or vault).
static func can_fund_disruption(reserve: int, cost: int) -> bool:
	return reserve >= cost and cost > 0


# === DEAD-DROP CONCEALMENT (s54.7c) ==========================================

## Make a new dead-drop record with a concealment rating (1–5).
static func make_dead_drop(concealment: int) -> Dictionary:
	return {
		"concealment": clampi(concealment, 1, 5),
		"visits_this_season": 0,
		"abandoned": false,
	}


## Register a visit to a dead drop (s54.7c): each visit past the 3rd in a season
## reduces concealment by 1; a drop at concealment 0 is abandoned. Mutates and
## returns the drop dict.
static func register_dead_drop_visit(drop: Dictionary) -> Dictionary:
	if drop.get("abandoned", false):
		return drop
	drop["visits_this_season"] = int(drop.get("visits_this_season", 0)) + 1
	if drop["visits_this_season"] > DEAD_DROP_FREE_VISITS_PER_SEASON:
		drop["concealment"] = int(drop.get("concealment", 0)) - 1
	if int(drop.get("concealment", 0)) <= 0:
		drop["concealment"] = 0
		drop["abandoned"] = true
	return drop


## Reset a dead drop's per-season visit counter (seasonal tick).
static func reset_dead_drop_season(drop: Dictionary) -> void:
	drop["visits_this_season"] = 0


# === EYE CONTENTION (s54.7c) =================================================

## Resolve OBSERVE_VIA_EYE contention when multiple Masters want the Eye on the
## same IC day (s54.7c): highest ImmediateNeed priority wins; ties → Tiger; then
## → highest public Status. `contenders` is an Array of dicts:
##   { npc_id: int, priority: int, is_tiger: bool, status: float }
## Returns the winning npc_id, or -1 if none.
static func resolve_eye_contention(contenders: Array) -> int:
	var best: Dictionary = {}
	for c: Dictionary in contenders:
		if best.is_empty():
			best = c
			continue
		if _eye_beats(c, best):
			best = c
	return int(best.get("npc_id", -1)) if not best.is_empty() else -1


static func _eye_beats(a: Dictionary, b: Dictionary) -> bool:
	var pa: int = int(a.get("priority", 0))
	var pb: int = int(b.get("priority", 0))
	if pa != pb:
		return pa > pb
	var ta: bool = bool(a.get("is_tiger", false))
	var tb: bool = bool(b.get("is_tiger", false))
	if ta != tb:
		return ta  # Tiger wins the priority tie
	return float(a.get("status", 0.0)) > float(b.get("status", 0.0))
