extends Control

@onready var code_input: LineEdit = $VBoxContainer/CodeInput
@onready var name_input: LineEdit = $VBoxContainer/NameInput

var pending_action = {}

func _get_player_name() -> String:
	return name_input.text.strip_edges()
		
func _ready():
	Network.disconnect_from_server()
	Network.message_received.connect(_on_network_message)
	Network.connected_to_server.connect(_on_socket_connected)

func _on_HostButton_pressed():
	var player_name = _get_player_name()
	if player_name.is_empty():
		show_error_name("Bitte gib einen Namen ein", true)
		return

	pending_action = {"type": "host", "name": player_name}
	Network.request_new_session()

func _on_JoinButton_pressed():
	var code = code_input.text.strip_edges()
	var player_name = _get_player_name()
	
	if code.is_empty():
		show_error_code("Bitte gib den Code ein", true)
		return
	else:
		show_error_code("", false)
		
	if player_name.is_empty():
		show_error_name("Bitte gib einen Namen ein", true)
		return
	else:
		show_error_name("", false)
	
	pending_action = {"type": "join", "name": player_name, "code": code}
	Network.request_session_ip(code)

func _on_socket_connected():
	if pending_action.is_empty(): return
	Network.send_json(pending_action)
	pending_action = {}
	
func _on_network_message(data):
	if data.has("type") and data["type"] == "session_info":
		get_tree().change_scene_to_file("res://ui/Lobby.tscn")
		print("lade lobby")
	elif data.has("type") and data["type"] == "error":
		print("Fehler vom Server: ", data["message"])

func show_error_name(msg: String, index: bool):
	if index:
		$VBoxContainer/ErrorLabel.visible = true
		$VBoxContainer/ErrorLabel.text = msg
		$VBoxContainer/ErrorLabel.modulate = Color(1, 0.0, 0.0, 1.0)
	else:
		$VBoxContainer/ErrorLabel.visible = false
		
func show_error_code(msg: String, index: bool):
	
	if index:
		$VBoxContainer/CodeError.visible = true
		$VBoxContainer/CodeError.text = msg
		$VBoxContainer/CodeError.modulate = Color(1, 0.0, 0.0, 1.0)
	else:
		$VBoxContainer/CodeError.visible = false
