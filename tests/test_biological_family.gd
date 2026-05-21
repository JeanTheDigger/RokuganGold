extends GutTest
## Tests for BiologicalFamily traversal per GDD s22.6.


# Test pedigree:
#
#   G3:        100   101   102   103     (paternal then maternal grandparents)
#                \ /           \ /
#   G2:           1             2
#                  \           /
#   G1 (self):       --- 3 ---
#                              \
#   G2 (sibling):              4   <- shares parents 1+2 with 3
#
#   Aunt (1's sibling): 5
#   First cousin: 50 (5's child)
#
#   Spouse cross-clan: 60 (Crane), spouse's sibling 61, in-law of 3.
#
# Plus a half-sibling (7) sharing only the mother (2) with 3.


var _chars: Dictionary


func before_each() -> void:
	_chars = {}


func _make(id: int, clan: String = "Lion", family: String = "Akodo") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.family = family
	_chars[id] = c
	return c


# -- SELF and NONE -----------------------------------------------------------

func test_self_returns_self() -> void:
	var a: L5RCharacterData = _make(1)
	var b: L5RCharacterData = _make(2)
	assert_eq(
		BiologicalFamily.get_relationship(a, a, _chars),
		BiologicalFamily.Relationship.SELF,
	)
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.NONE,
	)


func test_null_returns_none() -> void:
	var a: L5RCharacterData = _make(1)
	assert_eq(
		BiologicalFamily.get_relationship(a, null, _chars),
		BiologicalFamily.Relationship.NONE,
	)


# -- Sibling -----------------------------------------------------------------

func test_full_siblings_via_sibling_ids() -> void:
	var a: L5RCharacterData = _make(3)
	var b: L5RCharacterData = _make(4)
	a.sibling_ids = [4]
	b.sibling_ids = [3]
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.SIBLING,
	)


func test_full_siblings_via_shared_parents() -> void:
	var a: L5RCharacterData = _make(3)
	var b: L5RCharacterData = _make(4)
	a.mother_id = 2
	a.father_id = 1
	b.mother_id = 2
	b.father_id = 1
	# sibling_ids unset — should still be detected via shared parents.
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.SIBLING,
	)


func test_half_siblings_share_mother_only() -> void:
	var a: L5RCharacterData = _make(3)
	var b: L5RCharacterData = _make(7)
	a.mother_id = 2
	a.father_id = 1
	b.mother_id = 2
	b.father_id = 99   # different father
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.SIBLING,
	)


func test_unrelated_chars_with_minus_one_parents_are_not_siblings() -> void:
	# Both have mother_id=-1; the sentinel must NOT be treated as a match.
	var a: L5RCharacterData = _make(3)
	var b: L5RCharacterData = _make(4)
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.NONE,
	)


# -- Parent / Child ----------------------------------------------------------

func test_parent_via_mother_id() -> void:
	var child: L5RCharacterData = _make(3)
	var mother: L5RCharacterData = _make(2)
	child.mother_id = 2
	assert_eq(
		BiologicalFamily.get_relationship(child, mother, _chars),
		BiologicalFamily.Relationship.PARENT,
	)


func test_parent_via_father_id() -> void:
	var child: L5RCharacterData = _make(3)
	var father: L5RCharacterData = _make(1)
	child.father_id = 1
	assert_eq(
		BiologicalFamily.get_relationship(child, father, _chars),
		BiologicalFamily.Relationship.PARENT,
	)


func test_child_via_children_ids() -> void:
	var parent: L5RCharacterData = _make(2)
	var child: L5RCharacterData = _make(3)
	parent.children_ids = [3]
	assert_eq(
		BiologicalFamily.get_relationship(parent, child, _chars),
		BiologicalFamily.Relationship.CHILD,
	)


# -- Grandparent / Grandchild ------------------------------------------------

func test_grandparent_via_two_hop() -> void:
	var grand: L5RCharacterData = _make(100)
	var parent: L5RCharacterData = _make(1)
	var child: L5RCharacterData = _make(3)
	parent.father_id = 100
	child.father_id = 1
	assert_eq(
		BiologicalFamily.get_relationship(child, grand, _chars),
		BiologicalFamily.Relationship.GRANDPARENT,
	)


func test_grandchild_via_two_hop() -> void:
	var grand: L5RCharacterData = _make(100)
	var parent: L5RCharacterData = _make(1)
	var child: L5RCharacterData = _make(3)
	grand.children_ids = [1]
	parent.children_ids = [3]
	assert_eq(
		BiologicalFamily.get_relationship(grand, child, _chars),
		BiologicalFamily.Relationship.GRANDCHILD,
	)


func test_get_grandparent_ids_dedupe() -> void:
	var grand: L5RCharacterData = _make(100)
	var p1: L5RCharacterData = _make(1)
	var p2: L5RCharacterData = _make(2)
	var child: L5RCharacterData = _make(3)
	p1.father_id = 100
	p2.father_id = 100   # both parents share a father (unusual, but tests dedupe)
	child.mother_id = 2
	child.father_id = 1
	var grandparents: Array = BiologicalFamily.get_grandparent_ids(child, _chars)
	assert_eq(grandparents.size(), 1)
	assert_eq(grandparents[0], 100)


# -- First cousin ------------------------------------------------------------

func test_first_cousin_via_aunt_or_uncle() -> void:
	# self's father (1) has a sibling (5); 5's child (50) is self's first cousin.
	var father: L5RCharacterData = _make(1)
	var aunt: L5RCharacterData = _make(5)
	var self_char: L5RCharacterData = _make(3)
	var cousin: L5RCharacterData = _make(50)
	father.sibling_ids = [5]
	aunt.sibling_ids = [1]
	aunt.children_ids = [50]
	self_char.father_id = 1
	cousin.mother_id = 5
	assert_eq(
		BiologicalFamily.get_relationship(self_char, cousin, _chars),
		BiologicalFamily.Relationship.FIRST_COUSIN,
	)


func test_first_cousin_via_shared_grandparent() -> void:
	# Self's parent (1) and aunt (5) share a parent (100) but aren't in
	# each other's sibling_ids — half-siblings detected via grandparent.
	var grand: L5RCharacterData = _make(100)
	var father: L5RCharacterData = _make(1)
	var aunt: L5RCharacterData = _make(5)
	var self_char: L5RCharacterData = _make(3)
	var cousin: L5RCharacterData = _make(50)
	grand.children_ids = [1, 5]
	father.father_id = 100
	aunt.father_id = 100
	aunt.children_ids = [50]
	self_char.father_id = 1
	cousin.mother_id = 5
	assert_eq(
		BiologicalFamily.get_relationship(self_char, cousin, _chars),
		BiologicalFamily.Relationship.FIRST_COUSIN,
	)


# -- Cross-clan marriage relative --------------------------------------------

func test_cross_clan_marriage_relative_through_spouse_sibling() -> void:
	# self (Lion) marries spouse (Crane). Spouse has a sibling in Crane.
	# That spouse-sibling is a CROSS_CLAN_MARRIAGE_RELATIVE of self.
	var self_char: L5RCharacterData = _make(3, "Lion")
	var spouse: L5RCharacterData = _make(60, "Crane")
	var spouse_sib: L5RCharacterData = _make(61, "Crane")
	self_char.spouse_id = 60
	spouse.sibling_ids = [61]
	spouse_sib.sibling_ids = [60]
	assert_eq(
		BiologicalFamily.get_relationship(self_char, spouse_sib, _chars),
		BiologicalFamily.Relationship.CROSS_CLAN_MARRIAGE_RELATIVE,
	)


func test_intra_clan_marriage_does_not_create_cross_clan_relatives() -> void:
	var self_char: L5RCharacterData = _make(3, "Lion")
	var spouse: L5RCharacterData = _make(60, "Lion")
	var spouse_sib: L5RCharacterData = _make(61, "Lion")
	self_char.spouse_id = 60
	spouse.sibling_ids = [61]
	# Same clan — no cross-clan tie should fire.
	assert_eq(
		BiologicalFamily.get_relationship(self_char, spouse_sib, _chars),
		BiologicalFamily.Relationship.NONE,
	)


func test_cross_clan_skipped_when_target_in_self_clan() -> void:
	# Edge case: self and target are both Lion, but self's spouse is Crane
	# and the target happens to be related to the spouse. This shouldn't fire
	# a cross-clan tie because target is in self's own clan already.
	var self_char: L5RCharacterData = _make(3, "Lion")
	var spouse: L5RCharacterData = _make(60, "Crane")
	var related_lion: L5RCharacterData = _make(61, "Lion")
	self_char.spouse_id = 60
	spouse.sibling_ids = [61]
	assert_eq(
		BiologicalFamily.get_relationship(self_char, related_lion, _chars),
		BiologicalFamily.Relationship.NONE,
	)


func test_blood_relation_takes_precedence_over_cross_clan() -> void:
	# A is sibling of B, A's spouse is in another clan. Even if cross-clan
	# would fire, the SIBLING relation must be returned first.
	var a: L5RCharacterData = _make(3, "Lion")
	var b: L5RCharacterData = _make(4, "Lion")
	a.sibling_ids = [4]
	b.sibling_ids = [3]
	a.spouse_id = 60
	_make(60, "Crane")
	assert_eq(
		BiologicalFamily.get_relationship(a, b, _chars),
		BiologicalFamily.Relationship.SIBLING,
	)


# -- Modifier values ---------------------------------------------------------

func test_modifier_values_match_disposition_table() -> void:
	# The bond values are owned by DispositionSystem.FAMILY_BONDS — verify the
	# classifier returns matching modifiers for each relationship type.
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.SIBLING),
		DispositionSystem.FAMILY_BONDS["sibling"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.PARENT),
		DispositionSystem.FAMILY_BONDS["parent_child"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.CHILD),
		DispositionSystem.FAMILY_BONDS["parent_child"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.GRANDPARENT),
		DispositionSystem.FAMILY_BONDS["grandparent_grandchild"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.GRANDCHILD),
		DispositionSystem.FAMILY_BONDS["grandparent_grandchild"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.FIRST_COUSIN),
		DispositionSystem.FAMILY_BONDS["first_cousin"],
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.CROSS_CLAN_MARRIAGE_RELATIVE),
		DispositionSystem.FAMILY_BONDS["cross_clan_marriage"],
	)


func test_none_relationship_yields_zero_modifier() -> void:
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.NONE),
		0,
	)
	assert_eq(
		BiologicalFamily.get_family_modifier(BiologicalFamily.Relationship.SELF),
		0,
	)


func test_compute_pairwise_modifier_end_to_end() -> void:
	var a: L5RCharacterData = _make(3, "Lion")
	var b: L5RCharacterData = _make(4, "Lion")
	a.sibling_ids = [4]
	b.sibling_ids = [3]
	assert_eq(
		BiologicalFamily.compute_pairwise_modifier(a, b, _chars),
		DispositionSystem.FAMILY_BONDS["sibling"],
	)


# -- Direct helper queries ---------------------------------------------------

func test_get_parent_ids_returns_both_when_set() -> void:
	var c: L5RCharacterData = _make(3)
	c.mother_id = 2
	c.father_id = 1
	var parents: Array = BiologicalFamily.get_parent_ids(c)
	assert_eq(parents.size(), 2)
	assert_true(parents.has(1))
	assert_true(parents.has(2))


func test_get_parent_ids_skips_unset_sentinels() -> void:
	var c: L5RCharacterData = _make(3)
	c.mother_id = -1
	c.father_id = 1
	var parents: Array = BiologicalFamily.get_parent_ids(c)
	assert_eq(parents.size(), 1)
	assert_eq(parents[0], 1)


func test_get_aunt_uncle_ids_excludes_self_parent() -> void:
	var father: L5RCharacterData = _make(1)
	var uncle: L5RCharacterData = _make(5)
	var child: L5RCharacterData = _make(3)
	father.sibling_ids = [5]
	child.father_id = 1
	var aunts_uncles: Array = BiologicalFamily.get_aunt_uncle_ids(child, _chars)
	assert_true(aunts_uncles.has(5))
	assert_false(aunts_uncles.has(1))


# -- Generation lineage ------------------------------------------------------

func test_lineage_includes_full_four_generations() -> void:
	var grand_paternal: L5RCharacterData = _make(100)
	var grand_maternal: L5RCharacterData = _make(101)
	var father: L5RCharacterData = _make(1)
	var mother: L5RCharacterData = _make(2)
	var child: L5RCharacterData = _make(3)
	father.father_id = 100
	mother.mother_id = 101
	child.father_id = 1
	child.mother_id = 2

	var ggp_record: AncestorRecord = AncestorRecord.new()
	ggp_record.ancestor_id = 1000
	ggp_record.name = "Akodo Toturi the First"
	ggp_record.generation = 4
	father.grandparent_records = [ggp_record]

	var lineage: Dictionary = BiologicalFamily.get_generation_lineage(child, _chars)
	assert_eq(lineage[1].size(), 1)
	assert_eq(lineage[2].size(), 2)
	assert_true(lineage[3].has(100))
	assert_true(lineage[3].has(101))
	var g4: Array = lineage["g4_records"]
	assert_eq(g4.size(), 1)
	assert_eq((g4[0] as AncestorRecord).ancestor_id, 1000)


# -- Ancestor record basics --------------------------------------------------

func test_ancestor_is_living_when_ic_year_died_unset() -> void:
	var rec: AncestorRecord = AncestorRecord.new()
	rec.ic_year_died = -1
	assert_true(rec.is_living(500))


func test_ancestor_is_dead_when_year_died_passed() -> void:
	var rec: AncestorRecord = AncestorRecord.new()
	rec.ic_year_died = 400
	assert_false(rec.is_living(500))


func test_ancestor_is_living_when_year_died_in_future() -> void:
	var rec: AncestorRecord = AncestorRecord.new()
	rec.ic_year_died = 600
	assert_true(rec.is_living(500))


# -- compute_all_family_bonds -------------------------------------------------

func test_compute_all_family_bonds_returns_close_relations() -> void:
	var self_char: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	var father: L5RCharacterData = _make(1)
	var child: L5RCharacterData = _make(7)
	self_char.sibling_ids = [4]
	sibling.sibling_ids = [3]
	self_char.father_id = 1
	self_char.children_ids = [7]

	var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(self_char, _chars)
	assert_eq(bonds[4], DispositionSystem.FAMILY_BONDS["sibling"])
	assert_eq(bonds[1], DispositionSystem.FAMILY_BONDS["parent_child"])
	assert_eq(bonds[7], DispositionSystem.FAMILY_BONDS["parent_child"])


func test_compute_all_family_bonds_includes_grandparents_and_cousins() -> void:
	var grand: L5RCharacterData = _make(100)
	var father: L5RCharacterData = _make(1)
	var aunt: L5RCharacterData = _make(5)
	var self_char: L5RCharacterData = _make(3)
	var cousin: L5RCharacterData = _make(50)
	father.father_id = 100
	father.sibling_ids = [5]
	aunt.father_id = 100
	aunt.sibling_ids = [1]
	aunt.children_ids = [50]
	self_char.father_id = 1
	cousin.mother_id = 5

	var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(self_char, _chars)
	assert_eq(bonds.get(100, -1), DispositionSystem.FAMILY_BONDS["grandparent_grandchild"])
	assert_eq(bonds.get(50, -1), DispositionSystem.FAMILY_BONDS["first_cousin"])


func test_compute_all_family_bonds_includes_cross_clan_relatives() -> void:
	var self_char: L5RCharacterData = _make(3, "Lion")
	var spouse: L5RCharacterData = _make(60, "Crane")
	var spouse_sib: L5RCharacterData = _make(61, "Crane")
	self_char.spouse_id = 60
	spouse.sibling_ids = [61]

	var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(self_char, _chars)
	assert_eq(
		bonds.get(61, -999),
		DispositionSystem.FAMILY_BONDS["cross_clan_marriage"],
	)


func test_compute_all_family_bonds_does_not_include_strangers() -> void:
	var self_char: L5RCharacterData = _make(3)
	_make(99)  # Unrelated stranger.
	var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(self_char, _chars)
	assert_false(bonds.has(99))


func test_compute_all_family_bonds_handles_null_actor() -> void:
	var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(null, _chars)
	assert_true(bonds.is_empty())


# -- DispositionSystem.get_effective_disposition -----------------------------

func test_effective_disposition_falls_back_without_chars_by_id() -> void:
	var actor: L5RCharacterData = _make(3)
	actor.disposition_values = {99: 25}
	assert_eq(DispositionSystem.get_effective_disposition(actor, 99), 25)


func test_effective_disposition_layers_family_bond() -> void:
	var actor: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	actor.sibling_ids = [4]
	sibling.sibling_ids = [3]
	actor.disposition_values = {4: 10}
	# Stored 10 + sibling bond 20 = 30.
	assert_eq(
		DispositionSystem.get_effective_disposition(actor, 4, _chars),
		30,
	)


func test_effective_disposition_clamps_at_100() -> void:
	var actor: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	actor.sibling_ids = [4]
	sibling.sibling_ids = [3]
	actor.disposition_values = {4: 95}
	# 95 + 20 = 115 -> clamped 100.
	assert_eq(
		DispositionSystem.get_effective_disposition(actor, 4, _chars),
		100,
	)


func test_effective_disposition_returns_zero_for_negative_target() -> void:
	var actor: L5RCharacterData = _make(3)
	assert_eq(DispositionSystem.get_effective_disposition(actor, -1, _chars), 0)


func test_effective_disposition_returns_zero_for_null_actor() -> void:
	assert_eq(DispositionSystem.get_effective_disposition(null, 4, _chars), 0)


# -- NPCDecisionEngine.build_context augmentation ----------------------------

func test_build_context_omits_family_bonds_without_chars_by_id() -> void:
	var actor: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	actor.sibling_ids = [4]
	sibling.sibling_ids = [3]
	actor.disposition_values = {4: 5}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(actor, {})
	assert_eq(ctx.dispositions.get(4, 0), 5)


func test_build_context_layers_family_bonds_when_chars_by_id_provided() -> void:
	var actor: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	actor.sibling_ids = [4]
	sibling.sibling_ids = [3]
	actor.disposition_values = {4: 5}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(actor, {}, _chars)
	# 5 stored + 20 sibling bond.
	assert_eq(ctx.dispositions.get(4, 0), 25)
	assert_eq(ctx.disposition_values.get(4, 0), 25)


func test_build_context_seeds_dispositions_for_relatives_with_no_stored_value() -> void:
	# A character who has never met their sibling still feels the bond.
	var actor: L5RCharacterData = _make(3)
	var sibling: L5RCharacterData = _make(4)
	actor.sibling_ids = [4]
	sibling.sibling_ids = [3]
	# disposition_values is empty.
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(actor, {}, _chars)
	assert_eq(ctx.dispositions.get(4, 0), 20)


func test_build_context_does_not_alter_non_relatives() -> void:
	var actor: L5RCharacterData = _make(3)
	_make(99)
	actor.disposition_values = {99: -10}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(actor, {}, _chars)
	assert_eq(ctx.dispositions.get(99, 0), -10)
