"""L5R 4e Heritage Tables: random character background rolls.

Real L5R 4e heritage uses a two-stage d10 system: first roll determines
a category (Shameful Past, Illustrious Past, or Mixed Blessings), then
a second d10 determines the specific result within that category.

Verified tables use the two-stage dict format.  Unverified tables (not yet
checked against source material) use a legacy single-stage list format
and are marked accordingly.
"""

from __future__ import annotations

import random
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from l5r_rules.character import Character


def _roll_range_str(rolls: list[int]) -> str:
    """Format a list of ints as a die-range string: [2,3] -> '2-3'."""
    if len(rolls) == 1:
        return str(rolls[0])
    return f"{rolls[0]}-{rolls[-1]}"


def _find_entry(subtable: list[dict], roll: int) -> dict:
    """Find the entry in a subtable whose rolls list contains *roll*."""
    for entry in subtable:
        if roll in entry["rolls"]:
            return entry
    return subtable[0]


# ---- Verified two-stage tables (real L5R 4e data) -------------------------

_CRAB_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2, 3], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [4, 5, 6, 7], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [8, 9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor summoned a powerful kami during a time of need. Your ancestor made promises to the kami in return for its help, but never followed through. You gain the Disadvantage Wrath of the Kami.",
            "grants": {"disadvantages": ["Wrath of the Kami"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was a merchant patron who thought he was getting the better end of a deal, only to discover he'd had the wool pulled over his eyes. Your family has been impoverished ever since. Start with three less koku in your Outfit.",
            "grants": {"koku": -3},
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor fell to the Shadowlands and returned to fight his former clan as one of the Lost. His failure haunts your line to this day. You start with 0.1 Taint and your starting Honor is 1.0 lower.",
            "grants": {"taint": 0.1, "honor": -1.0},
        },
        {
            "rolls": [6, 7],
            "effect": "A creature from the Shadowlands cursed your line with its dying breath. You start play with the Disadvantage Bad Fortune: Lingering Misfortune.",
            "grants": {"disadvantages": ["Bad Fortune (Lingering Misfortune)"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor abandoned a comrade to die in the Shadowlands. The other man's family swore a blood feud against yours. You gain the Sworn Enemy Disadvantage.",
            "grants": {"disadvantages": ["Sworn Enemy"]},
            "notes": ["Fortune determines which family holds the blood feud."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor was seduced by the Shadowlands and in the generations since has taken several of his descendants to join him there. You are next on the list.",
            "grants": {},
            "notes": ["Fortune determines the nature and timing of this ancestral threat."],
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "A particular kami took an interest in your family line, and it senses a similarity to your ancestor in you. You may take the Friendly Kami Advantage (if you are a shugenja) or the Friend of the Elements Advantage for one less Experience Point.",
            "grants": {},
            "notes": ["May take Friendly Kami (shugenja) or Friend of the Elements for 1 less XP."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor made many political connections with another clan which have lasted to this day. You gain a 3-point Ally Advantage in that clan for free.",
            "grants": {"advantages": ["Ally (3 points, another clan)"]},
            "notes": ["Fortune determines which clan the Ally belongs to."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor single-handedly turned back an enemy sally during a siege. His deeds still bring fame to your family today. Gain 1.0 Glory.",
            "grants": {"glory": 1.0},
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor died a hero's death fighting the Shadowlands. His legacy of heroism inspires you today. Gain 1 free Rank in a Weapon Skill of your choice.",
            "grants": {},
            "notes": ["Gain 1 free Rank in a Weapon Skill of your choice."],
        },
        {
            "rolls": [8, 9],
            "effect": "A visiting dignitary got caught in a Shadowlands attack while touring the Wall. Your ancestor saved his life and in thanks was granted an additional stipend. Your starting Outfit gains 2 koku.",
            "grants": {"koku": 2},
        },
        {
            "rolls": [10],
            "effect": "During a fierce battle with another clan, your ancestor saved the life of one of his enemies. Their descendants remain indebted to your line. You gain a free 3-point Obligation with their clan.",
            "grants": {"disadvantages": ["Obligation (3 points, another clan)"]},
            "notes": ["Fortune determines which clan holds the Obligation."],
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "Your family is known for something disreputable, not necessarily undeserved. You gain the Infamous Disadvantage. However, you have learned from your family's illicit activities and gain one free Rank in a Low Skill.",
            "grants": {"disadvantages": ["Infamous"]},
            "notes": ["Gain 1 free Rank in a Low Skill of your choice."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor discovered something very interesting, and very taboo. You may take the Forbidden Knowledge Advantage for one less Experience Point.",
            "grants": {},
            "notes": ["May take Forbidden Knowledge for 1 less XP."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your family has always had good relations with the Nezumi. You gain a free 2-point Ally who is a Nezumi.",
            "grants": {"advantages": ["Ally (2 points, Nezumi)"]},
        },
        {
            "rolls": [6, 7],
            "effect": "Due to various mishaps and misfortunes, you are the last of your line, and have all your family's titles and responsibilities resting squarely on your shoulders. You gain 0.5 Status but you are also under a 3-point Obligation to the Crab to keep your family line alive.",
            "grants": {"status": 0.5, "disadvantages": ["Obligation (3 points, Crab Clan)"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor participated in a battle with another clan, where he unexpectedly distinguished himself in a duel. However, the descendants of the samurai he defeated would like a rematch. You gain 1.0 Glory but you also have a Sworn Enemy in another clan's family.",
            "grants": {"glory": 1.0, "disadvantages": ["Sworn Enemy (another clan)"]},
            "notes": ["Fortune determines which clan's family holds the grudge."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor was a Kaiu craftsman of singular skills. One of his creations was passed on to you. Unfortunately he was afflicted with too much Fire and sometimes didn't seem himself. You gain the Sacred Weapon: Kaiu Blade Advantage for free, but the blade is afflicted with some manner of curse known only to your Fortune.",
            "grants": {"advantages": ["Sacred Weapon (Kaiu Blade)"]},
            "notes": ["The blade is afflicted with a curse determined by the Fortune."],
        },
    ],
}


# ---- Unverified legacy tables (fabricated, pending source material) --------
# These use a single-stage d10 format and DO NOT match real L5R 4e.
# They will be replaced as each clan's real data is provided.

_CRANE_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2, 3], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [4, 5, 6, 7, 8], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor was in charge when a clan treasure vanished. He committed seppuku and your family has worked to rebuild its reputation ever since. You gain the Driven Disadvantage.",
            "grants": {"disadvantages": ["Driven"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was mildly obsessed with her looks, and people say you act just like her. You gain a 2-point Compulsion: Always Look Your Best.",
            "grants": {"disadvantages": ["Compulsion (Always Look Your Best, 2 points)"]},
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor was a clan magistrate but was rumored to sell justice to the highest bidder. His flaw has been passed down through the bloodline to you. You gain the Greedy Disadvantage.",
            "grants": {"disadvantages": ["Greedy"]},
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor was a soldier who deserted rather than face the enemies of the Crane. His deeds still stain your family's reputation. You start with 0.5 less Status and 0.5 less Glory than normal.",
            "grants": {"status": -0.5, "glory": -0.5},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor lost an important duel and his failure still hangs over your line. You start with 1.0 less Honor and 0.5 less Status than normal.",
            "grants": {"honor": -1.0, "status": -0.5},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor claimed a rival's art as his own, winning praise from the Imperial Court. If the deceit is ever discovered, your family will be ruined. You gain the Dark Secret Disadvantage.",
            "grants": {"disadvantages": ["Dark Secret"]},
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "Your ancestor created a work of art that is still admired to this day. You gain 1 free Rank in the appropriate Artisan skill and 0.5 Glory.",
            "grants": {"glory": 0.5},
            "notes": ["Gain 1 free Rank in an Artisan skill (Fortune determines which)."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your family has ties of marriage or alliance with another clan. You may take the Different School Advantage for 2 less Experience Points.",
            "grants": {},
            "notes": ["May take the Different School Advantage for 2 less XP."],
        },
        {
            "rolls": [4, 5, 6],
            "effect": "Your ancestor served the clan as a clerk in the Imperial bureaucracy. You may take the Precise Memory Advantage for 2 less points.",
            "grants": {},
            "notes": ["May take the Precise Memory Advantage for 2 less XP."],
        },
        {
            "rolls": [7],
            "effect": "Your ancestor fought in one of the famous battles of his time, and his courageous deeds are still celebrated in the Crane Clan. You gain 0.5 Glory and a free Rank in either Battle or a Weapon Skill of your choice.",
            "grants": {"glory": 0.5},
            "notes": ["Gain 1 free Rank in either Battle or a Weapon Skill of your choice."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor nearly single-handedly averted a political catastrophe and turned it into a victory for the Crane. His brilliance is reflected in your own skills. You may take the Clear Thinker Advantage for 1 less Experience Point.",
            "grants": {},
            "notes": ["May take the Clear Thinker Advantage for 1 less XP."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor saved an Asahina Fetish Master from a serious social mishap. In thanks she gave your family a fetish which has since been passed down to you.",
            "grants": {},
            "notes": ["Fortune determines which Asahina fetish was passed down."],
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "At your gempukku you were given an item. It seemed commonplace, but you were told you were to be its keeper and only use it in a time of great need. You were also told no one was sure what it did.",
            "grants": {},
            "notes": ["Fortune determines the nature of this mysterious item and its power."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor slew a major enemy of the Crane in a duel. His descendants remember this as well. You gain 0.5 Glory but also gain a Sworn Enemy in another clan.",
            "grants": {"glory": 0.5, "disadvantages": ["Sworn Enemy (another clan)"]},
            "notes": ["Fortune determines which clan holds the grudge."],
        },
        {
            "rolls": [4, 5, 6],
            "effect": "Your ancestor ignored his duty to the Crane and followed a personal quest to a different school in another clan. He made allies for your family but his obsessive nature has been passed down to you. You may take the Different School Advantage for two less points, but you have the Driven Disadvantage.",
            "grants": {"disadvantages": ["Driven"]},
            "notes": ["May take the Different School Advantage for 2 less XP."],
        },
        {
            "rolls": [7],
            "effect": "Your ancestor was a magistrate who revealed another family's dishonor. You have inherited his uncompromising and perceptive nature. You gain a free Rank in Investigation and the Contrary Disadvantage.",
            "grants": {"skills": {"Investigation": 1}, "disadvantages": ["Contrary"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was a highly successful merchant patron who cared little about scruples or propriety. You are a true heir to his traditions. You gain an additional 3 koku in your starting Outfit, but gain the Insensitive Disadvantage.",
            "grants": {"koku": 3, "disadvantages": ["Insensitive"]},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor was an artist of high renown and you're expected to follow in his footsteps, perhaps even to surpass him. You may take the Soul of Artistry Advantage for 2 less points, but you gain the Disadvantage Consumed by Perfection.",
            "grants": {"disadvantages": ["Consumed by Perfection"]},
            "notes": ["May take the Soul of Artistry Advantage for 2 less XP."],
        },
    ],
}

_DRAGON_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [3, 4, 5], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [6, 7, 8, 9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor gave away vital information about Dragon troop movements. His foolishness still haunts your family's reputation. You gain the Infamous Disadvantage.",
            "grants": {"disadvantages": ["Infamous"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was the victim of an elaborate confidence scheme which ended with his seppuku. Unfortunately, you share his weaknesses and your family's status has never recovered from his failure. You gain the Gullible Disadvantage and lose 0.5 Status.",
            "grants": {"disadvantages": ["Gullible"], "status": -0.5},
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor lacked the courage to face the enemies of the Dragon, fleeing from battle. It is up to you to rebuild your family's reputation. You start with 0.0 Glory and it will take you twice as long (20 Glory Points) to reach Glory Rank 1.",
            "grants": {},
            "notes": ["Starting Glory is set to 0.0 regardless of school. Reaching Glory Rank 1 requires 20 Glory Points (double normal)."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your mother became pregnant with you after swearing an oath of celibacy to her daimyo. She committed seppuku after giving birth. You start with the Black Sheep Disadvantage.",
            "grants": {"disadvantages": ["Black Sheep"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor successfully pursued a love match within another clan, disrupting others' marriage plans and earning their eternal hatred. You gain a Nemesis within that clan.",
            "grants": {"disadvantages": ["Nemesis (another clan)"]},
            "notes": ["Fortune determines which clan holds the grudge."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor lost focus during an alchemy experiment, causing it to fail horribly. Ever since then your family has been cursed with Epilepsy, and you are no exception.",
            "grants": {"disadvantages": ["Epilepsy"]},
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "Your ancestor was significantly involved in a famous major battle of his time. Gain a free 2-point Ally from another clan of your choice and 1 rank in the Lore Skill for that clan.",
            "grants": {"advantages": ["Ally (2 points, another clan)"]},
            "notes": ["Choose another clan: Gain a 2-point Ally and 1 Rank in that clan's Lore Skill."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor performed admirably while occupying a high-profile position in the Dragon Clan. You gain 1 free Rank in a High Skill of your choice.",
            "grants": {},
            "notes": ["Gain 1 free Rank in a High Skill of your choice."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor had a romantic affair during winter court that was the inspiration for many pillow books. Some of that past glory reflects on you. You gain 0.5 Glory and may take the Advantage Seven Fortunes Blessing: Benten's Blessing for 1 less Experience Point.",
            "grants": {"glory": 0.5},
            "notes": ["May take Seven Fortunes Blessing: Benten's Blessing for 1 less XP."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor played an instrumental role in a small battle. You gain 1 free Rank in a Bugei Skill of your choice.",
            "grants": {},
            "notes": ["Gain 1 free Rank in a Bugei Skill of your choice."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor died while carrying the clan banner in battle. His superiors found him still holding it upright the next morning. Your family still reveres his name and his glory redounds to your benefit. You gain 1.0 Glory and 0.5 Honor.",
            "grants": {"glory": 1.0, "honor": 0.5},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor was a tattooed man famous for his unusual nature, including the fact that he married and had children. You gain 1 free Rank in any one Skill which is not a School Skill for you.",
            "grants": {},
            "notes": ["Gain 1 free Rank in any one Skill which is not a School Skill for you."],
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "One of your parents was of the Tattooed Order and you were given a tattoo shortly before your gempukku. Unfortunately, your mind was not fully prepared for such power. You gain a Togashi tattoo of the Fortune's choice, but you also gain the Enlightened Madness Disadvantage connected to the tattoo.",
            "grants": {"disadvantages": ["Enlightened Madness"]},
            "notes": ["Gain a Togashi tattoo (Fortune determines which). The Enlightened Madness is connected to the tattoo."],
        },
        {
            "rolls": [2, 3],
            "effect": "One of your ancestors picked up an item from a battlefield on a whim. It has since been passed down to you. Although no one is quite sure what it does, family legend speaks of a spirit that makes its home within...",
            "grants": {},
            "notes": ["Fortune determines the nature of this ancestral battlefield item and the spirit within it."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor escalated a minor matter of honor into a duel to the death with a samurai from another clan. He won the duel, fortunately, but it was his temper which brought it on in the first place. You have inherited his nature and legacy. You gain 1.0 Glory and 1 free Rank in the Lore Skill for the clan of the duelist he defeated, but you also gain the Brash Disadvantage.",
            "grants": {"glory": 1.0, "disadvantages": ["Brash"]},
            "notes": ["Gain 1 free Rank in the Lore Skill for the defeated duelist's clan (Fortune determines which)."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your family has never been wealthy, but your ascetic lifestyle has helped you on the path to enlightenment. You gain 1 free Rank in the Meditation Skill, but you also have the Ascetic Disadvantage.",
            "grants": {"skills": {"Meditation": 1}, "disadvantages": ["Ascetic"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was a very creative soul, but saw into the Elements too deeply. You gain a +1k0 bonus to all Craft rolls, but you also gain the Frail Mind Disadvantage.",
            "grants": {"advantages": ["+1k0 to all Craft rolls"], "disadvantages": ["Frail Mind"]},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor followed one of the False Paths. You may take the Sage Advantage for 1 less Experience Point, but you also gain the Disbeliever Disadvantage.",
            "grants": {"disadvantages": ["Disbeliever"]},
            "notes": ["May take the Sage Advantage for 1 less XP."],
        },
    ],
}

_LION_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [3, 4, 5, 6, 7], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [8, 9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor was a Deathseeker who never redeemed his name. Your family still labors under his failure. You start with 2.0 less Honor.",
            "grants": {"honor": -2.0},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor had a vice, and someone else found out about it. You have the Blackmailed Disadvantage.",
            "grants": {"disadvantages": ["Blackmailed"]},
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor lacked the courage to stand on the front lines of battle. He ran, leading to a defeat that cost many lives. Your family lives under the shadow of his failure. You start with 0.0 Glory and gain the Disadvantage Phobia: Combat (1 point).",
            "grants": {"disadvantages": ["Phobia: Combat (1 point)"]},
            "notes": ["Starting Glory is set to 0.0 regardless of school."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor made an enemy in a family from another clan, and they've never forgotten it. You gain a Sworn Enemy from that clan.",
            "grants": {"disadvantages": ["Sworn Enemy (another clan)"]},
            "notes": ["Fortune determines which clan holds the grudge."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor served in an army destined for inglorious defeat. The Lion tend not to talk about this particular battle, but they do give you funny looks. You lose 0.5 Glory and gain the Disadvantage Driven: Prove Self.",
            "grants": {"glory": -0.5, "disadvantages": ["Driven (Prove Self)"]},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor found true love in the arms of a Crane. They were forbidden to see each other again, and being a dutiful Lion your ancestor obeyed, but you have inherited his passionate nature. You gain either the True Love or Lost Love Disadvantage (your choice).",
            "grants": {},
            "notes": ["Choose either the True Love or Lost Love Disadvantage."],
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "The blood of your ancestors runs strong in your veins. You may take a Lion Ancestor for 2 less points.",
            "grants": {},
            "notes": ["May take a Lion Ancestor Advantage for 2 less XP."],
        },
        {
            "rolls": [2, 3],
            "effect": "You can trace your line directly back to your family's founder. Honors and gifts from those early years have been passed down to you. You may take the Lion Sacred Weapon Advantage for 2 less points.",
            "grants": {},
            "notes": ["May take the Sacred Weapon (Lion) Advantage for 2 less XP."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor served honorably and memorably in the Imperial Legions. You gain 0.5 Honor and 0.5 Status.",
            "grants": {"honor": 0.5, "status": 0.5},
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor died a hero's death while fighting in one of the major battles of his time. His skills are reborn in you. You gain 1 free Rank in a Weapon Skill of your choice.",
            "grants": {},
            "notes": ["Gain 1 free Rank in a Weapon Skill of your choice."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor rose to be a Rikugunshokan, commanding one of the four Lion armies in a great battle of his age. He led well, and his legacy is in your blood. You may take the Advantage Leadership for 2 less Experience Points.",
            "grants": {},
            "notes": ["May take the Leadership Advantage for 2 less XP."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor died defending the Emperor from an assassination attempt. The Emperor proclaimed his line, of which you are the scion, to be Sacrosanct.",
            "grants": {"advantages": ["Sacrosanct"]},
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "Your ancestor was a Kitsu who met a spirit creature he shouldn't have. You still labor under the effects of that long-ago encounter. You gain the Cursed by the Realm Disadvantage but may take the Inner Gift Advantage for 2 less Experience Points.",
            "grants": {"disadvantages": ["Cursed by the Realm"]},
            "notes": ["May take the Inner Gift Advantage for 2 less XP."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was a famous Ikoma Bard and you possess a great many of her traits. You may take the Sensation Advantage for 1 less point, but you love the adulation of the audience, and gain the Disadvantage Compulsion: Perform (2 points) as well.",
            "grants": {"disadvantages": ["Compulsion: Perform (2 points)"]},
            "notes": ["May take the Sensation Advantage for 1 less XP."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your gempukku took place on the battlefield where your ancestor died. He guides your steps, walking beside you ever since. You gain the Haunted Disadvantage but also gain 1 free Rank in a Bugei Skill of your choice.",
            "grants": {"disadvantages": ["Haunted"]},
            "notes": ["Gain 1 free Rank in a Bugei Skill of your choice."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor took part in a battle that was a defeat for the Lion, but which is now used to teach students at the War College. You lose 1.0 Glory but gain 0.5 Honor.",
            "grants": {"glory": -1.0, "honor": 0.5},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was one of the Ikoma Lion's Shadow. His subtle and pragmatic ways have passed down to you. You start with 1.5 less Honor, but you may take either the Crafty or the Silent Advantage for 2 less Experience Points.",
            "grants": {"honor": -1.5},
            "notes": ["May take either the Crafty or the Silent Advantage for 2 less XP."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor took part in a victorious battle, but the Lion histories consider the battle to have been run ineptly. You lose 1.0 Glory but gain 1 free Rank in a Weapon Skill of your choice.",
            "grants": {"glory": -1.0},
            "notes": ["Gain 1 free Rank in a Weapon Skill of your choice."],
        },
    ],
}

_MANTIS_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2, 3, 4], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [5, 6, 7], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [8, 9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor thought he was the one in charge of the scam, he was wrong. His weakness is yours as well. You gain the Can't Lie Disadvantage.",
            "grants": {"disadvantages": ["Can't Lie"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor fought on the losing side in a famous battle. He was convinced the Mantis would win... right up until the end. You gain the Overconfident Disadvantage.",
            "grants": {"disadvantages": ["Overconfident"]},
        },
        {
            "rolls": [4, 5],
            "effect": "Your line is filled with pirates. One ancestor was particularly noted for harassing other clans. You gain a Sworn Enemy in a clan of the Fortune's choice.",
            "grants": {"disadvantages": ["Sworn Enemy (another clan)"]},
            "notes": ["Fortune determines which clan holds the grudge."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor fought and died in a war far from Rokugan's shores. No one in Rokugan has ever heard of it, nor would they want to. Lose 1.0 Glory.",
            "grants": {"glory": -1.0},
        },
        {
            "rolls": [8, 9],
            "effect": "Your family was on the losing side of a commercial dispute and has never recovered. You gain the Disadvantage Seven Fortune's Curse: Daikoku.",
            "grants": {"disadvantages": ["Seven Fortune's Curse (Daikoku)"]},
        },
        {
            "rolls": [10],
            "effect": "One of your ancestors committed seppuku to atone for the Gusai family's treachery. You gain Social Disadvantage: Gusai Ancestor.",
            "grants": {"disadvantages": ["Social Disadvantage (Gusai Ancestor)"]},
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "Your ancestor was a merchant patron of some renown within the Empire. You start with 2 extra koku in your Outfit.",
            "grants": {"koku": 2},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor proved himself during one of the great battles of his time, and his derring-do is still remembered today. His blood runs true in your veins. You may purchase the Daredevil Advantage for 1 less Experience Point.",
            "grants": {},
            "notes": ["May take the Daredevil Advantage for 1 less XP."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor was a legendary sailor and explorer. You gain 1 free Rank in either the Sailing Skill or the Navigation Skill.",
            "grants": {},
            "notes": ["Gain 1 free Rank in either Sailing or Navigation (your choice)."],
        },
        {
            "rolls": [6, 7],
            "effect": "You can trace your family line back to Kaimetsu-Uo himself. You may take the Blood of Osano-Wo Advantage for 1 less point.",
            "grants": {},
            "notes": ["May take the Blood of Osano-Wo Advantage for 1 less XP."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was a mercenary in the early days of the Mantis Clan. He made contacts across the Empire, but became especially good friends while serving in the army of one particular clan. You gain a free 3-point Ally in another clan of your choice.",
            "grants": {"advantages": ["Ally (3 points, another clan)"]},
            "notes": ["Choose which clan the Ally belongs to."],
        },
        {
            "rolls": [10],
            "effect": "Your ancestor won the blessing of the Thunder Dragon during a great storm. You may take a Rank of the Magic Resistance Advantage for 1 less Experience Point.",
            "grants": {},
            "notes": ["May take a Rank of Magic Resistance for 1 less XP."],
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "You are one of the secret descendants of the Gusai family. You gain Dark Secret: Gusai Family but also gain 1.0 Status.",
            "grants": {"status": 1.0, "disadvantages": ["Dark Secret (Gusai Family)"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was involved in covert trade with gaijin. You may take the Gaijin Gear Advantage for 1 less Experience Point, but you have an Obligation (3 points) to his foreign trading partner.",
            "grants": {"disadvantages": ["Obligation (3 points, foreign trading partner)"]},
            "notes": ["May take the Gaijin Gear Advantage for 1 less XP."],
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor was an ally of the Cornejo family and learned things which no Rokugani should know. You have the Advantage Forbidden Knowledge: Gaijin Pepper.",
            "grants": {"advantages": ["Forbidden Knowledge (Gaijin Pepper)"]},
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor was a prosperous smuggler, and while this enriched your family it also damaged their repute. You start with 1 additional koku in your Outfit, but lose 0.5 Glory.",
            "grants": {"koku": 1, "glory": -0.5},
        },
        {
            "rolls": [8, 9],
            "effect": "Your family history is filled with scoundrels and misfits. You gain 1.0 Infamy but also gain 1 free Rank in the Skill of Lore: Underworld.",
            "grants": {"skills": {"Lore: Underworld": 1}, "infamy": 1.0},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor married a komouri shapeshifter spirit. You may purchase the Child of Chikushudo Advantage.",
            "grants": {},
            "notes": ["May purchase the Child of Chikushudo Advantage."],
        },
    ],
}

_PHOENIX_TABLE: dict = {
    "categories": [
        {"rolls": [1, 2, 3], "name": "Shameful Past", "table": "shameful"},
        {"rolls": [4, 5, 6, 7], "name": "Illustrious Past", "table": "illustrious"},
        {"rolls": [8, 9, 10], "name": "Mixed Blessings", "table": "mixed"},
    ],
    "shameful": [
        {
            "rolls": [1],
            "effect": "Your ancestor was forced to undergo the Forgotten ritual, and remnants of it remain in your bloodline. You gain the Momoku Disadvantage.",
            "grants": {"disadvantages": ["Momoku"]},
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor lost a book containing the only copy of some vital information. He committed seppuku and your family has been committed to finding the knowledge ever since. You gain the Driven Disadvantage.",
            "grants": {"disadvantages": ["Driven"]},
        },
        {
            "rolls": [4, 5],
            "effect": "Your ancestor was a yojimbo who failed to protect his charge in battle. The shame of his actions has not yet been purged. You gain 1.0 Infamy.",
            "grants": {"infamy": 1.0},
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor was an Ishiken who got a little too close to the Void. You gain the Touch of the Void Disadvantage.",
            "grants": {"disadvantages": ["Touch of the Void"]},
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor dabbled in maho. He summoned an oni and gave it his name. Ever since, that oni has been haunting your family line.",
            "grants": {},
            "notes": ["Fortune determines the nature and timing of this oni haunting."],
        },
        {
            "rolls": [10],
            "effect": "While researching powerful new magics, your ancestor disappeared in a flash of light, taking his notes with him. The Kitsu have determined his soul never made it to Meido. No one has been able to duplicate his work or determine where he has gone. Your family is obsessed with hunting for him; you gain the Consumed by Knowledge Disadvantage.",
            "grants": {"disadvantages": ["Consumed by Knowledge"]},
        },
    ],
    "illustrious": [
        {
            "rolls": [1],
            "effect": "You can trace your line directly to your family's founder. You may take a Phoenix Clan Ancestor for 2 less Experience Points.",
            "grants": {},
            "notes": ["May take a Phoenix Clan Ancestor Advantage for 2 less XP."],
        },
        {
            "rolls": [2, 3],
            "effect": "Your ancestor was one of the Elemental Masters and your line is still granted respect for this today. You gain 1.0 Glory and 1.0 Status.",
            "grants": {"glory": 1.0, "status": 1.0},
        },
        {
            "rolls": [4, 5],
            "effect": "This is not your first time around on the kharmic wheel, and you have been lucky enough to be reborn as your own descendant. You may take the Enlightened Advantage for 1 less point.",
            "grants": {},
            "notes": ["May take the Enlightened Advantage for 1 less XP."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor was instrumental in negotiating a peace treaty between two clans. His legacy of virtue and compassion is still carried forward in your line. You gain 1.0 Honor and you may purchase the Advantage Paragon of Compassion for 2 less Experience Points.",
            "grants": {"honor": 1.0},
            "notes": ["May take the Paragon of Compassion Advantage for 2 less XP."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was a yojimbo who fought and won a glorious duel in defense of his charge. His fame endures and you look to his example for guidance. Gain 1 free Rank in the Iaijutsu Skill and 0.5 Glory.",
            "grants": {"skills": {"Iaijutsu": 1}, "glory": 0.5},
        },
        {
            "rolls": [10],
            "effect": "Your ancestor achieved one of the great breakthroughs of magic, and you have benefited from his work. Gain 1 free Rank in either the Lore: Shugenja Skill or the Spellcraft Skill.",
            "grants": {},
            "notes": ["Gain 1 free Rank in either Lore: Shugenja or Spellcraft (your choice)."],
        },
    ],
    "mixed": [
        {
            "rolls": [1],
            "effect": "Your ancestor was a shugenja of some renown with her Element, but was absolutely terrible with the opposing Element. You may take the Friend of the Elements (Element of your choice) Advantage for 1 less Experience Point, but also gain Wrath of the Kami in the opposing Element.",
            "grants": {"disadvantages": ["Wrath of the Kami (opposing Element)"]},
            "notes": ["May take Friend of the Elements (choose Element) for 1 less XP. Wrath of the Kami applies to the opposing Element."],
        },
        {
            "rolls": [2, 3],
            "effect": "A kansen tempted your ancestor into using maho, leaving a stain on your family name. The kansen has since found you. It acts as the Friendly Kami advantage, but the bonuses only apply to casting Maho spells.",
            "grants": {"advantages": ["Friendly Kami (Maho spells only)"]},
        },
        {
            "rolls": [4, 5],
            "effect": "One of your ancestors went missing for several months. No one is sure where he went, but when he returned he had no memories save for a message he claimed was from the Celestial Heavens. You may take the Advantage Chosen by the Oracles for 2 less Experience Points, but you also gain the Disadvantage Lord Moon's Curse.",
            "grants": {"disadvantages": ["Lord Moon's Curse"]},
            "notes": ["May take the Chosen by the Oracles Advantage for 2 less XP."],
        },
        {
            "rolls": [6, 7],
            "effect": "Your ancestor was repeatedly defeated at something, and your family has made a point of being the best at it ever since. Choose a Skill. You gain the Jealousy Disadvantage in that Skill, but you also gain either 2 free Ranks in that Skill or one free Emphasis in that Skill.",
            "grants": {"disadvantages": ["Jealousy (chosen Skill)"]},
            "notes": ["Choose a Skill: Gain either 2 free Ranks or 1 free Emphasis in that Skill. Jealousy applies to the same Skill."],
        },
        {
            "rolls": [8, 9],
            "effect": "Your ancestor was a well-known mediator. In one particularly dangerous situation she took extreme and dishonorable measures to preserve the peace. Her dishonor and success both linger. You start with 1.0 less Honor but also gain a 2-point Ally in another clan.",
            "grants": {"honor": -1.0, "advantages": ["Ally (2 points, another clan)"]},
            "notes": ["Fortune determines which clan the Ally belongs to."],
        },
        {
            "rolls": [10],
            "effect": "Your family has always been one of the guardians of Gisei Toshi. You have access to the sacred knowledge and hidden items within Gisei Toshi should you need them, but you must never tell anyone about the city's location. Gain Dark Secret: Location of Gisei Toshi.",
            "grants": {"disadvantages": ["Dark Secret (Location of Gisei Toshi)"]},
        },
    ],
}

_LEGACY_SCORPION: list[dict] = [
    {"roll": 1, "name": "Master Spy", "effect": "Ancestor was a legendary spy. +1 rank in Stealth (free).", "grants": {"skills": {"Stealth": 1}}},
    {"roll": 2, "name": "Poison Expert", "effect": "Family knows poisons well. +1 rank in Medicine (Poison emphasis, free).", "grants": {"skills": {"Medicine": 1}, "emphases": {"Medicine": ["Poison"]}}},
    {"roll": 3, "name": "Blackmail Network", "effect": "Family has leverage. +1 rank in Intimidation (free).", "grants": {"skills": {"Intimidation": 1}}},
    {"roll": 4, "name": "Double Agent", "effect": "Ancestor was a double agent. Family is distrusted. +1 rank in Sincerity (free).", "grants": {"skills": {"Sincerity": 1}}},
    {"roll": 5, "name": "Seductress", "effect": "Ancestor was legendarily charming. +1 rank in Temptation (free).", "grants": {"skills": {"Temptation": 1}}},
    {"roll": 6, "name": "Hidden Wealth", "effect": "Family has secret caches. Starting koku +5.", "grants": {"koku": 5}},
    {"roll": 7, "name": "Assassin's Blood", "effect": "Ancestor was a notorious assassin. +1 rank in Knives (free).", "grants": {"skills": {"Knives": 1}}},
    {"roll": 8, "name": "Political Maneuverer", "effect": "Family excels at court. +1 rank in Courtier (free).", "grants": {"skills": {"Courtier": 1}}},
    {"roll": 9, "name": "Mask of Secrets", "effect": "An ancestral mask with a hidden compartment.", "grants": {"advantages": ["Heritage: Mask of Secrets"]}},
    {"roll": 10, "name": "Fortune's Favor", "effect": "Ancestor struck a bargain with fate.", "grants": {"advantages": ["Heritage: Fortune's Favor"]}},
]

_LEGACY_UNICORN: list[dict] = [
    {"roll": 1, "name": "Gaijin Blood", "effect": "Foreign ancestry. +1 rank in one Gaijin skill (free). Distinct features.", "grants": {"advantages": ["Heritage: Gaijin Blood (+1 Gaijin skill, Fortune chooses)"], "disadvantages": ["Heritage: Gaijin Blood (Social TN +5 conservative courts)"]}},
    {"roll": 2, "name": "Horse Lord", "effect": "Family raises the finest horses. +1 rank in Horsemanship (free).", "grants": {"skills": {"Horsemanship": 1}}},
    {"roll": 3, "name": "Desert Survivor", "effect": "Ancestor crossed the Burning Sands. +1 Stamina for endurance checks.", "grants": {"stamina": 1}},
    {"roll": 4, "name": "Outsider's Perspective", "effect": "Family keeps foreign customs. +1 rank in Investigation (free).", "grants": {"skills": {"Investigation": 1}}},
    {"roll": 5, "name": "Cavalry Tradition", "effect": "Family excels at mounted combat.", "grants": {"advantages": ["Heritage: Cavalry Tradition (+1k0 attack while Mounted)"]}},
    {"roll": 6, "name": "Trade Routes", "effect": "Family controls trade routes. Starting koku +5, +1 rank in Commerce (free).", "grants": {"koku": 5, "skills": {"Commerce": 1}}},
    {"roll": 7, "name": "War Dog Breeder", "effect": "Family breeds war dogs. Start with a trained war dog companion.", "grants": {"advantages": ["Heritage: War Dog Breeder"]}},
    {"roll": 8, "name": "Meishodo Practitioner", "effect": "Ancestor practiced name magic. +1 rank in Lore: Theology (free).", "grants": {"skills": {"Lore: Theology": 1}}},
    {"roll": 9, "name": "Nomadic Heritage", "effect": "Family keeps nomadic traditions. +1 rank in Hunting (free).", "grants": {"skills": {"Hunting": 1}}},
    {"roll": 10, "name": "Battle Hardened", "effect": "Family has fought in many wars. +1 rank in Battle (free).", "grants": {"skills": {"Battle": 1}}},
]

# Combined table: dict values are two-stage (verified), list values are legacy
HERITAGE_TABLES: dict[str, dict | list] = {
    "Crab": _CRAB_TABLE,
    "Crane": _CRANE_TABLE,
    "Dragon": _DRAGON_TABLE,
    "Lion": _LION_TABLE,
    "Mantis": _MANTIS_TABLE,
    "Phoenix": _PHOENIX_TABLE,
    "Scorpion": _LEGACY_SCORPION,
    "Unicorn": _LEGACY_UNICORN,
}

DEFAULT_TABLE: list[dict] = [
    {"roll": 1, "name": "Noble Heritage", "effect": "+3 Glory points.", "grants": {"glory": 3.0}},
    {"roll": 2, "name": "Military Tradition", "effect": "+1 rank in one Bugei skill (free).", "grants": {"advantages": ["Heritage: Military Tradition (+1 Bugei skill, Fortune chooses)"]}},
    {"roll": 3, "name": "Scholarly Lineage", "effect": "+1 rank in one Lore skill (free).", "grants": {"advantages": ["Heritage: Scholarly Lineage (+1 Lore skill, Fortune chooses)"]}},
    {"roll": 4, "name": "Dark Secret", "effect": "Family harbors a secret. Fortune determines details.", "grants": {"disadvantages": ["Dark Secret (family secret)"]}},
    {"roll": 5, "name": "Wealthy Holdings", "effect": "Starting koku +3.", "grants": {"koku": 3}},
    {"roll": 6, "name": "Political Ties", "effect": "+5 Status points.", "grants": {"status": 5.0}},
    {"roll": 7, "name": "Spiritual Connection", "effect": "+1 rank in Meditation (free).", "grants": {"skills": {"Meditation": 1}}},
    {"roll": 8, "name": "Mixed Blessing", "effect": "+1 to one Trait, -1 to another (Fortune chooses).", "grants": {"advantages": ["Heritage: Mixed Blessing (+1 Trait, Fortune chooses)"], "disadvantages": ["Heritage: Mixed Blessing (-1 Trait, Fortune chooses)"]}},
    {"roll": 9, "name": "Ancestral Item", "effect": "Inherit a Fine-quality item of Fortune's choice.", "grants": {"advantages": ["Heritage: Ancestral Item (Fine-quality, Fortune chooses)"]}},
    {"roll": 10, "name": "Destiny", "effect": "+1 Void Point maximum.", "grants": {"void": 1}},
]


def _roll_legacy(table: list[dict]) -> dict:
    """Roll 1d10 on a legacy single-stage table."""
    roll = random.randint(1, 10)
    entry = table[roll - 1]
    return {
        "roll": str(roll),
        "name": entry["name"],
        "effect": entry["effect"],
        "grants": entry.get("grants", {}),
        "notes": entry.get("notes", []),
    }


def _roll_two_stage(table: dict) -> dict:
    """Roll two d10s on a verified two-stage heritage table."""
    cat_roll = random.randint(1, 10)
    category = None
    for cat in table["categories"]:
        if cat_roll in cat["rolls"]:
            category = cat
            break
    if category is None:
        category = table["categories"][0]

    subtable = table[category["table"]]
    entry_roll = random.randint(1, 10)
    entry = _find_entry(subtable, entry_roll)

    return {
        "roll": f"{cat_roll} then {entry_roll}",
        "name": category["name"],
        "effect": entry["effect"],
        "grants": entry.get("grants", {}),
        "notes": entry.get("notes", []),
    }


def roll_heritage(clan: str) -> dict:
    """Roll on a clan's heritage table. Returns {roll, name, effect, grants, notes}."""
    table = HERITAGE_TABLES.get(clan)
    if table is None:
        return _roll_legacy(DEFAULT_TABLE)
    if isinstance(table, dict):
        return _roll_two_stage(table)
    return _roll_legacy(table)


def get_table(clan: str) -> dict | list:
    """Return the raw heritage table data for a clan (or the default)."""
    return HERITAGE_TABLES.get(clan, DEFAULT_TABLE)


def format_table(clan: str) -> str:
    """Return a formatted string showing a clan's full heritage table."""
    table = get_table(clan)
    if isinstance(table, list):
        lines = [f"**{e['roll']}.** {e['name']}: {e['effect']}" for e in table]
        return "\n".join(lines)

    parts: list[str] = []
    parts.append("**Category Roll (d10):**")
    for cat in table["categories"]:
        parts.append(f"{_roll_range_str(cat['rolls'])}: {cat['name']}")
    for cat in table["categories"]:
        subtable = table[cat["table"]]
        parts.append(f"\n**{cat['name']}:**")
        for entry in subtable:
            rng = _roll_range_str(entry["rolls"])
            text = entry["effect"]
            if len(text) > 120:
                text = text[:117] + "..."
            parts.append(f"{rng}: {text}")
    return "\n".join(parts)


def apply_heritage(char: Character, result: dict) -> list[str]:
    """Apply a heritage result's mechanical grants to a character.

    Returns a list of human-readable notes about what was applied.
    """
    grants = result.get("grants", {})
    applied: list[str] = []
    if not grants and not result.get("notes"):
        return applied
    if "skills" in grants:
        for skill_name, rank_bonus in grants["skills"].items():
            current = char.skills.get(skill_name, 0)
            char.skills[skill_name] = current + rank_bonus
            applied.append(f"+{rank_bonus} {skill_name}")
    if "emphases" in grants:
        for skill_name, emph_list in grants["emphases"].items():
            existing = char.emphases.get(skill_name, [])
            for e in emph_list:
                if e not in existing:
                    existing.append(e)
            char.emphases[skill_name] = existing
            applied.append(f"Emphasis: {skill_name} ({', '.join(emph_list)})")
    if "honor" in grants:
        char.honor += grants["honor"]
        applied.append(f"Honor {grants['honor']:+.1f}")
    if "glory" in grants:
        char.glory += grants["glory"]
        applied.append(f"Glory {grants['glory']:+.1f}")
    if "status" in grants:
        char.status += grants["status"]
        applied.append(f"Status {grants['status']:+.1f}")
    if "void" in grants:
        char.void_ring += grants["void"]
        char.max_void_points = char.void_ring
        char.current_void_points = char.void_ring
        applied.append(f"+{grants['void']} Void")
    if "willpower" in grants:
        char.willpower += grants["willpower"]
        applied.append(f"+{grants['willpower']} Willpower")
    if "stamina" in grants:
        char.stamina += grants["stamina"]
        applied.append(f"+{grants['stamina']} Stamina")
    if "taint" in grants:
        char.taint += grants["taint"]
        applied.append(f"Taint {grants['taint']:+.1f}")
    if "infamy" in grants:
        char.infamy += grants["infamy"]
        applied.append(f"Infamy {grants['infamy']:+.1f}")
    if "koku" in grants:
        char.koku += grants["koku"]
        applied.append(f"{grants['koku']:+g} koku")
    if "advantages" in grants:
        for adv in grants["advantages"]:
            if adv not in char.advantages:
                char.advantages.append(adv)
                applied.append(f"Advantage: {adv}")
    if "disadvantages" in grants:
        for dis in grants["disadvantages"]:
            if dis not in char.disadvantages:
                char.disadvantages.append(dis)
                applied.append(f"Disadvantage: {dis}")
    if "armor" in grants:
        from l5r_rules.combat import ARMOR_CATALOG
        armor_key = grants["armor"]
        if armor_key in ARMOR_CATALOG:
            spec = ARMOR_CATALOG[armor_key]
            char.armor_name = armor_key
            char.armor_tn_bonus = spec["tn_bonus"]
            char.armor_reduction = spec["reduction"]
            applied.append(f"Equipped: {armor_key} armor (TN +{spec['tn_bonus']}, Reduction {spec['reduction']})")
    for note in result.get("notes", []):
        applied.append(f"[Fortune]: {note}")
    return applied
