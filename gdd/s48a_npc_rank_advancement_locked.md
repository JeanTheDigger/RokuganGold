# s48a — NPC Rank Advancement: Locked Values

This addendum formalises the implementation-specific values for the NPC
advancement system described in GDD s48 and s52 Part 3.  All values below
are locked and may be used in code without further design review.

---

## A48a-1  Sensei Self-Gain Rate

GDD s48 states that a Sensei "gains a small amount of progress themselves at
a reduced rate — teaching reinforces mastery."  No numeric value is given.

**Locked value:** `TRAINING_PROGRESS_SENSEI_SELF = 25`

Calibration: half the solo training rate (50).  The GDD describes the gain as
"small" and "reduced," which rules out the full solo rate (50) and the
student-benefit rates (75/100).  Half the solo rate sits between "none" and
"meaningful" and is consistent with the phrase "reinforces mastery" without
implying active practice.

---

## A48a-2  Rank-Up Topic

GDD s48 does not specify whether a topic is generated when a character's
Insight crosses a rank threshold.

**Locked value:** Rank-up generates a **Tier 4 Personal** topic.

- `topic_type = "rank_advancement"`
- `category = TopicData.Category.PERSONAL`
- `tier = TopicData.Tier.TIER_4`
- `title = "[Name] achieves Rank [N]"`
- `subject_character_id = character.character_id`
- `subject_role = "NEUTRAL"` (character is the subject but not in peril)
- Initial momentum = `TopicMomentumSystem.initial_momentum_for_tier(TIER_4)`

Rationale: Rank advancement is a personal milestone, not an empire-wide
political event.  Tier 4 (minor local news) is appropriate — it spreads
through the character's immediate social circle via normal conversation
propagation.  Higher tiers are reserved for deaths, wars, and political crises.

---

## A48a-3  School Rank Synchronisation

GDD s52 Part 3 states: "NPCs do not require Sensei visits to unlock Techniques
— they advance School Rank automatically when Insight threshold is met,
reflecting their ongoing training within their school's dojo."

**Locked behaviour:** When `process_seasonal_advancement()` detects that
`new_rank > old_rank`, it immediately sets `character.school_rank = new_rank`.

This keeps the stored `school_rank` field (used by tattoo allotment gates,
military promotion scoring, and technique flag assignment) in sync with the
computed insight rank.  No dojo-visit gate is applied to NPCs.

---

## A48a-4  Confirmed Existing Values

The following constants in `simulation/npc_advancement.gd` are confirmed as
GDD-sourced and require no further review:

| Constant | Value | Source |
|----------|-------|--------|
| `XP_TO_PROGRESS` | 200 | GDD s48 "1 XP = 200 progress" |
| `SKILL_PROGRESS_COST` | [1000, 2000, 3000, 4000, 5000] | GDD s48 Skill Progress Costs |
| `RING_PROGRESS_COST` | [4000, 8000, 12000, 16000, 20000] | GDD s48 Ring Progress Costs |
| `TRAINING_PROGRESS_SOLO` | 50 | GDD s48 "Solo training: 50 progress per AP" |
| `TRAINING_PROGRESS_SENSEI_1_ABOVE` | 75 | GDD s48 "Sensei 1 above: 75 progress per AP" |
| `TRAINING_PROGRESS_SENSEI_2_ABOVE` | 100 | GDD s48 "Sensei 2+ above: 100 progress per AP" |
| `IC_DAYS_PER_OOC_DAY` | 4 | GDD s48 "1 OOC day equals 4 IC days" |
| `MAX_SKILL_RANK` | 5 | GDD s48 Skill Progress Costs table |
| `MAX_RING_RANK` | 5 | GDD s48 Ring Progress Costs table |

All XP rates in `compute_daily_xp()` and all activity multipliers in
`get_activity_multiplier()` are confirmed GDD-sourced from s52 Part 3.

---

## A48a-5  Deferred Items

- **Technique array population** (`character.techniques`): The `techniques`
  field on `L5RCharacterData` is populated by school technique unlocks.
  Individual school technique effects are blocked until the relevant school
  sections are locked.  `SkillResolver.apply_technique_flags()` already handles
  all implemented technique effects; the `techniques` array itself remains as a
  schema placeholder.

- **"Between Ranks" dojo visit mechanic** (GDD s48, School Rank & Techniques):
  This gate applies to player characters only.  NPCs advance automatically per
  A48a-3 above.  PC dojo-visit logic is deferred until the PC interaction system
  is designed.
