class_name ActionExecutor
## Routes chosen ActionIDs to owning systems per GDD s55.4.7.
## Receives a ScoredAction + character + context, performs the skill roll
## (if applicable), applies effects, and returns a result dictionary.
## This is the bridge between NPC decision and world-state mutation.


static func _get_trait_value_by_name(character: L5RCharacterData, trait_name: String, fallback: int = 2) -> int:
	var lower: String = trait_name.to_lower()
	var val: Variant = character.get(lower)
	if val is int:
		return val
	return fallback


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
	"SHARE_SUPPLIES", "TRANSFER_KOKU", "ASSESS_PROVINCE_STATUS", "EVALUATE_WAR_READINESS",
	"ASSIGN_VASSAL_OBJECTIVE", "CALL_COURT", "SEND_INVITATION",
	"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID", "INVESTIGATE_PROVINCE",
	"INVESTIGATE_RUMOR", "NEGOTIATE_SURRENDER", "CONDUCT_COMMERCE",
	"DISPATCH_COURTIER",
	"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
	"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
	"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION", "DISSOLVE_MARRIAGE",
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

const SOCIAL_BASE_TN: int = 0
const COVERT_BASE_TN: int = 0
const MILITARY_BASE_TN: int = 0
const ADMIN_BASE_TN: int = 0

const BRIBE_KOKU_COST: float = 5.0
const PURCHASE_KOKU_COST: float = 1.0


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
	crime_records: Array = [],
) -> Dictionary:
	var action_id: String = action.action_id

	if character.captive_status != "":
		var captor_id: int = int(character.captive_status) if character.captive_status.is_valid_int() else -1
		var targets_captor: bool = captor_id >= 0 and (
			action.target_npc_id == captor_id or action.target_npc_id_secondary == captor_id
		)
		if HostageSystem.is_action_blocked_for_hostage(action_id, targets_captor):
			return {
				"success": false,
				"action_id": action_id,
				"character_id": ctx.character_id,
				"target_npc_id": action.target_npc_id,
				"target_province_id": action.target_province_id,
				"ic_day": ctx.ic_day,
				"season": ctx.season,
				"reason": "hostage_restricted",
				"effects": {},
			}

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

	if action_id == "DISSOLVE_MARRIAGE":
		return _execute_dissolve_marriage(action, character, ctx, characters_by_id)

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

	if action_id in ["ACCEPT_SEPPUKU", "REFUSE_SEPPUKU"]:
		return _execute_seppuku_response(action, character)

	if action_id == "EXTORT_ACCUSED":
		return _execute_extort_accused(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "EXAMINE_CRIME_SCENE":
		return _execute_examine_crime_scene(action, character, ctx, dice_engine, crime_records)

	if action_id == "EXAMINE_LETTER":
		return _execute_examine_letter(action, character, ctx)

	if action_id == "TREAT_WOUND":
		return _execute_treat_wound(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "MEDITATE":
		return _execute_meditate(action, character, ctx, dice_engine)

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

	if action_id == "REQUEST_PERFORMANCE":
		return _execute_request_performance(action, character, ctx)

	if action_id == "CONDUCT_TEA_CEREMONY":
		return _execute_conduct_tea_ceremony(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "TRAIN_ANIMAL":
		return _execute_train_animal(action, character, ctx, dice_engine)

	if action_id == "APPLY_TATTOO":
		return _execute_apply_tattoo(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "TRANSFER_KOKU":
		var koku_result: Dictionary = _execute_transfer_koku(action, character, characters_by_id)
		return {
			"success": koku_result.get("success", false),
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": koku_result,
		}

	if action_id == "MENTOR":
		var mentor_result: Dictionary = _execute_mentor(action, ctx, characters_by_id)
		return {
			"success": mentor_result.get("success", false),
			"action_id": action_id,
			"character_id": character.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": mentor_result,
		}

	if action_id == "PETITION_RONIN":
		return _execute_petition_ronin(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "ACCEPT_RONIN_PETITION":
		return _execute_accept_ronin_petition(action, character, ctx, characters_by_id)

	if action_id == "HIRE_RONIN":
		return _execute_hire_ronin(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "PERFORM_CLAN_INDUCTION":
		return _execute_perform_clan_induction(action, character, ctx, dice_engine, characters_by_id)

	if action_id == "APPROVE_CLAN_INDUCTION":
		return _execute_approve_clan_induction(action, character, ctx, characters_by_id)

	if action_id == "TERMINATE_CONTRACT":
		return _execute_terminate_contract(action, character, ctx, characters_by_id)

	if action_id == "CRAFT":
		return _execute_craft(action, character, ctx, dice_engine)

	if action_id == "DECLARE_SENBAZURU":
		return _execute_declare_senbazuru(action, character, ctx)

	if action_id == "PRESENT_SENBAZURU":
		return _execute_present_senbazuru(action, character, ctx)

	if action_id in ["COMPOSE_THEATER_PIECE", "LEARN_THEATER_PIECE",
			"PERFORM_THEATER_PIECE", "DEDICATE_PIECE"]:
		return _execute_theater_action(action_id, action, character, ctx, dice_engine)

	if action_id == "INVOKE_FAVOR":
		return _execute_invoke_favor(action, character, ctx)

	if action_id == "ANNOUNCE_HUNT":
		return _execute_announce_hunt(action, character, ctx)

	if action_id == "REQUEST_HUNT_INVITATION":
		return _execute_request_hunt_invitation(action, character, ctx)

	if action_id == "CANCEL_HUNT":
		return _execute_cancel_hunt(action, character, ctx)

	if action_id == "COMMISSION_ASSASSINATION":
		return _execute_commission_assassination(action, character, ctx, characters_by_id)

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

	if action_id in ["REQUEST_ART", "OFFER_ART_COMMISSION"]:
		return _execute_garden_commission_action(action, character, ctx)

	if action_id == "CULTIVATE_GARDEN":
		return _execute_cultivate_garden(action, character, ctx, dice_engine)

	if action_id == "MAINTAIN_GARDEN":
		return _execute_maintain_garden(action, character, ctx, dice_engine)

	if action_id == "COLLECT_BONSAI_SPECIMEN":
		return _execute_collect_bonsai_specimen(action, character, ctx, dice_engine)

	if action_id == "TEND_BONSAI":
		return _execute_tend_bonsai(action, character, ctx, dice_engine)

	if action_id == "DISPLAY_BONSAI":
		return _execute_display_bonsai(action, character, ctx)

	if action_id in ["COMPOSE_PAINTING", "DISPLAY_PAINTING", "PRESENT_EMAKIMONO"]:
		return _execute_painting_action(action_id, action, character, ctx, dice_engine, characters_by_id)

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
	var history_bonus: int = gift_item.get("history_point_bonus", 0)

	# Noshi wrapping bonus (s57.26.6–57.26.8): scan for best noshi in inventory.
	var noshi_item_id: int = -1
	var noshi_is_mundane: bool = false
	for _noshi: Dictionary in character.items:
		if _noshi.get("item_type", "") == "noshi":
			var _nt: int = _noshi.get("quality_tier", 0)
			if not noshi_is_mundane or _nt > 0:
				history_bonus += maxi(0, _nt - 1)  # FR = quality_tier - 1 (0 for Mundane)
				noshi_is_mundane = _noshi.get("is_mundane", false)
				noshi_item_id = _noshi.get("item_id", -1)
			break

	var gift_result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		character, recipient, tier, subtype, archetype, dice_engine, ctx.ic_day,
		history_bonus,
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
		"noshi_item_id": noshi_item_id,
		"noshi_is_mundane": noshi_is_mundane,
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

	if action.action_id == "TRAIN":
		# s48: solo training applies 50 progress per AP to the character's
		# highest-priority training target. Locked in s48a A48a-4.
		var train_result: Dictionary = NPCAdvancement.apply_solo_training_progress(character)
		effects["training_result"] = train_result
		effects["effect"] = "trained" if not train_result.get("reason", "") == "nothing_to_train" else "nothing_to_train"
		if ctx.festival_glory_martial > 0.001:
			effects["glory_change"] = ctx.festival_glory_martial

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
	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)
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
		var witness_ids: Array = _get_co_located_ids(character, characters_by_id)
		r = IntimidationSystem.resolve_public_intimidation(
			attacker_roll, defender_roll, target.honor, 0, witness_ids, disp_tier
		)
	else:
		r = IntimidationSystem.resolve_private_intimidation(
			attacker_roll, defender_roll, target.honor, by_letter, 0, disp_tier
		)

	var effects: Dictionary = {
		"disposition_change": -(3 + int(clampi(attacker_roll - defender_roll, 0, 25) / 5)) if r["success"] else 0,
		"honor_change": CrimeSystem.get_low_skill_honor_cost(character, "Intimidation"),
		"infamy_gain": r.get("infamy_gain", 0.0),
		"compliance_active": r.get("compliance_active", false),
	}

	if not r["success"]:
		effects["failed"] = true

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

	var base_tn: int = clampi(
		10 + int(subject_glory) * 5 - int(character.glory) * 5,
		5, 60
	)

	var listener: L5RCharacterData = characters_by_id.get(listener_id)
	var deception_tn: int = SkillResolver.get_deception_defense_bonus(listener) if listener != null else 0
	var tn: int = base_tn + deception_tn

	var skill_entry: Dictionary = action_skill_map.get("GOSSIP", {})
	var primary_skill: String = skill_entry.get("primary", "Courtier")
	var primary_trait: String = skill_entry.get("secondary", "Awareness")
	var skill_rank: int = character.skills.get(primary_skill, 0)
	var trait_val: int = _get_trait_value_by_name(character, primary_trait)
	var gossip_wc: int = _get_winter_court_skill_bonus(character, primary_skill, ctx)
	var roll_result: Dictionary = dice_engine.roll_skill_check(
		trait_val, skill_rank, tn
	)

	var roll_total: int = roll_result.get("total", 0) + gossip_wc
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
	var trait_val: int = _get_trait_value_by_name(character, primary_trait)

	var insult_wc: int = _get_winter_court_skill_bonus(character, primary_skill, ctx)
	var attacker_total: int = dice_engine.roll_skill_check(
		trait_val, skill_rank, 0
	).get("total", 0) + insult_wc

	var defender_total: int = 0
	if target != null:
		var def_etiquette: int = target.skills.get("Etiquette", 0)
		var def_awareness: int = target.awareness
		defender_total = dice_engine.roll_skill_check(
			def_awareness, def_etiquette, 0
		).get("total", 0)

	var success: bool = attacker_total >= defender_total
	var margin: int = attacker_total - defender_total
	var raises: int = maxi(int(margin / 5.0), 0)
	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)

	var insult_type: String = action.metadata.get("insult_type", "self")

	var effects: Dictionary = {}
	if success:
		var per_witness_disp: int = -2 - raises
		effects = {
			"target_witness_disposition": per_witness_disp,
			"witnesses": witness_ids,
			"insult_type": insult_type,
		}
	else:
		var backfire_disp: int = -2
		effects = {
			"failed": true,
			"witness_disposition_loss": backfire_disp,
			"witnesses": witness_ids,
			"insult_type": insult_type,
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
	var broadcast_wc: int = _get_winter_court_skill_bonus(character, primary_skill, ctx)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, primary_skill, tn, 0, "", Enums.Trait.NONE, 0, 0, broadcast_wc
	)

	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("total", 0) - tn
	var raises: int = maxi(int(margin / 5.0), 0)
	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)

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
	var a_trait_val: int = _get_trait_value_by_name(character, a_trait_name)
	var debate_wc: int = _get_winter_court_skill_bonus(character, primary_skill, ctx)
	var a_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + debate_wc

	var b_roll: int = 0
	if target != null:
		var b_courtier: int = target.skills.get("Courtier", 0)
		var b_awareness: int = target.awareness
		b_roll = dice_engine.roll_skill_check(
			b_awareness, b_courtier, 0
		).get("total", 0)

	var margin: int = a_roll - b_roll
	var raises: int = maxi(int(margin / 5.0), 0) if margin > 0 else 0
	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)

	var witness_disp_a: Dictionary = {}
	var witness_disp_b: Dictionary = {}
	for wid: int in witness_ids:
		var w: L5RCharacterData = characters_by_id.get(wid)
		if w != null and not CharacterStats.is_dead(w):
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
		"metadata": action.metadata,
	}


static func _resolve_bribe_attempt(
	briber: L5RCharacterData,
	magistrate: L5RCharacterData,
	action: NPCDataStructures.ScoredAction,
	dice_engine: DiceEngine,
) -> Dictionary:
	var bribe_result: Dictionary = BriberySystem.attempt_bribe(briber, magistrate, dice_engine)
	var result: int = bribe_result.get("result", BriberySystem.BribeResult.REFUSED)
	var success: bool = result == BriberySystem.BribeResult.ACCEPTED
	var blocked: bool = result == BriberySystem.BribeResult.BLOCKED_BY_PERSONALITY
	var suppress_case: bool = action.metadata.get("suppress_case", false)
	var r: Dictionary = {
		"success": success,
		"blocked_by_personality": blocked,
		"roll_total": bribe_result.get("briber_total", 0),
		"tn": bribe_result.get("magistrate_total", 0),
		"margin": bribe_result.get("briber_total", 0) - bribe_result.get("magistrate_total", 0),
		"detection_risk": not success,
		"suppress_case": suppress_case,
		"magistrate_id": magistrate.character_id,
	}
	if not blocked:
		r["koku_cost"] = BRIBE_KOKU_COST
	if not success and not blocked:
		r["failed"] = true
	return r


# -- Witness Tampering (s11.3.13c) --------------------------------------------

static func _resolve_bribe_witness(
	criminal: L5RCharacterData,
	witness: L5RCharacterData,
	_action: NPCDataStructures.ScoredAction,
	dice_engine: DiceEngine,
) -> Dictionary:
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(witness) * 5
	var contested: Dictionary = SkillResolver.resolve_contested_check(
		criminal, witness, dice_engine,
		"Temptation", "Etiquette",
		"", "", Enums.Trait.NONE, Enums.Trait.WILLPOWER,
		0, 0, 0, honor_bonus,
	)
	var attack_total: int = contested.get("total_a", 0)
	var defense_total: int = contested.get("total_b", 0)
	var success: bool = contested.get("winner") == "a"
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
	var honor_bonus: int = HonorGlorySystem.get_honor_rank(witness) * 5
	var contested: Dictionary = SkillResolver.resolve_contested_check(
		criminal, witness, dice_engine,
		"Intimidation", "Etiquette",
		"", "", Enums.Trait.NONE, Enums.Trait.WILLPOWER,
		0, 0, 0, honor_bonus,
	)
	var attack_total: int = contested.get("total_a", 0)
	var defense_total: int = contested.get("total_b", 0)
	var success: bool = contested.get("winner") == "a"
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
	var contested: Dictionary = SkillResolver.resolve_contested_check(
		killer, victim, dice_engine,
		"Stealth", "Investigation",
	)
	var attack_total: int = contested.get("total_a", 0)
	var defense_total: int = contested.get("total_b", 0)
	var success: bool = contested.get("winner") == "a"
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
	r["subject_id"] = subject_id
	r["secret_id"] = secret.secret_id

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
	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)
	var r: Dictionary = SecretSystem.expose_publicly(secret, character, subject, witness_ids, characters_by_id, has_proof)
	r["subject_id"] = subject_id
	r["secret_id"] = secret.secret_id

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
) -> Array:
	var ids: Array = []
	var loc: String = character.physical_location
	if loc.is_empty():
		return ids
	for cid: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid]
		if c.character_id != character.character_id and c.physical_location == loc \
				and not CharacterStats.is_dead(c):
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
	ctx: NPCDataStructures.ContextSnapshot,
) -> void:
	var effects: Dictionary = {}
	var action_id: String = action.action_id

	if action_id == "PUBLIC_ATONEMENT":
		effects = _compute_atonement_effects(action, result, _character)
		var offense_key: String = action.metadata.get("offense_key", "")
		if not offense_key.is_empty():
			HonorGlorySystem.record_atonement(_character, offense_key)
	elif action_id == "REQUEST_ALLIED_AID":
		effects = _compute_allied_aid_effects(action, ctx, result["success"])
	elif result["success"]:
		if action_id in SOCIAL_ACTIONS:
			effects = _compute_social_effects(action_id, result["margin"])
			if action_id == "NEGOTIATE" and action != null:
				var nt: String = action.metadata.get("need_type", "")
				if nt in RESOURCE_PROMISE_NEED_TYPES and action.target_npc_id >= 0:
					effects["requires_resource_promise"] = true
					effects["promise_creditor_id"] = ctx.character_id
					effects["promise_debtor_id"] = action.target_npc_id
					effects["promise_tier"] = _resource_tier_from_metadata(action.metadata)
					effects["source_action_id"] = "NEGOTIATE"
					effects["is_crisis_request"] = nt in CRISIS_NEED_TYPES
		elif action_id in COVERT_ACTIONS:
			effects = _compute_covert_effects(action_id, result["margin"])
		elif action_id in MILITARY_ORDERS:
			effects = _compute_military_effects(action_id, action)
		elif action_id in ADMINISTRATIVE_ACTIONS:
			effects = _compute_admin_effects(action_id, action)
		elif action_id in INTELLIGENCE_ACTIONS:
			effects = _compute_intelligence_effects(action_id, result.get("margin", 0))
		else:
			effects = _compute_self_effects(action_id)
	else:
		effects = _compute_failure_effects(action_id, result.get("margin", 0))

	if action_id == "WRITE_LETTER" and result.get("success", false) and ctx.festival_glory_poetry > 0.001:
		effects["glory_change"] = effects.get("glory_change", 0.0) + ctx.festival_glory_poetry

	# Commerce stigma (s57.40): fires on public Commerce rolls regardless of success
	if CommerceStigmaSystem.is_public_commerce(action_id, ctx):
		var stigma: Dictionary = CommerceStigmaSystem.apply_stigma(_character, ctx)
		if stigma["stigma_fired"]:
			effects["honor_change"] = effects.get("honor_change", 0.0) + stigma["stigma_honor_change"]
			effects["glory_change"] = effects.get("glory_change", 0.0) + stigma["stigma_glory_change"]
		if stigma["public_commerce_topic"]:
			effects["public_commerce_topic"] = true

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


# GDD s12.2 LOCKED: Friend tier = +31 to +60. Lords accept allied aid from characters
# at Friend tier or above — the threshold where genuine mutual trust exists.
const ALLIED_AID_ACCEPT_THRESHOLD: int = 31

const RESOURCE_PROMISE_NEED_TYPES: Array[String] = [
	"ACQUIRE_RESOURCE", "REQUEST_AID", "CONDUCT_COMMERCE",
]

const CRISIS_NEED_TYPES: Array[String] = [
	"DEFEND_PROVINCE", "REQUEST_AID",
]

const RESOURCE_TIER_KOKU_THRESHOLDS: Array[int] = [10, 50]
const RESOURCE_TIER_PU_THRESHOLDS: Array[int] = [5, 20]


static func _resource_tier_from_metadata(metadata: Dictionary) -> int:
	var koku: float = metadata.get("koku_amount", 0.0)
	var pu: int = metadata.get("pu_amount", 0)
	if koku > RESOURCE_TIER_KOKU_THRESHOLDS[1] or pu > RESOURCE_TIER_PU_THRESHOLDS[1]:
		return 1
	if koku >= RESOURCE_TIER_KOKU_THRESHOLDS[0] or pu >= RESOURCE_TIER_PU_THRESHOLDS[0]:
		return 2
	return 3

static func _compute_allied_aid_effects(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
	roll_success: bool,
) -> Dictionary:
	if not roll_success:
		return {"effect": "aid_request_failed", "failed": true}

	var target_id: int = action.target_npc_id
	if target_id < 0:
		return {"effect": "aid_request_failed", "failed": true, "reason": "no_target"}

	var target_disp: int = ctx.dispositions.get(target_id, 0)
	if target_disp < ALLIED_AID_ACCEPT_THRESHOLD:
		return {"effect": "aid_refused", "failed": true, "reason": "disposition_too_low"}

	return {
		"effect": "aid_accepted",
		"requires_resource_promise": true,
		"promise_creditor_id": ctx.character_id,
		"promise_debtor_id": target_id,
		"is_crisis_request": true,
	}


static func _compute_admin_effects(action_id: String, action: NPCDataStructures.ScoredAction = null) -> Dictionary:
	match action_id:
		"SET_TAX_RATE", "SET_STIPEND_RATE":
			return {"effect": "rate_adjusted"}
		"PURCHASE_MARKET":
			return {"effect": "transaction_completed", "koku_cost": PURCHASE_KOKU_COST}
		"SHARE_SUPPLIES":
			return {
				"effect": "supplies_shared",
				"requires_supply_sharing": true,
			}
		"TRANSFER_KOKU":
			return {"effect": "koku_transferred"}
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
			return {"effect": "aid_requested", "failed": true}
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
		"ASSIGN_VASSAL_OBJECTIVE":
			return _compute_assign_vassal_objective_effects(action)
		"SEND_INVITATION":
			return _compute_send_invitation_effects(action)
		"CALL_COURT":
			return _compute_call_court_effects(action)
	return {"effect": "administrative_action"}


static func _compute_assign_vassal_objective_effects(
	action: NPCDataStructures.ScoredAction,
) -> Dictionary:
	var vassal_id: int = action.target_npc_id if action != null else -1
	var need_type: String = action.metadata.get("need_type", "") if action != null else ""
	var result: Dictionary = {
		"effect": "vassal_objective_assigned",
		"requires_vassal_objective_assignment": true,
		"vassal_id": vassal_id,
		"assigned_need_type": need_type,
	}
	if action != null:
		if action.target_province_id >= 0:
			result["target_province_id"] = action.target_province_id
		var target_clan: String = action.metadata.get("target_clan", "")
		if not target_clan.is_empty():
			result["target_clan"] = target_clan
		var target_npc: int = action.metadata.get("target_npc_id", -1)
		if target_npc >= 0:
			result["objective_target_npc_id"] = target_npc
		if need_type in RESOURCE_PROMISE_NEED_TYPES and vassal_id >= 0:
			var lord_id: int = action.metadata.get("lord_id", -1) if action != null else -1
			if lord_id >= 0:
				result["requires_resource_promise"] = true
				result["promise_creditor_id"] = lord_id
				result["promise_debtor_id"] = vassal_id
				result["promise_tier"] = _resource_tier_from_metadata(action.metadata)
				result["source_action_id"] = "ASSIGN_VASSAL_OBJECTIVE"
				result["is_crisis_request"] = need_type in CRISIS_NEED_TYPES
	return result


static func _compute_send_invitation_effects(
	action: NPCDataStructures.ScoredAction,
) -> Dictionary:
	var invitee_id: int = action.target_npc_id if action != null else -1
	var settlement_id: int = action.target_settlement_id if action != null else -1
	return {
		"effect": "invitation_sent",
		"requires_court_invitation": true,
		"invitee_id": invitee_id,
		"invitation_settlement_id": settlement_id,
		"recipient_disposition_change": 5,
	}


static func _compute_call_court_effects(
	action: NPCDataStructures.ScoredAction,
) -> Dictionary:
	var settlement_id: int = action.target_settlement_id if action != null else -1
	return {
		"effect": "court_called",
		"requires_court_creation": true,
		"court_settlement_id": settlement_id,
		"glory_change": 0.1,
	}


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
				"recipient_disposition_change": 2,
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
				"failed": true,
				"garrison_refused": true,
				"target_npc_id": target_id,
				"target_province_id": target_province_id,
				"honor_change_recipient": honor_loss,
				"recipient_disposition_change": -2,
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
	var theology_rank: int = character.skills.get("Lore: Theology", 0)

	var location_type: String = action.metadata.get("location_type", "roadside_shrine")

	# Gohei Free Raises (s57.26.12–57.26.13): scan for highest-quality gohei.
	var gohei_item_id: int = -1
	var gohei_fr: int = 0
	var best_gohei_tier: int = -1
	for _g: Dictionary in character.items:
		if _g.get("item_type", "") == "gohei" and _g.get("uses_remaining", 0) > 0:
			var _gt: int = _g.get("quality_tier", 0)
			if _gt > best_gohei_tier:
				best_gohei_tier = _gt
				gohei_item_id = _g.get("item_id", -1)
	if gohei_item_id >= 0:
		gohei_fr = maxi(0, best_gohei_tier - 1)

	var worship_result: Dictionary = WorshipSystem.resolve_active_worship(
		char_type, is_shugenja, dice_engine, ring_value, theology_rank,
		location_type, directed_fortune,
	)

	var province_id: int = action.target_province_id

	var honor_bonus: float = ctx.festival_honor_gain
	if ctx.festival_has_lion_honor and character.clan == "lion":
		honor_bonus += 0.1

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
			"gohei_item_id": gohei_item_id,
			"gohei_fr": gohei_fr,
			"bonus_wp": worship_result.get("bonus_wp", 0.0),
			"directed": worship_result.get("directed", false),
			"honor_change": honor_bonus,
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
	var ss: int = action.metadata.get("ss", -1)
	var si: int = 10
	var garrison_above_minimum: bool = true
	var jade_stockpile_critical: bool = false

	for ws_variant: Variant in ctx.wall_statuses:
		if not ws_variant is NPCDataStructures.WallStatus:
			continue
		var ws: NPCDataStructures.WallStatus = ws_variant as NPCDataStructures.WallStatus
		if ws.province_id == target_province_id or target_province_id < 0:
			ss = ws.ss if ss < 0 else ss
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
		"siege_settlement_id", -1,
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
	# s57.41.1: Engineering Rank 5 mastery grants +5 flat bonus on cumulative rolls.
	var eng_rank: int = character.skills.get("Engineering", 0)
	var mastery_bonus: int = 5 if eng_rank >= 5 else 0
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Engineering", tn,
		0, "", Enums.Trait.NONE, 0, 0, mastery_bonus
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

	var seal_effects: Dictionary = {
		"effect": "breach_sealed" if success else "breach_seal_failed",
		"requires_breach_seal": success,
		"koku_cost": SEAL_KOKU_COST,
		"target_province_id": target_province_id,
	}
	if not success:
		seal_effects["failed"] = true

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
		"effects": seal_effects,
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
			return {"effect": "mentor_offered"}
		"OBSERVE_COURT_ATTENDEES":
			return {"effect": "court_observed", "info_gained": true}  # fallback — should not reach here
	return {"effect": "self_action_completed"}


static func _compute_atonement_effects(
	action: NPCDataStructures.ScoredAction,
	result: Dictionary,
	character: L5RCharacterData = null,
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
		var crit_honor: float = CrimeSystem.scale_honor_by_rank(HonorGlorySystem.ATONEMENT_CRITICAL_FAIL_HONOR_LOSS, character) if character != null else HonorGlorySystem.ATONEMENT_CRITICAL_FAIL_HONOR_LOSS
		return {
			"effect": "atonement_critical_failure",
			"failed": true,
			"honor_change": crit_honor,
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
		if ctx.is_lord and (
			action_id in CivilianOrderBudget.MILITARY_OR_CIVILIAN_ACTIONS
			or action_id in CivilianOrderBudget.PURE_ORDER_ACTIONS
		):
			return {"valid": true}
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
	crime_records: Array,
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
			"roll_total": exam_result.get("roll_total", 0),
		},
	}


static func _find_crime_record(
	case_id: int,
	crime_records: Array,
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


# -- Treat Wound --------------------------------------------------------------

static func _execute_treat_wound(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	if target_id < 0 or characters_by_id.is_empty():
		return {
			"success": false,
			"action_id": "TREAT_WOUND",
			"character_id": character.character_id,
			"target_npc_id": target_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "no_target",
			"effects": {},
		}

	var target: L5RCharacterData = characters_by_id.get(target_id)
	if target == null:
		return {
			"success": false,
			"action_id": "TREAT_WOUND",
			"character_id": character.character_id,
			"target_npc_id": target_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "target_not_found",
			"effects": {},
		}

	var can_check: Dictionary = MedicineSystem.can_treat(character, target, ctx.ic_day)
	if not can_check["valid"]:
		return {
			"success": false,
			"action_id": "TREAT_WOUND",
			"character_id": character.character_id,
			"target_npc_id": target_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": can_check["reason"],
			"effects": {},
		}

	# Witnesses: all characters in zone except healer and target.
	var witness_count: int = 0
	for present_id: int in ctx.characters_present:
		if present_id != character.character_id and present_id != target_id:
			witness_count += 1

	if MedicineSystem.evaluate_refusal(target, character, witness_count):
		return {
			"success": false,
			"action_id": "TREAT_WOUND",
			"character_id": character.character_id,
			"target_npc_id": target_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "treatment_refused",
			"effects": {},
		}

	var raises: int = action.metadata.get("raises", 0)
	var treat_result: Dictionary = MedicineSystem.treat_wound(
		character, target, dice_engine, ctx.ic_day, raises
	)

	return {
		"success": treat_result["success"],
		"action_id": "TREAT_WOUND",
		"character_id": character.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Medicine",
		"roll_total": treat_result.get("roll_total", 0),
		"tn": treat_result.get("tn", MedicineSystem.BASE_TN),
		"raises": raises,
		"effects": {
			"wounds_healed": treat_result["wounds_healed"],
			"kit_charge_consumed": treat_result["kit_charge_consumed"],
			"target_id": target_id,
			"wound_level_after": treat_result.get("wound_level_after", -1),
		},
	}


# -- Meditate -----------------------------------------------------------------
# Meditation (Void Recovery) / Void vs TN 20. Recovers VP per rank mastery.
# Rank 1–2: 1 VP. Rank 3–6: up to 2 VP. Rank 7+: up to 3 VP (s57.32.3).

static func _execute_meditate(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	const MEDITATE_TN: int = 20
	const MASTERY_RANK3: int = 3
	const MASTERY_RANK7: int = 7

	if character.current_void_points >= character.max_void_points:
		return {
			"success": false,
			"action_id": "MEDITATE",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "pool_full",
			"effects": {},
		}

	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Meditation", MEDITATE_TN, 0,
		"Void Recovery", Enums.Trait.VOID,
	)

	var result: Dictionary = {
		"success": check["success"],
		"action_id": "MEDITATE",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Meditation",
		"roll_total": check.get("total", 0),
		"tn": MEDITATE_TN,
		"effects": {
			"void_recovered": 0,
		},
	}

	if not check["success"]:
		return result

	var med_rank: int = SkillResolver.get_skill_rank(character, "Meditation")
	var recovery_cap: int = 1
	if med_rank >= MASTERY_RANK7:
		recovery_cap = 3
	elif med_rank >= MASTERY_RANK3:
		recovery_cap = 2

	var recoverable: int = character.max_void_points - character.current_void_points
	var recovered: int = mini(recovery_cap, recoverable)
	character.current_void_points += recovered
	result["effects"]["void_recovered"] = recovered

	return result


static func _execute_seppuku_response(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
) -> Dictionary:
	var case_id: int = action.metadata.get("case_id", -1)
	return {
		"success": true,
		"action_id": action.action_id,
		"character_id": character.character_id,
		"effects": {
			"case_id": case_id,
			"accepted": action.action_id == "ACCEPT_SEPPUKU",
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

	var honor_bonus: int = HonorGlorySystem.get_honor_rank(suspect) * 5
	var contested: Dictionary = SkillResolver.resolve_contested_check(
		character, suspect, dice_engine,
		"Intimidation", "Etiquette",
		"", "", Enums.Trait.NONE, Enums.Trait.WILLPOWER,
		0, 0, 0, honor_bonus,
	)
	var total: int = contested.get("total_a", 0)
	var tn: int = contested.get("total_b", 0)
	var success: bool = contested.get("winner") == "a"

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

	var honor: float = CrimeSystem.scale_honor_by_rank(-0.5, character) if intended_tier == WarJustification.MilitaryTier.TOTAL_WAR else 0.0
	var ladder_effects: Dictionary = justification.get("ladder_side_effects", {})
	if ladder_effects.has("honor_cost"):
		honor += CrimeSystem.scale_honor_by_rank(ladder_effects["honor_cost"], character)

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

static func _execute_petition_ronin(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var lord_id: int = action.metadata.get("target_lord_id", action.target_npc_id)
	var ic_day: int = ctx.ic_day

	if lord_id < 0:
		return {
			"success": false,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "no_lord_present",
			"effects": {},
		}

	# Per-lord cooldown check: failed rolls set a per-lord key (s52.5 A46).
	var cooldown_key: String = "petition_refused_until_%d" % lord_id
	var refused_until: int = character.supply_ledger.get(cooldown_key, -1)
	if refused_until >= 0 and ic_day < refused_until:
		return {
			"success": false,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": lord_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "petition_cooldown",
			"effects": {},
		}

	var target_lord: L5RCharacterData = characters_by_id.get(lord_id) as L5RCharacterData
	if target_lord == null or CharacterStats.is_dead(target_lord):
		return {
			"success": false,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": lord_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "lord_unavailable",
			"effects": {},
		}

	var lord_disp: int = int(ctx.disposition_values.get(lord_id, 0))
	var known_crimes: Array = []  # TODO: wire via ctx when crime-knowledge system exposes this
	if RoninSystem.lord_auto_rejects(target_lord, character, lord_disp, known_crimes):
		# Auto-rejection: lord refuses to grant an audience. No roll was made,
		# so no roll-failure consequences apply (s52.5 Part B — penalties are for failed rolls).
		return {
			"success": false,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": lord_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "auto_rejected",
			"effects": {},
		}

	var petition_result: Dictionary = RoninSystem.resolve_petition(
		character, target_lord, dice_engine, lord_disp
	)
	var margin: int = petition_result.get("margin", 0)
	var presentation_modifier: int = petition_result.get("presentation_modifier", 0)
	var effective_disp: int = lord_disp + presentation_modifier
	var accepted: bool = petition_result.get("success", false) and effective_disp >= 0

	if accepted:
		return {
			"success": true,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": lord_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"effects": {
				"requires_ronin_acceptance": true,
				"accepting_lord_id": lord_id,
				"ronin_id": character.character_id,
				"margin": margin,
			},
		}
	else:
		# Failed roll: -3 disposition on lord, 90-day per-lord cooldown (s52.5 Part B, A45–A46).
		return {
			"success": false,
			"action_id": "PETITION_RONIN",
			"character_id": character.character_id,
			"target_npc_id": lord_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "petition_refused",
			"effects": {
				"failed": true,
				"petition_refused_until": ic_day + RoninSystem.PETITION_COOLDOWN_DAYS,
				"recipient_disposition_change": RoninSystem.PETITION_FAILURE_DISPOSITION_PENALTY,
				"recipient_id": lord_id,
			},
		}


static func _execute_accept_ronin_petition(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var ronin_id: int = action.metadata.get("target_ronin_id", action.target_npc_id)
	var ic_day: int = ctx.ic_day

	if ronin_id < 0:
		return {
			"success": false,
			"action_id": "ACCEPT_RONIN_PETITION",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "no_ronin_present",
			"effects": {},
		}

	var ronin: L5RCharacterData = characters_by_id.get(ronin_id) as L5RCharacterData
	if ronin == null or CharacterStats.is_dead(ronin):
		return {
			"success": false,
			"action_id": "ACCEPT_RONIN_PETITION",
			"character_id": character.character_id,
			"target_npc_id": ronin_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "ronin_unavailable",
			"effects": {},
		}

	if not RoninSystem.is_ronin(ronin) or ronin.permanent_ronin:
		return {
			"success": false,
			"action_id": "ACCEPT_RONIN_PETITION",
			"character_id": character.character_id,
			"target_npc_id": ronin_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "not_eligible",
			"effects": {},
		}

	# Lord must have positive or neutral disposition toward the ronin.
	var lord_disp: int = 0
	for disp_key: Variant in character.disposition_values:
		if int(disp_key) == ronin_id:
			lord_disp = int(character.disposition_values[disp_key])
			break
	if lord_disp < 0:
		return {
			"success": false,
			"action_id": "ACCEPT_RONIN_PETITION",
			"character_id": character.character_id,
			"target_npc_id": ronin_id,
			"ic_day": ic_day,
			"season": ctx.season,
			"reason": "disposition_too_low",
			"effects": {},
		}

	return {
		"success": true,
		"action_id": "ACCEPT_RONIN_PETITION",
		"character_id": character.character_id,
		"target_npc_id": ronin_id,
		"ic_day": ic_day,
		"season": ctx.season,
		"effects": {
			"requires_ronin_acceptance": true,
			"accepting_lord_id": character.character_id,
			"ronin_id": ronin_id,
		},
	}


static func _execute_hire_ronin(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var ic_day: int = ctx.ic_day
	var ronin_id: int = action.metadata.get("target_ronin_id", -1)
	var contract_type: String = action.metadata.get("contract_type", "PROVINCE_DEFENSE")
	var duration_seasons: int = int(action.metadata.get("duration_seasons", 1))

	if ronin_id < 0:
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "no_ronin_present", "effects": {},
		}

	var ronin: L5RCharacterData = characters_by_id.get(ronin_id) as L5RCharacterData
	if ronin == null or CharacterStats.is_dead(ronin):
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "ronin_unavailable", "effects": {},
		}
	if not RoninSystem.is_ronin(ronin) or ronin.permanent_ronin:
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "not_eligible", "effects": {},
		}
	if ronin.supply_ledger.get("contract_end_ic_day", -1) >= 0:
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "already_contracted", "effects": {},
		}

	var lord_disp: int = int(ronin.disposition_values.get(character.character_id, 0))
	if lord_disp <= -1:
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "ronin_dislikes_lord", "effects": {},
		}

	var payment: float = RoninSystem.get_contract_payment(contract_type, duration_seasons)
	if character.koku < payment:
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "insufficient_koku", "effects": {},
		}

	# Courtier/Awareness vs TN 10 — confirming the lord can articulate contract terms.
	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Courtier", 10, ic_day,
	)
	if not check.get("success", false):
		return {
			"success": false, "action_id": "HIRE_RONIN",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "offer_fumbled", "effects": {},
		}

	return {
		"success": true, "action_id": "HIRE_RONIN",
		"character_id": character.character_id, "target_npc_id": ronin_id,
		"ic_day": ic_day, "season": ctx.season,
		"effects": {
			"injects_reactive_event": true,
			"reactive_type": "CONTRACT_OFFERED",
			"lord_id": character.character_id,
			"lord_status": character.status,
			"ronin_id": ronin_id,
			"contract_type": contract_type,
			"duration_seasons": duration_seasons,
			"payment": payment,
			"current_season": ctx.season,
		},
	}


static func _execute_perform_clan_induction(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var ic_day: int = ctx.ic_day
	var ronin_id: int = action.metadata.get("target_ronin_id", -1)

	# Only Provincial Daimyo or higher may sponsor induction (s52.7 Part A).
	if character.lord_rank < Enums.LordRank.PROVINCIAL_DAIMYO:
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "sponsoring_lord_rank_too_low", "effects": {},
		}

	if ronin_id < 0:
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "no_ronin_present", "effects": {},
		}

	var inductee: L5RCharacterData = characters_by_id.get(ronin_id) as L5RCharacterData
	if inductee == null or CharacterStats.is_dead(inductee):
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "inductee_unavailable", "effects": {},
		}

	# Koku check — must have enough before the ceremony begins.
	if character.koku < RoninSystem.INDUCTION_KOKU_COST:
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "insufficient_koku", "effects": {},
		}

	var lord_disp: int = int(character.disposition_values.get(ronin_id, 0))
	var eligibility: Dictionary = RoninSystem.can_be_inducted(inductee, character, lord_disp, [])
	if not eligibility.get("eligible", false):
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": eligibility.get("reason", "ineligible"), "effects": {},
		}

	# Koku deducted after eligibility confirmed (Pattern B — paid before the roll).
	character.koku -= RoninSystem.INDUCTION_KOKU_COST

	# Courtier/Awareness vs TN 20 — ceremony must be performed with proper rites.
	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Courtier", 20, ic_day,
	)
	if not check.get("success", false):
		return {
			"success": false, "action_id": "PERFORM_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "ceremony_failed",
			"effects": {"ceremony_failure_topic": true},
		}

	return {
		"success": true, "action_id": "PERFORM_CLAN_INDUCTION",
		"character_id": character.character_id, "target_npc_id": ronin_id,
		"ic_day": ic_day, "season": ctx.season,
		"effects": {
			"inductee_id": ronin_id,
			"daimyo_id": character.character_id,
		},
	}


## Family Daimyo issues formal approval for a specific ronin's induction (s52.7 Part A).
## No skill roll — this is an executive decision, not a social contest.
static func _execute_approve_clan_induction(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var ic_day: int = ctx.ic_day
	var ronin_id: int = action.metadata.get("target_ronin_id", -1)

	if character.lord_rank < Enums.LordRank.FAMILY_DAIMYO:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "approver_rank_too_low", "effects": {},
		}

	if ronin_id < 0:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "no_ronin_identified", "effects": {},
		}

	var ronin: L5RCharacterData = characters_by_id.get(ronin_id) as L5RCharacterData
	if ronin == null or CharacterStats.is_dead(ronin):
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "ronin_unavailable", "effects": {},
		}

	# Verify the ronin has earned sufficient deeds for this family.
	if RoninSystem.get_deed_count(ronin, character.family) < RoninSystem.INDUCTION_DEED_THRESHOLD:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "insufficient_deeds", "effects": {},
		}

	if RoninSystem.get_extraordinary_deed_count(ronin, character.family) < RoninSystem.INDUCTION_EXTRAORDINARY_DEED_REQUIRED:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "no_extraordinary_deed", "effects": {},
		}

	# Disposition must be at Friend tier or above (s52.7 Part D).
	if int(character.disposition_values.get(ronin_id, 0)) < RoninSystem.INDUCTION_MIN_DISPOSITION:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "disposition_too_low", "effects": {},
		}

	# Prevent duplicate approvals (s52.7 Part D).
	if int(ronin.supply_ledger.get("family_daimyo_approval", -1)) >= 0:
		return {
			"success": false, "action_id": "APPROVE_CLAN_INDUCTION",
			"character_id": character.character_id, "target_npc_id": ronin_id,
			"ic_day": ic_day, "season": ctx.season,
			"reason": "already_approved", "effects": {},
		}

	return {
		"success": true, "action_id": "APPROVE_CLAN_INDUCTION",
		"character_id": character.character_id, "target_npc_id": ronin_id,
		"ic_day": ic_day, "season": ctx.season,
		"effects": {
			"approve_ronin_id": ronin_id,
			"family_daimyo_id": character.character_id,
		},
	}


static func _execute_terminate_contract(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var ic_day: int = ctx.ic_day
	var ronin_id: int = action.metadata.get("target_ronin_id", -1)
	if ronin_id < 0:
		return {
			"success": false, "action_id": "TERMINATE_CONTRACT",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "no_target", "effects": {},
		}
	var ronin: L5RCharacterData = characters_by_id.get(ronin_id) as L5RCharacterData
	if ronin == null or CharacterStats.is_dead(ronin):
		return {
			"success": false, "action_id": "TERMINATE_CONTRACT",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "target_unavailable", "effects": {},
		}
	var contract_end: int = ronin.supply_ledger.get("contract_end_ic_day", -1)
	if contract_end < 0:
		return {
			"success": false, "action_id": "TERMINATE_CONTRACT",
			"character_id": character.character_id, "ic_day": ic_day, "season": ctx.season,
			"reason": "no_active_contract", "effects": {},
		}
	# Compute remaining seasons for refund calculation.
	var days_remaining: int = max(0, contract_end - ic_day)
	var season_days: int = InvestigationSystem.DAYS_PER_SEASON
	var remaining_seasons: int = (days_remaining + season_days - 1) / season_days
	var contract_type: String = ronin.supply_ledger.get("contract_type", "PROVINCE_DEFENSE")

	return {
		"success": true, "action_id": "TERMINATE_CONTRACT",
		"character_id": character.character_id, "target_npc_id": ronin_id,
		"ic_day": ic_day, "season": ctx.season,
		"effects": {
			"terminate_ronin_id": ronin_id,
			"contract_type": contract_type,
			"remaining_seasons": remaining_seasons,
			"current_season": ctx.season,
			"disposition_change": RoninSystem.CONTRACT_EARLY_TERMINATION_DISPOSITION,
		},
	}


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
				"failed": true,
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


static func _execute_dissolve_marriage(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var base: Dictionary = {
		"action_id": "DISSOLVE_MARRIAGE",
		"character_id": ctx.character_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
	}
	if ctx.lord_rank < Enums.LordRank.FAMILY_DAIMYO:
		base["success"] = false
		base["reason"] = "insufficient_rank"
		base["effects"] = {}
		return base

	var spouse_a_id: int = action.metadata.get("spouse_a_id", -1)
	var spouse_b_id: int = action.metadata.get("spouse_b_id", -1)

	if spouse_a_id < 0 or spouse_b_id < 0:
		base["success"] = false
		base["reason"] = "missing_metadata"
		base["effects"] = {}
		return base

	var spouse_a: L5RCharacterData = characters_by_id.get(spouse_a_id) as L5RCharacterData
	var spouse_b: L5RCharacterData = characters_by_id.get(spouse_b_id) as L5RCharacterData

	if spouse_a == null or CharacterStats.is_dead(spouse_a):
		base["success"] = false
		base["reason"] = "spouse_a_not_found"
		base["effects"] = {}
		return base

	if spouse_b == null or CharacterStats.is_dead(spouse_b):
		base["success"] = false
		base["reason"] = "spouse_b_not_found"
		base["effects"] = {}
		return base

	# Pathway 4 — Imperial Decree (s57.49.7): no Honor cost, no penalties.
	# Pathway 1 — Lord's Command: Honor cost pre-applied (Pattern B, s57.49.7).
	var pathway: int = 1
	if ctx.lord_rank == Enums.LordRank.IMPERIAL:
		pathway = 4
	else:
		HonorGlorySystem.apply_honor_change(character, MarriageSystem.DISSOLUTION_HONOR_LOSS_LORD)

	base["success"] = true
	base["effects"] = {
		"requires_dissolution": true,
		"spouse_a_id": spouse_a_id,
		"spouse_b_id": spouse_b_id,
		"ordering_lord_id": ctx.character_id,
		"pathway": pathway,
	}
	return base


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
	var a_skill_rank: int = 0
	if a_skill == "Lore":
		for sk: String in character.skills:
			if sk.begins_with("Lore:") and character.skills[sk] > a_skill_rank:
				a_skill_rank = character.skills[sk]
				a_skill = sk
	else:
		a_skill_rank = character.skills.get(a_skill, 0)
	var a_trait_val: int = _get_trait_value_by_name(character, a_trait_name)
	var wc_bonus: int = _get_winter_court_skill_bonus(character, a_skill, ctx)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + wc_bonus

	var defender_roll: int = 0
	if target != null:
		var d_skill: String = _CONTESTED_DEFENDER_SKILL.get(action_id, "Etiquette")
		var d_trait_name: String = _CONTESTED_DEFENDER_TRAIT.get(action_id, "Awareness")
		var d_skill_rank: int = target.skills.get(d_skill, 0)
		var d_trait_val: int = _get_trait_value_by_name(target, d_trait_name)
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
	var a_trait_val: int = character.awareness
	var provoke_wc: int = _get_winter_court_skill_bonus(character, "Courtier", ctx)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + provoke_wc

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_willpower: int = target.willpower
		defender_roll = dice_engine.roll_skill_check(
			d_willpower, d_etiquette, 0
		).get("total", 0)

	var witness_ids: Array = _get_co_located_ids(character, characters_by_id)
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
	var a_trait_val: int = _get_trait_value_by_name(character, game_trait)
	var a_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var b_roll: int = 0
	if target != null:
		var b_skill_rank: int = target.skills.get(game_skill, 0)
		var b_trait_val: int = _get_trait_value_by_name(target, game_trait)
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
	var a_trait_val: int = _get_trait_value_by_name(character, a_trait_name)
	var discern_wc: int = _get_winter_court_skill_bonus(character, a_skill, ctx)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + discern_wc

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_awareness: int = target.awareness
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
	var a_trait_val: int = character.perception
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0)

	var defender_roll: int = 0
	if target != null:
		var d_etiquette: int = target.skills.get("Etiquette", 0)
		var d_awareness: int = target.awareness
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
	var a_trait_val: int = character.perception
	var probe_wc: int = _get_winter_court_skill_bonus(character, "Courtier", ctx)
	var attacker_roll: int = dice_engine.roll_skill_check(
		a_trait_val, a_skill_rank, 0
	).get("total", 0) + probe_wc

	var defender_roll: int = 0
	if target != null:
		var d_sincerity: int = target.skills.get("Sincerity", 0)
		var d_awareness: int = target.awareness
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
	_dice_engine: DiceEngine,
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
	var is_public: bool = ctx.context_flag == Enums.ContextFlag.AT_COURT

	return {
		"success": true,
		"action_id": "ISSUE_DUEL_CHALLENGE",
		"character_id": ctx.character_id,
		"target_npc_id": target_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"injects_reactive_event": true,
		"reactive_event_type": "DUEL_CHALLENGE_RECEIVED",
		"reactive_event_target_id": target_id,
		"effects": {
			"challenge_issued": true,
			"to_death": to_death,
			"is_sanctioned": is_sanctioned,
			"is_public": is_public,
		},
	}


static func resolve_accepted_duel(
	challenger: L5RCharacterData,
	defender: L5RCharacterData,
	to_death: bool,
	is_sanctioned: bool,
	is_at_court: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	var duel: IndividualCombat.DuelState = IndividualCombat.create_duel(
		challenger.character_id, defender.character_id, to_death
	)

	var challenger_wants_stare_down: bool = _should_attempt_stare_down(challenger)
	var defender_wants_stare_down: bool = _should_attempt_stare_down(defender)
	var stare_down_result: Dictionary = {}
	if challenger_wants_stare_down or defender_wants_stare_down:
		stare_down_result = IndividualCombat.resolve_iaijutsu_stare_down(
			challenger, defender, duel, dice_engine
		)
		stare_down_result["challenger_initiated"] = challenger_wants_stare_down
		stare_down_result["defender_initiated"] = defender_wants_stare_down

	var ch_p := IndividualCombat.Participant.new()
	ch_p.character_id = challenger.character_id
	ch_p.stance = Enums.Stance.CENTER
	var def_p := IndividualCombat.Participant.new()
	def_p.character_id = defender.character_id
	def_p.stance = Enums.Stance.CENTER

	var assessment: Dictionary = IndividualCombat.resolve_duel_assessment(
		challenger, defender, duel, dice_engine
	)

	if _should_concede_at_assessment(defender, assessment, duel):
		var concession: Dictionary = IndividualCombat.concede_at_assessment(
			defender.character_id, duel
		)
		if concession["glory_change"] != 0.0:
			HonorGlorySystem.apply_glory_change(defender, concession["glory_change"])
		var effects: Dictionary = {
			"duel_result": {"assessment": assessment, "concession": concession},
			"winner_id": duel.winner_id,
			"loser_id": duel.loser_id,
			"simultaneous": false,
			"death_occurred": false,
			"challenger_dead": false,
			"defender_dead": false,
			"conceded": true,
			"conceder_id": defender.character_id,
		}
		if stare_down_result.size() > 0:
			effects["stare_down"] = stare_down_result
		if duel.winner_id == challenger.character_id and is_at_court:
			effects["glory_change"] = 0.5
		effects["is_sanctioned"] = is_sanctioned
		effects["challenger_id"] = challenger.character_id
		effects["defender_id"] = defender.character_id
		return effects

	var focus: Dictionary = IndividualCombat.resolve_duel_focus(
		challenger, defender, duel, dice_engine
	)

	var first_char: L5RCharacterData
	var second_char: L5RCharacterData
	var first_p: IndividualCombat.Participant
	var second_p: IndividualCombat.Participant
	if duel.simultaneous or duel.first_striker_id == duel.challenger_id:
		first_char = challenger
		first_p = ch_p
		second_char = defender
		second_p = def_p
	else:
		first_char = defender
		first_p = def_p
		second_char = challenger
		second_p = ch_p

	ch_p.void_ring_bonus = challenger.void_ring
	def_p.void_ring_bonus = defender.void_ring

	var strike: Dictionary = IndividualCombat.resolve_duel_strike(
		first_char, first_p, second_char, second_p, duel, dice_engine
	)

	var duel_result: Dictionary = {
		"assessment": assessment,
		"focus": focus,
		"strike": strike,
		"winner_id": duel.winner_id,
		"loser_id": duel.loser_id,
		"simultaneous": duel.simultaneous,
		"challenger_id": challenger.character_id,
		"defender_id": defender.character_id,
	}
	if stare_down_result.size() > 0:
		duel_result["stare_down"] = stare_down_result

	var winner_id: int = duel_result.get("winner_id", -1)
	var loser_id: int = duel_result.get("loser_id", -1)
	var simultaneous: bool = duel_result.get("simultaneous", false)

	var challenger_dead: bool = CharacterStats.is_dead(challenger)
	var defender_dead: bool = CharacterStats.is_dead(defender)
	var death_occurred: bool = challenger_dead or defender_dead

	var effects: Dictionary = {
		"duel_result": duel_result,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"simultaneous": simultaneous,
		"death_occurred": death_occurred,
		"challenger_dead": challenger_dead,
		"defender_dead": defender_dead,
		"is_sanctioned": is_sanctioned,
		"challenger_id": challenger.character_id,
		"defender_id": defender.character_id,
	}

	if winner_id != -1 and is_at_court:
		if winner_id == challenger.character_id:
			effects["glory_change"] = 0.5
		else:
			effects["winner_glory_change"] = 0.5
			effects["winner_glory_recipient_id"] = winner_id

	if death_occurred and not is_sanctioned:
		var killer_id: int = -1
		if challenger_dead:
			killer_id = defender.character_id
		elif defender_dead:
			killer_id = challenger.character_id
		effects["requires_crime_creation"] = true
		effects["crime_type"] = Enums.CrimeType.UNSANCTIONED_DUEL_DEATH
		effects["crime_perpetrator_id"] = killer_id
		effects["crime_victim_id"] = loser_id

	return effects


static func _should_attempt_stare_down(character: L5RCharacterData) -> bool:
	var intim: int = character.skills.get("Intimidation", 0)
	if intim == 0:
		return false
	match character.bushido_virtue:
		Enums.BushidoVirtue.YU:
			return true
		Enums.BushidoVirtue.REI:
			return false
		Enums.BushidoVirtue.JIN:
			return false
	match character.shourido_virtue:
		Enums.ShouridoVirtue.KETSUI:
			return true
		Enums.ShouridoVirtue.ISHI:
			return true
		Enums.ShouridoVirtue.SEIGYO:
			return false
	return intim >= 3


static func _should_concede_at_assessment(
	defender: L5RCharacterData,
	assessment: Dictionary,
	duel: IndividualCombat.DuelState,
) -> bool:
	var outmatched: bool = (
		assessment.get("assessment_bonus_id", -1) == duel.challenger_id
		and not assessment.get("defender_succeeded", true)
	)
	if not outmatched:
		return false
	match defender.bushido_virtue:
		Enums.BushidoVirtue.YU:
			return false
		Enums.BushidoVirtue.MEIYO:
			return not duel.duel_to_death
	match defender.shourido_virtue:
		Enums.ShouridoVirtue.KETSUI:
			return false
		Enums.ShouridoVirtue.ISHI:
			return false
		Enums.ShouridoVirtue.SEIGYO:
			return true
		Enums.ShouridoVirtue.CHISHIKI:
			return true
	return not duel.duel_to_death


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
	var trait_val: int = character.awareness

	# Bureaucracy emphasis grants +1k0 on kuge rolls per s55.7.3.
	var has_emphasis: bool = target_is_kuge and character.skills.has("Bureaucracy")
	var intro_wc: int = _get_winter_court_skill_bonus(character, skill, ctx)
	var roll_result: Dictionary = dice_engine.roll_skill_check(
		trait_val, skill_rank, 0, 0, 0, has_emphasis
	)
	var roll_total: int = roll_result.get("total", 0) + intro_wc

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
	var trait_val: int = character.perception
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
		var learned_ids: Array = []
		for _i: int in range(learn_count):
			if pool.is_empty():
				break
			var idx: int = dice_engine.roll_and_keep(1, 1, 0).total % pool.size()
			learned_ids.append(int(pool[idx]))
			pool.remove_at(idx)

		var learned_info: Array = []
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


# -- INVOKE_FAVOR --------------------------------------------------------------

static func _execute_invoke_favor(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var favor_id: int = action.metadata.get("favor_id", -1)
	var debtor_id: int = action.metadata.get("debtor_id", -1)
	if favor_id < 0 or debtor_id < 0:
		return {
			"success": false,
			"action_id": "INVOKE_FAVOR",
			"character_id": character.character_id,
			"reason": "no_favor_available",
		}
	var method: int = FavorData.InvocationMethod.PERSONAL_VISIT
	if ctx.context_flag == Enums.ContextFlag.AT_COURT:
		method = FavorData.InvocationMethod.COURT
	return {
		"success": true,
		"action_id": "INVOKE_FAVOR",
		"character_id": character.character_id,
		"target_npc_id": debtor_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_favor_invocation": true,
			"favor_id": favor_id,
			"debtor_id": debtor_id,
			"invocation_method": method,
		},
	}


# -- TRANSFER_KOKU -------------------------------------------------------------

static func _execute_mentor(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var skill_name: String = action.metadata.get("skill_name", "")
	var student_id: int = action.metadata.get("student_id", action.target_npc_id)
	if skill_name.is_empty() or student_id < 0:
		return {"effect": "mentor_failed", "reason": "no_target_or_skill"}
	var student: L5RCharacterData = characters_by_id.get(student_id) as L5RCharacterData
	if student == null or CharacterStats.is_dead(student):
		return {"effect": "mentor_failed", "reason": "student_unavailable"}
	var sensei_char: L5RCharacterData = characters_by_id.get(ctx.character_id) as L5RCharacterData
	if sensei_char == null:
		return {"effect": "mentor_failed", "reason": "sensei_unavailable"}
	if student.physical_location != sensei_char.physical_location:
		return {"effect": "mentor_failed", "reason": "not_co_located"}
	var sensei_rank: int = sensei_char.skills.get(skill_name, 0)
	var student_rank: int = student.skills.get(skill_name, 0)
	if sensei_rank <= student_rank:
		return {"effect": "mentor_failed", "reason": "rank_not_higher"}
	return {
		"effect": "mentor_offered",
		"success": true,
		"student_id": student_id,
		"sensei_id": ctx.character_id,
		"skill_name": skill_name,
		"sensei_skill_rank": sensei_rank,
		"rank_gap": sensei_rank - student_rank,
		"injects_reactive_event": true,
		"reactive_event_type": "ACCEPT_TRAINING",
		"reactive_event_target_id": student_id,
	}


const TRANSFER_KOKU_BASE_AMOUNT: float = 5.0
const TRANSFER_KOKU_WEALTHY_THRESHOLD: float = 20.0
const TRANSFER_KOKU_WEALTHY_AMOUNT: float = 10.0

static func _execute_transfer_koku(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var recipient_id: int = action.metadata.get("target_npc_id", action.target_npc_id)
	if recipient_id < 0:
		return {"success": false, "blocked_reason": "no_recipient"}
	var recipient: L5RCharacterData = characters_by_id.get(recipient_id) as L5RCharacterData
	if recipient == null or CharacterStats.is_dead(recipient):
		return {"success": false, "blocked_reason": "recipient_unavailable"}
	var amount: float = TRANSFER_KOKU_BASE_AMOUNT
	if character.koku >= TRANSFER_KOKU_WEALTHY_THRESHOLD:
		amount = TRANSFER_KOKU_WEALTHY_AMOUNT
	amount = minf(amount, character.koku)
	if amount <= 0.0:
		return {"success": false, "blocked_reason": "insufficient_koku"}
	character.koku -= amount
	recipient.koku += amount
	return {
		"success": true,
		"effect": "koku_transferred",
		"koku_amount": amount,
		"recipient_id": recipient_id,
		"requires_koku_transfer_fulfillment": true,
		"disposition_change": 3,
	}


# -- REQUEST_PERFORMANCE -------------------------------------------------------

static func _execute_request_performance(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	if not ctx.is_lord:
		return {
			"success": false,
			"action_id": "REQUEST_PERFORMANCE",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "not_a_lord",
			"effects": {},
		}

	if character.civilian_orders_remaining <= 0:
		return {
			"success": false,
			"action_id": "REQUEST_PERFORMANCE",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "no_civilian_orders",
			"effects": {},
		}

	var flag: Enums.ContextFlag = ctx.context_flag
	if flag != Enums.ContextFlag.AT_OWN_HOLDINGS and flag != Enums.ContextFlag.AT_COURT:
		return {
			"success": false,
			"action_id": "REQUEST_PERFORMANCE",
			"character_id": ctx.character_id,
			"target_npc_id": action.target_npc_id,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "wrong_context",
			"effects": {},
		}

	character.civilian_orders_remaining -= 1

	var performance_type: String = action.metadata.get("performance_type", "song")
	var target_performer_id: int = action.metadata.get("target_performer_id", -1)
	var venue_mode: String = action.metadata.get("venue_mode", "public")

	var letter_dict: Dictionary = {}
	if target_performer_id >= 0:
		letter_dict = {
			"to_character_id": target_performer_id,
			"from_character_id": character.character_id,
			"content": "performance_invitation",
			"performance_type": performance_type,
			"venue_mode": venue_mode,
		}

	return {
		"success": true,
		"action_id": "REQUEST_PERFORMANCE",
		"character_id": character.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"civilian_order_consumed": true,
			"performance_type": performance_type,
			"target_performer_id": target_performer_id,
			"venue_mode": venue_mode,
			"invitation_letter": letter_dict,
		},
	}


# -- CONDUCT_TEA_CEREMONY ------------------------------------------------------

static func _execute_conduct_tea_ceremony(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	if not TeaCeremonySystem.zone_allows_ceremony(ctx.zone_flags):
		return {
			"success": false,
			"action_id": "CONDUCT_TEA_CEREMONY",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"reason": "zone_not_eligible",
			"effects": {},
		}

	var candidate_ids: Array = action.metadata.get("participant_ids", [])
	var actual_participants: Array = []
	for pid: Variant in candidate_ids:
		var pid_int: int = int(pid)
		var c: L5RCharacterData = characters_by_id.get(pid_int)
		if c != null and c.current_void_points < c.max_void_points:
			actual_participants.append(pid_int)

	var total_count: int = 1 + actual_participants.size()
	var tn: int = TeaCeremonySystem.get_tn(total_count)

	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Tea Ceremony", tn, 0,
		"Void Recovery", Enums.Trait.VOID,
	)

	if not check.get("success", false):
		return {
			"success": false,
			"action_id": "CONDUCT_TEA_CEREMONY",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"skill_used": "Tea Ceremony",
			"roll_total": check.get("total", 0),
			"tn": tn,
			"reason": "roll_failed",
			"effects": {},
		}

	var tea_rank: int = SkillResolver.get_skill_rank(character, "Tea Ceremony")
	var recovery: int = (
		TeaCeremonySystem.VP_MASTERY_RECOVERY
		if tea_rank >= TeaCeremonySystem.MASTERY_RANK5
		else TeaCeremonySystem.VP_BASE_RECOVERY
	)

	var host_gain: int = mini(recovery, character.max_void_points - character.current_void_points)
	character.current_void_points += host_gain

	var participant_gains: Dictionary = {}
	for pid: int in actual_participants:
		var c: L5RCharacterData = characters_by_id.get(pid)
		if c != null:
			var gain: int = mini(recovery, c.max_void_points - c.current_void_points)
			c.current_void_points += gain
			participant_gains[pid] = gain

	return {
		"success": true,
		"action_id": "CONDUCT_TEA_CEREMONY",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"skill_used": "Tea Ceremony",
		"roll_total": check.get("total", 0),
		"tn": tn,
		"effects": {
			"host_vp_recovered": host_gain,
			"participant_gains": participant_gains,
			"total_participants": total_count,
			"recovery_per_participant": recovery,
		},
	}


# -- ANNOUNCE_HUNT -------------------------------------------------------------

static func _execute_announce_hunt(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var check: Dictionary = HuntSystem.can_announce(character, ctx)
	if not check.get("valid", false):
		return {
			"success": false,
			"action_id": "ANNOUNCE_HUNT",
			"reason": check.get("reason", "precondition_failed"),
		}

	var target_province_id: int = action.metadata.get("target_province_id", -1)
	var hunt_date_ic_day: int = action.metadata.get("hunt_date_ic_day", -1)
	if hunt_date_ic_day < 0:
		hunt_date_ic_day = ctx.ic_day + HuntSystem.MIN_HUNT_DAYS_AHEAD
	var priority_invitee_id: int = action.metadata.get("priority_invitee_id", -1)

	return {
		"success": true,
		"action_id": "ANNOUNCE_HUNT",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": target_province_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"hunt_date_ic_day": hunt_date_ic_day,
			"priority_invitee_id": priority_invitee_id,
			"topic_tier": TopicData.Tier.TIER_4,
			"topic_type": "hunt_announcement",
		},
	}


# -- REQUEST_HUNT_INVITATION ---------------------------------------------------

static func _execute_request_hunt_invitation(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var host_id: int = action.metadata.get("host_id", action.target_npc_id)
	var hunt_topic_id: int = action.metadata.get("hunt_topic_id", -1)

	if hunt_topic_id < 0:
		return {
			"success": false,
			"action_id": "REQUEST_HUNT_INVITATION",
			"reason": "no_hunt_topic",
		}

	return {
		"success": true,
		"action_id": "REQUEST_HUNT_INVITATION",
		"character_id": character.character_id,
		"target_npc_id": host_id,
		"target_province_id": -1,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"hunt_topic_id": hunt_topic_id,
			"requester_id": character.character_id,
			"requester_status": character.status,
		},
	}


# -- CANCEL_HUNT ---------------------------------------------------------------

static func _execute_cancel_hunt(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var check: Dictionary = HuntSystem.can_cancel(character, ctx)
	if not check.get("valid", false):
		return {
			"success": false,
			"action_id": "CANCEL_HUNT",
			"reason": check.get("reason", "precondition_failed"),
		}

	var active_hunt_id: int = ctx.known_objectives.get("active_hunt_id", -1)
	var accepted_invitee_ids: Array = action.metadata.get("accepted_invitee_ids", [])

	return {
		"success": true,
		"action_id": "CANCEL_HUNT",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"hunt_id": active_hunt_id,
			"glory_change": HuntSystem.GLORY_HOST_CANCEL,
			"accepted_invitee_ids": accepted_invitee_ids,
			"disposition_change_per_invitee": HuntSystem.DISP_CANCEL_PER_INVITEE,
			"topic_type": "hunt_cancellation",
		},
	}


# -- COMMISSION_ASSASSINATION --------------------------------------------------

static func _execute_commission_assassination(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_id: int = action.target_npc_id
	if target_id < 0:
		return {
			"success": false,
			"action_id": "COMMISSION_ASSASSINATION",
			"reason": "no_target",
		}

	var target: L5RCharacterData = characters_by_id.get(target_id)
	if target == null:
		return {
			"success": false,
			"action_id": "COMMISSION_ASSASSINATION",
			"reason": "target_not_found",
		}

	var assassin: L5RCharacterData = _select_best_assassin(
		character, characters_by_id, ctx
	)
	if assassin == null:
		return {
			"success": false,
			"action_id": "COMMISSION_ASSASSINATION",
			"reason": "no_eligible_assassin",
		}

	var method: int = _select_assassination_method(assassin)
	var honor_cost: float = CrimeSystem.scale_honor_by_rank(SecretSystem.get_assassination_order_honor_cost(target.status), character)
	HonorGlorySystem.apply_honor_change(character, honor_cost)

	return {
		"success": true,
		"action_id": "COMMISSION_ASSASSINATION",
		"character_id": character.character_id,
		"target_npc_id": target_id,
		"target_province_id": -1,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"assassin_id": assassin.character_id,
			"target_id": target_id,
			"method": method,
			"commissioner_id": character.character_id,
			"subject_honor_loss": honor_cost,
		},
	}


static func _select_best_assassin(
	lord: L5RCharacterData,
	characters_by_id: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> L5RCharacterData:
	var best: L5RCharacterData = null
	var best_score: int = -1
	for char_id: Variant in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id]
		if c.character_id == lord.character_id:
			continue
		if c.lord_id != lord.character_id:
			continue
		if CharacterStats.is_dead(c):
			continue
		var stealth: int = c.skills.get("Stealth", 0)
		if stealth < 3:
			continue
		var score: int = stealth + c.skills.get("Temptation", 0) + c.skills.get("Ninjutsu", 0)
		if score > best_score:
			best_score = score
			best = c
	return best


static func _select_assassination_method(assassin: L5RCharacterData) -> int:
	var poison_score: int = assassin.skills.get("Sleight of Hand", 0) + assassin.skills.get("Medicine", 0)
	var blade_score: int = maxi(assassin.skills.get("Kenjutsu", 0), assassin.skills.get("Ninjutsu", 0))
	var accident_score: int = assassin.skills.get("Engineering", 0) + assassin.skills.get("Investigation", 0)
	if poison_score >= blade_score and poison_score >= accident_score:
		return AssassinationSystem.ExecutionMethod.POISON
	if blade_score >= accident_score:
		return AssassinationSystem.ExecutionMethod.BLADE
	return AssassinationSystem.ExecutionMethod.ARRANGED_ACCIDENT


# -- TRAIN_ANIMAL --------------------------------------------------------------

static func _execute_train_animal(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var is_first_session: bool = action.metadata.get("is_first_session", false)
	var species_str: String = action.metadata.get("species", "")
	var companion_id: int = action.metadata.get("companion_id", -1)

	if is_first_session:
		# First session — acquire a new companion
		var check: Dictionary = AnimalHandlingSystem.can_train_first_session(
			character, ctx, species_str
		)
		if not check.get("valid", false):
			return {
				"success": false,
				"action_id": "TRAIN_ANIMAL",
				"reason": check.get("reason", "precondition_failed"),
			}

		var roll_result: Dictionary = AnimalHandlingSystem.make_training_roll(
			character, species_str, dice_engine
		)
		# Assign a new companion_id (caller is responsible for generating unique ids;
		# here we use a transient id from metadata or compute one)
		var new_id: int = action.metadata.get("new_companion_id", -1)
		if new_id < 0:
			new_id = character.character_id * 1000 + character.trained_companions.size()
		var companion_name: String = action.metadata.get("companion_name", species_str.to_lower())
		var new_companion: Dictionary = AnimalHandlingSystem.create_companion(
			character.character_id,
			species_str,
			new_id,
			companion_name,
			ctx.ic_day,
			action.target_province_id,
			roll_result.get("progress_gained", 0),
		)
		character.trained_companions.append(new_companion)

		return {
			"success": true,
			"action_id": "TRAIN_ANIMAL",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": action.target_province_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"skill_used": "Animal Handling",
			"roll_total": roll_result.get("roll_total", 0),
			"tn": roll_result.get("tn", 15),
			"effects": {
				"is_first_session": true,
				"companion_id": new_id,
				"species": species_str,
				"progress_gained": roll_result.get("progress_gained", 0),
				"roll_success": roll_result.get("success", false),
				"fully_trained": new_companion.get("fully_trained", false),
			},
		}

	else:
		# Subsequent session — advance existing companion
		var companion: Dictionary = {}
		for c: Variant in character.trained_companions:
			var comp: Dictionary = c as Dictionary
			if comp.get("companion_id", -1) == companion_id:
				companion = comp
				break

		if companion.is_empty():
			return {
				"success": false,
				"action_id": "TRAIN_ANIMAL",
				"reason": "companion_not_found",
			}

		var check: Dictionary = AnimalHandlingSystem.can_train_subsequent_session(
			character, ctx, companion
		)
		if not check.get("valid", false):
			return {
				"success": false,
				"action_id": "TRAIN_ANIMAL",
				"reason": check.get("reason", "precondition_failed"),
			}

		var roll_result: Dictionary = AnimalHandlingSystem.make_training_roll(
			character, companion.get("species", "DOG"), dice_engine
		)
		AnimalHandlingSystem.apply_training_progress(companion, roll_result.get("progress_gained", 0))

		return {
			"success": true,
			"action_id": "TRAIN_ANIMAL",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"skill_used": "Animal Handling",
			"roll_total": roll_result.get("roll_total", 0),
			"tn": roll_result.get("tn", 15),
			"effects": {
				"is_first_session": false,
				"companion_id": companion_id,
				"species": companion.get("species", ""),
				"progress_gained": roll_result.get("progress_gained", 0),
				"roll_success": roll_result.get("success", false),
				"fully_trained": companion.get("fully_trained", false),
				"sessions_completed": companion.get("sessions_completed", 0),
			},
		}


# -- s57.25.3 APPLY_TATTOO ---------------------------------------------------

static func _execute_apply_tattoo(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	var recipient_id: int = action.target_npc_id
	var recipient: L5RCharacterData = characters_by_id.get(recipient_id)
	if recipient == null:
		return {
			"success": false, "action_id": "APPLY_TATTOO",
			"character_id": character.character_id,
			"target_npc_id": recipient_id,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "no_recipient", "effects": {},
		}

	var target_tier: Enums.TattooQualityTier = action.metadata.get(
		"target_tier", Enums.TattooQualityTier.NORMAL
	) as Enums.TattooQualityTier
	var body_location: Enums.TattooBodyLocation = action.metadata.get(
		"body_location", Enums.TattooBodyLocation.LEFT_WRIST_FOREARM
	) as Enums.TattooBodyLocation
	var is_ability: bool = action.metadata.get("is_ability_tattoo", false)
	var ability: Enums.TattooAbility = action.metadata.get(
		"ability", Enums.TattooAbility.NONE
	) as Enums.TattooAbility

	var tattooing_rank: int = character.skills.get("Artisan: Tattooing", 0)
	if not TattooSystem.meets_skill_gate(tattooing_rank, target_tier):
		return {
			"success": false, "action_id": "APPLY_TATTOO",
			"character_id": character.character_id,
			"target_npc_id": recipient_id,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "skill_gate_failed", "effects": {},
		}

	var ap_required: int = TattooSystem.get_ap_cost(target_tier)
	if character.action_points_current < ap_required:
		return {
			"success": false, "action_id": "APPLY_TATTOO",
			"character_id": character.character_id,
			"target_npc_id": recipient_id,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "insufficient_ap", "effects": {},
		}

	var world_tattoos: Array = action.metadata.get("world_tattoos", [])
	var is_bald: bool = action.metadata.get("recipient_is_bald", false)
	if not TattooSystem.is_location_available(world_tattoos, recipient_id, body_location, is_bald):
		return {
			"success": false, "action_id": "APPLY_TATTOO",
			"character_id": character.character_id,
			"target_npc_id": recipient_id,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "location_occupied", "effects": {},
		}

	if is_ability:
		var in_togashi_territory: bool = action.metadata.get("in_togashi_territory", false)
		if not TattooSystem.can_apply_ability_tattoo(
			character.school_name, character.school_rank, in_togashi_territory
		):
			return {
				"success": false, "action_id": "APPLY_TATTOO",
				"character_id": character.character_id,
				"target_npc_id": recipient_id,
				"target_province_id": -1,
				"ic_day": ctx.ic_day, "season": ctx.season,
				"reason": "ability_tattoo_gate_failed", "effects": {},
			}

	var tn: int = TattooSystem.get_apply_tn(target_tier)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Tattooing", tn, 0, "",
		Enums.Trait.AGILITY, 0, 0, 0, ctx.ic_day
	)

	var roll_total: int = roll_result.get("total", 0)
	var raises: int = maxi((roll_total - tn) / 5, 0) if roll_result.get("success", false) else 0
	var final_quality: Enums.TattooQualityTier = TattooSystem.resolve_quality(
		target_tier, roll_total, raises
	)

	if final_quality == Enums.TattooQualityTier.MUNDANE:
		return {
			"success": false, "action_id": "APPLY_TATTOO",
			"character_id": character.character_id,
			"target_npc_id": recipient_id,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"skill_used": "Artisan: Tattooing",
			"roll_total": roll_total, "tn": tn,
			"margin": roll_total - tn,
			"effects": {
				"ap_cost_override": ap_required,
				"result_quality": Enums.TattooQualityTier.MUNDANE,
			},
		}

	var disp_bond: int = TattooSystem.get_disposition_bond(final_quality)
	return {
		"success": true, "action_id": "APPLY_TATTOO",
		"character_id": character.character_id,
		"target_npc_id": recipient_id,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"skill_used": "Artisan: Tattooing",
		"roll_total": roll_total, "tn": tn,
		"margin": roll_total - tn,
		"effects": {
			"requires_tattoo_creation": true,
			"ap_cost_override": ap_required,
			"result_quality": final_quality,
			"body_location": body_location,
			"is_ability_tattoo": is_ability,
			"ability": ability,
			"target_tier": target_tier,
			"raises": raises,
			"disposition_change": disp_bond,
			"recipient_disposition_change": disp_bond,
			"subject_type": action.metadata.get("subject_type", Enums.TattooSubjectType.IMAGE),
			"subject_description": action.metadata.get("subject_description", ""),
			"topic_id": action.metadata.get("subject_topic_id", -1),
		},
	}


# -- s49 CRAFT ----------------------------------------------------------------


static func _execute_craft(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Route origami sub-types (s57.26) before s49 artisan path.
	var origami_type: String = action.metadata.get("origami_type", "")
	if origami_type in ["noshi", "gohei", "senbazuru_progress"]:
		return _execute_craft_origami(action, character, ctx, dice_engine, origami_type)

	var wip_item_id: int = action.metadata.get("wip_item_id", -1)
	if wip_item_id >= 0:
		return {
			"success": true,
			"action_id": "CRAFT",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {"continues_wip": true, "wip_item_id": wip_item_id},
		}

	var skill_name: String = action.metadata.get("skill_name", "")
	if skill_name.is_empty():
		skill_name = ArtisanSystem.get_best_craft_skill(character)
	if skill_name.is_empty() or character.skills.get(skill_name, 0) <= 0:
		return {
			"success": false,
			"action_id": "CRAFT",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {"reason": "no_craft_skill"},
		}

	var base_tn: int = action.metadata.get("base_tn", 15)
	var material_tier: Enums.MaterialTier = action.metadata.get(
		"material_tier", Enums.MaterialTier.COMMON) as Enums.MaterialTier
	var is_exceptional: bool = action.metadata.get("is_exceptional", false)
	var category: Enums.CraftingCategory = action.metadata.get(
		"category", Enums.CraftingCategory.EQUIPMENT) as Enums.CraftingCategory
	var track: Enums.CraftingTrack = action.metadata.get(
		"track", Enums.CraftingTrack.CRAFT) as Enums.CraftingTrack
	var item_name: String = action.metadata.get("item_name", "Crafted Item")
	var denomination: String = action.metadata.get("denomination", "bu")
	var base_cost: float = action.metadata.get("base_cost", 5.0)
	var material_name: String = action.metadata.get("material_name", "Standard materials")
	var material_type: Enums.MaterialType = action.metadata.get(
		"material_type", Enums.MaterialType.OTHER) as Enums.MaterialType

	var koku_cost: float = ArtisanSystem.cost_in_koku(base_cost, denomination)
	if is_exceptional:
		koku_cost *= ArtisanSystem.EXCEPTIONAL_COST_MULTIPLIER

	var ap_cost: int = ArtisanSystem.get_ap_cost(base_cost, denomination, material_type)
	if ap_cost > 2:
		return {
			"success": true,
			"action_id": "CRAFT",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day,
			"season": ctx.season,
			"effects": {
				"creates_wip": true,
				"skill_name": skill_name,
				"base_tn": base_tn,
				"material_tier": material_tier,
				"material_name": material_name,
				"is_exceptional": is_exceptional,
				"category": category,
				"track": track,
				"item_name": item_name,
				"denomination": denomination,
				"base_cost": base_cost,
				"material_type": material_type,
				"ap_cost": ap_cost,
				"koku_cost": koku_cost,
			},
		}

	var craft_result: Dictionary = ArtisanSystem.resolve_crafting(
		character, dice_engine, skill_name, base_tn,
		material_tier, is_exceptional, 0,
	)

	var success: bool = craft_result.get("success", false)
	var item_ruined: bool = craft_result.get("item_ruined", false)

	var special_qualities: Array[Enums.WeaponSpecialQuality] = []
	var is_sacred: bool = false
	if success and category == Enums.CraftingCategory.WEAPONS and is_exceptional:
		var available_raises: int = craft_result.get("available_raises", 0)
		var sacred_check: Dictionary = ArtisanSystem.check_sacred_weapon(available_raises, character)
		if sacred_check.get("can_forge", false):
			is_sacred = true
			available_raises -= sacred_check.get("raise_cost", 7)

	var quality_tier: GiftGivingSystem.QualityTier = craft_result.get(
		"quality_tier", GiftGivingSystem.QualityTier.MUNDANE)

	return {
		"success": success,
		"action_id": "CRAFT",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": {
			"requires_item_creation": true,
			"item_ruined": item_ruined,
			"quality_tier": quality_tier,
			"crafting_roll_total": craft_result.get("total", 0),
			"effective_total": craft_result.get("effective_total", 0),
			"material_tier": material_tier,
			"material_name": material_name,
			"is_exceptional": is_exceptional,
			"is_sacred": is_sacred,
			"category": category,
			"track": track,
			"skill_name": skill_name,
			"item_name": item_name,
			"denomination": denomination,
			"base_cost": base_cost,
			"koku_cost": koku_cost,
		},
	}


# -- s57.26 ORIGAMI ACTIONS -------------------------------------------------------


static func _execute_craft_origami(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	origami_type: String,
) -> Dictionary:
	## Resolve a single origami craft session (noshi, gohei, or senbazuru progress).
	var raises_declared: int = action.metadata.get("raises", 0)
	var tn: int
	match origami_type:
		"noshi":
			tn = OrigamiSystem.NOSHI_TN
		"gohei":
			tn = OrigamiSystem.GOHEI_TN
		"senbazuru_progress":
			tn = OrigamiSystem.SENBAZURU_SESSION_TN
		_:
			return {
				"success": false, "action_id": "CRAFT",
				"character_id": character.character_id,
				"ic_day": ctx.ic_day, "season": ctx.season,
				"effects": {"reason": "unknown_origami_type"},
			}

	var roll_tn: int = tn + raises_declared * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Origami", roll_tn,
		raises_declared, "", Enums.Trait.AWARENESS, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)
	var success: bool = total >= roll_tn
	var quality_tier: int = OrigamiSystem.compute_quality_from_raises(raises_declared, success)

	var effects: Dictionary = {
		"origami_type": origami_type,
		"quality_tier": quality_tier,
		"roll_total": total,
		"raises_declared": raises_declared,
	}

	match origami_type:
		"noshi":
			# GDD s57.26.6: failure produces mundane noshi. Item always stored.
			if not success:
				quality_tier = GiftGivingSystem.QualityTier.MUNDANE
				effects["quality_tier"] = quality_tier
			effects["requires_noshi_creation"] = true
			effects["noshi_is_mundane"] = quality_tier == GiftGivingSystem.QualityTier.MUNDANE
			effects["wrapper_target_id"] = action.metadata.get(
				"target_npc_id", action.target_npc_id)
		"gohei":
			effects["requires_gohei_creation"] = success
			if success:
				effects["uses_remaining"] = OrigamiSystem.GOHEI_USES.get(
					quality_tier,
					OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.NORMAL])
		"senbazuru_progress":
			var senbazuru_id: int = action.metadata.get("senbazuru_id", -1)
			var cranes_added: int = 0
			if success:
				cranes_added = (OrigamiSystem.CRANES_BASE
					+ raises_declared * OrigamiSystem.CRANES_PER_RAISE)
			effects["senbazuru_id"] = senbazuru_id
			effects["cranes_added"] = cranes_added
			effects["session_success"] = success

	return {
		"success": success,
		"action_id": "CRAFT",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day,
		"season": ctx.season,
		"effects": effects,
	}


static func _execute_declare_senbazuru(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## 0 AP declaration that creates a new SenbazuruData (s57.26.14).
	## Gate: one active senbazuru per folder; cleared on presentation.
	var active_id: int = ctx.known_objectives.get("active_senbazuru_id", -1)
	if active_id >= 0:
		return {
			"success": false, "action_id": "DECLARE_SENBAZURU",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"reason": "already_has_active_senbazuru"},
		}
	var dedication_type: String = action.metadata.get("dedication_type", "Atonement")
	var recipient_id: int = action.metadata.get("recipient_id", -1)
	if dedication_type == "Atonement":
		recipient_id = -1
	return {
		"success": true, "action_id": "DECLARE_SENBAZURU",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"requires_senbazuru_creation": true,
			"dedication_type": dedication_type,
			"recipient_id": recipient_id,
		},
	}


static func _execute_present_senbazuru(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## 1 AP presentation; requires is_complete = true (s57.26.17).
	var senbazuru_id: int = ctx.known_objectives.get("active_senbazuru_id", -1)
	if senbazuru_id < 0:
		return {
			"success": false, "action_id": "PRESENT_SENBAZURU",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"reason": "no_active_senbazuru"},
		}
	if not ctx.known_objectives.get("senbazuru_is_complete", false):
		return {
			"success": false, "action_id": "PRESENT_SENBAZURU",
			"character_id": character.character_id,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"reason": "senbazuru_not_complete"},
		}
	return {
		"success": true, "action_id": "PRESENT_SENBAZURU",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"requires_senbazuru_presentation": true,
			"senbazuru_id": senbazuru_id,
		},
	}


# -- s57.22 THEATER PIECE ACTIONS -----------------------------------------------

static func _execute_theater_action(
	action_id: String,
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	match action_id:
		"COMPOSE_THEATER_PIECE":
			return _execute_compose_theater(action, character, ctx, dice_engine)
		"LEARN_THEATER_PIECE":
			return _execute_learn_theater(action, character, ctx, dice_engine)
		"PERFORM_THEATER_PIECE":
			return _execute_perform_theater(action, character, ctx, dice_engine)
		"DEDICATE_PIECE":
			return _execute_dedicate_piece(action, character, ctx, dice_engine)
	return {"success": false, "action_id": action_id, "character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season, "effects": {}}


static func _execute_compose_theater(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var meta: Dictionary = action.metadata
	var piece_id: int = meta.get("piece_id", -1)
	var is_new: bool = meta.get("is_new", false)
	var raises: int = meta.get("raises", 0)

	if is_new:
		# Declare composition intent — actual piece created in writeback
		var target_magnitude: int = meta.get("target_magnitude", 1)
		if not TheaterSystem.check_composition_skill_gate(character, target_magnitude):
			return {
				"success": false, "action_id": "COMPOSE_THEATER_PIECE",
				"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
				"effects": {"blocked_reason": "poetry_rank_insufficient"},
			}
		return {
			"success": true, "action_id": "COMPOSE_THEATER_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {
				"is_new_piece": true,
				"target_magnitude": target_magnitude,
				"target_topic_weight": meta.get("target_topic_weight", 1),
				"num_roles": meta.get("num_roles", 1),
				"framing": meta.get("framing", true),
				"subject": meta.get("subject", character.clan),
				"subject_type": meta.get("subject_type", TheaterSystem.SubjectType.CLAN),
				"topic_id": meta.get("topic_id", -1),
				"political_need_type": meta.get("political_need_type", ""),
			},
		}

	if piece_id < 0:
		return {
			"success": false, "action_id": "COMPOSE_THEATER_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_wip_piece"},
		}

	var tn: int = TheaterSystem.COMPOSITION_BASE_TN + raises * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Poetry", tn,
		raises, "", Enums.Trait.INTELLIGENCE, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)
	var progress: int = TheaterSystem.compose_progress_per_ap(total, raises)

	return {
		"success": total >= TheaterSystem.COMPOSITION_BASE_TN,
		"action_id": "COMPOSE_THEATER_PIECE",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"piece_id": piece_id,
			"roll_total": total,
			"progress_earned": progress,
			"raises": raises,
			"ic_day": ctx.ic_day,
		},
	}


static func _execute_learn_theater(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var meta: Dictionary = action.metadata
	var piece_id: int = meta.get("piece_id", -1)

	if piece_id < 0:
		return {
			"success": false, "action_id": "LEARN_THEATER_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_piece_available"},
		}

	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Acting", TheaterSystem.LEARNING_BASE_TN,
		0, "", Enums.Trait.INTELLIGENCE, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)
	var progress: int = TheaterSystem.learning_progress_per_ap(total)

	return {
		"success": total >= TheaterSystem.LEARNING_BASE_TN,
		"action_id": "LEARN_THEATER_PIECE",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"piece_id": piece_id,
			"roll_total": total,
			"progress_earned": progress,
			"ic_day": ctx.ic_day,
		},
	}


static func _execute_perform_theater(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var meta: Dictionary = action.metadata
	var piece_id: int = meta.get("piece_id", -1)
	var is_bunraku: bool = meta.get("is_bunraku_performance", false)
	var raises: int = meta.get("raises", 0)

	if piece_id < 0:
		return {
			"success": false, "action_id": "PERFORM_THEATER_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_piece_to_perform"},
		}

	var tn: int = TheaterSystem.PERFORMANCE_BASE_TN + raises * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Acting", tn,
		raises, "", Enums.Trait.AWARENESS, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)
	var success: bool = total >= tn
	var margin: int = total - TheaterSystem.PERFORMANCE_BASE_TN
	var is_critical: bool = success and margin >= TheaterSystem.CRITICAL_SUCCESS_MARGIN
	var raises_succeeded: int = raises if success else 0

	var ap_cost_override: int = 2 if is_bunraku else 1

	return {
		"success": success,
		"action_id": "PERFORM_THEATER_PIECE",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"piece_id": piece_id,
			"roll_total": total,
			"raises_succeeded": raises_succeeded,
			"is_critical": is_critical,
			"is_bunraku_performance": is_bunraku,
			"location_id": ctx.location_id,
			"ap_cost_override": ap_cost_override,
			"ic_day": ctx.ic_day,
		},
	}


static func _execute_dedicate_piece(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	var meta: Dictionary = action.metadata
	var piece_id: int = meta.get("piece_id", -1)
	var topic_id: int = meta.get("topic_id", -1)
	var raises: int = meta.get("raises", 0)

	if piece_id < 0:
		return {
			"success": false, "action_id": "DEDICATE_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_piece_to_dedicate"},
		}
	if topic_id < 0 or topic_id not in ctx.known_topics:
		return {
			"success": false, "action_id": "DEDICATE_PIECE",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_known_topic"},
		}

	# Courtier / Awareness roll vs TN 10 + magnitude * 2 (resolved in writeback since we lack piece here)
	var tn: int = TheaterSystem.DEDICATION_BASE_TN + raises * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Courtier", tn,
		raises, "", Enums.Trait.AWARENESS, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)

	return {
		"success": total >= tn,
		"action_id": "DEDICATE_PIECE",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"piece_id": piece_id,
			"topic_id": topic_id,
			"roll_total": total,
			"raises": raises,
		},
	}


# ---------------------------------------------------------------------------
# Garden and Bonsai executors (s57.23, s57.24)
# ---------------------------------------------------------------------------

static func _execute_garden_commission_action(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## REQUEST_ART: daimyo requests a garden commission from a specific artisan.
	## OFFER_ART_COMMISSION: artisan self-initiates a commission offer to a daimyo.
	## Both create a commission record via orchestrator writeback.
	var is_request: bool = action.action_id == "REQUEST_ART"
	var meta: Dictionary = action.metadata
	var zone_type: String = meta.get("zone_type", "")
	var target_quality_tier: int = clampi(meta.get("target_quality_tier", 1), 1, 5)
	var loc_int: int = int(ctx.location_id) if ctx.location_id.is_valid_int() else -1
	var settlement_id: int = meta.get("settlement_id", loc_int)
	var artisan_id: int
	var daimyo_id: int
	if is_request:
		artisan_id = meta.get("artisan_id", action.target_npc_id)
		daimyo_id = character.character_id
	else:
		artisan_id = character.character_id
		daimyo_id = meta.get("daimyo_id", action.target_npc_id)

	if zone_type.is_empty():
		return {
			"success": false,
			"action_id": action.action_id,
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "no_zone_type",
			"effects": {"blocked_reason": "no_zone_type"},
		}

	return {
		"success": true,
		"action_id": action.action_id,
		"character_id": character.character_id,
		"target_npc_id": artisan_id if is_request else daimyo_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"requires_commission_creation": true,
			"artisan_id": artisan_id,
			"daimyo_id": daimyo_id,
			"settlement_id": settlement_id,
			"zone_type": zone_type,
			"target_quality_tier": target_quality_tier,
			"is_obligated": is_request,
		},
	}


static func _execute_cultivate_garden(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Spend 1 AP to advance progress on an active commission.
	## Skill gate: Artisan: Gardening rank ≥ target_quality_tier.
	var meta: Dictionary = action.metadata
	var commission_id: int = meta.get("commission_id", -1)
	var quality_tier: int = clampi(meta.get("target_quality_tier", 1), 1, 5)
	var gardening_rank: int = character.skills.get("Artisan: Gardening", 0)

	if gardening_rank < GardenSystem.QUALITY_SKILL_GATE.get(quality_tier, 1):
		return {
			"success": false,
			"action_id": "CULTIVATE_GARDEN",
			"character_id": character.character_id,
			"target_npc_id": -1,
			"target_province_id": -1,
			"ic_day": ctx.ic_day, "season": ctx.season,
			"reason": "skill_gate_failed",
			"effects": {"blocked_reason": "skill_gate_failed"},
		}

	var tn: int = GardenSystem.QUALITY_TN.get(quality_tier, 15)
	var free_raise: int = GardenSystem.apply_gardening_free_raise(gardening_rank)
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Gardening", tn, free_raise,
		"", Enums.Trait.NONE, 0, 0, 0, ctx.ic_day
	)
	var total: int = roll.get("total", 0)
	var margin: int = total - tn
	var raises: int = maxi(int(margin / 5.0), 0)

	return {
		"success": roll.get("success", false),
		"action_id": "CULTIVATE_GARDEN",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"commission_id": commission_id,
			"roll_total": total,
			"tn": tn,
			"raises": raises,
		},
	}


static func _execute_maintain_garden(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Spend 1 AP to maintain an existing garden against tier degradation.
	var meta: Dictionary = action.metadata
	var garden_id: int = meta.get("garden_id", -1)
	var garden_tier: int = clampi(meta.get("garden_tier", 1), 1, 5)
	var gardening_rank: int = character.skills.get("Artisan: Gardening", 0)

	var tn: int = GardenSystem.QUALITY_TN.get(garden_tier, 15)
	var free_raise: int = GardenSystem.apply_gardening_free_raise(gardening_rank)
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Gardening", tn, free_raise,
		"", Enums.Trait.NONE, 0, 0, 0, ctx.ic_day
	)

	return {
		"success": roll.get("success", false),
		"action_id": "MAINTAIN_GARDEN",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"garden_id": garden_id,
			"roll_total": roll.get("total", 0),
			"tn": tn,
			"ic_season": ctx.season,
		},
	}


static func _execute_collect_bonsai_specimen(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Roll Artisan: Gardening / Perception vs TN 10 to collect a wild bonsai specimen.
	var province_id: int = action.target_province_id
	if province_id < 0:
		province_id = ctx.known_objectives.get("character_province_id", -1)

	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Gardening", GardenSystem.BONSAI_COLLECT_TN, 0,
		"", Enums.Trait.PERCEPTION, 0, 0, 0, ctx.ic_day
	)

	return {
		"success": roll.get("success", false),
		"action_id": "COLLECT_BONSAI_SPECIMEN",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": province_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"collector_id": character.character_id,
			"province_id": province_id,
			"roll_total": roll.get("total", 0),
		},
	}


static func _execute_tend_bonsai(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Roll Artisan: Gardening / Awareness vs TN 10 to tend owned bonsai.
	var meta: Dictionary = action.metadata
	var bonsai_id: int = meta.get("bonsai_id", ctx.known_objectives.get("owned_bonsai_id", -1))
	var ic_month: int = ctx.ic_day / 30

	var gardening_rank: int = character.skills.get("Artisan: Gardening", 0)
	var free_raise: int = GardenSystem.apply_gardening_free_raise(gardening_rank)
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Gardening", GardenSystem.BONSAI_TEND_TN, free_raise,
		"", Enums.Trait.NONE, 0, 0, 0, ctx.ic_day
	)
	var total: int = roll.get("total", 0)
	var margin: int = total - GardenSystem.BONSAI_TEND_TN
	var raises: int = maxi(int(margin / 5.0), 0)

	return {
		"success": roll.get("success", false),
		"action_id": "TEND_BONSAI",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"bonsai_id": bonsai_id,
			"roll_total": total,
			"raises": raises,
			"ic_month": ic_month,
		},
	}


static func _execute_display_bonsai(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## No roll required. Sets the display_settlement_id on the bonsai.
	var meta: Dictionary = action.metadata
	var bonsai_id: int = meta.get("bonsai_id", ctx.known_objectives.get("owned_bonsai_id", -1))
	var loc_int: int = int(ctx.location_id) if ctx.location_id.is_valid_int() else -1
	var settlement_id: int = meta.get("settlement_id", loc_int)

	return {
		"success": bonsai_id >= 0 and settlement_id >= 0,
		"action_id": "DISPLAY_BONSAI",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"bonsai_id": bonsai_id,
			"settlement_id": settlement_id,
		},
	}


# ---------------------------------------------------------------------------
# Painting executors (s57.27)
# ---------------------------------------------------------------------------

static func _execute_painting_action(
	action_id: String,
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
) -> Dictionary:
	match action_id:
		"COMPOSE_PAINTING":
			return _execute_compose_painting(action, character, ctx, dice_engine)
		"DISPLAY_PAINTING":
			return _execute_display_painting(action, character, ctx)
		"PRESENT_EMAKIMONO":
			return _execute_present_emakimono(action, character, ctx, characters_by_id)
	return {"success": false, "action_id": action_id, "character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season, "effects": {}}


static func _execute_compose_painting(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Advance WIP painting or declare new composition.
	## painting_id < 0 in metadata → declare new composition (writeback creates PaintingData).
	var meta: Dictionary = action.metadata
	var painting_id: int = meta.get("painting_id", ctx.known_objectives.get("active_painting_wip_id", -1))
	var painting_rank: int = character.skills.get("Artisan: Painting", 0)

	if painting_id < 0:
		# Declare new composition — actual PaintingData created in writeback.
		var target_quality: int = meta.get("target_quality_tier", clampi(painting_rank, 1, 5))
		if painting_rank < PaintingSystem.QUALITY_SKILL_GATE.get(target_quality, 1):
			return {
				"success": false, "action_id": "COMPOSE_PAINTING",
				"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
				"effects": {"blocked_reason": "insufficient_skill_rank"},
			}
		return {
			"success": true, "action_id": "COMPOSE_PAINTING",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {
				"is_new_painting": true,
				"format": meta.get("format", PaintingSystem.Format.KAKEMONO),
				"target_quality_tier": target_quality,
				"subject_type": meta.get("subject_type", PaintingSystem.SubjectType.NATURE),
				"framing": meta.get("framing", true),
				"style": meta.get("style", PaintingSystem.Style.NONE),
				"subject_id": meta.get("subject_id", -1),
				"season_affinity": meta.get("season_affinity", -1),
				"target_topic_ids": meta.get("target_topic_ids", []),
				"ic_day": ctx.ic_day,
			},
		}

	# Advance existing WIP.
	var raises_declared: int = meta.get("raises", 0)
	var tn: int = PaintingSystem.COMPOSE_TN + raises_declared * 5
	var roll: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Artisan: Painting", tn,
		raises_declared, "", Enums.Trait.AWARENESS, 0, 0, 0, ctx.ic_day,
	)
	var total: int = roll.get("total", 0)

	return {
		"success": roll.get("success", false),
		"action_id": "COMPOSE_PAINTING",
		"character_id": character.character_id,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"painting_id": painting_id,
			"roll_total": total,
			"raises_declared": raises_declared,
			"painter_rank": painting_rank,
			"ic_day": ctx.ic_day,
		},
	}


static func _execute_display_painting(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## No roll. Sets display_settlement_id on painting — slot mutation in writeback.
	var meta: Dictionary = action.metadata
	var painting_id: int = meta.get("painting_id", -1)
	var loc_int: int = int(ctx.location_id) if ctx.location_id.is_valid_int() else -1
	var settlement_id: int = meta.get("settlement_id", loc_int)
	var slot: int = meta.get("slot", PaintingSystem.DisplaySlot.WALL_ART)

	return {
		"success": painting_id >= 0 and settlement_id >= 0,
		"action_id": "DISPLAY_PAINTING",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"painting_id": painting_id,
			"settlement_id": settlement_id,
			"slot": slot,
		},
	}


static func _execute_present_emakimono(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	characters_by_id: Dictionary,
) -> Dictionary:
	## No roll. Collect co-located living characters as recipients.
	## PaintingSystem.resolve_present_emakimono() applied in writeback.
	var meta: Dictionary = action.metadata
	var painting_id: int = meta.get("painting_id", -1)

	if painting_id < 0:
		return {
			"success": false, "action_id": "PRESENT_EMAKIMONO",
			"character_id": character.character_id, "ic_day": ctx.ic_day, "season": ctx.season,
			"effects": {"blocked_reason": "no_emakimono_selected"},
		}

	# Gather co-located living recipients (excluding presenter).
	var recipient_ids: Array = []
	var presenter_loc: String = character.physical_location
	for cid: int in characters_by_id:
		if cid == character.character_id:
			continue
		var other = characters_by_id.get(cid)
		if not other:
			continue
		if CharacterStats.is_dead(other):
			continue
		if other.physical_location != presenter_loc:
			continue
		recipient_ids.append(cid)

	return {
		"success": painting_id >= 0,
		"action_id": "PRESENT_EMAKIMONO",
		"character_id": character.character_id,
		"target_npc_id": -1,
		"target_province_id": -1,
		"ic_day": ctx.ic_day, "season": ctx.season,
		"effects": {
			"painting_id": painting_id,
			"recipient_ids": recipient_ids,
			"ic_day": ctx.ic_day,
		},
	}
