extends VBoxContainer
class_name ItemRow

signal long_pressed
signal needed_changed(item_id: int, needed: bool)

# --------------------------------------------------
# One-time setup
# --------------------------------------------------
func _ready() -> void:
	# Long-press / click on the entire row
	var timer := Timer.new()
	timer.wait_time = 0.6
	timer.one_shot = true
	add_child(timer)

	gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed:
			timer.start()
		elif event is InputEventScreenTouch and not event.pressed:
			timer.stop()
		elif event.is_action_pressed("ui_accept"):
			if get_viewport().gui_get_focus_owner():
				get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
			long_pressed.emit()
	)
	timer.timeout.connect(func(): # release any ongoing scroll grab
		if get_viewport().gui_get_focus_owner():
			get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
		long_pressed.emit()
	)
# --------------------------------------------------
# Public API
# --------------------------------------------------
func setup(item: Dictionary) -> void:
	# Wire the toggle button once
	%NeedCheck.toggled.connect(func(toggled: bool):
		needed_changed.emit(int(item["id"]), toggled)
	)
	update_from_item(item)

func update_from_item(item: Dictionary) -> void:
	%NameLabel.text       = str(item.get("name", ""))
	%CategoryLabel.text   = _get_category_name(int(item.get("category_id", 0)))
	%PriceButton.text     = "%.2f €" % (int(item.get("price_cents", 0)) / 100.0)
	%NeedCheck.button_pressed = bool(item.get("needed", false))

	# Amount + unit on the toggle button
	%NeedCheck.text = str(item.get("amount", "")) + "\n" + str(item.get("unit", ""))

	# Description (hide if empty)
	var desc := str(item.get("description", ""))
	%DescriptionLabel.text = desc
	%DescriptionLabel.visible = not desc.is_empty()

# --------------------------------------------------
# Helpers
# --------------------------------------------------
func _get_category_name(id: int) -> String:
	for c in DB.select_categories():
		if int(c["id"]) == id:
			return str(c["name"])
	return ""
