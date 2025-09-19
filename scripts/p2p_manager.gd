extends Node
class_name P2PManager

const UDP_PORT := 5678
const TCP_PORT := 8090
const MAGIC    := "_neoshop_p2p"

var udp_peer      : PacketPeerUDP
var tcp_server    : TCPServer
var ws_server     : WebSocketPeer   # host side
var ws_client     : WebSocketPeer   # client side
var discovered    : Array[Dictionary] = []
var my_name       : String
var broadcast_timer : Timer


# -------------------- LIFECYCLE --------------------
func _ready() -> void:
	my_name = OS.get_unique_id()
	print("P2PManager ready")
	_start_udp()
	# tcp_server started only when hosting

func _exit_tree() -> void:
	print("P2PManager exit tree")
	close_all()

func close_all() -> void:
	print("close_all called")
	stop_hosting()
	if ws_client and ws_client.get_ready_state() < WebSocketPeer.STATE_CLOSED:
		ws_client.close()
		ws_client = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	if udp_peer:
		udp_peer.close()
		udp_peer = null


# -------------------- UDP / TCP --------------------
func _start_udp() -> void:
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	var err := udp_peer.bind(UDP_PORT, "0.0.0.0")
	print("UDP bind result: ", err)

func _start_tcp_server() -> void:
	if tcp_server:
		return   # already listening
	tcp_server = TCPServer.new()
	var err := tcp_server.listen(TCP_PORT)
	print("TCP listen result: ", err)
	if err == OK:
		emit_signal("hosting_started")
		print("TCP server listening on ", TCP_PORT)


# -------------------- HOST --------------------
func host_session() -> void:
	if broadcast_timer:
		print("Already hosting – ignoring")
		return
	print("host_session called")
	_start_tcp_server()   # start TCP listen
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 2.0
	broadcast_timer.timeout.connect(_broadcast)
	broadcast_timer.autostart = true
	add_child(broadcast_timer)
	emit_signal("hosting_started")
	print("Host timer started")

func stop_hosting() -> void:
	print("stop_hosting called")
	if broadcast_timer:
		broadcast_timer.stop()
		broadcast_timer.queue_free()
		broadcast_timer = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
		print("TCP server stopped")


func _broadcast() -> void:
	var ip := _get_local_ip()
	var pkt := { "magic": MAGIC, "name": my_name, "addr": ip, "port": TCP_PORT }
	udp_peer.set_dest_address("255.255.255.255", UDP_PORT)
	udp_peer.put_packet(JSON.stringify(pkt).to_utf8_buffer())
	print("UDP broadcast: ", pkt)


# -------------------- CLIENT --------------------
func join_session(addr: String, port: int) -> void:
	print("join_session called: ", addr, ":", port)
	ws_client = WebSocketPeer.new()
	var url := "ws://%s:%d" % [addr, port]
	var err := ws_client.connect_to_url(url)
	print("WS client connect result: ", err)


# -------------------- MAIN LOOP --------------------
func _process(_dt) -> void:
	# --- incoming UDP (always on) ---
	while udp_peer.get_available_packet_count() > 0:
		var data := udp_peer.get_packet().get_string_from_utf8()
		print("UDP recv: ", data)
		var msg: Variant = JSON.parse_string(data)
		if msg == null or not msg is Dictionary:
			push_warning("Bad packet: ", data)
			continue
		if msg.get("magic", "") == MAGIC and msg.get("name", "") != my_name:
			var exists := false
			for d: Dictionary in discovered:
				if d.name == msg.name:
					exists = true
					break
			if not exists:
				discovered.append(msg)
			emit_signal("discovered_changed")

	# --- TCP accept & upgrade (host) ---
	if tcp_server and tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		peer.poll()   # flush handshake
		print("TCP peer accepted: ", peer.get_connected_host(), ":", peer.get_connected_port())
		ws_server = WebSocketPeer.new()
		var err := ws_server.accept_stream(peer)
		print("WS server accept_stream result: ", err)
		if err != OK:
			push_error("WS upgrade failed")
			return
		print("WS server created, state: ", ws_server.get_ready_state())

	# --- host send (wait for OPEN) ---
	# --- poll server WebSocket (required) ---
	if ws_server:
		ws_server.poll()
		var state := ws_server.get_ready_state()
		print("WS server state: ", state)
		match state:
			WebSocketPeer.STATE_CONNECTING:
				pass
			WebSocketPeer.STATE_OPEN:
				print("WS server OPEN – sending rows")
				_send_dirty_rows()
				await get_tree().create_timer(0.5).timeout   # let client read
				ws_server.close(1000, "done")
				ws_server = null
				stop_hosting()
			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
				print("WS server closed")
				ws_server = null
				stop_hosting()

	# --- client receive (wait for OPEN) ---
	if ws_client:
		ws_client.poll()   # <-- NEW
		var state := ws_client.get_ready_state()
		print("WS client state: ", state)
		match state:
			WebSocketPeer.STATE_CONNECTING:
				pass
			WebSocketPeer.STATE_OPEN:
				print("WS client OPEN – receiving")
				while ws_client.get_available_packet_count() > 0:
					var pkt := ws_client.get_packet().get_string_from_utf8()
					print("WS client recv: ", pkt)
					if pkt == "{\"done\":true}":
						ws_client.close()
						print("Client import complete")
						continue
					var row : Variant = JSON.parse_string(pkt)
					if row is Dictionary:
						_apply_row(row)
			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
				print("WS client closed")
				ws_client = null


# -------------------- DATA HELPERS --------------------
func _send_dirty_rows() -> void:
	var dirty := DB.select_dirty("item")   # only items for now
	print("Host sending ", dirty.size(), " dirty rows")
	for row in dirty:
		ws_server.send_text(JSON.stringify(row))
	ws_server.send_text("{\"done\":true}")

func _apply_row(row: Dictionary) -> void:
	# last-write-wins: insert or update
	if row.has("id") and int(row.id) > 0:
		DB.update_item(row)
	else:
		DB.insert_item(row)

func _mark_clean_and_refresh() -> void:
	var dirty := DB.select_dirty("item")
	for d in dirty:
		DB.mark_clean("item", int(d.id))
	get_tree().call_group("ui", "refresh")

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			if addr.begins_with("192.168.42") or addr.begins_with("10."):
				return addr
			#if addr.begins_with("172."):
				#var b := int(addr.split(".")[1])
				#if 16 <= b and b <= 31:
					#return addr
	return "192.168.1.100"   # fallback

signal discovered_changed
signal hosting_started
