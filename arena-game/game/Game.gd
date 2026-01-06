extends Node2D

@export var player_scene: PackedScene
@export var YSort: Node2D
@onready var winnerpanel: Panel = $Winnerpanel

var players := {}            
var local_player_id := ""
var session_code := ""


func _ready():
	winnerpanel.visible = false
	Network.message_received.connect(_on_network_message)
	
	local_player_id = Network.local_player_id
	session_code = Network.session_code
	
	if Network.last_session_info:
		var players_info = Network.last_session_info.players
		for player in players_info:
			_spawn_player(player.id, player.name, player.x, player.y)
		
		

func _exit_tree():
	Network.message_received.disconnect(_on_network_message)
	
func _on_network_message(msg: Dictionary):
	match msg.type:
		"session_info":
			session_code = msg.code
			local_player_id = msg.your_id

		"player_leave":
			_remove_player(msg.player_id)

		"player_state":
			_update_player_state(msg)

		"hit":
			_apply_hit(msg)
		
		"game_over":
			_handle_game_over(msg.winner)


func _spawn_player(player_id: String, player_name := "", x = 0, y = 0):
	if players.has(player_id):
		return

	var p = player_scene.instantiate()
	p.player_id = player_id
	p.is_local_player = (player_id == local_player_id)
	
	YSort.add_child(p)
	p.player_name.text = player_name
	players[player_id] = p
	
	p.global_position = Vector2(x, y)
	p.apply_visual_identity()

func _remove_player(player_id: String):
	if not players.has(player_id):
		return

	players[player_id].queue_free()
	players.erase(player_id)

func _update_player_state(msg: Dictionary):
	var id = msg.id
	if id == local_player_id:
		return

	if not players.has(id):
		return

	var p = players[id]
	p.apply_network_state(msg)
	

func _apply_hit(msg: Dictionary):
	var target_id = msg.target
	var from_pos = _string_to_vector2(msg.from)
	var new_knockback_amount = int(msg.get("new_amount", 0))

	if not players.has(target_id):
		return

	players[target_id].apply_hit(from_pos, new_knockback_amount)

func _handle_game_over(winner_name: String):
	
	for id in players:
		var p = players[id]
		if p.state != p.PlayerState.DEATH:
			p.velocity = Vector2.ZERO
			p.state = p.PlayerState.IDLE 
		if p.has_method("freeze_player"):
			p.freeze_player()

	$Winnerpanel/Winner.text = winner_name + " hat gewonnen!"
	$Winnerpanel/Counter.text = "0"
	winnerpanel.visible = true
	
	for i in range(5, 0, -1):
		$Winnerpanel/Counter.text = str(i)
		await get_tree().create_timer(1.0).timeout
		
	Network.disconnect_from_server()
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")


func _string_to_vector2(string_val: String) -> Vector2:
	if string_val == "": return Vector2.ZERO
	# Klammern entfernen
	var clean = string_val.replace("(", "").replace(")", "")
	# Am Komma trennen
	var parts = clean.split(",")
	if parts.size() >= 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO
