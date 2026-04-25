# Simulation Rules & Philosophy (Working Draft)

This document captures the current design intent for the galaxy simulation.
It is intentionally short and should evolve with the code.

## Core Philosophy

- Prefer **smooth scaling formulas** over hard step thresholds.
- Keep systems **predictable and tunable** through clear constants.
- Avoid hidden coupling: separate **production logic** from **storage logic**.
- Use **defensive numeric handling** to prevent invalid values and drift.

## Current Rules

### Food
- Food production uses diminishing returns based on assigned farming workers.
- Food demand scales with population and should remain strict enough to matter strategically.
- Starvation and recovery should be explicit and easy to inspect in logs.

### Happiness
- Happiness demand should track the free population proportionally.
- Happiness production also uses diminishing returns.
- Happiness affects production through a clamped multiplier with a minimum floor to avoid total collapse.

### Production & Storage
- Production multipliers apply to production outputs.
- Storage capacities are not multiplied by happiness.
- Quantities persisted to storage should use integer-safe conversions to avoid float propagation in arrays/state.

## Engineering Notes

- Preserve existing structure and naming where practical to reduce regression risk.
- Prefer small, verifiable changes and keep logs informative for balancing work.
- When adjusting formulas, update this file with rationale and expected gameplay impact.
