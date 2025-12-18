extends PanelContainer
class_name ItemRow

#signal long_pressed
#signal needed_changed(item_id: String, needed: bool)
#signal in_cart_changed(item_id: String)

## --- gesture constants ---
#const TAP_MAX_DISTANCE  := 30.0
#const LONG_PRESS_TIME   := 0.6
#const SCROLL_THRESHOLD  := 15.0

# --- state ---
var shopping_mode    : bool    = false
var touch_start_time : float   = 0.0
var touch_start_pos  : Vector2 = Vector2.ZERO
var has_moved        : bool    = false
var is_scrolling     : bool    = false

# item dictionary
var my_item     : Dictionary = {}

# item data
var item_id     : String = "-1"
var iname       : String = ""
var amount      : float  = 0.0
var unit        : String = ""
var description : String = ""
var category_id : int    = -1
var needed      : bool   = false
var in_cart     : bool   = false
var price_cents : int    = 0
var is_deleted  : bool   = false
var updated_at  : int    = 0
var last_bought : int    = 0


# --------------------------------------------------
# READY
# --------------------------------------------------
func _ready() -> void:
	#print("_ready: " + self.name)
	## make ItemRow the exclusive touch handler
	#%ItemRow.mouse_filter = Control.MOUSE_FILTER_PASS
	#%ItemRow.gui_input.connect(_on_item_row_input)
	#_make_children_ignore_mouse(%ItemRow)
	# make ItemContainer the exclusive touch handler
	$".".mouse_filter = Control.MOUSE_FILTER_PASS
	#$".".gui_input.connect(_on_item_row_input)
	_make_children_ignore_mouse($".")
	#needed_changed.connect(DB.toggle_needed)


# --------------------------------------------------
# PUBLIC API
# --------------------------------------------------
func setup(item: Dictionary) -> void:
	#set_meta("item_dict", item)   # store once
	item_id = item.get("id", "")
	#update_from_item(item)


func update_from_item(item: Dictionary) -> void:
	my_item = item # save current data
	# not 100% sure if that is still right
	if item_id == "-1":
		print("update_from_item found id: -1")
		item_id = item.get("id", "")

	iname       = str(item.get("name",        ""))
	amount      = float(item.get("amount",     0.0))
	unit        = str(item.get("unit",         ""))
	description = str(item.get("description",  ""))
	category_id = int(item.get("category_id",  -1))
	needed      = bool(item.get("needed",      false))
	in_cart     = bool(item.get("in_cart",     false))
	price_cents = int(item.get("price_cents",  0))
	is_deleted  = bool(item.get("is_deleted", false))
	updated_at  = int(item.get("updated_at", 0))
	last_bought = int(item.get("last_bought", 0))

	#print(iname)

	%delPanel.visible = is_deleted

	#print("update_from_item: ", iname, \
		#" shopping_mode: ", DB.shopping_mode, \
		#" needed: ", needed, \
		#" in_cart: ", in_cart \
		#)

	## --- store in_cart for draw ---
	#%MainLine.set_meta("in_cart", in_cart)

	# --- basic UI ---
	%NameLabel.text        = iname
	%CategoryLabel.text    = _get_category_name(category_id)
	%PriceButton.text      = "%.2f €" % (price_cents / 100.0)

	if description.is_empty():
		%DescriptionLabel.visible = false
	else:
		%DescriptionLabel.visible = true
		%DescriptionLabel.text = description

	# --- shopping tint ---
	#modulate = Color(1, 0.8, 0.8, 0.6) if (DB.shopping_mode and in_cart) else Color.WHITE
	#if (DB.shopping_mode and in_cart):
		##print("shopping and in_cart: ", iname)
		##%ItemRow.modulate = Color(1, 0.8, 0.8, 0.6)
		#%inCartPanel.modulate = Color(0, 0.75, 0.25, 0.5)
		#%inCartPanel.visible = true
		##pass #NC

	if (is_deleted):
		print("deleted item: ", item_id)
		#%ItemRow.modulate = Color(1, 0.8, 0.8, 0.6)
		#%inCartPanel.modulate = Color(1.0, 0.0, 0.0, 0.25)
		#%inCartPanel.visible = true

	# --- amount / need / cart ---
	var amount_text := ""
	if amount != 0:
		if(amount - int(amount) == 0):
			amount_text = str(int(amount))
		else:
			amount_text = str(amount)
	if unit and not unit.is_empty():
		amount_text += "\n" + unit
	%NeedCheck.text = amount_text

	if DB.shopping_mode:
		%NeedCheck.icon = preload("res://icons/blue_shoppingbags.svg") if in_cart else preload("res://icons/cart.svg")
		%NeedCheck.toggle_mode = false
		if(in_cart):
			%inCartPanel.modulate = Color(0, 0.75, 0.25, 0.5)
			%inCartPanel.visible = true
		else:
			%inCartPanel.visible = false
	else:
		%NeedCheck.button_pressed = needed
		%NeedCheck.icon = preload("res://icons/cart.svg") if needed else null
		%NeedCheck.toggle_mode = true
		%inCartPanel.visible = false

	# --- request redraw for strike-through ---
	#queue_redraw()
	set_meta("item_dict", item)   # store updated item data


func set_shopping_mode(enabled: bool) -> void:
	shopping_mode = enabled
	#_update_need_check_appearance()
	#update_from_item(get_meta("item_dict"))   # refresh visuals right now
	#print("set_shopping_mode: ", shopping_mode,
			#" item name: ", iname
	#)
	#if item_id != "-1":
		#var items := DB.select_items("id = ?", [item_id])
		#if not items.is_empty():
			#update_from_item(items[0])
			#pass #NC


## --------------------------------------------------
## GESTURE HANDLING  (unchanged logic, only feedback fixed)
## --------------------------------------------------
#func _on_item_row_input(event: InputEvent) -> void:
	#return
	#if event is InputEventScreenTouch:
		#if event.pressed:
			#print("touch event.pressed")
			#touch_start_time = Time.get_unix_time_from_system()
			#touch_start_pos  = event.position
			#has_moved = false
			#is_scrolling = false
			#var t := Timer.new()
			#t.wait_time = LONG_PRESS_TIME
			#t.one_shot = true
			#add_child(t)
			#t.timeout.connect(_on_long_press_detected)
			#t.start()
		#else:
			#print(str(event))
			#var dur := Time.get_unix_time_from_system() - touch_start_time
			#var dist : float = (event.position - touch_start_pos).length()
			#for c in get_children():
				#if c is Timer and c.wait_time == LONG_PRESS_TIME:
					#c.queue_free() # remove long_press timer
			#if not has_moved and not is_scrolling and dist < TAP_MAX_DISTANCE:
				#if DB.shopping_mode:
					##in_cart_changed.emit(item_id)
					#in_cart = DB.toggle_in_cart(item_id)
					#my_item.set("in_cart", in_cart)
					#update_from_item(my_item)
					#print("in_cart, dur: " + str(dur) + " dist: " + str(dist) + " : " + str(in_cart))
				#else:
					#needed = DB.toggle_needed(item_id)
					#my_item.set("needed", needed)
					#update_from_item(my_item)
					#print("dur: " + str(dur) + " dist: " + str(dist) + " needed: " + str(needed))
#
				#_show_tap_feedback()
				#print("after tap_feedback, dur = ", dur)
#
	#elif event is InputEventScreenDrag:
		#var dist : float = (event.position - touch_start_pos).length()
		#if dist > SCROLL_THRESHOLD:
			#has_moved = true
			#is_scrolling = true
#
#func _on_long_press_detected() -> void:
	#if not has_moved and not is_scrolling:
		#long_pressed.emit(item_id)

# --------------------------------------------------
# FEEDBACK ANIMATION  (fixed)
# --------------------------------------------------
func _show_tap_feedback() -> void:
	if OS.get_name() == "Android":
		Input.vibrate_handheld(100)
	#print("tap feedback")
	# detach from layout while scaling
	var old_h := size_flags_horizontal
	var old_v := size_flags_vertical
	#size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	#size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", Vector2(1, 1),      0.05)
	tween.tween_callback(func():
		size_flags_horizontal = old_h
		size_flags_vertical   = old_v)

# --------------------------------------------------
# HELPERS
# --------------------------------------------------
func _make_children_ignore_mouse(node: Control) -> void:
	for c in node.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_make_children_ignore_mouse(c)

func _update_need_check_appearance() -> void:
	# nothing dynamic here anymore
	pass


#func toggle_needed(p_item_id: String, needed: bool) -> void:
	##NC todo: toggle should not need bool, but might return current state
		#print("toggle_needed id: ", p_item_id, " need: ", needed)
		#if p_item_id != "-1":
			#var items := DB.select_items("id = ?", [p_item_id])
			#if not items.is_empty():
				#update_from_item(items[0])
	
	
func _get_category_name(id: int) -> String:
	#for c in DB.select_categories():
		#if int(c["id"]) == id:
			#return str(c["name"])
	#return ""
	return(DB.catname.get(id, "empty id: " + str(id)))
