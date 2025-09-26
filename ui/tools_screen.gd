extends Control

const BACKUP_DIR := "user://backups"

@onready var dirty_btn: Button = %DirtyButton
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var list: ItemList = %DiscoveredList
@onready var status: Label = %StatusLabel
@onready var export_btn: Button = %ExportButton
@onready var import_btn: Button = %ImportButton
@onready var back_btn: Button = %BackButton
@onready var seed_btn: Button = %SeedButton
@onready var clear_btn: Button = %ClearButton
@onready var diag_btn: Button = %DiagnosticsButton
@onready var log_label: RichTextLabel = %LogLabel   # add to scene

func info(msg: String) -> void:
	print("[P2P] ", msg)
	if is_instance_valid(log_label):
		log_label.add_text(msg + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)


func _on_info_message(msg: String) -> void:
	if is_instance_valid(log_label):
		log_label.add_text(msg + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)


func _ready() -> void:
	dirty_btn.pressed.connect(_on_dirty)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	list.item_selected.connect(_on_pick_device)
	export_btn.pressed.connect(_on_export)
	import_btn.pressed.connect(_on_import)
	back_btn.pressed.connect(_on_back)
	seed_btn.pressed.connect(_on_seed)
	clear_btn.pressed.connect(_on_clear)
	diag_btn.pressed.connect(_on_diagnostics)
	P2P.discovered_changed.connect(_refresh_list)
	P2P.hosting_started.connect(_on_hosting)
	P2P.state_changed.connect(_on_p2p_state)
	P2P.info_message.connect(_on_info_message)
	P2P.sync_failed.connect(_on_sync_failed)


func _on_p2p_state(s: P2P.State) -> void:
	host_btn.disabled = s != P2P.State.IDLE
	join_btn.disabled  = s != P2P.State.IDLE
	match s:
		P2P.State.BROADCASTING:
			status.text = "Broadcasting…"; status.show()
		P2P.State.CONNECTED_HOST:
			status.text = "Host connected, syncing…"; status.show()
		P2P.State.SEARCHING:
			status.text = "Searching LAN…"; list.show(); status.show()
		P2P.State.JOINING:
			status.text = "Joining…"; status.show()
		P2P.State.SYNCING:
			status.text = "Syncing %s…" % P2P.sync_table; status.show()
		P2P.State.DONE:
			status.text = "Sync complete"; status.show()
			info("Sync complete")
		P2P.State.SHUTTING_DOWN:
			status.text = "Shutting down…"; status.show()
		P2P.State.IDLE:
			status.hide(); list.hide()


func _on_sync_failed() -> void:
	info("❌ Sync failed – tap Host/Join to retry")


func _on_dirty() -> void:
	DB.mark_all_dirty()


func _on_host() -> void:
	P2P.host_session()
	status.text = "Hosting on port 8090"
	status.show()


func _on_join() -> void:
	list.show()
	status.text = "Scanning LAN…"
	status.show()
	_refresh_list()


func _refresh_list() -> void:
	print("_refresh_list, discovered: ", P2P.discovered)
	list.clear()
	for d in P2P.discovered:
		list.add_item("%s  %s:%d" % [d.name, d.addr, d.port])
	if list.get_item_count() == 0:
		list.add_item("No devices found")


func _on_pick_device(index: int) -> void:
	var item: Dictionary = P2P.discovered[index]   # explicit cast
	P2P.join_session(item.addr, item.port)
	status.text = "Connecting to %s…" % item.name


func _on_hosting() -> void:
	status.text = "Host ready – waiting for peer…"


func _on_export() -> void:
	var path := BackupManager.export_json()
	OS.shell_open("file://" + path.get_base_dir())


func _on_import() -> void:
	var dlg := FileDialog.new()
	dlg.title   = "Import JSON"
	dlg.access  = FileDialog.ACCESS_FILESYSTEM
	dlg.current_dir = BACKUP_DIR
	
	dlg.filters = PackedStringArray(["*.json"])
	dlg.file_selected.connect(_on_import_file)
	dlg.min_size = Vector2i (300,800)
	dlg.max_size = Vector2i (650,900)

	dlg.add_theme_font_size_override("",18)
	add_child(dlg)
	dlg.popup_centered()


func _on_import_file(path: String) -> void:
	if BackupManager.import_json(path):
		OS.alert(tr("Import successful!"))
	else:
		OS.alert(tr("Import failed!"))


func _on_back() -> void:
	P2P.close_all()
	get_tree().change_scene_to_file("res://ui/planning_screen.tscn")


func _on_seed() -> void:
	var seed_manager = preload("res://scripts/seed_manager.gd").new()
	add_child(seed_manager)
	seed_manager.seed_completed.connect(_on_seed_done)
	seed_manager.seed_database()


func _on_seed_done(items: int, cats: int):
	print("Seeding complete: %d items, %d categories" % [items, cats])


func _on_clear() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.title = "Delete Database?"
	confirm.dialog_text = "This will erase the categories and items from your database.\n\nExisting data will be lost.\n\nContinue?"
	confirm.dialog_autowrap = true
	
	confirm.confirmed.connect(func():
			DB.clear_databases()             
			print("Databases deleted")
	)
	
	confirm.canceled.connect(func():
		print("Deleting cancelled")
	)
	
	get_tree().root.add_child(confirm)
	confirm.popup_centered()


func _on_diagnostics() -> void:
	var ok = DB._db.query("PRAGMA integrity_check")
	OS.alert("Integrity: %s" % DB._db.query_result[0].integrity_check)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_BACK, KEY_ESCAPE] and event.pressed:
		_on_back()
