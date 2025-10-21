extends Node

const SETTINGS_FILE_PATH = "user://settings.cfg"
const KEYBINDINGS_FILE_PATH = "user://keybindings.cfg"

const REMAPPABLE_ACTIONS = ["move_up", "move_down", "move_left", "move_right"]

var settings: Dictionary = {}

const DEFAULTS = {
	"general": {
		"language_index": 0,
		"locale": "pt",
		"ui_scale": 100.0
	},
	"audio": {
		"master_volume": 80.0,
		"music_volume": 100.0,
		"sfx_volume": 100.0
	},
	"graphics": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"resolution": "1920x1080",
		"vsync": true,
		"fps_limit": 0
	}
}

func _ready() -> void:
	load_settings()
	get_tree().root.ready.connect(apply_settings, CONNECT_ONE_SHOT)

func load_settings() -> void:
	_load_keybindings()
	
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)

	if err != OK:
		settings = DEFAULTS.duplicate(true)
		save_settings()
	else:
		settings = DEFAULTS.duplicate(true)
		for section in config.get_sections():
			if not settings.has(section): settings[section] = {}
			for key in config.get_section_keys(section):
				settings[section][key] = config.get_value(section, key)

func save_settings() -> void:
	_save_keybindings()

	var config = ConfigFile.new()
	var lang_index = settings.general.language_index
	settings.general.locale = "pt" if lang_index == 0 else "en"

	for section in settings:
		for key in settings[section]:
			config.set_value(section, key, settings[section][key])

	config.save(SETTINGS_FILE_PATH)

func _save_keybindings() -> void:
	var key_config = ConfigFile.new()
	for action in REMAPPABLE_ACTIONS:
		var events = InputMap.action_get_events(action)
		key_config.set_value(action, "events", events)
	
	key_config.save(KEYBINDINGS_FILE_PATH)

func _load_keybindings() -> void:
	var key_config = ConfigFile.new()
	var err = key_config.load(KEYBINDINGS_FILE_PATH)
	if err != OK:
		return

	for action in REMAPPABLE_ACTIONS:
		if not key_config.has_section(action):
			continue
		
		InputMap.action_erase_events(action)
		
		var events = key_config.get_value(action, "events", [])
		for event in events:
			InputMap.action_add_event(action, event)

func apply_settings() -> void:
	if not settings: return
	apply_audio_settings()
	apply_graphics_settings()
	apply_language_settings()
	apply_ui_scale()

func apply_audio_settings() -> void:
	_set_bus_volume("Master", settings.audio.master_volume)
	_set_bus_volume("Music", settings.audio.music_volume)
	_set_bus_volume("SFX", settings.audio.sfx_volume)

func apply_graphics_settings() -> void:
	DisplayServer.window_set_mode(settings.graphics.window_mode)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.graphics.vsync else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = settings.graphics.fps_limit

	if settings.graphics.window_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		var res_parts = settings.graphics.resolution.split("x")
		if res_parts.size() == 2:
			var width = int(res_parts[0])
			var height = int(res_parts[1])
			DisplayServer.window_set_size(Vector2i(width, height))
			DisplayServer.window_set_position(
				DisplayServer.screen_get_size() / 2 - DisplayServer.window_get_size() / 2
			)

func apply_language_settings() -> void:
	TranslationServer.set_locale(settings.general.locale)

func apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = settings.general.ui_scale / 100.0

func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if linear_value <= 0:
			AudioServer.set_bus_volume_db(bus_idx, -80)
		else:
			var db_value = linear_to_db(linear_value / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, db_value)
