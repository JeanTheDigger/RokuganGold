# Otosan Uchi — District ASCII Map Styles (illustrative)

> **Reference note, not design source, not literal engine output.** Each of the 16
> capital districts declares a thematic `zone_subtype` + `has_ascii_map = true`
> (`OtosanUchiZoneBuilder`), so `AsciiMapGenerator` renders a deterministic 31×31
> street-level map per district on entry. The maps below are faithful reproductions
> of the generators' **deterministic** layouts — the exact tile coordinates from
> `simulation/ascii_map_generator.gd` were ported and rendered through the engine's
> own `get_glyph` table. RNG-scattered detail (trees, mud, shop counts) is placed
> representatively; everything structural is exactly where the code puts it. Eight
> distinct styles cover the 16 districts; same-style districts differ by seed
> (`settlement:zone:subtype`).

**Legend** — `█` stone wall · `┌─┐│└┘┼` wood/paper wall (autotiled) · `∷` stone floor ·
`≡` tatami · `=` wood floor · `.` dirt · `,` mud · `~`/`≈` water · `♣` tree ·
`/` open wood door · `'` open shoji · `∏` open gate · `>` zone exit ·
`⊥` altar · `▣` offering box · `§` incense · `☗` statue (Fortune/komainu) ·
`▭` prayer/kneeling mat · `⊓` magistrate dais · `Ψ` weapon stand · `╥` table ·
`▫` cushion · `║` byōbu screen · `†` brazier · `▦` hearth · `▬` futon · `◍` water jar ·
`▤` shelf · `▥` chest · `▧` crate · `╳` drying net · `╦` vendor stall

---

## MARKET_STREET — Hidari (Emperor's Road), Juramashi

Shop rows north & south (tatami interiors, doors onto the road), a central stone
road band lined with vendor stalls `╦` and goods crates `▧`, exits west/east.

```
┌─────────────────────────────┐
│┼────│∷│────│∷│────│∷│────│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
│───/─┘∷└──/─┘∷└──/─┘∷└──/─┘∷∷│
│∷╦▧∷∷╦∷∷∷╦∷∷∷∷▧∷∷∷▧∷∷╦▧∷∷╦▧∷∷│
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
>∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷>
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
│∷╦▧∷∷╦∷∷∷╦∷∷∷∷▧∷∷∷▧∷∷╦▧∷∷╦▧∷∷│
│───/─┐∷┌──/─┐∷┌──/─┐∷┌──/─┐∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
││≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷│≡≡≡≡│∷∷│
│┼────│∷│────│∷│────│∷│────│∷∷│
└─────────────────────────────┘
```

## PLEASURE_QUARTER — Tsai (Brutal Flame)

A north-south main street with three houses to each side (geisha houses west, sake
houses east), each with a low table `╥`, cushions `▫`, a byōbu screen `║`, and a
brazier `†`; shoji doors `'` onto the street; exits north/south.

```
┌────────────∷∷>∷∷────────────┐
│∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷│
│──────────┐∷∷∷∷∷∷∷┌──────────│
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡║≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡║≡││
││≡≡≡▫╥▫≡≡≡│∷∷∷∷∷∷∷│≡≡≡▫╥▫≡≡≡││
││≡≡≡≡▫≡≡≡≡'∷∷∷∷∷∷∷'≡≡≡≡▫≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡†≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡†≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
│┼─────────│∷∷∷∷∷∷∷│─────────┼│
│┼─────────│∷∷∷∷∷∷∷│─────────┼│
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡║≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡║≡││
││≡≡≡▫╥▫≡≡≡│∷∷∷∷∷∷∷│≡≡≡▫╥▫≡≡≡││
││≡≡≡≡▫≡≡≡≡'∷∷∷∷∷∷∷'≡≡≡≡▫≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡†≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡†≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
│┼─────────│∷∷∷∷∷∷∷│─────────┼│
│┼─────────│∷∷∷∷∷∷∷│─────────┼│
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡║≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡║≡││
││≡≡≡▫╥▫≡≡≡│∷∷∷∷∷∷∷│≡≡≡▫╥▫≡≡≡││
││≡≡≡≡▫≡≡≡≡'∷∷∷∷∷∷∷'≡≡≡≡▫≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
││≡†≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡†≡≡≡≡≡≡≡││
││≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡││
│──────────┘∷∷∷∷∷∷∷└──────────│
│∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷│
└────────────∷∷>∷∷────────────┘
```

## TEMPLE_GROUNDS — Ochiyo (Spiritual)

Temple hall (altar `⊥`, flanking Fortune statues `☗`, incense `§`, offering box `▣`,
prayer mats `▭`) opening south onto a stone courtyard guarded by komainu `☗`, with
garden trees `♣`, torii posts, and the south gate `∏`/exit.

```
██████████████████████████████
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷┌─────────────┐∷∷∷∷∷∷██
██∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡≡≡≡≡│∷♣∷∷∷∷██
██∷♣∷∷∷∷│≡≡☗≡≡≡⊥≡≡≡☗≡≡│∷∷∷♣∷∷██
██∷∷∷∷∷∷│≡≡≡≡§≡≡≡§≡≡≡≡│∷∷♣∷∷∷██
██∷∷♣∷∷∷│≡≡≡≡≡≡▣≡≡≡≡≡≡│♣∷∷∷∷∷██
██∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡≡≡≡≡│∷∷∷∷♣∷██
██∷♣∷∷∷∷│≡≡≡≡≡≡≡≡≡≡≡≡≡│∷∷♣∷∷∷██
██∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷██
██∷∷∷∷∷∷│≡≡≡≡≡▭≡▭≡≡≡≡≡│∷∷∷∷∷∷██
██∷∷∷∷∷∷│≡≡≡≡≡≡≡≡≡≡≡≡≡│∷∷∷∷∷∷██
██∷∷∷∷∷∷└─────///─────┘∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷☗∷∷∷∷∷∷∷☗∷∷∷∷∷∷∷∷∷██
██∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷♣∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷██∷∷█∷∷∷∷∷∷∷∷∷∷∷██
██∷∷∷∷∷∷∷∷∷∷∷█∷∷∷█∷∷∷∷∷∷∷∷∷∷∷██
██████████████∏∏∏██████████████
██████████████∏>∏██████████████
```

## RESIDENTIAL_QUARTER — Hayasu (Gilded Hill), Meiyoko (Tenari's Ruin), Chisei, Hito

A 3×3 grid of walled house plots (hearth `▦`, futon `▬`, water jar `◍`) with alleys
between, a small stone shrine in the south-east corner, exits on the alleys.

```
┌─────────────────────────────┐
│┼───────│.│───────│.│───────┼│
││=======│.│=======│.│=======││
││=▦=====│.│=▦=====│.│=▦=====││
││=======│.│=======│.│=======││
││=======│.│=======│.│=======││
││=======│.│=======│.│=======││
││=◍===▬=│.│=◍===▬=│.│=◍===▬=││
││=======│.│=======│.│=======││
└────/───┘.└───/───┘.└───/────│
>.............................│
┌────────┐.┌───────┐.┌────────│
││=======│.│=======│.│=======││
││=▦=====│.│=▦=====│.│=▦=====││
││=======│.│=======│.│=======││
││=======│.│=======│.│=======││
││=======│.│=======│.│=======││
││=◍===▬=│.│=◍===▬=│.│=◍===▬=││
││=======│.│=======│.│=======││
│────/───┘.└───/───┘.└───/────┘
│.............................>
│────/───┐.┌───/───┐.████'████│
││=======│.│=======│.█∷∷∷∷∷∷∷█│
││=▦=====│.│=▦=====│.█∷∷∷∷∷∷∷█│
││=======│.│=======│.█∷∷∷∷∷∷∷█│
││=======│.│=======│.█∷∷∷∷∷∷∷█│
││=======│.│=======│.█∷∷∷∷∷∷∷█│
││=◍===▬=│.│=◍===▬=│.█∷∷∷∷∷∷∷█│
││=======│.│=======│.█∷∷∷∷∷∷∷█│
│┼───────│.│───────│.█████████│
└─────────────────────────────┘
```

## DOCKS_WATERFRONT — Hojize (Rich Crescent), Higshikawa (North Dock), Kosuga (South Dock)

Warehouses along the north edge, a stone quay with cargo crates `▧` and drying nets
`╳`, timber piers `=` reaching into the bay, exits east/west along the land.

```
...............................
.┌────┐.┌────┐.┌────┐.┌────┐...
.│====│.│====│.│====│.│====│...
.│====│.│====│.│====│.│====│...
.│====│.│====│.│====│.│====│...
.│====│.│====│.│====│.│====│...
.│====│.│====│.│====│.│====│...
.└──/─┘.└──/─┘.└──/─┘.└──/─┘...
>.............................>
...............................
.........╳.......╳.......╳.....
...............................
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
∷∷∷∷∷∷▧▧∷∷∷∷∷∷▧▧∷∷∷∷∷∷▧▧∷∷∷∷∷∷∷
∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷
≈≈≈≈==≈≈≈≈≈≈==≈≈≈≈≈≈==≈≈≈≈≈≈≈≈≈
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~==~~~~~~==~~~~~~==~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## POOR_QUARTER — Hinjaku (Eta's Island), Karada

A dense 4×4 grid of tiny shacks (bare hearth `▦` + water jar `◍`), muddy `,` alleys,
exits east/west.

```
┌─────────────────────────────┐
│┼────│.│────│.│────│.│────│..│
││▦==◍│.│▦==◍│.│▦==◍│.│▦==◍│..│
││====│.│====│.│====│.│====│..│
││====│,│====/.│====│.│====/..│
││====│.│====│.│====│.│====│..│
│───/─┘.└────┘.└──/─┘.└────┘..│
│............,................│
│─────┐.┌────┐.┌────┐.┌────┐..│
││▦==◍│.│▦==◍│.│▦==◍│.│▦==◍│..│
││====│.│====│.│====│.│====│..│
││====/.│====│,│====/.│====│..│
││====│.│====│.│====│.│====│..│
└─────┘.└──/─┘.└────┘.└──/─┘..│
>.............................>
┌─────┐.┌────┐.┌────┐.┌────┐..│
││▦==◍│.│▦==◍│.│▦==◍│.│▦==◍│..│
││====│.│====│.│====│.│====│..│
││====│.│====/.│====│.│====/..│
││====│.│====│.│====│.│====│..│
│───/─┘.└────┘.└──/─┘.└────┘..│
│.............................│
│─────┐.┌────┐.┌────┐.┌────┐..│
││▦==◍│.│▦==◍│.│▦==◍│.│▦==◍│..│
││====│.│====│.│====│.│====│..│
││====/.│====│.│====/.│====│..│
││====│.│====│.│====│.│====│..│
│─────┘.└──/─┘.└────┘.└──/─┘..│
│.............................│
│.............................│
└─────────────────────────────┘
```

## GOVERNMENT_QUARTER — Toyotomi (Prison/Moon), Kanjo (Sentaku Tribunal seat)

Magistrate hall north (dais `⊓`, yoriki weapon stands `Ψ`, petitioner cushions `▫`,
the accused's kneeling mat `▭`), record hall south (archive shelves `▤`, document
chests `▥`), open plaza between, exits east/west.

```
███████████████████████████████
█∷∷█████████████████████████∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡Ψ≡≡≡≡≡≡≡≡≡⊓≡≡≡≡≡≡≡≡≡Ψ≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡▫≡▭≡▫≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡▤≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷████████████/████████████∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
>∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷>
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
█∷∷████████████/████████████∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡▥≡≡≡▥≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡█∷∷█
█∷∷█≡▤≡≡≡▤≡≡≡≡≡≡≡≡≡≡≡▤≡≡≡▤≡█∷∷█
█∷∷█████████████████████████∷∷█
█∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷∷█
███████████████████████████████
```

## AUDIENCE_CHAMBER — Forbidden City

Imperial seat: a great tatami hall inside an engawa corridor, a tokonoma alcove `'`
recessed into the north wall, host seat with table `╥`/cushions `▫`, byōbu screen `║`,
weapon stand `Ψ`, brazier `†`, a fusuma divider creating a southern ante-room, exits
south & east.

```
===============================
===============================
===============================
============┌─────┐============
============│≡≡≡≡≡│============
=====┌─────────'─────────┐=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡Ψ≡│=====
=====│≡≡†≡≡≡▫≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡╥≡≡≡≡≡║≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡▫≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│====>
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│─────────'─────────│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====│≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡│=====
=====└─────────'─────────┘=====
===============================
===============================
===============================
===============================
===============>===============
```


---

## Landmark Lesser Zones (handcrafted layer)

Each district contains child Lesser Zones for its s2.3.23 named landmarks (**121 zones** total), each rendering via the nearest existing interior generator (reuse approach — bespoke generators can swap in later). Names are verbatim from s2.3.23; only GDD-named landmarks become zones. The Forbidden City's Imperial Palace is expanded to its full s57.36 interior set (11 sub-zones), per the s2.3.23 cross-ref "Imperial Palace ... contains 10+ interior sub-zones per Section 57.36."

**Tsai — Brutal Flame District** (Toshisoto) — 11 zones

| Landmark | Interior subtype |
|---|---|
| Zankoku Hon'O (lighthouse) | `WALL_TOWER` |
| Governor's residence | `LORD_QUARTERS` |
| Bayushi's Mask (okiya) | `ENKAI_HALL` |
| Leaves of Shosuro (tea house) | `CHASHITSU` |
| The Tear (theater) | `ENKAI_HALL` |
| Shrine of Hofukushu | `CASTLE_SHRINE` |
| Bayushi's Bane (hospital) | `GUEST_WING` |
| Dragon's Mists (hospital) | `GUEST_WING` |
| Life's Waterfall (sake house) | `ENKAI_HALL` |
| Light as the Wind (kite shop) | `MARKET_STREET` |
| Abandoned waterway houses | `POOR_QUARTER` |

**Hidari — Emperor's Road District** (Toshisoto) — 9 zones

| Landmark | Interior subtype |
|---|---|
| Road of the Most High | `ROAD` |
| Jade torii arches | `CASTLE_SHRINE` |
| Emerald Coin (market plaza) | `MARKET_STREET` |
| Doji's Children (okiya) | `ENKAI_HALL` |
| Inn of the Last Rite | `GUEST_WING` |
| Light from Above (dining house) | `ENKAI_HALL` |
| Soshiuchi / House of Loss | `LORD_QUARTERS` |
| Origami shop | `MARKET_STREET` |
| Governor's residence | `LORD_QUARTERS` |

**Juramashi — Juramashi District** (Toshisoto) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Craftsman's Quarter | `MARKET_STREET` |
| Bright Wind (geisha house) | `ENKAI_HALL` |
| Natsu-Togumara Shrine | `CASTLE_SHRINE` |
| Juramashi District Meeting Hall | `OHIROMA` |
| Maratu's Origata (gift shop) | `MARKET_STREET` |
| Governor's residence | `LORD_QUARTERS` |

**Ochiyo — Spiritual District** (Toshisoto) — 8 zones

| Landmark | Interior subtype |
|---|---|
| Temple of the Sun Goddess | `TEMPLE_GROUNDS` |
| Temple of Daikoku | `TEMPLE_GROUNDS` |
| Temple of Ebisu | `TEMPLE_GROUNDS` |
| Temple of Benten | `TEMPLE_GROUNDS` |
| Simple Pleasures (okiya) | `ENKAI_HALL` |
| Seppun's Path | `TSUBONIWA` |
| Meditation gardens | `TSUBONIWA` |
| Governor's residence | `LORD_QUARTERS` |

**Hayasu — Gilded Hill District** (Toshisoto) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Shining Square | `MARKET_STREET` |
| Riverside Merchant Plaza | `MARKET_STREET` |
| Cherry Blossom Row | `TSUBONIWA` |
| Chirping Crickets Neighborhood | `RESIDENTIAL_QUARTER` |
| Governor's residence (hilltop) | `LORD_QUARTERS` |
| Farms outside the walls | `FARMLAND` |

**Hojize — Rich Crescent District** (Toshisoto) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Wharves | `DOCKS_WATERFRONT` |
| Clan Guide Houses (inn) | `GUEST_WING` |
| Kinjiren Tombs | `CASTLE_SHRINE` |
| Chiken / Bloodhawk Bridge | `RIVER_CROSSING` |
| Governor's residence | `LORD_QUARTERS` |
| Koku Seal office | `GOVERNMENT_QUARTER` |

**Hinjaku — Eta's Island District** (Toshisoto) — 4 zones

| Landmark | Interior subtype |
|---|---|
| Takusanno Sakanaya (fishery) | `DOCKS_WATERFRONT` |
| Shizukomen (residential) | `POOR_QUARTER` |
| Eta quarter | `POOR_QUARTER` |
| Governor's residence | `LORD_QUARTERS` |

**Toyotomi — Prison/Moon District** (Toshisoto) — 5 zones

| Landmark | Interior subtype |
|---|---|
| Kyuden Kokai (prison) | `GOVERNMENT_QUARTER` |
| Magistrate station | `GOVERNMENT_QUARTER` |
| Jumping Frog (okiya) | `ENKAI_HALL` |
| The Moon (gambling quarter) | `ENKAI_HALL` |
| Governor's residence | `LORD_QUARTERS` |

**Meiyoko — Tenari's Ruin District** (Toshisoto) — 5 zones

| Landmark | Interior subtype |
|---|---|
| Tenari's ruins | `POOR_QUARTER` |
| Hana Garden | `TSUBONIWA` |
| Gokenin quarters | `RESIDENTIAL_QUARTER` |
| Criminal refuge areas | `POOR_QUARTER` |
| Governor's residence | `LORD_QUARTERS` |

**Higshikawa — North Dock District** (Toshisoto) — 5 zones

| Landmark | Interior subtype |
|---|---|
| Morning Star Wharves | `DOCKS_WATERFRONT` |
| Takeo Library | `AUDIENCE_CHAMBER` |
| Imperial Guard kaisha (barracks) | `WAR_COUNCIL_ROOM` |
| Pleasure houses | `ENKAI_HALL` |
| Governor's residence | `LORD_QUARTERS` |

**Kosuga — South Dock District** (Toshisoto) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Primary trade port | `DOCKS_WATERFRONT` |
| Flooded Merchant Bazaar | `MARKET_STREET` |
| Daikoku Arch | `CASTLE_SHRINE` |
| Yatoshin warehouse district | `DOCKS_WATERFRONT` |
| Governor's residence | `LORD_QUARTERS` |
| Koku Seal inspection point | `GOVERNMENT_QUARTER` |

**Kanjo — Kanjo District** (Ekohikei) — 7 zones

| Landmark | Interior subtype |
|---|---|
| Lion Embassy (south) | `AUDIENCE_CHAMBER` |
| Phoenix Embassy | `AUDIENCE_CHAMBER` |
| Scorpion Embassy | `AUDIENCE_CHAMBER` |
| Sorrow's Fall | `TSUBONIWA` |
| Sentaku Tribunal Hall | `OHIROMA` |
| Imperial Treasury | `GOVERNMENT_QUARTER` |
| Governor's residence | `LORD_QUARTERS` |

**Chisei — Chisei District** (Ekohikei) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Seppun Hill | `TEMPLE_GROUNDS` |
| Crane Embassy (Storyhouse) | `AUDIENCE_CHAMBER` |
| Phoenix secondary embassy | `AUDIENCE_CHAMBER` |
| Minor Clan embassy row | `AUDIENCE_CHAMBER` |
| Art galleries & performance halls | `ENKAI_HALL` |
| Governor's residence | `LORD_QUARTERS` |

**Karada — Karada District** (Ekohikei) — 5 zones

| Landmark | Interior subtype |
|---|---|
| Crab Embassy | `AUDIENCE_CHAMBER` |
| Oni Warai (the Oni's Smile) | `MOUNTAIN_PASS` |
| Yasuki Trading Grounds | `MARKET_STREET` |
| Lower-caste residential quarters | `POOR_QUARTER` |
| Governor's residence | `LORD_QUARTERS` |

**Hito — Hito District** (Ekohikei) — 6 zones

| Landmark | Interior subtype |
|---|---|
| Lion Embassy (barracks) | `WAR_COUNCIL_ROOM` |
| Unicorn Embassy | `AUDIENCE_CHAMBER` |
| Fox Embassy | `AUDIENCE_CHAMBER` |
| Road of Fast Hopes | `ROAD` |
| Samurai residential compounds | `RESIDENTIAL_QUARTER` |
| Governor's residence | `LORD_QUARTERS` |

**Forbidden City — Forbidden City** (Forbidden City) — 26 zones

| Landmark | Interior subtype |
|---|---|
| Imperial Palace — Throne Room | `OHIROMA` |
| Imperial Palace — Imperial Court Chambers | `AUDIENCE_CHAMBER` |
| Imperial Palace — Banquet Hall | `ENKAI_HALL` |
| Imperial Palace — Tea Pavilion | `CHASHITSU` |
| Imperial Palace — Guest Wing | `GUEST_WING` |
| Imperial Palace — Emperor's Private Chambers | `LORD_QUARTERS` |
| Imperial Palace — War Council Room | `WAR_COUNCIL_ROOM` |
| Imperial Palace — Dojo | `DOJO` |
| Imperial Palace — Outer Courtyard | `OUTER_COURTYARD` |
| Imperial Palace — Inner Garden | `TSUBONIWA` |
| Imperial Palace — Palace Shrine | `CASTLE_SHRINE` |
| Otomo Palace | `LORD_QUARTERS` |
| Seppun Palace | `LORD_QUARTERS` |
| Miya Palace | `LORD_QUARTERS` |
| Guest Home — Crab Clan | `GUEST_WING` |
| Guest Home — Crane Clan | `GUEST_WING` |
| Guest Home — Dragon Clan | `GUEST_WING` |
| Guest Home — Lion Clan | `GUEST_WING` |
| Guest Home — Phoenix Clan | `GUEST_WING` |
| Guest Home — Scorpion Clan | `GUEST_WING` |
| Guest Home — Unicorn Clan | `GUEST_WING` |
| Shrine of the First Hantei | `CASTLE_SHRINE` |
| Imperial Gardens | `TSUBONIWA` |
| Seppun Guard barracks | `WAR_COUNCIL_ROOM` |
| Emperor's Chosen quarters | `LORD_QUARTERS` |
| Emperor's Labyrinth (tunnels) | `MOUNTAIN_PASS` |

