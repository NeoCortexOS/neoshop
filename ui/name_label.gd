extends Label

var styleBox: StyleBoxFlat
var myFontColor: Color
   
func _ready():
	return
	#print(styleBox.bg_color)
	styleBox = get_theme_stylebox("label")
	myFontColor = get_theme_color("font_color")
	print("name stylebox in _ready: ",styleBox.bg_color, styleBox.resource_path, myFontColor)

	# Get the font color defined for the current Control's class, if it exists.
	#modulate = Color.BLACK
	
