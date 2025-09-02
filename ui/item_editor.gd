extends Window

signal item_saved
signal item_canceled
signal item_deleted

var _item_id : int = -1                 # -1 = new item
var _categories : Array = []

func _ready() -> void:
	#print("Item Editor _ready")
	#show()
	_populate_categories()
	%NeedBtn.pressed.connect(_on_need)
	%CartBtn.pressed.connect(_on_cart)
	%MinusBtn.pressed.connect(_on_minus)
	%PlusBtn.pressed.connect(_on_plus)
	%SaveBtn.pressed.connect(_on_save)
	%CancelBtn.pressed.connect(_on_cancel)
	%DeleteBtn.pressed.connect(_on_delete)
	close_requested.connect(_on_cancel)

# --------------------------------------------------
# Public API
# --------------------------------------------------
func new_item() -> void:
	_item_id = -1
	_clear_fields()
	popup_centered()

func edit_item(id: int) -> void:
	_item_id = id
	var items = DB.select_items("id = ?", [id])
	if items.is_empty():
		push_error("Item %d not found" % id)
		return
	var it : Dictionary = items[0]
	_populate_fields(it)
	%DeleteBtn.visible = true          # only show when editing
	popup_centered()

# --------------------------------------------------
# Internals
# --------------------------------------------------
func _populate_categories() -> void:
	_categories = DB.select_categories()
	%CategoryOption.clear()
	for c in _categories:
		%CategoryOption.add_item(str(c["name"]), int(c["id"]))

func _clear_fields() -> void:
	%NameEdit.text = ""
	%AmountEdit.text = "1"
	%UnitEdit.text = "pcs"
	%PriceEdit.text = "0"
	%DescriptionEdit.text = ""
	%CategoryOption.selected = 0
	%NeedBtn.button_pressed = false
	%CartBtn.button_pressed = false
	%DeleteBtn.visible    = false


func _populate_fields(it: Dictionary) -> void:
	%NameEdit.text        = str(it["name"])
	%AmountEdit.text      = str(it["amount"])
	%UnitEdit.text        = str(it["unit"])
	%PriceEdit.text       = str(float(it["price_cents"]) / 100.0)
	%DescriptionEdit.text = str(it["description"])
	var cat_id := int(it["category_id"])
	for i in _categories.size():
		if int(_categories[i]["id"]) == cat_id:
			%CategoryOption.selected = i
			break
	%NeedBtn.button_pressed = bool(it["needed"])
	%CartBtn.button_pressed = bool(it["in_cart"])

func _on_save() -> void:
	var p := {
		name        = %NameEdit.text,
		amount      = %AmountEdit.text.to_float(),
		unit        = %UnitEdit.text,
		description = %DescriptionEdit.text,
		category_id = %CategoryOption.get_item_id(%CategoryOption.selected),
		price_cents = int(%PriceEdit.text.to_float() * 100.0),
		needed      = %NeedBtn.button_pressed,
		in_cart     = %CartBtn.button_pressed,
		last_bought = 0,
		on_sale     = false
	}

	if _item_id == -1:
		DB.insert_item(p)
	else:
		p["id"] = _item_id
		DB.update_item(p)
	emit_signal("item_saved")
	queue_free()


func _on_need():
	pass


func _on_cart():
	pass	
	
	
func _on_minus():
	%AmountEdit.text = str(%AmountEdit.text.to_float() - 1)
	
func _on_plus():
	%AmountEdit.text = str(%AmountEdit.text.to_float() + 1)
	
	
func _on_delete() -> void:
	if _item_id != -1:
		DB.delete_item(_item_id)
	emit_signal("item_deleted")
	queue_free()


func _on_cancel() -> void:
	emit_signal("item_canceled")
	queue_free()
