# res://db/migration.gd
extends Node

const CURRENT_VERSION = 2

func check_and_migrate(db) -> bool:
	var current_version = _get_schema_version(db)
	
	if current_version < CURRENT_VERSION:
		print("Migrating database from version %d to %d" % [current_version, CURRENT_VERSION])
		return _perform_migration(db, current_version)
	
	return true

func _get_schema_version(db) -> int:
	# Check if config table exists
	var success = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='config'")
	if not success or db.query_result.size() == 0:
		return 0
	
	# Check if version is stored
	success = db.query("SELECT value FROM config WHERE key='schema_version'")
	if success and db.query_result.size() > 0:
		return int(db.query_result[0]["value"])
	
	return 1  # Default if no version stored

func _perform_migration(db, from_version: int) -> bool:
	var current = from_version
	
	while current < CURRENT_VERSION:
		print("current: ", current)
		match current:
			0:
				if not _migrate_v0_to_v1(db):
					return false
				print("DB migration to 1")
				_update_version(db, 1)
				current = 1
			1:
				if not _migrate_v1_to_v2(db):
					return false
				print("DB migration to 2")
				_update_version(db, 2)
				current = 2
			_:
				break
	
	# Final version update
	_update_version(db, CURRENT_VERSION)
	return true

func _update_version(db, version: int) -> void:
	db.query_with_bindings(
		"INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
		["schema_version", str(version)]
	)

func _migrate_v0_to_v1(db) -> bool:
	var tables = [
		"CREATE TABLE IF NOT EXISTS category (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)",
		"CREATE TABLE IF NOT EXISTS item (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL, unit TEXT, description TEXT, category_id INTEGER, needed BOOLEAN DEFAULT 0, last_bought INTEGER, price_cents INTEGER, on_sale BOOLEAN DEFAULT 0)",
		"CREATE TABLE IF NOT EXISTS shop (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, sort_order TEXT)",
		"CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT)"
	]
	
	for sql in tables:
		if not db.query(sql):
			push_error("Migration v0->v1 failed: " + sql)
			return false
	
	return true

func _migrate_v1_to_v2(db) -> bool:
	# Check if column exists
	var success = db.query("PRAGMA table_info(item)")
	if success and db.query_result.size() > 0:
		for column in db.query_result:
			if column["name"] == "in_cart":
				return true  # Already exists
	
	# Add the column
	return db.query("ALTER TABLE item ADD COLUMN in_cart BOOLEAN DEFAULT 0")
