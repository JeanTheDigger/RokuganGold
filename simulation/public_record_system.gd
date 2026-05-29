class_name PublicRecordSystem
## Settlement Public Record per GDD s57.50.
## Settlement-level buffer of public events. Commoner memory: events witnessed
## by background entities persist here and are accessible via ambient pickup
## (free, within tier-scaled window) or investigation roll (older entries).


# -- Retention Windows (TTL in IC days, -1 = permanent) -----------------------
# Per GDD s57.50.2 — locked s57.50

const RETENTION_BY_TIER: Dictionary = {
	TopicData.Tier.TIER_1: -1,    # permanent
	TopicData.Tier.TIER_2: 1080,  # 3 years
	TopicData.Tier.TIER_3: 360,   # 1 year
	TopicData.Tier.TIER_4: 90,    # 1 season
}

# -- Ambient Windows (IC days, 999999 = always ambient) -----------------------
# Per GDD s57.50.3 — locked s57.50

const AMBIENT_WINDOW_BY_TIER: Dictionary = {
	TopicData.Tier.TIER_1: 999999,  # always ambient
	TopicData.Tier.TIER_2: 360,     # 1 year
	TopicData.Tier.TIER_3: 90,      # 1 season
	TopicData.Tier.TIER_4: 14,      # 2 weeks
}

# -- Investigation TN Constants (per GDD s57.50.3) ----------------------------

const INVESTIGATION_BASE_TN: int = 10
const INVESTIGATION_TN_PER_DAYS: int = 10  # +1 TN per 10 IC days past ambient window
const INVESTIGATION_TN_CAP: int = 30


# -- Seeding ------------------------------------------------------------------

static func seed_event(
	settlement: SettlementData,
	event_type: String,
	tier: int,
	ic_day: int,
	topic_id: int = -1,
	subject_id: int = -1,
	zone_subtype: String = "",
) -> void:
	settlement.public_record.append({
		"event_type": event_type,
		"ic_day": ic_day,
		"tier": tier,
		"topic_id": topic_id,
		"subject_id": subject_id,
		"zone_subtype": zone_subtype,
	})


# -- Ambient Check ------------------------------------------------------------

static func is_ambient(entry: Dictionary, current_ic_day: int) -> bool:
	var tier: int = entry.get("tier", TopicData.Tier.TIER_4)
	var days_since: int = current_ic_day - entry.get("ic_day", current_ic_day)
	var window: int = AMBIENT_WINDOW_BY_TIER.get(tier, 14)
	return days_since <= window


static func get_ambient_events(settlement: SettlementData, current_ic_day: int) -> Array:
	var result: Array = []
	for entry: Variant in settlement.public_record:
		if entry is Dictionary and is_ambient(entry as Dictionary, current_ic_day):
			result.append(entry)
	return result


# -- Investigation Access -----------------------------------------------------

static func get_investigation_tn(entry: Dictionary, current_ic_day: int) -> int:
	var tier: int = entry.get("tier", TopicData.Tier.TIER_4)
	var days_since: int = current_ic_day - entry.get("ic_day", current_ic_day)
	var window: int = AMBIENT_WINDOW_BY_TIER.get(tier, 14)
	var days_past_window: int = max(0, days_since - window)
	var tn: int = INVESTIGATION_BASE_TN + days_past_window / INVESTIGATION_TN_PER_DAYS
	return mini(tn, INVESTIGATION_TN_CAP)


static func query_by_investigation(
	settlement: SettlementData,
	roll_total: int,
	current_ic_day: int,
) -> Array:
	var result: Array = []
	for entry: Variant in settlement.public_record:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry as Dictionary
		if is_ambient(e, current_ic_day):
			continue  # already free via ambient path
		var tn: int = get_investigation_tn(e, current_ic_day)
		if roll_total >= tn:
			result.append(e)
	return result


# -- Retention Purge ----------------------------------------------------------

static func purge_expired(settlement: SettlementData, current_ic_day: int) -> void:
	var retained: Array = []
	for entry: Variant in settlement.public_record:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry as Dictionary
		var tier: int = e.get("tier", TopicData.Tier.TIER_4)
		var retention: int = RETENTION_BY_TIER.get(tier, 90)
		if retention < 0:
			retained.append(e)  # permanent
		elif current_ic_day - e.get("ic_day", current_ic_day) <= retention:
			retained.append(e)
	settlement.public_record = retained
