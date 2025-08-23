## Add a new item asynchronously
#func _on_AddButton_pressed():
	#var item = Item.new()
	#item.name = "Milk"
	#item.amount = 1.5
	#item.unit = "l"
	#item.needed = true
	#item.category_id = 2  # known id
#
	#await DB.insert_item(item.to_dict())
	#refresh_list()
#
#func refresh_list():
	#var rows := await DB.select_items("needed = 1")
	#$ItemList.clear()
	#for d in rows:
		#$ItemList.add_item(d["name"])
