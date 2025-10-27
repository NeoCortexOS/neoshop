# res://ui/category_editor.gd
extends ConfirmationDialog

signal category_saved
signal category_cancelled

@onready var categories_container: VBoxContainer = %CategoriesContainer
@onready var item_add_button: Button = %AddButton

# per-row state:  { hbox, line_edit, delete_btn, orig_id, orig_name, orig_is_deleted, dirty }
var _rows: Array[Dictionary] = []

func _ready():
	print("_ready: " + self.name)
	get_ok_button().text = tr("Save")
	get_cancel_button().text = tr("Cancel")
	confirmed.connect(_on_save_button_pressed)
	canceled.connect(_on_cancel_button_pressed)
	item_add_button.pressed.connect(_on_add_button_pressed)

func popup_category_editor():
	rebuild_ui()
	popup_centered()

# --------------------------------------------------
# UI building
# --------------------------------------------------
func rebuild_ui():
	for child in categories_container.get_children():
		child.queue_free()
	_rows.clear()

	var cats := DB.select_categories()
	cats.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())

	for cat in cats:
		print("cat added: " + str(cat))
		_add_row(cat)

	# brand-new row at bottom (empty)
	_add_row({"id": -1, "name": "", "is_deleted": false})

func _add_row(cat: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var le := LineEdit.new()
	le.text = cat.name
	le.placeholder_text = tr("Category name")
	le.custom_minimum_size.x = 300
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.set_meta("cat_id", cat.id)
	hbox.add_child(le)

	var del_btn := Button.new()
	del_btn.text = tr("DELETE") if not cat.is_deleted else tr("UNDELETE")
	del_btn.pressed.connect(_on_delete_pressed.bind(del_btn))
	hbox.add_child(del_btn)

	categories_container.add_child(hbox)

	_rows.append({
		hbox = hbox,
		line_edit = le,
		delete_btn = del_btn,
		orig_id = cat.id,
		orig_name = cat.name,
		orig_is_deleted = cat.is_deleted,
		dirty = false
	})

	# mark dirty on any change
	le.text_changed.connect(func(_new_text): _mark_dirty(le))
	del_btn.pressed.connect(func(): _mark_dirty(le)) # btn toggles deleted state

	if cat.id == -1:  # focus new row
		le.grab_focus()
		await get_tree().process_frame
		%ScrollContainer.ensure_control_visible(le)

# --------------------------------------------------
# dirty tracking
# --------------------------------------------------
func _mark_dirty(le: LineEdit) -> void:
	print(le)
	for d in _rows:
		if d.line_edit == le:
			d.dirty = true
			print()
			break

# --------------------------------------------------
# delete / undelete (soft)  →  instant UI update
# --------------------------------------------------
func _on_delete_pressed(del_btn: Button) -> void:
	for d in _rows:
		if d.delete_btn == del_btn:
			var new_state: bool = not d.orig_is_deleted     # <- explicit type
			d.orig_is_deleted = new_state
			d.dirty = true
			del_btn.text = tr("UNDELETE") if new_state else tr("DELETE")
			# visual tint: repaint background
			d.hbox.modulate = Color(1, 0.4, 0.4, 0.9) if new_state else Color.WHITE
			break

# --------------------------------------------------
# save  →  ONLY dirty rows
# --------------------------------------------------
func _on_save_button_pressed():
	# validate
	var names: Dictionary = {}
	for d in _rows:
		var name: String = d.line_edit.text.strip_edges()   # <- explicit type
		print("name: " + name)
		if name.is_empty(): continue
		if names.has(name.to_lower()):
			_show_warning_dialog("Duplicate name: %s" % name)
			return
		names[name.to_lower()] = true

	# write
	for d in _rows:
		if not d.dirty: continue

		var new_name: String = d.line_edit.text.strip_edges()   # <- explicit type
		if new_name.is_empty(): continue

		var id: int = d.orig_id                                 # <- explicit type
		if id == -1:
			DB.insert_category(new_name)  # sets sync_flag = 1
		else:
			DB.update_category(id, new_name, d.orig_is_deleted)  # sets sync_flag = 1

	category_saved.emit()
	hide()

func _on_cancel_button_pressed():
	category_cancelled.emit()
	hide()

func _show_warning_dialog(msg: String):
	var dlg := AcceptDialog.new()
	dlg.title = tr("Warning")
	dlg.dialog_text = msg
	get_tree().root.add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)

# --------------------------------------------------
# add empty row
# --------------------------------------------------
func _on_add_button_pressed() -> void:
	_add_row({"id": -1, "name": "", "is_deleted": false})


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode in [KEY_BACK, KEY_ESCAPE]:
		_on_cancel_button_pressed()
