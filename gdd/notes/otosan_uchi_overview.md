# Otosan Uchi — Capital Overview (reference visual)

> **Reference note, not design source.** This file is a hand-drawn visual digest of
> the Imperial Capital, derived entirely from the LOCKED data in s2.3.23 (district
> table, PU, Governor tiers, clan preferences, handcrafted landmarks) and the
> `OtosanUchiZoneBuilder.DISTRICTS` table. It introduces no new design content.
> The authoritative source is always /gdd/s02.3 §2.3.23.
> Per-district ASCII map styles are rendered in
> [`otosan_uchi_district_maps.md`](otosan_uchi_district_maps.md).

Increasing indentation = deeper access tier (Toshisoto → Ekohikei → Forbidden City).

```
~~~~~~~~~~~~~~~~~~~~~~~~~ Bay of the Golden Sun ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      OTOSAN UCHI — the Imperial Capital · the only Miyako in the Empire
      100 PU (~50,000 souls) · the River of the Sun runs through the city

 ╔══════════════════════════════════════════════════════════════════════╗
 ║ ◆ TOSHISOTO — Outer City — 11 districts — 82 PU — Governor Status 4.5  ║
 ╠══════════════════════════════════════════════════════════════════════╣
 ║              sentaku      district          PU   Governor clan-pref    ║
 ║  waterfront  Higshikawa   North Dock         6   Lion / Crab / Unicorn ║
 ║   ▸ on the   Kosuga       South Dock        12   Crab / Unicorn / Imp. ║
 ║     water    Hojize       Rich Crescent     10   Lion / Imperial       ║
 ║              Hinjaku      Eta's Island       3   Crab                  ║
 ║  commerce    Tsai         Brutal Flame       5   Scorpion / Crab / Tor.║
 ║   & arts     Hidari       Emperor's Road     7   Crane / Imperial      ║
 ║              Juramashi    Juramashi         15   (none — craftsmen)    ║
 ║              Hayasu       Gilded Hill        8   Crane / Imperial      ║
 ║  sacred      Ochiyo       Spiritual          6   Imperial / Phoenix    ║
 ║   & law      Toyotomi     Prison / Moon      5   Scorpion / Crab / Lion║
 ║              Meiyoko      Tenari's Ruin      5   Scorpion / Lion / Crab║
 ║                                                                        ║
 ║      ╔════════════════════════════════════════════════════════════╗   ║
 ║      ║ ◆ EKOHIKEI — Inner City — 4 districts — 15 PU — Governor 5.0 ║   ║
 ║      ╠════════════════════════════════════════════════════════════╣   ║
 ║      ║   Kanjo   5  Imperial        Karada  3  Crab                ║   ║
 ║      ║   Chisei  4  Crane           Hito    3  Lion                ║   ║
 ║      ║   ▲ entered only via the guarded tier gates:               ║   ║
 ║      ║     · jade torii arches      (from Hidari / Emperor's Road) ║   ║
 ║      ║     · Bloodhawk Bridge ckpt. (from Hojize / Rich Crescent)  ║   ║
 ║      ║                                                            ║   ║
 ║      ║      ╔══════════════════════════════════════════════╗      ║   ║
 ║      ║      ║ ◆ FORBIDDEN CITY — 1 zone — 3 PU — NO Governor║      ║   ║
 ║      ║      ╠══════════════════════════════════════════════╣      ║   ║
 ║      ║      ║  The Emperor's direct domain. Kyuden Otomo    ║      ║   ║
 ║      ║      ║  sits within. Untaxed — its Koku flows whole  ║      ║   ║
 ║      ║      ║  to the Imperial stockpile.                   ║      ║   ║
 ║      ║      ╚══════════════════════════════════════════════╝      ║   ║
 ║      ╚════════════════════════════════════════════════════════════╝   ║
 ╚══════════════════════════════════════════════════════════════════════╝
        Access gating (Toshisoto → Ekohikei → Forbidden City) is the
        Sentaku access-petition pipeline; each ring is an access_layer.
```

## Landmark highlights

The handcrafted Lesser Zones each district *would* contain (s2.3.23):

- **Tsai · Brutal Flame** — Zankoku Hon'O (lighthouse, never gone dark) · Bayushi's Mask (Scorpion okiya) · The Tear (Scorpion theater) · Shrine of Hofukushu (Fortune of Vengeance, hidden) · Bayushi's Bane (Agasha poison hospital)
- **Hidari · Emperor's Road** — Road of the Most High · the jade torii (gate to Ekohikei) · Emerald Coin plaza · Doji's Children (Crane okiya) · Soshiuchi / House of Loss (haunted Crane mansion)
- **Juramashi** — Craftsman's Quarter · Bright Wind geisha house · Natsu-Togumara Shrine (Fortune of Travel) · District Meeting Hall *(the capital's largest district at 15 PU)*
- **Ochiyo · Spiritual** — Temple of the Sun Goddess (largest building) · Temples of Daikoku, Ebisu & Benten · secluded meditation gardens · Seppun's Path
- **Hayasu · Gilded Hill** — Shining Square · Cherry Blossom Row (Kakita-cultivated) · Chirping Crickets (immaculate samurai gardens) · hilltop Governor's estate
- **Hojize · Rich Crescent** — the Wharves (½ the city's river traffic) · Bloodhawk Bridge (Ekohikei checkpoint) · Kinjiren Tombs · Miya's Koku Seal office
- **Hinjaku · Eta's Island** — Takusanno Sakanaya (fishery, Pink Hamachi sushi) · the eta quarter beyond the walls *(split off Rich Crescent by a Lion governor)*
- **Toyotomi · Prison/Moon** — Kyuden Kokai, the Palace of Remorse (city prison) · magistrate station (25 yoriki, 100+ doshin) · the Moon gambling quarter
- **Meiyoko · Tenari's Ruin** — Tenari's haunted ruins · Hana Garden (iris, Shintao rock gardens) · criminal refuges
- **Higshikawa · North Dock** — Morning Star Wharves · Takeo Library (Ikoma records) · Imperial Guard kaisha (Lion barracks)
- **Kosuga · South Dock** — primary trade port (⅖ of city trade) · Flooded Merchant Bazaar · Daikoku Arch (ancient torii) · Yatoshin warehouses

## Simulation status

This layout is what the simulation already runs on: each district's PU generates
Koku → the Governor retains their `SET_TAX_RATE` share (10–50%, Honor-inverse for
NPCs) → the remainder flows to the Emperor; per-district stability/crime/unrest run
each season, with sustained deep crisis breeding an s11.11 peasant revolt that drags
stability further. The renderable per-district **tile maps** remain a deferred content
task (s4.4: Otosan Uchi is "Fully handcrafted … a content creation task").
