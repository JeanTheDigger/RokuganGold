# 18. NPC Objective System — LOCKED

Every named character — player and NPC alike — has an objective at all times. This is a foundational system that affects everything in the game, not just Personal Visits. NPC objectives drive movement through the world, decisions about who to invite to court, what letters to send, what alliances to seek, what military actions to take, and how to respond to other characters' actions.

**Core Principles — LOCKED:**

- Every named NPC has an active objective at all times — not just during court sessions.

- Objectives drive NPC behavior throughout all game systems — military, diplomatic, economic, and personal.

- An NPC whose objective is improving relations with the Lion Clan might send an invitation to a Lion courtier, travel to attend a Lion court, or commission a gift appropriate for a Lion samurai.

- A lord whose objective is securing a military alliance might travel to visit a neighboring clan's Champion personally, send letters expressing interest, or support their position at court.

- Objectives are not always visible to other characters — learning an NPC's objective requires the Probe intelligence action.

- NPCs change objectives over time as circumstances change — a resolved crisis, a new threat, a shift in political landscape all can trigger an objective change.

## 18.1 Two Objective Types — LOCKED

**Standing Objective — LOCKED:**

A deep personal ambition or lifelong drive. Generated at character creation and persists for a long time — possibly forever. It is directional, not completable. There is no moment where a standing objective is done. It guides general decision-making and colors how the character approaches every situation, every court session, every resource decision.

A standing objective can change, but rarely — only when a major life event fundamentally alters who the character is. The death of a child, a catastrophic betrayal, a spiritual revelation. These are not common events.

Characters without a lord — Clan Champions, Ronin, independent Minor Clan lords — pursue their standing objective as their primary driver. There is no one above them to assign tasks.

**Primary Objective — LOCKED:**

The immediate task a character is actively working toward. Must be completable — there is a clear done/not-done state. When it is done, a new one is assigned. Primary objectives link directly to topics and crises: they are often responses to active crises, and completing them generates new topics.

Primary objectives cascade down the hierarchy. A lord’s primary objective generates derived primary objectives for their vassals — specific actionable tasks that each vassal can pursue using their own skills and access. A lord whose primary objective is ‘secure an alliance with the Dragon Clan’ assigns their courtier to build Dragon dispositions at court, their letter-writer to maintain correspondence, their gift-master to commission appropriate gifts. Each vassal’s task is different but serves the same goal.

Primary objectives are assigned through existing diplomatic systems — either in person via an Action Point during a Personal Visit or court session, or by letter (one per IC day, no AP cost, subject to geographic delivery delay). The assignment method matters: in-person is secure and immediate; letter assignment has a lag and carries interception risk.

## 18.2 Objective Assignment — LOCKED

**At Game Start:**

- Standing objective: Generated at character creation using the three-input system (see Section 18.3). Present from day one.

- Primary objective (has a lord): Derived from the lord’s standing objective — the most immediate actionable task the vassal can pursue in service of that goal.

- Primary objective (no lord): Null at game start. The character pursues their standing objective directly until circumstances or a crisis creates an immediate task.

- Crisis override: If a crisis exists in the character’s territory at game start, their primary objective is automatically set to respond to it, overriding any lord-derived assignment.

**During Play:**

- A lord reassigns a vassal’s primary objective via Action Point (in person) or letter. The new objective replaces the old one upon receipt.

- A primary objective that is completed generates a Tier 4 topic — the completion is news. The character then awaits a new assignment or defaults to pursuing their standing objective.

- A primary objective that becomes impossible (the target died, the crisis resolved without them, political circumstances changed) is flagged as obsolete. The character defaults to their standing objective until reassigned.

- A standing objective changes only through major life events — not through normal play. When it changes, it is a significant narrative moment.

**Virtue Interactions:**

- Chugi (Duty/Loyalty): Primary objective always perfectly mirrors their lord’s known position. Cannot deviate. If their lord’s primary objective changes, theirs changes immediately regardless of how the information arrived.

- Ishi (Will): Once assigned a primary objective, pursues it until explicitly reassigned. Does not update even if circumstances change dramatically.

- Seigyo (Control): Pursues the primary objective but always evaluates how it serves their standing objective. Will pursue the assigned task while simultaneously maneuvering for personal advantage.

- Makoto (Sincerity): Once they accept a primary objective, they pursue it with complete conviction. Will not quietly abandon it — must be formally reassigned.

## 18.3 Standing Objective Generation — LOCKED

Three inputs determine which standing objectives are available and their weighted probability at generation. The system picks from a weighted pool — not random. A Jin/Ketsui Crane courtier is far more likely to receive ‘protect those under my care’ than ‘advance my family’s standing,’ though both remain possible.

- Input 1 — Role/Position: A Clan Champion has access to clan-level standing objectives unavailable to a provincial bushi. A courtier has access to political and personal standing objectives. A bushi has access to military and personal objectives. Role gates which objective domains are available.

- Input 2 — Bushido Virtue: The ethical direction of the objective. Jin characters weight toward protective and compassionate objectives. Gi characters weight toward justice and righteousness objectives. Meiyo characters weight toward honor-preservation objectives.

- Input 3 — Shourido Virtue: The ambition layer. Seigyo characters weight toward influence and control objectives. Ketsui characters weight toward endurance and achievement objectives. Chishiki characters weight toward knowledge and intelligence objectives.

## 18.4 Standing Objective List — LOCKED

Standing objectives are directional and never completed. They guide behavior without having a done state.

**Political Standing Objectives:**

- Expand my clan’s territorial influence.

- Maintain the balance of power — no single clan dominates.

- Advance my family’s standing within the clan hierarchy.

- Undermine [Clan X]’s influence across the Empire.

- Strengthen the Imperial institution.

- Accumulate political leverage — favors, secrets, and alliances held in reserve.

**Military Standing Objectives:**

- Strengthen the Kaiu Wall and Crab defenses.

- Keep my clan’s military the dominant force in the region.

- Eliminate the Shadowlands threat.

- Maintain peace — avoid war at all costs.

- Build the strongest possible fighting force under my command.

**Economic Standing Objectives:**

- Maximize my province’s prosperity.

- Control the Empire’s key trade networks.

- Ensure my clan never faces resource shortage.

- Grow my commercial enterprise.

Decomposition: CONDUCT_COMMERCE in highest-modifier accessible settlement → BEGIN_TRAVEL toward better markets when current is saturated or already traded this season → RAISE_DISPOSITION with at-risk trade contacts. Full decomposition in Section 55.24. STATUS: ✅ COVERED — all engine components exist.

### Accumulate personal wealth and resources.

**Personal Standing Objectives:**

- Honor my ancestors through my deeds.

- Protect those under my care.

- Accumulate knowledge and wisdom.

- Achieve personal excellence in my role.

- Elevate my family name.

- Live by Bushido without compromise.

- Advance my personal Glory and reputation.

- Seek vengeance for [historical wrong] — assigned at generation if historical modifier table includes a severe event.

## 18.5 Primary Objective List — LOCKED

Primary objectives are completable. They have a clear done/not-done state. Completing a primary objective generates a Tier 4 topic.

**Political Primary Objectives:**

- Secure a formal alliance with [Clan/Family X].

- Break the alliance between [X] and [Y].

- Isolate [Character X] politically — reduce their court standing below [threshold].

- Gain a Winter Court invitation for my lord.

- Secure [Character X]’s support on [Crisis topic].

- Have [Character X] appointed to [Position].

- Remove [Character X] from [Position].

- Resolve [Clan War crisis] through negotiation.

- Obtain an Imperial Edict on [topic].

- Expose [Character X]’s secret publicly.

- Forge a marriage arrangement between [Family X] and [Family Y].

- Secure a hostage exchange with [Clan X].

**Military Primary Objectives:**

- Conquer [Province X].

- Defend [Province X] against [Clan X].

- Resolve [Shadowlands Incursion crisis].

- Destroy [Army X] in the field.

- Relieve the siege of [Castle X].

- Raise a military force of [size] by [date].

- Secure a military alliance with [Clan X] against [Clan Y].

- Eliminate [Character X] — through duel or other means.

- Restore order in [Province X] — resolve active banditry or insurgency crisis.

**Economic Primary Objectives:**

- Resolve [Famine crisis] in [Region X].

- Secure [Trade Route X] — clear banditry or reopen blocked passage.

- Acquire [Resource X] above [threshold].

- Increase Koku output of [Province X] above [threshold].

- Establish a trade agreement with [Clan X].

- Sabotage [Clan X]’s economic output below [threshold].

**Personal Primary Objectives:**

- Arrange a marriage for [Family Member X].

- Secure an heir — adoption acknowledged or legitimate birth.

- Train [Character X] to Insight Rank [Y].

- Restore my Honor above [threshold] — after a disgrace event.

- Achieve Glory Rank [X].

- Avenge [Death/Disgrace of Character X] — done when vengeance is achieved.

- Earn a formal public apology from [Character X] for [insult].

## 18.6 Objective Change Triggers — LOCKED

Primary objectives change regularly. Standing objectives change rarely. The following triggers drive changes:

**Primary Objective Change Triggers:**

- Completion: Objective achieved. Topic generated. Lord assigns new objective.

- Obsolescence: Objective becomes impossible — target died, crisis resolved, political circumstances changed. Character defaults to standing objective until reassigned.

- Crisis override: A new crisis in the character’s territory or relevant sphere creates an immediate primary objective that supersedes the current one. The previous objective is suspended, not cancelled — it resumes if the crisis is resolved.

- Lord reassignment: The lord changes the objective via AP action or letter. Replaces the previous objective upon receipt.

**Standing Objective Change Triggers:**

- Major life event: Death of a child, catastrophic betrayal, profound disgrace, or a genuine spiritual transformation. These are rare and significant narrative moments.

- Completion of vengeance objective: If the standing objective was ‘avenge [X],’ achieving it leaves a void that must be filled with a new standing objective — the only case where a standing objective has a done state.

## 18.7 Objective Interactions with Other Systems — LOCKED

- Crisis System: Active crises generate primary objectives automatically for lords in the affected territory. A famine generates ‘resolve the famine.’ A Shadowlands Incursion generates ‘send military aid’ or ‘resolve the incursion.’ The specific objective depends on the character’s role and resources.

- Topic System: Completing a primary objective generates a Tier 4 topic. ‘Alliance Formed’ when an alliance objective completes. ‘Promotion or Appointment’ when an appointment objective completes. The topic type matches the completed objective type.

- Disposition System: A character’s standing objective influences their disposition-building behavior. A character whose standing objective is ‘advance my family’s standing’ will prioritize building disposition with high-Status characters. A character whose standing objective is ‘protect those under my care’ will prioritize disposition with their direct vassals and dependents.

- Court Action System: A character’s primary objective is their declared court objective (Section 15.4). The Objective Alignment System checks whether court actions serve or contradict the primary objective.

- Probe Action: A successful Probe (Section 15.4 Category 5) reveals the target’s primary objective. A Probe with 1 Raise reveals both primary and standing objectives. This is the only way to learn an NPC’s objectives without them declaring them publicly.

- Letter System: A lord assigns a primary objective by letter. The objective does not activate until the letter arrives. During transit, the vassal continues pursuing their current objective. A letter containing an objective assignment is a high-value interception target — it reveals the lord’s intentions.

- Hierarchy Cascade: A lord’s primary objective drives their vassals’ primary objectives. When the lord’s objective changes, their vassals’ objectives should be updated via new assignments. A lord who fails to reassign vassals after their own objective changes will have vassals pursuing outdated tasks.

## 18.8 Standing Objective Generation Weights — LOCKED

Each standing objective has a base weight of 1. Virtue and role apply multipliers. The generator picks from the weighted pool. Higher multipliers make an objective more likely for that virtue/role combination. Values below 1 make an objective actively unlikely.

**Political Standing Objectives — Weights:**

Expand my clan’s territorial influence: Kyōryōku ×3, Seigyo ×3, Ketsui ×2. Role: Clan Champion/Family Daimyo ×3, Provincial Daimyo ×2. Jin ×0.3, Rei ×0.5.

Maintain the balance of power: Gi ×3, Jin ×2, Dōsatsu ×2. Role: Clan Champion ×2, Courtier ×2. Kyōryōku ×0.3, Ishi ×0.5.

Advance my family’s standing: Seigyo ×3, Ketsui ×2. Role: Courtier ×3, Minor samurai ×2. Chugi ×0.5.

Undermine [Clan X]’s influence: Seigyo ×3, Dōsatsu ×2. Role: Courtier ×2, Scorpion clan ×2. Gi ×0.1, Makoto ×0.2.

Strengthen the Imperial institution: Chugi ×3, Meiyo ×2, Gi ×2. Role: Imperial family ×4, Crane clan ×2. Seigyo ×0.5.

Accumulate political leverage: Seigyo ×4, Dōsatsu ×3, Chishiki ×2. Role: Courtier ×3. Gi ×0.1, Makoto ×0.1.

**Military Standing Objectives — Weights:**

Strengthen the Kaiu Wall: Crab clan ×5, all other clans ×0.1. Yu ×2, Kyōryōku ×2, Chugi ×2.

Keep my clan’s military dominant: Kyōryōku ×3, Ketsui ×2, Yu ×2. Role: Military commander ×3, Clan Champion ×2. Rei ×0.5.

Eliminate the Shadowlands threat: Crab clan ×3, Phoenix clan ×2. Yu ×3, Kyōryōku ×2, Jin ×2. Seigyo ×0.5.

Maintain peace — avoid war: Jin ×3, Rei ×2, Gi ×2. Role: Courtier ×2, Crane clan ×2. Yu ×0.3, Kyōryōku ×0.2, Ishi ×0.3.

Build the strongest fighting force: Kyōryōku ×4, Ketsui ×3, Yu ×2. Role: Military commander ×3, Bushi ×2. Rei ×0.3, Dōsatsu ×0.5.

**Economic Standing Objectives — Weights:**

Maximize my province’s prosperity: Jin ×2, Chugi ×2, Kanpeki ×2. Role: Provincial Daimyo ×4, Local Daimyo ×3. Seigyo ×0.5.

Control the Empire’s trade networks: Seigyo ×3, Chishiki ×2. Role: Mantis clan ×3, Crane clan ×2, merchant-adjacent role ×3. Meiyo ×0.3.

Ensure my clan never faces shortage: Chugi ×3, Jin ×2, Ketsui ×2. Role: Clan Champion ×2, Family Daimyo ×2. Seigyo ×0.5.

Accumulate personal wealth: Seigyo ×2. Role: Minor samurai ×2. Meiyo ×0.2, Gi ×0.3.

**Personal Standing Objectives — Weights:**

Honor my ancestors: Chugi ×3, Meiyo ×3, Makoto ×2. Lion clan ×2. Available to any role.

Protect those under my care: Jin ×4, Chugi ×2, Rei ×2. Role: Provincial Daimyo ×2, Local Daimyo ×2. Seigyo ×0.3, Kyōryōku ×0.5.

Accumulate knowledge and wisdom: Chishiki ×4, Dōsatsu ×3. Role: Shugenja ×3, Courtier ×2, Dragon clan ×2. Kyōryōku ×0.3.

Achieve personal excellence: Kanpeki ×4, Ketsui ×2, Meiyo ×2. Available to any role.

Elevate my family name: Seigyo ×2, Ketsui ×2. Role: Minor family ×3, junior samurai ×2. Chugi ×0.5.

Live by Bushido without compromise: Meiyo ×4, Gi ×3, Makoto ×2. Lion clan ×2, Scorpion clan ×0.2. Available to any role.

Advance personal Glory: Kyōryōku ×2, Seigyo ×2, Ketsui ×2. Role: Bushi ×2, Courtier ×2.

Seek vengeance: Only available if character has a historical modifier of −50/−50 (killed a family member) in their starting disposition table. Ishi ×3, Kyōryōku ×2, Ketsui ×2. Jin ×0.3.

## 18.9 Objective Negligence and Betrayal Consequences — LOCKED

Honor is inward. The penalties in this section apply automatically based on what the character knows about their own conduct — not based on whether their lord has discovered the failure. A samurai who neglects their duty knows it. The shame is private before it is ever public.

**Honor Penalties — Negligence and Betrayal:**

- Failing to pursue an assigned primary objective — per IC season with no meaningful action taken toward it: −0.1 Honor. Passive negligence. The character was capable but chose not to act.

- Actively working against an assigned primary objective: −0.5 Honor immediately upon the contradicting action.

- Publicly abandoning an assigned primary objective: −1.0 Honor. Equivalent to reneging on a Public Declaration. The word was given to a lord — more serious than a court commitment to peers.

- Completing an assigned primary objective: +0.1 Honor. Duty fulfilled.

**External Consequences — If the Lord Discovers Active Opposition:**

Discovery of active opposition — a vassal working against their lord’s objective — is not automatic. It requires evidence reaching the lord through the game’s information systems: the conversation system, the letter system, or deliberate intelligence actions. The accusation itself becomes a Tier 4 Political topic (Betrayal) and spreads through the social network.

The lord’s response depends on their disposition toward the accused vassal. Disposition determines how much evidence is required before the lord acts:

- Trusted Ally / Devoted (+61 to +100): Requires overwhelming, irrefutable evidence from multiple independent sources. A single accusation from a rival is dismissed. The lord actively resists believing it.

- Friend (+31 to +60): Requires solid corroborating evidence. A single accusation triggers investigation, not immediate action.

- Acquaintance / Stranger (−10 to +30): Credible evidence from a trusted source is sufficient. No strong attachment clouds judgment.

- Rival / Enemy (−11 and below): The lord is already suspicious. Light evidence confirms what they already suspected.

**The Seppuku Demand:**

When a lord believes the evidence and determines that active betrayal occurred, the appropriate response is a demand for seppuku. This is the formal resolution of a fundamental breach of duty — the vassal pays the ultimate price to preserve the family name and partially restore what was broken.

- Vassal performs seppuku: Honor is partially restored. The family name is preserved. The debt is paid. A Death topic (variant: seppuku) is generated.

- Vassal refuses seppuku: They are stripped of their clan and family ties immediately. They become Ronin. Exile follows — they cannot operate within the political and social structure they betrayed. −1.0 Honor for the refusal itself. Permanent negative historical modifier with the entire clan and all associated families. A Retirement or Exile topic (variant: forced weakness) and a Betrayal topic are both generated.

**Fabricating Accusations:**

Forging proof of betrayal, planting evidence, and manipulating witnesses are possible but dangerous. These mechanics are fully designed in the Secret System (Section 12.8) — fabrication uses Forgery/Agility with TNs scaled by severity tier, and exposure of fabrication generates a permanent −25/−25 disposition modifier and a Betrayal topic. The principle is established here: a fabricated accusation of betrayal that is later exposed as false constitutes one of the most severe Honor violations in the game. The fabricator faces their own seppuku demand from their own lord for the dishonor brought upon the clan. Fabrication must be difficult, risky, and costly — but not impossible. This is Rokugan.

⚙️ CROSS-REF (v582): The objective derivation and cascade mechanism described qualitatively in Section 18.2 (“Primary objectives cascade down the hierarchy. A lord’s primary objective generates derived primary objectives for their vassals”) is formally specified in Section 57.54 (Clan Champion Strategic Evaluation System) and Sections 57.54.9–57.54.13 (Decision Hierarchy). Four tiers: Tier 1 Clan Champion produces clan_strategic_priorities (14 conclusion types, Section 57.54.1–8). Tier 2 Family Daimyo translates conclusions into territory-specific NeedTypes via mapping table, personality re-weighting, and combined pool with local needs (Section 57.54.10a–e). Tier 3 Provincial Daimyo receives ImmediateNeed via ASSIGN_VASSAL_OBJECTIVE, executes with local adjustment (Section 57.54.11). Tier 4 Individual samurai receives NeedType, executes via standard Phase 5 (Section 57.54.12). Target field inheritance (Section 57.54.10e) populates ImmediateNeed across all tiers. Delegation awareness (Section 57.54.10d) applies to all characters with subordinates (lord_id or operational_superior_id). The “hierarchy cascade” in Section 18.7 is the same system viewed from the topic/disposition perspective.

