class_name NutritionTank
extends Area2D


func absorb(actor: Node, amount: float) -> bool:
	if amount <= 0.0 or not actor.has_method(&"absorb_nutrition"):
		return false

	return actor.call(&"absorb_nutrition", amount) == true
