extends Node

const THEME_PATHS = {
	"material": "res://themes/material.tres",
	"light"   : "res://themes/light.tres",
	"dark"    : "res://themes/dark.tres"
}

func change_theme(tname:String):
	var t := load(THEME_PATHS.get(tname, THEME_PATHS.material))
	# Apply to all scenes
	for node in get_tree().root.get_children():
		node.theme = t
