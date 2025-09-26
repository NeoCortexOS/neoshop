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
			#2:
				#if not _migrate_v2_to_v3(db):
					#return false
				#print("DB migration to 3")
				#_update_version(db, 3)
				#current = 3
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
	var ddl = [
		# ---------- category ----------
		"CREATE TABLE IF NOT EXISTS category (
			id         INTEGER PRIMARY KEY,
			name       TEXT UNIQUE,
			updated_at INTEGER NOT NULL DEFAULT (unixepoch('subsec')*1000),
			sync_flag  INTEGER NOT NULL DEFAULT 0
		)",
		# ---------- item ----------
		"CREATE TABLE IF NOT EXISTS item (
			id          INTEGER PRIMARY KEY,
			name        TEXT NOT NULL,
			amount      REAL,
			unit        TEXT,
			description TEXT,
			category_id INTEGER REFERENCES category(id) ON DELETE SET NULL,
			needed      BOOLEAN DEFAULT 0,
			in_cart     BOOLEAN DEFAULT 0,
			last_bought INTEGER,
			price_cents INTEGER,
			on_sale     BOOLEAN DEFAULT 0,
			updated_at  INTEGER NOT NULL DEFAULT (unixepoch('subsec')*1000),
			sync_flag   INTEGER NOT NULL DEFAULT 0
		)",
		# ---------- shop ----------
		"CREATE TABLE IF NOT EXISTS shop (
			id         INTEGER PRIMARY KEY,
			name       TEXT UNIQUE,
			sort_order TEXT,
			updated_at INTEGER NOT NULL DEFAULT (unixepoch('subsec')*1000),
			sync_flag  INTEGER NOT NULL DEFAULT 0
		)",
		# ---------- config ----------
		"CREATE TABLE IF NOT EXISTS config (
			key        TEXT PRIMARY KEY,
			value      TEXT,
			updated_at INTEGER NOT NULL DEFAULT (unixepoch('subsec')*1000),
			sync_flag  INTEGER NOT NULL DEFAULT 0
		)"
	]
	for sql in ddl:
		if not db.query(sql):
			push_error("Migration v0→v1 failed: " + sql)
			return false
	return true


func _migrate_v1_to_v2(db) -> bool:
	var ddl = [
		"CREATE TABLE item_v2 (
			id          TEXT PRIMARY KEY,
			name        TEXT NOT NULL,
			amount      REAL,
			unit        TEXT,
			description TEXT,
			category_id INTEGER REFERENCES category(id) ON DELETE SET NULL,
			needed      BOOLEAN DEFAULT 0,
			in_cart     BOOLEAN DEFAULT 0,
			last_bought INTEGER,
			price_cents INTEGER,
			on_sale     BOOLEAN DEFAULT 0,
			updated_at  INTEGER NOT NULL DEFAULT (unixepoch('subsec')*1000),
			sync_flag   INTEGER NOT NULL DEFAULT 0
		);",
		"INSERT INTO item_v2 SELECT
			lower(hex(randomblob(16))), name, amount, unit, description,
			category_id, needed, in_cart, last_bought, price_cents, on_sale,
			updated_at, sync_flag
			FROM item;",
		"DROP TABLE item;",
		"ALTER TABLE item_v2 RENAME TO item;"
	]
	for sql in ddl:
		if not db.query(sql):
			push_error("Migration v1→v2 failed: " + sql); return false
	return true
