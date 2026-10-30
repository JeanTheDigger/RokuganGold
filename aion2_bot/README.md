# Aion 2 Discord Bot

A Discord bot for an Asmodian faction Discord server in **Aion 2** (NCSoft's MMO):
arrivals, approval tickets for Legion commanders and Legion members, a live siege
countdown and a Faction Commander election for every siege.

> **This folder is a completely separate project.** It shares no code with the
> Godot / GDScript game in this repository, and none with the Rokugan L5R bot
> in `../discord_bot/`. Nothing here imports from, or is imported by, anything
> outside this folder.

- `.gdignore` keeps the Godot editor from scanning or importing this folder.
- `.gitignore` keeps the bot token (`.env`) and the database (`aion2.db`) out of git.

## The server

| Category | Who sees it | Channels |
|---|---|---|
| **Welcome** | everyone, including people with no role | `#arrivals` (read-only: the bot posts "**Name** entered the server."), `#chat` (anyone can talk), `#commander-applications` and `#member-applications` (read-only, each holds an apply button) |
| **Asmodian Command** (*draft name*) | approved commanders and members, Head Admin | `#general`, `#questions`, `#memes`, `#screenshots`; `#siege-timer`, `#faction-commander` and `#siege-alerts` (only the bot posts); 🔊 **War Room** (everyone approved listens, only the Faction Commander speaks); 🔊 **Voice 1–5** (open voice chat for everyone approved) |
| **Faction Command** (*draft names*) | the current Faction Commander and Head Admin | `#fc-head-admin` (Faction Commander ↔ Head Admin), `#faction-leaders` (also every Legion Commander), `#step-down` (the step-down button) |
| **Legions** | Head Admin; each Legion's channel is also open to that Legion | one private channel per approved Legion, made automatically |
| **Tickets** | Head Admin; each ticket is also open to the people in it | one private channel per open application, made automatically |
| **Head Admin** | Head Admin only | `#admin-chat`, `#bot-log` (everything the bot does, plus ticket transcripts), `#siege-control` (the siege control panel), `#legion-control` (the Legion control panel) |

Roles: **Head Admin**, **Legion Commander**, **Legion Member**, **Faction
Commander** (held by the elected shot caller during a siege), **Siege Alerts**
(opt-in, for reminder pings), and one
**Legion: Name** role per approved Legion.

## How applications work

**Legion commander.** In `#commander-applications`, click **Apply as Legion
Commander** and fill in your character name, the name of the Legion you lead,
who you are, and optionally your **Legion's color**: Red, Green and Blue (0–255
each, like `200, 30, 60`) and a brightness from 0 to 100% (100% is the exact
color, lower is darker). A private ticket opens with you and the Head Admin. Only the
Head Admin can approve or deny. Approving approves **the commander and the
Legion together**: the Legion gets its **Legion: Name** role and private
channel, the commander gets **Legion Commander** + that role, and the Legion
now appears in the member application list. If two people claim the same
Legion, the ticket warns the Head Admin; once one is approved, the other cannot
be.

**Legion member.** In `#member-applications`, click **Apply to a Legion**, pick
your Legion from the list of approved ones and fill in your character name. A
private ticket opens with you, the Head Admin and **that Legion's commander**.
**Both** the commander and the Head Admin must click Approve (a person who is
both counts for both). Either may deny. Approved members get **Legion Member** +
their Legion's role, which opens Asmodian Command and their Legion's channel.

**Rules for everyone:**
- One open application at a time, and one Legion per person.
- Nobody can approve their own application.
- A denial can carry a reason. The applicant is told in the ticket and by DM
  (if their DMs are open), and may apply again.
- After a decision the ticket goes read-only for the applicant and commander.
  The Head Admin's **Close ticket** button posts a transcript to `#bot-log`
  and deletes the ticket channel.
- Every button keeps working after the bot restarts.

## Sieges and the Faction Commander

Artifact Sieges run **Monday, Thursday and Saturday at 9 PM Eastern**
(New York time, so it follows daylight saving). The schedule and every
duration below are constants at the top of `schedule.py`.

**`#siege-timer`** holds one message that says when the next siege starts,
in Eastern time and in each reader's own time zone, with a countdown. The bot
edits it every minute. During a siege it also shows that the siege is underway
and who the Faction Commander is.

**`#faction-commander`** runs one election per siege, all on its own:

| When (for a 9 PM siege) | What happens |
|---|---|
| 11 PM after the previous siege (when the previous Faction Commander's term ends) | Applications open. Any approved person (Legion Commander, Legion Member or Head Admin) clicks **Apply**, and can **Withdraw** until the poll opens. Up to 25 applicants. |
| 9 PM the day before (24 h before) | Applications close and the vote opens: a menu with every applicant's name. Each approved person votes **once**, for anyone, themselves included. Votes are **final**. Counts stay hidden until the end. |
| 8:30 PM (30 min before) | Voting ends. Most votes wins, and a tie is broken at random among the tied. The winner gets the **Faction Commander** role. If nobody applied or nobody voted, there is no Faction Commander for that siege. |
| 11 PM (2 h after the start) | The role is removed and applications for the next siege open (also after a skipped siege). |

For the Monday / Thursday / Saturday sieges that means:

| | Monday siege | Thursday siege | Saturday siege |
|---|---|---|---|
| Applications open | Sat 11 PM | Mon 11 PM | Thu 11 PM |
| Vote opens | Sun 9 PM | Wed 9 PM | Fri 9 PM |
| Vote closes, role given | Mon 8:30 PM | Thu 8:30 PM | Sat 8:30 PM |
| Role removed | Mon 11 PM | Thu 11 PM | Sat 11 PM |

A background loop drives this once a minute. If the bot was offline when a step
was due, it does that step as soon as it is back.

**What the Faction Commander role gives.** Access moves with the role, so it
changes hands automatically with each siege and each step-down.
- The **Faction Command** category: `#fc-head-admin`, a private room with the
  Head Admin; `#faction-leaders`, where the Faction Commander talks with every
  Legion Commander; and `#step-down`. History is kept between terms.
- 🔊 **War Room**: a voice channel every approved person can
  join, where only the Faction Commander can speak (with Priority Speaker) and
  type in the channel's text chat. Everyone else listens and reads. (Discord lets anyone with Administrator speak anywhere.)
- **Step down**: the Faction Commander clicks the button in `#step-down` and
  confirms. The bot takes their role and gives it to the **runner-up**: the
  next applicant by votes (zero votes included), ties broken at random, skipping
  anyone who stepped down or left the server. That repeats if the runner-up
  steps down too. With nobody left there is no Faction Commander for the rest of
  the siege. Whoever steps down can't take the role back that siege.

**Head Admin siege controls** live on a button panel in `#siege-control`,
which also shows the current siege, its election and any skipped sieges:

| Button | What it does |
|---|---|
| 👑 **Appoint commander** | Pick any approved person as Faction Commander for the current or next siege. An open vote is cancelled and whoever held the role is replaced. Appointed ahead of time, they get the role when the term begins (30 min before the siege). |
| 🚫 **Remove commander** | Takes the role from the current Faction Commander. The runner-up takes over, exactly like a step-down. |
| ⏭️ **Skip / un-skip a siege** | Pick one of the next 4 sieges. A skipped siege has no vote, no reminders and no Faction Commander, and the countdown says so. Its open vote is cancelled and its role taken back. Pick it again to un-skip. |
| 🗳️ **Cancel vote** | Only while a vote is open: **Restart fresh** (every vote wiped, same applicants, same closing time) or **End with no commander**. |

**`#siege-alerts`** pings the opt-in **Siege Alerts** role. People turn it on or
off with the button at the top of the channel. Each siege it posts:

| When (for a 9 PM siege) | Reminder |
|---|---|
| 9 PM the day before | The Faction Commander vote is open (only if someone applied). |
| 6:30 PM | 2 hours left to vote (only if the vote is open). |
| 8:00 PM | Siege in 1 hour, plus a last call to vote. |
| 8:30 PM | Siege in 30 minutes, and who the Faction Commander is. |
| 8:45 PM | Siege in 15 minutes. |
| 9:00 PM | The siege has begun. |

Each reminder goes out once. If the bot was offline and a reminder is more than
5 minutes late, it is skipped rather than posted stale.

**Legion colors.** A Legion's color is the color of its **Legion: Name** role,
so the commander's and members' names show in it across Discord (the other
roles have no color, so it is the one that shows). The ticket shows the color
the commander asked for, and the bot **warns** (but allows it) when a color is
very close to another Legion's. Pure black counts as "no color" in Discord, so
the bot uses #010101 instead.

## Managing Legions

Each Legion's private channel has a management panel for its **commander**, and
`#legion-control` (Head Admin category) has the same buttons for the **Head
Admin**, who first picks the Legion. The commander or the Head Admin can:

| Button | What it does |
|---|---|
| 🚪 **Remove a member** | Pick a member and confirm. They lose the Legion role, their approval (Legion Member role) and Siege Alerts, and get a DM. They can apply again. Picking the **commander** disbands the Legion (with a warning first). |
| 👑 **Transfer command** | Pick a member of the Legion and confirm. They become commander. The old commander stays on as a regular member. The new commander is added to the Legion's open member tickets, since they must approve them. |
| ✏️ **Rename** | Type the new name. The Legion's role and channel are renamed too. The name must not belong to another Legion. |
| 🎨 **Change color** | Type Red, Green, Blue (0–255) and a brightness (0–100%). The Legion's role takes that color, so its members' names show in it. Leave it blank to remove the color. |
| 🏴 **Disband** | Confirm. Everyone in it loses the Legion role and their approval, its pending member applications are denied, and its channel's transcript goes to `#bot-log` before the channel and role are deleted. |

Automatic:
- A member who **leaves the server** is removed from their Legion and must apply
  again if they come back.
- A **commander** who leaves the server (or is removed) **disbands** the Legion.
- Anyone who loses their approval is taken out of the Faction Commander race.
  If they hold the Faction Commander role, it passes to the runner-up. Only
  approved people can win a vote or take over as runner-up.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/setup server` | Head Admin | Creates the roles, categories and channels from `layout.py`, and posts the apply buttons. |
| `/legion list` | anyone | Lists approved Legions, their commanders and how many are approved in each. |

### `/setup server`

- **Who may run it:** members with the **Head Admin** role. On a brand-new
  server with no Head Admin role yet, the **server owner** may run it once; that
  run creates the role and gives it to the owner. After that only Head Admin may
  run it, the owner included.
- **Safe to re-run.** It only creates what is missing. It never deletes,
  renames, moves or changes the permissions of anything that already exists.
  Channels the bot uses (arrivals, the application rooms, tickets, Legions, the
  log) are remembered by ID, so renaming one by hand is fine. If an apply-button
  message was deleted, re-running posts it again. If setup stops partway, running
  it again picks up where it stopped.
- **To change what setup builds, edit `LAYOUT` in `layout.py`.** Setup checks the
  layout first and refuses to run on a broken one (duplicate names, a missing
  required channel, and so on).

## Running it

1. **Create the bot** at the [Discord Developer Portal](https://discord.com/developers/applications):
   New Application → **Bot** → **Reset Token** and copy the token. On the same
   page, turn on **Server Members Intent** and **Message Content Intent**. The
   bot needs the first to see people join and leave, and the second to save
   what people wrote in ticket and Legion transcripts (without it, their
   messages come out blank). It won't start until both are on.
2. **Invite it:** OAuth2 → URL Generator → scopes `bot` and `applications.commands`,
   permission **Administrator**. Open the URL and pick your server. In
   **Server Settings → Roles**, keep the bot's role **above** Head Admin, Legion
   Commander, Legion Member, Faction Commander, Siege Alerts and the Legion roles,
   or it can't hand them out. Administrator also lets it ping Siege Alerts without
   making that role pingable by everyone.
3. **Configure:** copy `.env.example` to `.env` and paste the token. Optionally
   set `DISCORD_GUILD_ID` to your server's ID so commands appear instantly.
4. **Run** (Python 3.10+):
   ```
   pip install -r requirements.txt
   python bot.py
   ```
5. In Discord, the server owner runs `/setup server`.

## Files

| File | Purpose |
|---|---|
| `bot.py` | Entry point: logs in, registers commands and buttons, posts arrivals. |
| `layout.py` | The roles/categories/channels setup builds. Edit this to change the server. |
| `setup_server.py` | The `/setup server` command. |
| `applications.py` | Apply buttons, forms, tickets, approvals, `/legion list`. |
| `schedule.py` | The siege calendar: days, time, time zone, and when each election step happens. |
| `siege.py` | The countdown, Faction Commander applications, the vote and the role. |
| `alerts.py` | Siege reminders and the Siege Alerts on/off button. |
| `controls.py` | The Head Admin siege control panel. |
| `legions.py` | Legion management panels, and cleanup when people leave the server. |
| `roles.py` | Finding roles by name; the bot's own channel permissions. |
| `storage.py` | The SQLite database (`aion2.db`, or the path in `AION2_DB`). |

## Known limits

- Discord allows 50 channels per category, so at most 50 approved Legions and
  50 open tickets at once.
- Discord lets anyone with **Administrator** (Head Admin, by default) post
  anywhere, including the bot-only channels.
- The siege schedule comes from community trackers, not NCSoft. If the game
  changes it, edit `schedule.py`.
