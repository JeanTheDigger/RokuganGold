# Food, Resources & Infrastructure (Test Simulation)

This note describes how the current test simulation works in `scripts/GalaxySimulationTest.gd`.

> Scope note: this behavior is currently specific to the **test scripts** and test data (`scripts/GalaxySimulationTest.gd`, `scripts/data/*_test.gd`).

## 1) Worker assignment and infrastructure priority

Workers are assigned per settlement in this order:
1. `farming`
2. `pleasure`
3. `mining`
4. `foundry`
5. `storage`

Assignment behavior by infrastructure type:
- All infrastructure types request their configured `workers` value.
- If `max_workers` is set and greater than `0`, it acts as a hard cap on requested workers.

Assigned workers are capped by the settlement's currently available population.

## 2) Happiness and production multiplier

- Happiness demand only uses non-slave population:

`required_happiness = (free + starving_free) * 0.75`

- Happiness production is the sum of all pleasure infrastructures in the settlement:

`happiness_per_infra = floor((assigned_workers ^ 0.9) * 20)`

- Production multiplier is based on ratio and clamped:

`multiplier = clamp(produced_happiness / required_happiness, 0.25, 1.0)`

This multiplier affects **food production**, not storage capacity.

## 3) Food production and storage

- Farming output before happiness penalty:

`farm_output = floor((assigned_workers ^ 0.9) * 0.25)`

- Final produced food:

`produced_food = floor(farm_output * multiplier)`

Storage flow:
1. Produced food goes to the farming infrastructure first.
2. Farming storage has a minimum capacity floor of `1000`.
3. Overflow is routed to storage infrastructures in the same settlement.
4. A storage infrastructure must have at least `1000` assigned workers to function.
5. Any remaining overflow is lost.

## 4) Resource consumption and accessibility

Daily food demand is based on total population (free + slave + starving_free + starving_slave):

`required_food = ceil(total_population / 35)`

Food is consumed from:
- farming infrastructure stores,
- functional storage infrastructures,
- settlement food holdings **only if** that settlement has at least one functional storage infrastructure.

## 5) Starvation and recovery

- If food is insufficient, unfed population is first applied to already starving groups, which then suffer deaths.
- Remaining unfed population is moved from non-starving to starving pools.
- If enough food is consumed that day, starving population recovers back into non-starving pools.

## 6) Daily growth

After consumption/starvation resolution, non-starving population grows by:

`floor(population * 0.001)`

applied separately to free and slave populations.
