# res://scripts/p2p_manager.gd
extends Node
class_name P2PManager

#enum State { IDLE, DISCOVERING, CONNECTING, SYNCING, SENDING, RECEIVING, TABLE_DONE, DONE, SHUTTING_DOWN }
enum State { 
	IDLE, 
	DISCOVERING, 
	CONNECTING, 
	SYNCING, 
	HOST_SENDING, 
	CLIENT_RECEIVING, 
	SHUTTING_DOWN, 
	DONE 
}
signal state_changed(new_state: State)
signal discovered_changed
signal sync_progress(table: String, current: int, total: int)
signal table_done(table: String)
signal sync_complete()
signal sync_failed()
signal info_message(text: String)

const UDP_PORT := 5678
const TCP_PORT := 8090
const MAGIC    := "_neoshop_p2p"
const SYNC_TIMEOUT := 15.0

# ---------- original networking objects ----------
var udp_peer: PacketPeerUDP
var tcp_server: TCPServer
var ws_peer: WebSocketPeer           # unified end-point (server or client)
var discovered: Array[Dictionary] = []
var my_name: String
var broadcast_timer: Timer
var timeout_timer: Timer

# ---------- new sync state ----------
var state: State = State.IDLE
var old_state : State = State.IDLE
var client_rcv_state : State = State.IDLE
var role_sender: bool = true         # true = I send rows first for current table
var current_table: String = ""
var current_row_index: int = 0
var current_rows: Array = []
#var tables: PackedStringArray = ["category", "item", "shop"]
var tables: PackedStringArray = ["category", "item"]
var table_index: int = 0

func _ready():
	my_name = OS.get_unique_id() if OS.get_name() != "Web" else "Web"
	if(OS.get_name() == "Linux"):
		var output = []
		OS.execute("/bin/sh", ["-c", "hostname"], output )
		info(str(output))
		my_name = output[0].strip_edges()
	if(OS.get_name() == "Android"):
		var output = []
		OS.execute("getprop", ["ro.product.model"], output )
		# [ro.product.model]: [SM-N986B]

		info(str(output))
		my_name = output[0].strip_edges()


func _exit_tree():
	close_all()


# ---------- state ----------
func _set_state(s: State):
	if state == s: return
	state = s
	state_changed.emit(s)
	info_message.emit("P2P → %s" % State.keys()[s])


# ---------- logging ----------
func info(msg: String):
	#print("[P2P] ", msg)
	info_message.emit("[P2P] " + msg)


# ---------- discovery ----------
func _start_udp():
	info("_start_udp")
	if udp_peer:
		info("udp_peer already exists")
		return
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	udp_peer.bind(UDP_PORT, "0.0.0.0")


func _stop_udp():
	info(self.name)
	if broadcast_timer:
		broadcast_timer.queue_free()
		broadcast_timer = null
	if udp_peer:
		udp_peer.close()
		udp_peer = null


##
## starts hosting session, is called from tools_screen
##
func host_session():
	if state != State.IDLE: return
	_set_state(State.DISCOVERING)
	_start_udp()
	_start_broadcast_timer()


func _start_broadcast_timer():
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 2.0
	broadcast_timer.timeout.connect(_broadcast)
	broadcast_timer.autostart = true
	add_child(broadcast_timer)


func _broadcast():
	var pkt = { "magic": MAGIC, "name": my_name, "addr": _get_local_ip(), "port": TCP_PORT }
	udp_peer.set_dest_address("255.255.255.255", UDP_PORT)
	udp_peer.put_packet(JSON.stringify(pkt).to_utf8_buffer())


func join_session(addr: String, port: int):
	info("join_session, addr: " + addr + ":" + str(port) + " state: " + State.keys()[state])
	#if state != State.IDLE: return
	_stop_udp()
	_set_state(State.CONNECTING)
	_real_connect(addr, port)


func _real_connect(addr: String, port: int):
	ws_peer = WebSocketPeer.new()
	var url := "ws://%s:%d" % [addr, port]
	var err := ws_peer.connect_to_url(url)
	if err != OK:
		info("WS connect error %d" % err)
		_idle_reset()
		return
	info("WS connecting to %s" % url)
	_start_timeout()


# ---------- accept ----------
func _process(_dt):
	_poll_udp()
	_poll_host_accept()
	_poll_client_recv()
	#_poll_state_done()
	# flush WebSocket every frame so handshake completes while in SENDING
	if is_instance_valid(ws_peer):
		ws_peer.poll()


func _poll_udp():
	if not udp_peer or udp_peer.get_available_packet_count() < 1: return
	#info("poll_udp pkgs: " + str(udp_peer.get_available_packet_count()))
	var data := udp_peer.get_packet().get_string_from_utf8()
	var msg : Variant = JSON.parse_string(data)
	info("poll_udp msg: " + str(msg))
	if msg and msg.get("magic", "") == MAGIC and msg.get("name", "") != my_name:
		var exists := false
		for d in discovered:
			if d.name == msg.name: exists = true; break
		if not exists:
			discovered.append(msg)
			discovered_changed.emit()


func _poll_host_accept():
	if state != State.DISCOVERING: return
	if state != old_state:
		info("poll_host_accept, state: " + State.keys()[old_state] + " -> " + State.keys()[state])
		old_state = state
	if not tcp_server:
		tcp_server = TCPServer.new()
		var err := tcp_server.listen(TCP_PORT)
		info("TCP listen result=%d" % err)
		if err != OK:
			push_error("TCP listen failed"); _idle_reset(); return
	if tcp_server and tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		ws_peer = WebSocketPeer.new()
		ws_peer.poll()   # flush handshake
		var err := ws_peer.accept_stream(peer)
		if err == OK:
			info("peer connected")
			_stop_udp()
			peer.set_no_delay(true)   # disable Nagle
			_set_state(State.HOST_SENDING)
			_start_timeout()
			_start_table_sync()
		else:
			push_error("WS accept failed"); _idle_reset()


# ---------- client recv ----------
func _poll_client_recv():
	if state != client_rcv_state:
		info("poll_client_recv, state: " + State.keys()[client_rcv_state] + " -> "+ State.keys()[state])
		client_rcv_state = state
	if not is_instance_valid(ws_peer) or ws_peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		#info("_poll_client_recv: ws_peer not available")
		return
	ws_peer.poll()
	var st := ws_peer.get_ready_state()
	match st:
		WebSocketPeer.STATE_CONNECTING:
			return
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING:
				_set_state(State.CLIENT_RECEIVING)
				_start_timeout()
				_start_table_sync() # currently does nothing if CLIENT_RECEIVING
			while ws_peer.get_available_packet_count() > 0:
				var pkt := ws_peer.get_packet().get_string_from_utf8()
				info("client received: " + str(pkt))
				var msg: Dictionary = JSON.parse_string(pkt) as Dictionary
				if msg == null: continue
				#if msg.has("table_done") and state == State.CLIENT_RECEIVING:
				if msg.has("table_done"):
					#_swap_role()
					info("table_done received, state = " + State.keys()[state])
					ws_peer.send_text(JSON.stringify({ "next_table": true, "table": current_table}))
					return
				if msg.has("next_table"):
					info("next_table received, state = " + State.keys()[state] + " table: " + msg.get("table", "empty???"))
					#_swap_role()
					if state == State.HOST_SENDING:
						info("host sending going to next table")
						_next_table()
					return
				if msg.has("table") and msg.has("row"):
					_handle_row(str(msg.table), msg.row)
				elif msg.has("ack") and msg.has("id") and msg.has("action"):
					_handle_ack(msg)
			#info("no msg received")
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			_idle_reset()


func _poll_state_done():
	if state == State.DONE:
		_idle_reset()


func _start_table_sync():
	if state == State.HOST_SENDING:
		# ---------- wait for OPEN (max 3 s) ----------
		var t1 := Time.get_ticks_msec()
		while ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t1 < 3000:
			ws_peer.poll()
			OS.delay_msec(10)
		info("ws open wait time: " + str(Time.get_ticks_msec() - t1))
		if ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			push_error("Server WS never entered OPEN")
			_idle_reset()
			return
		# ---------- now safe to send ----------
		# Host sends table data
		table_index = -1 # as it will be incremented in _next_table
		_next_table()
	elif state == State.CLIENT_RECEIVING:
		# Client waits for table data
		# No action needed here, data will be received in _poll_client_recv
		pass


func _send_next_row():
	if state != State.HOST_SENDING:
		return
	# Send the next row from current_rows
	var row : Dictionary = current_rows[current_row_index]
	row["sync_flag"] = 0
	print("send_next_row: " + str(row))
	var msg := {
		"table": current_table,
		"row": row
	}
	_send_message(msg)
	# Wait for acknowledgment before proceeding
	# This requires implementing a proper acknowledgment system

# ---------- sender ----------
func _send_rows():
	if current_row_index >= current_rows.size():
		_send_table_done()
		return
	var row: Dictionary = current_rows[current_row_index] as Dictionary
	row["sync_flag"] = 0
	var pkt := { "table": current_table, "row": row }
	ws_peer.send_text(JSON.stringify(pkt))
	sync_progress.emit(current_table, current_row_index + 1, current_rows.size())


func _send_message(msg: Dictionary):
	info("_send_message: " + str(msg))
	ws_peer.send_text(JSON.stringify(msg))


func _send_table_done():
	if state != State.HOST_SENDING:
		return
	var msg := {
		"table_done": true
	}
	_send_message(msg)
	

##
## checks if all tables are done
##
func _next_table():
	table_index += 1
	if table_index >= tables.size():
		_set_state(State.DONE)
		sync_complete.emit()
		_idle_reset()
		return
	current_table = tables[table_index]
	current_rows = DB.select_dirty(current_table)
	info("next_table found " + str(current_rows.size()) + " dirty records in " + current_table)
	current_row_index = 0
	if current_rows.size() == 0:
		#_swap_role()          # nothing to send, flip immediately
		table_done.emit(current_table)
		_send_table_done()
		_next_table()
	else:
		_set_state(State.HOST_SENDING)
		_send_next_row()

func _swap_role():
	role_sender = !role_sender
	info("_swap_role called, role_sender now = " + str(role_sender))
	if role_sender:
		# re-fetch rows (after previous receiver may have modified)
		current_rows = DB.select_dirty(current_table)
		current_row_index = 0
	if current_rows.size() > 0:
		_set_state(State.HOST_SENDING)
	else:
		# both sides sent → table finished
		#table_index += 1
		table_done.emit(current_table)
		_next_table()


# ---------- receiver ----------
func _handle_row(table: String, row: Dictionary):
	#var row: Dictionary = remote
	if state == State.CLIENT_RECEIVING:
		# Process received row
		# Compare timestamps and upsert if remote is newer
		# Send appropriate ACK
		_handle_client_row(table, row)
	elif state == State.HOST_SENDING:
		# Handle row received from client
		# Resolve conflicts and send appropriate response
		_handle_host_row(table, row)


func _handle_client_row(table: String, row: Dictionary):
	# Client receives row, upserts if newer, sends ACK
	# Implementation depends on your database structure
	var local: Dictionary = _select_local_row(table, row.get("id", ""))
	var use_remote := true
	if not local.is_empty():
		var local_time := int(local.get("updated_at", 0))
		var remote_time := int(row.get("updated_at", 0))
		if local_time > remote_time:
			use_remote = false
	if use_remote:
		_upsert_row(table, row)
		_send_ack(str(row.get("id", "")), "accept", {})
	else:
		_send_ack(str(row.get("id", "")), "reject", local)


func _handle_host_row(table: String, row: Dictionary):
	# Host receives row from client, handles conflicts
	# Implementation depends on your database structure
	info("_handle_host_row: " + str(row.id))
	pass


func _send_ack(id: String, action: String, row: Dictionary = {}):
	#info("send_ack: " + id + " " + action + " " + str(row))
	var ack := { "ack": true, "id": id, "action": action }
	if action == "reject":
		ack["row"] = row
	ws_peer.send_text(JSON.stringify(ack))

# ---------- ack handler ----------
func _handle_ack(msg: Dictionary):
	var id := str(msg.get("id", ""))
	var action: String = str(msg.get("action", ""))
	if action == "accept":
		DB.mark_clean(current_table, id)
	elif action == "reject" and msg.has("row"):
		var row: Dictionary = msg.row as Dictionary
		_upsert_row(current_table, row)
		info("_handle_ack " + current_table + " " + str(row))
	current_row_index += 1
	_send_rows()

# ---------- helpers ----------

func _select_local_row(table: String, id: Variant):
	match table:
		"category": 
			var res := DB.select_category(int(id))
			return Category.new(res[0]).to_dict() if res.size() else {}
		"item":     
			var res := DB.select_item(str(id))
			return Item.new(res[0]).to_dict() if res.size() else {}
		_:          return {}

func _upsert_row(table: String, row: Dictionary):
	match table:
		"category": DB.upsert_category(row.get("id", -1), row.get("name", ""), row.get("is_deleted", false))
		"item":     DB.upsert_item(row)

# ---------- timeout / shutdown (unchanged) ----------
func _start_timeout():
	if timeout_timer: timeout_timer.queue_free()
	timeout_timer = Timer.new()
	timeout_timer.wait_time = SYNC_TIMEOUT
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)

func _on_timeout():
	info("Sync timeout")
	sync_failed.emit()
	_idle_reset()

func close_all():
	if state == State.IDLE: return
	_idle_reset()

func _idle_reset():
	_set_state(State.SHUTTING_DOWN)
	_stop_udp()
	if timeout_timer:
		timeout_timer.queue_free()
		timeout_timer = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	if ws_peer and ws_peer.get_ready_state() < WebSocketPeer.STATE_CLOSED:
		ws_peer.close()
	ws_peer = null
	discovered.clear()
	_set_state(State.IDLE)

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			if addr.begins_with("192.168.42") or addr.begins_with("10."):
				return addr
			#if addr.begins_with("172."):
				#var b := int(addr.split(".")[1])
				#if 16 <= b and b <= 31:
					#return addr
	return "192.168.1.100"   # fallback100"
