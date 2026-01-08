extends Node

signal connected_to_server
signal message_received(data)

var MATCHMAKER_URL = "https://46.101.127.20.sslip.io/matchmaker"
var current_game_url = ""

var ws := WebSocketPeer.new()
var connected := false
var last_session_info = null
var local_player_id = ""
var session_code = ""

func _ready():
	MATCHMAKER_URL = "https://46.101.127.20.sslip.io/matchmaker"
	
	if OS.has_feature("web"):
		print("Browser-Modus: Matchmaker ist ", MATCHMAKER_URL)
	else:
		print("Editor-Modus: Matchmaker ist ", MATCHMAKER_URL)

func _process(_delta):
	ws.poll()
	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			print("WebSocket geöffnet und bereit!")
			connected_to_server.emit() 
		
		while ws.get_available_packet_count() > 0:
			var packet = ws.get_packet()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data:
				_handle_internal_data(data)
				message_received.emit(data)

	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		if connected:
			connected = false
			print("WebSocket geschlossen/getrennt.")

func _handle_internal_data(data):
	if data.has("type"):
		if data.type == "session_info" or data.type == "start_game":
			last_session_info = data
			if data.has("your_id"): local_player_id = data.your_id
			if data.has("code"): session_code = data.code

func request_new_session():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, response_code, _headers, body):
		if response_code != 200:
			print("Matchmaker Server Fehler: ", response_code)
			return
			
		var response_text = body.get_string_from_utf8()
		print("MATCHMAKER ANTWORT: ", response_text)
		var json = JSON.parse_string(response_text)
		
		if json and json.has("url"):
			print("Matchmaker Erfolg! Tunnel-URL: ", json.url)
			await get_tree().create_timer(0.5).timeout
			_connect_to_url(json.url)
		else:
			print("Matchmaker Fehler: Keine URL erhalten")
		http.queue_free()
	)
	http.request(MATCHMAKER_URL + "/create_session", [], HTTPClient.METHOD_POST)

func request_session_ip(code: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _response_code, _headers, body):
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("url"):
			_connect_to_url(json.url)
		else:
			print("Session-Code nicht gefunden oder keine URL vorhanden.")
		http.queue_free()
	)
	http.request(MATCHMAKER_URL + "/join_session/" + code, [], HTTPClient.METHOD_GET)

func _connect_to_url(url: String):
	ws = WebSocketPeer.new()
	connected = false 
	print("Verbinde über Tunnel: ", url)
	var err = ws.connect_to_url(url)
	if err != OK:
		print("Verbindungsfehler: ", err)

func disconnect_from_server():
	ws.close()
	connected = false

func send_json(data: Dictionary):
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		ws.send_text(json_string)
	else:
		print("Senden fehlgeschlagen: WebSocket nicht offen. Status: ", ws.get_ready_state())
