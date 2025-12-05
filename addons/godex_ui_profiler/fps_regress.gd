# res://addons/godex_ui_profiler/fps_regress.gd
extends Node               # ← add this
class_name FpsRegress
static func _start(target: int) -> void:
	var f := FpsRegress.new()
	f.target_fps = target
	Engine.get_main_loop().root.add_child.call_deferred(f)

var target_fps := 10
var frames := PackedFloat32Array()
func _process(_dt: float) -> void:
	frames.push_back(Engine.get_frames_per_second())
	if frames.size() > 120:
		frames.remove_at(0)                     # Godot 4.4 API
		var med := frames[frames.size()/2]
		if med < target_fps:
			push_error("FPS REGRESS: median %.1f < %d" % [med, target_fps])
