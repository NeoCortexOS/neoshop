```markdown
# Neoshop – Single Source of Truth
Offline-first shopping list for family & friends.  
Built with Godot 4.x → Android (primary), tablets/PC supported.  
MIT license; open-source repo on GitHub.

# godot-sqlite 4.5 (Asset-Lib) – tested on Godot 4.4.1

## 1. Data Model (SQLite)
```sql
CREATE TABLE item (
	id          INTEGER PRIMARY KEY,      -- unix epoch ms
	name        TEXT NOT NULL,
	amount      REAL,
	unit        TEXT,
	description TEXT,
	category_id INTEGER REFERENCES category(id),
	needed      BOOLEAN DEFAULT 0,
	in_cart     BOOLEAN DEFAULT 0,
	last_bought INTEGER,
	price_cents INTEGER,
	on_sale     BOOLEAN DEFAULT 0
);

CREATE TABLE category (
	id   INTEGER PRIMARY KEY,
	name TEXT UNIQUE          -- user-entered, not translated
);

CREATE TABLE shop (
	id         INTEGER PRIMARY KEY,
	name       TEXT UNIQUE,
	sort_order TEXT          -- comma-separated category ids
);

CREATE TABLE config (
	key   TEXT PRIMARY KEY,
	value TEXT
);
```

## 2. Core Features (MVP)
• Add / edit / delete items  
• Multiple named lists (implicit: one household = one list)  
• Planning mode: alphabetical sort, search & filter by category  
• Shopping mode: pick shop → show only relevant categories, sort by shop.sort_order, move in_cart items to bottom  
• Offline first; optional post-planning sync via tiny REST server or JSON export/import

## 3. UI Rules
• Row height ≈ 40 px → ~15 rows visible on phone  
• Item row layout (HBox):  
  – 40×40 TextureButton left:  
	• top line = amount, bottom = unit  
	• background texture toggles needed / in_cart / normal  
  – Remaining space:  
	• name (biggest, 3-line wrap)  
	• category (smaller font, max “Haushaltswaren”)  
	• price right-aligned, 12.34 €, shrink or wrap >99.99  
  – Optional description below row (2-line wrap, hidden if empty)  
• Long-press row → edit dialog  
• Settings screen: lines-per-screen, theme colors, language (.po), server URL, user, pass  
• Light & dark themes via Godot Theme resource; Material-ish look

## 4. Localization
• UI strings via gettext `.po` files  
• Symbols preferred for buttons  
• Article & category names NOT translated

## 5. Sync / Backup
• JSON export/import (entire DB) via file picker / share  
• Optional Dockerized Flask server (`POST /sync`) with HTTP basic auth  
• One-way merge after planning; live sync TBD

## 6. Dev & Release
• Godot 4.x, GDScript, SQLite via GDExtension  
• GitHub Actions: tag `v*` → build signed release APK  
• Repo root: `neoshop_context.md` always up-to-date
```
