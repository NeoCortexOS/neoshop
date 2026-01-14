extends Control
class_name PlanningScreen

const PB := preload("res://addons/godex_ui_profiler/profile_block.gd")
const ROW_HEIGHT := 128.0   # measured from .tscn + separators

signal row_tapped(item_id: String)          # replaces old long_pressed
signal row_long_pressed(item_id: String)

@onready var top_bar   : HBoxContainer     = $BackgroundPanel/MainVBox/TopBar
@onready var db_label  : Label             = $BackgroundPanel/MainVBox/TopBar/DBName
@onready var search    : LineEdit          = $BackgroundPanel/MainVBox/FilterBar/Search
@onready var category  : OptionButton      = $BackgroundPanel/MainVBox/FilterBar/CategoryFilter
@onready var item_count : Label      = %ItemCount
@onready var item_list : VBoxContainer     = %ItemList
@onready var add_btn   : Button            = $BackgroundPanel/MainVBox/BottomBar/AddButton
@onready var settings  : Button            = $BackgroundPanel/MainVBox/BottomBar/SettingsButton
@onready var tools     : Button            = $BackgroundPanel/MainVBox/BottomBar/ToolsButton
@onready var toggle_shopping_mode_btn  : Button = $BackgroundPanel/MainVBox/BottomBar/ToggleShoppingModeButton
@onready var category_editor: ConfirmationDialog = %CategoryEditor

@onready var search_timer: Timer = Timer.new()   # throttles search
var _pending_filter: Dictionary = {}             # deferred work
var _rebuild_frame_index: int = 0
var _visual_idx: int = 0

#var rows : Dictionary = {}   # int -> ItemRow
var shopping_mode : bool = false
var categories
var _saved_scroll : int = 0
var _saved_planning_scroll : int = 0
var _saved_shopping_scroll : int = 0
var _search_txt: String = ""          # cached filter state
# --- input handling variables ---
signal long_pressed
# --- gesture constants ---
const TAP_MAX_DISTANCE  := 30.0
const LONG_PRESS_TIME   := 0.6
const SCROLL_THRESHOLD  := 15.0

# --- state ---
var touch_start_time : float   = 0.0
var touch_start_pos  : Vector2 = Vector2.ZERO
var has_moved        : bool    = false
var is_scrolling     : bool    = false
var is_long_pressed  : bool    = false

# --- active_item ---
var active_item: Control = null
# item dictionary
var my_item     : Dictionary = {}

# item data
var item_id     : String = "-1"
var iname       : String = ""
var amount      : float  = 0.0
var unit        : String = ""
var description : String = ""
var category_id : int    = -1
var needed      : bool   = false
var in_cart     : bool   = false
var price_cents : int    = 0
var is_deleted  : bool   = false

# ----------  res://ui/planning_screen.gd  ----------
enum RefreshState { FILTER, VISUAL, IDLE }
var refresh_state : RefreshState = RefreshState.IDLE

##
## ---------- logging ----------
func info(msg: String):
	print("[planning_screen] ", msg)
	#info_message.emit("[P2P] " + msg)


func _ready() -> void:
	info("_ready: " + self.name)
	# parent the pooled rows into the VirtualContent node NOW
	var vp := %VirtualContent
	for r in ItemRowManager.pool: vp.add_child(r)
	db_label.text = "loading"
	_load_initial_settings()
	_update_app_title()
	#_populate_category_filter()
	_refresh_category_filter()
	_refresh()
	add_child(search_timer)
	search_timer.wait_time = 0.15
	search_timer.one_shot = true
	search_timer.timeout.connect(_on_search_timer)
	search.text_changed.connect(_on_search_text_changed)
	add_btn.pressed.connect(_on_add)
	settings.pressed.connect(_on_settings)
	tools.pressed.connect(_on_tools)
	toggle_shopping_mode_btn.pressed.connect(_on_shopping_toggle)

	category.item_selected.connect(_on_category_chosen)
	%CategoryEditButton.pressed.connect(_on_category_edit_pressed)
	category_editor.category_saved.connect(_on_categories_changed)
	
	var v_scroll: ScrollBar = %Scroll.get_v_scroll_bar()
	v_scroll.value_changed.connect(func(v): ItemRowManager._update_window(v))
	
	# initialize lazy data
	ItemRowManager.rebuild_pool()          # fill _full_items
	ItemRowManager.apply_filter("",-2,false) # initial visible window
	_update_counters()
	#_refresh()                              # sets counters + fake height
	#_wire_pool_input_events()
	row_tapped.connect(_on_row_tapped)
	row_long_pressed.connect(_edit_item)
	
## initial window at top
	#ItemRowManager.rebuild_visible_indices()
	#ItemRowManager._update_window(0.0)


#func _wire_pool_input_events() -> void:
	#for row: ItemRow in ItemRowManager.pool:
		## each row already has its own gui_input → just forward
		#row.gui_input.connect(_on_row_gui_input.bind(row))


func _on_row_tapped(item_id: String) -> void:
	if DB.shopping_mode:
		DB.toggle_in_cart(item_id)
		ItemRowManager.rebuild_for_mode(shopping_mode)
		_refresh()              # re-sorts cart
	else:
		DB.toggle_needed(item_id)
		_refresh()              # only counter changes


func _on_row_gui_input(event: InputEvent, row: ItemRow) -> void:
	# same constants you already use
	const TAP_MAX_DISTANCE   = 30.0
	const LONG_PRESS_TIME    = 0.6
	const SCROLL_THRESHOLD   = 15.0

	var item_id: String = row.item_id
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			touch_start_pos  = event.position
			touch_start_time = Time.get_ticks_msec() / 1000.0
			has_moved        = false
			is_long_pressed  = false
			var t := Timer.new()
			t.wait_time = LONG_PRESS_TIME
			t.one_shot  = true
			t.timeout.connect(_on_long_press_timer.bind(item_id))
			add_child(t)
			t.start()
		else:   # released
			# kill timer
			for c in get_children():
				if c is Timer and c.wait_time == LONG_PRESS_TIME:
					c.queue_free()
			var dist : float = (event.position - touch_start_pos).length()
			if not has_moved and dist < TAP_MAX_DISTANCE and not is_long_pressed:
				row_tapped.emit(item_id)

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var dist : float = (event.position - touch_start_pos).length()
		if dist > SCROLL_THRESHOLD:
			has_moved = true

func _on_long_press_timer(item_id: String) -> void:
	if not has_moved:
		is_long_pressed = true
		row_long_pressed.emit(item_id)


func _on_search_text_changed(_t):
	search_timer.start()        # restart on every keystroke
	# NEW: instant first frame
	if search_timer.is_stopped():
		_refresh_deferred()


func _on_search_timer():
	_refresh_deferred()


func _refresh_deferred():
	ItemRowManager.rebuild_for_mode(DB.shopping_mode)   # only if dirty
	ItemRowManager.apply_filter(
		search.text.to_lower(),
		category.get_item_id(category.selected),
		DB.shopping_mode
	)
	ItemRowManager.refresh_window(DB.shopping_mode)   # <-- NEW: instant visual swap
	_update_counters()


func _process(_dt: float) -> void:
	match refresh_state:
		RefreshState.FILTER:
			var rows: Array[ItemRow] = ItemRowManager._pool
			var last: int = min(_rebuild_frame_index + 30, rows.size())
			for i in range(_rebuild_frame_index, last):
				var row: ItemRow = rows[i]
				var it: Dictionary = row.get_meta("item_dict")
				# ----- visibility filter -----
				@warning_ignore("shadowed_variable_base_class")
				var show: bool = true
				if bool(it.get("is_deleted", false)): show = false
				elif bool(_pending_filter.get("shopping", false)) and !bool(it.get("needed", false)): show = false
				elif !str(_pending_filter.get("search", "")).is_empty() and !str(it.name).to_lower().contains(str(_pending_filter.get("search", ""))): show = false
				elif int(_pending_filter.get("cat_id", -2)) != -2 and int(it.category_id) != int(_pending_filter.get("cat_id", -2)): show = false
				row.visible = show
				# ----- visual refresh in SAME frame -----
				row.set_shopping_mode(bool(_pending_filter.get("shopping", false)))
				row.update_from_item(it)
			_rebuild_frame_index = last
			if _rebuild_frame_index >= rows.size():
				refresh_state = RefreshState.IDLE
				set_process(false)


func _update_app_title() -> void:
	var mode = tr("shopping") if DB.shopping_mode else tr("planning")
	var db_name = DB.get_db_name().replace('.db', '')
	%DBName.text = db_name.replace('.gd', '')
	%AppMode.text = mode

func _update_counters():
	# same counters as before, but only once at end
	if DB.shopping_mode:
		item_count.text = str(_in_cart_count()) + "\n" + str(_needed_count())
	else:
		item_count.text = str(_needed_count()) + "\n" + str(_visible_count())

func _populate_category_filter() -> void:
	info("_populate_category_filter")
	category.clear()
	category.add_item("All", -2)
	for cat in DB.select_categories():
		category.add_item(str(cat["name"]), int(cat["id"]))
	category.selected = 0


func _on_category_chosen(my_cat):
	var cat_id := category.get_item_id(category.selected)
	print("selected index: " + str(my_cat) + " id: " + str(category.get_selected_id()))
	print ("category chosen: " + str(cat_id) + " my_cat: " + str(my_cat))
	_refresh()


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
	info("_refresh_category_filter")

	# Clear existing items except "All"
	category.clear()
	category.add_item("All", -2)
	
	# Load fresh categories from database
	categories = DB.select_categories()
	#categories.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	categories.sort_custom(func(a, b): 
			var str_a = str(a["name"]).to_lower()
			var str_b = str(b["name"]).to_lower()
			
			# Umlaute und ß ersetzen
			str_a = str_a.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
			str_b = str_b.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
			
			# Alphabetischen Vergleich durchführen
			return str_a < str_b
			)
	# Add categories to dropdown
	for cat in categories:
		#print("refresh category: " + str(cat))
		if(cat["is_deleted"] == 0):
			category.add_item(str(cat["name"]), int(cat["id"]))
			#category.add_item(str(cat["name"]))
	
	# Reset selection to "All"
	category.selected = 0


#func _refresh() -> void:
	#var _prof := PB.ms("PlanningScreen._refresh total")
	#var search_txt : String = search.text.to_lower()
	#var cat_id     : int    = category.get_item_id(category.selected)
	#
	#var t1 : int = Time.get_ticks_msec()
	#var items : Array[Dictionary] = DB.select_items()
	#info ("time spent filling items: " + str(Time.get_ticks_msec() - t1))
	#
	## clear old rows
	#for child in item_list.get_children():
		#if child is ItemRow:
			#child.long_pressed.disconnect(_edit_item)  # Disconnect signal
		#child.queue_free()
	#rows.clear()
	#
	## Filter based on mode
	#if DB.shopping_mode:
		## Shopping mode: only needed items
		#items = items.filter(func(it: Dictionary) -> bool:
			#var matches_needed = bool(it.get("needed", false))
			#var matches_search = search_txt.is_empty() or str(it["name"]).to_lower().contains(search_txt)
			#var matches_category = cat_id == -2 or int(it["category_id"]) == cat_id
			#return matches_needed and matches_search and matches_category
		#)
		#
		## Sort for shopping mode
		#items.sort_custom(func(a, b):
			#var a_in_cart = bool(a.get("in_cart", false))
			#var b_in_cart = bool(b.get("in_cart", false))
			#
			#if a_in_cart != b_in_cart:
				#return !a_in_cart  # False first (not in cart)
			#
			#if !a_in_cart and !b_in_cart:
				## Both not in cart, sort by category
				#print(DB.catname[b.get("category_id", 0)])
				#return DB.catname[a.get("category_id", 0)] < DB.catname[b.get("category_id", 0)]
			#
			## Both in cart, sort by last_bought (newest first)
			#var a_last = int(a.get("last_bought", 0))
			#var b_last = int(b.get("last_bought", 0))
			#return b_last < a_last  # Descending order
		#)
	#else:
		## Planning mode: regular filtering
		#var _prof2 := PB.ms("filter + sort")
		#items = items.filter(func(it: Dictionary) -> bool:
			#var matches : bool = search_txt.is_empty() or str(it["name"]).to_lower().contains(search_txt)
			#if cat_id != -2:
				#matches = matches and int(it["category_id"]) == cat_id
			#return matches
		#)
		#_prof2.finish()
		#
		## Planning mode: sort by name
		##items.sort_custom(func(a, b): 
			##return str(a["name"]).to_lower() < str(b["name"]).to_lower()
		##)
		##items.sort_custom(_compare_german)
		#
		#items.sort_custom(func(a, b): 
			#var str_a = str(a["name"]).to_lower()
			#var str_b = str(b["name"]).to_lower()
			#
			## Umlaute und ß ersetzen
			#str_a = str_a.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
			#str_b = str_b.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
			#
			## Alphabetischen Vergleich durchführen
			#return str_a < str_b
		#)
		##items.sort_custom(compare_german)
		##print("planning mode")
		##info(str(compare_german("aaa","aab")))
#
	## Sync UI
	#var items_count: int = 0
	#var items_needed: int = 0
	#var items_in_cart: int = 0
	#var _prof3 := PB.ms("instantiate rows")
	#var sum_ms : float = 0
	#var startframe := Engine.get_frames_drawn()
	#for it in items:
		#items_count += 1
		#if bool(it.get("needed", false)):
			#items_needed += 1
		#if bool(it.get("in_cart", false)):
			#items_in_cart += 1
		#var id : String = it.get(["id"],"")
		#var row : ItemRow = preload("res://ui/item_row.tscn").instantiate() as ItemRow
		#row.setup(it)
		##row.set_shopping_mode(DB.shopping_mode)
		##row.long_pressed.connect(_edit_item.bind(id))
		#row.long_pressed.connect(_edit_item)
		#row.needed_changed.connect(DB.toggle_needed)
		#row.in_cart_changed.connect(_on_in_cart_changed)
		#var _prof4 := PB.ms("row setup")
		#item_list.add_child(row)
		#rows[id] = row
		#sum_ms += _prof4.finish()
	#_prof3.finish()
	#print("frames drawn: " + str(Engine.get_frames_drawn()- startframe))
	#info("items ms: " + str(sum_ms))
	#
	## Update UI for shopping mode - only hide add button
	##add_btn.visible = !DB.shopping_mode
#
	#if DB.shopping_mode:
		#item_count.text = str(items_in_cart) + "\n" + str(items_needed)
	#else:
		#item_count.text = str(items_needed) + "\n" +str(items_count)
#
	#
	#print("_refresh items: ", items_count, " shopping_mode = ", DB.shopping_mode)
	#_prof.finish()


#
# old version before rewrite on 20251212
#func _refresh() -> void:
	#var _prof := PB.ms("PlanningScreen._refresh total")
#
	## 1.  cache filter values
	#_search_txt = search.text.to_lower()
	#var cat_id  = category.get_item_id(category.selected)
#
	## 2.  single pass over STATIC pool → hide/show
	#var visible_cnt := 0
	#var needed_cnt  := 0
	#var in_cart_cnt := 0
#
	#for row in ItemRowManager._pool:          # always all elements
		#var it: Dictionary = row.get_meta("item_dict")
#
		#var show := true
		## ----- apply identical filters you used before -----
		#if bool(it.get("is_deleted",false)):   show = false
		#elif DB.shopping_mode and !bool(it.get("needed",false)): show = false
		#elif _search_txt and !str(it.name).to_lower().contains(_search_txt): show = false
		#elif cat_id != -2 and int(it.category_id) != cat_id:  show = false
#
		#row.visible = show
		#if show:
			#visible_cnt += 1
			#if bool(it.get("needed",false)):  needed_cnt  += 1
			#if bool(it.get("in_cart",false)): in_cart_cnt += 1
#
	## 3.  update counters exactly like you did before
	#if DB.shopping_mode:
		#item_count.text = str(in_cart_cnt) + "\n" + str(needed_cnt)
		#ItemRowManager._pool.sort_custom(func(a, b):
			#var a_in_cart = a.in_cart
			#var b_in_cart = b.in_cart
			#
			#if a_in_cart != b_in_cart:
				#return !a_in_cart  # False first (not in cart)
			#
			#if !a_in_cart and !b_in_cart:
				## Both not in cart, sort by category
				##print(DB.catname[b.category_id])
				#return DB.catname[a.category_id] < DB.catname[b.category_id]
			#
			## Both in cart, sort by last_bought (newest first)
			#var a_last = a.last_bought
			#var b_last = b.last_bought
			#return b_last < a_last  # Descending order
		#)
	#else:
		#item_count.text = str(needed_cnt) + "\n" + str(visible_cnt)
#
	## >>> original closing print kept  <<<
	#print("_refresh items: ", visible_cnt, " shopping_mode = ", DB.shopping_mode)
	#_prof.finish()


#func _refresh() -> void:
	#var _prof := PB.ms("PlanningScreen._refresh total")
	##await get_tree().process_frame
	#var vc := %VirtualContent
	#if not is_instance_valid(vc):
		#push_error("VirtualContent missing – did you re-save the .tscn?")
		#return
	## 1. always sort shopping mode (in_cart changes order)
	#if DB.shopping_mode:
		#ItemRowManager.rebuild_for_mode(DB.shopping_mode)
	#else:
		#ItemRowManager.rebuild_if_dirty(DB.shopping_mode)   # planning keeps dirty flag
		##ItemRowManager.rebuild_for_mode(DB.shopping_mode)
	## 2. filter & counters
	#ItemRowManager.apply_filter(search.text.to_lower(),
								#category.get_item_id(category.selected),
								#DB.shopping_mode)
	#_update_counters()
	## 3. fake height for virtual scrollbar
	#ItemRowManager.apply_filter(search.text.to_lower(),
								#category.get_item_id(category.selected),
								#DB.shopping_mode)
	#var total_rows : int = ItemRowManager.get_visible_count()
	#%VirtualContent.custom_minimum_size.y = total_rows * ROW_HEIGHT
	#_prof.finish()


func _refresh() -> void:
	var prof := PB.ms("PlanningScreen._refresh")
	ItemRowManager.rebuild_for_mode(DB.shopping_mode)
	ItemRowManager.apply_filter(
		search.text.to_lower(),
		category.get_item_id(category.selected),
		DB.shopping_mode
	)
	# fake scrollbar height
	%VirtualContent.custom_minimum_size.y = ItemRowManager.get_visible_count() * ROW_HEIGHT
	_update_counters()
	prof.finish()


# helpers for counters (cheap loops over _full_items)
func _needed_count() -> int:
	var n := 0
	for it in ItemRowManager._full_items:
		if bool(it.get("needed",false)) and !bool(it.get("is_deleted",false)):
			n += 1
	return n


func _in_cart_count() -> int:
	var n := 0
	for it in ItemRowManager._full_items:
		if bool(it.get("in_cart",false)) and !bool(it.get("is_deleted",false)):
			n += 1
	return n


func _visible_count() -> int:
	var n := 0
	for it in ItemRowManager._full_items:
		if !bool(it.get("is_deleted",false)):
			n += 1
	return n


func compare_german(a, b) -> bool:
	#print("compare_german")
	var str_a = str(a).to_lower()
	var str_b = str(b).to_lower()

	# Umlaute und ß ersetzen
	str_a = str_a.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
	str_b = str_b.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")

	# Alphabetischen Vergleich durchführen
	#print(str_a + " : " + str_b)
	if str_a < str_b:
		return true
	return false



func _open_editor(id: String) -> void:
	print("open_editor: ", id)

	# 1. remember position
	var sc : ScrollContainer = %Scroll
	_saved_scroll = sc.scroll_vertical

	# 2. release capture – let the finger/mouse up event finish
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame   # one frame = finger released

	# 3. open editor
	var popup := preload("res://ui/item_editor.tscn").instantiate()
	popup.item_saved.connect(func(): sc.scroll_vertical = _saved_scroll; _close_editor(popup))
	popup.item_canceled.connect(func(): sc.scroll_vertical = _saved_scroll; _close_editor(popup))
	popup.item_deleted.connect(func(): sc.scroll_vertical = _saved_scroll; _close_editor(popup))
	add_child(popup)
	if id != "-1":
		popup.edit_item(id)
	else:
		popup.new_item()
	popup.show()


func _close_editor(popup: Window) -> void:
	var sc: ScrollContainer = %Scroll
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	popup.queue_free()
	sc.scroll_vertical = _saved_scroll

	#ItemRowManager.mark_order_dirty()
	ItemRowManager.rebuild_for_mode(shopping_mode)
	_refresh()
	print("close_editor, scrollpos: " + str(_saved_scroll))



func _edit_item(id: String) -> void:
	if shopping_mode == true:
		info("edit_item in shopping: " + id)
	info("edit_item: " + id)
	_open_editor(id)


func _on_add() -> void:
	_open_editor("-1")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://ui/setup_screen.tscn")


func _on_tools() -> void:
	get_tree().change_scene_to_file("res://ui/tools_screen.tscn")


func _on_shopping_toggle() -> void:
	# ---------- baseline timer ----------
	var t0 := Time.get_ticks_msec()
	# -------------------------------------
	# remember scroll_pos
	var sc : ScrollContainer = %Scroll
	if DB.shopping_mode:
		_saved_shopping_scroll = sc.scroll_vertical
	else:
		_saved_planning_scroll = sc.scroll_vertical

	DB.shopping_mode = !DB.shopping_mode
	#toggle_shopping_mode_btn.text = "📋" if DB.shopping_mode else "🛒"
	# Preload the icons (use preload for performance, or load() if paths are dynamic)
	var notepad_icon = preload("res://icons/notepad.svg")
	#var cart_icon = preload("res://icons/cart.png")
	var cart_icon = preload("res://icons/cart.svg")

	# Set the button's icon based on the condition
	toggle_shopping_mode_btn.icon = notepad_icon if DB.shopping_mode else cart_icon
	if DB.shopping_mode:
		pass
# NC		ItemRowManager.mark_order_dirty()
	_update_app_title()
	_refresh()
	# ---------- log result ----------
	var dt := Time.get_ticks_msec() - t0
	prints("BASELINE_MODE_SWITCH_MS", dt, "visible", ItemRowManager.get_visible_count())
	# --------------------------------

func _on_in_cart_changed(my_item_id: String) -> void:
	DB.toggle_in_cart(my_item_id)
	#ItemRowManager.mark_order_dirty()   # <-- NEW: shopping order changed
	ItemRowManager.rebuild_for_mode(shopping_mode)
	_refresh()
	print("in_cart_changed for: " + my_item_id)


func _on_category_edit_pressed():
	category_editor.popup_category_editor()


func _on_categories_changed():
	_refresh_category_filter()
	#ItemRowManager.mark_order_dirty()
	ItemRowManager.rebuild_for_mode(shopping_mode)
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
	var t := Timer.new()

	#info(str(event))
	#if event is InputEventKey and event.pressed:
		#print(OS.get_keycode_string(event.keycode))
	if event is InputEventKey and event.keycode in [KEY_BACK, KEY_ESCAPE] and event.pressed:
		if(DB.shopping_mode):
			_on_shopping_toggle()
			return
		print("Application Quit")
		get_tree().quit()
		
	if event is InputEventScreenTouch:
		if event.pressed:
			print("touch event.pressed")
			touch_start_time = Time.get_unix_time_from_system()
			touch_start_pos  = event.position
			has_moved = false
			is_scrolling = false
			t = Timer.new()
			t.wait_time = LONG_PRESS_TIME
			t.one_shot = true
			is_long_pressed = false
			add_child(t)
			t.timeout.connect(_on_long_press_detected)
			t.start()
		else:
			print(str(event))
			var dur := Time.get_unix_time_from_system() - touch_start_time
			var dist : float = (event.position - touch_start_pos).length()
			for c in get_children():
				if c is Timer and c.wait_time == LONG_PRESS_TIME:
					c.queue_free() # remove long_press timer
			if not has_moved and not is_scrolling and dist < TAP_MAX_DISTANCE:
				# --- pick item under cursor ---
				active_item = _pick_item(event.position)
				if active_item == null:
					return

				item_id = active_item.item_id
				my_item = active_item.my_item
				info("active_item: " + item_id)
				if is_long_pressed:
					_edit_item(item_id)
					return
				if DB.shopping_mode:
					#in_cart_changed.emit(item_id)
					in_cart = DB.toggle_in_cart(item_id)
					my_item.set("in_cart", in_cart)
					active_item.update_from_item(my_item)
					#print("toggle in_cart, dur: " + str(dur) + " dist: " + str(dist) + " : " + str(in_cart))
					ItemRowManager.resort_incart_window()   # <-- NEW
					print("toggle in_cart, id: " + item_id + " : " + str(in_cart))
					ItemRowManager.rebuild_for_mode(shopping_mode)
					_refresh() # NC: does that fix sorting in shopping mode?
					print("refresh done")
				else:
					needed = DB.toggle_needed(item_id)
					my_item.set("needed", needed)
					active_item.update_from_item(my_item)
					print("toggle needed, id: " + item_id +  " needed: " + str(needed))

				active_item._show_tap_feedback()
				print("planning_screen after tap_feedback, dur = ", dur)

	elif event is InputEventScreenDrag:
		var dist : float = (event.position - touch_start_pos).length()
		if dist > SCROLL_THRESHOLD:
			has_moved = true
			is_scrolling = true
	if event is InputEventMouseButton and event.button_index == 1 and not event.pressed:
		print("Left mouse button released")
		for c in get_children():
			if c is Timer and c.wait_time == LONG_PRESS_TIME:
				c.queue_free() # remove long_press timer 
	#print("event = " + str(event))

func _on_long_press_detected() -> void:
	if not has_moved and not is_scrolling:
		print("ps long press detected")
		is_long_pressed = true

		long_pressed.emit(item_id)


#func _pick_item(pos: Vector2) -> Control:
	#var scroll_rect = %Scroll.get_rect() # determine the current rect of the scroll area
	## print(str(pos) + " " + str(scroll_rect) + " " + str($%Scroll.get_global_transform()))
	#if not scroll_rect.has_point(pos): # skip if not within scroll rect
		#info("_pick_item not within scroll_rect")
		#return
	#var count := item_list.get_child_count()
#
	## Iterate from topmost to bottommost child for correct "visual hit"
	#for i in range(count - 1, -1, -1):
		#var cand := item_list.get_child(i)
		## added visibility check because it would find wrong items
		#if cand is Control and cand.visible == true:
			#var rect: Rect2 = cand.get_global_rect()
			#if rect.has_point(pos):
				##print("pick: " + str(cand) + " : " + str(cand.get_children()))
				#return cand
	#print("pick found no candidate")
	#return null

# res://ui/planning_screen.gd
func _pick_item(pos: Vector2) -> ItemRow:
	# pos is in PlanningScreen coordinate space
	var sc: ScrollContainer = %Scroll
	if not sc.get_global_rect().has_point(pos):
		return null

	# convert to scroll-inner space
	var local_pos := sc.get_local_mouse_position()
	# account for current scroll
	local_pos.y += sc.scroll_vertical

	# which logical row index is under the finger?
	var row_idx := int(local_pos.y / ROW_HEIGHT)
	if row_idx < 0 or row_idx >= ItemRowManager._visible_indices.size():
		return null

	# map logical index → pool index
	var pool_idx := row_idx - ItemRowManager.window_first
	if pool_idx < 0 or pool_idx >= ItemRowManager.pool_used:
		return null

	return ItemRowManager.pool[pool_idx] as ItemRow
