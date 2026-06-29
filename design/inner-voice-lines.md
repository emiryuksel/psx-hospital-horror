# Inner Voice Lines — Protagonist Monologue

> Tone: tense, self-doubting, unreliable. Short lines (1–2 sentences). Subtitle display; no VO required in prototype.

---

## A. Game Start / Waking Up

1. "Where— no. I know this hallway. I don't know *how*."
2. "My head feels like a tape rewound too far. Names won't stick."
3. "The air tastes like copper and rain. When did hospitals smell like that?"
4. "Lights are on. Nobody's here. That's worse than darkness."
5. "I should leave. The doors are right there. …Why can't I remember leaving before?"

---

## B. First Enemy Encounter

1. "That shape— Christ— it was *walking* wrong."
2. "Don't stare. Don't stare. If I don't look at it, maybe it isn't real."
3. "I've seen something like this. In a dream. In a mirror. Not here."
4. "Gun's heavy. Hands aren't mine. Whose hands are these?"
5. "It saw me. I think it *recognized* me."

---

## C. Important Clue / Lore Pickup

1. "This name on the chart… that's not possible. I was never admitted."
2. "The dates don't line up. Nothing here lines up— except my handwriting."
3. "Someone wanted this found. Or someone wanted *me* to find it."
4. "If I remember this place, why does the map feel new?"
5. "The note says 'deceased.' The ink's still wet. Which is the lie?"

---

## D. Low Health / Danger

1. "Breathe. Just breathe. You don't need much blood to keep moving."
2. "Not here. Not in a hallway I might've died in already."
3. "Cold starting at the edges. Is that shock— or the mist?"
4. "If I fall, will I wake up in another room with no memory?"
5. "Hurts. Good. Pain means the story isn't finished yet."

---

## E. Entering Safe / Quiet Area (e.g. Nurse Station after clear)

1. "Quiet. Too quiet. Like the building's holding its breath."
2. "I could rest here. I shouldn't trust anywhere that feels safe."
3. "Coffee's still warm. Someone was here seconds ago. Or years."
4. "Lock the door. Locks never held anything in this place."
5. "For a second, I almost remember why I came back."

---

## F. Contradictory Memory Trigger

1. "I remember her voice. I don't remember her face. Which did I lose first?"
2. "I wasn't here. I was here. Both feel true and both feel like lies."
3. "The photo proves I was standing right there. I don't remember the camera."
4. "They said I died on the 13th. Today's the 14th. …Is it?"
5. "Maybe I'm not trying to escape. Maybe I'm trying to remember how to stay."

---

## Trigger Mapping (Implementation Reference — FAZ 7)

| Trigger ID | Condition | Suggested Line Pool |
|------------|-----------|---------------------|
| `wake_up` | First control after intro | A1–A3 |
| `first_enemy` | First Type A or B sighting | B1–B5 |
| `lore_major` | Fragments 1, 7, 11 | C1–C5 |
| `health_critical` | HP < 25% | D1–D5 |
| `safe_zone` | Enter Nurse Station (cleared) | E1–E5 |
| `memory_glitch` | Fragment 7 or 11 examined | F1–F5 |

---

## Writing Rules

- Never confirm protagonist's identity, guilt, or survival.
- Avoid explaining the Mist in monologue.
- Lines may contradict previous lines across the playthrough.
