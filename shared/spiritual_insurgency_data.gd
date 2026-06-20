class_name SpiritualInsurgencyData
extends Resource
## Data model for a spiritual insurgency event per GDD s56.16.
## Independent of standard InsurgencyData (s11.11).


@export var event_id: int = -1
@export var province_id: int = -1
@export var event_type: Enums.SpiritualEventType = Enums.SpiritualEventType.REALM_OVERLAP
@export var realm: Enums.SpiritRealm = Enums.SpiritRealm.GAKI_DO
@export var element: Enums.Ring = Enums.Ring.NONE
@export var severity: Enums.SpiritualSeverity = Enums.SpiritualSeverity.MILD
@export var season_spawned: int = -1
@export var seasons_active: int = 0
@export var resolved: bool = false
@export var resolution_type: String = ""
@export var npc_resolution_attempted: bool = false

# Restoration ritual progress that persists between missions (s56.16.5f:
# "Progress persists between missions"). A partial-success mission banks its
# completed rounds here so a follow-up needs fewer (s56.16.5b duration minus this).
@export var ritual_rounds_completed: int = 0

# Retreat/Failure stir the overlap up for one season (s56.16.5f): the season
# (TimeSystem absolute) through which the intensity spike persists. -1 = none.
@export var intensity_spike_until_season: int = -1
