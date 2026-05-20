class_name EffectApplicator
## Applies executor result effects to world state.
## Takes the result dict from ActionExecutor.execute() and mutates
## character data, province data, and the action log accordingly.
## This is the final step that closes the loop: decision → execution → mutation.


# -- Main Entry Point ---------------------------------------------------------

static func apply(
	result: Dictionary,
	characters: Dictionary,
	provinces: Dictionary,
	action_log: Array[Dictionary],
	settlements: Array[SettlementData] = [],
) -> Dictionary:
	var applied: Dictionary = {
		"disposition_changes": [],
		"honor_changes": [],
		"glory_changes": [],
		"infamy_changes": [],
		"province_updates": [],
		"info_events": [],
		"logged": false,
	}

	if not result.get("success", false) and not result.get("effects", {}).has("failed"):
		_log_action(result, action_log)
		applied["logged"] = true
		return applied

	var effects: Dictionary = result.get("effects", {})
	var actor_id: int = result.get("character_id", -1)
	var target_id: int = result.get("target_npc_id", -1)
	var actor: L5RCharacterData = characters.get(actor_id)

	if actor == null:
		return applied

	_apply_disposition(effects, actor, target_id, applied)
	_apply_recipient_effects(effects, actor, target_id, characters, applied)
	_apply_koku_cost(effects, actor)
	_apply_witness_effects(effects, actor, characters, applied)
	_apply_witness_gain(effects, actor, characters, applied)
	_apply_gossip_effects(effects, actor_id, target_id, characters, applied,
		result.get("season", 0))
	_apply_target_witness_effects(effects, target_id, characters, applied)
	_apply_disposition_ripple(effects, actor, target_id, characters, applied)
	_apply_honor(effects, actor, applied)
	_apply_glory(effects, actor, applied)
	_apply_winner_glory(effects, characters, applied)
	_apply_infamy(effects, actor, applied)
	_apply_province_effects(effects, result, provinces, applied, settlements)
	_apply_info_events(effects, result, applied)
	_apply_false_info(effects, actor, target_id, characters, result.get("season", 0))
	result["observable_effect"] = _detect_observable_effect(result, effects, applied)
	_log_action(result, action_log)
	applied["logged"] = true

	return applied


# -- Disposition ---------------------------------------------------------------

static func _apply_disposition(
	effects: Dictionary,
	actor: L5RCharacterData,
	target_id: int,
	applied: Dictionary,
) -> void:
	var disp_change: int = effects.get("disposition_change", 0)
	if disp_change == 0 or target_id < 0:
		return

	var old_val: int = actor.disposition_values.get(target_id, 0)
	var new_val: int = clampi(old_val + disp_change, -100, 100)
	actor.disposition_values[target_id] = new_val

	applied["disposition_changes"].append({
		"actor_id": actor.character_id,
		"target_id": target_id,
		"old": old_val,
		"new": new_val,
		"delta": disp_change,
	})


# -- Recipient-side effects (gifts, etc.) -------------------------------------
#
# Some actions (DELIVER_GIFT especially) mutate the *recipient*'s disposition
# toward the actor, not the actor's disposition toward the recipient. They
# may also append temporary modifier dicts to the recipient and consume an
# item from the actor's inventory.

static func _apply_recipient_effects(
	effects: Dictionary,
	actor: L5RCharacterData,
	target_id: int,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var consume_id: int = effects.get("consume_item_id", -1)
	if consume_id >= 0:
		_remove_item_by_id(actor, consume_id)

	if target_id < 0:
		return
	var recipient: L5RCharacterData = characters.get(target_id)
	if recipient == null:
		return

	var disp_change: int = effects.get("recipient_disposition_change", 0)
	if disp_change != 0:
		var old_val: int = recipient.disposition_values.get(actor.character_id, 0)
		var new_val: int = clampi(old_val + disp_change, -100, 100)
		recipient.disposition_values[actor.character_id] = new_val
		applied["disposition_changes"].append({
			"actor_id": recipient.character_id,
			"target_id": actor.character_id,
			"old": old_val,
			"new": new_val,
			"delta": disp_change,
		})

	var modifiers: Array[Dictionary] = effects.get("recipient_modifiers", [])
	if not modifiers.is_empty():
		var bucket: Array[Dictionary] = recipient.temporary_modifiers.get(actor.character_id, [])
		for mod: Dictionary in modifiers:
			bucket.append(mod)
		recipient.temporary_modifiers[actor.character_id] = bucket


static func _remove_item_by_id(actor: L5RCharacterData, item_id: int) -> void:
	for i in range(actor.items.size()):
		var item: Dictionary = actor.items[i]
		if item.get("item_id", -1) == item_id:
			actor.items.remove_at(i)
			return


# -- Koku cost deduction -------------------------------------------------------

static func _apply_koku_cost(effects: Dictionary, actor: L5RCharacterData) -> void:
	var cost: float = effects.get("koku_cost", 0.0)
	if cost > 0.0:
		actor.koku = maxf(0.0, actor.koku - cost)


# -- Witness disposition loss ---------------------------------------------------

static func _apply_witness_effects(
	effects: Dictionary,
	actor: L5RCharacterData,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var disp_loss: int = effects.get("witness_disposition_loss", 0)
	if disp_loss == 0:
		return
	var witness_ids: Array[int] = effects.get("witnesses", [])
	if witness_ids.is_empty():
		return

	for wid: int in witness_ids:
		var witness: L5RCharacterData = characters.get(wid)
		if witness == null or witness.character_id == actor.character_id:
			continue
		var old_val: int = witness.disposition_values.get(actor.character_id, 0)
		var new_val: int = clampi(old_val + disp_loss, -100, 100)
		witness.disposition_values[actor.character_id] = new_val
		applied["disposition_changes"].append({
			"actor_id": witness.character_id,
			"target_id": actor.character_id,
			"old": old_val,
			"new": new_val,
			"delta": disp_loss,
		})


# -- Witness disposition gain (broadcast actions, s12.2 Category 2) ------------

static func _apply_witness_gain(
	effects: Dictionary,
	actor: L5RCharacterData,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var disp_gain: int = effects.get("witness_disposition_gain", 0)
	if disp_gain == 0:
		return
	var witness_ids: Array[int] = effects.get("witnesses", [])
	if witness_ids.is_empty():
		return

	for wid: int in witness_ids:
		var witness: L5RCharacterData = characters.get(wid)
		if witness == null or witness.character_id == actor.character_id:
			continue
		var old_val: int = witness.disposition_values.get(actor.character_id, 0)
		var new_val: int = clampi(old_val + disp_gain, -100, 100)
		witness.disposition_values[actor.character_id] = new_val
		applied["disposition_changes"].append({
			"actor_id": witness.character_id,
			"target_id": actor.character_id,
			"old": old_val,
			"new": new_val,
			"delta": disp_gain,
		})


# -- Gossip 3rd-party targeting (s15.4) ----------------------------------------

static func _apply_gossip_effects(
	effects: Dictionary,
	gossiper_id: int,
	listener_id: int,
	characters: Dictionary,
	applied: Dictionary,
	season: int = 0,
) -> void:
	var subject_id: int = effects.get("gossip_subject_id", -1)
	var disp_change: int = effects.get("gossip_subject_disposition", 0)
	if subject_id < 0 or disp_change == 0 or listener_id < 0:
		return
	var listener: L5RCharacterData = characters.get(listener_id)
	if listener == null:
		return
	var old_val: int = listener.disposition_values.get(subject_id, 0)
	var new_val: int = clampi(old_val + disp_change, -100, 100)
	listener.disposition_values[subject_id] = new_val
	applied["disposition_changes"].append({
		"actor_id": listener_id,
		"target_id": subject_id,
		"old": old_val,
		"new": new_val,
		"delta": disp_change,
	})
	var concealed: bool = effects.get("source_concealed", false)
	var source_id: int = -1 if concealed else gossiper_id
	InformationSystem.add_knowledge(listener, InformationSystem.make_entry(
		Enums.KnowledgeSource.DAILY_CONVERSATION,
		"gossip_received",
		{"subject_id": subject_id, "gossiper_id": source_id},
		season,
	))


# -- Per-witness disposition toward target (PUBLIC_INSULT) ---------------------

static func _apply_target_witness_effects(
	effects: Dictionary,
	target_id: int,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var disp_change: int = effects.get("target_witness_disposition", 0)
	if disp_change == 0 or target_id < 0:
		return
	var witness_ids: Array[int] = effects.get("witnesses", [])
	if witness_ids.is_empty():
		return
	for wid: int in witness_ids:
		var witness: L5RCharacterData = characters.get(wid)
		if witness == null or witness.character_id == target_id:
			continue
		var old_val: int = witness.disposition_values.get(target_id, 0)
		var new_val: int = clampi(old_val + disp_change, -100, 100)
		witness.disposition_values[target_id] = new_val
		applied["disposition_changes"].append({
			"actor_id": witness.character_id,
			"target_id": target_id,
			"old": old_val,
			"new": new_val,
			"delta": disp_change,
		})


# -- Family/Clan Disposition Ripple (s12.2) ------------------------------------
# Per GDD: every disposition change applies +2 to target's family members,
# +1 to target's clan members (proportional direction, flat amounts).

static func _apply_disposition_ripple(
	effects: Dictionary,
	actor: L5RCharacterData,
	target_id: int,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var disp_change: int = effects.get("disposition_change", 0)
	if disp_change == 0 or target_id < 0:
		return
	var target: L5RCharacterData = characters.get(target_id)
	if target == null:
		return

	var direction: int = 1 if disp_change > 0 else -1
	var target_clan: String = target.clan
	var target_family: String = target.family

	if target_clan.is_empty():
		return

	for cid: int in characters:
		if cid == actor.character_id or cid == target_id:
			continue
		var c: L5RCharacterData = characters[cid]
		if c.clan != target_clan:
			continue

		var ripple: int = 0
		if c.family == target_family and not target_family.is_empty():
			ripple = DispositionSystem.FAMILY_RIPPLE * direction
		else:
			ripple = DispositionSystem.CLAN_RIPPLE * direction

		var old_val: int = actor.disposition_values.get(cid, 0)
		var cap: int = DispositionSystem.FAMILY_RIPPLE_CAP if c.family == target_family else DispositionSystem.CLAN_RIPPLE_CAP
		if absi(old_val) >= cap:
			continue
		var new_val: int = clampi(old_val + ripple, -100, 100)
		if absi(new_val) > cap:
			new_val = cap * direction
		actor.disposition_values[cid] = new_val

		applied["disposition_changes"].append({
			"actor_id": actor.character_id,
			"target_id": cid,
			"old": old_val,
			"new": new_val,
			"delta": new_val - old_val,
			"ripple": true,
		})


# -- Honor ---------------------------------------------------------------------

static func _apply_honor(
	effects: Dictionary,
	actor: L5RCharacterData,
	applied: Dictionary,
) -> void:
	var honor_change: float = effects.get("honor_change", 0.0)
	if absf(honor_change) < 0.001:
		return

	var actual: float = HonorGlorySystem.apply_honor_change(actor, honor_change)
	applied["honor_changes"].append({
		"character_id": actor.character_id,
		"delta": actual,
		"new_honor": actor.honor,
	})


# -- Glory ---------------------------------------------------------------------

static func _apply_glory(
	effects: Dictionary,
	actor: L5RCharacterData,
	applied: Dictionary,
) -> void:
	var glory_change: float = effects.get("glory_change", 0.0)
	if absf(glory_change) < 0.001:
		return

	var actual: float = HonorGlorySystem.apply_glory_change(actor, glory_change)
	applied["glory_changes"].append({
		"character_id": actor.character_id,
		"delta": actual,
		"new_glory": actor.glory,
	})


static func _apply_winner_glory(
	effects: Dictionary,
	characters: Dictionary,
	applied: Dictionary,
) -> void:
	var winner_glory: float = effects.get("winner_glory_change", 0.0)
	if absf(winner_glory) < 0.001:
		return
	var winner_id: int = effects.get("winner_glory_recipient_id", -1)
	var winner: L5RCharacterData = characters.get(winner_id)
	if winner == null:
		return
	var actual: float = HonorGlorySystem.apply_glory_change(winner, winner_glory)
	applied["glory_changes"].append({
		"character_id": winner.character_id,
		"delta": actual,
		"new_glory": winner.glory,
	})


# -- Infamy --------------------------------------------------------------------

static func _apply_infamy(
	effects: Dictionary,
	actor: L5RCharacterData,
	applied: Dictionary,
) -> void:
	var infamy_change: float = effects.get("infamy_gain", effects.get("infamy_change", 0.0))
	if absf(infamy_change) < 0.001:
		return

	var actual: float = HonorGlorySystem.apply_infamy_change(actor, infamy_change)
	applied["infamy_changes"].append({
		"character_id": actor.character_id,
		"delta": actual,
		"new_infamy": actor.infamy,
	})


# -- Province Effects ----------------------------------------------------------

static func _apply_province_effects(
	effects: Dictionary,
	result: Dictionary,
	provinces: Dictionary,
	applied: Dictionary,
	settlements: Array[SettlementData] = [],
) -> void:
	var effect_type: String = effects.get("effect", "")
	var province_id: int = result.get("target_province_id", -1)

	if province_id < 0 or not provinces.has(province_id):
		return

	var province: ProvinceData = provinces[province_id]

	match effect_type:
		"patrol_dispatched":
			# Placeholder: GDD patrol → insurgency suppression, not direct stability.
			province.stability = minf(province.stability + 2.0, 100.0)
			applied["province_updates"].append({
				"province_id": province_id,
				"effect": "stability_increase",
				"delta": 2.0,
				"new_stability": province.stability,
			})
		"garrison_assigned":
			var target_settlement: SettlementData = _find_settlement_in_province(province_id, settlements)
			if target_settlement != null:
				target_settlement.garrison_pu += 1
			applied["province_updates"].append({
				"province_id": province_id,
				"effect": "garrison_increase",
			})
		"intelligence_gathered":
			province.last_report_ic_day = result.get("ic_day", -1)
			applied["province_updates"].append({
				"province_id": province_id,
				"effect": "report_refreshed",
				"ic_day": province.last_report_ic_day,
			})


static func _find_settlement_in_province(
	province_id: int,
	settlements: Array[SettlementData],
) -> SettlementData:
	for s: SettlementData in settlements:
		if s.province_id == province_id:
			return s
	return null


# -- Information Events --------------------------------------------------------

static func _apply_info_events(
	effects: Dictionary,
	result: Dictionary,
	applied: Dictionary,
) -> void:
	if not effects.get("info_gained", false):
		return

	applied["info_events"].append({
		"character_id": result.get("character_id", -1),
		"action_id": result.get("action_id", ""),
		"target_npc_id": result.get("target_npc_id", -1),
		"target_province_id": result.get("target_province_id", -1),
		"ic_day": result.get("ic_day", -1),
		"quality": effects.get("quality", 1),
		"info_type": effects.get("info_type", ""),
	})


# -- False Info on Critical Failure (s15.4) ------------------------------------

static func _apply_false_info(
	effects: Dictionary,
	actor: L5RCharacterData,
	target_id: int,
	characters: Dictionary,
	season: int,
) -> void:
	var false_info: Array = effects.get("false_info", [])
	if false_info.is_empty() or target_id < 0:
		return
	var target: L5RCharacterData = characters.get(target_id)
	if target == null:
		return
	for info_type: String in false_info:
		var data: Dictionary = _generate_false_data(info_type, actor, target)
		data["target_character_id"] = target_id
		InformationSystem.update_intelligence_knowledge(actor, InformationSystem.make_entry(
			Enums.KnowledgeSource.INTELLIGENCE,
			info_type,
			data,
			season,
		))


static func _generate_false_data(
	info_type: String,
	actor: L5RCharacterData,
	target: L5RCharacterData,
) -> Dictionary:
	match info_type:
		"personality_insight":
			var actual: int = target.bushido_virtue
			var false_virtue: int = _pick_different_virtue(actual)
			return {"bushido_virtue": false_virtue, "is_false": true}
		"disposition_toward":
			var actual_disp: int = target.disposition_values.get(actor.character_id, 0)
			var inverted: int = clampi(-actual_disp, -100, 100)
			if inverted == 0:
				inverted = 15
			return {"toward_id": actor.character_id, "disposition": inverted, "is_false": true}
		"topic_attitude", "topic_position":
			if target.topic_positions.is_empty():
				return {"is_false": true}
			var tid: int = target.topic_positions.keys()[0]
			var actual_pos: float = target.topic_positions[tid]
			return {"topic_id": tid, "position": -actual_pos, "is_false": true}
		"court_objective":
			return {"need_type": "unknown", "is_false": true}
	return {"is_false": true}


const _BUSHIDO_VALUES: Array[int] = [
	Enums.BushidoVirtue.JIN, Enums.BushidoVirtue.YU,
	Enums.BushidoVirtue.REI, Enums.BushidoVirtue.CHUGI,
	Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO,
	Enums.BushidoVirtue.MAKOTO,
]


static func _pick_different_virtue(actual: int) -> int:
	for v: int in _BUSHIDO_VALUES:
		if v != actual:
			return v
	return Enums.BushidoVirtue.JIN


# -- Action Log ----------------------------------------------------------------

static func _log_action(
	result: Dictionary,
	action_log: Array[Dictionary],
) -> void:
	var entry: Dictionary = {
		"character_id": result.get("character_id", -1),
		"action_id": result.get("action_id", ""),
		"target_npc_id": result.get("target_npc_id", -1),
		"target_province_id": result.get("target_province_id", -1),
		"ic_day": result.get("ic_day", -1),
		"season": result.get("season", 0),
		"success": result.get("success", false),
		"skill_used": result.get("skill_used", ""),
		"is_order": result.get("is_order", false),
		"roll_result": result.get("roll_total", 0),
		"tn": result.get("tn", 0),
		"observable_effect": result.get("observable_effect", false),
	}
	var effects: Dictionary = result.get("effects", {})
	if effects.has("source_concealed"):
		entry["source_concealed"] = effects["source_concealed"]
		entry["concealment_depth"] = effects.get("concealment_depth", 0)
	action_log.append(entry)


# -- Observable Effect Detection -----------------------------------------------

const DISPOSITION_TIER_BOUNDARIES: Array[int] = [-61, -31, -11, 11, 31, 61, 91]


static func _get_disposition_tier(value: int) -> int:
	for i: int in range(DISPOSITION_TIER_BOUNDARIES.size()):
		if value < DISPOSITION_TIER_BOUNDARIES[i]:
			return i
	return DISPOSITION_TIER_BOUNDARIES.size()


static func _detect_observable_effect(
	result: Dictionary,
	effects: Dictionary,
	applied: Dictionary,
) -> bool:
	var _action_id: String = result.get("action_id", "")

	if effects.get("info_gained", false):
		return true

	var disp_changes: Array[Dictionary] = applied.get("disposition_changes", [])
	for change: Dictionary in disp_changes:
		var old_tier: int = _get_disposition_tier(change.get("old", 0))
		var new_tier: int = _get_disposition_tier(change.get("new", 0))
		if old_tier != new_tier:
			return true

	var province_updates: Array[Dictionary] = applied.get("province_updates", [])
	if province_updates.size() > 0:
		return true

	return false


# -- Batch Apply ---------------------------------------------------------------

static func apply_day_results(
	results: Array[Dictionary],
	characters: Dictionary,
	provinces: Dictionary,
	action_log: Array[Dictionary],
	settlements: Array[SettlementData] = [],
) -> Array[Dictionary]:
	var all_applied: Array[Dictionary] = []
	for result: Dictionary in results:
		var applied: Dictionary = apply(result, characters, provinces, action_log, settlements)
		all_applied.append(applied)
	return all_applied
