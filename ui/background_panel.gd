extends Panel

var styleBox: StyleBoxFlat 
   
func _ready():
	#return
	styleBox = get_theme_stylebox("panel")
	print("panel stylebox in _ready: ",styleBox.bg_color, styleBox.resource_path, )
	add_theme_stylebox_override("panel", styleBox)
