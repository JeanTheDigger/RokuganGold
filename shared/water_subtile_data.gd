class_name WaterSubtileData
extends Resource
## One node in the world water-movement graph per GDD s11.9 (river / lake / coastal
## / ocean sub-tiles; "N real days per sub-tile" by ship class). Ships and named
## vessels move sub-tile to sub-tile along this graph.
##
## This is the SCHEMA. The actual sub-tile instances, their adjacency, and which
## provinces (ports) connect to which sub-tile are LOCATION DATA to be populated
## when the precise world-map coordinates exist — `water_subtiles` starts empty and
## the whole naval movement engine is inert until it is filled. Caller owns all
## mutation; this is a plain data container.


@export var subtile_id: int = -1

## WaterSubtileType enum (RIVER / LAKE / COASTAL / OCEAN) — gates which ship
## classes may traverse it (NavalSystem.can_traverse) and the deep-ocean loss rule.
@export var water_type: int = Enums.WaterSubtileType.COASTAL

## Adjacent water sub-tile ids (the movement graph edges). Bidirectional adjacency
## is the caller's responsibility to keep symmetric when populating.
@export var adjacent_subtile_ids: PackedInt32Array = PackedInt32Array()

## Province ids that dock at this sub-tile (a coastal/river port). A ship voyaging
## to a province departs/arrives at one of its port sub-tiles. Empty = open water,
## no docking.
@export var port_province_ids: PackedInt32Array = PackedInt32Array()
