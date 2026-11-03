"""Build the player and staff cheat sheets from one source of truth.

Outputs (next to the bot, relative to discord_bot/):
  PLAYER_CHEATSHEET.md, STAFF_CHEATSHEET.md   Discord-ready: one card per message
  cheatsheets/player.html, staff.html          clean printable pages
  cheatsheets/player.png, staff.png            images to pin in a channel

Run from anywhere:   python3 tools/build_cheatsheets.py
Add --no-png to skip the images (they need a headless Chromium).

Every command named in a sheet is checked against the bot's live command tree,
so a renamed or removed command fails the build instead of lying to players.
"""
from __future__ import annotations

import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


@dataclass
class E:
    """One command line: the command (A | B means pick one), options, what it does."""
    cmd: str
    text: str
    opts: str = ""


@dataclass
class N:
    """A short note under a card's commands."""
    text: str


@dataclass
class Card:
    title: str
    items: list = field(default_factory=list)


@dataclass
class Sheet:
    slug: str
    title: str
    audience: str
    intro: str
    legend: str
    cards: list
    accent_band: str


# --------------------------------------------------------------------------- #
# Player sheet
# --------------------------------------------------------------------------- #
PLAYER = Sheet(
    slug="player",
    title="Player Cheat Sheet",
    audience="For everyone playing",
    intro="Type `/` in any channel, pick a command, then fill in its options. `/help` opens the full manual.",
    legend="A | B means pick one. Grey words are options. You have one character, so you never need to name it.",
    accent_band="#7a1f1a",
    cards=[
        Card("Start here", [
            E("/sheet create", "Build your character in a private channel. Staff approve it."),
            E("/whoami", "Your home screen, with buttons for Void, kata, gear and more."),
            E("/sheet view", "Your full character sheet."),
            E("/inventory", "Wield weapons, wear armor, drop things, check your purse."),
            E("/portrait set", "Add a picture of your character."),
            E("/help", "The full manual, by topic."),
        ]),
        Card("Roll dice", [
            E("/roll", "Roll and Keep. Only you see it unless you change secret.", "rolled kept"),
            E("/dice 5k3", "The quick way. Also 7k2+5."),
            E("/check skill | social | stealth | investigate | lore | craft",
              "A skill roll against a TN your GM names. Every one but skill picks the trait for you."),
            E("/macro save | roll", "Save a roll you repeat, then roll it by name."),
            E("/history", "The latest rolls in this channel."),
            N("Add `spend_void` to a check for +1k1. Use `secret` to choose who sees it."),
        ]),
        Card("Void and abilities", [
            E("/void status", "How many Void Points you have."),
            E("/void spend", "Spend one and say why."),
            E("/void refresh", "A Meditation roll to win one back."),
            E("/sheet kata activate", "Set your active kata."),
            E("/sheet kiho activate", "Turn a kiho on or off."),
            E("/sheet tattoo activate", "Set your active tattoo."),
        ]),
        Card("Spend XP", [
            N("Only in your own character channel. Staff grant the XP."),
            E("/xp balance", "What you have."),
            E("/xp spend", "A menu of everything you can buy."),
            E("/xp trait | skill | emphasis | kata | kiho | advantage", "Buy one directly."),
            E("/xp spell", "Memorise a spell you already know."),
            E("/xp costs", "The price list."),
            N("Ranking up: Your new technique appears by itself. Shugenja pick three new spells, "
              "and `/sheet learn` reopens the picker."),
        ]),
        Card("Money and items", [
            E("/pay", "Give money to another player.", "member koku bu zeni"),
            E("/trade", "Give an item to another player.", "member item"),
            E("/inventory", "See and manage what you carry."),
            N("Staff hand out items found in play. Arrows run out as you shoot them."),
        ]),
        Card("Fight", [
            E("/combat setup", "Invite the players, then begin."),
            E("/combat start | join", "Or start a fight and join it yourself."),
            E("/combat board", "Post the board of action buttons."),
            E("/fight stance", "Pick this first. It locks once you act."),
            E("/fight attack", "Attack, with raises and maneuvers."),
            E("/fight action | full_defense | guard", "Track your actions, or defend."),
            E("/combat turn done", "End your turn."),
            E("/combat status | recap", "The turn order, or the tally so far."),
            E("/combat end", "Close a fight that has only players in it."),
            N("Your hits go to staff to approve. Everyone sees your wound level, never the count."),
        ]),
        Card("Grapples, duels and Void", [
            E("/grapple", "Start a grapple. Pick the two fighters from a menu."),
            E("/duel", "Start an Iaijutsu duel."),
            E("/combat void armor | initiative | swap", "Spend a Void Point in a fight."),
            E("/fight condition", "Ask staff to apply Dazed, Prone and the like."),
        ]),
        Card("Magic", [
            E("/spell cast", "Cast a spell you know."),
            E("/spell importune", "Ask the kami for a spell you do not know."),
            E("/spell list | search | view", "Browse every spell."),
            N("You cast up to your School Rank in Mastery, one more in your Affinity element and one less "
              "in your Deficiency. New spells come only from rank-ups and from staff."),
        ]),
        Card("Roleplay", [
            E("/room create", "Make a private room and host it."),
            E("/room invite | kick | close", "Run these inside the room."),
            E("/letter send", "Write an in-character letter."),
            E("/letter list | read", "Your old letters."),
            E("/rumor list", "Rumors that reached you."),
            E("/location list", "The places on the server."),
            E("/date", "The in-game date."),
            E("/weather now", "Today's weather."),
        ]),
        Card("Look things up", [
            E("/ref search", "Search every catalogue at once."),
            E("/ref weapon | armor | advantage | kata | kiho | school | tattoo",
              "Pick one, then list, view or search."),
            E("/ref modifiers | calledshot | travel", "Quick combat and travel rules."),
            E("/ref encumbrance", "How much you can carry."),
            E("/compare", "Two characters side by side."),
            E("/players", "Who is on the server."),
        ]),
    ],
)

# --------------------------------------------------------------------------- #
# Staff sheet
# --------------------------------------------------------------------------- #
STAFF = Sheet(
    slug="staff",
    title="Staff Cheat Sheet",
    audience="For Fortune and Kami",
    intro="Fortune run the game. Kami also administer the server. Commands tagged [Kami] need Kami.",
    legend="A | B means pick one. Grey words are options. Most commands take member (pick a player) "
           "or character (type any name, NPCs too).",
    accent_band="#2b2a33",
    cards=[
        Card("Know this first", [
            E("/dm wizard", "A menu of every staff action. Start here if you forget a command."),
            N("`character` takes any character or NPC by name, from any channel. It autocompletes for staff only."),
            N("Players get a private notice when you edit their sheet, grant XP, deal damage, heal or give items."),
            N("The bot never changes Honor or Glory by itself, and never hurts NPCs by itself. You do both."),
        ]),
        Card("Set up once (Kami)", [
            E("/setup server", "Build the roles and channels."),
            E("/dm approval_channel", "Where new characters arrive."),
            E("/dm damage_channel", "Where damage and healing cards arrive."),
            E("/dm log_channel", "The combat event log."),
            E("/dm xp_log_channel", "A Kami-only log of XP and rank-up spells."),
            E("/dm date_channel", "The pinned in-game date."),
            E("/rumor channel", "The notice board for public rumors."),
            E("/sync", "Re-register the commands if they look stale."),
            N("Most channel commands have a clear twin, like `/dm clear_log`."),
        ]),
        Card("Each session", [
            E("/dm party", "Every active PC at a glance."),
            E("/dm pending", "Approvals still waiting, with jump links."),
            E("/dm new_day", "Heal everyone, refresh Void and spell slots."),
            E("/dm setdate", "Set the calendar. It also shows in #calendar."),
            E("/dm announce", "Post a session with RSVP reactions."),
            E("/weather set", "Choose the weather."),
            E("/dm undo", "Roll back the last change. Try preview first.", "preview"),
            E("/dm revive", "Undo a bug death. Otherwise death is permanent."),
            E("/dm taint", "View or change Shadowlands Taint."),
            E("/dm influence", "Track Influence in a court scene."),
        ]),
        Card("Approvals and damage", [
            N("New characters: Press Approve, or Deny to send the wizard back so the player can adjust it."),
            N("Damage cards: Press Roll & Apply Damage or Deny. Players only see the wound level."),
            E("/dm damage | heal", "Send a card for a character."),
            E("/dm treat", "A healer rolls Medicine and you approve."),
            E("/edit wound | heal", "Change wounds directly, with no card."),
            N("Condition requests from `/fight condition` and spells also come to you."),
        ]),
        Card("Edit characters", [
            E("/edit trait", "Set a Trait or Void."),
            E("/edit skill", "One skill, or many like Kenjutsu 3, Courtier 2."),
            E("/edit field", "Honor, glory, koku, school rank, void points and more."),
            E("/edit feature", "Add or remove advantages, techniques, kata, kiho, weapons, emphasis, tattoos or spells."),
            E("/edit spell", "Add or remove a spell. It warns you when it is above their rank."),
            E("/edit elements", "Set Affinity and Deficiency. Isawa choose theirs."),
            E("/edit identity | equip | activate | mount | rename | notes", "Clan, gear, active abilities, name and notes."),
            E("/sheet view | list | owner | delete | learn", "Work on another sheet with member or character."),
            E("/sheet data import", "Create a character from JSON."),
        ]),
        Card("XP, items and portraits", [
            E("/xp grant", "Give XP. A negative amount corrects. Add a reason.", "amount member reason"),
            E("/xp balance", "Check a total."),
            E("/give | take", "A weapon, armor, money or any item. Arrows go to the quiver.", "what"),
            E("/inventory", "Open anyone's gear, NPCs too.", "character"),
            E("/portrait set", "Set or clear another character's picture.", "character"),
            N("Rank-ups are automatic. The new technique lands on the sheet, and shugenja get a three-spell picker."),
        ]),
        Card("NPCs", [
            E("/npc create", "Step-by-step builder with exact stats."),
            E("/npc form", "One typed stat block."),
            E("/npc generate", "A quick NPC from clan, family, school and rank."),
            E("/npc edit | view | list | clone | delete", "Manage stored NPCs."),
            E("/npc template save | spawn | list", "Reusable templates. Spawn several at once."),
            E("/npc place | dismiss", "Put an NPC in a room or take them out."),
            E("/npc say", "Speak as an NPC."),
            E("/letter sendas", "Send a letter as any character."),
        ]),
        Card("Creatures and groups", [
            E("/creature catalog | search | info", "Browse the bestiary."),
            E("/creature spawn", "Make one from a template."),
            E("/creature create", "Build a custom creature."),
            E("/creature wound | heal", "Change its wounds directly."),
            E("/creature attack", "A creature attacks."),
            E("/creature list | view | delete", "Manage spawned creatures."),
            E("/category create | add | bulk_add | list | view", "Group NPCs and creatures."),
            E("/category spawn", "Spawn a whole group."),
        ]),
        Card("Run a fight", [
            E("/combat start | setup", "Begin a fight."),
            E("/combat npc | creature | category | room", "Add your side, or everyone in a room."),
            E("/combat add", "A quick monster from its Reflexes."),
            E("/combat next | board | status | summary", "Run the turn order."),
            E("/combat turn init | hold | delay | act | surprise", "Adjust the order."),
            E("/combat condition set | clear | list", "Dazed, Grappled and the rest."),
            E("/fight env cover | notes | damage", "Terrain and hazards."),
            E("/combat remove | end", "Take someone out, or finish."),
            N("NPC hits are not applied for you. Use `/creature wound`, `/edit wound` or a `/dm damage` card."),
        ]),
        Card("Act for NPCs", [
            E("/fight attack", "An NPC attacks.", "attacker_npc"),
            E("/spell cast", "An NPC casts.", "attacker_npc"),
            E("/spell resist | interrupt | damage", "Resistance, interruption and damage dice."),
            E("/check contest | cooperative", "Contested rolls and team rolls."),
            E("/check skill", "Roll for an NPC. Most checks take the same.", "name is_npc"),
            E("/engage battle start | status | roll | damage | table", "Mass battle."),
            E("/dm craft_extended", "A multi-step crafting project."),
            E("/ref heritage roll", "Roll on a clan's Heritage Table."),
        ]),
        Card("The world", [
            E("/rumor post | public | broadcast", "Send to characters, post a notice, or both."),
            E("/rumor list | delete", "Review and remove."),
            E("/location area create | delete", "Areas and who sees them."),
            E("/location create", "Add a location channel."),
            E("/location area fix-permissions", "Repair visibility."),
            E("/room close", "Close any room."),
            E("/stipend set | view | clear", "Monthly pay per clan."),
        ]),
    ],
)

SHEETS = [PLAYER, STAFF]
ACCENTS = ["#8c1d18", "#2f3e7a", "#2d6a3e", "#8a5a00", "#1f6b73", "#6b2c6b"]


# --------------------------------------------------------------------------- #
# Validation against the live command tree
# --------------------------------------------------------------------------- #
def command_paths() -> tuple[set[str], set[str]]:
    """(every command and group path, the leaf commands only) from the live tree."""
    os.environ.setdefault("DISCORD_TOKEN", "x")
    os.environ.setdefault("DB_PATH", os.path.join(tempfile.gettempdir(), "cheatsheet-check.db"))
    sys.path.insert(0, str(ROOT))
    import logging
    logging.disable(logging.CRITICAL)
    from discord import app_commands
    import bot  # noqa: WPS433 (imported late on purpose)

    paths: set[str] = set()
    leaves: set[str] = set()

    def walk(node, prefix: str) -> None:
        for c in (node.get_commands() if hasattr(node, "get_commands") else node.commands):
            name = f"{prefix}{c.name}".strip()
            paths.add(name)
            if isinstance(c, app_commands.Group):
                walk(c, name + " ")
            else:
                leaves.add(name)

    walk(bot.client.tree, "")
    return paths, leaves


def expand(cmd: str) -> list[str]:
    """'/xp trait | skill' -> ['xp trait', 'xp skill']."""
    first, *rest = [p.strip() for p in cmd.lstrip("/").split("|")]
    words = first.split()
    out = [first]
    for alt in rest:
        out.append(" ".join(words[:-1] + [alt]))
    return out


def validate(paths: set[str], leaves: set[str]) -> list[str]:
    """Names that are not real commands. A group such as `/ref weapon` is fine on its
    own, and one literal after a real leaf command (the 5k3 in `/dice 5k3`) is allowed."""
    bad: list[str] = []

    def ok(p: str) -> bool:
        if p in paths:
            return True
        parent = " ".join(p.split()[:-1])
        return parent in leaves

    for sheet in SHEETS:
        for card in sheet.cards:
            for it in card.items:
                if isinstance(it, E):
                    bad += [f"{sheet.slug}: /{p}" for p in expand(it.cmd) if not ok(p)]
                elif isinstance(it, N):
                    for span in re.findall(r"`(/[a-z_\- ]+)`", it.text):
                        if span.lstrip("/").strip() not in paths:
                            bad.append(f"{sheet.slug} note: {span}")
    return bad


# --------------------------------------------------------------------------- #
# Markdown (Discord-ready: each card is one message under 2000 characters)
# --------------------------------------------------------------------------- #
def md_card(card: Card) -> str:
    lines = [f"## {card.title}"]
    for it in card.items:
        if isinstance(it, E):
            opts = f" {it.opts}" if it.opts else ""
            lines.append(f"- `{it.cmd}{opts}`  {it.text}")
        else:
            lines.append(f"> {it.text}")
    return "\n".join(lines)


def build_md(sheet: Sheet) -> str:
    legend = sheet.legend.replace("Grey words are options.", "Words after a command are its options.")
    head = [f"# Rokugan Bot: {sheet.title}", f"*{sheet.audience}.*", "", sheet.intro, "", f"*{legend}*"]
    parts = ["\n".join(head)] + [md_card(c) for c in sheet.cards]
    return "\n\n---\n\n".join(parts) + "\n"


# --------------------------------------------------------------------------- #
# HTML
# --------------------------------------------------------------------------- #
def inline(text: str) -> str:
    out = []
    for i, chunk in enumerate(text.split("`")):
        out.append(f"<code>{html.escape(chunk)}</code>" if i % 2 else html.escape(chunk))
    return "".join(out)


def html_card(card: Card, accent: str) -> str:
    rows = []
    for it in card.items:
        if isinstance(it, E):
            opts = f' <span class="opt">{html.escape(it.opts)}</span>' if it.opts else ""
            rows.append(
                f'<div class="row"><div class="cmd">{html.escape(it.cmd)}{opts}</div>'
                f'<div class="desc">{inline(it.text)}</div></div>'
            )
        else:
            rows.append(f'<div class="note">{inline(it.text)}</div>')
    return (f'<section class="card" style="--accent:{accent}"><h2>{html.escape(card.title)}</h2>'
            + "".join(rows) + "</section>")


CSS = """
:root { --paper:#f4eddc; --ink:#1e1a15; --muted:#6b6254; --card:#fffdf7; --line:#d8cbb0; }
* { box-sizing: border-box; }
body { margin:0; background:var(--paper); color:var(--ink);
  font-family:"DejaVu Sans","Liberation Sans",system-ui,sans-serif; font-size:21px; line-height:1.35; }
header { background:var(--band); color:#fff; padding:36px 48px 30px; }
header .kicker { font-size:17px; letter-spacing:.14em; text-transform:uppercase; opacity:.8; }
header h1 { margin:6px 0 10px; font-family:"DejaVu Serif",Georgia,serif; font-size:50px; line-height:1.1; }
header p { margin:4px 0 0; font-size:21px; max-width:1300px; }
header p.legend { font-size:18px; opacity:.85; }
header code { background:rgba(255,255,255,.18); color:#fff; }
main { columns:2; column-gap:28px; padding:32px 48px 20px; }
.card { break-inside:avoid; background:var(--card); border:1px solid var(--line);
  border-left:9px solid var(--accent); border-radius:10px; padding:16px 22px 10px; margin:0 0 24px; }
.card h2 { margin:0 0 10px; font-size:26px; color:var(--accent); font-family:"DejaVu Serif",Georgia,serif; }
.row { padding:8px 0 9px; border-top:1px solid #ece3cf; }
.row:first-of-type { border-top:0; }
.cmd { font-family:"DejaVu Sans Mono","Liberation Mono",monospace; font-weight:700; font-size:20px;
  color:var(--accent); overflow-wrap:anywhere; }
.opt { font-weight:400; color:var(--muted); }
.desc { margin-top:2px; font-size:19px; color:#2c271f; }
.note { margin:8px 0 8px; padding:9px 13px; background:#f3ecd9; border-radius:7px;
  font-size:18px; color:#3b362d; }
code { font-family:"DejaVu Sans Mono","Liberation Mono",monospace; font-size:.92em;
  background:#ece3cf; padding:1px 6px; border-radius:4px; }
footer { padding:0 48px 30px; color:var(--muted); font-size:16px; }
@media print { body { font-size:12pt; } main { padding:12pt 24pt; } header { padding:18pt 24pt; } }
"""


def build_html(sheet: Sheet) -> str:
    cards = "".join(html_card(c, ACCENTS[i % len(ACCENTS)]) for i, c in enumerate(sheet.cards))
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rokugan Bot: {html.escape(sheet.title)}</title>
<style>{CSS}</style></head>
<body style="--band:{sheet.accent_band}">
<header><div class="kicker">Rokugan Bot · {html.escape(sheet.audience)}</div>
<h1>{html.escape(sheet.title)}</h1>
<p>{inline(sheet.intro)}</p><p class="legend">{html.escape(sheet.legend)}</p></header>
<main>{cards}</main>
<footer>Generated from the bot's command list. Commands change over time, so <code>/help</code> is the final word.</footer>
<script>document.body.dataset.h = document.documentElement.scrollHeight;</script>
</body></html>"""


# --------------------------------------------------------------------------- #
# PNG via headless Chromium
# --------------------------------------------------------------------------- #
def find_chromium() -> str | None:
    for cand in (
        os.environ.get("CHROMIUM"),
        "/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell",
        "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
        shutil.which("chromium"), shutil.which("chromium-browser"), shutil.which("google-chrome"),
    ):
        if cand and Path(cand).exists():
            return cand
    return None


def render_png(chrome: str, html_path: Path, png_path: Path, width: int = 1600) -> None:
    base = [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
            "--force-device-scale-factor=1"]
    dom = subprocess.run(base + [f"--window-size={width},1200", "--virtual-time-budget=2000",
                                  "--dump-dom", html_path.as_uri()],
                         capture_output=True, text=True, timeout=120).stdout
    m = re.search(r'data-h="(\d+)"', dom)
    height = int(m.group(1)) + 8 if m else 3000
    subprocess.run(base + [f"--window-size={width},{height}", f"--screenshot={png_path}",
                           html_path.as_uri()], capture_output=True, timeout=120, check=True)


def main(argv: list[str]) -> int:
    paths, leaves = command_paths()
    bad = validate(paths, leaves)
    if bad:
        print("Unknown commands in the sheets:\n  " + "\n  ".join(bad))
        return 1
    out_dir = ROOT / "cheatsheets"
    out_dir.mkdir(exist_ok=True)
    chrome = None if "--no-png" in argv else find_chromium()
    for sheet in SHEETS:
        md = build_md(sheet)
        for i, block in enumerate(md.split("\n---\n")):
            if len(block.strip()) > 1900:
                print(f"WARNING: {sheet.slug} block {i} is {len(block.strip())} characters, over a Discord message.")
        (ROOT / f"{sheet.slug.upper()}_CHEATSHEET.md").write_text(md)
        page = out_dir / f"{sheet.slug}.html"
        page.write_text(build_html(sheet))
        if chrome:
            render_png(chrome, page, out_dir / f"{sheet.slug}.png")
        print(f"built {sheet.slug}: {sum(1 for c in sheet.cards for i in c.items if isinstance(i, E))} commands")
    if not chrome and "--no-png" not in argv:
        print("No Chromium found, skipped the PNGs. Set CHROMIUM=/path/to/chrome to enable them.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
