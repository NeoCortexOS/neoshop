# res://addons/godex_ui_profiler/plugin.gd
@tool
extends EditorPlugin
func _enter_tree(): add_autoload_singleton("Profiler", "profiler.gd")
func _exit_tree(): remove_autoload_singleton("Profiler")
