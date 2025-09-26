extends Control
class_name PlanningScreen

@onready var top_bar   : HBoxContainer     = $BackgroundPanel/MainVBox/TopBar
@onready var db_label  : Label             = $BackgroundPanel/MainVBox/TopBar/DBName
@onready var search    : LineEdit          = $BackgroundPanel/MainVBox/FilterBar/Search
@onready var category  : OptionButton      = $BackgroundPanel/MainVBox/FilterBar/CategoryFilter
@onready var item_list : VBoxContainer     = $BackgroundPanel/MainVBox/Scroll/ItemList
@onready var add_btn   : Button            = $BackgroundPanel/MainVBox/BottomBar/AddButton
@onready var settings  : Button            = $BackgroundPanel/MainVBox/BottomBar/SettingsButton
@onready var tools     : Button            = $BackgroundPanel/MainVBox/BottomBar/ToolsButton
@onready var toggle_shopping_mode_btn  : Button = $BackgroundPanel/MainVBox/BottomBar/ToggleShoppingModeButton
@onready var category_editor: ConfirmationDialog = %CategoryEditor

var rows : Dictionary = {}   # int -> ItemRow
var shopping_mode : bool = false


func _ready() -> void:
	db_label.text = "loading"
	_load_initial_settings()
	_update_app_title()
	_populate_category_filter()
	_refresh()
	search.text_changed.connect(func(_t): _refresh())
	category.item_selected.connect(func(_t): _refresh())
	add_btn.pressed.connect(_on_add)
	settings.pressed.connect(_on_settings)
	tools.pressed.connect(_on_tools)
	toggle_shopping_mode_btn.pressed.connect(_on_shopping_toggle)
	
	%CategoryEditButton.pressed.connect(_on_category_edit_pressed)
	category_editor.category_saved.connect(_on_categories_changed)


func _update_app_title() -> void:
	var mode = tr("shopping") if DB.shopping_mode else tr("planning")
	var db_name = DB.get_db_name().replace('.db', '')
	%DBName.text = db_name.replace('.gd', '')
	%AppMode.text = mode


func _populate_category_filter() -> void:
	category.clear()
	category.add_item("All", -2)
	for cat in DB.select_categories():
		category.add_item(str(cat["name"]), int(cat["id"]))
	category.selected = 0


func _load_initial_settings() -> void:
	var myTheme: String = DB.get_config("theme", "light")
	var lang:  String = DB.get_config("language",  "en")
	ThemeManager.apply_theme(myTheme)
	LocaleHelper.set_locale(lang)
	#print("_load_initial_settings, theme: ", myTheme, " lang: ", lang)


func _on_seed() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.title = "Reset Database?"
	confirm.dialog_text = "This will add sample categories and items to your database.\n\nExisting data will be preserved.\n\nContinue?"
	
	confirm.confirmed.connect(func():
		var seed_manager = preload("res://scripts/seed_manager.gd").new()
		seed_manager.seed_completed.connect(func(items, cats): 
			print("Seeding complete: %d items, %d categories" % [items, cats])
			_refresh()
		)
		add_child(seed_manager)
		seed_manager.seed_database()
	)
	
	#confirm.canceled.connect(func():
		#print("Seeding cancelled")
	#)
		
	get_tree().root.add_child(confirm)
	confirm.popup_centered()
	_refresh()


func _refresh_category_filter():
	# Clear existing items except "All"
	category.clear()
	category.add_item("All", -2)
	
	# Load fresh categories from database
	var categories = DB.select_categories()
	categories.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	
	# Add categories to dropdown
	for cat in categories:
		category.add_item(str(cat["name"]), int(cat["id"]))
	
	# Reset selection to "All"
	category.selected = 0


func _refresh() -> void:
	var search_txt : String = search.text.to_lower()
	var cat_id     : int    = category.get_item_id(category.selected)
	
	var items : Array[Dictionary] = DB.select_items()
	
	# clear old rows
	for child in item_list.get_children():
		if child is ItemRow:
			child.long_pressed.disconnect(_edit_item)  # Disconnect signal
		child.queue_free()
	rows.clear()
	
	# Filter based on mode
	if DB.shopping_mode:
		# Shopping mode: only needed items
		items = items.filter(func(it: Dictionary) -> bool:
			var matches_needed = bool(it.get("needed", false))
			var matches_search = search_txt.is_empty() or str(it["name"]).to_lower().contains(search_txt)
			var matches_category = cat_id == -2 or int(it["category_id"]) == cat_id
			return matches_needed and matches_search and matches_category
		)
		
		# Sort for shopping mode
		items.sort_custom(func(a, b):
			var a_in_cart = bool(a.get("in_cart", false))
			var b_in_cart = bool(b.get("in_cart", false))
			
			if a_in_cart != b_in_cart:
				return !a_in_cart  # False first (not in cart)
			
			if !a_in_cart and !b_in_cart:
				# Both not in cart, sort by category
				return int(a.get("category_id", 0)) < int(b.get("category_id", 0))
			
			# Both in cart, sort by last_bought (newest first)
			var a_last = int(a.get("last_bought", 0))
			var b_last = int(b.get("last_bought", 0))
			return b_last < a_last  # Descending order
		)
	else:
		# Planning mode: regular filtering
		items = items.filter(func(it: Dictionary) -> bool:
			var matches : bool = search_txt.is_empty() or str(it["name"]).to_lower().contains(search_txt)
			if cat_id != -2:
				matches = matches and int(it["category_id"]) == cat_id
			return matches
		)
		
		# Planning mode: sort by name
		items.sort_custom(func(a, b): 
			return str(a["name"]).to_lower() < str(b["name"]).to_lower()
		)

	# Sync UI
	var items_count: int = 0
	for it in items:
		items_count += 1
		var id : String = it.get(["id"],"")
		var row : ItemRow = preload("res://ui/item_row.tscn").instantiate() as ItemRow
		row.setup(it)
		#row.set_shopping_mode(DB.shopping_mode)
		row.long_pressed.connect(_edit_item)
		row.needed_changed.connect(DB.toggle_needed)
		row.in_cart_changed.connect(_on_in_cart_changed)
		item_list.add_child(row)
		rows[id] = row
	
	# Update UI for shopping mode - only hide add button
	#add_btn.visible = !DB.shopping_mode

	print("_refresh items: ", items_count, " shopping_mode = ", DB.shopping_mode)


func _open_editor(id: String) -> void:
	print("open_editor: ", id)
	var sc := %Scroll
	sc.scroll_vertical = 0
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var popup := preload("res://ui/item_editor.tscn").instantiate()
	popup.item_saved.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		_refresh()
	)
	popup.item_canceled.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		_refresh()
	)
	popup.item_deleted.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		_refresh()
	)
	add_child(popup)
	if id != "-1":
		popup.edit_item(id)
	else:
		popup.new_item()
	popup.show()


func _edit_item(id: String) -> void:
	print("edit_item: ", id)
	_open_editor(id)


func _on_add() -> void:
	_open_editor("-1")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://ui/setup_screen.tscn")


func _on_tools() -> void:
	get_tree().change_scene_to_file("res://ui/tools_screen.tscn")


func _on_shopping_toggle() -> void:
	DB.shopping_mode = !DB.shopping_mode
	#toggle_shopping_mode_btn.text = "📋" if DB.shopping_mode else "🛒"
	# Preload the icons (use preload for performance, or load() if paths are dynamic)
	var notepad_icon = preload("res://icons/notepad.svg")
	#var cart_icon = preload("res://icons/cart.png")
	var cart_icon = preload("res://icons/cart.svg")

	# Set the button's icon based on the condition
	toggle_shopping_mode_btn.icon = notepad_icon if DB.shopping_mode else cart_icon
	_update_app_title()
	_refresh()


func _on_in_cart_changed(item_id: String) -> void:
	DB.toggle_in_cart(item_id)
	_refresh()
	print("in_cart_changed")


func _on_category_edit_pressed():
	category_editor.popup_category_editor()


func _on_categories_changed():
	_refresh_category_filter()
	_refresh()


# ------------------------------------------------------------------
func _get_editor() -> Window:
	if ResourceLoader.exists("res://ui/item_editor.tscn"):
		return preload("res://ui/item_editor.tscn").instantiate() as Window
	else:
		var dlg := AcceptDialog.new()
		dlg.dialog_text = "Editor scene missing – stub only"
		return dlg


func _input(event) -> void:
	#if event is InputEventKey and event.pressed:
		#print(OS.get_keycode_string(event.keycode))
	if event is InputEventKey and event.keycode in [KEY_BACK, KEY_ESCAPE] and event.pressed:
		if(DB.shopping_mode):
			_on_shopping_toggle()
			return
		print("Application Quit")
		get_tree().quit()
		
