# 56. Quest System --- ASCII Map Mission Generation --- LOCKED

This section defines the Quest System: the pipeline that translates world-state conditions into playable ASCII map missions for player characters. The Quest System is not a standalone content generator. It is a translator. The living world simulation creates the conditions (insurgencies, military objectives, spirit manifestations, criminal activity). The NPC Objective System (Section 18) assigns characters to respond. The Quest System takes those inputs and produces a procedurally generated ASCII map environment with enemies, objectives, and consequences that feed back into the World Map.

**Core Design Principle:** Every ASCII map mission is a physical manifestation of a world state. The simulation creates the condition. The quest system translates it into a playable space. If the condition does not exist in the world, the content does not exist for the player. No random dungeons. No spawning a cave full of enemies because the player needs something to do. If the player has nothing to do, the province is well-governed, and that is a success state, not a content drought.

**Cross-Reference:** Section 4.4.2 (ASCII Map Interface), Section 11.11 (Insurgency System), Section 18 (NPC Objective System), Section 54 (Bestiary), Section 55 (NPC Decision Engine).

