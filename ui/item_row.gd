extends VBoxContainer
class_name ItemRow

signal long_pressed
signal needed_changed(item_id: int, needed: bool)
signal in_cart_changed(item_id: int)

var shopping_mode : bool = false
var item_id : int = -1

# Gesture detection for both modes
var touch_start_time : float = 0
var touch_start_pos : Vector2 = Vector2.ZERO
var is_scrolling : bool = false
var has_moved : bool = false
const TAP_MAX_DISTANCE := 30.0  # pixels
const LONG_PRESS_TIME := 0.6  # seconds
const SCROLL_THRESHOLD := 15.0  # pixels

# --------------------------------------------------
# One-time setup
# --------------------------------------------------
func _ready() -> void:
	# Make MainLine the exclusive touch handler
	%MainLine.mouse_filter = Control.MOUSE_FILTER_PASS
	%MainLine.gui_input.connect(_on_main_line_input)

	# Force all children to ignore mouse/touch
	_make_children_ignore_mouse(%MainLine)

func _make_children_ignore_mouse(node: Control) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_make_children_ignore_mouse(child)


func _on_main_line_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Start tracking touch
			touch_start_time = Time.get_unix_time_from_system()
			touch_start_pos = event.position
			has_moved = false
			is_scrolling = false
			
			# Start long press timer
			var timer := Timer.new()
			timer.wait_time = LONG_PRESS_TIME
			timer.one_shot = true
			add_child(timer)
			timer.timeout.connect(_on_long_press_detected)
			timer.start()
			
		else:
			# Touch released
			var touch_duration = Time.get_unix_time_from_system() - touch_start_time
			var distance = (event.position - touch_start_pos).length()
			print("t: ", touch_duration, " d: ", distance)
			# Clean up timer
			for child in get_children():
				if child is Timer and child.wait_time == LONG_PRESS_TIME:
					child.queue_free()
			
			if not has_moved and not is_scrolling and distance < TAP_MAX_DISTANCE:
				# It's a tap!
				print("tapped")
				if shopping_mode:
					# Shopping mode: toggle in_cart
					print("toggle cart")
					#DB.toggle_in_cart(item_id)
					in_cart_changed.emit(item_id)
					_show_tap_feedback()
				else:
					# Planning mode: toggle needed
					var current_needed = %NeedCheck.button_pressed
					%NeedCheck.button_pressed = !current_needed
					needed_changed.emit(item_id, !current_needed)
					_show_tap_feedback()
					
	elif event is InputEventScreenDrag:
		# Check if we're scrolling
		var distance = (event.position - touch_start_pos).length()
		if distance > SCROLL_THRESHOLD:
			has_moved = true
			is_scrolling = true
			# Let the scroll container handle it

func _on_long_press_detected() -> void:
	print("long press detected, moved: ", has_moved, " scrolling: ", is_scrolling)
	if not has_moved and not is_scrolling:
		long_pressed.emit(item_id)
		print("long press emitted")
		#get_viewport().set_input_as_handled() 

func _show_tap_feedback() -> void:
	# Brief scale animation for feedback
	var original_scale = %MainLine.scale
	var tween = create_tween()
	tween.tween_property(%MainLine, "scale", original_scale * 0.95, 0.05)
	tween.tween_property(%MainLine, "scale", original_scale, 0.05)

func set_shopping_mode(enabled: bool) -> void:
	shopping_mode = enabled
	
	# Update NeedCheck button appearance
	_update_need_check_appearance()
	
	# Update item appearance
	if item_id != -1:
		var items = DB.select_items("id = ?", [item_id])
		if items.size() > 0:
			update_from_item(items[0])

func _update_need_check_appearance() -> void:
	# Always keep NeedCheck visible and interactive for gesture detection
	if shopping_mode:
		# Shopping mode: show appropriate icon based on in_cart
		%NeedCheck.toggle_mode = false
	else:
		# Planning mode: interactive needed toggle
		%NeedCheck.toggle_mode = true

# --------------------------------------------------
# Public API
# --------------------------------------------------
func setup(item: Dictionary) -> void:
	item_id = int(item.get("id", 0))
	update_from_item(item)

func update_from_item(item: Dictionary) -> void:
	if item_id == -1:
		item_id = int(item.get("id", 0))
	
	# Safely access all fields with defaults
	var name = str(item.get("name", ""))
	var amount = float(item.get("amount", 0.0))
	var unit = str(item.get("unit", ""))
	var description = str(item.get("description", ""))
	var category_id = int(item.get("category_id", -1))
	var needed = bool(item.get("needed", false))
	var in_cart = bool(item.get("in_cart", false))
	var price_cents = int(item.get("price_cents", 0))
	
	# Update UI elements
	%NameLabel.text = name
	
	# Handle amount display
	var amount_text = ""
	if amount != 0:
		amount_text = str(amount)
		if unit and not unit.is_empty():
			amount_text += "\n" + unit
	
	# Update NeedCheck button
	%NeedCheck.text = amount_text
	
	# Shopping mode specific styling
	if shopping_mode:
		# Update NeedCheck icon based on in_cart
		if in_cart:
			%NeedCheck.icon = preload("res://icons/checkmark.png")
		else:
			%NeedCheck.icon = preload("res://icons/cart.png")
		
		# Apply styling for in-cart items
		if in_cart:
			modulate = Color(0.9, 0.7, 0.7, 0.7)
			#%NameLabel.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			#%NameLabel.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		else:
			modulate = Color.WHITE
			%NameLabel.remove_theme_color_override("font_color")
	else:
		# Planning mode
		%NeedCheck.button_pressed = needed
		%NeedCheck.icon = preload("res://icons/checkmark.png")
		
		# Normal appearance
		modulate = Color.WHITE
		%NameLabel.remove_theme_color_override("font_color")
	
	# Handle category
	%CategoryLabel.text = _get_category_name(category_id)
	
	# Handle price
	%PriceButton.text = "%.2f €" % (price_cents / 100.0)
	
	# Handle description
	if description and not description.is_empty():
		%DescriptionLabel.text = description
		%DescriptionLabel.visible = true
	else:
		%DescriptionLabel.visible = false
	
	# Hide price/category for in-cart items in shopping mode
	#%CategoryLabel.visible = !(shopping_mode && in_cart)
	#%PriceButton.visible = !(shopping_mode && in_cart)

# --------------------------------------------------
# Helpers
# --------------------------------------------------
func _get_category_name(id: int) -> String:
	for c in DB.select_categories():
		if int(c["id"]) == id:
			return str(c["name"])
	return ""
