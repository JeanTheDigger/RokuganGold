extends GutTest


var _dice_engine: DiceEngine
var _character: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot
var _action_skill_map: Dictionary


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)

	_character = L5RCharacterData.new()
	_character.character_id = 1
	_character.character_name = "Test Samurai"
	_character.reflexes = 3
	_character.awareness = 4
	_character.stamina = 3
	_character.willpower = 3
	_character.agility = 3
	_character.intelligence = 3
	_character.strength = 3
	_character.perception = 3
	_character.void_ring = 2
	_character.skills = {
		"Etiquette": 4,
		"Courtier": 3,
		"Sincerity": 3,
		"Investigation": 2,
		"Intimidation": 2,
		"Battle": 2,
		"Commerce": 1,
		"Stealth": 2,
		"Temptation": 1,
	}
	_character.emphases = {}
	_character.wounds_taken = 0

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.character_name = "Test Samurai"
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	_ctx.ic_day = 10
	_ctx.dispositions = {10: 25, 20: -35, 30: 50}
	_ctx.characters_present = [10, 20, 30]

	_action_skill_map = {
		"CHARM": {"primary": "Etiquette", "secondary": "Courtier"},
		"INTIMIDATE": {"primary": "Intimidation", "secondary": null},
		"PROBE": {"primary": "Courtier", "secondary": "Perception"},
		"GOSSIP": {"primary": "Courtier", "secondary": "Awareness"},
		"WRITE_LETTER": {"primary": "Calligraphy", "secondary": "Courtier"},
		"BRIBE_FOR_INFO": {"primary": "Temptation", "secondary": "Awareness"},
		"EAVESDROP": {"primary": "Stealth", "secondary": "Investigation"},
		"ORDER_PATROL": {"primary": "Investigation", "secondary": "Battle"},
		"ASSESS_PROVINCE_STATUS": {"primary": "Battle", "secondary": "Commerce"},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"REST": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
		"PUBLIC_DEBATE": {"primary": "Courtier", "secondary": "Awareness"},
		"PUBLIC_INSULT": {"primary": "Courtier", "secondary": "Awareness"},
	}


func _make_action(action_id: String, target_npc: int = -1) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_npc
	a.ap_cost = 1
	return a


# -- No-Roll Actions -----------------------------------------------------------

func test_do_nothing_succeeds() -> void:
	var action := _make_action("DO_NOTHING")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_true(result["success"])
	assert_eq(result["action_id"], "DO_NOTHING")
	assert_eq(result["roll_total"], 0)


func test_rest_succeeds() -> void:
	var action := _make_action("REST")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_true(result["success"])
	assert_eq(result["effects"]["effect"], "rested")


func test_train_no_roll_placeholder_skill() -> void:
	var action := _make_action("TRAIN")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_true(result["success"])


# -- Social Actions ------------------------------------------------------------

func test_charm_makes_skill_roll() -> void:
	var action := _make_action("CHARM", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["action_id"], "CHARM")
	assert_eq(result["skill_used"], "Etiquette")
	assert_true(result["roll_total"] > 0)
	assert_eq(result["target_npc_id"], 10)


func test_charm_tn_adjusted_by_disposition() -> void:
	var action := _make_action("CHARM", 30)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	# Disposition 50 = Friend tier: TN reduced by 5
	assert_eq(result["tn"], 10)


func test_charm_hostile_target_higher_tn() -> void:
	var action := _make_action("CHARM", 20)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	# Disposition -35 = Enemy tier (s57.3): TN +5
	assert_eq(result["tn"], 20)


func test_social_success_produces_disposition_change() -> void:
	_dice_engine.set_seed(1)
	var action := _make_action("CHARM", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		var raises: int = maxi(result.get("margin", 0) / 5, 0)
		assert_eq(result["effects"]["disposition_change"], 8 + raises * 3)


func test_social_failure_produces_no_disposition_change() -> void:
	# Per GDD s12.2: no disposition change on normal failure.
	# Critical failure (margin ≤ -10) has action-specific penalties.
	_dice_engine.set_seed(999)
	_ctx.dispositions[20] = -70
	var action := _make_action("CHARM", 20)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if not result["success"]:
		var disp: int = result["effects"].get("disposition_change", 0)
		# Normal failure: 0. Critical failure (margin ≤ -10): -5 for CHARM.
		if result.get("margin", 0) <= -10:
			assert_eq(disp, -5)
		else:
			assert_eq(disp, 0)


func test_probe_produces_info_gained() -> void:
	_dice_engine.set_seed(1)
	var action := _make_action("PROBE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		assert_true(result["effects"]["info_gained"])


func test_public_debate_produces_glory_on_high_raises() -> void:
	# Per GDD s12.2: PUBLIC_DEBATE glory = 0.3 only if 3+ raises (margin ≥ 15)
	_dice_engine.set_seed(1)
	var action := _make_action("PUBLIC_DEBATE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		var raises: int = maxi(result.get("margin", 0) / 5, 0)
		var expected: float = 0.3 if raises >= 3 else 0.0
		assert_almost_eq(result["effects"]["glory_change"], expected, 0.001)


func test_intimidate_falls_through_without_characters() -> void:
	_dice_engine.set_seed(1)
	var action := _make_action("INTIMIDATE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		assert_eq(result["effects"].get("disposition_change", 0), 0)


# -- GOSSIP 3rd-party targeting (s15.4) ----------------------------------------

func test_gossip_success_changes_listener_disposition_toward_subject() -> void:
	var listener := L5RCharacterData.new()
	listener.character_id = 10
	listener.character_name = "Listener"
	listener.glory = 2.0
	listener.disposition_values = {99: 20}

	var subject := L5RCharacterData.new()
	subject.character_id = 99
	subject.character_name = "Subject"
	subject.glory = 3.0

	_character.glory = 2.0
	var chars: Dictionary = {1: _character, 10: listener, 99: subject}

	_dice_engine.set_seed(1)
	var action := _make_action("GOSSIP", 10)
	action.metadata = {"gossip_subject_id": 99}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		assert_eq(result["effects"].get("gossip_subject_id", -1), 99)
		assert_true(result["effects"].get("gossip_subject_disposition", 0) <= -5)


func test_gossip_effects_applied_to_listener() -> void:
	var listener := L5RCharacterData.new()
	listener.character_id = 10
	listener.character_name = "Listener"
	listener.glory = 2.0
	listener.disposition_values = {99: 20}

	var subject := L5RCharacterData.new()
	subject.character_id = 99
	subject.character_name = "Subject"
	subject.glory = 3.0

	_character.glory = 2.0
	var chars: Dictionary = {1: _character, 10: listener, 99: subject}

	_dice_engine.set_seed(1)
	var action := _make_action("GOSSIP", 10)
	action.metadata = {"gossip_subject_id": 99}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		var applied: Dictionary = EffectApplicator.apply(
			result, chars, {}, []
		)
		assert_true(listener.disposition_values[99] < 20)


func test_gossip_critical_failure_penalizes_gossiper() -> void:
	var listener := L5RCharacterData.new()
	listener.character_id = 10
	listener.character_name = "Listener"
	listener.glory = 2.0

	var subject := L5RCharacterData.new()
	subject.character_id = 99
	subject.character_name = "Subject"
	subject.glory = 8.0

	_character.glory = 1.0
	var chars: Dictionary = {1: _character, 10: listener, 99: subject}

	_dice_engine.set_seed(999)
	var action := _make_action("GOSSIP", 10)
	action.metadata = {"gossip_subject_id": 99}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if not result["success"] and result.get("margin", 0) <= -10:
		assert_eq(result["effects"].get("disposition_change", 0), -5)


# -- PUBLIC_INSULT per-witness targeting (s15.4) -------------------------------

func test_public_insult_success_affects_witnesses_toward_target() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.awareness = 2
	target.skills = {"Etiquette": 1}
	target.emphases = {}
	target.wounds_taken = 0
	target.physical_location = "castle_court"

	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {10: 15}
	witness.physical_location = "castle_court"

	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 10: target, 30: witness}

	_dice_engine.set_seed(1)
	var action := _make_action("PUBLIC_INSULT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		assert_true(result["effects"].get("target_witness_disposition", 0) <= -2)
		assert_true(result["effects"].get("witnesses", []).size() > 0)


func test_public_insult_effects_applied_to_witnesses() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.awareness = 2
	target.skills = {"Etiquette": 1}
	target.emphases = {}
	target.wounds_taken = 0
	target.physical_location = "castle_court"

	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {10: 15}
	witness.physical_location = "castle_court"

	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 10: target, 30: witness}

	_dice_engine.set_seed(1)
	var action := _make_action("PUBLIC_INSULT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		var applied: Dictionary = EffectApplicator.apply(
			result, chars, {}, []
		)
		assert_true(witness.disposition_values[10] < 15)


func test_public_insult_failure_backfires_on_insulter() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.awareness = 5
	target.skills = {"Etiquette": 5}
	target.emphases = {}
	target.wounds_taken = 0
	target.physical_location = "castle_court"

	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {1: 10}
	witness.physical_location = "castle_court"

	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 10: target, 30: witness}

	_dice_engine.set_seed(999)
	var action := _make_action("PUBLIC_INSULT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if not result["success"]:
		assert_eq(result["effects"].get("witness_disposition_loss", 0), -2)
		assert_true(result["effects"].get("witnesses", []).size() > 0)


# -- Intimidation System Routing -----------------------------------------------

func test_intimidate_routes_through_system_when_target_available() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.honor = 3.0
	target.reflexes = 3
	target.awareness = 3
	target.willpower = 3
	target.skills = {"Etiquette": 2}
	target.emphases = {}
	target.wounds_taken = 0
	var chars: Dictionary = {1: _character, 10: target}

	_dice_engine.set_seed(42)
	var action := _make_action("INTIMIDATE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "INTIMIDATE")
	assert_eq(result["skill_used"], "Intimidation")
	assert_true(result["effects"].has("honor_change"))
	assert_true(result["effects"].has("infamy_gain"))
	assert_true(result["effects"].has("compliance_active"))


func test_intimidate_public_includes_witnesses() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.honor = 3.0
	target.reflexes = 3
	target.awareness = 3
	target.willpower = 3
	target.physical_location = "Castle_Doji"
	target.skills = {"Etiquette": 2}
	target.emphases = {}
	target.wounds_taken = 0

	var bystander := L5RCharacterData.new()
	bystander.character_id = 20
	bystander.character_name = "Bystander"
	bystander.physical_location = "Castle_Doji"
	_character.physical_location = "Castle_Doji"

	var chars: Dictionary = {1: _character, 10: target, 20: bystander}
	_ctx.context_flag = Enums.ContextFlag.AT_COURT

	_dice_engine.set_seed(42)
	var action := _make_action("INTIMIDATE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "INTIMIDATE")
	if result["effects"].has("witnesses"):
		assert_true(result["effects"]["witnesses"].size() > 0)


func test_intimidate_blackmail_uses_secret_tier() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.honor = 3.0
	target.reflexes = 3
	target.awareness = 3
	target.willpower = 3
	target.skills = {"Etiquette": 2}
	target.emphases = {}
	target.wounds_taken = 0
	var chars: Dictionary = {1: _character, 10: target}

	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_dice_engine.set_seed(42)
	var action := _make_action("INTIMIDATE", 10)
	action.metadata = {"secret_ref": true, "secret_tier": 1}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "INTIMIDATE")
	assert_almost_eq(result["effects"]["honor_change"], -0.3, 0.01)
	assert_almost_eq(result["effects"]["infamy_gain"], 0.1, 0.01)
	if result["success"]:
		assert_true(result["effects"].has("favors_extracted"))


func test_intimidate_falls_through_without_characters_by_id() -> void:
	_dice_engine.set_seed(42)
	var action := _make_action("INTIMIDATE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["action_id"], "INTIMIDATE")
	assert_false(result["effects"].has("infamy_gain"))


# -- Covert Actions ------------------------------------------------------------

func test_bribe_for_info_uses_temptation() -> void:
	var action := _make_action("BRIBE_FOR_INFO", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["skill_used"], "Temptation")
	assert_eq(result["tn"], 20)


func test_eavesdrop_covert_tn() -> void:
	var action := _make_action("EAVESDROP")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["skill_used"], "Stealth")
	assert_eq(result["tn"], 20)


func test_covert_success_produces_info_and_detection() -> void:
	_dice_engine.set_seed(1)
	var action := _make_action("EAVESDROP")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		assert_true(result["effects"]["info_gained"])
		assert_true(result["effects"].has("detection_risk"))


# -- Military Actions ----------------------------------------------------------

func test_order_patrol_military_tn() -> void:
	var action := _make_action("ORDER_PATROL")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["skill_used"], "Investigation")
	assert_eq(result["tn"], 15)


func test_military_success_produces_effect() -> void:
	_dice_engine.set_seed(1)
	var action := _make_action("ORDER_PATROL")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	if result["success"]:
		assert_eq(result["effects"]["effect"], "patrol_dispatched")


# -- Administrative Actions ----------------------------------------------------

func test_assess_province_admin_tn() -> void:
	var action := _make_action("ASSESS_PROVINCE_STATUS")
	action.target_province_id = 5
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["skill_used"], "Battle")
	assert_eq(result["tn"], 10)
	assert_eq(result["target_province_id"], 5)


# -- Result Structure ----------------------------------------------------------

func test_result_contains_required_fields() -> void:
	var action := _make_action("CHARM", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_true(result.has("success"))
	assert_true(result.has("action_id"))
	assert_true(result.has("character_id"))
	assert_true(result.has("target_npc_id"))
	assert_true(result.has("ic_day"))
	assert_true(result.has("skill_used"))
	assert_true(result.has("roll_total"))
	assert_true(result.has("tn"))
	assert_true(result.has("margin"))
	assert_true(result.has("effects"))


func test_result_character_id_matches_context() -> void:
	var action := _make_action("CHARM", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["character_id"], 1)
	assert_eq(result["ic_day"], 10)


# -- Disposition TN Modifiers --------------------------------------------------

func test_tn_floor_is_5() -> void:
	_ctx.dispositions[30] = 100
	var action := _make_action("CHARM", 30)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_true(result["tn"] >= 5)


func test_stranger_disposition_no_modifier() -> void:
	_ctx.dispositions[10] = 0
	var action := _make_action("CHARM", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["tn"], 15)


func test_unknown_target_uses_base_tn() -> void:
	var action := _make_action("CHARM", 999)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["tn"], 15)


# -- DELIVER_GIFT wiring ------------------------------------------------------

func _make_recipient(id: int, school_type: Enums.SchoolType) -> L5RCharacterData:
	var r := L5RCharacterData.new()
	r.character_id = id
	r.school_type = school_type
	return r


func test_deliver_gift_falls_through_when_no_inventory() -> void:
	# No items in inventory and no characters_by_id provided.
	# The gift path returns {} and execution falls through to generic social.
	var action := _make_action("DELIVER_GIFT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	# Generic social path uses Etiquette and applies the standard social
	# disposition_change (no recipient_disposition_change).
	assert_false(result["effects"].has("gift_outcome"))


func test_deliver_gift_falls_through_when_recipient_unknown() -> void:
	var gift: Dictionary = InventorySystem.create_gift_item(
		1, "Fine Calligraphy",
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.QualityTier.FINE,
	)
	_character.items = [gift]
	var action := _make_action("DELIVER_GIFT", 10)
	# characters_by_id is empty — recipient cannot be resolved.
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_false(result["effects"].has("gift_outcome"))
	assert_true(_character.items.size() == 1)  # Item not consumed.


func test_deliver_gift_routes_to_gift_giving_system() -> void:
	var gift: Dictionary = InventorySystem.create_gift_item(
		7, "Masterwork Tea Bowl",
		GiftGivingSystem.GiftCategory.TEA_IMPLEMENTS,
		GiftGivingSystem.QualityTier.MASTERWORK,
	)
	_character.items = [gift]
	var recipient: L5RCharacterData = _make_recipient(10, Enums.SchoolType.COURTIER)
	var characters_by_id: Dictionary = {10: recipient}

	var action := _make_action("DELIVER_GIFT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, characters_by_id,
	)
	assert_true(result["effects"].has("gift_outcome"))
	assert_eq(result["effects"]["gift_tier"], GiftGivingSystem.QualityTier.MASTERWORK)
	assert_eq(result["effects"]["gift_subtype"], GiftGivingSystem.GiftCategory.TEA_IMPLEMENTS)
	assert_eq(result["effects"]["consume_item_id"], 7)
	assert_eq(result["skill_used"], "Etiquette")


func test_deliver_gift_picks_best_quality_from_inventory() -> void:
	var fine: Dictionary = InventorySystem.create_gift_item(
		1, "Fine Brush",
		GiftGivingSystem.GiftCategory.WRITING_IMPLEMENTS,
		GiftGivingSystem.QualityTier.FINE,
	)
	var masterwork: Dictionary = InventorySystem.create_gift_item(
		2, "Masterwork Inkstone",
		GiftGivingSystem.GiftCategory.WRITING_IMPLEMENTS,
		GiftGivingSystem.QualityTier.MASTERWORK,
	)
	_character.items = [fine, masterwork]
	var recipient: L5RCharacterData = _make_recipient(10, Enums.SchoolType.COURTIER)
	var characters_by_id: Dictionary = {10: recipient}

	var action := _make_action("DELIVER_GIFT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, characters_by_id,
	)
	assert_eq(result["effects"]["consume_item_id"], 2)


func test_deliver_gift_skips_forbidden_inventory_items() -> void:
	var sword: Dictionary = InventorySystem.create_gift_item(
		3, "Fine Katana",
		GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.QualityTier.FINE,
	)
	var fine_art: Dictionary = InventorySystem.create_gift_item(
		4, "Fine Painting",
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.QualityTier.FINE,
	)
	_character.items = [sword, fine_art]
	var recipient: L5RCharacterData = _make_recipient(10, Enums.SchoolType.COURTIER)
	var characters_by_id: Dictionary = {10: recipient}

	var action := _make_action("DELIVER_GIFT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, characters_by_id,
	)
	# The forbidden sword is skipped — best legal pick is the painting.
	assert_eq(result["effects"]["consume_item_id"], 4)


func test_deliver_gift_failure_is_marked_failed_so_effects_apply() -> void:
	# A weak giver gives a forbidden gift on purpose: the legendary-blade
	# exception does NOT apply at lower tiers, so the result is "forbidden".
	# Set up a sole sword in inventory so that path is forced.
	var sword: Dictionary = InventorySystem.create_gift_item(
		1, "Plain Katana",
		GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.QualityTier.FINE,
	)
	_character.items = [sword]
	var recipient: L5RCharacterData = _make_recipient(10, Enums.SchoolType.BUSHI)
	# Forbidden gift means select_best_gift returns {} — wiring falls through.
	var action := _make_action("DELIVER_GIFT", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, {10: recipient},
	)
	# No giftable item -> generic social path -> no gift_outcome key.
	assert_false(result["effects"].has("gift_outcome"))


# -- DECLARE_WAR Executor Tests --------------------------------------------------

func test_declare_war_justified_returns_war_effects() -> void:
	_character.clan = "Crab"
	_character.bushido_virtue = Enums.BushidoVirtue.YU
	var action := _make_action("DECLARE_WAR")
	action.metadata = {
		"standing_objective": "EXPAND_TERRITORY",
		"primary_objective": "",
		"intended_tier": WarJustification.MilitaryTier.RAID,
		"target_clan": "Crane",
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
	}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
	)
	assert_eq(result["effects"]["effect"], "war_declared")
	assert_true(result["effects"]["requires_war_creation"])
	assert_eq(result["effects"]["declaring_clan"], "Crab")
	assert_eq(result["effects"]["target_clan"], "Crane")


func test_declare_war_not_justified_returns_rejection() -> void:
	_character.clan = "Crab"
	_character.bushido_virtue = Enums.BushidoVirtue.JIN
	var action := _make_action("DECLARE_WAR")
	action.metadata = {
		"standing_objective": "MAINTAIN_PEACE",
		"primary_objective": "",
		"intended_tier": WarJustification.MilitaryTier.RAID,
		"target_clan": "Crane",
	}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
	)
	assert_eq(result["effects"]["effect"], "war_declaration_rejected")
	assert_true(result["effects"]["failed"])


func test_declare_war_total_war_honor_cost() -> void:
	_character.clan = "Crab"
	_character.bushido_virtue = Enums.BushidoVirtue.YU
	var action := _make_action("DECLARE_WAR")
	action.metadata = {
		"standing_objective": "EXPAND_TERRITORY",
		"primary_objective": "",
		"intended_tier": WarJustification.MilitaryTier.TOTAL_WAR,
		"target_clan": "Crane",
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
	}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
	)
	assert_eq(result["effects"]["effect"], "war_declared")
	assert_almost_eq(result["effects"]["honor_change"], -0.5, 0.01)


# -- Broadcast Social Actions (s12.2 Category 2) ------------------------------

func test_public_debate_success_gives_witness_disposition_gain() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {}
	witness.physical_location = "castle_court"
	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 30: witness}

	_dice_engine.set_seed(1)
	var action := _make_action("PUBLIC_DEBATE")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		assert_true(result["effects"].get("witness_disposition_gain", 0) >= 2)
		assert_true(result["effects"].get("witnesses", []).size() > 0)


func test_public_debate_witness_effects_applied() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {1: 5}
	witness.physical_location = "castle_court"
	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 30: witness}

	_dice_engine.set_seed(1)
	var action := _make_action("PUBLIC_DEBATE")
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		var applied: Dictionary = EffectApplicator.apply(
			result, chars, {}, []
		)
		assert_true(witness.disposition_values[1] > 5)


func test_public_debate_critical_failure_penalizes_with_witnesses() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 30
	witness.character_name = "Witness"
	witness.disposition_values = {1: 10}
	witness.physical_location = "castle_court"
	_character.physical_location = "castle_court"
	var chars: Dictionary = {1: _character, 30: witness}

	_dice_engine.set_seed(999)
	_ctx.dispositions[30] = -70
	var action := _make_action("PUBLIC_DEBATE", 30)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if not result["success"] and result.get("margin", 0) <= -10:
		assert_eq(result["effects"].get("witness_disposition_loss", 0), -2)


# -- ISSUE_DUEL_CHALLENGE Executor Tests ------------------------------------------

func test_duel_challenge_missing_target_returns_failed() -> void:
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 99)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, {}
	)
	assert_false(result["success"])
	assert_eq(result["effects"].get("reason"), "target_not_found")


func test_duel_challenge_returns_required_fields() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 3
	target.awareness = 3
	target.agility = 3
	target.intelligence = 3
	target.strength = 3
	target.perception = 3
	target.stamina = 2
	target.willpower = 2
	target.void_ring = 2
	target.skills = {"Iaijutsu": 3}
	_character.skills["Iaijutsu"] = 3
	var chars: Dictionary = {1: _character, 10: target}
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": false, "is_sanctioned": true}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_true(result.has("action_id"))
	assert_true(result.has("character_id"))
	assert_true(result.has("target_npc_id"))
	assert_true(result.has("ic_day"))
	assert_true(result.has("season"))
	assert_true(result.has("actor_won"))
	assert_true(result.has("effects"))
	assert_eq(result["action_id"], "ISSUE_DUEL_CHALLENGE")
	assert_eq(result["character_id"], 1)
	assert_eq(result["target_npc_id"], 10)


func test_duel_challenge_effects_include_duel_result() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 3
	target.awareness = 3
	target.agility = 3
	target.intelligence = 3
	target.strength = 3
	target.perception = 3
	target.stamina = 2
	target.willpower = 2
	target.void_ring = 2
	target.skills = {"Iaijutsu": 2}
	_character.skills["Iaijutsu"] = 2
	var chars: Dictionary = {1: _character, 10: target}
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": false, "is_sanctioned": true}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	var effects: Dictionary = result["effects"]
	assert_true(effects.has("duel_result"))
	assert_true(effects.has("winner_id"))
	assert_true(effects.has("loser_id"))
	assert_true(effects.has("death_occurred"))


func test_duel_challenge_at_court_winner_gets_glory_change() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 2
	target.awareness = 2
	target.agility = 2
	target.intelligence = 2
	target.strength = 2
	target.perception = 2
	target.stamina = 2
	target.willpower = 2
	target.void_ring = 2
	target.skills = {}
	# Give challenger a strong advantage for a deterministic win
	_character.reflexes = 5
	_character.awareness = 5
	_character.agility = 5
	_character.skills["Iaijutsu"] = 5
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var chars: Dictionary = {1: _character, 10: target}
	_dice_engine.set_seed(7)
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": false, "is_sanctioned": true}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	var effects: Dictionary = result["effects"]
	var winner: int = effects.get("winner_id", -1)
	if winner == 1:
		assert_eq(effects.get("glory_change", 0.0), 0.5)
	elif winner == 10:
		assert_eq(effects.get("winner_glory_change", 0.0), 0.5)
		assert_eq(effects.get("winner_glory_recipient_id", -1), 10)


func test_duel_challenge_not_at_court_no_glory_change() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 3
	target.awareness = 3
	target.agility = 3
	target.intelligence = 3
	target.strength = 3
	target.perception = 3
	target.stamina = 2
	target.willpower = 2
	target.void_ring = 2
	target.skills = {"Iaijutsu": 2}
	_character.skills["Iaijutsu"] = 2
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	var chars: Dictionary = {1: _character, 10: target}
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": false, "is_sanctioned": true}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	var effects: Dictionary = result["effects"]
	assert_false(effects.has("glory_change"))
	assert_false(effects.has("winner_glory_change"))


func test_duel_challenge_unsanctioned_death_creates_crime_record() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 1
	target.awareness = 1
	target.agility = 1
	target.intelligence = 1
	target.strength = 1
	target.perception = 1
	target.stamina = 1
	target.willpower = 1
	target.void_ring = 1
	target.skills = {}
	target.wounds_taken = 0
	# Give challenger overwhelming advantage for near-certain kill
	_character.reflexes = 5
	_character.agility = 5
	_character.awareness = 5
	_character.strength = 5
	_character.skills["Iaijutsu"] = 5
	var chars: Dictionary = {1: _character, 10: target}
	_dice_engine.set_seed(42)
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": true, "is_sanctioned": false}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	var effects: Dictionary = result["effects"]
	if effects.get("death_occurred", false):
		assert_true(effects.get("requires_crime_creation", false))
		assert_eq(effects.get("crime_type"), Enums.CrimeType.UNSANCTIONED_DUEL_DEATH)
		assert_ne(effects.get("crime_perpetrator_id", -1), -1)


func test_duel_challenge_sanctioned_death_no_crime_record() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.reflexes = 1
	target.awareness = 1
	target.agility = 1
	target.intelligence = 1
	target.strength = 1
	target.perception = 1
	target.stamina = 1
	target.willpower = 1
	target.void_ring = 1
	target.skills = {}
	target.wounds_taken = 0
	_character.reflexes = 5
	_character.agility = 5
	_character.awareness = 5
	_character.strength = 5
	_character.skills["Iaijutsu"] = 5
	var chars: Dictionary = {1: _character, 10: target}
	_dice_engine.set_seed(42)
	var action := _make_action("ISSUE_DUEL_CHALLENGE", 10)
	action.metadata = {"to_death": true, "is_sanctioned": true}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	var effects: Dictionary = result["effects"]
	if effects.get("death_occurred", false):
		assert_false(effects.get("requires_crime_creation", false))


# -- EXAMINE_CRIME_SCENE -------------------------------------------------------

func test_examine_crime_scene_calls_investigation_system() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 7
	cr.concealment_tn = 10
	cr.ic_day_committed = 5
	cr.evidence_total = 0
	cr.perpetrator_id = 99
	cr.known_suspects = [] as Array[int]
	var records: Array[CrimeRecord] = [cr]

	_character.skills["Investigation"] = 4
	_character.perception = 4
	_ctx.ic_day = 6

	var action := _make_action("EXAMINE_CRIME_SCENE")
	action.metadata = {"case_id": 7}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, {}, {}, 0, records
	)
	assert_eq(result["action_id"], "EXAMINE_CRIME_SCENE")
	var effects: Dictionary = result["effects"]
	assert_eq(effects["effect"], "scene_examined")
	assert_eq(effects["case_id"], 7)
	if result["success"]:
		assert_true(effects["evidence_gained"] > 0)
		assert_true(cr.evidence_total > 0)


func test_examine_crime_scene_no_record_fails() -> void:
	var records: Array[CrimeRecord] = []
	var action := _make_action("EXAMINE_CRIME_SCENE")
	action.metadata = {"case_id": 99}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, {}, {}, 0, records
	)
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "no_crime_record")


func test_examine_crime_scene_too_old_fails() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 8
	cr.concealment_tn = 10
	cr.ic_day_committed = 0
	cr.evidence_total = 0
	cr.perpetrator_id = 99
	cr.known_suspects = [] as Array[int]
	var records: Array[CrimeRecord] = [cr]

	_ctx.ic_day = 200

	var action := _make_action("EXAMINE_CRIME_SCENE")
	action.metadata = {"case_id": 8}
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map,
		{}, {}, {}, 0, records
	)
	assert_false(result["success"])
	assert_eq(result["effects"]["evidence_gained"], 0)


# -- PROBE Quality for Witness Evidence ----------------------------------------

func test_probe_success_includes_quality() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 10
	target.character_name = "Target"
	target.skills = {"Sincerity": 1}
	target.emphases = {}
	target.awareness = 2
	target.wounds_taken = 0
	var chars: Dictionary = {1: _character, 10: target}

	_character.skills["Courtier"] = 5
	_character.perception = 4
	_dice_engine.set_seed(7)

	var action := _make_action("PROBE", 10)
	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	if result["success"]:
		assert_true(result["effects"].has("quality"))
		assert_true(result["effects"]["quality"] >= 1)


# -- Bribe Attempt Resolution --------------------------------------------------

func test_bribe_attempt_resolves_with_target():
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Magistrate Kitsuki"
	magistrate.skills = {"Etiquette": 4}
	magistrate.emphases = {}
	magistrate.willpower = 4
	magistrate.honor = 7.0
	magistrate.wounds_taken = 0
	var chars: Dictionary = {1: _character, 20: magistrate}

	_character.skills["Temptation"] = 3
	_character.awareness = 3
	_dice_engine.set_seed(42)

	var action := _make_action("BRIBE_FOR_INFO", 20)
	action.metadata = {"suppress_case": true, "magistrate_id": 20}

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "BRIBE_FOR_INFO")
	assert_true(result.has("success"))
	assert_true(result["effects"].has("suppress_case"))
	assert_eq(result["effects"]["magistrate_id"], 20)


func test_bribe_attempt_high_honor_magistrate_resists():
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Honest Magistrate"
	magistrate.skills = {"Etiquette": 5}
	magistrate.emphases = {}
	magistrate.willpower = 5
	magistrate.honor = 9.0
	magistrate.wounds_taken = 0
	var chars: Dictionary = {1: _character, 20: magistrate}

	_character.skills["Temptation"] = 1
	_character.awareness = 2
	_dice_engine.set_seed(1)

	var action := _make_action("BRIBE_FOR_INFO", 20)
	action.metadata = {"suppress_case": true}

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "BRIBE_FOR_INFO")
	assert_false(result["success"])
	assert_true(result["effects"].get("detection_risk", false))


# -- FLEE_JURISDICTION ---------------------------------------------------------

func test_flee_jurisdiction_returns_success() -> void:
	var action := _make_action("FLEE_JURISDICTION", -1)
	action.metadata = {"flee_from_magistrate_id": 20}

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map
	)
	assert_eq(result["action_id"], "FLEE_JURISDICTION")
	assert_true(result["success"])
	assert_eq(result["effects"]["effect"], "flee_jurisdiction")
	assert_eq(result["effects"]["fugitive_id"], _character.character_id)


# -- EXTORT_ACCUSED ------------------------------------------------------------

func test_extort_accused_with_target() -> void:
	var suspect := L5RCharacterData.new()
	suspect.character_id = 50
	suspect.character_name = "Suspect"
	suspect.skills["Etiquette"] = 2
	suspect.willpower = 2
	suspect.honor = 1.0

	_character.skills["Intimidation"] = 5
	_character.willpower = 4
	_dice_engine.set_seed(99)

	var chars: Dictionary = {_character.character_id: _character, 50: suspect}
	var action := _make_action("EXTORT_ACCUSED", 50)
	action.metadata = {"extort_suspect_id": 50}

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "EXTORT_ACCUSED")
	assert_eq(result["effects"]["suspect_id"], 50)
	assert_eq(result["effects"]["magistrate_id"], _character.character_id)


func test_extort_accused_no_target_fails() -> void:
	var action := _make_action("EXTORT_ACCUSED", 999)
	action.metadata = {"extort_suspect_id": 999}

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, {}
	)
	assert_eq(result["action_id"], "EXTORT_ACCUSED")
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "no_target")


# -- BRIBE_WITNESS -------------------------------------------------------------

func test_bribe_witness_resolves() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 60
	witness.character_name = "Witness"
	witness.skills["Etiquette"] = 2
	witness.willpower = 2
	witness.honor = 2.0
	witness.wounds_taken = 0

	_character.skills["Temptation"] = 4
	_character.awareness = 4
	_dice_engine.set_seed(42)

	var chars: Dictionary = {_character.character_id: _character, 60: witness}
	var action := _make_action("BRIBE_WITNESS", 60)

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "BRIBE_WITNESS")
	assert_eq(result["effects"]["witness_id"], 60)
	assert_true(result["effects"].has("evidence_on_fail"))


# -- INTIMIDATE_WITNESS --------------------------------------------------------

func test_intimidate_witness_resolves() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 61
	witness.character_name = "Witness"
	witness.skills["Etiquette"] = 2
	witness.willpower = 2
	witness.honor = 2.0
	witness.wounds_taken = 0

	_character.skills["Intimidation"] = 4
	_character.willpower = 4
	_dice_engine.set_seed(42)

	var chars: Dictionary = {_character.character_id: _character, 61: witness}
	var action := _make_action("INTIMIDATE_WITNESS", 61)

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "INTIMIDATE_WITNESS")
	assert_eq(result["effects"]["witness_id"], 61)
	assert_true(result["effects"].get("detection_risk", false))


func test_kill_witness_resolves() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 62
	witness.character_name = "Victim"
	witness.skills["Investigation"] = 3
	witness.perception = 3
	witness.wounds_taken = 0

	_character.skills["Stealth"] = 4
	_character.agility = 4
	_dice_engine.set_seed(99)

	var chars: Dictionary = {_character.character_id: _character, 62: witness}
	var action := _make_action("KILL_WITNESS", 62)

	var result: Dictionary = ActionExecutor.execute(
		action, _character, _ctx, _dice_engine, _action_skill_map, {}, chars
	)
	assert_eq(result["action_id"], "KILL_WITNESS")
	assert_eq(result["effects"]["witness_id"], 62)
	assert_true(result["effects"].has("concealment_tn"))
	assert_typeof(result["effects"]["concealment_tn"], TYPE_INT)
