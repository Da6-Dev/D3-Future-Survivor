extends Node2D

const CHUNK_SIZE = Vector2i(32, 32)
const LOAD_MARGIN = 1

@export_group("Decoração Procedural")
@export var house_scenes: Array[PackedScene] = []
@export var game_seed: int = 12345
@export var structure_frequency: float = 0.05
@export var structure_spawn_threshold: float = 0.98

@onready var tilemap: TileMapLayer = $TileMapLayer
var camera: Camera2D

var required_chunks: Dictionary = {}
var loaded_chunks: Dictionary = {}

var noise_terrain = FastNoiseLite.new()
var noise_structures = FastNoiseLite.new()

var spawned_houses: Dictionary = {}

func _ready() -> void:
	noise_terrain.seed = game_seed
	noise_terrain.noise_type = FastNoiseLite.TYPE_VALUE
	noise_terrain.frequency = 0.1
	
	noise_structures.seed = game_seed + 1
	noise_structures.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_structures.frequency = structure_frequency
	
	await get_tree().process_frame
	camera = get_viewport().get_camera_2d()
	if not is_instance_valid(camera):
		return

func _process(_delta: float) -> void:
	if not is_instance_valid(camera):
		return
	_update_map_based_on_camera()

func _update_map_based_on_camera() -> void:
	var view_rect = get_viewport().get_visible_rect()
	var top_left_world = camera.get_screen_center_position() - view_rect.size / 2 * camera.zoom
	var bottom_right_world = camera.get_screen_center_position() + view_rect.size / 2 * camera.zoom
	var top_left_map = tilemap.local_to_map(top_left_world)
	var bottom_right_map = tilemap.local_to_map(bottom_right_world)
	var top_left_chunk = top_left_map / CHUNK_SIZE
	var bottom_right_chunk = bottom_right_map / CHUNK_SIZE
	
	var new_required_chunks: Dictionary = {}
	for x in range(top_left_chunk.x - LOAD_MARGIN, bottom_right_chunk.x + LOAD_MARGIN + 1):
		for y in range(top_left_chunk.y - LOAD_MARGIN, bottom_right_chunk.y + LOAD_MARGIN + 1):
			new_required_chunks[Vector2i(x, y)] = true
	
	if new_required_chunks.hash() == required_chunks.hash():
		return
		
	required_chunks = new_required_chunks
	var chunks_to_unload = []
	for chunk_coords in loaded_chunks.keys():
		if not required_chunks.has(chunk_coords):
			chunks_to_unload.append(chunk_coords)
	
	for chunk_coords in chunks_to_unload:
		_unload_chunk(chunk_coords)
	
	for chunk_coords in required_chunks.keys():
		if not loaded_chunks.has(chunk_coords):
			_load_chunk(chunk_coords)

func _load_chunk(chunk_coords: Vector2i):
	loaded_chunks[chunk_coords] = true
	var start_pos = chunk_coords * CHUNK_SIZE
	
	for x in range(CHUNK_SIZE.x):
		for y in range(CHUNK_SIZE.y):
			var tile_pos = start_pos + Vector2i(x, y)
			
			tilemap.set_cell(tile_pos, 2, Vector2i(5,2))
			
			var structure_value = noise_structures.get_noise_2d(tile_pos.x, tile_pos.y)
			var spawn_chance = remap(structure_value, -1.0, 1.0, 0.0, 1.0)
			
			if spawn_chance > structure_spawn_threshold:
				_spawn_house(tile_pos, chunk_coords)

func _spawn_house(tile_pos: Vector2i, chunk_coords: Vector2i):
	if house_scenes.is_empty():
		return
		
	var house_scene = house_scenes.pick_random()
	var house_instance = house_scene.instantiate()
	
	house_instance.global_position = tilemap.map_to_local(tile_pos)
	
	get_parent().add_child(house_instance)
	
	if not spawned_houses.has(chunk_coords):
		spawned_houses[chunk_coords] = []
		
	spawned_houses[chunk_coords].append(house_instance)

func _unload_chunk(chunk_coords: Vector2i):
	if spawned_houses.has(chunk_coords):
		for house_instance in spawned_houses[chunk_coords]:
			if is_instance_valid(house_instance):
				house_instance.queue_free()
		spawned_houses.erase(chunk_coords)

	if loaded_chunks.has(chunk_coords):
		loaded_chunks.erase(chunk_coords)
		var start_pos = chunk_coords * CHUNK_SIZE
		
		for x in range(CHUNK_SIZE.x):
			for y in range(CHUNK_SIZE.y):
				var tile_pos = start_pos + Vector2i(x, y)
				tilemap.erase_cell(tile_pos)
