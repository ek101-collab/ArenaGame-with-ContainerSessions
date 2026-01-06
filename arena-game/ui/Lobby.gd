extends Control

@onready var session_label: Label = $VBoxContainer/SessionCodeLabel
@onready var player_list: ItemList = $VBoxContainer/PlayerList
@onready var start_button: Button = $VBoxContainer/StartButton

var is_host := false

func _ready():
	start_button.visible = false
	Network.message_received.connect(_on_message)
	
	
	if Network.last_session_info:
		_on_message(Network.last_session_info)

func _exit_tree():
	if Network.message_received.is_connected(Callable(self, "_on_message")):
		Network.message_received.disconnect(Callable(self, "_on_message"))

func _on_message(msg):
	match msg.type:
		"session_info":
			session_label.text = "Session Code: " + msg.code
			is_host = msg.is_host
			start_button.visible = is_host
			update_players(msg.players)
		"player_list":
			update_players(msg.players)

		"start_game":
			get_tree().change_scene_to_file("res://game/Game.tscn")

func update_players(players):
	player_list.clear()
	for p in players:
		var display_name = ""
		if p.id == Network.local_player_id:
			display_name = p.name + " (Du)"
		else:
			display_name = str(p.name)
			
		player_list.add_item(display_name)

func _on_StartButton_pressed():
	if not is_host:
		return

	Network.send_json({
		"type": "start_game"
	})
