extends Node
class_name P2PManager_old

const UDP_PORT := 5678
const TCP_PORT := 8090
const MAGIC    := "_neoshop_p2p"

var udp_peer   : PacketPeerUDP
var tcp_server : TCPServer
var ws_client  : WebSocketPeer
var discovered : Array[Dictionary] = []
var my_name    : String
var broadcast_timer : Timer


func _ready() -> void:
	my_name = OS.get_unique_id()
	_start_udp()          # bind only
	_start_tcp_server()   # listen only


func host_session() -> void:
	if broadcast_timer:
		return   # already hosting
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 2.0
	broadcast_timer.timeout.connect(_broadcast)
	broadcast_timer.autostart = true
	add_child(broadcast_timer)
	emit_signal("hosting_started")
	print("Host started – broadcasting every 2 s")


func stop_hosting() -> void:
	if broadcast_timer:
		broadcast_timer.queue_free()
		broadcast_timer = null
		print("Host stopped")


func _broadcast() -> void:
	var ip := _get_local_ip()
	var pkt := { "magic": MAGIC, "name": my_name, "addr": ip, "port": TCP_PORT }
	udp_peer.set_dest_address("255.255.255.255", UDP_PORT)
	udp_peer.put_packet(JSON.stringify(pkt).to_utf8_buffer())
	print("UDP send: ", pkt)


func _start_udp() -> void:
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	var err := udp_peer.bind(UDP_PORT, "0.0.0.0")
	print("UDP bind → ", err)


func _start_tcp_server() -> void:
	tcp_server = TCPServer.new()
	var err := tcp_server.listen(TCP_PORT)
	print("TCP listen → ", err)
	if err == OK:
		emit_signal("hosting_started")



func _process(_dt) -> void:
	# --- incoming UDP only ---
	while udp_peer.get_available_packet_count() > 0:
		var data := udp_peer.get_packet().get_string_from_utf8()
		print("UDP recv: ", data)
		var msg : Variant = JSON.parse_string(data)
		if msg == null or not msg is Dictionary:
			push_warning("Bad packet: ", data)
			continue
		if msg.get("magic", "") == MAGIC and msg.get("name", "") != my_name:
			# simple dedup
			var exists := false
			for d in discovered:
				if d.name == msg.name:
					exists = true
					break
			if not exists:
				discovered.append(msg)
			emit_signal("discovered_changed")
			
	# --- WebSocket client poll ---
	if ws_client and ws_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws_client.get_available_packet_count() > 0:
			var pkt := ws_client.get_packet().get_string_from_utf8()
			print("WS recv: ", pkt)
			# TODO: apply incoming JSON


func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		# RFC-1918 private IPv4 only
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			if addr.begins_with("192.168.") or addr.begins_with("10."):
				return addr
			#if addr.begins_with("172."):
				#var b := int(addr.split(".")[1])
				#if 16 <= b and b <= 31:
					#return addr
	return "127.0.0.1"   # fallback


func join_session(addr: String, port: int) -> void:
	print("Joining ", addr, ":", port)
	ws_client = WebSocketPeer.new()
	var url := "ws://%s:%d" % [addr, port]
	var err := ws_client.connect_to_url(url)
	print("WS connect → ", err)

func close_all() -> void:
	if ws_client: ws_client.close()
	if tcp_server: tcp_server.stop()
	if udp_peer: udp_peer.close()

signal discovered_changed
signal hosting_started
