class_name AssetLibrary
## Programmatic asset access by id. Gameplay code loads assets through this
## instead of hard-coding res:// paths. Ids map to a stable folder layout under
## assets/runtime/.

const TEXTURE_DIR := "res://assets/runtime/textures/"
const AUDIO_DIR := "res://assets/runtime/audio/"
const DATA_DIR := "res://assets/runtime/data/"

const TEXTURE_EXTS := [".png", ".svg", ".jpg", ".jpeg", ".webp"]
const AUDIO_EXTS := [".ogg", ".wav", ".mp3"]

static var _texture_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _data_cache: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	return _load(_texture_cache, TEXTURE_DIR, TEXTURE_EXTS, id) as Texture2D


static func audio(id: StringName) -> AudioStream:
	return _load(_audio_cache, AUDIO_DIR, AUDIO_EXTS, id) as AudioStream


static func data(id: StringName) -> Resource:
	return _load(_data_cache, DATA_DIR, [".tres"], id)


static func clear_cache() -> void:
	_texture_cache.clear()
	_audio_cache.clear()
	_data_cache.clear()


static func _load(cache: Dictionary, dir: String, exts: Array, id: StringName) -> Resource:
	var key := String(id)
	if cache.has(key):
		return cache[key]
	for ext in exts:
		var path := "%s%s%s" % [dir, key, ext]
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource != null:
				cache[key] = resource
				return resource
	push_error("AssetLibrary: missing asset '%s' under %s" % [key, dir])
	return null
