# res://addons/godex_ui_profiler/profiler.gd
extends Node
const BLOCK = preload("profile_block.gd")
const SLOW  = preload("slow_query_logger.gd")
const SIG   = preload("signal_counter.gd")
const FPS   = preload("fps_regress.gd")

func _ready() -> void:
	SLOW.install()
	FPS._start(10)          # not static anymore
