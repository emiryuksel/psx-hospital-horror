# Ending Outline — The Mist Tone

> No clean "good ending." Player may **believe** they escaped; evidence undermines certainty.

---

## Ending A — "Helipad Departure" (Primary)

### Setup
- Player restores power, reaches roof, optional inner-voice: *"Don't open the doors."*
- Helipad: Mist wall at edge; distant rumbling; radio crackle (no clear voice).

### Player Choice
1. **Step into the Mist** (only interactable) — fade to white-grey.
2. **Wait at helipad** — Mist slowly advances; forced into choice after 60s.

### Resolution (Subtitle Epilogue — not voiced)

```
The lights below went out one by one.
You walked until the ground forgot you.

Somewhere, a chart still lists your name.
Admit date: tomorrow.
```

**Implication:** Escape uncertain — may be walking in circles, dead, or becoming part of the Mist. No helicopter ever confirmed.

---

## Ending B — "Containment Door" (Alternate / Hidden)

### Setup
- In Technical Level, player finds sealed **containment hatch** (not on critical path).
- Requires optional items: Morgue reel slot + Surgeon journal + Room 7 drawing.

### Player Choice
- Open hatch vs. proceed to roof.

### If Opened
- Red light. Air reverse-sucks. Mist **pulls inward** for 3 seconds.
- Player falls forward — cut to black.

### Resolution

```
You remembered why you came back.
It wasn't to leave.

The mist thinned for a moment.
That was enough.
```

**Implication:** Protagonist may have been complicit in the incident — or the hospital "needed" them inside. Deliberately ambiguous.

---

## Shared Ending Rules

- **No** creature explainer scene.
- **No** rescue team, no credits stinger with clear survival.
- Post-credits optional: single line of static + garbled intercom (same phrase as lobby, looped).

---

## Failure State (Death)

- Standard game over: *"YOU DIED"* (existing HUD).
- Reload from save point or last manual save.
- Optional death line (inner voice, one random):
  - "So this is the room I couldn't remember."
  - "Again. How many times is again?"

---

## Narrative Alignment

| Theme | How Ending Supports It |
|-------|------------------------|
| Unreliable memory | Epilogue contradicts player actions |
| Institutional horror | Hospital records outlive player |
| The Mist | No exterior world shown clearly |
| Hopelessness | No reward for 100% items |

---

## Implementation Notes (Future)

- Ending triggered by `EndingManager` autoload at roof interactable.
- Track `flags` dict: `saw_brute_alive`, `read_personnel_file`, `opened_containment`.
- Ending B only offered if `flags` count ≥ 2 optional truths.
