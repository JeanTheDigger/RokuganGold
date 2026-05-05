**ROKUGAN**

*A Godot Engine Game*

Game Design Document

# 1. Project Overview

## 1.1 Concept

Rokugan is a multiplayer persistent-world RPG set in the Emerald Empire of Legend of the Five Rings, built on the L5R 4th Edition rules system. Players take on the roles of samurai — courtiers, bushi, shugenja, or monks — within a living feudal world that advances with or without them.

The game operates on two interconnected layers. At the macro level, a living World Map simulates all of Rokugan: Great Clan territories, armies, rice yields, political relationships, and the creeping threat of the Shadowlands. Clan AIs pursue their own agendas — expanding borders, forging alliances, waging war — and the world’s balance of power shifts continuously through seasonal cycles. The World Map runs behind the scenes as the simulation layer. Players can open a visual map as a reference tool to see provinces, sub-tiles, army positions, and strategic information, but all player actions happen through two interfaces: a MUD-style text interface for zone navigation and orders, and an ASCII tactical map for combat, investigation, and face-to-face interaction.

Characters are persistent and irreplaceable. Named NPCs — canonical figures from L5R lore and procedurally generated samurai filling every other role — live, age, pursue objectives, and die permanently. When a powerful character is gone, the world does not simply produce another. Players share this world simultaneously, with clan AI filling any roles left vacant by human players.

The game is designed around a core tension the L5R setting makes explicit but rarely mechanises: the samurai caste’s public contempt for commerce and politics sitting atop an infrastructure of rice production, population management, and court maneuvering that determines who actually holds power. Honor is real — it opens doors, closes them, and can destroy a career — but so is ambition, and the two are rarely reconciled cleanly.

## 1.2 Genre & Platform

- Genre: Persistent-World Multiplayer RPG / Grand Strategy. Text-based with ASCII tactical maps.

- Platform: PC (Godot 4)

- Perspective: MUD-style text interface for zone navigation and orders. ASCII tile map (top-down) for tactical combat, exploration, and direct interaction. Visual World Map as a strategic reference layer.

## 1.3 Theme & Tone

**LOCKED:** The game is built around the central tension of the L5R setting: the samurai caste’s public devotion to honour, duty, and the Celestial Order sitting atop an infrastructure of rice production, population management, political manoeuvring, and personal ambition that determines who actually holds power. Honour is real — it opens doors, closes them, and can destroy a career — but so is ambition, and the two are rarely reconciled cleanly. The tone is political intrigue layered over military strategy, spiritual obligation, and personal drama. The supernatural is not fantasy spectacle — it is rooted in Shinto, Buddhist, and Rokugani cosmology. The Fortunes are real. The spirit realms bleed through when worship fails. Maho corrupts from within. The Shadowlands press from without. The world should feel authentically Japanese — not Western fantasy with a coat of paint.

