# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

class_name Helpers

class DirectoryIterator:
	var _path : String
	var _dir : Directory
	var _file_name := ""
	var _skip_navigational := false
	var _skip_hidden := false

	func _init(path : String, skip_navigational := false, skip_hidden := false) -> void:
		_path = path
		_skip_navigational = skip_navigational
		_skip_hidden = skip_hidden

	func should_continue() -> bool:
		return not _file_name.empty()

	func _iter_init(arg) -> bool:
		_dir = Directory.new()
		assert(_dir.open(_path) == OK)
		assert(_dir.list_dir_begin(_skip_navigational, _skip_hidden) == OK)
		_file_name = _dir.get_next()
		return should_continue()

	func _iter_next(arg) -> bool:
		_file_name = _dir.get_next()

		# Close the directory if this is the end
		var retval := should_continue()
		if not retval:
			_dir.list_dir_end()
		return retval

	func _iter_get(arg) -> Dictionary:
		return {
			"name" : _file_name,
			"is_dir" : _dir.current_is_dir()
		}

static func recursively_get_all_children_of_type(target : Node, target_type) -> Array:
	var matches := []
	var to_search := [target]
	while not to_search.empty():
		var entry = to_search.pop_front()

		for child in entry.get_children():
			to_search.append(child)

		if entry is target_type:
			matches.append(entry)

	return matches

static func call_deferred_and_return_yielded(obj : Object, method : String, args := []):
	var fn := _CallDeferredReturnYield.new(obj, method, args)
	var retval = fn._call()
	#print("retval: %s" % [retval])
	return retval

class _CallDeferredReturnYield:
	signal on_done(retval)
	var _obj : Object
	var _method : String
	var _args := []

	func _init(obj : Object, method : String, args := []) -> void:
		_obj = obj
		_method = method
		_args = args

	func _call():
		self.call_deferred("_call_and_emit_signal_on_done", _obj, _method, _args)
		var retval = yield(self, "on_done")
		return retval

	func _call_and_emit_signal_on_done(obj : Object, method : String, args := []) -> void:
		#print("calling: %s, %s, %s" % [obj, method, args])
		var retval = obj.callv(method, args)
		self.emit_signal("on_done", retval)
