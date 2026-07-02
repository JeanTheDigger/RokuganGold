class_name NamedVesselData
extends Resource
## An individual, named-NPC vessel per GDD s57.42 (owner-patron pattern, s57.42.2)
## and s57.43 (voyage play). Distinct from ShipData: ShipData is a military fleet
## Company for mass naval combat (s11.9); a NamedVesselData is a single boat a
## named character owns/operates for transport and personal use. The one crossover
## is that an individual named vessel may JOIN a naval battle as a single unit —
## converted to a ShipData Company on the fly — when its owner/captain opts in
## (owner_opts_into_battle). Otherwise the two models never touch.
##
## Caller owns all mutation; this is a plain data container.


## WARSHIP vessels lean toward fighting when a battle occurs where they are;
## TRANSPORT vessels lean toward fleeing. See owner_opts_into_battle().
enum Purpose { WARSHIP, TRANSPORT }


@export var vessel_id: int = -1

## ShipClass enum value. Named vessels are Kobune/Sengokobune (the classes that
## actually exist in play); no dedicated "civilian" class is instantiated.
@export var ship_class: int = Enums.ShipClass.KOBUNE

## Owner-patron: the named character who owns the vessel as property (s57.42.2).
@export var owner_id: int = -1

## The character who commands the vessel day-to-day (may equal owner_id in the
## self-owned edge case, s57.42.2). -1 = no captain assigned.
@export var captain_id: int = -1

## Owning clan (the owner's clan) — the side this vessel takes if it joins a battle.
@export var owning_clan: String = ""

@export var vessel_name: String = ""

## WARSHIP vs TRANSPORT — tilts the owner's opt-in-to-fight decision.
@export var purpose: int = Purpose.TRANSPORT

## Location.
@export var current_province_id: int = -1
@export var current_subtile_id: int = -1  # -1 = docked at a settlement

## Voyage / movement state (s57.42.7, s57.43).
@export var departure_tick: int = -1
@export var is_moving: bool = false
@export var destination_subtile_id: int = -1
@export var movement_days_remaining: int = 0

## Multi-hop voyage state — same shape as ShipData (NavalMovementSystem.step_movement
## operates on either model by duck typing). Remaining water sub-tile ids after the
## current hop; empty = single-hop / not voyaging. Voyage docks at the destination
## province on arrival.
@export var voyage_route: PackedInt32Array = PackedInt32Array()
@export var voyage_destination_province: int = -1

## Cargo capacity in Rice/Koku units (flavor per s11.9 — no goods-transport mechanic).
@export var cargo_capacity: float = 0.0

@export var is_destroyed: bool = false
@export var ic_day_launched: int = -1


## Decide whether the vessel's owner/captain opts into a naval fight that occurs
## where the vessel is (the s57.42/43 "joins battle like an individual" crossover).
## Owner-approved SHAPE: personality/virtue-driven, tilted by purpose. Exact virtue
## weighting is PROVISIONAL (flagged for owner tuning). Forward-wired: there is no
## live naval-battle trigger for named vessels until sub-tile water movement exists.
static func owner_opts_into_battle(owner: L5RCharacterData, vessel_purpose: int) -> bool:
	if owner == null or CharacterStats.is_dead(owner):
		# No captain to decide → a warship holds, a transport slips away.
		return vessel_purpose == Purpose.WARSHIP
	if vessel_purpose == Purpose.WARSHIP:
		# A warship fights unless its captain is notably cautious (Seigyo — Control).
		return owner.shourido_virtue != Enums.ShouridoVirtue.SEIGYO
	# TRANSPORT: flees unless a courageous owner (Yu) chooses to make a stand.
	return owner.bushido_virtue == Enums.BushidoVirtue.YU


## Convert this named vessel into a military ShipData "Company" so it can be slotted
## into a naval battle as a single unit (the crossover). owning_clan sets the battle
## side; stats are derived from ship_class via NavalSystem. Forward-wired helper.
func to_ship_data(battle_owning_clan: String = "") -> ShipData:
	var clan: String = battle_owning_clan if not battle_owning_clan.is_empty() else owning_clan
	var ship: ShipData = NavalSystem.create_ship(vessel_id, ship_class, clan, vessel_name, ic_day_launched)
	ship.captain_id = captain_id
	ship.owner_id = owner_id
	ship.current_province_id = current_province_id
	ship.current_subtile_id = current_subtile_id
	return ship
