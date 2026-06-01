## 52a World Generation Parameters — LOCKED

This addendum formalizes PROVISIONAL values for world initialization (GDD s52,
s2.3, s4.3, s22.4, s22.7, s57.21): character insight rank by position, status by
position, PU initialization constants, terrain multipliers, PU sub-type distribution,
character trait point budget, demographic parameters, and military structure sizing.

---

### Summary Table

| Value | Constant / Location | Section |
|-------|---------------------|---------|
| POSITION_RANK table (39 entries) | world_population_generator.gd | A23 |
| POSITION_STATUS: Local Daimyo | 4.0 | A24 |
| POSITION_STATUS: Provincial Daimyo | 5.0 | A24 |
| BASE_PU: FAMILY_SEAT / GREAT_CLAN / MINOR_CLAN / UNGOVERNABLE | 20 / 10 / 5 / 1 | A25 |
| Terrain PU multipliers (6 terrain types) | world_bootstrap.gd | A26 |
| TERRAIN_PU_DISTRIBUTION (8 terrain types, 4 sub-types each) | world_generator.gd | A27 |
| POINTS_PER_RANK (trait point budget per insight rank) | 4 | A28 |
| Parent age range for child generation | min gap 16, max gap 40 years | A29 |
| Marriage rate at world generation | 40% per generation | A30 |
| Cross-clan marriage rate | 15% of marriages | A31 |
| LEGIONS_PER_ARMY | 3 | A32 |
| Minor Clan Champion stipend | 3.0 koku/season | A33 |

---

### A23 — POSITION_RANK Table

**GDD source:** s22.8 lists positions but assigns no insight rank. s22.4 gives ring
point ranges per rank but not a position-to-rank mapping.

**Derivation:** Role-required excellence. Positions that require mastery of school
techniques or empire-wide recognition as the finest practitioner receive Rank 5.
Positions requiring proven excellence across a full career receive Rank 4. Established
veteran positions receive Rank 3. Junior lord and junior officer positions receive
Rank 2. Base samurai receives Rank 1.

| Position | Rank | Rationale |
|----------|------|-----------|
| EMPEROR | 5 | Divine mandate; generations of refinement expected |
| IMPERIAL_HEIR | 4 | Being groomed for throne; excellence expected |
| IMPERIAL_ADVISOR | 4 | Proven political mind; experienced counsellor |
| IMPERIAL_CHANCELLOR | 4 | Proven administrator; experienced |
| IMPERIAL_HERALD | 3 | Established courtier; skilled but not pinnacle |
| IMPERIAL_TREASURER | 3 | Established administrator |
| VOICE_OF_EMPEROR | 3 | Established courtier/official |
| EMERALD_CHAMPION | 5 | Empire's finest duelist/magistrate |
| JADE_CHAMPION | 5 | Empire's finest shugenja |
| AMETHYST_CHAMPION | 4 | Proven excellence in their domain |
| TURQUOISE_CHAMPION | 3 | Commerce/trade excellence; domain favors experience |
| TOPAZ_CHAMPION | 2 | Won at gempukku (Rank 1); now established (Rank 2) |
| RUBY_CHAMPION | 4 | Proven excellence |
| IMPERIAL_FAMILY_DAIMYO | 4 | Leader of Seppun/Otomo/Miya; proven |
| CLAN_CHAMPION | 5 | Pinnacle representative of their clan's excellence |
| FAMILY_DAIMYO | 4 | Proven family leader |
| RIKUGUNSHOKAN | 4 | Army general; proven military excellence |
| SENIOR_COURTIER | 3 | Experienced court figure; not the pinnacle |
| CLAN_MAGISTRATE_COMMANDER | 3 | Senior magistrate; proven track record |
| SCHOOL_MASTER | 5 | Must have mastered all school techniques |
| PROVINCIAL_DAIMYO | 3 | Established provincial administrator |
| LOCAL_DAIMYO | 2 | Junior lord managing a single holding |
| CLAN_MAGISTRATE | 2 | Established but junior magistrate |
| GARRISON_COMMANDER | 2 | Established but junior military position |
| TAISA | 3 | Veteran battalion commander |
| CHUI | 2 | Junior military officer |
| TEMPLE_HEAD | 5 | Highest religious leadership; spiritual mastery required |
| MONASTERY_ABBOT | 5 | Highest monastic leadership; spiritual mastery required |
| EMERALD_MAGISTRATE | 4 | Significant law/investigation experience required |
| JADE_MAGISTRATE | 4 | Significant shugenja experience required |
| INQUISITOR_LEADER | 5 | Expert in maho detection; highest Asako authority |
| WITCH_HUNTER_LEADER | 5 | Expert Kuni hunters; deepest Shadowlands knowledge |
| KUROIBAN_LEADER | 5 | Expert spirit hunters; deepest Seppun expertise |
| YORIKI | 2 | Assistant to magistrate; established but junior |
| MINOR_CLAN_CHAMPION | 4 | Proven excellence for their clan |
| MINOR_CLAN_SENIOR | 3 | Established senior figure in minor clan |
| WALL_SEGMENT_COMMANDER | 4 | Significant Crab military experience required |
| HIRUMA_SCOUT_COMMANDER | 4 | Deep Shadowlands survival expertise required |
| SAMURAI | 1 | Base rank for unpositioned samurai |

---

### A24 — POSITION_STATUS Corrections

**GDD source:** s22.4 gives two anchors: "Local Daimyo 3.0" and "samurai 1.0" as
examples. No other positions are explicitly anchored.

**Problem:** The existing table had `LOCAL_DAIMYO = 3.0` and
`PROVINCIAL_DAIMYO = 4.0`. When `lord_rank_from_status()` resolves governance
authority, the thresholds are: `< 4.0` → VILLAGE_HEADMAN (0 civilian orders),
`≥ 4.0` → CITY_DAIMYO (5 civilian orders), `≥ 5.0` → PROVINCIAL_DAIMYO
(8 civilian orders). This meant:

- Local Daimyo at 3.0 resolved as VILLAGE_HEADMAN → 0 civilian orders (cannot govern)
- Provincial Daimyo at 4.0 resolved as CITY_DAIMYO → wrong governance tier

**Correction:**
- `LOCAL_DAIMYO: 3.0 → 4.0` — resolves as CITY_DAIMYO (5 civilian orders);
  matches a lord who governs a single settlement but is not a provincial authority
- `PROVINCIAL_DAIMYO: 4.0 → 5.0` — resolves as PROVINCIAL_DAIMYO (8 civilian
  orders); correctly represents a province-level governance tier

All other POSITION_STATUS entries are unchanged.

**Note on GDD anchor:** GDD s22.4 example states "Local Daimyo 3.0" for Status.
This addendum overrides that example because Status 3.0 produces a governance
category with 0 civilian orders, making Local Daimyo functionally non-governing.
The GDD example appears to be illustrative of the Status scale rather than a
normative assignment for the simulation. The 4.0 value aligns Local Daimyo with
the minimum governing tier.

---

### A25 — BASE_PU Constants

**GDD source:** GDD s4.3 describes PU as the measure of provincial production
capacity but does not specify starting values for world initialization.

**Architecture note:** PU is held entirely on `SettlementData.population_pu`.
`ProvinceData` has no PU field — `generate_province()` does not store `total_pu`.
These BASE_PU constants seed settlement PU via `_create_province_settlements()`:
family seat castles receive `BASE_PU / 2` after terrain scaling; non-seat
provinces receive a village with 2–5 PU.

| Province Tier | BASE_PU | Castle PU (after halving) |
|---------------|---------|--------------------------|
| FAMILY_SEAT | 20 | ~7–10 after terrain scaling |
| GREAT_CLAN non-seat | 10 | Village: 2–5 |
| MINOR_CLAN | 5 | ~2–3 (keep) |
| UNGOVERNABLE | 1 | No settlements created |

These are initialization values for a fresh world. The simulation's production
mechanics are expected to grow or shrink PU dynamically during play.

---

### A26 — Terrain PU Multipliers

**GDD source:** s4.3 describes terrain type effects on production qualitatively
(plains fertile, mountains mineral-rich, wasteland barren) but specifies no
numeric scaling factors.

| Terrain | Multiplier | Rationale |
|---------|------------|-----------|
| PLAINS | 1.2 | Most fertile agricultural terrain |
| COASTAL | 1.0 | Average; trade compensates for limited farming |
| FOREST | 0.9 | Slightly reduced; logging and hunting offset |
| MOUNTAINS | 0.7 | Mining compensates; farming reduced |
| SWAMP | 0.6 | Difficult terrain; limited agricultural use |
| WASTELAND | 0.3 | Severely limited; primarily military outpost territory |

±10% variance applied after multiplication to create natural world variation.

---

### A27 — TERRAIN_PU_DISTRIBUTION

**GDD source:** s4.3 establishes four PU sub-types (farming, town, mining,
military) and describes their production outputs, but does not specify
allocation percentages by terrain.

**Derivation:** Percentages calibrated against L5R geographic flavor. Plains
are primarily agricultural with some commerce. Mountains favor mining. Wasteland
is almost entirely military.

| Terrain | Farming % | Town % | Mining % | Military % |
|---------|-----------|--------|----------|------------|
| PLAINS | 60 | 25 | 5 | 10 |
| RIVER_DELTA | 65 | 25 | 0 | 10 |
| FOREST | 45 | 25 | 15 | 15 |
| HILLS | 40 | 25 | 25 | 10 |
| MOUNTAINS | 25 | 20 | 40 | 15 |
| SWAMP | 50 | 20 | 5 | 25 |
| WASTELAND | 15 | 15 | 10 | 60 |
| COASTAL | 50 | 30 | 5 | 15 |

---

### A28 — POINTS_PER_RANK (Trait Point Budget)

**GDD source:** s22.4 gives ring value ranges per Insight Rank but does not
specify a point budget for trait advancement during world generation.

**Value:** `POINTS_PER_RANK = 4`

**Derivation:** Four points per rank allows Insight Rank 5 characters to have
distributed 16 trait advances above starting values (rank 1 base). This
produces plausible spread across the 8 traits for veteran characters without
making world-start NPCs unnaturally uniform.

**Note:** CLAUDE.md previously recorded this value as "10 per insight rank" —
that was an error. The code value of 4 is correct.

---

### A29 — Parent Age Range for Child Generation

**GDD source:** GDD s22.4 describes the biological family web but specifies no
minimum/maximum parent age constraints for world generation.

**Values:** Minimum parent-child age gap: 16 years. Maximum: 40 years.

**Rationale:** 16 years represents the earliest plausible parenthood after
gempukku (typical gempukku age: 15). 40 years represents the upper bound of
likely childbearing. Both values apply to the synthetic age-gap when generating
parent-child pairs during world bootstrap.

---

### A30 — Marriage Rate

**GDD source:** s22.7 describes the marriage system but specifies no probability
for world-start marriage frequency.

**Value:** 40% of eligible samurai per generation are assigned spouses during
world generation.

**Rationale:** Leaves the majority of lower-status samurai unmarried at world
start (consistent with marriage-as-political-instrument flavor of Rokugan), while
ensuring most senior characters have established family bonds.

---

### A31 — Cross-Clan Marriage Rate

**GDD source:** s22.7 describes cross-clan marriages as politically significant
but specifies no frequency.

**Value:** 15% of world-generation marriages are cross-clan.

**Rationale:** Rare enough to be noteworthy (political alliances), common enough
to create the family bond cross-clan tension the system requires.

---

### A32 — LEGIONS_PER_ARMY

**GDD source:** s57.21 establishes the military hierarchy (Company → Legion →
Section → Army) but does not specify the number of legions in an army.

**Value:** `LEGIONS_PER_ARMY = 3`

**Rationale:** Consistent with L5R 4e's implied scale: a standard Rokugan army
of ~3,000 soldiers organized into companies of ~100 men would yield approximately
3 legions of ~1,000 each. Used only for world initialization; actual army
composition varies through play.

---

### A33 — Minor Clan Champion Stipend

**GDD source:** s4.3 specifies stipend by lord rank but does not have an
explicit entry for Minor Clan Champion. Clan Champion receives 5.0 koku/season.

**Value:** `Minor Clan Champion: 3.0 koku/season`

**Derivation:** Equal to Family Daimyo (s4.3). Minor Clan Champions govern
at a scale comparable to a Great Clan Family Daimyo — a single clan with
limited territory — rather than at the scale of a Great Clan Champion who
oversees multiple families and dozens of provinces.
