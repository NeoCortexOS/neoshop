extends Node

# Run from the command-line with:
#   godot --headless --script res://db/seed.gd
# or simply call Seed.run() from any debug button.


func _ready():
	run()
	
func run() -> void:
	# --- categories ----------------------------------------------------------
	var cat_ids := {}
	for iname in ["Fruits", "Vegetables", "Dairy", "Bakery", "Household"]:
		cat_ids[iname] = DB.insert_category(iname)

	# --- items ---------------------------------------------------------------
	_add(cat_ids["Fruits"],     "Apples",        6, "pcs",  "",          129)
	_add(cat_ids["Fruits"],     "Bananas",       1, "kg",   "",           99)
	_add(cat_ids["Vegetables"], "Carrots",     500, "g",    "",           89)
	_add(cat_ids["Dairy"],      "Milk 1 L",      2, "l",    "",          119)
	_add(cat_ids["Bakery"],     "Whole-grain",   1, "loaf", "",          259)
	_add(cat_ids["Household"],  "Dish-soap",     1, "bottle", "500 ml", 149)
	print("Seed data inserted.")

func _add(cat_id:int, aname:String, amount:float, unit:String, desc:String, price_c:int) -> void:
	DB.insert_item({
		name        = aname,
		amount      = amount,
		unit        = unit,
		description = desc,
		category_id = cat_id,
		needed      = false,
		in_cart     = false,
		last_bought = 0,
		price_cents = price_c,
		on_sale     = false
	})
