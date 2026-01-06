extends Area2D





func _on_area_entered(area: Area2D) -> void:
	if area.name == "DeathBarrier":
		get_parent().death()
