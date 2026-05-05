# 10. To Do List

*Items below are flagged for elaboration — either incomplete sections, identified design gaps, or elements that need revisiting. Items marked ✓ DONE have been fully designed in later sections. Last updated to reflect design sessions through March 2026.*

**PRE-RELEASE AUDIT NOTE:** Several lists in this document are structural frameworks that will need a dedicated completeness audit before release. These include: the Tier 4 Topic category list (Personal, Political, Military, Supernatural, Economic — all sub-entries should be reviewed to ensure every meaningful in-game event type is covered); the historical and temporary disposition modifier tables (new event types will emerge during development and testing that are not yet listed); the crisis type list in Section 16.3 (explicitly flagged as in-progress); and the clan-to-clan baseline modifier table (deferred, needs a dedicated design session). Schedule a full GDD audit pass approximately 3 months before release to catch anything added during development that was not reflected in the design document.

## 🔴 High Priority — Mechanics

- ☒ DONE — Autumn event sequence fully defined: Harvest tick → Rice consumption → Starvation check → Tax cascade → Population adjustment → Iron production → Koku generation. Monthly Koku distribution and stipends fire at each month boundary. (Section 4.3.5)

- ☒ DONE — Loyalty/unrest event triggers defined at all three starvation stages: Shortage (+1 unrest, Tier 4 topic), Hunger (+3 unrest, −5 disposition, Tier 3 crisis), Famine (+10 unrest/season, −0.5 Honor/season, PU absorption risk). (Section 4.3.6)

- ☒ DONE — Combat event defined for peace bonus: any battle, successful raid, siege beginning, or hostile military unit moving through the province. Adjacent battles, failed raids, friendly passage, and minor banditry do not count. (Section 4.3.6)

- ☒ DONE — Individual character stipend amounts by feudal position defined (Section 4.3.9)

- ☒ DONE — Consequences for reduced/no stipend defined (Section 4.3.9)

- ☒ DONE — Arms market prices locked in Section 4.3.10: Peasant Levy 0.4 Koku/PU, Ashigaru 1.5 Koku/PU, Bushi Retainer 3.0 Koku/PU, Elite Samurai 7.0 Koku/PU. Raw Iron market price 0.8 Koku/unit. (Section 4.3.10)

- ☒ DONE — Combat effectiveness penalty per Arms degradation tier: Iron upkeep failure stat penalties defined (Attack −2/−4, Defense −2/−4, Morale −4/−8, Morale Defense −2/−4 after 1/2 consecutive seasons without upkeep). No separate Arms degradation tier system — Iron upkeep failure is the degradation mechanic. (Section 4.3.10)

✓ DONE — Location modifiers for Koku generation fully defined. See Section 4.3.8.

✓ DONE — Garrison costs and size requirements fully defined. See Section 4.3.11.

✓ DONE — Ronin hiring costs, availability, and pool size fully defined. See Section 4.3.11.

## 🟡 Medium Priority — Mechanics

- ☒ DONE — Maximum levy percentage: Tiered system. 0–50% safe (no additional penalty). 51–65% warning (−5 Stability immediately). 66–80% dangerous (−10 Stability immediately, −3/season while levied, −0.3 Honor). Above 80% desperation (−20 Stability immediately, −7/season while levied, −1.0 Honor). No hard ceiling — consequences are catastrophic, not blocked. (Section 4.3.19)

- ☒ DONE — Samurai unit upkeep rates defined in Section 4.3.19: Rice 0.35/season, Iron upkeep per Section 4.3.10 table (Bushi Retainer 0.20/season, Elite Samurai 0.40/season), ongoing Koku stipend.

- ☑ DONE — Define relationship between samurai units and lord/player character system (Section 4.3.19)

- ☒ DONE — Define garrison size requirements per settlement type: village (no garrison), town (0.5 PU), castle (1 PU) (Section 11.7)

- ☒ DONE — Criminality/banditry malus values: Three stacking effects while under-garrisoned: trade route Koku drain (−0.05/season per season, cap −0.3); Rice stockpile slow drain (−0.05 Rice/season); named character movement risk (15% random encounter check per province, negated by 1.0 PU escort). (Section 4.3.11)

- ☒ DONE — Design the disposition system: full system designed including scale, thresholds, modifiers, and court effects (Section 12.2)

- ☑ DONE — Define full Kami domain list and map each domain to a specific game mechanic (Section 4.3.21)

- ☒ DONE — Ritual/worship system fully designed in Section 4.3.21. Active worship via PERFORM_WORSHIP, Shugenja Divination rolls, WP thresholds, seasonal reset.

- ☒ DONE — Great Fortune malus table (three tiers: Restless/Displeased/Wrathful) and Minor Fortune bonus tiers (three tiers: Noticed/Favored/Beloved) fully defined in Section 4.3.21.

- ☒ DONE — Clan worship tendencies emerge from the NPC engine — PERFORM_WORSHIP and PERFORM_RITUAL NeedTypes, personality leans toward specific Fortunes, and Shugenja Divination driving directed worship decisions. No separate clan tendency table needed.

- Policy System — REMOVED. Covered by existing systems (resource allocation, court actions, objectives, favor/intimidation, War Status System).

- ☒ DONE — Honor and Glory interaction with political actions fully designed in Section 4.6. Full event table, timing (immediate), visibility (Honor private/discernible at TN 30, Glory public), Honor as court credibility (Free Raises at Rank 5+, additional Raises required at Rank 2 or below). All court action gains and losses locked. (Section 4.6)

- ☒ DONE — Design Winter Court as a distinct political season: fully designed in Section 15

- Design fixed bonus system for named significant locations on the World Map (Section 4.3.12)

- Design clan-level territorial bonuses and maluses on the World Map (Section 4.3.12)

- ☒ DONE — Design the lord personality system: Bushido + Shourido virtue system fully designed (Section 19)

- Design the ☒ DONE — Investigation/audit system: Commerce (Mathematics) + Intelligence vs TN 20. Failure: no find, vassal aware, +5 TN rest of year. Success: one irregularity. +1 Raise: formal accusation, Tier 3 Betrayal topic. +2 Raises: full exposure, Tier 2 secret. Three passive detection signals. (Section 4.3.7)

- ☑ DONE — Design unique unit types per clan: full Clan Elite Unit Roster designed with stat blocks, specials, cost tiers (Baseline/Specialized/Elite), and design notes for all seven Great Clans plus Mantis (Section 11.6)

- ☑ RESOLVED — Design full goods locality & movement system (Section 4.3.14) — no physical transport layer; adjacency markets, Supply Tether, and banditry drain cover all use cases.

- Playtest and tune terrain and mine quality modifier values (Section 4.3.4 & 4.3.10)

- Define ☒ DONE — Samurai retinue Rice consumption: 0.35 Rice/season regardless of activity. Levied peasant: 0.35 Rice/season consumption, 0 production while levied, net swing −1.50 Rice at Autumn if levied before Spring planting. (Section 4.3.16)

- ☒ DONE — AI desperation threshold: All Red on Feasibility Ledger triggers desperation flag. Desperation flag allows the AI to pursue options it would otherwise refuse — defined in Phase 2 Alternative Ladder. (Section 4.3.17)

- ☒ DONE — Players can destroy harvests and blockade trade routes. Fully designed in Section 4.3.17 Phase 4. Harvest destruction: −2.0 Honor, −0.5 Glory, −20 disposition targeted clan (permanent), −10 all others, Tier 2 crisis generated, Imperial Edict risk. Blockade: −0.5 Honor/season, triggers War Status Tier 3. Personality gates for all Bushido/Shourido types defined. Permanent terrain degradation explicitly not permitted. (Section 4.3.17)

- ☑ RESOLVED — Design the trade route map (Section 4.3.18) — adjacency model replaces explicit route map. Provinces trade with neighbours unless blocked by War Status or disruption.

- ☒ DONE — Rice Market System: Decentralised individual-lord pricing mirroring Iron system. Surplus decision (stockpile/sell/share). Disposition-based purchase priority. Price rises +0.25 Koku/season when demand active, falls −0.25 when unsold, floor 0.25 Koku. Intra-clan sharing generates Honor (0.1–1.0 scale by severity) when recipient at Shortage or worse. Trade route map remains a dedicated design session. (Section 4.3.18)

- ☒ DONE — Design political spending costs — gift-giving system designed in Section 12.3, court action costs in Section 15.4

- ☒ DONE — Iaijutsu duel flowchart: Three rounds. Assessment (Iaijutsu/Awareness vs Insight Rank ×5+10, reveals 6 pieces of info, +1k1 Focus bonus if beat by 10+). Focus (Contested Iaijutsu/Void, winner by 5+ strikes first with Free Raises). Strike (Iaijutsu/Reflexes vs Armor TN, first blood or death rules, Kharmic Strike if neither won Focus). Honor/Glory outcomes table. Optional stare-down. (Section 4.8.1)

- ☒ DONE — Honor & Glory court event table fully designed in Section 4.6. Full table covering Glory gains/losses and Honor gains/losses for all court actions, with immediate application timing.

- ☒ DONE — Honor/Glory visibility resolved in Section 4.6. Honor is private (discernible via Lore: Bushido/Awareness TN 30). Glory is public by definition.

- ☑ DONE — Define wound level visual representation on ASCII map (Section 4.5.3). Look command displays wound level, penalties, and status on selection.

- ☑ DONE — Design mode transition triggers and UX — MUD, ASCII, World Map (Section 4.4.3). Seamless UX details deferred to implementation.

- ☒ DONE — FOV / Fog of War: Perception-radius circle centered on character. Base radius = Perception Trait in tiles. Environmental modifiers: clear −0, overcast/dusk −1, heavy rain/fog/indoor −2, night/underground −3, supernatural −4. Minimum radius 1. Walls block within radius. Stealth still requires contested roll. No shared vision in multiplayer. (Section 4.4.2)

- ☑ DONE — Determine mass combat system and link to ASCII skirmish (Section 11.7). Full Battle Table System, Battlefield Bubble, 34 Heroic Opportunities, 37 individual soldier stat blocks.

- ☑ DONE — Curate starting School roster (Section 4.8.3). Full canon roster at launch — all Great Clan, Imperial, Mantis, Minor Clan, Ronin, Brotherhood, and miscellaneous schools. See Section 29.

- ☑ DONE — Design social check triggers on ASCII map (Section 4.5.5). Social Menu with target selection on ASCII map; MUD view for non-spatial social actions.

## 🟢 Lower Priority — Mechanics

- ☒ DONE — Full spell list already present in Section 32 (master spell compendium). All elements covered including Universal spells, Air, Earth, Fire, Water, Void, and Maho. Section 4.8.2 casting mechanics locked. No additional design needed.

- ☑ RESOLVED — Define Clan AI simulation depth for World Map (Section 4.2.2). Fully emergent — no separate Clan AI. NPC Decision Engine (Section 55) on all named characters produces clan behavior.

- ✅ RESOLVED — All 10 Traits tracked individually. Rings derived as minimum of their two Traits per L5R 4e RAW. Character sheet (Section 22.3) stores each Trait separately.

## 🔵 Lore / Narrative — Deferred

- ☑ DONE — Define game concept, genre, and tone (Section 1.1–1.3)

- ☑ DONE — Write world overview for the Emerald Empire (Section 2.1)

- ☑ DONE — Fill in all 7 Great Clan entries (Section 2.2)

- ☑ IN PROGRESS — Define key locations (Section 2.3). Settlement type vocabulary and infrastructure list defined (v533). Terrain reconciliation (v534). Crab Clan province entries begun (v535): Hida (5), Kaiu (3), Kuni (2) provinces written. Yasuki (2) and Toritaka (1) added (v536). All 13 non-Hiruma Crab provinces complete. Hiruma (3) added as ungovernable beyond-Wall territory (v537). All 16 Crab provinces complete. Crane Clan provinces added (v538): 16 provinces across 4 families. Dragon Clan provinces added (v539): 10 provinces across 4 families. Phoenix Clan provinces added (v540): 19 provinces across 4 families. Lion Clan provinces added (v541): 23 provinces across 4 families. Scorpion Clan provinces added (v543): 12 provinces across 4 families. Unicorn Clan provinces added (v544): 18 provinces across 5 families. Mantis Clan provinces added (v545, Minor Clan): 8 island provinces (Yoritomo family). Sea connections pending travel system rework. Fox Clan province added (v546, Minor Clan): 1 province (Kitsune family). Wasp Clan provinces added (v547, Minor Clan): 5 provinces (Tsuruchi family). Centipede Clan province added (v548, Minor Clan): 1 province (Moshi family). Badger Clan province added (v549, Minor Clan): 1 province (Ichiro family). Boar Clan territory added (v550, Historical — Destroyed): 1 province (Heichi family ruins). Dragonfly Clan province added (v551, Minor Clan): 1 province (Tonbo family). Hare Clan province added (v552, Minor Clan): 1 province (Usagi family). Monkey Clan province added (v553, Minor Clan): 1 province (Toku family). Oriole Clan territory added (v554, Minor Clan): 1 province (Tsi family, adjacencies pending). Ox Clan province added (v555, Minor Clan): 1 province (Morito family). Sparrow Clan province added (v556, Minor Clan): 1 province (Suzume family). Tortoise Clan province added (v557, Minor Clan): 1 province (Kasuga family, adjacencies pending). Settlements and sub-tile subdivisions pending.

- ☑ DONE — Define Shadowlands' role in story and systems (Section 2.4)

- Write story synopsis and define player character (Section 3.1–3.2)

- Design main NPCs (Section 3.3)

- Outline story structure, branches, and endings (Section 3.4–3.5)

- Define MVP / vertical slice scope (Section 8.1–8.3)

## 🟣 New — Systems Designed Since Initial To Do List

- ☒ DONE — Army Combat System: full CK2/Victoria II style system with unit stats, commander bonuses, terrain modifiers, rout system (Section 11.7)

- ☒ DONE — Siege Mechanics: starvation, storm assault, sortie, Honor cowardice threshold (Section 11.7)

- ☒ DONE — Supply Tether System: invisible tether, deprivation cascade, supply source hierarchy (Section 11.7)

- ☒ DONE — Time System: 1 tick = 6 real hours = 1 IC day, narrative time decoupled from mechanical time, Bubble Time for scene-based RP (Section 13)

- ☒ DONE — Action Point System: 2 AP per in-game day (Morning / Afternoon), 8 per real-world day, flat pool (Section 14, updated Section 48)

- ☒ DONE — Court System: three court types, resolution and commitment system, multi-party persuasion (Section 15)

- ☒ DONE — Court Action Menu: five categories fully elaborated with rolls, outcomes, and objective alignment system (Section 15.4)

- ☒ DONE — Topic & Momentum System: crisis tiers, momentum scale, personal relevance scores (Section 16)

- ☒ DONE — Crisis Types: Shadowlands Incursion, Maho Cult, Oni Manifestation, Clan War, Famine designed (Section 16.3)

- ☒ DONE — Personal Visits System: three visit types, available actions, intimate setting bonus deferred (Section 17)

- ☒ DONE — NPC Objective System: framework confirmed, full design deferred (Section 18)

- ☒ DONE — Personality System: Bushido and Shourido virtues defined with decision-making profiles (Section 19)

- ☒ DONE — Secret System: Fully designed in Sections 12.8 and 12.9. Covers secret data structure, physical proof, severity tiers (Tier 1 existential through Tier 4 minor), covert acquisition methods (Bribery, Eavesdrop, Letter Interception, Search Quarters/Pickpocket), fabrication mechanics, NPC decision logic, clan baselines, reputation consequences, Blackmail, Private Intimidation, Public Intimidation, and Compliance Tracker.

- ☒ DONE — Insurgency System: Seven types (Maho Cult, Peasant Revolt, Ronin Bandit Uprising, Province Taint Manifestation, Nezumi Infestation, Urban Criminal Network, Pirate (Wako) Fleet), Province Stability scale, Province Taint Level system (PTL 0–10), shared five-phase lifecycle, gameplay hook as ASCII map dungeon content. Urban Criminal Network is a settlement-level insurgency spawned by commerce and settlement size, not Stability. (Section 11.11)

- ☒ DONE — Named Character Generation System: character sheet (22.3), generation templates (22.4), world population system (Section 52)

- ☒ DONE — Clan Elite Unit Roster: All seven Great Clans plus Mantis fully designed with stat blocks, three cost tiers (Baseline/Specialized/Elite), special abilities, and army identity notes. (Section 11.6)

- ☒ DONE — War Status System: War Score, escalation chain, honor stakes, peace willingness, mechanical effects (Section 53)

- ☒ DONE — War Justification & Casus Belli: objective-to-war mapping for all standing and primary objectives, three-tier military action framework (Raid/Formal War/Total War), personality-driven aggression with province-level and clan-level weakness conditions, full 5-step decision sequence. (Section 53)

- ☒ DONE — Assassination and Succession Dispute: Succession System fully designed in Section 22.5 (succession order, confirmation authority, transition period with tax/Koku/vassal/army cascade effects, clean vs. disputed succession, Succession Dispute as Tier 2 crisis). Heir Evaluation and Designation system with nine weighted factors, personality-driven weight modifiers, topic-based achievement scoring, and re-evaluation triggers. Assassination cross-reference and Magistrate System Interface Contract in Section 12.8.

- ☒ DONE — Tier 3 crisis list: Border Raid, Provincial Famine, Criminal Organization, Trade Route Disruption, and Minor Clan Dispute — all fully designed with court commitments, end conditions, and inaction consequences. (Section 16.3)

- ☒ DONE — Artisan and Crafting System: quality tiers, provenance, history accumulation, discovery mechanics (Section 49)

- ☒ DONE — Intimidate Compliance/Pressure Tracker: Fully designed in Section 12.9. Compliance tracked separately from genuine position. Three contexts: Blackmail, Private Intimidation, Public Intimidation. Compliance ends when pressure expires, leverage removed, target resists, or actor’s disposition crosses into Friend range.

- ☒ DONE — NPC Objective System: Full design completed in Sections 18.1–18.9. Two objective types (Standing/Primary), full objective lists (Political, Military, Economic, Personal), generation weights, assignment via AP or letter, change triggers, system interactions, negligence and betrayal consequences.

- ☒ DONE — Favor System: Fully designed in Section 12.10. Two types (Specific/General), three tiers (Minor/T3, Moderate/T2, Major/T1), disposition values by tier, expiration rules, gift distinction, calling-in mechanics (letter/court/personal visit), breaking consequences by tier, inheritance of Major Favors by designated heir.

- ☒ DONE — Court Priority System: Fully designed in Section 15.8. NPC decision logic (primary objective first, personal relevance tiebreaker), proxy strategy, sequential courts, early departure costs, objective negligence connection.

- ☒ DONE — Player Reaction Menu: Fully designed in Section 14.2. Three categories: Requires Response (duel challenge, favor called in, proxy mandate, new objective, court RSVP), Requires Presence (active court, battle assignment), Notification Only. Response windows and default consequences for all Category 1 items.

- ☒ DONE — Inventory System: Three storage tiers (on person, current quarters, home storage), five item categories, slot-based capacity by outfit type, item transfer mechanics, interaction with covert acquisition and gift-giving. (Section 12.11)

- SCENARIO-DEPENDENT — Clan-to-Clan Baseline Modifier Table: Numeric values for all 28 Great Clan pairings will be set per scenario at game start. Narrative relationship descriptions per clan are documented in the Named Character System (Section 22). Full numeric table to be authored as part of each scenario’s setup parameters, not as a universal default.

- PARTIAL #x2014; Secret Severity Tier Classification List: Four-tier framework fully locked with all damage values, Honor/Glory costs, and Infamy modifiers (Section 12.8). Pending: full classification list mapping every topic type to a tier. This is a pre-release audit task, not a design task #x2014; the mechanics are complete.

- ☒ DONE — Honor Benefits Outside Court: The Strength of Honor (Section 32) provides Honor Rank as a flat bonus to resist intimidation (Section 12.9), insurgency defection (Section 11.11), Maho cult recruitment (Section 11.11), and all Temptation rolls. Honor thresholds gate NPC covert method use (Section 12.8). Honor Rank weighted in heir evaluation (Section 22.5). Court credibility in Section 4.6.

## ⚙️ Design Gaps / Flagged Issues

*Items added here as design flaws or contradictions are identified during development.*

