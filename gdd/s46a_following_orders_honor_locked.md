## 46a Following Orders Honor Table — LOCKED

This addendum formalizes the numeric values for the "Following Orders Despite
Misgivings" row of Table 2.3 (GDD s46), referenced in s55.25 and implemented
in `crime_system.gd:HONOR_TABLE_FOLLOWING_ORDERS`.

---

### Summary

| Honor Rank | Raw Value | Honor Change (÷10) |
|------------|-----------|---------------------|
| 0 (dishonorable) | +6 | +0.6 |
| 1–2 (low) | +4 | +0.4 |
| 3–4 (middle) | 0 | 0.0 |
| 5–6 (high) | 0 | 0.0 |
| 7–8 (very high) | −2 | −0.2 |
| 9–10 (near-perfect) | −4 | −0.4 |

**Array constant:** `HONOR_TABLE_FOLLOWING_ORDERS = [6, 4, 0, 0, -2, -4]`

---

### GDD Source

GDD s55.25 (Objective Decomposition — Personal Standing Objectives, Edge Case):

> "Table 2.3: 'following orders despite misgivings' is actually positive at
> low ranks but NEGATIVE at high ranks. A high-Honor samurai who refuses a
> dishonorable order is living their objective."

The row name is "following orders despite misgivings." The moral calculus
depends on the character's honor rank:

- **Low honor (ranks 0–2):** Following orders is simply what a dutiful
  samurai does. There are no real misgivings — the character's ethical
  framework is not yet refined enough to feel the tension. Compliance is
  an improvement over pure self-interest. The honor gain rewards basic
  feudal duty.

- **Middle honor (ranks 3–6):** The character is doing their job. The order
  is within the bounds of ordinary expectation. No strong signal in either
  direction — this is baseline samurai comportment.

- **Very high honor (ranks 7–10):** At this level, a character has developed
  an acute ethical sensibility. A high-Honor samurai who perceives a conflict
  between the order and their principles and chooses obedience anyway is making
  a genuine moral compromise. The small daily honor cost accumulates to reflect
  that sustained compliance with lord directives — even routine ones — carries a
  cost for those who have developed strong independent ethical judgment.

---

### Trigger

`_process_following_orders_honor_writebacks()` fires in `day_orchestrator.gd`
during the daily wave writeback pass. Conditions:

1. The character executed at least one successful action today.
2. Their primary objective has `assigned_by >= 0` (lord-assigned, not
   self-selected).
3. The character is alive.
4. Deduplicated: fires at most once per character per day regardless of how
   many lord-assigned actions they executed.

---

### Calibration

| Row | High-rank cost | Comparison |
|-----|---------------|------------|
| FALSE_COURTESY | 0 to −1.0 | Actively deceiving through politeness |
| DISOBEYING_LORD | 0 to −1.0 | Open insubordination |
| FOLLOWING_ORDERS (high rank) | −0.2 to −0.4 | Compliance despite conscience |
| PROTECTING_CLAN (gain) | +0.2 to +0.8 | Defending clan at personal risk |
| KINDNESS_BELOW_STATION (gain) | +0.2 to +0.6 | Deliberate generosity downward |

The negative values at high honor are intentionally gentle relative to active
violations (FALSE_COURTESY, DISOBEYING_LORD). Following orders is not a
violation — it is a structural duty of samurai society. The cost reflects a
subtle, cumulative tension between institutional loyalty and personal ethical
development, not a sharp moral failure.

---

### Design Note: Tension Without Trap

This row should not penalize high-honor characters so heavily that following
a lord's orders becomes mechanically unviable. The daily dedup cap ensures that
regardless of how productive a high-honor character is on a given day, the
maximum honor exposure from this row is −0.4 per day. A Rank 9 character
following lord orders for an entire season (90 days) accrues −36 points =
−3.6 Honor rank from this source alone. That is a meaningful but not
disqualifying signal — it represents the authentic L5R tension between Chugi
(duty) and Makoto (sincerity/personal integrity) at the highest levels of
moral development.
