class_name CrimeSuppressionSystem
## Crime suppression bridge per GDD s11.3.19.
## Connects the magistrate legal system to the existing insurgency suppression
## system (s11.11 Phase 5). Handles: suppression priority scoring, bushi vs
## courtier magistrate routing, doshin bonuses, detection advantage, and
## doshin availability/recruitment.


# -- Suppression Priority (s11.3.19c) -----

const SEVERITY_BONUS_BANDIT_PIRATE: int = 15
const SEVERITY_BONUS_SMUGGLING_GANG: int = 10

const STABILITY_URGENCY_BELOW_50: int = 20
const STABILITY_URGENCY_BELOW_25: int = 30

const PERSONALITY_PRIORITY: Dictionary = {
	Enums.BushidoVirtue.GI: 15,
	Enums.BushidoVirtue.YU: 10,
	Enums.BushidoVirtue.MEIYO: 10,
	Enums.BushidoVirtue.CHUGI: 10,
	Enums.BushidoVirtue.JIN: 0,
	Enums.BushidoVirtue.REI: 0,
	Enums.BushidoVirtue.MAKOTO: 0,
}

const SHOURIDO_PRIORITY: Dictionary = {
	Enums.ShouridoVirtue.KYORYOKU: 15,
	Enums.ShouridoVirtue.SEIGYO: 0,
	Enums.ShouridoVirtue.ISHI: 5,
	Enums.ShouridoVirtue.KETSUI: 5,
	Enums.ShouridoVirtue.DOSATSU: 0,
	Enums.ShouridoVirtue.CHISHIKI: 0,
	Enums.ShouridoVirtue.KANPEKI: 5,
}


static func get_suppression_priority(
	insurgency_type: Enums.InsurgencyType,
	province_stability: int,
	magistrate: L5RCharacterData,
) -> int:
	var priority: int = 0

	match insurgency_type:
		Enums.InsurgencyType.RONIN_BANDIT, Enums.InsurgencyType.PIRATE_FLEET:
			priority += SEVERITY_BONUS_BANDIT_PIRATE
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			priority += SEVERITY_BONUS_SMUGGLING_GANG
		_:
			priority += SEVERITY_BONUS_SMUGGLING_GANG

	if province_stability < 25:
		priority += STABILITY_URGENCY_BELOW_25
	elif province_stability < 50:
		priority += STABILITY_URGENCY_BELOW_50

	priority += _get_personality_priority(magistrate)

	return priority


static func _get_personality_priority(magistrate: L5RCharacterData) -> int:
	if magistrate.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return SHOURIDO_PRIORITY.get(magistrate.shourido_virtue, 0)
	return PERSONALITY_PRIORITY.get(magistrate.bushido_virtue, 0)


# -- Magistrate Approach (s11.3.19a) -----

enum SuppressionApproach {
	PERSONAL_COMBAT,
	YORIKI_DEPLOYED,
	MILITARY_SUPPORT_REQUESTED,
}


static func determine_suppression_approach(
	magistrate: L5RCharacterData,
	has_bushi_yoriki: bool,
) -> SuppressionApproach:
	if magistrate.school_type == Enums.SchoolType.BUSHI:
		return SuppressionApproach.PERSONAL_COMBAT
	if has_bushi_yoriki:
		return SuppressionApproach.YORIKI_DEPLOYED
	return SuppressionApproach.MILITARY_SUPPORT_REQUESTED


# -- Doshin Bonus (s11.3.19e.ii) -----

const DOSHIN_BONUS_SMALL: int = 3
const DOSHIN_BONUS_MEDIUM: int = 5
const DOSHIN_BONUS_LARGE: int = 8
const DOSHIN_BONUS_SAMURAI_INVESTIGATION: int = 3


static func get_doshin_investigation_bonus(doshin_count: int) -> int:
	if doshin_count >= 6:
		return DOSHIN_BONUS_LARGE
	if doshin_count >= 3:
		return DOSHIN_BONUS_MEDIUM
	if doshin_count >= 1:
		return DOSHIN_BONUS_SMALL
	return 0


static func get_doshin_suppression_bonus(doshin_count: int) -> int:
	if doshin_count >= 6:
		return DOSHIN_BONUS_LARGE
	if doshin_count >= 3:
		return DOSHIN_BONUS_MEDIUM
	if doshin_count >= 1:
		return DOSHIN_BONUS_SMALL
	return 0


static func get_doshin_samurai_investigation_bonus(doshin_count: int) -> int:
	if doshin_count >= 1:
		return DOSHIN_BONUS_SAMURAI_INVESTIGATION
	return 0


# -- Doshin Availability (s11.3.19e.vi, s11.3.19e.vii) -----

enum SettlementSize {
	REMOTE,
	VILLAGE,
	LARGE_VILLAGE,
	CASTLE_TOWN,
	TOWN,
	CITY,
	MAJOR_CITY,
	OTOSAN_UCHI,
}

enum DoshinTier {
	NONE,
	VILLAGE,
	CITY,
}


static func get_doshin_baseline(settlement_size: SettlementSize) -> Dictionary:
	match settlement_size:
		SettlementSize.REMOTE:
			return {"count": 0, "tier": DoshinTier.NONE, "has_headman": false}
		SettlementSize.VILLAGE:
			return {"count": 1, "tier": DoshinTier.VILLAGE, "has_headman": false}
		SettlementSize.LARGE_VILLAGE:
			return {"count": 2, "tier": DoshinTier.VILLAGE, "has_headman": false}
		SettlementSize.CASTLE_TOWN:
			return {"count": 3, "tier": DoshinTier.CITY, "has_headman": false}
		SettlementSize.TOWN:
			return {"count": 5, "tier": DoshinTier.CITY, "has_headman": true}
		SettlementSize.CITY:
			return {"count": 10, "tier": DoshinTier.CITY, "has_headman": true}
		SettlementSize.MAJOR_CITY:
			return {"count": 13, "tier": DoshinTier.CITY, "has_headman": true}
		SettlementSize.OTOSAN_UCHI:
			return {"count": 18, "tier": DoshinTier.CITY, "has_headman": true}
	return {"count": 0, "tier": DoshinTier.NONE, "has_headman": false}


static func get_available_doshin(
	settlement_size: SettlementSize,
	doshin_losses: int,
	is_village_planting_or_harvest: bool,
	province_stability: int,
) -> int:
	var baseline: Dictionary = get_doshin_baseline(settlement_size)
	var available: int = baseline["count"] - doshin_losses

	if is_village_planting_or_harvest and baseline["tier"] == DoshinTier.VILLAGE:
		available = ceili(float(available) / 2.0)

	if province_stability < 25:
		available -= 2

	return maxi(available, 0)


# -- Recruitment Limits (s11.3.19e.viii) -----

static func get_max_recruitable(
	available_doshin: int,
	daimyo_override: bool = false,
) -> int:
	if daimyo_override:
		return available_doshin
	return ceili(float(available_doshin) / 2.0)


# -- Doshin Loss Recovery (s11.3.19e.iii) -----

const DOSHIN_RECOVERY_PER_SEASON: int = 1
const STABILITY_PENALTY_NO_DOSHIN: int = -2


static func process_doshin_recovery(current_losses: int) -> int:
	if current_losses <= 0:
		return 0
	return maxi(current_losses - DOSHIN_RECOVERY_PER_SEASON, 0)


# -- Detection Advantage (s11.3.19a) -----

static func get_patrol_detection_chances(
	magistrate_count: int,
	yoriki_count: int,
) -> int:
	return magistrate_count + yoriki_count


# -- Suppression Consequences (s11.3.19d) -----

static func get_suppression_success_consequences(
	involves_samurai_criminals: bool,
) -> Dictionary:
	var result: Dictionary = {
		"glory_gain_magistrate": true,
		"glory_gain_yoriki": true,
		"daimyo_disposition_toward_magistrate": 5,
		"heimin_swift_justice": not involves_samurai_criminals,
		"samurai_enter_investigation": involves_samurai_criminals,
		"evidence_may_reveal_network": true,
	}
	return result


# -- ASCII Map Mission Types (s11.3.19b) -----

enum SuppressionMissionType {
	RAID_BANDIT_CAMP,
	RAID_SMUGGLING_OPERATION,
	RAID_GANG_HIDEOUT,
	INTERCEPT_PIRATE_VESSEL,
	ARREST_SUSPECT,
}


static func get_mission_type(insurgency_type: Enums.InsurgencyType) -> SuppressionMissionType:
	match insurgency_type:
		Enums.InsurgencyType.RONIN_BANDIT:
			return SuppressionMissionType.RAID_BANDIT_CAMP
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			return SuppressionMissionType.RAID_GANG_HIDEOUT
		Enums.InsurgencyType.PIRATE_FLEET:
			return SuppressionMissionType.INTERCEPT_PIRATE_VESSEL
		_:
			return SuppressionMissionType.RAID_SMUGGLING_OPERATION
