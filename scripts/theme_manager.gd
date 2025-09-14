extends Node
class_name ThemeMgr

const LIGHT := preload("res://themes/material_light.tres")
const DARK  := preload("res://themes/material_dark.tres")
const CLASSIC  := preload("res://themes/material_classic.tres")

func apply_theme(tname: String) -> void:
	match tname:
		"light":
			get_tree().root.theme = LIGHT
		"dark":
			get_tree().root.theme = DARK
		"classic":
			get_tree().root.theme = CLASSIC
	_save_config(tname)
	print("Theme applied: ", tname)

func _save_config(tname: String) -> void:
	DB._db.query_with_bindings(
		"INSERT OR REPLACE INTO config(key,value) VALUES(?,?)",
		["theme", tname]
	)
