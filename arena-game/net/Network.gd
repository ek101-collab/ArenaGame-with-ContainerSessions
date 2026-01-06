extends Node

signal connected_to_server
signal message_received(data)

var MATCHMAKER_URL = "http://127.0.0.1:8001"
var ws_url = ""

var ws := WebSocketPeer.new()
var connected := false
var last_session_info = null
var local_player_id = ""
var session_code = ""

func _ready():
	if OS.has_feature("web"):
		var current_host = JavaScriptBridge.eval("window.location.hostname")
		var current_protocol = JavaScriptBridge.eval("window.location.protocol")
		
		MATCHMAKER_URL = current_protocol + "//" + current_host + ":8001"
		print("Browser-Modus: Matchmaker ist ", MATCHMAKER_URL)
	else:
		MATCHMAKER_URL = "http://127.0.0.1:8001"
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
		
		if json and json.has("ip") and json.has("port"):
			await get_tree().create_timer(0.5).timeout
			_connect_ws(json.ip, str(json.port))
		else:
			print("Matchmaker Fehler: Ungültiges JSON erhalten")
		http.queue_free()
	)
	http.request(MATCHMAKER_URL + "/create_session", [], HTTPClient.METHOD_POST)

func request_session_ip(code: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _response_code, _headers, body):
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("ip") and json.has("port"):
			_connect_ws(json.ip, str(json.port))
		else:
			print("Session-Code nicht gefunden.")
		http.queue_free()
	)
	http.request(MATCHMAKER_URL + "/join_session/" + code, [], HTTPClient.METHOD_GET)

func _connect_ws(ip: String, port: String):
	ws = WebSocketPeer.new()
	connected = false 
	
	var protocol = "ws://"
	
	if OS.has_feature("web"):
		var current_protocol = JavaScriptBridge.eval("window.location.protocol")
		
		if current_protocol == "https:":
			protocol = "wss://"
		
	var target_ip = ip
	
	if OS.has_feature("web"):
		if ip == "DYNAMIC_HOST" or ip == "127.0.0.1" or ip == "localhost":
			target_ip = JavaScriptBridge.eval("window.location.hostname")
			print("Web-Fix: Nutze Hostname ", target_ip, " statt ", ip)
		
	var url = protocol + target_ip + ":" + port + "/ws"
	print("Versuche WebSocket Verbindung zu: ", url)
	
	var error = ws.connect_to_url(url)
	if error != OK:
		print("Kritischer Fehler beim Starten der Verbindung: ", error)

func disconnect_from_server():
	ws.close()
	connected = false

func send_json(data: Dictionary):
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		ws.send_text(json_string)
	else:
		print("Senden fehlgeschlagen: WebSocket nicht offen. Status: ", ws.get_ready_state())
