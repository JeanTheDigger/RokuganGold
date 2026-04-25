extends RefCounted
class_name CanonSystemData

# Canon star systems used to populate the Galaxy map.
#
# How to add a new system entry:
# 1) Add a new dictionary to SYSTEMS in alphabetical order by system_name.
# 2) Set system_name, region, and position for the system's galactic coordinates.
# 3) Add one or more planet dictionaries inside planets (name + planetary_type + optional moons).
# 4) Optionally add stars for binary systems in stars, and list hyperspace lanes in lanes.

const SYSTEMS: Array[Dictionary] = [
]
