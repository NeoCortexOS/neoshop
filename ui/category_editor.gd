# res://ui/category_editor.gd
extends ConfirmationDialog

signal category_saved
signal category_cancelled

@onready var categories_container: VBoxContainer = %CategoriesContainer
@onready var item_add_button: Button = %AddButton

var _category_inputs: Array = []

func _ready():
	# Configure the dialog buttons
	get_ok_button().text = tr("Save")
	get_cancel_button().text = tr("Cancel")
	
	# Connect signals
	confirmed.connect(_on_save_button_pressed)
	canceled.connect(_on_cancel_button_pressed)
	item_add_button.pressed.connect(_on_add_button_pressed)

func popup_category_editor():
	_load_categories()
	popup_centered()


func _load_categories():
	# Clear existing inputs
	for child in categories_container.get_children():
		child.queue_free()
	
	_category_inputs.clear()
	
	# Load categories from database
	var categories = DB.select_categories()
	categories.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	
	for category in categories:
		_add_category_row(category["name"], category["id"])

func _add_category_row(cname: String = "", category_id: int = -1):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var line_edit = LineEdit.new()
	line_edit.focus_mode = Control.FOCUS_ALL
	line_edit.text = cname
	line_edit.placeholder_text = "Category name"
	line_edit.custom_minimum_size = Vector2(300, 0)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.set_meta("category_id", category_id)
	
	var delete_button = Button.new()
	delete_button.text = "🗑"
	delete_button.custom_minimum_size = Vector2(40, 0)
	delete_button.pressed.connect(func(): _delete_category_row(hbox, line_edit))
	
	hbox.add_child(line_edit)
	hbox.add_child(delete_button)
	
	categories_container.add_child(hbox)
	_category_inputs.append({
		"line_edit": line_edit,
		"original_id": category_id
	})
	
	# Focus the new line edit
	if cname == "":
		line_edit.grab_focus()
		await get_tree().process_frame
		%ScrollContainer.ensure_control_visible(line_edit)
		print("net category added, trying to focus")

func _delete_category_row(container: Node, line_edit: LineEdit):
	var category_id = int(line_edit.get_meta("category_id", -1))
	
	# Check if category is in use
	var items = DB.select_items("category_id = ?", [category_id])
	if items.size() > 0:
		_show_warning_dialog("Cannot delete category with items. Move items to another category first.")
		return
	
	_show_warning_dialog("DELETE_CATEGORY")
	
	# Remove from UI
	categories_container.remove_child(container)
	container.queue_free()
	
	# Remove from tracking
	for i in range(_category_inputs.size()):
		if _category_inputs[i]["line_edit"] == line_edit:
			_category_inputs.remove_at(i)
			break
	
	# Only delete from database if it was an existing category
	if category_id != -1:
		DB.delete_category(category_id)

func _show_warning_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Warning"
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _on_add_button_pressed():
	_add_category_row("")

func _on_save_button_pressed():
	# Validate all categories
	var names = {}
	var has_empty = false
	
	for input_data in _category_inputs:
		var cname = input_data["line_edit"].text.strip_edges()
		if cname == "":
			has_empty = true
			continue
			
		if names.has(cname.to_lower()):
			_show_warning_dialog("Duplicate category name: %s" % cname)
			return
			
		names[cname.to_lower()] = cname
	
	if has_empty:
		_show_warning_dialog("Please fill in or delete empty category names")
		return
	
	# Save all categories
	for input_data in _category_inputs:
		var cname = input_data["line_edit"].text.strip_edges()
		if cname == "":
			continue
			
		var category_id = int(input_data["line_edit"].get_meta("category_id", -1))
		
		if category_id == -1:
			# New category
			DB.insert_category(cname)
		else:
			# Update existing
			DB.update_category(category_id, cname)
	
	# Emit signal
	category_saved.emit()

func _on_cancel_button_pressed():
	category_cancelled.emit()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_BACK, KEY_ESCAPE] and event.pressed:
		category_cancelled.emit()
		hide()
