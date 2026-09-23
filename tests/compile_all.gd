extends Node
func _ready() -> void:
	var d := DirAccess.open("res://scripts")
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s = load("res://scripts/" + f)
			if s == null:
				print("FAIL ", f)
	print("COMPILE_DONE")
	get_tree().quit()
