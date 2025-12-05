# res://addons/godex_ui_profiler/profile_block.gd
class_name ProfileBlock
static func ms(label: String) -> ProfileBlock:
	return ProfileBlock.new(label)

var _t: int
var _label: String
func _init(label: String) -> void:
	_t = Time.get_ticks_usec()
	_label = label
func finish() -> float:
	var dt := (Time.get_ticks_usec() - _t) / 1000.0
	prints("◄", "%.2f ms" % dt, _label)
	return dt
