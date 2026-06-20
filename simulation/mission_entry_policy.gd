class_name MissionEntryPolicy
## Per-seed-type mission entry classification (GDD s56.19, owner-approved 2026-06-06).
## Pure simulation class — no Node inheritance.
##
## Decides how a PC enters an ASCII-map mission for a given quest seed:
##   AUTO             — the threat comes to the PC or erupts where they stand
##                      (unavoidable; the mission launches on contact/arrival).
##   PLAYER_INITIATED — a known, located threat the PC chooses to assault
##                      (the mission launches only when the player commits to it).
##
## Seed type ints are defined by RosterCompositionSystem (MAHO_CULT=0 … WALL_SORTIE=100)
## and QuestSeedSelector (ONI_MANIFESTATION=101, ROAD_ENCOUNTER=102). Values do not
## collide across the two namespaces.
##
## LOCKED table (s56.19):
##   AUTO             : ROAD_ENCOUNTER, RONIN_BANDIT, ONI_MANIFESTATION, TAINT_MANIFESTATION,
##                      SPIRITUAL_OVERLAP (s56.16 — the realm erupts where the PC stands)
##   PLAYER_INITIATED : MAHO_CULT, URBAN_CRIMINAL_NETWORK, NEZUMI_INFESTATION,
##                      PEASANT_REVOLT, WALL_SORTIE

enum EntryMode { AUTO, PLAYER_INITIATED }


## Returns the entry mode for a quest seed type. Unknown seed types default to
## PLAYER_INITIATED — the safe choice (an unrecognized seed never auto-launches
## combat without the player committing to it).
static func entry_mode_for(seed_type: int) -> EntryMode:
	match seed_type:
		RosterCompositionSystem.SEED_RONIN_BANDIT, \
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION, \
		QuestSeedSelector.SEED_ONI_MANIFESTATION, \
		QuestSeedSelector.SEED_ROAD_ENCOUNTER, \
		QuestSeedSelector.SEED_SPIRITUAL_OVERLAP:
			return EntryMode.AUTO
		_:
			return EntryMode.PLAYER_INITIATED


## True if the seed auto-launches its mission on contact/arrival.
static func is_auto(seed_type: int) -> bool:
	return entry_mode_for(seed_type) == EntryMode.AUTO


## True if the seed's mission launches only when the player commits to it.
static func is_player_initiated(seed_type: int) -> bool:
	return entry_mode_for(seed_type) == EntryMode.PLAYER_INITIATED
