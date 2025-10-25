extends CanvasLayer

signal back_pressed

@onready var fps_limit_spinbox: SpinBox = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Gráficos/FpsLimitOption/FpsLimitSpinBox"
@onready var keybindings_grid: GridContainer = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Controles/ControlesMargin/VBoxContainer/KeybindingsGrid"
@onready var language_button: OptionButton = $SettingsPanel/MainMargin/VBoxContainer/MainContent/Geral/LanguageOption/LanguageButton
@onready var ui_scale_slider: HSlider = $SettingsPanel/MainMargin/VBoxContainer/MainContent/Geral/UIScaleOption/UIScaleSlider
@onready var window_mode_button: OptionButton = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Gráficos/WindowModeOption/WindowModeButton"
@onready var resolution_button: OptionButton = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Gráficos/ResolutionOption/ResolutionButton"
@onready var vsync_check: CheckButton = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Gráficos/VSyncOption/VSyncCheck"
@onready var master_volume_slider: HSlider = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Áudio/ÁudioContainer/MasterVolumeOption/MasterVolumeSlider"
@onready var music_volume_slider: HSlider = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Áudio/ÁudioContainer/MusicVolumeOption/MusicVolumeSlider"
@onready var sfx_volume_slider: HSlider = $"SettingsPanel/MainMargin/VBoxContainer/MainContent/Áudio/ÁudioContainer/SfxVolumeOption2/SfxVolumeSlider"
@onready var back_button: Button = $SettingsPanel/MainMargin/VBoxContainer/BottomButtons/BackButton
@onready var apply_button: Button = $SettingsPanel/MainMargin/VBoxContainer/BottomButtons/ApplyButton

@onready var tab_container: TabContainer = $SettingsPanel/MainMargin/VBoxContainer/MainContent

var is_dirty = false
var _action_to_rebind: StringName = &""
var _button_to_rebind: Button = null
var _last_focused_control: Control = null

const ACTION_DISPLAY_NAMES = {
	"move_up": "Mover para Cima",
	"move_down": "Mover para Baixo",
	"move_left": "Mover para Esquerda",
	"move_right": "Mover para Direita"
}

func _ready() -> void:
	EntityManager.register_settings_menu(self)
	hide()

	if back_button: back_button.pressed.connect(_on_back_button_pressed)
	if apply_button: apply_button.pressed.connect(_on_apply_button_pressed)
	
	if language_button: language_button.item_selected.connect(_on_language_selected)
	if ui_scale_slider: ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	
	if window_mode_button: window_mode_button.item_selected.connect(_on_window_mode_selected)
	if resolution_button: resolution_button.item_selected.connect(_on_resolution_selected)
	if vsync_check: vsync_check.toggled.connect(_on_vsync_toggled)
	if fps_limit_spinbox: fps_limit_spinbox.value_changed.connect(_on_fps_limit_changed)

	if master_volume_slider: master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider: music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider: sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	_populate_resolutions()
	_populate_languages()
	_populate_keybindings()
	
	tab_container.focus_mode = Control.FOCUS_ALL
	
func _unhandled_input(event: InputEvent) -> void:
	if _action_to_rebind != &"":
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_cancel_rebind() 
				get_viewport().set_input_as_handled()
				return 

			for action in ACTION_DISPLAY_NAMES.keys():
				if action == _action_to_rebind:
					continue
				if InputMap.action_has_event(action, event):
					InputMap.action_erase_event(action, event)
			
			InputMap.action_erase_events(_action_to_rebind)
			InputMap.action_add_event(_action_to_rebind, event)
			
			is_dirty = true
			_cancel_rebind() 
			get_viewport().set_input_as_handled()
			return
		
		if event is InputEventMouseButton and event.is_pressed():
			if is_instance_valid(_button_to_rebind) and not _button_to_rebind.get_rect().has_point(event.position):
				_cancel_rebind()
			return
		
		get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("ui_pause") and visible:
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	_last_focused_control = get_viewport().gui_get_focus_owner()
	show()
	_update_ui_from_settings()
	tab_container.call_deferred("grab_focus")

func _cancel_rebind():
	_action_to_rebind = &""
	if is_instance_valid(_button_to_rebind):
		var action_name = _button_to_rebind.get_meta("action_name")
		_button_to_rebind.text = _get_key_for_action(action_name)
	
	_button_to_rebind = null

func close_menu() -> void:
	hide()
	if is_dirty:
		SettingsManager.load_settings()
		SettingsManager.apply_settings()
		is_dirty = false
		
	if is_instance_valid(_last_focused_control):
		_last_focused_control.call_deferred("grab_focus")
	_last_focused_control = null

func _update_ui_from_settings() -> void:
	if fps_limit_spinbox: fps_limit_spinbox.value = SettingsManager.settings.graphics.fps_limit
	if language_button: language_button.select(SettingsManager.settings.general.language_index)
	if ui_scale_slider: ui_scale_slider.value = SettingsManager.settings.general.ui_scale
	if window_mode_button: window_mode_button.select(SettingsManager.settings.graphics.window_mode)
	if vsync_check: vsync_check.button_pressed = SettingsManager.settings.graphics.vsync
	
	if resolution_button:
		var current_res = SettingsManager.settings.graphics.resolution
		for i in range(resolution_button.item_count):
			if resolution_button.get_item_text(i) == current_res:
				resolution_button.select(i)
				break

	if master_volume_slider: master_volume_slider.value = SettingsManager.settings.audio.master_volume
	if music_volume_slider: music_volume_slider.value = SettingsManager.settings.audio.music_volume
	if sfx_volume_slider: sfx_volume_slider.value = SettingsManager.settings.audio.sfx_volume

	_populate_keybindings()
	is_dirty = false

func _populate_keybindings() -> void:
	if not keybindings_grid: return
	
	if _action_to_rebind != &"":
		_cancel_rebind()
		
	for child in keybindings_grid.get_children():
		child.queue_free()
	
	for action in ACTION_DISPLAY_NAMES.keys():
		var action_name = ACTION_DISPLAY_NAMES[action]
		
		var label = Label.new()
		label.text = action_name
		keybindings_grid.add_child(label)
		
		var button = Button.new()
		button.text = _get_key_for_action(action)
		button.pressed.connect(_on_rebind_button_pressed.bind(action, button))
		button.set_meta("action_name", action)
		keybindings_grid.add_child(button)

func _get_key_for_action(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "N/A"

func _on_rebind_button_pressed(action: StringName, button_node: Button) -> void:
	if _action_to_rebind != &"":
		_cancel_rebind()

	_action_to_rebind = action
	_button_to_rebind = button_node 
	button_node.text = "Pressione uma tecla..."
	
	button_node.release_focus()

func _on_apply_button_pressed() -> void:
	_cancel_rebind() 
	if is_dirty:
		SettingsManager.save_settings()
		SettingsManager.apply_settings()
		is_dirty = false
	close_menu()
	emit_signal("back_pressed")

func _on_back_button_pressed() -> void:
	_cancel_rebind() 
	close_menu()
	emit_signal("back_pressed")

func _on_fps_limit_changed(value: float) -> void:
	SettingsManager.settings.graphics.fps_limit = int(value)
	SettingsManager.apply_graphics_settings()
	is_dirty = true

func _on_language_selected(index: int) -> void:
	SettingsManager.settings.general.language_index = index
	is_dirty = true

func _on_ui_scale_changed(value: float) -> void:
	SettingsManager.settings.general.ui_scale = value
	is_dirty = true

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.settings.graphics.window_mode = index
	is_dirty = true

func _on_resolution_selected(index: int) -> void:
	if resolution_button:
		SettingsManager.settings.graphics.resolution = resolution_button.get_item_text(index)
		is_dirty = true

func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.settings.graphics.vsync = toggled_on
	is_dirty = true

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.settings.audio.master_volume = value
	SettingsManager.apply_audio_settings()
	is_dirty = true

func _on_music_volume_changed(value: float) -> void:
	SettingsManager.settings.audio.music_volume = value
	SettingsManager.apply_audio_settings()
	is_dirty = true

func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.settings.audio.sfx_volume = value
	SettingsManager.apply_audio_settings()
	is_dirty = true

func _populate_resolutions():
	if not resolution_button: return
	resolution_button.clear()
	var common_resolutions = ["1280x720", "1600x900", "1920x1080"]
	for res in common_resolutions:
		resolution_button.add_item(res)

func _populate_languages():
	if not language_button: return
	language_button.clear()
	language_button.add_item("Português", 0)
	language_button.add_item("English", 1)
