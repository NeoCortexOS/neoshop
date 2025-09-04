extends VBoxContainer
class_name ItemRow

signal long_pressed
signal needed_changed(item_id: int, needed: bool)
signal in_cart_changed(item_id: int)

# --- gesture constants ---
const TAP_MAX_DISTANCE  := 30.0
const LONG_PRESS_TIME   := 0.6
const SCROLL_THRESHOLD  := 15.0

# --- state ---
var shopping_mode : bool = false
var item_id       : int  = -1
var touch_start_time  : float  = 0.0
var touch_start_pos   : Vector2 = Vector2.ZERO
var has_moved  : bool = false
var is_scrolling : bool = false

# --------------------------------------------------
# READY
# --------------------------------------------------
func _ready() -> void:
	# make MainLine the exclusive touch handler
	%MainLine.mouse_filter = Control.MOUSE_FILTER_PASS
	%MainLine.gui_input.connect(_on_main_line_input)
	_make_children_ignore_mouse(%MainLine)

# --------------------------------------------------
# DRAW  (strike-through)
# --------------------------------------------------
@onready var _strike_color := Color.ORANGE_RED
@onready var _line_width  := int(2.0 * get_tree().root.content_scale_factor + 0.5)

func _draw() -> void:
	if not shopping_mode or not %MainLine.get_meta("in_cart", false):
		return

	# strike MainLine
	var r := Rect2(%MainLine.get_global_rect())
	r.position -= global_position
	var y := int(r.position.y + r.size.y * 0.5)   # integer pixel
	draw_line(Vector2(r.position.x, y),
			  Vector2(r.position.x + r.size.x, y),
			  _strike_color, _line_width)

	# Description
	if %DescriptionLabel.visible:
		r = Rect2(%DescriptionLabel.get_global_rect())
		r.position -= global_position
		y = int(r.position.y + r.size.y * 0.5)
		draw_line(Vector2(r.position.x, y),
				  Vector2(r.position.x + r.size.x, y),
				  _strike_color, _line_width)
# --------------------------------------------------
# PUBLIC API
# --------------------------------------------------
func setup(item: Dictionary) -> void:
	item_id = int(item.get("id", 0))
	update_from_item(item)

func update_from_item(item: Dictionary) -> void:
	if item_id == -1:
		item_id = int(item.get("id", 0))

	var iname       = str(item.get("name",        ""))
	var amount      = float(item.get("amount",     0.0))
	var unit        = str(item.get("unit",         ""))
	var description = str(item.get("description",  ""))
	var category_id = int(item.get("category_id",  -1))
	var needed      = bool(item.get("needed",      false))
	var in_cart     = bool(item.get("in_cart",     false))
	var price_cents = int(item.get("price_cents",  0))

	# --- store in_cart for draw ---
	%MainLine.set_meta("in_cart", in_cart)

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
	modulate = Color(1, 0.8, 0.8, 0.6) if (shopping_mode and in_cart) else Color.WHITE

	# --- amount / need / cart ---
	var amount_text := str(amount) if amount != 0 else ""
	if unit and not unit.is_empty():
		amount_text += "\n" + unit
	%NeedCheck.text = amount_text

	if shopping_mode:
		%NeedCheck.icon = preload("res://icons/checkmark.png") if in_cart else preload("res://icons/cart.png")
		%NeedCheck.toggle_mode = false
	else:
		%NeedCheck.button_pressed = needed
		%NeedCheck.icon = preload("res://icons/checkmark.png")
		%NeedCheck.toggle_mode = true

	# --- request redraw for strike-through ---
	queue_redraw()

func set_shopping_mode(enabled: bool) -> void:
	shopping_mode = enabled
	_update_need_check_appearance()
	if item_id != -1:
		var items := DB.select_items("id = ?", [item_id])
		if not items.is_empty():
			update_from_item(items[0])

# --------------------------------------------------
# GESTURE HANDLING  (unchanged logic, only feedback fixed)
# --------------------------------------------------
func _on_main_line_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_time = Time.get_unix_time_from_system()
			touch_start_pos  = event.position
			has_moved = false
			is_scrolling = false
			var t := Timer.new()
			t.wait_time = LONG_PRESS_TIME
			t.one_shot = true
			add_child(t)
			t.timeout.connect(_on_long_press_detected)
			t.start()
		else:
			var dur := Time.get_unix_time_from_system() - touch_start_time
			var dist : float = (event.position - touch_start_pos).length()
			for c in get_children():
				if c is Timer and c.wait_time == LONG_PRESS_TIME:
					c.queue_free()
			if not has_moved and not is_scrolling and dist < TAP_MAX_DISTANCE:
				if shopping_mode:
					in_cart_changed.emit(item_id)
				else:
					var new_needed : bool = !%NeedCheck.button_pressed
					%NeedCheck.button_pressed = new_needed
					needed_changed.emit(item_id, new_needed)
				_show_tap_feedback()

	elif event is InputEventScreenDrag:
		var dist : float = (event.position - touch_start_pos).length()
		if dist > SCROLL_THRESHOLD:
			has_moved = true
			is_scrolling = true

func _on_long_press_detected() -> void:
	if not has_moved and not is_scrolling:
		long_pressed.emit(item_id)

# --------------------------------------------------
# FEEDBACK ANIMATION  (fixed)
# --------------------------------------------------
func _show_tap_feedback() -> void:
	# detach from layout while scaling
	var old_h := size_flags_horizontal
	var old_v := size_flags_vertical
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

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

func _get_category_name(id: int) -> String:
	for c in DB.select_categories():
		if int(c["id"]) == id:
			return str(c["name"])
	return ""
