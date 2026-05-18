class_name BiologicalFamily
## Biological family web traversal per GDD s22.6.
##
## Pure simulation class — no Node inheritance, no scene tree. Operates on
## L5RCharacterData and a `chars_by_id: Dictionary` lookup. Disposition bond
## values are pulled from the existing DispositionSystem.FAMILY_BONDS table
## (s12.2) — this class is the relationship classifier, not a value source.


# -- Relationship enum --------------------------------------------------------

enum Relationship {
	NONE,
	SELF,
	SIBLING,
	PARENT,
	CHILD,
	GRANDPARENT,
	GRANDCHILD,
	FIRST_COUSIN,
	# Distant biological/marriage tie that crosses clan lines. Examples:
	# spouse's blood relatives in another clan, a sibling's child via a
	# cross-clan marriage. Carries a small permanent bond per s22.6.
	CROSS_CLAN_MARRIAGE_RELATIVE,
}


# -- Public API ---------------------------------------------------------------

static func get_relationship(
	a: L5RCharacterData,
	b: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Relationship:
	if a == null or b == null:
		return Relationship.NONE
	if a.character_id == b.character_id:
		return Relationship.SELF

	var blood: Relationship = _get_blood_relationship(a, b, chars_by_id)
	if blood != Relationship.NONE:
		return blood

	if _is_cross_clan_marriage_relative(a, b, chars_by_id):
		return Relationship.CROSS_CLAN_MARRIAGE_RELATIVE

	return Relationship.NONE


static func get_family_modifier(rel: Relationship) -> int:
	match rel:
		Relationship.SIBLING:
			return DispositionSystem.FAMILY_BONDS.get("sibling", 0)
		Relationship.PARENT, Relationship.CHILD:
			return DispositionSystem.FAMILY_BONDS.get("parent_child", 0)
		Relationship.GRANDPARENT, Relationship.GRANDCHILD:
			return DispositionSystem.FAMILY_BONDS.get("grandparent_grandchild", 0)
		Relationship.FIRST_COUSIN:
			return DispositionSystem.FAMILY_BONDS.get("first_cousin", 0)
		Relationship.CROSS_CLAN_MARRIAGE_RELATIVE:
			return DispositionSystem.FAMILY_BONDS.get("cross_clan_marriage", 0)
	return 0


static func compute_pairwise_modifier(
	a: L5RCharacterData,
	b: L5RCharacterData,
	chars_by_id: Dictionary,
) -> int:
	var rel: Relationship = get_relationship(a, b, chars_by_id)
	return get_family_modifier(rel)


# Computes all family bond modifiers for `actor` against every blood relative
# (close blood relations + cross-clan-marriage relatives) reachable from
# chars_by_id. Returns { other_id: int -> bond_value: int }.
#
# Limited to the close-relation set (siblings, parents, children, grandparents,
# grandchildren, first cousins) plus actor's spouse's blood relatives in
# differing clans. Bonds are pulled from DispositionSystem.FAMILY_BONDS.
static func compute_all_family_bonds(
	actor: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Dictionary:
	var bonds: Dictionary = {}
	if actor == null:
		return bonds

	# Close blood relations — direct id lookups, fast.
	for sib_id: int in get_sibling_ids(actor):
		_record_bond(bonds, sib_id, Relationship.SIBLING)
	for parent_id: int in get_parent_ids(actor):
		_record_bond(bonds, parent_id, Relationship.PARENT)
	for child_id: int in get_child_ids(actor):
		_record_bond(bonds, child_id, Relationship.CHILD)

	# Half-siblings via shared parent — scan chars_by_id for other entries
	# claiming the same mother/father.
	if actor.mother_id != -1 or actor.father_id != -1:
		for other_id: int in chars_by_id:
			if other_id == actor.character_id:
				continue
			if bonds.has(other_id):
				continue
			var other: L5RCharacterData = chars_by_id.get(other_id)
			if other == null:
				continue
			if _are_siblings(actor, other):
				_record_bond(bonds, other_id, Relationship.SIBLING)

	# Two-hop relations.
	for gp_id: int in get_grandparent_ids(actor, chars_by_id):
		if not bonds.has(gp_id):
			_record_bond(bonds, gp_id, Relationship.GRANDPARENT)
	for gc_id: int in get_grandchild_ids(actor, chars_by_id):
		if not bonds.has(gc_id):
			_record_bond(bonds, gc_id, Relationship.GRANDCHILD)
	for cousin_id: int in get_first_cousin_ids(actor, chars_by_id):
		if not bonds.has(cousin_id):
			_record_bond(bonds, cousin_id, Relationship.FIRST_COUSIN)

	# Cross-clan-marriage relatives via spouse's blood ties.
	if actor.spouse_id != -1:
		var spouse: L5RCharacterData = chars_by_id.get(actor.spouse_id)
		if spouse != null and spouse.clan != actor.clan:
			for other_id: int in chars_by_id:
				if other_id == actor.character_id:
					continue
				if bonds.has(other_id):
					continue
				var other: L5RCharacterData = chars_by_id.get(other_id)
				if other == null:
					continue
				if other.clan == actor.clan:
					continue
				var rel: Relationship = _get_blood_relationship(spouse, other, chars_by_id)
				if rel != Relationship.NONE:
					_record_bond(bonds, other_id, Relationship.CROSS_CLAN_MARRIAGE_RELATIVE)

	return bonds


static func _record_bond(
	bonds: Dictionary,
	other_id: int,
	rel: Relationship,
) -> void:
	if other_id < 0:
		return
	bonds[other_id] = get_family_modifier(rel)


# -- Direct relation lookups (no traversal beyond the character itself) ------

static func get_parent_ids(character: L5RCharacterData) -> Array[int]:
	var out: Array[int] = []
	if character == null:
		return out
	if character.mother_id != -1:
		out.append(character.mother_id)
	if character.father_id != -1:
		out.append(character.father_id)
	return out


static func get_sibling_ids(character: L5RCharacterData) -> Array[int]:
	if character == null:
		return ([] as Array[int])
	return character.sibling_ids.duplicate()


static func get_child_ids(character: L5RCharacterData) -> Array[int]:
	if character == null:
		return ([] as Array[int])
	return character.children_ids.duplicate()


# -- Two-hop traversals -------------------------------------------------------

static func get_grandparent_ids(
	character: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Array[int]:
	var out: Array[int] = []
	for parent_id: int in get_parent_ids(character):
		var parent: L5RCharacterData = chars_by_id.get(parent_id)
		if parent == null:
			continue
		for gp_id: int in get_parent_ids(parent):
			if not out.has(gp_id):
				out.append(gp_id)
	return out


static func get_grandchild_ids(
	character: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Array[int]:
	var out: Array[int] = []
	for child_id: int in get_child_ids(character):
		var child: L5RCharacterData = chars_by_id.get(child_id)
		if child == null:
			continue
		for gc_id: int in get_child_ids(child):
			if not out.has(gc_id):
				out.append(gc_id)
	return out


static func get_aunt_uncle_ids(
	character: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Array[int]:
	## Aunts and uncles = parents' siblings, including half-siblings detected
	## via shared grandparent.
	var out: Array[int] = []
	for parent_id: int in get_parent_ids(character):
		var parent: L5RCharacterData = chars_by_id.get(parent_id)
		if parent == null:
			continue
		for sib_id: int in get_sibling_ids(parent):
			if sib_id != parent_id and not out.has(sib_id):
				out.append(sib_id)
		# Half-aunts/uncles: parent's grandparents' other children.
		for gp_id: int in get_parent_ids(parent):
			var gp: L5RCharacterData = chars_by_id.get(gp_id)
			if gp == null:
				continue
			for cid: int in gp.children_ids:
				if cid != parent_id and not out.has(cid):
					out.append(cid)
	return out


static func get_first_cousin_ids(
	character: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Array[int]:
	var out: Array[int] = []
	for au_id: int in get_aunt_uncle_ids(character, chars_by_id):
		var au: L5RCharacterData = chars_by_id.get(au_id)
		if au == null:
			continue
		for cid: int in au.children_ids:
			if cid != character.character_id and not out.has(cid):
				out.append(cid)
	return out


# -- Cross-clan marriage relative detection ----------------------------------

static func _is_cross_clan_marriage_relative(
	a: L5RCharacterData,
	b: L5RCharacterData,
	chars_by_id: Dictionary,
) -> bool:
	## Detection scope (intentionally narrow to avoid runaway traversal):
	## - b is a blood relative of a's spouse, AND b's clan differs from a's clan.
	## - a's spouse's clan differs from a's clan (so the marriage actually
	##   crossed clan lines).
	if a.spouse_id == -1:
		return false
	var spouse: L5RCharacterData = chars_by_id.get(a.spouse_id)
	if spouse == null:
		return false
	if spouse.clan == a.clan:
		# Marriage was intra-clan; no cross-clan relatives generated.
		return false
	if b.clan == a.clan:
		# b is in a's own clan — not a cross-clan tie.
		return false
	var spouse_rel: Relationship = _get_blood_relationship(spouse, b, chars_by_id)
	return spouse_rel != Relationship.NONE


# -- Blood relationship classifier (no cross-clan recursion) -----------------

static func _get_blood_relationship(
	a: L5RCharacterData,
	b: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Relationship:
	if a.character_id == b.character_id:
		return Relationship.SELF

	if _are_siblings(a, b):
		return Relationship.SIBLING

	# Parent / child are direct id checks.
	if a.mother_id == b.character_id or a.father_id == b.character_id:
		return Relationship.PARENT
	if a.children_ids.has(b.character_id):
		return Relationship.CHILD

	# Grandparent / grandchild via two-hop traversal.
	if get_grandparent_ids(a, chars_by_id).has(b.character_id):
		return Relationship.GRANDPARENT
	if get_grandchild_ids(a, chars_by_id).has(b.character_id):
		return Relationship.GRANDCHILD

	# First cousin — b is a child of one of a's aunts/uncles.
	if get_first_cousin_ids(a, chars_by_id).has(b.character_id):
		return Relationship.FIRST_COUSIN

	return Relationship.NONE


static func _are_siblings(a: L5RCharacterData, b: L5RCharacterData) -> bool:
	if a.sibling_ids.has(b.character_id) or b.sibling_ids.has(a.character_id):
		return true
	# Half-siblings via shared mother or father (using -1 sentinel guard).
	if a.mother_id != -1 and a.mother_id == b.mother_id:
		return true
	if a.father_id != -1 and a.father_id == b.father_id:
		return true
	return false


# -- Generation walk ---------------------------------------------------------

static func get_generation_lineage(
	character: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Returns lineage organised by generation depth. G1 is self, G2 parents,
	## G3 grandparents (mix of full chars + lightweight records), G4
	## great-grandparents (lightweight records via parents' grandparent_records).
	var lineage: Dictionary = {
		1: [character.character_id],
		2: get_parent_ids(character),
		3: get_grandparent_ids(character, chars_by_id),
		4: ([] as Array[int]),
	}
	# G4 from parents' grandparent records (lightweight only). We surface
	# AncestorRecord ancestor_ids rather than character_ids since G4 is
	# almost certainly deceased.
	var g4_records: Array[AncestorRecord] = []
	for parent_id: int in get_parent_ids(character):
		var parent: L5RCharacterData = chars_by_id.get(parent_id)
		if parent == null:
			continue
		for record: AncestorRecord in parent.grandparent_records:
			if not g4_records.has(record):
				g4_records.append(record)
	# Self's own great-grandparent records take precedence if explicitly set.
	for record: AncestorRecord in character.great_grandparent_records:
		if not g4_records.has(record):
			g4_records.append(record)
	lineage["g4_records"] = g4_records
	return lineage
