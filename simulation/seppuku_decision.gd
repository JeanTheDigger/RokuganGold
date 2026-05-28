class_name SeppukuDecision
## NPC seppuku acceptance/refusal decision per personality.
## Called after ConvictionProcessor marks seppuku_offered on a CrimeRecord.
## The NPC's Bushido virtue and Honor rank determine acceptance.
##
## Design sources:
##   s19: "Meiyo: seppuku before dishonor" (siege end condition)
##   s19: Gi acts on evidence of wrongdoing
##   s19: Chugi follows lord's command
##   s18: refusal → exile, ronin, massive honor loss
##   s57.47.4: seppuku modifier (+1.0 Honor, halved family penalty)
##
## Shourido virtues lean toward refusal — self-preservation over code.
## Honor Rank 0 characters always refuse (no investment in the code).


const HONOR_RANK_ALWAYS_REFUSE: int = 0

const BUSHIDO_ACCEPTANCE: Dictionary = {
	Enums.BushidoVirtue.GI: true,
	Enums.BushidoVirtue.MEIYO: true,
	Enums.BushidoVirtue.CHUGI: true,
	Enums.BushidoVirtue.MAKOTO: true,
	Enums.BushidoVirtue.YU: true,
	Enums.BushidoVirtue.JIN: true,
	Enums.BushidoVirtue.REI: true,
}

const SHOURIDO_ACCEPTANCE: Dictionary = {
	Enums.ShouridoVirtue.KETSUI: false,
	Enums.ShouridoVirtue.KANPEKI: false,
	Enums.ShouridoVirtue.SEIGYO: false,
	Enums.ShouridoVirtue.DOSATSU: true,
	Enums.ShouridoVirtue.ISHI: false,
	Enums.ShouridoVirtue.CHISHIKI: true,
}

const DOSATSU_HONOR_THRESHOLD: int = 0
const CHISHIKI_HONOR_THRESHOLD: int = 0


static func will_accept_seppuku(character: L5RCharacterData) -> Dictionary:
	var honor_rank: int = HonorGlorySystem.get_honor_rank(character)

	if honor_rank <= HONOR_RANK_ALWAYS_REFUSE:
		return {
			"accepts": false,
			"reason": "no_honor_investment",
			"honor_rank": honor_rank,
		}

	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		var accepts: bool = SHOURIDO_ACCEPTANCE.get(
			character.shourido_virtue, false
		)
		if character.shourido_virtue == Enums.ShouridoVirtue.DOSATSU:
			accepts = honor_rank >= DOSATSU_HONOR_THRESHOLD
		elif character.shourido_virtue == Enums.ShouridoVirtue.CHISHIKI:
			accepts = honor_rank >= CHISHIKI_HONOR_THRESHOLD

		var reason: String = "shourido_self_preservation"
		if accepts:
			reason = "shourido_calculated_acceptance"
		return {
			"accepts": accepts,
			"reason": reason,
			"virtue": Enums.bushido_virtue_name(character.bushido_virtue),
			"shourido": true,
			"honor_rank": honor_rank,
		}

	var accepts: bool = BUSHIDO_ACCEPTANCE.get(
		character.bushido_virtue, true
	)

	var reason: String = "bushido_code_demands_it"
	if character.bushido_virtue == Enums.BushidoVirtue.MEIYO:
		reason = "seppuku_before_dishonor"
	elif character.bushido_virtue == Enums.BushidoVirtue.GI:
		reason = "just_consequence"
	elif character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		reason = "lord_commanded_it"

	return {
		"accepts": accepts,
		"reason": reason,
		"virtue": Enums.bushido_virtue_name(character.bushido_virtue),
		"shourido": false,
		"honor_rank": honor_rank,
	}


