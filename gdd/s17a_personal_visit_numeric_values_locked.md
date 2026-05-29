## 17a Personal Visit Numeric Values — LOCKED

This section formalises the disposition and honor consequences for visit refusals and
uninvited arrivals. GDD s17 describes these effects qualitatively ("small disposition
cost", "significant", etc.) without numeric values.

---

### Source Derivation

**GDD text (s17):**
> "Declining an invitation carries a small disposition cost toward the inviter."
> "Refusing after accepting an invitation is a significant social violation — the
>   host loses both disposition and Honor."
> "Arriving uninvited but with letter notice is a lesser breach."
> "Arriving without notice conveys trust and familiarity — a significant goodwill gesture."

**Calibration anchors:**

| Event | Value | Source |
|-------|-------|--------|
| Gossip base damage | −5 | s12.6 (GDD-confirmed) |
| Private insult | −5 / 30 days | s12.6 (GDD-confirmed) |
| Charm critical failure | −3 | s15.4a (locked) |
| Fulfilling a favor | +0.1 Honor | s12.10 (GDD-confirmed) |
| Breaking a minor favor | −0.5 Honor | s12.10 (GDD-confirmed) |
| PUBLIC_PERFORMANCE per-witness | +2 | s12.4 (GDD-confirmed) |

**Design principles:**

"Small" social costs sit at −2 to −3 across the system. "Significant" events sit
at −5 for disposition, −0.5 for Honor. Positive uninvited reception mirrors the
negative significant-penalty scale: if refusing after acceptance costs −5 disp,
graciously receiving the unexpected guest earns +5.

The letter-arrival case (arriving uninvited but with written notice) is between
the two refusal cases — worse than declining an invitation but better than a full
refusal after acceptance.

---

### Values — LOCKED

| Constant | Value | Rationale |
|----------|-------|-----------|
| `DECLINE_INVITATION_DISPOSITION` | −2 | "Small" — mildest breach; invitee was not obligated, merely politely expected. |
| `REFUSE_AFTER_INVITATION_DISPOSITION` | −5 | "Significant" — mirrors Gossip damage; host explicitly gave their word. |
| `REFUSE_AFTER_INVITATION_HONOR` | −0.5 | "Significant Honor loss" — same as breaking a Minor Favor; explicitly breaking a commitment. |
| `REFUSE_LETTER_ARRIVAL_DISPOSITION` | −3 | "Small, but more than declining" — between −2 (no obligation given) and −5 (explicit commitment). |
| `RECEIVE_UNINVITED_DISPOSITION` | +5 | "Significant goodwill" — mirrors the significant-negative scale; host demonstrates genuine warmth. |

---

### Notes

`REFUSE_UNINVITED_DISPOSITION` (the penalty for the host refusing an uninvited guest)
remains 0. GDD s17 is silent on this case; an uninvited guest can be turned away
without social consequence to the host.

`INTIMATE_SETTING_BONUS` (+3) and `DAILY_AP_DURING_VISIT` (2) are GDD-confirmed
(s17.2 and s14.1 respectively) and unchanged.
