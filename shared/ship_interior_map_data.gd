class_name ShipInteriorMapData
extends AsciiMapData
## s57.43 Ship Lesser Zone map data.
## A vessel underway (or docked) that carries a player character materializes as
## a SHIP_INTERIOR Lesser Zone with its own ASCII map (s57.43.2). The deck/cabin/
## hold layout is generated deterministically from ship_id + ship_class.
##
## The map footprint is the ship's deck sized by class; a one-tile WATER_DEEP
## margin surrounds it (the sea beyond the rail — "every map edge is water",
## s57.43.1). Rigging climb, quarterdeck elevation, wet-deck penalties, and the
## brazier Bo-Hiya mechanic are s40-combat effects; the anchors below carry the
## positions so the play layer can apply them when s40 individual combat is live.

# -- Identity (the deterministic seed source, s57.43.2) -----------------------

@export var ship_id: int = -1
@export var ship_class: int = Enums.ShipClass.KOBUNE

# The ship's deck footprint within the surrounding water margin (map-local tiles).
@export var deck_rect: Rect2i = Rect2i()

# -- Metadata anchors (mechanics deferred to s40 individual combat) ------------

# Climbable rigging positions near the mast (Athletics/Strength TN 10, one tile
# up per Simple Action; grants Higher attack bonus + 5 Armor TN vs ranged).
@export var rigging_tiles: Array[Vector2i] = []

# Elevated quarterdeck tiles (+1k0 attack vs the main deck below); also raised to
# elevation layer 1 on the base grid so the s4.4 Z-axis high-ground bonus applies.
@export var quarterdeck_tiles: Array[Vector2i] = []

# Deck-mounted fire pots for lighting Bo-Hiya fire arrows (must be adjacent + a
# Simple Action; extinguished and unrelightable in Storm/Typhoon weather).
@export var brazier_tiles: Array[Vector2i] = []

# The captain's default standing position (quarterdeck on ships that have one,
# else the main deck), per s57.42.2 / s57.43.4.
@export var captain_tile: Vector2i = Vector2i(-1, -1)

# Whether this class has an enclosed cabin (below-deck play space).
@export var has_cabin: bool = false
