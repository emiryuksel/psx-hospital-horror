# PSX Hospital Horror

A first-person survival horror game set inside **St. Véronique Memorial Hospital** — a place cut off from the world by an impenetrable mist, where memory fails and nothing is quite what it seems.

Built in **Godot 4.7** with deliberate PlayStation-era aesthetics: vertex-snapped geometry, nearest-neighbor textures, heavy fog, and a control scheme that favors tension over comfort.

---

## The Experience

You wake in an abandoned hospital lobby. The front doors open onto grey-white void. Power is dead. Something moves in the corridors.

Exploration, scarce resources, and deliberate combat carry you through a single-floor hospital core, a basement morgue, and a restricted technical level above. Progression is metroidvania-lite: keys, codes, and restored power unlock new wings. Backtracking is intentional. Shortcuts open as you learn the building.

The story never fully explains the mist. Notes contradict each other. An inner voice questions what you think you know. There is no clean ending — only choices that may or may not mean escape.

---

## Setting

**St. Véronique Memorial Hospital** is isolated by **the Mist** — not weather, not a chemical leak, something else entirely. Windows show only void. The building breathes in the basement. Dates on newspapers do not agree.

### Playable Areas

| Area | Role |
|------|------|
| Main Lobby | Starting space, tutorial beats, first inner-voice moment |
| Patient Wing | Core exploration, first enemy encounters |
| Nurse Station | Safe hub, save candidate, medical supplies |
| Emergency / Triage | Early combat pressure, scarce ammo |
| Operating Block | Mid-game setpiece, first Brute appearance |
| Staff Lounge | Lore, key items, humanizing detail |
| Admin / Archive | Dense narrative, access codes, protagonist hints |
| Basement / Morgue | Darkest zone, generator puzzle, mist density |
| Technical Level (3F) | Late game, HVAC ducts, implied mist source |
| Roof / Helipad | Final sequence and ending choice |

### Progression Gates

| Gate | Unlocks |
|------|---------|
| Maintenance Key | Basement stairs |
| Generator (partial) | Triage shutter |
| Nurse Station Keycard | Nurse hub, medicine |
| Archive Clerk Key | Admin / Archive |
| Surgeon's Tag | Operating Suite |
| Basement Key | Generator cage |
| Full Power + Override | Elevator, 3F |
| Roof access | Final sequence |

---

## Enemies

### Type A — Crawler

A human-sized silhouette bent wrong. Fast, flanking, swarm-capable. Prefers closets, under beds, behind curtains. Low damage per hit, high psychological pressure. Common in Patient Wing and Emergency; rare pairs in the Basement.

### Type B — Brute

Two and a half times human height. Blocks corridors. Heavy footsteps telegraph its approach. High damage, poor turning — juke into side rooms. Scripted first appearance in Operating Block. Two to three encounters across the full game.

Both enemies use a state machine (Idle → Patrol → Alert → Chase → Attack) with line-of-sight detection, last-known-position search, and fog-aware presentation. Silhouette and audio sell the threat more than polygon count.

---

## Gameplay Systems

### Movement & Feel

First-person controller with deliberate, weighty movement. Walk, sprint with stamina drain, crouch, head bob, and mouse-look. Sprinting is audible — enemies respond to sound.

### Combat

Melee (combat knife) and ranged (9mm pistol) weapons. Aim, fire, reload. Health and damage components shared between player and enemies. Muzzle flash, blood splat, and damage vignette feedback.

### Inventory

Slot-based inventory with stackable ammo, combinable items (empty magazine + rounds → loaded magazine), keys, herbs, weapons, and readable notes. Pickup items scattered through the level.

### Interaction

Unified interactable framework: doors, locked doors, fuse panels, elevator panels, notes, exit doors, and generic crates. Context prompts via the HUD.

### Flashlight

Battery-powered flashlight with drain and visual indicator. Essential in unlit wings after power failure.

### Quest & Objectives

Part I quest flow: find a weapon, locate the generator fuse, restore lobby power, reach the exit. Objective text updates through `QuestManager` as state changes.

### Inner Voice

Environmental trigger zones deliver unreliable narrator lines — commentary that undermines certainty rather than guiding the player.

### Save System

Quick save (F5) and quick load (F6). Persistent state for inventory, quest progress, door locks, and player position. Save data applied on scene load.

### Audio

Procedural placeholder SFX for footsteps, gunfire, knife swings, doors, pickups, enemy alerts, heartbeat, and ambient drone. Managed through a central audio autoload.

---

## Visual Identity

### PSX Rendering Pipeline

- Custom `psx_lit.gdshader` — view-space vertex snapping for authentic wobble without seam jitter between adjacent meshes
- Nearest-neighbor texture filtering project-wide
- `PsxMaterialHelper` for consistent surface assignment
- `PsxSurfaceTextures` autoload for hospital material presets (floor, wall, ceiling, metal, wood, door)
- Fog tuned per level for mist atmosphere
- Pixel-font HUD labels via `PixelLabel` autoload

### HUD

Native pixel-art HUD: health hearts, stamina bolt, flashlight battery tiers, crosshair, interaction prompts, objective text, and message overlay. Pause menu and inventory UI as separate scenes.

---

## Project Structure

```
psx-hospital-horror/
├── autoload/           # Global singletons (save, inventory, quest, audio, HUD, PSX settings)
├── assets/
│   ├── audio/          # Ambient and SFX (WAV)
│   ├── models/         # GLB import slots for hospital props and enemies
│   └── textures/       # Hospital surfaces, props, weapons, HUD, FX
├── design/             # Level layout, enemy design, narrative, endings, inner-voice lines
├── resources/items/    # Item resource definition
├── scenes/
│   ├── enemies/        # Enemy prefabs
│   ├── levels/         # Lobby, asset showcase
│   ├── player/         # Player rig
│   ├── test/           # Phase 1 test room
│   └── ui/             # Main menu, HUD, inventory, pause, note reader
├── scripts/
│   ├── combat/         # Health and combat components
│   ├── components/     # PSX mesh root, inner-voice zones
│   ├── enemies/        # Enemy AI state machine
│   ├── interaction/    # Doors, panels, pickups, interactables
│   ├── inventory/      # World pickup items
│   ├── levels/         # Level builders (lobby blockout, part 1)
│   ├── player/         # Controller, flashlight
│   └── ui/             # Menu and HUD scripts
├── shaders/            # PSX lit spatial shader
└── tools/              # Texture generation scripts (PowerShell)
```

---

## Controls

| Action | Key |
|--------|-----|
| Move | W A S D |
| Sprint | Shift |
| Crouch | Ctrl |
| Interact | E |
| Flashlight | F |
| Inventory | Tab |
| Fire | Left Mouse |
| Aim | Right Mouse |
| Reload | R |
| Melee weapon | 1 |
| Ranged weapon | 2 |
| Quick Save | F5 |
| Quick Load | F6 |

---

## Requirements

- **Godot Engine 4.7** (Forward Plus renderer)
- Windows, macOS, or Linux

---

## Getting Started

1. Clone the repository.
2. Open the project folder in Godot 4.7.
3. Press **F5** or click **Play** — the main menu loads `scenes/ui/main_menu.tscn`.
4. Start a new game to enter the lobby blockout (`scenes/levels/lobby.tscn`).

> **Note:** Enemy model folders under `assets/models/` are prepared for GLB import. Current enemies use placeholder geometry in the test scene.

---

## Development Status

Active prototype. Part I (lobby power restoration and exit) is playable. Level blockout, combat, inventory, save/load, PSX rendering, and core interaction systems are in place. Full hospital wing expansion, enemy model integration, and ending sequences are in progress.

Design documentation lives in `design/` — level layout, enemy specifications, collectible narrative fragments, inner-voice script, and ending outline.

---

## License

**All Rights Reserved.** This project is proprietary. No use, modification, or distribution is permitted without explicit written consent from the copyright holder. See [LICENSE](LICENSE) for full terms.

---

## Author

**Emir Yüksel**
