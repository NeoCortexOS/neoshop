# Neoshop – Complete Project Context & Development Guide

**Offline-first shopping list app for families**  
Built with Godot 4.4.1 + GDScript + SQLite GDExtension  4.5
Target: Android (primary), tablets/PC supported  
License: MIT, open-source

## Current Status Summary
✅ **Planning Screen** - Fully functional with search, filter, add/edit/delete  
✅ **Item Editor** - Complete CRUD operations with validation  
✅ **Database Layer** - SQLite integration with proper schema and migration  
✅ **Theme System** - Material theme integrated  
✅ **Responsive UI** - Works on phone, tablet, desktop  
✅ **Long-press Editing** - Timer-based long-press detection (0.6s)  
✅ **Real-time Search** - Live filtering as user types  
✅ **Category System** - Full CRUD for categories  
❌ **Shopping Mode** - Planned for next milestone  
❌ **Multi-list Support** - Future feature  
❌ **Android Permissions** - Needed for APK release  

---

## 1. Data Model (SQLite Schema)

```sql
-- File: res://db/schema.sql
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

**Key Design Decisions:**
- `id` uses unix epoch milliseconds for future sync compatibility
- `needed` flag for planning mode (what to buy)
- `in_cart` flag for shopping mode (what's already picked up)
- `price_cents` stored as integer to avoid floating-point issues
- Categories are user-defined, not localized

---

## 2. Project Structure

```
res://
├─ db/
│  ├─ database.gd      # SQLite CRUD singleton (autoload)
│  ├─ seed.gd          # Development data seeding
│  └─ schema.sql       # Database schema
├─ ui/
│  ├─ PlanningScreen.tscn/.gd    # Main shopping list view
│  ├─ item_row.tscn/.gd          # Reusable item display component
│  └─ item_editor.tscn/.gd       # Add/Edit item dialog
├─ themes/
│  ├─ material_light.tres
│  ├─ material_dark.tres
│  └─ theme_manager.gd
├─ test/
│  └─ seed_scene.tscn   # Quick dev/test scene
└─ main.tscn            # App entry point
```

**Dependencies:**
- godot-sqlite 4.5 (from Asset Library) - tested on Godot 4.4.1

---

## 3. UI/UX Specifications

### Item Row Layout (item_row.tscn)
**Actual Implementation:**
- **ItemRow:** VBoxContainer
- **MainLine:** HBoxContainer with 8px separation containing:
  - **NeedCheck:** Button (100×100px minimum) - shows amount/unit as button text and a checkmark icon
  - **NameLabel:** Label (100×40px minimum, 3-line autowrap)
  - **CategoryLabel:** Label (100×40px minimum)
  - **PriceButton:** Button (right-aligned, shrink horizontally)
- **DescriptionLabel:** Label below main line (2-line autowrap, hidden when empty)

### Interactions
- **Short tap:** Toggle `needed` flag in planning mode
- **Long press:** Open ItemEditor dialog
- **Add button:** Create new item via ItemEditor

### Planning Screen Features
- Live search filtering (searches name, description, category)
- Category filter dropdown (All + specific categories)
- Alphabetical sorting
- Responsive layout (phone: 1 column, tablet: 2+ columns)

### Theme System
- Material Design-inspired
- Light/dark mode support
- Colors configurable via Godot Theme resources
- Consistent spacing and typography scale

---

## 4. Core Features (Current Implementation)

### Planning Mode ✅
- View all items in alphabetical order
- Search by name, description, or category
- Filter by specific category
- Add new items with full details
- Edit existing items (name, amount, unit, description, category, price)
- Delete items with confirmation
- Toggle "needed" status for shopping preparation

### Item Management ✅
- CRUD operations through ItemEditor dialog
- Input validation (required name, positive price)
- Category selection with dynamic loading
- Automatic database persistence
- Real-time UI updates

### Database Layer ✅
- SQLite integration via GDExtension
- Singleton pattern for global access
- Prepared statements for performance
- Proper error handling and logging
- Schema migration on first run

---

## 5. Planned Features (Roadmap)

### M1: Category Management
- Add/edit/delete categories
- Reorder categories
- Category color coding

### M2: Android Deployment
- Runtime permissions setup
- Signed APK build process
- File system access for export/import
- Share functionality integration

### M3: Shopping Mode
- Toggle between Planning/Shopping views
- Shop selection with category ordering
- Visual distinction for in_cart items
- Quick toggle interactions
- Progress tracking

### M4: Advanced Features
- Multiple named shopping lists
- JSON export/import for backup
- Optional sync server integration
- Price history and analytics

---

## 6. Technical Implementation Notes

### Database Singleton (database.gd)
**Actual Implementation - Key Methods:**
```gdscript
# Category operations
- insert_category(name: String) -> int
- select_categories() -> Array
- delete_category(id: int) -> void

# Item operations
- insert_item(p: Dictionary) -> int
- update_item(p: Dictionary) -> void
- select_items(where_sql := "", params := []) -> Array
- delete_item(id: int) -> void
- toggle_needed(id: int, needed: bool) -> void
- toggle_in_cart(id: int) -> void

# Utility methods
- get_db_name() -> String
- select_item_count() -> int
```

**Database Setup:**
- Uses godot-sqlite GDExtension
- Database path: `user://neoshop.db`
- Schema loaded from `res://db/schema.sql`
- Migration system checks for table existence before creation

### Item Row Component (item_row.gd)
**Actual Implementation:**
```gdscript
# Signals
signal long_pressed
signal needed_changed(item_id: int, needed: bool)

# Key methods:
- setup(item: Dictionary) -> void        # One-time setup with signal connections
- update_from_item(item: Dictionary) -> void  # Refresh display from data
- _get_category_name(id: int) -> String  # Helper for category lookup

# UI Structure (VBoxContainer):
- MainLine (HBoxContainer)
  - NeedCheck (Button) - 100x100px with amount/unit text
  - NameLabel (Label) - 3-line wrap
  - CategoryLabel (Label) - _get_category_name from category_id
  - PriceButton (Button) - right-aligned price
- DescriptionLabel (Label) - 2-line wrap, hidden if empty
```

**Long-press Implementation:**
- Uses Timer (0.6s) for long-press detection
- Handles both touch and keyboard input
- Emits `long_pressed` signal to open editor

### Theme Integration
- Use Godot's built-in Theme system
- Define consistent color palette
- Responsive font scaling
- Support for system theme detection

---

## 7. Development Workflow

### For AI Assistants - Expected Capabilities:
1. **Generate complete .gd scripts** with proper GDScript syntax
2. **Provide .tscn file structure** as text representation showing node hierarchy
3. **Implement specific features** following the established patterns
4. **Debug existing code** and suggest improvements
5. **Add new functionality** while maintaining consistency

### Code Style Guidelines:
- Use snake_case for variables and functions
- Use PascalCase for classes and scenes
- Include type hints where possible
- Add clear comments for complex logic
- Follow Godot's signal-based architecture

### Testing Approach:
- Use seed.gd for consistent test data
- Test on multiple screen sizes
- Verify database operations
- Validate UI responsiveness

---

## 8. Current Technical Debt & Known Issues

1. **Performance:** Large item lists (>100 items) need virtualization

2. **Editor Popup Management:** 
   - Complex mouse filter manipulation for scroll container
   - Could be simplified with proper modal handling

3. **Error Handling:** Basic implementation, needs enhancement for database errors

4. **Accessibility:** Missing screen reader support and proper focus management

5. **Localization:** Framework in place but no actual translations

---

## 9. Quick Start for Development

### To add a new screen:
1. Create .tscn file in ui/ folder
2. Add corresponding .gd script
3. Follow responsive layout patterns
4. Integrate with theme system
5. Add navigation from main.tscn

### To modify database schema:
1. Update schema.sql
2. Add migration logic in database.gd
3. Update seed.gd if needed
4. Test with existing data

### To add new UI components:
1. Follow item_row.tscn as template
2. Use consistent sizing and spacing
3. Implement proper signal handling
4. Add to theme system if needed

---

## 10. AI Assistant Instructions

When working on this project:
- **Database Access:** Use the `DB` autoload singleton (not `database` or `Database`)
- **Node References:** Use `%NodeName` unique name syntax extensively as shown in the codebase
- **Signal Patterns:** Follow the established pattern of connecting signals in `_ready()`
- **Item Data Structure:** Dictionary with keys: id, name, amount, unit, description, category_id, needed, in_cart, last_bought, price_cents, on_sale
- **Category Structure:** Dictionary with keys: id, name
- **Price Handling:** Store as integer cents, display as float euros (divide by 100.0)
- **Boolean Fields:** Use 0/1 in SQLite, convert to bool in GDScript

**Common Code Patterns:**
```gdscript
# Database queries
var items = DB.select_items("needed = ?", [true])

# Node references  
@onready var search: LineEdit = $MainVBox/FilterBar/Search
%UniqueNodeName.text = "value"

# Signal connections in _ready()
search.text_changed.connect(func(_t): _refresh())

# Item row refresh pattern
for it in items:
	var id: int = int(it["id"])
	var row: ItemRow = rows.get(id)
	if not row:
		row = preload("res://ui/item_row.tscn").instantiate()
		rows[id] = row
```

**Current Architecture:**
- Single autoload `DB` for all database operations
- Scene-based UI with .tscn + .gd pairs
- Signal-driven communication between components
- Dictionary-based data passing
- Popup windows for editors (not dialogs)
