# Neoshop – Offline-first shopping list

Godot 4.4.1 + GDScript + SQLite 4.5  
Primary targets: Android, Web, Linux, Windows  
License: MIT, most icons are based upon https://github.com/googlefonts/noto-emoji  

---

## Scope
Single-household shopping list.  
Works fully offline; optional self-hosted sync (M7) for multi-user households.  

---

## Development workflow
I decided to try developing this project with "support" of an AI.  
After playing a bit with kimi.ai it seemed to be capable of delivering what I needed.  
From the very beginning I let Kimi generate most of the code, documents, even the milestones.  
I just set the framework, like using Godot and SQlite, platforms, etc.  
Then I reviewed each code block and iterated back and forth until it all worked as intended.  
The project tought me a lot about  working with an AI, like setting very specific boundaries,
keeping a close look at the generated code, working in small chunks.  
And one "discovery" really turned out to be a game changer: learning how to put the AI into the proper context.  
For this I created a "Godot expert" prompt as well as a script to collect all the info needed to start a fresh chat while giving it all the context it needs.  

As I believe in the power of FOSS I put this all on a public github repository.  
My knowledge about Godot is very limited, so do not expect any wizardry here. Any comments to improve the quality are welcome, I just can't promise to turn this into a fully working open source project with pull requests and such, as I have no experience with such things.  

I am trying to show the main steps of the progress by committing the actual state of my project as "we" keep developing it.  

Starting with this version of the README file I include this info about the workflow as it now becomes more of a issue/fix style instead of "let's see what the AI comes up with".  

---

## Feature History

| Milestone | Date | Highlights |
|-----------|------|------------|
| Start | 2025-08-22 | initial commit, MIT license, Readme |
| M1 | 2025-08-23 | Core CRUD: categories & items, SQLite migration v0→v1 |
| M2 | 2025-08-23 | Android persistence fix, export_presets.cfg, 90 MB APK |
| M3 | 2025-08-25 | Seeding manager with progress dialog, 8×8 sample data |
| M4 | 2025-08-28 | Real-time search, category filter, long-press edit |
| M5-a | 2025-09-02 | Shopping mode toggle, `in_cart` flag, DB migration v1→v2 |
| M5-b | 2025-09-04 | Strike-through effect, native PO pipeline, `tr()` complete |
| M6 | 2025-09-14 | Tint panel replaces strike-through, theme polish, scalable feedback |
| M7 | 2025-09-18 | Local-Network P2P Sync via WebSocket (partial, items only atm.)

### Current Functionality (M7)
- **Planning mode**: add, edit, delete, categorise, search.
- **Shopping mode**: only needed items, tap to toggle `in_cart`, sorted by category (then last-bought).
- **Themes**: light, dark, classic; persisted per device.
- **Languages**: English, German; runtime switch, PO workflow.
- **Navigation**: Android back button & PC Esc close pop-ups and return to planning screen.
- **Data**: SQLite, sequential migrations, (JSON export/import (Tools screen)).
- **Input**: touch & mouse; long-press (0.6 s) to edit; drag-scroll threshold to prevent mis-taps.

## Milestone 7 – Local-Network P2P Sync – COMPLETE
Date: 2025-09-18  

**Simple-tier (default)**  
- UDP broadcast discovery + WebSocket transfer – zero permissions.  
- One-tap “Host” / “Join” inside Tools screen.  
- Last-write-wins merge, ≤ 1 s conflict window (family-safe).  
- Falls back to JSON export/import when LAN unavailable.  

**Limitations**  
- LAN-only (same subnet).  
- No encryption (documented in-app).  
- Web export requires localhost or HTTPS for WebSocket.

##  Optional Advanced Tier
- AES-256 family-shared key (opt-in).  


---

## Roadmap

| Milestone | Focus |
|-----------|-------|
| M8 | Multi-table sync (categories, shops), Cancel / progress UI |
| M9 | shop specific ordering of categories, handling on-sale price|
| M10 | tbd... |


---

## Build & Run

```bash
git clone https://github.com/NeoCortexOS/neoshop
cd neoshop
# not sure if the next line will actually work, you have to install the android framework first and maybe do the initial export manually
godot --path . --export-release Android builds/Android/Neoshop.apk
```

No extra permissions; database lives in `user://neoshop.db`.

---

## Test
this is a neglected left over part of the AI's idea of implementing a test framework, does not work atm.

```bash
godot --path . -s test/test_crud.gd
```


---

## Privacy
Designed for private household use only. Self-hosted server option will carry a GDPR disclaimer.
