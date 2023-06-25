# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _to_call_out := []
var _mutex_out := Mutex.new()

func _start_loop(target_fps : int, frame_budget_threshold_msec : int) -> void:
	var frame_budget_msec := int(1000 / target_fps)
	#var frame_budget_threshold_msec := frame_budget_threshold_msec
	var consecutive_no_work_count := 0

	while _is_running:
		var frame_budget_remaining_msec := frame_budget_msec
		var is_sleeping := false
		var call_count := 0
		while not is_sleeping:
			#yield(get_tree().create_timer(0.1), "timeout")
			var before := Time.get_ticks_msec()

			_mutex_out.lock()
			var entry = _to_call_out.pop_front()
			_mutex_out.unlock()

			var callable = null
			var args = null
			if entry:
				callable = entry["callable"]
				args = entry["args"]
				if callable != null and callable.is_valid():
					if args != null and typeof(args) == TYPE_ARRAY and not args.empty():
						#FIXME print(entry)
						callable.call_funcv(args)
					else:
						callable.call_func()
					call_count += 1
					consecutive_no_work_count = 0
					#yield(get_tree().create_timer(0.1), "timeout")

			var after := Time.get_ticks_msec()
			var used := after - before
			frame_budget_remaining_msec -= used
			#print("Used:%s, frame_budget_remaining_msec:%s" % [used, frame_budget_remaining_msec])

			# Sleep if there is no work to do, or the budget is below the threshold
			if callable == null or frame_budget_remaining_msec < frame_budget_threshold_msec:
				is_sleeping = true
				consecutive_no_work_count += 1

#		if call_count > 0:
#			print("frame_budget_remaining_msec:%s, call_count:%s" % [frame_budget_remaining_msec, call_count])

		# Sleep, and do it longer if we had no work for X consecutive loops
		var sleep_sec := 0.05 if consecutive_no_work_count > 10 else 0.001
		yield(get_tree().create_timer(sleep_sec), "timeout")
		#yield(get_tree().create_timer(0.1), "timeout")

func start(target_fps : int, frame_budget_threshold_msec := 5) -> void:
	_is_running = true

	self.call_deferred("_start_loop", target_fps, frame_budget_threshold_msec)

func stop() -> void:
	_is_running = false

func call_throttled(cb : FuncRef, args := []) -> void:
	var entry := {
		"callable" : cb,
		"args" : args,
	}

	_mutex_out.lock()
	_to_call_out.push_back(entry)
	_mutex_out.unlock()
