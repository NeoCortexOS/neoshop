# res://scripts/item_row_manager.gd
extends Node
class_name ItemRowMgr

const ROW_SCENE := preload("res://ui/item_row.tscn")
const PB := preload("res://addons/godex_ui_profiler/profile_block.gd")

var list : Node = null
var _pool: Array[ItemRow] = []
var _id_to_row: Dictionary = {}
var items : Array = []
var _sort_cache: Dictionary = {}        # id -> normalised key

var _full_items: Array[Dictionary] = []          # 1. cached DB result
var _rows_ordered: Array[ItemRow] = []           # 2. current visual order
var _order_dirty : bool = true


func _ready() -> void:
	list = get_tree().current_scene.get_node("%ItemList")
	_sort_cache.clear()
	_rebuild_pool()                                # pull setup logic into its own func


func _rebuild_pool() -> void:
	var _prof := PB.ms("_rebuild")

	# clear old pool
	for r in _pool:
		r.queue_free()
	_pool.clear()
	_id_to_row.clear()
	_rows_ordered.clear()

	_full_items = DB.select_items()                # single DB hit
	for it in _full_items:
		_sort_cache[it.id] = _german_key(str(it.name))
	_full_items.sort_custom(Callable(self, "_german_cmp_cached"))

	for it in _full_items:
		var row := ROW_SCENE.instantiate()
		row.setup(it)
		row.set_meta("item_dict", it)
		row.hide()
		_pool.append(row)
		_id_to_row[it.id] = row
		list.add_child(row)
	_prof.finish()



func _german_cmp_cached(a: Dictionary, b: Dictionary) -> bool:
	return _sort_cache[a.id] < _sort_cache[b.id]


func _german_cmp(a: Dictionary, b: Dictionary) -> bool:
	# German collation helper (re-usable)
	var sa := str(a.name).to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")
	var sb := str(b.name).to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")
	return sa < sb


func _german_cmp_str(a: String, b: String) -> bool:
	# German collation helper (re-usable)
	var sa := a.to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")
	var sb := b.to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")
	return sa < sb


func _german_key(name: String) -> String:
	return name.to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")


# NEW – rebuild order without re-instantiating
func rebuild_for_mode(shopping_mode: bool) -> void:
	# 1. detach all rows from parent (keeps them alive)
	#for r in _rows_ordered:
	for r in _pool:
		if r.get_parent() == list:
			list.remove_child(r)

	# 2. choose sorting
	if shopping_mode:
		print("SORT-SHOPPING")
		var t0 := Time.get_ticks_msec()
		_full_items.sort_custom(Callable(self,"_shopping_cmp_cached"))
		print("SORT-SHOPPING", " ", Time.get_ticks_msec() - t0, " ms")
	else:
		print("SORT-PLANNING")
		_full_items.sort_custom(Callable(self, "_german_cmp_cached"))

	# 3. re-attach in new order
	#_rows_ordered.clear()
	
	var _prof := PB.ms("rebuild_for_mode rebuild list")
	var item_count : int = 0

	for it in _full_items:
		#if shopping_mode and !bool(it.get("needed",false)): continue   # SKIP non-needed
		var row: ItemRow = _id_to_row[it.id]
		list.add_child(row)
		#_rows_ordered.append(row)
		row.visible = true          # will be filtered later by PlanningScreen
		row.set_shopping_mode(shopping_mode)   # this fixed shopping_mode switch not updating visuals
		row.update_from_item(it)          # cheap, but touches labels & panels

		# ----- NEW: reset panel state for EVERY row -----
		#if (!shopping_mode):
			#row.get_node("inCartPanel").visible = false
			#row.get_node("delPanel").visible    = bool(it.get("is_deleted", false))
		#if(item_count < 10):
			#print ("ROW-MODE", shopping_mode, " id=", it.id)
		item_count += 1
	_prof.finish()
	print("items added to list: ", str(item_count))


#func _update_item_row(item):
		#var row: ItemRow = _id_to_row[item]
		#row.set_shopping_mode(shopping_mode)   # this fixed shopping_mode switch not updating visuals
		#row.update_from_item(it)          # cheap, but touches labels & panels
#

func _shopping_cmp(a: Dictionary, b: Dictionary) -> bool:
	# shopping:  not-in-cart first, then by category, then German alpha
	var a_cart := bool(a.get("in_cart", false))
	var b_cart := bool(b.get("in_cart", false))
	if a_cart != b_cart:
		return !a_cart						# false < true
	if !a_cart and !b_cart:					# both NOT in cart → category + alpha
		var cat_a : String = DB.catname.get(int(a.category_id), "")
		var cat_b : String = DB.catname.get(int(b.category_id), "")
		if cat_a != cat_b:
			#return cat_a < cat_b
			return _german_cmp_str(cat_a, cat_b)
	# same category or both in cart → German alpha
	return _german_cmp(a, b)


func _shopping_cmp_cached(a: Dictionary, b: Dictionary) -> bool:
	var a_cart := bool(a.get("in_cart", false))
	var b_cart := bool(b.get("in_cart", false))
	if a_cart != b_cart: return !a_cart
	if !a_cart and !b_cart:
		# both NOT in cart → category + alpha
		var cat_a : String = DB.catname.get(int(a.category_id), "")
		var cat_b : String = DB.catname.get(int(b.category_id), "")
		if cat_a != cat_b: 
			return _german_cmp_str(cat_a, cat_b)
	# both in cart → newest last_bought first
	var a_last : int = int(a.get("last_bought", 0))
	var b_last : int = int(b.get("last_bought", 0))
	if a_last != b_last: return a_last > b_last   # descending
	# tie-break: German alpha
	return _sort_cache[a.id] < _sort_cache[b.id]

	## same category or both IN cart → German alpha (last_bought is tie-breaker, not primary key)
	#return _sort_cache[a.id] < _sort_cache[b.id]

# ----------  scripts/item_row_manager.gd (add this method) ----------
func apply_filter(search_txt: String, cat_id: int, shopping_mode: bool) -> void:
	for row in _pool:
		var it: Dictionary = row.get_meta("item_dict")
		var show := true
		if it.get("is_deleted",false) and shopping_mode: show = false
		elif shopping_mode and !bool(it.get("needed",false)): show = false
		elif !search_txt.is_empty() and !str(it.name).to_lower().contains(search_txt): show = false
		elif cat_id != -2 and int(it.category_id) != cat_id: show = false
		row.visible = show


func mark_order_dirty() -> void:
	_order_dirty = true

func rebuild_if_dirty(shopping_mode : bool) -> void:
	#_order_dirty = true # force update
	if _order_dirty:
		rebuild_for_mode(shopping_mode)
		_order_dirty = false
	else:
		# order unchanged → only filter existing rows
		apply_filter("", -2, shopping_mode)   # will be overwritten by caller with real filter

func toggle_cart_dirty(item_id : String) -> void:
	# only the cart flag changed → no structural order change
	pass   # order stays identical, so _order_dirty remains false


# ----------  res://scripts/item_row_manager.gd  ----------
var _visual_batch_sz : int = 30
var _visual_idx      : int = 0
var _visual_mode     : bool = false

# Called from planning_screen._refresh_deferred after the filter pass
func refresh_visuals_async(shopping_mode : bool) -> void:
	_visual_mode    = shopping_mode
	_visual_idx     = 0
	# caller enables set_process(true) – we reuse the same timer slot

func process_visual_batch() -> bool:
	var rows := _pool
	var last : int = min(_visual_idx + _visual_batch_sz, rows.size())
	print("process_visual_batch: ", str(last))
	for i in range(_visual_idx, last):
		var row := rows[i]
		if row.visible:                       # only touch on-screen rows
			var it : Dictionary = row.get_meta("item_dict")
			row.set_shopping_mode(_visual_mode)   # <-- NEW: ensure mode is current
			row.update_from_item(it)          # cheap, but touches labels & panels
	_visual_idx = last
	return _visual_idx >= rows.size()        # true = finished
