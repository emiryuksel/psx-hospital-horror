# Level Layout — St. Véronique Memorial Hospital

## Overview

Single-floor hospital core + basement + restricted upper technical level. The building is isolated by **the Mist** — windows show only grey-white void. Progression is **metroidvania-lite**: keys, codes, and restored power unlock new wings.

```
                    [ROOF / HELIPAD — Final Area]
                              |
                    [TECHNICAL LEVEL — 3F]
                              |
    [ADMIN / ARCHIVE] ——— [MAIN CORRIDOR HUB] ——— [EMERGENCY]
            |                      |                      |
      [STAFF LOUNGE]         [PATIENT WING]         [TRIAGE]
            |                      |                      |
                         [OPERATING BLOCK]
                              |
                    [BASEMENT / MORGUE]
                              |
                      [MAIN LOBBY — Start]
```

---

## Areas

### 1. Main Lobby (Start)
- **Purpose:** Tutorial space, establish Mist, first inner-voice beat.
- **Connections:** Front doors (sealed by Mist), corridor to Patient Wing, elevator (inactive), stairwell down.
- **Locks:** None at start. Basement stair blocked by debris until **Maintenance Key** (Admin).
- **Notes:** Reception desk, overturned chairs, flickering emergency lights.
- **Blockout (prototype):** Interior ~14×12 m, ceiling 3.2 m. North corridor stub 7 m × 3.2 m. See `scenes/levels/lobby.tscn`.

### 2. Patient Wing Corridor
- **Purpose:** Core exploration, first enemy encounter (Type A swarm risk).
- **Connections:** Lobby, 4–6 patient rooms (2 lootable), Nurse Station, Operating Block.
- **Locks:** Nurse Station requires **Nurse Station Keycard** (Triage). One patient room locked until **Room 7 Code** (note in Archive).
- **Notes:** Gurneys, IV stands, blood trails that may or may not lead anywhere useful.

### 3. Nurse Station
- **Purpose:** Safe-ish hub after keycard; save point candidate; herb/ammo stash.
- **Connections:** Patient Wing only.
- **Locks:** Keycard.
- **Notes:** Medicine cabinets, patient board with redacted names.

### 4. Emergency / Triage
- **Purpose:** Early combat pressure, supplies scarce.
- **Connections:** Main hub, side entrance to Loading Bay (blocked until power).
- **Locks:** Triage shutter opens after **Generator Partial Power** (basement).
- **Notes:** Abandoned ambulance bay visible through Mist-choked glass.

### 5. Operating Block
- **Purpose:** Mid-game setpiece; Type B first appearance (scripted, avoidable).
- **Connections:** Patient Wing, sterile corridor to Basement lift.
- **Locks:** OR Suite requires **Surgeon's Tag** (Staff Lounge).
- **Notes:** Still-warm equipment implied; one operating table stained.

### 6. Staff Lounge
- **Purpose:** Lore, Maintenance Key, humanizes staff before horror.
- **Connections:** Admin wing, hidden door to Operating (Surgeon's Tag).
- **Locks:** Admin door needs **Archive Clerk Key**.
- **Notes:** Coffee cups, dated newspapers (dates contradict each other).

### 7. Admin / Archive
- **Purpose:** Lore dense; Room 7 code; protagonist past hints.
- **Connections:** Staff Lounge, Main hub side door.
- **Locks:** Clerk Key in Emergency locker.
- **Notes:** Filing cabinets, microfilm reader (decorative interact).

### 8. Basement / Morgue
- **Purpose:** Darkest area; generator; Mist seems to "breathe" here.
- **Connections:** Stairwell from Lobby, lift from Operating.
- **Locks:** Generator room cage → **Basement Key** (OR Suite).
- **Notes:** Cold storage, toe tags with familiar handwriting (unreliable).

### 9. Technical Level (3F)
- **Purpose:** Late game; HVAC / Mist source implied never confirmed.
- **Connections:** Elevator (full power), roof access.
- **Locks:** Elevator after **Full Power + Override Code** (three fragments).
- **Notes:** Cables, fans, something organic fused with ductwork.

### 10. Roof / Helipad (Final)
- **Purpose:** Final choice / Mist ending (see `ending-outline.md`).
- **Connections:** Technical only.
- **Locks:** Roof door from Technical.
- **Notes:** Helipad lights dead; Mist wall at edge; distant shapes move.

---

## Progression Gates (Summary)

| Gate | Unlocks |
|------|---------|
| Maintenance Key | Basement stairs |
| Generator (partial) | Triage shutter |
| Nurse Station Keycard | Nurse hub, meds |
| Archive Clerk Key | Admin / Archive |
| Surgeon's Tag | Operating Suite |
| Basement Key | Generator cage |
| Full Power + Override | Elevator, 3F |
| Roof access | Final sequence |

---

## Design Rules

- No outdoor playable space until final roof (still surrounded by Mist).
- Backtracking is intentional but shortcuts open (elevator, OR lift).
- Each wing should have **one** memorable landmark for navigation in low-res PSX visuals.
