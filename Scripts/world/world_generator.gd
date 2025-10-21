# Scripts/world/world_generator.gd
extends Node2D

const CHUNK_SIZE = Vector2i(32, 32)
const LOAD_MARGIN = 1

@export_group("Decoração Procedural")
@export var house_scenes: Array[PackedScene] = []
# REMOVEMOS house_density, não é mais necessário
@export var game_seed: int = 12345

# --- NOVO CONTROLE DE SPAWN ---
# Frequência do ruído para as casas. Valores maiores = mais "juntas".
@export var structure_frequency: float = 0.05
# Limite para spawnar. 
# 0.8 = 20% de chance (só valores de ruído entre 0.8 e 1.0)
# 0.9 = 10% de chance (mais raro)
# 0.98 = 2% de chance (muito raro)
@export var structure_spawn_threshold: float = 0.98

@onready var tilemap: TileMapLayer = $TileMapLayer
var camera: Camera2D

var required_chunks: Dictionary = {}
var loaded_chunks: Dictionary = {}

# --- DOIS GERADORES DE RUÍDO ---
var noise_terrain = FastNoiseLite.new()
var noise_structures = FastNoiseLite.new() # Um separado para casas

# Dicionário agora guarda um ARRAY de casas por chunk
var spawned_houses: Dictionary = {}


func _ready() -> void:
	# Configura o ruído do TERRENO
	noise_terrain.seed = game_seed
	noise_terrain.noise_type = FastNoiseLite.TYPE_VALUE
	noise_terrain.frequency = 0.1
	
	# Configura o ruído das ESTRUTURAS (casas)
	noise_structures.seed = game_seed + 1 # Seed diferente é importante!
	noise_structures.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH # Suave
	noise_structures.frequency = structure_frequency
	
	await get_tree().process_frame
	camera = get_viewport().get_camera_2d()
	if not is_instance_valid(camera):
		push_error("WorldGenerator: Nenhuma Camera2D ativa encontrada no viewport!")
		return

# ... (as funções _process e _update_map_based_on_camera continuam EXATAMENTE IGUAIS) ...

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


# --- LÓGICA DE LOAD MODIFICADA ---
func _load_chunk(chunk_coords: Vector2i):
	loaded_chunks[chunk_coords] = true
	var start_pos = chunk_coords * CHUNK_SIZE
	
	# Agora checamos CADA TILE
	for x in range(CHUNK_SIZE.x):
		for y in range(CHUNK_SIZE.y):
			var tile_pos = start_pos + Vector2i(x, y)
			
			# 1. Gera o terreno (como antes)
			# (Você pode usar noise_terrain aqui se quiser um terreno variado)
			tilemap.set_cell(tile_pos, 2, Vector2i(5,2)) # Layer 2, Atlas (5, 2)
			
			# 2. Verifica se devemos spawnar uma casa NESTE TILE
			# Não checamos se o array de cenas está vazio aqui,
			# pois a função _spawn_house fará isso.
			
			# Pega o valor do ruído (entre -1.0 e 1.0)
			var structure_value = noise_structures.get_noise_2d(tile_pos.x, tile_pos.y)
			# Mapeia para 0.0 - 1.0
			var spawn_chance = remap(structure_value, -1.0, 1.0, 0.0, 1.0)
			
			# Se o valor for maior que o nosso limite (threshold)...
			if spawn_chance > structure_spawn_threshold:
				# ...spawnamos uma casa AQUI.
				_spawn_house(tile_pos, chunk_coords)

# --- NOVA FUNÇÃO DE SPAWN DE CASA ---
func _spawn_house(tile_pos: Vector2i, chunk_coords: Vector2i):
	if house_scenes.is_empty():
		return # Não faz nada se nenhuma cena de casa foi definida
		
	# Escolhe uma casa aleatória do array
	var house_scene = house_scenes.pick_random()
	var house_instance = house_scene.instantiate()
	
	# Converte a posição do TILE para a posição de MUNDO
	# Isso garante que a casa fique perfeitamente alinhada à grade
	house_instance.global_position = tilemap.map_to_local(tile_pos)
	
	# Adiciona a casa à cena
	get_parent().add_child(house_instance)
	
	# Armazena a referência da casa para podermos deletá-la depois
	# Garante que o array exista antes de adicionar
	if not spawned_houses.has(chunk_coords):
		spawned_houses[chunk_coords] = []
		
	spawned_houses[chunk_coords].append(house_instance)


# --- LÓGICA DE UNLOAD MODIFICADA ---
func _unload_chunk(chunk_coords: Vector2i):
	# 1. Deleta TODAS as casas deste chunk
	if spawned_houses.has(chunk_coords):
		# Loop por todas as casas que foram spawnadas neste chunk
		for house_instance in spawned_houses[chunk_coords]:
			if is_instance_valid(house_instance):
				house_instance.queue_free()
		# Limpa o array de casas do chunk
		spawned_houses.erase(chunk_coords)

	# 2. Deleta o terreno (como antes)
	if loaded_chunks.has(chunk_coords):
		loaded_chunks.erase(chunk_coords)
		var start_pos = chunk_coords * CHUNK_SIZE
		
		for x in range(CHUNK_SIZE.x):
			for y in range(CHUNK_SIZE.y):
				var tile_pos = start_pos + Vector2i(x, y)
				tilemap.erase_cell(tile_pos)
