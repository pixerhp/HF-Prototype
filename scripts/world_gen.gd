extends StaticBody3D

@export var noise: FastNoiseLite = FastNoiseLite.new()

func get_height(x, z) -> float:
	return noise.get_noise_2d(x, z) * 50

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	noise.seed = RandomNumberGenerator.new().randi()
	var height_map: HeightMapShape3D = HeightMapShape3D.new()
	height_map.map_width = 300
	height_map.map_depth = 300
	
	var vertices = PackedVector3Array()
	
	var pool_array: PackedFloat32Array
	for x in range(0, height_map.map_width, 1):
		for z in range(0, height_map.map_depth, 1):
			var y0: float = get_height(x, z)
			var y1: float = get_height(x + 1, z)
			var y2: float = get_height(x, z + 1)
			var y3: float = get_height(x + 1, z + 1)
			pool_array.append(y0)
			
			if height_map.map_width - 1 != x && height_map.map_depth - 1 != z:
				vertices.push_back(Vector3(-1,1,1)*Vector3(x - height_map.map_width * 0.5 + 0.5, y0, z + 0.5 - height_map.map_depth * 0.5))
				vertices.push_back(Vector3(-1,1,1)*Vector3(x - height_map.map_width * 0.5 + 0.5, y2, z + 0.5 + 1 - height_map.map_depth * 0.5))
				vertices.push_back(Vector3(-1,1,1)*Vector3(x + 1 - height_map.map_width * 0.5 + 0.5, y1, z + 0.5 - height_map.map_depth * 0.5))

				vertices.push_back(Vector3(-1,1,1)*Vector3(x + 1 - height_map.map_width * 0.5 + 0.5, y1, z + 0.5 - height_map.map_depth * 0.5))
				vertices.push_back(Vector3(-1,1,1)*Vector3(x - height_map.map_width * 0.5 + 0.5, y2, z + 1 + 0.5 - height_map.map_depth * 0.5))
				vertices.push_back(Vector3(-1,1,1)*Vector3(x + 1 - height_map.map_width * 0.5 + 0.5, y3, z + 1 + 0.5 - height_map.map_depth * 0.5))
			
	height_map.map_data = pool_array
	$CollisionShape3D.shape = height_map

	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$MeshInstance3D.mesh = arr_mesh
