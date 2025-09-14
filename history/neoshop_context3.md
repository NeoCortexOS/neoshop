Offline-first shopping-list app for family & friends.  
Godot 4.4.1 + GDScript + SQLite GDExtension.

0.  Data Model (unchanged)
	• item, category, shop, config tables – schema in `res://db/schema.sql`.

1.  Current Status (this sprint)
	• ✅ **PlanningScreen** fully functional  
	  – 100×100 px toggle button (amount + unit)  
	  – name, category, price, optional description  
	  – live search & category filter  
	  – long-press row → ItemEditor (edit / add / delete)  
	  – “Add” button → ItemEditor (new item)  
	  – needed flag persisted in DB  
	• ✅ **ItemEditor.tscn** + `item_editor.gd`  
	  – single-line LineEdit for description  
	  – Save / Cancel / Delete buttons  
	• ✅ **Theme** switching scaffold (`res://themes/`)  
	• ✅ **Responsive** UI (phone, tablet, desktop)  
	• ✅ **Offline first** – no external deps beyond SQLite ext  
	• ❌ **Multiple named lists** – planned for later  
	• ❌ **Shopping mode** – planned for later  
	• ❌ **Android permissions** – planned for later  

2.  File Layout
	res://  
	├─ db/  
	│  ├─ database.gd      (SQLite CRUD singleton)  
	│  ├─ seed.gd          (one-shot seed script)  
	│  └─ schema.sql  
	├─ ui/  
	│  ├─ PlanningScreen.tscn / .gd  
	│  ├─ item_row.tscn / .gd  
	│  └─ item_editor.tscn / .gd  
	├─ themes/             (material, light, dark)  
	└─ test/  
	   └─ seed_scene.tscn  

3.  Next Milestones
	M1  Category editor  
	M2  Android runtime permissions & signed APK build  
	M3  Shopping mode toggle  
		– icon swap (check → cart)  
		– short-press toggles `in_cart`  
		– sort by shop_category, show only `needed`  
	M4  Shop entity & `on_sale_in_shop` field  
