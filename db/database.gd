# res://db/database.gd
extends Node

const SCHEMA_FILE := "res://db/schema.sql"
var _db: SQLite

func _ready():
	_db = SQLite.new()
	_db.path = ProjectSettings.globalize_path("user://neoshop.db")
	#_db.verbosity_level = SQLite.VERBOSE
	_db.verbosity_level = SQLite.QUIET
	_db.open_db()
	_migrate()

func _migrate() -> void:
	# Only run each DDL statement if the table does not yet exist
	var tables := ["category", "item", "shop", "config"]
	for table in tables:
		if not _table_exists(table):
			var ddl := FileAccess.open(SCHEMA_FILE, FileAccess.READ).get_as_text()
			_db.query(ddl)
			break   # once per new install is enough

func _table_exists(table:String) -> bool:
	_db.query_with_bindings("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", [table])
	return _db.query_result.size() > 0
	
# --------------------------------------------------------------
# Category
# --------------------------------------------------------------
@warning_ignore("shadowed_variable_base_class")
func insert_category(name: String) -> int:
	_db.query_with_bindings("INSERT INTO category(name) VALUES (?)", [name])
	_db.query("SELECT last_insert_rowid() AS id")
	return int(_db.query_result[0]["id"])

func select_categories() -> Array:
	_db.query("SELECT * FROM category ORDER BY name")
	return _db.query_result

func delete_category(id: int) -> void:
	_db.query_with_bindings("DELETE FROM category WHERE id = ?", [id])

# --------------------------------------------------------------
# Item
# --------------------------------------------------------------
func insert_item(p: Dictionary) -> int:
	_db.query_with_bindings("""
		INSERT INTO item(name, amount, unit, description, category_id,
						 needed, in_cart, last_bought, price_cents, on_sale)
		VALUES (?,?,?,?,?,?,?,?,?,?)
	""", [p.name, p.amount, p.unit, p.description, p.category_id,
		  p.needed, p.in_cart, p.last_bought, p.price_cents, p.on_sale])
	_db.query("SELECT last_insert_rowid() AS id")
	return int(_db.query_result[0]["id"])

func update_item(p: Dictionary) -> void:
	_db.query_with_bindings("""
		UPDATE item
		SET name=?, amount=?, unit=?, description=?, category_id=?,
			needed=?, in_cart=?, last_bought=?, price_cents=?, on_sale=?
		WHERE id = ?
	""", [p.name, p.amount, p.unit, p.description, p.category_id,
		  p.needed, p.in_cart, p.last_bought, p.price_cents, p.on_sale,
		  p.id])

func select_items(where_sql := "", params := []) -> Array:
	var sql := "SELECT * FROM item"
	if not where_sql.is_empty():
		sql += " WHERE " + where_sql
	sql += " ORDER BY name COLLATE NOCASE"
	_db.query_with_bindings(sql, params)
	return _db.query_result

func delete_item(id: int) -> void:
	_db.query_with_bindings("DELETE FROM item WHERE id = ?", [id])

func toggle_in_cart(id: int) -> void:
	_db.query_with_bindings("UPDATE item SET in_cart = NOT in_cart WHERE id = ?", [id])

func select_item_count() -> int:
	_db.query("SELECT COUNT(*) AS c FROM item")
	return int(_db.query_result[0]["c"])

# Returns a user-friendly DB name (file name without path)
func get_db_name() -> String:
	return _db.path.get_file()

func toggle_needed(id: int, needed: bool) -> void:
	_db.query_with_bindings(
		"UPDATE item SET needed = ? WHERE id = ?", [needed, id])
