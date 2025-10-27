
# neoshop_context8.md
Last updated: 2025-10-06
Session: 2025-10-06 (M8)  
Project: Neoshop – Offline-first family shopping list (moving toward multi-user sync)  
Engine: Godot 4.4.1 + GDScript + SQLite 4.5 GDExtension  
Target: Android (primary), tablets / PC / Web supported  
License: MIT

---

## ✅ Milestone 6 – Tint Panel & Theme Polish – COMPLETE
Changes since 2025-09-04 (M5-b → now):

1. **Strike-Through Replaced by Tint Panel**  
   - Removed `_draw()` strike-through logic in `ItemRow`.  
   - Added `inCartPanel` (semi-transparent green) that becomes visible when `in_cart = true` in shopping mode.  
   - Simpler shader-free implementation, saves one draw call per row, works on Web GLES2.

2. **Theme Refinements**  
   - `material_light.tres`, `material_dark.tres`, `material_classic.tres` updated:  
	 – `CategoryLabel` variation added (smaller font, 50 % opacity).  
	 – `PanelContainer` now uses 8 px rounded corners for consistency.  
   – Icon colors harmonised with tint panel green (`#00bb00 @ 50 %`).

3. **UI Micro-Fixes**  
   – `ItemRow` feedback tween detached from layout flags (scale animation no longer triggers re-flow).  
   – Long-press timer guard added to prevent spurious edit while scrolling.

4. **GDScript Hardening**  
   – Explicit `int()` casts on `category_id` comparisons (static analyser warning clean).  
   – `ItemRow.set_shopping_mode()` now re-uses `update_from_item()` to avoid code duplication.

---

## 📦 Added / Changed Files (diff summary)
M  res://ui/item_row.gd                 – strike-through removed, tint panel logic
M  res://ui/item_row.tscn               – inCartPanel node added
M  res://themes/*.tres                  – corner radius, CategoryLabel variation
M  res://ui/planning_screen.gd          – category_id cast fix

---

## M7 – Local-Network P2P Sync – COMPLETE (simple-tier)

Date: 2025-09-18  
Engine: Godot 4.4.1 + GDScript + SQLite 4.5  
Target: Android (primary), Linux, Windows, macOS, Web (localhost only)

### What shipped
- **UDP broadcast discovery** on port 5678 (RFC-1918 IPv4 only).  
- **WebSocket data transfer** on port 8090 (TCP, no encryption).  
- **Last-write-wins** merge – dirty rows streamed as newline-delimited JSON.  
- **One-tap sync**: Host → Join → automatic import → mark clean.  
- **Zero platform permissions** – uses only Godot-built-in sockets.  
- **Fallback preserved** – JSON export/import still available.

### Limitations (documented)
- **LAN-only** – both devices must be on the same subnet.  
- **No encryption** – family trust model, documented in-app.  
- **Last-write-wins** – conflict window ≤ 1 s acceptable for household use.  
- **Web export** requires **secure context** (localhost or HTTPS) for WebSocket.

### Files added / changed
- `autoload/p2p_manager.gd` – discovery + transfer engine  
- `ui/tools_screen.gd` – Host / Join buttons + discovered list  
- `ui/tools_screen.tscn` – HostButton, JoinButton, DiscoveredList  
- `project.godot` – P2PManager autoload

### Risk rating: 2  
- Works air-gapped, no external binaries, no crypto.  
- Falls back to JSON export/import if LAN unavailable.

## M7-bis – TCP Reliability Hardening  
Date: 2025-09-25  
Symptom: “ACK timeout page 0” although client logged ACK sent  
Cause: Host closed socket while client ACK still in TCP send buffer  
Fix:  
- set_no_delay(true) on accepted peer  
- Host waits 200 ms after last page before close  
- Client yields 1 frame after ACK to push Godot→kernel  
Risk: 1 – LAN-only timing tweak, no crypto change  

## 🔧 Quick-start Cheat-sheet for AI Assistants (updated)
- **Database singleton**: `DB` (already autoload)  
- **Locale switch**: `LocaleHelper.set_locale("de")`  
- **Price display**: `price_cents / 100.0` → `"%.2f €"`  
- **Boolean storage**: SQLite 0/1 ↔ GDScript `bool`  
- **Signals**: always connect in `_ready()` or `_refresh()` loop  
- **Item data dict**: `id, name, amount, unit, description, category_id, needed, in_cart, last_bought, price_cents, on_sale`  
- **Multi-user auth key**: stored in `config` table under `"sync_key"` (plain text, family-shared)

## M8 – Category Sync & Soft-Delete UI
Date: 2025-10-27

### What changed
- Database migration v2→v3: added `is_deleted` column; `sync_flag` now purely "dirty" marker.  
- Soft-delete is **synced**: winner = newer `updated_at`; result replicated on both sides.  
- UI: deleted categories/items show **red tint panel** (like green in-cart panel); toggle inside editors.  
- CategoryEditor: **only** modified rows become dirty (fixes "all categories marked dirty").  
- Scroll-position preserved when long-press opening item editor (no mouse-capture leak).  
- Purge job runs on start; rows deleted after `purge_deleted_after_days` (default 3) **and** `is_deleted = 1`.

### Files touched
- `db/migration.gd` – v3 migration  
- `db/database.gd` – purge helpers, `_select_visible`, soft-delete/undelete helpers  
- `scripts/p2p_manager.gd` – send & apply categories with conflict resolution  
- `ui/category_editor.gd` – dirty-tracking, red-tint, save-only-dirty  
- `ui/item_row.gd` / `item_row.tscn` – red `delPanel`  
- `ui/item_editor.gd` – deleted toggle  
- `ui/planning_screen.gd` – scroll-position restore  

### Limitations
- Shops table **not** yet included (deferred M9).  
- LAN-only, no encryption (family trust model unchanged).

### Risk
3 – schema bump; devices **must** open the app once to migrate before syncing with updated peers.

---

## 📝 Privacy Note
Neoshop is designed for **private family or household groups**. Do not host the sync server for public use without adding TLS, rate-limiting, and full GDPR data-processing agreements.

## Git commands to commit & push

# commit
git add -A
git commit -m "feat: M7 local-network P2P sync (UDP broadcast + WebSocket)
- add autoload P2PManager with discovery & transfer engine
- add Host/Join buttons to Tools screen
- implement last-write-wins merge for dirty rows
- fallback to JSON export/import preserved
- zero platform permissions, LAN-only, no encryption (family trust)
- tested Android ↔ Linux, ≤ 1 s conflict window
Risk: 2 – air-gapped, no external binaries"

# push (assumes main branch and origin remote)
git push origin main
