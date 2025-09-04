# res://scripts/i18n_helper.gd   (lowercase file name)
extends Node
class_name I18nHlp  # different class name

const CSV_PATH := "res://assets/i18n/%s.csv"
var _locales := ["en", "de"]
var _current := "en"
var _strings := {}

func _ready():
	_load_locale("en")

func set_locale(code: String) -> void:
	if code in _locales:
		_load_locale(code)
		_save_config(code)
		_update_all_tr_nodes()

func _load_locale(code: String) -> void:
	var path := CSV_PATH % code
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Locale not found: %s" % code)
		return
	_strings.clear()
	file.get_line()
	while not file.eof_reached():
		var line := file.get_csv_line(";")
		if line.size() >= 3:
			_strings[line[0]] = line[2] if OS.get_locale().begins_with("de") else line[1]
	_current = code

func t(key: String) -> String:
	return _strings.get(key, key)

func _save_config(code: String) -> void:
	DB._db.query_with_bindings(
		"INSERT OR REPLACE INTO config(key,value) VALUES(?,?)",
		["language", code]
	)

func _update_all_tr_nodes() -> void:
	for n in get_tree().get_root().get_children():
		n.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
