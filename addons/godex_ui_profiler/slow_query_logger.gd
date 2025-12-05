# res://addons/godex_ui_profiler/slow_query_logger.gd
class_name SlowQueryLogger
static func install() -> void:
	var s := SlowQueryLogger.new()
	# queue on our own instance, not on root
	s.call_deferred("_do_install")

func _do_install() -> void:
	var db = Engine.get_singleton("DB")
	if not db or not db.has_method("_db"): return
	var orig = db._db
	orig.query_with_bindings = func(sql, params := []):
		var t := Time.get_ticks_usec()
		var ok = orig.query_with_bindings.call(sql, params)
		var dt := (Time.get_ticks_usec() - t)/1000.0
		if dt > 2.0:
			prints("SLOW ► %.2f ms  %s  %s" % [dt, sql, params])
		return ok
