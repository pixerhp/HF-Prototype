extends Node

var player_prefab: PackedScene = preload("res://prefabs/player.tscn")
@onready var networked_objects_holder: Node = get_tree().current_scene.get_node("MultiplayerSpawner")
@onready var network_menu: Node = get_tree().current_scene.get_node("MenuCanvas/NetworkMenu")
@onready var version_label: Label = get_tree().current_scene.get_node("MenuCanvas/VersionLabel")

var ip: String = "192.168.1.206"
var shovel_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var version_file := FileAccess.open("res://version.txt", FileAccess.READ)
	if version_file:
		version_label.text = "Version " + version_file.get_as_text()
	network_menu.get_node("VBoxContainer/HostButton").connect("pressed", start_host)
	network_menu.get_node("VBoxContainer/ServerButton").connect("pressed", start_server)
	network_menu.get_node("VBoxContainer/ClientButton").connect("pressed", start_client)
	if "--server" in OS.get_cmdline_args():
		start_server()
	
func start_host():
	start_server()
	player_connect(multiplayer.get_unique_id())

func start_server():
	network_menu.visible = false
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	multiplayer.peer_connected.connect(self.player_connect)
	multiplayer.peer_disconnected.connect(self.player_leave)
	peer.create_server(1380)
	multiplayer.set_multiplayer_peer(peer)
	print("Server started")

func start_client() -> void:
	ip = network_menu.get_node("VBoxContainer/IP").text
	network_menu.visible = false
	print("Client start")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(self.server_connect)
	peer.create_client(ip, 1380)
	multiplayer.set_multiplayer_peer(peer)

func server_connect():
	print("Connected")

@rpc("call_local")
func set_seed(new_seed: int):
	WorldManager.world_seed = new_seed
	WorldManager.server_ready = true

func player_connect(id: int) -> void:
	rpc_id(id, "set_seed", WorldManager.world_seed)
	print("Player (" + str(id) + ") joined")
	var new_player: Node3D = player_prefab.instantiate()
	new_player.name = str(id)
	networked_objects_holder.add_child(new_player)
	new_player.global_position = new_player.spawn_point

func player_leave(id: int) -> void:
	if networked_objects_holder.get_node_or_null(str(id)) != null:
		networked_objects_holder.get_node(str(id)).queue_free()
	print("Player (" + str(id) + ") left")

func req_spawn_shovel(pos: Vector3):
	rpc_id(1, "spawn_shovel", pos)

@rpc("any_peer", "call_local")
func spawn_shovel(pos: Vector3):
	var new_shovel: Node3D = load("res://prefabs/shovel.tscn").instantiate()
	new_shovel.name += str(shovel_id)
	shovel_id += 1
	networked_objects_holder.add_child(new_shovel)
	new_shovel.global_position = pos
