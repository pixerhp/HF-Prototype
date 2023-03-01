extends StaticBody3D

@export var noise: FastNoiseLite = FastNoiseLite.new()

const THRESHOLD: float = 0.1
const CHUNK_SIZE: int = 16

var chunk_position: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	position = chunk_position * CHUNK_SIZE

func ground_level_at(x, z) -> float:
	return abs(noise.get_noise_2d(x, z)) * 20 + 35

func get_value_at(x, y, z) -> float:
	var result: float = ground_level_at(x, z) - y
	if result > 1.0:
		result = noise.get_noise_3d(x * 0.1, y * 0.1, z * 0.1) * 10
	return clampf(result, 0.0, 1.0)
	#return clampf(noise.get_noise_3d(x, y, z) if y < ground_level_at(x, z) else (abs(ground_level_at(x, z) - y) if ground_level_at(x, z) - y > -1 else 0.0), 0.0, 1.0)

func eval_voxels(a: float, b: float) -> float:
	if abs(a) > THRESHOLD and abs(b) > THRESHOLD or (abs(a) < THRESHOLD and abs(b) < THRESHOLD):
		return 0.0
	return min(a - b if a - b > 0 else 1 + (a - b), 1.0)

func generate_world(chunk_pos: Vector3i = Vector3i.ZERO, s: int = 5) -> void:
	chunk_position = chunk_pos
	noise.seed = s#RandomNumberGenerator.new().randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
#	var normals: PackedVector3Array = PackedVector3Array()
	var offset_mul: Array[Vector3] = [
		Vector3.RIGHT, # 0
		Vector3.UP, # 1
		Vector3.RIGHT, # 2
		Vector3.UP, # 3
		Vector3.RIGHT, # 4
		Vector3.UP, # 5
		Vector3.RIGHT, # 6
		Vector3.UP, # 7
		Vector3.BACK, # 8
		Vector3.BACK, # 9
		Vector3.BACK, # 10
		Vector3.BACK, # 11
	]
	
	var base_verts: Array[Vector3] = [
		Vector3( 0.0, -0.5, -0.5), # 0
		Vector3( 0.5,  0.0, -0.5), # 1
		Vector3( 0.0,  0.5, -0.5), # 2
		Vector3(-0.5,  0.0, -0.5), # 3
		Vector3( 0.0, -0.5,  0.5), # 4
		Vector3( 0.5,  0.0,  0.5), # 5
		Vector3( 0.0,  0.5,  0.5), # 6
		Vector3(-0.5,  0.0,  0.5), # 7
		Vector3(-0.5, -0.5,  0.0), # 8
		Vector3( 0.5, -0.5,  0.0), # 9
		Vector3( 0.5,  0.5,  0.0), # 10
		Vector3(-0.5,  0.5,  0.0), # 11
	]
	
	var base_uvs: Array[Vector2] = [
		Vector2(0.5, 1.0), # 0
		Vector2(1.0, 0.5), # 1
		Vector2(0.5, 0.0), # 2
		Vector2(0.0, 0.5), # 3
		Vector2(0.5, 1.0), # 4
		Vector2(1.0, 0.5), # 5
		Vector2(0.5, 0.0), # 6
		Vector2(0.0, 0.5), # 7
		Vector2(0.0, 1.0), # 8
		Vector2(1.0, 1.0), # 9
		Vector2(1.0, 0.0), # 10
		Vector2(0.0, 0.0), # 11
	]
	
	for x_loop in range(0, CHUNK_SIZE, 1):
		var x: float = chunk_position.x * CHUNK_SIZE + x_loop
		for y_loop in range(0, CHUNK_SIZE, 1):
			var y: float = chunk_position.y * CHUNK_SIZE + y_loop
			var tmp_z: float = chunk_position.z * CHUNK_SIZE
			var prev_layer: Array[float] = [get_value_at(x, y, tmp_z), get_value_at(x + 1, y, tmp_z), get_value_at(x, y + 1, tmp_z), get_value_at(x + 1, y + 1, tmp_z)]
			for z_loop in range(0, CHUNK_SIZE, 1):
				var z: float = chunk_position.z * CHUNK_SIZE + z_loop
				var corners: Array[float] = [prev_layer[0], prev_layer[1], prev_layer[2], prev_layer[3], 
										get_value_at(x, y, z + 1), get_value_at(x + 1, y, z + 1), get_value_at(x, y + 1, z + 1), get_value_at(x + 1, y + 1, z + 1)]
				prev_layer[0] = corners[4]
				prev_layer[1] = corners[5]
				prev_layer[2] = corners[6]
				prev_layer[3] = corners[7]
				
				var id: int = 0
				for i in range(corners.size()):
					id = id | (int(not abs(corners[i]) > THRESHOLD) << i)
				var edge_vertices: Array[float]
				if IndexMap.index_map[id].size() != 0:
					edge_vertices = [
						eval_voxels(corners[0], corners[1]), # 0
						eval_voxels(corners[1], corners[3]), # 1
						eval_voxels(corners[2], corners[3]), # 2
						eval_voxels(corners[0], corners[2]), # 3
						eval_voxels(corners[4], corners[5]), # 4
						eval_voxels(corners[5], corners[7]), # 5
						eval_voxels(corners[6], corners[7]), # 6
						eval_voxels(corners[4], corners[6]), # 7
						eval_voxels(corners[0], corners[4]), # 8
						eval_voxels(corners[1], corners[5]), # 9
						eval_voxels(corners[3], corners[7]), # 10
						eval_voxels(corners[2], corners[6]), # 11
					]
				for index in IndexMap.index_map[id]:
					vertices.push_back(Vector3(x_loop, y_loop, z_loop) + base_verts[index] - offset_mul[index] * 0.5 + offset_mul[index] * edge_vertices[index])
					uvs.push_back(base_uvs[index])
#					normals.push_back(Vector3.UP)
	
	var mesh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	mesh.set_faces(vertices)
	$CollisionShape3D.shape = mesh
	
	if vertices.size() < 3:
		return
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
#	arrays[Mesh.ARRAY_NORMAL] = normals

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$MeshInstance3D.mesh = arr_mesh
