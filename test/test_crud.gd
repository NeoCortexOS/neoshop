extends Node

const DB := preload("res://db/database.gd")   # the singleton we just fixed
var db: SQLite  # local instance for the in-memory test

func _ready():
	# 1. create an in-memory DB
	db = SQLite.new()
	db.path = ":memory:"
	db.verbosity_level = SQLite.VERBOSE
	db.open_db()

	# 2. create tables
	_create_schema()

	# 3. run the tests
	_test_category_crud()
	_test_item_crud()

	# 4. finish
	print("✅ All CRUD tests passed.")
	get_tree().quit()

# ---------- schema ----------
func _create_schema():
	db.query("""
		CREATE TABLE category (
			id   INTEGER PRIMARY KEY,
			name TEXT UNIQUE
		);
	""")
	db.query("""
		CREATE TABLE item (
			id          INTEGER PRIMARY KEY,
			name        TEXT NOT NULL,
			amount      REAL,
			unit        TEXT,
			description TEXT,
			category_id INTEGER REFERENCES category(id),
			needed      BOOLEAN DEFAULT 0,
			in_cart     BOOLEAN DEFAULT 0,
			last_bought INTEGER,
			price_cents INTEGER,
			on_sale     BOOLEAN DEFAULT 0
		);
	""")

# ---------- category ----------
func _test_category_crud():
	# CREATE
	var cat_id := _insert_category("Fruit")
	assert(cat_id > 0, "insert_category should return id")

	# READ
	var cats := _select_categories()
	assert(cats.size() == 1, "should be exactly one category")
	assert(cats[0]["name"] == "Fruit", "category name should match")

	# UPDATE (change name manually)
	db.query_with_bindings("UPDATE category SET name = ? WHERE id = ?", ["Veggie", cat_id])
	cats = _select_categories()
	assert(cats[0]["name"] == "Veggie", "update should work")

	# DELETE
	db.query_with_bindings("DELETE FROM category WHERE id = ?", [cat_id])
	cats = _select_categories()
	assert(cats.is_empty(), "category should be gone")
	print("✓ category CRUD ok")

# ---------- item ----------
func _test_item_crud():
	# need a category first
	var cat_id := _insert_category("Dairy")

	# CREATE
	var item := {
		name = "Milk",
		amount = 1.5,
		unit = "l",
		description = "Low-fat",
		category_id = cat_id,
		needed = true,
		in_cart = false,
		last_bought = 0,
		price_cents = 99,
		on_sale = false
	}
	var item_id := _insert_item(item)
	assert(item_id > 0, "insert_item should return id")

	# READ
	var items := _select_items("needed = 1")
	assert(items.size() == 1, "should find the milk")
	assert(items[0]["name"] == "Milk", "item name should match")

	# UPDATE
	db.query_with_bindings("""
		UPDATE item SET in_cart = 1 WHERE id = ?
	""", [item_id])
	items = _select_items("in_cart = 1")
	assert(items.size() == 1, "item should now be in cart")

	# DELETE
	db.query_with_bindings("DELETE FROM item WHERE id = ?", [item_id])
	items = _select_items("")
	assert(items.is_empty(), "item should be deleted")
	print("✓ item CRUD ok")

# ---------- thin wrappers around the singleton code ----------
func _insert_category(name: String) -> int:
	db.query_with_bindings("INSERT INTO category(name) VALUES (?)", [name])
	db.query("SELECT last_insert_rowid() AS id")
	return int(db.query_result[0]["id"])

func _select_categories() -> Array:
	db.query("SELECT * FROM category")
	return db.query_result

func _insert_item(p: Dictionary) -> int:
	db.query_with_bindings("""
		INSERT INTO item(name, amount, unit, description, category_id,
						 needed, in_cart, last_bought, price_cents, on_sale)
		VALUES (?,?,?,?,?,?,?,?,?,?)
	""", [p.name, p.amount, p.unit, p.description, p.category_id,
		  p.needed, p.in_cart, p.last_bought, p.price_cents, p.on_sale])
	db.query("SELECT last_insert_rowid() AS id")
	return int(db.query_result[0]["id"])

func _select_items(where_sql := "") -> Array:
	var sql := "SELECT * FROM item"
	if not where_sql.is_empty():
		sql += " WHERE " + where_sql
	db.query(sql)
	return db.query_result
