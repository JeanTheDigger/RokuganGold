extends SceneTree
## Live-world confirmation for s57.21 military unification Stage 1.
## Runs the REAL WorldBootstrap.bootstrap_world and asserts on the production roster that:
##   [1] company ids and unit ids (army/section/legion) are DISJOINT (no commanded_unit_id namespace collision);
##   [2] NO officer of rank >= TAISA carries a company_id as commanded_unit_id (the clobber is gone),
##       and every Taisa/Shireikan positively resolves to a real legion/section id;
##   [3] the Company->Legion chain is closed -- legions carry constituent companies, and each linked
##       company's parent_legion_id matches a legion its Chui's Taisa actually commands.
## Run: godot --headless -s tests/verify_military_unification_live.gd

const _WB := preload("res://simulation/world_bootstrap.gd")
const _DICE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- s57.21 military unification Stage 1 (LIVE bootstrapped world) ---")
	var dice: DiceEngine = _DICE.new(424242)
	var ws: Dictionary = _WB.bootstrap_world(dice)

	var characters: Array = ws.get("characters", [])
	var companies: Array = ws.get("military_data", {}).get("companies", [])
	var legions: Array = ws.get("military_legions", [])
	var sections: Array = ws.get("military_sections", [])
	var armies: Array = ws.get("military_armies", [])
	print("  roster: %d chars | %d companies | %d legions | %d sections | %d armies"
		% [characters.size(), companies.size(), legions.size(), sections.size(), armies.size()])

	var company_ids: Dictionary = {}          # company_id -> company dict
	for co: Dictionary in companies:
		company_ids[int(co["company_id"])] = co
	var legion_ids: Dictionary = {}
	for lg: Dictionary in legions:
		legion_ids[int(lg["legion_id"])] = lg
	var section_ids: Dictionary = {}
	for sc: Dictionary in sections:
		section_ids[int(sc["section_id"])] = true
	var army_ids: Dictionary = {}
	for ar: Dictionary in armies:
		army_ids[int(ar["army_id"])] = true
	var chars_by_id: Dictionary = {}
	for c: L5RCharacterData in characters:
		chars_by_id[c.character_id] = c

	print("[1] company ids DISJOINT from all unit ids")
	var collisions: int = 0
	for cid: int in company_ids:
		if legion_ids.has(cid) or section_ids.has(cid) or army_ids.has(cid):
			collisions += 1
	_ok(collisions == 0, "0 company/unit id collisions (got %d)" % collisions)
	_ok(companies.size() > 0 and legions.size() > 0, "non-empty companies + legions")

	print("[2] rank >= TAISA officers NOT clobbered; commanded_unit_id is a same-tier unit id or unset")
	# The clobber (commanded_unit_id = company_id) is the bug Stage 1 removes. A Taisa/Shireikan whose
	# commanded_unit_id is not a pop-B legion/section is legitimate ONLY if unset (-1) -- e.g. the s2.4
	# Wall command roster (12 Tower-Commander Taisa + 2 Wall-Commander Shireikan) that commands Wall
	# Towers via a separate structure, not a pop-B legion. The invariant: never a company id; either a
	# real same-tier unit id or -1, never "other".
	var clobbered: int = 0
	var taisa_legion: int = 0
	var taisa_unset: int = 0
	var taisa_other: int = 0
	var shi_section: int = 0
	var shi_unset: int = 0
	var shi_other: int = 0
	for c: L5RCharacterData in characters:
		if c.military_rank >= Enums.MilitaryRank.TAISA:
			if company_ids.has(c.commanded_unit_id):
				clobbered += 1
			if c.military_rank == Enums.MilitaryRank.TAISA:
				if legion_ids.has(c.commanded_unit_id):
					taisa_legion += 1
				elif c.commanded_unit_id == -1:
					taisa_unset += 1
				else:
					taisa_other += 1
			elif c.military_rank == Enums.MilitaryRank.SHIREIKAN:
				if section_ids.has(c.commanded_unit_id):
					shi_section += 1
				elif c.commanded_unit_id == -1:
					shi_unset += 1
				else:
					shi_other += 1
	print("  Taisa: %d command a legion, %d unset (Wall roster), %d other"
		% [taisa_legion, taisa_unset, taisa_other])
	print("  Shireikan: %d command a section, %d unset (Wall roster), %d other"
		% [shi_section, shi_unset, shi_other])
	_ok(clobbered == 0, "no rank>=TAISA officer commands a company (clobbered=%d)" % clobbered)
	_ok(taisa_other == 0, "no Taisa has a non-legion, non-unset commanded_unit_id (other=%d)" % taisa_other)
	_ok(shi_other == 0, "no Shireikan has a non-section, non-unset commanded_unit_id (other=%d)" % shi_other)
	# Every pop-B legion/section is commanded (one Taisa/Shireikan per unit); the surplus is the Wall roster.
	_ok(taisa_legion == legions.size(),
		"every pop-B legion has its Taisa commander (%d == %d)" % [taisa_legion, legions.size()])
	_ok(shi_section == sections.size(),
		"every pop-B section has its Shireikan commander (%d == %d)" % [shi_section, sections.size()])

	print("[3] Company->Legion chain closed")
	var legions_with_companies: int = 0
	var total_constituents: int = 0
	var bad_backref: int = 0
	for lg: Dictionary in legions:
		var cc: Array = lg.get("constituent_companies", [])
		if not cc.is_empty():
			legions_with_companies += 1
		for ccid_v: Variant in cc:
			total_constituents += 1
			var co: Dictionary = company_ids.get(int(ccid_v), {})
			# constituent must be a real company whose parent_legion_id points back to this legion.
			if co.is_empty() or int(co.get("parent_legion_id", -1)) != int(lg["legion_id"]):
				bad_backref += 1
	_ok(legions_with_companies > 0, "at least one legion carries constituent companies (%d)" % legions_with_companies)
	_ok(total_constituents > 0, "legions carry %d linked companies total" % total_constituents)
	_ok(bad_backref == 0, "every constituent company back-references its legion (bad=%d)" % bad_backref)

	# Positive chain: for every LINKED company, its commander's operational superior is a Taisa
	# whose commanded_unit_id equals the company's parent_legion_id (the s57.21.3 mirror).
	var linked: int = 0
	var chain_bad: int = 0
	for co: Dictionary in companies:
		var plid: int = int(co.get("parent_legion_id", -1))
		if plid < 0:
			continue
		linked += 1
		var cmd: L5RCharacterData = chars_by_id.get(int(co["commander_id"]), null)
		if cmd == null:
			chain_bad += 1
			continue
		var sup: L5RCharacterData = chars_by_id.get(cmd.operational_superior_id, null)
		if sup == null or sup.military_rank != Enums.MilitaryRank.TAISA or sup.commanded_unit_id != plid:
			chain_bad += 1
	print("  linked companies: %d | unlinked (garrison/wall/other): %d" % [linked, companies.size() - linked])
	_ok(linked > 0, "at least one company linked to a legion")
	_ok(chain_bad == 0, "every linked company's Chui->Taisa->legion mirror holds (bad=%d)" % chain_bad)

	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
