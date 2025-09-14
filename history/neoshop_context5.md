
```markdown
# neoshop_context5.md
Last updated: 2025-09-02  
Project: Neoshop – Offline-first family shopping list  
Engine: Godot 4.4.1 + GDScript + SQLite 4.5 GDExtension  
Target: Android (primary), tablets / PC supported  
License: MIT

---

## ✅ Milestone 4 – Shopping Mode – COMPLETE
- **Unified gesture system**: single `MainLine` touch handler  
  – tap → toggle `needed` (planning) or `in_cart` (shopping)  
  – long-press (0.6 s) → open `ItemEditor`  
  – scroll threshold 15 px to avoid conflicts  
- **Shopping mode toggle** keeps search & category filters enabled  
- **Visual states**: cart icon, gray-out + semi-transparent strike-through when `in_cart = true`

---

## 📦 Complete File Map (`tree -L 3 res://`)
```
res://
├─ db/
│  ├─ database.gd          # SQLite 4.5 singleton (autoload: **DB**)
│  └─ migration.gd         # schema v0→v2, WAL, FTS5 ready (schema hard-coded)
├─ ui/
│  ├─ planning_screen.tscn/.gd  # renamed from PlanningScreen.gd
│  ├─ item_row.tscn/.gd         # gesture-driven item widget
│  ├─ item_editor.tscn/.gd      # CRUD popup
│  ├─ category_editor.tscn/.gd  # CRUD categories
│  └─ settings.tscn/.gd         # stub (to be replaced)
├─ scripts/
│  ├─ seed_manager.gd         # sample data + progress dialog
│  └─ (next: I18nHelper.gd)
├─ themes/
│  ├─ material.tres
│  ├─ material_light.tres
│  └─ material_dark.tres
├─ icons/
│  ├─ checkmark.png
│  └─ cart.png
└─ assets/i18n/
   ├─ en.csv   (to be created)
   └─ de.csv   (to be created)
```

---

## 🗄️ Database Schema – Embedded in migration.gd
**Current version: 2**

```sql
-- Migration 0→1
CREATE TABLE category (
	id   INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT UNIQUE
);

CREATE TABLE item (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	name        TEXT NOT NULL,
	amount      REAL,
	unit        TEXT,
	description TEXT,
	category_id INTEGER REFERENCES category(id),
	needed      BOOLEAN DEFAULT 0,
	price_cents INTEGER,
	on_sale     BOOLEAN DEFAULT 0
);

-- Migration 1→2
ALTER TABLE item ADD COLUMN in_cart    BOOLEAN DEFAULT 0;
ALTER TABLE item ADD COLUMN last_bought INTEGER;
```

---

## 🎯 Next Milestone – Settings & I18N
| Work Item | Risk | Notes |
|-----------|------|-------|
| Setup screen (theme + language) | 2 | New scene `setup_screen.tscn` |
| Tools screen (import/export/seed) | 2 | Re-use `seed_manager.gd` |
| German translation | 1 | CSV + `tr()` wrapper |

---

## 🌐 I18N CSV Format (UTF-8, “;” delimiter)
```csv
keys;en;de
APP_TITLE;Neoshop;Neoshop
ADD_ITEM;Add Item;Artikel hinzufügen
NEEDED;Needed;Benötigt
IN_CART;In Cart;Im Wagen
SETTINGS;Settings;Einstellungen
THEME;Theme;Design
LANGUAGE;Language;Sprache
EXPORT_DB;Export Database;Datenbank exportieren
IMPORT_DB;Import Database;Datenbank importieren
SEED_SAMPLE;Seed Sample Data;Beispieldaten einfügen
```

---

## 🧪 Unit-test Stubs (GUT)
```
res://test/
├─ test_gesture_detection.gd
├─ test_i18n_keys.gd
└─ test_database_integrity.gd
```

---

## Decision Log
- Gesture system: single `MainLine` touch handler – risk 2 – accepted.  
- Theme switching: runtime `Theme` resource swap – risk 2 – accepted.  
- Language switch: immediate via `OS.set_locale()` + restart-less reload – risk 1 – accepted.

---

## 🔧 Quick-start Cheat-sheet for AI Assistants
- **Database singleton**: `DB` (already autoload)  
- **Node references**: use `%UniqueName` pattern  
- **Price display**: `price_cents / 100.0` → `"%.2f €"`  
- **Boolean storage**: SQLite 0/1 ↔ GDScript `bool`  
- **Signals**: always connect in `_ready()` or `_refresh()` loop  
- **Item data dict**: `id, name, amount, unit, description, category_id, needed, in_cart, last_bought, price_cents, on_sale`

```
