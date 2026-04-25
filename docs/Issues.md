# Issues

This document lists the balancing issues currently visible in the test-simulation economy after the Pop Unit / Luxury paradigm transition.

## 1) Governor ore threshold is still tuned for the old economic scale

### What is happening
- The governor logic still uses a very high ore floor per foundry (`GOVERNOR_ORE_PER_FOUNDRY_THRESHOLD = 120`).
- The foundry conversion now runs on a smaller scale (`3 ore -> 1 metal`) with 1-pop staffing assumptions.

### Why this is an issue
- The governor can over-prioritize mining construction even when the settlement is already healthy under the new Pop Unit scale.
- This distorts build queues and can delay farming/storage/pleasure responses.

### Impact on balancing
- AI/governor behavior appears more resource-anxious than intended.
- Production chains can skew toward ore stockpiling pressure.

---

## 2) Test fixtures begin with over-cap storage states

### What is happening
- Storage infrastructure capacity is now 100 units, but several fixtures still start with stored values above that cap (for example 400 or 1000 food).

### Why this is an issue
- Simulations begin from impossible or inconsistent states relative to the new infrastructure rules.
- Early-day behavior and validation outcomes can be misleading.

### Impact on balancing
- It becomes harder to interpret whether economy behavior is healthy, because the start state itself violates the target constraints.

---

## 3) Housing data fields and housing runtime logic are inconsistent

### What is happening
- Runtime population capacity is computed as `+5` per housing infrastructure.
- In fixture data, housing infrastructures still use large `storage_capacity` values (legacy-style fields).

### Why this is an issue
- The data presentation suggests one housing model while the runtime uses another.
- This increases risk of future regressions when someone edits fixtures expecting `storage_capacity` to matter for housing.

### Impact on balancing
- Balancing discussions and debugging become less reliable because data and effective logic are not aligned.

---

## 4) Farm storage asymmetry may conflict with desired storage simplicity

### What is happening
- Dedicated storage infrastructures are capped at 100 units.
- Farming infrastructure still uses a much larger food storage floor (1000).

### Why this is an issue
- If the goal is a tight, small-cap logistics economy, farm storage can dominate resilience and reduce the strategic importance of storage buildings.
- If the asymmetry is intentional, it still needs explicit balancing justification.

### Impact on balancing
- Storage pressure, starvation risk, and governor storage decisions may be weaker or less predictable than expected under the new paradigm.

---

## 5) Mixed-era constants remain in some balancing pathways

### What is happening
- Several constants and thresholds still appear inherited from previous large-scale tuning patterns.

### Why this is an issue
- The model now uses Pop Units and very small per-infrastructure staffing; old-scale thresholds can produce unintuitive breakpoints.

### Impact on balancing
- AI priorities, migration pressure, and industrial pacing can behave correctly in code but incorrectly in feel.

---

## 6) Validation helpers are not yet fully re-baselined to new limits

### What is happening
- Existing validation helpers were created across multiple balancing eras and are not all re-authored around the new cap assumptions.

### Why this is an issue
- A validation can still pass while masking tuning problems, or fail for reasons unrelated to intended Pop Unit behavior.

### Impact on balancing
- Reduced confidence in iteration speed and in the meaning of pass/fail outcomes during balancing work.

---

## 7) Documentation and fixtures are not yet fully “single-source” for the new paradigm

### What is happening
- The main design direction is now clear, but practical balancing still relies on a combination of runtime constants, fixture values, and interpretation.

### Why this is an issue
- The more places that can silently diverge, the easier it is for balancing drift to return.

### Impact on balancing
- More time is spent reconciling intent vs behavior instead of tuning gameplay outcomes.

---

## Suggested priority order for fixing

1. Re-baseline governor thresholds to Pop Unit scale.
2. Normalize all fixture starting stocks so they respect 100-cap storage.
3. Align housing fixture fields with runtime housing capacity logic.
4. Decide and document whether farm storage should remain 1000 or be reduced.
5. Re-baseline validation helpers around the finalized limits.
