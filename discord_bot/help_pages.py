"""/help: A guided, role-aware manual.

The landing page explains what the bot is and offers two menus: A topic ("what
do you want to do?") with a walkthrough in plain words and the exact commands
in order, and a command group with every command in it. Players never see
staff-only material; Fortune and Kami get extra topics and the staff commands.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import discord
from discord import app_commands


class _Deps:
    is_dm: object
    help_top: object          # () -> list of top-level commands/groups
    help_page_lines: object   # (cmd) -> list[str]
    help_leaves: object       # (cmd) -> list[(path, description)]
    blurbs: dict


_d = _Deps()


def init(*, is_dm, help_top, help_page_lines, help_leaves, blurbs: dict) -> None:
    _d.is_dm = is_dm
    _d.help_top = help_top
    _d.help_page_lines = help_page_lines
    _d.help_leaves = help_leaves
    _d.blurbs = blurbs


@dataclass
class Topic:
    key: str
    label: str
    title: str
    body: str
    staff: str = ""             # appended for Fortune/Kami only
    staff_only: bool = False    # hidden from players entirely
    groups: list[str] = field(default_factory=list)


TOPICS: list[Topic] = [
    Topic(
        key="start", label="Getting started", title="Getting started",
        groups=["sheet", "whoami", "players", "date"],
        body=(
            "**1. Make a character.** Run `/sheet create`. The bot opens a private creation channel for you and "
            "walks you through clan, family, school, heritage, traits, advantages, skills and spells with menus. "
            "Nothing is final until you press **Submit for Approval**.\n"
            "**2. Wait for approval.** Staff review the submission. On approval you get the Approved role, your clan "
            "and family roles, your nickname, and a private support channel named after your character where you "
            "talk to staff and spend XP.\n"
            "**3. Your dashboard.** `/whoami` shows your status card (rings, wounds, Void, honor, what you wield) with "
            "buttons for the full sheet, inventory, Void, Kata, Kiho, tattoos and export. Everything it shows is "
            "private to you.\n"
            "**4. Look around.** `/players` lists the approved characters, `/date` shows the Rokugani date, "
            "`/help` brings you back here.\n\n"
            "**Privacy rule.** Your dice pools, wounds count, Void Points and sheet are yours. Public posts show "
            "totals, TNs and outcomes only. Anything private arrives as a message only you can see, or in your "
            "support channel.\n\n"
            "**Roles.** Fortune runs the game (approvals, damage, NPCs). Kami administers the server. "
            "One character per player."
        ),
    ),
    Topic(
        key="character", label="Your character", title="Your character",
        groups=["sheet", "whoami", "void", "portrait"],
        body=(
            "**Sheet.** `/sheet view` shows your full sheet privately. `/sheet activate` picks which character is "
            "active if staff gave you more than one. `/sheet data export` gives you a JSON copy.\n"
            "**Void Points.** `/void spend reason:` spends one and logs why. `/void status` shows what you have. "
            "`/void refresh mode:Rest` needs staff; `mode:Meditation` rolls Meditation/Void on your own to recover one.\n"
            "**Kata, Kiho, tattoos.** Activate from `/whoami` or with `/sheet kata activate`, `/sheet kiho activate` "
            "and `/sheet tattoo activate`. Only one Kata at a time; the rules on exclusivity are enforced.\n"
            "**Techniques.** When your School Rank rises, `/sheet learn` records the techniques your school grants. "
            "In a fight, the board's **Techniques** button declares the ones that need declaring.\n"
            "**Portrait.** `/portrait set image:` with an upload, or `url:` with a link. It appears on your card and "
            "sheet, and `/portrait show` posts it in the channel for everyone.\n"
            "**What you cannot change.** Traits, skills, honor, glory and the like are edited by staff only. You "
            "advance through `/xp` (see Advancement) and manage gear through `/inventory` (see Gear and money)."
        ),
        staff=(
            "\n\n__Staff__\n`/edit` covers every field on any sheet: `trait`, `skill`, `field`, `identity`, `equip`, "
            "`feature`, `elements`, `wound`, `heal`, `activate`, `rename`, `notes`, `mount`, `spell`. `/sheet view "
            "member:` and `/sheet list member:` look at a player's sheets; `/sheet owner` reassigns one; `/sheet "
            "delete` removes one (roles, nickname and initiative are cleaned up). `/dm taint` adjusts Shadowlands "
            "Taint; at Rank 5 the character becomes a staff NPC."
        ),
    ),
    Topic(
        key="dice", label="Dice and checks", title="Dice and checks",
        groups=["roll", "dice", "check", "macro", "history"],
        body=(
            "**Plain dice.** `/roll rolled:7 kept:3` rolls 7k3. Add `tn:` to see success, `raises:` to call raises "
            "(+5 TN each), `emphasis:true` to reroll 1s once, `secret:true` to keep it to yourself. `/dice 7k3+5` is "
            "the shorthand. `/macro save` and `/macro roll` keep your usual pools. `/history` lists recent rolls here.\n"
            "**Checks from your sheet.** `/check skill trait: skill: tn:` builds the pool from your character, with "
            "wound penalties, advantages, emphases and Void spends applied for you. Specialised versions know the "
            "right trait: `/check stealth`, `/check investigate`, `/check social` (Courtier, Etiquette, Sincerity, "
            "Intimidation, Perform), `/check craft` (Artisan uses Awareness), `/check lore`, `/check horsemanship`, "
            "`/check medicine`, `/check poison`, `/check fear`, `/check honor` (the once-a-session Honor Roll).\n"
            "**Private or public.** Checks are private by default. `secret:false` posts the total, TN and outcome "
            "in the channel; the dice and modifiers still come to you alone.\n"
            "**Working together.** `/check cooperative` runs a group roll in either s41 form: Low, one roll plus the "
            "helpers' Skill Ranks, or High, everyone rolls and the best aids the rest.\n"
            "**Raises.** You may call at most your Void Ring in raises on one roll. Free Raises from techniques and "
            "masteries are added for you and do not count."
        ),
        staff=(
            "\n\n__Staff__\n`/check contest` runs a contested roll between any two characters. Every check takes "
            "`name:` or `member:` and `is_npc:true` so you can roll for anyone. `/dm craft_extended` handles long "
            "crafting projects."
        ),
    ),
    Topic(
        key="gear", label="Gear and money", title="Gear and money",
        groups=["inventory", "trade", "pay", "give", "take"],
        body=(
            "**The panel.** `/inventory` opens your gear privately. **Main hand** and **Off hand** menus wield what "
            "you own; whatever is in the main hand is what `/fight attack` uses. The **Action** menu drops a weapon, "
            "removes items, or puts armor on and takes it off. Changes save at once.\n"
            "**Bows and arrows.** Pick an arrow type as your main-hand weapon; the bow moves to your off hand by "
            "itself. Every shot spends one arrow, and the menu shows how many you have. An empty quiver refuses "
            "the shot, so ask staff for more before it comes to that.\n"
            "**Two weapons.** A weapon in each hand means −5 on main-hand attacks, the off-hand penalty by weapon "
            "size when you attack with it, and +Insight Rank to your Armor TN. A bow held for arrows is not dual "
            "wielding.\n"
            "**Getting things.** Only staff can hand out gear and money, with `/give`. You receive a note in your "
            "support channel each time.\n"
            "**Between players.** `/trade item: member:` hands an item to another character, `/pay member:` gives "
            "koku, bu or zeni. Both come from what you actually hold.\n"
            "**Reference.** `/ref weapon view` and `/ref armor view` show the stats; `/ref encumbrance` and "
            "`/ref dual_wield` explain the rules for your character."
        ),
        staff=(
            "\n\n__Staff__\n`/give what: character:` hands out a catalog weapon (real stats), an armor type, "
            "koku, bu, zeni, or any item; arrows go to the quiver by count. `/take` is the reverse and lists only what "
            "the target holds. Use `character:` rather than `member:` from a private room, since Discord's member "
            "picker only offers people in the channel. Weapon qualities are set from the staff row of `/inventory`."
        ),
    ),
    Topic(
        key="fight", label="Fighting", title="Fighting",
        groups=["combat", "fight"],
        body=(
            "**Joining.** Staff open a fight with `/combat start` in the channel, or anyone posts a roster with "
            "`/combat setup` and invited players press **Join**. `/combat join` rolls your Initiative. `/combat "
            "next` begins Round 1 and posts the **Combat Board**, which pings whoever is up.\n"
            "**The board.** Its buttons do most of a turn: **Stance**, **Attack**, **Techniques** (declare one), "
            "**Kata**, **Kiho**, **Tattoo**, **Cast Spell**, **Void Armor**, **Void Init**, **Void Swap**, **Gear** "
            "(your inventory, to swap weapons or arrows), **End Turn**. `/fight status` shows your own card.\n"
            "**Attacking.** `/fight attack target:` (or `target_npc:`, `target_creature:`) rolls to hit against the "
            "target's Armor TN. Options: `raises:` (+5 TN each, at most your Void Ring), `maneuver:` (Feint, "
            "Disarm, Knockdown, Called Shot, Extra Attack, each with its raise cost added for you), "
            "`attacker_stance:` and `defender_stance:`, `spend_void:` for +1k1, `increased_damage:`, `off_hand:` "
            "to strike with the off-hand weapon, `point_blank:` for a ranged shot at someone within melee reach "
            "(−10), `weapon_material:` for jade, crystal or obsidian.\n"
            "**What everyone sees.** The channel gets weapon, stance, total vs TN and hit or miss. The full "
            "breakdown is yours alone. On a hit, a damage card goes to staff; when they apply it, the channel sees "
            "the damage and the new wound level, never the count.\n"
            "**Actions.** A turn is one Complex action or two Simple ones. An attack is Complex. `/fight action` "
            "records other uses. Changing stance after Round 1 costs a Simple action. `/fight full_defense` and "
            "`/fight guard` are the defensive options; `/fight mount` handles horses.\n"
            "**Conditions.** Prone, Dazed, Stunned, Grappled and the rest are tracked on you and change your "
            "rolls and Armor TN automatically. The board's turn message reminds you of active ones."
        ),
        staff=(
            "\n\n__Staff__\n`/combat npc`, `/combat creature` and `/combat category` add your side. `/combat "
            "turn init|hold|delay|act|done|surprise` manage the order; `/combat condition set|clear|list` "
            "and `/fight condition` apply conditions; `/fight env cover|damage|notes` handle terrain. "
            "`/combat summary` shows the initiative breakdown, `/combat recap` the tally, `/combat end` closes.\n"
            "Damage cards land in the damage approval channel (`/dm damage_channel`). **Apply** resolves them and "
            "relays the result. `/dm damage`, `/dm heal`, `/dm treat`, `/dm undo` and `/dm revive` are the "
            "manual tools, all through the same approval channel. A budget refusal names whose turn it is; "
            "`/fight action action_type:Reset` overrides it."
        ),
    ),
    Topic(
        key="duel", label="Duels and grapples", title="Duels and grapples",
        groups=["engage", "duel", "grapple"],
        body=(
            "**Iaijutsu duel.** `/engage duel start duelist_a: duelist_b:` posts a duel board. Either duelist's "
            "player or staff drive the stages:\n"
            "• **Assess**: Both roll Iaijutsu (Assessment)/Awareness. The channel sees totals and who earned the "
            "+1k1 Focus bonus. What you learned about your opponent (Void, Reflexes, Iaijutsu, wound level) comes "
            "to you privately.\n"
            "• **Focus**: The contested roll for Free Raises and who strikes first.\n"
            "• **Strike**: The attack, with damage through the staff card like any hit.\n"
            "Either duelist may concede after Assessment.\n"
            "**Grapple.** `/engage grapple initiate attacker: target:` is the grab (Jiujutsu/Agility, then contested "
            "Strength). On success both are **Grappled**: Armor TN 5 plus armor, no stances, no Large weapons, and "
            "a grapple board appears. The controller can **Hit**, **Throw** or **Pin**; either side can **Contest "
            "Control** or **Break Free**. Each is a Complex action on the actor's own turn.\n"
            "**Third parties.** Anyone attacking a grappled character gets the reduced Armor TN automatically.\n"
            "`/duel` and `/grapple` are shortcuts that offer a menu of combatants."
        ),
        staff=(
            "\n\n__Staff__\n`/engage battle start|roll|table|damage|status` runs Mass Battle: Each round the "
            "general rolls, the table decides the personal result, and damage or glory follow the s11 tables."
        ),
    ),
    Topic(
        key="magic", label="Magic", title="Magic",
        groups=["spell"],
        body=(
            "**Finding spells.** `/spell list element:`, `/spell search`, `/spell view name:` for the full text. "
            "Spells you know are on your sheet; `/xp spell` memorises one so no scroll is needed.\n"
            "**Casting.** `/spell cast name:` rolls Ring + School Rank against the spell's TN and spends a slot of "
            "that element. Options: `raises:` for the spell's raise effects, `spend_void:` for +1k1, `target:` to "
            "aim it at a combatant (unlocks buttons to request conditions like Dazed), `conceal:` to hide the "
            "casting behind a Stealth roll, `cast_element:` for Universal spells (Commune, Sense, Summon, Command). "
            "The **Cast Spell** button on the combat board does the same.\n"
            "**Damage spells.** `/spell damage rolled: kept:` rolls the damage and sends a card to staff, who "
            "apply it like weapon damage.\n"
            "**Resisting and interrupting.** `/spell resist target: tn:` rolls a resistance; `/spell interrupt` "
            "is the counterspell contest.\n"
            "**Importune.** `/spell importune name:` asks the kami for a spell you do not know, at the harder TN.\n"
            "**Slots.** Spell slots refresh when staff advance the day with `/dm new_day`, together with Void."
        ),
    ),
    Topic(
        key="xp", label="Advancement", title="Advancement (XP)",
        groups=["xp"],
        body=(
            "**Getting XP.** Staff grant it with `/xp grant`. There is no automatic award. `/xp balance` shows "
            "what you have.\n"
            "**Spending it.** Only inside your own support channel (the one named after your character). "
            "`/xp spend` opens a menu of everything you can buy; or go direct: `/xp trait`, `/xp skill`, "
            "`/xp emphasis`, `/xp kata`, `/xp kiho`, `/xp spell`, `/xp advantage`, `/xp remove_disadvantage`. "
            "Each shows the cost and refuses if you are short or at a cap.\n"
            "**Costs** (`/xp costs`): Trait to rank N is N×4, Void N×6, skill N×1, an emphasis 2, kata and spells "
            "their Mastery Level, kiho scaled by monk or shugenja, advantages at their point value, disadvantages "
            "bought off at double.\n"
            "**Ranking up.** Insight is Rings×10 plus skill ranks. At 150, 175, 200, 225, 250 your School Rank "
            "rises and the reply tells you. Run `/sheet learn` to add the technique your school grants at the new "
            "rank.\n"
            "**Not modelled yet.** Alternate paths, advanced schools and a second school are handled by staff by "
            "hand for now."
        ),
        staff=(
            "\n\n__Staff__\n`/xp grant member: amount: reason:` writes to the Kami-only XP log channel "
            "(`/dm xp_log_channel`). `/xp balance member:` reads a player's balance."
        ),
    ),
    Topic(
        key="social", label="Letters, rumors and rooms", title="Letters, rumors and rooms",
        groups=["letter", "rumor", "room", "location"],
        body=(
            "**Letters.** `/letter send recipient: message:` writes in character to another player character. "
            "`/letter list` and `/letter read` show what you received. Delivery goes to the recipient's support "
            "channel.\n"
            "**Rumors.** `/rumor list` and `/rumor view` show what your character has heard. Staff post them "
            "targeted by clan, family, school or character, so not everyone hears the same thing.\n"
            "**Rooms.** `/room create name:` opens a private thread you host; `/room invite member:` and "
            "`/room kick` manage who is in it; `/room describe` pins a description; `/room close` ends it. "
            "Everything works inside a room: sheets, rolls, fights, spells.\n"
            "**Locations.** `/location list` shows the in-character areas and their channels. Staff create them."
        ),
        staff=(
            "\n\n__Staff__\n`/letter sendas sender_name:` writes as any character, NPCs included. `/rumor post`, "
            "`/rumor public` and `/rumor broadcast` seed information; `/rumor channel` sets the board. "
            "`/location area create` and `/location create` build areas and channels with role or member access; "
            "`/location area fix-permissions` repairs them. `/npc place` puts an NPC in a room and `/npc say` "
            "speaks as them there."
        ),
    ),
    Topic(
        key="ref", label="Rules reference", title="Rules reference",
        groups=["ref", "spell", "creature"],
        body=(
            "Everything the bot knows about the rules, readable any time:\n"
            "• `/ref weapon list|view`, `/ref armor list|view|search`\n"
            "• `/ref school list|search|view`, `/ref family list|search`, `/ref heritage table|roll clan:`\n"
            "• `/ref kata`, `/ref kiho`, `/ref tattoo`, `/ref advantage` with `list`, `search`, `view`\n"
            "• `/ref search query:` looks across all of them at once\n"
            "• `/ref encumbrance`, `/ref armor_tn`, `/ref ancestors`, `/ref dual_wield` explain a rule for your "
            "character; `/ref travel distance: mode:` computes journeys; `/ref modifiers` and `/ref calledshot` "
            "are the combat tables\n"
            "• `/spell list|search|view` for spells, `/creature catalog|search|info|compare` for the bestiary\n"
            "• `/compare name_a: name_b:` puts two characters side by side\n"
            "All rules are Legend of the Five Rings 4th Edition as adopted in the game design document."
        ),
    ),
    Topic(
        key="staff_setup", label="Staff: Server and channels", title="Staff: Server and channels", staff_only=True,
        groups=["setup", "dm", "stipend", "weather", "sync"],
        body=(
            "**First time.** `/setup server` (Kami) creates the Kami, Fortune and Approved roles and the channel "
            "layout: Lobby, OOC, IC, Player Support, Staff Members with `approvals` and `damage-approvals`.\n"
            "**Channels the bot posts to.** `/dm approval_channel` (character submissions, cards), "
            "`/dm damage_channel` (damage cards), `/dm log_channel` (combat and audit log), `/dm xp_log_channel` "
            "(Kami-only XP ledger), `/dm date_channel` (the calendar), `/rumor channel`. Each has a `clear` twin. "
            "Without an approval channel, damage and healing commands refuse to run.\n"
            "**Time.** `/dm setdate` sets the Rokugani date; `/dm new_day` advances one day, heals, refreshes Void "
            "and spell slots, pays stipends on a new month (`/stipend set clan:`), and reports Taint crossings.\n"
            "**Weather.** `/weather now`, `/weather forecast`, `/weather set`.\n"
            "**Announcements.** `/dm announce title: description:` posts a formatted notice.\n"
            "**Commands.** The bot registers its commands with Discord on start when they changed. `/sync` "
            "(Kami) forces it and reports any problem Discord would reject.\n"
            "**Roles.** Fortune runs play. Kami administers. `/dm roles` shows who holds them."
        ),
    ),
    Topic(
        key="staff_players", label="Staff: Players and approvals", title="Staff: Players and approvals", staff_only=True,
        groups=["dm", "edit", "give", "take", "xp", "sheet"],
        body=(
            "**Approvals.** New characters arrive as cards in the approval channel with **Approve** and **Reject**. "
            "Approving assigns roles, nickname and a support channel. `/dm pending` lists what is waiting.\n"
            "**Sheets.** `/edit` changes anything on a sheet; every edit is logged with who did it. `/sheet view "
            "member:` reads a player's sheet, `/sheet owner` reassigns, `/sheet delete` removes with cleanup, "
            "`/sheet data import` restores from JSON.\n"
            "**Gear and money.** `/give` and `/take` for weapons (with real stats), armor, arrows, money and "
            "items; the player is told in their support channel. `/stipend` handles monthly clan income.\n"
            "**Progress.** `/xp grant` awards XP; players spend it in their support channel. `/dm influence` "
            "adjusts Influence.\n"
            "**Health.** `/dm damage`, `/dm heal`, `/dm treat healer: patient: treatment:` (Medicine), `/dm undo` "
            "reverses a recent change, `/dm revive` is only for undoing a mistake since death is permanent. "
            "`/dm taint add:` applies Shadowlands Taint; at Rank 5 the character is Lost and becomes an NPC.\n"
            "**Overview.** `/dm party` summarises every active character; `/players` lists them; `/dm wizard` is "
            "a menu of the common staff tasks."
        ),
    ),
    Topic(
        key="staff_npc", label="Staff: NPCs and creatures", title="Staff: NPCs and creatures", staff_only=True,
        groups=["npc", "creature", "category"],
        body=(
            "**NPCs** are full sheets owned by staff. `/npc generate name: insight_rank:` builds one from clan, "
            "family and school templates; `/npc create` and `/npc form` open the wizard; `/npc edit` revises; "
            "`/npc clone` copies; `/npc template save|spawn|list` reuses builds. `/npc view`, `/npc list`, "
            "`/npc delete`.\n"
            "**Playing them.** `/npc place` puts one in a room and `/npc say` speaks as them through a webhook. "
            "`/combat npc` adds one to a fight; then any `/fight` or `/check` command takes `attacker_npc:` or "
            "`is_npc:true`. `/give character:` equips them.\n"
            "**Creatures** come from the bestiary: `/creature catalog|search|info|compare`, `/creature spawn "
            "template:` (with `randomize:`), `/creature create` for a custom one, `/creature wound|heal`, "
            "`/creature attack creature_name: target:` (result public, breakdown on the card).\n"
            "**Categories.** `/category create`, `add`, `bulk_add`, `spawn` and `/combat category` handle groups "
            "such as a bandit gang in one go.\n"
            "**Privacy.** NPC and creature names never appear in players' autocompletes or sheets; only what "
            "stands in the initiative order is visible to them."
        ),
    ),
]

_TOPIC_BY_KEY = {t.key: t for t in TOPICS}

_INTRO = (
    "This bot runs **Legend of the Five Rings, 4th Edition** for this server: character sheets, Roll and Keep "
    "dice, fights with initiative and damage approval, duels, magic, gear, letters and rumors. "
    "It does the arithmetic; the staff make the calls.\n\n"
    "**Pick a topic** below for a walkthrough, or **a command group** for the list of commands in it. "
    "`/help category:` jumps straight to either.\n\n"
    "**The three commands to know:** `/sheet create` to make a character, `/whoami` for your dashboard, "
    "`/fight attack` on your turn in a fight."
)


def _staff_tagged(desc: str) -> bool:
    d = (desc or "").rstrip().rstrip(".")
    return d.endswith("[Fortune]") or d.endswith("[Kami]")


def visible_topics(is_staff: bool) -> list[Topic]:
    return [t for t in TOPICS if is_staff or not t.staff_only]


def visible_groups(is_staff: bool):
    out = []
    for cmd in _d.help_top():
        leaves = _d.help_leaves(cmd)
        if not is_staff and all(_staff_tagged(desc) for _, desc in leaves):
            continue
        if cmd.name == "help":
            continue
        out.append(cmd)
    return out


def overview_embed(is_staff: bool) -> discord.Embed:
    lines = [_INTRO, ""]
    lines.append("__**Topics**__")
    for t in visible_topics(is_staff):
        lines.append(f"• **{t.label}**")
    if is_staff:
        lines.append("")
        lines.append("You hold a staff role, so staff topics and commands are included. Players see neither.")
    embed = discord.Embed(title="Rokugan Bot: Help", description="\n".join(lines)[:4096], color=discord.Color.gold())
    embed.set_footer(text="Menus below. This message is only visible to you.")
    return embed


def topic_embed(topic: Topic, is_staff: bool) -> discord.Embed:
    body = topic.body + (topic.staff if is_staff and topic.staff else "")
    if topic.groups:
        body += "\n\n__Command groups__: " + ", ".join(f"`/{g}`" for g in topic.groups)
    embed = discord.Embed(title=f"Help: {topic.title}", description=body[:4096], color=discord.Color.gold())
    embed.set_footer(text="Pick another topic or a command group below.")
    return embed


def group_embeds(cmd, is_staff: bool) -> list[discord.Embed]:
    """One or more embeds listing every command in a group, staff lines hidden from players."""
    lines = _d.help_page_lines(cmd)
    hidden = 0
    if not is_staff:
        kept = []
        for line in lines:
            if _staff_tagged(line):
                hidden += 1
                continue
            kept.append(line)
        lines = kept
    total = len(_d.help_leaves(cmd))
    blurb = _d.blurbs.get(cmd.name, "")
    embeds: list[discord.Embed] = []
    chunk: list[str] = []
    size = len(blurb) + 2
    for line in lines:
        if size + len(line) + 1 > 3900 and chunk:
            embeds.append(discord.Embed(description="\n".join(chunk), color=discord.Color.gold()))
            chunk, size = [], 0
        chunk.append(line)
        size += len(line) + 1
    embeds.append(discord.Embed(description="\n".join(chunk).strip() or "No commands to show.", color=discord.Color.gold()))
    shown = total - hidden
    embeds[0].title = f"Help: /{cmd.name} ({shown} command{'s' if shown != 1 else ''})"
    if blurb:
        embeds[0].description = blurb + "\n\n" + (embeds[0].description or "")
    if hidden:
        embeds[-1].set_footer(text=f"{hidden} staff-only command{'s' if hidden != 1 else ''} not shown.")
    return embeds


class HelpView(discord.ui.View):
    """Two menus: Topics and command groups. Edits the same private message in place."""

    def __init__(self, is_staff: bool, user_id: int) -> None:
        super().__init__(timeout=900)
        self.is_staff = is_staff
        self.user_id = user_id
        topics = visible_topics(is_staff)
        self.topic_select = discord.ui.Select(
            placeholder="Topic: What do you want to do?",
            options=[discord.SelectOption(label=t.label[:100], value=t.key) for t in topics][:25], row=0,
        )
        self.topic_select.callback = self._on_topic
        self.add_item(self.topic_select)
        groups = visible_groups(is_staff)
        self.group_select = discord.ui.Select(
            placeholder="Command group: Every command in it",
            options=[discord.SelectOption(label=f"/{c.name}", value=c.name,
                                          description=(_d.blurbs.get(c.name) or c.description or "")[:100] or None)
                     for c in groups][:25], row=1,
        )
        self.group_select.callback = self._on_group
        self.add_item(self.group_select)
        if len(groups) > 25:
            self.group_select_2 = discord.ui.Select(
                placeholder="More command groups",
                options=[discord.SelectOption(label=f"/{c.name}", value=c.name,
                                              description=(_d.blurbs.get(c.name) or c.description or "")[:100] or None)
                         for c in groups[25:50]], row=2,
            )
            self.group_select_2.callback = self._on_group
            self.add_item(self.group_select_2)
        home = discord.ui.Button(label="Overview", style=discord.ButtonStyle.secondary, row=3)
        home.callback = self._on_home
        self.add_item(home)

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.user_id:
            await interaction.response.send_message("Run `/help` yourself to browse.", ephemeral=True)
            return False
        return True

    async def _on_topic(self, interaction: discord.Interaction) -> None:
        key = self.topic_select.values[0] if self.topic_select.values else ""
        topic = _TOPIC_BY_KEY.get(key)
        if topic is None:
            await interaction.response.defer()
            return
        await interaction.response.edit_message(embed=topic_embed(topic, self.is_staff), view=self)

    async def _on_group(self, interaction: discord.Interaction) -> None:
        values = self.group_select.values or getattr(getattr(self, "group_select_2", None), "values", None) or []
        name = values[0] if values else ""
        cmd = next((c for c in _d.help_top() if c.name == name), None)
        if cmd is None:
            await interaction.response.defer()
            return
        embeds = group_embeds(cmd, self.is_staff)
        await interaction.response.edit_message(embed=embeds[0], view=self)
        for extra in embeds[1:]:
            await interaction.followup.send(embed=extra, ephemeral=True)

    async def _on_home(self, interaction: discord.Interaction) -> None:
        await interaction.response.edit_message(embed=overview_embed(self.is_staff), view=self)


async def autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    is_staff = _d.is_dm(interaction)
    cur = (current or "").lower().lstrip("/").strip()
    out: list[app_commands.Choice[str]] = []
    for t in visible_topics(is_staff):
        if cur in t.label.lower() or cur in t.key:
            out.append(app_commands.Choice(name=t.label, value=t.key))
    for c in visible_groups(is_staff):
        if cur in c.name:
            out.append(app_commands.Choice(name=f"/{c.name}", value=c.name))
    return out[:25]


async def run(interaction: discord.Interaction, category: str | None) -> None:
    is_staff = bool(_d.is_dm(interaction))
    view = HelpView(is_staff, interaction.user.id)
    if category:
        key = category.strip().lstrip("/").lower()
        topic = _TOPIC_BY_KEY.get(key) or next((t for t in visible_topics(is_staff) if t.label.lower() == key), None)
        if topic is not None and (is_staff or not topic.staff_only):
            await interaction.response.send_message(embed=topic_embed(topic, is_staff), view=view, ephemeral=True)
            return
        cmd = next((c for c in visible_groups(is_staff) if c.name == key), None)
        if cmd is not None:
            embeds = group_embeds(cmd, is_staff)
            await interaction.response.send_message(embed=embeds[0], view=view, ephemeral=True)
            for extra in embeds[1:]:
                await interaction.followup.send(embed=extra, ephemeral=True)
            return
        await interaction.response.send_message(
            f"No topic or command group called **{category}**. Use the menus below.",
            embed=overview_embed(is_staff), view=view, ephemeral=True,
        )
        return
    await interaction.response.send_message(embed=overview_embed(is_staff), view=view, ephemeral=True)
