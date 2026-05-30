# 52. World Population System

This section defines how the game world is populated with named characters at launch and how it maintains its population during play. It covers the one-time world population pass at game start, the ongoing generation triggers during play, and all supporting systems including name generation, gender distribution, NPC advancement, natural death, ronin rules, and child generation.

**⚙️ CROSS-REF (Law ****&**** Order):** Doshin (peasant law enforcers) exist within the magistrate hierarchy (Section 11.3.1), not as a separate population unit type. Their effect on province stability is modeled through the magistrate system — a province with an effective clan magistrate who maintains doshin has better law enforcement, which feeds into Province Stability (Section 11.11). Doshin do not need to be tracked as a distinct PU; their presence is implied by the quality of the magistrate assigned to the province.

**PART 1 — GAME START: ONE-TIME WORLD POPULATION**

Before any player logs in, the server runs a single world population pass. This pass fills every named position in the game world. It runs once and is never repeated. All subsequent character generation is handled by the ongoing triggers defined in Part 2.

**Step 1 — Define All Positions**

The world has a fixed set of named roles organized by the feudal hierarchy. Every role has a required minimum Insight Rank and a required Clan. The complete position roster at game start is approximately:

- 1 Emperor (canonical — pre-written).

- 8 Clan Champions (canonical — pre-written).

- ~20 Family Daimyo (mix of canonical and generated).

- ~80 Provincial Daimyo (mostly generated).

- ~400 Local Daimyo (generated).

- ~2,000 military commanders — Rikugunshokan through Gunso (generated, scaled by clan army size).

- ~1,000 courtiers, magistrates, temple heads, sensei, and other significant roles (generated).

Total named positions at game start: approximately 3,500 to 5,000. The exact number scales with the scope of the initial map and the number of provinces per clan. Every position must be filled before the game opens.

**Step 2 — Fill Canonical Positions First**

Pre-written characters (see Section 22.1 and 22.8) are placed into their designated positions first. These characters are hand-authored with specific attributes, relationships, and histories. Canonical characters occupy the highest-profile positions — Clan Champions, major family daimyo, key Imperial figures, and famous historical characters. The generation engine does not touch these positions.

**Step 3 — Generate All Remaining Characters**

For every unfilled position, the generation engine runs the template system (Section 22.4) with the following inputs:

- Position → determines required Insight Rank and Clan.

- Clan + most appropriate Family for that position + appropriate School → runs the generation template.

- Insight Rank is set to meet or slightly exceed the position's minimum requirement, with small variance.

The engine generates the complete character sheet — Traits, Skills, Techniques, Personality, Equipment, Honor/Glory/Status, and all other fields as defined in Section 22.3. Every generated character is immediately a fully functional named NPC.

**Step 4 — Build Family Webs**

Once all characters exist as individual sheets, the engine stitches biological family connections across the entire population. This pass ensures:

- Every character has assigned parents. Parents are older than their children (age consistency enforced).

- Marriages are distributed across the population, with inter-clan marriages reflecting historical political relationships.

- Children are assigned to appropriate parents. Families have 0–4 children based on weighted random distribution.

- Grandparents and great-grandparents are generated as lightweight records — name, clan, status, and living/deceased status — rather than full character sheets, unless they are still active in the world.

The result is a complete four-generation family web for every active named character, as defined in Section 22.6.

**Step 5 — Apply Starting Dispositions**

Clan-to-clan baseline disposition modifiers (Section 12.2) are applied across all character pairs. Characters who share a clan start with positive baselines. Historical rival clans start with negative baselines. Within the same family, strong positive baselines apply. The world opens with a complete social graph — every named character has defined starting relationships with every other named character of the same or neighboring clans.

**PART 2 — DURING PLAY: ONGOING GENERATION TRIGGERS**

After game start, new named characters only enter the world at Insight Rank 1. Three triggers create new characters during play.

**Trigger 1 — Position Vacancy**

When a named character dies, retires, or is otherwise removed from their position, that position becomes vacant. The promotion system fills it:

- The next most senior character below the vacant position in the same hierarchy is promoted. They retain their existing character sheet and take on the new role.

- If no suitable character exists at a sufficient Rank to fill the role, a newly generated Rank 1 character is created and assigned. They are immediately placed in the position but are significantly less capable than their predecessor — the capability gap is real and lasting.

- The new Rank 1 character is generated using the standard template for their assigned Clan + Family + School.

- This trigger is also used when the player character achieves a position — the previous holder either dies, retires, or is reassigned.

**Trigger 2 — Marriage Produces Children**

When two named characters marry and the marriage produces a child, the engine generates a new Rank 1 character immediately with appropriate lineage:

- The child's Clan is determined by marriage terms. In Rokugan the child typically takes the father's clan. Political marriages may specify the mother's clan instead — this is set at the time of the marriage agreement.

- The child's Family follows from their Clan assignment.

- School is not yet assigned at birth — it is assigned at gempuku (~15 IC years of age).

- The child is generated as an inactive character. They exist in the family web and are tracked for age, but they do not participate in the world, hold positions, or appear in social interactions until they reach gempuku age.

- At gempuku, the child becomes an active Rank 1 character. Their School is assigned based on clan/family tendency and any specific arrangements made by their parents. They enter the world as a full named character.

At the 4:1 IC/OOC ratio, gempuku occurs approximately 3.75 OOC years after birth. This is a long time. Children are tracked as lightweight records during this period rather than full character sheets. At gempuku the engine runs the full generation template and produces a complete Rank 1 character sheet.

Child record fields (complete list):

- Name: Generated at birth using clan name tables.

- Father: Link to the father's full character sheet.

- Mother: Link to the mother's full character sheet.

- Date of Birth: IC year and month.

- Clan and Family: Determined by marriage terms at birth.

- Gender: Assigned at generation using clan gender weights.

- Orientation: Assigned at generation. Straight (85%), gay (10%), bisexual (5%). Determines valid targets for Seduction ActionIDs (Section 12.8) and the organic romance check. A Seduction action targeting a character whose orientation is incompatible with the actor’s gender auto-fails with no roll — the target is not interested. Bisexual characters can target and be targeted by anyone. Orientation is stored on the character object and does not change.

- Status: Alive or Deceased. Children can die before gempuku — tracked as a Tier 4 Personal topic.

No other fields exist until gempuku. The child record is a placeholder, not a character.

**Trigger 3 — Population Density Below Threshold**

Each clan maintains a minimum population target — the minimum number of named characters required at each Rank tier to function. If a clan falls below this threshold due to war, plague, assassination, or any other cause, the engine generates new Rank 1 characters to represent young samurai entering service.

- These characters represent children of unnamed retainers, distant relatives, or new recruits who have not previously been tracked as named characters.

- They are generated using standard templates for the depleted clan.

- They enter at Rank 1 regardless of how high the gap is. The engine does not generate high-Rank replacements — only raw recruits. The gap takes years to close organically.

Population thresholds are defined per clan per Rank tier. The table below defines the minimum named characters each clan must maintain at each Rank level. When any tier falls below its minimum, Trigger 3 fires and the engine begins generating new Rank 1 characters for that clan. These minimums reflect clan size and military/political weight in Rokugan. Lion is the largest military clan. Dragon and Mantis are the smallest Great Clans. Actual population at launch is approximately 3 to 4 times these minimums — the minimums represent a depleted, barely-functional clan, not a healthy one.

Minimum population targets per clan per Rank tier:

- Crab Clan: Rank 5+ minimum 3, Rank 4+ minimum 8, Rank 3+ minimum 25, Rank 2+ minimum 60, Rank 1 minimum 100. Total minimum: 196.

- Crane Clan: Rank 5+ minimum 3, Rank 4+ minimum 8, Rank 3+ minimum 25, Rank 2+ minimum 60, Rank 1 minimum 100. Total minimum: 196.

- Dragon Clan: Rank 5+ minimum 1, Rank 4+ minimum 3, Rank 3+ minimum 10, Rank 2+ minimum 25, Rank 1 minimum 40. Total minimum: 79.

- Lion Clan: Rank 5+ minimum 4, Rank 4+ minimum 10, Rank 3+ minimum 30, Rank 2+ minimum 80, Rank 1 minimum 130. Total minimum: 254.

- Phoenix Clan: Rank 5+ minimum 2, Rank 4+ minimum 6, Rank 3+ minimum 18, Rank 2+ minimum 45, Rank 1 minimum 75. Total minimum: 146.

- Scorpion Clan: Rank 5+ minimum 2, Rank 4+ minimum 6, Rank 3+ minimum 18, Rank 2+ minimum 45, Rank 1 minimum 75. Total minimum: 146.

- Unicorn Clan: Rank 5+ minimum 2, Rank 4+ minimum 6, Rank 3+ minimum 18, Rank 2+ minimum 45, Rank 1 minimum 75. Total minimum: 146.

- Mantis Clan: Rank 5+ minimum 1, Rank 4+ minimum 3, Rank 3+ minimum 10, Rank 2+ minimum 25, Rank 1 minimum 40. Total minimum: 79.

Total minimum named characters across all clans: 1,242. At a healthy game start, actual population is approximately 3,700 to 5,000 named characters across all clans and factions.

**PART 3 — NPC ADVANCEMENT**

Generated characters do not remain static. NPCs advance through the same progression system as player characters (Section 48), but using a simplified autonomous version.

- NPCs accumulate XP automatically based on their activities — commanding in battles, participating in court sessions, completing assigned missions. The game tracks this in the background.

- NPCs spend XP on progress bars automatically, prioritizing their school's primary skills and Rings.

- NPCs do not require Sensei visits to unlock Techniques — they advance School Rank automatically when Insight threshold is met, reflecting their ongoing training within their school's dojo.

- NPC advancement rate is approximately half the rate of an active player character. They are living their lives, not grinding.

NPCs use the same progress bar system as player characters (Section 48). The math is identical — the same Skill and Ring thresholds, the same XP-to-progress conversion. The difference is that NPCs do not spend AP or make conscious training decisions. Instead they receive a passive daily XP income based on their role, multiplied by their current activity level.

**Base XP Rate by Role**

Every NPC earns a base XP amount each OOC day derived from their current role. Higher-responsibility roles generate more experience:

- Rank 1 soldier or courtier in peacetime: 0.02 XP per OOC day. Baseline — a young samurai in quiet service. Reaches Rank 2 in approximately 7 OOC years.

- Rank 1 on active duty (border patrol, active assignment): 0.04 XP per OOC day. Reaches Rank 2 in approximately 3.5 OOC years.

- Gunso (sergeant commanding a squadron): 0.05 XP per OOC day. Leadership role with regular training demands.

- Chui (company commander): 0.06 XP per OOC day. Regular command experience and decision-making.

- Taisa (legion captain): 0.08 XP per OOC day. Significant leadership and strategic complexity.

- Shireikan (commander of multiple legions): 0.10 XP per OOC day. Major strategic responsibility.

- Courtier in active court: 0.05 XP per OOC day. Regular political engagement.

- Magistrate on active investigations: 0.06 XP per OOC day. Regular challenges and field duties.

- Sensei actively teaching: 0.04 XP per OOC day. Teaching reinforces mastery but is less demanding than field command.

- Temple head or shugenja in active ritual practice: 0.05 XP per OOC day.

**Activity Multipliers**

The base rate is multiplied by the NPC's current activity level. Multipliers apply for the duration of the activity and stack on top of the role rate:

- Peacetime, no notable events: 1.0x. Base rate only.

- Active border patrol or minor skirmish: 1.5x. Some genuine danger and challenge.

- Participating in a battle: 2.5x for the duration of the battle (1 OOC day per Mass Battle). Significant combat experience.

- Commanding in a battle: 3.0x. Major leadership challenge under pressure.

- Active court season: 1.5x for courtiers during a court season. Intensive political engagement.

- Siege — attacker or defender: 2.0x for the duration of the siege. Sustained military stress.

- Major crisis involvement (Tier 1 or Tier 2 crisis): 2.0x. High-stakes situations accelerate growth.

**XP Spending Priority**

When the engine spends accumulated NPC XP on progress bars, it follows a fixed priority order. NPCs do not make conscious choices — the engine optimizes toward their school's strengths while reflecting how real skill deepens over time:

- First: Primary Ring for the school (Earth for Hida Bushi, Air for Doji Courtier, Fire for Isawa Shugenja). The most important attribute for their school's function.

- Second: All eligible skills, sorted by current rank descending (highest-ranked first). Eligible skills are: (a) all school skills, plus (b) any non-school skill the character already has at rank 1 or higher. Non-school skills at rank 0 are not eligible — NPCs deepen existing knowledge rather than beginning entirely new disciplines. Within the same current rank, school skills are prioritized over non-school skills.

- Third: Secondary Ring associated with the school's focus.

- Fourth: Void Ring (all school types — bushi, courtier, monk, and shugenja alike). Every samurai may cultivate inner stillness. Void training is available after school skills and focus rings are addressed.

- Fifth: Any remaining XP is held in reserve until a threshold is reached.

- Never: Rings unrelated to school function (beyond the two focus rings and Void), or non-school skills at rank 0. NPCs do not begin disciplines they have never touched.

**Worked Examples**

- Gunso in peacetime: 0.05 XP/day x 1.0 = 0.05 XP/day. Reaches Rank 2 in approximately 2.8 OOC years of uninterrupted peacetime service.

- Gunso during a battle: 0.05 x 3.0 = 0.15 XP earned on that single OOC day. A significant one-day boost.

- Chui commanding through a 30-day campaign at 2.0x multiplier: 0.06 x 2.0 x 30 = 3.6 XP total. Approximately 7% of the way to Rank 2 from a single campaign.

This means the world's NPC population grows in power over time at a rate determined by the world's activity level. A peaceful era produces slow advancement. A generation of constant warfare produces faster-advancing NPCs — but also more death, which offsets the gains. High-Rank NPCs who survive long enough will eventually reach Rank 5+ but most will not survive that long.

**PART 4 — NATURAL DEATH**

Characters die from causes other than combat. The engine runs a passive natural death check for every named character once per IC season (every 22.5 OOC days).

- Characters under age 50 IC: No natural death roll. They are in their active years.

- Characters age 50–65 IC: 1% chance of death per IC season check.

- Characters age 65–75 IC: 3% chance of death per IC season check.

- Characters age 75–85 IC: 8% chance of death per IC season check.

- Characters age 85+ IC: 20% chance of death per IC season check.

At the 4:1 ratio, IC age 50 is reached after approximately 12.5 OOC years of play — most characters will not reach natural death age during a typical campaign. For canonical characters who begin the game at advanced ages, natural death is a genuine concern. A 70-year-old canonical character has a 3% chance of dying each IC season — roughly every 5–6 OOC days.

Natural death generates a Tier 4 Personal topic (death of a named character). If the character held a significant position, it may also generate a Tier 3 or Tier 2 crisis depending on the power vacuum created.

**PART 5 — RONIN GENERATION**

When a named character loses their lord — through their lord's death without a suitable heir, through dismissal, through their lord's clan being destroyed, or through voluntary departure — they become Ronin.

- Ronin retain their existing character sheet entirely. No stats change. They lose their Role/Position field and their stipend.

- Ronin are not reassigned by the engine. They exist as free agents in the world, pursuing objectives autonomously.

- Ronin may be hired by other lords as mercenaries, seek a new lord through petition, join a ronin band, or simply wander.

- If a Ronin goes without income for an extended period, they may take the Debt disadvantage and eventually become desperate — a potential bandit or insurgency seed (connecting to the Insurgency System).

- A Ronin who finds a new lord and is formally accepted into service loses Ronin status and gains a new Role/Position. Their Honor may have suffered during the Ronin period depending on their conduct.

- Player characters who become Ronin follow the same rules — no special treatment.

**PART 6 — NAME GENERATION**

Given names are generated procedurally from syllable tables per clan. Family names are always canonical — drawn from the fixed list of families within each clan. The full name follows Rokugani convention: Family name first, given name second.

Name structure: 70% two-syllable names (Initial + Final), 30% three-syllable names (Initial + Middle + Final). Male and female names use distinct syllable pools per clan, reflecting authentic Rokugani phonetic patterns.

**Crab Clan Name Tables**

Style: Short, hard consonants. Earthy and blunt. Male names often end in hard stops. Female names slightly softer but still strong.

- Male — Initial: Ya, Ka, O-, Hi, To, Ku, Sa, Ta, No, Ha, Shi, Mu

- Male — Middle (optional): ki, su, ra, ko, ta, ru, ni, ma

- Male — Final: mo, ro, to, shi, ki, su, da, ka, zu

- Female — Initial: O-, Ya, Ka, Hi, Sa, Na, Tsu, Mi

- Female — Middle (optional): su, ki, ru, na, ko

- Female — Final: ko, ru, shi, ka, me, e, mi, na

**Crane Clan Name Tables**

Style: Flowing, elegant, often ending in vowel sounds. Refined and multi-syllable. Male names dignified. Female names graceful.

- Male — Initial: Ho, Ka, Sa, Ku, Yo, To, Na, Ha, Do, Shi

- Male — Middle (optional): wa, tu, su, ku, na, ri, shi

- Male — Final: ri, shi, na, wa, ru, i, to, e, yu

- Female — Initial: Yo, Sa, Ka, Ha, Na, Ki, Mi, Tsu, Shi

- Female — Middle (optional): su, na, ki, wa, ri

- Female — Final: ko, me, e, ka, na, mi, yo, ne, ra

**Dragon Clan Name Tables**

Style: Philosophical, nature-themed, often referencing elements or abstract concepts. Gender distinction is subtle.

- Male — Initial: Hi, Sa, Ka, To, Mi, Na, U, Kaze, Tsu

- Male — Middle (optional): to, su, ru, mi, na, ko

- Male — Final: mi, su, to, ru, shi, ko, so, ka

- Female — Initial: Hi, Sa, Ka, Mi, Na, Tsu, U, Shi

- Female — Middle (optional): to, su, na, mi, ru

- Female — Final: mi, ko, na, ka, e, ru, shi, to

**Lion Clan Name Tables**

Style: Strong and honorable-sounding. Male names powerful and short. Female names strong but can be longer — Matsu women in particular carry fierce names.

- Male — Initial: To, Gin, A, Ka, Shi, Ha, Na, Ta, Ma

- Male — Middle (optional): wa, ka, ru, to, su, ta

- Male — Final: ri, wa, ki, to, ru, shi, ka, su

- Female — Initial: Tsu, Ma, Ka, Gin, Na, Sa, A, Hi

- Female — Middle (optional): su, ru, ko, ta, na

- Female — Final: ko, ka, ru, me, na, e, shi, mi

**Phoenix Clan Name Tables**

Style: Spiritual and multi-syllable. Often soft consonants reflecting elemental themes. Gender distinction moderate.

- Male — Initial: Ta, Ho, U, Shi, Tsu, Ka, Hi, A, Mi

- Male — Middle (optional): da, chi, ko, su, ta, ru, na

- Male — Final: ka, da, ko, ru, na, shi, to, mi

- Female — Initial: Mi, Sa, Ka, Na, Tsu, Hi, A, Shi

- Female — Middle (optional): su, na, ko, ru, ki

- Female — Final: ko, na, mi, ka, e, ru, me, shi

**Scorpion Clan Name Tables**

Style: Sharp and sometimes ambiguous. Names often carry hidden or double meanings in Rokugani. Can sound innocent or threatening depending on context.

- Male — Initial: A, Ba, Shi, Ka, To, Ku, Sa, Ya

- Male — Middle (optional): ra, mo, ru, ku, shi, ta

- Male — Final: ro, ru, shi, ku, to, mo, ra, su

- Female — Initial: Ka, Sa, Mi, Shi, A, To, Ya, Na

- Female — Middle (optional): chi, ko, su, na, ru

- Female — Final: ko, chi, ka, mi, na, e, ru, shi

**Unicorn Clan Name Tables**

Style: Mix of Rokugani and gaijin/steppe influences. Some names feel distinctly foreign. Male names can be shorter and almost Mongolian-influenced.

- Male — Initial: Ka, Ta, Shi, Mo, Na, Chen, Bao, To, U

- Male — Middle (optional): ge, ta, su, ru, ko, na

- Male — Final: ge, su, ko, to, ru, ka, shi, mo

- Female — Initial: Ka, Mi, Tsu, Na, Sa, U, Hi, Shi

- Female — Middle (optional): mo, ko, na, su, ru

- Female — Final: ko, mo, ka, mi, na, e, ru, shi

**Mantis Clan Name Tables**

Style: Sea-flavored, often short and punchy. Some names reference waves, storms, or sea creatures. Gender distinction moderate.

- Male — Initial: A, Ku, Ta, Hi, Ka, To, Na, Tsu

- Male — Middle (optional): ra, su, mi, ko, ru, ta

- Male — Final: su, mi, ko, ra, to, ka, ru, shi

- Female — Initial: Mi, Ka, Ku, Hi, Na, Tsu, Sa, A

- Female — Middle (optional): mi, ko, su, na, ru

- Female — Final: ko, mi, ka, na, e, ru, me, shi

**PART 7 — GENDER DISTRIBUTION**

Gender is assigned at generation using weighted distributions that reflect Rokugani society and school restrictions. Some schools are historically gender-weighted or restricted.

- Default distribution: 55% male, 45% female for most schools.

- Matsu Bushi: 80% female. The Matsu family is historically and culturally dominated by female warriors.

- Daidoji Iron Warrior: 70% male. A traditionally male-dominated military school.

- Utaku Battle Maidens: 100% female. Restricted by school rules.

- Asahina Shugenja: 60% female. The Asahina family skews female.

- All other schools: Standard 55/45 distribution unless lore specifies otherwise.

Gender affects name generation (separate syllable tables), school eligibility for restricted schools, and certain social interactions where gender carries cultural weight in Rokugani society.

