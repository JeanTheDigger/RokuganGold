class_name CommuneSystem
## s32 Commune — standardized per-element divination (targeted at a person or scene).
##
## A shugenja speaks with one local elemental kami of a chosen element, which answers within its
## GDD-described domain (s32 flavour text turned into concrete capabilities):
##   Air   — "words, feelings, things conveyed through the air": recent Air-kami manipulations on
##           a target — Cloud the Mind memory-tampering, illusions, mind-reading.
##   Earth — "the land, the dead, blunt physical detail": Shadowlands Taint, the dead, scene facts.
##           [domain slot — not yet wired]
##   Fire  — "passion, what was burned, recent events; clearest/most accurate": recent events the
##           fire witnessed at a scene. [domain slot — not yet wired]
##   Water — "soundless visual images, good for investigating PAST incidents": replay a past
##           incident at a location. [domain slot — not yet wired]
##
## Pure class (no Node). The cast (resolve_commune) is character-only; the per-element reveal
## (commune_reveal) needs the world refs (crime_records / active_topics) and runs in a writeback.

const COMMUNE_MASTERY: int = 1  # s32: All Mastery 1


## Resolve the Commune cast itself (TN 10, ML1), rolling the CHOSEN element's Ring and consuming
## a slot of that element (Commune is universal — the element is the caster's choice of domain).
## Returns {success, total, tn, element}.
static func resolve_commune(
	communer: L5RCharacterData, dice: DiceEngine, element: Enums.Ring
) -> Dictionary:
	if communer == null or "commune" not in communer.spells_known:
		return {"success": false, "reason": "unknown_spell", "element": element}
	if not SpellSystem.can_afford_slot(communer, element):
		return {"success": false, "reason": "no_slot", "element": element}
	SpellSystem.consume_slot(communer, element)
	var ring: int = SpellSystem.get_ring_value(communer, element)
	var tn: int = SpellSystem.get_casting_tn(COMMUNE_MASTERY)
	var roll: DiceResult = dice.roll_and_keep(ring, ring, true, false)
	return {"success": roll.total >= tn, "total": roll.total, "tn": tn, "element": element}


## Per-element reveal dispatch (runs after a successful cast, in a writeback with world refs).
static func commune_reveal(
	communer: L5RCharacterData, target: L5RCharacterData, element: Enums.Ring,
	crime_records: Array, active_topics: Array,
) -> Dictionary:
	match element:
		Enums.Ring.AIR:
			return air_detect_tampering(communer, target, crime_records, active_topics)
		_:
			# Earth / Fire / Water domains are standardized slots, not yet wired to consumers.
			return {"detected": false, "reason": "element_domain_not_yet_standardized"}


## Air domain — ask the Air kami whether the target's mind was tampered with. If a covert s33
## Cloud the Mind crime exists against the target, the kami expose it: the communer learns the
## previously-unseeded topic, the crime opens to investigation, and the communer becomes the
## investigating magistrate. Returns {detected, topic_id, perpetrator_id, case_id}.
static func air_detect_tampering(
	communer: L5RCharacterData, target: L5RCharacterData,
	crime_records: Array, active_topics: Array,
) -> Dictionary:
	if communer == null or target == null:
		return {"detected": false}
	for rec: CrimeRecord in crime_records:
		if rec.source_action != "CLOUD_THE_MIND" or rec.victim_id != target.character_id:
			continue
		# Find the covert topic created from this record (subject = perpetrator, variant marker).
		for topic: TopicData in active_topics:
			if topic.resolved or topic.variant != "cloud_the_mind":
				continue
			if topic.subject_character_id != rec.perpetrator_id:
				continue
			if topic.topic_id not in communer.topic_pool:
				communer.topic_pool.append(topic.topic_id)
			if rec.legal_status == Enums.LegalStatus.NONE:
				rec.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
			rec.investigating_magistrate_id = communer.character_id
			return {"detected": true, "topic_id": topic.topic_id,
				"perpetrator_id": rec.perpetrator_id, "case_id": rec.case_id}
	return {"detected": false}
