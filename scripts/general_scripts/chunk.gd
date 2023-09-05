extends StaticBody3D

@export var noise: FastNoiseLite = FastNoiseLite.new()

const THRESHOLD: float = 0.1
const CHUNK_SIZE: int = 16

var chunk_position: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	position = chunk_position * CHUNK_SIZE
	$MeshInstance3D.material_override.albedo_texture = ChunkGenTools.atlas

func ground_level_at(x, z) -> float:
	return abs(noise.get_noise_2d(x, z)) * 20

func get_value_at(x, y, z) -> float:
#	var d: int = 2
#
#	if x < d and x > -d and y < 44 + d * 2 and y > 44 and z < d and z > -d:
#		return 1.0
#	if Vector3i(x, y, z) == Vector3i(8, 44, 8):
#		return 1.0
	
#	if sqrt((x*x) + ((y-16)*(y-16)) + (z*z)) < 16:
#		return(1)

#	var result: float = -y + x*y*z #ground_level_at(x, z) - y
	var result: float = noise.get_noise_3d(x * 10, y * 10, z * 10) * 10
	var ground_level: float = ground_level_at(x, z) + 35
	
	if y > ground_level:
		result = 0.0
	if result > 0.5:
		return 1.0
	if result > 0.0:
		return 1.0
	return 0.0

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
		Vector2(0, 0), # 0
		Vector2(1, 0), # 1
		Vector2(0, 1), # 2
		
		Vector2(0, 1), # 3
		Vector2(1, 0), # 4
		Vector2(1, 1), # 5
	]
	
	var data: Array = []
	
	for x_loop in range(0, CHUNK_SIZE + 1, 1):
		var x: float = chunk_position.x * CHUNK_SIZE + x_loop
		var layer_y: Array = []
		for y_loop in range(0, CHUNK_SIZE + 1, 1):
			var y: float = chunk_position.y * CHUNK_SIZE + y_loop
			var layer_z: Array[float] = []
			for z_loop in range(0, CHUNK_SIZE + 1, 1):
				var z: float = chunk_position.z * CHUNK_SIZE + z_loop
				layer_z.append(get_value_at(x, y, z))
			layer_y.append(layer_z)
		data.append(layer_y)
	
	var mat_rng = RandomNumberGenerator.new()
	mat_rng.seed = s + chunk_pos.x + chunk_pos.y * 100 + chunk_pos.z * 10000
	
	for x_loop in range(0, CHUNK_SIZE, 1):
		for y_loop in range(0, CHUNK_SIZE, 1):
			var prev_layer: Array[float] = [data[x_loop][y_loop][0], data[x_loop + 1][y_loop][0], data[x_loop][y_loop + 1][0], data[x_loop + 1][y_loop + 1][0]]
			for z_loop in range(0, CHUNK_SIZE, 1):
				var corners: Array[float] = [prev_layer[0], prev_layer[1], prev_layer[2], prev_layer[3], 
										data[x_loop][y_loop][z_loop + 1], data[x_loop + 1][y_loop][z_loop + 1], data[x_loop][y_loop + 1][z_loop + 1], data[x_loop + 1][y_loop + 1][z_loop + 1]]
				prev_layer[0] = corners[4]
				prev_layer[1] = corners[5]
				prev_layer[2] = corners[6]
				prev_layer[3] = corners[7]
				
				var id: int = 0
				for i in range(corners.size()):
					id = id | (int(not abs(corners[i]) > THRESHOLD) << i)
				var edge_vertices: Array[float]
				if ChunkGenTools.index_map[id].size() != 0:
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
				
#				var material_id: int = mat_rng.randi_range(0, ChunkGenTools.texture_count - 1)
				const layer_data: Array[int] = [
					6, 6,
					5, 5, 5, 5,
					7, 7,
					15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
					15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
					15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
					11, 11, 11, 11, 11, 11, 11, 11,
					11, 11, 11, 11, 11, 11, 11, 11,
					11, 11, 11, 11, 11, 11, 11, 11,
					11, 11, 11, 11, 11, 11, 11, 11,
					11, 11, 11, 11, 11, 11, 11, 11,
					19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 
					19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 
					19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 
					19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 
					20,
				]
				var layer: int = (ground_level_at(x_loop, z_loop) + 35) - (chunk_position.y * CHUNK_SIZE + y_loop)
				layer = max(min(layer, layer_data.size() - 1), 0)
				var material_id: int = layer_data[layer]
				var uv_index = 0
				for index in ChunkGenTools.index_map[id]:
					vertices.push_back(Vector3(x_loop, y_loop, z_loop) + base_verts[index] - offset_mul[index] * 0.5 + offset_mul[index] * edge_vertices[index])
					
					var offset: Vector2 = Vector2(material_id, 0) / Vector2(ChunkGenTools.texture_count, 1)
					uvs.push_back(base_uvs[uv_index + 0] / Vector2(ChunkGenTools.texture_count, 1) + offset)
					uv_index += 1
					uv_index %= 6
	
	var mesh: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	mesh.set_faces(vertices)
	call_thread_safe("set_collision_shape", mesh)
	
	if vertices.size() < 3:
		return
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	call_thread_safe("set_render_mesh", arr_mesh)

func set_collision_shape(mesh: ConcavePolygonShape3D):
	$CollisionShape3D.shape = mesh

func set_render_mesh(arr_mesh: ArrayMesh):
	$MeshInstance3D.mesh = arr_mesh
