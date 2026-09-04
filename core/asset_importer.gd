class_name AssetImporter
extends EditorScript
## Manifest-driven asset importer. Run from the editor (File > Run) to copy source
## assets from assets/source/ into assets/runtime/ and register them in credits.

const MANIFEST_PATH := "res://assets/source/manifest.json"
const SOURCE_ROOT := "res://assets/source/"
const TEXTURE_DIR := "res://assets/runtime/textures/"
const AUDIO_DIR := "res://assets/runtime/audio/"
const DATA_DIR := "res://assets/runtime/data/"
const CREDITS_PATH := "res://docs/credits.md"


func _run() -> void:
	var manifest := _read_manifest()
	if manifest.is_empty():
		return
	var imported: Array = []
	_import_textures(manifest.get("textures", []), imported)
	_import_audio(manifest.get("audio", []), imported)
	_import_data(manifest.get("data", []), imported)
	_write_credits(imported)
	var editor := get_editor_interface()
	if editor != null:
		editor.get_resource_filesystem().scan()
	print("AssetImporter: imported %d asset(s)." % imported.size())


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("AssetImporter: manifest not found at %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AssetImporter: manifest is not a JSON object.")
		return {}
	return parsed


func _import_textures(entries: Array, imported: Array) -> void:
	for item in entries:
		var entry := item as Dictionary
		if entry == null:
			continue
		var id := String(entry.get("id", ""))
		var source := String(entry.get("source", ""))
		if id.is_empty() or source.is_empty():
			push_warning("AssetImporter: skipping invalid texture entry %s" % [entry])
			continue
		var target := "%s%s.%s" % [TEXTURE_DIR, id, source.get_extension()]
		if _copy_file(SOURCE_ROOT + source, target):
			imported.append({"id": id, "kind": "texture", "source": source, "target": target})


func _import_audio(entries: Array, imported: Array) -> void:
	for item in entries:
		var entry := item as Dictionary
		if entry == null:
			continue
		var id := String(entry.get("id", ""))
		var source := String(entry.get("source", ""))
		if id.is_empty() or source.is_empty():
			push_warning("AssetImporter: skipping invalid audio entry %s" % [entry])
			continue
		var target := "%s%s.%s" % [AUDIO_DIR, id, source.get_extension()]
		if _copy_file(SOURCE_ROOT + source, target):
			imported.append({"id": id, "kind": "audio", "source": source, "target": target})


func _import_data(entries: Array, imported: Array) -> void:
	for item in entries:
		var entry := item as Dictionary
		if entry == null:
			continue
		var id := String(entry.get("id", ""))
		var source := String(entry.get("source", ""))
		var kind := String(entry.get("kind", "form"))
		if id.is_empty() or source.is_empty():
			push_warning("AssetImporter: skipping invalid data entry %s" % [entry])
			continue
		var json_path := SOURCE_ROOT + source
		if not FileAccess.file_exists(json_path):
			push_warning("AssetImporter: missing data source %s" % json_path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("AssetImporter: data source %s is not a JSON object." % json_path)
			continue
		var resource := _build_data_resource(kind, parsed)
		if resource == null:
			continue
		var target := "%s%s.tres" % [DATA_DIR, id]
		_ensure_dir(target)
		var err := ResourceSaver.save(resource, target)
		if err != OK:
			push_error("AssetImporter: failed to save %s (error %d)" % [target, err])
			continue
		imported.append({"id": id, "kind": "data", "source": source, "target": target})


func _build_data_resource(kind: String, data: Dictionary) -> Resource:
	match kind:
		"form":
			return FormDefinition.from_dict(data)
		_:
			push_error("AssetImporter: unknown data kind '%s'." % kind)
			return null


func _copy_file(from: String, to: String) -> bool:
	if not FileAccess.file_exists(from):
		push_warning("AssetImporter: missing source file %s" % from)
		return false
	_ensure_dir(to)
	var bytes := FileAccess.get_file_as_bytes(from)
	var file := FileAccess.open(to, FileAccess.WRITE)
	if file == null:
		push_error("AssetImporter: cannot write %s" % to)
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))


func _write_credits(imported: Array) -> void:
	if imported.is_empty():
		return
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ_WRITE)
	if file == null:
		push_error("AssetImporter: cannot open %s" % CREDITS_PATH)
		return
	file.seek_end()
	var text := "\n## 程序化导入\n\n| id | 类型 | 源文件 | 目标位置 |\n|---|---|---|---|\n"
	for item in imported:
		var entry := item as Dictionary
		text += "| %s | %s | %s | %s |\n" % [entry.get("id", ""), entry.get("kind", ""), entry.get("source", ""), entry.get("target", "")]
	text += "\n"
	file.store_string(text)
	file.close()
