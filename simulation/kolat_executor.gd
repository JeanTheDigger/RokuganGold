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
## ARCHIVE_TOPIC, ANONYMOUS_TIP, RESURRECT_TOPIC, SPONSOR_INSURGENCY,
## BRIBE_GARRISON_COMMANDER, DELIVER_SEALED_LETTER, and ROUTE_ANONYMOUS_INTELLIGENCE
## resolve here and return effect flags the DayOrchestrator Kolat writeback applies
## to world collections (topic pool, insurgency list, Honor, the standing-bribe
## registry + seasonal upkeep, the letter pipeline, asset disposition).
## ARCHIVE_TOPIC is fully self-contained (writes the Master's cloud_archive).
## Actions whose effect still requires a system not wired here (the Cloud's-Eyes
## spell, the Tear network, the Eye at the Hidden Temple, and the Silk/Lotus/Steel
## network-record lifecycle) return {ok: false, reason: "deferred_system"}.

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
		"APPROACH_FOR_RECRUITMENT":
			r = _approach_recruitment(actor, metadata, dice)
		"ROTATE_DEAD_DROP":
			r = _rotate_dead_drop(actor, metadata, dice)
		"USE_CLOUDS_EYES":
			r = _use_clouds_eyes(actor, metadata, dice)
		"DISTRIBUTE_INTELLIGENCE":
			r = _distribute_intelligence(metadata)
		"DELIVER_SEALED_LETTER":
			r = _deliver_sealed_letter(actor, metadata, dice)
		"ROUTE_ANONYMOUS_INTELLIGENCE":
			r = _route_anonymous_intelligence(actor, metadata, dice)
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


# === DEAD DROP ROTATION (Lotus, s54.7c) ======================================

## ROTATE_DEAD_DROP. 1 AP, Master Lotus. Replaces a compromised dead-drop node in
## lotus_network_record with the current settlement. Self-contained (Pattern B):
## mutates the Master's record directly. Roll Stealth (Sneaking) vs TN 10 to avoid
## drawing attention; the rotation itself succeeds regardless (the roll only flags
## whether it was noticed). Requires at least one compromised drop entry.
static func _rotate_dead_drop(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var settlement_id: String = String(metadata.get("settlement_id", actor.physical_location))
	if settlement_id == "":
		return {"ok": false, "reason": "no_settlement"}
	var rotated: String = KolatNetwork.rotate_dead_drop(actor, settlement_id)
	if rotated == "":
		return {"ok": false, "reason": "no_compromised_drop"}
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Stealth", 10)
	return {"ok": true, "rotated_operative": rotated, "unnoticed": bool(roll.get("success", false))}


# === INTELLIGENCE DISTRIBUTION (Silk, s54.7c) ================================

## DISTRIBUTE_INTELLIGENCE. 1 AP, Master Silk. Routes intelligence (a topic) to a
## registered field agent so they stop acting on outdated assumptions. The delivery
## itself does not require a success roll (s54.7c gives a roll only for interception
## on a compromised route). The DayOrchestrator writeback adds the topic to the
## agent's known_topics and refreshes the agent's last-report timestamp.
## DEFERRED: the compromised-route interception (Stealth vs the investigator's
## Investigation) — there is no route-compromise state or investigator selection
## in the model yet.
static func _distribute_intelligence(metadata: Dictionary) -> Dictionary:
	var target: L5RCharacterData = metadata.get("target", null)
	var topic_id: int = int(metadata.get("topic_id", -1))
	if target == null or topic_id < 0:
		return {"ok": false, "reason": "no_target_or_topic"}
	return {"ok": true, "distributes_intel": true,
		"agent_npc_id": target.character_id, "topic_id": topic_id}


# === CLOUD'S EYES (Cloud, s54.7c) ============================================

## USE_CLOUDS_EYES. 1 AP, Master Cloud. Casts the Kolat spell Master Cloud's Eyes
## (Air 3) to observe a target settlement in real time. Mechanically a casting
## roll of Spellcraft + Air Ring vs TN 15; on success 1d3 topics (+1 per Raise)
## from the settlement's current ambient pool enter the caster's known_topics at
## high confidence, tagged clouds_eyes, bypassing intelligence travel delay. The
## actual topic copy is done by the DayOrchestrator Kolat writeback (it has the
## active topic pool and the settlement→province map).
## DEFERRED gates (not enforced here): the Air Ring × 10 mile range limit (blocked
## on map distance data) and the jade-ward/Kuroiban-barrier block (no ward data on
## settlements). The failure −2k2 Perception penalty is not modelled (no per-AP
## modifier system).
static func _use_clouds_eyes(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var settlement_id: String = String(metadata.get("target_settlement_id", ""))
	if settlement_id == "":
		return {"ok": false, "reason": "no_target"}
	var air: int = SpellSystem.get_ring_value(actor, Enums.Ring.AIR)
	var spellcraft: int = int(actor.skills.get("Spellcraft", 0))
	var total: int = dice.roll_and_keep(air + spellcraft, maxi(1, air), spellcraft > 0).total
	if total < 15:
		return {"ok": true, "observes_settlement": false}  # failed scry, no topics
	var raises: int = (total - 15) / 5
	var topic_count: int = dice.rand_int_range(1, 3) + raises
	return {
		"ok": true, "observes_settlement": true,
		"target_settlement_id": settlement_id, "topic_count": topic_count,
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
	# Delegate to KolatNetwork, which writes the s54.7h cloud_archive schema
	# (keyed by archive_id, with parties_named / content_summary / original_momentum
	# / ic_day_archived plus reconstruction extras for RESURRECT_TOPIC).
	var aid: String = KolatNetwork.archive_topic(
		actor, topic, int(metadata.get("ic_day", -1)), int(metadata.get("leverage_value", 0))
	)
	var archive: Dictionary = actor.special_data.get("cloud_archive", {})
	return {"ok": true, "archive_id": aid, "archived_topic_id": topic.topic_id,
		"archive_size": archive.size()}


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


## APPROACH_FOR_RECRUITMENT (s54.7c). 1 AP, all Sects. The recruiting agent makes
## their case; on success the candidate becomes a conscious Kolat agent.
## Requires the candidate's disposition toward the recruiter ≥ Friend (+31, s12.2).
## Roll: contested Sincerity vs the target's Willpower. OWNER RULING (2026-06-07):
## the GDD's "+ (Gi rank × 2)" personality modifier is a mistake — personality
## affects decisions, not mechanics — so it is NOT applied here. Honor −0.5 on
## success only. The kolat_sect mutation, network registration, and topics are
## applied by the DayOrchestrator Kolat writeback.
static func _approach_recruitment(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var target: L5RCharacterData = metadata.get("target", null)
	if target == null:
		return {"ok": false, "reason": "no_target"}
	if target.kolat_sect != Enums.KolatSect.NONE:
		return {"ok": false, "reason": "already_kolat"}
	# Friend-tier disposition gate (s54.7c + s12.2 Friend = +31).
	var disp: int = int(target.disposition_values.get(actor.character_id, 0))
	if disp < 31:
		return {"ok": false, "reason": "disposition_too_low"}
	var roll: Dictionary = SkillResolver.resolve_contested_check(
		actor, target, dice, "Sincerity", "", "", "",
		Enums.Trait.NONE, Enums.Trait.WILLPOWER,
	)
	var success: bool = roll.get("winner", "b") == "a"
	var margin: int = int(roll.get("total_a", 0)) - int(roll.get("total_b", 0))
	if success:
		return {
			"ok": true, "recruits_agent": true,
			"recruiter_sect": actor.kolat_sect,
			"target_npc_id": target.character_id, "honor_loss": 0.5,
		}
	# Failure: a Tier 4 personal "unusual proposition" topic. Critical failure
	# (missed by 10+): the target reports the contact — a Tier 3 threat topic.
	if margin <= -10:
		return {"ok": true, "creates_threat_topic": true}
	return {"ok": true, "creates_proposition_topic": true}


## RESURRECT_TOPIC (s54.7c). 1 AP, Master Cloud. Re-injects an archived topic
## into the active pool attributed to "historical records". Roll Calligraphy
## (Cipher) + Intelligence vs TN 20 to encode the resurrection document
## convincingly; failure leaves it traceable. Honor −0.5 per use. The archived
## topic is selected by metadata["archive_topic_id"]; the actual re-injection is
## applied by the DayOrchestrator Kolat writeback.
static func _resurrect_topic(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var tid: int = int(metadata.get("archive_topic_id", -1))
	var entry: Dictionary = KolatNetwork.get_archived_topic(actor, tid)
	if entry.is_empty():
		return {"ok": false, "reason": "no_archived_topic"}
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


# === SILK / JADE COURIER ROUTING =============================================

## DELIVER_SEALED_LETTER (s54.7c). 1 AP, Silk operative. Carries a sealed cipher
## document to a named recipient (the recipient + payload come from the deferred
## Silk routing as metadata). Roll Sincerity (Deceit) vs TN 10 to appear as
## ordinary correspondence; failure draws a Tier 4 "a courier was asking after
## [recipient]" topic. The letter is delivered either way (the operative is at the
## destination); the DayOrchestrator writeback creates the LetterData + topic.
static func _deliver_sealed_letter(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var recipient_id: int = int(metadata.get("recipient_id", -1))
	if recipient_id < 0:
		return {"ok": false, "reason": "no_recipient"}
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Sincerity", 10)
	return {
		"ok": true, "delivers_letter": true,
		"recipient_id": recipient_id,
		"payload_topic_id": int(metadata.get("payload_topic_id", -1)),
		"courier_noticed": not bool(roll.get("success", false)),
	}


## ROUTE_ANONYMOUS_INTELLIGENCE (s54.7c). 1 AP, Master Jade. Routes a structured
## threat assessment to a registered jade_asset_network contact (asset_id) through
## anonymous channels. Roll Calligraphy (Cipher) vs TN 15 to encode securely. On
## success the asset's disposition toward Jade's cover persona rises +5 (applied by
## the writeback). Critical failure (margin ≤ -10) leaves a traceable element →
## Tier 4 personal risk topic. The asset / institutional target comes from the
## deferred Jade decomposition as metadata.
static func _route_anonymous_intelligence(actor: L5RCharacterData, metadata: Dictionary, dice: DiceEngine) -> Dictionary:
	var asset_id: int = int(metadata.get("asset_id", -1))
	var org: String = String(metadata.get("tip_org", ""))
	if asset_id < 0 and org.is_empty():
		return {"ok": false, "reason": "no_target"}
	var roll: Dictionary = SkillResolver.resolve_skill_check(actor, dice, "Calligraphy", 15)
	var margin: int = int(roll.get("margin", 0))
	return {
		"ok": true, "routes_anon_intel": true,
		"asset_id": asset_id, "tip_org": org,
		"asset_disposition_gain": 5 if (asset_id >= 0 and bool(roll.get("success", false))) else 0,
		"traceable_failure": margin <= -10,
	}
