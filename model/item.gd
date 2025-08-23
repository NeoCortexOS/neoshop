class_name Item
extends RefCounted

var id: int
var name: String
var amount: float
var unit: String
var description: String
var category_id: int
var needed: bool
var in_cart: bool
var last_bought: int
var price_cents: int
var on_sale: bool

func _init(d: Dictionary = {}):
	id            = d.get("id", 0)
	name          = d.get("name", "")
	amount        = d.get("amount", 0.0)
	unit          = d.get("unit", "")
	description   = d.get("description", "")
	category_id   = d.get("category_id", 0)
	needed        = bool(d.get("needed", false))
	in_cart       = bool(d.get("in_cart", false))
	last_bought   = d.get("last_bought", 0)
	price_cents   = d.get("price_cents", 0)
	on_sale       = bool(d.get("on_sale", false))

func to_dict() -> Dictionary:
	return {
		id = id,
		name = name,
		amount = amount,
		unit = unit,
		description = description,
		category_id = category_id,
		needed = needed,
		in_cart = in_cart,
		last_bought = last_bought,
		price_cents = price_cents,
		on_sale = on_sale
	}
