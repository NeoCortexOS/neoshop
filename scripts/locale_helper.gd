extends Node

func set_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	DB.set_config("language", code)   # store preference
