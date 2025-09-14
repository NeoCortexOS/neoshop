
# neoshop_context7.md
Last updated: 2025-09-14  
Session: 2025-09-14 (M6)  
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

## 🎯 Next Milestone – Multi-User Sync (M7)
| Work Item | Risk | Notes |
|-----------|------|-------|
| REST/JSON sync client | 2 | `HTTPRequest` wrapper, auth key in Setup |
| VPS docker image | 1 | Alpine + SQLite + lightweight Go or Python service |
| Timestamp schema | 2 | `item.updated_at INTEGER`, `category.updated_at INTEGER` |
| Last-write-wins merge | 3 | Conflict window ≤ 1 s acceptable for family use |
| On-demand export/import file | 1 | Keep existing `BackupManager` as offline fallback |
| GDPR disclaimer | 1 | Add in-app notice “for private family use only” |

---

## 🔧 Quick-start Cheat-sheet for AI Assistants (updated)
- **Database singleton**: `DB` (already autoload)  
- **Locale switch**: `LocaleHelper.set_locale("de")`  
- **Price display**: `price_cents / 100.0` → `"%.2f €"`  
- **Boolean storage**: SQLite 0/1 ↔ GDScript `bool`  
- **Signals**: always connect in `_ready()` or `_refresh()` loop  
- **Item data dict**: `id, name, amount, unit, description, category_id, needed, in_cart, last_bought, price_cents, on_sale`  
- **Multi-user auth key**: stored in `config` table under `"sync_key"` (plain text, family-shared)

---

## 📝 Privacy Note
Neoshop is designed for **private family or household groups**. Do not host the sync server for public use without adding TLS, rate-limiting, and full GDPR data-processing agreements.

## Git commands to commit & push

# stage the new context file
git add neoshop_context7.md

# optional: stage all other changed/new files
git add -A

# commit
git commit -m "docs: add neoshop_context7.md summarising M6 tint-panel & theme polish; announce M7 multi-user sync milestone"

# push (assumes main branch and origin remote)
git push origin main
