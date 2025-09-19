# res://db/database.gd
extends Node

var _db: SQLite
var db_path := "user://neoshop.db"
#var _migration: Migration
var shopping_mode : bool = false


func _ready():
	_db = SQLite.new()
	_db.path = db_path
	#_db.verbosity_level = SQLite.VERBOSE
	_db.verbosity_level = SQLite.QUIET
	var _migration = preload("res://db/migration.gd").new()

	var success = _db.open_db()
	if not success:
		push_error("Failed to open database")
		return
	
	# Run migrations
	if not _migration.check_and_migrate(_db):
		push_error("Database migration failed")
		return
	
	print("Database ready, version: ", _migration.CURRENT_VERSION)
	
	#_db.path = ProjectSettings.globalize_path("user://neoshop.db")
	print("Database path: ", _db.path)
	print("Directory exists: ", DirAccess.dir_exists_absolute(_db.path.get_base_dir()))
	
	TranslationServer.set_locale(DB.get_config("language", "en"))


func _table_exists(table:String) -> bool:
	var success = _db.query_with_bindings("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", [table])
	print("godot sql table: ", table, " result: ", success)
	return _db.query_result.size() > 0


# ---------- generic dirty mark ----------
func _touch(table: String, id: int) -> void:
	var sql = "UPDATE %s SET updated_at = (unixepoch('subsec')*1000), sync_flag = 1 WHERE id = ?" % table
	var success = _db.query_with_bindings(sql, [id])
	if not success:
		push_error("Failed to touch %s id %d" % [table, id])


# --------------------------------------------------------------
# Category
# --------------------------------------------------------------
func insert_category(cat_name: String) -> int:
	var success = _db.query_with_bindings(
		"INSERT INTO category(name,updated_at,sync_flag) VALUES (?,unixepoch('subsec')*1000,1)", [cat_name])
	if not success:
		push_error("Failed to insert category: " + cat_name)
		return -1
	return int(_db.get_last_insert_rowid())


func update_category(id: int, cat_name: String) -> void:
	var success = _db.query_with_bindings(
		"UPDATE category SET name = ?, updated_at = unixepoch('subsec')*1000, sync_flag = 1 WHERE id = ?", [cat_name, id])
	if not success:
		push_error("Failed to update category: " + str(id))


func delete_category(id: int) -> void:
	# soft delete
	var success = _db.query_with_bindings(
		"UPDATE category SET sync_flag = 3, updated_at = unixepoch('subsec')*1000 WHERE id = ?", [id])
	if not success:
		push_error("Failed to soft-delete category: " + str(id))


func select_categories() -> Array:
	_db.query("SELECT * FROM category ORDER BY name")
	return _db.query_result
# --------------------------------------------------------------
# Item
# --------------------------------------------------------------
# Update insert_item to handle new columns
func insert_item(p: Dictionary) -> int:
	p["updated_at"] = Time.get_unix_time_from_system()*1000
	p["sync_flag"]  = 1
	var query = """
		INSERT INTO item (name, amount, unit, description, category_id,
						  needed, in_cart, last_bought, price_cents, on_sale,
						  updated_at, sync_flag)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
	"""
	var params = [
		p.get("name", ""),
		p.get("amount", 0.0),
		p.get("unit", ""),
		p.get("description", ""),
		p.get("category_id", -1),
		p.get("needed", false),
		p.get("in_cart", false),
		p.get("last_bought", 0),
		p.get("price_cents", 0),
		p.get("on_sale", false),
		p["updated_at"],
		p["sync_flag"]
	]
	var success = _db.query_with_bindings(query, params)
	if success:
		return int(_db.get_last_insert_rowid())
	push_error("Insert item failed")
	return -1


func update_item(p: Dictionary) -> void:
	p["updated_at"] = Time.get_unix_time_from_system()*1000
	p["sync_flag"]  = 1
	var query = """
		UPDATE item SET
			name = ?, amount = ?, unit = ?, description = ?, category_id = ?,
			needed = ?, in_cart = ?, last_bought = ?, price_cents = ?, on_sale = ?,
			updated_at = ?, sync_flag = ?
		WHERE id = ?
	"""
	var params = [
		p.get("name", ""),
		p.get("amount", 0.0),
		p.get("unit", ""),
		p.get("description", ""),
		p.get("category_id", -1),
		p.get("needed", false),
		p.get("in_cart", false),
		p.get("last_bought", 0),
		p.get("price_cents", 0),
		p.get("on_sale", false),
		p["updated_at"],
		p["sync_flag"],
		p.get("id", -1)
	]
	var success = _db.query_with_bindings(query, params)
	if not success:
		push_error("Failed to update item: " + str(p.get("id", -1)))


func select_items(where_sql := "", params := []) -> Array:
	var sql := "SELECT * FROM item"
	if not where_sql.is_empty():
		sql += " WHERE " + where_sql
	sql += " ORDER BY name COLLATE NOCASE"
	_db.query_with_bindings(sql, params)
	return _db.query_result

func delete_item(id: int) -> void:
	var success = _db.query_with_bindings(
		"UPDATE item SET sync_flag = 3, updated_at = unixepoch('subsec')*1000 WHERE id = ?", [id])
	if not success:
		push_error("Failed to soft-delete item: " + str(id))

func toggle_needed(id: int, needed: bool) -> void:
	var success = _db.query_with_bindings(
		"UPDATE item SET needed = ?, updated_at = unixepoch('subsec')*1000, sync_flag = 1 WHERE id = ?",
		[needed, id])
	if not success:
		push_error("Failed to toggle needed: " + str(id))
	print("DB toggle_needed id: ", id, " need: ", needed)


func toggle_in_cart(id: int) -> void:
	# atomic: flip in_cart, touch updated_at, set last_bought if newly moved into cart
	var sql = """
		UPDATE item
		SET in_cart = NOT in_cart,
			updated_at = unixepoch('subsec')*1000,
			sync_flag = 1,
			last_bought = CASE
				WHEN (NOT in_cart) THEN unixepoch('subsec')
				ELSE last_bought
			END
		WHERE id = ?
	"""
	var success = _db.query_with_bindings(sql, [id])
	if not success:
		push_error("Failed to toggle in_cart: " + str(id))
	print("DB toggle_in_cart, id: ", id)


func select_item_count() -> int:
	_db.query("SELECT COUNT(*) AS c FROM item")
	return int(_db.query_result[0]["c"])


# Returns a user-friendly DB name (file name without path)
func get_db_name() -> String:
	return _db.path.get_file()

func get_config(key: String, default := "") -> String:
	var ok := _db.query_with_bindings("SELECT value FROM config WHERE key = ?", [key])
	if ok and _db.query_result.size() > 0:
		return str(_db.query_result[0]["value"])
	return default

func set_config(key: String, value: String) -> void:
	_db.query_with_bindings(
		"INSERT OR REPLACE INTO config(key, value) VALUES (?, ?)",
		[key, value]
	)


# ---------- sync helpers ----------
func select_dirty(table: String) -> Array:
	var success = _db.query_with_bindings("SELECT * FROM " + table + " WHERE sync_flag != 0 ORDER BY updated_at", [])
	print("DB.select_dirty: ", success)
	return _db.query_result if success else []

func mark_clean(table: String, id: int) -> void:
	var success = _db.query_with_bindings("UPDATE %s SET sync_flag = 0 WHERE id = ?" % table, [id])
	if not success:
		push_error("Failed to mark clean %s id %d" % [table, id])
