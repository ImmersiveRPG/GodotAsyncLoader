# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

class_name Helpers

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
