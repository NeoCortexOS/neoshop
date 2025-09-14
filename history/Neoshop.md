────────────────────────────────────────
PROJECT.md  (living spec)
────────────────────────────────────────
1. Vision  
   “Offline-first, multi-language shopping list for Android (Godot 4.x) that supports post-planning sync via a tiny REST server or simple JSON import/export.”

2. Data Model (SQLite)

```sql
CREATE TABLE item (
	id          INTEGER PRIMARY KEY,         -- unix epoch millis
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
	name TEXT UNIQUE
);

CREATE TABLE shop (
	id            INTEGER PRIMARY KEY,
	name          TEXT UNIQUE,
	sort_order    TEXT  -- comma-sep list of category.id
);

CREATE TABLE config (
	key   TEXT PRIMARY KEY,
	value TEXT
);
```

3. UI / UX Rules  
   • Theme: Material-ish; light & dark; colors adjustable via Godot Theme resource.  
   • Item row height: 40 px button + optional 2-line description → max 15 rows on phone.  
   • Left 40×40 button shows:  
	 – line 1 = amount (large), line 2 = unit (small).  
	 – background texture toggles: needed vs in-cart vs normal.  
   • Remaining row (horizontal):  
	 – name (biggest, 3-line wrap)  
	 – category (smaller font, max “Haushaltswaren”)  
	 – price (right-aligned, 12.34 €, shrink/wrap >99.99)  
   • Long-press row → open full edit dialog.  
   • Planning view: alphabetical, show search & filter by category.  
   • Shopping view: choose shop → show only categories in shop.sort_order, sort by that order, move in_cart items to bottom.  
   • Settings screen: lines-per-screen, colors, language, server URL, user, pass.

4. I18n  
   • Buttons & labels via gettext `.po` files; symbols preferred.  
   • Article/category names NOT translated (user-entered).

5. Sync / Backup  
   • JSON export/import (entire DB) via share sheet / file picker.  
   • Optional server: minimal Flask container exposing `/sync` endpoint.  
   • Auth: HTTP basic (user/pass stored in `config` table).  
   • Sync flow: POST full JSON → server responds with merged JSON; client replaces local DB.

6. Dev / Release  
   • Godot 4.x, GDScript.  
   • Project → Export → Android APK (debug keystore for CI).  
   • GitHub Actions: on tag `v*` build signed release APK + attach to release page.  
   • MIT license.

────────────────────────────────────────
LLM Prompt-Pack  (copy/paste)
────────────────────────────────────────
1. Create Godot 4 project skeleton  
   ```
   Create a Godot 4 project named "Neoshop" with:
   - main.tscn (Control root)
   - autoload Globals.gd for DB path & config
   - addons folder for SQLite GDNative or godot-sqlite
   - export_presets.cfg for Android
   ```

2. SQLite wrapper & schema migration  
   ```
   Provide GDScript that:
   - opens res://data/shop.db (or user:// on Android)
   - runs CREATE TABLE statements above (if tables missing)
   - exposes basic CRUD: add_item, list_items, update_item, delete_item
   ```

3. Item row scene  
   ```
   Design a reusable ItemRow.tscn (HBoxContainer):
   - 40×40 TextureButton left
   - VBoxContainer right with labels: name, category, price
   - dynamic font sizes & word-wrap as spec
   - expose GDScript properties: item_id, amount, unit, name, ...
   ```

4. Planning screen  
   ```
   Create PlanningScreen.tscn:
   - search LineEdit
   - filter OptionButton (categories)
   - ItemList or VBoxContainer of ItemRow instances
   - sort alphabetically
   ```

5. Shopping screen  
   ```
   Create ShoppingScreen.tscn:
   - shop selector OptionButton
   - load shop.sort_order, filter & sort items accordingly
   - tap row → toggle in_cart & move to bottom
   ```

6. Edit dialog  
   ```
   Create EditItemDialog.tscn (popup):
   - LineEdit name, SpinBox amount, LineEdit unit, TextEdit description,
	 OptionButton category, CheckButton needed/on_sale, SpinBox price_cents
   - save button commits to DB
   ```

7. Settings screen  
   ```
   SettingsScreen.tscn:
   - SpinBox lines_per_screen
   - ColorPickerButton for theme colors
   - OptionButton language (reads .po files)
   - LineEdits: server_url, username, password
   - buttons: export JSON, import JSON
   ```

8. SQLite → JSON export/import  
   ```
   GDScript functions:
   - export_db() → returns JSON string of all tables
   - import_db(json_string) → wipes local DB, inserts data
   - integrate with FileDialog for save/load
   ```

9. Flask sync server (Docker)  
   ```
   Provide minimal server.py:
   - POST /sync expects JSON body
   - merges on id (unixtime) keeping latest
   - returns merged JSON
   - basic auth via user/pass
   Dockerfile to expose port 8000
   ```

10. GitHub Actions release  
	```
	Provide .github/workflows/release.yml that:
	- runs on tag v*
	- installs Godot headless
	- exports release APK
	- signs with debug keystore (or GitHub secret)
	- uploads artifact to release page
	```

Use the spec as your north-star; iterate on any detail later.
