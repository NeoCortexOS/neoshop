extends Node
class_name BackupMgr

const BACKUP_DIR := "user://backups"

func export_json() -> String:
	var ts := int(Time.get_unix_time_from_system())
	var fname := "neoshop_backup_%d.json" % ts
	var path := BACKUP_DIR.path_join(fname)

	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)

	var data := {
		"version": 2,
		"timestamp": ts,
		"categories": DB.select_categories(),
		"items": DB.select_items()
	}

	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json)
	file.close()

	return path

func import_json(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != 2:
		return false

	DB._db.query("BEGIN")
	DB._db.query("DELETE FROM item")
	DB._db.query("DELETE FROM category")

	for cat in data.categories:
		DB.insert_category(str(cat.name))

	for it in data.items:
		var dict = Dictionary(it)
		dict.erase("id")
		DB.insert_item(dict)

	DB._db.query("COMMIT")
	return true
