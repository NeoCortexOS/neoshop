extends Node
class_name ThemeMgr

const LIGHT := preload("res://themes/material_light.tres")
const DARK  := preload("res://themes/material_dark.tres")

func apply_theme(tname: String) -> void:
	match tname:
		"light":
			get_tree().root.theme = LIGHT
		"dark":
			get_tree().root.theme = DARK
		"system":
			_apply_system_theme()
	_save_config(tname)

func _apply_system_theme() -> void:
	# simple fallback; extend with OS detection later
	get_tree().root.theme = LIGHT

func _save_config(tname: String) -> void:
	DB._db.query_with_bindings(
		"INSERT OR REPLACE INTO config(key,value) VALUES(?,?)",
		["theme", tname]
	)
