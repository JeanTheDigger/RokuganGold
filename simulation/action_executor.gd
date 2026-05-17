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
	"PROVOKE_EMOTION", "PLAY_GAME", "DISCERN_NEED",
]

const COVERT_ACTIONS: Array[String] = [
	"BRIBE_FOR_INFO", "EAVESDROP", "INTERCEPT_LETTER",
	"SEARCH_QUARTERS", "FABRICATE_SECRET",
	"SHADOW_TARGET", "CONCEAL_ITEM", "SEARCH_PERSON",
	"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
	"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
	"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
	"EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
	"BRIBE_WITNESS", "INTIMIDATE_WITNESS", "KILL_WITNESS",
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
	"COMPLY_WITH_EDICT", "DEFY_EDICT",
	"RESTORE_COUNCIL_COMPACT",
]

const INTELLIGENCE_ACTIONS: Array[String] = []

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
	worship_province_malus: Dictionary = {},
	doshin_bonus: int = 0,
	crime_records: Array[CrimeRecord] = [],
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

	if action_id == "PUBLIC_DEBATE":
		return _execute_public_debate(action, character, ctx, dice_engine, action_skill_map, characters_by_id)

	if action_id == "PUBLIC_DECLARATION":
		return _execute_broadcast_social(action, character, ctx, dice_engine, action_skill_map, characters_by_id)

	if action_id == "GOSSIP":
		return _execute_gossip(action, character, ctx, dice_engine, action_skill_map, characters_by_id)

	if action_id == "PUBLIC_INSULT":
		return _execute_public_insult(action, character, ctx, dice_engine, action_skill_map, characters_by_id)

	if action_id == "INTIMIDATE":
		var intim_result: Dictionary = _execute_intimidation(
			action, character, ctx, dice_engine, characters_by_id
		)
		if not intim_result.is_empty():
			return intim_result

	if action_id in _CONTESTED_COURT_ACTIONS:
		return _execute_contested_court_action(
			action, character, ctx, dice_engine, action_skill_map, characters_by_id
		)

	if action_id == "PROVOKE_EMOTION":
		return _execute_provoke_emotion(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "PLAY_GAME":
		return _execute_play_game(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "DISCERN_NEED":
		return _execute_discern_need(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "READ_CHARACTER":
		return _execute_read_character(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "PROBE":
		return _execute_probe(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "ASK_FOR_INTRODUCTION":
		return _execute_ask_for_introduction(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "OBSERVE_COURT_ATTENDEES":
		return _execute_observe_court_attendees(action, character, ctx, dice_engine, characters_by_id)

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

	if action_id in _CONSTRUCTION_ACTIONS:
		return _execute_construction(action, character, ctx)

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

	if action_id == "ISSUE_DUEL_CHALLENGE":
		return _execute_duel_challenge(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "COMPLY_WITH_EDICT" or action_id == "DEFY_EDICT":
		var compliant: bool = action_id == "COMPLY_WITH_EDICT"
		var edict_id: int = action.metadata.get("edict_id", -1)
		var target_clan: String = action.metadata.get("target_clan", character.clan)
		return {
			"success": true,
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"requires_edict_compliance": true,
				"edict_id": edict_id,
				"clan": target_clan,
				"compliant": compliant,
			},
		}

	if action_id == "DISPATCH_COURTIER":
		return _execute_dispatch_courtier(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "APPOINT_TO_POSITION":
		return _execute_appoint_to_position(action, character, ctx)

	if action_id == "ARRANGE_MARRIAGE":
		return _execute_arrange_marriage(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "PERFORM_WORSHIP":
		return _execute_perform_worship(action, character, ctx, dice_engine)

	if action_id == "SCOUT_ENEMY":
		return _execute_scout_enemy(action, character, ctx, dice_engine)

	if action_id == "CONDUCT_SORTIE":
		return _execute_conduct_sortie(action, character, ctx)

	if action_id == "CONDUCT_STORM_ASSAULT":
		return _execute_conduct_storm_assault(action, character, ctx)

	if action_id == "FORTIFY_WALL_SECTION":
		return _execute_fortify_wall_section(action, character, ctx, dice_engine)

	if action_id == "SEAL_WALL_BREACH":
		return _execute_seal_wall_breach(action, character, ctx, dice_engine)

	if action_id == "PURIFY_TAINTED_GROUND":
		return _execute_purify_tainted_ground(action, character, ctx, dice_engine)

	if action_id == "FLEE_JURISDICTION":
		return _execute_flee_jurisdiction(action, character, ctx)

	if action_id == "EXTORT_ACCUSED":
		return _execute_extort_accused(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "EXAMINE_CRIME_SCENE":
		return _execute_examine_crime_scene(action, character, ctx, dice_engine, crime_records)

	if action_id == "EXAMINE_LETTER":
		return _execute_examine_letter(action, character, ctx)

	if action_id == "RESTORE_COUNCIL_COMPACT":
		return {
			"success": true,
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"requires_compact_restoration": true,
				"restoring_champion_id": character.character_id,
			},
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

	if action_id == "PUBLIC_ATONEMENT":
		var offense_key: String = action.metadata.get("offense_key", "")
		if not offense_key.is_empty() and not HonorGlorySystem.can_atone(character, offense_key):
			return {
				"success": false,
				"action_id": action_id,
				"character_id": ctx.character_id,
				"target_npc_id": -1,
				"target_province_id": -1,
				"ic_day": ctx.ic_day,
				"season": ctx.season,
				"reason": "already_atoned",
				"effects": {},
			}

	if action_id in NO_ROLL_ACTIONS:
		return _execute_no_roll(action, character, ctx)

	var skill_info: Dictionary = action_skill_map.get(action_id, {})
	var primary_skill: String = skill_info.get("primary", "")

	if primary_skill.is_empty() or primary_skill.begins_with("_"):
		return _execute_no_roll(action, character, ctx)

	var tn: int = _get_tn_for_action(action_id, action, ctx, worship_province_malus, character)
	var wc_bonus: int = _get_winter_court_skill_bonus(character, primary_skill, ctx)
	var doshin_flat: int = _get_doshin_bonus(action_id, doshin_bonus)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, primary_skill, tn, 0, "", Enums.Trait.NONE, 0, 0, wc_bonus + doshin_flat
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
			"glory_change": 0.0,  # Already applied by PerformativeArtsSystem
			"disposition_change": 0,  # Already applied by PerformativeArtsSystem
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
			"glory_change": 0.0,  # Already applied by PerformativeArtsSystem
			"disposition_change": 0,  # Already applied by PerformativeArtsSystem
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

	var target_disp_toward_actor: int = target.disposition_values.get(character.character_id, 0)
	var disp_tier: String = _get_disposition_tier_name(target_disp_toward_actor)

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
		"disposition_change": -(3 + int(clampi(attacker_roll - defender_roll, 0, 25) / 5)) if r["success"] else 0,
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
		return "trusted_ally"
	if disp >= 31:
		return "friend"
	if disp >= 11:
		return "acquaintance"
	if disp >= -10:
		return "stranger"
	if disp >= -30:
		return "rival"
	if disp >= -60:
		return "enemy"
	return "blood_enemy"


# -- GOSSIP (s15.4 Category 3) ------------------------------------------------

static func _execute_gossip(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var listener_id: int = action.target_npc_id
	var subject_id: int = action.metadata.get("gossip_subject_id", -1)

	var subject: L5RCharacterData = characters_by_id.get(subject_id)
	var subject_glory: float = subject.glory if subject != null else 0.0

	var tn: int = clampi(
		10 + int(subject_glory) * 5 - int(character.glory) * 5,
		5, 60
	)

	var skill_entry: Dictionary = action_skill_map.get("GOSSIP", {})
	var primary_skill: String = skill_entry.get("primary", "Courtier")
	var primary_trait: String = skill_entry.get("secondary", "Awareness")
	var skill_rank: int = character.skills.get(primary_skill, 0)
	var trait_val: int = character.traits.get(primary_trait, 2)
	var roll_result: Dictionary = dice_engine.roll_skill_check(
		trait_val, skill_rank, tn
	)

	var roll_total: int = roll_result.get("total", 0)
	var margin: int = roll_total - tn
	var total_raises: int = maxi(int(margin / 5.0), 0)
	var damage_raises: int = action.metadata.get("damage_raises", total_raises)
	var concealment_raises: int = action.metadata.get("concealment_raises", 0)
	if damage_raises + concealment_raises > total_raises:
		damage_raises = total_raises
		concealment_raises = 0

	var resolution: Dictionary = CourtActionSystem.resolve_gossip(
		roll_total, tn, damage_raises, concealment_raises
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["gossip_subject_id"] = subject_id
		effects["gossip_subject_disposition"] = resolution["gossip_subject_disposition"]
		effects["info_gained"] = true
		var is_bayushi: bool = character.school.begins_with("Bayushi Courtier")
		effects["source_concealed"] = resolution.get("source_concealed", false) or is_bayushi
		effects["concealment_depth"] = resolution.get("concealment_depth", 0)
	else:
		effects["failed"] = true
		if resolution.has("disposition_change"):
			effects["disposition_change"] = resolution["disposition_change"]

	return {
		"success": resolution.get("success", false),
		"action_id": "GOSSIP",
		"character_id": ctx.character_id,
		"target_npc_id": listener_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": primary_skill,
		"roll_total": roll_total,
		"tn": tn,
		"margin": margin,
		"effects": effects,
	}


# -- PUBLIC_INSULT (s15.4 Category 4) ----------------------------------------

static func _execute_public_insult(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var skill_entry: Dictionary = action_skill_map.get("PUBLIC_INSULT", {})
	var primary_skill: String = skill_entry.get("primary", "Courtier")
	var primary_trait: String = skill_entry.get("secondary", "Awareness")
	var skill_rank: int = character.skills.get(primary_skill, 0)
	var trait_val: int = character.traits.get(primary_trait, 2)

	var attacker_total: int = dice_engine.roll_skill_check(
		trait_val, skill_rank, 0
	).get("total", 0)

	var defender_total: int = 0
	if target != null:
		var def_etiquette: int = target.skills.get("Etiquette", 0)
		var def_awareness: int = target.traits.get("Awareness", 2)
		defender_total = dice_engine.roll_skill_check(
			def_awareness, def_etiquette, 0
		).get("total", 0)

	var success: bool = attacker_total >= defender_total
	var margin: int = attacker_total - defender_total
	var raises: int = maxi(int(margin / 5.0), 0)
	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)

	var effects: Dictionary = {}
	if success:
		var per_witness_disp: int = -2 - raises
		effects = {
			"target_witness_disposition": per_witness_disp,
			"witnesses": witness_ids,
		}
	else:
		var backfire_disp: int = -2
		effects = {
			"failed": true,
			"witness_disposition_loss": backfire_disp,
			"witnesses": witness_ids,
		}
		if margin <= -10:
			effects["glory_change"] = -0.05

	return {
		"success": success,
		"action_id": "PUBLIC_INSULT",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": primary_skill,
		"roll_total": attacker_total,
		"tn": defender_total,
		"margin": margin,
		"effects": effects,
	}


# -- Broadcast Social Actions (s12.2 Category 2) ------------------------------

static func _execute_broadcast_social(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var action_id: String = action.action_id
	var skill_entry: Dictionary = action_skill_map.get(action_id, {})
	var primary_skill: String = skill_entry.get("primary", "Courtier")
	var tn: int = _get_social_tn(action, ctx, character)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, primary_skill, tn
	)

	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("total", 0) - tn
	var raises: int = maxi(int(margin / 5.0), 0)
	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)

	var effects: Dictionary = {}
	if success:
		var per_witness_disp: int = 2 + raises
		var glory_change: float = 0.0
		if action_id == "PUBLIC_DEBATE":
			glory_change = 0.3 if raises >= 3 else 0.0
		elif action_id == "PUBLIC_DECLARATION":
			glory_change = 0.1
		effects = {
			"witness_disposition_gain": per_witness_disp,
			"witnesses": witness_ids,
			"glory_change": glory_change,
		}
	else:
		effects = {"failed": true}
		if margin <= -10:
			effects["witness_disposition_loss"] = -2
			effects["witnesses"] = witness_ids

	return {
		"success": success,
		"action_id": action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": primary_skill,
		"roll_total": roll_result.get("total", 0),
		"tn": tn,
		"margin": margin,
		"effects": effects,
	}


# -- PUBLIC_DEBATE per-witness (s15.4 Category 4) -----------------------------

static func _execute_public_debate(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var skill_entry: Dictionary = action_skill_map.get("PUBLIC_DEBATE", {})
	var primary_skill: String = skill_entry.get("primary", "Courtier")
	var a_trait_name: String = skill_entry.get("secondary", "Awareness")
	var a_skill_rank: int = character.skills.get(primary_skill, 0)
	var a_trait_val: int = character.traits.get(a_trait_name, 2)
	var a_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var b_roll: int = 0
	if target != null:
		var b_courtier: int = target.skills.get("Courtier", 0)
		var b_awareness: int = target.traits.get("Awareness", 2)
		b_roll = dice_engine.roll_skill_check(
			b_awareness, b_courtier, 0
		).get("total", 0)

	var margin: int = a_roll - b_roll
	var raises: int = maxi(int(margin / 5.0), 0) if margin > 0 else 0
	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)

	var witness_disp_a: Dictionary = {}
	var witness_disp_b: Dictionary = {}
	for wid: int in witness_ids:
		var w: L5RCharacterData = characters_by_id.get(wid)
		if w != null:
			var w_disp_a: int = w.disposition_values.get(character.character_id, 0)
			var w_disp_b: int = w.disposition_values.get(target_id, 0)
			witness_disp_a[wid] = CourtActionSystem.get_debate_disposition_tier(w_disp_a)
			witness_disp_b[wid] = CourtActionSystem.get_debate_disposition_tier(w_disp_b)

	var resolution: Dictionary = CourtActionSystem.resolve_public_debate(
		a_roll, b_roll, witness_disp_a, witness_disp_b, raises
	)

	var effects: Dictionary = {
		"debate_per_witness": resolution.get("per_witness_results", []),
		"witnesses": witness_ids,
	}

	if not resolution.get("success", false):
		effects["failed"] = true
		if margin <= -10:
			effects["glory_change"] = -0.1

	return {
		"success": resolution.get("success", false),
		"action_id": "PUBLIC_DEBATE",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": primary_skill,
		"roll_total": a_roll,
		"tn": b_roll,
		"margin": margin,
		"effects": effects,
	}


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

		"BRIBE_FOR_INFO":
			if target == null:
				return {}
			var r: Dictionary = _resolve_bribe_attempt(character, target, action, dice_engine)
			return _build_covert_result(action, ctx, "Temptation", r)

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

		"BRIBE_WITNESS":
			if target == null:
				return {}
			var r: Dictionary = _resolve_bribe_witness(character, target, action, dice_engine)
			return _build_covert_result(action, ctx, "Temptation", r)

		"INTIMIDATE_WITNESS":
			if target == null:
				return {}
			var r: Dictionary = _resolve_intimidate_witness(character, target, action, dice_engine)
			return _build_covert_result(action, ctx, "Intimidation", r)

		"KILL_WITNESS":
			if target == null:
				return {}
			var r: Dictionary = _resolve_kill_witness(character, target, dice_engine)
			return _build_covert_result(action, ctx, "Stealth", r)

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


static func _resolve_bribe_attempt(
	briber: L5RCharacterData,
	magistrate: L5RCharacterData,
	action: NPCDataStructures.ScoredAction,
	dice_engine: DiceEngine,
) -> Dictionary:
	var temptation: int = briber.skills.get("Temptation", 0)
	var awareness: int = briber.awareness if briber.awareness > 0 else 2
	var rolled: int = maxi(temptation + awareness, 1)
	var kept: int = maxi(awareness, 1)
	var attack_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
	var attack_total: int = attack_result.get("total", 0)

	var etiquette: int = magistrate.skills.get("Etiquette", 0)
	var willpower: int = magistrate.willpower if magistrate.willpower > 0 else 2
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(magistrate) * 5
	var def_rolled: int = maxi(etiquette + willpower, 1)
	var def_kept: int = maxi(willpower, 1)
	var defense_result: Dictionary = dice_engine.roll_and_keep(def_rolled, def_kept)
	var defense_total: int = defense_result.get("total", 0) + honor_bonus

	var success: bool = attack_total > defense_total
	var suppress_case: bool = action.metadata.get("suppress_case", false)

	return {
		"success": success,
		"roll_total": attack_total,
		"tn": defense_total,
		"margin": attack_total - defense_total,
		"detection_risk": not success,
		"suppress_case": suppress_case,
		"magistrate_id": magistrate.character_id,
	}


# -- Witness Tampering (s11.3.13c) --------------------------------------------

static func _resolve_bribe_witness(
	criminal: L5RCharacterData,
	witness: L5RCharacterData,
	_action: NPCDataStructures.ScoredAction,
	dice_engine: DiceEngine,
) -> Dictionary:
	var temptation: int = criminal.skills.get("Temptation", 0)
	var awareness: int = criminal.awareness if criminal.awareness > 0 else 2
	var rolled: int = maxi(temptation + awareness, 1)
	var kept: int = maxi(awareness, 1)
	var attack_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
	var attack_total: int = attack_result.get("total", 0)

	var etiquette: int = witness.skills.get("Etiquette", 0)
	var willpower: int = witness.willpower if witness.willpower > 0 else 2
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(witness) * 5
	var def_rolled: int = maxi(etiquette + willpower, 1)
	var def_kept: int = maxi(willpower, 1)
	var defense_result: Dictionary = dice_engine.roll_and_keep(def_rolled, def_kept)
	var defense_total: int = defense_result.get("total", 0) + honor_bonus

	var success: bool = attack_total > defense_total
	return {
		"success": success,
		"roll_total": attack_total,
		"tn": defense_total,
		"margin": attack_total - defense_total,
		"detection_risk": not success,
		"effect": "witness_bribed" if success else "bribe_rejected",
		"witness_id": witness.character_id,
		"evidence_on_fail": InvestigationLoopSystem.WITNESS_BRIBE_EVIDENCE_ON_FAIL,
	}


static func _resolve_intimidate_witness(
	criminal: L5RCharacterData,
	witness: L5RCharacterData,
	_action: NPCDataStructures.ScoredAction,
	dice_engine: DiceEngine,
) -> Dictionary:
	var intimidation: int = criminal.skills.get("Intimidation", 0)
	var willpower_c: int = criminal.willpower if criminal.willpower > 0 else 2
	var rolled: int = maxi(intimidation + willpower_c, 1)
	var kept: int = maxi(willpower_c, 1)
	var attack_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
	var attack_total: int = attack_result.get("total", 0)

	var etiquette: int = witness.skills.get("Etiquette", 0)
	var willpower_w: int = witness.willpower if witness.willpower > 0 else 2
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(witness) * 5
	var def_rolled: int = maxi(etiquette + willpower_w, 1)
	var def_kept: int = maxi(willpower_w, 1)
	var defense_result: Dictionary = dice_engine.roll_and_keep(def_rolled, def_kept)
	var defense_total: int = defense_result.get("total", 0) + honor_bonus

	var success: bool = attack_total > defense_total
	return {
		"success": success,
		"roll_total": attack_total,
		"tn": defense_total,
		"margin": attack_total - defense_total,
		"detection_risk": true,
		"effect": "witness_intimidated" if success else "intimidation_rejected",
		"witness_id": witness.character_id,
		"witness_hostile": not success,
		"evidence_on_fail": InvestigationLoopSystem.WITNESS_INTIMIDATE_EVIDENCE_ON_FAIL,
	}


static func _resolve_kill_witness(
	killer: L5RCharacterData,
	victim: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth: int = killer.skills.get("Stealth", 0)
	var agility: int = killer.agility if killer.agility > 0 else 2
	var rolled: int = maxi(stealth + agility, 1)
	var kept: int = maxi(agility, 1)
	var attack_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
	var attack_total: int = attack_result.get("total", 0)

	var perception: int = victim.perception if victim.perception > 0 else 2
	var investigation: int = victim.skills.get("Investigation", 0)
	var def_rolled: int = maxi(perception + investigation, 1)
	var def_kept: int = maxi(perception, 1)
	var defense_result: Dictionary = dice_engine.roll_and_keep(def_rolled, def_kept)
	var defense_total: int = defense_result.get("total", 0)

	var success: bool = attack_total > defense_total
	return {
		"success": success,
		"roll_total": attack_total,
		"tn": defense_total,
		"margin": attack_total - defense_total,
		"detection_risk": true,
		"effect": "witness_killed" if success else "kill_attempt_failed",
		"witness_id": victim.character_id,
		"concealment_tn": attack_total if success else 0,
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
	worship_province_malus: Dictionary = {},
	character: L5RCharacterData = null,
) -> int:
	if action_id in SOCIAL_ACTIONS:
		return _get_social_tn(action, ctx, character)
	if action_id in COVERT_ACTIONS:
		return COVERT_BASE_TN
	if action_id in MILITARY_ORDERS:
		return MILITARY_BASE_TN
	if action_id in ADMINISTRATIVE_ACTIONS:
		return ADMIN_BASE_TN
	if action_id in INTELLIGENCE_ACTIONS:
		var intel_modifier: int = absi(int(worship_province_malus.get("intelligence_roll_modifier", 0)))
		return SOCIAL_BASE_TN + intel_modifier
	if action_id == "PUBLIC_ATONEMENT":
		var tier: int = action.metadata.get("offense_tier", 3)
		return HonorGlorySystem.ATONEMENT_TN_BY_TIER.get(tier, 20)
	return SOCIAL_BASE_TN


static func _get_social_tn(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
	character: L5RCharacterData = null,
) -> int:
	var tn: int = SOCIAL_BASE_TN
	var target_disp: int = ctx.dispositions.get(action.target_npc_id, 0)

	# Per GDD s12.2: Free Raises (−5 TN) or additional Raises (+5 TN) by tier
	if target_disp <= -61:
		tn += 10  # Blood Enemy: +2 additional Raises
	elif target_disp <= -31:
		tn += 5   # Enemy: +1 additional Raise
	# Rival (-30 to -11), Stranger (-10 to +10), Acquaintance (+11 to +30): no modifier
	elif target_disp >= 91:
		tn -= 15  # Devoted: 3 Free Raises
	elif target_disp >= 61:
		tn -= 10  # Trusted Ally: 2 Free Raises
	elif target_disp >= 31:
		tn -= 5   # Friend: 1 Free Raise

	if character != null and action.action_id in ["PUBLIC_DECLARATION", "OFFER_FAVOR"]:
		var honor_mod: int = HonorGlorySystem.get_court_honor_modifier(character)
		tn -= honor_mod * 5

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

	if action_id == "PUBLIC_ATONEMENT":
		effects = _compute_atonement_effects(action, result)
		var offense_key: String = action.metadata.get("offense_key", "")
		if not offense_key.is_empty():
			HonorGlorySystem.record_atonement(_character, offense_key)
	elif result["success"]:
		if action_id in SOCIAL_ACTIONS:
			effects = _compute_social_effects(action_id, result["margin"])
		elif action_id in COVERT_ACTIONS:
			effects = _compute_covert_effects(action_id, result["margin"])
		elif action_id in MILITARY_ORDERS:
			effects = _compute_military_effects(action_id, action)
		elif action_id in ADMINISTRATIVE_ACTIONS:
			effects = _compute_admin_effects(action_id)
		elif action_id in INTELLIGENCE_ACTIONS:
			effects = _compute_intelligence_effects(action_id, result.get("margin", 0))
		else:
			effects = _compute_self_effects(action_id)
	else:
		effects = _compute_failure_effects(action_id, result.get("margin", 0))

	result["effects"] = effects


static func _compute_social_effects(action_id: String, margin: int) -> Dictionary:
	var disp_change: int = 0
	var glory_change: float = 0.0
	var info_gained: bool = false
	var raises: int = maxi(int(margin / 5.0), 0)

	# Per GDD s12.2 Category 1 — Targeted Disposition Values (LOCKED)
	# Base + 3 per raise for disposition-granting social actions
	match action_id:
		"CHARM":
			disp_change = 8 + raises * 3
		"LISTEN_REFLECT":
			disp_change = 11 + raises * 3
		"PERSUADE":
			disp_change = 11 + raises * 3
		"NEGOTIATE":
			disp_change = 9 + raises * 3
		"IMPRESS":
			disp_change = 9 + raises * 3
		"PROBE", "READ_CHARACTER":
			info_gained = true
		"ASK_FOR_INTRODUCTION":
			info_gained = true
		"DISCLOSE":
			info_gained = true

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
		"quality": clampi(int(margin / 5.0), 1, 5),
	}


static func _compute_military_effects(action_id: String, action: NPCDataStructures.ScoredAction) -> Dictionary:
	match action_id:
		"ORDER_LEVY":
			var levy_type: int = action.metadata.get(
				"levy_unit_type", Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
			)
			return {
				"effect": "levy_raised",
				"requires_levy_pu": true,
				"levy_unit_type": levy_type,
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
			return {
				"effect": "patrol_dispatched",
				"requires_patrol": true,
				"patrol_province_id": action.target_province_id,
			}
		"ASSIGN_GARRISON":
			return {"effect": "garrison_assigned"}
		"DRILL_TROOPS":
			return {
				"effect": "training_bonus",
				"requires_drill": true,
				"target_company_id": action.metadata.get("target_company_id", -1),
			}
		"CONDUCT_RAID":
			return {"effect": "raid_executed"}
		"RAID_HARVEST":
			return _compute_harvest_destruction_effects(action)
		"CONDUCT_SORTIE":
			return {"effect": "sortie_executed"}
		"CONDUCT_STORM_ASSAULT":
			return {"effect": "assault_executed"}
		"MAINTAIN_SIEGE":
			var sid: int = action.metadata.get(
				"siege_settlement_id", -1,
			)
			return {
				"effect": "siege_maintained",
				"requires_siege_maintenance": true,
				"siege_settlement_id": sid,
			}
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


static func _execute_dispatch_courtier(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	# GDD s55.23a: Champion/Shireikan dispatches a courtier to a Family Daimyo
	# to formally request Wall garrison commitment. No deferral — the Daimyo
	# must comply or refuse this season.
	var target_id: int = action.target_npc_id
	var target_province_id: int = action.target_province_id

	if target_id < 0 or characters_by_id.is_empty():
		return {
			"success": false,
			"action_id": "DISPATCH_COURTIER",
			"character_id": ctx.character_id,
			"target_npc_id": target_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {"effect": "courtier_dispatched", "no_target": true},
		}

	var daimyo: L5RCharacterData = characters_by_id.get(target_id)
	if daimyo == null:
		return {
			"success": false,
			"action_id": "DISPATCH_COURTIER",
			"character_id": ctx.character_id,
			"target_npc_id": target_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {"effect": "courtier_dispatched", "no_target": true},
		}

	# Personality modifiers on the receiving Daimyo (GDD s55.23a)
	var position: float = 30.0
	match daimyo.bushido_virtue:
		Enums.BushidoVirtue.CHUGI:
			position += 15.0
		Enums.BushidoVirtue.YU:
			position += 8.0
		Enums.BushidoVirtue.MEIYO:
			position += 8.0
		Enums.BushidoVirtue.JIN:
			position += 6.0
	match daimyo.shourido_virtue:
		Enums.ShouridoVirtue.KYORYOKU:
			position -= 5.0
		Enums.ShouridoVirtue.SEIGYO:
			position -= 5.0

	# Courtier's persuasion roll (Courtier + Intelligence vs TN 20)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Courtier", 20
	)
	var margin: int = roll_result.get("margin", 0)
	position += margin * 0.5

	var wall_critical: bool = false
	for ws: Variant in ctx.wall_statuses:
		if ws is NPCDataStructures.WallStatus:
			var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
			if w.si < 6:
				wall_critical = true
				break

	if position >= 50.0:
		# Daimyo complies — honor gain scaled by contribution
		return {
			"success": true,
			"action_id": "DISPATCH_COURTIER",
			"character_id": ctx.character_id,
			"target_npc_id": target_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"skill_used": "Courtier",
			"roll_total": roll_result.get("total", 0),
			"tn": 20,
			"margin": margin,
			"effects": {
				"effect": "courtier_accepted",
				"requires_garrison_assignment": true,
				"target_npc_id": target_id,
				"target_province_id": target_province_id,
				"honor_gain_recipient": 0.1,
				"recipient_disposition_change": 2.0,
			},
		}
	else:
		# Daimyo refuses — honor loss scaled to Wall urgency
		var honor_loss: float = -1.0 if wall_critical else -0.3
		return {
			"success": false,
			"action_id": "DISPATCH_COURTIER",
			"character_id": ctx.character_id,
			"target_npc_id": target_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"skill_used": "Courtier",
			"roll_total": roll_result.get("total", 0),
			"tn": 20,
			"margin": margin,
			"effects": {
				"effect": "courtier_refused",
				"garrison_refused": true,
				"target_npc_id": target_id,
				"target_province_id": target_province_id,
				"honor_change_recipient": honor_loss,
				"recipient_disposition_change": -2.0,
			},
		}


static func _execute_perform_worship(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var is_shugenja: bool = character.school_type == Enums.SchoolType.SHUGENJA
	var is_monk: bool = character.school_type == Enums.SchoolType.MONK
	var char_type: String = "normal"
	if is_monk:
		char_type = "monk"
	elif is_shugenja:
		char_type = "shugenja"

	var directed_fortune: int = action.metadata.get("directed_fortune", -1)

	var ring_id: int = Enums.Ring.VOID
	if directed_fortune >= 0:
		ring_id = WorshipSystem.FORTUNE_RING.get(directed_fortune, Enums.Ring.VOID)
	var ring_value: int = CharacterStats.get_ring_value(character, ring_id)
	var theology_rank: int = character.skills.get("Theology", 0)

	var location_type: String = action.metadata.get("location_type", "roadside_shrine")

	var worship_result: Dictionary = WorshipSystem.resolve_active_worship(
		char_type, is_shugenja, dice_engine, ring_value, theology_rank,
		location_type, directed_fortune,
	)

	var province_id: int = action.target_province_id

	return {
		"success": true,
		"action_id": "PERFORM_WORSHIP",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_worship_accumulation": true,
			"province_id": province_id,
			"wp_distribution": worship_result.get("wp_distribution", {}),
			"total_wp": worship_result.get("total_wp", 0.0),
			"bonus_wp": worship_result.get("bonus_wp", 0.0),
			"directed": worship_result.get("directed", false),
		},
	}


static func _execute_scout_enemy(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	# GDD s55.23.2: Vassal-level military reconnaissance. Roll Battle+Perception
	# vs TN 20. Success: learn enemy army data. Critical failure: scouts detected.
	const SCOUT_TN: int = 20
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Battle", SCOUT_TN,
		0, "", Enums.Trait.NONE, 0, 0, 0
	)
	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("margin", 0)

	var effects: Dictionary = {
		"effect": "scout_completed",
		"info_gained": success,
		"scout_intel": success,
		"target_clan_id": action.metadata.get("target_clan_id", ""),
	}

	# Critical failure: scouts detected — topic generated (GDD s55.23.2)
	if not success and margin <= -10:
		effects["scouts_detected"] = true
		effects["detection_risk"] = true

	return {
		"success": success,
		"action_id": "SCOUT_ENEMY",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Battle",
		"roll_total": roll_result.get("total", 0),
		"tn": SCOUT_TN,
		"margin": margin,
		"effects": effects,
	}


static func _execute_examine_letter(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var letter_id: int = action.metadata.get("letter_id", -1)
	return {
		"success": true,
		"action_id": "EXAMINE_LETTER",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_letter_examination": true,
			"letter_id": letter_id,
			"examiner_id": character.character_id,
		},
	}


static func _execute_conduct_sortie(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	# GDD s2.4.10/s2.4.11: Taisa or higher commits garrison portion into
	# adjacent Shadowlands province to reduce SS. Horde combat is deferred
	# until Jigoku Horde generation (s2.4.7) is implemented.
	var target_province_id: int = action.target_province_id

	# Read SS from metadata (populated by NPC engine from world_state) or
	# fall back to the WallStatus context for the target province.
	var ss: int = action.metadata.get("ss", 0)
	var si: int = 10
	var garrison_above_minimum: bool = true
	var jade_stockpile_critical: bool = false

	for ws_variant: Variant in ctx.wall_statuses:
		if not ws_variant is NPCDataStructures.WallStatus:
			continue
		var ws: NPCDataStructures.WallStatus = ws_variant as NPCDataStructures.WallStatus
		if ws.province_id == target_province_id or target_province_id < 0:
			ss = ws.ss if ss == 0 else ss
			si = ws.si
			garrison_above_minimum = ws.garrison_above_minimum
			jade_stockpile_critical = ws.jade_stockpile_critical
			break

	var is_shireikan: bool = character.military_rank >= Enums.MilitaryRank.SHIREIKAN
	var force_size_override: String = action.metadata.get("force_size", "")

	var sortie_result: Dictionary = WallSystem.resolve_sortie(
		ss, si, garrison_above_minimum, jade_stockpile_critical,
		is_shireikan, target_province_id, force_size_override
	)

	if not sortie_result["success"]:
		return {
			"success": false,
			"action_id": "CONDUCT_SORTIE",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"effect": "sortie_blocked",
				"blocked_reason": sortie_result.get("blocked_reason", "unknown"),
				"force_size": sortie_result.get("force_size", ""),
			},
		}

	return {
		"success": true,
		"action_id": "CONDUCT_SORTIE",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"effect": "sortie_ordered",
			"requires_sortie_combat": true,
			"force_size": sortie_result["force_size"],
			"force_pct": sortie_result["force_pct"],
			"ss_reduction": sortie_result["ss_reduction"],
			"jade_per_warrior": sortie_result["jade_per_warrior"],
			"target_province_id": target_province_id,
		},
	}


static func _execute_conduct_storm_assault(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var settlement_id: int = action.metadata.get(
		"siege_settlement_id", character.physical_location,
	)
	return {
		"success": true,
		"action_id": "CONDUCT_STORM_ASSAULT",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"effect": "storm_assault_ordered",
			"requires_storm_assault": true,
			"siege_settlement_id": settlement_id,
		},
	}


static func _execute_fortify_wall_section(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	# GDD s2.4.16: Kaiu Engineer repairs SI on a Tower that is not fully breached.
	# TN = 20 + (10 − current_SI) × 2. Success: +1 SI + 0.5 per Raise (floored).
	# Lingering effect: Kaiu Reinforcement modifier per engineer rank.
	var target_province_id: int = action.target_province_id

	# Read SI from WallStatus. Prefer matching province; fall back to first entry.
	var si: int = 10
	for ws_variant: Variant in ctx.wall_statuses:
		if not ws_variant is NPCDataStructures.WallStatus:
			continue
		var ws: NPCDataStructures.WallStatus = ws_variant as NPCDataStructures.WallStatus
		if target_province_id < 0 or ws.province_id == target_province_id:
			si = ws.si
			if target_province_id < 0:
				target_province_id = ws.province_id
			break

	if si <= 0:
		return {
			"success": false,
			"action_id": "FORTIFY_WALL_SECTION",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"effect": "fortify_blocked",
				"blocked_reason": "si_is_zero_use_seal",
			},
		}

	var tn: int = WallSystem.get_fortify_tn(si)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Engineering", tn
	)
	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("margin", 0)
	var raises: int = maxi(int(margin / 5.0), 0)
	var si_gain: int = int(WallSystem.compute_fortify_si_gain(raises))
	var kaiu_reinforce: Dictionary = WallSystem.get_kaiu_reinforce(ctx.insight_rank)

	return {
		"success": success,
		"action_id": "FORTIFY_WALL_SECTION",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Engineering",
		"roll_total": roll_result.get("total", 0),
		"tn": tn,
		"margin": margin,
		"effects": {
			"effect": "wall_fortified",
			"requires_fortify_wall": success,
			"si_gain": si_gain,
			"kaiu_decay_reduction": kaiu_reinforce["decay_reduction"],
			"kaiu_reinforce_duration": kaiu_reinforce["duration"],
			"target_province_id": target_province_id,
		},
	}


static func _execute_seal_wall_breach(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	# GDD s2.4.16: Kaiu Engineer Rank 3+ rebuilds a fully breached Tower (SI = 0).
	# TN 35. Always costs 5 Koku from the Tower's koku_stockpile.
	# Success: SI restored to 2. Failure: no SI change, Koku still paid.
	const SEAL_TN: int = 35
	const SEAL_KOKU_COST: float = 5.0

	var target_province_id: int = action.target_province_id

	var si: int = -1
	for ws_variant: Variant in ctx.wall_statuses:
		if not ws_variant is NPCDataStructures.WallStatus:
			continue
		var ws: NPCDataStructures.WallStatus = ws_variant as NPCDataStructures.WallStatus
		if target_province_id < 0 or ws.province_id == target_province_id:
			si = ws.si
			if target_province_id < 0:
				target_province_id = ws.province_id
			break

	if si != 0:
		return {
			"success": false,
			"action_id": "SEAL_WALL_BREACH",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"effect": "seal_blocked",
				"blocked_reason": "si_not_zero",
			},
		}

	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Engineering", SEAL_TN
	)
	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("margin", 0)

	return {
		"success": success,
		"action_id": "SEAL_WALL_BREACH",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Engineering",
		"roll_total": roll_result.get("total", 0),
		"tn": SEAL_TN,
		"margin": margin,
		"effects": {
			"effect": "breach_sealed" if success else "breach_seal_failed",
			"requires_breach_seal": success,
			"koku_cost": SEAL_KOKU_COST,
			"target_province_id": target_province_id,
		},
	}


static func _execute_purify_tainted_ground(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var province_id: int = action.target_province_id
	if province_id < 0:
		province_id = action.metadata.get("province_id", -1)

	var ptl: float = action.metadata.get("ptl", 0.0)
	var tn: int = 15 + int(ptl * 5.0)

	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Lore: Shadowlands", tn,
	)
	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("margin", 0)
	var raises: int = maxi(margin / 5, 0) if success else 0

	var ptl_reduction: float = 0.0
	if success:
		ptl_reduction = 0.5 + (raises * 0.25)

	var school_rank: int = CharacterStats.get_insight_rank(character)
	var ward_bleed_reduction: float = 0.0
	var ward_duration: int = 0
	if success:
		match school_rank:
			1:
				ward_bleed_reduction = 0.1
				ward_duration = 2
			2:
				ward_bleed_reduction = 0.1
				ward_duration = 3
			3:
				ward_bleed_reduction = 0.2
				ward_duration = 4
			4:
				ward_bleed_reduction = 0.2
				ward_duration = 5
			_:
				ward_bleed_reduction = 0.3
				ward_duration = 6

	return {
		"success": success,
		"action_id": "PURIFY_TAINTED_GROUND",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Lore: Shadowlands",
		"roll_total": roll_result.get("total", 0),
		"tn": tn,
		"margin": margin,
		"raises": raises,
		"effects": {
			"effect": "taint_purified" if success else "purification_failed",
			"requires_purification": success,
			"ptl_reduction": ptl_reduction,
			"province_id": province_id,
			"ward_bleed_reduction": ward_bleed_reduction,
			"ward_duration": ward_duration,
			"ward_school_rank": school_rank,
		},
	}


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
		"MENTOR":
			return {"effect": "student_trained"}
		"OBSERVE_COURT_ATTENDEES":
			return {"effect": "court_observed", "info_gained": true}  # fallback — should not reach here
	return {"effect": "self_action_completed"}


static func _compute_atonement_effects(
	action: NPCDataStructures.ScoredAction,
	result: Dictionary,
) -> Dictionary:
	var tier: int = action.metadata.get("offense_tier", 3)
	var margin: int = result.get("margin", 0)
	var success: bool = result.get("success", false)
	if success:
		var raises: int = maxi(int(margin / 5.0), 0)
		var honor_gain: float = HonorGlorySystem.ATONEMENT_HONOR_BY_TIER.get(tier, 0.5)
		honor_gain += float(raises) * HonorGlorySystem.ATONEMENT_HONOR_PER_RAISE
		return {
			"effect": "atonement_performed",
			"honor_change": honor_gain,
			"glory_change": HonorGlorySystem.ATONEMENT_GLORY_LOSS,
			"offense_tier": tier,
		}
	if margin <= -10:
		return {
			"effect": "atonement_critical_failure",
			"failed": true,
			"honor_change": HonorGlorySystem.ATONEMENT_CRITICAL_FAIL_HONOR_LOSS,
			"glory_change": HonorGlorySystem.ATONEMENT_CRITICAL_FAIL_GLORY_LOSS,
			"offense_tier": tier,
		}
	return {
		"effect": "atonement_failed",
		"failed": true,
		"glory_change": HonorGlorySystem.ATONEMENT_GLORY_LOSS,
		"offense_tier": tier,
	}


static func _compute_failure_effects(action_id: String, margin: int = 0) -> Dictionary:
	var effects: Dictionary = {"failed": true}
	# Per GDD s12.2: no disposition change on normal failure.
	# Critical failure (margin ≤ -10) has action-specific penalties.
	if action_id in SOCIAL_ACTIONS and margin <= -10:
		effects["disposition_change"] = _get_critical_failure_disposition(action_id)
	if action_id in COVERT_ACTIONS:
		effects["detection_risk"] = true
	return effects


# Per GDD s12.2 critical failure (margin ≤ -10) disposition penalties
const CRITICAL_FAILURE_DISPOSITION: Dictionary = {
	"CHARM": -5,
	"PERSUADE": -7,
	"NEGOTIATE": -6,
	"LISTEN_REFLECT": -7,
	"IMPRESS": -6,
	"INTIMIDATE": -8,
	"DISCLOSE": -5,
	"GOSSIP": -5,
	"PROVOKE_EMOTION": -5,
	"DISCERN_NEED": -3,
}


static func _get_no_roll_effects(action_id: String) -> Dictionary:
	match action_id:
		"DO_NOTHING":
			return {"effect": "nothing"}
		"REST":
			return {"effect": "rested"}
		"BEGIN_TRAVEL", "CHANGE_DESTINATION":
			return {"effect": "travel_started"}
	return {"effect": "completed"}


static func _get_critical_failure_disposition(action_id: String) -> int:
	return CRITICAL_FAILURE_DISPOSITION.get(action_id, 0)


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


# -- EXAMINE_CRIME_SCENE (s57.15, s11.3.13) ------------------------------------

static func _execute_examine_crime_scene(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	crime_records: Array[CrimeRecord],
) -> Dictionary:
	var case_id: int = action.metadata.get("case_id", -1)
	var record: CrimeRecord = _find_crime_record(case_id, crime_records)

	if record == null:
		return {
			"success": false,
			"action_id": "EXAMINE_CRIME_SCENE",
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "no_crime_record",
			"effects": {},
		}

	var exam_result: Dictionary = InvestigationSystem.examine_scene(
		character, record, dice_engine, ctx.ic_day
	)

	return {
		"success": exam_result.get("success", false),
		"action_id": "EXAMINE_CRIME_SCENE",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"effect": "scene_examined",
			"case_id": case_id,
			"evidence_gained": exam_result.get("evidence_gained", 0),
			"suspect_found": exam_result.get("suspect_found", -1),
			"raises": exam_result.get("raises", 0),
			"threshold_crossed": exam_result.get("threshold_crossed", ""),
		},
	}


static func _find_crime_record(
	case_id: int,
	crime_records: Array[CrimeRecord],
) -> CrimeRecord:
	if case_id < 0:
		return null
	for record: CrimeRecord in crime_records:
		if record.case_id == case_id:
			return record
	return null


# -- Flee Jurisdiction ---------------------------------------------------------

static func _execute_flee_jurisdiction(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	return {
		"success": true,
		"action_id": "FLEE_JURISDICTION",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"effect": "flee_jurisdiction",
			"fugitive_id": character.character_id,
		},
	}


# -- Extort Accused (corrupt magistrate path) ---------------------------------

static func _execute_extort_accused(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var suspect: L5RCharacterData = characters_by_id.get(action.target_npc_id)
	if suspect == null:
		return {
			"success": false,
			"action_id": "EXTORT_ACCUSED",
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "no_target",
			"effects": {},
		}

	var intimidation: int = character.skills.get("Intimidation", 0)
	var willpower_mag: int = character.willpower if character.willpower > 0 else 2
	var kept_mag: int = maxi(willpower_mag, 1)
	var rolled_mag: int = maxi(intimidation + willpower_mag, 1)

	var etiquette: int = suspect.skills.get("Etiquette", 0)
	var willpower_sus: int = suspect.willpower if suspect.willpower > 0 else 2
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(suspect) * 5
	var def_rolled: int = maxi(etiquette + willpower_sus, 1)
	var def_kept: int = maxi(willpower_sus, 1)
	var defense_result: Dictionary = dice_engine.roll_and_keep(def_rolled, def_kept)
	var tn: int = defense_result.get("total", 0) + honor_bonus

	var roll: Dictionary = dice_engine.roll_and_keep(rolled_mag, kept_mag)
	var total: int = roll.get("total", 0)
	var success: bool = total >= tn

	var effects: Dictionary = {
		"effect": "extortion_attempt",
		"suspect_id": action.target_npc_id,
		"magistrate_id": character.character_id,
		"suppress_case": success,
	}

	return {
		"success": success,
		"action_id": "EXTORT_ACCUSED",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Intimidation",
		"roll_total": total,
		"tn": tn,
		"margin": total - tn,
		"effects": effects,
	}


# -- Intelligence Effects (s57.15) --------------------------------------------

static func _compute_intelligence_effects(action_id: String, _margin: int) -> Dictionary:
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
	_ctx: NPCDataStructures.ContextSnapshot,
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


# -- Governance Actions --------------------------------------------------------

static func _execute_appoint_to_position(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_id: int = action.metadata.get("target_npc_id", action.target_npc_id)
	var position: String = action.metadata.get("position", "")
	return {
		"success": target_id >= 0,
		"action_id": "APPOINT_TO_POSITION",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_appointment": true,
			"appointing_lord_id": ctx.character_id,
			"appointee_id": target_id,
			"position": position,
		},
	}


static func _execute_arrange_marriage(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var candidate_id: int = action.metadata.get("candidate_id", -1)
	var target_lord_id: int = action.metadata.get("target_lord_id", -1)
	var target_candidate_id: int = action.metadata.get("target_candidate_id", -1)

	if candidate_id < 0 or target_lord_id < 0:
		return {
			"success": false,
			"action_id": "ARRANGE_MARRIAGE",
			"character_id": ctx.character_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "missing_metadata",
			"effects": {},
		}

	var target_lord: L5RCharacterData = characters_by_id.get(target_lord_id) as L5RCharacterData
	if target_lord == null:
		return {
			"success": false,
			"action_id": "ARRANGE_MARRIAGE",
			"character_id": ctx.character_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "target_lord_not_found",
			"effects": {},
		}

	if target_candidate_id < 0:
		target_candidate_id = _find_best_marriage_candidate(
			target_lord, characters_by_id,
		)
		if target_candidate_id < 0:
			return {
				"success": false,
				"action_id": "ARRANGE_MARRIAGE",
				"character_id": ctx.character_id,
				"ic_day": ctx.ic_day,
				"season": ctx.season,
				"reason": "no_target_candidate",
				"effects": {},
			}

	var proposing_disp: int = target_lord.disposition_values.get(ctx.character_id, 0)
	var candidate_char: L5RCharacterData = characters_by_id.get(target_candidate_id) as L5RCharacterData
	var char_value: int = 0
	if candidate_char != null:
		char_value = int(candidate_char.status * 2 + candidate_char.glory)
	var favor_tier: int = action.metadata.get("favor_tier", 0)
	var has_mil_obj: bool = action.metadata.get("has_military_objective", false)

	var acceptance_score: int = MarriageSystem.evaluate_proposal(
		proposing_disp, char_value, favor_tier, has_mil_obj,
	)

	if MarriageSystem.is_benten_festival(ctx.ic_day):
		acceptance_score += MarriageSystem.BENTEN_FESTIVAL_BONUS

	if acceptance_score < 0:
		return {
			"success": false,
			"action_id": "ARRANGE_MARRIAGE",
			"character_id": ctx.character_id,
			"target_npc_id": target_lord_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"marriage_rejected": true,
				"proposing_lord_id": ctx.character_id,
				"target_lord_id": target_lord_id,
				"disposition_change": -3,
			},
		}

	var candidate_a: L5RCharacterData = characters_by_id.get(candidate_id) as L5RCharacterData
	var marriage_type: MarriageSystem.MarriageType = MarriageSystem.MarriageType.CROSS_CLAN
	if candidate_a != null and candidate_char != null:
		if candidate_a.clan == candidate_char.clan:
			if candidate_a.family == candidate_char.family:
				marriage_type = MarriageSystem.MarriageType.WITHIN_FAMILY
			else:
				marriage_type = MarriageSystem.MarriageType.BETWEEN_FAMILIES

	return {
		"success": true,
		"action_id": "ARRANGE_MARRIAGE",
		"character_id": ctx.character_id,
		"target_npc_id": target_lord_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_marriage": true,
			"proposing_lord_id": ctx.character_id,
			"target_lord_id": target_lord_id,
			"candidate_a_id": candidate_id,
			"candidate_b_id": target_candidate_id,
			"marriage_type": marriage_type,
			"acceptance_score": acceptance_score,
		},
	}


static func _find_best_marriage_candidate(
	lord: L5RCharacterData,
	characters_by_id: Dictionary,
) -> int:
	var best_id: int = -1
	var best_value: int = -1
	for cid: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid] as L5RCharacterData
		if c == null:
			continue
		if c.character_id == lord.character_id:
			continue
		if c.spouse_id >= 0:
			continue
		if CharacterStats.is_dead(c):
			continue
		var is_vassal: bool = c.lord_id == lord.character_id
		var is_child: bool = lord.children_ids.has(c.character_id)
		if not is_vassal and not is_child:
			continue
		var value: int = int(c.status * 2 + c.glory)
		if value > best_value:
			best_value = value
			best_id = c.character_id
	return best_id


# -- Winter Court Skill Bonus --------------------------------------------------

static func _get_winter_court_skill_bonus(
	character: L5RCharacterData,
	skill_name: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	if not WinterCourtSystem.is_home_ground_skill(skill_name):
		return 0
	var court_dict: Dictionary = ctx.active_court_at_location
	if court_dict.is_empty():
		return 0
	if court_dict.get("court_type", -1) != CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
		return 0
	if character.clan != court_dict.get("host_clan", ""):
		return 0
	return WinterCourtSystem.HOST_SKILL_BONUS


static func _get_doshin_bonus(action_id: String, bonus_value: int) -> int:
	if bonus_value <= 0:
		return 0
	if action_id in _DOSHIN_ELIGIBLE_ACTIONS:
		return bonus_value
	return 0


const _DOSHIN_ELIGIBLE_ACTIONS: Array[String] = [
	"EXAMINE_CRIME_SCENE", "INVESTIGATE_PROVINCE", "PROBE",
]


# -- Construction Intercepts ---------------------------------------------------

const _CONSTRUCTION_ACTIONS: Array[String] = [
	"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
	"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
]

const _CONSTRUCTION_TYPE_MAP: Dictionary = {
	"BUILD_SHRINE": "shrine",
	"FOUND_VILLAGE": "village",
	"BUILD_FORTIFICATION": "fortification",
	"FOUND_TEMPLE": "temple",
	"FOUND_MONASTERY": "monastery",
	"COMMISSION_SHIP": "ship",
}


static func _execute_construction(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var action_id: String = action.action_id
	var ctype: String = _CONSTRUCTION_TYPE_MAP.get(action_id, "")
	var meta: Dictionary = action.metadata if action.metadata != null else {}

	var effects: Dictionary = {
		"requires_construction": true,
		"construction_action": action_id,
		"construction_category": ctype,
		"province_id": action.target_province_id if action.target_province_id >= 0 else meta.get("province_id", -1),
		"settlement_id": action.target_settlement_id if action.target_settlement_id >= 0 else meta.get("settlement_id", -1),
		"is_dedicated": meta.get("is_dedicated", false),
		"dedicated_fortune": meta.get("dedicated_fortune", -1),
		"ship_class": meta.get("ship_class", -1),
		"shrine_tier": meta.get("shrine_tier", "roadside"),
	}

	return {
		"success": true,
		"action_id": action_id,
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": effects["province_id"],
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": effects,
	}


# -- Contested Court Actions (s15.4 Category 1) -------------------------------

const _CONTESTED_COURT_ACTIONS: Array[String] = [
	"NEGOTIATE", "PERSUADE", "CHARM", "IMPRESS", "LISTEN_REFLECT",
	"OFFER_FAVOR", "DISCLOSE",
]


static func _execute_contested_court_action(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var action_id: String = action.action_id
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var skill_entry: Dictionary = action_skill_map.get(action_id, {})
	var a_skill: String = _CONTESTED_ATTACKER_SKILL.get(action_id, skill_entry.get("primary", "Courtier"))
	var a_trait_name: String = _CONTESTED_ATTACKER_TRAIT.get(action_id, skill_entry.get("secondary", "Awareness"))
	var a_skill_rank: int = character.skills.get(a_skill, 0)
	var a_trait_val: int = character.traits.get(a_trait_name, 2)
	var wc_bonus: int = _get_winter_court_skill_bonus(character, a_skill, ctx)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + wc_bonus

	var defender_roll: int = 0
	if target != null:
		var d_skill: String = _CONTESTED_DEFENDER_SKILL.get(action_id, "Etiquette")
		var d_trait_name: String = _CONTESTED_DEFENDER_TRAIT.get(action_id, "Awareness")
		var d_skill_rank: int = target.skills.get(d_skill, 0)
		var d_trait_val: int = target.traits.get(d_trait_name, 2)
		defender_roll = dice_engine.roll_skill_check(
			d_trait_val, d_skill_rank, 0
		).get("total", 0)

	if action_id == "OFFER_FAVOR":
		var honor_mod: int = HonorGlorySystem.get_court_honor_modifier(character)
		attacker_roll += honor_mod * 5

	var margin: int = attacker_roll - defender_roll
	var raises: int = maxi(int(margin / 5.0), 0)
	var has_topic: bool = action.metadata.get("has_topic", false)
	var current_disp: int = ctx.dispositions.get(target_id, 0)

	var resolution: Dictionary
	match action_id:
		"NEGOTIATE":
			var session_count: int = action.metadata.get("session_negotiate_count", 0)
			resolution = CourtActionSystem.resolve_negotiate(
				attacker_roll, defender_roll, raises, has_topic, session_count
			)
		"PERSUADE":
			resolution = CourtActionSystem.resolve_persuade(
				attacker_roll, defender_roll, raises, has_topic
			)
		"CHARM":
			var charm_count: int = action.metadata.get("session_charm_count", 0)
			resolution = CourtActionSystem.resolve_charm(
				attacker_roll, defender_roll, raises, current_disp, charm_count
			)
		"IMPRESS":
			resolution = CourtActionSystem.resolve_impress(
				attacker_roll, defender_roll, raises, has_topic
			)
		"LISTEN_REFLECT":
			resolution = CourtActionSystem.resolve_listen_reflect(
				attacker_roll, defender_roll, raises, has_topic
			)
		"OFFER_FAVOR":
			resolution = CourtActionSystem.resolve_offer_favor(
				attacker_roll, defender_roll
			)
		"DISCLOSE":
			var disclosed_opinion: int = action.metadata.get("disclosed_opinion", 0)
			resolution = CourtActionSystem.resolve_disclose(
				attacker_roll, defender_roll, disclosed_opinion
			)
		_:
			resolution = {"success": false}

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["disposition_change"] = resolution.get("disposition_change", 0)
		if resolution.has("target_position_shift"):
			effects["target_position_shift"] = resolution["target_position_shift"]
		if resolution.has("position_durable"):
			effects["position_durable"] = true
		if resolution.has("position_hardened"):
			effects["position_hardened"] = true
		if resolution.has("session_tn_reduction"):
			effects["session_tn_reduction"] = resolution["session_tn_reduction"]
		if resolution.has("persuade_negotiate_tn_reduction"):
			effects["persuade_negotiate_tn_reduction"] = resolution["persuade_negotiate_tn_reduction"]
		if resolution.has("charm_ceiling_active"):
			effects["charm_ceiling_active"] = resolution["charm_ceiling_active"]
		if resolution.has("requires_favor_creation"):
			effects["requires_favor_creation"] = true
			effects["favor_creditor_id"] = ctx.character_id
			effects["favor_debtor_id"] = target_id
		if resolution.has("info_gained"):
			effects["info_gained"] = resolution["info_gained"]
		if resolution.has("disclosed_opinion"):
			effects["disclosed_opinion"] = resolution["disclosed_opinion"]
			effects["disclose_about_id"] = action.metadata.get("disclose_about_id", -1)
	else:
		effects["failed"] = true
		var fail_disp: int = resolution.get("disposition_change", 0)
		if fail_disp != 0:
			effects["disposition_change"] = fail_disp
		if resolution.has("target_position_shift"):
			effects["target_position_shift"] = resolution["target_position_shift"]
		if resolution.has("position_hardened"):
			effects["position_hardened"] = true

	if not action.metadata.is_empty():
		effects["_action_metadata"] = action.metadata

	return {
		"success": resolution.get("success", false),
		"action_id": action_id,
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": a_skill,
		"roll_total": attacker_roll,
		"tn": defender_roll,
		"margin": margin,
		"effects": effects,
	}


const _CONTESTED_ATTACKER_SKILL: Dictionary = {
	"NEGOTIATE": "Courtier",
	"PERSUADE": "Sincerity",
	"CHARM": "Etiquette",
	"IMPRESS": "Lore",
	"LISTEN_REFLECT": "Investigation",
	"OFFER_FAVOR": "Sincerity",
	"DISCLOSE": "Sincerity",
}

const _CONTESTED_ATTACKER_TRAIT: Dictionary = {
	"NEGOTIATE": "Awareness",
	"PERSUADE": "Awareness",
	"CHARM": "Awareness",
	"IMPRESS": "Intelligence",
	"LISTEN_REFLECT": "Perception",
	"OFFER_FAVOR": "Awareness",
	"DISCLOSE": "Perception",
}

const _CONTESTED_DEFENDER_SKILL: Dictionary = {
	"NEGOTIATE": "Courtier",
	"PERSUADE": "Sincerity",
	"CHARM": "Etiquette",
	"IMPRESS": "Etiquette",
	"LISTEN_REFLECT": "Sincerity",
	"OFFER_FAVOR": "Sincerity",
	"DISCLOSE": "Sincerity",
}

const _CONTESTED_DEFENDER_TRAIT: Dictionary = {
	"NEGOTIATE": "Awareness",
	"PERSUADE": "Willpower",
	"CHARM": "Awareness",
	"IMPRESS": "Awareness",
	"LISTEN_REFLECT": "Awareness",
	"OFFER_FAVOR": "Perception",
	"DISCLOSE": "Perception",
}


# -- PROVOKE_EMOTION (s15.4 Category 4) ---------------------------------------

static func _execute_provoke_emotion(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var a_skill_rank: int = character.skills.get("Courtier", 0)
	var a_trait_val: int = character.traits.get("Awareness", 2)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_willpower: int = target.traits.get("Willpower", 2)
		defender_roll = dice_engine.roll_skill_check(
			d_willpower, d_etiquette, 0
		).get("total", 0)

	var witness_ids: Array[int] = _get_co_located_ids(character, characters_by_id)
	var resolution: Dictionary = CourtActionSystem.resolve_provoke_emotion(
		attacker_roll, defender_roll, witness_ids
	)

	# Ikoma Bard R2 exemption: emotion on behalf of Lion or honorable cause
	var ikoma_exempt: bool = (
		target != null
		and target.school.begins_with("Ikoma Bard")
		and target.clan == "Lion"
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		if ikoma_exempt:
			effects["ikoma_bard_exempt"] = true
		else:
			effects["target_honor_change"] = resolution["target_honor_change"]
			effects["target_glory_change"] = resolution["target_glory_change"]
			effects["target_witness_disposition"] = resolution["target_witness_disposition"]
			effects["witnesses"] = resolution["witnesses"]
	else:
		effects["failed"] = true
		if resolution.has("witness_disposition_loss"):
			effects["witness_disposition_loss"] = resolution["witness_disposition_loss"]
			effects["witnesses"] = resolution["witnesses"]

	return {
		"success": resolution.get("success", false),
		"action_id": "PROVOKE_EMOTION",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Courtier",
		"roll_total": attacker_roll,
		"tn": defender_roll,
		"margin": attacker_roll - defender_roll,
		"effects": effects,
	}


# -- PLAY_GAME (s15.4 Category 1) ---------------------------------------------

static func _execute_play_game(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var game_skill: String = action.metadata.get("game_skill", "Games: Go")
	var game_trait: String = _GAME_TRAIT_MAP.get(game_skill, "Awareness")

	var a_skill_rank: int = character.skills.get(game_skill, 0)
	var a_trait_val: int = character.traits.get(game_trait, 2)
	var a_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var b_roll: int = 0
	if target != null:
		var b_skill_rank: int = target.skills.get(game_skill, 0)
		var b_trait_val: int = target.traits.get(game_trait, 2)
		b_roll = dice_engine.roll_skill_check(
			b_trait_val, b_skill_rank, 0
		).get("total", 0)

	var resolution: Dictionary = CourtActionSystem.resolve_play_game(
		a_roll, b_roll, character.character_id, target_id
	)

	return {
		"success": true,
		"action_id": "PLAY_GAME",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"play_game_result": resolution,
			"a_disposition_toward_b": resolution["a_disposition_toward_b"],
			"b_disposition_toward_a": resolution["b_disposition_toward_a"],
			"winner_id": resolution["winner_id"],
		},
	}


const _GAME_TRAIT_MAP: Dictionary = {
	"Games: Go": "Intelligence",
	"Games: Shogi": "Intelligence",
	"Games: Kemari": "Agility",
	"Games: Fortunes & Winds": "Awareness",
	"Games: Letters": "Awareness",
	"Games: Sadane": "Awareness",
}


# -- DISCERN_NEED (s15.4 Category 5) ------------------------------------------

static func _execute_discern_need(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var a_skill: String = "Investigation"
	var a_trait_name: String = "Awareness"
	if character.school.begins_with("Yasuki"):
		a_skill = "Commerce"
		a_trait_name = "Perception"
	elif character.school.begins_with("Doji"):
		a_skill = "Courtier"

	var a_skill_rank: int = character.skills.get(a_skill, 0)
	var a_trait_val: int = character.traits.get(a_trait_name, 2)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_awareness: int = target.traits.get("Awareness", 2)
		defender_roll = dice_engine.roll_skill_check(
			d_awareness, d_etiquette, 0
		).get("total", 0)

	var resolution: Dictionary = CourtActionSystem.resolve_discern_need(
		attacker_roll, defender_roll
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["info_gained"] = true
		effects["info_type"] = "priority_objective"
		if resolution.get("detected", false):
			effects["detected"] = true
	else:
		effects["failed"] = true
		if resolution.get("critical_failure", false):
			effects["disposition_change"] = resolution.get("disposition_change", 0)
			effects["detected"] = true

	return {
		"success": resolution.get("success", false),
		"action_id": "DISCERN_NEED",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": a_skill,
		"roll_total": attacker_roll,
		"tn": defender_roll,
		"margin": attacker_roll - defender_roll,
		"effects": effects,
	}


# -- Read Character / Probe (s15.4 Category 5) --------------------------------

static func _execute_read_character(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var a_skill_rank: int = character.skills.get("Investigation", 0)
	var a_trait_val: int = character.traits.get("Perception", 2)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_awareness: int = target.traits.get("Awareness", 2)
		defender_roll = dice_engine.roll_skill_check(
			d_awareness, d_etiquette, 0
		).get("total", 0)

	var resolution: Dictionary = CourtActionSystem.resolve_read_character(
		attacker_roll, defender_roll, dice_engine
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["info_gained"] = true
		effects["info_types"] = resolution.get("info_types", [])
		effects["info_count"] = resolution.get("info_count", 0)
		if resolution.get("partial", false):
			effects["partial"] = true
	else:
		effects["failed"] = true
		if resolution.get("critical_failure", false):
			effects["false_info"] = resolution.get("false_info", [])

	return {
		"success": resolution.get("success", false),
		"action_id": "READ_CHARACTER",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Investigation",
		"roll_total": attacker_roll,
		"tn": defender_roll,
		"margin": attacker_roll - defender_roll,
		"effects": effects,
	}


static func _execute_probe(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	var a_skill_rank: int = character.skills.get("Courtier", 0)
	var a_trait_val: int = character.traits.get("Perception", 2)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var defender_roll: int = 0
	if target != null:
		var d_sincerity: int = target.skills.get("Sincerity", 0)
		var d_awareness: int = target.traits.get("Awareness", 2)
		defender_roll = dice_engine.roll_skill_check(
			d_awareness, d_sincerity, 0
		).get("total", 0)

	var resolution: Dictionary = CourtActionSystem.resolve_probe(
		attacker_roll, defender_roll, dice_engine
	)

	var margin: int = attacker_roll - defender_roll
	var quality: int = maxi(int(margin / 5.0), 1) if margin > 0 else 1

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["info_gained"] = true
		effects["info_types"] = resolution.get("info_types", [])
		effects["info_count"] = resolution.get("info_count", 0)
		effects["quality"] = quality
		if resolution.get("partial", false):
			effects["partial"] = true
		effects["detected"] = true
	else:
		effects["failed"] = true
		effects["detected"] = true
		if resolution.get("critical_failure", false):
			effects["false_info"] = resolution.get("false_info", [])

	return {
		"success": resolution.get("success", false),
		"action_id": "PROBE",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Courtier",
		"roll_total": attacker_roll,
		"tn": defender_roll,
		"margin": margin,
		"effects": effects,
	}


# -- Duel Challenge -----------------------------------------------------------

static func _execute_duel_challenge(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)

	if target == null:
		return {
			"success": false,
			"action_id": "ISSUE_DUEL_CHALLENGE",
			"character_id": ctx.character_id,
			"target_npc_id": target_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {"failed": true, "reason": "target_not_found"},
		}

	var to_death: bool = action.metadata.get("to_death", false)
	var is_sanctioned: bool = action.metadata.get("is_sanctioned", true)

	var duel_result: Dictionary = IndividualCombat.resolve_full_duel(
		character, target, to_death, dice_engine
	)

	var winner_id: int = duel_result.get("winner_id", -1)
	var loser_id: int = duel_result.get("loser_id", -1)
	var simultaneous: bool = duel_result.get("simultaneous", false)

	var challenger_dead: bool = CharacterStats.is_dead(character)
	var defender_dead: bool = CharacterStats.is_dead(target)
	var death_occurred: bool = challenger_dead or defender_dead

	var effects: Dictionary = {
		"duel_result": duel_result,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"simultaneous": simultaneous,
		"death_occurred": death_occurred,
		"challenger_dead": challenger_dead,
		"defender_dead": defender_dead,
	}

	# Glory bonus for winning a witnessed duel at court (s40 / s4.6)
	if winner_id != -1 and ctx.context_flag == Enums.ContextFlag.AT_COURT:
		if winner_id == character.character_id:
			effects["glory_change"] = 0.5
		else:
			effects["winner_glory_change"] = 0.5
			effects["winner_glory_recipient_id"] = winner_id

	# Crime record if an unsanctioned duel caused a death (s40 / s2.8.11)
	if death_occurred and not is_sanctioned:
		var killer_id: int = -1
		if challenger_dead:
			killer_id = target.character_id
		elif defender_dead:
			killer_id = character.character_id
		effects["requires_crime_creation"] = true
		effects["crime_type"] = Enums.CrimeType.UNSANCTIONED_DUEL_DEATH
		effects["crime_perpetrator_id"] = killer_id
		effects["crime_victim_id"] = loser_id

	var actor_is_winner: bool = winner_id == character.character_id
	return {
		"success": not simultaneous and winner_id != -1,
		"action_id": "ISSUE_DUEL_CHALLENGE",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"actor_won": actor_is_winner,
		"effects": effects,
	}


# -- ASK_FOR_INTRODUCTION (s55.7.3 — LOCKED) ----------------------------------

static func _execute_ask_for_introduction(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	var target: L5RCharacterData = characters_by_id.get(target_id)
	var intermediary_id: int = action.metadata.get("intermediary_id", -1)
	var intermediary: L5RCharacterData = characters_by_id.get(intermediary_id)

	var target_is_kuge: bool = false
	if target != null:
		target_is_kuge = target.status >= CourtActionSystem.KUGE_STATUS_THRESHOLD
	var intermediary_status: float = intermediary.status if intermediary != null else 0.0

	# Skill selection: kuge targets use Etiquette/Awareness; others use Courtier/Awareness.
	var skill: String = "Etiquette" if target_is_kuge else "Courtier"
	var skill_rank: int = character.skills.get(skill, 0)
	var trait_val: int = character.traits.get("Awareness", 2)

	# Bureaucracy emphasis grants +1k0 on kuge rolls per s55.7.3.
	var has_emphasis: bool = target_is_kuge and character.skills.has("Bureaucracy")
	var roll_result: Dictionary = dice_engine.roll_skill_check(
		trait_val, skill_rank, 0, 0, 0, has_emphasis
	)
	var roll_total: int = roll_result.get("total", 0)

	var resolution: Dictionary = CourtActionSystem.resolve_ask_for_introduction(
		roll_total, target_is_kuge, intermediary_status
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		effects["contact_added"] = true
		effects["contact_id"] = target_id
		effects["disposition_gain"] = resolution.get("disposition_gain", 0)
		effects["target_is_kuge"] = target_is_kuge
	elif resolution.has("blocked_reason"):
		effects["blocked_reason"] = resolution["blocked_reason"]
		effects["failed"] = true
	else:
		effects["failed"] = true

	return {
		"success": resolution.get("success", false),
		"action_id": "ASK_FOR_INTRODUCTION",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": skill,
		"roll_total": roll_total,
		"tn": CourtActionSystem.ASK_FOR_INTRODUCTION_TN,
		"margin": roll_total - CourtActionSystem.ASK_FOR_INTRODUCTION_TN,
		"effects": effects,
	}


# -- OBSERVE_COURT_ATTENDEES (s55.7.3 — LOCKED) --------------------------------

static func _execute_observe_court_attendees(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var skill_rank: int = character.skills.get("Investigation", 0)
	var trait_val: int = character.traits.get("Perception", 2)
	var roll_result: Dictionary = dice_engine.roll_skill_check(trait_val, skill_rank, 0)
	var roll_total: int = roll_result.get("total", 0)

	var observable_ids: Array = action.metadata.get("observable_attendee_ids", [])
	var resolution: Dictionary = CourtActionSystem.resolve_observe_court_attendees(
		roll_total, observable_ids.size()
	)

	var effects: Dictionary = {}
	if resolution.get("success", false):
		var learn_count: int = resolution.get("learn_count", 0)
		# Pick learn_count random IDs from the observable pool.
		var pool: Array = observable_ids.duplicate()
		var learned_ids: Array[int] = []
		for _i: int in range(learn_count):
			if pool.is_empty():
				break
			var idx: int = dice_engine.roll_and_keep(1, 1, 0).total % pool.size()
			learned_ids.append(int(pool[idx]))
			pool.remove_at(idx)

		var learned_info: Array[Dictionary] = []
		for npc_id: int in learned_ids:
			var npc: L5RCharacterData = characters_by_id.get(npc_id)
			if npc != null:
				learned_info.append({
					"character_id": npc_id,
					"clan": npc.clan,
					"family": npc.family,
					"status": npc.status,
				})

		effects["info_gained"] = true
		effects["learn_count"] = learn_count
		effects["learned_attendees"] = learned_info
	else:
		effects["failed"] = true

	return {
		"success": resolution.get("success", false),
		"action_id": "OBSERVE_COURT_ATTENDEES",
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Investigation",
		"roll_total": roll_total,
		"tn": CourtActionSystem.OBSERVE_COURT_TN,
		"margin": roll_total - CourtActionSystem.OBSERVE_COURT_TN,
		"effects": effects,
	}
