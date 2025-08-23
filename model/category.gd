class_name Category
extends RefCounted

var id: int
var name: String

func _init(d: Dictionary = {}):
	id = d.get("id", 0)
	name = d.get("name", "")

func to_dict() -> Dictionary:
	return { id = id, name = name }
