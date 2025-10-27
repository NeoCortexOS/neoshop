class_name Category
extends RefCounted

var id: int
var name: String
var is_deleted: bool

func _init(d: Dictionary = {}):
	id         = d.get("id", 0)
	name       = d.get("name", "")
	is_deleted = bool(d.get("is_deleted", false))

func to_dict() -> Dictionary:
	return { id = id, name = name, is_deleted = is_deleted }
