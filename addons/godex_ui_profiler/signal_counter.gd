# res://addons/godex_ui_profiler/signal_counter.gd
extends Node
var cnt := {}
func _ready() -> void:
	set_process(false) # enabled per-node when needed
func hook(node: Node, sig: StringName) -> void:
	node.connect(sig, Callable(self, "_on").bind(node, sig), CONNECT_DEFERRED)
func _on(node: Node, sig: StringName) -> void:
	var k := str(node.name, "::", sig)
	cnt[k] = cnt.get(k, 0) + 1
func dump() -> void:
	for k in cnt: prints("SIGNAL", k, cnt[k])
