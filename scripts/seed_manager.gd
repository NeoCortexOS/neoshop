# res://scripts/seed_manager.gd
extends Node

signal seed_completed(items_added: int, categories_added: int)
signal seed_cancelled()

var _is_seeding := false

func seed_database() -> void:
	if _is_seeding:
		return
	
	_is_seeding = true
	
	var dialog = AcceptDialog.new()
	dialog.title = "Seeding Database"
	dialog.dialog_text = "Adding sample data..."
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	var progress_label = Label.new()
	progress_label.text = "Adding categories..."
	container.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.max_value = 100
	progress_bar.value = 0
	container.add_child(progress_bar)
	
	dialog.add_child(container)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	
	# Async seeding
	_seed_async(dialog, progress_label, progress_bar)

func _seed_async(dialog: AcceptDialog, label: Label, progress: ProgressBar) -> void:
	var total_steps: float = 3.0
	var current_step: float = 0.0
	
	# Step 1: Add categories
	label.text = "Adding categories..."
	progress.value = 0
	await get_tree().create_timer(0.5).timeout
	
	var categories_added = _add_categories()
	current_step += 1
	progress.value = (current_step * 100) / total_steps
	
	# Step 2: Add items
	label.text = "Adding sample items..."
	await get_tree().create_timer(0.5).timeout
	
	var items_added = _add_items()
	current_step += 1
	progress.value = (current_step * 100) / total_steps
	
	# Step 3: Complete
	label.text = "Complete!"
	progress.value = 100
	await get_tree().create_timer(1.0).timeout
	
	dialog.queue_free()
	
	var result_dialog = AcceptDialog.new()
	result_dialog.title = "Seeding Complete"
	result_dialog.dialog_text = "Added %d categories and %d items.\n\nApp will return to planning screen in 3 seconds..." % [categories_added, items_added]
	
	get_tree().root.add_child(result_dialog)
	result_dialog.popup_centered()
	
	await get_tree().create_timer(3.0).timeout
	result_dialog.queue_free()
	
	_is_seeding = false
	emit_signal("seed_completed", items_added, categories_added)
	
	# Return to planning screen
	get_tree().change_scene_to_file("res://ui/PlanningScreen.tscn")

func _add_categories() -> int:
	var categories = ["Fruits", "Vegetables", "Dairy", "Meat", "Bakery", "Beverages", "Snacks", "Household"]
	var added = 0
	
	for category_name in categories:
		var inserted_id = DB.insert_category(category_name)
		if inserted_id > 0:
			added += 1
	
	return added


func _add_items() -> int:
	var items = [
		{"name": "Apples", "amount": 1, "unit": "kg", "description": "Fresh red apples", "category": "Fruits", "price_cents": 250, "needed": true},
		{"name": "Milk", "amount": 2, "unit": "L", "description": "Whole milk", "category": "Dairy", "price_cents": 180, "needed": true},
		{"name": "Bread", "amount": 1, "unit": "loaf", "description": "Whole wheat bread", "category": "Bakery", "price_cents": 220, "needed": true},
		{"name": "Chicken", "amount": 500, "unit": "g", "description": "Boneless chicken breast", "category": "Meat", "price_cents": 800, "needed": false},
		{"name": "Eggs", "amount": 12, "unit": "pieces", "description": "Free range eggs", "category": "Dairy", "price_cents": 350, "needed": true},
		{"name": "Bananas", "amount": 6, "unit": "pieces", "description": "Ripe bananas", "category": "Fruits", "price_cents": 150, "needed": true},
		{"name": "Tomatoes", "amount": 500, "unit": "g", "description": "Fresh tomatoes", "category": "Vegetables", "price_cents": 200, "needed": true},
		{"name": "Cheese", "amount": 200, "unit": "g", "description": "Cheddar cheese", "category": "Dairy", "price_cents": 450, "needed": false}
	]
	
	var added = 0
	
	# Build category name to ID mapping
	var categories = {}
	var cat_result = DB.select_categories()
	print("Available categories:", cat_result)
	
	for cat in cat_result:
		categories[cat["name"]] = cat["id"]
	
	for item_data in items:
		var category_name = item_data["category"]
		if categories.has(category_name):
			var params = {
				"name": item_data["name"],
				"amount": item_data["amount"],
				"unit": item_data["unit"],
				"description": item_data["description"],
				"category_id": categories[category_name],
				"price_cents": item_data["price_cents"],
				"needed": item_data["needed"]
			}
			var inserted_id = DB.insert_item(params)
			print("Inserted item with ID:", inserted_id)
			if inserted_id != "":
				added += 1
		else:
			print("Category not found:", category_name)
	
	print("Items added:", added)
	return added


func clear_database() -> void:
	DB.query("DELETE FROM item")
	DB.query("DELETE FROM category")
	DB.query("DELETE FROM shop")
	DB.query("DELETE FROM config")
	emit_signal("seed_cancelled")
