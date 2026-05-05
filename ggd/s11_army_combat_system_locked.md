## 11.7 Army Combat System — LOCKED

The army combat system is inspired by Crusader Kings 2 and Victoria II. Combat is abstracted at the army level — players do not micromanage formations in real time. The drama lives at the character level, not the unit management level. The army is a consequence of political and economic choices; the battle is where named characters prove their worth.

**The Army View — Victoria II Grid Combat:**

Companies are arranged on a grid. Each Company fights the Company directly in front of it. If no enemy Company is in front, the unit automatically attempts to flank. Archer Companies occupy a rear row, firing support attacks at the enemy Company in front of their paired Melee Company. Most of the resolution is automated — dice rolls modified by unit stats, commander traits, and player character effects.

- Melee Companies form the front row and fight the enemy Company directly opposite them.

- Archer Companies sit in the row behind Melee Companies, providing ranged support fire against the enemy Company in the same column.

- No enemy in front = automatic flanking attempt against an adjacent enemy Company.

- Resolution: dice rolls + modifiers from unit quality, named commanders at each level (Gunso through Rikugunshokan), and player character presence.

- Formation structure (Vanguard, Main Body, Rear Guard, Flank Guards) influences pre-battle setup and modifier calculations but is not micromanaged in real time.

**Company Stats — LOCKED:**

The Company (Kaisha) is the base unit of the Army View battlefield. Each Company has five stats. All stats use a 1–10 scale, matching the 1d10 attack roll. Health is tied to manpower — a standard Company of 153 troops (7 Squadrons + Gunso commanders + Chui) starts at 153 Health. No shields exist in Rokugan — Defense represents armor quality, training, and formation discipline only.

- Health: Manpower pool, directly tied to Company size. A standard Company starts at 153. Depletes as casualties are taken. Zero Health = Company destroyed.

- Attack: Offensive capability. Added to the 1d10 attack roll. Modified by Chui stats, commander bonuses, terrain, flanking, player Heroic Events, and unit type matchups.

- Defense: Damage absorption through armor and training discipline. Subtracted from incoming attack totals to reduce Health damage.

- Morale: Will to fight. A parallel pool to Health. Depletes under pressure from casualties, flanking, and commander death. Zero Morale = rout attempt.

- Morale Defense: Resistance to Morale damage. Varies significantly by unit type — Ashigaru break easily, Bushi Retainers embrace death, Clan Elites are hardest to break.

**Universal Unit Stat Blocks — LOCKED:**

The following are the six universal units available to all clans. These are baselines before any commander, terrain, or player modifiers are applied. Clan-specific elite units are designed separately.

**Peasant Levy**

- Health: 153 | Attack: 1 | Defense: 1 | Morale: 8 | Morale Defense: 1

- Special: None.

- Notes: Barely functional. Attack and Defense of 1 means they contribute almost nothing offensively and fold quickly. Their only value is absorbing hits and buying time. Temporary — levied from village PU, must be released back to farming.

**Ashigaru Spearmen**

- Health: 153 | Attack: 3 | Defense: 4 | Morale: 12 | Morale Defense: 3

- Special: +3 Attack vs Cavalry.

- Notes: Front line infantry. Defense of 4 reflects formation discipline and spear-and-armor training. The anti-cavalry bonus is their defining trait. No shields — Defense is purely armor and training.

**Ashigaru Archers**

- Health: 153 | Attack: 4 | Defense: 2 | Morale: 10 | Morale Defense: 2

- Special: −3 Attack when engaged in melee (not trained for close combat).

- Notes: Ranged support unit. Positioned behind Melee Companies. Higher Attack than Spearmen at range but poor Defense. Morale Defense of 2 means they break quickly if directly engaged. Vulnerable if the front line collapses.

**Bushi Retainer**

- Health: 153 | Attack: 6 | Defense: 5 | Morale: 18 | Morale Defense: 8

- Special: None.

- Notes: The professional backbone of any clan army. Balanced high stats across the board. High Morale and Morale Defense reflect Bushido — trained samurai embrace death and do not break easily. The significant jump from Ashigaru reflects genuine training, equipment quality, and martial discipline.

**Light Cavalry**

- Health: 153 | Attack: 3 | Defense: 2 | Morale: 11 | Morale Defense: 4

- Special: +4 Attack bonus when flanking. Cannot be counter-attacked while flanking — the target must direct its counter-attack at the unit attacking from the front, regardless of Defense values.

- Notes: Universal flanking specialist. Low Attack and Defense in direct confrontation — their value is entirely in the flanking special rule. Moderate Morale reflects cavalry confidence but they are not suicidal. Dangerous when used to exploit gaps in the enemy line. Fragile if caught in a direct frontal engagement.

**Ronin**

- Health: 153 | Attack: 5 | Defense: 4 | Morale: 10 | Morale Defense: 4

- Special: None.

- Notes: Auxiliary forces. Similar capability to Bushi Retainers but slightly weaker overall. Notably lower Morale Defense — fighting for coin rather than conviction, they hold well individually but break faster under sustained pressure. Hired with Koku, no levy required, no clan affiliation. No Honor consequences for disbanding.

**Garrison**

- Health: 153 | Attack: 3 | Defense: 5 | Morale: 16 | Morale Defense: 7

- Special: +2 Defense when fighting inside their own settlement (castle or town).

- Notes: Not designed for open field combat. Trained to hold a position, defend walls, harass supply tethers, and suppress internal unrest. Moderate Defense reflects knowledge of their own ground and prepared positions. Low Attack — not trained for offensive operations. High Morale and Morale Defense reflect the motivation of defending one's home. Fragile in open field engagements where their positional advantage does not apply.

**Combat Round Resolution — LOCKED:**

Each round resolves simultaneously between opposing Companies:

- Step 1 — Attack Roll: Both Companies roll 1d10 and add their Attack stat.

- Step 2 — Apply Defense: Subtract the defending Company's Defense from the attacker's total. The remainder is Health damage dealt. Minimum 0.

- Step 3 — Apply Health Damage: Reduce each Company's Health accordingly.

- Step 4 — Morale Check: After Health damage is applied, each Company makes a Morale check. The check is influenced by: how much Health was lost this round (sudden heavy loss = harder check), current Health percentage (lower Health = harder check), and any outstanding effects (flanking, commander death, losing adjacent Companies). If the check fails, Morale drops by a value determined by the severity of the check.

- Step 5 — Rout Check: If Morale hits zero, the Company attempts to rout — fleeing through the nearest unoccupied side. If all four sides are occupied by enemy units, the Company cannot rout and fights to the death until Health reaches zero.

**Flanking Rules — LOCKED:**

Every Company has four sides. A flanking Company attacks an exposed side of an already-engaged enemy.

- The flanking Company attacks with +2 Attack. PROVISIONAL.

- The flanking Company does NOT receive a counter-attack that round — the enemy is already engaged on another side.

- The flanked Company takes Health damage from both attackers simultaneously.

- The flanked Company suffers an immediate Morale penalty from being hit from an unexpected direction.

- The flanked Company directs its single counter-attack at whichever of its two attackers has the lower Defense — instinctively targeting the easier threat. Exception: Light Cavalry cannot be counter-attacked while flanking regardless of Defense values.

- Complete encirclement (all four sides occupied by enemies): the Company cannot rout. Morale collapses rapidly. The unit fights to the death. This is a near-certain destruction condition.

**Morale Damage Formula — LOCKED:**

Morale damage is resolved as a separate roll after Health damage is applied each round. When a Morale check is triggered:

- Roll 1d10 and subtract the unit's Morale Defense. The remainder is Morale damage dealt. Minimum 0.

- A Peasant Levy (Morale Defense 1) takes up to 9 Morale damage per check. A Bushi Retainer (Morale Defense 8) rarely takes more than 1 or 2.

**Morale Check Triggers and Modifiers — LOCKED:**

The following events trigger a Morale check. Multiple triggers in the same round stack — a flanked Company that just lost its Chui and is below 50% Health faces a very severe check.

- Flanking hit: Roll normally, no modifier.

- Heavy Health loss this round (lost more than 25% of current Health in one round): +2 to the Morale damage roll.

- Low Health (currently below 50% Health): +1 to the Morale damage roll.

- Death of the Company's Chui: +3 to the Morale damage roll.

- Death of a higher commander (Taisa, Shireikan, Rikugunshokan): +4 to the Morale damage roll for all Companies under that commander's authority.

- Complete encirclement (all four sides occupied): No roll — automatic maximum Morale damage every round until the Company is destroyed.

**TBD — PENDING:** *Encirclement Morale damage: automatic 10 per round, bypassing Morale Defense entirely. Peasant Levy (Morale 8) destroyed in 1 round, Bushi Retainer (18) in 2, Lion’s Pride (22) in 3. Deathseekers immune. Value PROVISIONAL.*

**Commander Survival System — LOCKED:**

Named commanders (Gunso through Rikugunshokan) are at risk of injury or death during battle. Risk is tied to the Health of their Company — a commander is relatively safe while their unit holds, but becomes increasingly exposed as casualties mount. Commander survival uses the L5R XkY dice system, reflecting that personal skill and resilience determine whether a commander survives.

**The Survival Roll:**

When a threshold is triggered, the commander rolls: Earth k Earth + Mass Combat Skill vs. the Threshold TN.

- Roll a number of dice equal to Earth + Mass Combat Skill, keep the highest Earth dice, add Mass Combat Skill rank to the kept total.

- A weak commander (Earth 2, Mass Combat 1) rolls 3k2 — genuinely fragile on the battlefield.

- A veteran bushi (Earth 4, Mass Combat 3) rolls 7k4 — hard to kill.

- An exceptional general (Earth 5, Mass Combat 5) rolls 10k5 — survives nearly anything short of a complete rout.

**Threshold TNs:**

- Company below 75% Health — TN 10. Each threshold triggers only once per engagement.

- Company below 50% Health — TN 15.

- Company below 25% Health — TN 20.

- Company routed or destroyed — TN 25.

**Outcomes:**

- Beat the TN: Survived unharmed. No effect.

- Fail by 1–3: Injured. Commander's bonus no longer applies for the remainder of the battle. Company takes an immediate Morale hit. Commander survives and may return in future battles.

- Fail by 4+: Dead. Commander is permanently removed from the world. Company takes a severe Morale hit — triggers the full commander death Morale damage roll already locked. Named character is gone.

**ASCII Event Risk:**

Commander risk during ASCII events (duels, ambushes, etc.) is resolved entirely within the ASCII map using the full L5R individual combat system — wound levels, wound penalties, and death as natural outcomes of the event. This is separate from the threshold system and can kill or injure a commander regardless of their Company's Health.

Player characters do not choose their position in battle. They are assigned by their lord prior to engagement. A samurai serves where he is told. Assignment reflects trust, rank, and political standing — a lord who trusts a player character places them somewhere consequential; a lord who does not may assign them to the Rear Guard or Baggage Train escort, which is both a slight and a safer position. Players can influence their assignment through court, reputation, and relationships — but the decision belongs to whoever commands them.

**ASCII Event Interrupts — LOCKED:**

While the battle resolves automatically, player characters periodically trigger special events that pull them into the ASCII map view. These are short, randomly selected scenarios drawn from a pool appropriate to the battle context. Succeeding grants a bonus to the player's Company or beyond; failing applies a malus or has narrative consequences. The scope of the effect is determined by the event itself.

- Events are triggered by rolls during the automated battle resolution — not by player choice.

- Each event is a short ASCII scenario: a duel, protecting the commander, surviving an ambush, rallying broken troops, destroying the enemy baggage train, and so on.

- Local scope events (survive an ambush, rally troops) affect only the player's assigned Company.

- Wide scope events (duel the enemy champion, protect the general, destroy the baggage train) can affect the entire battle or campaign depending on outcome.

- The event communicates its own stakes — a player pulled into a duel with the enemy general knows immediately that what happens next matters beyond their Company.

- This mirrors the L5R tabletop Mass Battle system, where most of the battle is automated but player characters have Heroic Opportunities that let them personally influence the outcome.

**RESOLVED:** Full event pool designed below: 58 Heroic Opportunities across 9 categories (Combat, Target-Specific, Protection, Duel, Non-Combat, Unheroic, Siege, Cavalry, Naval). Each entry specifies trigger conditions, eligibility filters, skill rolls, TNs, success/failure outcomes, ASCII Battlefield Bubble configuration, and Army View stat modifier translation. Translation Table maps every outcome to Company-level modifiers. All values PROVISIONAL.

**⚙️ Formation setup mechanics are fully defined in the Battle Setup section of the revised Army Combat System: players assign Companies to Forward Row slots, Reserve Row slots, and Flank Positions before battle begins. The assignment is the primary pre-battle tactical decision. The Rikugunshokan (or controlling player) makes this assignment; AI commanders use the objective-driven formation logic in Section 55. The setup screen UI — how the player drags and assigns Companies to grid slots in Godot — is a front-end implementation item deferred to the Godot architecture phase (Section 5).**

**11.7a Army Movement on the World Map — LOCKED**

**SUB-TILE STRUCTURE — LOCKED**

Each province is divided into 4–5 sub-tiles on the World Map. Sub-tiles are movement and locality units, not economic units. Resource values (Rice, Koku, Iron) are tracked at province level. Sub-tiles determine where armies are, what settlements they can interact with, and which fortifications provide defensive coverage. A fortification only covers the sub-tile it occupies — an army on a different sub-tile of the same province is not protected by it. Settlements (villages, temples, fortifications) are localized to specific sub-tiles and can be raided, garrisoned, or assaulted based on which sub-tile the army occupies.

**MOVEMENT RATES — LOCKED**

Army movement is measured in whole real days per sub-tile. An army always arrives at the start of a new real day — no army is ever stranded mid-tile between sessions. All terrain costs are whole numbers.

Base terrain costs:

- Plains / Flatlands: 1 real day per sub-tile

- River delta / Coastal lowlands: 1 real day per sub-tile

- Forest / Light hills: 2 real days per sub-tile

- Heavy hills / Rough terrain: 2 real days per sub-tile

- Mountains: 3 real days per sub-tile

- River crossing: +1 real day added to destination sub-tile cost

Seasonal modifiers:

- Winter: all sub-tile crossing times ×2. Plains = 2 days. Forest = 4 days. Mountains = 6 days.

- Spring river crossing: +2 real days total added to destination cost (instead of the normal +1). The extra day represents flooding and high water.

- Summer and Autumn: no modifier. Standard terrain costs apply.

All combinations produce whole numbers. A plains crossing in winter = 2 days. A mountain crossing in winter = 6 days. A river crossing into mountains in winter = 8 days (3 ×2 + 2).

**FORCED MARCH — LOCKED**

A lord may order a forced march, reducing any sub-tile crossing by 1 real day. The minimum crossing time is always 1 real day — this floor cannot be broken. Cost: −5 Morale to all Companies in the army per day saved. Forced march can be applied to every sub-tile crossing if the lord accepts the cumulative Morale cost. An army that force marches repeatedly across difficult terrain arrives faster but significantly degraded.

Example: Forcing a mountain crossing (3 days) to 2 days costs −5 Morale. Forcing it to 1 day costs −10 Morale.

**BATTLE TRIGGER — LOCKED**

When an army moves onto a sub-tile occupied by an enemy army, battle triggers automatically. There is no choice to halt or disengage at the border — contact means combat. This makes intelligence on enemy army positions critical. A lord who does not know where the enemy army is may march directly into it.

**VISIBILITY — LOCKED**

Passive visibility: a commander always sees their own sub-tile and all immediately adjacent sub-tiles. They know if something is present — an army, a fortification, a settlement — without any investment. They cannot be surprised by what is directly next to them.

Active scouting: scouts extend visibility one additional ring beyond the adjacent ring — two sub-tiles out in any direction from the army’s position. This gives advance warning of approaching armies before they reach adjacent range, giving the lord time to react, reposition, or prepare.

A lord who does not invest in scouting operates on passive visibility only. An enemy army two sub-tiles away is invisible until it steps adjacent.

**SCOUTS — LOCKED**

Scouts are named Bushi characters — not a separate unit type, not an abstraction. All scouts are individually tracked named characters assigned to reconnaissance by their lord.

Schools best suited for scouting:

- Hiruma Scout (Crab) — Athletics, Hunting, Stealth, Lore: Shadowlands. Purpose-built for hostile terrain reconnaissance. Rank 1 always knows direction of Empire in Shadowlands. Primary ground scout.

- Daidoji Iron Warrior (Crane) — Athletics, Hunting (Traps), Stealth. Explicitly described as scouting, ambush, and supply caravan interdiction. Excellent concealed reconnaissance.

- Toritaka Bushi (Crab) — Hunting 2, +1k0 Perception at Rank 1. Strong awareness but specialized against Spirit Realm creatures.

- Shinjo / Moto (Unicorn) — Superior mobility and horsemanship. Cover more ground per day than foot scouts. Best for rapid wide-area reconnaissance.

Scouting quality is naturally differentiated by school. A Hiruma Scout gathers more detailed information and moves more quietly. A Shinjo character covers more ground. A lord with Unicorn vassals has a structural intelligence advantage.

**ORDER SYSTEM — LOCKED**

Lords manage their forces through an order system rather than spending personal AP on directing every subordinate. Each lord has 10 orders per real day (4 IC days) to give to characters physically present with them — in their camp, their army, or their settlement.

An order is a directive: “Scout that sub-tile.” “Hold this position.” “Deliver this letter.” The NPC receives the order, executes it, and returns to their lord for the next assignment. The lord does not spend AP supervising the execution — only issuing the direction.

Characters not physically present — vassals executing a task away from the lord — do not consume orders. They operate independently until the task completes and they return. At that point they re-enter the lord’s order pool.

Scouting costs 1 order to assign. A standing patrol — “keep watching that sub-tile” — costs 1 order to set up and continues until recalled. The lord’s own personal AP remains separate and is spent on the lord’s own actions (PERFORM_WORSHIP, WRITE_LETTER, court actions, personal diplomacy, etc.). Military Commander Orders — LOCKED: The order system extends to every level of the military command chain, not only feudal lords. Any character with military_rank (Section 11.3.18a) can issue orders to their direct subordinates — the characters whose operational_superior_id points to them. Taisa issues orders to their Legion’s Chui: garrison this province, detach to support an ally, recall to muster point, hold position. Shireikan issues orders to their Section’s Taisa: deploy your legion to Province X, march to reinforce the border, hold defensive positions. Rikugunshokan issues orders to their Go-hatamoto’s Shireikan: assign your section to the northern front, advance on the enemy capital, pull back and consolidate. Order budget by rank: Chui: 5 orders per real day — they direct a single Company, fewer moving parts. Taisa: 10 orders per real day — same as a lord, they direct 7 Chui across their Legion. Shireikan: 10 orders per real day — they direct 4–12 Taisa. Rikugunshokan: 15 orders per real day — they direct the entire Go-hatamoto through their Shireikan. Physical presence: orders to subordinates in the same location (same settlement, same army on the march) are instant. Orders to subordinates at a different location require a messenger — delivery time equals travel time between the two locations (1 sub-tile per real day, same as army movement). A Taisa whose Legion is spread across three garrisons can issue orders to all Chui, but the order to the distant garrison takes time to arrive. This creates a natural friction for dispersed forces — concentrated armies respond faster than scattered garrisons. Chui do not issue orders to individual soldiers — below Chui, the Company is a PU abstraction. The Chui’s “orders” are Company-level combat actions handled by the Army View (attack, defend, hold, move). Order budget values PROVISIONAL. Provincial Daimyo Military Authority — LOCKED. A Provincial Daimyo does not command Go-hatamoto forces. Standing army Companies belong to the military chain (Chui → Taisa → Shireikan → Rikugunshokan). The Daimyo governs their province (taxes, stability, worship) but the clan army is not theirs to command. To use Go-hatamoto forces, the Daimyo must request a military detachment through the feudal chain (Family Daimyo → Clan Champion → Rikugunshokan). This is a political act that requires authorization and takes time.

Independent military action uses two resources the Daimyo controls directly. First: levy authority. The Provincial Daimyo can raise Peasant Levy and Ashigaru from their own province’s PU using ORDER_LEVY. These levy Companies are under the Daimyo’s direct lord_id authority — not part of the Go-hatamoto hierarchy. They have no parent_legion_id and no parent_section_id. They are ad hoc forces, weaker than standing army units, but available without military chain authorization. Second: household retainers. The Daimyo’s personal samurai (bushi retainers whose lord_id = the Daimyo) can be attached to levy Companies as officers. A retainer assigned as Chui gives the levy Company a named commander — the commander Battle bonus from Section 11.6 applies, and the retainer rolls the Battle Table, triggering Heroic Opportunities that let them personally influence the outcome on the Battlefield Bubble. The retainer is the sharp edge. The levy is the mass.

This creates two tiers of military action. Small-scale (independent): the Daimyo musters levy troops, attaches household retainers as officers, and launches a border raid or punitive expedition. Weak force but under direct authority. The Daimyo takes the Honor cost and political consequences personally. No clan authorization needed. Large-scale (authorized): a real military campaign requires Go-hatamoto Companies. The Daimyo requests detachment through the feudal chain. The Clan Champion decides whether to commit standing army forces. The whole clan is politically involved once professional military deploys.

Natural scaling: a poor Provincial Daimyo with 1 retainer and 1 levy Company can manage a border skirmish. A wealthy one with 5 retainers and 3 levy Companies can mount a serious raid. But neither matches a Go-hatamoto Legion of 7 professional Companies with a Taisa and Reserve Company. The gap between independent action and authorized military force is deliberate — it makes the decision to escalate meaningful.

Levy Company data structure: same Company fields as Go-hatamoto units but parent_legion_id = null, parent_section_id = null, parent_army_id = null. The levy Company’s Chui (if a household retainer is assigned) has operational_superior_id = the Provincial Daimyo’s character_id and military_rank = CHUI. The Daimyo is not a Taisa — they are a feudal lord who happens to have military assets. The levy Companies answer to the Daimyo through lord_id, not through the military operational chain. When the raid is over, the levy can be disbanded (PU returns to civilian status, Arms retained in storage) or maintained as a standing provincial force at ongoing Rice and Koku cost.

Private Army Suspicion: A Provincial Daimyo who maintains a standing levy force for more than one season attracts attention. A levy is meant to be temporary — raised for a specific campaign and disbanded afterward. A lord who keeps armed forces under their direct authority outside the Go-hatamoto structure is building a private army. After 1 season of continuous levy maintenance, a Tier 4 court topic generates: “Lord X maintains armed forces outside clan authority.” The Daimyo’s Family Daimyo and Clan Champion suffer −5 disposition toward them per season the levy persists. Neighboring Provincial Daimyo suffer −3 disposition (suspicion of ambition). If the levy persists for 3+ seasons, the topic escalates to Tier 3 and the Clan Champion may issue a direct order to disband. Refusal to disband is insubordination — grounds for removal from office. Exception: a levy raised during active wartime (War Status involving the Daimyo’s clan) does not trigger suspicion. War justifies the force. The topic fires only when the levy persists into peacetime.

Dual Authority — Daimyo Who Hold Military Rank: Some lords hold both feudal and military authority simultaneously. A Provincial Daimyo who is also a Taisa commands both their province AND a garrisoned Legion. A Family Daimyo who serves as Shireikan commands both their family’s provinces AND a Go-hatamoto section. These dual-authority lords can launch full-scale military operations using Go-hatamoto forces without requesting detachment — they ARE the military commander. No levy needed, no authorization needed. This makes dual-authority lords drastically more powerful than pure feudal lords. The appointment of a competent general who is also a provincial governor is a deliberate strategic decision by the Clan Champion — it concentrates power in one person, which is efficient but politically dangerous. Dual authority is not the default.

Military Service Assignment — LOCKED. When the Go-hatamoto requires officers and troops, the request flows down the feudal chain: Clan Champion → Rikugunshokan → Family Daimyo. The Family Daimyo is the gatekeeper — but they do not personally select every samurai. The met_characters constraint (Section 22.3) applies: the Family Daimyo knows their Provincial Daimyo and major vassals, not every bushi in the family. The request cascades down the feudal chain. The Family Daimyo uses ASSIGN_VASSAL_OBJECTIVE to tell each Provincial and City Daimyo: “provide X bushi for military service.” The Provincial or City Daimyo — who actually knows their retainers — selects the specific samurai using ASSIGN_TO_MILITARY_SERVICE (1 AP). Authority: Provincial Daimyo or City Daimyo (the lord who directly controls the retainers). The selecting lord evaluates their available samurai, applies the commitment protection checks below, and sends the chosen retainers to the army. The assigned samurai’s operational_superior_id is set to their new military commander (Chui, Taisa, etc.). Their lord_id does not change — they remain feudally bound to their Provincial or City Daimyo, who remains feudally bound to the Family Daimyo. The feudal chain is unbroken. Only the operational chain changes.

Commitment Protection: Samurai with existing operational assignments carry a commitment cost that the NPC engine weighs before pulling them. The Family Daimyo’s decision engine evaluates each candidate’s current role and the consequence of removing them. Yojimbo — HIGH commitment. Pulling a bodyguard leaves their charge unprotected. If the charge is a Family Daimyo, Clan Champion, or other high-Status character, the commitment cost is near-prohibitive. The engine scores ASSIGN_TO_MILITARY_SERVICE at −30 for active yojimbo of Status 5+ charges, −15 for Status 3–4 charges. Magistrate — HIGH commitment. Pulling a magistrate leaves a jurisdiction without law enforcement. Crime suppression drops, insurgency detection stalls, active investigations are abandoned. The engine scores −25 for magistrates in provinces with active insurgencies, −15 for magistrates in stable provinces. Yoriki — MEDIUM commitment. Pulling a yoriki weakens an active investigation but does not eliminate law enforcement. The magistrate continues without them. Score −10 for yoriki on active cases, −5 for idle yoriki. Courtier on delegation — MEDIUM commitment. Pulling a courtier from a foreign court abandons diplomatic representation. Score −15 for courtiers at the Imperial Court, −10 for courtiers at clan courts. Shugenja at shrine or temple — LOW-MEDIUM commitment. Pulling a shrine keeper reduces worship effectiveness. Score −5 per active worship bonus the shugenja maintains. Uncommitted samurai — NO commitment cost. Retainers serving their Provincial Daimyo with no specific operational role. These are the first candidates for military service. Score +0.

Selecting Lord Personality Effect (Provincial or City Daimyo): A Jin (Compassionate) lord avoids pulling samurai from roles that protect people (yojimbo penalty doubled). A Yu (Courageous) lord sends their best warriors regardless of role (commitment penalties halved). A Seigyo (Control) lord keeps the most politically useful samurai home and sends the expendable ones. A Chugi (Dutiful) lord fulfills the Rikugunshokan’s request as completely as possible (commitment penalties reduced by −10).

Engine integration note: ASSIGN_TO_MILITARY_SERVICE was added to the ActionID enum when this system was originally designed; at that time, the action brought the total to 117 (86 standard + 31 Kolat). Counts have since increased — see Section 14 master list for the current authoritative ActionID total. Engine wiring: ASSIGN_TO_MILITARY_SERVICE aligns to LEVY_TROOPS (score 80) and DEFEND_PROVINCE (score 60). Annex D skill map: Courtier (Manipulation) + Awareness, Category 2 (Social). The selecting lord is managing people, not fighting.

Military Promotion System — LOCKED. Promotion through the military ranks follows a formal evaluation at each transition. The appointing authority and promotion criteria differ by level. Below Chui: Named NPCs and player characters serving as Hohei, Nikutai, or Gunso gain promotion through demonstrated competence. Hohei → Nikutai: automatic when the character reaches Battle 2 and has participated in at least 1 battle. Nikutai → Gunso: requires Battle 2, participation in at least 1 battle, and a vacancy in the Company’s squadron leadership. The Chui selects the Nikutai to promote. Gunso is the final non-command rank — commanding a guntai of ~20 soldiers within the Company. Unnamed soldiers remain PU abstractions; only named NPCs and player characters track these promotions individually.

Gunso or Retainer → Chui (Company Commander): The critical threshold — a bushi becomes a named military commander. Appointing authority: Taisa (for vacancies in their Legion) or the Family Daimyo via ASSIGN_TO_MILITARY_SERVICE. Trigger: a Company’s commander_id is null (vacancy exists). Criteria the engine evaluates for candidate scoring: Battle skill (weight 30 — the primary military leadership skill), Insight Rank (weight 20 — overall competence), School Rank (weight 15 — training depth), Glory (weight 10 — public reputation for martial achievement), disposition toward the appointing lord (weight 15 — trust), personality fit (weight 10 — Yu and Chugi favoured for frontline command, Seigyo favoured for garrison command). Formula: candidate_score = (Battle × 30) + (Insight Rank × 20) + (School Rank × 15) + (Glory × 10) + (disposition × 0.5) + (personality_fit × 10). Highest-scoring candidate is appointed. Minimum threshold: Battle 3. A character with Battle below 3 is not considered for Chui regardless of other scores — they lack the fundamental skill to command troops. Values PROVISIONAL.

Chui → Taisa (Legion Commander): Appointing authority: Shireikan (for vacancies in their Section) or Rikugunshokan. Trigger: a Legion’s commander_id is null. Candidates: Chui currently serving in the Go-hatamoto. Criteria: Battle skill (weight 35 — even more important at this level), Insight Rank (weight 20), battles fought as Chui (weight 15 — proven command experience, counted from battle_record on character sheet), Glory (weight 10), disposition toward appointing lord (weight 10), personality fit (weight 10 — strategic thinking valued: Seigyo and Dosatsu score well alongside Yu and Chugi). Minimum threshold: Battle 4 and at least 1 battle commanded as Chui.

Taisa → Shireikan (Section Commander): Appointing authority: Rikugunshokan or Clan Champion. Trigger: a Section’s commander_id is null, or the Rikugunshokan reorganises their Go-hatamoto. Candidates: Taisa with distinguished Legion command records. Criteria: Battle skill (weight 35), battles fought as Taisa (weight 20), Insight Rank (weight 15), Glory (weight 10), disposition (weight 10), personality fit (weight 10 — at this level, strategic vision and political awareness matter: Dosatsu, Seigyo, and Chugi score highest). Minimum threshold: Battle 5 and at least 2 battles commanded as Taisa.

Shireikan → Rikugunshokan (Supreme General): Appointing authority: Clan Champion only. This is one of the most consequential appointments in the clan. Trigger: the position is vacant or the Champion decides to replace the current holder. Candidates: Shireikan, Family Daimyo with military experience, or the Champion themselves. Criteria: Battle skill (weight 30), Insight Rank (weight 15), battles fought (weight 15), Glory (weight 10), disposition toward the Champion (weight 20 — trust is paramount for the supreme general), personality fit (weight 10). Minimum threshold: Battle 5. No minimum battle count — political appointment is possible for a Family Daimyo who has never personally commanded in the field. This is historically accurate and creates interesting dynamics when an untested Rikugunshokan faces their first war.

Demotion and Removal: A commander who loses a battle badly (Company routed, Legion shattered) may be demoted or removed. A commander whose disposition toward their appointing lord drops below −10 may be replaced for political reasons. Removal clears the character’s military_rank and commanded_unit_id. They return to their Provincial Daimyo’s retainer pool. Demotion is extremely shameful — the character loses 0.5 Glory. A removed Rikugunshokan who was also a Family Daimyo retains their feudal position but loses military authority.

Battle Record: Each named NPC with military_rank tracks a battle_record: battles_fought (int), battles_won (int), battles_lost (int), Companies_destroyed_under_command (int). This record is the primary experience metric for promotion. A Chui with 5 battles fought and 4 won is a strong Taisa candidate. A Taisa who lost 3 Legions is unlikely to become Shireikan regardless of Battle skill. Most Provincial Daimyo are administrators, not generals. The Go-hatamoto chain is staffed by career military officers (Taisa, Shireikan) who may or may not hold feudal positions. When a Clan Champion assigns military rank to a feudal lord, they are making a political statement about trust and delegation.

**☑ DONE:** *Shugenja in mass battle resolved. There are no generic shugenja units. Only clan-specific militarized shugenja exist: Dragon Yamabushi (Tier 2), Phoenix Elemental Guard (Tier 3), and Mantis Storm Riders (Tier 2). Their magic is baked into their Special stat lines. They fight normally in melee or at range like any other Company. Clans without militarized shugenja traditions (Crab, Crane, Lion, Scorpion, Unicorn) do not field shugenja units — this is a deliberate lore distinction, not a gap. Shugenja-adjacent synergy units (Mirumoto Bushi, Shiba Bushi, Elemental Legions) already reference the “shugenja unit” tag for their adjacency bonuses. Heroic Events for individual shugenja characters in mass battle (the “Spell / Kiho Effect” entry in Section 11.7) require expansion as part of the general Heroic Events design pass — not as a separate shugenja system. See Section 11.6 for full stat blocks.*

**☑ DONE:** *Clan-specific elite unit stat blocks designed. Full roster with stat blocks, specials, cost tiers, and design notes defined in Section 11.6 Clan Elite Unit Roster. Eight clans covered: Crab, Crane, Dragon, Lion, Phoenix, Scorpion, Unicorn, Mantis (Minor Clan).*

**Battle End Conditions — LOCKED:**

A battle ends when one side has been completely destroyed or has fully routed. Both conditions count — a side that still has Companies standing but has lost all Morale across its remaining units collapses just as decisively as one ground to zero Health.

- Complete destruction: All enemy Companies have been reduced to zero Health.

- Full rout: All remaining enemy Companies have hit zero Morale and fled the field.

- Mixed outcome: A battle ends when no Companies capable of fighting remain on one side — destroyed and routed Companies both count toward this total.

**Routing Contagion — LOCKED:**

When a Company routs, nearby allied Companies witness the collapse and suffer an immediate Morale hit. Watching your allies break is demoralizing — this can cascade into a chain rout if the army is already under pressure.

- When a Company routs, all adjacent allied Companies take an immediate Morale damage roll (1d10 − their Morale Defense).

- This can chain — if an adjacent Company also routs from the contagion, their neighbors are affected in turn.

- Well-disciplined units (high Morale Defense) are more resistant to routing contagion. Peasant Levies are especially vulnerable to cascade collapse.

**Rout Resolution — LOCKED:**

When a battle ends in a rout — one side's Companies all flee the field — the victorious army pursues. Rout resolution has two phases: pursuit casualties, then outcome determination.

**Phase 1 — Pursuit Casualties:**

The pursuing army cuts down routing soldiers. The rate depends entirely on whether Light Cavalry is present in the victorious army — no mixed calculation, no partial bonus. Either you have Light Cavalry or you don't.

- Light Cavalry present: 1d10 + 25% of routing army's remaining Health destroyed. Range: 26–35%.

- No Light Cavalry: 1d10 + 5% of routing army's remaining Health destroyed. Range: 6–15%.

- Rationale: Light Cavalry can run down fleeing infantry with ease. Infantry pursuing infantry can only catch the slowest and most exhausted stragglers.

**Phase 2 — Outcome:**

After pursuit casualties are applied, compare the routing army's remaining Health to its starting Health at the beginning of the battle. This is an army-wide calculation — total remaining Health across all surviving Companies vs. total starting Health across all Companies that entered the battle.

- Above 20% remaining Health: Army retreats to the previous sub-tile it came from. It regroups and still exists on the World Map in a weakened state. It can be rebuilt, resupplied, or reinforced.

- At or below 20% remaining Health: Army is dissolved entirely. All units are removed from the World Map. Health losses convert back to PU loss on the province the army was drawn from.

**Battle → World Map: PU Reconciliation — LOCKED:**

Every Company is tagged to its source province at the time of levy. This tag never changes. After battle resolves, Health is reconciled per Company against its source province — the game always knows exactly where to send survivors back to and where to record the dead.

- Each Company has a source province tag set at the time of levy. Permanent samurai units have a permanent home garrison as their source.

- Health lost during battle = PU lost from the source province. These people are dead or permanently incapacitated and do not return.

- Health remaining after battle = PU returned to the source province. Survivors go home.

- Example: A Company tagged to Beiden Village starts at 153 Health and ends the battle at 80 Health. 73 people are dead — 73 Health worth of PU is subtracted from Beiden Village's population permanently.

- Ronin Companies are the exception — they have no source province. Their Health loss simply disappears. No PU is returned because they were not drawn from any province's population.

- A lord who repeatedly levies the same province and commits it to costly battles will genuinely depopulate it over time — feeding directly into the starvation cascade and population dynamics systems.

**Post-Battle Recovery — Victorious Army Only — LOCKED:**

After a battle, the victorious army has time to tend to its wounded. A portion of the Health lost during battle is recovered. This applies only to the winning army — the losing army's recovery is handled entirely by the rout resolution system. Recovery only applies to Health lost during battle, not to Companies that were fully destroyed.

- 10% of total Health lost during battle is recovered — wounded soldiers patched up and returned to fighting fitness. Health is restored to their respective Companies.

- 10% of total Health lost during battle is returned to source provinces as PU — too injured to keep fighting but healthy enough to go home. These people rejoin the civilian population.

- 80% of total Health lost during battle is permanently dead — subtracted from source province PU as normal losses.

- Ronin Companies: the 10% recovery still applies to their Health pool, but neither the recovered nor the returned PU has a source province to go to. Recovered Ronin Health stays in the Company; there is no PU return for Ronin losses.

- Example: A victorious army lost 300 total Health across all Companies. 30 Health is restored to their Companies. 30 Health worth of PU is returned to the relevant source provinces. 240 Health worth of PU is permanently dead.

**Army Upkeep Deprivation — LOCKED:**

An army in the field requires a continuous supply of Rice and Arms delivered via supply lines from its home provinces. If supply lines are cut — by bypassed castle garrisons, enemy raids, or siege — the army begins degrading. Each resource has its own deprivation cascade. Both cascades can run simultaneously and their effects stack.

**Rice Deprivation (Starvation):**

- Tick 1: Warning state. No mechanical effect. Men are hungry but managing.

- Tick 2: −3 Morale to all Companies per tick. Grumbling turns to real suffering.

- Tick 3: −3 Morale AND −5 Health to all Companies per tick. Men are starving and dying.

- Tick 4+: −5 Morale AND −10 Health to all Companies per tick. Army is collapsing. Desertion is rampant.

**Arms Deprivation (Undersupply):**

- Tick 1: Warning state. No mechanical effect. Weapons dulling, armor damaged but still functional.

- Tick 2: −2 Attack, −2 Defense to all Companies. Equipment beginning to fail.

- Tick 3: −4 Attack, −4 Defense to all Companies. Equipment failing badly.

- Tick 4+: −6 Attack, −6 Defense to all Companies. Fighting with broken weapons and damaged armor.

- Note: Arms deprivation maluses apply on top of all other modifiers including terrain and commander bonuses.

**Deprivation Reset:**

- If supply is restored at any point, the deprivation counter resets to Tick 1 (warning state) on the following tick.

- Health and Morale lost to deprivation are NOT automatically recovered when supply is restored — only the ongoing deprivation effect stops. Recovery requires the army to be stationary in a friendly province with supply restored. Rice deprivation recovery (Health): +5 Health per Company per tick while stationary and Rice-supplied. Caps at Company's current maximum Health — deprivation recovery cannot heal battle losses. Rice deprivation recovery (Morale): +3 Morale per Company per tick while stationary and Rice-supplied. Arms deprivation recovery (Attack/Defense): maluses recover at 1 deprivation tier per tick while stationary and Arms-supplied. Tick 4 (−6/−6) → Tick 3 (−4/−4) → Tick 2 (−2/−2) → full. Requires ongoing Arms expenditure through the existing Iron upkeep system (Section 4.3). An army on the march or in enemy territory cannot recover from deprivation — it must stop and rest. All recovery values PROVISIONAL.

**Settlement Defense Tiers — LOCKED:**

Not all settlements require a siege. The type of settlement determines how an army can capture it.

- Village: No defenses. No siege needed. An army simply occupies it. Can be raided, looted, or garrisoned. Militarily trivial but economically meaningful — cutting off a village cuts off that PU from the enemy.

- Town/City: Has walls and a garrison. Requires a siege, but smaller scale than a castle. Shorter food reserves, weaker defenses, faster to reduce. A meaningful but not massive commitment. Food storage and siege duration values specified below (Town Siege Values).

- Castle: Full siege mechanics apply. One castle type only — no small vs. large distinction. Fixed values documented below.

**Castle — Fixed Values — LOCKED:**

- Minimum population: 0.5 PU civilians (~250 people). The minimum needed to run the castle day to day — servants, craftsmen, stable workers.

- Maximum food storage: 2.00 Rice. This storage ceiling also acts as an indirect population cap — the castle cannot support more people than its stores can sustain.

- Standard garrison: 1 PU military.

- Population migration: a lord can order civilian PU to move between existing settlements within their own province. Cost: 1 Civilian Order (Section 57.34). Duration: 1 IC day within the province. Source settlement must retain minimum 0.5 PU after the transfer. Each PU moved carries 1.0 Rice from the source settlement's stockpile (same rule as organic migration, Section 4.3.22). Transfer fails if the source stockpile has less than 1.0 Rice per PU being moved — the migrants need their survival seed. Destination settlement receives the PU and the carried Rice. Used for: filling castle garrison roles, manning a new fortification, rebalancing village sizes after famine. Not available during active siege of the source or destination settlement. Cross-province PU movement uses the existing cross-province migration rules (Section 4.3.22 LOCKED).

**Castle Rice Consumption Per Daily Tick — LOCKED:**

- Civilian PU: 1 PU × (0.25 Rice/season ÷ 90 days) = 0.0028 Rice/PU/daily tick.

- Military PU: 1 PU × (0.35 Rice/season ÷ 90 days) = 0.0039 Rice/PU/daily tick.

- Baseline consumption (0.5 PU civilians + 1 PU garrison): (0.5 × 0.0028) + (1 × 0.0039) = 0.0014 + 0.0039 = 0.0053 Rice/daily tick.

- At maximum storage (2.00 Rice) and minimum population: 2.00 ÷ 0.0053 = ~377 daily ticks (~12.5 real-world months) before starvation.

- If lord shelters 5 PU army inside: additional 5 × 0.0039 = 0.0195. New total: 0.0248 Rice/daily tick. 2.00 ÷ 0.0248 = ~80 daily ticks (~2.5 real-world months).

- Critical design consequence: sheltering an army inside the castle dramatically accelerates starvation. The decision is a genuine dilemma — protection vs. survival time.

**Town — Siege Values — LOCKED:**

Towns require a smaller siege than castles. Their large civilian population is their main liability during a siege — more mouths to feed means food runs out much faster than in a castle. A town falls in roughly one real-world month under siege, making town sieges a much faster and less committed operation than castle sieges.

- Typical civilian population: 10–20 PU. For siege calculation purposes, baseline is 10 PU civilians.

- Garrison: 0.5 PU military.

- Maximum food storage: 1.00 Rice (half a castle).

- Consumption per daily tick (10 PU civilians + 0.5 PU garrison): (10 × 0.0028) + (0.5 × 0.0039) = 0.028 + 0.00195 = ~0.030 Rice/daily tick.

- Siege duration at maximum storage: 1.00 ÷ 0.030 = ~33 daily ticks (~1 real-world month).

- Defense bonus during storm assault: Urban terrain +3 Defense. No additional fortification bonus — towns have walls but not the reinforced fortifications of a castle.

- Strategic implication: a town falls quickly compared to a castle. A lord defending a town has roughly 30 daily ticks before starvation forces resolution. Urgency is high.

A siege is a massive strategic commitment. It signals serious intent — not a raid, but a genuine attempt to push deep into enemy territory. Sieges are protracted, expensive, and demand sustained resources from the attacker. Source: Emerald Empire Chapter Ten, Sword and Fan Chapter Two.

**Why Castles Cannot Be Bypassed — LOCKED:**

- A bypassed castle garrison cuts the attacker's supply tether — convoys from home provinces cannot safely pass through a sub-tile with an active hostile garrison.

- The deeper an army pushes without clearing castles, the more supply tether nodes are at risk simultaneously.

- An army that ignores castles and marches on will eventually starve and run out of Arms — the deprivation cascade begins within ticks.

- Sieging a castle is therefore mandatory for any army that intends to campaign seriously into enemy territory.

**Three Ways a Siege Ends — LOCKED:**

- 1. The attacker gives up or is forced to retreat — a relief army arrives and drives off the besiegers, or the attacker's own supply situation collapses.

- 2. The garrison is starved into submission — food reserves run dry, the garrison can no longer fight.

- 3. The castle is taken by storm — a direct assault on the walls. Bloody, expensive, desperate.

**Starvation Siege — LOCKED:**

The attacker surrounds the settlement and waits. The garrison has food reserves that sustain it for a baseline number of ticks before starvation forces a resolution. The attacker does not need to fight — they just need to hold the perimeter and keep their own supply tether intact.

- Castles have large food reserves. Castle town (2.0 Rice storage, 10 PU civilians + 0.5 PU garrison): approximately 67 daily ticks (~17 real days). Town (1.0 Rice storage, 5 PU civilians + 0.5 PU garrison): approximately 65 daily ticks (~16 real days). Fortification (0.5 Rice storage, 0.5 PU garrison): approximately 256 daily ticks (~64 real days). Larger garrisons burn through food faster. Resupply during a siege extends survival dramatically. All values from existing consumption rates (civilian 0.0028 Rice/PU/tick, military 0.0039 Rice/PU/tick).

- Towns have smaller reserves — shorter baseline starvation time.

- The besieging army maintains its own supply tether back to friendly territory throughout — if that tether is cut by a relief force or a second garrison, the siege collapses.

**Siege Events — LOCKED:**

Similar to ASCII mass battle events, siege events fire periodically during the waiting period. These are opportunities — not requirements. Successfully resolving them reduces the remaining starvation time, accelerating the siege's end.

- Events represent smuggling attempts, secret passage resupply runs, garrison sorties, relief force sightings, and similar situations.

- Players can be pulled into ASCII scenarios to intercept a smuggling run, chase down a secret resupply party, or repel a sortie.

- Success reduces remaining siege time. Failure allows the garrison to extend its hold.

- These events fire on both sides — the defender may also receive events to attempt resupply or to call for relief.

**Siege Event Frequency — LOCKED:**

Event frequency scales with siege duration — the longer a siege drags on, the more desperate and active both sides become. Both sides roll independently at each interval, so late-stage sieges can see frequent events firing on both sides simultaneously.

- Days 1–30 (Early siege): 1 event every 10 daily ticks. Both sides still organized, relatively quiet.

- Days 31–60 (Mid siege): 1 event every 7 daily ticks. Desperation setting in, smuggling attempts increase.

- Days 61+ (Late siege): 1 event every 5 daily ticks. Constant activity — sorties, smuggling, relief force attempts.

- Events are not mandatory — a player can decline to participate, but forfeits the potential benefit.

### Siege Event Pool — LOCKED

The following 12 events form the complete siege event pool. Events fire according to the frequency schedule above (every 10/7/5 daily ticks at Early/Mid/Late stage). Each event resolves through an L5R 4th Edition skill roll. Success reduces the remaining siege duration (attacker events) or extends the garrison’s hold (defender events). Time reduction values are in daily ticks. Players may decline any event but forfeit the benefit.

### Attacker Events — LOCKED

These events fire for the besieging army. Success accelerates the siege end.

**A1 — Smuggling Ring Discovered: **Scouts have spotted a civilian attempting to run food past the siege lines. Characters can intercept on the ASCII map.

Roll: Perception + Stealth vs TN 20.

Success: supplies confiscated — −10 ticks from remaining siege duration.

Failure: supplies reach the garrison.

**A2 — Secret Passage Found: **Scouts report a suspected hidden tunnel beneath the walls. Characters must locate and collapse it.

Roll: Investigation + Intelligence vs TN 25.

Success: tunnel collapsed, resupply route cut — −15 ticks.

Failure: nothing confirmed. Garrison becomes aware of the search; their Concealment against future investigation attempts +1.

**A3 — Deserters at the Gate: **Desperate garrison soldiers are attempting to flee. Characters can capture and interrogate them.

Roll: Courtier + Awareness vs TN 15.

Success: intelligence gained — −5 ticks AND exact remaining food stores revealed.

Failure: deserters return to the garrison and report the attempt; garrison Morale +5 from the lord’s response.

**A4 — Relief Force Sighted: **Scouts report an enemy army on approach. No skill roll — this is a strategic decision. The attacker may stand firm and fight the relief battle, or retreat and abandon the siege. Standing firm and winning: siege continues uninterrupted. Retreating: siege ends immediately as a failed attempt.

**A5 — Supply Tether Raid: **The garrison has sent a raiding party to strike the attacker’s supply line. Characters must defend the convoy.

Roll: Battle + Agility vs TN 20.

Success: raid repelled, no damage to supplies.

Failure: supply tether damaged — attacker loses 0.5 Rice from their campaign stores.

**A6 — Contaminate the Water: **Engineers have identified the castle’s water source. Characters can attempt to contaminate it. Costs −0.5 Honor to attempt regardless of outcome. Personality gate: Jin and Gi characters will not attempt this action.

Roll: Engineering (Siege) + Intelligence vs TN 30.

Success: garrison water supply compromised — −20 ticks.

Failure: attempt discovered. Honor loss applies; no time benefit.

### Defender Events — LOCKED

These events fire for the besieged garrison. Success extends the garrison’s hold.

**D1 — Midnight Resupply Run: **A sympathetic merchant has arranged a secret food convoy through the siege lines. Garrison characters must escort it on the ASCII map.

Roll: Stealth + Agility vs TN 25.

Success: +0.5 Rice reaches the garrison — +15 ticks added to remaining hold.

Failure: convoy intercepted by the besieging army. Supplies lost.

**D2 — Message for Relief: **A swift rider will attempt to slip through the siege lines carrying a plea for help.

Roll: Horsemanship + Reflexes vs TN 20.

Success: message delivered — triggers Relief Force Sighted (A4) for the besieging army within 10 ticks.

Failure: rider captured. The attacker reads the message and learns the garrison’s exact remaining food stores.

**D3 — Tactical Sortie: **The garrison has identified a moment of weakness in the siege lines. A targeted sally could destroy attacker supplies or kill a key officer. Distinct from the Honor sortie mechanic — this is a tactical opportunity, not an Honor obligation.

Roll: Battle + Agility vs TN 20.

Success: attacker loses 0.5 Arms AND one attacker Company suffers −1 Attack for the remainder of the siege.

Failure: sortie repelled. Garrison loses 0.1 PU military.

**D4 — Civilian Morale Crisis: **Garrison civilians are near revolt, demanding the lord surrender and spare their lives. Characters must address the crowd. Jin characters receive 1 Free Raise on this roll.

Roll: Courtier + Awareness vs TN 20.

Success: morale stabilised. No effect on siege timeline.

Failure: all garrison Companies suffer −10 Morale immediately.

### Mutual Events — LOCKED

These events can fire for either side.

**M1 — Treachery Within: **An officer on one side approaches the other with a secret offer. Attacker version: a garrison officer offers to open a gate. Success: −30 ticks, siege ends decisively; cost −0.5 Honor to the lord for employing treachery. Failure: officer is executed by the garrison, siege continues. Defender version: a garrison officer attempts unauthorised surrender negotiations. The defending lord must stop them or accept the terms. Uses the existing secret and assassination mechanics (Section 12.8) for resolution.

**Storm Assault — LOCKED:**

The attacker can attempt to take the settlement by direct assault at any point during the siege. This is always available as an option — it does not require the garrison to be weakened first — but it is extremely costly.

- A storm assault is resolved as a battle using the full Army View combat system.

- The defender fights from Urban terrain — the Urban terrain bonus (+3 Defense) applies.

- Castle fortification bonus: +5 Defense on top of the Urban terrain bonus. Total effective Defense for a Garrison Company on castle walls: 5 (base) + 3 (Urban) + 5 (fortification) = 13.

- Against a Garrison Company at Defense 13, a Bushi Retainer (Attack 6 + 1d10 max 10) can deal at most 3 Health damage per round. Peasant Levies deal zero damage. Only elite units with high Attack and strong commander bonuses have realistic chances of progress.

- A failed assault weakens the attacking army — it may no longer have enough strength to maintain the siege and is forced to retreat.

- Crab and Lion clan armies receive bonuses to storm assaults due to their siege engineering traditions (Kaiu engineers). Full clan bonuses deferred to clan elite unit design session.

**Honor — Cowering in the Castle — LOCKED:**

A lord who remains fortified without sallying out to meet the enemy eventually suffers Honor loss. Hiding behind walls is not the way of Bushido. The pressure to sortie is real — a lord doesn't need to win, they just need to try.

- After 30 daily ticks of siege without any sortie or sally, the besieged lord begins losing Honor.

- Honor loss rate: −1 Honor per 10 daily ticks after the threshold is reached.

- Any sortie — even an unsuccessful one — resets the counter entirely back to zero.

- Personality modifier: aggressive lords feel the shame sooner (threshold reduced to 20 daily ticks). Pragmatic lords (Crab, Scorpion) feel it later (threshold extended to 45 daily ticks). Exact values deferred to personality system design.

**Sortie Mechanics — LOCKED:**

A sortie is a sally from the castle gates — the garrison exits and engages the besieging army in open battle. It is the primary way a besieged lord resets their Honor counter and can disrupt the siege.

- A sortie is resolved as a normal battle using the full Army View combat system.

- The garrison exits through the castle gates — they fight in Urban terrain initially (exiting the settlement) but lose the fortification +5 bonus once outside the walls.

- A successful sortie damages the besieging army, can disrupt their supply tether, and resets the Honor cowardice counter.

- A failed sortie costs the garrison Health and Morale — losses that come directly out of the people defending the castle.

- If the garrison loses the sortie badly and cannot retreat back inside, they can be destroyed in the open — outside the protection of the walls entirely.

- The decision to sortie is a genuine dilemma: risk real losses to preserve Honor, or conserve strength and accept the slow Honor drain.

**✓ DONE:** *Personality system fully designed in Section 19.3. Each Bushido virtue specifies siege end condition behavior (Jin: negotiated surrender, Yu: suicidal sortie, Rei: formal surrender with ceremony, Chugi: holds until lord orders otherwise, Gi: honest assessment then acts accordingly, Meiyo: seppuku before dishonor, Makoto: declares intent then follows through). Shourido virtues modify these responses (Ishi: never changes declared end condition, Seigyo: negotiates from strength). Sortie aggression and Honor cowardice thresholds are also defined per virtue in Section 19.3.*

**Supply Tether System — LOCKED:**

There are no physical convoy objects on the World Map. Instead, when an army enters hostile or neutral territory, an invisible supply tether automatically forms between the army and the nearest friendly controlled province behind it. Rice and Arms flow along this tether each tick automatically — it is a background process requiring no player action when intact. The tether is represented visually on the World Map as a line tracing back through the sub-tiles the army passed through.

**Tether Formation — LOCKED:**

- A tether forms automatically when an army leaves friendly or allied territory and enters hostile or neutral sub-tiles.

- The tether traces back through every sub-tile the army passed through to reach its current position, connecting back to the nearest friendly province.

- The tether supplies the army with Rice and Arms each tick automatically — no player action required while the tether is intact.

- An army entirely within friendly or allied territory does not need a tether — it draws supply directly from local province stores.

**Tether Visual States — LOCKED:**

- Solid line: Supply flowing normally. Army is fully supplied.

- Dashed/flickering line: Supply under threat. A castle garrison or enemy force on the tether route is raiding convoys. Partial supply reaching the army.

- Broken/red line: Supply cut entirely. Deprivation cascade begins on the following tick.

**Territory and Conquest During War — LOCKED:**

- Capturing a castle or sub-tile during active war gives operational control — the army can pass through it, tether through it, and use it as a staging point.

- True ownership of captured territory only transfers after the war ends. A captured province does not yield taxes, Rice, or permanent PU benefits until peace is declared.

- This means an army cannot simply conquer territory mid-war and immediately draw on its resources as a permanent holding.

**How the Tether is Threatened — LOCKED:**

- Any undefeated castle garrison on a sub-tile the tether passes through can raid the tether each tick — this is why bypassing castles is dangerous.

- Enemy armies that move onto a sub-tile the tether passes through can cut it entirely.

- The deeper an army pushes into enemy territory without clearing castles, the more nodes on its tether are vulnerable to interdiction.

- A snapped tether immediately triggers the deprivation cascade — Rice deprivation and Arms deprivation both begin counting from Tick

**Castle Garrison Tether Raid — LOCKED:**

When a hostile supply tether passes through a sub-tile containing an undefeated garrison, the garrison automatically attempts to raid the tether once per tick. No player action or AP expenditure required — this is a background process representing the garrison’s standing orders to interdict enemy supply lines.

**The Raid Roll — LOCKED:** Roll 1d10 + Garrison Attack stat (base 3 per the Garrison unit stat block). Compare against TN. Unescorted tether: TN 5. Escorted tether: TN 5 + escort Company’s Defense stat.

**Garrison PU Modifier — LOCKED:** The base Garrison Attack stat of 3 assumes a standard 1.0 PU garrison. Per 0.5 PU below 1.0: −1 Attack on the raid roll. Per 0.5 PU above 1.0: +1 Attack on the raid roll. A 0.5 PU garrison raids at Attack 2. A 2.0 PU reinforced garrison raids at Attack 5.

**Raid Outcomes — LOCKED:** Below TN: raid fails. Tether remains solid at this sub-tile. The garrison attempted to intercept but the convoy slipped through. Meets TN but does not exceed by 5 or more: partial raid. Tether enters dashed/flickering state at this sub-tile. 50% of Rice and Arms supply intercepted this tick. Exceeds TN by 5 or more: full cut. Tether enters broken/red state at this sub-tile. 100% of supply blocked. Deprivation cascade begins on the following tick per the existing Rice Deprivation and Arms Deprivation rules above.

**Partial Raid Deprivation Effect — LOCKED:** A partial raid (50% supply intercepted) causes the deprivation cascade to progress at half speed. Each deprivation stage requires double the normal number of ticks to trigger while the army is under partial interdiction. Example: under full cut, Tick 2 triggers −3 Morale. Under partial raid, the same −3 Morale penalty does not trigger until Tick 4. The army deteriorates steadily but survives longer — enough time to react, but not enough to ignore the problem indefinitely.

**Multiple Sub-Tiles — LOCKED:** Each bypassed garrison on the tether route rolls independently each tick. The worst result on the tether that tick applies. If any single garrison achieves a full cut, the tether is broken regardless of other sub-tiles. If multiple garrisons achieve partial raids, supply loss stacks: two partial raids on the same tether = 100% intercepted, functionally a full cut. The deeper the army pushes without clearing castles, the more raid rolls occur each tick, and the higher the cumulative probability of total supply failure.

**Tether Escort Mechanic — LOCKED:** The army commander may assign one Company per sub-tile as a tether escort. The escort Company is removed from the army’s battle roster for the duration of the assignment — it cannot participate in field battles or siege actions while guarding the tether. The escort Company’s Defense stat is added to the raid TN at that sub-tile (TN = 5 + Defense). Reassigning the Company back to the army roster requires 1 tick — representing the time needed to march from the tether sub-tile back to the main force. This creates a meaningful trade-off: protecting the supply line costs frontline strength.

**Typical Outcomes (Standard 1.0 PU Garrison, Attack 3) — Reference:** Unescorted tether (TN 5): 10% fail, 60% partial, 30% full cut — bypassing is extremely dangerous. Ashigaru Spearmen escort, Defense 4 (TN 9): 50% fail, 40% partial, 10% full cut — survivable but still risky. Bushi Retainer escort, Defense 5 (TN 10): 60% fail, 30% partial, 0% full cut — strong protection at the cost of a professional Company.

**Supply Restoration — Step-Down Recovery — LOCKED:** When a tether is reconnected (garrison cleared, escort assigned, enemy army driven off), the deprivation cascade does not reset instantly. The army recovers one deprivation stage per tick of restored full supply. An army at Tick 3 deprivation requires 3 ticks of full supply to return to normal. During step-down, the current stage’s penalties still apply but do not worsen. If supply is only partially restored (tether still under partial raid during recovery), step-down occurs at half speed — one stage per 2 ticks instead of one per tick. This mirrors the civilian starvation recovery logic (Section 4.3.6) but at a faster pace appropriate to military logistics. A brief tether cut (1–2 ticks) is recoverable quickly. A prolonged cut (4+ ticks) leaves lasting damage the army must nurse back over time. An army cannot simply fix the tether and charge back into battle at full strength.

**Supply Source Hierarchy — LOCKED:**

A clan is not a monolithic blob. An army draws supply from its commanding lord's own reserves first — not from the broader clan automatically. The tether connects the army to its lord's controlled provinces, not to every province in the clan. Broader clan resources only become available through deliberate political action.

**Default Supply Source:**

- An army draws Rice and Arms only from its commanding lord's own directly controlled provinces by default.

- The tether traces back to those provinces and no others.

- Nothing flows from the broader clan, allied lords, or family reserves automatically.

**Vertical Supply — Forced (Top-Down):**

- A lord can compel those beneath them in the feudal hierarchy to contribute reserves to supply an army.

- A Family Daimyo can order Local Daimyo under them to open their Rice and Arms stores.

- A Clan Champion can order Family Daimyo to contribute clan-wide.

- This is an exercise of authority — it can be done, but it generates resentment and damages disposition between the lord and the compelled vassal.

- A vassal with sufficiently poor disposition toward their lord may delay, underreport, or quietly hoard rather than comply fully — handled by the corruption and disposition systems.

**Horizontal Supply — Voluntary (Diplomatic):**

- Lords of equal standing cannot force each other — they must request through the political and character relationship system.

- Sharing between peers requires good disposition, friendship, or political favors between the relevant named characters.

- A request can be refused entirely, partially granted, or agreed to with conditions attached.

- Agreeing to share reserves is a generous act — it can earn Honor, Glory, or a favor owed in return.

- Refusing is entirely within a lord's rights and carries no automatic penalty, though it may strain the relationship depending on circumstances.

**Why This Matters:**

- A reckless general cannot drain the entire clan's Rice and Arms just because they share a clan affiliation.

- A powerful but unpopular Clan Champion may find vassals quietly hoarding rather than contributing to a war they don't believe in.

- The relationships player characters build at court — favors, friendships, dispositions — have direct military consequences when supply becomes critical.

- This mirrors CK2's vassal contribution system — a liege can call on vassals, but the willingness of those vassals depends entirely on the political relationships that have been built or neglected.

**Death of the Highest Commander — LOCKED:**

When the highest-ranking commander present on a side dies, the entire army suffers a Morale hit and loses that commander's bonus. The battle continues — the army does not instantly collapse — but the blow is severe.

- All Companies on the affected side take an immediate Morale damage roll with +4 modifier (the highest severity we have defined).

- The dead commander's bonus is removed from all Companies that were benefiting from it.

- The next highest-ranking surviving commander assumes leadership — their bonus now applies instead, which may be weaker.

- This applies at any scale — if a Chui is the highest commander in a skirmish, their death triggers this effect for their side.

**Commander Bonus System — LOCKED:**

Every named commander from Chui upward provides a bonus to units under their authority. The bonus value equals their Battle skill rank. The bonus type is determined by their highest Ring. This means that placing the best commanders at the highest positions is strategically decisive — a superior Rikugunshokan improves every Company in the army.

**Bonus Type by Highest Ring — LOCKED:**

- Fire (highest Ring) → Attack bonus equal to Battle skill rank.

- Water (highest Ring) → Attack bonus equal to Battle skill rank.

- Earth (highest Ring) → Defense bonus equal to Battle skill rank.

- Air (highest Ring) → Defense bonus equal to Battle skill rank.

- Void (highest Ring) → Morale bonus equal to Battle skill rank.

**Ring Tiebreaker by Clan — LOCKED:**

If a commander has two or more Rings tied for highest, their clan's cultural priority determines which bonus applies. This reflects the martial philosophy of each clan.

- Lion, Scorpion, Unicorn: Attack → Defense → Morale

- Crab, Crane: Defense → Attack → Morale

- Dragon: Morale → Defense → Attack

- Phoenix: Morale → Attack → Defense

**Ring Tiebreaker by Minor Clan — LOCKED:** Wasp, Mantis (pre-Great Clan), Bat, Snake: Attack → Defense → Morale. Hare, Monkey: Attack → Morale → Defense. Ox, Tortoise, Oriole: Defense → Attack → Morale. Fox, Sparrow, Dragonfly: Morale → Defense → Attack. Centipede: Morale → Attack → Defense.

**Commander Bonus Scope by Rank — LOCKED:**

- Chui (Lieutenant): Bonus applies to their Company only.

- Taisa (Captain): Bonus applies to every Company in their Legion.

- Shireikan (Commander): Bonus applies to every Company across their assigned Legions.

- Rikugunshokan (General): Bonus applies to every Company in the entire army.

- Bonuses from multiple commanders stack — a Company benefits from their Chui's bonus AND their Taisa's bonus AND the Rikugunshokan's bonus simultaneously.

- Example: A Rikugunshokan with Battle 5 and highest Ring Earth gives every Company in the army +5 Defense. A Taisa under him with Battle 3 and highest Ring Fire gives every Company in his Legion an additional +3 Attack. A Chui in that Legion with Battle 2 and highest Ring Void gives their specific Company an additional +2 Morale.

Each army deploys in two rows on the battlefield grid. The two rows serve distinct roles and the choice of what to put in Row 2 is a meaningful tactical decision made before battle.

**Row 1 — Front Line:**

- Melee Companies engage the enemy Company directly opposite them each round.

- If no enemy Company is directly in front, the unit automatically attempts to flank an adjacent enemy Company.

- This is the primary combat row — where Health damage and Morale checks are most concentrated.

**Row 2 — Support Row:**

Each Row 2 slot can hold one of two things:

- Reserve Melee Company: Held in reserve. Steps forward to fill a gap when the Row 1 Company in front of it is destroyed or routed. Does not attack while in reserve.

- Archer Company: Fires support attacks every round at the enemy Company directly in front of the Row 1 ally in their column. Cannot fill a gap — if the Row 1 Company in front is destroyed, the Archer Company is exposed and vulnerable to direct engagement.

**Archer Attack Resolution — LOCKED:**

Archer Companies fire every round automatically. Their attack is weaker than melee — reflecting the care needed to avoid friendly fire and the reduced lethality of ranged volleys compared to direct combat. Archers roll 1d5 instead of 1d10.

- Attack Roll: 1d5 + Attack stat (Ashigaru Archers: Attack 4, range 5–9 total).

- Apply Defense: Subtract the target Company's Defense as normal. Remainder is Health damage dealt.

- Morale: Archer attacks trigger the standard Morale check formula — no special treatment. Being under constant arrow fire is as demoralizing as melee casualties.

- Archers do not counter-attack — they have no melee response. If directly engaged (Row 1 Company destroyed or flanked), they suffer the −3 Attack penalty and fight at a severe disadvantage.

**Archer Damage in Practice:**

- vs. Peasant Levy (Defense 1): 4–8 Health damage per round. Meaningful sustained pressure.

- vs. Ashigaru Spearmen (Defense 4): 1–5 Health damage per round. Noticeable over a long battle.

- vs. Bushi Retainer (Defense 5): 0–4 Health damage per round. Chip damage — not decisive alone but Morale checks accumulate.

- Archers are most dangerous to poorly armored troops and most effective as a sustained attrition tool over multiple rounds rather than as a burst damage source.

**Terrain Modifiers — LOCKED:**

Terrain is a property of the sub-tile where the battle takes place. Each province is divided into 4–5 sub-tiles, each with its own terrain type. When two hostile armies occupy the same sub-tile, battle begins and that tile's terrain modifiers apply. Terrain applies a single modifier — either an attacker penalty OR a defender bonus, never both simultaneously. Unit-specific penalties apply on top of the terrain modifier and affect only that unit type. River crossings are not a terrain type — they are an approach condition handled by which tiles an army crossed to reach the battle.

**Flat Plains:**

- No terrain modifier for attacker or defender.

- Light Cavalry (both sides): +2 flanking bonus on top of their existing special rule. Plains are where cavalry dominates.

**Forest:**

- Defender: +2 Defense. The defender knows the ground and uses the trees for cover.

- Light Cavalry (both sides): loses flanking bonus entirely, −2 Attack. Horses cannot maneuver in dense forest.

- Ashigaru Spearmen (both sides): −1 Defense. Formation discipline breaks down in tight terrain.

**Hills:**

- Attacker: −2 Attack. Uphill advance is exhausting and disorganizing.

- Light Cavalry (attacker only): −1 flanking bonus on top of attacker penalty.

**Mountain:**

- Defender: +4 Defense. Commanding high ground is an overwhelming positional advantage.

- Light Cavalry (both sides): loses flanking bonus entirely, −3 Attack. Cavalry is nearly useless in mountain terrain.

- Ashigaru Archers (defender only): +1 Attack. Firing downhill increases effective range and accuracy.

**Urban:**

- Defender: +3 Defense. Every building, alley, and wall works as a fortification.

- Light Cavalry (both sides): loses flanking bonus entirely, −3 Attack. Streets prevent any meaningful cavalry maneuver.

- Ashigaru Spearmen (defender only): +1 Defense. Tight streets favor formation fighting and spear walls.

**Coastal/Beach:**

- No modifier for land vs. land engagements on coastal terrain — two armies meeting on a coastal tile in a conventional engagement fight normally.

- Amphibious landing attacker only: −3 Attack. Landing under fire while disorganized from the sea crossing is a severe disadvantage.

- Light Cavalry (amphibious attacker only): additional −2 Attack, loses flanking bonus. Sand, surf, and disembarkation chaos make cavalry useless on landing.

**Shadowlands Combat Overlay — LOCKED:**

The Shadowlands is not a terrain type. When a battle occurs on a Shadowlands sub-tile, the sub-tile's actual terrain (Plains, Forest, Hills, Mountain, etc.) determines the standard terrain modifier per the table above. The Shadowlands Combat Overlay applies as additional effects layered on top of that terrain modifier. Effects scale by zone. All Shadowlands forces (Bakemono, Ogres, Undead, Oni, Lost) are immune to all overlay effects.

"Crab-trained" = a Company serving in a Crab Clan army. Includes clan-specific elite units and universal units (Ashigaru, Garrison) under a Crab commander.

- Zone 1 — Wall-Sight: Non-Crab Imperial Companies: −1 Morale Defense. Crab-trained Companies: no penalty.

- Zone 2 — Three Days' March: Non-Crab Imperial Companies: −2 Morale Defense, −1 Attack. Taint Attrition: 2 Health lost per Battle Turn. Crab-trained Companies: no penalty.

- Zone 3 — The Deep Shadowlands: Non-Crab Imperial Companies: −3 Morale Defense, −2 Attack, −1 Defense. Taint Attrition: 4 Health lost per Battle Turn. Crab-trained Companies: −1 Morale Defense. Taint Attrition: 1 Health lost per Battle Turn.

All values PROVISIONAL pending playtesting.

**Shadowlands Terrain System — LOCKED**

The Shadowlands operates as a fundamentally different terrain system from all other terrain in Rokugan. Standard terrain modifiers (Section 11.7a) do not apply. The Shadowlands has its own movement costs, Taint exposure rates, foraging rules, and visibility conditions. It is divided into three geographic zones defined by distance from the Kaiu Wall. All three zones share two universal rules: foraging is impossible in all zones (no food or water is safe anywhere in the Shadowlands), and the standard army movement system applies with Shadowlands-specific costs below.

**Zone 1 — Wall-Sight — LOCKED:**

The strip of land visible from the Wall. The least Tainted part of the Shadowlands. Regularly patrolled by Hiruma Scouts and sortie parties.

- Movement cost: 2 days per sub-tile.

- Taint exposure: TN 10 Earth roll per day without jade. Standard rate. Jade provides full +10 bonus to resist.

- Visibility: scouts operating here are within Wall-Sight range. The Wall garrison can see them. Recall takes less than one day.

- Encounter rate: low. Small Bakemono patrols, occasional undead remnant. Nothing organized.

- SS relevance: Small sorties (−1 SS) operate primarily in this zone.

**Zone 2 — Three Days’ March — LOCKED:**

Known territory extending from Wall-Sight to approximately three days’ travel from the Wall. More hostile than Wall-Sight but still navigable by experienced Crab scouts.

- Movement cost: 3 days per sub-tile. Corrupted ground, twisted vegetation, unreliable landmarks.

- Taint exposure: TN 10 Earth roll per day without jade (base rate). Injuries and combat in this zone add a second TN 15 roll on top of the daily roll.

- Visibility: beyond Wall-Sight. Scouts operating here are isolated. Recall takes at least one full day’s travel back to the Wall.

- Encounter rate: moderate. Organized Bakemono patrols, undead remnants, occasional Ogre. Forces here are more purposeful than Wall-Sight wanderers.

- Jade degradation: standard rate. A 3-day penetration into this zone consumes roughly half a jade finger’s protection.

- SS relevance: Medium sorties (−2 SS) operate primarily in this zone.

**Zone 3 — The Deep Shadowlands — LOCKED:**

Past three days’ travel from the Wall. Alien landscape. Lakes of blood, massive volcanoes, blasphemous structures. The Festering Pit of Fu Leng lies here. The City of the Lost is here. This is where the Shadowlands is most fully itself.

- Movement cost: 4 days per sub-tile. Active supernatural interference with movement. The terrain itself resists passage.

- Taint exposure: TN 15 Earth roll per day without jade. Even with jade the daily roll fires at TN 10 rather than being suppressed. The ambient corruption is too thick to block entirely.

- Water hazard: water sources actively spread Taint. Contact alone triggers a TN 15 roll regardless of jade protection.

- Visibility: complete isolation from the Empire. No sight of the Wall, no reliable landmarks. A Hiruma Scout at Rank 1 always knows the direction of the Empire — this is precisely the ability that makes them indispensable in the Deep Shadowlands. Without a Hiruma, navigating here risks becoming permanently lost.

- Encounter rate: high. Organized Shadowlands forces, possible Oni presence, Lost characters, hostile terrain events. Every day here is a risk.

- Jade degradation: double rate. The Taint consumes jade faster here. A jade finger that would last 7 days in Wall-Sight lasts approximately 3–4 days in the Deep Shadowlands.

- SS relevance: Large sorties (−3 SS) operate in this zone. The risk matches the reward.

**Crab-Specific Bonuses — LOCKED:**

- Hiruma Scouts operate in all three zones without the navigation penalty that affects other schools. Rank 1 always knows direction of the Empire. They are the only school purpose-built for this terrain.

- Hida Bushi receive their +2 Defense vs Shadowlands creatures in all three zones. Their training specifically accounts for the types of enemies encountered here.

- Kuni Witch Hunters operating in the Shadowlands add their Lore: Shadowlands rank as a bonus to all Taint resistance rolls. Their deep knowledge of Jigoku’s influence provides genuine spiritual protection beyond what jade alone can offer.

