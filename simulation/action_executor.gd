class_name ActionExecutor
## Routes chosen ActionIDs to owning systems per GDD s55.4.7.
## Receives a ScoredAction + character + context, performs the skill roll
## (if applicable), applies effects, and returns a result dictionary.
## This is the bridge between NPC decision and world-state mutation.


# -- Action Categories --------------------------------------------------------

const SOCIAL_ACTIONS: Array[String] = [
	"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
	"PROBE", "READ_CHARACTER", "LISTEN_REFLECT", "IMPRESS",
	"PUBLIC_DEBATE", "PUBLIC_INSULT", "PUBLIC_DECLARATION",
	"PUBLIC_PERFORMANCE", "DELIVER_GIFT", "OFFER_FAVOR",
	"PERFORM_FOR", "DISCLOSE", "ASK_FOR_INTRODUCTION",
]

const COVERT_ACTIONS: Array[String] = [
	"BRIBE_FOR_INFO", "EAVESDROP", "INTERCEPT_LETTER",
	"SEARCH_QUARTERS", "FABRICATE_SECRET",
	"SHADOW_TARGET", "CONCEAL_ITEM", "SEARCH_PERSON",
	"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
	"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
	"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
	"EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
]

const MILITARY_ORDERS: Array[String] = [
	"ORDER_LEVY", "ORDER_DEPLOY", "ORDER_FORTIFY", "ORDER_RETREAT",
	"ORDER_BATTLE", "ORDER_PATROL", "ASSIGN_GARRISON",
	"CONDUCT_RAID", "RAID_HARVEST", "CONDUCT_SORTIE",
	"CONDUCT_STORM_ASSAULT", "MAINTAIN_SIEGE", "DRILL_TROOPS",
	"BLOCKADE_TRADE_ROUTE", "ASSIGN_TO_MILITARY_SERVICE",
]

const ADMINISTRATIVE_ACTIONS: Array[String] = [
	"SET_TAX_RATE", "SET_STIPEND_RATE", "PURCHASE_MARKET",
	"SHARE_SUPPLIES", "ASSESS_PROVINCE_STATUS", "EVALUATE_WAR_READINESS",
	"ASSIGN_VASSAL_OBJECTIVE", "CALL_COURT", "SEND_INVITATION",
	"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID", "INVESTIGATE_PROVINCE",
	"INVESTIGATE_RUMOR", "NEGOTIATE_SURRENDER", "CONDUCT_COMMERCE",
	"DISPATCH_COURTIER",
	"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
	"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
	"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION",
	"PURIFY_TAINTED_GROUND", "FORTIFY_WALL_SECTION", "SEAL_WALL_BREACH",
	"DECLARE_WAR",
]

const INTELLIGENCE_ACTIONS: Array[String] = [
	"EXAMINE_CRIME_SCENE",
]

const SELF_ACTIONS: Array[String] = [
	"TRAIN", "MEDITATE", "REST", "DO_NOTHING", "CRAFT",
	"WRITE_LETTER", "PERFORM_RITUAL", "PERFORM_WORSHIP",
	"PUBLIC_ATONEMENT", "MENTOR", "BEGIN_TRAVEL",
	"OBSERVE_COURT_ATTENDEES",
]

const NO_ROLL_ACTIONS: Array[String] = [
	"DO_NOTHING", "REST", "BEGIN_TRAVEL", "CHANGE_DESTINATION",
	"REQUEST_ART", "OFFER_ART_COMMISSION", "DISPLAY_BONSAI",
]

# -- TN Table -----------------------------------------------------------------

const BASE_TN: Dictionary = {
	"trivial": 5,
	"easy": 10,
	"average": 15,
	"hard": 20,
	"very_hard": 25,
	"heroic": 30,
}

const SOCIAL_BASE_TN: int = 15
const COVERT_BASE_TN: int = 20
const MILITARY_BASE_TN: int = 15
const ADMIN_BASE_TN: int = 10


# -- Main Entry Point ---------------------------------------------------------

static func execute(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var action_id: String = action.action_id

	if action_id == "DELIVER_GIFT":
		var gift_result: Dictionary = _try_execute_deliver_gift(
			action, character, ctx, dice_engine, characters_by_id
		)
		if not gift_result.is_empty():
			return gift_result

	if action_id == "PUBLIC_PERFORMANCE":
		return _execute_public_performance(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "PERFORM_FOR":
		return _execute_perform_for(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "INTIMIDATE":
		var intim_result: Dictionary = _execute_intimidation(
			action, character, ctx, dice_engine, characters_by_id
		)
		if not intim_result.is_empty():
			return intim_result

	if action_id == "NEGOTIATE_SURRENDER":
		var peace_effects: Dictionary = _execute_negotiate_surrender(
			action, character, ctx, dice_engine
		)
		return {
			"success": not peace_effects.get("failed", false),
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": peace_effects,
		}

	if action_id == "DECLARE_WAR":
		var war_effects: Dictionary = _execute_declare_war(character, action.metadata)
		return {
			"success": not war_effects.get("failed", false),
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": war_effects,
		}

	if action_id in COVERT_ACTIONS:
		var covert_result: Dictionary = _try_execute_covert(
			action, character, ctx, dice_engine, characters_by_id
		)
		if not covert_result.is_empty():
			return covert_result

	if action_id in MILITARY_ORDERS:
		var mil_check: Dictionary = _validate_military_order(action_id, ctx, military_data)
		if not mil_check.get("valid", false):
			return {
				"success": false,
				"action_id": action_id,
				"character_id": ctx.character_id,
				"target_npc_id": action.target_npc_id,
				"target_province_id": action.target_province_id,
				"ic_day": ctx.ic_day,
				"season": ctx.season,
				"reason": mil_check.get("reason", "hierarchy_invalid"),
				"effects": {},
			}

	if action_id in NO_ROLL_ACTIONS:
		return _execute_no_roll(action, character, ctx)

	var skill_info: Dictionary = action_skill_map.get(action_id, {})
	var primary_skill: String = skill_info.get("primary", "")

	if primary_skill.is_empty() or primary_skill.begins_with("_"):
		return _execute_no_roll(action, character, ctx)

	var tn: int = _get_tn_for_action(action_id, action, ctx)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, primary_skill, tn
	)

	var result: Dictionary = {
		"success": roll_result.get("success", false),
		"action_id": action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": primary_skill,
		"roll_total": roll_result.get("total", 0),
		"tn": tn,
		"margin": roll_result.get("total", 0) - tn,
	}

	_apply_effects(result, action, character, ctx)
	return result


# -- Deliver Gift -------------------------------------------------------------
#
# Returns an empty dict to signal "no gift wired, fall through to generic
# social path". Returns a populated result dict on successful resolution.

static func _try_execute_deliver_gift(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	if action.target_npc_id < 0:
		return {}
	if characters_by_id.is_empty():
		return {}
	var recipient: L5RCharacterData = characters_by_id.get(action.target_npc_id)
	if recipient == null:
		return {}

	var archetype: GiftGivingSystem.RecipientArchetype = (
		GiftGivingSystem.default_archetype_for_school(recipient.school_type)
	)
	var gift_item: Dictionary = GiftGivingSystem.select_best_gift(character.items, archetype)
	if gift_item.is_empty():
		return {}

	var tier: int = gift_item.get("quality_tier", 0)
	var subtype: int = gift_item.get("gift_subtype", -1)

	var gift_result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		character, recipient, tier, subtype, archetype, dice_engine, ctx.ic_day
	)

	var outcome: String = gift_result.get("outcome", "")
	var success: bool = outcome == "success"
	var roll: Dictionary = gift_result.get("roll", {})
	var tn: int = GiftGivingSystem.TN_DELIVER_GIFT

	var effects: Dictionary = {
		"recipient_disposition_change": gift_result.get("disposition_change", 0),
		"recipient_modifiers": gift_result.get("modifiers_to_apply", []),
		"consume_item_id": gift_item.get("item_id", -1),
		"gift_outcome": outcome,
		"gift_tier": tier,
		"gift_subtype": subtype,
		"gift_free_raises": gift_result.get("free_raises_applied", 0),
		# Preserve generic-social effect keys so downstream consumers that read
		# disposition_change uniformly still see something — but for gifts the
		# value lives on the recipient side.
		"disposition_change": 0,
	}
	# Failure paths still apply effects (half disposition, critical loss,
	# forbidden loss). Mark as "failed" so EffectApplicator's early-return
	# guard does not skip the recipient mutation.
	if not success:
		effects["failed"] = true

	return {
		"success": success,
		"action_id": "DELIVER_GIFT",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Etiquette",
		"roll_total": roll.get("total", 0),
		"tn": tn,
		"margin": roll.get("margin", 0),
		"effects": effects,
	}


# -- No-Roll Execution --------------------------------------------------------

static func _execute_no_roll(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var effects: Dictionary = _get_no_roll_effects(action.action_id)

	if action.action_id == "BEGIN_TRAVEL":
		var destination: String = _resolve_travel_destination(action)
		var travel_result: Dictionary = TravelSystem.begin_travel(character, destination)
		effects["travel"] = travel_result
		effects["effect"] = "travel_started" if travel_result.get("started", false) else "travel_failed"
	elif action.action_id == "CHANGE_DESTINATION":
		var destination: String = _resolve_travel_destination(action)
		var travel_result: Dictionary = TravelSystem.change_destination(character, destination)
		effects["travel"] = travel_result
		effects["effect"] = "destination_changed" if travel_result.get("changed", false) else "change_failed"

	return {
		"success": true,
		"action_id": action.action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "",
		"roll_total": 0,
		"tn": 0,
		"margin": 0,
		"effects": effects,
	}


# -- Performative Arts --------------------------------------------------------

static func _execute_public_performance(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var art_form: PerformativeArtsSystem.ArtForm = PerformativeArtsSystem.get_best_art_form(character)
	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)
	var fatigue_count: int = character.pieces_seen.get("_performance_count_today", 0)

	var perf_result: Dictionary = PerformativeArtsSystem.resolve_public_performance(
		character, art_form, witness_ids, dice_engine, fatigue_count
	)

	PerformativeArtsSystem.apply_performance_effects(character, perf_result, characters_by_id)
	character.pieces_seen["_performance_count_today"] = fatigue_count + 1

	var success: bool = perf_result["outcome"] != PerformativeArtsSystem.PerformanceOutcome.FAILURE and \
		perf_result["outcome"] != PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE

	return {
		"success": success,
		"action_id": "PUBLIC_PERFORMANCE",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": perf_result.get("skill_used", ""),
		"roll_total": perf_result.get("roll_total", 0),
		"tn": PerformativeArtsSystem.PERFORMANCE_TN,
		"margin": perf_result.get("margin", 0),
		"effects": {
			"glory_change": perf_result.get("glory_change", 0.0),
			"disposition_change": perf_result.get("disposition_per_witness", 0),
			"witness_count": witness_ids.size(),
			"performance_outcome": perf_result.get("outcome", 0),
			"art_form": art_form,
			"raises": perf_result.get("raises", 0),
			"performance_applied": true,
		},
	}


static func _execute_perform_for(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var art_form: PerformativeArtsSystem.ArtForm = PerformativeArtsSystem.get_best_art_form(character)
	var recipient: L5RCharacterData = characters_by_id.get(action.target_npc_id)

	if recipient == null:
		return _execute_no_roll(action, character, ctx)

	var perf_result: Dictionary = PerformativeArtsSystem.resolve_perform_for(
		character, recipient, art_form, dice_engine
	)

	PerformativeArtsSystem.apply_performance_effects(character, perf_result, characters_by_id)

	var success: bool = perf_result["outcome"] != PerformativeArtsSystem.PerformanceOutcome.FAILURE

	return {
		"success": success,
		"action_id": "PERFORM_FOR",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": perf_result.get("skill_used", ""),
		"roll_total": perf_result.get("roll_total", 0),
		"tn": PerformativeArtsSystem.PERFORMANCE_TN,
		"margin": perf_result.get("margin", 0),
		"effects": {
			"glory_change": perf_result.get("glory_change", 0.0),
			"disposition_change": perf_result.get("disposition_change", 0),
			"recipient_id": action.target_npc_id,
			"performance_outcome": perf_result.get("outcome", 0),
			"art_form": art_form,
			"raises": perf_result.get("raises", 0),
			"performance_applied": true,
		},
	}


# -- Intimidation (s12.9) -----------------------------------------------------

static func _execute_intimidation(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	if action.target_npc_id < 0:
		return {}
	var target: L5RCharacterData = characters_by_id.get(action.target_npc_id)
	if target == null:
		return {}

	var attacker_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Intimidation", 0
	)
	var defender_result: Dictionary = SkillResolver.resolve_skill_check(
		target, dice_engine, "Etiquette", 0
	)
	var attacker_roll: int = attacker_result.get("total", 0)
	var defender_roll: int = defender_result.get("total", 0)

	var disp_toward_target: int = ctx.dispositions.get(action.target_npc_id, 0)
	var disp_tier: String = _get_disposition_tier_name(disp_toward_target)

	var has_secret: bool = action.metadata.get("secret_ref") != null
	var by_letter: bool = action.metadata.get("by_letter", false)
	var is_public: bool = ctx.context_flag == Enums.ContextFlag.AT_COURT

	var r: Dictionary
	if has_secret:
		var secret_tier: int = action.metadata.get("secret_tier", 3)
		r = IntimidationSystem.resolve_blackmail(
			attacker_roll, defender_roll, target.honor, secret_tier, disp_tier
		)
	elif is_public:
		var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)
		r = IntimidationSystem.resolve_public_intimidation(
			attacker_roll, defender_roll, target.honor, 0, witness_ids, disp_tier
		)
	else:
		r = IntimidationSystem.resolve_private_intimidation(
			attacker_roll, defender_roll, target.honor, by_letter, 0, disp_tier
		)

	var effects: Dictionary = {
		"disposition_change": -(3 + clampi(attacker_roll - defender_roll, 0, 25) / 5) if r["success"] else 0,
		"honor_change": r.get("honor_loss", 0.0),
		"infamy_gain": r.get("infamy_gain", 0.0),
		"compliance_active": r.get("compliance_active", false),
	}

	if r.has("witnesses"):
		effects["witnesses"] = r["witnesses"]
		effects["witness_disposition_loss"] = r.get("witness_disposition_loss", 0)

	if r.has("favors_extracted"):
		effects["favors_extracted"] = r["favors_extracted"]

	return {
		"success": r["success"],
		"action_id": "INTIMIDATE",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Intimidation",
		"roll_total": attacker_roll,
		"tn": defender_roll + int(target.honor),
		"margin": attacker_roll - (defender_roll + int(target.honor)),
		"effects": effects,
	}


static func _get_disposition_tier_name(disp: int) -> String:
	if disp >= 91:
		return "devoted"
	if disp >= 61:
		return "sworn"
	if disp >= 31:
		return "ally"
	if disp >= 11:
		return "friend"
	if disp >= -10:
		return "neutral"
	if disp >= -30:
		return "rival"
	if disp >= -60:
		return "enemy"
	return "bitter_enemy"


# -- Covert Actions (s12.8) ---------------------------------------------------

static func _try_execute_covert(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var action_id: String = action.action_id
	var target: L5RCharacterData = characters_by_id.get(action.target_npc_id)

	match action_id:
		"EAVESDROP":
			if target == null:
				return {}
			var r: Dictionary = SecretSystem.resolve_eavesdrop(character, target, dice_engine)
			return _build_covert_result(action, ctx, "Stealth", r)

		"INTERCEPT_LETTER":
			var same_loc: bool = target != null and target.physical_location == character.physical_location
			var r: Dictionary = SecretSystem.resolve_intercept_letter(character, dice_engine, same_loc)
			return _build_covert_result(action, ctx, "Stealth", r)

		"SEARCH_QUARTERS":
			if target == null:
				return {}
			var r: Dictionary = SecretSystem.resolve_search_quarters(character, target, dice_engine)
			return _build_covert_result(action, ctx, "Stealth", r)

		"SHADOW_TARGET":
			if target == null:
				return {}
			var r: Dictionary = SecretSystem.resolve_shadow_target(character, target, dice_engine)
			return _build_covert_result(action, ctx, "Stealth", r)

		"CONCEAL_ITEM":
			var item_size: String = action.metadata.get("item_size", "MEDIUM")
			var is_weapon: bool = action.metadata.get("is_weapon", false)
			var r: Dictionary = SecretSystem.resolve_conceal_item(character, item_size, is_weapon, dice_engine)
			return _build_covert_result(action, ctx, "Sleight of Hand", r)

		"SEARCH_PERSON":
			if target == null:
				return {}
			var concealment_tn: int = action.metadata.get("concealment_tn", 15)
			var has_authority: bool = action.metadata.get("magistrate_authority", false)
			var r: Dictionary = SecretSystem.resolve_search_person(character, target, concealment_tn, dice_engine, has_authority)
			return _build_covert_result(action, ctx, "Investigation", r)

		"FORGE_IMPERSONATION_LETTER":
			var auth_level: String = action.metadata.get("authority_level", "minor")
			var r: Dictionary = SecretSystem.resolve_forge_impersonation_letter(character, auth_level, dice_engine)
			return _build_covert_result(action, ctx, "Forgery", r)

		"FORGE_ORDER":
			var auth_level: String = action.metadata.get("authority_level", "minor")
			var r: Dictionary = SecretSystem.resolve_forge_order(character, auth_level, dice_engine)
			return _build_covert_result(action, ctx, "Forgery", r)

		"FABRICATE_SECRET":
			var severity: SecretData.Severity = action.metadata.get("severity", SecretData.Severity.TIER_3)
			var secret_id: int = action.metadata.get("secret_id", -1)
			var r: Dictionary = SecretSystem.fabricate_secret(character, action.target_npc_id, severity, secret_id, dice_engine)
			return _build_covert_result(action, ctx, "Forgery", r)

		"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS", \
		"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE":
			if target == null:
				return {}
			var variant: SeductionSystem.SeductionVariant = _get_seduction_variant(action_id)
			var r: Dictionary = SeductionSystem.resolve_seduction(character, target, variant, dice_engine)
			return _build_covert_result(action, ctx, "Temptation", r)

		"EXPOSE_SECRET_PRIVATELY":
			return _execute_expose_privately(action, character, ctx, dice_engine, characters_by_id)

		"EXPOSE_SECRET_PUBLICLY":
			return _execute_expose_publicly(action, character, ctx, dice_engine, characters_by_id)

	return {}


static func _build_covert_result(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
	skill_used: String,
	system_result: Dictionary,
) -> Dictionary:
	var success: bool = system_result.get("success", false)
	var effects: Dictionary = system_result.duplicate()
	effects["detection_risk"] = system_result.get("detection_risk", not success)

	return {
		"success": success,
		"action_id": action.action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": skill_used,
		"roll_total": system_result.get("roll_total", system_result.get("eavesdropper_total", system_result.get("shadow_total", 0))),
		"tn": system_result.get("tn", 0),
		"margin": system_result.get("margin", 0),
		"effects": effects,
	}


static func _get_seduction_variant(action_id: String) -> SeductionSystem.SeductionVariant:
	match action_id:
		"SEDUCE_FOR_INFO":
			return SeductionSystem.SeductionVariant.SEDUCE_FOR_INFO
		"SEDUCE_FOR_ACCESS":
			return SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS
		"SEDUCE_FOR_LEVERAGE":
			return SeductionSystem.SeductionVariant.SEDUCE_FOR_LEVERAGE
		"SEDUCE_TO_COMPROMISE":
			return SeductionSystem.SeductionVariant.SEDUCE_TO_COMPROMISE
		_:
			return SeductionSystem.SeductionVariant.SEDUCE


static func _execute_expose_privately(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	_dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var recipient: L5RCharacterData = characters_by_id.get(action.target_npc_id)
	if recipient == null:
		return {}

	var subject_id: int = action.metadata.get("subject_id", -1)
	var subject: L5RCharacterData = characters_by_id.get(subject_id)
	if subject == null:
		return {}

	var secret: SecretData = action.metadata.get("secret_ref")
	if secret == null:
		return {}

	var has_proof: bool = action.metadata.get("has_proof", false)
	var r: Dictionary = SecretSystem.reveal_privately(secret, character, recipient, subject, has_proof)

	return {
		"success": true,
		"action_id": "EXPOSE_SECRET_PRIVATELY",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "",
		"roll_total": 0,
		"tn": 0,
		"margin": 0,
		"effects": r,
	}


static func _execute_expose_publicly(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	_dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var subject_id: int = action.metadata.get("subject_id", -1)
	var subject: L5RCharacterData = characters_by_id.get(subject_id)
	if subject == null:
		return {}

	var secret: SecretData = action.metadata.get("secret_ref")
	if secret == null:
		return {}

	var has_proof: bool = action.metadata.get("has_proof", false)
	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)
	var r: Dictionary = SecretSystem.expose_publicly(secret, character, subject, witness_ids, characters_by_id, has_proof)

	return {
		"success": true,
		"action_id": "EXPOSE_SECRET_PUBLICLY",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "",
		"roll_total": 0,
		"tn": 0,
		"margin": 0,
		"effects": r,
	}


static func _get_co_located_ids(
	character: L5RCharacterData,
	characters_by_id: Dictionary,
) -> Array[int]:
	var ids: Array[int] = []
	var loc: String = character.physical_location
	if loc.is_empty():
		return ids
	for id in characters_by_id:
		var c: L5RCharacterData = characters_by_id[id]
		if c.character_id != character.character_id and c.physical_location == loc:
			ids.append(c.character_id)
	return ids


# -- TN Calculation -----------------------------------------------------------

static func _get_tn_for_action(
	action_id: String,
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	if action_id in SOCIAL_ACTIONS:
		return _get_social_tn(action, ctx)
	if action_id in COVERT_ACTIONS:
		return COVERT_BASE_TN
	if action_id in MILITARY_ORDERS:
		return MILITARY_BASE_TN
	if action_id in ADMINISTRATIVE_ACTIONS:
		return ADMIN_BASE_TN
	if action_id in INTELLIGENCE_ACTIONS:
		return SOCIAL_BASE_TN
	return SOCIAL_BASE_TN


static func _get_social_tn(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var tn: int = SOCIAL_BASE_TN
	var target_disp: int = ctx.dispositions.get(action.target_npc_id, 0)

	if target_disp <= -60:
		tn += 15
	elif target_disp <= -30:
		tn += 10
	elif target_disp <= -10:
		tn += 5
	elif target_disp >= 61:
		tn -= 10
	elif target_disp >= 31:
		tn -= 5

	return maxi(tn, 5)


# -- Effect Application -------------------------------------------------------

static func _apply_effects(
	result: Dictionary,
	action: NPCDataStructures.ScoredAction,
	_character: L5RCharacterData,
	_ctx: NPCDataStructures.ContextSnapshot,
) -> void:
	var effects: Dictionary = {}
	var action_id: String = action.action_id

	if result["success"]:
		if action_id in SOCIAL_ACTIONS:
			effects = _compute_social_effects(action_id, result["margin"])
		elif action_id in COVERT_ACTIONS:
			effects = _compute_covert_effects(action_id, result["margin"])
		elif action_id in MILITARY_ORDERS:
			effects = _compute_military_effects(action_id)
		elif action_id in ADMINISTRATIVE_ACTIONS:
			effects = _compute_admin_effects(action_id)
		elif action_id in INTELLIGENCE_ACTIONS:
			effects = _compute_intelligence_effects(action_id, result.get("margin", 0))
		else:
			effects = _compute_self_effects(action_id)
	else:
		effects = _compute_failure_effects(action_id)

	result["effects"] = effects


static func _compute_social_effects(action_id: String, margin: int) -> Dictionary:
	var disp_change: int = 0
	var glory_change: float = 0.0
	var info_gained: bool = false

	match action_id:
		"CHARM", "DELIVER_GIFT", "OFFER_FAVOR", "LISTEN_REFLECT":
			disp_change = 3 + clampi(margin / 5, 0, 5)
		"PERSUADE", "NEGOTIATE":
			disp_change = 2 + clampi(margin / 5, 0, 3)
		"INTIMIDATE":
			disp_change = -(3 + clampi(margin / 5, 0, 5))
		"GOSSIP":
			info_gained = true
			disp_change = 1
		"PROBE", "READ_CHARACTER":
			info_gained = true
		"PUBLIC_DEBATE", "PUBLIC_DECLARATION", "PUBLIC_PERFORMANCE":
			glory_change = 0.1
			disp_change = 1
		"PUBLIC_INSULT":
			disp_change = -5
			glory_change = 0.05
		"IMPRESS":
			disp_change = 2
			glory_change = 0.05
		"ASK_FOR_INTRODUCTION":
			info_gained = true
		"DISCLOSE":
			disp_change = 2
			info_gained = true
		"PERFORM_FOR":
			disp_change = 2
			glory_change = 0.05

	return {
		"disposition_change": disp_change,
		"glory_change": glory_change,
		"info_gained": info_gained,
	}


static func _compute_covert_effects(action_id: String, margin: int) -> Dictionary:
	var info_gained: bool = true
	var detection_risk: bool = margin < 5

	match action_id:
		"BRIBE_FOR_INFO":
			detection_risk = false
		"FABRICATE_SECRET":
			info_gained = false

	return {
		"info_gained": info_gained,
		"detection_risk": detection_risk,
		"quality": clampi(margin / 5, 1, 5),
	}


static func _compute_military_effects(action_id: String) -> Dictionary:
	match action_id:
		"ORDER_LEVY":
			return {
				"effect": "levy_raised",
				"requires_levy_pu": true,
			}
		"ORDER_DEPLOY":
			return {"effect": "unit_deployed"}
		"ORDER_FORTIFY":
			return {"effect": "fortification_improved"}
		"ORDER_RETREAT":
			return {"effect": "retreat_ordered"}
		"ORDER_BATTLE":
			return {
				"effect": "battle_initiated",
				"requires_battle_resolution": true,
			}
		"ORDER_PATROL":
			return {"effect": "patrol_dispatched"}
		"ASSIGN_GARRISON":
			return {"effect": "garrison_assigned"}
		"DRILL_TROOPS":
			return {"effect": "training_bonus"}
		"CONDUCT_RAID":
			return {"effect": "raid_executed"}
		"RAID_HARVEST":
			return _compute_harvest_destruction_effects(action)
		"CONDUCT_SORTIE":
			return {"effect": "sortie_executed"}
		"CONDUCT_STORM_ASSAULT":
			return {"effect": "assault_executed"}
		"MAINTAIN_SIEGE":
			return {"effect": "siege_maintained"}
		"BLOCKADE_TRADE_ROUTE":
			return _compute_blockade_effects(action)
		"ASSIGN_TO_MILITARY_SERVICE":
			return {
				"effect": "service_assigned",
				"requires_service_assignment": true,
			}
	return {"effect": "military_order_issued"}


static func _compute_admin_effects(action_id: String) -> Dictionary:
	match action_id:
		"SET_TAX_RATE", "SET_STIPEND_RATE":
			return {"effect": "rate_adjusted"}
		"PURCHASE_MARKET":
			return {"effect": "transaction_completed"}
		"SHARE_SUPPLIES":
			return {
				"effect": "supplies_shared",
				"requires_supply_sharing": true,
			}
		"ASSESS_PROVINCE_STATUS", "INVESTIGATE_PROVINCE", "INVESTIGATE_RUMOR":
			return {"effect": "intelligence_gathered", "info_gained": true}
		"EVALUATE_WAR_READINESS":
			return {"effect": "readiness_assessed", "info_gained": true}
		"CONDUCT_COMMERCE":
			return {"effect": "commerce_conducted"}
		"NEGOTIATE_SURRENDER":
			return {"effect": "surrender_negotiated"}
		"DEMAND_TRIBUTE":
			return {"effect": "tribute_demanded"}
		"REQUEST_ALLIED_AID":
			return {"effect": "aid_requested"}
		"FOUND_VILLAGE":
			return {"effect": "village_founded"}
		"BUILD_FORTIFICATION":
			return {"effect": "fortification_ordered"}
		"BUILD_SHRINE":
			return {"effect": "shrine_built"}
		"FOUND_TEMPLE", "FOUND_MONASTERY":
			return {"effect": "religious_site_founded"}
		"COMMISSION_SHIP":
			return {"effect": "ship_commissioned"}
		"ARRANGE_MARRIAGE":
			return {"effect": "marriage_proposed"}
		"APPOINT_TO_POSITION":
			return {"effect": "position_filled"}
		"PURIFY_TAINTED_GROUND":
			return {"effect": "taint_purified"}
		"FORTIFY_WALL_SECTION":
			return {"effect": "wall_fortified"}
		"SEAL_WALL_BREACH":
			return {"effect": "breach_sealed"}
	return {"effect": "administrative_action"}


static func _compute_self_effects(action_id: String) -> Dictionary:
	match action_id:
		"TRAIN":
			return {"effect": "skill_practiced"}
		"MEDITATE":
			return {"effect": "void_point_recovered"}
		"CRAFT":
			return {"effect": "item_progress"}
		"WRITE_LETTER":
			return {"effect": "letter_sent"}
		"PERFORM_RITUAL", "PERFORM_WORSHIP":
			return {"effect": "ritual_completed", "honor_change": 0.1}
		"PUBLIC_ATONEMENT":
			return {"effect": "atonement_performed", "honor_change": 0.5}
		"MENTOR":
			return {"effect": "student_trained"}
		"OBSERVE_COURT_ATTENDEES":
			return {"effect": "court_observed", "info_gained": true}
	return {"effect": "self_action_completed"}


static func _compute_failure_effects(action_id: String) -> Dictionary:
	var effects: Dictionary = {"failed": true}
	if action_id in SOCIAL_ACTIONS:
		effects["disposition_change"] = -1
	if action_id == "PUBLIC_INSULT" or action_id == "PUBLIC_DEBATE":
		effects["glory_change"] = -0.05
	if action_id in COVERT_ACTIONS:
		effects["detection_risk"] = true
	return effects


static func _get_no_roll_effects(action_id: String) -> Dictionary:
	match action_id:
		"DO_NOTHING":
			return {"effect": "nothing"}
		"REST":
			return {"effect": "rested"}
		"BEGIN_TRAVEL", "CHANGE_DESTINATION":
			return {"effect": "travel_started"}
	return {"effect": "completed"}


# -- Military Hierarchy Validation (s57.21) ------------------------------------

static func _validate_military_order(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
	military_data: Dictionary,
) -> Dictionary:
	if ctx.commanded_unit_id < 0:
		return {"valid": false, "reason": "no_commanded_unit"}

	if military_data.is_empty():
		return {"valid": true}

	var companies: Dictionary = military_data.get("companies", {})
	var legions: Dictionary = military_data.get("legions", {})

	if ctx.military_rank == Enums.MilitaryRank.CHUI:
		var company: MilitaryUnitData.CompanyData = MilitaryHierarchy.get_company(
			companies, ctx.commanded_unit_id
		)
		if company == null:
			return {"valid": false, "reason": "unit_not_found"}
		if company.deployment_status == Enums.DeploymentStatus.GARRISONED:
			if action_id in ["ORDER_BATTLE", "CONDUCT_RAID", "RAID_HARVEST", "CONDUCT_SORTIE"]:
				return {"valid": false, "reason": "unit_garrisoned"}

	if ctx.military_rank >= Enums.MilitaryRank.TAISA:
		if not legions.is_empty():
			var legion: MilitaryUnitData.LegionData = legions.get(ctx.commanded_unit_id)
			if legion != null and not MilitaryHierarchy.can_legion_coordinate(legion):
				if action_id in ["ORDER_BATTLE", "CONDUCT_RAID"]:
					return {"valid": false, "reason": "legion_no_coordinator"}

	if ctx.military_rank >= Enums.MilitaryRank.SHIREIKAN:
		var sections: Dictionary = military_data.get("sections", {})
		if not sections.is_empty():
			var section: MilitaryUnitData.SectionData = sections.get(ctx.commanded_unit_id)
			if section != null and not MilitaryHierarchy.can_section_initiate_campaign(section):
				if action_id in ["ORDER_BATTLE", "CONDUCT_RAID"]:
					return {"valid": false, "reason": "section_no_commander"}

	return {"valid": true}


# -- Intelligence Effects (s57.15) --------------------------------------------

static func _compute_intelligence_effects(action_id: String, margin: int) -> Dictionary:
	match action_id:
		"EXAMINE_CRIME_SCENE":
			var raises: int = margin / 5
			var evidence: int = InvestigationSystem.EVIDENCE_BASE_WEIGHT \
				+ (raises * InvestigationSystem.EVIDENCE_PER_RAISE)
			return {
				"effect": "scene_examined",
				"info_gained": true,
				"evidence_gained": evidence,
				"raises": raises,
			}
	return {"effect": "intelligence_action"}


# -- Travel Destination Resolution (s55.29) -----------------------------------

static func _resolve_travel_destination(
	action: NPCDataStructures.ScoredAction,
) -> String:
	if action.target_settlement_id >= 0:
		return str(action.target_settlement_id)
	if action.target_province_id >= 0:
		return str(action.target_province_id)
	return ""


# -- War Termination (s53) -----------------------------------------------------

static func _execute_negotiate_surrender(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var war: WarData = action.metadata.get("war_ref") as WarData

	if war == null:
		return {"failed": true, "reason": "no_active_war"}

	var own_clan: String = character.clan
	var enemy_clan: String = WarTermination._get_opponent_clan(war, own_clan)
	if enemy_clan.is_empty():
		return {"failed": true, "reason": "not_a_combatant"}

	var target_virtue: String = action.metadata.get("target_virtue", "")
	var hostage_held: bool = action.metadata.get("hostage_held", false)
	var superior_pressuring: bool = action.metadata.get("superior_pressuring", false)

	var ctx_war: Dictionary = {
		"war": war,
		"own_clan": own_clan,
		"enemy_clan": enemy_clan,
	}

	return WarTermination.resolve_negotiate_surrender(
		character, ctx_war, target_virtue,
		hostage_held, superior_pressuring, dice_engine,
	)


# -- War Declaration (s53.1) ---------------------------------------------------

static func _execute_declare_war(
	character: L5RCharacterData,
	metadata: Dictionary,
) -> Dictionary:
	var standing_objective: String = metadata.get("standing_objective", "")
	var primary_objective: String = metadata.get("primary_objective", "")
	var intended_tier: int = metadata.get(
		"intended_tier", WarJustification.MilitaryTier.RAID,
	)
	var primary_virtue: String = metadata.get("primary_virtue", "")
	if primary_virtue.is_empty():
		primary_virtue = _get_primary_virtue_name(character)

	var target_garrison_min: bool = metadata.get("target_garrison_at_minimum", false)
	var no_field_army: bool = metadata.get("no_field_army_nearby", false)
	var no_alliance: bool = metadata.get("no_alliance_protection", false)
	var attacker_pu: float = metadata.get("attacker_pu", 0.0)
	var defender_pu: float = metadata.get("defender_observable_pu", 0.0)

	var feasibility_inputs: Dictionary = metadata.get("feasibility_inputs", {})

	var justification: Dictionary = WarJustification.evaluate_war_justification(
		standing_objective, primary_objective, intended_tier, primary_virtue,
		target_garrison_min, no_field_army, no_alliance, attacker_pu, defender_pu,
		feasibility_inputs,
	)

	if not justification.get("justified", false):
		return {
			"effect": "war_declaration_rejected",
			"failed": true,
			"reason": justification.get("reason", "unknown"),
			"step_failed": justification.get("step_failed", 0),
		}

	var target_clan: String = metadata.get("target_clan", "")
	var authority_level: int = metadata.get(
		"authority_level", WarData.AuthorityLevel.PROVINCIAL_RAID,
	)

	var honor: float = -0.5 if intended_tier == WarJustification.MilitaryTier.TOTAL_WAR else 0.0
	var ladder_effects: Dictionary = justification.get("ladder_side_effects", {})
	if ladder_effects.has("honor_cost"):
		honor += ladder_effects["honor_cost"]

	var result: Dictionary = {
		"effect": "war_declared",
		"requires_war_creation": true,
		"declaring_clan": character.clan,
		"target_clan": target_clan,
		"authority_level": authority_level,
		"declaring_lord_id": character.character_id,
		"intended_tier": intended_tier,
		"personality_driven": justification.get("personality_driven", false),
		"honor_change": honor,
	}

	if justification.has("ladder_outcome"):
		result["ladder_outcome"] = justification["ladder_outcome"]
		result["ladder_side_effects"] = ladder_effects

	return result


const _BUSHIDO_NAMES: Dictionary = {
	Enums.BushidoVirtue.JIN: "Jin",
	Enums.BushidoVirtue.YU: "Yu",
	Enums.BushidoVirtue.REI: "Rei",
	Enums.BushidoVirtue.CHUGI: "Chugi",
	Enums.BushidoVirtue.GI: "Gi",
	Enums.BushidoVirtue.MEIYO: "Meiyo",
	Enums.BushidoVirtue.MAKOTO: "Makoto",
}

const _SHOURIDO_NAMES: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: "Seigyo",
	Enums.ShouridoVirtue.KETSUI: "Ketsui",
	Enums.ShouridoVirtue.DOSATSU: "Dosatsu",
	Enums.ShouridoVirtue.CHISHIKI: "Chishiki",
	Enums.ShouridoVirtue.KANPEKI: "Kanpeki",
	Enums.ShouridoVirtue.ISHI: "Ishi",
	Enums.ShouridoVirtue.KYORYOKU: "Kyoryoku",
}


static func _get_primary_virtue_name(character: L5RCharacterData) -> String:
	if _BUSHIDO_NAMES.has(character.bushido_virtue):
		return _BUSHIDO_NAMES[character.bushido_virtue]
	if _SHOURIDO_NAMES.has(character.shourido_virtue):
		return _SHOURIDO_NAMES[character.shourido_virtue]
	return ""


# -- Harvest Destruction & Blockade Effects ------------------------------------

static func _compute_harvest_destruction_effects(action: NPCDataStructures.ScoredAction) -> Dictionary:
	var province_id: int = action.metadata.get("target_province_id", action.target_province_id)
	var target_clan: String = action.metadata.get("target_clan", "")
	var ordering_clan: String = action.metadata.get("ordering_clan", "")
	var result: Dictionary = StarvationWarfare.execute_harvest_destruction(
		province_id, ordering_clan, target_clan,
	)
	result["effect"] = "harvest_destroyed"
	result["requires_harvest_destruction"] = true
	return result


static func _compute_blockade_effects(action: NPCDataStructures.ScoredAction) -> Dictionary:
	var route_id: int = action.metadata.get("route_id", -1)
	var blocking_clan: String = action.metadata.get("blocking_clan", "")
	var target_clan: String = action.metadata.get("target_clan", "")
	var result: Dictionary = StarvationWarfare.execute_blockade(
		route_id, blocking_clan, target_clan,
	)
	result["effect"] = "route_blocked"
	result["requires_blockade"] = true
	return result
