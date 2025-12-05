# res://scripts/item_row_manager.gd
extends Node
class_name ItemRowMgr

const ROW_SCENE := preload("res://ui/item_row.tscn")
var _pool: Array[ItemRow] = []
var _id_to_row: Dictionary = {}

func _ready() -> void:
	var list := get_tree().current_scene.get_node("%ItemList")
	var items := DB.select_items()
	for it in items:
		var row := ROW_SCENE.instantiate()
		row.setup(it)
		row.set_meta("item_dict", it)

		# ----------  NEW  ----------
		# same signal names you originally used in PlanningScreen
		row.long_pressed.connect(
			Callable(get_tree().current_scene, "_edit_item"), CONNECT_DEFERRED| CONNECT_ONE_SHOT)
		#row.needed_changed.connect(
		#	Callable(DB, "toggle_needed"), CONNECT_DEFERRED| CONNECT_ONE_SHOT)
		row.in_cart_changed.connect(
			Callable(get_tree().current_scene, "_on_in_cart_changed"), CONNECT_DEFERRED| CONNECT_ONE_SHOT)
		# ---------------------------

		row.hide()
		_pool.append(row)
		_id_to_row[it.id] = row
		list.add_child(row)

func apply_filter(search_txt: String, cat_id: int, shopping_mode: bool) -> void:
	# read-only loop, no allocate
	for row in _pool:
		var it : Dictionary = row.get_meta("item_dict")
		var visible := true
		if bool(it.get("is_deleted", false)): visible = false
		elif shopping_mode and !bool(it.get("needed", false)): visible = false
		elif !search_txt.is_empty() and !str(it.name).to_lower().contains(search_txt): visible = false
		elif cat_id != -2 and int(it.category_id) != cat_id: visible = false
		row.visible = visible
