# s31–37a — WEATHER_SHIFT Province Weather System — LOCKED

## Overview

`SpellSimEffect.WEATHER_SHIFT` (value 16) marks spells that alter weather conditions.
At simulation level, only spells that produce a province-scale weather change with a
duration extending beyond a single combat scene are wired to the province weather system.
All other WEATHER_SHIFT spells are combat-duration concentration effects → `COMBAT_ONLY`.

---

## Province Weather State (ProvinceData)

Two new fields on `ProvinceData`:

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `province_weather_state` | `int` | `0` | Current weather. Uses `AsciiMapEnvironment.WeatherState` int values. `0` = CLEAR (no spell active). |
| `province_weather_expires_ic_day` | `int` | `-1` | IC day when weather resets to CLEAR. Sentinel `-1` = no active spell weather. |

The weather state is cleared (set to 0) when `ic_day >= province_weather_expires_ic_day`.
This runs at the start of each IC day via `DayOrchestrator._expire_province_weather()`.

---

## Spells Classified as Province-Level WEATHER_SHIFT

### `endless_deluge` (Water ML3)

GDD description: "A ritual (minimum 10 minutes to cast). Water spirits in the sky
congregate and unleash a massive rainstorm. Chief use: extinguish fires and abate drought.
Side effects: −1k0 to all physical actions, −2k0 to ranged attacks, −1k1 to Fire Spell
Casting Rolls within the storm."

| Value | Constant | Rationale |
|-------|----------|-----------|
| Province weather state | `WeatherState.STORM` (3) | "Massive rainstorm" — map to heaviest persistent precipitation type. |
| Duration | 1 IC day | GDD says 12 hours. IC tick = 1 IC day. 12 hours < 24 hours → rounds up to 1 tick minimum. |

**Simulation effects of STORM on ASCII map missions (from `AsciiMapEnvironment.WEATHER_DATA`):**
- Ranged TN +10, vision −4, movement ×3.0
- This is applied automatically by `MissionBuilder.assemble()` when it reads `province_weather_state`.

**Downstream effects deferred:**
- Drought abatement in ResourceTick: no numeric value in GDD s4.3. Implement when s4.3
  specifies a weather modifier for farming production.
- Travel speed modifier: TravelSystem has no weather modifier. Implement when s11.7a specifies.

---

### `breath_of_mist` (Water ML6)

GDD description: "Evokes hundreds of Water kami to reduce the ground to half-liquid mire
while filling the air with water vapor to obscure vision. Entire armies have been rendered
effectively helpless."

| Value | Constant | Rationale |
|-------|----------|-----------|
| Province weather state | `WeatherState.MIST` (5) | Creates obscuring mist/fog. |
| Duration | 1 IC day | No duration specified. Water Ring hours = ≤10 hours at max ring. Rounds up to 1 IC day tick. |

**Simulation effects of MIST on ASCII map missions:**
- Vision −3, stealth +5, movement ×1.0 (concentration-only)

---

## Spells Reclassified to COMBAT_ONLY

These spells are concentration-maintained or single-combat-duration. No province weather write.

| Spell | Element | ML | Reason |
|-------|---------|----|--------|
| `blessed_wind` | Air | 1 | Concentration, +15 Armor TN vs ranged. Single-combat. |
| `blessed_wind_of_lady_sun` | Air | 2 | Concentration, area buff/debuff. Single-combat. |
| `summoning_the_gale` | Air | 3 | Concentration, area ranged block. Single-combat. |
| `summon_fog` | Air | 3 | Concentration ("while maintained"), visibility 5 feet. Single-combat. |
| `howl_of_isora` | Air | 4 | One-time damage + knockdown. Instantaneous. |
| `the_swell_of_the_storm` | Water | 1 | One-time knockdown + flame extinguish. Instantaneous. |
| `heavens_tears` | Water | 2 | Brief per-round heal/harm, outdoors only. Single-combat. |

---

## MissionBuilder Integration

`MissionBuilder.assemble()` reads `province.province_weather_state` as `base_weather`
when the province has an active spell weather (state ≠ 0 and expires day > current ic_day).
This replaces the `seed_dict.get("weather", CLEAR)` default when a shugenja-cast storm
is active in the province.

---

## Locked Constants (A80–A83)

| # | Constant | Value | Location |
|---|----------|-------|----------|
| A80 | `endless_deluge` province weather state | `WeatherState.STORM` (3) | `SpellSystem.get_weather_shift_state()` |
| A81 | `endless_deluge` duration | 1 IC day | `SpellSystem.get_weather_shift_duration_days()` |
| A82 | `breath_of_mist` province weather state | `WeatherState.MIST` (5) | `SpellSystem.get_weather_shift_state()` |
| A83 | `breath_of_mist` duration | 1 IC day | `SpellSystem.get_weather_shift_duration_days()` |
