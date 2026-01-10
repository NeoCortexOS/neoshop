extends Node
class_name ItemRowMgr

const ROW_SCENE := preload("res://ui/item_row.tscn")
const PB       := preload("res://addons/godex_ui_profiler/profile_block.gd")

const ROW_HEIGHT   := 128.0
const WINDOW_HALF  := 15
const POOL_SIZE    := WINDOW_HALF * 2 + 1

# ---------- data ----------
var _full_items      : Array[Dictionary] = []
var _visible_indices : Array[int] = []
var _sort_cache      : Dictionary = {}

# ---------- pool ----------
var pool       : Array[ItemRow] = []
var pool_used  : int = 0
var window_first : int = -1
var window_last  : int = -1

# ---------- init ----------
func _enter_tree() -> void:
	if !pool.is_empty(): return
	for i in POOL_SIZE:
		var r := ROW_SCENE.instantiate()
		r.hide()
		pool.append(r)

# ---------- public ----------
func get_visible_count() -> int:
	return _visible_indices.size()

func set_virtual_viewport(parent: Control) -> void:
	for n in pool: parent.add_child(n)

func rebuild_pool() -> void:
	var prof := PB.ms("rebuild_pool")
	_full_items = DB.select_items()
	_sort_cache.clear()
	for it in _full_items:
		_sort_cache[it.id] = _german_key(it.name)
	prof.finish()

func rebuild_for_mode(shopping_mode: bool) -> void:
	var prof := PB.ms("sort_only")
	if shopping_mode:
		_full_items.sort_custom(Callable(self,"_shopping_cmp_cached"))
	else:
		_full_items.sort_custom(Callable(self,"_german_cmp_cached"))
	prof.finish()

func apply_filter(search_txt: String, cat_id: int, shopping_mode: bool) -> void:
	var prof := PB.ms("apply_filter")
	_visible_indices.clear()
	for i in _full_items.size():
		var it := _full_items[i]
		if it.get("is_deleted",false): continue
		if shopping_mode and !it.get("needed",false): continue
		if !search_txt.is_empty() and !it.name.to_lower().contains(search_txt): continue
		if cat_id != -2 and int(it.category_id) != cat_id: continue
		_visible_indices.append(i)

	var vc := get_tree().current_scene.get_node_or_null("%VirtualContent")
	if is_instance_valid(vc):
		vc.custom_minimum_size.y = _visible_indices.size() * ROW_HEIGHT

	var scroll : float = get_tree().current_scene.get_node("%Scroll").get_v_scroll_bar().value
	_update_window(scroll)
	prof.finish()

# ---------- window ----------
func _update_window(scroll_y: float) -> void:
	if _visible_indices.is_empty(): return

	var first_vis := int(scroll_y / ROW_HEIGHT)
	var last_vis  := first_vis + WINDOW_HALF * 2
	first_vis = max(0, first_vis)
	last_vis  = min(_visible_indices.size() - 1, last_vis)

	if first_vis == window_first and last_vis == window_last: return
	window_first = first_vis
	window_last  = last_vis

	_reset_pool()
	pool_used = 0
	for logic_idx in range(window_first, window_last + 1):
		if logic_idx >= _visible_indices.size(): break
		var it := _full_items[_visible_indices[logic_idx]]
		var r := pool[pool_used]
		r.setup(it)
		r.update_from_item(it)
		r.set_shopping_mode(DB.shopping_mode)
		r.position.y = logic_idx * ROW_HEIGHT
		r.show()
		pool_used += 1

func _reset_pool() -> void:
	for n in pool: n.hide()
	pool_used = 0

# ---------- helpers ----------
func _german_key(s: String) -> String:
	return s.to_lower().replace("ä","ae").replace("ö","oe").replace("ü","ue").replace("ß","ss")

func _german_cmp_cached(a: Dictionary, b: Dictionary) -> bool:
	return _sort_cache[a.id] < _sort_cache[b.id]

func _shopping_cmp_cached(a: Dictionary, b: Dictionary) -> bool:
	var a_cart := bool(a.get("in_cart",false))
	var b_cart := bool(b.get("in_cart",false))
	if a_cart != b_cart: return !a_cart
	if !a_cart and !b_cart:
		var ca : String = DB.catname.get(int(a.category_id),"")
		var cb : String = DB.catname.get(int(b.category_id),"")
		if ca != cb: return ca < cb
	var al := int(a.get("last_bought",0))
	var bl := int(b.get("last_bought",0))
	if al != bl: return al > bl
	return _sort_cache[a.id] < _sort_cache[b.id]
