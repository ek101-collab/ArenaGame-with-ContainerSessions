extends Area2D


func _on_area_entered(area: Area2D) -> void:
	var victim = area.get_parent() 
	var attacker = get_parent() 
	
	if victim == attacker:
		return
		
	if victim.has_method("apply_hit"):
		
		if attacker.is_local_player:
			
			Network.send_json({
				"type": "hit",
				"target": victim.player_id,
				"from": str(attacker.global_position)
			})
		
