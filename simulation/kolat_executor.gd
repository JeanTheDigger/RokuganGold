class_name KolatExecutor
## Executor handlers for the mechanically-resolvable Kolat ActionIDs (GDD s54.7c),
## backed by KolatSystem. Pure simulation class — no Node inheritance.
##
## This is the headless executor layer: `execute()` resolves a Kolat action from
## (actor, metadata, dice) and returns a result Dictionary. As of Tranche 5 it IS
## wired into the main ActionExecutor dispatch (ActionExecutor._KOLAT_ACTION_IDS)
## and reachable through the Phase-3 context unlock (NPCDecisionEngine
## .KOLAT_ACTION_POOL) plus the sleeper override loop. Still deferred: full
## per-action metadata population by the 6 Kolat decomposition functions (this
## layer reads targets/amounts/drops from action.metadata, which the decomposers
## do not yet populate end-to-end). All NPC-engine integration is unverified
## without a Godot runtime.
##
## Actions whose effect requires another system not callable here (topic
## resurrection, the Cloud's-Eyes spell, anonymous-tip topics, intelligence
## routing, insurgency seeding) return {ok: false, reason: "deferred_system"}.

## Resolve a Kolat action. `metadata` carries the action's resolved targets
## (target, temple, sleeper, amount, concealment, drop, strength, …). Returns a
## result dict; always includes "ok" and "action".
static func execute(
	action_id: String,
	actor: L5RCharacterData,
	metadata: Dictionary,
	dice: DiceEngine,
) -> Dictionary:
	var r: Dictionary
	match action_id:
		"LAUNDER_KOKU":
			r = _launder(actor)
		"UNDERREPORT_KOKU":
			r = _underreport(actor, metadata)
		"TRANSFER_KOLAT_FUNDS":
			r = _transfer(actor, metadata)
		"CONTRIBUTE_TO_RESERVE":
			r = _contribute_to_reserve(actor, metadata)
		"CONDUCT_CONDITIONING":
			r = _conduct_conditioning(actor, metadata, dice)
		"MAINTAIN_SLEEPER_CONTACT":
			r = _maintain_sleeper(actor, metadata, dice)
		"ACTIVATE_SLEEPER":
			r = _activate_sleeper(metadata)
		"ESTABLISH_DEAD_DROP":
			r = _establish_dead_drop(metadata)
		"CHECK_DEAD_DROP", "ROUTE_VIA_DEAD_DROP", "CHECK_CONFIRMATION_DROP":
			r = _visit_dead_drop(metadata)
		"SPONSOR_INSURGENCY":
			r = _sponsor_insurgency(actor, metadata)
		"BRIBE_GARRISON_COMMANDER":
			r = _bribe_garrison(actor, metadata)
		_:
			# Topic/spell/network ActionIDs need systems not callable here.
			r = {"ok": false, "reason": "deferred_system"}
	r["action"] = action_id
	return r


# === KOKU ====================================================================

static func _launder(actor: L5RCharacterData) -> Dictionary:
	var amount: int = KolatSystem.launder_koku(actor)
	return {"ok": true, "laundered": amount, "kolat_koku": actor.kolat_koku, "dirty_koku": actor.dirty_koku}


static func _underreport(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	var amount: int = int(metadata.get("amount", 0))
	if amount <= 0:
		return {"ok": false, "reason": "no_amount"}
	KolatSystem.add_dirty_koku(actor, amount)
	return {"ok": true, "dirty_koku": actor.dirty_koku}


static func _transfer(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	var temple: SettlementData = metadata.get("temple", null)
	if temple == null:
		return {"ok": false, "reason": "no_temple"}
	var moved: int = KolatSystem.transfer_to_vault(actor, temple, int(metadata.get("amount", actor.kolat_koku)))
	return {"ok": true, "transferred": moved, "vault": temple.temple_vault_koku}


static func _contribute_to_reserve(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	# CONTRIBUTE_TO_RESERVE (0 AP auto): divert skim_rate of a commerce yield into
	# dirty_koku (the local hidden reserve). s54.7c.
	var yield_koku: float = float(metadata.get("commerce_yield", 0.0))
	var skim_rate: float = float(metadata.get("skim_rate", 0.25))
	var diverted: int = int(floor(yield_koku * clampf(skim_rate, 0.0, 1.0)))
	if diverted > 0:
		KolatSystem.add_dirty_koku(actor, diverted)
	return {"ok": true, "diverted": diverted, "dirty_koku": actor.dirty_koku}


# === SLEEPER =================================================================

static func _conduct_conditioning(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var target: L5RCharacterData = metadata.get("target", null)
	if target == null:
		return {"ok": false, "reason": "no_target"}
	# Resolve one session. Cumulative progress + the completion handler (install
	# fields, −3.0 Honor) are driven by the CONDITION_SLEEPER decomposition (deferred).
	var session: Dictionary = KolatSystem.resolve_conditioning_session(actor, target, dice)
	return {"ok": true, "progressed": session.get("progressed", false),
		"progress_per_session": KolatSystem.progress_per_session(target),
		"sessions_required": KolatSystem.sessions_required(target)}


static func _maintain_sleeper(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var sleeper: L5RCharacterData = metadata.get("sleeper", null)
	if sleeper == null or not KolatSystem.is_sleeper(sleeper):
		return {"ok": false, "reason": "not_a_sleeper"}
	# Detect degradation: Medicine + Perception vs TN 20 (s54.7c). Roll BEFORE the
	# restore so the reading reflects the pre-contact state.
	var degrading: bool = sleeper.conditioning_stability < 100.0
	var roll: int = dice.roll_and_keep(
		actor.skills.get("Medicine", 0) + actor.perception, maxi(1, actor.perception)).total
	var detected: bool = degrading and roll >= 20
	KolatSystem.maintain_sleeper_contact(sleeper)
	return {"ok": true, "degradation_detected": detected,
		"conditioning_stability": sleeper.conditioning_stability}


static func _activate_sleeper(metadata: Dictionary) -> Dictionary:
	var sleeper: L5RCharacterData = metadata.get("sleeper", null)
	if sleeper == null:
		return {"ok": false, "reason": "no_sleeper"}
	return KolatSystem.activate_sleeper(sleeper, String(metadata.get("spoken_phrase", "")))


# === DEAD DROPS ==============================================================

static func _establish_dead_drop(metadata: Dictionary) -> Dictionary:
	var drop: Dictionary = KolatSystem.make_dead_drop(int(metadata.get("concealment", 3)))
	return {"ok": true, "drop": drop}


static func _visit_dead_drop(metadata: Dictionary) -> Dictionary:
	var drop: Dictionary = metadata.get("drop", {})
	if drop.is_empty():
		return {"ok": false, "reason": "no_drop"}
	KolatSystem.register_dead_drop_visit(drop)
	return {"ok": true, "drop": drop, "abandoned": drop.get("abandoned", false)}


# === DISRUPTION ==============================================================

static func _sponsor_insurgency(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	var strength: int = int(metadata.get("strength", 1))
	var cost: int = KolatSystem.sponsor_insurgency_cost(strength)
	# Funding source: temple vault if at-temple, else the local kolat_koku reserve.
	var temple: SettlementData = metadata.get("temple", null)
	if temple != null:
		if temple.temple_vault_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		temple.temple_vault_koku -= cost
	else:
		if actor.kolat_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		actor.kolat_koku -= cost
	# The actual insurgency seed/strengthen is applied by the InsurgencySystem
	# wiring (deferred). This handler resolves only the funding.
	return {"ok": true, "cost": cost, "strength_funded": strength, "insurgency_apply": "deferred"}


static func _bribe_garrison(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	var cost: int = KolatSystem.bribe_garrison_cost_per_season()
	var temple: SettlementData = metadata.get("temple", null)
	if temple != null:
		if temple.temple_vault_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		temple.temple_vault_koku -= cost
	else:
		if actor.kolat_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		actor.kolat_koku -= cost
	# The Stability penalty application is applied by the InsurgencySystem/Stability
	# wiring at the next Seasonal Tick (deferred). This handler resolves the payment.
	return {"ok": true, "cost": cost, "stability_penalty_apply": "deferred"}
