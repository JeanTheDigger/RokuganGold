class_name AncestorRecord
extends Resource
## Lightweight historical record for grandparents (Generation 3) and
## great-grandparents (Generation 4) per GDD s22.6.
##
## G3/G4 ancestors are usually deceased and don't need a full
## L5RCharacterData. The biological family web tracks them via these
## records for lineage display, succession queries, and detecting
## cross-clan-marriage relatives.
##
## Living G3 ancestors should be kept as full L5RCharacterData (they
## still act in the world). AncestorRecord is for static historical
## recordkeeping after death — or when the ancestor was never simulated.

@export var ancestor_id: int = -1     # Unique within the world's ancestor pool.
@export var name: String = ""
@export var clan: String = ""
@export var family: String = ""

# 3 = grandparent, 4 = great-grandparent. Any other value indicates a
# misclassified record.
@export var generation: int = 3

@export var ic_year_born: int = -1
@export var ic_year_died: int = -1    # -1 if still living, otherwise year of death.

@export var spouse_name: String = ""

# Names of known children, recorded for lineage display only. The actual
# parent linkage to descendants is via L5RCharacterData.mother_id /
# father_id and AncestorRecord.maternal flag — names are flavor.
@export var children_names: Array[String] = []

# True if the ancestor is on the mother's side, false if paternal side.
# Used for lineage-side queries (e.g. "show maternal grandparents").
@export var maternal: bool = false


func is_living(current_ic_year: int) -> bool:
	if ic_year_died < 0:
		return true
	return current_ic_year < ic_year_died
