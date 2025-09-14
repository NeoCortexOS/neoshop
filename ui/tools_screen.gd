extends Control

@onready var export_button: Button = %ExportButton
@onready var import_button: Button = %ImportButton

func _ready() -> void:
	%BackButton.pressed.connect(_on_back)
	%SeedButton.pressed.connect(_on_seed)
	%ExportButton.pressed.connect(_on_export)
	%ImportButton.pressed.connect(_on_import)
	%DiagnosticsButton.pressed.connect(_on_diagnostics)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://ui/planning_screen.tscn")

func _on_seed() -> void:
	var seed_manager = preload("res://scripts/seed_manager.gd").new()
	add_child(seed_manager)
	seed_manager.seed_completed.connect(_on_seed_done)

func _on_seed_done(items: int, cats: int):
	print("Seeding complete: %d items, %d categories" % [items, cats])

func _on_export() -> void:
	var path := BackupManager.export_json()
	OS.shell_open("file://" + path)

func _on_import() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Import JSON"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json"])
	dialog.file_selected.connect(_on_import_file)
	add_child(dialog)
	dialog.popup_centered()

func _on_import_file(path: String) -> void:
	if BackupManager.import_json(path):
		OS.alert("Import successful!")
	else:
		OS.alert("Import failed!")

func _on_diagnostics() -> void:
	var ok = DB._db.query("PRAGMA integrity_check")
	OS.alert("Integrity: %s" % DB._db.query_result[0].integrity_check)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_BACK, KEY_ESCAPE] and event.pressed:
		_on_back()
