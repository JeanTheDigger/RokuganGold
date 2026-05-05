# 47. Mass Battle Rules

This section defines the complete rules for Mass Battle — the large-scale military conflict system that governs army-level engagements across Rokugan. Mass Battle is distinct from individual combat (Section 40). Individual characters fight within the context of a Mass Battle, but the outcome of the battle itself is resolved through the army-level mechanics described here. This mirrors the L5R 4th Edition tabletop Mass Battle system: the battle is largely automated, but player characters have Heroic Opportunities that let them personally influence the outcome.

**OVERVIEW: THE TWO BATTLE VIEWS**

A Mass Battle is resolved simultaneously across two views that run in parallel:

- Army View (Mass Battle): Companies (Kaisha) are the basic tactical pieces. Players with Warlord or Commander roles see and maneuver individual Companies on a battlefield grid. The battle is complex by design — massive battles are messy, chaotic, and difficult to manage.

- ASCII Map View (Individual Combat): Player characters and named NPCs fight as individuals within the battle, operating inside the larger mass battle context. Their actions generate Heroic Events that apply modifiers to the Army View resolution.

Both views resolve in the same session. The Army View determines the battle’s outcome. The ASCII Map view determines individual glory, heroic contributions, and narrative events.

**ARMY STRUCTURE ****&**** COMMAND HIERARCHY**

Every army is organized into a strict hierarchy. Each level is commanded by a named, persistent character. Anonymous soldiers exist below the Gunso threshold.

- Hohei (Private): Individual soldier. Anonymous. No persistent identity. The mass of any army.

- Gunso (Sergeant): Commands a Squadron (Guntai) of 20 soldiers. NAMED — lowest threshold for persistent characters.

- Chui (Lieutenant): Commands a Company (Kaisha) of approximately 153 troops (7 squadrons + command staff). NAMED. The Company is the base unit of the Army View battlefield. Bonus applies to their Company only.

- Taisa (Captain): Commands a Legion (Daibutai) of approximately 750 troops (6 companies + 1 reserve company). NAMED. Bonus applies to every Company in their Legion.

- Shireikan (Commander): Oversees 4–12 legions. NAMED. Bonus applies to every Company across their assigned Legions.

- Rikugunshokan (General): Commands an Army (Go-hatamoto) of up to 48 legions. NAMED. Bonus applies to every Company in the entire army.

**COMMANDER BONUSES**

Every named commander from Chui upward provides a passive bonus to all Companies under their authority. Bonuses from multiple commanders stack — a Company simultaneously benefits from their Chui’s bonus, their Taisa’s bonus, and the Rikugunshokan’s bonus.

Bonus Value: Equal to the commander’s Battle skill rank (1–10).

Bonus Type: Determined by the commander’s highest Ring:

- Earth Ring: +Defense to all affected Companies.

- Fire Ring: +Attack to all affected Companies.

- Air Ring: +Defense to all affected Companies.

- Water Ring: +Attack to all affected Companies.

- Void Ring: +Morale bonus equal to Battle skill rank to all affected Companies.

Example: A Rikugunshokan with Battle 5 and highest Ring Earth gives every Company in the army +5 Defense. A Taisa under him with Battle 3 and highest Ring Fire gives every Company in his Legion an additional +3 Attack. A Company in that Legion benefits from both bonuses simultaneously.

When the highest-ranking commander present on a side is killed, the entire army suffers a Morale hit equal to 2 + the fallen commander’s Battle rank, and loses their passive bonus immediately. The battle continues — the army does not instantly collapse — but losing a high-Battle Rikugunshokan mid-battle can swing the outcome dramatically.

**COMPANY (KAISHA) STATS**

The Company (Kaisha) is the base unit of the Army View battlefield. Each Company has five stats. All stats use a 1–10 scale for Attack, Defense, Morale, and Morale Defense—matching the 1d10 attack roll. Health is tied directly to manpower—a standard Company of 153 troops (7 Squadrons + Gunso commanders + Chui) starts at 153 Health. No shields exist in Rokugan—Defense represents armor quality, training, and formation discipline only. See Section 11.7 for the full authoritative stat blocks.

- Attack: Offensive capability. Added to the 1d10 attack roll. Modified by the Chui’s stat bonus (if Fire Ring), terrain, flanking, player Heroic Events, and unit type matchups.

- Defense: Resistance to incoming attacks. Reduces damage from successful enemy hits. Modified by commander Earth Ring bonus and terrain cover.

- Morale: Current psychological cohesion. Starts at the Company’s base Morale value. Degrades through Morale damage events. If Morale reaches 0, the Company routs.

- Morale Defense: Resistance to Morale damage. Acts as a buffer against psychological shocks. High Morale Defense means the Company is harder to break through fear and attrition.

- Health: Manpower pool, directly tied to Company size. A standard Company starts at 153. Depletes as casualties are taken. Zero Health = Company destroyed. Health loss also triggers Morale checks (see below).

**STANDARD COMPANY TYPES ****&**** BASELINE STATS**

The authoritative unit stat blocks are defined in Section 11.7 and are reproduced here for reference. All values are as defined there — Section 11.7 is the master source.

Universal units (all clans): Peasant Levy (H:153 A:1 D:1 M:8 MD:1), Ashigaru Spearmen (H:153 A:3 D:4 M:12 MD:3, +3 Attack vs Cavalry), Ashigaru Archers (H:153 A:4 D:2 M:10 MD:2, −3 Attack in melee), Bushi Retainer (H:153 A:6 D:5 M:18 MD:8), Light Cavalry (H:153 A:3 D:2 M:11 MD:4, +4 Attack when flanking, cannot be counter-attacked while flanking), Ronin (H:153 A:5 D:4 M:10 MD:4), Garrison (H:153 A:3 D:5 M:16 MD:7, +2 Defense inside own settlement). Clan-specific elite units: see Section 11.6.

**BATTLE SETUP: DEPLOYMENT ****&**** FORMATION**

Before battle begins, each army deploys its Companies into a battlefield grid. The grid is determined by the terrain of the sub-tile where the two armies meet (see Terrain section below). Each army deploys in two rows: a Forward Row and a Reserve Row. The choice of what to place in each row is the primary pre-battle tactical decision.

Forward Row: Companies in the Forward Row engage immediately on Round 1. They are the first to take damage and the first to generate Morale events. Placing weak units (Ashigaru) in the front to absorb the initial shock while samurai units hold the flanks is a valid strategy.

Reserve Row: Companies in the Reserve Row do not engage in melee on Round 1. They may fire ranged attacks (Archers), hold for commitment (Heavy Cavalry charges), or wait to replace routing Forward Companies. Committing reserves is irreversible — once a Reserve Company moves to the Forward Row it cannot return. The Rikugunshokan or the controlling player chooses when to commit reserves.

Flank Positions: The battlefield grid has flank positions on each side. Placing Light Cavalry or fast units in flank positions enables flanking attacks (see Combat Round below). Flank positions are limited — the terrain type determines how many flank slots are available per side.

IMPLEMENTATION NOTE: The full formation setup screen UI — how players drag and assign Companies to formation slots — is resolved during engine development, pending front-end implementation decisions.

**BATTLE ROUND STRUCTURE**

Each round resolves simultaneously between opposing Companies (per Section 11.7):

- Step 1 — Attack Roll: Both Companies roll 1d10 and add their Attack stat.

- Step 2 — Apply Defense: Subtract the defending Company’s Defense from the attacker’s total. The remainder is Health damage dealt. Minimum 0.

- Step 3 — Apply Health Damage: Reduce each Company’s Health accordingly.

- Step 4 — Morale Check: After Health damage is applied, each Company makes a Morale check influenced by how much Health was lost this round, current Health percentage, and any outstanding effects (flanking, commander death, losing adjacent Companies). If the check fails, Morale drops by a value determined by the severity of the check.

- Step 5 — Rout Check: If Morale hits zero, the Company attempts to rout — fleeing through the nearest unoccupied side. If all four sides are occupied by enemy units, the Company cannot rout and fights to the death until Health reaches zero.

Archer Companies fire ranged support attacks each round at the enemy Company in front of their paired Melee Company, rolling 1d5 + Attack stat. The battle continues until one side has all Companies routed or destroyed.

Player characters may take Heroic Actions each round (see Heroic Events below). Commander Decisions (committing reserves, Rally orders) occur after Morale checks resolve.

**TERRAIN EFFECTS**

Terrain is a property of the sub-tile where the battle takes place. Terrain applies a single modifier—either an attacker penalty or a defender bonus, never both simultaneously. Unit-specific penalties apply on top and affect only that unit type (per Section 11.7).

- Flat Plains: No modifier. Light Cavalry (both sides): +2 flanking bonus on top of their existing special rule.

- Forest: Defender +2 Defense. Light Cavalry (both sides): loses flanking bonus, −2 Attack. Ashigaru Spearmen (both sides): −1 Defense.

- Hills: Attacker −2 Attack. Light Cavalry (attacker only): −1 flanking bonus on top of attacker penalty.

- Mountain: Defender +4 Defense. Light Cavalry (both sides): loses flanking bonus, −3 Attack. Ashigaru Archers (defender only): +1 Attack.

- Urban: Defender +3 Defense. Light Cavalry (both sides): loses flanking bonus, −3 Attack. Ashigaru Spearmen (defender only): +1 Defense. Castle fortification adds a further +5 Defense on top of Urban bonus.

- Coastal/Beach: No modifier for standard land engagements. Amphibious landing attacker only: −3 Attack. Light Cavalry (amphibious attacker): additional −2 Attack, loses flanking bonus.

- Shadowlands: Overlay system — the Shadowlands is not a terrain type. The sub-tile's actual terrain determines the standard terrain modifier. Shadowlands-specific combat effects (Morale Defense penalties, Attack penalties, Taint Attrition Health loss) scale by zone and layer on top. Full specification in Section 11.7 Shadowlands Combat Overlay.

**FLANKING**

Every Company has four sides. A flanking Company attacks an exposed side of an already-engaged enemy (per Section 11.7).

- The flanking Company attacks with +2 Attack. PROVISIONAL. Light Cavalry special: +4 Attack when flanking.

- The flanking Company does NOT receive a counter-attack that round—the enemy is already engaged on another side.

- The flanked Company takes Health damage from both attackers simultaneously and suffers an immediate Morale penalty.

- The flanked Company directs its single counter-attack at whichever of its two attackers has the lower Defense. Exception: Light Cavalry cannot be counter-attacked while flanking regardless of Defense values.

- Complete encirclement (all four sides occupied by enemies): the Company cannot rout. Morale collapses rapidly. The unit fights to the death—a near-certain destruction condition.

**MORALE SYSTEM**

Morale is a parallel pool to Health. A Company that reaches 0 Morale routs. Morale damage is not the same as Health damage—a Company can be at full Health and still rout if its Morale collapses (per Section 11.7).

**Morale Damage Formula:** Roll 1d10 and subtract the unit’s Morale Defense. The remainder is Morale damage dealt. Minimum 0. A Peasant Levy (Morale Defense 1) takes up to 9 Morale damage per check. A Bushi Retainer (Morale Defense 8) rarely takes more than 1 or 2.

**Morale Check Triggers and Modifiers (per Section 11.7):**

- Flanking hit: Roll normally, no modifier.

- Heavy Health loss this round (lost more than 25% of current Health in one round): +2 to the Morale damage roll.

- Low Health (currently below 50% Health): +1 to the Morale damage roll.

- Death of the Company’s Chui: +3 to the Morale damage roll.

- Death of a higher commander (Taisa, Shireikan, Rikugunshokan): +4 to the Morale damage roll for all Companies under that commander’s authority.

- Complete encirclement (all four sides occupied): No roll — automatic 10 Morale damage per round, bypassing Morale Defense entirely. The Company is destroyed when Morale reaches 0. Value PROVISIONAL.

**Routing Contagion:** When a Company routs, all adjacent allied Companies take an immediate Morale damage roll (1d10 − their Morale Defense). This can chain—if an adjacent Company also routs from the contagion, their neighbors are affected in turn. Well-disciplined units (high Morale Defense) resist routing contagion. Peasant Levies are especially vulnerable to cascade collapse.

**Rally:** A named commander (Taisa or above) may spend their action to issue a Rally order to one adjacent routing Company. A Rikugunshokan may Rally any Company in the army. Roll Battle vs TN 15 + Morale Damage total that triggered the rout. On success the Company halts its rout, restores 1 Morale, and may re-engage next Round.

**BATTLE TABLE SYSTEM — INDIVIDUAL CHARACTER EXPERIENCE IN MASS BATTLE**

Every named character participating in a Mass Battle — NPC and player alike — resolves their personal experience through the Battle Table each Battle Turn. The Battle Table determines Wounds suffered, Glory earned, and whether a Duel or Heroic Opportunity is triggered. The Army View (Company-level combat defined above) runs simultaneously and determines the battle’s strategic outcome. The Battle Table determines what happens to individuals within that outcome. Source: L5R 4th Edition Core Book and Sword and Fan.

Resolution path follows the Section 9 design principle. When an NPC’s Battle Table result triggers a Duel or Heroic Opportunity, it resolves through engine dice rolls — the NPC fights, succeeds or fails, takes Wounds, earns Glory, and the modifier feeds to the Army View. No ASCII map generates. When a player character’s result triggers a Duel or Heroic Opportunity, a 20×20 ASCII Battlefield Bubble generates around them and the player resolves the event spatially on the map. Same world state condition, different resolution path depending on who is involved.

**Stage 1 — Declaration**

Each Battle Turn, every character participating in the battle declares their Level of Engagement. Four levels exist, representing how deep into the fighting the character places themselves.

Reserves: The character is positioned well behind the front lines, relatively safe from the fighting. Minimal risk, minimal opportunity. Characters in Reserves can shift to Disengaged next turn.

Disengaged: The character is near the battle but not in direct combat. They can observe, coordinate, and respond to events. Characters who are Disengaged can shift to Reserves or Engaged next turn.

Engaged: The character is in the thick of battle, fighting alongside their unit. Direct combat risk. Characters who are Engaged can shift to Disengaged or Heavily Engaged next turn.

Heavily Engaged: The character is at the very front of the fighting, in the most dangerous position on the field. Maximum risk, maximum opportunity. Characters who are Heavily Engaged can shift to Engaged next turn.

A character can only shift one Level of Engagement per Battle Turn — no jumping from Reserves to Heavily Engaged in a single turn unless a Heroic Opportunity specifically moves them there. A Heroic Opportunity or special circumstance can override this restriction.

**Stage 2 — Determination**

With engagement levels declared and the current Army Status determined (see below), each character rolls on the Battle Table. The roll is: 1d10 + Water Ring + Battle Skill. The total is cross-referenced with the character’s Army Status (Winning, Stalemate, or Losing) and Level of Engagement to determine: how many dice of Wounds the character suffers, how much Glory the character earns, and whether the character encounters a Duel or Heroic Opportunity.

**Army Status — Derived from Army View**

Army Status is derived from the Army View state at the start of each Battle Turn, not from a separate roll. Calculate Army Strength for both sides: Army Strength = total current Health of all non-routed Companies ÷ total maximum Health of ALL Companies (including routed). Compare the two percentages. If your side is 10 or more percentage points ahead: Winning. If your side is 10 or more percentage points behind: Losing. If the difference is less than 10 percentage points: Stalemate.

Routed Companies count against you automatically — they contribute to the denominator (total max Health) but add zero to the numerator (current Health). Armies of different sizes compare fairly through the percentage calculation. Battle start is always Stalemate (both sides at 100%). The 10-point threshold is PROVISIONAL pending playtesting. Design rationale: 10 percentage points means small battles (5–10 Companies) are volatile — one Company loss swings the status. Large battles (20+ Companies) are stable — accumulated damage across many Companies determines the outcome. Routed Companies count against you (zero numerator, full denominator) so routing contagion can collapse Army Status dramatically in a single round. This is historically correct and produces the right dramatic arc.

**The Battle Table**

The table uses a column-offset system. Army Status shifts which columns apply to each Engagement Level. A Winning army reads leftward (safer columns); a Losing army reads rightward (more dangerous columns). The column mapping is:

Winning: Column 1 = Reserves, Column 2 = Disengaged, Column 3 = Engaged, Column 4 = Heavily Engaged. Stalemate: Column 2 = Reserves, Column 3 = Disengaged, Column 4 = Engaged, Column 5 = Heavily Engaged. Losing: Column 3 = Reserves, Column 4 = Disengaged, Column 5 = Engaged, Column 6 = Heavily Engaged.

Roll 1–3: Col 1: 1W, 0G. Col 2: 2W, 0G. Col 3: 3W, 1G. Col 4: 4W, 1G. Col 5: 5W, 1G, Duel. Col 6: 6W, 3G, Heroic Opportunity.

Roll 4–6: Col 1: 1W, 0G. Col 2: 1W, 0G. Col 3: 3W, 1G. Col 4: 4W, 1G. Col 5: 5W, 1G, Duel. Col 6: 5W, 2G, Heroic Opportunity.

Roll 7–9: Col 1: 1W, 0G. Col 2: 0W, 0G. Col 3: 2W, 1G. Col 4: 3W, 1G. Col 5: 4W, 1G, Duel. Col 6: 5W, 1G, Duel.

Roll 10–12: Col 1: 0W, 0G. Col 2: 0W, 0G. Col 3: 2W, 0G, Duel. Col 4: 3W, 0G, Heroic Opportunity. Col 5: 4W, 1G, Heroic Opportunity. Col 6: 4W, 1G, Duel.

Roll 13–15: Col 1: 0W, 1G. Col 2: 0W, 1G. Col 3: 1W, 1G, Duel. Col 4: 2W, 1G. Col 5: 3W, 1G. Col 6: 4W, 1G, Heroic Opportunity.

Roll 16–18: Col 1: 0W, 1G. Col 2: 0W, 1G, Duel. Col 3: 1W, 1G. Col 4: 2W, 1G, Duel. Col 5: 3W, 2G. Col 6: 3W, 2G, Heroic Opportunity.

Roll 19–21: Col 1: 0W, 2G. Col 2: 0W, 2G, Heroic Opportunity. Col 3: 1W, 2G. Col 4: 2W, 2G. Col 5: 3W, 2G, Heroic Opportunity. Col 6: 3W, 2G, Duel.

Roll 22–24: Col 1: 0W, 2G, Heroic Opportunity. Col 2: 0W, 2G. Col 3: 1W, 2G, Heroic Opportunity. Col 4: 2W, 2G. Col 5: 2W, 3G. Col 6: 3W, 3G, Duel.

Roll 25–27: Col 1: 0W, 2G. Col 2: 0W, 2G, Duel. Col 3: 0W, 3G. Col 4: 1W, 3G. Col 5: 2W, 4G, Heroic Opportunity. Col 6: 3W, 4G, Heroic Opportunity.

Roll 28–30: Col 1: 0W, 3G, Heroic Opportunity. Col 2: 0W, 3G, Duel. Col 3: 0W, 4G. Col 4: 1W, 4G, Duel. Col 5: 2W, 5G. Col 6: 3W, 5G, Heroic Opportunity.

W = dice of Wounds (each die is 1k1, rolled against the character’s Wound track as normal). G = Glory points earned this Battle Turn. Duel and Heroic Opportunity trigger Stage 3 Resolution. Characters who do not trigger a Duel or Heroic Opportunity take their Wounds, earn their Glory, and the Battle Turn ends for them. VALUES PROVISIONAL — transcribed from source images, should be verified against the physical book before locking.

**Stage 3 — Resolution**

Duel: The character encounters an enemy of roughly equal skill on the battlefield and the two engage in private combat. Other samurai allow this to play out — interfering is a grievous insult. For NPCs, the duel resolves through a Contested roll using the standard iaijutsu or skirmish rules (Section 4.8.1 / Section 40). For player characters, the duel plays out on the 20×20 Battlefield Bubble as a one-on-one fight against a named enemy combatant.

Heroic Opportunity: The character encounters a dramatic situation on the battlefield — a chance to change the course of the fight at personal risk. The specific opportunity is randomly selected from the eligible pool (see Heroic Opportunity Master List below). The character may decline — but declining typically imposes a penalty on the army’s next Battle Roll. For NPCs, the opportunity resolves through engine dice rolls. For player characters, the 20×20 Battlefield Bubble generates with the appropriate terrain, enemies, and objectives for that specific opportunity.

**THE BATTLEFIELD BUBBLE — ASCII MAP GENERATION**

When a player character’s Battle Table result triggers a Duel or Heroic Opportunity, the game generates a 20×20 ASCII map representing the immediate area around the character on the battlefield. This is the Battlefield Bubble — a slice of the larger battle as experienced from the character’s position. The bubble follows the same principles as quest mission ASCII maps (Section 56) but uses terrain derived from the sub-province where the battle is taking place rather than a dungeon or camp template.

The bubble contains real NPCs with individual stat blocks, not abstract representations. Friendly soldiers from the character’s Company occupy tiles near the character. Enemy soldiers from the opposing Company occupy tiles on the opposite side. Approximately 10–15 friendly and 10–15 enemy soldiers populate the bubble at any time, fighting each other along the front line. The player character is one combatant among many, choosing where to engage. Named commanders (Gunso, Chui) may appear as targetable individuals if the Heroic Opportunity calls for them.

The Army View state feeds into the bubble. If the character’s Company is winning (higher current Health than its opponent), the front line shifts toward the far edge — enemy soldiers fall back, friendly soldiers push up. If losing, the reverse — enemies press in, friendlies retreat. If a flanking attack hits in the Army View during the Heroic Opportunity, enemy soldiers appear from a side edge of the map. If the Company takes heavy casualties, friendly soldiers on the map start dying — the bubble gets thinner on the friendly side.

**Battlefield Bubble — Terrain Templates**

The bubble’s terrain is generated from the sub-province terrain type where the battle takes place. Each terrain type produces a distinct battlefield feel that matches the terrain modifiers already defined in the Army View Terrain Effects section above.

Plains: Mostly open tiles. Scattered low cover — tall grass, rice paddies, irrigation ditches, fallen soldiers, broken equipment. Wide sight lines. Cavalry can move freely. Mounted characters gain full benefit of the Mounted/Higher status (Section 40). This is the terrain where the Unicorn’s cavalry advantage is most devastating and where large-scale flanking is most effective.

Forest: Dense tree tiles blocking movement and line of sight. Narrow clearings and paths between clusters of trees. Cover everywhere. Cavalry is severely restricted — horses cannot weave through dense trees. Mounted characters lose the Mounted/Higher bonus in forested tiles. Ambush-friendly terrain where a smaller force can hold against a larger one. Matches the Army View’s Forest modifier: Defender +2 Defence, Light Cavalry loses flanking bonus and −2 Attack.

Hills: Elevation changes across the map. High ground tiles grant the Mounted/Higher attack bonus (Section 40) to any character on them, not just mounted characters. Slopes slow movement upward. Mix of open ground and rocky cover. Cavalry is partially restricted — can operate on hilltops and gentle slopes but not on steep terrain. Matches the Army View’s Hills modifier: Attacker −2 Attack.

Mountains: Narrow paths between impassable rock tiles. Very restricted movement. Chokepoints everywhere. Cavalry is useless — no room to charge or manoeuvre. Favours defensive fighting and small-unit tactics. Matches the Army View’s Mountain modifier: Defender +4 Defence, Light Cavalry loses flanking bonus and −3 Attack.

Urban: Buildings, walls, streets, alleys. Lots of hard cover. Some interior tiles (rooms, courtyards). Cavalry is useless in streets. Favours close-quarters fighting and ambush tactics. Matches the Army View’s Urban modifier: Defender +3 Defence, Light Cavalry loses flanking bonus and −3 Attack.

Coastal: Sand tiles, shallow water tiles that slow movement, possibly docks or beached boats as cover. Open but with movement-restricting water sections. Matches the Army View’s Coastal modifier: no standard modifier for land engagements, Light Cavalry loses flanking bonus in amphibious conditions.

**HEROIC OPPORTUNITY MASTER LIST**

The following is the complete catalogue of Heroic Opportunities available during Mass Battle. When the Battle Table triggers a Heroic Opportunity, the system randomly selects one from the eligible pool. Eligibility is filtered by context — terrain type, enemy composition, army status, and the character’s current situation. Source: L5R 4th Edition Core Book and Sword and Fan.

For player characters, each Heroic Opportunity generates a specific configuration on the 20×20 Battlefield Bubble — the right NPCs, objects, and conditions appear on the map. For NPCs, the opportunity resolves through engine dice rolls using the skill and TN specified. A character may decline a Heroic Opportunity. Declining typically imposes a −5 penalty on the army general’s next Battle Roll, representing the missed chance and its effect on the battle’s momentum.

**Category 1 — Combat Encounters**

Break the Line: The character receives the command to charge the enemy’s front line. The character must face 2 to 4 Rank 2 samurai to successfully attack the front line. The character is immediately moved to Heavily Engaged. Success: +3 to the general’s next Battle Roll. Glory: 3. On the ASCII map, enemy samurai spawn in a line ahead of the player, with friendly soldiers pressing behind.

Few Against Many: An ally charges into the midst of battle and is surrounded. The character watches as enemies close in. The character must fight a skirmish against 3–6 samurai of one Rank lower than themselves (minimum Rank 1). If the ally survives, the character gains 3 Glory and may gain the Ally Advantage. On the ASCII map, a friendly named NPC appears surrounded by enemies. The player must reach and relieve them. Eligibility: requires a named NPC ally in the same army.

Hold This Ground: The commander orders the character to hold the line. The character and their unit must hold position against opposing forces. If Engaged, face a number of opponents equal to their number plus 2. If Heavily Engaged, additional +2 opponents. Success: 2 Glory (Engaged) or 4 Glory (Heavily Engaged). On the ASCII map, waves of enemy soldiers advance toward the player’s position from the front edge.

Skirmish: The character encounters a group of enemies and must drive them back — force them out of the fight, not necessarily kill them. Success: +1 to the general’s next Battle Roll. On the ASCII map, a cluster of enemy soldiers holds a position. The player must push them off the map edge or break their morale.

Stand Against the Darkness: Ashigaru and craven samurai are breaking and running at the sight of a Shadowlands creature. The character may fight a minor oni or similar supernatural opponent. Success: 4 Glory, +3 to the general’s next Battle Roll. Failure or refusal: −5 to the general’s next Battle Roll. On the ASCII map, an oni or Tainted creature appears with fleeing friendly soldiers around it. Eligibility: Shadowlands enemy forces only.

For the Empire: A Shadowlands warrior or Lost samurai is spotted shouting commands to corrupted forces. The character may fight a Lost samurai of one Rank higher or a minor oni. Success: 3 Glory, −5 to the opposing general’s next Battle Roll. On the ASCII map, the enemy commander appears in the back line surrounded by Tainted soldiers. Eligibility: Shadowlands enemy forces only.

Shadowlands Madness: The Shadowlands Taint falls upon soldiers fighting at the character’s side. They collapse screaming, then rise moments later with an unholy gleam in their eyes. The character must fight 1 to 4 Tainted samurai of equal Insight Rank (if Heavily Engaged) or one Rank lower (if Engaged). Success: 1 Glory. Failure: −3 to the general’s next Battle Roll. On the ASCII map, friendly soldiers near the player suddenly turn hostile. Distinct from Corrupted Brothers — this is a small personal skirmish, not a unit-scale event. Eligibility: Shadowlands enemy forces only.

Fighting Street to Street: The battle has devolved into urban close-quarters combat. The character faces three times their number (or unit’s number) of enemies of equal Insight Rank or higher (+4 if Heavily Engaged). Success: general receives +1k1 bonus to next Battle Roll, character gains 8 Glory. On the ASCII map, the bubble generates with Urban terrain regardless of sub-province type — buildings, alleys, rubble. Eligibility: Urban terrain or siege assault only.

**Category 2 — Target-Specific Objectives**

A Clear Shot: The front lines break and the character has a clear ranged shot at the enemy commander. TN depends on the commander’s Armour TN, minimum 30 given the chaos. A hit is worth 4 Glory. A killing shot (extremely unlikely) is worth a full Rank of Glory. Success: −5 to the opposing general’s next Battle Roll. On the ASCII map, a gap opens in the enemy line with the enemy commander visible at range. Eligibility: character must have a ranged weapon.

Attack the Archers: A path opens to the enemy’s reserve archers. The character charges into the reserves to disrupt ranged fire. Resolved as a skirmish. Success: 2 Glory, −5 to the opposing general’s next Battle Roll. On the ASCII map, a gap in the front line leads to a cluster of enemy archers in the back of the map. Eligibility: enemy army has Ashigaru Archer companies.

Attack the Shugenja: A break in the battle opens a path to the enemy’s reserve shugenja performing battle rituals. A successful attack disrupts their magic. Extremely dangerous — shugenja are high-value targets surrounded by guards. Success: 3 Glory, −5 to the opposing general’s next Battle Roll, +2 Honour if the character offers surrender. On the ASCII map, enemy shugenja appear in the deep rear with bodyguards. Eligibility: enemy army has shugenja units.

Overwhelm: The character and others in their unit spot an enemy commander in the chaos with no guardians. The character and any others in their unit may attack a single samurai of Rank 3 or 4. Success: −5 to the opposing general’s next Battle Roll. On the ASCII map, an isolated enemy commander appears with no bodyguards nearby.

Pick Up the Banner: The army’s banner carrier falls to arrows. The character may carry the banner, boosting morale — but the banner carrier is a priority target. While holding the banner, the general gains +3 to Battle Rolls each turn, but the character is attacked by many samurai and archers every Battle Turn until they drop it. On the ASCII map, the banner appears on the ground near a fallen NPC. Picking it up draws continuous enemy attention.

Take the Enemy Banner: The character spots the opposing army’s standard bearer. They must kill the bearer and carry the banner back to their own Reserves. Near-impossible without help. While holding the enemy banner, −5 to the opposing general’s Battle Roll each turn. Completing the objective: a full Rank of Glory. On the ASCII map, the enemy banner carrier appears deep in enemy territory with heavy guard. The player must fight through, take the banner, and reach the friendly edge of the map.

Stop the Summoning: Maho-Tsukai are summoning an oni or casting a dangerous maho spell. The ritual completes at the end of the next Battle Turn. The character must become Heavily Engaged and face a number of Maho-Tsukai (Insight Rank 3 or 4) equal to their unit’s size +2, plus possible bodyguards or monsters. Success: 6 Glory, −5 to the opposing general’s next Battle Roll. Failure: −3k3 penalty to the general’s remaining Battle Rolls. On the ASCII map, maho cultists appear performing a ritual with a visible timer. Eligibility: Shadowlands or maho-using enemy forces only.

Save a Sacred Site: A shrine, temple, famous holding, or individual sacred to the city is under assault by enemy forces or being looted by the character’s own side. If lost or destroyed, the general suffers −1k1 to Battle Rolls for the rest of the battle. If defended, the character gains a full Rank of Glory. Defence requires fighting 3–6 enemies of the character’s Insight Rank or higher while Heavily Engaged. On the ASCII map, the sacred site appears as a defensible structure with enemies closing in. Eligibility: Urban terrain or province with a notable shrine/temple.

**Category 3 — Protection and Escort**

Protect the General: The character encounters the army’s general, who has lost their personal guard. The general commands the character to stand at their side. The character follows the general for the rest of the battle, gaining 1 Glory per Battle Turn. On the ASCII map, the general appears as a named NPC ally. Enemies periodically attack from multiple directions. The character must keep the general alive.

Save a Wounded Comrade: A kinsman has fallen in the midst of battle. The character may defend them. While defending the comrade, the character cannot take any other Heroic Opportunities. Each Battle Turn, face 2 or 3 Rank 1 or 2 opponents. Success: 1 Glory per Battle Turn defended. On the ASCII map, a wounded friendly named NPC lies on a tile. Enemies periodically approach. The character must hold position adjacent to the fallen comrade.

Escort Mission: A high-profile ally is trapped amid desperate fighting and their yojimbo has fallen. The character may escort them from Heavily Engaged back to Reserves. Success: Glory equal to the target’s Status Rank, plus the Ally Advantage with that NPC at 2 points of Devotion. On the ASCII map, the VIP appears as a named NPC ally who must be guided to the friendly edge of the map through enemy opposition.

Corrupted Brothers: A damning power of the Shadowlands has corrupted an entire unit of allies. They have turned on their own side and are advancing toward the army’s Command Staff and reserves. The character must stop the corrupted soldiers before they reach the Reserves. They start at Heavily Engaged and move back one Engagement Level each Battle Turn. Success: 1 Glory per soldier defeated. Failure: −3k3 penalty to all later Battle Rolls. On the ASCII map, corrupted friendly soldiers advance from the friendly edge toward a defensive position the player must hold. Eligibility: Shadowlands enemy forces only.

**Category 4 — Duel and Personal**

Show Me Your Stance: An enemy commander notices the character and challenges them to a duel. The character may accept, initiating a duel against a samurai of Rank 2 or 3. Victory: 1 Glory per Glory Rank of the opponent, +2 to the general’s next Battle Roll. On the ASCII map, a named enemy commander approaches and issues a formal challenge. Other combatants clear a space.

Be Prepared to Dig Two Graves: The character spots a specific enemy who killed one of their kinsmen. The character may pursue, entering the enemy’s Level of Engagement. Requires a Contested Battle/Perception Roll to locate them. If found, the character may initiate the Show Me Your Stance opportunity or simply attack. On the ASCII map, the target enemy appears somewhere on the map and the player must locate and reach them through the fighting.

Wedge: The character is sent to spearhead a wedge formation driving deep into enemy forces. For the duration, the character is considered Heavily Engaged regardless of actual Engagement Level. They drive forward each Round toward the enemy Reserves. Success (reaching the enemy Reserves, number of Rounds determined by battle scale): −2k2 to the opposing general’s next Battle Roll, 5 Glory. On the ASCII map, the player pushes through successive waves of enemies from one edge toward the other.

Follow the Commander: The character’s commander or an elite unit charges forward. The character may join them, becoming Heavily Engaged for the remainder of the battle. If the character survives alongside the elite unit, they double all Glory gains for the battle and may gain recognition from the unit’s leader. On the ASCII map, a named commander and elite soldiers appear pushing forward. The player fights alongside them.

**Category 5 — Non-Combat Opportunities**

Rally the Archers: The army’s ranged troops are in disarray. The character must regroup them using inspirational words. Roll: Perform: Oratory / Awareness at TN 20. Success: +5 to the general’s next Battle Roll, 1 Glory. Failure: −5 to the general’s next Battle Roll. On the ASCII map, a group of fleeing Ashigaru Archers appear. The player must reach them and use the Rally action.

Join the Battle: The character is in Reserves or Disengaged and sees an opportunity. They may move to Disengaged (or from Disengaged to Engaged) and immediately re-roll on the Battle Table with no modifiers. On the ASCII map, no bubble generates — this is a pure Declaration change.

Save a Wounded Opponent: Between breaths, the character notices a wounded enemy. They may ignore the enemy without penalty, or aid them. Aiding requires moving to Reserves and escorting the enemy to safety. No Glory, no Battle Roll modifier. The character gains no mechanical bonus — but the opponent becomes a valuable hostage for negotiation (Section 22.9). On the ASCII map, a wounded enemy NPC appears. The player must escort them to the friendly edge without either being killed.

Shugenja’s Gift: One of the army’s shugenja targets the character with a beneficial spell. The character may consider one Trait or Skill to be one Rank higher for the remainder of the battle. No ASCII map generates — this is a buff applied between Battle Turns.

**Category 6 — Unheroic Opportunities**

These opportunities assume the character prioritises pragmatism and results over honour. They typically cause Honour loss and Infamy gain but improve the army’s tactical position. Available to any character but most commonly pursued by Scorpion, pragmatic Crab, or desperate commanders. The NPC Decision Engine filters these through personality — high-Honour NPCs will decline.

Friendly Fire: Confusion on the battlefield — fog, night, or chaos — leads the character into combat with soldiers from their own army. The foes use Full Attack every round. If the character kills them, they lose 4 Honour and must explain. If the character withdraws, they may use Sincerity to convince the allies to stop. On the ASCII map, friendly soldiers appear hostile. Eligibility: night battles, fog, or dense terrain.

Feign Death: The character falls amid blood and mud. They may stand and continue fighting (gaining a small Honour bonus if their current Honour Rank is low), or hide among the dead. Hiding avoids all further Wounds but costs half the Honour of Fleeing from Battle. Alternatively, the character may use the feigning to ambush an enemy officer — creating an automatic Duel, but gaining 5 Infamy. On the ASCII map, the character starts prone among corpse tiles with enemies walking past.

Gaijin Warfare: A member of the Command Staff has entrusted the character with gaijin pepper and commanded them to use it at the right moment. Activating the explosive immediately causes Honour loss as though committing a heinous crime. The explosion imposes −2k2 on the opposing general’s Battle Roll and −1k1 on the Round after that. If discovered, the likely result is execution or reduction to ronin. On the ASCII map, the character carries the package toward a target position among enemy formations. Eligibility: requires pre-battle setup by the Command Staff.

Liar’s Tactic: An enemy officer demands the character’s surrender. The character may surrender and then renege at an opportune moment, using magic or combat to disrupt the enemy ranks. Success: −1k1 to the opposing general’s next Battle Roll, +1k0 bonus to the character’s commander. Cost: Honour loss as a Major Breach of Etiquette, 3 Infamy. On the ASCII map, the character starts unarmed near an enemy officer and must act at the right moment. Eligibility: Shugenja only.

The Way of Deception: An enemy officer falls in front of the character, leaving their armour, helm, and insignia. The character may don the enemy’s gear to give false orders. Roll: Sincerity (Deceit) / Awareness or Acting / Awareness at TN 20 to impose −1k0 on the opposing general’s next Battle Roll. Each Raise adds another −1k0. Each Round the character continues, the Honour loss increases and the TN rises by +10. Failure: 3 Infamy and targeted by an enemy duelist one Insight Rank higher. On the ASCII map, the character starts next to a fallen enemy officer and must navigate enemy lines in disguise.

Defilement: An enemy falls in full view of the opposing army. The character may defile the body, banner, or sword to outrage the enemy. Immediate Honour loss as a Major Breach of Etiquette, 5 Infamy. The enemy’s rage grants their commander +1k0 to the next Battle Roll, but the out-of-control rampage grants the character’s commander +1k1 for the remainder of the battle. On the ASCII map, a fallen enemy appears. Interaction triggers the defilement. Enemy soldiers immediately converge on the character.

**PLAYER MASS BATTLE EXPERIENCE — LOCKED**

This section defines how player characters experience mass battle. The mass battle is the Battle Table — declare engagement, roll, take consequences, occasionally get pulled into something dramatic. One Battle Table roll per Combat Round Resolution (Steps 1–5). The number of rolls per battle is dynamic — determined by how many Combat Rounds it takes for one side to break. A Mass Battle consumes 1 OOC day (4 IC days). All AP that day is consumed. The player can do nothing else.

**Combat Round Player Loop**

Each Combat Round, the player sees a battle status screen showing: Army Status (Winning/Stalemate/Losing), their Company’s current Health and Morale, their own current Wounds and Wound Rank, current Level of Engagement, and available engagement choices (one step up or down from current, or hold). The player selects their engagement level for this round. The Combat Round resolves: Army View Steps 1–5 fire (Company Attack rolls, Health damage, Morale checks, Rout checks), then the player’s Battle Table rolls. Result: Wounds taken, Glory earned, and either nothing (back to the status screen next round) or a Duel/Heroic Opportunity (Battlefield Bubble generates, the player plays it out, then back to the status screen). Most rounds are quick. The Bubble is the punctuation — rare, dramatic, high-stakes. A 20-round battle might produce 2–3 Heroic Opportunities and 17 rounds of “took 2k1 Wounds, earned 1 Glory, pick your engagement.”

**Combat Time and Pacing**

NPC-only battles resolve instantly as background calculations. When a battle involves player characters, the Army View pauses after detecting the player’s Company is engaged. The battle state is frozen — Companies locked in position, Army Status calculated, everything ready. The battle resumes at Combat Time: 7PM EST daily. All players in active battles are expected to be online at Combat Time. Rounds resolve live — declare engagement, Army View ticks, Battle Table rolls, Bubbles fire, repeat. A 15-round skirmish can finish in one session. A massive engagement might take 2–3 evenings. If the battle does not finish in one session, it freezes and resumes at the next Combat Time. Each Combat Round has a 2-minute decision window. All players must submit their engagement level selection within 2 minutes. If a player does not respond within the window, the system uses their last submitted engagement level and applies their pre-set Wound threshold rules (see below). The round resolves immediately. The absent player’s Battle Table roll still fires — they still take Wounds and earn Glory. If the roll triggers a Heroic Opportunity, the absent player misses it. The opportunity is forfeited. The decline penalty applies (−5 Morale to their Company for Categories 1–5, no penalty for Category 6). When any player triggers a Heroic Opportunity or Duel, the Army View pauses for all participants until the Bubble resolves. Everyone waits. This ensures the battle state remains synchronised — no rounds advance while a player is mid-encounter. Individual moments hold up the battle, but they are short and dramatic, not drawn-out dungeon crawls. Combat Time value (7PM EST) is PROVISIONAL — may be configurable per server or adjusted based on player base geography.

**Wound Threshold Pre-Set**

Before the battle begins (or at any point during it), the player sets a Wound threshold: “If I reach Wound Rank X, automatically shift one engagement level toward Reserves each round until I reach Reserves.” This is the standing order for when the player is absent or fails to respond within the timer. A cautious player sets the threshold at Hurt (Wound Rank 2) — they pull back early. A brave player sets it at Crippled (Wound Rank 6) — they fight until they can barely stand. A reckless player sets it to Down (Wound Rank 7) — effectively never retreating. The default if no threshold is set is Injured (Wound Rank 4). The threshold only governs automatic behavior — a player who is online can override it at any time by manually selecting their engagement level.

**Multiplayer Synchronization**

The Army View is shared state. All players in the same battle see the same Company Health, Morale, and Army Status. Combat Rounds are synchronous at Combat Time: all players declare engagement simultaneously within the 2-minute window, the Army View resolves once, all Battle Table rolls fire. If any Heroic Opportunity or Duel triggers, the Army View pauses until all Bubbles resolve. Then the next round begins.

**Co-op Bubbles — Same Side**

When multiple players are assigned to the same Company (or Companies in the same Legion), their Heroic Opportunities generate shared Battlefield Bubbles. Two samurai in the same unit would naturally be near each other on the battlefield. If both trigger a Heroic Opportunity on the same round, they share a single 20×20 Bubble — two players fighting side-by-side in the same encounter. If only one triggers, the non-triggering player still appears in their companion’s Bubble as a controllable ally rather than an NPC. They participate in the encounter even though their own Battle Table roll did not trigger one. This makes same-Company assignment a genuine co-op experience.

**PvP Bubbles — Opposing Sides**

When players are on opposing sides of a battle and their Companies are engaged against each other in the Army View, Heroic Opportunities can produce PvP Bubbles. If a player on one side triggers a Heroic Opportunity while an opposing player’s Company is the engaged enemy, the opposing player is pulled into the same Bubble as an adversary. If both trigger simultaneously, the Bubble is shared — Player A’s “Break the Line” charge meets Player B’s “Hold This Ground” defense on the same 20×20 map. This is real PvP combat on the Battlefield Bubble, the most dramatic outcome the game can produce. There is no consent mechanic for PvP in battle — this is war. If a player on the opposing side is absent (offline or timed out), their character is engine-controlled in the Bubble using their full character sheet stats. The absent player still takes Wounds and earns Glory from the Battle Table roll — they just do not personally control the fight. Being present for a battle matters.

**HEROIC OPPORTUNITY → ARMY VIEW TRANSLATION TABLE — LOCKED**

The Heroic Opportunity outcomes above use L5R tabletop language (“+3 to the general’s next Battle Roll”). In our system, mass combat resolves through the Army View — Company stat blocks (Health, Attack, Defense, Morale, Morale Defense) fighting each other. There is no “general’s Battle Roll.” This table translates every Heroic Opportunity outcome into specific Army View stat modifiers. All modifiers last 1 Battle Turn (1 round of Army View resolution) unless stated otherwise. “Character’s Company” means the Company the character is assigned to or commands. “Opposing Company” means the enemy Company currently engaged with the character’s Company.

Category 1 — Combat Encounters. Break the Line: +3 Attack to character’s Company for 1 turn. The charge opens a gap the Company exploits. Few Against Many: +2 Morale to character’s Company for 1 turn. Witnessing the rescue inspires the unit. Hold This Ground: +3 Defense to character’s Company for 1 turn (Engaged) or +5 Defense (Heavily Engaged). The line holds firm. Skirmish: +1 Attack to character’s Company for 1 turn. A small tactical gain. Stand Against the Darkness: +3 Attack to character’s Company for 1 turn, +5 Morale to all friendly Companies in the battle. Slaying a Shadowlands creature in view of the army rallies everyone. Failure: −5 Morale to all friendly Companies. For the Empire: −3 Attack to opposing Company for 2 turns. Killing an enemy sub-commander disrupts their coordination. Shadowlands Madness: Failure only: −3 Morale to character’s Company. Taint corruption within the unit shakes confidence. Fighting Street to Street: +5 Attack and +3 Defense to character’s Company for 1 turn. Urban mastery translates to Company-level dominance in close quarters.

Category 2 — Target-Specific Objectives. A Clear Shot: −5 Attack to opposing Company for 1 turn (hit). If killing blow: opposing Company loses commander bonus permanently and suffers −10 Morale immediately. Attack the Archers: −5 Attack to the targeted Ashigaru Archer Company for the remainder of the battle. Their ranged capability is crippled. Attack the Shugenja: −5 Attack to the targeted shugenja Company for the remainder of the battle. All Special abilities from that Company are suppressed for 2 turns. Overwhelm: −3 Attack to opposing Company for 1 turn. The enemy commander is shaken. Pick Up the Banner: +3 Morale to all friendly Companies per turn while held. Losing the banner carrier: −5 Morale to all friendly Companies. Take the Enemy Banner: −5 Morale to all enemy Companies per turn while held. Completing the objective (carrying banner to friendly reserves): −10 Morale to all enemy Companies immediately. Stop the Summoning: −5 Attack to all enemy Companies for 1 turn. The supernatural threat is neutralised. Failure: +10 Health damage to all friendly Companies immediately as the summoned entity manifests. Save a Sacred Site: Failure: −5 Morale to all friendly Companies for the remainder of the battle. Success: +3 Morale to all friendly Companies for the remainder of the battle.

Category 3 — Protection and Escort. Protect the General: no Company stat modifier. The value is keeping the general alive — if the general dies, all friendly Companies suffer −15 Morale immediately and lose the commander Battle bonus for the remainder of the battle. Save a Wounded Comrade: +1 Morale to character’s Company per turn while defending. The sight of a samurai protecting a fallen comrade steadies the unit. Escort Mission: no Company stat modifier. The value is the rescued NPC and the political relationship gained. Corrupted Brothers: Failure: −15 Morale to all friendly Companies and 10 Health damage to the general’s Company. The reserves are overrun by Tainted former allies. Success: no stat modifier, but prevents the catastrophic failure.

Category 4 — Duel and Personal. Show Me Your Stance: +2 Attack to character’s Company for 1 turn. Victory over an enemy commander in single combat inspires the unit. Defeat: −3 Morale to character’s Company. Be Prepared to Dig Two Graves: no Company stat modifier. This is personal vengeance — the army doesn’t know or care. Wedge: −10 Morale to opposing Company. The wedge reaching enemy reserves is devastating to enemy cohesion. +3 Attack to character’s Company for 2 turns as the formation exploits the breakthrough. Follow the Commander: +2 Attack and +2 Morale to character’s Company for the remainder of the battle. Fighting alongside elites raises the whole unit’s performance.

Category 5 — Non-Combat Opportunities. Rally the Archers: +5 Morale to the targeted Ashigaru Archer Company. Their ranged effectiveness is restored. Failure: −5 Morale to that Company — the rallying attempt failed publicly. Join the Battle: no Company stat modifier. The character enters a different engagement. Save a Wounded Opponent: no Company stat modifier. The value is the hostage captured (Section 22.9). Shugenja’s Gift: no Company stat modifier. The buff applies to the individual character only, affecting their Battle Table rolls and Heroic Opportunity performance for the rest of the battle.

Category 6 — Unheroic Opportunities. Refusal: declining a Category 6 opportunity carries NO penalty. A samurai who refuses to use gaijin pepper, defile a corpse, or feign death is acting with Honour. The decline penalty (−5 Morale to character’s Company) applies only to Categories 1–5, where declining represents cowardice or failure of duty. Category 6 opportunities are temptations, not duties. High-Honour NPCs decline them automatically through personality filters. Low-Honour and Shourido NPCs evaluate them through the standard scoring system. Friendly Fire: no Company stat modifier. This is a personal crisis. Feign Death: no Company stat modifier unless the character ambushes an enemy officer — in that case, −3 Attack to opposing Company for 1 turn. Gaijin Warfare: 20 Health damage directly to the targeted enemy Company. −10 Morale to all enemy Companies from the explosion. −5 Morale to all friendly Companies from the dishonour. Liar’s Tactic: −3 Attack to opposing Company for 1 turn. +1 Attack to character’s Company for 1 turn. The Way of Deception: −3 Attack to all enemy Companies for 1 turn. False orders cause momentary confusion across the enemy line. Duration extends by 1 turn per additional Raise achieved on the Sincerity roll. Defilement: +2 Attack to all enemy Companies for 1 turn (their rage). −3 Morale to all enemy Companies for the remainder of the battle (the psychological damage outlasts the rage). Net effect is strongly positive for the defiler’s side over multiple turns despite the short-term enemy Attack surge.

Category 7 — Siege Opportunities. These trigger only during Castle Siege template battles (Section 56.17). Eligibility: siege assault or defense context. Man the Breach: enemy forces have broken through a wall section. The character must hold the breach against waves of attackers pouring through a gap 2–3 tiles wide. Face 4–8 enemies per round, Heavily Engaged. Success: +5 Defense to character’s Company for 2 turns. The breach is plugged. Failure: −10 Morale to all friendly Companies. The wall is lost. On the ASCII map, a gap in the wall with enemies streaming through. Destroy the Siege Engine: enemy sappers or engineers are operating a siege weapon (ram, siege tower, trebuchet). The character must fight through guards and destroy or disable it. 3–5 guards plus the engine (treat as a destructible object, 30 Wounds, Reduction 5). Success: −5 Attack to all enemy Companies for 2 turns. The siege weapon is eliminated. On the ASCII map, the engine appears in the rear of the enemy formation with engineer NPCs. Hold the Gate: the castle gate is under direct assault. The character commands the defenders at the chokepoint — murder holes above, boiling oil available, 2-tile-wide bottleneck. Success: +5 Defense to character’s Company for the remainder of the battle while the gate holds. Failure: gate falls, −15 Morale to all friendly Companies. On the ASCII map, the gate area with murder hole tiles, oil cauldrons as interactable objects, and enemies pushing through the narrow passage. Boiling Oil: the character operates a cauldron of boiling water or oil from the battlements. Roll: Engineering + Strength TN 15. Success: 15 Health damage directly to the opposing Company. Each Raise adds 5 Health damage. On the ASCII map, interactable cauldron tile on the wall overlooking the assault below. Sortie from the Postern: the defenders launch a surprise attack from a hidden gate. The character leads a small force (4–6 friendlies) into the enemy flank. Success: −8 Morale to opposing Company (surprise and flank attack). +3 Attack to character’s Company for 1 turn. On the ASCII map, the character starts outside the walls behind enemy lines with a small friendly force.

Category 8 — Cavalry Opportunities. These trigger only when the character is mounted or their Company is a cavalry unit. Eligibility: character has Horsemanship 3+ or is assigned to a cavalry Company. Cavalry Charge: the character leads or joins a mounted charge into the enemy line. Roll: Horsemanship + Agility. On a hit, the character’s momentum carries through multiple enemies. Success: +5 Attack to character’s Company for 1 turn. The charge shatters the opposing formation. −5 Morale to opposing Company. On the ASCII map, the character starts mounted at the friendly edge with open ground ahead and an enemy line at the far edge. Ride Down the Flank: the character breaks away from the main engagement and circles to strike the enemy’s exposed flank. Requires 3 rounds of movement through open terrain before the attack connects. Success: −8 Morale to opposing Company (flank panic). +3 Attack to character’s Company for 2 turns as the flank collapses. Failure (detected during approach): −3 Morale to character’s Company. On the ASCII map, the character rides along the map edge, avoiding enemy scouts, before turning to strike the enemy flank. Intercept the Messenger: an enemy rider is spotted leaving the battlefield — carrying orders, a plea for reinforcements, or intelligence. The character gives chase. Contested Horsemanship roll. Success: the message is intercepted. Intelligence value feeds to the NPC Decision Engine. −3 Attack to all enemy Companies for 1 turn (orders disrupted). Failure: the messenger escapes. No modifier. On the ASCII map, a mounted enemy NPC rides toward the far edge. The character must reach them before they escape. Trample the Archers: the character drives their mount into enemy ranged troops. Cavalry vs unarmoured ashigaru archers is devastating. Success: −8 Attack to targeted Archer Company for 2 turns. +2 Attack to character’s Company for 1 turn. On the ASCII map, enemy archers appear in a loose formation with no spear wall protection. Rally and Reform: the character’s cavalry Company has been scattered by a failed charge or ambush. The character must rally the riders and reform the formation. Roll: Battle + Awareness TN 20. Success: character’s Company recovers +10 Morale immediately. Attack restored to base value (removes any penalties from the failed action). On the ASCII map, scattered mounted friendlies appear across the map. The character must ride to each group and use the Rally action.

Category 5 expanded entries. Tend the Wounded: a field medic opportunity. The character moves to Reserves and treats wounded soldiers. Roll: Medicine + Intelligence TN 15. Success: character’s Company recovers 5 Health (representing saved soldiers returning to the fight). Each Raise recovers 3 additional Health. On the ASCII map, wounded friendly NPCs lie in the rear area. The character treats them with Medicine rolls while enemies periodically threaten the aid station. Inspire the Line: the character steps forward and delivers a speech, war cry, or visible act of defiance that rallies wavering troops. Roll: Perform: Oratory + Awareness TN 20 or Battle + Awareness TN 25. Success: +5 Morale to all friendly Companies for 1 turn. Each Raise extends duration by 1 turn. On the ASCII map, no combat — a social action resolved through the Perform or Battle roll. The character stands visible to the army. Field Fortification: an engineer hastily constructs defensive positions during a lull in the fighting. Roll: Engineering + Intelligence TN 20. Success: +3 Defense to character’s Company for the remainder of the battle. Each Raise adds +1 Defense. On the ASCII map, the character places barricade objects on specific tiles. Enemies who advance through fortified tiles suffer movement penalties.

Category 9 — Naval Opportunities. These trigger only during naval combat when the character is aboard a ship. The Battlefield Bubble is the Ship Boarding ASCII template (Section 56.18). Eligibility: character is aboard a ship in the engagement. Weather at sea (Section 11.9) functions as the naval equivalent of terrain — the global and ship-type-specific modifiers are the baseline, and Naval Heroic Opportunities are how individual characters counteract or exploit those conditions. The Mantis dominate not because their ships are immune to weather, but because their characters have more eligible opportunities and better skills to succeed at them.

Subtype A — Weather Mitigation and Exploitation. Secure the Rigging: the storm is tearing at the sails and ropes. The character climbs the rigging and secures the lines before the ship loses maneuverability. Roll: Sailing (Knot-work) + Agility TN 20. Success: character’s ship ignores the weather Attack penalty for 1 turn. On the ASCII map, the character climbs rigging tiles, fighting wind and wet deck penalties, reaching and interacting with loose-rope tiles before a timer expires. Failure: no effect, character takes 2k2 Wounds from being thrown by the rigging. Eligibility: any character aboard. Army View: character’s ship ignores the global weather Attack modifier for 1 turn. Shift the Storm: the Yoritomo shugenja reaches out to the spirits of the sea and wind, bending the weather to their crew’s advantage. Roll: Spellcraft + Water TN 25. Success: weather shifts one step in the direction of the character’s choice (Clear is the floor, Typhoon is the ceiling — weather cannot be shifted below Clear or above Typhoon). The shift takes effect next round and persists for the remainder of the engagement. On the ASCII map, the shugenja performs a ritual on the quarterdeck, expending a spell slot. Hostile spirits or crew interruptions may threaten the ritual — the character must complete the casting before being disrupted. Failure: weather does not shift, spell slot expended. Eligibility: Yoritomo Shugenja or Storm Rider school only. Must have at least one Water spell slot remaining. Army View: the global weather state changes for both sides — all weather modifiers shift accordingly. Ride the Waves: the character reads the current and wave pattern, calling out adjustments to the helmsman that turn the rough seas into an advantage. Roll: Sailing (Navigation) + Intelligence TN 20. Success: character’s ship gains +2 Attack for 1 turn. On the ASCII map, the character stands at the bow or quarterdeck, reading the water. No combat — a skill check resolved through the Navigation roll. Failure: no effect. Eligibility: Sailing 3+ or Navigation emphasis. Army View: +2 Attack to character’s ship for 1 turn. Rally the Crew: the crew is breaking — morale is collapsing from casualties, weather, or a failed boarding attempt. The character rallies them. Roll: Perform: Oratory + Awareness TN 20 or Battle + Awareness TN 25. Success: +5 Morale to character’s ship for 1 turn. Each Raise extends by 1 turn. On the ASCII map, no combat — the character stands on the quarterdeck or main deck and delivers the rally. Fleeing heimin crew are visible around them. Failure: −3 Morale to character’s ship. Eligibility: any character aboard. Army View: +5 Morale to character’s ship for 1 turn (+1 turn per Raise). Failure: −3 Morale. Patch the Hull: the ship is taking structural damage. The character works below decks to reinforce breached planking before the ship takes on too much water. Roll: Engineering + Intelligence TN 20 or Sailing (Knot-work) + Strength TN 20. Success: character’s ship recovers 10 Health. Each Raise recovers 5 additional Health. On the ASCII map, the character descends to below-decks tiles. Water tiles are flooding in through breach points. The character must reach and interact with 2–3 breach tiles while the deck above shakes from combat. Failure: no repair, character takes 1k1 Wounds from falling debris. Eligibility: any character aboard. Army View: character’s ship recovers 10 Health (+5 per Raise).

Subtype B — Boarding Combat. Lead the Boarding: the ships are lashed together and the character leads the charge across the boarding planks onto the enemy deck. Roll: melee weapon skill + Agility. Success: +3 Attack to character’s ship for 1 turn. −3 Morale to opposing ship. On the ASCII map, the character crosses the boarding plank tiles (1 tile wide) onto the enemy deck. 3–5 enemy sailors defend the deck edge. The boarding plank provokes free attacks from the deck above per existing boarding rules. Failure: character is driven back, takes Wounds from the crossing. Eligibility: any character aboard, Engaged or Heavily Engaged. Army View: +3 Attack to character’s ship for 1 turn. −3 Morale to opposing ship. Repel Boarders: enemy crew are pouring over the rails onto the character’s ship. The character holds a chokepoint at the boarding plank or rail. Roll: melee weapon skill + Strength. Success: +3 Defense to character’s ship for 1 turn. On the ASCII map, enemies cross boarding planks and climb the rails. The character holds a 1–2 tile chokepoint, fighting 4–6 enemies who funnel through the narrow crossing. Wet deck penalties apply unless the character is Yoritomo Bushi, Storm Legion, or has Sailing 3+. Failure: boarders establish a foothold, no modifier. Eligibility: any character aboard, Engaged or Heavily Engaged. Army View: +3 Defense to character’s ship for 1 turn. Cut the Grapples: the enemy has lashed their ship to yours. The character fights along the rail, severing the lines and creating chaos among the enemy crew trying to cross. Roll: Sailing (Knot-work) + Agility TN 15 or Kenjutsu + Agility TN 20. Success: −3 Attack to opposing ship for 1 turn. The enemy crew loses footing and cohesion as their crossing lines go slack. On the ASCII map, grapple-rope tiles along the rail. The character reaches and interacts with 3–4 rope tiles while enemy boarders threaten from adjacent tiles. Failure: no effect. Eligibility: any character aboard. Army View: −3 Attack to opposing ship for 1 turn. Defend the Quarterdeck: the enemy boarding party is pushing toward the captain. The character positions themselves between the boarders and the quarterdeck. Roll: melee weapon skill + Stamina. Success: captain survives this round. +2 Morale to character’s ship per turn while defending. On the ASCII map, the character holds the 1–2 tile stairway to the elevated quarterdeck against waves of enemy boarders pushing past the main melee. Failure: boarders reach the quarterdeck, captain enters personal combat (engine-resolved if NPC). Eligibility: any character aboard, Engaged or Heavily Engaged. Army View: +2 Morale to character’s ship per turn while defending. Failure: captain may die (−15 Morale, loss of commander bonus). Rescue the Fallen: a named NPC ally has been knocked overboard during the fighting. Roll: Athletics (Swimming) + Strength TN 20 if diving in, or Sailing (Knot-work) + Agility TN 15 if throwing a rope. Success: NPC is saved. +2 Morale to character’s ship for 1 turn. Political relationship gained with the rescued NPC. On the ASCII map, the NPC is in a water tile adjacent to the ship edge. Diving in means the character enters the water and must climb back (TN 20). Rope keeps the character on deck but requires Knot-work. Failure (diving): character in the water, NPC drifts. Failure (rope): rescue window expires. Eligibility: any character aboard. Target is always a named NPC, never a player character. Army View: +2 Morale to character’s ship for 1 turn.

Subtype C — Target-Specific Naval. Kill the Captain: a gap opens in the fighting and the enemy captain is visible on their quarterdeck. The character fights through to reach them. Roll: resolved as a duel or skirmish against the enemy captain (named NPC with full stats). Success: −5 Attack to opposing ship for the remainder of the engagement. −10 Morale to opposing ship immediately. The ship loses its captain’s commander bonus permanently. On the ASCII map, the character fights across the enemy deck toward the quarterdeck, past 2–3 crew guards. The captain stands on the elevated quarterdeck with the +1k0 height advantage. Failure: character is driven back, takes Wounds. Eligibility: any character aboard, Heavily Engaged. Army View: −5 Attack to opposing ship for remainder of engagement. −10 Morale immediately. Commander bonus lost permanently. Fire the Sails: the character uses Bo-Hiya (fire arrows) to ignite the enemy ship’s sails and rigging. Roll: Kyujutsu + Reflexes TN 25. Precondition: character must be adjacent to a lit brazier tile and have Bo-Hiya equipped. Simple Action to light the arrow, then fire. Weather gate: brazier extinguished in Storm and Typhoon — this opportunity cannot trigger in those weather states. Success: −2 Defense to opposing ship for the remainder of the engagement. Each Raise reduces Defense by an additional −1 (maximum −4 total). On the ASCII map, the character fires from their own deck toward the enemy rigging. Enemy archers and boarders threaten while the character lines up the shot. Failure: arrow misses or fire fails to catch, no effect. Eligibility: Kyujutsu 3+ and Bo-Hiya equipped. Army View: −2 Defense to opposing ship for remainder of engagement (−1 per Raise, max −4). Seize the Colors: the enemy ship’s banner flies from the mast. The character climbs the enemy rigging and tears it down. Roll: Athletics (Climbing) + Strength TN 20. Success: −5 Morale to opposing ship immediately. On the ASCII map, the character fights across the enemy deck, then climbs the rigging tiles to the mast top (2–3 tiles of climbing under fire). Enemy crew converge on the mast base. Failure: character falls from the rigging, takes falling damage per Section 4.5.6. Eligibility: any character aboard, Heavily Engaged. Army View: −5 Morale to opposing ship immediately.

All values PROVISIONAL pending playtesting. The translation principle: Combat Encounter successes primarily boost Attack on the character’s Company. Target-Specific successes primarily debuff the targeted enemy Company. Protection successes prevent catastrophic Morale loss. Non-Combat and Unheroic opportunities have narrow or personal effects. Banner effects are the strongest because they affect ALL Companies in the battle, not just one. Naval Opportunities follow the same principle — Subtype A (weather mitigation) counteracts global penalties or provides buffs. Subtype B (boarding combat) mirrors Category 1 Combat Encounters. Subtype C (target-specific) mirrors Category 2 Target-Specific Objectives. The Mantis advantage is eligibility and skill depth, not exclusive access — most naval opportunities are open to any character aboard, but Mantis schools have the Sailing skill ranks, emphases, and school techniques that make success more likely.

**INDIVIDUAL SOLDIER STAT BLOCKS — REQUIRED**

The Battlefield Bubble requires individual stat blocks for every military unit type that can appear on the 20×20 ASCII map. These are distinct from the Company-level stat blocks defined in Section 11.6 and the Army View above, which represent aggregate unit performance. The individual stat blocks use the same abbreviated format as the bandit archetypes in Section 54.8. Named commanders (Gunso and above) use their full character sheet stats as defined in Section 22.3. Per Section 56.10.0a (Individual Variance Rule), each generic soldier has a 30–40% chance of one Trait or Skill at +1.

**Generic Unit Types**

PEASANT LEVY. Air 2 | Earth 2 | Fire 2 | Water 2 | Void 1. Honor: 1.0 | Status: 0.0 | Insight Rank: 0 (untrained). Skills: Peasant Weapons 1 or Spears 1, Athletics 1. Equipment: yari (spear) or improvised weapon, no armor, straw sandals. Conscripted farmers given a weapon and pointed at the enemy. Nearly identical to Rebel Peasants — because that is exactly what they are, just fighting for their lord instead of against him. They stand in a line because they were told to. They hold because the man next to them is holding. Individually useless against a trained samurai — dangerous only in numbers.

ASHIGARU SPEARMAN. Air 2 | Earth 2 | Fire 2 | Water 2 | Void 1 | Agility 3. Honor: 1.5 | Status: 0.0 | Insight Rank: 1. Skills: Spears 3, Defense 1, Athletics 2, Battle 1. Equipment: yari (spear), light ashigaru armor (Armor TN bonus +5, Reduction 2), jingasa helmet. Trained peasant infantry — drilled, equipped, and capable of holding a line. Individually a minor threat to a trained bushi but competent enough to be dangerous if ignored.

ASHIGARU ARCHER. Air 2 | Earth 2 | Fire 2 | Water 2 | Void 1 | Reflexes 3. Honor: 1.5 | Status: 0.0 | Insight Rank: 1. Skills: Kyujutsu 3, Defense 1, Athletics 2. Equipment: yumi (bow), tanto (knife), light ashigaru armor (Armor TN bonus +5, Reduction 2), jingasa helmet. Trained peasant ranged infantry. Effective at distance, near-helpless in melee — the tanto is a last resort, not a fighting weapon. On the Battlefield Bubble, Ashigaru Archers hold rear positions and fire into the front line. If enemies reach them they attempt to withdraw rather than fight.

BUSHI RETAINER. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4. Honor: 3.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 1. Skills: Kenjutsu 3, Defense 2, Iaijutsu 1, Battle 2, Athletics 2, Lore: Bushido 1. Equipment: katana, wakizashi, light armor (Armor TN bonus +5, Reduction 3). A professional samurai — trained at a dojo, carrying a real daisho, fighting with discipline and skill. The generic samurai soldier serving a Minor Clan or filling out a Great Clan’s ranks below the elite family schools. Individually dangerous to any non-samurai opponent and a credible threat to most player characters at lower Insight Ranks.

LIGHT CAVALRY. Air 2 | Earth 2 | Fire 2 | Water 2 | Void 1 | Agility 3. Honor: 1.5 | Status: 0.0 | Insight Rank: 1. Skills: Spears 2, Horsemanship 2, Athletics 2, Defense 1. Equipment: yari (spear), light ashigaru armor (Armor TN bonus +5, Reduction 2), jingasa helmet. Mount: Rokugani Pony (Section 54.1). Ashigaru-tier soldiers on horseback. Their value is mobility and flanking, not individual combat power — dismounted they fight no better than a regular Ashigaru Spearman. On the Battlefield Bubble, mounted Light Cavalry gain the Mounted/Higher bonus (+1k0 attack vs unmounted) from Section 40. Rider must make Horsemanship/Awareness TN 20 each round to get the pony to attack independently.

GARRISON. Air 2 | Earth 2 | Fire 2 | Water 2 | Void 1 | Agility 3, Willpower 3. Honor: 2.0 | Status: 0.0 | Insight Rank: 1. Skills: Spears 2, Defense 2, Athletics 1, Battle 1. Equipment: yari (spear), medium armor (Armor TN bonus +5, Reduction 3), jingasa helmet. Permanent settlement guards — ashigaru-tier soldiers who live in the town or castle they defend. Better armored than field ashigaru and more willing to stand their ground because they are defending their home. Statistically similar to Ashigaru Spearmen but with higher Defense skill and better armor, reflecting the Company stat block’s higher Defense (5 vs 4) and the +2 Defense inside own settlement special.

**Crab Clan**

HIDA BUSHI. Air 2 | Earth 4 | Fire 3 | Water 3 | Void 2 | Stamina 5, Strength 4. Honor: 3.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Heavy Weapons 3, Kenjutsu 2, Defense 3, Athletics 2, Intimidation 2, Lore: Shadowlands 2. Equipment: tetsubo or dai-tsuchi (heavy weapon), katana, heavy armor (Armor TN bonus +10, Reduction 5). The Crab’s frontline warrior — built to absorb punishment and crush what stands in front of them. The highest Earth and Reduction of any standard unit in the game. They do not finesse. They endure, and then they hit you with something very heavy.

CRAB BERSERKER. Air 2 | Earth 4 | Fire 3 | Water 3 | Void 2 | Stamina 5, Agility 4. Honor: 2.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Heavy Weapons 4, Kenjutsu 2, Defense 1, Athletics 3, Intimidation 3. Equipment: tetsubo or ono (heavy weapon), katana, medium armor (Armor TN bonus +5, Reduction 3). Hida warriors who have given themselves over to rage. Higher Attack than standard Hida Bushi but lower Defense — they hit harder and care less about being hit back. They use Full Attack Stance more readily than any other unit. Same Earth as a Hida Bushi because they are still Crab — they simply choose not to defend.

HIRUMA SCOUTS. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Reflexes 4, Agility 4. Honor: 3.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Kyujutsu 2, Stealth 3, Hunting 3, Athletics 3, Defense 2, Lore: Shadowlands 2. Equipment: katana, wakizashi, yumi (bow), light armor (Armor TN bonus +5, Reduction 2). Fast, quiet, and lethal — the Crab’s eyes beyond the Wall. Lower Earth than other Crab units because Hiruma train for speed and evasion, not endurance. They fight like skirmishers, not line infantry — strike, reposition, avoid getting pinned down. On the Battlefield Bubble, Hiruma Scouts are more likely to appear on flanks or in scouting-related Heroic Opportunities than in the front line.

**Crane Clan**

KAKITA BUSHI. Air 4 | Earth 2 | Fire 3 | Water 3 | Void 3 | Reflexes 5, Agility 4. Honor: 5.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Iaijutsu 4, Defense 2, Etiquette 2, Sincerity 1. Equipment: katana, wakizashi, light armor (Armor TN bonus +5, Reduction 2). The Crane’s duelist tradition made soldier. Extremely high Reflexes and Iaijutsu — they kill in the first exchange or make it very expensive to press them. Light armor because the Kakita style relies on not being hit rather than absorbing the blow. Individually among the most dangerous one-on-one combatants on any battlefield, but fragile if surrounded.

KENSHINZEN. Air 5 | Earth 3 | Fire 3 | Water 3 | Void 4 | Reflexes 6, Agility 5. Honor: 6.5 | Status: 3.0 | Insight Rank: 3 | School Rank: 2. Skills: Kenjutsu 5, Iaijutsu 6, Defense 3, Etiquette 3, Meditation 2. Equipment: katana, wakizashi, light armor (Armor TN bonus +5, Reduction 2). Master duelists who have transcended the Kakita school’s normal training. Reflexes 6 and Iaijutsu 6 make them among the most lethal individual combatants alive — a Kenshinzen in a duel is close to a death sentence for anyone below their caliber. Rare on a battlefield because dueling masters are not typically spent as line troops. When they appear in the Battlefield Bubble, they are most likely the target or trigger of a Duel Heroic Opportunity, not rank-and-file soldiers.

DAIDOJI HEAVY SPEARMEN. Air 2 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Stamina 4. Honor: 4.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Spears 4, Defense 3, Athletics 2, Battle 2, Kenjutsu 1. Equipment: yari (spear), katana, heavy armor (Armor TN bonus +10, Reduction 5). The Crane’s defensive backbone — samurai trained to hold ground while the Doji end the war at court. Highest Defense of any Tier 2 unit in the game, matching the Company stat block. They fight with disciplined spear work, anchor positions, and do not give ground willingly. Not flashy like the Kakita — effective, pragmatic, and very hard to move.

**Dragon Clan**

MIRUMOTO BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 3 | Agility 4, Reflexes 4. Honor: 4.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Defense 2, Iaijutsu 2, Athletics 2, Meditation 1, Lore: Theology 1. Equipment: katana, wakizashi (wielded simultaneously — Niten style), light armor (Armor TN bonus +5, Reduction 2). The Dragon’s two-sword fighters. Niten — wielding katana and wakizashi together — defines the Mirumoto. They attack and defend in the same motion, making them well-rounded individual combatants with no glaring weakness. Not as lethal in a single strike as a Kakita, not as durable as a Hida, but consistently dangerous across all phases of a fight.

DRAGON TALONS. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 2 | Agility 5, Strength 4. Honor: 4.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Heavy Weapons 4, Kenjutsu 2, Defense 2, Athletics 3. Equipment: no-dachi (heavy weapon), katana, medium armor (Armor TN bonus +5, Reduction 3). Dragon heavy infantry wielding massive two-handed blades designed to cleave through armor. High Agility and Strength reflect the power and precision needed to use a no-dachi effectively. They sacrifice the defensive versatility of Niten for raw cutting power — the blade goes through what it hits.

YAMABUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 3 | Intelligence 4, Willpower 4. Honor: 4.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Spellcraft 3, Lore: Theology 2, Meditation 2, Defense 1, Athletics 2, Craft: Alchemy 2. Equipment: staff or knife, no armor, scroll satchel, alchemical supplies. Spells: 3–4 combat-relevant elemental spells (Mastery Level 1–2). Dragon battle shugenja — Tamori-trained priests who wade into the fight rather than standing behind the line. On the Battlefield Bubble, they function as support — casting elemental magic to buff adjacent friendly soldiers or hinder enemies. Not strong in melee but not helpless either. The Tamori do not share the Asahina’s pacifism.

**Lion Clan**

AKODO BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Perception 4. Honor: 5.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 4, Battle 3, Defense 2, Iaijutsu 2, Athletics 2, Lore: War 2. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). The most disciplined samurai infantry in the Empire. Akodo train to fight as part of a unit — every sword stroke complements the man beside them. High Battle skill reflects tactical awareness, not just personal combat ability. Individually solid rather than spectacular, but their real power is in how they fight together. On the Battlefield Bubble, Akodo soldiers maintain spacing and coordination even without explicit formation mechanics.

LION’S PRIDE. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 3 | Agility 5, Reflexes 4. Honor: 6.0 | Status: 2.0 | Insight Rank: 3 | School Rank: 2. Skills: Kenjutsu 5, Battle 3, Defense 3, Iaijutsu 3, Athletics 3, Intimidation 3. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). Elite Matsu samurai-ko — the most feared warriors in the Empire. They hunt enemy commanders. Immune to Fear effects. On the Battlefield Bubble, Lion’s Pride soldiers actively seek out enemy named characters rather than fighting in the line. Their presence in a Heroic Opportunity involving an enemy commander makes that commander’s situation significantly more dangerous.

DEATHSEEKERS. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 1 | Agility 5, Strength 4. Honor: 0.5 | Status: 0.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 4, Heavy Weapons 3, Athletics 3, Defense 0. Equipment: katana or no-dachi, no wakizashi (surrendered upon taking the vow), light armor or none. Dishonored Lion bushi who have taken the Deathseeker vow — they seek redemption through a glorious death in battle. Void 1 reflects a broken spirit, not a calm mind. Defense 0 is deliberate — they do not defend. They use Full Attack Stance exclusively. They fight until they are dead. On the Battlefield Bubble, Deathseekers charge the most dangerous enemy they can find and do not withdraw for any reason.

**Phoenix Clan**

SHIBA BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 3 | Willpower 4, Perception 4. Honor: 5.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Spears 2, Defense 3, Theology 2, Meditation 2, Athletics 2. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). The Shiba exist to protect the Phoenix’s shugenja — every technique, every instinct is oriented toward keeping the person behind them alive. High Defense and Willpower reflect a warrior who absorbs blows meant for others. On the Battlefield Bubble, Shiba Bushi position themselves between friendly shugenja and the nearest threat.

ELEMENTAL GUARD. Air 4 | Earth 3 | Fire 4 | Water 3 | Void 3 | Intelligence 5, Willpower 4. Honor: 4.5 | Status: 2.0 | Insight Rank: 3 | School Rank: 2. Skills: Spellcraft 5, Lore: Theology 3, Meditation 3, Defense 1, Athletics 1. Equipment: staff or knife, no armor, scroll satchel. Spells: 5–6 combat-relevant elemental spells (Mastery Level 1–3). The most devastating magical force in Rokugan — Isawa-trained battle shugenja organized into four elemental legions. They do not fight with weapons. They fight with fire, earth, wind, and water. On the Battlefield Bubble, Elemental Guard cast area-effect spells targeting clusters of enemy soldiers. Individually fragile in melee — if enemies reach them, they are in serious danger. That is what the Shiba are for.

ELEMENTAL LEGIONS. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Willpower 4. Honor: 5.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Defense 3, Spellcraft 1, Athletics 2, Battle 2, Meditation 1. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). Shiba warriors trained specifically to fight alongside the Elemental Guard — they understand the rhythm of spell-casting and know how to press into the gaps that elemental magic creates. On the Battlefield Bubble, Elemental Legions always position adjacent to Elemental Guard shugenja. Separated from their shugenja they fight as standard Shiba Bushi with no special advantage.

**Scorpion Clan**

BAYUSHI BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Awareness 4. Honor: 2.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Sincerity 2, Defense 2, Stealth 2, Athletics 2, Intimidation 2. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). The Scorpion’s line soldier — competent swordsmen who fight dirty when clean fighting fails. They read opponents, exploit hesitation, and finish the wounded without ceremony. Individually comparable to an Akodo but with lower Honor and fewer scruples about how the kill happens.

BLACK CABAL. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 2 | Agility 4, Awareness 4. Honor: 1.5 | Status: 1.5 | Insight Rank: 2 | School Rank: 2 (Bayushi Bushi). Skills: Kenjutsu 4, Intimidation 4, Defense 2, Stealth 3, Athletics 2. Equipment: katana, wakizashi, black-lacquered heavy armor (Armor TN bonus +10, Reduction 5). Elite Bayushi Bushi selected for psychological warfare. They fight in eerie silence, never speaking, never removing their masks. The armor is as much psychological weapon as protection. On the Battlefield Bubble, enemies adjacent to a Black Cabal soldier are affected by Fear 1 — not supernatural Fear, just the visceral dread of fighting something that shows no emotion and no hesitation.

SCORPION’S CLAWS. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Reflexes 4. Honor: 1.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2 (Bayushi Bushi). Skills: Knives 4, Defense 2, Stealth 3, Athletics 2, Craft: Poison 1. Equipment: paired sai, wakizashi, light armor (Armor TN bonus +5, Reduction 2), poison kit (1 dose Night Milk). Bayushi Bushi who specialize in sai and poison. They don’t kill quickly — they degrade. Poison applied to their sai inflicts cumulative penalties on anyone they wound. A prolonged fight against the Claws is a losing proposition even if you’re winning the exchange, because every cut makes the next one worse. Light armor for speed — they rely on the sai’s defensive trapping capability and their own agility rather than heavy protection.

**Unicorn Clan**

SHINJO BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Perception 4. Honor: 4.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Horsemanship 3, Hunting 2, Defense 2, Athletics 2, Battle 1. Equipment: katana, wakizashi, yumi (bow), light armor (Armor TN bonus +5, Reduction 2). Mount: Unicorn Riding Horse (Section 54.1). The Unicorn’s baseline samurai — scouts and riders who fight from horseback. Mounted, they gain the Mounted/Higher bonus (+1k0 attack vs unmounted) and the Unicorn Riding Horse attacks independently with a single Horsemanship/Awareness TN 10 roll at the start of battle. Dismounted they fight as competent but unremarkable bushi. Their value is mobility.

WHITE GUARD. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 2 | Agility 5, Strength 4. Honor: 3.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2 (Moto Bushi). Skills: Kenjutsu 4, Heavy Weapons 3, Horsemanship 3, Defense 1, Athletics 3, Intimidation 3, Lore: Shadowlands 1. Equipment: scimitar or heavy weapon, katana, medium armor (Armor TN bonus +5, Reduction 3), white kabuki mask. Mount: Unicorn Riding Horse (Section 54.1). Moto heavy cavalry — fanatical finishers who smash through weakened formations. The white kabuki mask is the family’s mark of shame and determination after the fall of Moto Tsume. Low Defense reflects aggression over self-preservation. They hit what’s already hurting and don’t stop until it’s dead.

UTAKU BATTLE MAIDENS. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 3 | Agility 5, Reflexes 4. Honor: 6.0 | Status: 2.0 | Insight Rank: 3 | School Rank: 2 (Utaku Battle Maiden). Skills: Kenjutsu 4, Horsemanship 5, Defense 3, Athletics 3, Battle 2. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). Mount: Utaku Battle Steed (Section 54.1 — fights willingly without skill roll, Fear 2 when charging, Reduction 5, stays with rider even in death). The most elite cavalry in the Empire. Female only. The steed is not equipment — it is a bonded partner that attacks independently as a Simple Action. Mounted, the Battle Maiden and her steed fight as two coordinated combatants. Dismounted, she fights as a strong but conventional bushi who has lost half her capability.

**Mantis Clan (Minor Clan)**

YORITOMO BUSHI. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Strength 4. Honor: 3.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Knives 2, Jiujutsu 2, Defense 2, Athletics 3, Sailing 2. Equipment: katana, wakizashi, kama or sai, medium armor (Armor TN bonus +5, Reduction 3). Scrappy Minor Clan fighters who find and exploit gaps in an opponent’s guard. On land they are outclassed by Great Clan elites — they lack the institutional depth and training resources. What they have is relentless aggression and experience fighting dirty against opponents who underestimate them.

STORM RIDERS. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 3 | Intelligence 4, Willpower 4. Honor: 3.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2 (Yoritomo Shugenja). Skills: Spellcraft 3, Sailing 2, Meditation 2, Defense 1, Athletics 2, Knives 1. Equipment: knife, no armor, scroll satchel. Spells: 3–4 storm and weather-related elemental spells (Mastery Level 1–2). Yoritomo shugenja who weaponize weather. On the Battlefield Bubble, they buff adjacent Mantis soldiers with wind and rain magic. Their full potential is naval — on land they are competent battle shugenja but nothing the Isawa or Tamori would fear.

STORM LEGION. Air 3 | Earth 3 | Fire 4 | Water 3 | Void 2 | Agility 4, Stamina 4. Honor: 3.5 | Status: 1.5 | Insight Rank: 2 | School Rank: 2 (Yoritomo Bushi). Skills: Kenjutsu 4, Knives 3, Jiujutsu 3, Defense 2, Athletics 4, Sailing 3. Equipment: katana, wakizashi, kama, medium armor (Armor TN bonus +5, Reduction 3). The Yoritomo’s finest — veterans of boarding actions and beach assaults who have fought in every kind of terrain and weather. They suffer no terrain movement penalties on the Battlefield Bubble or ship decks — wet planking, rolling decks, rigging obstacles, and unstable footing do not slow them. High Athletics reflects years of climbing ship rigging, fighting on wet decks, and storming beaches in full armor. On land they are the most adaptable infantry in the game — forest, mountain, urban, it doesn’t matter. They’ve fought in worse.

**Minor Clans**

TSURUCHI ARCHER (Wasp Clan). Air 4 | Earth 2 | Fire 3 | Water 3 | Void 2 | Reflexes 5, Perception 4. Honor: 3.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kyujutsu 5, Hunting 3, Athletics 2, Defense 1. Equipment: yumi (bow), tanto, light armor (Armor TN bonus +5, Reduction 2). The finest archers in the Empire — no one outdraws a Tsuruchi. Highest individual ranged Attack of any unit in the game. In melee they are nearly helpless — Defense 1 and a tanto. On the Battlefield Bubble, Tsuruchi Archers hold the deepest rear positions and kill from distance. If the front line breaks and enemies reach them, they die.

ICHIRO BUSHI (Badger Clan). Air 2 | Earth 4 | Fire 3 | Water 3 | Void 2 | Stamina 5, Strength 4. Honor: 3.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Heavy Weapons 4, Jiujutsu 3, Defense 2, Athletics 3, Hunting 2. Equipment: tetsubo or ono (heavy weapon), katana, heavy armor (Armor TN bonus +10, Reduction 5). Mountain fighters who hit like Crab and ignore terrain that would slow anyone else. The Ichiro school teaches overwhelming force — heavy weapons and unarmed grappling, no subtlety. On the Battlefield Bubble, they suffer no movement penalties from Hills or Mountain terrain tiles.

USAGI BUSHI (Hare Clan). Air 3 | Earth 2 | Fire 3 | Water 3 | Void 2 | Agility 4, Reflexes 4. Honor: 4.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Athletics 4, Stealth 2, Hunting 2, Defense 1. Equipment: katana, wakizashi, light armor (Armor TN bonus +5, Reduction 2). Light, fast hunters built for pursuit and ambush. The Usagi fight with leaping attacks and rapid repositioning rather than holding ground. Low Defense and Earth reflect minimal armor and a frame built for speed over endurance. On the Battlefield Bubble, they move faster than other infantry and hit hardest when attacking enemies already engaged with someone else.

TOKU BUSHI (Monkey Clan). Air 2 | Earth 3 | Fire 3 | Water 3 | Void 2 | Willpower 4, Stamina 4. Honor: 5.0 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Defense 2, Athletics 2, Battle 1, Lore: Bushido 2. Equipment: katana, wakizashi, medium armor (Armor TN bonus +5, Reduction 3). The Toku school teaches endurance through faith — Willpower reduces wound penalties, conviction keeps them standing when better-equipped samurai would break. Not flashy, not powerful, but extraordinarily stubborn. On the Battlefield Bubble, Toku Bushi fight at reduced wound penalties and do not change behavior when outnumbered or facing stronger opponents.

MORITO BUSHI (Ox Clan). Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4, Strength 4. Honor: 3.5 | Status: 1.0 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 3, Heavy Weapons 2, Horsemanship 3, Defense 2, Athletics 2, Lore: Kolat 1. Equipment: katana, wakizashi, heavy weapon or polearm, light armor (Armor TN bonus +5, Reduction 2). Mount: Rokugani Pony (Section 54.1). The only Minor Clan cavalry unit in the game. Trained across multiple weapon types on the mountain-plain border between Unicorn and Lion territory. On the Battlefield Bubble, they gain the Mounted/Higher bonus and their mount attacks independently. Not as fast or well-mounted as the Unicorn — Rokugani Ponies, not Unicorn Riding Horses — but mounted samurai are mounted samurai.

SUZUME BUSHI (Sparrow Clan). Air 2 | Earth 2 | Fire 2 | Water 3 | Void 2 | Willpower 4, Stamina 3. Honor: 5.5 | Status: 0.5 | Insight Rank: 2 | School Rank: 2. Skills: Kenjutsu 2, Staves 2, Defense 2, Athletics 2, Lore: Bushido 2, Storytelling 2. Equipment: katana, wakizashi or staff, no armor or light ashigaru armor at best. The poorest samurai in the Empire — they cannot afford proper equipment and it shows. Low Attack, low Defense, low everything except the one thing money cannot buy: the absolute refusal to quit. The Sparrow have survived centuries of poverty and near-destruction on philosophical conviction alone. On the Battlefield Bubble, they are the weakest individual fighters of any samurai unit but they do not break, do not flee, and do not stop.

**Ronin**

RONIN. Air 3 | Earth 3 | Fire 3 | Water 3 | Void 2 | Agility 4. Honor: 1.5 | Status: 0.0 | Insight Rank: 2 | School Rank: 1. Skills: Kenjutsu 3, Defense 1, Athletics 2, Hunting 1. Equipment: katana, wakizashi, light armor (Armor TN bonus +5, Reduction 2) or no armor. Wave men — samurai without a lord. Comparable to a Bushi Retainer in raw stats but with lower School Rank (most ronin never completed full training or lost access to advanced techniques), worse equipment (no clan armory supplying them), and no clan loyalty. They fight for Koku. Some are honorable warriors fallen on hard times. Most are not. On the Battlefield Bubble, ronin hired as mercenary Companies fight competently but are the first to reconsider their employment if the battle turns badly.

⚙️ CROSS-REF: Army View Company stats are defined in Section 11.6. Army combat and terrain effects are in Section 11.7. Individual combat rules are in Section 40. Iaijutsu duel rules are in Section 4.8.1. Horse stat blocks (Rokugani Pony, Unicorn Riding Horse, Utaku Battle Steed) are in Section 54.1. Bandit archetype stat block format is in Section 54.8. Quest mission ASCII map templates are in Section 56. Hostage mechanics for captured enemies are in Section 22.9. The Mounted/Higher combat status is in Section 40. Horsemanship skill and mastery abilities are in Section 24.2.

**HORDE DEFENSE BATTLEFIELD BUBBLE — WALL VARIANT — LOCKED**

When a player character is stationed on the Kaiu Wall during a Shadowlands horde assault (Section 2.4.5), a Wall-specific Battlefield Bubble generates instead of the standard open-field variant. The Army View resolves the overall assault at Company level. The bubble represents the player's immediate section of Wall — what they see and fight from their position on the battlements.

Map Layout: 20×20, oriented as a cross-section of a Wall segment. Top rows (rows 1–6): the Wall walkway. Battlements provide hard cover (+10 Armor TN from ranged attacks originating below). Arrow slits allow ranged attacks downward at +0 TN modifier. Drop points (2–3 per map) allow defenders to pour boiling oil or drop rocks on climbers (Simple Action, 4k3 damage to all creatures on the target Wall-face tile, no attack roll required). The walkway is defender territory — friendly soldiers hold positions here. Middle rows (rows 7–14): the Wall face. This is where attackers climb. Ladders and grappling hooks appear on random Wall-edge tiles at the start of each Battle Turn wave. Creatures ascending a ladder move 2 tiles upward per round. Creatures climbing without a ladder (Ogres, Trolls — raw strength) move 1 tile upward per round. A defender adjacent to a ladder can destroy it as a Simple Action (Strength TN 15 or weapon strike against the ladder), dropping all creatures currently on it. Dropped creatures take 3k3 falling damage. Bottom rows (rows 15–20): the ground below the Wall. The horde masses here. Ranged defenders on the walkway can fire into the ground zone at normal range penalties. Creatures in the ground zone are assembling ladders, waiting for gaps, or beginning their climb. The player cannot descend to the ground zone — there is no way down from the walkway during the assault.

Friendly Force: The player's section of Wall is manned by 8–12 friendly Crab soldiers: Hida Bushi (heavy infantry holding the walkway), Hiruma Scouts (ranged support from arrow slits), and potentially a Kuni Witch-Hunter if one is assigned to this tower. All use their individual stat blocks from the soldier stat block section above. Named commanders (Gunso+) use their full character sheets.

Enemy Composition: Shadowlands creatures spawn at the bottom edge each Battle Turn in waves. The wave composition is drawn from the horde's Army View composition — if the horde is Bakemono-heavy, the bubble sees mostly Bakemono. If Ogres are present in the Army View, Ogres appear in the bubble. Wave size scales with the horde's current Health — a fresh horde sends 8–12 creatures per wave, a damaged horde sends 4–6. Creatures that reach the walkway engage defenders in melee. Creatures use their individual stat blocks from Section 54.9 (Goblin/Bakemono, Zombie, Troll, Ogre, Bog Hag all have full L5R stat blocks). Company-level subtypes (Bakemono Archer, Undead Revenant, etc.) are variations on these base stat blocks.

Wave-Based Resolution: The bubble does not end when the map is cleared. New enemies spawn each Battle Turn as long as the horde has Health remaining in the Army View. The player is holding their section of Wall until the overall assault is resolved — either the horde breaks (Army View Health drops low enough) or the garrison is overrun. Clearing a wave buys breathing room until the next wave climbs. The Army View state feeds the bubble: if the garrison is winning overall, waves get smaller and less dangerous. If losing, waves intensify and creatures start reaching the walkway faster. A garrison Company being routed in the Army View means friendly soldiers on the bubble start dying or fleeing — the player's section thins out.

Shadowlands-Specific Mechanics: Morale is largely irrelevant for the attackers — Undead have no Morale, Ogres fight until killed, only Bakemono can rout and they are driven forward by what is behind them. The defenders' morale matters: Crab garrison soldiers are the highest-Morale units in the game for defensive combat (+2 Defense inside own settlement), but watching their comrades die to oni still tests them. Taint exposure applies if Tainted creatures breach the walkway and engage in melee — per Section 42, physical contact with heavily Tainted creatures requires Earth rolls. Jade weapons deal bonus damage to Tainted creatures per existing rules. The Kuni Witch-Hunter's value is detecting which creatures carry the heaviest Taint and calling targets for jade-equipped defenders.

Key Tactical Decisions: Defend the ladders (stop creatures from reaching the walkway — reactive but safe) vs destroy the ladders (proactive but requires exposing yourself at the Wall edge). Concentrate defenders at one breach point vs spread across multiple. Use the drop points early (devastating but limited uses — oil and rocks are finite) vs save them for when Ogres or Trolls appear. Protect the Kuni Witch-Hunter (their jade wards and Taint detection keep the section fighting longer) vs let them fend for themselves while you hold the line.

Resolution: The bubble ends when the Army View resolves the assault — either the horde breaks and retreats, or the garrison falls. If the player's section of Wall holds until the horde breaks: +0.3 Glory, potential Heroic Opportunity rewards from the Battle Table (the player rolls the Battle Table each Battle Turn as normal). If the walkway is overrun and the player survives (retreats to the tower interior): the section is lost, the Army View reflects the breach, and the assault may continue at other sections. If the player is killed or incapacitated on the Wall: standard character death rules (Section 22.5).

⚙️ CROSS-REF: Tower assault rules in Section 2.4.5. Shadowlands creature Company roster in Section 2.4.7. Individual creature stat blocks in Section 54.9 (full bestiary: 20+ Shadowlands beasts, 7 goblin variants, spirit realm creatures for all 11 realms, elemental terrors, homebrew spirits, undead, mundane animals, legendary creatures — 273 total stat blocks across the document). Horde generation in Section 2.4.10. Kaiu Wall structure in Section 2.4. Taint mechanics in Section 42. Jade economy in Section 2.4.15.

**BATTLE EVENTS**

One Battle Event fires per round, determined by random roll with contextual weighting. Events represent the chaos of battle — they are opportunities, not punishments (though some are punishing). Successfully resolving an event reduces its negative impact or amplifies a positive one. Events are triggered by dice rolls during automated battle resolution, not by player choice. Players may encounter an event and choose how to respond in the ASCII Map view.

- The Wavering Line: A key Company’s Morale is critically low. A player character may attempt Rally (TN 20) this round as a free action in addition to their normal Heroic Event. Failure means the Company routs without a standard Morale check.

- Messenger Down: A courier carrying critical orders has been killed. The Rikugunshokan’s command bonus does not apply this round unless a player character personally carries orders to the affected unit (Movement check TN 15 in the ASCII Map view).

- Opening in the Line: The enemy’s formation has a gap. A player character can exploit it — Battle (TN 20) to direct a friendly cavalry unit through the gap, granting a flanking attack this round without using a flank slot.

- The Enemy Champion: A notable enemy warrior challenges any samurai on our side to personal combat. Ignoring the challenge deals –2 Morale to all friendly Companies (seen as cowardice). Accepting triggers a Heroic Duel. Winning restores 1 Morale to all friendly Companies.

- Terrain Shift: Weather changes, smoke from fires, or failing light alter the terrain conditions mid-battle. One terrain modifier is added or removed (GM/system chooses). This can benefit either side depending on composition.

- Ambush Revealed: A hidden unit (scout information missed) appears. One enemy Company that was in “Reserve” is revealed to have been flanking all along. Immediate flanking attack this round. Player characters may have noticed signs — if any player made a successful Hunting or Perception roll earlier in the session, they may negate this event.

**COMMANDER RISK: INJURY ****&**** DEATH**

Named commanders (Gunso through Rikugunshokan) are at risk of injury or death during battle. Risk is tied to the Health of their Company—a commander is relatively safe while their unit holds, but becomes increasingly exposed as casualties mount. Commander survival uses the L5R XkY dice system (per Section 11.7).

**The Survival Roll:** When a threshold is triggered, the commander rolls Earth k Earth + Mass Combat Skill vs the Threshold TN. Roll a number of dice equal to Earth + Mass Combat Skill, keep the highest Earth dice, add Mass Combat Skill rank to the kept total.

**Threshold TNs:**

- Company below 75% Health — TN 10. Each threshold triggers only once per engagement.

- Company below 50% Health — TN 15.

- Company below 25% Health — TN 20.

- Company routed or destroyed — TN 25.

**Outcomes:**

- Beat the TN: Survived unharmed.

- Fail by 1–3: Injured. Commander’s bonus no longer applies for the remainder of the battle. Commander survives and may return in future battles.

- Fail by 4+: Dead. Commander is permanently removed from the world. Company takes a severe Morale hit—triggers the full commander death Morale damage roll. Named character is gone.

ASCII Event Risk: Commander risk during ASCII events (duels, ambushes, etc.) is resolved entirely within the ASCII map using the full L5R individual combat system—wound levels, wound penalties, and death as natural outcomes. This is separate from the threshold system.

**ROUT RESOLUTION**

When all of one side’s Companies have routed or been destroyed, the battle ends. Rout resolution has two phases (per Section 11.7):

**Phase 1 — Pursuit Casualties:**

- Light Cavalry present: 1d10 + 25% of routing army’s remaining Health destroyed. Range: 26–35%.

- No Light Cavalry: 1d10 + 5% of routing army’s remaining Health destroyed. Range: 6–15%.

**Phase 2 — Outcome:** Compare the routing army’s remaining Health to its starting Health. This is an army-wide calculation—total remaining Health across all surviving Companies vs. total starting Health across all Companies that entered the battle.

- Above 20% remaining Health: Army retreats to the previous sub-tile it came from. It regroups and still exists on the World Map in a weakened state. It can be rebuilt, resupplied, or reinforced.

- At or below 20% remaining Health: Army is dissolved entirely. All units are removed from the World Map. Health losses convert back to PU loss on the province the army was drawn from.

**POST-BATTLE RECOVERY**

After a battle, the victorious army has time to tend to its wounded. This applies only to the winning army—the losing army’s recovery is handled entirely by the Rout Resolution system. Recovery only applies to Health lost during battle, not to Companies that were fully destroyed (per Section 11.7).

- 10% of total Health lost during battle is recovered—wounded soldiers patched up and returned to fighting fitness. Health is restored to their respective Companies.

- 10% of total Health lost during battle is returned to source provinces as PU—too injured to keep fighting but healthy enough to go home. These people rejoin the civilian population.

- 80% of total Health lost during battle is permanently dead—subtracted from source province PU as normal losses.

- Ronin Companies: the 10% recovery still applies to their Health pool, but neither the recovered nor the returned PU has a source province to go to. Recovered Ronin Health stays in the Company; there is no PU return for Ronin losses.

Example: A victorious army lost 300 total Health across all Companies. 30 Health is restored to their Companies. 30 Health worth of PU is returned to the relevant source provinces. 240 Health worth of PU is permanently dead.

**MASS BATTLE ****&**** THE L5R 4E TABLETOP SYSTEM**

This system is directly inspired by the L5R 4th Edition tabletop Mass Battle rules. In the tabletop system, most of the battle is automated through a series of Battle Skill rolls against a set Battle TN, with each success or failure shifting the Battle Momentum toward one side. Player characters make Heroic Opportunity rolls that allow them to personally influence the outcome. The video game adaptation preserves this philosophy: the battle’s outcome is primarily determined by army quality, commander skill, and formation decisions — not by player micromanagement. Player characters are heroic exceptions, not battle managers.

The key design tension this creates is intentional: a player whose lord has a superior army can still lose the battle through poor formation decisions and missed Heroic Events. A player whose lord has an inferior army can still win through brilliant play and exceptional Heroic Event performance. The army is the context. The character is the hero.

