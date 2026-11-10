extends Node
## The online connection, loaded once for the whole game as "Net". One player hosts and
## the other joins with the host's address (on Tailscale, the host's 100.x.y.z address or
## machine name). The host's copy keeps the official results; both copies play each fight
## themselves from the same armies and seed.
##
## Messages are small dictionaries sent with send(kind, data) and heard through the
## `message` signal. The match screen does the rest.

signal hosted                          # listening; waiting for someone to join
signal match_ready(match_seed: int)    # both connected and agreed: start the match
signal connection_failed(reason: String)
signal opponent_left
signal message(kind: String, data: Dictionary)

const PORT := 7777
## Bump whenever a change would make two copies play differently. Copies with different
## versions refuse to play each other.
const PROTOCOL_VERSION := "proto-3"

enum Mode { OFFLINE, HOST, CLIENT }

var mode: Mode = Mode.OFFLINE
var match_seed := 0
## Factions: yours (set by the menu before hosting or joining) and the other player's,
## which arrives with the connection handshake.
var local_faction := "Sword Court"
var opponent_faction := "Sword Court"
var _peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode == Mode.HOST


func host() -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(PORT, 1)   # one other player
	if error != OK:
		_peer = null
		return error
	multiplayer.multiplayer_peer = _peer
	mode = Mode.HOST
	hosted.emit()
	return OK


func join(address: String) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		_peer = null
		return error
	multiplayer.multiplayer_peer = _peer
	mode = Mode.CLIENT
	return OK


## Closes the connection and goes back to offline play.
func leave() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE


## Sends a message to the other player.
func send(kind: String, data: Dictionary = {}) -> void:
	if is_online() and _peer != null:
		_receive.rpc(kind, data)


## This computer's network addresses, Tailscale's (100.x.y.z) first, to show a host.
func local_addresses() -> PackedStringArray:
	var tailscale := PackedStringArray()
	var others := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("100."):
			tailscale.append(address)
		else:
			others.append(address)
	return tailscale + others


@rpc("any_peer", "call_remote", "reliable")
func _receive(kind: String, data: Dictionary) -> void:
	match kind:
		"hello":   # joiner -> host
			if is_host():
				if data.get("version", "") != PROTOCOL_VERSION:
					send("reject", {"reason": "The host is running a different version of the game."})
					_drop_later()
					return
				match_seed = randi() & 0x7fffffff
				opponent_faction = data.get("faction", opponent_faction)
				send("start", {"seed": match_seed, "faction": local_faction})
				match_ready.emit(match_seed)
		"start":   # host -> joiner
			match_seed = int(data["seed"])
			opponent_faction = data.get("faction", opponent_faction)
			match_ready.emit(match_seed)
		"reject":
			var reason: String = data.get("reason", "The host refused the connection.")
			leave()
			connection_failed.emit(reason)
		_:
			message.emit(kind, data)


func _drop_later() -> void:
	await get_tree().create_timer(0.5).timeout
	leave()


func _on_connected_to_server() -> void:
	send("hello", {"version": PROTOCOL_VERSION, "faction": local_faction})


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Couldn't reach the host. Check the address, that they're hosting, and that Tailscale is on for both of you.")


func _on_peer_connected(_id: int) -> void:
	pass   # the host waits for "hello" before starting


func _on_peer_disconnected(_id: int) -> void:
	if is_host():
		opponent_left.emit()


func _on_server_disconnected() -> void:
	leave()
	opponent_left.emit()
