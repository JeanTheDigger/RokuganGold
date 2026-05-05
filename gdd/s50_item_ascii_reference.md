# 50. Item ASCII Reference

This section documents the ASCII visual representations for every craftable and giftable item type in the game. Each entry shows the item's Normal quality rendering and, where meaningfully different, its Exceptional/Masterwork rendering. Hotspot markers are indicated by [1], [2], etc., corresponding to interactive components in Inspection Mode. Actual in-game ASCII is procedurally generated at item creation — these entries serve as the canonical design reference and template for the generation system.

All ASCII is rendered in monospace font. Width is constrained to approximately 40 characters. Quality tier affects visual density and decoration — Normal items use simpler line work, Exceptional items add detail, Masterwork adds elaborate ornamentation, Legendary items are visually unmistakable.

**WEAPONS**

**Katana**

Hotspots: [1] Blade [2] Tsuba (guard) [3] Hilt [4] Hilt wrap [5] Scabbard

Normal quality:

[5] [2][3][4]

|==========O--[###]>

|__________O

Exceptional quality:

[5] [2] [3][4]

|=========<*>==[###]>

|_________<*>

[1]

**Wakizashi**

Hotspots: [1] Blade [2] Tsuba [3] Hilt [4] Scabbard

Normal quality:

[4] [2][3]

|======O-[##]>

|______O

Exceptional quality:

[4] [2][3]

|=====<*>=[##]>

|_____<*>

[1]

**Tanto**

Hotspots: [1] Blade [2] Guard [3] Hilt

Normal quality:

[2][3]

O-[#]>

|=====>

[1]

Exceptional quality:

[2][3]

<*>=[#]>

|=====>>

[1]

**Naginata**

Hotspots: [1] Blade [2] Blade collar [3] Shaft [4] Butt cap

Normal quality:

[1]

/====>

[4]--[3]--[2]

|=========|

Exceptional quality:

[1]

//====>>

[4]==[3]===[2]

|==========|

**Yumi (Longbow)**

Hotspots: [1] Upper limb [2] Grip [3] Lower limb [4] String

Normal quality:

[1] [4]

( | |

( | [2]

( | |

[3] |

\___/

Exceptional quality:

[1] [4]

(( | |

(( | [2]

(( | |

[3] |

\____/

**Tetsubo (War Club)**

Hotspots: [1] Head [2] Studs [3] Shaft [4] Grip

Normal quality:

[1][2]

|####|

|####|

[3] |

| |

[4]--+

Exceptional quality:

[1][2]

|######|

|*#*#*#|

[3] |

| |

[4]====+

**War Fan (Tessen)**

Hotspots: [1] Fan face [2] Ribs [3] Guard [4] Handle

Normal quality:

[1]

/|||\

/ ||| \

/ [2] \

[3]

[4]

|

Exceptional quality:

[1]

/|*|\

/ |*| \

/ [2] \

<[3]>

[4]

||

**Yari (Spear)**

Hotspots: [1] Tip [2] Collar [3] Shaft [4] Butt

Normal quality:

[1]

/\

/ \

[2] |

|[3]|

| |

[4] |

Exceptional quality:

[1]

//\\

// \\

[2] |

||[3]|

|| |

[4]===|

**ARMOR**

**Ashigaru Armor**

Hotspots: [1] Chest plate [2] Shoulder guards [3] Helmet [4] Arm guards

Normal quality:

[3]

[___]

[2] [2]

|[1] |

|___|

[4] [4]

Exceptional quality:

[3]

[===]

<<[2] [2]>>

||[1]||

|___|

[4]=[4]

**Light Armor (Do-maru)**

Hotspots: [1] Cuirass [2] Shoulder guards [3] Helmet [4] Skirt plates [5] Arm guards

Normal quality:

[3]

/___\

[2] [2]

| [1] |

| === |

[4] [4]

[5] [5]

Exceptional quality:

[3]

/*___*\

[2] [2]

|| [1] ||

|| ===* ||

[4] [4]

[5]=====[5]

**Heavy Armor (O-Yoroi)**

Hotspots: [1] Cuirass [2] Great shoulder guards (O-sode) [3] Kabuto helmet [4] Skirt [5] Kote (arm guards) [6] Suneate (shin guards)

Normal quality:

[3]

[=====]

[2] [2]

| [===] |

| [ 1 ] |

|_[===]_|

[4] [4]

[5] [5]

[6] [6]

Exceptional quality:

[3]

[*=====*]

[2] [2]

|| [=*=] ||

|| [ 1 ] ||

||_ [=*=] _ ||

[4] [4]

[5] [5]

[6]=====[ 6]

**ARTISAN ITEMS**

**Painting (Kakemono/Scroll Painting)**

Hotspots: [1] Painted surface [2] Mounting silk [3] Upper roller [4] Lower roller [5] Hanging cord

Normal quality:

[5]

[3]_______________

|[2] [1] [2] |

| ... | |

| . . | |

| ... | |

|_______________|

[4]

Exceptional quality:

[5]

=[3]=================

|[2]* [1] *[2]|

| .~~~. |

| ( o_o ) |

| .~~~. |

|*_____________*|

=[4]=================

**Sculpture**

Hotspots: [1] Main figure [2] Base [3] Inscription

Normal quality:

[1]

/ \

| ( ) |

| |

[2]___[2]

|[3] |

|_____|

Exceptional quality:

[1]

/~~~\

| (*) |

| |

_[2]___[2]_

| [3] |

|___________|

**Bonsai**

Hotspots: [1] Canopy [2] Trunk [3] Pot [4] Soil surface

Normal quality:

[1]

( )

( *** )

( * )

[2]

|

[4]___[4]

|[3] |

|_____|

Exceptional quality:

[1]

( * )

(* *** *)

(* * *)

[2]

/ | \

[4]___[4]

|[3] |

|=====|

**Ikebana (Flower Arrangement)**

Hotspots: [1] Tall stem [2] Secondary stems [3] Flowers [4] Vessel

Normal quality:

[1]

| [3]

| /

[2]-+ [3]

\| /

| /

[4]

[====]

[____]

Exceptional quality:

[1]

| [3]

| *

[2]-+-- [3]

\| *

| *

[4]

[*====*]

[______]

**Origami (Crane)**

Hotspots: [1] Wings [2] Body [3] Head [4] Tail

Normal quality:

[1] [3]

/\ /\

/ X \

/ [2] \

\ /

\ [4] /

\ /

\_/

Exceptional quality:

[1] [3]

/\/\

/* *\

/ [2] \

\ /

\ [4] /

\ /

\_/

**Poetry Scroll**

Hotspots: [1] Paper surface [2] Upper rod [3] Lower rod [4] Ribbon seal [5] Text columns

Normal quality:

[2]___________

/ [1] [5] \

| | | | | |

| | | | | |

| |_|_|_| |

\__[4]_________/

[3]

Exceptional quality:

[2]=============

/ [1] [5] \

| |*| |*| |

| |*| |*| |

| |_|_|_| |

\==[4]===========/ =

[3]

**Tattoo Design (rendered on parchment)**

Hotspots: [1] Central motif [2] Border pattern [3] Signature mark

Normal quality:

[2]___________[2]

| |

| [1] |

| / \ |

| ( *** ) |

| \ / [3] |

|_____________|

Exceptional quality:

[2]===========[2]

|| * * ||

|| [1] ||

|| /~~~~~\ ||

||( *** ) ||

|| \~~~~~/ [3]||

||___________||

**Bonkei (Tray Landscape)**

Hotspots: [1] Stones [2] Plantings [3] Sand pattern [4] Tray

Normal quality:

[4]_______________

|[1]  [3]   [2] |

| /\  ...    *  |

| \/  ...    *  |

|_______________|

Exceptional quality:

[4]===============

|[1]  [3]  [2]  |

|/~~\ ~~~  ***  |

|\__/ ~~~  * *  |

|===============|

**CRAFT ****&**** GIFT ITEMS**

**Tea Set**

Hotspots: [1] Teapot body [2] Teapot lid [3] Spout [4] Handle [5] Cups [6] Tray

Normal quality:

[2]

[___]

[3]>[1]<[4] [5] [5]

| | U U

[6]_________________________

|_________________________|

Exceptional quality:

[2]

[*=*]

[3]>[1]<[4] [5] [5]

|~~~| U* *U

[6]_________________________

|*_______________________*|

**Pottery / Vase**

Hotspots: [1] Body [2] Neck [3] Rim [4] Base [5] Glaze pattern

Normal quality:

[3]

[___]

[2]

/ \

| [1] |

| [5] |

\_____/

[4]

Exceptional quality:

[3]

[*=*]

[2]

/* *\

| [1] |

| ~[5]~ |

\*___*/

[4]

**Kimono**

Hotspots: [1] Main fabric [2] Collar [3] Sleeves [4] Obi (sash) [5] Hem pattern

Normal quality:

[2]

/ \

[3] [3]

\[1] /

|[4]|

|===|

|[5]|

|___|

Exceptional quality:

[2]

/* *\

[3] [3]

\[1]**/

|[4]|

|===|

|[5]|

|_*_|

**Ring**

Hotspots: [1] Band [2] Setting [3] Gem

Normal quality:

[2]

[___]

/ [3] \

| [ ] |

\_[1]_/

Exceptional quality:

[2]

[*=*]

/ [3] \

| [*] |

\=[1]=/ =

**Mask**

Hotspots: [1] Face surface [2] Eye openings [3] Mouth [4] Cord loops [5] Painted detail

Normal quality:

[4] [4]

/[_____]\

| [2] [2] |

| [1] |

| [3] |

\_______/

Exceptional quality:

[4] [4]

/[*===*]\

| [2] [2] |

| *[1]* |

| [5][3] |

\*______*/

**Scroll Case**

Hotspots: [1] Cylinder body [2] End cap [3] Carrying cord [4] Clan seal

Normal quality:

[3]

|

[2]

|=|

|[1]|

| = |

|[4]|

|___|

[2]

Exceptional quality:

[3]

|

[2]

|=|

|[1]|

|*=*|

|[4]|

|===|

[2]

**Kemari Ball**

Hotspots: [1] Outer cloth [2] Stitching [3] Stone core (visible through wear)

Normal quality:

___

/[1]\

| [2] |

| + |

\___/

Exceptional quality:

___

/*[1]*\

| [2] |

| *+* |

\*___*/

Note: All ASCII representations above are design templates. The procedural generation system uses these as base templates, varying details based on specific material inputs, quality tier, and randomized aesthetic choices within clan-appropriate visual vocabularies. A Crane-clan painting will have more refined brushwork characters than a Crab-clan painting of identical quality. A Scorpion mask will use darker ASCII symbol choices than a Phoenix mask. Clan visual vocabulary is a separate design document to be produced when the generation system is implemented.

