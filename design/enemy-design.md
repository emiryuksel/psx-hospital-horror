# Enemy Design — Type A & Type B

> Visuals: low-poly, silhouette-first. Mist + PSX fog hide detail. Audio sells threat more than mesh.

---

## Type A — "Crawler" (Swarm Threat)

### Silhouette
- Human-sized **bent wrong**: elongated arms, head tucked low, spine visible as ridge.
- 300–800 tris target. No fingers — mitten-like claws (3 prongs).
- Pale grey-pink albedo; dark joint sockets. No eyes — smooth forehead slope.

### Behavior (State Machine)

| State | Behavior |
|-------|----------|
| **Idle** | Crouched, subtle sway animation (vertex wobble sells twitch) |
| **Patrol** | Short loops in closets, under beds, behind curtains — emerges near player path |
| **Alert** | Head snaps toward sound; 0.5s freeze before chase |
| **Chase** | Fast scramble; prefers flanking; **calls 1–2 others** within 8m (swarm) |
| **Attack** | Leap + slash; low damage (8–12); interruptible |

### Stats (Starting Point)
- HP: 40–60
- Speed: faster than player walk, slower than sprint
- Detection: narrow FOV (90°), good hearing (sprint noise)

### Encounter Zones
- Patient Wing (common)
- Emergency (medium)
- Basement (rare pairs)
- **Not** on roof until final sequence (optional swarm finale)

### Mist Relationship
- Slightly **more aggressive** in high-fog zones (basement).
- At distance, silhouette breaks into fog — player sees movement, not detail.

---

## Type B — "Brute" (Avoid or Burn Ammo)

### Silhouette
- **2.5× human height**, hunched, shoulders wider than door frame.
- 1200–2000 tris. Asymmetric lumps (tumor growths) on one shoulder only.
- Dark crimson/brown; single pale stripe along spine (landmark for aiming).

### Behavior

| State | Behavior |
|-------|----------|
| **Idle** | Back to player often; blocking corridor |
| **Patrol** | Slow, heavy steps — **audio telegraph** 2s before visible |
| **Alert** | Turns slowly; roar cue (subtitle: "Something breathes behind the metal") |
| **Chase** | Relentless but **poor turning** — juke in side rooms |
| **Attack** | Wide swing; 35–50 damage; breaks doors (scripted) |

### Stats
- HP: 200–350
- Speed: walk-speed chase
- Detection: wide FOV (140°), poor hearing

### Encounter Zones
- Operating Block (scripted first — avoid path)
- Morgue (optional mini-boss)
- Technical Level (one blocking duct room)
- **Max 2–3** per full game

### Mist Relationship
- Mist **clings** to Brute mesh (particle/fog multiplier) — appears from fog wall.
- Killing one does not prevent respawn implication in ending (unreliable world).

---

## Shared AI Notes

- Line-of-sight raycast from eye height; Mist does not block LOS (gameplay clarity).
- Last known position search 4–6 seconds before patrol resume.
- Damage flash: brief albedo shift (existing `EnemyAI` pattern).
- Death: collapse + dissolve into fog (no gore mesh swap in prototype).

---

## Asset Integration (FAZ 2.5)

| Enemy | Folder | Format |
|-------|--------|--------|
| Type A | `assets/models/enemies/crawler/` | `.glb` preferred |
| Type B | `assets/models/enemies/brute/` | `.glb` preferred |

- Rig optional in prototype; root motion not required.
- Collision: capsule for A, box+capsule for B.
- Materials: auto-assign `PsxMaterialHelper` via import preset.

---

## Spawn Guidelines

| Area | Type A | Type B |
|------|--------|--------|
| Lobby | 0 | 0 |
| Patient Wing | 2–4 | 0 |
| Emergency | 1–2 | 0 |
| Operating | 0 | 1 (scripted) |
| Basement | 2 | 0–1 |
| Technical | 1 | 1 |
| Roof | 3+ (finale) | 0 |
