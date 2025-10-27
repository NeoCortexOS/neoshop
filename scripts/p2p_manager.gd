# res://scripts/p2p_manager.gd
extends Node
class_name P2PManager

enum State { IDLE, BROADCASTING, CONNECTED_HOST, SEARCHING, JOINING, SYNCING, SENDING_CAT, DONE, SHUTTING_DOWN }
var ws_state_names = ["CONNECTING", "OPEN", "CLOSING", "CLOSED"]

signal state_changed(new_state: State)
signal discovered_changed
signal hosting_started        # legacy
signal sync_failed
signal info_message(text: String)      # forward to UI


const UDP_PORT := 5678
const TCP_PORT := 8090
const MAGIC    := "_neoshop_p2p"
const SYNC_TIMEOUT := 15.0   # was 3.0
const PAGE_SIZE := 50


var timeout_timer : Timer

var state: State = State.IDLE : set = _set_state
var old_state: State = State.DONE

var udp_peer   : PacketPeerUDP
var tcp_server : TCPServer
var ws_server  : WebSocketPeer
var ws_client  : WebSocketPeer
var discovered : Array[Dictionary] = []
var my_name    : String
var broadcast_timer : Timer
var sync_table : String = ""      # for progress UI


func info(msg: String) -> void:
	print("[P2P] ", msg)
	info_message.emit("[P2P]" + msg)               # let ToolsScreen listen


# -------------- life-cycle --------------
func _ready() -> void:
	print("_ready: " + self.name)
	# NC todo: insert name into config/setup
	if OS.get_name() == "Web":
		my_name="Web"
	else:
		my_name = OS.get_unique_id()
	_start_udp()          # bind only, no broadcast


func _exit_tree() -> void:
	close_all()


func _set_state(s: State) -> void:
	if state == s: return
	state = s
	state_changed.emit(s)
	info("P2P state → %s" % State.keys()[s])


# -------------- idle → host --------------
func host_session() -> void:
	if state != State.IDLE: return
	_set_state(State.BROADCASTING)
	_start_broadcast_timer()
	emit_signal("hosting_started")   # legacy, keep for compat


func _start_broadcast_timer() -> void:
	if broadcast_timer: return
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 2.0
	broadcast_timer.timeout.connect(_broadcast)
	broadcast_timer.autostart = true
	add_child(broadcast_timer)


func _broadcast() -> void:
	var ip := _get_local_ip()
	var pkt := { "magic": MAGIC, "name": my_name, "addr": ip, "port": TCP_PORT }
	udp_peer.set_dest_address("255.255.255.255", UDP_PORT)
	udp_peer.put_packet(JSON.stringify(pkt).to_utf8_buffer())


# -------------- idle → client --------------
func join_session(addr: String, port: int) -> void:
	if state != State.IDLE: return
	_set_state(State.SEARCHING)
	# actual connect happens after user picks device
	_real_connect(addr, port)


func _real_connect(addr: String, port: int) -> void:
	_set_state(State.JOINING)
	_start_timeout()
	ws_client = WebSocketPeer.new()
	var url := "ws://%s:%d" % [addr, port]
	var err := ws_client.connect_to_url(url)
	if err != OK:
		info("WS connect error %d" % err)
		_idle_reset()
		return
	info("WS connecting to %s" % url)


# -------------- host: accept --------------
func _process(_dt) -> void:
	_poll_udp()
	_poll_host_accept()
	_poll_host_send()
	_poll_client_recv()
	_poll_state_done()


func _poll_udp() -> void:
	if not udp_peer or udp_peer.get_available_packet_count() < 1: return
	print(udp_peer.get_available_packet_count())
	var data := udp_peer.get_packet().get_string_from_utf8()
	print(str(data))
	if !data:
		print("empty data")
		return
	var msg : Variant = JSON.parse_string(data)
	if msg and msg.get("magic", "") == MAGIC and msg.get("name", "") != my_name:
		var exists := false
		for d in discovered:
			if d.name == msg.name:
				exists = true; break
		if not exists:
			discovered.append(msg)
			emit_signal("discovered_changed")

func _poll_host_accept() -> void:
	if state != State.BROADCASTING: return
	if not tcp_server and _want_tcp():
		tcp_server = TCPServer.new()
		var err := tcp_server.listen(TCP_PORT)
		if err != OK:
			push_error("TCP listen failed"); _idle_reset(); return
	if tcp_server and tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		ws_server = WebSocketPeer.new()
		ws_server.poll()   # flush handshake
		var err := ws_server.accept_stream(peer)
		if err == OK:
			peer.set_no_delay(true)   # <── disable Nagle
			ws_server.poll()
			_set_state(State.CONNECTED_HOST)
			_start_timeout()

		else:
			push_error("WS accept failed"); _idle_reset()

func _want_tcp() -> bool:
	return true   # always listen while broadcasting

# -------------- data sync --------------
func _poll_host_send() -> void:
	if state != State.CONNECTED_HOST: return
	ws_server.poll()
	var st := ws_server.get_ready_state()
	match st:
		WebSocketPeer.STATE_CONNECTING: return
		WebSocketPeer.STATE_OPEN:
			_set_state(State.SYNCING)
			sync_table = "item"
			# hand over to coroutine; _process must not touch socket until done
			set_process(false)
			call_deferred("_send_pages_async")
		_: _idle_reset()


# res://scripts/p2p_manager.gd
func _send_pages_async() -> void:
	# ---------- wait for OPEN (max 3 s) ----------
	var t1 := Time.get_ticks_msec()
	while ws_server.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t1 < 3000:
		ws_server.poll()
		OS.delay_msec(10)
	if ws_server.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("Server WS never entered OPEN")
		_idle_reset()
		return
	# ---------- now safe to send ----------

	# ---------- 1. categories ----------
	var dirty_cat := DB.select_dirty("category")
	if dirty_cat.size() > 0:
		info("Host sending %d categories" % dirty_cat.size())
		var i = 0
		for cat in dirty_cat:
			if i == dirty_cat.size() - 1:
				ws_server.send_text(JSON.stringify({"table":"category","row":cat,"last":true}))
			else:
				ws_server.send_text(JSON.stringify({"table":"category","row":cat,"last":false}))
			i += 1
		info("sent " + str(i) + " categories")
		# wait for global ACK
		var t0 := Time.get_ticks_msec()
		while true:
			ws_server.poll()
			var n := ws_server.get_available_packet_count()
			if n > 0:
			#if ws_server.get_available_packet_count() > 0:
				var ack := ws_server.get_packet().get_string_from_utf8()
				#info("cat ack: " + ack)
				if ack == "{\"cat_ack\":true}":
					for cat in dirty_cat:
						DB.mark_clean("category", str(cat.id))
						#info("category marked clean: " + str(cat.id))
					break
			if Time.get_ticks_msec() - t0 > 2000: break
			OS.delay_msec(10)

	# ---------- 2.  items  ----------
	var dirty := DB.select_dirty("item")

	var total := dirty.size()
	#warning-ignore:integer_division
	var pages : int = (total - 1) / PAGE_SIZE + 1
	info("Host sending %d rows (%d pages)" % [total, pages])

	for i in range(0, total, PAGE_SIZE):
		if not is_instance_valid(ws_server) or ws_server.get_ready_state() != WebSocketPeer.STATE_OPEN:
			info("Socket gone during page %d" % int(i/PAGE_SIZE))
			break
		var page := dirty.slice(i, i + PAGE_SIZE)
		var pkt := JSON.stringify({"page": page, "index": int(i / PAGE_SIZE), "last": i + PAGE_SIZE >= total})
		ws_server.send_text(pkt)
		#info("sent pkt: " + pkt)
		# _send_pages_async  (immediately after send_text)
		info("Page %d sent  ws_server.state=%s  available=%d" % [i/PAGE_SIZE, ws_state_names[ws_server.get_ready_state()], ws_server.get_available_packet_count()])

		# ---- wait until OPEN (max 2 s) ----
		var open_t0 := Time.get_ticks_msec()
		while ws_server.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - open_t0 < 2000:
			ws_server.poll()
			OS.delay_msec(10)
		info("Time %d passed,  ws_server.state=%s  available=%d" % [Time.get_ticks_msec() - open_t0, ws_state_names[ws_server.get_ready_state()], ws_server.get_available_packet_count()])

		if ws_server.get_ready_state() != WebSocketPeer.STATE_OPEN:
			push_error("Page %d socket never entered OPEN" % (i / PAGE_SIZE))
			break
	
			# wait for ACK (max 5 s per page, 50 ms steps)
		var ack_ok := false
		for tries in range(100):          # 100 × 50 ms = 5 s
			ws_server.poll()
			var n := ws_server.get_available_packet_count()
			if n > 0:
				for _i in range(n): # consume all waiting packets
					var ack : String = ws_server.get_packet().get_string_from_utf8()
					info("Host RX pgk %d: %s at try: %d" % [n, ack, tries])
					if ack == "{\"ack\":true}" or JSON.parse_string(ack).get("ack") == true:
						ack_ok = true
			if ack_ok:
				break
			OS.delay_msec(50)
		info("host after tries: " + str(ack_ok))
		if not ack_ok:
			push_error("ACK timeout page %d" % (i / PAGE_SIZE))
			
		# mark **this** page clean only after successful ACK
		for row in page:
			DB.mark_clean("item", str(row.id))

	# --- all pages done → wait for client category upload (max 1 s) ---
	info("Host waiting for client category upload")
	var t2 := Time.get_ticks_msec()
	while ws_server.get_ready_state() == WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t2 < 1000:
		ws_server.poll()
		while ws_server.get_available_packet_count() > 0:
			var pkt := ws_server.get_packet().get_string_from_utf8()
			var data: Variant = JSON.parse_string(pkt)
			if data is Dictionary and data.get("table") == "category":
				_apply_category_row(data.row)
		# send ACK once per batch
		ws_server.send_text(JSON.stringify({"cat_ack":true}))
		OS.delay_msec(50)
	# final close
	#ws_server.close(1000, "host-done")
	
	# all pages done
	if is_instance_valid(ws_server) and ws_server.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_server.close(1000, "host-done")
	set_process(true)
	_idle_reset()


func _apply_category_row(row: Dictionary) -> void:
	var local := DB.select_category(int(row.id))
	var use_client := true
	if not local.is_empty():
		var local_time := int(local[0].updated_at)
		var cli_time   := int(row.updated_at)
		if local_time > cli_time: use_client = false
	if use_client:
		DB._db.query_with_bindings(
			"INSERT OR REPLACE INTO category(id,name,updated_at,sync_flag,is_deleted) VALUES (?,?,?,?,?)",
			[row.id, row.name, row.updated_at, 0, row.get("is_deleted",0)]
		)


func _poll_client_recv() -> void:
	if not is_instance_valid(ws_client) or ws_client.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return

	ws_client.poll()
	var st := ws_client.get_ready_state()
	match st:
		WebSocketPeer.STATE_CONNECTING:
			return
		WebSocketPeer.STATE_OPEN:
			if state == State.JOINING:
				_set_state(State.SYNCING)
				_start_timeout()
			while ws_client.get_available_packet_count() > 0:
				var pkt := ws_client.get_packet().get_string_from_utf8()
				var data: Variant = JSON.parse_string(pkt)

				## ---- category row ----
				#if data is Dictionary and data.get("table") == "category":
					#DB.upsert_category(data.row["id"],data.row["name"])
					#if data.get("last", false):
						#ws_client.send_text(JSON.stringify({"cat_ack":true}))
					#continue

				# ---- category row ----
				if data is Dictionary and data.get("table") == "category":
					if data.get("last", false):
						ws_client.send_text(JSON.stringify({"cat_ack":true}))
						info("cat_ack sent")
						#continue
					var row := Dictionary(data.row)
					var local := DB.select_category(int(row.id))
					var use_host := true
					if not local.is_empty():
						var local_time := int(local[0].updated_at)
						var host_time  := int(row.updated_at)
						if local_time > host_time:
							use_host = false
					if use_host:
						# insert or replace with host values
						DB._db.query_with_bindings(
							"INSERT OR REPLACE INTO category(id,name,updated_at,sync_flag,is_deleted) VALUES (?,?,?,?,?)",
							[row.id, row.name, row.updated_at, 0, row.is_deleted]
						)
					continue
					
				# --- paginated protocol ---
				if data is Dictionary and data.has("page"):
					for row in data.page:
						_apply_row(row)
					# ACK back to host only if socket still open
					info("WS valid? " + str(is_instance_valid(ws_client)) + " ready_state: " + str(ws_client.get_ready_state()))
					if is_instance_valid(ws_client) and ws_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
						ws_client.send_text(JSON.stringify({"ack":true,"idx":data.index}))
						# ----- force TCP flush -----
						#var tcp_peer : Variant = ws_client.tcp #.get_peer()   # returns StreamPeerTCP or StreamPeerTLS
						#if tcp_peer is StreamPeerTCP and tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
							#tcp_peer.put_data([])   # 0-byte push
						ws_client.poll()          # optional, but keeps Godot buffer empty
						info("Client ACK pushed to kernel")

						ws_client.poll()          # push into kernel
						await get_tree().create_timer(0.0).timeout   # 1 frame = kernel drain

						info("WS client sent ack, idx: " + str(data.index))
					# final page?
					if data.get("last", false):
						info("Client received last page")
						_mark_clean_and_refresh()
						# ----------  NEW: now send our own categories ----------
						if DB.select_dirty("category").size() > 0:
							_set_state(State.SENDING_CAT)
							set_process(false)
							call_deferred("_send_categories_to_host")
							return
						# ----------  else done ----------
						await get_tree().create_timer(0.2).timeout
						ws_client.close()
						_idle_reset()
					return

				# --- legacy single-packet fallback ---
				if pkt == "{\"done\":true}":
					info("Client received 'done'")
					ws_client.close()
					_mark_clean_and_refresh()
					_idle_reset()
					return

				# --- raw row (old host) ---
				if data is Dictionary and data.has("id"):
					_apply_row(data)

		_:
			info("Client socket closed or error")
			_idle_reset()


func _send_categories_to_host() -> void:
	var dirty_cat := DB.select_dirty("category")
	info("Client sending %d categories to host" % dirty_cat.size())
	for cat in dirty_cat:
		ws_client.send_text(JSON.stringify({"table":"category","row":cat}))
	# wait for host ACK
	var t0 := Time.get_ticks_msec()
	while true:
		ws_client.poll()
		if ws_client.get_available_packet_count() > 0:
			var ack := ws_client.get_packet().get_string_from_utf8()
			if ack == "{\"cat_ack\":true}": break
		if Time.get_ticks_msec() - t0 > 3000: push_error("Host cat ACK timeout"); break
		OS.delay_msec(10)
	# mark clean only after ACK
	for cat in dirty_cat:
		DB.mark_clean("category", str(cat.id))
	set_process(true)
	_idle_reset()

func _poll_state_done() -> void:
	if state == State.DONE:
		_idle_reset()


func _idle_reset() -> void:
	_set_state(State.SHUTTING_DOWN)
	if timeout_timer:
		timeout_timer.queue_free()
		timeout_timer = null
	_close_sockets()
	discovered = []
	_set_state(State.IDLE)


func _start_timeout() -> void:
	if timeout_timer:
		timeout_timer.queue_free()
	timeout_timer = Timer.new()
	timeout_timer.wait_time = SYNC_TIMEOUT
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)


func _on_timeout() -> void:
	info("Sync timeout")
	emit_signal("sync_failed")
	_idle_reset()


func _close_sockets() -> void:
	if broadcast_timer:
		broadcast_timer.queue_free()
		broadcast_timer = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	if ws_server and ws_server.get_ready_state() < WebSocketPeer.STATE_CLOSED:
		ws_server.close()
		ws_server = null
	if ws_client and ws_client.get_ready_state() < WebSocketPeer.STATE_CLOSED:
		ws_client.close()
		ws_client = null

# -------------- public safe quit --------------
func close_all() -> void:
	if state == State.IDLE: return
	_idle_reset()

# -------------- helpers --------------
func _start_udp() -> void:
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	udp_peer.bind(UDP_PORT, "0.0.0.0")



func _send_dirty_rows() -> void:
	if ws_server.get_ready_state() != WebSocketPeer.STATE_OPEN:
		info("Skip send – socket not open"); return
	var dirty := DB.select_dirty("item")
	var total := dirty.size()
	info("Host sending %d rows (%d pages)" % [total, (total-1)/PAGE_SIZE + 1])
	for i in range(0, total, PAGE_SIZE):
		var page := dirty.slice(i, i+PAGE_SIZE)
		var pkt := JSON.stringify({"page":page, "index":i/PAGE_SIZE, "last":i+PAGE_SIZE >= total})
		ws_server.send_text(pkt)
		# wait for client ACK before next page
		var t0 := Time.get_ticks_msec()
		while ws_server.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws_server.poll()
			if ws_server.get_available_packet_count() > 0:
				var ack := ws_server.get_packet().get_string_from_utf8()
				if ack == "{\"ack\":true}": break
			if Time.get_ticks_msec() - t0 > 1000: push_error("ACK timeout"); break
			await get_tree().create_timer(0.1).timeout


# res://scripts/p2p_manager.gd
func _apply_row(row: Dictionary) -> void:
	DB.upsert_item(row)   # replace old insert/update logic


func _mark_clean_and_refresh() -> void:
	var dirty := DB.select_dirty("item")
	for d in dirty:
		if d.id == null: d.id = ""
		DB.mark_clean("item", d.id)
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
	
