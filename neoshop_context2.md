```markdown
# Neoshop – Single Source of Truth
Offline-first shopping list for family & friends.  
Built with Godot 4.x → Android (primary), tablets/PC supported.  
MIT license; open-source repo on GitHub.

## 0. Current Status
• ✅ Godot 4.4.1-stable project  
• ✅ Godot-SQLite 4.5 (Asset-Lib GDExtension) installed and enabled  
• ✅ Singleton `DB` autoload (`res://db/database.gd`) – **CRUD layer fully working**  
• ✅ In-memory test scene (`res://test/test_crud.gd`) proves Category & Item CRUD  
• ✅ SQLite schema automatically created on first run  

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
• Row height ≈ 40 px → ~10 rows visible on phone  
• Item row layout (HBox):  
  – 40×40 px TextureButton left:  
	• top line = amount, bottom = unit  
	• background texture toggles needed / in_cart / normal  
  – Remaining space:  
	• name (biggest, 3-line wrap)  
	• category (smaller font, max “Haushaltswaren”)  
	• price right-aligned, 12.34, shrink or wrap >99.99  
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

## 7. Implemented / Ready to Use
• `res://db/database.gd` – singleton providing **offline CRUD**  
  – `insert_item`, `update_item`, `select_items`, `delete_item`  
  – Same for category  
• `res://test/test_crud.gd` – **one-scene smoke test** (passes)  
• Schema auto-created on first launch  
• No external dependencies beyond the Asset-Lib plug-in already installed
```

“Build PlanningScreen UI”
let us build the PlanningScreen UI. I attached a picture of a similar app.  
I'd like to achieve a similar screen layout, but with some tweaks.
The layout should primarily be set up to be used on 6" - 7" mobile phones in portrait mode, but should also be usable on a 10" tablet in landscape and eventually on a desktop PC. Since the screen size varies so much I am not sure what we should use as the base resolution in our Godot project. I tried 720x1280 and 1000x1000. We should aim for around 10-11 mm height for an average item row on mobile in portrait mode and maybe adjust that later for tablet and PC in landscape.  
The color scheme should be switchable in the setup screen between a similar look like the screenshot, a light and a dark theme. This could be achieved using Godot UI themes.

The vertical layout(using a vboxcontainer) should be like this:
- a top row that shows the app name, the database name and the current mode like  
"Neoshop - shopping_list (planning)"  
- The second should row contain a search field (could be a line_edit) and a category selector dropdown (this should also have an "all" choice). These would allow to select only articles that contain the letters entered in the search field, eventually filtered by category. Each change to those fields should trigger a refresh of the UI.
- Next is a vertical scroll area that will be filled with the instantiated item lines.
Each item line has the following format (using a vbox for the main line and the description):
-- the main item line using an hbox to contain
--- a check button on the left side that shows the amount on the top row and the unit on the bottom row.
   the background texture will change depending on the "needed" field
--- name field, word wrapping, showing up to 3 lines. Since usually 1-2 lines will be sufficient the font size should be chosen so it will use the line height with two lines and expand the line height accordingly if the third line is needed
--- a button containing the price. In a later version this may become an "on sale" flag that could display the logo of the shop offering the sale
-- If the description field contains text it will be shown below the main item line, formatted to allow up to two lines of text, otherwise the description field will be hidden.

Clicking the "needed" button will emit a toggle signal to allow flaggin items to be bought.
Long pressing the rest of the item line should pop up the item editor screen which will allow to change each field of the item
- the bottom toolbar holds buttons to call other screens
-- an add button that will pop up the iten edit screen to add a new item
-- a setup button to call the setup screen
-- a cart button that will switch to shopping mode (which will be detailled in the next milestone)
