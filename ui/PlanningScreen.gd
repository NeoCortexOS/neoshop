extends Control
class_name PlanningScreen

@onready var top_bar   : HBoxContainer     = $MainVBox/TopBar
@onready var db_label  : Label             = $MainVBox/TopBar/DBName
@onready var search    : LineEdit          = $MainVBox/FilterBar/Search
@onready var category  : OptionButton      = $MainVBox/FilterBar/CategoryFilter
@onready var item_list : VBoxContainer     = $MainVBox/Scroll/ItemList
@onready var add_btn   : Button            = $MainVBox/BottomBar/AddButton
@onready var settings  : Button            = $MainVBox/BottomBar/SettingsButton
@onready var cart_btn  : Button            = $MainVBox/BottomBar/CartButton
@onready var seed_btn  : Button            = $MainVBox/BottomBar/SeedButton
@onready var category_editor: ConfirmationDialog = %CategoryEditor


var rows : Dictionary = {}   # int -> ItemRow

func _ready() -> void:
	db_label.text = ""
	%AppTitle.text = "Neoshop – %s (planning)" % DB.get_db_name()
	_populate_category_filter()
	_refresh()
	search.text_changed.connect(func(_t): _refresh())
	category.item_selected.connect(func(_t): _refresh())
	add_btn.pressed.connect(_on_add)
	settings.pressed.connect(_on_settings)
	cart_btn.pressed.connect(_on_cart)
	seed_btn.pressed.connect(_on_seed)
	
	%CategoryEditButton.pressed.connect(_on_category_edit_pressed)
	category_editor.category_saved.connect(_on_categories_changed)

func _populate_category_filter() -> void:
	category.clear()
	category.add_item("All", -2)
	for cat in DB.select_categories():
		category.add_item(str(cat["name"]), int(cat["id"]))
	category.selected = 0
	
	
func _on_seed() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.title = "Reset Database?"
	confirm.dialog_text = "This will add sample categories and items to your database.\n\nExisting data will be preserved.\n\nContinue?"
	
	confirm.confirmed.connect(func():
		var seed_manager = preload("res://scripts/seed_manager.gd").new()
		seed_manager.seed_completed.connect(func(items, cats): 
			print("Seeding complete: %d items, %d categories" % [items, cats])
		)
		add_child(seed_manager)
		seed_manager.seed_database()
	)
	
	confirm.canceled.connect(func():
		print("Seeding cancelled")
	)
		
	get_tree().root.add_child(confirm)
	confirm.popup_centered()
	_refresh()

		
func _refresh_category_filter():
	# Clear existing items except "All"
	category.clear()
	category.add_item("All", -2)  # -2 for "All" selection (matches your existing code)
	
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

	print("--- _refresh ---")
	print("search_txt = '", search_txt, "'  cat_id = ", cat_id)
	
	var items : Array[Dictionary] = DB.select_items()
	#print("raw items from DB: ", items.size(), " rows")
	#for it in items:
		#print("  ", it)
		
	# clear old rows
	for child in item_list.get_children():
		child.queue_free()
	rows.clear()
	
	# Filter
	items = items.filter(func(it: Dictionary) -> bool:
		var matches : bool = search_txt.is_empty() or str(it["name"]).to_lower().contains(search_txt)
		if cat_id != -2:
			matches = matches and int(it["category_id"]) == cat_id
		return matches
	)

	# Sync UI
	var existing : Array = rows.keys()
	for it in items:
		var id : int = int(it["id"])
		var row : ItemRow = rows.get(id)
		if not row:
			row = preload("res://ui/item_row.tscn").instantiate() as ItemRow
			row.setup(it)
			row.long_pressed.connect(_edit_item.bind(id))
			row.needed_changed.connect(DB.toggle_needed)
			item_list.add_child(row)
			rows[id] = row
		else:
			row.update_from_item(it)
		existing.erase(id)

	# Remove deleted rows
	for id in existing:
		rows[id].queue_free()
		rows.erase(id)


func _open_editor(id: int) -> void:
	var sc := %Scroll   # give ScrollContainer a unique name
	sc.scroll_vertical = 0           # optional: reset scroll
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ← no scroll grab

	var popup := preload("res://ui/item_editor.tscn").instantiate()
	popup.item_saved.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS   # restore
		print("item_saved mouse restored")
		_refresh()
	)
	popup.item_canceled.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS   # restore
		print("item_cancelled mouse restored")
		_refresh()
	)
	popup.item_deleted.connect(func():
		sc.mouse_filter = Control.MOUSE_FILTER_PASS   # restore
		print("item_deleted mouse restored")
		_refresh()
	)
	add_child(popup)
	popup.size = Vector2i(360, 480)
	popup.position = Vector2i(get_viewport().get_visible_rect().get_center()) - popup.size / 2
	if id != -1:
		popup.edit_item(id)
	else:
		popup.new_item()
	popup.show()

func _edit_item(id: int) -> void:
	_open_editor(id)

func _on_add() -> void:
	_open_editor(-1)
	
	
func _on_settings() -> void:
	get_tree().change_scene_to_file("res://ui/settings.tscn")

func _on_cart() -> void:
	get_tree().change_scene_to_file("res://ui/shopping_screen.tscn")

	
# ------------------------------------------------------------------
func _get_editor() -> Window:
	print("using real editor: ", ResourceLoader.exists("res://ui/item_editor.tscn"))
	if ResourceLoader.exists("res://ui/item_editor.tscn"):
		return preload("res://ui/item_editor.tscn").instantiate() as Window
	else:
		var dlg := AcceptDialog.new()
		dlg.dialog_text = "Editor scene missing – stub only"
		return dlg

func _on_category_edit_pressed():
	category_editor.popup_category_editor()

func _on_categories_changed():
	_refresh_category_filter()
	_refresh()
