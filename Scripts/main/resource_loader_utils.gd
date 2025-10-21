extends Node

func populate_resources_from_path(output_array: Array, path: String, expected_script: Script, recursive: bool = false) -> void:
	
	if not DirAccess.dir_exists_absolute(path):
		printerr("ResourceLoaderUtils: O diretório não foi encontrado: ", path)
		return
	
	_scan_directory(path, expected_script, recursive, output_array)

func _scan_directory(path: String, expected_script: Script, recursive: bool, resource_array: Array) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		printerr("ResourceLoaderUtils: Não foi possível abrir o diretório: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path = path.path_join(file_name)

		if dir.current_is_dir():
			if recursive:
				_scan_directory(full_path, expected_script, recursive, resource_array)
		else:
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				
				if full_path.ends_with(".remap"):
					full_path = full_path.trim_suffix(".remap")
					
				var resource = load(full_path)
				
				if resource:
					var actual_script = resource.get_script()
					if actual_script == expected_script:
						resource_array.append(resource)
		
		file_name = dir.get_next()
