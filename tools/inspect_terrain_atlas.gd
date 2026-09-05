extends SceneTree
func _init() -> void:
	var report := {}
	for item: Array in [["architecture_kit",400],["ecology_kit",440]]:
		var image := Image.load_from_file("res://assets/runtime/terrain/%s.png" % item[0])
		var columns := 3 if item[0] == "architecture_kit" else 2
		var rectangles: Array[Rect2i] = []
		for y in range(2):
			for x in range(columns):
				rectangles.append(Rect2i(x*image.get_width()/columns,0 if y==0 else item[1],image.get_width()/columns,item[1] if y==0 else image.get_height()-int(item[1])))
		var entry := {"size":[image.get_width(),image.get_height()],"corner":str(image.get_pixel(0,0)),"blank":str(image.get_pixel(500,50)),"cells":[]}
		for rect: Rect2i in rectangles:
			var low := rect.end
			var high := rect.position
			for y in range(rect.position.y,rect.end.y):
				for x in range(rect.position.x,rect.end.x):
					if image.get_pixel(x,y).a >= 0.85:
						low.x = mini(low.x,x)
						low.y = mini(low.y,y)
						high.x = maxi(high.x,x)
						high.y = maxi(high.y,y)
			entry.cells.append([low.x,low.y,high.x-low.x+1,high.y-low.y+1])
		report[item[0]] = entry
	var file := FileAccess.open("res://assets/source/terrain/atlas_regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()
