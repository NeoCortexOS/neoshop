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
	
# --------------------------------------------------------------
# Category
# --------------------------------------------------------------
@warning_ignore("shadowed_variable_base_class")
#func insert_category(name: String) -> int:
	#_db.query_with_bindings("INSERT INTO category(name) VALUES (?)", [name])
	#_db.query("SELECT last_insert_rowid() AS id")
	#return int(_db.query_result[0]["id"])
func insert_category(name: String) -> int:
	var query = "INSERT INTO category (name) VALUES (?)"
	var success = _db.query_with_bindings(query, [name])
	if success:
		print("Insert successful: " + name)
		return int(_db.get_last_insert_rowid())
	else:
		push_error("Failed to insert category: " + name)
		return -1


@warning_ignore("shadowed_variable_base_class")
func update_category(id: int, name: String) -> void:
	var query = "UPDATE category SET name = ? WHERE id = ?"
	var success = _db.query_with_bindings(query, [name, id])
	if not success:
		push_error("Failed to update category: " + str(id))

func delete_category(id: int) -> void:
	var query = "DELETE FROM category WHERE id = ?"
	var success = _db.query_with_bindings(query, [id])
	if not success:
		push_error("Failed to delete category: " + str(id))


func select_categories() -> Array:
	_db.query("SELECT * FROM category ORDER BY name")
	return _db.query_result
# --------------------------------------------------------------
# Item
# --------------------------------------------------------------
# Update insert_item to handle new columns
func insert_item(p: Dictionary) -> int:
	print("Attempting to insert item:", p)
	var query = """
	INSERT INTO item (name, amount, unit, description, category_id, needed, in_cart, last_bought, price_cents, on_sale)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
		p.get("on_sale", false)
	]
	
	var success = _db.query_with_bindings(query, params)
	if success:
		print("Insert successful, ID:", p.get("id"))
		return int(_db.get_last_insert_rowid())

	print("Insert failed - SQLite error: ", _db.error_message if _db.has_method("error_message") else "Unknown error")
	return -1


func update_item(p: Dictionary) -> void:
	var query = """
	UPDATE item SET 
		name = ?, amount = ?, unit = ?, description = ?, category_id = ?, 
		needed = ?, in_cart = ?, last_bought = ?, price_cents = ?, on_sale = ?
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
		p.get("id", -1)
	]
	
	_db.query_with_bindings(query, params)


func select_items(where_sql := "", params := []) -> Array:
	var sql := "SELECT * FROM item"
	if not where_sql.is_empty():
		sql += " WHERE " + where_sql
	sql += " ORDER BY name COLLATE NOCASE"
	_db.query_with_bindings(sql, params)
	return _db.query_result

func delete_item(id: int) -> void:
	_db.query_with_bindings("DELETE FROM item WHERE id = ?", [id])


func toggle_needed(id: int, needed: bool) -> void:
	_db.query_with_bindings(
		"UPDATE item SET needed = ? WHERE id = ?", [needed, id])
	print("DB toggle_needed id: ", id, " need: ", needed)


func toggle_in_cart(id: int) -> void:
	_db.query_with_bindings("UPDATE item SET in_cart = NOT in_cart WHERE id = ?", [id])
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
