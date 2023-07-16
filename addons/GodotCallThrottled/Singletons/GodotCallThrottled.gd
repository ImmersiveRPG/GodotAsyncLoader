# Copyright (c) 2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotCallThrottled

extends Node

const INT32_MAX := int(int(pow(2, 31)) - 1)

signal waiting_count_change(waiting_count)
signal over_frame_budget(used_usec, budget_usec)
signal engine_too_busy(waiting_count)
signal engine_not_busy(waiting_count)

var _main_iteration_start_ticks := 0
var _main_iteration_end_ticks := 0
var _last_node_scene := preload("res://addons/GodotCallThrottled/LastNode/LastNode.tscn")
var _last_node = null

var _to_call := []
var _mutex := Mutex.new()

const _is_logging := true
var _frame_budget_usec := 0
var _frame_budget_threshold_usec := 0
var _is_setup := false
var _was_working := false
var _is_too_busy_to_work := false

func _on_start_physics_frame() -> void:
	#if _is_logging: print("Frame: %s" % [self.get_tree().get_frame()])
	self._main_iteration_start()

	# Just return if there isn't a scene yet
	var target = self.get_tree().root
	if not target: return

	# Forget last node if it has been freed
	if not is_instance_valid(_last_node):
		_last_node = null

	# Create the dummy last node in tree
	if not _last_node:
		_last_node = _last_node_scene.instance()
		target.add_child(_last_node)

	# Move last node to be last in tree
	if _last_node and _last_node.get_index() != target.get_child_count()-1:
		target.move_child(_last_node, target.get_child_count()-1)

func _main_iteration_start() -> void:
	_main_iteration_start_ticks = Time.get_ticks_usec() # FIXME: Change to Engine.get_frame_ticks()
	_main_iteration_end_ticks = _main_iteration_start_ticks
	#if _is_logging: print("    _main_iteration_start: %s" % [_main_iteration_start_ticks])

func _main_iteration_done() -> void:
	_main_iteration_end_ticks = Time.get_ticks_usec()
	#if _is_logging: print("    _main_iteration_done: %s" % [_main_iteration_end_ticks])
	var overhead_usec := int(clamp(_main_iteration_end_ticks - _main_iteration_start_ticks, 0, INT32_MAX))
	#if _is_logging: print("    overhead_usec: %s" % [overhead_usec])

	# Run callables
	if _is_setup:
		self._run_callables(overhead_usec)

func _run_callables(overhead_usec : float) -> void:
	var frame_budget_surplus_usec := int(clamp(_frame_budget_usec - overhead_usec, 0, INT32_MAX))
	var frame_budget_expenditure_usec := 0
	var is_working := true
	var call_count := 0
	var has_reasonable_starting_budget := frame_budget_surplus_usec - _frame_budget_threshold_usec > 0

	var did_work := false
	while has_reasonable_starting_budget and is_working:
		var before := Time.get_ticks_usec()

		# Get the next callable
		_mutex.lock()
		var entry = _to_call.pop_front()
		_mutex.unlock()

		var did_call := false
		if entry:
			var callable = entry["callable"]
			var args = entry["args"]
			if callable != null and callable.is_valid():
				if args != null and typeof(args) == TYPE_ARRAY and not args.empty():
					callable.call_funcv(args)
				else:
					callable.call_func()
				did_work = true
				did_call = true
				call_count += 1

		var after := Time.get_ticks_usec()
		var used := after - before
		frame_budget_surplus_usec -= used
		frame_budget_expenditure_usec += used

		# Stop running callables if there are none left, or we are over budget
		if not did_call or frame_budget_surplus_usec < _frame_budget_threshold_usec:
			is_working = false

	_mutex.lock()
	var waiting_count := _to_call.size()
	_mutex.unlock()

	if _is_logging and call_count > 0:
		print("budget_usec:%s, overhead_usec:%s, expenditure_usec:%s, surplus_usec:%s, called:%s, waiting:%s" % [_frame_budget_usec, overhead_usec, frame_budget_expenditure_usec, frame_budget_surplus_usec, call_count, waiting_count])

	self.emit_signal("waiting_count_change", waiting_count)

	if _is_too_busy_to_work and not _was_working and did_work:
		_is_too_busy_to_work = false
		self.emit_signal("engine_not_busy", waiting_count)

	if not _is_too_busy_to_work and _was_working and not did_work and waiting_count > 0:
		_is_too_busy_to_work = true
		self.emit_signal("engine_too_busy", waiting_count)

	var used_usec := int(clamp(Time.get_ticks_usec() - _main_iteration_start_ticks, 0, INT32_MAX))
	if used_usec > _frame_budget_usec:
		self.emit_signal("over_frame_budget", used_usec, _frame_budget_usec)

	_was_working = did_work

func start(frame_budget_usec : int, frame_budget_threshold_usec : int) -> void:
	_frame_budget_usec = frame_budget_usec
	_frame_budget_threshold_usec = frame_budget_threshold_usec
	self.get_tree().connect("physics_frame", self, "_on_start_physics_frame")
	_is_setup = true

func call_throttled(cb : FuncRef, args := []) -> void:
	if not _is_setup:
		push_error("Please run GodotCallThrottled.start before calling")
		return

	var entry := {
		"callable" : cb,
		"args" : args,
	}

	_mutex.lock()
	_to_call.push_back(entry)
	_mutex.unlock()
