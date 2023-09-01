extends Node

var chunk_prefab: PackedScene = preload("res://prefabs/chunk.tscn")
var generation_queue: Array[Vector3i] = []
var server_ready: bool = false

@onready var chunk_holder: Node3D = get_tree().current_scene.get_node("Chunks")
@onready var thread: Thread = Thread.new()
@onready var world_seed: int = randi()

func _exit_tree() -> void:
	if thread.is_started():
		thread.wait_to_finish()

func is_spawn_chunk_generated():
	var result: bool = true
	for y in range(4):
		if not chunk_holder.has_node(str(Vector3i(0, y, 0))):
			result = false
			generate_chunk(Vector3i(0, y, 0))
	return result

func _process(_delta: float) -> void:
	if not server_ready:
		return
	if thread.is_started() and not thread.is_alive():
		thread.wait_to_finish()
	if not thread.is_started():
		if generation_queue.size() > 0:
#			print("Chunks to load:" + str(generation_queue.size()))
			var next_chunk: Vector3i = generation_queue.pop_back()
			if not chunk_holder.has_node(str(next_chunk)):
				var new_chunk: Node3D = chunk_prefab.instantiate()
				new_chunk.name = str(next_chunk)
				new_chunk.chunk_position = next_chunk
				chunk_holder.call_deferred("add_child", new_chunk)
				thread.start(new_chunk.generate_world.bind(next_chunk, world_seed))

func load_world_around_player(player_position: Vector3):
	var player_position_integer: Vector3i = player_position
	player_position_integer /= 16
	player_position_integer.x = player_position_integer.x if player_position.x > 0 else player_position_integer.x - 1
	player_position_integer.y = player_position_integer.y if player_position.y > 0 else player_position_integer.y - 1
	player_position_integer.z = player_position_integer.z if player_position.z > 0 else player_position_integer.z - 1
#	print(player_position_integer)
#	for chunk in generation_queue:
#		if (chunk - player_position_integer).length() > 4:
##			print("Cleaned up: " + str(chunk))
#			generation_queue.erase(chunk)
	var chunks_around: Array[Vector3i] = [
		#Vector3i(1, 0, 0),
		#Vector3i(0, 1, 0),
		#Vector3i(0, 0, 1),
		#Vector3i(-1, 0, 0),
		#Vector3i(0,-1, 0),
		#Vector3i(0, 0,-1),
		#Vector3i(0, 0, 0)
	]
	
	for x in range(-2, 3):
		for z in range(-2, 3):
			for y in range(-2, 3):
				chunks_around.append(Vector3i(x, y, z))
	chunks_around.append(Vector3i(0, 0, 0))
	
	for chunk in chunks_around:
		generate_chunk(player_position_integer + chunk)

func generate_chunk(chunk_pos :Vector3i):
	if not chunk_holder.has_node(str(chunk_pos)) and not chunk_pos in generation_queue:
		generation_queue.push_back(chunk_pos)
