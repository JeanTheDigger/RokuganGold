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
## ARCHIVE_TOPIC, ANONYMOUS_TIP, RESURRECT_TOPIC, SPONSOR_INSURGENCY, and
## BRIBE_GARRISON_COMMANDER resolve here and return effect flags the
## DayOrchestrator Kolat writeback applies to world collections (topic pool,
## insurgency list, Honor, the standing-bribe registry + its seasonal upkeep).
## ARCHIVE_TOPIC is fully self-contained (writes the Master's cloud_archive).
## Actions whose effect still requires a system not wired here (the Cloud's-Eyes
## spell, Silk intelligence routing / network records) return
## {ok: false, reason: "deferred_system"}.

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
			r = _sponsor_insurgency(actor, metadata, dice)
		"BRIBE_GARRISON_COMMANDER":
			r = _bribe_garrison(actor, metadata, dice)
		"ARCHIVE_TOPIC":
			r = _archive_topic(actor, metadata)
		"ANONYMOUS_TIP":
			r = _anonymous_tip(metadata)
		"RESURRECT_TOPIC":
			r = _resurrect_topic(actor, metadata, dice)
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

static func _sponsor_insurgency(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
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
	# Routing roll (s54.7c): Commerce (Merchant) + trait vs TN 20 to move the funds
	# without leaving a commercial trail. The funds are routed and the insurgency
	# seeded/strengthened either way — the roll only governs detection.
	#   success         → clean, no topic
	#   failure         → Tier 4 investigation topic naming suspicious merchant activity
	#   critical (≤ -10)→ traced to a Coin cover identity (MANAGE_COMPROMISED_AGENT)
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Commerce", 20)
	var margin: int = int(roll.get("margin", 0))
	var success: bool = bool(roll.get("success", false))
	# Seeding/strengthening of the InsurgencyData and the failure/crit topics are
	# applied by the DayOrchestrator Kolat writeback, which has the world collections.
	return {
		"ok": true, "cost": cost, "strength_funded": strength,
		"seeds_insurgency": true, "routing_detected": not success,
		"compromised": margin <= -10,
	}


static func _bribe_garrison(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var cost: int = KolatSystem.bribe_garrison_cost_per_season()
	# A target commander is required (supplied by the deferred Coin decomposition).
	var commander: L5RCharacterData = metadata.get("target", null)
	if commander == null:
		return {"ok": false, "reason": "no_target", "cost": cost}
	# Pay the first installment (vault if at-temple, else local reserve). The koku is
	# spent on the attempt regardless of the commander's answer (s54.7c: on refusal the
	# commander "pockets the money").
	var temple: SettlementData = metadata.get("temple", null)
	if temple != null:
		if temple.temple_vault_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		temple.temple_vault_koku -= cost
	else:
		if actor.kolat_koku < cost:
			return {"ok": false, "reason": "insufficient_funds", "cost": cost}
		actor.kolat_koku -= cost
	# Roll Commerce (Appraisal) + trait vs the commander's Willpower × 5 (s54.7c).
	#   success         → bribe established; the −2 under-garrison Stability penalty
	#                     (s11.11) is applied each season by the Kolat seasonal pass
	#   failure         → commander refuses, no topic, no bribe
	#   critical (≤ -10)→ commander reports the approach; Tier 3 threat topic
	var tn: int = commander.willpower * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Commerce", tn)
	var success: bool = bool(roll.get("success", false))
	var margin: int = int(roll.get("margin", 0))
	return {
		"ok": true, "cost": cost,
		"bribe_established": success,
		"creates_threat_topic": margin <= -10,
	}


# === CLOUD ARCHIVE / TOPIC ===================================================

## ARCHIVE_TOPIC (s54.7c). 0 AP, Master Cloud. Writes a topic's full data
## structure into cloud_archive in special_data. Clerical — no roll, no Honor.
## The topic to archive is supplied by the deferred MAINTAIN_CLOUD_ARCHIVE
## decomposition as metadata["topic"] (a TopicData).
static func _archive_topic(actor: L5RCharacterData, metadata: Dictionary) -> Dictionary:
	var topic: TopicData = metadata.get("topic", null)
	if topic == null:
		return {"ok": false, "reason": "no_topic"}
	var archive: Dictionary = actor.special_data.get("cloud_archive", {})
	# Snapshot the topic's data (s54.7c: tier, parties, content, source, IC day,
	# original momentum). Stored as a plain Dictionary so it serialises with the
	# character and survives independent of normal momentum decay.
	archive[topic.topic_id] = {
		"topic_id": topic.topic_id,
		"title": topic.title,
		"slug": topic.slug,
		"tier": int(topic.tier),
		"category": int(topic.category),
		"subject_character_id": topic.subject_character_id,
		"clan_involved": topic.clan_involved,
		"family_involved": topic.family_involved,
		"momentum": topic.momentum,
		"ic_day_recorded": topic.ic_day_created,
		"leverage_value": int(metadata.get("leverage_value", 0)),
		"is_archived": true,
	}
	actor.special_data["cloud_archive"] = archive
	return {"ok": true, "archived_topic_id": topic.topic_id, "archive_size": archive.size()}


## ANONYMOUS_TIP (s54.7c). 1 AP, Master Jade. Feeds intelligence to an
## anti-Shadowlands organisation without identifying the source. Generates a
## Tier 4 topic at the target organisation; the topic does not name the source.
## The topic is created by the DayOrchestrator Kolat writeback. The target org
## and subject are supplied by the deferred Jade decomposition.
static func _anonymous_tip(metadata: Dictionary) -> Dictionary:
	var org: String = String(metadata.get("tip_org", ""))
	var subject: String = String(metadata.get("tip_subject", ""))
	if org.is_empty() or subject.is_empty():
		return {"ok": false, "reason": "no_target"}
	return {
		"ok": true, "creates_anon_tip": true,
		"tip_org": org, "tip_subject": subject,
		"tip_subject_id": int(metadata.get("tip_subject_id", -1)),
	}


## RESURRECT_TOPIC (s54.7c). 1 AP, Master Cloud. Re-injects an archived topic
## into the active pool attributed to "historical records". Roll Calligraphy
## (Cipher) + Intelligence vs TN 20 to encode the resurrection document
## convincingly; failure leaves it traceable. Honor −0.5 per use. The archived
## topic is selected by metadata["archive_topic_id"]; the actual re-injection is
## applied by the DayOrchestrator Kolat writeback.
static func _resurrect_topic(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var archive: Dictionary = actor.special_data.get("cloud_archive", {})
	var tid: int = int(metadata.get("archive_topic_id", -1))
	if not archive.has(tid):
		return {"ok": false, "reason": "no_archived_topic"}
	var entry: Dictionary = archive[tid]
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Calligraphy", 20)
	var success: bool = bool(roll.get("success", false))
	var margin: int = int(roll.get("margin", 0))
	# Success encodes the document convincingly (untraceable). Failure leaves the
	# cipher family identifiable; a strong success (1 Raise worth of margin)
	# reduces traceability by one tier. Honor −0.5 applies regardless of outcome.
	return {
		"ok": true, "resurrects_topic": true, "archive_entry": entry,
		"traceable": not success, "traceability_reduced": success and margin >= 5,
		"honor_loss": 0.5,
	}
