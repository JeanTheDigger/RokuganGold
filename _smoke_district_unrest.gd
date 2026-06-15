extends SceneTree
# THROWAWAY smoke driver (s2.3.23 Otosan Uchi district stability/crime/revolt).
# NOT a GUT test, NOT under /tests/ — a one-off tool. Run locally then DELETE:
#   godot --headless --script _smoke_district_unrest.gd
#
# Exercises DayOrchestrator._process_district_stability_crime over several IC
# seasons across four districts and prints the per-season state, confirming:
#   - stability evolves toward the chaos baseline minus crime drag,
#   - crime is generated every season,
#   - a present skilled Governor holds a chaotic district up,
#   - a failing GOVERNED district gets a Tier-3 NEGATIVE failure topic,
#   - a chronically-failing district (3 seasons < 25) spawns a PEASANT_REVOLT,
#   - a low-chaos district stays stable (control).

const CAP_SETTLEMENT_ID: int = 1
const CAP_PROVINCE_ID: int = 1
const SEASONS: int = 9


func _make_zone(zid: String, sentaku: String, has_gov: bool, lord_id: int) -> NavigationZoneData:
	var nz := NavigationZoneData.new()
	nz.zone_id = zid
	nz.sentaku_name = sentaku
	nz.has_governor = has_gov
	nz.zone_lord_id = lord_id
	nz.district_pu = 8
	nz.district_stability = 100.0
	return nz


func _make_governor(cid: int, name: String, courtier: int) -> L5RCharacterData:
	var g := L5RCharacterData.new()
	g.character_id = cid
	g.character_name = name
	g.skills = {"Courtier": courtier}
	g.status = 3.0
	g.wounds_taken = 0
	g.physical_location = str(CAP_SETTLEMENT_ID)  # co-located at the capital = "present"
	return g


func _init() -> void:
	var dice := DiceEngine.new(42)

	var capital := SettlementData.new()
	capital.settlement_id = CAP_SETTLEMENT_ID
	capital.province_id = CAP_PROVINCE_ID
	capital.settlement_type = Enums.SettlementType.IMPERIAL_CAPITAL
	var settlements: Array = [capital]

	# Four districts (3 HIGH chaos to isolate the governance effect, 1 LOW control).
	var zA := _make_zone("d_jur", "Juramashi", true, -1)          # HIGH, VACANT
	var zB := _make_zone("d_tsai", "Tsai", true, 101)             # HIGH, weak gov
	var zC := _make_zone("d_mei", "Meiyoko", true, 102)           # HIGH, strong gov
	var zD := _make_zone("d_hoj", "Hojize", true, -1)             # LOW, vacant control
	var zones: Array = [zA, zB, zC, zD]

	var govB := _make_governor(101, "Weak-Gov(Courtier1)", 1)
	var govC := _make_governor(102, "Strong-Gov(Courtier6)", 6)
	var chars_by_id: Dictionary = {101: govB, 102: govC}

	var crime_records: Array = []
	var season_meta: Dictionary = {}
	var active_topics: Array = []
	var next_topic_id: Array = [1000]
	var insurgencies: Array = []
	var next_insurgency_id: Array = [1]

	print("season | district  | stab | crime | unrest | revolt_id   (Gov)")
	print("-------+-----------+------+-------+--------+-----------")
	for s in range(SEASONS):
		var ic_day: int = s * 90
		var season_idx: int = s % 4
		DayOrchestrator._process_district_stability_crime(
			zones, chars_by_id, settlements,
			crime_records, season_meta, ic_day, dice,
			active_topics, next_topic_id,
			insurgencies, next_insurgency_id, season_idx,
		)
		for z: NavigationZoneData in zones:
			var gov_tag: String = "vacant"
			if z.zone_lord_id >= 0 and chars_by_id.has(z.zone_lord_id):
				gov_tag = (chars_by_id[z.zone_lord_id] as L5RCharacterData).character_name
			print("  %2d   | %-9s | %4d | %5d | %6d | %3d   (%s)" % [
				s, z.sentaku_name, int(round(z.district_stability)),
				z.district_crime_count, z.district_unrest_seasons,
				z.district_revolt_insurgency_id, gov_tag,
			])
		print("       active_insurgencies=%d  failure_topics=%d" % [
			insurgencies.size(), _count_failure_topics(active_topics),
		])
		print("-------+-----------+------+-------+--------+-----------")

	print("\n=== Failure topics created ===")
	for t: TopicData in active_topics:
		if t.variant == "governor_failure":
			print("  topic %d  tier=%d role=%s  '%s'" % [
				t.topic_id, t.tier, t.subject_role, t.title,
			])
	print("\n=== Revolts spawned ===")
	for i: InsurgencyData in insurgencies:
		print("  insurgency %d  type=%d prov=%d settl=%d str=%d conceal=%d" % [
			i.insurgency_id, i.insurgency_type, i.province_id,
			i.settlement_id, i.strength, i.concealment,
		])
	quit()


func _count_failure_topics(topics: Array) -> int:
	var n: int = 0
	for t: TopicData in topics:
		if t.variant == "governor_failure":
			n += 1
	return n
