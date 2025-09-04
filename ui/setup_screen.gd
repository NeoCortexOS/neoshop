extends Control

@onready var theme_option: OptionButton = %ThemeOption
@onready var language_option: OptionButton = %LanguageOption

func _ready() -> void:
	## translate UI
	#%TitleLabel.text      = tr("SETUP_TITLE")
	#%ThemeLabel.text      = tr("THEME")
	#%LanguageLabel.text   = tr("LANGUAGE")
	#%ApplyButton.text     = tr("APPLY")
	#%CancelButton.text    = tr("CANCEL")
	
	_load_settings()
	%ApplyButton.pressed.connect(_on_apply)
	%CancelButton.pressed.connect(_on_cancel)

func _load_settings() -> void:
	var theme: String = DB.get_config("theme", "light")
	var lang:  String = DB.get_config("language",  "en")

	# theme
	for i in theme_option.get_item_count():
		if theme_option.get_item_text(i).to_lower() == theme:
			theme_option.select(i)
			break

	# language
	var lang_idx := 0 if lang == "en" else 1
	language_option.select(lang_idx)

func _on_apply() -> void:
	var theme: String = theme_option.get_item_text(theme_option.selected).to_lower()
	var lang:  String = "en" if language_option.selected == 0 else "de"

	ThemeManager.apply_theme(theme)
	LocaleHelper.set_locale(lang)
	DB.set_config("theme", theme)
	DB.set_config("language", lang)
	get_tree().change_scene_to_file("res://ui/planning_screen.tscn")

func _on_cancel() -> void:
	get_tree().change_scene_to_file("res://ui/planning_screen.tscn")
