@tool
class_name GreenhouseBackdrop
extends Node2D
@export var length: float = 9200.0
@export var background_texture: Texture2D
@export var floor_y: float = 400.0
func _draw() -> void:
	draw_rect(Rect2(-300,-800,length+600,1500),Color("#172e2c"))
	if background_texture == null:
		return
	var height := 950.0
	var width := height * background_texture.get_width() / float(background_texture.get_height())
	for index in range(-1,ceili(length / width)+1):
		draw_texture_rect(background_texture,Rect2(index*width,-280,width,height),false,Color(0.56,0.69,0.64,1.0))
