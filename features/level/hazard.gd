class_name Hazard
extends Area2D


signal actor_hurt(actor: Node2D)
signal actor_killed(actor: Node2D)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func kill(actor: Node2D) -> void:
	actor_killed.emit(actor)


func _on_body_entered(actor: Node2D) -> void:
	actor_hurt.emit(actor)
	kill(actor)
