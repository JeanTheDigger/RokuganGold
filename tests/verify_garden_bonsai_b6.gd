extends SceneTree
## Runtime driver for s57.23a B6 / s57.24.9 — the bonsai-in-zone garden integration boost.
## GardenSystem.get_garden_effective_tier (garden effective visitor tier = current_tier + 1,
## capped at Legendary 5, when an active bonsai is displayed in the same zone; presence-based,
## bonsai quality irrelevant) was BUILT but had ZERO production callers — the live garden-visit
## pass read the raw garden.current_tier, so a co-displayed bonsai never boosted the garden's
## visitor disposition bonus. Now GardenSystem.apply_visitor takes an effective_tier override and
## _process_garden_visitor_effects computes it from the settlements hosting an active bonsai.
## Run: godot --headless -s tests/verify_garden_bonsai_b6.gd

const _GS := preload("res://simulation/garden_system.gd")
const _GD := preload("res://shared/garden_data.gd")
const _BD := preload("res://shared/bonsai_data.gd")
const _CH := preload("res://shared/character_data.gd")
const _SET := preload("res://shared/settlement_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _garden(gid: int, sid: int, creator: int, tier: int, ic_day: int) -> GardenData:
	var g: GardenData = _GD.new()
	g.garden_id = gid
	g.settlement_id = sid
	g.creator_id = creator
	g.current_tier = tier
	g.installation_date = ic_day  # < 1 IC year old -> familiarity factor 1.0
	g.destroyed = false
	return g


func _bonsai(bid: int, display_sid: int, dead: bool) -> BonsaiData:
	var b: BonsaiData = _BD.new()
	b.bonsai_id = bid
	b.display_settlement_id = display_sid
	b.is_dead = dead
	return b


func _visitor(cid: int, loc: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.physical_location = loc
	return c


func _settlement(sid: int, lord: int) -> SettlementData:
	var s: SettlementData = _SET.new()
	s.settlement_id = sid
	s.lord_character_id = lord
	return s


func _init() -> void:
	print("--- s57.23a B6 garden integration boost (bonsai in zone) ---")
	_test_effective_tier_arbiter()
	_test_apply_visitor_override()
	_test_end_to_end_boost()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_effective_tier_arbiter() -> void:
	print("[1] get_garden_effective_tier: +1 when bonsai present, capped at Legendary 5")
	var g2: GardenData = _garden(1, 100, 50, 2, 0)
	_ok(_GS.get_garden_effective_tier(g2, -1) == 2, "no bonsai -> raw tier 2")
	_ok(_GS.get_garden_effective_tier(g2, 1) == 3, "bonsai present -> tier 3 (+1)")
	var g5: GardenData = _garden(2, 100, 50, 5, 0)
	_ok(_GS.get_garden_effective_tier(g5, 1) == 5, "Legendary garden + bonsai -> capped at 5")


func _test_apply_visitor_override() -> void:
	print("[2] apply_visitor honors the effective_tier override (bonus == tier), backward-compatible")
	var g: GardenData = _garden(1, 100, 50, 2, 0)
	# No override -> raw tier 2 -> bonus 2.
	var r_raw: Dictionary = _GS.apply_visitor(g, 60, 50, 0)
	_ok(int(r_raw.get("bonus", 0)) == 2, "no override -> bonus 2 (raw tier)")
	# Override with effective tier 3 (B6 boost) -> bonus 3.
	var g2: GardenData = _garden(1, 100, 50, 2, 0)
	var r_boost: Dictionary = _GS.apply_visitor(g2, 60, 50, 0, 3)
	_ok(int(r_boost.get("bonus", 0)) == 3, "effective_tier 3 -> bonus 3 (B6 boost)")
	# Creator is still excluded regardless of override.
	var g3: GardenData = _garden(1, 100, 50, 2, 0)
	var r_creator: Dictionary = _GS.apply_visitor(g3, 50, 50, 0, 3)
	_ok(int(r_creator.get("bonus", 0)) == 0, "creator visit still excluded")


func _test_end_to_end_boost() -> void:
	print("[3] end-to-end: a co-displayed bonsai raises the garden visitor bonus +2 -> +3")
	var loc := "100"
	var setts: Array = [_settlement(100, 50)]

	# (a) Garden alone at settlement 100, tier 2 -> visitor gets +2.
	var g_alone: GardenData = _garden(1, 100, 50, 2, 0)
	var v1: L5RCharacterData = _visitor(60, loc)
	DayOrchestrator._process_garden_visitor_effects(
		[g_alone], [v1], {60: v1}, setts, 0, [])
	var mods1: Array = v1.temporary_modifiers.get(50, [])
	_ok(mods1.size() == 1 and int(mods1[0].get("value", 0)) == 2,
		"garden alone -> visitor gains +2 toward creator")

	# (b) Same garden + an active bonsai displayed at settlement 100 -> visitor gets +3.
	var g_boost: GardenData = _garden(1, 100, 50, 2, 0)
	var v2: L5RCharacterData = _visitor(61, loc)
	var bonsai := [_bonsai(9, 100, false)]
	DayOrchestrator._process_garden_visitor_effects(
		[g_boost], [v2], {61: v2}, setts, 0, bonsai)
	var mods2: Array = v2.temporary_modifiers.get(50, [])
	_ok(mods2.size() == 1 and int(mods2[0].get("value", 0)) == 3,
		"garden + co-displayed bonsai -> visitor gains +3 (B6 boost)")

	# (c) A bonsai displayed at a DIFFERENT settlement does NOT boost this garden.
	var g_far: GardenData = _garden(1, 100, 50, 2, 0)
	var v3: L5RCharacterData = _visitor(62, loc)
	var bonsai_far := [_bonsai(9, 200, false)]
	DayOrchestrator._process_garden_visitor_effects(
		[g_far], [v3], {62: v3}, setts, 0, bonsai_far)
	var mods3: Array = v3.temporary_modifiers.get(50, [])
	_ok(mods3.size() == 1 and int(mods3[0].get("value", 0)) == 2,
		"bonsai at a different settlement -> no boost (+2)")

	# (d) A DEAD bonsai at settlement 100 does NOT boost.
	var g_dead: GardenData = _garden(1, 100, 50, 2, 0)
	var v4: L5RCharacterData = _visitor(63, loc)
	var bonsai_dead := [_bonsai(9, 100, true)]
	DayOrchestrator._process_garden_visitor_effects(
		[g_dead], [v4], {63: v4}, setts, 0, bonsai_dead)
	var mods4: Array = v4.temporary_modifiers.get(50, [])
	_ok(mods4.size() == 1 and int(mods4[0].get("value", 0)) == 2,
		"dead bonsai -> no boost (+2)")
