extends SceneTree
## Runtime driver for the s29.15.4 Doji Courtier R3 "The Perfect Gift" technique.
## SkillResolver.execute_perfect_gift (Courtier TN 20 -> a one-shot Devotion-equivalent
## disposition modifier: +20 base / +35 at +1 Raise / +50 at +2 Raises, non-stacking per
## pair) had ZERO production callers, and its data field perfect_gift_targets was dead
## (touched only inside the dormant func). The intended trigger -- an accepted DELIVER_GIFT
## -- is a fully live path (_try_execute_deliver_gift -> GiftGivingSystem.resolve_deliver_gift),
## so a Doji Courtier R3+ delivering a gift never received the technique. This driver exercises
## the wire: on a successful gift, _try_execute_deliver_gift now fires execute_perfect_gift and
## surfaces perfect_gift_applied / perfect_gift_disposition. All values are the arbiter's own
## LOCKED s29.15.4 constants (TN 20, +20/+35/+50) -- no invention.
## Run: godot --headless -s tests/verify_perfect_gift.gd

const _AE := preload("res://simulation/action_executor.gd")
const _SR := preload("res://simulation/skill_resolver.gd")
const _GGS := preload("res://simulation/gift_giving_system.gd")
const _INV := preload("res://simulation/inventory_system.gd")
const _DICE := preload("res://simulation/dice_engine.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A strong Doji Courtier at insight rank 3+ (all rings high -> insight >= 200 -> rank >= 4).
func _mk_doji(id: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school = "Doji Courtier"
	c.school_type = Enums.SchoolType.COURTIER
	c.clan = "Crane"
	c.awareness = 5
	c.reflexes = 5
	c.agility = 5
	c.intelligence = 5
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.perception = 5
	c.void_ring = 4
	c.skills = {"Courtier": 6}
	c.wounds_taken = 0
	return c


func _mk_recipient(id: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school_type = Enums.SchoolType.COURTIER
	c.clan = "Lion"
	c.wounds_taken = 0
	return c


func _init() -> void:
	print("--- s29.15.4 Doji R3 Perfect Gift ---")
	_test_gates()
	_test_success_and_nonstack()
	_test_executor_integration()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_gates() -> void:
	print("[1] arbiter gates: wrong school / rank<3 / already-applied return no-op (no roll)")
	var dice: DiceEngine = _DICE.new(1)
	# Wrong school.
	var bayushi: L5RCharacterData = _mk_doji(10)
	bayushi.school = "Bayushi Courtier"
	var tgt1: L5RCharacterData = _mk_recipient(11)
	var r1: Dictionary = _SR.execute_perfect_gift(bayushi, tgt1, dice)
	_ok(r1.get("success", true) == false and r1.get("reason", "") == "wrong_school", "non-Doji -> wrong_school")
	_ok(not tgt1.disposition_values.has(10), "wrong school applied no disposition")
	# Rank too low: a rank-1 Doji (all traits 2 -> insight ~100 -> rank 1).
	var junior: L5RCharacterData = _CHAR.new()
	junior.character_id = 12
	junior.school = "Doji Courtier"
	junior.skills = {"Courtier": 1}
	junior.wounds_taken = 0
	var tgt2: L5RCharacterData = _mk_recipient(13)
	var r2: Dictionary = _SR.execute_perfect_gift(junior, tgt2, dice)
	_ok(r2.get("success", true) == false and r2.get("reason", "") == "rank_too_low", "rank<3 -> rank_too_low")
	# Already-applied: seed the target into perfect_gift_targets.
	var doji: L5RCharacterData = _mk_doji(14)
	doji.perfect_gift_targets = [15]
	var tgt3: L5RCharacterData = _mk_recipient(15)
	var r3: Dictionary = _SR.execute_perfect_gift(doji, tgt3, dice)
	_ok(r3.get("success", true) == false and r3.get("reason", "") == "already_applied", "repeat target -> already_applied")
	_ok(not tgt3.disposition_values.has(14), "already-applied target unchanged")


func _test_success_and_nonstack() -> void:
	print("[2] success: LOCKED +20/+35/+50 disposition (Pattern B), then non-stacking")
	var dice: DiceEngine = _DICE.new(777)
	var doji: L5RCharacterData = _mk_doji(20)
	var tgt: L5RCharacterData = _mk_recipient(21)
	var r: Dictionary = _SR.execute_perfect_gift(doji, tgt, dice)
	_ok(r.get("success", false) == true, "strong Doji clears Courtier TN 20")
	var applied: int = int(r.get("disposition_applied", 0))
	_ok(applied in [20, 35, 50], "disposition_applied is a LOCKED tier value (+20/+35/+50): %d" % applied)
	_ok(tgt.disposition_values.get(20, 0) == applied, "Pattern-B: recipient disposition toward Doji raised by that amount")
	_ok(21 in doji.perfect_gift_targets, "target recorded in perfect_gift_targets (non-stacking guard)")
	# Non-stacking: a second attempt on the same target no-ops.
	var before: int = tgt.disposition_values.get(20, 0)
	var r2: Dictionary = _SR.execute_perfect_gift(doji, tgt, dice)
	_ok(r2.get("success", true) == false and r2.get("reason", "") == "already_applied", "second attempt -> already_applied")
	_ok(tgt.disposition_values.get(20, 0) == before, "no further disposition on the repeat")


func _test_executor_integration() -> void:
	print("[3] _try_execute_deliver_gift fires Perfect Gift on a successful Doji gift")
	var dice: DiceEngine = _DICE.new(777)
	var doji: L5RCharacterData = _mk_doji(30)
	doji.items = [{
		"category": _INV.ItemCategory.GIFT,
		"gift_subtype": _GGS.GiftCategory.TEA_IMPLEMENTS,  # APPROPRIATE for a courtier, not forbidden
		"quality_tier": _GGS.QualityTier.NORMAL,
		"item_id": 1,
		"history_point_bonus": 0,
		"item_type": "gift",
	}]
	var recipient: L5RCharacterData = _mk_recipient(31)
	var chars: Dictionary = {30: doji, 31: recipient}
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "DELIVER_GIFT"
	action.target_npc_id = 31
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 30
	ctx.ic_day = 100
	var res: Dictionary = _AE._try_execute_deliver_gift(action, doji, ctx, dice, chars)
	var eff: Dictionary = res.get("effects", {})
	_ok(res.get("success", false) == true, "gift accepted (success)")
	_ok(bool(eff.get("perfect_gift_applied", false)) == true, "Perfect Gift fired on the accepted gift")
	_ok(int(eff.get("perfect_gift_disposition", 0)) in [20, 35, 50], "surfaced a LOCKED disposition tier")
	_ok(recipient.disposition_values.get(30, 0) >= 20, "recipient disposition toward the Doji raised (Pattern B)")
	# Control: a non-Doji giver fires no Perfect Gift.
	var dice2: DiceEngine = _DICE.new(777)
	var bayushi: L5RCharacterData = _mk_doji(40)
	bayushi.school = "Bayushi Courtier"
	bayushi.items = doji.items.duplicate(true)
	var recip2: L5RCharacterData = _mk_recipient(41)
	var chars2: Dictionary = {40: bayushi, 41: recip2}
	var action2 := NPCDataStructures.ScoredAction.new()
	action2.action_id = "DELIVER_GIFT"
	action2.target_npc_id = 41
	var ctx2 := NPCDataStructures.ContextSnapshot.new()
	ctx2.character_id = 40
	ctx2.ic_day = 100
	var res2: Dictionary = _AE._try_execute_deliver_gift(action2, bayushi, ctx2, dice2, chars2)
	var eff2: Dictionary = res2.get("effects", {})
	_ok(bool(eff2.get("perfect_gift_applied", true)) == false, "non-Doji giver: no Perfect Gift")
